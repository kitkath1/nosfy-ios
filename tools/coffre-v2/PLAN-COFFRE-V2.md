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

### ★ LE FILM EST LIVRÉ — `lune_noir_video_360.mp4` (25-08), et il est BON

2494 × 3326, HEVC 10 bits, 24 i/s, **193 images**, 8,04 s, 19,1 Mo.

**Ce que la mesure dit, et tout est excellent :**

| Mesure | Valeur | Conséquence |
|---|---|---|
| Le disque | bbox **509 × 503**, écart-type des quatre bords : **0,5 / 0,5 / 0,3 / 0,0 px** sur 193 images | **immobile au demi-pixel** — le détourage est UNE ellipse, calculée une fois, valable pour tout le tour |
| Le fond | **min 0, moyenne 0,000, max 0** aux quatre coins | rien à incruster : on coupe au bord du disque, il n'y a pas de voile à tuer |
| Le ratio | 0,986 à 0,992 | un cercle (très légèrement plus large que haut) |

**⚠️ MAIS CE N'EST PAS LA PIÈCE QUI TOURNE — C'EST LA LUNE DEDANS.** Le disque
de verre est rigoureusement identique d'un bout à l'autre ; ce qui pivote sur
l'axe vertical, c'est **le croissant à l'intérieur**, qui passe **de champ (un
simple trait vertical) aux images ~48 et ~144**. Ce n'est pas ce qui avait été
spécifié — et c'est **plus beau** : un objet 3D qui tourne dans une bulle de
verre immobile, plutôt qu'un palet qui bascule. Deux conséquences :
- le geste droite-gauche fait tourner **la lune**, pas la pièce ;
- ce film **ne donne pas deux faces** (or / sombre) : il n'y a qu'une pièce, la
  sombre. La distinction or/noire reste à trancher (question ②).

**LE TEST DE COMPOSITION EST FAIT** (`refs/essai-sol.jpg`,
`essai-contact.jpg`, `essai-noir.jpg`) : sa pièce détourée, posée sur le vrai
fond de la chambre.
> **Réponse à son inquiétude (« ma vidéo est sur fond noir, ça va le faire ? »)
> : OUI, et sans rien lui redemander.** Le fond noir n'est pas un problème,
> c'est un cadeau — il est à zéro absolu et le disque est fixe, donc le
> détourage est exact.

Ce que les trois essais montrent :
- **Sur le sol** (y/H 0,63, sa maquette) : la pièce lit comme un **galet
  d'obsidienne** — silhouette très nette contre le sol clair, croissant qui
  brûle. Grounded, lisible, premium.
