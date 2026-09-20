# Plan de debug — retours TestFlight du 19-09 (build 1.0 (81))

Écrit le 20-09-2026 après une analyse en lecture seule : rien n'a été codé,
rien n'a été commité, rien n'a été écrit au serveur ni installé sur un
téléphone. Chaque affirmation est **MESURÉE** (appel ou rapport lu),
**LUE** (fichier:ligne) ou **SUPPOSÉE** — et le dit.

Sources : deux enquêtes à agents avec vérification contradictoire de chaque
constat (code + faits), une lecture des faits serveur sur les deux comptes du
test (transaction `read_only`, aucun identifiant sorti), les deux rapports de
crash et les deux retours-captures que TestFlight a transmis à Apple.

Les six retours de Kathryn (quatre dictés le matin, deux ajoutés ensuite) :

| # | Ce qu'elle a vu | Verdict court |
|---|---|---|
| 1 | Lancer le HIIT pendant une séance ferme l'app, la Live Activity reste | **Défaut, cause identifiée** : index hors bornes dans le graphe des paliers HIIT (`ChambreHiit.swift:440`), deux rapports Apple le 19-09 |
| 2 | Margaux : « plusieurs fois le jour 19 » sur la Route ; ×2 demandé ; bouton « Review » | **Libellé ambigu, pas un doublon** (le galet porte la date du jour) ; le sticker ×2 existe mais n'est pas posé ; « View » est un bouton inerte |
| 3a | Kathryn : pas d'onboarding, pas remise à zéro, « directement au jour 3 » | **Conforme** au contrat du 13/18-09 : compte existant, 2 séances déjà faites |
| 3b | 149 pièces grattées, dans l'historique mais pas dans le module or | **Conception du 30-08 jamais racontée à l'écran** : 147 gagnées → 2 sachets nés aussitôt, 27 restent |
| 4 | S'assurer que chaque pièce gagnée est comptée | **Au serveur, rien ne manque** ; le récit se casse entre le brut (story, card) et le net (coffre) ; deux défauts latents lus |
| 5 | Card à gratter : vibration énorme, grattage qui ne prend pas, reward « ouverte » si on quitte, petit ticket | **Trois défauts de conception, lus** : le ticket verrouille le grattage sans le dire ; le seuil de 55 % est inatteignable là où le chiffre est écrit ; la card ne se rouvre jamais après « Later » ou une mort de l'app. Vibration = le grondement continu de la fusée, à confirmer à la main |
| 6 | La lune de la Route ne répond pas au tap, « il faut vraiment appuyer » | **Défaut, lu, déterministe** : le tap court refuse une lune pas encore atteinte, l'appui tenu (≥ 0,13 s) l'ouvre — c'est la durée, pas la pression ; et le panneau « Today's session » couvre la récompense du milieu aux rangs 4-6 |

Et deux retours envoyés par le bouton TestFlight (captures, lus par l'API
App Store Connect) : « le nom dans la Story c'est toujours Catherine » et
« quand je tire vers le bas sur la Home, tout l'iPhone bug, je suis bloqué »
(§ 7).

---

## 0. Avant de toucher à quoi que ce soit

### 0.1 Le build 81 n'est PAS `HEAD 781742b4` — MESURÉ

L'archive a été faite à 10:05:46 depuis l'arbre de travail
(`tools/production/testflight-api-2026-09-19/archive.log`), **trente minutes
avant** le commit 781742b4 (10:35:42), qui ne contient que `tools/production`
et `docs/site`. Les 588 empreintes SHA-256 de `sources.json` coïncident toutes
avec l'arbre au 20-09 (0 écart, recalculé deux fois) ; **37 fichiers Swift
diffèrent de HEAD et 5 en sont absents**, dont `Nosfy/Views/PlayerSeance.swift`
(non suivi, compilé par le groupe synchronisé du pbxproj, appelé par
`DepartSeance.swift`).

Conséquence : tout ce qui se juge « à HEAD » peut être faux pour le binaire
(exemple ci-dessous : les titres « Séance cardio » / « Bonus de progrès » de
« Mes gains » sont dans le binaire, pas dans HEAD). **La référence du build 81
est `sources.json` = l'arbre.** Pour les fichiers cités ici, il est dit
quand HEAD et l'arbre diffèrent.

À faire, sur son ordre : un commit **par chemins** des 42 fichiers du
manifeste qui ne sont pas dans HEAD (`PlayerSeance.swift` et
`ReglementSeance.swift` ré-ajoutés), ou au minimum une note dans
`tools/production/testflight-api-2026-09-19/README.md` : « HEAD 781742b4 n'est
pas le binaire ; référence = sources.json ».

### 0.2 Mettre l'archive et les dSYM à l'abri — MESURÉ

`Nosfy-81.xcarchive` (407 Mo, dSYM app UUID `12292D8B-0F31-3082-B3B2-C2B32E023516`,
widget `582015CB-…`) vivait dans
`/var/folders/sk/…/T/nosfy-testflight-20260919-3ndqywhv/`, un dossier que macOS
purge. **FAIT le 20-09 08:04** : copié dans
`~/Library/Developer/Xcode/Archives/2026-09-19/Nosfy-81.xcarchive` (Organizer le
voit ; UUID relu identique). Les symboles sont aussi chez Apple
(`uploadSymbols=true` dans `ExportOptions.plist`) : les rapports arrivent déjà
symbolisés.

### 0.3 Les rapports de crash et les retours TestFlight se lisent par l'API — MESURÉ

`tools/production/appstore_connect.py` (`token()` + `request(path)`) suffit,
sans modification :

- `GET /v1/apps/6813439459/betaFeedbackCrashSubmissions` → 2 rapports du 19-09 ;
  `GET /v1/betaFeedbackCrashSubmissions/{id}/crashLog` → le texte symbolisé
  (rangés le 20-09 dans `tools/production/crash-81-2026-09-19/` :
  `Nosfy-81-2026-09-19T09-08Z.crash` et `…T12-34Z.crash` — ils portent le
  modèle, l'OS et le bundle, aucun identifiant personnel ; non suivis par git).
- `GET /v1/apps/6813439459/betaFeedbackScreenshotSubmissions` → les 2 retours
  écrits par Kathryn (§ 7).

À ajouter au plan TestFlight (`PLAN-TESTFLIGHT-2026-09-18.md`) : « après chaque
session de test, relire ces deux points d'accès ».

### 0.4 Les faits serveur sur les deux comptes — MESURÉS le 20-09 (lecture seule)

Deux comptes Apple existent sur le projet, aucun supprimé.

| | Kathryn `9f5b775d` | Margaux `6692fe98` (« Nini ») |
|---|---|---|
| Créé / onboarding terminé | 18-09 08:33 / 08:34 Paris | 19-09 10:43 / 10:45 Paris, Nosfy/81 |
| Reconnexion Apple | **19-09 11:04:45, nouvelle session Nosfy/81** (feuille Apple repassée) | — |
| Séances finies au 19-09 soir | 6 : 18-09 ×2 (1 série chacune) ; 19-09 11:05→11:07 **vide** ; 11:07→11:10 (1 série) ; 11:14→11:18 (2 séries + 7 longueurs piscine) ; 14:34:11→14:34:49 **vide, 38 s** | 3 : 10:47→10:49 (1 série) ; 11:08→11:09 **vide** ; 13:27→13:28 **vide** |
| Séances ouvertes au serveur | 0 | 0 |
| Galets (`seances_chemin()` rejouée) | 4 (18, 18, 19, 19) | 1 (19) |
| `cardio_phases` | 0 — aucun HIIT n'a atteint le serveur | 0 |
| Carnet (or) | +20 +10 +20 (18-09) ; 19-09 : +10 retour, +20 série, **+147 chemin nœud 3 puis −100 −100 à la même microseconde**, +40 série +140 piscine puis −100 −100 → **solde 7** (407 gagnées, 400 converties). Le 20-09 au matin : 2 séances de plus, +10 retour → **17** (517 − 500) | +20 série, +10 retour → **30** |
| Reçu `galet:3` | 19-09 11:10:51 : montant **147** (pas 149), or, `sachets_convertis 2`, solde après 27 | aucun claim (seuil 3 non atteint) |
| Sachets | 10, dont **5 fermés** (4 « conversion », 1 « séance ») ; 5 cartes (1 légendaire d'un sachet « cadeau » posé côté serveur le 18-09) | 1, ouvert ; 1 carte |
| Annonces en attente | 0 (toutes acquittées) | 0 |
| `apple_jetons` | **0 ligne** | **0 ligne** (entrée réelle sur le 81, clé posée) |

Ce que le serveur ne peut pas dire : l'écran (galets affichés, libellés,
boutons), le crash lui-même, la Live Activity. `jour_courant()` est refusée à
l'administrateur (42501) ; `fuseau_jour = Europe/Paris` lu dans `reward_rules`.

---

## 1. Retour 1 — le crash au lancement du HIIT

### 1.1 La cause — MESURÉE (deux rapports Apple, symbolisés)

Rapports `68CFB1B0` (19-09 **11:08:04** Paris, pendant la séance 11:07→11:10)
et `41707C3D` (19-09 **14:34:28**, 47 s après le lancement de l'app, 17 s après
le début de la séance 14:34:11) — iPhone 15, iOS 26.6.1, image Nosfy UUID
`12292D8B…` = l'archive 81. Les deux disent la même chose :

```
Exception Type:  EXC_BREAKPOINT (SIGTRAP)   — un trap Swift, ni jetsam ni watchdog
0  Swift runtime failure: Index out of range
3  closure #1 in PaliersVue.laque(_:sol:)  (ChambreHiit.swift:440)
5  closure #1 in PaliersVue.laque(_:sol:)  (ChambreHiit.swift:438)
7  SwiftUICore ForEachState.item(at:offset:)
```

Le code, identique dans HEAD, l'arbre et le binaire (dernier commit
0e8410b8) :

