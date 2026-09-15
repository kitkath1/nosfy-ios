# LE CARDIO — quatre fiches à la robe muscu, le double galet, le graphe, la piscine

**Plan du 15-09-2026, sur la demande de Kathryn** (session woochoper-ios-41) :

> *« Refais les pages "exercices" cardio au même design que les exercices de
> base (layout, design, image, palet, etc.). Pour le HIIT, au lancement de
> l'exercice, le "double palet" où on peut mesurer l'intensité (km/h) et le
> temps avec tap stop — page qu'on a bossée il y a quelques semaines. Dans la
> page HIIT il y a la description comme les pages exercices, mais une fois la
> session terminée on retrouve à la place de la description le graphe issu du
> détail du widget HIIT "n séances" où on voit les repos et intervalles —
> exactement le même composant. Dans l'overlay (détail de la séance) on indique
> HIIT et en dessous les intervalles, pour garder la constance avec les
> exercices de base. Piscine : pas de galet ; le user saisit à la main
> (composant liquid glass inspiré d'Apple) le nombre de longueurs sur X mètres,
> avec un petit plus blanc dégradé ; ça s'ajoute au back-end, et dans l'overlay
> on indique Piscine et en dessous le nombre de longueurs. Escalier : même
> principe que le HIIT (double galet, le temps qu'on peut stopper ou pas), et à
> la place du km/h une vitesse de 1 à 15 ; même graphe avec intervalles s'il y
> en a. Tapis à vitesse modérée : même layout, le user choisit sa vitesse.
> Fais un plan, informe le back-end, ne code pas. »*

**Rien n'est codé.** Tout ce qui suit est LU dans l'arbre du 15-09 au matin
(les `fichier:ligne` peuvent glisser : trois sessions y travaillent — pastille,
back-end, chauffe) et dans le site de doc (`docs/site/content/*.ts`), qui reste
la référence des états.

---

## ⚡ LES VERDICTS DU 15-09 (ses réponses au §2, et ce qu'ils changent)

| question | son verdict | ce que ça change dans ce plan |
|---|---|---|
| **Q1** description cardio | **oui**, courte, comme les exercices | les 4 `cue`/`mistake` réécrits une phrase (A) |
| **Q2** le repos est un segment | **oui, important** — « 30 s à 15 km/h puis 1 min à 9 km/h, il faut le noter, c'est lié au graphe » | ⚠️ le repos garde **SA vitesse** (9 km/h), pas 0 : c'est une RÉCUP au sens du widget (`speed < seuil` → `temps_recup`, `recup_moy`) — et c'est juste. Le cadran passe en mode récup au stop (Q15 de l'économie). `kind` = `.recuperation` si vitesse > 0, `.repos` sinon |
| **Q3** l'escalier | graphe **« en vitesse-niveau, comme un tapis de salle »** ; **« pas en mode sprint bien sûr »** | `EchellePaliers.escalier` (1-15, unité « niveau ») ; ses segments montés sont `.acceleration`, jamais `.sprint` ; exclu du HIIT au serveur — **FAIT ce matin par la session back-end** (`20260915150000_widget_hiit_sans_escalier.sql`, 16 exclusions, verif 14 ✓ + 31 ✓) |
| **Q4** tapis modéré ≥ 15 | (pas contredit) | on laisse |
| **Q5** l'argent | **PAS 20 par intervalle** : la SÉANCE est jugée à l'intensité — HIIT 100 → 300 (km/h 15 / 17+, temps, nombre d'intervalles, repos), escalier 50 → 100 (temps × niveau), piscine 1 longueur = 20 ; « c'est là que l'IA intervient » ; tout en base + documentation | **le barème vit au serveur, calculé à la clôture** → `PLAN-ECONOMIE-CARDIO.md` (même dossier). La dalle du set ne dit plus « +20 » ; `seriesPayantes` reste la muscu ; un `cardioFait` ouvre la clôture |
| **Q6** compteur piscine | (à voir sur maquette) | reco inchangée |
| **Q7** quand le graphe remplace la description | « une fois la session terminée » | dès qu'un segment FAIT existe pour cet exo (ce passage, sinon la dernière séance datée) — reco tenue |
| **Q8** Finish | **termine l'EXERCICE, pas la séance** | reco tenue : la scène se démonte, la fiche revient avec le graphe ; la séance se termine par la dalle |
| **Q9** fête vs décideur | (pas contredit) | le décideur fait loi ; la pop-up `.fire` encourage SANS montant |
| **Q10** premier set | (pas contredit) | part seul à l'arrivée des pastilles |
| **overlay** (D) | **« pour tous les cardio, une ligne et une description, même UI, sans les flammes »** | la rangée d'un exo cardio dans le grand player : nom + une ligne par intervalle / la ligne des longueurs, **pas de `FlammesRow`** (les flammes = les séries de muscu) ; le gain à droite vient du carnet, pas d'un « +20 » par ligne |

Ce qui reste à trancher est au §8 de `PLAN-ECONOMIE-CARDIO.md` (Q11-Q15 : les
chiffres du barème, le tapis modéré, le plafond piscine, l'IA, le cadran en récup).
**15-09 midi : « je suis d'accord avec tes propos » — Q11-Q15 tranchées sur mes recos.
« Go serveur » (à la session back-end) et « go app sur simulateur ».**

---

## ⚡ L'ÉTAT AU 15-09 APRÈS-MIDI — ce qui est FAIT, ce qui est MESURÉ, ce qui reste

**Côté app (moi), codé et mesuré au simulateur kat-exos — rien commité :**

| chantier | fait | preuve | pas mesuré |
|---|---|---|---|
| **A** la robe | `RobeFiche` (muscu · galetCardio(mode) · piscine) ; photo, titre, description réécrite (4 `cue`/`mistake`), galet d'aube sur les 4 fiches ; `cardioPage` / steppers / « Enregistrer » archivés | `captures/j1-hiit-fiche.png`, `j5-piscine.png` | au doigt, au téléphone |
| **B** le double galet | `ModeCardio` (.hiit 0-20 dép. 10 · .escalier 1-15 dép. 6, jamais Sprint · .tapisModere) ; `SeanceTapis` à deux vitesses (effort / récup, bascule au stop, l'encre dit RÉCUP) ; `onSetFini` / `onRecupFinie` → la fiche écrit des `CardioPhase(isDone: true)` dans le bloc du passage ; dalle « SET n END · récap » SANS montant ; Finish = fin de l'exercice ; `-sansBraiseTapis`, `SondeVol.tic(4)`, `RythmeEcran.dort` ; banc `-cardioAuto` | journal `[flow] phase écrite` : HIIT 10 / 13 / 16 km/h (Accélération · Accélération · Sprint) + récups à 7 ; escalier 6 / 9 / 12 + récups au niveau 1 ; `captures/j2-scene-recup.png`, `j2-escalier-scene.png` | le TOUCHER (le banc appelle le modèle), la cadence et la chauffe (ABBA sur son téléphone), la poussée avec une session |
| **C** le graphe | `EchellePaliers` (.tapis = les nombres d'avant à l'identique · .escalier), `LegendePaliers` partagée, `GrapheCardioFiche` (138 pt) à la place de `DescriptionExo` dès qu'un segment fait existe ; `rafraichirSegments` hors du corps | `captures/j2-fiche-graphe.png`, `j3-escalier-graphe.png` | la chambre HIIT avant/après (identique par construction) |
| **D** l'overlay | `SlateLigne.Genre`, `SlateGroupe.lignes(de:)` / `cardio` / `resume`, `SlateRang` sans flammes, `SetHistoryRow(rank:ligne:)` sans gain ; `groupesDeSeance` + `buildGroupes` ; banc `-grandPlayerOuvert` | `captures/j4-grand-player.png` | la story 2 (même `SlateListe`) |
| **E** la piscine | `LoggedExercise.longueurs` / `metresParLongueur`, `CompteurLongueurs` + `CompteurLongueursVue` (25 / 50 m, −, +) à la place du galet, écrit à chaque + ; banc `-piscineAuto` | journal `[flow] piscine : longueurs=5 → 4` ; `captures/j5-piscine.png` | la matière (v1 obsidienne peinte — à juger), le serveur |
| la clôture | `Workout.cardioFait` ouvre la clôture, la fête, la story, le sachet ; `reglerFinDeSeance(cardio:)` ; `ClotureSeance` décode `pieces_cardio` / `pieces_total` / `sachet_cardio` / `cardio_detail` / `cardio_rejeu` / `bonus_progres` ; `Annonce.cardio` → dalle « +N cardio » à la réponse, jamais sur rejeu ; le pull pose `isDone: true` et lit `piscine {…}` ; `PiscineRow` dans `push` | **MESURÉ DE BOUT EN BOUT** (banc `-sessionBanc … -terminerSeanceAuto`, compte de test) : HIIT → `[flow] cardio payé : 102 pièces` (base 100 + 25 s à 16 km/h), sachet sans série ; piscine → `80 pièces` (4 longueurs × 20), la ligne `piscine_longueurs` poussée puis lue | la dalle au doigt (passée sous la story), le pull piscine sur base vide |
| **la nav** | verdict Kathryn 15-09 midi : « pas de menu (nav) avec les deux galets, jamais — juste le slider » → `bandeVisible` faux pendant la scène | `captures/j2-scene-sans-nav.png` | — |

**Côté serveur (session back-end, FAIT le 15-09)** : le filtre escalier
(`20260915150000`) ; le barème + la raison `cardio_seance` + `piscine_longueurs` +
`pieces_cardio_seance()` + l'enveloppe (`20260915160000`) ; `seances_depuis.piscine`
+ `effort_seance` sans `Repos` (`20260915170000`) ; le catalogue regénéré
(`20260915180000`) ; `tools/serveur/verif_cardio.py` 22 ✓, verif_faits 14 ✓,
verif_portes 34 ✓. Deux écarts corrigés à la pose : `round` (pas `floor`) sur la
pièce de temps ; « 5 min à 12 » = 45 (tapis), pas 0.

**Le compte de test** : mes deux séances de mesure (HIIT, piscine) ont été effacées
par la session back-end après lecture des montants ; il est revenu à ses 23 séances
de démo. ⚠️ Dette signalée par elle sur SON script `tools/serveur/verif_cardio.py` :
le `finally` efface les séances, faits et longueurs mais PAS les lignes `coin_ledger`
(`cardio_seance` / `bonus_progres`) → chaque run gonflait le solde du compte de test
(45 orphelines balayées à la main). **Corrigé par elle dans la foulée** (le delete dans
le `finally` + un compteur d'orphelines en fin de run), non commité.

**Le site** : b-flow-fiche-cardio · b-flow-phases-faites · b-flow-graphe-fiche ·
b-flow-overlay-cardio · b-flow-piscine-compteur · b-flow-cardio-cloture (🟡, page
Flow) + les six ⚪ du barème (page Serveur) + notes b-tb-cardio, b-tb-piscine-longueurs
— artefact + verif verts, republié.

**Les fichiers de ce lot** (à committer par chemins, avec le site) : `Woop/Models.swift`,
`Woop/Views/TapisScene.swift`, `TapisLab.swift`, `ExerciseDetailView.swift`,
`CardioFiche.swift` (NOUVEAU), `SessionSlate.swift`, `SetHistoryRow.swift`,
`ChambreHiit.swift` (+ le `L()` d'une autre session dedans), `WoopApp.swift` (hunks :
terminerSeance, groupesDeSeance, `-grandPlayerOuvert`), `Services/SacreServeur.swift`,
`EconomieWoop.swift`, `Annonces.swift`, `SupabaseSync.swift` (une ligne),
`docs/site/content/{serveur,briques}.ts`, `docs/site/index.html`, `tools/cardio/`.

**Le build** : l'arbre partagé ne compilait pas (`FondVideoMetal.swift`, chauffe, en
vol) → construit depuis une copie jetable sans ce fichier (`scratchpad/arbre`,
`dd-cardio`), EXIT=0 à chaque tour.

---

## 0. L'ÉTAT DES LIEUX — ce que le code et le site disent aujourd'hui

### 0.1 Les quatre exercices cardio (`Models.swift:234-258`)

| id | tracking | `speed` veut dire | image | ce que sa fiche fait aujourd'hui |
|---|---|---|---|---|
| `hiit-tapis` | `.intervals` | km/h | `exo-hiit-tapis.png` ✅ | un ÉDITEUR de cycle prévu (steppers) + « Enregistrer l'exercice » |
| `escalier` | `.steady` | **un niveau de machine** (`Models.swift:528`, `SteadyBlock` « Niveau », `ExerciseEditor.swift:215-217`) | `exo-escalier.png` ✅ | durée + niveau + « Enregistrer » |
| `tapis-lent` | `.steady` | km/h (+ inclinaison) | `exo-tapis-lent.png` ✅ | durée + vitesse + inclinaison + « Enregistrer » |
| `piscine` | `.steady` | km/h (sans pente, `hasIncline: false`) | `exo-piscine.png` ✅ | durée + vitesse + « Enregistrer » — **aucune notion de longueur nulle part** (`grep -ri longueur\|piscine supabase/ Woop/Services/` → seul le catalogue) |

Les quatre `cue` / `mistake` existent (`Models.swift:239-258`) mais n'ont pas été
réécrits en « une phrase, français simple » comme les 25 muscu du 05-09 — et
**la fiche cardio ne les affiche pas** (règle du 05-09, rappelée par la session
pastille ce matin : « pas de texte pour les exos cardio »). Sa demande
d'aujourd'hui dit l'inverse → **Q1**.

### 0.2 La page Exercices : RIEN ne diffère

Les cartes cardio sont dessinées par le même `ExerciseCard(exercise:)`
(`ExercisesView.swift:2036`), le tap ouvre la même fiche `ExerciseDetailView(exercise:)`
par `deepLinked` (`:1990`, `:2020`, `:535`). `grep -i 'cardio\|tracking\|intervals\|steady'
ExercisesView.swift` ne rend que des commentaires et le mot « tracking » de la typo.
**La page exos n'a rien à changer** ; tout le sujet est la FICHE.

### 0.3 La fiche : UN booléen commande deux mondes

`private var isStrength: Bool { exercise.tracking == .setsRepsWeight }`
(`ExerciseDetailView.swift:431`). Tout en dépend :

| bloc | muscu (`isStrength`) | cardio (`!isStrength`) | où |
|---|---|---|---|
| la page | `strengthPage` (page NOIRE sans carte, surface de geste) | `cardioPage` dans une **carte noire** clippée `pageShape` (« un contenu qui défile a besoin d'un couteau », `:17-18`) | `:709-715` |
| le fond | `Color.black` | `HeaderEmberCard()` (le feu derrière la carte) | `:749` |
| le header | `collapsingHeaderBack` : photo + grand titre + **`DescriptionExo`** dans la pile du titre | rien | `:773`, `:1603-1616` |
| la description | `DescriptionExo(cue:mistake:enSeance:vu:)` (`:2883`) | **absente** | `:1610-1615` |
| le plancher | **`LaunchPebble`** « Start exercise » — le galet d'aube (`LaunchPebble.swift`), `onDrive/onRelease/onLaunch` → `launch()` (`:2199`) → `running = RunningSeries` → `LiquidLensLab` (`:1024`) | **`primaryAction`** = `DiamondPrimaryButton("Enregistrer l'exercice")` en `safeAreaInset` | `:849-889` / `:893-895`, `:2149-2171` |
| le contenu | (la carte des séries est archivée, `carteSeriesVisible`) | `titleBlock(big:false)` + `hero(210)` + `LastTimeBanner` + `editor` (`IntervalBlock` / `SteadyBlock`, des `WoopCard` à steppers — la grammaire de l'ANCIENNE feuille modale) | `:1464-1483`, `:2131-2144` |
| l'écriture | `finirSerie` (`:~1040`) → `settleSeries` → `StrengthSet(isDone: true, durationSeconds)` + DecideurSerie + pièces | `save()` (`:2674`) → `add(draft)` (`:2698`) : **du PRÉVU** — `.intervals` = `phases × repeatCount` ; `.steady` = UNE phase `.recuperation` de `steadySeconds` à `steadySpeed` (`:2680-2687`) ; `CardioPhase` sans aucune notion de « fait » | `:2723-2731` |

Le « palet » qu'elle nomme = **`LaunchPebble`**, le galet d'aube au plancher
(« Start exercise »), qui rapporte son doigt à la fiche ; c'est lui qui, en
muscu, monte la lentille `LiquidLensLab` (« SET n »). Le cardio n'en a pas.

### 0.4 Le double galet existe — au BANC seulement

`TapisScene.swift` (V5, commitée `39f95f9` le 01-09, plan `tools/tapis/PLAN-TAPIS-HIIT.md`) :

- **le modèle** `SeanceTapis` (`:43-145`) : `etat .court/.repos`, `setIndex`,
  `setsFaits`, `setDebut`, `reposDebut`, `vitesse` (10 par défaut), `vitesseChoisie`,
  `dernierBilan: BilanSet`, `dalleVisible`, `popupVisible`. `stopper()` (`:98-107`)
  ferme le set, pose le bilan, lance la fête ; `relancer()` (`:133-140`) repart.
  **Le commentaire de `stopper()` dit lui-même : « J2 : c'est ici que la
  CardioPhase s'écrira » — elle ne l'est pas.** Le repos a son ancre
  (`reposDebut`) mais n'est écrit nulle part.
- **la scène** `TapisScene(seance:onFinish:tempsFige:)` (`:190-226`) : la scène
  vivante (deux pastilles de braise `braiseGlow`, chrono héros 350 pt, cadran
  vitesse même taille) sous une `TimelineView(.animation 1/60)` (`:206`) ;
  `AnneauHote` (l'arc de crans) ; `FumeeVitesse` (`knobSmoke` à 30 Hz **sous le
  doigt seulement**, `:875`) ; `PriseVitesse` = toute la moitié basse, glissement
  horizontal absolu, **0 → 20 km/h, 40 pt/cran** (`:754-756`) ; `zonesTactiles`
  (tap chrono `:568-585`) ; le pied `SliderObsidienne("Finish")` → `onFinish`
  (`:595-603`) ; la fête = `NotifJauge("SET n END", gain: piecesParSerie)` puis
  `RewardPopup(style: .fire)` (`:236-263`) ; l'en-tête « N MIN · N SETS »
  (`TimelineView .periodic 60 s`, `:534`).
- **les constantes à paramétrer** pour l'escalier / le tapis modéré : `vMin/vMax`
  dans `PriseVitesse` (`:755-756`) ET dans `TapisCotes` (`:907-908`) (deux copies —
  le piège « un uniforme, deux rôles » : grepper `20` et `10` avant de toucher),
  `EtatVitesse.continu/valeur/base = 10` (`:718-726`), l'encre « km/h » (`:554`),
  `BilanSet.recap` « KM/H » (`:82`), `pasCran` 15° pour 20 crans = 300° (`:906`).
- **le site d'appel** : `TapisLab` seul (`grep 'TapisScene(\|SeanceTapis(' Woop/`
  → `TapisLab.swift:55,65,105`, `WoopApp.swift:1034` sous `-tapisLab`). **Le
  double galet n'est branché sur AUCUN exercice.**
- **la cadence** : 60,0 img/s au SIMULATEUR, la fête 40-43 img/s (montage d'une
  pop-up pendant un film — piège connu). **Jamais mesuré sur son téléphone**, pas
  de `SondeVol.tic`, pas de `RythmeEcran.dort` (`grep` → 0).

### 0.5 Le graphe « n séances » de la chambre HIIT — un composant public, sans horloge

`PaliersVue(segments: [SegmentHiit], vide: Bool)` (`ChambreHiit.swift:160-422`),
monté par l'étage 2 en `.frame(height: 210)` avec la légende (`:79-82`, `:87-102`).
`struct` NON privée, un `GeometryReader`, zéro `TimelineView` (« dessin PUR »,
`:158`), une animation d'entrée `apparu` 0,5 s, tap = sélection d'une barre.
Entrée : `SegmentHiit(secondes:vitesse:effort:)` (`WidgetsCards.swift:2961-2968`).

**Mais son échelle est celle du tapis, en dur :**
- hauteur `10 + (clamp(v, 4, 20) − 4) × 6,25` (`:384`) → un niveau d'escalier 1 à 4
  fait 10 pt, plat ;
- « effort » = `vitesse ≥ SemaineStats.seuilEffort` (15,0, `WidgetsCards.swift:3200`),
  chaleur `t = (v − 15) / 4` (`:245`, `:332`, `:362`) → un escalier n'est chaud
  qu'au niveau 15 ;
- le graphite s'éclaircit de 5 à 9,5 km/h (`:265`) ;
- cotes et légende disent « km/h » (`:308`, `:98`).

L'adaptateur `LoggedExercise → [SegmentHiit]` existe déjà, deux fois :
`ChambreDonnees.hiit` (`:451-465`, **exclut `escalier` explicitement** `:454`) et
`SemaineStats.segmentsDuPic` (`WidgetsCards.swift:3202-3221`, idem `:3208`). Le
serveur (`widget_hiit`) rend `segments {secondes, vitesse, genre, cycle}` et est
traduit par `ChambreServeur.swift:305`.

### 0.6 L'overlay « détail de la séance » — le GRAND PLAYER et l'ardoise

- **`GrandPlayer`** (`PiluleVagabonde.swift:1913` — **le fichier de la session
  pastille**), ouvert par `WoopApp.ouvrirGrandPlayer()` (`:1161`) et monté `:1670-1690`
  avec `groupes: groupesDeSeance(a)` (`WoopApp.swift:1186-1205`). Sa partition =
  `SlateListe(groupes:courant:basAir:deplies:)` (`:2105`, `SessionSlate.swift:295`),
  une rangée par exercice = `SlateRang` (numéro, `groupe.exercise.name`,
  `FlammesRow(done:total:)`, `SessionSlate.swift:476-492`), dépliée →
  `SetHistoryRow(rank:reps:kilos:seconds:done:)` (`:509-513`, `SetHistoryRow.swift:15`)
  = « Set n · reps · kg · s · +20 », 66 pt fixes.
- **Ce qu'un exo cardio y montre AUJOURD'HUI** : `groupesDeSeance` construit
  `rows` depuis `orderedSets` seulement (`:1198-1203`) → un HIIT = une rangée à
  **zéro flamme, zéro ligne** ; `SessionSlate.buildGroupes` (`:204-216`) le
  **saute** carrément (`!le.orderedSets.isEmpty`). Le résumé cardio
  `LoggedExercise.summary` (`Models.swift:478-496`, « 12 min · 3 cycles · pic
  19 km/h ») n'est lu que par l'ancienne `ActiveWorkoutView` (plus montée : `grep
  'ActiveWorkoutView(' Woop/` hors du fichier → 0) et `lastTime` de la fiche.
- La pastille (`TicketSeries "\(setsFaits) SETS"`, `:2064`) et le Foyer (`series:
  seriesPayantes`, `Foyer.swift:548-549`) comptent les mêmes `done`.
- `SlateListe` est **PARTAGÉE avec la story 2** (`SessionSlate.swift:292-294`) :
  une ligne cardio y apparaîtra aussi.

### 0.7 L'argent : une séance 100 % cardio paie ZÉRO, et trois gardes le verrouillent

`Workout.seriesPayantes = Σ completedSets` (`Models.swift:360-362`, « LA ligne
à changer si la règle bouge ») → `gain = series × piecesParSerie` (`WoopApp.swift:574-575`),
`guard gain > 0` (`:582`, pas de trophée), `reglerFinDeSeance` `guard series > 0`
(`SacreServeur.swift:360`), et le bypass `ProfilLune.swift:150` qui recompte
`completedSets` en direct. `CardioPhase` n'a pas d'`isDone` (`Models.swift:524-549`).
Le serveur ne recoupe pas : `p_series` est déclaré par le client (dette connue,
b-fn-cloturer-seance).

### 0.8 Le serveur (lu dans les migrations, confirmé par la session back-end ce matin)

- `cardio_phases` (`20260729120000_woop_schema.sql:35-46`) : `kind text` **sans
  check**, `seconds int`, `speed double`, `incline`, `cycle_index`, `position`,
  RLS own. `CardioPhaseRow` pousse les six champs (`SupabaseSync.swift:39-49`),
  `relire()` les remet en `CardioPhase` **sans fait/prévu** (`:226-237`). 🟢
  mesuré 15-09 (b-tb-cardio : 70 phases sur le compte de test).
- `widget_hiit` (`20260905090000_widgets_lecture.sql:308-400`) : un effort =
  `c.speed >= seuil_effort_kmh` (15,0, `reward_rules`) **sur TOUTES les
  `cardio_phases`, sans regarder l'exercice** — le téléphone, lui, exclut
  l'escalier. Un escalier « niveau 15 » compterait comme un sprint au serveur.
  Ses clés (`pic, pic_precedent, efforts, efforts_precedent, temps_pics, recup_moy,
  recup_moy_precedent`) sont lues par `bilan-periode` : **on ne les renomme pas**.
- `effort_seance` (`:86-107`) : `20 kg-équivalent × minutes de cardio`, **toutes
  phases confondues** — un repos écrit en phase pèserait comme un sprint.
- `calculer_faits_seance` / `top_cardio` (`20260915120000:23-24`, `:152-158`) :
  `hiit_secondes = Σ seconds` des phases ≥ seuil, `vitesse_duree = max(speed × seconds)`.
- la table `exercices` (29 lignes) est GÉNÉRÉE depuis `Models.swift` par
  `tools/widgets/catalogue_sql.py` : **si un `tracking` change, une nouvelle
  migration se génère** (pas une réécriture).
- dernière migration de la session back-end : `20260915140000` → la nôtre
  commence à **`20260915150000`**.

### 0.9 Le site de doc — les lignes qui bougeront

`serveur.ts` : b-tb-cardio (note : la table reçoit du FAIT + le repos),
b-fn-widget-hiit (escalier), b-rg-pieces-par-serie (note « s'applique aux
intervalles »), b-fn-seances-depuis (piscine), + **nouvelles** b-tb-piscine-longueurs,
b-rg-piscine-longueurs-par-serie. `briques.ts` / page widgets : b-wd-segments-seance
(⚪ « sans cardio_phases la chambre n'a rien à lire » — **déjà périmée** : b-tb-cardio
est 🟢 depuis ce matin, à signaler à la session back-end), b-wd-hiitpeak-groupage
(🔴 toujours vrai, `WidgetsCards.swift:3162`), b-wd-cardio-sans-volume, b-rg-seuil-effort
(« aucun Swift ne la lit » — faux depuis `SemaineStats.seuilEffort`, en dur à 15 ;
à lire dans `regles_annonces()` un jour). `flow` : nouvelles briques b-flow-cardio-*
au fil des jalons.

---

## 1. LES CINQ CHANTIERS — sa demande traduite

| | chantier | ce qui existe | ce qui manque |
|---|---|---|---|
| **A** | Les 4 fiches cardio prennent la ROBE MUSCU (page noire, photo dans la pile du titre, titre repliable, description, galet d'aube au plancher) | tout, côté muscu | l'aiguillage `isStrength` → trois robes ; les 4 descriptions réécrites |
| **B** | Le DOUBLE GALET branché sur HIIT / Escalier / Tapis modéré, paramétré (plage, unité, départ) ; **les intervalles ET les repos écrits en phases FAITES** ; la paie et la fête comme une série | `TapisScene` V5 au banc | le mode, le site d'appel depuis le galet, `isDone`, `seriesPayantes`, le décideur |
| **C** | Le GRAPHE `PaliersVue` dans la fiche à la place de la description, dès qu'une séance de cet exo a des segments | `PaliersVue` public, sans horloge | l'échelle paramétrable (km/h vs niveau), l'adaptateur `LoggedExercise → segments`, le montage dans la pile du titre |
| **D** | L'OVERLAY : « HIIT » puis les intervalles ; « Piscine » puis les longueurs — la même grammaire que les séries | `SlateLigne` / `SetHistoryRow` / `groupesDeSeance` | la variante de ligne (intervalle · longueurs), les deux constructeurs de groupes |
| **E** | La PISCINE : saisie manuelle (liquid glass, longueurs × X m, « + » blanc dégradé), écrite en local ET au serveur, relue par l'overlay | rien (le sticker `sticker-piscine` existe) | le composant, deux champs sur `LoggedExercise`, la table `piscine_longueurs`, push/pull, la doc |

---

## 2. À TRANCHER AVANT LA PREMIÈRE LIGNE (mes recommandations en premier)

**Q1 — La description sur le cardio.** Ta règle du 05-09 disait « pas de texte
pour les exos cardio » ; ta demande d'aujourd'hui dit « la description comme les
pages exercices ». *Reco : aujourd'hui prime — les quatre `cue`/`mistake`
réécrits une phrase, même ton que les 25 muscu (« Alterne des passages rapides et
des récupérations, sans jamais t'accrocher aux barres. » / « À éviter — partir
trop vite sur le premier cycle. »).* La session pastille a été prévenue.

**Q2 — Le repos est-il un segment ?** Pour « voir les repos et intervalles » dans
le graphe, le repos doit être ÉCRIT (`kind .repos`, durée mesurée du stop à la
relance, `speed 0`). *Reco : oui, écrit à la RELANCE (le repos est fermé à cet
instant ; un « Finish » pendant un repos ne l'écrit pas).* Conséquence serveur :
`effort_seance` compterait les minutes de repos comme du cardio (+20 kg/min) →
*reco : la session back-end exclut `kind = 'Repos'` d'`effort_seance`* (une ligne).
Le repos ne paie pas (§Q5).

**Q3 — L'escalier et le seuil des 15 km/h.** Son `speed` est un NIVEAU 1-15 : le
seuil d'effort (15 km/h) n'a pas de sens pour lui — au téléphone il est déjà
exclu du HIIT (`ChambreDonnees:454`), au serveur il ne l'est PAS. *Reco : (a) sur
l'escalier, tout segment couru (niveau > 0) est un « effort », chaleur graduée par
`niveau / 15`, les repos en graphite ; (b) l'escalier ne compte ni dans le widget
HIIT ni dans `top_cardio` — la session back-end pose le filtre `exercise_id <>
'escalier'` dans `widget_hiit` et `calculer_faits_seance` pour que serveur et
téléphone disent pareil.* Question ouverte : veux-tu au contraire un widget /
un record propre à l'escalier un jour ? (Ça se range, ça ne se code pas maintenant.)

**Q4 — Le tapis modéré et le HIIT partagent la définition.** Un tapis modéré
poussé à 16 km/h devient un « effort » dans le widget HIIT. *Reco : on laisse — un
effort EST un passage au-dessus de 15, quel que soit l'exercice ; c'est la
définition tranchée le 05-09.*

**Q5 — L'argent.** Un intervalle fini (tap stop) = une série = `pieces_par_serie`
(20) — c'est ce que le plan tapis §5 a tranché le 31-08 (« SET n COMPLETE · +20 »)
et ce que `NotifJauge` affiche déjà. Le repos ne paie rien. **La piscine** : un tap
« + » ne peut pas valoir 20 pièces (farmable au doigt). *Reco : une règle en base
`piscine_longueurs_par_serie = 10` (10 longueurs = une série = 20 pièces), lue par
l'app, jamais en dur.* À toi de dire 10, 20, ou « la piscine ne paie pas ».

**Q6 — Le compteur de longueurs.** *Reco : une pastille à la matière du galet
d'aube (le seul verre qui vit sur la nuit — il porte son jour, `LaunchPebble`) :
le NOMBRE en grand, « longueurs · 25 m » dessous, le « + » blanc dégradé
(`TapisScene.encreApple`) à droite ; au-dessus, 25 m / 50 m en deux chips ; un
« − » discret (une erreur de doigt ne doit pas être définitive) ; haptique par
tap.* Deux questions : veux-tu le « − » ? Le X mètres se choisit une fois et se
mémorise (dernière valeur), ou à chaque séance ?

**Q7 — Quand le graphe remplace la description.** *Reco : dès que cet exercice a
au moins un segment FAIT — dans ce passage (le graphe grandit intervalle par
intervalle sous tes yeux quand tu reviens sur la fiche) ou, hors séance, la
DERNIÈRE séance où tu l'as fait, avec sa date en titre (« Mardi 15.09 · 12 min ·
6 segments », la grammaire de l'étage 2 de la chambre). La description ne
revient plus tant qu'une séance existe.* Ou préfères-tu la description toujours,
et le graphe SEULEMENT après la séance du jour ?

**Q8 — « Finish » finit QUOI ?** Le plan tapis §10.1 avait tranché « le slider
clôt la SÉANCE ». Depuis, la fin de séance vit dans la dalle / le grand player
(un seul ordre dans toute l'app, 14-09). *Reco : « Finish » finit l'EXERCICE — la
scène se démonte, la fiche revient avec son graphe ; la séance se termine par le
stop de la dalle, comme partout.*

**Q9 — La fête du set contre le décideur.** `TapisScene` fait une pop-up `.fire`
à CHAQUE set ; le décideur des pop-ups (`DecideurSerie`, règles serveur : rangs
3 / 5 / 10, budget 4 par séance) fait loi pour la muscu depuis ce matin. *Reco :
le décideur fait loi aussi ici (un intervalle = un rang) ; la dalle NotifJauge
« SET n END · +20 » reste à chaque set (une dalle n'est pas une pop-up, règle
`notif_consomme_budget = false`) ; la robe `.fire` reste LA robe des pop-ups du
cardio.*

**Q10 — Le premier set part-il tout seul ?** Aujourd'hui `SeanceTapis` démarre
le chrono à l'arrivée des pastilles (0,85 s). *Reco : oui pour le HIIT et le
tapis (tu es déjà sur la machine quand tu slides le galet) ; idem escalier.*

---

## 3. L'ARCHITECTURE — chantier par chantier

### A. La fiche : de `isStrength` à trois robes

```swift
enum RobeFiche { case muscu, galetCardio(ModeCardio), piscine }
// dérivée de l'exercice, UNE fois, en `let` de la fiche — jamais relue par image
```

- Les sept `if isStrength` (`:709`, `:749`, `:773`, `:785`, `:799`, `:849`, `:893`)
  deviennent des `private var` nommées (`pageDeLaRobe`, `plancherDeLaRobe`…) —
  **le mur du type-checker** (le fichier fait 2 996 lignes ; chaque branche sort en
  `private var`/`struct`, loi §1 du skill architecture).
- `cardioPage`, `IntervalBlock`, `SteadyBlock`, `primaryAction` « Enregistrer » :
  **archivés** — le site d'appel meurt, les composants restent (`ExerciseEditor.swift`
  intouché). Jamais de suppression : la loi du 05-09.
- Le header, la photo, le titre, `DescriptionExo`, le fond noir, `LaunchPebble` :
  **les mêmes vues, les mêmes cotes** pour le cardio — c'est ça, « le même design ».
  La photo cardio est un PNG à fond noir comme les autres (`hero`, `heroAspect`).
- `LaunchPebble.onLaunch` / `driveEnded` : en muscu → `launch()` → `RunningSeries`
  → `LiquidLensLab` (« SET n ») ; en `galetCardio` → `seanceTapis = SeanceTapis(...)`
  et la scène prend **le slot page entier** (`pageContenu` remplacé, pas recouvert :
  le rideau — une fiche montée sous la scène continuerait de rendre sa photo et
  ses horloges). Le galet s'endort (`asleep`) tant que la scène vit.
- ⚠️ Le hero est le **point de couture de la pastille** (`PiluleEtat.ancreGlobale`,
  session pastille) : on ne bouge pas ses cotes.

### B. Le double galet, paramétré — `TapisScene(mode:)`

```swift
struct ModeCardio {
    let plage: ClosedRange<Double>   // hiit 0…20 · escalier 1…15 · modéré 0…20
    let depart: Double               // 10 · 6 · 7
    let unite: String                // "km/h" · "" · "km/h"
    let libelle: String              // "km/h" · "NIVEAU" · "km/h"
    let pasGlisse: Double            // 40 · 53 (15 crans sur la même course) · 40
    let kindEffort: PhaseKind        // .sprint · .acceleration · .acceleration
    func estEffort(_ v: Double) -> Bool   // hiit/modéré : v ≥ seuilEffort · escalier : v > 0
}
```

- **Les sites à paramétrer** (§0.4) : `PriseVitesse.vMin/vMax/pasGlisse`,
  `TapisCotes.vMin/vMax`, `EtatVitesse` (départ), `encreVitesse` (unité),
  `BilanSet.recap`, `AnneauCrans` (la course : 15 crans × 15° = 225° — ou pas de
  20° pour garder 300° ; à voir au banc, jamais à l'œil). Avant de toucher : `grep
  -n '20\b\|\b10\b' TapisScene.swift` — un nombre porte souvent deux rôles.
- **L'écriture, dans la fiche, jamais dans la scène** (la scène ne connaît pas
  SwiftData — elle rapporte) : `SeanceTapis` gagne deux callbacks `onSetFini(BilanSet)`
  et `onReposFini(secondes:vitesse:)`. La fiche écrit dans `bloc` (`:37`, le
  `LoggedExercise` de CE passage — deux passages = deux blocs) :
  - au stop : `CardioPhase(kind: mode.kindEffort(vitesse), seconds: bilan.secondes,
    speed: bilan.vitesse, cycleIndex: bilan.rang, order: 0, isDone: true)` — HIIT et
    tapis : `.sprint` si ≥ seuil, `.acceleration` sinon ; escalier : toujours
    `.acceleration` (« pas en mode sprint ») ;
  - à la relance (verdict Q2) : `CardioPhase(kind: vitesse > 0 ? .recuperation :
    .repos, seconds: reposÉcoulé, speed: vitesseRécup, cycleIndex: rang, order: 1,
    isDone: true)` — **la récup garde SA vitesse** (son exemple : 1 min à 9 km/h) ;
  - `context.save()` tout de suite (la pastille annonce ce qui est écrit).
- **Deux vitesses en mémoire dans `SeanceTapis`** (Q15 de l'économie) :
  `vitesseEffort` (10 au départ) et `vitesseRecup` (`PhaseKind.recuperation.defaultSpeed`
  = 7 au départ, puis la dernière réglée). Au stop le cadran BASCULE sur la récup
  (l'encre dit « RÉCUP ») ; au tap suivant il revient à l'effort. Sans ça, une récup
  non réglée hériterait des 17 km/h de l'effort et le serveur la compterait comme un
  effort. Sur l'escalier : niveau d'effort / niveau de récup (0 = arrêt).
- **`isDone` sur `CardioPhase`** (`Models.swift:524`) : défaut `false`, LOCAL (pas
  de colonne serveur — la muscu ne pousse pas le sien non plus, dette cohérente et
  DITE au site) ; `relire()` pose `true` sur une séance finie (la loi du pull §3.4).
- **La paie — verdict Q5 : PAS par intervalle.** `seriesPayantes` (`Models.swift:360`)
  reste la muscu seule ; `Workout.cardioFait` (au moins une phase faite ou une
  longueur) ouvre la clôture : les gardes `gain > 0` (`WoopApp:582`), `series > 0`
  (`SacreServeur:360`) et le trophée deviennent « séries > 0 OU cardio fait ». Le
  montant cardio est CALCULÉ PAR LE SERVEUR à la clôture (`pieces_cardio_seance`,
  `PLAN-ECONOMIE-CARDIO.md` §4) et annoncé quand il répond. La dalle du set dit
  « SET n END · 1:30 · 17 km/h », **sans « +20 »** (`NotifJauge.gain` à 0 ou une
  variante sans pièce — à voir sur capture).
- **Le décideur** (Q9) : au stop, `DecideurSerie.pour(serie: rang, …)` comme
  `finirSerie` (`:~1040-1050`) pour la CADENCE des pop-ups (rangs 3 / 5 / 10, budget
  serveur), la robe `.fire` avec ses encouragements et le compte de sets — jamais un
  montant. La `NotifJauge` reste dans le modèle (le banc `-tapisAuto` doit voir ce
  que le doigt déclenche).
- **La fin** : `onFinish` → la scène se démonte (`seanceTapis = nil`), `bloc` garde
  ses phases, la fiche revient sur le graphe (C). `isIdleTimerDisabled` posé à
  l'arrivée, rendu à la sortie.
- **La pastille** : `TicketSeries "N SETS"` = `groupes.done` → suit D.

### C. Le graphe dans la fiche — `PaliersVue`, UN composant, DEUX échelles

```swift
struct EchellePaliers {              // la chambre garde son défaut : ZÉRO changement chez elle
    var min: Double = 4, max: Double = 20, seuil: Double = SemaineStats.seuilEffort
    var unite: String = "km/h"
    var chaleur: (Double) -> Double   // défaut (v − seuil) / 4 ; escalier v / 15
    var fmt: (Double) -> String       // ChambreFmt.kmh · escalier "\(Int(v))"
}
PaliersVue(segments:, vide:, echelle: .tapis)   // le défaut = l'échelle d'aujourd'hui
```

- Les six constantes en dur de §0.5 lisent l'échelle. **Non-régression mesurée** :
  la chambre HIIT capturée avant / après, diff de pixels à zéro (le banc
  `-chambreLongue hiit`).
- **L'adaptateur**, une fonction, à côté des deux existantes (qui restent pour la
  chambre) : `segments(de: LoggedExercise, mode:) -> [SegmentHiit]` =
  `orderedPhases.filter(\.isDone)` → `SegmentHiit(secondes, vitesse, effort:
  mode.estEffort(speed))`. Un repos (vitesse 0) = 10 pt de graphite (le plancher) :
  lisible, jamais chaud.
- **Le montage** : dans la pile du titre (`collapsingHeaderBack`, `:1603-1616`), à la
  place de `DescriptionExo` quand `segmentsDeCetExo` n'est pas vide (Q7) :
  `PaliersVue(...).frame(height: 210)` + la légende + une ligne « Mardi 15.09 ·
  6:40 · 6 segments ». Il suit le titre (jamais une cote fixe : la leçon du 05-09
  sur les titres à deux lignes) et s'éteint au scroll comme lui. `.allowsHitTesting`
  : la pile du titre est SOURDE (`:1628`) → le tap-sélection d'une barre ne marchera
  pas là ; c'est voulu au J3 (un graphe à lire, pas à toucher) — à trancher si tu
  le veux tappable.
- **Pas une horloge de plus** : `PaliersVue` n'en a aucune. Le remplacement
  description ↔ graphe est un `if` (deux vues jamais montées ensemble).
- Le mensonge 🔴 `hiitPeak()` (`WidgetsCards.swift:3162`, le groupage) devient
  VISIBLE le jour où de vrais intervalles existent : la card HIIT de la home dira
  « 2:00 continuous » sous quatre efforts. Hors périmètre, mais à corriger dans la
  foulée (b-wd-hiitpeak-groupage, 1 h).

### D. L'overlay — une variante de ligne, la même grammaire

```swift
struct SlateLigne {                 // SessionSlate.swift:264
    enum Genre { case serie(reps: Int, kilos: Double), intervalle(vitesse: Double, unite: String),
                 longueurs(n: Int, metres: Int) }
    var genre: Genre; var seconds: Int; var done: Bool
}
```

- `SetHistoryRow` reçoit le genre et garde son gabarit (66 pt, `fixedSize` des
  métriques) : « Set 1 · 12 reps · 40 kg · 45 s · +20 » (muscu, inchangé),
  « Set 1 · 1:30 · 17 km/h », « Set 3 · 0:52 · niveau 11 », « 20 longueurs · 25 m ·
  500 m » — **sans gain à droite sur le cardio** (verdict Q5 : la séance est payée
  au serveur, pas la ligne ; la place reste vide, comme une série à venir).
  **L'invariant PageCard « taille fixe » est intact** (la ligne ne change pas de
  hauteur).
- **Sans les flammes** (son verdict : « même UI, sans les flammes ») : la rangée
  d'un exo cardio n'a pas de `FlammesRow` — les flammes comptent des séries de
  muscu. À sa place, la « description » qu'elle demande : le résumé court de la
  ligne de tête (« 6 intervalles · 12 min », « 20 longueurs · 500 m »), dans
  l'encre sourde de la rangée. Les repos n'ont pas de ligne (ils sont dans le
  GRAPHE).
- **Les deux constructeurs** : `WoopApp.groupesDeSeance` (`:1186-1205`) et
  `SessionSlate.buildGroupes` (`:204-216`) : `rows` = séries faites OU phases
  faites d'effort OU la ligne de longueurs ; la garde `!le.orderedSets.isEmpty`
  devient « a quelque chose de fait ».
- Le titre du groupe reste `groupe.exercise.name` (« HIIT sur tapis de course »,
  « Piscine ») — la constance, c'est le même composant, pas un mot de moins.
- **La story 2 partage `SlateListe`** : elle montrera les lignes cardio d'elle-même.
  `GrandPlayer` vit dans `PiluleVagabonde.swift` (session pastille) : les hunks
  s'y posent par marqueurs, elle est prévenue.

### E. La piscine

- **La fiche** : robe muscu (photo, titre, description, page noire) **sans galet**.
  Au plancher, à la place exacte du galet : le compteur (Q6). Il vit dans un
  `@Observable` à part (`CompteurLongueurs`) — le « + » ne réveille que la
  pastille, jamais la fiche (loi de la page ré-évaluée).
- **Le modèle** : `LoggedExercise` gagne `longueurs: Int = 0` et
  `metresParLongueur: Int = 25` (défauts SwiftData, migration légère). **Pas une
  `CardioPhase` détournée** : une phase piscine entrerait telle quelle dans
  `widget_hiit`, `effort_seance`, `top_cardio` et le graphe.
- Chaque « + » : `longueurs += 1`, `save()`, haptique ; la paie par tranche (Q5) :
  `seriesPayantes` += `longueurs / longueursParSerie` (la règle lue dans
  `reward_rules`, jamais en dur — `EconomieWoop` la porte comme `piecesParSerie`).
- **Le serveur** (proposé à la session back-end, à sa main) : table
  `piscine_longueurs` (`logged_exercise_id uuid pk → logged_exercises cascade`,
  `user_id`, `longueurs int`, `metres_par_longueur int`, `updated_at`), RLS own CRUD
  comme les quatre tables de séance, index sur `user_id` ; `seances_depuis` rend
  `piscine {longueurs, metres}` par exercice ; `regle piscine_longueurs_par_serie`
  dans `reward_rules`. `SupabaseSync` : un `PiscineRow` de plus dans `push()`
  (upsert, idempotent par pk) et `relire()` le remet. `effort_seance` :
  `longueurs × metres` ne pèse rien (ou une règle, à trancher plus tard — b-wd-cardio-sans-volume).
- **L'overlay** : « Piscine » → « 20 longueurs · 25 m · 500 m · +40 » (D).
- **La doc, dans le même commit** : b-tb-piscine-longueurs ⚪ (plan) → 🔵 (posée,
  sondée : GET avec témoin 400) → 🟢 (push + pull lus au banc) ; b-rg-piscine-longueurs-par-serie.

---

## 4. LE SERVEUR — ce qui bouge, ce qui ne bouge pas (pour la session back-end)

| | quoi | qui | quand |
|---|---|---|---|
| ne bouge PAS | `cardio_phases` (schéma), `CardioPhaseRow`, les clés de `widget_hiit`, la signature de `cloturer_seance` (`p_series` déclaré par le client — dette connue, pas ce chantier), pas d'`isDone` serveur | — | — |
| bouge | **le barème cardio** : ~20 clés `reward_rules`, la raison `cardio_seance`, `pieces_cardio_seance()`, `cloturer_seance` qui la crédite — `PLAN-ECONOMIE-CARDIO.md` §4, migration `20260915160000` | session back-end (moi pour le Swift) | à son go sur le barème |
| bouge | `piscine_longueurs` + RLS + `seances_depuis` + `pieces_par_longueur` | session back-end (moi pour le Swift) | J6, après Q13 |
| **FAIT** | `widget_hiit` et `calculer_faits_seance` : `exercise_id <> 'escalier'` (Q3) — `20260915150000_widget_hiit_sans_escalier.sql`, déployé, verif_faits 14 ✓ + verif_widgets 31 ✓ | session back-end, 15-09 matin | — |
| bouge | `effort_seance` : `kind <> 'Repos'` (Q2 — une récup à 9 km/h reste du cardio ; seul un arrêt à 0 est exclu) | session back-end | J2 |
| bouge | migration catalogue si un `tracking` change (`tools/widgets/catalogue_sql.py`) — **reco : ne pas changer `tracking`**, la robe se décide par `id`/`category` ; la table `exercices` reste vraie | — | — |
| à vérifier après J2 | `python3 tools/serveur/verif_faits.py` (14 preuves : le sens de kind/speed/seconds ne change pas, mais des repos à speed 0 apparaissent) | session back-end | J2 |

---

## 5. LA PERF ET LA CHAUFFE — avant tout verdict (skill `woop-performance`)

- **`TapisScene` est le moteur le plus lourd de ce chantier** : deux `braiseGlow`
  (350 pt de côté chacun) sous une `TimelineView` à 60 Hz plein écran, plus
  `knobSmoke` à 30 Hz sous le doigt. 60,0 img/s au simulateur, **jamais un chiffre
  sur son téléphone**, et la home gèle déjà par vagues sur téléphone chaud
  (c313012). → à J2 : `SondeVol.tic(<famille tapis>)` sur les deux horloges,
  `RythmeEcran.dort` branché, barreau **`-sansBraiseTapis`** (les pastilles en
  aplat), et une campagne ABBA (thermique 0 au départ, 3 × 60 s) A = scène vivante /
  B = `-sansBraiseTapis`, la paire (cadence, processeur) publiée. **Aucun verdict de
  rendu avant ce chiffre.**
- **La scène REMPLACE la fiche** (pas d'overlay) : sinon la photo, `HeaderEmberCard`
  et le galet rendent derrière — le rideau.
- La fête à 40-43 img/s (la pop-up qui naît pendant un film) : pré-monter
  `RewardPopup` invisible est interdit (rideau) → **alléger sa scène** ou la faire
  naître après la dalle (+0,4 s, déjà) ; mesurée au téléphone, pas au sim.
- `PaliersVue` : zéro horloge, N rectangles + N laques — rien au repos.
- Le compteur piscine : `liquidLens` = un `layerEffect` ; il dort (`asleep`) hors
  toucher, comme le galet. Le « + » n'écrit que l'observable du compteur.
- Le graphe à la place de la description : un `if`, jamais deux vues montées.

---

## 6. LES JALONS — chacun avec sa preuve, dans cet ordre

| | jalon | preuve (mesurée, pas jugée) | site de doc |
|---|---|---|---|
| **J0** | Les 10 verdicts (§2) | ses réponses, en tête de ce fichier | — |
| **J1** | La robe (A) sur les 4 fiches : photo, titre, description, galet — le galet ne lance rien encore sur le cardio (ou le double galet nu si J2 suit dans la foulée) | 4 captures (sim kat-exos, `-exoLab -openExercise <id>`) à côté d'une fiche muscu ; **la fiche muscu capturée avant/après, identique** ; build PROPRE vert (`$?` sans pipe) | b-flow-fiche-cardio 🟡 |
| **J2** | Le double galet branché (B) — HIIT d'abord, puis escalier et tapis modéré par le mode ; `isDone`, `seriesPayantes`, décideur, `-sansBraiseTapis`, sonde | banc `-exoLab -openExercise hiit-tapis -tapisAuto` : journal des `CardioPhase` écrites (kind · seconds · speed · cycle · isDone), `seriesPayantes` = N, la pastille « N SETS », la dalle « SET n END » ; film de la séquence ; **ABBA sur son téléphone** | b-tb-cardio note (du FAIT + repos) · b-rg-pieces-par-serie note · b-fn-widget-hiit (escalier) |
| **J3** | Le graphe (C) | capture fiche après séance ; **capture chambre HIIT avant/après, diff de pixels = 0** | b-wd-segments-seance (périmée → corrigée) |
| **J4** | L'overlay (D) | capture GrandPlayer avec un HIIT déplié (`-openTab home` + séance de banc) ; `-slateOpen` ; story 2 capturée, non cassée | b-flow-overlay-cardio |
| **J5** | La piscine en local (E) | capture, cinq « + », relance de l'app → 5 longueurs persistées (SwiftData) ; `seriesPayantes` par tranche | b-flow-piscine 🟡 |
| **J6** | La piscine au serveur | migration posée (`migration list` avant/après), `GET piscine_longueurs?select=longueurs&limit=1` → 200 et un témoin → 400, push depuis le banc `-sessionBanc` → `count=exact`, `-pullNow` après désinstallation → la ligne revient, rejeu idempotent | b-tb-piscine-longueurs 🔵 → 🟢 · b-fn-seances-depuis · b-rg-piscine-longueurs-par-serie |
| **J7** | Son téléphone : la séance HIIT au doigt, thermique lu à 0 | sonde `-sondeVol`, ses marques, la paire (cadence, cpu) ; le verdict au doigt (galet, glissement de vitesse, stop, Finish) | — |

Chaque jalon qui touche un site d'appel ou le serveur emporte **la source ET le
livrable du site** dans son commit (`npm run artefact` PUIS `npm run verif`,
republier au même lien). Aucun commit sans son ordre.

---

## 7. LES PIÈGES DÉJÀ PAYÉS QUI S'APPLIQUENT

- **Les pixels et le hit-test sont deux choses** (`.offset` sous un geste — la
  molette V3 est morte de ça, `TapisScene.swift:688-710`) : la prise de vitesse
  reste `frame → contentShape → gesture → position`, jamais `.offset`.
- **Un `Button` sous un drag d'ancêtre meurt à 2 pt** : les taps de la scène
  restent en `highPriorityGesture(TapGesture())` (`:564-567`).
- **Le rideau** : rien de monté-caché — la scène remplace la page ; le galet dort.
- **Le mur du type-checker** : chaque robe en `private var` nommée, les tables de
  constantes en `static let` ; le mur ne se voit qu'en build PROPRE.
- **Un uniforme / une constante porte deux rôles** : `20` et `10` dans `TapisScene`
  (plage, départ, course angulaire) — grep avant.
- **Le ForEach et l'identité** : `SlateLigne` change de forme → `SlateGroupe.cle`
  doit inclure le genre (sinon une ligne série → intervalle ne se rejoue pas).
- **`@State` dans une vue `.equatable()` est invisible** : `SlateListe` compare
  `deplies` chez l'hôte — on n'y touche pas.
- **`hiitPeak()` groupe des phases identiques** (🔴 b-wd-hiitpeak-groupage) : de
  vrais intervalles rendront le mensonge visible sur la home.
- **Le `-demoData` sème une séance OUVERTE** : bancs de J2 avec base propre
  (uninstall) ou `-cardioBanc` dédié.
- **Deux builds sur le même DerivedData = base verrouillée** ; sim dédié
  (kat-exos `EC0CCAC9…` ou kat-tapis `E500AB23…`, `dd-exos` / `dd-tapis`).
- **Le simulateur n'a pas de doigt** : `-tapisAuto` appelle `stopper()` — il prouve
  l'écriture et la fête, PAS le toucher (la leçon V4). Le toucher se prouve sur son
  téléphone.

---

## 8. LES BANCS

Existants : `-exoLab` (+ `-openExercise <id>`), `-tapisLab` (`-tapisFige`, `-tapisT`,
`-tapisSet`, `-tapisAuto`, `-tapisNu`, `-tapisChoisi`, `-tapisSansChiffres`),
`-chambreLongue hiit`, `-slateOpen`, `-sessionBanc`, `-pullNow`, `-sondeVol`.

À poser : `-cardioBanc <id>` (ouvre la fiche, lance le double galet, `-tapisAuto`
enchaîne 3 sets + 2 repos, écrit, puis Finish → le graphe), `-sansBraiseTapis`
(barreau), `-piscineLab` (5 « + » automatiques), `-cardioMode escalier|modere`.

---

## 9. LA COORDINATION (ce que j'ai dit aux autres sessions, et ce qu'elles ont répondu)

- **woochoper-ios-05 (back-end)** : rien en vol sur `cardio_phases` / `widget_hiit`.
  À préserver : `calculer_faits_seance` (lit `speed >= seuil`), les clés de
  `widget_hiit` lues par `bilan-periode`. Elle conseille une table à part pour la
  piscine (reco reprise), dernière migration `20260915140000`. Je lui envoie ce plan
  avec le schéma proposé (§3.E, §4) et les deux filtres (escalier, repos).
- **woochoper-ios-dd (pastille / île)** : rien en vol sur le cardio ; me rappelle la
  règle « pas de texte cardio » du 05-09 (→ Q1) et le point de couture du hero. Je la
  préviens que J4 pose des hunks dans `PiluleVagabonde.swift` (`GrandPlayer.groupes`)
  et `SessionSlate.swift`.
- **La session compte (pull)** : `SupabaseSync.swift` est son fichier — `PiscineRow`
  et `relire()` à J6, par hunks, après son accord.
- **La session chauffe** : je ne touche ni `HomeNuit` ni ses horloges ; la scène
  tapis arrive avec son barreau et ses tics.
