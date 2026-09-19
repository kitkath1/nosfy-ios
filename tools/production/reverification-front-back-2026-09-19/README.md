# Nouvelle vérification front et backend — 19 septembre 2026

**Suite du même jour :** le défaut de reçu historique décrit dans cette
mesure est corrigé. La nouvelle lecture Supabase et le vrai client Swift sont
testés dans [Stories et historique](../stories-historique-2026-09-19/README.md).
Les résultats ci-dessous conservent l’état observé avant ce correctif.

Demandée après la première passe : tests en arrière-plan, sans téléphone ;
documentation actualisée dans Annonces, Serveur, Flow, Coffre, Cartes et Stories.

## Résultats

| Contrôle | Résultat | Preuve |
|---|---|---|
| Clients Swift réels → Supabase → SwiftData → construction de story | **20 PASS**, un écart historique reproduit séparément | `swift-live.log` |
| Parcours API neuf → sept séances → galets → boosters → cartes → reconnexion | **44 PASS** | `parcours-api.log` |
| Sauvegarde, reçu, migration, séries faites et gardes Welcome Back | **35 PASS** | `fin-seance.log` |
| Outbox, pannes, concurrence et changement de compte | **15 PASS** | `outbox.log` |
| Snapshot et synchronisation Swift | **13 PASS** | `sync.log` |
| Pull, reconnexion et isolation | **9 PASS** | `pull.log` |
| Renouvellement de session et retours tardifs | **15 PASS** | `session.log` |
| Route vide, dates, seuils et fin des 35 séances | **2 × 1 277 PASS** (normal puis `-cheminReel`) | `route.log` |
| Compilation de l’arbre courant, Debug iOS Simulator arm64 | **BUILD SUCCEEDED** | `build.log` |
| Documentation : artefact puis vérification | **23 tests PASS**, livrable identique au build, dix pages sans débordement à 390 px | `doc-artefact-final.log`, `doc-verif-final.log` |

Le nombre de contrôles du parcours API varie avec le nombre de sachets obtenus
par le tirage : 44 dans cette passe, 45 dans la précédente. Ce n’est pas un
contrôle retiré. Les deux identités API et l’identité Swift ont été supprimées.
Le compte personnel et le téléphone n’ont pas été utilisés.

`sources-avant.json` identifie les sources de l’app ; `sources-controle.json`
confirme qu’aucune n’a changé pendant cette vérification. Les tests unitaires
utilisent des transports ou des stockages isolés, indiqués dans leurs journaux.

## Ce que prouve le nouveau banc Swift connecté

`python3 tools/serveur/verif_front_back_live.py` compile les sources réelles :
`SupabaseSession`, `SupabaseSync`, les modèles SwiftData, `OutboxGains`,
`ReglementSeance`, `SacreServeur`, `CartesServeur` et `StorySession`.
Les requêtes HTTP et les décodeurs sont ceux de l’app, sans réponse réseau simulée.

Une seule série faite parmi cinq prévues traverse le snapshot et arrive au
serveur. Le règlement réel reçoit 20 pièces et un sachet, les sauve sur la
séance puis vide la file. La story relit ce reçu. Rejouer la clôture ne change
ni le stock ni sa version. Les annonces portent leurs vrais UUID, sont
acquittées par le client Swift et disparaissent ; le bilan de la story reste
identique malgré `events` vide.

Le Claim quotidien passe par l’outbox réelle : premier paiement au montant
serveur, second sans gain supplémentaire. Le client Cartes reprend la même
opération et le même sachet, la RPC d’attribution conserve un seul exemplaire,
puis les vrais décodeurs Collection et Coffre relisent carte et journal.
L’Edge Function `forge-card` est exercée par le banc API distinct.

L’hôte des vues est remplacé par un récepteur de résultats, le Keychain par une
mémoire privée et les préférences par un domaine jetable. Ce banc valide les
échanges et l’état métier ; il ne prétend pas exercer le montage des vues,
le geste Apple natif, les haptiques ou le thermique. Les deux contrôles UI
simulateur de la première passe restent dans `../fin-seance-2026-09-19/`.

## Écart confirmé : anciennes stories après restauration

Le vrai `SupabaseSync.relire` remplit une nouvelle base locale depuis la séance
réelle. Série et volume sont exacts. **Le reçu de récompenses n’est pas
rechargé** : la story restaurée reste « Récompenses en attente ». Le journal
marque explicitement `ECART CONFIRMÉ`, séparément des 20 assertions réussies.
Les pièces, boosters et cartes restent au serveur ; il manque la lecture du
reçu historique côté app. La brique Stories reste ouverte, avec cette preuve.

## Statuts documentaires

Les appels vérifiés sont verts dans leurs sections respectives, avec ce dossier
comme preuve. Les anciennes lignes disant que la story ne se déclenche pas ou
que le retour au chemin n’existe pas sont corrigées à partir des tests UI déjà
terminés, pas d’une nouvelle mesure sur téléphone.

Les deux robes Welcome Back et les stories FR/EN disposent déjà de preuves
physiques datées du 18-09 ; leurs statuts locaux sont corrigés sans prétendre
avoir refait ces tests. La règle « un galet par séance » est tranchée dans
`CLAUDE.md` depuis le 18-09 : la demande de confirmation périmée est retirée.

Les cartes récapitulatives restent calculées depuis les lignes et les mesures :
une fonction absente, un écart constaté ou une mesure non réalisée ne devient
pas verte parce qu’une autre vérification passe. Restent notamment le reçu
historique, les 36 scènes futures du catalogue de 50, les mesures de chauffe,
le parcours Apple natif et la distribution du binaire final. Cette passe ne
modifie aucun code produit, aucune migration, aucun droit ni contenu distant.

Pas de commit ni de publication demandés. `main` et `origin/main` étaient
alignés à l’arrivée ; l’arbre partagé portait 85 fichiers suivis modifiés.

## Vérification du livrable documentaire

Les captures de l’état général à 1440 et 390 px, ainsi que les pages Serveur
et Stories à 1440 px, ont été regardées. Le nouvel encart de résultats est
lisible ; les points ouverts conservent leur statut. Les captures des six
sections sont conservées dans `captures/`. `git diff --check` passe sur les
chemins de cette vérification. `main` et `origin/main` sont toujours alignés
au contrôle final ; aucun commit ni push effectué.

Fichiers de cette passe : `tools/serveur/verif_front_back_live.py`,
`tools/serveur/tests/front_back_live.swift`, ce dossier de preuves,
`tools/production/fin-seance-2026-09-19/README.md`, `MULTI-SESSION.md`,
`docs/site/content/{briques,mesures,serveur,qa}.ts`, les pages
`docs/site/content/pages/{annonces,flow,coffre,forge,histoire,qa}.mdx`,
les composants `docs/site/components/{Etat,Serveur}.tsx` et le livrable
`docs/site/index.html`. Les fichiers partagés contiennent aussi le travail
des autres sessions ; cette liste n’autorise pas à les committer en bloc.
