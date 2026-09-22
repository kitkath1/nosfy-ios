# Exercices : l'accueil par zones, le carrefour de fin d'exercice, et le mouvement

Analyse et plan du 21-09-2026, avant toute ligne de code (règle du 29-08).
Demande de Kathryn, dictée le matin :

> « Quand on arrive sur la liste des exercices, on a la molette, très bien, et
> la liste — mais c'est pas très clair. Les utilisateurs aimeraient une sorte de
> page d'accueil d'exercices : des designs minimal blancs, comme la référence,
> en mode cards, des typologies d'exercices. Le user clique sur Abdos et arrive
> dans la page Abdos avec la liste, qui reste inchangée pour le moment. Aussi :
> quand l'utilisateur termine un exercice, il ne comprend pas qu'il faut aller
> piocher un autre exercice pour continuer — être plus guidé, ou tout remettre à
> plat. Et : j'ai un MCP Higgsfield pour animer les images en vidéo (Kling), pas
> cher — challenge-moi. Les gens aiment voir le mouvement, le schéma. Les
> programmes IA, plus tard. »

La référence qu'elle partage : des tuiles sombres arrondies, un corps gris, le
muscle visé en **blanc** (« Quadriceps 60 % », « Pectoraux 20 % »), sur noir.

---

## ⚠️ Correction de Kathryn (21-09, 10 h) — lue avant tout le reste

> « Tu vas trop vite et c'est pas du tout ce que j'ai demandé. Pour les images,
> ça va pas : j'ai demandé des **carrés**, **dégradé de noir**, et l'idée c'est
> de reprendre **l'anatomie du corps** comme sur ce que je t'ai partagé — en
> **gris** les parties du corps qui ne sont pas concernées, en **blanc** les
> parties concernées. »

Ce que ça change : (1) elle voulait **un plan et un challenge**, pas un banc
codé le matin même — le banc reste dans l'arbre, non commité, dans
`ExercisesView.swift` seul, et **ne bouge plus** tant qu'elle n'a pas tranché
(le garder pour la mise en page, ou le retirer : D0) ; (2) il n'y a **qu'une
robe d'icônes**, la sienne (§ 3, « Les icônes ») — les pictogrammes Apple et
les photos recadrées du banc sont des bouche-trous **refusés**.

---

## 0. En une phrase

Trois trous, un seul fil : **l'utilisateur ne sait jamais où il en est dans sa
séance** — à l'entrée (un mur de 29 cartes et une molette à apprendre), à la
sortie d'un exercice (une pop-up qui dit « Terminé » puis plus rien), et devant
un exercice qu'il ne connaît pas (une photo figée d'un geste).

---

## 1. Ce que l'utilisateur voit aujourd'hui (vérifié dans le code)

Le parcours : Route → Start → décompte → **Exercices** (`docs/site/content/pages/flow.mdx`, § « Le départ, maintenant »).

- **La page Exercices** (`Nosfy/Views/ExercisesView.swift:393`) : la grande card
  posée sur la vidéo de fond `exos-fond-loop`, le titre, deux chips (cards ↔ liste
  :416, recherche), et **les 29 exercices** en deux colonnes de cards de 200 pt
  ou en liste de rangées de 64 pt (`GrilleExos` :1736). En bas, **la molette
  couchée** (`ArcDial` :2160) : six crans — Tout, Haut, Abdos, Bas, Fessiers,
  Cardio (:2163). Elle ne prend pas le doigt : c'est la bande basse de 156 pt
  qui la tourne (:466). Le titre devient le nom de la section choisie (:723).
  Le contenu se termine 210 pt avant le bord bas : le lit de la molette, où
  aucune carte ne reste nette (:1769).
- **Le catalogue** (`Nosfy/Models.swift:27`, :93) : 29 exercices, cinq zones —
  Haut 6 · Abdos 10 · Bas 4 · Fessiers 5 · Cardio 4. Chaque zone a déjà un
  sous-titre (:36 — « Dos, pectoraux, épaules, bras », « Rotation, gainage,
  anti-rotation »…). Le cardio « ne désigne pas une zone » (:24-26).
