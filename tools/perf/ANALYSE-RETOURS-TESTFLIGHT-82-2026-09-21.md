# Retours TestFlight 82 — analyse avant de coder (21-09-2026)

**Ce document ne mesure rien et ne corrige rien.** Il lit le code du build 82
et les preuves déjà payées, pour dire — bug par bug — ce que le téléphone fait
vraiment quand Kathryn voit ce qu'elle décrit, ce qui est prouvé, ce qui est
seulement lu, et ce qu'il faut faire dans quel ordre. Règle de la maison :
analyser avant de coder, mesurer avant de dire « corrigé ».

## 0. Ce qu'elle teste, et ce qu'Apple dit

- **Le build 82** (envoyé le 20-09 à 14:24) est HEAD `5480775e` + l'arbre de
  13:52. Les empreintes (`tools/production/testflight-82-2026-09-20/sources.sha256`)
  prouvent que `HomeNuit.swift`, `ProfilLune.swift`, `BoosterLab.swift`,
  `RythmeEcran.swift`, `CoffreV2.swift`, `Annonces.swift`, `NotifCard.swift`,
  `DuolinguoPage.swift` du build sont **identiques** à ceux de l'arbre lus ici.
  Les deux correctifs de la home d'hier (`7f0992c8` le matin, `11150e8e`
  l'après-midi) **sont dedans** : ce qu'elle voit encore n'est pas un trou
  déjà bouché, c'est autre chose (§ 1).
- **Apple, lu le 21-09 matin** (`betaFeedbackCrashSubmissions`,
  `…ScreenshotSubmissions`) : **aucun crash sur le 82** (les deux rapports
  datent du 81, 19-09 : le HIIT). Un retour sans texte le 20-09 à 17:37 (build
  82, 4G, batterie 70 %, app ouverte depuis 9 min 50) : la page Profil avec
  **Nosfy pendu visible**, la collection à 0/5, et une carte orange en plein
  vol vers sa rangée. À lui demander ce qu'elle voulait montrer.
- **Rien du build 82 n'a été mesuré à la sonde** : la dernière Release sondée
  est la 76 (18-09 matin). Tout ce qui a été posé depuis — couvertures des
  covers, projecteur du coffre, correctif 78 du Profil, Profil refait, home du
  20-09, cinématique du galet — est « compilé, non mesuré ». Ce que ce document
  dit du coût est **lu**, pas chiffré.

## 1. « La home : un blur qui dure longtemps, et pas très fluide »

### Ce qu'elle voit, traduit

Deux familles possibles, que ses mots ne séparent pas encore :

1. **Les mots de la phrase qui se refloutent et reviennent nets, un par un,
   pendant 3 à 4 secondes** — après un retour du coffre, de la Route, de la
   fiche, du manège, ou après « Later » sur Welcome Back.
2. **La page qui reste floue pendant ou après un tirage** (les widgets, la
   card Route, la phrase), avec des images qui sautent.

### Ce que le code fait (lu, contredit, retenu)

