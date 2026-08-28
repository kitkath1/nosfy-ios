# LE BOOSTER NOIR — le manège des légendaires

**Écrit le 28-08-2026, sur le brief de Kathryn** : *« un variant booster
noir qui permettra d'ouvrir les légendaires : si l'user collecte une pièce
noire il peut ouvrir ce fameux booster — donc même expérience que le
carrousel de base, mais noir »*. Assets **reçus** le 28-08 (bureau) : **`face_booster_noir.png`**
et **`dos_booster_noir.png`** — voir §2.4, ils sont **baked** :
`booster-noir-color.png` + `booster-noir-emiss.png` sont dans `Woop/Media`.

**TRANCHÉ par Kathryn le 28-08** : manège noir **SÉPARÉ** (« on n'aura
jamais les deux ensemble ») · la cérémonie **GARDE LA BRAISE** · le prix
est **UNE PIÈCE NOIRE, pas plus**.

Rien n'est codé. La règle backend qui en découle est écrite dans la grosse
note : [../rewards/PLAN-REWARDS-BACKEND.md](../rewards/PLAN-REWARDS-BACKEND.md)
**§4 decies**. Le parcours jaune, lui, ne bouge pas d'un pixel :
[PARCOURS-BOOSTER.md](PARCOURS-BOOSTER.md) · [SUPABASE-PIPELINE.md](SUPABASE-PIPELINE.md).

> **LA LOI DU VARIANT** — « même expérience, mais noir ». Aucune mécanique
> neuve : le manège, l'engagement, la charge au maintien, la découpe de
> braise, le Sacre et l'accueil au profil sont **le même code**. Ce qui
> change est une **ROBE** (trois textures) et une **PORTE D'ENTRÉE** (la
> pièce noire au lieu des 20 pièces jaunes). Tout le reste qui change
> serait une régression du Sacre, pas un variant.

---

## 1. Ce qui existe, mesuré dans le code (l'état des lieux)

