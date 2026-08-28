-- ═══════════════════════════════════════════════════════════════════
-- LE WALLET DU COFFRE — un nom, un prix, une progression, un appel
-- Écrit le 28-08-2026, sur trois verdicts de Kathryn :
--   1. « il faudrait le même nom »        → la 2ᵉ monnaie s'appelle ARGENT
--   2. « il faut créer dans Supabase »    → `booster_progress`
--   3. « le prix, écris-le dans Supabase » → `reward_rules`
--
-- Analyse : ../../tools/coffre-v2/PLAN-PIED-COFFRE.md
-- Flow    : ../../tools/rewards/CHANTIERS-UX.md §7
-- Règles  : ../../tools/rewards/PLAN-REWARDS-BACKEND.md §4 undecies
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. LE RENOMMAGE : 'black' → 'silver' ────────────────────────────
--
-- POURQUOI MAINTENANT : les deux tables ont été créées ce matin et sont
-- VIDES. Renommer une valeur de monnaie coûte, à cet instant précis, une
-- contrainte et rien d'autre ; dans un mois, ça coûte une reprise de
-- données et une fenêtre de panne.
--
-- POURQUOI 'silver' ET PAS 'black' : la planche `piece-argent` mesure
-- 186 · 170 · 153 sur ses hautes lumières — un métal PÂLE. Une pièce qui
-- ressemble à ça ne peut pas s'appeler « noire » à l'écran, et l'app
-- l'appelait déjà `.argent` / « legendary coins ». Le sachet qu'elle
-- ouvre, lui, garde son nom : **la pièce d'argent ouvre le booster noir**.
-- Deux objets, deux noms — c'est la tautologie « pièce noire → booster
-- noir » qu'on évite, pas la couleur.
--
-- L'ordre compte : on lâche la contrainte AVANT de réécrire, sinon
-- l'update viole l'ancienne.
alter table public.coin_ledger drop constraint if exists coin_ledger_currency_check;
update public.coin_ledger set currency = 'silver' where currency = 'black';
alter table public.coin_ledger add constraint coin_ledger_currency_check
  check (currency in ('yellow', 'silver'));

alter table public.coin_ledger drop constraint if exists coin_ledger_raison_check;
alter table public.coin_ledger add constraint coin_ledger_raison_check
  check (raison in ('serie_faite', 'ouverture_booster', 'doublon',
                    'cadeau', 'annulation',
                    -- la raison nomme L'ACTE, pas la monnaie : on gagne une
                    -- pièce d'argent, on ouvre un booster noir.
                    'piece_argent', 'ouverture_booster_noir',
                    'conversion_booster'));

-- ── 2. `booster_progress` — le report de la conversion ──────────────
--
-- 1 booster orange = 100 pièces, CUMULÉ AVEC REPORT (§4 sexies) : au
-- règlement, `reste` (0-99) + les pièces de la séance donnent n boosters
-- et un nouveau reste. Rien ne se perd à l'arrondi — et c'est ce `reste`
-- que le pied du coffre affiche en « 62/100 ».
create table if not exists public.booster_progress (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  reste      int not null default 0 check (reste between 0 and 99),
  updated_at timestamptz not null default now()
);

alter table public.booster_progress enable row level security;
do $$ begin
  create policy "chacun voit sa progression"
    on public.booster_progress for select to authenticated
    using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

-- ── 3. `reward_rules` — LES PRIX SORTENT DU CODE ────────────────────
--
-- ⚠️ Le prix d'un booster n'existait NULLE PART : `CoffreFortPurse.perSeries`
-- disait ce qu'une série rapporte, et rien ne disait ce qu'une pièce achète.
-- Il vit ici, et nulle part ailleurs — l'app le LIT, elle ne le connaît pas.
-- C'est la table de configuration du §2 de la note rewards : seuils,
-- budgets, cooldowns et probabilités la rejoindront, et tout se règle sans
-- redéployer l'app.
create table if not exists public.reward_rules (
  key   text primary key,
  value jsonb not null
);

