-- ═══════════════════════════════════════════════════════════════════════════
-- LA COMPOSITION D'UN CHAPITRE EXISTE ENFIN AILLEURS QUE DANS DU SWIFT
-- ═══════════════════════════════════════════════════════════════════════════
--
-- VERDICT APPLIQUÉ (29-08, audit de la card ROUTE de la home) : « Chapitre 1 ·
-- étape X sur 9 » est affiché sur l'écran d'accueil, et le 9 n'existait que
-- dans `EcranSpec.parEcran`. Les 22 clés de `reward_rules` ne parlaient ni de
-- chapitre ni d'étape : la seule chose que l'app dise du chemin sur la home
-- n'avait aucune source.
--
-- La loi de la maison est explicite : « les prix vivent en base, pas dans le
-- code — l'app les LIT, elle ne les connaît pas », et « une constante Swift
-- qui double une règle serveur est une bombe à retardement ». La composition
-- d'un chapitre est une règle de jeu au même titre qu'un prix.
--
-- ⚠️⚠️ **CE QUE CETTE MIGRATION NE FAIT PAS, ET IL FAUT LE DIRE** : elle ne
-- tranche PAS « où commence un chapitre ». C'est le vrai blocage
-- (docs/screens/duolingo-chemin.md § 8) : la dérivation par les vraies dates
-- envoie aujourd'hui le chemin au chapitre 5 parce qu'un rang vaut un JOUR
-- et que la base contient des séances vieilles de plusieurs semaines. Aucune
-- de ces clés ne répond à ça — elles disent de quoi un chapitre est FAIT, pas
-- quand il commence. Le chemin reste donc en mode démo tant que cette
-- décision-là n'est pas prise, et le site le dit.
--
-- ⚠️ **ET LE FRONT GARDE LA MAIN SUR LA GÉOMÉTRIE.** La table des nœuds
-- (`EcranSpec.etapes`) est un `static let` calculé au chargement : les
-- positions, le serpentin et l'air entre les pierres en découlent. L'app LIT
-- donc ces règles pour les COMPARER aux siennes et crier si elles divergent —
-- elle ne les applique pas à chaud. Afficher « sur 10 » au-dessus d'un
-- chapitre qui dessine 9 pierres serait exactement la double vérité qu'on
-- cherche à tuer. Le jour où le serveur pilotera la géométrie, c'est une
-- fonction qui changera, pas cette table.
--
-- Aucune table, aucune colonne, aucun index : cinq lignes de configuration.
-- ═══════════════════════════════════════════════════════════════════════════

insert into public.reward_rules (key, value) values
  -- LE CHEMIN COMPLET : cinq chapitres, 45 nœuds, 35 séances.
  ('chemin_chapitres',              '5'::jsonb),
  -- UN CHAPITRE : `S S S ◆ S S S S ☾` — neuf nœuds, dont deux récompenses.
  -- C'est ce nombre-là que la card de la home affiche (« étape X sur 9 »), et
  -- c'est celui qu'on doit pouvoir vérifier au doigt sur la route.
  ('chemin_noeuds_par_chapitre',    '9'::jsonb),
  ('chemin_seances_par_chapitre',   '7'::jsonb),
  -- DEUX RÉCOMPENSES PAR CHAPITRE, PAS PLUS (sa règle du 27-08) : celle du
  -- milieu au rang 3 — pièce sur les chapitres pairs, lune sur les impairs —
  -- et le trésor qui ferme le chapitre au rang 8. Les rangs sont 0-based,
  -- comme `EtapeSpec.n`.
  ('chemin_rang_recompense_milieu', '3'::jsonb),
  ('chemin_rang_tresor',            '8'::jsonb)
on conflict (key) do nothing;
