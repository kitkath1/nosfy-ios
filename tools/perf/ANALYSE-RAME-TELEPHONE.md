# « ÇA RAME DE FOU, DES FOIS ÇA MARCHE » — l'analyse des trois pages qu'elle nomme (05-09-2026)

Verdict de Kathryn, sur son iPhone : « ça fait ramer de fou le téléphone, des
fois ça marche ; sur la homepage c'est horrible, pareil sur le détail d'exo ou
exercices. »

> **Ce document est une ANALYSE STATIQUE, pas une campagne.** Le téléphone
> appartient aujourd'hui à la session performance (interdiction d'y monter un
> build), et le simulateur est un instrument CASSÉ pour ces pages
> (`tools/home-v2/CHAUFFE-HOME.md` §0 : trois relevés successifs de la même
> home = 8,7 · 18,7 · 5,6 img/s — le bruit dépasse l'effet). Donc : ce qui
> suit **se lit dans le code** (`fichier:ligne`, citations verbatim) et se
> range en suspects À MESURER — jamais en coupables. La méthode et les pièges :
> le skill `woop-performance`, payé ce matin même.

---

## 0. D'ABORD : « des fois ça marche » a déjà une explication mesurée

L'intermittence n'est probablement PAS un moteur qui s'allume et s'éteint.
Trois faits établis par la campagne du matin :

1. **Au-dessus de l'état thermique 1, iOS BRIDE** — et deux essais successifs
   ne se ressemblent plus. Un téléphone chaud rame ; le même, froid, « marche ».
2. **Relancer l'app en boucle MAINTIENT le téléphone chaud** — une partie de ce
   qu'elle a senti pendant la campagne venait des mesures elles-mêmes (piège
   n° 3 du skill, avoué et payé).
3. **Une séance OUVERTE fausse tout** : elle tient les galets « dispo » de la
   route à 46-72 battements/s, la card route et la vidéo (skill §6.9). La home
   avec séance et la home sans séance sont DEUX pages différentes.

**Et la question à poser avant toute conclusion : QUEL build est sur son
téléphone ?** Le remède majeur de la session perf (`10a0d55`, « on n'anime plus
en redessinant » : 33-38 % → 4-18 % de processeur, mesuré sur SON téléphone,
rendu validé par elle) date de ce matin 10 h 13. Si son build est antérieur,
elle juge les moteurs d'AVANT le remède — et le premier geste n'est pas
d'analyser, c'est de **reposer un build à jour** (ce que la session perf
s'apprête à faire).

## 1. LA HOME — le chantier est déjà tenu, je n'y touche pas

C'est le territoire de la session perf : registre
`tools/home-v2/CHAUFFE-HOME.md`, campagne `-souffleHorloge` en vol dans l'arbre
(LisereRespirant, MenuNappe, CardRoute, ProfilLune, HomeNuit…), et `10a0d55`
déjà scellé. Les chiffres établis : châssis nu **1 %**, page immobile
**27-39 %**, le verre = **un quart**, les vidéos = **rien**, les horloges
désaccordées = **10 points**.

Un seul apport de ma journée à leur signaler (§4) : **la pastille de séance vit
désormais dans l'île par défaut** — son horloge de 15 Hz (`PiluleVagabonde`,
capsule + braises de fond) bat au-dessus de TOUTES les pages tant que la séance
tourne, home comprise. Elle battait déjà avant (pastille sortie) ; le lieu a
changé, pas le moteur — mais c'est une horloge d'app, pas de page : la porte
d'onglet (`RythmeEcran.dort`) ne la fermera jamais.

## 2. LA PAGE EXERCICES — le suspect n° 1 n'a JAMAIS été mesuré

**Un verre natif PAR CARD VISIBLE, posé SUR une vidéo qui joue.**

- la preuve : `ExercisesView.swift:2623` — `.glassEffect(.clear, in: Self.shape)`
  dans la card, montée par le `ForEach(rangs)` de `:1984` ; le fond est
  `ExosFondVideo` (la vidéo `exos-fond-loop.mp4` en boucle) ;
