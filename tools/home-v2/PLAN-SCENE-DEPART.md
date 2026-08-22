# LA SCÈNE DE DÉPART — le plan

*Rien n'est codé. Tout ce qui suit est mesuré ; les sources sont nommées.
Les mesures neuves sont marquées **[M]**.*

---

## 1. LA DEMANDE

Un seul écran. Le doigt tire. La card se raccourcit par le bas, le slider
paraît dans la bande — et **à l'intérieur de la card, deux objets descendent :
le texte et la pilule.** Pendant ce temps la braise et l'arête de la card ne
bougent pas d'un pixel.

*« la vidéo doit descendre en cinématique Apple 3D vers le bas, la pilule ; le
texte aussi doit descendre en blur magnifique ; le slider est trop collé et la
card n'est pas bien respectée ; tu vas trop vite ; ça doit être doux et
majestueux. »* Et, du tour d'avant : *« JE DOIS VOIR LA BORDURE DE LA CARD !
ON EST SUR LE MÊME ÉCRAN, SIMPLEMENT LES ÉLÉMENTS GLISSENT. »*

**[M] Les deux flèches vertes font 728 px chacune, au pixel près.** Ce n'est
pas approximatif : c'est une consigne. Les deux objets font le même trajet.
« On est sur le même écran » se lit **caméra verrouillée** — et une caméra
verrouillée est le plan le plus cher qui existe.

---

## 2. CE QUE MESURE LA CAPTURE DE 08:46

Calibration : écran repéré à x 4..648, y 0,4..1400,5 → **k = 1,6020 px/pt**.
Contrôle : 874 × 1,6020 = 1400,1 px pour 1400,1 mesurés.

| | mesuré à s = 1 | voulu |
|---|---|---|
| pilule | y **78 → 336**, dôme à ~196 | au repos 187 → 445, dôme à 247 |
| | **elle MONTE de 51 pt** | elle doit descendre |
| braise | **42 %** de sa lumière dans le cadre | 100 % |
| arête basse de la card | 758 (874 − 116) | — |
| slider | 752 → 814 : **il chevauche l'arête de 6 pt** | sous l'arête, avec de l'air |
| noir sous le slider | **60 pt morts** (26 + 34) | 24 + 34 |
| libellé du slider | 62 × 0,169 = **10,5 pt** | plancher iOS : 11 pt |
| durée | 0,2 s de pouce + un ressort de 0,46 s | 1,4 – 2,4 s |

---

## 3. LES QUATRE CAUSES

### (1) Il n'y a pas de film, il y a un pouce

