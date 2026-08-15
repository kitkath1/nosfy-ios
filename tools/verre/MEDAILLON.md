# LE MÉDAILLON — ORDRE DE BATAILLE

*Synthèse de six sondes indépendantes (fond, anneau, bague, glyphe, géométrie, lecture visuelle) sur `t16b.png` contre `REF_CROP` / `REF_HD`. Document de travail : à relire à chaque tour. Tout ce qui n'est pas dans l'ATLAS est interdit.*

---

## 0. PRÉALABLE — LE RÉFÉRENTIEL (à geler AVANT le tour 1)

### 0.1 Conventions, non négociables

| grandeur | définition |
|---|---|
| angles | **0° = droite, 90° = bas, 180° = gauche, 270° = haut** (y descend). Donc 45° = bas-droite, 210° = haut-gauche, 320° = haut-droite. |
| luma L | moyenne des trois canaux **encodés** (aucune linéarisation gamma). Un shader en espace linéaire convertit avant de comparer. |
| chromie X | R − B |
| **R canonique** | **R50 = rayon à mi-hauteur de la chute externe** (le bord visible). Seule définition qui applique la même recette optique des deux côtés. |
| masse | ∫(L − base) dr sur R ± 3,2 pt, en pt·luma — **invariante de résolution**, c'est la cible à opposer en priorité |
| A_ras | L(R+0,5 pt) − fond local, fond = percentile 8 de L sur [R+2,5 ; R+12] pt du même rayon |

### 0.2 Les trois rayons ne sont pas le même rayon

C'est le premier piège du chantier : six sondes ont produit six valeurs de R (de 21,2 à 31,9 pt). Elles ne se contredisent pas, elles ne mesurent pas la même chose.

| définition | RÉF (CROP) | MOI | rapport |
|---|---|---|---|
| R au max de gradient | 29,85 | 29,10 | 0,975 |
| R à la crête du liseré | 30,70 | 28,05 | 0,914 |
| **R50 (bord visible) — CANONIQUE** | **31,34** | **29,01** | **0,926** |

Position de la crête du fil : **réf 0,98 R50 = 1,027–1,030 × R_gradient** (elle déborde sur la lèvre extérieure) ; **moi 0,967 R50 = 0,964 × R_gradient** (il est inscrit).

> ⚠ **Normaliser par la crête du liseré biaise en faveur du liseré inscrit** et masque l'écart n° 6 du diagnostic. Les rapports fournis par les sondes « anneau » et « glyphe » (normalisés crête) restent valides entre eux mais doivent être reconvertis en R50 avant d'être mélangés aux autres : ×0,980 côté réf, ×0,967 côté moi.

### 0.3 Ce que le brief affirmait, et qui est FAUX

Les six sondes convergent, indépendamment, vérification pixel à l'appui :

- **« Mon médaillon fait 42,5 pt (R = 21,2) »** → **FAUX**. Il fait **58,0 pt** (R50 = 29,01). Le code le confirme : `FlammeMedaillon` est un `.frame(width: 58, height: 58)`. R = 21,2 pt tombe *à l'intérieur du bol*, sur rien. Toute sonde qui remesure 42,5 pt a attrapé le disque intérieur.
- **« La référence est 44 à 60 % plus grande »** → **FAUX**. Elle fait 62,7–63,6 pt. **L'écart réel est de −8 % en diamètre, −16 % en surface.** La décision de layout change donc de nature : ce n'est plus un sauvetage, c'est un réglage.
- **Bornes de `REF_HD` (x 209–794, 1,6160 px/pt)** → **FAUX**. Le bord gauche de la carte est à x ≈ 176,4–179 ; la brillance à x = 796 est le **bord d'écran du téléphone**, pas la carte. Vrai bord droit ≈ 762–765. Échelle réelle **1,6144–1,6270 px/pt** (retenir **1,620 ± 0,006**).

### 0.4 Laquelle des deux références croire

| question | verdict | pourquoi |
|---|---|---|
| **niveaux absolus (luma, RGB, planchers)** | **REF_CROP seule** | REF_HD a les noirs écrasés (min exactement 0,0000). Régression REF_HD/REF_CROP sur la même grille polaire : **×0,54 dans les ombres, ×0,95 dans les hautes lumières**. REF_CROP partage le domaine photométrique de mon rendu (blanc du texte 0,976 vs 0,986 ; sombre de carte p50 0,082 vs 0,069) : **ses valeurs sont directement opposables à mon rendu.** |
| **formes, rapports, phases, positions** | **les deux, elles concordent** | corrélation 0,925–0,965 ; toutes les cibles de forme sont confirmées deux fois |
| **REF_HD apporte-t-elle de l'information ?** | **non** | c'est REF_CROP réagrandie ×1,19–1,20 puis recapturée (corrélation 0,855–0,88, pente 0,905). Elle sert de **contre-vérification de forme, jamais de source de niveau.** |
| **échelle de REF_HD selon la sonde « glyphe » (1,692 px/pt)** | **fausse** | elle a inclus le cadre du téléphone. Tous ses pt REF_HD sont **4,6 % trop petits** (son R = 29,96 vaut en réalité 31,40). **Ses fractions de R restent justes** (numérateur et dénominateur portent la même erreur). |

### 0.5 Le banc de mesure (à construire avant le tour 1)

