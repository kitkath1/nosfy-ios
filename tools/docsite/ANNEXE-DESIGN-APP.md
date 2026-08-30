# ANNEXE — Le langage design de l'app, relevé pour le CSS (sonde du 30-08-2026)

> Matière brute du plan `PLAN-SITE-PREMIUM.md` §3-4. Chaque valeur a sa preuve `fichier:ligne` dans l'app.

# Langage design de Woop — relevé pour un site de doc « premium noir Apple »

## 1. Le slider noir « obsidienne »

Vue : `/Users/kathryn/Desktop/woochoper-ios/Woop/Views/SliderObsidienne.swift` (863 l.)
Shader : `/Users/kathryn/Desktop/woochoper-ios/Woop/NavMonolith.metal:590` `[[stitchable]] sliderObsidienne(...)` (bloc `:549-838`).

| Élément | Valeur exacte | Preuve |
|---|---|---|
| Base du noir | **noir absolu #000000** sur la moitié basse ; la couleur ne vient que de ce qui s'y ajoute (`float3 rgb = float3(0.0)`) | `NavMonolith.metal:604` |
| Voile du haut | **blanc 10,0 %** (`piste.x = 0.100`) qui meurt à **60 % de la hauteur** (`piste.y = 0.60`), courbe `smoothstep` (plateau sur le 1ᵉʳ tiers puis chute) | `SliderObsidienne.swift:284`, loi `NavMonolith.metal:617-621` |
| Anneau noir (liseré sombre) | **obsidienne pure**, épaisseur `h × 0.056` (≈ 3,8 pt sur h=68), sortie franche ±0,45 pt | `SliderObsidienne.swift:284` / `NavMonolith.metal:612-613` |
| Liseré de flanc (reflet) | pic **23,9 % de blanc** (`0.239`, ×1,55 à l'armement), teinte `rgb(0.97, 0.98, 1.00)` ; profondeur `h×0.029`, demi-largeur `h×0.019`, centré **30° au-dessus de l'horizontale**, sigma **32°**, coupé net à +12/+34° | `SliderObsidienne.swift:269, 285-287` / `NavMonolith.metal:648-660` |
| « Cheveu » de crête | `0.004 + 0.011·topness^2.2`, teinte `rgb(0.86, 0.89, 0.95)` | `NavMonolith.metal:664-667` |
| Rayon | capsule pure (`nsdRound(p, halfB, halfB.y)`) ; hauteur **68 pt** → rayon 34 | `SliderObsidienne.swift:35`, `NavMonolith.metal:600` |
| Ombre portée | **62 % de noir**, étalement `h × 0.26` (≈ 17,7 pt), décalage y = 0, poids vertical en **carré** (0,04 en haut / 0,23 sur le flanc / 1,00 dessous) | `SliderObsidienne.swift:289-292` / `NavMonolith.metal:816-819` |
| Le pouce (chrome) | capsule couchée `medalH = h×0.683`, ratio **1,68** ; « puits » = blanc quasi constant **+11,5 %** (`0.115 + 0.020·(1-wy) + 0.014·press`) ; grossit ×1,12 sous le doigt | `SliderObsidienne.swift:145-147, 262`, `NavMonolith.metal:743-745` |
| Fil de métal liquide | `repetition 0.80`, `angle 94°`, `softness 0.20`, `contour 0.88`, `distortion 0.42`, `speed 0.20`, `shiftRed 0.017`, `shiftBlue 0.032`, `lineW 1.05 pt`, `glow 0.30`, `floorLevel 0.30`, **or = 0.0** (c'est du chrome) | `SliderObsidienne.swift:157-175` |
| Typo du libellé | `.system(size: h × 0.169 ≈ 11,5 pt, weight: .medium)`, **tracking `h × 0.050` ≈ 3,4 pt**, capitales | `SliderObsidienne.swift:325-327` |
| Encre du libellé | `LinearGradient(Color(white: 0.94) → Color(white: 0.54))`, top→bottom + halo blanc `blur 4, opacity 0.30, plusLighter` | `SliderObsidienne.swift:353-365` |
| **La lampe qui suit le pouce** | `RadialGradient(Color.white.opacity(0.50) → .clear)`, centre = x du pouce, `startRadius 0`, **`endRadius = medalW × 1.5`**, `blendMode(.plusLighter)`, masquée par le texte | `SliderObsidienne.swift:373-383` |
| Refus | la pierre rougit du dedans : `mix(rgb, float3(0.62, 0.13, 0.16), 0.20)` = **#9E2129** à 20 % | `NavMonolith.metal:637` |
| Braise du « déjà poussé » | `float3(1.00, 0.42, 0.16)` derrière le pouce, dose 0,02 max | `NavMonolith.metal:630` |

**La matière en 5 lignes (transposable CSS)**
1. Fond : `linear-gradient(to bottom, rgba(255,255,255,.10) 0%, rgba(255,255,255,.10) 20%, #000 60%, #000 100%)` sur `background:#000` — le voile MEURT à 60 %, la moitié basse est plus noire que la page.
2. Bord : `inset 0 0 0 4px #000` (l'anneau d'obsidienne), puis PAR-DESSUS un liseré de flanc `inset 0 0 0 1.3px rgba(247,250,255,.24)` visible surtout sur les calottes gauche/droite (jamais un contour d'égale intensité tout autour).
3. Crête : `inset 0 1px 0 rgba(219,227,242,.015)` en haut seulement — c'est ce cheveu qui donne une TRANCHE.
4. Ombre : `box-shadow: 0 0 18px rgba(0,0,0,.62)` large et molle, poids en bas (pas de contact dur), 0 offset horizontal.
5. Pouce : capsule `border-radius:999px`, `background: rgba(255,255,255,.115)` + un liseré chromé 1,05 px à franges (à imiter par `border:1px solid` + `background-image: conic/linear-gradient` argenté), `transform: scale(1.12)` au `:active`.

## 2. Le logo lune

La lune du splash est **dessinée en Metal**, pas en image : `Woop/LogoMonolith.metal` (le « monolithe » — un tube néon qui trace le croissant) piloté par `Woop/Views/MoonSplash.swift:44-64` (`MoonLanding.zoom = 0.70`, `faceR = 76` → face de 106 pt), la silhouette venant du SDF binaire `Woop/MoonSDF.bin`. Néon : `float3(1.00, 0.30, 0.045) → (1.00, 0.45, 0.135)` (`LogoMonolith.metal:671`), bloom `float3(1.00, 0.50, 0.16)` (`:849`).

**3 meilleurs candidats pour un logo de nav 24-28 px**

| # | Chemin | Dimensions | Pourquoi |
|---|---|---|---|
| 1 | `/Users/kathryn/Desktop/woochoper-ios/Woop/AppIcon.icon/Assets/lune (2).svg` | **749 × 718** (viewBox `0 0 749 718`), vecteur | LE choix : SVG, remplissage `linearGradient` **blanc → blanc 70 %** vertical (`stop-color="white"` / `stop-opacity="0.7"`), fond transparent. Se recolore en CSS, net à 24 px. Contient un `backdrop-filter: blur(12px)` d'origine Figma — à retirer. |
| 2 | `/Users/kathryn/Desktop/woochoper-ios/Woop/Assets.xcassets/sticker-pastille-lune.imageset/sticker_pastille_lune.png` | **863 × 846** | Pastille carrée noire pailletée, lune gravée en creux. Bon pour un favicon / avatar, trop de détail à 24 px. |
| 3 | `/Users/kathryn/Desktop/woochoper-ios/Woop/Media/carte-logo-ref.png` | **1254 × 1254** | Le logo « néon orange sur obsidienne » de référence — parfait en OG-image / hero, pas en nav 24 px. |

Autres : `Woop/Assets.xcassets/onb-lune-loop-poster.imageset/onb-lune-loop-poster.jpg` **1080 × 1644** (poster vidéo, plein cadre — inutilisable en logo). `Woop/Assets.xcassets/AppIcon.appiconset/` **ne contient AUCUN fichier image** (`Contents.json` seul, 3 slots 1024×1024 vides) — l'icône est produite par `Woop/AppIcon.icon/icon.json` : dégradé de fond **display-p3 `0.33273,0.33273,0.33273` → `0.00000,0.00000,0.00000`**, orientation verticale de y=0 à y=0,7, `shadow neutral 0.5`, `specular true`, `translucency 0.5`.

## 3. Les noirs et les blancs

**Le fond**
- Fond de page : **`Color.black` = #000000 pur**, répété : `HomeNuit.swift:172`, `:1027`, `:2249`, `:4049`, `:4090` ; `HomeAuroraView.swift:54, 59, 63, 955, 1039` ; `StorySuite.swift:43, 137, 972`.
- Les tokens historiques existent mais sont **teintés froid** : `.woopBase = rgb(0.016, 0.016, 0.024)` ≈ **#040406**, `.woopSheet = rgb(0.027, 0.027, 0.035)` ≈ **#070709** — `Woop/Theme.swift:23, 25`.
- `.woopCard = Color.black` **NOIR PUR assumé** — raison documentée : les photos d'exercice ont un fond noir absolu, toute plaque grise redessinerait leur rectangle (`Theme.swift:27-32`).
- Panneaux / cards : `LinearGradient(Color(white: 0.060) → Color(white: 0.030))` = **#0F0F0F → #080808** (`HomeNuit.swift:1248-1250`) ; variante story `Color(white: 0.105) → Color(white: 0.055)` = **#1B1B1B → #0E0E0E** (`StorySuite.swift:239-240`, `:1118-1119`) ; `Color(white: 0.15) → 0.07` (`StorySuite.swift:1402-1403`), `0.13 → 0.05` (`:3038-3039`), `0.07 → 0.015` (`:2680-2681`).
- Voiles noirs : `.black.opacity(0.72)` (`HomeNuit.swift:4182`), `0.55` (`:4101`), `0.45 radius 16 y 8` en ombre (`:776`). Scrim `SessionSlate.swift:160-169` : stops `.black 0.95 / 0.88 / 0.25` puis `0.97 / 0.95 / 0.88`.

**Les blancs (titres)**
- `WoopGradient.silverText` — encre argent des titres : `white 1.0 (0) → white .80 (0.62) → white .68 (1.0)`, top→bottom (`Theme.swift:150-158`).
- `WoopGradient.titleFade` — grand titre de fiche : `white 1.0 (0) → .90 (0.32) → .60 (0.68) → .25 (1.0)`, **en diagonale `topLeading → bottomTrailing`** (le commentaire explique : un dégradé horizontal fait clignoter les titres sur deux lignes) — `Theme.swift:166-176`.
- Mot géant story : `Color(white: 0.94) → Color(white: 0.26)` = **#F0F0F0 → #424242** (`StorySuite.swift:605-607`).
- Titre argenté 3 arrêts : `white 0.98 → rgb(0.78,0.79,0.84) → white 0.40` (`StorySuite.swift:2860-2863`).
- Trait/lame argent : `white .95 → white .25` (`SessionSlate.swift:468-469`).
- Encre des contrôles : `white .95 → white .52` (`Theme.swift:182-186`).
- Liseré diamant : `white .65 (0) → .10 (0.40) → .0 (1.0)` (`Theme.swift:118-124`).

**Les gris (encres)**
- `inkPrimary = .white.opacity(0.96)`, `inkSecondary = .white.opacity(0.55)`, `inkMuted = .white.opacity(0.30)` — `Theme.swift:57-59`.
- La phrase d'accueil : mot clair **1,00**, mot sourd **0,42** dans le noir / **0,54** dans la lumière — le chiffre 0,34 a été rejeté à la mesure (2,9:1 < 3:1) — `HomeNuit.swift:328, 337`. Pied de dégradé du bloc `argent = 0.86` (`:341`), masque `white → white.opacity(0.90)` (`:446-448`).
- Sous-titres story : `Color(white: 0.94)` titre / `Color(white: 0.55)` sous-titre (`StorySuite.swift:1094, 1099`) ; lignes de séance `0.92 / 0.34` et `0.94 / 0.52` selon l'état (`SessionSlate.swift:479, 483`).
- Traits/bordures : **`Color.white.opacity(0.06)`, `lineWidth: 1`** (`HomeNuit.swift:1251`) ; `white.opacity(0.08)` sur le chip de verre (`ChipVerre.swift:70`).

## 4. L'aurore orange / rouge

**L'aurore de la home** — `Woop/AuroraHome.metal:592-594` (palette), `:592-780` (loi) :
```
AU_BASE  = rgb(1.00, 0.54, 0.24)  → #FF8A3D   le pic, orange FRANC
AU_BRUME = rgb(1.00, 0.95, 0.94)  → #FFF2F0   la brume des ombres
AU_CREME = rgb(1.00, 0.90, 0.60)  → #FFE699   le cœur, or de néon
```
Géométrie du halo (`AuroraHome.metal:597-605`) : foyer à **86,3 % de la hauteur** (`AU_CY = 0.863`), λ montant **0,105**, λ descendant **0,099** (×2,75 sous le cœur), amplitude **1,069**. Dôme à sommet plat centré x≈0,475, largeur 0,190, exposant 2,93 ; deux épaules gaussiennes à **x = 0,122** (largeur 0,090) et **x = 0,833** (largeur 0,132). Le halo est éteint au-dessus de `smoothstep(0.28, 0.55, y)` — il prend l'écran à partir de la mi-hauteur (`:713`). Trame de points : pas 6,4 × 7,7 pt, rayon 0,72 pt, grain 0,28 (`:632-637`).
Loi de couleur (`:721-725`) : `bas = 0.56·(1 - v/0.664)^2.3` mélange vers la BRUME, `haut = 1.10·smoothstep(0.60, 0.995, v)^1.782` mélange vers la CRÈME, tone-map `v = 1 - exp(-E·1.75)` **à teinte conservée** (on comprime le niveau, jamais les canaux — c'est le remède au « burn »).

**L'aurore de fond (login / fiche)** — `Woop/AuroraBg.metal:64-73` :
```
BG_BASE  = rgb(1.00, 0.56, 0.31) → #FF8F4F   le pic, à L≈112
BG_OR    = rgb(1.00, 0.76, 0.33) → #FFC254
BG_BRUME = rgb(1.00, 0.95, 0.94) → #FFF2F0
BG_CREME = rgb(1.00, 0.93, 0.73) → #FFEDBA   ce que devient l'orange > 169
BG_BLANC = rgb(1.00, 0.99, 0.97) → #FFFCF7   le cœur
BG_GRIS  = rgb(0.91, 0.90, 0.89) → #E8E6E3
BG_JAUNE = rgb(1.00, 0.83, 0.42) → #FFD46B
```
Plancher rouge sombre du fond embrasé : `float3(0.130, 0.046, 0.010)` = **#210C03** (`AuroraBg.metal:525`) ; braise de réhaussement `rgb(1.00, 0.50, 0.19)` = **#FF8030** (`:405, 479`) et `rgb(1.00, 0.44, 0.10)` = **#FF701A** (`:571`).

**Le halo des exos (« page exo »)** — `Woop/ExosHalo.metal:32-36` :
```
EXH_CREME  = (1.000, 0.938, 0.790) → #FFEFC9
EXH_JAUNE  = (1.000, 0.830, 0.420) → #FFD46B
EXH_ORANGE = (1.000, 0.580, 0.280) → #FF9447
EXH_BRAISE = (1.000, 0.450, 0.160) → #FF7329
EXH_BLANC  = (1.000, 0.970, 0.900) → #FFF7E6
```
Pierre du bouton exo : `mix(rgb(0.0863,0.0902,0.1020), rgb(0.0196,0.0196,0.0275))` = **#161719 → #050507** (`ExosHalo.metal:235-236`).

**Les rouges (« harmonisation 22-08 »)** — la note d'harmonisation est en `Woop/Views/LiquidLensLab.swift:1190-1194` : l'encre orange-doré (0,62/0,22) a rejoint la **famille rouge/orange** `Color(red: 1.0, green: 0.48, blue: 0.18)` = **#FF7A2E** à 0,90.
Autres rouges vifs du dépôt : `#FF3309` (`StorySuite.swift:1046`, `:2602`), `#FF3814` (`:1654`), `#FF5719 → #9E0D05` en dégradé (`:1182-1183`), `#FF4506` (`CoffreV2.swift:989`), `#FF4504` (`DepartCine.swift:532`), `#FF3805` (`FlammeJauge.swift:619`), `#FF2E05` (`RewardCard.swift:1197`).
Néon de l'onglet actif (JewelTabBar) — 3 anneaux concentriques : `rgb(1.0, 0.40, 0.09)` **#FF6617** flou 6 / `rgb(1.0, 0.64, 0.22)` **#FFA338** flou 1,5 / `rgb(1.0, 0.98, 0.94)` **#FFFAF0** net 1,05 px, en `plusLighter` (`JewelTabBar.swift:354-366`).

**CSS d'approche** : `radial-gradient(120% 55% at 50% 86%, #FFE699 0%, #FF8A3D 34%, rgba(255,138,61,.22) 62%, #000 88%)` + deux épaules `radial-gradient(40% 30% at 12% 88%, …)` et `at 83% 88%`.

## 5. Le Liquid Glass

**118 occurrences** de `glassEffect|liquidLens|GlassEffectContainer|ultraThinMaterial` dans `Woop/Views/*.swift`, réparties sur **33 fichiers**. Décompte : `.clear` **34**, `.regular` **14**, `GlassEffectContainer` **16**, `liquidLens` **9**, `.ultraThinMaterial` **7**.

Teintes canoniques : `.regular.tint(.black.opacity(0.5))` (`ChipVerre.swift:50-52`, `BoosterPopup.swift:804`, `HomeAuroraView.swift:291`), `0.45` (`ConnexionButtonLab.swift:286`, `ExerciseEditor.swift:531`), `0.32` (`ActiveWorkoutView.swift:245`), `0.30` (`SessionSlate.swift:156`) ; verre de JOUR = **même verre, tint BLANC 0,42** (`ChipVerre.swift:64-66`). Liseré : **blanc 0,08 sur la nuit / noir 0,10 sur la lumière, 1 px** (`ChipVerre.swift:69-74`). Forme de référence du chip : **44 × 44, rayon 15 continu** (`ChipVerre.swift:9`).

**La loi de la maison** (`.claude/skills/woop-architecture/SKILL.md:132-148`), en 5 lignes :
1. `glassEffect(.regular)` est **INTERDIT** pour tout objet « liquid glass » — c'est le givré laiteux, la source de dix reproches (`SKILL.md:134-135`).
2. `glassEffect(.clear)` est le verre validé, mais il **réfracte aux bords et givre l'intérieur** : il ne marche que sur du contenu **DOUX** — halos, dégradés, lumière (`SKILL.md:136-138`).
3. Du contenu **NET** sous un verre (texte, glyphes) = seulement la calotte `liquidLens` (`SKILL.md:139-140`).
4. `.blur` pose un **voile UNIFORME sur tout le rectangle de l'hôte** — ce n'est pas un flou local (`SKILL.md:141-142`) ; un verre aux bounds vivants devient un blur plat définitif (`:145-146`).
5. Loi anti-brun des ambiances chaudes : « **R reste à 1,00, on désature le VERT** » — la saturation TIENT (`SKILL.md:147-148`).

**Traduction CSS** : `backdrop-filter: blur(24px) saturate(140%); background: rgba(0,0,0,.50); border: 1px solid rgba(255,255,255,.08); border-radius: 15px;` + reflet `background-image: linear-gradient(to bottom, rgba(255,255,255,.07), transparent 55%)`. À ne poser QUE sur du contenu doux (halo, dégradé) — jamais au-dessus d'un texte.

## 6. La typo

- **Une seule famille : Inter**, en 5 graisses statiques `.otf` dans `/Users/kathryn/Desktop/woochoper-ios/Woop/Fonts/` : `Inter-Light`, `Inter-Regular`, `Inter-Medium`, `Inter-SemiBold`, `Inter-Bold`. Mappage : `Font.inter(_:_:)` — `.bold/.heavy/.black → Inter-Bold`, `.semibold → Inter-SemiBold`, `.medium → Inter-Medium`, défaut → `Inter-Regular` (`Woop/Theme.swift:8-18`). Décrite comme « la linéale de l'app : néo-grotesque neutre dessinée pour l'écran — le registre *minimal premium* qui remplace le SF Rounded d'origine » (`Theme.swift:5-7`).
- **SF Rounded subsiste** dans les écrans anciens (`ActiveWorkoutView.swift`, `CalendarView.swift`, `AuthView.swift` : `.font(.system(…, design: .rounded, weight: .semibold))`) — c'est le legacy, pas le registre cible.
- Cotes typiques :
  - Titre de section : `.inter(19, .semibold)` + `WoopGradient.silverText` (`Theme.swift:395-397`).
  - Phrase d'accueil : `.inter(30, .semibold)`, **tracking −0,4**, interligne 2 pt (`HomeNuit.swift:316-320, 495-496`).
  - **Libellé de bouton primaire (le registre « gravé ») : `.inter(13.5, .semibold)`, `textCase(.uppercase)`, `tracking: 2.4`, `white.opacity(0.95)`** (`Theme.swift:352-356`).
  - CTA diamant : `.system(size: 13.5, weight: .medium)`, **`tracking: 4.6`**, capitales, dégradé `white → .86 → .54` (`ConnexionButtonLab.swift:227-236`).
  - Slider : `size h×0.169 (≈11,5)`, `.medium`, **tracking h×0.050 (≈3,4)** (`SliderObsidienne.swift:325-327`).
  - Chiffres : toujours `.monospacedDigit()` (`SessionSlate.swift:477`, `BravoLab.swift:694`).
  - Bouton secondaire : `.inter(14.5, .medium)`, `inkPrimary` (`Theme.swift:381-382`).

## 7. Pièces / booster

- **Or** : `.woopGold = rgb(0.949, 0.749, 0.325)` = **#F2BF53** (`Theme.swift:50`). Pièce 3D : `GOLD = rgb(1.000, 0.762, 0.318)` **#FFC251**, `GOLD_HOT = rgb(1.000, 0.898, 0.606)` **#FFE59B**, `GOLD_DEEP = rgb(0.238, 0.130, 0.026)` **#3D2107** (`Woop/MoonCoin.metal:156-161`) ; laque du fond `rgb(0.0055, 0.0038, 0.0026)` (`:300`).
- **Argent / verre** : `VERRE = rgb(0.780, 0.790, 0.800)` **#C7C9CC** (mixé vers `rgb(0.980, 0.660, 0.300)` #FAA84D quand teinté), reflet `rgb(1.000, 0.965, 0.870)` **#FFF6DE**, laque `rgb(0.0022, 0.0021, 0.0024)` — `Woop/PieceVerre.metal:175-178, 305`. Néon de pièce : `NEON_COEUR = rgb(1.000, 0.930, 0.780)` **#FFEDC7**, `NEON = rgb(1.000, 0.520, 0.105)` **#FF851B** (`PieceVerre.metal:377-378`).
- Assets : `piece-or.png` / `piece-argent.png` **2880 × 2560** ; `piece-or-mini.png` / `piece-argent-mini.png` **132 × 132** ; `booster-orange.png` **1054 × 1408** (pas de hex en code — c'est un rendu bitmap, à échantillonner si besoin).
- Violet legacy (encore dans `Theme.swift` mais explicitement retiré des composants : « le violet a quitté les steppers », `Theme.swift:178-181`) : `.woopViolet #A58BFF`, `.woopVioletCore #855DFF`, `.woopVioletDeep #5C36D8`.

---

## TOKENS PROPOSÉS POUR LE CSS

| Variable | Valeur | Provenance (fichier:ligne) |
|---|---|---|
| `--noir` | `#000000` | `Woop/Theme.swift:27` (`woopCard = Color.black`) ; fond de page `HomeNuit.swift:172`, `HomeAuroraView.swift:54` |
| `--noir-froid` | `#040406` | `Woop/Theme.swift:23` (`woopBase = rgb(.016,.016,.024)`) |
| `--panneau` | `linear-gradient(#0F0F0F, #080808)` | `Woop/Views/HomeNuit.swift:1248-1250` (`Color(white:.060) → .030`) |
| `--panneau-haut` | `#1B1B1B` | `Woop/Views/StorySuite.swift:239` (`Color(white: 0.105)`) |
| `--trait` | `rgba(255,255,255,.06)` — 1 px | `Woop/Views/HomeNuit.swift:1251` (`strokeBorder(.white.opacity(0.06), lineWidth: 1)`) |
| `--trait-verre` | `rgba(255,255,255,.08)` — 1 px | `Woop/Views/ChipVerre.swift:69-70` |
| `--encre-vive` | `rgba(255,255,255,.96)` | `Woop/Theme.swift:57` (`inkPrimary`) |
| `--encre-calme` | `rgba(255,255,255,.55)` | `Woop/Theme.swift:58` (`inkSecondary`) |
| `--encre-sourde` | `rgba(255,255,255,.42)` | `Woop/Views/HomeNuit.swift:328` (`sourd = 0.42`, retenu après mesure de contraste 3,4:1) |
| `--titre` | `linear-gradient(160deg, #fff 0%, rgba(255,255,255,.90) 32%, rgba(255,255,255,.60) 68%, rgba(255,255,255,.25) 100%)` | `Woop/Theme.swift:166-176` (`WoopGradient.titleFade`, diagonale obligatoire) |
| `--verre` | `rgba(0,0,0,.50)` + `backdrop-filter: blur(24px)` | `Woop/Views/ChipVerre.swift:9, 50-52` (recette maison : rayon 15, tint noir 0,5) |
| `--reflet` | `linear-gradient(to bottom, rgba(255,255,255,.65) 0%, rgba(255,255,255,.10) 40%, transparent 100%)` | `Woop/Theme.swift:118-124` (`diamondRim`) |
| `--aurore-1` | `#FFE699` (le cœur, or de néon) | `Woop/AuroraHome.metal:594` (`AU_CREME = 1.00, 0.90, 0.60`) |
| `--aurore-2` | `#FF8A3D` (le pic, orange franc) | `Woop/AuroraHome.metal:592` (`AU_BASE = 1.00, 0.54, 0.24`) |
| `--aurore-3` | `#FFF2F0` (la brume des ombres) | `Woop/AuroraHome.metal:593` (`AU_BRUME = 1.00, 0.95, 0.94`) |
| `--rouge` | `#FF7A2E` | `Woop/Views/LiquidLensLab.swift:1194` (harmonisation 22-08 : `rgb(1.0, 0.48, 0.18)`) |
| `--or` | `#F2BF53` | `Woop/Theme.swift:50` (`woopGold = rgb(.949, .749, .325)`) |

*(17 lignes ; si la limite de 15 est stricte, supprimer `--noir-froid` et `--panneau-haut`, les moins portants.)*

**Bouton primaire « en matière de noir » (recette CSS directe, depuis `Woop/Theme.swift:341-378`)** — c'est le velours du `WoopPrimaryButtonStyle`, jumeau CSS-able du slider :
`border-radius:15px; padding:16px 0; font:600 13.5px Inter; text-transform:uppercase; letter-spacing:2.4px; color:rgba(255,255,255,.95);`
`background: radial-gradient(120% 180% at 50% -55%, rgba(255,255,255,.14), transparent 70%), linear-gradient(#2A2A32 0%, #16161B 52%, #0A0A0D 100%);`
`border:1px solid transparent; box-shadow: 0 10px 18px rgba(0,0,0,.70), inset 0 1px 0 rgba(255,255,255,.65);`
(valeurs exactes : `rgb(0.165,0.165,0.195)` → `rgb(0.088,0.088,0.108)` @52 % → `rgb(0.038,0.038,0.052)`, `Theme.swift:361-365` ; halo `white .14` centre `(0.5, −0.55)` rayon 240, `:372-377` ; ombre `.black .70 radius 18 y 10`, `:381` ; liseré `white .65 → .10 @0.4 → 0 @1.0`, `:385-392`).