-- ═══════════════════════════════════════════════════════════════════
-- `roll_rare` REDEVIENT PRIVÉE — le revoke de midi ne suffisait pas
--
-- ⚠️⚠️ **TROUVÉ PAR LA SONDE, PAS PAR LA LECTURE.** La migration
-- `20260829120000_annonces.sql` révoquait `roll_rare` de `public` et de
-- `authenticated`. Appelée en HTTP juste après le push, avec la seule clé
-- anon, elle a répondu **23502 not-null sur user_id** — c'est-à-dire
-- qu'elle S'EST EXÉCUTÉE et qu'elle a tenté son insertion. Un 404
-- (« aucune fonction ») était attendu.
--
-- La cause : **Supabase pose des DEFAULT PRIVILEGES** qui accordent
-- `execute` sur toute nouvelle fonction du schéma `public` **directement à
-- `anon`, `authenticated` et `service_role`** — pas à travers `PUBLIC`.
-- Révoquer de `PUBLIC` ne retire donc rien à `anon`, dont le grant est
-- nominatif. Il fallait le nommer.
--
-- ⚠️ **CE QUE ÇA AURAIT COÛTÉ.** Pour `anon` le trou est inoffensif :
-- `auth.uid()` est nul, l'insertion viole le not-null, rien n'est écrit.
-- Mais la même porte ouverte à un compte CONNECTÉ serait un distributeur
-- de pièces d'argent : la fonction accepte un `workout_id` quelconque,
-- donc l'index `(user_id, raison, workout_id)` ne bloque rien entre deux
-- uuid différents — il suffisait de rappeler avec un uuid neuf jusqu'à ce
-- que le `random()` tombe. C'est exactement le « RNG client farmable » que
-- le §2 du plan interdit, et toute la valeur de cette pièce est sa rareté.
--
-- La leçon, elle, est générale et vaut pour toute fonction interne :
-- **un `revoke ... from public` ne suffit pas sur Supabase.**
--
-- Analyse : ../../tools/rewards/PLAN-ANNONCES.md
-- ═══════════════════════════════════════════════════════════════════

revoke all on function public.roll_rare(uuid) from anon;
revoke all on function public.roll_rare(uuid) from authenticated;
revoke all on function public.roll_rare(uuid) from public;

-- ⚠️ `service_role` la garde : c'est le rôle de l'edge function et des
-- tâches d'administration, jamais un client. Le lui retirer casserait toute
-- reprise côté serveur sans rien protéger de plus — il court-circuite le
-- RLS de toute façon.

-- ⚠️ **ET ON NE COMPTE PAS SUR LE SEUL DROIT.** `cloturer_seance` est
-- `security definer` : elle s'exécute avec les droits de son propriétaire,
-- donc son appel interne à `roll_rare` continue de passer. La défense est
-- double, comme elle doit l'être quand il s'agit d'argent :
--   ① le DROIT — plus personne d'autre que le propriétaire ne l'appelle ;
--   ② l'INDEX — `coin_ledger_gain_unique (user_id, raison, workout_id)`
--      interdit deux pièces sur la même séance, même si l'appel revenait.
