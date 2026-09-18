# Le sachet noir du manège — « trop mat, pas assez réaliste » (18-09, 17:05)

Verdict de Kathryn sur son iPhone, après l'ouverture du noir : « très beau » de
loin, mais dans le manège « trop mat, pas assez réaliste » — « pas très beau ».
Ordre : « vas-y code ». Chantier de MATIÈRE, pas de parcours.

## Ce qui rend le noir mat aujourd'hui — lu dans le code

`RobeBooster.matiere` (`Nosfy/Views/BoosterPack.swift:374-386`) :

| robe | rugosité | vernis (clearCoat) | rugosité du vernis |
|---|---|---|---|
| lune (validée, « laque ») | 0,35 | 1,0 | 0,04 |
| noire | **0,62** | **0,30** | **0,32** |

Ce mat est un choix DATÉ : le 28-08, verdict « plus d'effet mat sur le booster
dans le noir » — parce que le vernis épais rendait alors « une vitre grise » sur
l'encre, sous un horizon HDR orange fort (`horizonForce` 0,4). Depuis, le studio
noir a été refroidi et éteint (`PaletteStudio.noire` : horizon améthyste à
**0,09**, sol 0,02, omni ×0,12). Deux causes s'additionnent donc :

1. **la surface** est rugueuse et presque sans vernis → pas de reflet net ;
2. **il n'y a rien à refléter** : l'horizon HDR est à 0,09 — un vernis, même
   épais, ne rend une laque que s'il a une lumière à renvoyer.

`metalness` est à 0 pour les deux robes (recette « laque » : corps encre F0 4 %,
tout le mouillé vient du vernis + `clearCoatNormal` des plis). La recette
« mylar » (`-boosterMylar` : metalness 1, roughness 0,14, clearCoat 0,5/0,10,
`metalLift` 1) existe au banc — c'est le sachet de chips aluminisé.

## Le verdict précédent et celui-ci ne se contredisent pas

Le 28-08 « plus mat » chassait la VITRE GRISE : un vernis épais renvoyant un
horizon orange fort sur de l'encre. Aujourd'hui « trop mat » demande le vivant
d'un vrai sachet noir (foil noir laminé : reflets nets, froids, qui glissent
sur les plis). La réponse n'est pas de remettre le 28-08 tel quel, mais de
rendre le vernis avec un horizon FROID et modéré, pour que ce qui se reflète
soit un éclat blanc-bleu fin, pas une nappe.

## Trois candidates, au banc, à juger à l'ÉCRAN (loop courte)

Drapeau `-noirMatiere <n>` (UserDefaults, `RobeBooster.variantNoir`) ; 0 = l'actuel.

| n | nom | rugosité | vernis | rug. vernis | metalness | horizonForce | idée |
|---|---|---|---|---|---|---|---|
| 0 | actuel (mat) | 0,62 | 0,30 | 0,32 | 0 | 0,09 | témoin |
| 1 | laque noire | 0,35 | 1,0 | 0,05 | 0 | 0,22 | la recette Lune, horizon froid modéré |
| 2 | satin | 0,45 | 0,75 | 0,14 | 0 | 0,16 | entre les deux : reflet présent, doux |
| 3 | foil noir | 0,24 | 0,55 | 0,08 | 0,55 (`metalLift` 0,45) | 0,28 | métal sombre laminé, reflets froids |

Ce qui ne change PAS : le dessin (textures cuites), les plis (`booster-normal`),
la découpe (braise), la poudre blanche, l'omni améthyste. Un seul moteur par
variante : la matière + la force de l'horizon qu'elle reflète (les deux vont
ensemble, un vernis sans horizon ne se voit pas — c'est le point 2).

Coût : aucune horloge, aucun shader nouveau — des constantes de matériau et
un scalaire d'environnement. Rien à mesurer côté chauffe pour choisir ; la
mesure iPhone se refait une fois la variante posée (mêmes conditions que
`tools/carte-lune/iphone-2026-09-18/`, manège noir 31 % CPU).

## Méthode

1. Coder le drapeau (BoosterPack.swift : `matiere`, `palette.horizonForce`,
   `metalness`/`metalLift` dans `material(...)`).
2. Simulateur, `-boosterLab -boosterNoir -boosterGallery -boosterStill`,
   capture à 12 s pour n = 0…3 → `tools/sacre/captures/noir-matiere-<n>-2026-09-18.png`.
3. Lui montrer les quatre, côte à côte ; SON verdict choisit ; alors seulement
   la valeur choisie devient la matière par défaut de `.noire`, et on remesure
   sur l'iPhone (elle n'a plus de sachet : un sachet noir de test à reposer).

## Verdicts, sur SON iPhone (18-09, 17:50 → 18:20)

Banc `-skipAuth -boosterLab -boosterNoir -boosterGallery -noirMatiere <n>` installé
sur son téléphone (rien n'est consommé). Captures simulateur des candidates :
`tools/sacre/captures/noir-matiere-{0..4}-2026-09-18.jpg` et la planche
`noir-matiere-planche-2026-09-18.jpg` (la 3 blanchit tout : éliminée au sim).

- **Variante 1 (laque)** : « plus sombre, et on voit pas assez la lune au milieu —
  néon blanc ; et musique autre, car c'est légendaire ».
- **Variante 5 (laque sombre : rugosité 0,38 · vernis 1,0 / 0,06 · horizon 0,13)
  + la lune en néon blanc + la boîte à musique du manège noir** : « ok très bien ».
- **Le sacre noir** (chœur, orgue, cloches — `cuire_sacre_noir.py`), écouté en
  `-boosterCine` : « oui très bien ».

Posé par défaut : `RobeBooster.matiere(.noire)` = laque sombre (le mat du 28-08
reste au banc, `-noirMatiere 9`). Néon : `tools/sacre/neon_lune_noir.py` →
`Nosfy/Media/booster-noir-emiss.png` (l'ancienne dans `noir/booster-noir-emiss-avant-neon.png`).
Musiques : `manege-noir.caf`, `sacre-noir.caf` (BoosterAmbience(robe:)).
Non mesuré : le coût (aucune horloge ni shader nouveau — deux pistes audio de plus
en mémoire, 4,6 Mo chacune, chargées seulement pour la robe noire).
