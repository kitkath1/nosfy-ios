-- ════════════════════════════════════════════════════════════════════════
-- LE MÉNAGE DES DORMANTS — 15-09, sur le mot de Kathryn
--
-- Deux choses que personne ne lit ni n'écrit, retirées pour que la carte du serveur
-- ne les traîne plus (« enlève-la alors » · « ah ok donc enlève alors si le retour
-- disponible est bien géré ») :
--
--  ① la table `booster_progress` (wallet_coffre.sql:50-60, 28-08) — le « report » de la
--     conversion, mort depuis 20260830210000 : la conversion est automatique par tranches
--     de 100 et la LIGNE DE PROGRESSION DU COFFRE lit `reste` = solde_or mod prix, calculé
--     par etat_coffre() (conversion_jour_flamme.sql:319 → EconomieWoop.reste →
--     CoffreV2.swift:2543). La ligne à l'écran ne bouge pas.
--  ② les trois clés `welcome_*` de reward_rules (welcome_chaque_connexion.sql:37-44,
--     30-08) — absence requise, pause, maximum par mois. Le POP-UP Welcome Back ne les
--     lit pas : « une fois par jour, +10 » est décidé par etat_coffre().retour_disponible
--     (premiere_arrivee.sql:172-177 : aucune ligne retour_quotidien au jour de la maison)
--     et payé par claim_retour_quotidien. Le pop-up et ses pièces ne bougent pas.
--
-- MESURÉ AVANT LA POSE (15-09, API de gestion, base vivante) :
--   select proname from pg_proc where prosrc ilike '%booster_progress%'  → []
--   select proname from pg_proc where prosrc ilike '%welcome_%'          → []
--   select count(*) from booster_progress                                → 0
--   aucune vue ni règle dépendante (pg_depend / pg_rewrite → 0)
-- Vérification après : tools/serveur/verif_portes.py (booster_progress → 404 PGRST205,
-- reward_rules?key=like.welcome_* → [], le témoin d'existence devient workout_facts).
-- ════════════════════════════════════════════════════════════════════════

drop table if exists public.booster_progress;

delete from public.reward_rules
 where key in ('welcome_absence_jours', 'welcome_cooldown_jours', 'welcome_max_mois');
