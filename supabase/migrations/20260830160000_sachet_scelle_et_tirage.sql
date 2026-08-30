-- ═══════════════════════════════════════════════════════════════════════════
-- UN SACHET = UNE CARTE, LE NOIR SE CONSOMME, ET LE CHEMIN TIRE AU SERVEUR
-- ═══════════════════════════════════════════════════════════════════════════
--
-- VERDICT APPLIQUÉ (30-08, Kathryn : « corrige tout ça ») — les quatre trous
-- de tools/sacre/ANALYSE-FLOW-BACKEND-BOOSTER.md (§2.4, §4.7, §4.8), le plan
-- dans tools/sacre/PLAN-BACKEND-BOOSTER-FIXES.md :
--
--   1. la forge n'était pas reliée au sachet (le client n'envoyait pas
--      `booster_id`) : aucun scellement, aucune idempotence du tirage, la
--      garantie légendaire du noir jamais armée ;
--   2. `claim_booster_legendaire` répondait 500 sur un refus métier et
--      rendait une LIGNE là où l'autre porte rend du jsonb ;
--   3. la pile noire ne se consommait jamais (`ouvrir_booster(true)` exige
--      `opened_at is null`, un légendaire naît OUVERT) ;
--   4. le tirage du chemin et sa pitié vivaient au client.
--
-- Et la relecture adverse du 30-08 (trois lentilles : pose, argent, client),
-- appliquée AVANT la pose : la course sur un nœud rend le STOCKÉ (§4), la
-- reprise orange est bornée à six heures (§3), le nœud est borné et
-- rapproché de sa piste (§4), `etat_coffre` montre les sachets ouverts non
-- scellés (§5), et l'ancienne `reclamer_noeud_chemin` ne croit plus le
-- client (§6). Côté fonction edge, `forge-card` scelle AVANT de créditer la
-- collection (déployée par `supabase functions deploy forge-card`).
--
-- Ce fichier ne crée ni table, ni colonne, ni index : les index d'unicité
-- existants (user_boosters_noir_ouvert_unique, user_boosters_chemin_unique,
-- coin_ledger_chemin_unique) tiennent toute l'idempotence.
--
-- ⚠️ ORDRE : les clés de reward_rules AVANT la fonction qui les lit ; le
-- `drop function` AVANT le `create` qui change un type de retour (un
-- `create or replace` refuse « cannot change return type » — la pose casse).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. LES TAUX DU CHEMIN VIVENT EN BASE ────────────────────────────────────
--
-- Les mêmes nombres que `RewardChemin.TirageRecompense` (le client), et pour
-- les mêmes raisons (deux récompenses par chapitre, cinq chapitres) : pièce
-- noire 6 %, double légendaire 1 %, rare 11 %, pitié après 12 communs
-- (le taux DOUBLE à chaque nœud suivant), pièces jaunes de 100 à 200.
-- `where not exists` plutôt qu'`on conflict` : on ne présume pas de la
-- contrainte d'unicité de `key` — une clause `on conflict` sans index
-- correspondant casse À LA POSE.
insert into public.reward_rules (key, value)
select k, v::jsonb from (values
  ('chemin_taux_piece_noire',        '0.06'),
  ('chemin_taux_double_legendaire',  '0.01'),
  ('chemin_taux_rare',               '0.11'),
  ('chemin_pitie',                   '12'),
  ('chemin_pieces_min',              '100'),
  ('chemin_pieces_max',              '200')
) as t(k, v)
where not exists (select 1 from public.reward_rules r where r.key = t.k);

