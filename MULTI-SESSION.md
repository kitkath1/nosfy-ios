# Règle multi-session (Nosfy)

## Sauvegarde Parcours/TestFlight — 19-09

Commit Parcours 858abef5 poussé sur main à la demande de Kathryn.
Sélection dans une copie isolée, index partagé inchangé. Parent et sélection
rencontrent le même ToasterGain absent ; le build intégré 81 est VALID chez Apple.
Sonde de parcours demandée ensuite : chantier suivant, absente du build81.

## TestFlight via API — build 81 envoyé, 19-09

Kathryn autorise les fiches et la publication TestFlight. Clé JBXG6FH45V +
Issuer fourni : API 200 ; ancienne clé 48V7W7DND9 refusée 401.
Archive et export Release signés réussis, copie figée de 588 fichiers.
Apple accepte l’IPA 1.0 (81) sans erreur à 10:18 Paris ; traitement COMPLETE,
build VALID. Consignes FR/en-GB relues, build sélectionné dans le brouillon1.0.
Descriptions/sous-titres/mots-clés FR/en-GB enregistrés puis relus, catégorie
Santé et forme. Icône lune compilée, puis extraite par Apple et vue.
Groupe « Premiers testeurs » créé vide, lien public et notifications désactivés.
Téléphone fourni ensuite : contacts et notes de revue enregistrés.
Build rattaché au groupe ; demande de revue HTTP201, WAITING_FOR_REVIEW relu.
URL confidentialité/assistance encore manquantes pour la fiche publique.
50 cartes requises pour ouvrir aux testeurs : catalogue relu 14/50.
Aucune invitation, aucun téléphone ni art touché ; index partagé intact.
Preuves : tools/production/testflight-api-2026-09-19/README.md.
Documentation artefact/verif PASS : 23 tests, dix pages à 390 px ; captures
relues. 588 fichiers sources encore identiques au build après envoi.
Revue externe soumise, réponse Apple attendue ; aucune invitation.


## Parcours — nouvelle vérification sans téléphone, 19-09

Sur demande de Kathryn : relancer les tests front/backend en arrière-plan,
mettre les preuves à jour dans toutes les sections concernées, pas seulement QA.
Aucun accès iPhone ; comptes QA et clients Swift isolés. Sources de production
laissées aux sessions en cours, documentation partagée modifiée par lignes.
Preuves : tools/production/reverification-front-back-2026-09-19/.
Résultats : 20 contrôles Swift connectés, 44 API, 35 fin de séance, 15 outbox,
13 sync, 9 pull, 15 session, 2 × 1 277 Route PASS ; build Debug réussi.
Le pull sans reçu historique est reproduit, puis corrigé dans la passe Stories ci-dessus. Briques et pages
Annonces/Serveur/Flow/Coffre/Cartes/Stories mises à jour ; notes périmées de
retour Route, déclenchement story et confirmation de règle corrigées.
Livrable documentaire régénéré puis vérifié : 23 tests PASS, dix pages sans
débordement à 390 px ; captures État, Serveur et Stories regardées.
Aucun code produit modifié, aucun commit demandé.


## Parcours TestFlight — 19-09 : fin de séance et Route

Sur « oui très bien enchaîne » : clôture persistée avant réseau, story aux gains
confirmés, compte neuf sans booster fictif, Welcome Back retenu pendant séance
et story, puis animation finie du galet accompli après la story. Fichiers :
Models, NosfyApp, OutboxGains, EconomieNosfy, Compte, StoryFlow/StorySuite,
DepartSeance, DuolinguoPage, ChambreDonnees, SupabaseSync, SacreServeur et nouveau
ReglementSeance. Hunks des autres
sessions conservés ; catalogue et dessins Cartes hors périmètre. Tests isolés,
aucun usage de l’iPhone réservé par Erreur. Pas de commit ni upload demandé.
Validation : 35 assertions SwiftData/story/Welcome, 15 outbox, 13 sync,
1277 Route, 45 API Supabase et 2 parcours UI simulateur PASS ; build Debug final
réussi. Preuves : tools/production/fin-seance-2026-09-19/README.md.
Le reçu après pull/reconnexion est corrigé dans la passe Stories ci-dessus. Restent Apple natif,
chaîne intégrée et chauffe iPhone, archive et distribution. Mise à jour de la
doc terminée : artefact puis verif PASS (23 tests, dix pages à 390 px),
vert limité à la preuve nommée.



## Stories restaurées et jours du widget — correction mesurée, 19-09