- **Avec une ombre de contact** (ellipse serrée, écrasée à 0,115 de son
  diamètre, 80 % d'assombrissement, posée à 0,40 D sous le centre) : c'est ELLE
  qui sépare « posé » de « collé ». ⚠️ Une flaque large ne pose rien, elle
  salit le sol — l'ombre doit être **serrée**.
- **Dans le noir du haut** (y/H 0,27) : les hautes lumières du bourrelet
  chantent (c'est l'éclairage pour lequel elle a rendu), mais l'objet FLOTTE.

**Le seul renoncement, et il faut le nommer** : sa pièce a été rendue contre du
noir, donc ses reflets clairs (L 200-255) perdent leur mordant contre un sol à
L 152. Sur le sol, ce qui porte l'objet n'est plus son bourrelet lumineux mais
sa **silhouette sombre**. C'est un autre registre que sa référence — plus
graphique, aussi beau, et il faut qu'elle le voie avant qu'on grave.

### ★★ LES DEUX PIÈCES SONT LIVRÉES ET CUITES (25-08, `recuit_pieces.py`)

`gold_glass_piece.mp4` et `silver_glass_piece.mp4` — deux vrais tours de
manège, **même dessin**, la pièce elle-même qui tourne et passe par la tranche.
Kathryn les annonce elle-même comme mal cadrées (« l'IA a halluciné »). Mesuré,
elle a raison, et le défaut est pire que du cadrage :

| | OR | ARGENT |
|---|---|---|
| images | 145 | 145 |
| diamètre dans le cadre | 538 px | **836 px (×1,55)** |
| dérive du centre x | 14 px | **30 px** (8 % du diamètre) |
| faces / tranches aux images | 0·53·94 / 30·74·114 | 0·67 / 36·99 |
| **un tour complet** | **~94 images** | **~124 images** |
| épaisseur du chant | 36 % | 30 % |

→ **Pas la même taille, pas la même vitesse, et elles dérivent.** Posées côte à
côte, elles se désynchronisent en trois secondes. Aucun réglage d'affichage ne
rattrape ça : il faut recuire.

**LA MÉTHODE : on ne recadre pas, ON RE-CHRONOMÈTRE.**
`tools/coffre-v2/recuit_pieces.py` mesure la largeur projetée image par image,
en déduit **les repères d'angle** (face = 180°·k, tranche = 90° + 180°·k), puis
**ré-échantillonne sur une grille d'angles régulière**. Sortie : une planche de
sprites, 72 cases pour un tour, alpha prémultipliée.

⚠️ **LE PIÈGE PAYÉ DANS CE SCRIPT, ET IL EST INSTRUCTIF.** Le premier jet
inversait la largeur par un `arccos` image par image. Or la dérivée de
`D·cos θ` est **nulle à la face** : là où la pièce est presque frontale, la
largeur ne bouge plus et l'angle devient indéterminé. Résultat mesuré :
**96 cases demandées, 41 images distinctes servies**, toutes tassées autour des
tranches. Le remède est de ne se servir de la largeur que pour repérer les
ÉVÉNEMENTS (les extrêmes, qui sont nets) et d'interpoler linéairement entre
eux : **72 cases → 72 images distinctes**, pour les deux pièces.

**LE RÉSULTAT, MESURÉ** : après cuisson, les deux pièces ont le même diamètre
**à 0,3 % près** (329-330 px) et **le même angle à chaque case**. Elles sont
jumelles. Preuves : `refs/pieces-jumelles.jpg` (les deux, case par case),
`refs/piece-or-detouree.jpg` (le détourage sur gris — aucune boîte, aucun
halo), `refs/pieces-sur-la-scene.jpg` (à la vraie taille, sur la vraie chambre,
avec l'ombre de contact).

**LE POIDS — TRANCHÉ PAR LA MESURE (25-08).** Aux réglages du premier essai
(72 × 384) une planche pèse 9,3 Mo et occupe **40 Mo décodée** : deux pièces
résidentes = 80 Mo, intenable. Sept configurations mesurées :

| config | planche | fichier | RAM | pas |
|---|---|---|---|---|
| 72 × 384 | 3456×3072 | 9,3 Mo | 40 Mo | 5,0° |
| **72 × 320** | **2880×2560** | **7,0 Mo** | **28 Mo** | **5,0°** |
| 72 × 288 | 2592×2304 | 5,8 Mo | 23 Mo | 5,0° |
| 48 × 320 | 2240×2240 | 4,7 Mo | 19 Mo | 7,5° |
| 36 × 320 | 1920×1920 | 3,5 Mo | 14 Mo | 10,0° |

**Retenu : 72 cases × 320 px.** Les deux raisons, et elles sont mesurées :
- **Le pas reste à 5°.** Descendre à 48 cases (7,5°) ferait cranter la rotation
  sous un doigt lent — et c'est exactement le geste qu'on vend.
- **La perte de définition est nulle à l'œil.** À 320 la pièce fait 271 px pour
  un affichage à 396 px en 3× (sur-échantillonnage 1,46), et la comparaison
  384/320/288 au format d'écran est **indiscernable** — les caustiques du tore
  et les hachures du croissant survivent toutes
  (`tools/coffre-v2/refs/…`, essai fait). Le verre est fait de dégradés
  DOUX : c'est la matière la plus tolérante au ré-échantillonnage qui soit.

⚠️ **ET LA RÈGLE QUI VA AVEC : UNE SEULE PLANCHE MONTÉE À LA FOIS.** Le manège
n'en montre qu'une ; garder les deux en mémoire doublerait la note pour rien.
Pic mémoire visé : **28 Mo**, pas 56.

**Les planches ne sont PAS commitées** : c'est la RECETTE qui fait foi, pas
l'artefact (la leçon de `recuit_duo.sh`). Une commande les régénère.

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

---

## §13. LE COFFRE v3 — ÉTAT AU 26-08 ET PASSATION

> Écrit pour la prochaine session. Ce qui suit est **mesuré ou lu dans le
> code** ; ce qui ne l'est pas est marqué « non identifié ».

### 13.1 Ce qui EXISTE et tourne (`Woop/Views/CoffreV2.swift`, ~700 l.)

Commits : `cdf9dc8` (la page) · `85ecd31` (le manège + salle allumée) ·
`73f2081` (le geste unique) · `7c4f40b` (la profondeur + haptiques).

- **La card** au patron `GrandeCardExos` (marge 10, rayon 55) qui porte la
  chambre de Kathryn (`coffre-salle-loop.mp4`, 540×1174, 306 Ko, boucle simple,
  image de pose sous une couche transparente).
- **La salle est ALLUMÉE par défaut** ; le doigt sur la pièce pousse la lampe
  d'un cran (montée 0,26 s, retombée 0,62 s).
- **Deux pièces** en planches de sprites 72 cases × 320 px, cuites par
  `recuit_pieces.py` depuis ses deux films — **jumelles à 0,3 % près**.
- **Le manège** : rail à 0,40 W, les DEUX pièces montées en permanence, flou de
  mise au point, élastique tanh aux deux bouts, cran au lâcher, grain haptique
  par dixième de course. Vers la DROITE amène la noire.
- **La profondeur** : la pièce tenue s'avance de 14 % + ombre portée, l'autre
  recule de 12 % et se floute de 5 pt.
- **Un angle par pièce** (`tours: [Double]`), grain haptique tous les 10°.
- **La card se raccourcit par le bas** (`FormeCardExos`) → la lune se découvre.
- **UN SEUL GESTE** pour toute la page, qui trie par l'endroit du contact.
- **L'arrivée** : `coffre-arrivee.mp4` (images 27→71 de `Liquid_pièces`,
  243 Ko), 2,85 s, un tap la passe, raccord à courbe unique vers la pièce posée.
- `CoffreFortFlow` est l'**enveloppe mince** : même signature, 4 points d'appel
  intacts, `-coffreV1` rejoue l'ancienne page.
- Bancs : `-coffre2` · `-coffreSansFilm` · `-coffreSkip` · `-coffreArgent` ·
  `-coffrePage <v>` · `-coffre2Allume`. Sim dédié **kat-coffre**
  (`5FF5AD67-F97E-47E4-AC22-D0782CD541B8`).

### 13.2 LES QUATRE DÉFAUTS OUVERTS (verdicts du 26-08)

**① « L'arrivée de la vidéo ne se voit pas, elle est fondue bizarrement. »**
*Cause, lue dans le code et mesurable :* le film vit dans une bande de
**402 × 226 pt au milieu d'un écran de 874** — soit **26 % de la hauteur** — et
il porte un fondu doux sur ses QUATRE bords (`fonduBords`, 9 à 10 % de chaque
côté). Sur du noir, une bande sombre à bords fondus ne se lit pas comme une
vidéo : elle se lit comme un halo. Et ses pièces COMMENCENT petites (largeur
0,169 du cadre à l'image 27).
*Remède à essayer :* le film **plein cadre**, recadré sur la bande centrale où
vivent les pièces (mesuré : x ∈ [0,21 ; 0,75] — un crop portrait y est
possible SI l'on recentre, contrairement au plein 9:19,5 qui les coupe) ; le
fondu latéral supprimé, ne garder qu'un fondu haut/bas court. **À FILMER**, la
capture fixe ne dit rien d'une arrivée. ⚠️ Le tap qui passe doit survivre.

**② « La pièce floue doit être plus basse, pas au même niveau que l'autre. »**
*Trivial et non fait :* `MesuresPiece` ne décale que l'échelle, le flou et
l'opacité. Il lui manque un **`y` qui suive `recul`** — la voisine descend de
quelques points quand elle recule. Une ligne.

**③ « Il manque un effet spectaculaire après l'arrivée. »**
*Non conçu.* Piste cohérente avec les lois de la page : au contact, **la barre
néon FRAPPE** (flash court, une onde qui traverse le sol), la chambre s'allume
d'un coup au lieu du fondu actuel, et l'ombre de contact rebondit. C'est
l'ATTERRISSAGE qui manque, pas la descente.

**④ « Quand je tape sur une pièce, plein de petites pièces sortent mais ça ne
fait rien de plus. »**
*NON IDENTIFIÉ, et il faut le dire.* Il n'y a **aucun système de particules
dans `CoffreV2.swift`**, et `Paillettes` (`RocketHaptics.swift:548`) est une
classe d'HAPTIQUES, pas de visuel. Deux pistes à vérifier avant de coder quoi
que ce soit : `VolDePieces` (`HomeAuroraView`) et `PlayerSeance` — les deux
seuls fichiers du dépôt qui savent faire voler des pièces. **À filmer sur le
téléphone** : c'est le seul moyen de savoir ce que c'est. Et sa remarque porte
autant sur le fond : le tap sur une pièce **ne fait rien** — il faudra décider
ce qu'il fait.

### 13.3 Les pièges payés sur ce chantier (à ne pas repayer)

1. **Un geste posé sur un conteneur dont les enfants sont en `.position()`
   PREND TOUT L'ÉCRAN.** Avec `minimumDistance: 0` il gagne partout. C'était
   la cause UNIQUE de trois pannes (seconde pièce inatteignable, card qui ne
   se soulève pas, tap qui ne passe pas). Remède : **un seul geste** qui trie
   par l'endroit du contact — ne rien laisser à arbitrer.
2. **Une card qui ne fait que `offset(y: max(tirage, 0))` NE BOUGE PAS quand on
   tire vers le haut.** Il faut une forme `Animatable` qui se raccourcit.
3. **Un argument de lancement n'arrive PAS toujours en `NSNumber`** —
   `-coffrePage 0.35` arrive en `String`. Lire les deux formes, toujours
   (`CoffreV2Page.nombre(_:)`).
4. **`offset` est une transformation de RENDU, pas de layout** : le
   `frame(alignment:)` qui suit aligne des bornes qui n'ont pas bougé. Pour
   découper une planche de sprites, on découpe le **`CGImage`**.
5. **Le vérificateur de types sature** sur des mesures inlinées dans un
   `ViewBuilder` → les sortir dans un type (`MesuresPiece`).
6. **Le simulateur ne fabrique pas de doigt** et l'accès accessibilité
   d'AppleScript est refusé sur cette machine : tout geste se juge au
   TÉLÉPHONE, ou par un banc qui fige l'état.
7. **Kathryn utilise le simulateur pendant les captures** — utiliser
   **kat-coffre**, jamais le sien.
8. **L'autre session casse le build** (`RewardCard.swift`, deux fois en une
   heure) : boucler sur le build plutôt que toucher son fichier.

---

## §14. LE COFFRE v4 — LES QUATRE DÉFAUTS TRAITÉS (26-08)

> Tout ce qui suit est **mesuré** ou **filmé au simulateur**. Le banc de la
> session : `-coffre2 -coffreTap -coffreTapFerme`, sim **kat-coffre**.

### 14.1 ① « L'arrivée ne se voit pas, elle est fondue bizarrement »

Le §13 accusait la bande de 26 % et le fondu des quatre bords. Les deux
étaient vrais, et **il y avait une troisième cause, plus grosse que les deux
autres réunies** :

| Sonde | v1 | v2 |
|---|---|---|
| Pic de luminance de la pièce (dernière image) | **L 70 / 255** | **L 255** |
| p99 de la pièce | 64 | **241** (la planche de sprites : 253) |
| Cadre | 1080 × 608, posé en bande de 402 × 226 pt | 1280 × 1200, posé **plein largeur** |
| Largeur de la pièce à l'écran | 212 pt | **370 pt** |
| Masque | fondu sur les 4 bords | **aucun** |

**LE FICHIER ÉTAIT CUIT 3,4 FOIS TROP SOMBRE.** Le film source décodé
correctement culmine à 254 ; le `coffre-arrivee.mp4` livré culminait à 70. Ce
n'était pas un choix, c'était une cuisson ratée — et ça explique tout : une
pièce à 27 % de sa lumière sur du noir n'est pas une arrivée, c'est un
fantôme. Le raccord sautait en plus de 70 à 255 en une image.

**ET LE FONDU MANGEAIT LA PIÈCE.** Mesuré : les quatre bords du fichier sont à
**zéro absolu** (max 0,0 sur les colonnes et lignes extrêmes) — il n'y avait
donc rien à fondre, du noir sur du noir. En revanche la pièce occupe
y ∈ [0,021 ; 0,964] du cadre et le masque effaçait de 0 à 0,10 et de 0,90 à 1 :
**il rongeait le haut et le bas de l'objet**. « Fondue bizarrement », mot pour
mot.

**LA RECETTE DE LA v2** (à rejouer telle quelle si le fichier se reperd) :

```sh
ffmpeg -y -i ~/Downloads/Liquid_pièces.mp4 \
  -vf "select='between(n\,27\,71)',crop=2304:2160:697:0,\
scale=1280:1200:flags=lanczos,setpts=N/24/TB,format=yuv420p" \
  -fps_mode cfr -r 24 -c:v libx264 -profile:v high -crf 17 -preset veryslow \
  -movflags +faststart -an -color_range tv -colorspace bt709 \
  -color_primaries bt709 -color_trc bt709 Woop/Media/coffre-arrivee.mp4
```

Le `crop` est **symétrique autour de la pièce** (centre mesuré x = 0,4815) :
le cadre du film vaut donc exactement la largeur de l'écran, et la pièce y fait
0,9203 de cette largeur. 940 Ko contre 243.

### 14.2 ⚠️⚠️ ET LE RACCORD EST MORT — recalé DEUX FOIS

La v2 gardait l'idée du plan (« la pièce du film devient la pièce de la
page »). Verdict : *« horrible encore, tu l'as fait fondre avec l'une des
pièces qui se pose après, NON ! joue plutôt le fondu noir de fin de vidéo,
pour un effet wahou »*.

**La cause profonde était structurelle, pas cosmétique :** ce sont **deux
rendus différents du même objet** — le film vient de `Liquid_pièces`, les
sprites de `gold_glass_piece` — donc quoi qu'on fasse, l'œil voit un objet en
remplacer un autre. Aucun réglage ne rattrape ça.

**LA FORME JUSTE, en trois temps et zéro morphing** (chronométrée au
simulateur, 30 img/s) :

| t | Ce qui se passe | Mesuré |
|---|---|---|
| 0 → 1,88 s | Le film joue, plein cadre | |
| 1,88 → 2,55 | Son sommet est TENU | immobilité mesurée (d = 0,00) |
| 2,55 → 2,89 | **FONDU AU NOIR** (`easeIn 0,34`) | 11,2 → 0,0 |
| 2,89 → 3,05 | **NOIR ABSOLU TENU** | tot = 0,00 pendant 0,17 s |
| 3,05 → 3,22 | **LA CHAMBRE S'ALLUME D'UN COUP** | sol 0 → 147 en **0,17 s** |
| 3,05 → 3,7 | La nappe chaude retombe | tot 87 → 71 |

Le noir tenu n'est pas une économie, **c'est la coupure** : sans lui le film et
la page se chevauchent et on retombe sur le fondu recalé.

### 14.3 ⚠️⚠️⚠️ LE PIÈGE QUI A COÛTÉ LE PLUS : LES COURBES DÉRIVÉES

La v2 écrivait toute la mise en scène en courbes dérivées d'un état animé —
`chute = 1 − (1−raccord)^2,2`, `filmP`, `salleP`, chacune posée sur son
`.opacity` ou son `.position`. **Aucune n'a jamais été jouée.**

> **SwiftUI n'évalue le corps d'une vue QU'UNE FOIS par animation, à la valeur
> d'ARRIVÉE, puis il interpole les MODIFICATEURS entre leurs deux bouts.** Une
> courbe écrite dans le corps ne survit donc que par ses extrémités : elle est
> remplacée par la courbe de l'animation elle-même.

Mesuré : l'allumage réglé pour 0,157 s durait **0,40 s** et démarrait 0,24 s
trop tôt — c'est-à-dire qu'il suivait la rampe de `raccord`, pas la mienne.

**Les deux remèdes, et il faut choisir :**
1. **Tout garder LINÉAIRE** dans les mesures (c'est ce que fait `MesuresPiece`
   pour la loupe : interpoler la mesure ou interpoler le modificateur donne
   alors le même résultat) ;
2. **Sortir la forme non linéaire dans un type `Animatable`** — c'est ce que
   fait déjà `FormeCardExos` (Shape) et ce que fait désormais `PieceSprite`
   (View), qui sans ça n'animerait AUCUNE rotation.

La v4 a choisi (1) partout et (2) pour la rotation. Les temps forts qui ont
vraiment besoin d'une courbe (la frappe, l'onde) vivent dans un `TimelineView`
— une **vraie** horloge, la seule qui ne mente jamais.

### 14.4 ② La pièce floue est plus basse

`MesuresPiece.bas = 18·loin + 11·recul` (pt). Le défaut n'était pas le flou,
c'était la LIGNE : deux pièces sur le même axe horizontal disent « côte à
côte » plus fort que le flou ne dit « pas encore à toi ». L'ombre de contact
suit (`repos.y + m.bas + d·0,40`), sinon elle s'en décolle.

### 14.5 ③ L'effet spectaculaire — `Atterrissage`

Quatre choses au même instant, **toutes de la lumière** (loi 3 : on ne pose pas
de lampe, on fait FRAPPER celle qui est là) :
la **nappe** (radiale, centrée sur la barre, 0,46 · coup) · la **barre** qui
encaisse (cœur blanc chaud + nappe orange, montée 45 ms, chute 0,40 s) ·
l'**onde** au sol (anneau écrasé à 0,30, jusqu'à 2,8 × la pièce) · la **pièce
et son ombre** qui s'écrasent puis rebondissent (keyframes).

