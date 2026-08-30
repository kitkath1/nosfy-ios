# ANALYSE — flow de fin de séance, back-end des boosters, source de vérité de la réserve

Fusion de trois rapports de lecture (flow de fin de séance · back-end boosters · coffre/profil), relus le 30-08 sur l'arbre de travail (HEAD `fc473c9`, 30-08 13:23). Rien n'a été modifié dans le dépôt hors ce fichier.

**Convention des preuves.** Les numéros de ligne sont ceux des rapports d'origine ; quand le relevé du 30-08 donne un autre numéro (l'arbre a bougé : `WoopApp.swift`, `BoosterPopup.swift`, `BoosterCard.swift` sont modifiés non commités, cf. §4.1), il est noté « → relevé 30-08 : L… ». Les chemins sont relatifs à la racine du dépôt ; les migrations à `supabase/migrations/`.

---

## 1. La chaîne de fin de séance aujourd'hui

### 1.1 Les portes vers `terminerSeance()`

`terminerSeance()` est définie à `Woop/WoopApp.swift:441-512` (relevé 30-08 : `func terminerSeance` L441, `guard gain > 0` L508, `proposer()` L510 — inchangés). Trois appelants :

| Porte | Preuve | État |
|---|---|---|
| (a) `StopCardHote.onTerminer` — la card STOP joue 0,50 s de filament + 0,42 s de sortie AVANT d'appeler `onTerminer` | `WoopApp.swift:1127-1147` (zIndex 13) ; `Woop/Views/StopCard.swift:110-121` (relevé : `asyncAfter(+0.50)` L113, `easeOut(0.42)` L114, `onTerminer()` L118) | vivante |
| (b) `.onChange(of: depart.clotureDemandee)` | `WoopApp.swift:1365-1370` → relevé 30-08 : L1377-1380 ; déclaration `Woop/Views/DepartSeance.swift:39` | **morte** : `grep -rn clotureDemandee Woop` ne rend que la déclaration (`= false`), la lecture et la remise à `false` — aucun écrivain à `true` (revérifié 30-08) |
| (c) banc `-clotureTest`, 4 s après splash/auth | `WoopApp.swift:1324-1329` → relevé : L1336 | banc |

La card STOP se lève par `DepartEtat.shared.pauseOuverte = true` (`Woop/Views/WorkoutPill.swift:199-209`, `demanderLaPause` ; relevé : L199 et L207) ; `WoopApp.swift:674` et `:717` (`onStopViaPause`).

### 1.2 Ordre exact et délais dans `terminerSeance()` (t0 = appel)

Preuve : `Woop/WoopApp.swift:441-512`.

| Instant | Action | Ligne |
|---|---|---|
| t0 | garde `active` ; sinon `pauseOuverte = false` (0,22 s) + `selection = .home` (0,3 s) + `return` | :442-451 (relevé : L447, L449) |
| t0 | `series = a.seriesPayantes` ; `gain = series × EconomieWoop.shared.piecesParSerie` | :458-459 |
| t0 | `pauseOuverte = false` (0,22 s) | :462-464 (relevé L463) |
| t0 | `a.endedAt = .now` + `save` + `WorkoutActivityController.end()` | :465-467 (relevé L465) |
| t0 | si `gain > 0` → `WoopCelebration.shared.workoutFinished()` | :471 (relevé L471) |
| t0 | `selection = .home` (easeOut 0,3 s) | :475 (relevé L475) |
| t0 (fond) | `Task.detached { await SupabaseSync.shared.push([snapshot]) ; await SacreServeur.reglerFinDeSeance(seance, series:) }` | :495-499 (relevé L496-498) |
| t0 + 1,6 s | `depart.notifPieces = gain` (si `gain > 0`) | :501-503 |
| t0 + 4,6 s | `depart.notifPieces = nil` | :504-506 |
| t0 | `guard gain > 0 else { return }` | :508 |
| t0 + 5,2 s | `SacreEtat.shared.proposer()` | :509-511 |

**Aucune story n'est appelée nulle part dans cette fonction** (`WoopApp.swift:441-512` ; aucune référence `Story*` dans `WoopApp.swift` hors le banc `-storyLab`, `:250` et `:757-758`, relevé : L250, L757-758).

### 1.3 Le trophée — chemin indirect

`workoutFinished()` pose `awaiting = true` (`Woop/Views/HomeView.swift:259`). `celebrateFinishedWorkout()` (`WoopApp.swift:1570-1577` → relevé L1582) est déclenchée par `.onChange(of: activeWorkouts.isEmpty)` (`:1403-1406` → relevé L1417) et `.onChange(of: sheetWorkout == nil)` (`:1407` → relevé L1419) ; elle exige `awaiting && sheetWorkout == nil && active == nil`, force `selection = .home` si besoin (relevé L1585), puis `deliver()` à +0,5 s → `trophySignal += 1` (`HomeView.swift:262-266`), écouté par `TrophyRow` (`HomeView.swift:325`). Le trophée joue donc ~t0 + 0,5 s, avant la notif pièces (+1,6 s).

### 1.4 Étagement zIndex à la racine (`mainBody`)

Rapport flow : route `CheminHote` 4 (noir 3,5) ; `DepartPanneauHote` 5 ; `BoosterCardHote` 6 ; `BoosterLab` (manège) 7 ; `PiecesNotif` 9 (`allowsHitTesting(false)`) ; `RewardCheminHote` 12 ; `StopCardHote` 13 ; `MoonDust` 20 (`WoopApp.swift:557, :1114-1115, :1147, :1157-1158, :1172, :1187, :1258, :1295`). Relevé 30-08 : 3,5 L557 · 4 L593 · 12 L1115 · 13 L1147 · 9 L1157 · 5 L1172 · 6 L1196 · 7 L1270 · 8 L1277 · 9 L1297 · 20 L1307 · 10 L1323.

### 1.5 Un second `finish()` hors chaîne

`ActiveWorkoutView.finish()` (`Woop/Views/ActiveWorkoutView.swift:297-307`, relevé L297-307) pose `endedAt`, save, `end()`, `WoopCelebration.workoutFinished()` SANS garde `gain > 0` (L302), push Supabase, puis `recap = workout` (L307) — ni notif pièces, ni `proposer()`, ni `reglerFinDeSeance`. C'est l'ancienne feuille (`sheetWorkout`), repli de banc.

### 1.6 Où joue la story 2 (`StoryFlow` / `StoryPortal`) — aujourd'hui

**La fin de séance ne déclenche PAS la story.** Preuves : aucune référence `Story*` dans `WoopApp.swift` hors `-storyLab` (`:250`, `:757-758`) ; `HomeNuit` (la vraie home, `WoopApp.swift:976`) n'a aucun `Story*` ; le onTap des mini-cards (`Woop/Views/HomeNuit.swift:1291`) appelle `ouvrirChemin()` (relevé : `func ouvrirChemin` L3752) avec le commentaire « Le jour où une mini ouvrira la story de SA séance » (`HomeNuit.swift:3021-3036`, relevé L3021). Le plan le dit : « La fin de séance ne lance toujours PAS la story (branchement à venir) — hors de ce chantier » (`tools/story/PLAN-STORY-V2-ENDED.md` §4, l.224-236 ; la réf. `HomeNuit.swift:1221` qui y figure est périmée).

Trois sites montent la story :

