-- ════════════════════════════════════════════════════════════════════════
-- L'OBJECTIF HEBDOMADAIRE — 05-09-2026
--
-- Verdict : « l'objectif hebdo peut être modifié dans le widget, et plus tard
-- il sera dans l'onboarding — donc ajoute ». C'est la SEULE donnée des quatre
-- widgets que l'utilisatrice ÉCRIT : tout le reste se dérive de ses séances.
--
-- Deux décisions portées ici :
--   ① Il ne va PAS dans `reward_rules`. Cette table porte les RÈGLES DU JEU,
--      les mêmes pour tout le monde (prix, taux, seuils). Une préférence par
--      personne est autre chose — d'où `user_prefs`, une ligne par compte.
--   ② Le DÉFAUT, lui, est une règle du jeu (`objectif_hebdo_defaut`) : il vaut
--      pour qui n'a jamais choisi, et il se change en une ligne le jour où
--      l'onboarding en proposera un autre.
--
-- Analyse : tools/widgets/ANALYSE-DATAS-WIDGETS.md
-- ════════════════════════════════════════════════════════════════════════

-- ── ② le défaut, règle du jeu ──────────────────────────────────────────
insert into public.reward_rules (key, value)
values ('objectif_hebdo_defaut', '5'::jsonb)
on conflict (key) do nothing;

-- ── ① la préférence, une ligne par compte ──────────────────────────────
-- La borne est LARGE (1..14) : elle protège la base, elle ne dicte pas
-- l'écran. La vitrine propose 3 à 10 — c'est un choix de design, il peut
-- bouger sans migration.
create table if not exists public.user_prefs (
  user_id        uuid primary key references auth.users (id) on delete cascade,
  objectif_hebdo integer not null default 5
                 constraint user_prefs_objectif_borne
                 check (objectif_hebdo between 1 and 14),
  updated_at     timestamptz not null default now()
);

alter table public.user_prefs enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'user_prefs'
                    and policyname = 'select own') then
    create policy "select own" on public.user_prefs
      for select using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'user_prefs'
                    and policyname = 'insert own') then
    create policy "insert own" on public.user_prefs
      for insert with check (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies
                  where schemaname = 'public' and tablename = 'user_prefs'
                    and policyname = 'update own') then
    create policy "update own" on public.user_prefs
      for update using (user_id = auth.uid()) with check (user_id = auth.uid());
  end if;
end $$;

grant select, insert, update on public.user_prefs to authenticated;

-- ── LA LECTURE : la préférence, sinon le défaut ────────────────────────
-- ⚠️ La table est déclarée AVANT la fonction qui la lit (piège ③ du skill).
create or replace function public.objectif_hebdo()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.objectif_hebdo from public.user_prefs p where p.user_id = auth.uid()),
    public.regle_num('objectif_hebdo_defaut', 5)::integer);
$$;

-- ── L'ÉCRITURE : un acte, idempotent par construction ──────────────────
-- Un objectif hors bornes est une erreur MÉTIER : 200 avec un motif, jamais
-- un raise qui deviendrait un 500 (le client ne saurait plus distinguer un
-- refus légitime d'un serveur cassé).
create or replace function public.definir_objectif(p_objectif integer)
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
  if p_objectif is null or p_objectif < 1 or p_objectif > 14 then
    return jsonb_build_object('ok', false, 'raison', 'hors_bornes',
                              'min', 1, 'max', 14,
                              'objectif', public.objectif_hebdo());
  end if;

  insert into public.user_prefs (user_id, objectif_hebdo, updated_at)
  values (v_uid, p_objectif, now())
  on conflict (user_id) do update
    set objectif_hebdo = excluded.objectif_hebdo,
        updated_at     = now();

  -- on rend le nouvel état : l'appelante vient d'écrire, elle ne doit pas
  -- avoir à re-demander pour savoir où elle en est.
  return jsonb_build_object('ok', true, 'objectif', p_objectif);
end;
$$;

grant execute on function public.objectif_hebdo()             to authenticated;
grant execute on function public.definir_objectif(integer)    to authenticated;

-- ── LA RÉGULARITÉ REND L'OBJECTIF ET CE QU'IL RESTE ────────────────────
-- Même corps qu'en 20260905090000, plus `objectif` et `reste`. On remplace
-- la fonction entière : une définition partielle n'existe pas.
create or replace function public.widget_regularite(p_fenetre text default 'semaine')
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  b record;
  v_tz text := public.fuseau_jour();
  v_uid uuid := auth.uid();
  v_faites int; v_prec int;
  v_suite int := 0; v_record int := 0;
  v_obj int;
  v_semaine timestamp;
  v_jours jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into b from public.fenetre_bornes(p_fenetre);
  v_obj := public.objectif_hebdo();

  select count(*) into v_faites from public.workouts w
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut and w.started_at < b.fin;

  select count(*) into v_prec from public.workouts w
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut_prec and w.started_at < b.fin_prec;

  v_semaine := date_trunc('week', now() at time zone v_tz);
  if not exists (select 1 from public.workouts w
                  where w.user_id = v_uid and w.ended_at is not null
                    and date_trunc('week', w.started_at at time zone v_tz) = v_semaine)
  then
    v_semaine := v_semaine - interval '7 days';
  end if;
  loop
    exit when not exists (select 1 from public.workouts w
                           where w.user_id = v_uid and w.ended_at is not null
                             and date_trunc('week', w.started_at at time zone v_tz) = v_semaine);
    v_suite := v_suite + 1;
    v_semaine := v_semaine - interval '7 days';
    exit when v_suite > 520;
  end loop;

  with sem as (
    select distinct date_trunc('week', w.started_at at time zone v_tz) s
      from public.workouts w
     where w.user_id = v_uid and w.ended_at is not null
  ), iles as (
    select s, s - (row_number() over (order by s)) * interval '7 days' as ile from sem
  )
  select coalesce(max(n), 0) into v_record
    from (select count(*) n from iles group by ile) x;

  select coalesce(jsonb_agg(j order by j->>'jour'), '[]'::jsonb) into v_jours
    from (
      select jsonb_build_object(
               'jour',      (w.started_at at time zone v_tz)::date,
               'seances',   count(*) over (partition by (w.started_at at time zone v_tz)::date),
               'effort',    round(public.effort_seance(w.id)),
               'intensite', case
                              when public.effort_seance(w.id) >= 4000 then 3
                              when public.effort_seance(w.id) >= 1500 then 2
                              else 1 end
             ) j
        from public.workouts w
       where w.user_id = v_uid and w.ended_at is not null
         and w.started_at >= b.debut and w.started_at < b.fin
    ) t;

  return jsonb_build_object(
    'fenetre',   p_fenetre,
    'debut',     b.debut,
    'fin',       b.fin,
    'faites',    v_faites,
    'objectif',  v_obj,
    -- « il reste » n'a de sens que sur la semaine : l'objectif est hebdomadaire.
    'reste',     case when p_fenetre = 'mois' then null
                      else greatest(v_obj - v_faites, 0) end,
    'precedent', v_prec,
    'delta',     v_faites - v_prec,
    'suite_semaines', v_suite,
    'record_suite',   v_record,
    'jours',     v_jours
  );
end;
$$;
