-- LE BANC DES SÉRIES PAR FENÊTRE (22-09) — exécuté ENTIER dans BEGIN / ROLLBACK par
-- tools/widgets/series-2026-09-22/verif_series_fenetre.py, sur la base vivante, sous l'identité
-- d'un compte inventé le temps de la transaction. Rien ne reste.
--
-- Il vérifie widget_regularite(series, series_precedent, series_delta) telle que la chambre la
-- lira : une ligne de strength_sets = une série faite (même à 0 rép), comptée à la FIN de la
-- séance, sur la fenêtre Semaine (lundi → maintenant, la précédente au même temps écoulé) et
-- la fenêtre Mois (30 jours glissants) ; le cardio ne compte pas ; le vide rend des zéros.
create temp table qa_resultats(rang serial, nom text, ok boolean, detail text) on commit drop;

-- une séance de musculation : p_series séries (la première à 0 rép si p_zero), finie il y a p_il_y_a
create function pg_temp.muscu(p_u uuid, p_il_y_a interval, p_series int, p_zero boolean, p_duree interval default interval '12 minutes') returns jsonb
language plpgsql as $f$
declare w uuid := gen_random_uuid(); e uuid := gen_random_uuid(); fin timestamptz := now() - p_il_y_a;
        se jsonb := '[]'; i int;
begin
  for i in 0..p_series-1 loop
    se := se || jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'user_id',p_u,'logged_exercise_id',e,
             'reps', case when p_zero and i = 0 then 0 else 10 end,'weight',20,'position',i));
  end loop;
  return public.synchroniser_seance(
    jsonb_build_object('id',w,'user_id',p_u,'started_at',fin - p_duree,'ended_at',fin,'notes','QA séries','fuseau','Europe/Paris'),
    jsonb_build_array(jsonb_build_object('id',e,'user_id',p_u,'workout_id',w,'exercise_id','hip-thrust','position',0)),
    se, '[]'::jsonb, '[]'::jsonb);
end $f$;

-- une séance 100 % cardio : deux sprints, aucune série
create function pg_temp.cardio(p_u uuid, p_il_y_a interval) returns jsonb
language plpgsql as $f$
declare w uuid := gen_random_uuid(); e uuid := gen_random_uuid(); fin timestamptz := now() - p_il_y_a;
begin
  return public.synchroniser_seance(
    jsonb_build_object('id',w,'user_id',p_u,'started_at',fin - interval '10 minutes','ended_at',fin,'notes','QA cardio','fuseau','Europe/Paris'),
    jsonb_build_array(jsonb_build_object('id',e,'user_id',p_u,'workout_id',w,'exercise_id','tapis','position',0)),
    '[]'::jsonb,
    jsonb_build_array(
      jsonb_build_object('id',gen_random_uuid(),'logged_exercise_id',e,'kind','Sprint','seconds',60,'speed',16,'incline',0,'cycle_index',0,'position',0),
      jsonb_build_object('id',gen_random_uuid(),'logged_exercise_id',e,'kind','Repos','seconds',60,'speed',5,'incline',0,'cycle_index',0,'position',1)),
    '[]'::jsonb);
end $f$;

create function pg_temp.note(p_nom text, p_ok boolean, p_detail text default null) returns void
language sql as $n$ insert into qa_resultats(nom, ok, detail) values (p_nom, p_ok, p_detail); $n$;

do $$
declare
  u uuid := gen_random_uuid();
  s jsonb; m jsonb; b record;
  ecoule interval;
