-- ════════════════════════════════════════════════════════════════════════
-- LES WIDGETS COMPLETS, ET home() — 13-09 soir (« ok pour tes recommandations, fais que le backend »)
--
-- Le serveur rendait moins que le téléphone : la chambre lue depuis le serveur
-- restait grise sur le fantôme (la fenêtre précédente jour par jour), le défi
-- du mois, les quatre semaines du record de vitesse, la récup et le plus long
-- trou de la fenêtre précédente ; et elle ne connaissait ni nom ni catégorie
-- d'exercice. Ici les quatre fonctions rendent tout — en plus, sans rien
-- retirer ni renommer (les clés du 05-09 restent) — et `exercices`
-- (20260913210000) leur donne les noms.
--
-- Construit par tools/… widgets-complets.py depuis les définitions VIVES
-- (pg_get_functiondef), par remplacements assertés. Mesuré le 13-09.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.widget_regularite(p_fenetre text DEFAULT 'semaine'::text)

returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  b record;
  v_tz text := public.fuseau_jour();
  v_uid uuid := auth.uid();
  v_faites int; v_prec int;
  v_suite int := 0; v_record int := 0;
  v_obj int;
  v_semaine timestamp;
  v_jours jsonb;
  v_defi jsonb;
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

  -- LE DÉFI (13-09) : battre le meilleur mois calendaire de l'historique (hors mois courant).
  -- null = aucun mois passé : pas de défi (le seul null assumé de cette fonction).
  select jsonb_build_object(
           'cible',        meilleur.n,
           'mois_cible',   to_char(meilleur.m, 'YYYY-MM'),
           'faites_mois',  (select count(*) from public.workouts w
                             where w.user_id = v_uid and w.ended_at is not null
                               and date_trunc('month', w.started_at at time zone v_tz) = date_trunc('month', now() at time zone v_tz)),
           'dates',        (select coalesce(jsonb_agg(w.started_at order by w.started_at), '[]'::jsonb) from public.workouts w
                             where w.user_id = v_uid and w.ended_at is not null
                               and date_trunc('month', w.started_at at time zone v_tz) = date_trunc('month', now() at time zone v_tz)),
           'jours_ecoules', greatest(extract(day from (now() at time zone v_tz))::int, 1))
    into v_defi
    from (select date_trunc('month', w.started_at at time zone v_tz) m, count(*) n
            from public.workouts w
           where w.user_id = v_uid and w.ended_at is not null
             and date_trunc('month', w.started_at at time zone v_tz) < date_trunc('month', now() at time zone v_tz)
           group by 1 order by n desc, m desc limit 1) meilleur;

  return jsonb_build_object(
    'fenetre',   p_fenetre,
    'defi',      v_defi,
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
$function$

;

create or replace function public.widget_volume(p_fenetre text DEFAULT 'semaine'::text)

returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  b record;
  v_uid uuid := auth.uid();
  v_vol numeric; v_prec numeric; v_seances int; v_reps int;
  v_exos jsonb; v_jours jsonb; v_record numeric;
  v_jours_prec jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into b from public.fenetre_bornes(p_fenetre);

  select coalesce(sum(s.reps * s.weight), 0), coalesce(sum(s.reps), 0)
    into v_vol, v_reps
    from public.strength_sets s
    join public.logged_exercises e on e.id = s.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut and w.started_at < b.fin;

  select coalesce(sum(s.reps * s.weight), 0) into v_prec
    from public.strength_sets s
    join public.logged_exercises e on e.id = s.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut_prec and w.started_at < b.fin_prec;

  select count(distinct w.id) into v_seances
    from public.workouts w
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut and w.started_at < b.fin;

  -- le volume par exercice. ⚠️ Le catalogue n'est pas en base : on rend
  -- `exercice_id`, l'app fait la jointure avec son catalogue Swift (et donc
  -- le nom, la catégorie et le sticker).
  select coalesce(jsonb_agg(x order by (x->>'volume')::numeric desc), '[]'::jsonb)
    into v_exos
    from (
      select jsonb_build_object(
               'exercice_id', e.exercise_id,
               'volume',      round(sum(s.reps * s.weight)),
               'reps',        sum(s.reps),
               'charge_max',  max(s.weight),
               -- 13-09 : le nom et la catégorie viennent du miroir du catalogue (table exercices)
               'nom',         (select cat.nom from public.exercices cat where cat.id = e.exercise_id),
               'categorie',   (select cat.categorie from public.exercices cat where cat.id = e.exercise_id)) x
        from public.strength_sets s
        join public.logged_exercises e on e.id = s.logged_exercise_id
        join public.workouts w on w.id = e.workout_id
       where w.user_id = v_uid and w.ended_at is not null
         and w.started_at >= b.debut and w.started_at < b.fin
       group by e.exercise_id
    ) t;

  -- le volume jour par jour (la courbe)
  -- ⚠️ on GROUPE d'abord, on CONSTRUIT l'objet ensuite : un `group by` ne
  -- peut pas porter sur une colonne qui contient déjà un agrégat (42803).
  select coalesce(jsonb_agg(jsonb_build_object('jour', jour, 'volume', vol)
                            order by jour), '[]'::jsonb) into v_jours
    from (
      select (w.started_at at time zone public.fuseau_jour())::date jour,
             round(coalesce(sum(s.reps * s.weight), 0)) vol
        from public.workouts w
        left join public.logged_exercises e on e.workout_id = w.id
        left join public.strength_sets s on s.logged_exercise_id = e.id
       where w.user_id = v_uid and w.ended_at is not null
         and w.started_at >= b.debut and w.started_at < b.fin
       group by 1
    ) t;

  -- 13-09 : la fenêtre PRÉCÉDENTE jour par jour — le fantôme pointillé de la courbe
  select coalesce(jsonb_agg(jsonb_build_object('jour', jour, 'volume', vol)
                            order by jour), '[]'::jsonb) into v_jours_prec
    from (
      select (w.started_at at time zone public.fuseau_jour())::date jour,
             round(coalesce(sum(s.reps * s.weight), 0)) vol
        from public.workouts w
        left join public.logged_exercises e on e.workout_id = w.id
        left join public.strength_sets s on s.logged_exercise_id = e.id
       where w.user_id = v_uid and w.ended_at is not null
         and w.started_at >= b.debut_prec and w.started_at < b.fin_prec
       group by 1
    ) t;

  -- le record de semaine, sur tout l'historique
  select coalesce(max(v), 0) into v_record from (
    select sum(s.reps * s.weight) v
      from public.strength_sets s
      join public.logged_exercises e on e.id = s.logged_exercise_id
      join public.workouts w on w.id = e.workout_id
     where w.user_id = v_uid and w.ended_at is not null
     group by date_trunc('week', w.started_at at time zone public.fuseau_jour())
  ) x;

  return jsonb_build_object(
    'fenetre',   p_fenetre,
    'volume',    round(v_vol),
    'precedent', round(v_prec),
    'delta_pct', case when v_prec > 0
                      then round((v_vol - v_prec) / v_prec * 100)
                      else null end,
    'seances',   v_seances,
    'par_seance', case when v_seances > 0 then round(v_vol / v_seances) else 0 end,
    'reps',      v_reps,
    'record_semaine', round(v_record),
    'exercices', v_exos,
    'jours',     v_jours,
    'jours_precedent', v_jours_prec,
    'debut',     b.debut,
    'fin',       b.fin,
    'debut_precedent', b.debut_prec
  );
