-- ════════════════════════════════════════════════════════════════════════
-- L'ESCALIER N'EST PAS UN SPRINT — 15-09, chantier Widgets
--
-- La « vitesse » d'une phase d'escalier est un NIVEAU de machine (1-15), pas des km/h
-- (Models.swift, `SemaineStats.hiitPeak` l'exclut depuis le 05-09). Mesuré sur la définition
-- vivante de widget_hiit (pg_get_functiondef, 15-09) : l'escalier n'était exclu que des quatre
-- semaines du record (`pics4`) — pas du pic, des efforts, du temps de pics, de la récup, des
-- segments ni du trou. Un palier 15 comptait comme un sprint à 15 km/h, et la chambre HIIT
-- aurait dessiné un escalier en segments d'effort. `calculer_faits_seance` (20260915120000)
-- avait le même trou dans sa partie cardio (top_cardio).
--
-- Même signature, mêmes clés, même repli : aucun appelant ne bouge. Le téléphone
-- (SemaineStats, ChambreDonnees) exclut déjà `ex.exerciseID == "escalier"` : les deux comptent
-- enfin pareil — c'est ce que tools/serveur/verif_widgets.py vérifie.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.widget_hiit(p_fenetre text default 'semaine')
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  b record;
  v_uid uuid := auth.uid();
  v_seuil numeric := public.regle_num('seuil_effort_kmh', 15.0);
  v_pic numeric; v_efforts int; v_temps int; v_moy numeric;
  v_pic_p numeric; v_efforts_p int; v_temps_p int;
  v_recup int; v_seances jsonb;
  v_pics4 jsonb; v_recup_moy int; v_recup_moy_p int; v_trou int; v_trou_p int;
  v_semaine0 timestamp;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into b from public.fenetre_bornes(p_fenetre);

  -- la fenêtre courante
  select coalesce(max(c.speed), 0), count(*), coalesce(sum(c.seconds), 0),
         coalesce(round(avg(c.speed)::numeric, 1), 0)
    into v_pic, v_efforts, v_temps, v_moy
    from public.cardio_phases c
    join public.logged_exercises e on e.id = c.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut and w.started_at < b.fin
     and (c.speed >= v_seuil and e.exercise_id <> 'escalier');

  -- la fenêtre précédente, bornée au même temps écoulé (①)
  select coalesce(max(c.speed), 0), count(*), coalesce(sum(c.seconds), 0)
    into v_pic_p, v_efforts_p, v_temps_p
    from public.cardio_phases c
    join public.logged_exercises e on e.id = c.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut_prec and w.started_at < b.fin_prec
     and (c.speed >= v_seuil and e.exercise_id <> 'escalier');

  -- le temps de récupération : tout ce qui est SOUS le seuil dans une
  -- séance qui contient au moins un effort
  select coalesce(sum(c.seconds), 0) into v_recup
    from public.cardio_phases c
    join public.logged_exercises e on e.id = c.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut and w.started_at < b.fin
     and (c.speed < v_seuil and e.exercise_id <> 'escalier')
     and exists (select 1 from public.cardio_phases c2
                  join public.logged_exercises e2 on e2.id = c2.logged_exercise_id
                 where e2.workout_id = w.id and (c2.speed >= v_seuil and e2.exercise_id <> 'escalier'));

  -- les séances de la fenêtre, chacune avec SES segments (aucun pareil)
  select coalesce(jsonb_agg(x order by x->>'debut'), '[]'::jsonb) into v_seances
    from (
      select jsonb_build_object(
               'seance_id', w.id,
               'debut',     w.started_at,
               'jour',      (w.started_at at time zone public.fuseau_jour())::date,
               'pic',       (select max(c.speed) from public.cardio_phases c
                              join public.logged_exercises e on e.id = c.logged_exercise_id
                             where e.workout_id = w.id and e.exercise_id <> 'escalier'),
               'efforts',   (select count(*) from public.cardio_phases c
                              join public.logged_exercises e on e.id = c.logged_exercise_id
                             where e.workout_id = w.id and (c.speed >= v_seuil and e.exercise_id <> 'escalier')),
               'segments',  (select coalesce(jsonb_agg(jsonb_build_object(
                                      'secondes', c.seconds, 'vitesse', c.speed,
                                      'genre', c.kind, 'cycle', c.cycle_index,
                                      'effort', (c.speed >= v_seuil and e.exercise_id <> 'escalier'))
                                      order by e.position, c.cycle_index, c.position), '[]'::jsonb)
                               from public.cardio_phases c
                               join public.logged_exercises e on e.id = c.logged_exercise_id
                              where e.workout_id = w.id and e.exercise_id <> 'escalier')
             ) x
        from public.workouts w
       where w.user_id = v_uid and w.ended_at is not null
         and w.started_at >= b.debut and w.started_at < b.fin
         and exists (select 1 from public.cardio_phases c
                      join public.logged_exercises e on e.id = c.logged_exercise_id
                     where e.workout_id = w.id and (c.speed >= v_seuil and e.exercise_id <> 'escalier'))
    ) t;

  -- 13-09 : LES QUATRE DERNIÈRES SEMAINES, S-3 → cette semaine — le pic de chacune (0 = rien couru)
  v_semaine0 := date_trunc('week', now() at time zone public.fuseau_jour());
  select jsonb_agg(coalesce(p, 0) order by k desc) into v_pics4
    from (select k, (select max(c.speed)
                       from public.cardio_phases c
                       join public.logged_exercises e on e.id = c.logged_exercise_id
                       join public.workouts w on w.id = e.workout_id
                      where w.user_id = v_uid and w.ended_at is not null and e.exercise_id <> 'escalier'
                        and (w.started_at at time zone public.fuseau_jour()) >= v_semaine0 - (k * interval '7 days')
                        and (w.started_at at time zone public.fuseau_jour()) <  v_semaine0 - ((k - 1) * interval '7 days')) p
            from generate_series(0, 3) k) t;

  -- 13-09 : la récup moyenne (les segments sous le seuil, dans les séances qui ont un effort), les deux fenêtres
  select coalesce(avg(c.seconds), 0)::int into v_recup_moy
    from public.cardio_phases c
    join public.logged_exercises e on e.id = c.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut and w.started_at < b.fin and (c.speed < v_seuil and e.exercise_id <> 'escalier')
     and exists (select 1 from public.cardio_phases c2 join public.logged_exercises e2 on e2.id = c2.logged_exercise_id
                  where e2.workout_id = w.id and (c2.speed >= v_seuil and e2.exercise_id <> 'escalier'));
  select coalesce(avg(c.seconds), 0)::int into v_recup_moy_p
    from public.cardio_phases c
    join public.logged_exercises e on e.id = c.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut_prec and w.started_at < b.fin_prec and (c.speed < v_seuil and e.exercise_id <> 'escalier')
     and exists (select 1 from public.cardio_phases c2 join public.logged_exercises e2 on e2.id = c2.logged_exercise_id
                  where e2.workout_id = w.id and (c2.speed >= v_seuil and e2.exercise_id <> 'escalier'));

  -- 13-09 : le plus long trou entre deux séances HIIT, en jours, les deux fenêtres
  select coalesce(max(d), 0) into v_trou from (
    select extract(day from (w.started_at - lag(w.started_at) over (order by w.started_at)))::int d
      from public.workouts w
     where w.user_id = v_uid and w.ended_at is not null and w.started_at >= b.debut and w.started_at < b.fin
       and exists (select 1 from public.cardio_phases c join public.logged_exercises e on e.id = c.logged_exercise_id
                    where e.workout_id = w.id and (c.speed >= v_seuil and e.exercise_id <> 'escalier'))) g;
  select coalesce(max(d), 0) into v_trou_p from (
    select extract(day from (w.started_at - lag(w.started_at) over (order by w.started_at)))::int d
      from public.workouts w
     where w.user_id = v_uid and w.ended_at is not null and w.started_at >= b.debut_prec and w.started_at < b.fin_prec
       and exists (select 1 from public.cardio_phases c join public.logged_exercises e on e.id = c.logged_exercise_id
                    where e.workout_id = w.id and (c.speed >= v_seuil and e.exercise_id <> 'escalier'))) g;

  return jsonb_build_object(
    'fenetre',        p_fenetre,
    'seuil',          v_seuil,
    'pics4',          v_pics4,
    'recup_moy',      v_recup_moy,
    'recup_moy_precedent', v_recup_moy_p,
    'plus_long_trou', v_trou,
    'plus_long_trou_precedent', v_trou_p,
    'pic',            v_pic,
    'pic_precedent',  v_pic_p,
    'efforts',        v_efforts,
    'efforts_precedent', v_efforts_p,
    'temps_pics',     v_temps,
    'temps_pics_precedent', v_temps_p,
    'vitesse_moyenne_effort', v_moy,
    'temps_recup',    v_recup,
    'ratio',          case when v_temps > 0
                           then round(v_recup::numeric / v_temps, 2) else null end,
    'seances',        v_seances
  );
end;
$function$;

-- ── calculer_faits_seance : la partie cardio, sans l'escalier ──────────────

create or replace function public.calculer_faits_seance(p_workout uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  w           record;
  v_jour      date;
  v_fenetre   integer := public.regle_num('top_fenetre_jours', 7)::integer;
  v_min       integer := public.regle_num('top_min_seances', 2)::integer;
  v_seuil     numeric := public.regle_num('seuil_effort_kmh', 15.0);
  v_avant     integer;                  -- séances finies dans la fenêtre, hors elle
  -- muscu
  v_series    numeric; v_volume numeric; v_series_p numeric; v_volume_p numeric;
  -- cardio
  v_hiit      numeric; v_vd numeric;    v_hiit_p numeric;   v_vd_p numeric;
  -- double
  v_autres    integer; v_heures jsonb;  v_minutes integer;
  v_faits     jsonb := '[]'::jsonb;
  v_range     jsonb;
  v_deja      jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('faits', '[]'::jsonb, 'raison', 'sans_session');
  end if;

  select id, started_at, ended_at into w
    from public.workouts
   where id = p_workout and user_id = v_uid and ended_at is not null;
  if not found then
    return jsonb_build_object('faits', '[]'::jsonb, 'raison', 'seance_inconnue');
  end if;

  -- Le jour de la SÉANCE, dans le fuseau de la maison (la même définition que la flamme).
  v_jour := (w.started_at at time zone public.fuseau_jour())::date;

  -- DÉJÀ ESTAMPILLÉE ? On rend le stocké, on ne recalcule jamais.
  select coalesce(jsonb_agg(jsonb_build_object(
           'kind', kind, 'mesure', mesure, 'valeur', valeur,
           'precedent', precedent, 'detail', detail) order by kind), '[]'::jsonb)
    into v_deja
    from public.workout_facts
   where user_id = v_uid and workout_id = p_workout;
  if jsonb_array_length(v_deja) > 0 then
    return jsonb_build_object('faits', v_deja, 'rejeu', true);
  end if;

  -- ── la fenêtre : les séances finies d'AVANT, hors elle-même ───────────
  select count(*) into v_avant
    from public.workouts
   where user_id = v_uid and ended_at is not null and id <> p_workout
     and started_at >= w.started_at - make_interval(days => v_fenetre)
     and started_at <  w.started_at;

  if v_avant + 1 >= v_min then
    -- ── muscu : séries faites et volume de CETTE séance ─────────────────
    select count(s.id), coalesce(sum(s.reps * s.weight), 0)
      into v_series, v_volume
      from public.strength_sets s
      join public.logged_exercises e on e.id = s.logged_exercise_id
     where e.workout_id = p_workout and s.user_id = v_uid;
    -- … et le MEILLEUR des séances d'avant, mesure par mesure
    select coalesce(max(x.series), 0), coalesce(max(x.volume), 0)
      into v_series_p, v_volume_p
      from (select w2.id,
                   count(s.id)                          as series,
                   coalesce(sum(s.reps * s.weight), 0)  as volume
              from public.workouts w2
              join public.logged_exercises e on e.workout_id = w2.id
              join public.strength_sets s on s.logged_exercise_id = e.id
             where w2.user_id = v_uid and w2.ended_at is not null and w2.id <> p_workout
               and w2.started_at >= w.started_at - make_interval(days => v_fenetre)
               and w2.started_at <  w.started_at
             group by w2.id) x;
    -- un précédent DANS LA MÊME DISCIPLINE : une première séance de fonte au milieu
    -- d'une semaine de tapis ne « bat » rien (se dépasser suppose un précédent)
    if v_series > 0 and v_series_p > 0 and (v_series > v_series_p or v_volume > v_volume_p) then
      -- la mesure la mieux battue, en proportion ; un précédent à 0 vaut « première fois » = infini
      if (v_volume > v_volume_p and (v_series <= v_series_p
           or (v_volume / greatest(v_volume_p, 1)) >= (v_series / greatest(v_series_p, 1)))) then
        v_faits := v_faits || jsonb_build_object('kind', 'top_muscu', 'mesure', 'volume_kg',
                                                 'valeur', round(v_volume, 1), 'precedent', round(v_volume_p, 1));
      else
        v_faits := v_faits || jsonb_build_object('kind', 'top_muscu', 'mesure', 'series',
                                                 'valeur', v_series, 'precedent', v_series_p);
      end if;
    end if;

    -- ── cardio : temps d'effort et « vitesse × durée » de CETTE séance ──
    select coalesce(sum(c.seconds), 0), coalesce(max(c.speed * c.seconds), 0)
      into v_hiit, v_vd
      from public.cardio_phases c
      join public.logged_exercises e on e.id = c.logged_exercise_id
     where e.workout_id = p_workout and c.user_id = v_uid and c.speed >= v_seuil
       and e.exercise_id <> 'escalier';
    select coalesce(max(x.hiit), 0), coalesce(max(x.vd), 0)
      into v_hiit_p, v_vd_p
      from (select w2.id,
                   coalesce(sum(c.seconds), 0)            as hiit,
                   coalesce(max(c.speed * c.seconds), 0)  as vd
              from public.workouts w2
              join public.logged_exercises e on e.workout_id = w2.id
              join public.cardio_phases c on c.logged_exercise_id = e.id and c.speed >= v_seuil
                                          and e.exercise_id <> 'escalier'
             where w2.user_id = v_uid and w2.ended_at is not null and w2.id <> p_workout
               and w2.started_at >= w.started_at - make_interval(days => v_fenetre)
               and w2.started_at <  w.started_at
             group by w2.id) x;
    if v_hiit > 0 and v_hiit_p > 0 and (v_hiit > v_hiit_p or v_vd > v_vd_p) then
      if (v_vd > v_vd_p and (v_hiit <= v_hiit_p
           or (v_vd / greatest(v_vd_p, 1)) >= (v_hiit / greatest(v_hiit_p, 1)))) then
        v_faits := v_faits || jsonb_build_object('kind', 'top_cardio', 'mesure', 'vitesse_duree',
                                                 'valeur', round(v_vd, 1), 'precedent', round(v_vd_p, 1));
      else
        v_faits := v_faits || jsonb_build_object('kind', 'top_cardio', 'mesure', 'hiit_secondes',
                                                 'valeur', v_hiit, 'precedent', v_hiit_p);
      end if;
    end if;
  end if;

  -- ── ×2 : une autre séance FINIE le même jour de la maison ─────────────
  select count(*) into v_autres
    from public.workouts w2
   where w2.user_id = v_uid and w2.ended_at is not null and w2.id <> p_workout
     and (w2.started_at at time zone public.fuseau_jour())::date = v_jour;
  if v_autres > 0 then
    select jsonb_agg(to_char(w3.started_at at time zone public.fuseau_jour(), 'HH24:MI')
                     order by w3.started_at),
           coalesce(sum(extract(epoch from (w3.ended_at - w3.started_at)) / 60), 0)::integer
      into v_heures, v_minutes
      from public.workouts w3
     where w3.user_id = v_uid and w3.ended_at is not null
       and (w3.started_at at time zone public.fuseau_jour())::date = v_jour;
    v_faits := v_faits || jsonb_build_object('kind', 'double_jour', 'mesure', null,
                                             'valeur', v_autres + 1, 'precedent', null,
                                             'detail', jsonb_build_object('heures', v_heures,
                                                                          'minutes', v_minutes));
  end if;

  -- ── le rangement : la porte du 30-08, idempotente par index ───────────
  v_range := public.poser_faits_seance(p_workout, v_jour, v_faits);
  -- un double_jour déjà pris par une autre séance du jour (index partiel) est
  -- compté « connu » par poser_faits_seance : on rend ce qui est réellement rangé
  select coalesce(jsonb_agg(jsonb_build_object(
           'kind', kind, 'mesure', mesure, 'valeur', valeur,
           'precedent', precedent, 'detail', detail) order by kind), '[]'::jsonb)
    into v_deja
    from public.workout_facts
   where user_id = v_uid and workout_id = p_workout;
  return jsonb_build_object('faits', v_deja, 'rejeu', false, 'range', v_range);
end $$;

