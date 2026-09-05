# Les données des quatre widgets — ce qui existe, ce qui manque

**05-09-2026.** Analyse demandée avant d'écrire une ligne de back-end. Elle
inventorie **toutes** les données que les quatre cards de la home et leurs
« chambres longues » affichent, et dit pour chacune : d'où elle vient
aujourd'hui, ce que le serveur en sait, et ce qu'il faudrait poser.

> **MISE À JOUR DU 05-09, APRÈS MESURE.** Le back-end a été mesuré puis écrit.
> Ce qui suit reste vrai côté app ; les trois faits qui changent tout sont en
> tête du §1 bis.

---

## 0. Le fait qui commande

**Les quatre widgets sont calculés dans le téléphone, en entier.**
`SemaineStats.calcule()` ([WidgetsCards.swift:2207-2293](../../Woop/Views/WidgetsCards.swift))
repasse sur les `Workout` en mémoire et produit les quatre cards. Aucun appel
serveur.

Conséquences, dans l'ordre de gravité :

1. **Rien ne survit à une réinstallation** — `SupabaseSync` n'a qu'un `push`
   ([SupabaseSync.swift:70](../../Woop/Services/SupabaseSync.swift)) et
   `snapshot()`. Il n'existe **aucune lecture**. C'est la cause unique de tous
   les 🟡 de cette liste.
2. **Rien n'est comparable entre appareils.**
3. **La home ne peut pas se peindre avant la fin de la synchro locale.**

---

## 1 bis. CE QUE LA MESURE A DIT (05-09, API de gestion)

1. **`cardio_phases` existe et porte tout** — six colonnes, témoin bidon à
   l'appui (400/42703). Le ⚪ « à retravailler » du 29-08 est **démenti**.
2. **Les quatre tables de séance sont VIDES.** `count(*) = 0` partout. Les 80
   lignes de `coin_ledger` appartiennent toutes au **compte de test**, écrites
   par les scripts des 28-30 août. **Aucun compte réel n'a jamais rien
   synchronisé** — alors que `push()` est appelé de trois endroits et que les
   politiques RLS sont bonnes. `push()` avale ses erreurs
   ([SupabaseSync.swift:118-121](../../Woop/Services/SupabaseSync.swift)) :
   une panne d'auth est invisible. **C'est le blocage racine.**
3. **La lecture est posée** : `20260905090000_widgets_lecture.sql` déployée,
   `widget_regularite` · `widget_volume` · `widget_hiit` · `widget_peak`
   mesurées bout en bout sur données semées (puis `rollback`, zéro ligne
   laissée), et `seuil_effort_kmh = 15.0` en base.

## 1. Ce que le serveur reçoit déjà — et c'est beaucoup

`push()` écrit **quatre tables** dans l'ordre des clés étrangères
([SupabaseSync.swift:111-117](../../Woop/Services/SupabaseSync.swift)) :

| table | colonnes poussées | ce que ça débloque |
|---|---|---|
| `workouts` | `started_at`, `ended_at`, `notes` | régularité, séries de semaines, tous les comptes par fenêtre |
| `logged_exercises` | `exercise_id`, `position` | catégories, exercices préférés |
| `strength_sets` | `reps`, `weight`, `position` | volume, records de charge, 1RM |
| `cardio_phases` | `kind`, `seconds`, `speed`, `incline`, `cycle_index`, `position` | **toute la chambre HIIT** |

**La donnée brute des quatre widgets est donc DÉJÀ au serveur.** Ce qui manque
n'est pas la collecte : c'est **le calcul et la lecture**.

> ⚑ **LITIGE À TRANCHER.** La carte du serveur donne `cardio_phases` en ⚪
> « à retravailler » (`b-tb-cardio`, décision du 29-08), alors que
> `SupabaseSync.swift:117` y écrit à chaque séance. Deux lectures possibles :
> le schéma est jugé insuffisant (mais il porte bien durée + vitesse + cycle),
> ou l'écriture échoue en silence (`push` avale ses erreurs,
> [:118-121](../../Woop/Services/SupabaseSync.swift)). **À MESURER** :
> `GET /rest/v1/cardio_phases?select=seconds,speed,cycle_index&limit=1` avec
> un témoin bidon. Tant que ce n'est pas mesuré, aucune pastille ne bouge.

