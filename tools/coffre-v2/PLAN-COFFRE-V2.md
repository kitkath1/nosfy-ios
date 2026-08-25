# LA CHAMBRE AU TRÉSOR — plan de refonte de la page coffre (v2)

> Chantier ouvert le 25-08-2026. La page actuelle (`CoffreFortView.swift`,
> **710 lignes**, commitée `f9f2da9`) est ARCHIVÉE, pas amendée.
> **Ce document est la v2 du plan.** La v1 a été fouettée par trois juges
> adverses (fidélité / technique / design) qui y ont trouvé une esquive
> caractérisée, quatre chiffres faux et une loi qui s'auto-détruisait. Le
> §12 garde la trace de ce qui a été cassé — c'est la seule façon de ne pas
> le repayer.

---

## §0. LA DEMANDE, DÉCOMPOSÉE

Verbatim de Kathryn (25-08), et ce que chaque phrase engage :

| # | Sa phrase | Ce que ça engage |
|---|---|---|
| D1 | « remplacer la vidéo d'arrivée par `Liquid_pièces.mp4` » | Nouvelle cuisson, nouvelle partition. **Le film entier, passage compris.** |
| D2 | « même comportement : au tap je peux passer l'animation » | Le raccourci survit — **et sa surface tapable aussi** (aujourd'hui bornée au bloc vidéo). |
| D3 | « on va revoir toute la page, tu peux l'archiver et en faire une nouvelle » | Refonte totale. **Trois extractions bloquantes** avant la première ligne neuve. |
| D4 | « même layout que la home et exercice : toute la page est une card qu'on peut **scroller / dragger**, et **on voit la lune** » | **Un COMPORTEMENT, pas une forme.** `CarteLevee` + `FormeCardExos` + `EtatExos` + `LuneSecrete`. La lune est nommée dans le dépôt. |
| D5 | « le background s'active **que quand on touche la pièce** » | **La pièce est l'interrupteur** — et « que quand » se lit *momentané*. |
| D6 | « scroll droite-gauche, deux types : or et noires, avec un blur au scroll » | Le manège horizontal — **c'est LUI, le « scroller » de D4**. |
| D7 | « dans le header noir, la même taille de typo que la Home, sur 3 lignes » | La grammaire `PhraseVue`, aux vraies constantes. |
| D8 | « les pièces en liquid glass natif, qu'on voie leur beauté » | Verre natif — avec **de la matière dessous**, et le croissant éteint dans le shader. |

**Sa maquette** (screenshot du 25-08) confirme D4 + D7 : la card démarre haut,
la phrase 3 lignes vit **sur le noir DANS la card**, la barre néon coupe à
mi-hauteur, la pièce est posée au sol dessous.

**Les deux axes de D4/D6, et ils ne se disputent rien :**
- **horizontal** = le manège des pièces (« scroller ») ;
- **vertical** = la levée de la card (« dragger ») → **la lune apparaît dans la
  bande découverte**, exactement comme la home et les exos.

---

## §1. LES MESURES — ce que les deux fichiers autorisent

Sondés le 25-08 sur les originaux de `~/Downloads`, puis **re-sondés par deux
juges indépendants**. Rien ici n'est estimé.

### 1.1 `Liquid_pièces.mp4` — le film des pièces

| Grandeur | Mesure |
|---|---|
| Format | 3840 × 2160 (16:9 **paysage**), HEVC 10 bits, 24 i/s, 193 images, 8,04 s, 9,4 Mo |
| Structure | **DEUX cycles identiques de 96 images (4,00 s)** — le second recopie le premier |
| Le sujet | **DEUX palets ray-tracés** — un de verre sombre, un d'OR — biseaux concentriques, liseré spéculaire blanc (**L 179 de moyenne, pointes à 255**), et **chacun porte le croissant de la maison** en néon orange gravé dans sa laque |
| Le mouvement | Ils **s'approchent, atteignent leur plus près, se mettent SUR LA TRANCHE, puis S'ÉLOIGNENT** |
| La courbe (largeur / aire) | img 20-27 : **0,158 → 0,169**, aire 2,6 % — *quasi immobiles* · img 28-30 : la **RUÉE** (0,169 → 0,394 en 3 images, deltas 7,6 / 11,4 / 17,4) · **img 68-72 : LE SOMMET, 0,552, aire 16 %, frontale** · img 76 : **0,175** (elle est de champ) · img 82 : 0,108, aire 4,2 % · img 90 : 0,131, hauteur 0,633 — **elles reculent** |
| Le noir | min **0**, moyenne **2,46** — **vrai zéro, aucun voile** |
| Couture de boucle | **3,11** — elle boucle presque proprement |

**Trois conséquences dures :**

1. **⚠️ IL N'Y A PAS DE « PASSAGE DEVANT L'OBJECTIF ». LE SOMMET EST À
   L'IMAGE 68-72, ET C'EST LÀ QU'ON COUPE.** Mesuré et vu image par image : au
   sommet la pièce est frontale et emplit le cadre (aire 16 %) ; ensuite elle
   **tourne sur la tranche** (largeur 0,552 → 0,175 en six images, la hauteur
   tenant à 0,89) puis **rapetisse et s'éloigne** (aire 16 % → 4 %, hauteur
   0,94 → 0,63). Rien ne sort du cadre, rien ne passe devant.
   *Cette ligne a été écrite à l'envers dans la v2 de ce plan, sur la foi d'un
   juge, et annoncée à Kathryn comme la découverte principale. Elle était
   fausse : c'est la v1 qui avait raison. Voir §12.*
2. **Le film s'ouvre sur 1,15 s de temps mort** (images 0-27 : deux pièces
   minuscules et quasi immobiles, L 2,6). L'arrivée démarre donc à **l'image
   27**, sur **LA RUÉE** — elles font irruption, déjà grosses, en flou de
   mouvement. C'est une bien meilleure ouverture que 1,15 s de rien.
   *(La ruée est progressive sur 4 images, pas une coupe franche : les deltas
   montent 7,6 → 11,4 → 17,4. Un juge l'a lue comme un cut ; c'est un élan.)*
3. **Il ne peut pas remplir un portrait.** Au plus près la matière tient
   x ∈ [0,21 ; 0,75] ; un crop 9:19,5 ne garde que 23 % de la largeur et
   **coupe les deux pièces en deux**. Le film vit donc en **BANDE 16:9**.
4. **Ce film ne se POSE jamais** : aucune image où une pièce est immobile.
   L'atterrissage se **fabrique**, au sommet (§5.2).

### 1.2 `backgroundcoffre.mp4` — la chambre

| Grandeur | Mesure |
|---|---|
| Format | 2160 × 3840 (9:16 **portrait**), HEVC 10 bits, 24 i/s, 193 images, 8,04 s, 10,6 Mo |
| Mouvement | **0,61 / 255** de moyenne image à image (un juge indépendant mesure 0,27 — même ordre, même conclusion) : la vidéo est **quasi immobile** |
| Couture de boucle | **1,05** — elle boucle proprement, **aucun palindrome nécessaire** |
| Le quart haut | min **0**, moyenne **0,00**, p99 **0,00** — **VRAI ZÉRO ABSOLU** |
| Profil vertical | noir de 0 à 45 % · **barre néon à y/H = 0,494** · sol qui **plafonne à L 152** puis redescend à 143 |
| Étendue de la barre | x ∈ [0,169 ; 0,819] — elle a des **bouts visibles**, c'est un objet dans la pièce |
| ⚠️ Couleur de la barre (mesurée sur les **pixels clairs**, pas en moyenne de ligne) | cœur **(255, 255, 221)** *écrêté* · y−4 **(160, 0, 6) sat 1,00** · y+6 **(255, 139, 0) sat 1,00** · y+20 (255, 123, 34) · y+60 (255, 162, 139) · y+120 (196, 177, 177) |
| ⚠️ Le sol, en **saturation** | y/H 0,55 : L 121, **sat 0,72** · **0,63 : L 152, sat 0,23** · 0,70 : sat 0,07 · 0,80 : sat 0,02 · 0,95 : sat 0,01 |

