# Retours TestFlight 85 — le plan (30-09-2026)

**Plan seul. Rien n'est codé ni mesuré, et rien n'est commité.** Chaque étape se fait après ton « go ».
On montre le résultat, puis on attend avant de passer à la suivante.

Build concerné : **85**, copié de l'arbre le 29-09 à 08:43 (`/tmp/nosfy-tf85`, HEAD `2004cced` + 1 176
fichiers touchés dans l'arbre).

| # | Ce que tu vois | Cause | Taille |
|---|---|---|---|
| 3 | La page Exercices en séance quand j'ajoute un exo depuis l'overlay | **trouvée à la lecture** : l'aller passe encore par l'onglet Exercices | moyen |
| 2 | « Gainage » dans la pastille au lieu de la date | **trouvée** : la pastille affiche le PREMIER exercice de la séance | petit |
| 5 | Des kilos demandés pour crunch au sol, toucher de chevilles, gainage | **trouvée** : ces 3 exos sont déclarés « reps × kilos » comme les autres. Le serveur ne garde aucun temps | gros (app + serveur) |
| 1 | Mode avion : l'app bugue, impossible de saisir en salle | **pas trouvée à la lecture** : on la reproduit d'abord | inconnu |
| 6 | La story, 3ᵉ page | **ta phrase est coupée** : il me faut la suite | ? |
| 4 | Repos : le cadran doit passer au noir avec une fumée blanche très forte | à voir en capture, puis maquette | moyen + chauffe |

---

## Étape 0 — Mettre à jour le site de doc (avant tout code)

La règle de la maison : un défaut constaté va sur le site. Les six retours y entrent comme défauts (🔴), et un
fait mesuré y est ajouté : **le 85 contenait déjà la 2ᵉ passe du chevron.**
`quitterLaFiche(feu: true)`, `CoupeEtat.shared.jouer(bascule)` et la garde `filmDepart == nil, morphPlayer <
0.98` sont bien dans `/tmp/nosfy-tf85`. Briques concernées : `b-fiche-chevron-seance`, `b-erreur-mode-avion`,
`b-flow-live-lune`, `b-tb-strength-sets`. On en ajoute une pour la pastille et une pour la story. Ensuite :
`npm run artefact && npm run verif`, puis republication au lien fixe.

---

## Étape 1 — La page Exercices ne doit plus jamais apparaître en séance (retour 3)

**Ce que tu vois.** Tu es dans l'overlay, tu touches « Ajouter un exercice », puis un exercice. Tu arrives sur
la page Exercices (les grands carrés Haut / Abdos / Bas…), la pastille repliée en haut.

**Pourquoi ce n'est pas le même bug que le chevron.** Les correctifs du 25-09 et du 29-09 (commités par
l'autre session : `be784c8d`, puis `2b7252ec` ce matin) gardent **les sorties** de la fiche et le menu. Ton
geste, c'est **l'aller** : aucun de ces correctifs ne le garde.

**La cause, lue dans le code.** Quand tu choisis un exercice, l'overlay n'ouvre pas la fiche lui-même. Il bascule
l'onglet sur Exercices, puis c'est **la page Exercices** qui doit pousser la fiche par-dessus elle.
- `NosfyApp.swift:2201-2204` : `onChoisirExo` → `PlayerEtat.exerciceDemande = exo` puis `selection = .exercises`
  (en direct, sans passer par la porte `allerAuxExercices`).
- `ExercisesView.swift:598-605` : la page lit la demande et pousse la fiche (`deepLinked = exo`).

Tant que la fiche vit **au-dessus de la page**, la page se montre dès que la poussée rate ou qu'on la défait.
C'est la cause unique déjà relevée le 22-09 (« le lecteur ouvre la fiche en passant par l'onglet
Exercices »), sous un cinquième costume.

**Les scénarios probables (à reproduire, pas encore prouvés) :**
- a. Tu ouvres l'overlay par la pastille **depuis une fiche A**. A reste empilée dessous. Tu choisis B : la page
  remplace une fiche empilée par une autre, et c'est dans ce cas que SwiftUI peut revenir à la racine.
- b. Le choix arrive pendant que la fiche précédente se dépile encore (le `dismiss()` part 0,3 s après).
- c. La page naît au moment même de la poussée (`initial: true`), et la poussée se perd.

