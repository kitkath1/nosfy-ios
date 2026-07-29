-- Schéma Woop : sauvegarde des séances poussées par SupabaseSync.swift.
-- Chaque ligne appartient à un utilisateur anonyme (auth.uid()) et le RLS
-- garantit qu'un appareil ne voit et ne modifie que ses propres données.

-- MARK: Tables

create table public.workouts (
    id uuid primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    started_at timestamptz not null,
    ended_at timestamptz,
    notes text not null default '',
    created_at timestamptz not null default now()
);

create table public.logged_exercises (
    id uuid primary key,
    workout_id uuid not null references public.workouts (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade,
    exercise_id text not null,
    position integer not null,
    created_at timestamptz not null default now()
);

create table public.strength_sets (
    id uuid primary key,
    logged_exercise_id uuid not null references public.logged_exercises (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade,
    reps integer not null,
    weight double precision not null,
    position integer not null,
    created_at timestamptz not null default now()
);

create table public.cardio_phases (
    id uuid primary key,
    logged_exercise_id uuid not null references public.logged_exercises (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade,
    kind text not null,
    seconds integer not null,
    speed double precision not null,
    incline double precision not null default 0,
    cycle_index integer not null default 0,
    position integer not null,
    created_at timestamptz not null default now()
);

-- MARK: Index sur les clés étrangères

create index workouts_user_id_idx on public.workouts (user_id);
create index logged_exercises_workout_id_idx on public.logged_exercises (workout_id);
create index logged_exercises_user_id_idx on public.logged_exercises (user_id);
create index strength_sets_logged_exercise_id_idx on public.strength_sets (logged_exercise_id);
create index strength_sets_user_id_idx on public.strength_sets (user_id);
create index cardio_phases_logged_exercise_id_idx on public.cardio_phases (logged_exercise_id);
create index cardio_phases_user_id_idx on public.cardio_phases (user_id);

-- MARK: Row Level Security
-- L'upsert de l'app (insert + merge-duplicates) exige select, insert et update.
-- delete est prévu pour une future suppression de séance depuis l'app.

alter table public.workouts enable row level security;
alter table public.logged_exercises enable row level security;
alter table public.strength_sets enable row level security;
alter table public.cardio_phases enable row level security;

do $$
declare
    t text;
begin
    foreach t in array array['workouts', 'logged_exercises', 'strength_sets', 'cardio_phases']
    loop
        execute format($f$
            create policy "select own" on public.%I
                for select to authenticated
                using ((select auth.uid()) = user_id);

            create policy "insert own" on public.%I
                for insert to authenticated
                with check ((select auth.uid()) = user_id);

            create policy "update own" on public.%I
                for update to authenticated
                using ((select auth.uid()) = user_id)
                with check ((select auth.uid()) = user_id);

            create policy "delete own" on public.%I
                for delete to authenticated
                using ((select auth.uid()) = user_id);
        $f$, t, t, t, t);
    end loop;
end $$;
