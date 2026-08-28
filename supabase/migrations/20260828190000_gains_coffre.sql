-- ═══════════════════════════════════════════════════════════════════
-- LES GAINS DU COFFRE — les trois sources qui n'étaient pas des séries
--
-- Verdicts de Kathryn du 28-08 :
--   1. « à chaque connexion tu manges 10 pièces » → une fois par JOUR
--      CALENDAIRE (elle a tranché : « oui une fois par jour calendaire »)
--   2. « dans les gains il y a aussi les gains booster issus des rewards du
--      Duolingo » → les boosters du chemin doivent exister côté serveur
--   3. « à la fin de chaque séance on gagne automatiquement un booster
--      basique » — ⚠️ « peu importe le nombre de séries, c'est UN booster à
--      la fin de la session complète »
--
-- Écran   : ../../docs/screens/coffre-rewards.md
-- État    : ../../tools/coffre-v2/BACKEND-COFFRE.md
-- Règles  : ../../tools/rewards/PLAN-REWARDS-BACKEND.md §4 duodecies + terdecies
-- ═══════════════════════════════════════════════════════════════════

-- ── 0. LE SOLDE D'OR — il manquait, et tout le reste s'en sert ──────
--
-- ⚠️ `solde_argent()` existait, pas son pendant jaune : la migration du
-- wallet ne calculait l'or QU'À L'INTÉRIEUR d'`etat_coffre`, en sous-requête.
-- Toute fonction qui veut rendre un solde après avoir écrit devait donc le
-- recalculer à la main. Il sort ici, et il est défini EN PREMIER parce que
-- les fonctions d'en dessous l'appellent.
create or replace function public.solde_or()
returns integer
language sql stable security definer set search_path = public as $$
  select coalesce(sum(delta), 0)::integer
    from public.coin_ledger
   where user_id = auth.uid() and currency = 'yellow';
$$;

-- ── 1. LES DEUX NOUVELLES RAISONS, ET LA NOUVELLE ORIGINE ───────────
--
-- ⚠️ La raison nomme L'ACTE, pas la monnaie (règle posée dans la migration
-- du wallet) : on gagne des pièces au retour quotidien, on gagne des
-- boosters sur le chemin.
alter table public.coin_ledger drop constraint if exists coin_ledger_raison_check;
-- ⚠️⚠️ **RECOPIER LA LISTE DE LA DERNIÈRE MIGRATION, PAS DE LA PREMIÈRE.**
-- Mon premier jet reprenait celle de `booster_noir.sql` — `piece_noire`, un
-- nom mort depuis le renommage argent — et **perdait `conversion_booster`**.
-- Un `check` se REMPLACE en entier : ce qu'on oublie de recopier devient
-- interdit, et les lignes qui le portaient rendent la migration impossible à
-- appliquer. La liste ci-dessous est celle de `wallet_coffre.sql` + les deux
-- nouvelles.
alter table public.coin_ledger add constraint coin_ledger_raison_check
  check (raison in ('serie_faite', 'ouverture_booster', 'doublon',
                    'cadeau', 'annulation',
                    'piece_argent', 'ouverture_booster_noir',
                    'conversion_booster',
                    -- NOUVEAU
                    'retour_quotidien',   -- +10, une fois par jour
                    'chemin'));           -- le tirage d'un nœud du chemin

alter table public.user_boosters drop constraint if exists user_boosters_origine_check;
alter table public.user_boosters add constraint user_boosters_origine_check
  check (origine in ('seance', 'achat', 'cadeau', 'legendaire',
                     'chemin'));          -- NOUVEAU

-- ⚠️ **SANS `'chemin'`, LES BOOSTERS DU CHEMIN SE RANGERAIENT SOUS
-- `'cadeau'`** — et l'historique deviendrait illisible : on ne saurait plus
-- distinguer ce que le parcours a donné de ce qu'on a offert à la main.
alter table public.user_boosters
  add column if not exists noeud_id integer;

-- ⚠️ **LA ROBE MANQUAIT, ET L'HISTORIQUE EN A BESOIN.** `user_boosters` ne
-- disait que l'ORIGINE (d'où vient le sachet), jamais sa ROBE (à quoi il
-- ressemble). Tant qu'un sachet gagné était forcément orange et un
-- légendaire forcément noir, l'origine suffisait à deviner. Le chemin casse
-- ça : son tirage « rare » rend **[orange, noir]** dans le même nœud. Sans
-- cette colonne, l'historique ne peut pas montrer le bon sachet.
alter table public.user_boosters
  add column if not exists robe text
  check (robe is null or robe in ('lune', 'noire'));

