-- ════════════════════════════════════════════════════════════════════════
-- LE TEMPS D'UNE SÉRIE, AU SERVEUR — 30-09-2026 (retours TestFlight 85)
--
-- Verdict de Kathryn, 30-09 : « je ne rentre pas de kilos lors de la saisie,
-- je mets que le nombre de reps : crunch au sol et toucher de chevilles ;
-- gainage, c'est que le temps — un chrono qui commence avec 1, 2, 3, GO, et
-- le cadran ». Plan : tools/production/PLAN-RETOURS-TESTFLIGHT-85-2026-09-30.md,
-- étape 3.
--
-- LE DÉFAUT LU : strength_sets n'avait que reps et weight (0001_init.sql:43-44).
-- Le chrono d'une série (StrengthSet.durationSeconds) restait au téléphone : le
-- temps d'un gainage n'existait pas au serveur, et une réinstallation le perdait.
--
-- ① strength_sets.duree_s : les secondes sous tension de la série. 0 pour toutes
--    les séries d'avant, et pour un client qui ne l'envoie pas encore.
-- ② synchroniser_seance : la fonction de 20260920160000, À LA LETTRE, plus
--    duree_s (absente du payload → 0 ; négative → travail_invalide).
-- ③ seances_depuis : la fonction de 20260918083033, À LA LETTRE, plus duree_s
--    dans chaque série — le pull la remet dans le téléphone.
--
-- Rien ne touche l'argent : cloturer_seance compte les LIGNES sauvegardées (une
-- série de gainage à 0 rep est une série faite), et les pics de charge des
-- widgets filtrent déjà weight > 0 (le poids du corps n'y entre pas).
-- ════════════════════════════════════════════════════════════════════════

-- ① la colonne, AVANT les fonctions qui s'en servent.
alter table public.strength_sets
  add column if not exists duree_s integer not null default 0 check (duree_s >= 0);
comment on column public.strength_sets.duree_s is
  'Les secondes sous tension de la série (le chrono du cadran). Seule mesure d''un exercice au temps seul (gainage) ; 0 quand la série n''a pas été chronométrée ou vient d''un client d''avant le 30-09.';

-- ② synchroniser_seance : 20260920160000 + duree_s.
create or replace function public.synchroniser_seance(p_workout jsonb, p_exercices jsonb,
  p_series jsonb, p_phases jsonb, p_piscines jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare
  u uuid := auth.uid(); w uuid := (p_workout->>'id')::uuid;
  debut timestamptz := (p_workout->>'started_at')::timestamptz;
  fin timestamptz := (p_workout->>'ended_at')::timestamptz;
  -- LE FUSEAU DU TÉLÉPHONE (20-09) : le jour local de la séance, pour le plafond du jour.
  fz text := nullif(p_workout->>'fuseau','');
begin
  if u is null then raise sqlstate 'PT401' using message='connexion_requise'; end if;
  if w is null or debut is null or fin is null or fin<debut or fin>now()+interval '5 minutes' then
    raise sqlstate 'PT400' using message='seance_invalide'; end if;
  if jsonb_typeof(p_exercices) is distinct from 'array' or jsonb_typeof(p_series) is distinct from 'array'
     or jsonb_typeof(p_phases) is distinct from 'array' or jsonb_typeof(p_piscines) is distinct from 'array' then
    raise sqlstate 'PT400' using message='instantane_invalide'; end if;
  if jsonb_array_length(p_exercices)>200 or jsonb_array_length(p_series)>2000
     or jsonb_array_length(p_phases)>5000 or jsonb_array_length(p_piscines)>200 then
    raise sqlstate 'PT400' using message='instantane_trop_grand'; end if;
  -- Les relations du payload doivent décrire CET arbre, sans ids dédoublés.
  if exists(select 1 from jsonb_array_elements(p_exercices) e where (e->>'workout_id')::uuid is distinct from w)
     or exists(select 1 from jsonb_array_elements(p_series||p_phases||p_piscines) c
       where not exists(select 1 from jsonb_array_elements(p_exercices) e where e->>'id'=c->>'logged_exercise_id'))
     or exists(select 1 from jsonb_array_elements(p_exercices) e group by e->>'id' having count(*)>1)
     or exists(select 1 from jsonb_array_elements(p_series) s group by s->>'id' having count(*)>1)
     or exists(select 1 from jsonb_array_elements(p_phases) c group by c->>'id' having count(*)>1) then
    raise sqlstate 'PT400' using message='relations_invalides'; end if;
  if exists(select 1 from jsonb_array_elements(p_series) s where (s->>'reps')::integer<0 or (s->>'weight')::float8<0
            or coalesce((s->>'duree_s')::integer,0)<0)
     or exists(select 1 from jsonb_array_elements(p_phases) c where (c->>'seconds')::integer<=0) then
    raise sqlstate 'PT400' using message='travail_invalide'; end if;
  -- Ne pas déplacer un exercice ou une réalisation déjà rattachés ailleurs.
  if exists(select 1 from public.logged_exercises e join jsonb_array_elements(p_exercices) j on e.id=(j->>'id')::uuid where e.workout_id<>w)
     or exists(select 1 from public.strength_sets s join jsonb_array_elements(p_series) j on s.id=(j->>'id')::uuid where s.logged_exercise_id<>(j->>'logged_exercise_id')::uuid)
     or exists(select 1 from public.cardio_phases c join jsonb_array_elements(p_phases) j on c.id=(j->>'id')::uuid where c.logged_exercise_id<>(j->>'logged_exercise_id')::uuid) then
    raise sqlstate 'PT409' using message='identifiant_deja_rattache'; end if;
  -- Un fuseau inconnu ne casse rien : il est ignoré, le jour de la maison prend le relais.
  if fz is not null then
    begin perform now() at time zone fz; exception when others then fz := null; end;
  end if;
  insert into public.workouts as wk(id,user_id,started_at,ended_at,notes,fuseau)
    values(w,u,debut,fin,coalesce(p_workout->>'notes',''),fz)
    on conflict(id) do update set started_at=excluded.started_at,ended_at=excluded.ended_at,notes=excluded.notes,
      fuseau=coalesce(excluded.fuseau,wk.fuseau);
  -- L'upsert prend le verrou de séance : la clôture attend la transaction entière.
  insert into public.logged_exercises(id,user_id,workout_id,exercise_id,position)
    select x.id,u,w,x.exercise_id,x.position from jsonb_to_recordset(p_exercices) as x(id uuid,exercise_id text,position int)
    on conflict(id) do update set exercise_id=excluded.exercise_id,position=excluded.position;
  -- 30-09 : le temps de la série (absent d'un client d'avant → 0).
  insert into public.strength_sets(id,user_id,logged_exercise_id,reps,weight,position,duree_s)
    select x.id,u,x.logged_exercise_id,x.reps,x.weight,x.position,coalesce(x.duree_s,0)
    from jsonb_to_recordset(p_series) as x(id uuid,logged_exercise_id uuid,reps int,weight float8,position int,duree_s int)
    on conflict(id) do update set reps=excluded.reps,weight=excluded.weight,position=excluded.position,duree_s=excluded.duree_s;
  insert into public.cardio_phases(id,user_id,logged_exercise_id,kind,seconds,speed,incline,cycle_index,position)
    select x.id,u,x.logged_exercise_id,x.kind,x.seconds,x.speed,x.incline,x.cycle_index,x.position
    from jsonb_to_recordset(p_phases) as x(id uuid,logged_exercise_id uuid,kind text,seconds int,speed float8,incline float8,cycle_index int,position int)
    on conflict(id) do update set kind=excluded.kind,seconds=excluded.seconds,speed=excluded.speed,incline=excluded.incline,cycle_index=excluded.cycle_index,position=excluded.position;
  insert into public.piscine_longueurs(logged_exercise_id,user_id,longueurs,metres_par_longueur)
    select x.logged_exercise_id,u,x.longueurs,x.metres_par_longueur
    from jsonb_to_recordset(p_piscines) as x(logged_exercise_id uuid,longueurs int,metres_par_longueur int)
    on conflict(logged_exercise_id) do update set longueurs=excluded.longueurs,metres_par_longueur=excluded.metres_par_longueur;
  -- Remplacer l'instantané de CETTE séance ; conserver tous les autres comptes.
  delete from public.strength_sets s using public.logged_exercises e
    where s.logged_exercise_id=e.id and e.workout_id=w and not exists(select 1 from jsonb_array_elements(p_series) j where (j->>'id')::uuid=s.id);
  delete from public.cardio_phases c using public.logged_exercises e
    where c.logged_exercise_id=e.id and e.workout_id=w and not exists(select 1 from jsonb_array_elements(p_phases) j where (j->>'id')::uuid=c.id);
  delete from public.piscine_longueurs p using public.logged_exercises e
    where p.logged_exercise_id=e.id and e.workout_id=w and not exists(select 1 from jsonb_array_elements(p_piscines) j where (j->>'logged_exercise_id')::uuid=p.logged_exercise_id);
  delete from public.logged_exercises e where e.workout_id=w
    and not exists(select 1 from jsonb_array_elements(p_exercices) j where (j->>'id')::uuid=e.id);
  update public.workouts set sync_complete_at=clock_timestamp() where id=w;
  return jsonb_build_object('ok',true,'workout_id',w,'series',jsonb_array_length(p_series),'phases',jsonb_array_length(p_phases));
end $$;

-- ③ seances_depuis : 20260918083033 + duree_s dans chaque série.
CREATE OR REPLACE FUNCTION public.seances_depuis(p_depuis timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limite integer DEFAULT 200)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
     and (p_depuis is null or greatest(w.sync_complete_at, w.ended_at, w.started_at, w.created_at) > p_depuis);

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
                                     'id', st.id, 'reps', st.reps, 'weight', st.weight, 'position', st.position,
                                     -- 30-09 : le temps de la série, remis au téléphone par le pull
                                     'duree_s', st.duree_s)
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
         and (p_depuis is null or greatest(w.sync_complete_at, w.ended_at, w.started_at, w.created_at) > p_depuis)
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
