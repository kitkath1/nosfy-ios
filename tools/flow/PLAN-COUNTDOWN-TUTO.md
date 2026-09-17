# LE DÉPART DEPUIS LA ROUTE : LE COMPTE À REBOURS ET LE TUTO QUI MONTRE (05-09-2026)

**MISE À JOUR DU 17-09 — correctif de montage57 validé au simulateur Release et confirmé sur iPhone par Kathryn ; J2 exercice58 installé, cinq parcours ciblés validés au simulateur ; J3 île reste planifié.**

La demande du 16-09 porte sur Route → `count.mp4` → Exercices et le départ
serveur. Le relais actuel est `WoopApp.demarrerDepuisChemin()`. Le film complet
est intégré en H.264,1080×1920,24 images/s,6,04s,563444octets ; les fondus sont
cuits, le son respecte le silencieux. Un tap passe, l'arrière-plan met en pause,
la fin réelle libère le lecteur. Les moteurs des pages couvertes dorment. Le correctif57 monte le lecteur dans
un overlay indépendant des ancres de la visite et ouvre Exercices à sa fin.
Il conserve la séance existante lors d’une reprise depuis Start. Le défaut56,
la forte chauffe signalée et la validation57 sont suivis dans
[la reprise du17-09](../perf/campagnes/2026-09-16-depart-count/reprise-start-17/etat.md).

Le même UUID local part dans `workouts` sans bloquer l'interface. Le serveur
ignore les doublons, une fin déjà reçue n'est jamais effacée par un départ
retardé. L'annulation ne vise que cet UUID encore ouvert ; sa file locale
persiste en cas de panne. Les tests QA et le rendu sont consignés dans
[la campagne53](../perf/campagnes/2026-09-16-depart-count/etat.md).

Les sections suivantes conservent **le plan historique du 05-09**, ses choix
et les jalons de tuto. Le17-09, l’étape exercice est codée en FR/EN, avec Passer,
sans l’ancienne horloge ; la validation58 et ses limites sont suivies dans
[la campagne du tutoriel](../perf/campagnes/2026-09-17-tuto-depart/etat.md). Ses anciens chemins/numéros de ligne
ne décrivent pas l'implémentation53. Le poids du fichier et le décodage matériel
ne prouvent pas une énergie négligeable : le coût doit être mesuré sur iPhone.

Demande historique du 05-09 :

> « On retravaille le lancement de la session depuis la route : cette vidéo
> `count.mp4` (dans Téléchargements) apparaît, **plus** un petit tuto tout
> petit — sur la page exercice, toute la page blur noir, on entoure QUE un
> exercice très finement, une petite flèche dégradé blanche (comme un dessin),
> et un texte blanc « Sélectionner un exercice pour commencer votre
> entraînement », en dessous **skip**. Et après ça sélectionne la Display
> Island : « Retrouvez ici le détail de votre séance ». Fin.
> Ce tuto apparaît **systématiquement**, mais j'ai le bouton skip. Et après,
> bien sûr, je reste sur la page exo pour sélectionner un exercice.
> **Build que sur le simu, pas le téléphone** (une autre session travaille la
> performance) — et **fais attention à la performance aussi !** »

> **Convention.** Sans marque = **vérifié** dans le code ce jour (`fichier:ligne`)
> ou **mesuré** (`ffprobe`). **?** = attend sa décision. **CIBLE** = décidé,
> n'existe pas encore.

---

## 1. LA CHAÎNE D'AUJOURD'HUI — ce sur quoi ça se greffe

| étape | où | ce qui se passe |
|---|---|---|
| le galet play | `DepartSeance.swift:193` | `panneauOuvert = true` — le panneau du départ monte |
| « Commencer » | `WoopApp.swift:1618-1626` | `depart.fermer()` · `tutoDemande = true` · `startWorkout()` |
| la séance naît | `WoopApp.swift:821-833` | `Workout()` inséré, `WorkoutActivityController.ensure`, puis **`selection = .exercises`** |
| la page exos | `ExercisesView.swift:1030` | `armerTutoSiDemande()` → le tuto **existant** (voile percé) à +0,3 s |

