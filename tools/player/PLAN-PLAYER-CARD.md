# PLAN HARD — LE PLAYER UNIFIÉ + LE RIDEAU (comportement UI/UX)

> Écrit le 30-08 après DEUX échecs (le rideau qui rend en continu → tel qui
> chauffe ; le player-fiche monté en haut → fantôme derrière l'image). Ce plan
> fige le COMPORTEMENT avant toute ligne. On ne code pas tant qu'il n'est pas
> validé par Kathryn.

---

## 0. L'INVARIANT (la règle de Kathryn, mot pour mot)

1. **Chaque page est une « grosse card »** — home, liste d'exercices, **détail
   d'exercice**. Même cadre, mêmes coins, même comportement.
2. **Le player est UN SEUL composant**, monté **partout pareil**.
3. **Le player est TOUJOURS EN BAS, SOUS LE GALET.** Jamais en haut, jamais
   flottant, jamais fantôme. (Le player en haut de la fiche = **régression** à
   corriger — il y a été monté par une autre session.)
4. **Au DRAG, le player POUSSE la page** (la grosse card monte) et **découvre
   le détail du player dessous** ; **un drag vers le bas repose la page**.
5. **Même geste, même rendu, même composant sur les trois pages.** Zéro
   divergence d'un pouième.

---

## 1. L'ÉTAT DES LIEUX — le « bazar » actuel (mesuré, `fichier:ligne`)

Le player existe aujourd'hui en **quatre formes qui divergent** — c'est ÇA, le
bazar :

| Forme | Où | Position | Nature | Verdict |
|---|---|---|---|---|
| `WorkoutPill(docked:true)` | home `HomeNuit:2559` | **bas** | dalle | ✅ la référence |
| `WorkoutPill(docked:true)` | liste `ExercisesView:1213` | bas | dalle | ✅ |
| `WorkoutPill(docked:false)` | **fiche** `ExerciseDetailView:626` | **HAUT** (`.overlay(.top)`) | pilule flottante | 🔴 régression + fantôme derrière l'image |
| `ActiveWorkoutSheet` | `WoopApp:1068` | plein écran | **`.sheet` modal transparent** | 🔴 « le gros player qui fout le bazar » |
| `SessionSlate` | banc `CalLab:195` | bas | tiroir qui monte | ⚪ jamais dans le vrai flow |

**« Le gros player dégeu qui fout le bazar » = l'`ActiveWorkoutSheet`** : une
`.sheet` système au fond verre TRANSPARENT (`ActiveWorkoutView:243`, `.regular`
— INTERDIT par la doctrine). Ouvert, c'est un modal plein écran ; c'est lui qui
a causé le gel (corrigé en surface par e9521cf). Il ne ressemble à aucune des
dalles, s'ouvre par-dessus tout, et casse la lecture « page = card ».

**Ce qu'on veut à la place** : **une seule dalle en bas** (la référence home),
qu'on **tire pour pousser la page** et lire la séance. Plus de `.sheet`, plus de
pilule flottante en haut, plus de `SessionSlate` isolé au banc.

---

## 2. LE COMPORTEMENT CIBLE — la machine à états + le rideau

### 2.1 Les états (un seul curseur `levee` ∈ [0,1], piloté au doigt)

⚠️ **CORRIGÉ 30-08 (verdict Kathryn : « c'est le PLAYER qui pousse, se grandit
et pousse la page ») — L'ACTEUR DU MOUVEMENT EST LE PLAYER, PAS LA PAGE.** La
première version (la page qui glisse vers le haut, le player statique révélé
dessous) était FAUSSE. Le chemin juste, façon now-playing Spotify/Apple Music :
**la dalle-player GRANDIT depuis le bas** — elle s'étend vers le haut, son
contenu se déploie en partition — **et c'est SA croissance qui POUSSE la page**
vers le haut, laquelle floute et s'efface à mesure.

```
 levee = 0            0 < levee < 1              levee = 1
 ┌──────────────┐    ┌──────────────┐          ┌──────────────┐
 │              │    │ ░ page       │           │ ▒▒▒ trait ▒▒ │ ← la page :
 │  LA PAGE     │    │ ░ compressée │ ← poussée ├──────────────┤   un TRAIT flou
 │ (grosse card)│    │ ░ + floue    │   par le  │  ▂▂ player   │
 │    NETTE     │    ├──────────────┤   player  │  (sommet)    │
 │              │    │ ▲▲ PLAYER ▲▲ │           │  série 1 ✓   │ ← le player
 ├──────────────┤    │ ▲▲ qui       │           │  série 2 ✓   │   DÉPLOYÉ :
 │ ▂▂ PLAYER ▂▂ │ ↑  │ ▲▲ GRANDIT   │           │  série 3…    │   partition
 │  (dalle bas) │    │ ▲▲ partition │           │  exo 2, 3…   │   + stop
 ├──────────────┤    │ ▲▲ qui naît  │           │              │
 │   GALET      │    └──────────────┘           └──────────────┘
 └──────────────┘     le player MONTE,           drag ↓ : il se
                      la page RECULE             range, la page revient
```

### 2.1 bis — LE LAYOUT (maquette Kathryn 30-08, la sensation des cards)

**Chaque page est une GROSSE CARD GRISE qui FLOTTE sur le fond noir** — et le
player ne vit PAS dedans : il vit **SOUS elle, dans le fond**, détaché.

```
 ┌────────────────────┐  ← fond NOIR de l'app
 │ ╭────────────────╮ │
 │ │                │ │  ← LA PAGE : grosse card GRISE arrondie,
 │ │   grosse card  │ │    marges FINES (~12-14 pt) sur les côtés
 │ │     grise      │ │    et en haut — elle flotte, on sent
 │ │   (la page)    │ │    l'objet qu'on peut pousser
 │ │                │ │
 │ ╰────────────────╯ │
 │        ──          │  ← le petit TRAIT (grabber) au-dessus de la dalle
 │ ▂▂▂ dalle player ▂ │  ← LE PLAYER : détaché, dans le fond noir,
 └────────────────────┘    la bande du bas (jamais superposé à la card)
```

- **`levee = 0`** — la card-page NETTE flotte sur le fond ; la **dalle-player
  détachée en dessous**, dans la bande du bas, avec son petit trait. Card et
  player **ne se chevauchent jamais** au repos.
- **On tire la dalle vers le HAUT** → **LE PLAYER GRANDIT** : sa dalle reste
  son sommet, la partition se déploie dedans. **Sa croissance POUSSE la card
  ENTIÈRE** vers le haut — elle floute, s'efface et **DISPARAÎT** (la
  sensation : on pousse une carte physique hors de l'écran).
- **`levee = 1`** — le player occupe l'écran (partition + stop) MAIS **il ne
  colle JAMAIS l'heure / le Dynamic Island** : son sommet s'arrête SOUS la
  zone sûre du haut, avec **de l'air + un élément premium** — un petit trait
  (grabber capsule) au sommet, et le header spotlight. Le haut respire.
- **On tire vers le BAS** → **le player se range**, la card revient, se
  re-nette, reflotte à sa place.

### 2.1 ter — LE RANGEMENT À LA SPOTIFY (verdict 30-08)

**Un tirage rapide vers le bas range le player MÊME DEPUIS LA PARTITION** —
pas seulement depuis la dalle. « Je sais qu'il y a scroll, mais si je tire
vite fait je peux la faire descendre comme Spotify. » La règle (celle des
sheets système) : quand le scroll de la partition est À SON SOMMET et que le
doigt tire FRANCHEMENT vers le bas, le geste bascule au rangement au lieu de
faire rebondir le scroll. ⚠️ On ne partage pas un doigt avec un ScrollView
(loi maison) — la solution technique se prouve au banc : lecture de l'offset
du scroll (sonde) + un geste de rangement qui ne COMMET que sur un flick
descendant net, scroll au sommet. Jamais de scrollDisabled en plein toucher.

### 2.4 L'EFFET PREMIUM (le cœur du rendu, verdicts Kathryn 30-08)

La signature, c'est la **dissolution progressive de la page** quand le player
la pousse : **flou croissant + fondu**, une animation « complexe premium » type
Apple.

1. **Le flou et le fondu suivent `levee`** (0 → net, 1 → dissous), en continu au
   doigt — pas un palier.
2. **Le player, lui, reste NET et MONTE en présence** à l'inverse (il naît, il
   grandit, il prend la page).
