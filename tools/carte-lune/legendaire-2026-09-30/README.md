# La légendaire en main — preuves du banc (30-09-2026)

Étapes 1 et 2 du plan `../ANALYSE-LEGENDAIRE-INVISIBLE-2026-09-29.md`, sur son
« ça me va je valide » puis « continue et commit tout ». **Au simulateur
seulement** : le produit (manège, collection) montre encore la légendaire
d'avant, tant que les masques ne sont pas livrés par le serveur (décision D3).
**Aucune mesure de chauffe sur son iPhone.**

## Ce qui est ici

| fichier | ce qu'il prouve |
|---|---|
| `planche-le-souverain-en-main.jpg` | le cerf (Forêt) : trois inclinaisons, face à l'épique Le Passage et à la légendaire d'aujourd'hui au même angle, crops ×3 ; dernière ligne : la lampe du pouce (avec / sans doigt) et le filigrane du cadre (penchée à gauche / à droite) |
| `planche-dragon-d-obsidienne-en-main.jpg` | le dragon (Cimes) : lave, cendres, écailles gravées |
| `planche-le-grand-silence-en-main.jpg` | le Grand Silence (Bois) : nacre qui monte, pas de feu — le plus discret, sa peinture est presque noire |
| `*-en-main.mp4` | 12 s de chaque carte, inclinaison libre (le balancement du banc) : la vie |
| `*-ceremonie.mp4` | la sortie de la légendaire (§ 3 du plan) : un point, un cheveu, une fente — la carte sort par la tranche et se tourne, sa gravure prise par la porte ; la vie s'éveille, le temps ralentit, la porte se referme ; le nom gravé (banc `-luneCeremonie`) |
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
-sansSouffle -sansLampe` ; `-sansMatiere` rend la légendaire du produit ;
`-luneSonde` vérifie que l'atlas arrive brut ; `-luneLampe u,v` fige la lampe
du pouce (captures).

## Corrigé après le premier commit (a8d1aeee)

- **La colonne « penchée à gauche » des premières planches était fausse** :
  `-luneTilt -0.5,0` commence par un tiret, UserDefaults le prenait pour un
  autre drapeau et la carte se balançait librement. Le banc lit désormais
  l'argument lui-même ; les planches sont refaites.
- **Un éclair blanc sur toute la carte** : quand l'inclinaison alignait la
  lampe du monde avec le regard, tout aplat portant de la gravure (corps du
  cadre, marges) renvoyait la lumière d'un bloc — la marge mesurée à 254 sur
  une image en balancement libre. La gravure ne s'allume plus que sur une
  pente (un fil, le flanc d'un filet) ; mesuré ensuite : marge à 0 sur 24
  images de balancement et aux cinq angles, dont l'angle d'alignement.

## Ce qui n'est pas fait

Livraison des masques au produit, cérémonie branchée au manège (elle vit au
banc seulement), vignette de collection, piano, mesure de chauffe sur iPhone. Le filigrane du cadre change
de flanc avec l'inclinaison, mais reste discret.