⚠️ Deux pièges évités d'un coup : un `TimelineView` au lieu de deux
`withAnimation` sur la même valeur (qui n'animent RIEN), et un **compteur**
`choc` comme déclencheur de keyframes au lieu d'une date qu'on remet à `nil`
(le démontage re-déclencherait l'effet).

### 14.6 ④ Le tap — LA LOUPE

La « pluie de petites pièces » reste **NON IDENTIFIÉE** : re-vérifié à la
grep, il n'y a toujours aucun système de particules dans cette page, et les
trois seuls du dépôt (`VolDePieces`, `SeriesCoinFlight`, `CoinField`) sont
montés ailleurs, sous des `fullScreenCover` qui les couvrent. **`-coffreTap`
existe maintenant pour la filmer** (piège n° 6 : le simulateur ne fabrique pas
de doigt, donc une réponse au tap qu'aucun banc ne déclenche n'est jamais
vérifiée).

Ce que le tap FAIT, en revanche, est tranché (demande du 26-08) : **il ouvre la
pièce.** Un seul curseur `loupe`, ressort 0,62 s :
- la pièce passe à **0,64 W = 251 pt** et vient à 0,545 H (0,78 W recalé :
  « trop gros, et c'est collé au néon ») ;
- **la chambre REMONTE** — `scaleEffect(1,34, anchor: .bottom)`, jamais un
  `offset` (qui ouvrirait une bande vide en bas) : la barre monte de 115 pt ;
- **écart mesuré barre → haut de pièce : 69 pt** (contre 3 pt avant recalage) ;
- **fumée noire** : `CoinSmoke` en palette `.dark`, celle qui avait été
  composée exprès pour cette page ;
- **son** : `CoinChime.chink(volume: 0,14, rate: 0,72)` — « un plus petit
  bruit, élégant, très discret, premium » ;
- un second tap, ou un doigt hors de la pièce, referme.

### 14.6 bis ⚠️⚠️⚠️ LA TRANSITION DE LA LOUPE — « TROP CHEAP, ON VOIT QU'ELLE
### SE TRANSFORME EN TRANSPARENCE »

Le premier jet faisait grandir la pièce en **animant son `frame`**. C'était la
faute, et elle a un nom :

> **ANIMER LE `frame` D'UNE `Image`, CE N'EST PAS L'AGRANDIR.** SwiftUI ne sait
> pas interpoler un rendu bitmap entre deux tailles : il **fond l'ancienne
> image dans la nouvelle**. On voit donc deux pièces translucides se remplacer
> — à l'aller comme au retour. Un `scaleEffect` est une transformation de
> RENDU : même texture, matrice qui grandit, **aucune dissolution possible**.

Le cadre du sprite est désormais **toujours celui de la loupe** (le plus grand)
et c'est l'échelle qui travaille : au repos on descend en résolution au lieu de
monter, ce qui est le bon sens de l'échantillonnage.

**Les trois autres transparences, tuées avec :**
1. **La voisine SORT PAR LE CÔTÉ** (`cx` → hors cadre, échelle −30 %) au lieu de
   se dissoudre. Un objet qui devient translucide n'existe pas dans le monde ;
   un objet qui sort du cadre, si. Elle ne perd que 34 % d'opacité.
2. **Les textes ont leur PROPRE horloge** (`texteOp`) : ils partent en 0,16 s et
   reviennent 0,30 s après la fermeture. Portés par `loupe`, ils se dissolvaient
   pendant les 0,62 s du ressort — une page entière qui devient translucide sous
   l'objet qui grandit, c'est exactement ce qu'on lit comme « cheap ».
3. **L'ombre portée reste SERRÉE** (rayon 26 et non 40) : une auréole grise
   large autour d'une pièce sur un sol clair se lit comme de la transparence,
   pas comme du poids.

**Et ce qui rend la transition spectaculaire**, enfin : la pièce fait **UN TOUR
COMPLET** en montant (`tours[i] += 1` dans le MÊME `withAnimation` que `loupe` —
un objet qui grossit sans tourner est un zoom, un objet qui tourne en venant est
un objet qu'on vous montre ; un tour ENTIER et pas un demi, sinon elle finit sur
la tranche), plus **le théâtre** : la chambre se retire dans l'ombre par les
BORDS (ouverture radiale centrée sur la pièce, jamais un voile uniforme — un
voile uniforme grise l'objet aussi).

⚠️ Le tour ne s'anime que parce que `PieceSprite` est devenu `Animatable` (§14.3).

### 14.7 La chambre recuite (« on voit tous les défauts »)

`coffre-salle-loop.mp4` faisait **540 px** de large pour une card qui en
demande **1206 au 3×** — 2,2 × d'agrandissement au repos, **3,0 ×** la loupe
ouverte. Recuit en **1620 × 3518** (pixel pour pixel au repos, 1,0 × à la
loupe), et `salle-poster` avec lui :

```sh
ffmpeg -y -i ~/Downloads/backgroundcoffre.mp4 \
  -vf "crop=1768:3840:196:0,scale=1620:3518:flags=lanczos,format=yuv420p" \
  -c:v libx264 -profile:v high -crf 21 -preset veryslow -movflags +faststart \
  -an -color_range tv -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
  Woop/Media/coffre-salle-loop.mp4        # 3,0 Mo
```

Le `crop` reproduit exactement le recadrage d'origine (déduit de la barre :
elle passe de x ∈ [0,1685 ; 0,8208] dans la source à [0,169 ; 0,821] ici).

### 14.8 Le sens des deux pièces (la petite card de verre)

| | Compte | Mot | Ligne de verre |
|---|---|---|---|
| OR | `coins` | coins earned | 20 coins for every set you finish. |
| NOIRE | **0** | legendary coins | One opens a legendary card booster. |

⚠️ Premier jet recalé d'un mot — *« ça fait trop cheap »* : étiquette en
capitales, deux lignes, verre teinté à 42 %. Ce qui rend une mention premium,
c'est ce qu'on lui ENLÈVE : plus de titre, **une seule ligne**, et la moitié de
la matière du verre (teinte blanche 0,28, liseré noir 0,07). Les deux comptes
et les deux lignes se croisent sur `page`, **à taille fixe** — deux cards
montées/démontées au cran feraient sauter la mise en page.

⚠️ Et l'économie n'est tranchée qu'à moitié : `CoffreFortPurse.perSeries = 20`
dit ce qu'une série rapporte, **rien ne dit ce qu'une pièce achète**. Le prix
du booster s'écrira dans `CoffreV2Page.compte(_:)`, et nulle part ailleurs.

### 14.9 Ce qui reste ouvert

1. **La pluie de petites pièces** — à filmer sur le téléphone avec
   `-coffreTap` sous la main.
2. Le prix d'un booster (le seul chiffre qui manque à la card de verre).
3. Verdicts téléphone sur la loupe : taille, écart au néon, densité de fumée.

---

# §15. LE PODIUM ET LE PROJECTEUR — la chambre RETOURNÉE (plan, 26-08)

> **CE CHAPITRE EST UN PLAN. RIEN N'EST CODÉ.** Tout ce qui suit est mesuré sur
> `~/Desktop/podium.png` (la maquette de Kathryn), sur `coffre-salle-loop.mp4`
> et sur les planches de sprites. Les images de travail :
> `refs/podium-maquette-kathryn.jpg` (sa maquette) et `refs/podium-compositions.jpg`
> (quatre montages de vérification, faits hors du projet).

## 15.1 La demande, mot pour mot

> « dans cet écran cela manque de mise en valeur, il faut mettre les pièces en
> avant comme un podium et un spotlight, mais avec le fond gris j'ai pas
> l'impression qu'on va y arriver »
> « j'ai inversé le background, une grosse majorité est noir »
> « il faut rajouter un spotlight au-dessus de la lune sélectionnée, sans la
> grossir comme avant — je tap, elle grossit un peu mais pas trop »
> « je te passe l'image du podium, il faudra que tu la crop pour pas perdre
> l'animation néon en haut, et tu vas le fondre dans le noir »

Et elle avait raison AVANT de savoir pourquoi : **un projecteur n'est pas de la
lumière, c'est du NOIR.** Le sol de la chambre est mesuré à **L 148-152** sur
toute la moitié basse. On ne peut pas éclairer ce qui est déjà éclairé — aucun
faisceau, aucun halo, aucun liseré ne peut se lire là-dessus. Retourner la
chambre n'est donc pas un goût, c'est la seule façon d'avoir de quoi allumer.

## 15.2 ⚠️ LA MESURE QUI ÉCONOMISE UN FICHIER : SON FOND EST LA CHAMBRE ACTUELLE, RETOURNÉE

Profil vertical au centre, autour de la barre, sa maquette contre un simple
`vflip` de `coffre-salle-loop.mp4` :

| Écart à la barre | Maquette Kathryn | `vflip` de la chambre |
|---|---|---|
| −0,20 H | (187, 161, 155) L 166 | (186, 172, 173) L 175 |
| −0,12 H | (243, 151, 131) L 169 | (230, 172, 162) L 184 |
| −0,06 H | (252, 112, 65) L 138 | (254, 137, 81) L 158 |
| −0,02 H | (255, 100, 7) L 126 | (253, 119, 0) L 139 |
| +0,02 H | (48, 7, 0) L 15 | (26, 0, 0) L 5 |
| +0,05 H | (5, 0, 0) L 1,1 | (3, 0, 0) L 0,6 |

**C'est la même rampe, la même loi maison (R à 254, le VERT qui monte, le BLEU
à zéro), la même chute au noir.** Sa maquette n'est pas un nouveau décor : c'est
le nôtre à l'envers. **Aucun nouveau rendu n'est nécessaire pour le fond** — un
`vflip` à la cuisson suffit.

La seule différence est le CADRAGE : elle met la barre à **0,344 H**, le
retournement naturel la met à **0,507 H**.

## 15.3 ⚠️⚠️ LE PODIUM SE COMPOSE EN ADDITIF — ET C'EST MESURÉ, PAS ASTUCIEUX

« Tu vas le fondre dans le noir » : il n'y a **rien à fondre**, et c'est le
cadeau de ces deux fichiers.

| Sonde | Valeur |
|---|---|
| Le noir de la chambre retournée là où le podium se pose (y/H 0,60 → 0,95) | **moyenne 0,0000 · max 0,0 · p99,9 = 0,00** |
| Le pourtour du podium dans sa maquette, à gauche du socle | moyenne 4,4 · p99 16,9 (c'est sa propre retombée de lumière, elle fait partie de l'objet) |
| … à droite | moyenne 2,4 · p99 8,9 |
| … sous le reflet | moyenne 1,2 · p99 3,5 |
| … au-dessus du socle | moyenne 1,2 · p99 3,2 |

➜ **Le podium se pose en `.blendMode(.plusLighter)` sur le noir de la chambre.**
Son fond noir disparaît EXACTEMENT (zéro + presque-zéro = presque-zéro : au pire
4/255 de voile dans les coins vides, invisible), et sa retombée de lumière au
sol arrive avec lui. **Pas de masque à dessiner, pas d'alpha à détourer, pas de
bord à raccorder.** Vérifié au montage (`refs/podium-compositions.jpg`).

⚠️ Corollaire à ne pas rater : ça n'est vrai **que dans la zone noire**. Le
podium ne doit jamais chevaucher la barre ni le mur — au-dessus de 0,50 H,
l'additif éclaircirait le décor.

## 15.4 Le découpage du podium (les cotes)

Mesuré sur `podium.png` (941 × 1672, ratio 0,563) :

| Grandeur | Fraction | px |
|---|---|---|
| Cœur de la barre | y/H **0,3417** | 571 |
| Étendue de la barre | x ∈ [0,148 ; 0,845] | |
| Cylindre du podium — largeur | **0,3932 W** | 370 |
| Cylindre — haut (ellipse du dessus) | y/H **0,6471** | 1082 |
| Cylindre — bas | y/H **0,7632** | 1276 |
| Centre du cylindre | x/W **0,4984** (centré) | |
| Le reflet meurt | vers y/H 0,86 | |

**La découpe à faire** : `x ∈ [0,18 ; 0,82]`, `y ∈ [0,615 ; 0,90]` — on prend
LARGE, parce que la retombée et le reflet **font partie de l'objet** ; les
rogner, c'est reposer le socle sur une arête.

⚠️ **RÉSOLUTION — la seule vraie limite.** Le cylindre ne fait que **370 px** de
large dans son fichier. Pour un socle de 185 pt à l'écran il en faut **555 au
3×** : on agrandirait de **1,5×**. Sur un objet sombre et doux ça passe (vérifié
au montage), mais si elle peut ré-exporter la même image en **≥ 1400 px de
large**, le socle devient net gratuitement. *À demander, pas bloquant.*

## 15.5 Le cadrage — la seule vraie décision de composition

On veut la barre plus haut que son retournement naturel (0,507 H) pour ouvrir
du noir. **La forme juste est un décalage, pas une déformation** : le film garde
sa taille et sa largeur d'écran, on le fait GLISSER vers le haut, et le bas
découvert est du noir — celui de la card, exactement le même que celui du film.

Coût mesuré de la remontée à 0,344 H (soit −145 pt) : la première ligne visible
du mur passe de **L 157 à L 171**. C'est-à-dire qu'on perd les gris les plus
pâles du haut, et **rien d'autre**. Le décalage est gratuit.

| Variante | Barre | Noir disponible | |
|---|---|---|---|
| **A** | 0,344 H | 66 % | son cadrage, celui de sa maquette — **reco** |
| B | 0,430 H | 57 % | compromis, on garde tout le mur |
| C | 0,507 H | 49 % | le retournement nu ; **le podium et la barre se disputent la place** |

## 15.6 L'anatomie proposée (à fouetter au banc, pas à croire sur parole)

| Élément | Place | Cote |
|---|---|---|
| Barre néon | 0,344 H | (le film) |
| **Le faisceau** | du bord haut jusqu'au socle | cône très diffus + flaque sur le socle |
| Ellipse haute du podium | **0,660 H** | socle **0,46 W** = 185 pt |
| La pièce, DEBOUT sur le socle | centre **0,578 H** | **0,36 W** = 145 pt |
| Le compte + son mot | 0,800 H | |
| La petite card de verre | 0,872 H | |

⚠️ **DEUX CONSÉQUENCES QUI VONT MORDRE SI ON NE LES ÉCRIT PAS MAINTENANT :**

1. **L'ENCRE S'INVERSE.** Aujourd'hui le compte et la card de verre sont en
   **encre sombre sur le sol clair** (`encre = white 0,10`, verre teinté BLANC à
   0,28 — la recette de JOUR de `ChipVerre`). Dans la chambre retournée, tout ce
   texte tombe sur du **NOIR** : il faut la recette de NUIT (encre blanche,
   verre teinté NOIR 0,5, liseré blanc 0,08). Les deux existent déjà dans
   `ChipVerre` et se pilotent par `clarte` — **rien à inventer, tout à
   rebrancher**.
2. **LA PHRASE DU HAUT TOMBE DANS LA LUMIÈRE.** « Find what you worked for. »
   vit à y 63…250, c'est-à-dire **en plein dans le mur éclairé**. Trois issues :
   (a) elle descend sous le podium avec le reste du texte — **reco**, le haut
   devient du décor pur et c'est ce que montrent ses deux réfs ; (b) elle passe
   en encre sombre sur le mur ; (c) on redescend le mur, ce qui reprend le noir
   qu'on vient de gagner. Le chevron, lui, reste en haut à gauche et bascule en
   `ChipVerre(clarte: 1)` — la recette de jour, déjà écrite.

## 15.7 Le projecteur

**La loi** : il ne se dessine pas, il se **creuse**. Ce qui le fait exister,
c'est le noir autour, pas le blanc dedans. Deux couches seulement (l'école déjà
validée sur la robe `spotlight` de la reward card, §7a du plan des rewards) :
- **le cône** — très diffus, du bord haut jusqu'au socle, ouverture ~30°,
  opacité basse ; c'est du volume, pas un trait ;
- **la flaque** — une ellipse écrasée sur le dessus du socle, plus vive que le
  cône : c'est ELLE qui dit « la lumière touche ».

Teinte : la rampe maison, **R à 1,00, le vert qui monte, le bleu à zéro** — le
projecteur est de la même famille que la barre, jamais un blanc bleuté.

**Il est FIXE et il désigne** : il reste au centre, et le manège fait passer les
pièces dessous. C'est ce qui donne un sens à « la lune **sélectionnée** » — la
sélectionnée, c'est celle qui est sous la lumière. (Un projecteur qui suit la
pièce ne désigne plus rien : il devient un accessoire de la pièce.)

