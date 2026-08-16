# CAD_GLASS — le journal des échecs (15/16-08-2026)

Ce que la carte de verre a coûté avant d'arriver. Documenté à la demande
de Kathryn : chaque échec est une loi pour la suite du fouettage.

## 1. Les dégradés SwiftUI ne feront jamais du verre (4 tours, verdict 0/10)
Trois `LinearGradient` + trois `strokeBorder` d'un `AngularGradient` + deux
ellipses floutées = « du blur, des corner borders dégradés, un halo posé
vite fait ». Un verre n'est pas une couleur : c'est un ÉCLAIRAGE. Chaque
couche peinte indépendamment lit « dessin » ; il faut que tout sorte d'un
même modèle de lumière.

## 2. Le verre gonflé v1 « noir et orange » (9 tours, verdict 2/10)
Archivé dans `archives/v1-noir-orange/`. Deux lampes, fumée, rayons —
auto-jugé ~9,5, recalé à 2/10. Les fautes mesurées ensuite :
- corps 2,8× trop clair au centre (0,141 vs 0,050), 3,7× au coin haut-droit ;
- CELLULE RECTANGULAIRE : alpha résiduel 1-3/255 sur tout le rectangle du
  shader + trois rayons décoratifs → boîte visible à brightness ×16 ;
- dynamique plate (P10-P90 = 0,095-0,159) là où la photo alterne noir
  véritable et événements (0,029-0,241) ;
- des lumières inventées (stries, fumée, rayons « esthétiques ») que la
  référence ne contient pas. LA LOI : chaque lumière doit pointer son
  pixel dans la photo, sinon interdite.
- L'AUTO-JUGEMENT NE VAUT RIEN : juger « à l'œil » son propre rendu contre
  une photo qu'on regarde de mémoire = ~7 points d'écart avec le verdict
  réel. Depuis : sondes chiffrées (zones, profils, événements) + calque.

## 3. Les échecs de MESURE (les plus chers)
- **Sonde au mauvais endroit** : le bas de carte supposé à yT+381 px alors
  que la carte fait 375 px → « fil bas mort partout (0,00) » pendant un
  tour entier. Les bords se DÉTECTENT au gradient, jamais supposés.
- **Écran supposé 393 pt** : le sim fait 402 pt (1206 px) → j'ai cherché
  les fils lumineux 14 pt trop à l'intérieur et conclu qu'ils manquaient
  alors qu'ils existaient.
- **Arc de coin sondé au mauvais rayon** (26 px au lieu de ~36) : je
  sondais DANS le verre → conclusion fausse « les arcs sont morts »,
  corrigée en re-mesurant (les arcs sont des dégradés à structure).
- **Le max ne dit pas la présence** : mes sondes calaient des pics de
  1 px pendant que Kathryn voyait des MASSES lumineuses à 1,7 px/pt.
  Toute preuve doit exister aux DEUX échelles (microscope + échelle réelle).

## 4. Les pièges SwiftUI/Metal payés
- **La fente `detail` gonfle son hôte** : des lignes gelées à 358 pt
  débordent la proposition et `.frame(width:)` CENTRE l'enfant trop grand
  → carte fermée à 390 pt au lieu de 362, encarts 6 pt au lieu de 20,
  symétriques donc invisibles. Remède : le détail vit en `.overlay` d'un
  `Color.clear` (un overlay ne pèse rien dans la mesure).
- **Le pic sur l'arête perd la moitié de sa lumière** : une gaussienne de
  fil centrée à d=0 est mangée par la couverture alpha (inside=0,5 au
  bord). Le fil doit vivre ~0,9 pt DANS le verre.
- **La nappe chaude en double** : FlammeJauge posait sa lumière par-dessus
  le shader → +0,03-0,05 partout. Une seule source de vérité par pixel.
- Les hotspots de coins à longue portée (exp(-d/52)) coulent le long des
  flancs et détruisent les enveloppes voisines : un hotspot meurt en
  10-20 pt.

## 5. Les échecs de LECTURE du brief et de la cible
- Trois frappes successives sur LE COIN alors que Kathryn pointait « le
  petit bout JUSTE AVANT le coin » (la barre de la tranche haute,
  x 12-22 %). Aller trop vite fait frapper à côté : reformuler la cible
  (zone, coordonnées) AVANT de frapper.
