# L'ACCUEIL DE NOSFY — la chauve-souris, le texte au-dessus, et le halo qui vit

*13-09-2026 · plan, rien n'est codé · suite de `PLAN-RETOUCHES-FILM.md` §7*

Sa consigne : « une fois arrivée dans l'onboarding, au milieu de l'écran la vidéo fondue
(`welcome_nosty`), au-dessus un texte Apple — *Bienvenue dans mon univers noir…* puis en
anglais, puis *Je suis Nosfy, je suis là pour t'aider à te dépasser* puis en anglais. La
chauve-souris ne bouge pas, juste le texte. La vidéo assez haute pour ne pas passer sous
les textes, parfois plus longs à la deuxième étape. Ça défile, disparition, et on arrive à
la langue. Et le halo derrière l'île doit bouger dix fois plus, l'haptique plus fort. »

---

## 0. La vidéo, mesurée (`~/Downloads/welcome_nosty.mp4`, 13-09 11:46)

| | mesuré | conséquence |
|---|---|---|
| format | **3840 × 2160, paysage**, HEVC 10 bits, 24 i/s, 7,04 s, 19 Mo | injouable telle quelle sur un téléphone (la famille du tuto : « 3,4 écrans par image ») — **à cuire** |
| fond | **noir vrai** (coins à 0/255), pas d'alpha | posée sur le noir de la page, sa boîte est **invisible par construction** — pas de masque, pas de fusion |
| le sujet | la chauve-souris **au centre**, dans le tiers médian (x ≈ 33 → 69 %), **pleine hauteur** : les oreilles touchent le bord haut, le corps est **coupé par le bord bas** | recadrer au tiers médian ; et les DEUX bords coupés (haut, bas) se voient sur du noir → **extinctions cuites** (loi n° 5 de la cuisson) |
| mouvement | différence moyenne t = 0,5 → 6,5 s : **0,70 / 255** | quasi fixe — « la chauve-souris ne bouge pas » est déjà vrai ; un ping-pong sera **sans couture** |

---

## 1. L'écran : une étape de plus, AVANT la langue

Une nouvelle `Etape.accueil`, la première du film. Elle ne pose aucune question — c'est
la rencontre. L'île est éteinte (tiers 0), le halo s'allume comme aujourd'hui (l'allumage
de 1,2 s), puis :

```
┌──────────────────────────────┐
│           ● île              │  0 → 152 pt : le halo (inchangé)
│                              │
│  Bienvenue dans mon          │  LA ZONE DE TEXTE — hauteur FIXE 160 pt,
│  univers noir.               │  alignée EN BAS, calée sur le bloc le plus
│                              │  long (FR2 : 3 lignes à 30 pt ≈ 142 pt)
│  ──────── 24 pt ────────     │
│        ┌──────────┐          │  LA VIDÉO — bande de 300 pt de haut,
│        │  (chauve │          │  190 pt de large (ratio 0,63 mesuré),
│        │  -souris)│          │  centrée. Son haut est SOUS la zone de
│        └──────────┘          │  texte quoi qu'il arrive : 152+160+24 = 336
│                              │
│         (rien — l'air)       │  336 + 300 = 636 < 852 : il reste 216 pt
└──────────────────────────────┘
```

**La règle qui répond à « la vidéo assez haute » :** ce n'est pas la vidéo qu'on monte,
c'est **la zone de texte qu'on fixe**. Une hauteur réservée pour le bloc le plus long, le
texte aligné au bas de cette zone — un texte court laisse de l'air au-dessus, un texte
long remplit, et la vidéo ne bouge jamais. Aucun chevauchement possible, par construction.

**Les quatre blocs, un à la fois** (`Tirade`, comme la présentation de la question 1 —
chaque bloc remplace le précédent en fondu-flou, « ça défile ») :

