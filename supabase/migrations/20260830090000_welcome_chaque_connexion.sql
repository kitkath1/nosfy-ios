-- ═══════════════════════════════════════════════════════════════════════════
-- LE WELCOME BACK N'ATTEND PLUS QUATRE JOURS : IL EST LÀ À CHAQUE CONNEXION
-- ═══════════════════════════════════════════════════════════════════════════
--
-- VERDICT APPLIQUÉ (30-08) : « le welcome back, c'est à CHAQUE CONNEXION, pas
-- tous les 4 jours, et UNE FOIS PAR JOUR ».
--
-- Analyse : tools/rewards/ANALYSE-WELCOME-BACK.md
--
-- CE QUI NE CHANGE PAS, ET C'EST L'ESSENTIEL : l'argent faisait DÉJÀ ce qu'elle
-- demande. `claim_retour_quotidien()` verse `pieces_retour_quotidien` et sa
-- garde est l'index partiel `coin_ledger_retour_jour_unique (user_id, jour)` —
-- donc une fois par jour calendaire, quoi que fasse l'écran, et un second appel
-- rend `credite: false` au lieu d'une erreur. Cette migration n'y touche pas.
--
-- CE QUI CHANGE : les trois règles qui bridaient la CARD, posées le 29-08.
-- Elles disaient « il faut 4 jours d'absence, 14 jours de pause, 2 par mois au
-- plus ». Elles disent maintenant « à chaque connexion, sans pause, au plus une
-- par jour ».
--
-- ⚠️ AUCUNE LIGNE DE SWIFT NE LIT ENCORE CES CLÉS (grep sur tout le dépôt) :
-- la card n'a pas de porte de production, elle ne vit qu'au banc. On change
-- donc la règle AVANT que la porte ne l'applique, ce qui est le bon ordre —
-- et ça ne peut rien casser aujourd'hui.
--
-- ⚠️ POURQUOI 31 ET NON « ILLIMITÉ » : la clé est un nombre, et la porte qui la
-- lira doit pouvoir écrire `count < welcome_max_mois` sans cas particulier.
-- 31 est le plus grand nombre de jours d'un mois : c'est « un par jour »
-- exprimé dans l'unité de la clé, pas une désactivation déguisée.
--
-- Aucune table, aucune colonne, aucun index, aucune fonction : trois valeurs.
-- ═══════════════════════════════════════════════════════════════════════════

-- ⚠️ `do update`, PAS `do nothing` : les trois clés existent déjà (migration
-- 20260829120000). Un `do nothing` laisserait les anciennes valeurs en place et
-- la migration passerait en silence — le pire des deux mondes.
insert into public.reward_rules (key, value) values
  -- aucune absence requise : la card peut se montrer à chaque connexion
  ('welcome_absence_jours',  '0'::jsonb),
  -- aucune pause entre deux
  ('welcome_cooldown_jours', '0'::jsonb),
  -- au plus une par jour : 31 = le plus grand nombre de jours d'un mois
  ('welcome_max_mois',       '31'::jsonb)
on conflict (key) do update set value = excluded.value;
