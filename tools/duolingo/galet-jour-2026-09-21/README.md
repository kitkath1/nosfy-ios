# Un galet = un jour — 21-09-2026

Sa règle, dictée le 21-09 : **« oui c'est ça, un jour = un galet »**, avec le
sticker ×2 sur le galet du jour, une **pop-up native** pour choisir l'heure de
la séance à revoir quand la journée en porte deux, et **les pièces de la
deuxième séance conservées** (« il faut juste mettre le fois ici »).

## Ce qui a changé, et ce qui n'a pas bougé

| | avant (18-09 → 20-09) | depuis le 21-09 |
|---|---|---|
| un galet | une séance terminée avec travail | **un jour local avec au moins une séance** |
| deux séances le même jour | deux galets, le 2e portait le ×2 | **un galet**, qui porte le ×2 |
| lunes 3/7 et trésor 35 | comptaient des séances | **comptent des jours** |
| plafond 2 séances/jour | inchangé | inchangé (la 3e est refusée, pop-up native) |
| pièces et sachet de la 2e séance | payés | **payés** (sa décision) |
| « View » sur un galet | ouvrait la séance à ± 2 s | **demande le jour** → une seule séance : sa story ; deux : la feuille native d'Apple, heure + type + durée |

## Serveur — POSÉ le 21-09 et vérifié

`supabase/migrations/20260921090000_chemin_un_galet_par_jour.sql`

- `public.jours_chemin()` (nouvelle) : un jour par ligne, avec `seances` (1 ou 2),
  `premiere` et `derniere` fin de la journée. Elle s'appuie sur
  `seances_chemin_plafonnees()`, **laissée intacte**.
- `cartes_prive.tirer_noeud_chemin` : la garde compte `jours_chemin()` au lieu
  des séances plafonnées. **Une seule ligne change** par rapport au 20-09.
- Ni `seances_chemin()` (le correctif HIIT d'une autre session), ni la clôture,
  ni `reward_rules` ne sont touchés.

**Pose** : `POST /v1/projects/…/database/query` → HTTP 201, puis relecture des
deux fonctions (`pg_get_functiondef` contient bien `jours_chemin` pour les
deux). Historique : `supabase migration repair` a été refusé par la CLI
(`LegacyDbConfigLoginRoleStatusError`, 401 — la CLI n'est plus authentifiée sur
ce Mac), la version a donc été inscrite directement dans
`supabase_migrations.schema_migrations` (insert idempotent, relu : la ligne
`20260921090000 · chemin_un_galet_par_jour` est en tête).

⚠️ Constat de passage, pas de mon fait : `20260920120000`
(`seances_chemin_kind_telephone`, le correctif HIIT) **figure dans l'historique
distant** — elle n'était donnée pour « locale » que jusqu'au 20-09.

## Bancs

- **`tools/duolingo/qa-galet-jour.sql`** + `verif_galet_jour.py` (nouveaux) :
  **15 PASS / 0 FAIL**, d'abord avec la migration rejouée dans la transaction
  annulée (avant la pose), puis sur la base posée. Ils couvrent : deux séances
  le même jour = une ligne à `seances = 2` avec `premiere < derniere` ; les deux
  clôtures payées ; la troisième séance qui n'ajoute ni jour ni séance et ne
  paie rien ; la lune du rang 3 **refusée** à trois séances sur deux jours,
  **accordée** au troisième jour ; le rejeu idempotent ; la séance vide qui ne
  pose pas de galet ; le compte étranger qui ne voit rien.
- **`tools/duolingo/qa-plafond-jour.sql`** (existant) : **25 PASS / 0 FAIL**.
  Deux corrections : l'assertion « lune accordée avec 3 séances comptées »
  devient un **refus** (elles tenaient sur deux jours) ; et le fuseau du contrôle
  de la ligne de date n'est plus écrit en dur — Pago Pago ne recule d'un jour
  qu'avant midi à Paris, ce banc échouait donc tous les après-midi, **avant** ce
  chantier. Il choisit maintenant le fuseau qui décale vraiment à l'heure du banc.
- **`tools/duolingo/verif_route_vide.py`** (le calcul Swift réel, sans vue) :
  **1 328 contrôles PASS**. ⚠️ Il ne compilait plus depuis le 20-09 (il
  n'extrayait pas `PlafondJour`, dont `etapeEtFaits` dépend depuis le plafond) :
  réparé, et étendu au ×2 (un seul galet, la date de la première fin, l'actif
  qui ne répète plus la date du jour, la 3e séance sans effet, un jour double
  parmi des jours simples).

## Téléphone — l'app

Build simulateur **vert** (`BUILD SUCCEEDED`). Fichiers touchés :
`PlafondJour.swift` (nouvelle `jours(_:)`), `DuolinguoPage.swift`
(`etapeEtFaits` rend `seances`, `Lecture.seancesParGalet`, `multiple` par
lecture, l'actif sans date quand le jour est fait, la fête ×2),
`GaletEtape.swift` (le sticker tombe au ressort), `CardRoute.swift`,
`HomeNuit.swift`, `NosfyApp.swift` (le galet fêté = celui du jour, « View » par
jour), `DepartSeance.swift`, `Models.swift` (`duJour(parFin:)`),
`HistoriqueStories.swift` (la feuille native, et une trace quand un jour est vide).

Bancs de l'app : `-duoFois2` (le dernier galet fait porte deux séances),
`-sansFeteFois2` (le ×2 posé sans son arrivée), `-cheminFete`, `-sansCineGalet`.

## Ce qui n'est PAS fait

- **Rien n'est mesuré sur son iPhone** : ni la fête du galet, ni le ×2.
- Les comptes réels n'ont pas été relus après la pose (lecture seule respectée ;
  ils sont vides depuis le 20-09).
- Le fait `double_jour` de la story (Paris, `started_at`, séances vides
  comprises) n'a toujours **pas** la même définition du jour que le galet (jour
  local, `ended_at`, avec travail) : la story peut dire ×2 sans la Route, et
  l'inverse. À aligner — non fait ici.
