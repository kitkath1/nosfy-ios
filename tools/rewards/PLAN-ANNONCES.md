# LES ANNONCES — notification ET pop-up, un seul backend

**Écrit le 29-08-2026** sur le verdict de Kathryn : *« notification et pop-up
rewards sont liées, analyse pour faire le backend de ça aussi »*.

Ce document ne remplace pas `PLAN-REWARDS-BACKEND.md` : il l'instruit. Le plan
dit **ce qu'il faudrait** ; celui-ci dit **ce qui existe vraiment**, mesuré
fichier par fichier le 29-08, et ce que le couple exige. C'est le brouillon du
**§4 quaterdecies**.

Les deux fiches écran : [`docs/screens/notification.md`](../../docs/screens/notification.md)
et [`docs/screens/reward-popup.md`](../../docs/screens/reward-popup.md).

> ⚠️ **30-08 — KATHRYN A TRANCHÉ, ET LA RÉFÉRENCE A CHANGÉ DE FICHIER.** Le
> contrat, les rangs, le rythme, le Welcome Back et la fin de séance sont
> écrits dans [`tools/annonces/PLAN-COFFRE-ANNONCES.md`](../annonces/PLAN-COFFRE-ANNONCES.md)
> (§0 ses mots, §1 les dix défauts qu'elle a pris, §3 **le contrat**, §5-§6 ce
> qui change et dans quel ordre). Ce document garde le **constat du 29-08**
> (neuf composants, quatre formules) : il reste juste comme mesure de ce qui
> existait. Là où il **proposait** (§5, §8) ou où le code a bougé depuis
> (8e8a0cc, 9ef6da1), c'est marqué **périmé** et le nouvel état est écrit à
> côté — les propositions ne se lisent plus comme des décisions.

---

## §0 — LE CONSTAT : NEUF COMPOSANTS ANNONCENT UN GAIN, ET AUCUN NE SE PARLE

Ce n'est pas une opinion, c'est un inventaire. Chacun a son fichier, son
moment, son z-index et **son propre calcul du gain** :

| # | Composant | Où | Quand | Statut |
|---|---|---|---|---|
| 1 | `PillGain` | `RestartSheet.swift:536` | +0,34 s après une série ordinaire, vit 2 s | production |
| 2 | `RewardPopup` (6 robes) | `RewardCard.swift:68` | séries de rang 3/5/10, ou **le chip « … »** | production |
| 3 | `SeriesCoinFlight` | `RestartSheet.swift:417` | à **chaque** série | production |
| 4 | `PiecesNotif` | `PlayerSeance.swift:260` | clôture (+1,6 s) et card à gratter (+0,3 s) | production |
| 5 | `VolDePieces` | `PlayerSeance.swift:206` | sur `notifPieces` | ⚠️ **en archive** (`HomeAuroraView` n'est montée nulle part) |
| 6 | `CardRecompense` | `RewardCheminCard.swift:20` | claim d'un nœud du chemin | production |
| 7 | `BoosterPopup` | `BoosterPopup.swift:298` | clôture (+5,2 s) | production — ⚠️ le « bouton d'essai » qu'on lui prête vit dans `HomeAuroraView`, donc en **archive** (voir ligne 5) |
| 8 | `StoryWin` | `StorySuite.swift:1457` | la page « butin » de la story | production |
| 9 | Les trois **robes de notification** | `NotifCard.swift`, `NotifChasse.swift` | — | ⚠️ **banc seulement** (`-notifLab`) |

⚠️ **Périmé depuis 8e8a0cc (30-08) pour les lignes 4, 7 et 8** — la chaîne de
clôture n'est plus « capsule +1,6 s, pop-up booster +5,2 s ». Relu le 30-08 au
soir : `terminerSeance()` pose la **story** à +2,0 s (`WoopApp.swift:532-535`) ;
à sa fermeture, `enchainerApresStory()` (`WoopApp.swift:543-556`) pose la capsule
`PiecesNotif` à **+0,3 s** (retirée à +3,3 s) puis `SacreEtat.shared.proposer()`
à **+3,4 s** — la card booster, plus `BoosterPopup`. `StoryWin` est donc **dans
la vraie chaîne**, plus seulement au banc. Le créneau reste unique
(`DepartSeance.swift:43`, hôte `WoopApp.swift:1238-1239`). Et **tranché le
30-08** : cette chaîne devient story → **page noire** avec les dalles empilées →
**le chemin** animé → « Ouvrir » (plan §0, §5.1, J3).

⚠️⚠️ **LE MÊME GAIN EST RECALCULÉ QUATRE FOIS — ET LES QUATRE NE DONNENT PAS
LE MÊME NOMBRE.** Elles partagent le facteur 20, jamais le multiplicande :

```
WoopApp.swift:442             a.setCount * 20       → séries ENREGISTRÉES
StorySuite.swift:1489         session.series * 20   → séries ENREGISTRÉES
CoffreFortPurse (completedSets)                     → séries FAITES
ExerciseDetailView.swift:2171 max(faites,1) * 20    → séries FAITES, par exo,
                                                      décalées d'un cran (§2.3)
```

**Sur une séance d'un exercice à 5 séries enregistrées dont 4 faites** —
mesuré, pas supposé :

| qui parle | ce qu'il annonce |
|---|---|
| la clôture et la story | **100** |
| le coffre et le profil | **80** |
| la pill à la 4ᵉ série | **60** |

**Trois nombres différents pour le même argent, le même jour.**

⚠️ **Et ce n'est donc PAS une simple duplication de code** : c'est un
désaccord de **DÉFINITION** — « série enregistrée » contre « série faite » —
qui survivrait à toute factorisation naïve. La fonction manquante devra
**trancher laquelle est la vraie** avant d'être écrite. (Le serveur, lui, a
déjà tranché de fait : `cloturer_seance` reçoit `a.setCount`, donc les séries
**enregistrées** — y compris celles qu'on n'a jamais faites.)

