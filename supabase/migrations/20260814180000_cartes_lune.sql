-- LE POOL PARTAGÉ DU SET LUNE
-- Une génération IA n'est pas reproductible : une carte qui existe est
-- une image STOCKÉE, canonique — c'est ce qui permet que deux users
-- retrouvent LES MÊMES cartes et comparent leurs collections.
-- Écritures UNIQUEMENT par la forge (service_role via forge-card) :
-- aucune policy d'insert côté client, le défaut-refus fait la loi.

-- Le pool canonique : une ligne = une carte, à jamais.
create table if not exists public.cards (
  id uuid primary key default gen_random_uuid(),
  famille text not null,
  rarete text not null
    check (rarete in ('common', 'rare', 'epic', 'legendary')),
  scene text not null,           -- la scène inventée par le directeur
  art_path text not null,        -- storage cards/art/<id>.png (l'illustration NUE, le cadre est posé par l'app)
  depth_path text,               -- storage cards/depth/<id>.png (v0 analytique app tant que null)
  created_at timestamptz not null default now()
);
comment on table public.cards is
  'Le pool canonique du set Lune — les cartes récompense partagées entre tous les comptes.';

alter table public.cards enable row level security;
create policy "le pool est lisible par tous les comptes"
  on public.cards for select to authenticated using (true);

-- La collection : qui possède quelle carte du pool.
create table if not exists public.user_cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  card_id uuid not null references public.cards (id) on delete cascade,
  obtained_at timestamptz not null default now(),
  workout_id uuid                -- la séance d'origine (sans FK : le lien est narratif)
);
comment on table public.user_cards is
  'La collection par user — remplie par forge-card à la fin des séances.';

create index if not exists user_cards_user_idx
  on public.user_cards (user_id);

alter table public.user_cards enable row level security;
create policy "chacun lit sa propre collection"
  on public.user_cards for select to authenticated
  using (auth.uid() = user_id);

-- Le bucket des PNG (public en lecture : les cartes sont le set commun ;
-- écritures service_role uniquement — aucune policy d'écriture).
insert into storage.buckets (id, name, public)
  values ('cards', 'cards', true)
  on conflict (id) do nothing;
