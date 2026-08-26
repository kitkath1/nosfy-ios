# LA STORY v2 — « SESSION ENDED » : le texte-verrière, le plongeon
# dans la pills, et le résumé au verre des widgets

**Écrit le 26-08-2026 sur le brief de Kathryn (deux captures du flow
refusé + la référence Apple « M5 Pro. M5 ») — RIEN n'est codé.**

Le flow v2 actuel ne va pas. Ce plan couvre **LE DÉBUT** du nouveau
flow : « le flow que je t'ai donné c'est le début, pas la fin — il
manquera 2 écrans mais je te dirai ». Les deux écrans suivants seront
dictés plus tard ; la structure les attend (pages 1-2 du chef
d'orchestre).

Ce plan hérite de tout l'appareil story existant : le portail
(`StoryPortal`, masque carte → écran, rayon 24→52), le chef
d'orchestre (`StoryFlow` — tap, pause à l'appui long, tirage vers le
bas, segments `StoryProgress`, tout à l'horloge), la donnée
(`StorySession`) et les deux sites de présentation (grille du
calendrier + LCD de l'iPod). **On remplace les écrans, pas la
machine.**

---

## 1. LA SCÈNE, EN DEUX ACTES SUR UNE SEULE PAGE

Le brief, dans l'ordre de Kathryn :

1. « Gros écran noir à la Apple », **« Session Ended »** au milieu —
   et dans les lettres, **deux vidéos de la pills rouge de la Home**
   qui tournent, comme les lettres « M5 Pro. » d'Apple : le noir est
   plein, le texte est une VERRIÈRE.
2. « Le texte est au milieu, après on zoom de fou, et le texte défile
   sur la droite toujours au milieu de l'écran, puis gros zoom
   cinématique à l'intérieur d'une pills rouge. »
3. Le zoom fini, « la grosse pills vient se placer en haut à droite
   de l'écran et bouge en mode fondue comme sur la home », un petit
   **éclair** (`éclair.mp4`, « incliné sur le côté ») bouge en bas,
   et au milieu **le résumé de la séance** dans « le liquid glass
   avec double bordure comme les widgets de la home, même corner
   radius step, et gros texte blanc ».

**Un seul écran du chef d'orchestre porte les deux actes** — comme
`StoryOne` porte déjà son intro dans son `hold` (2,40 s de dézoom +
la lecture). Une coupe de page (`.transition(.opacity)`) au milieu du
plongeon tuerait la cinématique ; l'acte A (SESSION ENDED) et l'acte
B (le résumé) sont une seule partition de `t`, fonctions pures à
l'horloge, école `StoryCine`. Le tap passe aux écrans suivants, la
grammaire ne change pas.

---

## 2. ACTE A — LE TEXTE-VERRIÈRE

### 2.1 La brique qui n'existe pas encore

⚠️ **Il n'y a AUCUN précédent vidéo-masquée-par-du-TEXTE dans le
repo** (vérifié sur tous les `.mask(`). Les deux moitiés existent :

- le masque-glyphe : `RewardCard.swift:937` (`.mask(glyphe())` — la
  trame déborde, c'est le MASQUE qui rogne) ;
- la vidéo découpée dans une forme : `CalLab.swift:3283-3299`
  (`CalqueVideo` dans un hôte `Color.clear` + overlay + clip — « le
  clip ne mord une couche UIKit qu'à la bonne taille »).

La forme robuste : **par mot** — chaque mot est son propre bloc
`CalqueVideo(...).mask(Text(mot))`, les deux blocs dans un `HStack`.
Pas de rect de mot à mesurer, chaque verre vit sous SON mot.
⚠️ `CalqueVideo` porte déjà son `clipsToBounds` interne
(`DepartCine.swift:277-287`) : le `AVPlayerLayer` ne déborde pas de
son hôte, le masque-Text fait le reste. C'est la voie qui respecte
les lois payées (un `.mask` SwiftUI ne rattrape JAMAIS le débord
d'une couche UIKit).

### 2.2 Les deux verres dans les lettres

« Deux vidéos (la même pills rouge de la Home) qui tournent à
l'intérieur pour bien faire ressortir le texte. »

- **Mot 1 « Session »** : le verre rouge COUCHÉ — l'école
  `home-fond-pilule` (caustiques lentes, ping-pong).
- **Mot 2 « Ended »** : le verre rouge DEBOUT — l'école
  `Video rouge_liquid` / `duo-galet-rouge` (la gélule qui tourne,
  braise au pied).

⚠️ Les fichiers du bundle sont TROP PETITS pour le plein zoom :
`home-fond-pilule.mp4` fait 1206×964 et au sommet du zoom l'intérieur
d'une lettre doit tenir ~1170 px de large. **On recuit depuis les
masters de Téléchargements** (mesurés : `Video rouge_liquid.mp4`
2160×3836, 24 i/s, 7,04 s, bords noirs à vrai 0 ; `pills_2.mp4` idem,
source du fond home). Deux sorties : `story-ended-verre-a.mp4` et
`story-ended-verre-b.mp4` — cadrées sur la MATIÈRE (le corps du
verre, pas la scène), ping-pong école porte (`recuit_porte.sh` :
split → reverse + trim des DEUX doublons de bord → concat), ralenti
`setpts` + `minterpolate` blend, **30 i/s** (le 24 bat en 3:2 à
60 Hz), une passe CRF 17 (école galets : le double encodage pose des
macro-blocs), jamais `-ss` (tout dans le graphe).

### 2.3 La typo du géant

**RÉGLÉ (26-08, E2)** : le plan se trompait — `Theme.swift:8-17`
embarque QUATRE graisses statiques (Regular, Medium, SemiBold,
**Bold**). La verrière part en `.inter(190, .bold)` (le corps du
LAYOUT, donc déjà ×4). Rien à livrer, sauf si le verdict capture
réclame un Black.

### 2.4 La caméra de l'acte A (partition de t, valeurs de départ)

| Temps | Mouvement |
|---|---|
| 0 → 0,9 s | naissance : le texte au milieu, échelle « affiche » (tient dans l'écran), les verres tournent déjà |
| 0,9 → 2,2 s | **LE ZOOM FOU** : échelle ×1 → ×4, courbe `outLong` maison (départ raide, traîne longue) |
| 2,2 → 3,6 s | **LE DÉFILEMENT** : à ×4 le texte est plus large que l'écran, il traverse vers la droite, toujours centré verticalement |
| 3,6 → 4,6 s | **LE PLONGEON** : la course s'arrête sur la lettre-cible, l'échelle repart ×4 → ~×12, centrée sur son verre |
| 4,6 s | l'intérieur de la lettre couvre l'écran → raccord vers l'acte B |

Toutes les valeurs se jugent au banc, aucune n'est un contrat.

⚠️ **La loi du zoom rastérisé** (payée sur le dézoom de `StoryOne`,
`StoryOne.swift:82-99`) : un `scaleEffect` posé après un masque
compose dans un tampon à la taille non zoomée puis l'agrandit — flou.
Ici le masque est obligatoire (c'est la technique), donc la parade
s'inverse : **le composite se construit à la taille du défilement
(×4) et l'échelle anime DE PETIT (0,25) À 1,0** — on réduit un grand
tampon (net par construction), on ne grossit jamais un petit. La
police est posée à sa taille ×4 réelle, le `scaleEffect` ne fait que
descendre.

⚠️ Le plongeon (×4 → ×12) grossit, lui, au-delà du tampon — mais ce
qu'on regarde alors est le VERRE (matière douce, en mouvement rapide)
et les arêtes du glyphe sortent de l'écran dès le premier tiers. Si
le flou se voit sur capture : calque de secours « lettre seule »
construit à la taille du plongeon, monté à 3,6 s. **Verdict sur
capture, pas d'avance.**

### 2.5 Le raccord du plongeon

Au sommet du plongeon, l'écran ne montre plus que le verre de la
lettre-cible. **ÉCHANGE SEC, jamais un fondu** (l'école du relais
`StoryReel`, `StoryVideo.swift:142-172` : les deux couches montrent
la même image, l'échange en une frame est invisible par
construction) : un `CalqueVideo` plein cadre du MÊME fichier, au
cadrage calculé pour coïncider, prend le relais. La couture se
MESURE (sonde : capture avant/après, delta sous le seuil — l'école
`fouette_film.py`), elle ne s'affirme pas.

---

## 3. ACTE B — LE RÉSUMÉ

La scène, de bas en haut :

1. **Le noir plein** (`Color.black`). Rien d'autre : c'est lui qui
   rend la fondue gratuite (noir + contenu = contenu).
2. **LA PILLS EN HAUT À DROITE.** Le plein-cadre du plongeon RECULE
   et se pose : transform seulement (scale + offset, ancre
   `.topTrailing`) — ⚠️ loi `CalqueVideo` : « on transforme, on ne
   redimensionne jamais » (`DepartCine.swift:251-254`). À la pose,
   elle « bouge en mode fondue comme sur la home », et la recette
   home est mesurée (`DepartCine.swift:476-661`) :
   - `.blendMode(.plusLighter)` sur le noir — le sombre disparaît
     par construction, pas de scrim nécessaire sur fond noir pur ;
   - le mouvement au repos N'EST PAS une animation SwiftUI : c'est
     le CONTENU (caustiques ralenties, ping-pong long) ;
   - naissance = `opacity` + `scaleEffect(1,015 → 1)` — l'approche
     imperceptible, jamais un bounce (`HomeNuit.swift:984-986`).
   Le fichier : `home-fond-pilule.mp4` tel quel (couché, déjà
   validé à l'écran) — mais son corps sort du cadre à GAUCHE
   (overlay x=-360 cuit) alors qu'ici il doit entrer par la DROITE.
   **Recuit miroir** (`hflip` sur la source, mêmes paramètres) →
   `story-pilule-droite.mp4`. Telle quelle vs miroir : verdict sur
   capture.
3. **L'ÉCLAIR EN BAS.** Asset : `~/Downloads/éclair.mp4` — mesuré :
   h264, **2160×3836, 24 i/s, 6,04 s**, pas d'alpha, **bords noirs à
   vrai 0 aux trois instants sondés (0,00 % de la bande de 4 px au-
   dessus de 8/255)** — rien à détourer, fusion additive directe.
   Recuit → `story-eclair-loop.mp4` : crop à la boîte utile,
   **inclinaison cuite** (« incliné sur le côté », ~25°, à juger sur
   capture), ping-pong école porte, ralenti ×2, 30 i/s, CRF 17.
   Posé en bas (à gauche sur la capture de référence), ~150 pt,
   `.plusLighter`. Il « bouge » : c'est le fichier qui tourne, pas
   un modificateur.
4. **LA CARD RÉSUMÉ AU CENTRE — le verre des widgets, à
   l'identique.** Le composant existe et il est générique :
   **`CardCorps`** (`WidgetsCards.swift:180`) — on le RÉUTILISE, on
   ne le retranscrit pas. Ce qu'il donne (mesuré) :
   - forme externe `0,152·W` **`.circular`** (jamais `.continuous` —
     sondé sur la référence des widgets) ;
   - « même corner radius step » : panneau encastré à `0,0345·W`,
     rayon interne `0,1175·W` = **externe − encastrement** (rayons
     concentriques exacts) ;
   - **bordure №1** : liseré angulaire `cardLisereConique` (trait
     1,6 + bloom 4,4 flou 2,4 opacité 0,46, or au coin haut-droit,
     blanc au bas-gauche, il respire ±3° sur 9,4 s) ;
   - **bordure №2** : liseré interne `cardLisereDedans` 1,1 pt,
     gris, jamais saturé ;
   - le verre : `glassEffect(.clear)` dans
     `GlassEffectContainer(spacing: 0)`, bounds CONSTANTS.
   Le contenu : « gros texte blanc » = le registre widget mesuré —
   héros `.inter(0,175·H, .semibold)` en **dégradé métal
   white 1,00 → 0,863** (jamais un blanc plat), unités/labels
   `encreDouce` (white 0,581). Quatre lignes : min, séries, exos,
   calories — la donnée est déjà là (`StorySession` : minutes,
   series, exos, kcal = minutes × 7, l'estimation franche). Les
   nombres COMPTENT à l'horloge (école `count(to:from:)`,
   `StoryOne.swift:301-304`).
   ⚠️ Lois du verre, toutes payées : l'encre AU-DESSUS du verre,
   jamais dans le conteneur (l'encre dedans est lentillée) ; le
   verre ignore `.opacity` — la matérialisation est un fondu de
   calques par-dessus, la taille ne bouge JAMAIS (le verre aux
   bounds vivants = blur plat définitif) ; **AUCUN
   `rotation3DEffect`** sur la card (verre natif + tilt = le verre
   grossit et se détache, et le `compositingGroup` qui répare tue la
   réfraction — le gyro doux reste possible sur la pills, pas sur le
   verre) ; sur noir pur le corps du verre est invisible — c'est le
   LISERÉ qui fait lire le verre, et c'est voulu.
5. **Les segments** `StoryProgress` en haut, inchangés.

Le raccord A → B : pendant le reflux de la pills (4,6 → 5,4 s),
l'éclair naît en bas et la card se matérialise au centre (fondu +
petite montée, école `contentAt` de `StoryOne`). Lecture du résumé
jusqu'au bout du `hold` (~12 s au total pour la page, à caler).

---

## 4. CE QUI NE CHANGE PAS (et qu'on protège)

- `StoryPortal` : le morph carte → écran, l'haptique `slam()`.
- Le chef d'orchestre : tap tiers gauche / reste, appui long =
  pause (l'horloge ET l'image — le nouveau `t` doit rester une
  fonction pure), tirage vers le bas = fermeture, `partitionRect`
  pour les pages qui en auront besoin.
- Les deux sites : la grille du calendrier (`CalLab.swift:319-364`)
  et le play de l'iPod (`CalLab.swift:3873-3887`, story dans
  l'arbre, `zIndex(10)`).
- `StorySession` : la donnée telle quelle. La fin de séance ne lance
  toujours PAS la story (branchement à venir, noté
  `HomeNuit.swift:1221`) — hors de ce chantier.

Les fichiers `story_1.mp4` / `story_1_loop.mp4` / `video_story_2` /
`video_story_3` et les écrans actuels ne meurent qu'au verdict de
Kathryn (§7 Q3) — rien n'est supprimé avant.

---

## 5. LES RECETTES (bloquant, avant tout code)

Un script `tools/story/recuit_story_ended.sh`, école
`recuit_duo.sh` / `recuit_calques.sh` (les pièges y sont déjà
codifiés : jamais `-ss`, ping-pong amputé de ses deux doublons de
bord, blends en `gbrp`, une passe CRF 17, `nbf()` compte les frames).

| Sortie | Source | Travail |
|---|---|---|
| `story-ended-verre-a.mp4` | `~/Downloads/pills_2.mp4` (2160×3836) | crop matière couché, ralenti, ping-pong, 30 i/s |
| `story-ended-verre-b.mp4` | `~/Downloads/Video rouge_liquid.mp4` | crop matière debout, ralenti, ping-pong, 30 i/s |
| `story-pilule-droite.mp4` | source de `home-fond-pilule` | hflip + les paramètres du recuit calques |
| `story-eclair-loop.mp4` | `~/Downloads/éclair.mp4` | crop boîte utile, inclinaison cuite, ping-pong, ralenti ×2, 30 i/s |

Chaque sortie : bords sondés (bande 4 px, seuil 8/255), couture du
ping-pong mesurée (< 2), première frame extraite en pose PNG.

---

## 6. LES JALONS (une capture validée à chaque pas)

- **E1 — les recettes.** Les quatre fichiers recuits + sondes
  (bords, couture, cadence) + planche de frames. Rien en Swift.
- **E2 — la verrière au repos.** L'écran A statique au banc
  `-endedLab` : « Session Ended » au milieu, les deux verres qui
  tournent dans les lettres. Verdict typo (la graisse d'Inter).
- **E3 — la caméra.** Zoom fou → défilement → plongeon, filmés au
  banc `-endedAuto` (la story se rejoue seule, école `-storyAuto`) ;
  fouettage : détecteur de flash + couture du raccord mesurée.
- **E4 — l'acte B.** Le reflux de la pills en haut à droite,
  l'éclair, la card `CardCorps` et ses compteurs. Capture posée à
  côté de la référence.
- **E5 — le branchement.** La nouvelle page 0 dans `StoryFlow`,
  `hold[]` recalé, segments, pause/tap/tirage vérifiés dessus ;
  **non-régression** des deux sites (grille + iPod) ; verdicts
  téléphone (⚠️ le sim est AVEUGLE aux gels Metal — les verdicts de
  fluidité se rendent sur l'iPhone).

Bancs : **les bancs EXISTANTS `-storyLab` / `-storyAuto`** — la
nouvelle page 0 vit dans `StoryFlow`, donc le banc des stories la
montre déjà ; ne pas toucher `WoopApp.swift` pendant que les
sessions parallèles y vivent vaut mieux qu'un alias de confort
(`-endedLab` abandonné, décision 26-08). **Simulateur dédié : `kat-story`** (créé et booté,
iPhone 17 Pro / iOS 26.5, UDID `58183E61-2F08-4A03-BD65-7F0BC1B19BA1`),
derived data `dd-story` — les sims des autres sessions ne sont pas
touchés. Les sessions parallèles ont `SessionSlate.swift` en vol :
**committer PAR CHEMINS, ses seuls hunks** (leçon payée deux fois).

---

## 6 bis. LES PARTIS PRIS DU PREMIER JET (26-08 — tout se rejuge
## sur capture)

- **Les deux verres sont COUCHÉS le long des mots** (transpose 90°,
  bande 1920×640, la gélule ENTIÈRE avec du noir aux bouts — l'objet
  doit se LIRE, pas devenir une texture). « Session » = pills_2
  (dôme spéculaire), « Ended » = rouge_liquid (braise ambrée).
- **La caméra voyage vers « Ended »** : le texte file vers la
  gauche, on lit vers la droite, et le plongeon vise le bol du
  premier « d » de « Ended » (`focus = midX + 0,17 × largeur`).
- **Le ralenti des verres est ×1,5** (pas le ×3 de la home) : dans
  les lettres, la pills doit VISIBLEMENT tourner.
- **L'acte B ouvre sur la pilule PLEIN CADRE** (échange sec au
  sommet du plongeon, la couche décode depuis `diveAt`), puis elle
  VOLE vers son coin haut-droit en rétrécissant (`outLong`, arrivée
  à vitesse nulle) — « la grosse pills vient se placer en haut à
  droite », au mot près.
- **La naissance de la card** = un voile noir AU-DESSUS du verre qui
  s'éteint (le verre ignore `.opacity`) ; la card est montée à
  bounds constants dès la coupe.
- Libellés du premier jet : `dateLabel` en chapeau, « Résumé », et
  « min / séries / exos / calories » (le mot de la maquette).

## 6 ter. LES VERDICTS DU PREMIER TOUR DE SIM (26-08, kat-story)

Le premier jet a TOURNÉ au banc `-storyLab -storyAuto` (E1→E4 en un
tour). Ce qui est validé par la capture, ce qui est tombé :

1. **« On ne voit pas, c'est quasi tout noir »** (verdict Kathryn,
   confirmé par ma planche) : le centre du verre rouge est NOIR — la
   verrière ne « ressort » pas. Remèdes tranchés :
   - **recuire les deux verres sur les zones ROUGES/CLAIRES** de la
     matière (« prendre plusieurs vidéos de la pills quand c'est
     rouge, ou très clair ») — cadrages choisis sur pixels, la bande
     basse-gauche de chaque gélule couchée (le bulbe + le liseré
     rouge du bord) : A `crop 1980×660 @ (90,610)` du couché
     2856×1392, B `crop 1980×660 @ (40,600)` du couché 2580×1284,
     avec un petit lift `eq` (gamma ~1,22, saturation ~1,12 — la
     saturation MONTE, loi anti-brun) ; **PAS ENCORE RECUIT** ;
   - le SOCLE de glyphe (école ChiffreRevele) : une lettre à
     white 0,105 SOUS la vidéo, dans le même masque — CODÉ.
2. **La card du résumé** : « même taille que les cards rewards »
   — `l = min(0,80·L, 332)`, `h = 1,32·l`, forme **R36 continuous**
   (RewardCard.swift:185-198) ; matière = « dégradé noir → liquid
   glass comme dans les petites cards exercice » : LA recette
   d'ExercisesView.swift:2324-2340 — une seule dalle
   `glassEffect(.clear, in: forme)` + **la NUIT par-dessus qui se
   dissout** (stops : noir plein → 0,72 @0,58 → 0 @0,78) ; typo
   « à la Apple » = **SF (system), plus gros** — le CardCorps du
   premier jet MEURT sur cet écran. **PAS ENCORE CODÉ.**
3. **La phrase à la Apple** : « Kathryn, votre session du 12 juin »,
   SF bold GRANDE, **alternance blanc/gris par ligne** (la maquette
   « With only / 5 hours of sleep / … »), posée haut-gauche, la card
   la RECOUVRE en partie. **CODÉE** (blanc 0,96 / gris 0,52,
   34 pt bold, stagger 0,12 s ; prénom en dur — la dette du
   « Bonjour Kathryn » de la home, même endroit du backlog).
4. Positions recalées au premier tour (CODÉ) : pills 0,78·L collée
   à droite (top 0,10·H), éclair remonté (plus coupé par le bas).
5. Ce que la planche VALIDE déjà : le portail, la mécanique
   zoom → défilement → plongeon → coupe → reflux, les compteurs, la
   pause/tap/tirage du chef d'orchestre sur la nouvelle page.

## 8. PAGE 2 — « DÉTAILS » (brief 26-08, maquette Frame …228)

L'écran 2 du flow (à la place de l'actuel StoryTwo « fumée ») :

- **Le fond** : une GROSSE vidéo de pills — le gros plan macro
  (l'arc du verre qui mange le bas de l'écran sur la maquette),
  ANIMÉE (« donc faut animation ») ; recuit dédié à prévoir (un
  cadrage macro de `rouge_liquid`/`pills_2`, école des verres).
- **L'éclair** aussi sur cette page — en HAUT À DROITE (maquette),
  penché ; c'est `story-eclair-loop` réutilisé, position propre.
- **Le titre** : « Détails », haut-gauche, le registre SF bold de
  la phrase (le même que « Kathryn, votre session… »).
- **La liste** : la partition existante `SlateListe` (vignette,
  nom, petites flammes, Set 1/2/3, +20 et la pièce gelée) — mais
  **REPLIÉE PAR DÉFAUT** (« on fait replier par défaut ») : tous
  les groupes fermés, le tap déplie (la grammaire du dépliage DANS
  les données est déjà payée — piège ForEach). La zone
  `partitionRect` du chef d'orchestre continue de protéger ses taps.

## 9. PAGE 3 — « STORY CARD » (brief 26-08, maquette Frame …230)

L'écran 3 : l'ANALYSE. À la place de l'actuel StoryThree :

- **Le fond** : le noir, avec la grosse vidéo de pills SUR LE CÔTÉ
  (à gauche sur la maquette, le verre qui entre par le flanc).
- **LA CARD** : un NOUVEAU VARIANT des cards rewards, nommé
  **`.story`** — « on va créer encore un variant de cards rewards
  qui s'appelle Story cards » :
  - fond NOIR comme les robes rewards (la grammaire RewardCard),
    taille rewards, R36 ;
  - **LES STICKERS** : des stickers die-cut (liseré blanc, école de
    la maquette : pêche + sneaker) choisis « selon ce que le user a
    fait » — mapping activité → stickers ; ils **BOUGENT** (petites
    horloges de flottement/balancement, école sticker-flamme de la
    robe fire) et portent **UN HALO DE LUMIÈRE** ;
  - **LE TEXTE D'ANALYSE** : SF, l'alternance blanc/gris (le bloc
    « With only 5 hours of sleep… ») — STATIQUE d'abord, et « plus
    tard contextuel » : c'est le contrat des textes dynamiques déjà
    écrit au plan backend (`tools/rewards/PLAN-REWARDS-BACKEND.md`
    §4 — bigLines, longueur max contractuelle, l'IA choisit les
    MOTS jamais la typo) ; la robe `.story` doit y inscrire SA
    ligne de contrat (nombre de lignes, longueur max, quels mots
    peuvent être gris).
  - Assets stickers : à inventorier — le calendrier à stickers a
    déjà des planches ; sinon Kathryn livre les PNG die-cut.

## 6 quater. LE TOUR 2 (26-08 après-midi — « go » sur tout)

Tout le §6 ter est PAYÉ, plus les pages 2-3. Mesuré au sim :

- **Verres v2 recuits sur les bandes claires** — mais le premier
  cadrage de B (y 600) manquait le bulbe : recalé **y 300** (le
  bulbe vit à y 306..871 du couché). A garde son cadrage (à re-juger
  si le verdict téléphone le trouve sombre). Socle monté à 0,13
  (0,105 restait sous le seuil de lecture au repos).
- **Le repos cadrait faux** : viser « Session » poussait « Ended »
  hors écran — au repos le focus est le CENTRE DE LA LIGNE, le zoom
  recale sur « Session » en grossissant.
- **Le plongeon** : ×12 coupait en plein zoom (lettre entière à
  l'écran) → **×34**, et la cible déplacée sur le « n » d'Ended
  (minX + 0,26·l) — là où l'aspectFill pose le bulbe AMBRÉ du verre
  B : l'intérieur de la lettre est incandescent à la coupe, la
  pills qui suit est de la même chair.
- **Fouettage** : détecteur de flash sur le film complet (916
  frames) — AUCUN flash en V ; une seule coupe d'une frame, celle
  du plongeon (ΔY 25,7, vers le PLUS clair), voulue.
- **Les deux macros 4K natives** cuites (`story-macro-bas` 1720×1408
  de pills_2, `story-macro-flanc` 1276×1632 de rouge_liquid, ralenti
  ×2, 30 i/s, CRF 17) — leurs bords de coupe sont posés SUR les
  bords de l'écran, donc ils n'existent pas.
- **Pages 2-3 CODÉES** (`Woop/Views/StorySuite.swift`) :
  `StoryDetails` (dôme bas + éclair haut-droite + « Détails » +
  `SlateListe` repliée : `courant: ""`, rien à changer au composant)
  et `StoryAnalyse` + **`StoryCard`** — la robe `.story` vit dans
  StorySuite EN ATTENDANT (RewardCard.swift est en vol dans une
  session parallèle, on n'y touche pas ; elle y déménagera au
  calme). Stickers = les PNG du CALENDRIER (`WoopSticker.asset`,
  vérifié : basket/abricot/chocolat/bras existent), lévitation
  glaciale ±2 pt sur horloges premières en fonctions pures de `t`,
  halo qui respire, paire déterministe (hash stable de `dateLabel`,
  JAMAIS `hashValue` — il change à chaque lancement).
- Reste pour E5 : la non-régression des deux sites au DOIGT (le
  plumbing est intact mais un tap réel vaut mieux qu'un
  raisonnement), et les verdicts téléphone.

## 6 quinquies. LE TOUR 3 — LES QUATRE VERDICTS (26-08 soir).
## **PAYÉ le soir même** — tout ce qui suit est codé, cuit et filmé
## (fouettage : 2296 frames, AUCUN flash en V). Écarts au plan :
## les bandes larges restaient noires à droite (le cœur orange est
## une COLONNE, mesuré) — les verres v3 sont donc des crops SERRÉS
## dans les bulbes, ÉTIRÉS en 1920×640 (A : pills_2 1000×600@(40,560),
## gamma 1,30 sat 1,14 ; B : rouge 1100×660@(0,220), gamma 1,22
## sat 1,12) — le verre est amorphe, l'étirement se lit comme une
## coulée. Le plongeon rend un « n » OR incandescent plein écran.

### 1. La verrière : ORANGE, et « de base zoomé » + haptique

« On ne voit pas assez la couleur — prends les parties ORANGES de
la vidéo. Pas assez Apple en zoom : DE BASE ça doit être zoomé,
pour diminuer l'effet cheap. + haptique. »

- **Recuit v3 des deux verres, cadrés SUR l'orange** : les bandes
  actuelles gardent trop de verre noir. On resserre sur la matière
  incandescente et on ACCEPTE l'upscale (verre = matière douce) :
  - verre A (pills_2 couché 2856×1392) : ~`crop 1440×480` centré
    sur le bulbe crème + le liseré rouge (zone x 0..1500,
    y 640..1280) → `scale 1920×640` ;
  - verre B (rouge couché 2580×1284) : ~`crop 1440×480` DANS le
    bulbe ambré (x 0..1500, y 300..900) → `scale 1920×640` ;
  - cadres exacts posés SUR frames extraites au moment du bake
    (jamais de tête), même eq (gamma 1,22, sat 1,12).
- **L'animation change de grammaire** : le zoom-depuis-petit MEURT
  (c'est lui, l'effet cheap). La caméra est DÉJÀ dans le texte à
  la première image — on ne voit jamais la ligne entière :
  - 0 → 0,7 s : naissance à k 0,94 → 1,0 (l'approche
    imperceptible), focus au DÉBUT de la ligne (« Se » plein
    écran) ;
  - 0,7 → 3,4 s : LE TRAVELLING — toute la ligne défile devant la
    caméra à k = 1 (c'est LA passe de lecture, l'école du site
    M5) ; vitesse easée aux deux bouts ;
  - 3,4 → 4,4 s : LE PLONGEON ×34 sur le « n » ambré, inchangé ;
  - 4,4 s : la coupe (la page gagne ~0,4 s, `hold[0]` recalé).
- **La partition haptique** (sensoryFeedback sur des BEATS dérivés
  de t — des entiers calculés, jamais un grain par image) :
  - un impact doux au départ du travelling ;
  - un grain léger quand CHAQUE MOT passe le centre de l'écran
    (deux grains en tout — la trame du moteur sature au-delà) ;
  - **LE SLAM à la coupe** (`SwapFeedback.shared.slam()` —
    l'atterrissage le plus lourd de la maison : on rentre DANS la
    pills) ;
  - un impact doux à la matérialisation de la card.
  ⚠️ Le sim est muet côté haptique — verdict téléphone.

### 2. L'acte B : la card au centre, la pills penchée vers ELLE

- **La card se CENTRE** (`x = 0,50·L` — elle était à 0,54).
- **La pills grossit** (~0,95·L de large, toujours collée à
  droite) et **s'incline VERS LA CARD** : `rotationEffect` d'une
  douzaine de degrés, le nez qui plonge vers la card et plus vers
  la phrase. Rotation SwiftUI sûre ici : additif sur noir, les
  bords noirs tournés n'ajoutent rien.
- **La nuit de la card recule** : noir plein sur les **30 % du
  haut SEULEMENT**, puis dissolution franche — « et après liquid
  glass » : stops ~ noir@0 → noir@0,30 → 0,50@0,45 → 0,15@0,65 →
  0@0,85. Les chiffres du bas vivent SUR le verre — lisibilité à
  vérifier sur capture (la pills passe derrière).

### 3. « Détails » : le dôme ZOOMÉ, qui FOND quand le texte arrive

- **Le dôme grossit** (« zoomé comme ça vers le bas », la
  maquette) : cadre ~1,35·L de large, ancré au bord bas, la crête
  qui monte depuis la droite — les bords de coupe restent posés
  hors écran.
- **Le fondu d'arrière-plan** : quand la partition arrive
  (t ≈ 0,35+), le dôme RECULE — opacité vers ~0,45 + un voile noir
  gradient sur la zone de la liste, calés sur la MÊME rampe que
  l'entrée de la liste (une seule chose bouge à la fois : le voile
  et la liste partagent leur sstep).

### 4. La story card : la vidéo EN GROS à gauche, FONDUE

- **Le flanc grossit** (~0,95·L, la moitié hors écran à gauche,
  posé haut) — « en gros à gauche ».
- **Fondue comme la home côté gauche** : les bords EXPOSÉS (droit
  et bas — là où la coupe traverse le verre) fondent dans la nuit
  par masque gradient (l'école des flancs de RewardCard : clear /
  0,3 @ 12 % / 1 @ 30 %), et le calque passe en `.plusLighter` sur
  le noir — aucun bord ne doit exister, le verre FOND dans la page
  (le verdict payé du fond home : « le corps du verre ne doit pas
  avoir de bord, il doit FONDRE dans la nuit »).

## 6 sexies. LE TOUR 4 — LES INCLINAISONS ET LA STORY CARD RICHE
## (26-08 nuit). **PAYÉ sur le « ok »** — recuits v2 des deux macros
## (l'arc cuit à +22° : `crop pills 1392×2856 → rotate 22° →
## crop 1720×1296@(460,60)` ; le bulbe : `rouge 1500×1352@(400,1948)`,
## noir naturel gardé, masque mort), pills rangée coin haut-droit
## 0,62·L à 32°, card riche codée (planche bras/basket/chocolat/
## abricot + flamme par heuristique locale sur le titre — le vrai
## choix viendra des faits —, slam de pose par sticker, spotlight
## qui balaie, `PoudreStory` jumelle locale de PoudreDiamant —
## l'originale est private dans RewardCard en vol —, « KING » argent
## fondu derrière, gabarit de la bigWord). Fouettage : 2242 frames,
## AUCUN flash. Les trois pages collent aux Frames …228/…230/…233.

Verdict d'ouverture : « t'écoutes pas ce que je t'ai dit » — le
tour 3 a raté DEUX inclinaisons. On les répare en regardant SES
images (Frames …228 et …230), pas de tête.

### 1. Story 1 (le résumé) : la pills VERS LA CARD, pas sur le texte

Le 12° du tour 3 ne suffisait pas : la pills barre encore tout le
haut DERRIÈRE la phrase (« pas faire le haut du texte ! »). La
composition change :

- la pills se RANGE dans le coin haut-DROIT (plus petite,
  ~0,62·L), le corps qui déborde par le coin — le haut-gauche
  redevient du NOIR pour la phrase ;
- l'inclinaison passe à ~30-35° : le NEZ PLONGE vers la card, la
  diagonale de la maquette d'origine (rotation SwiftUI sûre :
  additif sur noir) ;
- la phrase ne rencontre plus le verre qu'à son extrême droite.
- Verdict sur capture, valeurs dans `EndedCine`.

### 2. Story 2 (Détails) : le dôme est un ARC DIAGONAL

La Frame …228 ne montre pas un dôme posé : l'arc TRAVERSE l'écran
en diagonale — il entre bas-gauche, la crête vers le haut-droit
(~40 % de hauteur), l'ambre le long du flanc bas, le spéculaire
sur l'arête haute. Le mien est symétrique et couché au fond.

- **Recuit v2 de `story-macro-bas`** : la rotation se CUIT
  (~−22-25°, `rotate=…:fillcolor=black`, l'école du verre couché
  de la home), puis crop DANS la zone sûre — jamais un
  `rotationEffect` sur ce calque : ses bords de coupe entreraient
  dans l'écran en tournant ;
- cadres mesurés sur frames extraites au moment du bake, bords de
  coupe posés HORS écran, définition native conservée ;
- placement : ancré bas, débordant à gauche ET à droite.

### 3. Story 3 (Story card) : le BULBE ROND, pas l'épaule

« Même commentaire » — la Frame …230 montre LE BULBE incandescent
de la gélule vu de près : une masse presque RONDE de verre
rouge/ambre qui tourbillonne, son CONTOUR courbe net contre le
noir en bas-droite, fondue hors écran en haut-gauche. Mon flanc
actuel montre l'épaule, mauvaise matière.

- **Recuit v2 de `story-macro-flanc`** : re-cadrer sur LE BULBE de
  `rouge_liquid` (le bas de la gélule debout, zone ~x 490..1770,
  y 2050..3220 — presque carré, définition native, ralenti ×2) ;
- le crop GARDE le noir naturel autour du bulbe : le contour rond
  du verre est le VRAI bord de l'objet — **le masque de fondu du
  tour 3 MEURT sur les côtés visibles** (droite/bas), il
  n'écrasera plus le contour ; seuls les bords hors écran
  (haut/gauche) n'ont besoin de rien ;
- posé haut-gauche débordant, `plusLighter` conservé.

### 4. La story card — le variant 5 s'enrichit

« Augmente l'animation » + quatre ajouts, tous de la grammaire
rewards existante :

- **LES STICKERS = DES PERFORMANCES.** Chaque sticker correspond à
  une CATÉGORIE de la séance, choisi par les FAITS (jamais au
  hasard) :
  | catégorie dominante | sticker |
  | --- | --- |
  | haut du corps (muscu) | `sticker-bras` (le muscle) |
  | cardio | `sticker-basket` |
  | abdos | `sticker-chocolat` (la tablette) |
  | bas du corps | `sticker-abricot` (à confirmer) |
  | intensité / record / streak | `sticker-flamme` (à confirmer) |
  Les DEUX catégories dominantes de la séance → les deux stickers
  de la card. **Le contrat complet vit au plan backend** (§4 ter
  de `../rewards/PLAN-REWARDS-BACKEND.md`, ajouté ce soir) : le
  fact engine calcule les volumes par catégorie, le moteur choisit
  DANS la planche, l'IA n'invente jamais un sticker.
- **PLUS D'ANIMATION** : chaque sticker ARRIVE avec du poids (le
  slam de pose de la pièce du calendrier — l'ombre qui s'écrase),
  lévitation amplifiée, balancement ±3-4°, respiration d'échelle
  légère — toujours des fonctions pures de `t`, horloges premières.
- **LE HALO DEVIENT SPOTLIGHT** : plus un simple radial — la nappe
  qui BALAIE et accroche les stickers au passage (l'école du
  balayage des robes welcome/fire), plus intense que le halo du
  tour 2.
- **LA POUDRE DE DIAMANT** : `PoudreDiamant` (RewardCard.swift:421,
  la poudre des cards rewards) posée dans la card, autour des
  stickers.
- **LE TEXTE GÉANT DERRIÈRE** : un MOT (« KING », « BOSS », …)
  derrière les stickers, en argent fondu — l'école `TexteGeant` de
  la robe welcome (le texte géant derrière, fondu majestueux) ;
  DYNAMIQUE plus tard : c'est une `bigWord` du contrat backend
  (3-6 lettres, la borne est contractuelle).
- **LE TEXTE D'ANALYSE DEVIENT IA** : les lignes blanc/gris
  restent la grammaire (l'IA choisit les mots ET quels mots sont
  gris, borné au contrat §4 ter) — statique au banc en attendant.

### L'ordre de paiement du tour 4

T4-a les deux recuits v2 (dôme diagonal, bulbe rond) + sondes ;
T4-b story 1 : la pills rangée/inclinée ; T4-c la story card
riche (stickers-performances mappés en local, slam, spotlight,
poudre, texte géant) ; T4-d capture des trois pages posée à côté
des Frames …228/…230 + fouettage.

## 6 septies. LE TOUR 5 — LA CARD PROFONDE, LES 6 PHRASES, LE VRAI
## 4K (26-08). **PAYÉ le jour même**, avec deux verdicts mid-course
## de Kathryn intégrés (« plus gros le texte derrière les stickers »,
## « plus fondu, magnifique, ça prend tout le header, très luxe ») :
## le mot argent vit à corps ×1,55 (à ×2 il ne montrait que son
## ventre), tête FONDUE dans la card (posée plus bas — coupée net au
## bord au premier jet, mesuré). Recuit 4K v3 fait (lanczos ×1,4
## avant rotation +29°, fenêtre 2400×1820, affichage 1,75·L).
## Micro-détails 1-2-4-5-6-7-8-9 CODÉS (le n° 3, l'éventail au tap,
## attend le verdict) ; le tilt/l'appui vivent dans le rect remonté
## au chef (`page >= 1` — un drag né dans la card ne ferme plus la
## story). Les 6 phrases VRAIES tournent (gabarits par catégorie,
## « 26 kg on crunch », troncature sans mot-outil traînant —
## « crunch à la, » payé au sim). Fouettage : 2457 frames, AUCUN
## flash. Le plan du tour disait :

### 1. Le titre géant : PLUS GROS, fondu en dégradé

« Le gros titre fait cheap. » Le « KING » du tour 4 était trop
petit (0,34·l) et trop simplement voilé. La refonte, école
`TexteGeant` de la robe welcome (la seule référence maison d'un
texte géant qui ne fait PAS cheap) :

- **le corps monte à ~0,52·l** — le mot DÉBORDE derrière les
  stickers, coupé par les flancs de la card (un texte géant qui
  tient dans la card n'est pas géant) ;
- **le fondu est un DÉGRADÉ à deux étages** : l'encre elle-même en
  argent riche (blanc 0,92 → 0,30, l'axe vertical) ET le masque de
  dissolution (plein en haut du mot, mort aux deux tiers — jamais
  un simple opacity) ; les flancs fondent aussi (le masque
  horizontal des flancs, école welcome) ;
- un **glint** le traverse par instants (voir micro-détail n° 4) ;
- la composition stickers/titre se resserre : le mot posé PLUS
  HAUT, les stickers qui MORDENT dessus (le chevauchement fait la
  profondeur — un titre derrière qui ne touche rien fait sticker
  de foire).

### 2. LES MICRO-DÉTAILS ET INTERACTIONS de la card (« genre 7 au
### moins » — en voilà neuf, chacun sur une école payée)

1. **LE TILT AU DRAG** : la card suit le doigt à ±11°
   (l'école RewardCard) — AUTORISÉ ici : cette card n'a PAS de
   verre natif (fond opaque), la loi verre+rotation3D ne mord pas.
2. **LE GYRO DOUX** : au poignet, les stickers bougent en
   PARALLAXE différentielle (l'avant plus que l'arrière, le titre
   presque pas) — la profondeur se joue à PLUSIEURS, école
   pastille-lune : « la lumière n'appartient qu'au poignet ».
3. **LE TAP SUR UN STICKER** : il BONDIT (petit ressort sur le
   modificateur, jamais sur l'état animé) et jette un ÉVENTAIL de
   mini-stickers à gravité — l'école des 42 flammes de la robe
   fire (Canvas, sprite résolu UNE fois, hash déterministe) + un
   grain haptique. Le sticker flamme jette des flammes, la basket
   des mini-baskets.
4. **LE GLINT DU TITRE** : une lame spéculaire balaie « KING »
   toutes les ~5 s (`.mask(Text)`, l'école « NOUVEAU » de
   BoosterLab) — jamais en continu, un événement.
5. **LA POUDRE OBÉIT À LA LUMIÈRE** : les grains brillent PLUS
   quand la nappe du spotlight passe sur eux (gain fonction de la
   distance au centre de la nappe) — « les paillettes ne vivent
   que dans la lumière », la loi du métal.
6. **LES OMBRES VIVENT** : l'ombre de chaque sticker s'allonge à
   l'OPPOSÉ du spotlight qui balaie — une seule lumière dans la
   scène, tout lui obéit.
7. **L'ENTRÉE SÉQUENCÉE HAPTIQUE** : le titre fond d'abord, puis
   chaque sticker SLAM avec son grain (3 grains, jamais plus), puis
   les lignes s'allument — le rythme existe déjà, l'haptique par
   slam manque.
8. **L'APPUI LONG** : la story se met en pause (grammaire du chef,
   acquise) ET la card se SOULÈVE (échelle 1,02, l'ombre s'étale) —
   on la tient entre les doigts.
9. **LA LECTURE QUI S'ALLUME** : pendant la lecture, les lignes
   grises passent au blanc UNE À UNE (la ligne « active » suit
   l'horloge de la page) — le texte se lit tout seul, école des
   fondus échelonnés (⚠️ piège payé : sous `withAnimation` ces
   rampes ne jouent qu'au doigt — ici tout est déjà fonction de
   `t`, le piège ne mord pas).

Le n° 3 et le n° 9 sont les plus chers — à payer en dernier, sur
verdict de capture des sept autres.

### 3. LES SIX PHRASES VRAIES — le moteur

« Des phrases vraies en fonction des exos du catalogue et de la
performance user — et l'IA devra respecter 6 phrases. » Le contrat
passe de « 4 à 6 lignes » à **EXACTEMENT 6** (amendé au §4 ter du
plan backend) :

- **la matière** : `StorySession.groupes` porte déjà les VRAIS exos
  (`ExerciseCatalog` : nom, muscle) et les vraies séries
  (reps/kg/secondes) — les phrases citent LE NOM DU CATALOGUE et
  LA PERFORMANCE (« 28 kg on bench », jamais « you did great ») ;
- **les faits locaux v1** (avant le fact engine serveur) : meilleure
  série (exo + charge), groupe dominant, volume total, densité
  (volume/min), série la plus longue — calculés du `StorySession`,
  pas d'IA requise ;
- **les gabarits déterministes** : une famille de 6 lignes par
  CATÉGORIE dominante (haut du corps / cardio / abdos / bas du
  corps), à trous typés :
  `["Big push day.", "{kg} kg on", "{exo_court},", "your best set.",
  "{series} sets in {min} min.", "Keep pressing."]` — les nombres
  RECOPIÉS des faits (la loi §4), le nom d'exo TRONQUÉ au contrat ;
- **l'alternance** : le NOYAU narratif en blanc, les circonstances
  en gris — le gabarit marque chaque mot ; l'IA, plus tard, remplit
  le MÊME moule : 6 lignes, ≤ 20 signes, drapeaux gris par mot ;
- **la bigWord** vient du même moteur : un TIER de performance
  (volume/PR/densité) → « KING » / « BOSS » / « SOLID » — table au
  backend, jamais un choix libre.

### 4. Story 2 : la pills BEAUCOUP plus grande, la vraie
### orientation, le VRAI 4K

« Ça va pas : la pills est beaucoup plus grande, regarde
l'orientation, il faut vraiment un 4K là. » Trois causes, trois
remèdes au recuit v3 de `story-macro-bas` :

- **l'échelle** : sur la Frame …228 le verre mange ~55 % de
  l'écran, la crête vers 42 % de hauteur — l'affichage passe de
  1,35·L à **~1,75·L**, ancré bas-droit ;
- **l'orientation** : la pente de SA courbe est plus raide — la
  rotation cuite passe de +22° à **~+28-30°**, et le cadre remonte
  pour garder la crête haut-droit et la fuite bas-gauche (cadre
  posé sur frames extraites, comme toujours) ;
- **le 4K** : à 1,75·L l'affichage fait ~2110 px de large @3x — le
  crop actuel (1720) est SOUS l'écran. La source se
  SUR-ÉCHANTILLONNE ×1,4 (lanczos) AVANT la rotation, et la
  fenêtre sort à **~2400×1800** — au-dessus de l'affichage, plus
  aucune bouillie possible. Budget décodage à re-mesurer (une
  seule couche, ça passe — à confirmer à la SondeCadence téléphone).

L'ordre de paiement : T5-a le recuit 4K de la story 2 (le plus
court) ; T5-b le titre géant ; T5-c les micro-détails 1-2-4-5-6-7-8
(les sept sûrs) ; T5-d le moteur des 6 phrases + branchement des
gabarits ; T5-e les n° 3 et 9 sur verdict ; captures à chaque pas.

## 6 octies. LE TOUR 6 — LE DÉCALAGE, ET LA LUMIÈRE DIFFUSE (26-08)

### 1. LE BUG DU DÉCALAGE — cause trouvée, mesurée, morte

« Quand je clique sur une ligne ça se décale vs quand c'est
replié — il faut corriger le même bug sur le composant player. »

**La cause** (sondée : `-slateSonde` déplie/replie tout seul, plus
des bordures de debug filmées) : `SetHistoryRow` a une largeur
MINIMALE INCOMPRESSIBLE — lune + « Set N » + les trois métriques
en `fixedSize` + le gain ≈ **342 pt**. La liste de la story n'en
offrait que ~310 : la ligne dépliée ÉLARGISSAIT le ScrollView,
donc la liste, donc la colonne de la page — que le parent
RECENTRAIT. Mesuré : le titre « Détails » sautait de x 96 à
x 158 (**62 px**) à chaque dépliage.

C'est le piège maison de LA FENTE QUI GONFLE SON HÔTE, re-payé.

**Le remède, dans le composant PARTAGÉ** (`SlateListe`, donc la
story ET l'ardoise du player d'un coup) : un `GeometryReader`
prend la largeur PROPOSÉE et ne la rend jamais — la largeur est
IMPOSÉE au contenu (`.frame(width: g.size.width)` + `clipped`).
Et pour que rien ne soit rogné, la liste de la story court plus
large que son titre (marge 6 au lieu de 24 : 354 pt de contenu
> 342 requis).

**Vérifié au pixel** : story → titre 104..699 et rangée 113..1100
IMMOBILES sur toute la bascule ; player (`-calLab -slateOpen`) →
rangée 103..1112, titre d'exo 187..938, immobiles aussi.

### 2. LE BALAYAGE DU MOT — mort, remplacé par la lumière diffuse

« Le balayage sur la police c'est trop cheap, il faut que ce soit
plus diffus et irrégulier, qui vient de partout dans le texte. »

La LAME est supprimée. À sa place, **sept nappes molles** dans le
masque du glyphe, chacune sur SA période première (3,7 / 5,3 /
7,1 / 4,3 / 6,7 / 9,1 / 5,9 s) et SA phase (hash déterministe) :
elles s'allument par une bosse étroite (`sin^6`), dérivent à
peine pendant qu'elles brillent, et meurent — jamais deux au même
endroit, jamais une traversée. Flou 6 pt. C'est l'irrégularité
qui fait le métal ; un balayage régulier fait le sticker.

### 3. LE FLANC GAUCHE — le mot sort de la nuit

« Le mot doit être aussi fondu sur le côté gauche, il commence
trop loin. » Le masque des flancs est asymétrique désormais :
clear → 0,35 @16 % → plein @42 % à gauche (contre 88 % → clear à
droite) — le mot ÉMERGE de la nuit au lieu d'être posé dessus.

## 7. À TRANCHER PAR KATHRYN

Tranché en cours de route (26-08) : le chapeau EXISTE (la phrase
« Kathryn, votre session du … », §6 ter.3) ; « calories » est le
mot ; les pages 2-3 sont remplacées par « Détails » (§8) et « Story
card » (§9) ; la graisse était un faux problème (Inter-Bold est
embarqué) — et la verrière parle en Inter-Bold tant qu'un verdict ne
réclame pas SF aussi là.

Reste ouvert :

1. **La lettre du plongeon** — verdict sur capture E3 (aujourd'hui :
   le bol du premier « d » de « Ended »).
2. **« Session Ended »** tel quel, ou un autre libellé ?
3. **Les stickers de la robe `.story`** : la planche vient d'où —
   les stickers du calendrier, ou des PNG die-cut neufs à livrer ?
   Et le mapping activité → sticker (qui décide quoi, en attendant
   le contextuel) ?
4. **La vidéo macro des pages 2-3** : un seul recuit macro partagé
   (bas d'écran page 2 / flanc page 3), ou deux cadrages dédiés ?