`scene = -tirage / 150` ([HomeNuit.swift:1623](../../Woop/Views/HomeNuit.swift#L1623)).
Un pouce parcourt 150 pt en 0,20 s : **le film dure 0,20 s**, puis un ressort
unique `spring(0.46, 0.82)` **pose** la fin au lieu de la parcourir.

L'écart se mesure **contre la page elle-même** : son arrivée dure déjà
**1,84 s** ([HomeNuit.swift:2180-2188](../../Woop/Views/HomeNuit.swift#L2180-L2188)).
Le départ est à un ordre de grandeur en dessous de son propre écran. Ce n'est
pas un `response` à baisser : c'est une machinerie absente.

### (2) Le scrub demande 530 images/s, le silicium en sert 20 — et il n'achetait rien

**[M]** `ffprobe home-fond-loop.mp4` → **1620 × 3522, 24 i/s, 859 images,
35,79 s, 72 clés (GOP 11,93)**. *(Le commentaire
[HomeNuit.swift:839](../../Woop/Views/HomeNuit.swift#L839) annonce
« 1080×2348, 12 s » : périmé sur les trois nombres — et c'est sur ce chiffre-là
que tout le raisonnement de scrub avait été écrit.)*

Chaque cible tombe dans un GOP différent, à `tolerance .zero` : ~6 images de
5,7 Mpix à redécoder. Le coalesceur en sert 15 à 25 par seconde. **On voit
quatre ou cinq images distinctes sur tout le geste.**

Et **trois preuves indépendantes** qu'il n'achetait rien :

1. **[M]** Le barycentre de la pilule ne dérive que de **47 pt en x, 28 pt en y
   sur les 6 s du clip source** (144 images mesurées). C'est une respiration,
   pas un mouvement. Le roulé façon AirPods **n'a jamais été dans l'image**.
2. **[M] Le fichier est un palindrome** (`split → reverse → concat` dans
   `recuit_fond.sh`). L'image 858 diffère de l'image 0 de **0,71/255 en
   moyenne** : `scrub = 1` montre **la même image** que `scrub = 0`. Même avec
   un scrubber parfait, le geste ne produisait **aucun changement net**.
3. Le contenu réel est à 8 i/s : les 429 images du fichier sont 287 images
   triplées par `setpts=3.0 + minterpolate=blend`.

**Le scrub meurt.** La couche pilule garde son `AVPlayerLooper` ; sa **cadence**
monte de 1,0 à 2,2 pendant la scène (deux appels, pas de rampe, zéro seek).

### (3) L'`aspectFill` recentre quand le tiroir s'ouvre

- Card fermée : 382 × 864, ratio **0,442** → remplissage **par la hauteur**, le
  bas de la vidéo tombe **pile** sur l'arête.
- Card ouverte : 382 × 748, ratio **0,511** → remplissage **par la largeur** et
  `aspectFill` **CENTRE** : débord de 41 pt en haut et en bas.

**Chaque point de levée déplace le contenu vidéo de −0,5 pt.** Ajouté au zoom
×1,15 ancré au centre, c'est ce mécanisme — pas le zoom seul — qui fait monter
la pilule de 51 pt et jette **58 % de la lumière de la braise**. Le fichier
avait déjà fait le tour du problème dans ses propres commentaires
([:1039-1052](../../Woop/Views/HomeNuit.swift#L1039-L1052)) sans pouvoir
conclure : un plan plat ne peut pas déplacer un morceau en laissant l'autre.

### (4) La bande du bas est renversée

Air requis au-dessus du slider : **30,8 pt**. Air disponible : **−6**.
Déficit réel **36,8 pt**, et 60 pt de noir mort en dessous.

---

## 4. L'ARCHITECTURE — une lampe glissée entre deux calques

```
  ┌ card — clip FIXE, rayons 45 / 55, marge 10, JAMAIS transformée ────┐
  │                                                                     │
  │  ⑤ le voile de lisibilité      multiply — sous le BLOC DE TEXTE     │
  │  ④ CALQUE PILULE               descend, roule, grossit              │
  │  ③ l'occlusion de contact      multiply — suit la pilule            │
  │  ② LE FOYER                    plusLighter — suit la pilule         │
  │  ① CALQUE BRAISE               cloué à l'arête, AUCUNE transformation│
  │  ⓪ le poster de secours        DANS le UIViewRepresentable          │
  └─────────────────────────────────────────────────────────────────────┘
     hors du clip : le mobilier SwiftUI · hors de la card : le slider
```

**Le foyer est SOUS la pilule, et la pilule est additive.** Conséquence gratuite
et exacte, sans un seul shader : là où le verre est sombre on voit la braise ;
là où il est moyen il **prend la teinte** du lit ; là où il est spéculaire il
reste blanc. La loi « pas de shader sur un `AVPlayerLayer` » n'est pas
contournée : elle est rendue **inutile**.

### 4.1 — `plusLighter`, pas `screen`

Je me corrige : j'avais écrit `screen`. **`plusLighter` a deux précédents en
production sur un `AVPlayerLayer`** ([DepartSeance.swift:267](../../Woop/Views/DepartSeance.swift#L267),
BoosterPopup.swift:492) ; `screen` en a **zéro**, et c'est structurel :
`plusLighter` / `plusDarker` sont les deux modes que CoreAnimation compose
nativement en `compositingFilter` ; les autres exigent que SwiftUI **rastérise**
la source — ce qu'un `AVPlayerLayer` hébergé n'est pas.

L'écrêtage que je redoutais n'existe pas : les deux calques ne se superposent
que dans la bande de raccord, où le contenu plafonne à 12/255.
**Filet**, si une capture montre un écrêtage sur le dôme :
`layer.compositingFilter = "screenBlendMode"` posé **dans** le représentable.

⚠️ **Le `compositingGroup` ne va PAS sur la pilule.** Posée seule, elle s'isole
et fusionne contre le `Color.black` de `GrandeCardVideo` : additif sur noir =
identité, **le foyer sort du calcul et la thèse s'évapore sans une seule erreur
de compilation.** Le groupe englobe le ZStack braise + foyer + occlusion +
pilule.

### 4.2 — La coupe : je me corrige, il n'y a pas 299 px de noir

**[M]** J'avais mesuré une seule image à un seuil de 6. Au vrai plancher et sur
tout le clip : la pilule descend jusqu'à la ligne **1232** et la braise remonte
à **1208** (canevas 1080). Sur le fichier 1620 × 3522, la bande est
**continue** de 636 à 3516 ; le creux se déplace entre les lignes **1736 et
1848** et vaut **0 à 7/255** ; à une ligne fixe à **1900**, le maximum traversé
sur les 859 images est **12/255**.

**La parade rend la coupe exacte, et elle ne demande pas de HEVC-alpha :**

| calque | lignes du fichier | raccord cuit |
|---|---|---|
| **pilule** | 0 .. 1960 | fondu vers le noir sur 1800 → 1960 |
| **braise** | 1800 .. 3522 | fondu depuis le noir, rampe complémentaire |

Composés en additif, **les deux rampes se somment et reconstituent l'original
au pixel.** Hors de la bande, chaque calque est noir là où l'autre porte le
contenu. *(Contrôle indépendant que j'ai fait : dans la bande de recouvrement,
la braise plafonne à **2/255** et l'écart entre le screen et la somme est de
**0,00/255**.)*

### 4.3 — Échelle **constante**, jamais `aspectFill`

Les deux calques sont dimensionnés à **l'échelle du repos, K = 864/3522 =
0,245315**, et **jamais par la largeur**.

- **Braise** : cadre 397,4 pt de large × 422,4 pt, **ancré par son arête basse**
  sur l'arête de la card. Elle suit la card — seul déplacement admis, et il est
  nul en relatif puisqu'elle **est** le bas de la card.
- **Pilule** : cadre 397,4 × 480,8, **ancré par son arête haute** au haut de la
  card (y = 10). Elle ne peut plus se recentrer quand la card change de hauteur.

⚠️ **Pas « par la largeur ».** `382/1620 = 0,2358` est **4 % plus petit**,
déplace le haut de la braise de 12 pt et supprime les **7,71 pt de débord
latéral par côté** que l'`aspectFill` rogne aujourd'hui : au premier arrondi
sous-pixel, un liseré noir apparaît sur les flancs, et la recette de parité (J1)
le verrait.

---

## 5. LA GÉOMÉTRIE DE LA BANDE — `leveeTiroir` 116 → **158**

C'est une somme, pas une envie.

| cote | pt | justification |
|---|---|---|
| réserve du home indicator | **34** | inset système ; le mobilier vit déjà dans la safe area (62..840) |
| rail du bas | **24** | le rail **déjà établi** : le galet est à `.padding(.bottom, 24)`, l'invite aussi. Le slider **remplace** le galet dans la rangée — deux objets qui se succèdent partagent leur arête. Le 26 actuel désaligne de 2 pt, et ce saut se voit pendant le fondu croisé |
| hauteur du slider | **68** | sa hauteur **naturelle**, rabotée à 62 par la home. Le libellé vaut `height × 0,169` : **10,48 pt à 62** (sous Caption 2 = 11 pt), **11,49 à 68**. Toutes ses cotes internes sont un relevé au 1:1 sur 68 |
| air au-dessus | **32** | **[M]** la gerbe de poudre du commit monte à **30,8 pt** hors cadre, et le Canvas de poudre fait 130 de haut = 31 pt de plafond — la toile a été taillée pour ça. 32 est le cran suivant sur la grille de 8, et c'est 2 × la marge système : l'échelle où Apple lit « objet séparé » |
| **total** | **158** | |

**Contrôle :** arête card `874 − 158 = 716` · slider `748..816` · `816 + 24 =
840` · `840 + 34 = 874` ✓. L'arête basse du slider tombe **au pixel** sur celle
du galet.

### 5.1 — Édition couplée : `padding(.bottom, 122)` → **164**

La phrase finale est épinglée à la **safe area**, pas à l'arête. Sa marge
au-dessus de l'arête vaut `34 − L + padBottom` : aujourd'hui 40 pt, à L = 158
sans rien toucher **−2 pt** — elle tomberait SOUS la card, sur le noir, et
l'intention mourrait sans un avertissement. **Règle : `padBottom = L + 6`.**

**[M] Et elle fait TROIS lignes, pas deux.** Vérifié à la vraie fonte
(Inter-SemiBold 30 pt, largeur 330) : 316 / 313 / 147 pt. Bloc de **122 pt**,
soit **554..676**. Toute cote calculée sur deux lignes est fausse de 38 pt.

### 5.2 — D'où sort la course : **284 pt**, dérivée deux fois

| contrainte | calcul |
|---|---|
| **le texte** : le bas de l'ancien bloc doit rejoindre le haut du nouveau | ancien 110..289 (h 179) réduit à ×0,90 ancre `.topLeading` ⇒ h 161,1 ; `110 + d + 161,1 = 554` ⇒ **d = 282,9** |
| **la pilule** : son centre doit finir dans le cœur du feu | **[M]** centre au repos **315** ; braise clouée : R = 0,30 à y 588, R = 0,42 à 661 ; `315 + d = 599` ⇒ **d = 284** |
| **retenu** | **284 pt pour les deux** — écart entre les deux dérivations : **1,1 pt** |

**Tes 450 pt.** La translation écran est 284. La distance **relative** entre la
pilule et la crête de braise se ferme de **284 + 158 = 442 pt**, parce que la
braise clouée monte de L à sa rencontre. Écart à ta mesure : **1,8 %**.

**Je dis explicitement que j'outrepasse la lettre de la consigne**, et
pourquoi : à 450, le centre de la pilule tombe **49 pt sous l'arête** et **63 %
de l'objet est coupé**. On regarderait un moignon. Banc `-coursePilule` pour
trancher à l'œil.

*(`leveeSeance` 106 → 166 suit la même anatomie — `32 + 76 + 24 + 34` — mais
part en jalon séparé : c'est hors périmètre.)*

---

## 6. LA PARTITION — **T = 1,95 s**

**Deux curseurs qui ne se croisent jamais.** `g`, la prise, collée au pouce,
réversible, qui ne fait que de la **lumière** ; et `e`, un **temps en
secondes**, parti au cran, que plus rien n'accélère.

### 6.1 — Phase doigt (`g`, ~0,20 à 0,40 s, aucune horloge)

| g | quoi | valeurs |
|---|---|---|
| 0,00 → 0,37 | la phrase d'accueil **se défocalise** — elle ne bouge pas | blur **0 → 3,5 pt** sur les glyphes |
| 0,04 → 0,41 | les deux cards de verre décrochent | blur **0 → 6,0** (plafond dur), offset +7, opacité → 0 |
| 0,08 → 0,45 | la semaine décroche, la dernière et le moins | blur **0 → 4,0**, offset +5 |
| 0,00 → 0,28 | l'invite « pull to start » meurt | opacité → 0, offset +6 |
| 0,00 → 1,00 | **la bande noire s'ouvre, 1:1 exact** | levée = \|tirage\|, 0 → 158 |
| — | **pilule, braise, slider, nouvelle phrase** | **rien. Zéro pixel.** |

**Trois rayons de flou différents (6 / 4 / 3,5), pas un seul.** Trois plans au
même rayon, c'est un masque ; trois rayons différents, c'est une profondeur de
champ. C'est la définition numérique du verdict « des éléments masqués ».

**Et c'est l'immobilité pendant la prise qui fait exister la chute ensuite.**
Si le texte commence à tomber au doigt, il repart d'un point aléatoire au cran
et « les deux flèches font la même longueur » est perdu.

### 6.2 — La partition (`e`, en secondes)

| de → à (s) | quoi | valeurs | courbe |
|---|---|---|---|
| **0,00** | **LE CHOC** — l'armement | `.rigid` 1,00 / 0,90. Rien ne bouge encore | — |
| 0,00 → 0,28 | la card **finit de se poser** | levée → **158**, arête **716** définitive | `timingCurve(0.10, 0.55, 0.36, 1)` — départ raccordé à la vitesse du doigt |
| 0,00 → 0,45 | la lune se couche | elle tient la bande pendant que le slider n'y est pas encore | sstep |
| **0,26** | **le verre est DÉMONTÉ** | les cards + la semaine sortent de l'arbre | seuil verrouillé |
| **0,10 → 1,52** | **LA CHUTE DU TEXTE** | offset y **0 → +284**. Bloc 110..289 → 394..673. Pic **452 pt/s à 0,88 s**, **3 pt/s à l'arrivée** | **`timingCurve(0.62, 0, 0.20, 1)`** |
| 0,10 → 0,78 | …il sort du plan de netteté | blur **3,5 → 22 pt** sur les glyphes, échelle **1,00 → 0,90** ancre `.topLeading` | somme de deux fenêtres |
| 0,66 → 1,30 | …**et seulement là**, il s'éteint | opacité → 0. À 1,28 s il a parcouru **95 %** de sa course : elle voit tout le voyage, il ne s'arrête jamais à l'écran | sstep |
| **0,14 → 1,56** | **LA CHUTE DE LA PILULE** | offset y **0 → +284** sur le calque pilule seul. Centre **315 → 599**. 40 ms de retard au départ et à l'arrivée : le verre est plus lourd que l'encre | **même courbe** |
| 0,20 → 1,62 | **L'APPROCHE** | `scaleEffect` **1,00 → 1,22** ancre `.center`. Finit **0,06 s après** la chute : le sujet se pose, la caméra s'installe encore | `timingCurve(0.42, 0, 0.28, 1)` |
| 0,14 → 1,40 | **le roulé, axe X** | `rotation3DEffect(8°, (1,0,0), perspective: 0.50)`. **Même courbe que la translation** — un corps rigide n'a qu'une courbe | même courbe |
| 0,44 → 1,74 | **le roulé, axe Y — décalé exprès** | `−3°`, fenêtre décalée de +0,30 s. **L'axe résultant DÉRIVE** : l'œil lit un corps qui bascule, pas un plan qu'on incline. Deux axes synchrones se composent en un axe fixe et l'effet meurt | `timingCurve(0.30, 0, 0.30, 1)` |
| 0,00 → 1,55 | **le film accélère** (pas de scrub) | `player.rate` **1,0 → 2,2**, retour à 1,0. **Deux appels**, zéro seek | échelon |
| **0,74 → 1,66** | **LE FOYER** — la braise reçoit sans bouger d'un pixel | `EllipticalGradient` additif, rayons **190 × 96**, centre = celui de la pilule + 36. Couleur = **le ratio de canaux MESURÉ du lit, 1 : 0,272 : 0,015**. Alpha 0 → 0,10 | sstep |
| 0,74 → 1,66 | …et sa **portée** monte | le stop nul passe de 208 à 268 pt au-dessus de l'arête. **Ce n'est pas la braise qui monte, c'est la zone qu'elle éclaire** — un feu qui prend éclaire plus haut, il ne se déplace pas | sstep |
| 1,04 → 1,72 | **l'occlusion de contact** | `RadialGradient` gris 0,55 → blanc, `.multiply`, **entre** le foyer et la pilule. **Arrive 0,30 s après le foyer** : la lumière d'abord, l'ombre qu'elle implique ensuite | sstep |
| **1,08** | **LE CONTACT** | transient 0,28 / 0,10, pendant que la pilule va encore à 300 pt/s : on sent une collision, pas un arrêt | — |
| 0,92 → 1,58 | **le voile de lisibilité** | gris 0,70 → blanc, `.multiply`, **au-dessus** de la pilule, **sous** le texte. Un calque posé, jamais un `.mask` | sstep |
| **0,96 → 1,78** | **LA NOUVELLE PHRASE S'ÉCRIT** | **trois** fragments, retards **0 / 0,13 / 0,26**, rampe 0,56 ⇒ **77 % de recouvrement**. Par fragment : blur **20 → 0**, offset **+90 → 0**, échelle 1,04 → 1,00, opacité 0 → 1. Elle **naît en vol** à y ≈ 644 et **finit la chute** pour se poser à 554..676 | sstep par fragment |
| **0,95 → 1,82** | **LE SLIDER MONTE** — il arrive, il ne s'essuie pas | offset **+30 → 0**, échelle **uniforme 0,93 → 1,00** ancre `.bottom`, blur **7 → 0**, opacité 0 → 1. Position 748..816, hauteur 68 | `timingCurve(0.22, 1, 0.36, 1)` |
| 0,78 → 1,50 | **la tenue** | haptique **continue**, 0,72 s, sharpness 0,05, enveloppe 0 → 0,26 → 0 | cloche |
| **1,88** | l'invite, et le doigt est accepté | transient 0,20 / **0,45** — le seul timbre clair après le cran | — |
| 1,82 → 1,95 | l'apnée, puis l'horloge s'endort | 0,13 s. `e` retombe sur T **au centième** : aucune image ne change à la bascule | — |

### 6.3 — Les contrôles de rythme

- **Six atterrissages, espacés de 0,04 / 0,06 / 0,10 / 0,04 / 0,04 s** : texte
  1,52 · pilule 1,56 · échelle 1,62 · roulé Y 1,74 · phrase 1,78 · slider 1,82.
  **Aucun instant ne voit deux objets s'immobiliser ensemble.**
- **Densité** : 5 canaux à 0,30 s · 8 à 0,90 · 6 à 1,30 · 3 à 1,70 · 1 à 1,80.
  Decrescendo, pas de falaise.
- **Queue morte : 0,13 s.**
- **Rien de neuf ne commence après e = 1,08.** Les 0,87 dernières secondes —
  45 % de la partition — ne sont que des fins. *« C'est ce dernier tiers qui
  fait le luxe »* (MenuNappe.swift:1430).

### 6.4 — Le déclenchement, le retour, l'interruption

**L'amplitude de l'élastique EST la cible** : `158·tanh(pouce/190)` au lieu de
150. Conséquence : au lâcher, **la card avance toujours** — aujourd'hui elle
**recule de 22 pt**, ce qui se lit comme un rebond raté. Les seuils se recalent
sur le **pouce** : cran 90 → 95 (132,0 pt de pouce contre 131,7 — l'invariant du
geste est conservé au pixel), fermeture 40 → 42.

- **Un seul site d'appel**, `lancer(gDepart:)`. Le tap passe `gDepart = 0` ;
  toutes les fenêtres sont écrites en `max(gCran, sstep(e, a, b))`, donc **la
  partition fait elle-même le travail que le doigt aurait fait**. Les deux
  chemins donnent la même scène **image par image à partir de e = 0,26**.
- **Interruption** : à `e < 0,55`, un doigt coupe l'horloge et rebranche sur
  `g` ; au-delà, un **tap** rejoue le reste en 0,32 s — **la même sortie,
  pressée, jamais une coupe.**
- **Fermeture : 0,72 s**, soit 37 % de l'aller, avec **trois** décalages au lieu
  de dix-huit. Une fermeture est une obéissance, pas une cérémonie ; un
  événement subi dix fois par jour devient une lenteur. Zone morte de 24 pt sur
  le drag vers le bas.
- **Aucune haptique sur un abandon** : un annulement qui vibre punit d'avoir
  changé d'avis.

---

## 7. LA MACHINERIE

### 7.1 — Le prérequis n° 1 : `Chambre(p: e)` ne joue RIEN

`Chambre` est `Animatable` : SwiftUI n'interpole que si la valeur change **dans
une transaction**. Une horloge murale n'invalide aucun body. Au lâcher, la
pilule descendrait seule et **tout le reste gèlerait**.

**UNE `TimelineView` à la racine du contenu de la home.** `Chambre` sort du
chemin de la scène (elle reste pour `arrivee`, piloté par un `withAnimation` —
là elle est correcte).

```swift
TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                        paused: reduceMotion || depart == nil)) { tl in
    contenu(geo, g: g, e: e(tl.date))
}
```

L'horloge est **pausée au repos et sous le doigt** : coût zéro. Elle ne tourne
que pendant les 1,95 s. **60 Hz et pas 30** : pointe 452 pt/s ⇒ 7,5 pt/image à
60 Hz contre **15 pt/image à 30 Hz** sur un objet net de 288 pt.

### 7.2 — `DepartCine` : la partition comme un enum d'instants absolus

École `BravoCine` / `MoonSplashBeat` / `ConnexionCine` : des `static let xxxAt`
/ `xxxFor`, et **rien que** des fonctions pures de `e`. Rien n'est stocké.
Bénéfice direct : `-departFige <e>` **reconstitue** la scène à n'importe quel
instant, donc on la juge sur images fixes.

### 7.3 — La nuance qui débloque tout

La loi « un `scaleEffect` sur un `AVPlayerLayer` SAUTE » est vraie **pour une
valeur qui vient d'un `withAnimation`**.
[DepartSeance.swift:250-269](../../Woop/Views/DepartSeance.swift#L250-L269)
prouve qu'elle est fausse pour une valeur qui vient d'une **horloge**. Et le
commentaire sur place ajoute la loi jumelle : **transformer, jamais
redimensionner la frame** — *« un `AVPlayerLayer` redimensionné 60×/s relayoute
et re-rend chaque image. »*

⚠️ **Mais le `rotation3DEffect` sur une couche vidéo n'a AUCUN précédent.** Les
deux jalons cités font scale + offset **à 30 Hz**, sans rotation. C'est le
jalon J0, et on ne devine pas.

⚠️ **Ordre des modificateurs** : `.scaleEffect(k).offset(y: d)` et **jamais**
l'inverse — S·T multiplierait le déplacement par k, soit 62 pt de course
parasite.

### 7.4 — Les haptiques : un `CHHapticPattern` armé en bloc

Le motif entier est livré au moteur **au cran** (école `DiveRumble`) : il tient
l'horloge du moteur, insensible aux images. **On ne tire jamais une haptique
depuis une closure de `TimelineView`** — une évaluation de body n'a pas le droit
d'avoir d'effet de bord et sera rejouée plus d'une fois par image.

Disparaissent : le `.rigid` du lâcher et celui du tap de l'invite. **Trois
`.rigid` en moins de 0,5 s aujourd'hui, dont deux annoncent le même
événement.** Le lâcher se sent par **l'arrêt du grondement**.

---

## 8. LES PIÈGES, ET LEUR PARADE

| # | piège | parade |
|---|---|---|
| 1 | **`Chambre` + `Date` = zéro image.** 80 % de la scène ne jouerait jamais | une `TimelineView` racine (7.1). **Prérequis avant toute discussion de courbe** |
| 2 | **Le `rotation3DEffect` sur vidéo n'a aucun précédent** | J0, banc `-depart3D`. Si ça saute : on y renonce, translation + échelle portent 80 % de l'effet |
| 3 | **Le poster additionne** — deux pilules | il rentre dans le représentable, masqué sur `isReadyForDisplay` |
| 4 | **`compositingGroup` sur le mauvais nœud** tue le foyer **sans erreur de compilation** | il englobe le ZStack, pas la pilule |
| 5 | **La coupe n'est pas sans perte** | fondu complémentaire cuit (4.2), recette p99 ≤ 2/255 |
| 6 | **Le démontage du verre oscille** sous un pouce lent | verrou `verreMonte` : **une bascule par cycle**, remontage à `g ≤ 0,05` |
| 7 | **Un `.blur` de rayon nul reste une passe hors écran** | tous les flous **démontés** sous 0,30 pt |
| 8 | **La lampe globale se noie.** **[M]** la zone chaude varie de ×3,06 d'une image à l'autre (écart-type 20 %) | **pas de lampe globale** : un foyer **local** qui suit l'objet — l'œil détecte une structure corrélée bien sous le seuil d'un changement global |
| 9 | **`Color(1.00, 0.42, 0.13)` désature le feu** — et une saturation qui baisse, c'est du brun. **[M]** le lit mesuré : **1 : 0,272 : 0,015**, teinte 15,7°, saturation 0,985 | le foyer utilise **le ratio du lit**. Ajouter du lit à du lit ne change ni teinte ni saturation : la loi anti-brun est satisfaite **par construction** |
| 10 | **Le voile et l'occlusion se superposent** sous le texte | disjoints, et **le contrôle J4 mesure le produit**, pas chacun |
| 11 | **Le galet et la lune se coupent en une image** si on supprime le ressort du lâcher | le galet reste sur `withAnimation(tiroirOuvert)` ; la lune reçoit sa propre fenêtre |
| 12 | **Le trou de la bande** : 640 ms de noir vide | la lune tient jusqu'à 0,45, le slider entre à 0,95. Trou résiduel 0,50 s, occupé par la pilule qui traverse |
| 13 | **`DragGesture(minimumDistance: 14)`** : le premier événement porte déjà 14 pt, donc `g` saute | `pouce = max(0, -translation.height - 14)` |
| 14 | **La safe area basse pourrait ne pas être 840** (si `JewelTabBar` est posée en `safeAreaInset`, tout le calcul est faux) | **une capture au J2 avant de verrouiller les cotes.** Une mesure, pas une hypothèse |
| 15 | **`reduceMotion` n'est traité nulle part** ; `paused: reduceMotion` figerait la page à mi-scène | chemin court **explicite** : pas d'horloge, pas de rotation, pas de rate. La pilule saute sur sa transformation finale, le mobilier fait un fondu |
| 16 | **`SondeCadence` est aveugle au diaporama vidéo** — elle mesure le fil principal, qui tiendra 60 Hz devant une image figée | second instrument : compter les `hasNewPixelBuffer` par seconde. **Deux nombres, pas un** |
| 17 | **`xcodebuild \| grep` rend le code de sortie de grep** | `set -o pipefail`, `stat` du dylib avant toute capture |
| 18 | **`WoopApp.swift` porte le chantier d'une autre session** | commit **par chemins**, jamais `git add -A` |

---

## 9. LES JALONS

**J0 — la preuve de la transformation vidéo** *(bloquant)*
Banc `-depart3D` : la couche pilule seule, en `TimelineView` 60 Hz, jouant
translation 284 / échelle 1,22 / rotation X 8° / rotation Y −3° en boucle.
**Vérifié** : capture 60 i/s, barycentre **et largeur de boîte** par image.
Critère : **aucun palier de plus de 2 images consécutives**. `mpdecimate` est
écarté (le rate change les pixels de toute façon).

**J1 — les deux calques**
Découpe à la ligne 1900, fondu complémentaire, deux `AVPlayerLooper`,
`plusLighter`, échelle constante, poster rentré.
**Vérifié** : (1) **parité au repos**, p99 ≤ 2/255 — c'est le portillon ;
(2) pas d'écrêtage après descente ; (3) **la braise ne bouge pas** — profil de
luminance par ligne aux 5 gels, corrélation ≥ 0,99. *C'est le test qui aurait
tué les trois tentatives de `899a11e` en une minute chacune.*

**J2 — la géométrie**
`leveeTiroir` 158, `padBottom` 164, slider 68, mort du `scaleEffect(x:)`.
**Vérifié** : arête card **716 ± 0,5**, slider **748..816 ± 0,5**, bloc final
**554..676**, et **le contrôle du piège 14**.
⚠️ **Verdict humain requis** : le slider à 68 est un changement de **matière**.
S'il est refusé, la bande se recalcule à 156.

**J3 — la partition**
`DepartCine`, la `TimelineView` racine, les deux curseurs, le cran, le tap, le
retour, l'interruption, le verrou du verre.
**Vérifié** : barycentres aux 5 instants (± 4 pt) · **les deux courses à 284 ±
4 pt chacune** · le raccord des deux phrases ≤ 3 pt · **les deux chemins**
(tap / cran) identiques à partir de e = 0,26.

**J4 — la lumière**
Foyer, portée, occlusion, voile, liseré.
**Vérifié** : contraste du texte final ≥ 7:1 **en mesurant le produit** des deux
calques · dérive de teinte ≤ 3° et **la saturation ne baisse jamais** · le foyer
se voit (≥ 2,5 × l'écart-type temporel naturel, sinon il est sous le bruit).

**J5 — la cadence, AU TÉLÉPHONE**
Pire trou < 25 ms, jamais deux vsyncs manqués d'affilée, **et** ≥ 22 nouveaux
pixel-buffers/s par calque. Si le budget craque, on coupe dans cet ordre : le
blur du slider, la rotation Y, puis 60 → 30 Hz en allongeant la chute.

⚠️ **La géométrie et la partition partent ENSEMBLE.** La levée à 158 sur le plan
aplati ajouterait +21 pt de montée parasite et +21 pt de braise coupée : seule,
elle répare le slider et abîme l'image.

---

## 10. CE QU'ON NE FAIT PAS

**Démontré impossible :** le scrub sous toutes ses formes · recuire un fichier
pilule à la durée de la scène (145 images source, ce serait une décimation de
57 %, et ça gèlerait la durée dans un `.mp4` — chaque tour de fouettage
coûterait un ffmpeg) · cuire la mise au point dans le fichier · geler la pilule
à l'image 0 au repos (**[M]** c'est son état le plus **petit**) ·
`.blendMode(.screen)` sur un `AVPlayerLayer` · la lampe globale · une descente
de 450 pt · la braise dimensionnée par la largeur · `Chambre` sur le chemin de
la scène.

**Écarté par décision :** tout ressort — *on ne peut pas lire la position d'un
ressort en vol, donc on ne peut pas la passer au doigt : une cinématique en
ressort est une prison par construction* · une courbe sur le curseur maître
(`.linear`, point) · une chaîne d'`asyncAfter` qui livre des valeurs · le
`scaleEffect(x:)` du slider (un essuie-glace : sa capsule est peinte par un SDF,
un scale en x déforme la matière pendant 0,6 s) · une ombre portée sous la
pilule (la lumière vient d'en bas) · **toute lueur qui franchit l'arête de la
card** — les 32 pt de noir pur sont ce qui **prouve** qu'elle a un bord, sa
demande littérale · un `.mask` ou un filtre sur une couche vidéo · un `.blur`
sur un conteneur · un `drawingGroup` autour de la vidéo · un écran noir · des
sinusoïdes de respiration sur le mobilier (ce serait mettre de la vie du mauvais
côté de la vitre) · une fermeture symétrique · juger la fluidité au simulateur.

---

## 11. LE BUDGET

| | aujourd'hui | après |
|---|---|---|
| pilule | *(dans le composite, en seeks)* | ~1,5 Mpix, en **lecture** |
| braise | *(dans le composite)* | ~0,25 Mpix (gradient p99 = **2,0** : c'est un dégradé, la définition n'y sert à rien) |
| **par image** | **5,71 Mpix, en seeks** | **~1,75 Mpix, en lecture linéaire** |

Aucune source nouvelle : `~/Downloads/pills_2.mp4` et `~/Downloads/flamme.mp4`
sont déjà les deux entrées du script.

---

### Résumé des nombres

| | |
|---|---|
| durée de la partition | **1,95 s** (+ 0,20 à 0,40 s de prise, réversible) |
| course commune texte / pilule | **284 pt** d'écran, **442 pt** en relatif |
| `leveeTiroir` | 116 → **158** (32 + 68 + 24 + 34) |
| arête basse de la card | 758 → **716** |
| slider | **748..816**, hauteur **68** |
| bloc de texte final | **554..676**, trois lignes |
| centre de la pilule | 315 → **599** |
| fermeture | **0,72 s** |

---

# TOUR 2 — les quatre retours du 22-08, et le bug qui en explique deux

## LA MESURE QUI CHANGE TOUT : `.padding(.bottom, levee)` COÛTE 34 pt DE PLUS

Trois gels, trois captures, un tableau :

| levée demandée | arête basse mesurée | raccourcissement réel |
|---|---|---|
| 0 | 874 | **0** |
| 60 | 780 | **94** |
| 156 | 684 | **190** |

**Le raccourcissement vaut `levée + 34` dès que la levée dépasse zéro**, et zéro
quand elle est nulle. La cause : `.padding(.bottom, levee)` est posé sur une vue
en `.ignoresSafeArea()`. À levée 0 la card touche le bord physique, donc elle
s'étend dans l'encart bas (34 pt) ; au premier point de levée elle ne le touche
plus, `ignoresSafeArea` ne peut plus réclamer ces 34 pt, **et ils sont perdus
d'un coup**. Ce n'est pas une rampe, c'est une marche.

**Cette marche explique DEUX des quatre retours :**

1. **« la card ne descend pas assez »** — je demandais 156, la card se
   raccourcit de 190 : son arête est à **684** alors que l'état PLAYER la pose à
   **734** (mesuré : dock 784..860). Elle monte 50 pt trop haut.
2. **« le texte dépasse la card »** — la phrase finale est calée sur
   `padBottom = levée + 6`, une formule écrite pour `arête = 874 − levée`. Avec
   la marche, son bas tombe à 678 pour une arête à 684 : **6 pt d'écart au lieu
   de 40**. Elle ne dépasse pas encore, elle affleure — et à la moindre ligne de
   plus, elle sort.

**Le correctif** : la levée cesse d'être un padding et devient **l'arête
voulue**. `GrandeCardVideo` reçoit la hauteur de la card, pas une marge, et la
calcule à partir de l'encart bas lu à l'exécution — jamais d'un 34 écrit en dur,
qui est une cote d'iPhone 17 Pro et pas une loi.

## LES QUATRE POINTS

### 1. LE TEXTE DOIT SE TRANSFORMER, PAS ÊTRE REMPLACÉ

*« que ça soit bien ce texte qui s'écrit / qui se transforme du blur, et pas
l'autre texte qui vient du bas. »*

Aujourd'hui il y a **deux blocs** : l'ancien descend et meurt en vol (opacité
0,66 → 1,30), le nouveau **naît en bas** et monte de 90 pt (0,96 → 1,78). Elle
voit donc un texte partir et un autre arriver — pas une transformation.

**Un seul bloc, et l'échange se cache DANS le flou.** C'est la grammaire d'Apple
et c'est la seule façon honnête : on ne voit pas un objet changer de mots, on
voit un objet sortir du net, et revenir au net en disant autre chose.

- un bloc unique, qui fait **toute** la course (110 → 554), sur la courbe de la
  chute ;
- le flou en **cloche** : 0 → 26 → 0, sommet à l'instant de la bascule ;
- l'échelle en cloche aussi : 1,00 → 0,94 → 1,00 (il s'éloigne puis revient) ;
- **la bascule des mots au sommet du flou**, en fondu croisé de 0,12 s : à
  26 pt de rayon, la différence de hauteur entre 5 lignes et 3 est invisible —
  c'est ce qui permet de changer le nombre de lignes sans que le bloc saute ;
- ancre `.topLeading` : la gouttière de 24 pt ne bouge pas pendant que le bloc
  respire.

⚠️ Le bloc d'accueil porte `ObjectifTouche` (le galet du chiffre). Il doit être
démonté **avant** la bascule, pas pendant : un verre natif qui disparaît en
plein fondu se voit.

### 2. LA CARD DESCEND AU NIVEAU DU PLAYER

*« elle doit descendre comme quand on ouvre le player, même niveau, et le slider
est dans cet espace. »*

Mesuré : **état player → arête 734** (levée effective 140, dock 784..860).
**État tiroir → arête 684.** Elle a raison au point près : 50 pt d'écart.

**Une seule arête pour les deux états : 734.** Un seul endroit, trois contenus
(le secret, le slider, le player) — c'est déjà l'intention écrite dans le code,
elle n'était pas tenue.

Bande de 140 pt. Le slider fait 62. Répartition proposée :

| | pt |
|---|---|
| air au-dessus du slider | **39** |
| slider | **62** |
| air en dessous | **39** (dont 34 de réserve d'indicateur) |

Les 39 du haut passent la contrainte mesurée de la gerbe de poudre du commit
(33,8 pt au-dessus du cadre à h = 62). Le slider tombe donc à **773..835**.

### 3. LE TEXTE NE DOIT PLUS AFFLEURER

Conséquence directe du correctif de la marche : la phrase se mesure **depuis
l'arête de la card**, jamais depuis la safe area. Cible : bas du bloc à
`arête − 40` = **694**, soit 572..694 pour trois lignes.

⚠️ Et une vérification qui manque : la largeur. Le bloc fait `écran − 72` = 330
et démarre à 24, donc il court jusqu'à 354 pour une card qui s'arrête à 392 —
22 pt à droite contre 14 à gauche. À mesurer au rendu : si les lignes touchent,
la gouttière droite passe à 24 comme à gauche (bloc de 344).

### 4. LE RETOUR DOIT ÊTRE AUSSI BEAU QUE L'ALLER

*« il faut que le retour au drag soit aussi fluide, que tout remonte en blur et
la pilule pareil, remonte comme elle est descendue. »*

La bonne nouvelle : **c'est déjà vrai par construction.** Toutes les grandeurs
sont des fonctions pures de `e`, et la fermeture fait redescendre `e` de T à 0 :
la pilule remonte donc exactement par où elle est descendue, et les flous
rejouent à l'envers. Ce qui cloche est la **durée** : 0,72 s, soit 37 % de
l'aller. À cette vitesse la cascade se tasse et on ne voit plus le flou.

- la fermeture passe à **1,25 s** (64 % de l'aller) ;
- la courbe s'inverse honnêtement : `timingCurve(0.30, 0, 0.20, 1)` — elle part
  franchement et se pose longuement, comme l'aller ;
- **le doigt doit pouvoir la reprendre** en cours : elle est déjà interruptible
  (`ferme = nil` au premier contact), à vérifier au doigt ;
- et la bascule des mots (point 1) doit se rejouer au même `e`, donc dans
  l'autre sens, sans un seul instant où les deux blocs sont nets.

## LES JALONS

**J7 — la marche des 34 pt.** Correctif de `GrandeCardVideo`, puis les trois
gels rejoués : le raccourcissement doit être **linéaire** (0 → 0, 60 → 60,
140 → 140), à ± 1 pt. C'est le portillon : rien d'autre ne se règle tant que la
cote ment.

**J8 — l'arête commune à 734.** `-tiroirOuvert` et `-homeSeance` capturés,
arêtes identiques à ± 0,5 pt. Slider 773..835. Bloc de texte 572..694.

**J9 — la transformation du texte.** `-departFige` aux instants de la bascule :
à aucun instant deux textes ne doivent être lisibles en même temps. Mesure :
énergie des glyphes nets (gradient > 40) — un seul pic, jamais deux.

**J10 — le retour.** `-departAuto` filmé, la fermeture mesurée à 1,25 s ± 0,05,
barycentre de la pilule symétrique à l'aller à ± 6 pt, et la cadence relevée
(elle est à 52 % au simulateur — à juger au téléphone).

---

# TOUR 3 — les sept fix du 22-08, et les deux pièges qu'ils ont révélés

## 1. LA CARD PREND TOUTE LA LARGEUR

*« on voit trop les côtés noirs à droite et à gauche, elle doit prendre
l'espace »* — et ce n'est PAS un revirement sur « je dois voir la bordure de la
card ». Ce qui donne sa forme à une card, c'est son **arête basse et ses
coins** ; ils restent. Le noir des FLANCS ne dessinait rien, il coupait la
braise en deux.

Bénéfice mesuré : la vidéo fait 1080 × 2348 = **0,45997**, l'écran 402 × 874 =
**0,46000**. À marge nulle le cadrage devient **exact** — on ne rogne plus les
7,7 pt latéraux qu'on perdait de chaque côté. `K` passe de 864/2348 à
**874/2348**, les coins du haut prennent le rayon de l'ÉCRAN (55) puisqu'ils le
touchent, et le centre de la pilule se recale à 309.

## 2. ⚠️ LE PIÈGE DU `multiply` : `.clear` EST DU NOIR

*« on voit une sorte de calque léger noir derrière le texte »* — c'était mon
occlusion de contact : `RadialGradient(colors: [.black.opacity(…), .clear])` en
`.blendMode(.multiply)`.

**En prémultiplié, `.clear` vaut (0, 0, 0, 0), et un multiply le lit comme du
NOIR.** Tout le rectangle du dégradé s'assombrissait donc uniformément — y
compris là où on croyait ne rien poser. L'identité du multiply n'est pas la
transparence, **c'est le blanc opaque**. Le stop lointain passe à `.white`.

C'est le cousin exact du piège déjà payé sur `.blur` (« un flou pose un voile
sur tout le rectangle de son hôte ») : un blend ne se raisonne pas en
« invisible », il se raisonne en **élément neutre**.

## 3. TOUT EN ANGLAIS, ET L'ALTERNANCE CONSERVÉE

La page était déjà anglaise partout ailleurs (« Sessions this week », « Weekly
volume », « Your last sessions ») : la phrase d'accueil était la seule pièce en
français, et le mélange se voyait.

- accueil : *Hello Kathryn, / you've done / 4 workouts / this week / out of 3
  planned.* — l'alternance clair/sourd est reprise à la lettre ;
- arrivée : *Alright Kathryn, / slide to start / your session.* — même
  alternance, mais le sourd monte à **0,62** (contre 0,42) : ce bloc atterrit
  sur la BRAISE, pas sur la nuit, et un gris de nuit s'y ferait manger ;
- « Cette semaine. » → « This week. » · « Démarrer » → « Start ».

## 4. ⚠️ LA FLUIDITÉ DES ALLER-RETOURS : CE N'ÉTAIT PAS UNE LENTEUR, C'ÉTAIT UN SAUT

*« ce n'est pas assez fluide si on fait des aller-retours non stop »*.

Un doigt qui se posait en plein film mettait `depart` à nil, et `eNow` retombait
**immédiatement** sur l'état posé : `e` sautait de 0,6 à 1,95 **en une image**.
Plus on jouait, plus on voyait de sauts.

Trois pièces :

- **le gel** — le doigt fige la scène là où elle en est (`eGele`), il ne la
  remet plus à l'état posé ;
- **la reprise continue** — `lancer` recule la naissance de l'horloge de ce qui
  est déjà joué (`Date() − eGele`), donc un aller-retour ne rejoue jamais le
  début du film ;
- **la fermeture proportionnelle** — elle part de `eGele` et sa durée vaut
  `1,25 s × (e/T)`, plancher 30 %. Défaire un quart de film ne peut pas coûter
  le même temps que défaire la fin.

## 5. LA POSE DU TEXTE, LIGNE PAR LIGNE

*« plus cinématique douce type Apple quand le texte arrive en bas »*. Le bloc
revenait au net d'un coup — trois lignes qui redeviennent nettes ensemble, c'est
un interrupteur. Elles se posent maintenant décalées de **0,10 s**, avec 9 pt de
montée résiduelle.

⚠️ Le retard ne joue QUE sur la remontée au net. À la descente les trois lignes
floutent ensemble : décalées, le bloc se déchirerait.

## 6. L'HAPTIQUE

- **au pull** : le franchissement du cran se sent (`.rigid` 0,55 à l'armement,
  `.light` 0,30 au désarmement), une fois par franchissement et **réversible** —
  c'est un armement, pas un commit ;
- **pendant le film** : deux secousses, à **1,30 s** (la pilule touche la
  braise, `.soft`) et **1,86 s** (le slider est prêt, `.light`).

⚠️ Jamais depuis la closure du `TimelineView` : une évaluation de body n'a pas
le droit d'avoir d'effet de bord, elle est rejouée plus d'une fois par image et
on vibrerait en rafale. Elles partent d'`asyncAfter` qui **ne livrent aucune
valeur** — c'est échelonner des ARRIVÉES par des réveils qui est interdit, pas
sentir.

## CE QUI RESTE

**La cadence : 60 % au simulateur** (187 images distinctes sur 311), contre 52 %
avant. C'est le décodage vidéo LOGICIEL du simulateur, pas la partition —
`e` monte régulièrement, vérifié à l'écran. **Ça se juge au téléphone.**

**Le haut de la card reste sombre** quand la pilule est descendue. Arithmétique :
un objet de 258 pt qui descend de 334 dans un cadre de 734 vide le haut. La
portée du foyer l'habite, elle ne le remplit pas.

---

# TOUR 4 — le plan des six derniers fix

## 1. LE CALQUE : IL EST DÉMONTRÉ, ET IL DOIT MOURIR

Elle l'a signalé **deux fois**. Mon premier correctif (`.clear` → `.white`) était
juste mais insuffisant. Le calcul, cette fois :

`RadialGradient(.black.opacity(0.38) → .white, endRadius: 150)` dans un cadre de
**304 × 124**, en `multiply`. Le facteur appliqué au fond, selon la distance au
centre :

| r | facteur |
|---|---|
| 0 | ×0,62 |
| 62 — **le bord haut/bas du cadre** | **×0,63** |
| 150 | ×1,00 |

**Au bord du cadre le fond est encore assombri de 37 %, et il redevient intact
D'UN COUP hors du cadre.** Le dégradé n'atteint le blanc qu'à 150 pt alors que
le cadre s'arrête à 62 : on ne voit pas une ellipse douce, on voit **un
rectangle**. C'est exactement ce qu'elle décrit.

**Verdict : on la supprime.** Trois raisons, et la troisième suffit :
- elle a coûté deux verdicts ;
- sa géométrie est fausse (un dégradé radial ne devient neutre qu'au-delà de son
  cadre) ;
- **elle n'aurait jamais dû exister.** La lumière vient d'EN BAS ; un objet
  au-dessus d'une source ne projette rien sur elle. Je l'ai écrit moi-même dans
  le § 6.2 avant de l'ajouter quand même.

⚠️ La leçon, générale : **un blend ne se raisonne pas en « invisible », il se
raisonne en ÉLÉMENT NEUTRE.** Pour `multiply` c'est le blanc opaque, et il doit
être atteint **avant le bord du cadre**, pas au-delà.

## 2. LE SLIDER S'ALLONGE

Mesuré sur sa capture : la capsule occupe **29 → 372 pt** (cadre 24 → 378).
Elle veut « quasi tout l'écran, s'arrêter aux petites bordures noires ».

`.padding(.horizontal, 24)` → **12**. Cadre 12 → 390, capsule visible ≈ 17 → 385.

Contrôle géométrique : le point le plus à gauche de la capsule est (12, 799) ;
le coin de l'écran a son centre en (55, 819) et 55 de rayon ; la distance vaut
47,4 < 55 — **la capsule reste dans l'écran**, elle ne mord pas sur l'arrondi.

## 3. LES VARIANTES DE TEXTE — 27 premières lignes

Mesurées à **CoreText avec `Inter-SemiBold.otf`**, donc crénage GPOS compris.
Contrôle : « Allez Kathryn, glissez » = **313,1 pt** (le plan annonçait 316 —
l'écart de 2,9 pt EST le crénage).

**Plafond : 300 pt, pas 330.** Deux raisons. (a) La largeur du bloc est
`écran − 72`, donc elle SUIT l'appareil : sur un 375 pt elle tombe à 303, et
tout ce qui dépasse casserait là-bas sans jamais casser sur le 17 Pro. (b) Le
bloc est ancré par le BAS : une ligne qui passe à la ligne le fait grandir VERS
LE HAUT, ce qui déplace la seule ligne qu'on lit.

⚠️ **DEUX RÈGLES D'ÉCRITURE, et elles sont éliminatoires :**
1. **Virgule finale, sans exception.** La ligne 2 commence par un `s` minuscule.
   Un point rendrait le bloc agrammatical : « Be on fire. slide to start your
   session. »
2. **Le test se fait à TROIS lignes, jamais sur la ligne seule.** Écartée sur ce
   seul motif : « Your excuses called, » (298 pt, elle tient) — c'est une amorce
   de blague qui appelle sa chute, et « slide to start » n'est pas sa chute.

**Le sac**, par registre :

| doux | encouragement | défi |
|---|---|---|
| There you are, · Good to see you, · Take your time, · Nothing to prove, · One more, Kathryn, | You showed up, · Be stronger today, · Be a better version, | Beat yesterday, · No excuses today, · Be on fire, · Be badass today, |

| brutal | humour | absurde |
|---|---|---|
| Make it hurt, · Zero mercy today, · Wreck it, Kathryn, | Earn the shower, · The couch will wait, · Nobody's watching, · Feel free to panic, · Legs, we're sorry, | Scare the mirror, · Summon the beast, · Gravity is optional, · The iron misses you, |

Plus **Be sexy today,** et **Be funking badass,** — ses mots, sa graphie, gardés
tels quels.

⚠️ **Sa préférée est impossible deux fois.** « Be more stronger today » fait
**348 pt** (elle déborde) **et** l'anglais est cassé. Substitut proposé :
**« Be stronger today, »** (266 pt). C'est le seul endroit où je réécris ses
mots — **à valider par elle.**

## 4. LES VARIANTES DE BOUTON — 17 libellés

Du plus court au plus long, en points rendus : Start (62) · Begin (57) ·
Send it (74) · Let's go (87) · Unleash (87) · Just start (117) · **Start Hulk**
(118) · **Start Dude** (119) · Beast mode (121) · Slide, killer (128) ·
Start, champ (140) · **Kick your ass** (145) · Start, dammit (147) ·
Start the fire (152) · Wake the beast (164) · Start suffering (173) ·
Start, gorgeous (178).

« Start Kick your Ass » est raccourci en **« Kick your ass »** : le libellé est
centré dans une capsule dont le pouce mange les 90 pt de gauche.

## 5. LA RÈGLE DE TIRAGE

**Un sac mélangé, pas un tirage au hasard.** On tire sans remise ; quand le sac
est vide on le remélange **en interdisant que la première soit la dernière
sortie**. Conséquences : jamais deux fois de suite la même, et on voit les 27
avant d'en revoir une. Un `Int.random` pur redonnerait la même variante deux
fois sur sept.

⚠️ **Le tirage se fait dans `lancer()`, jamais dans un `body`.** Un body doit
rester pur : il est réévalué plusieurs fois par image, et le texte changerait en
plein fondu.

## 6. LE LAG — 152 Mpix/s aujourd'hui, 301 PENDANT LE FILM

Le budget de décodage, calculé :

| | Mpix/image | Mpix/s à 24 i/s |
|---|---|---|
| pilule 1620 × 3522 | 5,71 | **137** |
| braise 540 × 1174 | 0,63 | 15 |
| **total au repos** | | **152** |
| **pendant le film** (`rate` 2,2) | | **301** |

Deux correctifs, et le second est gratuit :

**(a) Rogner chaque calque à sa boîte utile, à la densité de l'écran.** La
pilule n'occupe que les lignes 480..1182 et les colonnes 0..941 du canevas ; et
1620 px de large pour un écran qui en affiche 1206 est un sur-échantillonnage de
1,34× qui ne se voit pas. Résultat : **1051 × 784 = 0,82 Mpix** au lieu de 5,71,
soit **6,9× moins**. Total **27 Mpix/s au lieu de 152 : 5,7× moins.**

**(b) Le `rate = 2,2` double le coût de décodage exactement pendant le film** —
au pire moment possible. Il a été mis pour que les caustiques s'accélèrent
pendant la chute, ce qui est un luxe. **Il passe à 1,0** ; à re-tenter à 1,4
seulement si le budget le permet, mesuré.

**La mesure** : le compte d'images distinctes (60 % aujourd'hui) est un
instrument grossier. On y ajoute le compte de `hasNewPixelBuffer(forItemTime:)`
par seconde et par calque, imprimé au banc — **deux nombres, pas un** — et le
verdict se prend AU TÉLÉPHONE, qui décode en matériel.

## 7. LE PULL INVERSE DOIT SUIVRE LE DOIGT

*« la fluidité au pull aussi, pull inverse »*. Aujourd'hui le doigt **gèle** la
scène (correctif du TOUR 3, qui a supprimé le saut). Mais geler, c'est ne rien
faire : on tire vers le bas et **rien ne bouge** jusqu'au lâcher.

**Le retour doit être une manipulation, pas une lecture.** Tiroir ouvert, un
drag vers le bas pilote `e = T · g` en 1:1 : la pilule remonte sous le doigt, le
texte se refloute, le slider redescend — et on peut changer d'avis à mi-chemin.
Au lâcher, la partition reprend vers l'état décidé.

⚠️ **L'asymétrie est voulue, et c'est la règle d'Apple** : une présentation se
JOUE (l'ouverture reste un film de 1,95 s que le doigt n'accélère pas), un
rejet se MANIPULE (il suit la main). On ne touche donc pas au pull avant.

## LES JALONS

**J11 — le calque.** Occlusion supprimée. Recette : capture à `e = T` avant /
après, différence sur la bande 574..694 ; l'écart doit être **partout du même
signe et sans bord franc** — un `|d(luminance)/dy|` sous 4/255 sur tout le
rectangle 49..353 × 599..723.

**J12 — le slider.** Capsule visible à 17 ± 2 pt du bord, des deux côtés.

**J13 — les variantes.** Les 27 lignes rendues et mesurées au pixel : aucune ne
passe à la ligne, à 402 **et à 375 pt** de large. Le sac : 60 tirages
consécutifs, aucun doublon adjacent, les 27 vues avant la première répétition.

**J14 — le lag.** Calques rognés, `rate` à 1,0. Images distinctes ≥ 85 % au
simulateur, et le compte de pixel-buffers ≥ 22/s par calque. Puis **le
téléphone**.

**J15 — le pull inverse.** Filmé au doigt : le barycentre de la pilule doit
suivre le pouce à ± 6 pt pendant tout le drag descendant.

## TOUR 4 — LIVRÉ, et les trois causes que j'avais ratées

L'enquête indépendante a trouvé mieux que mon diagnostic. Dans l'ordre du poids :

**① LE `rate` À 2,2 TOURNAIT AU REPOS, EN PERMANENCE.** `rate(e) = e < 1.55 ?
2.2 : 1.0` — et au repos `e` vaut **0**, donc 0 < 1,55 → **2,2**. La home
décodait donc 1620×3522 à 52,8 i/s **tout le temps** : **316 Mpix/s**, soit plus
que de la 4K30 (249), en logiciel. Le film ne coûtait rien de plus que le
repos — c'est le repos qui payait le prix du film, en permanence. Ce n'était pas
un réglage, c'était un bug, et il explique « ça lag » **avant même** qu'on tire.
*(Bug jumeau : `preroll(atRate: 1)` remettait le rate réel à 1,0 dans le dos du
garde — selon qui gagnait la course, soit le repos restait à 2,2 pour toujours,
soit le film n'accélérait jamais.)*

**② `verreAt = 0.26` ÉTAIT DÉCLARÉ ET LU NULLE PART.** Le commentaire disait
« le verre est DÉMONTÉ » ; `grep -rn verreAt` ne rendait que sa propre
déclaration. Les deux cards gardaient donc leur `glassEffect(.clear)` **et** leur
gaussienne de 6 pt pendant **1,69 s des 1,95 s** du film, à opacité zéro — et une
capture de fond de verre natif force la résolution en texture de tout le
composite situé dessous, donc de toute la chaîne vidéo, deux fois par image, pour
peindre du vide. **C'est la première cause côté TÉLÉPHONE.** Le dépôt le savait
(MenuCouronne garde son disque par `if p > 0.01`) ; la leçon n'avait jamais été
portée ici.

**③ LA CLOCHE DE 26 pt ÉTAIT POSÉE SUR LE CONTENEUR DE LA PHRASE** — le piège
exact que le fichier dénonce trois lignes plus haut. Elle gonflait les bornes du
calque de ±78 px et floutait **1,47 Mpix par image**, par-dessus la passe de
masque que `PhraseVue` pose déjà. Elle passe sur les GLYPHES (`flouDepart`).

**Le budget, après :** pilule **1094 × 838 = 0,92 Mpix**, braise **604 × 496 =
0,30 Mpix** → **29 Mpix/s contre 316. Onze fois moins.**

⚠️ **Et le compte d'images distinctes n'est plus un instrument valide** : avec le
`rate` à 1,0 la vidéo avance 2,2× moins vite, donc deux images voisines se
ressemblent plus et le compte BAISSE alors que la fluidité monte. Il faut le
compte de `hasNewPixelBuffer` par calque, ou le verdict à l'œil.
