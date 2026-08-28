-- ═══════════════════════════════════════════════════════════════════
-- LE BOOSTER NOIR — la pièce noire ouvre les légendaires
-- Écrit le 28-08-2026. Plan : ../../tools/sacre/PLAN-BOOSTER-NOIR.md
-- Règle : ../../tools/rewards/PLAN-REWARDS-BACKEND.md §4 decies
--
-- ⚠️ NON APPLIQUÉE. Rien ne se fait sur Supabase sans Kathryn, et par la
--    CLI — jamais par le MCP de session (il pointe AxioSense).
--        supabase db push        (après relecture ensemble)
--
-- ⚠️ CE QUE J'AI TROUVÉ EN L'ÉCRIVANT, et qui corrige le plan :
--    `user_boosters` et `coin_ledger` **n'existent pas encore** dans les
--    migrations (seuls `cards` et `user_cards` sont déployés). Le §4 decies
--    annonçait « une migration de la contrainte `origine` » en supposant la
--    table là. Ce fichier CRÉE donc les deux tables, aux schémas exacts de
--    SUPABASE-PIPELINE.md, avec ce que le noir demande EN PLUS dès le
--    départ : la valeur `legendaire`, la colonne `currency`, et les deux
--    raisons de mouvement de la pièce noire.
--
--    Les `alter` défensifs en fin de fichier rattrapent l'autre monde :
--    si le SQL du pipeline a été passé avant celui-ci, les tables existent
--    SANS ces ajouts — les `create ... if not exists` les auraient sautées
--    en silence, et la contrainte serait restée fausse.
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. Les sachets ──────────────────────────────────────────────────

create table if not exists public.user_boosters (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  origine     text not null default 'seance'
              check (origine in ('seance', 'achat', 'cadeau', 'legendaire')),
  workout_id  uuid,                       -- la séance qui l'a gagné
  obtained_at timestamptz not null default now(),
  opened_at   timestamptz,                -- null = il tourne sur le manège
  card_id     uuid references public.cards (id)   -- rempli à l'ouverture
);

-- UNE SÉANCE = UN BOOSTER, jamais deux (séance rejouée, reprise, multi-appareil).
create unique index if not exists user_boosters_seance_unique
  on public.user_boosters (user_id, workout_id)
  where workout_id is not null;

-- La requête du manège et de la pill.
create index if not exists user_boosters_attente_idx
  on public.user_boosters (user_id, obtained_at)
  where opened_at is null;

-- ⚠️ LA VRAIE GARDE DU DOUBLE-CLIC EST ICI, PAS DANS LA FONCTION.
-- Première écriture de `claim_booster_legendaire` : un `perform … for update`
-- sur le grand livre avant de lire le solde. Ça ne verrouille RIEN — un
-- `for update` ne pose de verrou que sur les lignes qu'il TROUVE, et le cas
-- qui fait mal (deux appels simultanés) part souvent d'un solde d'une seule
-- ligne, voire d'aucune. Deux appareils pouvaient donc dépenser la même pièce.
--
-- Cet index le rend IMPOSSIBLE au niveau de la base : **au plus UNE réserve
-- noire non scellée par utilisateur**. Le deuxième appel viole l'unicité,
-- la fonction l'attrape et rend la réserve déjà ouverte — le retour
-- idempotent, obtenu par contrainte plutôt que par politesse.
create unique index if not exists user_boosters_noir_ouvert_unique
  on public.user_boosters (user_id)
  where origine = 'legendaire' and card_id is null;

alter table public.user_boosters enable row level security;
do $$ begin
  create policy "chacun voit ses boosters"
    on public.user_boosters for select to authenticated
    using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;
-- AUCUNE policy d'insert/update client : tout passe par les fonctions.

-- ── 2. Le grand livre, à DEUX monnaies ──────────────────────────────

create table if not exists public.coin_ledger (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  delta      integer not null check (delta <> 0),
  raison     text not null
             check (raison in ('serie_faite', 'ouverture_booster',
                               'doublon', 'cadeau', 'annulation',
                               'piece_noire', 'ouverture_booster_noir')),
  -- DEUX MONNAIES, UNE COLONNE (jamais une deuxième table) : deux soldes
  -- dérivés de la même somme. Le jaune se gagne aux séries, le noir tombe
  -- du RNG serveur (`roll_rare`, p = 1/30, pity 45, cooldown 10).
  currency   text not null default 'yellow'
             check (currency in ('yellow', 'black')),
  workout_id uuid,
  booster_id uuid references public.user_boosters (id),
  created_at timestamptz not null default now()
);

create index if not exists coin_ledger_user_idx on public.coin_ledger (user_id);

-- L'ANTI-DOUBLE-CRÉDIT : une séance ne crédite qu'une fois, même rejouée.
create unique index if not exists coin_ledger_gain_unique
  on public.coin_ledger (user_id, raison, workout_id)
  where workout_id is not null and delta > 0;

