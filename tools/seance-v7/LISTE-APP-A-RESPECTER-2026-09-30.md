# La séance v7 : ce que son app fait déjà, et qu'on garde tel quel (30-09-2026)

Demande de Kathryn (30-09, après la première version codée) : « t'as zappé
tout le contexte de l'app », « on avait déjà un composant », « mes pop-up
aussi elles manquent, des annonces ». Puis : « ne code pas, analyse ou
propose », et « go je te suis ».

Ce document est **la liste contre laquelle on code**. Chaque ligne se
vérifie au simulateur avant de dire que c'est fait.

## La règle

**La page v7 remplace son lecteur (`GrandPlayer`), et rien d'autre.** Tout
le reste (départ, cadran, saisie, repos, récompenses, pop-ups, fin de
séance) passe par les chemins et les composants qui existent déjà.

Ce qui est neuf dans la v7 ne vit que sur la page : les grosses cartes en
verre, supprimer ou ajouter une série au doigt, les actions sur le côté de la
carte, la séance vide et la feuille Ajouter de la maquette v7.

## Le parcours, dans l'ordre

Légende : **garder** = inchangé ; **brancher** = la page v7 doit y mener ;
**neuf** = n'existe que sur la page v7 ; **à décider** = choix de Kathryn.

### 1. Avant la séance

| Ce qu'elle voit | Composant | Où | v7 |
|---|---|---|---|
| « tire pour commencer » | `InviteTirage` | `HomeNuit.swift:5470` | garder |
| la Route et « Démarrer » | `DuolinguoPage`, `PanneauDepartChemin` | `DuolinguoPage.swift:1917`, `:2474` | garder |
| le plafond du jour | alerte native | `DuolinguoPage.swift:2348` | garder |

### 2. Le départ de la séance

| Ce qu'elle voit | Composant | Où | v7 |
|---|---|---|---|
| le compte 1-2-3-GO filmé | `FilmDepartSeance` (`count.mp4`, haptiques) | `FilmDepartSeance.swift:7` | garder |
| **les comètes orange** (paillettes) | `CoupeEtat.jouer` / `Ouverture` | `OuvertureParticules.swift:127` | garder ; **à décider** : plus de moments (point 4) |
| la pastille dans l'île | `PiluleVagabonde` | `NosfyApp.swift:2017-2026` | garder |
| la Live Activity | `WorkoutActivityController.ensure` | `NosfyApp.swift:938` | garder |
| la séance ouverte au serveur | `OuvertureSeanceServeur.ouvrir` | `NosfyApp.swift:3040` | garder |

### 3. La page de séance (l'ancien lecteur)

