# Écran — REWARDS (le coffre)

`Woop/Views/CoffreV2.swift` · hôte `Woop/Views/CoffreFortView.swift`
(`CoffreFortFlow`) · **l'économie, en un seul endroit** :
`Woop/Services/EconomieWoop.swift` (depuis le 29-08 — `CoffreFortPurse.swift`
ne sert plus qu'à calculer la maquette) · réserve de sachets `SacreEtat`
(`Woop/Views/BoosterPopup.swift`, qui délègue ses deux compteurs à
`EconomieWoop` :71-74, :91-94) · client RPC `Woop/Services/SacreServeur.swift` ·
file d'écritures `Woop/Services/OutboxGains.swift`.

> **Convention de ce document.** Ce qui est écrit sans marque est **vérifié
> dans le code** (`fichier:ligne`, relu le 30-08 au soir — les numéros de
> `WoopApp.swift` bougent : une autre session l'édite). Ce qui porte **?** n'est
> pas sûr. Ce qui porte **CIBLE** est décidé mais pas codé. Ce qui porte
> **DÉCIDÉ 30-08** a été tranché par Kathryn le 30-08 dans
> `tools/annonces/PLAN-COFFRE-ANNONCES.md` (§0 ses mots, §1 les dix défauts
> qu'elle a pris : « oui sur tout ») — **rien n'en est codé**, et le jalon qui
> le codera est nommé. Ce qui porte **périmé depuis …** est ce que cette fiche
> affirmait, gardé pour l'histoire, faux aujourd'hui. Les tables ne sont pas
> décrites ici : `tools/coffre-v2/BACKEND-COFFRE.md`.

> ⚠️ **Où on en est, en quatre lignes (30-08).** Le coffre **lit** le serveur
> (`etat_coffre()` à l'ouverture, `historique_gains()` pour la page des gains)
> et le manège **consomme** au serveur — branché, mesuré sur le compte de test.
> Ce qui **ment** encore : la jauge est calculée sur un solde qui ne se
> convertit jamais (sondé : 1 360 pièces → « 60 to go » et pas un sachet de
> plus), le « jour » du versement est UTC, la flamme n'existe pas, le profil
> cache ses objets à 0. Le 30-08 elle a tranché les quatre ; **J1** (serveur)
> et **J2** (app) du plan les codent. Cette fiche dit les deux états.

---

## 1 · Rôle

**Le guichet de l'économie.** C'est le seul écran qui répond à « qu'est-ce que
je possède, et qu'est-ce que ça m'ouvre ». Trois questions, dans cet ordre :

1. **Qu'est-ce que j'ai** — les deux monnaies et les deux réserves de sachets,
   un objet par page.
2. **Ce que ça coûte** — la règle de chaque objet, écrite sous lui.
3. **Où j'en suis** — la jauge vers le prochain sachet, et l'historique de ce
   qui a été gagné.

Ce n'est pas un écran de dépense unique : c'est **la porte du Manège**, qui est
la cérémonie d'ouverture. **DÉCIDÉ 30-08 :** ce n'est plus non plus un écran
d'**achat** — plus rien ne s'y achète (§6.8).

---

## 2 · Affiche

**Une salle, un socle, un objet.** Un mur éclairé barré d'un néon en haut
(0,225 de la hauteur), du noir en dessous, un socle au milieu, et **un seul
objet posé dessus à la fois**.

**Quatre pages qui se feuillettent** horizontalement, dans cet ordre. Le pied
lit `EconomieWoop` et rien d'autre (`CoffreV2.swift:2382-2435`, propriété
calculée `variantes`, « jamais un appel réseau ici ») :

| # | objet | ce que le pied dit **aujourd'hui** (`CoffreV2.swift`) |
|---|---|---|
| 1 | pièce d'or | le solde `or` · « *{pieces_par_serie}* coins for every set you finish. » (:2392 — le taux vient du serveur, c'était la neuvième copie du 20) · pas de bouton |
| 2 | booster orange | les sachets `boosters` · **jauge** `reste` sur `prix` (:2404) · « Won after every session, or bought for *{prix}* coins. » (:2406) · bouton **OUVRIR** si `boosters > 0`, sinon « *N* COINS TO GO » en verre mat, inactif (:2407-2409) |
| 3 | pièce d'argent | le solde `argent` · « A rare drop from the path. Never earned, never bought. » (:2418) · pas de bouton |
| 4 | booster noir | `boostersNoirs` (= argent **+** le noir payé, ouvert, pas scellé — `EconomieWoop.swift:94`) · « One silver coin opens it. A legendary card, guaranteed. » (:2430) · **OUVRIR** ou « LOCKED » mat, inactif (:2431-2432) |

**Périmé depuis 1b73879 (28-08) puis le 29-08 :** « 100 coins open one. » —
la phrase de la page 2 est devenue « …or bought for N coins » quand le prix
a été lu du serveur. **DÉCIDÉ 30-08 — elle disparaît à son tour** (plan §0
« la jauge », §1 Q9) :

- « or bought for *N* coins » n'a plus de sens : **rien ne s'achète**. À 100
  pièces **un sachet apparaît tout seul** (le nombre monte : 1, 2…) et **les
  pièces retombent** — la jauge repart de `reste`, qui ne peut plus dépasser 99.
- le pied n'a plus que **la jauge et OUVRIR** ; « *N* COINS TO GO » comme
  bouton est mort (la jauge le dit déjà). Ce que le pied dit à 0 sachet reste
  à dessiner (§5 « rien à ouvrir »).
- le sachet **forfaitaire** de clôture continue d'arriver **en plus** du
  converti (§6.7, option 1 assumée).

Jalon **J2** du plan ; le serveur d'abord (**J1**, §6.8).

**La loi de la page** : *le pied décrit toujours l'objet posé sur le socle.*
Une règle, quatre pages, aucun cas particulier.

**Ce qui dit qu'il y a autre chose** : les objets voisins **dépassent des deux
bords**, éclairés par leur propre flaque de lumière (or chaud, braise, argent
froid, violet). Plus une barre de quatre crans sous le socle — plein = j'y
suis, allumé = j'y ai quelque chose, éteint = la page existe mais elle est
vide.

**En haut** : le chevron de fermeture, le titre « Rewards », et la pill
d'historique — trois ronds de 44 pt sur la même ligne.

**La page Historique** (par la pill) : un titre, puis une ligne par gain —
l'objet, ce qu'il a rapporté, la date. Servie par le **journal du serveur**
(`historique_gains`, §6.3) ; la reconstruction depuis les séances n'est plus
que le repli sans compte (`CoffreFortView.swift:538-546`).

---

## 3 · Actions

| # | Action | Geste | Appel backend — **aujourd'hui** |
|---|---|---|---|
| A1 | **Changer d'objet** | glisser horizontalement, ou taper un cran | aucun |
| A2 | **Regarder un objet de près** | taper l'objet (il grossit et lévite) | aucun |
| A3 | **Ouvrir un booster** | bouton « OUVRIR » (pages 2 et 4, seulement quand il y a de quoi ouvrir) | **aucun au tap** : le coffre se ferme et le Manège monte 450 ms plus tard (`CoffreV2.swift:2543-2549`). C'est le manège qui consomme **à l'engagement** : orange → `ouvrir_booster` (`EconomieWoop.swift:305`, migration `20260829150000`), noir → `claim_booster_legendaire` (:303 ; elle débite la pièce d'argent et rend le sachet ouvert — 9ef6da1). Mesuré 30-08 : `boosters_or` 47 → 46, rejoué → le même id (`tools/sacre/verif_backend_sachet.py`, 22 ✓) |
| A3' | **Acheter un sachet** | — **inatteignable depuis le coffre** : la branche `acheterBooster()` de `ouvrirManege` (:2551-2559 → `claim_booster`) ne peut jamais courir, le bouton étant inactif à 0 sachet (:2407-2409). Elle vit **au profil** : tirer le géant (`ProfilLune.swift:276`) → « Utiliser *N* pièces pour ouvrir un booster ? » (:1306) → OUVRIR → `ouvrirOuAcheter()` (:1255-1273) → `EconomieWoop.acheterBooster()` (:253-272) → `claim_booster()` | **DÉCIDÉ 30-08 : retiré** — l'app perd les deux sites d'appel, la fonction serveur est **fermée** (`revoke execute from authenticated`, J1). Voir §6.8 |
| A4 | **Voir l'historique** | pill en haut à droite | `historique_gains(60)` — lu à l'ouverture du coffre, dans le même `.task` que `etat_coffre` (`CoffreFortView.swift:589` → `EconomieWoop.rafraichir(avecJournal: true)` :168-185). **Périmé depuis le 29-08 :** « reconstruit en local depuis les séances » — c'est le repli, plus la règle |
| A5 | **Fermer l'historique** | croix, **ou tirer la page vers le bas** | aucun |
| A6 | **Fermer le coffre** | chevron en haut à gauche | aucun |
| A7 | **Tirer la card** ? | un geste vertical existe (`tirage` :1606, `LuneSecrete` :2578) — **?** son statut produit n'est pas tranché | aucun |

**Périmé depuis 1b73879 (28-08) et le 29-08 :** « aucune action ne déclenche
le moindre appel réseau ; les réserves sont un compteur en mémoire initialisé
à 1 ; la dépense est simulée (`dispo = coins − sachets × 100`) ». Aujourd'hui :

- **à l'ouverture**, `.onAppear` pose la maquette **avant la première image**
  (`CoffreFortView.swift:586` — sinon la roulette du solde défile depuis 0),
  puis `.task` relit `etat_coffre()` + le journal (:589) ;
- **la dépense simulée est morte** (`CoffreV2.swift:2370-2377`) : le solde n'a
  qu'une source, il se débite au serveur ou il ne bouge pas ;
- **les réserves lisent `user_boosters`** (`etat_coffre().boosters_or`) dès que
  le serveur a parlé ; la maquette (`maquetteBoosters`, `EconomieWoop.swift:85`)
  monte de un à chaque clôture payante (`WoopApp.swift:524`) — un affichage,
  pas une écriture d'argent.

---

## 4 · Sorties

| Depuis | Vers |
|---|---|
| **OUVRIR** (page 2 ou 4) | le coffre se **ferme d'abord** (`onClose` :2545), puis le **Manège** monte à la racine 450 ms plus tard (:2546-2548) — le Manège vit sous le `fullScreenCover` du coffre, l'ouvrir sans fermer lancerait la cérémonie derrière la page |
| **OUVRIR** → Manège → sachet déchiré | la **carte forgée** (`forge-card`, qui **scelle** le sachet — `card_id`, 9ef6da1), puis retour d'où l'on venait |
| **chevron** | l'écran d'où l'on est venu |
| **pill historique** | l'Historique, **en overlay** — pas une feuille : empiler une `sheet` sur un `fullScreenCover` donne la poignée grise du système au milieu de la nuit |
| **Historique** → croix / drag bas | retour au coffre, page inchangée |

**Qui entre ici** — vérifié, le **?** tombe :

- la **pastille des pièces du profil** (`ProfilLune.swift:751-761`, `showCoffre`
  → `CoffreFortFlow` :295) ;
- le **bouton-pièce de la home** (`HomeNuit.swift:3263-3264` → `ouvrirCoffre()`
  :3364-3368, +0,34 s le temps de la fumée → `fullScreenCover` :2368-2378).

**Périmé :** « les deux pills du profil (or et noir) ». Les deux **pills
booster** du profil (:562-578) n'entrent **pas** dans le coffre : elles
ouvrent le **Manège** directement (`ouvrirManege(robe:)`). Le **chemin**
n'entre pas non plus : la card à gratter puis le Manège (`DuolinguoPage.swift`
ne cite `CoffreFortFlow` que dans un commentaire). Le plan (§1 Q6, défaut
pris) confirme : « Ouvrir » après une séance **va droit au manège**, sans
escale au coffre.

Chaque entrée calcule **sa** maquette (séries faites × 20 depuis SwiftData :
`HomeNuit.swift:2372-2375`, `ProfilLune.swift:124-129`,
`CoffreFortView.swift:538-546`) et la **pousse** à l'arbitre
(`poserMaquette`, `EconomieWoop.swift:131-145`), qui ne la sert que tant que
le serveur n'a jamais répondu (:134). Le site suit ce qu'il reste de double
source sous `b-deux-nombres`.

---

## 5 · États

| État | Aujourd'hui (vérifié) | CIBLE / DÉCIDÉ |
|---|---|---|
| **arrivée** | la cascade (titre, objet, jauge) sur **le dernier état connu** : la maquette est posée avant la première image, `etat_coffre()` part dans `.task` et corrige à l'arrivée (`CoffreFortView.swift:586-589`). Jamais de squelette gris — un nombre périmé, pas un trou | inchangé. **DÉCIDÉ 30-08 :** `etat_coffre()` rendra en plus `flamme`, `flamme_aujourdhui`, `retour_disponible` (J1) — un seul appel au retour au premier plan |
| **vide** | page or à 0, page argent à 0 : le compte s'affiche et **la règle explique** — elle ne console pas. Historique vide : « Rien encore. Une série faite, vingt pièces. » | inchangé |
| **rien à ouvrir** | le verrou se dit par **la matière** (5ᵉ loi d'Opal, `CoffreV2.swift:1290-1300`) : même place, même taille, verre mat — « *N* COINS TO GO » page 2, « LOCKED » page 4 (:2407-2409, :2431-2432). **Périmé :** « le bouton n'existe pas quand le solde est à 0 » | **DÉCIDÉ 30-08 :** page 2, le mat ne peut plus dire « *N* coins to go » comme une promesse d'achat ; ce qu'il dit à 0 sachet est à dessiner (J2) |
| **chargement d'une action** | n'existe pas : OUVRIR ferme le coffre tout de suite, le manège attend la réponse de son côté | « OUVRIR » doit passer en attente et **revenir à son état** si l'appel échoue — jamais un bouton mort |
| **erreur** | `rafraichir()` **ne propage jamais** son échec (`EconomieWoop.swift:166-167`, :181-184) : la page garde le dernier état, `derniereErreur` n'est jamais affichée telle quelle. Un achat refusé ne dit **rien** qu'une haptique `.warning` (`ProfilLune.swift:1272`, `CoffreV2.swift:2557`) — assumé, le panneau affiche déjà « Il te manque *N* pièces » | l'achat disparaît (§6.8) ; il reste à dire l'échec d'**une ouverture** — **?** sous quelle forme |
| **hors ligne** | les soldes affichent le dernier état connu et **le repli ne revient jamais en arrière** (`serveur` reste vrai, :33-37, :111). ⚠️ **Sans compte, l'achat passe** (`possible` faux → `.obtenu`, :254) : un choix, pas un oubli — mais qui disparaît avec l'achat | « OUVRIR » refuse et le dit |
| **conflit deux appareils** | les claims sont **idempotents côté serveur** (index uniques partiels) ; le pire cas est un rafraîchissement | — |
| **la jauge** | `reste = solde_or mod prix_booster` sur le solde **TOTAL** (`20260830160000…sql:455-461`) : sondé 30-08 14:35, `solde_or 1360 → reste 60`, `boosters_or 47` — **treize tranches de 100 qui ne sont des sachets nulle part**. La jauge est honnête sur un solde qui ment | **DÉCIDÉ 30-08 :** la conversion à 100, au serveur (§6.8) — `reste` devient vrai **par construction** (solde < 100), sans changer sa formule |

---

## 6 · Le backend et ses règles

> Ce que le serveur doit **décider** et **renvoyer**. Le détail des tables est
> dans `tools/coffre-v2/BACKEND-COFFRE.md`, les règles d'économie dans
> `tools/rewards/PLAN-REWARDS-BACKEND.md` §4 nonies → terdecies, et **ce qui
> change au 30-08 dans `tools/annonces/PLAN-COFFRE-ANNONCES.md` §4 (M1)**.

### 6.1 Les règles

| Règle | Valeur | Statut |
|---|---|---|
| une série terminée rapporte | **20 pièces d'or** (`pieces_par_serie`) | tranchée le 13-08 · 🟢 lue du serveur |
| un sachet orange « vaut » | **100 pièces d'or** (`prix_booster`) | tranchée · **DÉCIDÉ 30-08 : ce n'est plus un prix d'achat, c'est le seuil de conversion** (§6.8) |
| un booster noir coûte | **1 pièce d'argent** (`prix_booster_legendaire`) | tranchée · 🟢 consommé par `claim_booster_legendaire` (9ef6da1) |
| une connexion rapporte | **10 pièces d'or, une fois par jour calendaire** (`pieces_retour_quotidien`) | tranchée le 28-08 · **DÉCIDÉ 30-08 : « jour » = minuit chez elle (§6.5), et les +10 partent au tap d'un bouton Claim, plus tout seuls** — le reste est le lot « annonces » |
| une séance terminée rapporte | **1 booster orange, forfaitaire, automatique** | tranchée le 28-08 · 🟢 `cloturer_seance` |
| une séance terminée peut faire tomber | **1 pièce d'argent**, p = 1/30, pitié 45 séances, cooldown 10 (`rare_une_chance_sur`, `rare_pity_seances`, `rare_cooldown_seances` — `20260829120000_annonces.sql:126-128`) | 🟢 `roll_rare` privée, tirée au règlement (:342-348) ; **DÉCIDÉ 30-08 : annoncée par une dalle « argent » dans la pile** (lot annonces) |
| un nœud de chemin rapporte | 100-200 pièces **ou** 1-2 sachets ; noir 6 % (`chemin_taux_piece_noire`), double légendaire 1 %, rare 11 % (`20260830160000…sql:46-48`) | **Périmé depuis 9ef6da1 :** « codé au front, pas au serveur ». `tirer_noeud_chemin` tire au serveur, dérive la pitié du journal, rejoué rend le stocké |
| la pièce d'argent | **ne s'achète pas et ne se gagne pas régulièrement** — elle TOMBE | tranchée |
| **100 pièces → 1 sachet, tout seul** | à 100, un sachet apparaît, les pièces **retombent** | **DÉCIDÉ 30-08** (plan §0 « la jauge ») — pas codé, J1 (§6.8) |
| **le jour** | `fuseau_jour = Europe/Paris`, clé serveur | **DÉCIDÉ 30-08** (Q7, défaut) — pas codé, J1 (§6.5) |
| **la flamme 🔥** | jours d'affilée, **dérivés au serveur**, **sans bonus**, affichés | **DÉCIDÉ 30-08** (plan §0) — pas codé, J1 + J2 (§6.10) |
| **le profil** | or, argent, géant, noir, orange : **toujours visibles, même à 0** | **DÉCIDÉ 30-08** (plan §0 + Q10) — pas codé, J2 (§6.9) |

⚠️⚠️ **UN SEUL BOOSTER PAR SESSION COMPLÈTE, QUEL QUE SOIT LE NOMBRE DE
SÉRIES** (précisé par Kathryn le 28-08). Les deux récompenses de fin de séance
ne comptent donc PAS la même chose : les **pièces** sont proportionnelles au
travail (séries × 20), le **booster** est forfaitaire — il paie le fait
d'avoir fini, pas la quantité. Une séance de 3 séries et une de 15 donnent
**un sachet chacune**. **Et depuis le 30-08, en plus** : si les pièces de la
séance font passer le solde au-dessus de 100, un **second** sachet naît de la
conversion (§6.7).

⚠️ **Les prix ne vivent pas dans le code.** L'app les LIT (`reward_rules`,
via `etat_coffre()` → `EconomieWoop.swift:196-197`) ; elle ne les connaît pas.
Changer un prix ne doit jamais demander un build. **Fait le 29-08** : le
profil disait 20 et le coffre 100 pour le même sachet (`EconomieWoop.swift:12-14`).

⚠️ **Le solde est DÉRIVÉ, jamais stocké** — la somme d'un journal ne peut pas
mentir, un solde stocké se désynchronise. C'est pour ça que `booster_progress`
est morte et **ne se réveille pas** pour la conversion (plan §4 « ce qu'on ne
fait pas ») : le nombre de sachets convertis se **compte** dans
`user_boosters`, il ne se stocke pas.

⚠️ **Tout crédit est IDEMPOTENT par construction**, par index unique partiel et
non par compteur applicatif : une série ne paie qu'une fois, une séance ne
donne qu'un sachet, un nœud de chemin ne se réclame qu'une fois, un jour ne
verse qu'une fois. Un compteur local se remet à zéro à la réinstallation ;
un index, non. ⚠️ **Exception, aujourd'hui :** `claim_booster()`
(`20260828190000_gains_coffre.sql:354-381`) n'a **aucun témoin** — deux taps,
deux achats. Elle meurt au J1, le défaut avec elle.

**Fait depuis 9ef6da1 :** « la pitié du chemin doit passer côté serveur » —
elle y est, dérivée du journal, jamais stockée.

### 6.2 ✅ DÉPLOYÉ LE 28-08 — et vérifié fonction par fonction *(histoire ; les migrations suivantes en bas)*

`supabase db push` a posé `20260828190000_gains_coffre.sql` (les deux
précédentes étaient déjà en base). Chaque fonction a ensuite été **appelée en
HTTP** pour vérifier qu'elle répond, et pas seulement que la migration est
enregistrée :

| fonction | vérifiée le 28-08 | et depuis |
|---|---|---|
| `solde_or()` | ✓ 200 | interne, jamais appelée du client |
| `claim_retour_quotidien()` | ✓ (400 sans session : `auth.uid()` est nul, c'est le comportement attendu) | 🟢 appelée à chaque premier plan (`WoopApp.swift:91`) — **DÉCIDÉ 30-08 : au tap d'un Claim, et jour Paris** |
| `cloturer_seance(uuid, int)` | ✓ 200, forme JSON correcte | élargie le 29-08 (`argent`, `reste`, `prix_booster`), 🟢 appelée par l'outbox ; sondée ×2 le 30-08 |
| `reclamer_noeud_chemin(int, int, text, text[])` | ✓ 200, forme JSON correcte | **délègue** à `tirer_noeud_chemin` depuis 9ef6da1, ne croit plus le client |
| `historique_gains(int)` | ✓ 200 | 🟢 lue à l'ouverture du coffre |
| `claim_booster()` | ✓ 200 | 🟢 un site d'appel (le profil) — **DÉCIDÉ 30-08 : retirée de l'app, fermée au J1** |

⚠️ **PIÈGE DE VÉRIFICATION, ET IL M'A EU DEUX FOIS SUR SIX** : appelées avec un
corps vide, `cloturer_seance` et `reclamer_noeud_chemin` rendent **404**. Ce
n'est pas « la fonction n'existe pas » — **PostgREST résout une fonction par le
NOM DE SES ARGUMENTS**, et celles-là ont des paramètres sans valeur par défaut.
Un 404 sur un RPC veut dire « aucune signature ne correspond », pas « aucune
fonction ». Re-testées avec leurs arguments : 200.

**Les preuves, et non plus des suppositions** (Kathryn : *« t'es sûr on est
bien là ? »* — je ne l'étais pas : j'avais vérifié que les FONCTIONS
répondent, jamais que les colonnes, index et contraintes existaient).

**Les colonnes**, demandées une par une à PostgREST, avec une colonne bidon en
témoin (elle rend bien 400) :

| table | colonnes vérifiées |
|---|---|
| `coin_ledger` | `jour` ✓ `noeud_id` ✓ `raison` ✓ `currency` ✓ `workout_id` ✓ `booster_id` ✓ |
| `user_boosters` | `noeud_id` ✓ `robe` ✓ `origine` ✓ `opened_at` ✓ (+ `card_id` depuis 9ef6da1) |
| `reward_rules` | `key` ✓ `value` ✓ |

**Les règles sont peuplées** — `etat_coffre()` rend
`prix_booster: 100`, `pieces_par_serie: 20`.

⚠️⚠️ **ET LE MESSAGE D'ERREUR DE `claim_retour_quotidien()` PROUVE TOUT LE
RESTE.** Appelée sans session, elle échoue — mais sur quoi :

```
null value in column "user_id" … violates not-null constraint
Failing row contains (…, null, 10, retour_quotidien, yellow, null, null,
                      2026-08-28 18:46:04+00, null, 2026-08-28)
```

Cette ligne dit, sans qu'on ait rien à croire sur parole :
1. le montant **10** a bien été lu dans `reward_rules` ;
2. la raison `retour_quotidien` **passe le CHECK** — sinon l'erreur serait une
   violation de contrainte, pas de `not null` ;
3. la colonne **`jour` est remplie** (`2026-08-28`, en dernière position) —
   donc le calcul UTC dans la fonction marche ;
4. la ligne a **dix colonnes**, celles attendues.

Elle n'échoue que parce qu'`auth.uid()` est nul hors session. C'est le
comportement voulu — désormais **mesuré**, plus supposé.

**Périmé depuis 9ef6da1 (30-08 16:13) — l'incohérence des deux langues.**
Cette fiche notait que `claim_booster_legendaire()` levait un **500**
`P0002 « pièces d'argent insuffisantes »` pour une condition métier, là où
`claim_booster()` répondait 200 `{ouvert: false, raison: 'solde_insuffisant'}`,
et demandait à aligner. **Aligné** : la migration `20260830160000_sachet_scelle_et_tirage.sql`
la réécrit (:63-127), et un refus métier rend **200** avec
`{ouvert: false, raison: 'argent_insuffisant', solde_argent, prix}` (:95-100) —
plus jamais un 500, plus jamais une ligne nue. Elle **reprend** aussi un noir
déjà payé, ouvert, non scellé (:73-88) au lieu d'en facturer un second. Sondée
30-08 14:35 sur le compte de test (`tools/sacre/verif_backend_sachet.py`,
22 ✓) : #1 `ouvert:true, reprise:false, prix:1` · #2 même id, `reprise:true,
prix:0` · `noirs_ouverts` 0 → 1. Le client lit les deux dialectes
(`SacreServeur.swift:120-135`) parce que l'app et la base se déploient par
deux actes. La question se ferme d'elle-même au J1 : `claim_booster` n'aura
plus de langue du tout.

**Périmé depuis le 29-08 :** « RIEN DANS L'APP NE LES APPELLE ENCORE ». Les
sites d'appel, relus le 30-08 :

| fonction | qui l'appelle |
|---|---|
| `etat_coffre` | `EconomieWoop.rafraichir` (:174) — à l'ouverture du coffre (`CoffreFortView.swift:589`), au retour au premier plan (`WoopApp.swift:97`), après chaque consommation (`EconomieWoop.swift:308`) |
| `historique_gains` | `rafraichir(avecJournal: true)` (:177), coffre seulement |
| `cloturer_seance` | l'outbox (`OutboxGains.swift:191-205`), posée par `SacreServeur.reglerFinDeSeance` depuis `terminerSeance` (`WoopApp.swift:510-513`, `Task.detached`, jamais attendue) ; la réponse est **appliquée** (`EconomieWoop.swift:207-214`) mais **aucune annonce ne la lit** — la pièce d'argent finit dans un `print` |
| `claim_retour_quotidien` | l'outbox (:206-211), posée par `reglerRetourQuotidien` (`SacreServeur.swift:282-291`) à chaque `scenePhase == .active` (`WoopApp.swift:83-98`) |
| `claim_booster` | `EconomieWoop.acheterBooster` (:257) ← le profil seul (§3 A3') |
| `claim_booster_legendaire` · `ouvrir_booster` | `EconomieWoop.consommerBooster` (:303, :305) ← le manège à l'engagement (`BoosterLab.lancerForge`) |
| `tirer_noeud_chemin` | `RewardChemin.reclamer` (9ef6da1) ; `reclamer_noeud_chemin` reste appelée par l'outbox d'une version antérieure et délègue |

### 6.3 Ce que le serveur renvoie

**`etat_coffre()`** — tout le pied en un appel, pour que le coffre et le profil
ne puissent pas afficher deux vérités (`20260830160000…sql:435-469`) :

```
solde_or · solde_argent · boosters_or · noirs_ouverts · reste (0-99)
prix_booster · pieces_par_serie
```

`boosters_or` compte aussi l'orange ouvert **non scellé** des six dernières
heures (:445-450, la fenêtre de reprise d'`ouvrir_booster`) ; `noirs_ouverts`
le noir payé, ouvert, non scellé, au plus un (:451-454) — sans lui la porte du
manège se fermait sur un sachet payé (9ef6da1). Décodé
`SacreServeur.swift:66-92`.

Sonde du 30-08 14:35 (compte de test, corps lu) :
`{"reste":60,"solde_or":1360,"boosters_or":47,"prix_booster":100,"solde_argent":1,"noirs_ouverts":0,"pieces_par_serie":20}`
— c'est cette réponse qui montre le mensonge de la jauge (§5) : `1360 mod 100
= 60`, honnête, sur un solde que rien ne convertit.

**DÉCIDÉ 30-08 — trois clés de plus (J1, plan §4 M1.7)** :
`retour_disponible` (= pas de `retour_quotidien` à `jour_courant()` — lu sans
payer), `flamme` (jours d'affilée), `flamme_aujourdhui`. Un seul appel au
retour au premier plan pour la porte du Welcome Back et la flamme. La formule
de `reste` **ne change pas** : la conversion la rend vraie par construction.

**`historique_gains(p_limite)`** — le journal, une ligne par ÉVÉNEMENT, la plus
récente d'abord : `quand · genre (coins/booster) · motif · montant · monnaie ·
robe` (`SacreServeur.swift:368-400`). **Périmé depuis le 29-08 :** « la page
reconstruit l'historique depuis les séances ; `GainCoffre.robe` est toujours
`nil` ». Le journal serveur est lu (§3 A4) et une ligne `booster` porte sa
robe (`EconomieWoop.swift:318-324` : `noire` ou `lune`) — le versement
quotidien, les sachets du chemin et celui de fin de séance y apparaissent.
`robe: nil` ne survit que dans la maquette (`CoffreFortView.swift:546`).
**DÉCIDÉ 30-08 :** les sachets **convertis** (`origine = 'conversion'`) y
entreront comme les autres — `historique_gains` lit `user_boosters` sans
filtrer l'origine (`gains_coffre.sql:340-347`), rien à changer ; le libellé
côté app (`EconomieWoop.titre`, :327-…) gagne un cas.

### 6.4 Les écritures

| Quand | Ce que le serveur écrit | Garantie | état |
|---|---|---|---|
| une séance est terminée | **+ séries × 20** pièces, raison `serie_faite`, en **une seule ligne** (`annonces.sql:304-314`) | unique par (user, raison, séance) | 🟢 |
| une séance est terminée | **1 booster** `origine = 'seance'`, **forfaitaire** (:318-330) | unique par (user, séance) ; rejouée rend le **même** `booster_id` (sondé ×2, 30-08) | 🟢 |
| une séance est terminée | **1 pièce d'argent**, peut-être — `roll_rare` (:342-348), isolé dans une sous-transaction : un tirage cassé ne coûte jamais le crédit | unique par séance ; rejouée rend `argent:false` — **DÉCIDÉ 30-08 : rejouée, elle rendra le STOCKÉ** (`rejeu:true`, J1, M1.5), pour qu'une page relue après un kill dise vrai | 🟢 / 🔴 au rejeu |
| première ouverture du jour | +10 pièces, raison `retour_quotidien`, colonne `jour` **UTC** (`gains_coffre.sql:149-151`) | unique par (user, jour) | 🟢 · **DÉCIDÉ : jour Paris** (§6.5) |
| un nœud de chemin est réclamé | le serveur **tire** : pièces **ou** 1-2 boosters `origine = 'chemin'` (`tirer_noeud_chemin`, 9ef6da1) | unique par (user, nœud) ; rejoué rend le stocké | 🟢 |
| **le solde atteint 100** | **−100** raison `conversion_booster` **+ 1 booster `origine = 'conversion'`**, dans la **même transaction**, tant que `solde ≥ prix` | le solde lui-même est le témoin : un rejeu ne crédite rien, donc ne convertit rien | **DÉCIDÉ 30-08 — pas codé (J1)**, §6.8 |
| « Ouvrir » un booster orange | `opened_at` posé **à l'engagement** (`ouvrir_booster`) ; un ouvert non scellé < 6 h est **repris** | idempotent par la reprise | 🟢 (9ef6da1) |
| « Ouvrir » un booster noir | −1 pièce d'argent, 1 booster `origine = 'legendaire'` **né ouvert** (`claim_booster_legendaire`) | au plus un noir non scellé (index) ; refus → 200 + motif | 🟢 (9ef6da1) |
| ~~« Acheter » un booster orange~~ | ~~−100 pièces, 1 booster `origine = 'achat'`~~ (`claim_booster`, `gains_coffre.sql:354-381`) | ~~refuse si le solde est insuffisant~~ — sans témoin d'idempotence | **DÉCIDÉ 30-08 : retirée** (§6.8) |
| la forge scelle | `card_id` sur le sachet, **avant** la collection (`forge-card`) | deux forges = une carte | 🟢 (9ef6da1) |

`conversion_booster` est dans le `check` des raisons **depuis le 28-08**
(`gains_coffre.sql:50`) et **n'a jamais été écrite** ; `conversion` n'est
**pas** dans le `check` des origines (:56-58 : `seance, achat, cadeau,
legendaire, chemin`) — le J1 l'ajoute en recopiant la **dernière** liste
(loi woop-backend : un `check` se réécrit entier).

### 6.5 Le fuseau — **UTC aujourd'hui, Europe/Paris DÉCIDÉ le 30-08, et le changement coûte une ligne**

**Aujourd'hui, deux endroits comptent le jour, tous les deux en UTC** :
`claim_retour_quotidien()` écrit `jour = (now() at time zone 'UTC')::date`
(`gains_coffre.sql:149-151` — le commentaire :146-148 désigne lui-même « LA
ligne à changer »), et le client garde un marqueur `woop.retour.dernierJourUTC`
pour ne poster qu'une fois par jour (`SacreServeur.swift:282-291`). À Paris,
quelqu'un qui ouvre l'app entre minuit et 2 h en été (1 h en hiver) touche
encore le versement de la **veille**.

**Périmé depuis le 30-08 :** « le fuseau du profil serait juste, mais coûte
une colonne et une décision — ? reste ouvert ». **DÉCIDÉ 30-08** (plan §0
« chaque jour à minuit chez elle (pas UTC) », §1 Q7, défaut pris) :

- **une clé serveur `fuseau_jour = "Europe/Paris"`** dans `reward_rules`, et une
  fonction interne `jour_courant()` = `(now() at time zone (clé))::date` ;
- `claim_retour_quotidien()` écrit `jour = jour_courant()` ; l'index
  `(user_id, jour)` **ne bouge pas** ;
- **pas de table de profil**, pas de colonne : si elle déménage, c'est une
  ligne de `reward_rules` — sans build ;
- **le marqueur UTC du client disparaît** avec le Claim au tap (le serveur sait :
  `retour_disponible`, §6.3).

Jalon **J1** (M1.1-2) ; porte de sortie : `claim_retour_quotidien` ×2, `jour`
lu dans le carnet = la date Paris, #2 `credite:false`.

⚠️ **Ce qu'il ne faut surtout pas** — et ça, c'est tranché depuis toujours :
le fuseau envoyé par le client à chaque appel. Il se change dans les réglages
du téléphone — c'est le farm par voyage dans le temps. **Le serveur ne croit
jamais le fuseau du téléphone.**

⚠️ **Le jour est une COLONNE, pas une expression d'index — et Postgres ne
laissait pas le choix.** `(created_at at time zone 'UTC')::date` dans un index
est **refusé** : `timezone(text, timestamptz)` est `STABLE`, pas `IMMUTABLE`
(elle dépend de la base de fuseaux, qui est mise à jour). L'index aurait fait
**échouer la migration À LA POSE**, à moitié appliquée. Le jour est donc écrit
par la fonction au moment de l'insertion — c'est exactement ce qui rend le
passage à Paris **une seule ligne**, pas un index à reconstruire.

### 6.6 L'ordre de branchement — **fait, jusqu'au 5**

1. ✅ **Écrire** sans rien lire (28-08) — le journal se remplit par l'outbox.
2. ✅ **Lire les prix** (`reward_rules`) au lieu des constantes Swift (29-08,
   `EconomieWoop`).
3. ✅ **Lire les soldes** (`etat_coffre`) — le corps de `variantes` ne calcule
   plus rien (`CoffreV2.swift:2382-2435`).
4. ✅ **Basculer l'historique** sur le journal (`CoffreFortView.swift:589`).
5. ✅ **Le chemin** et sa pitié côté serveur (9ef6da1, `tirer_noeud_chemin`).

⚠️ Les étapes 1 et 2 ne changeaient **rien à l'écran** — et un branchement qui
ne se voit pas est un branchement qu'on peut défaire.

**Ce qui vient, dans le même ordre écrire-avant-lire** (plan §6) :
6. **J1** — le serveur dit vrai : conversion (§6.8), jour Paris (§6.5),
   `flamme()` (§6.10), `etat_coffre` + 3 clés, `cloturer_seance` rejouée rend
   le stocké, `claim_booster` fermée.
7. **J2** — l'app le montre : l'or qui retombe et le sachet qui apparaît, l'achat
   retiré, le profil à 0 (§6.9), la flamme affichée.
8. **J3** — la fin de séance (page noire, pile, retour sur le chemin) : lot
   « annonces », `docs/screens/notification.md`.

### 6.7 La question d'économie — **tranchée le 30-08 : option 1, assumée**

Une séance de 5 séries rapporte 100 pièces = un sachet. Si elle donne **en
plus** un sachet automatique, elle en rapporte **deux**, et le prix de 100
pièces ne décide plus grand-chose pour quelqu'un de régulier. Trois sorties
étaient ouvertes : assumer · monter le prix (150-200) · distinguer les robes.

**DÉCIDÉ 30-08 : assumer.** Les deux sachets sont **deux événements** — le
forfaitaire paie le fait d'avoir fini, le converti paie les 100 pièces — et
**les deux s'affichent** (plan §0 « la jauge » : « le sachet forfaitaire de
clôture s'affiche aussi » ; deux dalles empilées dans la pile de fin de
séance, `sachets_convertis` et `booster_neuf`). Les nombres restent
**inchangés** (§0 : 20 / série · +10 / jour · 100 = 1 sachet · 1 argent =
1 noir · nœud 100-200). Le prix vivant dans `reward_rules`, ce choix reste
révisable sans build.

**Périmé depuis le 30-08 :** le commentaire de `20260829120000_annonces.sql:38-48`
(« aucune conversion automatique, et c'est voulu — faire les deux, c'est payer
deux fois le même travail ») décrivait la question ouverte ; elle est fermée
dans l'autre sens. Le J1 le réécrit dans la migration qui pose la conversion.

### 6.8 La jauge et la conversion — **DÉCIDÉ 30-08, pas codé (J1 serveur, J2 app)**

**Ses mots** (plan §0) : « à 100 pièces un sachet apparaît tout seul, le
nombre monte (1, 2…), bouton Ouvrir ; les pièces RETOMBENT (converties) ; le
sachet forfaitaire de clôture s'affiche aussi ».

**Au serveur** (plan §4 M1.3-4) — `convertir_pieces()`, **privée** (revoke
nominatif `anon` / `authenticated` / `public`, comme `roll_rare`), sous
`pg_advisory_xact_lock(hashtext(auth.uid()::text))` :

- tant que `solde_or() ≥ prix_booster` : **une ligne `−prix` raison
  `conversion_booster`** + **un `user_boosters` origine `conversion`**, dans la
  **même transaction** ; rend le nombre converti ;
- appelée **à la fin** de `cloturer_seance`, `claim_retour_quotidien` et
  `tirer_noeud_chemin` (piste pièces) — les trois seules portes par où l'or
  entre ; leurs réponses gagnent `sachets_convertis` et un `solde` **après**
  conversion ;
- **témoin d'idempotence = le solde lui-même** : un rejeu ne crédite rien,
  donc ne convertit rien ;
- **conséquence par construction** : le solde ne dépasse plus jamais 99,
  `reste = solde mod prix` est enfin vrai **sans changer de formule**,
  `boosters_or` compte les convertis **sans changer de requête** — `etat_coffre`
  ne bouge pas ; `booster_progress` reste morte.

**Dans l'app** (plan §5.4) — `EconomieWoop.appliquer(ClotureSeance)` applique
le `solde` retombé et fait entrer `sachets_convertis` dans la pile d'annonces
(robe booster) ; le pied de la page 2 perd « bought for *N* coins » et le
bouton « *N* COINS TO GO » (§2) ; l'or **retombe** à l'écran, le nombre de
sachets **monte**.

**L'achat meurt avec** (plan §1 Q9, défaut pris) : avec la conversion le
solde ne dépasse plus 99, donc `claim_booster()` (prix 100) **ne peut plus
jamais réussir** — la garder, ce serait garder un bouton mort. On **retire**
les deux sites d'appel (`ProfilLune.swift:1255-1273` et le panneau « Utiliser
*N* pièces » :1306-1323 ; la branche morte de `CoffreV2.swift:2551-2559`) et
`EconomieWoop.acheterBooster` (:253-272), et le J1 **ferme** la fonction en
base (`revoke execute on function public.claim_booster() from authenticated`,
porte de sortie : `rpc/claim_booster` → 401/403, témoin `rpc/fonction_inventee`
→ 404). La fonction passe ⚪ « sans appelant, fermée » sur le site — on ne
détruit pas. **« Ouvrir » ouvre un sachet qui existe déjà**, et c'est tout.

**Porte de sortie du J1** (plan §6) : `cloturer_seance` ×2 sur la même
séance — #1 `sachets_convertis ≥ 0` et `solde < 100`, #2 `rejeu:true` avec les
**mêmes** `pieces / argent / booster_id` ; `etat_coffre().reste` < 100 après.
**Porte de sortie du J2** : au sim, 100 pièces → « 1 » qui apparaît, or
retombé, capture avant/après. Tant que ces deux sondes n'ont pas été lues, la
pastille du site ne bouge pas.

### 6.9 Le profil — **DÉCIDÉ 30-08 : cinq objets, toujours visibles, même à 0** (J2)

**Aujourd'hui** (`ProfilLune.swift`) : la pill **noire** n'existe que si
`boostersNoirsEnAttente > 0` (:562-570), la pill **orange** que si
`boostersEnAttente > 0` (:571-578) ; **aucune vue de la pièce d'argent** ; le
**géant** (`TirageBooster`, :276-277) est planté dans le sol comme une porte,
hors de l'inventaire ; la pastille des pièces (:751-761) est la seule toujours
là.

**DÉCIDÉ 30-08** (plan §0 « le profil » ; §1 Q10 pour l'orange, défaut pris) :
**pièce d'or, pièce d'argent, le géant, le booster noir, le booster orange** —
tous **visibles à 0**. Un objet à 0 se dit par la matière (mat, non éclairé),
pas par son absence : l'inventaire a toujours la même forme, c'est le nombre
qui change. Jalon **J2** ; porte de sortie : capture du profil à 0 sur les
cinq.

### 6.10 La flamme 🔥 — **DÉCIDÉ 30-08 : jours d'affilée, comptés au serveur, sans bonus, affichés** (J1 + J2)

**Aujourd'hui : rien, nulle part** (plan §2.5) — ni fonction, ni clé, ni
colonne ; le seul « streak » est hebdomadaire, local, dans `CalendarView` que
personne ne monte ; la flamme des galets est un glyphe. Ce qui permet de la
dériver existe déjà : `workouts.ended_at`, poussé par le client
(`SupabaseSync.swift:88`).

**DÉCIDÉ 30-08** (plan §0 « la flamme », §4 M1.6, §5.4-14) :

- **`flamme()`** → `{jours, aujourdhui_fait}` : dates distinctes de
  `workouts.ended_at` (dans `fuseau_jour`, §6.5) pour `auth.uid()`, jours
  consécutifs en remontant depuis aujourd'hui (ou hier si aujourd'hui n'est pas
  fait). **Dérivée, jamais stockée, zéro écriture, zéro clé de bonus.**
- rendue par `etat_coffre()` (`flamme`, `flamme_aujourdhui`, §6.3) →
  `EconomieWoop` → **affichée** (home et/ou route), **jamais annoncée** (pas de
  dalle, pas de pop-up — plan §3 dernière ligne).
- **aucun effet sur l'argent** : pas de multiplicateur, pas de pièce de
  série — un chiffre qu'on regarde.
- ne pas la confondre avec le glyphe « flame » des galets futurs.

Porte de sortie du J1 : `etat_coffre().flamme` cohérent avec `workouts` du
compte de test, lu.