- **L'aide du premier départ** : une carte éclairée dans la brume,
  « Choisissez un exercice — Il s'ajoutera à votre séance », Passer
  (`VisiteExercice.swift`, ancre `tuto-card` posée sur la PREMIÈRE carte,
  `ExercisesView.swift:1078`).
- **La fiche** (`ExerciseDetailView.swift`) : photo héros, titre, consigne,
  erreur fréquente, courbe de charge, ligne de coach ; le galet lance une série.
  Fin de série → retour à la fiche → pill de pièces (2 s) ou Moment → puis la
  pop-up **« Encore une série ? · À ton rythme. · [Recommencer] [Terminé] »**
  (`RestartSheet.swift:151-185`), posée par `finirSerie` → `jouerIssue` →
  `poserLaQuestion` (:3031, :3114, :3141).
- **Après « Terminé »** : `exitRestart(thenLaunch: false)` (:3152) enregistre la
  série… et c'est tout. L'utilisateur reste sur la fiche, muette. Pour
  continuer, il doit deviner le chevron (:2207, `dismiss()`) qui ramène à la
  page Exercices — la même page que la première fois, la card levée, la pastille
  du player en bas (:689). Rien ne dit « choisis le suivant ». Pour finir la
  séance : l'**appui long** sur le galet play (`NosfyApp.swift:1072`) ouvre
  « Terminer la séance ? » (`PlayerSeance.swift:75`) — un geste enseigné nulle
  part — ou le STOP du player.

Trois faits qui comptent pour la suite :

1. Le filtre par zone **existe déjà** (`filter`, :399) et la molette **le pilote
   déjà** : une card de zone n'a qu'à écrire ce même état. Pas de nouvelle
   navigation à inventer.
2. Les sous-titres de zone **existent déjà** dans le modèle : l'accueil n'écrit
   aucun texte nouveau.
3. Le panneau « Terminer la séance ? » **existe déjà** et s'ouvre par un simple
   état (`DepartEtat.shared.pauseOuverte`, `DepartSeance.swift:35`) : le
   carrefour n'a qu'à l'appeler.

---

## 2. Le diagnostic : trois trous

**Trou 1 — l'entrée : le filtre est un objet à apprendre.** La molette est
belle, mais elle n'a pas de surface visible (elle se tourne « par la bande »),
le mur de 29 cartes sous « Tout » ne dit rien du corps, et ses bugs passés
(30 tours, sensibilité, filet du départ) montrent ce que coûte un filtre au
geste. Les utilisateurs veulent **choisir une zone avant de voir des
exercices** — c'est exactement ce que dit la référence.

**Trou 2 — la sortie : pas de carrefour.** La question est binaire (encore /
terminé) et « Terminé » est un cul-de-sac. L'utilisateur ne sait ni qu'il doit
aller chercher un autre exercice, ni où (le chevron ramène à une page identique
à la première fois), ni comment finir (l'appui long n'est jamais montré).

**Trou 3 — le mouvement n'est pas montré.** La photo héros montre UNE pose ;
la consigne décrit le trajet en mots. Un débutant devant « Pull-through à la
poulie » a besoin de voir le geste.

Les trois se répondent : **le « suivant » du carrefour a besoin d'un endroit
où atterrir qui dise « choisis une zone »** — c'est l'accueil. Sans l'accueil,
le carrefour renvoie au mur ; sans le carrefour, l'accueil n'est vu qu'une fois.

---

## 3. Chantier A — l'accueil des exercices (les zones en cards)

### Ce que tu verras

La page Exercices s'ouvre sur **cinq cards blanches minimales, une par zone** :
Haut · Abdos · Bas · Fessiers · Cardio — l'icône, le nom, le sous-titre déjà
écrit, et le nombre d'exercices en pilule (le « 60 % » de la référence).
Tap sur Abdos → la liste des dix exercices d'abdos, **inchangée** (cards ou
liste, la chip, la recherche), le titre dit « Abdos », la molette se cale
d'elle-même sur le cran Abdos. Tourner la molette jusqu'à « Tout » ramène
l'accueil ; taper le chevron ramène à la home, comme aujourd'hui.

