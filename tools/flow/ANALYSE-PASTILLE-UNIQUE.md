# UNE SEULE PASTILLE VIVANTE — la fiche exo et la pastille de séance (05-09-2026)

Chantier dicté par Kathryn le 05-09, en sept passes dans la journée. **Tout ce
qui suit est CODÉ et vérifié** (build vert lu sans pipe, captures et films dans
`tools/flow/captures/` et `tools/flow/films/`) — sauf ce qui porte **? téléphone**.

> **Convention.** Sans marque = vérifié dans le code ou à la capture ce jour.
> **? téléphone** = à juger sous son doigt, jamais prouvable au simulateur.
> Les numéros de ligne de `WoopApp.swift` bougent (une autre session l'édite).

---

## 0. LES LOIS QUI SORTENT DE CETTE JOURNÉE

### ⚠️⚠️ « UPCOMING » N'EXISTE PAS

> « Sous l'exercice, on ne peut pas avoir *upcoming* : c'est un état qui
> n'existera **jamais**, puisqu'on ne sait pas ce que le user va faire. »
> — Kathryn, 05-09

C'est la **même loi que les flammes** du 04-09 (`FlammeJauge.swift:1243` : « on
met des flammes QUE lorsqu'une série est accomplie »), et elle vaut **partout,
jusque dans les règles serveur** : on n'affiche que **L'ACQUIS**, jamais une
promesse. Une série « à venir » est une supposition sur quelqu'un qui n'a pas
encore décidé — l'écrire en gris, c'est mentir poliment.

Corrigé : `SetHistoryRow.swift:193` (la partition du player — la place reste,
elle est vide) et `PageCard.swift:695` (la page bidon du banc dit ce que dit la
vraie).

### ⚠️ CE QUI BOUGE TOUT SEUL, ON L'ÉTEINT

Deux objets gigotaient sans qu'on les touche, et les deux ont été rejetés le
même jour : le **talon du ticket** (26° toutes les 3,4 s, « l'animation avec le
petit ticket est horrible ») et, avant lui, la carte des séries. Ce qui a le
droit de vivre en continu, c'est ce qui **dit un état** : le nom de l'exercice
balayé par la lumière parce que l'exercice TOURNE.

### ⚠️ UNE DURÉE LONGUE NE SUFFIT PAS : C'EST LE DÉBUT DE LA COURBE

Verdict « pas assez blur, fading, Apple ; trop vite, trop cheap » sur une
arrivée de 1,45 s. La cause, mesurée au film (`films/arrivee-texte.mov`) :
la courbe expo-out `timingCurve(0.16, 1, 0.3, 1)` fait **50 % du chemin dans
les 15 premiers pour cent du temps** — le flou avait disparu dès la première
image visible, et la seconde moitié rampait sans qu'on la voie. Remède :
`easeInOut`, lent aux **deux** bouts (`films/arrivee-v2.mov`, planche v2 : le
flou se lit sur cinq images).

---

## 1. CE QUI A CHANGÉ, ÉCRAN PAR ÉCRAN

### La fiche exo (`ExerciseDetailView.swift`)

| | Avant | Maintenant |
|---|---|---|
| Sous le titre | **la carte des séries** (`FlammeJauge` : « Training », `Sets N`, le contrat, les flammes, et la liste dépliable) | **la description de l'exercice**, en gros, puis de la NUIT |
| Le geste | tirer la carte pour la déplier (`carteP`, `carteDrag`) | **mort** — il n'ouvrait plus rien |
| La cible des pièces | le cadre de la carte (`seriesCardFrame`) | **la pastille** (`PiluleEtat.ancreGlobale`), figée au tir |

**L'archivage** : `FlammeJauge.swift` (1 821 lignes) et son banc restent
**entiers** — c'est le SITE D'APPEL qui se tait. `-carteSeries` la remonte
telle quelle pour la revoir (`ExerciseDetailView.swift:253`).

**La description** : `Exercise.cue` (réécrite pour les **25 exercices de
musculation**, une phrase, français simple) puis `Exercise.mistake`, précédée
de « À éviter » — sans ce mot, mesuré à la première capture, l'erreur se lisait
comme une **seconde consigne**. **Aucun texte pour le cardio** (sa fiche n'en
affiche pas : l'overlay est gardé par `isStrength`).

**L'arrivée** : le titre puis les deux phrases naissent **hors focale** (flou
26 → 0, 16 pt plus bas, 1,04 → 1) sur 1,6 s en `easeInOut`, étagés à 0,15 /
0,48 / 0,76 s (`ArriveeDouce`). ⚠️ Ce n'est PAS `ArriveeFloue` (CoffreV2:1159) :
celle-là décale par RANG dans un curseur continu, et sous un simple
`withAnimation` le corps n'est évalué qu'UNE fois — le rang ne décale alors
plus rien. Ici le retard vit dans l'animation.

**Le recul derrière la pastille** : pastille SORTIE de l'île → le texte passe à
flou 7 / opacité 0,16 (« blur quasi noir, on le voit légèrement en arrière-plan
comme Apple ») ; elle RENTRE dans l'île → il revient en fondu plus lent
(0,28 s à la sortie, 0,55 s au retour : ce qui arrive doit dégager la vue tout
de suite, ce qui revient a le droit de se poser).

### La pastille et l'île (`PiluleVagabonde.swift`, `WoopApp.swift`)

- **Elle VOLE dans l'île au départ de séance** — `PiluleEtat.envolerVersIle()`,
  le même ressort et le même carillon que le vol du doigt, joué 0,55 s après le
  début. Posée à `dansIle = true` sec, elle y NAISSAIT : personne ne voyait le
  voyage, donc personne n'apprenait qu'il existe un retour.
- **Une poignée** sous la capsule, dans la lèvre tactile qui existait déjà
  (`PriseIle.sous` = 44 pt) : elle fait **signe** (aller-retour) à l'arrivée et
  à chaque série finie, puis se tait à 0,30. Jamais un clignotant.
- **L'île ne montre PAS les flammes** (elles y ont vécu une heure : la capsule
  passait de 250 à ~295 pt, le chrono sous l'heure du système, le stop sous le
  wifi — mesuré `captures/fiche-seance-ile.png`). Le chrono est désormais
  **aligné à droite** dans son slot : il démarre après l'heure système.
