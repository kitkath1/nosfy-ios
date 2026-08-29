# NOTIFICATIONS V2 — la refonte du 28-08 (verdict de Kathryn sur le J1)

Ce plan REMPLACE les §2 et §3 de `PLAN-NOTIFS.md`. Le socle (§1), le banc
(§4) et la discipline (§7) restent tels quels : ils n'ont pas été contestés.

**Ce qui est acquis et qu'on ne rejoue pas** : la dalle noire aux cotes OPAL,
la pièce de la maison (`PieceSprite`, planche de 72 cases — la case 40 est
la bonne, la 4 sortait une face NOIRE qui lisait comme un anneau), le banc
`-notifLab` avec les deux robes empilées, `dd-notif`, `kat-notif`.

---

## §A — VARIANT A « LA JAUGE » : ce qui change

### A1. Le titre saute

« SET COMPLETE » disparaît. La card mène avec **le gain**, pas avec un
label d'état : l'information est « +20 coins earned », le reste est du
décor administratif.

```
┌──────────────────────────────────────────┐
│  +20 coins earned                  ,-·-. │
│  Vault progress                   (  ()  │
│                                    `-·-' │
│  ▰▰▰▰▰▰▰▰▰▰▰▰·:·.░░░░░░░░░░░░             │
└──────────────────────────────────────────┘
```

Le « +20 » monte toujours pendant l'entrée (`ChiffreQuiMonte`, déjà écrit et
`Animatable` — c'est ce qui l'empêche de claquer en une image).

### A2. La pièce TOURNE

Elle passe de la case figée 40 à `PieceQuiTourne` — la même mécanique que le
variant B, **période lente** (~9 s le tour) : c'est une ambiance, pas un
numéro. La planche est chargée une fois et retenue ; le tour ne fait que
choisir une case (on ne seeke jamais dans une vidéo — trois mesures l'ont
tué dans `DepartCine.swift`).

### A3. La barre : plus fine, et REMPLIE DE PARTICULES

- **Hauteur 7 → 4 pt.** Un trait, plus une gélule.
- **Les particules** montent et dérivent DANS le remplissage, s'éteignent au
  front, et une **traînée de lumière** court sous la barre.

**Comment, et pourquoi comme ça :**

1. **Un `Canvas`, pas N calques.** Ce qui se redessine par image est UN
   dessin (loi n°4). Cinquante petites vues animées, c'est cinquante
   invalidations par image. Le `Canvas` ici est minuscule (~240 × 12 pt) —
   la loi « un Canvas plein écran rasterise toute sa surface » ne mord pas
   à cette taille.
2. **⚠️ Un `Canvas` n'est PAS animable.** Il faut `Animatable` sur ses
   valeurs pilotes, sinon le remplissage CLAQUE au lieu de monter. Ici il y
   en a une seule (la fraction) — pas besoin d'`AnimatablePair`.
3. **Les particules sont DÉTERMINISTES, par hash** (la grammaire de
   `Scintilles` et de la poudre de la card reward) : `sin(i·12.9898 +
   k·78.233)`. Pas de tableau d'état, pas de `Math.random` — une capture de
   réglage doit être reproductible, sinon deux tours de fouettage ne se
   comparent jamais.
4. **Elles ne vivent que SOUS le front.** Une particule au-delà de la
   fraction est de la lumière qui ment sur le gain.

### A4. Ce qui NE change pas

Le rognage par `Shape` (la barre ne change jamais de largeur — un layout
recalculé à 60 Hz, c'est le lag), le dégradé blanc froid → blanc pur, la
tête spéculaire, la pièce qui mord le bord droit.

---

## §B — VARIANT B « LE GROS TEXTE » : la refonte lourde

C'est là qu'est le travail. Ta réf (le « YOU MADE » avec le 4 de verre)
dit deux choses que le J1 ne fait pas : **le texte est BEAUCOUP plus fondu**,
et **il est COUPÉ** — pas éteint aux bords, coupé.

### B1. DEUX LIGNES, et elles débordent

```
┌──────────────────────────────────────────┐
│ ██  ██  ███  ██  ██                      │
│ ██  ██  ██   ██  ██     ← « YOU », le U  │
│  ████   ███   ████        rogné à droite │
│ ██   ██ ██ ███ ██                        │
│ ██   ██ ██  █  ██  ,-·-. ← « WIN » rogné │
│ ██   ██ ██     ██ (  ()  ← la petite     │
└───────────────────┴`-·-'──────────────────┘
```

- **« YOU » sur la ligne 1, « WIN » sur la ligne 2** — la structure de ta
  réf, pas une ligne unique. C'est ce qui permet de **rogner le U** : sur
  une seule ligne on ne peut couper que le Y et le N des extrémités.
- **Corps ~104 pt** (contre 84) — le mot déborde de la dalle en largeur ET
  les deux lignes débordent en hauteur. Hors layout (`fixedSize`), le
  `clipShape` du socle fait la coupe. **Jamais rétréci** : c'est le débord
  qui fait la coupe, une police réduite pour « tenir » tue l'effet.
- **Le rognage est un PRÉREQUIS, pas un effet de bord** — donc il se
  MESURE : la sonde vérifie que la colonne de pixels du bord droit de la
  dalle contient de l'encre de lettre. Une capture où le mot « rentre »
  est un échec, même si elle est jolie.

### B2. Le FONDU — beaucoup plus loin

Le J1 posait la base à blanc 0,34 → 0,05 : ça lit comme du gris plat. La
réf est presque noire.

- **La base tombe à ~0,12 → 0,02.** Les lettres non éclairées ne sont plus
  grises : elles sont **du relief dans le noir**.
- **Le fondu du bas** (les lettres qui se noient) monte, comme dans
  `TexteGeant` : la ligne du bas est à demi avalée.
- Conséquence directe et voulue : **sans la lampe, on ne lit presque rien.**
  C'est la lumière qui écrit le mot, pas l'encre.

### B3. LE SPOTLIGHT — d'en haut, et il laisse des zones NOIRES

Ton verdict, mot pour mot : *« le spotlight qui part de la partie haute
pour éclairer le mot YOU WIN, et parfois une partie du mot est complètement
dans le noir. »*

- **La source est en HAUT** (centre du bord supérieur), pas au centre de la
  dalle.
- **Le cône est ÉPAIS** (« l'épaisse spotlight ») — un faisceau franc, pas
  un halo mou.
- **Le champ est ÉTROIT par rapport au mot.** C'est LA condition pour que
  « parfois une partie du mot soit complètement dans le noir » : si le
  champ couvre tout, il n'y a jamais d'ombre. Le rayon utile vaut ~55 % de
  la largeur du mot.
- **Il BALAIE** sur `balayageSpot` (l'horloge déjà partagée avec la card
  reward, deux harmoniques premières entre elles : la course est large et
  jamais mécanique — période ~9,7 s). À gauche de sa course, « WIN » est
  noir ; à droite, c'est « YOU ».
- La technique reste celle qui est éprouvée : **une copie sombre + une copie
  claire masquée par le champ**. La trame ne se redessine pas, seul le
  masque glisse.

### B4. CHAQUE LETTRE APPARAÎT INDIVIDUELLEMENT

L'entrée n'est plus un fondu de bloc : les lettres arrivent **une par une**.

- Le mot devient une **rangée de lettres**, chacune avec son propre retard
  (~0,055 s d'écart), chacune montant de quelques points en s'allumant.
- **⚠️ UN SEUL progrès `p` pilote les six lettres**, et il vit dans une
  `struct View: Animatable` À PART. Deux raisons payées :
  - des rampes échelonnées posées sous un `withAnimation` nu ne jouent
    qu'au doigt (loi déjà écrite dans `RewardCard`) ;
  - si `p` vit sur la card, la card entière se ré-évalue soixante fois par
    seconde pendant l'entrée (loi n°2).
- **⚠️ Jamais deux `withAnimation` au même tour** — deux au même instant ne
  font RIEN. Un aller-retour se joue en keyframes.
- Coût du découpage : le crénage d'une rangée de `Text` n'est pas celui
  d'un `Text` unique. Sur un titre d'affiche c'est acceptable, mais **ça se
  regarde sur capture** avant de le déclarer bon.

### B5. LA PIÈCE — UNE SEULE, QUI TOURNE, AU CENTRE

**UNE pièce, et elle est AU CENTRE de la notification** (verdict de Kathryn,
28-08 — dit deux fois : *« elle ne tourne pas sur le N, elle est au centre
de la notification »*). C'est l'objet héros, celui qui joue le rôle du « 4 »
de verre dans sa réf : **posé par-dessus le mot, au milieu de la dalle**.

- Elle **tourne** (`PieceQuiTourne`, la planche de 72 cases).
- Elle est **plus petite** qu'au J1 : ~54 pt de diamètre visible (contre 70).
- Elle n'est pas à droite, elle n'est pas sur une lettre : **au centre**, et
  c'est le mot qui passe DERRIÈRE elle.
- Elle prend la lumière du même spot que les lettres — une seule lampe dans
  la card, jamais deux lumières qui se contredisent.
- Elle garde son **creux sombre** dessous : le J1 l'a montré, un objet posé
  nu sur une lettre ne lit pas — un objet sans SOL n'est pas devant, il est
  collé.

---

## §C — LES JALONS

| # | Ce qui sort | Comment on le juge |
|---|---|---|
| **V2-1** | Variant A : titre sauté, pièce qui tourne, barre à 4 pt | capture posée |
| **V2-2** | Variant A : les particules dans la barre | **film** de l'entrée (le remplissage se juge en mouvement, pas sur une image) |
| **V2-3** | Variant B : deux lignes, corps 104, fondu à 0,12, rognage | capture + **sonde du bord droit** (l'encre DOIT toucher la coupe) |
| **V2-4** | Variant B : le spot épais du haut, la course, les zones noires | film — et une sonde qui vérifie qu'à un instant du balayage une moitié du mot est sous 3/255 |
| **V2-5** | Variant B : les lettres une par une | film de l'entrée |
| **V2-6** | Variant B : LA pièce qui tourne, au centre, et son creux | capture |
| **V2-7** | Ton verdict | — |

Ordre choisi : **le rognage et le fondu AVANT les animations.** Ce sont tes
deux prérequis (« c'est un prérequis très important ») ; animer des lettres
dont la taille et la valeur ne sont pas encore tranchées, c'est fouetter
deux fois.

---

## §D — CE QUE ÇA COÛTE, ET CE QU'ON MESURERA

Cette V2 ajoute trois choses qui vivent **à la cadence de l'écran** là où le
J1 n'en avait qu'une (le balayage) : les particules, les lettres à l'entrée,
la pièce qui tourne dans la card A. C'est exactement le profil des chantiers
qui ont coûté des images par le passé.

- `./tools/charge.sh` **avant** toute mesure (🔴 au-dessus de 2 : la charge
  machine invalide la cadence — payé le 27-08, j'ai accusé la route à
  12-21 img/s alors que la home SEULE tombait à 9-20).
- Deux régimes mesurés : **repos** (les deux cards posées, seul le spot
  balaie) et **entrée** (tout part en même temps).
- ⚠️ **La vraie cadence se mesure sur le TÉLÉPHONE.** Ce que je pourrai dire
  du simulateur, je le dirai comme tel.
- Aucun `blur` par objet (27 img/s la pièce, mesuré), aucun verre animé
  (60 → 14 img/s), aucun masque sur une couche vidéo — il n'y a d'ailleurs
  plus une seule vidéo dans ces deux cards.