Kathryn demande de corriger les reçus après reconnexion et de revoir les
séances en touchant leurs jours dans le widget. Périmètre : lecture seule des
bilans côté Supabase, pull Swift, accès aux jours Regularity, tests et doc.
Les 50 cartes sont explicitement requises pour le lancement et restent à la
session Cartes. Aucun asset/catalogue touché ici ; aucun téléphone utilisé.
RPC recus_seances déployée, lecture seule et propriétaire contrôlé : 24 Swift
connectés, 17 API, 17 pull, 35 fin de séance et 5 dates PASS. Trois gestes UI
simulateur PASS : jour unique, choix entre deux séances et jour vide. Les
reçus restent identiques après ouverture du booster et acquittement. Sources
partagées par lignes ; pas de commit/push demandé. Preuves :
tools/production/stories-historique-2026-09-19/README.md.
Sources finales : build Debug réussi, 3 gestes UI repassés sans échec ;
documentation artefact puis verif PASS (23 tests, dix pages à 390 px), captures
relues. Simulateur dédié libéré ; pas de changement des sources ProgressPage.


## Analyse TestFlight — premier vrai compte, 19-09

Configuration Supabase relue sans écriture : Apple actif, inscriptions ouvertes,
quatre secrets présents. Compte --flow 50 PASS et inscription Swift 12 PASS ;
deux comptes QA nettoyés. Analyse des seuils du pilote et de l’expérience
complète : tools/production/analyse-testflight-2026-09-19/README.md.
Entrée Apple du binaire final, distribution et J+1 encore non mesurés ; reçu
des stories alors absent, corrigé dans la passe Stories ci-dessus. Aucun téléphone utilisé,
aucun code produit modifié, aucun envoi TestFlight ou commit demandé.
Documentation Compte/QA et mesure de distribution actualisées ; ancien KO
Cartes de QA19 rapproché des preuves simulateur du 19-09, sans nouveau test UI.
Release iPhone arm64 sans signature réussie, 249 sources identiques à la passe
connectée ; iOS 26 minimum, manifeste présent. Documentation artefact/verif
PASS (23 tests). Archive actuelle et App Store Connect restent à traiter.


## Coffre / Cartes — vert backend et tirage commun, 19-09

Sur sa demande : documentation backend explicitement validée (53 Coffre,
28 Cartes, 44 API parcours et 20 Swift connectés déjà mesurés). Nouvelle
lecture seule de la fonction déployée : les nouvelles références publiées
rejoignent toutes les anciennes de même rareté, sans terminer les 14 avant
les 36 suivantes. Total prévu 50 conservé. Aucun art généré ou publié,
aucun compte ni téléphone utilisé ; pas de migration ni changement du tirage.
Preuves : tools/carte-lune/catalogue-commun-2026-09-19/. Les lignes de chauffe,
de rendu, de production des images et de distribution gardent leur état réel.
Sources documentaires modifiées par lignes, index partagé intact. Commit de
cette session demandé ensuite : sélection et livrable vérifiés dans un worktree
isolé, puis push sur main. Les autres sessions restent hors de la sélection.
Validation documentaire : artefact puis 23 tests PASS ; dix pages à 390 px,
captures Coffre/Cartes relues. Le bilan backend vert suit ses briques ; les
compteurs généraux gardent les mesures physiques encore ouvertes.
Question complémentaire fiche exercice : historique lié aux séries faites ;
conseil-exercice absent de la liste distante relue le 19-09. Brique IA maintenue
absente, preuve ajoutée ; aucun déploiement IA dans cette passe.


## Profil / Coffre — 19-09, tests terminés ; iPhone rendu à Erreur

Bouton de rejeu Nosfy retiré, quatre titres alignés ; toucher de la pastille
or corrigé sur son décor MoonCoin. Build 80 simulateur + iPhone réussis.
Huit accès Coffre FR/EN et alignement PASS au simulateur dédié ; deux reprises
après réponse perdue PASS (orange Réessayer, noir relance). 28 API Cartes et
53 Coffre PASS. Comptes temporaires seulement, aucun gain personnel consommé.

Cible de 50 scènes préparée : 14 publiées, 36 propositions sans génération,
shiny très marqué et personnages récurrents dans des poses distinctes.

Le runner physique 79 a attendu le verrou iOS puis été arrêté ; aucune nouvelle
mesure thermique. L’iPhone reste à Erreur, sans réinstallation de notre 80.
Deux propriétés DemoSession de CalLab ont reçu @MainActor pour suivre
StorySession.init. Les autres corrections de compilation sont de Parcours.
Preuves : tools/carte-lune/profil-coffre-2026-09-19/. Commit ciblé autorisé par Kathryn (« commit que ça »), préparé dans un worktree
isolé. Index partagé conservé ; relire et restager vos versions avant votre
prochain commit pour éviter de reprendre les anciennes lignes de ce chantier.
Compilation isolée : deux déplacements de compilation CoffreV2 inclus ; puis
blocage préexistant Annonces → ToasterGain absent de HEAD, laissé à sa session.
Documentation isolée : 23 tests PASS. Le build 80 partagé reste distinct.

## Cartes — iPhone RÉSERVÉ (18-09 18:40) : le chevron pendant le manège, sur son « vas-y »

