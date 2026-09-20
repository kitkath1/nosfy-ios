# La Route : deux séances par jour, pas trois — analyse, rien n'est codé

*20-09-2026 · sur son mot : « fais une règle backend aussi, le maximum dans la
route de galets = 2 sessions par jour, pour pas tricher et avoir trop de
boosters ; et dans le front : quand on clique encore sur un jour, le galet déjà
fait se montre « une séance faite », la pop-up duo dit « Lancer une deuxième
séance aujourd'hui ? », et une fois faites, pop-up erreur : pas d'autre séance,
attendez demain. Ne code pas, analyse, et coordonne-toi : un fix est sur la
page Route dans l'autre session. »*

---

## 0. Ce qu'elle veut, en une phrase

Une journée vaut **au plus deux galets** (donc au plus deux pas vers les lunes
et le trésor) ; la deuxième séance du jour est **annoncée** comme telle avant de
partir ; la troisième est **refusée** avec un mot clair — et c'est le **serveur**
qui tient la règle, pour qu'aucun téléphone ne puisse la contourner.

---

## 1. Ce qui existe aujourd'hui — lu au site et dans le code, pas déduit

| brique | où | état |
|---|---|---|
| **Un galet par séance terminée avec travail** (règle du 18-09) | téléphone : `Workout.faitPourRoute` (Models.swift:401-405) · serveur : `seances_chemin()` (20260918083033:115-126) | 🟢 `b-route-jour` — « deux séances le même jour restent deux séances » (DuolinguoPage.swift:280-281). **Aucun plafond nulle part.** |
| **Les lunes 3/7 et le trésor à 35** sont gardés par le NOMBRE de séances de `seances_chemin()` | `tirer_noeud_chemin` (20260918083033:141-145) → `409 progression_insuffisante` | 🟢 `b-fn-tirer-noeud-chemin` — un plafond posé DANS `seances_chemin()` protège les lunes tout seul |
| **Les boosters viennent AUSSI des pièces** : 100 pièces = 1 sachet (`prix_booster` = 100, solde modulo 100) ; les pièces sont payées à la clôture de CHAQUE séance | `cloturer_seance` → `cloturer_seance_validee_interne` ; `etat_coffre().reste` | 🟢 — ⚠️ une troisième séance que la Route ignore **donne quand même des sachets par ses pièces** : plafonner la Route seule ne ferme pas la triche qu'elle nomme |
| **Le « ×2 » existe déjà** : fait serveur `double_jour` (toute séance finie, même vide, jour **Europe/Paris**, un seul par jour), page ×2 de la story, sticker `sticker-fois2` | 20260915120000:163-179 · StorySuite.swift:2755 | 🟢 story · ⚪ jamais posé sur un galet (plan TestFlight § 2.4) |
| **Le jour** | Route et widget = jour **local** du téléphone · serveur = **Europe/Paris** · l'app n'envoie **aucun fuseau** (SupabaseSync, ProfilServeur : rien) | trois définitions coexistent (plan TestFlight § 2.4, décision § 9.3) |
| **La pop-up « duo »** = `PanneauDepartChemin` : « Today's session · Start · Later » sur le galet actif, « Session done · View · Later » sur un galet fait | DuolinguoPage.swift:1396-1466 | tout en **anglais** (règle du 28-08 : une seule coque, jamais moitié-moitié) |
| **Le départ d'une séance** passe par UNE porte : `NosfyApp.startWorkout()` (home, Route via `onDemarrer`, exercices) ; une séance déjà ouverte est RAMENÉE, jamais doublée | NosfyApp.swift:1037-1048 | le bon endroit pour dire « demain » à toutes les portes |
| **Séances vides** (finies sans travail) | ne font ni galet ni pièce (`faitPourRoute`, `seances_chemin`) — sauf pour `double_jour` | plan TestFlight § 2.3, à trancher |

---

## 2. La coordination — ce que l'autre session tient, et ce que ça impose

La session **« retours TestFlight du 19-09 »** (MULTI-SESSION.md, plan
`tools/production/PLAN-DEBUG-TESTFLIGHT-2026-09-20.md`) a, dans l'arbre, non
commité :

- **une migration qui redéfinit `seances_chemin()`**
  (`supabase/migrations/20260920120000_seances_chemin_kind_telephone.sql`) : le
  serveur comptait un galet HIIT sur `kind='effort'`, une valeur que le téléphone
  n'envoie jamais → une séance 100 % HIIT n'avançait jamais la Route au serveur ;
- **`DuolinguoPage.swift`** en cours d'édition (« View » ouvre la story de la
  séance, la coque du panneau ferme au tap) ;
- le § 2 de son plan porte **exactement les mêmes objets** que cette règle : le
  chiffre du galet (date ≠ rang, décision 1), le **×2 sur le 2e galet du jour**
  (décision 2), **la définition du jour** et les séances vides (décision 3).

**Ce que ça impose, sans discussion :**