**Le tuto existant n'est PAS celui qu'elle décrit** : c'est un voile
`.ultraThinMaterial` percé de DEUX fenêtres (`VoileTuto`, remplissage `evenOdd`)
qui s'ouvrent en cascade sur **la card** et **la molette**, avec des liserés de
braise qui respirent (`ExercisesView.swift:1058-1150`). Pas de cercle, pas de
flèche, pas de texte, pas de skip. Et il est servi **UNE FOIS PAR
INSTALLATION** en release (`tutoExosVu`, `:1040-1043`) — en DEBUG il rejoue à
chaque départ.

Ce qu'on garde de lui : **la mécanique du voile percé** (le doigt passe à
travers la fenêtre) et **les ancres** (`anchorPreference` / `SlotAnchorKey`,
`:732` et `:2050`). Ce qu'on jette : les deux fenêtres, la cascade, la braise.

## 2. LA VIDÉO — mesurée, et telle quelle elle est INJOUABLE

`ffprobe ~/Downloads/count.mp4` :

| | mesuré | ce que ça implique |
|---|---|---|
| définition | **2160 × 3840** | **8,3 Mpx par image** — 3,4× l'écran d'un iPhone 15 Pro (1179 × 2556). Le décodeur les sort, le compositeur les REDESCEND à chaque image |
| codec | HEVC | ok (matériel), mais en 4K le coût de rééchantillonnage reste |
| cadence | 24 img/s, 145 images | |
| durée | **6,04 s** | à CHAQUE départ de séance (voir §5, question ①) |
| poids | 2,7 Mo | acceptable une fois recuit |
| audio | **piste AAC présente** | la maison joue tout MUET ; un décompte, non (question ②) |

**CIBLE — le recuit** (`tools/flow/recuit_count.sh`, jumeau des huit autres
`recuit_*.sh` du dépôt) : `scale=1179:2556` (le plus grand écran cible),
`-c:v hevc_videotoolbox` ou `h264`, CRF sage, **fondu d'entrée/sortie CUIT dans
le fichier** — ⚠️ jamais un masque SwiftUI sur une couche vidéo : un masque
force un rendu HORS ÉCRAN de tout le plan à chaque image (loi de la maison).
Sortie : `Woop/Media/count.mp4` (ressource NUE : `Bundle.main.url(forResource:)`,
`Image("count")` ne trouverait rien, en silence) + `git add` explicite.

## 3. LES TROIS JALONS

### J1 — LE COMPTE À REBOURS (entre « Commencer » et la page exos)

- Un `CinematicPlayer` (`CinematicPlayer.swift:31`, `AVPlayerLayer` nu — la
  maison ne se sert JAMAIS de `VideoPlayer`/AVKit) plein cadre, **au châssis**
  (`WoopApp`), au-dessus de tout, monté seulement pendant sa lecture.
- Il part **quand la séance naît** (`startWorkout()`), et la bascule
  `selection = .exercises` se fait **DERRIÈRE lui** : la page exos a ainsi ses
  6 s pour naître, sa vidéo de fond comprise. On gagne l'arrivée qu'on n'a
  jamais eue le temps de préparer.
- Il se démonte à `didPlayToEndTime` (jamais un minuteur parallèle : deux
  horloges finissent toujours par diverger) et **appelle le tuto**.
- ⚠️ **On ne monte rien de caché** (loi du rideau) : le player naît à
  l'ouverture, meurt à la fin. Pas d'`opacity(0)`.

### J2 — LE TUTO, ÉTAPE 1 : L'EXERCICE ENTOURÉ

Sur la page exos, tout se voile **sauf un exercice** :

- **le voile** : la matière existante (`VoileTuto` + `evenOdd`), mais **UNE**
  fenêtre. Elle épouse la card de l'exercice visé, publiée par son
  `anchorPreference` (une ancre neuve, `"tuto-exo"`, sur la première card
  visible de la grille) ;