Il pulse très légèrement au repos (±4 %, période ~5,5 s, hors phase avec la
respiration de la barre) : une lampe de théâtre vit, elle n'est pas une découpe
en carton.

## 15.8 ⚠️ LA QUESTION OUVERTE : LA SECONDE PIÈCE A-T-ELLE SON SOCLE ?

Aujourd'hui la voisine flotte au bord, floue. Sur du noir, **flotter se voit** :
au montage elle a l'air suspendue. Trois formes, et il faut trancher :

- **(a) UN SOCLE PAR PIÈCE — reco.** Une rangée de podiums qui défile ; celui du
  centre est sous le faisceau, les autres sont dans l'ombre (plus petits, plus
  sourds, plus flous). Le manège devient une **galerie**, et le projecteur
  devient la sélection. C'est aussi ce que montre sa réf chinoise.
- **(b) UN SEUL SOCLE, les pièces passent dessus.** Plus sobre, mais pendant le
  geste il y a un instant où le socle est vide ou porte deux pièces.
- **(c) La voisine reste sans socle**, simple invite au bord. Le moins de
  travail, mais c'est le défaut d'aujourd'hui qu'on garde.

⚠️ (a) suppose un socle **détouré**, pas la vignette entière — sinon les
retombées de lumière des socles voisins s'additionnent en un tapis gris. Sa
maquette donne un socle **au centre, avec sa lumière** : pour (a) il faudra soit
qu'elle exporte le socle **seul sur noir, sans sa flaque**, soit qu'on ne
compose la flaque que pour celui du centre.