---

## 2. Widget 01 · Regularity

Après le verdict du 05-09, la chambre ne parle **que** de régularité — aucun
kilo.

| ce que l'écran montre | d'où ça vient | serveur | verdict |
|---|---|---|---|
| séances faites dans la fenêtre | `cette.count` ([:2239](../../Woop/Views/WidgetsCards.swift)) | dérivable de `workouts` | 🟡 local |
| l'objectif hebdomadaire (3→10) | `prevues`, passé en paramètre | **nulle part** | ⚪ à poser |
| comparaison à la fenêtre précédente | `precedente` bornée au même instant ([:2230-2236](../../Woop/Views/WidgetsCards.swift)) | ⚪ | 🟡 local |
| semaines d'affilée (la série) | **n'existe pas** | ⚪ | ⚪ à écrire |
| record de séries (6 semaines) | **n'existe pas** | ⚪ | ⚪ à écrire |
| jours faits (les cases) | `joursFaits` / `moisFaits` ([:2271, :2285](../../Woop/Views/WidgetsCards.swift)) | dérivable | 🟡 local |
| sticker d'un jour | `WoopSticker.pour(_:)` ([ProgressPage.swift:704](../../Woop/Views/ProgressPage.swift)) sur la 1ʳᵉ catégorie | dérivable de `logged_exercises` | 🟡 local |
| **halo d'intensité d'un jour** | approché par `efforts[i]` (volume + 20 kg/min de cardio, [:2267](../../Woop/Views/WidgetsCards.swift)) — **jamais normalisé ni exposé** | ⚪ | ⚪ à définir |
| le défi (« encore 4 pour battre août ») | **n'existe pas** | ⚪ | ⚪ à écrire |

**À poser au serveur** — une seule fonction suffirait :

```
regularite(p_fenetre text)  -- 'semaine' | 'mois'
  → { faites, objectif, precedente, suite_semaines, record_suite,
      jours[{jour, categorie, intensite}], defi{reste, cible, mois, projection} }
```

**La série de semaines ressemble à `flamme()`** qui existe déjà
(`20260830...`, dérivée de `workouts.ended_at` dans `fuseau_jour`) — mais en
**jours**. La version en semaines se dérive exactement pareil : on ne stocke
rien, on compte à rebours depuis la semaine courante tant qu'une semaine
contient au moins une séance. **Même loi : jamais un compteur.**

**L'objectif est la seule donnée à ÉCRIRE** (les autres se dérivent).
**FAIT le 05-09** (`20260905110000_objectif_hebdo.sql`) : table `user_prefs`
(une ligne par compte, RLS « own », borne 1..14), `definir_objectif(n)`
idempotente qui rend le nouvel état et refuse en 200 hors bornes,
`objectif_hebdo()` qui retombe sur la règle `objectif_hebdo_defaut = 5`.
`widget_regularite` rend désormais `objectif` et `reste`. Mesuré : écrire 10
→ relire 10, écrire 3 → relire 3, 99 et 0 refusés, ligne supprimée après le
test. **L'onboarding pourra écrire par la même porte.**

---

## 3. Widget 02 · Volume

| ce que l'écran montre | d'où ça vient | serveur | verdict |
|---|---|---|---|
| volume de la fenêtre | `cette.reduce { $0 + $1.totalVolume }` ([:2245](../../Woop/Views/WidgetsCards.swift)) | dérivable de `strength_sets` (`sum(reps × weight)`) | 🟡 local |
| gain vs période précédente | ([:2248-2253](../../Woop/Views/WidgetsCards.swift)) — **borne les deux moitiés au même instant**, correctif du 25-08 | ⚪ | 🟡 local, **modèle à reprendre** |
| volume par jour (la courbe) | `efforts[i]` | dérivable | 🟡 local |
| moyenne par séance | `v / faites` | dérivable | 🟡 local |
| record de semaine | **n'existe pas** (valeur en dur dans la maquette) | ⚪ | ⚪ à écrire |
| les 3 exercices qui portent le total | agrégat par `exerciseID` | dérivable | 🟡 local |
| répartition par catégorie | somme par `ExerciseCategory` ([Models.swift:9](../../Woop/Models.swift)) | dérivable — **la catégorie est dans le catalogue Swift, pas en base** | 🟡 local ⚠️ |
| **le cardio pèse 0 kg** | par construction | — | ⚪ **décision à écrire** |

