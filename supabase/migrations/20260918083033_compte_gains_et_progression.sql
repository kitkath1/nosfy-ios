-- Compte : un instantané complet avant paiement ; progression par séance faite.
-- Les lignes strength_sets/cardio_phases sauvegardées sont les réalisations,
-- jamais les séries/phases seulement prévues. L'app filtre isDone avant envoi.
alter table public.workouts add column sync_complete_at timestamptz;
comment on column public.workouts.sync_complete_at is
  'Instantané complet reçu par synchroniser_seance ; null pour les anciennes sauvegardes partielles.';

-- Empêcher aussi le rattachement REST d'une ligne personnelle à la séance d'autrui.
create policy "parent own" on public.logged_exercises as restrictive for all to authenticated
  using (exists(select 1 from public.workouts w where w.id=workout_id and w.user_id=(select auth.uid())))
  with check (exists(select 1 from public.workouts w where w.id=workout_id and w.user_id=(select auth.uid())));
create policy "parent own" on public.strength_sets as restrictive for all to authenticated
  using (exists(select 1 from public.logged_exercises e where e.id=logged_exercise_id and e.user_id=(select auth.uid())))
  with check (exists(select 1 from public.logged_exercises e where e.id=logged_exercise_id and e.user_id=(select auth.uid())));
create policy "parent own" on public.cardio_phases as restrictive for all to authenticated
  using (exists(select 1 from public.logged_exercises e where e.id=logged_exercise_id and e.user_id=(select auth.uid())))
  with check (exists(select 1 from public.logged_exercises e where e.id=logged_exercise_id and e.user_id=(select auth.uid())));
create policy "parent own" on public.piscine_longueurs as restrictive for all to authenticated
  using (exists(select 1 from public.logged_exercises e where e.id=logged_exercise_id and e.user_id=(select auth.uid())))
  with check (exists(select 1 from public.logged_exercises e where e.id=logged_exercise_id and e.user_id=(select auth.uid())));