| pièce | où | ce qu'elle fait |
| --- | --- | --- |
| `BoosterScene.init?(still:mylar:gallery:)` | [BoosterPack.swift:338](../../Woop/Views/BoosterPack.swift#L338) | monte le maillage `booster.bin`, la matière, l'anneau, le sol, la caméra |
| la matière | [BoosterPack.swift:356-401](../../Woop/Views/BoosterPack.swift#L356-L401) | `diffuse = booster-color`, `emission = booster-emiss` (0,6), `normal` + `clearCoatNormal = booster-normal` |
| l'anneau | [BoosterPack.swift:582-604](../../Woop/Views/BoosterPack.swift#L582-L604) | **10 clones** (`ringCount = 10`), matières COPIÉES du sachet, uniformes re-semés |
| le studio | [BoosterPack.swift:641-690](../../Woop/Views/BoosterPack.swift#L641-L690) | key light chaude (1,00/0,93/0,85), omni braise (1,00/0,45/0,15), sol `multiply` orangé |
| l'hôte SwiftUI | [BoosterStage:1225](../../Woop/Views/BoosterLab.swift#L1225) | passe `still / mylar / gallery / cine / forge / panOnly / muet` au coordinateur |
| le flow | [BoosterLab:481](../../Woop/Views/BoosterLab.swift#L481) | `appMode: true` = le Sacre monté au-dessus du TabView |
| le montage | [WoopApp.swift:1027-1075](../../Woop/WoopApp.swift#L1027-L1075) | `BoosterPopupHote` (zIndex 6) puis `BoosterLab(appMode:)` (zIndex 7) |
| l'état | `SacreEtat` [BoosterPopup.swift:24](../../Woop/Views/BoosterPopup.swift#L24) | `popupOuverte`, `manegeOuvert`, `manegePose`, `boostersEnAttente`, `arriveeDemandee` |
| la carte | `ForgeServeur.tirer` [BoosterLab.swift:2216](../../Woop/Views/BoosterLab.swift#L2216) | l'edge function `forge-card` tire **common 60 / rare 27 / epic 10 / legendary 3** |

**Six familles `legendary` existent déjà** au catalogue
([LuneForge.swift:102-119](../../Woop/Services/LuneForge.swift#L102-L119)) :
Le démon en majesté · La vallée souveraine · L'oiseau souverain · Le dragon
de braise · Le cerf d'obsidienne · La lune souveraine. **Le booster noir
n'invente aucune carte** — il force le registre qui existe.

---

## 2. LA ROBE — un paramètre, trois textures, zéro mécanique

### 2.1 Le paramètre

```swift
enum RobeBooster { case lune, noire }        // .lune = l'actuel, défaut
```

Il descend, et il ne fait QUE choisir des noms de fichiers :

```
WoopApp  →  BoosterLab(appMode:robe:)  →  BoosterStage(robe:)
                                       →  BoosterScene(still:mylar:gallery:robe:)
                                       →  material() : Self.image(robe.color / robe.emiss)
```

Banc : **`-boosterNoir`**, sur le patron exact de `-boosterMylar`
([BoosterLab.swift:484](../../Woop/Views/BoosterLab.swift#L484)) — il se
combine avec `-boosterGallery`, `-boosterCine`, `-boosterStill`.

⚠️ **La normal map ne change pas.** `booster-normal` décrit les PLIS du
maillage, pas le dessin : même sachet, mêmes froissures. Un second fichier
serait 132 Ko et un risque de désaccord entre la laque et le vernis
(`clearCoatNormal` lit la même image).

### 2.2 L'atlas — les rectangles sont MESURÉS

`booster-color.png` est un atlas **2048²** qui porte les deux peaux côte à
côte (le reste est du noir pur) :

| panneau | colonnes | lignes | taille |
| --- | --- | --- | --- |
| **FACE** (le croissant, la lune) | **722 → 1317** | **57 → 1989** | 596 × 1933 |
| **DOS** (la trame de croissants) | **1428 → 2023** | **57 → 1989** | 596 × 1933 |

Le fond émissif suit la même grille, un peu rentré (c'est le liseré néon) :
FACE `x ∈ [740, 1293]`, `y ∈ [175, 1821]` ; DOS `x ∈ [1447, 2003]`,
`y ∈ [172, 1821]`.

**Le bake** (`tools/sacre/bake_booster_noir.py`, à écrire) :

1. partir de l'atlas actuel comme GABARIT (il porte les sertissages
   crantés du haut et du bas, qui appartiennent au sachet et pas au
   dessin) ;
2. remettre à l'échelle `face_booster_noir` dans le rect FACE et
   `dos_booster_noir` dans le rect DOS, **sans changer leur ratio** — le
   nœud porte déjà une échelle `(0,75 · 1 · 0,45)` qui rend au dessin ses
   proportions natives ([BoosterPack.swift:567-575](../../Woop/Views/BoosterPack.swift#L567-L575)) :
   un dessin étiré au bake ressortirait ovale à l'écran ;
3. écrire `booster-noir-color.png` (2048², sRGB, sans alpha) ;
4. l'émissive : si ses images portent des néons, les extraire par seuil de
   luminance + flou léger dans les mêmes rects → `booster-noir-emiss.png` ;
   si le booster noir est MUET (aucun néon), une émissive quasi noire suffit
   — mais **jamais un fichier absent** : `emission.contents = nil` change la
   matière, et `moonCharge` / `lipGlow` / la braise de découpe s'écrivent
   par-dessus l'émissive.
5. **Vérification obligatoire à l'œil** : `-boosterLab -boosterNoir` figé
   (`-boosterStill -boosterYaw 180` puis `-boosterYaw 0`) — recto et verso,
   liseré aligné sur le bord du sachet, sertissage continu.

### 2.4 LES ASSETS REÇUS — et ce qu'il a fallu composer (28-08)

| fichier | taille | ce que c'est |
| --- | --- | --- |
| `face_booster_noir.png` | 1024 × 1536 | **un sachet COMPLET** : sertissages, liseré **IRISÉ** (foil arc-en-ciel, écart RVB mesuré 50,6 sur les pixels clairs), croissant en relief débossé, deux étoiles. Silhouette x 111→913, y 73→1463 (ratio 0,577 — le jaune fait 0,572 : même grille) |
| `dos_booster_noir.png` | 941 × 1672 | **une TRAME SEULE**, plein cadre : ni bord, ni liseré, ni sertissage. Traits gris neutres (écart RVB 10,1) |

⚠️ **Le dos noir n'est pas un dos de sachet.** Le jaune (`dos_booster.png`)
était un sachet entier ; le noir est une étoffe. Étirée telle quelle sur le
panneau, elle donnait un dos SANS bord et SANS sertissage — or les
sertissages sont **imprimés dans la texture** (le maillage en a le relief,
pas le dessin). **Le dos est donc COMPOSÉ** : la menuiserie (sertissages +
liseré irisé + bords) vient de la FACE noire, la trame remplit l'intérieur,
à son échelle de motif (couverture, jamais d'étirement — un croissant ovale
se verrait).

Le masque de l'intérieur a coûté trois passes, toutes gardées en commentaire
dans le script : la propagation depuis le centre **fuit** par les brèches du
liseré (coins coupés, languettes) et mange tout le sachet ; et le premier
pixel clair d'une colonne n'est PAS le liseré mais une **dent du
sertissage**, qui accroche la lumière — le masque montait dans le
sertissage et y semait des croissants. La forme juste : suivre le **rail**
gauche/droite ligne par ligne, et prendre l'étendue verticale du cadre là où
ce rail existe.

**L'émissive est CALIBRÉE sur le jaune, pas choisie au jugé.** Le liseré
jaune est un néon (il émet), le noir est un foil (il réfléchit) — mais une
émissive nulle ferait disparaître un sachet noir sur un sol d'encre. Une
première passe rendait une émissive **trois fois plus chaude que le néon**
(moyenne 2,5 / p99 97, contre 0,80 / 38 pour `booster-emiss`). Seuil 95 +
force 0,42 : **moyenne 0,81, p99 33** — le même profil, donc
`emission.intensity = 0,6` reste valable sans retoucher la matière.

Le bake est rejouable : `python3 tools/sacre/bake_booster_noir.py`
(planches de verdict dans `tools/sacre/noir/preview-*.png`).

⚠️ **Les deux fichiers vont dans `Woop/Media`, en ressources NUES.**
`Image("booster-noir-color")` ne trouve RIEN et ne dit rien (piège payé,
[BoosterPopup.swift:635-641](../../Woop/Views/BoosterPopup.swift#L635-L641)) :
le chargement passe par `Bundle.main.path(forResource:ofType:)`, comme
aujourd'hui.

### 2.3 LE COÛT — à payer AVANT d'ajouter une robe

`BoosterScene.init` **décode ~36 Mo de textures SANS CACHE à chaque
construction** — c'est écrit et mesuré dans
[WoopApp.swift:1260-1266](../../Woop/WoopApp.swift#L1260-L1266) (129 ms
rendus, le four qui cuisait deux fois). Une deuxième robe double la
surface de ce trou.

**Le remède, deux lignes, avant tout le reste** : un cache
`[String: UIImage]` dans `BoosterScene.image(_:)`. Le four
([WoopApp.swift:1290](../../Woop/WoopApp.swift#L1290)) garde tout son sens :
les **pipelines Metal sont les mêmes** (mêmes shader modifiers, seules les
textures changent) — il n'y a pas de second four à allumer.

---

## 3. L'ANNEAU : noir SÉPARÉ — **TRANCHÉ** (« on n'aura jamais les deux ensemble »)

Les 10 clones de l'anneau naissent d'une COPIE de la matière du sachet
([BoosterPack.swift:585-598](../../Woop/Views/BoosterPack.swift#L585-L598)),
et les tableaux d'état de la galerie (`galleryLight`, `moonLight`) sont
indexés par position, pas par identité de sachet.

**Verdict 28-08** : le manège noir est un `BoosterScene` monté avec
`robe: .noire`. **Zéro ligne à changer dans la galerie.** Deux réserves,
deux portes, deux manèges — *« même expérience, mais noir »* à la lettre.

L'anneau MIXTE est écarté, et c'est ce qui rend le chantier court : il
aurait demandé une matière PAR CLONE (deux jeux de textures vivants en
mémoire), une table robe-par-slot, et la rareté qui suit le slot engagé
jusqu'à la forge — le manège serait devenu un inventaire.

---

## 4. LA PORTE D'ENTRÉE — la pièce noire

Aujourd'hui : la proposition (`SacreEtat.proposer()`) ouvre le panneau
« Un booster t'attend ! / Une carte du set Lune dort à l'intérieur », le
diamant « Ouvrir un Booster » monte le manège, et la pill du profil
(`PillBooster`) est la porte de récupération.

Le noir emprunte **le même chemin**, avec sa robe :

```swift
SacreEtat.robeCourante: RobeBooster       // ce que le manège doit porter
SacreEtat.proposer(robe:)                 // .lune par défaut
SacreEtat.ouvrirManege(robe:)             // la séquence panneau→scène inchangée
SacreEtat.boostersNoirsEnAttente          // la 2ᵉ réserve (maquette, puis user_boosters)
```

Ce que le noir doit avoir à lui :

1. **les mots** du panneau — le set Lune n'est plus le sujet, la
   LÉGENDAIRE l'est. Proposition : *« Une pièce noire ouvre ce booster. »*
   / *« Une carte LÉGENDAIRE dort à l'intérieur. »* (verdict Kathryn) ;
2. **la vignette** : `booster-pill.png` (120×214) est un rendu du sachet
   jaune. Il en faut un noir — même recette, même cadrage, `booster-pill-noir.png` ;
3. **la pill du profil** : soit une deuxième pill à côté (elle porte la
   vignette noire), soit la même pill avec une pastille — la deuxième
   réserve doit se VOIR, sinon un booster noir gagné et non ouvert
   disparaît ([ProfilLune.swift:535](../../Woop/Views/ProfilLune.swift#L535)) ;
4. **le tell** : `-boosterShiny` fait FUIR la lumière de la fente
   (`lipGlow` qui pulse, [BoosterPack.swift:408-424](../../Woop/Views/BoosterPack.swift#L408-L424)).
   Un booster noir contient TOUJOURS une légendaire : le tell y est
   **allumé par construction**, pas par un drapeau de banc. C'est la
   promesse qu'on tient avant le premier geste.

---

## 5. LA CÉRÉMONIE — ce qu'on ne touche pas, ce qu'on peut teinter

**Intouchable** (c'est l'expérience) : l'aimantation du manège, la
pichenette, le dolly-zoom d'engagement, la charge au maintien, la découpe
de braise sous le doigt, la sortie sans un tour, le Sacre de la carte
vivante, le balayage d'envol, l'accueil au profil, le berceau (jamais
d'euler au lacet π).

**LE VERDICT A CHANGÉ DEVANT LE RENDU, ET C'EST LA LEÇON DU JOUR.** Le
matin : « le noir garde la braise » — donc aucune palette à écrire. Le
premier manège noir construit sur cette base : *« pas de halo orange mais
noir stp très dark, il est trop orange, j'aime pas : mets noir un peu
violet si tu veux et blanc »*, puis *« les boosters doivent être noirs et
l'écosystème aussi »*.

**Pourquoi la braise ne pouvait pas tenir** : un albédo d'encre ne rend
que ce qu'on lui envoie. Le sachet du set Lune a ses NÉONS DESSINÉS — il
reste noir sous une lumière orange parce que sa lumière à lui est dans la
texture. Le sachet noir n'a rien de tel : il prend l'orange en plein, et
la braise le repeint en ambre. On ne le voyait pas sur la maquette à plat.

**Ce qui existe donc maintenant** : `RobeBooster.PaletteStudio`, une
palette portée par la robe — clé, omni du bas et son échelle, `multiply`
du sol, poudre, et l'horizon de l'environnement HDR (un `.hdr` cuit par
robe, `booster-studio-noir.hdr`). Réglages du noir, après trois tours de
verdict :

| ce qui éclaire | set Lune | robe noire |
| --- | --- | --- |
| clé directionnelle (260) | 1,00 / 0,93 / 0,85 | **0,90 / 0,93 / 1,00** (blanc froid) |
| omni du bas | braise 1,00 / 0,45 / 0,15, ×1 | **améthyste 0,55 / 0,48 / 0,88, ×0,12** |
| `multiply` du sol | 1,00 / 0,80 / 0,65 | **0,88 / 0,90 / 1,00** |
| poudre + son grain | or et lune, halo braise | **blanc pur, grain SANS halo** (`pearlDotBlanche`) |
| horizon HDR | braise, force 0,40 / 0,12 | **améthyste, force 0,09 / 0,02** |
| matière | laque : rugosité 0,35, vernis 1,00 / 0,04 | **MATE : 0,62, vernis 0,30 / 0,32** |

Trois précisions qui viennent des trois tours :

1. **« violet plus discret »** — le violet est un SOUPÇON, pas une
   couleur : désaturé et à un huitième de la braise, il ne se nomme qu'au
   bord des plis.
2. **« la poudre doit être noir et blanche »** — un grain additif garde SA
   couleur quoi qu'on fasse des lumières : tant que son halo est or, la
   poussière rallume en or ce que le studio vient d'éteindre. Le grain a
   donc sa version blanche.
3. **« plus d'effet mat »** — le vernis épais (clearCoat 1,0 à rugosité
   0,04) fait le sachet LAQUÉ du set Lune ; sur une encre sans néon, il ne
   rendait qu'une vitre grise. Vernis mince : assez pour que le foil du
   liseré vive, trop peu pour que la grande face brille.

**CE QUI RESTE ORANGE : LA DÉCOUPE.** Le feu de la déchirure vit dans le
shader (`ember`, `burn`, `heat`) et n'appartient pas au studio. Un monde
froid dont la coupure est la seule braise — c'est le contraste qu'on
cherche, et ça respecte le verdict du matin là où il vaut encore.

⚠️ La garde reste vraie : le **piège du double rôle d'un uniforme** —
`ember` sert à la fois la découpe et le tube de braise du rouleau ;
grepper tous ses sites avant de toucher à l'un d'eux.

⚠️ **NON-RÉGRESSION MESURÉE** (la règle du fouettage) : le manège JAUNE,
capturé au même instant avant et après la refonte de palette, est
identique — centre du sachet `(75,4 · 44,1 · 33,7)` dans les deux cas,
pic `(255,100,32)` contre `(255,102,32)`, 4071 pixels saturés contre 4055
(la gigue d'une image d'animation).

---

## 5 bis. LE SACHET PRÉSENTÉ — cadrage Pocket, et plus de rotation
### (28-08, verdict porté par une capture Pokémon Pocket ; vaut pour LES
### DEUX ROBES — « pour le orange et le noir c'est le même workflow »)

Deux corrections de l'état « engagé » (le sachet posé, avant la découpe) :

**1. Le cadrage.** Le sachet flottait au milieu du vide, à hauteur d'axe :
on ne TIRE pas confortablement sur un objet qui ne touche à rien. Il est
maintenant **en gros, le pied coupé par le bord bas** — l'école Pocket.

Le grossissement se prend à l'**objectif** (champ 60° → 49°, ×1,28), jamais
en avançant la caméra : le sachet est presque plat face à l'objectif, une
courte focale lui creuserait les flancs. La caméra monte ensuite de 0,43,
le sujet descend d'autant.

⚠️ **Les chiffres sont RELEVÉS SUR LA RÉFÉRENCE, pas estimés** — deux
essais au jugé ont été refusés avant de la mesurer :

| | référence Pocket | ×2 (champ 30°) | ×1,55 | **retenu ×1,28** |
| --- | --- | --- | --- | --- |
| bord haut | 46 % | 34,6 % | ~35 % | **54,7 %** |
| largeur | 74 % | **116 % — coupé aux flancs** | 89 % | **70,6 %** |
| pied | coupé | coupé | coupé | **coupé** |

La référence ne coupe **que le bas**. C'est la contrainte qui tranche le
grossissement — et le grossissement seul : la hauteur, elle, se règle à la
caméra.

**LE RÉGLAGE EST LA FRACTION VISIBLE, PAS LA POSITION.** Trois crans
demandés à la suite avant de trouver le bon, et c'est ce vocabulaire-là qui
a fini par le donner : 100 % visible (le sachet posé, pied compris) =
« beaucoup trop » ; 70 % = trop bas ; **85 % = le bon** (mesuré 84,5 %,
bord haut à 54,7 %). Une seule constante le porte, `cadreDechirure.y`.

**2. Plus de rotation.** Le sachet engagé est là pour être DÉCHIRÉ : un
objet qu'on fait tourner sous le pouce n'invite pas à tirer dessus, et la
moitié des gestes de traction le mettaient en rotation au lieu d'ouvrir.
La pichenette est réservée aux sachets **hors du Sacre** (`!galleryOn`) :
le géant de la page profil et les bancs la gardent entière.

**Le cadrage rend la main à `finishTear`** : dès que la bande cède, retour
au cadrage canonique (0 · 0 · 2,05, champ 60°) sur lequel TOUT l'aval est
calé — la sortie de carte, le dolly 1,86, le recouvrement même-image de
`CarteVivante`. Le mouvement se fond dans le grand RRRIP : un recul qui
ouvre l'espace au moment exact où quelque chose en sort.

---

## 6. LA CARTE QUI SORT — légendaire, garantie, côté SERVEUR

`forge-card` tire aujourd'hui `common 60 / rare 27 / epic 10 / legendary 3`
(SUPABASE-PIPELINE.md). Le booster noir doit **forcer le registre
legendary**.

- Le client n'a **jamais** le droit de demander une rareté : `tirer()`
  passerait un `booster_id`, et c'est le SERVEUR qui lit `origine =
  'legendaire'` sur la ligne réservée pour choisir le pool. Un paramètre
  `rarete: "legendary"` envoyé par l'app serait la faille du système.
- La garde d'idempotence `claim_booster` est réutilisée **telle quelle**
  (verrou `for update skip locked`, retour idempotent si déjà scellé) —
  c'est elle qui interdit de tirer deux légendaires avec une seule pièce.
- Détail de la note backend : *« nécessite que le pool légendaire de
  `forge-card` soit adressable directement »* — 6 familles existent, le
  pool est donc peuplé ; reste à ce que la fonction sache filtrer dessus.

Le SQL et la règle complète : **§4 decies** de la grosse note backend.

### 6 bis. LE CADRE DES LÉGENDAIRES — full noir, un filet d'argent
### (28-08 : « pas de bordure orangée, full noir avec un peu de blanc,
### très très premium — fais un variant du cadre »)

`carte-cadre.png` est un asset FIXE (1086×1448, RGBA) posé par
`LuneForge.composer` par-dessus l'illustration ; ses 39 854 pixels clairs
sont une braise franche (RVB 168 · 90 · 38). Le variant
`carte-cadre-legendaire.png` est cuit par
`tools/sacre/bake_cadre_legendaire.py` (rejouable) et rend
**142 · 145 · 148** — un argent froid, écart R−B de −5,9.

Trois décisions qui ne se devinent pas :

1. **La forme ne bouge pas d'un pixel.** Alpha inchangé, aucun redessin :
   le cadre est mesuré à la fenêtre d'illustration (`fenetre`) et au
   placement des lunes de rareté — un cadre redessiné de trois pixels
   décalerait l'image sous lui.
2. **On neutralise par le CANAL MAX, pas par la luminance.** La luminance
   d'un orange 168 · 90 · 38 vaut 107 : elle rendrait un liseré gris sale,
   à moitié éteint. Le canal max garde l'ÉCLAT et ne retire que la couleur
   — c'est ce qu'on demande à un argent.
3. **Le filet est baissé à 0,88** (« un peu de blanc ») : à éclat égal, une
   ligne blanche crie deux fois plus fort qu'une ligne d'or.

Côté code : `LuneForge.nomDuCadre(rarete)` choisit l'asset, et **les lunes
de rareté passent au blanc froid avec lui** — une légendaire au liseré
d'argent qui garderait des croissants de braise aurait l'air d'un montage.

**LE FOND DE LA CARD EST NOIR AUSSI** (28-08, deuxième passe) : le corps du
cadre n'était pas noir dans l'asset d'origine — il tirait `10,4 · 4,8 · 2,8`,
un brun très sombre qui, neutralisé, devenait un GRIS. Sur une page noire un
gris ne se lit pas comme du noir, il se lit comme un VOILE. Le pied de la
courbe est donc repoussé à zéro (point noir à 26, ce qui reste ré-étalé) :
le champ de la carte mesure maintenant **`3,2 · 3,3 · 3,4`** — du noir, et
le liseré garde son éclat.

⚠️ **Il ne se voit pas encore au banc** : la cérémonie y sort le
placeholder `carte-lune-1`, dont l'art est DÉJÀ composé. Le cadre ne
s'applique qu'aux cartes qui passent par `habiller(illustration:rarete:)`
— donc le jour où le booster noir tire vraiment dans le pool légendaire
(J2).

---

## 7. LES VERDICTS, ET CE QUI RESTE OUVERT

**Tranché le 28-08 par Kathryn :**

1. ~~Q1 — l'anneau~~ → **manège noir SÉPARÉ** (« on n'aura jamais les deux
   ensemble »). §3.
2. ~~Q2 — la cérémonie~~ → **le noir GARDE LA BRAISE**. §5.
3. ~~Q3 — le prix~~ → **une pièce noire, pas plus.** Aucune pièce jaune ne
   se débite à l'ouverture d'un booster noir (le §9.2 de la note backend
   est clos ; la règle est au §4 decies).

4. ~~Q4 — le tell permanent~~ → **oui, MAIS PAS AU MANÈGE.** « Oui » le
   matin, puis, devant les dix sachets de l'anneau : *« la fente trop moche
   dans le manège, enlève »*. Dix sertissages qui fuient font dix lampes de
   poche dans une nuit qu'on veut noire. Le tell vit donc dans la
   CÉRÉMONIE (le sachet engagé, seul), jamais dans la galerie —
   `robe.tellPermanent && !gallery`.
5. ~~Q2 bis — la lumière~~ → **le studio du noir est FROID** (voir §5) :
   verdict rendu devant le premier rendu, il remplace le « garde la
   braise » du matin pour tout ce qui n'est pas la découpe.

**Encore ouvert :**

6. **Q5 — les mots** du panneau noir, et la pill du profil (deuxième pill
   ou pastille sur celle qui existe) ?

---

## 8. JALONS

- **J0 — LA ROBE, zéro backend. ✅ FAIT le 28-08.** Le bake
  (`booster-noir-color.png` + `booster-noir-emiss.png` dans `Woop/Media`,
  script rejouable, planches de verdict) ; `RobeBooster` (textures,
  palette, matière, tell) descendue de `BoosterLab` à `BoosterScene` par
  `BoosterStage` ; le cache des textures ; le `.hdr` par robe ; le banc
  **`-boosterNoir`**. Le manège noir tourne et va au bout de la cérémonie
  avec le placeholder. Build propre (DerivedData neuf), non-régression du
  manège jaune MESURÉE (§5).
  ⚠️ Deux dettes laissées volontairement : le four de `WoopApp` ne
  préchauffe que le `.hdr` jaune (la première ouverture noire cuira son
  1024×512 sur place), et l'appelant de `BoosterLab(robe:)` côté app
  n'existe pas encore — c'est J1.
- **J1 — LA PORTE.** `SacreEtat` à deux réserves, panneau noir (mots +
  vignette), pill du profil, tell permanent. Compteur maquette.
- **J1 — LA PORTE. ✅ FAIT le 28-08.** `SacreEtat` à deux réserves
  (`boostersNoirsEnAttente`, `robeCourante`), la pop-up qui dit les mots du
  noir, la vignette noire DÉCOUPÉE (le sachet noir n'a pas de néon : en
  `plusLighter` il ne resterait de lui que son filet, illisible à 26 pt —
  il porte donc un alpha et se compose normalement), la deuxième pill au
  profil, le plan d'en-tête ÉTALONNÉ FROID (`booster-loop-noir.mp4`, écart
  R−B des pixels clairs +55 → −2) et le banc **`-sacreNoir`** qui joue la
  porte entière sans backend.
  ⚠️ L'étalonnage n'est pas un rendu : les sachets filmés gardent le dessin
  du set Lune. De près, ce sont des sachets Lune éteints.
- **J2 — LA GARANTIE. ✅ DÉPLOYÉ le 28-08** (sur go explicite de Kathryn,
  qui a fourni un jeton neuf — l'ancien, celui de l'environnement, rendait
  401 même sur `projects list`). Vérifié EN LIGNE sans déclencher de
  génération payante : sans JWT → `401 non connecté` (la fonction démarre,
  donc elle parse) ; avec un `booster_id` inconnu → `404 booster inconnu`
  (mon chemin s'exécute, et il sort avant l'appel à OpenAI).
  `FORGE_DEV_USER` est posé sur l'uuid du compte de banc
  (`be69f505-…`) **avant** le déploiement, pour que `CarteLuneLab` ne
  perde jamais ses leviers. Patch
  `supabase/functions/forge-card/index.ts` : le client n'envoie que le
  `booster_id` de SA réserve, le serveur relit `origine` et impose le
  registre. Trois bornes dans le même patch — la garantie tient sur les
  DEUX chemins (pool ET forge neuve : les 35 % qui sautent le pool
  forgeaient une famille au hasard dans les 25), l'idempotence est au
  sachet (`user_boosters.card_id` scellé après coup), et **les manettes
  d'atelier `famille`/`force_new` se ferment** (`FORGE_DEV_USER`) — elles
  laissaient n'importe qui demander « La lune souveraine » sans pièce noire.
- **J3 — SUPABASE. ✅ APPLIQUÉ le 28-08** (`supabase db push`, sur go
  explicite). L'historique distant était PROPRE — les trois anciennes
  migrations enregistrées, donc le piège que je craignais (rejouer
  `woop_schema`, qui crée ses tables **sans `if not exists`**) n'existait
  pas : seule la mienne manquait.
  **Vérifié, avec un témoin** — `user_boosters` et `coin_ledger` répondent
  200, `solde_noir` répond 200, `claim_booster_legendaire` répond
  `P0002 — aucune pièce noire` (mon exception, mot pour mot), et une
  fonction **inventée** répond 404 : c'est ce témoin qui rend les trois
  autres réponses probantes.
  Fichier : `supabase/migrations/20260828120000_booster_noir.sql`.
  ⚠️ **Correction du plan** : ce n'est PAS un `alter` de contrainte —
  `user_boosters` et `coin_ledger` **n'existent pas encore** (le SQL de
  SUPABASE-PIPELINE.md n'a jamais été passé). Le fichier crée les deux
  tables aux schémas du pipeline, avec `'legendaire'`, `currency` et les
  raisons du noir dès le départ, plus `claim_booster_legendaire()` et
  `solde_noir()` — et les `alter` défensifs au cas où le pipeline serait
  passé avant lui (un `create if not exists` sur une table déjà là ne dit
  RIEN et laisserait la contrainte fausse).
  **La réserve noire n'est pas un stock de sachets : c'est le SOLDE NOIR.**
  Le sachet naît au claim ; la pill du profil compte donc des pièces
  noires, c'est-à-dire des boosters ouvrables.

  ⚠️ **Une faiblesse de ma propre SQL, trouvée en la relisant** : la
  première écriture gardait le double-clic par un `perform … for update`
  sur le grand livre. **Ça ne verrouille rien** — un `for update` ne pose
  de verrou que sur les lignes qu'il TROUVE, et le cas qui fait mal (deux
  appareils simultanés) part souvent d'une seule ligne, voire d'aucune.
  La garde est maintenant un **index unique partiel** : au plus UNE réserve
  noire non scellée par utilisateur. Le second appel viole l'unicité, la
  fonction l'attrape et rend la réserve existante — l'idempotence obtenue
  par contrainte plutôt que par politesse.

  **Le côté app est écrit aussi** : `Woop/Services/SacreServeur.swift`
  (`solde_noir`, `claim_booster_legendaire`) et le paramètre `boosterId`
  de `ForgeServeur.tirer`. **Rien ne les appelle encore** — le drapeau
  `-sacreServeur` sera l'interrupteur qui fait passer `SacreEtat` de la
  maquette au vrai solde, le jour où la migration est passée. Une app dont
  le backend n'existe pas ne doit pas semer des 404 dans ses logs.
- **J4 — L'ANNONCE.** La pièce noire se gagne en scène : `RewardPopup`
  atmosphère RARE + `reward-rare.mp4` (déjà recuite dans `Woop/Media`),
  puis la pill noire s'allume au profil.

---

## 9. LES PIÈGES QUI S'APPLIQUENT ICI (déjà payés ailleurs)

- **Une ressource de `Woop/Media` n'est PAS dans un catalogue** :
  `Image("nom")` rend un carré vide en silence.
- **36 Mo de textures décodées par construction de scène** — cacher AVANT
  d'ajouter une robe.
- **Le mur du type-checker** : toute fermeture de plus de deux lignes
  posée dans le corps d'une vue rapproche du « unable to type-check » —
  le corps est une addition de vues NOMMÉES (payé au commit 337a6e3).
- **Le lacet π** : aucune écriture d'euler sur le pack, tout passe par le
  berceau — sinon « le booster tourne » revient.
- **Deux builds sur le même `-derivedDataPath`** = base verrouillée.
- **Un `xcodebuild | grep`** rend le code de grep : le build noir se
  vérifie sur `$?` capturé sur la ligne même (payé 3×).
