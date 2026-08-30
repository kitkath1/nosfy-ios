-- ═══════════════════════════════════════════════════════════════════════════
-- 20260830210000 — LE COFFRE DIT VRAI : la conversion, le jour, la flamme
--
-- VERDICT APPLIQUÉ (Kathryn, 30-08-2026 au soir — tools/annonces/PLAN-COFFRE-ANNONCES.md
-- §0, §1 défauts acceptés, §4 M1) :
--   • « à 100 pièces un sachet apparaît TOUT SEUL, le nombre monte, et les pièces
--     RETOMBENT (converties) ; le sachet forfaitaire de clôture s'affiche en plus » —
--     y compris LE STOCK D'AVANT : à la pose, chaque solde jaune ≥ 100 devient ses
--     sachets (le compte de test : 1 536 → 15 sachets `conversion` + 36 ; le vrai compte
--     pareil). Le coffre dit vrai DÈS la pose, pas au premier +10 du lendemain ;
--   • « le Welcome Back : chaque jour à MINUIT CHEZ ELLE, pas UTC » (Q7 : une règle
--     serveur `fuseau_jour` = Europe/Paris, jamais le fuseau du téléphone — SKILL §4) ;
--   • « la flamme 🔥 : oui, jours d'affilée, comptée au serveur, SANS bonus » ;
--   • Q9 : l'achat `claim_booster` se ferme — avec la conversion le solde ne dépasse
--     plus 99, l'achat ne pouvait plus réussir.
--
-- CE QUE LE CODE FAISAIT (relu fichier:ligne, plan §2.4) : aucune conversion —
-- `etat_coffre.reste = solde_or % prix` sur le solde TOTAL (1 360 pièces → « 60/100 »,
-- treize tranches de 100 qui n'étaient des sachets nulle part) ; la raison
-- `conversion_booster` existait dans le check du carnet depuis le 28-08 et n'avait
-- jamais été écrite ; `claim_booster` débitait 100 au tap, sans témoin d'idempotence.
--
-- LES QUATRE LOIS (SKILL woop-backend) tenues ici :
--   1. un solde se DÉRIVE : la conversion est une ligne -100 dans le carnet + un sachet,
--      jamais un report stocké (`booster_progress` reste morte) ; la flamme se dérive des
--      séances, rien ne la stocke ;
--   2. l'idempotence est un INDEX — et pour la conversion, LE SOLDE LUI-MÊME : un rejeu
--      ne crédite rien (l'index refuse AVANT le déclencheur), donc ne convertit rien ;
--      deux crédits en vol sont sérialisés par un verrou consultatif par utilisatrice ;
--   3. un ledger ne se rembobine pas : rien n'est effacé, rien n'est réécrit — et une
--      `annulation` positive ne se reconvertit PAS (le déclencheur l'exclut) ;
--   4. rien n'est déployé sans sonde : tools/annonces/verif_backend_coffre.py.
--
-- ÉCARTS À LA LETTRE DU PLAN, DITS ICI (relecture adverse du 30-08 soir, 4 lentilles) :
--   • M1.4 disait « appeler convertir_pieces à la fin de trois fonctions » — on pose un
--     DÉCLENCHEUR sur tout crédit jaune : un seul endroit, les crédits de demain aussi,
--     `tirer_noeud_chemin` n'a pas à être recopiée (une enveloppe du même nom ajoute
--     `sachets_convertis`) ; conséquence : un cadeau posé à la main convertit aussi ;
--   • M1.7 disait trois clés — `etat_coffre` en rend QUATRE : `jour` (la date de la
--     maison), `retour_disponible`, `retour_prochain` (le prochain minuit Paris : l'horloge
--     du +10 qu'une session voisine planifie — dérivé de la même règle, zéro écriture),
--     `flamme` = {jours, aujourdhui_fait} ; le plan §4 est réaligné sur cette forme ;
--   • `argent` GARDE son sens (« la pièce est tombée à CET appel ») pour ne pas changer un
--     champ que l'app incrémente (EconomieWoop.swift:211) ; le stocké au rejeu est sous
--     une clé NEUVE, `argent_seance` ;
--   • les lignes `retour_quotidien` d'avant la pose portent un jour UTC : au plus UN
--     double versement, le jour de la pose, entre 00:00 et 02:00 Paris (on ne réécrit pas
--     leur `jour` : deux claims à cheval sur minuit UTC feraient sauter l'index) ;
--   • `claim_booster` est fermée alors que l'app installée l'appelle encore quand
--     `boosters == 0` (CoffreV2.swift:2552, ProfilLune.swift:1265 → 403 → `.impossible`,
--     rien de visible) : c'est un 🔴 sur la carte du serveur jusqu'au J2, qui retire l'appel.
--
-- ⚠️ ORDRE : le check des origines AVANT la fonction qui écrit 'conversion' ; la clé
-- du fuseau AVANT la fonction qui la lit ; `flamme()` AVANT `etat_coffre()` qui l'appelle ;
-- le rattrapage du stock APRÈS le déclencheur (il n'en a pas besoin, mais les
-- fonctions qu'il appelle, si).
-- ⚠️ Un `check` se REMPLACE en entier : la liste des origines est celle de
-- 20260828190000_gains_coffre.sql:57-58 (la DERNIÈRE) + 'conversion'.
-- ⚠️ Les droits se RÉVOQUENT NOMINATIVEMENT (anon, authenticated, public) : sous
-- Supabase les default privileges donnent execute à chaque rôle — payé sur roll_rare
-- (20260829130000).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 0. LE JOUR : une règle serveur, jamais le fuseau du client ──────────────
--
-- « Minuit chez elle » : une app à une utilisatrice n'a pas de table de profil
-- (site : b-po-profil ⚪). Une CLÉ de règle est la forme la moins chère qui ne
-- croit pas le client — une ligne à changer si elle déménage.
insert into public.reward_rules (key, value) values
  ('fuseau_jour', '"Europe/Paris"'::jsonb)
on conflict (key) do nothing;

-- ⚠️ La ligne à changer est aussi la ligne qui casserait tout : un fuseau mal
-- tapé ferait lever `at time zone` dans `etat_coffre`, donc à chaque premier plan.
-- Un nom inconnu de la base des fuseaux retombe sur UTC au lieu de rendre 500.
create or replace function public.fuseau_jour()
returns text
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select r.value #>> '{}' from public.reward_rules r
      where r.key = 'fuseau_jour'
        and exists (select 1 from pg_timezone_names t where t.name = r.value #>> '{}')),
    'UTC');
$$;

-- Le jour courant DANS ce fuseau. C'est la seule définition du « jour » de la
-- maison : le Welcome Back, la flamme et `retour_disponible` la partagent.
-- Interne : l'app lit `etat_coffre().jour`, elle n'a pas à l'appeler.
create or replace function public.jour_courant()
returns date
language sql stable security definer set search_path = public as $$
  select (now() at time zone public.fuseau_jour())::date;
$$;

revoke all on function public.fuseau_jour()  from public;
revoke all on function public.fuseau_jour()  from anon;
revoke all on function public.fuseau_jour()  from authenticated;
revoke all on function public.jour_courant() from public;
revoke all on function public.jour_courant() from anon;
revoke all on function public.jour_courant() from authenticated;

-- ── 1. L'ORIGINE 'conversion' — recopier la DERNIÈRE liste, jamais la première ─
alter table public.user_boosters drop constraint if exists user_boosters_origine_check;
alter table public.user_boosters add constraint user_boosters_origine_check
  check (origine in ('seance', 'achat', 'cadeau', 'legendaire',
                     'chemin',
                     'conversion'));       -- NOUVEAU : né de 100 pièces

-- ── 2. LA CONVERSION — privée, sous verrou, dérivée du solde ─────────────────
--
-- Tant que le solde jaune ≥ prix_booster : un sachet `conversion` + une ligne
-- -prix `conversion_booster` (la raison existait depuis wallet_coffre.sql:42,
-- jamais écrite), dans la MÊME transaction. Rend le nombre converti.
--
-- ⚠️ Le témoin d'idempotence est le solde : la fonction ne fait rien tant qu'il
-- n'y a pas 100 pièces en poche, et un rejeu de clôture (index refusé) ne
-- crédite rien. Le verrou consultatif de transaction, par utilisatrice, empêche
-- deux crédits en vol de lire le même solde et de convertir deux fois ; le solde
-- est lu APRÈS la prise du verrou.
-- ⚠️ `p_user` est un paramètre, pas `auth.uid()` : le déclencheur (§3) passe
-- `new.user_id` et le rattrapage (§11) passe chaque utilisatrice — juste aussi
-- pour un crédit posé par la main du dashboard (auth.uid() y vaut null).
-- ⚠️ Borne à 1 000 tours (2 000 lignes) : un solde délirant ne bloque pas la
-- transaction ; si la borne est atteinte, un WARNING le dit dans les logs.
create or replace function public.convertir_pieces(p_user uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_prix    integer;
  v_solde   integer;
  v_n       integer := 0;
  v_booster uuid;
begin
  if p_user is null then return 0; end if;

  select coalesce((value)::text::integer, 100) into v_prix
    from public.reward_rules where key = 'prix_booster';
  v_prix := greatest(coalesce(v_prix, 100), 1);

  perform pg_advisory_xact_lock(hashtext(p_user::text));

  select coalesce(sum(delta), 0)::int into v_solde
    from public.coin_ledger
   where user_id = p_user and currency = 'yellow';

  while v_solde >= v_prix loop
    if v_n >= 1000 then
      raise warning 'convertir_pieces : borne atteinte pour %, il reste % pièces', p_user, v_solde;
      exit;
    end if;

    insert into public.user_boosters (user_id, origine)
    values (p_user, 'conversion')
    returning id into v_booster;

    insert into public.coin_ledger (user_id, delta, raison, currency, booster_id)
    values (p_user, -v_prix, 'conversion_booster', 'yellow', v_booster);

    v_n     := v_n + 1;
    v_solde := v_solde - v_prix;
  end loop;

  return v_n;
end $$;

revoke all on function public.convertir_pieces(uuid) from public;
revoke all on function public.convertir_pieces(uuid) from anon;
revoke all on function public.convertir_pieces(uuid) from authenticated;

-- ── 3. LE DÉCLENCHEUR — tout crédit jaune convertit ─────────────────────────
--
-- Un seul endroit, pour TOUS les crédits : la clôture, le retour quotidien, le
-- chemin, un cadeau posé à la main — et ceux qu'on écrira demain. Il ne se
-- redéclenche pas lui-même : la ligne de conversion est un DÉBIT (delta < 0),
-- que la condition `when` exclut. Il EXCLUT aussi `annulation` : c'est la
-- seule façon de DÉFAIRE une conversion (écrire +100 `annulation` : loi n° 3)
-- sans qu'elle se reconvertisse aussitôt ; le solde peut alors dépasser 99
-- jusqu'au crédit suivant, et c'est voulu.
--
-- Le nombre converti par CE crédit est porté par la TRANSACTION
-- (`set_config(…, true)`) : les fonctions qui répondent le relisent au lieu de
-- deviner par un horodatage.
create or replace function public.tg_convertir_apres_credit()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_avant integer;
begin
  v_avant := coalesce(nullif(current_setting('woop.convertis', true), ''), '0')::int;
  perform set_config('woop.convertis',
                     (v_avant + public.convertir_pieces(new.user_id))::text,
                     true);
  return null;
end $$;

revoke all on function public.tg_convertir_apres_credit() from public;
revoke all on function public.tg_convertir_apres_credit() from anon;
revoke all on function public.tg_convertir_apres_credit() from authenticated;

drop trigger if exists coin_ledger_convertir on public.coin_ledger;
create trigger coin_ledger_convertir
  after insert on public.coin_ledger
  for each row
  when (new.delta > 0 and new.currency = 'yellow' and new.raison <> 'annulation')
  execute function public.tg_convertir_apres_credit();

-- Ce que CETTE transaction a converti (0 si rien) — lu par les trois fonctions.
create or replace function public.convertis_transaction()
returns integer
language sql stable security definer set search_path = public as $$
  select coalesce(nullif(current_setting('woop.convertis', true), ''), '0')::int;
$$;
revoke all on function public.convertis_transaction() from public;
revoke all on function public.convertis_transaction() from anon;
revoke all on function public.convertis_transaction() from authenticated;

-- ── 4. LA CLÔTURE rend le STOCKÉ au rejeu, et dit ce qu'elle a converti ──────
--
-- Avant : rejouée (outbox, kill, double tap), elle rendait des zéros — une page
-- noire qui se relit après un kill n'aurait rien eu à empiler. Maintenant :
-- `rejeu: true` et les MÊMES pièces / sachet que la première fois ; la pièce
-- d'argent de la séance est sous `argent_seance` (le stocké), pendant que
-- `argent` garde son sens d'aujourd'hui — « tombée à CET appel » — parce que
-- l'app installée l'incrémente (EconomieWoop.swift:211) sans lire `rejeu`.
-- La réponse porte aussi `solde_argent` et `sachets_convertis` : la pile de la
-- page noire se compose depuis UNE réponse (plan §5.1).
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
  v_rejeu     boolean := false;
  v_booster   uuid;
  v_neuf      boolean := true;
  v_argent    boolean := false;   -- tombée À CET APPEL
  v_argent_s  boolean := false;   -- tombée pour CETTE SÉANCE (le stocké)
  v_prix      integer;
  v_solde     integer;
begin
  if p_workout is null then
    raise exception 'cloturer_seance : il faut la séance';
  end if;

  select coalesce((value)::text::integer, 20) into v_par_serie
    from public.reward_rules where key = 'pieces_par_serie';
  v_pieces := greatest(coalesce(p_series, 0), 0) * v_par_serie;

  -- ① les pièces — seulement s'il y a eu du travail. L'insertion déclenche la
  --    conversion (§3) dans la même transaction.
  if v_pieces > 0 then
    begin
      insert into public.coin_ledger
        (user_id, delta, raison, currency, workout_id)
      values (auth.uid(), v_pieces, 'serie_faite', 'yellow', p_workout);
    exception when unique_violation then
      -- Un REJEU : l'index a parlé. On relit ce qui a été payé la première fois.
      v_credite := false;
      v_rejeu   := true;
      select coalesce(delta, 0) into v_pieces
        from public.coin_ledger
       where user_id = auth.uid() and raison = 'serie_faite' and workout_id = p_workout
       limit 1;
    end;
  else
    v_credite := false;
  end if;

  -- ② le sachet — FORFAITAIRE (un par séance terminée, quel que soit le
  --    nombre de séries).
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

  -- ③ LA RARETÉ — au règlement, une seule fois, isolée dans une
  --    sous-transaction (le bonus ne coûte jamais le crédit principal).
  if v_credite then
    begin
      v_argent := public.roll_rare(p_workout);
    exception when others then
      v_argent := false;
    end;
  end if;
  -- Le stocké : cette séance a-t-elle (jamais) fait tomber sa pièce ?
  select exists (
    select 1 from public.coin_ledger
     where user_id = auth.uid() and raison = 'piece_argent' and workout_id = p_workout)
    into v_argent_s;

  select coalesce((value)::text::integer, 100) into v_prix
    from public.reward_rules where key = 'prix_booster';
  v_solde := public.solde_or();

  return jsonb_build_object(
    'pieces',            case when v_credite or v_rejeu then v_pieces else 0 end,
    'pieces_creditees',  v_credite,
    'rejeu',             v_rejeu,
    'booster_id',        v_booster,
    'booster_neuf',      v_neuf and v_booster is not null,
    'solde',             v_solde,
    'solde_argent',      public.solde_argent(),
    'argent',            v_argent,
    'argent_seance',     v_argent_s,
    'sachets_convertis', public.convertis_transaction(),
    'reste',             (greatest(v_solde, 0) % greatest(v_prix, 1))::int,
    'prix_booster',      v_prix);
end $$;

-- ── 5. LE RETOUR QUOTIDIEN — le jour de la maison, et ce qu'il a converti ───
--
-- `jour = public.jour_courant()` : la ligne que le commentaire de
-- gains_coffre.sql:146-148 désignait comme « LA ligne à changer ». L'index
-- `(user_id, jour)` ne bouge pas.
create or replace function public.claim_retour_quotidien()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_montant   integer;
  v_credite   boolean := true;
  v_jour      date;
begin
  select coalesce((value)::text::integer, 10) into v_montant
    from public.reward_rules where key = 'pieces_retour_quotidien';
  v_jour := public.jour_courant();

  begin
    insert into public.coin_ledger (user_id, delta, raison, currency, jour)
    values (auth.uid(), v_montant, 'retour_quotidien', 'yellow', v_jour);
  exception when unique_violation then
    -- Déjà pris ce jour-là. Pas une erreur : le bouton Claim peut appeler sans
    -- savoir (un autre appareil a pu passer avant).
    v_credite := false;
  end;

  return jsonb_build_object(
    'credite',           v_credite,
    'montant',           case when v_credite then v_montant else 0 end,
    'jour',              v_jour,
    'sachets_convertis', public.convertis_transaction(),
    'solde',             public.solde_or());
end $$;

-- ── 6. LE CHEMIN — la même réponse, plus `sachets_convertis` ────────────────
--
-- On ne recopie pas 220 lignes : la fonction du 30-08 devient `_brut`
-- (privée), et une enveloppe du MÊME nom et de la MÊME signature l'appelle et
-- ajoute ce que la conversion a fait. `reclamer_noeud_chemin` (l'ancienne
-- porte) résout `tirer_noeud_chemin` par son nom à l'appel : elle passe par
-- l'enveloppe sans qu'on la touche. (Le `solde` rendu par `_brut` est déjà
-- post-conversion : le déclencheur a tourné pendant son insert.)
alter function public.tirer_noeud_chemin(integer, boolean)
  rename to tirer_noeud_chemin_brut;

revoke all on function public.tirer_noeud_chemin_brut(integer, boolean) from public;
revoke all on function public.tirer_noeud_chemin_brut(integer, boolean) from anon;
revoke all on function public.tirer_noeud_chemin_brut(integer, boolean) from authenticated;

create or replace function public.tirer_noeud_chemin(
  p_noeud  integer,
  p_pieces boolean
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v jsonb;
begin
  v := public.tirer_noeud_chemin_brut(p_noeud, p_pieces);
  return v || jsonb_build_object('sachets_convertis', public.convertis_transaction());
end $$;

revoke all on function public.tirer_noeud_chemin(integer, boolean) from public;
revoke all on function public.tirer_noeud_chemin(integer, boolean) from anon;
grant execute on function public.tirer_noeud_chemin(integer, boolean) to authenticated;

-- ── 7. LA FLAMME — dérivée des séances, jamais stockée, ne rapporte rien ────
--
-- Les jours DISTINCTS de fin de séance (`workouts.ended_at`, dans le fuseau de
-- la maison), comptés d'affilée en remontant depuis aujourd'hui — ou depuis
-- hier si aujourd'hui n'est pas encore fait (la flamme ne s'éteint pas avant
-- minuit). Zéro écriture, zéro clé de bonus : lire `workouts`, poussé par le
-- client, est acceptable ici parce que ça ne PAIE rien (moteur_faits.sql:20-26).
create or replace function public.flamme()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_fuseau     text;
  v_aujourdhui date;
  v_jour       date;
  v_jours      integer := 0;
  v_fait_auj   boolean := false;
  r            record;
begin
  v_fuseau     := public.fuseau_jour();
  v_aujourdhui := public.jour_courant();

  select exists (
    select 1 from public.workouts
     where user_id = auth.uid() and ended_at is not null
       and (ended_at at time zone v_fuseau)::date = v_aujourdhui)
    into v_fait_auj;

  v_jour := case when v_fait_auj then v_aujourdhui else v_aujourdhui - 1 end;

  for r in
    select distinct (ended_at at time zone v_fuseau)::date as d
      from public.workouts
     where user_id = auth.uid() and ended_at is not null
     order by d desc
  loop
    if r.d > v_jour then
      continue;                       -- un jour « d'avance » : ignoré
    elsif r.d = v_jour then
      v_jours := v_jours + 1;
      v_jour  := v_jour - 1;
    else
      exit;                           -- un trou : la série s'arrête
    end if;
  end loop;

  return jsonb_build_object('jours', v_jours, 'aujourdhui_fait', v_fait_auj);
end $$;

revoke all on function public.flamme() from public;
revoke all on function public.flamme() from anon;
grant execute on function public.flamme() to authenticated;

-- ── 8. `etat_coffre` — quatre clés de plus, un seul appel au premier plan ────
--
-- `jour` (la date de la maison), `retour_disponible` (le Welcome Back peut-il
-- promettre avant de payer ?), `retour_prochain` (le prochain minuit dans le
-- fuseau, en timestamptz : l'horloge du +10), `flamme` ({jours, aujourdhui_fait}).
-- Le reste est inchangé ; `reste` est vrai DÈS la pose (§11) et après chaque
-- crédit (§3), sous la borne du §2.
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
         and (opened_at is null
              or (card_id is null
                  and opened_at > now() - interval '6 hours'))),
    'noirs_ouverts', (
      select count(*)::int from public.user_boosters
       where user_id = auth.uid() and origine = 'legendaire'
         and opened_at is not null and card_id is null),
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
       where key = 'pieces_par_serie'),
    -- NOUVEAU (30-08 soir)
    'jour', public.jour_courant(),
    'retour_disponible', (
      not exists (
        select 1 from public.coin_ledger
         where user_id = auth.uid() and raison = 'retour_quotidien'
           and jour = public.jour_courant())),
    'retour_prochain', (
      ((public.jour_courant() + 1)::timestamp at time zone public.fuseau_jour())),
    'flamme', public.flamme()
  );
$$;

-- ── 9. L'ACHAT SE FERME — la jauge fait son travail à sa place ──────────────
--
-- La fonction reste en base (un ledger ne se rembobine pas, et une porte
-- manuelle future se rouvre par un grant), mais plus personne ne peut la
-- pousser : avec la conversion, le solde ne dépasse jamais 99, et un achat ne
-- pouvait plus que mentir « bought for 100 coins ». Elle n'avait aucun témoin
-- d'idempotence (double tap = deux achats).
-- ⚠️ L'app installée l'appelle ENCORE quand `boosters == 0` (CoffreV2.swift:2552,
-- ProfilLune.swift:1265 → EconomieWoop.acheterBooster) : elle recevra 403 →
-- `.impossible`, rien de visible — 🔴 sur la carte du serveur jusqu'au J2.
revoke all on function public.claim_booster() from public;
revoke all on function public.claim_booster() from anon;
revoke all on function public.claim_booster() from authenticated;

-- ── 10. LES DROITS DES FONCTIONS RÉÉCRITES (même signature : conservés) ──────
grant execute on function public.cloturer_seance(uuid, integer) to authenticated;
grant execute on function public.claim_retour_quotidien()       to authenticated;
grant execute on function public.etat_coffre()                  to authenticated;

-- ── 11. LE STOCK D'AVANT : converti UNE fois, à la pose ─────────────────────
--
-- « Les pièces retombent » vaut pour ce qui est déjà en poche : chaque solde
-- jaune ≥ prix devient ses sachets, ici, dans la transaction de la migration
-- (même verrou, même boucle, même carnet). Sans ça, le coffre mentirait jusqu'au
-- prochain +10, puis ferait naître quinze sachets d'un coup dans UNE réponse.
-- C'est une ÉCRITURE D'ARGENT à la pose : dite ici, et mesurée par la sonde
-- ([0] : solde < prix avant tout crédit).
select public.convertir_pieces(u.user_id)
  from (select distinct user_id from public.coin_ledger where currency = 'yellow') u;

-- ── DOWN (à la main, jamais les lignes) — dans CET ordre ─────────────────────
-- 1) re-créer cloturer_seance / claim_retour_quotidien / etat_coffre depuis
--    20260829120000 / 20260828190000 / 20260830160000 (elles ne dépendent plus
--    de flamme/jour_courant) ;
-- 2) drop trigger coin_ledger_convertir on public.coin_ledger ;
-- 3) drop function public.tg_convertir_apres_credit(), public.convertis_transaction(),
--    public.convertir_pieces(uuid), public.flamme(), public.jour_courant(),
--    public.fuseau_jour() ;
-- 4) drop function public.tirer_noeud_chemin(integer, boolean) PUIS
--    alter function public.tirer_noeud_chemin_brut(integer, boolean) rename to tirer_noeud_chemin ;
-- 5) grant execute on function public.claim_booster() to authenticated.
-- Les lignes `conversion_booster` et les sachets `conversion` RESTENT : un carnet
-- ne se rembobine pas — pour défaire une conversion, on écrit +100 `annulation`
-- (que le déclencheur n'attrape pas) et on retire le sachet par la main.
