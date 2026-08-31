# LE PLAYER TAPIS — deux pastilles, le chrono qui se tape, la page qui s'embrase

**Plan du 31-08-2026, sur la demande de Kathryn** : *« pour le HIIT TAPIS,
l'affichage du chrono : deux boules. On part de la fiche détail, on slide le
galet (une autre session bosse dessus), et deux palets viennent sur la page
(le même design qu'actuellement), l'un vers le haut, l'autre vers le bas. Le
chrono se lance ; une petite phrase blanc dégradé Apple s'allume et s'éteint
("Tap to Stop") et un icon Stop blanc dégradé apparaît toutes les 3 secondes
dans la pastille, à la place du chrono. En dessous, la pastille du
kilométrage à 0, configurée avec une grosse molette blur de 0 à 20 km/h (à
17 km/h il faut trouver le bouton VITE). Un set se termine au clic sur stop
→ notification variant grosse pièce, "set 1 terminé + 20 pièces", et on
reste sur la page. Le chrono revient à 0, stop devient start, "tap to
start", ainsi de suite. Pour terminer la session : glisser le slider en bas.
Plus j'avance dans les sets, plus le fond de la page devient rouge. Fais un
plan, ne code pas, hésite pas à challenger. »*

**Rien n'est codé.** Tout ce qui suit est mesuré dans le code du 31-08 au
matin (arbre avec WIP multi-sessions : les `fichier:ligne` peuvent glisser).

> ⚠️ **Trois sessions vivent dans l'arbre** : le player/fiche
> (`PageCard.swift`, `ExerciseDetailView.swift`, `WorkoutPill.swift`,
> `PlayerSeance.swift` non tracké), le coffre (`WoopApp.swift` hunks), la
> progress. Les jalons J0-J2 de ce plan sont des **fichiers neufs + bancs**
> (zéro conflit) ; le J3 touche la fiche — il attend que la session du galet
> cardio ait posé, ou se coordonne avec elle. Commits par chemins explicites,
> jamais `git add -A`, jamais `git stash`.

---

## 0. CE QUE JE CHALLENGE (avant l'anatomie)

1. **⚡ TRANCHÉ 31-08 (ok Kathryn) — deux « stop » à l'écran = confusion.**
   En mode tapis, la dalle masque son stop (`stopVisible: false`, le
   paramètre existe — `WorkoutPill.swift:154`) ; la SEULE fin de session
   sur cette page est le slider du bas. Sur les autres pages (home, liste),
   la dalle garde son stop : on peut toujours clore de partout.
2. **Le slider de la maquette dit « FINISH SET » mais termine la SESSION.**
   Piège de libellé pur : le set se finit au TAP, la session au SLIDE. Le
   slider doit dire **« Finish »** / « End session » — jamais « set ».
3. **⚡ TRANCHÉ 31-08 (ok Kathryn) — à 17 km/h, le tap d'abord.** Le
   panneau vitesse = une rangée de GROS raccourcis (l'éventail 5·6·7·8·10
   de ta maquette — le pattern `restChoices`/`restRow` existe,
   `SetEntrySheet.swift:29, 247`) + la grosse molette pour l'ajustement
   fin. Un tap = 90 % des cas ; la molette = le réglage posé, entre deux
   sets.
4. **⚡ TRANCHÉ 31-08 (verdict Kathryn) : la POP-UP OUI — au tap stop.**
   Mon challenge initial (« aucune pop-up en courant ») visait le mauvais
   instant : au tap stop on ne court PLUS (entre-sets = repos). Sa demande :
   *« quand j'ai tapé sur stop : notification pour dire "enregistré" + une
   pop-up stylée avec des flammes et tout, pour encourager »*. Donc CHAQUE
   fin de set = la notif grosse pièce (l'enregistrement, §6.1) **ET la
   pop-up flammes** (l'encouragement, §6.2). Ce qui RESTE interdit : une
   pop-up PENDANT qu'un set court, et le panneau « Recommencer ? » de la
   muscu (sans objet sur tapis).
5. **⚡ TRANCHÉ 31-08 (OK Kathryn) : l'alternance stop/chrono joue sur les
   2 premiers sets de la séance, puis s'éteint** (le « Tap to stop » qui
   pulse reste, lui, en permanence). Le seuil « 2 » reste réglable au banc.
6. **⚡ TRANCHÉ 31-08 (OK Kathryn) : le chrono survit au monde réel du
   tapis.** App en arrière-plan (musique), écran qui veut s'éteindre : le
   chrono est une **fonction pure d'une date-ancre** (la discipline
   `LightDial`, `Woop/Figures/LightDial.swift:134-136` — zéro accumulation),
   et la séance tapis pose `isIdleTimerDisabled` (l'écran ne dort pas tant
   qu'un set court).
7. **Un set de 3 secondes vaut-il 20 pièces ?** Le serveur ne vérifie pas
   (`p_series` est déclaré, §5). App perso : pas d'anti-farm à construire,
   mais le plan le DIT au lieu de le laisser découvrir (§10.6 propose un
   plancher optionnel).

---

## 1. L'ÉTAT DES LIEUX, mesuré dans le code

| pièce | où | verdict |
|---|---|---|
| **L'écran des maquettes** | nulle part | `"Tap to stop"`, `"select km/h"` : zéro occurrence. À construire — mais chaque brique existe. |
| **La pastille « éclipse »** | la **lentille liquide** du parcours muscu : `ShaderLibrary.liquidLens` en `layerEffect` + halos `eclipseGlow` (`LiquidLensLab.swift:1062-1088, 1178-1179` ; `Woop/LiquidLens.metal:52-76`) ; vie de la pastille `nightLens` :866-988, **fonction pure du temps** ; encre (titre `SET n` + chrono `m:ss`) :1131-1210 | ✅ « le même design qu'actuellement » = ELLE. L'`EclipseCounter` (`CounterLab.swift:66-242`) est son ancêtre de banc — on ne le ressuscite pas. |
| **Le chrono du parcours réel** | `TimelineView(.animation 1/60)` racine + dates-ancres `@State` (`LiquidLensLab.swift:209, 109-145`) | ✅ la discipline à recopier (jamais d'accumulation). |
| **Le flux cardio actuel** | `cardioPage` = un ScrollView d'ÉDITION (`ExerciseDetailView.swift:1427-1446`) + « Enregistrer l'exercice » → `save()` (:2087-2109, :2603) | 🔴 le cardio n'a AUCUN player vivant : il enregistre a posteriori. C'est le trou que ce plan comble. |
| **Le modèle de données** | `CardioPhase` : `seconds`, `speed` km/h, `cycleIndex`, `order`, `kind` (`Models.swift:523-549`) ; `hiit-tapis` = `.intervals` (:236-240) | ✅ le réceptacle existe. ❌ pas d'`isDone` : une phase est toujours du PRÉVU. |
| **La paie** | `Workout.seriesPayantes` = Σ `completedSets` = `sets.filter(\.isDone)` (`Models.swift:344-362, 463`) — « LA ligne à changer si la règle bouge » (:357) | 🔴 les phases paient 0 : **une séance 100 % tapis ne déclenche RIEN** (gardes `series > 0` : `WoopApp.swift:492`, `SacreServeur.swift:326`). |
| **Le serveur** | `cloturer_seance(p_workout, p_series)` 🟢 mesuré (site, `serveur.ts:20`) ; **`p_series` est un entier déclaré par le client**, jamais recoupé | ✅ payer les sets tapis ne demande AUCUNE migration. `pieces_par_serie` = 20 (`reward_rules`), lu par l'app (`EconomieWoop.piecesParSerie`, défaut :105). |
| **La table `cardio_phases`** | poussée par `SupabaseSync.swift:113-116` (`CardioPhaseRow` :39-49) ; le site la dit ⚪ « à retravailler (29-08) » (`serveur.ts:15`) | ⚠️ litige doc/code À POSER. Personne ne la lit : re-modelable à coût quasi nul. Ce chantier EST le retravail. |
| **La notif « grosse pièce »** | `NotifJauge(sousTitre:libelle:gain:fraction:pose:naissance:)` — pièce **92 pt** qui mord le bord, tour 9 s (`NotifCard.swift:140-165`) | ✅ existe, robe `RobeSocle` noir peint. ❌ montée au banc `-notifLab` SEULEMENT (`NotifLab.swift:52`) — jamais branchée. |
| **L'annonce en séance (muscu)** | `PillGain` locale à la fiche, zIndex 30, `allowsHitTesting(false)` (`RestartSheet.swift:536-582` ; montage `ExerciseDetailView.swift:1130-1139`) ; montant **lu du serveur** (:2355) | le précédent du « local à la page, passif ». `FileAnnonces` (racine, zIndex 9) ne sert que la clôture. |
| **La molette** | `FluidPicker` (réglette crantée générique, verre fumé, haptique par cran — `SetEntrySheet.swift:476-592`) ; physique de référence `ArcDial` (`ExercisesView.swift:810-1016`) ; haptique de référence `MoisIpod` (`CalLab.swift:3721-4029`) | ✅ `FluidPicker(title:"SPEED", unit:"km/h", range:0...20, step:0.5)` compile aujourd'hui. À GROSSIR. ⚠️ bug « molette 30× » jamais réglé (mémoire) : ne pas hériter de la physique ArcDial sans re-mesurer. |
| **Le slider** | `SliderObsidienne` (`label`, `height:62`, `validate`, `onConfirm:` NOMMÉ — `SliderObsidienne.swift:28`) ; déjà posé en pied de scène par la muscu (`LiquidLensLab.swift:1252`, y = h−78) | ✅ tel quel. |
| **Le contexte d'arrivée** | la fiche en séance = slot `page` de `PageCard` (`ExerciseDetailView.swift:601-606`) ; bande du bas RÉSERVÉE au player : `bandeH` = 110 pt (`PageCard.swift:76-78, 233`) ; au drag du player la page devient un **snapshot mort** (:376-386) | les pastilles vivent DANS la page ; le chrono figé pendant la levée est un état documenté, pas un bug. |
| **Le fond** | la scène du cadran muscu : `Color.black` + `NightSpotlight` + `NightStars` (`LiquidLensLab.swift:1154-1176`) | le fond qu'on teinte. Précédent rouge par paliers : la LUNE DE SANG (uniform par paliers, « 0,55 s PAR PALIER EST UN PLANCHER », `LuneDeSang.swift:19-40`) ; loi anti-brun (mémoire) : **R = 1,00, on désature le VERT, B ≈ 0** (braise : G/R 0,30-0,45). |

---

## 2. LA MACHINE À ÉTATS — un set tapis, du tap au ledger

```
   galet lancé (autre session)
        │  arrivée des pastilles (0,8 s)
        ▼
  ┌──────────────┐   tap sur la pastille chrono   ┌──────────────┐
  │  SET n COURT │ ─────────────────────────────▶ │  ENTRE-SETS  │
  │ chrono m:ss  │   • CardioPhase écrite          │ chrono 0:00  │
  │ "Tap to stop"│     (seconds mesurés, speed,    │ icône ▶ play │
  │ blink + ⏹/⏱  │      cycleIndex=n, faite)       │"Tap to start"│
  │ fond palier n│   • notif grosse pièce          │ sous-texte   │
  └──────────────┘     "SET n COMPLETE · +20"      │ "rest m:ss"  │
        ▲              • POP-UP FLAMMES (§6.2,     └──────┬───────┘
        │                l'encouragement — tap            │ tap play
        │                pour fermer, on reste            │
        │                en entre-sets)                   │
        │              • fond → palier n+1                │
        │              (easeOut ≥ 0,55 s)                 │
        └──────────────────────────────────────────────────┘
                                                   set n+1 démarre

  slider « Finish » (bas de page) ──▶ clôture de séance
    (la chaîne actuelle, intouchée : push + cloturer_seance,
     story, pile d'annonces, trophée)
```

- **L'état vit dans UN `@Observable` : `SeanceTapis`** (`etat: .court/.repos`,
  `setIndex`, `setDebut: Date?`, `reposDebut: Date?`, `vitesse: Double`,
  `setsFaits`). Jamais des `@State` éparpillés sur la fiche (la page porte
  déjà vidéos et shaders — piège de la page ré-évaluée). L'Observation ne
  réveille que les vues qui LISENT.
- **Le premier set démarre à l'arrivée des pastilles** (les maquettes : le
  chrono court déjà). Les suivants au tap play.
- **Le repos n'est pas un décompte** (pas de durée cible en HIIT libre) :
  l'état entre-sets affiche le temps ÉCOULÉ depuis le stop, petit, sous la
  pastille — utile (« repos ou très vite »), passif. À trancher (§10.4).
- **La vitesse du set** = la valeur de la molette au moment du STOP (si elle
  change en plein set, v1 garde la dernière — une phase par set, §10.5).
- **La séance tapis pose `isIdleTimerDisabled = true`** à l'arrivée des
  pastilles, le rend à la clôture / à la sortie de page.

---

## 3. L'ÉCRAN — l'anatomie

Tout vit dans le **slot `page`** de `PageCard` : un mode `tapisPage` de la
fiche, monté quand `exercise.tracking == .intervals && active != nil &&
seanceTapis.enCours` — la `cardioPage` d'édition reste la page hors séance.
La page ne scrolle PAS (rien à scroller entre deux pastilles : zéro conflit
de geste vertical). Les cotes fines se prennent au banc ; l'architecture :

| zone (haut → bas) | quoi |
|---|---|
| y ≈ 90 | **la phrase** « Tap to stop » / « Tap to start » — Inter-SemiBold ~20, le dégradé blanc « très Apple » de la maison ; **pulse** lent (opacité 0,35 → 0,9, période ~2,6 s, dérivée de l'horloge — jamais un `repeatForever` d'état) |
| y ≈ 150 → 400 | **la pastille CHRONO** : la lentille actuelle, telle quelle (liquidLens + eclipseGlow + encre `SET n` / `m:ss` Inter-Light). Dedans, l'**alternance** : toutes les ~3 s, crossfade 0,6 s chrono → glyphe ⏹ (blanc dégradé) → chrono ; en état repos, le glyphe ▶ REMPLACE le chrono (pas d'alternance : l'état se lit d'un coup). **Toute la pastille est la cible** (~250 pt), `contentShape` + `highPriorityGesture(TapGesture())` — jamais un `Button`. |
| y ≈ 440 | la légende « select km/h » (même encre discrète que les captions du cadran) |
| y ≈ 470 → 660 | **la pastille VITESSE** : même lentille, encre `7.0 km/h` (grand) ; halos FIGÉS ou au ralenti si la cadence l'exige (deux lentilles vivantes jamais mesurées ensemble — §8). Tap n'importe où → le panneau vitesse. |
| par-dessus, à la demande | **LE PANNEAU VITESSE** (in-tree, JAMAIS un sheet système — mort dans cette maison) : verre fumé `.regular.tint(noir 0,45)` (le pattern validé du popover stepper, `ExerciseEditor.swift:523-533`), montant du bas. Dedans : **la rangée de raccourcis** (4-6 grosses pastilles ≥ 60 pt : les vitesses récentes + favorites — l'éventail de ta maquette) puis **la GROSSE molette** : `FluidPicker` grossi (hauteur ~96, chiffres ~60, 0 → 20, pas 0,5, ~16 pt/cran), haptique par cran (`UISelectionFeedback`, `prepare()` obligatoire, plancher 40 ms — les leçons MoisIpod), session audio `.ambient + .mixWithOthers` (jamais par-dessus la musique de salle). Un tap raccourci ferme le panneau ; la molette laisse un « Done ». |
| par-dessus, au tap stop | **la notif grosse pièce** (haut, §6.1) puis **LA POP-UP FLAMMES** (§6.2) : `RewardPopup` robe `.fire`, tap pour fermer, on reste en entre-sets |
| y ≈ pageH − 78 | **le slider « Finish »** : `SliderObsidienne(label: "Finish", height: 62, validate: { active != nil }, onConfirm: finirSession)` — la place exacte du « Finish set » muscu (`LiquidLensLab.swift:1252`), AU-DESSUS de la bande du player (le bord physique appartient au drag de levée + Reachability). |
| la bande (110 pt) | la dalle player habituelle (`WorkoutPill(docked:true)`), **`stopVisible: false`** en mode tapis (§0.1). |

**Le mouvement d'arrivée** : un seul progrès `p` porté par une vue
`Animatable`, rampes en `sstep` (l'école StopCard, `StopCard.swift:128-141`) :
la pastille chrono descend du bord haut (la lentille SAIT déjà atterrir en
goutte — `nightLens` :916-937, on rejoue sa naissance), la pastille vitesse
monte du bord bas, la phrase et le slider fondent ensuite. ~0,8 s, haptique
`.impact(.medium)` à la pose, et le chrono du set 1 démarre à `p = 1`
(completion + drapeau, jamais une garde sur la valeur animée).

**Les textes** : ANGLAIS (tranché Coffre §29 ; la StopCard est déjà EN).
« Tap to stop » / « Tap to start » / « SET n » / « Finish » /
« SET 1 COMPLETE ».

---

## 4. LE FOND QUI S'EMBRASE — des paliers, jamais une horloge

**Le mécanisme** (l'avis mesuré du rapport fond, retenu) :

- Le fond du mode tapis = le noir de la scène + **une nappe de braise
  STATIQUE par palier** : 2-3 `RadialGradient`/`Ellipse` nées floues (jamais
  un `.blur` vivant), teintes **R = 1,00 · G 0,30-0,45 · B ≈ 0** (la loi
  anti-brun — un rouge qui monte en opacité sur du noir VIRE AU BRUN si le
  vert ne descend pas avec). Palette LOCALE au tapis — jamais `FlammePalette`
  (partagée avec la home).
- **Le pilote = `setsFaits`**, palier `k = min(setsFaits, 6)` : intensité +
  étendue croissantes, saturation du palier 6 (une séance de 15 sets ne
  finit pas blanche de rouge). Les valeurs des 7 paliers se cuisent au banc
  Python AVANT tout Swift (l'école `essai_fond.py` de la StopCard : composer
  et trancher en 2 min sans builder).
- **L'animation n'existe qu'à la transition** : au tap stop, UN
  `withAnimation(.easeOut(~0,7 s))` monte le palier — ≥ 0,55 s, le plancher
  mesuré de la Lune de sang (en dessous l'œil lit un dégradé, pas un état).
  Entre les sets : STATIQUE. Zéro `TimelineView` plein écran (60 → 16 img/s,
  mesuré), zéro couche pré-montée invisible (le piège du RIDEAU, payé
  30-08 : tel qui chauffe).
- **La lisibilité se mesure** : l'encre blanche des pastilles et la dalle
  (verre `.clear` qui TEINTERA sur fond saturé) se jugent sur capture au
  palier 6, pixels clairs — pas à l'œil sur le palier 1.
- **Le snapshot PageCard** : la nappe doit survivre à l'`ImageRenderer`
  (`PageCard.swift:376-386`) — pas de `blendMode(.plusLighter)` sur fond
  transparent (rendu divergent possible dans la capture) : des gradients
  opaques posés sur le noir. Vérifié à la capture au J3, pas à l'œil.

---

## 5. LES DONNÉES ET L'ARGENT — le miroir exact de la muscu

**Le principe : un set tapis = une série.** Même compteur, même taux, même
chaîne — zéro nouvelle définition du gain (la 9ᵉ copie a été tuée le 30-08).

1. **L'écriture, au tap stop** : une `CardioPhase(kind: .sprint,
   seconds: <mesuré au chrono>, speed: <molette>, cycleIndex: <n° du set>,
   order: 0)` + `context.save()` — le miroir du compteur muscu (« une série
   lancée au compteur arrive déjà cochée : elle a été faite, pas prévue »,
   `ExerciseDetailView.swift:2643-2647`). `kind = .sprint` ⇒ `isEffort`
   (`Models.swift:292`) : les secondes comptent pour le futur fait
   `hiit_secondes`.
2. **Prévu vs fait — `isDone` sur `CardioPhase`, LOCAL seulement.** L'éditeur
   écrit du prévu (`add(_:)`, :2652-2660) ; le player du fait. Sans
   distinction, la paie compterait du prévu. On ajoute `isDone` (défaut
   `false`, migration SwiftData légère) ; le player écrit `isDone: true`.
   **Pas de colonne serveur** : la muscu ne pousse pas non plus son `isDone`
   (`StrengthSetRow`, `SupabaseSync.swift:30-37`) — même dette, cohérente,
   dite au site ; conséquence assumée : une réinstallation perd le
   fait/prévu (la dette « la lecture qui manque » — `SupabaseSync` n'a qu'un
   `push` — déjà connue et générale). (L'alternative « convention sans
   champ » est fragile : un `save()` d'éditeur en pleine séance mélangerait
   tout.)
3. **La paie — LA ligne** : `Workout.seriesPayantes`
   (`Models.swift:360-362`) devient `Σ completedSets + Σ phases faites`
   (`phases.filter(\.isDone)`). Son commentaire (:344-359) désigne ce point
   unique ; ses trois consommateurs (gain de clôture, card STOP, `p_series`)
   suivent d'un coup. ⚠️ Réparer AUSSI `ProfilLune.swift:131` qui recompte
   `completedSets` en direct (bypass) — sinon le profil diverge en silence.
4. **Le serveur : RIEN.** `p_series` est déclaré ; `cloturer_seance` paie
   `p_series × pieces_par_serie` et reste idempotente par séance. Décision
   d'économie explicite (§10.6) : un set tapis vaut 20, comme une série.
5. **La notif lit le taux** : `EconomieWoop.shared.piecesParSerie`
   (`EconomieWoop.swift:105`) — jamais `20`, jamais `CoffreFortPurse.perSeries`.
6. **La sync** : `CardioPhaseRow` pousse déjà kind/seconds/speed/cycle/order
   (`SupabaseSync.swift:39-49, 113-116`) — les phases FAITES partent au
   serveur sans une ligne de plus.
7. **Les faits (hors périmètre, préparé)** : des phases réalisées rendent
   enfin possibles `hiit_secondes` et `vitesse_duree`
   (`moteur_faits.sql:98-109`) — la formule `vitesse_duree` n'est écrite
   nulle part (Σ speed×seconds sur les phases d'effort est l'interprétation
   naturelle) : à trancher AVANT que quiconque code le calcul client.
8. **⚠️ LE SITE DE DOC, dans les MÊMES commits** (règle absolue) :
   - poser le **litige** `cardio_phases` (⚪ « à retravailler » vs push réel
     `SupabaseSync.swift:113-116`) dès maintenant ;
   - au J2 : la brique `cardio_phases` change d'état (la table reçoit du
     FAIT), la règle `pieces_par_serie` reçoit la note « s'applique aussi aux
     sets tapis (client, `seriesPayantes`) » ;
   - au J3 : le site d'appel de la notif (si genre nouveau) ;
   - `npm run artefact` PUIS `npm run verif` (l'ordre mesuré), republier au
     même lien, source + livrable dans le commit du changement.

---

## 6. LA FIN DE SET SE FÊTE DEUX FOIS — la notif (l'enregistrement) + la pop-up flammes (l'encouragement)

Tranché le 31-08 : au tap stop, DEUX choses (dans cet ordre) — la notif qui
dit « c'est enregistré, +20 », puis la pop-up stylée flammes qui encourage.

### 6.1 La notif « grosse pièce » — brancher la robe, enfin

Elle décrit exactement **`NotifJauge`** : la dalle 138 pt à la pièce de
92 pt qui mord le bord (`NotifCard.swift:140-165`) — codée, validée au banc,
JAMAIS branchée (le vrai flow montre encore `PillGain`).

**Proposé : le tapis est le premier client de la robe.**
`NotifJauge(sousTitre: "SET \(n) COMPLETE", libelle: "COINS EARNED",
gain: piecesParSerie, fraction: <jauge du coffre>, …)` — la `fraction` lit
`EconomieWoop` (le solde jaune, < 100 par construction depuis la conversion,
sur le prix du sachet) — montée **locale à la page tapis** (le précédent PillGain : zIndex 30 local, `allowsHitTesting(false)`,
~3 s, transition `.move(.top)`) — pas via `FileAnnonces` (la pile racine
sert la clôture ; y injecter une robe 138 pt casserait sa grammaire capsule).

- Elle descend du haut : elle passera DEVANT la phrase « Tap to stop » 3 s —
  acceptable (elle arrive quand le set est FINI, l'état est au repos ;
  hit-testing false, rien n'est volé). À juger sur film au J2.
- ⚠️ Le strobe de la planche est MESURÉ (`PLAN-NOTIFS-V8.md` §A) : la pièce
  à 72 cases jouée lentement stroboscope — la robe actuelle a son réglage,
  ne pas y toucher.
- Repli si elle préfère la cohérence de la pile : `case serie(rang:gain:)`
  dans `Annonce` (trois switches exhaustifs, `Annonces.swift:38-42, 129,
  168`) — mais la pièce reste petite (20 pt), ce n'est PAS sa demande.
- La clôture, elle, ne change pas : story → `FileAnnonces` → pièces +
  sachet (la chaîne actuelle, intouchée).

### 6.2 LA POP-UP FLAMMES — l'encouragement (verdict 31-08)

**La base existe et elle est à ELLE** : la robe **`.fire`** de la card
reward — « le sticker FLAMME NOIRE au centre (l'asset de Kathryn) »
(`RewardCard.swift:49, 59-60` ; force ×2 sur son effet :704 ; banc
`-fireAuto` :1690-1692). La muscu la sort déjà à la série ×10
(`DecideurSerie`, `RestartSheet.swift:615` : `.reward(style: .fire, video:
"reward-rare")`) et la monte par `jouerIssue`
(`ExerciseDetailView.swift:2373-2397`). **Rien à inventer : une
`RewardPopup` en robe `.fire`, avec l'encre du tapis.**

- **Le contenu** : le sticker flamme au centre, un titre encourageant
  (copy EN, tiré au sort dans une petite liste — « KEEP BURNING » /
  « ON FIRE » / « ONE MORE » …), et le **bilan du set en sous-titre**
  (« SET 3 · 0:45 · 17 km/h ») — le seul endroit qui montre ce que le set
  a pesé. Pas de pièces dedans : l'argent est dit par la notif (§6.1), la
  pop-up ne parle que du feu.
- **Le crescendo** : la pop-up monte en intensité avec les sets — le MÊME
  pilote que le fond (`setsFaits`) nourrit sa force de flamme (le paramètre
  `force` existe déjà :704). Le fond rougit, la flamme grossit : une seule
  histoire.
- **La séquence au tap stop** : notif tout de suite (+0 s) → pop-up à
  +0,4 s (elle naît sous la notif qui descend, pas en même temps). Tap
  n'importe où pour fermer → retour à l'écran entre-sets. Le tap play du
  set suivant reste sur la pastille — fermer la pop-up ne relance JAMAIS un
  set (fermer ≠ repartir).
- **La cadence** : la robe `.fire` est validée mais jamais montée sur une
  page qui porte deux lentilles + une nappe de braise — la mesure du J2
  la couvre (film du tap stop complet : notif + pop-up + palier qui monte).
- **Ce qu'on n'importe PAS de la muscu** : le `DecideurSerie` (les rendez-
  vous %3/%5/%10) et le panneau « Recommencer ? » — sur tapis, chaque set
  sort la MÊME paire notif + pop-up, prévisible.

---

## 7. LE CÂBLAGE — fichiers neufs d'abord, la fiche en dernier

**Neufs (J0-J2, zéro conflit de session) :**
- `Woop/Views/TapisScene.swift` — `SeanceTapis` (@Observable), `TapisScene`
  (la page : phrase, deux pastilles, panneau vitesse, slider, nappes de
  braise), en **vues nommées** (le mur du type-checker a déjà cassé un build
  device). La lentille : **extraire de `LiquidLensLab` une
  `PastilleLentille` paramétrée** (titre, encre centrale, vie) — la
  discipline MedaillonStop/VeineOr : paramétrer, jamais copier ; avec
  **non-régression du parcours muscu mesurée** (`-lensLab` filmé
  avant/après). Si l'extraction s'avère trop invasive à la lecture fine
  (le fichier est un monde), repli assumé : composer localement les MÊMES
  shaders (`liquidLens` + `eclipseGlow`) — ~50 lignes, le précédent des 16
  `sstep` privés. Tranché au J0, à la lecture, pas avant.
- `Woop/Views/TapisLab.swift` — le banc (école `StopLab`/`NotifLab`).
- `tools/tapis/` — `voir.sh` (copie de `tools/stop/voir.sh`, `$?` capturé
  sur la ligne), `essai_fond.py` (les paliers de braise cuits sans builder),
  captures/, films/.

**La fiche (J3, coordination session player) :**
- `ExerciseDetailView.swift` : la branche `tapisPage` (montée si
  `.intervals` + séance + `seanceTapis.enCours`), le handoff du galet cardio
  (le point d'entrée de l'autre session : la branche `else` de :872) →
  `seanceTapis.demarrer()` + l'arrivée. La dalle passe
  `stopVisible: false` en mode tapis.
- `Models.swift` : `isDone` sur `CardioPhase` + `seriesPayantes` élargie
  (deux hunks chirurgicaux). `ProfilLune.swift:131` : le bypass réparé.
- La clôture, la StopCard, `terminerSeance()` : **zéro ligne.**

---

## 8. LES BANCS, LE SIM, LES MESURES

Sim dédié : **kat-tapis** (à créer). DerivedData : `dd-tapis`.
`./tools/charge.sh` avant TOUTE mesure (🔴 > 2 = ne pas mesurer) ;
`--terminate-running-process` obligatoire ; lancer deux fois avant capture.

| argument | effet |
|---|---|
| `-tapisLab` | la scène seule sur données bidon (sets, vitesse, paliers simulés au tap) |
| `-tapisFige` | naît posée (`p = 1`), captures immobiles |
| `-tapisT <s>` | les horloges (pulse, alternance, lentilles) clouées à l'instant s |
| `-tapisSet <n>` | naît avec n sets faits — UNE capture PAR PALIER de rouge |
| `-tapisAuto` | joue un cycle set→stop→notif→start en boucle — c'est lui qu'on FILME |
| `-fps` | `SondeCadence("tapis")` par régime (repos / set qui court / panneau ouvert / transition de palier) |

**Le vrai risque cadence : DEUX lentilles vivantes + la nappe + le pulse.**
Jamais mesuré ensemble (la muscu n'a qu'UNE lentille). Cibles : 60 au sim au
repos, pire trou < 34 ms ; verdict au TÉLÉPHONE. Si ça tombe : d'abord
`-tapisT` pour isoler, puis dégrader la lentille vitesse (halos figés) avant
de toucher au reste.

**Non-régression** : `-lensLab` (parcours muscu) filmé avant/après
l'extraction de la lentille — pas un pixel de différence attendu ;
`-homeSeance -fps` inchangé.

**L'économie se prouve en LISANT** : une clôture au compte de test
(`-skipAuth -sessionBanc -outboxBanc`) avec N sets tapis → la réponse de
`cloturer_seance` LUE (pieces = N × 20), le carnet lu. Jamais « ça doit
marcher ».

---

## 9. JALONS — chacun avec sa preuve

- **J0 — LA SCÈNE AU BANC.** `TapisScene` + `TapisLab` + l'extraction (ou le
  repli) lentille. Preuve : captures `-tapisFige` comparées aux maquettes
  (phrase, deux pastilles, slider) ; film `-tapisAuto` (arrivée 0,8 s, tap
  stop → état repos, tap play → set suivant) ; alternance et pulse dérivés
  de l'horloge (vérifié à `-tapisT`) ; cadence `-fps` après `charge.sh` ;
  non-régression `-lensLab`.
- **J1 — LA VITESSE.** Le panneau (raccourcis + grosse molette), haptiques
  préparées. Preuve : captures du panneau ; film ouverture/choix/fermeture ;
  le km/h de la pastille suit ; cadence panneau ouvert.
- **J2 — LES DONNÉES, L'ARGENT, LE ROUGE, LA FÊTE.** `isDone` +
  `seriesPayantes` + écriture au stop + `NotifJauge` branchée + **la
  pop-up flammes** (robe `.fire`, encre tapis, crescendo) + paliers de
  braise (cuits d'abord dans `essai_fond.py`). Preuves : les phases LUES en
  SwiftData après 3 sets au banc (sonde console) ; UNE clôture compte de
  test → réponse `pieces` lue ; capture PAR palier (`-tapisSet 0..6`), G/R
  mesuré sur pixels clairs (0,30-0,45) ; film du tap stop COMPLET (notif à
  +0 s, pop-up à +0,4 s, palier qui monte — cadence de la séquence
  mesurée) ; la pop-up fermée au tap ne relance pas de set (vérifié au
  film). **Le site de doc part dans le même commit** (§5.8).
- **J3 — LA FICHE.** Le branchement réel : galet cardio (coordination
  session player) → arrivée → sets → slider Finish → chaîne de clôture
  INTACTE (story, pile, trophée). Preuve : film du flow complet au sim ;
  le snapshot PageCard capturé avec les pastilles montées (levée du player
  pendant un set : chrono figé, rien de noir) ; dalle sans stop en mode
  tapis, stop présent ailleurs.
- **J4 — TON VERDICT, au téléphone, si possible SUR le tapis.** La molette
  au doigt à 17 km/h (le seul test qui compte), les haptiques réelles, la
  cadence, la lisibilité du palier 6, l'écran qui ne dort pas. J4 n'est pas
  automatique : tant que tu n'as pas tranché, le chantier est ouvert.

Commits par chemins, dans l'ordre des jalons ; `git log -1` avant chaque ;
message sans trace d'assistant.

---

## 10. À TRANCHER (mes recommandations en premier)

> ⚡ **31-08, « ok » de Kathryn** sur les points restants (fin de session,
> stop de dalle, raccourcis+molette, économie) : les recommandations
> s'appliquent. Les points mineurs non relistés partent AUSSI sur la reco,
> par défaut — réversibles au banc, un verdict à l'écran peut les rouvrir.

1. ~~La fin de session~~ — **TRANCHÉ 31-08 : le slider « Finish » de la
   page commet la clôture DIRECTEMENT** (glisser est déjà l'anti-accident,
   seuil 0,72 ; la StopCard reste la voie du stop de dalle sur les AUTRES
   pages).
2. ~~Le stop de la dalle en mode tapis~~ — **TRANCHÉ 31-08 : masqué**
   (`stopVisible: false`, §0.1).
3. ~~L'alternance chrono ⇄ ⏹~~ — **TRANCHÉ 31-08 : 2 premiers sets puis
   extinction** (le seuil reste réglable au banc).
4. **Le temps de repos affiché** — oui, petit « rest m:ss » sous la pastille
   en état repos (recommandé : HIIT = repos calibrés au feeling) / non
   (l'écran le plus nu possible).
5. **La vitesse en plein set** — v1 : une phase par set, la vitesse du STOP
   fait foi (recommandé — simple, honnête) / découper la phase à chaque
   changement (fidèle mais complexe, et le fait `vitesse_duree` n'existe
   même pas encore).
6. ~~L'économie~~ — **TRANCHÉ 31-08 : un set tapis = 20 pièces
   (`pieces_par_serie`), sans plancher de durée** — dit au site de doc au
   J2.
7. ~~La plage de la molette~~ — **TRANCHÉ 31-08 : 0 → 20 pas 0,5 +
   raccourcis récents/favoris** (la divergence 0-25 de l'éditeur est
   assumée ; le détail des raccourcis se règle au banc).
8. **Le carré noir** dans la pastille vitesse de la maquette — un glyphe
   tapis ? un vide ? (recommandé : rien — l'encre du km/h suffit, la
   lentille est la matière).
9. **`.steady` (tapis-lent)** — hors périmètre v1 (recommandé) / le même
   player avec un seul « set ».
10. **La pop-up flammes, ses mots** — copy EN tirée au sort (« KEEP
    BURNING », « ON FIRE », …) avec le bilan du set en sous-titre
    (« SET 3 · 0:45 · 17 km/h ») (recommandé) / un texte fixe. Et la
    vidéo : la robe `.fire` muscu embarque `reward-rare` — sur tapis,
    recommandé SANS vidéo (la flamme + le crescendo suffisent, et la
    cadence de la page est déjà chargée).
11. **La pop-up se ferme-t-elle seule ?** — non, tap obligatoire
    (recommandé : c'est l'instant de repos, elle a le temps, et une card
    qui s'enfuit n'encourage pas) / auto-fermeture ~4 s (le tap play reste
    accessible dès qu'elle part).

---

## 11. LES PIÈGES QUI S'APPLIQUENT (déjà payés ailleurs)

1. **Le mur du type-checker** — vues nommées, jamais un empilement
   d'expressions ; le banc = un `static let` + un `else if`.
2. **La page ré-évaluée par image** — le chrono/pulse/alternance vivent dans
   des `TimelineView` FEUILLES (la pastille seule), fonctions pures de
   dates-ancres ; l'hôte ne lit que des états discrets (`setIndex`, `etat`,
   `vitesse`) ; jamais `withAnimation(.repeatForever)` sur un état (avalé
   quand le parent se ré-évalue — payé 2×, `PageCard.swift:402-407` ;
   la fuite du souffle, `WorkoutPill.swift:409-443`).
3. **Deux horloges dérivent** — l'alternance, le pulse et le chrono dérivent
   de LA MÊME horloge (phase), jamais d'un `DispatchQueue`.
4. **Un `Button` sous un drag d'ancêtre est annulé** — les taps des
   pastilles : `contentShape` + `highPriorityGesture(TapGesture())` (loi
   `WorkoutPill.swift:498-514`).
5. **Un `DragGesture` peut mourir sans `onEnded`** — la molette et le slider
   gardent remise à plat sur `startLocation` + chien de garde qui COMMET si
   le seuil était franchi ; le bug « molette 30× » n'est PAS réglé : la
   physique se re-mesure AU DOIGT avant d'être déclarée saine.
6. **Le verre** — `.regular` nu INTERDIT ; le panneau vitesse = verre fumé
   teinté (pattern stepper) ; jamais un verre aux bounds vivants (blur plat
   définitif) ; le verre ne se reconstruit jamais par image.
7. **Le rideau** — rien ne se monte invisible « pour plus tard » : le
   panneau vitesse ne se monte qu'ouvert, la nappe du palier courant
   seulement (tel qui chauffe, payé 30-08).
8. **L'anti-brun** — R = 1,00, G désaturé, B ≈ 0 ; `mix` vers la teinte,
   jamais une addition ; mesuré sur pixels clairs, jamais en moyenne.
9. **`onConfirm:` nommé** sur SliderObsidienne (closures traînantes
   interdites — deux propriétés optionnelles suivent) ; le slider ne se
   démonte pas avant +0,45 s (son filament joue).
10. **Le montant se LIT** (`EconomieWoop.piecesParSerie`) — jamais 20 en dur
    (la 9ᵉ copie a été tuée le 30-08).
11. **Le build et la mesure** — `$?` sur la ligne, jamais `| grep` ;
    `charge.sh` avant `-fps` ; une cinématique se FILME ; le verdict est au
    téléphone ; `-demoData` sème une séance ouverte qui persiste
    (uninstall) ; `-skipAuth` pour capturer.
12. **Multi-session** — commits par chemins/hunks ; `PlayerSeance.swift`
    (untracked) et les hunks des autres ne se touchent JAMAIS ; le J3
    attend/coordonne la session du galet cardio.
13. **La doc** — toute modification qui touche la paie, la table ou un site
    d'appel embarque `docs/site/content/*.ts` + artefact + verif DANS le
    même commit (règle absolue du CLAUDE.md).