- la loi, mesurée sur la home le 05-09 (skill §4) : « un verre posé **sur une
  vidéo** ne peut RIEN mettre en cache : ce qu'il y a dessous change à chaque
  image, il refait son flou en boucle » — et le verre était **le quart** du
  coût de la home avec SIX verres. Ici il y en a un par card visible
  (~6-8 à l'écran), sur vidéo, dans une liste qui défile ;
- l'aveu d'époque (`woop-page-exos-couronne`, 22-08) : « Restent à juger sur
  l'appareil : la cadence — 8 verres natifs au-dessus d'une vidéo qui joue dans
  une liste qui défile ». **Ce jugement n'a jamais eu lieu.**

**Le barreau à poser** (il n'existe pas) : `-sansVerreExos` — les cards en
aplat sombre à la place du verre. Dix minutes de code, et la session perf peut
mesurer A/B sur le téléphone. Sans lui, on ne pourra ni accuser ni disculper.

Second suspect, plus petit : le disque de la molette porte un
`glassEffect(.regular.tint(...))` (`:2261`) — un `.regular`, l'interdit de la
maison, ET un verre sur la même vidéo. Même barreau, même mesure.

Les 4 horloges de la page sont, elles, **bien tenues** : 4 `TimelineView`,
4 `paused:` (`RythmeEcran.dort("exercises")`).

## 3. LA FICHE EXO (muscu) — le gros moteur est MORT CE MATIN, sans que personne ne le mesure

**Jusqu'à ce matin, la carte des séries portait une horloge SANS PLAFOND.**

- la preuve, verbatim (`FlammeJauge.swift:94`) :
  `TimelineView(.animation(minimumInterval: bouge ? 1.0 / 30.0 : nil))` —
  `bouge` est vrai PENDANT le geste. **Au repos, l'intervalle est `nil` : la
  fermeture entière (jauge, flammes, dégradés, contrat) était ré-évaluée à
  CHAQUE image de l'écran** — 60 Hz, et jusqu'à 120 sur ProMotion. Sans
  `paused:`, sans porte d'onglet. C'est le motif exact que `10a0d55` vient de
  tuer ailleurs (« on redessine 20 fois par seconde pour tourner une lumière de
  trois degrés » — ici c'était jusqu'à 120 fois, pour faire osciller des
  flammes de 3°) ;
- **l'archivage de la carte (commit `23b95d9`, ce matin) a retiré ce moteur de
  la fiche** — avec son verre (`VerreGonfle`, un `colorEffect` plein carte) ;
- ⚠️ donc si son « détail d'exo horrible » a été senti sur un build
  d'AVANT `23b95d9`, le principal suspect est déjà mort. S'il a été senti
  APRÈS, il faut chercher ailleurs (ci-dessous). **C'est la deuxième raison de
  savoir quel build elle tient.**

Ce qui reste sur la fiche muscu, par ordre de soupçon :

1. **le galet « Start exercise »** (`LaunchPebble`) : sa renaissance = quatre
   passes hors écran sur 2,23 Mpx à 30 Hz pendant ~4 s (mesuré, memoire
   `woop-piege-rideau-player-derriere`) — transitoire mais lourd, et il a déjà
   été pris à rejouer sous un écran opaque ;
2. **mes ajouts du jour**, à mesurer honnêtement (§4) ;
3. la photo héro (6,3 Mo décodés au montage — un coût d'ENTRÉE, pas de
   croisière ; mesuré dans la partition légère).

## 3bis. LA FICHE CARDIO — deux horloges SANS PORTE, un vrai défaut, pas cher

`ExerciseDetailView.swift:2760` (`ExoHeaderGlow`) et `:2804` (le champ de
braise) : **deux `TimelineView` à 30 Hz, zéro `paused:`, zéro porte d'onglet**,
qui nourrissent des shaders plein cadre. Elles ne montent que sur le cardio —
mais si « le détail d'exo » qu'elle a senti était un tapis/escalier, c'est EUX.
Remède connu et invisible : `paused: RythmeEcran.dort(...)` + le pas commun.
(La troisième `TimelineView` du fichier, `:1840`, est un blink de BANC —
`-verreLab` seulement, hors de cause en prod.)

## 4. MES AJOUTS DU JOUR — audités comme le reste, sans complaisance

| quoi | l'horloge / la passe | le verdict de lecture |
|---|---|---|
| l'île par défaut (15 Hz, capsule + braises) | pré-existante (04-09), déjà plafonnée à 15 Hz, `paused: figee` sous le player | déplacée, pas créée — mais elle bat sur TOUTES les pages en séance ; la session perf l'a déjà dans sa campagne (« île de la pilule », skill §6) |
| `DescriptionExo` — le recul (pastille sortie) | **`.blur(5)` PERMANENT sur deux blocs de texte tant que la pastille est dehors, sur la fiche** | rayon FIXE sur contenu STATIQUE : cacheable en théorie, **jamais mesuré**. Remède tout prêt si la mesure accuse : rasteriser le bloc reculé (`drawingGroup()`) ou pré-flouter |
| `ArriveeDouce` (titre + description) | flou 26 → 0 pendant 1,6 s, à l'ARRIVÉE seulement | transitoire ; rayon ANIMÉ donc jamais en cache pendant la course (loi du skill) — 1,6 s de gaussienne sur deux blocs, au pire moment (la page monte ses lecteurs). À mesurer au `pire` (le trou en ms), pas au processeur |
| le nom balayé du grand player (`InviteAnimee` 20 Hz) | UNE horloge de plus, player OUVERT seulement, gelée sous le doigt | le même moteur que l'invite existante ; visible uniquement player plein écran |
| l'archivage de la carte | — | **retire** l'horloge sans plafond + un verre de la fiche (§3) |

## 5. CE QUE JE REMETS À LA SESSION PERF (et ce que je ne fais PAS)

- je ne monte **rien** sur le téléphone (consigne du jour), je ne conclus
  **rien** du simulateur sur ces pages (l'instrument y est cassé) ;
- les deux gestes pas chers qui l'attendent : la **porte des deux horloges
  cardio** (§3bis) et le **barreau `-sansVerreExos`** (§2) pour instruire le
  suspect n° 1 ;
- les deux questions qui précèdent toute mesure : **quel build tient son
  téléphone** (avant/après `10a0d55`, avant/après `23b95d9`), et **une séance
  était-elle ouverte** quand elle a senti la rame (la ligne de sonde le dit :
  `seance`, `onglet`, `therm`) ;
- le protocole est le leur : sonde `-sondeVol`, ABBA, thermique 0, la paire
  (cadence, processeur), médiane, `t > 15`.
