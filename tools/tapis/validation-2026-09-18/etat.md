# Molette cardio et Welcome Back — 18 septembre 2026

## Changements

- TapisScene : contact sans seuil de déplacement ; bande tactile pleine largeur
  remontée jusqu'à 44 points au-dessus du disque et descendue à 6 points du
  slider Finish. Le chrono reste devant dans le chevauchement.
- Le tap ouvre sans changer ni confirmer une vitesse. Repli après 2,4 secondes
  sans changement ; 0,55 seconde après réglage. Glissement continu depuis le
  point de contact ; les écritures du modèle restent limitées aux crans.
- Fin et annulation du geste protégées contre les doubles validations.
  Les anciens rappels de fumée ne peuvent plus effacer une nouvelle prise.
- RewardPopup : `reward-welcome` par défaut pour `.welcome` / `.video`.
  Les vidéos explicites de première arrivée gardent la priorité ; `.texte`
  reste la seconde variante. Aucun changement de la règle de Claim.
- Catalogue : retrait de `pop-welcome-back-prod` du manifeste et des scripts
  de capture. Les deux robes conservées sont vidéo et texte géant.

## Vérifications déjà réalisées

- Compilation Debug simulateur de l'application et du runner terminée.
- Documentation : export Webpack + inliner réussi (1 852 513 octets),
  TypeScript et 23 tests réussis. Contrôle du livrable : exactement les deux
  entrées Welcome Back, absence de la troisième.
- Turbopack refuse l'ouverture d'un port local, y compris lors de la reprise
  élevée ; génération réussie avec Webpack, sans modification de configuration.
- Premier essai navigateur : les images lazy hors écran n'étaient pas encore
  chargées lors de l'assertion. Ce constat ne prouve pas une image absente.
  Reprise interrompue par un délai de démarrage Chrome de 30 secondes.
- Essai tactile simulateur non concluant, arrêté : lectures d'accessibilité
  très lentes pendant les compilations simultanées ; des attentes expirent
  alors que le message final contient déjà la valeur attendue (9, prise=false).
  Le test d'ouverture transitoire ne peut pas être validé dans ces conditions.
  Le simulateur dédié kat-tapis a été arrêté ; aucun autre simulateur arrêté.
- Première compilation Release interrompue après prélèvement : solveur de
  types Swift actif. Le calcul de la vidéo par défaut a été sorti du corps
  SwiftUI dans une propriété explicitement typée avant reprise en version70.

## Limites

Ces vérifications ne mesurent pas la chauffe ni les performances énergétiques.
Les essais utilisent les bancs locaux ; ils ne valident ni ne clôturent une
séance du compte. Aucun commit demandé ni créé.

## Validation physique finale

Release70 compilée, installée à08:22:32 ; version relue sur l'iPhone15 :
1.0 /70. `testDeuxRobesWelcome` PASS12,553s ; `testMoletteSurIPhone`
PASS17,890s. Deux tests, zéro échec, total30,443s.

Captures relues : les trois arcs sont ouverts après le tap à gauche de la
pastille, sans changement de la valeur initiale. Les glissements physiques
changent HIIT10→12, cardio7→9, escalier6→8 (assertions UI). Vidéo chauve-souris
visible et texte géant visible dans les deux captures Welcome Back. Ces
captures utilisent RewardLab ; le défaut vidéo de production est fixé dans
RewardPopup, commun à tous les appels. La règle serveur de déclenchement et
le paiement ne sont pas rejoués.

Woop relancé normalement avec `-sansSondeVol` après les tests ; commande
réussie, journal `iphone70-retour-normal.log`. Le téléphone conserve70.
Pas de nouvelle validation thermique ni de promesse de cadence à partir de
ce test tactile.