**Le mur des 29 disparaît** : « Tout » devient l'accueil. Pour tout voir, on
cherche (la recherche est globale, `ExosCatalogue.liste` :1099) ou on tourne.
C'est une décision à prendre (D3) — je la recommande : c'est ce mur qui n'est
« pas très clair ».

### Deux formes de cards, à choisir sur le simulateur (banc `-accueilForme`)

(La forme des cards n'est pas la robe des icônes : quelle que soit la forme, l'icône est le carré anatomique ci-dessous.)

- **Rangées** (la référence, mot pour mot) : icône 56 · nom 16 · sous-titre 12
  · pilule « 10 ». Cinq rangées de 76 pt = 412 pt. Le contenu net disponible
  au-dessus du lit de la molette est de **420 pt** sur iPhone 15 (mesuré au
  banc : le contenu commence 141 pt sous le bord de l'écran — zone sûre 59 +
  bandeau 82 — et le lit à 561) : **tout tient sans scroll, aucune card dans le
  voile.** (À 88 pt, la cinquième rangée passait sous le nom du cran.)
- **Tuiles** (« en mode cards ») : 2 × 2 pour les quatre zones du corps, et
  Cardio en tuile large en dessous (il « ne désigne pas une zone »). ≈ 421 pt.

### Les icônes : SA référence, pas une autre (correction du 21-09, 10 h)

Il n'y a **qu'une seule robe**, celle de l'image qu'elle a partagée :

- **le carré** : une tuile carrée à coins arrondis, en **dégradé de noir** (du
  gris très sombre vers le noir), comme les tuiles de la référence ;
- **dedans, le corps** : une planche anatomique — les muscles dessinés — **en
  gris**, et **la zone visée en blanc**. Haut : pectoraux, épaules, bras (le
  dos, de dos) ; Abdos : grand droit et obliques ; Bas : quadriceps, ischios,
  mollets ; Fessiers : glutéaux ; Cardio : à trancher avec elle (le corps
  entier en marche ? le cœur ?) ;
- **cadré sur la zone** : la référence montre les jambes pour « Quadriceps »,
  le torse pour « Pectoraux » — chaque carré est un **recadrage du MÊME
  corps**, pas un dessin à part.

Comment on les fabrique — **un seul corps, jamais cinq dessins à la main** :

1. **Un corps de référence** (de face ; de dos pour le dos et les fessiers),
   planche anatomique gris sur noir, sans texte : généré UNE fois (Higgsfield,
   modèle image, après sa connexion — § 7), ou fourni par Kathryn si elle a une
   planche sous licence.
2. **`tools/exos-accueil/cuire_icones.py`** : sur CE corps, les cinq zones
   tracées une fois (polygones), peintes en blanc ; cinq recadrages ; le
   dégradé de noir du carré ; sortie `typo-<zone>` @1x/2x/3x dans
   `Assets.xcassets`. Une main humaine une fois, sur le corps — zéro par carte.
3. Le banc reçoit les cinq assets **sans changer une ligne de vue** (la tuile
   d'icône lit `typo-<zone>` ; les bouche-trous disparaissent).

⚠️ Les icônes du banc du matin (`-accueilRobe symboles|photos`) ne sont **pas
le design** : elles ne servent qu'à juger la mise en page (les cinq rangées,
les tuiles, la pilule, la molette) en attendant les carrés. Les captures
`b1`–`b4` se lisent avec cette réserve.

Demain, la même anatomie servira **« Muscles ciblés » sur la fiche** (sa
référence exacte : Quadriceps 60 %, Pectoraux 20 %). Un seul système d'icônes,
deux usages — c'est pour ça qu'on ne fabrique pas cinq icônes à la main.

### Ce qui ne change pas

