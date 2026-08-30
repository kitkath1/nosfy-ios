# LA CARD BOOSTER v2 — « le sachet est le bouton », dans son champ d'étoiles

**Plan du 30-08-2026, sur les verdicts de Kathryn** après la capture
`captures/card-b2-115057.png` (variant B, tranché ce matin) :

> *« très mal détouré, d'ailleurs c'est le même composant que dans la page
> coffre ! corrige ça. En background derrière lui, en "fondu", cette vidéo dot
> (dans Downloads), bien fondue dans le noir. La petite main plus dégradé de
> blanc, premium, et écrit en anglais "glisse le…", plus premium, plus beau.
> Et un peu plus petit le booster. Fais un plan, ne code pas. »*

**Rien de ce plan n'est codé.** Ce qui existe : `Woop/Views/BoosterCard.swift`
(l'hôte, la card Animatable, le geste, le doigt v1), un hunk `WoopApp.swift`,
et un imageset `booster-hero` **faux** (voir §1). Sim **kat-stop**, `dd-stop`,
banc `-boosterPopup -skipAuth`.

---

## 1. LE DÉTOURAGE — j'ai refait une erreur déjà payée, la recette existe

### Ce qu'elle voit (mesuré)

Le zoom de la capture montre un **voile gris rectangulaire** autour du sachet
(net au-dessus du cran, sur les flancs) et un pied coupé à plat. Mon
`booster-hero` (cuit ce matin par `bake_sachet.py`) contient **156 841 px
mi-transparents ET sombres (10,6 % de l'image)** : c'est le fond noir du rendu
d'origine (luma 12-20) que mon alpha « de luminance » a rendu à demi opaque.
Posé sur la card (fond à 2-17/255), ce demi-noir est plus clair qu'elle : un
rectangle.

### Pourquoi c'était faux par construction

`tools/coffre-v2/bake_vignettes.py` l'écrit noir sur blanc, en tête de
fichier, et ça a coûté quatre versions le 28-08 : ***« je reconstruisais une
silhouette que quelqu'un avait déjà détourée »***. `booster-orange.imageset`
**porte déjà un vrai alpha** — mesuré ce matin : 62,4 % plein, 28,5 % en
dégradé (la lueur), 9,1 % nul. Je suis reparti de la luminance, exactement la
voie que ce fichier interdit.

### La recette juste = celle du coffre, à la taille du héros

`SachetVignette` (le composant du coffre — *« c'est le même composant »*) ne
détoure rien : il prend l'alpha livré et applique **deux traitements**, et
deux seulement (`bake_vignettes.py`, `durcir()`) :

1. **Durcir** : remapper l'alpha `0,55 → 0` et `1,00 → 1`. La lueur du rendu
   part, le cœur reste, et le pixel de transition (l'antialiasing du
   détourage vit entre 0,1 et 1) garde un bord lisse — couper net à 0,99
   donnerait un escalier.
2. **Couper le reflet au sol** à `y = 1310` (mesuré : le sachet et sa flaque
   orange y sont séparés). Sans la coupe, le sachet traîne sa flaque.

Résultat mesuré sur l'asset : **corps 903 × 1304 px, x 60-962, y 6-1309,
ratio 0,692** — une seule pièce, bord raide. Le pied est le **cran du bas**,
pas une coupe à plat.

**La lueur appartient à la SCÈNE, pas au sprite** (loi du §18.5 du coffre,
`CoffreV2.lueurObjet`) : un dégradé radial orange sous le sachet, fait par la
card — il peut respirer, suivre le glissement, s'éteindre au commit ; un halo
peint dans des pixels ne saura jamais faire ça.

**Le bake** : `tools/sacre/bake_sachet.py` est RÉÉCRIT — plus un seuil, plus
une fermeture, plus un `fill_holes` : `durcir` + coupe 1310 + crop aux bornes
(+ 4 px) → `booster-hero.imageset` 903 × 1304 (2,6 × la taille d'affichage à
176 pt sur ×3 — net). Portillon : 0 pixel mi-transparent sombre, bord raide
≤ 2 px (la référence `sticker-booster`), et la planche noir / fond de card /
gris de contrôle sans aucun rectangle.

---

## 2. LE FOND — la vidéo « dot », fondue dans le noir

### La source, mesurée : `~/Downloads/video_dot.mp4`

H.264 **3836 × 2160 (paysage), 24 img/s, 121 images / 5,04 s**, une piste
audio (à jeter). Une petite **constellation de points dorés** qui s'allument
et s'éteignent sur une grille discrète ; ils vivent en **x 24-76 %, y 38-61 %**
de l'image, centre (51 %, 48 %).

- **Le noir n'est pas noir** : décodé, fond min 0, médiane 10, **p95 24/255**,
  teinté chaud (R 10,8 · G 7,3 · B 5,2). Posé tel quel il ferait un rectangle
  brun sur la card. Il faut **écraser sous ~26** — c'est le pelage-à-zéro de
  la chauve-souris à l'envers : ici le fond est *presque* noir, et presque ne
  suffit pas.
- **La couture de boucle n'est pas propre** : |f0 − f120| = 0,73 contre 0,16
  entre deux voisines (× 4,5) → **palindrome** amputé (0→120 puis 119→1 :
  240 images, 10,0 s), la grammaire de la bête.
- **Une fenêtre portrait 1:1,40 ne contient PAS les points** : elle ne fait
  que 40 % de la largeur, les points en occupent 52 %. On ne recadre donc pas
  en portrait : on prend la **bande paysage entière**, mise à la largeur de
  la card.

### La forme juste : LA VIDÉO EST LE MUR (« la vidéo a gagné », la matrice)

On cuit un fichier **portrait 1080 × 1512** (= 314 × 440 pt à 3,44 px/pt, le
ratio 1,40 de la card) qui contient :

1. **le fond de la card lui-même** — les six stops de `BoosterCard.fond`
   (blanc 0,006 / 0,014 / 0,050 / 0,066 / 0,028 / 0,008 à 0 / 0,36 / 0,62 /
   0,74 / 0,86 / 1) rendus en pixels ;
2. **la bande de points**, écrasée (< 26 → 0, puis une courbe douce pour ne
   pas poster), mise à **1080 de large** (→ 608 px de haut, 177 pt), posée
   **derrière le sachet** (centre à y ≈ 136 pt = 468 px), en **écran** sur le
   fond, sous une **vignette** cuite : fondu radial et vertical qui meurt
   ~180 px avant ses bords — plus aucune arête, ni en haut, ni en bas, ni sur
   les côtés.

Ainsi, dans SwiftUI, la vidéo est **bord à bord, opaque, sans masque** (la
loi), et **ses bords valent exactement le fond** que la card dessine dessous :
pendant l'entrée elle fond dans un mur identique, pas de couture possible.
Les points, à 1080 de large, font ~164 pt d'envergure autour d'un sachet de
176 pt de haut (~122 de large) : ils l'encadrent, ils ne le noient pas.

Encodage : `libx264 -profile high -preset slow -crf 17 -g 48 -keyint_min 48
-sc_threshold 0 -x264-params no-dct-decimate=1:aq-mode=3`, bt709 / tv, `-an`,
`+faststart` — la grammaire de `bake_stop.py` (attendu ≈ 1,5 Mo).
**Portillon** : les 12 lignes/colonnes de bord du fichier décodé = le fond
attendu ± 1 (aucun rectangle) ; couture f0↔f239 < l'écart médian ; 240
images ; taille.

La couche : `VideoBoucle` (privée dans `StopCard.swift`) passe **internal**
avec son `nom:` — un hunk dans mon propre fichier, rien de plus. Empilement
final de la card : dalle noire → `fond` (SwiftUI, pour l'entrée) → **vidéo**
(opacité 0 → 1 sur `p` 0,15 → 0,55) → `LampeEventail` (écran) →
`PoudreBooster` → **lueur de scène** (radial orange, §1) → sachet → doigt et
légende → encre → liseré.

---

## 3. LE DOIGT ET LA LÉGENDE — premium, en anglais

### Ce qui cloche (v1)

`hand.point.up.left.fill` à 26 pt, plein, gradient blanc 0,95 → 0,35, posé à
42 % sous le centre du sachet : **trop gros, trop plein, sans mot**. Il se lit
comme un curseur, pas comme une invitation.

### La v2

- **Le glyphe** : `hand.point.up` (le **contour**, pas le plein), poids
  `.light`, **20 pt** — un trait, pas une masse. Rempli d'un **dégradé de
  blanc** vertical 0,96 → 0,28, et derrière lui une **lueur douce** (le même
  glyphe, blanc 0,35, `.blur(3)`, `.plusLighter`) : il est en lumière, pas en
  peinture. ⚠️ Un seul blur, sur 20 pt : coût nul (la loi des 27 img/s vaut
  pour un objet plein écran).
- **Le geste montré** : une boucle de **2,6 s** —
  1. 0 → 0,20 : il **arrive** (fondu + 4 pt de montée) ;
  2. 0,20 → 0,36 : il **touche** — un anneau fin (1 pt, blanc 0,55) naît au
     point de contact et s'ouvre de 18 → 46 pt en s'éteignant ;
  3. 0,36 → 0,76 : il **glisse vers le haut** de 46 pt, et laisse derrière
     lui une **traînée** : une capsule 2 × 28 pt, blanc 0,45 → 0, qui
     s'allonge puis s'efface — c'est elle qui dit « glisse », pas le doigt ;
  4. 0,76 → 1 : il s'efface.
  Il part du **tiers bas du sachet** (y = centre + 46 pt), légèrement à
  droite (x + 30) pour ne pas couvrir le croissant, et **s'éteint dès que la
  main touche** (déjà codé : `touche`).
- **La légende** : « **swipe up to open** » — **le vocabulaire exact de la
  home** (`HomeNuit.swift:4415`, « pull to start ») : `.inter(11, .medium)`,
  `tracking(1.6)`, blanc **0,46**, en minuscules. La même voix que l'invite
  du galet — l'utilisatrice l'a déjà lue cent fois. Posée **sous le sachet**
  (y = 272), elle respire avec le doigt (opacité 0,46 → 0,70 au moment de la
  traînée, jamais plus : une légende qui clignote est un défaut).
  Alternative : « slide up to open » (le slider de la home dit « slide to
  start » à la ligne 2670). À trancher (§7).

---

## 4. LES COTES v2 — card 314 × 440 pt (ratio 1,40), depuis le bord haut

| y (pt) | quoi | changement |
|---|---|---|
| 9 | la fente du spot | — |
| 0 → 196 | le cône (`LampeEventail`), balayage ±19° | — |
| 48 → 224 | **le sachet, 176 pt** (−12 %), centre **136**, ~122 de large | 200 → 176, centre 144 → 136 |
| ~60 → 237 | la bande de points, DANS la vidéo, centrée sur lui | nouveau |
| 182 → 136 | la course du doigt (il part du tiers bas du sachet et MONTE de 46 pt) | nouveau |
| 272 | « swipe up to open », Inter 11 medium, tracking 1,6, blanc 0,46 | nouveau |
| 312 → 338 | titre « A booster is waiting », Inter 22 semibold | 300 → 312 (le sachet plus court libère 12 pt, ils vont à l'air) |
| 348 → 366 | sous-titre « A Moon set card sleeps inside. », Inter 15, 0,55 | idem |
| 380 → 424 | « Later », 44 pt | — |
| 440 | bord bas (16 pt d'air) | — |

La lueur de scène (§1) : ellipse radiale orange (`booster` chaud, 0,42 → 0)
de 1,9 × 2,1 fois la largeur du sachet, centrée 12 pt sous son centre ;
opacité 0,55 au repos, **+ 0,25 pendant le glissement** (il s'allume quand on
le prend), → 0 en 0,2 s au commit (elle part avant lui).

---

## 5. LE CÂBLAGE — rien de nouveau à la racine

Le hunk `WoopApp.swift` du variant B reste tel quel (`BoosterCardHote`, zIndex
6, `onFermer` sans `withAnimation`). Le mouvement (entrée 0,70 s, envol
0,42 s → sortie 0,30 s → `sacre.ouvrirManege()`, Cancel 0,30 s) ne change
pas. **Toujours l'orange** : `robe:` ne descend plus, c'est acquis.

Fichiers touchés : `BoosterCard.swift` (sachet 176, lueur de scène, doigt v2,
légende, la vidéo), `StopCard.swift` (`VideoBoucle` internal — un hunk),
`tools/sacre/bake_sachet.py` (réécrit), `tools/sacre/bake_dot.py` (nouveau),
`Woop/Media/booster-dot-loop.mp4`, `booster-hero.imageset` (recuit).

---

## 6. JALONS — chacun avec sa preuve

- **J0 — LES DEUX CUISSONS, zéro Swift.** `bake_sachet.py` v2 → planche
  noir / fond / gris **sans rectangle**, bord raide ≤ 2 px, 0 px
  mi-transparent sombre. `bake_dot.py` → `booster-dot-loop.mp4` + son
  portillon (bords = fond ± 1, couture, 240 images, poids) + planche du
  raccord.
- **J1 — LA CARD, posée.** Capture `-boosterPopup -boosterCardFige`, cotes
  du §4 mesurées (`tools/stop/cotes.py` adapté : sachet, légende, titre), et
  **la composition Python d'abord** (fond + vidéo + sachet + lueur) pour
  trancher l'intensité des points AVANT le build — la leçon d'hier : 2 min
  au lieu d'un cycle.
- **J2 — LE MOUVEMENT.** Film du doigt (2 boucles), du glissement (le sachet
  monte, la lueur s'allume), du commit (envol → sortie → manège) et du
  Cancel. `analyse_film.py` sur les pts. **`charge.sh` avant**, sinon rien.
- **J3 — TON VERDICT** : le doigt, la légende, l'intensité des points, et le
  sachet à 176.

Commit par chemins (`BoosterCard.swift`, le hunk `StopCard.swift`, le hunk
`WoopApp.swift` **par hunk**, `tools/sacre/…`, Media, l'imageset) ; jamais
`git add -A` ; `git log -1` avant.

---

## 7. À TRANCHER (mes recommandations en premier)

1. **La légende** : « swipe up to open » (recommandé — le verbe du geste) /
   « slide up to open » (le mot du slider de la home).
2. **Les points au repos** : discrets (recommandé : la vidéo à 0,75
   d'opacité, ils scintillent sans voler la vedette) / pleins (1,0).
3. **Le doigt tape-t-il, ou glisse-t-il seulement ?** Les deux (recommandé :
   le tap ouvre aussi, il faut le dire) / glisser seul.

---

## 8. LES PIÈGES QUI S'APPLIQUENT ICI

1. **On ne re-détoure JAMAIS un asset qui a un alpha** — `bake_vignettes.py`,
   en-tête, quatre versions payées le 28-08, et une cinquième ce matin.
2. **La lueur appartient à la scène** (§18.5 du coffre) : durcir l'alpha,
   jeter la lueur, la refaire en radial.
3. **Un noir « presque » noir fait un rectangle** — écraser sous le p95 du
   fond mesuré (26), et **vérifier sur le fichier décodé**, pas en mémoire.
4. **Une vidéo ne se fond que bord à bord**, jamais par un `.mask` sur la
   couche : le fondu se cuit DANS le fichier, et ses bords valent le fond.
5. **`.mask` lit l'alpha** ; **`convert("L")` sur un RGBA ment** (payés hier).
6. **Un `Button` sous un drag d'ancêtre est annulé** : le sachet garde son
   `DragGesture(minimumDistance: 0)` unique, décision à la levée.
7. **`.blur` = 27 img/s par objet plein écran** ; sur un glyphe de 20 pt,
   rien — mais UN seul.
8. **`charge.sh` avant tout film ou `-fps`** : hier, ratio 8,4, une mesure
   jetée.
9. **`Woop/Media` est nu** — la vidéo par `Bundle.main.url`, le sachet en
   imageset. Le groupe Xcode est synchronisé, le `git add` reste manuel.
10. **Le mur du type-checker** : la card reste une addition de vues nommées
    (`fond`, `video`, `lueur`, `sachet`, `indice`, `legende`, `encre`).

---
---

# SECOND TOUR — 30-08, après-midi

Verdict de Kathryn sur la capture `card-b3-122307.png` (la v2 bâtie) :
*« non, toujours le bug du détourage !! regarde bien, tu vas trop vite. Et
la main : plus premium — Apple, full dégradé blanc, avec un filament blanc
qui glisse derrière, et le texte blanc flouté qui disparaît, "drag to…" —
quelque chose de premium, c'est trop cheap. Refais un plan. »*

**Rien de ce second tour n'est codé.** La v2 (Swift restructuré après la
relecture adverse, cuissons zoom 1,9 / bornes sur la queue) est bâtie dans
`dd-stop` ; elle sert de base.

## 9. LE DÉTOURAGE, SECOND VERDICT — la recette du coffre ne tient pas au héros

### Ce qu'elle voit, au zoom natif (`/tmp/zoom-pied-b3.png`)

1. **Une coupe à plat au milieu du cran du bas.** La recette du coffre coupe
   le reflet à `y = 1310` ; mesuré ligne à ligne sur l'alpha durci, **le cran
   court jusqu'à y = 1321** (largeur 818 px de 1312 à 1321, puis chute à 765 —
   le reflet, plus étroit). 1310 tranche 11 px de cran : une ligne droite dans
   les dents. Invisible sur une pill de 145 pt, c'est 2,5 pt sur un héros.
2. **Deux pieds orange sous les coins, et un bloom le long des flancs.** La
   lueur latérale du rendu survit au durcissage à 0,55… et **survit à tout
   seuil** : à 0,90 le pied est encore là — **il est OPAQUE dans l'alpha de
   la source** (bloom mesuré dans l'anneau de 40 px hors du corps : 51 450 px
   à 0,55, 16 402 à 0,90). L'alpha ne distingue pas cette lueur du plastique.

### Ce qui les distingue : la COULEUR, pas l'alpha

Le plastique est **sombre** (luma < 70) ; la lueur est **orange et claire**.
Le corps se déduit donc du plastique : par ligne, le span entre le premier et
le dernier pixel *opaque et sombre* (lissé sur 15 lignes — un sachet n'a pas
de trou, son contour est doux), et :

- **le liseré néon vit SUR le bord** du plastique → le corps est dilaté de
  **4 px** (0,5 pt au héros) pour ne pas le couper ;
- **les crans sont gris, pas noirs**, et **droits** : leurs lignes n'ont pas
  de plastique noir → on prolonge le dernier span valide en ligne droite (en
  haut) ;
- **sous le cadre néon (y ≥ 1180) le sachet est droit et c'est là que
  vivent les pieds** — le critère « neutre » (R − G < 25) qui les excluait
  mangeait aussi les flancs (le plastique y reflète l'orange : 766 px de large
  au lieu de 780, du sachet perdu) → on garde le critère sombre, et sous 1180
  on prolonge les flancs mesurés juste au-dessus, **en ligne droite** ;
- **coupe à 1322**, la fin réelle du cran ;
- plume gaussienne 1,2 px, et jamais plus opaque que la source.

**Mesuré sur le prototype** (`vignettes/sachet-corps-plastique.png`, sur
gris 60 / le fond de la card / noir) : corps **780 × 1326 px**, coins nets,
cran complet, liseré entier, **bloom 51 450 → 3 295 px (− 94 %)**, et ce qui
est exclu par rapport au durcir 0,55 = 8 957 px de lueur claire pour
6 704 sombres (la frange orange-sombre des pieds, pas du plastique).

⚠️ Ce N'EST PAS le re-détourage interdit par `bake_vignettes.py` : on ne
reconstruit pas une silhouette depuis la luminance d'un rendu sur fond noir —
on part de l'alpha livré (opaque), et on en RETIRE la lueur que l'auteur y a
laissée opaque. La règle reste : la lueur appartient à la scène.

`tools/sacre/bake_sachet.py` est à réécrire ainsi (v3). Portillon : bloom
< 5 000 px, bord ≤ 3 px, cran jusqu'à 1321, et la planche trois fonds sans
pied ni bloom.

## 10. LA MAIN v3 — « Apple, full dégradé blanc, un filament, le texte flouté »

La v2 (contour fin + lueur additive, 20 pt) lit comme un curseur. La v3 suit
ses mots à la lettre, dans la grammaire Apple des indices de geste :

- **La main** : `hand.point.up.fill` — PLEINE, 26 pt, remplie d'un **dégradé
  de blanc vertical** (blanc 1,00 en haut → blanc 0,74 en bas, une pointe de
  gris froid dans le bas pour le volume), une **ombre portée douce** (noir
  0,45, rayon 6, y 3) qui la décolle du sachet, et une inclinaison de −8°.
  Ni contour, ni lueur additive, ni blur sur elle : la matière fait le
  premium, pas l'effet.
- **Le filament** : une ligne blanche fine (1,5 pt) qui **glisse DERRIÈRE la
  main** pendant sa montée — elle part de la pulpe du doigt, s'allonge vers le
  bas jusqu'à ~56 pt, dégradé blanc 0 → 0,90 → 0 (ses deux bouts meurent),
  `plusLighter`, un blur de 0,6 pt. C'est la trace du glissement — **c'est
  elle qui dit « glisse »**, la main ne fait que montrer où. Elle se dissout
  vers le haut quand la main s'efface.
- **Le texte** : « **drag to open** » (ou « drag up to open », §11), en
  minuscules, `.inter(11, .medium)`, tracking 1,6, blanc 0,62 — et il **naît
  et meurt dans le flou**, le vocabulaire déjà codé du coffre (`ArriveeFloue`,
  CoffreV2:1159 : blur 9 → 0, 9 pt de montée, opacité) : il arrive avec la
  main (flou 9 → 0 sur 0,35 s), tient pendant le glissement, et **se dissout
  dans le flou** (0 → 9) quand elle part. Posé sous le sachet, à 272.
- **La boucle** (3,0 s) : 0 → 0,12 la main paraît (opacité + 4 pt de montée) et
  le texte sort du flou · 0,12 → 0,22 elle **touche** (elle s'enfonce de 6 %,
  un anneau fin de 1 pt s'ouvre 18 → 40 pt et meurt) · 0,22 → 0,62 elle
  **monte de 60 pt**, le filament s'allonge derrière · 0,62 → 0,76 elle
  s'efface, le filament se dissout par le haut · 0,76 → 0,92 le texte rentre
  dans le flou · 0,92 → 1 silence.
- Départ : le tiers bas du sachet (y = centre + 46), x + 26 (le croissant
  reste visible). Elle **s'éteint au premier contact** (déjà codé, `touche`),
  et le texte baisse à 0,30.

Coût : un blur de 0,6 sur 56 × 2 pt, et celui d'`ArriveeFloue` sur une ligne
de texte — rien qui ressemble à la loi des 27 img/s (un objet plein écran).

## 11. À TRANCHER (second tour)

1. **Le texte** : « drag to open » (recommandé — court, le verbe qu'elle a
   dit) / « drag up to open » (dit le sens) / garder « swipe up to open ».
2. **La main** : `hand.point.up.fill` (recommandé, la main Apple) /
   `hand.tap.fill` (l'index qui tape — plus « tap » que « drag »).
3. **Le filament** : blanc pur (recommandé) / blanc teinté de l'orange du
   sachet (il l'enlèverait au monochrome du parcours — non).

## 12. JALONS (second tour)

- **J0'** — `bake_sachet.py` v3 (§9) : la planche trois fonds sans pied.
- **J1'** — la main v3 + le texte flouté (§10), sur la v2 bâtie ; capture
  `-boosterPopup` + `cotes_booster.py` (la card se CALCULE, elle ne se
  détecte pas — le titre de la home traverse le scrim à 50/255).
- **J2'** — film de la boucle de la main (2 tours) + du commit ; `charge.sh`
  avant.
- **J3'** — son verdict.

---
---

# TROISIÈME TOUR — 30-08, 13 h : LE GESTE

Ses mots, le sim v5 sous le doigt : *« réduis la taille du booster, c'est
possible ? Au drag on voit le booster se DÉCHIRER, tu vois, et le halo de la
card derrière s'allume très fort ; et si j'arrête le drag, ça redescend ?? »*
Et sur la main : *« la petite main, pas assez premium ! »* (v3 : 26 pt, un
bout de doigt, un filament en barre — un curseur). **Rien de ce tour n'est
codé**, sauf la main v4 (§14, bâtie pour être jugée).

## 13. LA DÉCHIRURE AU DRAG — la card COMMENCE ce que le manège finit

### Ce qui existe : le manège sait déjà déchirer, et reprendre

`BoosterStage` (BoosterLab.swift, SceneKit) porte **tout** le geste : la
charge au maintien (`hold`, 0,18 s), le pan qui « convertit la charge en
découpe » (`adoptHoldIntoTear`), **LE GRAND RRRIP** (l. 424 : « la bande qui
cède — la déchirure accélère »), le **soupir** du sachet relâché sans
déchirure (l. 238 : « une détente douce »), son audio, et surtout
**`freezeTear(at: s)`** (l. 1301) : le manège sait se poser sur une
déchirure **entamée à s ∈ [0, 1]**. Refaire une déchirure 3D sur la card
serait la deuxième dans le même parcours, avec deux moteurs — non. La card
fait la **première seconde** du geste, en 2D, et **passe le relais** au manège
à la profondeur atteinte.

### Le geste sur la card, image par image

`prise` (la montée du doigt, freinée à 0,62 — déjà codée) devient la
**profondeur de déchirure** `d = prise / seuil` ∈ [0, 1] :

1. **Le sachet se déchire.** Le héros est cuit en **deux pièces** au bake
   (`bake_sachet.py` v4) : le **CAPUCHON** — le cran du haut + ~18 px de
   plastique — et le **CORPS**, séparés par une **ligne de déchirure en
   zigzag** (dents de 4-7 px, amplitude ±6 px, tirée d'un bruit
   DÉTERMINISTE : jamais un `random`, deux captures doivent être
   comparables). Les deux pièces se complètent au pixel ; le corps reçoit
   sur son bord déchiré un **liseré de plastique arraché** (1 px, blanc
   chaud 0,7) qui n'existe que là. Mesuré sur le héros : le cran du haut
   occupe les lignes 0 → ~40 (luma p90 152 → 60), le plastique noir suit
   (y 70 : p90 12) et le cadre néon commence vers y 90-130 — la ligne de
   déchirure vit à **y ≈ 62**, entre le cran et le cadre, là où un vrai
   sachet cède.
   Au drag : le capuchon **monte avec le doigt** (offset −prise, + une
   rotation de 3° × d qui bascule vers l'arrière) ; le corps reste, il
   **s'affaisse** de 2 pt × d. La fente s'ouvre.
2. **La lumière flambe.** Ce qu'elle décrit — « le halo derrière s'allume
   très fort » — devient la règle : la **lueur de scène** passe de 0,55 à
   **1,0** (et son rayon de 1,9 → 2,3 largeurs) sur d ; **de la fente sort
   une lumière** : une capsule blanc-orange (l'orange du set à 0,9, blanc au
   cœur) posée SUR la ligne de déchirure, large comme le corps, haute de
   2 + 10 d pt, floutée 6, en additif — la carte qui dort dedans respire ;
   et le **cône du spot** monte de 1,0 à 1,25. Trois lumières, une horloge.
3. **Les crans se sentent.** Tous les 12 pt de montée, un
   `.sensoryFeedback(.impact(weight: .light, intensity: 0.5))` — la
   grammaire des crans du slider (`lastCran`). Le sim ne vibre pas : verdict
   téléphone.
4. **Lâcher avant le seuil : ça redescend.** Oui — et c'est déjà le
   ressort du code (`response 0,34, damping 0,7`) : capuchon, corps, lueur,
   fente et cône rejoignent 0 **ensemble**, la fente se referme. Le chien de
   garde (0,6 s) fait pareil si le geste meurt. Rien ne reste entrouvert.
5. **Passer le seuil : le RRRIP.** À `d = 1` (64 pt) : `onOuvrir()` — mais
   plus l'envol du sachet entier (§2.3 v1, qui contredit une déchirure) :
   le **capuchon part** (0,32 s, +40 pt, il s'efface), le corps reste
   ouvert, la lumière tient, la card sort (0,30 s), et le manège s'ouvre
   **posé sur `freezeTear(at: 0,30)`** puis relâché dans le GRAND RRRIP —
   il continue le geste, il ne le recommence pas. ⚠️ À VÉRIFIER AVANT DE
   CODER : `freezeTear(at:)` est une prise de BANC (elle fige) ; il faut lui
   adjoindre une reprise — `reprendreDechirure(depuis: s)` = `freezeTear`
   puis l'animation du RRRIP à partir de s — dans `Coordinator`
   (BoosterLab.swift, l. 1301 et le RRRIP l. 424). Un `BoosterLab(appMode:
   true, dechirureDepart: 0.30)` porte la valeur. Si la reprise s'avère
   coûteuse dans ce moteur, le repli est honnête : le manège s'ouvre
   intact et son propre RRRIP joue — la card aura fait l'*annonce* du
   geste, pas sa moitié.

### Les cotes

- **Le sachet : 176 → 156 pt** (« réduis la taille du booster » — la
  seconde fois ; 200 → 176 → 156, −22 % en tout), centre à **140**. La
  bande de points, la légende (272) et l'encre ne bougent pas.
- Le seuil reste 64 pt de montée freinée (≈ 103 pt de course réelle) :
  assez pour sentir, pas assez pour lasser.

### Ce qui ne change pas

Un seul `DragGesture(minimumDistance: 0)` (tap OU montée décident à la
levée), la zone de toucher = le sachet + 12 pt, `SachetVivant` seul se
ré-évalue pendant le geste (la déchirure vit dedans), le chien de garde.

## 14. LA MAIN v4 — bâtie pour être jugée (déjà dans le sim)

Sur le film de la v3 (`vignettes/main-boucle.png`) : 26 pt, un fondu qui ne
laisse qu'un bout de doigt, un filament en BARRE posé à côté — un curseur.
La v4, codée et bâtie (`captures/main-v4-{0.18,0.45,0.62}.png`, phases
CLOUÉES par `-boosterMainPhase`, la seule façon de comparer deux robes) :

- la main des indices Apple : **40 pt**, pleine, blanche **jusqu'à la
  paume**, qui meurt au poignet (stops 1 · 1 à 45 % · 0) ; sous elle **sa
  lumière** — le même glyphe, blanc 0,32, flou 10, additif : ni ombre, ni
  bord, un halo ;
- une **COMÈTE** derrière, pas une barre : un halo de 10 pt flouté à 5 et un
  cœur de 2 pt, les deux en additif, qui s'allonge de 8 à 68 pt pendant la
  montée (64 pt, 0,22 → 0,62), pied ancré où elle a touché ;
- le **contact** : le disque doux d'Apple (blanc 0,16, flou 3, 22 → 52 pt)
  + son anneau fin ;
- départ au tiers bas du sachet (+ 18 pt à droite), le croissant reste
  visible.

### Ce que la relecture adverse de la v3 a trouvé, à corriger avec le §13

1. **`.animation(value: touche)` manque sur la légende** : au premier
   contact pendant sa naissance ou son silence, le texte CLAQUE de
   l'invisible au net (flou 9 → 0, opacité 0 → 1 dans la même image) alors
   que la main s'éteint en 0,28 s. Porter le 0,62 / 0,30 par `.opacity`
   (animable), pas par la couleur du `foregroundStyle`.
2. **Sous « Réduire les animations », l'affordance disparaît entièrement** :
   les deux horloges sont gelées à c ≈ 0 → main à 0, texte à 0. Rendre une
   main STATIQUE (`parait 1, monte 0`) et un texte net et fixe.
3. **Les horloges tournent après le contact sur du contenu invisible** :
   `paused: reduceMotion || touche` sur les deux `TimelineView` (le fondu de
   sortie vit sur l'opacité externe, il joue quand même), et **les rayons
   de flou retombent à 0 exact** quand l'objet est invisible (comète à
   opacité 0 pendant 55 % de la boucle, texte pendant son silence) — la loi
   d'`ArriveeFloue` : « sinon il coûte ce prix-là pour toujours ».
4. Les constantes du texte au diapason de la main : sortie du flou 0 → 0,12,
   retour 0,76 → 0,92 ; l'anneau et la comète ancrés sur la **pulpe** (x −5,
   après la rotation de −8°), pas sur la paume.

## 15. À TRANCHER (troisième tour)

1. **La déchirure sur la card** : la première seconde en 2D + relais au
   manège à 0,30 (recommandé — un seul geste, deux moteurs qui se passent
   le relais) / la card n'annonce que (capuchon qui se soulève, lumière), le
   manège déchire tout lui-même (le repli, sûr).
2. **La lumière de la fente** : blanc-orange (recommandé — c'est la carte
   qui dort) / blanc pur.
3. **Le sachet à 156** (recommandé) / 164.

## 16. JALONS (troisième tour)

- **J0''** — `bake_sachet.py` v4 : les deux pièces + la ligne en zigzag +
  le liseré arraché. Preuve : la planche capuchon / corps / réassemblés
  (au pixel), et le zigzag sur gris.
- **J1''** — `SachetVivant` : capuchon + corps, la fente qui s'ouvre sur
  `prise`, les trois lumières, les crans ; les 4 corrections du §14. Preuve :
  captures `-boosterPrise <pt>` (une prise CLOUÉE à 0 / 24 / 48 / 64 —
  comme `-boosterMainPhase`, on ne juge pas un geste au hasard).
- **J2''** — la reprise dans le manège (`reprendreDechirure`) — ou le repli
  tranché. Preuve : film card → RRRIP sans coupure ni double déchirure.
- **J3''** — film du geste complet (`filmer.sh`, `charge.sh` avant) : tirer,
  lâcher (ça redescend), tirer au bout (le RRRIP).
- **J4''** — son verdict, au téléphone (les crans ne vibrent pas au sim).

---

## 17. CE QUI A ÉTÉ FAIT (30-08, 13 h → 13 h 20) — le troisième tour, bâti

- **J0''** — `bake_sachet.py` cuit aussi `booster-hero-cap` et
  `booster-hero-corps` sur le canevas du héros : zigzag déterministe à
  y = 62 ± 8 (0,0465 de la hauteur), liseré arraché blanc chaud (14 px corps,
  6 px capuchon), **alpha réassemblé ≡ héros : OUI**. Planche
  `vignettes/sachet-dechirure.png`.
- **J1''** — `SachetVivant.dechirure(d:)` : corps qui s'affaisse (2 pt),
  fente lumineuse ENTRE les lèvres (blanc → orange, additif, 2 → 10 pt, flou
  4 → 0 au repos), capuchon qui **PÈLE à 0,35 × la prise** (mesuré à 1:1 sur
  `dechirure-prises.png` : il quittait le sachet dès 24 pt — une bande qui
  s'envole) + bascule 3D −14°·d, charnière sur la ligne ; lueur 0,55 → 1,0 et
  élargie ; crans haptiques tous les 12 pt (`.heavy` 0,9 — « haptique
  fort ») ; `CommitHaptic.play()` au commit ; sachet 156 / centre 140 ;
  `-boosterPrise <pt>` cloue la déchirure. Les 4 corrections de la relecture
  v3 (§14) sont faites. Verdict au doigt sur le sim : **« Trop stylé »**.
- **Main v5** (v11) : 34 pt `.light`, fondu dès 30 % ; « **D**rag to open »
  en dégradé de blanc (leading → trailing, 1 → 0,25) qui naît et meurt dans le
  flou. Planche `vignettes/main-v5-phases.png`.
- **J2''** — **LA REPRISE DANS LE MANÈGE, CODÉE ET PROUVÉE.** Le rapport de
  l'agent : `tearProgress` est UNE variable monotone poussée par `setTear`
  (BoosterPack.swift:1157) ; `freezeTear` n'est que `setTear + dim + poudre`
  — c'est `dim` et la poudre qui « figent » ; le pan reprend DÉJÀ depuis la
  valeur vivante (`tearStartProgress`, BoosterLab:2735 ; mapping absolu
  l. 2774) ; seuil du RRRIP `> 0,82` (l. 2842). Ajouts : `BoosterStage.
  dechirureDepart`, `Coordinator.reprendreDechirure(depuis:)` =
  `setTear(min(s, 0.75), sparking: false)` (plafond 0,75 : au-delà de 0,82 un
  tap ferait la cérémonie ; s = 0 no-op, sinon `tornGlow` s'allume),
  `BoosterLab.dechirureDepart`, WoopApp passe **0,30**. Preuve en cinématique
  (`vignettes/manege-reprise.png`) : le sachet arrive **déjà mordu** à 10,5 s,
  le RRRIP continue, la carte sort, le résultat se pose.
  ⚠️ Ce que la reprise change, à savoir : l'anneau du manège montre cinq
  clones INTACTS (la morsure n'apparaît qu'à l'engagement du sachet central),
  le retour à l'anneau se ferme après la morsure (`backOutGallery` exige
  `tearProgress == 0`), la charge au maintien est morte (même garde), le tell
  de rareté arrive toujours discret. Aucun n'est bloquant ; tous sont à juger
  au téléphone.
- **Le sim ment sur une chose** : les captures figées par `-boosterMainPhase`
  ont été prises pendant que Kathryn tirait sur le sachet — main éteinte,
  déchirure ouverte. Une planche se lit en sachant qui a le doigt sur le sim.

## 18. LA RELECTURE ADVERSE DU COMMIT fc473c9 — seize findings, un bloquant

Trois lentilles (manège, geste, lois) sur le diff commité. Corrigé dans le
commit suivant :

1. **BLOQUANT — `dechirureDepart: 0.30` était une CONSTANTE sur le seul
   manège de la racine** : toutes ses portes (pills lune ET noire du profil,
   coffre, bancs, et même le TAP sur la card qui n'a rien déchiré) recevaient
   un sachet mordu. → **la morsure est portée par l'état** :
   `SacreEtat.morsureCard: Float?`, écrite par le GLISSEMENT seul
   (`onOuvrir(Float?)`, nil sur un tap), lue par WoopApp
   (`dechirureDepart: sacre.morsureCard`), effacée dans `fermerManege()` et à
   `onCarteEnvolee`.
2. **Un trou de 0,32 s** entre la card partie et le manège : `ouvrirManege`
   lisait `popupOuverte` encore vrai et attendait la sortie d'une feuille
   déjà partie. → la racine baisse `popupOuverte` dans `onOuvrir` (0,06 s).
3. **Le commit claquait** : `prise = 0` à l'image même de l'envol — fente
   éteinte, lueur retombée, capuchon redescendu PENDANT qu'il part. → sur la
   branche seuil, `prise` reste au seuil ; c'est la sortie de la card qui
   éteint tout.
4. **Le chien de garde refermait le sachet SOUS un doigt immobile** (un
   `DragGesture` n'émet rien tant que le doigt ne bouge pas ; le cas exact du
   verdict « si j'arrête le drag, ça redescend ?? »). → plus de minuteur :
   `@GestureState doigtPose`, que SwiftUI remet à faux lui-même quand le
   geste finit OU meurt sans `onEnded` — c'est LE chien de garde juste.
5. **Cinq gardes `tearProgress == 0` mouraient** dans le manège dès que le
   sachet naissait mordu (retour à l'anneau, charge au maintien, invite,
   shiny leak, tell de rareté). → `morsureHeritee` dans le coordinateur,
   comparée à la place de 0 : « rien de plus que ce que la card a fait » =
   sachet intact du point de vue du manège.
6. La charnière du capuchon était 22 pt SOUS la lèvre (rotation posée après
   l'offset) → rotation d'abord. Deux haptiques au même tick du commit →
   une seule. La main cachée gardait quatre flous gelés → retirée, pas
   cachée. Deux tailles bougeaient par image (lueur, fente) → des transforms.
   `-boosterPrise` cloue vraiment (le geste est désactivé au banc).

Preuve de non-régression : `vignettes/manege-intact.png` — sans geste de card
(`-boosterManege -boosterCine`), le sachet arrive **intact** au manège.
