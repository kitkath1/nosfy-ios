# LE PLAN DE LA FLUIDITÉ — « ça bug encore à cause du ruban, rien n'est fluide au global »

> Verdict Kathryn, iPhone 15, 05-09. Son verdict prime sur toute mesure simulateur.
> Rien n'a été modifié pour écrire ce document : lecture seule, chaque cause porte
> un `fichier:ligne` lu et sa condition de montage.
> A/B simulateur du jour (`-sansBord` 5 img/s allumé contre 8 éteint) : **les deux
> effondrés — l'instrument ne vaut rien** (`tools/home-v2/CHAUFFE-HOME.md` §0), et
> cet écart ne disculpe pas le ruban.

---

## 1. CE QUI SE PASSE

1. Ce n'est pas UNE chose qui rame : **six moteurs tournent en même temps sur la
   home immobile**, et dix pendant une séance. Aucun ne s'arrête jamais tout seul.
2. Le ruban rouge est bien coupable — c'est le plus gros consommateur d'une séance
   — **mais il n'est pas le plus rapide** : le galet du chemin bat plus vite que lui.
3. **Le plus rapide de tous tourne au repos** : le galet d'aujourd'hui, dans la card
   du chemin, respire à la cadence de l'écran (60 fois par seconde), avec un shader,
   deux flous et un halo, alors que son souffle dure plusieurs secondes.
4. **Rien ne dort quand on ne le regarde pas** : quitter la home ne l'éteint pas,
   et le grand player plein écran ne coupe rien de ce qui est derrière lui — les
   vidéos, le ruban et les horloges continuent à peindre sous une page opaque.
5. Le mécanisme d'extinction existe déjà, il est écrit et câblé partout — **personne
   ne tire la corde** (une ligne manquante à l'ouverture du player).
6. Donc : on éteint d'abord ce qui ne se voit pas (aucun changement d'allure), et on
   ne touche à l'apparence du ruban qu'après, avec ton accord.

---

## 2. LES BARREAUX — COMMENT ON VA MESURER

**La seule preuve, c'est ton téléphone.** Un seul moteur éteint à la fois, deux
minutes, main sur le dos de l'appareil. Deux drapeaux ensemble ne disent pas lequel
comptait.

Le geste (arguments **après `--`**, sinon devicectl les avale) :

```
xcrun devicectl device process launch --terminate-existing \
  --device 022244AD-484B-5489-A884-6B781A82E372 fr.kathryn.woop \
  -- -skipAuth            # ← la référence, sans drapeau
… -- -skipAuth -sansGalet # ← puis UN SEUL drapeau à la fois
```

Et **deux régimes à chaque essai**, parce qu'elle dit « au global », pas « en
séance » : (A) home immobile, aucune séance ; (B) séance ouverte, deux minutes,
en passant d'un onglet à l'autre.

### 2.1 Ceux qui EXISTENT DÉJÀ (rien à coder, jouables ce soir)

- **`-sansGalet`** — `CardRoute.swift:252` → `GaletEtape.figee` (`CardRoute.swift:581`).
  Éteint l'horloge à cadence libre du galet actif.
  *Question : le galet du chemin est-il l'horloge la plus chère de la home AU REPOS ?*
  ⚠️ Il n'a jamais été joué **au repos** — seulement pensé comme un suspect de séance.
- **`-sansPiece`** — `CoffreFortCoin.swift:50` → `MoonCoinView(figee:)`
  (`MoonCoinLab.swift:117`). Éteint la pièce du trésor (30 Hz + lecture du gyroscope).
  *Question : le coût que le simulateur ne peut PAS voir (le gyro y est mort) est-il là ?*