-- ⚠️ La colonne AVANT l'index qui s'en sert — sinon la migration échoue à sa
-- première ligne sur une base neuve.
alter table public.coin_ledger
  add column if not exists noeud_id integer;

-- L'ANTI-DOUBLE-RÉCLAMATION DU CHEMIN. ⚠️ Aujourd'hui c'est un `UserDefaults`
-- (`chemin.reclamees`) qui tient cette garantie côté app — et un
-- `UserDefaults` se remet à zéro à la réinstallation : boosters infinis, la
-- leçon est déjà écrite dans `RewardChemin.swift`. Un index, lui, ne
-- s'oublie pas.
create unique index if not exists user_boosters_chemin_unique
  on public.user_boosters (user_id, noeud_id)
  where origine = 'chemin' and noeud_id is not null;

create unique index if not exists coin_ledger_chemin_unique
  on public.coin_ledger (user_id, noeud_id)
  where raison = 'chemin' and noeud_id is not null;

-- ── 2. LE VERSEMENT DE CONNEXION ────────────────────────────────────

insert into public.reward_rules (key, value) values
  -- ✅ tranché le 28-08 : 10 pièces, une fois par jour calendaire.
  ('pieces_retour_quotidien', '10'::jsonb)
on conflict (key) do nothing;

-- ⚠️⚠️ **L'IDEMPOTENCE EST UN INDEX, PAS UN COMPTEUR.**
--
-- « À chaque connexion » ne peut pas être pris au mot : tuer l'app et la
-- relancer EST une connexion — dix pièces toutes les trois secondes, en
-- boucle, et les 100 pièces d'un booster ne veulent plus rien dire. La règle
-- est donc UNE FOIS PAR JOUR CALENDAIRE, et elle se tient ici, pas dans
-- l'app : un compteur dans les préférences se remet à zéro à la
-- réinstallation.
--
-- ⚠️ **LE FUSEAU EST UNE DÉCISION, ET ELLE EST PROVISOIREMENT UTC.** Quelqu'un
-- qui ouvre l'app à 1 h du matin à Paris touche le versement de la veille.
-- L'alternative juste (le fuseau déclaré du profil) coûte une colonne, et
-- reste ouverte — voir `docs/screens/coffre-rewards.md` §6.4. Ce qu'il ne
-- faut SURTOUT pas, c'est le fuseau envoyé par le client à chaque appel : il
-- se change dans les réglages du téléphone, et c'est le farm par voyage dans
-- le temps.
-- ⚠️⚠️ **ON N'INDEXE PAS `(created_at at time zone 'UTC')::date` — POSTGRES
-- LE REFUSE.** `timezone(text, timestamptz)` est **STABLE**, pas IMMUTABLE
-- (elle dépend de la base de fuseaux, qui est mise à jour), et une expression
-- d'index doit être immuable. La migration aurait échoué À LA POSE avec
-- « functions in index expression must be marked IMMUTABLE » — pas à l'appel,
-- à la pose : la moitié du fichier serait passée, l'autre non.
--
-- Le jour est donc une COLONNE, écrite par la fonction au moment de
-- l'insertion. Et ça rend le choix du fuseau explicite et modifiable : le
-- jour où on passe au fuseau du profil, c'est cette ligne-là qu'on change,
-- pas un index.
alter table public.coin_ledger
  add column if not exists jour date;

create unique index if not exists coin_ledger_retour_jour_unique
  on public.coin_ledger (user_id, jour)
  where raison = 'retour_quotidien' and jour is not null;

create or replace function public.claim_retour_quotidien()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_montant integer;
  v_credite boolean := true;
begin
  select coalesce((value)::text::integer, 10) into v_montant
    from public.reward_rules where key = 'pieces_retour_quotidien';

  begin
    -- ⚠️ Le jour est calculé ICI, pas dans l'index (voir le commentaire de
    -- `coin_ledger_retour_jour_unique`). UTC pour l'instant — c'est LA ligne
    -- à changer le jour où on passe au fuseau du profil.
    insert into public.coin_ledger (user_id, delta, raison, currency, jour)
    values (auth.uid(), v_montant, 'retour_quotidien', 'yellow',
            (now() at time zone 'UTC')::date);
  exception when unique_violation then
    -- Déjà pris aujourd'hui. ⚠️ Ce n'est PAS une erreur : la pop-up doit
    -- pouvoir appeler sans savoir, et se taire si c'est déjà fait.
    v_credite := false;
  end;

  return jsonb_build_object(
    'credite', v_credite,
    'montant', case when v_credite then v_montant else 0 end,
    'solde',   public.solde_or());
