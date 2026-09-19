# Première séance et Route — 19 septembre 2026

Nouvelle passe demandée ensuite, sans téléphone : [vérification des vrais clients Swift et du backend](../reverification-front-back-2026-09-19/README.md). Les résultats de cette première passe restent ci-dessous.

Corrections demandées après l’audit TestFlight, puis animation du galet de fin de
séance. Travail dans l’arbre partagé, sans commit, sans installation sur l’iPhone
réservé par la session Erreur et sans upload TestFlight. Catalogue Cartes laissé
à sa session. Aucun utilisateur existant modifié par ces tests.

## Ce qui est corrigé

- **Fermeture pendant l’envoi** : `endedAt` et `recompenseARegler` sont sauvés
  ensemble dans SwiftData. Le marqueur reconstitue l’outbox avant la synchro au
  lancement, à la connexion, au retour réseau et au premier plan. Le reçu sauvé
  acquitte le marqueur ; le serveur assure l’idempotence du même UUID.
- **Story** : seules les séries faites comptent. Aucun set de démonstration
  injecté pour une séance cardio. Pièces, sachets, argent et faits sont attachés
  à la séance ; le total provient du reçu. `booster_ids` reste utilisable après
  acquittement des annonces, alors que `events` devient vide. Sans réponse,
  « Récompenses en attente » remplace le faux montant. Les volumes, répétitions et records de charge excluent les
  lignes non réalisées, y compris les résumés de l’accueil et de la Chambre. Les kcal restent une estimation locale (minutes × 7).
- **Compte neuf** : aucun sachet fictif avant le chargement du serveur. Les
  sachets de maquette sont réservés aux arguments explicites de laboratoire.
- **Welcome Back** : retenu pendant séance active, clôture/story, Route, panneau
  de départ et pause, en plus de l’inscription, première arrivée et manège.
- **Route** : après la story, le galet accompli reçoit un sceau et une onde
  courte, le suivant devient actif. Au changement de chapitre, défilement vers
  le suivant. Réduire les animations pose directement l’état final ; aucun
  timer ou moteur permanent ajouté. `-sansFeteRoute` désactive la séquence.
  Le chevron rend l’accueil, libère les annonces puis propose le booster.
  Une séance avec travail = un galet, même si deux séances le même jour.
  Au-delà de 35, pas de redémarrage ni de faux 36e galet.

## Preuves

| Vérification | Résultat / fichier |
|---|---|
| Modèles SwiftData, arrêt avant réseau, nouveau processus, reçu relu, migration ancienne base, story et gardes Welcome Back | 35 assertions PASS, `fin-seance.log` ; `python3 tools/serveur/verif_fin_seance.py` |
| Outbox réelle : réseau différé, concurrence, changement de compte, nouvelle rétention sans envoi | 15 PASS, `outbox.log` |
| Synchronisation Swift avec transport intercepté | 13 PASS, `sync.log` |
| Route vide, travail réel, seuils 3/7, 35 et 36 séances | 1277 PASS, `route.log` |
| Supabase réel : neuf vide → 7 séances → galets → boosters → cartes → reconnexion ; quotidien idempotent ; reçu après annonces | 45 PASS sur ce passage, `parcours-api.log` ; deux identités QA nettoyées |
| Compilation Debug iOS Simulator arm64 | BUILD SUCCEEDED, `build-final.log` |
| Story → galet, première et septième séance, animations réduites, arrière-plan | 2 tests XCTest PASS, `ui-verification.log` ; captures dans `captures/` |
| Documentation statique | `artefact` puis `verif` PASS, 23 tests, dix pages sans débordement à 390 px ; `doc-verif-final.log` |

Le nombre d’assertions API dépend du nombre de sachets issus du tirage de test.
Le test UI utilise une copie jetable avec un reçu de fixture, pas un compte réel.
Le script `preparer-banc.py` indique exactement ses injections ; aucun hook de
ce banc n’entre dans les sources de production.

## Encore nécessaire avant les premiers testeurs

1. **Stories restaurées après déconnexion/réinstallation** : le reçu local
   survit à une relance, mais le pull des séances ne recharge pas encore
   `bilanRecompense`. Ces stories restent « Récompenses en attente » ; les
   soldes, sachets et cartes restent au serveur. Brancher une lecture
   historique du reçu, puis vérifier ce parcours sans nouveau paiement.
