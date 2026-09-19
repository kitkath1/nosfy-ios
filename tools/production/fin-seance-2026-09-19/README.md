# Première séance et Route — 19 septembre 2026

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
  « Récompenses en attente » remplace le faux montant. Les volumes excluent les
  lignes non réalisées. Les kcal restent une estimation locale (minutes × 7).
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
| Modèles SwiftData, arrêt avant réseau, nouveau processus, reçu relu, migration ancienne base, story et gardes Welcome Back | 31 assertions PASS, `fin-seance.log` ; `python3 tools/serveur/verif_fin_seance.py` |
| Outbox réelle : réseau différé, concurrence, changement de compte, nouvelle rétention sans envoi | 15 PASS, `outbox.log` |
| Synchronisation Swift avec transport intercepté | 12 PASS, `sync.log` |
| Route vide, travail réel, seuils 3/7, 35 et 36 séances | 1277 PASS, `route.log` |
| Supabase réel : neuf vide → 7 séances → galets → boosters → cartes → reconnexion ; quotidien idempotent ; reçu après annonces | 45 PASS sur ce passage, `parcours-api.log` ; deux identités QA nettoyées |
| Build et rendu de l’animation | Vérification en cours : `build-sim.log`, `ui.log` |

Le nombre d’assertions API dépend du nombre de sachets issus du tirage de test.
Le test UI utilise une copie jetable avec un reçu de fixture, pas un compte réel.
Le script `preparer-banc.py` indique exactement ses injections ; aucun hook de
ce banc n’entre dans les sources de production.

## Encore nécessaire avant les premiers testeurs

1. **Apple natif** : création d’un compte neuf, relance et reconnexion réelles ;
   échange du code Apple et suppression/révocation. L’audit du 19-09 a trouvé
   Apple configuré, mais aucun jeton Apple stocké ne prouve ce parcours.
2. **iPhone avec le binaire intégré** : première séance → story → galet →
   annonces → booster → carte ; interrompre/reprendre, finir hors ligne puis
   reconnecter ; vérifier le retour du lendemain. Les bancs API et simulateur
   ne valident pas ces gestes, le réseau du téléphone ni les haptiques.
3. **Chauffe** : le verdict QA18 reste ouvert/rouge. Mesure comparative iPhone
   nécessaire, dont l’animation ajoutée ; ne pas déduire le thermique du sim.
4. **Distribution** : figer et identifier les sources communes, archiver le
   binaire final signé, contrôler sa fiche App Store Connect et les métadonnées
   de test, téléverser puis inviter. L’archive79 du 18-09 précède ces corrections.
   Premier build destiné aux testeurs externes : contrôle Beta App Review Apple.
5. **Exploitation backend** : qualifier les 63 diagnostics de sécurité observés
   le 19-09 (ils ne prouvent pas 63 failles), vérifier une restauration ; la
   liste de sauvegardes vide dans l’API ne prouve pas l’absence de sauvegarde.

Aucune migration ni Edge Function changée par cette session. Backend observé
le 19-09 : ACTIVE_HEALTHY, 51 versions de migrations alignées jusqu’à
20260918084850, 6 fonctions ACTIVE. Cela ne clôture pas les contrôles ci-dessus.
