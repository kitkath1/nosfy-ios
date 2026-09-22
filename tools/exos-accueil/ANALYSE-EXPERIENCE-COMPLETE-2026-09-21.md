# Nosfy, toute l'expérience relue à froid — 21-09-2026

Demande de Kathryn (21-09, 10 h 40) : « Tu es sûr ? Je ne suis pas encore
convaincue. Réanalyse toute l'app et l'expérience. Ne code pas, rechallenge. »

Méthode : trois lectures parallèles du code (l'entrée, la séance, la boucle de
récompense), chacune en `fichier:ligne` ; les douze affirmations les plus
lourdes **re-vérifiées par moi dans le code** (§ 8) ; les retours réels des
testeuses des builds 81 et 82 (`tools/production/PLAN-DEBUG-TESTFLIGHT-2026-09-20.md`,
mémoire du 21-09) ; les 23 étapes QA du site (`docs/site/content/qa.ts`).
**Rien codé. Rien mesuré au doigt sur un téléphone.** Ce document dit ce que
le code fait ; il ne dit pas ce que le doigt ressent.

---

## 1. La réponse courte

**Non, l'accueil par zones n'est pas la meilleure expérience — c'est un
pansement sur le mauvais endroit.** Les utilisatrices ne sont pas perdues
parce qu'elles ne trouvent pas un exercice. Elles sont perdues parce que
**l'app ne leur dit jamais où elles en sont** : ni dans la séance, ni dans
le geste qu'on attend d'elles, ni dans ce qu'elles gagnent. Sept causes
racines, pas trente bugs. Elles sont au § 3. La proposition de fond est au § 5.

---

## 2. Le parcours réel d'une nouvelle utilisatrice, écran par écran

Ce qu'elle voit, et entre crochets **ce qu'elle doit deviner**.

1. **Splash** « lune de sang », 3,4 s, aucun texte. [qu'un toucher passe]
2. **La Porte** : quatre pages en **anglais en dur** (« Training,
   remembered. », « Pick your exercises, log every set as you go. »…) et un
   bouton **français** « Se connecter avec Apple » (`PorteEntree.swift:172-183`,
   `:660`). La langue ne se choisit qu'au 3ᵉ écran du film suivant.
   [qu'il y a quatre pages ; qu'il n'y a pas d'autre porte]
3. **Le film Nosfy** : 8 s non passables (Nietzsche), la chauve-souris, la
   langue, le prénom (obligatoire, sans « Passer »), le but, les jours, « Bien. »,
   8 s de film final non passable, puis « YOU'RE READY / Let's go, prénom /
   5 sessions a week » **en anglais dans les deux langues** — 5 en dur si les
   jours ont été passés (`NosfyOnboarding.swift:1108`).
4. **La Home** : la phrase à son prénom, une card ROUTE, deux widgets gris, une
   pièce **sans chiffre** en haut à droite (`CoffreFortCoin.swift:37-88`), un
   galet de verre en bas à gauche, trois glyphes sans libellé. Pour lancer une
   séance : **tirer la page vers le haut, puis faire glisser un slider**. Le
   seul mot qui l'enseigne : « tire pour commencer », 11 pt, blanc à 46 %
   (`HomeNuit.swift:5407`). [le tirage, le slider, le galet, le tap sur la card]
5. **La pop-up « Bienvenue »** puis **la visite** : quatre objets éclairés
   (Route, progrès, profil, pièces) — **et pas un seul geste**
   (`VisiteHome.swift:107-126`).
6. **La Route** : un serpentin de neuf pierres muettes, « CHAPITRE 1 · Le verre
   noir ». [que le galet du jour se tape] Le panneau qui s'ouvre est
   **entièrement en anglais** : « Today's session · Start · Later »
   (`DuolinguoPage.swift:1533-1547`).
7. **Le décompte** : 1-2-3-GO, passable au tap — écrit seulement pour VoiceOver
   (`FilmDepartSeance.swift:69`).
8. **Exercices** : la brume sur la première card, « Choisissez un exercice — Il
   s'ajoutera à votre séance. » Aucun « touche pour continuer », un seul temps,
   la molette jamais présentée (`VisiteExercice.swift`). Pendant ce temps la
   pastille de séance **naît dans la Dynamic Island** (`NosfyApp.swift:1685`)
   avec un chrono et un stop de 26 pt **dans le trou de l'écran**.
9. **La fiche** : photo, titre, « DERNIÈRE CHARGE », courbe, une ligne de coach,
   et un galet « Start exercise » avec deux chevrons. **La consigne du geste et
   l'erreur fréquente ne sont plus affichées en musculation**
   (`ExerciseDetailView.swift:1739`, `:3573`, seulement sous `-sansCourbe` ou
   pour la piscine). [que le galet monte **jusqu'en haut** ; qu'un lâcher trop
   tôt efface la série sans un mot, `:2953-2956`]
10. **Le monde blanc** : « Start Training », « Swipe up », trois chevrons ajoutés
    le 17-09 parce que « les users sont perdus » ; « SET 1 », 3-2-1-GO, le
    chrono, « Finish set » ; **la saisie vient après l'effort** : molettes REPS
    (12 par défaut) et WEIGHT (20 kg par défaut), « REST required », « Slide to
    start rest » — tout en anglais en dur. [qu'on note à la fin ; que le repos
    est obligatoire]
11. **Fin de série** : sept pièces volent vers la pastille — **dans la Dynamic
    Island, donc dans le trou** ; une pill « COINS EARNED · VAULT PROGRESS »
    avec une barre **sans chiffres** ; à la 3ᵉ série une pop-up « Set 3 » ; sinon
    « Encore une série ? · Recommencer · Terminé ». **« Terminé » ferme la
    pop-up et rien d'autre** (`:3162-3175` : les deux appels sont sans effet).
12. **La série suivante repart à 12 reps / 20 kg / repos à choisir**
    (`LiquidLensLab.swift:157-158`, `:1346` — l'état est démonté entre deux
    séries). Une utilisatrice à 10 × 80 kg retape tout, ou enregistre 12 × 20.
13. **Le deuxième exercice** : aucun bouton. Le chevron de la fiche, seul
    chemin (`:2217`). Le glyphe « Entraînements » de la nav est **inerte depuis
    la fiche** (`NavEncre.swift:692`). Le tuto « Il s'ajoutera à votre séance »
    ne rejoue pas. Le nombre de séries faites n'est lisible nulle part sur la
    fiche (carte des séries derrière `-carteSeries`, `:289-290`).
14. **Voir sa séance** : il faut sortir la pastille de l'île (drag ≥ 12 pt,
    `PiluleVagabonde.swift:952`), **puis** la taper — deux gestes différents, et
    le premier ne fait rien de visible. Le grand player affiche alors le nom du
    **premier** exercice de la séance, pas du courant (`NosfyApp.swift:1915`).