end $$;

-- ── 3. LA FIN DE SÉANCE : LES PIÈCES *ET* LE SACHET ─────────────────
--
-- ⚠️⚠️ **LES DEUX RÉCOMPENSES NE COMPTENT PAS LA MÊME CHOSE, ET C'EST SA
-- PRÉCISION DU 28-08** (« peu importe le nombre de séries, c'est UN booster à
-- la fin de la session complète ») :
--
--     les PIÈCES sont proportionnelles au travail  → séries × 20
--     le BOOSTER est FORFAITAIRE                   → il paie le fait d'avoir
--                                                    FINI, pas la quantité
--
-- Une séance de 3 séries et une de 15 donnent un sachet chacune.
--
-- ⚠️ Et les pièces s'écrivent en UNE SEULE LIGNE par séance, pas une par
-- série : l'index `coin_ledger_gain_unique (user_id, raison, workout_id)`
-- existe déjà et ne tolère qu'une ligne de gain par séance. Écrire série par
-- série l'aurait fait échouer dès la deuxième.
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

  -- ② le sachet — FORFAITAIRE, et même si aucune série n'a été faite ?
  --    NON : une séance ouverte puis abandonnée ne doit pas payer. Le
  --    sachet récompense une séance TERMINÉE, et c'est l'appelant qui le
  --    déclare en appelant cette fonction. On exige au moins une série.
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

  return jsonb_build_object(
    'pieces',          case when v_credite then v_pieces else 0 end,
    'pieces_creditees', v_credite,
    'booster_id',      v_booster,
    'booster_neuf',    v_neuf and v_booster is not null,
    'solde',           public.solde_or());
end $$;

