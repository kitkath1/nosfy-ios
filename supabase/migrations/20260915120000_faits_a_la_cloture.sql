-- ════════════════════════════════════════════════════════════════════════
-- LES FAITS SE CALCULENT À LA CLÔTURE — 15-09, étape 4a (« faits & bilan »)
--
-- Le défaut (site : b-fn-poser-faits 🔵 « personne ne l'appelle », b-rg-top 🔵 « lues par
-- personne », b-st-top ⚪) : le tiroir `workout_facts` et sa porte `poser_faits_seance`
-- existent depuis le 30-08, mais RIEN ne calcule « cette séance était un record ».
-- Les stories TOP / ×2 ne se déclenchent que sur un drapeau de banc.
--
-- Le 30-08 avait tranché « l'app calcule, le serveur range » parce que le serveur ne
-- tenait alors aucune séance (la poussée ne marchait pas). Depuis le 13-09 il les tient
-- toutes, et la clôture ARRIVE APRÈS la poussée, dans la même tâche (WoopApp :
-- `await push([snapshot])` puis `reglerFinDeSeance`). Le serveur peut donc CALCULER
-- lui-même, avec les mêmes règles `top_*` posées le 30-08 — une seule définition, la
-- même pour la story, le calendrier et un test. L'app garde le droit de calculer aussi
-- (la story n'attend pas le réseau) ; ce que le serveur range est la vérité.
--
-- ① `calculer_faits_seance(p_workout)` — lit la séance (celle de la personne, finie),
--    compare à la fenêtre `top_fenetre_jours` glissante (les séances FINIES d'avant, hors
--    elle-même), exige `top_min_seances` séances dans la fenêtre (elle comprise : « se
--    dépasser suppose un précédent »), et pose :
--      · top_muscu   : `series` (séries faites) ou `volume_kg` (Σ reps × poids) — il suffit
--                      d'en battre UNE ; on garde la mesure la mieux battue (en proportion) ;
--      · top_cardio  : `hiit_secondes` (Σ secondes des phases ≥ seuil_effort_kmh) ou
--                      `vitesse_duree` (max vitesse × secondes d'une phase d'effort) ;
--      · double_jour : une autre séance finie le MÊME jour de la maison (jour_courant sur
--                      started_at) — detail {heures: ["07:12","19:40"], minutes: Σ durées},
--                      la forme que `DoubleFait(heures:minutes:)` attend déjà.
--    UN FAIT EST UN ESTAMPILLAGE : posé une fois (index workout_facts_unique), jamais
--    recalculé — la loi du 30-08. Rejouée, elle rend le STOCKÉ. Sans séance connue
--    (pas encore poussée, ou pas à elle) → {faits: [], raison: 'seance_inconnue'}, jamais
--    une erreur : la clôture ne doit pas échouer pour un fait décoratif.
-- ② `cloturer_seance` devient une ENVELOPPE (le motif de tirer_noeud_chemin) : l'ancienne
--    est renommée `cloturer_seance_brut` (privée), la nouvelle l'appelle et ajoute `faits`.
--    Même signature, même idempotence, mêmes clés + une : aucun appelant ne bouge
--    (SacreServeur.cloturerSeance décode `faits` en optionnel).
--
-- Vérification : tools/serveur/verif_faits.py (compte de test : une séance record semée
-- puis retirée ; rejeu ; seconde séance du jour → double_jour ; séance inconnue → []).
-- ════════════════════════════════════════════════════════════════════════

-- ── 1. Le calcul ──────────────────────────────────────────────────────────

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
     where e.workout_id = p_workout and c.user_id = v_uid and c.speed >= v_seuil;
    select coalesce(max(x.hiit), 0), coalesce(max(x.vd), 0)
      into v_hiit_p, v_vd_p
      from (select w2.id,
                   coalesce(sum(c.seconds), 0)            as hiit,
                   coalesce(max(c.speed * c.seconds), 0)  as vd
              from public.workouts w2
              join public.logged_exercises e on e.workout_id = w2.id
              join public.cardio_phases c on c.logged_exercise_id = e.id and c.speed >= v_seuil
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

comment on function public.calculer_faits_seance(uuid) is
  'Calcule et range les faits d''une séance finie (top_muscu, top_cardio sur la fenêtre top_fenetre_jours avec top_min_seances ; double_jour) — estampillage unique, rejouée elle rend le stocké ; {faits: [], raison} si la séance est inconnue.';

revoke all on function public.calculer_faits_seance(uuid) from public;
revoke all on function public.calculer_faits_seance(uuid) from anon;
grant execute on function public.calculer_faits_seance(uuid) to authenticated;

-- ── 2. La clôture rend les faits ──────────────────────────────────────────

alter function public.cloturer_seance(uuid, integer) rename to cloturer_seance_brut;
revoke all on function public.cloturer_seance_brut(uuid, integer) from public;
revoke all on function public.cloturer_seance_brut(uuid, integer) from anon;
revoke all on function public.cloturer_seance_brut(uuid, integer) from authenticated;

create or replace function public.cloturer_seance(p_workout uuid, p_series integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reponse jsonb;
  v_faits   jsonb;
begin
  v_reponse := public.cloturer_seance_brut(p_workout, p_series);
  -- Les faits ne paient rien et ne doivent jamais faire échouer la clôture :
  -- une séance pas encore poussée rend simplement [] (raison seance_inconnue).
  begin
    v_faits := public.calculer_faits_seance(p_workout);
  exception when others then
    v_faits := jsonb_build_object('faits', '[]'::jsonb, 'raison', 'calcul_impossible');
  end;
  return v_reponse || jsonb_build_object('faits', coalesce(v_faits->'faits', '[]'::jsonb),
                                         'faits_raison', v_faits->>'raison');
end $$;

comment on function public.cloturer_seance(uuid, integer) is
  'Fin de séance : pièces, sachet, pièce d''argent (cloturer_seance_brut, idempotent) — et depuis le 15-09 les faits de la séance (calculer_faits_seance) dans la même réponse, clé faits.';

revoke all on function public.cloturer_seance(uuid, integer) from public;
revoke all on function public.cloturer_seance(uuid, integer) from anon;
grant execute on function public.cloturer_seance(uuid, integer) to authenticated;
