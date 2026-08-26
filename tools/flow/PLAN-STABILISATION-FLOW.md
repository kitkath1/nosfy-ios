# STABILISER LE FLOW END-TO-END — l'audit du build téléphone (26-08-2026)

Dossier de chantier issu de l'audit dicté par Kathryn sur le build installé
sur l'iPhone (« le Frédéric »), avec ses trois captures. **Rien n'est codé
ici.** C'est la carte du terrain, l'ordre de bataille, et les quatre
décisions qui bloquent.

**Méthode de l'audit** : 15 lecteurs en lecture seule sur les 77 400 lignes /
125 fichiers Swift, 614 lectures de fichiers, consigne « un juge qui affirme
ne remplace pas une sonde qui mesure » — chaque cause devait être prouvée par
un extrait verbatim avec fichier:ligne, ou déclarée NON IDENTIFIÉE. Les cinq
affirmations qui portent le plan ont ensuite été revérifiées à la main.

**Priorité posée par Kathryn** : aucun backend, aucune nouvelle règle de
gamification, aucune nouvelle architecture. On veut d'abord traverser l'app
de bout en bout sur le téléphone sans bug.

---

## 0. LE VERDICT — ce ne sont pas 13 bugs, ce sont 5 causes

Les treize points de l'audit remontent à cinq fautes, chacune écrite
plusieurs fois dans le dépôt. C'est ce qui rend le chantier faisable : on ne
répare pas treize écrans, on répare cinq lois.

| # | La cause | Les points de l'audit qu'elle explique |
|---|----------|----------------------------------------|
| **C1** | Un état de séance écrit à la main, jamais remis à zéro | §13, §3, §4, §5, §8 |
| **C2** | Six copies du même panneau, et leurs divergences sont les bugs | §10, §12, §11 |
| **C3** | Le geste posé sous le mobilier, la surface tactile absente | §4, §9, §6, §10 |
| **C4** | Le geste annulé laisse son état périmé | §4, §6, §8, §10 |
| **C5** | Rien n'est préchauffé, rien n'est en cache, 211 minuteurs font la partition | §5, §2, §1, §3 |

---

## 1. C1 — LE FLAG DE SÉANCE JAMAIS REMIS À ZÉRO

**Mesuré.** `grep -rn "enSeance *=" Woop/` rend exactement :

```
HomeNuit.swift:1701   @State private var enSeance = CommandLine.arguments.contains("-homeSeance")
HomeNuit.swift:3108   enSeance = true      // demarrerDepuisChemin()
HomeNuit.swift:3150   enSeance = true      // commencer()
```

**`enSeance = false` n'existe nulle part dans le dépôt.** Même faute deux
fois de plus :

- `debutSeance` (HomeNuit:1702) — écrit en 3107 et 3148, **jamais remis à nil** ;
- `verreMonte` (HomeNuit:1738) — mis à `false` en 2889 par le film de départ,
  remis à `true` **uniquement** dans `fermer()` (2942), qui n'est jamais
  appelée sur le chemin slider → chemin → séance → fin.

### Ce que ce seul bug produit

La séance a **deux machines à états qui ne se parlent pas** : la vérité en
base (`Workout.endedAt`, écrite par `terminerSeance()`, WoopApp.swift:420) et
l'affichage de la home v2 (`enSeance`, un `@State` local).

- **Le player fantôme** : monté sous `if enSeance` (HomeNuit:2199) — son
  chrono continue même de tourner.
- **La Home vide** : les deux rangées de widgets ne sont montées que
  `if verreMonte` (2496 et 2540), resté `false`.
- **Le menu rangé dans la pastille**, l'invite de tirage éteinte, les curseurs
  `g` et `e` cloués à zéro, et le geste de tirage qui sort avant le cran :
  la home n'est pas seulement mal peinte, **elle est verrouillée**.
- **Le Skip du booster est innocent** : il ne fait que refermer la pop-up. La
  home était déjà cassée depuis la clôture. C'est *ouvrir* le booster qui la
  répare par accident, parce que l'éclipse du manège démonte et reconstruit
  tout le TabView (WoopApp:671, `homeEclipsee`).

### Le correctif

Le patron est déjà écrit **quinze lignes plus loin** dans le dépôt
(ExercisesView.swift:412) : `enSeance` y est *dérivé*, pas écrit.

1. Dans `HomeNuitPage` : `@Query(filter: #Predicate<Workout> { $0.endedAt == nil })`,
   puis `var enSeance: Bool { !seancesOuvertes.isEmpty }` et
   `var debutSeance: Date? { seancesOuvertes.first?.startedAt }`. Retirer les
   deux `= true`.
2. Un **seul** `onChange(of: enSeance)` qui, au passage à `false`, appelle
   `rendreLaHome()` : `verreMonte = true`, `tiroirOuvert = false`,
   `tirage = 0`, `depart = nil`, `ferme = nil`, `eGele = nil`, `gCran = 0`,
   `scroll = 0`, `axeVertical = nil`, recalcul des stats.
   ⚠️ Un seul `withAnimation` — jamais deux sur `tirage` au même tour (piège
   payé du dépôt). ⚠️ Ne **pas** réutiliser `fermer()` : elle lance un film de
   1,25 s ; on veut l'état posé, pas une cérémonie.

**Effort : S. C'est le lot 0, et il répare à lui seul §13, la moitié de §4 et
une partie de §3 et §5.**

---

## 2. C2 — SIX COPIES DU MÊME PANNEAU

