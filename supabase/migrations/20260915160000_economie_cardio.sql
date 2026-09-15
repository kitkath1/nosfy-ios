-- ════════════════════════════════════════════════════════════════════════
-- L'ÉCONOMIE DU CARDIO — ce qu'une séance HIIT, escalier, tapis ou piscine rapporte
-- 15-09, sur le go de Kathryn (« go cardio ») — tools/cardio/PLAN-ECONOMIE-CARDIO.md §2 et §4
--
-- Ses mots : « une séance cardio vaut des pièces à juger selon l'intensité : HIIT entre 100
-- et 300 (km/h, temps, intervalles, repos) ; escalier entre 50 et 100 (temps × niveau) ;
-- piscine 1 longueur = 20 ; tout dans Supabase ». Tranché ce midi : les chiffres du §2.1 tels
-- quels, le tapis modéré 30 → 100, la piscine 20 la longueur quel que soit X mètres avec un
-- plafond de 300, et le bonus n'est pas un avis de l'IA mais UNE RÈGLE : un fait top_cardio
-- (calculer_faits_seance, 20260915120000) → bonus_progres (30, la clé du 29-08).
--
-- LE PRINCIPE : c'est le SERVEUR qui compte, jamais le téléphone (il a toutes les phases,
-- poussées avant la clôture) ; chaque chiffre est une ligne de reward_rules ; le barème est
-- DÉTERMINISTE (deux séances identiques paient pareil, une séance se réexplique) ; une séance
-- rejouée paie une fois (l'index coin_ledger_gain_unique, déjà là).
--
-- ① les clés du barème (insert … do nothing : elles se règlent à la main) ;
-- ② la raison `cardio_seance` (+ `bonus_progres`) dans coin_ledger_raison_check — recopiée
--    depuis la liste VIVANTE (pg_get_constraintdef, 15-09 09:50 : serie_faite · ouverture_booster
--    · doublon · cadeau · annulation · piece_argent · ouverture_booster_noir · conversion_booster
--    · retour_quotidien · chemin) — le piège n° 1 du skill ;
-- ③ `piscine_longueurs` — ICI et pas en 170000 : `pieces_cardio_seance` la lit, et plpgsql ne
--    vérifie une table qu'à l'exécution (une fonction qui marcherait à la pose et casserait au
--    premier appel) ; 170000 la rend dans seances_depuis ;
-- ④ `pieces_cardio_seance(p_workout)` — le barème, exercice par exercice, appelable seule ;
-- ⑤ `cloturer_seance` (l'enveloppe SEULE, `_brut` ne bouge pas) : APRÈS `_brut` (la conversion
--    par 100 doit voir le total), le crédit `cardio_seance` sous unique_violation, le sachet
--    forfaitaire si p_series = 0 et cardio > 0, le `bonus_progres` si top_cardio, et les clés
--    EN PLUS : pieces_cardio · cardio_detail · pieces_total · bonus_progres · sachet_cardio ;
--    solde · reste · sachets_convertis sont RELUS après le crédit (sinon ils dataient d'avant).
--
-- Vérification : tools/serveur/verif_cardio.py (les sept séances du §2.1, trois escaliers, un
-- tapis, une piscine, une mixte, une vide — ×2, montants comparés, rejeu, sachet sans série,
-- sans jeton → 401, puis effacées) ; puis verif_faits.py (14) et verif_portes.py (34).
-- ════════════════════════════════════════════════════════════════════════

-- ── ① Le barème, en base ──────────────────────────────────────────────────

insert into public.reward_rules (key, value) values
  -- le HIIT sur tapis — entre 100 et 300
  ('cardio_hiit_base',              '100'::jsonb),   -- dès qu'il y a un effort d'au moins…
  ('cardio_hiit_effort_min_s',      '20'::jsonb),    -- … 20 s
  ('cardio_hiit_pieces_par_minute', '5'::jsonb),     -- par minute d'effort, pondérée par la vitesse :
  ('cardio_hiit_palier2_kmh',       '17'::jsonb),    -- ×1 de 15 à 17, ×mult2 de 17 à 19, ×mult3 au-delà
  ('cardio_hiit_mult2',             '1.5'::jsonb),
  ('cardio_hiit_palier3_kmh',       '19'::jsonb),
  ('cardio_hiit_mult3',             '2'::jsonb),
  ('cardio_hiit_temps_max',         '120'::jsonb),   -- le plafond des pièces de temps
  ('cardio_hiit_bonus_densite',     '40'::jsonb),    -- +40 si l'effort fait au moins…
  ('cardio_hiit_densite_min',       '0.5'::jsonb),   -- … la moitié du total (effort + récup)
  ('cardio_hiit_bonus_longs',       '40'::jsonb),    -- +40 s'il y a au moins…
  ('cardio_hiit_longs_min',         '3'::jsonb),     -- … 3 efforts d'au moins…
  ('cardio_hiit_long_s',            '60'::jsonb),    -- … 60 s
  ('cardio_hiit_max',               '300'::jsonb),
  -- l'escalier — entre 50 et 100 : 50 + (minutes montées × niveau moyen) / 4
  ('cardio_escalier_min_minutes',   '5'::jsonb),
  ('cardio_escalier_base',          '50'::jsonb),
  ('cardio_escalier_diviseur',      '4'::jsonb),
  ('cardio_escalier_max',           '100'::jsonb),
  -- le tapis à allure modérée — entre 30 et 100 : 30 + (minutes × km/h moyens) / 4
  ('cardio_tapis_min_minutes',      '5'::jsonb),
  ('cardio_tapis_base',             '30'::jsonb),
  ('cardio_tapis_diviseur',         '4'::jsonb),
  ('cardio_tapis_max',              '100'::jsonb),
  -- la piscine — 20 la longueur, quel que soit X mètres, 300 au plus par séance
  ('pieces_par_longueur',           '20'::jsonb),
  ('cardio_piscine_max',            '300'::jsonb)
on conflict (key) do nothing;

-- ── ② Les deux raisons nouvelles du carnet ────────────────────────────────

alter table public.coin_ledger drop constraint if exists coin_ledger_raison_check;
alter table public.coin_ledger add constraint coin_ledger_raison_check
  check (raison in ('serie_faite', 'ouverture_booster', 'doublon', 'cadeau', 'annulation',
                    'piece_argent', 'ouverture_booster_noir', 'conversion_booster',
                    'retour_quotidien', 'chemin',
                    'cardio_seance', 'bonus_progres'));

-- ── ③ La piscine : les longueurs d'un exercice ────────────────────────────

create table if not exists public.piscine_longueurs (
  logged_exercise_id  uuid primary key references public.logged_exercises (id) on delete cascade,
  user_id             uuid not null references auth.users (id) on delete cascade,
  longueurs           integer not null check (longueurs >= 0),
  metres_par_longueur integer not null default 25 check (metres_par_longueur > 0),
  updated_at          timestamptz not null default now()
);
comment on table public.piscine_longueurs is
  'Les longueurs d''un exercice de piscine (saisie manuelle dans l''app) : une ligne par logged_exercise, poussée par l''app (upsert sur la clé primaire), relue par seances_depuis. Payée par pieces_cardio_seance : pieces_par_longueur × longueurs, plafond cardio_piscine_max.';
create index if not exists piscine_longueurs_user_idx on public.piscine_longueurs (user_id);
alter table public.piscine_longueurs enable row level security;
do $$ begin
  create policy "piscine : chacun la sienne (select)" on public.piscine_longueurs for select to authenticated using (auth.uid() = user_id);
  create policy "piscine : chacun la sienne (insert)" on public.piscine_longueurs for insert to authenticated with check (auth.uid() = user_id);
  create policy "piscine : chacun la sienne (update)" on public.piscine_longueurs for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
  create policy "piscine : chacun la sienne (delete)" on public.piscine_longueurs for delete to authenticated using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

-- ── ④ Le barème, exercice par exercice ─────────────────────────────────────

create or replace function public.pieces_cardio_seance(p_workout uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_seuil     numeric := public.regle_num('seuil_effort_kmh', 15.0);
  e           record;
  -- hiit
  h_base      numeric := public.regle_num('cardio_hiit_base', 100);
  h_min_s     numeric := public.regle_num('cardio_hiit_effort_min_s', 20);
  h_ppm       numeric := public.regle_num('cardio_hiit_pieces_par_minute', 5);
  h_p2        numeric := public.regle_num('cardio_hiit_palier2_kmh', 17);
  h_m2        numeric := public.regle_num('cardio_hiit_mult2', 1.5);
  h_p3        numeric := public.regle_num('cardio_hiit_palier3_kmh', 19);
  h_m3        numeric := public.regle_num('cardio_hiit_mult3', 2);
  h_tmax      numeric := public.regle_num('cardio_hiit_temps_max', 120);
  h_bdens     numeric := public.regle_num('cardio_hiit_bonus_densite', 40);
  h_dmin      numeric := public.regle_num('cardio_hiit_densite_min', 0.5);
  h_blongs    numeric := public.regle_num('cardio_hiit_bonus_longs', 40);
  h_lmin      numeric := public.regle_num('cardio_hiit_longs_min', 3);
  h_long_s    numeric := public.regle_num('cardio_hiit_long_s', 60);
  h_max       numeric := public.regle_num('cardio_hiit_max', 300);
  -- escalier / tapis / piscine
  e_min       numeric := public.regle_num('cardio_escalier_min_minutes', 5);
  e_base      numeric := public.regle_num('cardio_escalier_base', 50);
  e_div       numeric := public.regle_num('cardio_escalier_diviseur', 4);
  e_max       numeric := public.regle_num('cardio_escalier_max', 100);
  t_min       numeric := public.regle_num('cardio_tapis_min_minutes', 5);
  t_base      numeric := public.regle_num('cardio_tapis_base', 30);
  t_div       numeric := public.regle_num('cardio_tapis_diviseur', 4);
  t_max       numeric := public.regle_num('cardio_tapis_max', 100);
  p_par       numeric := public.regle_num('pieces_par_longueur', 20);
  p_max       numeric := public.regle_num('cardio_piscine_max', 300);
  -- le travail
  v_exos      jsonb := '[]'::jsonb;
  v_total     numeric := 0;
  v_pieces    numeric;
  v_detail    jsonb;
  v_bareme    text;
  -- hiit : les agrégats
  n_efforts   int; n_longs int; s_effort numeric; s_recup numeric; s_pondere numeric; v_pic numeric;
  v_temps     numeric; v_dens numeric; v_dens_ok boolean; v_longs_ok boolean; v_base_ok boolean;
  -- steady : minutes et moyenne pondérée
  v_minutes   numeric; v_moy numeric;
  -- piscine
  v_long      int; v_mpl int;
begin
  if v_uid is null then
    return jsonb_build_object('total', 0, 'exercices', '[]'::jsonb, 'raison', 'sans_session');
  end if;
  if not exists (select 1 from public.workouts w where w.id = p_workout and w.user_id = v_uid) then
    return jsonb_build_object('total', 0, 'exercices', '[]'::jsonb, 'raison', 'seance_inconnue');
  end if;

  for e in select le.id, le.exercise_id, le.position
             from public.logged_exercises le
            where le.workout_id = p_workout and le.user_id = v_uid
              and le.exercise_id in ('hiit-tapis', 'escalier', 'tapis-lent', 'piscine')
            order by le.position
  loop
    v_pieces := 0; v_detail := '{}'::jsonb; v_bareme := e.exercise_id;

    if e.exercise_id = 'hiit-tapis' then
      -- un EFFORT = une phase au seuil ou plus ; une RÉCUP = en dessous (sa vitesse est gardée :
      -- « 30 s à 15 puis 1 min à 9, il faut le noter »)
      select count(*) filter (where c.speed >= v_seuil),
             count(*) filter (where c.speed >= v_seuil and c.seconds >= h_long_s),
             coalesce(sum(c.seconds) filter (where c.speed >= v_seuil), 0),
             coalesce(sum(c.seconds) filter (where c.speed <  v_seuil), 0),
             coalesce(sum((c.seconds / 60.0) * case when c.speed >= h_p3 then h_m3
                                                    when c.speed >= h_p2 then h_m2 else 1 end)
                      filter (where c.speed >= v_seuil), 0),
             coalesce(max(c.speed) filter (where c.speed >= v_seuil), 0),
             coalesce(bool_or(c.speed >= v_seuil and c.seconds >= h_min_s), false)
        into n_efforts, n_longs, s_effort, s_recup, s_pondere, v_pic, v_base_ok
        from public.cardio_phases c
       where c.logged_exercise_id = e.id;

      if v_base_ok then
        -- round, pas floor : `20/60.0` en numeric perd sa précision (6 sprints de 20 s à 19
        -- rendaient 119 au lieu de 120) — round rejoint l'arithmétique exacte du barème
        v_temps    := least(round(s_pondere * h_ppm), h_tmax);
        v_dens     := case when s_effort + s_recup > 0 then round(s_effort / (s_effort + s_recup), 2) else 0 end;
        v_dens_ok  := v_dens >= h_dmin;
        v_longs_ok := n_longs >= h_lmin;
        v_pieces   := least(h_base + v_temps + (case when v_dens_ok then h_bdens else 0 end)
                                   + (case when v_longs_ok then h_blongs else 0 end), h_max);
        v_detail := jsonb_build_object(
          'efforts', n_efforts, 'longs', n_longs, 'effort_s', s_effort, 'recup_s', s_recup,
          'km_h_max', v_pic, 'minutes_effort', round(s_effort / 60.0, 1),
          'temps_pondere_min', round(s_pondere, 2), 'pieces_temps', v_temps,
          'densite', v_dens, 'bonus_densite', (case when v_dens_ok then h_bdens else 0 end),
          'bonus_longs', (case when v_longs_ok then h_blongs else 0 end),
          'plafond_applique', (h_base + v_temps + (case when v_dens_ok then h_bdens else 0 end)
                               + (case when v_longs_ok then h_blongs else 0 end)) > h_max);
      else
        -- un « HIIT » jamais au-dessus du seuil est PAYÉ comme un tapis modéré (§2.1, dernière
        -- ligne du tableau) : les minutes courues, aux km/h moyens
        select coalesce(sum(c.seconds) / 60.0, 0),
               case when coalesce(sum(c.seconds), 0) > 0
                    then sum(c.speed * c.seconds) / sum(c.seconds) else 0 end
          into v_minutes, v_moy
          from public.cardio_phases c
         where c.logged_exercise_id = e.id and c.speed > 0;
        v_bareme := 'tapis (repli : aucun effort au seuil)';
        v_pieces := case when v_minutes >= t_min
                         then least(floor(t_base + (v_minutes * v_moy) / t_div), t_max) else 0 end;
        v_detail := jsonb_build_object('efforts', 0, 'minutes', round(v_minutes, 1), 'km_h', round(v_moy, 1),
                                       'plafond_applique', v_minutes >= t_min and t_base + (v_minutes * v_moy) / t_div > t_max);
      end if;

    elsif e.exercise_id = 'escalier' then
      -- les segments MONTÉS (speed > 0 = le niveau de la machine) ; les repos ne comptent pas
      select coalesce(sum(c.seconds) / 60.0, 0),
             case when coalesce(sum(c.seconds), 0) > 0 then sum(c.speed * c.seconds) / sum(c.seconds) else 0 end
        into v_minutes, v_moy
        from public.cardio_phases c
       where c.logged_exercise_id = e.id and c.speed > 0;
      v_pieces := case when v_minutes >= e_min
                       then least(floor(e_base + (v_minutes * v_moy) / e_div), e_max) else 0 end;
      v_detail := jsonb_build_object('minutes', round(v_minutes, 1), 'niveau_moyen', round(v_moy, 1),
                                     'plafond_applique', v_minutes >= e_min and e_base + (v_minutes * v_moy) / e_div > e_max);

    elsif e.exercise_id = 'tapis-lent' then
      select coalesce(sum(c.seconds) / 60.0, 0),
             case when coalesce(sum(c.seconds), 0) > 0 then sum(c.speed * c.seconds) / sum(c.seconds) else 0 end
        into v_minutes, v_moy
        from public.cardio_phases c
       where c.logged_exercise_id = e.id and c.speed > 0;
      v_pieces := case when v_minutes >= t_min
                       then least(floor(t_base + (v_minutes * v_moy) / t_div), t_max) else 0 end;
      v_detail := jsonb_build_object('minutes', round(v_minutes, 1), 'km_h', round(v_moy, 1),
                                     'plafond_applique', v_minutes >= t_min and t_base + (v_minutes * v_moy) / t_div > t_max);

    elsif e.exercise_id = 'piscine' then
      select p.longueurs, p.metres_par_longueur into v_long, v_mpl
        from public.piscine_longueurs p where p.logged_exercise_id = e.id and p.user_id = v_uid;
      v_long := coalesce(v_long, 0); v_mpl := coalesce(v_mpl, 25);
      v_pieces := least(v_long * p_par, p_max);
      v_detail := jsonb_build_object('longueurs', v_long, 'metres_par_longueur', v_mpl,
                                     'metres', v_long * v_mpl, 'plafond_applique', v_long * p_par > p_max);
    end if;

    v_total := v_total + v_pieces;
    v_exos := v_exos || jsonb_build_object('exercice_id', e.exercise_id, 'logged_exercise_id', e.id,
                                           'bareme', v_bareme, 'pieces', v_pieces::int, 'detail', v_detail);
  end loop;

  return jsonb_build_object('total', v_total::int, 'exercices', v_exos);
end $$;

comment on function public.pieces_cardio_seance(uuid) is
  'Le barème du cardio (PLAN-ECONOMIE-CARDIO.md §2), déterministe, lu dans reward_rules : HIIT (base + temps pondéré + densité + longs, plafond 300 ; sans effort au seuil → payé comme un tapis modéré), escalier (50 + minutes × niveau / 4, plafond 100), tapis modéré (30 + minutes × km/h / 4, plafond 100), piscine (20 la longueur, plafond 300). {total, exercices[]} ; 0 sans séance connue.';

revoke all on function public.pieces_cardio_seance(uuid) from public;
revoke all on function public.pieces_cardio_seance(uuid) from anon;
grant execute on function public.pieces_cardio_seance(uuid) to authenticated;

-- ── ⑤ La clôture paie le cardio ────────────────────────────────────────────

create or replace function public.cloturer_seance(p_workout uuid, p_series integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reponse   jsonb;
  v_faits     jsonb;
  v_cardio    jsonb;
  v_total     integer := 0;
  v_credite   integer := 0;
  v_rejeu     boolean := false;
  v_bonus     integer := 0;
  v_bonus_val integer := public.regle_num('bonus_progres', 30)::integer;
  v_booster   uuid;
  v_sachet    boolean := false;
  v_prix      integer;
  v_solde     integer;
begin
  -- ① la clôture d'avant : les pièces des séries, le sachet (si p_series > 0), la pièce
  --    d'argent — idempotente, rejouée elle rend le stocké
  v_reponse := public.cloturer_seance_brut(p_workout, p_series);

  -- ② les faits (15-09 matin) — jamais une erreur pour un fait décoratif
  begin
    v_faits := public.calculer_faits_seance(p_workout);
  exception when others then
    v_faits := jsonb_build_object('faits', '[]'::jsonb, 'raison', 'calcul_impossible');
  end;

  -- ③ le cardio — APRÈS _brut : le déclencheur de conversion par 100 voit le total
  begin
    v_cardio := public.pieces_cardio_seance(p_workout);
  exception when others then
    v_cardio := jsonb_build_object('total', 0, 'exercices', '[]'::jsonb, 'raison', 'calcul_impossible');
  end;
  v_total := coalesce((v_cardio->>'total')::integer, 0);
  if v_total > 0 then
    begin
      insert into public.coin_ledger (user_id, delta, raison, currency, workout_id)
      values (auth.uid(), v_total, 'cardio_seance', 'yellow', p_workout);
      v_credite := v_total;
    exception when unique_violation then
      -- déjà payé : on relit ce qui l'a été la première fois, rien ne bouge
      v_rejeu := true;
      select coalesce(delta, 0) into v_credite
        from public.coin_ledger
       where user_id = auth.uid() and raison = 'cardio_seance' and workout_id = p_workout
       limit 1;
    end;

    -- le sachet forfaitaire qu'une séance SANS série n'avait pas (_brut l'exige > 0) :
    -- un par séance, l'index user_boosters_seance_unique en répond
    if coalesce(p_series, 0) <= 0 then
      begin
        insert into public.user_boosters (user_id, origine, workout_id)
        values (auth.uid(), 'seance', p_workout)
        returning id into v_booster;
        v_sachet := true;
      exception when unique_violation then
        select id into v_booster from public.user_boosters
         where user_id = auth.uid() and workout_id = p_workout limit 1;
      end;
      v_reponse := v_reponse || jsonb_build_object('booster_id', v_booster, 'booster_neuf', v_sachet);
    end if;

    -- ④ le bonus est une RÈGLE : un fait top_cardio rangé pour cette séance → bonus_progres,
    --    une ligne à part, idempotente par le même index
    if exists (select 1 from public.workout_facts f
                where f.user_id = auth.uid() and f.workout_id = p_workout and f.kind = 'top_cardio') then
      begin
        insert into public.coin_ledger (user_id, delta, raison, currency, workout_id)
        values (auth.uid(), v_bonus_val, 'bonus_progres', 'yellow', p_workout);
        v_bonus := v_bonus_val;
      exception when unique_violation then
        select coalesce(delta, 0) into v_bonus
          from public.coin_ledger
         where user_id = auth.uid() and raison = 'bonus_progres' and workout_id = p_workout
         limit 1;
      end;
    end if;
  end if;

  -- ⑤ le solde, le reste et les sachets convertis, RELUS après le crédit (ceux de _brut
  --    dataient d'avant le cardio — un coffre qui aurait menti d'une séance)
  select coalesce((value)::text::integer, 100) into v_prix from public.reward_rules where key = 'prix_booster';
  v_solde := public.solde_or();
  v_reponse := v_reponse || jsonb_build_object(
    'solde',             v_solde,
    'reste',             (greatest(v_solde, 0) % greatest(v_prix, 1)),
    'sachets_convertis', public.convertis_transaction());

  return v_reponse
      || jsonb_build_object('faits', coalesce(v_faits->'faits', '[]'::jsonb),
                            'faits_raison', v_faits->>'raison')
      || jsonb_build_object('pieces_cardio',  v_credite,
                            'cardio_detail',  v_cardio - 'total',
                            'cardio_rejeu',   v_rejeu,
                            'bonus_progres',  v_bonus,
                            'sachet_cardio',  v_sachet,
                            'pieces_total',   coalesce((v_reponse->>'pieces')::integer, 0) + v_credite + v_bonus);
end $$;

comment on function public.cloturer_seance(uuid, integer) is
  'Fin de séance : pièces des séries, sachet, pièce d''argent (cloturer_seance_brut) ; les faits (calculer_faits_seance) ; depuis le 15-09 soir LE CARDIO (pieces_cardio_seance → ligne cardio_seance, le sachet si aucune série, bonus_progres si top_cardio) ; solde · reste · sachets_convertis relus après. Rejouée, elle rend le stocké.';

revoke all on function public.cloturer_seance(uuid, integer) from public;
revoke all on function public.cloturer_seance(uuid, integer) from anon;
grant execute on function public.cloturer_seance(uuid, integer) to authenticated;