| | texte | ~durée |
|---|---|---|
| FR 1 | **Bienvenue dans mon univers noir.** | 2,4 s |
| EN 1 | Welcome to my dark world. *(sourd)* | 2,2 s |
| FR 2 | **Je suis Nosfy, je suis là pour t'aider à te dépasser.** | 3,2 s |
| EN 2 | I'm Nosfy, I'm here to help you go further. *(sourd)* | 2,8 s |

≈ 11 s, puis fondu-flou de tout (texte + vidéo) → `.langue`. Un **tap** n'importe où saute
à la langue (Apple laisse toujours passer ; à trancher, voir §6).

⚠️ **« t'aider à te dépasser » tutoie.** Tout le film vouvoie (« Dans quelle langue doit-il
*vous* parler ? », « Comment dois-je *vous* appeler ? »). C'est ta phrase, je la garde telle
quelle — mais il faut trancher : soit tout passe au **tu** (six phrases à changer), soit
celle-ci devient « je suis là pour vous aider à vous dépasser ». Le mélange, lui, n'est pas
tenable.

Le halo **bat avec chaque mot** ici aussi (le A du plan précédent, déjà branché sur
`MotsFlou`).

---

## 2. La cuisson — `tools/porte/recuit_nosfy.sh`, la recette de la maison

Reprend `tools/duolingo/recuit_duo.sh` (X264 : `-preset slow -crf 20 -pix_fmt yuv420p
-g 48 -movflags +faststart -an`) et ses lois payées :

1. **Jamais `-ss`** : le trim vit DANS le graphe (`trim` + `setpts`).
2. **Le crop d'abord, au ratio de la fenêtre** : la bande fait 190 × 300 pt → **600 × 900 px**
   (@3x, ratio 2:3). Dans la source : `crop=1440:2160:1200:0` (le tiers médian, 40 pt de
   marge de chaque côté de la bête), puis `scale=600:900`.
3. **Les extinctions sont cuites** : un dégradé noir sur les **15 % du bas** (le corps coupé)
   et les **6 % du haut** (les oreilles au bord) — dans le fichier, jamais en runtime. Sur
   du noir, une extinction cuite est invisible ; un bord net, lui, se voit à trois mètres.
4. **Le ping-pong ampute ses deux doublons de bord** (comptage au réel) : 7,04 s aller +
   retour = **~14 s**, couture zéro. Avec 0,70/255 de mouvement, on ne verra même pas le
   demi-tour.
5. **Un poster** (`nosfy-accueil-poster`, image 0) dans les assets : il tient l'écran
   pendant que le lecteur chauffe — jamais un rectangle noir qui « pop ».

Sortie : `Woop/Media/nosfy-accueil-loop.mp4`, attendu **1 à 2 Mo** (contre 19). La
synchro de dossier l'embarque seule.

---

## 3. L'hôte : `NosfyReel`, à nous — pas `VideoReward`

`VideoReward` est **`private`** dans `RewardCard.swift` : l'utiliser, c'est toucher un
fichier partagé pour un mot. Et il porte des mécaniques de card (relance, recul, gel sur la
dernière image) dont l'accueil n'a que faire.