- `laque` parcourt `segments` et lit `L.l[i]` / `L.x[i]`
  (`Nosfy/Views/ChambreHiit.swift:433-441`) ;
- `largeurs(dans:)` rend **deux tableaux vides** dès que `total == 0` (toutes
  les durées à 0) **ou `utile <= 0`** (largeur du cadre nulle ou trop petite :
  `utile = champ − gout × (n − 1)`) — `:499-505`.

Le graphe a deux sites d'appel : la **fiche cardio** (`CardioFiche.swift:55`,
`segments` ou une `silhouette` non vide quand la fiche est vide — donc
`total > 0` toujours) et la chambre HIIT (`ChambreHiit.swift:79`). Sur la
fiche, le graphe « cède » sa place pendant une séance (la pile des séries passe
au-dessus du galet, `.frame(minHeight: 90 … maxHeight: 138)`, commentaire
`:50-54`) : une passe de mise en page à **largeur nulle** suffit pour que
`largeurs` rende `[]` et que le `ForEach` lise `L.l[0]`. **SUPPOSÉ** : c'est
pourquoi le crash n'arrive que « pendant une session » (le test HIIT 10→12 du
18-09 sur son iPhone, Release 70, était fait sans séance ouverte).

Écartées par les rapports : la migration SwiftData de 858abef5 (elle aurait
tué l'app au lancement, `NosfyApp.swift:17-23` `fatalError`), la Live Activity
« focus cardio », une mise à mort par le système.

### 1.2 Ce que le crash laisse derrière lui — LU + MESURÉ

- **La Live Activity reste** : iOS garde la carte d'une app tuée, et au
  relancement la racine la **ré-adopte** tant que la séance est ouverte
  (`NosfyApp.swift` HEAD:2342 `.onAppear { WorkoutActivityController.ensure(active) }`,
  `WorkoutActivityController.swift:42-48, 65-79` : l'activité dont `startedAt`
  correspond est mise à jour, jamais terminée). Elle s'éteint au « Terminer »
  du panneau ou quand la purge vide la séance. C'est une conséquence de la
  séance ouverte, pas un défaut d'ActivityKit — mais il n'existe aucun geste
  « cette séance est morte » hors Stop/Terminer.
- **La séance ouverte** : au serveur, 0 séance ouverte ; la séance du crash de
  14:34 a été fermée par « Terminer » 21 s après (14:34:49, vide). Mais la règle
  de purge au lancement est un **défaut latent** (jamais survenu ici) :
  `preparerAuLancement` juge avec `setCount` = séries de **muscu** seulement
  (`Models.swift:366-368`) ; une séance HIIT seule ouverte > 3 h est
  **supprimée** avec ses phases et annulée au serveur (`NosfyApp.swift`
  HEAD:2493-2508), toute séance > 12 h aussi ; une séance avec séries ouverte
  entre 3 h et 12 h est fermée en silence (`endedAt = début + 1 h`) **sans
  clôture ni gain** (`:2513-2520`, `ReglementSeance.swift:56-59`), et compte
  pourtant pour un galet si des séries sont cochées.

### 1.3 Un second défaut, dans le même chantier — LU, à mesurer

Le serveur ne compte un galet HIIT que sur `c.kind = 'effort'`
(`supabase/migrations/20260918083033_compte_gains_et_progression.sql:122`,
`seances_chemin()`), alors que le téléphone pousse les libellés Swift bruts :
« Repos », « Récupération », « Accélération », « Sprint » (`Models.swift:297-301`,
`SupabaseSync.swift:406` `kind: $0.kindRaw`). Le client, lui, compte l'effort
(`faitPourRoute`, `Models.swift:401-405`). Donc, dès que le crash sera levé :
**une séance 100 % HIIT avancera la Route sur le téléphone mais pas au
serveur**, et la lune du rang 3/7 répondra `progression_insuffisante` (409).
Le banc du 18-09 (« muscu, effort cardio ou natation comptent ») a été joué
avec des phases posées en API, pas avec ce que le téléphone envoie. Le
paiement cardio n'est pas touché (`pieces_cardio_seance` ne lit pas `kind`).

### 1.4 Plan de debug

1. **Reproduire au simulateur** (un trap d'index se produit en Debug comme en
   Release ; seule la confirmation exige le téléphone) : compte de banc
   `-sessionBanc`, démarrer une séance (Route → Start → Exercices), ouvrir la
   fiche HIIT ; variante : un `print` temporaire de `champ`, `n`, `total` dans
   `largeurs` pour voir la passe à largeur nulle ; variante 2 : un segment à
   0 s. Film + journal dans `tools/cardio/crash-81/`.
2. **Correctif défensif, une seule vue** : construire la laque depuis `L`
   (zip de `segments` et `L.l`/`L.x`, ou `guard i < L.l.count`), et ne rien
   dessiner tant que `largeurs` est vide. Pas de changement de dessin.
3. **Mesurer en Release câblé sur son iPhone** (thermique 0, téléphone
   coordonné via `MULTI-SESSION.md`) : `xcodebuild … -configuration Release`,
   `xcrun devicectl device install app`, `launch --console … -sondeVol` ; HIIT
   pendant une séance ×3, puis Stop → la Live Activity doit partir sous 1 s ;
   relire `betaFeedbackCrashSubmissions` après le build suivant.
4. **Même chantier cardio, avant le build 82** :
   - `seances_chemin()` : migration corrective (`kind in ('Sprint','Accélération')`
     ou une correspondance côté poussée), banc `verif_gains_progression.py`
     étendu à une séance HIIT seule, puis pastille remesurée ;
   - la purge : remplacer `setCount` par `faitPourRoute` (une seule définition
     du « travail », celle de la Route) et, pour une séance abandonnée avec
     travail, poser `recompenseARegler` pour que la reprise règle le gain au
     lieu de fermer en silence ; décider du sort d'une séance ouverte > 12 h
     avec travail (aujourd'hui supprimée).
5. **Doc dans le même commit** : 🔴 sur la fiche cardio / chambre HIIT
   (preuve : les deux rapports), 🔴 sur `b-fn-seances-chemin` / `b-route-jour`
   (preuve : migration:122 vs `SupabaseSync.swift:406`), brique « séance restée
   ouverte » ; `b-flow-live-lune` reste 🟡 tant que Stop → extinction n'est pas
   vu sur l'iPhone.

---

## 2. Retour 2 — la Route des galets (Margaux, et Kathryn)

### 2.1 « Plusieurs fois le jour 19 » = la DATE, pas un rang — LU, cohérent avec le serveur

Chaque galet accompli porte **le jour du mois de la fin de sa séance**, le mois
sur trois lettres dessous (`GaletEtape.swift:71-74` `Calendar.component(.day)`,
`:832-850` : le jour en grand × 0,34, le mois en corps × 0,125 ≈ **8 pt**, fr_FR
en dur `HomeNuit.swift:1936-1939`). Et **le galet actif porte lui aussi la date
du jour** (`DuolinguoPage.swift:404-413`, `maintenant = Date()`). Donc le
19-09, avec N séances avec travail ce jour-là, on lit **N + 1** fois « 19 » :
Margaux 1 + 1, Kathryn 2 + 1 (après ses deux « 18 »). Sur la card Route de la
Home, le galet ne porte **que le chiffre**, sans mois (`CardRoute.swift:122-125`
`jourSeul: true`) : c'est là que « 19 » se lit le plus naturellement comme un
numéro de jour de parcours.

**Aucun doublon réel** — MESURÉ : l'id envoyé au serveur est le `remoteID`
local (`SupabaseSync.swift:390-392`), `synchroniser_seance` fait `on conflict
(id) do update`, le pull n'insère que les ids absents (`:232-238`) ; au
serveur, aucune paire (début, fin) en double sur les deux comptes.

### 2.2 « Directement au jour 3 » — conforme

Un galet par séance terminée avec travail (règle du 18-09) : ses 2 séances du
18-09 font les galets 1 et 2, l'actif est le 3e (`DuolinguoPage.swift:293`
`id(pourJour: finies.count)`). Aucune séance de banc ne peut s'y glisser en
Release (les drapeaux lisent `CommandLine.arguments`).

### 2.3 Les séances vides ne comptent pas — à trancher

4 des 9 séances du 19-09 (2 chez Margaux, 2 chez Kathryn) **n'ont aucun
exercice** : finies en 1 à 3 minutes, elles ne font ni galet ni pièce, côté
téléphone (`faitPourRoute`) comme côté serveur (`seances_chemin`). Si « il
faut les comptabiliser même si c'est un test » vise ces séances-là, c'est la
règle du 18-09 qu'il faut assouplir, pas un calcul faux. Question posée en § 9.

### 2.4 Le badge ×2 — le sticker existe, il n'est jamais posé sur un galet — LU

- Le sticker « ×2 » que Kathryn appelle « celui qu'on a déjà » **existe dans le
  build** : `sticker-fois2` et `sticker-pastille-fois2` (assets du 27-08,
  `WoopSticker.fois2`, `CalLab.swift:4795`), branché sur la page ×2 de la
  story (`StorySuite.swift:2755`) et le banc du calendrier — jamais sur
  `GaletEtape`, ni sur la Route, ni sur la card Route.
- **Trois définitions du « deux fois le même jour » coexistent** :
  la Route (téléphone) = séances **avec travail**, jour **local** ; le fait
  serveur `double_jour` (`20260915120000:163-179`) = **toute** séance finie,
  vide comprise, jour **Europe/Paris**, un seul ×2 par jour (`20260830100000:88-90`) ;
  la story lit ce fait serveur (`ReglementSeance.swift:23-24`, le commentaire
  `StoryFlow.swift:46` « jour local » est périmé). Le 19-09 à 11:10, la story
  de Kathryn a pu dire ×2 grâce à la séance **vide** de 11:05, pendant que la
  Route ne comptait qu'une séance.
- Esquisse (front seul, sans serveur si la définition Route est retenue) :
  dans `Lecture`, le rang de chaque galet fait dans sa journée locale ;
  `GaletEtape` reçoit `multiple: Int?` et pose `WoopSticker.fois2` (il
  s'ajoute, ne remplace rien — règle du 27-08) sur le 2e galet du jour ; la
  card Route de la Home et le panneau lisent la même `Lecture`. Backend :
  aligner `double_jour` sur « avec travail » (migration + `verif_faits.py`) si
  Kathryn veut que la story et la Route disent la même chose.

### 2.5 Le bouton « Review » — LU : c'est « View », et il ne fait rien

En tapant un galet accompli, le panneau « Session done » s'ouvre avec
« View » et « Later » (anglais en dur, `DuolinguoPage.swift:1334-1338`) ; le
tap sur « View » appelle seulement `fermerPanneau()` — commentaire « la story de
cette séance — à brancher quand elle le dira » (`:1354-1360`, lignes du 28-08,
non touchées par 858abef5). Le mot « Review » n'existe qu'en libellé VoiceOver
du widget semaine (`WidgetsCards.swift:1227`).

**Revoir une séance existe déjà ailleurs** : le widget Regularity et la
chambre Régularité (commit 858abef5) → `HistoriqueStories.ouvrir(jour:)` →
`recus_seances` (déployée le 19-09) → la story avec son reçu, ou un choix si
plusieurs séances le même jour (`HistoriqueStories.swift:14-35`). Pour une
séance faite avant le build 81 sans reçu (les deux du 18-09 de Kathryn), la
fonction reconstruit le bilan depuis le carnet (20 pièces chacune).

Ce qu'il faut « indiquer backend et front » :
- **Front** : `DuolinguoPage` reçoit un `onVoir` ; la racine retrouve la séance
  par sa date et appelle `HistoriqueStories.ouvrir(workout)` — même chemin que
  le widget ; libellé « Voir / View » (ou « Revoir / Review ») via `L()`, à
  trancher avec la règle « tout en anglais » du 28-08 pour ce panneau.
- **Backend** : rien à écrire, `recus_seances` suffit ; la carte du serveur
  gagne un site d'appel (la brique passe de « widget seul » à « widget +
  Route » quand c'est mesuré).

---

## 3. Retour 3 — le compte de Kathryn

### 3.1 Pas d'onboarding, pas de remise à zéro — conforme, MESURÉ

Le profil serveur porte `onboarding_termine_at` du 18-09 ; la porte rend
« CONNUE → app » pour un profil terminé (`AppleAuth.swift:146-160`,
`NosfyApp.swift:2017`, migration `20260913200000_profil.sql:96`) — c'est le
verdict du 13/14-09 : « si on a un compte, on arrive dans l'app ». Le 19-09 à
11:04:45 Kathryn est **repassée par la feuille Apple** (nouvelle session auth
Nosfy/81 au serveur) — la raison pour laquelle la porte s'est rouverte
(installation TestFlight par-dessus l'app posée par câble ? Keychain ?) n'est
pas connue et se lit au câble (`[PORTE]` dans le journal). Personne n'a
demandé ni fait de remise à zéro (README du 18-09 : « aucun effacement »).

Il n'existe **aucun moyen de recommencer** sans supprimer le compte (§ 8). Pour
une QA « compte neuf » répétable : un Apple ID de test, pas un bouton de
remise à zéro.

### 3.2 « 149 pièces dans l'historique, pas dans le module or » — la conversion, jamais racontée

Chronologie MESURÉE sur son carnet :

| Heure (19-09) | Écriture serveur | Solde or après |
|---|---|---|
| 11:05:24 | +10 retour quotidien | 60 |
| 11:10:25 | +20 (1 série) | 80 |
| **11:10:51** | **+147 « chemin » nœud 3** (reçu `galet:3`), puis à la même microseconde **−100 et −100 `conversion_booster`** → 2 sachets « conversion » | **27** |
| 11:18:07 | +40 (2 séries) +140 (piscine 7 longueurs × 20), puis −100 −100 → 2 sachets | 7 |

Ce que l'app lui a montré, LU dans le build :

1. la card grattée roule jusqu'au **brut** (147) et dit « Added to your
   balance » (`RewardCheminVariants.swift:88, :117`) — au moment où elle
   s'affiche, le serveur a déjà retiré 200 ;
2. à la fermeture de la card, les dalles : « +147 » puis **deux « BOOSTER +1 »**
   (événements acquittés 11:11:40 → 11:11:46) — rien ne dit que ces sachets
   viennent des pièces (`Annonces.swift:124-131` ignore le motif `conversion`) ;
3. le Coffre : le module « Gold Coin » lit `solde_or` **net** (`CoffreV2.swift:2588`
   ← `etat_coffre()`), la jauge « 27 / 100 » sous Lune Booster ; « Mes gains »
   liste **+147** et une ligne « +1 · 100 pièces → un sachet »
   (`EconomieNosfy.swift:546`, français figé sur une page anglaise) mais
   **jamais la ligne −100** (`historique_gains_identifie` filtre `delta > 0`,
   `20260918084850:346-352` ; `cartes_prive.tracer` n'émet aucun événement pour
   un débit, `:97`).

Conclusion : ni une monnaie différente (tout est en or, `20260830160000:343-352`),
ni un défaut de lecture (le reçu applique le coffre puis `rafraichir()`,
`RewardChemin.swift:226-243`) ; c'est **la conversion automatique tranchée le
30-08** (« à 100 pièces un sachet apparaît tout seul et les pièces
retombent », `20260830210000_conversion_jour_flamme.sql:4-15`), mesurée au banc,
dite en trois endroits disjoints mais **jamais au moment du gain**. La somme
des lignes visibles de l'historique ne fait pas le module : c'est exactement
« pas cohérent ». Une remise à zéro n'y change rien : la conversion rejouera au
premier crédit.

Les quatre sachets de conversion et le sachet de la séance de 11:18 sont
**toujours fermés** : c'est là qu'est « allé » l'argent.

Les options à trancher (§ 9) :
- **A — compléter le récit** (recommandé, front seul, aucune écriture d'argent) :
  la card grattée dit « 147 gagnées → 2 sachets + 27 restent » (le reçu porte
  déjà `sachets_convertis` et `coffre`, `20260918084850:150-161`), la dalle du
  sachet converti dit « 100 pièces → 1 sachet », le module Gold Coin porte une
  sous-ligne, « Mes gains » montre la tranche convertie (rendre les −100, ou
  la ligne sachet sans « + ») ; libellés fr/en par `L()`.
- **B — un total cumulé « pièces gagnées »** à côté du solde (une clé
  `total_gagne` dans `etat_coffre`, lecture pure) — complément de A, ne
  suffit pas seul.
- **C — supprimer la conversion automatique** : défaire le verdict du 30-08
  (`drop trigger coin_ledger_convertir`, rouvrir `claim_booster`, remettre
  l'achat dans le Coffre, refaire bancs et site) — lourd, et les sachets déjà
  nés restent.

---

## 4. Retour 4 — chaque pièce gagnée est-elle comptée ?

### 4.1 Au serveur : oui — MESURÉ

Sur les deux comptes, **chaque séance avec travail a sa ligne de pièces** et
chaque reçu de clôture reporte un solde égal à la somme du carnet. Les
séances sans reçu sont soit les 2 du 18-09 (payées par le binaire 76, avant
les reçus `cartes_prive`), soit les 4 séances **sans aucun exercice**
(poussées, jamais clôturées, par conception `NosfyApp.swift:602-609`).
Aucun HIIT n'a atteint le serveur (0 `cardio_phases`) : le +140 est la piscine.

Aucune vue n'affiche un bonus que le serveur n'écrit pas : `bonus_fort`,
`bonus_surprise`, `bonus_plafond_seance`, `notif_consomme_budget` sont des
clés mortes (insérées une fois, `20260829120000_annonces.sql`, lues par
personne) ; le seul bonus vivant est `bonus_progres` (+30, record cardio des
7 jours, `20260915160000:332-347`) — jamais produit ici.

### 4.2 Où le récit se casse — LU

- **Le brut contre le net** : la story dit « N coins earned, M boosters »
  (`StorySuite.swift:1289, :1392`, `pieces_total` du reçu, les sachets de
  conversion comptés comme gagnés), le toaster dit le brut, **le Coffre dit le
  reste** — 5 séries = « +100 coins earned, 2 boosters » puis Gold Coin à 0.
  Même mécanisme qu'en 3.2, visible à chaque fin de séance.
- **La card STOP annonce « +0 coins » pour une séance cardio** (le montant
  local est séries × 20, `NosfyApp.swift:1658-1660` → `StopCard.swift:351` ;
  le barème cardio ne vit qu'au serveur). Cas réel du 19-09 : la piscine a
  affiché « 2 sets · +40 coins » et le serveur a payé 180. Le plan du 15-09
  prévoyait « N intervalles / N longueurs, pas de montant avant la réponse »
  (`PLAN-ECONOMIE-CARDIO.md:269`) — jamais codé.
- **La story attend le reçu au plus 6 s** après « Terminer » (`NosfyApp.swift:672-684`,
  deux aller-retours en série : `synchroniser_seance` puis `cloturer_seance`) ;
  au-delà, la page butin s'ouvre sur « — / Rewards pending ». Rien n'est perdu
  (le reçu est sauvé à l'arrivée, le toaster et le Coffre suivent), mais
  l'écart réel en 4G n'a jamais été mesuré sur son iPhone, ni si le « — »
  devient « +N » sans fermer la story.
- **Séance abandonnée > 3 h** : fermée sans clôture ni gain (§ 1.2) — latent.
- **Refus définitif silencieux** (confiance basse, non vérifié) : un 4xx de
  `cloturer_seance` (dates dans le futur, séance étrangère) jette le gain de
  l'outbox avec un simple `print` (`OutboxGains.swift:246-248, :159-161`) ;
  une horloge de téléphone en avance de > 5 min fait refuser
  `synchroniser_seance` pour toujours (`20260918083033:29-30`). Aucun cas vu.
- **Libellés** : dans HEAD, « Mes gains » affiche `cardio_seance` en clair ;
  **le binaire 81 porte déjà** « Séance cardio » / « Bonus de progrès »
  (`EconomieNosfy.swift` de l'arbre) — à commiter. Un `bonus_progres` arriverait
  au toaster comme un second « COINS EARNED » sans étiquette.

### 4.3 Protocole de vérification bout en bout — à jouer sur téléphone, jamais sur un vrai compte

Deux pistes, parce que le compte de test `kat44426+woop-forge-test@gmail.com`
n'est joignable qu'en Debug (`-sessionBanc`, `ForgeServeur.swift:120-127`) :

- **Piste A — build Debug `-sessionBanc`** (le carnet) : lire le point de
  départ (`etat_coffre`, `GET coin_ledger?order=created_at.desc`), puis
  1. **muscu 5 séries** : pill « +20 · 100 this session » à la 5e ; card STOP
     « 5 sets · +100 coins » ; story « +100 coins earned » ; toasters « COINS
     EARNED +100 », « BOOSTER +1 » × 2 ; Coffre Gold Coin = (S + 100) mod 100,
     Lune Booster + 2 ; carnet : `serie_faite +100` (workout_id, receipt_id),
     `conversion_booster −100` (booster_id) ; `user_boosters` origine `seance`
     + `conversion` ; reçu `seance:<uuid>` ; rejouer → aucune ligne ;
  2. **galet 3** (3e séance avec travail) : « Nosfy has something for you » →
     Claim → gratter → M (100-200) ; toasters +M puis « BOOSTER +1 » × k,
     k = (S + M) div 100 ; carnet `chemin +M` sans workout_id, k conversions ;
     reçu `galet:3` ; rejouer le Claim → `deja_reclame`, aucune ligne ;
  3. **kill / relance** : 1 série, tuer l'app, relancer < 3 h → séance active →
     Terminer → payée ; relancer > 3 h → fermée en silence, 0 ligne (§ 1.2) ;
  4. **mode avion** au Terminer : story « — », rien au carnet ; réseau revenu →
     toaster +N, **une seule** ligne `serie_faite`.
- **Piste B — build TestFlight (82), Apple ID de test sacrifiable** :
  étape 0 = le crash HIIT levé (§ 1) ; puis **HIIT 10 × 1 min à 17 km/h**
  (barème mesuré 255) : card STOP « +0 coins » (défaut 4.2 tant que non
  corrigé), story « +255 », toasters « CARDIO COINS +255 » puis « BOOSTER +1 »
  × (k + 1) ; carnet `cardio_seance +255`, k conversions, sachet de séance ;
  la Route avance d'un galet **sur le téléphone ET au serveur** (§ 1.3).
- Lecture serveur après chaque étape : `python3 tools/serveur/sonde_parcours.py
  --depuis <ISO> --json` (agrégats) et, pour le détail, une requête
  `read_only` par l'API de gestion (le script de session `sonde_retour4.py`
  peut devenir `tools/serveur/sonde_compte.py` — à corriger d'abord : il
  cherchait `kind='effort'` et ignorait `piscine_longueurs`).
- Ce protocole devient la fiche `qa-22` du site, un verdict par étape, posé
  après mesure seulement.

---

## 5. Retour 5 — la card à gratter « Nosfy has something for you »

Tout est LU dans le build 81 (`RewardChemin.swift`, `RewardCheminCard.swift`,
`RewardCheminVariants.swift`, `RocketHaptics.swift` : identiques à HEAD et à
l'arbre). La fiche d'écran le disait déjà : « rien n'a encore été validé au
téléphone : le port de Nosfy, le grattage, l'haptique »
(`docs/screens/duolingo-chemin.md:557-559`). Le retour de Kathryn est le
**premier verdict au doigt** de cette card.

### 5.1 Le parcours tel qu'il est — LU

Tap sur la lune → panneau « Nosfy has something for you » → **« Claim »** :
le serveur **tire et crédite à cet instant** (`tirer_noeud_chemin`,
`RewardChemin.swift:197-221` ; décision du 28-08 : « tuer l'app en plein
scratch ne doit pas coûter la récompense », `:177-179`), le galet est gravé
(`chemin.reclamees`, `NosfyApp.swift:877-884`) → la card s'ouvre → il faut
**glisser le petit sticker Nosfy dans la card** → seulement alors le voile
noir écoute le doigt → gratter **55 %** de la grille → révélation (`.heavy`,
le chiffre roule, « Added to your balance ») → « Close ». **Le grattage ne
décide rien** : c'est une animation de lecture.

### 5.2 « Le petit ticket » = le sticker Nosfy, et c'est lui qui verrouille le grattage — LU

- L'asset `sticker-nosfy.png` est **littéralement dessiné en ticket cranté**
  (bords perforés, laque holographique, croissant), rendu à 33 pt (prise
  64 pt), posé à ~20 % du haut de la card (`RewardCheminCard.swift:250-264`).
- La surface noire est **sourde au doigt** tant qu'il n'a pas été traîné
  d'environ **93 pt vers le bas** (`.allowsHitTesting(nosfyRange)` `:116` ;
  départ −0,30 × 424, seuil −0,08 × 424, `:260, :272`) ; un tap sur le sticker
  ne fait rien (`minimumDistance: 2`). Le seul mot d'aide, « Scratch to
  reveal » (anglais en dur, blanc à 30 %), **n'apparaît qu'après** ce
  rangement (`:121`) : celle qui ne range pas le ticket ne lit jamais
  « scratch ».
- Le sticker n'a **ni ressort ni borne** : lâché trop haut il reste où il est
  (sa position s'accumule, `:274-277`) ; poussé vers le haut ou le côté il
  **sort de la card clippée et disparaît** (`:52`) — c'est « le petit ticket
  qu'on peut faire disparaître », et une card qui ne se grattera plus jamais.
  D'où « une fois sur deux » : selon que le geste l'a envoyé vers le bas ou
  ailleurs.
- Aucun geste d'ancêtre ne vole le doigt (rien sur la racine, la card est à
  zIndex 12 au-dessus d'un noir à 0,62 qui isole la Route).

### 5.3 Même armée, la card ne se révèle presque jamais là où on gratte — LU, calculé

Révélation à **55 % de 468 cases** (grille 18 × 26, pinceau ± 30 pt,
`:28-33, :179-180`) : ≈ 4 traits pleine largeur, ≈ 1 250 pt de trait sans
recouvrement. Et le seuil **compte le bandeau vidéo** (232 pt = 14 rangées
sur 26) comme surface à gratter : gratter **toute la moitié basse**, là où le
chiffre est écrit, donne **46 %** ; mordre 30 pt dans la vidéo, 53,8 % —
toujours sous le seuil. Pour révéler, il faut gratter la vidéo, qui n'a rien
à révéler. Pendant ce temps, sous le trou, on lit **« +0 coins »** (le
compteur ne roule qu'à `revele`, `RewardCheminVariants.swift:21, :41, :61`)
alors que le serveur a déjà crédité : l'écran contredit le compte, elle
appuie « Later ». Le commentaire du seuil dit « un chiffre à régler au
doigt » — jamais réglé.

### 5.4 « La vibration énorme » — LU, à confirmer à la main

Le grattage réutilise **le grondement continu de la fusée**
(`RewardCheminCard.swift:172-181` → `RocketHaptics.swift:343-375`) : un
événement `hapticContinuous` **intensité 1,0, netteté 0,06 (très grave),
durée 60 s**, rabaissé par `hapticIntensityControl` à 0,09-0,43 selon la
vitesse du doigt, **tenu au dernier niveau tant que le doigt reste posé**, et
relancé à 1,0 à chaque nouvelle pose avant d'être rabaissé. En niveau, c'est
l'appelant le plus doux de la maison (plafond 0,43 contre 0,76 pour le galet
du player) ; ce qui le rend « énorme » est la **durée** (plusieurs secondes de
moteur grave sous le doigt, § 5.3) et la relance à chaque pose. Seules deux
portes l'arrêtent (`onEnded`, `reveler`) : un geste annulé (Centre de
contrôle, second doigt, vue démontée) peut le laisser tourner jusqu'à 60 s
(confiance basse, non vérifié). S'ajoutent un `.rigid` au rangement du
sticker et un `.heavy` à la révélation, ponctuels. **Muet au simulateur.**
Contre-épreuve simple sur son iPhone : Réglages › Accessibilité › Réduire les
animations coupe exactement cette ligne (`:178`) et rien d'autre.

### 5.5 « Quand je quitte l'app, c'est comme si je l'avais ouverte » — DÉFAUT, LU

Réclamé ≠ gratté, mais l'app confond les deux dès qu'elle est relancée. Au
Claim : `chemin.tirages` (le tirage) et `chemin.reclamees` (le galet) sont
écrits dans les préférences ; **« la card est ouverte » ne vit qu'en mémoire**
(`ouverte`, `RewardChemin.swift:135`) et « déjà gratté » (`chemin.revele`)
n'est posé qu'à la fin du grattage. Trois sorties mènent à la même impasse :

1. **le processus meurt** avant le grattage (balayage, ou l'app tuée — un
   simple passage en arrière-plan garde la card, aucun gestionnaire
   `.background` ne la démonte, `NosfyApp.swift:110-112`) ;
2. **le bouton « Later »** sous la card (`RewardCheminCard.swift:72-73` →
   `fermer()`) — une sortie conçue qui promet un plus tard qui n'existe pas ;
3. un tap dont la réponse serveur s'est perdue.

Au retour : les annonces retenues pendant la card sont perdues, le serveur les
rend, **le toaster « +N pièces » (puis « sachet ») défile tout seul et
s'acquitte** (`EconomieNosfy.swift:509-521`) ; sur la Route, le galet dit
**« Reward already claimed » sans bouton** (`DuolinguoPage.swift:1336-1341`,
`peutReclamer` refuse un nœud réclamé `:371-374`) ; la branche « la card se
rouvre sans se re-gratter » (`RewardChemin.swift:199-201`, promise par
`:68-70` et `duolingo-chemin.md:306`) est **injoignable depuis l'écran**.
L'argent est au compte (ses 147 dans « Mes gains ») ; le résultat n'a jamais
été montré. Se reproduit **au simulateur, sans serveur** (`simctl terminate`
après le Claim).

### 5.6 Plan de debug

1. **Mesurer au doigt sur son iPhone** (thermique 0) : (a) gratter sans
   toucher le sticker → attendu : rien ; glisser le sticker vers le bas →
   attendu : ça gratte ; le pousser de côté → attendu : il disparaît ;
   (b) gratter une fenêtre de pouce sur le chiffre → « +0 coins », rien ne
   bascule ; (c) la vibration avec et sans « Réduire les animations » ;
   (d) Claim → card → tuer l'app → relancer → galet « already claimed », toaster
   seul. Chaque point filmé. Au sim : `-rewardChemin coins` (rendu, souris),
   `-rewardAuto` (le banc qui range le sticker tout seul à 1,6 s — c'est
   pourquoi le défaut n'a jamais été vu au banc).
2. **Les décisions qui lui reviennent** (§ 9) : retirer le ticket, ou le
   garder avec le mot « Scratch / Gratter » ; le seuil ; l'haptique ; le
   galet gravé au tap ou après grattage ; le mot du bouton de reprise.
3. **Correctifs esquissés, sans code** :
   - le ticket : **option 1** le retirer (`nosfyRange` vrai d'emblée, sticker
     non monté, invite dès l'ouverture) ; **option 2** le garder mais ne
     jamais rendre le voile sourd (retirer `allowsHitTesting(nosfyRange)` :
     le sticker garde ses 64 pt, le reste gratte), le borner à la card, et
     écrire `L("GRATTER", "SCRATCH")` en 13 pt semibold, blanc 0,55-0,65,
     **dès l'ouverture** ;
   - le seuil : 0,55 → ≈ 0,30, compté **hors bandeau vidéo**, puis l'app finit
     le grattage elle-même (fondu 0,45 s déjà écrit dans `reveler`) ; ou le
     montant visible sous le voile dès l'ouverture (le tirage est déjà connu) ;
   - l'haptique : remplacer le grondement par une **texture** de grattage
     (`hapticTransient` courts, intensité ≈ 0,3, netteté ≈ 0,7, un par pas
     ≥ 30 ms) ou plafonner le continu à ≈ 0,12-0,15, durée 0,3 s réarmée à
     chaque pas, jamais 60 s ; filet `.onChange(of: gratteEnCours)` → `dragEnd()`
     ; barreau `-sansHaptiqueGrattage` ;
   - la reprise (**front seul, le serveur sait déjà tout rejouer**) : au
     lancement et au retour de la Route, `journal.keys ∖ vues` = « tiré non
     révélé » → rouvrir la card sur le tirage stocké (réinstallation : le
     rejeu de `tirer_noeud_chemin` rend le stocké avec `deja_reclame` et ses
     événements non acquittés, `20260918084850:184-192`) ; sur la Route, un
     nœud réclamé non révélé n'est pas « already claimed » mais offre
     `L("Gratter", "Scratch")` ; les annonces du nœud (motif `chemin` **et**
     `cadeau` pour la seconde robe) restent retenues et ne s'acquittent
     qu'après `marquerRevele` ; « Later » retiré ou renommé « Scratch later »
     avec le galet qui reste ouvrable. Backend : rien d'obligatoire ;
     optionnel : `noeud_id` dans les événements d'annonce.
4. **Non-régression** : `tools/serveur/verif_parcours_rewards.py` rejoue déjà
   `tirer_noeud_chemin` (nœud 8) et vérifie que les annonces acquittées ne
   reviennent pas ; ajouter le protocole sim « Claim → terminate → relance →
   la card se rouvre, `evenements.vu_at` reste nul jusqu'à la révélation ».
5. **Doc** : une brique « card à gratter » (page flow, domaine chemin) en 🔴
   avec 5.2, 5.3, 5.5 et la réserve « haptique non mesurée » ;
   `b-route-reclamee` garde son 🟢 sur la mémoire des nœuds mais reçoit le
   litige « réclamé ≠ révélé ».

## 6. Retour 6 — la lune de la Route ne répond pas au tap

`GaletEtape.swift`, `DuolinguoPage.swift`, `DepartSeance.swift` sont identiques
octet pour octet entre HEAD et l'arbre (le « MM » de git vient de l'index
posé par une autre session) : l'analyse vaut pour le build 81. **Aucun banc n'a
jamais tapé une lune** (les XCUITest tapent `qa.fin`, des coordonnées de story,
ou le galet du jour — immobiles) ; les 🟢 de `b-route-chapitre` /
`b-fin-galet-anime` disent eux-mêmes « toucher iPhone encore ouvert ».

### 6.1 Le geste tel qu'il est — LU

Le galet n'est ni un `Button` ni un `TapGesture` : c'est un
**`DragGesture(minimumDistance: 0)`** (le tap : `onEnded`, course < 12 pt →
`onTap()`, `GaletEtape.swift:295-333`) sous un **`highPriorityGesture`
LongPress 0,13 s + Drag** (le « port » du galet, `:280, :394-396` : haptique
`.medium` à la prise, le galet se soulève, et au lâcher `onTap()` est
**ré-émis** si la course reste < 12 pt, `:437-443`). Zone tactile = cercle
Ø taille + 4 (`:265-274`). Le tout dans un `ScrollView` paginé, sous le drag
simultané de sortie de la Route (24 pt, `DepartSeance.swift:310-316`).
`tape(e)` ouvre **toujours** le panneau d'un nœud spécial
(`DuolinguoPage.swift:1496-1501`).

### 6.2 La cause qui colle mot pour mot — LU, déterministe, doigt immobile

**Le tap court refuse ce que l'appui tenu accorde.** Une lune (ou pièce) que
le chemin n'a pas encore atteinte est `.lune(dispo: false)` ; `GaletEtape`
la range dans `verrouille` (`:246-247`) et **le tap court joue le refus**
(liseré froid, haptique `.rigid`, `:324-332`) **sans jamais appeler
`onTap()`** — alors que la page a écrit pour ce cas le panneau-promesse
« Nosfy has something for you / Reach this step to unlock your reward »
(`:1339-1341`, 28-08, commit 8d153d83), qui devient du code mort depuis le
tap. **Le port, lui, ré-émet `onTap()` sans lire `verrouille`** : un appui
≥ 0,13 s (< 10 pt) soulève le galet et, au lâcher, ouvre le panneau. Ce n'est
pas la pression, c'est **la durée** qui change de chemin — « des fois il faut
vraiment, vraiment appuyer ». Le refus date du 26-08 (cba7f634), la promesse
du 28-08 ne l'a pas retiré. Sur une lune **disponible** ou déjà réclamée, le
tap normal ouvre. Sur le compte de Kathryn le 19-09 (4 galets faits), la
grosse lune de fin de chapitre (rang 8, seuil 7) était exactement dans ce
cas. Se reproduit **au simulateur** : tap XCUITest immobile sur une lune non
disponible → refus ; `press(forDuration: 0.3)` → panneau.

### 6.3 Une seconde cause qui s'additionne — LU, confirmée par une capture du 29-08

Le panneau « Today's session » **s'ouvre seul à l'arrivée** sur la Route
(`DuolinguoPage.swift:1969-1978`) et se pose **130 pt au-dessus** du galet du
jour (« il couvre le passé », `:1292-1302`) ; il fait ≈ 296 × 116 pt, sa coque
(verre + noir 0,32, `:2085-2133`, zIndex 5) est hit-testable **sans aucun
geste**, et le rattrapeur « tap n'importe où ferme » vit **sous** les galets
(`:1162-1174`). Or la récompense du milieu (rang 3) est exactement le nœud
du passé que le panneau chevauche **tant que le galet du jour est aux rangs
4, 5 ou 6** : moitié haute couverte au rang 4, **entièrement au rang 5**,
tiers bas au rang 6 (géométrie `:185-188, :240-241` ; capture réelle
`tools/road/shots/j0-route-etape5.png` : actif au rang 6, la lune du rang 3
passe déjà sous le bord du panneau). Un tap sur la coque meurt : ni panneau,
ni fermeture. Le 19-09 après-midi, Kathryn était au rang 5.

### 6.4 Ce qui reste à mesurer — SUPPOSÉ

- **Un tap qui roule** : le tap est un drag qu'un pan du `ScrollView`
  peut annuler **sans `onEnded`** (« un drag annulé par le scroll n'appelle
  jamais onEnded », `GaletEtape.swift:214-216`) ; un vrai doigt bouge de 2 à
  8 pt, un tap XCUITest de 0. Le seuil du pan n'est pas publié par Apple :
  seule la mesure départage (défaut général à tous les galets s'il tient).
- **L'état figé** : `faits` / `reclamees` sont lus une fois à
  `ouvrirChemin` (`DepartSeance.swift:175-181`) et à `onAppear`, sans
  `onChange` : une Route ouverte avant la fin de la relecture serveur garde
  une lune sombre jusqu'à fermeture-réouverture (« il faut insister »).
- Confiance basse : l'appui tenu **ferme le panneau ouvert** à la prise et
  reconstruit les 45 galets sous le doigt (`:1241-1249, :1259-1262`) — une
  séquence perdue donnerait un galet qui se soulève, retombe, rien ne
  s'ouvre ; et le halo allumé déborde la zone tactile de ~12 pt
  (`GaletEtape.swift:674-680` vs `:274`).

### 6.5 Plan de debug

1. **Sonde d'abord** (aucune n'horodate le tap d'un galet) :
   `NavDiagnostic.noter("route.galet-tap \(e.id)")` en tête de `tape(_:)` et
   un `print` du `onEnded` du drag bas (course, verrouillé) — `-jouetSonde`
   ne trace que le port.
2. **Reproduire au sim** (`-duoEtape 3 -jouetSonde`, iPhone 15 FD3651DD) :
   `LuneUITests` — cible = récompense du rang 3 et lune du rang 8 ; cas A tap
   immobile, B +3 pt, C +6 pt, D +10 pt, E `press(0,3 s)` ; assertion
   `staticTexts["Nosfy has something for you"]` ; film via
   `tools/duolingo/fouette_film.py`. Et le panneau : taper la récompense du
   rang 3 à 10 pt au-dessus / au-dessous de son centre avec l'actif au rang 4
   puis 5.
3. **Sur son iPhone** (`-navProbe -jouetSonde`, thermique 0, compte neuf et
   compte existant séparément) : 20 taps naturels sur une lune non
   disponible, une disponible, une réclamée ; compter panneaux ouverts vs
   lignes « PRISE ».
4. **Correctifs esquissés, sans code** — dans l'ordre du gain :
   - **une ligne** : retirer `.lune(dispo: false)` / `.piece(dispo: false)` de
     `verrouille` (ou faire vérifier la même garde par les deux chemins) —
     la promesse déjà écrite s'ouvre au tap ;
   - **le panneau ne couvre jamais un nœud actionnable** : dans le calcul de
     `dessous` / `yp` (`:1300-1302`), décaler quand un spécial intersecte le
     rectangle — « le poser dessous » contredit la règle du 28-08 (le
     panneau couvre le passé, jamais l'avenir) — et donner à la coque
     `onTapGesture { fermerPanneau() }` pour que « n'importe où ferme » soit
     vrai aussi sur le panneau ;
   - si la mesure 6.4 le confirme : **séparer le tap du drag** (`TapGesture`
     en `simultaneousGesture` avec le port, le press visuel porté par un
     geste qui ne conditionne pas l'ouverture) — jamais un
     `highPriorityGesture` seul (il vole les taps de la nav, piège payé) ;
   - `contentShape` élargie à Ø taille + 28 (≥ 44 pt partout ; l'air entre
     galets est de 31,6 pt, à surveiller pour la pièce Ø 53) ;
   - `onChange(of: faits / reclamees)` dans la page pour relire l'état sans
     la refermer.
5. **Doc** : litige sur `b-route-chapitre` / `b-route-reclamee` (« le tap
   court refuse une lune non atteinte ; le panneau couvre la récompense aux
   rangs 4-6 »), brique « tap sur un galet » à mesurer, verdict QA20 « tactile
   iPhone » toujours ouvert.

---

## 7. Les deux retours envoyés par TestFlight — MESURÉS (API ASC)

- **« Le nom de l'utilisateur dans la Story c'est toujours Catherine »** : la
  page d'ouverture de la story dit « Kathryn, » **en dur**
  (`StoryEnded.swift:325`, commentaire `:318` « la même dette que le Bonjour
  Kathryn de la home ») ; la home a été corrigée (`b-ux-prenom-home` 🟢), pas
  la story. Margaux (« Nini » au serveur) a lu « Kathryn ». Correctif : lire
  `ProfilServeur.prenomLocal` (`ProfilServeur.swift:74-79`, la source de la
  home), repli sans prénom ; 🔴 sur la page histoire jusqu'à mesure sur un
  profil qui n'est pas le sien. Petit, visible par toutes les testeuses, avant
  le 82.
- **« Quand je tire vers le bas sur la Home, tout l'iPhone bug, je suis
  bloqué »** : non couvert par l'analyse (aucune capture ni durée). À lui
  demander : l'écran revient-il seul, combien de temps, la Home noire ou la
  rouge ? Puis mesurer avec le skill `woop-performance` (la chauffe/gel de la
  home est documentée et non corrigée, `tools/perf/ECHECS-CHAUFFE-HOME.md`) —
  ouvert, pas bloquant pour rebâtir.

---

## 8. Remettre à zéro les comptes de Margaux et de Kathryn — procédure, et ce qu'elle doit confirmer

Rien n'a été touché. La règle de `CLAUDE.md` tient : **aucune suppression sans
son accord explicite couvrant cette suppression**, et l'historique personnel se
conserve.

### 8.1 Ce qu'une suppression fait — LU

- **Serveur** : `supprimer-compte` tente la révocation Apple puis un seul
  `auth.admin.deleteUser` (`supabase/functions/supprimer-compte/index.ts:26-56`) ;
  les 20 tables à clé utilisateur sont en `on delete cascade` (14 `public` +
  4 `cartes_prive` + `apple_jetons` ; `apple_revocations` survit exprès). Le
  banc `--flow` rejoué le 19-09 09:23 (après la migration 84850) confirme que
  la cascade `cartes_prive` ne bloque pas ; son contenu après suppression n'a
  pas été relu (schéma hors REST).
- **Téléphone** : `Compte.effacerToutCeQuiEstAElle` (`Compte.swift:155-200`)
  efface la session (Keychain compris), 14 clés de préférences, les quatre
  modèles SwiftData. Restent : `woop.porteVue`, `woop.depart.annulations /
  proprietaires`, `chemin.secs.*`, les réglages de labo — d'où **désinstaller
  l'app** avant de réinstaller TestFlight.
- **Apple** : `requestedScopes` est vide (`AppleAuth.swift:12-15`), Apple ne
  rend jamais prénom ni e-mail ; après suppression, une nouvelle entrée rend
  le même identifiant Apple mais un **nouvel** utilisateur Supabase, et
  l'onboarding se rejoue (profil absent → NOUVELLE). Le prénom est demandé
  par Nosfy (`b-po-prenom-obligatoire`).
- **⚠️ `apple_jetons` est vide pour les deux comptes** (MESURÉ) alors que
  Margaux est entrée par la vraie feuille Apple sur le 81, clé `.p8` posée
  la veille. Donc « Supprimer mon compte » répondra `revocation: aucun_jeton`,
  Apple gardera Nosfy dans « Connexion avec Apple », rien dans
  `apple_revocations`. La cause n'est pas établie (pas de `authorizationCode`
  rendu ? `apple-jeton` en échec ? journaux edge vides sur 18-20/09) : à lire
  au câble à la prochaine entrée Apple (`[compte] apple-jeton → …`,
  `[PORTE] Apple n'a rendu aucun authorizationCode`). C'est un défaut à
  diagnostiquer **avant** de supprimer un vrai compte, sinon la révocation
  exigée par l'App Store reste non mesurée.
- **Aucun outil d'export** : les `.secrets/sauvegarde-compte-*.json` du 14-09
  sont des requêtes ad hoc (7 tables, aucun script conservé), et il n'existe
  aucun ré-import. Une sauvegarde est une lecture, pas un retour arrière.

### 8.2 La procédure sûre

1. **Sa réponse écrite**, compte par compte : (1) les comptes visés
   (`9f5b775d` Kathryn, `6692fe98` Margaux — jamais `be69f505`, le compte
   e-mail du banc) ; (2) qu'elle accepte de **perdre** ce qui sera remesuré à
   l'instant T (au 20-09 07:35 : Kathryn 8 séances, 17 pièces, 13 sachets dont
   5 fermés, 5 cartes dont 1 légendaire ; Margaux 3 séances, 30 pièces, 1
   sachet, 1 carte) ; (3) le chemin : **A** dans l'app (Réglages › Supprimer
   mon compte, sur chaque téléphone — c'est le chemin de production, jamais
   mesuré sur un vrai compte Apple) ou **B** purge admin par service role
   (`DELETE /auth/v1/admin/users/{uid}`, le helper de `verif_compte.py:217`),
   seule voie sans le téléphone de Margaux — au lancement suivant le refresh
   est refusé → `session_revoquee` → effacement + porte ; (4) qu'elle
   désinstallera l'app des deux iPhone avant de réinstaller ; (5) le moment :
   **après le build 82** (le 81 rejoue les retours 1 et 2).
2. Écrire `tools/serveur/sauvegarde_compte.py` (lecture seule, les 20 tables,
   un fichier par uid dans `.secrets/`) et le faire relire.
3. Jouer la suppression **A** d'abord sur un Apple ID de test, au câble, pour
   lire `apple-jeton`, la révocation réelle et l'état du téléphone après.
4. Puis Margaux (A avec elle, ou B), puis Kathryn — chacune après son « oui ».
5. Vérifier (`sonde_parcours.py`, lecture des tables), réinstaller, nouvel
   onboarding ; consigner dans `tools/production/` et repeindre
   `b-po-supprimer` / `b-ed-apple-jeton` selon ce qui a été lu.

---

## 9. Les décisions qui lui reviennent (une ligne chacune)

1. **Le chiffre du galet** : le rang de séance (« 3 », « 4 ») ; la date rendue
   lisible (« 19 SEPT » sur une ligne, mois plus gros) ; ou rang en grand +
   date en petit — et, dans tous les cas, **le galet actif ne porte plus le
   même chiffre qu'un galet fait le même jour** (halo + « Today », sans
   chiffre). Même règle sur la card Route de la Home. Libellés fr/en.
2. **Le ×2** : sur le **2e galet du jour** (chaque séance garde son galet,
   `WoopSticker.fois2` posé dessus), ou **fusion** en un galet ×N (change la
   règle « un galet par séance » et le compte 7/chapitre au serveur).
3. **Le jour** : local du téléphone (Route, widget) ou Europe/Paris (serveur,
   story) — et **la séance vide** compte-t-elle (aujourd'hui non, sauf pour le
   fait `double_jour` de la story).
4. **« View »** : brancher sur la story de la séance (chemin du widget), libellé
   « View » / « Review », anglais en dur ou `L()`.
5. **Les pièces** : A (compléter le récit de la conversion), B (total cumulé),
   C (supprimer la conversion) — recommandation A, B en complément.
6. **La card STOP en cardio** : « cardio · payé à la fin » plutôt que « +0 coins ».
7. **Une séance abandonnée avec travail** : régler le gain à la relance
   (recommandé) ou garder le silence ; et le sort d'une séance > 12 h.
8. **Le petit ticket** : le retirer (le voile écoute dès l'ouverture, le mot
   « SCRATCH / GRATTER » dès la première image), ou le garder sans qu'il
   verrouille rien, borné à la card, avec le mot écrit avant comme après.
9. **Le seuil de grattage** : ≈ 30 % hors bandeau vidéo puis l'app finit le
   grattage (convention des tickets), ou le montant lisible sous le voile.
10. **L'haptique du grattage** : une texture courte (recommandé) ou le
    grondement plafonné — après ton verdict à la main, jamais au sim.
11. **Réclamé ≠ gratté** : le galet reste gravé « à ouvrir » avec un bouton
    « Gratter » (recommandé : la garde anti-double-tap tient) ou ne se grave
    qu'après le grattage ; « Later » retiré ou « Scratch later ».
12. **La lune pas encore atteinte** : s'ouvre au tap sur la promesse « Reach
    this step » (recommandé, une ligne) ou reste muette — mais alors la même
    règle pour l'appui tenu.
13. **Le panneau du jour** : décalé quand il couvre une récompense, et/ou sa
    coque ferme au tap.
14. **La remise à zéro** : les cinq points du § 8.2.

---

## 10. Ordre conseillé

1. Figer la référence (§ 0.1, § 0.2) — sans cela tout se mesure contre de
   mauvaises sources.
2. **Retour 1**, le seul qui bloque le pilote : reproduction au sim, correctif
   défensif, Release câblé ×3, Live Activity après Stop.
3. Même chantier : `seances_chemin` (`kind`), la purge (`faitPourRoute`), la
   séance abandonnée.
4. Le prénom en dur de la story (§ 7) — cinq lignes.
5. Retour 6, la lune (§ 6) : la sonde, puis la ligne `verrouille`, puis le
   panneau qui couvre — mesuré au sim avec un doigt qui bouge, puis au doigt.
   Retour 5, la card (§ 5) : après ses décisions 8-11 — c'est un chantier
   de dessin et de geste, pas un patch.
6. Retour 3b / 4 : lui montrer les trois écrans avec les chiffres mesurés
   (card 147, dalles, Coffre 27 → 7, « Mes gains » sans −100) et faire
   trancher A / B / C ; les libellés déjà dans l'arbre partent dans le même
   commit.
7. Retour 2 / 3a : galet actif distinct, sticker ×2, définition du jour,
   « View » branché, libellés.
8. Doc **dans chaque commit** : pastilles 🔴 avec preuve (rapports Apple,
   fichier:ligne), `qa-22`, une entrée QA « retours TestFlight du 19-09 »
   (8 retours et leur état), `b-coffre-journal` et `b-po-supprimer` corrigés ;
   `cd docs/site && npm run artefact && npm run verif` ; republication au
   même lien.
9. Build 82 → TestFlight → relire `betaFeedbackCrashSubmissions` et
   `…ScreenshotSubmissions` ; rejouer le retour 1 sur un Apple ID de test.
10. Remise à zéro (§ 8) après le 82 et son « oui » écrit.

---

## 12. État après codage — 20-09, midi

Sur son ordre (« donc code ? t'as fix tout »), tout ce qui suit est codé dans
l'arbre, compilé (build simulateur vert), et joué au simulateur là où un banc
existe ; détail, captures et réserves dans
`tools/production/testflight-fix-2026-09-20/README.md`. **Rien n'est commité ;
la migration `seances_chemin` est écrite, pas déployée.**

- Retour 1 : `largeurs()` ne rend plus `[]` (fiche HIIT vivante en séance au
  sim) ; purge sur `faitPourRoute`, séance abandonnée réglée ; migration
  `kind` écrite.
- Retour 2 : galet du jour « TODAY », sticker ×2 sur le 2e galet du jour,
  « View » → story de la séance.
- Retour 3b / 4 : le récit de la conversion partout (card, dalle, story,
  module Or, « Mes gains ») ; card STOP « cardio · paid at the end ».
- Retour 5 : ticket décoratif sans verrou, « SCRATCH TO REVEAL », seuil 30 %
  hors bandeau, vrai montant sous le voile, texture haptique, reprise
  (« Scratch » sur le galet, réouverture au lancement, « Scratch later »).
- Retour 6 : la lune non atteinte s'ouvre au tap court ; le panneau passe
  sous le galet quand une récompense est sur son chemin, sa coque ferme au tap.
- Story : prénom du profil.
- Non fait : `apple_jetons` (diagnostic au câble), le « tirer vers le bas »
  (capture à demander), la remise à zéro (§ 8, sur son oui écrit).

## 11. Ce qui n'a pas été mesuré, et ne se déduit pas

- Le store SwiftData de son iPhone n'a pas été relu depuis le 18-09 (76) : le
  nombre exact de galets affichés, la séance HIIT crashée en local, restent
  SUPPOSÉS (cohérents avec le serveur).
- Aucune capture de la Route, du panneau, du Coffre du 19-09 : les libellés
  « 19 / SEPT », « Session done / View », « 27 / 100 » sont LUS dans le code.
- La Live Activity après Stop, le tap de reprise depuis l'île, l'écart réseau
  réel de la story, le mode avion : jamais mesurés sur son iPhone.
- `apple-jeton` sur une vraie entrée Apple : jamais lu.
- Le comportement du Keychain après désinstallation : comportement iOS
  supposé.
- Le simulateur ne rend ni haptique, ni feuille Apple, ni Release (mais rend
  un trap d'index).

Preuves de cette analyse : rapports de crash (scratchpad `crash-81/`, à
ranger), scripts de lecture serveur (`faits-serveur.py`, `sonde_retour4.py`,
`lire_seances.py`, `verif_doublons.py`, `verif_vides_kind.py` — lecture seule
prouvée par `transaction_read_only = on` sur chaque requête), journaux des
enquêtes (`~/.claude/projects/…/subagents/workflows/wf_d3424ba7-18a/`,
`wf_e4d88ef1-6f8/`, `wf_b97eb263-b5f/`).