- La « voûte » tuée par excès de purge alors qu'elle était pointable
  (haut int 0,106 > centre 0,050) — la purge aussi doit être mesurée.
- Le jury d'agents ne vaut que sur des PLANCHES préparées (mêmes zones,
  mêmes échelles) avec un format de verdict imposé ; en libre, il
  généralise.

## 6. LA POUSSÉE DU COIN DROIT (17-08) — quatre leçons payées
- **NaN × 0 = NaN.** `atan2(max(vx,0), max(vy,0))` vaut `atan2(0,0)` —
  indéfini — sur TOUT ce qui est à gauche et sous le coin. Le garde
  `× gate` (nul dans cette zone) ne protège de rien : le NaN traverse
  l'énergie, la couleur ET l'alpha. Résultat : un **panneau noir
  rectangulaire** sur l'intérieur de la carte, aux bords exactement
  x = W−26 pt et y = 26 pt (la signature du coin). Invisible aux sondes
  de flanc, qui ne regardent que les 18 premiers points — c'est
  `zones.py` qui l'a attrapé (centre 0,001 au lieu de 0,048). Garde :
  `max(v, 1e-4)`, jamais `max(v, 0.0)`, avant toute fonction indéfinie
  en zéro.
- **NE JAMAIS CALIBRER SUR LA RÉFÉRENCE AGRANDIE.** Sa photo fait
  1,35 px/pt, la capture du simu 3 px/pt : pour comparer, j'agrandissais
  la sienne au LANCZOS — qui **dépasse** sur un trait d'un pixel et m'a
  affiché un pic de 0,88 à 48° qui n'existe pas (sa vraie valeur native :
  0,55). J'ai calé mon fil dessus et posé **×1,94 de sa lumière**.
  Loi : mesurer chacun à SA résolution native, et comparer la **masse
  lumineuse intégrée** (invariante par échelle), jamais les pics.
- **Une lumière fonction de la seule distance au bord ne peut être
  qu'une bande PARALLÈLE au bord.** La sienne descend en diagonale
  (le front rentre d'1 pt tous les 2 pt de descente, mesuré case par
  case) ; la mienne avait une pente de 0,00 — mathématiquement
  inévitable. Pour une diagonale, il faut une coordonnée diagonale.
- **Plateau + falaise = un CONTOUR.** Une bande construite en
  `smoothstep` d'entrée, dessus plat, `smoothstep` de sortie a deux
  épaules : elle se lit comme un objet collé (« une tache »), pas comme
  de la lumière. Un seul lobe, sans seuil, se lit comme de la matière.
  Le test qui tranche : la carte numérique par cases de 2 pt — un
  dessus plat s'y voit au premier coup d'œil.

## 7. LA BRAISE DU BAS (17-08) — quatre leçons de plus
- **Une lumière trop HAUTE se lit « nappe », la même couchée se lit
  « fil ».** J'ai donné 19 pt de portée verticale à une braise qui en a
  6 : même énergie, verdict « beaucoup trop gros ». La portée verticale
  se mesure par COUPE VERTICALE (le max à hauteur fixe ne la voit pas).
- **La fausse diagonale.** En cherchant le maximum à hauteur fixe, j'ai
  relié le filament (x=72 %) au lait du coin bas-droit (x>80 %) et
  conclu à une dérive vers la droite. Deux objets sans rapport, une
  géométrie inventée. La coupe verticale a tranché : la crête est à
  0,00 pt à tous les x. (Le vrai rayon incliné existe, mais à 41° et il
  se voit en CHROMIE, pas en luminance.)
- **Chercher la trace d'un rayon jusqu'au bord, c'est attraper le
  coin** : le lait du coin bas-droit gagne toujours, la sonde annonçait
  un « rayon à 94,8 % ». Borner la recherche à x=88 %.
