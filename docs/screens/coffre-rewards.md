# Écran — REWARDS (le coffre)

`Woop/Views/CoffreV2.swift` · hôte et données `Woop/Views/CoffreFortView.swift`
(`CoffreFortFlow`) · économie `Woop/Views/CoffreFortPurse.swift` · réserve de
sachets `SacreEtat` (`Woop/Views/BoosterPopup.swift`) · client RPC
`Woop/Services/SacreServeur.swift`.

> **Convention de ce document.** Ce qui est écrit sans marque est **vérifié
> dans le code**. Ce qui porte **?** n'est pas sûr et attend une décision ou
> une vérification. Ce qui porte **CIBLE** est décidé mais **n'existe pas
> encore**. Les tables de la base ne sont pas décrites ici : seulement ce que
> le backend doit **décider** et **renvoyer**. Le détail des tables vit dans
> `tools/coffre-v2/BACKEND-COFFRE.md`.

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
la cérémonie d'ouverture.

---

## 2 · Affiche

**Une salle, un socle, un objet.** Un mur éclairé barré d'un néon en haut
(0,225 de la hauteur), du noir en dessous, un socle au milieu, et **un seul
objet posé dessus à la fois**.

**Quatre pages qui se feuillettent** horizontalement, dans cet ordre :

| # | objet | ce que le pied annonce |
|---|---|---|
| 1 | pièce d'or | le solde en pièces · « 20 coins for every set you finish. » |
| 2 | booster orange | les sachets en attente · « 100 coins open one. » · **jauge** + « n to go » · bouton **Ouvrir** |
| 3 | pièce d'argent | le solde d'argent · « A rare drop, never earned. » |
| 4 | booster noir | les légendaires ouvrables · « One silver coin opens it. » · bouton **Ouvrir** |

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
l'objet, ce qu'il a rapporté, la date.

---

## 3 · Actions

| # | Action | Geste | Appel backend |
|---|---|---|---|
| A1 | **Changer d'objet** | glisser horizontalement, ou taper un cran | aucun |
| A2 | **Regarder un objet de près** | taper l'objet (il grossit et lévite) | aucun |
| A3 | **Ouvrir un booster** | bouton « Ouvrir » (pages 2 et 4) | **CIBLE** page 2 → `claim_booster` (débite 100 pièces, réserve un sachet) · page 4 → `claim_booster_legendaire` (débite 1 pièce d'argent) — **écrite et déployée, jamais appelée** |
| A4 | **Voir l'historique** | pill en haut à droite | **CIBLE** `historique_gains()` — aujourd'hui reconstruit en local depuis les séances |
| A5 | **Fermer l'historique** | croix, **ou tirer la page vers le bas** | aucun |
| A6 | **Fermer le coffre** | chevron en haut à gauche | aucun |
| A7 | **Tirer la card** ? | un geste vertical existe (`tirage`, `LuneSecrete`) — **?** son statut produit n'est pas tranché | aucun |

⚠️ **Aujourd'hui aucune action ne déclenche le moindre appel réseau.** Tout est
local : les soldes sont recalculés depuis les séances SwiftData, les réserves
de sachets sont un compteur en mémoire initialisé à 1, et la dépense est
**simulée** (`dispo = coins − sachets × 100`).

---

## 4 · Sorties

| Depuis | Vers |
|---|---|
| **Ouvrir** (page 2 ou 4) | ⚠️ le coffre se **ferme d'abord**, puis le **Manège** monte à la racine 450 ms plus tard — le Manège vit sous le `fullScreenCover` du coffre, l'ouvrir sans fermer lancerait la cérémonie derrière la page |
| **Ouvrir** → Manège → sachet déchiré | la **carte forgée** (`forge-card`), puis retour d'où l'on venait |
| **chevron** | l'écran d'où l'on est venu (profil, home, ou chemin selon l'entrée) |
| **pill historique** | l'Historique, **en overlay** — pas une feuille : empiler une `sheet` sur un `fullScreenCover` donne la poignée grise du système au milieu de la nuit |
| **Historique** → croix / drag bas | retour au coffre, page inchangée |

**Qui entre ici** : les deux pills du **profil** (or et noir) et — **?** — la
home. Le **chemin** n'entre pas dans le coffre : ses récompenses ouvrent
directement la card à gratter puis le Manège.

---

## 5 · États

