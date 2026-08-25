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

---

## 10. LES CARDS PIXEL (jalon V3) — LE PANNEAU À LED

Commandé le 21-08 sur deux références : une card au **cœur** blanc (« 72 »),
une card à la **flamme** ambre (« 4/5 »). Consigne : *« travaille
essentiellement les lignes et les points, pas le background liquid glass pour
le moment, et le chiffre »* — donc la matière du panneau d'abord, le verre
après.

### 10.1 Ce que les références disent, mesuré

Sonde numpy sur ses deux images (card de 620 × 614 px) :

| pièce | pas | Ø du point | ratio |
|---|---|---|---|
| la grille FINE (glyphe + chiffre) | 11 px | 8,5 px | **0,78** — ils se touchent presque |
| la RÈGLE (la ligne pointillée) | 28 px | 8 px | **0,29** — elle respire |

Niveaux mesurés : point **allumé** L 254 · point **éteint** L 27 (il EXISTE,
et c'est lui qui fait « panneau » et pas « dessin ») · règle à gauche du
glyphe **L 249**, à droite **L 102**.

Ramené à un widget de **148 pt** : grille fine **2,6 pt** (point 2,0), règle
**6,7 pt** (point 1,9), glyphe **11 cellules** de large (≈ 29 pt), chiffre sur
**7 rangées** (≈ 18 pt). Vingt-deux points de règle en travers.

### 10.2 Les quatre lois du panneau

1. **LES POINTS ÉTEINTS EXISTENT.** Un glyphe posé sur du vide est un dessin ;
   posé sur un champ de points sourds, c'est un afficheur. Le champ sourd
   s'éteint en **radial** autour du glyphe (mesuré sur ses deux images) — il
   ne couvre pas toute la card.
2. **LA RÈGLE EST LA JAUGE.** Ce n'est pas un décor : les points à gauche du
   seuil sont allumés, ceux de droite sourds. À 50 % on retombe exactement
   sur ses références.
3. **LA CHALEUR SE CALCULE, ELLE NE SE DESSINE PAS.** La flamme n'est pas
   peinte cellule par cellule : sa forme est un bitmap, sa **couleur** vient
   d'un champ de chaleur (1 au cœur du bas, décroissant) — le blanc au pied,
   l'ambre au ventre, la braise à la pointe. La rampe s'écrit **en canaux**
   (on éteint le bleu puis le vert quand la chaleur tombe), jamais en `mix`
   entre deux teintes : le chemin droit passe par le brun (loi payée au J1).
4. **UN SEUL CANVAS.** Un widget porte ~900 points ; une vue par point serait
   la mort. Tout est dessiné dans UN `Canvas`, en points, sans image.

### 10.3 Les deux cards

| | glyphe | valeur | la jauge |
|---|---|---|---|
| **CŒUR**, blanc pur | 11 × 9 | « 72 » | le pouls moyen de la semaine |
| **FLAMME**, braise | 11 × 12 | « 8,4 » | les tonnes soulevées |

Les deux valeurs viennent de son brief d'origine (volume soulevé, cardio) et
ne redisent RIEN de la phrase (loi 4 : chaque chose se dit une fois — le
compte des séances est déjà dans la phrase ET dans la semaine).

### 10.4 La géométrie de la card

Mesurée sur son wireframe : deux carrés de **148 × 128 pt**, gouttière 24
(alignée sur la phrase et sur l'ardoise de la semaine), **58 pt** d'écart. La
règle vit à **45 %** de la hauteur, le chiffre en bas à gauche à 14 pt du
bord. Fond : pour l'instant l'ardoise de la semaine (verre plus tard, sa
consigne).

### 10.5 Le banc

`-widgetLab` : les deux cards seules, en grand, avec la jauge qui balaie —
le seul moyen de juger la règle et le champ sourd sans le reste de la page.

---

## 11. LE PANNEAU, REPRIS À ZÉRO (verdict « beaucoup trop cheap », 21-08)

Verdict sans appel sur le §10 : *« c'est beaucoup trop cheap, je veux des
petits points très fins, minimal, élégant, et dégradé… beaucoup de dégradé,
beaucoup de détail et beaucoup de points… je veux comme la photo à 100 %
sauf les backgrounds »*. La nouvelle référence (deux cards de **530 × 341 px**)
a été sondée au numpy. Elle dit une chose que je n'avais pas vue : **ce n'est
pas un glyphe posé sur un fond, c'est une DALLE À LED, et c'est la dalle qui
est le sujet.**

### 11.1 L'écart, chiffré

| grandeur | SA référence | CE QUE J'AI FAIT | facteur |
|---|---|---|---|
| pas de la grille | **1,08 % de la largeur** (5,7 px) | 1,76 % | 1,6× trop gros |
| cellules par card | **93 × 60** | 57 × 49, et seulement en tache | — |
| Ø du point **éteint** | **0,17 × le pas** | 0,62 | **3,6× trop gros** |
| Ø du point **allumé** | **0,70 × le pas** | 0,62 | — |
| rapport allumé / éteint | **× 4,1** | × 1,0 | **le bloom n'existait pas** |
| dégradé du panneau | points de **L 10 à L 100** | constant | **rapport 10 perdu** |
| le cœur | **16 × 13 cellules** | 11 × 9 | 2× moins de définition |
| la flamme | **18 × 23 cellules** | 11 × 12 | 2× moins |
| la règle | 34 points, pas **3,67 cellules** | 2,6 cellules | trop serrée |

**Les trois fautes, nommées :**
1. **Le point éteint doit être un GRAIN, pas une pastille.** À 0,17 du pas il
   fait une trame de soie ; à 0,62 il fait du gros-plan de Lego. C'est LA
   faute qui saute aux yeux.
2. **Un point allumé BLOOME.** Chez elle il est **quatre fois** plus large
   que ses voisins éteints — c'est ça, une LED qui s'allume. Chez moi tous
   les points faisaient la même taille : une grille de cases cochées.
3. **La dalle porte la LUMIÈRE DE LA CARD.** Ses points éteints vont de L 10
   dans l'ombre à L 100 sous la traînée du verre : la trame RÉVÈLE l'éclairage
   au lieu de le subir. Chez moi le champ était plat, et cantonné à une tache
   ronde autour du glyphe au lieu de couvrir toute la card.

### 11.2 La loi qui sort de là

> **LA DALLE EST UN MATÉRIAU, PAS UN AFFICHEUR.** Toute la surface est en
> points ; ce qui « s'affiche » n'est qu'un endroit où les points sont plus
> gros et plus chauds. Rien n'est jamais posé SUR la dalle — tout est fait
> DE la dalle.

Corollaire : **un point n'a pas deux états, il a une intensité.** Son rayon
ET sa couleur en découlent, continûment. C'est ce qui donne le dégradé
qu'elle réclame : le bord du cœur n'est pas une frontière, c'est une rangée
de points à mi-régime.

### 11.3 La route technique : un shader, pas un Canvas

93 × 60 = **5 580 points par card**, 11 160 pour les deux. Un `Canvas` les
dessine un par un à chaque image : c'est le lag garanti. La maison sait faire
autrement — **c'est un shader**, comme tout le reste (`nuitRasant`,
`galetMedaillon`, `LiquideMolette`). Coût en O(pixels) et non en O(points),
anticrénelage gratuit, et le dégradé par construction.

**La forme retenue — `layerEffect`, la dalle qui MANGE un calque.** Le shader
ne connaît ni cœur ni flamme : il prend un calque quelconque et le rend « en
points ». Pour chaque pixel, il trouve sa cellule, échantillonne le calque
source AU CENTRE de cette cellule, et peint un point dont le **rayon** et la
**couleur** viennent de ce qu'il y a lu.

Ce que ça donne, et c'est là qu'est l'élégance : **le glyphe redevient un
dessin normal.** On dessine un vrai cœur (un chemin, pas un bitmap) rempli
d'un dégradé, avec sa lueur floue dessous ; le shader en fait une constellation
de points d'intensités continues. Les demi-teintes du dessin deviennent des
demi-points. Aucun bitmap 16 × 13 à saisir à la main, et le dégradé est
gratuit.

Le calque source d'une card contient donc, de bas en haut :
1. **l'éclairage de la dalle** — le dégradé ambiant + la traînée du verre
   (c'est lui qui fait vivre les points éteints de L 10 à L 100) ;
2. **la lueur** du glyphe — sa silhouette floutée large, dans sa teinte ;
3. **le glyphe** — chemin plein, dégradé interne (le cœur : plus clair au
   centre-gauche ; la flamme : blanc au pied, ambre au ventre, braise à la
   pointe, en canaux — jamais un `mix` entre deux teintes).

**Au-dessus du shader, deux pièces seulement** — parce que leur grille n'est
PAS celle de la dalle (mesuré : la règle est à 3,67 cellules, un pas non
entier) :
4. **la règle**, ses points à elle, plus gros, allumés à gauche du seuil ;
5. **le chiffre**, en 7 × 9 sur la grille fine, en points pleins.

### 11.4 Les constantes de départ (mesurées, à fouetter au banc)

pas **1,08 %** de la largeur · point éteint **0,17** du pas · point allumé
**0,70** · rayon = 0,17 + 0,53 × intensité^0,8 · rapport de niveau du
panneau **10** entre l'ombre et la traînée · cœur **16 × 13**, flamme
**18 × 23** · règle : pas **3,67** cellules, point **0,55**.

Format de la card revu sur sa référence : **1,55 de rapport** (530 × 341) et
non 1,16 — les deux widgets de la home passent donc à **148 × 100**, la dalle
a besoin de largeur pour que la règle respire.

### 11.5 Le fouettage

Ce jalon se juge à la sonde, pas à l'œil : `tools/home-v2/mesure_dalle.py`
compare une capture au tableau du § 11.1 (pas, ratio des deux Ø, rapport de
bloom, amplitude du dégradé, définition du glyphe). Tant qu'une ligne n'est
pas à sa valeur, ce n'est pas fini. Banc : `-dalleLab`, avec les curseurs du
pas, des deux rayons, du bloom et du dégradé, et le sélecteur cœur/flamme.

**Hors périmètre pour l'instant** (sa consigne) : le fond en verre de la card.
La dalle d'abord.

---

## 12. LES CARDS « VOLUME / SÉANCES » (jalon V3, la 3ᵉ direction)

Verdict sur la dalle à LED : *« stop, je veux pas ça en fait »*. Nouvelle
référence (`mini_widget_noir.png`, deux cards de 607 × 613 px), consigne :
*« je veux exactement ça à 100 %, tous les détails, tout — fais workflow et
fouette »*.

### 12.1 L'anatomie, mesurée (workflow à 5 lentilles, 371 mesures)

**LA CARD EST UNE DOUBLE COQUE.** Profil sur le bord gauche, en px :
`0-2` le liseré de la bezel (crête L 74) · `4-18` la bezel presque noire ·
`19` la couture · `20-23` le liseré du PANNEAU (crête L 49) · `24+` le
panneau. Encastrement **3,45 % de la largeur**.

**LE COIN N'EST PAS UNE SQUIRCLE.** Ajustement d'une superellipse sur 200
points : **n = 2,0**, arc de cercle pur, rayon **14,6 % de la largeur**. Un
coin `.continuous` d'Apple y met un galbe que la référence n'a pas — et le
reflet qu'on trace dessus s'en décolle au milieu du virage.

**LE LISERÉ EST UN DÉGRADÉ ANGULAIRE**, et c'est LA découverte. Il fait le
tour, et son intensité tourne avec l'angle : deux POINTS MORTS aux coins
haut-gauche (#1B1A1A) et bas-droit (#141414), deux CRÊTES aux coins
haut-droit (l'or, #FEF6D0 écrêté au blanc, balayage 141°) et bas-gauche
(le blanc pur, 118°). **Les « traînées » ne sont pas des objets posés à côté
de la card : c'est ce liseré lui-même, saturé sur un arc.** Mon premier jet
en faisait deux arcs flottants — d'où le décollement.

Le reste, mesuré : aucune ombre portée, aucun halo ambiant (à 6 px du bord
on est au fond) · bloom 4-5 px au liseré, 8-12 px aux crêtes · rails
#333333 → #1C1C1C, liseré 1 px, rayon 25,5 % de leur largeur · segments en
dégradé **HORIZONTAL** (#EEA557 gauche, #E29B58 milieu, #FFC582 droite —
un cylindre éclairé par la droite, pas une touche laquée), rayon 12,1 % ·
base des barres à **63,5 %** de la hauteur (ce que je prenais pour leur pied
à 69,2 % était la LETTRE du jour) · pied en deux colonnes CENTRÉES (27 % et
70 %).

### 12.2 L'instrument de fouettage

`tools/home-v2/compare_widget.py` note le rendu contre la référence, région
par région (en-tête, graphe, pied, les deux arêtes), et sort le triptyque
`réf | mien | écart`.

⚠️ **L'instrument est très sévère, et il faut le savoir pour lire sa note.**
Calibré contre la référence elle-même : un décalage de **2 px** coûte
**1,3 point**, 4 px en coûtent 2,7. Et la référence est un rendu
photographique (grain, dégradés doux, sa propre fonte) qu'une reconstruction
vectorielle ne peut pas corréler au-delà de ~0,7. L'alignement résiduel a été
vérifié par corrélation croisée : **dx = +1 px, dy = +1 px, échelle 1,00** —
il n'y a plus de décalage systématique à corriger.

### 12.3 L'état

Livré (non commité) : `Woop/Views/WidgetsCards.swift`, banc `-cardsLab`.
Note de l'instrument : **6,05/10** — c'est-à-dire « tout est placé à 3-5 px
près », pas « c'est à moitié faux ».

Trois demandes du 21-08, appliquées et qui S'ÉLOIGNENT VOLONTAIREMENT de la
référence (l'instrument les compte donc en écart, à raison) :
le « 4 / 5 » aligné sur le « 8.4 » et posé AU-DESSUS de sa légende (il la
recouvrait), sa fonte réduite, et **la valeur au-dessus de son libellé dans
la colonne droite du pied** (la référence fait l'inverse).

Reste ouvert : l'unité (« plutôt kilos que tonnes »), le grain
photographique de la référence, et le câblage aux vraies données.

### 12.4 Ce que le workflow a corrigé de fond (371 mesures, 6 agents)

- **La fonte est SF Pro (système), pas Inter** — vérifié par IoU du masque du
  « 4 » contre SFNS.ttf (0,88-0,91), pas deviné. Et **tout est `.regular`**
  sauf les deux gros chiffres (Medium) : le « +12 % » qui semble gras à l'œil
  est mesuré à 0,119 de rapport trait/capitale, donc Regular.
- **Les gros chiffres ne sont pas blancs plats** : dégradé vertical
  métallique #FFFFFF → #DCDCDC (card volume) / → #C9C9C9 (card séances).
- **Tracking +0,03 em sur les textes moyens, nul sur les petits labels** du
  pied — une règle, pas un réglage au cas par cas.
- **Un seul gris #949392** couvre 8 des 12 textes sans qu'on voie la
  différence.
- **La matière du corps** : ni aplat ni dégradé linéaire, mais un plancher
  #030303 et DEUX lueurs radiales sur l'anti-diagonale (pic #282828 au coin
  haut-droit, #1B1B1B au bas-gauche, aux deux tiers de sa force), strictement
  NEUTRES — toute la chaleur vient des reflets et du contenu.

**ET UN AVERTISSEMENT QUI VAUT POUR TOUT LE CHANTIER** : la référence n'est
pas un rendu vectoriel, c'est une image RETOUCHÉE (unsharp mask). Preuve
dure : une coupe à travers un fût de chiffre donne `196, 237, 91, 0, 5, 8` —
un pixel à ZÉRO de chaque côté de l'arête, sur un fond qui vaut 5-10. C'est
du ringing. **La hairline noire autour du corps, du panneau et de chaque
glyphe est cet artefact — il ne faut PAS le reproduire.** Ses irrégularités
non plus : le pas des 7 barres dérive de +3,7 % de gauche à droite, celui des
7 pastilles rétrécit de 4,5 %, les rayons des coins diffèrent de 6 px d'un
coin à l'autre. On régularise.

C'est aussi pourquoi l'instrument plafonne : une reconstruction vectorielle
propre ne peut pas corréler au-delà de ~0,7 avec une image sur-nettoyée.

### 12.5 Le tour de verdicts du 21-08 sur les cards

Quatre demandes, appliquées :
1. **Le gros chiffre était plus lourd à droite qu'à gauche** — même corps
   (19,3 %H) mais l'un en Medium, l'autre en Regular. Les deux passent en
   **Regular à 17,5 %H** : même taille, même graisse, et plus discret.
2. **L'unité devient `kg`** (« ce seront nos vraies données ») — l'en-tête et
   la moyenne du pied.
3. Le pied de la card des séances **touchait le bord** : 5,5 %H → **4,3 %H**.
4. **Les deux cards sont posées sur la home** (`CardsRangee`, 170 × 170,
   gouttière 24, écart 14). Verticale recalée : les cards à 31,5 % de la
   hauteur utile, l'ardoise de la semaine repoussée à 56,5 % — elles se
   chevauchaient de 37 pt.

Restent ouverts : la langue (les cards sont en anglais comme la référence,
la page est en français), le reflet blanc du bas-gauche qui court encore un
peu plus loin que celui de la référence, et le câblage aux vraies données.

---

## 13. LES DEUX CHANTIERS SUIVANTS — LE GALET/LA NAPPE, ET LE TIROIR

Commandés le 21-08 : *« le menu pills liquid glass assez noir avec logo home
néon blanc, et quand on clique, une partie de l'écran du bas devient halo
fondu avec le titre de nos sections… et après le chantier avec le replay
(effet comme quand la carte globale de la home est levée). Des transitions
très Apple like, très luxe. »*

**LA DOCTRINE DES DEUX CHANTIERS, en une phrase :** *rien n'apparaît — tout
ARRIVE, dans un ordre, et la lumière passe toujours avant la géométrie.*
C'est la loi maison (« l'oreille arrive 0,25 s avant l'œil ») appliquée à
deux gestes. Un panneau qui « pop » est un panneau ; un panneau dont la
lumière s'allume avant qu'il ne bouge est un objet.

---

## CHANTIER A — LE GALET ET LA NAPPE

### A.1 Le galet

Un seul bouton, en bas à gauche, **62 pt**, aligné sur la gouttière de la
page (x 24).

- **Le corps est NOIR MAT, pas du verre natif.** La loi payée deux fois :
  le verre natif ne montre que ce qu'il RÉFRACTE, et posé sur le noir de la
  page il est à jeun (p95 mesuré à 23, verdict « on voit rien, ça fait
  blur »). Le galet reprend donc la matière du galet de la barre v1
  (`galetMedaillon` — un shader qui PEINT son cristal au lieu de l'emprunter,
  et qui brille donc sur n'importe quel fond).
- **Le glyphe est une MAISON AU NÉON BLANC**, tracée au trait comme
  `GlypheLune` — jamais un SF Symbol : à cette taille, c'est le tracé qui
  fait la marque. Recette de `NeonPrimaryButton`, en blanc au lieu d'ambre :
  cœur blanc pur, tube, halo court (≤ 10 pt, au-delà c'est du néon de bar).
- Au repos il **respire** (l'invite du galet play, déjà écrite) — et
  seulement lui : c'est le seul objet vivant de la bande basse.

### A.2 L'ouverture — six gestes, aucun simultané

| t (s) | ce qui bouge |
|---|---|
| 0,00 | le galet s'enfonce (échelle 0,94), `impact(.soft)`, son néon monte au blanc pur |
| **0,04** | **LA NAPPE S'ALLUME AVANT DE MONTER** — opacité 0 → 1 en 0,22 s, immobile. La lumière d'abord. |
| 0,10 | la nappe MONTE de 40 pt (ressort response 0,52 / damping 0,86) |
| 0,10 | **la home RECULE** : échelle 1 → 0,974 et un voile noir à 0,22 — elle ne s'en va pas, elle s'ÉLOIGNE |
| 0,26 | les items arrivent **du bas vers le haut**, 55 ms d'écart, flou 10 → 0 + montée 14 pt |
| 0,42 | le galet **devient** le chevron (fondu croisé du glyphe, le corps ne bouge pas) |

Total ≈ 0,75 s. C'est lent, et c'est le sujet.

### A.3 La nappe : d'où vient le « halo fondu »

**LA CLÉ, et elle est gratuite : la nappe ne PEINT pas ses halos, elle les
prend à la vidéo.** Le bas de la grande card est déjà une nappe de braise (la
flamme, cuite dans `home-fond-loop.mp4`). Un verre `.clear` posé dessus la
floute et la relève en halos diffus — c'est exactement la loi « le verre
natif ne montre que ce qu'il réfracte », et ici il a enfin de quoi manger.
Aucun dégradé de braise à réinventer.

**Trois pièges déjà payés, à honorer :**
1. **`.blur` pose un voile UNIFORME sur tout le rectangle de son hôte** — il
   ne sait pas s'affaiblir vers le haut. Le fondu du bord haut de la nappe se
   fait donc par un **masque en dégradé sur le verre**, jamais par un flou
   qui diminue.
2. **Un `glassEffect` aux bounds vivants reste flou plat pour toujours.** La
   nappe a une **taille constante** ; c'est son masque qui monte.
3. **L'encre vit au-dessus du CONTENEUR de verre**, pas dedans (sinon elle
   est lentillée : le chiffre-trou-dans-du-métal du galet de l'objectif).

Géométrie, mesurée sur sa maquette : la nappe prend le **tiers bas** (son
bord haut à ~66 % de la hauteur), bord haut **fondu sur 60 pt**, aucun
liseré, aucun coin arrondi visible — c'est une brume qui monte, pas une
feuille qui se pose.

### A.4 Les items

**Profil · Progression · Collection · Réglages** — quatre, sa DA. 26 pt
semibold blanc, gouttière 32, 22 pt entre eux. **Pas de card autour de
chaque option : le verre EST le conteneur.** Le survol au doigt = un grain
léger ; le choix = le coup lourd (`SwapFeedback.slam()`, déjà écrit).

### A.5 La fermeture

Tap dehors, drag vers le bas > 60 pt, ou choix d'un item.
**Le choix se voit** : l'item choisi RESTE, les autres s'effacent d'abord
(60 ms), puis la nappe descend avec lui. On voit partir ce qu'on a choisi —
c'est ce détail qui fait « luxe » et pas « menu ».

---

## CHANTIER B — LE TIROIR DU BAS

Le geste existe déjà (§ 9.11) : la card se soulève, la bande du bas se
découvre, la lune secrète s'y allume. Ce chantier lui donne son CONTENU.

### B.1 Un geste, trois contenus

La même bande révélée porte, selon l'état de la séance :

| état | ce qu'on trouve dans le tiroir |
|---|---|
| hors séance | **LE SECRET** — la lune néon (déjà livré) |
| en séance | **LE PLAYER** — « Session du 21 août · En séance · 18 min » + le stop |
| séance finie | **LE REPLAY** — la carte de la séance, qui ouvre sa story |

Un seul geste, un seul tiroir, trois contenus : c'est ce qui fait qu'on
l'apprend une fois.

### B.2 La physique du tiroir

Ce qui manque aujourd'hui, et qui sépare un jouet d'un tiroir :
- la card suit le doigt **1:1 jusqu'à 40 pt** puis se retient (tanh) — en
  place ;
- **au-delà d'un SEUIL de 90 pt, elle s'AIMANTE OUVERTE au lâcher** et ne
  retombe plus. En dessous, elle revient. C'est ce cran qui fait le tiroir ;
- le contenu arrive à **55 % de la course**, pas à l'ouverture : on le voit
  VENIR, on ne le découvre pas ;
- fermeture : drag vers le haut, ou tap sur la card.

### B.3 Le player

À la place du slider quand une séance tourne (§ 9.5, état 2) : la lune du
mois à gauche, le titre, « En séance · N min » en sourd, et un **stop
minuscule** à droite. Les fondations existent (le jalon 1 du player, la règle
`playerLift`). Le compteur des minutes **roule** (`contentTransition
(.numericText)`), il ne saute pas.

### B.4 Le replay

La carte de la dernière séance, posée dans le tiroir, qui **ouvre sa story**
depuis son propre rect — le portail `StoryFlow` existe déjà (celui de l'iPod
du mois). ⚠️ Piège payé : `presentationBackground(.clear)` décale la story
sous l'île et coupe son titre.

---

## LES ARBITRAGES — RENDUS LE 21-08

1. **« Le replay » = LE PLAYER de la séance en cours.** Le rejeu de la
   dernière séance viendra après, dans le même tiroir.
2. **LE GALET EST DU VERRE NATIF NOIR**, pas un galet peint — et sa raison
   est juste : *« liquid natif qui va se révéler grâce aux flammes du
   background »*. C'est l'exception à la loi du verre à jeun, et elle est
   légitime : à cet endroit précis (bas-gauche de la card) la nappe de
   flamme de la vidéo passe DESSOUS. Le verre a enfin de quoi réfracter.
   ⚠️ Conséquence : le galet doit être posé **au-dessus de la vidéo et sous
   l'encre** — le néon vit AU-DESSUS du conteneur, jamais dedans.
3. **La nappe = LA BRUME QUI MONTE** : pas de coins arrondis, pas de liseré,
   le tiers bas qui devient du verre et dont le bord haut se fond sur 60 pt.
4. **Quatre items** : Profil · Progression · Collection · Réglages. Les
   entraînements restent accessibles par la bande « Cette semaine ».

### 13.1 CHANTIER A — LIVRÉ LE 21-08 (non commité)

`Woop/Views/MenuNappe.swift` : `GlypheMaison` (la maison tracée au trait),
`NeonMaison` (le néon blanc, recette `NeonPrimaryButton`), `GaletMaison`
(verre natif + encre au-dessus du conteneur + souffle ±2 % sur 4,3 s),
`MenuNappe` (la brume), `MenuItems` (`View, Animatable` — les rampes
échelonnées ne jouent pas sous un `withAnimation` ordinaire), `MenuHote`
(la chorégraphie), `MenuLab`. Bancs : `-menuLab`, `-menuRejoue`.

**La chorégraphie est pilotée par le BINDING, pas par le tap** — sans ça le
banc ne peut pas l'ouvrir (le simulateur ne sait pas poser un doigt) et la
page ne pourra pas l'ouvrir non plus depuis ailleurs.

**Le verre natif fonctionne ICI** : le galet posé au-dessus de la nappe de
flamme de la vidéo a enfin de quoi réfracter — vérifié à la capture, il
brille. C'est l'exception à la loi du verre à jeun, et elle tient parce que
l'endroit est choisi.

**Une correction en route** : le verre `.clear` seul est presque INVISIBLE
sur un fond déjà doux — il floute sans blanchir, et la nappe ne se lisait
pas. Il lui faut un **lait très bas** dessous (blanc 0 → 0,085 du haut vers
le bas) : pas un voile gris, une brume qui monte avec la lumière qu'elle
recouvre.

### 13.2 LA NAPPE, REPRISE — « pourquoi t'as mis du blur ? c'est pas liquid »

Verdict juste, et la faute est nommable en une phrase :

> **LE LIQUID GLASS SE LIT PAR SES BORDS.** Le corps d'une nappe de verre
> posée sur du contenu doux ne montre presque rien : ce qui dit « verre »,
> c'est le LISERÉ SPÉCULAIRE et la LENTILLE au bord. En fondant le bord haut
> au masque pour faire un « halo fondu », j'ai supprimé **exactement** ce qui
> faisait le verre. Il ne restait que le flou — donc un frost.

Deux fautes de plus, en cascade :
1. **Le lait aggravait.** Ajouté pour rendre la nappe visible, il blanchit
   UNIFORMÉMENT — c'est la signature d'un frost, pas d'un verre. Il traitait
   le symptôme (« on ne la voit pas ») en renforçant la cause.
2. **La nappe débordait la card** : elle allait jusqu'au bord de l'ÉCRAN
   alors que la grande card s'arrête 10 pt avant, avec des coins de 45. Elle
   passait donc sur le noir de la page → la bande bizarre du bas.

**LE NOUVEAU PLAN, en trois points :**

- **Un bord haut NET, jamais fondu.** C'est ce que montre sa propre
  maquette : une arête droite, pleine largeur, avec la card visible
  au-dessus. Cette arête porte le liseré spéculaire du verre natif, et c'est
  elle qui fait la matière. Le « fondu » ne se joue plus sur le bord mais sur
  la MONTÉE (l'arête balaie l'écran).
- **La nappe est CLIPPÉE à la forme de la grande card.** Son bord haut reste
  droit et pleine largeur ; ses coins bas épousent ceux de la card. Plus
  aucune bande sur le noir.
- **Plus de lait.** Le verre `.clear` seul, avec son bord — et si le corps
  reste discret, tant mieux : c'est le bord qui parle.

Ce qui ne change pas : la lumière avant la géométrie, la cascade des items du
bas vers le haut, le recul de la page, l'élu qui reste à la fermeture.

### 13.3 LA NAPPE EST MORTE — ce sont des HALOS

Verdict : *« non horrible, ça fait blur… je préfère des halos fondus noirs en
bas de l'écran et un peu haut »*.

**La faute de fond, et elle est plus grave que les réglages :** je me suis
entêté à faire une FEUILLE. Or une feuille a des bords — et un bord, ici,
c'est soit un frost (si on le fond) soit une boîte posée sur l'écran (si on
le garde net). Sur sa capture, ce qu'on voit est exactement ça : un
rectangle gris-brun aux trois côtés visibles, flottant sur la page. Il n'y a
pas de réglage qui sauve une feuille : c'est la FORME qui est fausse.

> **LOI : un halo n'a pas de bord. Une feuille en a forcément un. Si le
> dessin demande « fondu », alors l'objet ne peut pas être une surface — ce
> doit être une LUMIÈRE (ici une ombre).**

**Le nouveau plan, et il est plus simple que tout ce que j'ai essayé :**

- **Plus aucun verre dans le fond du menu.** Le `glassEffect` reste là où il
  a un bord légitime et de quoi réfracter : LE GALET, qu'elle a validé.
- **Le fond du menu = deux ou trois HALOS NOIRS**, ancrés hors du cadre sous
  le bas de l'écran, de grand rayon, qui s'éteignent complètement avant
  d'atteindre leur bord. Aucun rectangle, aucun clip, aucune arête : il n'y a
  rien à border, donc rien qui puisse se lire comme une boîte.
- **Plusieurs foyers, pas un dégradé droit** : un grand au centre-bas, deux
  plus petits aux coins. Un dégradé linéaire se lit comme un calque ; des
  foyers qui se recouvrent se lisent comme de la lumière.
- **Ils montent « un peu haut »** — le grand atteint ~62 % de la hauteur,
  mais son dernier tiers est déjà à zéro : ce qu'on voit finir est bien plus
  bas que ce qui est dessiné.

Ce qui ne change pas : la lumière avant la géométrie, la cascade des items,
le recul de la page sans ressort, l'élu qui reste à la fermeture.

### 13.4 LES HALOS SONT LUMINEUX — et la transition tient à UN seul curseur

Verdict : *« je vois pas de halo, que du full noir — je m'attendais à des
effets de halo, et que le fond commence fondu en noir… et l'animation de
transition doit être superbe, c'est pas assez fluide »*.

**LA FAUTE DE LECTURE, et elle est bête :** « halo fondu noir » — j'ai fait
des halos NOIRS. Elle voulait des halos **LUMINEUX** sur un fond qui
**commence** fondu en noir. Son tout premier brief le disait déjà mot pour
mot : *« le bas devient un blur gradient de halos jaune / orange / blanc »*.
Un halo noir n'est pas un halo, c'est une ombre — et une ombre sur du noir ne
se voit pas. D'où « que du full noir ».

**LE FOND DU MENU, en deux couches et dans cet ordre :**

1. **LA NUIT QUI COMMENCE FONDUE.** Un noir qui naît de rien en haut de la
   zone et qui se densifie en descendant — c'est lui qui rend les titres
   lisibles, et son bord haut n'existe pas.
2. **LES HALOS, PAR-DESSUS, EN LUMIÈRE AJOUTÉE** (`.plusLighter`) : trois ou
   quatre foyers chauds — ambre `1,00/0,62/0,24`, orange, et un cœur presque
   blanc — de grand rayon, posés bas, qui RESPIRENT sur des périodes
   premières entre elles. Ce sont eux qu'on doit voir ; la nuit n'est là que
   pour les porter.

⚠️ Et la loi de couleur de la maison s'applique : la rampe s'écrit **en
canaux** (on éteint le bleu puis le vert quand la lumière tombe), jamais en
interpolation entre deux teintes — le chemin droit passe par le brun.

**LA TRANSITION : UN SEUL CURSEUR, PAS UNE CHAÎNE DE MINUTEURS.**

L'ancienne chorégraphie enchaînait quatre `DispatchQueue.asyncAfter`
(0,10 · 0,26 · 0,42). Chaque réveil est une MARCHE : quatre animations qui
démarrent chacune de son côté ne peuvent pas être fluides, et c'est
exactement ce qu'elle sent.

La forme juste est celle de la phrase de la home (`PhraseVue: View,
Animatable`) : **une seule grandeur `p` de 0 à 1**, animée UNE fois, dont
chaque pièce dérive son propre avancement avec son propre retard.

| pièce | fenêtre sur `p` |
|---|---|
| la nuit et les halos | 0,00 → 0,34 |
| la montée | 0,06 → 0,74 |
| les items (cascade du bas) | 0,30 → 1,00, 0,055 de retard chacun |
| le glyphe → chevron | 0,46 → 0,86 |

Une seule courbe (`.timingCurve(0.22, 1, 0.36, 1)` — la courbe d'Apple pour
les feuilles), 0,78 s. Tout est continu par construction, il n'y a plus une
seule marche.

### 13.5 LE MENU EN « ULTRA PREMIUM » — le plan des micro-interactions

Verdict : *« ça passe, mais comment rendre encore plus premium… quand on
ferme, il y a une sorte de décalage de tout l'écran… je voudrais des micro-
interactions, plein de micro-animations… la police en dégradé blanc aussi…
et quand on passe dessus au drag sur les sections, qu'il se passe quelque
chose avec du liquid glass… quelque chose de vraiment sublime, même si on
fait 20 tours »*.

#### A. LE DÉCALAGE — le diagnostic, et il n'est pas dans la courbe

J'ai déjà retiré le ressort ; il reste. La vraie cause est ailleurs :

> **JE FAIS RECULER LA VIDÉO.** `scaleEffect` sur `GrandeCardVideo`, c'est
> une transformation appliquée à un `AVPlayerLayer` — une couche UIKit qui
> n'interpole PAS dans la transaction SwiftUI et qui recalcule son cadrage
> `resizeAspectFill` à chaque changement de bounds. Elle saute au lieu de
> glisser, et comme elle occupe tout l'écran, c'est TOUT l'écran qui semble
> se décaler.

**Le remède, et il est plus juste physiquement : le FOND ne recule pas, le
CONTENU recule.** La vidéo est le monde, elle reste ; ce sont la phrase, les
cards et la semaine qui s'éloignent (échelle 0,974 + voile). Un monde qui
bouge quand on ouvre un menu n'a d'ailleurs aucun sens.

#### B. LES MICRO-INTERACTIONS — ce que je propose

**1. LE GALET, quatre états au lieu de deux**
- doigt POSÉ (avant le tap) : le verre se creuse (`.interactive()` le fait
  déjà) et le néon monte de 15 % — on sent qu'il a compris avant qu'on lâche ;
- au tap : **une ONDE part du galet** — un anneau très fin qui s'étale à
  travers les halos et meurt en 0,5 s. C'est elle qui « allume » la nappe ;
- maison → chevron : **un MORPHISME, pas un fondu croisé** — le toit se
  replie et devient le chevron (deux `Path` interpolés) ;
- haptiques : `.soft` à la pose, `.rigid` à l'ouverture pleine.

**2. LE DRAG SUR LES SECTIONS — la pièce maîtresse**

C'est là qu'elle attend le sublime, et la maison a déjà LA bonne pièce : la
**loupe du panneau 3-7**, celle qu'elle a validée (« garde le zoom natif »).
On la remonte ici, verticale :

- **un galet de liquid glass SUIT le doigt** le long de la colonne ;
- sous lui, le titre est **GROSSI** (zoom ×1,55, gaussienne de portée 34) et
  monte de quelques points — l'école exacte de la loupe de la barre d'Apple ;
- il **s'AIMANTE** d'un item à l'autre : jamais posé entre deux, avec un
  **cran haptique** à chaque passage ;
- il **s'ÉTIRE** en changeant d'item — une capsule qui se déforme, pas un
  rectangle qui saute (`glassEffectID` + morphisme natif) ;
- les voisins **reculent** (0,96) et pâlissent : la loupe creuse un puits ;
- au lâcher : le galet se **referme** sur l'élu, coup lourd, et la nappe part.

⚠️ Les deux lois du verre s'appliquent : l'encre AU-DESSUS du conteneur (le
titre grossi ne vit pas dans le verre, sinon il est lentillé), et le galet
garde une TAILLE de layout constante (c'est son contenu qui change), sinon
le flou devient plat pour toujours.

**3. LA TYPO EN DÉGRADÉ BLANC** — oui, et deux crans plus loin :
- au repos, le dégradé vertical des gros chiffres des cards
  (#FFFFFF → #C9C9C9) ;
- **sous la loupe, le dégradé se DÉPLACE** : le blanc suit le galet le long
  du mot. C'est ce glissement qui fait lire « métal poli » et pas « texte
  gris ».

**4. LES HALOS QUI RÉPONDENT**
- le foyer le plus proche du doigt gagne 12 % : la lumière suit la main ;
- au choix d'un item, une **pulse** part de lui et traverse les halos ;
- **dérive gyro** de ±6 pt (`SkyMotion` existe déjà) : le fond devient une
  scène et non un calque.

**5. LA FERMETURE QUI RACONTE**
- l'élu RESTE, les autres s'effacent d'abord (déjà prévu) ;
- puis l'élu **descend avec la nappe** et s'efface en dernier ;
- le galet reprend son souffle avec un dépassement discret — il « respire »
  après l'effort.

**6. REDUCE MOTION** : loupe sans zoom, halos fixes, tout en fondus de 0,25 s.

#### C. L'ORDRE QUE JE PROPOSE

1. le décalage (le fond ne recule plus) — c'est un défaut, pas un ornement ;
2. la loupe au drag + l'aimant + les crans — la pièce maîtresse ;
3. la typo en dégradé et son glissement sous la loupe ;
4. l'onde du galet et le morphisme maison → chevron ;
5. les halos qui répondent au doigt, puis le gyro.

### 13.6 LES MICRO-INTERACTIONS — LIVRÉES (non commité)

`Woop/Views/MenuNappe.swift`. Bancs `-menuLab` (au doigt) et `-menuRejoue`
(l'ouverture en boucle).

**Le décalage est mort, et le diagnostic était le bon** : le fond ne recule
plus. `MenuHote` prend maintenant DEUX contenus — le `fond` (la vidéo, qui
ne bouge pas) et le `contenu` (le mobilier, qui s'éloigne). Une couche UIKit
ne sait pas s'échelonner dans une transaction SwiftUI : elle saute.

**Livré aussi** : la LOUPE de verre qui suit le doigt le long des sections,
aimantée item par item avec un cran haptique à chaque passage, les voisins
qui reculent et pâlissent ; la TYPO en dégradé blanc dont le blanc GLISSE
sous la loupe ; l'ONDE qui part du galet au tap ; le MORPHISME maison →
chevron (le toit se retourne, le corps se rétracte dans la pointe) ; les
HALOS qui gagnent 12 % près du doigt ; le néon qui monte à la POSE du doigt,
avant le tap. Tout est coupé sous Reduce Motion.

**⚠️ PIÈGE NEUF, et il vaut pour toute l'app : LE VERRE NATIF IGNORE
`.opacity`.** La loupe posée à opacité 0 se voyait quand même — elle restait
accrochée sur « Profil » au repos. Il faut la DÉMONTER (`if loupe > 0.01`).
Sa taille reste constante tant qu'elle est là, donc la loi des bounds
vivants est sauve.

### 13.7 LE MENU, PASSE PREMIUM — supprimer deux objets, ajouter dix détails

Verdict : *« la pastille liquid… un peu cheap. Je pense à quelque chose de
plus premium : la police plus fine de base, au drag elle se grossit un peu et
le reste devient un peu blur. Et le cercle qui apparaît quand je clique, pas
fan, trop cheap. Je veux des micro-détails partout. »*

**LES DEUX OBJETS À TUER, et pourquoi ils sonnent cheap — c'est nommable :**

> **1. LA PASTILLE DERRIÈRE LE TITRE.** Un chip posé derrière un mot est la
> grammaire d'Android et du web, pas celle d'Apple. Apple n'entoure jamais
> l'élément actif : il le rend **plus présent** et **éloigne les autres**.
> La sélection doit se dire par la TYPOGRAPHIE et la PROFONDEUR, pas par un
> contenant.
>
> **2. L'ANNEAU QUI S'ÉTALE.** C'est un *ripple* — la signature de Material
> Design. Apple ne fait jamais partir un cercle d'un bouton. Chez Apple, un
> bouton ne PROJETTE rien : il se comprime, et **c'est la scène qui répond**.

**CE QUI LES REMPLACE :**

**A. LA MISE AU POINT (au lieu de la pastille)** — son idée, et elle est la
bonne :
- au repos, les titres sont **fins** (Regular, tracking +0,02 em) ;
- sous le doigt : échelle **1,10**, graisse qui monte à **Medium**, blanc
  pur, et le tracking qui se **resserre** — le mot se densifie ;
- **les autres se FLOUTENT** (2,5 pt), pâlissent (0,55) et reculent (0,98).
  C'est le flou des voisins qui fait la profondeur, pas le fond ;
- au passage d'un item à l'autre, le flou du sortant MONTE pendant que celui
  de l'entrant TOMBE : un croisement, jamais une commutation.

**B. L'ALLUMAGE DIRECTIONNEL (au lieu de l'anneau)** — le galet ne projette
rien : il **allume la scène**. Les quatre halos s'allument **dans l'ordre de
leur distance au galet**, sur 0,25 s. On ne voit pas un cercle partir, on
voit la lumière se propager depuis la main. C'est la même loi que l'arrivée
de la home (la pièce s'allume avant que les mots n'existent).

**LES DIX MICRO-DÉTAILS, par ordre de coût :**

| # | où | ce qui se passe |
|---|---|---|
| 1 | galet, doigt POSÉ | compression 0,94 + néon +15 % + **le halo le plus proche gagne 8 %** — la lumière anticipe le tap |
| 2 | galet, relâchement | un dépassement à **1,02** avant de revenir : le « release » d'Apple, jamais un retour sec |
| 3 | titres, arrivée | le tracking se **resserre** de +0,06 à +0,02 em : le mot se POSE au lieu d'apparaître |
| 4 | titres, survol | échelle + graisse + tracking, **et rien derrière** |
| 5 | titres, voisins | flou 2,5 + opacité 0,55 + échelle 0,98, en croisement |
| 6 | fond, pendant le drag | les halos se **décalent de 6 pt vers le doigt** — parallaxe de la main |
| 7 | fond, pendant le drag | un **liseré chaud très fin** naît sur le bord gauche, à la hauteur de l'item survolé : le cadre répond |
| 8 | choix | flash blanc de 0,08 s sur l'élu, puis **pulse des halos depuis sa position** |
| 9 | fermeture | les halos s'éteignent **dans l'ordre INVERSE** de leur allumage |
| 10 | partout | dérive **gyro** de ±6 pt sur les halos et sur le reflet du galet |

**LES HAPTIQUES, et le silence en fait partie :** `.soft` à la pose,
`.selection` à chaque cran de la mise au point, `.rigid` au choix — et
**rien** à la fermeture. Un geste qui se termine dans le silence se sent
plus cher qu'un geste qui claque deux fois.

**Reduce Motion** : pas de flou des voisins (juste l'opacité), pas de
parallaxe, pas de gyro, tout en fondus de 0,25 s.

### 13.8 LA PASSE PREMIUM — LIVRÉE (non commité)

`Woop/Views/MenuNappe.swift`. Bancs `-menuLab` (au doigt) / `-menuRejoue`.

**Les deux objets tués :** la pastille de verre derrière le titre, et
l'anneau qui partait du galet.

**Ce qui les remplace :**
- **LA MISE AU POINT.** Les titres sont fins (Regular) et trackés ouvert au
  repos ; sous le doigt le titre grossit de 10 %, sa graisse monte à Medium
  (⚠️ **deux textes croisés** — SwiftUI ne sait pas interpoler une graisse),
  son tracking se RESSERRE (le mot se densifie au lieu de simplement
  grossir), et son dégradé glisse. Les voisins se floutent à 2,6 pt,
  pâlissent à 0,55 et reculent. Rien derrière.
- **L'ALLUMAGE DIRECTIONNEL.** Les quatre halos s'allument dans l'ordre de
  leur distance au galet (rang × 0,16 de retard sur le curseur) : on voit la
  lumière se propager depuis la main, pas un cercle partir.
- **LE DÉPASSEMENT DU GALET** : amortissement 0,55 — la compression est
  franche, le relâchement dépasse avant de se poser.
- **LE LISERÉ DU CADRE** : un fil chaud de 2 pt naît sur le bord gauche à la
  hauteur de l'item survolé.
- **LA PARALLAXE DE LA MAIN** : les foyers se décalent de 6 pt vers le doigt.
- **L'ARRIVÉE PROGRESSIVE** : retard porté de 55 à **90 ms** par item — à
  55 ms les quatre mots arrivaient presque ensemble et la cascade ne se
  voyait pas.

**⚠️ DEUX PIÈGES SWIFT PAYÉS ICI, et ils reviendront :**
1. **Un `onLongPressGesture`, même à 0,01 s, VOLE le tap qui le suit.** Le
   galet ne s'ouvrait plus. Un seul `DragGesture(minimumDistance: 0)` donne
   les deux : l'état « doigt posé » à `onChanged`, le tap à `onEnded` si le
   doigt n'a pas fui de plus de 40 pt. (Déjà payé sur le puits de l'iPod, où
   le tap devait être posé AVANT l'appui.)
2. **Le vérificateur de types SATURE** sur un titre dont toutes les mesures
   sont en une expression — et les découper en instructions dans un
   `@ViewBuilder` donne « type '()' cannot conform to 'View' ». La forme
   juste est un petit **type de mesures** calculé dehors, que la vue
   consomme.


## 14. LA PIÈCE DU TRÉSOR (25-08) — la porte du coffre, revenue de la v1

La demande : « il manque la pièce dans le coin qui connecte à la page
coffre — en noir pas or, plus premium, plus Apple, néon discret. » Puis le
verdict de première passe : « plus noir stp, c'est marron on dirait. »

**Livré.** `CoffreFortCoinButton` (le composant v1, inchangé pour la v1)
gagne un paramètre `matte` passé au shader `moonCoin` — la matière de la
page BRAVO : anthracite, reflets, tranche, croissant à 52 %. Posée en
haut-droit de `HomeNuitPage` (top 43 = l'œil de la première ligne de la
phrase, trailing 24 = la marge miroir du texte), elle suit la grammaire du
mobilier : née avec `arrivee`, éteinte par `net` (offset 8 + flou 6 +
opacité), sourde pendant l'édition et la vitrine. Tap → fumée claire puis
`CoffreFortFlow` en `fullScreenCover` (20 pièces la série, le corps
`CoffreFortPurse`). Banc : `-coffreSmoke` (le même nom que la v1).

**Le brun, mesuré et tué (MoonCoin.metal).** Le `matte` d'origine
n'éteignait que le métal : la LAQUE de la face gardait sa rampe ambrée
(15:7:2 en R:V:B au bord — de l'or sans son anneau, c'est du brun) et le
bain du néon (spill 0,185) vernissait toute la face. Sous `matte` : laque
graphite neutre à peine froide, vernis neutre, spill à 42 %. La pièce
d'or (matte 0) ne bouge pas d'un octet.

**⚠️ PIÈGE PAYÉ — l'overlay de fumée DANS le `contenu` de MenuHote ne
peint RIEN.** L'ancre se résolvait, `CoinSmoke` se montait (vérifié aux
prints : box juste, toucher reçu), et pas un pixel n'arrivait à l'écran —
sur film complet, zéro. Le MÊME code déplacé AU NIVEAU PAGE (au-dessus de
MenuHote, la grammaire exacte de la v1) peint normalement (pic mesuré
14/255 de moyenne dans l'anneau, p99,5 à 213). La préférence traverse la
hiérarchie, donc rien ne change au câblage — seul l'hébergement compte.
Non élucidé au fond (le trio identité `blur(0)/scale(1)/opacity(1)` du
retrait est suspect) ; la loi pratique : **les couches transitoires à
TimelineView se posent au niveau page, jamais dans `contenu:`**.

**La fumée est CLAIRE, et c'est mesuré** : la palette sombre du trésor
culmine ici à 0,45/255 de moyenne — invisible sur le coin noir absolu.

**Fouetté au film** (`-departAuto`, 15 i/s) : naissance en fondu avec
l'arrivée, extinction avec le mobilier au départ (la partition des cards,
`net` partagé), retour à la fermeture — aucun saut hors grammaire.
Captures : `shots/verdict-piece-noire-page.jpg` / `-crop.jpg`. Restent :
le verdict téléphone (haptique du tap, tintement, fumée réelle) et la
promotion du compte de pièces au vrai backend le jour venu.