- **`-sansBord`** — `BordSeance.swift:39`. Éteint le ruban entier.
  *Question : combien pèse le ruban, tout compris ?* (Relevé 03-09 : « un peu retombée,
  mais ça chauffe quand même » → il pèse, il n'est pas seul.)
- **`-sansInvite`** — `HomeNuit.swift:2257`. Éteint l'invite « pull to start ».
  *Question : reste-t-il quelque chose du côté du bas de la home au repos ?*
  (Faible a priori : les deux invites sont déjà démontées en séance,
  `HomeNuit.swift:3543` et `:3568` — `if !enSeance`.)

### 2.2 Ceux à AJOUTER, par ordre d'utilité

- **`-tickSonde`** — *ce n'est pas un extincteur, c'est LE juge du litige central.*
  Un compteur de ticks par étiquette, imprimé toutes les 10 s, posé dans le corps de
  chaque `TimelineView` suspecte (`HomeNuit.swift:209`, `ExercisesView.swift:2284`,
  `BordSeance.swift:70`). *Question : **une horloge d'onglet caché tique-t-elle ?***
  Toute la moitié « onglets cachés » du plan dépend de cette réponse, et le dépôt la
  déclare non mesurée depuis le 03-09 (`tools/nav/ANALYSE-CHAUFFE-GESTES.md:91`).
  À jouer en premier : il oriente les gestes 2, 7 et 8.
- **`-bordPlat`** — garde le ruban et ses trois `strokeBorder`, retire les trois
  `.blur` (`BordSeance.swift:101`, `:105`, `:109`), le `.mask` (`:112`) et le
  `.blendMode(.plusLighter)` (`:121`). *Question : est-ce le RUBAN qui coûte, ou ses
  cinq passes plein cadre ?* C'est le seul A/B que `-sansBord` ne sait pas faire.
- **`-bordVisible`** — garde `BordSeance` mais le passe en
  `actif: enSeance && !ongletCache` à `PageCard.swift:270` (l'environnement est déjà
  lu ligne 64, il ne sert qu'au registre de nav). *Question : combien de rubans
  tournent vraiment en séance — un, deux, trois ?*
- **`-playerCouvre`** — arme `PlayerEtat.shared.couvre = true` dans
  `ouvrirGrandPlayer()` (`WoopApp.swift:1057-1062`) et le désarme au retour à 0
  (`WoopApp.swift:1270`). *Question : que coûte tout ce qui peint sous un plein écran
  opaque ?* Les cinq lecteurs existent déjà (`DepartCine.swift:692` et `:722`,
  `ExosFond.swift:204`, `WorkoutPill.swift:491`, `ProgressPage.swift:202`).
- **`-sansRasant`** — force `paused: true` sur `HomeNuit.swift:209-210`. Éteint le
  shader **plein écran** du fond de la home (30 Hz). *Question : le plus gros
  remplissage permanent de l'app est-il celui-là ?*
- **`-sansMolette`** — met en pause les deux horloges permanentes d'Exercices :
  `ExercisesView.swift:2284` (liseré de la molette, 30 Hz, aucun `paused:`) et
  `ExercisesView.swift:1539` (`BraiseEcriture`, **60 Hz + `Canvas`**, aucun `paused:`,
  montée en permanence sous le champ de recherche, `ExercisesView.swift:1445`).
  *Question : la page Exercices porte-t-elle sa propre chauffe, indépendante du ruban ?*
- **`-sansVieuxPlayer`** — ne monte pas `PlayerMondeHote` (`WoopApp.swift:1424`).
  *Question : l'ancien player, monté toute la séance une hauteur d'écran plus bas,
  coûte-t-il encore quelque chose ?*

### 2.3 L'ORDRE DES ESSAIS

1. **Référence** (aucun drapeau), régimes A et B. On note la chaleur, pas un chiffre.
2. **`-tickSonde`** — tranche le litige des onglets cachés. Il commande la suite.
3. **`-sansGalet`**, régime A d'abord (jamais fait), puis B.
4. **`-sansPiece`**, régime A — le suspect invisible au simulateur.
5. **`-sansRasant`**, régime A — la plus grande surface.
6. **`-sansBord`** puis **`-bordPlat`**, régime B — sépare le ruban de ses passes.
7. **`-bordVisible`**, régime B avec bascules d'onglets — sépare le ruban de ses copies.
8. **`-playerCouvre`**, régime B avec le grand player ouvert 2 min.
9. **`-sansMolette`**, régime A sur Exercices.
10. **`-sansVieuxPlayer`**, régime B.

⚠️ `./tools/charge.sh` n'est utile que pour le simulateur ; sur le téléphone, la
règle est : même charge de batterie, même luminosité, appareil froid au départ.
`-fps` (`SondeCadence.swift:93`) ne voit que le **fil principal** — pas la chaleur GPU.

---

## 3. L'ORDRE DES GESTES

### 1. Le galet actif : lui donner un intervalle et une porte de sommeil

- **Où** : `GaletEtape.swift:246` (`minimumInterval: nil`) et `:419-430` (`pauseTimeline`).
- **Quoi** : `minimumInterval: 1.0/15.0` ; ajouter `homeDort` et `\.ongletCache` à
  `pauseTimeline`. Optionnel : remplacer le `.blendMode(.plusLighter)` du halo
  (`:517`) par une opacité simple — sur du noir, additif ≈ normal.
- **Gain attendu** : l'horloge la plus rapide de l'app au repos passe de 60 à 15 Hz,
  ×1 à ×3 galets (l'actif, la lune et la pièce disponibles ne sont jamais pausés,
  `:423-424`) ; trois passes hors écran par image en moins, plus le rendu hors écran
  de toute la bande qu'elles forcent sous le `.mask` de `CardRoute.swift:515`.
- **Risque** : aucun connu. C'est exactement l'argument déjà appliqué à la pilule
  (`PiluleVagabonde.swift:657-660` : « 15 Hz, PAS 30 … un cycle sur deux de rendu qui
  disparaît »).
- **Allure** : **NON** — un souffle de plusieurs secondes est identique à 15 Hz.

### 2. Faire dormir ce qui est caché (si `-tickSonde` dit que ça tique)

- **Où** : les cinq horloges de la home lisent `DepartEtat.shared.homeDort` en direct
  (`HomeNuit.swift:210`, `:4680`, `:4816`, `:4854`, `:4932`) et **jamais** l'onglet ;
  `ExercisesView.swift` et `ProfilLune.swift` ne contiennent **aucune** occurrence de
  `ongletCache` ; le châssis pose pourtant l'environnement sur les trois onglets
  (`WoopApp.swift:1180`, `:1189`, `:1201`).
- **Quoi** : `@Environment(\.ongletCache)` lu par ces vues, composé dans leur `paused:`.
  `\.dort` (`WoopApp.swift:1228`) contient déjà `selection != .home` mais n'a **qu'un
  seul lecteur**, les calques vidéo (`DepartCine.swift:692`/`:722`) — le châssis le dit
  lui-même : « les endormir sous un onglet caché est l'item 7, **NON fait** »
  (`WoopApp.swift:1224-1227`).
- **Gain attendu** : jusqu'à ×2-3 sur tout ce qui n'est pas regardé. Conditionnel au
  barreau `-tickSonde` : si les horloges cachées ne tiquent pas, le gain est nul et il
  ne faut PAS écrire ce code.
- **Risque** : une horloge qui ne redémarre pas au retour d'onglet (à vérifier au doigt).
- **Allure** : **NON**.

### 3. Le grand player doit éteindre ce qu'il couvre — une ligne

- **Où** : `WoopApp.swift:1057-1062`. `ouvrirGrandPlayer()` n'écrit que `morphPlayer = 1`.
- **Quoi** : `PlayerEtat.shared.couvre = true` à l'ouverture, `= false` là où
  `morphPlayer` retombe (`WoopApp.swift:1270`, et `fermer()` de
  `PiluleVagabonde.swift:1611`).
- **Gain attendu** : sous un plein écran opaque, deux calques vidéo de la home
  s'arrêtent (`DepartCine.swift:692`, `:722`), le fond vidéo d'Exercices aussi
  (`ExosFond.swift:204`). Zéro nouvelle porte à écrire.
- **Risque** : un calque vidéo qui ne repart pas à la fermeture — le chemin `dort`
  fait déjà ce va-et-vient, mais à fouetter.
- **Allure** : **NON** (rien de visible n'est modifié — c'est sous une page opaque).

### 4. Le ruban : retirer les cinq passes plein cadre

- **Où** : `BordSeance.swift:101` (`.blur` 14), `:105` (4), `:109` (1,2), `:112`
  (`.mask`), `:121` (`.blendMode(.plusLighter)`), hôte = la page entière
  (`PageCard.swift:270`, posé avant le `clipShape` `:271`).
- **Quoi** : ce que l'en-tête du fichier promet déjà mot pour mot (`:13-18` :
  « **AUCUN `.blur`, AUCUN `Canvas`** … du pur vecteur ») — la douceur par les stops
  de l'`AngularGradient` (`:157-172`) plus une passe de `strokeBorder` de plus, le
  fondu du haut cuit en 4ᵉ stop d'opacité au lieu du `.mask`, et le `plusLighter`
  tombe avec eux (sur du noir, additif ≈ normal).
- **Gain attendu** : cinq rendus hors écran de ~393 × 759 pt à 20 Hz qui disparaissent
  — et avec eux la re-capture forcée de tout ce qui est peint dessous (vidéo, verres
  natifs, shaders des galets).
- **Risque, et il est réel** : **cinq essais ont déjà échoué** sur ce contour
  (`tools/home-v2/ANALYSE-HOME-VIVANTE.md:265-296` — même un shader d'UNE passe a
  lagué). C'est l'argument fort pour dire que le coût est l'**invalidation**, pas le
  dessin ; le barreau `-bordPlat` doit trancher **avant** qu'on écrive ce code.
- **Allure** : **OUI, elle doit trancher.** Sans les flous, la braise sera plus nette,
  moins « nappe ». La version validée (« j'aime bien l'épaisseur ») est celle d'AUJOURD'HUI.
  Repli si elle refuse : la **nappe cuite** (un calque pré-flouté statique dont on
  n'anime que la `rotationEffect` — rendu identique, zéro re-raster), cible déjà
  écrite dans `tools/home-v2/ANALYSE-RUBAN-SEANCE.md`.

### 5. Le ruban : une seule instance

- **Où** : `PageCard.swift:270` — `.overlay { BordSeance(actif: enSeance || BordSeance.banc) }`,
  dans le corps de **chaque** PageCard (home `HomeNuit.swift:2360-2362`, `enSeance`
  défini `:1938` ; liste `ExercisesView.swift:475-477`, `enSeance` `:134` ; fiche
  `ExerciseDetailView.swift:611-613`, `enSeance: active != nil`) ; `BordSeance.swift:41`
  n'a **aucun** `@Environment` de visibilité.
- **Quoi** : à court terme `actif: enSeance && !ongletCache` ; à terme, **une** instance
  au châssis, comme son propre en-tête l'exige (`BordSeance.swift:8` : « IL VIT AU
  CHÂSSIS, PAS DANS LA HOME »).
- **Gain attendu** : borné. La copie de la fiche poussée est documentée **détachée**
  (`PageCard.swift:192-204`, `onDisappear`) ; le ×N des onglets cachés est déclaré
  réfuté par la relecture adverse (`tools/nav/ANALYSE-CHAUFFE-GESTES.md:104`). Reste
  certain : les ~0,3 s de transition où deux hôtes coexistent — c'est exactement le
  moment où elle dit « quand je passe d'une page à l'autre, ça met du temps ».
- **Risque** : passer le ruban au châssis a déjà échoué **visuellement** le 03-09 (il
  débordait dans la bande noire sous la card) ; la géométrie est à refaire.
- **Allure** : **NON** pour la garde `ongletCache` ; **OUI (à surveiller)** pour le
  déménagement au châssis (c'est le débord qui avait fait annuler).

### 6. La fermeture du grand player : sortir le doigt du corps

- **Où** : `PiluleVagabonde.swift:1578` (`fermeture = v.translation.height`) ; lu six
  fois dans le corps : `:1367`, `:1368`, `:1377`, `:1398`, `:1414`, `:1426`.
- **Quoi** : le patron existe **deux fois** dans le dépôt et n'a pas été appliqué ici —
  `OffsetVol` (`PlayerMonde.swift:919`) et `DessinPilule`
  (`PiluleVagabonde.swift:470-476`) : un `ViewModifier` qui SEUL relit l'offset. Plus :
  figer `rayon` (`:1377`) — un rayon de coin qui change par image, c'est un masque
  plein écran neuf à chaque image (`:1398`) — et rendre le `.mask` de `:1401`
  conditionnel (`@ViewBuilder`) au lieu d'un ternaire qui laisse toujours un
  `Rectangle()` en style `.glisse`.
- **Gain attendu** : le geste le plus fréquent du player cesse de reconstruire
  `teteFixe` + `partition` + `piedExercices` à chaque événement de doigt.
- **Risque** : faible. Les braises sont déjà gelées pendant le geste (`:1386`) et la
  partition est déjà `.equatable()` (`:1498-1503`) — le gain est donc plus petit
  qu'annoncé, mais le mécanisme est le piège n°1 du dépôt, mot pour mot.
- **Allure** : **quasi NON** — seul le coin qui s'arrondit pendant le drag disparaît.

### 7. Exercices : deux horloges permanentes, aucune porte

- **Où** : `ExercisesView.swift:2284` (liseré de la molette, 30 Hz, aucun `paused:`,
  monté en permanence via `ArcDial` `:722`) et `ExercisesView.swift:1539`
  (`BraiseEcriture`, **60 Hz + `Canvas`**, aucun `paused:`, monté en permanence sous
  le champ de recherche `:1442-1447`) ; juste à côté, un
  `glassEffect(.regular…interactive())` (`:2258-2260`).
- **Quoi** : la braise d'écriture ne vit qu'à la frappe (`gel`/`frappe`) — la pauser
  dès que son âge dépasse sa traîne ; la molette à 15 Hz et pausée sous `ongletCache`.
- **Gain attendu** : un `Canvas` 60 Hz permanent sur une page immersive, c'est du
  remplissage pur pour un effet qui ne dure qu'une demi-seconde après une touche.
- **Risque** : la braise qui ne repart pas à la frappe suivante (à fouetter au doigt).
- **Allure** : **NON** (aucun pixel ne change au repos ; le liseré de la molette
  respire pareil à 15 Hz).

### 8. Profil : cinq horloges sans pause

- **Où** : `ProfilLune.swift:1238` (20 Hz), `:1420` (30 Hz, le géant SceneKit),
  `:1504` (30 Hz), `:1929` (20 Hz), `:2032` (shader plein largeur, 30 Hz) — **aucune**
  n'a de `paused:`, et le fichier ne lit **jamais** `ongletCache`.
- **Quoi** : composer `ongletCache` dans les cinq `paused:`.
- **Gain attendu** : conditionnel au même barreau `-tickSonde` que le geste 2. Le
  SceneKit, lui, a déjà une porte de scroll (`:1144`, `:1161`) et un « enterré »
  persisté (`:1109`) — si elle a enterré le sachet, il n'est jamais monté.
- **Risque** : faible.
- **Allure** : **NON**.

### 9. La pièce du trésor : une porte, comme les autres

- **Où** : `HomeNuit.swift:3615` — `CoffreFortCoinButton` monté **sans aucune garde**
  (ni `verreMonte`, ni `enSeance`, ni `homeDort`) ; moteur `MoonCoinLab.swift:117`
  (30 Hz) + `:123` (lecture du `tilt` d'un `@Observable`).
- **Quoi** : passer `figee: true` quand `net > 0.02` (la page fait autre chose),
  quand `homeDort`, et sous `ongletCache` — le paramètre existe déjà
  (`MoonCoinLab.swift:65` : « le rendu est IDENTIQUE au pixel, c'est du coût pur qui
  s'en va »).
- **Gain attendu** : le seul suspect dont le coût est **nul au simulateur et réel sur
  l'appareil** (le gyroscope y est mort) — profil exact du symptôme.
- **Risque** : aucun sur un état déjà posé.
- **Allure** : **NON** (au repos, la pièce est déjà immobile à l'œil).

### 10. L'ancien player, monté toute la séance

- **Où** : `WoopApp.swift:1424` (`PlayerMondeHote`, zIndex 8.5) →
  `PlayerMonde.swift:329` : `if seance != nil || etat.monte` — un arbre plein écran
  (voile + corps) monté pendant toute la séance, alors que **plus rien ne l'ouvre**
  depuis le pivot du 04-09 (les seuls écrivains de `PlayerEtat.couvre`/`monte` sont
  `PlayerMonde.swift:64`/`:172`, atteints par les bancs `-playerDoigt`/`-playerCycle`,
  et `PanBande.swift:155` dont l'hôte `NavPanHote` n'a aucun site de montage).
- **Quoi** : le monter sur `etat.monte` seul (il naîtrait alors au geste, ce que le
  commentaire `:324-328` cherchait à éviter — donc à trancher au barreau).
- **Gain attendu** : inconnu, à mesurer (`-sansVieuxPlayer`). Le fichier affirme
  « un arbre statique offscreen ne coûte rien » : c'est une affirmation, pas une sonde.
- **Risque** : casser un chemin d'ouverture résiduel.
- **Allure** : **NON**.

### 11. Le gyroscope sans consommateur

- **Où** : `DemonSky.swift:34-35` — `CMMotionManager` à 30 Hz **sur la file
  principale**, démarré par `HomeNuit.swift:196` et `:1631`, arrêté nulle part dans
  l'app vivante (`stop()` n'est appelé que par `WoopDemonSky`, qui n'est monté que
  dans les écrans d'archive : `HomeView.swift`, `HomeAuroraView.swift:425`).
- **Quoi** : compter les consommateurs, ou l'arrêter quand personne ne lit.
- **Gain attendu** : petit — 30 réveils du fil principal par seconde qui, sur la home
  vivante, n'alimentent plus que la pièce (geste 9).
- **Risque** : la parallaxe qui meurt là où on la veut (RewardCard, la pièce).
- **Allure** : **NON** tant que les lecteurs réels gardent leur alimentation.

---

## 4. CE QUI NE SE PROUVE PAS SANS LE TÉLÉPHONE

- **Les onglets cachés tiquent-ils ?** Jamais mesuré (`ANALYSE-CHAUFFE-GESTES.md:91`),
  et la relecture adverse dit non. Toute la moitié « sommeil » du plan en dépend :
  barreau `-tickSonde`, avant d'écrire une ligne.
- **Le gyroscope n'existe pas au simulateur.** La pièce (geste 9) y coûte zéro par
  construction : aucune mesure sim ne peut ni l'accuser ni l'innocenter.
- **Le ruban : dessin ou invalidation ?** Cinq refontes ont lagué, dont un shader
  d'une seule passe — la réponse n'est pas dans le code, elle est dans `-bordPlat`.
- **La part GPU / thermique.** `SondeCadence` (`SondeCadence.swift:46-59`) compte les
  battements servis au fil principal ; elle ne voit pas la chaleur GPU. Pour ça, c'est
  Instruments, ou sa main sur le dos de l'appareil — qui, elle, ne ment pas.
- **Le coût d'un verre natif au-dessus d'une vidéo vivante** (trois sur la home, un sur
  la molette) : jamais isolé, aucun interrupteur. Personne ne sait le chiffrer ici.

---

## 5. LES CAUSES ÉCARTÉES (qu'on ne rouvre pas)

- **Le `glassEffect(.regular)` de la pilule** (`PiluleVagabonde.swift:981`) : la loi du
  dépôt sur `.regular` est **esthétique** (« le givré laiteux »), aucune mesure ne dit
  qu'il coûte plus que `.clear` ; et le même patron est partout (`PageCard.swift:686`).
- **Les braises de la pilule « à 30 Hz »** : c'est le correctif **déjà livré** (c96bb67
  les a passées à 15 Hz) — le commentaire cité à charge est la trace du remède.
- **Le SceneKit du Profil « rend sur les autres onglets »** : jamais mesuré, et
  mécaniquement douteux (onglet non sélectionné ⇒ `view.window == nil`) ; le géant est
  en plus détruit à chaque Sacre (`WoopApp.swift:1164`) et « enterré » est persisté.
- **Le ruban en TROIS exemplaires** : la copie de la fiche est détachée
  (`PageCard.swift:192-204`), le ×N des onglets cachés est réfuté
  (`ANALYSE-CHAUFFE-GESTES.md:104`) — au pire ×2, et seulement en transition.
- **« Le gyroscope n'a pas de bande morte »** : FAUX pour `tilt`, elle est là
  (`DemonSky.swift:56`). Vrai pour `shake` (`:65-66`, aucun seuil) — mais son unique
  lecteur, `SemaineStrip` (`HomeNuit.swift:1725`), n'est monté que derrière le banc
  `-thisWeek` (`HomeNuit.swift:2107`, `:3441`). Cause sans site de montage vivant.
- **La fumée d'invite qui bat en séance** : déjà réparée — les deux invites sont
  démontées, pas seulement transparentes (`HomeNuit.swift:3543` et `:3568`, `if !enSeance`).
- **Le double montage du panneau de départ, les conteneurs vides à la racine, le
  `.blur` orphelin de `MenuNappe`** : gravité 2, sous le bruit de tout le reste — à
  ramasser le jour où on repasse dans ces fichiers, jamais comme un chantier.