| Ce qu'elle voit | Composant | Où | v7 |
|---|---|---|---|
| le carré du jour qui flotte + halo | `MiniCardJour(flotte:)` + `HaloCarte` | `HomeNuit.swift:1515`, `PiluleVagabonde.swift:3225` | garder (le halo manque aujourd'hui dans la v7) |
| le ticket « N SETS » | `TicketSeries` | `PiluleVagabonde.swift:248` | garder |
| le titre qui bouge « En cours » | `InviteAnimee` | `PiluleVagabonde.swift:184` | **garder** (la v7 l'a remplacé par un texte figé : à reprendre) |
| la chaleur de la tête | `ChaleurTete` | `PiluleVagabonde.swift:3257` | garder |
| les braises | `BraisesVague` | `PiluleVagabonde.swift:92` | garder |
| « Ajouter un exercice » à particules | `BoutonAjouter` | `BoutonAjouter.swift:27` | garder |
| **les carrés de zones qui respirent, inégaux, pour inviter** | `CarreZoneMini` | `PiluleVagabonde.swift:2918` | **garder** (la v7 les a recopiés sans leur respiration : reprendre les siens) |
| les rangées « Set 1 · 12 reps · 20 kg · +20 » | `SetHistoryRow` + `FlammesRow` | `SetHistoryRow.swift:15` | à décider : ses rangées, ou celles des grosses cartes v7 |
| « Terminer » en médaillon | `MedaillonStop` | `WorkoutPill.swift:21` | garder (bas ou haut : à décider) |
| fermer au glisser vers le bas | `fermer()` | `PiluleVagabonde.swift:2889` | garder |
| les grosses cartes en verre, glisser pour supprimer, actions sur le côté | — | `SeanceV7.swift` | **neuf** |
| la séance vide et la feuille Ajouter de la maquette | — | `SeanceV7.swift` | **neuf** |

### 4. Choisir un exercice

| Ce qu'elle voit | Composant | Où | v7 |
|---|---|---|---|
| la coupe noire, puis sa fiche | `lancer(exo)` → `CoupeEtat.couper` → `ouvrirFicheDeSeance` | `PiluleVagabonde.swift:2536`, `NosfyApp.swift:1193` | **brancher** : ⚠️ la v7 ne referme pas la page (`poserFerme()` manquant) |
| sa fiche, son graphe, son coach | `ExerciseDetailView`, `CourbeChargeFiche`, `demanderLeCoach` | `ExerciseDetailView.swift:24`, `ChargeFiche.swift:67` | garder ; la tête d'une carte v7 y mène |
| **son départ : galet blanc OU slider** (Réglages) | `LaunchPebble` / `SliderObsidienne` | `ExerciseDetailView.swift:1090-1122` | **garder** ; à décider : aussi en bas de la page v7 (point 1) |

### 5. La série

| Ce qu'elle voit | Composant | Où | v7 |
|---|---|---|---|
| la plongée du galet, le voile blanc, les grains | `driveMoved` → `launch()` | `ExerciseDetailView.swift:3089`, `:2507` | garder |
| **son cadran** : galet blanc, halos, 3-2-1-GO, chrono, sons | `LiquidLensLab` + `eclipseGlow` | `LiquidLensLab.swift:27`, `LiquidLens.metal:699` | garder ; à décider : halos plus orangé rouge (point 5) |
| « Finish set » | slider du cadran | `LiquidLensLab.swift:1410` | garder |
| **sa saisie** : règles, puces de repos, « glisse pour lancer le repos » | `SetEntrySheet` | `SetEntrySheet.swift:12` | garder |
| le repos dans le même cadran, « Skip rest » | `LiquidLensLab` | `:1422` | garder ; **ajouter le trait blanc** (validé) |
| l'envol | `startEnvol` + `EnvolHaptic` | `:977`, `:1532` | garder |

### 6. Après la série — **ses pop-ups**

| Ce qu'elle voit | Composant | Où | v7 |
|---|---|---|---|
| les pièces qui volent vers la pastille | `SeriesCoinFlight` | `RestartSheet.swift:333` | garder |
| **sa robe de toaster**, en tour de rôle | `ToasterSerie` + `TourDesRobes` | `NotifAile.swift:349`, `:166` | garder |
| **les pop-ups de récompense** (rang 3, rang 10, puis au hasard ; 4 max) | `RewardPopup` via `DecideurSerie` | `RewardCard.swift:82`, `RestartSheet.swift:683` | garder |
| **« Encore une série ? · Recommencer · Choisir un autre exercice »** | `RestartPopup` | `RestartSheet.swift:101` | garder ; « Choisir un autre exercice » ramène à la page v7 |
| la flamme dans la rangée | `FlammesRow` | `FlammeJauge.swift:1212` | à décider : une plus belle arrivée (point 3) |

### 7. Cardio et HIIT

| Ce qu'elle voit | Composant | Où | v7 |
|---|---|---|---|
| le double cadran du tapis | `TapisScene` | `TapisScene.swift:676` | garder |
| la vitesse, « SET n END », « KEEP BURNING » | `dalleVitesse`, `DalleSetFini`, `RewardPopup .fire` | `TapisScene.swift:1012`, `:1289`, `:768` | garder |
| « Finish », le reçu | `finirTapis` | `ExerciseDetailView.swift:2668` | garder |

### 8. Partir et revenir

| Ce qu'elle voit | Composant | Où | v7 |
|---|---|---|---|
| la pastille dans l'île, qui sort sous le doigt, sons d'île | `PiluleVagabonde`, `CarillonIle` | `PiluleVagabonde.swift:522`, `:469` | garder |
| la pastille blanche sur la home | `IleRespirante` | `PiluleVagabonde.swift:1308` | garder |
| **le point blanc** (pulsar, paillettes) | `PointSeance` | `PointRec.swift:82` | garder |
| la home en séance (le Foyer) | `FoyerPage` | `Foyer.swift:773` | garder |
| le chevron de la fiche (avec les comètes) | `quitterLaFiche(feu: true)` | `ExerciseDetailView.swift:3430` | garder ; il doit ramener à la page v7 |

### 9. La fin

| Ce qu'elle voit | Composant | Où | v7 |
|---|---|---|---|
| la card STOP et son slider | `StopCardHote` | `StopCard.swift:24` | garder |
| « Rien n'a été enregistré » | alerte native | `NosfyApp.swift:714` | garder |
| **la pile d'annonces** qui sort de l'île | `FileAnnonces` → `AnnonceDepuisIle` | `Annonces.swift:81`, `:331` | garder |
| la story | `StoryPortal` / `StoryFlow` | `StoryFlow.swift:630` | garder |
| la Route qui fête le galet du jour | `DuolinguoPage` célébration | `DuolinguoPage.swift:2232` | garder |
| le booster qui attend | `BoosterCardHote` | `BoosterPopup.swift:111` | garder |

## Ce que le premier jet avait cassé ou oublié (30-09 au soir) — corrigé le même soir

1. **Choisir un exercice ne referme pas la page** : la fiche s'ouvre dessous, et tout le §5 et le §6 sont invisibles. C'est la cause des « pop-ups qui manquent ».
2. `SeanceV7Etat.lancerDirect` n'est lu nulle part : « Allez, go » ouvre seulement la fiche.
3. `InviteAnimee`, `HaloCarte`, `ChaleurTete` et la respiration de `CarreZoneMini` ont été remplacés par des copies figées.
4. Mon cadran (`CadranV7.swift`) et mes roues ont été supprimés le 30-09 : plus aucun composant de série n'est recréé.

## Superposition (à vérifier au simulateur)

La page v7 est montée au même niveau que le lecteur (zIndex 8,4). Tout ce
qui s'affiche PENDANT la page doit passer au-dessus :

- au-dessus (bon) : `PileAnnoncesHote` (9), `RewardCheminHote` (12), `StopCardHote` (13), `StoryPortal` (15), le film et les comètes ;
- en dessous (caché tant que la page est ouverte, comme avec l'ancien lecteur) : la fiche et tout son parcours (0), `PiluleVagabonde` (6), `BoosterCardHote` (6), Welcome Back (8). D'où la règle du §4 : **la page se referme quand une série part**.

## Les choix — validés par Kathryn le 30-09 (« go » sur mes recommandations)

1. **Le départ** : A. ton galet ou ton slider en bas de la page v7 · B. seulement dans la fiche. *Je recommande A.*
2. **Le verre des cartes** : A. vrai verre iOS 26 partout · B. vrai verre sur la tête des cartes seulement. *Je recommande B*, avec un barreau `-sansVerreV7` et une mesure iPhone.
3. **La flamme dans la rangée** : A. « elle prend feu » (trait orange d'1 px, étincelle, ta cérémonie) · B. « elle vole » du cadran à sa rangée · C. braises en plus. *Je recommande A, avec C.*
4. **Les comètes** : aussi au premier lancement de chaque exercice et à la séance complète ? *Je recommande oui, et rien de plus.*
5. **Le cadran** : halos plus orangé rouge et plus visibles (des valeurs de couleur seulement, aucun coût de chauffe) + le trait blanc au repos. *Je recommande oui, avec un avant/après.*
6. **Les rangées de séries** : les tiennes (`SetHistoryRow`, « +20 » et pièce), ou celles des cartes v7 ? *Je recommande les tiennes, dans les grosses cartes v7.*
7. **« Terminer »** : ton médaillon stop en bas (le lecteur), ou la capsule de verre en haut (la maquette v7) ? *Non tranché : la capsule de la v7 reste par défaut.*

## Comment on vérifie

- Chaque ligne « garder » et « brancher » est rejouée au simulateur, du départ à la Route, avec le banc `-v7Banc` et les bancs existants (`-goAuto`, `-departSerieAuto`, `-envolFire`, `-sheetFire`, `-robeNotif`, `-terminerSeanceAuto`), et le parcours est filmé.
- Rien n'est dit « fait » sans sa capture.
- La chauffe se mesure sur son iPhone (skill woop-performance) avant tout verdict.

## État (30-09, fin de soirée)

Codé contre cette liste et rejoué au simulateur : voir
[PLAN-SEANCE-V7-2026-09-30.md](PLAN-SEANCE-V7-2026-09-30.md), § « Vérifié au
simulateur » et « Reste ouvert ». Rien n'est mesuré sur l'iPhone, rien n'est
commité.
