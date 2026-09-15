-- ════════════════════════════════════════════════════════════════════════
-- LA PISCINE RELUE, LE REPOS HORS DE L'EFFORT — 15-09, cardio (PLAN-ECONOMIE-CARDIO.md §4 (2),
-- PLAN-CARDIO.md §3.E)
--
-- ① `seances_depuis` rend `piscine {longueurs, metres_par_longueur, metres}` par exercice (null
--    sans longueurs) : un téléphone neuf retrouve ses longueurs comme ses séries. Même signature,
--    mêmes clés + une par exercice ; SupabaseSync.relire les lit en optionnel (session cardio).
-- ② `effort_seance` (la jauge d'intensité du calendrier : volume + 20 kg-équivalent la minute de
--    cardio) ignore les segments `Repos` (vitesse 0, l'arrêt entre deux sets, écrit depuis le
--    double galet) — une minute d'arrêt n'est pas une minute d'effort. Les récups à 9 km/h
--    restent des minutes de cardio (elles courent).
-- Définitions vivantes relues par pg_get_functiondef avant modification (15-09).
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.seances_depuis(p_depuis timestamptz default null, p_limite integer default 200)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_limite integer := greatest(least(coalesce(p_limite, 200), 500), 1);
  v_total integer;
  v_seances jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;

  select count(*) into v_total
    from public.workouts w
   where w.user_id = v_uid
     and (p_depuis is null or coalesce(w.ended_at, w.started_at, w.created_at) > p_depuis);

  select coalesce(jsonb_agg(s.seance order by s.started_at), '[]'::jsonb) into v_seances
    from (
      select w.started_at,
             jsonb_build_object(
               'id',         w.id,
               'started_at', w.started_at,
               'ended_at',   w.ended_at,
               'notes',      w.notes,
               'created_at', w.created_at,
               'exercices',  coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'id',          e.id,
                          'exercise_id', e.exercise_id,
                          'position',    e.position,
                          'series',      coalesce((
                            select jsonb_agg(jsonb_build_object(
                                     'id', st.id, 'reps', st.reps, 'weight', st.weight, 'position', st.position)
                                   order by st.position)
                              from public.strength_sets st where st.logged_exercise_id = e.id), '[]'::jsonb),
                          'phases',      coalesce((
                            select jsonb_agg(jsonb_build_object(
                                     'id', c.id, 'kind', c.kind, 'seconds', c.seconds, 'speed', c.speed,
                                     'incline', c.incline, 'cycle_index', c.cycle_index, 'position', c.position)
                                   order by c.position)
                              from public.cardio_phases c where c.logged_exercise_id = e.id), '[]'::jsonb),
                          -- 15-09 : la piscine de l'exercice (null sans longueurs) — le pull la remet dans le téléphone
                          'piscine',     (select jsonb_build_object('longueurs', p.longueurs,
                                                                    'metres_par_longueur', p.metres_par_longueur,
                                                                    'metres', p.longueurs * p.metres_par_longueur)
                                            from public.piscine_longueurs p where p.logged_exercise_id = e.id))
                        order by e.position)
                   from public.logged_exercises e where e.workout_id = w.id), '[]'::jsonb),
               'faits',      coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'id', f.id, 'kind', f.kind, 'mesure', f.mesure, 'valeur', f.valeur,
                          'precedent', f.precedent, 'jour', f.jour, 'detail', f.detail))
                   from public.workout_facts f where f.workout_id = w.id), '[]'::jsonb)
             ) as seance
        from public.workouts w
       where w.user_id = v_uid
         and (p_depuis is null or coalesce(w.ended_at, w.started_at, w.created_at) > p_depuis)
       order by w.started_at desc
       limit v_limite
    ) s;

  return jsonb_build_object(
    'serveur_at', now(),
    'depuis',     p_depuis,
    'total',      v_total,
    'rendues',    jsonb_array_length(v_seances),
    'seances',    v_seances);
end;
$function$
;

create or replace function public.effort_seance(p_workout uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $function$
  -- ⚠️ SECURITY DEFINER contourne RLS : cette fonction DOIT filtrer elle-même
  -- sur auth.uid(), sinon n'importe quelle session lit le volume d'une autre
  -- en devinant un uuid de séance. (Trou trouvé en relecture adverse, 05-09.)
  select case when exists (select 1 from public.workouts w
                            where w.id = p_workout and w.user_id = auth.uid())
    then coalesce((select sum(s.reps * s.weight)
                   from public.strength_sets s
                   join public.logged_exercises e on e.id = s.logged_exercise_id
                   where e.workout_id = p_workout), 0)
       + coalesce((select 20 * sum(c.seconds) / 60.0
                   from public.cardio_phases c
                   join public.logged_exercises e on e.id = c.logged_exercise_id
                   where e.workout_id = p_workout
                     -- 15-09 : un arrêt écrit comme segment (kind Repos, vitesse 0) n'est pas de l'effort
                     and c.kind <> 'Repos'), 0)
    else 0 end;
$function$
;
