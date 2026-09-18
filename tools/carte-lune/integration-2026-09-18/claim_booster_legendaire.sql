CREATE OR REPLACE FUNCTION public.claim_booster_legendaire()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id    uuid;
  v_solde integer;
  v_prix  integer;
begin
  -- LA REPRISE : un légendaire déjà payé, ouvert, jamais scellé — le sien.
  -- ⚠️ SANS fenêtre de temps, contrairement à `ouvrir_booster` (§3) : l'index
  -- « au plus un noir non scellé » garantit qu'il y en a au plus UN, il a
  -- déjà été payé d'une pièce d'argent, et c'est lui que `etat_coffre()`
  -- compte dans `noirs_ouverts` (§5) pour tenir la porte du manège ouverte.
  -- Le rendre est la seule réponse qui ne perde pas d'argent.
  select id into v_id from public.user_boosters
   where user_id = auth.uid() and origine = 'legendaire'
     and opened_at is not null and card_id is null
   order by opened_at desc
   limit 1;
  if v_id is not null then
    return jsonb_build_object(
      'ouvert', true, 'booster_id', v_id, 'reprise', true,
      'solde_argent', public.solde_argent(), 'prix', 0::integer);
  end if;

  select coalesce((value)::int, 1) into v_prix
    from public.reward_rules where key = 'prix_booster_legendaire';
  v_prix := coalesce(v_prix, 1);
  v_solde := public.solde_argent();

  -- ⚠️ UN REFUS MÉTIER N'EST PAS UNE ERREUR SERVEUR : 200, avec le motif.
  if v_solde < v_prix then
    return jsonb_build_object(
      'ouvert', false, 'raison', 'argent_insuffisant'::text,
      'solde_argent', v_solde, 'prix', v_prix);
  end if;

  begin
    insert into public.user_boosters (user_id, origine, opened_at)
      values (auth.uid(), 'legendaire', now())
      returning id into v_id;
  exception when unique_violation then
    -- L'index « au plus un noir non scellé » a parlé : on le rend.
    select id into v_id from public.user_boosters
     where user_id = auth.uid() and origine = 'legendaire'
       and card_id is null
     limit 1;
    return jsonb_build_object(
      'ouvert', true, 'booster_id', v_id, 'reprise', true,
      'solde_argent', v_solde, 'prix', 0::integer);
  end;

  insert into public.coin_ledger (user_id, delta, raison, currency, booster_id)
    values (auth.uid(), -v_prix, 'ouverture_booster_noir', 'silver', v_id);

  return jsonb_build_object(
    'ouvert', true, 'booster_id', v_id, 'reprise', false,
    'solde_argent', public.solde_argent(), 'prix', v_prix);
end $function$