1. **Un banc gelé** `-medFreeze` : le médaillon seul, animation figée à t constant, cadence hors sujet. Une seule image de chaque côté existe : **si le médaillon respire, un écart de niveau et un écart de phase d'animation sont indiscernables.** Tout se mesure gelé.
2. **Deux résolutions par capture** : le natif 3,0 px/pt **et** un ré-échantillonnage à 1,354 px/pt (celle de REF_CROP). Les cibles sensibles au flou (§4.8) se jugent **sur la version dégradée** ; toutes les autres sur le natif.
3. **Une seule sonde, un seul fichier, gelée** : elle prend une capture et rend PASS/FAIL ligne à ligne pour les cibles du tour en cours **et pour toutes les non-régressions des tours précédents**. Elle doit d'abord reproduire, sur `t16b.png`, les chiffres « MOI » de ce document à ±2 %.
4. **Vérifier `stat` du binaire avant toute capture.** Piège déjà payé deux fois dans ce projet : `xcodebuild | grep` renvoie le code de sortie de **grep**, un build cassé sort « exit 0 » et on mesure une app périmée pendant des heures.
5. **Sous-dossier préfixé par tour**, jamais la racine du scratchpad : trois sondes sur six ont vu leurs fichiers écrasés par des sessions parallèles (`fit.py` détruit, `kg.py` détruit par `kG.py` — le FS macOS est insensible à la casse). Commits **par chemins explicites** (piège payé : 32 000 fichiers avalés par l'index).

### 0.6 Où vit le médaillon dans le code

`Woop/Views/FlammeJauge.swift` → `struct FlammeMedaillon` (l. 575), appelé l. 219 dans `dalle`. C'est un empilement **SwiftUI**, pas un shader :

| couche | ligne | ce qu'elle produit aujourd'hui |
|---|---|---|
| « la niche » `Circle().fill(RadialGradient)` — centre `UnitPoint(0.5, 0.44)`, endRadius 34, stops (0,225/0,170/0,140) → (0,150/0,118/0,105) @0,62 → (0,085/0,068/0,070) @1,0 | ~617 | **le bol.** Centre **au-dessus** du milieu → c'est la source directe de la phase inversée (φ = 280°). endRadius 34 sur R = 29 → 1,17 R → la chute molle. Dernier stop B/R = 0,82 → le voile bleu. |
| « l'anneau » `Circle().strokeBorder(AngularGradient, lineWidth: 1.4)` | ~630 | **le fil.** `strokeBorder` dessine **vers l'intérieur** → liseré inscrit. Stop `flamme.opacity(0.88)` à la location **0,32 = 115°** → **c'est l'arc orange du bas, une ligne de code.** |
| « l'ambiance » `Circle().fill(RadialGradient(flamme…or…clear))` endRadius 29, `.plusLighter` | ~655 | la nappe chaude qui écrase le contraste du bol |
| `Image(systemName: "flame")`, `.font(.system(size: 26, weight:))`, rampe jaune→or→(1,0/0,66/0,24), `.shadow(or, r 2,6)` + `.shadow(flamme, r 6)` | 869–884 | **le glyphe.** Symbole SF vectoriel → bord net. Le halo n'est que deux ombres : trop faible au pied, trop étalé. |
| `FlammePalette.or = (1,0 ; 0,78 ; 0,38)` | 460 | B/R = 0,38 au lieu de 0,473 ; G/R = 0,78 au lieu de 0,883 → **l'encre orange** |

Frame **58 × 58**, `taille` = 1 au repos. Les cibles de layout se traduisent donc en `frame`, `padG` et alignement du `HStack` de `dalle`.

---

## 1. L'ATLAS — LA LOI

### 1.1 La loi centrale : DEUX sources, jamais mélangées

C'est le résultat le plus structurant des six sondes, et il explique la moitié des écarts d'un coup.

**Source A — interne, CHAUDE : la goutte du glyphe**, en (+0,031 ; +0,178) R, chromie +0,53.
Elle éclaire *tout l'intérieur du disque* et **rien d'autre** :
- le lavis (excès +0,27 sur le plancher), le halo du trait (excès +0,17 au pied) ;
- le fond du bol : gradient directionnel de phase **φ = 64–86° (retenir 71°)**, amplitude **12–20 %**, décroissante vers l'extérieur (20 % @0,60 R → 12 % @0,85 R) ;
- la zone sous la flamme (45–105°) est **×1,32 plus claire** ET **+0,030 à +0,070 plus chaude** que le secteur opposé (225–285°).
- **Discriminant décisif** : un bol concave éclairé par la carte produirait le même *sens* (clair en bas-droite) mais serait **neutre**. La réf est **plus chaude** là où elle est plus claire. → **c'est bien la goutte qui éclaire le bol, pas un spéculaire de cuve.** Un seul terme explique tout l'intérieur.
- **Elle ne sort JAMAIS du disque** : chromie extérieure ≤ +0,006 sur l'arc, ≤ +0,045 partout.

**Source B — externe, NEUTRE : la lumière de la carte, en haut-gauche (~205°)**, chromie +0,002 à +0,025.
Elle produit, et rien d'autre :
- la **bague** sur la rive du disque (190–230°, crête luma 0,916, RGB 0,916/0,919/0,914 — *le vert est la composante la plus haute*) ;
- le **verre allumé du flanc gauche** (L = 0,305 à d = 6 pt) contre le flanc droit noir (0,071) ;
- l'**asymétrie de la flaque** (fond à 5,0–6,0 pt à droite/bas, 7,0–9,0 pt en haut/gauche) ;
- le **silhouettage** du bord bas-gauche (événement E3).

**Le fil du liseré appartient aux deux** : quasi neutre partout (chromie médiane +0,097, **jamais > +0,181**), il porte deux « cheveux bijou » à droite (légèrement chauds, +0,113/+0,126) et deux zones de lumière de scène à gauche (neutres pures, +0,015/+0,025).

> **Mon rendu a UNE seule source, chaude, orientée vers le haut (φ = 280°), qui fait tout.** De là découlent, mécaniquement, les défauts n° 1, 2, 5, 6, 8 et 9 du diagnostic.

---

### 1.2 SYSTÈME A — L'ASSISE (layout)

| grandeur | cible | tolérance | actuel |
|---|---|---|---|
| diamètre D50 | **63,1 pt** (R50 = 31,55) | ± 1,5 | 58,0 |
| D50 / hauteur de carte | 0,500 | ± 0,015 | 0,463 |
| centre y / hauteur de carte | **0,565** | ± 0,010 | 0,655 |
| centre x (marge gauche) | **48,9 pt** (marge 17,4) | ± 1,0 | 43,6 (14,59) |
| marge haute | 39,4 pt | ± 2,0 | 52,99 |
| marge basse | 23,5 pt | ± 2,0 | 14,17 |
| rapport marge haute/basse | 1,66 | 1,50–1,85 | **3,74** |
| jeu bord du disque → bord gauche du « S » | 15,4 pt | ± 1,3 | 15,23 ✔ |
| circularité max(R)−min(R) sur 12 angles | ≤ 1 % de R | — | 0,6 % ✔ |
| ellipticité a/b | 0,99–1,01 | — | 1,000 ✔ |

**Les deux disques sont circulaires** (les 5,3 % d'étalement mesurés sur la réf tombent tous à 30/300/330°, c'est le détecteur qui accroche la flaque ; hors ces trois angles la réf s'étale sur 0,21 pt = 0,7 %). **Le mien est déjà meilleur : ne pas y toucher.**

Conséquence de layout : si G5 + G6 sont tenus, le titre « Séries » passe de x = 87,84 à **x ≈ 95,9 pt** (padG +2,8 ; frame 58 → 63,1 ; espacement du HStack inchangé à 14).

---

### 1.3 SYSTÈME B — LE BOL (le fond intérieur, glyphe masqué)

Le dégradé est **radial ET directionnel à la fois**. Mon rendu rate les deux.

**Composante radiale** (bande 150–225°, jamais de glyphe, REF_CROP) :

| r/R | 0,45 | 0,55 | 0,65 | 0,75 | 0,85 | 0,90 |
|---|---|---|---|---|---|---|
| **L cible** | **0,232** | **0,178** | **0,135** | **0,111** | **0,098** | 0,101 |
| normalisé | 1,000 | 0,769 | 0,581 | 0,477 | 0,423 | 0,435 |
| moi | 0,230 | 0,200 | 0,180 | 0,160 | 0,135 | 0,123 |

- **Chute L(0,45)/L(0,85) = 2,37×** (REF_HD confirme 2,44×) ; moi 1,71×.
- **Mi-hauteur du halo à r/R = 0,72** ; chez moi ≥ 0,95, c'est-à-dire jamais dans le disque. *La réf a un halo serré, j'ai une nappe large.*
- Plancher absolu (0,35 ≤ r/R ≤ 0,88) : **≤ 0,070** (réf 0,0663) ; moi 0,1080.
- **max/min du fond ≥ 3,50** (réf 3,79 ; REF_HD 4,46) ; moi 2,36.

**Composante directionnelle** : fit L(θ) = a₀ + b·cos(θ − φ)

| r/R | φ cible | b/a₀ cible | φ moi | b/a₀ moi |
|---|---|---|---|---|
| 0,60 | 64° | 20 % | 278° | 8 % |
| 0,75 | **71°** | **18 %** | 280° | 11 % |
| 0,85 | 86° | 12 % | 279° | 15 % |

- **Contraste angulaire par anneau** : réf 1,71× à 0,75 et 0,85 R ; moi 1,27 et 1,37.
- **Anneau 0,80–0,93 R, l'ombre du bol** : le plus sombre en **haut-gauche (240–270° : 0,0765–0,0800)**, le plus clair en **bas-droite (30° : 0,1346)**. Test simple : moyenne(240–300°) ≤ **0,90 ×** moyenne(0–60°) — réf 0,71 ; moi **1,20 (inversé)**.
- **Sous la flamme / opposé** (45–105° vs 225–285°) : L ×**1,30 à 1,35**, X **+0,030 à +0,070**. Moi ×0,75 à 0,84 et −0,023 à −0,027 : **inversé sur les deux axes.**

**RGB par anneau (cible, tolérance ±8 % relatif par canal) :**

| r/R | R | G | B | **B/R** | X/L | (moi R / G / B) |
|---|---|---|---|---|---|---|
| 0,45 | 0,350 | 0,231 | 0,120 | **0,34** | 0,98 | 0,315 / 0,230 / 0,152 |
| 0,60 | 0,258 | 0,177 | 0,099 | **0,38** | 0,89 | 0,244 / 0,188 / 0,138 |
| 0,75 | 0,152 | 0,113 | 0,075 | **0,49** | 0,70 | 0,200 / 0,156 / 0,124 |
| 0,85 | 0,124 | 0,091 | 0,067 | **0,54** | 0,62 | 0,169 / 0,131 / 0,108 |

**Paroi 0,72–0,92 R** : R/B ≥ **1,95** (réf 2,04), luma ∈ [0,090 ; 0,120] (réf 0,106), **canal bleu ≤ 0,080** (moi 0,113).

**Résidu par canal MOI − REF_CROP** — la mesure la plus actionnable, elle sépare deux défauts distincts par le rayon :

| bande | dR | dG | dB | lecture |
|---|---|---|---|---|
| **r/R ≥ 0,72** | +0,0405 | +0,0380 | +0,0433 | **un VOILE GRIS QUASI NEUTRE de +0,040** (écart entre canaux : 0,005). C'est littéralement « le fond noir qui manque ». |
| **r/R ≤ 0,62** | **−0,0153** | +0,0101 | **+0,0401** | le bleu est +0,040 trop haut, **le rouge −0,015 trop bas**. La braise proche est pâle et rosée. |

**Le centre du bol** (champ total, glyphe compris) : L(0,25 R) = **0,489** en réf, **0,329** chez moi — mon centre est **33 % trop sombre**. Rapport L(0,25 R)/L(fosse) : réf **5,5–6,3**, moi 2,7–2,8.

> ⚠ Piège de mesure : à r/R = 0,30 il ne survit **0 cellule sur 24** au masque du glyphe dans les trois sources, et à 0,45 seulement 4 sur 24 (secteur 180–225°). **Toute cible du fond sous 0,50 R est faiblement contrainte** — ne pas s'y battre.

---

### 1.4 SYSTÈME C — LA VIGNETTE INTERNE (la douve)

Le bol se referme sur une **fosse sombre juste sous le fil**, puis le fil, puis (dehors) la flaque. C'est cette alternance qui fait « serti ».

| grandeur | cible | tolérance | actuel |
|---|---|---|---|
| rayon du minimum du profil radial sur 0,60–0,99 R | **0,88 R** | 0,84–0,91 | **0,937–0,97** |
| niveau du minimum | **0,090** | ≤ 0,095 | 0,115–0,117 |
| niveau relatif à la crête du fil | **0,25 ×** | 0,15–0,35 | **0,48 ×** |
| L(0,25 R) / L(fosse) | **≥ 4,5** | (réf 5,5) | 2,7–2,8 |

Deux sondes concordent (0,86–0,90 R / plancher 0,078 ; 0,881–0,896 R / 0,17–0,29 × la crête). Chez moi : **il n'y a ni douve ni paroi, juste une pente douce.**

---

### 1.5 SYSTÈME D — LE FIL (le liseré)

#### La contradiction apparente entre deux sondes, et son arbitrage

- La sonde « anneau » : *« la réf n'a PAS un liseré continu, elle a QUATRE arcs séparés »* (critère : contraste > 0,20 au-dessus du plancher extérieur).
- La sonde « lecture visuelle » : *« le sien fait le tour complet, luma > 0,20 sur 83 % du tour »* (critère : luma absolue).

**Les deux ont raison, ce sont deux critères différents.** La loi est :

> **Le fil de la référence est CONTINU en présence (luma de crête ≥ 0,18 dans les 12 secteurs, de 0,182 à 0,724) et MODULÉ ×10,2 en contraste, avec quatre événements.**
> Le mien est l'inverse : **modulé seulement ×4,5 mais absent en absolu sur le haut** (au-dessus de 0,20 sur seulement 57 % du tour, et à 300° le bord du disque est un *minimum local*).

#### Section du trait — la forme, pas la largeur

| grandeur | cible | tolérance | actuel |
|---|---|---|---|
| **w90/w50 (pointe, pas plateau)** | **≤ 0,46** (réf 0,35–0,46) | — | **0,67–0,80** |
| largeur de crête w90 | ≤ 0,55 pt | — | 0,90–1,06 |
| FWHM médiane sur E1 | 0,034 R | ± 0,005 R | 0,049 R |
| FWHM médiane sur E2 | 0,038 R | ± 0,005 R | 0,045 R |
| position radiale de la crête | **0,98 R50 (= 1,03 R_gradient, DÉBORDANTE)** | 1,01–1,05 R_grad | 0,964 R_grad (inscrite) |
| **amplitude de (r_pic − R) sur 72 angles** | **≥ 0,60 pt** (réf 0,84 et 0,80) | — | **0,23 pt** |
| **amplitude de la FWHM sur 72 angles** | **≥ 1,20 pt** (réf 2,24 et 2,10) | — | **0,22 pt** |
| chromie au pic, TOUT angle | **≤ +0,19** (réf max +0,181) | — | **+0,692** |
| chromie/luma à la crête | ≤ 0,45 (réf médiane 0,271) | — | 0,697 |
| chromie médiane sur le tour | +0,097 | ± 0,04 | +0,162 |

#### TABLE-FIL — la loi angulaire (REF_CROP, luma de crête et chromie, tous les 10°)

*Directement transposable en stops d'`AngularGradient` : `location = θ/360`.*

| θ | L réf | X réf | | θ | L réf | X réf | | θ | L réf | X réf |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 0,151 | +0,066 | | 120 | 0,290 | +0,134 | | 240 | 0,365 | +0,083 |
| 10 | 0,230 | +0,103 | | 130 | 0,375 | +0,181 | | 250 | 0,301 | +0,058 |
| 20 | 0,334 | +0,141 | | **140** | **0,651** | +0,137 | | 260 | 0,268 | +0,039 |
| 30 | 0,447 | +0,149 | | **150** | **0,720** | +0,087 | | 270 | 0,208 | +0,024 |
| **40** | **0,495** | +0,103 | | 160 | 0,544 | +0,121 | | 280 | 0,216 | +0,042 |
| 50 | 0,409 | +0,113 | | 170 | 0,487 | +0,118 | | 290 | 0,220 | +0,061 |
| **60** | 0,235 | +0,092 | | 180 | 0,399 | +0,142 | | 300 | 0,234 | +0,093 |
| 70 | 0,183 | +0,077 | | 190 | 0,651 | +0,104 | | 310 | 0,423 | +0,171 |
| 80 | 0,177 | +0,063 | | 200 | 0,869 | +0,022 | | **320** | **0,525** | +0,099 |
| **90** | **0,167** | +0,054 | | **210** | **0,919** | **+0,015** | | 330 | 0,286 | +0,103 |
| 100 | 0,201 | +0,057 | | 220 | 0,718 | +0,025 | | 340 | 0,205 | +0,106 |
| **110** | 0,231 | +0,077 | | 230 | 0,455 | +0,142 | | 350 | 0,207 | +0,100 |

#### Les quatre événements

| | arc | pic | contraste max | FWHM | masse max | chromie | plancher extérieur | topologie radiale |
|---|---|---|---|---|---|---|---|---|
| **E1** « cheveu bijou bas-droite » | **18° → 52°** (34°) | 0,516 @ 42,5° | **0,43** | 1,05 pt = 0,034 R | **0,55** | +0,126 | 0,084–0,101 (noir) | **épaule à −1,65 pt, SILLON à −1,05 pt, profondeur 0,020, puis la pointe** — trois étages |
| **E2** « cheveu bijou haut-droite » | **303° → 332°** (29°) | 0,527 @ 317,5° | **0,46** | 1,18 pt = 0,038 R | **0,65** | +0,113 | 0,061–0,078 (noir) | **trait SEUL sur une épaule montante, PAS de sillon** — aucun max local en dedans du pic entre −3,0 et −0,3 pt |
| **E3** bord silhouetté | 130° → 178° | 0,740 @ 145° | — | 0,87–1,37 pt | — | +0,09 à +0,18 | **0,17 à 0,30 (clair)** | marche, pas trait |
| **E4** = **la bague** | 190° → 228° | 0,939 @ 205° | — | **2,2–3,0 pt** | 1,38 | **+0,015 à +0,025 (neutre pur)** | 0,34 à 0,44 | dôme large, aucune pointe |

- **Rapport E2/E1 des contrastes max : 1,07 ± 0,15.**
- **À 0° pile (plein est) le fil RETOMBE** : pic 0,151, contraste 0,083, FWHM 1,46 pt. **Les deux cheveux encadrent l'est, ils ne le traversent pas.**
- **Entre 60° et 110° et entre 340° et 10° : contraste < 0,16** (réf 0,053 à 0,151).
- **Centroïde angulaire de la masse : 197°** ± 12 (REF_HD 203,9°). Moi : **111,6°** → 85° d'erreur.
- **masse(flanc ouest 90–270°)/masse(flanc est 270–90°) = 2,05 ± 0,30.** Moi 1,44.
- **Modulation contraste max/min sur 72 angles ≥ 8,0** (réf 10,2 et 8,2). Moi 4,5.
- masse@90° ≤ 0,16 pt·luma. Moi 0,409 (**2,4× à 4,1× trop lourd entre 60 et 110°**).

> **E3 et E4 n'appartiennent pas au fil : ce sont la source B.** Les implémenter dans le fil (dans l'`AngularGradient`) serait une erreur d'architecture — E4 est neutre pur, large de 2,2–3,0 pt, et il vit hors du disque. Le fil proprement dit ne porte que **le plancher neutre + E1 + E2**.

---

### 1.6 SYSTÈME E — LA BAGUE (le flare neutre du haut-gauche)

**Verdict tranché, avec trois preuves indépendantes : elle est ATTACHÉE AU DISQUE** (rive spéculaire), **mais son intensité est pilotée par la carte.**

1. Le verre est aussi clair à 180° qu'à 210° (rapport 0,97–1,06) mais la bague y est **10 à 100 fois plus faible** (rapport 0,009–0,097). Si elle était le verre vu derrière le disque, les deux rapports seraient égaux. **Déphasage de 14–16° entre le max du verre (194–196°) et le max de la bague (208–210°).**
2. La crête épouse le cercle à **±0,16–0,20 pt** sur 40° d'arc. Une lumière de fond n'a aucune raison de faire ça.
3. **Un minimum local à R+6,0/+6,2 pt** sépare la bague de la lumière du coin de carte, qui **croît** au-delà (0,302 → 0,448 → 0,446). Une lumière occultée serait monotone.

*Nuance à ne pas perdre : la bague **n'existe que du côté où le verre est allumé** (corrélation A_ras vs fond +0,60 / +0,72). Elle est absente à 30–90° où le verre est noir. Géométrie au médaillon, photométrie à la carte.*

| grandeur | cible | tolérance | actuel |
|---|---|---|---|
| angle du sommet | **209°** | ± 3 | *(aucun)* |
| barycentre angulaire | 213° | ± 3 | — |
| largeur à mi-hauteur | 25° (198→223°) | ± 4 | — |
| pied à 25 % | 193° → 228° | ± 4 / ± 3 | — |
| **A_ras au sommet** | **+0,55** | ± 0,08 | **−0,001** |
| L(R+0,5)/fond local | 2,80 | ± 0,25 | 0,99 |
| luma absolue de la crête | **≥ 0,90** (réf 0,916) | ± 0,03 | 0,198 |
| rayon de la crête | **r/R = 0,99** | ± 0,01 | 0,966 |
| **\|chromie\| de R−0,3 à R+4 pt** | **≤ 0,020** (réf ≤ 0,006) | — | **+0,088 à +0,120** |
| mi-portée | r/R = 1,068 | ± 0,010 | — |
| chute à 10 % | r/R = 1,168 | ± 0,015 | — |
| excès < 0,02 au-delà de | r/R ≥ 1,20 | — | — |
| **masse ∫[R+0,5 ; R+4] au sommet** | **≥ 0,85 pt·luma** (réf 0,93/1,10) | 0,85–1,15 | **0,014** |
| somme sur 190/200/210/220/230° | ≥ 2,3 (réf 2,47/3,34) | — | 0,111 |
| contraste angulaire sommet/hors-arc | ≥ 10 (réf 11,0 et 19,6) | — | — |
| **A_ras médian HORS arc** | **+0,025 à +0,055** — *ne pas éteindre le reste du tour à zéro* | — | +0,004 |
| minimum local entre bague et coin de carte | r/R = 1,19 ± 0,03, ≤ 0,40 × la crête, puis +40 % avant 1,50 | — | aucun |

**Profil de décroissance — trois temps, ce n'est pas une gaussienne** : chute rapide (mi-hauteur à +2,0/+2,3 pt), **palier long** (excès 0,14 → 0,07 entre +3 et +5 pt), atterrissage net vers +6 pt.

**Le test de sertissage** (la formulation la plus lisible du défaut n° 1) : pour chaque secteur de 30° dans 120° → 240°,
`moyenne(L, 1,06–1,14 R) − moyenne(L, 0,90–0,96 R) ≥ +0,08`
Cibles : **+0,11 / +0,19 / +0,29 / +0,26 / +0,12** à 120/150/180/210/240° (± 0,05). **Aucun secteur ne doit être négatif.**
Aujourd'hui : −0,047 / −0,006 / −0,002 / −0,057 / −0,059 → **négatif sur 12 secteurs sur 12.**

---

### 1.7 SYSTÈME F — LA FLAQUE (l'ombre circulaire extérieure)

Un **creux circulaire** accroché au disque, présent dans tous les secteurs, dont la position est quasi constante (5,0 / 5,5 / 5,5 / 7,0 / 9,0 pt sur cinq secteurs différents). **Un dégradé de carte ne produit pas un creux circulaire.**

| grandeur | cible | tolérance | actuel |
|---|---|---|---|
| **A = L(anneau 4–9 pt) / L(anneau 1–4 pt)** | **0,60** | 0,52–0,70 | **1,073** (le verre MONTE) |
| position du fond de cuvette au-delà de la crête | **0,20 R** (≈ 6,3 pt) | 0,16–0,26 R | 0,11 R |
| profondeur du fond sous le plateau 15–20 pt | **23 %** | 18–30 % | 12,2 % |
| présence : L(d=6) < L(d=3) | **≥ 4 secteurs sur 5** | — | **0 / 5** |
| L(d=6)/L(d=3) par secteur | droite 0,92 · bas 0,91 · bas-droite 0,90 · haut 0,72 | ± 0,08 | 1,01 / 1,21 / 1,08 / 1,03 |
| remontée L(plateau 15–20)/L(fond) | 1,30 | 1,20–1,45 | 1,14 |
| bave externe du fil L(d=+3)/L(plateau) | 0,96 | 0,85–1,10 | 0,91 ✔ de justesse |

*Directionnalité* : le fond de cuvette est plus près du disque à droite/bas (5,0–6,0 pt) qu'en haut/gauche (7,0–9,0 pt) → source en haut-gauche, cohérent avec la source B. **L'amplitude directionnelle n'est pas chiffrable au-delà de ce constat** (les secteurs gauche et haut sont pollués par le halo de bord de carte et, sur REF_HD, par le rectangle rouge d'annotation).

