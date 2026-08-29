# Écran — LA NOTIFICATION DE GAIN (le toaster)

`Woop/Views/NotifCard.swift` (le template, la jauge, le gros texte) ·
`Woop/Views/NotifChasse.swift` (la châsse) · banc `Woop/Views/NotifLab.swift`
(`-notifLab`) · plans `tools/notifs/PLAN-NOTIFS-V8.md` et `-V9.md`.

> **Convention de ce document.** Ce qui est écrit sans marque est **vérifié
> dans le code** (29-08, relecture adverse ligne par ligne). Ce qui porte
> **?** n'est pas sûr et attend une décision ou une vérification. Ce qui porte
> **CIBLE** est décidé mais **n'existe pas encore**. Les tables de la base ne
> sont pas décrites ici : seulement ce que le backend doit **décider** et
> **renvoyer**.
>
> ⚠️ **La dalle elle-même est CIBLE** : elle n'existe que sur son banc. Ce qui
> est vérifié, c'est ce qu'elle remplace, ce qui la déclenchera, et ce qui
> part au serveur autour d'elle.

**Ce qu'elle remplace** — il y a aujourd'hui **DEUX** toasters, pas un :
`PillGain` (`Woop/Views/RestartSheet.swift:536`, montée
`ExerciseDetailView.swift:1016`, pendant la séance) et `PiecesNotif`
(`Woop/Views/PlayerSeance.swift:260`, montée `WoopApp.swift:1093`, sur la
home à la clôture et après un claim du chemin).

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

**CIBLE — une famille, quatre robes, un template.** Les trois robes
« pièces » se succèdent en variant (verdict du 29-08 : *« on a 4 variants
donc tu peux les faire varier »*), la robe « booster » s'affiche quand le gain
est un sachet. Aucune robe n'est clouée à un moment.

**Pourquoi elle remplace les deux toasters** : ils disent la même chose avec
deux looks (verre `.regular` teinté pour l'un, `.clear` pour l'autre), deux
langues (« this session » / « pièces lune ») et deux durées (2,0 s / 3,0 s).
CIBLE : un gain se dit d'une seule façon.

---

## 2 · Affiche

### 2.1 Aujourd'hui — les deux toasters

| toaster | ce qu'on voit | où | durée |
|---|---|---|---|
| `PillGain` | `piece-or-mini` · `+20` · `· 140 this session` ; verre `.regular` teinté noir 0,34, capsule de 44 pt | haut de la fiche exo, padding 8, `zIndex 30` | **2,0 s** puis 0,30 s de sortie |
| `PiecesNotif` | disque de braise · `+240` (le compte roule en trois paliers) · `pièces lune` ; verre `.clear` sous une capsule noire 0,35 | haut de la racine (`WoopApp`), padding 8, `zIndex 9` | **3,0 s** (clôture : +1,6 s → +4,6 s) · **3,2 s** (chemin) |

Les deux sont sourds au doigt (`allowsHitTesting(false)`). ⚠️ Le vol de
pièces qui devait accompagner la capsule (`VolDePieces`, 2,6 s) vit dans
`HomeAuroraView` — une vue **en archive** : l'onglet Accueil monte
`HomeNuitPage` (`WoopApp.swift:933`), qui n'écoute pas `notifPieces`.
Aujourd'hui la capsule descend seule.

### 2.2 CIBLE — la dalle

**La dalle** : 138 pt de haut, coins 28, **noire et opaque** (pas de verre —
elle se juge sur la nuit vraie), liseré blanc 0,16 → 0,03, ombre. Le gabarit
est celui de la card OPAL de référence (capture du 28-08, hors dépôt). Entrée
par `offset` + `opacity`, jamais un redimensionnement (loi du verre aux bounds
vivants).

| # | Robe | Ce qu'on voit | Ce qu'elle porte |
|---|---|---|---|
| 1 | **LA JAUGE** | `+20 COINS EARNED` (le chiffre monte de 0), `VAULT PROGRESS`, une barre de 3 pt à dégradé blanc avec de la poudre de diamant **dedans** (clippée), une pièce d'or qui tourne (9 s/tour) et mord le bord droit de 16 pt | le gain, la fraction de jauge |
| 2 | **LE GROS TEXTE** | `YOU WIN` à 104 pt, **rogné** (le U et WIN coupés — prérequis), très fondu, la vidéo matrice dans le glyphe, un projecteur qui descend du haut, les lettres qui naissent une à une, une pièce (54 pt) au centre, `+20 COINS` | le gain |
| 3 | **LA CHÂSSE** | Nosfy en vidéo (boucle 1,500 s, 78 Ko, `Woop/Media/nosfy-notif-loop.mp4`) au centre, poudre de diamant de ses ailes, `+20` avec un halo de lumière qui respire, `COINS EARNED`, un galet de verre sur l'aile droite, une lueur dans le coin bas droit | le gain |
| 4 | **LE BOOSTER** | la jauge, avec le sachet **orange** détouré (`booster-orange`) qui lévite à la place de la pièce ; `+1 BOOSTER EARNED` ; seconde ligne **?** — pas encore codée (V9 §A) | le sachet |

