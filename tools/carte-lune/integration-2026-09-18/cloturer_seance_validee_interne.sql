CREATE OR REPLACE FUNCTION public.cloturer_seance_validee_interne(p_workout uuid, p_series integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end $function$
