# ANALYSE — LE WELCOME BACK PASSE À « CHAQUE CONNEXION, UNE FOIS PAR JOUR »

**30-08 (matin).** Son verdict : « le welcome back, modifie dans le backend : c'est à
**chaque connexion**, pas tous les 4 jours, et **une fois par jour** ! Et il y a
**deux variants de cards** + **notification avec pièce**. »

**30-08 (soir) — TRANCHÉ, et ça change la moitié de cette fiche.** Ses mots sont
dans [`tools/annonces/PLAN-COFFRE-ANNONCES.md`](../annonces/PLAN-COFFRE-ANNONCES.md)
§0 : **bouton Claim** dans la pop-up ; les +10 partent **au tap** (plus tout seuls
au retour au premier plan) ; **chaque jour à minuit chez elle** (`Europe/Paris`,
une clé serveur — pas UTC, jamais le fuseau du téléphone) ; puis une **dalle
« +10 » dans l'app**, sur la home — **pas une notification iPhone**. La porte de
production = **la home, au premier plan, si `etat_coffre().retour_disponible`**
(clé nouvelle, J1). Le détail : plan §2.3 (ce que le code fait), §4 M1 (le
serveur), §5.3 (l'app), §6 (J1 → J2).

> Ce qui porte `fichier:ligne` est vérifié dans le code — **relu le 30-08 au
> soir** (les numéros de `WoopApp.swift` bougent, une autre session l'édite) ;
> ce qui porte une valeur de `reward_rules` est lu en base. **Rien de la
> décision du soir n'est codé** : ce que fait le code aujourd'hui est le §1,
> ce qui est décidé est le §3. Ne pas lire l'un pour l'autre.

---

## 1 · L'état exact du code (relu le 30-08 au soir — c'est ce qui TOURNE)

Il faut séparer deux choses que le mot « welcome back » désigne en même temps :
**l'argent** et **la card**. Elles n'ont pas du tout le même état.

### L'argent — il part TOUT SEUL, et c'est ce qu'elle a défait le soir

`claim_retour_quotidien()` (`supabase/migrations/20260828190000_gains_coffre.sql:135-162`)
verse `pieces_retour_quotidien` = **10 pièces**, et sa garde est un
`unique_violation` attrapé sur l'index partiel
`coin_ledger_retour_jour_unique (user_id, jour) where raison = 'retour_quotidien'`
(:131-133). Le jour est écrit par la fonction, **en UTC** :
`(now() at time zone 'UTC')::date` (:149-151) — son propre commentaire (:146-148)
dit « c'est LA ligne à changer le jour où on passe au fuseau du profil ».

Côté app, la chaîne complète, sans qu'on tape rien :

| # | où | quoi |
|---|---|---|
| 1 | `Woop/WoopApp.swift:83-99` | à chaque `scenePhase == .active` : `OutboxGains.semer()` (:86), puis **`SacreServeur.reglerRetourQuotidien()` (:91)**, puis `vider()` (:92), puis `EconomieWoop.rafraichir()` (:97) |
| 2 | `Woop/Services/SacreServeur.swift:282-291` | un marqueur `UserDefaults` du **jour UTC** (:283-289, clé `woop.retour.dernierJourUTC`) — « par politesse », l'idempotence est l'index (:270-274) — puis `OutboxGains.shared.poster(.retourQuotidien)` (:290) |
| 3 | `Woop/Services/OutboxGains.swift:206-211` | le cas `.retourQuotidien` (:47) appelle `SacreServeur.claimRetourQuotidien` (`SacreServeur.swift:169-175`), `print`, puis `EconomieWoop.shared.appliquer(r)` |

Donc **une fois par jour calendaire UTC, quoi qu'il arrive**, un second appel
rend `credite: false` (ce n'est pas une erreur), et **le solde monte sans
qu'aucun écran ne le dise** — la réponse finit dans un `print`.

⚠️ **PÉRIMÉ depuis le 30-08 au soir** : cette fiche disait ici « il n'y a donc
rien à changer sur l'argent ». Il y a **trois choses** à changer, toutes
tranchées : le **déclencheur** (au tap du Claim, pas au premier plan), le
**jour** (minuit Paris, pas UTC), et une **lecture sans paiement**
(`retour_disponible`) pour que la porte sache si la card a le droit de se
montrer. Le paragraphe est gardé parce qu'il décrit ce qui **tourne encore** —
c'est ce que le J2 défait (§3).

### La card — c'est ELLE qui était bridée à 4 jours

Trois règles, posées le 29-08 dans `20260829120000_annonces.sql:134-136` :

| clé | valeur du 29-08 | ce qu'elle bridait |
|---|---|---|
| `welcome_absence_jours` | **4** | il fallait 4 jours d'absence pour que la card se montre |
| `welcome_cooldown_jours` | **14** | deux semaines de pause entre deux cards |
| `welcome_max_mois` | **2** | deux cards par mois au maximum |

⚠️ **ET PERSONNE NE LES LIT** (toujours vrai le 30-08 au soir — grep sur tout
le Swift : aucune des trois clés n'est consommée). Elles sont 🔵 « serveur
seul » dans le site, et c'est exact — des règles écrites d'avance pour une
porte qui n'existe pas. **Changer leurs valeurs ne casse donc rien** (§2).

### Les deux variants de card — ils existent, et leur « Claim » ne paie rien

`Woop/Views/RewardLab.swift:83-84` : la robe `.welcome` a **deux** variantes
montées au banc — `welcome` (fond **vidéo**) et `welcomeTexte` (robe **texte**).
Ateliers : `-welcomeTexte` (`Woop/Views/ExerciseDetailView.swift:835-842`) et
`-welcomeLab` (:843-850).

**Son bouton « Claim » ne paie rien** : `BoutonClaim(montant: count, action: fermer)`
(`Woop/Views/RewardCard.swift:873-874`, la capsule :1742) — `fermer()` (:151)
descend la card, c'est tout ; « Later » (:880-881) fait exactement la même
chose. Le montant affiché est la **constante Swift** `piecesRetourQuotidien = 10`
(`ExerciseDetailView.swift:2270`, lue :1097-1098), qui double la clé
`pieces_retour_quotidien` de la base — son propre commentaire (:2262-2269) la
déclare provisoire.

**Aucune porte de production** : la card ne s'ouvre que par ces deux drapeaux
d'atelier. Rien, dans le flow, ne décide de la montrer.

### La notification à la pièce — elle existe aussi

`PiecesNotif` (`Woop/Views/PlayerSeance.swift:260`) est la capsule qui descend
avec le compte des pièces. Elle sert la fin de séance (`WoopApp.swift:543-556` :
posée +0,3 s après la fermeture de la story, retirée à +3,3 s) et la card à
gratter ; son hôte est `WoopApp.swift:1238-1239`, son **unique créneau**
`DepartSeance.swift:43` (`notifPieces: Int?` — une seconde écriture écrase la
première). Rien n'est branché sur le versement du retour.

⚠️ **Tranché le soir, autrement que la fiche le prévoyait** : ce ne sera pas
« brancher `PiecesNotif` sur `credite: true` » mais une **dalle « +10 »
poussée AU TAP** du Claim dans la file d'annonces de la home (plan §5.1.1,
§5.3.10) — **pas une notification iPhone**. Voir §3.

---

## 2 · Ce qui a changé le 30-08 au matin — les trois valeurs (déployé)

**Uniquement les trois valeurs**, dans `reward_rules` — pas une ligne de Swift,
pas une fonction, pas un index. Migration
`supabase/migrations/20260830090000_welcome_chaque_connexion.sql:37-44`
(commit 6557a90), en `do update` parce que les clés existaient :

| clé | avant | après | lecture |
|---|---|---|---|
| `welcome_absence_jours` | 4 | **0** | aucune absence requise : **à chaque connexion** |
| `welcome_cooldown_jours` | 14 | **0** | aucune pause entre deux |
| `welcome_max_mois` | 2 | **31** | au plus un par jour, donc plus de plafond mensuel réel |

⚠️ **Pourquoi 31 et pas « illimité »** : la clé est un nombre, et la porte qui la
lira un jour doit pouvoir écrire `count < welcome_max_mois` sans cas
particulier. 31 est le plus grand nombre de jours d'un mois : c'est « un par
jour » exprimé dans l'unité de la clé, pas une désactivation déguisée.

⚠️ **Ce qui GARANTIT le « une fois par jour » n'est pas ces clés — c'est
l'index.** Les trois valeurs disent quand la CARD a le droit de se montrer ;
l'argent, lui, est tenu par `coin_ledger_retour_jour_unique`. Même si la porte
se trompait et proposait la card trois fois, le versement ne partirait qu'une
fois. C'est la loi de la maison : l'idempotence est un index, jamais un
compteur.

⚠️ **Depuis le soir, la porte tranchée ne lit pas ces clés non plus** : elle lit
`etat_coffre().retour_disponible` (= pas de ligne `retour_quotidien` à
`jour_courant()`, plan §4 M1.7), c'est-à-dire **l'index lui-même, relu sans
payer**. Les trois clés restent en base, cohérentes avec la décision
(0 / 0 / 31 = « un par jour », ce que l'index garantit déjà) et lues par
personne. **Les garder comme témoin ou les retirer n'est pas tranché** — à
poser au J1, avec la migration M1. Le site les tient 🔵 (`b-rg-welcome`,
`b-rg-welcome-cooldown-jours`, `b-rg-welcome-max-mois`).

---

## 3 · Ce qui est TRANCHÉ le 30-08 au soir, et ce qui reste à coder

Le matin, cette fiche laissait trois questions ouvertes (« ce que ça n'ouvre
PAS »). Le soir les a fermées — **sauf une** :

| question du matin | réponse du soir | où c'est écrit |
|---|---|---|
| 1. **la porte** : qui décide de montrer la card, et où | **la home, au premier plan** : si `etat_coffre().retour_disponible` (clé nouvelle, lue **sans payer**) → la card `.welcome`. « Later » ferme ; la card **revient** au prochain premier plan du même jour tant que le Claim n'a pas été tapé | plan §3 (ligne « 1er lancement après minuit (Paris) ») · §4 M1.7 · §5.3.10 |
| 2. **? lequel des deux variants** — vidéo ou texte | **toujours pas tranché** : le plan écrit « `.welcome` (2 robes) » sans choisir | plan §3 |
| 3. brancher `PiecesNotif` sur le `credite: true` | **non, autrement** : au **tap** du Claim, une dalle « +10 » (robe pièces) entre dans la **file d'annonces** de la home. Le montant est local, le journal rattrape (Q8) ; si le serveur répond « déjà pris » — autre appareil — **rien de plus** ne s'affiche. Pas de notification iPhone | plan §1 Q8 · §3 (« après le Claim ») · §5.1.1 · §5.3.10 |

Et ce que le matin n'avait pas posé, tranché aussi :

- **Le Claim paie.** Il poste `.retourQuotidien` (outbox + index = l'idempotence,
  inchangée) ; **le tap est le seul déclencheur**. `reglerRetourQuotidien()`
  **sort** du `scenePhase` (`WoopApp.swift:91`) et le marqueur UTC local
  (`SacreServeur.swift:283-289`) disparaît — le serveur sait.
- **Minuit chez elle.** Une clé serveur `fuseau_jour = "Europe/Paris"` dans
  `reward_rules` + une fonction interne `jour_courant()` ;
  `claim_retour_quotidien` écrit `jour = jour_courant()` (la ligne :149-151 que
  son commentaire désigne). **Jamais le fuseau du téléphone** (Q7 : un voyage
  dans le temps serait une ferme à pièces). L'index `(user_id, jour)` ne bouge
  pas. Déménager = une ligne à changer, pas une table de profil.
- **Le montant** vient de la réponse (`montant`), plus de la constante
  `piecesRetourQuotidien = 10` (`ExerciseDetailView.swift:2270`), qui est
  retirée.
- **L'ordre** : **J1** = le serveur (M1 : `fuseau_jour`, `jour_courant()`,
  `claim_retour_quotidien` en jour Paris, `retour_disponible` dans
  `etat_coffre`) ; **J2** = l'app (porte sur la home + Claim → outbox → dalle).
  Porte de sortie du J2, **mesurée** au sim : « Claim → carnet +10 **au tap
  seulement** », capture avant/après (plan §6). Porte de sortie du J1 :
  `claim_retour_quotidien` ×2 → `jour` = date Paris dans le carnet, le second
  `credite:false` ; `etat_coffre().retour_disponible` false après.

⚠️ **Rien de tout ça n'est codé au 30-08 au soir.** Ce qui tourne est le §1 :
l'argent part seul au premier plan, en jour UTC, et le Claim ferme la card. Le
site le dit tel quel : `b-rg-le-versement-lui-part-vraiment` 🟢 avec le litige
« décision du 30-08 : au tap », `b-wb-porte` ⚪ (plan §7, J0). Les pastilles
bougent **après** la sonde du J1 et le tap mesuré du J2, pas avant.

---

## 4 · La documentation part avec le changement

C'est la loi du dépôt (« une modification backend qui ne touche pas le site est
une modification inachevée ») : la carte du serveur et la page des annonces
sont mises à jour **dans le même mouvement** que chaque jalon — le 30-08 matin
avec les trois valeurs, le J1 avec `fuseau_jour` / `jour_courant` /
`retour_disponible` (`serveur.ts`), le J2 avec la porte et le site d'appel
déplacé (`b-wb-porte`, `b-fn-claim-retour-quotidien` dans `briques.ts` /
`serveur.ts`). Le calendrier complet : plan §7.