---

### 1.8 SYSTÈME G — LE LIT (le verre de la carte autour du médaillon)

**Ce n'est pas « trop clair » : c'est plat.** Mon champ n'est pas éclairé du tout, il est teinté.

| secteur, L à d = 6 pt | RÉF (CROP) | MOI | verdict |
|---|---|---|---|
| gauche | **0,3049** | 0,2096 | **trop SOMBRE** |
| haut | 0,1124 | 0,0649 | trop sombre |
| bas | 0,1066 | 0,1390 | trop clair |
| bas-droite | 0,0894 | 0,1004 | trop clair |
| **droite** | **0,0706** | 0,1051 | **trop CLAIR (1,5×)** |
| **rapport gauche/droite** | **4,3×** | **2,0×** | **le gradient est écrasé de moitié** |

| grandeur | cible | actuel |
|---|---|---|
| chromie du fond sur 1,10–1,40 R | **≤ +0,045** (réf +0,0275 ; REF_HD +0,0106) | **+0,0935** |
| chromie du verre à d = 3 pt, secteur droite | ≤ +0,05 (réf +0,044 / +0,026) | +0,144 |
| niveau absolu du verre à d = 6 pt, droite | 0,047–0,071 | 0,1051 |
| grain : σ du résidu HF / moyenne locale, 1,10–1,42 R | ≤ 5 % (réf 2,1 %) | **10,7 %** |
| flare le plus clair | luma 0,50, à **1,05–1,17 R**, chromie **+0,002** | luma 0,443, à **1,35–1,47 R**, chromie **+0,122** |

