# Règle multi-session (Nosfy)

## CGU + anglais + bancs + conformité — session CGU, 18-09 après-midi, rien commité

12:32-12:40 : `verif_cardio`, `verif_faits` (compte jetable), `verif_backend_coffre`
portés sur `synchroniser_seance` → 22 / 14 / 53 ✓, litiges levés. Conformité
posée : `ITSAppUsesNonExemptEncryption` (deux Info.plist) + `Nosfy/PrivacyInfo.xcprivacy`,
vérifiés dans le bundle sim. Site republié v73. Toujours aucun iPhone, aucun index.
~15:00 : lecture statique du coffre sur sa demande — `tools/perf/ANALYSE-COFFRE-CHAUFFE-2026-09-18.md`,
E77 au registre, mesure `m-coffre-projecteur-chauffe` sur le site (v75). Deux suspects :
`Projecteur` (3 flous plein cadre redessinés à 20 Hz, CoffreV2.swift:835-925) et les
fullScreenCover coffre/chemin/fiche sans couverture `RythmeEcran.stories` (la Home ne
dort pas dessous). Puis, sur son « bah fais » (~15:20) : hunks POSÉS dans
`RythmeEcran.swift` (couvertures + `.couvreLaHome()`), `CoffreFortView.swift` (1 ligne),
`HomeNuit.swift` (2 lignes), `NosfyApp.swift` (1 ligne sur le manège à la racine),
`SondeVol.swift` (tics[5]), `CoffreV2.swift` (Projecteur : barreau, porte, tic — région
835-870 seulement, les hunks Cartes du pied sont intacts). Build sim EXIT 0, dessin
intact, rien mesuré. Session manège : le `.couvreLaHome()` sur `BoosterLab` à la racine
n'endort que la Home/Profil dessous, il ne touche pas au manège lui-même.

## Cartes — iPhone RÉSERVÉ par la session Ouvrir (18-09 15:15, « vas-y » de Kathryn)

Contrôle iPhone du parcours Cartes : build Debug de l'arbre partagé (correctif
`PiedCoffre.allume`) installé sur « iPhone de Frédéric », lancé avec la sonde
(`-sondeVol -ecranEveille -navProbe`), SON compte, aucune remise à zéro, aucune
suppression. Elle fait les gestes (Ouvrir après le film, envol, noir, chevron),
je lis la sonde et le serveur. → **iPhone LIBÉRÉ à 16:50**, relancé `-sansSondeVol`.
Résultat : 2 sachets orange ouverts au doigt après le film, 2 cartes révélées et
envolées vers la collection, serveur cohérent ; thermique 0 sur 3 min, 60 img/s
médian, CPU 30 % médian pendant le manège. Preuves tools/carte-lune/iphone-2026-09-18/.
Non fait : manège noir (0 sachet sur son compte), sortie par le chevron, coupure réseau.


## Cartes — blocage « Ouvrir » LEVÉ au simulateur, commité (session Ouvrir, 18-09 15:00)

12:15-12:45 : les 4 scénarios UI Cartes passent (0 échec) sur `nosfy-cartes-20260918`,
fixture jetable, compte supprimé après, sim éteint. La cause n'était PAS le bouton
(`allowsHitTesting` innocenté par A/B) : le banc tapait PENDANT le film d'arrivée du
coffre. Correctif `PiedCoffre.allume` (CoffreV2.swift) + trace `traceQA()` DEBUG.
`accessibilityHidden` est ignoré par XCUITest (mesuré). Tests A/B corrigés
(`CartesUITests-apres.swift`). Tout dans `tools/carte-lune/ouverture-ui-2026-09-18/`.
Site : b-cartes-ouverture-qa 🟢, page Cartes, mesure iPhone toujours ◌ ; republié v74.
⚠️ Commit par hunks : CoffreV2.swift et NosfyApp.swift gardent VOS hunks non commités
dans l'arbre (24 + 5), rien emporté. Sur ordre explicite de Kathryn, ce commit porte
aussi les 36 captures allégées + `scripts/alleger.py` (octets identiques aux vôtres,
repris depuis `out/`) : sans elles le livrable dépasse 2 Mo. `captures.py` n'est pas
emporté. Aucun iPhone touché. Reste ouvert : Ouvrir/envol/chauffe sur le téléphone.


