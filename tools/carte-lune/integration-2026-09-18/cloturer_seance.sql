CREATE OR REPLACE FUNCTION public.cloturer_seance(p_workout uuid, p_series integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end $function$
