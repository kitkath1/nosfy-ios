CREATE OR REPLACE FUNCTION public.claim_retour_quotidien()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_montant   integer;
  v_credite   boolean := true;
  v_jour      date;
begin
  -- 13-09 (première arrivée) : pas de +10 avant la première séance finie — la même
  -- règle que etat_coffre.retour_disponible, tenue ici pour qu'on ne puisse pas la contourner.
  if not exists (select 1 from public.workouts w where w.user_id = auth.uid() and w.ended_at is not null) then
    return jsonb_build_object(
      'credite', false, 'raison', 'premiere_seance_requise', 'montant', 0,
      'jour', public.jour_courant(),
      'sachets_convertis', public.convertis_transaction(),
      'solde', public.solde_or());
  end if;
  select coalesce((value)::text::integer, 10) into v_montant
    from public.reward_rules where key = 'pieces_retour_quotidien';
  v_jour := public.jour_courant();

  begin
    insert into public.coin_ledger (user_id, delta, raison, currency, jour)
    values (auth.uid(), v_montant, 'retour_quotidien', 'yellow', v_jour);
  exception when unique_violation then
    -- Déjà pris ce jour-là. Pas une erreur : le bouton Claim peut appeler sans
    -- savoir (un autre appareil a pu passer avant).
    v_credite := false;
  end;

  return jsonb_build_object(
    'credite',           v_credite,
    'montant',           case when v_credite then v_montant else 0 end,
    'jour',              v_jour,
    'sachets_convertis', public.convertis_transaction(),
    'solde',             public.solde_or());
end $function$
