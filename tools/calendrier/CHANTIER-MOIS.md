# LE BAC DES MOIS — dossier d'intention (posé le 19-08, PAS ENCORE CONSTRUIT)

Vision de Kathryn, posée avant chantier. Rien de ce qui suit n'est codé :
ce document existe pour que la session qui ouvrira le chantier reparte
d'ici, pas d'une réexplication.

## L'idée

Sous le calendrier, la liste devient un bac de **grandes cards
MENSUELLES** — la référence de layout est la card « Любимое » d'Apple
Music (capture fournie le 19-08) : une grande card sombre, le titre
centré en haut, et un **éventail de mini-cards qui se chevauchent** dans
le corps.

- **La première card = le mois en cours** ; les mois précédents suivent
  dans la continuité du scroll.
- **Le comportement de scroll d'aujourd'hui est conservé À L'IDENTIQUE**
  (deux courses : calendrier → mini-barre → titre « Calendrier » ; la
  pile en bandeaux ; l'aimant ; le wipe flouté réservé au vol). Seul le
  CONTENU des pochettes change : une pochette = un MOIS, plus une
  session.
- Les pochettes-sessions actuelles (« 18. Août », sticker, pièces)
  deviennent les **mini-cards dans l'éventail** de leur mois : très
  belles, très lisibles, laissant deviner le sticker, l'ambiance de la
  séance, quelques infos clés.

## La grande card mensuelle

Minimale, à la Apple Music :
- le **nom du mois** (et l'année si ce n'est pas l'année courante),
- le **nombre de sessions réalisées** (« 9 séances »),
- l'éventail des mini-cards de sessions qui se chevauchent (inclinées,
  en escalier — le layout de la référence).

Matière : traitement premium Apple / **Liquid Glass**, ou de subtils
halos noirs / reflets élégants — à trancher AU BANC, selon ce qui
fonctionne le mieux visuellement. (Rappels payés : les bounds du verre
doivent rester CONSTANTS ; le bourrelet du rim EST la signature liquide ;
jamais de bordure — la hiérarchie par la lumière.)

## Les interactions

1. **Tap sur une card mensuelle** → une **page dédiée au mois**.
2. Sur cette page, PLUS TARD : un **player type iPod classic** (molette
   cliquable, cf. deuxième capture du 19-08), en **Liquid Glass** ; le
   **drag du doigt sur la molette** fait défiler les entraînements du
   mois, chaque entraînement étant représenté par sa card de session
   (l'esprit cover-flow, cohérent avec le bac à vinyles).
3. **Interaction avancée, pour après** : **pincer la card mensuelle** →
   elle se déploie en une vue où toutes les petites cards apparaissent
   côte à côte ; le scroll donne alors une vue globale de toutes les
   sessions du mois.

## L'OUVERTURE — la cinématique d'entrée (arbitrée le 19-08, AVANT le jalon 2)

Réf. : les paragraphes marketing Apple (capture iPhone 17 Pro fournie —
gris + gras blanc + le sticker chocolat plaqué sur le texte).

- **Porte unique** : la cinématique ne joue que via « Tout voir » de la
  home (la demande `CalCine.demande` est consommée à l'apparition) —
  jamais sur un simple passage d'onglet.
- **La phrase** : bilan SEMAINE + MOIS, deux lignes, sobre (« Cette
  semaine, **3 séances** 〔flamme plaquée〕 / et déjà **6** en août. ») —
  gris Apple #86868B, chiffres blancs bold, sticker PNG qui se plaque en
  chevauchant le mot (ressort + rotation).
- **L'écriture** : mot à mot (flou+transparence → net, cascade ~70 ms),
  JAMAIS une machine à écrire ; le tout sur UN progrès Animatable (la
  loi des rampes). Ticks d'haptique quand les chiffres claquent.
- **L'arrivée** : le texte s'enfuit dans le flou, le voile noir se lève,
  la page (réelle dessous) arrive DU flou — la grammaire du wipe.
- **Garde-fous** : tap partout = skip (sortie pressée), ~3 s max,
  Reduce Motion = apparition simple, zéro TimelineView.
- **Banc** : `-cineLab` (boucle la cinématique pour fouetter le tempo).

## Découpage pressenti (à valider à l'ouverture du chantier)

- **Jalon 1** : les cards mensuelles dans le bac (éventail de
  mini-cards, nom du mois + compte), grammaire de scroll inchangée.
- **Jalon 2** : la page du mois (tap → page dédiée), simple d'abord.
- **Jalon 3** : le player-iPod en verre (molette + drag circulaire →
  session suivante/précédente).
- **Jalon 4** : le pincement → mosaïque + vue globale au scroll.

## Points ouverts (à trancher avec Kathryn au banc)

- Le tap sur une MINI-card (dans l'éventail ou la page du mois)
  ouvre-t-il toujours la story (le portail actuel) ?
- L'éventail : combien de mini-cards visibles avant un « +N » ?
- La page du mois : que montre-t-elle AVANT que le player-iPod existe ?
- La molette iPod : drag circulaire (le geste iPod) ou balayage simple ?

## État du code au moment où ce plan est posé

Page = `Woop/Views/CalLab.swift`, commit `6d2742a` (« LE BAC À
VINYLES ») + retouches du 19-08 au matin NON commitées : pochettes 360 pt,
`ExoHeaderGlow` du header supprimé, surface ardoise (dégradé blanc
0,11 → 0,055) au lieu du noir pur. Le banc : `-calLab` (+ `-calAuto`
boucle, `-calTune` console, appui long 0,6 s pour la console partout).
Sim dédié kat-cal-18 (`scratchpad/simcal.txt`).