| Site | Comment | Preuve |
|---|---|---|
| (a) Banc `-storyLab` | `StoryLab` monte `StoryPortal` sur `@State showing` ; `onClose` → `showing = false`, `run += 1`, rejeu à +1,6 s si `-storyAuto` | `Woop/Views/StoryFlow.swift:629-704` (relevé : `struct StoryLab` L629, `-storyAuto` L635) |
| (b) Onglet Progrès RÉEL | `CalendarStickersPage` (`WoopApp.swift:992`, relevé L992) porte `.fullScreenCover(item: $story)` → `StoryPortal` (`Woop/Views/CalLab.swift:109, :295-302`, relevé L297) ; `openStory(day:rect:)` (`:319-323`, relevé L319 ; branché sur `onDayTap` `:395`) sur `DemoSession.at(day)` — **données DÉMO** (`:4687-4700`) ; `onClose = { story = nil }`. Et `MoisIpod` (`:2316`) : `jouer()` pose `storyIpod = CalStoryLaunch` (`:3883-3897`, relevé L3896), `StoryPortal` en arbre zIndex 10 (`:2488-2496`, relevé L2488), `fermerStory()` = `storyIpod = nil` + ressort (`:3901-3914`, relevé L3901-3902) ; session = `DemoSession.storySession` (`:4729`) | `CalLab.swift` |
| (c) `HomeAuroraView` (ARCHIVE, `WoopApp.swift:975`) | `.fullScreenCover(item: $story)` avec `StorySession(workout:)` (`Woop/Views/HomeAuroraView.swift:128, :255-262`, relevé L256-260) — `story` n'y est jamais assigné qu'à `nil` (seule écriture `:260`) : code mort | `HomeAuroraView.swift` |

**État / drapeau.** Il n'existe AUCUN état partagé de story (pas de `StoryEtat`, pas de `storyOuverte`) : chaque site tient son propre `@State` Identifiable (`CalStoryLaunch` privé à CalLab `:788`, relevé L788 ; `StoryLaunch{workout, rect}` `StoryFlow.swift:157-161` ; `Bool showing` au banc). Donnée = `StorySession` (`StoryFlow.swift:57-153`), `top: TopSport?` (`:71`), `double: DoubleFait?` (`:76`) ; seul constructeur depuis une vraie séance : `init(workout: Workout)` (`:111-145`). TOP et ×2 ne sont posés que par les drapeaux de banc `-storyTop` / `-storyTopMuscu` / `-storyDouble` (`:640-653`, relevé L642-648) ; « le vrai déclencheur viendra du fact engine » (`:638-639` et `:21`).

**Pages.** `StoryFlow.PageRole = ouverture · resume · details · analyse · butin` (`:275`, relevé L275). Jour ordinaire 4 pages `[ouverture, details, analyse, butin]`, jour d'exception 5 (`:279-283`) ; `exception` : ×2 prime sur TOP (`:286-290`) ; ouverture = `StoryEnded` `.complet/.top/.double` (`:328-332` ; `Woop/Views/StoryEnded.swift:73`), résumé = `StoryEnded .resume` (`:333-336`), details = `StoryDetails`, analyse = `StoryAnalyse`, butin = `StoryWin` (`:353-358` ; robe `.poche/.renverse` choisie par `-winRenverse`, `Woop/Views/StorySuite.swift:1455`). Durées : `hold[0]` / 6,5 s / `hold[1]` / `hold[2]` / 8,0 s (`:297-307`) ; **relevé 30-08 : `StoryCine.hold = [12.6, 7.0, 7.0]`** (`StoryFlow.swift:169`) — ce qui lève l'inconnue du rapport flow (la mémoire disait `[13, 7, 7]` au 26-08).

**Fermeture.** Trois sorties, toutes vers `StoryFlow.onClose` (`:249`, relevé L249) : (i) fin automatique — `conduct()` (`:416-425`, relevé L416) → `advance()` : `if page >= dernier { onClose(); return }` (`:429-432`, relevé L429-430) ; (ii) tap tiers droit sur la dernière page → `advance()` (`:534-538`) ; (iii) tirage bas > 110 pt (ou > 40 pt + prédiction > 300) → `fall = 900` puis `onClose()` (`:503-510`, relevé L507-508). `StoryPortal.onClose` (`:558`, relevé L558) reçoit ce `onClose` dans `close()` (`:614-621`, relevé L614-620) : garde `closing` (L615-616), referme le masque en 0,34 s, puis appelle SON `onClose` à +0,30 s (L620). Chez tous les hôtes ce `onClose` ne fait QUE démonter (`story = nil` / `showing = false` / `storyIpod = nil`) : **rien n'est enchaîné après la story — ni booster, ni notif, ni trophée** (`StoryFlow.swift:683-691` ; `CalLab.swift:297-301, :3901-3914`).

**Point d'accroche « booster à la fermeture de la story » (constat, pas décision).** Le seul callback de fin est `StoryFlow.onClose` relayé par `StoryPortal.onClose` à +0,30 s (`:614-621`). Aucun hôte de `StoryPortal` n'est dans la chaîne de fin ; il n'existe pas de `.onChange` racine sur un état de story. Dans `terminerSeance`, la séance vient d'être fermée (`a.endedAt = .now` `:465`) : `active` devient `nil` au tour suivant — `StorySession(workout:)` (`StoryFlow.swift:111`) exigerait de capturer `a` avant. `proposer()` gère déjà le cas manège ouvert (`propositionEnAttente`, `BoosterPopup.swift:107-110` → relevé L115-118).

### 1.7 La proposition du booster (`SacreEtat`) — mécanique

`@Observable final class SacreEtat`, singleton `shared` (`Woop/Views/BoosterPopup.swift:23-26`). Propriétés : `popupOuverte` (`:29`), `manegeOuvert` (`:31`), `manegePose` (`:37`), `arriveeDemandee: CarteEnvolee?` (`:41` → relevé L49), `boostersEnAttente` (`:62-66` → relevé L71-73), `boostersNoirsEnAttente` (`:82-86` → relevé L91-93), `robeCourante = bancNoir ? .noire : .lune` (`:89` → relevé L97), `bancNoir = -sacreNoir` (`:96` → relevé L104), `propositionEnAttente` (`:99` → relevé L107). **Relevé 30-08 : une propriété `morsureCard` s'est ajoutée** (écrite `WoopApp.swift` L1187, L1224 ; `fermerManege` L163) — commit `fc473c9`, absente des trois rapports.

