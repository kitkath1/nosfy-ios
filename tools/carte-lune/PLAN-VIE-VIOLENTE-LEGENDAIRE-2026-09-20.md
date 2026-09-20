# La vie violente de la légendaire — et le saccadé au zoom

Plan du 20 septembre 2026, nuit, sur ses deux retours après le banc à plans
et relief : « pour l'effet légendaire il faut **animer dans l'image** les
braises ou les lumières du ciel **de manière violente**, et pareil pour les
créatures — je ne vois pas trop la différence entre un paysage légendaire et un
paysage basique » ; « ça bouge en **saccadé** au zoom de ton animation — c'est
mieux, mais pas fluide ». **Rien n'est codé.**

Ce qu'elle a raison de dire : le banc d'aujourd'hui donne à toutes les cartes
la même chose — de la profondeur et un geste. Une légendaire n'y est qu'une
belle peinture avec de la profondeur ; une commune aussi. La différence de
rareté n'existe pas encore **dans l'image**. Le plan du Passage la prévoyait
(§ 2 : « la vie ») mais en dose homéopathique — une respiration de 0,6 %, un
catch-light d'un pixel, des braises de 1 px. Trop fin pour se voir de loin.
Elle veut du **violent**. Ce plan remplace le § « la vie » par une vraie
mise en scène animée, dans ses lois (pas de vidéo, pas de balayage, pas de
néon ; la peinture porte le mouvement ; tout cuit par script pour 50 cartes).

---

## 1. Ce que l'utilisateur voit — une légendaire contre une commune

| | commune (paysage) | légendaire |
|---|---|---|
| en main | la peinture, sa profondeur, le foil d'aujourd'hui | **la peinture brûle** : les bois du cerf flambent, des braises en jaillissent en continu ; la lune bat ; les nuages roulent |
| au tap | le verre s'ouvre, le doigt conduit | idem — et **le monde se déchaîne** : le feu monte d'un cran, un **éclair** claque dans le ciel, la neige tourne en bourrasque |
| la créature | immobile | **elle vit fort** : respiration ample, la tête tourne vers l'œil, les yeux clignent, la fourrure est léchée par la lumière du feu, le dragon crache ses étincelles, le corbeau frémit des plumes |
| l'air | rien | brume qui roule, bourrasques, chaleur qui ondule au-dessus du feu |
| le son | rien | crépitement, vent, le piano |
| rare / épique | | rare = l'air qui dérive ; épique = la météo (neige, cendres, nacre) sans le feu ni la créature vivante |

Le test de réussite : **une capture de deux secondes**, sans le geste, doit
suffire à dire laquelle est la légendaire.

## 2. Les cinq moteurs, dans l'image

Tous nourris par des **masques cuits par carte** (kit v3, § 4) et rendus
dans **un seul passage de shader** posé sur le monde (relief ou plans),
piloté par le temps quand le monde est ouvert ou la carte en main, éteint
sinon (sa règle : rien ne tourne avant le tap ; en main, seule la carte).

### M1 — Le feu qui flambe (bois du cerf, lave du dragon, braises d'horizon)