**C'est LA raison pour laquelle les deux sujets n'en font qu'un.** Kathryn a
raison au-delà de ce qu'elle visait : ce ne sont pas deux composants liés,
c'est **une seule fonction manquante** — *annoncer un gain* — qui a été
réimplémentée neuf fois.

⚠️ Et deux composants sont morts sans qu'on l'ait remarqué : la page **BRAVO**
(`BravoLab.swift:228`) n'a plus **aucun** site de montage hors de son banc, et
le **vol de pièces** de la home est dans une vue archivée. Toute la cérémonie
BRAVO est du code entretenu que le flow ne traverse plus.

---

## §1 — LA FAMILLE : UNE DÉCISION, TROIS FORMATS

La bonne façon de lire les deux chantiers :

> **Il n'y a pas « les notifications » et « les pop-ups ». Il y a UNE
> décision — annoncer, et comment — qui rend l'un des trois formats.**

| Format | Ce qu'il coûte à la joueuse | Aujourd'hui |
|---|---|---|
| **le silence** | rien | ~60 % des séries (le cas `.pill` est déjà « presque rien ») |
| **la NOTIFICATION** (4 robes) | rien : elle traverse, on ne la tape pas | codée, **branchée nulle part** |
| **la POP-UP** (6 robes) | l'écran, un scrim, un geste | branchée, mais sur des modulos |

Le code le **dit déjà** : `IssueSerie` (`RestartSheet.swift:596`) a exactement
ces trois cas — `.pill`, `.moment`, `.reward` — et `DecideurSerie` est annoté
*« une PLACE, pas un MOTEUR »*. **La place existe. Le moteur, non.**

⚠️ **Mais la place est trop étroite** : `DecideurSerie` ne vit que dans la
**fiche exo**. Les quatre autres chaînes d'annonce (clôture, card à gratter,
story, coffre) ne passent pas par lui — leurs délais sont écrits en dur, et
aucune ne sait ce que les autres viennent de montrer.

---

## §2 — CE QUI DÉCIDE : le moteur qui n'existe pas

### 2.1 Ce que le plan exige (§2)

Budget de séance (4 pop-ups pour ~20 séries, dont ≤ 1 reward monétaire et
≤ 1 vidéo) · écart minimal (3 séries **et/ou ?** 6 min) · file de priorité
(Rare > Reward > Moment, un fait qui arrive en cooldown est **abandonné**,
jamais mis en file) · rareté serveur avec *pity timer*. Et un interdit,
écrit noir sur blanc :

> *« Interdiction des positions fixes : aucun déclencheur du type "série
> 5/10/15" ; les triggers sont des FAITS, pas des compteurs. »*

⚠️ **PÉRIMÉ — tranché le 30-08 dans l'autre sens** (plan §0 « pop-ups en
séance », §1 Q1-Q2, §2.7) : elle veut des **rangs FIXES 3 / 5 / 10**, puis « et
plus » = **un rang au hasard toutes les 5 à 8 séries** (15±, 21±…) — jamais
tous les multiples ; la **vidéo une seule fois**, au rang 10 ; l'écart « 3
séries ET 6 min » ne s'applique qu'aux rangs tirés après le 10. Le budget
(4 / 1 pièces / 1 vidéo) et la file de priorité tiennent. L'interdit du plan
backend §2 est donc à réécrire (hors de ce lot) : le compteur **est** un
déclencheur voulu, le hasard vient après.

### 2.2 Ce qui tourne

```swift
if serie % 10 == 0 { return .reward(style: .fire, video: "reward-rare") }
if serie % 5  == 0 { return .reward(style: .halo, video: nil) }
if serie % 3  == 0 { return .moment(...) }
return .pill(gain: gain, total: total)
```

(`RestartSheet.swift:608-630`, relu le 30-08 — les trois modulos :614, :618,
:622 ; sans hasard, sans budget, sans horloge, sans serveur.)

⚠️ **C'était mot pour mot le déclencheur que le plan interdisait** — et depuis
le 30-08 c'est **à moitié voulu** : les rangs 3, 5 et 10 sont les bons ; ce qui
reste faux, c'est **tous les multiples** (6, 9, 12, 15, 20…) et la vidéo **à
chaque dizaine**. Le rythme qui en sort reste celui que la décision refuse :
une pop-up toutes les 3 séries, **deux d'affilée aux rangs 9 et 10**, jusqu'à
**6 interruptions** dans une séance de 20 séries au lieu des 4 — dont une vidéo
de 8 s tous les 10 rangs. Le décideur à budget est le **J4** (plan §5.2.7) ; ses
clés (`popup_rangs_fixes [3,5,10]`, `popup_rang_video 10`,
`popup_hasard_ecart_min/max 5/8`, `popup_hasard_apres 10`) sont la migration
**M2** (plan §4), pas encore écrite.

