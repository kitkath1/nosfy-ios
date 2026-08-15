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

## 7. Les échecs d'outillage
- `xcodebuild | grep` masque le code de sortie (payé encore) : toujours
  `> log 2>&1; EXIT=$?` + `stat` du metallib AVANT toute capture.
- Un tour de jury a jugé des captures effacées : vérifier l'existence des
  fichiers avant de juger.