- **le cercle « très fin »** : un `Shape` tracé à la main autour de la card —
  une ellipse **légèrement irrégulière** (deux ou trois bosses de Bézier : un
  cercle parfait ne se lit pas comme un dessin), trait **0,8 pt**, blanc à
  0,85. Il s'ÉCRIT (`trim(from: 0, to: p)` animé UNE fois, ~0,7 s) puis se
  **fige** ;
- **la flèche** : le même vocabulaire — un tracé courbe qui s'écrit après le
  cercle (retard 0,25 s), avec une pointe, en `LinearGradient` blanc
  (opaque à la pointe, éteint à la queue) ;
- **le texte** : « Sélectionner un exercice pour commencer votre
  entraînement », blanc, la fonte de la maison, sous la flèche ;
- **skip** : dessous, discret (blanc 0,45), et il **éteint tout le tuto** —
  pas seulement l'étape ;
- ⚠️ **le doigt passe à travers la fenêtre** (c'est déjà la loi du voile
  existant) : taper l'exercice entouré fait à la fois le tuto ET le choix.
  Le tuto ne bloque rien, il montre.

### J3 — LE TUTO, ÉTAPE 2 : L'ÎLE

- La fenêtre voyage de la card vers **la Dynamic Island** (`IleGeo`,
  `PiluleVagabonde.swift` — cotes PHYSIQUES, l'hôte doit ignorer la zone sûre) ;
- même cercle fin autour de la capsule, flèche qui monte, texte « Retrouvez ici
  le détail de votre séance » ;
- puis **fin** : le voile s'éteint, **on reste sur la page exos**, aucune
  navigation (« bien sûr je reste sur la page exo pour sélectionner un
  exercice »).

**Le tuto est SYSTÉMATIQUE** : `tutoExosVu` meurt, `armerTutoSiDemande` ne garde
que le `tutoDemande` du départ. Le skip ne pose aucune clé — il éteint ce
tuto-ci, pas les suivants.

## 4. LES LOIS QUI S'APPLIQUENT — la perf, puisqu'elle la nomme

1. **Une couche `AVPlayerLayer` ne coûte rien** (décodage matériel) : ce qui
   coûte, c'est ce que le fil principal redessine et ce que le compositeur
   rééchantillonne → **le recuit du §2 est la moitié du travail de perf**.
2. **Jamais de masque ni de flou SUR la vidéo** : les fondus se cuisent dans le
   fichier.
3. **Rien qui s'anime en boucle** — c'est la loi du 05-09 (§0 de
   `ANALYSE-PASTILLE-UNIQUE.md`) : le cercle et la flèche s'écrivent UNE fois
   puis se taisent. Pas de liseré qui respire, pas de halo qui pulse (le tuto
   d'aujourd'hui en a un : il meurt avec lui).
4. **Un tracé qui s'écrit est un `Shape` `trim`é, pas un `Canvas`** : un Canvas
   plein écran rasterise toute sa surface même vide.
5. **Le voile ne se recalcule pas par image** : la partition du tuto lit un âge
   (`Date`) dans UNE `TimelineView` bornée, gardée par `RythmeEcran.dort` comme
   l'actuelle — et elle s'ARRÊTE quand le tracé est posé.
6. **Un `@State` écrit par image ne vit pas sur la page** : l'état du tuto va
   dans un petit `@Observable`, pas dans `ExercisesView`.
7. Mesure obligatoire avant de dire que c'est bon : `./tools/charge.sh` puis
   `-fps` — et **la vraie cadence se mesure sur le TÉLÉPHONE**, ce qui est
   justement interdit aujourd'hui : **le verdict de perf restera donc en
   suspens**, et il faut le DIRE plutôt que le laisser croire.

## 5. LES QUESTIONS — TRANCHÉES PAR KATHRYN LE 05-09

| | la question | **sa décision** |
|---|---|---|
| ① | les 6 s à chaque départ | **on garde le film entier, ET un tap le passe** |
| ② | le son du décompte | **on le garde**, `.ambient` + `mixWithOthers` (sa musique continue, le mode silencieux est respecté) |
| ③ | quel exercice on entoure | **le PREMIER de la grille, toujours** — pas le premier visible |

⚠️ **Ce que ③ implique, et qui n'est pas gratuit** : si la page est déjà
défilée quand le tuto s'arme, il doit la RAMENER en haut avant de tracer le
cercle — sinon on entoure une card hors écran. Et le remède connu est étroit :
**`scrollPosition(id:)` fait naître la page DÉFILÉE** (piège payé le 22-08,
`woop-page-exos-couronne`) ; la seule cible juste est une **ORDONNÉE**
(`ScrollPosition(edge: .top)` + `scrollTo(y:)`). Le retour se fait AVANT le
voile, jamais pendant : une page qui défile sous un voile est illisible.

Les deux autres restent sur ma reco, à corriger d'un mot si elle veut :
**④** iPhone sans Dynamic Island → l'étape 2 se replie sur la pastille à sa
place réelle (`PiluleEtat.ancreGlobale`) ; **⑤** le décompte vaut pour TOUT
départ de séance, pas seulement depuis la route (une règle, pas une exception).

### Ce que ces réponses ferment côté code

- le tap qui passe le film : un `contentShape` plein cadre sur le player, qui
  coupe la lecture ET enchaîne sur le tuto — le même chemin que la fin
  naturelle, jamais un second chemin (deux sorties finissent par diverger) ;
- le son : `AVAudioSession.setCategory(.ambient, options: [.mixWithOthers])`,
  la recette déjà écrite dans `CarillonIle` (`PiluleVagabonde.swift:20`) ;
- la cible : une ancre `"tuto-exo"` posée sur la card d'indice 0 de la grille.

## 6. LES QUESTIONS D'ORIGINE (gardées pour l'histoire)

① **6,04 s à chaque départ, c'est long.** Trois issues : garder tel quel ·
recuire à ~3 s (couper les premières images) · laisser passer d'un tap.
**Ma reco : garder les 6 s ET permettre le tap pour passer** — le premier jour
on regarde, le trentième on tape.

② **Le son du décompte** : la maison joue tout muet. Un compte à rebours muet
perd la moitié de son effet. **Ma reco : le garder**, en `.ambient` +
`mixWithOthers` (sa musique continue) et **jamais** en mode silencieux.

③ **Quel exercice entoure-t-on ?** Le premier de la grille · le premier VISIBLE
sans défiler · un tiré au sort. **Ma reco : le premier visible** — entourer une
card hors écran obligerait le tuto à faire défiler la page, et une page qui
bouge toute seule sous un voile est illisible.

④ **iPhone sans Dynamic Island** (l'étape 2 vise un trou qui n'existe pas) :
**ma reco** — replier sur la pastille à sa place réelle
(`PiluleEtat.ancreGlobale` sait déjà la donner).

⑤ **Le compte à rebours joue-t-il aussi quand la séance est lancée AILLEURS**
que depuis la route (le galet de la home, un banc) ? **Ma reco : oui** — c'est
le départ de séance qui le porte, pas la page d'où l'on vient ; une seule règle
vaut mieux qu'une exception.

## 7. CE QUE ÇA TOUCHE

`WoopApp.swift` (le player du décompte au châssis, la bascule derrière lui) ·
`ExercisesView.swift` (le tuto : voile à UNE fenêtre, ancre `tuto-exo`, mort de
`tutoExosVu`) · un fichier neuf `TutoDepart.swift` (le cercle, la flèche, le
texte, le skip, l'état) · `tools/flow/recuit_count.sh` + `Woop/Media/count.mp4`.

**Bancs à poser** : `-countLab` (le décompte seul, sur du noir) · `-tutoDepart`
(le tuto sans décompte) · `-tutoEtape <1|2>` (une étape figée, pour la capture).
