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