---

### 1.9 SYSTÈME H — LE GLYPHE

#### H1. Silhouette

| grandeur | cible | tol. | actuel | état |
|---|---|---|---|---|
| largeur | 0,744 R | ± 0,025 | 0,729 | ✔ |
| aire / aire du disque | 0,180 | ± 0,012 | 0,177 | ✔ |
| bas (y max) | +0,49 R | ± 0,02 | +0,48 | ✔ |
| H/L | 1,355 | ± 0,030 | 1,422 | ✘ |
| sommet (y min) | −0,505 R | ± 0,020 | −0,56 | ✘ |
| centre dx | **+0,031 R** | ± 0,008 | −0,004 | ✘ |
| centre dy | −0,011 R | ± 0,012 | −0,043 | ✘ |
| flanc droit à y = 0 | +0,400 R | ± 0,015 | +0,36 | ✘ |
| flanc gauche à y = 0 | −0,315 R | ± 0,015 | −0,35 | ✘ |
| RMS de l'écart de forme normalisé (180 angles) | ≤ 0,030 | — | 0,055 | ⚠ *plancher de bruit inter-réf = 0,056 : ne pas viser mieux que 0,030* |

**La couronne du haut — le seul vrai défaut de forme.** Partout ailleurs l'écart de rayon tient dans ±2,4 % ; à **238° il vaut +62,2 %** et à 306° +23,5 %.

| largeur de silhouette à la profondeur… | 2 % | **5 %** | **10 %** | 15 % | 20 % | 30 % | 40 % |
|---|---|---|---|---|---|---|---|
| cible (moy. réf, en fraction de H) | 0,26 | **0,315** | **0,393** | 0,40 | 0,41 | 0,59 | 0,65 |
| moi | **0,011** | **0,161** | **0,322** | 0,391 | 0,448 | 0,517 | 0,609 |

**Ligne de crête (y min pour chaque x, en R) — c'est là que tout se joue :**

| x/R | −0,35 | **−0,30** | −0,25 | −0,20 | 0,00 | +0,20 |
|---|---|---|---|---|---|---|
| cible | +0,03 | **−0,13** | −0,50 | −0,50 | −0,50 | −0,40 |
| moi | −0,06 | **−0,50** | −0,56 | −0,56 | −0,49 | −0,38 |

> **Arbitrage entre les deux sondes** : la sonde « lecture visuelle » ne voit pas le dard (elle mesure une boîte englobante : hauteur 0,984 R contre 0,995 en réf, donc *plus courte*). La sonde « glyphe » le voit (+62 % à 238°). **Croire la sonde « glyphe »** : une boîte englobante est aveugle à un éperon fin. **Mais** la valeur à 2 % de profondeur (0,26 H côté réf) est sous le plancher de flou de REF_CROP (1 px = 0,74 pt) : **elle n'est PAS opposable.** À 5 % on est à 1,5 pt de profondeur, à 10 % à 3,1 pt ≫ 0,74 pt : **ce sont les seules cibles de couronne à opposer** (D5 %, D10 %), plus le test de crête à x = −0,30 R qui, lui, sépare « le sommet est trop haut » de « il y a un éperon à gauche ».

#### H2. Le trait

| grandeur | cible | tol. | actuel |
|---|---|---|---|
| **chromie de crête** | **+0,500** | ± 0,020 | **+0,646** |
| **G/R** | **0,883** | ± 0,015 | **0,751** |
| **B/R** | **0,473** | ± 0,020 | **0,328** |
| RGB de crête | (0,958 ; 0,850 ; 0,460) | — | (0,961 ; 0,721 ; 0,315) |
| luma de crête | ≥ 0,730 | — | 0,672 |
| FWHM sur la normale | 0,0600 R | ± 0,0020 | 0,0553 |
| descente 10–90 % du **flanc extérieur** | **≥ 0,045 R** | — | 0,027 |
| rapport flanc extérieur / intérieur | ≥ 1,35 | — | 1,31 ⚠ |

**Le rouge est identique des deux côtés (0,944–0,961) : tout l'écart de couleur est dans le VERT et le BLEU.** Le remède est d'ajouter du vert et du bleu, pas de retirer du rouge.

#### H3. Halo (excès de luma sur le plancher du disque)

| distance au trait | cible | actuel |
|---|---|---|
| **0,5 pt** | **≥ +0,160** (réf +0,168/+0,192) | +0,077 |
| 2 pt | +0,10 ± 0,02 | +0,057 |
| 4 pt | ≈ +0,05 | +0,031 |
| **portée à 50 %** | **3,0 pt ± 0,5** | **4,0 pt** |
| excès de chromie à 0,5 pt | ≥ +0,220 | +0,109 |
| L(halo 0,5 pt)/L(plancher du disque) | ≥ 2,3× | 1,46× |

**Halo 2,2× à 2,5× trop faible au pied et 33 % trop étalé : un voile plat au lieu d'une collerette serrée.**

#### H4. Lavis intérieur

| grandeur | cible | actuel |
|---|---|---|
| excès sur le plancher du disque | **+0,27 ± 0,03** | +0,183 |
| rapport lavis / plancher | ≥ 3,0× | 2,09× |
| uniformité (max/min des 4 quadrants) | ≤ 1,35 | 1,13 ✔ |

Chez la réf l'intérieur du contour est un **aplat chaud uniforme** ; chez moi c'est un point chaud radial au-dessus de la goutte, et le bas-gauche reste sombre.

#### H5. Diffusion du glyphe dans le bol

| grandeur | cible | réf | actuel |
|---|---|---|---|
| chromie moyenne sur 0,30–0,50 R | ≥ +0,34 | +0,395 | +0,317 |
| chromie moyenne sur 0,50–0,70 R | ≥ +0,15 | +0,182 | +0,126 |
| luma médiane à 0,25 R | ≥ 0,44 | 0,489 | 0,329 |
| chromie à 0,45 R | +0,320 | — | +0,172 |

#### H6. La goutte

| grandeur | cible | tol. | actuel |
|---|---|---|---|
| aire / aire du disque | 0,0289 | ± 0,0020 | 0,0230 |
| **aire goutte / aire silhouette** | **0,162** | ± 0,010 | **0,130** |
| largeur | 0,315 R | ± 0,012 | 0,286 |
| hauteur | 0,402 R | ± 0,015 | 0,381 ⚠ |
| centre dy | +0,178 R | ± 0,012 | +0,174 ✔ |
| centre dx | +0,031 R | ± 0,010 | +0,004 |
| chromie moyenne | +0,540 | ± 0,020 | +0,646 |
| luma moyenne | ≥ 0,672 | — | 0,647 ⚠ |
| **largeur à 30 % de profondeur** | **≥ 0,55 H_goutte** | — | 0,344 |
| **largeur à 40 %** | **≥ 0,68 H_goutte** | — | 0,531 |

*La référence atteint sa pleine largeur dès **30–40 %** de profondeur, moi seulement à **60 %** : une **goutte ronde à sommet mousse** contre une **flamme dentelée à pointe**. Mesure à mi-hauteur plateau/plancher (invariante au flou) : les deux réfs y concordent à 1 % près.*

#### H7. Étincelles et pastilles

| grandeur | cible | actuel |
|---|---|---|
| nombre (top-hat ⌀3,2 pt, seuil +0,045) | 5 à 8 | 3 |
| aire totale | 4,5 ‰ ± 1,5 ‰ du disque | 2,58 ‰ ⚠ |
| luma de la plus vive | ≥ 0,510 | 0,446 |
| **chromie de la plus vive** | **+0,38 ± 0,06 (ambrées, pas grises)** | **+0,145** |
| diamètre médian | 1,65 pt ± 0,25 | 1,60 ✔ |
| fraction au-dessus du centre | ≥ 0,85 | 1,00 ✔ |
| **pastille A** en (+0,160 ; −0,110) R, excès sur l'anneau 2,5–4,2 pt | ≥ +0,14 (réf +0,172 / +0,216) | **−0,009** |
| **pastille B** en (+0,240 ; −0,090) R | ≥ +0,12 (réf +0,191 / +0,141) | **−0,018** |

Les deux pastilles sont **au même endroit dans les deux références à ±0,005 R**, avec un excès net. *Reproductibles — pas démontrées intentionnelles (voir §5).*

---

## 2. LE DIAGNOSTIC — PAR GRAVITÉ VISUELLE

*L'ordre est celui de l'œil, pas celui de la mesure. Les deux sondes qui ont regardé à fort grossissement placent les trois premiers en tête, indépendamment l'une de l'autre.*

**① LA POLARITÉ DU SERTISSAGE EST INVERSÉE — « pastille posée » contre « pierre sertie ».**
Dehors − dedans (1,06–1,14 R vs 0,90–0,96 R) : **négatif sur 12 secteurs sur 12** (−0,002 à −0,059), quand la réf est à **+0,11 à +0,29** sur tout le flanc gauche. La bague n'existe pas : masse **0,014 contre 0,932–1,100 → facteur 67 à 79.** Mon seul point clair extérieur est une lueur **chaude** (+0,122) à 1,35–1,47 R, loin du disque, au lieu d'un flare **neutre** (+0,002) collé à 1,05–1,17 R.

**② L'ARC ORANGE DU BAS.**
Chromie à la crête du fil, secteur 90° : **+0,481 à +0,603 contre +0,054 à +0,073 → ×8,3.** À 115° : **+0,692 contre +0,109 → ×6,3.** Chromie/luma 0,697 contre 0,271. La réf ne dépasse **jamais** +0,181 ; moi je dépasse +0,30 sur tout l'arc 70–160°. Amplitude crête−creux : ×3,5 trop forte en bas, ×0,25 trop faible à 300°. **Cause identifiée dans le code : un unique stop `flamme.opacity(0.88)` à la location 0,32 de l'`AngularGradient`.**

**③ L'ASSISE.**
Centre à **0,655 h contre 0,565** → **12 pt trop bas** ; marge basse **14,2 contre 23,5** ; rapport haut/bas **3,74 contre 1,66**. **5,3 pt trop à gauche**, **8 % trop petit** (D50 58,0 contre 63,1). Le disque frôle la barre de progression.