> ⚠️ **Le catalogue d'exercices n'est pas en base** (mémoire projet : « aucune
> table catalogue »). Le serveur connaît `exercise_id` mais **pas** sa
> catégorie ni son nom. Deux voies : (a) le serveur rend les agrégats par
> `exercise_id` et l'app fait la jointure avec son catalogue — simple, garde
> le catalogue en Swift ; (b) une table `exercises` de référence. **(a) est
> suffisante** pour tout ce que les widgets affichent.

---

## 4. Widget 03 · HIIT Peak — le plus riche, et le seul qui MENT

| ce que l'écran montre | d'où ça vient | serveur | verdict |
|---|---|---|---|
| les segments d'une séance | `ex.orderedPhases`, chaque `CardioPhase` portant SA durée et SA vitesse ([Models.swift:524-546](../../Woop/Models.swift)) | **poussés dans `cardio_phases`** | 🟡 local (litige §1) |
| le pic de la fenêtre | `hiitPeak()` | dérivable (`max(speed)`) | 🟡 local |
| **le « × N » d'un intervalle** | groupage par `(kindRaw\|speed\|seconds)` **identiques** ([:2318-2325](../../Woop/Views/WidgetsCards.swift)) | — | 🔴 **MENT** |
| nombre d'efforts | **n'existe pas** | ⚪ | ⚪ à écrire |
| temps de pics cumulé | **n'existe pas** | ⚪ | ⚪ à écrire |
| fourchettes d'effort / de récup | **n'existe pas** | ⚪ | ⚪ à écrire |
| ratio effort:récup | **n'existe pas** | ⚪ | ⚪ à écrire |
| le pic sur 4 semaines | **n'existe pas** | ⚪ | ⚪ à écrire |

### 4.1 Le défaut 🔴, en clair

`hiitPeak()` déduit les répétitions en groupant les phases d'effort par une
clé qui exige **la même vitesse ET la même durée**. Une séance réelle — verdict
du 05-09 — ne répète jamais rien : `2:00 @ 17,0` puis `0:30 @ 19,0` puis
`1:30 @ 17,5`. Donc **chaque groupe vaut n = 1**, le score
`pow(v, 2.2) × pow(sec × n, 0.5)` retombe sur une phase isolée, et la card
affiche **« 2:00 continuous »** là où il y a eu quatre efforts.

**La card de la home ment déjà, avant même que la chambre existe.** Corriger
le groupage est un **préalable au branchement** : sinon la home dira
« continuous » et la chambre « 4 efforts » à un écran de distance.

### 4.2 Le seuil — trois chiffres pour une idée

| où | valeur | ce que ça définit |
|---|---|---|
| `hiitPeak()` ([:2306](../../Woop/Views/WidgetsCards.swift)) | **9,5 km/h** | plancher de candidature d'un pic |
| la chambre (verdict 05-09) | **15,0 km/h** | ce qui compte comme « un effort » |
| `efforts[i]` de la régularité ([:2267](../../Woop/Views/WidgetsCards.swift)) | **20 kg/min** | l'équivalence cardio ↔ fonte |

**Un effort = un passage au-dessus de 15,0 km/h.** Ce seuil doit vivre en base,
dans `reward_rules`, exactement comme `chemin_pitie` ou `pieces_par_serie` —
sinon la home, la chambre et le bilan compteront trois fois différemment. Le
9,5 devient alors un second seuil explicite, ou disparaît.

> ⚠️ Le seuil est une **règle du jeu**, pas une préférence : il a sa place dans
> `reward_rules`. L'app le **lit**, elle ne le connaît pas (§1 du skill).

---

## 5. Widget 04 · Peak Effort