2. **Apple natif** : création d’un compte neuf, relance et reconnexion réelles ;
   échange du code Apple et suppression/révocation. L’audit du 19-09 a trouvé
   Apple configuré, mais aucun jeton Apple stocké ne prouve ce parcours.
3. **iPhone avec le binaire intégré** : première séance → story → galet →
   annonces → booster → carte ; interrompre/reprendre, finir hors ligne puis
   reconnecter ; vérifier le retour du lendemain. Les bancs API et simulateur
   ne valident pas ces gestes, le réseau du téléphone ni les haptiques.
4. **Chauffe** : le verdict QA18 reste ouvert/rouge. Mesure comparative iPhone
   nécessaire, dont l’animation ajoutée ; ne pas déduire le thermique du sim.
5. **Distribution** : figer et identifier les sources communes, archiver le
   binaire final signé, contrôler sa fiche App Store Connect et les métadonnées
   de test, téléverser puis inviter. L’archive79 du 18-09 précède ces corrections.
   Premier build destiné aux testeurs externes : contrôle Beta App Review Apple.
6. **Exploitation backend** : qualifier les 63 diagnostics de sécurité observés
   le 19-09 (ils ne prouvent pas 63 failles), vérifier une restauration ; la
   liste de sauvegardes vide dans l’API ne prouve pas l’absence de sauvegarde.

Aucune migration ni Edge Function changée par cette session. Backend observé
le 19-09 : ACTIVE_HEALTHY, 51 versions de migrations alignées jusqu’à
20260918084850, 6 fonctions ACTIVE. Cela ne clôture pas les contrôles ci-dessus.

## Rejouer le contrôle visuel sans toucher au projet partagé

Copier les dossiers réels `Nosfy`, `NosfyShared`, `NosfyWidgets` et
`Nosfy.xcodeproj` dans un dossier temporaire neuf (depuis le chemin canonique,
pas les symlinks de `woochoper-ios`). Dans cette copie uniquement :

1. Appliquer `tools/nav/fouettage/applique_patch.py` à son `project.pbxproj`.
2. Copier le scheme `tools/nav/fouettage/NosfyUITests.xcscheme` dans
   `Nosfy.xcodeproj/xcshareddata/xcschemes/` et `FinSeanceUITests.swift` dans
   un dossier `NosfyUITests/` de la copie.
3. Exécuter `python3 preparer-banc.py CHEMIN_DE_LA_COPIE` (script de ce dossier).
4. Lancer `xcodebuild test -project Nosfy.xcodeproj -scheme NosfyUITests
   -destination 'platform=iOS Simulator,id=UUID_DU_SIM_DEDIE'
   -derivedDataPath CHEMIN_DERIVED_DATA_ISOLE -resultBundlePath CHEMIN_RESULTAT_NEUF
   CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES` depuis la copie.

La fixture n'est pas une preuve de paiement serveur : elle donne un reçu de
20 pièces et un sachet à une séance avec une série faite parmi cinq.
Les assertions suivent les pages, la validation du galet, le prochain actif
et le retour d'arrière-plan. Le montant WIN animé n'est pas exposé au sélecteur
XCTest de ce rendu : il se contrôle dans les captures, en complément du test
Swift du reçu. Les essais `ui-diagnostic.log` et `ui-final.log` documentent
cet échec de repérage ; ils ne sont pas les résultats de validation finale.

### Lecture finale des captures

- `captures/story-20-un-sachet.png` : +20 pièces et un sachet visibles.
- `captures/route-premier-accompli.png` : première séance datée, galet suivant
  actif et mention « Séance accomplie ».
- `captures/route-sept-reduce.png` : chapitre 2 et état final sans la séquence
  animée (branche Réduire les animations forcée dans la copie de test).
- `captures/qa-1440.png` et `qa-390.png` : liste des six points restants lisible,
  compteur global encore à corriger/valider, aucun passage global au vert.

Les captures attestent les états affichés ; rythme et haptiques restent à juger
sur iPhone. Un rejeu supplémentaire pour filmer la transition (`ui-film.log`)
a été interrompu pendant la préparation Xcode, sans exécution du scénario :
aucune preuve vidéo ajoutée. La validation UI est le passage terminé avec
**2 tests, 0 échec** dans `ui-verification.log`, pas ce rejeu facultatif.