- **Deux sources de référence ne donnent PAS les mêmes valeurs au
  bord.** `reference-card.png` (1,35 px/pt) sous-estime l'arête — sa
  dernière ligne est un pixel de bord à couverture partielle — là où sa
  capture d'écran (1,62 px/pt) la résout (0,86 contre 0,46 au même
  point). Pour un événement DE BORD, prendre la source la mieux
  résolue ; pour l'intérieur, le crop propre. Et une sonde qui cherche
  une crête SOUS l'arête dans un crop sans air bute sur la dernière
  ligne : elle rend alors une « épaisseur » égale à toute sa fenêtre.

## 8. LA CARTE DÉPLIÉE ET LA CADENCE (16-08) — six leçons

### Les unités
- **Deux unités de mesure ne peuvent pas cohabiter.** Certaines lois
  étaient en FRACTION de hauteur, d'autres en POINTS. À 125 pt les deux
  donnent le même résultat ; dépliée à 480, tout ce qui est en fraction
  enfle de 3,8×. Le « gros halo blanc » de l'ouvert était une bande dont
  le ventre était en fraction et le front en points : son centre glissait
  de y=27 à y=104 et sa largeur de 5,5 à 44 pt. **Un DÉTAIL (cheveu,
  bande, segment) s'écrit en points absolus ancrés à une arête ; seul un
  CHAMP (le bol, un dégradé général) a le droit d'être en fraction.**
- **Le même y absolu ne tombe pas au même endroit de l'arc selon le
  rayon.** L'allumage du fil droit, ancré au haut de la carte, s'allumait
  à 30° sur la grande carte et restait mort sur la petite. Ce qui touche
  un coin s'ancre au POINT DE TANGENCE, pas au bord de la carte.
- **Le repère du shader et celui de la capture ne coïncident pas sur la
  carte dépliée** : les cloches tombaient 38 pt trop bas. On cale sur ce
  qui SE VOIT, pas sur ce que le code raconte.

### La géométrie, encore
- **Le rayon des coins déduit du code au lieu d'être mesuré.** Le code
  dit `26 → 55` à l'ouverture ; le rayon réel de la capture vaut **20 pt**.
  Deux tours de mesures d'arc à jeter, et un correctif posé sur un arc
  qui n'existe pas. La règle est pourtant écrite plus haut dans ce
  fichier. **La géométrie se mesure à CHAQUE état, jamais ne se déduit.**

### La cadence
- **Mesurer le BASELINE avant d'attribuer un coût à un mouvement.** On a
  optimisé le dépliement (chemin court dans le shader : ControlMap, grain
  et accidents fins coupés en course) et gagné 30 → 34 images distinctes
  par seconde… pour découvrir ensuite que la carte IMMOBILE en produit
  31,8 quand l'enregistrement en capte 57. Le plafond est PERMANENT, il
  n'a rien à voir avec la course. Une heure de travail sur le mauvais
  poste, faute d'avoir mesuré le repos d'abord.
- **Un drapeau qu'on ne mesure pas est un drapeau qui n'existe pas.**
  `allege` était passé au verre depuis des semaines sans y rien faire —
  et le fichier le documentait lui-même (« sans effet tant que le shader
  est figé »). Personne ne l'avait vérifié au film.

### SwiftUI
- **Un enfant plus grand que son hôte GONFLE l'hôte** (déjà payé avec la
  fente `detail`, repayé avec un cercle de flaque de 98 pt dans un
  médaillon de 58 : le `multiply` a noirci un quart de la carte et le
  médaillon a changé de taille). `background` et `overlay` ne pèsent
  RIEN dans la mesure : c'est là que vivent les lumières débordantes.
- **`minimumScaleFactor` fait sauter la taille du texte entre deux
  états** : la place disponible change au dépliement, donc SwiftUI
  rétrécit le texte dans la carte fermée et le rend plein dans l'ouverte.
- **Une ligne composée depuis `sets` sort VIDE au banc** : `sets` y est
  vide et la liste, elle, affiche des valeurs de repli. Toute donnée
  affichée doit partager les replis de sa voisine, sinon elle disparaît
  là où l'autre s'affiche.

## 9. Les échecs d'outillage
- `xcodebuild | grep` masque le code de sortie (payé encore) : toujours
  `> log 2>&1; EXIT=$?` + `stat` du metallib AVANT toute capture.
- Un tour de jury a jugé des captures effacées : vérifier l'existence des
  fichiers avant de juger.