Un sachet orange de TEST posé sur son compte (origine cadeau, id dans
tools/carte-lune/iphone-2026-09-18/orange-test-chevron-pose.json). App du commit
8bbccfb0 déjà installée, relancée avec la sonde. → **LIBÉRÉ 18:50**, app relancée
normalement. Chevron : retour home, sachet intact, manège repris, carte envolée (« c'est good »).
→ commité 3f879fec (index temporaire). ⚠️ Session erreur : votre index porte briques.ts,
mesures.ts et index.html d'AVANT 3f879fec — un `git commit` nu effacerait mes lignes
(chevron) : `git add` de nouveau ces trois chemins depuis l'arbre avant de commiter.
3f879fec remet aussi le `]` fermant à la fin de mesures.ts (acefb57c ne compilait pas).
⚠️ Ce commit remet le `]` fermant à la FIN de `docs/site/content/mesures.ts` : dans acefb57c
il précédait l'entrée m-erreur-avion-iphone, la source ne compilait pas (`npm run artefact`
refusait). Rien d'autre emporté ; vos autres lignes de mesures.ts restent dans l'arbre.


## Cartes — iPhone RÉSERVÉ (18-09 17:45) : banc de matière du sachet noir, sur son « vas-y code »

Build Debug de l'arbre (BoosterPack.swift : `-noirMatiere <n>`, 4 recettes) installé
sur son téléphone, lancé en banc `-skipAuth -boosterLab -boosterNoir -boosterGallery`
(rien n'est consommé, aucun sachet). Elle juge à l'écran, je relance par variante.
→ **LIBÉRÉ 18:12**, app relancée normalement (son compte). Verdict : laque sombre
(variante 5) + lune en néon blanc + musique du manège noir = « ok très bien », commité.
Analyse : tools/sacre/ANALYSE-SACHET-NOIR-MATIERE-2026-09-18.md.


## Cartes — iPhone RÉSERVÉ à nouveau (18-09 17:10) : manège noir + chevron, sur son « vas-y »

Un sachet noir de TEST posé sur son compte (origine cadeau, id dans
tools/carte-lune/iphone-2026-09-18/noir-test-pose.json). App déjà installée,
relancée avec la sonde. → **LIBÉRÉ 17:20**, relancé `-sansSondeVol`. Noir ouvert au doigt,
légendaire révélée et envolée (serveur : 3 cartes) ; therm 1 atteint APRÈS 13 min de home
immobile écran allumé au câble (cpu 9 %) — à lire par la session chauffe, pas un verdict.
Son verdict : le sachet noir dans le manège « trop mat, pas assez réaliste ».


## Cartes — iPhone RÉSERVÉ (18-09 17:45) : banc de matière du sachet noir, sur son « vas-y code »

Build Debug de l'arbre (BoosterPack.swift : `-noirMatiere <n>`, 4 recettes) installé
sur son téléphone, lancé en banc `-skipAuth -boosterLab -boosterNoir -boosterGallery`
(rien n'est consommé, aucun sachet). Elle juge à l'écran, je relance par variante.
→ **LIBÉRÉ 18:12**, app relancée normalement (son compte). Verdict : laque sombre
(variante 5) + lune en néon blanc + musique du manège noir = « ok très bien », commité.
Analyse : tools/sacre/ANALYSE-SACHET-NOIR-MATIERE-2026-09-18.md.


## Cartes — iPhone RÉSERVÉ à nouveau (18-09 17:10) : manège noir + chevron, sur son « vas-y »

Un sachet noir de TEST posé sur son compte (origine cadeau, id dans
tools/carte-lune/iphone-2026-09-18/noir-test-pose.json). App déjà installée,
relancée avec la sonde. → **LIBÉRÉ 17:20**, relancé `-sansSondeVol`. Noir ouvert au doigt,
légendaire révélée et envolée (serveur : 3 cartes) ; therm 1 atteint APRÈS 13 min de home
immobile écran allumé au câble (cpu 9 %) — à lire par la session chauffe, pas un verdict.
Son verdict : le sachet noir dans le manège « trop mat, pas assez réaliste ».


## ⚠️ Session Ouvrir — commit 715022cc posé par index TEMPORAIRE : relisez VOTRE index avant de commiter (18-09 17:05)

L'index partagé portait 25 fichiers d'une autre session (CGU, Info.plist,
PrivacyInfo, production…) : je n'y ai pas touché, mon commit est passé par
`GIT_INDEX_FILE` séparé. Conséquence à connaître : vos versions À L'INDEX de
`MULTI-SESSION.md`, `docs/site/content/briques.ts`, `mesures.ts` et
`docs/site/index.html` datent d'AVANT 715022cc (elles n'ont pas la brique
« Sur son iPhone », la mesure `m-cartes-noir-chevron-iphone`, ma note iPhone).
Un `git commit` nu les ré-écrirait telles quelles et EFFACERAIT ces lignes de HEAD.
Avant de commiter : `git add` de nouveau ces quatre chemins depuis l'arbre (qui
contient tout), ou `git diff --cached HEAD -- <chemin>` pour vérifier. `forge.mdx`
est déjà réaligné sur HEAD dans l'index.


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