## 15.9 Le tap — « elle grossit un peu, mais pas trop »

La loupe à **0,64 W** est recalée. Ce que le tap fait désormais :

| | Repos | Ouverte |
|---|---|---|
| Diamètre | 145 pt | **~180 pt** (×1,25, et pas ×1,9) |
| Hauteur | posée sur le socle | **décollée de ~16 pt** — elle LÉVITE |
| Faisceau | nominal | **+45 %**, cône resserré |
| Le reste de la scène | nominal | s'assombrit de ~35 % |
| Fumée noire | — | comme aujourd'hui, mais autour du socle |

**C'est la LUMIÈRE qui fait la mise en valeur, plus la taille.** Et ça règle du
même coup le grief « trop gros / collé au néon » : à 180 pt le sommet de la
pièce est à 0,49 H, soit **128 pt sous la barre**.

⚠️ Tout ce qui a été payé le 26-08 reste valable et ne se rediscute pas : le
cadre du sprite **ne bouge jamais** (c'est `scaleEffect` qui travaille, sinon
SwiftUI fond les bitmaps → la « transparence cheap »), la voisine **sort par le
côté**, les textes ont **leur propre horloge**, et le tour complet accompagne la
montée.

## 15.10 Ce qui MEURT dans la page actuelle

- `CoffreV2Cotes.piecY = 0,615` → remplacé par la cote du socle.
- **L'ombre de contact** (l'ellipse noire) : sur du noir, elle n'existe plus.
  C'est le **reflet du socle** (qui vient avec l'image) et la flaque de lumière
  qui font le contact.