alter table public.reward_rules enable row level security;
do $$ begin
  create policy "les règles sont publiques en lecture"
    on public.reward_rules for select to authenticated
    using (true);
exception when duplicate_object then null; end $$;

insert into public.reward_rules (key, value) values
  -- ce qu'une série RAPPORTE (la loi des 20, tranchée le 13-08)
  ('pieces_par_serie',        '20'::jsonb),
  -- ce qu'une pièce ACHÈTE (§4 sexies : 100 pièces = 1 booster, report cumulé)
  ('prix_booster',            '100'::jsonb),
  -- le booster noir : UNE pièce d'argent, et rien d'autre (28-08)
  ('prix_booster_legendaire', '1'::jsonb)
on conflict (key) do nothing;

-- ── 4. Les fonctions, au nouveau nom ────────────────────────────────

drop function if exists public.solde_noir();

create or replace function public.solde_argent()
returns integer
language sql stable security definer set search_path = public as $$
  select coalesce(sum(delta), 0)::integer
    from public.coin_ledger
   where user_id = auth.uid() and currency = 'silver';
$$;

revoke all on function public.solde_argent() from public;
grant execute on function public.solde_argent() to authenticated;

-- `claim_booster_legendaire` garde son nom (il dit ce qu'elle DONNE) et
-- change de monnaie. Le reste — le retour idempotent, la garde par index
-- unique partiel — ne bouge pas d'une ligne.
create or replace function public.claim_booster_legendaire()
returns public.user_boosters
language plpgsql security definer set search_path = public as $$
declare b public.user_boosters;
declare solde integer;
declare prix integer;
begin
  select * into b from public.user_boosters
   where user_id = auth.uid() and origine = 'legendaire'
     and opened_at is not null and card_id is null
   order by opened_at desc
   limit 1;
  if found then return b; end if;

  -- LE PRIX VIENT DE LA TABLE, plus d'une constante.
  select coalesce((value)::int, 1) into prix
    from public.reward_rules where key = 'prix_booster_legendaire';

  select coalesce(sum(delta), 0) into solde
    from public.coin_ledger
   where user_id = auth.uid() and currency = 'silver';
  if solde < prix then
    raise exception 'pièces d''argent insuffisantes' using errcode = 'P0002';
  end if;

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
    values (auth.uid(), -prix, 'ouverture_booster_noir', 'silver', b.id);

  return b;
end $$;

revoke all on function public.claim_booster_legendaire() from public;
grant execute on function public.claim_booster_legendaire() to authenticated;

-- ── 5. `etat_coffre()` — UN SEUL APPEL POUR TOUT LE PIED ────────────
--
-- Ce n'est pas qu'une économie d'allers-retours : c'est LA GARANTIE que le
-- coffre et le profil ne peuvent pas afficher deux vérités. Un nombre montré
-- à deux endroits n'a le droit d'exister qu'une fois.
--
-- ⚠️ Les deux monnaies n'ont pas la même forme, et la réponse le dit :
--   • l'OR s'ACCUMULE   → un solde, un reste (0-99), un prix ;
--   • l'ARGENT TOMBE    → un solde, et RIEN d'autre. Pas de progression,
--     donc **jamais le pity timer** : exposé, il rend la rareté farmable —
--     et la rareté est toute la valeur de cette pièce (§8 anti-abus).
--   • sur la page argent, solde et sachets ouvrables sont LE MÊME NOMBRE
--     (le sachet noir naît au claim) : le client n'en reçoit qu'un.
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
    'reste', (
      select coalesce((select reste from public.booster_progress
                        where user_id = auth.uid()), 0)::int),
    'prix_booster', (
      select coalesce((value)::int, 100) from public.reward_rules
       where key = 'prix_booster'),
    'pieces_par_serie', (
      select coalesce((value)::int, 20) from public.reward_rules
       where key = 'pieces_par_serie')
  );
$$;

revoke all on function public.etat_coffre() from public;
grant execute on function public.etat_coffre() to authenticated;
