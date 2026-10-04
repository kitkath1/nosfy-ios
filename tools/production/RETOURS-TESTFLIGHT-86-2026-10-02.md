# Retours TestFlight 86 (02-10-2026)

Neuf captures commentées par Kathryn, l'après-midi du 02-10. Le HIIT est le plus grave (« le plus compromettant »).
Maquettes demandées : <https://claude.ai/artifact/CQEp5reqhq9atvvhzeenZY> (séance vide, saisie et repos, un seul slider pour finir).

| # | Son retour | Cause lue | État |
|---|---|---|---|
| 1 | HIIT : « il se déroule tout seul, au bout de X secondes il passe en repos ; c'est moi qui gère le repos et la vitesse » | `lancerTapis` armait `SeanceTapis.minute = (20 s, 40 s)` (HIIT minuté v17, d94d757e) : `armerLeMinuteur` appelait `stopper` puis `relancer` seul | Corrigé dans l'arbre : la fiche n'arme plus le minuteur (`ExerciseDetailView.swift`, `lancerTapis`). Le modèle le garde pour le banc `-tapisMinute`. Les médaillons EFFORT / RÉCUP disparaissent avec lui |
| 2 | HIIT : « il manque les pop (annonce flamme) quand je termine un set » | La pop-up flammes « SETS » avait été retirée avec le minuteur (v17) | Rétablie dans l'arbre : `lancerLaFete` la montre à +0,4 s, seulement si la récup est encore en cours (`TapisScene.swift`) |
| 3 | HIIT : « j'ai lancé un exo et je vois le menu » | Non trouvée, voir § Nav pendant le HIIT | Garde posée dans l'arbre : le châssis cache la nav tant que la scène du tapis est montée (`TapisEnCours`) |
| 3b | HIIT : « il faut un état 0 km/h qui clignote pour montrer que l'user doit sélectionner sa vitesse, au repos ou au HIIT » | Le HIIT partait à 10 km/h à l'effort et à 7 en récup, deux vitesses inventées | Dans l'arbre : départ à 0 aux deux (`ModeCardio.hiit`). 03-10, sa réponse « 0 c'est plus clair, avec un effet de lumière à l'intérieur » : chaque Stop et chaque reprise repartent de 0, le tapis lent part aussi à 0, et une lumière respire DANS le galet tant qu'il vaut 0 (`LumiereAChoisir`, sans flou ni couleur). Le chiffre ne clignote plus |
| 4 | Fiche ouverte depuis la séance : « pas de galet » | Le 86 lisait le réglage galet/slider aussi en séance | Déjà corrigé dans l'arbre par la session Exercices (02-10) : la fiche de séance part au slider. Pas vu à l'écran en séance |
| 5 | « Slider design composant missing » sur « ▶ Let's go · Treadmill HIIT » | Même cause : réglage « galet » → `BoutonPrimaire` au lieu de `SliderObsidienne` (`SeanceV7.swift`, `depart`) | Déjà corrigé dans l'arbre (`departSlider { true }`, session Exercices). Pas vu à l'écran |
| 6 | « Des fois le bouton Terminer en haut, des fois en bas avec le slider » | `barreHaut` montre « Terminer » tant qu'il reste un exercice ; le slider du bas devient « Terminer la séance » quand tout est fait (`SeanceV7.swift`, `barreHaut` et `depart`) | Maquette : un seul endroit, le slider du bas. À trancher : finir avant la fin passe par le ■ de la pilule |
| 7 | « Pourquoi deux sliders » (carte STOP par-dessus « Terminer la séance ») | Le slider du bas appelle `onStop`, qui ouvre la carte STOP et son propre slider | Maquette : le slider du bas termine directement ; la carte STOP ne vient que du ■, et le slider de la page se retire sous elle. Rien codé |
| 8 | Saisie de série : « trop de texte, pas assez aéré » ; « pareil pour l'ajout des repos » | « Série 1 » ×2, « à noter · 1 sur 3 », « Dernière fois… », 4 puces, « Valider · repos 1:30 » | Maquette : le cadran dit la série une fois, valeurs déjà posées, repos en une ligne (menu natif), « Valider » seul. 03-10 (« encore trop de texte, aère, à la Apple ») : `SaisieApple`, dans la grammaire de l'écran « Let's go » (nom en capitales espacées, valeurs entre deux traits de 1 pt, chiffres légers dégradés, « Repos 1:30 » en une ligne, `BoutonPrimaire` « Valider »). Rien codé |
| 9 | Séance vide « pas assez claire, aérée » ; « une suggestion refaire la séance précédente » | `SeanceV7.swift` (« Compose ta séance. » + « Ajouter un exercice ») | Maquette : un seul point focal (+), « Ta dernière séance » en bas avec « Refaire ». Compte neuf : pas de suggestion. Rien codé |
| 10 | « Des fois une salle de composants qui me redemande de rejouer la série faite » | Identifié le 03-10 (elle) : la carte « TA SÉANCE DE LA SEMAINE » de la séance vide (`SeanceDeLaSemaine`). `derniere` (`SeanceV7.swift`) prend la dernière séance TERMINÉE, de n'importe quel jour, y compris celle finie dans la journée ; sans séance finie, la carte n'existe pas (le « des fois ») | Maquette `VideApple` : la suggestion est intégrée à l'écran (« 4 exercices, mardi » + « Refaire ta séance de mardi »). Règle proposée : jamais la séance faite le jour même, mais la dernière d'un autre jour ; sans séance, son objectif. Rien codé |
| 11 | « UI cheap, regarde les borders » (cartes de la page) ; « je ne peux pas cliquer sur une série terminée » | Cartes à bord épais de `SeanceV7` ; les lignes faites ne s'ouvrent pas | Maquette : liste groupée à filets fins, chevron sur chaque ligne. Rien codé |