-- ── 4. LE CHEMIN : UN NŒUD RÉCLAMÉ ──────────────────────────────────
--
-- ⚠️ Le TIRAGE reste au front pour l'instant (`RewardChemin.TirageRecompense`)
-- et cette fonction ENREGISTRE ce qu'il a donné. C'est une étape, pas la
-- cible : tant que le tirage est au client, il est falsifiable — comme la
-- pitié (après 12 nœuds communs, le taux rare double), qui devra remonter
-- ici. Ce qui est déjà garanti, lui, c'est qu'un nœud ne paie **qu'une
-- fois**, quoi que raconte le client.
create or replace function public.reclamer_noeud_chemin(
  p_noeud    integer,
  p_pieces   integer default 0,
  p_monnaie  text    default 'yellow',
  p_boosters text[]  default '{}'
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_deja    boolean := false;
  v_robe    text;
  v_faits   integer := 0;
begin
  if p_noeud is null then
    raise exception 'reclamer_noeud_chemin : il faut le nœud';
  end if;

  if coalesce(p_pieces, 0) > 0 then
    begin
      insert into public.coin_ledger
        (user_id, delta, raison, currency, noeud_id)
      values (auth.uid(), p_pieces, 'chemin',
              coalesce(p_monnaie, 'yellow'), p_noeud);
    exception when unique_violation then
      v_deja := true;
    end;
  end if;

  -- ⚠️ Un nœud peut rendre DEUX sachets (le tirage « rare » rend
  -- [orange, legendaryBlack], le « légendaire » deux noirs) — mais l'index
  -- d'unicité porte sur (user, nœud). On ne peut donc pas insérer deux
  -- lignes de chemin pour le même nœud… **et c'est le point à trancher** :
  -- soit l'index passe sur (user, nœud, rang), soit un nœud ne rend qu'une
  -- ligne portant une quantité. Provisoirement : la PREMIÈRE robe crée la
  -- ligne du nœud, la seconde est enregistrée en `cadeau` rattaché au même
  -- nœud — lisible dans l'historique, et jamais dupliqué.
  if array_length(p_boosters, 1) is not null then
    foreach v_robe in array p_boosters loop
      begin
        insert into public.user_boosters (user_id, origine, noeud_id, robe)
        values (auth.uid(),
                case when v_faits = 0 then 'chemin' else 'cadeau' end,
                p_noeud, v_robe);
        v_faits := v_faits + 1;
      exception when unique_violation then
        v_deja := true;
      end;
    end loop;
  end if;

  return jsonb_build_object(
    'deja_reclame', v_deja,
    'boosters',     v_faits,
    'solde',        public.solde_or(),
    'solde_argent', public.solde_argent());
end $$;

-- ── 5. L'HISTORIQUE — le journal, pas une reconstruction ────────────
--
-- ⚠️⚠️ **C'EST LE CŒUR DE LA DEMANDE.** La page des gains reconstruit
-- aujourd'hui son contenu depuis les SÉANCES (`séries × 20`, côté app). Les
-- trois sources qui ne sont pas des séances — le versement quotidien, les
-- boosters du chemin, le booster de fin de séance — **n'y apparaissent
-- jamais**. Une reconstruction ne peut montrer que ce qu'elle sait
-- recalculer ; un journal montre ce qui s'est passé.
--
-- C'est aussi ce qui donnera enfin des lignes AVEC UN SACHET : côté app,
-- `GainCoffre.robe` est toujours `nil`, donc chaque ligne montre la pièce
-- d'or.
create or replace function public.historique_gains(p_limite integer default 60)
returns table (
  quand    timestamptz,
  genre    text,     -- 'coins' | 'booster'
  motif    text,     -- la raison / l'origine
  montant  integer,  -- pièces, ou 1 pour un sachet
  monnaie  text,     -- 'yellow' | 'silver' | null
  robe     text      -- 'lune' | 'noire' | null
)
language sql stable security definer set search_path = public as $$
  -- ⚠️ **CHAQUE LITTÉRAL EST TYPÉ.** Dans un `union all` rendu par une
  -- fonction `returns table`, un littéral nu reste de type `unknown` :
  -- Postgres essaie de le résoudre depuis l'autre branche, et quand les deux
  -- branches en ont un au même rang (`'coins'` / `'booster'`), il échoue à la
  -- CRÉATION de la fonction — pas à l'appel. Une migration qui casse à la
  -- pose est la pire des surprises.
  select created_at,
         'coins'::text, raison::text, delta::integer,
         currency::text, null::text
    from public.coin_ledger
   where user_id = auth.uid() and delta > 0
  union all
  select obtained_at,
         'booster'::text, origine::text, 1::integer,
         null::text,
         (case when origine = 'legendaire' then 'noire'
               else coalesce(robe, 'lune') end)::text
    from public.user_boosters
   where user_id = auth.uid()
   order by 1 desc
   limit greatest(coalesce(p_limite, 60), 1);
$$;

-- ── 7. ACHETER UN BOOSTER ORANGE ────────────────────────────────────
--
-- ⚠️ Le débit et la réserve dans la MÊME transaction : sans ça un réseau qui
-- coupe entre les deux laisse une pièce dépensée sans sachet, ou l'inverse.
create or replace function public.claim_booster()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_prix    integer;
  v_solde   integer;
  v_booster uuid;
begin
  select coalesce((value)::text::integer, 100) into v_prix
    from public.reward_rules where key = 'prix_booster';

  v_solde := public.solde_or();
  if v_solde < v_prix then
    return jsonb_build_object('ouvert', false, 'raison', 'solde_insuffisant',
                              'solde', v_solde, 'prix', v_prix);
  end if;

  insert into public.user_boosters (user_id, origine)
  values (auth.uid(), 'achat')
  returning id into v_booster;

  insert into public.coin_ledger
    (user_id, delta, raison, currency, booster_id)
  values (auth.uid(), -v_prix, 'ouverture_booster', 'yellow', v_booster);

  return jsonb_build_object('ouvert', true, 'booster_id', v_booster,
                            'solde', public.solde_or(), 'prix', v_prix);
end $$;

-- ── 8. LES DROITS ───────────────────────────────────────────────────
grant execute on function public.claim_retour_quotidien()          to authenticated;
grant execute on function public.cloturer_seance(uuid, integer)    to authenticated;
grant execute on function public.reclamer_noeud_chemin(integer, integer, text, text[]) to authenticated;
grant execute on function public.historique_gains(integer)         to authenticated;
grant execute on function public.solde_or()                        to authenticated;
grant execute on function public.claim_booster()                   to authenticated;
