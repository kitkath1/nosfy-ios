# La légendaire en main — preuves du banc (30-09-2026)

Étapes 1 et 2 du plan `../ANALYSE-LEGENDAIRE-INVISIBLE-2026-09-29.md`, sur son
« ça me va je valide » puis « continue et commit tout ». **Au simulateur
seulement** : le produit (manège, collection) montre encore la légendaire
d'avant, tant que les masques ne sont pas livrés par le serveur (décision D3).
**Aucune mesure de chauffe sur son iPhone.**

## Ce qui est ici

| fichier | ce qu'il prouve |
|---|---|
| `planche-le-souverain-en-main.jpg` | le cerf (Forêt) : trois inclinaisons, face à l'épique Le Passage et à la légendaire d'aujourd'hui au même angle, crops ×3 |
| `planche-dragon-d-obsidienne-en-main.jpg` | le dragon (Cimes) : lave, cendres, écailles gravées |
| `planche-le-grand-silence-en-main.jpg` | le Grand Silence (Bois) : nacre qui monte, pas de feu — le plus discret, sa peinture est presque noire |
| `*-en-main.mp4` | 12 s de chaque carte, inclinaison libre (le balancement du banc) : la vie |
| `capturer.sh`, `planche.py` | les rejouer |

Les captures brutes ne sont pas gardées (elles vont dans `/tmp/nosfy-legendaire`).

## Rejouer

```sh
python3 tools/carte-lune/cuire_matiere.py --legendaires          # les kits (atlas)
python3 tools/carte-lune/cuire_matiere.py le-passage loup-de-cendre loup-des-racines
# construire l'app pour le simulateur, l'installer, puis :
tools/carte-lune/poser_matiere_sim.sh <udid>
tools/carte-lune/legendaire-2026-09-30/capturer.sh <udid> le-souverain le-passage
```

Barreaux du passage : `-sansRelief -sansBraises -sansNeige -sansPaillettes
-sansSouffle` ; `-sansMatiere` rend la légendaire du produit ; `-luneSonde`
vérifie que l'atlas arrive brut.

## Ce qui n'est pas fait

Livraison des masques au produit, lampe du pouce, filigrane du cadre distinct,
cérémonie de sortie du sachet, vignette de collection, piano, mesure de
chauffe sur iPhone.