**Le correctif proposé : la fiche ne passe plus par l'onglet Exercices en séance.** L'overlay ouvre la fiche
lui-même, au-dessus de la home, dans sa propre pile (montée seulement en séance, à la racine). La page n'est
plus sous la fiche, donc elle ne peut plus apparaître, quel que soit le geste : chevron, glissement depuis le
bord gauche, relance de l'app. Quand on quitte la fiche, la pile se vide et l'overlay est dessous.
- Pas de `fullScreenCover` : il a déjà gelé toute l'app le 27-08.
- À vérifier avant de coder : ce que la fiche attend de la page (sa nav du bas, la saisie, le cadran plein
  écran, le tuto).

**Avis de l'autre session (celle du chevron, 30-09).** Elle a lu le chemin et pense aussi que le scénario **a**
est le plus probable, parce qu'il colle à ta capture. Le **b** vient de son `dismiss()` différé de 0,3 s : la
fenêtre est courte et tombe pendant les paillettes. Le **c** est peu probable, car la page est déjà montée
quand on vient d'une fiche. Aucun banc ne tape encore la pastille depuis une fiche.

**Tu choisis entre deux correctifs :**

| | A. La fiche à la racine (mon plan) | B. Remplacer la fiche dans l'onglet (alternative de l'autre session) |
|---|---|---|
| Ce qu'on fait | En séance, l'overlay ouvre la fiche dans sa propre pile, au-dessus de la home | Quand une fiche est déjà ouverte, la page vide sa pile puis pousse B au tour suivant, sous la coupe (ou pile en `path`, on pose `[B]`) |
| Ce que ça ferme | Toute la famille : la page n'est plus jamais sous la fiche | Ce scénario-là ; la page reste sous la fiche |
| Taille | Moyenne (vérifier ce que la fiche attend de la page) | Petite (un seul endroit dans `ExercisesView`) |

Ma recommandation : **A**. C'est la sixième fois que ce défaut revient, et B laisse la page sous la fiche.
L'autre session tient les portes du chevron : c'est **toi** qui dis qui code. Rien n'est lancé sans ton go.

**La preuve.** Au simulateur, on filme ce scénario exact : séance ouverte → fiche A → pastille → overlay →
Ajouter un exercice → zone → B. On le filme à nouveau avec un glissement depuis le bord gauche, puis après une
relance en séance. Le verdict : **aucune image** de la page Exercices. Ensuite, ton iPhone.

---

## Étape 2 — La pastille : la date de la séance, pas « Gainage » (retour 2)

**La cause, lue.** Le contenu de la pastille (`contenuPilule`, `NosfyApp.swift:1711-1750`) écrit le nom de
`a.orderedExercises.first`, c'est-à-dire **le premier exercice de la séance**, pour toute la séance. Le
chiffre à côté du chrono (« · 12 reps ») vient lui aussi de la 1ʳᵉ série de ce premier exercice.

**Le correctif.** Le titre devient la date de la séance en cours, dans la langue de l'app : « Mardi 30
septembre » / « Tuesday, September 30 ». Elle est tirée de `startedAt`. La mini-carte du jour reste à gauche.
- **Question :** la ligne du dessous garde-t-elle « · 12 reps » ? Ce chiffre ne dit rien de juste
  aujourd'hui. Ma proposition : le chrono seul.
- **Question :** la Live Activity du système (île déployée, écran verrouillé) écrit, elle aussi, le nom de
  l'exercice en titre (`WorkoutLiveCard.swift:60`). On lui met la date aussi ? Ma proposition : oui, même
  règle partout.

**La preuve.** Une capture au simulateur, puis ton iPhone. La Live Activity ne se juge que sur l'iPhone
(piège payé le 20-09).

---

## Étape 3 — Saisir selon l'exercice : reps seules, temps seul, 3-2-1 GO (retour 5)

**La cause, lue.**
- Les trois exercices au poids du corps (`crunch-sol`, `chevilles`, `gainage`, `Models.swift:146-162`) sont
  déclarés « séries × reps × charge » (`tracking: .setsRepsWeight`) comme tous les autres.
- La pop-up propose toujours un poids **de 4 à 100 kg** (`SetEntrySheet.swift:72-73`). On ne peut même pas
  dire 0.
