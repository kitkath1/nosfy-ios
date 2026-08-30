# AUDIT — LE CHEMIN, LE CALENDRIER ET LES STORIES DISENT-ILS LA MÊME CHOSE ?

**29-08.** Sa question : « t'es sûr que le chemin est bien clair, que tu l'as
bien compris, et qu'il est sync avec le calendrier aussi ? Et quid des
stories ? »

> **Convention.** Ce qui porte une référence `fichier:ligne` est **vérifié dans
> le code**. Ce qui porte une réponse HTTP est **sondé sur le vrai serveur**,
> avec un témoin qui échoue. Le reste porte **?** et attend une décision.

---

## 0 · La réponse courte

Les trois écrans racontent la même chose — « ce que tu as fait » — et **ils
lisent bien la même table** (`Workout`, en SwiftData). Mais ils n'en tirent pas
le même récit, et j'ai trouvé **trois désaccords réels**, dont deux sont des
désaccords de DÉFINITION — le genre que ce dépôt a déjà payé une fois (quatre
formules rendaient trois nombres différents parce que « série enregistrée » et
« série faite » n'étaient pas la même chose).

| # | Désaccord | Gravité |
|---|---|---|
| 1 | **Le jour d'une séance** : le calendrier compte `startedAt`, le chemin `endedAt` | une séance à cheval sur minuit tombe sur **deux jours différents** selon l'écran |
| 2 | **Le sticker** : la home le choisit par un modulo, le panneau de la route l'a **en dur** | le même jour porte **deux stickers différents** |
| 3 | **Le modèle** : le chemin est un CALENDRIER (1 nœud = 1 JOUR), le calendrier est une LISTE de séances | un jour de repos consomme un nœud → le chemin s'épuise en 45 jours |

Et une absence, qui n'est pas un désaccord mais un trou : **les stories ne se
choisissent pas** — il n'existe aucun moteur de faits, ni dans l'app ni en base.

---

## 1 · Ce que chaque écran lit, exactement

| Écran | Source | Ce qu'il en fait |
|---|---|---|
| **Calendrier** (`CalendarView.swift:14`) | `@Query Workout` | `finished = workouts.filter { !$0.isActive }` (`:24`), groupé par `startOfDay(startedAt)` (`:28`) |
| **Chemin** (`HomeNuit.swift:3776`) | les mêmes `Workout` | `EcranSpec.etapeEtFaits(seancesFinies:)` sur les `endedAt` |
| **Card ROUTE** (home) | la même lecture que le chemin | `EcranSpec.Lecture` + `apercu` |
| **Stories** (`CalLab.swift:360`) | une `StorySession` construite **par le calendrier** | `CalStoryLaunch(rect:session:)` |

**Le prédicat « terminée » est le MÊME des deux côtés** — `isActive` vaut
`endedAt == nil` (`Models.swift:332`), donc `!isActive` et `endedAt != nil`
disent bien la même chose. C'est la seule bonne nouvelle de cet audit, et elle
mérite d'être dite : **il n'y a pas deux définitions de « séance finie ».**

---

## 2 · Désaccord n° 1 — LE JOUR D'UNE SÉANCE

- le **calendrier** range une séance au jour où elle a **commencé**
  (`CalendarView.swift:28` : `startOfDay(for: $0.startedAt)`) ;
- le **chemin** estampille un nœud fait avec la date où elle s'est **terminée**
  (`etapeEtFaits` range `dates[i] = brut`, où `brut` est un `endedAt`).

**Conséquence, et elle est réelle** : une séance commencée à 23 h 40 et finie à
0 h 20 apparaît **le lundi sur le calendrier et le mardi sur le chemin**. Deux
écrans, deux vérités, sur la même séance.

**? À trancher** : lequel fait foi. Mon avis, et il n'engage que moi : le jour
**de fin**, parce que c'est ce que le chemin promet par ailleurs (« les jours
apparaissent le jour où le user a TERMINÉ sa séance ») et parce que c'est
l'instant qui paie. Mais c'est une règle de jeu, pas une décision technique.

---

## 3 · Désaccord n° 2 — LE STICKER

- la home et le calendrier : `stickers[i % 7]` (`HomeNuit.swift:1567`) — l'index
  du jour dans la semaine, aucune séance ne le décide ;
- le panneau de la route : `SemaineStrip.sticker(1)` (`DuolinguoPage.swift:2242`)
  — **le 1 est écrit en dur**, donc c'est toujours la flamme.

Le commentaire du code dit pourtant, mot pour mot, que le parcours doit
« RÉEMPLOYER cette card, pas l'imiter — vraie mini-card, vraie date, vrai
sticker ». La card est bien réemployée ; **le sticker, lui, est faux**.

**Sondé côté serveur** : `workouts?select=sticker` → **400**
(`column workouts.sticker does not exist`), témoin `colonne_bidon` → 400 aussi.
Il n'existe donc **aucune source** de sticker, nulle part. Ce n'est pas un
branchement à faire : c'est une donnée à inventer.

