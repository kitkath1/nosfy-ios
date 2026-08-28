---
name: woop-backend
description: Les lois du back-end de Woop (Supabase/Postgres + le client iOS qui l'appelle). À lire AVANT d'écrire une migration, une fonction serveur, un appel réseau ou toute écriture qui touche à l'argent du jeu — et avant de déclarer qu'un déploiement marche. Couvre l'économie (soldes dérivés, idempotence par index, ledger irréversible), les pièges de migration qui cassent À LA POSE, la vérification d'un déploiement sans base locale, la frontière client/serveur (ce qu'on ne croit jamais du client), l'outbox, et l'ordre de branchement écrire-avant-lire.
---

# Écrire le back-end de Woop

Ce dépôt n'a pas de tests, et sa base porte de l'**argent de jeu** : des
pièces, des sachets, un journal. Une erreur de vue se corrige au tour suivant.
Une erreur d'écriture reste.

**Quatre principes cardinaux**, dont tout le reste découle :

1. **Un solde se DÉRIVE, il ne se stocke pas.** La somme d'un journal ne peut
   pas mentir ; un compteur se désynchronise.
2. **L'idempotence est un INDEX, jamais un compteur.** Un index ne s'oublie
   pas, ne se réinstalle pas, ne se remet pas à zéro.
3. **Un ledger ne se rembobine pas.** On n'efface pas une ligne, on en écrit
   une inverse. Donc : on ne se trompe pas d'écriture.
4. **Rien n'est « déployé » sans une VÉRIFICATION.** « La migration est
   enregistrée » n'est pas « la colonne existe ».

---

## 1. L'économie — les lois de l'argent

**Le solde est dérivé.** `sum(delta)` sur `coin_ledger`, filtré par monnaie.
Jamais une colonne `balance`. Deux appareils, une reprise, un rejeu : la somme
est toujours juste, un compteur ne l'est plus.

**Les prix vivent en base, pas dans le code.** `reward_rules` porte
`pieces_par_serie`, `prix_booster`, `pieces_retour_quotidien`. **L'app les
LIT ; elle ne les connaît pas.** Une constante Swift qui double une règle
serveur est une bombe à retardement : le jour où l'une bouge, l'écran et la
base racontent deux histoires.

> ⚠️ Il en reste deux dans le code (`CoffreFortPurse.perSeries = 20`,
> `CoffreV2.prixBooster = 100`). Elles disparaissent à l'étape 2 du
> branchement. Ne pas en ajouter.

**Toute écriture d'argent est idempotente, et par un index unique PARTIEL :**

```sql
create unique index user_boosters_seance_unique
  on public.user_boosters (user_id, workout_id) where workout_id is not null;
```

Le motif est toujours le même : `insert` dans un `begin … exception when
unique_violation then` qui renvoie « déjà fait » **sans lever d'erreur**. Un
appelant doit pouvoir rappeler sans savoir.

⚠️ **Ce qui NE tient PAS l'idempotence** : un `UserDefaults` (se remet à zéro
à la réinstallation — payé sur `chemin.reclamees`, « boosters infinis »), un
`select` puis `insert` (deux appareils passent entre les deux), un booléen
dans le modèle local.

**Distinguer ce qui est proportionnel de ce qui est forfaitaire.** Fin de
séance : les **pièces** valent `séries × taux`, le **sachet** est UN par
session complète quel que soit le nombre de séries. Deux règles, deux clés
d'unicité, la même fonction.

---

## 2. Écrire une migration — les quatre pièges qui cassent À LA POSE

Une migration s'applique **en transaction** : elle passe entière ou pas du
tout. C'est une protection, pas une excuse — un échec à la pose sur une base
distante, c'est une soirée perdue et une base à l'état incertain dans la tête
de tout le monde.

**① Un `check` se REMPLACE en entier — recopier la DERNIÈRE liste, jamais la
première.** Ce qu'on oublie de recopier devient interdit, et les lignes
existantes qui le portent rendent la migration **impossible à appliquer**.

> Payé : ma contrainte `coin_ledger_raison_check` reprenait la liste de la
> migration d'origine (`piece_noire`, un nom mort depuis un renommage) et
> perdait `conversion_booster`. Attrapé en relecture, pas par la machine.

**② Une expression d'index doit être IMMUTABLE.**

```sql
-- ✗ REFUSÉ : timezone(text, timestamptz) est STABLE, pas IMMUTABLE
create unique index … on coin_ledger (user_id, ((created_at at time zone 'UTC')::date));
-- ✓ le jour est une COLONNE, écrite par la fonction
alter table coin_ledger add column jour date;
create unique index … on coin_ledger (user_id, jour) where raison = '…';
```

Bénéfice second : la règle de fuseau devient **une ligne à changer**, pas un
index à reconstruire.

**③ La colonne AVANT l'index et avant la fonction qui s'en sert.** Un fichier
se lit de haut en bas. Idem pour une fonction appelée par une autre.

**④ Dans un `union all` rendu par une `returns table`, TYPER chaque
littéral.** Un littéral nu reste `unknown` ; quand les deux branches en ont un
au même rang, la résolution échoue **à la création de la fonction**.

```sql
select created_at, 'coins'::text, raison::text, delta::integer, …
union all
select obtained_at, 'booster'::text, origine::text, 1::integer, …
```

**Et systématiquement** : `security definer`, `set search_path = public`,
`grant execute … to authenticated`, un en-tête de fichier qui dit **quel
verdict** la migration applique et **où** est l'analyse.

---

## 3. Écrire une fonction serveur

**Une erreur MÉTIER n'est pas une erreur SERVEUR.** « Tu n'as pas assez de
pièces » se répond `200` avec `{ouvert: false, raison: 'solde_insuffisant'}`,
jamais par un `raise exception` qui devient un **HTTP 500** — le client ne
peut alors pas distinguer un refus légitime d'un serveur cassé.

> ⚠️ `claim_booster_legendaire()` fait encore l'inverse (P0002 → 500). À
> aligner : les deux portes du même coffre ne doivent pas répondre dans deux
> langues.

**Le débit et le crédit dans la MÊME transaction.** Un réseau qui coupe entre
les deux laisse une pièce dépensée sans sachet, ou l'inverse.

**Rendre le nouveau solde.** L'appelant vient d'écrire ; il ne doit pas
avoir à re-demander pour savoir où il en est.

**Une fonction par ACTE, pas par table.** `cloturer_seance` écrit dans deux
tables : c'est un acte. Deux appels laisseraient un état à moitié réglé.

---

## 4. Ce qu'on ne croit JAMAIS du client

| ce que le client envoie | pourquoi c'est faux |
|---|---|
| un tirage de récompense | il se rejoue jusqu'à obtenir la légendaire |
| un compteur de pitié | il se remet à zéro à volonté |
| un fuseau horaire | il se change dans les réglages du téléphone — **farm par voyage dans le temps** |
| un montant, un prix | ils vivent dans `reward_rules` |
| « j'ai déjà réclamé » | c'est à l'index de le dire |

> ⚠️ **Dette actuelle et assumée** : le tirage du chemin et sa pitié vivent
> encore dans `RewardChemin.TirageRecompense` (au front). Le serveur ne fait
> qu'ENREGISTRER. Ce qui est déjà garanti, c'est qu'un nœud ne paie qu'une
> fois. Le tirage doit remonter.

**Le seul garde-fou côté client qui compte** : celui qui empêche d'écrire
là où il ne faut pas.

```swift
// Les données de démonstration ne quittent JAMAIS l'appareil.
if CommandLine.arguments.contains("-demoData"),
   !CommandLine.arguments.contains("-syncNow") { return }
```

⚠️ **Toute écriture d'argent porte cette garde.** Payé : un premier jet de
`reglerFinDeSeance` ne l'avait pas — un lancement de banc avec `-demoData`
aurait crédité mille pièces et dix sachets sur un vrai compte, **et un ledger
ne se rembobine pas**.

---

## 5. L'outbox — et la seule raison pour laquelle elle est correcte

Une écriture perdue est un **gain perdu**. Donc toute écriture d'argent passe
par `OutboxGains` : on tente, et on met en attente si ça rate. Vidage au
**retour au premier plan** — le seul instant où l'app est vivante, où le
réseau a eu une chance de revenir, et où personne ne regarde rien de précis.

⚠️⚠️ **REJOUER UNE FILE N'EST SÛR QUE PARCE QUE LE SERVEUR EST IDEMPOTENT.**
Sans cette garantie, une file DOUBLE les gains au premier accident. **On ne
met jamais dans cette file une opération dont le serveur ne sait pas dire
« déjà fait ».**

⚠️ **Une file qui ne jette rien est une file qui se BOUCHE.** Trois sorts, pas
deux :

| sort | quand | action |
|---|---|---|
| réussi | 2xx | on retire |
| **refusé définitivement** | 4xx sauf 401/408/429 | on retire **et on le crie** |
| à rejouer | réseau, 5xx, 401, 429 | on garde |

Le 401 est du côté « on rejoue » : une session expirée se renouvelle.
La file est **bornée** (200) : hors ligne trois semaines, une file non bornée
ne tient plus dans les préférences.

**Le type de la file est un `enum Codable`, jamais un `[String: Any]`** — il
casse la compilation le jour où une signature change, ce qui est exactement ce
qu'on veut d'une file qui survit aux mises à jour.

---

## 6. Déployer, et VÉRIFIER

**Par la CLI, jamais par le MCP** (celui de la session pointe sur un autre
projet). Rien ne part sans Kathryn. Le jeton se révoque après usage.

```
supabase migration list --linked   # d'abord : ce qui va réellement partir
supabase db push
```

⚠️ **« La migration est enregistrée » ne prouve PAS que le schéma est là.**
Sans Docker ni Postgres local, on vérifie autrement — et ça se fait très bien :

**Les colonnes**, par PostgREST, **avec une colonne bidon en témoin** :

```
GET /rest/v1/<table>?select=<colonne>&limit=1
   200  → la colonne existe (RLS filtre les lignes, elle n'erre pas)
   400  → "column … does not exist"
```

**Les fonctions**, en les appelant. ⚠️ **PIÈGE : PostgREST résout une fonction
par le NOM DE SES ARGUMENTS.** Un `404` sur un RPC veut dire « aucune
signature ne correspond », **pas** « la fonction n'existe pas » — une fonction
dont les paramètres n'ont pas de défaut rend 404 sur un corps vide. Re-tester
avec les arguments.

⚠️ **LIRE le corps des erreurs, ne pas les interpréter.** Le message d'échec
de `claim_retour_quotidien` sans session prouvait à lui seul quatre choses :
le montant lu dans `reward_rules`, la raison acceptée par le `check` (sinon
l'erreur serait une violation de contrainte), la colonne `jour` remplie, et le
nombre de colonnes. Un code HTTP seul n'aurait rien prouvé.

**Le test de bout en bout se fait sur le compte de TEST**
(`kat44426+woop-forge-test@gmail.com`, `ForgeServeur.jwtBanc()`), jamais sur un
vrai compte. Et il inclut **le rejeu** : appeler deux fois et vérifier que le
second ne crédite rien.

**Le simulateur n'a pas de mode avion — on le fabrique en banc.**
`-outboxAvion` coupe, `-outboxSemer` sème, `-outboxBanc` route vers le compte
de test. La file se lit **de l'extérieur** :

```
xcrun simctl get_app_container <dev> fr.kathryn.woop data
→ Library/Preferences/fr.kathryn.woop.plist  ·  clé woop.outbox.gains
```

---

## 7. L'ordre de branchement — écrire AVANT de lire

1. **Écrire, sans que rien ne lise.** L'écran ne change pas ; si c'est faux,
   rien ne casse visiblement ; le journal se remplit.
2. **Lire les prix** depuis `reward_rules`.
3. **Lire les soldes** — c'est la première étape où l'écran change, donc la
   première où une panne réseau se VOIT : elle oblige à écrire les états
   « chargement » et « erreur ».
4. **Basculer l'historique** sur le journal.

**Un branchement qui ne se voit pas est un branchement qu'on peut défaire.**

⚠️ Et une reconstruction n'est pas un journal : la page des gains recalcule
`séries × 20` depuis les séances, donc elle **rate** tout ce qui n'est pas une
séance (versement quotidien, boosters du chemin, sachet de fin de séance).

---

## 8. La check-list avant de dire « c'est fait »

- [ ] La migration nomme le verdict qu'elle applique et pointe vers l'analyse.
- [ ] Chaque `check` recopié depuis **la dernière** migration, pas la première.
- [ ] Aucune expression d'index non-immuable.
- [ ] Colonnes et fonctions déclarées **avant** leurs usages.
- [ ] Chaque écriture d'argent : un index unique partiel + `unique_violation`
      attrapée + garde `-demoData`.
- [ ] Les erreurs métier rendent 200 avec un motif, pas 500.
- [ ] `migration list` **avant** et **après** le push.
- [ ] Colonnes vérifiées par PostgREST, **avec un témoin qui échoue**.
- [ ] Fonctions appelées **avec leurs arguments** (le 404 ment).
- [ ] Corps d'erreur **lus**, pas devinés.
- [ ] Bout en bout sur le compte de test, **rejeu compris**.
- [ ] Ce qui n'a pas pu être mesuré est **dit**, pas supposé.
