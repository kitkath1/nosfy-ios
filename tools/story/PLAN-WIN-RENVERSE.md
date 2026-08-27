# LA PAGE WIN, VARIANT « LE RENVERSEMENT » — les boosters tombent
# du ciel, la pièce et le mot se posent au sol, et l'or change de métal

**Écrit le 27-08-2026 sur le brief de Kathryn — RIEN n'est codé
(« fais deux plans !! pour des variants spectaculaires. ne code
pas »).** Un DEUXIÈME variant de la page du butin, qui ne remplace
pas le premier : les deux robes coexistent, le choix se fait au
moteur (note backend §4 nonies).

> Le brief : « pareil, faire encore un variant pour WIN avec les
> boosters qui partent du HAUT de la card, et la pièce et WIN EN BAS,
> et changer la couleur de WIN, et changer la couleur du saler. Donc
> deux variants nouveaux à rajouter. »

⚠️ **UNE LECTURE À CONFIRMER** : « le saler » = **le LASER**, c'est-à-
dire le filament rouge/blanc qui passe derrière WIN (il en a
exactement l'allure : un trait de 1,8 pt, un point de lumière blanc
qui glisse dedans, deux lueurs). Tout le §4 est écrit sous cette
hypothèse ; si c'est autre chose, seul le §4 est à refaire. **Q1.**

---

## 1. CE QUI EXISTE — mesuré ligne à ligne

`enum WinCine` + `struct StoryWin`, `Woop/Views/StorySuite.swift:1228-
1999`. Commité (`a9a0290`), cinq tours de verdicts, **76-80 img/s**
mesurés. Le variant CLONE ; on ne touche pas à la robe validée.

### 1.1 La partition et la card

