# Les Cimes Éteintes — ténèbres et braises

18 septembre 2026. Deuxième famille de Nosfy, après La Forêt des Veilles.
Kathryn valide les quatre créatures noir/orange : « trop belles les cards de
cet univers », puis demande des paysages et de sceller les deux familles.
Les noms FR/EN sont des noms éditoriaux de travail. Les fichiers sont des
références d’atelier ; aucune publication Supabase ni installation iPhone.

## Signature fixée

Noir profond, orange braise, suie, cendre, obsidienne et montagnes inquiétantes.
Créatures reconnaissables dans une famille prédéfinie, pas une espèce improvisée
à chaque tirage. La première famille garde la forêt, la brume et la lumière
lunaire ; cette seconde famille doit se reconnaître sans lire son nom.

Les communes peuvent être une créature ou un paysage. Le corbeau est conservé,
explicitement apprécié ; les paysages complètent la famille sans le remplacer.
Le soin reste élevé partout. La commune demeure sobre ; rare et légendaire
accentuent fortement les matières shiny noires et cuivrées. Ce shiny est peint :
aucune animation supplémentaire n’a été implémentée.

## Six références conservées

| Rareté | Français | English | Illustration |
| --- | --- | --- | --- |
| Commune | Corbeau de Suie | Soot Raven | [PNG](01-commune-corbeau-de-suie-v3.png) |
| Rare | Aile d’Ambre | Amberwing | [PNG](02-rare-aile-d-ambre-v3.png) |
| Épique | Loup de Cendre | Ash Wolf | [PNG](03-epique-loup-de-cendre-v3.png) |
| Légendaire | Dragon d’Obsidienne | Obsidian Dragon | [PNG](04-legendaire-dragon-d-obsidienne-v3.png) |
| Commune, paysage | La Faille Ardente | Emberrift | [PNG](05-commune-la-faille-ardente-v1.png) |
| Commune, paysage | Le Col des Cendres | Ashen Pass | [PNG](06-commune-le-col-des-cendres-v1.png) |

Mode : outil intégré `image_gen`, une génération par illustration. Prompts
exacts : [quatre créatures](prompts-v3-braise.json), [deux paysages](prompts-paysages.json).
Dimensions et empreintes : [images.json](images.json). Les six PNG font 1024 × 1536.

## Revue artistique

Les six images ont été regardées. Le corbeau apporte une présence intime et
un plumage mat ; la chauve-souris se distingue par ses membranes d’ambre noir ;
le loup par sa crinière minérale ; le dragon par ses écailles et son envergure.
Les deux paysages gardent des masses noires et une lumière orange localisée.
Ils représentent respectivement une gorge avec arche et un col entre deux aiguilles.

La qualité de l’image nue ne valide pas le rendu dans l’app. Avant publication :
contrôler le dragon dont l’aile gauche atteint le bord et les marges de la
chauve-souris sous le cadre existant ; vérifier les noirs, les visages et les
différences de rareté à taille iPhone. Le shiny animé et son coût restent ouverts.

## Itérations écartées

- Les Marées Muettes sont rejetées : Kathryn n’aime pas les créatures marines.
  Les quatre générations avaient terminé au moment de la demande d’arrêt ;
  elles ne sont ni retenues ni publiées.
- Les premières Cimes, corbeau / lynx / gypaète / bouquetin sous la lune,
  sont rejetées : trop claires et trop proches de la première famille.
- `prompts.json` archive cette v1 ; `retouches.json` conserve une proposition
  de v2 préparée mais **jamais envoyée**. La direction noir/orange et les
  nouvelles créatures l’ont remplacée avant génération.
- La demande explicite d’un dragon d’obsidienne remplace l’exclusion générale
  des dragons ; les dragons féériques et colorés restent hors direction.

## Contrat commun

Les références sont définies à l’avance et communes à tous les propriétaires.
FR et EN sont deux noms de la même référence, pas deux cartes différentes.
La famille artistique est distincte de l’identité précise de chaque carte.
Une image neuve par utilisateur ou un regroupement de plusieurs arts sous un
même doublon ne satisfait pas ce contrat. Les cartes non obtenues restent vides
dans la collection. Le scellement Git conserve l’atelier ; il ne publie pas
automatiquement ces références dans le tirage de l’app.