| ce que l'écran montre | d'où ça vient | serveur | verdict |
|---|---|---|---|
| le record de la fenêtre | `peakEffort()` ([:2353](../../Woop/Views/WidgetsCards.swift)) | dérivable (`max(weight)`) | 🟡 local |
| le précédent record | `maxAvant[exerciseID]` ([:2355-2361](../../Woop/Views/WidgetsCards.swift)) | dérivable | 🟡 local |
| **l'ascension (toutes les marches)** | `maxAvant` **contient déjà l'historique complet — puis il est JETÉ** | ⚪ | ⚪ **le chantier le moins cher** |
| 1RM estimé | **n'existe pas** (Epley dans la maquette) | ⚪ | ⚪ trivial |
| « depuis le dernier record » | **n'existe pas** | ⚪ | ⚪ à écrire |
| les autres pics de la fenêtre | dérivable | ⚪ | 🟡 local |

---

## 6. Le bilan (semaine ET mois) — demandé pour les QUATRE widgets

« En progrès / En recul » compare une fenêtre à la précédente. **Rien ne le
calcule** : `SemaineStats` ne compare que le volume.

**Le modèle existe déjà et il est bon** : le correctif du 25-08
([:2218-2236](../../Woop/Views/WidgetsCards.swift)) borne la période précédente
**au même temps écoulé** — un mardi, on compare deux mardis, pas deux jours
contre sept. *Toute* comparaison de fenêtre doit reprendre cette borne, sinon
le bilan annoncera « en recul » tous les lundis de l'année.

**La phrase de l'IA** est la **seule** pièce des chambres qui ait besoin du
réseau. `weekly-synthesis` fait déjà ce travail dans le dépôt
(`supabase/functions/weekly-synthesis/index.ts`, 131 lignes) mais n'est
**jamais déployée** (`b-edge-weekly`). Elle veut : un cache par période (une
phrase par semaine, pas par ouverture), un état de repli **sans phrase** (les
deltas seuls), jamais un spinner.

---

## 7. Ce qu'il faudrait poser, par ordre de coût croissant

| # | ce qu'on pose | coût | pourquoi d'abord |
|---|---|---|---|
| 1 | **Mesurer `cardio_phases`** (sonde + témoin) | ⏱️ | tout le HIIT en dépend, et le litige §1 bloque toute décision |
| 2 | **Corriger le groupage de `hiitPeak()`** | ⏱️ | la card ment **aujourd'hui**, sur du code livré |
| 3 | `seuil_effort_kmh = 15.0` dans `reward_rules` | ⏱️ | une seule définition pour trois écrans |
| 4 | **Ne plus jeter `maxAvant`** → l'ascension | ⏱️ | la donnée est là, à un `return` près |
| 5 | Une **lecture** dans `SupabaseSync` | ⏳ | débloque *tous* les 🟡 d'un coup |
| 6 | `regularite()`, `volume_fenetre()`, `hiit_fenetre()`, `peak_fenetre()` | ⏳ chacune | une fonction par **acte**, pas par table |
| 7 | `bilan_periode()` — la comparaison, bornée au même instant | ⏳ | sert les quatre widgets |
| 8 | Déployer `weekly-synthesis` + cache | ⏳ | la phrase du bilan |
| 9 | L'objectif hebdomadaire (écriture) | ⏱️ | la seule donnée que l'utilisatrice **écrit** |

**L'ordre de branchement du skill s'applique** (§7) : écrire d'abord sans que
rien ne lise, puis lire les règles, puis les valeurs — c'est à l'étape « lire »
que l'écran change, donc la première où une panne réseau se voit, donc la
première qui oblige à écrire les états « chargement » et « erreur ».

---

## 8. Ce qui n'a PAS été vérifié

- **Aucune sonde HTTP n'a été lancée.** Tous les états ci-dessus sont lus dans
  le code. Le litige `cardio_phases` (§1) est le premier à mesurer.
- **Je n'ai pas vérifié le schéma réel** des quatre tables (colonnes,
  contraintes, RLS) — seulement ce que l'app leur envoie.
- **Les chiffres de la maquette sont plausibles, pas mesurés** sur la base.