`DepartSeance`, `SetEntrySheet`, `RestartSheet`, `StopSessionSheet`,
`PlayerSeance` et `BoosterPopup` portent **la même** forme : coins hauts
34 pt continuous, `glassEffect(.regular.tint(.black 0.30))`, dégradé de nuit
0,95/0,88/0,25, liseré 0,16→0,03→clear, poignée 40×5, drag min 12 / seuil 90.

Ce sont leurs **divergences** qui sont les bugs de l'audit.

### §10 — la pill Rest qui demande deux ou trois taps

`restChip(_:)` (SetEntrySheet.swift:273-379) :

- un `Button(.plain)` dont le label ne porte **aucun `contentShape`** ;
- il mesure **~53 × 36 pt** — sous les 44 pt d'Apple sur la hauteur ;
- **7 pt de gouttière morte** entre chaque pastille (6 pastilles sur 353 pt) ;
- par-dessus, tout le panneau porte `.gesture(dismissDrag)` — un
  `DragGesture(minimumDistance: 12)` **exclusif** dont le garde
  `startLocation.y < 110` est *à l'intérieur* de la closure : le geste se
  reconnaît donc sur **toute** la feuille, pastilles comprises. Un doigt qui
  roule de 12 pt pendant le tap annule le Button — et le drag, lui, ne fait
  rien.
- Un **troisième** reconnaisseur de drag (`returnDrag`,
  ExerciseDetailView:848) couvre la feuille en ancêtre.

Le jumeau `RestartSheet` (117-124) a **déjà payé exactement cette leçon** et
utilise `.contentShape` + `.simultaneousGesture` « pour que les deux boutons
gardent leurs taps ». SetEntrySheet ne l'a jamais reçue.

### §12 — l'overlay « refaire l'exercice » trop petit, et le Training qui dépasse

Trois défauts distincts, tous mesurés :

1. **Trop petit** : sa hauteur est `g.size.height * 0.52`
   (ExerciseDetailView.swift:876) calculée sur la hauteur **sans** zone sûre,
   alors qu'il est posé bord à bord — le `.ignoresSafeArea()` est sur le
   ZStack *intérieur*, pas sur le GeometryReader comme dans l'hôte canonique
   `DepartPanneauHote` (DepartSeance.swift:131-152). **≈ 48 pt perdus** sur un
   iPhone de 852 pt.
2. **Le Training dépasse** : le bord haut de `carteSeries` est à un offset
   **fixe** de 367 pt (`expandedHeader + 4`), tandis que le haut du panneau
   est **proportionnel**. Rien dans le code ne relie les deux : la couverture
   dépend du modèle d'iPhone (sur un 932 pt : bord de card à ~482, haut du
   panneau à ~496 → il dépasse de ~14 pt).
3. **Le halo fuit** : la lumière de la card est peinte par `VerreGonfle` dans
   un rectangle **28 pt plus grand** que la card et posé **après** le
   `clipShape`. Même un panneau qui affleurerait pile le bord laisserait fuir
   28 pt de halo — et il n'y a aucun voile derrière « Recommencer » (juste
   `Color.clear`) pour l'éteindre.

**Stop vs Recommencer** : deux mécaniques différentes. Stop est un
`fullScreenCover` système avec `disablesAnimations` et une entrée jouée en
interne (`posee`) ; Recommencer est un panneau in-tree animé par une
`.transition(.move)` de l'hôte. Et deux bases de calcul : **0,47 de l'écran
plein** contre **0,52 du safe**. Ils ne peuvent structurellement jamais avoir
les mêmes cotes.

**Et la non-fluidité de Recommencer est écrite ailleurs dans le dépôt** : il
re-cadre son `AVPlayerLayer` 60 fois par seconde
(`.frame(width: … * z)` piloté par TimelineView) — la faute que
`DepartSeance` et `StopSessionSheet` documentent tous les deux comme payée et
corrigée par un `scaleEffect`.

### Le correctif

Un **`PanneauQuestion` paramétré**, dans `Woop/Views/`, qui absorbe les six.
Tout l'identique descend tel quel. Entrées : titre, sous-titre, primaire,
échappée, slot média `@ViewBuilder`, voile, et
`hauteur: .contenu | .ancre(CGFloat)` — **jamais `.fraction`**, c'est elle qui
rate. Trois lois obligatoires dans le composant :

- `.contentShape(shape)` + `.simultaneousGesture(dismissDrag)`, jamais `.gesture` ;
- la zone de rangement bornée à une bande haute **géométrique**, pas un
  `guard startLocation.y < 110` dans la closure ;
- caméra en `scaleEffect` sur frame constant, jamais une mesure animée.

**Bonus** : ça donne d'un coup l'hôte du futur **Moment** (§11).

---

## 3. C3 — LE GESTE POSÉ SOUS LE MOBILIER

### §4 — le pull de la Home (le bug critique n°1)

Le geste existe et il est propre. **Il est posé au mauvais endroit** :
`tirageGeste` vit sur `fondPage` — la couche `fond()` de `MenuHote`, **sous
tout le mobilier** — alors que la bande « pull to start » que l'app te
désigne au doigt, elle, ne porte qu'un `onTapGesture`.

> C'est littéralement ça, « le tap marche mieux que le geste » : sur la zone
> d'invite, seul le tap est servi. Ailleurs c'est un damier — cards, ardoise
> de la semaine, minis, galet, pièce, nombre de l'objectif attrapent le doigt
> les uns après les autres.