Pas des points qui montent : **des flammes**. Un champ de bruit en deux
octaves, étiré vers le haut et **advecté** (il monte, il tord), **façonné par
le masque de feu** (les pixels chauds de la peinture, dilatés de 12 px vers
le haut) et coloré blanc-orangé au cœur → braise → rouge sombre aux bords.
Au-dessus des flammes, **la chaleur ondule** : les pixels sont déplacés par
le même champ (un léger tremblement de l'image, comme au-dessus d'un
brasier). Des **braises** jaillissent des flammes (grille de particules,
grosses au départ, qui s'éteignent en montant), avec des **bouffées** :
toutes les 2-4 secondes, une salve plus forte, et à chaque geste de la
main. Vitesse de scintillement 8-12 Hz : c'est ce qui fait « violent ».
Sur le dragon, la lave **pulse** à travers les fissures (le masque
émissif — les pixels chauds et saturés — monte et descend d'intensité
sur deux houles) et **crache** des étincelles par salves.

### M2 — Le ciel qui vit (la lune, les éclairs, les nuages)

- **La lune bat** : son halo (position cuite : la tache claire la plus
  ronde du ciel) respire fort, 0,4 → 1,0, sur 3 s ; à chaque battement, un
  cercle de lumière très fin s'en détache et s'éteint (une onde, pas un
  balayage : elle a une cause et un bord).
- **Les éclairs** : toutes les 6 à 15 secondes (apériodique), un **éclair**
  — le ciel entier s'éclaire en blanc-bleuté pendant 80 ms, deux fois
  (le double flash réel), avec **une branche** dessinée par un tracé cuit
  (huit tracés d'éclair par monde, choisis au hasard, posés dans le masque
  ciel) ; les nuages se révèlent en contre-jour pendant le flash ; un
  crépitement sonore. C'est l'effet le plus fort et le plus rare.
- **Les nuages roulent** : le plan nuages (kit) dérive lentement, et son
  masque est **tordu** par un champ de bruit lent — ils ne glissent pas,
  ils se déforment.
- Dans les Bois (pas de ciel) : la **nacre monte** en filets brillants le
  long des troncs (masque des blancs froids), et des lucioles nacrées.

### M3 — La créature qui vit fort

- **Respiration ample** : 2 à 3 % (contre 0,6 %), le flanc qui se soulève
  visiblement, 3,5 s de période.
- **La tête tourne vers l'œil** : le masque de tête (le tiers haut du
  détourage, affiné à la main si besoin) reçoit un **champ de déplacement
  cuit** : quand le téléphone penche à droite, la tête tourne de quelques
  degrés vers la droite (un déplacement de 6-10 px des pixels de la tête,
  plus fort aux bords, nul au centre — l'illusion d'une rotation).
