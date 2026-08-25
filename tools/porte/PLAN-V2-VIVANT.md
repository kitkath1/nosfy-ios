# PORTE V2 — LE VIVANT : la parallaxe, la caresse, les alignements

Plan dicté le 2026-08-22 au soir. **Rien ne se code tant que ce plan n'a pas le
GO.** Frère de `PLAN-V2-OUVERTURE.md` et `PLAN-V2-MANEGE.md`.

Le verdict, mot pour mot :
- « comment rendre ça plus **premium et beau et interactif** à cette étape de
  login ? on peut faire **bouger au doigt la vidéo** ou quelque chose comme
  les **images gyroscopiques** ? » ;
- « il manque un effet quand je passais mon doigt au drag — avant il y avait
  de la **lumière qui sortait de mon doigt**, un halo » ;
- « les **textes** des autres sections **ne sont pas alignés** comme Welcome…
  pas même hauteur et pas même début » ; « les **petits points blancs** ne
  sont pas alignés bien sous le texte ».

---

## 1. LES ALIGNEMENTS — un bug, mesuré, une ligne de remède

### 1.1 Le diagnostic (prouvé au profil numpy sur les captures)

| page | bord gauche du texte mesuré | attendu |
|---|---|---|
| 1 | ~26 (le kicker) | 26 |
| 2 | **56,7** | 26 |
| 3 | **54,0** | 26 |
| 4 | **101,0** | 26 |

Et les dots, eux, sont **exactement à 26,0** : ce ne sont pas eux qui sont
désalignés — c'est le texte qui n'est pas à sa marge. Ils *paraissent* faux
parce que la référence au-dessus d'eux flotte.

**La cause, classique** : dans `blocTexte`, le `VStack(alignment: .leading)`
n'a pas de largeur imposée — il prend la largeur de sa plus longue ligne, et
`containerRelativeFrame` le **CENTRE** dans la page. Plus le texte est court,
plus il dérive vers le centre (« Finish a session, » → 101 pt).

**Le remède** : `.frame(maxWidth: .infinity, alignment: .leading)` entre le
VStack et ses paddings. Une ligne. Toutes les pages tombent à 26,0.

### 1.2 La hauteur — la zone de texte devient FIXE

Mesuré : les premières lignes tombent à ~482 / 489 / 525 pt selon la page
(2 ou 3 lignes, kicker ou pas). Le remède est une **zone de texte à gabarit
fixe**, ancrée au bas du header, identique sur les quatre pages :

```
┌─ zone de texte (hauteur FIXE = kicker + 3 lignes) ──────┐
│ KICKER  (11 pt, tracking 3,2 — présent sur les QUATRE)  │
│ ligne 1                                                 │
│ ligne 2                                                 │
│ [ligne 3 éventuelle]                                    │
└──── ancrée à texteSurArete du bas du header ────────────┘
```

- Le contenu est **top-aligné dans la zone** : la première ligne de chaque
  page tombe au même y, au pixel. Une page de 2 lignes laisse du vide en bas
  de zone — invisible, les dots sont hors scroll à y fixe.
- **Un kicker sur les QUATRE pages** — c'est ce qui garantit l'alignement ET
  c'est mieux : `WELCOME` / `EXERCISES` / `PROGRESS` / `BOOSTERS`. (Variantes
  à choisir à l'écran : `TRAIN` / `TRACK` / `REWARDS`.)