Trois défauts s'ajoutent :

- **le verrou d'axe est tranché dès le premier événement** : `minimumDistance`
  vaut 14, le seuil de décision 8 — le premier événement porte déjà 14 pt, la
  décision est donc prise sur du bruit, et un geste jugé horizontal est mort
  sans appel ;
- **les seuils sont énormes** : 171 pt de pouce vers le haut pour ouvrir,
  179 pt vers le bas pour refermer, sans poignée ni tap de repli au retour
  (l'invite est rendue sourde tiroir ouvert). D'où « le retour est encore
  moins fiable » ;
- **rien n'est remis à zéro au début du geste** → voir C4.

### §9 — le scroll des séries capturé par Training

Le ScrollView des séries **existe** et il est correctement activé. Mais la
card Training entière est posée en `.overlay` avec **`.allowsHitTesting(false)`**
(ExerciseDetailView.swift:1429), ce qui rend **sourd tout son sous-arbre**,
ScrollView compris — un `allowsHitTesting` faux sur un ancêtre ne se rouvre
pas depuis un descendant.

Du coup chaque doigt tombe sur la seule surface vivante de la page : un
`Color.clear` plein écran qui porte `carteDrag` (986-989). **C'est exactement
ce que tu décris comme « je peux faire défiler le composant Training ».**

Le blame raconte la régression : le `false` date du 13-08 (cfe08e1, quand un
ScrollView de page pilotait la carte), le ScrollView de page meurt le 15-08
(bd848e7), et le ScrollView interne des séries arrive le 16-08 (8abe0e0) —
**dans un sous-arbre déjà mort. Il n'a jamais été atteignable.** Le banc
`-scrollBas` ne prouvait que le débordement du contenu, pas la joignabilité.

**Correctif** : `.allowsHitTesting(carteP > 0.90 && !carteSaisie)`, compensé
par une bande de prise `Color.clear` en overlay haut (poignée + en-tête) qui
rend la fermeture. **Effort : S. Aucun changement visuel.**

### §6 — sortir du mode édition

Le tap de sortie **existe** (HomeNuit:2686 : `if edition, vitrineSlot == nil
{ sortirEdition() }`) mais il ne se déclenche pas de façon fiable, et le tap
**sur un widget** ne fait rien du tout (la card passe en `.inerte`,
`CardTouche` ne pose alors aucun geste). Le **drag vers le bas pour fermer le
carrousel n'existe pas** : `annuler()` n'a qu'un seul site d'appel, le tap sur
le scrim.

Et le carrousel lag pour une raison lue : ce n'est ni un ScrollView ni un
TabView, c'est une roue custom (`VitrineHote`) dont le curseur est un `@State`
réécrit à chaque événement, injecté dans deux `Chambre` Animatable imbriqués
**dans un TimelineView** — les quatre cards complètes sont reconstruites à
chaque image du geste, avec sur chacune un `.blur` **et** un `.shadow` dont
les rayons changent (deux passes hors écran non cachables × 4), et sur la
nacelle active un blur posé sur un `glassEffect` **natif**. Pendant ce temps
la home reste montée et vivante sous un blur plein écran.

---

## 4. C4 — LE GESTE ANNULÉ LAISSE SON ÉTAT PÉRIMÉ

Aucune remise à zéro en tête de `onChanged`. Un geste **annulé** — celui que
le système vole au bord bas — laisse `axeVertical` et `tirage` périmés : le
tirage suivant ne répond plus, et la card peut rester bloquée à mi-course.

**C'est ça, ton « parfois ça marche, parfois rien ne se passe ».**

Un seul fichier sur cinq fait la remise à zéro correctement
(ExercisesView.swift:731-740). La forme à généraliser :

```swift
.onChanged { v in
    if debut != v.startLocation { /* tout remettre à plat */; debut = v.startLocation }
    …
}
```

plus un **chien de garde de péremption** à l'école de `SliderObsidienne.stale`
(0,18 s) qui ramène l'état au repos si plus aucun événement n'arrive et
qu'aucun `onEnded` n'est venu.

À poser dans : `tirageGeste` (HomeNuit:2733), `roueGeste` (WidgetEdition:643),
les `dismissDrag` du panneau unique, et le geste des galets (GaletEtape:131).

---

## 5. LE SCREENSHOT 1 — CE N'EST PAS UN BUG DE WOOP

L'écran entier poussé vers le bas, status bar et Dynamic Island compris, avec
un chevron gris au-dessus : **c'est la Reachability d'iOS.**

Vérifié dans le code : aucune feuille système sur le chemin de la home v2,
aucune transformation de fenêtre, **aucun `defersSystemGestures` nulle part
dans le dépôt**, et le seul chevron de la home est blanc et en bas. Le code ne
peut pas produire cette image. Or le geste qu'on te demande démarre à
**24-34 pt du bord bas** — pile dans la bande que le système se réserve.

Trois remèdes, cumulables :

1. remonter la poignée du pull hors de la bande système (C3) ;
2. `.defersSystemGestures(on: .bottom)` sur la home ;
3. **surtout C4** — pour que le geste volé par le système ne laisse pas la
   page cassée derrière lui. C'est ce troisième point qui compte le plus :
   Reachability restera toujours activable par l'utilisatrice, mais elle ne
   doit pas casser l'app.

---

## 6. C5 — LA CADENCE : RIEN N'EST PRÉCHAUFFÉ, 211 MINUTEURS FONT LA PARTITION

### §5 — la fumée puis le délai puis le menu

La fumée et le menu **ne sont pas le même événement** :

- la fumée part sur `onChanged` — doigt **posé** (MenuNappe:1266) ;
- le menu part sur `onEnded` — doigt **levé** (MenuNappe:1401).

Il y a donc au minimum toute la durée de l'appui entre les deux. Pire : dès
que le doigt dérive de plus de 12 pt (1293), le tap bascule sur `lacher()`,
qui pose un retard **explicite de 0,26 s** (1665) appliqué en `.delay(r)` sur
l'animation du menu (1786) — animation qui dure 0,78 s, les mots ne
commençant qu'à p ≥ 0,30.

Choisir une section coûte ensuite **0,13 s + 0,52 s de minuteurs avant même
que `onRoute` ne soit appelé** (1833 et 1794) : la page de destination ne
commence à se construire qu'à ~0,65 s.

### Et cette construction est chère partout

| Écran | Ce qui coûte à l'ouverture |
|-------|----------------------------|
| Progrès | ouvre un second plein écran (l'iPod) dès `onAppear`, puis 3,25 s de cinématique |
| Coffre | attend 3,25 s |
| Parcours | fait naître ~10 lecteurs AVPlayer d'un coup, 50 minuteurs étalés jusqu'à 2,2 s |
| Profil | décode un PNG 1024×1536 et le re-rastérise **sur le fil principal**, puis empile 25 dos en HStack **non lazy** |

**Aucun cache partagé de lecteurs ni de textures.** Un préchauffage de shaders
existe — **3 entrées sur 66 shaders** — et il ne couvre pas `knobSmoke`, celui
de la fumée du galet.

### Le correctif : un `Fourneau` appelé dans `WoopApp.init`

- **Shaders** : recopier l'école `CoinSmokeWarm` (CoffreFortCoin.swift:96) pour
  le chemin chaud — `knobSmoke`, `moonDust`, `banniereHalos`, `panacheInvite`,
  `diamondButton`. ⚠️ En recopiant l'**arité verbatim** du site d'appel : piège
  payé du dépôt, signature changée = page blanche sans erreur.
- **Vidéo** : un dictionnaire `nom → AVURLAsset` chargé en tâche détachée au
  lancement pour les 5-6 boucles des onglets ; les `makeUIView` fabriquent un
  `AVPlayerItem` à partir de l'asset chaud. ⚠️ **Jamais partager l'item
  lui-même** — un `AVPlayerItem` n'appartient qu'à un lecteur.

### Deux règles jumelles à passer dans la même salve

- **`paused:` obligatoire** sur toute TimelineView dont la sortie est
  invisible ou immobile. La garde se pose sur la **timeline**, jamais par un
  `if` autour d'une vue animée (piège maison : garde sur un @State animé =
  morte).
- **Ne jamais monter une couche à opacité 0** : `if lumiere > 0.001 { … }`
  (MenuNappe:1129), `if pose > 0.01 { CardsRangee(…) }` (HomeNuit:2496/2540).
  Le précédent `verreMonte` dit déjà « on démonte, on n'éteint pas ».
- **Bande morte sur le gyro** : `DemonSky.swift:41-46` et `AuroraBgLab.swift:22-24`
  publient à chaque échantillon (30 Hz) sans aucune bande morte — alors que
  `tools/porte/PLAN-V2-VIVANT.md §2.3` l'exige en toutes lettres. Deux
  `CMMotionManager` tournent **en même temps** pendant la cérémonie de
  connexion. Faire mourir `BgTilt` au profit de `SkyMotion` (qui n'est pas un
  `ObservableObject` : il n'invalide aucun body par lui-même).

---

## 7. §3 — L'ARRIVÉE DE LA HOME : la partition existe, elle est morte

Une séquence d'entrée existe déjà — mais elle n'a que **deux horloges**, et la
seconde est neutralisée. `lancer()` (HomeNuit:3243) allume la card vidéo
(`naissance`, easeOut 1,15 s dès t=0) puis, 0,38 s plus tard, lance `arrivee`
en `.linear` sur 1,46 s.

**La pill rouge n'est pas un composant SwiftUI** : c'est le calque vidéo
`home-fond-pilule` de `FondDeuxCalques`. Elle vit **dans** `GrandeCardVideo` et
arrive avec `naissance` — **la toute première chose de la page, 380 ms avant
le premier mot**. C'est exactement ce que tu vois. La faire arriver en dernier
demande de la sortir du calque vidéo, ou de retarder ce calque.

Les rangs d'apparition des widgets et de la semaine **sont écrits**
(`pose = (arrivee − 0,55) / 0,30` et `(arrivee − 0,70) / 0,30`) — mais
`CardsRangee` et `SemaineStrip` sont de simples `View` : sous `withAnimation`,
une valeur lue dans un body **saute à sa cible**. C'est le piège que le dépôt
documente lui-même. Résultat : tout ce qui n'est pas la phrase se fond
**ensemble** et **linéairement**, sans décalage ni profondeur.

**Le correctif est déjà écrit et déjà en production** : `Chambre(p:)` est le
pont `Animatable` du dépôt, utilisé dans la vitrine. Enrober
`mobilierScene(_:_:_:)` (HomeNuit:2298) dans `Chambre(p: arrivee) { a in … }`
remet à jouer **toutes** les fenêtres déjà écrites, sans en inventer une
seule. Idem pour `MenuItems` (MenuNappe:442).

⚠️ Ne **pas** remplacer par une TimelineView : celle du body de la home
(HomeNuit:1954) est volontairement pausée au repos ; la réveiller rejouerait
le piège de la page ré-évaluée par image.

Reste à ajouter : les chiffres animés (aucun widget n'en a) et le halo du fond
(`lueur`, éteint au repos — `foyer(0) = 0`).

---

## 8. §1 — LA VIDÉO WELCOME : mesurée, et ce n'est pas un flottement

**L'écran est la PORTE** (WoopApp:963 → `PorteEntree`, page 0, kicker
« WELCOME »), pas la card reward `.welcome` — c'est le seul endroit où « la
vidéo est rejouée quand on revient en arrière », écrit tel quel dans le code
(PorteEntree:768-776).

**Sonde ffmpeg + numpy** (les chiffres viennent de la mesure, pas du code) :

- `onb-arrivee.mp4` = **274 images à 30 i/s** = 9,133 s = `arriveeT` ;
- son image **178** est exactement l'image **0** de `onb-lune-loop.mp4`
  (écart 0,56/255) ;
- sa **dernière** image (273) est exactement l'image **95** de la boucle (0,56) ;
- or la boucle est un **ping-pong** de 190 images (f0 ≈ f189 à 1,82 ;
  f47 ≈ f141 à 2,16) dont **l'image 95 est le point de retournement**.

**Donc** : à la seconde précise où le film se pose et où la page s'habille
(9,133 s), la caméra **repart en arrière pour 3,13 s**, puis revient, à
l'infini. Ce n'est pas un flottement ajouté — **c'est le relais vers la
boucle.**

Le « bug » qui s'y ajoute : le trou d'`AVPlayerLooper` (1 à 3 images vidées à
chaque tour, tous les 6,33 s) découvre la pose, et au HEAD cette pose est
l'image ~94 de la boucle — c'est-à-dire **l'autre extrémité du mouvement**.
Un saut d'image, pas un flash — ce que le détecteur de flashs du jalon O1 ne
pouvait pas voir (les deux images ont la même luminance : 14,04 vs 14,94). Le
fichier **non commité** de l'arbre de travail corrige déjà ça.

**Le correctif pour figer** : couper le relais (PorteEntree:967-1002). Le
master porte déjà `actionAtItemEnd = .pause` (981) : sans relais il **gèle
tout seul sur son image 273** — c'est-à-dire exactement la position finale de
l'arrivée. Plus supprimer le `.offset(par)` de la parallaxe (753), sinon le
gyro continue de la déplacer.

⚠️ **Il y a une seconde branche** : le chemin sans film (lancements suivants,
ou après un tap-saut) monte la même boucle ping-pong via `CalqueVideo` (847).
Figer le film ne suffit pas — il faut traiter les deux branches du créneau.

---

## 9. §2 — LOGIN → HOME : d'où vient la bande noire

Il n'y a **ni `fullScreenCover` ni sheet** : le routage racine est un simple
`if showAuth` dans le ZStack de `RootView.mainBody` (WoopApp:671, 941).

**La « grosse bande noire qui descend » est un `Rectangle().fill(.black)`**
ancré en haut, dont la hauteur croît de 0 à 70 % de l'écran en 1,45 s : c'est
`PorteSortie` (PorteEntree:1113-1120), le rideau de la cérémonie de sortie.

**Le « deux écrans superposés » a une cause lue** : la cérémonie de connexion
a été écrite pour l'**ancien** écran (`AuroraLoginView` + `CineMonolith`). La
porte qui l'a remplacé n'a plus de lune vectorielle — le nuage de braises
`MoonDustOverlay` se dissout donc au-dessus d'une vidéo, à l'endroit où le
monolithe se posait sur un écran **qui n'existe plus**, pendant que l'« aube »
de la home (`ConnexionCine.birth` → `AuroraFloor`) n'est plus lue par personne
(elle vit dans `HomeAuroraView`, l'archive).

**Le lag a quatre sources cumulées, toutes lisibles :**

1. à 2,10 s, `showAuth = false` monte **tout** le TabView + `HomeNuitPage` (et
   son `AVQueuePlayer`) et démonte la porte (3 lecteurs + une `SCNView` dont
   la naissance est **mesurée à 1137 ms dans le fichier**) — dans **une seule
   transaction sans animation** ;
2. le shader plein écran `moonDust` n'est jamais préchauffé, alors que trois
   autres pipelines le sont dans `WoopApp.init` ;
3. un « four » `SCNView rendersContinuously` est programmé à splash + 9,2 s,
   alors que le film d'arrivée de la porte dure 9,133 s — **il s'allume 0,07 s
   après que le bouton devient tapable** ;
4. la home rejoue **en plus** sa propre cinématique d'arrivée pendant que la
   racine lui applique un `scaleEffect(1.05 → 1.0)` et que le nuage de braises
   tourne encore au-dessus.

**Bonne nouvelle pour le zoom-portail** : il est **déjà écrit et vectoriel**.
`MonolithScene` (LogoLab.swift:77) + la LUT `MoonSDF` (dont le canal B existe
précisément pour ne pas terrasser à ×16) + la « plongée » du splash
(×0,35 → ×10, `pow(p, 1.6)`). Il ne reste qu'à le brancher entre la porte et
la home.

⚠️ **Ce chantier suppose le lot 3 fait** — sinon on ajoute un shader plein
écran à 60 Hz sur un budget qui n'a pas été mesuré.

---

## 10. §8 — LA PAGE EXERCISE

### (a) Le flottement du player — cause lue

`WorkoutPill(docked: true)` porte
`.animation(.easeInOut(2.6).repeatForever(autoreverses: true), value: lueur)`
posée sur **tout** le pill — donc **au-dessus de ses `.padding` et de son
`.frame(height:)`** — alors que `lueur` ne pilote **que des opacités**.
`lueur` bascule dans un `onAppear` qui tombe **pendant l'insertion animée du
pill** (le `withAnimation(0.62 s)` de `enSeance`) : la géométrie en vol hérite
donc d'un aller-retour infini de 2,6 s. **5,2 s le cycle — exactement la
période mesurée le 25-08.** Le commentaire du fichier (WorkoutPill:246-249)
décrit la leçon et le correctif ; le correctif a été posé trop haut dans
l'arbre.

**Correctif** : descendre l'animation sur les seules vues dont `lueur` change
l'opacité, jamais sur le conteneur qui porte la géométrie.

### (b) Le picker

Le « picker custom » est `ArcDial` (la molette couchée, ExercisesView
1831-2171). **Elle ne prend pas le doigt du tout** (`allowsHitTesting(false)`) :
c'est la page qui la tourne depuis une bande tactile invisible de **156 pt**
collée au bas de la card (`priseBasse`), et l'engagement floute + assombrit +
recule **toute** la scène (`TheatreToucher`). D'où ta lecture « un overlay
posé au-dessus de tout ».

### (d) La molette

**Aucune physique** : deux seuils de 8 pt **en série** avant de bouger, 100 pt
de glisse par cran, et `relacher()` **ne lit jamais `v.velocity`** — il aimante
simplement `pos.rounded()`. La molette de `CalLab` (l'iPod), elle, démarre à
**2 pt** et a une vraie roue libre (omega lissé, décroissance exponentielle).
**Il y a trois molettes divergentes dans le dépôt** : `ArcDial`, la roue de la
vitrine (WidgetEdition:670-676, qui lit bien `velocity` mais borne à ±2 crans),
et celle de l'iPod. **La bonne est celle de l'iPod** — c'est elle qu'il faut
recopier.

### (c) Les catégories — ⚠️ NON IDENTIFIÉ, ET JE LE DIS

Les six sections sont Tout(28) / Haut(6) / Abdos(10) / Bas(4) / Fessiers(5) /
Cardio(3). Deux choses trouvées :

- une branche du tap qui ne fait **rien de visible** (carte jugée « dans le
  voile » → un `scrollTo` qui peut ne déplacer que 18 à 48 pt dans une section
  courte) ;
- deux bandes qui **mangent** le tap : bandeau de 123 pt en haut, prise de
  molette de 156 pt en bas.

Mais **aucune raison lue dans le code pour que ça dépende de la section**.
Verdict honnête : **non identifié**. Il faut une **sonde qui peint les zones
tactiles** et un passage sur les six catégories, pas une hypothèse habillée en
fait. C'est la règle du dépôt.

---

## 11. §11 — BRAVO ET LA CHAÎNE REWARD

**Pourquoi tu vois encore BRAVO** : elle est littéralement montée dans le flow
actif. `ExerciseDetailView.swift:856` pose `BravoView` dès que `finished != nil`,
et `finished` est écrit par `startBravo`, appelé depuis le `onFinish` de la
lentille (814), lui-même tiré par la fin du repos
(`LiquidLensLab.swift:807-814`). **Un seul point d'entrée dans le flow actif** —
le banc `-bravoLab` (WoopApp:535) est à part.

**La chaîne reward n'est pas branchée** : `declencherRewardFlow()` est gardé
par l'argument `-rewardFlow` (87), et le seul déclencheur vivant de
`RewardPopup` est le **fake** du chip « … » (1634).

**Ce qui existe déjà** : les 6 robes de `RewardPopup` (`.halo` `.neon` `.galet`
`.spotlight` `.fire` `.welcome`), le slot vidéo, 10 fichiers `reward-*.mp4`.
**Ce qui n'existe nulle part** : la **pill de fin de série** et le **Moment** —
les plans du 25/26-08 (`tools/rewards/CHANTIERS-UX.md` §3, §4) les décrivent et
disent eux-mêmes « rien n'est codé ».

**Le point de branchement du décideur** : `LiquidLensLab.swift:807-814`, le
`onFinish` de la lentille — le seul endroit où l'outcome part **une** fois.
⚠️ Pas une minuterie de plus.

⚠️ **Piège à ne pas rater** : `BravoPillView` vit dans `BravoLab.swift` et est
consommé par `CoffreFortView.swift`. **Archiver ne peut pas être supprimer le
fichier.**

`tools/rewards/CHANTIERS-UX.md` §9 posait « le sort de BRAVO : décision
produit en attente ». **Kathryn a tranché le 26-08 : morte du flow actif.**

---

## 12. §7 — LE PARCOURS : ce qui manque vraiment

Le modèle d'état est un enum à 5 cas (`EtapeEtat`, GaletEtape.swift:20) dérivé
d'un **seul entier** (`EtatDuo.etape`) par comparaison d'index. **Il n'y a
aucune notion de date, de « terminé » ni de « raté » dans le code** :
`etatDe()` ne connaît que avant / égal / après.

- Le rendu ne distingue quasiment pas les états : les gains du shader vont de
  **0,85 à 1,0** et l'opacité de l'encre de **0,85 à 1,0**.
- Le galet actif n'a **aucun halo** — juste une respiration injectée au shader.
- Les galets portent un **numéro d'étape 1..10**, jamais une date.
- **Il n'existe pas d'objet « chapitre »** : un chapitre = un index d'écran 0..4
  avec 10 étapes. Le seul galet lune est le nœud-trésor **unique** du 5e écran
  (`tresor: ecran == 4 && n == 9`) — il faut donc en créer un **par chapitre**.
- Les deux entrées vers la séance existent et tombent toutes les deux dans
  `ouvrirChemin()`. **Rien à faire de ce côté.**

**La mini-card « Toute la semaine »** est `SemaineStrip.mini(_:)`, méthode
**privée** dans `SemaineStrip` (HomeNuit.swift:1533). Bonne nouvelle : **aucune
dépendance** à l'environnement, au store ni à un `@State` parent — l'extraire
est un refactor pur.

⚠️ **Mais** : même sur la Home, **la date et le sticker sont fabriqués** (dates
= les N derniers jours, sticker = index modulo 5). « Vraie date, vrai
sticker » demande un câblage aux `Workout` **qui n'existe nulle part**. C'est
du backend. → **Décision n° 2 ci-dessous.**

---

## 13. L'ORDRE DE BATAILLE

Une salve par lot. Chaque lot est fouetté au simulateur (transitions filmées,
détecteur de flash, `SondeCadence` par régime, allers-retours d'états) **puis
verdict téléphone avant la salve suivante**. On ne cumule pas deux lots non
validés.

### LOT 0 — DÉBLOQUER (XS/S, chaque item indépendant et réversible)
1. **C1** : dériver `enSeance` / `debutSeance` du `@Query` + le `onChange` qui
   remet la home debout (dont `verreMonte = true`).
   → répare §13 en entier, plus une part de §3, §4, §5.
2. **§9** : `allowsHitTesting` conditionnel sur la card Training + bande de
   prise. → §9 en entier, zéro changement visuel.
3. **§1** : couper le relais de la vidéo welcome, sur les **deux** branches.
4. **§11a** : retirer `BravoView` du flow (5 appels, tous dans
   `ExerciseDetailView`), sans toucher au fichier `BravoLab.swift`.

### LOT 1 — LE DOIGT (S/M)
C3 + C4 + Reachability, en une seule passe sur la grammaire des gestes.
Remise à zéro sur `startLocation` + chien de garde de péremption partout ;
`tirageGeste` porté sur `InviteTirage` (poignée ~100 pt, `minimumDistance ≥ 6`)
et posé en `.simultaneousGesture` sur `MenuHote` ; seuils divisés ;
`.contentShape(Rectangle())` sur tout conteneur qui rattrape un tap dans le
vide ; `.defersSystemGestures(on: .bottom)`.
→ **§4, §6** (dont le drag-vers-le-bas du carrousel et le tap sur widget), §10 partiel.
**Avant de signer : une sonde `-pullSonde` qui peint les zones tactiles.**

### LOT 2 — LE PANNEAU UNIQUE (M)
C2 + C3 : écrire `PanneauQuestion` et y faire entrer les six copies, avec
`contentShape` + `simultaneousGesture` + hauteur par contenu/ancre + caméra en
`scaleEffect` sur frame constant. Sortir Stop du `fullScreenCover` pour qu'il
partage l'hôte in-tree de Recommencer.
→ **§10 et §12 d'un coup**, et l'hôte du futur Moment.

### LOT 3 — LA CADENCE (M)
(a) Le `Fourneau` : préchauffage des shaders du chemin chaud (arité verbatim)
+ cache d'`AVURLAsset`. (b) `paused:` sur toutes les TimelineView invisibles,
et ne plus monter les couches à opacité 0. (c) Bande morte du gyro, puis mort
de `BgTilt` au profit de `SkyMotion`. (d) Le flottement du player (§8a).
→ **§5, §8a**, et le socle indispensable au §2.

### LOT 4 — LA CHORÉGRAPHIE (M)
C5 + `Chambre(p:)` : brancher le pont Animatable sur le mobilier de la home et
sur `MenuItems` ; supprimer les minuteurs qui font office de partition (le
0,26 s, les 0,13 + 0,52 s du menu, le four à 9,2 s, la cascade du parcours) ;
sortir la pill rouge du calque vidéo pour qu'elle arrive en dernier ; les
chiffres animés ; le halo du fond.
→ **§3, §5** en entier.

### LOT 5 — LES REFONTES (L, une par salve)
Dans cet ordre de dépendance :
1. **§11** — le décideur rewards branché sur `LiquidLensLab.onFinish` : pill /
   Moment / popup / vidéo, selon `tools/rewards/PLAN-REWARDS-BACKEND.md`.
2. **§7** — les états de galets (dates, terminé / raté / futur / actif) + le
   galet Lune par chapitre + la mini-card réemployée.
3. **§8b/§8d** — le picker natif et la molette recopiée de l'iPod.
4. **§8c** — les catégories, après la sonde tactile.
5. **§2** — le zoom-portail lune (suppose le lot 3 fait).

**§14 (l'expérience de fin)** : on n'y touche pas. On garde ce qui existe. Le
but du chantier est seulement « terminer la séance → état propre → aucune UI
fantôme » — c'est le lot 0.

---

## 14. LES QUATRE DÉCISIONS QUI BLOQUENT

### D1 — §1 et §2 se disputent les mêmes trente lignes
§1 veut **figer** le header de la page 0 de la porte (couper le relais,
supprimer l'offset de parallaxe). §2 veut y **monter une lune vectorielle**
(`MonolithScene`) comme point de départ du zoom-portail, en remplaçant ou en
surchargeant `onb-lune-loop`. **Il faut trancher l'ordre** : figer d'abord et
refaire le portail après (au risque de refaire le travail), ou attaquer le
portail directement (au risque de garder le glitch plusieurs jours).
→ *Ma recommandation : figer d'abord (lot 0, effort S), portail au lot 5. Le
glitch te gêne à chaque lancement ; le portail est une cérémonie.*

### D2 — la mini-card du parcours : vraies données ou données fabriquées ?
Sur la Home, la date **et** le sticker sont fabriqués. Réemployer le composant
tel quel donne le bon design tout de suite mais avec de fausses données ; le
câbler aux `Workout` est du backend, que tu as explicitement repoussé.
→ *Ma recommandation : réemployer tel quel maintenant, câbler au backend.
Sinon §7 est bloqué par la chose qu'on a décidé de ne pas faire.*

### D3 — BRAVO : morte, ou recyclée en Moment ?
Le plan la retire du flux par défaut. `tools/rewards/CHANTIERS-UX.md` §9 laisse
la porte ouverte à un recyclage « fin d'exo ». Tu as dit « archivée et
supprimée du flow actif » — je le lis comme : **retirée du flow, fichier
conservé** (il le faut : `CoffreFortView` consomme `BravoPillView`). Confirme
si tu veux aussi qu'elle disparaisse comme mise en scène possible d'un Moment.

### D4 — §8b, « le picker natif Apple » : lequel ?
`ArcDial` est une molette couchée qui ne prend pas le doigt. Un `Picker` natif
iOS 26 changerait complètement la page (la molette, sa bande de prise de
156 pt, et le `TheatreToucher` qui recule la scène disparaissent tous les
trois). Deux lectures possibles de ta demande :
- **(a)** remplacer `ArcDial` par un vrai `Picker` natif (le plus proche de tes
  mots, refonte de la page) ;
- **(b)** garder la molette mais lui rendre le doigt (`allowsHitTesting(true)`,
  physique de l'iPod) et supprimer l'effet d'overlay (`TheatreToucher`).
→ *Ma recommandation : (b) d'abord — c'est ce qui règle « difficile à
comprendre » et « pas assez sensible » d'un coup, sans refonte. Si le rendu ne
te va toujours pas, (a) au lot suivant.*

---

## 15. ⚠️ L'ÉTAT DU DÉPÔT — À LIRE AVANT DE COMMITTER

- **Trois autres sessions Claude tournent sur ce dépôt.** L'une a committé
  **pendant** l'audit. Fichiers déjà emportés par le passé :
  `Woop/Figures/CoinChime.swift`, `HomeAuroraView.swift`, `JewelTabBar.swift`,
  `Theme.swift`.
- **16 fichiers source modifiés non commités** (587 lignes) +
  `Woop/Views/PlayerSeance.swift` (274 lignes) **non suivi** + 2 stickers.
  Deux chantiers en vol indépendants : (A) la chaîne de fin de séance / player,
  (B) la robe texte du Welcome Back.
- **Les 13 dossiers `dd-*` (8,7 Go de DerivedData Xcode) sont TRACKÉS dans
  git** : 32 368 fichiers suivis. Le `.gitignore` ne fait que 4 lignes et ne
  les couvre pas. C'est **toute** la cause du `git status` illisible (le diff
  HEAD complet annonce 25 190 fichiers modifiés).
  → **Un `git add -A` serait catastrophique.** Committer **par chemins
  explicites**, et relire `git log -3` **avant chaque commit**.
  → *Proposition à valider : ajouter `dd-*/` au `.gitignore` et
  `git rm -r --cached dd-*` en une salve dédiée, avant le lot 0.*
- **6 worktrees** dont 5 hors du dépôt principal (`~/Downloads/woop-*`) —
  chacun peut committer dans le même `.git`.

---

## 16. LES PIÈGES DU DÉPÔT À RELIRE AVANT CHAQUE SALVE

- Un `@State` écrit à chaque image sur la vue qui contient tout → la page
  entière se ré-évalue.
- `.ignoresSafeArea` + `offset` sur un ScrollView → ping-pong d'insets, toute
  la page respire.
- `glassEffect` natif redimensionné frame par frame → blur plat définitif. Un
  verre se **démonte**, il ne se fond pas.
- Deux `withAnimation` sur la même valeur au même tour → **rien**. Un
  aller-retour se fait en **keyframes**.
- Garde sur un `@State` animé = morte. Le ressort se pose sur le
  **modificateur**.
- Un `Color.clear` parmi des enfants en `.position` n'attrape pas les gestes.
  Une vue sans taille intrinsèque n'est pas tappable. Un `Button` sous un
  `DragGesture` à `minimumDistance` 0 est affamé.
- Un stitchable dont la signature change sans l'appel Swift → **page blanche
  sans erreur**.
- `xcodebuild | grep` rend le code de `grep` : build échoué = « exit 0 », app
  périmée capturée. **Stat du binaire avant capture.**
- Mesurer une couleur sur les **pixels clairs**, jamais en moyenne de ligne.
- **Et la règle qui prime** : un juge qui affirme ne remplace pas une sonde qui
  mesure. Le §8c est marqué NON IDENTIFIÉ pour cette raison — il faut une
  sonde avant une ligne de code.
