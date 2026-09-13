-- ════════════════════════════════════════════════════════════════════════
-- LA LECTURE DES SÉANCES — la moitié serveur du « pull » qui manque (13-09 soir,
-- Kathryn : « fais le reste pour que tout soit vert dans la partie backend »).
--
-- Depuis le 29-08 le site le dit : `SupabaseSync` n'a QU'UN `push` — un téléphone neuf
-- ne retrouve jamais ses séances (b-sy-jamais-ecrit, b-ux-home-phrase). Voici ce que
-- l'app lira : `seances_depuis(p_depuis, p_limite)` rend L'ARBRE COMPLET des séances
-- de la personne — workouts → logged_exercises → strength_sets / cardio_phases, et les
-- workout_facts de chaque séance — avec les MÊMES ids (uuid) que le téléphone a
-- poussés, pour qu'un pull ne crée jamais de doublon.
--
--  · p_depuis null → tout (borné par p_limite, 200 par défaut, 500 au plus), les plus
--    récentes d'abord ; sinon les séances dont ended_at (ou started_at) est postérieur
--    → la lecture incrémentale ; `serveur_at` est l'horloge à garder pour le prochain
--    appel.
--  · `total` = le compte SANS la limite : l'app sait s'il en reste.
--  · sans session → {erreur: sans_session} ; anon révoqué.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.seances_depuis(
  p_depuis timestamptz default null,
  p_limite integer default 200)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
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
                              from public.cardio_phases c where c.logged_exercise_id = e.id), '[]'::jsonb))
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
$$;
revoke execute on function public.seances_depuis(timestamptz, integer) from public, anon;
grant  execute on function public.seances_depuis(timestamptz, integer) to authenticated;
comment on function public.seances_depuis(timestamptz, integer) is
  'La moitié serveur du pull (13-09) : l''arbre complet des séances de la personne (workouts → logged_exercises → strength_sets / cardio_phases, + workout_facts), mêmes uuid que le téléphone a poussés. p_depuis null = tout (p_limite, ≤ 500) ; sinon les séances finies (ou commencées) après. total = sans la limite ; serveur_at = l''horloge du prochain appel.';