3. **LE PLAYER EST UNE CARD NOIRE, PAS UN BALAYAGE** (verdict v4 : « le
   balayage doit être une card noire aussi — elle balayait pas, elle
   POUSSE »). Le corps du player qui monte est LUI-MÊME une card (coins
   arrondis, le même langage d'objet que la page grise) : deux cartes
   physiques, la noire qui pousse la grise. Jamais une nappe noire plein bord
   qui « essuie » l'écran.
4. **LE MORPH DU STOP** (verdict v4) : pendant le drag, le bouton STOP de la
   dalle **quitte sa place, descend, GROSSIT en passant par un blur** (le
   morphisme suit `levee`, pic de flou à mi-course) et **se pose AU CENTRE EN
   BAS** du player déployé. **EN DESSOUS de lui** (tranché 30-08), un bouton
   **liquid glass « Page exercices »** qui renvoie vers la page exercices —
   le stop au centre, le bouton verre dessous. Au rangement, le morph
   se rejoue à l'envers (le stop remonte dans la dalle). ⚠️ Un seul stop
   visible à tout instant : celui de la dalle s'éteint dès que le fantôme
   du morph prend le relais (petit paramètre sur `WorkoutPill` — ma zone).
   ⚠️ Verre : `glassEffect(.regular)` nu INTERDIT — le bouton suit le pattern
   validé du galet molette (verre fumé `.regular.tint(noir)` interactive) ou
   `.clear` sur contenu doux ; le blur du morph est LOCAL au bouton (petite
   passe, pas plein écran — la cadence ne paie pas).
5. **L'AIR ET LA LUMIÈRE** (verdict v4) : PLUS de padding partout dans le
   player déployé (la partition respire), et un SPOTLIGHT plus présent — le
   haut du player est une scène, pas un plafond.

### 2.2 Les règles du geste

- **Le drag PART de la dalle** (la zone du player en bas). Un seul point de
  prise, sûr, sous le pouce.
- **La vitesse tranche, la position départage** au lâcher (seuils : |v| > 260
  ⇒ intention ; sinon `levee > 0.5`). L'aimant sur l'intention prédite.
- **`.global`** obligatoire (un objet qui bouge ne mesure jamais son geste
  dans son propre repère — la loi payée sur le galet ET sur mon rideau raté).

### 2.3 Ce qui bouge, et ce qui NE bouge PAS

- **Ce qui bouge à l'œil** : le player grandit, la page recule/floute/s'efface.
- **Ce qui bouge techniquement** : des **offsets** et un **MASQUE** — jamais
  une taille. Le corps du player est monté à TAILLE FINALE (plein écran) et
  **révélé par un `clipShape` animable qui grandit depuis le bas** (la loi §2
  règle 5 : un frame animé au doigt re-layoute tout ; un masque ne re-layoute
  rien). La dalle reste le sommet du masque (offset), la page prend un offset
  vers le haut + le flou/fondu du snapshot.
- **Ne bouge pas** : le galet, et le layout de tout ce que le masque révèle.
- ⚠️ **Le flou est la partie la plus DANGEREUSE pour la cadence** — voir la loi
  7 ci-dessous. Il ne se fait PAS avec un `.blur(radius:)` vivant sur la page
  native.

---

## 3. LES LOIS TECHNIQUES — payées, non négociables

1. **LE DÉTAIL DU PLAYER NE SE MONTE QUE PENDANT LE DRAG.** `if levee > 0.02 {
   partition }`. **Jamais rendu en continu** — c'est l'échec du 30-08 (tel qui
   chauffe, mini-cards derrière l'image). La loi de `SessionSlate` : « la liste
   ne vit que l'ardoise ouverte ». Voir mémoire
   `woop-piege-rideau-player-derriere`.
2. **Les données de la partition se FIGENT à la PRISE** (`@State` rempli au
   premier point du doigt), **jamais recalculées par image** (une seule visite
   SwiftData par geste).
3. **Offset + masque, jamais `frame`/`padding` animé** (§2/§5).
4. **Arbitrage de geste** : pendant le lever (`busy = true`), on DÉSARME les
   autres drags de la page — la **carte des séries** de la fiche (`carteDrag`)
   et, sur la page exo, la **molette** (`priseBasse`). Deux lifts ne partagent
   pas un doigt.
5. **La chaîne stop est préservée** : la dalle porte le stop → `DepartEtat.
   pauseOuverte` → `StopCardHote` (racine). Le player-en-card ne touche PAS à
   la chaîne de fin (trophée / pièces / booster).
6. **On tue l'`ActiveWorkoutSheet`** (le `.sheet` transparent) une fois le
   rideau en place : plus de modal, donc plus de gel possible, et le défer de
   e9521cf (`onAddExercise`) devient inutile — à retirer À CE MOMENT-LÀ.
7. **LE FLOU PREMIUM NE SE FAIT PAS AVEC UN `.blur(radius:)` VIVANT.** Un flou
   plein écran sur une page qui porte du verre natif = deux passes hors écran
   PAR IMAGE (§5), re-rasterisées à chaque image de la vidéo de fond — c'est
   EXACTEMENT le gel de la molette (60→14) et la chauffe du rideau raté. Pour
   le rendu premium sans le gel, l'ordre des options :
   - **Un SNAPSHOT flouté** : on capture la page UNE fois à la prise du doigt
     (`ImageRenderer`/`drawingGroup` gelé), on floute/fondu CE snapshot (une
     image morte, pas l'arbre vivant), et la page vivante est cachée sous lui
     pendant le lever. Zéro re-rasterisation de verre natif par image.
   - À défaut, un **`.rect(cornerRadius:).blur` via un `ViewModifier` sur un
     rendu figé**, ou un **material progressif** — jamais l'arbre vivant.
   - Ça se MESURE au banc (tranche 0) sur le TÉLÉPHONE : le lever DOIT tenir
     ~60 img/s. Si le snapshot n'y arrive pas, on baisse l'ambition du flou
     AVANT de sacrifier la cadence.

---

## 4. L'ARCHITECTURE — un seul composant, trois pages

- **UN composant `PageCard { page } player: { player }`** (nom à choisir) :
  reçoit le contenu de la PAGE et le contenu du PLAYER, gère le curseur
  `levee`, le drag, le voile, la poignée. Toute la logique du rideau vit LÀ,
  une seule fois.
- **Chaque page l'utilise pareil** : home, liste, détail passent leur propre
  `page` et le MÊME `player` (dalle + partition de la séance courante).
- **La dalle-player** = la référence home (`WorkoutPill(docked:true)`), sous le
  galet, sur les trois pages.
- **Le contenu du player détaillé** = la partition de séance (`SlateListe`,
  déjà écrite et Équatable) — montée SEULEMENT `levee > 0.02`.
- **Décision à trancher avec Kathryn** : le composant est-il monté PAR PAGE
  (chaque page l'enveloppe) ou UNE FOIS à la racine (au-dessus des onglets) ?
  - *Par page* : chaque page contrôle sa card ; mais 3 montages à garder
    synchrones, et il faut envelopper le body de chaque page.
  - *Racine unique* : un seul montage, cohérence garantie ; mais il faut que la
    racine sache quelle « page » afficher dessous (elle le sait déjà via
    `selection`), et gérer la dalle sous le galet au-dessus de la barre
    d'onglets.
  - **Reco** : composant `PageCard` réutilisable + montage PAR PAGE (chaque
    page reste maîtresse de son contenu), la dalle+partition factorisées en un
    sous-composant partagé pour ne pas diverger.

---

## 5. LES TRANCHES DE CONSTRUCTION (l'ordre, une boucle courte par tranche)

Chaque tranche = build + **verdict sur le TÉLÉPHONE** avant la suivante.

1. **Tranche 0 — le composant `PageCard` isolé au banc.** Le mouvement complet
   sur données bidon, **dans le layout de la maquette** (§2.1 bis) : la page =
   grosse card GRISE qui flotte (marges fines), la dalle-player DÉTACHÉE
   dessous dans le fond noir avec son trait ; le player grandit et pousse la
   card qui disparaît (**snapshot flouté**, loi 7) ; à pleine levée le sommet
   du player respire SOUS la zone sûre (air + grabber + spotlight, jamais
   collé à l'heure) ; **flick descendant = rangement même depuis la
   partition** (§2.1 ter). On valide MOUVEMENT, EFFET PREMIUM et CADENCE
   (~60 img/s) sur le TÉLÉPHONE avant de toucher au vrai flow.
   V3 jugée par Kathryn (30-08) : chemin ✅, mais collé à l'heure ❌, layout
   pas la sensation cards ❌, rangement depuis la partition manquant ❌.
   V4 jugée par Kathryn (30-08) : layout cards ✅ (la grise flotte, la dalle
   détachée) — mais le player montait en NAPPE qui balaye ❌ (il doit être une
   CARD NOIRE qui pousse, §2.4.3), le MORPH DU STOP manque ❌ (§2.4.4 : stop
   qui descend/grossit/blur → centre-bas + bouton verre « Page exercices »),
   et il faut PLUS d'air et de spotlight ❌ (§2.4.5). → v5 au banc.
   V5/v5.1 REJETÉES par Kathryn (30-08, « trop cheap, refais un plan ») :
   toujours l'effet BALAYAGE ❌, fond GRIS + PLAQUES ❌, stop et bouton
   INVENTÉS pas au design ❌. → le plan V6 ci-dessous (§2.6) fige le RENDU
   avant tout nouveau build.

### 2.6 V6 — LE PLAN DU RENDU (après le rejet v5 : « trop cheap »)

Le diagnostic honnête des v5 : j'INVENTAIS des matières (gris 0.045, plaques,
faux stop, capsule à bordure) au lieu de réutiliser les objets VALIDÉS de la
maison, et la physique du push était fausse (la card s'évaporait sur place →
lecture « balayage »). Les trois piliers du rendu v6 :

**A. LA PHYSIQUE DU PUSH — le contact 1:1.** Le bas de la card-page TOUCHE le
sommet du player pendant TOUTE la course : `offset_card = -levee × course` (la
course DU PLAYER, exactement — pas un facteur arbitraire). La card SORT par le
haut à la vitesse où le player monte — on la VOIT sortir, objet entier, coins
vivants. Le flou monte (0 → 24) mais l'opacité reste haute LONGTEMPS
(1 → ~0,55 sur la course) : une carte poussée hors champ, jamais une carte
évaporée sur place. C'est le contact qui fait le « poussé ».

**B. LES MATIÈRES — rien d'inventé, tout de la maison.**
- Le corps du player : **NOIR PUR + la robe de l'ardoise** — les dégradés
  noirs déjà validés de `SessionSlate.corps()` (0,95/0,88/0,25 + verre à la
  pose), PAS un `fill(gris)`. La séparation d'objet vient des coins, du trait
  et de la LUMIÈRE (spotlight), jamais d'une teinte grise.
- AUCUNE plaque : pas de fonds de rangée rajoutés, la partition vit sur le
  noir comme dans l'ardoise réelle.
- Le stop morphé : **LE VRAI `medallionButton`** de WorkoutPill (extrait /
  paramétré — ma zone), le MÊME objet que dans la dalle, juste transporté et
  scalé. Jamais un mime.
- « Page exercices » : **SANS bordure** — verre fumé du pattern molette
  (`.regular.tint(noir)` interactive) nu, ou capsule noire éclairée par la
  scène. Le premium est la matière, pas le contour.

**C. LA MÉTHODE — figer avant de builder.** Plus de micro-itérations de
design à l'aveugle : chaque élément du player pointe un objet DÉJÀ validé de
l'app (ardoise → corps ; dalle home → sommet ; medallion → stop ; molette →
verre). Un élément sans référent maison = une question à Kathryn AVANT le
build, pas une invention.

**D. LE NOIR ABSOLU — zéro gris, nulle part** (verdict v5.1 : « pourquoi tu
mets du gris ??? ça jure de fou »). Ma card démo était GRISE (0,13) — une
lecture LITTÉRALE de la maquette Figma, où le gris ne servait qu'à montrer
l'objet sur le canvas. Dans Woop, les pages sont NOIRES (la robe : noir +
blancs en dégradé, premium minimal — réf. goûts design). La card-page est
NOIRE avec son vrai contenu ; l'objet se lit par ses COINS et la LUMIÈRE
(spotlight, élévation), jamais par une teinte. AUCUN aplat gris : ni card, ni
player, ni plaque, ni bouton. Les seuls « gris » de l'écran sont les ENCRES
(textes en blanc dégradé).

**E. TUER L'EFFET CALQUE** (verdict v5.1 : « effet calque trop moche »). Le
snapshot flouté d'une card au bas vide = une image plate qui flotte. Remèdes,
dans l'ordre : (1) une card démo au contenu RÉALISTE jusqu'en bas, dans sa
robe noire ; (2) le flou n'arrive qu'EN FIN de course (~0 jusqu'à 50 %, puis
monte) — pendant le push, la card reste un OBJET net reconnaissable qui SORT,
le flou n'est que sa dissolution finale ; (3) si le snapshot se lit encore
« calque » : pousser la VUE VIVANTE (offset seul — un offset ne coûte rien)
et ne basculer sur le snapshot flouté qu'au-delà de ~60 % de course. Se juge
au banc, sur le téléphone.

**F. UNE SEULE MATIÈRE — le déployé est UN objet, pas un mille-feuille**
(verdict v5.1 : « toutes les couches horribles », 0/10). Inventaire des
couches empilées à pleine levée, mesuré au screenshot : ① le bas de la
card-page qui DÉPASSE encore derrière le sommet du player ; ② le trait ; ③ la
dalle qui porte SON propre fond ; ④ la plaque claire du groupe courant de la
partition ; ⑤ le corps 0,045 sur le fond noir. Cinq nuances de sombre = un
mille-feuille cheap. LA RÈGLE : à pleine levée, l'écran est UNE surface —
- la card-page est TOTALEMENT sortie/éteinte : RIEN ne dépasse derrière le
  sommet du player (l'offset finit hors écran, l'opacité finit à 0) ;
- le player est UNE seule nappe noire continue : la dalle n'a AUCUN fond
  propre qui tranche (son fond = celui du corps), la partition n'a AUCUNE
  plaque (le groupe courant se distingue par l'ENCRE — luminance du texte —
  jamais par un fond) ;
- ce qui structure l'écran : le trait, la lumière (spotlight), les encres.
  RIEN d'autre. Trois valeurs de noir maximum dans tout l'écran.

**G. LA FLUIDITÉ SE MESURE, ET LE HITCH DE LA PRISE SE TRAQUE** (verdict
v5.1 : « pas fluide »). Suspect n° 1 : la capture ImageRenderer (scale 3,
plein écran) faite au PREMIER `onChanged` — un hitch au moment exact où le
doigt attend la réponse. Remèdes à mesurer : capturer À LA POSE du doigt sur
la dalle (avant le seuil des 12 pt), ou pousser la vue vivante (E.3, aucune
capture pendant le geste). Et LA MESURE avant tout verdict : SondeCadence
par régime + film du geste, machine calme, sur le TÉLÉPHONE (§9).

### 2.7 LE HÉROS-JOUR (idée Kathryn 30-08, challengée — v7)

**L'idée** : à gauche de la dalle, remplacer la lune par une **MINI-CARD JOUR**
(la mini-card grise calendar du widget This Week — `MiniCardJour`, RÉUTILISÉE
sans la modifier : elle appartient à la zone Progress). Au drag, **cette même
mini-card voyage et se pose AU CENTRE, comme un CD** (la référence : le
now-playing d'Apple Music — l'artwork est le héros). Sous elle : **l'exercice
EN COURS + la progression** de la séance.

**Le challenge (ce que je corrige de l'idée)** :
1. **UN SEUL objet en vol.** Card-jour qui voyage + stop qui voyage = deux
   trajectoires croisées, le regard ne sait plus quoi suivre. LE HÉROS EST LA
   CARD-JOUR (gauche → centre, elle grossit ×~3,5, esprit CD). Le stop ne
   VOLE plus : il NAÎT en fondu à sa place du bas, avec « Page exercices ».
   La hiérarchie de la référence Apple : l'artwork vole, les contrôles
   émergent en place.
2. **La partition reste** (la référence n'a pas de liste, notre player en a
   besoin — « voir la séance » est le rôle). Elle vit SOUS le bloc héros.
3. **Le stop DESCEND** (verdict capture v6 : « trop haut ») : ~140 pt du bas
   (au lieu de 176), « Page exercices » ~80.

**La composition v7 (validée sur schéma avant tout code)** :

⚠️ TRANCHÉ 30-08 : challenge VALIDÉ (un seul objet en vol, le stop naît en
fondu) + AU REPOS LA DALLE DIT L'EXERCICE EN COURS, pas la date — la date vit
déjà dans la mini-card jour à gauche, zéro redondance.

```
REPOS (la dalle)                 DÉPLOYÉ (le player)
┌────────────────────────┐            ── (trait)
│ ┌──┐ Woodchopper pou…  │          ╭─────────╮
│ │30│ In session · 27 ⏹ │          │   30    │  ← LA MINI-CARD JOUR
│ └──┘ ▁▁▁ progression ▁ │          │  AOÛT   │    posée au centre (le CD)
└────────────────────────┘          ╰─────────╯
  ↑ la mini-card jour à          Woodchopper poulie…   ← l'exercice EN COURS
    gauche (remplace la lune)    ▁▁▁▁●▁▁▁▁▁▁▁▁▁       ← la progression
                                 ─────────────────
PENDANT LE DRAG :                01 Woodchopper 🔥🔥
la mini-card QUITTE la           Set 1  12·20·47 +20   ← la partition
gauche, monte au centre          Set 2  …               (scroll)
en grossissant ; la dalle
se dissout ; titre +                   ( ⏹ )           ← le stop, en FONDU
progression naissent                                     (il ne vole plus),
sous elle ; stop + bouton         ⟮ Page exercices ⟯     PLUS BAS
émergent en bas.
```

### 2.8 LA PARTITION DIT LE VRAI (question Kathryn 30-08 : « et si c'est le
troisième exercice ? »)

Aujourd'hui `buildGroupes` REMONTE l'exercice courant en tête : affiché
« 01 » même s'il est le 3ᵉ de la séance — la numérotation MENT. La règle de
l'ardoise est pourtant déjà écrite : « un replay ne devine pas — il retrace ».

**Le comportement v8 :**
1. **L'ORDRE RÉEL de la séance est préservé** : si l'exercice en cours est le
   3ᵉ, il s'affiche « 03 », À SA PLACE, entre le 02 et le 04.
2. **Seul l'exercice EN COURS naît DÉPLIÉ** (`deplies = [sonId]`) — les
   autres fermés, comme aujourd'hui.
3. **La liste s'OUVRE SUR LUI** : à l'ouverture du player, un scroll initial
   (sans animation, avant la première image) amène le groupe courant en vue —
   on ne cherche pas son exercice, il est déjà là.
4. **LE SET EN COURS se distingue** : dans le groupe déplié, la première
   ligne non faite est LE set en cours — étiquette « Now » (à l'encre d'or de
   la maison) au lieu d'« Upcoming », chiffres à pleine encre. Les suivants
   restent « Upcoming » gris. Porté par les DONNÉES (`SlateLigne.enCours`),
   rendu dans `SetHistoryRow`.
5. Le TITRE de la scène (sous le héros) et de la dalle disent toujours
   l'exercice EN COURS — quel que soit son rang.

⚠️ Fichier : `SessionSlate.swift` (ma zone player) porte 28 lignes de WIP
non commité d'une autre session — édition par hunks en les évitant.

### 2.9 LE BADGE « SETS » ET LE REMPLAÇANT DE LA BARRE (Kathryn 30-08)

**1. Le badge sur la mini-card jour** : un STICKER NOIR À NÉON BLANC
« 13 sets » (le total de la séance), collé sur la card du héros, « joli qui
bouge ». Contraintes maison :
- Le « bouge » est une LUEUR COMPOSITÉE (opacité/glow en
  `repeatForever` — le compositeur anime, zéro réévaluation), JAMAIS une
  horloge par image : la leçon DiamondPrimaryButton (60 → 16 img/s pour un
  colorEffect 30 Hz permanent) vient d'être payée par la session Progress.
- LISIBILITÉ : à l'échelle dalle (0,58) un texte « 13 sets » est illisible →
  le badge ne s'allume qu'en VOL et POSÉ (opacité liée à `levee`) ; au repos
  la card reste date + sticker.

**2. Le remplaçant de la barre au DÉPLOYÉ** (verdict : « ça marche pas autant
en mode réduit qu'ouvert ») : la veine d'or est un CHEVEU de bord — parfaite
en dalle, PERDUE en pleine scène (une petite barre flottante au milieu).
- **Reco (a)** : LES FLAMMES DE L'EXERCICE EN COURS (`FlammesRow`, le langage
  des séries déjà maison) — 2 vives / 3 éteintes, et LA FLAMME DU SET EN
  COURS PALPITE (le seul élément vivant, cohérent avec le badge). La barre
  disparaît du déployé ; la veine RESTE en dalle (validée là).
- (b) L'ÉTAPE EN MOTS : « Set 3 sur 5 » (la grammaire de la route) sous le
  titre — sobre, dit exactement où on en est.
- (c) L'ANNEAU SUR LE HÉROS : le périmètre de la mini-card se remplit
  (trim d'un RoundedRectangle) — très Apple, lie la progression au CD, mais
  matière NEUVE (pas de référent maison direct).

### 2.10 LES QUATRE VERDICTS DU FILM v8.1 (Kathryn 30-08 — « j'insiste à
100 %, tant que c'est pas ça fouette »)

**1. DEUX CARDS, LE TRAIT AU MILIEU — l'aspect poussé, le point capital**
(réf. : sa capture Bureau `Capture d'écran 2026-08-30 à 18.25.05`, copiée
dans le scratchpad). Pendant TOUT le push on doit LIRE deux cards distinctes :
la card-page au-dessus (ses coins bas visibles), **LE TRAIT À LA JONCTION**
(il vit au point de contact et VOYAGE avec lui — pas au sommet du player
seul), le player-card en dessous. **LE FONDU N'ARRIVE QU'APRÈS** : le
flou/dissolution ne démarre qu'à ~0,7 de course (encore plus tard qu'avant) —
tant que les deux cards se poussent, elles restent NETTES et entières. La
sensation : deux objets physiques bord à bord, pas un morphing.
→ Fixes : le bas de la card-page garde ses coins pendant le push ; le trait
se dessine ENTRE les deux (à la jonction mobile) ; courbes : flou 0 jusqu'à
0,7 puis 24 ; opacité 1 jusqu'à 0,78 puis → 0.
→ « FOUETTE » : méthode fouettage-avant-montrer obligatoire — film,
relecture adverse frame par frame aux instants CONNUS (états figés), sondes.

**2. LE VOL DU HÉROS S'EST PERDU** (« on a perdu l'animation de la mini-card
qui glisse du mini-lecteur à la card »). Suspects : la capture ImageRenderer
au départ de l'auto-cycle (30-80 ms de main thread) qui MANGE le début du
spring ; et la montée trop rapide (response 0,55 → le vol dure ~0,6 s).
→ Fixes : yield/frame APRÈS la capture avant d'animer ; montée de démo plus
lente (response ~0,85) pour que le vol se LISE ; vérifier le handoff
vignette→héros au pixel (même point, même échelle, même instant).

**3. LE BADGE : PLUS PETIT, SUR LE FLANC** (« trop gros, il doit être sur le
côté de la card, on voit rien »). Police ~10-11, paddings réduits, et posé À
CHEVAL SUR LE BORD (le flanc droit, mi-hauteur — comme la ×2 : ~55 % dedans),
pas au coin bas.

**4. LA BARRE RESTE — LA COMÈTE EST SON ANIMATION** (corrigé 30-08 : « la
comète ne remplace pas la barre !! la barre s'anime en continu c'est tout »).
La barre blanche demeure (dalle + scène, même objet) ; **la petite comète
blanche se balade EN CONTINU à l'intérieur** (tête vive, traîne fondue) —
c'est l'animation permanente qui dit « en cours ». Aucune fraction affichée
nulle part (« Set 3 of 5 » reste mort). Compositée (`repeatForever`), jamais
une horloge. La v8.1 en est déjà très proche (barre + dégradé coulissant) —
resserrer le coulissant en « comète » (tête + traîne) et le faire se balader.

### 2.11 LES TROIS VERDICTS v9.1 (30-08, analyse avant code)

**1. LA COMÈTE TOUJOURS INVISIBLE — le diagnostic.** Deux tentatives
`withAnimation(.repeatForever)` (onAppear nu, puis différé d'un frame) ont
échoué : la barre vit dans la dalle, dont le parent est RE-ÉVALUÉ à chaque
changement de `levee` — un `repeatForever` posé par transaction y est
fragile par nature (l'animation d'état se fait avaler/réattacher). LE FIX
FIABLE, et c'est un pattern DÉJÀ VALIDÉ dans la maison : un
`TimelineView(.animation(minimumInterval: 1/30))` LOCAL à la barre — le
liseré vivant de la molette fait exactement ça. Pas d'état, pas de
transaction : x = f(horloge), ça ne peut pas ne pas marcher. Coût : la barre
seule (220×5 pt) se redessine à 30 Hz — négligeable et précédent (molette).
⚠️ Ce n'est PAS une « horloge de page » interdite : le TimelineView
n'invalide que sa sous-vue minuscule.

**2. LE BADGE DEVIENT UN TICKET DE CINÉMA** (« noir à l'ancienne, mais garde
le fond blur noir »). La capsule devient une forme TICKET : rectangle aux
coins doux avec DEUX ENCOCHES semi-circulaires au milieu des flancs (les
crans du ticket), et une fine ligne POINTILLÉE verticale près du bord (la
déchirure). On GARDE : le fond noir dégradé + liseré fondu (la matière ×2),
le texte néon blanc respirant, la pose penchée à cheval sur le flanc.

```
   ╭──────╮╭──────────╮
   │  ╳╳  ◟◞  5 SETS  │   ← encoches latérales + pointillés
   ╰──────╯╰──────────╯      (TicketShape custom, même matière)
```

**3. LA DALLE TROP TASSÉE** (« tout est trop collé à la ligne de progression
et au footer »). Mesure : dalle 76 pt — contenu HStack ~46 + barre à 7 du
bas → ~10 pt entre le titre et la barre : serré. FIX : la hauteur de la
dalle passe PARAMÉTRABLE (`hauteurDock`, défaut 76 — la home intacte) et le
player la monte à 86-88 pt : le contenu se centre, l'air apparaît entre
vignette/titre et barre, et sous la barre. `PageCard(dockH:)` suit.

### 2.12 LES VERDICTS T1 SUR TÉLÉPHONE (30-08 — « ça marche, par contre… »)

**1. LE HAUT DE LA FICHE CASSÉ AU RE-CLIC (chevron coupé, retour mort) — le
bug de fond.** PageCard fait `.ignoresSafeArea()` sur son GeometryReader
racine : la fiche (`pageContenu`) vit dedans et PERD ses insets — ses
GeometryReader internes (:704, :972…) lisent des insets NULS, le header
remonte sous la status bar, le chevron est coupé et intapable (« je ne peux
plus revenir en arrière »). Le banc ne le voyait pas : la page démo n'utilise
pas les insets. LE FIX : le moteur ne vole PLUS la safe area de la page — le
GeometryReader racine reste DANS la zone sûre (la page retrouve ses insets),
et SEUL le corps du player plonge au bord physique
(`.ignoresSafeArea(edges: .bottom)` sur lui seul) ; les hauteurs (bandeH,
corpsH, course) se recalculent en conséquence.

**2. LE RANGEMENT PAS FLUIDE (« j'arrive pas à drag le player déplié »). Au
déployé, la seule prise est la dalle ÉTEINTE (invisible : opacité 0, mais
c'est elle qui a le geste) + un flick exigeant (v>900). On ne trouve pas la
prise. LE FIX (le pattern Apple Music : on tire depuis l'artwork) : le
moteur pose une ZONE DE PRISE sur tout le HEADER déployé (le CD + titre +
barre, ~300 pt hors partition — rien n'y scrolle) : `Color.clear +
contentShape + le même geste de tirage`, montée seulement `levee > 0.5`,
SOUS le pied (les boutons gardent la priorité). Et le flick de la partition
descend à v>650.

**3. LA POP-UP STOP : « élève le stop à l'intérieur dans le slider »** — à
vérifier dans StopCard.swift (zone de la session stop, absente — je prends
sur ordre de Kathryn) : soit le glyphe ■ est décentré dans le curseur du
slider (le remonter/centrer), soit le slider est trop bas dans la card (le
remonter). Tranché À LA LECTURE du code, ajustement minimal.

**4. LA VIGNETTE ENCORE TROP COLLÉE au texte dans la dalle** : trailing 6 →
11.

### 2.13 T1.1 REJETÉE (30-08, 4 captures) — LE DÉFAUT DE FOND ET LE PLAN T1.2

**Le défaut de fond, dit par Kathryn : « la page détail n'est PAS une card —
on n'a pas la sensation de pousser le contenu. »** Ma T1 encadrait la fiche
dans un cadre RACCOURCI (zoneH = écran − bande) : la fiche, pleine
d'hypothèses plein-écran (ses GeometryReader, son galet en safeAreaInset, sa
carte des séries), s'est CASSÉE — le galet au-dessus des séries (capture
19.58.52), la bande noire au scroll et au lancement du palet (20.00.50), le
bandeau noir au déployé (19.58.25) — et la page plein-bord sans coins ne se
lit jamais comme une card qu'on pousse.

**T1.2 — les deux corrections structurelles :**

**A. LA PAGE GARDE SON PLEIN CADRE ; LA BANDE EST UN INSET, PAS UNE COUPE.**
Le slot page reprend TOUTE la zone sûre (sa géométrie native revient : galet,
séries, scroll réparés d'un coup), et la bande du player est donnée à la page
par `safeAreaInset(edge: .bottom, bandeH)` — son contenu remonte au-dessus de
la dalle SANS que son cadre change. Plus de zone morte : plus de bande noire.

**B. LA CARD NAÎT SOUS LE DOIGT — le pattern app-switcher d'iOS.** Au repos,
la page est une page (plein bord, normale). À LA PRISE, elle est remplacée
par son SNAPSHOT dès le premier point (plus de vue vivante poussée — c'était
aussi le « pas fluide » : la fiche réelle porte vidéos et shaders, son
offset par image coûtait plein pot ; une image morte ne coûte rien), et ce
snapshot SE DÉTACHE : les coins (≈28) naissent, une légère échelle (1 →
0,96) l'écarte des bords — LA CARD apparaît, puis elle est POUSSÉE en
contact 1:1. La sensation « pousser un objet » vient de là. Au retour, elle
se repose et se re-fond dans la page vivante (mêmes pixels : swap invisible).

**C. Les finitions T1.1 restantes :** l'air entre le contenu de la dalle et
la barre (elle colle — équilibrer les paddings internes du dock) ; le hitch
de capture à MESURER sur le tel (G) une fois A/B posés.

### 2.13 bis — LE BLUR DE DISPARITION REVIENT (verdict 30-08, capture
20.14.47 : « il manque l'animation de blur de disparition de la card comme
on avait, c'est pas beau »)

En T1.2 j'avais repoussé le flou à 70 % de course (le « deux cards nettes »)
— trop tard : la card disparaît sèchement, la dissolution premium des
v6-v9 (validée « trop belle » au film) a disparu. L'ÉQUILIBRE :
- 0 → ~0,40 : DEUX CARDS NETTES (le push se lit, §2.13-A tenu) ;
- ~0,40 → 1 : LE BLUR MONTE progressivement (0 → 24) — la dissolution
  visible pendant la seconde moitié du vol ;
- l'extinction (opacité) démarre à ~0,55 et finit à ~0,9.
Courbes : `flouCard = 24·lisse((levee−0,40)/0,5)`,
`opaciteCard = 1 − lisse((levee−0,55)/0,35)`.

### 2.14 LE LAYOUT UNIVERSEL (vision Kathryn 30-08 — « le même layout
partout, c'est homogène »)

**TOUTE page est une CARD (home, liste, détail), le GALET play flotte
DEVANT elle, et le drag révèle TOUJOURS quelque chose dessous :**
- **EN SÉANCE** → le PLAYER (la dalle, puis le déployé — tout ce plan) ;
- **HORS SÉANCE** → **LA LUNE** (le « secret » que la home a déjà :
  `LuneSecrete`, découverte au tirage — home/exos/coffre la portent déjà).

```
            EN SÉANCE                      HORS SÉANCE
     ╭──────────────────╮            ╭──────────────────╮
     │    la page-card  │            │    la page-card  │
     │        (◉) galet │← devant    │        (◉) galet │
     ╰──────────────────╯            ╰──────────────────╯
        ── trait                        (drag ↑)
      ▂▂ dalle player ▂▂                 🌙 la lune
```

La grammaire de la HOME devient LA grammaire de toutes les pages — PageCard
est le conteneur universel : un slot « dessous » qui montre le player en
séance et la lune hors séance. Le drag existe TOUJOURS ; seul ce qu'il
révèle change. La fiche hors séance cesse d'être « nue » (l'état T1) : elle
est la même card, lune dessous. Le galet play vit DEVANT la card (pas dans
son flux) et s'estompe pendant la levée comme la dalle.

⚠️ Réutiliser la `LuneSecrete` EXISTANTE (home) — jamais une copie ; son
montage actuel dans HomeNuit est la référence, à extraire ou paramétrer avec
la même discipline que MedaillonStop/VeineOr.

### 2.15 LA GROSSE CARD PERMANENTE (verdict 30-08 : « t'as pas transformé la
page détail en grosse card comme ma capture — t'as rien compris »)

Ma T1.2 faisait naître la card SOUS LE DOIGT seulement (app-switcher) —
FAUX : **la page EST une grosse card DÈS LE REPOS**, comme la capture
20.14.47 et la maquette d'origine. Le layout permanent :

```
   ┌─────────────────────┐ ← fond noir de l'app
   │  ╭───────────────╮  │
   │  │   LA FICHE    │  │ ← LA CARD : coins ~30, marges fines
   │  │  (chevron,    │  │   (~12 latéral, ~6 sous la status bar),
   │  │   image,      │  │   la fiche VIT dedans en permanence
   │  │   séries…)    │  │
   │  │      (◉)      │  │ ← le galet play DEVANT la card
   │  ╰───────────────╯  │
   │   ── trait           │ ← la bande : dalle player (séance)
   │  ▂▂ dalle player ▂▂  │   ou trait+lune (hors séance)
   └─────────────────────┘
```

**Le geste technique (qui ne repaye pas la T1.2)** : le cadre de la page ne
bouge quasiment pas — `padding` latéral 12 + top 6 (un iPhone « un peu plus
étroit », la fiche s'adapte) + l'inset bas DÉJÀ posé (bandeH) +
`clipShape(RoundedRectangle(30))` — un clip ROGNE LE DESSIN sans toucher au
layout (pas le piège du cadre raccourci). Le fond noir de l'app respire
autour. Au drag, la card — déjà card — est poussée telle quelle (l'« habit
qui naît » disparaît : plus simple, plus juste).

À l'identique ensuite sur home (T2) et exos (T3) — LE layout unique.

### 2.16 LES DEUX BUGS DU TEL §2.15 (verdicts 31-08 au matin, captures
07:52 « tout est collé au milieu » et 07:53 « toujours le bandeau noir »)

**BUG B — le bandeau noir + le chevron au déplié (CAUSE PROUVÉE,
`ExerciseDetailView.swift:959-961`)** : `.navigationBarBackButtonHidden` /
`.toolbar(.hidden, for: .navigationBar)` / `.toolbar(.hidden, for:
.tabBar)` vivent DANS `pageContenu` — le slot que PageCard **démonte** dès
la prise (remplacé par le snapshot). Démontés, ces préférences meurent → la
nav bar système Liquid Glass REVIENT (le bandeau noir, son chevron-galet),
et le cadre de PageCard se décale pendant le geste. Au ranger, la page
remonte et la barre se cache — « quand je monte » exactement.
→ **FIX** : ces trois modifiers remontent sur le `body` (sur `PageCard`),
qui n'est jamais démonté. Deux lignes déplacées, risque nul.

**BUG A — « tout est collé au milieu » (repos, en séance)** : la fiche a
été taillée pour 759 pt et la card §2.15 lui en donne ~643 (−6 en haut,
−110 de bande). Or trois morceaux sont FIXES :
- `expandedHeader = 12+225+8+118 = 363` (l'image + le titre) ;
- la carte des séries posée à `y = expandedHeader + 4` (fixe, hors scroll) ;
- le galet « Start exercise » en `safeAreaInset(edge: .bottom)` ~240 pt —
  un INSET : il RÉSERVE sa hauteur, le contenu recule d'autant.
363 + carte (~200) + 240 > 643 → la carte et le galet se chevauchent.

→ **FIX PRINCIPAL — le galet passe DEVANT la card (et réalise le §2.14
« le palet devant », déjà demandé)** : le galet quitte le
`safeAreaInset(bottom)` et devient un `overlay(alignment: .bottom)` — il
FLOTTE devant le contenu au lieu de réserver 240 pt. Le scroll reçoit en
échange un dégagement bas (contentMargins/padding) pour que sa fin ne
meure pas sous le galet. La carte des séries récupère l'espace : plus de
chevauchement. Ses gestes (drive/drag) restent gagnants : un overlay est
AU-DESSUS au hit-test.
→ **SI la mesure dit que ça ne suffit pas** (la carte encore trop près de
la bande) : compacter le header dans les cadres courts — `expandedHeader`
devient fonction de la hauteur du cadre (l'image 225 réduite au prorata).
On ne touche à cette zone à pièges (header rétrécissant, morphing,
`pageFull`) QUE si la sonde l'exige.

**LE FOUETTAGE §2.16** (avant tout tel) :
1. le banc de la VRAIE fiche au déplié : `-pageCardLevee` est déjà lu par
   le Lab — la fiche le passe aussi (`leveeInitiale`), pour CAPTURER le
   déplié réel sans doigt ;
2. sondes : plus de bandeau (le corps du player à 8 pt sous le haut sûr,
   AUCUN chevron au déplié) ; carte des séries et galet DISJOINTS (bande
   de séparation mesurée) ; chevron/retour intacts au repos ; les deux
   états (séance / hors séance) ; non-régression du banc.

### 2.17 LE PÉRIMÈTRE DU PLAYER (verdict 31-08 : « le player n'arrive
jamais dès que le galet est enclenché et pendant le chrono ! que sur home,
exercices, calendrier (progress) et détail exercice — pas le reste »)

1. **Les pages à player (et LEUR SEULES)** : home · page exercices ·
   progress/calendrier · détail exercice. Le coffre, le profil, et tout le
   reste : JAMAIS de dalle.
2. **Le player disparaît pendant l'exercice actif** : dès le drive du galet
   (`flood ≥ 0.01`) et pendant toute la série (`running != nil`, la
   lentille et son chrono), la bande ENTIÈRE se cache (ni dalle, ni trait,
   ni lune) — la card prend presque toute la hauteur (padding bas 12).
   Fait : `bandeVisible` sur PageCard, dérivé par l'hôte. Le retrait du
   corps est sec (couvert par la plongée/lentille) ; la hauteur de card
   est animée (0,25 s), un événement, jamais par image.
3. **Le galet est un OVERLAY** (fix A §2.16) : plus de réservation de
   160 pt ; la carte des séries OUVERTE compense (−LaunchPebble.height)
   pour garder son bas. ⚠️ `pageFull` (l'ancre de la plongée) perd les
   160 pt d'inset dans son calcul — le zoom du launch est À VÉRIFIER au
   doigt ; s'il vise trop haut : re-caler la cible (§ dette).
4. **Dette ouverte — le compactage du header** : `expandedHeader` (363,
   image 225) reste taillé écran-entier ; dans la card, la carte des
   séries frôle le dôme (2 pt d'air au sim, chevauchement au tel avec de
   vraies données). Le rendre adaptatif touche `PanneauMesures.
   ancreCarteExo` (couplage static) et le morphing du header — micro-passe
   dédiée, au banc `-headerFreeze`, pas en douce ici.
5. **La robe NUIT de la plongée** (le « tout devient blanc ») : analysée,
   EN ATTENTE du verdict de Kathryn — voile assombri, flash bref à
   trancher, lentille intouchée.

### 2.18 LE HAUT DE LA CARD FOND DANS L'HEURE (verdict 31-08 : « la page
détail ne doit PAS être coupée en haut — elle fond dans le header de
l'iPhone, comme home et exercices. Tu m'as mis une limite : hors de
question »)

**L'erreur d'origine, avouée** : le §2.15 posait la card avec un top à
6 pt, des coins HAUTS et un liseré en travers — une LIMITE sous l'heure.
Or la sonde de la réf 20.14.47 le montrait déjà : ses « marges » étaient
le CADRE du screenshot (34 partout, y compris en haut), et la bande de
l'heure porte du contenu — **la page fondait dans l'heure, plein bord**.
Comme home et exercices.

**LA RÈGLE (la grosse card, version vraie)** :
- **LE HAUT FOND** : padding top 0, coins hauts 0, PAS de liseré en
  travers (le liseré des flancs meurt en fondu vers le haut, mask
  gradient). Le noir de la fiche continue dans le noir de l'app jusque
  sous l'heure — aucune couture. Le chevron/headerChips ne bougent pas.
- **LES CÔTÉS** : 8 pt (validés « réajuste » 31-08) — invisibles en haut
  (noir sur noir), structurants en bas.
- **LE BAS** : inchangé — coins 30, la bande du player DÉTACHÉE dessous.
- **LE BANC** : la demoPage passe en robe NOIRE plein cadre (le gris 0.05
  fabriquait un « bord » que la vraie fiche n'a pas).

**LE BUG DE LA LUNE ALLUMÉE AU REPOS** (capture 31-08 08:31, banc) : le
piège de la maison « un DragGesture peut mourir sans onEnded » —
`tirageLune` n'a PAS de chien de garde : le geste annulé (pointeur sorti
de la fenêtre sim, présentation) laisse `levee` à ~0,16 → la lune reste
ALLUMÉE et la card levée. Remède connu (le même que partout) : remise à
plat sur `startLocation` en tête d'`onChanged` + chien de garde ~0,3 s
réarmé qui appelle `ranger()`. Le grand `tirage` du player veut le même
chien de garde.

**DÉJÀ POSÉ localement, EN ATTENTE du go** (avoué : édité avant le
« ne code pas ») : le compactage du header — `heroCap` 225 → 175 et
`expandedHeader` réécrit en FORMULE (`12 + heroCap + 8 + 118` = 313) pour
que carte, relais du tap et `PanneauMesures` suivent d'un seul geste.
Répond au « tout est collé au milieu ». Rien n'est buildé.

### 2.19 L'EXERCICE ACTIF EST FULL SCREEN — JAMAIS EN CARD (verdicts 31-08
midi, 4 captures : « dès qu'on lance le galet tout l'écran est blanc — des
bordures noires SURTOUT PAS ; pareil la vue chrono : full screen, pas de
marge, pas d'élément de card » + « toujours la barre noire une fois le
player ouvert »)

**BUG 1 — la plongée et la lentille naissent DANS la card (cause lue,
`ExerciseDetailView` ~983-1090)** : le voile `paper`, le flash et
`LiquidLensLab` (la lentille, son chrono) sont des overlays DE
`pageContenu` — le slot que PageCard habille en card : clippés par la robe
(marges 8, coins bas, bandes). Leurs `ignoresSafeArea` sont neutralisés
dans le cadre paddé.
→ **FIX : le bloc DÉMÉNAGE au body** — overlay DE PageCard (mêmes états,
même struct), où `ignoresSafeArea` redevient opérant : bord à bord
PHYSIQUE, zéro bordure. Le `scaleEffect(dive)` (le zoom de la page) RESTE
dans la page, sous le voile. Le player est déjà effacé (§2.17
`bandeVisible`) ; par-dessus tout, la question ne se pose plus.

**BUG 2 — la « barre noire » du player ouvert (cause lue, le spotlight)** :
la lumière du sommet (RadialGradient, overlay du root PageCard) vit en
zone SÛRE : elle s'arrête à la safe top — la status bar reste noire pure
au-dessus d'une zone éclairée : c'est ELLE, la barre. Le corps, lui, est
noir sur noir (aucun bord dessiné).
→ **FIX : le spotlight ignore la safe top** (une ligne) — la lumière monte
jusqu'au châssis, la démarcation meurt.

**Fouettage** : `-aubeFreeze 0.6` → le blanc couvre l'ÉCRAN PHYSIQUE
entier (sondes : AUCUN pixel noir de marge, ni bandes haut/bas) ; le
déplié réel → aucune rupture de luminance à la safe top ; non-régression
des quatre états §2.18.

(Constat au passage, T2/T3 : « on a la vue grosse card QUE dans la page
détail » — home, exercices et progress attendent leur tour, périmètre
§2.17.)

---

## §3 LE PLAYER GLOBAL AU-DESSUS DES PAGES (le revirement du 31-08 —
plan v2, écrit sur l'INVENTAIRE du code, pas sur des suppositions)

Verdicts : « je préfère finalement l'OVERLAY (sheet au-dessus des
écrans) — garde tout le reste (les grosses cards) » · « full page ça me
va aussi, tant que ça passe par-dessus les pages-cards » · « DIMINUER
LES BUGS » · « la card détail n'a pas les mêmes dimensions que home et
exercices ».

### 3.0 LES FAITS ÉTABLIS (inventoriés fichier:ligne, 31-08)

1. **Le point de montage racine existe** : le ZStack de `mainBody`
   (`WoopApp.swift:1030`), en FRÈRE du TabView (`:1058`), échelle de
   zIndex documentée (Départ 5 · Booster 6 · RewardPopup 8 · Annonces 9
   · RewardChemin 12 · StopCard 13 · story 15).
2. **Le précédent maison** : LE CHEMIN a déjà QUITTÉ son
   fullScreenCover pour la racine (`WoopApp.swift:1188-1205`) — même
   raison, même geste. On copie.
3. **Trois dalles WorkoutPill EXISTENT déjà** : home
   (`HomeNuit.swift:2656`, dock 76), exercices
   (`ExercisesView.swift:1213`, dock 76), fiche
   (`ExerciseDetailView` dallePlayer, dock 86). Progress n'en a PAS
   mais **réserve déjà 96 pt avec le contrat écrit**
   (`ProgressPage.swift:15-17, 99-111` : « la page DÉGAGE la zone, le
   player est ailleurs »).
4. **La barre bijou est MORTE** (`WoopApp.swift:721-726` :
   `barreBijouVisible` toujours false) — aucun conflit de tab bar.
5. **ActiveWorkoutSheet** (le player modal historique) vit encore :
   `.sheet($sheetWorkout)` attaché au TabView (`:1162`), fond verre
   transparent (`ActiveWorkoutView.swift:243`) — c'est LUI l'orphelin
   mangeur de touchers du defer e9521cf (`WoopApp.swift:764-787`).
6. **Les présentations UIKit passent AU-DESSUS de la racine** : le
   sheet `:1162`, les covers coffre (`HomeNuit:2372`), Chemin
   (`:2339`), l'ExercisesView IMBRIQUÉE dans le cover du Chemin
   (`HomeNuit:2360`), MoisIpod (`ProgressPage:155`).
7. Exercices et progress ont DÉJÀ leur système de card
   (`GrandeCardExos`/`FormeCardExos`, clipShape + `.ignoresSafeArea()`
   sur le ZStack) — DIFFÉRENT de la robe §2.18 de la fiche : c'est LA
   cause des dimensions divergentes qu'elle voit.

### 3.1 LA DÉCISION D'ARCHITECTURE : UN SEUL PLAYER, À LA RACINE

**`PlayerMonde` — une instance UNIQUE, montée dans le ZStack de
`mainBody`, zIndex 8,5** (au-dessus des pop-ups de jeu 5-8, SOUS les
annonces 9, le reward-chemin 12 et la StopCard 13 — le stop doit
pouvoir se poser SUR le player ouvert).

Pourquoi l'unique et pas un par page (la moitié des bugs se décide
ici) :
- UN état, UN montage, UNE animation — jamais N players à
  synchroniser, jamais un player par page qui survit à une navigation ;
- il couvre TOUT (pages, robes, galet, molette) sans rien mesurer —
  prouvé par l'inventaire (« un frère du TabView passe au-dessus ») ;
- la séance est déjà un état GLOBAL (`active` vit à RootView,
  `DepartEtat.shared` pour le stop) — le player la suit ;
- le type-checker : `mainBody` a DÉJÀ payé le mur (337a6e3) → le
  player s'ajoute comme UNE ligne (`playerMondeHote`, struct à part
  dans PageCard.swift ou un fichier neuf `PlayerMonde.swift` — PAS
  `PlayerSeance.swift`, il appartient à une autre session).

**L'état** : `PlayerEtat` @Observable (fichier du player) —
`p: CGFloat` (0 fermé, 1 ouvert), `ouvert: Bool`, `ouvrir()` /
`fermer()` (springs uniques response 0,42/0,86), et RIEN d'autre. La
dalle de chaque page appelle `ouvrir()` ; les gestes du player
appellent `fermer()`. Le chien de garde commet sur tout geste.

**Les données** : le player global dit LA SÉANCE, pas la fiche —
titre = l'exercice COURANT (v1 : le premier non terminé de
`active.orderedExercises`), groupes SlateGroupe requêtés à
l'ouverture (le pattern de la fiche, une visite par ouverture), sets
faits = `active` entier. La dalle par page garde ses données locales
actuelles (elles sont déjà justes).

### 3.2 LA MACHINE À ÉTATS (hit-test et z-order à chaque état)

Couches de `PlayerMonde` (de bas en haut) : VOILE noir
(opacité 0,55·p, `contentShape` plein — il MANGE les touchers du
dessous dès p > 0,05 et un tap dessus ferme) → CORPS noir opaque à
TAILLE FINALE plein écran châssis-à-châssis (à la racine, plus aucun
conflit de corpsH avec une card : `ignoresSafeArea` + offset
`(1−p)·écran` — la seule chose qui bouge) → trait + ScenePlayer +
PiedPlayer (fonctions de p, RÉUTILISÉS TELS QUELS — le héros vole
encore) → spotlight (déjà réglé châssis).

| état | déclencheur | ce qui écoute le doigt |
|---|---|---|
| fermé (p=0) | — | rien du player (démonté : `if etat.actif`) |
| ouverture | TAP dalle OU drag-up franc ≥ 40 pt sur elle → `ouvrir()` (animation UNIQUE, jamais un suivi) | rien — tout est sourd le temps du spring |
| ouvert (p=1) | — | le player seul (partition, stop, boutons) ; le voile ferme au tap ; flick descendant > 650 et header-grab ferment |
| fermeture | `fermer()` | rien jusqu'à p=0, puis démontage |

**Jamais de `.sheet`/`fullScreenCover`** (l'orphelin e9521cf est la
preuve à vie). Montage `if` + `.transition` interdits aussi pendant
l'animation de p : le corps est monté tant que `p > 0` OU `ouvert`.

### 3.3 LE SORT DE CHAQUE PIÈCE ACTUELLE

| pièce (PageCard.swift) | sort |
|---|---|
| snap / capture() / swap pageLayer / displayScale | ☠️ MEURENT (plus un seul ImageRenderer dans l'app) |
| flouCard / opaciteCard / offset de page / course partagée | ☠️ MEURENT — la page ne bouge plus JAMAIS |
| corpsPlayer + tirage + header-grab + flick | 🚚 DÉMÉNAGENT dans PlayerMonde (le corps monte déjà par offset à taille finale — la mécanique est la bonne, seul son HÔTE change) |
| ScenePlayer / PiedPlayer / BarreBlancheAnimee / BadgeSetsNeon / TicketShape | 🚚 DÉMÉNAGENT (vues partagées, zéro copie) |
| robeCard §2.18 (haut fondu, marges 8, coins bas) + bande §2.17 (dalle / trait+lune / rien) + luneFond + tirageLune + chiens | 🏠 RESTENT par page — PageCard devient **PageRobe** (slots page + dalle seulement, plus de detail/pied) |
| spotlight | 🚚 suit le corps dans PlayerMonde |
| mondeFlottant §2.19 (fiche) | 🏠 reste au body de la fiche (l'exercice actif est full screen ET le player y est fermé + bande cachée §2.17 — aucun conflit de z) |

### 3.4ter LE RE-SÉQUENÇAGE DU 31-08 APRÈS-MIDI (verdicts : « ça ne
monte pas en overlay, ça se transforme en page » · « j'ai demandé à
tester sur les 3 écrans, pourquoi tu bâcles » · « même taille de cards,
même player — t'as pas vu la flèche »)

**LA RÈGLE QUI PRIME SUR L'ANCIENNE SÉQUENCE : aucun build tel avant
que LES QUATRE PAGES (home, exercices, progress, fiche) soient
branchées ET passent ENSEMBLE le fouettage ultime.** Le découpage
« la fiche d'abord, le tel entre chaque étape » est MORT — il
contournait la consigne.

- **S1' — le vol d'ouverture réparé** : `ouvrir()` monte le corps et
  anime `p` dans la MÊME transaction → SwiftUI insère la vue avec `p`
  déjà à sa cible, le vol ne joue pas (« ça se transforme en page »).
  Fix : monter (`monte = true`, `p = 0`), PUIS le spring au tick
  suivant. Et le protocole gagne un juge du VOL : sur le film, la
  frontière haute du corps doit DESCENDRE/MONTER sur ≥ 4 frames
  consécutives (jamais une apparition en 1 frame).
- **S2' — LA GÉOMÉTRIE UNIQUE, TOUT DE SUITE** (la flèche) : les
  quatre pages ont LA MÊME robe (haut fondu, marges 8, coins bas 30,
  bas de card à la MÊME hauteur) et LA MÊME dalle (dock 86, même
  position au pixel, même contenu de WorkoutPill). Exercices, home et
  progress se branchent sur PageCard ; leurs systèmes de card actuels
  (GrandeCardExos, FormeCardExos, la card de HomeNuit) deviennent le
  CONTENU du slot page ; la molette exercices et le galet home restent
  des habitants de LEUR page. Chaque page a son analyse AVANT le
  branchement (la levée de card exercices liée à la molette, la scène
  de départ home, la story in-tree de progress).
- **S3' — LE FOUETTAGE ULTIME ×4** (§3.4bis entier) : cycles filmés
  sur les quatre pages + le juge du vol + géométrie CHIFFRÉE ÉGALE
  (le tableau des quatre pages dans le rapport) + retours + pages
  immobiles.
- **S4' — le tel** : seulement quand S3' passe entier.
- Ensuite, inchangés : S5 (mort d'ActiveWorkoutSheet), S7 (parcours
  de masse), dettes (robe nuit, zoom launch).

### 3.4 L'ANCIENNE SÉQUENCE (S1-S7, ARCHIVÉE le 31-08 — S1 seul a été
joué ; le re-séquençage 3.4ter fait foi)

- **S1 — PlayerMonde à la racine + la fiche dégraissée.**
  `PlayerMonde` monté dans mainBody (une ligne, struct à part) ; la
  fiche passe sur PageRobe (sa dalle : tap/drag-up → `ouvrir()`) ;
  `-playerOuvert` fige p=1 (le banc). Puis LE FOUETTAGE ULTIME
  (§3.4bis) sur la fiche — et le tel seulement s'il passe entier.
- **S2 — page exercices.** Sa dalle (`BandeExos:1213`) : dock 76 → 86,
  padding bottom 14 gardé, tap → `ouvrir()`. La MOLETTE : AUCUN
  conflit nouveau (l'ouverture est un tap sur la dalle, la molette
  garde sa prise du pouce). ⚠️ l'instance IMBRIQUÉE dans le cover du
  Chemin (`HomeNuit:2360`) : son binding replie déjà les covers — on
  VÉRIFIE au banc que la dalle y ferme le cover avant d'ouvrir le
  player (sinon : player invisible sous le cover, le bug est PLANIFIÉ
  ici au lieu d'être découvert).
- **S3 — home.** `fondPage:2656` : dock 76 → 86, tap → `ouvrir()` ;
  `placeDy: 57` inchangé (le galet monte déjà en séance).
- **S4 — progress.** Poser la dalle dans les 96 pt réservés
  (`leveeSeance` — le contrat de la page est déjà écrit pour ça).
- **S5 — TUER ActiveWorkoutSheet.** `sheetWorkout`/`feuilleSeance`/le
  `.sheet(:1162)` meurent ; `galetPlayTape` (le galet play) démarre la
  séance PUIS `ouvrir()` ; les defer 0,35/0,4 d'e9521cf se retirent
  (l'orphelin n'existe plus). C'est le T4 promis.
- **S6 — L'UNIFORMITÉ DES ROBES** (« pas les mêmes dimensions ») :
  mesurer `GrandeCardExos`/`FormeCardExos` (exercices, progress) vs
  `robeCard` (fiche) ; UNE constante partagée (coins bas 30, marges 8,
  haut fondu) consommée par les trois — ALIGNER, pas rebrancher (moins
  de pièces qui bougent). Sondes différentielles avant/après sur les
  trois pages.
- **S7 — LE PARCOURS EN MASSE FILMÉ** : home → exercices → fiche →
  galet → série → retour, player ouvert/fermé sur CHAQUE étage,
  10 cycles par étage, cadence sondée, puis le verdict tel global.

### 3.4bis LE FOUETTAGE ULTIME — LA PORTE DE TOUT VERDICT (gravé en
mémoire, ordonné 31-08 : « sans ça tu ne viens pas me voir — on a eu
trop de beugs »)

AUCUN build tel, AUCUN « c'est prêt », sans CE protocole passé ENTIER
au simulateur. À chaque étape S il couvre les pages DÉJÀ branchées ;
S7 le passe sur les quatre.

1. **Les cycles filmés** : chaque page branchée × ouverture (tap
   dalle, drag-up franc) × CHAQUE fermeture (flick descendant,
   header-grab, tap sur le voile) — `simctl recordVideo`, ≥ 6 cycles
   par page.
2. **Rien ne casse en UI** : capture de la page AVANT le premier
   cycle vs APRÈS le dernier — différentiel pixel ≤ bruit ; sondes
   des éléments clés par page (chevron/titre fiche, molette
   exercices, galet home, calendrier progress, dalle partout).
3. **LES RETOURS FIABLES** : back de la fiche → re-entrée ×5 APRÈS
   des cycles player ; changement d'onglet pendant ET après le player
   ×5 ; et après CHAQUE cycle un TAP-SONDE sur un bouton de la page —
   il doit répondre (aucun voile ni hit-test orphelin, le fantôme
   d'e9521cf ne renaît pas sous une autre robe).
4. **MÊME TAILLE DE CARDS** : les mêmes sondes géométriques (marge
   gauche, bas de card, haut fondu, position de dalle) sur les quatre
   pages — valeurs ÉGALES, chiffrées dans le rapport.
5. **OUVERTURE SMOOTH, PAS DE PAGE QUI SAUTE** : les films relus au
   détecteur de saut (différentiel inter-frames : la page DERRIÈRE le
   player = zéro mouvement hors voile ; aucun flash) ; cadence sondée
   en régime, charge machine vérifiée avant (`./tools/charge.sh`).
6. **L'échec** : un seul point qui casse = on répare, puis on
   RE-passe le protocole ENTIER — jamais un verdict sur un protocole
   partiel.

Le rapport à Kathryn cite les chiffres (pas « ça marche ») : cycles
joués, différentiels, valeurs géométriques des 4 pages, cadence.

### 3.4quater LES RETOURS DU TEL 01-09 (verdict : « ok » sur cette liste)

1. **HOME PAR DÉFAUT = PLEIN ÉCRAN** : hors séance, AUCUNE zone noire,
   aucun trait (la robe home ne joue qu'en séance). Le slider dans la
   card : ok. **La pastille home (galet maison) disparaît à l'état
   pull/slider** — même cachée elle casse le layout.
2. **MARGES LATÉRALES 0 + LISERÉ MORT, PARTOUT** : les cards vont bord
   à bord (verdict : « padding noir à supprimer comme leur border ») ;
   la card ne se lit plus que par son BAS. Réparer le layout des
   widgets home cassé par le cadre réduit.
3. **L'INTÉRIEUR DU PLAYER** : (a) le CD (176 pt) chevauche titre/barre
   (scène à 237 pt) depuis que le corps part du châssis — cotes
   scène/pied à re-poser ENSEMBLE ; (b) partition VIDE quand la séance
   n'a pas d'exercices (séance du galet) — toujours au moins le groupe
   « courant » placeholder (le pattern de la fiche).
4. **LA FLUIDITÉ DU VOL (chantier loi n° 6)** : le hote relit `p` dans
   tout son body par frame. REFONTE : l'ouverture étant DÉCLENCHÉE, le
   contenu se construit UNE fois à l'état posé ; tous les mouvements
   (corps, héros, opacités) deviennent des modifiers ANIMATABLES animés
   par le même withAnimation — zéro body ré-évalué pendant le vol,
   CoreAnimation seul. Les vues partagées perdent `levee` (plus aucun
   autre consommateur depuis §3). Cadence sondée avant/après.
5. **HORS SÉANCE : FULL SCREEN PARTOUT, LA LUNE AU DRAG** (verdict
   01-09 : « full screen mais lune en bas si on drag, si ça bug pas
   trop ») : padding bas 0, AUCUN trait dessiné ; une PRISE INVISIBLE
   de 30 pt au bord bas porte l'élastique lune (jamais un geste
   page-large — c'est lui qui apportait les bugs). La HOME en est
   exemptée (`luneAuDrag: false`) : son tiroir possède déjà le geste
   du bas — sa lune est une perte assumée, dite.

### 3.4sexies LA CHAUFFE ET LA FLUIDITÉ (verdicts 01-09 : « la fluidité
horrible » · « le tel chauffe de fou » · « la dalle un peu plus basse
donc card un peu plus basse »)

**LA MESURE D'ABORD** : au REPOS, en séance, l'app tient 15-17 % de CPU
en continu (3 relevés sim, `ps -o %cpu`). La chauffe n'est pas une
impression — et la fluidité du suivi se noie dans ce bruit de fond (le
GPU/CPU déjà occupés quand le doigt arrive).

**LES SUSPECTS, par ordre de culpabilité :**
1. **LE RIDEAU (piège maison, payé une 2ᵉ fois)** : le cadre du player
   global était monté EN PERMANENCE dès qu'une séance existe
   (`if seance != nil`) — un voile plein écran + un corps ignoresSafeArea
   rendus en continu derrière TOUTES les pages. ✅ DÉJÀ POSÉ localement
   (avant le « ne code pas », avoué, rien de commité) : le cadre ne naît
   qu'au geste (`if etat.monte`) — le pré-montage d'un tick protège le
   vol (jugé au film).
2. **LES 4 VEINES 30 Hz** : chaque page du TabView vit en permanence
   (structurel SwiftUI) et chaque dalle porte sa BarreBlancheAnimee
   (TimelineView 30 Hz) → jusqu'à 4 horloges qui invalident en continu.
3. Les fonds vidéo des pages (préexistants — hors périmètre sauf preuve).

**LA MÉTHODE (le pattern -pullSonde : attribuer un coût, jamais le
deviner)** :
- M1 : CPU au repos APRÈS le fix-rideau — si ≤ ~5 %, le rideau était
  la chauffe ; sinon :
- M2 : A/B par soustraction — veines de dalles éteintes partout → CPU ;
  puis fonds vidéo → CPU. Chaque suspect reçoit SON chiffre.
- M3 : les fixes ciblés se tranchent AVEC Kathryn quand le visuel est
  en jeu (une veine morte au repos se voit).
- La FLUIDITÉ se re-juge à SON doigt après M1 (le suivi était noyé dans
  le bruit) ; si encore : geler les TimelineView pendant le suivi
  (`vivante: false` dès `p > 0`), sonde `-fps` en cycle à l'appui.

**LA DALLE PLUS BASSE (« aucun changement visible »)** : les −14 pt de
S6 étaient trop timides. ✅ DÉJÀ POSÉ localement : la bande descend de
18 pt DANS la zone home-bar (le bas de dalle à ~16 pt du bord physique,
l'école de l'ancienne pill home) et la card la suit — à VALIDER sur
capture avant tout tel.

**LA SÉQUENCE** : fouettage complet (CPU avant/après CHIFFRÉ ·
géométrie ×4 · cycles + juge du vol · retours) → UN build tel → verdict.

### 3.4septies L'ANALYSE DU DRAG « TRÈS MAL » (01-09, sans code — la
dalle est ACQUISE)

**LES TROIS COUPABLES, par ordre :**

1. **LA NAISSANCE DANS LE GESTE.** Au TAP, le contenu du player naît un
   tick AVANT le vol (protégé). Au DRAG : `saisir()` monte le contenu
   ENTIER (partition, mini-card, badge, médaillon) DANS LA PREMIÈRE
   FRAME DU GESTE — le hitch de naissance tombe PILE sous le doigt (le
   piège « une vue lourde qui naît pendant un film », version geste).
   C'est pour ça que le tap passe et que le drag accroche.

2. **LES ANIMATIONS CONTINUES DU CONTENU.** Le BadgeSetsNeon RESPIRE en
   `repeatForever` (ombres animées), en permanence dès qu'il existe —
   pendant le suivi, il invalide le pied à la cadence système EN PLUS
   du doigt. C'est probablement AUSSI lui (avec la comète 30 Hz,
   depuis en pause) qui chauffait le « rideau » : un cadre monté n'est
   coûteux QUE si quelque chose y anime.

3. **LE VOILE ALPHA SUR LES VIDÉOS DES PAGES.** Une couche alpha
   par-dessus une AVPlayerLayer fait perdre le direct-to-display : le
   compositeur rééchantillonne la vidéo à CHAQUE frame du vol (la loi
   maison : « ce qui coûte, c'est ce que le compositeur doit
   rééchantillonner »). Home/exos/progress ont toutes un fond vidéo.

(Accessoire : le chien de garde re-empile un `asyncAfter` PAR FRAME —
60/s ; churn inutile, un seul timer réarmé suffit.)

**LE PLAN DE FIX (au go) :**
- F1 : le contenu du player devient INERTE tant que p < 1 (le badge ne
  respire que POSÉ, comme la comète) → le cadre+contenu peuvent alors
  être PRÉ-MONTÉS en permanence SANS chauffe (un arbre statique
  offscreen ne coûte rien — le rideau ne brûlait que par ses
  animations) → la naissance SORT du geste, le drag ne paie plus rien.
- F2 : les LECTEURS des pages SE TAISENT (`rate 0`, le pattern
  rateFond de progress) dès que le player couvre (p > 0,05) — le
  compositeur retrouve son chemin direct.
- F3 : le chien = un seul minuteur réarmé.
- Vérifs : CPU repos (cadre monté inerte ≈ sans player), `-fps` en
  cycle, films du vol, et SON doigt.

### 3.4nonies L'ANALYSE « PAS ENCORE ASSEZ FLUIDE » (01-09, 3ᵉ passe —
sans code)

**LE CONSTAT DE MÉTHODE : je n'ai JAMAIS mesuré la cadence réelle sur
SON tel pendant SON drag.** La loi maison : la vraie cadence se mesure
sur le téléphone. Tant que ce chiffre manque, on ne sait pas si le
« pas fluide » est une CADENCE (rendu) ou une RÉPONSE (le geste).
→ Protocole : SondeCadence branchée au player (l'arg `-fps` existant),
lancée sur le tel avec console — elle drague 20 s, la console donne
les img/s seconde par seconde pendant SES gestes. LE chiffre qui
aiguille tout le reste.

**LES DEUX DÉFAUTS DE RÉPONSE déjà identifiables dans le code (le
ressenti, même à 60 img/s) :**
1. **LA PRISE TARDE ET SAUTE** : `minimumDistance: 12` = le player ne
   bouge qu'après 12 pt de doigt (un début de geste « qui ne répond
   pas ») ; et le suivi calcule `1 − dy/écran` en ABSOLU — au premier
   événement, p saute de sa valeur au point du doigt. Fix candidat :
   prise à 2-4 pt + suivi ANCRÉ (p = p₀ − dy/écran, p₀ capturé à la
   prise).
2. **LE SAUT DE REPRISE EN VOL** : attraper le player PENDANT une
   animation (il monte au tap, elle le rattrape) : le modèle `p` est
   déjà À LA CIBLE (1) pendant que l'écran montre la valeur animée —
   le premier `suivre()` fait CLAQUER le player de sa position visible
   vers celle du doigt. C'est un glitch structurel des animations de
   modèle SwiftUI. Fixes candidats : (a) raccord DOUX (le premier
   suivre re-cible en `withAnimation` courte au lieu d'écrire sec) ;
   (b) interdire la reprise pendant le vol tap (fenêtre 0,7 s) —
   moins bien (le doigt doit toujours gagner).

**RESTE CÔTÉ RENDU (si la sonde tel dit < 50 img/s)** : le voile
plein écran composité par frame au-dessus des couches vidéo (muettes
mais PRÉSENTES — une AVPlayerLayer figée reste une couche) et des
shaders de la fiche. Piste alors : pendant le vol, remplacer le voile
alpha par un assombrissement SANS couche (brightness sur la page ?) —
à mesurer avant.

### 3.4decies LE PLAN F — « ÇA MARCHE PAS » (01-09, 4ᵉ passe, après le
scellement 647cdbb ; sans code, attend son go)

**LE CONSTAT.** S10 (suivi ancré + prise 3 pt + `scrollDisabled` si la
partition tient) est sur le tel, verdict « ça marche pas ». La série §3
est SCELLÉE (647cdbb) — ce plan repart de ce socle. Trois défauts sont
encore LISIBLES dans le code (vérifiés `fichier:ligne` ce matin), plus
la mesure qui manque toujours.

**F1 — LE SPRING DE POURSUITE (la cause n°1 du ressenti).**
`PlayerMonde.swift:124` : chaque frame de drag écrit `p` via
`withAnimation(.interactiveSpring(response: 0.15))`. Le player ne SUIT
pas le doigt, il le POURSUIT avec ~0,15 s de retard permanent, et
chaque delta RELANCE un ressort re-ciblé — du caoutchouc structurel,
jamais du « collé au doigt ». On l'avait mis pour amortir le saut de
saisie en vol (§3.4nonies-2 : pendant une animation, le modèle `p` est
déjà à la cible pendant que l'écran montre la valeur animée — une
écriture sèche CLAQUE). Le vrai fix n'est pas d'amortir TOUTES les
écritures, c'est de supprimer l'écart modèle/visuel :
**POSSÉDER `p`.** Plus aucun `withAnimation` sur `p` : les vols
ouvrir/fermer deviennent un TWEEN MAISON (un pas par frame —
`CADisplayLink` ou `TimelineView` — qui avance `p` avec la même courbe
easeInOut 0,68 s). Alors `p` modèle == `p` visible À CHAQUE INSTANT :
la saisie en vol lit `p` (exact, l'ancre est juste), le suivi écrit `p`
SEC (transaction sans animation) — collé au doigt, zéro rattrapage,
zéro claquement. C'est l'architecture des vrais sheets (UIKit met un
animator EN PAUSE à la saisie et lit `fractionComplete` ; on refait
pareil en possédant la variable). ⚠️ Lois tenues : le tween n'écrit
QUE `p` (lu par `OffsetVol`/voile seuls — la granularité §3 tient), et
le pas de frame vit derrière l'`@Observable`, pas un `@State` de page.

**F2 — LE SCROLL QUI GARDE LE CENTRE dès que la partition déborde.**
`PageCard.swift:398` : `scrollDisabled(contenuH <= cadreH + 1)` ne
libère le drag que si la liste TIENT dans son cadre. Une vraie séance
(plusieurs exos) déborde → le `ScrollView` reprend TOUS les drags
verticaux du centre → « j'arrive pas à drag vers le bas » revient
exactement dans le cas réel. Le vrai pattern (Apple Music) : la
COOPÉRATION AU TOP — le scroll possède tant qu'il n'est pas à
l'offset 0 ; AU TOP (l'état par défaut de la partition), tirer vers le
BAS appartient au player. SwiftUI pur ne sait pas transférer un geste
en plein vol → un `UIPanGestureRecognizer` SIMULTANÉ posé sur
l'`UIScrollView` sous-jacent (introspection par descente de vues,
`shouldRecognizeSimultaneously = true`) : si `contentOffset.y <= 0` ET
translation vers le bas → il ÉPINGLE l'offset à 0 et nourrit
`suivreDelta` ; sinon il ne fait rien et le scroll garde. Parade au
risque d'introspection : si l'`UIScrollView` n'est pas trouvé, on
retombe sur S10 tel quel (rien de cassé).

**F3 — L'EFFLEUREMENT QUI « BIM ».** `PlayerMonde.swift:160-161` :
`commettre()` juge l'élan à ±150 pt/s. Un drag LENT dépasse déjà
150 → quasi tout relâcher part à FOND d'un coup : elle ne peut jamais
poser le player à mi-geste ni le raccompagner — c'est le « quand
j'effleure, bim ». Recaler le seuil à ~450 pt/s (l'ordre de grandeur
UIKit) : en dessous, c'est la POSITION qui décide (les seuils
asymétriques existants) ; l'effleurement FRANC continue de commettre.

**F4 — LA MESURE QUI MANQUE (la porte de sortie, pas une option).**
Toujours aucun chiffre de cadence sur SON tel pendant SON drag. La
sonde est branchée (`SondeCadence("player")` sous `-fps`). Protocole :
lancer sur le tel avec `-fps` + console, elle drague 20 s, lire les
img/s seconde par seconde. Si ~60 → F1-F3 étaient le sujet, fin. Si
< 45 pendant le suivi → il reste un chantier RENDU (nota : les vidéos
de page sont DÉJÀ à rate 0 pendant tout le vol — `couvre` se lève dès
`ouvrir()`/`saisir()`, vérifié `PlayerMonde.swift:46,101` — donc le
suspect serait le compositage voile+couches, à trancher sonde en main,
pas à deviner).

**ORDRE DE JEU** (chaque passe se termine par le FOUETTAGE ULTIME
§3.4bis ENTIER avant de lui montrer) :
1. **Passe A = F1 + F3** (posséder `p`, seuil d'élan) — le cœur du
   ressenti, un seul fichier (`PlayerMonde.swift`).
2. **Passe B = F2** (coopération au top, chantier UIKit séparé).
3. **F4 en porte** : la mesure `-fps` au tel AVANT son verdict final —
   le chiffre d'abord, le « c'est fluide » ensuite.

**JOURNAL DE LA PASSE A (01-09 après-midi)** :
- F1 codé : `MoteurVol` (CADisplayLink), `volVers(cible:duree:courbe:)`
  avec fins par fermeture de vol (les jetons `poseJeton`/`jetonVie`
  sont morts) ; `saisir()` arrête le vol LÀ OÙ IL EST ; suivi SEC ;
  `enMouvement = enSuivi || enVol` fige le contenu en bloc pour TOUT
  mouvement. F3 codé : élan 150 → 450.
- **LE PAS BORNÉ (trouvé au fouettage, film à l'appui)** : un tween au
  temps TÉLÉPORTE sous famine (sim chargé : 6 frames au ralenti puis
  55 % d'amplitude en UNE frame, mesuré f2499 du film b-fiche). Borne
  à 0,08 de course/frame — au-dessus de la pente crête légitime
  (easeOut ×3 / 13 frames ≈ 0,074), donc invisible à cadence pleine ;
  sous famine le vol s'ALLONGE au lieu de sauter.
- **Le banc `-playerDoigt`** (doigt fantôme) : tap-vol · fermeture au
  doigt lent (élan 120 : la position décide) · ouverture lente ·
  REPRISE en plein vol à 250 ms — il exerce le chemin du geste que
  `-playerCycle` ne touche pas.
- **Les juges recalés, leçons de mesure** : (a) la luminance globale
  ne juge pas une page à VIDÉOS (flammes home = Δ légitimes) → les Δ
  ne se jugent qu'EN VOL (`couvre` fait taire les lecteurs) ; (b) la
  page exos est aussi sombre que le player → juge à DEUX ZONES (titre
  header + titres de grille) ; (c) le player MICRO-OUVERT (p ~0,1)
  recouvre pile la bande et masque la pilule SANS bouger la luminance
  → les frames « avant/après » exigent la dalle visible ; (d) le
  texte de la dalle VIT (chrono) → ancrage xmin/ymin strict (±6),
  xmax libre (±40), ymax ±20 (lueurs qui respirent).
- **Égalité géométrique mesurée (en séance, boîte claire de la bande
  basse)** : home (68, 1100, 0, 76) · progress (68, 1100, 0, 76) ·
  fiche (68, 1100, 0, 76) — IDENTIQUES au pixel. Exos : jugée à part
  (zones), même robe PageCard.
- `-activeWorkout` = l'arg qui sème la séance OUVERTE (le vrai régime
  du player) ; `-demoData` ne sème que l'historique.

**BILAN DU FOUETTAGE (protocole C, 01-09 13h, machine calme, binaire
pas-borné, 4 pages × ~7 cycles doigt fantôme en séance)** :
- VOLS (frames mesurables par transition, juge lum) : home
  [20,59,20,54,17] · progress [23,37,19,29,16] · fiche
  [44,4,48,4,53,4,55,6,101,7] — min ≥ 3, moy ≥ 5 partout ✓. Exos
  (page sombre, juge lum aveugle) : bord du corps MESURÉ frame à
  frame — ouverture f24-35 : −72,−64,−60,−56,−52,−40,−36,−28,−20,
  −12,−4,0 px/f (décélération easeInOut propre) ; fermeture
  f613-625 : +44/+48 px/f réguliers ✓.
- SAUT/FLASH : home max 5 px-lum (filet 11,2) ✓ · progress 8 (11,7)
  ✓ · fiche/exos : bords mesurés lisses (max 96 px/f continu,
  ≪ 230) ; les « échecs » lum restants = falaises LÉGITIMES (le bord
  traverse le dôme/la dalle claire) — et le pas borné rend la
  téléportation STRUCTURELLEMENT impossible (≤ 204 px/frame). ✓
- PAGE INTACTE : dalle avant/après IDENTIQUE (68, 1100, 0, 76) sur
  home, fiche ; progress écarts [4,0,0,2] ; casse grossière 8,32 ·
  8,24 · 4,36 · 5,49 (seuil 10) ✓ — et l'ÉGALITÉ GÉOMÉTRIQUE des
  dalles : (68, 1100, 0, 76) au pixel sur les quatre pages ✓.
- RETOURS : SONDE-HIT 18-21 rapports/page, jamais un conteneur UIKit
  orphelin (le fantôme e9521cf ne renaît pas) ✓.
- Leçon d'instrumentation : les juges lum/zones ont accusé à tort
  exos et fiche (voile progressif, dôme clair, pilule masquée au
  micro-ouvert, trait pris pour la pilule) — chaque accusation a été
  contre-vérifiée par une MESURE DE POSITION du bord, qui est le bon
  instrument (juge_trait naïf rejeté : il suivait les textes).

### 3.4undecies LE PLAN HARD DU DRAG VERS LE BAS (01-09 fin de
journée — verdict : « j'arrive toujours pas à drag vers le bas, ça
fait 10 fois, fais un plan hard » ; sans code, attend son go)

**L'AVEU DE MÉTHODE, d'abord.** Dix itérations parce que mes bancs
n'ont JAMAIS testé son doigt : le doigt fantôme appelle
`suivreDelta()` DANS le modèle — il court-circuite tout le routage
tactile (recognizers, ScrollView, priorités). Le protocole prouvait la
cinématique (vraie), jamais LA POSSESSION DU GESTE. Le coupable
identifié dès §3.4decies-F2 et repoussé en « passe B » : depuis le
player ouvert, le `ScrollView` de la partition possède TOUS les drags
verticaux du centre de l'écran dès que la liste déborde
(`scrollDisabled(contenuH <= cadreH + 1)`, PageCard.swift:398, ne joue
que liste courte). Son drag vers le bas tombe dedans. On ne repousse
plus : c'est LE chantier, et il se teste désormais avec de VRAIS
touchers.

**LE PRINCIPE (le « hard ») : LE DRAG DESCENDANT APPARTIENT AU
PLAYER — toujours, partout sur le corps, sans zone morte.** La liste
ne scrolle que ce qui reste (montées, et descentes quand elle n'est
pas au top).

- **B1 — LE PAN MAÎTRE UIKIT.** Un `UIPanGestureRecognizer` à nous,
  posé au niveau du corps du player (introspection : descendre depuis
  la vue hôte jusqu'à l'`UIScrollView` de la partition et accrocher le
  pan sur leur ancêtre commun), `shouldRecognizeSimultaneouslyWith =
  true`. SwiftUI ne sait pas exprimer une priorité CONTRE le pan d'un
  UIScrollView ; UIKit sait : notre pan pilote `suivreDelta` pour tout
  geste NET vers le bas (|dy| > |dx|), et le pan du scroll est
  subordonné (`shouldBeRequiredToFail` conditionnel).
- **B2 — LA COOPÉRATION AU TOP (Apple Music).** Dans le pan continu :
  si `contentOffset.y <= 0` ET translation descendante → le player
  prend (offset ÉPINGLÉ à 0, bounces coupés pendant la prise) ; si la
  liste est descendue → elle remonte d'abord son chemin, et LE MÊME
  geste bascule au player à l'instant où elle touche le top (on lit
  l'offset en continu, pas d'état armé à l'avance).
- **B3 — LE FILET (si l'introspection ne trouve pas le scroll sur cet
  iOS)** : `scrollDisabled(p < 1 || enSuivi)` — la liste ne scrolle
  qu'au POSÉ COMPLET ; et au posé, des PRISES LARGES garanties :
  le header entier + deux gouttières latérales de 36 pt (contentShape
  au-dessus de la liste). Le pire des cas garde de vraies poignées —
  plus jamais « je n'y arrive pas ».
- **B4 — LE BANC DES VRAIS TOUCHERS (la leçon, outillée).** Fini le
  fantôme-modèle comme seule preuve : un pilote CGEvent (souris
  scriptée SUR la fenêtre du Simulator — le sim traduit en VRAIS
  UITouch qui traversent le VRAI routage) joue : drag lent descendant
  depuis le CENTRE de la liste (contenu LONG puis court), depuis le
  header, depuis les gouttières, flick descendant, drag montant
  (le scroll doit garder les montées liste longue). Chaque geste
  filmé + `-gesteSonde` à la console. AUCUN verdict de routage sans ce
  banc.
- **B5 — LA SONDE DE POSSESSION (`-gesteSonde`).** En DEBUG : chaque
  began/changed/ended de notre pan et du pan du scroll loggé avec le
  gagnant. Si le voleur n'est pas le scroll (un cover, un autre
  recognizer, la Reachability du bord bas), la console le NOMME au
  lieu qu'on devine.

**ORDRE : B5 + B4 d'abord** (prouver le voleur avec de vrais touchers
AVANT de réparer — une fois, proprement), **puis B1/B2, filet B3**,
puis le protocole §3.4bis ENTIER + le banc B4 complet, et seulement
là le tel.

**JOURNAL (01-09 fin d'après-midi)** :
- `tools/player/doigt.swift` écrit (CGEvent sur la fenêtre du sim) —
  **l'injection est REFUSÉE par macOS** (self-test : curseur demandé
  (200,200), resté sur place — Accessibilité non accordée au
  processus). Les vrais-touchers automatisés attendent soit cette
  permission (Réglages → Confidentialité → Accessibilité), soit une
  target XCUITest. AUCUN verdict de routage n'a donc encore été rendu
  au sim — dit, pas caché.
- **Pivot d'ordre, pas d'esprit** : B1/B2 se construisent par
  POSSESSION (le pan maître prend le descendant au niveau fenêtre —
  correct quel que soit le voleur) ; B5 embarque pour le TEL :
  `-gesteSonde` fait crier maître (BEGAN/PREND/LAISSE/COMMET) et
  scroll (began/ended/offset) — la console USB nommera le voleur sous
  SES doigts si le pan maître ne suffisait pas.
- Découverte de banc : même la séance `-activeWorkoutLong` donne une
  partition PLIÉE plus courte que son cadre (seul « courant » est
  déplié) → `scrollDisabled` S10 était souvent ACTIF — le ScrollView
  n'est probablement pas le seul voleur ; le pan maître ne dépend pas
  de son identité.
- CODÉ : `PanMaitre` (pan fenêtre simultané, direction nette, coop
  au top avec épinglage d'offset, retrait au démontage — un
  recognizer ne retient pas sa cible), le `simultaneousGesture`
  SwiftUI du corps RETIRÉ (remplacé), seed `-activeWorkoutLong`
  (5 exos ×4 sets), `SondeGestePan` (target additionnel sur le pan du
  scroll), logs SAISIR/COMMETTRE sous `-gesteSonde`.

### 3.4duodecies L'AFFINAGE + LA RAFALE (01-09 soir — verdicts :
« plus fluide de fou, tu peux encore l'améliorer ? et après tu
commit » · « si je joue et fais 20 fois d'affilée ça bug »)

Le pan maître A réglé le drag (« plus fluide de fou »). Les
retouches de cette passe, toutes dans `PlayerMonde.swift` :
1. **La fin de course CONTINUE la vitesse du doigt** : pente initiale
   d'un easeOut cubique = 3·distance/durée → durée = 3·distance/v :
   elle jette, ça file ; elle pose, ça se pose. Zéro à-coup au
   relâcher (élan aligné et > 0,35 course/s ; sinon le tempo
   proportionnel).
2. **Les butées VIVENT** : au-delà de [0, 1], sur-course élastique
   (tanh, ≤ 5 %) — une butée qui répond, pas un mur ; et la JUPE
   (débord noir 80 pt sous le corps) couvre le bas pendant
   l'étirement.
3. **LA RAFALE, deux trous colmatés** : (a) le voile reste bouclier
   dès le vol mais ne FERME qu'au posé — en vol, un tap parasite de
   la rafale fermait le player par surprise ; (b) le pan maître, une
   fois PRIS, garde le geste jusqu'au relâcher — `ouvert` ne se
   re-lit que pour prendre, jamais pour lâcher en plein doigt.
4. Prise à 6 pt (au lieu de 8).

### 3.5 LES RISQUES, CHACUN AVEC SA PARADE

1. **Le mur du type-checker de mainBody** (337a6e3, payé) → le player
   est UNE var nommée + struct à part, jamais un inline.
2. **Un cover UIKit par-dessus le player ouvert** (coffre, Chemin,
   MoisIpod) → conforme au périmètre §2.17 (« pas le reste ») : le
   cover recouvre, le player attend dessous ; SEULE l'ExercisesView
   imbriquée est traitée (S2).
3. **La vue lourde qui naît pendant un film** → la partition reste
   montée à p > 0,02 (différée), les groupes requêtés à l'ouverture,
   une fois.
4. **Le geste mort sans onEnded** → chiens de garde partout (déjà
   écrits), et l'ouverture DÉCLENCHÉE n'a pas de geste à perdre.
5. **Le double-player transitoire S1→S4** : impossible — les dalles
   home/exercices n'ouvrent RIEN aujourd'hui ; chaque étape en branche
   UNE sur le player unique.
6. **La séance qui meurt pendant que le player est ouvert** (stop
   validé depuis la pop-up) → `fermer()` sur `active == nil`
   (onChange à la racine), le corps se range proprement.
7. **Les hunks des autres sessions** : `ActiveWorkoutView.swift`,
   `SessionSlate.swift`, `PlayerSeance.swift` portent du travail
   étranger — commits par chemins/hunks, jamais `-A`, et
   `SessionSlate` ne s'édite qu'en évitant les 28 lignes étrangères.

Dettes inchangées : robe NUIT de la plongée (verdict attendu), cible
du zoom du launch, sticker réel du jour (moteur de faits).

**H. LA VALIDATION PAR CAPTURES, PAS PAR BUILDS EN RAFALE.** Cinq builds
device jugés à l'œil = la mauvaise boucle (payée aujourd'hui, 0/10). La
prochaine : (1) v6 appliquant A→G ; (2) TROIS CAPTURES statiques (repos /
mi-course / déployé) prises au banc et montrées à Kathryn AVANT tout
déploiement ; (3) seulement une fois le rendu accepté sur captures, UN build
device pour juger le mouvement et la cadence. Le rendu se valide sur image,
le geste sur téléphone.
2. **Tranche 1 — la FICHE détail.** On remplace la pilule flottante du haut
   (la régression) par `PageCard` : la dalle en bas sous le galet, la fiche
   devient la « grosse card » qui se pousse. Arbitrage avec `carteDrag`.
3. **Tranche 2 — la HOME.** Même composant, la home devient la grosse card, sa
   dalle actuelle devient la dalle du rideau. ⚠️ Fichier WIP d'une autre
   session — coordonner ou commit par hunk.
4. **Tranche 3 — la LISTE d'exercices.** Idem, arbitrage avec la molette.
5. **Tranche 4 — on TUE l'`ActiveWorkoutSheet`** (le gros player modal) et le
   défer d'`onAddExercise` : plus de `.sheet`, le player-en-card est la seule
   forme.

---

## 6. LA COORDINATION MULTI-SESSION (bloquant réel)

- **La fiche** (`ExerciseDetailView`) est le **chantier ACTIF d'une autre
  session** — deux commits aujourd'hui (`0c7ab1a`, `2972f14`). C'est elle qui a
  monté le player en haut.
- **La home** (`HomeNuit`) est aussi le WIP d'une autre session.
- **`WoopApp`** porte le WIP BoosterCard d'une troisième.
- Règle : **commit par hunk** (`git apply --cached` filtré), jamais
  `git add -A`, jamais `git stash`. Kathryn a dit « ignore autre session » — on
  avance, mais on ne DÉTRUIT pas leur travail non commité sur le disque.
- **Risque** : si on refait le player pendant qu'une autre session le refait
  aussi, on se marche dessus au prochain commit. À arbitrer avec Kathryn :
  soit on attend qu'ils posent, soit on prend la main et ils suivent.

---

## 7. LA VÉRIFICATION (sur le TÉLÉPHONE, le seul juge)

- **Cadence** : le lever tient 60 img/s sur l'appareil (le sim est aveugle aux
  gels Metal). Le tel **ne chauffe pas** (la partition n'est montée qu'au
  lever).
- **Cohérence** : le MÊME geste, la MÊME dalle, au MÊME endroit (bas, sous le
  galet) sur home + liste + détail.
- **Non-régression** : la chaîne stop et la chaîne de fin intactes ; la molette
  (fiche exo) et la carte des séries (fiche détail) ne « respirent » pas
  pendant le lever.
- **Le gel ne peut plus revenir** : plus d'`ActiveWorkoutSheet` modal (tranche
  4), donc plus de conteneur de présentation orphelin.

---

## DÉCISIONS DE KATHRYN (30-08) — figées

1. ✅ **Montage** : composant **`PageCard` PAR PAGE**. (Pas de racine unique.)
2. ✅ **La poignée = la dalle-player** : on la tire vers le HAUT pour lever la
   page ; **un drag vers le BAS la repose, façon Spotify** (le now-playing qui
   redescend). Même geste pour ouvrir et fermer.
3. ✅ **Multi-session** : **je reprends la main sur la fiche ET la home.** Les
   autres sessions restent sur documentation / backend / page Progress. Message
   de contexte envoyé aux sessions app (40, 0b, cd, 42) le 30-08.
4. ⏳ **Amplitude** du lever : à juger au banc (tranche 0) — seule décision
   reportée, elle se prend à l'œil sur l'appareil.

**Statut** : plan validé, décisions prises. Reste le GO de Kathryn pour coder
(elle a dit « ne code pas » ce soir) — et, idéalement, un accusé de la session
qui tenait le player-fiche (`0c7ab1a`/`2972f14`) avant que j'y reparte.