end;
$function$

;

create or replace function public.widget_hiit(p_fenetre text DEFAULT 'semaine'::text)

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
     and c.speed >= v_seuil;

  -- la fenêtre précédente, bornée au même temps écoulé (①)
  select coalesce(max(c.speed), 0), count(*), coalesce(sum(c.seconds), 0)
    into v_pic_p, v_efforts_p, v_temps_p
    from public.cardio_phases c
    join public.logged_exercises e on e.id = c.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut_prec and w.started_at < b.fin_prec
     and c.speed >= v_seuil;

  -- le temps de récupération : tout ce qui est SOUS le seuil dans une
  -- séance qui contient au moins un effort
  select coalesce(sum(c.seconds), 0) into v_recup
    from public.cardio_phases c
    join public.logged_exercises e on e.id = c.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut and w.started_at < b.fin
     and c.speed < v_seuil
     and exists (select 1 from public.cardio_phases c2
                  join public.logged_exercises e2 on e2.id = c2.logged_exercise_id
                 where e2.workout_id = w.id and c2.speed >= v_seuil);

  -- les séances de la fenêtre, chacune avec SES segments (aucun pareil)
  select coalesce(jsonb_agg(x order by x->>'debut'), '[]'::jsonb) into v_seances
    from (
      select jsonb_build_object(
               'seance_id', w.id,
               'debut',     w.started_at,
               'jour',      (w.started_at at time zone public.fuseau_jour())::date,
               'pic',       (select max(c.speed) from public.cardio_phases c
                              join public.logged_exercises e on e.id = c.logged_exercise_id
                             where e.workout_id = w.id),
               'efforts',   (select count(*) from public.cardio_phases c
                              join public.logged_exercises e on e.id = c.logged_exercise_id
                             where e.workout_id = w.id and c.speed >= v_seuil),
               'segments',  (select coalesce(jsonb_agg(jsonb_build_object(
                                      'secondes', c.seconds, 'vitesse', c.speed,
                                      'genre', c.kind, 'cycle', c.cycle_index,
                                      'effort', c.speed >= v_seuil)
                                      order by e.position, c.cycle_index, c.position), '[]'::jsonb)
                               from public.cardio_phases c
                               join public.logged_exercises e on e.id = c.logged_exercise_id
                              where e.workout_id = w.id)
             ) x
        from public.workouts w
       where w.user_id = v_uid and w.ended_at is not null
         and w.started_at >= b.debut and w.started_at < b.fin
         and exists (select 1 from public.cardio_phases c
                      join public.logged_exercises e on e.id = c.logged_exercise_id
                     where e.workout_id = w.id and c.speed >= v_seuil)
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
     and w.started_at >= b.debut and w.started_at < b.fin and c.speed < v_seuil
     and exists (select 1 from public.cardio_phases c2 join public.logged_exercises e2 on e2.id = c2.logged_exercise_id
                  where e2.workout_id = w.id and c2.speed >= v_seuil);
  select coalesce(avg(c.seconds), 0)::int into v_recup_moy_p
    from public.cardio_phases c
    join public.logged_exercises e on e.id = c.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut_prec and w.started_at < b.fin_prec and c.speed < v_seuil
     and exists (select 1 from public.cardio_phases c2 join public.logged_exercises e2 on e2.id = c2.logged_exercise_id
                  where e2.workout_id = w.id and c2.speed >= v_seuil);

  -- 13-09 : le plus long trou entre deux séances HIIT, en jours, les deux fenêtres
  select coalesce(max(d), 0) into v_trou from (
    select extract(day from (w.started_at - lag(w.started_at) over (order by w.started_at)))::int d
      from public.workouts w
     where w.user_id = v_uid and w.ended_at is not null and w.started_at >= b.debut and w.started_at < b.fin
       and exists (select 1 from public.cardio_phases c join public.logged_exercises e on e.id = c.logged_exercise_id
                    where e.workout_id = w.id and c.speed >= v_seuil)) g;
  select coalesce(max(d), 0) into v_trou_p from (
    select extract(day from (w.started_at - lag(w.started_at) over (order by w.started_at)))::int d
      from public.workouts w
     where w.user_id = v_uid and w.ended_at is not null and w.started_at >= b.debut_prec and w.started_at < b.fin_prec
       and exists (select 1 from public.cardio_phases c join public.logged_exercises e on e.id = c.logged_exercise_id
                    where e.workout_id = w.id and c.speed >= v_seuil)) g;

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
$function$

;

create or replace function public.widget_peak(p_fenetre text DEFAULT 'semaine'::text)

returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  b record;
  v_uid uuid := auth.uid();
  v_pics jsonb; v_asc jsonb; v_records int;
  v_top record;   -- .exo : l'exercice dont on déplie l'ascension
  v_depuis int;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into b from public.fenetre_bornes(p_fenetre);

  -- les charges max de la fenêtre, par exercice, avec le précédent record
  select coalesce(jsonb_agg(x order by (x->>'delta')::numeric desc nulls last,
                                (x->>'charge')::numeric desc), '[]'::jsonb)
    into v_pics
    from (
      select jsonb_build_object(
               'exercice_id', e.exercise_id,
               'nom',         (select cat.nom from public.exercices cat where cat.id = e.exercise_id),
               'categorie',   (select cat.categorie from public.exercices cat where cat.id = e.exercise_id),
               'charge',      max(s.weight),
               'reps',        (select max(s2.reps) from public.strength_sets s2
                                join public.logged_exercises e2 on e2.id = s2.logged_exercise_id
                                join public.workouts w2 on w2.id = e2.workout_id
                               where w2.user_id = v_uid and w2.ended_at is not null and e2.exercise_id = e.exercise_id
                                 and s2.weight = max(s.weight)),
               'precedent',   (select max(s3.weight) from public.strength_sets s3
                                join public.logged_exercises e3 on e3.id = s3.logged_exercise_id
                                join public.workouts w3 on w3.id = e3.workout_id
                               where w3.user_id = v_uid and w3.ended_at is not null
                                 and e3.exercise_id = e.exercise_id
                                 and w3.started_at < b.debut),
               -- ⑤ un PREMIER n'est pas un record battu : sans précédent le
               -- delta est NULL (il valait la charge entière, donc « +120 kg »
               -- sur un exercice jamais fait — le même mensonge que hiitPeak).
               'premier',     (select max(s3.weight) from public.strength_sets s3
                                join public.logged_exercises e3 on e3.id = s3.logged_exercise_id
                                join public.workouts w3 on w3.id = e3.workout_id
                               where w3.user_id = v_uid and w3.ended_at is not null
                                 and e3.exercise_id = e.exercise_id
                                 and w3.started_at < b.debut) is null,
               'delta',       case when (select max(s3.weight) from public.strength_sets s3
                                join public.logged_exercises e3 on e3.id = s3.logged_exercise_id
                                join public.workouts w3 on w3.id = e3.workout_id
                               where w3.user_id = v_uid and w3.ended_at is not null
                                 and e3.exercise_id = e.exercise_id
                                 and w3.started_at < b.debut) is null then null
                              else max(s.weight) - (select max(s3.weight)
                                from public.strength_sets s3
                                join public.logged_exercises e3 on e3.id = s3.logged_exercise_id
                                join public.workouts w3 on w3.id = e3.workout_id
                               where w3.user_id = v_uid and w3.ended_at is not null
                                 and e3.exercise_id = e.exercise_id
                                 and w3.started_at < b.debut) end,
               'e1rm',        round((max(s.weight) * (1 + (select max(s2.reps)
                                from public.strength_sets s2
                                join public.logged_exercises e2 on e2.id = s2.logged_exercise_id
                                join public.workouts w2 on w2.id = e2.workout_id
                               where w2.user_id = v_uid and w2.ended_at is not null and e2.exercise_id = e.exercise_id
                                 and s2.weight = max(s.weight))::numeric / 30))::numeric, 1)
             ) x
        from public.strength_sets s
        join public.logged_exercises e on e.id = s.logged_exercise_id
        join public.workouts w on w.id = e.workout_id
       where w.user_id = v_uid and w.ended_at is not null
         and w.started_at >= b.debut and w.started_at < b.fin
         and s.weight > 0
       group by e.exercise_id
    ) t;

  -- L'ASCENSION du meilleur exercice de la fenêtre : toutes ses marches,
  -- c'est-à-dire chaque fois que sa charge max a battu la précédente.
  -- on suit l'exercice qui a le plus PROGRESSÉ (un record battu raconte une
  -- histoire) ; à défaut seulement, le plus lourd de la fenêtre.
  select (p->>'exercice_id')::text as exo into v_top
    from jsonb_array_elements(v_pics) p
   order by case when (p->>'delta') is null then 1 else 0 end,
            (p->>'delta')::numeric desc nulls last,
            (p->>'charge')::numeric desc
   limit 1;

  if v_top.exo is null then
    v_asc := '[]'::jsonb;
  else
    select coalesce(jsonb_agg(jsonb_build_object('jour', jour, 'charge', charge)
                              order by jour), '[]'::jsonb)
      into v_asc
      from (
        select jour, charge from (
          select (w.started_at at time zone public.fuseau_jour())::date jour,
                 max(s.weight) charge,
                 max(max(s.weight)) over (order by (w.started_at at time zone public.fuseau_jour())::date
                                          rows between unbounded preceding and 1 preceding) precedent
            from public.strength_sets s
            join public.logged_exercises e on e.id = s.logged_exercise_id
            join public.workouts w on w.id = e.workout_id
           where w.user_id = v_uid and w.ended_at is not null
             and e.exercise_id = v_top.exo and s.weight > 0
           group by 1
        ) g
        where precedent is null or charge > precedent
      ) marches;
  end if;

  -- 13-09 : depuis le dernier record (jours), lu sur la dernière marche de l'ascension
  select (current_date - max((m->>'jour')::date))::int into v_depuis from jsonb_array_elements(v_asc) m;

  -- combien de records battus dans la fenêtre
  select count(*) into v_records
    from jsonb_array_elements(v_pics) p
   where (p->>'delta')::numeric > 0;

  return jsonb_build_object(
    'fenetre',   p_fenetre,
    'pics',      v_pics,
    'meilleur_exercice', v_top.exo,
    'ascension', v_asc,
    'records_battus', v_records,
    'depuis_record', v_depuis
  );