**Conséquences :**
1. **Le noir du haut est à vrai zéro** → header noir, haut de card et haut de
   vidéo sont **le même noir**. Aucune couture possible entre le texte et la
   scène. C'est le cadeau de ce fichier.
2. **La vidéo ne bouge pas** → « l'activer » ne peut pas vouloir dire « la
   faire jouer » : ça ne se verrait pas. **Activer = allumer** (§2, Loi 1).
3. **Le sol est à L 152** → c'est lui qui rend le verre natif possible (Loi 4).
4. **⚠️ LA LAMPE EST UN NÉON ORANGE-ROUGE SATURÉ À CŒUR BRÛLÉ**, et la v2 de ce
   plan disait « chaud, **jamais saturé** » sur la foi d'une **moyenne de ligne
   polluée par le noir** — un artefact de ma propre sonde. La vérité :
   **sat 1,00** à quatre pixels du cœur. Et la rampe exhibe la loi maison de ce
   dépôt, celle de l'harmonisation rouge : **R reste à 255, c'est le VERT qui
   monte (0 → 139 → 162), et le BLEU reste à 0 sur 120 px**. Obéir à un beige
   (174,166,134), c'est fabriquer exactement le brun qu'on combat ici depuis
   des mois.
5. **⚠️ LE SOL SE DÉSATURE, ET LA PIÈCE EST POSÉE DANS SA ZONE TIÈDE.** Sat
   0,72 sous la barre, **0,23 à y/H 0,63** — la place de la pièce, soit
   RGB (178, 142, 137) : un gris chaud, c'est-à-dire la zone brune. À traiter
   au jalon C4 (le corps de la pièce et son ombre y répondent), pas à
   découvrir en capture.

---

## §2. LES CINQ LOIS DE LA PAGE

**Loi 1 — LA PIÈCE EST L'INTERRUPTEUR, ET L'INTERRUPTEUR EST MOMENTANÉ.**
La salle vit **tant que le doigt est posé**, et retombe quand il se lève.
*Pourquoi momentané :* un interrupteur qu'on ne bascule qu'une fois est un
**fusible** — c'est la seule interaction de la page, et elle s'épuiserait au
premier usage. Momentanée, la page retrouve son noir au repos, le geste est
rejouable à l'infini, et l'objet devient un vrai objet.

**Loi 2 — LE NOIR EST CONTINU.**
Un seul noir, mesuré à zéro, du haut de l'écran jusqu'à la barre. La card ne
« commence » pas : elle se révèle par sa lumière. Aucun liseré, aucun scrim,
aucune bordure ne doit trahir où elle démarre.

**Loi 3 — UNE SEULE LAMPE.**
La barre néon de la vidéo est l'unique source. Le verre la réfracte, la pièce
porte son ombre au sol, le compte prend sa chaleur. **Aucun halo maison.**
*Exception unique et nommée :* le croissant de la pièce, qui est sa propre
lumière — et qui n'éclaire que l'intérieur de sa silhouette.

**Loi 4 — LE VERRE A ENFIN DE QUOI VIVRE… QUAND LA LAMPE EST ALLUMÉE.**
Le dépôt porte la loi mesurée (`HomeNuit.swift:536-542`) : *« le `glassEffect`
natif ne marche pas sur les PETITS objets posés sur du noir […] `.clear` natif
reste souverain sur les GRANDES [surfaces] »*, et le galet de 56 pt fut retiré
parce qu'*« un objet qui est la chose la plus brillante de l'écran se lit
comme un AUTOCOLLANT »*. À **132 pt sur un sol à L 150**, on est loin de la
zone morte : **sa demande D8 est juste, et c'est cette page qui pouvait la
tenir.**
⚠️ **Corollaire, et c'est le piège de la Loi 1 :** salle éteinte, le verre n'a
RIEN. La pièce au repos ne peut donc pas compter sur lui — elle vit sur son
corps peint et sur son croissant (§6.4).

**Loi 5 — LE FILM NE MENT PAS SUR LE LIEU.**
Le film montre les pièces dans le noir ; la page les montre dans la chambre.
Le raccord ne se fait pas sur une coupe mais sur **ce que le passage laisse
derrière lui** (§5.2).

---

## §3. L'ANATOMIE CHIFFRÉE

Cotes pour un iPhone 17 Pro (402 × 874 pt).

### 3.1 La card — LE PATRON COMPLET, gestes compris

⚠️ **La v1 de ce plan ne recopiait que la géométrie.** `GrandeCardExos` ne fait
QUE le fond — le fichier le dit lui-même (`ExosFond.swift:167` : *« LA LEVÉE NE
VIT PLUS ICI »*). D4 demande un **comportement**, et il est déjà écrit.

**(a) La géométrie** — `GrandeCardExos` (`ExosFond.swift:103-174`), vérifiée
ligne à ligne par le juge technique :

| Cote | Valeur | Ligne |
|---|---|---|
| `margeHaut` | **10** | `:112` |
| `margeCote` | **0** | `:113` |
| `rayon` | **55** (4 coins) — loi concentrique : elle touche l'arête, donc rayon **d'écran** | `:119` |
| Forme | `UnevenRoundedRectangle(…, .continuous)`, **publiée** `static var forme` | `:124-130` |
| Corps | `Color.black` + overlay(`Color.clear`.overlay{ poster + vidéo }) | `:132-159` |
| Naissance | `.opacity(n)` · `.scaleEffect(1,015 − 0,015·n)` — jamais un bounce | `:163-164` |

**(b) Les gestes** — cinq pièces, dont **quatre `private` dans
`ExercisesView.swift`** : elles doivent être **promues ou recopiées**
(~120 lignes, à budgéter dans le jalon C2, pas en fin de parcours) :

| Pièce | Ligne | Rôle |
|---|---|---|
| `FormeCardExos` | `:238` | `Shape` **`Animatable`** sur `levee` + `haut` — la card se RACCOURCIT sans changer de frame |
| `CarteLevee` | `:269` (**private**) | `clipShape(FormeCardExos)` + `offset(y: max(tirage, 0))` |
| `MonteAvecLaCard` | `:282` (**private**) | ce qui remonte avec le bord bas — **un simple offset, aucune taille ne change** |
| `CadreCarte` | `:312` (**private**) | cadre le contenu DANS la forme de la card |
| `BandeExos` + `EclatLune` | `:992`, `:978` (**private**) | **LA BANDE DÉCOUVERTE, ET C'EST LÀ QUE VIT LA LUNE** |
| `EtatExos` | `:100` | `@Observable` — `tirage`, `levee`, `leveeDrag`, `luneP`, `luneHautP` |

**(c) ⚠️ LA LOI DE FLUIDITÉ** (`ExercisesView.swift:173-187`), que la v1
ignorait : `leveeFixe` a le droit de passer par un `frame` ; **`leveeDrag`
JAMAIS** — *« un `padding`/`frame` animé par image redimensionne
l'`AVPlayerLayer` ET re-layoute le ScrollView »*. Sans elle, on rejoue
littéralement « ça laggue quand on drag la card ».