La liste et ses cards/rangées, la recherche et le clavier natif, la molette
(elle reste le raccourci entre zones voisines, et VoiceOver passe toujours par
elle), le chevron → home, la pastille du player, le tuto à projecteurs, et
**l'invariant PageCard — taille fixe partout — que rien ne touche.**

### Les lois que ça touche (skills `woop-architecture`, `woop-performance`)

- **Verre sur vidéo** : cinq verres `.clear` de plus au maximum (la liste en a
  29) ; l'accueil ne scrolle pas → aucun voile vivant, aucun flou à rayon animé.
  **Barreau `-sansVerreAccueil`** (nuit opaque `white 0.055`, la recette de
  `-sansVerreListe`).
- **Rien par image** : `accueil: Bool` change au tap seulement (famille de
  `cherche` et `modeListe`, jamais dans l'`@Observable` du par-image) ;
  l'accueil est un `struct View` aux entrées stables.
- **La cascade** : même transition que les cards (opacité + offset, pilotée par
  le `withAnimation` de la mutation, sinon téléportation).
- **Le tuto** : l'ancre `tuto-card` passe sur la première card de zone ; le
  texte « Choisissez un exercice » devient à discuter (D5 : « Choisissez une
  zone » ?).
- **Le type-checker** : sous-vues nommées, constantes en `static let`.
- **La mesure** : sur TON iPhone, thermique 0, ABBA, la paire (img, cpu)
  accueil vs liste. Le simulateur ne juge que le dessin.

### Bancs

`-exosAccueil 0|1` (forcer le mur ou l'accueil), `-exosSection n` (une zone
posée, inchangé), `-accueilForme rangees|tuiles`, `-accueilRobe symboles|photos`,
`-sansVerreAccueil`, `-tutoExos` (le projecteur sur la première zone).

### Coût

Une journée (code, captures, doc). Les icônes anatomie : une demi-journée
après ta connexion Higgsfield.

---

## 4. Chantier B — le carrefour de fin d'exercice

### Aujourd'hui

« Encore une série ? · [Recommencer] [Terminé] ». Terminé = rien.

### Proposition A (recommandée) : la pop-up devient le carrefour

Le titre dit ce qui vient d'arriver, en vrai (lu de la séance, jamais inventé) :
**« Série 3 terminée »**, sous-titre « Tirage vers soi · +60 pièces ».
Trois sorties, toujours les mêmes, dans l'ordre d'usage :

1. **Encore une série** — primaire (la capsule de verre, inchangée).
2. **Exercice suivant** — secondaire : la fiche se ferme (`dismiss()`), la page
   Exercices s'ouvre **sur l'accueil des zones**. C'est ici que A et B se
   répondent.
3. **Terminer la séance** — tertiaire, encre nue : ouvre le panneau existant
   « Terminer la séance ? » (`DepartEtat.shared.pauseOuverte = true`), qui
   déclenche déjà toute la chaîne de fin (trophée, pièces, booster).

La croix et le fond ferment sans choisir : on reste sur la fiche, comme
aujourd'hui — rien ne casse pour qui veut relire sa courbe.

Ce que ça touche : `RestartSheet.swift` (propre), `ExerciseDetailView.swift`
(deux fermetures dans `exitRestart` — ⚠️ **fichier mixte** : une autre session
y porte 14 lignes en vol, hunks à part), rien dans `NosfyApp.swift`.
Banc : `-serieFin` existe déjà pour poser la pop-up.

### Proposition B (« tout remettre à plat ») : le tableau de séance

Après « Terminé », on n'atterrit plus sur la fiche mais sur **l'ardoise ouverte**
(`SessionSlate`) : ce qui est fait, l'exercice courant, et en pied « Exercice
suivant » / « Terminer ». L'ardoise devient LA page de séance. Trois à quatre
jours, et elle touche la dalle du player (l'invariant PageCard) — pas
maintenant, et pas sans un plan à part.

### Ce que je recommande

**A maintenant** (une demi-journée). B quand les programmes IA existeront :
« Exercice suivant » deviendra « Suivant : Développé couché » — le programme
dit quoi faire, le carrefour le montre. Le carrefour est l'endroit où l'IA
parlera ; on le pose aujourd'hui vide de suggestion.

---

## 4 bis. « Tu es sûr que c'est la meilleure expérience ? » (Kathryn, 21-09, 10 h 20)

Réponse honnête : **non, pas à elle seule.** L'accueil par zones répare la
bibliothèque (on trouve un exercice), le carrefour répare la sortie (on sait
quoi faire après). Mais la cause du « les users sont perdus » est en dessous des
deux : **la séance n'a pas de forme.** On appuie sur Play, on tombe sur une
bibliothèque vide de sens, on choisit un exercice, on le fait, et rien ne dit
jamais « voilà ta séance : ce que tu as fait, ce qu'il te reste, quand tu as
fini ». Un débutant ne veut pas COMPOSER une séance, il veut en SUIVRE une.
Les apps qui ne perdent personne (Fitness+, Nike Training Club, Freeletics)
commencent toutes par une séance proposée, pas par un catalogue.

Ce que ça donnerait, sans rien casser d'existant :

1. **Le tableau de séance devient la maison de la séance.** L'ardoise
   (`SessionSlate`) existe déjà, cachée derrière un tirage que personne ne
   trouve. Après Play et après chaque « Terminé », on atterrit DESSUS : la
   liste des exercices faits avec leurs séries, l'exercice en cours, et deux
   boutons toujours au même endroit — « Exercice suivant » et « Terminer ».
   La fiche n'est plus qu'un aller-retour depuis ce tableau.
2. **La séance du jour est proposée, pas construite.** Le galet du jour de la
   Route porte déjà « la séance d'aujourd'hui » : il peut porter trois à cinq
   exercices pré-choisis (par zone, ou la dernière séance rejouée). Le tableau
   s'ouvre rempli en « à faire » ; « Exercice suivant » ouvre directement la
   fiche du prochain. La bibliothèque par zones sert à REMPLACER ou AJOUTER,
   plus à démarrer. C'est l'antichambre exacte des programmes IA : le jour où
   l'IA existe, elle remplit ce tableau, rien d'autre ne change.
3. **La fin est visible** : le dernier exercice fait, le tableau dit « séance
   terminée » et propose Terminer — plus d'appui long à deviner.

Ordre de priorité si elle valide cette lecture : le tableau (1) d'abord, la
séance proposée (2) ensuite, l'accueil par zones et le carrefour deviennent
des pièces de ce tableau. Rien de codé : c'est une décision de fond (D7).

Les icônes : elle a tranché D2 — **le corps est généré**, la zone visée en
blanc, le reste en gris ; production après sa connexion Higgsfield.

---

## 5. Chantier C — le mouvement (ta question Kling / Higgsfield) : le challenge

### Ce que les gens veulent

Voir le trajet : départ, arrivée, ce qui bouge, ce qui ne doit PAS bouger.

### Où ça vit

Sur la **fiche**, dans le héros — jamais sur les cards (29 lecteurs vidéo dans
une grille en verre, c'est interdit par toutes les lois de coût de la maison).
La card garde la photo.

### Ce que Kling (via Higgsfield) sait faire, et ce qu'il ne garantit pas

- Il sait : image → vidéo de 5 s **à partir de TA photo**, style conservé (noir,
  silhouette, muscle en lumière). C'est son point fort, et le coût est faible
  (quelques dizaines de centimes par clip ; 29 exercices × 3 essais = quelques
  euros).
- Il ne garantit pas : **l'exactitude du geste**. Un coude qui plie quand il ne
  faut pas, une barre qui ondule, un muscle éclairé qui « bave » sur trois
  images. Pour une démonstration d'exercice, **un geste faux est pire qu'une
  photo** : il enseigne l'erreur. Donc un tri à l'œil, clip par clip, par toi,
  avec un budget de re-tirage (trois essais par exercice), et le droit de
  garder la photo quand rien ne passe.
- Ton propre verdict du 20-09 (« en vidéo c'est cheap ») visait le brillant de
  la carte légendaire, pas une démonstration : ici la vidéo est du CONTENU, pas
  une décoration. Mais la même exigence tient — au premier membre qui fond, on
  coupe.

### La recette qui réduit le risque (dérivée par script, comme la légendaire)

1. **Ne générer que la moitié du geste** — la montée, 2 à 2,5 s. Moins de
   temps généré = moins d'hallucination.
2. **Ping-pong par script** (ta recette de `start-entrainement-loop`,
   `tools/exos-v2/recuit_fond_exos.sh` pour le recuit) : la descente est la
   montée à l'envers. Un exercice EST un aller-retour → une boucle parfaite,
   sans couture, gratuite.
3. **Recuit** : 720 px de large au plus, H.264, muet, 0,6 à 1 Mo par exercice →
   29 exercices ≈ 25 Mo dans l'app. Acceptable ; à surveiller pour 50.
4. **Un prompt fixe pour tous** (« slow controlled repetition, camera locked,
   pure black background, the lit muscle stays lit, no morphing »), aucune
   consigne par exercice. Ce qui ne tient pas au prompt commun retourne à la
   photo.

### La chauffe (la loi de la maison)

- Une couche `AVPlayerLayer` ne coûte presque rien (décodage matériel) — mais la
  fiche porte déjà des shaders et jusqu'à trois lecteurs (constaté
  `ExerciseDetailView.swift:3124`). Donc : **jamais sous un verre**, en pause dès
  que le header se replie ou que la page est couverte (le rideau),
  `AVPlayerLooper` retenu et libéré au `onDisappear`, photo si « Réduire les
  animations » ou protection thermique.
- **Barreau `-sansFilmExo` obligatoire**, mesure sur TON iPhone, thermique 0,
  ABBA, la paire (img, cpu) fiche-photo vs fiche-film. Sans ce chiffre, le film
  ne se pose pas.

### Le « schéma » — l'alternative que je te challenge de garder

Deux poses (départ, arrivée) et une flèche fine : lisible en une demi-seconde,
zéro chauffe, et **plus pédagogique pour la forme** que cinq secondes qui
bougent. Il se dérive du même film (première et dernière image) → un seul
pipeline. Ma proposition : **le schéma par défaut sur la fiche, le film au
tap** — ou l'inverse, à trancher sur le simulateur, pas sur le papier.

### Le pilote

Trois exercices : Crunch au sol (simple), Tirage vers soi (poulie,
trajectoire), Squat à la barre (complexe). Trois tirages chacun, tri par toi sur
une planche avec crops ×3 **et** le film sur le simulateur à la taille de la
fiche, puis la mesure iPhone. Verdict → les 29, puis les suivants. Une journée,
après ta connexion Higgsfield.

---

## 6. Ce que je te challenge, sur le fond

1. **La molette n'est plus l'entrée, elle devient le raccourci.** On la garde,
   mais elle n'est plus le seul chemin — et c'est ce qui la rendra enfin aimable.
2. **Le mur des 29 disparaît.** On choisit une zone d'abord ; la recherche pour
   le reste. Avec 50 exercices demain, une molette à neuf crans serait
   injouable ; un accueil à huit tuiles, non.
3. **La fin d'exercice est un carrefour, pas une question.** Trois sorties
   visibles, toujours les mêmes, au même endroit.
4. **Le mouvement, oui — trié et montré à la taille de la fiche.** Un geste
   faux n'est pas montrable ; le schéma fait souvent mieux.
5. **Un seul système d'icônes** pour les zones de l'accueil et, demain, les
   « Muscles ciblés » de la fiche.
6. **L'IA de programme vivra dans le carrefour** — « Suivant : X ». On pose le
   carrefour aujourd'hui, l'IA le remplira.

---

## 7. Higgsfield — l'état au 21-09

- CLI installé : `~/.npm-global/bin/higgsfield` (1.1.26 ; `/usr/local` est à
  root, pas de sudo ici → préfixe utilisateur, `PATH` ajouté dans `~/.zshrc`).
- Skill posé, au projet : `.claude/skills/higgsfield-generate` (le seul des huit
  qui serve ici — images, image → vidéo, Seedance 2.5 par défaut, Kling au
  choix de modèle). Les sept autres (marque, e-commerce, sites, miniatures
  YouTube, explainers, Soul ID) n'ont rien à faire dans Nosfy ; une commande
  les ajoute si besoin.
- **Connexion NON faite** : `higgsfield auth login` a ouvert la page de
  connexion et coupé au bout du délai, personne devant le navigateur. À refaire
  par Kathryn dans un terminal (nouvelle fenêtre, le PATH y est) :
  `higgsfield auth login`, valider dans le navigateur, puis
  `higgsfield workspace list` et `higgsfield workspace set <id>`.
- Rien n'a été généré, rien n'a été dépensé.

---

## 8. Décisions à prendre (oui / non)

| | Question | Si oui | Si non |
|---|---|---|---|
| D0 | Le banc codé ce matin **reste dans l'arbre** (pour juger la mise en page) ? | il attend les carrés anatomiques, rien d'autre n'y bouge | je le retire en une commande, le plan seul reste |
| D1 | Forme des cards : **rangées** (icône · nom · pilule, la référence) ? | l'accueil = 5 rangées | tuiles 2 × 2 + Cardio en large |
| D2 | Le corps de référence des icônes : **généré** (Higgsfield, après ta connexion) ? | je génère UN corps, tu le valides, le script cuit les cinq carrés | tu me donnes une planche anatomique sous licence, le script fait le reste |
| D3 | **Le mur des 29 disparaît** (« Tout » = l'accueil) ? | recherche et molette pour tout voir | une sixième card « Tous les exercices », qui tombe dans le lit de la molette |
| D4 | **Carrefour A** tout de suite (trois sorties) ? | une demi-journée, `-serieFin` | on garde « Recommencer / Terminé » |
| D5 | Le tuto du départ dit **« Choisissez une zone »** ? | la brume éclaire la première card de zone | il garde « Choisissez un exercice » sur une card de zone (incohérent) |
| D7 | **Le tableau de séance** devient la maison de la séance, avec une séance du jour PROPOSÉE (§ 4 bis) ? | on repense le flow autour du tableau ; accueil et carrefour en deviennent des pièces | on garde « bibliothèque d'abord » et on pose seulement A + le carrefour |
| D6 | **Pilote film** sur trois exercices ? | après ta connexion : 9 clips, planche, mesure iPhone | la photo reste ; on documente le schéma comme piste |

---

## 9. Ordre proposé

1. **D'abord ton verdict** sur ce plan (D0-D6) — rien ne bouge avant.
1 bis. **Les carrés anatomiques** : le corps de référence (D2), le script, les
   cinq assets → le banc les reçoit ; captures dans `tools/exos-accueil/captures/`.
2. **Carrefour A** (une demi-journée) — montré au banc `-serieFin`.
4. **Pilote film** sur trois exercices → planche + mesure iPhone → décision.
5. Le site de doc à chaque pas : `b-flow-exos-accueil`, `b-flow-carrefour-fin-exo`,
   `b-flow-film-exo` — l'état vérifié, jamais l'intention.

---

## 10. Vérifié / non vérifié

**Vérifié (lu dans le code, `fichier:ligne` ci-dessus)** : le filtre et la
molette partagent le même état ; le sous-titre des zones existe ; « Terminé » ne
fait rien d'autre qu'enregistrer ; le panneau de fin s'ouvre par un booléen ;
l'ancre du tuto est posée sur la première carte ; 29 exercices dans cinq zones ;
le lit de la molette fait 210 pt.

**Non vérifié** : ce que la pastille (dalle) ouvre au tap sur la page Exercices
(non relu ici) ; le coût iPhone de cinq verres de plus (à mesurer) ; la qualité
de Kling sur des silhouettes (aucun clip généré) ; la hauteur exacte du slot de
la card sur iPhone 15 (≈ 771 pt, estimée sur la capture `l1-exos-liste.png`
— à confirmer avec `-exosSonde`).