end;
$function$

;

-- ── home() : UN appel pour la home (13-09, Kathryn : « la homepage est aussi interactive,
-- des fois le wording change, ça doit récupérer des vraies données ») — le prénom, les
-- séances faites cette semaine, l'objectif, le reste, la séance en cours. LE MOT reste à
-- l'écran (« Hello X, you've done N workouts this week. » / « Alright X, you've been at it
-- N minutes so far. » / « Hello there, » sans prénom) : ici seulement les nombres et le nom.
create or replace function public.home()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  p public.profils%rowtype;
  r jsonb;
  v_enc timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into p from public.profils where user_id = v_uid;
  r := public.widget_regularite('semaine');
  select w.started_at into v_enc from public.workouts w
   where w.user_id = v_uid and w.ended_at is null order by w.started_at desc limit 1;
  return jsonb_build_object(
    'prenom',             p.prenom,
    'onboarding_termine', p.onboarding_termine_at is not null,
    'faites',             r->'faites',
    'objectif',           r->'objectif',
    'reste',              r->'reste',
    'en_seance',          v_enc is not null,
    'minutes_en_seance',  case when v_enc is null then 0 else floor(extract(epoch from (now() - v_enc)) / 60)::int end,
    'derniere_seance_at', (select max(w.ended_at) from public.workouts w where w.user_id = v_uid and w.ended_at is not null),
    'seances_total',      (select count(*) from public.workouts w where w.user_id = v_uid and w.ended_at is not null)
  );
end;
$function$;
revoke execute on function public.home() from public, anon;
grant  execute on function public.home() to authenticated;
comment on function public.home() is 'Un appel pour la home : prenom, onboarding_termine, faites/objectif/reste (widget_regularite semaine), en_seance + minutes_en_seance (une séance poussée sans fin), derniere_seance_at, seances_total. Le wording (« Hello X, you''ve done N workouts this week. ») reste à l''écran.';