15. **Finir** : le médaillon STOP (pastille, île ou player) → « **Stop the
    session?** », un slider « Stop », pas de bouton Annuler (`StopCard.swift:389`,
    `:410`). L'appui long « Terminer la séance ? » **n'existe plus**
    (`JewelTabBar` jamais montée : `NosfyApp.swift:1050-1053` contre `:161` ;
    `PausePanneauHote` sans site d'appel).
16. **Après** : retour Home immédiat, puis **2 à 8 s de silence**, puis la story
    « Séance terminée » (4 pages), puis la Route s'ouvre seule et fête le galet,
    puis 3,4 s plus tard « A booster is waiting! · Drag to open · Later ». Le
    trophée de la home n'existe pas (`WoopCelebration` sans consommateur).
17. **Le lendemain** : aucune notification n'existe dans l'app (zéro
    `UNUserNotificationCenter`, entitlements = Apple seul), aucun widget
    d'écran d'accueil. Le « +10 » du Welcome Back ne se voit que si elle a
    déjà décidé d'ouvrir l'app. Sa **flamme de jours est calculée, transmise,
    stockée — et affichée nulle part** (`EconomieNosfy.swift:182-183`, aucune
    vue ne la lit).

Bilan compté : **quatorze gestes ou règles à deviner**, deux « pastilles
mortes » (le stop dans le trou de l'île, la pièce sans chiffre), trois
libellés qui promettent ce qu'ils ne font pas (« Terminé », « Bravo, tu as
terminé ton entraînement ! » après une seule série `:1342`, « Claim » qui
crédite avant que « Scratch » ne révèle `RewardChemin.swift:12-14`).

---

## 3. Les sept causes racines

**A. La séance n'a pas de forme.** Pas de tableau visible, pas de « suivant »,
pas de fin visible, pas de compte de séries, un « Terminé » vide, un ajout
d'exercice sans bouton, une nav inerte. L'ardoise (`SessionSlate`) qui devait
être ce tableau n'est montée que dans un banc (`CalLab.swift:195`) ; sa
partition survit dans le grand player, derrière deux gestes. **C'est la cause
que tu sens** (« ils ne comprennent pas qu'il faut piocher un autre exercice »).

**B. Les gestes sont la langue de l'app, et personne ne les enseigne.** Tirer
la Home, glisser le slider, monter le galet jusqu'au sommet, sortir la
pastille de l'île, taper le galet de la Route, porter le galet du menu :
six gestes inventés, aucun montré. La visite montre des objets, pas des
gestes. Chaque fois qu'une testeuse s'est perdue (17-09 « ils ne captent pas
qu'il faut le monter tout en haut »), la réponse a été **un chevron de plus**,
jamais un bouton.

**C. L'app parle deux langues dans la même minute.** Porte anglaise, film
français, Route anglaise, panneau Start français en dur
(`DepartSeance.swift:565-589`), lentille anglaise, pop-up de relance
localisée, Stop anglais, booster anglais, toasters anglais. Ce n'est pas un
détail de traduction : **une utilisatrice ne peut pas savoir si elle a
compris**, puisque la moitié des mots ne sont pas dans sa langue.

**D. La boucle de motivation est invisible.** La pièce de la Home n'a pas de
chiffre ; la flamme n'est affichée nulle part ; « 20 pièces par série » et
« 100 pièces = 1 sachet » ne sont écrits qu'à l'intérieur du coffre, page ①
(`CoffreV2.swift:2653-2659`) ; le solde **redescend** de 147 à 27 sans
transaction visible (retour TestFlight 81, retour 3b) ; aucune notification,
aucun widget. Une boucle quotidienne dont le déclencheur quotidien n'est
jamais émis n'est pas une boucle.

**E. Les récompenses disent le contraire de ce qu'elles font.** « Claim »
crédite et tire ; « Scratch » ne décide rien mais dit « Ajouté à ton solde »
pendant qu'on gratte ; la card « Training » dit « Bravo, tu as terminé ton
entraînement ! » à la première série ; les pop-ups « Set 3 / Set 5 » se
recomptent **à chaque exercice** parce que le rang vit dans la fiche
(`:3082-3088`, `:132`) ; la 2ᵉ rare est un doublon deux fois sur trois (3
rares, toutes des chauves-souris).

**F. Des morceaux morts ressemblent à des chemins.** `JewelTabBar` et son
galet play, `PausePanneau`, `SessionSlate`, `ActiveWorkoutSheet` et son
« Ajouter un exercice », `PlayerMonde`, `HomeView` et son trophée : tous
écrits, aucun monté. Le menu du galet de la Home liste « Profile · Progress ·
Exercises » pour deux destinations : **« Progress » ouvre Exercices et
« Exercises » ne fait rien** (`MenuNappe.swift:724`, `HomeNuit.swift:2094`,
`:3034`). Ce code mort coûte deux fois : il trompe les sessions qui le lisent,
et il porte des textes (« Terminer la séance ? ») qu'on croit à l'écran.

**G. La saisie perd la mémoire.** 12 reps, 20 kg, repos à rechoisir à chaque
série ; molette plafonnée à 100 kg et 50 reps (`SetEntrySheet.swift:70-73`).
Pour une app de musculation, c'est la donnée la plus chère à saisir, et elle
est jetée à chaque fois.

---

## 4. Ce que je retire de mon plan du matin

L'accueil par zones (chantier A) reste juste **comme pièce**, faux **comme
priorité** : il répare un catalogue de 29 exercices que personne n'a du mal à
lire ; il ne touche à aucune des sept causes. Le carrefour (chantier B) touche
la cause A, mais par le petit bout : il ajoute deux boutons à une pop-up au
lieu de donner une forme à la séance. Le film Kling (chantier C) est du
contenu ; il ne guérit rien tant que la consigne du geste elle-même a disparu
de la fiche (cause A, point 9).

---

## 5. La proposition de fond : une séance qu'on suit, pas qu'on compose

Cinq décisions, dans l'ordre où elles guérissent.

**1. Le tableau de séance devient la maison de la séance.** Pas une nouvelle
page : la partition qui existe déjà (`SlateListe`), montée **en plein écran,
comme page**, entre la Home et la fiche. Elle dit : ce qui est fait (exercices,
séries, pièces), l'exercice en cours, ce qui reste, et deux boutons toujours
au même endroit : **« Exercice suivant »** et **« Terminer »**. Après Play on
arrive dessus ; après chaque « Terminé » on y revient ; la fiche n'est qu'un
aller-retour. Le stop de la Dynamic Island cesse d'être le seul chemin.

**2. La séance du jour est proposée, pas construite.** Le galet du jour porte
trois à cinq exercices pré-choisis (par zone, ou la dernière séance rejouée).
Le tableau s'ouvre rempli en « à faire » ; « Suivant » ouvre la fiche du
prochain ; la bibliothèque par zones sert à **remplacer ou ajouter**. C'est
l'antichambre exacte des programmes IA : le jour où l'IA existe, elle remplit
ce tableau, rien d'autre ne change.

**3. Les trois premiers jours, un bouton là où il y a un geste.** « Commencer »
sur la Home à côté de « tire pour commencer » ; « Lancer la série » sous le
galet ; « Voir ma séance » sous la pastille. Les gestes restent pour qui les a
appris ; les boutons disparaissent au bout de trois séances (ou jamais, si les
chiffres disent qu'ils servent). Un geste inventé se mérite, il ne s'impose
pas à la première minute.

**4. La saisie se souvient.** Reps, charge et repos de la dernière série du
même exercice, préremplis ; « Terminé » dit ce qu'il a enregistré ; la
consigne du geste et l'erreur fréquente reviennent sur la fiche, au-dessus
de la courbe, en une ligne chacune.

**5. Une langue, et la boucle visible.** Toute chaîne passe par `L()` (les
sites en dur sont listés au § 2) ; la pièce de la Home porte son chiffre et
la flamme ses jours ; la règle « 20 pièces par série, 100 = un sachet » est
dite **une fois avant** la première conversion, pas après ; une notification
locale par jour (le +10, la flamme) et un widget. La Route dit son but
(« 35 séances, 5 chapitres ») une fois.

Puis, et seulement puis : l'accueil par zones avec ses carrés anatomiques,
le carrefour de fin d'exercice comme pied du tableau, le film ou le schéma du
geste sur la fiche.

---

## 6. Ce que ça coûte, et l'ordre

| | Chantier | Cause | Ordre de grandeur |
|---|---|---|---|
| 1 | Le tableau de séance en page, avec Suivant / Terminer | A, F | 3 à 4 jours (la partition existe ; la dalle et le PageCard sont sacrés, à poser explicitement) |
| 2 | La saisie qui se souvient, la consigne rendue à la fiche | G, A | 1 jour |
| 3 | Une langue partout | C | 1 à 2 jours (chaînes en dur des 12 fichiers cités) |
| 4 | Pièce chiffrée + flamme sur la Home, la règle dite une fois | D | 1 jour |
| 5 | Boutons d'apprentissage des trois premiers jours | B | 2 jours |
| 6 | Séance du jour proposée | A | 2 à 3 jours + décision de contenu |
| 7 | Notification locale + widget | D | 2 jours |
| 8 | Nettoyer le code mort qui ment (menu, JewelTabBar, PausePanneau…) | F | 1 jour |
| 9 | Accueil par zones (carrés anatomiques), carrefour, film | — | après |

Tout ça se décide avant de coder : **D7** (le tableau comme maison), **D8**
(la séance proposée), **D9** (les boutons d'apprentissage), **D10** (une seule
langue, laquelle par défaut), **D11** (notifications : oui ou non pour le
lancement).

---

## 7. Ce que les testeuses ont déjà dit, et qui va dans le même sens

- 17-09 : « les users sont perdus, ils ne captent pas qu'il faut le monter
  tout en haut » → cause B (réponse donnée : trois chevrons).
- 19-09, Margaux : « plusieurs fois le jour 19 », bouton « Review » inerte →
  causes E et F.
- 19-09, Kathryn : 149 pièces « disparues » → cause D (conversion jamais
  racontée avant).
- 19-09 : card à gratter « qui ne prend pas », reward « ouverte » si on
  quitte → cause E.
- 20-09 : « on est obligé de revenir sur la page d'accueil pour avoir les
  toasters » → cause D.
- 21-09 : « il ne comprend pas qu'il faut aller piocher un autre exercice » →
  cause A.

Six retours, six fois la même famille. Ce n'est pas un problème de
bibliothèque.

---

## 8. Vérifié par moi / lu par les lecteurs / non vérifié

**Vérifié par moi dans le code (grep, 21-09 11 h)** : `JewelTabBar` n'est
montée que sous `barreBijouVisible`, toujours faux avec trois onglets ;
`PausePanneauHote` n'a aucun site d'appel ; `SessionSlate` n'est montée que
dans `CalLab` ; `draftReps = 12` / `draftKilos = 20` ne sont jamais
réassignés ; le menu du galet a trois titres pour deux destinations ; la
flamme n'est lue par aucune vue ; « Stop the session? » est en dur ;
le garde de `NavEncre` avale le tap ; `exitRestart(false)` n'appelle que
`settleSeries` et `declencherRewardFlow` ; `DescriptionExo` n'est atteint en
muscu que sous `-sansCourbe`.

**Lu par les lecteurs, non re-vérifié** : le reste des `fichier:ligne` de ce
document. Chaque ligne est citée pour pouvoir être contredite.

**Non vérifié, et qui compte** : ce que le doigt ressent (aucun téléphone) ;
si les testeuses ont trouvé le stop dans l'île ; combien abandonnent où.
Il n'y a **aucune mesure d'usage dans l'app** (la sonde parcours ne lit que le
serveur : séances, reçus). Avant de trancher D7-D11, une chose vaut plus que
tout ce document : **regarder deux personnes utiliser l'app dix minutes sans
rien leur dire.**