### 2.3 ⚠️ ET LA RÈGLE EN DUR NE TIENT MÊME PAS SA PROPRE PROMESSE

`faites` est lu **synchroniquement** après `settleSeries(f, coins: true)`, dont
l'écriture est **différée de 0,55 s**. Le décideur juge donc le rang de la
série **précédente** :

| voulu | réel |
|---|---|
| MOMENT à la 3ᵉ | **4ᵉ** |
| `.halo` à la 5ᵉ | **6ᵉ** |
| vidéo rare à la 10ᵉ | **11ᵉ** |

Et la pill **sous-compte de 20 pièces** : « 20 coins this session » sur la
2ᵉ série. ⚠️ Le banc `-serieFin` passe `serie: n` en dur — **il ne reproduit
pas le décalage, il ne peut donc pas le révéler**. Un bug qu'aucun banc ne
voit est un bug qui vit longtemps.

### 2.4 Ce qu'il faut, et où ça vit

| Décision | Qui | Pourquoi pas ailleurs |
|---|---|---|
| **annoncer ou se taire** | serveur (`reward_rules` + budget de séance) | *« le pacing n'est pas un dé »* — et une règle client est falsifiable |
| **quel FORMAT** (silence / dalle / pop-up) | serveur | c'est le budget d'attention, la ressource rare |
| **quelle ROBE** dans le format | **client**, rotation déterministe | ⚠️ elle s'affiche **avant** toute réponse ; la demander au serveur, c'est l'attendre |
| **le MONTANT** | client d'abord, serveur qui rattrape | loi du §1 : *« l'UI affiche le gain tout de suite, le ledger rattrape »* |
| **la RARETÉ** (pièce d'argent) | serveur, toujours | RNG client = farmable |

⚠️ **Tranché le 30-08, et ce tableau bouge sur une ligne** : « annoncer ou se
taire » et « quel FORMAT » ne sont **pas** demandés au serveur à chaque série —
**le rang est tiré au CLIENT depuis les clés serveur** (`regles_annonces()` lue
en début de séance), hasard **déterministe par séance** (`hash(workout_id,
rang)`), budget tenu en mémoire de séance ; pas de table `popup_servies`
(plan §4 « ce qu'on ne fait pas », §5.2.7). Une pop-up ne paie rien, donc rien
n'est falsifiable qui compte. La RARETÉ, elle, reste au serveur (`roll_rare`,
déployée le 29-08 — §10).

⚠️ **La robe est le seul point où les deux chantiers divergent, et c'est
normal** : la notification se pose en 0,3 s (rotation client) ; la pop-up
prend l'écran et peut, elle, attendre une réponse — c'est même **la seule qui
en a le budget**.

---

## §3 — CE QUI EST ANNONCÉ : le grain manquant

### 3.1 Le fact engine n'existe pas

Aucune structure `{id, kind, value, unit, comparison, window, rank}`, aucune
des 9 détections v1, **aucun fetch des références historiques** que le §3
décrit pourtant comme *« un seul fetch, petit, cacheable »*.

⇒ Aucune annonce ne peut dire « +4 kg vs la dernière séance » ni « #1 sur
14 jours ». Le seul fait honnête aujourd'hui est un cumul de la séance en
cours — et c'est exactement ce que `DecideurSerie` fabrique à la main.

⚠️ **Conséquence directe sur la robe `.spotlight`** : sa matrice tire ses
bribes d'une **liste figée**. Elle affiche « 24KG » à quelqu'un qui n'a jamais
soulevé 24 kg. Le plan exige les vrais faits ; le code montre du décor. **?**
décor assumé, ou mensonge à corriger — pas tranché.

### 3.2 ⚠️ L'OUTBOX N'A PAS LE GRAIN DE LA SÉRIE

Le §1 spécifie `{session_uuid, serie_index, type, facts, montant, ts}` écrit
**au fil de l'eau**, avec un index d'idempotence sur
`(user_id, session_uuid, serie_index, raison)`.

L'`OutboxGains` réelle a **trois cas** : `finDeSeance(seance:series:)`,
`retourQuotidien`, `noeudChemin`. **Aucun `serie_index`, aucun `facts`.** Le
crédit ne part **qu'à la clôture, en bloc**.

⇒ **C'est le trou qui bloque les deux chantiers ensemble.** Une annonce par
série — dalle ou pop-up — n'a aucune écriture correspondante. La loi « l'UI
affiche, le ledger rattrape » **n'a pas d'objet à rattraper**.

### 3.3 Ce qui n'est jamais crédité

| Ce que l'écran dit | Ce que le serveur reçoit |
|---|---|
| pop-up `.moment` / `.reward` de série | **rien** (`rewardShow = true`, point) |
| card à gratter : « **Added to your balance** » | ✅ **branché le 29-08** — `.noeudChemin` posté depuis `reclamer` |
| Welcome Back : « Claim +N » | **rien du bouton** — son action est `fermer` (`RewardCard.swift:873-874`, relu 30-08) ; le versement, lui, part au premier plan (✅ 29-08, `WoopApp.swift:91`). ⚠️ **Tranché le 30-08 : le contraire** — les +10 partent **au tap du Claim**, le premier plan ne paie plus ; jour = minuit **Paris** ; puis une dalle « +10 ». Voir `ANALYSE-WELCOME-BACK.md` §3 et plan §5.3 (J2) |
| « 2 boosters gagnés » | **rien** — `boostersEnAttente` n'est **jamais incrémenté**, nulle part |

**Au moment où ce document a été écrit**, les cas `.noeudChemin` et
`.retourQuotidien` de l'outbox étaient **écrits, traités, et postés par
personne** : du code mort des deux côtés d'un tuyau complet. « Added to your
balance » était un mensonge — le compte ne bougeait pas, et une réinstallation
rendait tous les nœuds re-réclamables.

✅ **Les deux sont branchés depuis le 29-08** (§7, étape 3). Ce qui reste
vrai : le grain de la série manque toujours — et **il n'est pas dans le plan
du 30-08** (le crédit reste à la clôture, en bloc ; la dalle de série est
« locale, le taux vient du serveur », plan §3). ⚠️ **Périmé depuis 9ef6da1
(30-08)** : « le tirage du chemin est encore au client » — le chemin **tire au
serveur** (`tirer_noeud_chemin`, qui rend type, montant, monnaie, robes,
rareté ; plan §2.6). Ce qui manque encore côté app : la dalle après la card ne
part que pour les pièces (`RewardChemin.swift:286-294`), rien pour un tirage en
sachets — tranché : card **et** dalle, robe pièces ou booster (plan §0, §5.4.13).

### 3.4 Et le serveur, lui, n'avait pas non plus tout (état du 29-08 matin)

⚠️ **PÉRIMÉ depuis 97cf6d9 (29-08 soir) — gardé pour l'histoire, corrigé au
§10.** Ce qui était vrai au matin :

`cloturer_seance(p_workout, p_series)` faisait **deux écritures** : les pièces
et le sachet forfaitaire. Elle **ne tirait aucune rareté** et **n'écrivait
jamais `booster_progress.reste`** — donc la pièce d'argent ne pouvait pas être
gagnée (booster noir inatteignable) et la jauge aurait dit 0/100 pour toujours.

**Ce qui tourne depuis** (déployé et sondé, §10) : `cloturer_seance` tire
`roll_rare` (privée, 1/30, pity 45, cooldown 10) et rend `argent`, `reste`,
`prix_booster` ; `reste` est **dérivé** (`solde_or mod prix_booster`) ;
`booster_progress` est morte et **ne se réveille pas** (un solde se dérive).
Ce qui reste faux le 30-08 : `reste` est calculé sur le solde **total** —
`solde_or 1360 → reste 60`, treize tranches de 100 qui ne sont des sachets
nulle part (plan §2.4) ; **tranché** : conversion automatique à 100 au serveur
(`convertir_pieces()`, plan §4 M1.3, J1), et `cloturer_seance` rejouée rend
**le stocké** au lieu de zéros (M1.5).

---

## §4 — CE QUI EST RACONTÉ : l'IA, et ce qu'elle n'a jamais fait

### 4.1 ⚠️ Aucune IA n'a jamais écrit un texte affiché dans cette app

Deux edge functions existent ; **une seule tourne** :

- **`forge-card`** ✅ — appelée par le manège. GPT-5 écrit une *scène*,
  `gpt-image-1` la peint. ⚠️ Le texte de GPT-5 **n'est jamais affiché** :
  c'est un prompt pour le peintre.
- **`weekly-synthesis`** ⚠️ **code mort, et pas même déployée** — Claude écrit
  4-6 phrases, mais la seule vue qui les affiche (`SynthesisCard`) vit dans
  `ProgressionView`, qui **n'est montée nulle part** : l'onglet Progrès affiche
  le calendrier depuis le 18-08. Sondée le 30-08 : absente de `functions list`
  (`forge-card` seule, ACTIVE v4), `POST /functions/v1/weekly-synthesis` → 404
  (plan §2.2). `narrate-reward` → 404 aussi : elle **n'existe pas**, c'est le
  **J5** (plan §4 E1).

⇒ **On ne peut pas dire « ça marche déjà, on recopie ».** Ni la latence, ni le
rendu, ni le comportement en échec n'ont jamais été vus à l'écran.

### 4.2 Ce qui est réutilisable — et ce qui ne l'est surtout pas

✅ **Le patron de `forge-card`** : clé du modèle **dans l'edge function**,
appelant vérifié (`admin.auth.getUser`, 401 sinon), manettes du client
**supprimées du corps**, rareté **jamais acceptée du client** (déduite de
`user_boosters.origine`), et **garde d'idempotence** (un booster scellé rend
sa carte au lieu d'en tirer une seconde).

❌ **À ne pas copier** :
- l'auth de `weekly-synthesis`, qui ne vérifie que le **préfixe « Bearer »**
  sans valider le jeton, et s'en remet à un `verify_jwt` **absent de
  `config.toml`** — invisible dans le dépôt ;
- le repli de `ForgeServeur` sur un **compte de test aux identifiants en dur
  dans le binaire**. Sur une fonction facturée au token, c'est un robinet
  ouvert à qui désassemble l'app.

### 4.3 Les quatre pièces manquantes

| Ce qu'il faut | Pourquoi |
|---|---|
| **un contrat JSON typé** (`{title, subtitle, bigLines[]}`) + parse strict | les deux fonctions rendent du **texte libre** ; « 4 à 6 phrases » de prose est l'inverse de ce qu'une card demande |
| **des bornes de longueur, aux TROIS étages** (prompt, serveur, rendu) | il n'y en a **nulle part** : `Text` sans `lineLimit` ni `minimumScaleFactor` — un titre de 40 signes casse la carte |
| **une persistance** (événement → texte, idempotente) | un texte non stocké se **regénère** : la même série raconterait deux histoires, rien ne serait rejouable. ⚠️ Tranché le 30-08 : **pas au J1** — une table `reward_narrations` seulement si le rejeu doit rendre le même texte (plan §4 E1) |
| **un budget de latence** (pré-chauffe + gabarit de secours) | `forge-card` assume 60-90 s ; une fin de série n'a pas ce budget, et **aucun repli textuel n'existe**. Tranché le 30-08 : **l'IA écrit la PROCHAINE pop-up** (envoyée à la série N, lue à N+1), `AbortController` 10 s, gabarit sinon — **jamais d'attente, jamais de spinner** (plan §0, §4 E1, §5.2.8) |

### 4.4 ⚠️ Et l'IA n'a nulle part où écrire — mais le fil existe

**Aucun mot géant ne vient d'un champ de texte de l'API.** Nuance mesurée, et
elle change ce qui reste à faire : `RewardPopup` **remonte** bien `lignes:`
dans deux montages sur trois — `.spotlight` y passe le nombre en toutes
lettres dérivé de `count` (`:408`), welcome/`.texte` deux littéraux (`:503`) —
et seul `.neon` laisse jouer le défaut « YOU / MADE / IT ».

⇒ **Il ne manque pas un fil à tirer, il manque une SOURCE.** Le travail
restant est plus petit qu'annoncé côté vue, et entier côté serveur. Et le
composant pose déjà la loi qui la bornera : *« l'IA fournit les MOTS, jamais
la mise en forme d'une donnée »*.

Même chose pour `actionLabel` / `dismissLabel` (les boutons sont des
ternaires en dur) et pour `sticker:`. **La dette de l'audit du §4 est
intégralement impayée.**

⚠️ **Et le contrat de texte n'est pas uniforme** : `title` est **jeté** par
`.neon`, `.spotlight` et welcome/`.texte` ; `subtitle` par `.spotlight` et
welcome/`.texte` ; `unit` par `.neon` et `.welcome`. Le backend peut remplir
les quatre champs et n'en voir **aucun** à l'écran.

⇒ **Il faut un tableau du contrat PAR ROBE avant toute IA.** C'est le §4 du
plan qui l'annonce (*« C'est ce tableau — et lui seul — que l'IA reçoit »*) et
**qui n'a jamais été écrit**.

---

## §5 — LE CONTRAT PAR CATÉGORIE — PÉRIMÉ : tranché le 30-08, il vit ailleurs

⚠️ **Ce tableau était une PROPOSITION du 29-08 ; Kathryn a écrit le sien le
30-08.** Le contrat en vigueur est **`tools/annonces/PLAN-COFFRE-ANNONCES.md`
§3** — une ligne par événement, avec la robe et **qui sait quoi** (quelle
réponse serveur porte le nombre). Il n'est pas recopié ici : deux tableaux qui
se contredisent valent moins qu'un seul qui dit vrai.

**Ce qui diffère de la proposition du 29-08**, ligne à ligne :

| ce que ce document proposait | ce qu'elle a tranché (plan §3) |
|---|---|
| série ordinaire → notification, « outbox, grain série » | **dalle** « +20 », 2 s, robe pièces en rotation ; crédit **local**, le taux vient du serveur — pas de grain série dans l'outbox (le crédit reste à la clôture, en bloc) |
| « série + fait notable » → MOMENT ; « gain monétaire notable » → REWARD ; « rare » → pop-up `.fire`/`.spotlight` + vidéo | **des rangs** : 3 → `.galet`, 5 → `.halo`, 10 → `.fire` + vidéo, puis un rang **au hasard** toutes les 5-8 séries ; le texte vient de **l'IA préparée à la série d'avant**, sinon gabarit ; la pièce d'argent **n'est pas une pop-up de série** (voir clôture) |
| clôture → **une** notification (`gain`, `fraction`) ; sachet → une notification à part | **une PILE de dalles** sur une page noire après la story : pièces (jauge) → sachet forfaitaire (robe **booster**, à coder) → **pièce d'argent** (robe **argent**, à coder) → sachet(s) **converti(s)** à 100 (nouveau) ; chacune lue dans la réponse de `cloturer_seance` ; puis **le chemin** animé |
| — (rien après le chemin) | la pop-up **« Ouvrir »** après la route posée = une **invitation** (« ton sachet t'attend »), **pas une annonce** — le sachet a déjà été dit dans la pile (Q4) ; elle va droit au manège (Q6) |
| claim du chemin → notification après la card, « `noeudChemin` à poster » | la card à gratter **et** une dalle après (« +176 », robe pièces **ou booster** selon `tirer_noeud_chemin`) ; posté depuis le 29-08, tiré au serveur depuis 9ef6da1 |
| Welcome Back → pop-up sur la home 1×/jour, « `retourQuotidien` à poster » | pop-up **+ bouton Claim** au 1er premier plan après **minuit Paris**, si `retour_disponible` (lu sans payer) ; **le tap paie** ; puis une **dalle « +10 »** sur la home — pas de notification iPhone |
| `.neon` · `.spotlight` · `.welcome` sans événement → « leur en donner un, sinon les retirer » | `.welcome` en a un ; **`.neon` et `.spotlight` n'en ont aucun → à retirer** si rien ne les prend (plan §3, dernière ligne) |
| — | **séance record** → la story TOP à la place de la normale (moteur de faits posé, chantier stories, hors lot) ; **la flamme** → affichée, **jamais annoncée** |

Les robes **booster** (robe 4) et **argent** (robe 5) n'existent pas encore —
c'est le **J2** (plan §5.1.2) ; la pile et la page noire, le **J3**.

---

## §6 — CE QUI DOIT ÊTRE RETIRÉ AVANT DE BRANCHER

Ce ne sont pas des détails : ce sont des choses **livrées** qui mentent.

### ✅ Fait le 29-08 — les quatre mensonges livrés

| Quoi | Ce qui a changé |
|---|---|
| ⚠️ le **chip « … »** du header (`ExerciseDetailView.swift:1846`, monté **sans drapeau**) | derrière **`-rewardAtelier`**. Il ouvrait une récompense **fausse**, atteignait le **Welcome Back en deux taps** — au milieu d'une séance — et le mélange atelier/jeu était **réel mais inverse de ce qu'on croyait** : tapé pendant la pill, `serieAPoser` est encore posé, donc sa fermeture **ouvrait le panneau « Recommencer ? »**. Une card d'atelier commandait une étape du parcours |
| ⚠️ le **décalage d'un rang** (`:2163-2172`) | le rang tient compte de l'écriture différée **et il est mémorisé** (`rangIssue`) : une relecture de `sets` changerait de valeur sous la card, entre sa naissance à +0,34 s et l'écriture à +0,55 s. Le MOMENT retombe à la 3ᵉ, la pop-up à la 5ᵉ, la vidéo rare à la 10ᵉ ; la pill ne sous-compte plus |
| ⚠️ le **plancher `max(…, 4)`** (`:1070`) | réservé à l'**atelier**, là où il avait été écrit |
| ⚠️ le **montant du Claim en séries** | la robe welcome annonce **10 pièces**, unité `Coins`. ⚠️ Constante Swift provisoire — à lire dans `regles_annonces()` |
| le banc `-serieFin` | porte le rang lui aussi : **un banc qui ne reproduit pas le jeu ne peut rien en révéler**, et c'est précisément ce qui a laissé vivre le décalage |

### Ce qui reste

| Quoi | Où | Pourquoi ça presse |
|---|---|---|
| `-rewardFlow` appelé depuis un chemin de **production** | `:2233`, neutralisé par une garde interne | le vrai branchement passe par ce point : qui enlèvera la garde aura **deux moteurs d'issue en parallèle** |
| ⚠️ la constante `piecesRetourQuotidien = 10` | `ExerciseDetailView.swift:2270` (lue :1097-1098, relu 30-08) | elle double une règle qui vit déjà en base — tranché : **retirée au J2**, le montant vient de la réponse `montant` du Claim (plan §5.3.10) |
| 6,14 Mio de **vidéo orpheline** | `Woop/Media` | poids payé à chaque install, et la robe welcome **boucle la mauvaise vidéo** |

---

## §7 — L'ORDRE DE BRANCHEMENT

L'école du coffre (§6.6 de `coffre-rewards.md`) : **écrire avant de lire**,
et une étape qui ne se voit pas est une étape qu'on peut défaire.

| # | Ce qu'on fait | Ce qui change à l'écran | État |
|---|---|---|---|
| **1** | **Le ménage du §6** — le chip fake, le plancher, le décalage, le montant du Claim | ⚠️ **oui, et c'est voulu** : les rendez-vous reviennent où ils devaient être | ✅ **29-08** (build vert ; ⚠️ **pas encore mesuré au simulateur**) |
| **2** | **Le grain de la série dans l'outbox** (`serie_index`, `facts`) + `settle_session` idempotent | rien | ⚠️ **hors du plan du 30-08** : le crédit reste à la clôture, en bloc (plan §3, §4 « ce qu'on ne fait pas ») |
| **3** | **Poster ce qui est déjà écrit** : `.noeudChemin` au claim, `.retourQuotidien` au premier plan | rien — sauf que le compte devient vrai | ✅ **29-08** — ⚠️ tranché le 30-08 : `.retourQuotidien` **déménage au tap du Claim**, le premier plan ne paie plus (plan §5.3, **J2**) |
| **4** | **`reste`** — ⚠️ **DÉRIVÉ**, pas écrit : `solde_or mod prix_booster` (un solde ne se stocke pas) | rien encore (personne ne le lit) | ✅ **29-08** — ⚠️ vrai seulement quand le solde < 100 : la **conversion automatique** à 100 est tranchée (plan §4 M1.3, **J1**) |
| **5** | **Un seul point d'annonce** : `DecideurSerie` sort de la fiche et devient le passage obligé des cinq chaînes | rien, si le portage est fidèle | → **J4** : un **décideur à budget** (rangs fixes 3/5/10 puis hasard, clés serveur M2), plan §5.2.7 |
| **6** | **Les clés de pacing dans `reward_rules`** (budget, écart, cooldowns) + `regles_annonces()` | le rythme cesse d'être en dur | ✅ **29-08** (le preset `demo` reste à faire) — ⚠️ **lues par personne** au 30-08 (grep : un commentaire, `ExerciseDetailView.swift:2269`) ; + 5 clés de rangs au **J4** (M2) |
| **7** | **La notification branchée** — les 4 robes prennent la place de la pill et de la capsule | **oui** — le sujet du chantier | → **J2** (file d'annonces `[Annonce]` + robes **booster** et **argent**) et **J3** (la page noire, la pile), plan §5.1 ; `PillGain` **garde** son créneau en séance |
| **8** | **Le fact engine**, puis les vrais faits dans la matrice | les textes deviennent vrais | moteur de faits **posé** (`20260830100000_moteur_faits.sql`), à appeler — chantier stories, hors lot (plan §3) |
| **9** | **`roll_rare`** — la pièce d'argent devient gagnable | le booster noir s'ouvre enfin | ✅ **29-08** — la dalle **argent** qui l'annonce est le J2/J3 (aujourd'hui : un `print`, `OutboxGains.swift:199`) |
| **10** | **`narrate-reward`** — l'IA écrit, sur des gabarits déjà en place | les textes deviennent contextuels | → **J5** (plan §4 E1) : sondée 30-08 → 404, n'existe pas |

**Ce qui est parti le 29-08** : la migration
`supabase/migrations/20260829120000_annonces.sql` (le `reste` dérivé,
`roll_rare`, la clôture qui rend l'annonce entière, 17 clés de rythme,
`regles_annonces()`) et le branchement des deux tuyaux morts côté app
(`.noeudChemin` depuis `RewardCheminEtat.reclamer`, `.retourQuotidien` au
retour au premier plan). La doctrine est écrite en **§4 quaterdecies** du plan
backend.

⚠️ **L'étape 1 est passée devant les autres dans l'ordre de valeur** : tant
que le décalage d'un rang et le chip « … » sont là, tout réglage de rythme se
juge sur un moteur qui ne tient pas ses propres rendez-vous.

⚠️ **Les étapes 1 à 6 ne demandent AUCUNE nouvelle idée** : tout est déjà
écrit, écrit à moitié, ou écrit des deux côtés d'un tuyau qu'il ne reste qu'à
brancher. L'IA est **la dernière** étape, et le §9.6 du plan le recommande
lui-même : *« gabarits d'abord, l'IA est une couche qui se pose après, le JSON
est le même »*.

---

## §8 — À TRANCHER — quatre sur huit le sont, depuis le 30-08

1. ✅ **TRANCHÉ le 30-08** — *une notification consomme-t-elle le budget des 4
   pop-ups ?* **Non** : une dalle ne consomme pas le budget, et elle a **son
   propre plafond, 6 par séance** ; le budget des pop-ups est 4 / 1 en pièces /
   1 vidéo (plan §0 « le rythme »). Les clés `notif_consomme_budget = false` et
   `notifs_max_seance = 6` (`annonces.sql:146-151`) disent déjà cela — lues par
   personne jusqu'au J4. (Ce qui est écrit ci-dessous était la proposition : le
   plan a tranché ce genre de question pour la story, *« c'est une page, pas
   une interruption »* — une dalle qu'on ne tape pas ne dépense pas
   d'attention.)
2. ✅ **TRANCHÉ le 30-08 — DANS L'AUTRE SENS que la proposition.** *Si la dalle
   et la pop-up annoncent le même gain, laquelle gagne ?* Ce document proposait
   « une seule annonce par événement, **jamais les deux** — la pop-up remplace
   la dalle ». Elle garde la doctrine **« une annonce PAR événement »** mais
   **la pile est voulue** : à la clôture, pièces + sachet (+ argent, + convertis)
   sont **deux à quatre événements, donc deux à quatre dalles empilées** sur la
   page noire ; au nœud du chemin, la card à gratter **et** une dalle après.
   « La pop-up remplace la dalle » **tombe** pour ces deux cas ; la pop-up
   « Ouvrir » qui suit n'est pas une seconde annonce du sachet mais une
   **invitation** (Q4). Le §4 quaterdecies de `PLAN-REWARDS-BACKEND.md` et le
   commentaire de la clé `annonce_une_par_evenement` (`annonces.sql:138-144`)
   disent encore l'inverse — **périmés, à réécrire** (plan §2.7, hors de ce
   lot) ; le site passe `b-flow-deux-annonces` de 🔴 à ⚪ « voulu : la pile
   n'existe pas » (plan §7 J0).