- **La pastille tirée** dit : le nom de l'exercice, puis **le chrono et les
  reps**, et rien d'autre. Plus de ticket « N SETS », plus de flammes.
- **Le ticket reste dans le DÉTAIL** (la tête du grand player), **sans son
  animation** : le talon ne se soulève plus tout seul.
- **Le nom de l'exercice en cours est balayé par la lumière** dans le grand
  player — la MÊME lueur que l'invite (`InviteAnimee`, un seul balayage dans la
  maison), et elle se tait sous le doigt comme elle.

---

## 2. LES BARREAUX DE BANC AJOUTÉS

Le simulateur ne drague pas et ne tape pas : sans eux, trois états n'étaient
pas capturables.

| barreau | ce qu'il pose |
|---|---|
| `-carteSeries` | remonte la carte des séries archivée (la comparer) |
| `-piluleSortie` | la séance démarre pastille **hors de l'île** (le texte qui recule) |
| `-playerOuvert` | `-piluleLab` naît **player ouvert** (la tête, le nom balayé) |

Recette de capture : `-demoData -activeWorkout -skipAuth -openTab exercises
-openExercise papillon` (⚠️ `-activeWorkout` est OBLIGATOIRE pour qu'une séance
existe : `-activeWorkoutLong` seul n'en sème aucune).

## 3. CE QUI RESTE À JUGER — ? téléphone

- la poignée sur un iPhone **sans** Dynamic Island (les cotes d'`IleGeo` sont
  physiques et taillées pour le trou) ;
- la cadence réelle de l'arrivée floue (un `.blur` de 26 sur deux blocs de
  texte, pendant 1,6 s, au moment même où la fiche monte ses lecteurs) ;
- que la volée de pièces atteigne vraiment la pastille (à FILMER : une capture
  ne prouve pas une trajectoire) ;
- le chevauchement chrono / heure système sur les autres modèles.
