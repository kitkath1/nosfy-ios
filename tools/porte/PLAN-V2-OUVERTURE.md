# PORTE V2 — L'OUVERTURE : la plongée de la lune, le film qui dure, le bug des écrans noirs

Plan dicté le 2026-08-22 au soir, après le premier verdict à l'écran
(`kat-entree`). **Rien ne se code tant que ce plan n'a pas le GO.**
Les deux autres volets du verdict : `PLAN-V2-VIVANT.md` (parallaxe, caresse,
alignements) et `PLAN-V2-MANEGE.md` (le vrai manège 3D en page 4).

Le verdict, mot pour mot :
- « l'arrivée de la lune **pas assez spectaculaire** » ;
- « la vidéo trop belle juste après **qui doit durer plus longtemps** » ;
- « une fois arrivée sur l'écran de connexion la première vidéo **beug** :
  elle bouge un petit peu ou montre des **petits écrans noirs bizarres** » ;
- « **j'attends beaucoup pour l'arrivée cinématique dès le début**. »

---

## 1. LE BUG DES ÉCRANS NOIRS — diagnostic MESURÉ, remède canonique

### 1.1 Ce qui se passe (prouvé, pas supposé)

Le lecteur du film d'arrivée (`ReelPorte`) tient **une seule** image de pose
sous ses deux couches : `onb-arrivee-poster` — la première image du master.
Or le master **commence au noir** (le fondu du raccord avec la lune) :