| État | Aujourd'hui | CIBLE |
|---|---|---|
| **arrivée** | une cascade : le titre s'affûte, l'objet se pose, la jauge se remplit. Pas de chargement — tout est local et instantané | l'appel `etat_coffre()` part à l'ouverture ; **les nombres restent ceux du dernier état connu** pendant qu'il vole, et se corrigent à l'arrivée. ⚠️ Jamais de squelette gris à la place d'un nombre : le coffre est une salle, pas un tableau de bord |
| **vide** | page or à 0, page argent à 0 : le compte s'affiche et **la règle explique** — elle n'console pas. Historique vide : « Rien encore. Une série faite, vingt pièces. » | inchangé |
| **rien à ouvrir** | le bouton « Ouvrir » **n'existe pas** quand le solde est à 0 (pas un bouton grisé) | ⚠️ **CIBLE à trancher** : le §5 d'Opal dit qu'un verrou se dit par la **matière** — le sachet mat, non éclairé, et le bouton « Locked ». Aujourd'hui il n'y a rien du tout |
| **chargement d'une action** | n'existe pas | « Ouvrir » doit passer en attente et **revenir à son état** si l'appel échoue — jamais un bouton mort |
| **erreur** | **n'existe pas du tout** | ⚠️ Un échec d'`etat_coffre()` ne doit **pas** vider la page : on garde le dernier état connu et on ne dit rien. Un échec de `claim_booster` doit se dire, parce qu'il a coûté un geste — **?** sous quelle forme (bandeau, retour du bouton, haptique d'échec) |
| **hors ligne** | invisible — rien n'est réseau | les soldes affichent le dernier état connu ; « Ouvrir » refuse et le dit |
| **conflit deux appareils** | le compteur local diverge en silence | les claims sont **idempotents côté serveur** (index uniques partiels), donc le pire cas est un rafraîchissement, jamais un double débit |

---

## 6 · Le backend et ses règles

> Ce que le serveur doit **décider** et **renvoyer**. Le détail des tables est
> dans `tools/coffre-v2/BACKEND-COFFRE.md`, les règles d'économie dans
> `tools/rewards/PLAN-REWARDS-BACKEND.md` §4 nonies → terdecies.

### 6.1 Les règles

| Règle | Valeur | Statut |
|---|---|---|
| une série terminée rapporte | **20 pièces d'or** | tranchée le 13-08 |
| un booster orange coûte | **100 pièces d'or** | tranchée |
| un booster noir coûte | **1 pièce d'argent** | tranchée |
| une connexion rapporte | **10 pièces d'or, une fois par jour calendaire** | ✅ tranchée le 28-08 |
| une séance terminée rapporte | **1 booster orange, automatiquement** | tranchée le 28-08 |

| un nœud de chemin rapporte | 100-200 pièces · 1 pièce d'argent (6 %) · **ou 1 à 2 boosters** | codé au front, pas au serveur |
| la pièce d'argent | **ne s'achète pas et ne se gagne pas régulièrement** — elle TOMBE | tranchée |

⚠️⚠️ **UN SEUL BOOSTER PAR SESSION COMPLÈTE, QUEL QUE SOIT LE NOMBRE DE
SÉRIES** (précisé par Kathryn le 28-08). Les deux récompenses de fin de séance
ne comptent donc PAS la même chose : les **pièces** sont proportionnelles au
travail (séries × 20), le **booster** est forfaitaire — il paie le fait
d'avoir fini, pas la quantité. Une séance de 3 séries et une de 15 donnent
**un sachet chacune**.

⚠️ **Les prix ne vivent pas dans le code.** L'app les LIT (`reward_rules`) ;
elle ne les connaît pas. Changer un prix ne doit jamais demander un build.

⚠️ **Le solde est DÉRIVÉ, jamais stocké** — la somme d'un journal ne peut pas
mentir, un solde stocké se désynchronise.

⚠️ **Tout crédit est IDEMPOTENT par construction**, par index unique partiel et
non par compteur applicatif : une série ne paie qu'une fois, une séance ne
donne qu'un sachet, un nœud de chemin ne se réclame qu'une fois, un jour ne
verse qu'une fois. Un compteur local se remet à zéro à la réinstallation ;
un index, non.

⚠️ **La pitié du chemin doit passer côté serveur** (après 12 nœuds communs, le
taux rare double). Au front, elle est falsifiable.

### 6.2 ✅ DÉPLOYÉ LE 28-08 — et vérifié fonction par fonction

`supabase db push` a posé `20260828190000_gains_coffre.sql` (les deux
précédentes étaient déjà en base). Chaque fonction a ensuite été **appelée en
HTTP** pour vérifier qu'elle répond, et pas seulement que la migration est
enregistrée :

