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
    -- 15-09 soir : le prix de la piscine, LU en base (déjà posé par 20260915160000) — la fiche
    -- piscine lit « pieces_par_longueur » et son plafond au lieu de les connaître en dur.
    'pieces_par_longueur', (
      select coalesce((value)::text::integer, 20) from public.reward_rules
       where key = 'pieces_par_longueur'),
    'cardio_piscine_max', (
      select coalesce((value)::text::integer, 300) from public.reward_rules
       where key = 'cardio_piscine_max'),
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