| pose | luminance mesurée |
|---|---|
| `onb-arrivee-poster` (celle de ReelPorte) | **0,00 — max 0. Noir au bit.** |
| `onb-lune-loop-poster` (celle qu'il faudrait après le relais) | 15,16 — max 255 |

Et la loi du dépôt, écrite dans `StoryVideo.swift:65-69` : **à chaque
changement d'item, `AVPlayerLooper` vide sa couche 1 à 3 images.** La boucle
dure **5,800 s** — donc toutes les 5,8 s, la couche se vide, le trou tombe sur
la pose… qui est noire. Voilà les « petits écrans noirs bizarres », au rythme
exact où tu les as vus.

**Le « ça bouge un petit peu » est le MÊME instant** : le tour de boucle est
aussi le point où le ping-pong **inverse le sens** du mouvement de caméra.
L'inversion seule est douce et voulue ; combinée au clignotement noir, elle lit
comme un à-coup. Une cause, deux symptômes.

Pourquoi le fouettage ne l'a pas vu : le détecteur de flashs a scanné le film
de l'arrivée sur **12 s** — le premier tour de boucle tombe à ~10,8 s
(4,93 + 5,8), au bord de la fenêtre, et la frame vidée peut tomber ENTRE deux
frames de la capture 60 Hz. Leçon pour le banc du § 1.3 : on scanne
**≥ 3 tours de boucle** (20 s), jamais un seul.

Pourquoi les autres pages n'ont pas le bug : leurs `CalqueVideo` posent la
première image de **leur propre boucle** — au tour de boucle, le trou montre
la bonne image, décalée d'un souffle. Imperceptible par construction.

### 1.2 Le remède — les DEUX filets de StoryReel

C'est le mécanisme canonique du dépôt (`StoryVideo.swift:65-75`) : un filet
par fichier, commuté par `onLoop`.

- pendant le master : pose = `onb-arrivee-poster` (noire — c'est CORRECT ici,
  le master commence au noir) ;
- dès le relais (`onLoop = true`) : pose = **`onb-lune-loop-poster`** — la
  première image de la boucle, celle-là même que le trou devrait montrer.

⚠️ **La pose de la boucle doit être SA première image, au pixel.** Pas une
image « proche » : le filet bouche un trou d'1 à 3 frames, il doit porter
exactement ce qu'on devait voir (la loi de `grabFirstFrame`, tolérance zéro).
Notre `onb-lune-loop-poster` est déjà extraite par `select=eq(n\,0)` : bonne.

⚠️ **Et la même vérification vaut pour les créneaux du carrousel** : leurs
poses sont les frames 0 de leurs boucles (`onb-exos-loop-poster` 1,44,
`onb-track-loop-poster` 1,87 — sombres parce que les boucles LE SONT à leur
frame 0). Correctes par construction. Ne pas « éclaircir » ces poses : une
pose plus claire que la vidéo ferait l'inverse du bug — un flash CLAIR.

### 1.3 La vérification du jalon

Banc : `-porteLab -porteArrivee`, film de **22 s** (≥ 3 tours de boucle),
détecteur de flashs en V sur le header. Critère : **zéro** frame sous 45 % de
ses voisines aux instants 10,7 / 16,5 / 22,3 s (les tours de boucle). Et le
même scan sur la page 1 en mode direct (`-porteVue`), 20 s.

---

## 2. LE FILM QUI DURE — le recut

### 2.1 La matière disponible

La source `splash_1.mp4` fait **8,042 s** (193 img à 24). Le recut actuel n'en
garde que les 5 dernières secondes (fenêtre 3,042 → 8,042). Le contenu
mesuré : les 1,2 premières secondes sont noires, la lumière naît vers 1,2 s,
et le plan est un **recul continu** qui découvre le second pavé — il n'y a pas
un temps mort dans les 6,8 s utiles.

### 2.2 Les deux crans, et le recommandé

| | fenêtre source | ralenti | durée finale | images @30 |
|---|---|---|---|---|
| actuel | 3,042 → 8,042 (5,0 s) | aucun | 4,93 s | 148 |
| **B — recommandé** | **1,60 → 8,042 (6,44 s)** | **`setpts=1.30`** | **8,37 s** | **251** |
| A — sobre | 1,60 → 8,042 (6,44 s) | aucun | 6,44 s | 193 |

Le cran B : on part plus tôt (la naissance de la lumière fait partie du
spectacle) **et** on ralentit de 30 % — le recul devient un glissement, l'œil a
le temps d'habiter le verre. Le ralenti passe par `minterpolate mi_mode=blend`,
la recette éprouvée du fond de la home (qui tourne à `setpts=3.0` sans que ça
se voie — 1,30 est très en dessous).

⚠️ **Les trois lois du recut, qui ne bougent pas :**
1. la fenêtre se coupe au **`trim` dans le graphe**, jamais à `-ss`
   ([[le piège payé au J0]] : le fondu s'appliquerait à des images jetées) ;
2. le **fondu d'entrée 0,45 s** reste, et il est MESURÉ nécessaire : à 1,60 s
   la source est déjà à 8,5/255 de moyenne (max 218) — sans fondu, la couture
   avec la lune serait une coupe sur une image allumée ;
3. la boucle se recoupe **dans le fichier livré** (les ~3,2 dernières
   secondes), et l'image de raccord est recalculée — un NUMÉRO d'image dans la
   base de temps 30, passé à `ReelPorte`, jamais une constante recopiée.

### 2.3 Les conséquences assumées

- Le premier lancement passe de 8,4 s à **~11,8 s** (lune 4,45 § 3 + film
  8,37 − chevauchement noir). C'est le territoire de la version « longue » que
  tu avais écartée au premier arbitrage — **mais le verdict écran a parlé : le
  film est trop beau pour être coupé.** Le tap saute toujours, et le film ne
  joue qu'au premier lancement.
- La partition de l'habillage suit : flamme à **T − 1,2**, cascade à **T**,
  avec `T = la nouvelle durée` — les constantes sont déjà statiques
  (`arriveeT`), un seul chiffre bouge.
- `-cineTest` : l'attente passe de 8 à **12 s**.

---

## 3. LA LUNE SPECTACULAIRE — la plongée d'ouverture

### 3.1 Ce qui manque, et ce que la maison sait déjà faire

Aujourd'hui la lune **apparaît** (reveal 0 → 1, caméra fixe). Rien n'arrive,
rien ne se pose. Or le shader sait déjà tout faire — l'archive le prouve :
la PLONGÉE de `MoonSplashBeat` est un zoom exponentiel de caméra
(`×0,35 → ×10` en `p^1.6`), la SURTENSION est une impulsion de `cineCtl.y`,
et le tremblement/les chutes de l'agonie (`drops`, `gasp`) vivent déjà dans le
shader sur la courbe du sang — **ils joueront tout seuls pendant les fondus
d'états**, personne ne les a encore entendus parce que la caméra ne bougeait
pas assez pour qu'on les regarde.

### 3.2 La nouvelle partition (fonction pure du temps, comme toujours)

```
0,00 → 0,45   LA NAISSANCE AU LOIN. Caméra à ×0,32 : la lune est une lueur
              minuscule au centre de la nuit. reveal 0 → 0,35, les étoiles
              s'installent (night.x → 1). Le silence avant le geste.
0,45 → 1,30   LA PLONGÉE. Le zoom file de ×0,32 à ×1,20 en exponentielle
              (p^1.6 — la courbe de l'archive : lente au départ, elle avale
              la fin). reveal → 1. À LA POSE : une impulsion de surtension
              (cineCtl.y, 0,3 s) — le néon SURTEND sous le coup de frein —
              et LE BATTEMENT haptique fort. C'est l'arrivée qu'on attend.
1,30 → 1,85   ÉTAT ①   halo ivoire large — tenu, idleLife allumé.
1,85 → 2,10   fondu    night.w 0 → 0,52 (le shader tremble tout seul : drops)
2,10 → 2,65   ÉTAT ②   halo orange serré — tenu.
2,65 → 2,90   fondu    night.w → 1,00 ; la braise s'allume (z 0,40) ; gasp.
2,90 → 3,45   ÉTAT ③   la lune de sang, nette — tenue.
3,45 → 4,45   L'IMPLOSION DOUCE. reveal meurt PENDANT que la caméra rentre
              d'un cheveu (×1,20 → ×1,26) : la lune ne s'éteint pas, elle
              se referme. La braise du contour meurt en dernier.
                                                        TOTAL 4,45 s
```

- **0,55 s par palier reste le plancher** — la loi du premier plan tient.
- Les battements : `paliers(times:)` gagne un quatrième coup — **fort à la
  pose (1,30)**, puis les trois des états. Toujours d'un bloc au moteur.
- ⚠️ La caméra vit dans `MonolithCanvas(camera:)` — dans le SHADER, jamais un
  `scaleEffect` (les hairlines rastériseraient : la loi du fichier).
- ⚠️ Le zoom ×0,32 montre PLUS de scène : vérifier au gel (`-luneSangFreeze
  0.2`) qu'aucun bord de la SDF ni artefact de tuile n'entre dans le cadre.
- reduceMotion : saute à l'état ③ tenu, comme aujourd'hui.

### 3.3 La couture avec le film

L'implosion meurt au noir à 4,45 s ; le film rallongé commence au noir
(fondu 0,45 s). La couture reste noir-sur-noir. Le souffle noir total
(implosion + fondu d'entrée) se **mesure** au jalon et se règle en chevauchant
l'extinction si le trou dépasse ~1,2 s — le curseur existe déjà
(`withAnimation(.easeOut(0.5))` de la racine).

---

## 4. LES JALONS

| | jalon | vérification |
|---|---|---|
| **O1 ✅** | Les deux filets de `ReelPorte` | **FAIT 22-08 soir.** Film de 30 s couvrant TROIS tours de boucle : **zéro flash sur 1 717 frames scannées**. Le bug est mort. |
| **O2 ✅** | Le recut B | **FAIT.** ⚠️ Le fichier sort à **247 images**, pas les 251 de la formule — `minterpolate` mange une queue : la constante Swift suit le FICHIER (`ffprobe -count_frames`), jamais le calcul. Image 0 à **0,00/0** ; raccord : `argmin` de l'écart = **155 exactement** (la discrimination est faible — 0,461 vs 0,52 au témoin — parce que le ralenti rend les voisines quasi identiques : un décalage d'une image y est invisible par nature). |
| **O3 ✅** | La plongée (partition 4,45 s) + `paliers` ×3 dont la pose FORTE | **FAIT.** Sept gels (naissance / plongée / POSE+surtension / ①②③ / implosion) : l'arc dramatique est là, le halo flashe à la pose. La surtension recopie la courbe exacte du boom de l'archive (montée 60 ms, morte 550 ms). Haptique muette au sim. |
| **O4 ✅** | Les horloges (arriveeT 8,233 / four 9,2 s / `-cineTest` 12 s) | **FAIT.** La cascade tombe pile à la fin du film rallongé (bouton absent à 9,5 s, présent à 10,5 — mesuré sur film propre). La couture reste ≤ 8/255 de luminance. ⚠️ La cadence du run à froid était POLLUÉE (la session parallèle compilait sur la même machine — l'enregistreur lui-même a pris 4 s de retard) : le profil propre de la veille fait foi pour la mécanique, le reste est O5. |
| **O5** | **Verdict téléphone** | la plongée, les battements (fort + 2), le ralenti du film, le souffle noir |

**L'ordre est la loi : O1 (le bug) se livre SEUL et d'abord** — c'est une
correction, elle ne doit pas attendre le spectacle.

---

## V3 — LE SECOND VERDICT (23-08) : « encore plus spectaculaire »

### La comète — le levier que le shader tenait en réserve

`cineCtl.w` (`cometHead`) pilote une décharge de lumière qui court DANS le
tube : tête nette de 1,7 % de tour, traîne derrière seulement (« sans
l'asymétrie ce n'est plus une comète, c'est une bille »). Elle fait **un tour
et demi** pendant la plongée, sur la même exponentielle `p^1,6` que la caméra —
portée par le mouvement, jamais en train de le doubler — et s'arrête net à la
pose.

**⚠️ ET LE VRAI SUJET N'ÉTAIT PAS LA COMÈTE, C'ÉTAIT LE TUBE.** Premier essai :
elle courait pour de bon (point chaud mesuré à x=501 puis x=558, soit 57 px en
0,1 s) et **on ne la voyait pas** — parce qu'à pleine puissance le tube sature
à 254 et elle sature au même niveau. Le remède est une décision de mise en
scène, pas un réglage d'intensité :

| | avant | après |
|---|---|---|
| néon pendant la course | 0,35 → **1,00** | 0,30 → **0,52** (veille) |
| néon à la pose | déjà 1 | **0,52 → 1,00 en 0,30 s** |

Mesuré sur les gels : à t=1,00 et 1,15 le maximum tombe à 172 puis 223 avec
**zéro pixel saturé** — la comète est la seule chose brillante, elle TRACE le
croissant. Puis l'embrasement, sous la surtension. À t=1,42 : 3 064 pixels
saturés d'un coup.

### Le lacet d'arrivée

`userYaw` sur un ressort résolu à la main (dépassement 8 %, normalisé pour
valoir 1 EXACTEMENT en p=1 — le demi-point de reliquat de la forme brute
suffirait à décaler la pose). La lune arrive de biais (~12°) et pivote : ce qui
fait le geste, ce ne sont pas les degrés, ce sont les REFLETS qui balayent.

### Le recut V3 du film

Fenêtre **1,20 → 8,042** (au lieu de 1,60), ralenti **×1,35**, et un **serrage
1,16 → 1,00 CUIT** par-dessus (`zoompan`) : la source recule déjà, le zoom se
desserre avec elle — les deux vont dans le même sens. Sortie **274 images /
9,13 s**, raccord recalculé à **178**.

**Trois pièges ffmpeg payés dans l'ordre, tous silencieux ou presque :**
1. `nb_frames` n'existe pas dans le vocabulaire de `zoompan` → le graphe
   ÉCHOUE (« Undefined constant »). La rampe se pilote à `ot`.
2. `setpts` ne fabrique AUCUNE image : retirer `minterpolate` en croyant que
   le `fps=30` de zoompan suffisait a rendu **164 images / 5,47 s** — le
   ralenti avait disparu, et la boucle coupée au-delà de la fin ne faisait plus
   que 16 images.
3. `zoompan` SANS `fps=` retombe sur son défaut de **25** : 274 images
   étiquetées 10,96 s, donc lues 20 % trop lentes, la partition Swift à côté.

**Et le raccord ne se recopie plus** : le script le CALCULE (`total − 96`) et
l'imprime — c'est ce chiffre qui doit atterrir dans `PorteEntree`.