- **Serveur :** `strength_sets` n'a que `reps` et `weight`, tous deux obligatoires, et **aucune colonne de
  temps** (`supabase/migrations/0001_init.sql:43-44`). Le chrono d'un gainage reste dans le téléphone
  (`durationSeconds`) et n'est jamais envoyé : au serveur, il est perdu.
- Le cardio et le HIIT n'ont aucun décompte au départ : le 3-2-1 GO n'existe que dans le cadran de la muscu
  (`LiquidLensLab.swift:132-137`).

**Le correctif, côté app.**
- **Reps seules** (crunch au sol, toucher de chevilles) : la pop-up ne montre que le nombre de reps (et le repos).
- **Temps seul** (gainage) : pas de pop-up de reps ni de kilos. Commencer → **3, 2, 1, GO** → le cadran compte
  → Terminer. Le temps fait la série.
- **HIIT et cardio** : le même 3-2-1 GO au départ du **premier** set. Un seul allumage, repris du cadran, pas
  un deuxième dessin.
- Partout où s'écrit « 12 reps · 20 kg », on écrit « 12 reps » ou « 0:45 ». C'est le cas dans la fiche, la
  courbe, l'historique, la Live Activity, la story et la phrase du coach.

**Le correctif, côté serveur (une migration, posée avec ton accord).**
- `strength_sets.duree_s` : un entier, 0 par défaut, jamais négatif.
- `synchroniser_seance` l'écrit, et la relecture le rend.
- `exercices.tracking` accepte les deux nouveaux types. Le catalogue est regénéré par
  `tools/widgets/catalogue_sql.py`, jamais à la main.
- À vérifier : `weight = 0` passe la contrainte. Une série de gainage à 0 rep mais 45 s compte comme une série
  faite à la clôture (`cloturer_seance`), donc elle est payée. Le volume en kilos ne bouge pas (0 × reps = 0).

**Les questions.**
- Le gainage garde-t-il le choix du repos ? Ma proposition : oui.
- Tes anciennes séries de ces trois exos portent des kilos forcés (4 kg minimum). Ma proposition : on les garde
  telles quelles et on n'affiche plus les kilos pour ces exercices.

**La chauffe.** L'allumage se fait en valeurs animées, sans horloge qui redessine. Barreau : `-sansAllumage`.
**La preuve.** Une série au simulateur pour chaque type, puis la ligne relue au serveur (`duree_s` lue, pas
supposée), puis ton iPhone.

---

## Étape 4 — Le mode avion (retour 1)

**Ce que j'ai lu, sans trouver la panne :**
- La fin de séance s'écrit d'abord dans le téléphone (`NosfyApp.swift:669-726`).
- Le départ envoyé au serveur ne bloque rien.
- Un jeton qui ne se renouvelle pas faute de réseau ne déconnecte pas : seul un refus 400-403 rend la porte
  (`Supabase.swift:163-176`).
- Le coach attend 8 s au plus, puis parle seul.
- Au retour du réseau, la reprise existe (`NosfyApp.swift:2774`).

Donc **pas de correctif à l'aveugle.**

**Les suspects :**
- L'écran « Ouverture de ton compte… » bloque sans « Plus tard » quand le compte est à vérifier au lancement
  (`VerificationCompte.swift`).
- Un réseau « à moitié », comme le Wi-Fi d'une salle sans internet : chaque appel attend son délai (8 à 60 s)
  au lieu d'échouer tout de suite.
- La story qui attend le reçu.
- Un appel caché dans la saisie, que je n'ai pas trouvé.

**Question :** que se passe-t-il, et à quel moment ?
- L'écran d'erreur avec la bête ?
- « Ouverture de ton compte… » qui tourne ?
- L'app figée ?
- La série qui ne s'enregistre pas ?

Et c'était le vrai mode avion, ou une salle sans réseau ?

**La méthode.**
1. Un interrupteur de banc qui fait échouer tous les appels comme en mode avion.
2. On déroule tout le parcours et on le filme : lancement, départ, overlay, fiche, 3 séries, repos, fin, story,
   Route.
3. Le même parcours sur ton iPhone, en vrai mode avion.
4. On corrige à l'endroit vu.

La règle visée : **en séance, rien n'attend le réseau.**

---

## Étape 5 — La story, 3ᵉ page (retour 6, phrase coupée)