- **`loupeZoom` — la chambre qui remonte** : elle remontait pour dégager le sol
  clair. Le noir est déjà là ; la chambre ne bouge plus.
- **Le vignettage radial de la loupe** : il servait à assombrir un sol clair.
  Remplacé par la baisse du décor et la montée du faisceau.
- **`Atterrissage`** : la barre qui frappe et la nappe restent (elles sont
  toujours au bon endroit) ; **l'onde au sol** doit passer **sur le socle**, où
  il y a de la lumière — sur du noir, un anneau clair est un anneau qui flotte.
- **`encre`** et la recette de la card de verre : voir §15.6, elles s'inversent.

## 15.11 Les jalons

| | | Verdict attendu |
|---|---|---|
| **P0** | Recuire la chambre **retournée** (`vflip`) + son image de pose. Une commande, zéro risque. | — |
| **P1** | Le cadrage : banc `-coffreBarre 0.344 / 0.43 / 0.507`, page nue. | **le cadrage A/B/C** |
| **P2** | Le podium en additif + la pièce debout dessus, sans faisceau. | les cotes du socle et de la pièce |
| **P3** | Le faisceau (cône + flaque), fixe, avec sa pulsation. | **l'intensité** — c'est là que ça se joue |
| **P4** | Le texte : inversion de l'encre, descente de la phrase, verre de nuit. | la lisibilité |
| **P5** | La seconde pièce : trancher (a)/(b)/(c) et le socle qui va avec. | **sa décision** |
| **P6** | Le tap ×1,25 + lévitation + faisceau qui monte. | |
| **P7** | L'arrivée : le film + fondu au noir + **l'allumage devient l'allumage du PROJECTEUR**, pas de la chambre. Le noir tenu prend tout son sens : la scène est déjà noire, c'est le faisceau qui naît. | |

⚠️ P7 est un cadeau du retournement : aujourd'hui l'allumage doit faire naître
une chambre entière en 0,17 s. Sur une scène noire, il n'a plus qu'à **allumer
une lampe sur un objet** — et c'est exactement le geste d'un projecteur de
théâtre.

## 15.12 Ce qu'il me faut d'elle

1. **La décision §15.8** (un socle par pièce, un seul, ou aucun pour la voisine).
2. *Si (a)* : le socle **seul sur noir, sans sa flaque de lumière**.
3. *Optionnel, gratuit en qualité* : la même image de podium ré-exportée à
   **≥ 1400 px de large** (aujourd'hui le cylindre ne fait que 370 px, on
   agrandit de 1,5×).
4. Le cadrage A/B/C — mais ça, le banc P1 le lui montrera mieux qu'une question.

## 15.13 CE QUI EST CODÉ (26-08) — et les trois calages payés

Assets recuits : `coffre-salle-loop.mp4` **retourné** (`vflip`, 1620 × 3518) ·
`salle-poster` avec lui · `coffre-podium` découpé de sa maquette
(`crop 603 × 360 à (169, 1028)`, fondu bas et latéral cuits dans l'image).

Code : `SceneCoffre` (toute la géométrie sortie des `ViewBuilder`) ·
`CoffreV2Podium` (les cotes mesurées du socle) · `Projecteur` (cône + flaque,
pulsation 15 Hz) · `PiedCoffre` (le pied de page) · `MesuresPiece` réécrit
autour de la MARCHE.

**Le socle ne bouge pas, les pièces viennent dessus** (sa décision) : `mont =
max(0, 1 − 2|e|)`. À mi-course les deux sont descendues et **l'estrade est
LIBRE** — c'est le plus beau moment du geste. Avec `1 − |e|` on aurait eu deux
demi-pièces en lévitation au-dessus du même socle.

### Les trois calages, mesurés

1. **« Le blanc prend tout le haut header de l'iPhone, et on voit toute la
   démarcation de l'image. »** Le retournement avait cassé la **loi 2 de la
   page** — le noir continu : le quart HAUT du fichier était à vrai zéro, et
   c'est lui qui rendait le début de la card invisible. Retournée, la chambre
   pose son mur ÉCLAIRÉ sous l'encoche.
   *Remède :* un masque **en espace ÉCRAN** (jamais en espace vidéo) qui tue le
   mur sur trois bords — le haut (noir plein jusqu'à 0,035 H, plein mur à
   0,105) et les deux côtés (5,5 %). Pas de fondu en bas : il n'y a que du noir.
   ⚠️ Et il ne porte QUE sur la chambre — le socle, la pièce et le texte sont
   des couches à part. C'est la faute exacte de l'ancien `fonduBords`, qui
   mangeait le haut et le bas de la pièce du film.
   *Vérifié :* y/H 0 → 0,035 = **0,0 absolu** ; bords latéraux à **10-13 sur une
   moyenne de 153**, soit 8 % du mur.
   *Conséquence :* le chevron descend de 63 à **104** — à 63 il tombait dans le
   fondu, et un chip de JOUR posé sur du gris à L 80 n'est lisible ni de jour
   ni de nuit. Et la barre descend de 0,344 à **0,375 H** pour rendre sa place
   au titre.

2. **« Les pièces flottent légèrement par défaut au-dessus. »** Elles étaient
   posées sur `cylHaut` — le bord **ARRIÈRE** de l'ellipse du dessus, c'est-à-dire
   sur le vide derrière le socle. Mesuré au profil, la face du dessus va de
   y 1082 à 1140 (sa lèvre avant, L 82,7) : le niveau de pose est son CENTRE,
   **0,2306** du découpage — soit **13 pt plus bas**. `cylPose` existe pour ça,
   et `yBas` s'en déduit.

3. **« Le composant footer n'est pas assez travaillé. »** Il ne l'était pas :
   un chiffre, un mot et une pilule posés l'un sous l'autre, ce sont trois
   objets qui flottent au même endroit. `PiedCoffre` en fait **un** : une seule
   dalle de verre de nuit, le compte et la phrase séparés par un filet, le mot
   en petites capitales espacées, et **un liseré spéculaire en haut qui meurt à
   ses deux bouts** — c'est lui qui donne l'épaisseur, et c'est la seule chose
   qui sépare une dalle de verre d'un rectangle gris (un liseré qui va d'un
   bord à l'autre ne l'éclaire pas, il le DESSINE).

