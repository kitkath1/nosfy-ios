CREATE OR REPLACE FUNCTION public.cloturer_seance_brut(p_workout uuid, p_series integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_par_serie integer;
  v_pieces    integer;
  v_credite   boolean := true;
  v_rejeu     boolean := false;
  v_booster   uuid;
  v_neuf      boolean := true;
  v_argent    boolean := false;   -- tombée À CET APPEL
  v_argent_s  boolean := false;   -- tombée pour CETTE SÉANCE (le stocké)
  v_prix      integer;
  v_solde     integer;
begin
  if p_workout is null then
    raise exception 'cloturer_seance : il faut la séance';
  end if;

  select coalesce((value)::text::integer, 20) into v_par_serie
    from public.reward_rules where key = 'pieces_par_serie';
  v_pieces := greatest(coalesce(p_series, 0), 0) * v_par_serie;

  -- ① les pièces — seulement s'il y a eu du travail. L'insertion déclenche la
  --    conversion (§3) dans la même transaction.
  if v_pieces > 0 then
    begin
      insert into public.coin_ledger
        (user_id, delta, raison, currency, workout_id)
      values (auth.uid(), v_pieces, 'serie_faite', 'yellow', p_workout);
    exception when unique_violation then
      -- Un REJEU : l'index a parlé. On relit ce qui a été payé la première fois.
      v_credite := false;
      v_rejeu   := true;
      select coalesce(delta, 0) into v_pieces
        from public.coin_ledger
       where user_id = auth.uid() and raison = 'serie_faite' and workout_id = p_workout
       limit 1;
    end;
  else
    v_credite := false;
  end if;

  -- ② le sachet — FORFAITAIRE (un par séance terminée, quel que soit le
  --    nombre de séries).
  if greatest(coalesce(p_series, 0), 0) > 0 then
    begin
      insert into public.user_boosters (user_id, origine, workout_id)
      values (auth.uid(), 'seance', p_workout)
      returning id into v_booster;
    exception when unique_violation then
      v_neuf := false;
      select id into v_booster
        from public.user_boosters
       where user_id = auth.uid() and workout_id = p_workout
       limit 1;
    end;
  end if;

  -- ③ LA RARETÉ — au règlement, une seule fois, isolée dans une
  --    sous-transaction (le bonus ne coûte jamais le crédit principal).
  if v_credite then
    begin
      v_argent := public.roll_rare(p_workout);
    exception when others then
      v_argent := false;
    end;
  end if;
  -- Le stocké : cette séance a-t-elle (jamais) fait tomber sa pièce ?
  select exists (
    select 1 from public.coin_ledger
     where user_id = auth.uid() and raison = 'piece_argent' and workout_id = p_workout)
    into v_argent_s;

  select coalesce((value)::text::integer, 100) into v_prix
    from public.reward_rules where key = 'prix_booster';
  v_solde := public.solde_or();

  return jsonb_build_object(
    'pieces',            case when v_credite or v_rejeu then v_pieces else 0 end,
    'pieces_creditees',  v_credite,
    'rejeu',             v_rejeu,
    'booster_id',        v_booster,
    'booster_neuf',      v_neuf and v_booster is not null,
    'solde',             v_solde,
    'solde_argent',      public.solde_argent(),
    'argent',            v_argent,
    'argent_seance',     v_argent_s,
    'sachets_convertis', public.convertis_transaction(),
    'reste',             (greatest(v_solde, 0) % greatest(v_prix, 1))::int,
    'prix_booster',      v_prix);
end $function$
