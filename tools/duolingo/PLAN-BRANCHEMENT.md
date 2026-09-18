# §23 — LE BRANCHEMENT : la Duolinguo_page entre dans l'app

> Actualisation18-09 — progression réelle déployée : compte vide au premier
> galet, tout en haut ; puis un galet par séance terminée avec travail.
> Pas d’avance calendaire ni de démo automatique. Récompenses serveur à3/7
> séances par chapitre ; cinq chapitres, trésor final à35. Au-delà, séances
> conservées sans remise à zéro.1074 contrôles Swift,35API PASS ; iPhone à
> qualifier. Référence actuelle (les sections datées suivantes sont historiques) :
> `tools/production/compte-progression-2026-09-18/README.md`.



Demande de Kathryn (25-08) : connecter la page Duolingo à la **Home V2
rouge** et à la **widget card (la troisième)** ; quand on **slide la home
jusqu'au bout** on arrive sur la page Duolingo ; à l'arrivée le **premier
galet s'illumine** et un **petit overlay liquid glass** au-dessus du galet
propose de commencer (**primary + bouton-lien**, et à gauche une
**mini-card sticker flamme + date du jour**) ; confirmer **démarre la
session** et atterrit sur la **RED PAGE EXO** ; il manque un **chevron**
dans le header CHAPITRE pour revenir à la Home.

## L'état des lieux (mesuré dans l'arbre, 25-08)

- La Home V2 rouge = `HomeNuitPage` (HomeNuit.swift:1600), vivante au banc
  `-homeV2` via `HomeNuitLab` — PAS encore branchée au TabView réel
  (WoopApp monte toujours `HomeAuroraView`). Le branchement TabView est un
  chantier À PART (une ligne au B4, rien de plus).
- La rangée des widgets = `CardsRangee` (WidgetsCards.swift:2411),
  **2 slots** de 170×170 (`widgetSlot0/1`). « La troisième » = une card
  NOUVELLE à créer.
- Les gestes de la home (HomeNuit:2142-2185) : le tirage en bloc de la
  grande card — vers le BAS = le tiroir (slider), vers le HAUT = la levée
  (player/lune). Tout nouveau geste doit se glisser LÀ-DEDANS sans casser
  l'existant (non-régression au B5).
- Le départ de séance existant : le slider → `DepartEtat.shared.proposer()`
  → overlay de confirmation → `commencer()` (HomeNuit:3046 — enSeance,
  debutSeance, la card se lève). L'arbitrage du 22-08 (« on ne bascule PAS
  vers les exercices ») reste vrai POUR LE SLIDER ; le chemin, lui, DOIT
  atterrir sur la RED PAGE EXO (sa demande d'aujourd'hui) — deux portes,
  deux chorégraphies, même moteur.
- La RED PAGE EXO = `ExercisesView` (v7 grande card), sait déjà vivre en
  séance (player docké, banc `-exosSeance`).
- La DuolinguoPage vit au banc `-duoLab`, aucune sortie, aucun hôte.

## Les jalons

### B0 — les sorties de la page (préparation, sans visuel)