### 3.2 La lune (D4) — elle a un nom, elle est greppable

**Aucune question à poser :** `LuneSecrete` (`HomeNuit.swift:1158`), dont le
commentaire dit *« Quand la grande card se SOULÈVE (tirage vers le HAUT), la
bande du BAS se découvre et le croissant de la marque s'y allume »*.

- Home : `luneP = (−tirage − 70) / 60`, posée `HomeNuit.swift:2171` sous
  *« LA LUNE — le secret d'aujourd'hui »*.
- Exos : **deux** exemplaires, bas et haut — `luneP = (−tirage − 62)/56`,
  `luneHautP = (tirage − 74)/50`, `ExercisesView.swift:1027-1033`.

**Ici : les deux**, comme les exos. Tirer vers le haut découvre la lune du bas ;
pousser vers le bas découvre celle du haut. C'est *exactement* « le même layout
que la home et exercice », au sens plein de sa phrase.

### 3.3 Le header (D7)

| Grandeur | Valeur home | Ici |
|---|---|---|
| Police / corps | Inter-**SemiBold 30** (`:315`, `:495`) | identique |
| Tracking | **−0,4** (`:316`) | identique |
| Interligne | VStack `spacing: 2` (`:321`) | identique |
| Ton clair | **1,00** (`:497`) | identique |
| Ton sourd | 0,42 → 0,54 **selon la lampe** (`:331`, `:336`, `:519-521`) | **constant 0,42** — obtenu **sans toucher `PhraseVue`** : poser `sourdLumiere = 0,42` neutralise le champ (`sourd + (sourdLumiere − sourd)·n`) |
| Masque d'argent | 1,00 → 0,90 (`:340`, `:446`) | identique |
| Marge gauche / haut | **24** (`:2384`) / **48 depuis la safe area** (`:2389`) | identique |
| Largeur de bloc | 300 (`:322`) | à re-mesurer sur 3 lignes |
| Lignes | 5 fragments | **3**, alternance clair / sourd / clair |

⚠️ **Trois accrocs réels que la v1 ne voyait pas :**
1. **La cascade n'est pas à 0,10 s.** La home est à `retard = 0,14` (`:348`) et
   `duree = 0,90` (`:350`) → 3 lignes = 2 × 0,14 + 0,90 = **1,18 s**.
   La v1 budgétait 0,50 s : **sous-dimensionné d'un facteur 2,4**.
2. **`duréeTotale = duree + 4·retard`** (`:365`) est **câblé sur 5 fragments**.
   À 3 lignes, la dernière finit à p ≈ 0,81 et il reste 19 % de rampe morte :
   il **faut** passer `duree`/`retard` — ce n'est donc pas « identique ».
3. **`PhraseVue` exige deux `@Binding`** (`objectif`, `reglageOuvert`,
   `:417-419`) et monte `ObjectifTouche` dès qu'un fragment porte un objectif.
   À fournir à vide ici.

⚠️ Le découpage en `VStack` de `Text` est **obligatoire** : *« SwiftUI ne sait
pas flouter ni décaler un RUN dans un paragraphe qui se replie »*.
⚠️ `PhraseVue` est `Animatable` : des rampes échelonnées sous un `@State` +
`withAnimation` **ne jouent qu'au doigt** (piège payé).

*Note de langue :* sa maquette écrit « Find what, your worked for. » — la forme
juste est « **Find what you worked for.** ». Et la **3ᵉ ligne devient l'invite**
(§4.2).

### 3.4 La pièce
- Diamètre **132 pt** (rayon 66) — 33 % de la largeur de card, mesuré sur sa
  maquette.
- ⚠️ L'hôte du shader `moonCoin` fait **3,4 rayons (224 pt)** : gabarit
  `Color.clear` + overlay obligatoire, sinon **il impose sa taille** (débord de
  138 pt mesuré sur l'ancienne page).
- Centre à **y ≈ 0,63 × H ≈ 544 pt** — posée *sur* le sol, jamais flottante :
  **son ombre portée est ce qui la pose** (Loi 3).

### 3.5 Le compte — ⚠️ LA PASTILLE MEURT
La v1 gardait `TresorPastille` / `BravoPillView`. **Trois raisons de la tuer :**
1. Elle fabrique **trois objets ronds sur le même axe vertical** (le palet, la
   mini-pièce DANS la pastille, la pièce du manège) — c'est l'échec
   « autocollant » à l'échelle de la page.
2. Son **fil d'or 0,7 pt** et la respiration de son néon sont une **deuxième
   source de lumière** avec ses propres règles → viol frontal de la Loi 3.
3. Loi maison : *chaque chose se dit une fois*. La page a pour sujet **une
   pièce** ; lui coller dessous un second objet rond qui dit « argent » est une
   redite.

**Le nombre devient la LÉGENDE de la pièce** : une ligne sous elle, dans le
système typographique de la phrase, **ton sourd 0,42, sans conteneur**. Un
grand chiffre, un petit mot. C'est la seule chose autorisée à prendre la
chaleur quand la salle s'allume.

---

## §4. LE MANÈGE DES DEUX PIÈCES (D6) ET L'INVITE

### 4.1 La loi du manège, déjà validée ailleurs
La loi cover-flow du CHEMIN DE FEU (validée par elle : « trop beau on y
arrive »), transposée en horizontal. `u` = l'avancement entre deux crans :

| Grandeur | Formule | Rôle |
|---|---|---|
| Rotation | `sin(2π·u) × 16°`, axe **(0,1,0)**, perspective 0,6 | ⚠️ **SIGNÉE**. Un `sin(π·u)` symétrique est **invisible par construction** — piège payé, elle l'a réclamé dix fois avant que ça rentre. |
| Flou / nuit | `\|sin(2π·u)\|` | ⚠️ **zéro aux DEUX poses ET AU MILIEU** ; il pique aux **quarts** (u = 0,25 et 0,75) |
| Échelle | `1 + 0,20·sin(π·u)` | le « gros zoom puis dézoom » |

⚠️ **LA V2 DE CE PLAN LISAIT CE FLOU À L'ENVERS** (« monte au milieu du
voyage »). La source dit le contraire, mot pour mot
(`DuolinguoPage.swift:468-470`) : *« floue/sombre à l'APPROCHE, **NETTE face
caméra au centre** (le moment de présentation), floue au départ, nette
posée »*. Le voyage a donc **trois** temps nets — la pose de départ, **la
présentation au centre**, la pose d'arrivée — et deux temps flous entre eux.
C'est mieux que ce que j'avais écrit : la deuxième pièce ne « naît pas du
flou », elle **se présente nette à mi-chemin**, puis se refloute avant de se
poser. C'est ça, la chorégraphie qu'elle a validée au CHEMIN DE FEU.

⚠️ **ET DEUX MÉCANISMES DE CE TABLEAU SONT INTERDITS SUR DU VERRE NATIF** —
c'est le vrai problème du manège, voir §6.3 : ni `scaleEffect`, ni `.blur`.
La forme du manège est donc **à trancher au banc C5**, pas ici.

### 4.2 L'invite — sans quoi la page est un écran mort
À la fin de l'arrivée, plus rien ne bouge jusqu'au doigt, et l'objet censé
inviter est **à son état le plus pauvre** (salle éteinte = verre vide). Trois
signaux, aucun ne viole les Lois 2 et 3 :