**H1 — la phrase rejoue son entrée floue à CHAQUE retour de cover**
(`HomeNuit.swift:604-608`, `RythmeEcran.swift:163-166`, `ParoleLigne.swift:46-79`).
Le correctif du 20-09 devait faire « ne plus rejouer au retour d'une page
interne » (son mot). Il a déplacé la porte de la phrase sur `dortHome` — or
depuis le 18-09, `dortHome` devient vrai sous le coffre, la Route, la fiche et
le manège (les « couvertures »). Donc : le cover s'ouvre → la phrase se croit
partie ; le cover se ferme → elle se croit « arrivée » → nouvelle phrase, et
chaque mot repart d'un flou de 12 pt vers le net en 1,05 s, décalé mot par mot :
**2,5 à 4 s de flou animé** sur la home, exactement ce qu'elle a dit le 19-09
(« au retour du coffre, le temps que le texte s'anime, ça fait beuggé »).
Aucune porte thermique ne le coupe (`ParoleLigne.swift:22-25` ne lit pas la
protection). Retenu 3/3 par les contradicteurs. **C'est la cause la plus
probable du « blur qui dure longtemps ».** Précision des contradicteurs : le
manège renvoie sur le Profil, donc le rejeu ne vient qu'au prochain tap sur
Home ; et l'arrivée sur l'onglet est, elle, voulue (E60).

**H2 — au lancement avec Welcome Back, deux flous à la suite.** La phrase joue
son arrivée (flou 30 pt, 1,46 s) derrière la card, puis « Later » la fait
rejouer mot par mot. **Écarté** par deux contradicteurs : la card ne s'ouvre pas
pendant l'arrivée (`Compte.proposerWelcomeBack` attend), l'enchaînement décrit
n'a pas lieu. Reste vrai : Welcome Back n'est pas un cover (§ 4).

**H3 — sous le doigt, trois flous restent vivants** (`HomeNuit.swift:3461,
3613-3614, 3657, 3822, 4018`) : les glyphes de la phrase (3,5 pt), le bloc
phrase (jusqu'à 6 pt après 40 pt de course), la card Route en verre natif
(6 pt pendant ses 63 premiers points) et la pièce. Le correctif du 26-08 n'a
coupé que le flou des deux widgets. Un flou dont le rayon change n'est jamais
mis en cache. Retenu 3/3, gravité **moyenne/mineure** : borné par la bisection
du 26-08 (semaine et pièce négligeables alors), non remesuré depuis que la card
Route a du verre et un contenu vivant.

**HF-2 — dès le premier point de tirage, TOUTE la page est ré-évaluée à chaque
image** (`HomeNuit.swift:4127-4258` : `tirage`, `scroll`, `eGele` sont des
états de la page entière), et pendant les 68 premiers points les verres natifs
restent montés sur la vidéo vivante. Retenu (1 vote, majeure). C'est le
« dès que je frôle » du 20-09.

**H4 — au lâcher, tous les rayons sont animés 0,26 à 1,25 s.** Rectifié par les
contradicteurs : seule la fermeture avec scène (`fermer()`, 0,375-1,25 s)
tourne à 60 Hz ; `reposer()` (0,26 s) n'anime que 2-3 flous sans horloge. **Une
partie du « blur qui dure » est voulue** : `dureeFermeture` = 1,25 s choisie
parce qu'à 0,72 s « on ne voyait plus le flou » (`HomeNuit.swift:2435-2437`).
Sur téléphone bridé, une rampe de 0,26 s finit bien à 0,26 s à l'horloge murale ;
ce qui « dure », c'est une image floue prise au milieu de la rampe et laissée à
l'écran par un trou de 0,3 à 1,7 s (le gel documenté, § 4).

**H5 — le film de départ empile 3-4 familles de flous à rayon animé sous une
TimelineView 60 Hz** pendant 1,62 s à l'aller et jusqu'à 1,25 s au retour
(`HomeNuit.swift:3012-3014, 3513, 3595, 3657`). Retenu 3/3, moyen : c'est le
flou **nominal**, jamais mesuré ni à froid ni à chaud, et ce n'est pas la charge
continue qui mène à thermique 2.

**HF-1 — au repos, deux vidéos en boucle sous trois verres natifs**
(`DepartCine.swift:706-745`, `WidgetsCards.swift:317-322, 481-484`) : le verre
refait son flou à chaque image vidéo (24/s). Retenu 3/3 avec deux
rectifications : (a) **la porte thermique existe** : dès thermique 1 (« fair »),
`verreHome` retire le verre (`PageCard.swift:743-757`) et la vidéo passe à
rate 0 (`DepartCine.swift:591-593`) ; (b) ce n'est pas « le seul moteur » — le
mobilier garde 11 points de CPU vidéos figées et verre éteint (banc 23). À
froid, c'est le moteur permanent que la sonde CPU ne peut structurellement pas
voir. H6 (même mécanisme, formulé « c'est la charge qui mène à thermique 2 ») a
été **écarté** pour cette surestimation.

**H7 / HF-5 — sous le coffre ouvert depuis la home, les deux vidéos continuent
de décoder** : l'environnement `\.dort` du châssis (`NosfyApp.swift:1607-1608`)
ne lit pas `RythmeEcran.couvert` — le fichier le dit lui-même : « item 7, NON
fait ». Retenu 2/3, **mineur** (décodage matériel hors fenêtre, coupé à
thermique 1). Sous la Route, `homeDort` fait dormir ; sous le manège, le TabView
est démonté.

**HF-6 — Welcome Back n'est pas un cover** (`NosfyApp.swift:2020-2031`, sans
`.couvreLaHome()`) : la home vit entière dessous (vidéos, verres, barres) sous
une card en verre `.regular` avec quatre horloges 30/60 Hz sans porte thermique
(`RewardCard.swift:326-331, 611-612, 1096, 1233, 1379`), et son ouverture
démarre le gyroscope (§ 5, AR-02). Depuis `5480775e`, « Later » la fait revenir
à chaque lancement : **elle est très probablement à l'écran au moment où elle
juge la home**. Non contredit (limite de session) ; montage vérifié ligne à
ligne ici.

**Ce qui a été écarté** : H2 (ci-dessus) ; H6 (surestimation) ; H9 « la card
Route respire en séance sur la home » — la card Route n'est **pas** montée en
séance dans le build 82 (`HomeNuit.swift:3137-3142` : `foyerEnSeance()`), et la
Home noire est mesurée à 3 % CPU (E62).

**Ce qui n'explique toujours pas** : le retour du 19-09 « quand je tire vers le
bas, tout l'iPhone bug, je suis bloquée » (`m-home-tirer-bloque`) — aucun chemin
lu ne bloque le fil principal ; seul le gel GPU documenté (§ 4) le fait.

### La question à lui poser

**Le flou qui dure : sur les mots de la phrase après un retour (coffre, Route,
Later), ou sur toute la page pendant/après un tirage ?** Un film de 10 s
tranche entre H1 et H3/H4. Et : **le téléphone était-il chaud** (protection
visible : vidéo de fond figée, galets posés) ?

### La mesure qui tranche

Une Release locale des **mêmes sources** que le 82 (sha256 vérifiables), avec
`-sondeVol -navProbe -ecranEveille`, thermique 0 au départ, sans câble :
1. lancement → Later → chrono de la phrase (H1/H2) ; coffre ouvert/fermé × 3
   (H1) ; tirage × 10 avec ses marques (pastille) (H3/H4) ; lire `pire` et
   `gel`, **conserver les lignes gel=1** (lire-vol.py les jette : à corriger) ;
2. la même chose une fois le téléphone à thermique 2 (c'est là qu'elle vit).

### Les remèdes, dans l'ordre (rien de posé)

1. **Ne plus rejouer la phrase au retour d'un cover** : `visiteVoix` doit
   ignorer `couvert` et ne compter que le lancement, `scenePhase` et
   l'onglet — ce qu'elle a demandé le 20-09 et que le correctif n'a pas fait.
   Un fichier, dessin intact, à **montrer** au sim puis mesurer.
2. **Une porte thermique sur l'entrée mot par mot** (`ParoleLigne`) : à
   « fair », les mots se posent nets sans flou animé — le texte reste.
3. **Couper les flous vivants sous le doigt** (Route 6 pt, bloc phrase,
   pièce) comme les widgets le 26-08, derrière un barreau `-flouSousDoigt`
   pour l'A/B : à montrer (« ça se montre, ça ne se décrète pas »).
4. **Welcome Back** : poser les vidéos de la home (poster) et endormir ses
   quatre horloges à thermique ≥ 1 ; arrêter le gyroscope à sa fermeture (§ 5).
5. **`\.dort` lit `couvert`** (les vidéos dorment sous le coffre) — décision de
   conception, coût mineur, à mesurer en A/B `-fondPose` sous le coffre.

## 2. « L'app chauffe surtout quand la séance est longue »

### Ce que le code fait pendant une séance de 45 min (lu, non mesuré)

Dans le build 82, « le player » n'est ni `PlayerSeance.swift` ni
`ActiveWorkoutView.swift` : **code mort** (aucun site d'appel de production ;
`ActiveWorkoutSheet` n'est joignable que par la barre bijou, jamais montée).
La séance se joue dans l'onglet **Exercices → fiche d'exercice**, avec la
**pastille** à la racine et le **GrandPlayer** quand on la tape.

**SL-01 — la lentille de série redessine l'écran entier à 60 Hz, sans aucune
porte**, pendant chaque série ET son repos (`LiquidLensLab.swift:227-256` :
`TimelineView(.animation(1/60))` sans `paused:`, zéro lecture de `scenePhase`,
`ProtectionThermique` ou `RythmeEcran` dans le fichier ; montée `if let series
= running`, `ExerciseDetailView.swift:1150`) : un `compositingGroup` +
`layerEffect` Metal à 110 pt d'échantillonnage + `colorEffect` + Canvas + un
flou à rayon animé pendant la cinématique du sommet. **C'est le poste qui
tourne le plus longtemps d'une séance muscu, et il n'a pas de barreau.**
Vérifié ligne à ligne ici.

**G2 — aucun écran de séance ne lit l'état thermique** : 0 occurrence de
`ProtectionThermique`/`thermalState` dans `ExercisesView`, `ExerciseDetailView`,
`TapisScene`, `ExosFond`, `LiquidLensLab` (et `BoosterLab`, `Annonces`,
`NotifCard`). La protection existe (dès « fair ») mais n'endort que la Home, la
Route, le Coffre et le Profil : **quand le téléphone chauffe en séance, rien ne
se calme sur l'écran qu'elle regarde.** Vérifié.

**SL-02 / G1 — sous la fiche poussée, la page Exercices reste « affichée » pour
toutes ses portes** : sa vidéo de fond boucle à rate 1 (`ExosFond.swift:213-215`
ne lit que `ongletCache` et `PlayerEtat.couvre`), sa molette de verre natif à
20 Hz reste armée (`ExercisesView.swift:2292-2319`, `dort("exercises")` ne lit
ni la fiche ni le GrandPlayer). Supposition non mesurée : SwiftUI met peut-être
les TimelineView d'une page poussée en pause de lui-même ; il ne met **pas** un
AVPlayer en pause. À trancher par une ligne de sonde.

**SL-03 — la pastille sortie de l'île** : verre natif interactif +
`compositingGroup` + ombre 22, une invite à 20 Hz sans porte thermique tant
qu'aucun exercice n'est choisi, et la fiche pose un `.blur(5)` **permanent** sur
sa description quand la pastille est sortie (`ExerciseDetailView.swift:3621` —
le fichier écrit lui-même qu'un blur non nul force une passe hors écran à
chaque image, « pour toujours »).

**G8 — le GrandPlayer ouvert** : vague plein écran à 15 Hz, Canvas + flou 26 +
`plusLighter` (`PiluleVagabonde.swift:2040-2046`) — gated thermique et geste,
mais « la plus chère de l'app » d'après son propre commentaire ; et il ne fait
dormir ni la page Exercices ni la Home sous lui (SL-05).

**SL-08 / G9 — le tapis (cardio, HIIT)** : scène à 60 Hz plein écran pendant
toute la course, écran forcé allumé, aucune porte thermique.

**Hors de cause (vérifié)** : la Live Activity (mises à jour sur événement, le
chrono est rendu par iOS, SL-06/G14) ; la barre bijou (jamais montée, G3) ; la
Home dort correctement sous l'onglet Exercices (SL-09) ; aucune fuite de
CADisplayLink ni de timer (SL-10) ; le coach IA = un appel réseau par série,
pas une horloge (SL-07).

**Preuve existante** : aucune mesure d'une vraie séance longue depuis le 03-09
(un seul barreau joué, « ça chauffe quand même ») ; qa-18 est 🔴 depuis le
18-09 (« séance prolongée toujours ouverte »).

### La mesure qui tranche

Une balade `-sondeVol` de 30 min **dans la fiche**, séries et repos réels,
thermique 0 au départ, sans câble, lecture par tranche de 5 min de la paire
(cadence, CPU) + `therm`. Un `SondeVol.tic` dans la lentille (angle mort
aujourd'hui) et un barreau **`-sansLentille`** à créer avant — sans quoi on ne
pourra ni l'accuser ni la disculper.

### Les remèdes, dans l'ordre

1. **Un lecteur thermique dans les écrans de séance** : à « fair », la lentille
   passe à 30 Hz et pose son shader entre deux séries ; l'invite de la pastille
   et la vague du GrandPlayer se figent (la vague l'est déjà). Dessin de
   l'effort intact, repos moins cher.
2. **Un `paused:` sur la lentille pendant le repos** quand rien ne bouge à
   l'écran (le compte à rebours peut vivre par valeur animable).
3. **Couvrir la page Exercices sous la fiche** (vidéo en pose, molette
   endormie) : `dort("exercises")` lit la fiche poussée, comme les covers.
4. **Retirer le `.blur(5)` permanent** de la description quand la pastille est
   sortie (une opacité fait le même retrait).
5. Démonter `PlayerMondeHote` de la racine (code mort pré-monté toute la
   séance, SL-04) — à relire par la session Player avant de toucher.

## 3. « Ça chauffe si je tire plusieurs boosters dans le manège 3D »

### Ce que le code fait (lu ; l'arrêt est mesuré, le coût actif jamais)

**M1 — chaque tirage rebâtit un manège complet et détruit le précédent**
(`NosfyApp.swift:2065-2138`, `BoosterLab.swift:1409, 2023-2025`) : SceneKit
plein écran à **60 img/s, HDR + bloom + anticrénelage 2X**, dix clones de
sachet, sol miroir, cinq systèmes de particules, deux moteurs audio (sept
pistes en mémoire), un moteur haptique, le gyroscope. Le mesh est relu depuis
`booster.bin` à chaque fois, ~36 Mo de textures décodées sans cache. Le
démontage est **complet et mesuré** (E74/E75 : six CADisplayLink invalidés,
scène détachée, compteur de rendus stable) : **ce n'est pas une fuite, c'est le
coût plein de chaque sachet**, empilé sur un téléphone qui n'a pas refroidi.

**M2 / G12 — le manège ignore la protection thermique** : sa seule pause est
`scenePhase != .active || attenteReseau` (`BoosterLab.swift:628`) ; 0 lecture
thermique dans `BoosterLab`, `BoosterPack`, `CarteLuneLab`. À thermique 2 il
rend toujours à 60 Hz en HDR — le cas exact du cercle « bridage → gels ».
Vérifié.

**M3 — à l'étage résultat (carte révélée), trois horloges SwiftUI à 60 Hz se
superposent** sans fin automatique : le décor de l'envol (Canvas + flous), le
registre des lunes (`.blur` animé), la CarteVivante (trois shaders sur ~426 pt
+ CoreMotion 60 Hz). Tant qu'elle regarde la carte.

**M4 — entre deux tirages, l'app démonte puis remonte tout le TabView**
(`NosfyApp.swift:1547, 2495-2525` : `homeEclipsee`) et la pose sur le
**Profil**, dont le sachet géant SceneKit reprend à 30 Hz (la page mesurée la
plus chère : 39-41 % CPU à froid, E75 ; « 30 rendus/s malgré protection 1 »,
E76). Le correctif 78 (`-profilRepos`, décors posés à chaud) est dans le 82,
**jamais mesuré**. Le « repos » entre deux sachets est donc la page la plus
chère de l'app.

**M6 — le manège est un angle mort de la sonde et n'a pas de barreau** : aucun
`SondeVol.tic`, pas de `-sansManege`. Le mécanisme d'un barreau existe pourtant
(`poseAuRepos`, `setPaused`, `preferredFramesPerSecond`).

**M9 — chaque retour au coffre pour le sachet suivant rallume le Projecteur**
(3 flous plein cadre à 20 Hz, `CoffreV2.swift:835-925`), barreau
`-sansProjecteur` posé le 18-09, jamais joué.

**Preuve existante** : deux manèges d'affilée en Debug = 30-31 % CPU à
60 img/s, thermique 0 tenu **3 min** (« ce n'est pas une endurance ») ; le
Profil immobile 39-41 % ; une charge hors app (BTLEServer ~97 % d'un cœur) vue
le 18-09, non imputable ni exclue (M06).

### La question à lui poser

**Par quelle porte tire-t-elle « plusieurs » sachets** : la pill du Profil
(elle reste sur le Profil au sachet géant entre deux) ou le coffre (elle
repasse par la home et le Projecteur) ? Et **combien de temps reste-t-elle sur
la carte révélée** ?

### La mesure qui tranche

`SondeVol.tic` dans `BoosterLab`/`CarteVivante` + barreau `-sansManege` (pose
30 Hz ou image) à créer ; puis trois sachets d'affilée, thermique 0 au départ,
sans câble, trajectoire thermique lue ; puis Metal System Trace d'un manège +
un étage résultat (le GPU que la sonde ne voit pas).

### Les remèdes, dans l'ordre

1. **Le manège lit la protection** : à « fair », 30 img/s et bloom réduit ; à
   « serious », `setPaused` avec scène détachée (déjà écrit) + message
   « ton téléphone souffle » plutôt qu'un manège saccadé.
2. **L'étage résultat s'endort** quand rien ne bouge (CoreMotion en pause,
   registre posé après son arrivée) — la carte reste vivante au doigt.
3. **Ne pas remonter tout le TabView pendant le fondu de sortie** (remontage
   synchrone à 0,4 s du teardown : deux GPU en même temps) — décaler à la fin
   de la transition.
4. **Cache du mesh et des textures** entre deux tirages (aujourd'hui relus à
   chaque sachet).
5. Mesurer enfin le Profil refait et le correctif 78 à chaud.

## 4. « L'app, au global, n'est pas très fluide » — le fil commun

Trois faits lus qui relient tout :

1. **La protection thermique protège les décors, pas les écrans qu'elle
   regarde** : Home, Route, Coffre, Profil s'endorment dès « fair » ; séance,
   manège, toasters, tirage de la home n'ont **aucun** lecteur. Le téléphone
   monte donc à « serious » pendant qu'elle s'entraîne ou tire des sachets, et
   c'est **à ce cran** qu'elle revient sur la home et le profil.
2. **À « serious », le GPU est bridé et la home gèle par vagues** (6-18 img/s
   avec 2-13 % de CPU, Release sans câble, 14-09 — `BUG-CHAUFFE-GEL-HOME.md`,
   **non corrigé**, son ordre). Le build 15 saccadait aussi à froid (E02) : la
   chaleur n'explique pas tout, mais elle explique le « blur qui reste ».
3. **Deux choses tournent tout le temps sans que personne ne les arrête** :
   le gyroscope `SkyMotion` (30 réveils/s du fil principal, démarré par la
   home et par chaque card, `stop()` jamais appelé — `DemonSky.swift:31-74`,
   vérifié), et — si la clé `woop.sondeVol` était restée dans le conteneur — la
   sonde elle-même en Release (`NosfyApp.swift:83-91` sans `#if DEBUG`,
   `SondeVol.swift:47-57`), écran forcé allumé. **La capture du 20-09 17:37 ne
   montre pas la capsule noire de la sonde** : elle n'est probablement pas
   active sur son téléphone (l'app a été désinstallée avant le 82) — à
   confirmer d'un mot.

**Vérifié hors de cause** : la barre bijou (jamais montée), la nav du bas (pas
de moteur), les services (aucun polling ; une rafale au lancement et à chaque
retour au premier plan, § 5), `isIdleTimerDisabled` (posé par le tapis
seulement, § 5 pour le trou).

## 5. « Quand je me balade énormément et fais plein d'allers-retours, ça
chauffe »

Ce qui s'accumule ou se répète (lu ; rien mesuré) :

- **AR-02 — le gyroscope jamais arrêté** (ci-dessus) : coût **constant**, pas
  une accumulation, mais pour toute la vie de l'app, sur tous les écrans, sous
  la Route, en séance, pendant la story. Le coffre, lui, arrête le sien.
  Remède : `stop()` quand plus personne ne lit `tilt` (aucune card montée).
- **AR-03 — à chaque retour au premier plan** (écran rallumé, retour de l'île,
  autre app), la racine rejoue cinq tâches base/réseau : relecture de TOUTES
  les séances, push, outbox, coffre + événements, Welcome Back, serveur de
  départ (`NosfyApp.swift:110-139, 2575-2583`). Verrouillées contre la
  concurrence, **pas contre la répétition**. Remède : un délai minimum entre
  deux rafales (par ex. 60 s) et un push incrémental.
- **AR-04 — l'écran reste allumé pour toujours** si un tapis/HIIT est quitté
  sans Finish (`ExerciseDetailView.swift:2435` pose `isIdleTimerDisabled =
  true`, rendu seulement par Finish ou la fin de séance sous la fiche, jamais
  par `onDisappear`). Multiplicateur passif de chauffe. Remède : le rendre à la
  disparition de la fiche.
- **AR-05 / G1 — la page Exercices sous la fiche** (§ 2).
- **M1 / M4 — chaque sachet = un manège neuf + un TabView remonté** (§ 3).
- **B6 — après une séance, 2 à 6 dalles d'affilée** (§ 6).
- Petites fuites sans chauffe : observateur `NotificationCenter` jamais retiré
  par la vidéo des cards (`RewardCard.swift:2781`, +1 par Welcome Back vidéo) ;
  tableau `vus` des annonces réécrit en entier à chaque dalle ;
  `stoppedSessions` qui grossit d'une date par séance ; session audio
  reconfigurée à chaque arrivée sur le profil et à chaque dalle.

**Vérifié propre** : la Route, le manège, le coffre, la story, la pilule, la
nav invalident bien leurs liens et lecteurs au démontage ; aucune vue de séance
gardée vivante après fermeture.

### La mesure qui tranche

Une balade de 10 min `-sondeVol -ecranEveille` à thermique 0 (Route, coffre,
manège, fiche, story × 3 chacun), puis Instruments Allocations/Leaks sur dix
ouvertures/fermetures — les coordinateurs doivent mourir à chaque fois.

## 6. « Pousser le toaster vers l'île pour le cacher : ça chauffe et ça bugue »

### Ce que le code fait (retenu 3/3)

**B1 — le toaster ne prend AUCUN toucher.** L'hôte de toutes les dalles porte
`.allowsHitTesting(false)` (`Annonces.swift:202`) et il n'existe **aucun
geste** dans `Annonces.swift`, `NotifCard.swift`, `NotifChasse.swift`. Le dessin
promet un retour dans l'île (le masque part de la capsule de l'île, 126 × 36 pt
à y = 11) ; le code n'a rien pour le faire. C'était le contrat choisi le 29-08
(`docs/screens/notification.md:147`). **Le geste qu'elle tente n'existe pas :
son doigt traverse la dalle.**

**B2 — sur la home, ce doigt tombe sur le tirage de la page**
(`HomeNuit.swift:3178`, page-large, 2 pt de seuil). Un swipe vers le haut
≥ 80 pt ou > 420 pt/s **ouvre le film de départ** (TimelineView 60 Hz, cinq à
six flous animés, 1,95 s + 1,25 s de fermeture) — et le jour des deux séances,
il tape le **plafond** : haptique warning + pop-up « revenez demain » +
`fermer()`. C'est le candidat le plus probable pour « ça bugue » (retenu 2/3 ;
un contradicteur le classe comme conséquence de B1, ce qu'il est).

**B3** (en séance hors home : le swipe fait sortir la pilule de l'île) —
**écarté** : le cas n'est pas atteint dans son parcours et la zone tactile
était surestimée.

**B4-B7 — la file** : après une séance, **2 à 6 dalles d'affilée** (pièces,
cardio, bonus, sachet, sachet converti, argent) à la fin de la cinématique du
galet, puis la card à gratter, puis le +10 — 7 à 25 s de dalle animée, chacune
avec carillon, haptique, changement de catégorie audio et appel réseau
(`Annonces.swift:88-131`, `NosfyApp.swift:932`). Pendant ses 2,8 s, la dalle
« pièces » ré-évalue la pièce à chaque image avec un `CGImage` neuf sous deux
ombres, un clip et le masque du morph (`NotifCard.swift:1073`, `CoffreV2.swift:367`).
**Aucune porte de sortie** : ni tap, ni swipe, ni thermique, ni arrière-plan ;
la seule fin est l'horloge. Rien ne peut la laisser « à mi-course ».

### La question à lui poser

**Quel toaster pousse-t-elle** : la dalle noire COINS EARNED / BOOSTER de l'app,
ou la bannière système de la Live Activity (qui, elle, se replie au swipe) ?
Et voit-elle la card de la home bouger ou la pop-up « revenez demain » quand
elle pousse ?

### Les remèdes (décisions à prendre)

1. **Un vrai geste de renvoi vers l'île** sur la dalle : l'hôte devient
   tactile sur le rectangle de la dalle seulement, un swipe vers le haut joue
   la transition de sortie puis la suivante — et le tirage de la home ne reçoit
   plus ce doigt. C'est ce qu'elle attend depuis le 17-09 (« comme une vraie
   notif Apple »).
2. **Regrouper les dalles d'une clôture** (pièces + cardio + bonus en une, les
   sachets en une) et **mettre la file en pause à « serious »**.
3. Figer la pièce (`-notifT 0` existe pour l'A/B) : une pièce qui tourne 9 s
   sous trois passes hors écran, pour 2,8 s d'affichage.

## 7. « On ne voit plus la petite chauve-souris du profil »

La « chauve-souris » est **Nosfy pendu** sous la Dynamic Island de la bannière
(`ProfilLune.swift:640-648, 1722-1766`) : une vidéo muette de 7 s
(`profil-nosfy-penche.mp4`, **bien dans le build 82**, sha `97eecfde`), jouée
**une fois** à l'arrivée sur l'onglet puis démontée. Les vraies chauves-souris
dessinées (`NightBirds`) ne vivent que dans LuneDeSang et MoonSplash.

Ce qui la cache, dans l'ordre de probabilité (lu, vérifié ligne à ligne ;
rien mesuré) :

1. **CS-3 — la porte thermique « serious »** (`ProfilLune.swift:372` :
   `!ReposDecorProfil.banniere` = `thermalState ≥ 2`). Elle est lue **une seule
   fois** dans la fermeture `onChange(of: ongletCache)`, pas dans un body
   observé : arriver sur le profil avec le téléphone à « serious » → pas de
   Nosfy, et **il ne remonte pas quand le téléphone refroidit** tant qu'on ne
   quitte pas l'onglet — alors que le galet et le spot, eux, lisent la même
   porte dans leur body et se réveillent. Avec ses symptômes de chauffe, c'est
   l'explication la plus simple : **la chauve-souris est un symptôme de la
   chaleur.** Sur la capture du 20-09 17:37 (app ouverte depuis 10 min), il
   était là.
2. **CS-2 — le seul retour est la bascule d'onglet** (`ProfilLune.swift:361-374`,
   `NosfyApp.swift:1580`) : fermer le coffre, revenir du film de revisite,
   revenir d'arrière-plan, scroller — rien ne rejoue (par conception). Si
   « doit réapparaître » veut dire aussi au retour du coffre, c'est une
   **décision produit**, pas un bug.
3. **CS-5 — la page reste scrollée** entre deux visites : Nosfy joue sous le
   dégradé noir du header dès 26 pt de scroll, ou hors écran.
4. **CS-6 — aucune porte de cover ni d'arrière-plan** : ouvert dans les 7 s,
   le coffre ou le manège le laisse jouer et se démonter sous eux ; en
   arrière-plan le lecteur reste probablement figé (supposé).
5. Reduce Motion (réglage système) le supprime aussi (le galet serait alors
   une image fixe : elle n'a rien dit de tel).

**Danger à connaître** : l'index git partagé porte `D
Nosfy/Media/profil-nosfy-penche.mp4` (et `profil-piano.wav`) en suppression
posée par une autre session — le fichier est sur le disque et dans HEAD, mais
un `git commit` nu l'emporterait et Nosfy disparaîtrait pour de bon (repli
`ProfilLune.swift:1704-1709`).

### Remèdes

1. **Observer la porte** comme le galet et le spot : Nosfy se monte quand le
   téléphone redescend sous « serious », sans quitter l'onglet (correctif
   minimal, un fichier).
2. **Décider** si le retour d'un cover / d'arrière-plan doit rejouer ; si oui,
   ajouter `scenePhase` et la fermeture du coffre à la formule.
3. Remonter la page en haut à l'arrivée sur l'onglet, ou ne pas jouer si la
   bannière est hors écran.

## 8. « Un galet = un jour, malgré deux séances, avec une super animation ×2 »

### Ce que le code fait aujourd'hui

**Serveur et téléphone disent la même chose : un galet PAR SÉANCE, deux par
jour au plus** (règle du 18-09 gravée dans CLAUDE.md, briques.ts:104,
serveur.ts:9-12). Ce qu'elle voit le 21-09 (deux séances = deux galets, le
second avec ×2) est **le code qui fait ce qu'il dit**. Passer à « un jour avec
≥ 1 séance = un galet » change une **unité** dans dix endroits — vérifiés ligne
à ligne :

**Serveur** (`supabase/migrations/20260920160000_…sql`) :
- G1 `:152` — la garde des lunes compte des **lignes de séances** plafonnées
  (`count(*) from seances_chemin_plafonnees()`, seuil 3/7 par chapitre, 35 pour
  le trésor) → doit compter des **jours** (`count(distinct jour)` ou une
  `jours_chemin()`).
- G2 `:117-137` — `seances_chemin_plafonnees()` porte déjà `jour` et
  `rang_jour` : il manque `public.jours_chemin()` (jour, nb séances, première,
  dernière fin) par-dessus. Ne pas toucher `seances_chemin()` (fix HIIT de la
  session Route) ni la clôture.
- G3 `:179-188` — la clôture **paie** la 2e séance (pièces + sachet + faits) :
  **décision**, pas un bug (ses mots ne parlent que des galets — recommandé :
  garder le paiement).
- G4 (`20260920170000`) — rétroactivité : `chemin_plafond_depuis` protège les
  journées d'avant ; **sa journée du 21-09 a déjà deux galets** : la nouvelle
  règle lui en retire un sous les yeux (acceptable : aucune lune atteinte) — à
  dire, ou poser une seconde date `chemin_jour_depuis`.
- G5 — le fait `double_jour` de la story (Paris, `started_at`, séances vides
  comprises) et le ×2 du galet (jour local, `ended_at`, avec travail) n'ont pas
  la même définition : à aligner si le galet du jour devient l'objet du ×2.

**Téléphone** :
- G6 `PlafondJour.swift:53-64` — `comptees` rend une entrée par séance ; il
  manque `jours(_:)` (le plafond `atteint`, lui, garde les séances : la pop-up
  de la 3e ne bouge pas).
- G7 `DuolinguoPage.swift:286-297` — `etapeEtFaits` pose **un galet par entrée**
  : LE site de la règle ; à itérer sur les jours et rendre `seances[id]` (1 ou
  2).
- G8 `DuolinguoPage.swift:450-460` — `multiple()` fabrique le ×2 en comptant
  les **autres** galets du même jour : sous la nouvelle règle il rend toujours
  nil → doit lire `seances[id] == 2`.
- G9 `DuolinguoPage.swift:404-413, 1504, 1739` — après la 1re séance, c'est le
  galet **actif (demain)** qui porte la date du jour et propose « Start a second
  session today? » : sous la nouvelle règle, deux galets « 21 » côte à côte (le
  retour TestFlight 81 !). **Décision** : la 2e séance part du galet **du
  jour** (fait), son panneau gagne « Start a second session today? », l'actif ne
  porte plus de date tant que le jour est fait — la seule option qui donne un ×2
  sur le galet du jour sans doublon de date.
- G10 `NosfyApp.swift:776-780` — le galet fêté après la story = le **rang de la
  séance** : la 2e séance du jour fêterait le galet de demain (sceau et halos
  sur un galet vide) → `celebration` = le galet du même jour local.
- G11 `NosfyApp.swift:1006-1017` — « View » retrouve la séance par sa date à
  ±2 s : un galet à deux séances n'en rouvre qu'une. **Décision** : la dernière,
  ou deux « View ».
- G13/G14 — `GaletEtape` (le sticker garde son code, son sens change) et la
  card Route (banc `double` à réécrire).
- G16 — bancs : `verif_route_vide.py:51-56` affirme l'ancienne règle ;
  `qa-plafond-jour.sql:95-96` accorde la lune à 3 séances sur 2 jours → à
  réécrire (2 séances aujourd'hui → 1 galet ×2 ; 3 jours → lune ; 3 séances sur
  2 jours → refus ; minuit local).
- G17 — CLAUDE.md (§ Compte vide et Route), briques.ts:104, serveur.ts:9-12,
  qa-23, le plan du plafond : à réécrire **dans le commit du changement**.

**La super animation ×2** (G12) : la cinématique du galet existe
(`DuolinguoPage.swift:2183-2262` : zoom 1,6×, sceau, deux halos, dézoom ;
barreau `-sansCineGalet`, banc `-cheminFete`). À la 2e séance du jour, elle
rejoue **sur le galet du jour** (déjà fait — `validerCelebration` est
idempotent) et c'est là que le ×2 se pose : le sticker arrive **après le
sceau** par une transition d'échelle + opacité sous un ressort, une onde de
plus ou une rotation −8° → +6° → −8° par valeur, l'haptique `.success`
doublée. **Aucune TimelineView, aucun flou, aucun `.shadow`** ; barreau
`-sansFeteFois2` à créer avec l'animation. **La cinématique actuelle n'a jamais
été mesurée sur son iPhone** : la mesurer avant d'y ajouter.

### L'ordre du chantier (rien de posé)

1. **Ses décisions** : pièces de la 2e séance (garder ?), rétroactivité (même
   date que le plafond ?), d'où part la 2e séance (galet du jour), date et
   « View » d'un galet à deux séances (la dernière ?).
2. **Serveur** : `jours_chemin()` + garde des lunes en jours + règle de date ;
   banc SQL réécrit ; lecture seule des comptes réels avant la pose (comme le
   20-09).
3. **App** : `PlafondJour.jours`, `etapeEtFaits` en jours + `seances`,
   `multiple` par lecture, G9/G10/G11, bancs Swift.
4. **La fête ×2**, montrée au sim (crops ×3) puis mesurée à la sonde.
5. **Doc** : CLAUDE.md, briques, serveur, qa, artefact + verif, dans le même
   commit. ⚠️ `DuolinguoPage.swift`, `GaletEtape.swift`, `CardRoute.swift`,
   `NosfyApp.swift` portent des hunks non commités de deux autres sessions :
   commit par chemins et par hunks.

## 9. Ce que cette analyse n'a pas fait, honnêtement

- **Rien n'est mesuré sur le build 82** ; tout ce qui précède est lu dans le
  code et dans les campagnes passées. Une Release locale des mêmes sources
  avec la sonde est le seul moyen de chiffrer.
- La phase de contradiction (trois lecteurs adverses par cause) a été coupée
  par une limite de session : **14 causes vérifiées sur 51 + 41** (retenues et
  écartées ci-dessus) ; les autres ont été **relues ligne à ligne ici** pour
  les plus lourdes (gyroscope, lentille, lecteurs thermiques, manège, sites de
  la règle du galet, sonde en Release), pas toutes.
- Le registre des échecs est amputé (E01-E45 ne sont lisibles que par `git
  show 4b1b966d`) et `lire-vol.py` jette les lignes `gel=1` et ignore
  `tics[5]` : à réparer avant la prochaine campagne.
- Aucun code, aucun asset, aucune écriture serveur, aucun téléphone touché.

## 10. Les questions pour elle, en une fois

1. Le flou qui dure : **sur les mots** après un retour (coffre, Route, Later),
   ou **sur toute la page** pendant/après un tirage ? Un film de 10 s.
2. Voit-elle une **petite capsule noire avec des chiffres** en haut à gauche
   (la sonde) ? Le 82 a-t-il été installé après suppression de l'app ?
3. Quel **toaster** pousse-t-elle : la dalle noire de l'app ou la bannière
   système de la Live Activity ? Voit-elle la home bouger ou la pop-up
   « revenez demain » ?
4. Les boosters : depuis **la pill du Profil** ou **le coffre** ? Combien de
   temps sur la carte révélée ?
5. La chauve-souris : le téléphone était-il chaud ? « Réapparaître » = à chaque
   arrivée sur l'onglet, ou aussi au retour du coffre ?
6. Le galet-jour : les **pièces** de la 2e séance restent-elles payées ? La
   règle vaut-elle **dès aujourd'hui** (son 21-09 passe de 2 galets à 1) ?
7. La capture du 20-09 17:37 (profil, carte en vol) : que voulait-elle montrer ?

## 11. Taha : « plusieurs séances, pas enregistrées dans son compte » (21-09, après-midi)

**Lu au serveur le 21-09 (lecture seule, uid tronqué).** Le compte de Taha
(`0e50bf50`, créé le 20-09 à 16:38, profil « Taha », fr) **existe et porte ses
quatre séances**, toutes finies, toutes avec le marqueur de réception complète
(`sync_complete_at`), toutes au fuseau Europe/Paris :

| séance | durée | exercices | séries | intervalles | payée ? |
|---|---|---|---|---|---|
| 16:41 → 17:04 | 23 min | **0** | 0 | 0 | rien à payer |
| 17:05 → 17:06 | 1 min | **0** | 0 | 0 | rien à payer |
| 18:10 → 18:38 | 28 min | 1 | 0 | **2** (cardio) | **oui, 94 pièces** |
| 18:44 → 18:47 | 3 min | 1 | **1** | 0 | **oui, 20 pièces** |

Son carnet : +10 (retour du jour, ×2), +94 (cardio), +20 (série), −100 (un
sachet converti). **Rien n'est perdu de ce qui a été validé.** Aucun retour
TestFlight écrit par lui (les quatre retours sont de Kathryn) ; la liste des
testeurs est refusée à cette clé (403). Même motif chez « Truciiii »
(`72ea5691`) : une séance de 26 s sans exercice parmi cinq.

**Ce que le code fait** : `Workout.snapshot()` (SupabaseSync.swift:395-420)
n'envoie que les séries **validées** (`isDone`) et les intervalles mesurés —
c'est voulu, les séries prévues restent locales (site : `b-tb-strength-sets`).
Une séance sans rien de validé est donc **vide** au serveur, ne compte pas
dans la Route (`faitPourRoute`), ne paie rien et n'ouvre ni story ni galet.
Et `terminerSeance` (NosfyApp.swift) la fermait **en silence** : `endedAt`
posé, retour à l'accueil, pas un mot. De son côté : « j'ai fait une séance, il
ne s'est rien passé, elle n'est pas dans mon compte ».

**Ce qui est corrigé (dans l'arbre, non mesuré)** : une séance qui se termine
sans aucune série validée ni intervalle le **dit**, par la pop-up native
(l'école du plafond du jour) : « Rien n'a été enregistré — cette séance se
termine sans aucune série validée ni intervalle : elle ne compte pas dans ta
Route et ne rapporte rien. Valide tes séries pendant la séance pour qu'elles
comptent. » L'économie ne change pas d'un centime.

**Ce que je ne sais pas** : si Taha a *vraiment* fait des séries pendant ses
23 minutes sans les valider (le geste d'ancrage), ou s'il a exploré l'app
avec une séance ouverte. Aucune donnée locale de son téléphone n'a été lue.
La question à lui poser : « pendant ta séance, as-tu tapé pour valider chaque
série ? et que voyais-tu à la fin : rien, ou une story ? »