- `proposer(robe:)` (`:103-116` → relevé L111-124) : si `manegeOuvert` → `propositionEnAttente = true`, `return` ; sinon `robeCourante = bancNoir ? .noire : robe`, haptique `.soft`, `withAnimation(spring 0,42/0,88) { popupOuverte = true }`. **Purement UI : aucun appel réseau, aucune écriture.** Appelants : `WoopApp.swift:510` (fin de séance +5,2 s), `WoopApp.swift:1342` (banc `-boosterPopup`, relevé L1352), `Woop/Views/HomeAuroraView.swift:286` (bouton d'essai, archive ; relevé L286), `BoosterPopup.swift:160` (`fermerManege` rejoue à +0,9 s ; relevé L166-169). Le commentaire `:101-102` « aujourd'hui le bouton d'essai ; demain la fin de séance » est périmé.
- `popupOuverte` : vrai par `proposer()` (`:114` → L122) ; faux par `ouvrirManege()` (`:132, :139-142` → L140, L149) et par la racine (`WoopApp.swift:1182-1186` → relevé L1188 dans `onOuvrir` et L1194 dans `onFermer`). Lu par `BoosterCardHote(ouverte:)` (`WoopApp.swift:1180`) et la sonde `.sondeCadence(popupOuverte ? "panneau" : "home")` (`:1190` → L1199). Dans `BoosterCardHote`, `ouverte` pilote `ouvrir()/fermer()` (`Woop/Views/BoosterCard.swift:57-64` → relevé L59-66) et `allowsHitTesting` (`:54` → L56).
- `ouvrirManege(robe:)` (`:125-149` → relevé L133-157) : `guard !manegeOuvert` ; pose `robeCourante` si fournie ; `manegePose = false` ; ferme `popupOuverte` (0,22 s) ; à +0,32 s (si la pop-up était ouverte) ou +0,06 s, referme une pop-up rouverte puis `manegeOuvert = true` (0,38 s). **Aucune réservation serveur** (`docs/site/index.html:1832-1833`). Appelants : `WoopApp.swift:1181` (`BoosterCardHote.onOuvrir` ; relevé 30-08 L1186-1190 : `onOuvrir: { morsure in sacre.morsureCard = morsure ; sacre.popupOuverte = false ; sacre.ouvrirManege() }`), `WoopApp.swift:1345` (banc `-boosterManege`), `Woop/Views/ProfilLune.swift:347, :566, :574, :1260, :1275`, `Woop/Views/CoffreV2.swift:2546, :2561` (relevé : inchangées).
- `manegeOuvert` : écrit par `ouvrirManege` (`:146` → L154), `fermerManege` (`:155` → L164), `WoopApp.swift:1219` (`onCarteEnvolee`, 0,4 s → relevé L1230-1232). Lu par `if sacre.manegeOuvert { BoosterLab(...) }` (`WoopApp.swift:1191-1259` → relevé L1200-1270), `.onChange(of: sacre.manegeOuvert)` (`:1380-1399` → L1392 : ferme la route, filet d'éclipse +6 s, `homeEclipsee = false` à la fermeture), `.onChange(of: sacre.manegePose)` (`:1371-1379` → L1383), `ProfilLune.swift:1025`, `Woop/Views/BoosterLab.swift:2114`, `proposer()`.
- `fermerManege()` (`:152-163` → L160-170) : haptique, `manegePose = false`, (`morsureCard = nil`), `manegeOuvert = false` (0,32 s), rejoue `proposer()` à +0,9 s si `propositionEnAttente` ; appelée par `onRetourHome` (`WoopApp.swift:1206-1211` → L1215-1218, + `selection = .home`) et le banc `-boosterRetourAuto` (`:1351` → L1363).
- **Sortie du manège → profil**, `onCarteEnvolee` (`WoopApp.swift:1212-1256` → relevé L1221-1268) : `morsureCard = nil` ; `manegeOuvert = false` (0,4 s) ; `noir = robeCourante == .noire` ; décrément `sacre.boostersNoirsEnAttente` ou `sacre.boostersEnAttente = max(0, n − 1)` ; `Task { await EconomieWoop.shared.consommerBooster(legendaire: noir) }` (relevé L1261-1262, résultat jeté) ; `selection = .profile` (L1263) ; +0,45 s `sacre.arriveeDemandee = carte` (L1264-1267 ; l'`onAppear` de la page profil la relit en filet, `BoosterPopup.swift:38-41`).
- **« Later »** : `Button(action: onFermer) { Text("Later") }` (`BoosterCard.swift:320-326` → relevé L325-326) et le scrim (`:190`) → `fermer(puis: onFermer)` (sortie 0,30 s, `:88-97`) → racine `onFermer: { sacre.popupOuverte = false }` (`WoopApp.swift:1182-1186` → L1191-1195). Rien d'autre : aucun incrément, aucun appel réseau, aucune écriture (rapports backend et coffre concordants).

### 1.8 Ce que les docs disent de la place de la story et du booster

- `tools/sacre/PARCOURS-BOOSTER.md` : parcours HOME → pop-up booster → MANÈGE → cérémonie → RÉSULTAT → envol → PROFIL (l.16-21) ; §1 « la pop-up apparaît quand l'utilisateur termine un entraînement … Ce branchement n'est PAS fait » (l.34-37, daté 15-08 — **périmé** : `WoopApp.swift:509-511` la branche à +5,2 s) ; §2 Ouvrir → Manège direct ; Plus tard / tap hors panneau → home, booster jamais perdu (l.58-62) ; §7 reprise par la pill profil (l.143-152) ; tableau backend « Fin de séance : créer un booster (une séance = un booster) » (l.165). **Aucune mention de la story.**
- Mémoire `woop-flow-complet.md` (dicté 20-08, l.26-44, 63-66) : 5-8 : STOP player → overlay PAUSE → confirmer → home ; 6 animation des pièces vers la pastille ; 7 pop-up booster → flow booster ; 8 trophée dans la card home. **Pas de story.** Le chantier (C) y note « proposer() +5,2 s (1,8 s si gain 0) » — la variante « 1,8 s si gain 0 » n'existe plus (`guard gain > 0 else { return }`, `WoopApp.swift:508`).
- `tools/flow/BUGS-RESTANTS.md` : parcours « fin de séance → pièces cumulées → booster → ouverture → carte → collection → Home » (l.20-22), pas de story ; §1a le panneau de fin racine est « câblé sur terminerSeance() » (l.68-71) ; §4 les nœuds lune du chemin réutilisent `SacreEtat.shared.proposer()` (l.293-306) ; contrainte « Ne pas toucher StoryEnded/StorySuite/StoryFlow » (l.31-34) ; §9 « l'expérience de fin, volontairement non touchée » (l.466).
- `tools/story/ANALYSE-VARIANTS-ET-FAITS.md` §6 bis : « la story démarre deux secondes après « Terminer », et le seul appel serveur de la clôture part par l'outbox » (l.149-150) — **intention documentaire, sans code**. `tools/story/PLAN-STORY-WIN.md` : la 4e page « butin » montre les boosters gagnés, « la pop-up booster vue = pris en compte, et dans le profil on voit le nombre total de boosters qu'on peut ouvrir » (l.10-22) ; §4 « le front : la page WIN montre les boosters DE LA SÉANCE ; le Sacre les ouvre » (l.123-125).
- `tools/rewards/PLAN-REWARDS-BACKEND.md` §4 quaterdecies (l.1198-1223, 1313-1324) : une seule annonce par événement (verdict 29-08) ; la fin de séance enchaîne aujourd'hui capsule +1,6 s ET pop-up +5,2 s, ce que la règle interdit ; robe 4 « booster » de la notif vs pop-up non tranchée (`docs/screens/notification.md:117, 136-139` ; `tools/notifs/PLAN-NOTIFS-V9.md:152-157`).

---

## 2. Ce qui existe côté back-end pour les boosters

### 2.1 Tables

**`user_boosters`** (`20260828120000_booster_noir.sql:27-36` ; `20260828190000_gains_coffre.sql:55-74`) : `id uuid`, `user_id` (FK `auth.users`), `origine text check in ('seance','achat','cadeau','legendaire','chemin') default 'seance'`, `workout_id uuid`, `obtained_at`, `opened_at` (null = non ouvert), `card_id` (FK `cards`, rempli à l'ouverture), `noeud_id integer`, `robe text check in ('lune','noire')`.

Index (l'idempotence est un index, jamais un compteur — `.claude/skills/woop-backend/SKILL.md:41-60`) :
- `user_boosters_seance_unique (user_id, workout_id) where workout_id is not null` — 1 séance = 1 sachet (`booster_noir.sql:39-41`) ;
- `user_boosters_attente_idx (user_id, obtained_at) where opened_at is null` (`:44-46`) ;
- `user_boosters_noir_ouvert_unique (user_id) where origine='legendaire' and card_id is null` — au plus une réserve noire non scellée (`:59-61`) ;
- `user_boosters_chemin_unique (user_id, noeud_id) where origine='chemin' and noeud_id is not null` (`gains_coffre.sql:86-88`).

RLS activée, policy `select` seule pour `authenticated` (`auth.uid() = user_id`) ; aucune policy insert/update client — toute écriture passe par des fonctions `security definer` (`booster_noir.sql:63-69`).

**`coin_ledger`** (`booster_noir.sql:73-96` ; `20260828160000_wallet_coffre.sql:30-42` ; `gains_coffre.sql:25-31, 46-53, 78-79, 90-92, 128-133`) : `delta integer check <> 0`, `raison text check in ('serie_faite','ouverture_booster','doublon','cadeau','annulation','piece_argent','ouverture_booster_noir','conversion_booster','retour_quotidien','chemin')`, `currency check in ('yellow','silver') default 'yellow'`, `workout_id`, `booster_id` (FK `user_boosters`), `noeud_id`, `jour date`, `created_at`. Solde dérivé par `sum(delta)` (`solde_or()`, `solde_argent()`), jamais de colonne balance. Index : `coin_ledger_gain_unique (user_id, raison, workout_id) where workout_id is not null and delta > 0` ; `coin_ledger_chemin_unique (user_id, noeud_id) where raison='chemin'` ; `coin_ledger_retour_jour_unique (user_id, jour) where raison='retour_quotidien'`.

**Annexes** : `booster_progress (user_id, reste 0-99)` créée, `reste` écrit par personne ; depuis le 29-08 `etat_coffre()` dérive `reste = solde_or mod prix_booster` (`wallet_coffre.sql:44-56, 86-89` ; `20260829120000_annonces.sql:24-49`). `reward_rules` : `pieces_par_serie=20`, `prix_booster=100`, `prix_booster_legendaire=1`, `pieces_retour_quotidien=10`, `rare_une_chance_sur=30`, `rare_pity_seances=45`, `rare_cooldown_seances=10`, `annonce_une_par_evenement=true`, `notif_consomme_budget=false`, `notifs_max_seance=6`, `popups_max_seance=4` (`annonces.sql:90-172` ; `gains_coffre.sql:96-99`).

### 2.2 Fonctions

| Fonction | Rôle | Comportement | Preuve |
|---|---|---|---|
| `cloturer_seance(p_workout uuid, p_series int)` | **l'ACCORD** du sachet de séance | ① insert `coin_ledger serie_faite` (séries × `pieces_par_serie`, une ligne) dans `begin…exception when unique_violation` → `pieces_creditees=false` ; ② si `p_series > 0`, insert `user_boosters (origine 'seance', workout_id)` ; `unique_violation` → `booster_neuf=false` + re-select de l'id ; ③ `roll_rare(p_workout)` SEULEMENT si crédité, en sous-transaction qui avale toute exception ; rend jsonb `{pieces, pieces_creditees, booster_id, booster_neuf, solde, argent, reste, prix_booster}`. Idempotente par rappel ; `grant execute to authenticated` | `annonces.sql:279-364, 377` (remplace `gains_coffre.sql:180-238`) ; insert sachet `:316-330`, `:356-358` |
| `ouvrir_booster(p_legendaire boolean default false)` | **la CONSOMMATION** | plus ancien `user_boosters` (`obtained_at asc`) avec `opened_at is null` dans la bonne pile (`origine='legendaire'` si `p_legendaire`, sinon `origine<>'legendaire'`), `for update skip locked` ; aucun → 200 `{ouvert:false, raison:'aucun_sachet'}` ; sinon `update opened_at=now()` → `{ouvert:true, booster_id}`. Revoke `public` ET `anon`, grant `authenticated`. **Non idempotente** : chaque appel consomme un sachet | `20260829150000_ouvrir_booster.sql:48-93` (`:56-64`, `:84-93`) |
| `claim_booster()` | l'achat orange | lit `prix_booster`, compare `solde_or()` ; refus métier 200 `{ouvert:false, raison:'solde_insuffisant', solde, prix}` ; sinon insert `user_boosters (origine 'achat')` + `coin_ledger (-prix, 'ouverture_booster', 'yellow', booster_id)` même transaction → `{ouvert:true, booster_id, solde, prix}`. Aucun index d'idempotence : chaque appel débite | `gains_coffre.sql:350-381, 389` |
| `claim_booster_legendaire()` | la réserve noire | idempotent si une ligne `origine='legendaire'`, `opened_at not null`, `card_id null` existe ; sinon vérifie solde argent, insère `user_boosters (origine 'legendaire', opened_at = now())` puis débite `-prix 'ouverture_booster_noir' 'silver'`. Refus métier par `raise exception P0002` → HTTP 500 (non aligné). Rend une ligne `user_boosters` (pas jsonb) | `wallet_coffre.sql:110-154` (`:136-138`) ; `booster_noir.sql:139-182` ; `SKILL.md:118-120` ; `docs/screens/coffre-rewards.md:214-220` |
| `reclamer_noeud_chemin(p_noeud, p_pieces, p_monnaie, p_boosters text[])` | les sachets du chemin | insère `coin_ledger 'chemin'` si `p_pieces>0` ; pour chaque robe de `p_boosters` insère `user_boosters` : la première `origine 'chemin'`, la suivante `'cadeau'` (contournement de l'index (user, nœud), « à trancher ») ; `unique_violation` → `deja_reclame=true`. Le TIRAGE reste au client | `gains_coffre.sql:240-303` (`:276-283`, `:284-296`) |
| `etat_coffre()` | lecture | `{solde_or, solde_argent, boosters_or, reste, prix_booster, pieces_par_serie}` ; **relevé 30-08** : `boosters_or = count(*) from user_boosters where user_id = auth.uid() and origine <> 'legendaire' and opened_at is null` (`annonces.sql:49-62`, lu ligne à ligne — lève l'inconnue du rapport backend) | `annonces.sql:49-76` |
| `historique_gains(p_limite)` | lecture | union `coin_ledger (delta>0)` + `user_boosters` avec robe (`'noire'` si `origine='legendaire'` sinon `coalesce(robe,'lune')`) | `annonces.sql:203-249` |
| `noeuds_chemin_reclames()` | lecture | l'ensemble des `noeud_id` payés | `20260829160000_noeuds_chemin_lus.sql` |
| `roll_rare(uuid)` | privée | revoke anon/authenticated/public, appelée seulement depuis `cloturer_seance` ; insère `coin_ledger 'piece_argent' 'silver' +1` avec `workout_id` | `20260829130000_roll_rare_prive.sql:32-47` ; `annonces.sql:185-249` |
| `claim_retour_quotidien` | welcome back | 10 pièces d'or, une fois par jour calendaire (index (user, jour)) ; **aucun booster** | `gains_coffre.sql:135-162` ; `20260830090000_welcome_chaque_connexion.sql:1-20` |

**forge-card** (`supabase/functions/forge-card/index.ts:151-200, 206-225, 261-269`) : accepte `booster_id` ; relit `user_boosters (id, origine, card_id)` ; si `card_id` déjà posé → rend la carte existante (idempotence au sachet) ; si `origine='legendaire'` → `rareteImposee='legendary'` ; après l'insert `user_cards`, scelle `update user_boosters set card_id … where id=booster_id and card_id is null`. Sans `booster_id`, rien ne change (tirage ordinaire, aucun scellement).

### 2.3 État de déploiement

- **Mesuré (rapport backend, 30-08)** : `supabase migration list --linked` → les 13 migrations locales présentes côté remote (relevé 30-08 du dossier : `0001_init`, `20260729120000_woop_schema`, `20260814180000_cartes_lune`, `20260828120000_booster_noir`, `20260828160000_wallet_coffre`, `20260828190000_gains_coffre`, `20260829120000_annonces`, `20260829130000_roll_rare_prive`, `20260829150000_ouvrir_booster`, `20260829160000_noeuds_chemin_lus`, `20260829170000_regles_chemin`, `20260830090000_welcome_chaque_connexion`, `20260830100000_moteur_faits` — 13 fichiers). Sonde PostgREST clé anon : `POST rpc/ouvrir_booster` → HTTP 401 code 42501 « permission denied for function ouvrir_booster » (la fonction EXISTE, le revoke anon tient) ; témoin `rpc/fonction_inventee_temoin` → 404 PGRST202.
- **Documenté** : migrations du 28-08 déployées et vérifiées fonction par fonction (`docs/screens/coffre-rewards.md:155-212`) ; 29-08 annonces + roll_rare_prive vérifiées sur le compte de test rejeu ×3 (`tools/rewards/PLAN-REWARDS-BACKEND.md:1258-1268` ; commit `97cf6d9`) ; les quatre du 29/30-08 déployées (commit `6557a90` « Les quatre sont déployées et vérifiées ») ; forge-card patchée déployée le 28-08 (`tools/sacre/PLAN-BOOSTER-NOIR.md:452-467`).
- **Commentaires du code (relevé 30-08, toujours présents)** : `Woop/Services/SacreServeur.swift:325-326` « ⚠️ MIGRATION `20260829150000_ouvrir_booster.sql` — NON DÉPLOYÉE » ; `Woop/Services/EconomieWoop.swift:274-279` « ELLE DÉPEND D'UNE MIGRATION NON DÉPLOYÉE … l'appel échoue en 404, on l'avale » ; commit `2972f14` ; `docs/site/index.html:611, 835`. Voir §4.2.

### 2.4 Le client iOS

- **Grant (accord)** : `SacreServeur.reglerFinDeSeance(_ seance: UUID, series: Int)` (`SacreServeur.swift:226-233`, relevé L226) : `guard series > 0`, puis `OutboxGains.shared.poster(.finDeSeance(seance:, series:))` (`OutboxGains.swift:45`, `:121`). L'outbox tente l'envoi immédiat (`SacreServeur.cloturerSeance` → RPC `cloturer_seance`) et met en file si échec ; la réponse est appliquée sur le MainActor à `EconomieWoop.shared.appliquer(r)` (`OutboxGains.swift:190-205`, relevé L205) → `boostersServeur += 1` si `booster_neuf` (`EconomieWoop.swift:197-204`, relevé L197). **Aucun appel Swift n'insère dans `user_boosters`** : le serveur crée le sachet. Un seul site de production : `terminerSeance()` (`WoopApp.swift:495-499`) ; banc `-outboxSemer` (`WoopApp.swift:86` ; `OutboxGains.swift:110-114`).
- **Outbox** : actor, file Codable `GainEnAttente` en UserDefaults clé `woop.outbox.gains` (relevé L75), plafond 200 (L69), trois sorts (réussi / refusé 4xx sauf 401-408-429 / à rejouer) ; vidage UNIQUEMENT au retour au premier plan dans l'ordre semer → `reglerRetourQuotidien` (`WoopApp.swift:91`) → `vider()` (L92) → `EconomieWoop.rafraichir()` (L97). Gardes : `-demoData` sans `-syncNow` → `.aRejouer`, `WoopConfig.isConfigured`, `-outboxAvion`, `-outboxBanc` (`OutboxGains.swift:42-51, 61-91, 141-164, 176-242` ; `WoopApp.swift:78-97`).
- **Consommation** : `EconomieWoop.consommerBooster(legendaire:)` (`EconomieWoop.swift:264-293`, relevé L281) → `SacreServeur.ouvrirBooster(legendaire:jwt:)` (`SacreServeur.swift:327-334`, relevé L327) → RPC `ouvrir_booster {p_legendaire}` puis `rafraichir()` ; rend `booster_id` ou nil, avale toute erreur. Appelée à `onCarteEnvolee` (relevé L1261-1262), résultat jeté. **Hors outbox** (appel direct, pas idempotent — `SKILL.md:164-191` ; `ouvrir_booster.sql:90-92`).
- **Achat** : `EconomieWoop.acheterBooster()` (`:221-262`, relevé L243) → `SacreServeur.claimBooster` (`:296-302`, relevé L296) → RPC `claim_booster` ; `boostersServeur += 1` si ouvert ; sans serveur (`possible` faux) la porte reste ouverte (`.obtenu`). Appelée par `ProfilLune.swift:1265` et `CoffreV2.swift:2551` (relevé L2551). Hors outbox volontairement (`EconomieWoop.swift:232-237`).
- **Forge non reliée au sachet** : `BoosterLab.lancerForge()` appelle `ForgeServeur.tirer(jwt: jwt)` sans `boosterId` (`BoosterLab.swift:2258-2272` → relevé L2286) alors que `ForgeServeur.tirer` accepte `boosterId` et l'envoie en `booster_id` (`Woop/Services/ForgeServeur.swift:31-43`). Conséquences documentées : aucune idempotence de tirage, aucun scellement, garantie légendaire du noir jamais armée ; ordre forge (t2) → consommation (t5, à l'envol) → un quit entre les deux laisse la carte en `user_cards` ET le sachet non consommé (`docs/site/index.html:1795-1830`, `:1517-1523`).
- **La pile NOIRE ne se consomme jamais** : `claim_booster_legendaire` crée la ligne légendaire avec `opened_at = now()` (`wallet_coffre.sql:136-138`) ; `ouvrir_booster(p_legendaire=true)` exige `opened_at is null` (`ouvrir_booster.sql:56-64`) → ne matche jamais, rend `aucun_sachet`, l'app avale. De plus `SacreServeur.claimLegendaire` (`SacreServeur.swift:108`) n'a **aucun appelant** dans `Woop/` (grep revérifié 30-08 : 0 hors `SacreServeur.swift`) : la pièce d'argent n'est jamais débitée ; la porte noire (`ProfilLune.swift:562-567` ; `CoffreV2.swift:2427-2431`) s'ouvre sur le seul solde affiché (`docs/site/index.html:1836-1843`).
- **Drapeau mort** : `SacreServeur.actif` (`-sacreServeur`, `SacreServeur.swift:45`) n'est lu nulle part (grep 30-08 : 0 usage hors sa définition) ; l'accès serveur est décidé par `EconomieWoop.possible` (`EconomieWoop.swift:147-151`, relevé L147).
- **Ordre écrire-avant-lire** (`SKILL.md:244-259` ; `tools/coffre-v2/BACKEND-COFFRE.md:127-141`) : 1-4 branchés (`cloturer_seance` via outbox ; prix/soldes par `etat_coffre` ; `historique_gains` avec `avecJournal`) ; 5 partiel (nœud enregistré + `noeuds_chemin_reclames` en union avec le local, `Woop/Views/DepartSeance.swift:92-110` ; tirage et pitié encore au front, `Woop/Views/RewardChemin.swift:159-205`).

### 2.5 Doctrine (quand un booster est dû)

- **Fin de séance** : « à la fin de chaque séance on gagne automatiquement un booster basique — peu importe le nombre de séries » (Kathryn 28-08) ; pièces proportionnelles (séries × 20), sachet FORFAITAIRE ; 0 série ne paie rien — garde à trois endroits : `terminerSeance` `gain > 0` (`WoopApp.swift:468-471, 508`), `reglerFinDeSeance` `series > 0` (`SacreServeur.swift:226-230`), `cloturer_seance` `p_series > 0` (`gains_coffre.sql:4-11, 164-174, 214-218` ; `PLAN-REWARDS-BACKEND.md:1116-1132` §4 terdecies ; `coffre-rewards.md:128, 133-138, 247-248`).
- **Nœud du chemin** : nœud du milieu (rang 3) et trésor (rang 8) ; tirage AU CLAIM au front : commun `[orange, orange]`, rare `[orange, noir]` 11 %, légendaire `[noir, noir]` 1 %, pitié (`20260829170000_regles_chemin.sql:35-51` ; `docs/screens/duolingo-chemin.md:96, 221, 264-265, 292` ; `PLAN-REWARDS-BACKEND.md:1099-1114` ; `RewardChemin.swift:159-205`).
- **Welcome back** : 10 pièces, aucun booster (`PLAN-REWARDS-BACKEND.md:994-1019` §4 duodecies ; grep « booster » sur `tools/rewards/ANALYSE-WELCOME-BACK.md` = 0).
- **Achat / noir** : orange 100 pièces ; noir 1 pièce d'argent = 1 légendaire garantie, la pièce d'argent TOMBE via `roll_rare` (p = 1/30, pitié 45, cooldown 10) ; manège noir séparé (`PLAN-REWARDS-BACKEND.md:606-649, 674-681, 714-760` ; `coffre-rewards.md:124-131`).
- **Conversion 100 pièces = 1 booster : NON implémentée** — `annonces.sql:37-46` refuse explicitement (`claim_booster` débite déjà 100) ; question ouverte (`PLAN-REWARDS-BACKEND.md:412-444, 1152-1171, 1275-1279` ; `coffre-rewards.md:287-293`).

---

## 3. La source de vérité des boosters en attente, et qui la lit

### 3.1 L'arbitre

- `SacreEtat.boostersEnAttente` n'est PAS un état : propriété calculée `@MainActor` qui lit `EconomieWoop.shared.boosters` et écrit `EconomieWoop.shared.maquetteBoosters = max(newValue, 0)` (`BoosterPopup.swift:62-66` → relevé L71-73). Idem `boostersNoirsEnAttente` → `boostersNoirs` / `maquetteNoirs` (`:82-86` → L91-93).
- `EconomieWoop.boosters = serveur ? boostersServeur : maquetteBoosters` (`EconomieWoop.swift:83`, relevé L83) ; `maquetteBoosters` naît à 1, en mémoire seulement (L85 ; aucun `UserDefaults` dans `EconomieWoop.swift` ni `BoosterPopup.swift`) ; `boostersNoirs = serveur ? argent : maquetteNoirs` (solde d'argent = sachets noirs) ; `serveur` (`private(set)`, L105) passe à `true` à la première réponse et ne redescend jamais (`:33-37`, « LE REPLI NE REVIENT JAMAIS EN ARRIÈRE »).
- **Vérité serveur** : `etat_coffre().boosters_or` = `count(*)` de `user_boosters` où `user_id = auth.uid() and origine <> 'legendaire' and opened_at is null` (`annonces.sql:49-62`, relu 30-08).

### 3.2 Écrivains

| Sens | Où | Preuve |
|---|---|---|
| `boostersServeur =` (relecture) | `appliquer(EtatCoffre)` → `boostersServeur = e.boostersOr` | `EconomieWoop.swift:181-189` |
| `boostersServeur += 1` | `appliquer(ClotureSeance)` si `booster_neuf` | `:197-204` |
| `boostersServeur += 1` | `acheterBooster()` après `claim_booster` réussi | `:243-262` |
| serveur, via `rafraichir()` | nœud chemin neuf : l'outbox appelle `rafraichir()` (réponse booléenne) | `OutboxGains.swift:212-222` (relevé L222) ; `RewardChemin.swift:194-204` (relevé L194-201) |
| **décrément local** | `onCarteEnvolee` : `sacre.boostersEnAttente = max(0, n − 1)` — n'écrit QUE `maquetteBoosters` ; en mode serveur, `boostersServeur` ne descend que par `consommerBooster` → `ouvrir_booster` → `rafraichir()` | `WoopApp.swift:1235-1250` → relevé L1246-1262 |
| **incrément de maquette** | **AUCUN** dans le dépôt : grep `maquetteBoosters` = init `= 1` (`EconomieWoop.swift:85`), setter (`BoosterPopup.swift:65` → L73), décrément (`WoopApp.swift:1240` → L1253-1256) | grep |

Insertion serveur des lignes `user_boosters` : `cloturer_seance` (origine `seance`), `reclamer_noeud_chemin` (`chemin`/`cadeau`), `claim_booster` (`achat`), `claim_booster_legendaire` (`legendaire`, sans appelant client) — §2.2.

### 3.3 Relecture serveur (`rafraichir`)

Cinq sites (grep `rafraichir(` ; relevé 30-08 concordant) : retour au premier plan après `OutboxGains.vider()` (`WoopApp.swift:97`) ; `ProfilLune` `.task { await economie.rafraichir() }` (`ProfilLune.swift:303`) ; `CoffreFortFlow` `.task { rafraichir(avecJournal: true) }` (`Woop/Views/CoffreFortView.swift:589`) ; outbox après nœud chemin neuf (`OutboxGains.swift:222`) ; après `consommerBooster` (`EconomieWoop.swift:287`). `CoffreV2.swift` n'appelle jamais `rafraichir`.

Garde : `EconomieWoop.possible` faux sous `-demoData` (sans `-syncNow`) ou si `WoopConfig.isConfigured` faux → tout reste en maquette (`EconomieWoop.swift:147-151, :162-163, :244, :282`).

### 3.4 Qui lit — la pill du profil

Header de `ProfilLune`, overlay `.bottomTrailing` : `HStack` avec `PillBooster(nombre: SacreEtat.shared.boostersNoirsEnAttente, robe: .noire)` SI `> 0` (relevé L563), puis `PillBooster(nombre: SacreEtat.shared.boostersEnAttente)` SI `> 0` (relevé L572), puis `pastillePieces` (`ProfilLune.swift:555-587`). Pas de pill à 0. Tap : pill noire → `ouvrirManege(robe: .noire)`, pill orange → `ouvrirManege(robe: .lune)` (`:562-578`) ; aucun débit ni `consommerBooster` à ce moment.

`PillBooster` (`BoosterPopup.swift:777-814` → relevé `struct PillBooster` L786) : `SachetVignette(15×26, robe:)` + `Text("\(nombre)")` Inter 15 bold `.contentTransition(.numericText())`, capsule `glassEffect(.regular.tint(black 0.5).interactive())`, kick puis `action()` à +0,22 s. `SachetVignette` (`:728-766` → relevé L737) : PNG du bundle `booster-pill` / `booster-pill-noir` par `Bundle.main.path`.

Panneau « TirageBooster » du profil : `ouvrirOuAcheter()` (`ProfilLune.swift:1255-1278`, relevé L1255) : si `economie.boosters > 0` → `ouvrirManege()` SANS robe puis `fermer()` ; sinon `acheterBooster()` puis idem.

### 3.5 Qui lit — le coffre

`CoffreV2Page` lit `EconomieWoop.shared` via `private var economie` (`CoffreV2.swift:1811`, relevé L1811). `variantes` : page ② `PiedVariante(solde: e.boosters, pill: (courant: e.reste, cible: prix), robe: .lune, bouton: e.boosters > 0 ? ("OUVRIR", true) : ("\(prix − e.reste) COINS TO GO", false))` ; page ④ `solde: e.boostersNoirs, robe: .noire, bouton: e.boostersNoirs > 0 ? ("OUVRIR", true) : ("LOCKED", false)` (`:2381-2434`) ; `PiedCoffre` → `DiamondPrimaryButton` sourd + `highPriorityGesture(TapGesture)` → `onOuvrir()` (`:1309-1312, :1412-1429, :3184-3185`).

Ouverture : `CoffreV2Page.ouvrirManege(_ robe:)` (`:2542-2564`, relevé L2542) : si `robe == .noire || economie.boosters > 0` → `onClose()` puis +0,45 s `SacreEtat.shared.ouvrirManege(robe:)` (L2546) ; sinon `economie.acheterBooster()` (L2551) et si `.obtenu` même séquence (L2561) ; refus → haptique `.warning`.

Montage : `CoffreFortFlow(coins:onClose:)` (4 appelants) monte `CoffreV2Page(coins: economie.or, gains: economie.journal, onClose:)` sauf `-coffreV1` ; `onAppear { poserMaquette }` puis `.task { rafraichir(avecJournal: true) }` (`CoffreFortView.swift:513-590`). Depuis le profil : `pastillePieces` → `showCoffre = true` à +0,34 s (`ProfilLune.swift:294-295, :751-761`, relevé L761) → `.fullScreenCover`. Depuis la home : `HomeNuit.ouvrirCoffre()` → `coffreOuvert` (`HomeNuit.swift:2277-2287, :3271-3274`).

### 3.6 « Later » et la réserve — les deux modes

- **Mode serveur** : « Later » n'a rien à ajouter — le sachet est inséré par `cloturer_seance` et `boostersServeur += 1` appliqué à la réponse, sans lien avec la card ; la pill (`> 0`) et la page ② le montrent dès `EconomieWoop.serveur == true` et la réponse arrivée ; hors ligne, l'outbox rejoue au retour premier plan puis `rafraichir()` (`OutboxGains.swift:190-205` ; `EconomieWoop.swift:197-204` ; `ProfilLune.swift:571-575` ; `CoffreV2.swift:2397-2408` ; `WoopApp.swift:84-98`).
- **Mode maquette** (sans compte / `-demoData` / non configuré) : `maquetteBoosters` n'est incrémenté par aucune ligne. Donc la pill affiche « 1 » dès le premier lancement sans séance ; séance + « Later » laisse « 1 » ; après UNE ouverture la pill disparaît (0) et le pied du coffre passe à « N COINS TO GO » ; la séance suivante + « Later » ne la ramène pas (`EconomieWoop.swift:85` ; `BoosterPopup.swift:65` → L73 ; `WoopApp.swift:1240` → L1253-1256 ; `ProfilLune.swift:571`). Le commentaire racine (relevé L1233-1245) documente le `max(1, …)` d'antan qui rendait le compteur invariant.
- **Effet de bord serveur après ouverture** : le décrément local n'atteint que la maquette ; le nombre affiché ne descend que si `ouvrir_booster` réussit puis `rafraichir()` ; si l'appel échoue (404 avalé), pill et « OUVRIR » restent allumés (`WoopApp.swift:1235-1250` → L1246-1262 ; `EconomieWoop.swift:280-293` ; `SacreServeur.swift:325-326`).
- **Noir du chemin** : un sachet `origine='chemin', robe='noire'` est compté dans `boosters_or` (`origine <> 'legendaire'`) et NON dans la pill noire (`boostersNoirs = argent`) — divergence structurelle entre `user_boosters.robe` et le filtre `origine` (`annonces.sql:59-62` ; `gains_coffre.sql:287-290`).

Docs : `PARCOURS-BOOSTER.md:143-176` (« Le booster n'est jamais perdu » ; la pill = « le nombre de boosters non ouverts », « la même requête que celle du manège », survit au relancement via `user_boosters` ; « promis localement et réclamé au premier lancement connecté ») ; `docs/screens/notification.md:117` (« Plus tard ferme, le sachet reste dans `boostersEnAttente` (maquette : 1 en mémoire) ») ; `coffre-rewards.md:44-46, :106` (à 0 le bouton « Ouvrir » n'existe pas ; cible « Locked » à trancher).

---

## 4. Les contradictions (citées, non tranchées)

### 4.1 État git des fichiers et numéros de ligne
- Rapport flow : « `WoopApp.swift`, `BoosterPopup.swift`, `BoosterCard.swift`, `StoryFlow.swift`, `StoryEnded.swift` : propres (HEAD). `StorySuite.swift` : M ».
- Relevé 30-08 (`git status --short`) : ` M Woop/WoopApp.swift`, ` M Woop/Views/BoosterPopup.swift`, ` M Woop/Views/BoosterCard.swift`, ` M Woop/Views/StorySuite.swift` (`git diff --stat HEAD` : BoosterCard 88 lignes, BoosterPopup +9, WoopApp 24). HEAD est `fc473c9` (30-08 13:23, « le manège reprend la déchirure où la card l'a laissée »), postérieur aux rapports. Conséquence : les lignes `WoopApp.swift` au-delà de ~L1180 et `BoosterPopup.swift` au-delà de ~L40 des rapports flow et coffre sont décalées (+8 à +12) ; les relevés 30-08 sont notés en regard dans ce document. La propriété `SacreEtat.morsureCard` et le paramètre `onOuvrir: (Float?) -> Void` (`BoosterCard.swift:33`) n'existent dans aucun des trois rapports.

### 4.2 Déploiement de `ouvrir_booster`
- Rapport backend (mesuré 30-08) : `supabase migration list --linked` montre `20260829150000` côté remote ; sonde anon → 401 42501 (la fonction existe) ; conclusion « les commentaires NON DÉPLOYÉE sont PÉRIMÉS ».
- Rapport coffre : « le commentaire dit que la migration est NON DÉPLOYÉE (tant qu'elle ne l'est pas : 404 avalé, le compte ne descend pas) » ; inconnue déclarée « impossible de vérifier à distance ».
- Code (relevé 30-08, toujours présent) : `SacreServeur.swift:325-326` et `EconomieWoop.swift:274-279` affirment NON DÉPLOYÉE ; `docs/site/index.html:611` est cité comme « litige ».
- Non tranché ici : aucune commande réseau exécutée dans cette fusion.

### 4.3 La place de la story dans la fin de séance
- Code : aucune story dans `terminerSeance()` ni dans `HomeNuit` (§1.6).
- `ANALYSE-VARIANTS-ET-FAITS.md:149-150` : « la story démarre deux secondes après « Terminer » ».
- `PLAN-STORY-V2-ENDED.md:224-236` : « La fin de séance ne lance toujours PAS la story (branchement à venir) ».
- `PLAN-STORY-WIN.md:10-22, :123-125` : la page butin montre les boosters de la séance et « la pop-up booster vue = pris en compte ».
- `woop-flow-complet.md`, `PARCOURS-BOOSTER.md`, `BUGS-RESTANTS.md` : aucune story dans le flow canonique.

### 4.4 La minuterie de la pop-up (+5,2 s) vs la règle « une annonce par événement »
- Code : capsule pièces +1,6 s ET `proposer()` +5,2 s (`WoopApp.swift:501-511`).
- `PLAN-REWARDS-BACKEND.md:1198-1223` (§4 quaterdecies, verdict 29-08) : une seule annonce par événement — « ce que la règle interdit ». Robe 4 « booster » de la notif vs pop-up : non tranchée (`notification.md:139`).
- `PARCOURS-BOOSTER.md:34-37` (15-08) : « Ce branchement n'est PAS fait » — périmé par `WoopApp.swift:509-511`.
- `woop-flow-complet.md` (C) : « proposer() +5,2 s (1,8 s si gain 0) » — la branche 1,8 s n'existe plus (`WoopApp.swift:508`).

### 4.5 La porte `clotureDemandee`
- Code : lue et remise à `false` (`WoopApp.swift` L1377-1380), déclarée (`DepartSeance.swift:39`), jamais écrite à `true`.
- Mémoire `woop-flow-complet.md` : l'écrivain attendu serait le `onEnd` de `SessionSlate`/`StopSessionSheet` — non retrouvé (inconnue flow, non levée).

### 4.6 Le compte de sachets et « Later »
- Rapport coffre (4) : « en mode MAQUETTE, « Later » n'ajoute RIEN — et c'est là le manque » et propose un incrément de maquette (`maquetteBoosters += 1` dans `terminerSeance` ou `proposer`).
- Rapport backend : « Plus tard : aucun état local d'attente : le sachet reste en `user_boosters` … se reprend par la PillBooster » ; doctrine `PARCOURS-BOOSTER.md:143-157`.
- `PARCOURS-BOOSTER.md:143-176` : « le booster doit être promis localement et réclamé au premier lancement connecté » — le code ne promet rien localement (aucun incrément de maquette, aucune file pour le sachet lui-même ; seule la clôture est en outbox).
- `notification.md:117` : « le sachet reste dans `boostersEnAttente` (maquette : 1 en mémoire) » — décrit l'invariant « 1 », pas une réserve qui monte.

### 4.7 La pile noire
- `claim_booster_legendaire` pose `opened_at = now()` (`wallet_coffre.sql:136-138`) ; `ouvrir_booster(true)` exige `opened_at is null` (`ouvrir_booster.sql:56-64`) — les deux fonctions ne s'accordent pas sur ce qu'est un sachet noir « ouvrable ».
- `boostersNoirs = argent` côté client (`EconomieWoop.swift`) vs un sachet `robe='noire'` du chemin compté dans `boosters_or` côté serveur (`annonces.sql:59-62`).
- `claimLegendaire` sans appelant (grep 30-08) vs doctrine « 1 pièce d'argent = 1 légendaire garantie » (`PLAN-REWARDS-BACKEND.md:606-649`).

### 4.8 Forge et sachet
- `ForgeServeur.tirer` accepte `boosterId` (`ForgeServeur.swift:31-43`) et forge-card scelle `card_id` (`index.ts:261-269`) ; `BoosterLab.lancerForge()` n'envoie pas de `boosterId` (`BoosterLab.swift` L2286). `PLAN-BOOSTER-NOIR.md:452-467` déclare forge-card déployée avec la garantie ; la garantie n'est jamais armée côté client.

### 4.9 Petites divergences de références
- `PLAN-STORY-V2-ENDED.md` cite `HomeNuit.swift:1221` pour le branchement story ; le site réel est `HomeNuit.swift:1291` / `:3021-3036` (rapport flow).
- `BoosterPopup.swift:101-102` « aujourd'hui le bouton d'essai ; demain la fin de séance » vs `WoopApp.swift:510` qui appelle déjà `proposer()` à la fin de séance.
- Rapport backend : `docs/site/content/` non suivi et le commit `6557a90` dit qu'une autre session refond le site — quelle version du site fait foi n'est pas établi.

---

## 5. Les inconnues restantes

**Levées par le relevé 30-08** (pour mémoire) : `StoryCine.hold = [12.6, 7.0, 7.0]` (`StoryFlow.swift:169`) ; le filtre de `boosters_or` exclut bien `origine = 'legendaire'` (`annonces.sql:59-62`) ; la home montée en production est `HomeNuit` (`WoopApp.swift:976`, `HomeAuroraView` = archive `:975`) ; le décrément `onCarteEnvolee` n'a plus de `max(1, …)` (commentaire racine L1233-1245).

**Toujours ouvertes :**

Flow
1. Qui devait écrire `clotureDemandee = true` (onEnd de `SessionSlate`/`StopSessionSheet` selon la mémoire) — non retrouvé ; non vérifié si `SessionSlate` porte encore un `onEnd` débranché.
2. Ce que fait `PiecesNotif` (`WoopApp.swift` L1152) pendant les 3 s, et si la `NotifCard` non commitée (`NotifLab`) est branchée à la place — non lu.
3. `HomeAuroraView.notifPieces` onChange (`:210`) — archive, non lu.
4. Si la story fermée par tirage pendant `conduct()` peut appeler `onClose` deux fois (`StoryPortal.close()` a la garde `closing`, `StoryFlow.swift:615-616`) — séquence temporelle non vérifiée.
5. `docs/screens/*` (coffre-rewards, duolingo-chemin, notification, reward-popup) non relues sur la place du booster dans le flow ; `tools/sacre/PIEGES-ET-FIX.md` et `PLAN-BOOSTER-CARD.md` : grep « fin de séance/terminerSeance/story » vide.
6. Ce que change exactement le commit `fc473c9` (morsure de la card reprise par le manège) dans la séquence card → manège : lu en surface (`WoopApp.swift` L1186-1190), pas relu dans `BoosterCard.swift` (88 lignes modifiées non commitées).

Back-end
7. Si la version de forge-card réellement déployée est celle du dépôt (aucun `functions list`/diff exécuté).
8. Si un vrai compte a déjà une ligne `user_boosters origine='seance'` (le commit `2972f14` dit que le tuyau n'était jamais déclenché avant le fix de la série muscu).
9. Si `ouvrir_booster` a été vue faire descendre la pile sur un compte connecté (le site marque « à mesurer ») — et donc laquelle des deux lectures du §4.2 est la bonne aujourd'hui.
10. Alignement 200/500 de `claim_booster_legendaire` — « à trancher » (`PLAN-REWARDS-BACKEND.md:1321-1324`), pas de migration.
11. Robe 4 « booster » de la notification vs pop-up à +5,2 s — non tranché (`notification.md:139`).
12. Conversion automatique pièces → sachets (§4 sexies) et l'origine `'pieces'` — jamais codées ; question d'économie ouverte (`coffre-rewards.md` §6.7).
13. « Un nœud rend deux sachets sous un index (user, nœud) » : contournement `'chemin'` + `'cadeau'` (`gains_coffre.sql:276-283`), décision non prise.
14. Où commence un chapitre du chemin (`regles_chemin.sql:14-21`) — le chemin reste en mode démo.
15. Quelle version du site de doc fait foi (`docs/site/content/` non suivi, refonte par une autre session).
16. Si `SupabaseSession.shared.token()` aboutit au simulateur (le site dit `notAuthenticated`) — non mesuré.

Coffre / pill
17. Si, sur téléphone/sim avec compte connecté, `cloturer_seance` répond `booster_neuf = true` et la pill apparaît après « Later » — déduit du code, pas mesuré.
18. `CoffreV2.swift` (~3 800 lignes) non relu intégralement hors pied, variantes, ouverture, récit, socle.
19. Comportement des bancs (`-boosterManege`, `-sacreNoir`, `-profilSacre`, CoffreV2 lab, `CoffreV2.swift:3796-3798`) si `maquetteBoosters` passait de 1 à 0 — non exécuté.
20. Si `RewardCheminEtat` ou la card du chemin annonce quelque chose à la pill quand le tirage rend des sachets hors ligne — aucun incrément local trouvé.