begin
  insert into auth.users(id) values (u);
  perform set_config('request.jwt.claim.sub', u::text, true);
  select * into b from public.fenetre_bornes('semaine');
  ecoule := now() - b.debut;   -- le temps écoulé depuis lundi 00:00 (fuseau du compte)

  -- 0. LE VIDE : des zéros, jamais un null
  s := public.widget_regularite('semaine'); m := public.widget_regularite('mois');
  perform pg_temp.note('vide · semaine : series 0, series_precedent 0, series_delta 0',
            (s->>'series')::int = 0 and (s->>'series_precedent')::int = 0 and (s->>'series_delta')::int = 0,
            (s->>'series') || ' / ' || (s->>'series_precedent') || ' / ' || (s->>'series_delta'));
  perform pg_temp.note('vide · mois : series 0, series_precedent 0',
            (m->>'series')::int = 0 and (m->>'series_precedent')::int = 0, m->>'series');
  perform pg_temp.note('vide · aucune des trois clés n''est null',
            (s ? 'series') and (s ? 'series_precedent') and (s ? 'series_delta')
            and jsonb_typeof(s->'series') = 'number' and jsonb_typeof(s->'series_precedent') = 'number');

  -- 1. CETTE SEMAINE : 8 séries (dont une à 0 rép) + 5 séries + une séance cardio seule
  perform pg_temp.muscu(u, interval '3 hours', 8, true);
  perform pg_temp.muscu(u, interval '30 minutes', 5, false);
  perform pg_temp.cardio(u, interval '20 minutes');
  s := public.widget_regularite('semaine');
  perform pg_temp.note('semaine : 13 séries (8 + 5 ; la série à 0 rép compte ; le cardio ne compte pas)',
            (s->>'series')::int = 13, s->>'series');
  perform pg_temp.note('semaine : 3 séances faites (le compte des séances ne bouge pas)',
            (s->>'faites')::int = 3, s->>'faites');
  perform pg_temp.note('semaine : series_precedent 0 sans historique, delta +13',
            (s->>'series_precedent')::int = 0 and (s->>'series_delta')::int = 13,
            (s->>'series_precedent') || ' / ' || (s->>'series_delta'));

  -- 2. LA SEMAINE D'AVANT, bornée au MÊME temps écoulé : une séance de 4 séries finie
  --    il y a 7 jours + 2 h compte ; une de 6 séries finie il y a 7 jours − 1 h (après la
  --    borne) ne compte PAS. (Le banc exige au moins 2 h écoulées depuis lundi 00:00.)
  if ecoule < interval '2 hours 30 minutes' then
    perform pg_temp.note('semaine d''avant : banc rejoué trop tôt dans la semaine (< 2 h 30 depuis lundi)', false, ecoule::text);
  else
    perform pg_temp.muscu(u, interval '7 days 2 hours', 4, false);
    perform pg_temp.muscu(u, interval '7 days' - interval '1 hour', 6, false);
    s := public.widget_regularite('semaine');
    perform pg_temp.note('semaine d''avant au même temps écoulé : 4 séries (la séance d''après la borne exclue)',
              (s->>'series_precedent')::int = 4, s->>'series_precedent');
    perform pg_temp.note('semaine : delta = 13 − 4 = 9', (s->>'series_delta')::int = 9, s->>'series_delta');
    perform pg_temp.note('semaine : precedent (séances) = 1, la même borne', (s->>'precedent')::int = 1, s->>'precedent');
  end if;

  -- 3. LA DATE DE FIN : une séance commencée il y a 7 jours + 5 min et FINIE il y a 7 jours − 5 min
  --    (à cheval sur la borne fin_prec) — les séries suivent la fin (hors fenêtre d'avant),
  --    la séance suit le début (dans la fenêtre d'avant) : le litige du site, mesuré.
  perform pg_temp.muscu(u, interval '7 days' - interval '5 minutes', 3, false, interval '10 minutes');
  s := public.widget_regularite('semaine');
  perform pg_temp.note('à cheval sur la borne : ses 3 séries NE comptent PAS dans series_precedent (fin après la borne)',
            (s->>'series_precedent')::int = 4, s->>'series_precedent');
  perform pg_temp.note('à cheval sur la borne : la séance, elle, compte dans precedent (début avant la borne) — le litige',
            (s->>'precedent')::int = 2, s->>'precedent');

  -- 4. LE MOIS : 30 jours glissants ; il y a 29 jours compte, il y a 31 jours va dans le mois d'avant
  perform pg_temp.muscu(u, interval '29 days', 7, false);
  perform pg_temp.muscu(u, interval '31 days', 9, false);
  perform pg_temp.muscu(u, interval '61 days', 2, false);   -- hors des deux fenêtres
  m := public.widget_regularite('mois');
  perform pg_temp.note('mois : 13 + 4 + 6 + 3 + 7 = 33 séries (tout ce qui a fini depuis 30 jours)',
            (m->>'series')::int = 33, m->>'series');
  perform pg_temp.note('mois d''avant : 9 séries (il y a 31 jours ; il y a 61 jours est hors fenêtre)',
            (m->>'series_precedent')::int = 9, m->>'series_precedent');
  perform pg_temp.note('mois : delta 24', (m->>'series_delta')::int = 24, m->>'series_delta');

  -- 5. Les clés d'avant sont toujours là (rien retiré, rien renommé)
  perform pg_temp.note('les clés du 13-09 sont intactes',
            (s ? 'faites') and (s ? 'precedent') and (s ? 'delta') and (s ? 'objectif') and (s ? 'reste')
            and (s ? 'suite_semaines') and (s ? 'record_suite') and (s ? 'jours') and (s ? 'defi') and (s ? 'debut') and (s ? 'fin'));

  -- 6. Un AUTRE compte ne voit rien de tout ça
  perform set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
  s := public.widget_regularite('semaine');
  perform pg_temp.note('un compte étranger lit 0 série', (s->>'series')::int = 0 and (s->>'series_precedent')::int = 0, s->>'series');
end $$;

select nom, ok, detail from qa_resultats order by rang;
