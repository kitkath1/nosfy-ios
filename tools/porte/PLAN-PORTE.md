# LA PORTE — la lune de sang, le film d'arrivée, et le carrousel de connexion

Plan dicté le 2026-08-22, quatre arbitrages pris le 22-08 (§ 11).
**V1 livrée (J0→J6 ✅) et montrée le soir même sur `kat-entree`.**

## ⚡ LA V2 — le verdict du premier regard (22-08 au soir)

Le verdict a ouvert TROIS plans frères, arbitrés par le verdict lui-même,
**aucun codé** (ils attendent le GO) :

| plan | ce qu'il couvre |
|---|---|
| `PLAN-V2-OUVERTURE.md` | la plongée spectaculaire de la lune (4,45 s), le film rallongé (8,37 s, ralenti ×1,30), et **LE BUG des écrans noirs** (pose noire de ReelPorte + tour de boucle 5,8 s — diagnostic MESURÉ, remède = les deux filets de StoryReel) |
| `PLAN-V2-VIVANT.md` | **les alignements** (textes mesurés à 54-101 pt au lieu de 26 : le bloc était centré — une ligne de remède), la **parallaxe** gyro+doigt de la vidéo (SkyMotion, transforms jamais frames), la **caresse** lumineuse transplantée du login (le shader vit dans AuroraBg.metal, PAS LoginAurora.metal) |
| `PLAN-V2-MANEGE.md` | **le VRAI manège 3D en page 4** (l'arbitrage § 4.1 est INVERSÉ par le verdict) : monté une fois, `paused` au scroll, pan-seulement (le tap-cérémonie est le seul danger et il n'est pas installé), cinématique native `beginPlacing` rejouée à chaque arrivée — 2 flags + 1 méthode d'une ligne dans BoosterLab |

L'ordre de chantier : **OUVERTURE (le bug d'abord) → VIVANT → MANÈGE.**

---

Ce qui suit est la V1 : un jalon = un film de vérification au simulateur + un
verdict au téléphone, dans l'ordre du § 10.

Le brief en une phrase : **on entre par trois états de la lune de sang, un film
d'arrivée se pose sans jamais bouger d'un pixel, et la page s'habille autour de
lui — quatre pages qui changent le grand header vidéo au scroll, une flamme qui
brûle en bas pour toujours, et un seul bouton collé au pied.**

---

## 0. CE QUI EXISTE AUJOURD'HUI, ET CE QU'ON ARCHIVE

L'enchaînement réel (vérifié dans `Woop/WoopApp.swift`) :

```
MoonSplashView (zIndex 10, 13,95 s ou un tap)   ← Woop/Views/MoonSplash.swift
   ↓ showSplash = false
AuroraLoginView sur socle noir (zIndex 8/9)     ← Woop/Views/LoginLab.swift:20
   ↓ tap CONNEXION → startConnexionCinematic() (WoopApp.swift:289), 3,70 s
la home
```

- `MoonSplashView` : une **partition pure fonction du temps** (`MoonSplashBeat.at`),
  7 temps, 13,95 s, un seul shader `logoMonolith` (20 arguments) nourri par la LUT
  `MoonSDF.bin`. **L'éclipse et la renaissance rouge → or existent déjà** : la lune
  de sang n'est pas à inventer, elle est à re-timer.
- `AuroraLoginView` : fond shader `bgAuroraLogin` + caresse au doigt + le monolithe
  posé (`CineMonolith`) + titre Inter 34 + `DiamondInputField` + `DiamondConnexionButton`.
- `AuthView` (nébuleuse + diablotins) est **déjà** en archive derrière `-authNebula`.

**L'archive ne coûte rien : elle existe déjà.** `-moonSplashLab` rejoue la
cinématique de 13,95 s, `-loginLab` ouvre `AuroraLoginView` nue, `-authNebula`
l'écran nébuleuse, `-splashTest` la bouteille et le diablotin. On ne supprime
aucun fichier — on débranche seulement `WoopApp.swift:871` et `:908`.

Ce qui n'existe nulle part : **aucun onboarding, aucun carrousel, aucune clé de
premier lancement.** `showAuth` repart vrai à chaque lancement (`WoopApp.swift:218`)
et la seule clé « déjà vu » du dépôt est `tutoExosVu`.

---

## 1. LA DOCTRINE — cinq lois, elles tranchent tous les micro-débats

**LOI 1 — LA VIDÉO NE BOUGE JAMAIS.** Le film d'arrivée est cadré, dès sa
première image, **exactement** dans le rectangle du header (402 × 612). Il ne
grandit pas, ne rétrécit pas, ne se recadre pas. Ce qui « se pose », c'est la
PAGE : la flamme s'allume, le texte monte, les dots naissent, le bouton arrive.
C'est ce que montre ta maquette « arrivée » — le cadrage y est déjà celui de la
page 1, seul l'habillage manque. Corollaire technique : zéro `scaleEffect` et
zéro frame animée au-dessus d'un `AVPlayerLayer`, donc zéro relayout par image,
donc zéro saccade (le « ça laggue quand on drag la card », `DepartCine.swift:220-226`).

**LOI 2 — LE ZOOM EST CUIT, PAS CALCULÉ.** Le mouvement de caméra « premium »
vit dans le fichier (`zoompan` au recuit), jamais dans SwiftUI. Un
`scaleEffect` posé après un masque compose dans un tampon non zoomé puis
l'agrandit : zoom rastérisé, donc flou (loi écrite `StoryVideo.swift:36-54`).
Cuit, il est net, gratuit, et identique sur tous les appareils.

**LOI 3 — LE FEU EST EN BAS, ET IL Y RESTE.** Une seule source de chaleur par
écran : la flamme du pied. Le header est du **verre sur du noir** — de l'or, pas
du feu. Si les deux brûlent, il ne reste qu'une page orange (loi héritée de la
home v2, § 1 de `tools/home-v2/PLAN-HOME-V2.md`).

**LOI 4 — DEUX LECTEURS VIDÉO AU MAXIMUM, JAMAIS TROIS.** La flamme (1) plus le
header (1), plus un second header **pendant le seul glissement du doigt**. Le
recyclage pair/impair du § 4.3 garantit cette borne par construction. Le maximum
mesuré ailleurs dans l'app est 3 (BRAVO en cérémonie) — on reste dessous, sur
un écran qui empile déjà de l'audio, de l'haptique et un shader.

**LOI 5 — LE BOUTON EST COLLÉ, ET IL EST SEUL.** Un seul appel à l'action,
toujours au même pixel, sur les quatre pages. Pas de « Passer », pas de lien
secondaire encadré (« sur la nuit, un cadre clair se lit comme un bug » —
`StopSessionSheet.swift:85`). Le carrousel est une lecture, pas un questionnaire.

---

## 2. L'ANATOMIE, DE HAUT EN BAS (chiffres pour un écran de 402 × 874)

| bande | de | à | ce qu'il y a |
|---|---|---|---|
| **header vidéo** | 0 | **612** | la vidéo, plein bord, sous l'encoche |
| fondu de pied | 572 | 612 | 40 pt de dégradé vers le noir (`StoryFootFade`) |
| kicker (page 1) | 496 | 510 | `WELCOME`, inter 11 medium, tracking 3,2, blanc 0,42 |
| **le texte** | ~520 | **586** | 2 lignes, inter 26, `WoopGradient.titleFade` |
| **les dots** | 630 | 636 | 4 pastilles, alignées à gauche |
| la flamme | 510 | 874+ | `home-fond-flamme`, 402 × 427,3, poussée vers le bas |
| **le bouton** | 760 | 818 | `DiamondPrimaryButton`, h 58 |
| encart bas | 840 | 874 | lu dans `\.encartBas`, **jamais écrit en dur** |

