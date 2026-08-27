# LA STORY CARD, VARIANT « LA COLONNE » — les stickers à gauche
# qu'on prend dans la main, le texte en bas qui sort de la nuit

**Écrit le 27-08-2026 sur le brief de Kathryn — RIEN n'est codé
(« fais deux plans !! pour des variants spectaculaires. ne code
pas »).** Un DEUXIÈME variant de la card de la story 3 (la robe
`.story`), qui ne remplace rien : les deux robes coexistent, le
choix se fait au moteur (note backend §4 nonies).

> Le brief : « faire un variant avec le texte en bas fondu et les
> stickers sur le côté gauche qu'on peut aussi bouger ».

---

## 1. CE QUI EXISTE — mesuré ligne à ligne, pas supposé

La robe actuelle : `StoryCard`, `Woop/Views/StorySuite.swift:167`
(la page hôte est `StoryAnalyse`, :115). Elle est COMMITÉE et
validée. Le variant la CLONE ; on ne touche pas à l'originale.

### 1.1 Le gabarit (commun aux quatre cards de la story)

| | valeur |
| --- | --- |
| largeur `l` | `min(size.width · 0.80, 332)` → 314,40 pt sur un écran 393 ; plafond 332 |
| hauteur `h` | `l · 1.32` → 414,98 pt |
| position | `(0.52·W ; 0.53·H)` — décentrée +7,86 pt à droite, +25,6 pt en bas |
| forme | `RoundedRectangle(cornerRadius: 36, style: .continuous)` |
| fond | `LinearGradient([white 0.105, white 0.055], top→bottom)` |
| arête | `strokeBorder` 1 pt, blanc 0,16 @0 → 0,04 @0,38 → clear @1 (topLeading→bottomTrailing) — « une arête rasante OUVERTE, jamais un contour fermé » |
| entrée | opacité `sstep(0.25, 0.80, t)`, montée de 16 pt finie à 0,85 s |
| hold de la page | `StoryCine.hold[2]` = **7,0 s** |

Mise en page interne actuelle (`StorySuite.swift:194-202`) :
`VStack(alignment: .leading, spacing: 0) { scene.padding(.top, 26) ;
texte.padding(.top, 18) ; Spacer() }` puis
`.padding(.horizontal, 30)` — la colonne de contenu fait **l − 60 =
254,40 pt**.

### 1.2 Les trois pièces qui bougent dans le variant