`DuolinguoPage` gagne deux callbacks et ne connaît JAMAIS son hôte :
`onRetour: (() -> Void)?` (le chevron) et `onDemarrer: (() -> Void)?`
(l'overlay a confirmé). `nil` = le banc actuel, rien ne change à `-duoLab`.
L'étape « courante » reste celle du banc (`-duoEtape`) ; le vrai compteur
de sessions viendra avec le backend (§21), pas ici.

**Portillon** : `-duoLab` rend au pixel près comme avant (capture avant/
après).

### B1 — LE CHEVRON du header CHAPITRE

Un `chevron.left` DANS la capsule de la dalle, à gauche du bloc
« CHAPITRE n / titre » (l'école du chevron de la RED PAGE EXO). Cible
44 pt, encre AU-DESSUS du verre (jamais dans le GlassEffectContainer —
le piège payé du conteneur), il sort avec la dalle pendant le geste
(même sortie 0,11 s). Tap → haptique légère + `onRetour`.

**Question fermée Q1** — le chevron : **(A, défaut)** dans la capsule de
la dalle, à gauche du texte · (B) une pastille de verre séparée à gauche
de la capsule.

### B2 — LES DEUX PORTES depuis la Home V2 rouge

**Porte 1 — LA TROISIÈME CARD.** Une card « LE CHEMIN » à créer dans
WidgetsCards, posée SOUS la rangée des deux widgets : pleine largeur
(354×~110, l'école de l'ardoise de la semaine — la rangée de 170 ne loge
pas un 3ᵉ slot), double coque + liseré de la maison. Contenu : une
mini-pastille-bijou (le composant réel en petit, Ø 44), « CHAPITRE n »
en petites capitales + le titre du chapitre, et la progression muette
(« 3/10 » en chiffre gris). Tap → la page Duolingo s'ouvre
(fullScreenCover, fondu + montée 0,45 s — l'école CoffreFortFlow).
Elle respire en édition comme les autres (CardTouche), mais ne rentre
PAS dans la vitrine (ce n'est pas un widget de stats).

**Question fermée Q2** — la 3ᵉ card : **(A, défaut)** pleine largeur sous
la rangée · (B) la rangée passe à 3 slots de 110 (les widgets stats
rapetissent).

**Porte 2 — LA FIN DU SLIDE.** Le SOULÈVEMENT de la grande card (tirage
vers le haut) prolongé au-delà d'un cran (~180 pt rendus) : la home
glisse vers le haut ET le chemin monte du bas, nourris par le MÊME doigt
(l'école playerLift/levée — une transition continue, jamais un
view-swap sec). Lâcher au-delà du cran = commit (la page Duolingo
prend l'écran) ; en deçà = ressort. EN SÉANCE, ce geste appartient déjà
au player : la porte 2 se désarme (la card et le chevron suffisent).
L'aiguillage vit dans le geste de tirage EXISTANT (HomeNuit:2142) — on
étend, on ne double pas (deux DragGesture sur la même page = le piège
du geste volé).

**Question fermée Q3** — la fin du slide : **(A, défaut)** le
soulèvement vers le HAUT prolongé (le chemin « monte » vers toi) · (B)
le tirage vers le BAS à fond, au-delà du tiroir du slider.

### B3 — L'ARRIVÉE : le galet s'illumine + LE PETIT OVERLAY

Chorégraphie d'arrivée (les deux portes) : la page naît posée sur
l'écran-chapitre de l'étape courante, la cascade de naissance joue,
puis à +0,4 s le galet courant S'ILLUMINE (gains ×1,35 + bloom court
0,6 s + haptique douce) et l'OVERLAY naît au-dessus de lui (spring
0,42/0,80, ancré au galet — il se place au-dessus, ou en dessous si le
galet est dans le tiers haut de l'écran).

L'overlay « liquid glass » (capsule ~300×104) : verre natif `.clear` +
pellicule noire 0,30 AU-DESSUS du verre, encre au-dessus de tout
(l'école de la dalle, verbatim), ombre d'élévation, PAS de queue de
bulle (pas de BD — la proximité fait l'ancrage). Dedans :

- à GAUCHE, LA MINI-CARD (64×82) : fond noir double-coque (l'école des
  minis de la semaine), le STICKER FLAMME de la maison (perle de flamme
  aux arrêts `CardTon.chaleur`) et LA DATE DU JOUR — le jour en gros
  chiffre métallique, le mois en petites capitales dessous (l'école des
  stickers du calendrier).
- à droite : une ligne de titre (voix « vous », registre Apple), le
  bouton PRIMARY en capsule pleine (encre noire sur blanc — l'école du
  slider « COMMENCER »), et dessous le BOUTON-LIEN en texte sourd 0,55,
  sans capsule.

« Plus tard » → l'overlay se dissout (0,25 s), le galet garde une
respiration douce ; un tap sur le galet actif ROUVRE l'overlay (c'est
désormais le sens du tap-avance sur l'étape courante).

**Question fermée Q4** — les textes (défauts) : titre « Session du
jour », primary « Commencer », lien « Plus tard ».

### B4 — LE DÉPART : la session démarre et atterrit sur la RED PAGE EXO

Primary → haptique medium ; l'overlay se ferme et LIBÈRE la scène
(0,12 s — la loi des deux mouvements qui se dévorent) ; le galet pulse
une fois ; la séance DÉMARRE par le MÊME moteur que le slider de la
home (`debutSeance`/`enSeance` partagés — vérifier à l'écriture quel
objet `-exosSeance` simule, et n'en créer AUCUN nouveau) ; à +0,25 s la
RED PAGE EXO arrive avec le player docké. Côté hôte : dans
`HomeNuitLab`, un fullScreenCover(ExercisesView) ; dans l'app réelle
(TabView), `selection = .exercises` — c'est le callback `onDemarrer`
qui décide, la page Duolingo n'en sait rien. Le branchement de la home
v3 au TabView réel reste un chantier à part.

⚠️ Pièges à payer d'avance : les LECTEURS de la duo-page passent à
rate 0 au départ et se PRÉ-RÉVEILLENT au retour (l'école du pré-réveil
— un rate 0→1 en plein geste flushe la couche = écran noir) ; le
fullScreenCover au-dessus d'une page vidéo doit gel(er) la page
dessous.

### B5 — LE FOUETTAGE (avant de montrer, comme toujours)

- Films + détecteur (tools/duolingo/fouette_film.py) : home→duo par la
  card, home→duo par le slide (lâcher AVANT le cran = ressort, APRÈS =
  commit), arrivée + overlay (naissance, « Plus tard », réouverture au
  tap), départ→exo, chevron retour, et l'aller-retour COMPLET
  home→duo→exo→retour.
- Relecture adverse : opacité 0 tappable (l'overlay dissous), double
  withAnimation, geste volé (le slide étendu vs le scroll du chemin vs
  le slider), lecteurs qui survivent au démontage, page ré-évaluée par
  image (l'overlay ne pilote rien par frame), verre aux bounds vivants
  (l'overlay naît à taille CONSTANTE, le spring est un transform).
- NON-RÉGRESSION des gestes de la home : tiroir slider, levée player,
  secret lune, vitrine — les quatre refilmés à l'identique.
- Cadence par régime (sim calme, verdict téléphone).

### B6 — mémoire + captures + verdicts Kathryn

Mise à jour de woop-duolinguo-page (§23) + woop-home-v2. Rien n'est
commité sans son verdict.

## Les quatre questions fermées (défauts proposés, « GO reco » suffit)

- **Q1** chevron : dans la capsule de la dalle (A, défaut) ou pastille
  séparée (B) ?
- **Q2** 3ᵉ card : pleine largeur sous la rangée (A, défaut) ou rangée
  de 3 (B) ?
- **Q3** fin du slide : soulèvement vers le haut (A, défaut) ou tirage
  vers le bas à fond (B) ?
- **Q4** textes : « Session du jour » / « Commencer » / « Plus tard »
  (défauts) ?

Ordre d'exécution : B0 → B1 → B3 (l'overlay se juge au banc `-duoLab`
seul) → B2 → B4 → B5 → B6. Chaque jalon capturé/filmé avant le suivant.
