-- ════════════════════════════════════════════════════════════════════════
-- LA PREMIÈRE ARRIVÉE SUR LA HOME — 13-09 soir, sur son « go » (plan compte § 6)
--
-- S1 `profils.visite_home_le` : la mémoire de la visite guidée (une réinstallation
--    ne la rejoue pas ; qui a vu la visite, quand).
-- S2 `marquer_visite_home()` : pose la date UNE fois, crée la ligne si elle manque,
--    rend profil().
-- S3 `profil()` rend `visite_home` ; `home()` rend `premiere_fois` (onboarding fini
--    et aucune séance finie) et `visite_home`.
-- S4 `etat_coffre.retour_disponible` est FAUX tant qu'aucune séance n'est finie, et
--    `claim_retour_quotidien` refuse de même (`premiere_seance_requise`) — le Welcome
--    Back n'a rien à fêter le soir de la première arrivée, et le refus côté claim
--    empêche d'encaisser le +10 en contournant l'écran.
--
-- Les quatre fonctions sont reprises de leurs définitions VIVES (pg_get_functiondef)
-- par remplacements assertés (scratchpad premiere-arrivee.py) ; rien retiré, rien
-- renommé. Droits inchangés (CREATE OR REPLACE garde les privilèges).
-- ════════════════════════════════════════════════════════════════════════

alter table public.profils add column if not exists visite_home_le timestamptz;
comment on column public.profils.visite_home_le is
  'La visite guidée de la home a été faite (date). Posée UNE fois par marquer_visite_home() ; null = jamais vue. Une réinstallation ne rejoue pas la visite.';

create or replace function public.marquer_visite_home()
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'raison', 'sans_session');
  end if;
  insert into public.profils (user_id, visite_home_le, updated_at)
  values (v_uid, now(), now())
  on conflict (user_id) do update
    set visite_home_le = coalesce(public.profils.visite_home_le, now()),
        updated_at     = now();
  return public.profil() || jsonb_build_object('ok', true);
end;
$$;
revoke execute on function public.marquer_visite_home() from public, anon;
grant  execute on function public.marquer_visite_home() to authenticated;
comment on function public.marquer_visite_home() is
  'La visite guidée de la home est faite : pose profils.visite_home_le UNE fois (jamais réécrite ; la ligne est créée si elle manque) et rend profil() + ok. Appelée par l''app au dernier tap de la visite (première arrivée, 13-09).';

CREATE OR REPLACE FUNCTION public.profil()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  p public.profils%rowtype;
  v_exos jsonb;
  v_seances integer;
  v_cree timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into p from public.profils where user_id = v_uid;
  select coalesce(jsonb_agg(e.exercise_id order by e.position, e.choisi_at), '[]'::jsonb)
    into v_exos from public.exercices_choisis e where e.user_id = v_uid;
  select count(*) into v_seances from public.workouts w where w.user_id = v_uid and w.ended_at is not null;
  select u.created_at into v_cree from auth.users u where u.id = v_uid;
  return jsonb_build_object(
    'existe',             p.user_id is not null,
    'onboarding_termine', p.onboarding_termine_at is not null,   -- l'aiguillage : true → la home direct
    'langue',             p.langue,
    'prenom',             p.prenom,
    'but',                p.but,
    'objectif_hebdo',     public.objectif_hebdo(),
    'exercices',          v_exos,
    'seances',            v_seances,
    'compte_cree_at',     v_cree,
    'onboarding_termine_at', p.onboarding_termine_at,
    'visite_home',        p.visite_home_le is not null,   -- 13-09 : la visite guidée est faite
    'visite_home_le',     p.visite_home_le
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.home()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  p public.profils%rowtype;
  r jsonb;
  v_enc timestamptz;
  v_total integer;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into p from public.profils where user_id = v_uid;
  r := public.widget_regularite('semaine');
  select w.started_at into v_enc from public.workouts w
   where w.user_id = v_uid and w.ended_at is null order by w.started_at desc limit 1;
  select count(*) into v_total from public.workouts w where w.user_id = v_uid and w.ended_at is not null;
  return jsonb_build_object(
    'prenom',             p.prenom,
    -- 13-09 : la première arrivée (onboarding fini, aucune séance) et la visite guidée
    'premiere_fois',      p.onboarding_termine_at is not null and v_total = 0,
    'visite_home',        p.visite_home_le is not null,
    'onboarding_termine', p.onboarding_termine_at is not null,
    'faites',             r->'faites',
    'objectif',           r->'objectif',
    'reste',              r->'reste',
    'en_seance',          v_enc is not null,
    'minutes_en_seance',  case when v_enc is null then 0 else floor(extract(epoch from (now() - v_enc)) / 60)::int end,
    'derniere_seance_at', (select max(w.ended_at) from public.workouts w where w.user_id = v_uid and w.ended_at is not null),
    'seances_total',      v_total
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.etat_coffre()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
       where key = 'pieces_par_serie'),
    -- NOUVEAU (30-08 soir, cette migration) : le montant du retour quotidien,
    -- lu dans la règle — plus jamais une constante Swift.
    'pieces_retour_quotidien', (
      select coalesce((value)::text::integer, 10) from public.reward_rules
       where key = 'pieces_retour_quotidien'),
    -- 20260830210000
    'jour', public.jour_courant(),
    -- 13-09 (première arrivée) : rien à fêter tant qu'aucune séance n'est finie
    'retour_disponible', (
      exists (select 1 from public.workouts w where w.user_id = auth.uid() and w.ended_at is not null)
      and not exists (
        select 1 from public.coin_ledger
         where user_id = auth.uid() and raison = 'retour_quotidien'
           and jour = public.jour_courant())),
    'retour_prochain', (
      ((public.jour_courant() + 1)::timestamp at time zone public.fuseau_jour())),
    'flamme', public.flamme()
  );
$function$
;

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
;
