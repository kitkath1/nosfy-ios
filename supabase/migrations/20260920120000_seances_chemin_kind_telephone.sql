-- Verdict appliqué : retour TestFlight du 19-09, plan de debug § 1.3
-- (tools/production/PLAN-DEBUG-TESTFLIGHT-2026-09-20.md).
--
-- `seances_chemin()` (20260918083033:115-126) ne comptait un intervalle cardio
-- que sur `c.kind = 'effort'`. Or le téléphone pousse les libellés bruts de
-- `PhaseKind` (Nosfy/Models.swift:297-301 · SupabaseSync.swift:406) :
-- « Repos », « Récupération », « Accélération », « Sprint » — et c'est
-- `isEffort` (Accélération, Sprint) qui fait un galet côté téléphone
-- (`faitPourRoute`, Models.swift:401-405). Une séance 100 % HIIT avançait donc
-- la Route sur le téléphone et jamais au serveur : la lune répondait
-- `progression_insuffisante`. Le banc du 18-09 posait ses phases en API avec
-- 'effort', une valeur que l'app n'envoie jamais.
--
-- Ici : la MÊME définition que le téléphone — 'Sprint' et 'Accélération' sont
-- des efforts ; 'effort' reste accepté pour les lignes de banc. Le paiement
-- cardio (`pieces_cardio_seance`) ne lit pas `kind` et ne change pas.
-- DOWN (à la main) : rejouer la définition du 20260918083033:115-126.

create or replace function public.seances_chemin() returns table(id uuid,ended_at timestamptz)
language sql stable security invoker set search_path='' as $$
 select w.id,w.ended_at from public.workouts w
 where w.user_id=(select auth.uid()) and w.ended_at is not null and w.sync_complete_at is not null
 and (exists(select 1 from public.logged_exercises e join public.strength_sets s on s.logged_exercise_id=e.id
             where e.workout_id=w.id and e.user_id=w.user_id and s.user_id=w.user_id)
   or exists(select 1 from public.logged_exercises e join public.cardio_phases c on c.logged_exercise_id=e.id
             where e.workout_id=w.id and e.user_id=w.user_id and c.user_id=w.user_id
               and c.kind in ('effort','Sprint','Accélération') and c.seconds>0)
   or exists(select 1 from public.logged_exercises e join public.piscine_longueurs p on p.logged_exercise_id=e.id
             where e.workout_id=w.id and e.user_id=w.user_id and p.user_id=w.user_id and p.longueurs>0))
 order by w.ended_at,w.id
$$;
revoke all on function public.seances_chemin() from public,anon;
grant execute on function public.seances_chemin() to authenticated;
