-- ═══════════════════════════════════════════════════════════════════════════
-- 20260830220000 — `etat_coffre()` rend le MONTANT du retour quotidien
--
-- VERDICT APPLIQUÉ : la loi de la maison — « l'app LIT les prix, elle ne les
-- connaît pas » (SKILL woop-backend §1). Le +10 du Welcome Back vivait par
-- cœur DEUX fois dans l'app (ExerciseDetailView.swift:2270,
-- EconomieWoop.swift:121 — site : b-coffre-montant-retour 🔵) alors que la
-- règle `pieces_retour_quotidien` est en base depuis le 28-08. Demandé par la
-- session du coffre (§29.16) le 30-08 au soir, pour que l'horloge du +10 et la
-- card Welcome Back disent le nombre du serveur.
--
-- Même signature, même type : `create or replace`, ordonnée APRÈS
-- 20260830210000 (elle en garde toutes les clés — `jour`, `retour_disponible`,
-- `retour_prochain`, `flamme`). Rien d'écrit, rien de révoqué.
-- Sonde : tools/annonces/verif_backend_coffre.py [0] (la clé existe, = la règle).
-- ═══════════════════════════════════════════════════════════════════════════

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
       where key = 'pieces_par_serie'),
    -- NOUVEAU (30-08 soir, cette migration) : le montant du retour quotidien,
    -- lu dans la règle — plus jamais une constante Swift.
    'pieces_retour_quotidien', (
      select coalesce((value)::text::integer, 10) from public.reward_rules
       where key = 'pieces_retour_quotidien'),
    -- 20260830210000
    'jour', public.jour_courant(),
    'retour_disponible', (
      not exists (
        select 1 from public.coin_ledger
         where user_id = auth.uid() and raison = 'retour_quotidien'
           and jour = public.jour_courant())),
    'retour_prochain', (
      ((public.jour_courant() + 1)::timestamp at time zone public.fuseau_jour())),
    'flamme', public.flamme()
  );
$$;

grant execute on function public.etat_coffre() to authenticated;
