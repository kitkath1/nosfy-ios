# Profil, Coffre et catalogue commun — 19 septembre 2026

## Changements livrés

Le bouton de rejeu « ▶ Nosfy » et son état ont été retirés de la racine ;
l’onboarding normal reste en place. Les quatre registres partagent une colonne
de lunes de 44 pt. Les constantes inutilisées 4/11/4/6 ont été retirées : les
compteurs lisent toujours `totaux_cartes()`, soit 5/3/3/3 références publiées.

La pièce d’or décorative avait son propre geste sans action ; au centre de la
pastille, elle interceptait le toucher. `allowsHitTesting(false)` sur ce décor
rend toute la pastille au bouton qui ouvre sa page du Coffre.

50 scènes dans les trois univers sont décidées, sans génération maintenant.
Le plan `../PLAN-50-SCENES-2026-09-19.md` décrit 14 références existantes et
36 compositions proposées, shiny très marqué et personnages récurrents avec
poses, angles et actions distincts. Mêmes scènes officielles pour tous.
Aucun PNG généré, aucun art possédé remplacé, aucun catalogue distant modifié.
La répartition 20/15/9/6 reste une proposition, pas un quota actif.

## Backend relu

- `qa-api.log` et `qa-api.json` : 28 PASS, deux comptes temporaires supprimés.
  Identité commune, vrais doublons, 20 appels simultanés pour un seul exemplaire,
  huit préparations d’achat pour un débit, gratuité des noirs possédés,
  collection après reconnexion, stocks et reçus cohérents.
- `qa-coffre.log` : 53 PASS, compte temporaire supprimé. Conversion,
  idempotence de clôture, versement quotidien, fuseau, flamme et droits.
  La garde du galet futur est vérifiée ; conversion par galet non rejouée ici
  (preuve antérieure : `../integration-2026-09-18/qa-galets-garanties.log`).
- `catalogue-distant.json` : 14 références relues, mêmes UUID, références et
  SHA256 que le manifeste publié ; raretés 5/3/3/3, mondes 4/6/4. Les flags
  `published:false` périmés du manifeste d’atelier ont été corrigés.
- `plan50-validation.json` : 50 scènes distinctes, 14 empreintes inchangées,
  36 champs `art:null`, trois mondes conservés.

## Parcours UI et coupure

Premier passage sur le simulateur dédié iPhone 17 / iOS 26.5 :

- Alignement des quatre titres vérifié, bouton de rejeu absent. Pages orange,
  noire et argent FR correctes ; échec sur la pastille or (profil resté ouvert).
  `captures79/AF799AFA-0496-4EE8-BDE4-811B2770A042.txt` montre le bouton décoratif
  « Ton trésor » imbriqué. Cet échec a conduit au correctif décrit plus haut.
- Orange : réponse perdue APRÈS attribution réelle, Réessayer, vraie carte,
  envol, un seul exemplaire : PASS 23,716 s.
- Noir : même perte, fermeture de l’app, relance, même sachet repris,
  légendaire révélée, envol : PASS 36,973 s.

Après correction, build 80 : `testAProfilEtQuatrePagesCoffre` PASS en 152.949 s.
Les quatre accès au Coffre ont été vérifiés en français ET en anglais,
ainsi que l’alignement des titres et l’absence du bouton de rejeu.
Journal `ui80-tests.log`, images `captures80/`, banc `ProfilCoffreUITests.swift`.
Les deux tests réseau déjà réussis ne sont pas rejoués inutilement.

`ui-serveur-apres.json` confirme un sachet orange et un noir ouverts,
exactement deux `user_cards`, chacune liée à son sachet. La première requête
manuelle avait demandé une colonne rarete absente de user_cards ; corrigée
pour relire id/card_id/booster_id. Aucun doublon masqué par le banc.