create function public.synchroniser_seance(p_workout jsonb, p_exercices jsonb,
  p_series jsonb, p_phases jsonb, p_piscines jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare
  u uuid := auth.uid(); w uuid := (p_workout->>'id')::uuid;
  debut timestamptz := (p_workout->>'started_at')::timestamptz;
  fin timestamptz := (p_workout->>'ended_at')::timestamptz;
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
  if exists(select 1 from jsonb_array_elements(p_series) s where (s->>'reps')::integer<0 or (s->>'weight')::float8<0)
     or exists(select 1 from jsonb_array_elements(p_phases) c where (c->>'seconds')::integer<=0) then
    raise sqlstate 'PT400' using message='travail_invalide'; end if;
  -- Ne pas déplacer un exercice ou une réalisation déjà rattachés ailleurs.
  if exists(select 1 from public.logged_exercises e join jsonb_array_elements(p_exercices) j on e.id=(j->>'id')::uuid where e.workout_id<>w)
     or exists(select 1 from public.strength_sets s join jsonb_array_elements(p_series) j on s.id=(j->>'id')::uuid where s.logged_exercise_id<>(j->>'logged_exercise_id')::uuid)
     or exists(select 1 from public.cardio_phases c join jsonb_array_elements(p_phases) j on c.id=(j->>'id')::uuid where c.logged_exercise_id<>(j->>'logged_exercise_id')::uuid) then
    raise sqlstate 'PT409' using message='identifiant_deja_rattache'; end if;
  insert into public.workouts(id,user_id,started_at,ended_at,notes)
    values(w,u,debut,fin,coalesce(p_workout->>'notes',''))
    on conflict(id) do update set started_at=excluded.started_at,ended_at=excluded.ended_at,notes=excluded.notes;
  -- L'upsert prend le verrou de séance : la clôture attend la transaction entière.
  insert into public.logged_exercises(id,user_id,workout_id,exercise_id,position)
    select x.id,u,w,x.exercise_id,x.position from jsonb_to_recordset(p_exercices) as x(id uuid,exercise_id text,position int)
    on conflict(id) do update set exercise_id=excluded.exercise_id,position=excluded.position;
  insert into public.strength_sets(id,user_id,logged_exercise_id,reps,weight,position)
    select x.id,u,x.logged_exercise_id,x.reps,x.weight,x.position
    from jsonb_to_recordset(p_series) as x(id uuid,logged_exercise_id uuid,reps int,weight float8,position int)
    on conflict(id) do update set reps=excluded.reps,weight=excluded.weight,position=excluded.position;
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
revoke all on function public.synchroniser_seance(jsonb,jsonb,jsonb,jsonb,jsonb) from public,anon;
grant execute on function public.synchroniser_seance(jsonb,jsonb,jsonb,jsonb,jsonb) to authenticated;

-- Garder l'économie existante, mais la rendre inaccessible sans la validation.
alter function public.cloturer_seance(uuid,integer) rename to cloturer_seance_validee_interne;
revoke all on function public.cloturer_seance_validee_interne(uuid,integer) from public,anon,authenticated;
create function public.cloturer_seance(p_workout uuid,p_series integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); w public.workouts; n integer; r jsonb;
begin
  if u is null then raise sqlstate 'PT401' using message='connexion_requise'; end if;
  if p_workout is null or p_series is null or p_series<0 then raise sqlstate 'PT400' using message='cloture_invalide'; end if;
  select * into w from public.workouts where id=p_workout for update;
  if not found then raise sqlstate 'PT503' using message='seance_a_synchroniser'; end if;
  if w.user_id<>u then raise sqlstate 'PT403' using message='seance_inaccessible'; end if;
  if w.ended_at is null or w.sync_complete_at is null then raise sqlstate 'PT503' using message='seance_a_synchroniser'; end if;
  if w.ended_at<w.started_at or w.ended_at>now()+interval '5 minutes' then raise sqlstate 'PT400' using message='dates_invalides'; end if;
  select count(*)::integer into n from public.strength_sets s join public.logged_exercises e on e.id=s.logged_exercise_id
    where e.workout_id=p_workout and e.user_id=u and s.user_id=u;
  -- p_series est un contrôle de complétude, jamais la source du montant.
  if n<>p_series then raise sqlstate 'PT503' using message='series_a_synchroniser'; end if;
  r:=public.cloturer_seance_validee_interne(p_workout,n);
  if r->>'booster_id' is null then r:=r||jsonb_build_object('booster_neuf',false); end if;
  return r||jsonb_build_object('series_verifiees',n);
end $$;
revoke all on function public.cloturer_seance(uuid,integer) from public,anon;
grant execute on function public.cloturer_seance(uuid,integer) to authenticated;

-- Progression : une séance complète avec du travail ; aucune avance calendaire.
create function public.seances_chemin() returns table(id uuid,ended_at timestamptz)
language sql stable security invoker set search_path='' as $$
 select w.id,w.ended_at from public.workouts w
 where w.user_id=(select auth.uid()) and w.ended_at is not null and w.sync_complete_at is not null
 and (exists(select 1 from public.logged_exercises e join public.strength_sets s on s.logged_exercise_id=e.id
             where e.workout_id=w.id and e.user_id=w.user_id and s.user_id=w.user_id)
   or exists(select 1 from public.logged_exercises e join public.cardio_phases c on c.logged_exercise_id=e.id
             where e.workout_id=w.id and e.user_id=w.user_id and c.user_id=w.user_id and c.kind='effort' and c.seconds>0)
   or exists(select 1 from public.logged_exercises e join public.piscine_longueurs p on p.logged_exercise_id=e.id
             where e.workout_id=w.id and e.user_id=w.user_id and p.user_id=w.user_id and p.longueurs>0))
 order by w.ended_at,w.id
$$;
revoke all on function public.seances_chemin() from public,anon;
grant execute on function public.seances_chemin() to authenticated;

alter function public.tirer_noeud_chemin(integer,boolean) rename to tirer_noeud_chemin_valide_interne;
revoke all on function public.tirer_noeud_chemin_valide_interne(integer,boolean) from public,anon,authenticated;
create function public.tirer_noeud_chemin(p_noeud integer,p_pieces boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare n integer; seuil integer;
begin
 if auth.uid() is null then raise sqlstate 'PT401' using message='connexion_requise'; end if;
 if p_noeud is null or p_noeud<0 or p_noeud>=45 or p_noeud%9 not in (3,8) then
   raise sqlstate 'PT400' using message='noeud_invalide'; end if;
 -- Un ancien claim reste rejouable ; aucun nouveau droit n'est inventé.
 if not exists(select 1 from public.noeuds_chemin_reclames() r where r.noeud_id=p_noeud) then
   select count(*) into n from public.seances_chemin();
   seuil:=(p_noeud/9)*7+case when p_noeud%9=3 then 3 else 7 end;
   if n<seuil then raise sqlstate 'PT409' using message='progression_insuffisante'; end if;
 end if;
 return public.tirer_noeud_chemin_valide_interne(p_noeud,p_pieces);
end $$;
revoke all on function public.tirer_noeud_chemin(integer,boolean) from public,anon;
grant execute on function public.tirer_noeud_chemin(integer,boolean) to authenticated;
revoke all on function public.noeuds_chemin_reclames() from public,anon;
grant execute on function public.noeuds_chemin_reclames() to authenticated;

-- Inclure les sauvegardes tardives dans le pull incrémental.
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