- **Header = 0,70 × hauteur** → 611,8, arrondi à 612. C'est la cote de tes
  maquettes : mesurées, la vidéo y meurt à 70 %, 70 % et 72 % de la hauteur du cadre.
- **Marge latérale 26 pt partout** (texte, dots, bouton) — le patron maison de
  l'écran de connexion (`LoginLab.swift:165`).
- **Le texte est ancré au BAS du header**, pas au haut de la page : une 3ᵉ ligne
  (page 3) pousse vers le haut, jamais vers le bas, et les dots ne bougent pas d'un pixel.
- **Les dots** : active = capsule 22 × 6, r 3, blanc 0,92 ; inactive = 10 × 6, blanc 0,22 ;
  espacement 6. **Quatre**, pas trois — tes maquettes en montrent trois parce que
  la page booster n'était pas encore dessinée.
- **La flamme** garde son ratio natif (604/642 = 0,940810 → **402,010 × 427,322**, les
  cotes exactes de `braL`/`braH`) et son arête basse clouée au bord physique,
  **puis descend de `flammeBas` pt**. Départ à **+56**, curseur de banc de 0 à 96.
  C'est ça, « plus basse » : là où elle vit aujourd'hui (la home v2), elle est
  **collée au bord, sans offset, sans blend, sans masque, opacité 1** — donc la
  seule façon de la faire descendre est d'en sortir une partie de l'écran.
  ⚠️ Précision qui compte : cette flamme est aujourd'hui du **code de banc**.
  `FondDeuxCalques` n'est atteignable que par `-homeV2` (& co), `-menuLab` (& co)
  et `-harmonie` ; la home de **production** reste `HomeAuroraView`, qui n'a pas de
  flamme. On reprend donc le pied de la home **v2**, celle en chantier.
- **Le bouton** : `.padding(.horizontal, 26)` + `.padding(.bottom, 22)` + l'encart.
  ⚠️ Son écrin shader déborde de **34 pt de chaque côté** (halos, poussières) : le
  pied ne doit porter **aucun** `clipped()`.

---

## 3. LE FILM D'ENTRÉE

### 3.1 Les trois états de la lune de sang — `LuneDeSangView`

**La bonne nouvelle : les trois états existent déjà dans le shader.** Tout passe
par un seul curseur, `blood = smoothstep(0.25, 0.80, night.y)`
(`LogoMonolith.metal:316`), poussé depuis Swift. Il pilote le tube (or → ambre →
cuivre → sang), le fil de plasma (blanc chaud → rouge), le halo (**rayon 150 → 96 pt,
il se CONTRACTE**, ivoire → orange → rouge sombre), le verre dépoli, les anneaux,
la vignette. Il n'y a **aucune** constante `Color` de la lune côté Swift : on ne
peint pas, on pousse un uniform.

Tes trois écrans, traduits :

| | état | `night` visé | ce qu'on voit |
|---|---|---|---|
| ① | halo large diffus | (1 ; 0 ; 0 ; **0**) | halo ivoire r 150, tube or, étoiles |
| ② | halo orange serré | (1 ; 0 ; 0 ; **0,52**) | halo contracté r 123, orange (0,90 0,44 0,14), bandes ambre |
| ③ | lune de sang éteinte | (1 ; 0 ; 0,40 ; **1,00**) | halo r 96 à −35 %, tube (0,58 0,10 0,035), fil rouge, braise du contour |

**⚠️ LE PIÈGE À PAYER D'ABORD — `night.y` fait DEUX métiers.** Le même canal
porte la teinte de sang (l. 316) **et** la couverture nuageuse
(`V = smoothstep(0, 0.42, dens + night.y*2.7 - 2.25)`, l. 1435). À `night.y ≥ 0,80`,
c'est-à-dire dès que la lune devient rouge, **les nuages avalent l'écran**. Ta
maquette ③ montre une lune de sang **nette, sans voile** : en l'état, elle n'est
pas exprimable.

Le remède recommandé : **passer `night` de `float3` à `float4`** — (atmosphère,
voile, braise, **sang**) — et lire `blood` sur `night.w`. Un seul uniform change de
type, trois points d'appel bougent dans le même commit :
`LogoMonolith.metal:263` + `316`, `LogoLab.swift:191/295`, `MoonSDF.probe`
(`MoonSDF.swift:74-82`). **⚠️ ARITÉ DU STITCHABLE** : en oublier un rend la page
**BLANCHE, sans une seule erreur de compilation** (piège déjà payé).

**La partition** (fonction pure du temps, comme l'actuelle — c'est la condition
pour la régler par captures) :

```
0,00 → 0,55   PROLOGUE   la lune au loin, reveal 0 → 0,38     (repris tel quel)
0,55 → 1,20   LA POSE    caméra au centre, zoom 1,0, reveal → 1
1,20 → 2,10   ÉTAT ①     tenu 0,90 s, idleLife allumé
2,10 → 2,45   fondu      night.w 0 → 0,52
2,45 → 3,25   ÉTAT ②     tenu 0,80 s
3,25 → 3,60   fondu      night.w → 1,00 ; night.z (braise) → 0,40
3,60 → 4,40   ÉTAT ③     tenu 0,80 s
4,40 → 5,00   EXTINCTION reveal → 0, tout meurt au noir
                                                       TOTAL 5,00 s
```

