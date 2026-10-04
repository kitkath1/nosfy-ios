# Plan : la séance « à la Apple » (04-10-2026)

Ses mots du 04-10, sur l'artefact <https://claude.ai/artifact/CQEp5reqhq9atvvhzeenZY> (rangée 5) :
« bien lui [la séance vide v1, le + au centre] mais avec la pilule noire discrètement en fond ; après dans Ajouter on a la page puis l'overlay actuel mais on choisit une catégorie ; puis retour à la page séance avec les cards ; dernier screen [Terminer v1] très bien mais liquid glass et flamme blanche, et rajoute en background ; un mix en background entre les deux derniers screenshots ; très bien pour le chrono ». Plus : « quand je suis sur la page cadran, je dois pouvoir la tirer vers le bas, ça me remet sur le résumé de la séance, comme Spotify, très fluide ».

Le 04-10 soir, sur la rangée 5 : « très bien, anime l'arrivée vide → séance, magnifique ; la séance en cours pas assez Apple : fais un mix avec les traits et le résumé ; très bien le cadran tiré vers le bas ». La rangée 6 (`Flow.dc.html`, animée en Play) est la référence.

Rien de ce plan n'est codé. `VideV7` (la séance vide « Let's go », refusée le 03-10) sort.

## 1. Le fond commun (`FondV7`, SeanceV7.swift)