- **Les yeux clignent** : masque des yeux (les deux taches chaudes ou
  claires les plus symétriques dans la tête, validées à l'œil) ; un
  clignement = une fermeture de 120 ms toutes les 4-9 s ; entre deux, un
  catch-light qui pulse.
- **Le feu la lèche** : la fourrure près des bois reçoit la lumière des
  flammes (M1 éclaire le relief E1 par intermittence — une lumière qui
  bouge avec une cause).
- **Par créature** : le dragon crache (M1), le corbeau frémit (un
  tremblement des plumes de bout d'aile, masque cuit), le loup souffle
  (une buée qui sort du museau).

### M4 — L'air et la météo déchaînés

La météo du monde (neige / cendres / nacre) existe déjà en dose calme pour
l'épique ; la légendaire l'a **en bourrasques** : la densité double pendant
2 s toutes les 8-12 s, le vent couche les flocons, une brume roule au sol
(champ de bruit lent, masque bas de l'image). Chaque geste de la main
déclenche une bourrasque.

### M5 — Le son

Crépitement continu sous le feu (volume lié à l'intensité des flammes),
vent qui monte avec les bourrasques, le claquement de l'éclair, le piano
(plan musique). Spatial : le feu à l'endroit du feu dans l'image (gauche /
droite), le vent selon l'inclinaison.

## 3. Ce qui reste interdit — et ce qui est la différence avec « cheap »

- Pas de vidéo, pas de boucle filmée : tout est calculé sur les masques de
  la peinture elle-même — le feu sort **de ses bois**, pas d'un calque posé.
- Pas de balayage : l'éclair est un flash avec une **branche** (un bord),
  la lune une onde qui naît d'elle, le feu une flamme.
- Pas de couleur hors blanc, argent, braise, rouge sombre, et le
  blanc-bleuté d'un éclair (80 ms).
- **Violent ≠ sale** : les flammes ont des cœurs blancs nets et des bords
  qui meurent vite ; les braises sont des points durs ; rien de flou, rien
  d'opaque, rien de « coton » — les champs de bruit sont **cuits** en
  textures (pas de procédural à 10 fetches), comme le ciel de la home.

## 4. Le kit v3 — ce que le script cuit en plus, par carte

| masque / donnée | comment | vérification |
|---|---|---|
| **feu** (zones chaudes + direction) | pixels chauds, dilatés vers le haut ; direction = « haut » + gradient du masque | planche |
| **émissif** (lave, braise dans la matière) | chaud ET saturé | planche |
| **ciel** | déjà (sombre + lisse) | — |
| **lune** | la tache claire la plus ronde du ciel (cercle de Hough) | à l'œil, une fois par carte |
| **tête / yeux** | tiers haut du détourage ; yeux = deux taches symétriques claires ou chaudes | **à l'œil, une fois par carte** — le seul point où une main peut corriger (un JSON) |
| **nacre** | blancs froids (déjà) | — |
| **bout d'aile / museau** | par famille (corbeau, loup) : masque par heuristique, corrigé à l'œil | une fois par carte |
| **textures cuites** | deux champs de bruit (feu, brume), huit tracés d'éclair par monde | une fois par monde |

Tout par script (`cuire_vie.py`, à écrire) ; le JSON par carte peut être
retouché à la main pour les yeux — c'est le seul geste humain, et il ne
concerne que les six légendaires (les autres raretés n'ont pas M3).

## 5. Le saccadé au zoom — pourquoi, et comment ça se juge

Ce qu'elle a vu : les **films du simulateur**. Trois causes, dont deux dans
mon code :

1. **Le simulateur n'est pas une mesure** : il rend SwiftUI et Metal sur le
   processeur du Mac (chargé par quatre compilations), et l'enregistrement
   `simctl recordVideo` tombe à 20-30 images par seconde avec des à-coups.
   Un film du sim **ne prouve pas** la fluidité, ni son absence. La règle
   de la maison : **la sonde sur son iPhone**, thermique 0, la paire
   (cadence, pire intervalle) — critère : 60 img/s et `pire` < 20 ms
   pendant l'ouverture et le pincement.
2. **Mon ouverture anime la TAILLE des six plans** (`.frame` interpolé de
   la taille carte à la taille écran) : à chaque image, SwiftUI refait la
   mise en page de six images de 1024×1536 et le GPU les rééchantillonne
   — c'est le motif « redessiner pour animer » (33-38 % de processeur
   mesurés sur la home pour le même péché). Remède : **les plans naissent
   à la taille écran**, et l'ouverture n'anime que `scaleEffect`,
   `offset` et `opacity` — des valeurs animables, sans mise en page.
3. **Le corps entier est réévalué 60 fois par seconde** (la `TimelineView`
   reconstruit la pile de six `Image`). Remède : les plans sont des
   **feuilles** à identité stable (valeurs stockées), et seuls leurs
   modificateurs lisent l'inclinaison (le pattern `OffsetVol` du player) ;
   côté relief, la caméra SceneKit se pilote **dans le rendu SceneKit**
   depuis CoreMotion, sans passer par SwiftUI à chaque image.

Et un quatrième point, à l'œil : le pincement applique l'échelle
**immédiatement** ; une inertie (un ressort critique de ~80 ms) rend le
zoom « lourd », donc naturel.

Ces trois corrections sont **du code de banc**, mesurable avant tout
jugement : on ne dira plus « fluide » sur un film du sim.

## 6. L'ordre, si elle dit oui

1. **La fluidité** (§ 5, 2-3) + la sonde : une demi-journée, mesurée sur
   son iPhone **seulement quand le sim est validé et qu'elle dit
   « installe »**.
2. **M1 le feu** sur le cerf et le dragon (masque cuit, flammes, chaleur,
   braises en salves) — c'est ce qui fait la différence en une capture.
   Un jour.
3. **M2 le ciel** (lune qui bat, éclairs, nuages qui roulent). Un jour.
4. **M3 la créature** (respiration ample, tête, yeux, feu qui lèche).
   Un jour et demi, plus les masques validés à l'œil pour six cartes.
5. **M4 la météo déchaînée** et **M5 le son**. Un jour.
6. Les raretés intermédiaires (rare = air, épique = météo calme). Une
   demi-journée.
7. Le kit v3 dans `cuire_kits.sh` pour les 50. Une demi-journée.

Chaque moteur arrive avec son barreau (`-sansFeu`, `-sansCiel`, `-sansVie`,
`-sansMeteo`) et se mesure seul.

## 7. Ce qui n'est pas prouvé

- Le coût de cinq moteurs dans un passage de shader plein écran sur un
  profil déjà 🔴 : inconnu tant que la sonde n'a pas parlé. Si ça chauffe,
  l'ordre de sacrifice est : M4, M2 (nuages), M3 (tête), jamais M1.
- La détection des yeux et de la lune : heuristique, validée à l'œil.
- « Violent » se juge par elle, en crops et en mouvement — sur son iPhone,
  pas sur un film du sim.