3. ✅ **TRANCHÉ le 30-08** — *l'écart minimal : OU ou ET ?* **ET** : 3 séries
   **et** 6 min, sur l'horloge de séance — et il ne s'applique qu'aux rangs
   tirés **au hasard après le 10** ; les rangs fixes 3 / 5 / 10 gagnent sur
   lui (plan §1 Q1, défaut pris). `ecart_exige_les_deux = true`
   (`annonces.sql:102-110`) est la bonne valeur.
4. **Le chip « … »** doit-il redevenir « date, heure » comme son commentaire
   le prévoyait, ou disparaître ? — **toujours ouvert**.
5. ✅ **TRANCHÉ le 30-08, pour la première version seulement** — *le texte
   d'IA est-il stocké ou regénéré ?* **Pas stocké** quand `narrate-reward`
   arrive (J5) : l'IA sert la **prochaine** pop-up, et une table
   `reward_narrations (user, workout, serie_index)` unique ne vient que
   **si** le rejeu doit rendre le même texte (plan §4 E1 : « pas au J1 »). La
   question reste posée pour le rejeu.
6. **La langue** : EN partout, ou FR/EN localisé dès v1 ? Aujourd'hui les deux
   cohabitent (`PillGain` en anglais, `PiecesNotif` en français, `BoosterPopup`
   en français, `RewardPopup` en anglais).