## Live Activity — portrait, lune et Stop,18-09

Commit limité à cette session, demandé par Kathryn. Grande carte et île déployée :
portrait original Nosfy aux yeux rouges ; formats compacts : lune. Exercice lancé,
phases muscu/cardio/piscine, chronos système et frise d’allures. Stop demande la
suppression immédiate sans attendre une mise à jour et ignore les callbacks tardifs.
Aucun changement backend. Flow et index d’état documentés ; contrôles physiques dans le contrat détaillé.
Copie isolée et simulateur dédié ; aucun accès iPhone. 53 contrôles modèles/player
et16 contrôles pilote/Stop PASS ; widget compilé. Build global isolé bloqué par
VolDePieces absent du Home antérieur, dépendance laissée à sa session.
Documentation :23 tests PASS, captures390/1440 relues. Preuves et limites :
`tools/live-activity/COMMIT-2026-09-18.md`. ActivityKit réel et chauffe iPhone ouverts.
Index privé, fichiers partagés fusionnés par hunks ; les travaux des autres
sessions restent dans l’arbre et leurs entrées d’index sont préservées.

## Session Nosfy / Apple / contrôle production — 18 septembre 2026

Commit limité à cette session, demandé par Kathryn. Dossier principal
`/Users/kathryn/Desktop/Nosfy` ; projet et schéma `Nosfy`, sources `Nosfy/`,
`NosfyShared/`, `NosfyWidgets/`. Les anciens accès locaux masqués ne se
versionnent pas. Utiliser les chemins Nosfy pour les nouveaux commits.
Les déplacements partent des blobs HEAD : aucun correctif parallèle non
committé de Forge, chauffe, stories ou Home/Route n’est emporté.

Compte vide : premier galet en haut du chapitre1, aucun fait/date fictifs.
Correction `EcranSpec.etapeEtFaits`, 34 contrôles Swift ; contrat Compte,
Flow, Serveur et QA17 à jour. Aucun accès iPhone pour ce correctif.
La progression non vide reste à terminer avant la qualification production.
Preuves : `tools/duolingo/preuves-compte-vide-2026-09-18/README.md`.

Clé Apple configurée ; sonde avec code factice réussie. Vrai échange et
révocation à mesurer. Contrôle d’intégrité : une séance inexistante obtient
20 pièces et un sachet ; test rouge, correctif pas encore déployé.
Preuves : `tools/porte/preuves-apple-2026-09-18/README.md`,
`tools/production/ETAT-PRODUCTION-2026-09-18.md` et
`tools/nom/preuves-2026-09-18/README.md`.
Release74 issue de l’arbre partagé installée et nom Nosfy relu ; la session
Home/Route a ensuite posé75. Aucun nouveau binaire ni scénario physique
pour ce commit. La session chauffe conserve le téléphone.

## Message à la session Forge — 17-09-2026, chantier Compte

Kathryn demande de se coordonner : cette session prend le parcours **Compte**
(Apple, onboarding, profil, reprise de session, déconnexion/suppression,
tests dédiés et documentation page `porte`). La **Forge** reste à l'autre session :
pas de modification de `forge-card`, du tirage ni de sa page.
Le renouvellement du jeton et ses tests sont déjà présents dans l'arbre partagé :
ils sont conservés. Pour les fichiers de documentation communs (`briques.ts`,
`serveur.ts`, `qa.ts`), seules les lignes Compte seront modifiées par cette session.
Le livrable `docs/site/index.html` sera régénéré depuis les sources partagées.
Répondre ici pour signaler un chevauchement. Le 18-09, Kathryn demande le commit
Compte et autorise aussi son socle antérieur nécessaire : Keychain, reprise,
déconnexion/suppression, pull, et helpers d’authentification de banc déjà présents
dans `ForgeServeur.swift`. Le tirage et la génération Forge restent exclus.
Aucune installation sur le téléphone n'est prévue par cette session.