**Ce que la jauge montre aujourd'hui** : `fraction = 0,62`, **une constante de
démonstration** (`NotifJauge`). Elle ne lit aucun serveur.

**Un gain qui n'est pas 20** — **?** non dessiné : un claim du chemin donne
+100 à +200 (la jauge déborderait les 100 pièces d'un sachet : pleine puis
repart ? deux sachets ?), le Welcome Back +10. Le banc ne connaît que `+20`.

**Position** : **?** — en haut, sous la barre d'état, comme les deux
d'aujourd'hui, est l'hypothèse ; le banc les empile au centre et la position
finale n'a pas été jugée.

**Durée** : **?** — les films du banc mettent ~1,3 s à se poser (délai 0,35 s
+ ressort 0,62 s + la montée de la barre). 3,2 s partout **me semble** le
minimum pour lire le chiffre et voir la barre monter ; rien n'est mesuré.

**Langue** : **?** — le template est en anglais, `PiecesNotif` parle français,
`PillGain` anglais ; à trancher une fois.

---

## 3 · Actions

| # | Action | Geste | Appel backend |
|---|---|---|---|
| A1 | **Aucune** — la dalle est traversée | un tap la traverse et atteint l'écran dessous (`allowsHitTesting(false)` chez les deux toasters actuels ; CIBLE : la dalle pareil) | **aucun** — l'appel part de l'événement qui la fait naître, jamais d'elle |

**Ce qui la déclenche**, moment par moment — et ce qui part au serveur à cet
instant :

