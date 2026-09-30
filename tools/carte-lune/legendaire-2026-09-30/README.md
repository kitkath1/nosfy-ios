# La légendaire en main — preuves du banc (30-09-2026)

Étapes 1 et 2 du plan `../ANALYSE-LEGENDAIRE-INVISIBLE-2026-09-29.md`, sur son
« ça me va je valide » puis « continue et commit tout ». Depuis le 30-09
au soir (« oui oui mets tout dans l'app ! »), **la matière est dans le
produit** — manège et collection, livrée par le serveur (§ « Dans l'app »
plus bas). **Mesuré au simulateur seulement ; aucune mesure de chauffe sur
son iPhone.**

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

## Dans l'app (30-09 au soir)

Ses ordres : « oui oui mets tout dans l'app ! », « et même celles déjà
obtenues par Margaux », « toutes les légendaires qui vont se générer […]
auront un effet wahou », « attention au zoom, quand on clique ».

- **Le serveur livre la matière.** Pour chaque légendaire publiée en base,
  `tools/carte-lune/publier_matiere.py --upload` cuit le kit s'il manque
  (depuis l'illustration publiée, empreinte vérifiée, détourage rembg pour
  une carte que personne n'a vue) et le dépose dans le bucket public
  `cards` : `matiere/<card_id>.json` (le pointeur) et `matiere/<sha256>.png`
  (l'atlas, jamais écrasé). Relu à distance par empreinte le 30-09 : Le
  Souverain (atlas `08f669ce`), Dragon d'Obsidienne (`f68db96a`), Le Grand
  Silence (`7aeed1e8`) — `publication-matiere.json`. **À relancer après
  chaque publication de cartes** : c'est ce qui donne aux légendaires à
  venir la même matière, sans une ligne de plus.
- **L'app la va chercher par l'identifiant de la carte**
  (`LuneMatiere.publiee`) : pointeur relu, atlas téléchargé une fois,
  empreinte vérifiée, cache disque. `CarteVivante` le fait seule dès qu'on
  lui donne l'identifiant d'une légendaire — manège et collection, donc
  aussi les exemplaires déjà obtenus. Préchargé au tirage
  (`ForgeServeur.tirer`) et à l'ouverture de la collection
  (`CollectionLune.relire`).
- **L'interrupteur** : `reward_rules.legendaire_matiere` (migration
  `20260930200000`, posée, lue `true` par `regles_annonces()`). À `false`,
  toutes les légendaires reviennent au rendu d'avant sans nouvelle version.
- **La cérémonie remplace la sortie du sachet** pour une légendaire (manège
  noir) : lancée quand la carte sort, avant l'extraction ; la scène résultat
  prend le relais quand la porte s'est refermée.
- **Le zoom au tap est retiré** : le film de plongée (×4,8, écrit pour une
  seule carte) ne part plus au tap ni à l'appui long. Le pincement agrandit
  jusqu'à ×2 sous les doigts et revient au lâcher. Le film survit au banc
  seulement (`-lunePlongee`).

| fichier | ce qu'il prouve |
|---|---|
| `manege-noir-dragon-ceremonie.jpg` | le VRAI chemin produit au simulateur, compte de test : collection → sachet noir → noir → cheveu → fente → le Dragon (attribué par le serveur, kit publié chargé) → nom gravé → scène résultat avec la carte gravée ; plus de double sortie |

Journal de ce passage : `[collection] 11 références · 30 exemplaires`, puis
`[matiere] … kit publié chargé` pour les trois légendaires (atlas
`f68db96a` pour le Dragon).

Au 30-09, ni Margaux (« Nini ») ni Kathryn ne possèdent de légendaire : la
première qu'elles tireront arrivera avec sa matière.

## Ce qui n'est pas fait

**Mesure de chauffe sur son iPhone** (règle n° 6 ; A/B avec `-sansMatiere`
sous `-sondeVol`), tap et pincement en collection essayés au doigt (le
simulateur n'a pas de doigt ici), bascule de l'interrupteur à `false`,
vignette de collection, piano. Le filigrane du cadre change de flanc avec
l'inclinaison, mais reste discret.