Avancement Compte : migration `20260917184811_compte_objectif_atomique.sql`
appliquée seule (objectif invalide refusé avant écriture), 32 tests API verts
sur comptes jetables nettoyés. Corrections app : `InscriptionCompte.swift`,
`VerificationCompte.swift`, `ProfilServeur.swift`, `AppleAuth.swift`,
`NosfyOnboarding.swift`, hunks Compte de `NosfyApp.swift` et `Compte.swift`.
Release simulateur compilée ; documentation `porte` et schémas actualisés.
Preuves : `tools/porte/preuves-2026-09-17/README.md`.
Complément du 18-09 : `verif_compte.py --flow`, 50 PASS ; compte neuf vide,
première série → pièces et sachet, rejouée sans doublon, gains retrouvés après
reconnexion, isolation entre comptes et suppression étendue. Aucun tirage Forge.

Validation isolée du 18-09 : le socle Compte et ses tests sont repris, mais
le HEAD `dba590bc` seul a des incohérences UI : `ToasterGain` / `VolDePieces`
absents, catégories manquantes dans `RecentWorkoutCard`, `onStopViaPause`
appelé dans la racine mais absent d’`ActiveWorkoutView`. Le filtre `fantomes`
est aussi signalé par le compilateur. Ces interfaces restent aux sessions
concernées ; le commit Compte ne récupère pas leurs corrections.

Plusieurs sessions Claude travaillent sur ce dépôt **en parallèle**, sur des
chantiers différents (flow/gel, route/booster, story/rewards…). Le working tree
contient donc en permanence du travail non commité appartenant à plusieurs
sessions à la fois.

## La loi

> **Chaque session IGNORE le travail des autres, et ne committe QUE le sien.**

Concrètement, pour toute session :

1. **Ne jamais `git add -A` ni `git add .`** — ça avalerait le travail non
   commité des autres sessions.
2. **Committer par CHEMINS EXPLICITES**, uniquement les fichiers que CETTE
   session a modifiés : `git add Nosfy/Views/MonFichier.swift`.
3. Si un fichier contient à la fois mes changements ET ceux d'une autre session
   (fichier « mixte » : souvent `NosfyApp.swift`, `HomeNuit.swift`), **ne pas le
   committer en bloc** — soit ne pas le committer du tout (le laisser en working
   tree, il est déjà déployé sur l'appareil), soit stager seulement mes hunks.
4. **Relire `git status` et `git log -3` AVANT chaque commit** — vérifier qu'on
   n'emporte rien d'étranger, et qu'une autre session n'a pas commité entre
   temps (collision déjà payée plusieurs fois).
5. **Un build qui casse n'est pas forcément le vôtre** : vérifier l'horodatage
   du fichier fautif ; une autre session peut écrire en direct (ex : le
   « type-check trop long » de `StorySuite.swift` — retry le build).
6. **Auteur du commit : toujours Kathryn** (config git locale). Jamais de
   trailer `Co-Authored-By`, jamais de mention d'assistant, jamais `--author`.

## Pourquoi

Le 27-08, un montage réel (`SessionSlate`, le player qui se soulève) a été
**réverté par accident** : une session // a commité une copie périmée de
`ExerciseDetailView.swift` — diff mécaniquement inverse — dans un commit qui ne
parlait que d'autre chose. Personne ne l'a vu, le fichier compilait encore. La
règle ci-dessus existe pour que ça ne se reproduise plus.
