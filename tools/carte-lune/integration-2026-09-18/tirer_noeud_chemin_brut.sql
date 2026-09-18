CREATE OR REPLACE FUNCTION public.tirer_noeud_chemin_brut(p_noeud integer, p_pieces boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_deja     boolean := false;
  v_montant  integer := 0;
  v_monnaie  text    := 'yellow';
  v_robes    text[]  := '{}';
  v_rarete   text    := 'common';
  v_secs     integer := 0;
  v_mult     numeric := 1;
  v_pitie    integer;
  v_min      integer;
  v_max      integer;
  v_t_noire  numeric;
  v_t_double numeric;
  v_t_rare   numeric;
  v_faits    integer := 0;
  v_robe     text;
  v_chap     integer;
  v_par      integer;
  v_milieu   integer;
  v_tresor   integer;
  v_rang     integer;
  v_chapitre integer;
begin
  if p_noeud is null then
    raise exception 'tirer_noeud_chemin : il faut le nœud';
  end if;

  -- ── LE NŒUD EST BORNÉ ET RAPPROCHÉ DE SA PISTE (relecture adverse 30-08) ──
  -- Sans ça, tout compte authentifié pouvait appeler (45, true), (46, true),
  -- … (10^9, true) : chaque entier neuf passait les index (user, nœud) et
  -- créditait 100-200 pièces — et 6 % de pièces d'argent. La géométrie du
  -- chemin vit DÉJÀ dans `reward_rules` (migration 20260829170000) : 5
  -- chapitres de 9 nœuds, la récompense du milieu au rang 3 (pièces si le
  -- chapitre est pair, lune = sachets s'il est impair), le trésor au rang 8.
  select coalesce((value)::int, 5) into v_chap
    from public.reward_rules where key = 'chemin_chapitres';
  select coalesce((value)::int, 9) into v_par
    from public.reward_rules where key = 'chemin_noeuds_par_chapitre';
  select coalesce((value)::int, 3) into v_milieu
    from public.reward_rules where key = 'chemin_rang_recompense_milieu';
  select coalesce((value)::int, 8) into v_tresor
    from public.reward_rules where key = 'chemin_rang_tresor';
  v_chap   := coalesce(v_chap, 5);
  v_par    := coalesce(v_par, 9);
  v_milieu := coalesce(v_milieu, 3);
  v_tresor := coalesce(v_tresor, 8);
  if p_noeud < 0 or p_noeud >= v_chap * v_par then
    return jsonb_build_object(
      'deja_reclame', false, 'raison', 'noeud_invalide'::text,
      'solde', public.solde_or(), 'solde_argent', public.solde_argent());
  end if;
  v_rang     := p_noeud % v_par;
  v_chapitre := p_noeud / v_par;
  if not ((v_rang = v_tresor and not p_pieces)
          or (v_rang = v_milieu and p_pieces = (v_chapitre % 2 = 0))) then
    return jsonb_build_object(
      'deja_reclame', false, 'raison', 'piste_invalide'::text,
      'solde', public.solde_or(), 'solde_argent', public.solde_argent());
  end if;

  -- ── DÉJÀ RÉCLAMÉ ? On rend ce qui a été tiré, tel quel. ──
  if p_pieces then
    select delta, currency into v_montant, v_monnaie
      from public.coin_ledger
     where user_id = auth.uid() and raison = 'chemin' and noeud_id = p_noeud
     limit 1;
    if found then
      return jsonb_build_object(
        'deja_reclame', true, 'type', 'coins'::text,
        'montant', v_montant, 'monnaie', v_monnaie,
        'robes', '[]'::jsonb,
        'rarete', case when v_monnaie = 'silver' then 'legendary'::text
                       else 'common'::text end,
        'solde', public.solde_or(), 'solde_argent', public.solde_argent());
    end if;
  else
    -- ⚠️ Les deux lignes naissent dans la MÊME transaction (même `now()`) :
    -- `obtained_at` ne les départage pas — la ligne `chemin` (première
    -- robe tirée) passe avant la ligne `cadeau`, comme au tirage.
    select array_agg(coalesce(robe, 'lune') order by (origine = 'cadeau'), obtained_at)
      into v_robes
      from public.user_boosters
     where user_id = auth.uid() and origine in ('chemin', 'cadeau')
       and noeud_id = p_noeud;
    if v_robes is not null and array_length(v_robes, 1) > 0 then
      return jsonb_build_object(
        'deja_reclame', true, 'type', 'boosters'::text,
        'montant', 0::integer, 'monnaie', 'yellow'::text,
        'robes', to_jsonb(v_robes),
        'rarete', case when 'noire' = all(v_robes) then 'legendary'::text
                       when 'noire' = any(v_robes) then 'rare'::text
                       else 'common'::text end,
        'solde', public.solde_or(), 'solde_argent', public.solde_argent());
    end if;
  end if;

  -- ── LES RÈGLES, lues en base (avec les défauts du client si absentes) ──
  select coalesce((value)::numeric, 0.06) into v_t_noire
    from public.reward_rules where key = 'chemin_taux_piece_noire';
  select coalesce((value)::numeric, 0.01) into v_t_double
    from public.reward_rules where key = 'chemin_taux_double_legendaire';
  select coalesce((value)::numeric, 0.11) into v_t_rare
    from public.reward_rules where key = 'chemin_taux_rare';
  select coalesce((value)::int, 12) into v_pitie
    from public.reward_rules where key = 'chemin_pitie';
  select coalesce((value)::int, 100) into v_min
    from public.reward_rules where key = 'chemin_pieces_min';
  select coalesce((value)::int, 200) into v_max
    from public.reward_rules where key = 'chemin_pieces_max';
  v_t_noire  := coalesce(v_t_noire, 0.06);
  v_t_double := coalesce(v_t_double, 0.01);
  v_t_rare   := coalesce(v_t_rare, 0.11);
  v_pitie    := coalesce(v_pitie, 12);
  v_min      := coalesce(v_min, 100);
  v_max      := coalesce(v_max, 200);

  -- ── LA PITIÉ, DÉRIVÉE : les communs d'affilée depuis le dernier non-commun ──
  if p_pieces then
    select count(*) into v_secs
      from public.coin_ledger cl
     where cl.user_id = auth.uid() and cl.raison = 'chemin'
       and cl.currency = 'yellow'
       and cl.created_at > coalesce(
         (select max(created_at) from public.coin_ledger
           where user_id = auth.uid() and raison = 'chemin'
             and currency = 'silver'),
         '-infinity'::timestamptz);
  else
    select count(distinct ub.noeud_id) into v_secs
      from public.user_boosters ub
     where ub.user_id = auth.uid() and ub.origine in ('chemin', 'cadeau')
       and ub.obtained_at > coalesce(
         (select max(obtained_at) from public.user_boosters
           where user_id = auth.uid() and origine in ('chemin', 'cadeau')
             and robe = 'noire'),
         '-infinity'::timestamptz);
  end if;
  -- La même courbe que le client : ×2 par nœud au-delà du seuil.
  v_mult := power(2::numeric, greatest(0, v_secs - v_pitie + 1));

  -- ── LE TIRAGE, ici et nulle part ailleurs ──
  if p_pieces then
    if random() < least(1::numeric, v_t_noire * v_mult) then
      v_montant := 1; v_monnaie := 'silver'; v_rarete := 'legendary';
    else
      v_montant := v_min + floor(random() * (v_max - v_min + 1))::int;
      v_monnaie := 'yellow'; v_rarete := 'common';
    end if;
    begin
      insert into public.coin_ledger (user_id, delta, raison, currency, noeud_id)
        values (auth.uid(), v_montant, 'chemin', v_monnaie, p_noeud);
    exception when unique_violation then
      -- LA COURSE (deux requêtes en vol, deux appareils) : l'index a parlé,
      -- on rend ce qui a été ÉCRIT par le gagnant — jamais le tirage neuf
      -- que l'index vient de refuser (relecture adverse 30-08).
      v_deja := true;
      select delta, currency into v_montant, v_monnaie
        from public.coin_ledger
       where user_id = auth.uid() and raison = 'chemin' and noeud_id = p_noeud
       limit 1;
      v_rarete := case when v_monnaie = 'silver' then 'legendary' else 'common' end;
    end;
    return jsonb_build_object(
      'deja_reclame', v_deja, 'type', 'coins'::text,
      'montant', v_montant, 'monnaie', v_monnaie,
      'robes', '[]'::jsonb, 'rarete', v_rarete,
      'solde', public.solde_or(), 'solde_argent', public.solde_argent());
  end if;

  if random() < least(1::numeric, v_t_double * v_mult) then
    v_robes := array['noire', 'noire']; v_rarete := 'legendary';
  elsif random() < least(1::numeric, v_t_rare * v_mult) then
    v_robes := array['lune', 'noire']; v_rarete := 'rare';
  else
    v_robes := array['lune', 'lune']; v_rarete := 'common';
  end if;
  -- Deux sachets sous un index (user, nœud) : la première robe fait la ligne
  -- du nœud, la seconde est un `cadeau` rattaché au même nœud — le
  -- contournement déjà en place, lisible et jamais dupliqué.
  foreach v_robe in array v_robes loop
    begin
      insert into public.user_boosters (user_id, origine, noeud_id, robe)
        values (auth.uid(),
                case when v_faits = 0 then 'chemin' else 'cadeau' end,
                p_noeud, v_robe);
      v_faits := v_faits + 1;
    exception when unique_violation then
      v_deja := true;
      exit;
    end;
  end loop;
  if v_deja then
    -- LA COURSE : on rend les robes ÉCRITES par le gagnant, pas les nôtres.
    -- ⚠️ Les deux lignes naissent dans la MÊME transaction (même `now()`) :
    -- `obtained_at` ne les départage pas — la ligne `chemin` (première
    -- robe tirée) passe avant la ligne `cadeau`, comme au tirage.
    select array_agg(coalesce(robe, 'lune') order by (origine = 'cadeau'), obtained_at)
      into v_robes
      from public.user_boosters
     where user_id = auth.uid() and origine in ('chemin', 'cadeau')
       and noeud_id = p_noeud;
    v_robes  := coalesce(v_robes, '{}');
    v_rarete := case when 'noire' = all(v_robes) then 'legendary'
                     when 'noire' = any(v_robes) then 'rare'
                     else 'common' end;
  end if;

  return jsonb_build_object(
    'deja_reclame', v_deja, 'type', 'boosters'::text,
    'montant', 0::integer, 'monnaie', 'yellow'::text,
    'robes', to_jsonb(v_robes), 'rarete', v_rarete,
    'solde', public.solde_or(), 'solde_argent', public.solde_argent());
end $function$
