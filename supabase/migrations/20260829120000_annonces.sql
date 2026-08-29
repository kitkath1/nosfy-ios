-- ═══════════════════════════════════════════════════════════════════
-- LES ANNONCES — une seule annonce par événement, et de quoi la faire
--
-- Verdict de Kathryn du 29-08 : « notification et pop-up rewards sont
-- liées » puis, sur la question posée : « oui une seule annonce par
-- événement je suis d'accord ».
--
-- L'analyse qui a produit cette migration : neuf composants annoncent un
-- gain dans l'app, et QUATRE formules indépendantes recalculent le même
-- nombre. Ce ne sont pas deux composants liés — c'est une seule fonction
-- manquante, « annoncer un gain », réimplémentée neuf fois.
--
-- Cette migration donne au serveur ce qu'il faut pour qu'il n'y en ait
-- plus qu'une : le RESTE qui dit la vérité, la RARETÉ qui tombe enfin,
-- les RÈGLES DE RYTHME sorties du code, et UNE SEULE RÉPONSE par acte.
--
-- Analyse : ../../tools/rewards/PLAN-ANNONCES.md
-- Écrans  : ../../docs/screens/notification.md · reward-popup.md
-- Règles  : ../../tools/rewards/PLAN-REWARDS-BACKEND.md §2 (pacing) et §4
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. LE `reste` DEVIENT DÉRIVÉ — la jauge cesse de mentir ─────────
--
-- ⚠️⚠️ **`booster_progress.reste` EST CRÉÉ, LU PAR `etat_coffre`, ET ÉCRIT
-- PAR PERSONNE.** Mesuré le 29-08 : aucune fonction ne le met à jour. La
-- jauge « 62/100 » du pied du coffre — et celle de la notification qui
-- arrive — affichent donc **0/100 en permanence**, quel que soit le solde.
--
-- Et c'est une violation de la loi n° 1 de ce back-end : **un solde se
-- DÉRIVE, il ne se stocke pas.** `reste` EST un solde (« combien j'ai mis
-- de côté vers le prochain sachet »), et un compteur stocké se
-- désynchronise dès le premier rejeu.
--
-- La forme juste tient en une ligne : `solde_or mod prix_booster`. Elle est
-- vraie à tout instant, elle survit à un rejeu, et elle se corrige d'
-- elle-même après un achat (le solde baisse de 100, le reste ne bouge pas).
--
-- ⚠️ **CE QUE ÇA NE FAIT PAS, ET C'EST VOULU** : aucune conversion
-- automatique des pièces en sachets. Le §4 sexies décrit un report cumulé
-- qui donnerait des boosters au règlement — mais `claim_booster()` DÉBITE
-- déjà 100 pièces pour en donner un. Faire les deux, c'est payer deux fois
-- le même travail. C'est la question d'économie ouverte du §6.7 de la fiche
-- coffre (« une séance en rapporte deux »), et elle appartient à Kathryn :
-- cette migration ne la tranche pas, elle rend seulement la jauge HONNÊTE.
--
-- La table `booster_progress` est conservée (on ne détruit pas) : elle
-- redeviendra la bonne forme le jour où la conversion automatique sera
-- tranchée. En attendant, plus personne ne la lit.
create or replace function public.etat_coffre()
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'solde_or', (
      select coalesce(sum(delta), 0)::int from public.coin_ledger
       where user_id = auth.uid() and currency = 'yellow'),
    'solde_argent', (
      select coalesce(sum(delta), 0)::int from public.coin_ledger
       where user_id = auth.uid() and currency = 'silver'),
    'boosters_or', (
      select count(*)::int from public.user_boosters
       where user_id = auth.uid() and origine <> 'legendaire'
         and opened_at is null),
    -- ⚠️ DÉRIVÉ, plus lu d'une table vide. `greatest(…, 0)` parce qu'un
    -- solde négatif (une annulation de trop) rendrait un modulo négatif, et
    -- `greatest(prix, 1)` parce qu'un prix à zéro en base ferait une
    -- division par zéro — deux gardes qui coûtent zéro et évitent un 500.
    'reste', (
      select (greatest((select coalesce(sum(delta), 0)::int
                          from public.coin_ledger
                         where user_id = auth.uid() and currency = 'yellow'), 0)
              % greatest((select coalesce((value)::text::integer, 100)
                            from public.reward_rules
                           where key = 'prix_booster'), 1))::int),
    'prix_booster', (
      select coalesce((value)::text::integer, 100) from public.reward_rules
       where key = 'prix_booster'),
    'pieces_par_serie', (
      select coalesce((value)::text::integer, 20) from public.reward_rules
       where key = 'pieces_par_serie')
  );
