# Ouvrir la chambre longue — le plan (13-09)

**Le problème, dit par Kathryn le 13-09 :** « j'arrive pas à bien cliquer dessus sur les
widgets pour voir le détail » — le double tap (deux relâchements courts, immobiles, à
moins de 0,32 s) ne se déclenche pas assez souvent au doigt. **Les contraintes, dites
dans la même minute :** ne rien enlever à l'expérience actuelle — **le tap simple garde le
mini-détail** (la card se retourne), **l'appui long garde la vibration** (les cards
tremblent, on change de widgets). Et la fluidité, jugée « pas très bien », se mesure
avant de se corriger.

Rien n'est codé. Ce plan attend son verdict.

## 1. Ce qui existe aujourd'hui (lu dans `CardTouche`, WidgetsCards.swift)

| geste | ce qu'il fait | où |
|---|---|---|
| tap simple | la card se retourne : le mini-détail | `CardTouche.onEnded`, `.home` |
| appui long | l'édition : les cards vibrent, on réordonne / échange | `.home(onEdition:)` |
| deux taps < 0,32 s | ouvre la chambre longue | `finPrecedente` / `seuilDouble` (13-09) |
| glisser | l'échange de widgets pendant l'édition | le `DragGesture` de la card |

Le double tap vit DANS le `DragGesture` existant (jamais `onTapGesture(count: 2)`, qui
retarderait tous les taps simples). Son défaut n'est pas le code, c'est le geste : deux
touches rapides et immobiles sur une card qui, au premier tap, **se retourne déjà** — le
doigt hésite, la deuxième touche arrive après 0,32 s ou bouge de quelques points, et rien
ne s'ouvre. Sur le simulateur ça passe ; au doigt, non.

## 2. Les portes possibles

**A. Le mini-détail EST la porte (recommandée).** Tap 1 : la card se retourne (inchangé).
Tap 2, **sur la face retournée, quel que soit le délai** : la chambre s'ouvre. Le
mini-détail devient l'antichambre du détail long — c'est la progression naturelle
(« voir » → « voir plus »), aucune précision de timing, aucun conflit avec l'appui long
(il reste l'appui long) ni avec le glisser (il reste le glisser). Un glyphe discret sur la
face retournée (le chevron d'iOS, en bas à droite, gris) dit que c'est une porte — pas une
phrase, la règle des textes du 13-09. **Coût : une heure.** Une ligne de `CardTouche` (si
la card est retournée, un tap ouvre au lieu de re-retourner) et le glyphe sur la face
arrière de chaque card.

**B. Le double tap tolérant.** Garder le double tap mais élargir la fenêtre (0,32 → 0,45 s)
et tolérer 12 pt de mouvement. Moins de ratés, jamais zéro : le geste reste un geste de
précision, et le premier tap retourne toujours la card sous le doigt. **Coût : dix
minutes.** Peut se combiner avec A.

**C. Glisser vers le haut sur la card.** Un tirage vertical de 40 pt ouvre la chambre (la
feuille monte du bas : le geste dit ce qui va se passer). Conflit à régler avec le
glisser d'édition (horizontal) et avec le défilement de la home — un axe à trancher
dans le `DragGesture`, et le bord bas appartient à iOS. **Coût : une demi-journée**, avec
la sonde de gestes.

**D. Appui long → menu.** L'appui long ouvrirait un petit menu (Détail · Modifier) au lieu
de lancer directement l'édition. Rejeté d'avance : il change l'expérience qu'elle veut
garder (la vibration ouvre l'édition, tout de suite).

## 3. La recommandation

**A + B ensemble.** A parce qu'elle ne demande aucune précision et qu'elle donne un sens au
mini-détail ; B parce que ça ne coûte rien et que ceux qui double-tapent vite continueront
d'y arriver. Le tap simple, l'appui long et le glisser ne bougent pas d'un point.

À mesurer au doigt sur SON téléphone avant tout verdict (la sonde de gestes de
`tools/nav/fouettage`, dix ouvertures de suite, compter les ratés) : le simulateur ne sait
pas taper.

## 4. La fluidité — mesurer avant de toucher

Le skill `woop-performance` est la loi : aucune décision sans un chiffre pris sur son
téléphone, thermique à 0 au départ. Le plan de mesure, dans l'ordre :

1. **La chambre ouverte, immobile**, 30 s, avec `-sondeVol` : le processeur de la page. La
   référence à battre : une page immobile de l'app coûte 27 à 39 %.
2. **Les barreaux**, un par un, pour accuser ou disculper : `-sansChambre` (le témoin), puis
   la feuille sans son `.ultraThinMaterial` (le verre est le quart du coût de toute page —
   un barreau `-chambreSansVerre` à poser), puis sans les ombres (halos des cases, laque des
   barres, ombre des marches : un `-chambreSansOmbres` à poser).
3. **Les horloges** : la chambre n'a AUCUNE `TimelineView` — mais la courbe du cumul porte un
   halo qui respire en `repeatForever`, et chaque bloc joue son entrée en scène à
   l'ouverture. Compter les battements pendant l'ouverture, puis au repos.
4. **Le défilement** : la feuille est un `ScrollView` sous un masque dégradé ; un masque
   sur un défilement redessine à chaque image. Mesurer avec et sans le masque.

Les suspects, dans l'ordre où je parierais : le verre de la feuille (loi connue), les
ombres portées (une par case du calendrier, 7 à 35 ; une laque par barre), le masque du
rouleau. Le remède connu pour le verre : le garder immobile et opaque en dessous (jamais
redimensionné — il ne l'est pas), ou le remplacer par un dégradé noir plein quand la home
est en séance.