Le banc DEBUG `-cartesQA -cartesQACoupure` jette une seule réponse réussie
avant décodage. Il exerce la reprise d’une attribution déjà validée au serveur ;
il ne remplace pas l’essai réel du mode avion. Aucun jeton dans le code ou les
logs. Les comptes de test sont distincts du compte personnel.

## Builds et limites physiques

79 iPhone a compilé, été installé et relu (bundleVersion 79). Son runner était
bloqué sur le déverrouillage et a été arrêté avant tout scénario, après la
réservation du téléphone par la session Erreur. Aucun gain personnel consommé.
Le téléphone n’a pas reçu notre 80 ; sa version courante dépend de l’autre session.

80 compile pour simulateur et iPhone (`simulateur80-build.log`,
`iphone80-build.log`). L’arbre partagé contient aussi les modifications de
Parcours et Erreur. Les échecs intermédiaires Self / isolation / typage de la
racine sont résolus ; cette session a ajouté @MainActor aux deux propriétés
DemoSession de CalLab qui appellent maintenant StorySession.init isolé.
`sources80.json` donne les empreintes relevées au lancement du dernier build.
Aucun commit effectué.

Aucune nouvelle mesure thermique physique : chauffe Profil/Coffre, endurance
et mode avion pendant une ouverture restent ouverts. Le shiny animé et son
coût restent à réaliser/mesurer ; le contraste des trois familles attend le
verdict sur écran physique. Un build, une capture ou un test API ne valide pas
ces points. La documentation conserve leurs états ouverts.

Incident du banc avant le dernier passage : le sélecteur anglais « coins »
correspondait aussi à « silver coins ». La capture AX confirmait la page
argent. Sélection rendue unique en excluant silver ; aucun code produit
modifié pour cet échec de test. Journal ui80-premier-tests.log.

## Nettoyage et documentation

`nettoyage.log` : compte UI supprimé (HTTP 200), jetons de fixture retirés.
Le simulateur dédié a été arrêté ; les trois comptes utilisés par les tests
backend avaient déjà été supprimés. Le compte personnel n’a pas été modifié.

Documentation locale reconstruite par `npm run artefact`, puis `npm run verif` :
23 tests PASS, livrable identique au build, dix pages sans débordement à 390 px.
Captures Coffre, Cartes et État relues ; `artefact.log` et `verif.log` archivés.
Aucune republication d’un éventuel lien externe n’est revendiquée.

Relecture demandée avant le commit : [points encore ouverts](POINTS-OUVERTS.md).
La mention 78 est périmée ; les limites physiques restent explicites.

## Périmètre du commit ciblé

Le commit est préparé depuis HEAD dans un worktree isolé : suppression du rejeu,
alignement, toucher de l’or, banc de réponse perdue, plan 50 et preuves.
Les autres modifications du Profil (rangée des pastilles, traductions), des
stories et du compte restent aux autres sessions. Les captures et parcours
80 ci-dessus ont été réalisés dans l’arbre partagé, comme indiqué.

La compilation isolée a révélé deux erreurs déjà présentes dans HEAD et
corrigées dans le dossier partagé : trace DEBUG de ouvrirManege égarée dans
un ViewBuilder (robe absente), et ordre de déclaration des arguments de
PiedCoffre. Seuls ces déplacements nécessaires sont inclus depuis CoffreV2,
sans ses autres changements. `commit-build-avant.log` conserve cet échec.

Après ces déplacements, le build isolé révèle un blocage préexistant hors
périmètre : Annonces.swift appelle ToasterGain, absent de HEAD (cinq appels,
aucune déclaration dans git grep HEAD). Annonces et NotifCard sont inchangés
dans ce commit. La déclaration existe dans le travail non commité d’une autre
session ; elle n’est pas embarquée. `commit-build.log` conserve cet échec.
Le build 80 réussi cité plus haut porte sur l’arbre partagé, pas ce sous-ensemble.
La documentation isolée, elle, passe les 23 tests et les contrôles d’affichage
(`commit-artefact.log`, `commit-verif.log`).