| Moment | Aujourd'hui | Appel backend aujourd'hui | CIBLE |
|---|---|---|---|
| **une série finie** | `DecideurSerie.pour` (`RestartSheet.swift:608`) rend `.pill` hors des rangs 3/5/10 → `PillGain` 2,0 s → la question « Recommencer ? » **0,22 s** après sa sortie (`:2203`) | **aucun** — `settleSeries` n'écrit que le **brouillon en mémoire** de la fiche (`@State sets: [DraftSet]`, `:114`) ; rien n'est persisté en SwiftData à la fin d'une série (la seule écriture est `save()`, au geste de l'utilisateur) | la dalle lit une **outbox locale au grain de la série** (plan backend §1). ⚠️ L'`OutboxGains` réelle n'a **pas** ce grain (ses trois cas : fin de séance, retour quotidien, nœud du chemin) — ce CIBLE suppose de l'étendre |
| **la clôture** (« Terminer ») | `terminerSeance()` (`WoopApp.swift:431`) : `gain = séries × 20`, ferme la pause, sauve, **bascule toujours sur la home** ; puis, seulement si gain > 0 : le trophée, `PiecesNotif` à +1,6 s, la pop-up booster à +5,2 s | `SupabaseSync.push([snapshot])` **puis** `cloturer_seance(p_workout, p_series)` via l'outbox, en tâche détachée → `{pieces, pieces_creditees, booster_id, booster_neuf, solde}`. ⚠️ **La réponse n'est lue par aucun écran** (le seul consommateur la `print`) : la notif affiche le calcul local | la dalle affiche le local ; **?** la jauge lit `solde`/`reste` quand la réponse arrive |
| **un claim du chemin** | `RewardCheminEtat.fermer()` (`RewardChemin.swift:205`) : `PiecesNotif(montant)` à +0,3 s, **seulement si le tirage est en pièces** ; le tirage est local (`TirageRecompense.tirer`) | **aucun** — `reclamer_noeud_chemin` existe (`SacreServeur.reclamerNoeudChemin`, case `.noeudChemin` de l'outbox) mais **rien ne le poste** : `RewardChemin.swift` n'appelle ni `SacreServeur` ni `OutboxGains` | le claim poste l'outbox ; la dalle annonce ; si le tirage donne des sachets → robe 4 |
| **Welcome Back** | **aucune logique de production** ne choisit `.welcome` (le décideur n'émet que galet/halo/fire). ⚠️ Mais le chip « … » du header de la fiche exo (`ExerciseDetailView.swift:1846`, *« prêté à la card reward le temps de l'atelier »*) est monté **sans drapeau** (`:713`) et fait tourner les six robes : **deux taps ouvrent Welcome Back dans un build de production** | ✅ **branché le 29-08** : `.retourQuotidien` est posté au retour au premier plan (`SacreServeur.reglerRetourQuotidien`, jour compté en UTC comme le serveur). ⚠️ Le `Claim` de la pop-up, lui, appelle toujours `fermer` sans réseau | **la pop-up vit sur la HOME, une fois par jour calendaire, en deux robes** (`WelcomeRobe.video` / `.texte` — verdict 29-08) ; les deux ont le même `Claim` → outbox → la dalle « +10 » **si `credite`** (§4 duodecies du plan backend) |
| **un booster gagné** | la pop-up `SacreEtat.proposer()` à +5,2 s ; « Plus tard » ferme, le sachet reste dans `boostersEnAttente` (**maquette : 1 en mémoire**) | dans `cloturer_seance` (`booster_neuf`) — le même appel que les pièces | **robe 4** — **?** son rapport à la pop-up (§4) |

⚠️ **La règle qui commande tout** (plan backend §1) : **l'UI affiche le gain
tout de suite, le ledger rattrape.** C'est déjà le comportement de
`terminerSeance` : l'appel vit dans une tâche qui *« ne propage jamais son
échec »*. Une dalle qui attendrait la réponse arriverait, en cas de réseau
lent, après la série suivante — c'est le raisonnement, pas une latence
mesurée.

---

## 4 · Sorties

**La dalle ne mène nulle part** : elle s'efface et l'écran dessous continue
là où il était. Ce qui compte, c'est ce qui vient **derrière** elle.

| Depuis | Vers |
|---|---|
| une série finie (fiche exo) | la question **« Recommencer ? »** (`poserLaQuestion`) — **0,22 s** après la sortie de la pill (`:2203`) ; *« un seul chemin vers le panneau »* : c'est la fermeture de ce qu'on montre qui pose la question (une pop-up fermée la pose à 0,26 s, `:1110`) |
| la clôture (home) | la **pop-up booster** à +5,2 s — ⚠️ une minuterie fixe depuis « Terminer », **pas** chaînée à la fin de la notif. Si la dalle se pose à +1,6 s comme la capsule d'aujourd'hui (**?** CIBLE), elle a 3,6 s avant que la pop-up monte dessus |
| un claim du chemin | retour au **chemin**. CIBLE (`duolingo-chemin.md` §4) : *« un toaster des gains puis redirection immédiate vers le COFFRE »* — n'existe pas |
| Welcome Back | la pop-up vit sur la **home** (CIBLE, une fois par jour, deux robes) et s'y referme ; la dalle « +10 » se pose sur la home ; rien derrière. Si le serveur répond « déjà pris » (`credite = false`) : **pas de dalle** |
| un booster gagné (robe 4) | **?** — la pop-up booster annonce déjà le sachet à +5,2 s ; deux annonces du même sachet seraient redondantes. Trois lectures : la robe 4 **remplace** la pop-up ; elle vient **après « Plus tard »** (la première formulation du 28-08) ; elle ne sert qu'aux sachets **du chemin**. Non tranché |
| un tap sur la dalle | **rien** — elle est traversée |

**Qui la monte** — **?** CIBLE : un seul hôte. Aujourd'hui `PillGain` vit
dans la fiche exo et `PiecesNotif` à la racine ; la racine (`WoopApp`) est le
seul endroit d'où la dalle peut se poser sur n'importe quel écran (home, fiche,
chemin).

---

## 5 · États

| État | Aujourd'hui | CIBLE |
|---|---|---|
| **chargement** | **n'existe pas, et c'est la loi** : le montant est **local** (`séries × 20`, ou le tirage du chemin), jamais attendu du réseau | inchangé pour le chiffre. La **jauge** est le seul élément qui dépend du serveur (`reste` de `etat_coffre()`), et la dalle se pose **avant** toute réponse : **?** elle partirait du **dernier `reste` connu** (cache du dernier `etat_coffre()`) et monterait de `reste / prix` à `(reste + gain) / prix` ; la réponse, quand elle arrive, ne corrige que le cache. Tant que rien n'est branché : `0,62`, constante — à écrire là où on lit le code |
| **vide** (gain = 0) | **pas de dalle** — `terminerSeance` ne pose ni notif ni pop-up si `gain == 0` (mais bascule quand même sur la home), `reglerFinDeSeance` refuse `series == 0`, et un tirage du chemin en sachets ne pose pas la capsule | inchangé ; un sachet gagné pose la robe 4 |
| **erreur** | **rien à dire, par construction** : l'appel est en fond, ne propage pas, et l'outbox rejoue au retour au premier plan (`OutboxGains.vider()` sur `.active`). ⚠️ Un refus **définitif** (4xx hors 401/408/429) est **jeté et crié** dans la console — le gain annoncé n'a alors jamais été crédité | **?** — faut-il une correction visible quand un gain annoncé est refusé pour de bon ? Le §1 du plan backend dit « le ledger rattrape », pas « le ledger contredit ». Non tranché |
| **hors ligne** | identique au nominal — la dalle est locale ; l'écriture attend dans l'outbox (bornée à 200 entrées, `UserDefaults`) | inchangé |
| **deux gains qui se suivent** | ⚠️ `depart.notifPieces` est **un seul `Int?`** : un second gain **écrase** le premier (clôture puis claim rapide, par exemple) | **?** — une file (l'une après l'autre) ou un cumul (`+260`) ; non tranché |

---

## 6 · Le backend et ses règles

> Ce que le serveur doit **décider** et **renvoyer**. Le détail des tables vit
> dans `tools/coffre-v2/BACKEND-COFFRE.md` et `tools/rewards/PLAN-REWARDS-BACKEND.md`.
> CIBLE : la règle des notifications s'y écrira en **§4 quaterdecies** (le
> §4 undecies annoncé au V8 est déjà pris par le wallet ; le plan s'arrête
> aujourd'hui au terdecies).

### 6.1 Les règles

| Règle | Valeur | Statut |
|---|---|---|
| toute annonce d'un gain passe par le template — plus de pill ni de capsule ad hoc | une famille, quatre robes | **CIBLE** (verdict 28-08) — les deux toasters ad hoc sont toujours là |
| la notification est **locale et immédiate** ; le règlement est **asynchrone et idempotent** | — | **vérifié** pour la clôture (`terminerSeance` + outbox) ; CIBLE pour la série, le chemin, le Welcome Back |
| elle intervient à chaque gain de pièces : la séance en cours, sa clôture, les rewards (le chemin, le Welcome Back) | — | **CIBLE** (verdict 28-08) |
| les robes « pièces » varient ; la robe « booster » quand le gain est un sachet | — | **CIBLE** (verdict 29-08) ; **?** le mode de variation (§6.4) |
| une série rapporte | **20 pièces** | vérifié : `gainParSerie = 20` (client) et `pieces_par_serie: 20` (serveur) |

### 6.2 Ce que le serveur renvoie déjà, et que la dalle pourra lire

| appel | ce qu'il rend | ce que la dalle en ferait |
|---|---|---|
| `cloturer_seance(p_workout, p_series)` | `pieces · pieces_creditees · booster_id · booster_neuf · solde` | rien pour le chiffre (déjà affiché) ; `booster_neuf` dit si la robe 4 a lieu d'être |
| `etat_coffre()` | `solde_or · solde_argent · boosters_or · reste · prix_booster · pieces_par_serie` | **`reste / prix_booster`** = la jauge, la seule valeur qu'elle ne peut pas calculer (`reste` est borné 0-99 côté serveur) |
| `claim_retour_quotidien()` | `credite · montant · solde` | la dalle « +10 » **seulement si `credite`** — elle *« s'appelle sans savoir »* |
| `reclamer_noeud_chemin(…)` | `deja_reclame` | rien — le montant vient du tirage, déjà connu |

⚠️ **Le montant vient toujours du client, jamais de la réponse** : la
constante Swift (`gainParSerie = 20`) et le `pieces_par_serie` du serveur (20)
disent la même chose aujourd'hui — **?** le jour où le prix change en base, la
dalle annoncera l'ancien nombre jusqu'au build suivant. À terme la constante se
lit dans `reward_rules` (étape 2 du branchement, `coffre-rewards.md` §6.6).

### 6.3 Ce que le serveur garantit, et qui rend l'annonce immédiate possible

- **L'idempotence est garantie côté serveur** — un gain par séance, un sachet
  par séance, un versement par jour, un nœud par chemin : rejouer l'outbox ne
  crédite jamais deux fois. *« On ne met jamais dans cette file une opération
  dont le serveur ne sait pas dire "déjà fait" »* (`OutboxGains`). Le
  mécanisme est décrit dans `BACKEND-COFFRE.md`.
- **Le solde est dérivé**, jamais stocké — donc la jauge ne peut venir que de
  lui.
- **Le tirage du chemin est encore au client** (`TirageRecompense.tirer`) et la
  pitié aussi — falsifiables. CIBLE : le claim devient l'appel, et la dalle
  annonce ce que le serveur a tiré.

### 6.5 L'état du serveur — sondé en HTTP le 29-08 (clé anon, sans session)

Le projet Woop (`ytnnyjkramgiqyxdrkcu`), chaque fonction appelée ; un `400
not-null user_id` est la réponse **attendue** sans session (la fonction a
tourné jusqu'à l'insertion, `auth.uid()` est nul) — c'est la preuve qu'elle
existe et qu'elle calcule juste :

| fonction | réponse | ce qu'elle prouve |
|---|---|---|
| `etat_coffre()` | **200** `{reste 0, solde_or 0, boosters_or 0, prix_booster 100, solde_argent 0, pieces_par_serie 20}` | les six clés de la jauge, les prix lus en base |
| `solde_or()` · `solde_argent()` | 200 `0` | — |
| `claim_retour_quotidien()` | 400 not-null, ligne `(…, 10, retour_quotidien, yellow, …, 2026-08-29)` | montant **10** lu dans `reward_rules`, jour rempli |
| `cloturer_seance(uuid, 3)` | 400 not-null, ligne `(…, 60, serie_faite, …)` | **3 × 20 = 60**, le taux vient du serveur |
| `reclamer_noeud_chemin(3, 150, yellow, [])` | 400 not-null, ligne `(…, 150, chemin, yellow, …, 3, …)` | la raison `chemin` et le nœud passent |
| `historique_gains(5)` | 200 `[]` | — |
| `claim_booster()` | 200 `{ouvert false, raison solde_insuffisant, prix 100, solde 0}` | le refus métier en 200, lisible |
| `claim_booster_legendaire()` | **500** `P0002 « pièces d'argent insuffisantes »` | ⚠️ l'incohérence déjà notée dans `coffre-rewards.md` §6.2 est **toujours là** : un refus métier en exception |
| `reward_rules` (select anon) | 200 `[]` | la RLS ne l'ouvre qu'aux `authenticated` — normal ; l'app la lira avec sa session |

**Verdict** : côté Supabase, **tout ce que la dalle a besoin de lire ou de
déclencher existe et répond** — rien à migrer pour les notifications. Ce qui
manque est **dans l'app** (§3 : trois cas d'outbox jamais postés, la réponse
de clôture jamais lue, `etat_coffre()` jamais appelé).