$$;

-- ── 2. LES RÈGLES DE RYTHME SORTENT DU CODE ─────────────────────────
--
-- ⚠️⚠️ **CE QUI DÉCIDE AUJOURD'HUI EST EXACTEMENT CE QUE LE PLAN
-- INTERDIT.** `DecideurSerie.pour` (RestartSheet.swift:611) tient en trois
-- modulos — `serie % 10`, `% 5`, `% 3` — alors que le §2 du plan écrit noir
-- sur blanc : « Interdiction des positions fixes : aucun déclencheur du type
-- "série 5/10/15" ». Le rythme qui en sort est celui que le plan décrit
-- comme le mauvais : jusqu'à SIX interruptions dans une séance de 20 séries
-- au lieu des quatre de la table v1, dont deux d'affilée aux rangs 9 et 10.
--
-- Les valeurs ci-dessous sont celles de la table v1 (§2), tranchées le 25-08
-- par délégation. Elles vivent ICI pour que le rythme se règle **sans
-- redéployer l'app** — c'est toute la raison d'être de `reward_rules`.
insert into public.reward_rules (key, value) values
  -- LE BUDGET D'ATTENTION — la ressource rare de ce jeu.
  ('popups_max_seance',          '4'::jsonb),
  ('reward_monetaire_max_seance','1'::jsonb),
  ('video_max_seance',           '1'::jsonb),

  -- L'ÉCART MINIMAL. ⚠️ **AMBIGUÏTÉ NON TRANCHÉE, ET ELLE COMPTE DOUBLE** :
  -- la doctrine du §2 dit « 3 séries / 6 min » (un OU), la table v1 de la
  -- même section dit « 3 séries ET 6 minutes ». Le OU est deux fois plus
  -- permissif. On pose le ET — le plus proche du « ~60 % de séries
  -- silencieuses » qui est le RÉSULTAT visé — et la clé ci-dessous permet
  -- de basculer sans build le jour où Kathryn tranche.
  ('ecart_min_series',           '3'::jsonb),
  ('ecart_min_minutes',          '6'::jsonb),
  ('ecart_exige_les_deux',       'true'::jsonb),

  -- LES BONUS MONÉTAIRES (§2, table v1).
  ('bonus_fort',                 '40'::jsonb),
  ('bonus_progres',              '30'::jsonb),
  ('bonus_surprise',             '20'::jsonb),
  ('bonus_plafond_seance',       '60'::jsonb),

  -- L'ANTI-RESSASSAGE : un même type de fait ne se raconte pas deux fois.
  ('meme_fait_max_seance',       '1'::jsonb),
  ('meme_fait_max_semaine',      '2'::jsonb),

  -- LA RARETÉ (§4 du plan, et §4 decies pour ce qu'elle ouvre).
  -- ⚠️ Ces trois-là ne sortent JAMAIS au client : `regles_annonces()` les
  -- retire (voir §3). Un pity timer visible est un pity timer farmable, et
  -- la rareté est toute la valeur de cette pièce.
  ('rare_une_chance_sur',        '30'::jsonb),
  ('rare_pity_seances',          '45'::jsonb),
  ('rare_cooldown_seances',      '10'::jsonb),

  -- LE WELCOME BACK (§2, table v1). ⚠️ Le montant du claim n'est PAS ici :
  -- c'est `pieces_retour_quotidien` (10, tranché le 28-08). La table v1
  -- disait « claim +20 » — elle est PÉRIMÉE sur ce point, et deux clés qui
  -- se contredisent valent moins qu'une seule qui dit vrai.
  ('welcome_absence_jours',      '4'::jsonb),
  ('welcome_cooldown_jours',     '14'::jsonb),
  ('welcome_max_mois',           '2'::jsonb),

  -- ✅ **LE VERDICT DU 29-08, ET C'EST LA RÈGLE QUI COMMANDE TOUT LE
  -- COUPLE** : « oui une seule annonce par événement je suis d'accord ».
  -- Un gain ne se dit qu'une fois : la pop-up REMPLACE la dalle, elle ne
  -- s'y ajoute pas. Aujourd'hui la fin de séance en enchaîne DEUX (la
  -- capsule à +1,6 s, la pop-up booster à +5,2 s) — c'est ce que cette clé
  -- interdit.
  ('annonce_une_par_evenement',  'true'::jsonb),

  -- ⚠️ **EN ATTENTE DE SON VERDICT** (§8.1 de PLAN-ANNONCES). Une dalle
  -- qu'on ne tape pas ne dépense pas d'attention : je propose qu'elle NE
  -- consomme PAS le budget des quatre pop-ups. Mais alors il lui faut son
  -- propre plafond, sinon on la sert à chaque série — d'où la seconde clé.
  ('notif_consomme_budget',      'false'::jsonb),
  ('notifs_max_seance',          '6'::jsonb)
on conflict (key) do nothing;

-- ── 3. UN SEUL APPEL POUR TOUT LE RYTHME ────────────────────────────
--
-- L'app LIT les règles, elle ne les connaît pas. Un seul aller-retour, et
-- surtout : **une règle ajoutée demain ne demande aucun changement de
-- client** — c'est tout l'intérêt d'agréger la table plutôt que d'énumérer
-- des champs.
--
-- ⚠️⚠️ **LES TROIS CLÉS DE RARETÉ SONT RETIRÉES DE LA RÉPONSE.** Le §8
-- (anti-abus) et le §4 undecies sont formels : « le back-end ne doit surtout
-- jamais exposer le *pity timer* — rendu visible, il devient farmable, et la
-- rareté est toute la valeur de cette pièce ». Elles vivent dans la table
-- (le serveur s'en sert), elles ne sortent pas par cette porte.
--
-- ⚠️ La table est en lecture publique pour `authenticated` (policy « les
-- règles sont publiques en lecture », migration du wallet) : un client
-- curieux peut donc lire `rare_pity_seances` en interrogeant la table
-- directement. **Cette fonction ne suffit pas à le cacher** — la vraie
-- protection serait de sortir les trois clés dans une table à part, sans
-- policy de lecture. À faire le jour où la rareté sera vraiment en jeu ;
-- c'est noté, pas résolu.
create or replace function public.regles_annonces()
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
    from public.reward_rules
   where key not in ('rare_une_chance_sur', 'rare_pity_seances',
                     'rare_cooldown_seances');
$$;

-- ── 4. LA PIÈCE D'ARGENT TOMBE ENFIN ────────────────────────────────
--
-- ⚠️⚠️ **AUJOURD'HUI ELLE NE PEUT PAS ÊTRE GAGNÉE.** `roll_rare` était
-- nommée dans les commentaires de la migration du booster noir (« le noir
-- tombe du RNG serveur, p = 1/30, pity 45, cooldown 10 ») et n'a jamais été
-- écrite. Conséquence en chaîne, mesurée : solde argent bloqué à 0 → aucun
-- booster noir ouvrable → toute la robe noire du Sacre, ses textures bakées
-- et sa card légendaire sont inatteignables par le jeu.
--
-- ⚠️ **LE COMPTEUR DE PITIÉ EST DÉRIVÉ, JAMAIS STOCKÉ** — la loi n° 1, et
-- ici elle protège aussi de la triche : le nombre de séances depuis la
-- dernière pièce se COMPTE dans le journal. Il n'y a rien à remettre à zéro,
-- rien à falsifier, et une réinstallation ne redonne pas sa chance.
--
-- ⚠️ **ET LE TIRAGE NE PEUT PAS SE REJOUER** : l'index
-- `coin_ledger_gain_unique (user_id, raison, workout_id) where workout_id is
-- not null and delta > 0` — qui existe déjà — couvre `piece_argent`. Une
-- séance ne peut donc faire tomber qu'une pièce, même si l'outbox rejoue
-- l'appel dix fois. C'est la condition SANS LAQUELLE la file d'attente
-- doublerait les gains au premier accident de réseau.
create or replace function public.roll_rare(p_workout uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_chance   integer;
  v_pity     integer;
  v_cooldown integer;
  v_dernier  timestamptz;
  v_depuis   integer;
  v_tombe    boolean;
begin
  if p_workout is null then return false; end if;

  select coalesce((value)::text::integer, 30) into v_chance
    from public.reward_rules where key = 'rare_une_chance_sur';
  select coalesce((value)::text::integer, 45) into v_pity
    from public.reward_rules where key = 'rare_pity_seances';
  select coalesce((value)::text::integer, 10) into v_cooldown
    from public.reward_rules where key = 'rare_cooldown_seances';

  select max(created_at) into v_dernier
    from public.coin_ledger
   where user_id = auth.uid() and raison = 'piece_argent';

  -- Les séances RÉGLÉES depuis la dernière pièce (ou depuis toujours).
  select count(*)::integer into v_depuis
    from public.coin_ledger
   where user_id = auth.uid()
     and raison = 'serie_faite' and delta > 0
     and created_at > coalesce(v_dernier, '-infinity'::timestamptz);

  -- ⚠️ LE COOLDOWN NE S'APPLIQUE QU'APRÈS UN PREMIER DROP. Sans cette
  -- garde, une joueuse neuve serait muselée dix séances avant d'avoir la
  -- moindre chance — ce n'est pas un cooldown, c'est une porte fermée.
  if v_dernier is not null and v_depuis < v_cooldown then
    return false;
  end if;

  -- La pitié d'abord (elle GARANTIT), le hasard ensuite.
  v_tombe := (v_depuis >= v_pity)
             or (random() < 1.0 / greatest(v_chance, 1));
  if not v_tombe then return false; end if;

  begin
    insert into public.coin_ledger
      (user_id, delta, raison, currency, workout_id)
    values (auth.uid(), 1, 'piece_argent', 'silver', p_workout);
  exception when unique_violation then
    -- Cette séance a déjà fait tomber sa pièce : un rejeu, pas un gain.
    return false;
  end;

  return true;
end $$;

-- ── 5. LA CLÔTURE REND L'ANNONCE ENTIÈRE ────────────────────────────
--
-- ⚠️⚠️ **UNE SEULE ANNONCE PAR ÉVÉNEMENT SUPPOSE UNE SEULE RÉPONSE.** Tant
-- que la clôture rendait les pièces d'un côté et que le reste se demandait
-- ailleurs, l'app avait besoin de plusieurs sources pour composer sa dalle —
-- et c'est précisément comme ça qu'on se retrouve avec quatre formules du
-- même nombre. Un acte, un appel, une réponse : tout ce que la dalle doit
-- dire est là.
--
-- Ce qui change par rapport à la version du 28-08 :
--   • le TIRAGE de la pièce d'argent (§4) est appelé ici — c'est le
--     « au settle » du §2 du plan, le seul endroit où il ne soit pas
--     falsifiable ;
--   • la réponse porte `argent` (la pièce est-elle tombée) et `reste`
--     (où en est la jauge APRÈS ce gain).
--
-- ⚠️ **LE TIRAGE N'A LIEU QUE SI LES PIÈCES ONT ÉTÉ RÉELLEMENT
-- CRÉDITÉES.** `v_credite` est faux exactement quand l'index a refusé
-- l'insertion, c'est-à-dire sur un REJEU. Sans cette garde, chaque passage
-- de l'outbox offrirait une nouvelle chance de tirer — la file d'attente
-- deviendrait une machine à sous.
create or replace function public.cloturer_seance(
  p_workout uuid,
  p_series  integer
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_par_serie integer;
  v_pieces    integer;
  v_credite   boolean := true;
  v_booster   uuid;
  v_neuf      boolean := true;
  v_argent    boolean := false;
  v_prix      integer;
  v_solde     integer;
begin
  if p_workout is null then
    raise exception 'cloturer_seance : il faut la séance';
  end if;

  select coalesce((value)::text::integer, 20) into v_par_serie
    from public.reward_rules where key = 'pieces_par_serie';
  v_pieces := greatest(coalesce(p_series, 0), 0) * v_par_serie;

  -- ① les pièces — seulement s'il y a eu du travail.
  if v_pieces > 0 then
    begin
      insert into public.coin_ledger
        (user_id, delta, raison, currency, workout_id)
      values (auth.uid(), v_pieces, 'serie_faite', 'yellow', p_workout);
    exception when unique_violation then
      v_credite := false;
    end;
  else
    v_credite := false;
  end if;

  -- ② le sachet — FORFAITAIRE (un par séance terminée, quel que soit le
  --    nombre de séries : sa précision du 28-08).
  if greatest(coalesce(p_series, 0), 0) > 0 then
    begin
      insert into public.user_boosters (user_id, origine, workout_id)
      values (auth.uid(), 'seance', p_workout)
      returning id into v_booster;
    exception when unique_violation then
      v_neuf := false;
      select id into v_booster
        from public.user_boosters
       where user_id = auth.uid() and workout_id = p_workout
       limit 1;
    end;
  end if;

  -- ③ LA RARETÉ — au règlement, côté serveur, et une seule fois.
  --
  -- ⚠️⚠️ **LE BONUS NE DOIT JAMAIS COÛTER LE CRÉDIT PRINCIPAL.** Les pièces
  -- et le sachet viennent d'être insérés DANS CETTE TRANSACTION : une
  -- exception non rattrapée ici les annulerait tous les deux, et la séance
  -- n'aurait jamais payé. Le bloc `exception` ouvre une sous-transaction qui
  -- isole le tirage — s'il casse, on perd une chance de pièce d'argent, pas
  -- le travail de la joueuse. C'est le seul endroit de ce fichier où
  -- attraper `others` est la bonne réponse, et c'est parce que le résultat
  -- est facultatif par nature.
  if v_credite then
    begin
      v_argent := public.roll_rare(p_workout);
    exception when others then
      v_argent := false;
    end;
  end if;

  select coalesce((value)::text::integer, 100) into v_prix
    from public.reward_rules where key = 'prix_booster';
  v_solde := public.solde_or();

  return jsonb_build_object(
    'pieces',           case when v_credite then v_pieces else 0 end,
    'pieces_creditees', v_credite,
    'booster_id',       v_booster,
    'booster_neuf',     v_neuf and v_booster is not null,
    'solde',            v_solde,
    -- NOUVEAU — de quoi composer l'annonce sans rien redemander.
    'argent',           v_argent,
    'reste',            (greatest(v_solde, 0) % greatest(v_prix, 1))::int,
    'prix_booster',     v_prix);
end $$;

-- ── 6. LES DROITS ───────────────────────────────────────────────────
--
-- ⚠️ `roll_rare` n'est PAS donnée au client : elle ne s'appelle que depuis
-- `cloturer_seance`, en `security definer`. Exposée, elle serait rejouable
-- jusqu'à la pièce — et l'index ne protège que par séance.
revoke all on function public.roll_rare(uuid) from public;
revoke all on function public.roll_rare(uuid) from authenticated;

revoke all on function public.regles_annonces() from public;
grant execute on function public.regles_annonces()              to authenticated;
grant execute on function public.etat_coffre()                  to authenticated;
grant execute on function public.cloturer_seance(uuid, integer)  to authenticated;