## 03-10 : maquettes validées (« ça me va, code »), codées

- **Séance vide** (`SeanceV7.swift`, `VideV7`) : la grammaire de l'écran « Let's go ». La dernière séance d'un autre jour (`derniere` exclut aujourd'hui) avec « Refaire ta séance de mardi », sinon son objectif s'il a été choisi (`Goal.cleHebdo`), sinon pas de chiffre. Le voile de la barre du haut s'efface sur la séance vide (il éteignait la lampe). `SeanceDeLaSemaine` est archivée, sans site d'appel.
- **Note de série** (`CadranV15.swift`, `NoteV15`, `TeteV15`, `ChromeV15`) : pendant la note, le nom seul en capitales, ni onglet ni bloc « Série 1 · à noter » ; valeurs entre deux traits (Inter light, `MotsFlou.blancDegrade`), celle de la molette allumée ; « Repos 1:30 » en `Menu` iOS ; `BoutonPrimaire` « Valider ». Le lecteur revient au repos.
- **Un seul slider** (`SeanceV7.swift` + 1 hunk `NosfyApp.swift`) : plus de « Terminer » en haut ; le slider « Terminer la séance » appelle `terminerSeance()` directement (`onTerminer`), sans la carte STOP. La carte reste au ■ de la pastille.
- Vu au simulateur le 03-10 (`tools/seance-v7/captures-tf86-2026-10-03/`) : séance vide d'un compte neuf (01) et avec un passé (02, « 3 exercices, vendredi », « Refaire ta séance de vendredi ») ; note filmée par `-v15Auto` (03, 04). La lampe de l'île était hors écran (cadre centré sur 0, son cœur à −258 pt), recentrée et revue.
- **Bout en bout à vrais touchers (XCUITest, 03-10)** — `tools/seance-v7/bout-en-bout-2026-10-03/` (`joue.sh`, test, journal, captures). Trois cas passent :
  - compte neuf : vide → ajout de Woodchopper → trois séries (slider, Stop, note, menu Repos, Valider, repos, slider « Lancer ») → « Tout est fait » → slider « Terminer » glissé : la séance se clôt, sans carte STOP ; l'accueil dit « 1 séance », puis vient la story de fin (après la réponse de clôture, au plafond de secours au simulateur) ;
  - un passé : « Refaire ta séance de vendredi » remplit la page des 3 exercices. Vu en passant et corrigé : « 1 séries » → « 1 série » (`SeanceV7.swift`, carte et légende du slider) ;
  - HIIT : 27 s d'effort sans toucher, toujours en effort ; galet glissé → 4 km/h ; Stop → récup à 0 et pop flamme « ON FIRE · SETS · Close » ; 17 s de récup sans toucher, rien ne repart ; Go → l'effort repart à 0 ; maintenir → fini, nav revenue ; aucun bouton de nav touchable pendant la course.
  - À savoir : la pop flamme reste jusqu'à « Close » (ou un toucher à côté, qui la ferme sans relancer).
- Pas codé : la page en cours / finie en lignes fines (`TerminerApple`, les bordures « cheap »), le toucher d'une série faite (sa réponse attendue).