1. **La braise du croissant.** Une respiration très lente de **l'émission de la
   ligne seule** — période 4,5 à 5,5 s, plafond sous L 90. **Aucun pixel hors
   de la silhouette ne change.** (`moonCoin` a déjà `breath` et `idleLife`.)
2. **La pièce arrive VIVANTE.** Au raccord, elle garde une **rotation
   résiduelle amortie sur ~1,2 s**, comme une pièce lancée qui s'immobilise.
   Une chose qui vient de s'arrêter reste touchable à l'œil plusieurs secondes.
3. **Le mot invite, pas la lumière.** La **3ᵉ ligne de la phrase EST le signal**
   (« Touch it. »). Coût : zéro pixel de lumière. Elle meurt dès qu'on lui
   obéit. C'est le geste Apple : la pièce reste noire, **c'est le texte qui
   invite**.

### 4.3 Ce qui reste à trancher
**Ce qui sépare l'or de la noire n'est pas dit** (question ②). Recommandation :
**l'or = les pièces gagnées** (le compte d'aujourd'hui) · **la noire = celles à
gagner** (le prochain palier, la prochaine lune du chemin).

---

## §5. LA PARTITION DE L'ARRIVÉE (D1 + D2)

### 5.1 Ce que la v1 avait faux
Elle coupait à l'image 70 et se félicitait de raccourcir l'arrivée de 6,85 s à
3,6 s. **Trois substitutions non demandées** : le passage jeté, le
raccourcissement inventé, et la présence à l'écran qui tombe de `slotRatio 0,40`
+ `zoom 2,15` à **226 pt sur 874, soit 26 %** — le seul chiffre qui tranchait
était le seul absent.

### 5.2 La partition v3 — on entre sur la ruée, on coupe au sommet

| t (s) | Image | Ce qui se passe |
|---|---|---|
| 0,00 | 27 | Page **noire absolue**, salle ÉTEINTE. Le film s'ouvre **sur LA RUÉE** — les pièces font irruption, déjà grosses, en flou de mouvement. Les 1,15 s de temps mort du fichier sont **coupées à la cuisson** (§1.1 conséquence 2). |
| 0,00 → 0,17 | 27→31 | La ruée : largeur 0,169 → 0,394. |
| 0,17 → 1,79 | 31→70 | Elles culbutent, tournent, grossissent jusqu'au **SOMMET** : 0,552, frontale, aire 16 %. |
| **1,79** | **70** | **LA COUPE, AU SOMMET.** La bande s'éteint (0,22 s) et **la pièce de la page prend sa place** : elle naît **au lacet exact de l'image 70**, à l'échelle qu'elle y avait, et se pose (0,55 s, `easeOut`) — **rotation résiduelle amortie sur 1,2 s** (§4.2). |
| 2,00 → 3,18 | — | La phrase s'écrit, **1,18 s** (`retard 0,14`, `duree 0,90`). |
| 3,18 | — | La légende du compte naît. |
| ∞ | — | Salle **ÉTEINTE**. La pièce respire (§4.2). **On attend le doigt.** |