alter table public.coin_ledger enable row level security;
do $$ begin
  create policy "chacun lit son grand livre"
    on public.coin_ledger for select to authenticated
    using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

-- ── 3. LES RATTRAPAGES (si les tables préexistaient) ────────────────
-- Un `create table if not exists` sur une table déjà là ne dit RIEN et ne
-- change RIEN : sans ce bloc, la contrainte `origine` resterait à trois
-- valeurs et `claim_booster_legendaire` échouerait à l'insert.

alter table public.user_boosters drop constraint if exists user_boosters_origine_check;
alter table public.user_boosters add constraint user_boosters_origine_check
  check (origine in ('seance', 'achat', 'cadeau', 'legendaire'));

alter table public.coin_ledger add column if not exists currency text
  not null default 'yellow';
alter table public.coin_ledger drop constraint if exists coin_ledger_currency_check;
alter table public.coin_ledger add constraint coin_ledger_currency_check
  check (currency in ('yellow', 'black'));

alter table public.coin_ledger drop constraint if exists coin_ledger_raison_check;
alter table public.coin_ledger add constraint coin_ledger_raison_check
  check (raison in ('serie_faite', 'ouverture_booster', 'doublon',
                    'cadeau', 'annulation',
                    'piece_noire', 'ouverture_booster_noir'));

-- ── 4. `claim_booster_legendaire()` — LA GARDE ──────────────────────
--
-- La même doctrine que `claim_booster` (le jaune) : c'est la fonction qui
-- RÉSERVE, et elle est idempotente. Un double tap, un réseau qui coupe, un
-- retour arrière ne tirent JAMAIS deux légendaires avec une seule pièce.
--
-- Trois différences avec le jaune, toutes voulues :
--   1. le sachet noir n'existe pas avant d'être ouvert — la pièce noire EST
--      la réserve. La ligne `user_boosters` naît ici, `origine='legendaire'`.
--   2. le prix est UNE PIÈCE NOIRE, et rien d'autre : aucun débit jaune
--      (verdict Kathryn du 28-08 — le §9.2 de la note rewards est clos).
--   3. le solde lu est le solde NOIR, dérivé (`sum(delta) where black`),
--      jamais une colonne tenue à la main.
create or replace function public.claim_booster_legendaire()
returns public.user_boosters
language plpgsql security definer set search_path = public as $$
declare b public.user_boosters;
declare solde integer;
begin
  -- LE RETOUR IDEMPOTENT AVANT TOUT : une réserve noire déjà ouverte et
  -- pas encore scellée est LA réserve en cours — on la rend telle quelle.
  select * into b from public.user_boosters
   where user_id = auth.uid() and origine = 'legendaire'
     and opened_at is not null and card_id is null
   order by opened_at desc
   limit 1;
  if found then return b; end if;

  -- Le solde NOIR est dérivé, jamais une colonne tenue à la main.
  select coalesce(sum(delta), 0) into solde
    from public.coin_ledger
   where user_id = auth.uid() and currency = 'black';
  if solde < 1 then
    raise exception 'aucune pièce noire' using errcode = 'P0002';
  end if;

  -- LA COURSE EST ARBITRÉE PAR L'INDEX, pas par un verrou de politesse
  -- (voir `user_boosters_noir_ouvert_unique` plus haut). Deux appels
  -- simultanés : le premier insère, le second viole l'unicité — et repart
  -- avec la réserve déjà ouverte au lieu de dépenser une deuxième pièce.
  begin
    insert into public.user_boosters (user_id, origine, opened_at)
      values (auth.uid(), 'legendaire', now())
      returning * into b;
  exception when unique_violation then
    select * into b from public.user_boosters
     where user_id = auth.uid() and origine = 'legendaire'
       and card_id is null
     limit 1;
    return b;
  end;

  insert into public.coin_ledger (user_id, delta, raison, currency, booster_id)
    values (auth.uid(), -1, 'ouverture_booster_noir', 'black', b.id);

  return b;
end $$;

revoke all on function public.claim_booster_legendaire() from public;
grant execute on function public.claim_booster_legendaire() to authenticated;

-- ── 5. Le solde noir, pour l'app ────────────────────────────────────
-- La pill noire du profil ne compte PAS des sachets : elle compte des
-- PIÈCES NOIRES — c'est-à-dire des boosters noirs ouvrables. Une seule
-- source de vérité, dérivée.
create or replace function public.solde_noir()
returns integer
language sql stable security definer set search_path = public as $$
  select coalesce(sum(delta), 0)::integer
    from public.coin_ledger
   where user_id = auth.uid() and currency = 'black';
$$;

revoke all on function public.solde_noir() from public;
grant execute on function public.solde_noir() to authenticated;
