-- ════════════════════════════════════════════════════════════════════════
-- LE PROFIL ET LES EXERCICES CHOISIS — 13-09
--
-- Demandé par Kathryn le 13-09 : « créer pour plus tard, même si c'est empty,
-- ça sera utile en termes de data » ; « on crée des comptes que par Apple, et
-- ça identifie direct si un compte existe déjà : on arrive à la home direct ».
--
-- Ce que Nosfy demande et n'écrivait nulle part (WoopApp.swift : « Rien n'est
-- écrit au serveur : definir_profil() n'existe pas ») trouve ici sa table :
--   · `profils`            — langue, prénom, but, et la DATE de fin d'onboarding
--                            (c'est elle, l'aiguillage : posée = on connaît la
--                            personne, la home direct ; absente = Nosfy) ;
--   · `exercices_choisis`  — les exercices que la personne a choisis, par id du
--                            catalogue Swift (le catalogue reste dans l'app :
--                            nom, catégorie, muscles) et dans l'ordre.
-- L'objectif hebdo, lui, reste dans `user_prefs` (20260905110000) : `definir_profil`
-- le relaie à `definir_objectif` pour que le questionnaire n'ait qu'UN appel.
--
-- LA LOI DU VIDE, côté serveur : `profil()` rend toujours un objet — `existe`
-- false, `exercices` [], l'objectif par défaut — jamais un null, jamais une
-- erreur pour une personne qui n'a encore rien.
--
-- Aucun Swift n'appelle ces fonctions à ce jour (🔵 serveur seul) : le site
-- d'appel est la fin du questionnaire de Nosfy (session porte) et l'échange
-- Apple (l'aiguillage). Mesuré le 13-09 depuis le compte de test.
-- ════════════════════════════════════════════════════════════════════════

-- ── LES TABLES ──────────────────────────────────────────────────────────

create table if not exists public.profils (
  user_id                uuid primary key references auth.users (id) on delete cascade,
  langue                 text,            -- « fr » / « en », la langue du questionnaire
  prenom                 text,
  but                    text,            -- la réponse « pourquoi tu t'entraînes » (libre)
  onboarding_termine_at  timestamptz,     -- posé quand Nosfy se termine — L'AIGUILLAGE
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create table if not exists public.exercices_choisis (
  user_id      uuid not null references auth.users (id) on delete cascade,
  exercise_id  text not null,             -- l'id du catalogue Swift (ExerciseCatalog)
  position     integer not null default 0,
  choisi_at    timestamptz not null default now(),
  primary key (user_id, exercise_id)
);

alter table public.profils           enable row level security;
alter table public.exercices_choisis enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'profils' and policyname = 'select own') then
    create policy "select own" on public.profils for select using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'profils' and policyname = 'insert own') then
    create policy "insert own" on public.profils for insert with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'profils' and policyname = 'update own') then
    create policy "update own" on public.profils for update using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'exercices_choisis' and policyname = 'all own') then
    create policy "all own" on public.exercices_choisis for all using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
end $$;

grant select, insert, update         on public.profils           to authenticated;
grant select, insert, update, delete on public.exercices_choisis to authenticated;

-- ── LA LECTURE : profil() — l'aiguillage et tout ce qu'on sait ──────────

create or replace function public.profil()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  p public.profils%rowtype;
  v_exos jsonb;
  v_seances integer;
  v_cree timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into p from public.profils where user_id = v_uid;
  select coalesce(jsonb_agg(e.exercise_id order by e.position, e.choisi_at), '[]'::jsonb)
    into v_exos from public.exercices_choisis e where e.user_id = v_uid;
  select count(*) into v_seances from public.workouts w where w.user_id = v_uid and w.ended_at is not null;
  select u.created_at into v_cree from auth.users u where u.id = v_uid;
  return jsonb_build_object(
    'existe',             p.user_id is not null,
    'onboarding_termine', p.onboarding_termine_at is not null,   -- l'aiguillage : true → la home direct
    'langue',             p.langue,
    'prenom',             p.prenom,
    'but',                p.but,
    'objectif_hebdo',     public.objectif_hebdo(),
    'exercices',          v_exos,
    'seances',            v_seances,
    'compte_cree_at',     v_cree,
    'onboarding_termine_at', p.onboarding_termine_at
  );
end;
$$;

-- ── L'ÉCRITURE : definir_profil(…) — la fin du questionnaire, en UN appel ──

create or replace function public.definir_profil(
  p_langue text default null,
  p_prenom text default null,
  p_but text default null,
  p_objectif_hebdo integer default null,
  p_onboarding_termine boolean default true)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'raison', 'sans_session');
  end if;
  insert into public.profils (user_id, langue, prenom, but, onboarding_termine_at, updated_at)
  values (v_uid, p_langue, p_prenom, p_but,
          case when p_onboarding_termine then now() else null end, now())
  on conflict (user_id) do update
    set langue     = coalesce(excluded.langue, profils.langue),
        prenom     = coalesce(excluded.prenom, profils.prenom),
        but        = coalesce(excluded.but, profils.but),
        -- une fin d'onboarding ne se défait pas : on garde la première date
        onboarding_termine_at = coalesce(profils.onboarding_termine_at, excluded.onboarding_termine_at),
        updated_at = now();
  if p_objectif_hebdo is not null then
    perform public.definir_objectif(p_objectif_hebdo);   -- user_prefs, borne 1..14
  end if;
  return public.profil();
end;
$$;

-- ── LES EXERCICES CHOISIS : choisir_exercices(ids) — l'ensemble, dans l'ordre ──

create or replace function public.choisir_exercices(p_ids text[])
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'raison', 'sans_session');
  end if;
  delete from public.exercices_choisis where user_id = v_uid
    and not (exercise_id = any (coalesce(p_ids, '{}')));
  insert into public.exercices_choisis (user_id, exercise_id, position)
  select v_uid, id, ord - 1
    from unnest(coalesce(p_ids, '{}')) with ordinality as t(id, ord)
  on conflict (user_id, exercise_id) do update set position = excluded.position;
  return jsonb_build_object('ok', true, 'exercices',
    (select coalesce(jsonb_agg(e.exercise_id order by e.position), '[]'::jsonb)
       from public.exercices_choisis e where e.user_id = v_uid));
end;
$$;

grant execute on function public.profil()                                          to authenticated;
grant execute on function public.definir_profil(text, text, text, integer, boolean) to authenticated;
grant execute on function public.choisir_exercices(text[])                         to authenticated;