**④ LE VOILE GRIS DU BOL — « le fond noir qui manque ».**
Excès quasi neutre de **+0,040 sur R, G et B** à r/R ≥ 0,72 (écart entre canaux : 0,005). Plancher **0,108 contre 0,066 (1,63×)** ; L@0,85 **0,136 contre 0,094 (1,44×)** ; L@0,75 **0,160 contre 0,113**. Chute radiale **1,71× contre 2,37×** ; mi-hauteur du halo **≥ 0,95 R contre 0,72 R** ; max/min **2,36 contre 3,79**.

**⑤ LE BOL EST GRIS AU LIEU D'ÊTRE CUIVRÉ.**
Paroi 0,72–0,92 R : **R/B = 1,58 contre 2,04** ; bleu **0,113 contre 0,071 (+61 %)**, vert +33 %, rouge +25 %. B/R : **0,57 contre 0,38** à 0,60 R ; **0,64 contre 0,54** à 0,85 R. X/L : **0,56 contre 0,89** à 0,60 R ; **0,45 contre 0,62** à 0,85 R.

**⑥ LE FOND DE CARTE AUTOUR EST MARRON, ET PLAT.**
Chromie sur 1,10–1,40 R : **+0,0935 contre +0,0275 (×3,4)**, sur les 360°. Verre à d=6 : **0,105 contre 0,071 à droite** mais **0,210 contre 0,305 à gauche** → le rapport gauche/droite tombe de **4,3× à 2,0×**. Grain haute fréquence **10,7 % contre 2,1 %**.

**⑦ L'ÉCLAIRAGE TOURNE À L'ENVERS.**
φ du fond du bol : **280° contre 71° → retourné de 209°.** Les deux extrêmes ont échangé leur place (à 0,85 R : plus clair à 270° chez moi, à 45° chez elle). Centroïde de la masse du fil : **111,6° contre 197° → 85° d'erreur.** Anneau 0,80–0,93 R : mes deux secteurs les plus clairs (haut-gauche, 0,150–0,155) sont ceux qui devraient être les plus noirs (0,0765–0,0800) → **1,94× et 2,02× trop clairs.** *Cause identifiée : `UnitPoint(0.5, 0.44)` — le centre du dégradé de la niche est au-dessus du milieu, il devrait être à ≈ (0,516 ; 0,589).*

**⑧ LA FLAQUE N'EXISTE PAS.**
A = **1,073 contre 0,60** : le verre **monte** au lieu de descendre. Creux résiduel 12,2 % à 3,2 pt au lieu de 23 % à 6,3 pt. **0 secteur sur 5.**

**⑨ LE GLYPHE NE DIFFUSE PAS — il flotte sur le disque au lieu de l'éclairer.**
Halo à 0,5 pt : **+0,077 contre +0,168/+0,192 (2,2 à 2,5×)**, et **33 % trop étalé** (portée 50 % à 4,0 pt contre 3,0). Chromie du halo 2,0 à 2,5× trop faible. Lavis **+0,183 contre +0,254/+0,293**. Rapport halo/plancher **1,46× contre 2,4–3,5×**. Chromie à 0,45 R **+0,172 contre +0,320 (0,54×)**.

**⑩ L'ENCRE EST ORANGE SOMBRE AU LIEU D'ÊTRE OR PÂLE.**
G/R **0,751 contre 0,883 (−15 %)**, B/R **0,328 contre 0,473 (−30 %)**, chromie **+0,646 contre +0,500 (+29 %)**, luma **0,672 contre 0,738/0,755 (−9 à −11 %)**. Même défaut sur la goutte (+0,646 contre +0,532/+0,547).

**⑪ LE FIL EST UN RUBAN, PAS UN ÉCLAT.**
w90/w50 **0,67–0,80 contre 0,35–0,46** ; crête plate de **0,90–1,06 pt contre 0,34–0,52 (2,2 à 2,7× trop large)**. Un seul arc au lieu de quatre ; modulation **4,5× contre 10,2×**. Corrélation croisée des profils angulaires : **0,011 à décalage nul, 0,411 au mieux (+75°)** — *même en tournant mon anneau on ne le fait pas coïncider*. Le trait ne respire pas : amplitude radiale **0,23 pt contre 0,84**, amplitude de FWHM **0,22 pt contre 2,24**.

**⑫ PAS DE VIGNETTE INTERNE.**
Fosse à **0,94–0,97 R / 0,48 × la crête** au lieu de **0,88 R / 0,25 ×**. Rapport centre/fosse **2,7 contre 5,5–6,3**.

**⑬ LE DARD ET LA COURONNE DU GLYPHE.**
À x = −0,30 R mon contour monte à **−0,50 R au lieu de −0,13 R** (un éperon de 0,36–0,38 R = 10 pt). Largeur à 5 % de profondeur **0,161 H contre 0,315**. Sommet à **−0,56 R contre −0,505**. Écart de rayon **+62 % à 238°**.

**⑭ LA GOUTTE EST TROP PETITE ET TROP POINTUE.**
**0,130 contre 0,162** de la silhouette (−20 %) ; largeur 0,286 contre 0,315 R ; pleine largeur atteinte à **60 % de profondeur au lieu de 30–40 %**.

**⑮ LES ÉTINCELLES SONT GRISES.** Chromie de la plus vive **+0,145 contre +0,38** ; 3 au lieu de 5–8 ; aire 2,58 ‰ contre 4,5 ‰.

**⑯ LES DEUX PASTILLES INTÉRIEURES MANQUENT** (excès −0,009 et −0,018 contre +0,14 à +0,22).

**⑰ MICRO** : glyphe décalé de ≈1 pt vers le haut-gauche (dx −0,035 R, dy −0,032 R) ; trait 8–10 % trop fin ; bord extérieur du trait 1,7 à 3,0× trop net (0,027 R contre 0,047–0,081).

---

## 3. L'ORDRE DE BATAILLE — 12 TOURS

*Principe d'ordonnancement : **on ne peut pas mesurer un excès sur un fond qui va bouger.** Presque toutes les cibles des systèmes D/E/F/H sont des excès ou des rapports sur le fond local ou sur le plancher du disque. Chaque tour installe le fond du suivant.*

---