Les trois migrations du 28-08 (`booster_noir`, `wallet_coffre`,
`gains_coffre`), `SacreServeur.swift` et `OutboxGains.swift` sont **commités**
(`1b73879`, session coffre) : le dépôt porte le schéma de sa prod.

`supabase migration list --linked` n'a pas pu comparer appliqué/local depuis
cette session (CLI non connectée : `401 Unauthorized`) — la preuve ci-dessus
est HTTP, pas la table des migrations.

### 6.4 Ce que le backend n'a PAS à décider — **?** (recommandations, V9 §B2)

- **La robe.** Elle s'affiche avant toute réponse ; la choisir côté serveur
  reviendrait à l'attendre. Recommandé : une rotation **déterministe**
  (`hash(session_uuid, serie_index) % 3`, rejouable au banc — la loi du
  `DecideurSerie`, *« une page qui change d'avis à chaque relance ne se juge
  pas »*). Réserve : le moteur de décision (§2 du plan) pourra **suggérer**
  une robe pour un gain exceptionnel, honorée si elle est là.
- **La durée, la position, la langue** — du design, **à trancher** sur
  capture (§2).

---

## 7 · Bancs

| Argument | Effet |
|---|---|
| `-notifLab` | le banc : les robes empilées sur du noir vrai, un tap rejoue les entrées |
| `-notifSeule 1\|2` | une seule robe (la jauge, ou le gros texte) — **le cas vrai de l'app** |
| `-notifSeule 3` | ⚠️ **n'isole PAS la châsse** : `NotifLab.swift:51` teste `seule != 2` au lieu de `seule != 2 && seule != 3`, la jauge reste montée avec elle (deux dalles, sonde étiquetée `notif-seule-3`). **Bug à corriger** (V9-0) |
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

---

## 8 · À vérifier au téléphone

Rien de ce qui suit n'est jugeable au simulateur, et **rien n'a été validé** :
la cadence réelle des robes (et de la vidéo Nosfy sur l'appareil), la lecture
du chiffre en ~3 s dans une vraie séance, le galet de verre sur l'aile (un
`.clear` sans nourriture rend un disque gris), le fondu de la pièce une fois
codé, et le chevauchement avec la pop-up booster à +5,2 s.
