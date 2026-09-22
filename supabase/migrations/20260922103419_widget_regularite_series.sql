-- ════════════════════════════════════════════════════════════════════════
-- LES SÉRIES PAR SEMAINE ET PAR MOIS — 22-09, chantier Widgets (« go pour Regularity »)
--
-- Verdict appliqué : Kathryn, 22-09 — « il faut mettre le nombre de séries faites par semaine
-- et par mois dans Regularity ; tu récupères ça avec la date de fin de séance ». Analyse :
-- tools/widgets/ANALYSE-SERIES-SEMAINE-MOIS-2026-09-22.md (§ 4).
--
-- widget_regularite rend trois clés de plus — `series`, `series_precedent`, `series_delta` —
-- comptées sur strength_sets (une ligne = une série faite, la définition qui PAIE déjà à la
-- clôture), sur les mêmes bornes que faites / precedent (fenetre_bornes, la fenêtre d'avant au
-- même temps écoulé), à la date de FIN de séance. Même signature, mêmes clés d'avant, même
-- repli (des zéros, jamais un null) : aucun appelant ne bouge ; la chambre Regularity les lit
-- (ChambreServeur.regularite) et le téléphone compte pareil (Workout.seriesPayantes) —
-- tools/serveur/verif_widgets.py compare les deux.
--
-- Construit depuis la définition VIVE (pg_get_functiondef relue le 22-09, identique au dépôt
-- 20260913211000), par remplacements assertés. DOWN (à la main) : rejouer la définition de
-- 20260913211000_widgets_complets.sql:16-128.
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
  v_series int; v_series_prec int;
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

  -- LES SÉRIES FAITES (22-09, Kathryn : « le nombre de séries faites par semaine et par
  -- mois ; tu récupères ça avec la date de fin de séance »). Une ligne de strength_sets EST
  -- une série faite : la poussée n'envoie que les séries cochées (SupabaseSync.swift:406) et
  -- c'est ce même count(*) que cloturer_seance paie (series_verifiees). Comptées à la FIN de
  -- la séance (w.ended_at), sa règle — les séances, elles, restent au jour de début : le
  -- litige est posé sur le site (b-fn-fenetre-bornes). ⚠️ strength_sets.is_done n'est JAMAIS
  -- écrite (toujours false) : on ne filtre pas dessus ; une série chronométrée à 0 rép compte ;
  -- le cardio et la piscine ne sont pas des séries (leur barème est à part). La fenêtre d'avant
  -- est bornée au même temps écoulé (fenetre_bornes), comme faites / precedent.
  select count(*) into v_series
    from public.strength_sets s
    join public.logged_exercises e on e.id = s.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and e.user_id = v_uid and s.user_id = v_uid
     and w.ended_at is not null
     and w.ended_at >= b.debut and w.ended_at < b.fin;

  select count(*) into v_series_prec
    from public.strength_sets s
    join public.logged_exercises e on e.id = s.logged_exercise_id
    join public.workouts w on w.id = e.workout_id
   where w.user_id = v_uid and e.user_id = v_uid and s.user_id = v_uid
     and w.ended_at is not null
     and w.ended_at >= b.debut_prec and w.ended_at < b.fin_prec;

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
    -- 22-09 : les séries faites de la fenêtre, celles d'avant, l'écart (des zéros à vide)
    'series',           v_series,
    'series_precedent', v_series_prec,
    'series_delta',     v_series - v_series_prec,
    'jours',     v_jours
  );
end;
$function$

;

-- les droits ne bougent pas (create or replace les conserve) ; redits pour la lecture
revoke all on function public.widget_regularite(text) from public, anon;
grant execute on function public.widget_regularite(text) to authenticated;