**Total 3,18 s** contre 6,85 s aujourd'hui. ⚠️ **Le raccourcissement n'est pas
un but** (elle ne l'a jamais demandé) : il tombe de ce qu'on garde — la ruée et
la montée au sommet — et de ce qu'on jette, qui n'est que le temps mort du
fichier et le recul d'après-sommet. Si elle veut plus long, on rallonge la pose
et la phrase, jamais en réintroduisant les 1,15 s de rien.

### 5.3 ⚠️ LA RÈGLE DE PLACEMENT QUE LA V1 N'AVAIT PAS
Le plan v1 ne disait **jamais où la bande 16:9 se pose verticalement**. Or le
centre de la pièce à l'image de coupe **n'est pas** le centre de la bande, et sa
place au sol est y ≈ 544 pt. Selon le placement, elle devrait descendre ~100 pt
**en plus** de rétrécir — et ça se verrait.

> **On aligne le CENTRE DE LA PIÈCE, pas le centre de la bande.** Le cadre du
> film se calcule **à l'envers**, depuis le centroïde de la pièce à l'image de
> coupe, pour que le raccord soit une **pose** et pas un déplacement.

Et il faut **vérifier** que `CinematicPlayer` ne recadre pas :
`videoGravity = .resizeAspect` est **codé en dur** (`:105`) — valable seulement
si le cadre a le ratio exact du fichier. On le mesure, on ne l'hérite pas.

### 5.4 Le raccourci (D2) — et les deux trous de la v1
Le mécanisme se réécrit **comme une fonction du temps** (une seule horloge —
une chaîne d'`asyncAfter` fait une marche par réveil, leçon payée trois fois),
donc passer devant = **avancer le curseur à T**.

⚠️ **Trou 1 — la surface tapable.** Aujourd'hui elle est bornée au bloc vidéo
(`Color.clear.frame(height: H · slotRatio).onTapGesture(perform: skip)`,
`:176-179`). « Le même comportement » porte aussi là-dessus : **la surface du
raccourci est la bande du film, et rien d'autre**.

⚠️ **Trou 2 — la collision de sémantique.** La pièce naît à 3,29 s, l'arrivée
finit à 4,68 s. Dans cette fenêtre, un doigt sur la pièce **passe l'animation**
ou **allume la salle** ? Arbitrage : **tant que l'arrivée n'est pas finie, la
pièce n'écoute pas** ; seule la bande écoute, et elle passe devant. La pièce
prend le doigt à T.

---

## §6. LE VERRE NATIF DES PIÈCES (D8)

### 6.1 Le patron de référence existe déjà
`GaletEtape.swift:395-430` et `:590-640` — corps peint DOUX dessous
(`RadialGradient` nacre + ellipse spéculaire floutée), `Circle().fill(.clear)
.glassEffect(.clear, in: Circle())`, **encre AU-DESSUS**, sur des galets de
82-104 pt. **L'ordre en trois couches est conforme.**

### 6.2 Les trois couches, corrigées
1. **Dessous — LE CORPS PEINT.** `moonCoin`, `matte: 0` (or) / `matte: 1`
   (anthracite — dont j'ai **neutralisé la laque aujourd'hui**, commit
   `bafc9c5` : le brun 15:7:2 est mort).
   ⚠️ **ET `reveal: 0`.** `moonCoin` **peint le croissant lui-même**
   (`MoonCoin.metal:445-453`) : laissé allumé, il serait **lentillé** sous le
   verre (les fantômes) *et* repeint net par-dessus — **le croissant deux
   fois**. `reveal: 0` l'éteint dans le shader. La v1 ne le disait nulle part.
2. **LE VERRE.** `.clear`, jamais `.regular` (interdit par la loi maison),
   nourri par le corps peint **et** par le sol à travers la card.
3. **Dessus — LE CROISSANT.** Peint au-dessus du verre.
   ⚠️ **Une encre DANS un conteneur de verre est lentillée** (fantômes).

### 6.3 ⚠️ Les pièges qui vont mordre

**⚠️⚠️ LE PLUS GRAVE, ET LA V2 L'AVAIT ÉCRIT À L'ENVERS : LE MANÈGE ET LE VERRE
NATIF SONT INCOMPATIBLES EN L'ÉTAT.** Deux précédents mesurés, tous deux
verbatim dans le dépôt :

- **Pas de `scaleEffect`** — `PorteEntree.swift:1274-1277` : *« ⚠️ **AUCUN
  `scaleEffect` ICI NON PLUS** — un `glassEffect` mis à l'échelle rend un BLUR
  PLAT, il cesse de lire comme du verre. **La cote passe donc dans le
  `frame`** »*. La v2 prescrivait exactement l'inverse (« transforms sur le
  groupe composé, jamais le frame »). C'est faux : pour le verre, **la taille
  passe par le `frame`**, et une taille qui bouge **par image** est de toute
  façon le piège des bounds vivants (`MenuCouronne.swift:35-36` : *« LE DISQUE
  EST MONTÉ À TAILLE CONSTANTE, révélé par un masque — un `glassEffect` aux
  bounds vivants reste flou plat pour toujours »*).
- **Pas de `.blur`** — `MenuCouronne.swift:32-33` : *« ⚠️ Et jamais un
  `.blur` : il pose un voile uniforme sur tout le rectangle de son hôte, **il
  ne sait pas s'arrêter en rond** »*. Sur une pièce RONDE de 132 pt, le flou du
  manège poserait un **voile carré**.

→ **Le zoom `1 + 0,20·sin` et le flou `|sin(2πu)|` du §4.1 ne peuvent pas
s'appliquer à une pièce en verre natif.** Trois issues, à trancher au banc C5 :
 **(a) LE RETOURNEMENT** — une seule pièce qui se **retourne** (or d'un côté,
 noire de l'autre) : plus de voyage, donc ni zoom ni flou à faire, et c'est la
 grammaire naturelle d'une pièce ; **(b)** garder deux pièces et **remplacer le
 flou par la nuit** (une opacité noire, qui n'a pas de forme) et le zoom par
 un `frame` à valeurs discrètes ; **(c)** le plan B sprite (§6.4), qui rend
 zoom et flou légitimes puisqu'il n'y a plus de verre.
 *Recommandation : (a).* Elle a demandé « deux types de pièces » et un scroll,
 pas nécessairement deux objets simultanés — et un retournement **est** un
 scroll droite-gauche.

**Les autres :**
- **Le verre aux bounds vivants** : taille constante, révélée par un masque.
- **Le verre natif ignore `.opacity`** : pour le faire disparaître pendant le
  film, il faut le **DÉMONTER**, avec un verrou à une bascule par cycle
  (`HomeNuit.swift:2434-2443`, `verreMonte`).
- **⚠️ `.environment(\.colorScheme, .dark)` N'EST PAS le remède au blanc
  laiteux — et ici c'est un NO-OP** : l'app est déjà `.preferredColorScheme(.dark)`
  (`WoopApp.swift:64`). La v1 citait le bon piège et le mauvais remède. **Les
  vrais remèdes sont nommés dans le code** (`CalLab.swift:3181`) : le **masque
  d'ANNEAU** (le verre ne vit que sur la bande) et **la NUIT posée dessus**
  (`Circle().fill(.black.opacity(0,46))`) — plus la **teinte noire** d'`ArcKnob`
  (`.regular.tint(black 0,38)`, choisie parce qu'*« à 0,20 il buvait la flamme
  et rendait un galet blanc laiteux »*).
- **⚠️ `.clear` = contenu DOUX seulement.** Sous le verre il y aura la vidéo
  (doux ✓) **et** `moonCoin`, qui est NET (liseré `rimIn = 0,946`, tube à
  plancher 0,85 pt). C'est exactement le cas où la loi affinée du dépôt dit
  **`liquidLens`**, pas `.clear`. → **C4 teste les deux.**

### 6.3 bis ⚠️ LE SHADER DE VERRE A ÉCHOUÉ — ET C'EST MESURÉ (25-08)

Verdict de Kathryn sur la première pièce montrée : *« c'est pas liquid glass, faut
que tu travailles »*, puis, devant le second jet : *« c'est quoi cette horreur ».*
Elle avait raison les deux fois.

**Ce que l'objet est vraiment.** Sa référence n'est pas une pièce de métal :
c'est un **cabochon de verre transparent** avec un disque noir suspendu dedans.
Mesuré sur son rendu 4K natif (`tools/coffre-v2/refs/piece-ref-4k.png`,
profil par `compare_piece.py`) :

| Zone | Mesure |
|---|---|
| L'ellipse | ratio h/w **0,902** → un **TANGAGE** de 25,6°, pas un lacet |
| La face | r/R 0 → 0,62 · **52 % de ses pixels sous L 3**, médiane **2,7** |
| Le tore | r/R 0,65 → 1,03 · **45 % de ses pixels sous L 10**, médiane **14**, moyenne 51, p90 183 |
| Les arcs | ★ 0,77 (dominé par le HAUT, 105/66) · gorge 0,91 · ★ 0,95 (dominé par le BAS, 66/50) |
| La teinte | verre **neutre** (sat 0,01-0,04) · or **ambre en demi-teintes** (sat 0,30-0,47), pics au blanc dans les deux cas |

**Les trois lois que ça donne** (elles restent vraies quelle que soit la
technique retenue) :
1. **LE VERRE EST NOIR.** La moitié du bourrelet laisse passer le fond ; sa
   moyenne de 51 ne vient que des 12 % de pixels très clairs — de **fines
   lignes**. Rien ne doit être constant sur l'anneau.
2. **LA FACE EST UN TROU NOIR** (médiane 2,7). Sa saturation de 0,75 ne dit pas
   qu'elle baigne dans l'orange : elle dit que le PEU qui s'y trouve est orange.
3. **DEUX SOURCES, PAS UNE.** Les deux arcs viennent de lampes différentes.

**Le score, tour par tour** (`compare_piece.py`, note sur 10) :

| Tour | Ce qui a été corrigé | Note |
|---|---|---|
| 1 | le premier jet | **2,66** |
| 2 | le tangage (je rendais un CERCLE, ratio 1,018) | **3,93** |
| 3 | le tore rendu transparent (base retirée), la face rendue noire, le bain court | **5,18** |

**La décision : ON ARRÊTE LE SHADER.** Trois tours pour +2,5 points ; il en
faudrait dix de plus pour espérer 8, et **9,8 est hors de portée d'un shader
analytique face à un rendu ray-tracé**. Le verre est le pire cas : sa beauté
EST la transparence, la réfraction et les caustiques internes — c'est
littéralement ce pour quoi le ray tracing existe.

**LA VOIE RETENUE (proposée par Kathryn le 25-08 : « si c'est plus simple que
je gère des images et que tu les utilises »)** : **ses rendus deviennent les
pièces.** C'est déjà l'école de la maison — la pilule de la home v2 EST une
vidéo, et c'est ce qui la rend belle.

**⚠️ ET ÇA DÉBLOQUE LE MANÈGE.** Tout le §6.3 (pas de `scaleEffect`, pas de
`.blur`) ne vaut que pour le **verre natif**. Sur une IMAGE, le zoom et le
flou redeviennent parfaitement légitimes. **Le retournement n'est donc plus une
nécessité technique** — on peut revenir à ce qu'elle avait demandé au départ :
un manège horizontal entre deux pièces, avec le flou de mise au point (§4.1).

**Ce qui est PERDU, et il faut le dire** : une image ne réfracte pas la salle
en direct. L'idée « la pièce lentille le sol éclairé » (Loi 4) devient un effet
CUIT, pas vivant. C'est un vrai renoncement, et il est acceptable : la beauté
de l'objet passe avant la physique de sa lumière.

**Ce qui SURVIT du travail jeté** :
- `tools/coffre-v2/compare_piece.py` — l'instrument. Il servira à vérifier que
  les images livrées sont cadrées et exposées pareil d'une pièce à l'autre.
- `tools/coffre-v2/refs/piece-verre.json` / `piece-or.json` — le profil radial
  de référence, la définition chiffrée de l'objet.
- `Woop/PieceVerre.metal` + le banc `-pieceCalibre` : **gardés, pas appelés**.
  Ils portent la spec mesurée ; si un jour une pièce doit être générée (une
  couleur inédite, une pièce d'or « parfaite »), c'est de là qu'on repart.

### 6.4 Le vrai risque, nommé
Le juge de design le pose sans détour : couper d'un **palet ray-tracé** (liseré
L 179-255, laque noire, croissant émissif) vers un `moonCoin` + verre **posé sur
une salle éteinte, donc sur rien**, c'est remplacer l'objet héros par **un
disque terne**. Aucune courbe ne rattrape ça.

**Les trois remèdes, cumulés :**
1. Le corps peint dessous porte la pièce quand le verre n'a rien (Loi 4,
   corollaire) ;
2. le croissant respire (§4.2.1) — c'est sa propre lumière, elle ne dépend pas
   de la salle ;
3. la rotation résiduelle (§4.2.2) : un objet qui finit de tourner est vivant
   même mat.

**Et le plan B, s'il faut le sortir** : la pièce du film découpée en sprite
(l'école de la home v2, où la pilule EST une vidéo). **A/B au banc en C4** —
je monte le verre, le sprite n'existe que si le verre échoue.

---

## §7. L'ARCHIVE — ⚠️ TROIS EXTRACTIONS BLOQUANTES, PAS UNE

La v1 n'en voyait qu'une. Remplacer le fichier sans les trois **casse huit
compilations**.

| Ce qui sort | Sites externes | Conséquence si oublié |
|---|---|---|
| **`CoffreFortPurse`** (`:13-20`, `perSeries = 20`) — la **seule** définition de l'économie | **5** : `HomeAuroraView:246`, `HomeNuit:2059`, `ProfilLune:114`, `BravoLab:642`, `SetHistoryRow:23` | 5 compilations mortes |
| **`CinematicPlayer` + `CinematicPlayerHost`** (`:76-115`) | **5** : `StoryVideo:77`, `StoryVideo:81`, `BravoLab:528`, `BravoLab:531`, `BravoLab:566` | **StoryVideo et BravoLab morts** |
| **`CoffreFortFlow(coins:onClose:)`** (`:561`) — le point d'entrée public. **TRANCHÉ 25-08 : il survit en ENVELOPPE MINCE à signature identique** (le pager meurt, pas la porte) | **4** : `HomeNuit:2056`, `HomeAuroraView:243`, `ProfilLune:280`, `WoopApp:512` | **3 pages ne s'ouvrent plus** |

**Le reste :**
- `CoinSmoke` / `CoinSmokeWarm` : **déjà dehors** (`CoffreFortCoin.swift`).
- Le chevron : `ChipVerre` + **la cote** `leading 20` / `top safeTop + 4`.
  ⚠️ Un `padding(.top, 16)` le pose **46 pt trop haut, dans l'îlot** (mesuré,
  verbatim dans le code `:399-402`).
- `TresorPastille` : **morte** (§3.5).
- `CoffreFortCine` : morte (partition recalée sur `coffre-beau`, qui disparaît).
- `HaloDawnLab` **est** la page démon. **TRANCHÉ 25-08 : le pager meurt** — elle
  n'est plus atteignable depuis le coffre, mais **elle n'est pas supprimée**
  (son banc la monte toujours). On ne détruit pas une page qu'on n'a pas été
  chargé de détruire.
- `coffre-beau.mp4` : retiré du paquet (6,2 Mo rendus) après validation.

**Où va l'archive** : `tools/coffre-v2/ARCHIVE/` — le fichier complet, une
capture pleine page, la partition chiffrée, et `ARCHIVE.md`. **La v1 doit
rester rejouable** (règle maison, payée sur la home v1).

---

## §8. LES JALONS

Un jalon par échange, une capture archivée dans `tools/coffre-v2/shots/`.

| # | Jalon | Banc | Ce qu'on juge |
|---|---|---|---|
| **C0** | **Les 3 extractions + l'archive** | — | rien ne casse ; la v1 rejouable |
| **C1** | **Les deux cuissons** : `coffre-piece-arrivee` (bande 16:9, **images 27 → 71 seulement** — la ruée puis la montée au sommet, le temps mort et le recul jetés, crush du noir, fondu de bords) + `coffre-salle-loop` (portrait 540×1174, boucle simple) + les deux posters | `-coffreMedia` | poids, couture, noir à zéro, **aucun glitch noir au sim** |
| **C2** | **LA CARD ET SES GESTES** — la géométrie **+ la promotion des 5 pièces privées** + la loi de fluidité + **les deux lunes** | `-coffre2`, `-coffreTirage` | ça drague sans lag ; la lune apparaît ; on ne voit pas où la card commence |
| **C3** | **L'ALLUMAGE MOMENTANÉ** : la salle vit sous le doigt et retombe | `-coffreAllume` | une lampe qui s'allume, jamais un fondu d'image — **et la retombée** |
| **C4** | **LA PIÈCE** : 3 couches, `reveal: 0`, **A/B `.clear` vs `liquidLens`**, et le plan B sprite si échec | `-coffrePiece`, `-coffreVerreAB` | « on voit leur beauté » — ou l'autocollant |
| **C5** | **LE MANÈGE — ET SA FORME EST À TRANCHER** : (a) le retournement d'une seule pièce *(reco)*, (b) deux pièces avec la nuit au lieu du flou, (c) le sprite. Le verre natif interdit `scaleEffect` et `.blur` (§6.3) | `-coffreManege`, `-coffreManegeAuto` | la présentation **nette au centre**, les poses nettes, rien de carré sur un objet rond |
| **C6** | **L'ARRIVÉE** : le film entier + le raccord **aligné sur le centroïde** + le raccourci + l'arbitrage du tap | `-coffreSkip`, `-coffreArrivee` | le raccord : **une pose, pas un déplacement** |
| **C7** | **LA PHRASE ET LA LÉGENDE** : 3 lignes, cascade 1,18 s, `sourdLumiere = 0,42`, l'invite | `-coffrePhrase` | la hiérarchie : la pièce d'abord |
| **C8** | **L'INVITE** : braise du croissant + rotation résiduelle | `-coffreInvite` | est-ce vivant sans rien allumer ? |
| **C9** | **LE FOUETTAGE** : films 2 vitesses, détecteur de flash, sonde de cadence, Reduce Motion, allers-retours | `-coffreAuto` | **rien ne se montre sans être filmé** |
| **C10** | **LE TÉLÉPHONE** : OLED, haptiques, chauffe, gyro | appareil | le verdict qui compte |

**Simulateur dédié** : `kat-coffre` + `dd-coffre/`. On committe **par chemins**
(les sessions parallèles touchent les mêmes fichiers).

---

## §9. LES PIÈGES CONNUS QUI VONT MORDRE ICI

1. **`aspectRatio(.fill)` ne prend pas la taille proposée** → hôte
   `Color.clear` de taille neutre, sinon la card se pose à 2,3 pt du bord au
   lieu de 10.
2. **`resizeAspectFill` déborde ses bornes** — `clipsToBounds` **et**
   `masksToBounds`, le `clipShape` SwiftUI ne rattrape pas UIKit.
3. **Le glitch noir du simulateur** : décodeur logiciel. Remèdes cumulés :
   sortie **540×1174**, **image de pose** sous une couche vidéo **transparente**
   (jamais noire), preroll. ⚠️ `AVPlayer.preroll` **lève une exception** tant
   que `status != readyToPlay`.
4. **`AVPlayerLooper`, jamais un seek sur `didPlayToEndTime`** ; looper
   **retenu** par le coordinateur.
5. **Le `rate` 0 → 1 en plein geste vide la couche** → pré-réveil.
6. **`ignoresSafeArea` sur un `GeometryReader`** lui fait rendre une encoche de
   **ZÉRO** — seul le défilement fuit, jamais le proxy qui mesure.
7. **Une seule sonde de scroll** : une sonde qui rend une constante ne rappelle
   plus jamais.
8. **Le double `withAnimation`** sur la même valeur au même tour = RIEN.
9. **`.blur` laisse son calque** : le flou vit sur les **glyphes** ou sur le
   **contenu qui passe dessous**.
10. **La page ré-évaluée par image** : aucun `@State` écrit par image sur la vue
    qui porte tout.
11. **`xcodebuild | grep` rend le code de grep** → **`stat` du binaire avant
    chaque capture**.

---

## §10. LES QUESTIONS FERMÉES

Trois. La question « c'est quoi la lune ? » de la v1 a été **supprimée** : la
réponse était greppable (§3.2).

**① L'interrupteur est-il MOMENTANÉ ?** La salle s'allume tant que ton doigt
est posé sur la pièce, et **retombe quand tu le lèves** — au lieu de rester
allumée pour toujours. ***Recommandé : OUI, momentané.*** Restée allumée, c'est
un fusible : la seule interaction de la page s'épuise au premier usage.
⚠️ Et il faut la règle qui va avec (à mesurer en C3) : **la pièce garde un
pourtour sombre quand la salle s'allume**. Sinon son croissant (L 86) s'inverse
contre un sol à L 152 — il devient une rainure plus sombre que son fond — et le
liseré spéculaire, qui ne brillait que contre du noir, s'aplatit. **L'unique
interaction de la page serait destructrice pour son sujet.**

**② L'or et la noire — qu'est-ce qui les sépare ?** Recommandation :
**l'or = les pièces gagnées** (ton compte) · **la noire = celles à gagner** (le
prochain palier, la prochaine lune du chemin).

**③ ~~La page démon~~ — TRANCHÉ le 25-08 : « la page démon aussi, plus besoin
là ».** Le pager vertical MEURT, et avec lui la seule chose qui disputait le
drag vertical à la levée de card. Conséquences, toutes bonnes :
- `CoffreFortFlow` **survit en enveloppe mince, à signature identique**
  (`coins:onClose:`) — les 4 sites d'appel ne bougent pas d'une ligne — mais
  son `ScrollView` paginé, son `LazyVStack` et son `containerRelativeFrame`
  disparaissent ; il ne présente plus qu'une page.
- `HaloDawnLab` n'est plus atteignable depuis le coffre. **Elle n'est pas
  supprimée** (son banc la monte toujours) : on ne détruit pas une page qu'on
  n'a pas été chargé de détruire.
- Le drag vertical est **entièrement libre** pour la levée de card et les deux
  lunes (§3.2). C'était la condition de D4.
- Le `GeometryReader` qui mesurait `safeTop` pour le pager reste nécessaire au
  chevron. ⚠️ Et il ne doit **toujours pas** porter `ignoresSafeArea` (§9.6).

**Nouvelle question ③ — LA FORME DU MANÈGE.** Le verre natif interdit le zoom
et le flou (§6.3). Ma reco : **une seule pièce qui se RETOURNE** — l'or d'un
côté, la noire de l'autre, le scroll droite-gauche la fait tourner. **Ou tu
tiens à voir les deux pièces côte à côte ?**

---

## §10 bis. CE QUE KATHRYN DOIT LIVRER (les images des pièces)

Décidé le 25-08 après l'échec du shader (§6.3 bis). **Format, cadrage et
exposition comptent autant que le rendu** — l'instrument `compare_piece.py`
vérifiera que les deux pièces sont jumelles.

### Le minimum, qui débloque tout
**DEUX images, une par pièce** — la sombre (verre) et l'ambre (or) :

| Critère | Exigence | Pourquoi |
|---|---|---|
| Fond | **noir pur (0,0,0)** ou transparent | tout autre fond laisse un halo carré au compositing |
| Cadrage | la pièce **centrée**, la même marge autour des deux | le manège compare deux objets : un décalage de 2 % se lit comme un saut |
| Pose | **la même inclinaison pour les deux**, celle de sa référence (ellipse h/w ≈ 0,90) | c'est la pose qu'elle a validée, et elle n'a pas besoin d'être tournée ensuite |
| Taille | **≥ 1400 px de côté**, carré | la pièce fait 132 pt à l'écran, soit 396 px en 3× ; la marge sert au zoom du manège |
| Format | **PNG** (16 bits si possible) | le dégradé du tore descend à L 2-14 : un JPEG y fabrique des blocs |
| Lumière | **identique sur les deux** | sinon l'une paraît plus « allumée » que l'autre au passage |

### ★ LA VOIE PREMIUM — LE TOUR DE MANÈGE (proposée par Kathryn, 25-08)

> « la pièce peut se tourner de droite à gauche, ou je génère une vidéo qu'on
> manipule au scroll/drag ? » — « et la vidéo elle tourne sur elle-même en
> entier, tu captes ? »

**Oui, et c'est LA solution.** Le doigt choisit l'angle, chaque angle est un
VRAI rendu ray-tracé : c'est la mécanique des pages produit d'Apple, et c'est
le seul chemin vers le « premium » qu'aucun shader ne donnera ici.

**⚠️ MAIS ON NE SEEKE PAS DANS UNE VIDÉO — c'est déjà mesuré et mort dans ce
dépôt.** `DepartCine.swift:15-26`, trois mesures indépendantes :
> *« `home-fond-loop.mp4` = 859 images, 72 clés (GOP 11,9). Le geste demandait
> **4 295 img/s** et 360 franchissements de clé par seconde, à tolérance ZÉRO.
> AVPlayer en sert **15 à 25** : on voyait **QUATRE images sur 859**. »*

Un doigt qui tourne une pièce demande exactement ce régime-là. Un `seek` par
image ne le tiendra jamais.

**LA FORME JUSTE : elle livre une VIDÉO, je la coupe en IMAGES.**
La vidéo est son format de travail — elle n'a pas à s'en occuper. À la cuisson
(`recuit_coffre.sh`, jalon C1) le film devient une **planche de sprites** : une
seule texture, chargée une fois, et le doigt ne fait plus que choisir une case.
Zéro décodeur, zéro seek, réponse à l'image près.

**Ce qu'il faut dans le film :**

| Critère | Exigence | Pourquoi |
|---|---|---|
| Le tour | la pièce tourne sur son **axe vertical** (droite-gauche), **360° complet** | 360° ramène à la face de départ : la boucle est parfaite par construction |
| ⚠️ La vitesse | **STRICTEMENT LINÉAIRE — aucun ease-in/ease-out** | c'est **le doigt** qui fait la courbe ; un ralenti cuit dans le film rend le geste collant sur les bords et glissant au milieu |
| Les images | **96 à 144 pour le tour** (2,5° à 3,75° par image) | en dessous on voit les crans à la rotation lente |
| Cadrage | **absolument constant** : même taille, même centre, du début à la fin | la moindre dérive se lit comme un tremblement sous le doigt |
| Lumière | **fixe dans la scène**, pas attachée à la pièce | c'est la lumière qui doit balayer l'objet quand il tourne — sinon il a l'air peint |
| Fond | **noir pur** | tout autre fond laisse une boîte au compositing |
| Taille | **1000 à 1400 px de côté**, carré | affiché à ~400 px : c'est déjà large |

**Les deux faces, et c'est le seul choix qui reste :**
- **(a) UNE pièce, deux faces** — l'or d'un côté, la sombre de l'autre. Le tour
  de 360° donne alors TOUT : face or → tranche → face sombre → tranche → or.
  Un seul film, et le manège de droite à gauche EST le retournement.
  ***C'est ma recommandation.***
- **(b) DEUX pièces séparées**, comme dans son film actuel → deux tours de
  manège, et le scroll passe de l'une à l'autre.

**Ce que ça change pour la page** : le §4.1 (rotation `sin(2πu)`, flou, zoom)
devient inutile pour la pièce elle-même — **la rotation n'est plus simulée,
elle est RÉELLE**. Le flou et le zoom du manège restent disponibles (ce sont
des images, pas du verre natif) mais ne servent plus qu'à la mise au point du
voyage, si elle en veut.

### Ce qui n'est PAS nécessaire
Ni image de la tranche, ni version « allumée » par la salle, ni fond : la page
fournit la chambre. Une pièce, deux fois, c'est tout.

---

## §11. CE QUI N'EST PAS ENCORE CHIFFRÉ (dette assumée)

Le juge de design a raison sur un point : *« la meilleure idée de la page
n'engage aucune grandeur »*. Trois choses sont à mesurer au banc C3, pas à
décider ici :
- **la durée de l'allumage** (montée) et **de la retombée** — une lampe monte
  vite et retombe lentement, jamais l'inverse ;
- **le délai au doigt** — combien de ms entre le contact et la première lueur ;
- **la luminance cible du sol** à l'écran une fois la card composée (la source
  est à L 150 ; ce qui compte est ce qu'on lit après composition).

---

## §12. CE QUE LES JUGES ONT CASSÉ DANS LA V1

Gardé pour ne pas le repayer.

| # | Le défaut | La correction |
|---|---|---|
| 1 | **Le passage du film jeté** (coupe à l'image 70) et l'arrivée raccourcie sans qu'on l'ait demandé | Le cycle entier se joue, passage compris (§5.2) |
| 2 | **D4 esquivée** : « le patron à la lettre » = 6 cotes statiques, **zéro geste**, et `CarteLevee` jamais nommé | §3.1(b) : les 5 pièces privées à promouvoir + la loi de fluidité |
| 3 | **« On voit la lune » posé en question** alors que la réponse est **greppable** (`LuneSecrete`) | §3.2, question supprimée |
| 4 | **La cascade à 0,10 s** — la home est à `retard 0,14` / `duree 0,90` → **1,18 s** | §3.3, partition rebudgétée |
| 5 | **`duréeTotale` câblé sur 5 fragments** | §3.3 : passer `duree`/`retard` |
| 6 | **`.environment(colorScheme, .dark)` vendu comme le remède au blanc laiteux** — c'est un **no-op** (l'app est déjà dark) | §6.3 : masque d'anneau + nuit posée + teinte noire |
| 7 | **Le croissant peint deux fois** (`moonCoin` le peint déjà) | §6.2 : `reveal: 0` |
| 8 | **`.clear` sur du contenu NET** alors que la loi dit `liquidLens` | §6.3 + A/B en C4 |
| 9 | **Une seule extraction bloquante** vue sur trois | §7 : +`CinematicPlayer` (5 sites), +`CoffreFortFlow` (4 sites) |
| 10 | **La place verticale de la bande jamais dite** | §5.3 : on aligne le **centroïde de la pièce** |
| 11 | **La surface tapable du raccourci** et la **collision de sémantique** du tap | §5.4 |
| 12 | **La pastille du compte** gardée : 3 objets ronds, 2ᵉ source de lumière | §3.5 : elle meurt, le nombre devient légende |
| 13 | **La page morte** après l'arrivée (rien ne bouge, verre vide) | §4.2 : braise, rotation résiduelle, l'invite par le mot |
| 14 | **« 710 lignes » puis « 416 l. »** dans un document qui proclame « rien n'est estimé » | Corrigé : **710** (le fichier), 416 (la seule struct `CoffreFortView`) |

### Et ce que la V2 a cassé toute seule (4ᵉ tour, 25-08)

La v2 a corrigé 14 défauts **et en a introduit un**. Les juges ont été relus,
et chaque grief re-mesuré par moi avant correction — deux d'entre eux étaient
eux-mêmes exagérés (notés ci-dessous).

| # | Le défaut | La correction |
|---|---|---|
| 15 | **⚠️ LE PIRE : « le passage devant l'objectif » N'EXISTE PAS.** La v2 a canonisé la lecture d'un juge — pièces qui passent devant, or sur la tranche « en feu », coupe à jeter — et **je l'ai annoncée à Kathryn comme la découverte principale**. Mesuré et vu : au sommet (68-72) la pièce est frontale et emplit le cadre, puis elle **se met de champ et RECULE** (aire 16 % → 4 %, hauteur 0,94 → 0,63). **La v1 avait raison : on coupe au sommet.** | §1.1 conséquence 1, §5.2 |
| 16 | **La couleur de la lampe, mesurée en moyenne de ligne** (artefact pollué par le noir) : « (174,166,134), chaud, jamais saturé ». Vérité : cœur écrêté (255,255,221), **sat 1,00 à 4 px**, et la loi maison en clair — R à 255, le VERT qui monte, le BLEU à 0 | §1.2 conséquence 4 |
| 17 | **La désaturation du sol jamais dite** — et la pièce est posée pile dans la zone tiède (sat 0,23, RGB 178/142/137) | §1.2 conséquence 5 |
| 18 | **La loi du flou du manège lue à l'envers** : `\|sin(2πu)\|` est **nul au milieu** (le moment de présentation), pas maximal | §4.1 |
| 19 | **La règle du verre écrite à l'envers** : la v2 disait « transforms sur le groupe, jamais le frame » ; le dépôt dit **l'inverse** (`PorteEntree:1274`), et interdit en plus le `.blur` sur du rond (`MenuCouronne:32`). **Le manège et le verre natif sont incompatibles en l'état** | §6.3, tranché au banc C5 |
| 20 | **Les 1,15 s de temps mort au début du film**, jamais vues | §1.1 conséquence 2 |
| — | *Grief non retenu :* « une coupe franche à l'image 28 ». C'est un **élan progressif** sur 4 images (deltas 7,6 → 11,4 → 17,4), pas un cut | noté §1.1 |
| — | *Grief non retenu :* « il n'y a pas de passage » **et** « le film s'ouvre sur une coupe » venaient de deux juges qui se contredisaient ; seule la mesure a tranché | — |

**LA LEÇON DE MÉTHODE, ET ELLE EST CHÈRE.** J'ai remplacé une lecture juste
(la mienne, mesurée) par une lecture fausse (celle d'un juge, affirmée), parce
qu'elle était formulée avec plus d'assurance. **Un juge qui affirme ne
remplace pas une sonde qui mesure.** Tout grief d'un juge se re-mesure avant
d'entrer au plan — et à plus forte raison avant d'être annoncé à Kathryn.

---

*Rien n'est codé. Le premier coup de pioche est **C0** — les trois extractions
et l'archive — et il ne demande aucun des trois verdicts.*
