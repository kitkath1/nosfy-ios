-- ════════════════════════════════════════════════════════════════════════
-- LA LECTURE DES QUATRE WIDGETS — 05-09-2026
--
-- Verdict appliqué : « les quatre widgets sont calculés dans le téléphone,
-- donc rien ne survit à une réinstallation ». Cette migration pose la
-- LECTURE qui manquait : une fonction par widget, dérivée des quatre tables
-- que `SupabaseSync.push()` remplit déjà (workouts, logged_exercises,
-- strength_sets, cardio_phases).
--
-- Analyse : tools/widgets/ANALYSE-DATAS-WIDGETS.md
--
-- Quatre décisions portées ici :
--   ① La fenêtre précédente est bornée AU MÊME TEMPS ÉCOULÉ. Un mardi, on
--      compare deux mardis — pas deux jours contre sept. (Correctif du 25-08,
--      WidgetsCards.swift:2218-2236 : sans cette borne, le bilan annonçait
--      « en recul » presque tous les lundis de l'année.)
--   ② Un EFFORT est un passage au-dessus de `seuil_effort_kmh`, et ce seuil
--      vit en base. Il y avait trois chiffres pour une idée : 9,5 km/h dans
--      hiitPeak(), 15,0 voulu à l'écran, 20 kg/min pour l'équivalence cardio.
--      Une seule définition, lue par tout le monde.
--   ③ AUCUNE factorisation de cycle. Une séance HIIT est une suite de phases
--      dont aucune ne se répète : on compte des efforts, on ne déduit jamais
--      un « × N ». (C'est le défaut de hiitPeak(), WidgetsCards.swift:2318.)
--   ④ Rien n'est stocké. Tout se dérive — la série de semaines comme le
--      solde : un compteur se désynchronise, une somme ne ment pas.
--
-- ⚠️ `speed` et `weight` sont en `double precision` : tout `round(x, n)` sur
-- eux exige un `::numeric` explicite — Postgres n'a pas de round(double, int).
-- (Attrapé au banc bout en bout, pas en relecture : 42883.)
--
-- Toutes les fonctions sont en LECTURE seule (`stable`), rendent du `jsonb`,
-- et ne lèvent jamais : une fenêtre vide rend des zéros, jamais un null.
-- ════════════════════════════════════════════════════════════════════════

-- ── ② le seuil, en base ────────────────────────────────────────────────
insert into public.reward_rules (key, value)
values ('seuil_effort_kmh', '15.0'::jsonb)
on conflict (key) do nothing;

-- ── un lecteur de règle numérique, avec défaut ─────────────────────────
create or replace function public.regle_num(p_key text, p_defaut numeric)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select (value #>> '{}')::numeric from public.reward_rules
                   where key = p_key), p_defaut);
$$;

-- ── ① LES BORNES D'UNE FENÊTRE ─────────────────────────────────────────
-- 'semaine' : depuis lundi 00:00 dans le fuseau de la maison.
-- 'mois'    : les 30 derniers jours glissants.
-- La fenêtre précédente a la MÊME DURÉE ÉCOULÉE, décalée d'une période.
create or replace function public.fenetre_bornes(p_fenetre text)
returns table (debut timestamptz, fin timestamptz,
               debut_prec timestamptz, fin_prec timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  with z as (select public.fuseau_jour() as tz),
  b as (
    select case
             when p_fenetre = 'mois' then now() - interval '30 days'
             else (date_trunc('week', now() at time zone (select tz from z))
                   at time zone (select tz from z))
           end as d,
           case when p_fenetre = 'mois' then interval '30 days'
                else interval '7 days' end as pas
    from z
  )
  select b.d,
         now(),
         b.d - b.pas,
         (b.d - b.pas) + (now() - b.d)
  from b;
$$;

-- ── L'EFFORT D'UNE SÉANCE ──────────────────────────────────────────────
-- La même jauge que l'app (WidgetsCards.swift:2267) : le volume de fonte
-- plus une équivalence cardio. Elle sert au halo d'intensité du calendrier
-- et à rien d'autre — ce n'est pas un bilan, c'est une jauge.
create or replace function public.effort_seance(p_workout uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
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
                   where e.workout_id = p_workout), 0)
    else 0 end;
$$;

-- ════════════════════════════════════════════════════════════════════════
-- WIDGET 01 · RÉGULARITÉ
-- ════════════════════════════════════════════════════════════════════════
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
  v_semaine timestamp;
  v_jours jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into b from public.fenetre_bornes(p_fenetre);

  select count(*) into v_faites from public.workouts w
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut and w.started_at < b.fin;

  select count(*) into v_prec from public.workouts w
   where w.user_id = v_uid and w.ended_at is not null
     and w.started_at >= b.debut_prec and w.started_at < b.fin_prec;

  -- ④ LA SÉRIE DE SEMAINES, dérivée — jamais un compteur.
  -- La semaine courante compte si elle a une séance ; sinon on part de la
  -- précédente (la même loi que flamme() : hier compte si aujourd'hui ne
  -- l'est pas encore), pour qu'un lundi matin ne remette pas la série à zéro.
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
    exit when v_suite > 520;   -- garde-fou : dix ans
  end loop;

  -- le record de série : la plus longue île de semaines consécutives
  with sem as (
    select distinct date_trunc('week', w.started_at at time zone v_tz) s
      from public.workouts w
     where w.user_id = v_uid and w.ended_at is not null
  ), iles as (
    select s, s - (row_number() over (order by s)) * interval '7 days' as ile from sem
  )
  select coalesce(max(n), 0) into v_record
    from (select count(*) n from iles group by ile) x;

  -- les jours de la fenêtre, avec leur intensité (1..3) et leur catégorie
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
    'precedent', v_prec,
    'delta',     v_faites - v_prec,
    'suite_semaines', v_suite,
    'record_suite',   v_record,
    'jours',     v_jours
  );
end;
$$;

-- ════════════════════════════════════════════════════════════════════════
-- WIDGET 02 · VOLUME
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.widget_volume(p_fenetre text default 'semaine')
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  b record;
  v_uid uuid := auth.uid();
  v_vol numeric; v_prec numeric; v_seances int; v_reps int;
  v_exos jsonb; v_jours jsonb; v_record numeric;
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
               'charge_max',  max(s.weight)) x
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
    'jours',     v_jours
  );
