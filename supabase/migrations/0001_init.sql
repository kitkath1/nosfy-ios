-- Woop — schéma de synchronisation.
--
-- SwiftData reste la source de vérité sur l'iPhone : l'app doit pouvoir
-- enregistrer une série en salle sans réseau. Ces tables sont une couche de
-- sauvegarde et de synchronisation, alimentée en arrière-plan.

create extension if not exists "pgcrypto";

-- MARK: Séances

create table if not exists public.workouts (
    id           uuid primary key,
    user_id      uuid not null references auth.users (id) on delete cascade,
    started_at   timestamptz not null,
    ended_at     timestamptz,
    notes        text not null default '',
    updated_at   timestamptz not null default now()
);

create index if not exists workouts_user_started_idx
    on public.workouts (user_id, started_at desc);

-- MARK: Exercices d'une séance

create table if not exists public.logged_exercises (
    id           uuid primary key,
    workout_id   uuid not null references public.workouts (id) on delete cascade,
    user_id      uuid not null references auth.users (id) on delete cascade,
    exercise_id  text not null,
    rest_seconds integer not null default 0,
    position     integer not null default 0
);

create index if not exists logged_exercises_workout_idx
    on public.logged_exercises (workout_id);

-- MARK: Séries de musculation

create table if not exists public.strength_sets (
    id                  uuid primary key,
    logged_exercise_id  uuid not null references public.logged_exercises (id) on delete cascade,
    user_id             uuid not null references auth.users (id) on delete cascade,
    reps                integer not null,
    weight              numeric(6, 2) not null,
    is_done             boolean not null default false,
    position            integer not null default 0
);

create index if not exists strength_sets_exercise_idx
    on public.strength_sets (logged_exercise_id);

-- MARK: Cycles de cardio
-- Un cycle = une durée et une vitesse. C'est ce qui permet de lire un HIIT
-- comme une alternance effort / récupération plutôt qu'un bloc de minutes.

create table if not exists public.cardio_phases (
    id                  uuid primary key,
    logged_exercise_id  uuid not null references public.logged_exercises (id) on delete cascade,
    user_id             uuid not null references auth.users (id) on delete cascade,
    -- Repos, Récupération, Accélération ou Sprint.
    kind                text not null,
    seconds             integer not null,
    speed               numeric(5, 2) not null,
    incline             numeric(4, 1) not null default 0,
    -- Les phases d'un même cycle partagent cet index.
    cycle_index         integer not null default 0,
    position            integer not null default 0
);

create index if not exists cardio_phases_exercise_idx
    on public.cardio_phases (logged_exercise_id, cycle_index, position);

-- MARK: Synthèses IA
-- On mémorise chaque synthèse pour ne pas rappeler le modèle à chaque
-- affichage de l'onglet Progrès.

create table if not exists public.syntheses (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references auth.users (id) on delete cascade,
    week_start   date not null,
    content      text not null,
    created_at   timestamptz not null default now(),
    unique (user_id, week_start)
);

-- MARK: Row Level Security
-- Chaque ligne n'est visible et modifiable que par son propriétaire. L'app
-- s'authentifie en anonyme au premier lancement : pas d'écran de connexion,
-- mais un vrai auth.uid() derrière lequel verrouiller les données.

alter table public.workouts          enable row level security;
alter table public.logged_exercises  enable row level security;
alter table public.strength_sets     enable row level security;
alter table public.cardio_phases     enable row level security;
alter table public.syntheses         enable row level security;

do $$
declare
    t text;
begin
    foreach t in array array['workouts', 'logged_exercises', 'strength_sets',
                             'cardio_phases', 'syntheses']
    loop
        execute format(
            'drop policy if exists %I on public.%I', t || '_owner', t
        );
        execute format(
            'create policy %I on public.%I
                 for all
                 to authenticated
                 using (user_id = (select auth.uid()))
                 with check (user_id = (select auth.uid()))',
            t || '_owner', t
        );
    end loop;
end $$;