### Les cotes finales

| | |
|---|---|
| Barre néon | 0,375 H |
| Chevron / titre | 104 pt, **encre SOMBRE** (il vit sur le mur) |
| Pose du socle | 0,665 H · cylindre 0,42 W |
| Pièce au repos | 152 pt · sommet à **101 pt** sous la barre |
| Pièce au tap | ×1,22 = 185 pt, +16 pt de lévitation · sommet à **52 pt** sous la barre |
| Voisine | au PIED du socle, rail 0,38 W, −24 % de lumière |
| Pied de page | dalle 352 × 86, centrée à `podFin + 58` |

### Ce qui reste

- La **pluie de petites pièces** au tap, toujours non identifiée (`-coffreTap`
  est là pour la filmer).
- Le prix d'un booster (le seul chiffre qui manque à `compte(_:)`).
- Verdicts téléphone : intensité du faisceau, densité de la fumée, et le vide
  noir entre la barre et le socle.

## 15.14 Les quatre calages du soir (26-08) — et une leçon sur « fondu »

**① « Je parlais de la démarcation de la PHOTO DU PODIUM, qui se voit quand
l'écran s'éclaire. »** J'avais entendu « le mur » ; c'était le socle. La cause
est mécanique : sa retombée de lumière va jusqu'à **x 0,05** de sa maquette
(mesuré, L 4,4 de moyenne à gauche du cylindre), et mon premier découpage la
TRANCHAIT. En `.plusLighter`, un bord tranché à L 4 est invisible sur du noir —
mais **dès que la scène monte d'un cran, le rectangle de la photo apparaît**.
*Remède :* on prend tout — `crop 884 × 493 à (28, 961)` — et les quatre bords
meurent **en cosinus dans l'image elle-même** (13 % en haut, 20 % en bas, 15 %
de chaque côté). Vérifié : les trois premiers pixels de chaque bord sont à
**0,01 / 255**, et le saut maximal mesuré sur une ligne traversant le socle,
écran allumé, est de **4,57 / 255** — et il tombe *dans* la retombée, pas sur un
bord.

**② « Je voulais pas que la partie grise soit FONDUE — elle prend juste bien
tout l'écran iPhone, elle était coupée avant. »** Deux jets ratés pour un seul
malentendu : le patron `GrandeCardExos` (marge 10 pt + quatre coins à 55)
**coupait** le mur, et le masque en dégradé que j'ai posé ensuite le faisait
**mourir** sous l'encoche. Elle ne voulait ni l'un ni l'autre : **plein cadre**.
*Remède :* `FormeScene` — haut carré et à ras bord, bas arrondi, et elle garde
le seul comportement qui compte (la card se raccourcit à la levée, sinon la
lune est inatteignable). Vérifié : le mur touche les trois bords (L 93 aux
arêtes latérales dès y/H 0,00). Et le chevron retrouve sa cote canonique de 63.

> **LEÇON.** « Fondu » ne désigne pas le même objet selon qui parle. Deux
> chantiers de suite ont été refaits parce que j'ai appliqué le remède au
> mauvais calque. Avant de fondre quoi que ce soit : **demander QUEL bord**, ou
> le montrer en capture.

**③ « Les pièces étaient un peu plus au-dessus du podium, là elles sont trop
collées. »** J'étais passé du vide (13 pt, `cylHaut` = le bord ARRIÈRE de
l'ellipse) au contact franc (`cylPose`, mesuré). Elle voulait le milieu :
`CoffreV2Cotes.vol = 8` — une pièce de verre qui **affleure** son socle. Ce
n'est pas une erreur de pose, c'est la seule chose qui dise qu'elle est
précieuse.

**④ « La vidéo d'entrée, tu l'as coupée trop tôt. »** Le métrage ne peut pas
être rallongé : au-delà de l'image 72 la pièce se met de champ et RECULE (§1.1),
finir là-dessus c'est finir sur un objet qui s'en va. Ce qu'on rallonge, c'est
le **temps de pose sur son sommet : 1,38 s au lieu de 0,68** (`terminer()` à
3,25 s), et le fondu au noir passe de 0,34 à **0,44 s**, le noir tenu de 0,16 à
**0,18**. C'est le temps qui fait exister une arrivée, pas le métrage.

**⑤ La fluidité.** Le projecteur re-floutait un tracé **plein écran** douze fois
par seconde. La pulsation ne touche désormais **que l'opacité** : le corps du
faisceau est construit une fois, groupé en une seule passe de composition
(`compositingGroup`), et l'horloge ne fait plus varier qu'un scalaire.

## 15.15 « Ça sert à rien d'éclairer toute la page »

Verdict : *« l'image se voit, une démarcation du background vs le bas sous la
card coins earned… au pire insiste juste sur le spotlight au-dessus qui
s'allume plus et qui bouge, là c'est trop discret. »*

**La cause, mesurée.** La retombée de lumière du rendu de Kathryn baigne tout
le sol : à l'écran ça faisait une nappe à **L 11-25 qui s'arrêtait à y/H 0,83**,
avec du noir dessous. Et **une nappe qui s'arrête, on lit le bord de l'image**.

> **LA LOI.** Le remède n'est jamais d'AGRANDIR la nappe pour qu'elle atteigne
> les bords — c'est de **ne plus en avoir**. Un décor lavé de lumière trahit
> toujours son cadre quelque part ; une lumière posée sur un OBJET, jamais.

**Deux remèdes, et ils vont ensemble :**

1. **Le socle éteint sa nappe lointaine.** Un facteur radial cuit dans l'asset
   (`0,16 + 0,84·exp(−r²/0,62)`, métrique elliptique centrée sur le cylindre) :
   le socle garde ses **L 209**, la nappe au sol tombe de **L 20 à L 2**.
   Vérifié après coup à l'écran : la colonne hors du socle passe de 11-25 à
   **0,2-2,7**, et elle meurt sans marche.
2. **Le projecteur se resserre sur la pièce, et il BOUGE.** Trois foyers, tous
   serrés, plus aucun lavage :
   - **la COURONNE** sur le crâne de la pièce — c'est elle qu'elle a montrée en
     gros plan, et c'est elle qu'on voit d'abord (mesuré à l'écran : pic
     **L 107** pile sur le bord haut de la pièce) ;
   - **le CÔNE**, court : de la barre au cœur de la pièce, plus jusqu'au sol ;
   - **la FLAQUE** sur le socle, à 0,34 : juste de quoi dire que ça POSE.

   ⚠️ **Il CHERCHE, il n'oscille pas** : deux harmoniques aux périodes
   **premières** (7 s et 11 s) — leur somme ne se répète qu'au bout de 77 s,
   donc l'œil n'y trouve jamais de cadence. Une seule sinusoïde se lit comme un
   métronome en trois allers. (Loi reprise de la robe `spotlight` des rewards.)
   Le balayage vaut ±0,045 W au sommet du cône, ±0,014 W sur la couronne.

   ⚠️ Et il ne suit la pièce que **verticalement** (quand elle grandit et
   lévite), jamais latéralement : le projecteur est FIXE, et c'est ce qui fait
   qu'il DÉSIGNE (loi 3). Au tap il monte de **55 %**.

