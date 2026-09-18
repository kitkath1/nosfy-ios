CREATE OR REPLACE FUNCTION public.convertir_pieces(p_user uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_prix    integer;
  v_solde   integer;
  v_n       integer := 0;
  v_booster uuid;
begin
  if p_user is null then return 0; end if;

  select coalesce((value)::text::integer, 100) into v_prix
    from public.reward_rules where key = 'prix_booster';
  v_prix := greatest(coalesce(v_prix, 100), 1);

  perform pg_advisory_xact_lock(hashtext(p_user::text));

  select coalesce(sum(delta), 0)::int into v_solde
    from public.coin_ledger
   where user_id = p_user and currency = 'yellow';

  while v_solde >= v_prix loop
    if v_n >= 1000 then
      raise warning 'convertir_pieces : borne atteinte pour %, il reste % pièces', p_user, v_solde;
      exit;
    end if;

    insert into public.user_boosters (user_id, origine)
    values (p_user, 'conversion')
    returning id into v_booster;

    insert into public.coin_ledger (user_id, delta, raison, currency, booster_id)
    values (p_user, -v_prix, 'conversion_booster', 'yellow', v_booster);

    v_n     := v_n + 1;
    v_solde := v_solde - v_prix;
  end loop;

  return v_n;
end $function$