-- ── 2. `claim_booster_legendaire` — 200 avec un motif, en jsonb ─────────────
--
-- ⚠️ LE TYPE DE RETOUR CHANGE (`user_boosters` → `jsonb`) : `drop` d'abord.
-- La sémantique ne bouge pas : idempotente sur un légendaire OUVERT NON
-- SCELLÉ (elle le rend tel quel), sinon vérifie la pièce d'argent, crée le
-- sachet ouvert et débite — dans la même transaction. C'est ELLE la
-- consommation du booster noir (le client n'appelle plus `ouvrir_booster
-- (true)` pour le noir).
drop function if exists public.claim_booster_legendaire();

create function public.claim_booster_legendaire()
returns jsonb
language plpgsql security definer set search_path = public as $$
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
end $$;

revoke all on function public.claim_booster_legendaire() from public;
revoke all on function public.claim_booster_legendaire() from anon;
grant execute on function public.claim_booster_legendaire() to authenticated;

-- ── 3. `ouvrir_booster` — la reprise d'un sachet ouvert non scellé ──────────
--
-- Même signature (pas de drop, les grants restent). Ce qui change : AVANT
-- d'ouvrir un sachet neuf, on rend celui qui est déjà OUVERT et PAS ENCORE
-- SCELLÉ dans la même pile — le cas exact d'un quit entre la consommation et
-- la forge. Un client qui rappelle sans savoir retombe sur le même id, et la
-- forge (idempotente au sachet) rend la même carte. Sans ça, chaque relance
-- ouvrait un sachet de plus.
create or replace function public.ouvrir_booster(
  p_legendaire boolean default false
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  -- ⚠️ LA FENÊTRE (relecture adverse 30-08) : avant cette migration, aucun
  -- manège n'a jamais scellé son sachet — chaque compte porte des ORPHELINS
  -- (ouverts, sans carte). Sans borne, les N prochaines ouvertures les
  -- rendraient un par un et le compteur `boosters_or` ne descendrait pas
  -- pendant N sachets. La reprise ne vise qu'un quit entre la consommation
  -- et la forge : six heures, pas l'histoire du compte.
  select id into v_id
    from public.user_boosters
   where user_id = auth.uid()
     and opened_at is not null
     and opened_at > now() - interval '6 hours'
     and card_id is null
     and (case when p_legendaire then origine = 'legendaire'
                                 else origine <> 'legendaire' end)
   order by opened_at desc
   limit 1;
  if v_id is not null then
    return jsonb_build_object('ouvert', true, 'booster_id', v_id, 'reprise', true);
  end if;

  select id into v_id
    from public.user_boosters
   where user_id = auth.uid()
     and opened_at is null
     and (case when p_legendaire then origine = 'legendaire'
                                 else origine <> 'legendaire' end)
   order by obtained_at asc
   limit 1
     for update skip locked;

  if v_id is null then
    return jsonb_build_object('ouvert', false, 'raison', 'aucun_sachet'::text);
  end if;

  update public.user_boosters
     set opened_at = now()
   where id = v_id;

  return jsonb_build_object('ouvert', true, 'booster_id', v_id, 'reprise', false);
end $$;

-- ── 4. `tirer_noeud_chemin` — le tirage ET la pitié au serveur ──────────────
--
-- « Ce qu'on ne croit jamais du client : un tirage de récompense, un
-- compteur de pitié. » Le client ne dit plus que le NŒUD et la PISTE ; le
-- serveur tire (`random()`), lit ses taux dans `reward_rules`, DÉRIVE la
-- pitié du journal (jamais un compteur : combien de nœuds communs d'affilée
-- sur la piste depuis le dernier non-commun), écrit, et rend le résultat.
-- Rejoué (timeout, double tap, réinstallation) : il rend le résultat STOCKÉ
-- — jamais un second tirage.
--
-- L'ancienne `reclamer_noeud_chemin(p_noeud, p_pieces, p_monnaie, p_boosters)`
-- reste en place : l'outbox peut encore porter un nœud tiré avant cette
-- version. Le client ne la poste plus.
create or replace function public.tirer_noeud_chemin(
  p_noeud  integer,
  p_pieces boolean
)
returns jsonb
language plpgsql security definer set search_path = public as $$
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
end $$;

revoke all on function public.tirer_noeud_chemin(integer, boolean) from public;
revoke all on function public.tirer_noeud_chemin(integer, boolean) from anon;
grant execute on function public.tirer_noeud_chemin(integer, boolean) to authenticated;

-- ── 5. `etat_coffre` — les sachets ouverts non scellés SE VOIENT ────────────
--
-- Relecture adverse 30-08 : consommer AVANT de forger crée un état « ouvert,
-- pas scellé » que l'app ne voyait pas (`boosters_or` = `opened_at is null`,
-- noirs = solde d'argent, déjà débité). Si la forge ne scelle pas (app tuée
-- pendant la peinture, 500, timeout), le compte tombait à 0, la porte du
-- manège se fermait, et la reprise n'était plus jamais déclenchée : sachet
-- payé dans le vide. Désormais `boosters_or` compte aussi l'orange ouvert
-- non scellé des six dernières heures (LA MÊME fenêtre que la reprise de
-- `ouvrir_booster`, §3 — deux nombres, une règle), et `noirs_ouverts` dit
-- le noir payé non scellé (au plus un, par l'index), sans fenêtre comme sa
-- reprise (§2). Même signature, même type : `create or replace`.
create or replace function public.etat_coffre()
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'solde_or', (
      select coalesce(sum(delta), 0)::int from public.coin_ledger
       where user_id = auth.uid() and currency = 'yellow'),
    'solde_argent', (
      select coalesce(sum(delta), 0)::int from public.coin_ledger
       where user_id = auth.uid() and currency = 'silver'),
    'boosters_or', (
      select count(*)::int from public.user_boosters
       where user_id = auth.uid() and origine <> 'legendaire'
         and (opened_at is null
              or (card_id is null
                  and opened_at > now() - interval '6 hours'))),
    'noirs_ouverts', (
      select count(*)::int from public.user_boosters
       where user_id = auth.uid() and origine = 'legendaire'
         and opened_at is not null and card_id is null),
    'reste', (
      select (greatest((select coalesce(sum(delta), 0)::int
                          from public.coin_ledger
                         where user_id = auth.uid() and currency = 'yellow'), 0)
              % greatest((select coalesce((value)::text::integer, 100)
                            from public.reward_rules
                           where key = 'prix_booster'), 1))::int),
    'prix_booster', (
      select coalesce((value)::text::integer, 100) from public.reward_rules
       where key = 'prix_booster'),
    'pieces_par_serie', (
      select coalesce((value)::text::integer, 20) from public.reward_rules
       where key = 'pieces_par_serie')
  );
$$;

-- ── 6. `reclamer_noeud_chemin` — l'ancienne porte ne croit plus le client ───
--
-- Relecture adverse 30-08 : elle restait grantée à `authenticated` avec le
-- montant, la monnaie et les robes DICTÉS par l'appelant —
-- `reclamer_noeud_chemin(9999, 1000000, 'silver', '{}')` créditait un
-- million de pièces d'argent, et remonter le tirage dans §4 ne protégeait
-- rien tant qu'elle était ouverte. On ne la révoque pas (l'outbox d'une
-- version antérieure peut encore porter un nœud, et un 4xx sur une entrée
-- de file « crie ») : elle DÉLÈGUE à `tirer_noeud_chemin` en ignorant tout
-- ce que le client raconte sauf le nœud et la piste, et rend la même forme
-- qu'avant (`deja_reclame`, `boosters`, `solde`, `solde_argent`).
create or replace function public.reclamer_noeud_chemin(
  p_noeud    integer,
  p_pieces   integer default 0,
  p_monnaie  text    default 'yellow',
  p_boosters text[]  default '{}'
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v jsonb;
begin
  if p_noeud is null then
    raise exception 'reclamer_noeud_chemin : il faut le nœud';
  end if;
  -- La piste : des pièces si le client en annonçait, des sachets sinon.
  -- Le MONTANT et les ROBES, eux, sont tirés par le serveur.
  v := public.tirer_noeud_chemin(p_noeud, coalesce(p_pieces, 0) > 0);
  return jsonb_build_object(
    'deja_reclame', coalesce((v->>'deja_reclame')::boolean, false),
    'boosters',     case when v->>'type' = 'boosters'
                         then jsonb_array_length(coalesce(v->'robes', '[]'::jsonb))
                         else 0 end,
    'raison',       v->>'raison',
    'solde',        public.solde_or(),
    'solde_argent', public.solde_argent());
end $$;