**Et le vol de la pièce, troisième passe.** 13 pt de vide involontaire (pose sur
le bord arrière de l'ellipse) → contact franc (`cylPose` mesuré) → **18 pt**,
qui est la seule valeur qui ait été DEMANDÉE (« remonte un peu les pièces du
podium, elles sont trop collées dessus »).

---

# §16. L'ÉVENTAIL, LA LÉVITATION ET LA FLUIDITÉ (plan + exécution, 26-08)

Verdicts : *« réduis la taille de la pièce par défaut encore »* · *« le halo,
travaille-le plus en effet spotlight comme les cards rewards, très joli, un peu
triangulaire, élégant »* · *« la pièce flotte légèrement par défaut »* · *« c'est
pas fluide pour passer d'une pièce à l'autre au drag »* · *« il y a toujours la
démarcation, car tu as activé que toute la page devienne plus claire au tap :
non, pas besoin »*.

## 16.1 ⚠️ LA DÉMARCATION QUI RESTAIT — elle avait raison sur la cause

Ce n'était **pas** le socle (celui-là est réglé, §15.15). C'était **`eclat`** :
le doigt posé sur la pièce faisait monter `.brightness(0,10)` et
`.saturation(1,14)` **sur toute la chambre**. Éclaircir un décor, c'est
exactement ce qui fait apparaître ses bords — la loi du §15.15, deuxième
application en deux heures.

> **`eclat` MEURT.** Il datait de la loi 1 (« la pièce est l'interrupteur »),
> écrite quand la page n'avait pas de projecteur. Maintenant qu'elle en a un,
> **c'est le faisceau qui répond au doigt**, pas la pièce entière. Une seule
> lampe (loi 3), et elle est locale.

## 16.2 Le halo devient L'ÉVENTAIL des rewards

La recette est déjà validée (`RewardCard.swift`, `LampeEventail` + `Eventail` +
`balayageSpot`). On la PORTE, on ne la réinvente pas :

- **DEUX ÉVENTAILS** — la nappe LARGE et douce (flou 13) et le CŒUR étroit et
  plus vif (flou 9, écrasé à 0,55 en x). *« La lumière a un corps et une âme. »*
- **Les flancs sont FONDUS** par un masque latéral : *« un trait à bord franc
  sur du noir est de l'encre, pas de la lumière »*. C'est ça qui donne le
  triangle ÉLÉGANT plutôt qu'un cône découpé.
- **Le balayage** `sin(0,62 t)·0,78 + sin(0,29 t + 1,3)·0,30`, borné — deux
  harmoniques aux périodes premières : le projecteur CHERCHE. Rotation **ancrée
  à la source**, sur le bord haut de l'éventail.
- Teinte : la rampe maison (R à 1,00, le vert monte, le bleu à zéro) — le
  blanc pur des rewards deviendrait bleuté à côté du néon.

La **couronne** (la lumière posée sur le crâne de la pièce, sa capture en gros
plan) reste, mais s'efface derrière l'éventail. La **flaque** sur le socle
reste, discrète : elle dit que ça pose.

## 16.3 Les cotes qui rétrécissent

| | avant | après |
|---|---|---|
| Pièce au repos | 152 | **130** |
| Socle (cylindre) | 0,42 W | **0,393 W** — SA cote, mesurée sur sa maquette |
| Vol au repos | 18 pt | 18 pt + **une lévitation de ±3,2 pt** |

Écarts vérifiés : sommet de la pièce à **105 pt** sous la barre au repos, **61**
ouverte.

## 16.4 La lévitation

Elle ne flotte pas d'une hauteur, elle **respire** : ±3,2 pt, période 4,7 s.

⚠️ Écrite en `ViewModifier` avec un `TimelineView` dedans, comme `CarteLevee`
des exos : `body(content:)` reçoit l'arbre **déjà construit**, donc le relire
vingt fois par seconde ne reconstruit rien. Et l'ombre, elle, ne bouge PAS —
c'est l'écart entre l'objet et son ombre qui fait la lévitation.

## 16.5 ⚠️ LA FLUIDITÉ DU MANÈGE — quatre causes, toutes mesurables

Le drag écrit `page` soixante fois par seconde, et **tout ce qui lit `page`
se reconstruit soixante fois par seconde**. Ce qui coûtait :

1. **DEUX DALLES DE VERRE en fondu croisé sur `page`.** `glassEffect` est un
   matériau système : en croiser deux à chaque image du geste, c'est deux
   passes de matériau par image, pour une information qui **ne change qu'au
   cran**. ➜ Le pied lit un **index discret** (`piedIdx`), mis à jour au
   passage du cran avec son propre fondu. Pendant le geste, il ne bouge plus
   du tout.
2. **Le décor et le projecteur se reconstruisaient** parce que la page entière
   se ré-évalue. ➜ `SceneCoffre` devient `Equatable`, la chambre sort en
   `SalleFond` et le projecteur passe en `.equatable()` : SwiftUI saute leur
   corps tant que leurs entrées n'ont pas bougé.
3. **`mont` avait un COUDE** à |e| = 0,5 (`max(0, 1−2|e|)`) : la pièce changeait
   de direction d'un coup au milieu du voyage. ➜ Lissé en `smoothstep`.
4. **Le flou par image.** `.blur` sur une `Image` force une passe hors écran à
   chaque image. ➜ Rayon max 7 → **5**, et il meurt plus tôt.

## 16.6 Ce qui ne change pas

Le cadre du sprite ne bouge jamais (c'est `scaleEffect` qui travaille) · la
voisine sort par le côté · les textes ont leur propre horloge · le tour complet
au tap · le projecteur reste FIXE latéralement (il DÉSIGNE) · la scène est plein
cadre, ni coupée ni fondue.

---

# §17. MINI-FIX (26-08) — le drag, le halo de trop, et la légèreté

## 17.1 ⚠️ LE DRAG NE MARCHE QUE DANS UN SENS — trois causes, pas une

*« J'arrive à drag quand je drag vers la gauche pour voir la pièce de droite,
et inversement ça marche pas. »*

**(a) LA ZONE DE PRISE DE LA PIÈCE MANGE LE MILIEU DE L'ÉCRAN.** `prise = d ×
0,70` = **91 pt de rayon** autour du centre de la pièce, soit une fenêtre de
182 pt de large (45 % de l'écran) et de 182 pt de haut, pile à la hauteur où le
doigt passe pour faire défiler. Tout geste qui commence là **tourne la pièce**
au lieu de pousser le manège — et comme la pièce tourne bien, on ne comprend pas
pourquoi le manège ne bouge pas.
➜ `d × 0,56` = 73 pt : le disque fait 130 pt de large, on garde 8 pt de marge
autour de lui et pas 26.

**(b) LE SENS EST INVERSÉ PAR RAPPORT AU GESTE NATUREL.** Le code portait
« vers la DROITE amène la pièce noire » (sa demande d'alors) : le rail va donc
à l'inverse du doigt. Elle décrit aujourd'hui la convention normale — *« je drag
vers la gauche pour voir la pièce de droite »* — et c'est elle qui gagne : **le
rail suit le doigt.**

**(c) LE CRAN POUVAIT REFUSER UN GESTE FRANC.** `cible = (pagePrise + élan)
.rounded()` : une course de 100 pt suivie d'un lâcher mou rend un arrondi qui
**revient en arrière**. Un geste franc doit TOUJOURS commettre.
➜ Au-delà d'un quart de course, on part du côté où le doigt allait
(`ceil`/`floor`), sans discuter de l'arrondi.

## 17.2 « Tu as le spotlight ET un gros halo, faut choisir »

Deux sources dans la même scène, c'est une de trop — et c'est le contraire de
la loi 3 (une seule lampe). **La COURONNE meurt** : cette ellipse posée sur le
crâne de la pièce faisait une galette floue derrière l'objet. Il ne reste que
l'éventail (qui éclaire) et la flaque sur le socle (qui dit que ça pose).

## 17.3 « Le spotlight beaucoup plus premium et léger »

Un faisceau premium **ne peint pas un coin de gris** : il suggère du volume et
il MEURT avant d'arriver. Trois réglages, tous dans le même sens :

| | avant | après |
|---|---|---|
| Nappe — opacité de tête | 0,30 | **0,16** |
| Nappe — flou | 13 | **19** |
| Cœur — opacité de tête | 0,46 | **0,26** |
| Cœur — flou | 9 | **13** |
| Où la lumière est éteinte | à 100 % de la course | **à 82 %** — elle arrive, elle ne repeint pas |