| fonction | vérifiée |
|---|---|
| `solde_or()` | ✓ 200 |
| `claim_retour_quotidien()` | ✓ (400 sans session : `auth.uid()` est nul, c'est le comportement attendu) |
| `cloturer_seance(uuid, int)` | ✓ 200, forme JSON correcte |
| `reclamer_noeud_chemin(int, int, text, text[])` | ✓ 200, forme JSON correcte |
| `historique_gains(int)` | ✓ 200 |
| `claim_booster()` | ✓ 200 |

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
| `user_boosters` | `noeud_id` ✓ `robe` ✓ `origine` ✓ `opened_at` ✓ |
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

⚠️ **UNE INCOHÉRENCE TROUVÉE AU PASSAGE, ET ELLE EST ANCIENNE.**
`claim_booster_legendaire()` rend **HTTP 500** avec `P0002 « pièces d'argent
insuffisantes »` : elle lève une exception pour une condition MÉTIER. Un client
ne peut alors pas distinguer « tu n'as pas assez » d'un serveur cassé sans
éplucher le corps. Mon `claim_booster()` fait l'inverse — **200** avec
`{ouvert: false, raison: 'solde_insuffisant'}`. **? À aligner** : les deux
portes du même coffre ne devraient pas répondre dans deux langues.

⚠️ **RIEN DANS L'APP NE LES APPELLE ENCORE** — c'est l'étape 1 assumée (§6.6).

### 6.3 Ce que le serveur doit renvoyer

**`etat_coffre()`** — tout le pied en un appel, pour que le coffre et le profil
ne puissent pas afficher deux vérités :

```
solde_or · solde_argent · boosters_or · reste (0-99)
prix_booster · pieces_par_serie
```

**`historique_gains()`** — le journal, une ligne par ÉVÉNEMENT, la plus récente
d'abord : `date · type · libellé · montant · robe`.
⚠️ Aujourd'hui la page **reconstruit** l'historique depuis les séances
(`séries × 20`) : les trois sources qui ne sont pas des séances — le versement
quotidien, les boosters du chemin, le booster de fin de séance — **n'y
apparaissent jamais**. C'est ce qui rend la bascule obligatoire, et c'est aussi
ce qui donnera enfin des lignes avec une image de **sachet** (`GainCoffre.robe`
est aujourd'hui toujours `nil`, donc chaque ligne montre la pièce d'or).

### 6.4 Les écritures

| Quand | Ce que le serveur écrit | Garantie |
|---|---|---|
| une séance est terminée | **+ séries × 20** pièces, raison `serie_faite`, en **une seule ligne** | unique par (user, raison, séance) — l'index existe déjà |
| une séance est terminée | **1 booster** `origine = 'seance'`, **forfaitaire** | unique par (user, séance) — l'index existe déjà |
| première ouverture du jour | +10 pièces, raison `retour_quotidien` | unique par (user, jour) |
| un nœud de chemin est réclamé | pièces **ou** 1-2 boosters `origine = 'chemin'` | unique par (user, nœud) |
| « Ouvrir » un booster orange | −100 pièces, 1 booster `origine = 'achat'` | refuse si le solde est insuffisant |
| « Ouvrir » un booster noir | −1 pièce d'argent, 1 booster `origine = 'legendaire'` | une seule réserve non scellée à la fois |

### 6.5 Le fuseau — **UTC pour l'instant, et le changement coûte une ligne**

Le versement quotidien a besoin d'une définition de « jour ». En UTC,
quelqu'un qui ouvre l'app à 1 h du matin à Paris touche le versement de la
veille. Le fuseau du profil serait juste, mais coûte une colonne et une
décision. **?** — reste ouvert.

⚠️ **Ce qu'il ne faut surtout pas**, c'est le fuseau envoyé par le client à
chaque appel : il se change dans les réglages du téléphone — c'est le farm par
voyage dans le temps.

⚠️ **Le jour est une COLONNE, pas une expression d'index — et Postgres ne
laissait pas le choix.** `(created_at at time zone 'UTC')::date` dans un index
est **refusé** : `timezone(text, timestamptz)` est `STABLE`, pas `IMMUTABLE`
(elle dépend de la base de fuseaux, qui est mise à jour). L'index aurait fait
**échouer la migration À LA POSE**, à moitié appliquée. Le jour est donc écrit
par la fonction au moment de l'insertion — ce qui rend le choix du fuseau
explicite et modifiable : **une seule ligne à changer**, pas un index à
reconstruire.

### 6.6 L'ordre de branchement

1. **Écrire** sans rien lire — remplir le journal pendant que l'app continue
   sur sa maquette.
2. **Lire les prix** (`reward_rules`) au lieu des constantes Swift.
3. **Lire les soldes** (`etat_coffre`) — le corps de `variantes` disparaît, la
   vue ne bouge pas d'une ligne.
4. **Basculer l'historique** sur le journal.
5. **Le chemin** et sa pitié côté serveur.

⚠️ Les étapes 1 et 2 ne changent **rien à l'écran** — et un branchement qui ne
se voit pas est un branchement qu'on peut défaire.

### 6.7 La question d'économie ouverte — **?**

Une séance de 5 séries rapporte 100 pièces = un booster. Si elle donne **en
plus** un booster automatique, elle en rapporte **deux**, et le prix de 100
pièces ne décide plus grand-chose pour quelqu'un de régulier. Trois sorties :
assumer · monter le prix (150-200) · distinguer les robes. Le prix vivant dans
`reward_rules`, ce choix se change sans build.
