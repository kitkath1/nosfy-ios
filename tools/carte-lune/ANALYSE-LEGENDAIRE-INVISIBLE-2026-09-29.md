# Cartes — pourquoi la légendaire ne se distingue pas (analyse, 29-09-2026)

Son constat : « les cartes légendaires ne se distinguent pas assez des autres.
Le cerf par exemple : tu avais imaginé des trucs mais je ne l'ai jamais vu. »

**Analyse seule. Rien codé, rien mesuré, rien lancé.** Tout est lu dans le code
et les fichiers (disque = HEAD sur les fichiers cités). Rien n'a été regardé à
l'écran ni écouté pendant cette session.

## 1. Verdict

Elle a raison, deux fois.

1. **Dans l'app, une Quatre Lunes = une Trois Lunes avec un cadre argent et un
   croissant de plus.** Rien d'autre.
2. **Ce qui avait été imaginé pour le cerf (gravé, bois qui brûlent, neige sous
   le verre) n'est jamais arrivé dans l'app.** Ça existe en images fabriquées
   sur le Mac et dans un banc de test, jamais dans ce qu'elle ouvre.

## 2. Ce qu'elle voit aujourd'hui, moment par moment

| moment | Trois Lunes | Quatre Lunes | différence |
|---|---|---|---|
| le sachet avant ouverture (signal lumineux) | même signal | même signal | **aucune** |
| la carte sort et se pose (flash, son, vibration) | identique | identique | **aucune** |
| la musique du manège | selon le sachet (noir / orange) | selon le sachet | **aucune** — un sachet orange peut donner une légendaire |
| sous la carte au manège | 3 lunes | 4 lunes, même blanc | un croissant |
| la carte en main, penchée | bande de reflet or, poussière, vitre | **la même bande or**, même poussière, même vitre | cadre argent + 4 croissants, peints dans l'image |
| la plongée (14 s) | même trajet | même trajet, écrit pour une autre carte | le son seulement (collection) |
| la collection | rangée « Trois Lunes » | rangée « Quatre Lunes », mêmes pastilles, vignette fixe | le titre |

Deux fautes contre sa règle, déjà dans l'app :

- la légendaire porte **une bande de reflet qui traverse** (un balayage) ;
- cette bande est **or** sur un cadre **argent**.

## 3. Pourquoi elle n'a jamais vu le cerf imaginé

Le cerf = « Le Souverain » (Forêt des Veilles, légendaire). Elle l'a eu en main
le 18-09, avec le rendu commun à toutes les cartes.

| ce qui était promis | où ça vit | dans l'app |
|---|---|---|
| le cerf gravé, poils qui prennent la lumière un à un | images Python (`maquette.py`) | non |
| les bois qui brûlent de leurs propres pixels | images Python + banc `-mondeLab -mondeVie` | non |
| la neige sous le verre, météo par monde | images Python | non — l'app ne lit même pas le monde de la carte |
| la nacre (Bois) | images Python | non |
| la lampe du pouce | le plan seulement | non |
| le piano à part | le plan seulement | non (l'ancien son légendaire existe, plongée en collection) |

Les cinq causes :

1. **Le travail est parti ailleurs.** Après le plan du 20-09, tout l'effort est
   allé sur « entrer dans la carte » (le Passage, banc). La carte **en main** —
   ce qu'elle voit en premier — n'a rien reçu.
2. **Le banc n'est pas l'app.** Il ne s'ouvre que par argument de lancement, au
   simulateur, avec des fichiers posés à la main. Aucune utilisatrice ne peut y
   arriver.
3. **Son ordre du 20-09 soir** (« travaille qu'au simulateur, tes rendus sont
   horribles ») : plus rien n'est allé sur son iPhone, et rien n'est revenu lui
   être montré ensuite. Le chantier s'est arrêté le 20-09 (dernier commit
   `4e854aaa`, v2 du feu écrite, jamais compilée).
4. **L'app ne reçoit que l'image.** Les masques de chaque carte (profondeur,
   plans, feu) existent pour les 14 cartes publiées, mais sur le Mac seulement.
   L'app télécharge le PNG, puis applique la même profondeur à toutes.
5. **Le rendu ne sait pas la rareté.** Le shader de la carte n'a aucune entrée
   de rareté ; la rareté ne choisit que le son.

Noms techniques : `carteLuneV5` (`Nosfy/CarteLune.metal:185`), `CarteVivante`
(`Nosfy/Views/CarteLuneLab.swift:249`, son `:754`), `ForgeServeur.swift:62-85`,
`LuneForge.swift:523-553`, banc `MondeCarteLab.swift`, `CarteVie.metal`.

## 4. Ce qui existe et peut resservir

- kits des 14 cartes : profondeur, détourage, six plans, masque feu / émissif /
  ciel, tête et yeux (`tools/carte-lune/profondeur/`, scripts `cuire_*.py`) ;
- le feu depuis les pixels chauds, vu au simulateur (v1) ;
- la maquette Python avec ses trois météos.

Ce qui manque encore partout : le masque de **gravure** (relief), la **nacre**,
la **neige** dans le shader, la **lampe**, les quatre barreaux (`-sansRelief`,
`-sansBraises`, `-sansNeige`, `-sansLampe`), et **le chemin de livraison** des
masques jusqu'au téléphone.

## 5. Ce que je recommande (ordre)

Principe : la différence doit être là **où elle regarde en premier**, donc la
carte en main, pas l'entrée dans la carte.

1. **La carte en main, sur le cerf seul, au simulateur.** Bande or retirée sur
   la légendaire ; gravure cuite par script depuis l'image ; braises depuis ses
   pixels chauds ; neige fine. Trois Lunes intacte. Montré en planche côte à
   côte Trois / Quatre Lunes au même angle, **crops ×3**. Son verdict avant la
   suite.
2. **Les deux autres légendaires publiées** (Dragon d'Obsidienne, Le Grand
   Silence) par le même script, sans main humaine — la preuve que ça tient pour
   les 3 mondes.
3. **La collection** : vignette légendaire cuite (photo de l'objet, fixe).
4. **La sortie du sachet** : la légendaire annoncée avant d'être vue.
5. **Mesure chauffe sur son iPhone**, barreau par barreau, puis livraison des
   masques par le serveur (décision back-end), puis piano.

## 6. Décisions à prendre par elle

- D1 — commencer par la carte en main (recommandé) ou par la sortie du sachet ;
- D2 — le banc « entrer dans la carte » : gelé pendant ce temps (recommandé) ;
- D3 — les masques voyagent avec l'image depuis le serveur (recommandé) ou sont
  embarqués dans l'app ;
- D4 — je lui montre d'abord la maquette du cerf existante (planche + film du
  20-09), pour qu'elle dise si la direction est la bonne avant tout code.

## 7. Non prouvé ici

- aucun écran regardé, aucun son écouté : tout vient du code ;
- la qualité de la gravure sur une peinture très sombre ;
- le risque « peau de girafe » de la neige et des braises ;
- le coût sur son iPhone (profil déjà 🔴).

## 8. Site de doc

`briques.ts:48` dit déjà ⚪ « RIEN dans l'app, RIEN mesuré sur iPhone » : l'état
est juste, pas de pastille à changer. À corriger au prochain passage : la note
de `briques.ts:49` dit « NON commité » alors que le banc est commité
(`9d4bf19c`), toujours hors produit.