- La page 3 est **recomposée en lignes écrites à la main** (le retour à la
  ligne est une décision, jamais le hasard d'une largeur) :
  « Track your performance / and become / your best version. »

### 1.3 La vérification

Profil numpy sur les 4 captures `-portePage` : bord gauche = **26,0 ± 0,3**
partout, première ligne au **même y ± 0,5** partout, dots inchangés à 26,0.

---

## 2. LA PARALLAXE — la vidéo qui bouge au poignet ET au doigt

### 2.1 Le moteur : `SkyMotion`, et c'est un verdict de recon

Trois moteurs d'inclinaison coexistent. Le bon pour une page entière est
**`SkyMotion`** (`DemonSky.swift:17-62`) — il est *conçu* comme une dérive de
caméra de scène : double filtre (passe-bas ~0,8 s + **recentrage ~15 s** : il
lit l'écart à la tenue habituelle, pas l'angle absolu), partagé entre écrans,
et **seul à respecter `reduceMotion` à la source**.

Écartés : `BgTilt` (un CMMotionManager par vue, **aucun stop()**, publie à
60 Hz **sans bande morte** — l'invalidation par image incarnée) ; `LuneMotion`
(calibré pour un objet tenu en main, réponse vive — trop nerveux pour une
page).

⚠️ **Les trois pièges payés de SkyMotion, à respecter :**
1. il ne démarre pas tout seul — le bug du 19-08 : « la parallaxe lisait des
   zéros sur téléphone ». `start(reduceMotion:)` à l'apparition de la porte,
   relance sur `scenePhase == .active` ;
2. **pas de refcount** : ne jamais appeler `stop()` depuis la porte (on
   couperait le poignet de toute l'app — le bug qui a imposé le compteur de
   clients à LuneMotion) ; la porte est un écran d'entrée, la home reprend
   le même singleton derrière ;
3. muet au simulateur → le fallback est LE DOIGT (§ 2.3), et le verdict est
   au téléphone.

### 2.2 La géométrie — transformer, jamais redimensionner

La loi est écrite et payée (`DepartCine.swift:251-254`) : un `AVPlayerLayer`
dont la frame change relayoute et re-rend chaque image. **La parallaxe passe
donc par `offset` — un transform — sur un cadre FIGÉ.** Le précédent existe
mot pour mot : `DepartLoopVideo` vit déjà en `.frame` fixe +
`.scaleEffect(pose*respire)` + `.offset(x:dx, y:dy)` dans une TimelineView.

- **Le cadre du header est surdimensionné de ±8 pt** (418 × 628 au lieu de
  402 × 612), centré, débordement mangé par le clip existant. L'upscale passe
  de ×1,117 à **×1,161** @3x — sur de la matière verre/lueur, imperceptible ;
  à re-juger au téléphone, et le cran de repli est ±6 (×1,150).
- L'offset de parallaxe : `±8 pt × tilt` — la vidéo SEULE bouge. Les dots et
  le texte restent cloués (un contre-mouvement du texte est un cran 2, à ne
  tenter qu'après verdict).
- ⚠️ L'ordre des transforms compte : `scaleEffect` PUIS `offset` (l'inverse
  multiplie le déplacement — 62 pt de course parasite, payé).
- ⚠️ Le masque du fondu de pied reste calé sur l'ÉCRAN, après le cadre — il
  ne voyage pas avec la parallaxe.

### 2.3 Le doigt + le poignet, sommés

Le précédent exact existe : `AuroraBgLab.swift:47-90` somme `tilt.value` et
`fingerTilt` sur la même translation, avec un **ressort de retour**
(`e^-4Δt · cos 9Δt`) au lâcher. On recopie l'école :

- le doigt qui se pose et glisse **sans paginer** (drag vertical ou micro-drag)
  pousse la vidéo de ±10 pt de plus, ressort au lâcher ;
- pendant une PAGINATION (drag horizontal franc), la parallaxe doigt se tait —
  le croisé est déjà le mouvement ;
- au simulateur, c'est ce chemin-là qui permet de juger sans gyroscope.

⚠️ **La bande morte est obligatoire** : l'écriture du tilt dans un
`@Observable` ne publie que si |Δ| > 0,002 (l'école BacMotion) — sinon on
recrée « la page qui se ré-évalue par image ». Et seul un **enfant dédié**
(`PorteHeader`) lit cette valeur, jamais la page.

`reduceMotion` : parallaxe morte des deux côtés (le moteur refuse déjà de
démarrer ; le consommateur zère aussi — la double garde de l'école SkyMotion,
« un seul des deux ne suffit pas car un autre écran a pu démarrer le
singleton »).

---

## 3. LA CARESSE — la lumière qui sort du doigt

### 3.1 D'où elle vient, et le piège du fichier éponyme

La caresse de l'écran de connexion vit en deux moitiés :
- **Swift** (`LoginLab.swift`) : un calque `Color.clear` + `DragGesture(
  minimumDistance: 0, coordinateSpace: .global)` échantillonne le doigt
  toutes les ~28 ms en `TouchTrace(point, born)` — cap 10 points, vie 1,4 s,
  triplets (x, y, âge) avec sentinelle `[-4000, -4000, 9]` ;
- **Metal** : ⚠️ **PAS `LoginAurora.metal`** — ce fichier est l'ARCHIVE. La
  version en production est `bgAuroraLogin` dans **`AuroraBg.metal:634-673`**.
  Transplanter depuis la bonne source.

Les maths, verbatim (à recopier telles quelles) : amplitude
`exp(-âge/0,65) · (1 − smoothstep(1,0 ; 1,4 ; âge))`, gaussienne isotrope qui
**s'évase avec l'âge** (`sig = 55 + 80·âge` pt), couleur blanc-crème
`(1,00 0,96 0,88)` qui **dore** dès 0,45 s `(1,00 0,78 0,42)`, accumulation
tone-mappée `1 − exp(−L·1,70)` — elle éclaire sans jamais écrêter.

### 3.2 Le shader autonome — `PorteCaresse.metal`

La boucle est extractible : elle ne dépend du fond que par **deux** choses,
et les deux ont leur remède :
1. `cur` (la texture des rideaux fbm, « la lueur a la matière du fond, jamais
   du coton ») → on recopie le petit `bgFbm` (4 octaves, `static` dans
   AuroraBg.metal) dans le nouveau fichier : la lueur garde sa matière ;
2. le **fondu écran** final (il compose contre le fond dans le même shader)
   → en couche autonome au-dessus des VIDÉOS, la sortie devient **émissive en
   `.plusLighter`** : `half4(rgb_lumière, 0)`.

⚠️ **Les quatre pièges payés, tous documentés :**
- **le prémultiplié fond clair** : toute « lumière » dont couleur < alpha
  ASSOMBRIT un fond clair — invisible sur banc noir, visible sur la vidéo.
  Sortie émissive pure, jamais un alpha qui voile ;
- **l'hôte `.clear` annule tout** au `* color.a` final (payé sur la gerbe du
  swap) : l'hôte du `colorEffect` est un `Rectangle().fill(.black)` opaque en
  `.plusLighter` (noir additif = identité) ;
- **l'arité du stitchable** : nouvelle signature (sans tilt/cine) = nouvel
  appel `ShaderLibrary` complet, changés ensemble ;
- **la passe qui peint du vide** (l'école MenuNappe) : le sous-arbre entier
  est **ABSENT quand `traces` est vide** — au repos, la caresse ne coûte pas
  un pixel. (Dans le login, la sentinelle âge 9 tournait à vide dans un fond
  déjà payé ; en couche autonome ce serait du pur gâchis.)

### 3.3 Le geste — la coexistence avec le scroll, LE point neuf

Le login n'a pas de scroll ; la porte, si. Le drag de la caresse doit donc
être **`simultaneousGesture`** (l'école StoryFlow : décider sans voler) :
- pendant une pagination, la traîne SUIT le doigt qui feuillette — la lumière
  accompagne le geste, c'est le premium demandé ;
- le calque de caresse vit AU-DESSUS du header et du contenu passif, SOUS le
  bouton (qui garde ses touches) ;
- ⚠️ `contentShape(Rectangle())` obligatoire sur le calque clair (sans lui,
  rien n'attrape — la vue sans taille intrinsèque) ;
- ⚠️ coordonnées : le geste est en `.global` et l'hôte du shader doit être
  full-bleed à (0,0) — c'est le cas de la porte (`ignoresSafeArea`) ; sinon
  conversion obligatoire.
- l'haptique du login vient avec : tic doux tous les 90 ms
  (`sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55))`) et
  `SparkleChime.breath()` au début de chaque caresse (les sons existent).

---

## 4. LES JALONS

| | jalon | vérification |
|---|---|---|
| **V1 ✅** | Les alignements | **FAIT 22-08 soir, mesuré** : kicker à y = 462,7 sur les QUATRE pages, première grande ligne à 491,0-491,7 (±0,35 pt — la géométrie des glyphes, plus rien du layout), bord gauche 27-28 partout (dots inchangés à 26,0). Kickers posés : WELCOME / EXERCISES / PROGRESS / BOOSTERS ; page 3 recomposée en 3 lignes écrites. |
| **V2 ✅** | La parallaxe gyro + doigt | **CODÉ + fouetté au sim.** Cadres surdimensionnés ±10 (upscale ×1,172), mouvement en `.offset` sur le contenu SOUS le masque (le masque reste cloué à l'écran), somme gyro ±6 + doigt ±6 bornée à la marge, ressort au lâcher, double garde reduceMotion. ⚠️ En route, UN VRAI DÉFAUT attrapé : `CinematicPlayer` (aspect-FIT en dur) laissait 3,4 pt de colonnes vides sur le film d'arrivée surdimensionné — que la parallaxe aurait fait entrer dans le champ → `ReelHote` (fill + clip). **Le gyro ne se juge qu'au téléphone** (muet au sim — le fallback doigt y est le seul témoin). |
| **V3 ✅** | La caresse | **CODÉ + capturé.** `PorteCaresse.metal` : les maths de `bgAuroraLogin` verbatim + fbm embarqué pour la matière, hôte noir opaque en plusLighter (le patron nebulaStars). Geste SIMULTANÉ (jamais volé au scroll), cadences du login à la lettre (28 ms / 1,4 s / cap 10 / souffle / tic 90 ms), sous-arbre ABSENT au repos. Banc `-porteTrail` : la traîne figée capturée, crème → doré par-dessus la vidéo. |
| **V4** | **Verdict téléphone** | l'amplitude des deux parallaxes, la chaleur/intensité de la traîne sur les vidéos, l'haptique de la caresse. ⚠️ Cadence : au sim les montages de créneau coûtent ~1 image de plus qu'avant les cadres élargis (44-93 ms aux glissements, machine calme) — dans la classe acceptée, mais LE chiffre à revérifier au téléphone à la SondeCadence. |

L'ordre : **V1 d'abord** (c'est une correction, pas un ajout), puis V2 et V3
qui sont indépendants l'un de l'autre.

---

## V3 — LE SECOND VERDICT (23-08) : les textes, les widgets, la démo

### Les textes — deux lignes, plus épais, près du bouton

- **Deux lignes MAXIMUM**, et c'est une loi d'écriture, pas une contrainte de
  place : la page 3 qui débordait a été **réécrite** (« Track your performance
  / and become your best. »), jamais rétrécie. La page 1 aussi, une fois passée
  en semibold (« Training, remembered. »).
- **Inter 27 semibold** — la vraie graisse du fichier (`Inter-SemiBold`),
  jamais un `.fontWeight` qui ferait synthétiser un gras et baverait sur du néon.
- **Descendus de 54 pt sous l'arête du header**, dans la nuit de la flamme : un
  seul saut d'œil jusqu'au bouton au lieu de deux.

**⚠️ ET LA DESCENTE S'OBTIENT EN AGRANDISSANT LE SCROLL, JAMAIS PAR UN PADDING
NÉGATIF.** Payé, et visible d'un coup d'œil : `padding(.bottom, -54)` faisait
bien descendre le bloc, mais **un `ScrollView` CLIPPE son contenu à son
cadre** — le texte sortait dessous et se faisait TRANCHER EN DEUX (verdict :
« c'est cassé, regarde tous les textes »). Le scroll mesure donc
`hHeader + descenteTexte` et le bloc reste bottom-ancré dedans. Les dots
retrouvent du même coup leur cote de 18 pt.

### Les deux widgets de la home v2 (page 3)

Les VRAIES cards (`CardsRangee`), en verre comme sur la home — leur encre est
au-dessus de leur propre verre, qui n'a donc que la vidéo à manger.
- slots **`[.volume, .regularite]`** — le verdict a écarté Peak au profit de la
  régularité **avec les mois** ; ⚠️ les mois n'apparaissent QUE si `moisFaits`
  est non-nil, sinon la card montre la semaine.
- **échelle 0,80, constante** — ⚠️ jamais animée : le verre natif redimensionné
  image par image rend un blur plat définitif (piège payé). Seule l'opacité vit.
- posées à **0,56 × hauteur** du header : à 0,30 elles « flottaient dans un
  grand vide » (verdict). Arête basse ~479, texte à 545 : 66 pt d'air.

### La carte « Sets » (page 2)

La vraie `FlammeJauge` de la fiche d'exercice, à **0,74**, centrée — et elle
JOUE : les séries se valident une à une, les cinq flammes s'allument, le compte
roule en `numericText`. Sa cinématique est sa propre démonstration, sur la page
qui dit « log every set as you go ».
- L'horloge vit DANS le composant : la porte ne se réévalue pas pour une flamme.
- Le sous-arbre entier est absent hors de la page 2.
- ⚠️ La commodité `FlammeJauge(done:)` ne prend pas `total`/`contrat`
  (extension `where Detail == EmptyView`) : la ligne de contrat impose l'init
  mémoire complète et un `detail: { EmptyView() }` explicite.

### La caresse s'arrête avant le manège

Verdict : « tu enlèves la couleur qui suit le doigt, on doit pouvoir faire
tourner le manège ». La traîne meurt au **seuil p < 2,4** — avant l'arrivée,
pas à la pose : elle ne doit pas s'éteindre SOUS le doigt. Et on n'échantillonne
même plus le doigt au-delà, sinon le geste de rotation remplirait le tampon
pour rien et la traîne réapparaîtrait d'un coup au retour.

Deux raisons, la seconde suffirait : la traîne SALIT une scène 3D qui a sa
propre lumière, et surtout elle dit au doigt qu'il **dessine** là où il
**tourne** — deux gestes contradictoires sur le même pixel.

### Le film rejoue au retour sur la page 1

Rien à armer : le créneau pair porte le film tant que `arriveeFinie` est faux,
et il est démonté chaque fois qu'on quitte la page 1. Revenir le remonte,
`onAppear` repart, le master rejoue du noir — et la règle pair/impair garantit
que ce remontage tombe TOUJOURS à opacité zéro.

⚠️ Le drapeau a donc changé de sens : il ne dit plus « le film est consommé »
mais « on vient de sauter ». **Et il s'oublie en partant** — laissé posé, un
seul tap-saut aurait tué le rejeu pour toujours.

---

## V4 — LE VERDICT DU 24-08 : quatre corrections, et UNE loi payée deux fois

### ⚠️ LA LOI : `scaleEffect` DÉTRUIT LA MATIÈRE D'UN SHADER ET D'UN VERRE

C'est la cause COMMUNE de deux verdicts distincts — « la carte est un fond
noir » et « les widgets, c'est pas liquid glass ». J'avais mis `0,74` sur la
carte et `0,80` sur les widgets pour les rapetisser.

- **Sur un shader** : SwiftUI compose dans un tampon puis AGRANDIT ce tampon.
  Le grain, la veine d'or et le liseré hairline se rastérisent — il ne reste
  qu'une plaque sombre. (Cousine de la loi du zoom rastérisé, `StoryVideo.swift:36-54`.)
- **Sur un verre natif** : une échelle rend un **blur plat** — il cesse de lire
  comme du verre (la famille du « verre aux bounds vivants »).

**LA RÈGLE : un composant en shader ou en verre se redimensionne par sa
LARGEUR/son CADRE, jamais par une échelle.** Carte à `frame(width: 268)`,
cards à `cote = 136`.

### Le « verre gonflé » ne vient pas de la carte — il vient de DERRIÈRE

Ma carte et celle de la fiche d'exercice sont **le même `FlammeJauge`** ; je
l'appelais **nu**, la fiche l'appelle **encastré** :

```
dansEcrin: true      // les rayons rentrent, la veine d'or s'éteint
bandeau: 40          // LA BANDE DE LUMIÈRE en tête
liseré: 1            // le filet qui cerne la dalle
```

Le composant le documente : « le composant n'y dessine rien d'opaque —
**l'aurora de l'hôte y passe** — mais il y POSE la poignée et les cinq
flammes ». **Le bandeau est un TROU** : c'est par lui que le verre remonte, et
c'est ce trou qui fait le renflé et les cheveux de lumière sur l'arête. Sans
`bandeau`, pas de trou, donc pas de verre : une plaque sombre. La poignée grise
vient de là aussi — elle est le SIGNE de l'encastrement, pas un ornement.

Le verre lui-même : la recette exacte de la dalle du player
(`SessionSlate.corps`) — `glassEffect(.regular.tint(black 0,30))`.

### Le « fondu blanc toutes les 5 s »

Le compteur de démo, arrivé à 5, **redescendait à 0 EN ANIMATION** : la jauge
se vidait, les cinq flammes s'éteignaient une à une en ressort. Vu de loin, la
carte semblait disparaître. **Un cycle de démo se rembobine hors champ, il ne
se joue pas à l'envers** : la remise à zéro est passée en
`Transaction(disablesAnimations)`.

### La cadence, et ce que j'ai eu tort d'en conclure

Mesuré : verre sur vidéo vivante **14 img/s**, verre sur du noir **59**. J'en
avais tiré un remède — remplacer la vidéo par son image de pose sous les
verres — qui rendait bien 60 img/s. **Arbitrage de Kathryn : révoqué.** « La
vidéo se reflète justement dans leur verre » — c'est le sujet, pas un effet de
bord, et la home porte ces mêmes verres sur sa vidéo depuis toujours. Mesure
finale, vidéo vivante sous les verres : page 2 **46-50**, page 3 **60**.

⚠️ Et une leçon de méthode, celle qui m'a coûté le plus : **j'avais bissecté
APRÈS avoir retiré le verre.** J'ai donc mesuré des cards sans verre, conclu
qu'il était innocent, et laissé le changement en place. Une mesure faite après
le changement qu'elle est censée juger ne prouve rien.

### Le flottement

Deux sinus désaccordés (rapport 0,63, irrationnel : la trajectoire ne se
referme jamais), amplitude ±4 pt, périodes 5,6 / 6,4 / 6,7 s, **déphasés** —
deux objets côte à côte qui montent ensemble, c'est le plateau qui bouge, pas
les objets.

⚠️ **C'est un `ViewModifier`, et c'est la raison d'être de la forme** :
`body(content:)` reçoit l'arbre DÉJÀ CONSTRUIT, donc la `TimelineView` ne
réévalue que l'`offset` — jamais les cards ni le bijou. Écrit à l'endroit, chaque
card se reconstruirait 30 fois par seconde. Et un `offset` est une TRANSLATION :
les bounds du verre ne bougent pas, le piège du blur plat ne peut pas mordre.
