# Écran — LA NOTIFICATION DE GAIN (le toaster)

`Woop/Views/NotifCard.swift` (le template, la jauge, le gros texte) ·
`Woop/Views/NotifChasse.swift` (la châsse) · banc `Woop/Views/NotifLab.swift`
(`-notifLab`) · plans `tools/notifs/PLAN-NOTIFS-V8.md` et `-V9.md` ·
**le contrat par catégorie : `tools/annonces/PLAN-COFFRE-ANNONCES.md` §3**.

> **Convention de ce document.** Ce qui est écrit sans marque est **vérifié
> dans le code** (29-08, relecture adverse ligne par ligne ; **relu le 30-08
> au soir**, numéros de ligne relevés ce jour-là — ceux de `WoopApp.swift`
> bougent, une autre session l'édite). Ce qui porte **?** n'est pas sûr et
> attend une décision ou une vérification. Ce qui porte **CIBLE** est décidé
> mais **n'existe pas encore**. Ce qui porte **TRANCHÉ 30-08** a été décidé
> par Kathryn le 30-08 (plan §0-§1) et remplace un **?** d'hier. Ce qui porte
> **périmé** décrivait l'état d'avant `8e8a0cc` (la story dans la chaîne) ou
> `9ef6da1` (le tirage du chemin au serveur) — gardé pour l'histoire, plus
> une mesure. Les tables de la base ne sont pas décrites ici : seulement ce
> que le backend doit **décider** et **renvoyer**.
>
> ⚠️ **La dalle elle-même est CIBLE** : elle n'existe que sur son banc. Ce qui
> est vérifié, c'est ce qu'elle remplace, ce qui la déclenchera, et ce qui
> part au serveur autour d'elle.

**Ce qui a changé depuis la première écriture (29-08) — en une lecture :**

| quoi | avant (périmé) | maintenant |
|---|---|---|
| la chaîne de clôture | capsule à +1,6 s et pop-up booster à +5,2 s, **minuteries fixes depuis « Terminer »**, sur une home nue | **`8e8a0cc`** : la story à +2,0 s après « Terminer » ; **à sa fermeture** la capsule à +0,3 s (retirée à +3,3 s) puis la card booster à +3,4 s (`WoopApp.swift:532-535`, `:543-556`) |
| le tirage du chemin | local (`TirageRecompense.tirer`), « rien ne le poste » | **`9ef6da1`** : au serveur, `tirer_noeud_chemin` via `RewardChemin.tirerAuServeur` (`RewardChemin.swift:224-235`) ; la dalle vient après la card, pièces seulement (`:281-296`) |
| la réponse de `cloturer_seance` | « lue par aucun écran, `print` seul » | **lue** : 8 champs décodés (`SacreServeur.swift:195-226`), appliqués par l'outbox (`OutboxGains.swift:205` → `EconomieWoop.swift:207-212`). Ce qui reste vrai : **aucune annonce** ne lit `argent` ni `booster_neuf` |
| `claim_booster_legendaire` | 500 `P0002` sur un refus | **`9ef6da1`** : 200 avec `raison: argent_insuffisant` (migration `20260830160000_sachet_scelle_et_tirage.sql:96-100`) |
| robe 4 (booster) vs pop-up | trois lectures, non tranché | **TRANCHÉ 30-08** : la dalle booster va dans la **pile** de la page noire ; la pop-up « Ouvrir » vient **après le chemin** et n'est qu'une **invitation** (plan §1 Q4, §3) |
| Welcome Back | +10 partent seuls au premier plan, jour UTC, aucune dalle | **TRANCHÉ 30-08** : bouton **Claim**, +10 **au tap**, jour = **minuit Paris** (règle serveur), dalle « +10 » dans l'app au tap, **pas** de notification iPhone (plan §0, §1 Q7-Q8) |
| « chargement : n'existe pas, et c'est la loi » | absolu | **nuancé 30-08** : la page noire accepte « un petit chargement » **borné à 4 s** parce que la pièce d'argent est tirée au serveur ; la dalle **de série** reste locale (plan §2.7, §5.1 point 3) |

**Ce qu'elle remplace** — il y a aujourd'hui **DEUX** toasters, pas un :
`PillGain` (`Woop/Views/RestartSheet.swift:536`, montée
`ExerciseDetailView.swift:1033`, pendant la séance) et `PiecesNotif`
(`Woop/Views/PlayerSeance.swift:260`, montée `WoopApp.swift:1237-1244`, sur la
home après la story de clôture, et après un claim du chemin).

---

## 1 · Rôle

**Dire un gain sans interrompre.** Ce n'est pas une pop-up : personne n'a
rien à taper, l'écran dessous reste vivant, elle descend, tient, et repart
seule. C'est la face visible de la loi des 20 (*« soixante pour cent des
séries ne méritent pas une pop-up, elles méritent qu'on dise merci et qu'on
s'efface »* — `PillGain`).

Elle répond à deux questions, dans cet ordre :

1. **Qu'est-ce que je viens de gagner** — le chiffre, qui monte.
2. **Où ça me mène** — la progression vers le prochain sachet (la jauge), ou
   l'objet gagné (la pièce, le sachet).

**CIBLE — une famille, un template, cinq robes** (TRANCHÉ 30-08 : quatre
hier, **plus la robe « argent »**, plan §3 et §5.1 point 2). Les trois robes
« pièces » se succèdent en variant (verdict du 29-08 : *« on a 4 variants
donc tu peux les faire varier »*), la robe « booster » s'affiche quand le
gain est un sachet, la robe « argent » quand la pièce d'argent tombe
(1/30 à la clôture). Aucune robe n'est clouée à un moment.

**Pourquoi elle remplace les deux toasters** : ils disent la même chose avec
deux looks (verre `.regular` teinté pour l'un — hors la loi du verre,
`RestartSheet.swift:563-564` —, `.clear` pour l'autre), deux langues
(« this session » / « pièces lune ») et deux durées (2,0 s / 3,0 s).
CIBLE : un gain se dit d'une seule façon.

---

## 2 · Affiche

### 2.1 Aujourd'hui — les deux toasters

| toaster | ce qu'on voit | où | durée |
|---|---|---|---|
| `PillGain` | `piece-or-mini` · `+20` · `· 140 this session` ; verre `.regular` teinté noir 0,34, capsule de 44 pt | haut de la fiche exo, padding 8, `zIndex 30` | **2,0 s** puis 0,30 s de sortie (`ExerciseDetailView.swift:2292-2293`) |
| `PiecesNotif` | disque de braise · `+240` (le compte roule en trois paliers) · `pièces lune` ; verre `.clear` sous une capsule noire 0,35 | haut de la racine (`WoopApp.swift:1237-1244`), padding 8, `zIndex 9` | **3,0 s** (clôture : **+0,3 s → +3,3 s après la fermeture de la story**, `WoopApp.swift:547-552` ; *périmé depuis `8e8a0cc` : « +1,6 s → +4,6 s depuis Terminer »*) · **3,2 s** (chemin, `RewardChemin.swift:291-293`) |

Les deux sont sourds au doigt (`allowsHitTesting(false)`). ⚠️ Le vol de
pièces qui devait accompagner la capsule (`VolDePieces`, 2,6 s) vit dans
`HomeAuroraView` — une vue **en archive** : l'onglet Accueil monte
`HomeNuitPage` (`WoopApp.swift:1055`), qui n'écoute pas `notifPieces`.
Aujourd'hui la capsule descend seule.

### 2.2 CIBLE — la dalle

**La dalle** : 138 pt de haut, coins 28, **noire et opaque** (pas de verre —
elle se juge sur la nuit vraie), liseré blanc 0,16 → 0,03, ombre. Le gabarit
est celui de la card OPAL de référence (capture du 28-08, hors dépôt). Entrée
par `offset` + `opacity`, jamais un redimensionnement (loi du verre aux bounds
vivants).

| # | Robe | Ce qu'on voit | Ce qu'elle porte | état |
|---|---|---|---|---|
| 1 | **LA JAUGE** | `+20 COINS EARNED` (le chiffre monte de 0), `VAULT PROGRESS`, une barre de 3 pt à dégradé blanc avec de la poudre de diamant **dedans** (clippée), une pièce d'or qui tourne (9 s/tour) et mord le bord droit de 16 pt | le gain, la fraction de jauge | au banc |
| 2 | **LE GROS TEXTE** | `YOU WIN` à 104 pt, **rogné** (le U et WIN coupés — prérequis), très fondu, la vidéo matrice dans le glyphe, un projecteur qui descend du haut, les lettres qui naissent une à une, une pièce (54 pt) au centre, `+20 COINS` | le gain | au banc |
| 3 | **LA CHÂSSE** | Nosfy en vidéo (boucle 1,500 s, 78 Ko, `Woop/Media/nosfy-notif-loop.mp4`) au centre, poudre de diamant de ses ailes, `+20` avec un halo de lumière qui respire, `COINS EARNED`, un galet de verre sur l'aile droite, une lueur dans le coin bas droit | le gain | au banc |
| 4 | **LE BOOSTER** | la jauge, avec le sachet **orange** détouré (`booster-orange`) qui lévite à la place de la pièce ; `+1 BOOSTER EARNED` ; seconde ligne **?** | le sachet (forfaitaire de clôture, converti à 100, ou tiré au chemin) | **TRANCHÉ 30-08 : à coder** (V9 §A, plan §5.1 point 2) — pas une ligne aujourd'hui |
| 5 | **L'ARGENT** | **?** non dessinée — la pièce d'argent (`piece-argent`, 186 · 170 · 153) | la pièce d'argent tombée à la clôture (`cloturer_seance.argent`) | **TRANCHÉ 30-08 : à coder** (plan §0 « pièce d'argent », §3) — n'existe nulle part |

**Ce que la jauge montre aujourd'hui** : `fraction = 0,62`, **une constante de
démonstration** (`NotifCard.swift:148`). Elle ne lit aucun serveur.
**TRANCHÉ 30-08** : elle lira `EconomieWoop.reste / prixBooster`
(`EconomieWoop.swift:101-103` — ces deux valeurs existent déjà, appliquées à
chaque réponse de `cloturer_seance`, `:207-212`) ; fin du `0,62` en dur (plan
§5.1 point 2).

**Un gain qui n'est pas 20** — **TRANCHÉ 30-08, à dessiner** : le banc ne
connaît que `+20`, mais un nœud du chemin donne **+100 à +200** (176 tiré au
banc serveur le 30-08) et le Welcome Back **+10** — les deux montants
« se dessinent » (plan §5.1 point 2). La question d'hier (« la jauge
déborderait les 100 pièces d'un sachet : pleine puis repart ? deux
sachets ? ») est fermée par la **conversion automatique** : à 100 pièces un
sachet apparaît tout seul, les pièces **retombent**, et chaque sachet
converti a **sa propre dalle** robe booster dans la pile (plan §0 « la
jauge », §3 « sachet(s) converti(s) », serveur `convertir_pieces` M1 — **rien
de tout ça n'existe** au 30-08 soir).

**Position** : **?** — en haut, sous la barre d'état, comme les deux
d'aujourd'hui, est l'hypothèse ; le banc les empile au centre et la position
finale n'a pas été jugée. **Reste ouvert** le 30-08.

**Durée** : **?** — les films du banc mettent ~1,3 s à se poser (délai 0,35 s
+ ressort 0,62 s + la montée de la barre). 3,2 s partout **me semble** le
minimum pour lire le chiffre et voir la barre monter ; rien n'est mesuré.
**Reste ouvert** le 30-08 (le contrat §3 dit « 2 s » pour la dalle de série,
sans mesure).

**Langue** : **?** — le template est en anglais, `PiecesNotif` parle français,
`PillGain` anglais ; à trancher une fois. **Reste ouvert** le 30-08.

**Empilement** : **TRANCHÉ 30-08** — plus un `Int?` unique, **une FILE typée**
`[Annonce]` (pièces · booster · argent · retour +10) que l'hôte de la racine
empile l'une sous l'autre ; `PiecesNotif` devient un cas de la file (plan
§5.1 point 1). Aujourd'hui : `notifPieces: Int?` (`DepartSeance.swift:43`),
voir §5 « deux gains qui se suivent ».

---

## 3 · Actions

| # | Action | Geste | Appel backend |
|---|---|---|---|
| A1 | **Aucune** — la dalle est traversée | un tap la traverse et atteint l'écran dessous (`allowsHitTesting(false)` chez les deux toasters actuels ; CIBLE : la dalle pareil) | **aucun** — l'appel part de l'événement qui la fait naître, jamais d'elle |

**Ce qui la déclenche**, moment par moment — ce que le code fait (relu le
30-08), ce qui part au serveur à cet instant, et ce qui est décidé (le
contrat complet par catégorie : **plan §3**) :

| Moment | Aujourd'hui (relu 30-08) | Appel backend aujourd'hui | Décidé (plan §3, §5) |
|---|---|---|---|
| **une série finie** | `DecideurSerie.pour` (`RestartSheet.swift:611`, appelée `ExerciseDetailView.swift:484-485` et `:2242-2243`) rend `.pill` hors des multiples de 3/5/10 → `PillGain` 2,0 s → la question « Recommencer ? » **0,22 s** après sa sortie (`:2292-2296`) | **aucun** — `settleSeries` n'écrit que le **brouillon en mémoire** de la fiche (`@State sets: [DraftSet]`, `:125`) ; rien n'est persisté en SwiftData à la fin d'une série (la seule écriture est `save()`, au geste de l'utilisateur) | **dalle « +20 », 2 s, pièces en rotation, locale** — le taux vient du serveur (`gainParSerie` lit `EconomieWoop.shared.piecesParSerie`, `:2257`). La dalle **ne consomme pas** le budget des pop-ups (plafond 6 par séance). *Périmé* : l'idée d'une « outbox au grain de la série » — le contrat §3 la dit locale, point |
| **la clôture** (« Terminer ») | `terminerSeance()` (`WoopApp.swift:455-536`) : `gain = séries × piecesParSerie` (`:472-473`), ferme la pause, sauve, **bascule toujours sur la home** (`:489`, et `celebrateFinishedWorkout()` `:1666-1673` force `.home` une seconde fois) ; si gain > 0 : le trophée (`:485`), `maquetteBoosters += 1` (`:524`), **la story à +2,0 s** (`:532-535`). **À la fermeture de la story** (`storyFinHote` `:565-576`), `enchainerApresStory()` (`:543-556`) : `notifPieces = gain` — **le calcul local** — à +0,3 s, retiré à +3,3 s, puis `SacreEtat.shared.proposer()` à +3,4 s. *Périmé depuis `8e8a0cc`* : « `PiecesNotif` à +1,6 s, la pop-up booster à +5,2 s » | `SupabaseSync.push([snapshot])` **puis** `cloturer_seance(p_workout, p_series)` via l'outbox, dans une seule `Task.detached` (`:510-513`), jamais attendue → `{pieces, pieces_creditees, booster_id, booster_neuf, solde, argent, reste, prix_booster}`. **La réponse EST lue** (`SacreServeur.ClotureSeance` `:195-226` décode les 8 champs ; `OutboxGains.swift:191-205` → `EconomieWoop.appliquer` `:207-212` : or, `reste`, `prixBooster`, `argent += 1`, `boostersServeur += 1`). ⚠️ Ce qui reste vrai : **aucune annonce ne regarde `argent` ni `booster_neuf`** — la pièce d'argent finit dans le `print` de `OutboxGains.swift:195-199` ; la capsule affiche `storyGain`, pas `r.pieces`. *Périmé* : « la réponse n'est lue par aucun écran » | **TRANCHÉ 30-08** : story → **une page noire** (« un petit chargement », borné 4 s, attend la réponse de `cloturer_seance` publiée par l'outbox ; repli « local, dit comme tel ») où les dalles **s'empilent** : pièces (jauge) → sachet forfaitaire (robe 4) → sachet(s) converti(s) → pièce d'argent (robe 5) → **retour sur le CHEMIN**, animation « séance terminée » → **puis** la pop-up « Ouvrir » (plan §0, §5.1). Pièces + sachet = **deux événements, deux annonces** — la doctrine « une annonce PAR événement » tient |
| **un claim du chemin** | `RewardCheminEtat.reclamer` (`RewardChemin.swift:182-221`) : **le tirage est au serveur** (`tirerAuServeur` `:224-235` → `SacreServeur.tirerNoeudChemin`, puis `EconomieWoop.rafraichir()`) ; sans compte, le tirage local d'hier, **dit comme tel**, et rien n'est écrit. À `fermer()` (`:281-296`) : `PiecesNotif(montant)` à +0,3 s pour 3,2 s, **seulement si le tirage est en pièces** (`:286`) — rien pour un tirage en sachets. *Périmé depuis `9ef6da1`* : « le tirage est local, rien ne le poste » | `tirer_noeud_chemin(p_noeud, p_pieces)` — synchrone (la révélation a besoin du résultat), idempotent (rejoué, rend le stocké : sondé 30-08, 176 jaunes rejoué identique). `reclamer_noeud_chemin` n'est plus qu'un délégué (`OutboxGains.swift:212-214`, cas hérité) | **TRANCHÉ 30-08** : la card à gratter **ET une dalle après** — pièces (**+176** à dessiner) **ou booster** (robe 4) selon le tirage (plan §0 « nœud du chemin », §5.4 point 13) |
| **Welcome Back** | **aucune logique de production** ne choisit `.welcome` (le décideur n'émet que galet/halo/fire). Le chip « … » de la fiche exo qui faisait tourner les six robes vit **derrière `-rewardAtelier`** (`ExerciseDetailView.swift:1887-1893`) — *périmé* : « monté sans drapeau, deux taps ouvrent Welcome Back en prod ». La card `.welcome` existe en deux robes, son « Claim » = `fermer()` (`RewardCard.swift:874`), sans réseau | **branché le 29-08, dans le mauvais sens** : à chaque `scenePhase == .active` (`WoopApp.swift:83-92`), `reglerRetourQuotidien()` (`SacreServeur.swift:282-291`) poste `.retourQuotidien` **une fois par jour UTC** (marqueur `UserDefaults`) → `claim_retour_quotidien()` (`gains_coffre.sql:135-162`, jour UTC `:149-151`) → **les +10 partent tout seuls, sans tap, sans dalle** | **TRANCHÉ 30-08** : la pop-up vit sur la **home**, au premier plan, si `etat_coffre().retour_disponible` (clé nouvelle, lue sans payer) ; **bouton Claim** → outbox `.retourQuotidien` → **dalle « +10 » au tap** (le montant est local, le journal rattrape ; « déjà pris » sur un autre appareil = rien de plus) ; **jour = minuit Paris** par une règle serveur `fuseau_jour`, jamais le fuseau du téléphone ; **pas de notification iPhone** ; `reglerRetourQuotidien()` sort du `scenePhase` (plan §0, §1 Q7-Q8, §4 M1, §5.3). *Périmé* : « la dalle +10 seulement si `credite` » — au tap, avant la réponse |
| **un booster gagné** | la card booster `SacreEtat.proposer()` à +3,4 s après la story (`WoopApp.swift:553-555`, `BoosterPopup.swift:111-124`) ; « Plus tard » ferme, le sachet **est déjà au coffre** : `boostersEnAttente` lit `EconomieWoop.boosters` = `boosters_or` du serveur (`BoosterPopup.swift:71-74`) — *périmé* : « maquette : 1 en mémoire ». Aucune dalle | dans `cloturer_seance` (`booster_neuf`, un sachet forfaitaire par séance, index `(user_id, workout_id)`) — le même appel que les pièces ; sondé 30-08 ×2, même `booster_id` | **TRANCHÉ 30-08** : **robe 4 dans la pile** de la page noire (elle annonce) ; la card « Ouvrir » vient **après le chemin** et n'est qu'une **invitation** (plan §1 Q4, §3 « après la route animée ») |
| **une pièce d'argent** (1/30) | **rien** — `argent: true` arrive (`SacreServeur.swift:204`, `EconomieWoop.swift:211`) et personne ne l'annonce | `cloturer_seance.argent` (`roll_rare` privée, pity 45, cooldown 10 ; `annonces.sql:342-348`) — vrai **une seule fois** : rejouée, la fonction rend des zéros (`:354-363`) | **TRANCHÉ 30-08** : **robe 5 « argent » dans la pile** ; et pour que la page noire survive à un kill, `cloturer_seance` rejouée devra rendre **le stocké** (`rejeu: true`), pas des zéros (plan §4 M1 point 5) |

⚠️ **La règle qui commande tout** (plan backend §1) : **l'UI affiche le gain
tout de suite, le ledger rattrape.** C'est le comportement de
`terminerSeance` : l'appel vit dans une tâche qui *« ne propage jamais son
échec »*. **Nuancé le 30-08** : la page noire de clôture **attend** la
réponse de `cloturer_seance` (borne 4 s) parce que la pièce d'argent est
tirée au serveur et n'est connue que par elle ; passé la borne, ou sans
compte, ou hors ligne, elle affiche le **repli local, dit comme tel**
(pièces × taux, sachet forfaitaire, pas d'argent). La dalle **de série**, elle,
reste locale et immédiate — une dalle qui attendrait la réponse arriverait,
en cas de réseau lent, après la série suivante.

---

## 4 · Sorties

**La dalle ne mène nulle part** : elle s'efface et l'écran dessous continue
là où il était. Ce qui compte, c'est ce qui vient **derrière** elle.

| Depuis | Vers (aujourd'hui) | Décidé 30-08 |
|---|---|---|
| une série finie (fiche exo) | la question **« Recommencer ? »** (`poserLaQuestion`, `ExerciseDetailView.swift:2304`) — **0,22 s** après la sortie de la pill (`:2294-2296`) ; *« un seul chemin vers le panneau »* : c'est la fermeture de ce qu'on montre qui pose la question (une pop-up fermée la pose à 0,26 s, `:1137-1141`) | inchangé |
| la clôture | la **card booster** à +3,4 s **après la fermeture de la story** (`WoopApp.swift:553-555`) — chaînée à la story, pas à la capsule (la capsule est retirée à +3,3 s, la card monte à +3,4 s : elles ne se superposent pas). *Périmé depuis `8e8a0cc`* : « la pop-up booster à +5,2 s, une minuterie fixe depuis Terminer, pas chaînée à la fin de la notif ; si la dalle se pose à +1,6 s elle a 3,6 s avant que la pop-up monte dessus » | la pile de la page noire rend la main → **le CHEMIN** (`selection = .home` `:489` et `celebrateFinishedWorkout()` `:1669` à rediriger ; `rafraichirReclamees()` à la clôture, pas seulement à l'`onAppear`), animation « séance terminée » sur la route → **puis** la card « Ouvrir » (signal « route posée », plus une minuterie) → droit au manège (plan §1 Q6, §5.1 points 3-6) |
| un claim du chemin | retour au **chemin** (`RewardChemin.swift:287`). *Périmé* : « CIBLE : un toaster des gains puis redirection immédiate vers le COFFRE » — les mots du 30-08 ne parlent plus d'escale coffre (plan §1 Q6) | la dalle (pièces ou booster) sur le chemin ; rien derrière |
| Welcome Back | **aucune pop-up de production** ; les +10 sont versés en silence au premier plan (§3) | la pop-up vit sur la **home** ; **Claim** → dalle « +10 » sur la home au tap, rien derrière ; « Later » ferme et la card revient au prochain premier plan du même jour (plan §5.3). *Périmé* : « si le serveur répond `credite = false` : pas de dalle » — la dalle part au tap ; un « déjà pris » n'affiche rien de plus |
| un booster gagné (robe 4) | **aucune robe 4** — seule la card booster à +3,4 s | **TRANCHÉ 30-08** : la robe 4 **annonce** (dans la pile), la card « Ouvrir » **invite** (après le chemin). *Périmé* : les « trois lectures » du 29-08 (remplace la pop-up / après « Plus tard » / sachets du chemin seulement) — aucune des trois n'est la réponse |
| un tap sur la dalle | **rien** — elle est traversée | inchangé |

**Qui la monte** — CIBLE, **confirmé 30-08** : un seul hôte, la racine.
Aujourd'hui `PillGain` vit dans la fiche exo et `PiecesNotif` à la racine
(`WoopApp.swift:1237-1244`) ; la racine est le seul endroit d'où la dalle
peut se poser sur n'importe quel écran (home, fiche, chemin). La page noire
(`PileAnnonces.swift`, CIBLE) se monte à l'`onClose` de la story, zIndex
entre la story (15) et la poussière (20) — plan §5.1 point 3.

---

## 5 · États

| État | Aujourd'hui | Décidé 30-08 |
|---|---|---|
| **chargement** | **n'existe pas** : le montant est **local** (`séries × piecesParSerie`, `WoopApp.swift:473`, ou le tirage rendu par le serveur pour le chemin), jamais attendu du réseau à la clôture. La jauge du banc : `0,62`, constante (`NotifCard.swift:148`) | **nuancé** : *périmé* « et c'est la loi ». La **page noire** de clôture accepte « un petit chargement » **borné à 4 s** (la pièce d'argent est tirée au serveur) avec un repli local dit comme tel (plan §2.7, §5.1 point 3). La dalle **de série** reste sans chargement. La jauge lit `EconomieWoop.reste / prixBooster` — déjà appliqués à chaque réponse (`EconomieWoop.swift:207-212`), donc pas de nouveau cache à inventer ; *périmé* : « elle partirait du dernier `reste` connu et la réponse ne corrige que le cache » |
| **vide** (gain = 0) | **pas de dalle** — `terminerSeance` ne pose ni story ni notif ni card si `gain == 0` (`:514`, mais bascule quand même sur la home), `reglerFinDeSeance` refuse `series == 0` (`SacreServeur.swift:258`), et un tirage du chemin en sachets ne pose pas la capsule (`RewardChemin.swift:286`) | inchangé pour la séance vide ; **un tirage en sachets pose la robe 4** (plan §5.4 point 13) |
| **erreur** | **rien à dire, par construction** : l'appel est en fond, ne propage pas, et l'outbox rejoue au retour au premier plan (`OutboxGains.vider()` sur `.active`, `WoopApp.swift:92`). ⚠️ Un refus **définitif** (4xx hors 401/408/429) est **jeté et crié** dans la console (`OutboxGains.swift:155`) — le gain annoncé n'a alors jamais été crédité | **?** — faut-il une correction visible quand un gain annoncé est refusé pour de bon ? Le §1 du plan backend dit « le ledger rattrape », pas « le ledger contredit ». **Reste ouvert** le 30-08 |
| **hors ligne** | identique au nominal — la capsule est locale ; l'écriture attend dans l'outbox (bornée à 200 entrées, `UserDefaults`) | la page noire affiche le **repli local, dit comme tel** ; la dalle de série inchangée |
| **deux gains qui se suivent** | ⚠️ `depart.notifPieces` est **un seul `Int?`** (`DepartSeance.swift:43`) : un second gain **écrase** le premier (clôture puis claim rapide, par exemple) | **TRANCHÉ 30-08** : **une FILE typée** `[Annonce]`, empilée l'une sous l'autre par l'hôte de la racine — jamais un cumul (« +260 ») : pièces + sachet sont **deux événements**, donc deux dalles (plan §0 « clôture », §5.1 point 1). *Périmé* : « une file ou un cumul, non tranché » |
| **rejeu après un kill** (nouveau) | `cloturer_seance` rejouée rend `pieces 0, booster_neuf false, argent false` (`annonces.sql:354-363`) — une page noire qui recharge ne pourrait rien relire | **TRANCHÉ 30-08** : la fonction rejouée rend **le stocké** + `rejeu: true` (plan §4 M1 point 5) — **à écrire** |

---

## 6 · Le backend et ses règles

> Ce que le serveur doit **décider** et **renvoyer**. Le détail des tables vit
> dans `tools/coffre-v2/BACKEND-COFFRE.md` et `tools/rewards/PLAN-REWARDS-BACKEND.md`
> (§4 quaterdecies, la règle des annonces — **à réécrire** : elle dit encore
> « la pop-up REMPLACE la dalle », plan §2.7). **Le contrat par catégorie,
> tranché le 30-08, est le tableau §3 de `tools/annonces/PLAN-COFFRE-ANNONCES.md`**
> — c'est lui qui commande, cette fiche ne le recopie pas.

### 6.1 Les règles

| Règle | Valeur | Statut |
|---|---|---|
| toute annonce d'un gain passe par le template — plus de pill ni de capsule ad hoc | une famille, **cinq** robes (pièces ×3, booster, argent) | **CIBLE** (verdict 28-08, élargi 30-08) — les deux toasters ad hoc sont toujours là, les robes 4 et 5 ne sont pas codées |
| **une annonce PAR événement** ; pièces et sachet de clôture sont **deux** événements | — | **TRANCHÉ 30-08** — la clé `annonce_une_par_evenement` est en base (`annonces.sql:144`) mais son commentaire (`:138-143`) et le site la lisent encore comme « la pop-up remplace la dalle, deux annonces à la fin c'est interdit » : **à réécrire** (plan §2.7, §7) |
| la notification est **locale et immédiate** ; le règlement est **asynchrone et idempotent** | — | **vérifié** pour la clôture (`terminerSeance` + outbox) ; **nuancé 30-08** pour la page noire (attend, borne 4 s) ; CIBLE pour la série, le chemin, le Welcome Back |
| elle intervient à chaque gain : la série, sa clôture (pièces, sachet, argent, conversion), le chemin (pièces ou sachet), le Welcome Back (+10 au tap) | — | **CIBLE** (verdict 28-08, précisé 30-08 plan §3) |
| une dalle **ne consomme pas** le budget des pop-ups ; plafond 6 par séance | `notif_consomme_budget: false`, `notifs_max_seance: 6` (`annonces.sql:150-151`) | **TRANCHÉ 30-08** (plan §0 « le rythme ») — en base, lues par personne |
| les robes « pièces » varient ; la robe « booster » quand le gain est un sachet ; « argent » quand la pièce tombe | — | **CIBLE** (verdict 29-08 + 30-08) ; **?** le mode de variation (§6.4) |
| une série rapporte | **20 pièces** | vérifié : `pieces_par_serie: 20` en base, **lu du serveur** par `EconomieWoop.piecesParSerie` (`EconomieWoop.swift:105`, 20 en repli) et consommé par `terminerSeance` (`WoopApp.swift:473`) et la fiche (`ExerciseDetailView.swift:2257`). *Périmé* : « `gainParSerie = 20` (client) » — la constante Swift est morte |
| le Welcome Back rapporte | **10 pièces**, une fois par jour | `pieces_retour_quotidien: 10` en base ; côté app **encore une constante** `piecesRetourQuotidien = 10` (`ExerciseDetailView.swift:2270`) — TRANCHÉ 30-08 : à retirer au profit de la réponse (plan §5.3) |

### 6.2 Ce que le serveur renvoie déjà, et ce que la dalle en fait

| appel | ce qu'il rend | lu par | ce que la dalle en ferait |
|---|---|---|---|
| `cloturer_seance(p_workout, p_series)` | `pieces · pieces_creditees · booster_id · booster_neuf · solde · argent · reste · prix_booster` (8 champs, `annonces.sql:354-363`) | **oui** — `SacreServeur.ClotureSeance` (`:195-226`) → `EconomieWoop.appliquer` (`:207-212`). *Périmé* : « lue par aucun écran » | la pile : `pieces` (jauge, `reste / prix_booster`), `booster_neuf` (robe 4), `argent` (robe 5) ; CIBLE 30-08 : `sachets_convertis` et `rejeu` (plan §4 M1) |
| `etat_coffre()` | `solde_or · solde_argent · boosters_or · reste · prix_booster · pieces_par_serie · noirs_ouverts …` | oui — `EconomieWoop.rafraichir()` (`:187-197`) | la jauge ; CIBLE 30-08 : `retour_disponible`, `flamme` (plan §4 M1 point 7) |
| `claim_retour_quotidien()` | `credite · montant · solde` | oui — `OutboxGains.swift:206-211` → `EconomieWoop.appliquer` (`:217`) ; **posté sans tap** (§3) | la dalle « +10 » **au tap** (TRANCHÉ 30-08) — *périmé* : « seulement si `credite` » |
| `tirer_noeud_chemin(p_noeud, p_pieces)` | `type · montant · monnaie · robes · rarete · deja_reclame` (`sachet_scelle_et_tirage.sql:199-…`) | oui — `RewardChemin.tirerAuServeur` (`:224-235`) | la dalle après la card : le montant (pièces) ou la robe 4 (sachets). *Périmé* : `reclamer_noeud_chemin` → `deja_reclame`, « rien — le montant vient du tirage, déjà connu » |

⚠️ **Le montant affiché à la clôture vient encore du client** : `storyGain`
(`WoopApp.swift:544-548`) est `séries × piecesParSerie`, pas `r.pieces` — ils
disent la même chose parce que le taux est lu du serveur ; la page noire
(CIBLE) lira la réponse. *Périmé* : « la constante Swift `gainParSerie = 20`
et le `pieces_par_serie` du serveur disent la même chose aujourd'hui ; le
jour où le prix change en base, la dalle annoncera l'ancien nombre jusqu'au
build suivant » — le taux est lu en base depuis `EconomieWoop`.

### 6.3 Ce que le serveur garantit, et qui rend l'annonce immédiate possible

- **L'idempotence est garantie côté serveur** — un gain par séance, un sachet
  par séance, un versement par jour, un nœud par chemin : rejouer l'outbox ne
  crédite jamais deux fois. *« On ne met jamais dans cette file une opération
  dont le serveur ne sait pas dire "déjà fait" »* (`OutboxGains`). Le
  mécanisme est décrit dans `BACKEND-COFFRE.md`. ⚠️ Nuance 30-08 : idempotent
  ne veut pas dire **relisible** — `cloturer_seance` rejouée rend des zéros
  (§5 « rejeu »), à corriger pour la page noire.
- **Le solde est dérivé**, jamais stocké — donc la jauge ne peut venir que de
  lui (`reste` de la réponse, ou `etat_coffre()`).
- **Le tirage du chemin est au serveur** depuis `9ef6da1` (30-08) :
  `tirer_noeud_chemin` tire, dérive la pitié de son journal, écrit, et rend le
  stocké au rejeu ; sondé le 30-08 (`tools/sacre/verif_backend_sachet.py`,
  22 ✓). *Périmé* : « le tirage est encore au client (`TirageRecompense.tirer`)
  et la pitié aussi — falsifiables ». Reste `TirageRecompense.tirer` en repli
  sans compte, **dit comme tel**, qui n'écrit rien (`RewardChemin.swift:203-209`).
- **La pièce d'argent est tirée au serveur** (`roll_rare`, privée depuis
  `20260829130000`) — c'est ce qui justifie le « petit chargement » de la page
  noire : personne au client ne peut la deviner.

### 6.5 L'état du serveur — sondé en HTTP le 29-08 (clé anon, sans session), relu le 30-08

Le projet Woop (`ytnnyjkramgiqyxdrkcu`), chaque fonction appelée ; un `400
not-null user_id` est la réponse **attendue** sans session (la fonction a
tourné jusqu'à l'insertion, `auth.uid()` est nul) — c'est la preuve qu'elle
existe et qu'elle calcule juste :

| fonction | réponse (29-08) | ce qu'elle prouve | au 30-08 |
|---|---|---|---|
| `etat_coffre()` | **200** `{reste 0, solde_or 0, boosters_or 0, prix_booster 100, solde_argent 0, pieces_par_serie 20}` | les six clés de la jauge, les prix lus en base | + `noirs_ouverts` (9ef6da1) ; CIBLE + `retour_disponible`, `flamme` |
| `solde_or()` · `solde_argent()` | 200 `0` | — | — |
| `claim_retour_quotidien()` | 400 not-null, ligne `(…, 10, retour_quotidien, yellow, …, 2026-08-29)` | montant **10** lu dans `reward_rules`, jour rempli | jour **UTC** (`gains_coffre.sql:149-151`) — TRANCHÉ 30-08 : minuit Paris (M1) |
| `cloturer_seance(uuid, 3)` | 400 not-null, ligne `(…, 60, serie_faite, …)` | **3 × 20 = 60**, le taux vient du serveur | sondé avec session le 30-08 ×2 (site, `b-fn-cloturer-seance`) : #2 `booster_neuf:false`, même `booster_id` |
| `reclamer_noeud_chemin(3, 150, yellow, [])` | 400 not-null, ligne `(…, 150, chemin, yellow, …, 3, …)` | la raison `chemin` et le nœud passent | **délègue à `tirer_noeud_chemin` et ignore le montant envoyé** (9ef6da1) ; sondé 30-08 `(3, 1000000, silver)` → `deja_reclame`, argent 0→0 |
| `tirer_noeud_chemin(…)` | — (n'existait pas) | — | **nouvelle** (9ef6da1) ; sondé 30-08 : `(3,true)` → 176 jaunes, rejoué identique ; `(8,false)` → `[noire, noire]` |
| `historique_gains(5)` | 200 `[]` | — | — |
| `claim_booster()` | 200 `{ouvert false, raison solde_insuffisant, prix 100, solde 0}` | le refus métier en 200, lisible | TRANCHÉ 30-08 : **à fermer** (`revoke`) — avec la conversion à 100, l'achat ne peut plus réussir (plan §1 Q9, §4 M1 point 8) |
| `claim_booster_legendaire()` | **500** `P0002 « pièces d'argent insuffisantes »` | ⚠️ l'incohérence de `coffre-rewards.md` §6.2 était toujours là le 29-08 | **périmé depuis `9ef6da1`** : **200** `{ouvert false, raison argent_insuffisant, solde_argent, prix}` (`sachet_scelle_et_tirage.sql:96-100`) ; sondé 30-08 avec session ×2 (site, `b-fn-claim-legendaire`) — la sonde anon à 500 n'a **pas** été rejouée |
| `reward_rules` (select anon) | 200 `[]` | la RLS ne l'ouvre qu'aux `authenticated` — normal ; l'app la lira avec sa session | lue : `EconomieWoop.rafraichir()` via `etat_coffre()` |

**Verdict du 29-08 — périmé le 30-08** : « côté Supabase, tout ce que la
dalle a besoin de lire ou de déclencher existe et répond — rien à migrer pour
les notifications ». **Faux depuis les décisions du 30-08** : la pile a besoin
de `sachets_convertis` (conversion automatique à 100), d'un `cloturer_seance`
rejouée qui rend le stocké, de `retour_disponible` et du jour Paris pour le
Welcome Back — la migration **M1** du plan §4, ~~pas écrite au 30-08 soir~~
**écrite, posée le 30-08 à 18:48 et prouvée à 18:49**
(`supabase/migrations/20260830210000_conversion_jour_flamme.sql` ;
`tools/annonces/verif_backend_coffre.py` → TOUT EST VERT, 47 preuves :
`sachets_convertis` et `rejeu` rendus par `cloturer_seance`,
`retour_disponible` / `retour_prochain` / `flamme` dans `etat_coffre`, jour
Paris dans `claim_retour_quotidien`). Côté serveur, la dalle a désormais tout.
Ce qui manque **dans l'app** reste vrai : aucune robe booster ni argent, un
seul créneau `notifPieces`, aucune porte de production pour le Welcome Back,
`argent` et `booster_neuf` reçus et jamais annoncés.

Les migrations du 28-08 au 30-08 (`booster_noir`, `wallet_coffre`,
`gains_coffre`, `annonces`, `roll_rare_prive`, `ouvrir_booster`,
`noeuds_chemin_lus`, `regles_chemin`, `welcome_chaque_connexion`,
`moteur_faits`, `sachet_scelle_et_tirage`), `SacreServeur.swift` et
`OutboxGains.swift` sont **commités** : le dépôt porte le schéma de sa prod
(`migration list --linked : remote` cité par `9ef6da1`).

### 6.4 Ce que le backend n'a PAS à décider — **?** (recommandations, V9 §B2)

- **La robe.** Elle s'affiche avant toute réponse ; la choisir côté serveur
  reviendrait à l'attendre. Recommandé : une rotation **déterministe**
  (`hash(session_uuid, serie_index) % 3`, rejouable au banc — la loi du
  `DecideurSerie`, *« une page qui change d'avis à chaque relance ne se juge
  pas »*). Réserve : le moteur de décision (§2 du plan) pourra **suggérer**
  une robe pour un gain exceptionnel, honorée si elle est là. **Reste
  ouvert** le 30-08 (le plan tranche le hasard des **pop-ups** —
  `hash(workout_id, rang)`, §5.2 point 7 — pas celui des robes de dalle).
- **La durée, la position, la langue** — du design, **à trancher** sur
  capture (§2). **Restent ouverts** le 30-08.

---

## 7 · Bancs

| Argument | Effet |
|---|---|
| `-notifLab` | le banc : les **six** robes empilées sur du noir vrai, un tap rejoue les entrées. Depuis le 24-09 la pile se met **à l'échelle** pour tenir en une capture (six dalles = 898 pt, l'écran en offre 781) et le bandeau **imprime le facteur** — une planche réduite qu'on croit à l'échelle ment sur les cotes |
| `-notifSeule <n>` | une seule robe, **à 1:1** — le cas vrai de l'app, et le seul régime où l'on juge une cote. `1` jauge · `2` gros texte · `3` châsse · `4` booster · `5` l'aile · `6` le clin d'œil |
| `-robeSuite [n]` | **en SÉANCE** (24-09) : `n` toasters de fin de série s'enchaînent seuls, par le VRAI chemin, un toutes les ~2,9 s. **C'est la seule prise qui prouve la ROTATION** — `-robeNotif` cloue une robe, il montre qu'elle sait s'afficher, pas qu'elle tombe à son tour. Avec `-exoLab` |
| `-robeNotif <1\|2\|3\|5\|6>` | **en SÉANCE** : cloue la robe du toaster de fin de série, pour filmer une robe précise. Avec `-exoLab -serieFin 1` |
| `-sansVideoNotif` | le barreau de coût des robes vidéo (2, 3, 5, 6 — la jauge est la SEULE sans lecteur) : elles retombent sur la jauge. La chauffe fait la même chose toute seule (`ProtectionThermique.ambianceAuRepos`) |
| `-notifFige` | les dalles naissent posées (captures immobiles) — l'équivalent du `banc: true` qui empêche `PillGain` de partir au banc |
| `-notifT <s>` | l'horloge du projecteur et du tour de pièce, clouée |
| `-notifNu` | sans bandeau |
| `-fps` | `SondeCadence` (`CADisplayLink`) — le seul juge du « ça lag » |

Simulateur dédié : **`kat-notif`**. Boucle : `tools/notifs/voir.sh`. Captures
et films : `tools/notifs/captures/`.

**Mesuré au simulateur** (charge 🟡, l'autre session allumée) : les trois
dalles empilées **55-60 img/s** ; la mesure étiquetée « Châsse seule »
(**60,0 img/s, pire trou 17 ms**) portait en réalité **deux dalles** (jauge +
châsse, le bug ci-dessus) — elle est donc **conservatrice**, pas fausse, mais
la Châsse seule n'a jamais été mesurée. La pièce de la jauge : **84 % d'images
identiques, 9,6 pas/s** — le stroboscope de la planche à 72 cases sur 9 s
(V8 §A ; remède : le fondu entre deux cases).

**Le 24-09 — les robes 5 et 6, et ce que le banc a révélé.** Les robes 5
(« l'aile », Nosfy à gauche qui déploie son aile vers le chiffre) et 6 (« le
clin d'œil », la dalle de la maison avec la petite tête à la place de la
pièce) sont au banc. Au passage, la ligne « `-notifSeule 3` n'isole pas la
châsse » de ce tableau était **périmée** : `NotifLab.montre(_:)` teste depuis
longtemps l'égalité au rang, plus une exclusion — la mesure « Châsse seule »
de l'été reste, elle, à refaire. Deux défauts trouvés ce jour-là, hors banc :

1. **Les robes 2 et 3 n'avaient aucun site d'appel** depuis le 29-08 — elles
   ne vivaient QUE dans ce banc. En séance une seule robe sortait, la jauge.
   `ToasterSerie` (`NotifAile.swift`) fait tourner **CINQ robes en tour de
   rôle** — gros texte, aile, clin d'œil, châsse, puis la jauge à la pièce
   (sa règle : « toutes les robes sauf la booster, et tu alternes ; on voit
   tout le temps celle de la pièce »). Chacune passe UNE fois avant qu'aucune
   ne repasse, sur un **compteur de toasters posés** et non sur le rang de la
   série (les rangs 3/5/10 sont des rangs de pop-up : ils ne posent aucun
   toaster, certaines robes seraient tombées deux fois moins souvent). La
   robe BOOSTER reste hors du tour : ce qu'elle pose à droite est le sachet
   orange, la quittance d'un booster gagné — sur un « +20 COINS EARNED »
   elle annoncerait un sachet que personne n'a eu.

   ⚠️ **Sa règle dure : « la pièce tombe jamais deux fois d'affilée », et
   elle tient MÊME SOUS CHALEUR.** Premier jet : la porte thermique ramenait
   toutes les robes vidéo à la jauge — c'est-à-dire la pièce à *chaque*
   série, exactement le défaut qu'elle venait de signaler, réintroduit par
   la protection. Maintenant la chaleur ne peut poser la pièce que si la
   précédente n'était pas elle : sous chaleur on **alterne** pièce / vidéo
   (un lecteur sur deux au lieu de zéro). Le barreau `-sansVideoNotif`, lui,
   reste absolu — il sert à peser l'app sans aucun lecteur.

   ⚠️ **La robe se choisit quand le toaster NAÎT** (`RobeNotif.suivante`,
   gardée par la fiche dans `robePill`), **jamais dans un `body`** : un corps
   de vue est réévalué autant de fois que SwiftUI le décide, et une rotation
   qui avance là-dedans compte n'importe quoi.

   **Prouvé** au banc `-robeSuite` : séquence lue sur le film — YOU WIN,
   l'aile, le clin d'œil, la châsse, la pièce, YOU WIN
   (`captures/tour-de-role-2409.png`, `tour-de-role-film-2409.mp4`).
2. **La jauge ne bougeait jamais de la séance** : le site d'appel lisait
   `EconomieWoop.reste` nu, qui n'est réécrit que quand le serveur répond —
   or le serveur PAIE à la clôture. Corrigé au site d'appel
   (`fractionCoffre(apres:)`), **non mesuré** : la preuve demande deux séries
   de suite et la lecture de la barre entre les deux.

**Le « glitch » de la vidéo (24-09) était TEMPOREL, pas graphique.** Les deux
sources sont en **24 img/s** ; 60 / 24 = 2,5, donc sur un écran 60 Hz chaque
image tient 2 puis 3 rafraîchissements, en alternance — le pulldown 3:2. Les
images du film au simulateur sont propres une par une (pas max 0,91 pour un
médian 0,42 : aucun artefact, aucun saut de contenu). Remède : **re-dater les
mêmes images à 30 img/s** (`setpts=N/30/TB`) — 2 rafraîchissements à 60 Hz,
4 à 120, cadence parfaitement régulière. Rien n'est dupliqué ni interpolé
(`minterpolate` fabrique des fantômes sur les membranes). **À vérifier de ses
yeux sur l'iPhone** : le simulateur enregistre à ~30 img/s, il ne peut pas
juger un 60 Hz.

**Deux défauts de la JAUGE, trouvés en la faisant enfin aller au bout.**

3. **Le bout de la course était laid.** À `f = 1` le front arrivait
   exactement sur le bord du `Canvas` : la tête blanche y était **coupée en
   deux**, et le halo du front — à qui `NotifCard.swift` donne « le droit de
   déborder, c'est de la lumière » — se faisait **trancher par les bornes du
   Canvas**, ce qui posait un **rectangle gris** de 18 pt de haut à arêtes
   droites (zoom ×3 : `captures/zoom-fin-barre.png`). Une lumière n'a pas
   d'arête. Corrigé par deux gestes, aucun n'est un réglage : la course
   s'arrête **un rayon de tête avant** le bord (la tête tient entière par
   construction), et le halo **meurt** entre 0,88 et 1 — il n'y a plus rien
   devant à éclairer.
4. **La barre ne s'animait pas au rejeu du banc.** `rejouer()` posait
   `tour += 1` (qui change l'**identité** de la pile, donc SwiftUI la détruit
   et la recrée) et `pose = true` dans la **même transaction**. Or *une vue
   qui naît ne s'anime pas* : elle apparaît avec la valeur qu'on lui donne,
   il n'y a pas de « avant » à interpoler — `Animatable` n'était jamais
   appelé, la barre naissait pleine. Un tour de boucle de plus (`asyncAfter`
   de 0,05 s avant `poser()`) suffit.

⚠️ **Et la mesure de cette animation a menti deux fois, ça vaut d'être écrit.**
(a) `simctl io recordVideo` enregistre en **cadence variable** : compter les
images décodées revient à compter des instants de durées différentes — il faut
forcer `fps=60` au décodage. (b) Sur le banc **entier** (six dalles, trois
lecteurs vidéo), le simulateur saute des images et l'animation *paraît*
claquer même quand elle ne claque pas. La mesure valable se fait sur
`-notifSeule 1` — la seule robe **sans vidéo**. Relevé là, à 60 img/s :
`2 → 97 → 129 → 299 → 343 → 376 → 408 → 443`, une vraie rampe.

Aucun banc n'existe pour la page noire ni la file (30-08) — ils viennent avec
les jalons J2-J3 du plan §6.

---

## 8 · À vérifier au téléphone

Rien de ce qui suit n'est jugeable au simulateur, et **rien n'a été validé** :
la cadence réelle des robes (et de la vidéo Nosfy sur l'appareil), la lecture
du chiffre en ~3 s dans une vraie séance, le galet de verre sur l'aile (un
`.clear` sans nourriture rend un disque gris), le fondu de la pièce une fois
codé, et l'enchaînement capsule (+0,3 s → +3,3 s) → card booster (+3,4 s)
après la fermeture de la story — *périmé* : « le chevauchement avec la
pop-up booster à +5,2 s ». Une fois la page noire codée (J3) : la pile
entière, le « petit chargement » borné à 4 s, et le repli hors ligne dit
comme tel.