Ce que je vois sur ta capture, **à confirmer** :
- **« 1 sets »** : le pluriel n'est pas géré. En français, ce serait « 1 séries ». C'est vrai dans les cinq
  gabarits (`StorySuite.swift:769`, `:780`, `:785`, `:790`).
- **« 156 minutes »** : c'est la durée d'ouverture de la séance, 2 h 36. Ta 1ʳᵉ capture montre 152:49 sur la
  pastille : la séance était restée ouverte.
- **Le grand mot en fond**, derrière les stickers, est coupé à droite (« SOLI… »).

**Question :** que voulais-tu dire au point 6 ?

---

## Étape 6 — Repos : noir et fumée blanche très forte (retour 4)

**Ce que j'ai lu.** Le cadran (`LiquidLensLab.swift` + `LiquidLens.metal`) garde le même verre en effort et en
repos. En repos, seul le petit mot au-dessus du chrono passe à l'orange (`:1306-1311`). À la lecture, je ne
vois pas ce que tu appelles « le noir de fumée ».

**Le chemin.**
1. Une capture au simulateur du cadran en effort puis en repos, côte à côte, pour qu'on parle de la même chose.
2. Une maquette du repos, avec des gros plans ×3 : noir, fumée blanche très forte qui monte et roule. Pas de
   bande qui balaie.
3. Ton oui.
4. Le shader.

**La chauffe.** Ce cadran est déjà le premier suspect de la chauffe en séance : il redessine à 60 Hz sans
porte (`m-tf82-seance-longue-lentille`). La fumée vit dans le shader déjà monté (un paramètre de plus, pas
une couche nouvelle). Barreau : `-sansFumeeRepos`. Mesure sur ton iPhone avant et après (skill
`woop-performance`).

---

## Étape 7 — TestFlight 86

On copie `tools/production/testflight-85-2026-09-29/`, on change `BUILD=` et le préambule. En tête des
consignes de test : ce que personne n'a pu vérifier avant l'envoi.

## Chevauchement avec le chantier Réglages (session 39, plan seul, 30-09)

Tu as demandé un 4ᵉ onglet « Réglages » avec la langue et le format de départ de série : galet blanc ou
slider. En mode slider, la fiche montre le slider à la place du galet, et le lancement arrive **directement
au chrono 0:00**. Plan : `tools/reglages/PLAN-REGLAGES-2026-09-30.md`. Ce chantier touchera plus tard des
fichiers de mes étapes 1 et 3 : `NosfyApp.swift`, `ExerciseDetailView.swift`, `LiquidLensLab.swift`,
`TapisScene.swift`, `CardioFiche.swift`.

- **À trancher par toi :** en mode slider, le départ « directement à 0:00 » saute-t-il le 3-2-1 GO de l'étape
  3 ? Ma proposition : le **GO reste** pour le gainage, le HIIT et le cardio. C'est un décompte, pas une
  cinématique, et le slider ne fait que remplacer le galet.
  **La session 39 est d'accord (30-09)** : son slider appellera `launchPosed()`, donc le même départ, avec le GO.
  Son plan recommande la même chose (D2). Il fixe l'ordre : **mon étape 3 d'abord**, le J2 de Réglages
  ensuite. Elle ne touchera ni `ExerciseDetailView`, ni `LiquidLensLab`, ni `TapisScene` tant que l'étape 3
  n'est pas posée, ou abandonnée par toi. Le dernier mot reste le tien.
- Chaque fichier partagé que je modifie est noté dans `MULTI-SESSION.md`.
- **Défaut suspect relevé par la session 39** (lu, non mesuré) : sous VoiceOver, le bouton du galet ne
  relèverait pas le cadran (`LaunchPebble` ligne 169, `ExerciseDetailView:1264-1266`). En muscu, le chrono ne
  viendrait jamais. À mettre dans les consignes de test du 86.

## Les règles tenues à chaque étape

- On lit le site du domaine avant de coder, et le site est mis à jour dans le même geste.
- Skills `woop-architecture` (vues), `woop-backend` (migration), `woop-performance` (cadran, allumage).
- On vérifie qu'un commit compile seul dans un worktree détaché. L'arbre partagé donne un faux vert.
- Aucun commit sans ton ordre. Commit par chemins, jamais nu.