Haptique : trois battements, un par état, envoyés **d'un bloc** au moteur
(`RocketHaptics.shared.launch`) — jamais image par image. Bancs :
`-luneSangLab` (boucle + bouton Rejouer) et `-luneSangFreeze <t>` (fige la
partition **et** l'horloge du shader), sur le patron exact de `-moonSplashLab`.
⚠️ Comme `-moonSplashFreeze`, le drapeau `-freeze` coupe le `.task` **avant** le
minuteur de fin : `finish()` n'est alors plus appelé que par un tap. C'est voulu,
mais ça bloque tout le parcours d'entrée — à ne pas confondre avec un bug.

ℹ️ Ce que `MoonSDF.warmUp()` paie n'est **pas** la cuisson de la LUT : dans le
chemin normal, `MoonSDF.bin` est **lu** du bundle en deux millisecondes. Ce qui
est chauffé, c'est la **pré-compilation du shader**. La porte doit malgré tout
garder l'attente `while !MoonSDF.isReady` avant de poser son horloge — sinon le
début du plan saute.

### 3.2 L'arrivée — le film qui se pose

La dernière image de `splash_1.mp4` **est** ta maquette « arrivée » : le pavé de
verre à la lune, le pavé haltère à sa droite. Vérifié image par image.

- La lune de sang meurt **au noir** (5,00 s) ; `splash_1` **commence au noir**
  (mesuré : les 1,2 premières secondes sont vides). **La couture est
  noir-sur-noir, donc introuvable.** On coupe les 1,2 s mortes au recuit.
- Le film joue **dans son cadre de header définitif**, une fois (LOI 1).
- À **fin − 1,2 s** : la flamme du pied s'allume en fondu (0,8 s).
- À **fin** : le texte, les dots et le bouton montent en cascade — le
  `reveal(shown:delay:)` maison (ressort 0,65/0,85, +26 pt, retards 0 / 0,12 / 0,24,
  `AuthView.swift:160`).
- Puis **le relais** : le master passe la main à `onb-lune-loop.mp4` sur son
  image de raccord. C'est le mécanisme de `StoryReel` (`StoryVideo.swift:41`),
  déjà éprouvé : **échange sec, jamais un fondu** (un fondu croisé de 0,30 s EST
  le flash noir — la couche entrante n'a pas encore produit d'image), boucle
  amorcée et prérollée avant le relais, master démonté 0,6 s après.

### 3.3 Le compte total, et le tap — **TRANCHÉ**

**Version courte, au premier lancement seulement.**

| | ~~version longue~~ | **la version retenue** |
|---|---|---|
| lune de sang | ~~5,00 s~~ | **3,40 s** — 0,55 s par palier, fondus de 0,25 |
| arrivée | ~~6,80 s~~ | **5,00 s** — on entre après le noir ET après le premier tiers |
| **total** | ~~11,80 s~~ | **8,40 s** |

Aujourd'hui l'entrée coûte **13,95 s à chaque ouverture**. On passe à 8,40 s, et
**une seule fois** (§ 8, `woop.porteVue`). Aux ouvertures suivantes, le carrousel
s'ouvre directement en page 1, sur sa boucle.

La partition de 5,00 s du § 3.1 se resserre donc ainsi (mêmes états, mêmes
valeurs de `night`, seuls les temps changent) :

```
0,00 → 0,40   PROLOGUE + POSE   la lune arrive, reveal → 1
0,40 → 0,95   ÉTAT ①            halo ivoire large, tenu 0,55 s
0,95 → 1,20   fondu             night.w 0 → 0,52
1,20 → 1,75   ÉTAT ②            halo orange serré, tenu 0,55 s
1,75 → 2,00   fondu             night.w → 1,00 ; night.z (braise) → 0,40
2,00 → 2,55   ÉTAT ③            lune de sang, tenu 0,55 s
2,55 → 3,40   EXTINCTION        reveal → 0, tout meurt au noir
                                                       TOTAL 3,40 s
```
⚠️ **0,55 s par palier est un plancher, pas un confort.** En dessous, l'œil ne
lit plus trois états mais un dégradé continu. Si le verdict téléphone dit que ça
défile, c'est l'extinction (0,85 s) qu'on raccourcit, jamais les paliers.

**Un tap termine à tout instant** (c'est déjà la loi du splash actuel,
`MoonSplash.swift:826`) et cette porte-là doit la garder. Le `finish()` protégé
par un booléen fait foi — **jamais** la durée nominale.

---

## 4. LE CARROUSEL — quatre pages

### 4.1 Le contenu

| # | header | kicker | texte (anglais, 2 lignes) |
|---|---|---|---|
| 1 | `onb-lune-loop` (les pavés de verre, la lune) | `WELCOME` | **Welcome to Woop.**<br>**Your training, remembered.** |
| 2 | `onb-exos-loop` (flamme / haltère / coureur) | — | **Pick your exercises,**<br>**log every set as you go.** |
| 3 | `onb-track-loop` (kettlebell dans la nuit) | — | **Track your performance**<br>**and become your best version.** |
| 4 | `booster-loop` **en petit, centré** | — | **Finish a session,**<br>**open a booster.** |

Variantes si celles-là ne sonnent pas : ① « Welcome to Woop. / Everything you
lift, remembered. » — ② « Choose your exercises, / track every single set. » —
③ « See your progress / and become your best version. » — ④ « Every session earns
you / a booster to open. »

**La page 4 n'a pas de vidéo plein cadre, et c'est voulu.** Tu as dit « en
petit ». Le vrai manège 3D coûte **~416 000 triangles par image** (20 copies du
sachet, doublées par la réflexion du sol), plus HDR, bloom, particules,
gyroscope, moteur haptique et nappe audio ; il installe trois recognizers en dur
(un tap = toute la cérémonie) ; et en mode galerie il publie
`SacreEtat.shared.manegePose = true`, **qui éclipse la home à la racine** —
un effet de bord global, à ne surtout pas embarquer dans une porte d'entrée.
En face, `booster-loop.mp4` (1160 × 800, ping-pong 17,7 s, déjà dans le bundle) est
mesuré à « zéro image de coût ». **On pose le trio de sachets dans un cadre de
300 × 207 centré dans le header**, en `.blendMode(.plusLighter)` sur noir, avec la
poudre `PoudreBooster` par-dessus. ⚠️ Le blend additif **exige** du noir sous lui.

### 4.2 La pagination

Le dépôt n'a **aucun** `TabView(.page)` — `tabViewStyle` n'existe nulle part. Le
patron maison est celui de `CoffreFortFlow` (`CoffreFortView.swift:571-588`),
qu'on couche à l'horizontale :

```
ScrollView(.horizontal) {
    LazyHStack(spacing: 0) { … 4 blocs de TEXTE … }
        .scrollTargetLayout()
}
.scrollTargetBehavior(.paging)
.scrollIndicators(.hidden)
```
chaque bloc en `.containerRelativeFrame(.horizontal)`.

**Seuls les textes défilent.** Le header, les dots, la flamme et le bouton vivent
**hors** du scroll.

Le couplage se fait par **UNE seule sonde composée** :

```
private struct SondeOnb: Equatable { var x: CGFloat; var largeur: CGFloat }
```
⚠️ **PIÈGE DE LA SONDE CONSTANTE** : un `onScrollGeometryChange` dont la closure
renvoie une valeur qui ne change pas n'est **plus jamais rappelé**, et deux
sondes sur le même ScrollView se volent les rappels. Une sonde, un type
`Equatable` composé, **le champ vivant emporte les stables** (loi payée cinq fois :
`ExercisesView.swift:193`, `CalLab.swift:4243`, `HomeNuit.swift:1631`, `ProfilLune.swift:25`,
`FlammeJauge.swift:419`).

Elle écrit `p ∈ [0 ; 3]` dans un **`@Observable final class EtatPorte`** — jamais
un `@State` sur la page. ⚠️ **PIÈGE DE LA PAGE RÉ-ÉVALUÉE PAR IMAGE** : un état
écrit 60 fois par seconde sur la vue qui contient tout, c'est exactement « ça
saccade, ça colle au doigt ». Le corps de la page **n'en lit rien** ; seuls
`PorteHeader` et `PorteDots` le lisent, et les dots sont une `View, Animatable`
sur `p`.

⚠️ Ne **jamais** tenir un `scrollPosition` dans la page : c'est un binding à
double sens, SwiftUI y écrit au poser **et** au lâcher du doigt — la page
s'invalide à l'instant exact où le scroll démarre, le pire moment
(`ExercisesView.swift:179-188`).

### 4.3 Le croisé des vidéos — la règle pair / impair

Avec `i = floor(p)` et `f = p − i`, les deux pages visibles sont toujours
`(i, i+1)`, donc toujours **une paire et une impaire**. D'où la règle :

> **Le créneau A porte les pages PAIRES, le créneau B les IMPAIRES.**

Conséquence, et c'est tout l'intérêt : **le créneau dont le fichier change est
toujours celui qui est à opacité 0.** Aucun remontage n'est jamais visible.
Opacités : A = `i` pair ? `1−f` : `f`, et l'inverse pour B. Au repos, `f = 0` :
**un seul lecteur tourne**, plus la flamme. Deux au maximum, pendant le seul
glissement.

⚠️ Un `UIViewRepresentable` **ne reconstruit pas** sa `UIView` quand un paramètre
change : `makeUIView` ne tourne qu'une fois. Le changement de fichier passe donc
par un `.id(fichier)` sur le créneau (ou par le chemin de `DemonVideo.swift:41`,
qui remonte son player sur changement d'offre). C'est justement parce que ce
remontage est invisible à opacité 0 que la règle pair/impair vaut.

### 4.4 Le composant de header

On part de `CalqueVideo(nom:pose:rate:)` (`DepartCine.swift:255`) — le seul lecteur
maison avec **image de pose intégrée**, effacée sur `isReadyForDisplay`, et
reprise après retour d'arrière-plan. On lui ajoute les deux lignes qui lui
manquent :

```swift
v.clipsToBounds = true
v.playerLayer.masksToBounds = true          // ExosFond.swift:55-56
```
⚠️ **PIÈGE DU DÉBORDEMENT** : un `AVPlayerLayer` en `resizeAspectFill` sort de ses
bornes et **le `clipShape` de SwiftUI ne rattrape pas une couche UIKit** (mesuré :
2,3 pt au lieu de 10 sur la card exos). `CalqueVideo` n'a pas ces deux lignes ;
il n'est sauvé aujourd'hui que parce que le ratio du cadre de la flamme est
**exactement** celui du fichier. Dès qu'on change une cote, ça déborde en silence.

Autres lois du gabarit, à ne pas perdre en recopiant :
`AVPlayerLooper` **retenu par le Coordinator** (relâché, la boucle s'arrête au
premier tour) ; `backgroundColor = .clear`, **jamais noir** (le looper vide la
couche 1 à 3 images à chaque tour) ; `preroll` **attaché à une KVO sur `.status`**
— appelé avant `readyToPlay` il **lève une exception et tue l'app au lancement**
(payé le 21-08, et on est précisément sur l'écran de lancement) ;
`isMuted = true` obligatoire ; `dismantleUIView` qui coupe tout.

---

## 5. LES MÉDIAS — le recuit

**Aucune ligne de `project.pbxproj` à toucher.** Le projet est en groupes
synchronisés Xcode 16 (`objectVersion = 70`, `PBXFileSystemSynchronizedRootGroup`
sur `Woop/`, `PBXResourcesBuildPhase` **et** `PBXSourcesBuildPhase` **vides** —
les chaînes « Media » et « mp4 » n'existent nulle part dans les 441 lignes du
fichier) : déposer un `.mp4` dans `Woop/Media/` suffit. **Vérifié de bout en
bout sur le bundle réellement construit** : 21 `.mp4` dans `Woop/Media/`, 21 `.mp4`
**à la racine** de `Woop.app`, aucun sous-dossier `Media/`.

⚠️ Les sous-dossiers sont **aplatis** au bundle : un nom de fichier doit être
unique dans **tout** `Woop/`, pas seulement dans son dossier (aucun doublon
aujourd'hui — à préserver en nommant les nouveaux fichiers), et l'accès se fait
toujours par `Bundle.main.url(forResource:withExtension:)` **sans** `subdirectory:`.

⚠️ **AJOUTER est gratuit et instantané ; RETIRER exige un build propre.** Un build
incrémental **ne purge pas** les ressources supprimées — le bundle courant traîne
encore quatre fichiers qui n'existent plus dans l'arbre source. Corollaire : ne
jamais chiffrer le poids de l'app depuis un `dd-*/`, il surestime.

💡 **De la place gratuite avant d'ajouter un header** : `home-fond-loop.mp4`
(**14,4 Mo**, sa struct `HomeFondVideo` n'est jamais instanciée), `coffre-salut.mp4`
(zéro référence) et l'imageset `home-fond-poster` (plus aucune référence Swift).
De quoi absorber presque entièrement les quatre nouvelles vidéos — après un clean.

### 5.1 Les sources, mesurées

| fichier | définition | durée | poids | verdict |
|---|---|---|---|---|
| `splash_1.mp4` | 2160 × 3840 **HEVC 10 bits** | 8,04 s | 5,2 Mo | ✅ le film d'arrivée |
| `splash_2.mp4` | 2160 × 3836 h264 | 6,04 s | 4,7 Mo | ✅ page 2 |
| `splash_3.mp4` | 1956 × 4240 h264 | 5,04 s | 1,8 Mo | ⚠️ voir ci-dessous |
| `home-fond-flamme.mp4` | 604 × 642, **déjà dans le bundle** | 35,8 s | 0,6 Mo | ✅ la flamme du pied |
| `booster-loop.mp4` | 1160 × 800, **déjà dans le bundle** | 17,7 s | 1,8 Mo | ✅ page 4 |

⚠️ **`splash_1` est en HEVC 10 bits** (`yuv420p10le`) : tout le reste du projet est
en `yuv420p` 8 bits. À convertir, pas à embarquer tel quel.

⚠️ **`splash_3` est presque vide, et c'est mesuré.** Luminance moyenne 16,6/255 ;
découpée en trois bandes sur sa dernière image : haut **moyenne 1,4 / p99 30**,
milieu **0,2 / p99 5**, bas **0,0 / max 2** — le tiers bas est **littéralement
noir**. Toute la matière (un kettlebell, un disque, un haltère dans l'ombre) tient
dans le tiers haut.

**TRANCHÉ : on recadre sur le tiers haut ET on relève la matière au recuit.**

⚠️ **LOI ANTI-BRUN, et elle est éliminatoire ici.** On ne monte **pas** le gamma à
l'aveugle : sur une matière déjà orange sombre, un `gamma` global remonte le vert
plus vite que le rouge en valeur relative, la saturation tombe, et **une
saturation qui baisse, c'est du brun** (la leçon payée deux fois sur
l'harmonisation rouge de la page exo). La méthode :

1. mesurer le **ratio de canaux** du kettlebell allumé sur la source, comme on
   l'a fait pour le lit de braise (`Feu.lit = 1,000 / 0,272 / 0,015`) ;
2. relever avec un `curves` qui **tient ce ratio** — on tire vers la couleur
   mesurée, on ne l'**ajoute** pas (la règle du `mix`, déjà écrite) ;
3. re-mesurer après encodage ;
4. verdict au téléphone. **Si ça ne prend pas**, le repli est de changer de source
   (`flamme_2.mp4`, `pills_glass.mp4`, `forme_glass_red_2.mp4`) — planche de
   contact avant de trancher, jamais à l'œil sur un écran de Mac.

**FAIT AU JALON 0 — et une correction de méthode.**

La courbe retenue a été choisie **par le vert, pas par la luminosité**. Trois
crans, mesurés sur trois images chacun :

| cran | p99 tiers haut | **g/r** | verdict |
|---|---|---|---|
| doux | 80 – 93 | 0,547 – 0,568 | sous la cible |
| **retenu** | **89 – 103** | **0,519 – 0,538** | plus clair **et** plus saturé |
| fort | 98 – 114 | 0,552 – **0,574** | le vert **repart** → virage au brun |

Le cran fort est plus lumineux et pourtant moins bon : c'est exactement le piège
que la loi décrit. **On s'arrête au cran où `g/r` est au minimum.**

⚠️ **LA CIBLE « p99 ≥ 90 SUR LE TIERS HAUT » ÉTAIT UNE MAUVAISE MÉTRIQUE, et je
l'avais écrite dans ce plan.** Le tiers haut est à **91,6 % de vide** : son p99
mesure donc surtout du noir, et il oscille avec le pouls de la source. Sur le
fichier livré il va de **82 à 102** selon l'image — 3 relevés sur 7 restent
2 à 8 points sous 90. **La bonne métrique est le p99 des pixels ALLUMÉS** (L ≥ 4),
qui ne mesure que la matière :

| | source | **livré** | |
|---|---|---|---|
| p99 matière, 4 instants | 138 – 182 | **180 – 214** | **×1,18 à ×1,31, uniforme** |
| moyenne du cadre entier | 1,1 | **2,2 – 2,7** | budget ≤ 40 : large |
| ratio matière R/G/B | 1,000 / 0,684 / 0,429 | **1,000 / 0,44-0,52 / 0,16-0,21** | la saturation **monte** |

Donc : le relèvement est réel, uniforme et anti-brun ; l'ancienne cible n'est pas
tenue partout, et **pousser plus fort violerait la loi qui compte davantage**.
Le vrai verdict reste le téléphone.

### 5.2 Le cadrage — un seul canevas

Header = 402 × 612 pt → ratio **0,6569**. Au facteur maison, le canevas est
**1080 × 1644** (1080/1644 = 0,6569 = 402/612, au pixel). Ratio exact = **rien
n'est rogné par `resizeAspectFill`** — la même loi qui sauve la flamme aujourd'hui.

Fenêtres de recadrage vérifiées à la planche de contact :

- `splash_1` : `crop=2160:3288:0:276` — la lune est bien posée, l'haltère tient
  dans le cadre. (`y=0` marche aussi ; `y=552` coupe trop.)
- `splash_2` : `crop=2160:3288:0:274` — les trois pavés (flamme, haltère,
  coureur) tiennent tous. (`y=548` mange le coureur.)
- `splash_3` : `crop=1956:2977:0:0` — le tiers haut, plus le relèvement du § 5.1.

### 5.3 La recette

Le script `tools/porte/recuit_porte.sh`, sur le patron exact de
`tools/home-v2/recuit_calques.sh` :

```
crop → scale=1080:1644 → [zoompan très lent, cuit] → ping-pong (reverse + concat)
     → setpts → minterpolate=fps=30 → libx264 -preset slow -crf 20
     → -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 -movflags +faststart -an
```
puis l'image de pose (`select=eq(n\,0)`, `-q:v 3`) dans
`Woop/Assets.xcassets/<nom>-poster.imageset`, `Contents.json` écrit par le script.

⚠️ **30 img/s en sortie, et c'est une loi, pas un goût.** Les sources sont à 24 ;
à 60 Hz, du 24 bat en 3:2 — une image sur deux tient deux fois plus longtemps que
sa voisine, **et sur un mouvement de caméra lent ce battement se voit**
(`StoryVideo.swift:10-16`, qui contourne le problème en jouant à 1,25). En sortant
à 30, chaque player tourne à `rate = 1,0` (le défaut) et le problème n'existe
pas. ⚠️ `play()` vaut littéralement `rate = 1.0` : tout débit se pose **après**.

Le raccord master → boucle (page 1) : **la boucle se coupe dans la queue du
master**, à partir de l'image de raccord exacte, et sa première image est
**bit pour bit** l'image `handoffFrame` du master — c'est ce qui rend l'échange
invisible par construction (le modèle `story_1` / `story_1_loop`).

Fichiers produits (nommage maison : minuscules à tirets, suffixe `-loop`) :
`onb-arrivee.mp4`, `onb-lune-loop.mp4`, `onb-exos-loop.mp4`, `onb-track-loop.mp4`,
plus les quatre `-poster`.

### 5.4 Le budget de décodage — chiffré avant d'encoder

| | définition | Mpix/s |
|---|---|---|
| header à **1080 × 1644 @ 30** | la cote du § 5.2 | **53,3** |
| flamme (`home-fond-flamme`, 604 × 642 @ 24) | déjà là | 9,3 |
| **au repos (header + flamme)** | | **62,6** |
| **pointe pendant un glissement** (2 headers) | | **115,9** |

Repères mesurés du dépôt : le fond plein écran de la home v1 (`home-fond-loop`,
1620 × 3522 @ 24) coûtait **136,9** Mpix/s et a été jugé trop cher ; les deux calques
rognés qui l'ont remplacé coûtent **37,2** à eux deux (et non les « 27 » du
commentaire — le fichier pilule est encodé 11,7 % plus grand que sa cote déclarée).

**On reste donc sous le pire régime déjà expédié, même en pointe.** Si la
`SondeCadence` pince au jalon 1, les deux crans de repli, dans l'ordre :
sortir à **24 img/s** (42,6 au lieu de 53,3 — mais on retrouve le battement 3:2,
donc il faut alors jouer à `rate = 1,25`), puis descendre le canevas à **972 × 1480**
(43,2 @ 30).

---

## 6. LE BOUTON — « SE CONNECTER » et la pomme

LE bouton primaire du système est **`DiamondPrimaryButton`**
(`ConnexionButtonLab.swift:152`, alias `DiamondConnexionButton`), 58 pt de haut,
rendu 100 % shader Metal. `NeonPrimaryButton` est un prototype concurrent **mort à
l'usage** — ne pas le réanimer sans décision explicite.

Aujourd'hui il ne prend **que** `title: String`. L'extension minimale :

```swift
var glyph: String? = nil        // "apple.logo"
```
posé en `.overlay(alignment: .leading)`, **dans la gouttière déjà réservée**. Le
composant réserve en effet `.padding(.horizontal, 38)` **des deux côtés**, pour
que la flèche `arrow.right` ne mange pas le texte : la gouttière gauche est donc
libre et symétrique. Quand `glyph != nil`, **la flèche disparaît** (un logo à
gauche + une flèche à droite, c'est deux signaux pour une action).

⚠️ Le titre est **majusculisé de force** avec `tracking 4.6` : « Se connecter »
s'affichera **SE CONNECTER**, ce qui est le registre gravé de la maison. Douze
signes : très en dessous de la limite de ~30 où `minimumScaleFactor(0.72)`
commence à rétrécir.

⚠️ Il n'existe **aucun** état `disabled` ni `loading` dans la famille diamant.
`.disabled()` bloquera le tap mais **rien ne changera à l'écran**. Si la connexion
Apple doit montrer une attente, c'est à écrire.

⚠️ Le composant fait tourner une `TimelineView` à 30 Hz **en permanence**, même au
repos. Sur cette page il s'ajoute au header vidéo + la flamme : à mesurer à la
`SondeCadence` au jalon 1, et à passer à deux régimes si ça pince (la leçon
écrite de `NeonPrimaryButton.swift:96-105` : payer 60 fps pendant le transitoire,
20 au repos).

**Le branchement Apple, plus tard, mais à savoir dès maintenant** : le dépôt n'a
**aucune** trace de `AuthenticationServices`, **aucun fichier `.entitlements`**, et
l'`Info.plist` est généré (`INFOPLIST_KEY_*`). Sign in with Apple demande une
capability, donc — contrairement aux médias — **un vrai passage par Xcode et le
pbxproj**. Et l'auth réelle d'aujourd'hui est un numéro mappé en dur sur deux
comptes Supabase (`Services/Supabase.swift:26-35`), avec `woop.phone` comme clé de
session : **sans champ téléphone, plus personne n'écrit `woop.phone`**, donc la
session en place survit — mais le jour où l'identité vient d'Apple, cette clé
change de nature. À trancher au moment du branchement, pas avant.

---

## 7. LA SORTIE — ce qui casse, et ce qu'on met à la place

La cérémonie actuelle (`ConnexionCine`, 3,70 s) plonge **la caméra du monolithe
posé** (`CineMonolith`) pendant que le nuage de braises (`MoonDustOverlay`,
zIndex 20) couvre la coupe à 2,10 s. **La nouvelle porte n'a pas de monolithe** :
son header est une vidéo. La cérémonie perd son sujet.

**TRANCHÉ : LA FLAMME EMBRASE.** Au tap, trois choses partent ensemble, calées sur
l'horloge existante :

```
0,00   le doigt tombe. DiveRumble part (inchangé).
0,00 → 1,45   LE HEADER MEURT PAR LE HAUT. Un masque descend du bord haut
              jusqu'à l'arête du header : la vidéo s'éteint dans l'ordre où
              on l'a découverte. ⚠️ Un MASQUE, pas une frame animée.
0,00 → 1,95   LE FOYER ENFLE. La flamme du pied ne monte PAS : c'est la ZONE
              qu'elle éclaire qui grandit (un feu qui prend éclaire plus haut,
              il ne se déplace pas — la loi écrite du fond de la home).
              Le foyer est le RadialGradient en .plusLighter à la couleur
              MESURÉE du lit — Feu.lit = 1,000 / 0,272 / 0,015. Ajouter du lit
              à du lit ne change ni teinte ni saturation : ANTI-BRUN PAR
              CONSTRUCTION, pas par précaution.
1,45 → 2,10   le texte, les dots et le bouton s'en vont (le reveal à l'envers).
2,10          LA COUPE, sous le nuage de braises. Inchangée.
```

Le feu de la porte devient le feu de la home : le raccord raconte quelque chose.
`CineMonolith` sort de la page (la porte n'a plus de monolithe à plonger) mais
**reste dans le fichier**, vivant pour `-loginLab`.

⚠️ Le masque du header et le foyer sont deux rampes sur la **même** horloge
`cineStart`, lues en fonction pure du temps — **jamais** deux `withAnimation` sur
la même valeur dans le même tour (ça ne joue rien), et **jamais** une rampe
échelonnée sous `withAnimation` (elle ne jouerait qu'au doigt). Si un
aller-retour devient nécessaire, c'est un `keyframeAnimator`.

**On ne touche pas aux minuteries** : les quatre
`DispatchQueue` de la racine restent calées sur `ConnexionCine` (coupe 2,10 /
barre 2,55 / souffle 3,10 / **fin 3,90** — la dernière tombe à `end + 0,2`),
sinon c'est l'arrivée de la home qu'on casse. ⚠️ La bascule se fait dans **une seule transaction sans animation**
(`WoopApp.swift:306-311`) : `HomeWelcome.start`, `showAuth = false`, `homeArriving`,
`barArriving`. Rien à insérer là-dedans.

---

## 8. LE BRANCHEMENT À LA RACINE — deux lignes, et pas une de plus

La porte se moule **exactement** sur les deux drapeaux existants :

| drapeau | avant | après |
|---|---|---|
| `showSplash` | `MoonSplashView(landsOnAurora: false)` (l. 908) | **`LuneDeSangView`** |
| `showAuth` | `AuroraLoginView(onConnect:cineStart:)` (l. 871) | **`PorteEntree(onConnect:cineStart:)`** |

Même contrat (`onConnect: (String) -> Void`, `cineStart: Date?`), donc :

- ✅ la garde de **performance** de la ligne 604 (`!showSplash && !showAuth &&
  !homeEclipsee`, qui empêche toute la home de tourner derrière) **ne bouge pas** ;
- ✅ le `.task(id: showSplash || showAuth)` de la ligne 923 et son `guard` de la
  924 **ne bougent pas** — donc les bancs `-clotureTest`, `-departPanneau`,
  `-boosterPopup`, `-boosterManege` continuent de se déclencher au bon moment ;
- ✅ les archives restent atteignables sans un fichier supprimé.

**C'est tout l'intérêt de se mouler sur les deux drapeaux existants** : une
insertion d'un troisième état aurait demandé de retoucher la garde 604, la clé
et le `guard` 923-924 — quatre endroits où un oubli est silencieux.

⚠️ **LE POINT DE CODE QU'IL FAUT QUAND MÊME TOUCHER : `-cineTest`**
(`WoopApp.swift:1087-1104`). Ce banc n'attend **que** le splash
(`while showSplash { sleep 0,2 s }`, l. 1091), puis dort **6 s** et appelle
`startConnexionCinematic()`. Avec un film d'arrivée de 5 à 6,8 s entre les deux,
il déclencherait la cérémonie de sortie **en plein milieu de l'arrivée** et
poserait `showAuth = false` derrière : on sortirait de la porte sur une home déjà
montée. Son attente doit couvrir la porte entière, ou son délai passer après le film.

⚠️ **LE FIL PRINCIPAL N'EST PAS LIBRE PENDANT LES PREMIÈRES SECONDES.** Le `.task`
de `WoopApp.swift:1000` n'est **pas keyé** : il tourne dès le montage de `mainBody`,
quel que soit l'état d'entrée. Il purge les séances fantômes, pousse Supabase, et
**insère un `SCNView` « four » dans la keyWindow à +2,5 s, pour 1,8 s**. C'est
exactement la fenêtre où la lune de sang joue ses trois paliers. À mesurer au
jalon 4, et à décaler si le film hoquette.

Le film d'arrivée appartient à **`PorteEntree`**, pas à la lune : ainsi sa
première image (noire) est déjà montée quand la lune s'éteint, et il n'y a pas un
trou noir de plus entre les deux.

⚠️ `MoonSplashView` **et** `AuroraLoginView` posent chacune `.statusBarHidden()`,
`.persistentSystemOverlays(.hidden)` et `.preferredColorScheme(.dark)`. Les
oublier sur la porte ferait **apparaître et disparaître la barre d'état** au
raccord.

⚠️ `landsOnAurora: false` n'est pas cosmétique : à `true`, la dernière seconde du
splash monte `AuroraLoginBackground` sous le monolithe. La porte n'est pas
l'aurore : ça reste `false`, ou ça disparaît avec la nouvelle partition.

**Le premier lancement — TRANCHÉ.** Rien n'existe aujourd'hui : `showAuth` repart
vrai à chaque fois, et le dépôt n'a **aucune** clé de premier lancement. On en
crée une, `woop.porteVue` :
- **premier lancement** : lune de sang → arrivée → carrousel (8,40 s) ;
- **ensuite** : le carrousel s'ouvre directement en page 1, sur sa boucle, sans
  film. **On économise 8,40 s à chaque ouverture, et 13,95 s par rapport à
  aujourd'hui.**

⚠️ **ET ON COPIE LE REMÈDE DÉJÀ ÉCRIT PAR LA MAISON.** Le seul précédent « déjà
vu » du projet, `tutoExosVu`, n'est **jamais lu en debug** :
```swift
#if DEBUG
let deja = false                                      // ExercisesView.swift:739-743
#else
let deja = UserDefaults.standard.bool(forKey: "tutoExosVu")
#endif
```
Sans ça, la porte ne serait visible **qu'une fois par installation** — donc
intestable. On recopie le motif, plus un banc `-porteNeuve` qui efface la clé.

⚠️ En DEBUG, `DemoData.seedDemoIfNoneFinished` est **appelé** à chaque lancement
(`WoopApp.swift:40`) mais le semis est gardé (`WoopApp.swift:1161-1166`) : il sème
**une** fois, puis plus jamais. Conclusion inchangée — **un « premier lancement »
ne sera jamais vierge en debug** — mais ce n'est pas la clé de la porte qui le
provoque.

**Bancs à ouvrir** : `-porteLab` (la porte nue), `-portePage <n>` (ouvre sur une
page), `-porteFreeze <t>` (fige le film d'entrée), `-porteNeuve` (rejoue le premier
lancement), `-luneSangLab` / `-luneSangFreeze <t>`.

---

## 9. LES PIÈGES DÉJÀ PAYÉS QUI NOUS ATTENDENT ICI

1. **L'arité du stitchable** — `night` en `float4` touche 4 endroits ; en oublier
   un rend la page **blanche**, sans erreur de compilation.
2. **La sonde constante** — une sonde par ScrollView, type composé, le champ
   vivant emporte les stables.
3. **La page ré-évaluée par image** — `@Observable`, jamais `@State` sur la page ;
   les enfants animés en `View, Animatable`.
4. **Le débordement de `resizeAspectFill`** — `clipsToBounds` **et**
   `masksToBounds` ; le `clipShape` SwiftUI ne rattrape pas UIKit.
5. **`preroll` avant `readyToPlay`** — exception, app morte **au lancement**.
6. **Le trou du bouclage** — fond de couche transparent + image de pose, sinon
   flash noir 1 à 3 images à chaque tour.
7. **L'hôte qui gonfle** — `Color.clear` en hôte, le contenu déborde **dedans** ;
   un `ZStack` prend la taille de son plus grand enfant et l'`overlay` le CENTRE
   (payé deux fois : 78 pt de braise sous l'arête, card à 2,3 pt du bord).
8. **La marche des 34 pt** — un `padding` sur une vue en `ignoresSafeArea` coûte
   l'encart bas **d'un coup**, pas en rampe. L'encart se **lit** (`\.encartBas`).
9. **Le double `withAnimation`** — deux `withAnimation` sur la même valeur dans le
   même tour ne jouent **rien** ; un aller-retour se fait en `keyframeAnimator`.
10. **`grep` masque le code de sortie d'`xcodebuild`** — build échoué = « exit 0 »,
    et on capture une app périmée pendant des heures. **Vérifier le `stat` du
    dylib avant toute capture.**
11. **Le simulateur est aveugle** à l'haptique et aux gels Metal : les trois états
    de la lune se jugent **au téléphone**.
12. **Une vue sans taille intrinsèque n'attrape pas les gestes** — si le header
    doit un jour capter un tap, lui forcer son cadre.
13. **Aucun lecteur du dépôt ne se met en pause quand sa page est masquée mais
    reste montée** — et ça fuit déjà en production : `ExosFondVideo` (136,9 Mpix/s)
    n'a aucun `onDisappear` et continue de décoder derrière l'onglet Accueil dès
    que l'onglet Exercices a été visité une fois. La porte ne doit pas ajouter un
    lecteur à cette liste : elle est démontée à la connexion, donc son
    `dismantleUIView` doit vraiment couper (`pause` + `disableLooping` +
    `playerLayer.player = nil`).
14. **Un `UIViewRepresentable` ne reconstruit pas sa `UIView`** quand un paramètre
    change : `makeUIView` ne tourne qu'une fois. C'est ce qui impose la règle
    pair/impair du § 4.3.
15. **`-ss` NE COUPE PAS LE GRAPHE DE FILTRES** — payé au jalon 0. Placé après
    `-i`, c'est une recherche de *sortie* : ffmpeg filtre le clip **depuis le
    début** puis jette les images d'avant le point de coupe. Un `fade=t=in:st=0`
    s'applique donc à des images jetées et **le fondu n'existe pas dans le
    fichier**, sans un mot d'avertissement (mesuré : image 0 à 21,3/255 au lieu
    de 0). Placé avant `-i`, il tombe sur le keyframe le plus proche et la
    fenêtre glisse. **La seule forme juste : `trim` dans le graphe, puis
    `setpts=PTS-STARTPTS`.**

---

## 10. LES JALONS — un jalon, un film, un verdict

| | jalon | ce qui se vérifie |
|---|---|---|
| **J0 ✅** | `recuit_porte.sh` : 4 vidéos + 4 poses | **FAIT le 22-08**, détail ci-dessous. |
| **J1 ✅** | **LA COQUILLE** `-porteLab` : 4 pages, header, dots, flamme, bouton. | **FAIT le 22-08.** Cotes mesurées au numpy sur capture ×3 : vidéo morte à **612,0** (fondu 572 → 612), dots **630,0 → 635,7**, liseré haut du bouton **759,3**, bloc texte 525 → 585. Contraste du texte : pire tiers réel **13,9:1** sur les 4 pages (la « faute » de la page 2 était le pavé de la VIDÉO traversant la bande de mesure) → **pas de scrim**. Cadence sim : **60,0 img/s tenues, pire trou 17 ms** (2 lecteurs + shader du bouton). Bancs : `-porteLab`, `-portePage <n>`, `-porteFlamme <v>`, `-fps`. L'encre du texte a quitté `titleFade` (diagonal, éteignait la fin de ligne — 0,94 → 0,25 mesuré, le verdict déjà payé sur la connexion) pour un fondu vertical 0,96 → 0,80. `CalqueVideo` a reçu son filet `clipsToBounds`+`masksToBounds`. Reste au téléphone : `flammeBas` et le grain. |
| **J2 ✅** | **LE CROISÉ** : règle pair/impair | **FAIT le 22-08.** Banc `-porteAuto` (balayage 0→1→2→3→0 par le VRAI scroll, `scrollTo` animé). Film de 888 frames analysé au numpy : **zéro flash en V** (aucune frame sous 45 % de ses voisines), delta max frame-à-frame **3,0/255**. Cadence pendant les glissements : 58-60 img/s, pire trou 43 ms (l'image du montage du 2ᵉ lecteur — invisible, prouvé par le scan). Créneau démonté sous alpha 0,005 : ≤ 2 lecteurs de header **par construction**, y compris sur le retour 3→0 qui traverse trois pages. |
| **J3 ✅** | **L'ARRIVÉE** : `ReelPorte` (relais d'image) + l'habillage | **FAIT le 22-08.** `ReelPorte` = la mécanique de `StoryReel` en base de temps paramétrée (30, pas le 24 codé en dur) et débit 1,0. Raccord à l'image 60 : deltas mesurés autour du relais **0,35-3,38/255, aucun pic** — la couture est introuvable. Séquence filmée : noir → film → flamme à T−1,2 (0,8 s) → cascade reveal 0/0,12/0,24 à T=4,93 → boucle. Scroll fermé pendant le film (un glissement démonterait le master), tap = saut sec vers l'état final. Banc `-porteArrivee`. Cadence 59-60. **Reste au téléphone** : le tap-saut et l'aller-retour page 1→0 après arrivée (vérifiés par construction, pas au doigt). |
| **J4 ✅** | **LA LUNE DE SANG** : `night` en `float4`, la partition, `-luneSangLab` | **FAIT le 22-08.** Le `float4` a traversé ses 4 points d'un seul commit (Metal + MonolithCanvas/Scene + probe + MoonSplashBeat) — aucune page blanche, l'arité a tenu. L'archive rend au pixel : `b.night.w = b.night.y` au seul point de retour de `at()`. Les 3 états figés (`-luneSangFreeze 0.675/1.475/2.275`) : halo qui se contracte, rougissement mesuré **g/r 0,739 → 0,616 → 0,563**, état ③ **net, sans voile** — le découplage prouvé. `soloNeon: 1` + zoom 1,2 : la lune seule, comme la maquette. Haptique : `RocketHaptics.paliers(times:)`, trois battements d'un bloc. **Verdict téléphone en attente** (le sim est aveugle à l'haptique et aux gels). |
| **J5 ✅** | **LE BOUTON** (glyphe pomme) **+ la sortie** (§ 7) | **FAIT le 22-08.** `DiamondPrimaryButton` gagne `glyph:` — posé dans la gouttière déjà réservée, **la flèche disparaît** quand il est là. La sortie filmée au banc `-porteSortie` (auto à +3 s, l'école de `-clotureTest`) : rideau fini à 1,45, habillage qui s'en va, foyer `Feu.lit` en `.plusLighter` qui enfle sans virer brun. La queue du ressort du bouton (~2,34 s) dépasse la coupe de 2,10 — couverte par le nuage de braises, à juger au téléphone. |
| **J6 ✅** | **LE BRANCHEMENT** + `woop.porteVue` + archives | **FAIT le 22-08.** Racine : `LuneDeSangView` remplace `MoonSplashView` (l. 908), `PorteEntree` remplace `AuroraLoginView` (l. 871), même contrat, garde 604 et `.task` 923 intouchés. `woop.porteVue` écrite à la fin du film (vu OU sauté) ; en DEBUG jamais lue (le remède `tutoExosVu`), `-porteVue` force le raccourci, `-porteNeuve` efface. `-cineTest` passé de 6 à 8 s (l'angle mort de la contre-expertise). **LE FOUR DÉPLACÉ** : à +2,5 s fixes il volait 143-204 ms mesurés en plein palier ② — il attend maintenant la fin du film. Parcours froid filmé : lune ①②③ → couture noire (le stall de mount de ~200 ms y tombe, luminance mesurée 0,0-2,7 : **invisible**) → arrivée → flamme → habillage. Chemin retour (`-porteVue`) vérifié : porte habillée directe. Archives vivantes : `-moonSplashLab`, `-loginLab`, `-authNebula`, `-splashTest`. |

### J0 — LIVRÉ ET MESURÉ (22-08)

`tools/porte/recuit_porte.sh`, quatre fichiers dans `Woop/Media/` et quatre poses
dans `Woop/Assets.xcassets/`. **Aucune ligne de Swift, aucune ligne de pbxproj.**

| fichier | images | durée | poids |
|---|---|---|---|
| `onb-arrivee.mp4` | 148 | 4,93 s | 2,0 Mo |
| `onb-lune-loop.mp4` | 174 | 5,80 s | 836 Ko |
| `onb-exos-loop.mp4` | 356 | 11,87 s | 3,0 Mo |
| `onb-track-loop.mp4` | 296 | 9,87 s | 2,0 Mo |

Les quatre en **1080 × 1644, h264, yuv420p, 30 img/s**, sans piste audio. Aucun
doublon de nom dans tout `Woop/`. **Poids ajouté 7,8 Mo**, contre **15 Mo** de
vidéo morte récupérable (`home-fond-loop.mp4` + `coffre-salut.mp4`) — le chantier
peut se payer lui-même, après un clean build.

**Ce qui est prouvé par la mesure, pas affirmé :**

- **LE RACCORD.** Image 60 du master vs image 0 de la boucle : écart moyen
  **0,421/255**, max 33 — du bruit de compression, rien d'autre. Témoin à six
  images de là : **4,160** et max 254. La mesure discrimine, donc le raccord
  tient : l'échange sec sera invisible.
- **LE FONDU D'ENTRÉE.** Image 0 à **0,00 de moyenne et 0 de maximum** — noir pur,
  au bit. Pleine lumière à l'image 13 (0,43 s). Le raccord avec la lune qui meurt
  est noir-sur-noir.
- **LES COUTURES DE BOUCLE.** Écart dernière/première image non nul sur les trois
  boucles : aucun arrêt sur image au rebouclage (les deux doublons du ping-pong
  sont bien coupés).
- **LA DERNIÈRE IMAGE DU MASTER** est la composition de la maquette « arrivée ».

**Une remarque de mise en scène, découverte à la planche** : le mouvement de
`splash_1` sur cette fenêtre n'est pas une poussée mais une **prise de recul** —
la caméra s'écarte et **découvre** le second pavé. L'arrivée se pose en révélant,
elle ne se pose pas en fonçant. C'est mieux, et c'est gratuit.

⚠️ **Une constante à passer au code au jalon 3** : le raccord est à **l'image 60,
échelle de temps 30**. `StoryReel` code aujourd'hui `CMTime(value:, timescale: 24)`
en dur (`StoryVideo.swift:144`) — nos fichiers sont à 30. Le composant de la porte
doit prendre la base de temps en paramètre, ou exprimer le raccord en secondes.

---

## 11. LES ARBITRAGES — TRANCHÉS LE 22-08

1. **La durée du film d'entrée** → **version courte, 8,40 s, au PREMIER LANCEMENT
   seulement** (§ 3.3, § 8). Aux ouvertures suivantes, le carrousel s'ouvre direct
   sur sa boucle.
2. **La page 3** → **on recadre sur le tiers haut et on relève la matière au
   recuit**, en tenant le ratio de canaux mesuré, cible p99 ≥ 90 sur le tiers haut
   et moyenne du cadre ≤ 40 (§ 5.1). Repli si le téléphone dit non : changer de source.
3. **La sortie** → **la flamme embrase** (§ 7). Le header meurt par le haut, le
   foyer enfle à la couleur mesurée du lit, le nuage de braises couvre la coupe.
4. **Le découplage sang / nuages** → **`night` passe en `float4`** (§ 3.1). Quatre
   points de code dans le même commit ; en oublier un rend la page blanche.

### LE FOUETTAGE (22-08, après J6 — la règle est désormais en mémoire :
### tout se fouette AVANT d'être montré)

**Relecture adverse ligne à ligne des deux fichiers neufs, contre la checklist
des pièges payés. Quatre vrais défauts trouvés et corrigés :**

1. **Une opacité nulle reste tappable** — pendant le film, le bouton invisible
   gardait son rectangle : un tap dans sa zone déclenchait la CÉRÉMONIE DE
   SORTIE en plein film d'arrivée, au lieu du saut. → `allowsHitTesting(habille)`.
2. **`ReelPorte` ne survivait pas à l'arrière-plan** — la réécriture avait
   perdu l'observateur `willEnterForeground` de `CalqueVideo` : une
   notification pendant le film = image figée pour toujours. → reprise de la
   seule couche VIVANTE (réveiller la boucle avant le relais l'avancerait en
   douce et le raccord sauterait).
3. **`reduceMotion` n'avait pas de chemin dans l'arrivée** — la lune l'avait,
   le film de 4,93 s non. → la porte naît posée (le `sauter()` du tap).
4. **La boucle d'attente de la lune tournait À CHAUD sur une vue démontée** —
   `try?` avale l'annulation du `.task`, le `sleep` annulé revient
   immédiatement et le `while !MoonSDF.isReady` spinnait. → gardes
   `Task.isCancelled` (⚠️ le même motif existe dans MoonSplash.swift:852,
   l'archive — hérité, pas touché).

**Puis quatre films re-mesurés sur le binaire final :**

| film | frames scannées | flashes en V | verdict |
|---|---|---|---|
| croisé (`-porteAuto`) | 7 418 | **0** | deltas max 9,7 hors coupes système |
| arrivée (`-porteArrivee`) | 718 | **0** | cadence 58-60 |
| sortie (`-porteSortie`) | 531 | 0 (1 faux positif : une MONTÉE depuis le noir) | rideau/foyer/habillage à l'heure |
| complet à froid (aucun drapeau) | 1 043 | **0** | la lune joue à **60/60/60** (le four décalé a payé) ; le stall de montage de la porte (357 ms) tombe dans la couture mesurée à ≤ 2,9/255 de luminance — invisible |

La relecture par agents a échoué (limite de session) : celle-ci est MANUELLE,
ligne à ligne — pas un « 0 défaut » d'agents morts.

**Reste ouvert — tout est du VERDICT TÉLÉPHONE, le code est prêt :**

- `flammeBas` — départ à **+56 pt**, curseur `-porteFlamme <v>` de 0 à 96.
- Les trois états de la lune — teintes et tenue des paliers, au téléphone
  (`-luneSangLab`, `-luneSangFreeze <t>`). Le sim est aveugle aux gels Metal.
- Les trois battements haptiques (`RocketHaptics.paliers`) — muets au sim.
- Le noir de la couture (~1 s entre l'extinction et la première lumière du
  film) — un souffle voulu ; s'il est trop long, on chevauche l'extinction et
  le fondu d'entrée.
- La queue de sortie du bouton (~2,34 s, coupe à 2,10) — sous les braises ; si
  elle se voit, raccourcir le ressort du reveal inverse.
- Les quatre textes anglais — les lignes du § 4.1 et leurs variantes, à choisir
  à l'écran.
- ~~Le scrim sous le texte~~ — **TRANCHÉ PAR LA MESURE (J1)** : 13,9:1 partout,
  pas de scrim.
- ~~La cadence de sortie du recuit~~ — **30 img/s tenus** : 60 img/s mesurés à la
  sonde sur tous les régimes (repos, glissement, arrivée, sortie).