Un seul fond pour la séance vide, les cartes, « Tout est fait » : le noir, la lampe de l'île en haut (l'`EllipticalGradient` de `VideV7`, centre du cadre à 258), la braise en bas à gauche (celle de `FondV7` aujourd'hui), et le galet noir en filigrane : `Image("duo-galet-noir-poster")`, cotes de `NosfyOnboarding.galetDuCote`, `blendMode(.screen)`, opacité 0,34, fondu vers le bas par un masque linéaire. Image immobile : aucune horloge, aucun flou (skill perf : pas de nouvelle `TimelineView`).

- Fichier : `Nosfy/Views/SeanceV7.swift`, `FondV7` et `VideV7` (à réécrire).
- Barreau : `-sansGaletFond` (pour la chauffe).

## 2. La séance vide (`VideV7`, réécrite)

La v1 de l'artefact : l'en-tête de la page (« Séance », la date, la pièce, la tuile du jour), le médaillon « + » de 96 pt au centre, « Compose ta séance » dessous, rien d'autre. En bas, « TA DERNIÈRE SÉANCE » : une carte en verre (`VerreV7`) avec la pile des trois vignettes, « Vendredi · 3 exercices · 52 min », et « Refaire ». Compte neuf : pas de carte. La règle « jamais la séance du jour » (`derniere`) reste.

- Le « + » et « Refaire » : les actions existantes (`ouvrirAjout`, `etat.reprendre`).
- Ce qui part : « TA SÉANCE », le grand titre, le chiffre entre deux traits, la flamme, le `BoutonPrimaire`.

## 3. L'ajout en deux temps (`FeuilleAjoutV7`)

La feuille actuelle, avec une étape de plus : elle s'ouvre sur les cinq zones en grands carrés (`CarreZone` de `ExercisesView.swift`, 108 × 122, sur trois colonnes), et la recherche. Toucher une zone pousse la liste de ses exercices (la liste d'aujourd'hui), avec « ‹ Abdos » à gauche pour revenir aux zones et « Ajouter (n) » à droite. La recherche saute l'étape : elle liste tout de suite.

- `@State private var zone: ExerciseCategory?` (nil = les zones). Le dépliage reste dans la donnée (loi §3).
- La transition zones → liste : un `.move(edge: .trailing)` sous ressort, jamais un fondu seul.

## 3 bis. L'arrivée vide → séance, animée (« magnifique, polie »)

Une seule page, deux états, et une chorégraphie en trois temps au premier exercice ajouté (ou à « Refaire ») :
1. le « + » central glisse vers le bas et se range à la place du médaillon « + » du slider (le même `MedaillonStop`, un `matchedGeometryEffect` entre les deux positions, ressort response 0,8), « Compose ta séance » et la carte « Ta dernière séance » s'effacent (0,35 s) ;
2. « TA SÉANCE » puis le titre montent (opacité + 26 pt, 0,6 s, décalés de 0,18 s) ;
3. le chiffre entre deux traits, puis les lignes et le slider (décalés de 0,18 s encore).
Tout en `withAnimation` sur des valeurs animables, jamais une horloge (skill perf).

## 4. La séance en cours : le mix (« les traits et le résumé », les lignes fines)

La grammaire de « Terminer v1 » pour TOUTE la séance, pas seulement la fin :
- « TA SÉANCE » en petites capitales, le titre en blanc dégradé : « Prête. » avant la première série, « En cours. » ensuite, « Tout est fait. » à la fin ;
- le chiffre entre deux traits de 1 pt : « 3 exercices, 10 séries » → « 3 séries, 12 min » → « 10 séries, 32 min » (des faits, jamais une prévision de charge) ;
- les exercices en lignes fines (filet 1 pt à 0,1), vignette 40 × 44, nom, sous-titre (« 3 séries » / « 13 reps · 25 kg » une fois fait), les flammes blanches à droite, le chevron. Celui qui vient en semibold ; les faits en retrait (0,72).
- Les flammes : `sticker-flamme-serree` en `.template` blanc, ombre 3 pt à 0,45 ; grises à 0,2 tant que la série n'est pas faite.
- Le slider « Let's go · exercice · Série n » et le « + » du bas ne changent pas ; à la fin, « Terminer la séance · +60 ».
- Ce qui part : les grosses cartes à bord épais et leur dépliage ; `EnteteV7` (« Séance », date, pièce, tuile) reste SEULEMENT sur la page vide.
- Toucher une ligne ouvre la fiche (sa validation du 04-10 attendue sur « corriger ou ouvrir »).

## 4 ter. (était 4) Les cartes en verre — ABANDONNÉ le 04-10 (« pas assez Apple »), remplacé par le mix ci-dessus.

Une seule carte en verre (`VerreV7`, rayon 26) qui groupe les exercices, un filet de 0,5 pt entre les lignes. Chaque ligne : la vignette (42 × 46), le nom, le sous-titre (« 3 séries » / « 13 reps · 25 kg » une fois faite), les flammes à droite, le chevron. Les flammes : `sticker-flamme-serree` peinte en blanc (`.renderingMode(.template)`, `.white`, un `shadow` de 3 pt à 0,45), grises à 0,2 tant que la série n'est pas faite. Toucher une ligne faite ouvre la fiche de l'exercice (sa réponse du 03-10 attendue sur « corriger ou ouvrir » — ici : ouvrir, la correction se fait dans l'onglet Séries du cadran).

- Ce qui part : le bord épais des cartes (« UI cheap, regarde les borders », TF86), le dépliage par carte avec les séries listées. Les séries vivent dans la fiche (onglet Séries).
- Le slider « Let's go » et le « + » du bas ne changent pas. « Tout est fait » = la même page, titre « Tout est fait », les flammes allumées, la tuile du jour avec sa flamme, le slider « Terminer la séance · +60 ».

## 4 quater. Le halo du doigt (« quand je touche l'écran, le halo blanc dégradé magnifique »)

La loi de la maison (le pouce est la lampe ; `MenuHalos`, `ArdoiseFond.doigt`, le slider) sur la page vide et la page de séance : un disque de lumière blanche sans bord (RadialGradient 0,22 → 0,09 à 28 % → 0 à 70 %, rayon 180 pt) qui naît sous le doigt à la pose (0,28 s), le suit tant qu'il bouge, et meurt au relâcher en s'élargissant un peu (0,9 s). Rien ne bouge tant que le doigt ne bouge pas ; jamais un balayage. Un `DragGesture(minimumDistance: 0)` en `simultaneousGesture` sur le fond de la page, qui ne vole ni les lignes, ni le slider, ni le « + » ; la position en `@State`, l'opacité et l'échelle en valeurs animées (loi §2 : pas d'horloge). Barreau `-sansHaloDoigt`.

## 5. Le cadran tiré vers le bas (`ChromeV15`, `ExerciseDetailView`)

Un `DragGesture(minimumDistance: 12)` sur la tête du cadran et sur le disque, filtré sur l'axe (comme `carteDrag`), qui ne s'arme que vers le bas et hors du geste de la molette. Le doigt déplace la fiche entière par un `offset` (loi §2 : jamais une taille), le fond de la page de séance se révèle dessous à l'échelle 0,93 → 1 (la grammaire de `page` dans `SeanceV7`, `ajout`). Au lâcher : au-delà de 120 pt ou d'une vitesse de 600 pt/s, `quitterLaFiche()` (la coupe sourde existante, 0,3 s) ; sinon retour en ressort (response 0,38). Chien de garde de 0,3 s sur `onEnded` (loi §4). Haptique medium au décollage, ferme au franchissement.

- Pendant une course de tapis, le geste est le même : `quitterLaFiche` termine déjà la course (02-10).
- Barreau : aucun ; la cadence se filme (`simctl recordVideo`, 60 i/s) avant et après.

## 6. Ce qui ne change pas

Le cadran (sacré, jamais redessiné), la note de série aérée (03-10), le repos tel quel (« très bien pour le chrono »), le slider unique, le HIIT au toucher.

## 7. Ordre et preuves

1. Fond + séance vide (1 h) → capture compte neuf et avec passé.
2. La séance en lignes fines + l'arrivée animée + le halo du doigt (3 h 30) → film vide → séance (XCUITest, un vrai doigt), captures Prête / En cours / Tout est fait.
3. Ajout en deux temps (2 h) → film zones → liste → cartes.
4. Cadran tiré (3 h) → film à 60 i/s, cadence mesurée, puis le banc XCUITest `tools/seance-v7/bout-en-bout-2026-10-03/joue.sh` rejoué (un cas de plus : tirer le cadran).
5. Site : brique `b-seance-vide-note-tf86` mise à jour, `npm run artefact && npm run verif`.
6. Rien n'est commité sans son ordre. iPhone non mesuré tant qu'elle ne l'a pas en main.