**LE MOT GÉANT** (`titre(l:)`, :428-476) : `corps = l·1.30 /
max(3, mot.count)` → police `corps · 1,55` = **158,38 pt black** pour
BOSS/KING, 126,70 pt pour SOLID ; tracking `−corps·0,04` ; encre
`LinearGradient([white 0.94, white 0.26])` ; masque des flancs
ASYMÉTRIQUE (`clear@0 / 0.35@0.16 / white@0.42 / white@0.86 /
clear@1` — « le fondu de GAUCHE commence PLUS TÔT : le mot sort de la
nuit ») ; traîne (`white@0 / 0.72@0.40 / 0.20@0.70 / clear@0.94`) ;
**opacité plafonnée à 0,52**, rampe 0,35 → 0,90 s ; offset
`y = −grand·0.16` = −22,13 pt et `x = gyro · 3`. Le mot est le
PREMIER du ZStack de la scène : les stickers mordent dessus.
Sept nappes diffuses dedans (périodes 3,7/5,3/7,1/4,3/6,7/9,1/5,9 s,
`blur 6`, opacité `sstep(1.2, 2.2, t)`) — la lame de balayage est
MORTE (« le balayage sur la police c'est trop cheap »).

**LES STICKERS** (`sticker(_:i:grand:x:deg:bal:)`, :376-411) :
`grand = l·0.44` = **138,34 pt** ; trois poses en RANGÉE horizontale
`[(−0.52, −8°, z0), (0.02, +4°, z2), (0.56, +11°, z1)]` → offsets
x = −71,94 / +2,77 / +77,47 pt. Slam : départs 0,45 / 0,61 / 0,77 s
sur 0,30 s, échelle **1,55 → 1,00** (`outLong` k = 3). Lévitation
±3,0 pt (période 4,00 s), balancement ±3,5° (8,85 s), souffle ±1,2 %
(3,31 s), déphasage `i·2.1`. Ombre : ellipse `grand·0.44 × grand·0.10`,
`blur 8`, opacité `0.50·pose`, qui S'ALLONGE À L'OPPOSÉ de la nappe.
Parallaxe gyro DIFFÉRENTIELLE ±3,5 / ±5,1 / ±6,7 pt selon le rang.
Trois grains haptiques (0,57 / 0,73 / 0,89 s).
La planche : heuristique sur `session.title` → 3 stickers (2 dans le
seul cas piscine) ; `.flamme` toujours en dernier ;
`WoopSticker.asset` = PNG 384² (bras, basket, flamme, abricot,
chocolat) ou 768² (jambes, piscine) — **384 px pour un cadre de
138,34 pt sur un écran @3x (415 px) : c'est sous-échantillonné.**

**LE TEXTE** (`texte`, :619-640) : SIX lignes, `.system(25, .bold)`,
`VStack(alignment: .leading, spacing: 3)`, blanc des faits
`white 0.94`, gris `white(0.48 + 0.34·actif)`. Entrée : `a = 0.70 +
i·0.10`, `sstep(a, a+0.45)`. **La lecture qui s'allume** : `lit =
1.9 + i·0.55` (1,90 → 4,65 s), `actif = sstep(lit, lit+0.35) ·
(1 − sstep(lit+0.95, lit+1.30))` — chaque ligne grise s'éclaire à son
tour puis se rendort ; la dernière s'éteint à 5,95 s pour un hold de
7,0 s. Le bloc vit dans le FLUX, sous la scène : son haut est à
26 + 143,87 + 18 = **187,87 pt** du haut de la card, son bas vers
382 pt sur 414,98 — il reste ~33 pt de marge.

### 1.3 Ce qui vit par-dessus, et les gestes

- **Le spotlight** (`:353-359`) : `EllipticalGradient([(1.0, 0.94,
  0.84) @0.26 → clear])`, `grand·1.8 × grand·1.2` = 249 × 166 pt,
  `plusLighter`, qui BALAIE en `x = sin(t·0.52)·l·0.33` — **±103,75 pt,
  période 12,08 s**. C'est LA lumière de la scène : l'ombre des
  stickers et la poudre lui obéissent.
- **`PoudreStory`** (`:651-730`) : 58 grains, Canvas 30 Hz, cantonnée
  au TIERS HAUT (`cy = h·(0.10 + 0.34·hash)`), éclairée par la nappe
  (`sigma = l·0.20`, `nappe = l/2 + balaie`), `gain = 1` ici.
- **Le tilt** : `.simultaneousGesture(DragGesture(minimumDistance: 3))`
  → `pench = clamp(±11, translation/9)`, `rotation3DEffect` sur les
  deux axes, retour ressort (0,42 / 0,62). Autorisé « parce que cette
  card n'a pas de verre natif ».
- **L'appui long** : `LongPressGesture(0.24).sequenced(before:
  DragGesture(0))` → `scaleEffect(1.02)`. Le MÊME 0,24 s arme la
  pause du chef d'orchestre.
- **Le rect publié** : `.onGeometryChange { $0.frame(in:
  .named("storyFlow")) } → onCardRect` — c'est LUI qui fait renoncer
  le chef (pas de descente de page, pas de changement de page ; un
  tap prolonge l'horloge en recalant `pageStart` à −1,2 s).

### 1.4 La machinerie de saisie existe déjà — mais elle est enfermée

Tout ce qu'il faut pour « qu'on peut aussi bouger » est écrit et
validé dans `StoryWin` (`StorySuite.swift:1811-1932`) :

```swift
private struct Bornes { let x: CGFloat; let haut: CGFloat; let bas: CGFloat }
private func objet<V: View>(cle: Int, centre: CGPoint, l: CGFloat,
                            h: CGFloat, base: CGPoint,
                            bornes: Bornes? = nil, revient: Bool = false,
                            @ViewBuilder _ contenu: () -> V) -> some View
```

- états : `placements` (la place gardée), `prises` (le delta en
  cours), `tenus` (qui est dans la main), `grains`, `saisies` ;
- geste : `.gesture(DragGesture(minimumDistance: 2, coordinateSpace:
  .named("storyFlow")))` — un geste d'ENFANT, `minimumDistance: 2`
  pour qu'un tap franc retombe chez le chef ;
- `onChanged` : entrée dans `tenus` + une haptique légère à la
  SAISIE, `prises[cle] = translation`, et **un grain de poudre par
  rappel de doigt tant que `grains.count < 90`** ;
- `onEnded` : soit le RESSORT de retour (`spring 0.62 / 0.58`,
  `revient: true` — les boosters), soit le cumul dans `placements`
  (`revient: false` — la pièce reste où on la pose) ; puis le ménage
  des grains de plus d'une seconde, **une fois par lâcher, jamais par
  image** ;
- `PoudreDoigt` : Canvas 30 Hz, grains de 0,8 s, étoiles à 4 branches
  de 0,8 à 2,4 pt, blanc bleuté (0,95 ; 0,97 ; 1,00), plafond 90,
  **montée seulement s'il y a des grains** (« une Canvas à 30 Hz qui
  ne dessine rien reste une horloge qui coûte : 58 img/s contre 82 »).

⚠️ Tout cela est `private` DANS `StoryWin`. Le variant ne doit ni
copier-coller (deux vérités qui divergeront) ni refactorer à
l'aveugle une page validée — voir le jalon C1.

---

## 2. LE DESSIN DU VARIANT — un poster, pas une card

Le principe : **la card devient une vitrine**. À gauche, une COLONNE
d'objets qu'on prend dans la main ; à droite, le vide sombre ; en
bas, le texte qui SORT de la nuit sous la traîne du mot géant. On
lit de haut en bas dans une seule diagonale : objets → mot → phrases.

```
┌──────────────────────────────┐
│ ▣                            │   ▣ = sticker (saisissable)
│      ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─    │   la colonne mord le vide,
│   ▣  │   B O S S        │    │   le mot géant est DERRIÈRE,
│      └ ─ ─ ─ ─ ─ ─ ─ ─ ─    │   posé bas et fondu
│ ▣                            │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │   ░ = la nuit d'où sort le texte
│    Big push day.             │
│    32 kg on                  │
│    développé,                │
│    your best set,            │
│    18 sets in 42 min.        │
│    Keep pressing.            │
└──────────────────────────────┘
```

### 2.1 LA COLONNE DE GAUCHE — trois objets qu'on prend

- **Format** : `grandC = l · 0.30` ≈ **94,3 pt** (contre 138,34 en
  rangée — trois objets empilés dans 415 pt de haut ne peuvent pas
  garder la taille d'une rangée de trois côte à côte).
- **Les places** (repère du centre de la card, `x` en fraction de `l`,
  `y` en fraction de `h`) :

| rang | x | y | rotation | échelle | z |
| --- | --- | --- | --- | --- | --- |
| 0 | −0,315 | −0,290 | −11° | 1,00 | 0 |
| 1 (**héros**) | −0,255 | −0,065 | +6° | **1,16** | 2 |
| 2 | −0,330 | +0,155 | −5° | 0,94 | 1 |

  Le héros du milieu est plus gros et AVANCE de 0,06·l vers le
  centre : la colonne n'est pas une pile, elle SERPENTE — c'est le
  même refus de l'alignement mécanique que le serpentin des galets.
  Les trois se CHEVAUCHENT verticalement de ~8 pt (l'écart de
  0,225·h = 93,4 pt pour des objets de 94,3 à 109,4 pt).
- **L'arrivée** : le slam existant, mais EN CASCADE DESCENDANTE et
  légèrement plus lente — départs 0,45 / 0,65 / 0,85 s sur 0,32 s,
  échelle 1,55 → 1,00 ; ils tombent du haut de 10 pt
  (`offset y = (1 − pose)·(−10)`). Les trois grains haptiques
  suivent (0,59 / 0,79 / 0,99 s).
- **La vie au repos** : inchangée dans son école mais réorientée —
  la lévitation devient **latérale ET verticale** (une ellipse de
  Lissajous : `x = sin(t·0.53 + φ)·2,5`, `y = sin(t·1.57 + φ)·3,0`),
  balancement ±3,5°, souffle ±1,2 %, `φ = i·2.1`. Un objet suspendu
  dans une vitrine ne monte pas et ne descend pas seulement : il
  DÉRIVE.
- **L'ombre** : conservée, mais posée sous chaque objet
  (`grandC·0.44 × grandC·0.10`, `blur 8`, `y = grandC·0.30`) et
  toujours allongée À L'OPPOSÉ de la nappe du spotlight.
- **LA SAISIE** — le cœur du variant :
  - `revient: true` (le RESSORT du booster) : la colonne se
    reforme toujours. Une vitrine dont les objets restent par terre
    n'est plus une vitrine — et la story se rejoue.
  - `bornes = Bornes(x: l/2 − grandC·0.50 − 10.5,
    haut: −h/2 + grandC·0.50 + 10.5, bas: h/2 − grandC·0.50 − 10.5)` :
    on peut les traîner **partout dans la card**, jamais dehors — la
    card CLIPPE avant les gestes, un objet qui déborde disparaît net,
    et dans un coin R36 l'écart entre le rectangle et la forme atteint
    **10,5 pt** (`36 − 36/√2`). Contrairement aux boosters, qui
    pouvaient sortir : ici la card est un cadre, pas une poche.
  - **zone de touche réduite au glyphe** : `.contentShape(Circle()
    .scale(0.62))`. Le PNG porte de larges marges transparentes (le
    glyphe ne fait que ~45 % du canevas) et **SwiftUI teste le
    RECTANGLE, pas l'alpha** — sans ça le doigt attrape un objet en
    visant du vide, et les voisins se volent le départ du drag
    (l'école `CalLab.swift:3425-3428`).
  - **la saisie ne s'arme qu'à t ≥ 1,15 s** : avant 0,95 s le chef
    d'orchestre tourne la page sur n'importe quel tap (garde
    `clock > 0.95`), et les objets slament jusqu'à 1,07 s. Un objet
    qui vient d'atterrir n'est pas encore un objet qu'on prend.
  - **le rect publié prend 20 pt de marge sur chaque bord** (l'école
    `StoryWin`) : sans ça, un doigt qui vise le bord d'un objet collé
    au flanc gauche démarre hors du rect et le chef reprend le geste.
  - la poudre de diamant du doigt (`PoudreDoigt`, l'identique), une
    haptique légère à la saisie.
  - **le sticker TENU se soulève** : `scaleEffect 1.08`, son ombre
    S'ÉLARGIT de 30 % et s'ADOUCIT (`blur 8 → 14`), `zIndex` porté à
    10 — il quitte la colonne, il est dans la main. Rampe 0,18 s.
- ⚠️ **LE CONFLIT À RÉSOUDRE** (mesuré au code, pas supposé) : la
  card porte DÉJÀ un `.simultaneousGesture(DragGesture(
  minimumDistance: 3))` qui la fait TILTER de ±11°. Simultané = il
  recevra AUSSI le doigt qui traîne un sticker : on tirerait l'objet
  ET la card en même temps. Remède : `guard tenus.isEmpty` dans le
  `onChanged` du tilt (et remise à zéro du `pench` à la saisie).
  Le tilt reste vivant partout ailleurs sur la card.

### 2.2 LE TEXTE EN BAS, QUI SORT DE LA NUIT

- **La place** : le bloc quitte le flux du `VStack` et s'ancre au
  bas — `.frame(maxHeight: .infinity, alignment: .bottom)` +
  `.padding(.bottom, 30)`, colonne toujours à `.padding(.horizontal,
  30)` mais DÉCALÉE à droite de la colonne d'objets :
  `.padding(.leading, 44)` — MESURÉ sur la capture de référence : la
  plus longue ligne de la démo (« 18 sets in 42 min. », 18 signes)
  fait **163,8 pt**, soit 0,364 em d'avance ; une ligne de 20 signes
  (le maximum du contrat) fait ≈ 182 pt et il reste 210 pt après le
  décalage. Le contrat « ≤ 20 signes » tient — voir §7.1, où une
  estimation à 275 pt avait failli tuer le variant.
- **LE FONDU — le sens compte.** Le bloc est masqué d'un dégradé
  vertical `clear@0 / white 0.30@0.14 / white 0.72@0.38 /
  white@0.62 / white@1` : **le texte ÉMERGE de la nuit en
  descendant**, il ne s'y noie pas. La dernière ligne (« Keep
  pressing. » — la chute) reste PLEINE. C'est la lecture que je
  retiens : un texte dont on ne lit pas la fin n'est pas un texte
  (la loi `titleFade` de `Theme.swift:164-179` : « on s'arrête à
  0,25 — plus bas, les dernières lettres cessent d'être lisibles, et
  un titre illisible n'est plus un titre »). La lecture inverse (le
  texte qui se noie vers le bas) est **la question Q1**.
- **La nuit sous le texte** : un voile propre à la card, dans son
  fond, sous le mot — `LinearGradient(clear@0 / black 0.35@0.55 /
  black 0.62@0.82 / black 0.70@1)` clippé par la forme. Il creuse le
  pied de la card pour que le texte ait de quoi émerger, et il
  RENFORCE la traîne du mot géant au lieu de la concurrencer.
- **La lecture qui s'allume est CONSERVÉE** — c'est la plus belle
  chose de cette page (`lit = 1.9 + i·0.55`). Un seul réglage : les
  entrées se resserrent (`a = 0.62 + i·0.08`) parce que le regard
  arrive plus tôt en bas dans cette composition.
- **La typo** : `.system(25, .bold)` conservée (elle est la taille de
  référence des cards) ; interligne porté de 3 à **5 pt** — un bloc
  posé au sol respire davantage qu'un bloc au milieu.

### 2.3 LE MOT GÉANT DESCEND, ET SE FAIT PLUS DISCRET

Il n'est plus un header : il est le CIEL de la moitié basse.

- ancrage `.frame(width: l, height: h, alignment: .center)` avec
  `offset y = +h·0.06` (au lieu de `−grand·0.16` en header) : sa
  tête arrive vers 42 % de la hauteur, sa traîne meurt DANS le voile
  de nuit, juste au-dessus de la première ligne ;
- **opacité plafonnée à 0,42** (au lieu de 0,52) : il y a désormais
  des objets nets à sa gauche, il doit reculer d'un cran (la même
  valeur que le WIN de la page butin, qui a payé cette leçon) ;
- masque des flancs re-symétrisé (`clear@0 / white@0.22 / white@0.80
  / clear@1`) : la colonne d'objets occupe déjà le flanc gauche,
  l'asymétrie d'origine (qui servait à faire « sortir le mot de la
  nuit » à gauche) n'a plus de rôle ;
- les sept nappes diffuses, inchangées.

### 2.4 LE SPOTLIGHT SUIT LA COLONNE

Aujourd'hui il balaie ±103,75 pt autour du centre. Dans le variant,
sa course se DÉCALE à gauche (`centre x = −l·0.18`, amplitude
`l·0.26` = ±81,7 pt, même période 12,08 s) : la lumière lèche la
colonne d'objets et meurt sur le texte. La poudre suit
automatiquement (`nappe = l/2 + balaie`), et l'ombre des objets
continue de fuir la lampe. **Une seule lumière dans la scène, tout
lui obéit** — c'est déjà la loi de cette card.

### 2.5 LE DÉTAIL QUI FAIT LE WAHOU

Quand on REPOSE un sticker (le ressort le ramène), il **rebondit sur
sa place** : une cloche de 4 % d'échelle à l'arrivée (0,12 s), et
l'ombre encaisse le choc en s'élargissant de 8 % puis en revenant.
Plus un grain haptique doux au moment exact où le ressort passe sous
1 % de sa course. C'est le seul événement de la page qui n'est pas
sur l'horloge : il est à TOI.

---

## 3. LES JALONS (une capture validée à chaque pas)

- **C1 — LA MACHINERIE PARTAGÉE (le pas risqué, à faire en premier
  et à prouver).** `Bornes`, `objet(...)`, `PoudreDoigt` sortent de
  `StoryWin` vers un petit hôte réutilisable du même fichier — soit
  un `struct SaisieObjets` qui porte les cinq `@State` et rend le
  helper, soit un `@Observable` local. **Extraction À L'IDENTIQUE**,
  zéro changement de comportement : la preuve est un film A/B de la
  page WIN (même cadence 76-80 img/s, mêmes bornes, même ressort,
  même poudre) AVANT de brancher quoi que ce soit sur la story card.
- **C2 — le squelette du variant** : `StoryCard` gagne une robe
  (`enum RobeStory { case rangee, colonne }`, `.rangee` par défaut),
  banc `-storyCardColonne`. Colonne posée, mot descendu, texte
  ancré en bas : capture des deux robes côte à côte.
- **C3 — le fondu du texte** + le voile de nuit : réglage à la SONDE
  de luminance (les pixels du texte, pas la moyenne de ligne — la
  règle payée), et vérification que la dernière ligne reste ≥ 0,90
  de l'encre pleine.
- **C4 — la saisie** : les trois objets saisissables, bornes, ressort
  de retour, poudre du doigt, levée à la prise, `guard tenus.isEmpty`
  sur le tilt. **Vérifier au doigt sur l'appareil** : le tap simple
  ne doit toujours pas changer de page, et le drag ne doit pas tirer
  la story vers le bas (le rect publié fait déjà les deux).
- **C5 — le spotlight décalé**, la cascade du slam, le rebond du
  repos, les trois haptiques.
- **C6 — fouettage** : film long, détecteur de flash, cadence
  `mpdecimate` sur la fenêtre localisée à la planche-contact (⚠️
  `-storyAuto` BOUCLE : jamais à l'horloge). **Budget : ≥ 75 img/s**
  — la page actuelle tient 82 ; la poudre du doigt ne coûte que
  saisie en main.
- **C7 — verdicts téléphone** (le gyro, la saisie, l'haptique) et
  note backend §4 nonies.

## 4. LE BACKEND — ce que le variant demande (rien de neuf)

Le payload `.story` du §4 ter ne change pas d'un signe : 2-3
stickers, `bigWord` 3-6 lettres, **exactement 6 lignes** de ≤ 20
signes avec les drapeaux gris par mot. Le variant est une ROBE, pas
un contrat : il se choisit côté moteur (§4 nonies), et les gabarits
déterministes de secours restent les mêmes.

⚠️ Un seul point d'attention pour l'IA : dans cette robe, la
DERNIÈRE ligne est la seule qui reste pleinement lumineuse — c'est
la chute. Le gabarit doit continuer d'y mettre l'impératif
(« Keep pressing. », « Hold the line. », « Walk it off. »), jamais un
chiffre.

## 5. À TRANCHER PAR KATHRYN

1. **Le sens du fondu** : le texte ÉMERGE de la nuit en descendant
   (proposé — la dernière ligne reste pleine), ou il SE NOIE vers le
   bas (plus radical, la chute devient un murmure) ?
2. **Les objets reviennent-ils à leur place** (proposé, l'école du
   booster) ou **restent-ils où on les pose** (l'école de la pièce du
   butin — la vitrine garde la trace du doigt jusqu'à la fin de la
   page) ?
3. **Le mot géant** : reste-t-il derrière (proposé, opacité 0,42), ou
   disparaît-il complètement de ce variant — la colonne d'objets
   étant déjà le sujet ?
4. **La colonne** : trois objets comme aujourd'hui, ou **quatre**
   (on relâcherait la borne des 3 stickers) ? Quatre remplit mieux
   un flanc de 415 pt, mais dilue le sens (chaque sticker est un
   fait).
5. **Le variant se déclenche quand** : une fois sur deux, un jour sur
   sept, sur un fait précis, ou au hasard « pour la surprise » ?

## 6. LES PIÈGES QUI S'APPLIQUENT ICI (déjà payés ailleurs)

- **Un Button sous un DragGesture d'ancêtre est ANNULÉ** — d'où le
  geste d'ENFANT à `minimumDistance: 2`, jamais un Button.
- **Le geste annulé garde son état** : si un drag meurt sans
  `onEnded`, `tenus` reste collé et le tilt reste mort. Le chien de
  garde (0,6 s) de la molette est la réponse écrite ; à reprendre si
  la sonde le montre.
- **La ligne incompressible décale la page** : le bloc de texte est
  déjà dans une largeur imposée ; l'ancrage en bas ne doit pas
  introduire de `minWidth`.
- **Une Canvas rasterise toute sa surface même vide** : `PoudreDoigt`
  reste montée SEULEMENT s'il y a des grains.
- **La sonde constante ne rappelle jamais** : le rect de la card doit
  continuer d'être publié par `onGeometryChange` sur un champ VIVANT.
- **Mesurer une couleur sur les PIXELS CLAIRS**, jamais en moyenne de
  ligne — pour le réglage du fondu du texte.

---

## 7. RELECTURE ADVERSE — ce que le contrôle a trouvé, et ce que
## j'ai MESURÉ moi-même (27-08)

Un agent de relecture a passé le plan au code. Six trous réels, et
**deux affirmations que la mesure a démenties** — la règle de la
maison (« un juge qui affirme ne remplace pas une sonde qui mesure »)
vient de se payer une fois de plus.

### 7.1 DÉMENTI PAR LA MESURE — la largeur du texte n'est pas un
### problème

Le contrôle calculait qu'une ligne de 20 signes en SF 25 bold fait
≈ 275 pt (avance moyenne supposée 0,55 em) et concluait : « au-delà
d'une colonne de stickers de 40 pt, le texte ne tient plus », ce qui
tuait le variant.

**Mesuré sur la capture de référence** (`ref_storycard.png`, banc
`-storyLab`, 420 px pour 393 pt = 1,069 px/pt), en relevant les
pixels clairs de chaque bloc :

| ligne | largeur RÉELLE |
| --- | --- |
| « Big push day. » (14 signes) | 146,0 pt |
| « 32 kg on » | 59,9 pt |
| « développé, » | 121,6 pt |
| **« 18 sets in 42 min. » (18 signes)** | **163,8 pt** |

Soit **0,364 em d'avance**, pas 0,55 : une ligne de 20 signes fait
**≈ 182 pt**, pas 275. Avec la colonne de contenu de 254,40 pt, il
reste **72 pt de marge**. Le décalage à droite du bloc de texte est
donc possible — je le fixe à **44 pt** (au lieu des 52 du §2.2), ce
qui laisse 210 pt pour 182 : 28 pt de sécurité pour un gabarit qui
serait plus large que la démo. **Le contrat backend « ≤ 20 signes »
tient** — rien à changer au §4 ter.

### 7.2 DÉMENTI — le budget vertical se libère tout seul

Le contrôle a raison sur le constat : le flux actuel (26 + 143,87 de
scène + 18 + ~192 de texte) ne laisse que ~33 pt de jeu (mesuré sur
la capture : le texte finit à 375,5 pt sur 415, soit 39,5 pt de
marge). Mais sa conclusion (« il faut rétrécir la scène ») rate le
point : **dans ce variant la colonne QUITTE LE FLUX.** Les trois
objets sont posés en absolu (`.position`, comme les objets de la page
butin), pas dans un `VStack`. La bande de 143,87 pt disparaît du
calcul : le texte peut s'ancrer en bas avec toute la hauteur pour
lui. À écrire noir sur blanc dans le jalon C2.

### 7.3 CONFIRMÉ ET AGGRAVÉ — le tilt, et lui seul, doit être désarmé

Le contrôle confirme la lecture du §2.1 et ferme la porte à
l'alternative : **`.highPriorityGesture` sur l'enfant ne tue PAS le
`.simultaneousGesture` d'un ancêtre** — c'est sa définition, et c'est
exactement pourquoi le chef d'orchestre est monté ainsi. Le seul
remède est le DÉSARMEMENT (`guard tenus.isEmpty` dans le `onChanged`
du tilt, et `pench = .zero` à la saisie).

Il ajoute une raison de plus, chiffrée : dans `StoryCard` l'ordre des
modificateurs pose `.scaleEffect` puis les deux `.rotation3DEffect`
**AVANT** les gestes — or la loi du dépôt dit l'inverse
(`GaletEtape.swift:194-196` : « posés AVANT contentShape et les
gestes, sinon le repère du drag voyage avec la vue qu'il porte »).
Un objet positionné dans une card qui tourne de ±11° et grossit de
2 % se décale du doigt (≈ −2,3 pt sur 127 pt de course, plus la
perspective non modélisée du `rotation3DEffect`). Le désarmement
règle les deux d'un coup.

⚠️ **Et cela reste une affirmation, pas une mesure.** Jalon C0 :
un banc qui pose UN sticker saisissable nu et FILME si la card
bascule en même temps. On ne code le reste qu'après ce film.

### 7.4 CONFIRMÉ — trois trous réels dans le §2.1

1. **La card CLIPPE avant les gestes** (`.clipShape(Self.forme)` posé
   ligne 229, avant les `.simultaneousGesture`) : un objet traîné
   au-delà du bord DISPARAÎT net — contrairement à la pièce de WIN,
   qui vit dans une couche NON clippée. Les bornes doivent donc
   garder l'objet ENTIER dans la card, et tenir compte de l'arrondi :
   dans un coin R36, l'écart entre le rectangle et la forme atteint
   `36 − 36/√2` = **10,5 pt**. Bornes corrigées :
   `Bornes(x: l/2 − grandC·0.50 − 10.5, haut: −h/2 + grandC·0.50 +
   10.5, bas: h/2 − grandC·0.50 − 10.5)`.
2. **SwiftUI teste le RECTANGLE, pas l'alpha** — et le glyphe ne fait
   que ~45 % du canevas de ces PNG (commentaire `StorySuite.swift:
   159-160`). Aujourd'hui, en rangée, les boîtes se recouvrent déjà à
   46 % (pas de 74,71 pt pour des boîtes de 138,34) : **le doigt
   attrape un sticker en visant du vide.** Dans la colonne, chaque
   objet reçoit un `.contentShape(Circle().scale(0.62))` (l'école
   `CalLab.swift:3425-3428` : « les zones de tap : PETITES, sur les
   glyphes seuls — une grande zone volait le départ du drag »), et
   l'écart vertical de la colonne (0,225·h = 93,4 pt) reste supérieur
   à la zone de touche réduite (58 pt).
3. **Le rect publié n'a pas la marge de WIN** : `StoryCard` publie
   `frame(in: .named("storyFlow"))` brut, quand `StoryWin` publie la
   card + **20 pt sur chaque bord**. Un doigt qui vise les derniers
   points d'un objet collé au flanc gauche peut démarrer HORS du rect
   (le rect est un rectangle, la card un R36) et le chef reprendrait
   le geste. Recopier la marge de 20 pt.

### 7.5 CONFIRMÉ — la fenêtre des 0,95 s

`StoryFlow.swift:524` : le chef ne renonce au tap que si
`clock > 0.95` (« la partition ne FOND qu'à ~1 s — son rect ne compte
pas tant qu'elle est invisible »). Or les stickers slament de 0,45 à
1,07 s : **un doigt posé sur un objet à 0,8 s ferait AVANCER LA
STORY.** Dans le variant, la saisie ne s'arme donc qu'à **t ≥ 1,15 s**
(après le dernier slam, marge comprise) — un objet qui vient
d'atterrir n'est pas encore un objet qu'on prend.

### 7.6 CONFIRMÉ — un défaut hérité à corriger pendant l'extraction

`objet(...)` ne fait le ménage des grains **que dans `onEnded`**
(`StorySuite.swift:1874-1876`), avec un plafond de 90 posé dans
`onChanged`. À 60 rappels/s, un drag de **1,5 s sature le plafond et
la poudre MEURT en cours de geste** (vie d'un grain : 0,8 s). Le
jalon C1 (l'extraction) corrige : le ménage passe aussi dans
`onChanged`, une fois toutes les 10 insertions — jamais par image.
Le correctif profite AUSSI à la page butin.

### 7.7 CONFIRMÉ — la cadence de cette page n'a JAMAIS été mesurée

Aucun chiffre n'existe pour la story card, ni au sim ni au téléphone
(les 58/41/63/73/80 img/s sont ceux de WIN ; le 82 est celui de
Détails). Or c'est la vue la plus chargée non mesurée du fichier :
**7 nappes floutées (`blur(radius: 6)`) NON quantifiées** + 3 ombres
`blur(radius: 8)` + une Canvas de 58 grains à 30 Hz + `BacMotion` qui
republie à 30 Hz — la page se ré-évalue déjà au gyro, sans personne
qui la touche.

D'où **le jalon C0** (avant tout) : mesure de référence au banc, page
localisée à la planche-contact. Et une économie gratuite à prendre au
passage, déjà payée sur WIN : **quantifier l'horloge du mot à 20 Hz**
(`let t = (t * 20).rounded() / 20`) et **supprimer le `blur(6)` des
nappes** — c'est exactement ce qui a fait passer WIN de 41 à 63 img/s.

### 7.8 NON SPÉCIFIÉ — un objet saisi pendant la pause

`paused` n'est consommé par AUCUNE des cards (seulement par les
couches vidéo). Pendant l'appui long du chef (pause à 0,24 s), `t`
gèle mais les Canvas continuent à 30 Hz et le gyro republie. Un objet
SAISI PENDANT LA PAUSE est un état non défini. Décision à prendre au
jalon C4 : la saisie annule la pause (recommandé — un objet dans la
main est plus fort qu'une pause), ou la pause verrouille la saisie.

### 7.9 Ce que le contrôle a laissé ouvert, et qui reste vrai

- le micro-détail n° 3 du plan story v2 (« le TAP sur un sticker : il
  BONDIT et jette un éventail de mini-stickers ») occupe EXACTEMENT
  la place que ce variant donne au tap. Compatible techniquement (le
  drag ne s'arme qu'à 2 pt, un tap franc passe dessous) — mais il
  faut un `onTapGesture` d'ENFANT, jamais un `Button`
  (`SessionSlate.swift:448-452`). Statut à trancher : abandonné ou en
  attente ?
- aucun banc ne sait filmer un drag : la saisie et la poudre se
  jugent AU DOIGT, sur l'appareil. C'est la seule partie de ce
  variant qu'aucune capture ne prouvera.

---

## 8. CE QUI EST CODÉ (27-08)

`RobeStoryCard { rangee, colonne }` sur `StoryCard`, `.rangee` par
défaut, banc **`-storyCardColonne`**.

**C1 — LA MACHINERIE EST PARTAGÉE.** `Bornes` et `ObjetSaisissable`
sortent de `StoryWin` et deviennent des types du fichier : une seule
vérité, deux pages. `StoryWin.objet(...)` n'est plus qu'une
enveloppe qui passe ses cinq états. Deux ajouts au passage :
- `armeA` / `horloge` : la saisie ne s'arme qu'après une date de page
  (1,15 s sur la story card — avant 0,95 s le chef tourne la page sur
  n'importe quel tap) ;
- **le ménage des grains vit AUSSI dans `onChanged`** : avec le seul
  ménage du lâcher, un drag de ~1,5 s saturait le plafond de 90 et la
  poudre MOURAIT en cours de geste. Le correctif profite aux deux
  pages.

**La colonne** : trois objets à `l·0.30` (héros ×1,16 au milieu,
avancé vers le centre), places `(−0.315 ; −0.290) / (−0.255 ;
−0.065) / (−0.330 ; +0.155)`, rotations −11 / +6 / −5°, cascade
0,45 / 0,65 / 0,85 s. Dérive de Lissajous (±2,5 x, ±3,0 y),
balancement ±3,5°, souffle ±1,2 %, parallaxe gyro différentielle
conservée. **Saisissables**, retour à ressort, levée à 1,08 avec son
ombre qui s'élargit de 30 % et s'adoucit (flou 8 → 14), `zIndex` à 10
dans la main. Zone de touche **réduite au glyphe**
(`contentShape(Circle().scale(0.62))`) et bornes à
`grandC·0.50 + 10.5` (le coin R36).

**Le texte** s'ancre en bas (`padding .leading 44 / .bottom 30`,
interligne 5) sous un masque qui le fait **ÉMERGER de la nuit** — la
dernière ligne reste pleine. **Le mot géant** descend à `+h·0.06`,
recule à 0,42 et ses flancs se re-symétrisent. **Le spotlight** se
décale à gauche (amplitude `l·0.26`, centre `−l·0.18`).

**Le tilt se DÉSARME** dès qu'un objet est tenu (`guard tenus.isEmpty`)
— un `.gesture` d'enfant n'annule pas un `.simultaneousGesture`
d'ancêtre. **Le rect publié prend 20 pt de marge** sur chaque bord.

RESTE : la mesure de cadence de référence (C0 — cette page n'a JAMAIS
été mesurée), l'économie gratuite du mot (quantifier son horloge à
20 Hz, supprimer le `blur(6)` des nappes — ce qui a fait passer WIN
de 41 à 63), et les verdicts AU DOIGT.

### ⚠️ CODÉ MAIS **NON COMMITÉ** — il bugue (verdict 27-08)

Verbatim : « ne commit pas le deuxième variant, le gris avec BOSS et
les stickers, il bugue — on verra plus tard ! »

Vu au film (banc `-storyCardColonne`, sim kat-story) : **les objets
de la colonne se posent SUR le texte.** Les places du §2.1
(x = −0,315 / −0,255 / −0,330 de `l`) mettent leurs boîtes de
94-110 pt à cheval sur la colonne de texte, qui commence à 44 pt du
bord gauche — ils mordent les premiers signes de chaque ligne.

Les deux corrections à faire avant de reprendre :
1. **la colonne doit vivre au-dessus du texte, pas devant** : soit
   elle se limite aux deux tiers HAUTS de la card (y de −0,33·h à
   +0,02·h) et le texte garde le tiers bas pour lui seul, soit le
   texte se décale encore (mais le §7.1 a mesuré qu'au-delà de ~70 pt
   de décalage une ligne de 20 signes ne tient plus) ;
2. **le mot géant descendu à +h·0,06 arrive lui aussi dans le
   texte** — les trois calques (mot, objets, texte) se disputent le
   même tiers bas. C'est le même arbitrage vertical que celui qui a
   été chiffré pour la page butin au §7.3 de l'autre plan : il faut
   le faire ICI aussi, sur capture, avant de re-coder.

Le code écrit ce jour-là est SAUVEGARDÉ hors du dépôt :
`~/Downloads/woop-variant-colonne.patch` (11 hunks sur
`Woop/Views/StorySuite.swift`, applicable par `git apply`). Ce qui a
été commité de cette journée, c'est UNIQUEMENT la machinerie
partagée (`Bornes` + `ObjetSaisissable` + le correctif du ménage des
grains), qui part avec la page butin et sert les deux robes.