| | valeur |
| --- | --- |
| `cardAt / cardFor` | 0,15 / 0,60 s (entrée finie à 0,75) |
| `pieceAt` | 0,85 s |
| `compteurAt / compteurFor` | 1,30 / 2,20 s (le compteur roule jusqu'à 3,50) |
| `titreAt` | 4,30 s |
| hold de la page | **8,0 s** — toujours la DERNIÈRE |
| card | `l = min(0.80·W, 332)`, `h = 1.32·l`, centre `(0.50·W ; 0.53·H)`, R36 |
| fond | trois paliers `white 0.145@0 / 0.075@0.55 / 0.02@1` |
| arête | 1 pt, blanc 0,18 @0 → 0,05 @0,38 → clear @1 |
| pills or | `story-macro-or.mp4` 1500×1352, `mw = 1.15·W`, ancrée bas, `offset y = mh·0.42`, `plusLighter`, fondu CUIT dans le fichier |

Données : `pieces = series · 20`, `boosters = pieces / 100`,
`roule = pieces · outLong(clamp((t − 1.3)/2.2), 2.6)`. Démo : 18
séries → 360 pièces → 3 boosters → couronne « Big win. ».

### 1.2 Les quatre pièces que le variant déplace ou recolorie

**LE MOT « WIN »** (`motOr`, :1482-1571) — le seul mot GRAVÉ de la
maison : horloge quantifiée **20 Hz** (« recomposer à 60 Hz coûtait
41 img/s »), `font(size: l·0.52, weight: .black)` = 167,2 pt,
tracking `−l·0.018`. Cinq couches empilées :
1. le **halo** : Ellipse `l·1.1 × l·0.55`, RadialGradient
   `(1.0, 0.80, 0.42)` à `0.13 + 0.03·sin(t·0.53)`, `plusLighter` ;
2. l'**ombre interne** : le glyphe en `black 0.45`, offset y **+1,8** ;
3. le **biseau** : le glyphe en `(1.0, 0.94, 0.76)` à 0,85, offset
   y **−1,3** ;
4. l'**encre métal**, SIX paliers avec une **bande de reflet qui
   dérive** — `bande = 0.40 + 0.05·sin(t·0.31)`, période 20,27 s :
   `(1.0,0.90,0.62)@0 · (1.0,0.78,0.38)@bande−0.16 ·
   (1.0,0.93,0.68)@bande · (0.98,0.70,0.26)@bande+0.14 ·
   (0.92,0.44,0.06)@0.86 · (0.62,0.30,0.05)@1` ;
5. **7 nappes** (périodes 3,7/5,3/7,1/4,3/6,7/5,9/8,3 s, sans blur)
   et **9 scintilles** (`pow(sin(πu), 12)`, cercles de 2,4 pt).
Masques : flancs `clear@0 / white@0.30 / white@0.70 / clear@1` ;
traîne à SIX paliers, **la seule traîne longue de la maison**
(`white@0 / 0.92@0.14 / 0.58@0.30 / 0.26@0.48 / 0.08@0.66 /
clear@0.80`). Opacité finale **0,42** (« un peu plus fond de
carte »), `alignment: .top`, `offset y = +6`.

**LE FILAMENT / « laser »** (`filament`, :1425-1461) — monté dans le
FOND de la card, entre le dégradé et le mot (« dans le bloc du mot il
héritait de l'opacité et se noyait ») : `Capsule()` de `l·0.98 ×
1,8 pt`, rouge `(1.0, 0.22, 0.08)`. Le **point de lumière glisse** :
`pic = 0.5 + 0.26·sin(tq·0.47 + 0.6)`, stops `clear@0 / rouge
0.95@pic−0.30 / BLANC PUR@pic / rouge 0.95@pic+0.30 / clear@1`.
Deux lueurs (`shadow rouge 0.9 r8`, `shadow white 0.55 r1.6`),
ondulation `dy = l·0.31 + 5·sin(tq·0.37) + 2·sin(tq·0.83+1.1)`,
bascule `−6° + 2.6·sin(tq·0.29)`, souffle `0.62 + 0.16·sin(tq·0.61)`,
`plusLighter`, horloge 20 Hz.

**LA PIÈCE** (`objets`, :1630-1680) : `piece-or-mini` (PNG 132², la
vidéo est morte — « big beug »), affichée 96×96, base
`(0 ; −h·0.24)`, **placement PERSISTANT** (`revient: false`). Nage de
Lissajous `px = 5.5·sin(t·0.53)`, `py = −(7·sin(t·0.62) +
2.5·sin(t·1.13+0.9))`, tilt ±2,2°, souffle ±2 % ; halo radial
`(1.0, 0.80, 0.42)` à `0.20 + 0.06·sin(t·0.71)`, r 78, cadre
160×160 ; **`PoudrePiece`** (26 grains nés sur un anneau de 44-52 pt,
écart +22, montée −16, vie 1,4-2,8 s) montée DANS son cadre de
220×220 — elle la suit au doigt.

**LA POCHE** (`poche`, :1691-1775) : une couche
`.frame(l × h).clipShape(forme).position(centre)` — les boosters sont
CLIPPÉS par la card (« dans la card, on les voit de moitié »).
`hb = 130`, `wb = 80,77`. `basesB = [(−0.24,−9°), (0.03,+6°),
(0.27,−4°), (−0.09,+11°), (0.15,−12°)]`, **héros = l'index 1**,
repos `h/2 − hb·(héros ? 0.28 : 0.12)`. Montée : `pose =
clamp((roule − (i+1)·100)/30)`, `sortie = (1 − outLong(pose,3))·hb·
0.62` — 80,6 pt cachés sous la coupe au départ, plus un dépassement
de ressort de 6 %. Nage ±18 pt / ±6 pt / ±4,5°. Bornes
`(x: l/2 − wb·0.45, haut: −h/2 + hb·0.62, bas: h/2)`. **Le holo**
s'allume à la prise (`sticker-booster-holo`, AngularGradient cyan →
magenta → or → vert, teinte pilotée par le doigt), **retour à
ressort** au lâcher (0,62 / 0,58).

### 1.3 Trois choses mesurées qu'il faut savoir avant de toucher

1. **Le `plusLighter` à pleine intensité SATURE AU BLANC** (verbatim
   `:1782-1784`) — c'est la loi qui a coûté l'irisation du holo au
   premier jet. Toute recoloration additive se règle en intensité
   RETENUE avec des couleurs SATURÉES.
2. ⚠️ **UN DOUTE À LEVER, JALON W1** : le holo appelle
   `.foregroundStyle(irise)` sur `Image("sticker-booster-holo")`
   (`:1797`, `:1804`) — or ce PNG n'est PAS un template (aucun
   `template-rendering-intent` dans les 15 imagesets du dépôt, zéro
   `renderingMode` dans le code) et ses 36 995 pixels opaques sont
   TOUS blancs. Si `foregroundStyle` est sans effet sur ce bitmap, la
   frise s'allume en BLANC et l'irisation qu'on croit voir vient du
   sticker lui-même. À prouver par une capture avant/après
   `.renderingMode(.template)`, au banc `-winHolo`.
3. **Trois valeurs contradictoires** traînent dans les commentaires
   du mot (« la traîne meurt à ~0,58 », « morte à 0,86 », le code
   dit 0,80) et sur les flancs (« 26 % » écrit, 30 % codé). Le
   variant repart du CODE, et corrige les commentaires au passage.

---

## 2. LE DESSIN DU VARIANT — le ciel donne, le sol reçoit

Le renversement n'est pas un déplacement d'éléments : c'est un
**changement de récit**. Aujourd'hui la page dit « voilà ce que tu as
gagné, et regarde ce que ça ouvre » (le mot en fond, le butin en
poche). Le variant dit **« ça tombe du ciel, et ça se pose à tes
pieds »** : les paquets pleuvent par le haut, la pièce et le mot les
attendent en bas, gravés dans le sol de la card.

```
┌──────────────────────────────┐
│ ▤   ▤▤    ▤       ▤          │  ▤ = booster, suspendu au bord haut,
│  ▤        ▤▤                 │      vu de moitié, saisissable
│                              │
│         +360                 │  le compteur monte au tiers haut
│      pièces gagnées          │
│                              │
│           ◉                  │  la pièce PLANE au-dessus du mot
│  ░░░░ W I N ░░░░             │  le mot GRAVÉ DANS LE SOL,
│  ═══════════════════════     │  le laser posé sur sa ligne de flottaison
└──────────────────────────────┘
```

### 2.1 LES BOOSTERS TOMBENT DU HAUT

- **La poche se retourne** : mêmes bornes de principe, tout est
  miroir vertical — repos `−h/2 + hb·(héros ? 0.28 : 0.12)`, sortie
  `sortie = −(1 − outLong(pose, 3))·hb·0.62` (ils viennent de
  **au-dessus** du bord haut), bornes
  `Bornes(x: l/2 − wb·0.45, haut: −h/2, bas: h/2 − hb·0.62)`.
- **Ils PENDENT, ils ne flottent pas.** C'est la différence de
  nature : un objet suspendu par le haut a un point d'attache. La
  nage devient un **balancement de pendule** — la rotation
  s'amplifie (±7°, période 3,4 s, déphasage `i·2.1`) et la
  translation se réduit (±7 pt en x, ±4 pt en y). L'oscillation
  d'un pendule est en `sin`, pas en `Lissajous` : un seul terme,
  volontairement.
- **L'arrivée** : à chaque franchissement de 100, le booster
  **TOMBE** — `outLong(pose, 3)` remplacé par une chute avec REBOND
  (deux cloches amorties : `1 − (1−u)² ` puis un dépassement de 9 %
  qui s'éteint en 0,22 s), et le grain haptique passe de `.rigid
  0,65` à `.heavy 0,7` : ça pèse.
- **La saisie ne change pas** — même geste d'enfant, même poudre,
  même holo à la prise, même ressort de retour. Ce qui change : en
  tombant vers le bas, le doigt les emmène vers le mot ; **quand un
  booster passe DEVANT le mot WIN, il projette une ombre** (une
  ellipse noire à 0,35, `blur 12`, décalée de 8 pt) — la seule
  ombre portée de la page, et elle prouve que les objets sont
  au-dessus.

### 2.2 LA PIÈCE ET LE MOT AU SOL

- **Le mot** s'ancre en bas : `.frame(l × h, alignment: .bottom)`,
  `offset y = −8`. **Sa traîne se RETOURNE** — les six paliers
  s'inversent (`clear@0.20 / 0.08@0.34 / 0.26@0.52 / 0.58@0.70 /
  0.92@0.86 / white@1`) : il est PLEIN au sol et se dissout en
  montant. C'est ce qui fait « gravé dans le sol » plutôt que
  « posé sur le fond ».
- **La gravure s'inverse aussi** : l'ombre interne passe au-dessus
  (`offset y = −1,8`) et le biseau en dessous (`+1,3`) — une lettre
  creusée dans un sol est éclairée par le haut ; garder l'ordre
  actuel donnerait un mot en RELIEF, pas en creux.
- **L'opacité DESCEND** (et non l'inverse : j'avais tranché à
  l'envers, voir §7.4). Mesuré : le fond passe de `white 0.145` en
  haut à `white 0.02` en bas, donc **le même 0,42 rend le mot ~6×
  plus contrasté au bas de la card**. Trois valeurs au banc
  (0,42 / 0,28 / 0,18) sur une seule image ; recommandation **0,22**,
  Kathryn tranche (Q7).
- **La pièce** descend : base `(0 ; +h·0.14)` = +58 pt (l'ordre
  vertical complet des quatre blocs est chiffré au §7.3, après
  mesure des collisions), juste **au-dessus** du mot, avec `zIndex` au-dessus de lui. Elle garde sa nage de
  Lissajous, son halo et sa poudre — mais son halo se DOUBLE d'une
  **flaque au sol** : une ellipse de lumière (`l·0.42 × l·0.10`,
  radial, même or, 0,10 + 0,04·sin) posée sous elle, qui respire
  avec sa hauteur. Une pièce qui plane au-dessus d'un sol gravé doit
  éclairer ce sol.
- **Le compteur remonte** : le bloc `+360 / pièces gagnées /
  couronne` passe à `offset y = −h·0.10` (−41,5 pt) — assez haut pour
  dégager la tête du mot, assez bas pour rester sous les paquets
  pendus (leur bord bas est à −106 pt). Le §7.3 donne les quatre
  étendues mesurées : sans ce recalage, le mot basculé recouvrait le
  compteur sur 64 pt et la pièce écrasait la couronne.

### 2.3 LA COULEUR DU MOT — trois métaux, un recommandé

La recette d'encre reste la même (six paliers + bande de reflet
dérivante + biseau + gravure + nappes + scintilles) : **seules les
couleurs changent**, ce qui est le geste le moins risqué et le plus
spectaculaire.

**A. LE CHROME IRISÉ — recommandé.** Le mot prend l'iridescence des
pochettes qui tombent du ciel : c'est la page où le butin PLEUT, le
mot doit être fait de la même matière que les paquets.
- encre : un `AngularGradient` bouclé (cyan `(0.05,0.85,1.0)` →
  magenta `(1.0,0.25,0.85)` → or `(1.0,0.78,0.15)` → vert
  `(0.20,1.0,0.45)` → cyan), **angle qui tourne à 6 °/s** (contre
  24 °/s pour le holo au doigt : un mot n'est pas un objet qu'on
  incline), masqué par le glyphe ;
- **par-dessous**, un socle de métal froid en six paliers
  (`white 0.96@0 / 0.72@bande−0.16 / white@bande / 0.58@bande+0.14 /
  0.34@0.86 / 0.18@1`) : l'irisation seule ferait une flaque
  d'essence ; il faut du métal dessous pour que ça reste un mot ;
- l'irisation à **0,45 d'intensité** et le socle plein : la loi du
  `plusLighter` qui sature au blanc a déjà été payée sur la frise ;
- biseau `(0.92, 0.96, 1.0)` (froid), gravure `black 0.50` ;
- nappes recoloriées en `(0.86, 0.94, 1.0)` à 0,46, scintilles en
  blanc pur.

**B. LE PLATINE.** `white 0.98 / (0.86,0.88,0.94) / white 0.92 /
(0.62,0.65,0.74) / (0.34,0.36,0.44) / (0.16,0.17,0.22)`. Sobre,
glacé, très Apple. ⚠️ Il porte un SENS dans cette app : « l'argent,
c'est rare d'en avoir » — un WIN d'argent dirait autre chose que
l'or (une monnaie plus rare, pas seulement une autre couleur). À
n'utiliser que si ce sens est voulu — **Q3**.

**C. LA BRAISE.** `(1.0,0.94,0.80) / (1.0,0.55,0.10) /
(1.0,0.78,0.38) / (1.0,0.40,0.04) / (1.0,0.22,0.02) /
(0.42,0.10,0.02)` — la `FlammePalette` telle quelle, anti-brun
garanti (R = 1,00 tenu, on ne désature que le vert). Le plus chaud,
le plus proche du feu de la maison ; mais c'est presque l'or
d'aujourd'hui, poussé — le moins « nouveau » des trois.

### 2.4 LA COULEUR DU LASER — l'inversion

Si le mot passe au froid (A ou B), **le laser prend l'or** : c'est
l'échange exact des registres, et c'est ce qui rend le variant
lisible en un coup d'œil.

- rouge → **or blanc** : stops `clear@0 / (1.0,0.78,0.38) 0.95@pic
  −0.30 / BLANC PUR@pic / (1.0,0.78,0.38) 0.95@pic+0.30 / clear@1` ;
  lueurs `shadow (1.0,0.72,0.30) 0.9 r8` + `white 0.55 r1.6` ;
- il **descend au sol avec le mot** : `dy = h − l·0.31` (la ligne de
  flottaison du mot, pas celle de la card), même ondulation à deux
  horloges, bascule **inversée** (`+6° − 2.6·sin`) — le trait suit la
  pente du sol, pas celle du ciel ;
- **il double** : un second filament, deux fois plus fin (0,9 pt),
  deux fois plus sourd (0,45), décalé de 9 pt sous le premier et
  d'une phase de +2,1 rad — un laser réel a sa réflexion. C'est le
  micro-détail qui vaut le plus cher à l'œil pour ce qu'il coûte.

Variante si le mot reste chaud (C) : le laser passe au **cyan
électrique** `(0.20, 0.90, 1.0)` — le seul froid de la scène, il
crie sur la braise (l'école du néon vert de la mini-card TOP).

### 2.5 CE QUI NE BOUGE PAS

La pills or ancrée bas (son fondu est CUIT dans le fichier — jamais
un masque par image sur une vidéo), le fond gris → noir en trois
paliers, l'arête, l'entrée de la card, les quatre gabarits de
couronne, les haptiques de plaquage et de saisie, le rect publié au
chef d'orchestre. **Le hold reste 8,0 s** et la page reste la
DERNIÈRE de la story (§4 octies : le butin ferme toujours).

---

## 3. LES JALONS

- **W1 — LE DOUTE DU HOLO** (avant tout le reste) : prouver ou
  infirmer que `.foregroundStyle` colore `sticker-booster-holo`.
  Capture au banc `-winHolo`, avant/après `.renderingMode(.template)`,
  mesure de teinte sur les pixels clairs. Si le doute est fondé,
  c'est un correctif qui profite AUSSI à la robe actuelle.
- **W2 — la robe** : `enum RobeWin { case poche, renverse }`,
  `.poche` par défaut, banc `-winRenverse`. Rien d'autre : capture
  des deux robes côte à côte pour prouver que l'existante n'a pas
  bougé d'un pixel.
- **W3 — le renversement géométrique** : poche en haut (chute +
  rebond + pendule), compteur au tiers haut, mot au sol (traîne et
  gravure inversées), pièce basse + flaque de lumière. Film.
- **W4 — les métaux** : les trois encres A/B/C au banc, côte à côte
  sur capture, **teinte et saturation mesurées sur les pixels
  clairs** (jamais en moyenne de ligne — la règle payée) ; verdict
  de Kathryn sur une seule image.
- **W5 — le laser** : la nouvelle couleur, la descente au sol, le
  second filament de réflexion.
- **W6 — l'ombre portée** des boosters sur le mot (le détail qui
  prouve la profondeur), et le rebond de chute.
- **W7 — fouettage** : détecteur de flash, cadence `mpdecimate` sur
  la fenêtre localisée à la planche-contact. **Budget : ≥ 75 img/s**
  (la robe actuelle tient 76-80 ; l'`AngularGradient` du chrome est
  masqué par le glyphe et tourne à l'horloge quantifiée 20 Hz, il
  ne doit rien coûter — à PROUVER, pas à supposer).
- **W8 — verdicts téléphone** + note backend §4 nonies.

## 4. LE BACKEND (§4 nonies, à écrire pour les deux variants)

Rien ne change au contrat du butin (§4 sexies : 1 booster = 100
pièces, conversion cumulée avec report, crédit idempotent au settle,
« vu = enregistré », profil = solde ouvrable). Le variant est une
ROBE.

Ce qu'il faut ajouter, pour les DEUX plans du jour :

```
robes:
  story_card: rangee | colonne        (§ PLAN-STORY-CARD-COLONNE)
  butin:      poche   | renverse      (ce plan)
```

- le choix est au MOTEUR, jamais au client, et il est **stable pour
  une séance donnée** (la story rejouée montre la même robe : une
  robe qui change à la relecture donne l'impression d'un bug) ;
- il se calcule au `settle_session` et se stocke avec la séance,
  comme tout le reste ;
- règle de choix à trancher (**Q5**) : alternance stricte, tirage
  par hash du `session_uuid`, ou un FAIT (par exemple : le
  renversement les jours où le butin dépasse 3 boosters — le ciel
  s'ouvre quand il y a beaucoup à donner) ;
- l'IA n'entre pas ici : une robe n'est pas un mot.

## 5. À TRANCHER PAR KATHRYN

1. **« le saler » = le laser (le filament derrière WIN) ?** Tout le
   §2.4 en dépend.
2. **La couleur du mot** : chrome irisé (proposé), platine, ou
   braise ?
3. Si platine : **assume-t-on le sens « argent = rare »** (le variant
   deviendrait la robe des grosses séances) ?
4. **La pièce** : garde-t-elle son placement PERSISTANT (elle reste
   où on la pose, comme aujourd'hui) maintenant qu'elle est au sol,
   ou revient-elle à sa place comme les boosters ?
5. **Le déclencheur des robes** : alternance, hasard stable, ou un
   fait (≥ 3 boosters) ?
6. **Le compteur** : au tiers haut derrière les paquets qui pendent
   (proposé), ou reste-t-il au centre, les paquets s'arrêtant plus
   haut ?

## 6. LES PIÈGES QUI S'APPLIQUENT (déjà payés)

- **Le `plusLighter` à pleine intensité sature au blanc** — la
  recolorisation du mot et du laser se règle en intensité retenue.
- **L'anti-brun** : R = 1,00 tenu, on désature le VERT, jamais on ne
  remonte le bleu (six sites documentés dans le dépôt).
- **Un uniforme / une valeur porte souvent DEUX rôles** : `bande`
  pilote le reflet du métal ; la recolorier sans regarder ses trois
  usages (deux `location` clampées + la couleur du milieu) donne un
  dégradé qui se retourne.
- **Le masque par image sur une vidéo coûte la cadence** : la pills
  garde son fondu CUIT.
- **`-storyAuto` BOUCLE** : la fenêtre de la page se localise à la
  planche-contact (0,5 img/s), jamais à l'horloge — une mesure prise
  à l'horloge a déjà donné « 50 img/s » sur la mauvaise page.
- **Une Canvas rasterise toute sa surface même vide** : `PoudreDoigt`
  reste conditionnée aux grains.

---

## 7. RELECTURE ADVERSE — les collisions, chiffrées (27-08)

Un agent de relecture a passé le plan au code. Rien n'est refusé,
mais **trois chiffres changent le dessin** et un quatrième renverse
une décision que j'avais prise à l'envers.

### 7.1 LE CLAMP AURAIT MANGÉ LE RENVERSEMENT — confirmé

Les bornes actuelles sont `Bornes(x: l/2 − wb·0.45, haut: −h/2 +
hb·0.62, bas: h/2)` : `haut` vaut **−126,89 pt**. Un booster posé au
miroir (`base.y = −h/2 + hb·0.28` = −171,09) serait ÉCRASÉ par le
clamp à −126,89 — **44,2 pt plus bas que voulu, et il ne dépasserait
jamais du bord haut.** Le §2.1 posait déjà le miroir exact
(`haut: −h/2`, `bas: h/2 − hb·0.62`) et l'inversion du signe de
`sortie` : les deux sont OBLIGATOIRES, pas optionnels.

### 7.2 « ON LES VOIT DE MOITIÉ » N'A JAMAIS ÉTÉ VRAI — à re-poser

Au repos, il ne manque que **28,60 pt sur 130** au héros (22 %) et
**49,40 pt** aux autres (38 %) : le « de moitié » du verdict décrit
la borne basse, pas la pose. En haut, la question doit être posée
**en points, pas en fraction** — combien de chaque paquet doit rester
sous le plafond ? (Proposition : 34 pt pour le héros, 52 pt pour les
autres — le miroir exact de l'existant, qui a été validé à l'œil.)

### 7.3 LES TROIS BLOCS DU BAS SE COGNENT — le §2.2 est rectifié

Mesuré (à l = 314,40 / h = 414,98, en points autour du CENTRE de la
card) :

| bloc | étendue si on le bascule tel quel |
| --- | --- |
| le mot, `alignment: .bottom` | **[+12,9 ; +207,5]** (hauteur de ligne ≈ 194,6 pt) |
| la pièce au miroir (`+h·0.24`) | [+51,6 ; +147,6] |
| le compteur actuel (`offset y = h·0.07`) | [−18,9 ; +77,0], la couronne seule à [+61,5 ; +77,0] |

→ le mot recouvrirait le compteur sur **64 pt** et TOUTE la couronne ;
la pièce au miroir recouvrirait la couronne **intégralement**.
« En bas » ne suffit pas : il faut un ordre vertical.

**L'ordre tranché** (à valider sur capture au jalon W3) :

| | place | étendue |
| --- | --- | --- |
| les paquets | pendus au plafond | [−207,5 ; −106] |
| le compteur + sous-titre + couronne | `alignment: .center`, `offset y = −h·0.10` = **−41,5** | [−89 ; +7] |
| la pièce | base `(0 ; +h·0.14)` = **+58** | [+10 ; +106] |
| le mot | `alignment: .bottom`, `offset y = −8` | [+12,9 ; +207,5] |

La pièce chevauche donc la tête du mot — **c'est voulu** : elle plane
au-dessus de la gravure, comme aujourd'hui elle plane devant. Le
compteur remonte juste assez pour dégager la tête du mot, et reste
sous les paquets (leur bord bas est à −106).

### 7.4 L'OPACITÉ DU MOT — j'avais tranché À L'ENVERS

J'avais écrit « l'opacité monte de 0,42 à 0,50 ». **La mesure dit le
contraire.** Le fond de la card va de `white 0.145` en haut à
`white 0.02` en bas ; le stop le plus clair du métal est 0,93. Sur le
canal vert :

- en haut (fond 0,145) : `0,145 + 0,42·(0,93 − 0,145)` = 0,475 →
  **rapport 3,3×** ;
- en bas (fond 0,02) : `0,02 + 0,42·(0,93 − 0,02)` = 0,402 →
  **rapport 20×**.

**Le même 0,42 rend le mot ~6× plus contrasté au bas de la card.** Le
verdict « un peu plus fond de carte » (qui avait fait descendre 0,46
→ 0,42) serait annulé par le simple déménagement. Pour retrouver
exactement le rapport d'aujourd'hui il faudrait descendre à ~0,05 —
autant dire que ce ne serait plus un mot.

**Ce qu'il faut faire** : ne pas deviner, MESURER sur capture. Trois
valeurs au banc (0,42 / 0,28 / 0,18) sur une seule image, et Kathryn
tranche. Ma recommandation : **0,22** — le mot reste « du fond »
(rapport ≈ 11×, deux fois plus présent qu'aujourd'hui, ce qui est
justement l'intention d'un mot GRAVÉ DANS LE SOL), sans devenir un
titre. **Q7.**

### 7.5 LA RECOLORATION TOUCHE PLUS QUE LE MOT

Dans le seul bloc du mot, **10 littéraux** : les 6 stops du métal, le
halo `(1.0, 0.80, 0.42)`, le biseau `(1.0, 0.94, 0.76)`, la nappe
`(1.0, 0.90, 0.62)`, la scintille `(1.0, 0.97, 0.88)` — l'ombre
interne restant noire. **Hors du mot, deux ors lui répondent** : la
couronne `(1.0, 0.84, 0.55)` à 0,72 et le badge « ×N » des boosters
(dégradé blanc chaud → or). Suivent-ils le mot, ou restent-ils or
pour garder le lien avec la pièce et la pills ? **Q8.**
Ma recommandation : **ils restent OR** — la page reste dorée par ses
OBJETS (la pièce, la pills, le badge), et le mot devient l'exception
froide qui les fait ressortir. C'est plus fort qu'un camaïeu.

⚠️ Et une contrainte physique : le halo, les 7 nappes et les 9
scintilles sont en `.plusLighter`. **Une couleur FROIDE en additif
sur un fond gris vire au blanc bien plus vite qu'un or** (la loi
mesurée sur la frise holo : « à pleine intensité le plusLighter
SATURE AU BLANC »). La recolorisation ne se fait donc PAS à valeurs
constantes : les intensités du chrome devront être retenues d'un
tiers environ, à régler à la sonde sur les pixels clairs.

### 7.6 LE CALENDRIER DE LA PAGE — 5,35 s de plan fixe

La sortie des paquets est pilotée par `roule`, pas par `t` : sur la
démo (360 pièces, 3 boosters) ils sont pleins à **1,65 / 2,01 /
2,65 s**. Le compteur finit à 3,50 s, la couronne entre à 4,30 s, la
page dure 8,0 s. **Tout est posé à 2,65 s : il reste 5,35 s de plan
fixe** que seuls le mot recoloré, le laser et la nage doivent tenir.
C'est l'argument le plus fort pour le second filament de réflexion
(§2.4) et pour l'ombre portée des paquets (§2.1) : sans eux, la
seconde moitié de la page ne raconte plus rien.

### 7.7 LE DOUTE DU HOLO — VÉRIFIÉ MOI-MÊME, il tient

Le contrôle a affirmé que le code montait l'irisé « par `.mask`, pas
par `foregroundStyle` », ce qui aurait clos le sujet. **J'ai lu les
lignes : c'est faux.** `StorySuite.swift:1793-1805` :

```swift
Image("sticker-booster-holo")
    .resizable().scaledToFit()
    .frame(width: wb, height: hb)
    .foregroundStyle(irise)        // ← ligne 1797 (et 1804)
```

`.foregroundStyle` sur une `Image` bitmap **non template** (aucun
`template-rendering-intent` dans les 15 imagesets, zéro
`renderingMode` dans tout le dépôt), dont les 36 995 pixels opaques
sont TOUS blancs. Le jalon **W1 tient** : capture au banc `-winHolo`,
avant/après `.renderingMode(.template)`, teinte mesurée sur les
pixels clairs. Si le doute est fondé, le correctif profite d'abord à
la robe ACTUELLE.

### 7.8 LES DEUX DÉFAUTS HÉRITÉS

1. **La poudre du doigt meurt en cours de geste** : plafond de 90
   grains posé dans `onChanged`, ménage fait UNIQUEMENT dans
   `onEnded` → à 60 rappels/s, un drag de ~1,5 s sature et la poudre
   s'éteint. Le variant B, avec deux objets de plus en haut,
   l'atteindra plus vite. Correctif (commun aux deux plans) : ménage
   aussi dans `onChanged`, une fois toutes les 10 insertions.
2. **Un objet saisi pendant la pause est un état non spécifié**
   (`paused` n'est lu que par les couches vidéo ; les Canvas et le
   gyro continuent). À trancher au jalon W3.

### 7.9 Ce que le contrôle laisse ouvert

- **La hauteur rendue des glyphes n'est pas mesurée** : toutes les
  étendues du §7.3 reposent sur une hauteur de ligne SF de 1,19 em.
  Une seule capture au banc les convertit en points vrais — c'est le
  premier geste du jalon W3, avant de déplacer quoi que ce soit.
- **Aucun verdict téléphone** n'existe pour cette page : les 76-80
  img/s sont au simulateur, où l'app est aveugle aux gels Metal.
- **Aucun banc ne sait filmer un drag** : la saisie des paquets
  pendus se juge AU DOIGT.

---

## 8. CE QUI EST CODÉ (27-08, sur « oui c'est laser ! chrome irisé stp »)

`RobeWin { poche, renverse }` sur `StoryWin`, `.poche` par défaut,
banc **`-winRenverse`**. La robe validée n'est touchée par aucune
valeur : chaque branchement porte son ternaire.

1. **La poche au plafond** : `repos = −h/2 + hb·(héros ? 0.28 : 0.12)`,
   `sortie = −(1 − montée)·hb·0.62`, bornes MIROIR (`haut: −h/2`,
   `bas: h/2 − hb·0.62`) — sans elles le clamp écrasait la pose de
   44,2 pt (§7.1).
2. **La chute avec rebond** : `1 − (1−pose)²` plus une cloche amortie
   `0.09·sin(π·min(1, 1.6·pose))·e^(−4·pose)` — une arrivée molle
   serait un vol, pas une chute.
3. **Le pendule** : suspendu, l'objet a un point d'attache — UN seul
   terme (`sin(1.85·t + φ)`), rotation ±7°, translation ±7 x / ±4 y.
   La nage de Lissajous appartient à ce qui flotte.
4. **L'ombre portée** sur le mot, la seule de la page : son alpha suit
   la hauteur du paquet. **Un DÉGRADÉ, jamais un `blur`** — trois
   flous par image coûtaient 14 img/s (mesuré 42 contre 56).
5. **Le compteur remonte** à `−h·0.10`, **la pièce descend** à
   `+h·0.14` avec sa FLAQUE de lumière au sol (elle éclaire la
   gravure sous elle), **le mot s'ancre en bas** (`alignment:
   .bottom`, `offset −8`), **traîne et gravure INVERSÉES**.
6. **Le chrome irisé** : socle de métal FROID à six paliers +
   **deux passes croisées** — l'arc angulaire qui tourne à 6 °/s et
   une bande linéaire qui descend en sens inverse. C'est leur
   CROISEMENT qui fait le chrome ; une seule nappe faisait un
   dégradé. Halo, nappes et biseau passent au froid, RETENUS (une
   couleur froide en additif sature au blanc plus vite qu'un or).
7. **Le laser en or**, descendu au sol, bascule inversée, **plus sa
   RÉFLEXION** : 0,9 pt, 0,45 d'alpha, 9 pt sous le fil, et son point
   de lumière court en SENS INVERSE.
8. **La couronne et le badge ×N restent OR** : la page reste dorée
   par ses OBJETS, le mot est l'exception froide qui les fait
   ressortir (Q8 tranchée dans ce sens).

### Ce que la mesure a corrigé en cours de route

| | valeur |
| --- | --- |
| irisation à 0,45 (1er jet) | invisible — 0,45 × 0,28 d'opacité finale = **0,13 effectif**, le mot rendait GRIS |
| irisation à 0,95 + 2ᵉ passe | **dispersion de teinte 129°** (l'or de la robe poche : 23°) — le chrome se LIT |
| opacité du mot | 0,22 → **0,28** (rapport de contraste mesuré 13,7× contre 6,7× pour la robe poche : ~2× plus présent, c'est l'intention d'une gravure au sol) |
| cadence | 42 img/s (1er jet) → **69** après le remplacement des trois `blur` par des dégradés (robe poche mesurée à 56 dans la même session — le Mac était chargé) |

⚠️ **LE TYPE-CHECKER A MORDU, une fois de plus** : un ternaire entre
DEUX littéraux de six `Gradient.Stop` a fait passer le build à plus
de dix minutes. Les deux tables vivent maintenant dans
`metalStops(bande:froid:)`, et TOUS les ternaires ont été hissés hors
des littéraux (halo, nappes, flaque, chute, pendule). **La loi « tout
est pré-typé » vaut aussi pour les tables de couleurs.**

RESTE : le verdict au doigt (la saisie des paquets pendus), la
SondeCadence téléphone, et W1 (le doute du holo — non traité ici,
il concerne la robe actuelle).