end;
$$;

-- ════════════════════════════════════════════════════════════════════════
-- WIDGET 03 · HIIT
-- ③ On compte des EFFORTS (des passages au-dessus du seuil). On ne déduit
--   JAMAIS un « × N » : aucune phase ne se répète.
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.widget_hiit(p_fenetre text default 'semaine')
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  b record;
  v_uid uuid := auth.uid();
  v_seuil numeric := public.regle_num('seuil_effort_kmh', 15.0);
  v_pic numeric; v_efforts int; v_temps int; v_moy numeric;
  v_pic_p numeric; v_efforts_p int; v_temps_p int;
  v_recup int; v_seances jsonb;
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
                                      'genre', c.kind, 'cycle', c.cycle_index)
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

  return jsonb_build_object(
    'fenetre',        p_fenetre,
    'seuil',          v_seuil,
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
$$;

-- ════════════════════════════════════════════════════════════════════════
-- WIDGET 04 · PEAK EFFORT
-- L'ascension garde TOUTES ses marches — l'app les construisait puis les
-- jetait (WidgetsCards.swift:2355).
-- ════════════════════════════════════════════════════════════════════════
create or replace function public.widget_peak(p_fenetre text default 'semaine')
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  b record;
  v_uid uuid := auth.uid();
  v_pics jsonb; v_asc jsonb; v_records int;
  v_top record;   -- .exo : l'exercice dont on déplie l'ascension
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

  -- combien de records battus dans la fenêtre
  select count(*) into v_records
    from jsonb_array_elements(v_pics) p
   where (p->>'delta')::numeric > 0;

  return jsonb_build_object(
    'fenetre',   p_fenetre,
    'pics',      v_pics,
    'meilleur_exercice', v_top.exo,
    'ascension', v_asc,
    'records_battus', v_records
  );
end;
$$;

-- ── les droits : lecture pour toute session authentifiée ───────────────
grant execute on function public.regle_num(text, numeric)      to authenticated;
grant execute on function public.fenetre_bornes(text)          to authenticated;
grant execute on function public.effort_seance(uuid)           to authenticated;
grant execute on function public.widget_regularite(text)       to authenticated;
grant execute on function public.widget_volume(text)           to authenticated;
grant execute on function public.widget_hiit(text)             to authenticated;
grant execute on function public.widget_peak(text)             to authenticated;