7. **Le sort de BRAVO** : morte de fait — on l'assume et on la retire, ou on
   lui rend une porte ?
8. `reward-piece-3` et `-5` **sans chauve-souris** : plans « objet nu » voulus,
   ou prises à refaire ? Le jour où la rotation sera branchée, une série sur
   cinq montrera une pièce **sans le messager**.

---

## §9 — CE QUI EST MESURÉ, ET QUI NE SE REJOUE PAS

- **9 composants** annoncent un gain ; **4 formules** calculent le même nombre
  et **en rendent trois différents** (100 / 80 / 60) ; **3** sont morts ou en
  archive (BRAVO, le vol de pièces, le bouton d'essai booster).
- **3 robes de pop-up sur 6** sont inatteignables par le jeu.
- **7 vidéos de reward sur 11** (**7,93 Mio**) ne sont jouables qu'au banc ;
  **6,14 Mio** de vidéo sont orphelines dans le bundle.
- La famille reward pèse **15,07 Mio** ; `Woop/Media` pèse **195,5 Mio** de
  vidéo (**244 Mio** en tout) — les rewards n'en sont que **6,2 %**.
- Côté Supabase, **tout ce que les annonces doivent lire ou déclencher existe
  et répond** (sondé en HTTP le 29-08 : `etat_coffre`, `cloturer_seance`,
  `claim_retour_quotidien`, `reclamer_noeud_chemin`, `historique_gains`,
  `claim_booster`). Ce qui manque est **dans l'app**.
- ⚠️ Sauf `settle_session`, `reward_events` et `welcome_state` : **ceux-là
  n'existent nulle part** — et `welcome_state` n'existera pas : sa question
  (« disponible aujourd'hui ? ») devient la clé `retour_disponible` de
  `etat_coffre()` (plan §4 M1.7, J1). `roll_rare`, elle, **existe depuis le
  29-08 au soir** (97cf6d9, §10) — la ligne d'origine la comptait parmi les
  absents, c'était vrai le matin.

---

## §10 — LE DÉPLOIEMENT, ET CE QU'IL A RÉVÉLÉ (29-08)

Les deux migrations sont **appliquées et vérifiées** sur `ytnnyjkramgiqyxdrkcu` :
`20260829120000_annonces.sql` puis `20260829130000_roll_rare_prive.sql`.

### Ce que la sonde a prouvé — sur le compte de TEST, jamais un vrai

| Preuve | Mesure |
|---|---|
| **le `reste` dérivé dit la vérité** | `solde_or 160 → reste 60`, puis `1240 → 40`. Avant la migration il valait **0 en permanence** (table jamais écrite) |
| **la clôture crédite juste** | 3 séries → `pieces 60`, `pieces_creditees true`, `booster_neuf true`, solde 160 → 220 |
| **le REJEU ne crédite rien** | 2ᵉ et 3ᵉ appels identiques : `pieces 0`, `pieces_creditees false`, `booster_neuf false`, même `booster_id`, solde **figé** |
| ⭐ **la pièce d'argent tombe enfin** | une ligne `piece_argent · delta 1 · silver` rattachée à sa séance, et `solde_argent : 1` — **elle était impossible à gagner avant** |

### ⚠️ Et une faille, trouvée par la sonde et pas par la lecture

`roll_rare` répondait **`23502` not-null** à un appel anon : elle **s'exécutait**.
Cause : **sur Supabase, `revoke … from public` ne suffit pas** — les
`default privileges` accordent `execute` **nominativement** à `anon` et
`authenticated`. Il faut les nommer.

**Ce que ça aurait coûté** : la fonction accepte un `workout_id` quelconque,
donc l'index `(user_id, raison, workout_id)` ne bloque rien entre deux uuid
différents. Un compte connecté n'avait qu'à rappeler avec un uuid neuf jusqu'à
ce que le `random()` tombe — **le RNG client farmable que le §2 interdit**, sur
la pièce dont la rareté est toute la valeur.

Refermé et **re-mesuré** : `403 42501 permission denied`, avec la clé anon
**et** avec une vraie session. Non-régression vérifiée sur les huit autres
fonctions.

⚠️ **La leçon est générale** : après tout `db push`, appeler chaque fonction —
et garder un **témoin qui doit échouer** (une fonction inexistante rend 404
`PGRST202`). Une sonde qui rend 200 partout ne prouve rien.
