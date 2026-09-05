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

### ⚠️ L'ÎLE EST LE DÉFAUT — ET C'EST UNE RÈGLE DE POIDS, PAS DE GOÛT

> « Quand on lance une séance, la pastille de l'exercice en cours est par
> défaut dans le Dynamic Island, **pour alléger l'écran** — d'autant qu'une
> fois qu'on lance un exo, on **arrive sur la page exercice**. Sinon ça reste
> un peu lourd à lire. » — Kathryn, 05-09

C'est la raison d'être du défaut, et elle doit survivre à qui touchera ce code :
le chemin normal (lancer un exo → atterrir sur la fiche) pose la pastille **sur
la page qu'on vient d'ouvrir pour la LIRE**. Une dalle de 96 pt en travers d'une
description, c'est une page qu'on ne lit plus. L'île la range ; le texte reste
entier ; et quand on la tire, c'est le TEXTE qui recule — jamais l'inverse.

⚠️ Corollaire : **on ne remet jamais la pastille au premier plan par défaut**
« pour qu'on la voie ». Ce qui la fait voir, c'est son VOL à l'aller (0,55 s
après le départ) — pas sa présence en travers de la lecture.

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
**flou 5 / encre 0,34** ; elle RENTRE dans l'île → il revient en fondu plus lent
(0,28 s à la sortie, 0,55 s au retour : ce qui arrive doit dégager la vue tout
de suite, ce qui revient a le droit de se poser). ⚠️ Les premières cotes (flou 7,
encre 0,16) ne laissaient qu'une TACHE : « on voit encore le texte, mais très
très finement blurré, pour comprendre qu'il est en train de disparaître — là, il
est tout noir ». Un recul doit rester LISIBLE COMME TEXTE pour dire qu'il
s'efface ; sinon il n'y a plus rien à comprendre.

### La pastille et l'île (`PiluleVagabonde.swift`, `WoopApp.swift`)

- **Elle VOLE dans l'île au départ de séance** — `PiluleEtat.envolerVersIle()`,
  le même ressort et le même carillon que le vol du doigt, joué 0,55 s après le
  début. Posée à `dansIle = true` sec, elle y NAISSAIT : personne ne voyait le
  voyage, donc personne n'apprenait qu'il existe un retour.
- **TOUT l'en fait sortir** : tap **ou** drag de 3 pt, et la lèvre tactile passe
  de 44 à **60 pt**. Avant, le tap OUVRAIT LE PLAYER (réparation du 04-09) : le
  seul geste qui atteignait vraiment l'app servait à autre chose, et la sortie
  n'existait qu'au drag, dans 44 pt sous un trou que le système se réserve —
  d'où « souvent c'est bloqué, j'arrive pas à la retirer ».
- **Le morphing est adouci** : ressort 0,50 → **0,72 / 0,88**, et les deux
  formes se **fondent** l'une dans l'autre (`.transition(.opacity)` sur chaque
  branche) — le cadre voyageait pendant que le contenu SAUTAIT (« trop brutal »).
- **Rien d'autre dans l'île** : ni flammes (elles y ont vécu une heure : la
  capsule passait de 250 à ~295 pt, le chrono sous l'heure du système, le stop
  sous le wifi — `captures/fiche-seance-ile.png`), ni poignée (« enlève le trait
  sous le display island, ça sert à rien » : ce qui apprend qu'on peut la tirer,
  c'est le VOL de l'aller, pas un dessin).
- **Le chrono a changé de CÔTÉ, le stop aussi** — et c'est une mesure, pas un
  goût : deux textes blancs à chiffres fixes sur la même ligne de base se lisent
  comme UNE chaîne, quel que soit l'air entre eux (« le time, il est collé sur
  l'heure » — il y avait pourtant 13 pt). Les bandes libres du haut, mesurées
  sur `captures/ile-v6-haut.png` (iPhone 15 Pro) : l'heure système finit à
  **93 pt**, le trou commence à **133**, le wifi à **~318**. Il reste 40 pt à
  gauche, 50 à droite. Le **stop** (un disque, qui ne se confond avec aucun
  texte) prend la gauche, collé au trou, et grossit (0,62 → **0,72**) ; le
  **chrono** prend la droite, en 13 pt.
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

⚠️ **PIÈGE REPAYÉ : il faut LANCER DEUX FOIS.** Un `install` suivi d'un seul
`launch --terminate-running-process` rend une app **sans ses arguments** — on
atterrit sur la porte, sans séance et sans deep link, et on croit que son
barreau ne marche pas. C'est la recette déjà écrite dans `tools/stop/voir.sh` :
deux lancements, le premier paie les caches.

## 3. CE QUI RESTE À JUGER — ? téléphone

- **le calage final de l'île n'a PAS été revu à l'écran** : la dernière
  retouche (stop collé au trou, chrono en 13 pt) est posée sur les cotes
  mesurées de `ile-v6-haut.png`, mais le simulateur a cessé de rendre une image
  neuve avant que je la recapture — c'est la première chose à regarder ;
- l'île sur un iPhone **sans** Dynamic Island (les cotes d'`IleGeo` sont
  physiques et taillées pour le trou) ;
- la cadence réelle de l'arrivée floue (un `.blur` de 26 sur deux blocs de
  texte, pendant 1,6 s, au moment même où la fiche monte ses lecteurs) ;
- que la volée de pièces atteigne vraiment la pastille (à FILMER : une capture
  ne prouve pas une trajectoire) ;
- le chevauchement chrono / heure système sur les autres modèles.
