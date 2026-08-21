# LA HOME v2 — « LA CHAMBRE NOIRE »

Plan de refonte dicté le 2026-08-20. La v1 (aurore + carte obsidienne) est
**gelée et rejouable** : `tools/home-v1-archive/ARCHIVE.md`. La v2 vit à côté
d'elle (`-homeV2`) jusqu'à l'arbitrage final.

Le brief en une phrase : **une chambre noire, une seule lampe hors cadre à
gauche, une phrase d'Apple, cinq points, une lune noire au liseré de néon —
et tout le feu enfermé dans le verre.**

---

## 1. LA DOCTRINE (quatre lois, elles tranchent tous les micro-débats)

**LOI 1 — UNE SEULE SOURCE.** Il y a une lampe, elle est *hors cadre, en haut
à gauche*, et **tout** dans la page lui obéit : le rasant du fond, le liseré
de la lune (qui s'allume sur son arc GAUCHE), l'arête haute des cartes, le
dégradé de la phrase (blanc en haut, argent en bas). Rien ne brille de
lui-même. C'est ce qui fait la différence entre « une page avec des effets »
et **une pièce**.

**LOI 2 — LE NOIR EST LA MATIÈRE, PAS LE VIDE.** Cible mesurée : ≥ 78 % des
pixels sous L=24. Le halo actuel monte à L≈200 sur 40 % de l'écran ; le
nouveau plafonne à **L≈112** et meurt avant le tiers de la hauteur. Le luxe
n'est pas la quantité de lumière, c'est sa **rareté**.

**LOI 3 — LE FEU NE VIT QUE DANS LE VERRE.** Le fond ne brûle plus (« ou
background de feu, je sais plus où j'en suis » → tranché : **non**). L'orange
et le jaune n'existent qu'à trois endroits, et **un seul à la fois par
écran** : le liseré de la lune (permanent, minuscule), le sol qui s'allume
quand le menu s'ouvre (transitoire), l'objet en verre-braise du 3ᵉ screenshot
(un seul, le « Commencer »). Un fond de feu **et** du verre de feu : les deux
s'annulent, il ne reste qu'une page orange.

**LOI 4 — CHAQUE CHOSE SE DIT UNE FOIS.** La v1 dit trois fois la même
chose : « 1 / 5 entraînements », la rangée de trophées, et le titre de
section qui répète le sous-titre. La v2 : la phrase dit le compte **en
mots**, les cinq points le disent **en objets**, et plus rien d'autre. Zéro
titre de section, zéro sous-titre, zéro chiffre en double.

---

## 2. L'ANATOMIE, DE HAUT EN BAS (chiffres pour un écran de 402 pt)

### 2.1 Le rasant de la gauche (le fond)

- Source virtuelle à `(-40, 30)`, hors cadre. Champ : une ellipse anisotrope
  ~**560 × 300 pt**, décroissance plus rapide vers la droite que vers le bas
  (λx 0,42 / λy 0,58) — la lumière **rase** un mur, elle ne l'inonde pas.
- Sommet **L ≈ 112** (vs 200 en v1), plus rien au-delà de `y = 330`, plus
  rien au-delà de `x = 300`. Le coin haut-droit est **noir absolu** : c'est
  ce noir qui fait exister le liseré de la lune.
- Teinte : blanc-chaud, **pas** orange. `1,00 / 0,94 / 0,86` à 22 % — la
  braise (`1,00 / 0,62 / 0,24`) n'apparaît qu'en **queue** de dégradé, dans
  les 12 % du bas du halo, comme la chaleur résiduelle d'une lampe.
- Grain 0,26 (celui de la maison, `WoopGrain`) : sans lui, un dégradé aussi
  large fait de la bande sur OLED.
- Vie : deux respirations ±5 % sur périodes **37 s et 23 s** (premières entre
  elles, sinon elles battent ensemble et ça pulse), et **dérive gyro** de
  ±6 pt sur la source (`SkyMotion`, déjà amorcé par la scène).
- Étoiles : la passe `nebulaStars` reste, mais **inversée** — masquée du haut
  vers le bas à partir de `y = 0,52` (elle vit dans le noir, pas dans le
  halo). Densité réduite d'un tiers : la v1 en met assez pour lire « ciel »,
  la v2 veut « chambre ».

### 2.2 La phrase (le cœur de la page)

Départ à `y = 108` (56 pt d'air sous l'île — c'est cet air qui dit « Apple »),
gouttière gauche `x = 24`, largeur max **300 pt** (4 à 5 lignes : une phrase
qui respire tient sur des lignes COURTES).

Typo : `.inter(30, .semibold)`, tracking **−0,4**, interligne **1,14**
(`lineSpacing 4`). Alignement gauche, jamais justifié.

**La carte d'emphase** (la grammaire du 1ᵉʳ screenshot : clair / sourd
alterné, jamais deux blocs clairs collés) :

| Fragment | Ton |
|---|---|
| « Bonjour Kathryn, » | **clair** — `WoopGradient.silverText` (1,00 → 0,82 vertical) |
| « vous avez fait » | sourd — blanc 0,34 |
| « 4 entraînements » | **clair** |
| « cette semaine sur » | sourd |
| « 5 prévus. » | **clair** |

Le dégradé est **vertical et unique pour tout le bloc** (un seul masque, pas
un par mot) : les lignes du bas sont naturellement plus argentées que celles
du haut — c'est la lampe qui décroît, pas un effet de texte.

**Le blur-parallaxe, en deux temps :**

1. **À l'arrivée** — fragment par fragment, dans l'ordre de lecture :
   `blur 14 → 0`, `y +10 → 0`, `opacité 0 → 1`, 0,42 s chacun, décalés de
   **90 ms**. ⚠️ Ces rampes échelonnées **ne jouent pas** dans un
   `withAnimation` classique (piège déjà payé) : il faut une
   `struct PhraseVue: View, Animatable` dont `animatableData` porte `p`, et
   chaque fragment lit `p` avec son propre retard.
2. **Au scroll** — la phrase est sur un plan qui suit le scroll à **0,86**
   (elle traîne), et au-delà de 40 pt de course elle **se dissout dans la
   nuit** : `blur = min(6, (offset − 40) / 22)`, `opacité → 0,30`. Le mur
   monte, la phrase s'efface : on ne lit pas deux choses à la fois.

⚠️ Une **seule** sonde de scroll pour toute la page (`onScrollGeometryChange`
qui renvoie une constante ne rappelle plus jamais) : elle publie l'offset, la
phrase, le fond et le mur le lisent.

### 2.3 Les cinq points

À `phrase.bas + 26`, alignés sur la gouttière `x = 24`. Diamètre **9 pt**,
pas de **16 pt** (7 pt d'air : les points doivent se lire comme des objets
séparés, pas comme un tiret pointillé).

- **Fait** : disque rempli d'un dégradé vertical blanc `1,00 → 0,72`, plus un
  fil intérieur de 0,5 pt à 0,50 (c'est lui qui donne la *perle* plutôt que
  le rond plat).
- **À faire** : contour 1 pt blanc 0,16, remplissage 0,03 (pas transparent —
  un trou se lit comme un bug).
- Le **dernier fait** porte seul une buée de 3 pt à 0,10 et respire
  (0,92 ↔ 1,00 sur 4,7 s) : c'est « le plus récent », pas une décoration.
- Arrivée : remplissage de gauche à droite, **70 ms** d'écart, chacun en
  `scale 0,6 → 1,06 → 1,00` sur 120 ms. Le corps compte avec l'œil.
- Refusé : en faire de petites lentilles de verre. À 9 pt, un `liquidLens` ne
  rend rien de lisible et coûte une passe — le plat gagne.

### 2.4 La lune noire (haut-droite)

44 pt, à `x = 334`, **alignée sur la première ligne** de la phrase (même
hauteur d'œil). Elle reste la porte du trésor (`CoffreFortCoinButton`
retravaillé, la fumée `CoinSmoke` conservée).

- **Corps** : noir pur `#000`. Pas d'obsidienne, pas de reflet, pas de galet.
- **Le fil net** : 1,0 pt, blanc 0,92, **d'intensité variable le long du
  cercle** — maximum sur l'arc gauche-haut (face à la lampe), éteint à 20 %
  sur l'arc droit-bas. C'est *ça* qui fait cher : un anneau d'intensité
  constante est un pictogramme, un anneau qui obéit à la lumière est un
  bijou.
- **La braise** : buée extérieure de 7 pt, `1,00 / 0,62 / 0,24` à 0,35, en
  `.screen`, décalée de 1,5 pt vers la lampe. Portée courte — au-delà de
  10 pt, ça devient du néon de bar.
- **Le croissant** : `GlypheLune` (les 18 cubiques du logo) posé DANS le
  disque, en noir sur noir, révélé seulement par un liseré de 0,5 pt sur son
  arête haut-gauche. On ne le voit pas, on le **devine** — et c'est la
  signature de l'app.
- Vie : le point le plus brillant du fil dérive de 8° sur 11 s. Au toucher :
  le fil monte au blanc pur en 90 ms puis retombe en 400 ms, la fumée part
  (déjà en place), la page du trésor s'ouvre 0,34 s après (déjà en place).

### 2.5 Le mur des séances

Départ à `y ≈ 330` (le mur naît là où la lumière meurt). Pas de titre de
section (loi 4) — seulement, 14 pt au-dessus de la première carte, un
sur-titre `11 pt`, majuscules, tracking 2,4, blanc **0,38** : `SÉANCES`.
Et sous lui un filet de 1 pt en dégradé, de `x = 24` à `x = 180`, qui meurt
dans le noir (le seul trait de toute la page — il tient le mur).

**La carte** : `354 × 200`, rayon **30** continu, noir. Contenu :
- le **sticker** (le vrai objet du calendrier, `sticker-*.imageset`) à
  droite, 68 pt, avec son ombre portée courte — c'est le seul élément coloré
  de la carte, et il suffit ;
- la date en sur-titre 11 pt blanc 0,40, le titre **22 pt semibold** en
  `silverText`, et en pied deux mesures (durée / exercices) en 13 pt 0,52 ;
- la **matière** : noir mat + une seule arête de lumière **en haut à gauche**
  (loi 1), 1 pt à 0,10 qui s'éteint au tiers du bord. Pas de tube néon, pas
  de halo d'or, pas de reflet au sol (les 12 rendus par image du reflet des
  cards du manège viennent d'être tués pour du lag — on ne les rachète pas).
- 16 pt entre deux cartes. Elles **respirent** : échelle 1,000 ↔ 1,006 sur
  une période propre à chacune (13 s + index × 1,7 s), amplitude sous le
  seuil de conscience — on ne voit rien bouger, la page est juste *vivante*.

**La mécanique** — trois candidates, arbitrage à rendre (§ 7) :

> **A. LA LAMPE (recommandée).** La lampe de la page **descend dans le mur**.
> Le mur est dans le noir : chaque carte n'est lisible que quand la lumière
> passe dessus. Le drag vertical déplace la lampe (ou le scroll la déplace,
> couplée comme la molette de l'iPod l'est au manège : `posLampe = index +
> cran / pas`), et elle **s'aimante** à la carte la plus proche au lâcher.
> Sous la lumière : carte à 100 %. Voisines : 30 %, sticker seul visible.
> Loin : silhouette noire et une lueur de sticker. *Lire, c'est éclairer.*
> C'est nouveau, c'est exactement la doctrine de la page (une seule source,
> et elle est **manipulable**), et ça réutilise tout le savoir-faire maison
> (un champ de lumière dans un shader). Plancher de lisibilité obligatoire :
> une carte ne descend jamais sous 0,30 sur son sticker et son titre —
> sinon c'est joli et inutilisable.
>
> **B. L'ACCORDÉON MAGNÉTIQUE.** Pile verticale de dalles épaisses : le
> scroll ne translate pas, il **respire**. La carte au point focal se
> déplie à 200 pt, les autres se compriment à une tranche de 44 pt où ne
> restent que le sticker et la date. Aimanté (on atterrit toujours sur une
> carte). Grammaire Wallet — très Apple, zéro risque, moins de « jamais vu ».
>
> **C. LE MUR DE STICKERS.** Au repos, **pas de cartes du tout** : les
> stickers seuls, posés sur le noir comme des objets, avec leurs ombres. Le
> tap fait **naître** la carte depuis le sticker (le sticker devient son
> sceau). La collection est un mur d'objets, plus une liste. Le plus radical,
> le moins lisible en un coup d'œil.

**TRANCHÉ (20-08) : A, avec l'aimant de B.** Le drag déplace la lampe *et*
la lampe se cale sur une carte au lâcher — les deux idées se marient, et on
garde l'ergonomie. B et C sont écartées, pas perdues : elles restent des
plans B si le banc `-murLampe` ne vend pas la lampe au téléphone.

**Loi de perf, non négociable** : **UNE seule passe Metal pour tout le mur**
(un rectangle hôte, le champ de lumière + les SDF des cartes dedans), les
textes en SwiftUI par-dessus avec leur opacité pilotée. Six cartes × un
shader chacune = le lag qu'on vient de payer sur le manège. 30 Hz au repos,
60 Hz seulement sous le doigt.

### 2.6 Le galet unique et le sol qui s'allume

**Plus de barre.** Un seul bouton, **verre liquide natif**, centré, 62 pt,
posé 24 pt au-dessus de l'indicateur.

- `Color.clear.glassEffect(.clear.interactive(), in: .circle)` — `.regular`
  est **interdit** (loi payée au témoin-carte), et le `.clear` natif
  **givre** ce qui est net : le glyphe maison (22 pt, blanc 0,95) est donc
  posé **au-dessus** du verre, jamais dedans.
- En séance, le glyphe devient l'**anneau de néon** (la loi du galet
  `running` survit à la mort de la barre), et l'appui tenu ouvre toujours
  « Terminer la séance ? ».

**Au tap : LE SOL S'ALLUME** (4ᵉ screenshot). Le concept : la lampe de la
pièce **descend au sol** le temps du menu — c'est le même luminaire, il a
changé de place. Donc, pendant que la nappe monte, le rasant du haut
**baisse à 35 %** : une seule source, toujours.

- La nappe : les **46 %** bas de l'écran. Cœur jaune `1,00 / 0,86 / 0,42` en
  bas à gauche (la lampe garde son côté), orange `1,00 / 0,54 / 0,20` au
  milieu, une pointe de blanc là où c'est le plus chaud, et rien de net :
  tout est **derrière** un verre.
- Le flou **progressif** (fort en bas, nul en haut) : `.blur` en est
  incapable — il pose un voile uniforme sur tout le rectangle de son hôte
  (piège payé). Deux routes : (a) verre natif `.clear` sur un rectangle
  arrondi + la nappe peinte en Metal **dessous** — natif, sobre, immédiat ;
  (b) la page rasterisée une fois (`ImageRenderer`) puis re-échantillonnée
  dans une passe Metal avec un **rayon en rampe** — c'est le vrai rendu du
  screenshot. **On livre (a) au jalon, on fouette (b) si (a) ne vend pas.**
- ⚠️ La feuille doit avoir une **taille constante** et être révélée par un
  clip/masque animé : un `glassEffect` dont les bounds changent image par
  image reste flou plat pour toujours (piège payé).
- La liste : 26 pt semibold blanc, gouttière `x = 32`, 22 pt entre les
  items, arrivée décalée de **55 ms** du bas vers le haut (`blur 10 → 0`,
  `y +14 → 0`). Ordre : **Commencer une séance** (l'item lumineux), puis
  Entraînements · Exercices · Progrès · Profil · Trésor.
- Le bouton **devient** la feuille : `GlassEffectContainer` + morphisme natif
  (le cercle s'étire en capsule, la capsule devient la poignée), le glyphe
  maison passe en chevron bas par fondu croisé. Sortie : tap dehors, drag bas
  > 60 pt, ou choix d'un item.
- Haptiques : ouverture = un `.impact(.soft)` au décollement du verre ;
  chaque item survolé = un grain léger ; le choix = le coup lourd
  (`SwapFeedback.slam()` existe déjà).

---

## 3. LES TROIS VERRES (le « maximise le liquid glass », avec sa loi)

Maximiser le verre **sans** le rendre laiteux : la maison a déjà payé la
règle, on l'applique.

| Verre | Où il a le droit d'exister | Interdit |
|---|---|---|
| **Natif `.clear`** | le galet maison, la nappe du menu, les chips | tout ce qui a du **texte net derrière** (il le givre) |
| **Maison (`liquidLens`)** | un bord de carte, une loupe sur du contenu **net** | les grandes surfaces (une passe par hôte) |
| **Verre de feu** (3ᵉ screenshot) | **UN seul objet par écran** : le « Commencer » | tout le reste — c'est un accent, pas une matière de page |

`.regular` : **jamais**. Nappe spéculaire > 0,5 : **jamais** (ça frost).

Le **verre de feu** en détail : une capsule 322 × 54, verre natif `.clear`,
et **dans** son épaisseur un dégradé de braise (rouge sombre en haut → ambre
→ jaune blanc en bas) qui coule vers le bas comme une goutte, plus un
liseré chaud de 0,5 pt sur son arête haute. Texte au-dessus du verre, en
blanc. C'est l'objet le plus cher de l'app : il n'apparaît qu'une fois.

---

## 4. LA CHORÉGRAPHIE

**Arrivée (2,0 s au total).** La lumière d'abord, le contenu ensuite — la loi
maison. `0,00` : noir. `0,10` : le rasant monte (easeOut 0,80 s). `0,45` : la
phrase, fragment par fragment (90 ms). `1,05` : les cinq points (70 ms).
`1,25` : le sur-titre et son filet. `1,35` : le mur, cartes du bas vers le
haut (blur 8 → 0, y +18 → 0, 60 ms d'écart). `1,80` : le galet monte du bas
en ressort. Rien n'arrive en même temps, jamais.

**Parallaxe au scroll** (une sonde, quatre plans) : fond **0,04**, phrase
**0,86** (+ dissolution), points **0,90**, mur **1,00**. La lune reste
accrochée en haut (elle ne défile pas — c'est un objet de la pièce, pas du
document).

**Respirations** (périodes premières entre elles, sinon tout bat ensemble) :
fond 37 s / 23 s · lune 11 s · dernier point 4,7 s · cartes 13 s + 1,7 s ×
index.

**Reduce Motion** : parallaxe et dérives à zéro, la lampe du mur éclaire tout
à 100 %, les arrivées deviennent des fondus de 0,25 s.

---

## 5. CE QUI MEURT, CE QUI DÉMÉNAGE

| Pièce | Sort |
|---|---|
| L'aurore plein haut (`bgAuroraHome` sur la home) | **remplacée** par le rasant `nuitRasant` — le shader reste (la page de connexion s'en sert) |
| La carte obsidienne + `TrophyRow` | **archivées** (`tools/home-v1-archive/`) — vivantes au banc `-obsidianLab`, hors de la home |
| Le double titre « Derniers entraînements » / « Ta collection » | **mort** (loi 4) |
| `JewelTabBar` sur la home | **retirée** — le composant et son banc `-navLab` restent |
| Le galet play central | **déménage** dans le menu (arbitrage § 7) |
| Le bouton d'essai booster (`SachetVignette`) | **mort** sur la home v2 |
| `CarnetHome` (le carnet de cuir) | **quitte la home** ; reste au banc `-carnetLab`, à replacer (page Entraînements ?) |
| Les étoiles `nebulaStars` | **gardées, inversées** (dans le noir du haut-droit et du bas) |
| La lune-coffre | **gardée**, refondue (§ 2.4) |

---

## 6. L'ARCHITECTURE ET LES PIÈGES

**Fichiers neufs** (la v1 n'est pas touchée) :
- `Woop/Views/HomeNuit.swift` — la page, la phrase, les points, le mur.
- `Woop/Views/GaletMaison.swift` — le bouton verre + le menu du sol.
- `Woop/HomeNuit.metal` — deux entrées : `nuitRasant` (le rasant, ~50 lignes)
  et `murLampe` (le champ de lumière du mur, une passe pour tout le mur).
- La nappe du menu : réutiliser `HaloDawn.metal` (le fond `-haloLab`) plutôt
  que d'écrire un troisième dégradé de braise.

**Bancs** : `-homeV2` (la page), `-phraseLab` (4 curseurs : blur, retard,
niveau sourd, tracking), `-murLampe` (le mur seul, lampe au doigt),
`-homeV2Menu` (le menu déjà ouvert), `-verreFeu` (la capsule braise).
Chaque banc s'ouvre **tout seul** : le simulateur ne sait pas poser un doigt.

**Nav** : `RootView` garde son `TabView` (l'état et les piles), le
`safeAreaInset` perd `JewelTabBar` ; le galet et son menu sont un **overlay à
la racine** (au-dessus du `TabView`) — la nappe doit pouvoir couvrir
n'importe quelle page, et le bouton devra exister partout.

**Les pièges déjà payés qui s'appliquent ici** (chacun a coûté des heures) :
1. `.blur` = voile **uniforme** sur tout le rectangle de l'hôte → la nappe
   progressive est du Metal ou du verre natif, jamais un `.blur`.
2. Les rampes échelonnées sur un `p` sous `withAnimation` ne jouent qu'au
   doigt → `struct View, Animatable` pour la phrase et le menu.
3. `.regular` interdit ; `.clear` givre le net → glyphes et textes **au-dessus**
   du verre.
4. `glassEffect` aux bounds vivants = flou plat définitif → taille constante,
   révélation par clip.
5. Une seule sonde par scroll (une sonde qui rend une constante ne rappelle
   plus jamais).
6. `xcodebuild | grep` rend le code de sortie de **grep** → vérifier le `stat`
   de `Woop.debug.dylib` avant **toute** capture.
7. Arité d'un stitchable changée sans l'appel Swift = **page blanche**, sans
   une erreur de compilation.
8. `ScrollView` décalé sous le bord + overlay `ignoresSafeArea` = ping-pong
   d'insets qui fait respirer toute la page.

---

## 7. LES JALONS (un commit, un banc, un verdict téléphone chacun)

| # | Ce qu'on juge | Livrable |
|---|---|---|
| **J0** | *fait* — l'archive de la v1 | `tools/home-v1-archive/` |
| **J1** | ✅ *livré (non commité)* — **la lumière** : le noir, le rasant de gauche, rien d'autre | `-homeV2` + `nuitRasant` |
| **J2** | ✅ *livré (non commité)* — **la phrase** : typo, carte d'emphase, arrivée fragment par fragment, dissolution au scroll | `-phraseLab` |
| **J3** | **les points + la lune** : la jauge, le fil qui n'existe qu'à gauche, la braise courte | dans `-homeV2` |
| **J4** | **le mur** : la mécanique tranchée, une passe Metal, les stickers, l'aimant | `-murLampe` |
| **J5** | **le galet + le sol** : verre natif, morphisme, nappe de feu, la liste, les haptiques | `-homeV2Menu` |
| **J6** | **le verre de feu** : la capsule braise du « Commencer » | `-verreFeu` |
| **J7** | **le verdict téléphone** + la cadence (`SondeCadence`) + l'arbitrage v1/v2 | — |

---

## 7 bis. JALON 1 — LIVRÉ LE 2026-08-20 (non commité)

`Woop/HomeNuit.metal` (`nuitRasant`) + `Woop/Views/HomeNuit.swift`
(`RasantParams`, `HomeNuitFond`, `HomeNuitLab`), câblés sur `-homeV2` dans
`RootView`. Sonde : `tools/home-v2/mesure_rasant.py`. Captures :
`tools/home-v2/shots/`.

**Les constantes retenues** (fouettées contre la sonde, pas devinées) :
lampe (−0,10 ; 0,060) hors cadre · rayons 1,10 le long / 0,62 en travers ·
axe **32°** · sommet **0,62** · extinction **2,1** · braise **1,0** ·
air 0,07 · souffle 1,0 (±5 % sur 37 s et 23 s) · voile **0** · étoiles **0** ·
**cœur blanc 0,18 (rayon 0,20)** · **flanc orangé 0,72 (hauteur 0,46)** ·
genou de compression à 0,80.
Palette : chaud (1,00 / 0,92 / 0,82) · braise (1,00 / 0,62 / 0,24) ·
orange du flanc (1,00 / 0,52 / 0,16) · blanc du filament (1,00 / 0,985 / 0,96).

**Les cibles, mesurées sur `-isoRasant -rasantFreeze 100` :**

| Cible | Mesuré (état livré) |
|---|---|
| sommet L ≈ 112 | **141** — assumé : verdict « plus de blanc » (le filament) |
| ≥ 78 % des pixels sous L = 24 | **90,0 %** |
| extinction en x ≤ 300 pt | **240 pt** |
| extinction en y ≤ 330 pt | **379 pt** — la coulée orangée descend plus bas, mais à L ≤ 10 (une carte du mur la couvre ; à revoir au J4 si elle gêne la lampe du mur) |
| coin haut-droit ≤ L 4 | **2,1** |
| zéro écrêtage | **0 pixel** (garanti par le genou, pas par le réglage) |
| saturation qui MONTE quand L tombe | 0,55 → 0,63 → 0,68 → 0,74 → **0,79** |

**Les trois défauts payés en route** (et leur leçon) :
1. **La sonde mesurait l'heure.** Sommet annoncé 108 quand le champ plafonnait
   à 78 : les glyphes blancs de la barre de statut tombent en plein dans la
   zone la plus claire du rasant. → `-isoRasant` cache la barre, et la sonde
   mesure tout le cadre au lieu d'en couper le haut.
2. **`mix` entre deux teintes fabrique du brun.** Le chemin droit entre le
   blanc-chaud et la braise passe par un orange désaturé : sat 0,23 à L 35-60
   quand les tranches voisines tenaient 0,42 et 0,50 — une plaque brune,
   visible à l'œil. → la loi de couleur s'écrit **en canaux** (on éteint le
   bleu puis le vert quand la lumière tombe), jamais en interpolation.
3. **Le masque radial des étoiles les envoyait dans le coin haut-droit**
   (L max 51 pour une cible de 4) — soit exactement l'écrin du liseré de la
   lune. → elles ne vivent plus que dans le tiers bas, et par défaut **elles
   ne vivent pas** : une chambre n'a pas de ciel.

**Deux contraintes NÉES de ce jalon, à honorer au J2 :**
- **L'axe est rentré à 32°** pour que la lumière meure AVANT le mur : le mur
  doit être noir, puisque c'est sa propre lampe (le drag) qui l'éclairera.
  La flaque couvre la zone de la phrase, et rien de plus.
- **Le « sourd » de la phrase ne peut pas être une constante.** Mesuré
  derrière la première ligne : le fond monte à L ≈ 55 côté gauche. Un
  fragment à blanc 0,34 (L ≈ 87) n'y garde qu'un rapport de 1,6:1 — illisible.
  Le sourd doit donc **suivre la lumière** (0,34 dans le noir → ~0,48 dans la
  flaque). C'est une contrainte de lisibilité, et ça tombe juste : la phrase
  obéit à la lampe comme tout le reste (loi 1).

## 7 ter. JALON 2 — LIVRÉ LE 2026-08-20 (non commité)

`PhraseFragment` / `PhraseTexte` / `PhraseParams` / `PhraseVue` /
`HomeNuitPage` dans `Woop/Views/HomeNuit.swift`. Bancs : `-phraseLab` (console,
onglet phrase), `-phraseFige <p>` (l'arrivée figée), `-phraseRejoue` (elle se
rejoue toutes les 3,4 s), `-phraseScroll <pt>` (la course figée).
Capture : `tools/home-v2/shots/j2-phrase.jpg`,
`shots/j2-arrivee-et-dissolution.jpg`.

**La forme retenue.** Cinq fragments, un par ligne, tons alternés :
« Bonjour Kathryn, » *clair* · « vous avez fait » *sourd* ·
« 4 entraînements » *clair* · « cette semaine » *sourd* ·
« sur 5 prévus. » *clair*. Inter 30 semibold, tracking −0,4, interligne 2
(1,27 apparent), largeur 300, gouttière 24, **56 pt sous la barre**.
Un SEUL dégradé (blanc → 0,86) pour tout le bloc.
Arrivée : flou 14 → 0 + montée 10 pt, 0,42 s par fragment, **90 ms** d'écart.
Scroll : plan à 0,86, flou jusqu'à 6 et opacité jusqu'à 0,30 passé 40 pt.

**Pourquoi une ligne = un fragment (et pas un mot).** SwiftUI ne sait ni
flouter ni décaler un *run* dans un paragraphe qui se replie : la
concaténation de `Text` porte des couleurs, pas des effets. Le découpage
manuel en lignes rend les deux — contrôle typographique exact ET animation par
fragment. C'est d'ailleurs ce que fait la référence : ses retours à la ligne
tombent sur ses fragments.

**Trois choses payées en route :**
1. **`ignoresSafeArea` rend les insets à ZÉRO.** Un `GeometryReader` sous ce
   modificateur annonce `safeAreaInsets.top = 0` : le bloc, calé à
   « inset + 48 », remontait se coller à l'île. La page tient un seul repère,
   celui de l'ÉCRAN (le shader peint hors safe area) — donc le
   `GeometryReader` ne l'ignore PAS, et c'est le `ScrollView` qui ignore le
   haut, avec le décalage ajouté à la main.
2. **Le sourd de 0,34 ne passait pas.** Mesuré : 2,9:1 sur « cette semaine »,
   sous le plancher de 3:1 du grand texte. Et la référence Apple est bien plus
   claire qu'elle n'en a l'air (ses mots sourds sont à rgb(128), soit 0,50).
   Retenu : **0,42 dans le noir, 0,54 dans la flaque** → 3,8:1 et 4,6:1. Le
   contraste et le goût tiraient du même côté.
3. **`zsh` ne découpe pas `$V`.** Quatre captures de bancs lancées par une
   boucle `set -- $V` étaient en fait quatre fois le même lancement, arguments
   perdus — et elles « prouvaient » que `-phraseFige` ne marchait pas. Les
   arguments de banc se passent en appels explicites.

## 7 quater. LE TOUR DE VERDICTS DU 20-08 (« plus de blanc, plus d'orange, une arrivée plus cinématique »)

**1. « Plus de blanc » → LE FILAMENT.** Monter l'amplitude était le mauvais
levier (ça agrandit la flaque : c'est le rendu 0,84, écarté au banc). Un
second lobe serré, en blanc presque neutre, blanchit le CENTRE sans grossir
le halo. ⚠️ **Premier essai invisible** : centré sur la lampe — donc hors
cadre, contribution mesurée **+0,001** sur le pixel le plus clair. Tout lobe
qui doit se voir se place DANS le cadre : celui-ci vit sur l'axe du faisceau,
à 0,22 largeur d'écran de la lampe (il reste solidaire d'elle au banc).

**2. « Encore plus d'orange » → LA COULÉE DU FLANC**, plus une rampe de teinte
élargie. Deux choses ont été comprises en le faisant :
- **L'orange doit vivre où il y a du NIVEAU.** Réservé à la queue du dégradé
  (rampe 0,04 → 0,50), il était mathématiquement là et visuellement nulle
  part : la queue est trop sombre pour porter une couleur. Rampe élargie à
  **0,08 → 0,78** : l'ambre prend les demi-teintes, et se voit.
- **La coulée est un lobe SÉPARÉ, en lumière ajoutée** (orange 1,00/0,52/0,16),
  étroit et long (0,32 × 0,62), collé au bord gauche, son cœur à y = 185 pt —
  **sous** le filament. Versée dans le champ principal, elle réchauffait tout
  le halo et l'orange ne se voyait nulle part ; ronde, elle se lisait comme un
  second foyer, et la page n'a qu'une source.
- Résultat mesuré sur le bord gauche : rgb(168, 99, 42) à y = 140, rgb(168,
  91, 30) à y = 180 — **saturation 0,75-0,82 à L ≈ 105**. Avant : sat 0,45 à
  L 40, c'est-à-dire du brun invisible.

**3. LE GENOU (0,80).** Trois foyers qui s'additionnent finissent par écrêter :
mesuré, 2 853 pixels à 255 dans le rouge — et un écrêtage ne se lit pas comme
« très lumineux », il se lit comme une TACHE plate au bord dur. Au-delà de
0,80 la montée devient exponentielle décroissante : la limite est
asymptotique, **aucun réglage de curseur ne peut plus la franchir**.

**4. L'ARRIVÉE CINÉMATIQUE** (« pas assez Apple »). Les premiers chiffres
faisaient une apparition propre mais pressée. Ce qui la rend cinématique n'est
pas *plus de flou*, c'est **une chose de plus qui bouge, et du temps** :
- La PIÈCE s'allume avant les mots : easeOut sur **1,15 s**, et en trois
  gestes simultanés — la lampe **entre** par la gauche (0,24 largeur d'écran
  de course), son niveau monte (12 % → 100 %), et sa flaque **se fait**
  (extinction 1,25 → 2,1, rayons ×1,32 → ×1). Ce dernier geste est la mise au
  point — faite **dans le shader**, jamais au `.blur` : un flou plein écran
  animé coûterait une passe hors écran par image.
- Le filament et la coulée n'arrivent qu'après 45 % de la course : ce sont les
  DÉTAILS de la lampe, ils se posent quand elle est en place.
- La phrase part **0,38 s** après la lumière : flou **30** → 0, montée 22 pt,
  échelle **1,05 → 1,00** (le fragment ne monte pas, il s'APPROCHE — c'est le
  couple flou + échelle qui fait la mise au point, jamais le flou seul),
  0,90 s par fragment, **140 ms** d'écart. Total ≈ **1,9 s**.
- Bancs : `-arriveeFige <s>` reconstitue toute la cinématique à un instant
  (lumière comprise), `-phraseRejoue` la joue en boucle.
  Capture : `shots/j2-arrivee-cinematique.jpg`.

**5. `-isoRasant` n'isolait que le FOND.** La phrase restait dessus, et la
sonde mesurait son blanc : sommet annoncé 254, « écrêtage » de 2 359 pixels
situés… sur la première ligne de texte. Le drapeau d'attribution vit
maintenant sur `RasantHorloge` et éteint aussi le contenu : « seul » se décide
à l'échelle de la page. (Deuxième fois que ce piège se paie sur ce jalon,
après la barre de statut — une sonde de sommet mesure toujours le pixel le
plus clair, et le texte blanc l'est toujours.)

## 7 quinquies. LE GALET DE L'OBJECTIF (20-08) — et LA loi du verre natif

**Ce que c'est.** Le chiffre de la phrase n'est plus un chiffre : c'est un
galet de verre liquide NATIF, posé sur la ligne d'écriture. On le touche, un
panneau de verre descend et propose **3 à 7** — et les deux corps de verre
n'en font qu'UN, tenus par un petit **tuyau** liquide. Le choix roule dans le
galet (`contentTransition(.numericText)`), est gardé en `@AppStorage`
(`Goal.cleHebdo`, avec `Goal.hebdo` comme nouvelle source de vérité) et se
sent (impact souple à l'ouverture, sélection au choix).
Captures : `shots/j2-galet-tuyau.jpg`, `shots/j2-galet-objectif-ouvert.jpg`.

**LA LOI, et elle vaut pour toute l'app :**

> **L'encre doit être au-dessus du CONTENEUR de verre, pas seulement au-dessus
> du verre.** Une `Text` posée en `overlay` À L'INTÉRIEUR d'un
> `GlassEffectContainer` devient du contenu que le conteneur LENTILLE : le
> chiffre du galet se lisait comme un TROU dans du métal (bille de chrome au
> zoom), et les chiffres du panneau sortaient givrés, doublés de fantômes
> ondulés. Hors du conteneur, le même verre natif est **magnifique** et
> l'encre est nette.

C'est ce qui a coûté le détour de ce jalon : j'ai d'abord accusé la MATIÈRE
(« le verre natif ne tient pas à 48 pt sur du noir ») et taillé un galet à la
main — verdict de Kathryn, sans appel : « blur, nul à chier », le verre natif
d'avant était magnifique. Le défaut n'était pas la matière, c'était la
hiérarchie des calques. La leçon générale : **avant d'accuser un matériau,
vérifier ce qu'on a mis dedans.**

**La géométrie du tuyau**, mesurée en trois essais :
- `glassEffectUnion(id:namespace:)` : **retiré**. Avec un seul membre présent
  (panneau fermé) il étale le verre sur tout le cadre du conteneur — le galet
  devenait une dalle qui recouvrait « prévus. ».
- C'est le `spacing` du `GlassEffectContainer` qui soude : **40**, pour un
  écart de **18 pt** entre les deux formes. À 14 pt d'écart pour 26 de
  spacing, rien ne fusionne (deux corps séparés) ; à 6 pt pour 40, la
  jonction est aussi LARGE que le galet (une équerre, plus une pastille) ;
  à 18 pt pour 40, le col se pince — **la pastille reste une pastille, et un
  petit tuyau tient le panneau.**
- Le panneau PEND du galet par son bord gauche (`offset x = −8`) : centré, il
  sortait de l'écran (le galet est à x ≈ 79 pt, le panneau en fait 244).
  C'est aussi la grammaire des menus d'Apple.
- Il s'ouvre VERS LE BAS : à l'aplomb du galet, il recouvrait « prévus. » et
  le verre en réfractait le fantôme à l'envers.
- Le galet **ne disparaît pas** à l'ouverture (le morphisme `glassEffectID`
  l'avait fait d'abord) : un mot de la phrase ne peut pas s'absenter, la
  phrase se retrouvait avec « sur ⬚ prévus. ».

**Deux pièges de plus, payés ici :**
- **`onAppear` rejoue.** Le banc `-galetChoisit 7` a pris le défaut en flagrant
  délit : le panneau se rouvrait tout seul huit secondes plus tard, parce que
  le changement d'`@AppStorage` remonte le sous-arbre. Sans verrou, c'est la
  CINÉMATIQUE D'ARRIVÉE entière qui rejouerait en pleine page (la leçon de
  l'aube de la v1, payée une troisième fois). Un `@State deja` garde la porte.
- **Kathryn travaille sur le simulateur pendant que je capture.** Deux de mes
  captures « du galet » étaient en fait SA page iPod du mois, et j'en ai tiré
  un faux diagnostic. Les captures qui comptent se font sur un **second
  simulateur** (iPhone 17 Pro `D8A31930…`), éteint après usage.

### Le combustible : pourquoi le verre natif « ne montrait rien »

Verdict de Kathryn après le premier tour : la toute première itération était
« un verre magnifique et brillant, clair », et l'état corrigé « on voit rien,
ça fait blur, pas premium ». Les deux sont vrais, et la mesure explique
pourquoi — surface du galet (tout sauf l'encre), même endroit, même lumière :

| état | surface moy. | surface p95 | le « 5 » |
|---|---|---|---|
| 1. natif, encre DANS le conteneur | 50 | **186** | illisible (nœud d'argent) |
| 3. taillé à la main | 14 | 35 | net |
| 4. natif, encre HORS du conteneur | 12 | **23** | net |

**Le verre natif ne montre que ce qu'il réfracte.** Dans l'itération 1, ce
qu'il réfractait était le chiffre blanc lui-même (227 de blanc pur, enfermé
dans le conteneur, étalé par la lentille sur toute la surface) : d'où le verre
brillant — et l'illisibilité, qui en était l'autre face. En sortant l'encre du
conteneur, on lui a retiré sa seule source : il ne restait que du noir à
courber. **Ce n'était pas un flou, c'était un verre à jeun.**

La réponse n'est donc ni « natif » ni « taillé », c'est : **qu'est-ce qu'on
donne à manger au verre.** Pas un glyphe — de la lumière douce. Trois essais
mesurés pour la placer :

| place du foyer | surface p95 | ce qu'on apprend |
|---|---|---|
| centré, cadre 1,5× débordant | 60 | ce qui monte éclaire le MILIEU : le chiffre y perd son fond noir |
| **dehors**, au-delà du coin | 34 | **la lentille ne montre que ce qui est SOUS elle** — nourrir par l'extérieur ne nourrit rien |
| sous le galet, calé sur son coin haut-gauche | **120** | l'arête brille, le cœur reste sombre — le contraste de l'itération 1 sans son défaut |

État retenu : `combustible 1,05` · `liseré 0,45` · `scintille 0,55`, ambre du
combustible **pâli** à (1,00 / 0,92 / 0,83) — à (1,00 / 0,80 / 0,58) le galet
virait au caramel, or ce qui est demandé est un verre *clair*. Mesuré :
surface p95 **120**, fond sous le chiffre 64 → **10,4:1** pour le « 5 », et
**7,5:1** pour les chiffres du panneau. Le liseré et l'éclat vivent **au-dessus
du conteneur** (dedans, l'arête sortirait dédoublée) ; le combustible vit
**dedans, avant le verre** (c'est le seul endroit où la lentille le mange).

### Comment on GARDE le cristallin sans perdre le chiffre (21-08)

Verdict : « c'est trop beau, comment on peut le garder en vrai ». Le problème
était que la brillance venait de l'illisibilité — le chiffre blanc enfermé
dans le conteneur ÉTAIT le combustible de la lentille. La distinction qui
débloque tout : **ce qui nourrit la lentille n'a pas besoin d'être ce qu'on
lit.**

**L'école retenue — LE FANTÔME.** Dans le conteneur, un fantôme du chiffre :
le même glyphe, **plus gros (×1,30) et plus gras (`.black`)**, blanc plein,
adouci de 1,5 pt seulement. Au-dessus du conteneur, le chiffre net à sa
taille. Le fantôme étant CENTRÉ sur le glyphe lisible, la lentille en fait une
**aura** — pas un doublon.

Deux essais mesurés pour y arriver, et le premier était une faute que
l'analyse avait pourtant annoncée :

| fantôme | surface p95 | leçon |
|---|---|---|
| flouté à 8 pt | **65** | le flou étale le blanc : il détruit la DENSITÉ et les BORDS FRANCS, qui sont exactement ce qui fait les caustiques. Un fantôme flou n'est qu'un halo — on retombe sur l'école du halo |
| dense, ×1,20, flou 1,5 | 142 | le cristal revient |
| **dense, ×1,30, flou 1,5, dose 1,0** | **178** | l'itération 1 en tenait 186 : on est à son niveau |

Et le galet a **grandi de 48 à 56 pt** (taille + 26) : la distorsion de la
lentille est maximale près de l'arête, donc éloigner le glyphe du bord aplatit
le centre. C'est ce réglage-là qui rend le chiffre lisible, plus que la dose.

Mesures finales : surface p95 **178**, pourtour du glyphe 65 → le chiffre net
tient **10,2:1**. Brillance et lisibilité, ensemble.

**Les trois écoles restent commutables au lancement** (elles se comparent, on
ne les tranche pas de mémoire) : `-homeV2` = fantôme (retenue) ·
`-galetPur` = l'itération 1 telle quelle · `-galetNourri` = encre nette + halo.

### LE CRISTAL PEINT — `VerreGalet.metal` (21-08, l'état livré)

Le double du fantôme n'était pas un réglage à trouver : **une lentille déplace
ce qu'elle montre**, donc un fantôme posé dessous ne peut jamais se superposer
au chiffre net. (Le double du PANNEAU, lui, était bien ma faute : je grossissais
la rangée entière ×1,30, donc chaque fantôme s'écartait vers l'extérieur — on
lisait « 4 4 », « 6 6 », et seul le chiffre du centre restait aligné. Un
fantôme grossit chaque glyphe **sur lui-même, par sa police**.)

**Le témoin qui a tranché, et il vient de l'app** : le galet qu'on tire pour
lancer une séance est brillant sur un fond BLANC. Or ce n'est pas du verre
natif — c'est un shader maison, `galetMedaillon`
([GaletSlide.swift:468](../../Woop/Views/GaletSlide.swift)). Il ne réfracte
rien : il **peint** son cristal, donc il brille sur n'importe quel fond.

D'où les **deux recettes de couches**, à ne plus confondre :

| famille | recette | ce qu'elle exige |
|---|---|---|
| verre **natif** (`glassEffect`) | monde (image / vidéo / dégradé) → verre → **encre au-dessus du CONTENEUR** | un monde à réfracter ; et il le DÉPLACE |
| verre **maison** (shader) | rect **blanc** → le shader peint tout → encre au-dessus | rien derrière ; aucun double |

`Woop/VerreGalet.metal` (`verreGalet`) peint : l'arête directionnelle (face à
la lampe, loi 1), le **point chaud** spéculaire très dur (sans lui l'arête est
une lueur, pas un reflet), la contre-lumière du côté opposé (ce qui sépare le
verre du métal peint), la caustique en retrait du bord, le corps laiteux, la
nappe qui traverse l'épaisseur, l'éclat qui dérive sur 14 s, et **la
dispersion** — que le natif ne sait pas faire.

**Trois mesures qui ont recalé le shader :**
- **le col ne pontait pas** : le smooth-min ne crée un pont que si `k` dépasse
  environ **4× l'écart**. Au milieu d'un intervalle de 12 pt les deux distances
  valent 6, et `smin(6,6,k) = 6 − k/4` ne passe sous zéro qu'à partir de
  k = 24. À 17, il ne se passe rien et on croit le shader cassé. Retenu :
  **k = 34**.
- **l'arête sortait MAGENTA** : les deux franges de dispersion tombaient au même
  endroit et s'additionnaient sur le rouge et le bleu, sans rien au milieu. Il
  faut une paire **équilibrée** (chaud dehors, froid en retrait, vert entre) et
  discrète : 0,16 / 0,10 / 0,14 pour 0,7 pt d'écart.
- **le corps était vide** (surface p95 = 13) : à 0,11 la nappe intérieure ne
  faisait qu'un contour, et un contour n'est pas du verre. Montée à 0,26, plus
  une nappe large côté lampe.

Constantes retenues : `brillance 1,0` · `arête 2,4 pt` · `dispersion 0,7` ·
`col 34 pt` · `scintille 0,55`. Le panneau **naît du galet** : fermé, son SDF
est rétracté DANS le galet (centre interpolé, demi-tailles à 16/28 %), donc
l'ouverture est une matière qui s'étire — ce que le conteneur natif ne savait
pas faire.

**Les quatre écoles restent commutables** : `-homeV2` = le cristal peint
(retenu) · `-galetFantome` · `-galetPur` · `-galetNourri`.

### LA TRICHE QUI GAGNE : LE VERRE CUIT (21-08, état livré)

Verdict sur le cristal peint : « c'est de la merde ». Et la bonne question est
venue d'elle : *on ne peut pas tricher pour avoir ce rendu ?* Si — on le CUIT.

**Le principe.** On reproduit une fois le verre natif magnifique, on le
capture, il devient une image (`Assets/galet-verre`, 168×168 @3x pour une
pastille de 56 pt), et le chiffre net se pose dessus. Plus de lentille à
nourrir, plus de fond à inventer, **plus de double** — et le rendu est
identique au pixel, sur n'importe quel fond.

**Le piège unique, mais fatal :** l'itération 1 est belle parce qu'elle plie LE
CHIFFRE. Cuite telle quelle, le glyphe tordu est DANS l'image, et poser un
chiffre net dessus graverait le double pour toujours. On la cuit donc nourrie
d'une forme **neutre** : deux lames de lumière croisées et un point chaud.

**Deux mesures ont réglé cette forme neutre :**
- **le taux de couverture, pas la densité.** À 0,30 de hauteur de lame, les
  formes couvrent 70 % de la pastille et la lentille ne montre plus qu'un blanc
  plein. Un chiffre n'occupe qu'un quart de la surface, EN TRAITS FINS : c'est
  ce rapport qu'il faut imiter (lames à 0,115 et 0,075 de hauteur).
- **le résultat, mesuré dans le corps** : moyenne 112, écart-type 83,
  **6,1 alternances** par ligne — au-dessus de l'itération 1 (72 / 82 / 5,2).

**Le montage retenu** : le conteneur natif reste DESSOUS (il fournit le panneau
et le COL liquide — une forme qui change à chaque image ne peut pas être
cuite), et l'image ne couvre que la pastille. Elle est découpée **exactement**
aux bornes du galet et clippée au même rectangle arrondi : un crop avec marge
peindrait un carré noir par-dessus la page.

**Ce que la cuisson coûte, et c'est assumé** : la matière est figée (plus
d'éclat qui dérive, plus de réaction à la lampe) ; il faut recuire à tout
changement de taille ; et le panneau, resté natif et non nourri, est plus
sombre que la pastille — soit on le cuit aussi (capsule étirable
`resizable(capInsets:)`), soit on lui donne le même monde neutre.

Banc de cuisson : **`-galetCuisson`** (la pastille seule, à sa taille finale,
sur du noir, sans chiffre) ; le curseur `neutre` dose le combustible.

**Bancs ajoutés** : `-galetOuvert` (le panneau ouvert au lancement),
`-galetChoisit <n>` (le banc ouvre et choisit tout seul — le simulateur ne
sait pas poser un doigt, et c'est le seul moyen de vérifier le câblage :
roulement du chiffre, fermeture, stockage).

## 8. LES ARBITRAGES — RENDUS LE 2026-08-20

1. **Le mur = LA LAMPE + L'AIMANT.** Le drag descend la lampe dans le mur ;
   la carte éclairée est à 100 %, ses voisines à 30 %, et la lampe se cale
   sur une carte au lâcher. Plancher de lisibilité : jamais sous 0,30 sur le
   sticker et le titre. Une seule passe Metal pour tout le mur.
2. **Le play = PREMIER ITEM DU MENU**, en capsule de **verre-braise** (§ 3).
   Un seul objet en bas au repos : le galet maison. Le galet play de la barre
   part à la réserve (banc `-navLab`), et son état « en séance » migre sur le
   glyphe du galet maison (anneau de néon + appui tenu = « Terminer »).
3. **Le feu = DANS LE VERRE, UNIQUEMENT.** Au repos : noir + rasant
   blanc-chaud à gauche + le liseré de la lune. Pas de braise permanente au
   sol, pas de fond de feu. Le jaune/orange n'existe que dans la nappe du
   menu (transitoire) et dans la capsule braise.
4. **La voix = « vous ».** « Bonjour Kathryn, vous avez fait 4 entraînements
   cette semaine sur 5 prévus. » Le registre d'Apple France. **Dette à
   payer** : repasser les autres pages (« Ta collection d'entraînements »,
   « tu peux fermer l'app sans rien perdre », le tuto des exercices…) — à
   faire en un passage dédié, pas au fil de l'eau, sinon l'app parle deux
   langues.

---

## 9. LE COMPLÉMENT DU 21-08 — « LA GRANDE CARD VIDÉO » (wireframes de Kathryn)

Dicté par wireframes le 21-08, **il prime sur les sections qu'il contredit.**
La DA en une ligne : *Apple minimalism + Liquid Glass + interface noire +
matière cinématique. Au repos, la page doit presque sembler trop simple.*

### 9.1 Pourquoi ça débloque le chantier du verre

La loi mesurée au § 7 quinquies : le verre natif ne montre que ce qu'il
réfracte — sur du noir il est à jeun (p95 = 23), nourri il est magnifique
(p95 = 186). **La vidéo de fond est le quatrième combustible, et le bon** :
un monde entier sous le verre, fait de contenu DOUX (fumée, reflets,
gradients) — exactement ce que `.clear` a le droit de manger. Les cards
fantômes, le panneau du menu et le col du galet deviennent vivants par
construction.

### 9.2 Le concept

- La home est **UNE grande surface** aux très grands coins arrondis (rayon
  concentrique : rayon du device − la marge), posée sur la page noire —
  l'anatomie du puits de l'iPod appliquée à la home entière.
- Dedans, un **fond vidéo en boucle** : noir profond, verre liquide sombre,
  fumée rouge/orange subtile, reflets blancs, mouvement presque imperceptible.
- L'univers lune/démon/rouge reste un détail d'ambiance, jamais un thème.
- Interdits DA : dashboard, accumulation de cards, gros halos, néons,
  gaming/fantasy, grandes illustrations, bordures lumineuses partout.

### 9.3 Les deux vidéos, livrées et mesurées (21-08)

`~/Downloads/pills_glass.mp4` et `~/Downloads/flamme.mp4` — toutes deux
2160×3836, 24 i/s, 6,04 s, 145 frames, H.264.

| mesure | pills_glass (le fond de la card) | flamme (le tiers bas / slider) |
|---|---|---|
| matière | pilule de verre liquide ambré-rouge qui se remplit, sur noir | braises diffuses qui montent du bord bas |
| noir | **vrai 0** (p50 = 0 — pas de plancher 16-235 à écraser) | vrai 0, max 77 (très sobre) |
| couture bouclée f144→f0 | **12,15** pour 0,69 entre voisines → saute à l'œil | **9,08** pour 0,28 → saute aussi |
| saturation (L>40) | 0,89 | 1,00 (zéro risque de brun) |
| zone de la phrase (haut-gauche) | p95 monte à **144** par frames → scrim cuit + cadrage obligatoires | noir absolu |

**Recuisson obligatoire, la recette de `start_entrianeemnt`** : ping-pong
(couture invisible par construction sur un mouvement lent), noir plancher
vérifié après réencodage, **scrim de la phrase cuit DANS le fichier**
(dégradé haut-gauche, comme le fondu de pied du panneau booster). Cadrage :
la pilule est centrée dans la source — l'aspect-fill de la card la pousse à
droite en alignant le crop, la phrase garde son noir à gauche.

### 9.4 Les arbitrages du 21-08 — RENDUS

1. **La vidéo prend tout le fond.** Le rasant `nuitRasant` est **archivé**
   derrière son flag (`-rasantLab`) — le code et les mesures du § 7 bis
   restent, la page ne s'en sert plus. Le poster d'attente = la frame de
   pose de la vidéo.
2. **Vidéos générées puis recuites** — livrées (pills_glass + flamme).
3. **La lune** : full noir **plus or en dégradé subtil**, petit néon
   **discret** — et **au clic elle S'ALLUME** (puis ouvre le trésor, la
   mécanique existante). Le § 2.4 est recalé : l'or remplace le fil blanc
   0,92, le néon reste une buée courte.
4. **Les séances** : taper une mini card de la semaine **ouvre la STORY**
   (le StoryFlow de la page du mois, « basta comme avant ») ; un bouton
   **« Tout voir » blanc léger** mène à la page calendar. **Le grand mur
   LAMPE + aimant (J4) meurt sur la home** — la grammaire lampe reste un
   plan B archivé au § 2.5 pour une autre page.

### 9.5 Les trois états

**ÉTAT 1 — repos.** De haut en bas, tout tient sur UN écran (pas de scroll —
ce qui évacue d'office les pièges 5 et 8 du § 6) :
- la phrase (inchangée, le chantier J2 + le nombre-texte survivent tels
  quels ; le nombre 3–7 pilote désormais le NOMBRE de cards de la semaine) ;
- **deux widgets noirs pixel art** minimalistes (8,4 t volume · 5,8 km cardio,
  cœur pixel) — l'école dot-matrix existe déjà dans l'app : la barre de
  statut de l'iPod (`▶·mois·lune`). Des objets noirs qui flottent sur la
  vidéo, pas des cards de dashboard ;
- **la semaine : 5 mini cards verticales.** Faites = noires, opaques, nettes,
  date + sticker. À faire = **fantômes** : `.clear` natif sur la vidéo,
  silhouette seule, la fumée passe au travers. Pas de progress bar. À la fin
  d'une séance, la fantôme **se matérialise** en noire — bounds CONSTANTS,
  révélation par calques/clip (piège 4), et le verdict « swap = paillettes,
  jamais de dissolution » reste à confirmer sur cette transition précise ;
- **le slider de départ** : noir, minimal — un dot blanc/verre, un fil très
  fin, quasi pas de texte. Matière = le galet de la navbar noire de la v1
  (`galetMedaillon` sait briller sur n'importe quoi : il peint). Drag droite
  = départ ; pendant le drag, lueur orange/rouge **extrêmement** subtile
  derrière le dot (loi anti-brun en canaux), haptique à la validation.
  **La capsule verre-braise (J6, § 3) meurt — le slider la remplace, et le
  play sort du menu (l'arbitrage § 8.2 est renversé par la spec).**

**ÉTAT 2 — séance active.** Pas de nouvelle page : **la grande card remonte
physiquement** de quelques dizaines de points et révèle DESSOUS un
mini-player (« Session du 21 août · En séance · 18 min » + stop minuscule).
Les fondations existent : le jalon 1 du player (dock sous le galet, la règle
`playerLift`). Animation fluide, sans bounce.

**ÉTAT 3 — menu.** Petit bouton home rond noir en bas à gauche. Au tap, pas
de page : la home derrière **se floute et s'assombrit PAR NOUS** (les rouges
de la vidéo deviennent des halos diffus — c'est nous qui fabriquons le
contenu doux), puis une surface `.clear` monte du bas — translucide, fumée,
presque sans bord, le verre EST le conteneur. Dedans, quatre lignes de type
nu : **Profil · Progression · Collection · Réglages.** L'encre au-dessus du
CONTENEUR (la loi). Le témoin validé de cette matière : la dalle du profil.

### 9.6 Ce que le complément tue, garde, transforme

| pièce du plan v2 | sort |
|---|---|
| rasant J1 (`nuitRasant`) | **archivé** (flag + mesures gardés) |
| phrase J2 + nombre-texte + panneau 3–7 | **survit tel quel** |
| les 5 points (J3) | **morts** — remplacés par les 5 mini cards ½ fantômes |
| lune noire liseré néon (J3) | **recalée** : noir + or dégradé subtil + néon discret, s'allume au clic |
| le mur LAMPE + aimant (J4) | **mort sur la home** — story au tap + « Tout voir » → calendar |
| galet + menu du sol (J5) | **survit**, en plus sobre (4 items, pas de play) |
| capsule verre-braise (J6) | **morte** — le slider de départ la remplace |
| `SÉANCES` sur-titre + filet | **morts** (la semaine se suffit) |

### 9.7 Les jalons du complément

| # | Ce qu'on juge | Banc |
|---|---|---|
| **V1** | la matière : recuisson des 2 vidéos (ping-pong, noir plancher, scrim), la grande card aux coins concentriques, la phrase posée dessus | `-homeV2` |
| **V2** | la semaine : 3 noires + fantômes `.clear`, la matérialisation | `-semaineLab` |
| **V3** | les widgets pixel (école dot-matrix) | dans `-homeV2` |
| **V4** | le slider de départ (matière navbar, lueur au drag, haptique) | `-sliderLab` |
| **V5** | la levée (état 2) + mini-player | `-leveeLab` |
| **V6** | le menu (état 3) : flou maison + dalle `.clear` + 4 items | `-homeV2Menu` |
| **V7** | la lune noir-or qui s'allume au clic | dans `-homeV2` |
| **V8** | verdicts téléphone : cadence, batterie vidéo, noirs OLED | — |

### 9.8 JALON V1 — LIVRÉ LE 21-08 (non commité)

`Woop/Media/home-fond-loop.mp4` (4,8 Mo, 1080×2348, 24 i/s, 12 s) cuit par
`tools/home-v2/recuit_fond.sh` ; `FondBanc` / `HomeFondVideo` /
`GrandeCardVideo` dans `Woop/Views/HomeNuit.swift`. La page `-homeV2` vit sur
la card ; `-fondRasant` (ou `-rasantLab`, `-isoRasant`) rend la chambre noire
du jalon 1. Naissance : fondu easeOut 1,15 s + approche 1,015 → 1, la phrase
part à 0,38 s — les horloges du J2 inchangées.

**Mesuré (sonde numpy sur la boucle entière)** : coutures 1,0-1,35 pour un
bruit entre voisines de 0,7 (en direct : 12 — le ping-pong était obligatoire) ;
noirs à vrai 0 ; saturation 0,98 ; zone de la phrase ligne à ligne : L1-L4
p95 = 0 à TOUTES les frames, L5 ≤ 52 au pire frame (la flaque validée du J2
valait 55). Marge 10 pt / rayon 45 continus, vérifiés à la capture (bandes
noires 30 px, le coin incurve la lueur).

**Trois pièges payés :**
1. **`blend` sur yuv420p fusionne les PLANS YUV** : un « screen » sur la
   chroma (neutre = 128) fabrique une vidéo MAGENTA et soulève les noirs à
   37. La fusion se fait en RGB (`format=gbrp` avant `blend`).
2. **Le cadrage se juge contre le wireframe, pas contre la source** : la
   pilule centrée de la source montait dans la phrase (p95 144). Pad gauche
   210 + pad haut 480 (bords mesurés noirs purs → padding invisible) : la
   pilule à 65 %, son dôme à 28 % — sous la phrase.
3. **Une zone de mesure rectangulaire ment** : « la zone de la phrase » à
   p95 122 quand les VRAIES boîtes des cinq lignes donnaient 0/0/0/0/151 —
   seul le liseré du dôme croisait la queue de « sur 5 prévus. » sur ~15 pt.
   Le remède n'était pas d'élargir le scrim de coin mais une PASTILLE
   gaussienne locale (0,65, σ 150×120, centrée 470/770), qui se lit comme
   l'ombre naturelle du flanc gauche du dôme.

**Reste ouvert au V8** : la couture à l'œil sur téléphone (1,35 est sous le
seuil théorique, pas encore juré sur OLED), la batterie (décodage matériel,
à sonder), et le pop éventuel du player au premier frame (couvert par le
fondu de naissance en pratique).

### 9.9 LE TOUR DE VERDICTS DU 21-08 (sur V1) + JALON V2 — LIVRÉS

**Les trois verdicts de Kathryn sur V1, et leurs remèdes :**
1. « Des fois la vidéo pas très fluide, on voit le noir glitch » + « on capte
   que c'est une vidéo, maybe plus slowy » → **LE RALENTI ×2** cuit dans le
   fichier (`setpts=2.0*PTS`, boucle de 24 s) : le pas de mouvement par frame
   passe à ~0,35 de luminance (sous le seuil), et le décodeur travaille
   moitié moins — les hoquets du simulateur (décodage logiciel) devraient
   suivre. À re-juger au téléphone (décodage matériel) avant d'accuser autre
   chose.
2. « La pills dans le coin ? » → OUI, tranché et cuit : un objet posé au
   centre est une affiche, un objet COUPÉ par le cadre est une fenêtre. La
   pilule réduite (45 % de hauteur), dôme à 13 %, flanc droit coupé à 104 %
   du cadre. Les cinq lignes de la phrase vivent sur du noir (pire : 17).
3. **La source a changé : `pills_2.mp4`** (plus sombre, plus « verre
   liquide ») — bbox mesurée 448..1816 × 408..3237, recette recalée.

**JALON V2 — LA SEMAINE (livré, non commité).** `SemaineStrip` dans
`HomeNuit.swift` : `prevus` emplacements (l'objectif du panneau 3-7 pilote le
COMPTE — le nombre-texte et la semaine disent la même chose), faites = plaques
noires 0,055 + arête haute 1 pt + date fr + sticker maison ; restantes =
FANTÔMES `.clear` nus. Vérifié en capture : la nappe de flamme de la vidéo
passe À TRAVERS les fantômes quand elle monte — le verre est nourri, c'était
tout l'enjeu. Les deux lois du verre appliquées : rangées JUMELLES (verre dans
le conteneur, encre au-dessus), bounds constants (la matérialisation est un
fondu de calques par-dessus le verre, le verre ne se démonte jamais).
Matérialisation : plaque easeOut + sticker en ressort + haptique douce.
Bancs : `-semaineFaits <n>` (force les faites — sans lui, objectif ≤ faites =
aucun fantôme visible), `-semaineMaterialise` (joue la matérialisation à
2,5 s). Dette assumée : le banc matérialise la semaine SANS avancer la phrase
(loi 4 techniquement violée au banc) — le câblage réel des deux au store vient
au jalon du flow.

**L'IDÉE DE KATHRYN POUR V5 (21-08, à spéc'er)** : la levée n'est pas
seulement l'état-séance — la card se TIRE au doigt (drag/scroll), et hors
séance elle cache UNE SURPRISE dessous (« genre la petite lune ») — l'école
de la carte dépliable du profil et de son booster. Le player en séance et la
surprise hors séance partagent le même geste et la même couche révélée.

### 9.10 LE TOUR DE VERDICTS DU 21-08 (sur V2) — trois corrections livrées

1. **« La pilule DERRIÈRE le texte, sur le côté, comme mon screenshot »** —
   recadrée : 52 % de hauteur, dôme à 17 %, flanc gauche à 48 % (les lignes
   passent SUR le verre), droite coupée à 103 %. La pastille du scrim suit le
   dôme (0,50, σ 190×180, centre 640/620). Mesuré ligne à ligne au pire
   frame : L3 = 52 (= la flaque validée du J2), le reste ≤ 6.
2. **« Je dois pouvoir drag TOUTE la home »** — le ScrollView est MORT (la
   home tient sur un écran) : la card entière (fond, phrase, semaine) suit le
   doigt en bloc, élastiquée en tanh (course max 150 pt), retour en ressort
   au lâcher. La dissolution de la phrase est nourrie par le tirage vers le
   haut (même formule que l'ancien scroll, `-phraseScroll` marche toujours).
   La couche révélée dessous (player en séance / la surprise-lune) = V5.
3. **« La semaine : reprends le calendrier, tout réduire »** — `SemaineStrip`
   refaite au patron du bac : ardoise 354×122 rayon 24 (gradient, grain,
   lumière posée haut-gauche) mais TRANSLUCIDE (noir 0,50 → 0,30 — une
   ardoise opaque affamerait les fantômes), titre « Cette semaine. », minis
   70×87 = `MiniSeanceCard` ÷ 1,9 (même ardoise 0,040 → 0,014, cheveu 6 %,
   grain, date bold + mois sourd, sticker bas-gauche), éventail −9° → +9°
   (le bac ÷ 2) en layout FIXE + transforms de rendu (jamais un HStack — la
   loi de l'éventail), la droite devant, minis TRANCHÉES par le bord bas.
   Vérifié en capture : le fantôme attrape la lueur de la pilule à travers
   l'ardoise translucide.

### 9.11 LE TOUR DE VERDICTS DU 21-08 (2ᵉ salve) — LE VERRE COUCHÉ, LE SECRET, LE GLITCH

**1. « C'est incliné sur le côté, sous le texte ».** Sa maquette ne montre pas
une pilule debout : un VERRE EN DIAGONALE qui entre par le bas-gauche, passe
SOUS la phrase, dôme (la grande caustique) en haut à droite. Angle et pose
trouvés par **recouvrement de masques** contre sa maquette — le profil de bord
seul se faisait piéger par la nappe du bas. Retenu : **75° horaire, contenu de
440 × 269 pt, bord droit à 355, haut à 175, corps qui SORT par la gauche.**
⚠️ Le placement se fait en `overlay` (coordonnées négatives permises), jamais
en `pad`.

**2. « La petite lune est en bas, pas en haut ».** `LuneSecrete` vit désormais
dans la bande du BAS et se lève quand la card se SOULÈVE (tirage négatif).
C'est la même place et le même geste que le player de séance (V5) : hors
séance le secret, en séance le player.

**3. « Ralentis encore » + « fondu à gauche » (le carré vert).** Ralenti porté
à **×3** (boucle 36 s) et — le point qui compte — **`minterpolate` en fondu** :
`setpts` seul TRIPLE les frames, ce qui fait un palier de 3 images et se lit
comme un LAG. L'interpolation fabrique de vraies images intermédiaires. Plus
un **fondu de gauche cuit dans le scrim** (rampe 0,92 → 0 sur 130 pt, fenêtrée
en y pour épargner la nappe du bas) : le corps du verre n'a plus de bord, il
fond dans la nuit. Mesuré : bande 0-40 pt à L 1,4.

**4. « On voit moins ces beaux reflets clairs ».** La pastille gaussienne du
scrim, posée quand la pilule était DEBOUT, tombait pile sur le dôme depuis
qu'il est couché — elle mangeait la caustique. Retirée. Les cinq lignes
tiennent quand même (pire : L3 à 64, la ligne CLAIRE — du blanc dessus).

**5. « Des fois glitch noir, résous absolument ».** Trois causes, trois
remèdes, tous nécessaires :
- **la résolution** : 1080 × 2348 met à genoux le décodeur LOGICIEL du
  simulateur, et une frame ratée sur une couche opaque = un écran NOIR. Sortie
  ramenée à **540 × 1174** (le contenu est mou, ça ne se voit pas) : le
  fichier passe de 6,8 à **1,5 Mo** et le décodage à un quart ;
- **l'image de pose** : la première frame est cuite dans les assets
  (`home-fond-poster`, 15 Ko) et posée SOUS la vidéo, dont la couche est
  rendue TRANSPARENTE. Un raté ne fait plus que figer l'image ;
- **le préchargement** : `preroll` une fois les tampons prêts, plus un GOP
  court (une clé toutes les 2 s) pour que la boucle reprenne franc.
⚠️ **`AVPlayer.preroll` LÈVE UNE EXCEPTION** tant que `status != readyToPlay` :
appelé à la construction de la vue, il TUE l'app au lancement (payé). Il
s'attache à une observation du statut.

**6. LA SEMAINE, recalée au wireframe mesuré.** L'ardoise était à **L 4** quand
la sienne est à **L 27** (soit exactement le `white: 0.11` de la pochette du
bac) : elle disparaissait dans la page. Corrigé, en gardant l'opacité 0,90
pour ne pas affamer les fantômes. Et le reste au comparatif à la même échelle :
minis **70 × 88** (au lieu de 62) au **pas 51** (au lieu de 55,5 — elles se
chevauchent bien plus), tops à **66 / 56** pt sous le haut de l'ardoise (elles
étaient 16 pt trop bas), titre à **20 pt** (le sien fait 147 pt de large, le
mien en tenait 115), jour à **10** et mois à **5,5** (ils étaient trop gros
d'un tiers).