**? À trancher** : ce qui décide d'un sticker (le type de séance ? le muscle ?
un tirage stable par jour ?). Tant que ce n'est pas décidé, le seul correctif
honnête est de faire lire **la même fonction** aux deux écrans, pour qu'ils
mentent au moins **de la même façon**.

---

## 4 · Désaccord n° 3 — LE MODÈLE LUI-MÊME

Le chemin est **un calendrier déguisé en carte** : un rang vaut un JOUR
(`etapeEtFaits` : `rang(d) = jours entre la première séance et d`). Donc :

- un jour de repos **consomme un nœud** ;
- 45 nœuds = **45 jours**, pas 45 séances ;
- avec une base qui contient des séances vieilles de plusieurs semaines, la
  dérivation réelle tombe au **chapitre 5, tout allumé** — c'est écrit dans le
  code, et c'est la raison pour laquelle le mode DÉMO est le défaut.

Le calendrier, lui, n'a pas ce problème : il n'a pas de progression, il a des
dates.

**C'est LE blocage du chemin**, déjà nommé au § 8 de sa fiche : *où commence un
chapitre*. Deux familles de réponses, et elles ne coûtent pas la même chose :

| Réponse | Ce que ça change | Coût |
|---|---|---|
| **un nœud = une SÉANCE** (les jours de repos ne consomment rien) | le chemin devient une progression, plus un calendrier ; les dates restent des estampilles | une ligne dans `etapeEtFaits` — mais ça change ce que le chemin RACONTE |
| **un nœud = un JOUR, et le chapitre a une ORIGINE** (posée en base, glissante) | le chemin reste un calendrier, mais il ne part plus de la préhistoire | une colonne serveur + la dérivation |

**? Elle seule peut trancher** : est-ce que sauter un jour doit se VOIR sur le
chemin (aujourd'hui : oui, sous la forme d'une pierre `rate`), ou est-ce que le
chemin ne compte que ce qu'on a fait ?

---

## 5 · Les stories — ce n'est pas un désaccord, c'est un trou

- Une story ne se lance **que depuis le calendrier** (`CalLab.swift:360`), sur
  une `StorySession` que la page construit elle-même. Rien en fin de séance.
- Le choix d'un variant : **aucun moteur**. Le site le dit déjà (« le moteur de
  faits n'existe pas — deux variants sont inatteignables »), et la sonde le
  confirme : `workout_facts` → **404**, la table n'existe pas.
- Donc les variants « TOP SESSION », « ×2 », les records… sont peints et
  inatteignables, faute de quelqu'un pour dire *ce que cette séance a été*.

**Le lien avec le chemin** : c'est le MÊME manque. Le chemin a besoin de savoir
« ce jour-là a été fait », les stories de savoir « ce jour-là a été un record » —
les deux sont des **faits** dérivés des mêmes séances, et personne ne les
calcule ni ne les range.

---

## 6 · Ce que le serveur sait déjà — sondé, pas supposé

| Sonde | Réponse | Ce que ça prouve |
|---|---|---|
| `workouts?select=id,started_at,ended_at` | **200** | les séances et leurs deux dates sont en base |
| `logged_exercises` · `strength_sets` · `cardio_phases` | **200** | de quoi reconstruire calendrier, volumes et cardio |
| `workouts?select=colonne_bidon` | **400** | le témoin : la sonde sait échouer |
| `workouts?select=sticker` | **400** | aucune source de sticker |
| `workout_facts` | **404** | aucun moteur de faits |
| `rpc/noeuds_chemin_reclames` | **200** | déployé le 29-08 (il rendait 404 avant) |
| `reward_rules` (clés `chemin_*`) | **5 lignes** | la composition d'un chapitre est en base |

⚠️ **`SupabaseSync` n'a qu'un `push`** — pas une ligne de lecture. Les trois
écrans dérivent donc de SwiftData, et à la réinstallation l'app repart vide
**devant un serveur plein**. Ce n'est pas trois chantiers, c'en est **un**.

---

## 7 · L'ordre que je propose

Rien de tout ça ne demande une migration. Dans cet ordre, chaque étape est
visible et réversible :

1. **Une seule définition du jour d'une séance** (§ 2) — une fonction, lue par
   le calendrier ET par le chemin. C'est la moins chère et elle tue un mensonge.
2. **Un seul choix de sticker** (§ 3) — même fonction des deux côtés, même faux
   sticker partout, en attendant qu'il ait une source.
3. **La lecture qui manque** (§ 6) — le `select` sur `workouts`, qui rend au
   calendrier et au chemin leur mémoire après une réinstallation.
4. **Le modèle du chemin** (§ 4) — sa décision à elle, et tout le reste en
   dépend.
5. **Le moteur de faits** (§ 5) — le plus gros, et il débloque les stories.

**Rien n'est codé de tout ça.** Ce document est l'analyse qui précède.