### TOUR 1 — L'ASSISE
**(a)** Poser le médaillon à sa taille et à sa place, une fois pour toutes.
**(b)** Cibles : D50 = **63,1 pt ± 1,5** ; cy/h = **0,565 ± 0,010** ; marge gauche **17,4 ± 1,0** ; marge haute **39,4 ± 2,0** ; marge basse **23,5 ± 2,0** ; rapport haut/bas **1,66** (1,50–1,85) ; jeu disque→« S » **15,4 ± 1,3**, le « S » passant à **x ≈ 95,9 ± 1,5**.
*Leviers : `frame 58 → 63,1`, `padG +2,8`, alignement vertical du HStack de `dalle`.*
**(c)** Ne doit pas casser : la **circularité** (déjà 0,6 %, meilleure que la réf — n'y toucher sous aucun prétexte) ; les **fractions de R du glyphe** (largeur 0,729, aire 0,177, bas +0,48 — le glyphe doit grandir avec le disque : `size 26 → 28,3`) ; le jeu disque→« S ».
**(d)** **Premier parce que toute cible en pt en dépend** : FWHM du fil (0,034 R = 0,95 pt à R=28 mais 1,07 pt à R=31,5), fond de flaque à 6,3 pt, halo à 0,5 et 2 pt, largeur de crête w90 ≤ 0,55 pt. Le faire au tour 8 invaliderait sept tours de réglage.
**⚠ Décision de layout, pas mesure — voir Q1.** Si la designer refuse le déplacement du titre, tous les tours suivants s'appliquent **en fraction de R** et les cibles en pt se recalculent à R = 29,0 (FWHM E1 0,95 pt, E2 1,06 pt, w90 ≤ 0,50 pt, sillon à −1,00 pt sous une épaule à −1,50 pt, fond de flaque à 5,8 pt).

---

### TOUR 2 — LE LIT ET SA SOURCE
**(a)** Rendre au verre autour du médaillon sa **direction** (haut-gauche clair, droite noire) et sa **neutralité**.
**(b)** L(d=6 pt) par secteur : gauche **0,305 ± 0,04**, haut **0,112 ± 0,02**, bas **0,107 ± 0,02**, bas-droite **0,089 ± 0,02**, droite **0,071 ± 0,015** ; **rapport gauche/droite ≥ 4,0** (réf 4,3) ; chromie ≤ **+0,045** sur 1,10–1,40 R et ≤ **+0,05** à d=3 pt secteur droite ; **grain ≤ 5 %** du niveau local.
**(c)** Ne doit pas casser : le reste de la carte (le verre validé au commit `55cfa13`) ; le plateau à 15–20 pt (il servira de référence à O6) ; la rampe qui **croît** vers le coin haut-gauche au-delà de 1,20 R (0,305 → 0,448 → 0,446).
**(d)** **La bague et la flaque se mesurent en EXCÈS sur ce fond.** Les régler avant lui, c'est les calibrer contre une référence qui va bouger. Et le niveau absolu de la bague (crête 0,916) n'est atteignable **que si** le verre sous elle est à 0,305 — aujourd'hui il est à 0,082.
**⚠ Question préalable** : d'où vient le brun ? Trois candidats à localiser avant de coder — l'ambiance `plusLighter` (endRadius 29, donc intérieure : à écarter), les `.shadow` orange du glyphe (r 2,6 et 6), ou une aura peinte par la carte hôte. Le décider par bisection (désactiver une couche, capturer, mesurer).

---

### TOUR 3 — LA FLAQUE
**(a)** Creuser autour du disque l'anneau sombre circulaire qui le sertit dans le verre.
**(b)** **A = L(4–9 pt)/L(1–4 pt) = 0,60** (0,52–0,70) ; fond de cuvette à **0,20 R** au-delà de la crête (0,16–0,26) ; profondeur **23 %** sous le plateau 15–20 pt (18–30 %) ; **présente dans ≥ 4 secteurs sur 5** ; L(d=6)/L(d=3) = droite 0,92 · bas 0,91 · bas-droite 0,90 · haut 0,72 (± 0,08) ; remontée L(plateau)/L(fond) = **1,30** (1,20–1,45).
**(c)** Ne doit pas casser : la direction et la neutralité du tour 2 (le creux ne doit pas re-teinter le verre) ; le plateau 15–20 pt (sinon O6 passe par baisse du numérateur, ce qui est un faux positif) ; le bord de carte.
**(d)** C'est **le socle noir sur lequel le fil va « sauter »** : le contraste du fil se définit comme pic − plancher extérieur. Sans flaque, les cibles du tour 6 sont atteignables par surbrillance, ce qui est exactement le défaut actuel.
**⚠** Aux angles 170–200° et en bas, la fenêtre de mesure atteint le bord de carte (13,0 et 12,5 pt). **Mesurer avec A_ras (percentile 8), jamais avec une moyenne** — sinon on lit un artefact de rampe.

---

### TOUR 4 — LE BOL : LE NOIR REVIENT
**(a)** Rendre au fond intérieur sa chute radiale serrée et son plancher noir, et retirer le terme directionnel inversé.
**(b)** L@0,85 R = **0,094 ± 0,010** ; L@0,75 R = **0,113 ± 0,010** ; L min sur 24 angles @0,85 = **0,078 ± 0,008** ; plancher absolu sur 0,35–0,88 R **≤ 0,070** ; **chute L(0,45)/L(0,85) ≥ 2,30** ; L(0,65)/L(0,45) = **0,58 ± 0,05** ; **mi-hauteur du halo à r/R = 0,72 ± 0,04** ; max/min ≥ **3,50** ; **résidu par canal vs REF_CROP sur 0,72–0,88 : |dR|,|dG|,|dB| ≤ 0,012** ; **fosse : minimum à 0,88 R ± 0,03, niveau ≤ 0,095, soit 0,25 × la crête (0,15–0,35)**. Amplitude du terme directionnel ramenée à **≤ 5 %** (on le remettra au tour 9, à la bonne phase).
**(c)** **NE DOIT PAS DESCENDRE LE CENTRE** : L(0,25 R) ≥ 0,44 est une non-régression *déjà en échec* (0,329) — voir le piège §4.2. Ne doit pas casser : la flaque du tour 3 (elle est dehors, le bol est dedans : le fil les sépare) ; la chromie absolue à 0,75 et 0,85 R (elle est **déjà juste** : +0,078 / +0,062 contre +0,080 / +0,059).
**(d)** **Le glyphe se juge en excès sur ce plancher.** Tant que le plancher est à 0,167 au lieu de 0,133, les cibles halo/plancher ≥ 2,3× et lavis/plancher ≥ 3,0× sont arithmétiquement inatteignables, quelle que soit la puissance du halo.
**⚠** Le masque du glyphe est absolu (L > 0,28) : mon fond étant plus clair, j'écarte davantage de mes cellules lumineuses. **L'excès mesuré (+0,040) est un MINORANT** — à mesure que le fond s'assombrit, la sonde révélera plus de voile. Ne pas s'arrêter au premier passage.

---

### TOUR 5 — LE CUIVRE
**(a)** Retirer le plancher bleu du bol, à luma constante.
**(b)** **B/R : 0,34 @0,45 R · 0,38 @0,60 · 0,49 @0,75 · 0,54 @0,85** (± 0,05) ; **paroi 0,72–0,92 R : R/B ≥ 1,95, canal bleu ≤ 0,080, luma ∈ [0,090 ; 0,120]** ; X/L = **0,89 @0,60 R (± 0,10)** et **0,62 @0,85 R (± 0,08)** ; RGB par anneau à ± 8 % relatif par canal (table §1.3) ; et le seul écart où je suis **en dessous** : **R remonte de +0,031 à 0,45 R et +0,025 à 0,50 R**.
**(c)** Ne doit pas casser : les luma acquises au tour 4 (D1/D4 ne bougent pas de plus de ±0,010) ; le résidu neutre sur 0,72–0,88 (|dR|,|dG|,|dB| ≤ 0,012 — un gain de saturation global le ferait exploser).
**(d)** Après le tour 4 parce qu'on retire du bleu **à luma fixée**. Dans l'autre ordre on tourne en rond : chaque correction de teinte déplace la luma et inversement.
**⚠ Piège de remède** : ma chromie **absolue** est correcte à 0,75 et 0,85 R. **Il ne faut pas ajouter d'orange** — c'est le bleu qu'il faut retirer. Un gain de saturation ferait passer B/R en cassant le résidu neutre.

---

### TOUR 6 — LE FIL : SECTION ET NEUTRALITÉ
**(a)** Faire du liseré un **fil neutre en pointe posé sur la lèvre extérieure**, au lieu d'un ruban orange inscrit.
**(b)** **Chromie ≤ +0,15 dans les 12 secteurs** (aucun angle au-dessus de +0,19), **chromie/luma ≤ 0,45**, chromie médiane +0,097 ± 0,04 ; **w90/w50 ≤ 0,46** ; **w90 ≤ 0,55 pt** ; FWHM médiane **0,036 R ± 0,005** ; **crête à 0,98 R50 = 1,03 R_gradient** (1,01–1,05) ; bave externe L(d=+3)/L(plateau) = 0,96 (0,85–1,10).
*Levier : `strokeBorder` (vers l'intérieur) → tracé sur un cercle inset négatif ; profil en pointe au lieu d'un `lineWidth` plat.*
**(c)** **NE DOIT PAS ÉTEINDRE LE FIL** : luma de crête **≥ 0,18 dans les 12 secteurs** — non-régression critique, je suis déjà à 0,170–0,181 sur 240–330° (voir §4.5). Ne doit pas casser : la fosse interne (tour 4) ni la flaque (tour 3) — le fil se pose **entre** les deux.
**(d)** On ne module pas un ruban, on module un fil. **Il faut la bonne section avant la bonne distribution** (tour 7). Et le fil se pose sur la lèvre entre fosse interne et flaque : les deux doivent exister d'abord.

---

### TOUR 7 — LES QUATRE ÉVÉNEMENTS
**(a)** Remplacer l'arc unique par la topologie angulaire de la référence.
**(b)** **Nombre d'arcs contigus à contraste > 0,20 : exactement 4** (tolérance 4 ± 0), bornes **E1 18→52°**, **E2 303→332°**, **E3 130→178°**, **E4 190→228°**, ± 6° sur chaque borne. **Contraste max E1 = 0,43 ± 0,06 atteint entre 35 et 47°** ; **E2 = 0,46 ± 0,06 entre 313 et 322°** ; **rapport E2/E1 = 1,07 ± 0,15**. **Masse E1 = 0,55 ± 0,10** ; **masse E2 = 0,65 ± 0,12** ; **masse@90° ≤ 0,16** ; masse E4 ≥ 1,10. **Entre 60–110° et 340–10° : contraste < 0,16.** **Modulation ≥ 8,0.** **Centroïde angulaire 197° ± 12** ; **masse ouest/est = 2,05 ± 0,30**. Chromie E1 **+0,126 ± 0,05**, E2 **+0,113 ± 0,05**, **E4 ≤ +0,06** (réf +0,015 à +0,025).
*Table-fil §1.5 directement transposable : `location = θ/360`. Note d'architecture : E3 et E4 relèvent de la source B — les porter au tour 8, pas dans l'`AngularGradient` du fil.*
**(c)** Ne doit pas casser : la neutralité et la section du tour 6 **sur les événements eux-mêmes** ; la continuité (le fil ne s'éteint pas entre les événements : contraste ≥ 0,053, luma ≥ 0,15).
**(d)** Après le tour 6, avant le tour 8 : la bague (E4) a besoin que la topologie du fil soit posée pour qu'on puisse la lui **soustraire** proprement au lieu de l'y confondre.
**⚠ Tour le plus « destructeur » du plan** : il éteint exactement la zone 60–110° où mon rendu met tout son or. **Confirmation designer demandée avant (Q11).**

---

### TOUR 8 — LA BAGUE : LA POLARITÉ S'INVERSE
**(a)** Poser sur la rive haut-gauche le flare **neutre** qui fait passer le médaillon de « posé » à « serti ».
**(b)** **Test de sertissage : dehors(1,06–1,14 R) − dedans(0,90–0,96 R) ≥ +0,08 sur les 5 secteurs de 120 à 240°**, cibles +0,11 / +0,19 / +0,29 / +0,26 / +0,12 (± 0,05), **aucun négatif**. Sommet **209° ± 3** ; mi-largeur **25° ± 4** ; barycentre **213° ± 3** ; **A_ras au sommet +0,55 ± 0,08** ; L(R+0,5)/fond = **2,80 ± 0,25** ; **crête ≥ 0,90 à r/R = 0,99 ± 0,01** ; **|chromie| ≤ 0,020 de R−0,3 à R+4 pt** ; mi-portée **1,068 ± 0,010**, chute à 10 % **1,168 ± 0,015**, excès < 0,02 au-delà de **1,20** ; **masse ≥ 0,85 pt·luma** au sommet et **≥ 2,3** sur 190–230° ; **contraste angulaire ≥ 10** ; **A_ras hors arc entre +0,025 et +0,055** ; **minimum local à 1,19 R ± 0,03**, ≤ 0,40 × la crête, puis +40 % avant 1,50 R. Profil asymétrique : retombée 220–230° plus lente que la montée 190–200°.
**(c)** Ne doit pas casser : la flaque (le creux à 1,19–1,20 R reste présent dans ≥ 4 secteurs) ; la neutralité du lit (tour 2) ; le fil neutre (tour 6) — la bague est une **couche superposée**, pas une teinte du fil : *le fil orange culmine à r = R−1,0/−1,5 pt avec chromie +0,24, la bague blanche à r = R±0,2 avec chromie 0,00. Deux couches, jamais une seule teintée.*
**(d)** **C'est le geste qui change le plus visuellement (défaut ① et les trois « corrections décisives » de la lecture visuelle) — et pourtant il vient au tour 8, parce qu'il se définit en EXCÈS sur le fond local et en LUMA ABSOLUE sur le verre.** Le poser avant les tours 2–3 revient à le calibrer contre un fond qui va bouger de 0,082 à 0,305.
**→ Autorisé : un coup d'essai jetable dès le tour 2**, uniquement pour vérifier la faisabilité technique (où dessiner hors du `frame` de 58 pt sans clipping), **jamais pour régler des valeurs.**

---

### TOUR 9 — LE GLYPHE COMME SOURCE : HALO, LAVIS, DIFFUSION
**(a)** Rebrancher la goutte comme **la** source interne : elle doit éclairer le bol, pas flotter dessus.
**(b)** Halo : **excès ≥ +0,160 à 0,5 pt**, **+0,10 ± 0,02 à 2 pt**, **portée 50 % = 3,0 pt ± 0,5** (aujourd'hui 4,0 — il faut **resserrer en montant**), **excès de chromie ≥ +0,220 à 0,5 pt**, **L(halo)/L(plancher) ≥ 2,3×**. Lavis : **excès +0,27 ± 0,03**, **rapport ≥ 3,0×**, uniformité ≤ 1,35. Diffusion : **L(0,25 R) ≥ 0,44** ; chromie moyenne **≥ +0,34 sur 0,30–0,50 R** et **≥ +0,15 sur 0,50–0,70 R**. Terme directionnel du bol : **φ = 71° ± 25° à 0,75 R**, **amplitude 18 % ± 6 %**, **L(45–105°)/L(225–285°) ≥ 1,20 @0,75 R** (réf 1,35), **X(45–105°) − X(225–285°) ≥ +0,030** (réf +0,051), et le test d'ombre **moyenne(240–300°) ≤ 0,90 × moyenne(0–60°)** sur l'anneau 0,80–0,93 R.
**(c)** Ne doit pas casser : le plancher du bol du tour 4 (L@0,85 ≤ 0,104, L min @0,85 ≤ 0,086) — **le halo monte le centre, pas la périphérie** ; le B/R du tour 5 ; la fosse à 0,88 R.
**(d)** Après le tour 4 (le rapport halo/plancher exige le bon plancher) et après le tour 5 (le X/L du bol exige la bonne teinte). Et c'est **ici** que revient le terme directionnel retiré au tour 4 — mais à la bonne phase et pour la bonne raison : *ce n'est pas un dégradé de fond, c'est la lumière de la goutte.*
**⚠ Le discriminant à ne pas rater** : la zone sous la flamme doit être **plus claire ET plus chaude**. Si elle devient plus claire mais neutre, on a implémenté un spéculaire de cuve — mauvais mécanisme, même image approximative, et il cassera dès que le glyphe bougera.

---

### TOUR 10 — L'ENCRE OR PÂLE ET LA SECTION DU TRAIT
**(a)** Passer l'encre de l'orange au **or pâle lumineux**, et fondre son bord extérieur.
**(b)** **Chromie de crête +0,500 ± 0,020** ; **G/R 0,883 ± 0,015** ; **B/R 0,473 ± 0,020** ; **luma de crête ≥ 0,730** ; RGB de crête ≈ (0,958 ; 0,850 ; 0,460). Goutte : **chromie +0,540 ± 0,020**, luma ≥ 0,672. **FWHM du trait 0,0600 R ± 0,0020** ; **descente 10–90 % du flanc extérieur ≥ 0,045 R** ; **rapport extérieur/intérieur ≥ 1,35**.
*Levier : `FlammePalette.or` (1,0 ; 0,78 ; 0,38) → ≈ (1,0 ; 0,88 ; 0,48). **Le rouge ne bouge pas** (0,944–0,961 des deux côtés) : tout l'écart est vert + bleu.*
**(c)** Ne doit pas casser : le halo du tour 9 (l'excès de chromie à 0,5 pt reste ≥ +0,220 — **une encre plus pâle diminue mécaniquement la chromie du halo, il faudra recompenser**) ; la diffusion (chromie ≥ +0,34 sur 0,30–0,50 R) ; les fractions de R de la silhouette (une hausse de graisse élargit aussi la boîte : largeur 0,744 R ± 0,025 est une non-régression).
**(d)** Après le tour 9 : la couleur du halo et celle du trait sont liées ; régler le trait d'abord ferait redécaler le halo. Et le trait se juge sur un bol au bon plancher.
**⚠** La cible du flanc extérieur (0,045 R) est un **plancher, pas une valeur exacte** : les deux références divergent de 1,7× (0,047 HD contre 0,081 CROP). Le **sens** est sûr (les deux sont plus molles que moi, et toutes deux nettement plus molles à l'extérieur qu'à l'intérieur — un flou d'échantillonnage isotrope ne peut pas produire cette asymétrie). Ne pas sur-optimiser sa valeur.

---

### TOUR 11 — LA FORME DU GLYPHE : COURONNE, GOUTTE, FLANCS, CENTRE
**(a)** Émousser la couronne, arrondir la goutte, recentrer.
**(b)** **Largeur de silhouette à 5 % de profondeur : 0,315 H ± 0,035** ; **à 10 % : 0,393 H ± 0,030** ; **y min à x = −0,30 R : −0,13 R ± 0,05** ; **écart de rayon normalisé à 238° ≤ 0,06** ; sommet absolu **−0,505 R ± 0,020** ; **H/L 1,355 ± 0,030**. Position : **dx +0,031 R ± 0,008**, **dy −0,011 R ± 0,012**, **flanc droit à y=0 : +0,400 R ± 0,015**, **flanc gauche : −0,315 R ± 0,015**. Goutte : **aire/silhouette 0,162 ± 0,010** ; aire/disque 0,0289 ± 0,0020 ; largeur **0,315 R ± 0,012** ; hauteur 0,402 R ± 0,015 ; **largeur à 30 % de profondeur ≥ 0,55 H_g**, **à 40 % ≥ 0,68 H_g** ; dx +0,031 R ± 0,010, dy +0,178 R ± 0,012.
**(c)** Ne doit pas casser : largeur 0,744 R, aire 0,180, bas +0,49 R (les trois sont **déjà justes** — ce sont des non-régressions, pas des cibles) ; l'encre et la section du tour 10 ; la position dy de la goutte (+0,174, déjà juste).
**(d)** Après la couleur : la forme se juge sur un contour à mi-hauteur, donc sur une luma stabilisée. Et le décalage de position (dx +0,035 R) déplace le centre de gravité de la source interne → il doit venir **après** que la diffusion du tour 9 soit calée, pour ne pas la recaler deux fois. *(Si le tour 9 échoue de peu sur la phase φ, le tour 11 peut le rattraper : +0,035 R de dx pousse φ vers la droite.)*
**⚠** Cibles jugées **sur la version ré-échantillonnée à 1,354 px/pt**. **La largeur à 2 % de profondeur (0,26 H côté réf) n'est PAS opposable** — elle est sous le plancher de flou de la référence (1 px = 0,74 pt). Le vrai juge est le couple 5 % / 10 %.

---

### TOUR 12 — LES MICRO-LUMIÈRES : ÉTINCELLES ET PASTILLES
**(a)** Rendre les étincelles ambrées et poser les deux pastilles intérieures.
**(b)** **Chromie de la plus vive +0,38 ± 0,06** ; luma **≥ 0,510** ; **nombre 5 à 8** (top-hat ⌀3,2 pt, seuil +0,045, hors trait et goutte) ; aire totale **4,5 ‰ ± 1,5 ‰** ; diamètre médian 1,65 pt ± 0,25 ; **≥ 85 % au-dessus du centre**. **Pastille A (+0,160 ; −0,110) R : excès ≥ +0,14** ; **pastille B (+0,240 ; −0,090) R : excès ≥ +0,12** (excès mesuré sur l'anneau 2,5–4,2 pt autour, sonde ponctuelle ⌀1,8 pt).
**(c)** Ne doit pas casser : l'uniformité du lavis (≤ 1,35) ; le compte d'étincelles ne doit pas être atteint en abaissant le seuil (protocole gelé) ; le grain hors disque (≤ 5 %).
**(d)** Dernier : ce sont des micro-lumières posées **sur** tout le reste, et le compte d'étincelles dépend du plancher (le déficit de 3 contre 5–8 est peut-être seulement le corollaire du déficit de luminosité, cf. §5 Q5).
**⚠** Les pastilles sont **reproductibles, pas démontrées intentionnelles** (Q5). Ne pas les implémenter avant la réponse de la designer.

---

## 4. LES PIÈGES PRÉVISIBLES

**4.1 — La règle qui bouge.** Six sondes, six rayons (21,2 → 31,9). Trois définitions de R diffèrent de 5 % côté réf et de 3 % côté moi, **et pas dans le même sens** : chez moi le max de gradient *est* la chute du liseré, chez la réf c'est la transition disque→flaque, le fil étant 1 pt plus loin. **Normaliser par la crête du fil masque le défaut n° 6 (liseré inscrit).** → Geler R50, publier la table de conversion §0.2, et refuser toute mesure dont la définition de R n'est pas explicitée.

**4.2 — La contradiction centre/périphérie du bol.** Le fond exige **plancher ≤ 0,070** (assombrir) ; la lecture visuelle exige **L(0,25 R) ≥ 0,44** alors que je suis à 0,329 (**éclaircir de +34 %**). Les deux sont vraies. **Arbitrage : le bol ne doit PAS être assombri globalement — c'est un gain de CONTRASTE** (rapport centre/fosse de 2,7 à ≥ 4,5, cible 5,5), pas une baisse d'exposition. **Verrouiller L(0,25 R) ≥ 0,44 comme non-régression AVANT de descendre la périphérie.** Concrètement : la moitié du remède est au tour 4 (descendre le bord), l'autre moitié au tour 9 (monter le centre par la diffusion du glyphe).

**4.3 — La contradiction « chromie absolue correcte / bol gris ».** À 0,75 et 0,85 R ma chromie absolue est **juste** (+0,078 / +0,062 contre +0,080 / +0,059). C'est la **luma** qui est trop haute, donc X/L s'effondre. **Ajouter de l'orange est le mauvais remède** ; il faut retirer le plancher **bleu** (B/R de 0,64 à 0,54 et de 0,57 à 0,38). Un gain de saturation global ferait passer B/R en **cassant le résidu neutre** (|dR|,|dG|,|dB| ≤ 0,012 sur 0,72–0,88).

**4.4 — La contradiction « éteindre le brun / la bague doit atteindre 0,92 ».** La bague culmine à 0,916 **parce que le verre sous elle est à 0,305**. Mon verre à gauche est à 0,21, à droite à 0,105. **« Éteindre le brun » ne veut PAS dire assombrir : à gauche il faut MONTER (0,21 → 0,305), à droite DESCENDRE (0,105 → 0,071).** C'est une **inversion de gradient**, pas un gain global. Un simple assombrissement du voisinage passerait la chromie et rendrait la bague impossible.

**4.5 — La contradiction « éteindre l'arc orange / le fil doit rester continu ».** Tuer l'arc du bas risque d'emporter la continuité. La réf tient un **plancher** : luma de crête ≥ 0,18 dans les 12 secteurs, et le contraste entre 60 et 110° reste entre **0,053 et 0,151 — donc pas zéro**. Mon fil est déjà à 0,170–0,181 sur 240–330°, à la limite. **Arbitrage : la cible du tour 6 est « chromie ≤ +0,15 à luma constante », pas une extinction.** La modulation vient au tour 7, et elle se fait **par le haut** (monter E1/E2), pas par le bas.

**4.6 — La bague ne doit pas être un arc isolé.** A_ras hors arc doit rester entre **+0,025 et +0,055** : la référence garde un liseré blanc faible sur tout le tour. Une bague posée comme un arc localisé qui tombe à 0 ailleurs échoue D6 alors même qu'elle passe D1/D7.

**4.7 — Le voile du bol est un MINORANT.** Le masque du glyphe est absolu (L > 0,28, dilaté de 0,038 R et 5°) ; mon fond étant plus clair, j'écarte davantage de mes propres cellules lumineuses. **Le vrai voile est ≥ +0,040.** À chaque tour où le fond s'assombrit, la sonde en révélera plus. Ne pas conclure au premier PASS.

**4.8 — Le piège de la résolution : REF_CROP est à 1,354 px/pt (1 px = 0,74 pt), moi à 3,0.**
Cibles **contaminées, à ne jamais sur-optimiser** : largeur absolue du cheveu (0,98–1,07 pt = 1,3 px — REF_HD, plus fin en px/pt, mesure **plus large**, preuve qu'il est rééchantillonné) ; largeur de silhouette à 2 % de profondeur ; netteté du bord droit de la goutte (6,65 pt CROP contre 2,36 HD contre 1,00 moi) ; grain (le 2,1 % de la réf est en partie son sous-échantillonnage).
Cibles **immunisées, à opposer en priorité** : la **masse intégrée**, le rapport **w90/w50**, les seuils à **mi-hauteur plateau/plancher**, les largeurs aux profondeurs **≥ 5 %**, les **rapports** et les **positions**.
→ **Toute cible de netteté se juge sur ma capture ré-échantillonnée à 1,354 px/pt.**

**4.9 — Le piège REF_HD.** Noirs écrasés (min exactement 0,0000), ×0,54 dans les ombres. C'est REF_CROP réagrandie ×1,19. Quatre sondes en ont tiré quatre échelles (1,6144 / 1,6160 / 1,6257 / **1,692 — fausse, elle inclut le cadre du téléphone**). **REF_HD ne valide qu'une forme, jamais un niveau.**

**4.10 — Le seul désaccord RÉEL entre les deux références : 140–150°.** A_ras +0,217/+0,171 (CROP) contre +0,050/+0,022 (HD), crête à −0,30 pt contre −0,80 pt. Facteur 4 en amplitude, 0,5 pt en rayon — ni bruit ni résolution. Partout ailleurs la corrélation est +0,925. **Deux exports différents, ou deux instants d'une animation.** → **Ne pas cibler ce secteur.** Le laisser libre, le vérifier en dernier, et poser Q3.

**4.11 — La capture périmée.** `xcodebuild | grep` renvoie le code de sortie de **grep** : un build cassé sort « exit 0 » et on mesure une app périmée. Piège déjà payé **deux fois** sur ce projet. **Vérifier `stat` du binaire avant toute capture ; horodater chaque PNG.** Une sonde qui régresse sans raison = capture périmée jusqu'à preuve du contraire.

**4.12 — Le scratchpad partagé.** Trois sondes sur six ont perdu des fichiers (`fit.py` écrasé, `kg.py` détruit par `kG.py` — FS insensible à la casse). **Un sous-dossier préfixé par tour, et des commits par chemins explicites** (un `git add` large a déjà avalé 32 000 fichiers d'index).

**4.13 — L'arité du stitchable.** Si un shader entre en jeu, un changement de signature non répercuté côté Swift rend **la page blanche, sans une seule erreur de compilation**. Vérifier après chaque changement de signature. *(Le médaillon étant aujourd'hui du SwiftUI pur, ce piège n'arrive que si un tour bascule une couche en shader — probable pour la bague et le grain.)*

**4.14 — L'image unique.** Une seule capture de chaque côté. Si le médaillon respire, un écart de niveau et un écart de phase sont indiscernables. **Tout se mesure gelé** ; et si la référence est animée (Q3), certaines cibles sont des instantanés, pas des lois.

**4.15 — Le glyphe est juge et partie.** Il masque **59,4 % des cellules** du fond (masque commun des trois sources). À r/R = 0,30 : **0 cellule sur 24**. À 0,45 : **4 sur 24** (secteur 180–225° seulement) — ce n'est pas une médiane de fond, c'est une lecture de flanc gauche. **Aucune bataille sous 0,50 R.**

**4.16 — La flaque contre le bord de carte.** À 170–200° et en bas, la fenêtre de mesure atteint le bord de carte (13,0 et 12,5 pt chez moi ; 10,4 px du bord dans REF_CROP à 180°). Les « masses » y sont des artefacts de rampe. **Toujours A_ras (percentile 8), jamais une moyenne.**

**4.17 — Ordre de bataille contre impatience.** Le défaut n° 1 (la polarité) est corrigé au **tour 8 sur 12**. C'est délibéré et il faut l'assumer devant la designer : la bague se définit en excès sur un fond qui bouge aux tours 2–3 et en luma absolue sur un verre qui bouge au tour 2. **Le prototype d'essai au tour 2 est autorisé pour la faisabilité, interdit pour le réglage.**

---

## 5. CE QUI RESTE INCERTAIN — À DEMANDER À LA DESIGNER

**Q1 — La taille et l'assise sont une décision de layout, pas une mesure.**
Passer R de 29,0 à 31,55 pt et remonter le centre de 12 pt oblige le titre « Séries » à passer de x = 87,8 à **x ≈ 95,9 pt**, et rendre 9 pt de marge basse. On le fait ? Ou on garde 58 pt et on applique tout en fraction de R (auquel cas les cibles en pt se recalculent, §Tour 1) ? *Rappel : l'écart réel est de −8 %, pas de −44 à −60 % comme le brief le supposait. La question est donc bien plus ouverte qu'annoncé.*

**Q2 — Le niveau absolu de la référence.**
REF_CROP et REF_HD divergent d'un facteur **1,9 à 2,5 dans les ombres**. J'ai retenu REF_CROP (elle partage le domaine photométrique de mon rendu). **Si c'est REF_HD qui dit vrai, il faut descendre le fond de ×2,81 au lieu de ×1,44** — la cible D1 passerait de 0,094 à **0,048**, et tout le tour 4 changerait d'amplitude. Comment REF_CROP a-t-elle été produite (capture d'écran ? export ? quel profil d'affichage ?), et laquelle fait foi ? **Toutes les cibles de FORME sont indifférentes à cet arbitrage ; toutes les cibles de NIVEAU en dépendent.**

**Q3 — Le médaillon de référence est-il animé ?**
Les deux références divergent d'un facteur 4 à 140–150° (lumière de rive), et REF_HD n'est qu'un réagrandissement de REF_CROP — ce qui rend la divergence encore plus étrange. Deux instants d'une animation, ou deux exports ? Si c'est animé, quelles grandeurs respirent, et à quelle amplitude ?

**Q4 — La bague appartient-elle au médaillon ou à la carte ?**
Mesure : attachée au disque (trois preuves), mais **pilotée par la lumière de la carte**. Je ne peux pas distinguer « une lueur dessinée DERRIÈRE le disque, débordant de 3 pt » d'« une rive dessinée SUR le bord avec un bloom extérieur » : la crête tombe dans l'épaisseur de l'anticrénelage (−0,15 à −0,40 pt). **La décision change le comportement** : si le médaillon bouge ou grossit (essor de la carte dépliée), la bague le suit-elle ?

**Q5 — Les deux pastilles intérieures** en (+0,160 ; −0,110) R et (+0,240 ; −0,090) R : élément de design volontaire, ou accident de l'art source ? Elles sont **au même endroit dans les deux références à ±0,005 R**, avec un excès de +0,14 à +0,22 — donc pas du bruit. Mais rien ne prouve l'intention.

**Q6 — Le dard du glyphe : épaissir le terminal, ou raccourcir la boucle ?**
La mesure dit « à x = −0,30 R le contour monte à −0,50 R au lieu de −0,13 », elle ne dit pas lequel des deux gestes elle veut. *Et sous-question technique : le glyphe est aujourd'hui le symbole SF « flame » à 26 pt. La référence est-elle le même symbole (à une taille/graisse différente, adouci), un autre symbole, ou un tracé maison ?* Cela change entièrement le coût du tour 11.

**Q7 — La flaque : ombre portée, réfraction du verre, ou vignette peinte ?**
La mesure prouve un **creux circulaire** (fond à 0,20 R au-delà de la crête, 23 % sous le plateau, présent sur cinq secteurs à distance quasi constante), **pas son mécanisme**. Le choix change l'implémentation et le comportement quand la carte bouge.

**Q8 — Le fil de la référence « respire ».**
Sa crête ondule de **±0,4 pt** (amplitude 0,84) et son épaisseur varie de **0,77 à 3,01 pt**, là où mon cercle est mathématique (0,23 et 0,22 pt). Est-ce le « border imparfait » voulu, du bruit de rendu, ou un artefact de compression de la photo ? **Doit-on le reproduire ?** *(Si oui, c'est un tour à part ; si non, retirer D9 des cibles.)*

**Q9 — Le grain.** Mon fond est tramé à 10,7 % contre 2,1 %. Mais le 2,1 % de la référence est en partie l'effet de son sous-échantillonnage : **l'écart vrai est plus faible que ×5,1**, je ne peux pas le chiffrer. Combien de grain la designer veut-elle vraiment ? (Le mien est visiblement tramé à l'œil sur les planches — c'est un vrai défaut, seul son facteur est incertain.)

**Q10 — Le glyphe de la référence est flou et auréolé, le mien vectoriel net.**
S'agit-il d'un art bitmap flouté ou d'un tracé rendu avec un halo dessiné ? Si c'est un bitmap, la cible « flanc extérieur ≥ 0,045 R » est en partie un artefact de la source et il faut la revoir à la baisse.

**Q11 — Confirme-t-elle qu'il faut éteindre la zone 60–110° du liseré ?**
C'est exactement là que mon rendu met tout son or (masse 0,409 contre 0,100 attendue), et c'est le geste le plus destructeur du plan (tour 7). La référence y a un **creux** : contraste 0,053 à 0,151, chromie +0,054 à +0,077. **Confirmation demandée avant le tour 7.**

**Q12 — E3 et E4 « appartiennent-ils » au médaillon ?**
De 130° à 230° le plancher extérieur monte à 0,17–0,44 : le pic mesuré y est un **bord silhouetté sur la clarté de la carte**, pas forcément un élément dessiné. Mes cibles les incluent parce qu'ils existent dans l'image. **Si la lumière de la carte est correctement reproduite au tour 2, E3 tombera tout seul** — et il faudra alors retirer sa ligne de D1 plutôt que la forcer.

---

### RÉSUMÉ EN UNE PHRASE

La référence est **une pierre noire cuivrée, creusée en cuvette, sertie dans un verre allumé en haut-gauche** : un fil quasi neutre qui déborde sur sa lèvre et porte quatre éclats, une bague blanche neutre à 10 h, une flaque d'ombre circulaire tout autour, et **une seule source chaude à l'intérieur — la goutte de la flamme — qui éclaire son propre bol vers le bas-droite**.
Le mien est **une pastille grise voilée, posée à plat sur un halo brun**, éclairée par le haut au lieu du bas, ceinte d'un ruban orange plat le plus vif exactement là où la référence est éteinte.