## 03-10 après-midi : « hors sujet », « trop de texte », la salle sans réseau

- **La séance vide codée (VideV7) est refusée au simulateur** : « on comprend rien, je voulais un état empty… le but : une page vide en grammaire Apple, pour ajouter des exos ». L'affiche « Let's go » (galet, flamme, grand titre) était hors sujet. **« Trop de texte »** aussi sur le repos : le nom de l'exercice 3 fois, « Série 2 » 3 fois. Nouvelles maquettes, rangée 4 de l'artefact (version 11) : vide = « Aucun exercice » + un bouton « Ajouter des exercices » (ou ses zones tout de suite), une ligne « Refaire vendredi » ; repos = le nom une fois, le cadran (filmé), le slider « Série 2 », rien d'autre. Rien codé ; `VideV7` reste dans l'arbre en attendant son choix.
- **« À la salle, comme je capte pas, je ne peux pas utiliser l'app, je reçois le message d'erreur de Nosfy »** : cause lue (un refresh refusé effaçait tout et rendait la porte, recouverte par l'écran hors ligne), corrigée et mesurée au simulateur. Voir `docs/site` (b-erreur-mode-avion) et `tools/erreur/hors-ligne-session-suspendue-2026-10-03/`. Non mesuré sur l'iPhone.

## 04-10 : son verdict sur les maquettes, le plan

« Bien lui [vide v1] avec la pilule noire discrète en fond ; le + ouvre la feuille, on choisit une zone, puis ses exercices ; retour aux cartes ; Terminer v1 très bien mais liquid glass, flamme blanche, le fond ; le chrono très bien ». Et : « sur la page cadran, tirer vers le bas me remet sur le résumé de la séance, comme Spotify ». Artefact rangée 5 (version 12), plan `tools/seance-v7/PLAN-SEANCE-APPLE-2026-10-04.md`. Rien codé, son accord attendu.

## 04-10 soir : « go », codé

Ses ordres du soir, codés dans l'arbre (non commité) : la séance vide v1 avec le galet en fond (la VIDÉO de « Let's go » sur la page vide seulement, le poster ailleurs — `-sansGaletVideo`) ; l'arrivée vide → séance animée (le + glisse dans la barre, la séance monte en trois temps) ; la séance en lignes fines avec « TA SÉANCE / Prête. / En cours. / Tout est fait. » et le chiffre entre deux traits ; les flammes blanches SEULEMENT pour les séries faites ; la ligne ouvre la PLAYLIST (feuille en verre : les séries faites avec flamme et valeur, glisser pour supprimer, la prochaine avec sa pastille ▶ en verre, « Ajouter une série ») et la vignette ouvre la fiche ; l'ajout en deux temps (zones, puis exercices) ; l'onglet Séries du cadran = la même playlist, sans « À suivre », avec « Ajouter une série » ; le cadran se TIRE vers le bas comme Spotify (offset + léger recul, le fond de la séance dessous, seuil 120 pt, chien de garde) ; le médaillon Stop à 88 pt, enfoncé au doigt, bouffée blanche au tap ; le halo du doigt sur la page.
« Gainage, crunch, exercices au sol sans poids » : déjà réglé depuis le 30-09 (`Exercise.Saisie` : reps seules / temps seul, note v15, Live Activity, serveur `duree_s`) — relu, rien à changer ; vérifié au banc du 04-10 sur le crunch (note sans kg).

## Nav pendant le HIIT

La fiche publie `bandeVisible: running == nil && flood < 0.01 && seanceTapis == nil` (`ExerciseDetailView.swift`, `PageCard`). La nav du châssis (`NosfyApp.swift`, `NavEtat.bandeVisiblePubliee`) devrait donc se cacher.

Au simulateur, le banc `-bancHiit` (DEBUG, `NosfyApp.swift`) a parcouru 9 chemins. `bandeVisiblePubliee` vaut `false` pendant toute la course, sur chacun d'eux. Le code de la nav est identique entre la copie figée du 86 (`/tmp/nosfy-tf86`) et l'arbre. La cause reste inconnue.

La garde ajoutée : `TapisScene` pose `TapisEnCours.shared` à son apparition et le retire à sa disparition. Le châssis lit ce drapeau en plus du registre. Vu au simulateur : pas de nav pendant la course, et la nav revient après Finish.

Preuves : `tools/tapis/retours-tf86-2026-10-02/` (01 à 16).

Vu seulement au simulateur. Rien n'est mesuré sur l'iPhone.