1. Le plafond s'écrit dans **une migration séparée, datée APRÈS `20260920120000`**,
   en `create or replace` de **leur** version de `seances_chemin()` (la
   définition « Sprint / Accélération ») — jamais en parallèle sur la même
   fonction, sinon la dernière posée efface l'autre.
2. **Une seule session touche `DuolinguoPage.swift` et `GaletEtape.swift`** : les
   états du galet (fait / ×2 / verrouillé jusqu'à demain) et le panneau sont dans
   leurs mains tant que leur chantier est ouvert. Ce plan leur donne les textes
   et les états ; il ne les code pas.
3. La **définition du jour** doit être tranchée UNE fois pour trois choses à la
   fois : le plafond, le ×2 (`double_jour`) et le chiffre du galet.

Proposition de partage (à elle de dire) : la session Route prend tout le front
(galets, panneau, card Route de la Home) ; le serveur (migration + banc + site)
peut être pris par n'importe laquelle des deux, **après** leur migration.

---

## 3. La règle serveur — la vraie garde

### 3.1 Où elle vit

- **`reward_rules` : `chemin_seances_par_jour_max = 2`** — une règle du jeu, la
  même pour tout le monde (pas `user_prefs`). Lue par la fonction ; relue par
  l'app pour COMPARER à sa constante, comme `chemin_chapitres`.
- **`seances_chemin()`** : garde, par jour, les **deux premières** séances avec
  travail (ordre `ended_at`, puis `id` pour figer les égalités) ; les suivantes
  restent des séances (historique, stats, story), mais **n'existent pas pour la
  Route**. Comme `tirer_noeud_chemin` compte `seances_chemin()`, les lunes 3/7 et
  le trésor à 35 sont protégés sans une ligne de plus.
- **`cloturer_seance`** — voir la décision 3 : si la troisième séance ne doit
  **rien** rapporter (recommandé), la clôture rend `{ok:true, plafond_jour:true,
  pieces:0, booster_neuf:false}` : la séance est gardée, rien n'est crédité,
  et le rejeu rend le stocké (idempotence par index, comme aujourd'hui).

### 3.2 Le jour — la décision qui conditionne tout

| option | ce qu'elle voit | ce que ça demande |
|---|---|---|
| **A — le jour local du téléphone, porté par la séance** (recommandé) | « attendez demain » = SON minuit, à Paris comme en voyage ; la Route, le widget et le serveur disent la même chose | une colonne `workouts.fuseau text` (identifiant IANA, ex. `Europe/Paris`), envoyée par `synchroniser_seance` ; défaut `Europe/Paris` pour l'historique ; `double_jour` réaligné dessus |
| B — Europe/Paris partout | simple ; faux dès qu'elle voyage (une séance à 23 h à New York compte « demain ») | rien à envoyer ; la Route du téléphone doit alors compter en Europe/Paris aussi |
| C — le fuseau du profil (`profils.fuseau`, posé au lancement) | juste au quotidien ; une séance faite la veille d'un déplacement peut changer de jour après coup | une colonne + un appel au lancement |

Le jour de rattachement d'une séance est celui de sa **fin** (`ended_at`) — la
même règle que le galet aujourd'hui (le galet porte le jour de la fin).

### 3.3 Ce qu'il ne faut pas rater

- **Une resynchronisation tardive** (l'outbox, une séance restée sur le
  téléphone) peut faire entrer une séance PLUS ANCIENNE dans les deux premières
  du jour et en faire sortir une autre : les galets ne changent pas de nombre,
  mais une lune déjà réclamée sur l'ancien compte ne se reprend pas (« un ancien
  claim reste rejouable ; aucun nouveau droit n'est inventé »). Acceptable, à
  écrire noir sur blanc dans la fonction.
- **Le serveur gagne** : si l'heure du téléphone est trafiquée, la Route locale
  peut montrer trois galets un jour ; à la prochaine lecture serveur
  (`seances_chemin` / le pull) elle en remontre deux. La Route doit relire le
  serveur en apparaissant, comme la home relit le prénom.
- **Les séances vides ne consomment pas le quota** (elles ne font pas de galet) :
  deux séances vides ne bloquent pas la journée ; deux vraies + dix vides = deux
  galets, zéro effet. Aligner `double_jour` sur « avec travail » évite qu'une
  séance vide déclenche le ×2 (§ 2.4 du plan TestFlight, constaté le 19-09).
- **Le plafond ne rétroagit pas** sur l'historique réel de Kathryn (deux « 18 »
  puis des « 19 ») : elle a déjà des journées à deux séances, jamais à trois.
  Vérifier en lecture seule avant la pose (comme `verif_faits`).

---

## 4. Le front — les états, tels qu'elle les a décrits

Le compte du jour, côté téléphone : `seancesFinies` du jour local, filtrées
`faitPourRoute` — la même lecture que `EcranSpec.etapeEtFaits` (DuolinguoPage.swift:283-294),
qui reçoit un `maxParJour: 2` et ignore la 3e du jour. Et la vérité serveur
au-dessus (§ 3.3).

| aujourd'hui | le galet fait | le galet actif (le suivant) | la pop-up « duo » | ailleurs |
|---|---|---|---|---|
| **0 séance** | — | comme aujourd'hui : halo « Today » | « Today's session · Start · Later » | inchangé |
| **1 séance faite** | sceau « une séance faite » (l'état actuel), sans ×2 | ouvert, halo | **« Start a second session today? »** — CTA « Start » (FR si `L()` : « Lancer une deuxième séance aujourd'hui ? ») | inchangé |
| **2 séances faites** | le 2e porte le **×2** (`sticker-fois2`, décision 2 du plan TestFlight) | **verrouillé jusqu'à demain** : pas de halo, un cadenas ou une lune qui dort | **la pop-up d'erreur** : « That's your two sessions for today — come back tomorrow! » (FR : « Deux séances aujourd'hui, c'est le maximum — revenez demain ! »), un seul bouton « OK / Close », pas de « Start » | la card Route de la Home dit « demain » ; `startWorkout()` refuse avec le même mot (recommandé, décision 2) |

Détails qui comptent :

- **La langue** : le panneau est tout en anglais par règle du 28-08 ; sa règle
  du 20-09 sur la sortie de Nosfy (« tout en anglais sauf le bouton ») va dans
  le même sens. Décision 4 du plan TestFlight (« View » / `L()`) : la même pour
  ces deux textes.
- **Minuit, app ouverte** : la Route relit la date à l'apparition et sur
  `NSCalendarDayChanged` — sinon le cadenas reste après minuit.
- **Une séance en cours à minuit** : comptée au jour de sa fin — le téléphone et
  le serveur disent pareil.
- **Hors ligne** : le téléphone applique la règle seul (elle est locale et
  déterministe) ; à la synchro le serveur tranche.
- **Aucune horloge** : ce sont des états, pas des animations — rien à mesurer
  côté chauffe. Le ×2 et le cadenas sont des images posées.

---

## 5. Les bancs — ce qui prouvera la règle

- `tools/duolingo/verif_route_vide.py` (le banc de la Route, 2 × 1 277
  assertions Swift + 35 API) : ajouter **trois séances avec travail le même
  jour local** → 2 galets, le 2e ×2, le 3e refusé ; **deux vides + une vraie** →
  1 galet ; **23 h 50 → 0 h 10** → deux jours ; rejeu idempotent.
- `verif_gains_progression` (API) : 7 séances en 3 jours → la lune du rang 7
  refuse tant qu'un 4e jour n'a pas eu lieu (`progression_insuffisante`) ;
  3e séance du jour → clôture `plafond_jour`, solde inchangé, `etat_coffre().reste`
  inchangé.
- Sur **son téléphone** : deux séances réelles puis la tentative d'une
  troisième, dans les deux langues — et le passage de minuit.

---

## 6. La doc, dans le même commit que la migration

- `serveur.ts` : la règle `b-rg-chemin-seances-par-jour-max` (⚪ tant qu'elle
  n'est pas posée, 🟢 après mesure), la note de `b-fn-seances-chemin`
  (« deux premières du jour »), la colonne `workouts.fuseau` si A, la clôture
  `plafond_jour`.
- `briques.ts` : `b-route-jour` (« un galet par séance, **deux par jour au
  plus** »), une brique pour la pop-up d'erreur et la promesse « deuxième
  séance ».
- `qa.ts` : une étape « la troisième séance du jour est refusée ».

---

## 7. Ses décisions (une ligne chacune)

1. **Le jour** : local du téléphone porté par la séance (A, recommandé), Paris
   (B), ou le fuseau du profil (C).
2. **La troisième séance** : **refusée à toutes les portes** (Home, Route,
   Exercices — recommandé : un seul message, aucune séance fantôme) ou seulement
   « pas comptée » (elle existe, la Route l'ignore).
3. **Ses pièces** : la troisième séance **ne rapporte rien** (recommandé — sinon
   100 pièces = 1 sachet, la triche reste ouverte), ou paie ses pièces sans galet.
4. **Les textes** : anglais partout (règle du 28-08) ou `L()` — la même réponse
   que pour « View ».
5. **Qui code quoi** : le front de la Route reste à la session retours
   TestFlight ; le serveur après leur migration `20260920120000`.

## 8. Ordre conseillé

1. Ses cinq décisions (§ 7) — le jour d'abord, tout en dépend.
2. La session Route pose et mesure sa migration `seances_chemin` (kind).
3. La migration du plafond (règle + fonction + clôture + fuseau si A), le banc
   API, lecture seule sur les comptes réels avant la pose.
4. Le front (états, ×2, cadenas, textes) chez la session Route, avec la même
   lecture locale ; `startWorkout()` refuse si décision 2.
5. Le site, l'étape QA, puis son téléphone : deux séances, la troisième, minuit.