**`NosfyReel`** (dans `NosfyOnboarding.swift`, ~40 lignes, l'école de `ReelHote`) :
`AVPlayerLayer` en `resizeAspect` (la bande a le ratio du fichier — rien à rogner),
`clipsToBounds` + `masksToBounds` (SwiftUI ne rattrape pas UIKit), **`AVPlayerLooper`**
pour la boucle (sans seek qui rebrousse), muet.

Deux lois de la maison dans son corps :
- **DÉMONTÉ, jamais caché** — quand l'étape passe, la vue sort de l'arbre (une vue montée
  mais cachée est rendue : le piège du rideau, payé au téléphone qui chauffe).
- **Son barreau `-sansNosfyVideo`** — le poster à la place du lecteur. Sans lui on ne
  pourra ni l'accuser ni le disculper à la mesure.

---

## 4. Le halo « dix fois plus », et l'haptique « plus fort »

« Dix fois » n'est pas un chiffre, c'est un verdict : *je ne le vois pas bouger*. Ce qui
manque n'est pas une couche, c'est de l'**amplitude** — et une période plus courte.
Tout reste des transformations (échelle, décalage, opacité) : rien ne redessine.

| couche | aujourd'hui | proposition |
|---|---|---|
| respiration (tout) | 0,96 ↔ 1,10 · 4,3 s | **0,88 ↔ 1,26 · 3,2 s** |
| braise vagabonde | ±46 / ±24 pt · 11 s | **±110 / ±60 pt · 7 s** |
| nappe lente | 0,94 ↔ 1,14 · 7 s | **0,85 ↔ 1,30 · 5 s** |
| langue de braise | 1 tour / 19 s | **1 tour / 8 s** |
| battement par mot | +4 % · capsule 0,58 → 0,74 | **+10 % · capsule 0,58 → 0,92** |
| embrasement (il parle) | × 1,30 | **× 1,50** |

⚠️ Le flou et la couleur ne bougent toujours pas — c'est ce qui coûte. Et « plus » a une
fin : au-delà, le halo mange le texte du haut de l'écran ; on mesure sur une capture avec
la phrase la plus haute (FR 1) et on s'arrête là.

**L'haptique :** un troisième coup, **fort** (`.heavy`, intensité 1), déclaré dans une
extension de `Haptique` *dans notre fichier* (NavEncre.swift reste aux autres). La
grammaire monte d'un cran : elle répond = **moyen** (était léger) · il parle = **fort**
(était moyen) · le flash de l'île = **fort** · « Bien. » = **fort**. Pas de coup par mot —
trente vibrations en dix secondes, ça n'appuie plus, ça engourdit. Le simulateur n'a pas
de moteur : le verdict est sur le téléphone.

---

## 5. Ce que ça coûte, et ce qu'on mesure AVANT de juger

C'est la **première vidéo de cette page** — posée sous cinq couches floutées en
`plusLighter` qui bougent, avec du texte mot par mot par-dessus. C'est la famille « les
widgets en verre brûlent ». Le décodage est matériel et le fichier petit (600 × 900, 24 i/s),
mais on ne le croit pas : on le mesure.

- `-sondeVol` sur l'étape d'accueil, **avec et sans** `-sansNosfyVideo`, thermique lue à 0
  au départ, sur SON iPhone.
- Le halo à sa nouvelle amplitude, seul, avant la vidéo — pour attribuer chaque coût.
- Le seuil de refus : si l'accueil tient moins bien que la page des questions
  aujourd'hui, la vidéo attend ou s'allège (18 i/s, 480 × 720).

---

## 6. L'ordre, et trois choses à trancher

| rang | geste | coût | mesure |
|---|---|---|---|
| ① | cuire : `recuit_nosfy.sh` + poster | 0 en app | poids < 2 Mo, couture du ping-pong à l'œil |
| ② | `NosfyReel` + barreau `-sansNosfyVideo` | +1 couche vidéo | `-sondeVol` avec / sans |
| ③ | `Etape.accueil` : zone de texte fixe, 4 blocs, tap pour passer | petit | capture avec FR 2 (le plus long) |
| ④ | le halo × amplitude + `Haptique.fort` | 0 couche | capture avec FR 1 (le plus haut) — le halo ne mange pas le texte |
| ⑤ | build, pose, `-parcoursMaquette` déjà armé → l'icône | 0 | ton verdict, au téléphone |

**À trancher avant ① :**
1. **Tu ou vous** — « t'aider à te dépasser » contre le reste du film.
2. **Le tap saute-t-il l'accueil ?** (je dis oui : Apple laisse toujours passer.)
3. **L'anglais** : « Welcome to my dark world. » / « I'm Nosfy, I'm here to help you go
   further. » — ou tes mots.
