# L'ÉCONOMIE DU CARDIO — ce qu'une séance HIIT, escalier, tapis ou piscine rapporte

**Proposition du 15-09-2026** (session woochoper-ios-41), sur ses mots :

> *« Une séance cardio vaut des pièces à juger selon l'intensité : si HIIT, selon
> l'intensité (km/h entre 15 et 17, voire plus), selon le temps fait, le nombre de
> reps/séries, le nombre de repos et le temps — entre 100 et 300 pièces car très
> dur ! À toi d'estimer : si le user fait de longs intervalles de plus d'une minute
> et moins de repos, ou inversement de longues courses à 15 km/h, tu récompenses —
> et c'est là que l'IA intervient pour les récompenses. Il faut mettre tout ça dans
> Supabase, et la documentation, très important. Escalier pareil : selon le temps
> (10 ou 20 min à intensité 7 ou 10, c'est pas pareil), entre 50 et 100 pièces.
> Piscine : 1 longueur = 20 pièces, ok. Propose-moi quelque chose, ne code pas
> encore. Le repos écrit comme un segment, c'est important : si je cours à 15 km/h
> 30 secondes et que je repasse 1 minute à 9 km/h, il faut le noter — c'est lié au
> graphe. Escalier pas en mode sprint. Finish dans le double galet termine
> l'exercice, pas la séance. »*

**Rien n'est codé, rien n'est en base.** Ce fichier est la proposition à valider ;
le chantier lui-même est `PLAN-CARDIO.md` (même dossier).

---

## 1. LE PRINCIPE, EN QUATRE PHRASES

1. **C'est le serveur qui compte, jamais le téléphone.** Il a déjà toutes les
   phases de la séance (elles sont poussées AVANT la clôture, dans la même tâche —
   `WoopApp.swift:611-614`) ; le téléphone ne lui envoie aucun montant. Une séance
   rejouée dix fois paie une fois (le même index unique qu'aujourd'hui).
2. **Chaque chiffre du barème est une ligne de la table des règles**
   (`reward_rules`), lisible et changeable à la main sans toucher au code — comme
   `pieces_par_serie = 20` aujourd'hui. Tu veux que 17 km/h paie plus ? Une ligne.
3. **Le barème est DÉTERMINISTE** : deux séances identiques rapportent la même
   somme, et une séance se réexplique toujours (« 12 min d'effort à 17 km/h : 90,
   récups courtes : +40 »). C'est ce qui rend l'argent testable, et ce qui empêche
   « ça ment ».
4. **L'IA n'invente pas un montant : elle RACONTE la récompense** (les mots de la
   story et de la pop-up, dans ta langue) et, si tu le veux, elle choisit UN bonus
   borné parmi ceux qui existent déjà en base. Le détail et l'alternative sont au §5.

---

## 2. LE BARÈME — exercice par exercice, avec des exemples

Tous les noms de clés sont ceux qui iront dans `reward_rules`. Les valeurs sont MES
propositions, à partir de tes fourchettes ; tu les changes d'un mot.

### 2.1 Le HIIT sur tapis — entre 100 et 300

Ce que le serveur lit : les segments de la séance pour cet exercice (`cardio_phases`
de `hiit-tapis`). Un **effort** = un segment à `seuil_effort_kmh` (15,0) ou plus — la
définition déjà en base depuis le 05-09. Une **récup** = un segment en dessous (ton
exemple : 1 min à 9 km/h).

| composante | règle | clé(s) | plafond |
|---|---|---|---|
| **la base** — une séance HIIT, c'est dur | 100 dès qu'il y a au moins un effort d'au moins 20 s | `cardio_hiit_base` 100 · `cardio_hiit_effort_min_s` 20 | — |
| **le temps sous effort, pondéré par la vitesse** | 5 pièces par minute d'effort ; la minute vaut ×1 de 15 à 17 km/h, ×1,5 de 17 à 19, ×2 à partir de 19 | `cardio_hiit_pieces_par_minute` 5 · `cardio_hiit_palier2_kmh` 17 · `cardio_hiit_mult2` 1.5 · `cardio_hiit_palier3_kmh` 19 · `cardio_hiit_mult3` 2 | `cardio_hiit_temps_max` 120 |
| **la densité** — moins de repos que d'effort | +40 si le temps d'effort fait au moins la moitié du total (effort + récup) | `cardio_hiit_bonus_densite` 40 · `cardio_hiit_densite_min` 0.5 | — |
| **les longs intervalles** | +40 s'il y a au moins 3 efforts d'au moins 60 s | `cardio_hiit_bonus_longs` 40 · `cardio_hiit_longs_min` 3 · `cardio_hiit_long_s` 60 | — |
| **le total** | base + temps + densité + longs | `cardio_hiit_max` 300 | 300 |

**Ce que ça donne** (calculé à la main, à vérifier par le script au J6) :

| la séance | temps pondéré | densité | longs | **pièces** |
|---|---|---|---|---|
| ton exemple ×12 : 30 s à 15, 1 min à 9 | 6 min × 5 × 1 = 30 | 0,33 → 0 | 0 | **130** |
| 10 × 1 min à 17, 1 min de récup | 10 × 5 × 1,5 = 75 | 0,50 → +40 | 10 → +40 | **255** |
| 8 × 1:30 à 17, 45 s de récup | 12 × 5 × 1,5 = 90 | 0,67 → +40 | 8 → +40 | **270** |
| 6 sprints de 20 s à 19, 40 s de récup | 2 × 5 × 2 = 20 | 0,33 → 0 | 0 | **120** |
| une longue course : 20 min à 15 d'un trait | 20 × 5 = 100 | 1,00 → +40 | 1 seul → 0 | **240** |
| 30 min à 15 d'un trait | 150 → plafond 120 | +40 | 0 | **260** |
| 5 min à 12 km/h (jamais au-dessus de 15) | aucun effort | — | — | **45** — payée comme un tapis modéré (§2.3 : 30 + 5 × 12 / 4) |

*(15-09, à la pose par la session back-end : la pièce de temps HIIT est ARRONDIE
(`round`), pas tronquée — « 6 sprints de 20 s à 19 » rend bien 120 et non 119 ;
la ligne « 5 min à 12 » disait « 0 » par erreur, c'est 45. Tout le reste est posé
tel quel et vérifié : `tools/serveur/verif_cardio.py`, 22 ✓.)*

Le HIIT reste la séance la mieux payée de l'app : une muscu à 15 séries fait 300, un
HIIT dur aussi. Les sprints courts à 19 paient peu (120) parce que le TEMPS pèse —
tu as dit « selon le temps fait » ; si tu veux que la vitesse pèse plus que le
temps, c'est `cardio_hiit_mult3` (2 → 3) ou `cardio_hiit_pieces_par_minute`.

### 2.2 L'escalier — entre 50 et 100

Ce que le serveur lit : les segments MONTÉS (`speed` > 0, c'est le niveau de la
machine 1-15) ; les repos ne comptent pas dans les minutes. Jamais un sprint, jamais
dans le widget HIIT (fait ce matin par la session back-end).

| règle | clé(s) |
|---|---|
| en dessous de 5 min montées : rien | `cardio_escalier_min_minutes` 5 |
| **50 + (minutes montées × niveau moyen) / 4**, plafond 100 | `cardio_escalier_base` 50 · `cardio_escalier_diviseur` 4 · `cardio_escalier_max` 100 |

| la séance | calcul | **pièces** |
|---|---|---|
| 10 min au niveau 7 | 50 + 70/4 | **67** |
| 20 min au niveau 7 | 50 + 140/4 | **85** |
| 10 min au niveau 10 | 50 + 100/4 | **75** |
| 20 min au niveau 10 | 50 + 200/4 → plafond | **100** |
| 30 min au niveau 5 | 50 + 150/4 | **87** |

Le niveau moyen est pondéré par le temps (10 min à 5 puis 10 min à 10 = 7,5).

### 2.3 Le tapis à allure modérée — tu n'as rien dit : je propose entre 30 et 100

Même forme que l'escalier, avec les km/h : **30 + (minutes × km/h moyens) / 4**,
plafond 100, rien sous 5 min (`cardio_tapis_base` 30 · `cardio_tapis_diviseur` 4 ·
`cardio_tapis_max` 100 · `cardio_tapis_min_minutes` 5). 20 min à 6 km/h → 60 ;
30 min à 8 → 90 ; 45 min à 8 → 100. Un tapis modéré poussé à 15 km/h ou plus compte
AUSSI comme un effort dans le widget HIIT (la définition), mais il est PAYÉ par ce
barème-ci, pas par celui du HIIT — un exercice, un barème. **À trancher (Q12).**

### 2.4 La piscine — 20 pièces la longueur

`pieces_par_longueur` 20, comme tu l'as dit. **Deux choses à regarder avant de
valider :**
- 40 longueurs (1 km) = **800 pièces = 8 sachets**, là où le HIIT le plus dur fait
  300. Je propose un plafond `cardio_piscine_max` = **300** pour que le HIIT reste
  la séance reine — ou pas de plafond, à toi de dire (Q13).
- une longueur de 50 m vaut-elle la même chose qu'une de 25 m ? Aujourd'hui « 1
  longueur = 20 » quel que soit X mètres. L'alternative : 20 pièces par 25 m
  (`pieces_par_25m`), donc 40 pour une longueur de 50 m (Q13).

### 2.5 Une séance mixte, et le sachet

- **Muscu + cardio** : les séries × 20 (comme aujourd'hui, ligne `serie_faite`) **+**
  le barème de chaque exercice cardio (une seule ligne `cardio_seance` par séance,
  la somme). Deux exercices cardio dans la même séance = deux barèmes additionnés.
- **Le sachet de fin de séance** reste forfaitaire, UN par séance — aujourd'hui il
  exige au moins une série (`gains_coffre.sql:217-218`). Demain : au moins une série
  OU au moins une pièce cardio. Une séance vide ne paie toujours rien.
- **La pièce d'argent** (1 chance sur 30 à la clôture) : inchangée, elle joue dès
  que la clôture paie quelque chose.
- **La conversion 100 pièces → un sachet** : automatique, par le déclencheur qui
  existe (`coin_ledger_convertir`) — un HIIT à 270 donne donc 2 sachets convertis +
  70 de reste, exactement comme 14 séries de muscu. Rien à écrire.

---

## 3. CE QUE TU VERRAS À L'ÉCRAN

- **Pendant le HIIT** : au tap stop, la dalle « SET 3 END · 1:30 · 17 km/h » —
  **sans « +20 »** (un intervalle ne paie plus à la pièce : c'est la séance qui est
  jugée). La pop-up flammes encourage (« ON FIRE », 3 SETS), sans montant.
- **À la fin de l'exercice** (Finish) : la fiche revient avec le graphe des
  segments (efforts en braise, récups en graphite).
- **À la fin de la séance** (le stop de la dalle, comme partout) : la story puis la
  pile d'annonces — les pièces de muscu tout de suite (le téléphone les connaît),
  **les pièces cardio quand le serveur répond** (une seconde plus tard, dans la même
  pile — c'est déjà comme ça que l'argent et les sachets convertis arrivent,
  b-flow-deux-annonces), avec la phrase de l'IA si tu la veux (§5) : « 8 efforts à
  17 km/h, des récups courtes : 270 pièces ».
- **Hors ligne** : la séance est dans la file d'attente (l'outbox), les pièces cardio
  arrivent au prochain lancement connecté — rien ne se perd, rien ne se double.
- **Le coffre et le profil** : le solde vient du serveur, comme aujourd'hui ; la page
  des gains (le carnet) montre une ligne « HIIT · 270 » au lieu de « séries × 20 »
  (c'est `historique_gains`, il rend déjà chaque ligne du carnet avec sa raison).

---

## 4. LE SERVEUR — ce qui s'écrit (pour la session back-end, à son go)

Une migration, **`20260915160000_economie_cardio.sql`** (la session back-end a pris
`150000` ce matin) :

1. **Les règles** — les ~20 clés du §2 en `insert … on conflict do nothing` dans
   `reward_rules` (le même geste que `seuil_effort_kmh`). `regles_annonces()` les
   rendra à l'app avec les autres (elle rend tout sauf `rare_*`).
2. **La raison** — `coin_ledger_raison_check` recopiée depuis **la liste VIVANTE**
   (confirmée par la session back-end le 15-09 par `pg_get_constraintdef`, égale à
   `gains_coffre.sql:46-53` : serie_faite · ouverture_booster · doublon · cadeau ·
   annulation · piece_argent · ouverture_booster_noir · conversion_booster ·
   retour_quotidien · chemin) **+ `cardio_seance`**. Le piège n° 1 du skill : ce
   qu'on oublie de recopier devient interdit, et une ligne existante qui le porte
   rend la migration **impossible à poser** — relire la vivante juste avant.
3. **L'idempotence** — RIEN à créer : l'index partiel `coin_ledger_gain_unique
   (user_id, raison, workout_id) where workout_id is not null` (`booster_noir.sql:94`,
   vivant : pkey · user_idx · gain_unique · chemin_unique · retour_jour_unique) ne
   tolère déjà qu'UNE ligne par (raison, séance). Une ligne `cardio_seance` par
   séance, un rejeu rend `unique_violation` → « déjà payé », jamais une erreur.
4. **La fonction de calcul** — `pieces_cardio_seance(p_workout uuid) returns jsonb`,
   `security definer`, filtre `auth.uid()` elle-même (la leçon d'`effort_seance`),
   `stable`, grantée à `authenticated` : elle lit `logged_exercises` (par
   `exercise_id`, le nom du catalogue) → `cardio_phases` (efforts = `speed >=
   seuil_effort_kmh`, récups en dessous ; l'escalier = tout ce qui monte) et
   `piscine_longueurs`, applique le §2 via `regle_num(clé, défaut)`, et rend
   `{total, exercices: [{exercice_id, pieces, detail: {efforts, minutes_effort,
   temps_pondere, densite, longs, …}}]}`. **Appelable seule** : l'app pourra montrer
   une estimation avant Finish si un jour on le veut, et le script de vérification
   la sonde directement.
5. **La clôture** — `create or replace` de **l'enveloppe `cloturer_seance` SEULE**
   (`20260915120000`) ; `cloturer_seance_brut` ne bouge pas. Dans l'enveloppe, **APRÈS**
   `_brut` (l'ordre compte : le déclencheur de conversion par 100 doit voir le
   total) : `v_cardio := pieces_cardio_seance(p_workout)` ; si `total > 0`, insert
   `coin_ledger (delta = total, raison 'cardio_seance', currency 'yellow',
   workout_id)` dans `begin … exception when unique_violation` → rejeu ; si
   `p_series = 0` et `total > 0`, le sachet forfaitaire que `_brut` n'a pas donné
   (insert `user_boosters` origine `seance`, `workout_id`, sous `unique_violation`
   aussi — index `user_boosters_seance_unique`) ; la réponse = `v_reponse ||
   {faits…} || {pieces_cardio, cardio_detail, pieces_total}` — les clés existantes
   restent, `SacreServeur.ClotureSeance` décode les siennes en optionnels, rien ne
   casse. Même signature, aucun appelant ne bouge.
6. **La piscine** — `piscine_longueurs` (voir `PLAN-CARDIO.md` §3.E) dans une
   migration à part, `20260915170000`, avec `seances_depuis` qui la rend.
7. **La vérification, avant toute pastille** — `tools/serveur/verif_cardio.py` sur le
   compte de test, à l'école de `verif_faits.py` : sème les sept séances du tableau
   §2.1 + trois escaliers + une piscine + une mixte + une vide, appelle
   `cloturer_seance` ×2 sur chacune, compare aux montants du tableau, vérifie le
   rejeu (même `booster_id`, `pieces_cardio` 0 au second appel, le solde ne bouge
   pas), le sachet sans série, `pieces_cardio_seance` sans jeton → 401, puis efface
   tout. **Tant que ce script n'est pas vert, aucune ligne du site n'est verte.**
8. **Les deux gardes de la session back-end, après la pose** : relancer
   `tools/serveur/verif_faits.py` (14 ✓) et `verif_portes.py` (34 ✓) — la clôture
   est dans les deux ; et le site (`serveur.ts` : b-fn-cloturer-seance, b-tb-coin-ledger,
   les nouvelles clés et la fonction, chacune avec sa preuve) **dans le même
   commit** — la carte du serveur est à 53/53 vert, elle ne doit pas mentir un jour.

**Ce qui ne bouge pas** : le schéma de `cardio_phases`, `CardioPhaseRow`,
`calculer_faits_seance`, les clés de `widget_hiit`, `pieces_par_serie`, la
conversion, la pièce d'argent, la garde `-demoData` de l'outbox.

---

## 5. L'IA — deux façons de la faire intervenir, et celle que je recommande

**Option A — l'IA RACONTE (recommandée).** Le barème décide du montant ; une edge
function (`narrate-cardio`, sur le modèle de `bilan-periode` : le jeton vérifié, la
langue de `profils.langue`, le cache dans une table `recits_seance` par séance,
`{phrase: null}` si rien à dire) reçoit le `cardio_detail` **du serveur** (jamais
un chiffre du téléphone) et écrit une phrase courte pour la story et la pop-up de fin
de séance : « 8 efforts à 17 km/h et des récups de 45 s : 270 pièces. » / « Une
vraie longue : 20 min sans descendre sous 15. » C'est exactement le contrat déjà
posé pour les mots géants (b-st-mots-geants : « les mots viennent du serveur, la
typo jamais ») et pour `narrate-reward` (J5 des annonces). Elle peut aussi nommer
**ce qui a fait la différence** (« tes récups sont plus courtes que la semaine
dernière »), parce que `calculer_faits_seance` lui donne `top_cardio` et que
`widget_hiit` lui donne la fenêtre d'avant.

**Option B — l'IA JUGE un bonus.** Le barème paie la base ; l'IA lit la séance et
choisit un bonus parmi les trois qui existent déjà en base depuis le 29-08
(`bonus_fort` 40, `bonus_progres` 30, `bonus_surprise` 20, plafond
`bonus_plafond_seance` 60), jamais un montant libre. **Pourquoi je ne la recommande
pas en premier** : deux séances identiques peuvent recevoir deux bonus différents
(« pourquoi lui 40 et moi 0 ? » — et un ledger ne se rembobine pas) ; ça ajoute 2 à
4 s et une clé d'API dans la clôture ; et une panne de l'IA devient une panne de
paie. Si tu la veux quand même, elle vit dans l'edge function de l'option A, après
la clôture, avec sa propre ligne `bonus_ia` idempotente par séance et le plafond
en base — la base ne dépend jamais d'elle.

**Option A' — le bonus est une RÈGLE, pas un avis** : `top_cardio` (le fait calculé
par le serveur : plus de temps au-dessus du seuil, ou vitesse × durée, que la
meilleure des 7 derniers jours) → `bonus_progres` 30, déterministe, une ligne de
plus dans la clôture. L'IA le raconte. C'est ce que je poserais.

---

## 6. LE CÔTÉ APP — petit, et c'est voulu

- `Workout.cardioFait: Bool` (au moins une phase faite ou une longueur) à côté de
  `seriesPayantes` ; les trois gardes deviennent « séries > 0 OU cardio fait »
  (`WoopApp.swift:582`, `SacreServeur.swift:360`, le trophée) ; `p_series` reste les
  séries de muscu seules.
- `SacreServeur.ClotureSeance` décode `pieces_cardio`, `cardio_detail`,
  `pieces_total` (en optionnels, comme `faits` le 15-09) ; la pile d'annonces reçoit
  une dalle « HIIT · +270 » quand la réponse arrive (le chemin de `argent` et
  `sachets_convertis`, déjà là).
- La StopCard et le Foyer affichent les séries de muscu ; pour une séance cardio
  ils disent « 3 intervalles » / « 20 longueurs » et **pas de montant avant la
  réponse** (le téléphone ne connaît pas le barème, et ne doit pas le connaître —
  sinon c'est une neuvième copie de règle).
- Aucun « +20 » sur la dalle du set ni sur la ligne d'intervalle de l'overlay ; la
  ligne de la piscine dit ses longueurs, le montant vient du carnet.

---

## 7. LA DOCUMENTATION — ce qui va sur le site, à quel moment, avec quelle preuve

| jalon | ligne du site (`docs/site/content/`) | état | preuve |
|---|---|---|---|
| **à ton go sur ce fichier** | `serveur.ts` : `b-rg-cardio-hiit` (les 11 clés), `b-rg-cardio-escalier`, `b-rg-cardio-tapis`, `b-rg-piscine` (`pieces_par_longueur`), `b-fn-pieces-cardio-seance`, `b-tb-piscine-longueurs` | ⚪ absent — « proposé le 15-09, à poser » | `{ fichier: tools/cardio/PLAN-ECONOMIE-CARDIO.md, lignes: § }` |
| migration posée, script rouge ou pas encore écrit | les mêmes | 🔵 serveur seul | `migration list` avant/après + `GET reward_rules?key=like.cardio_*` → les clés lues |
| `verif_cardio.py` vert | `b-fn-pieces-cardio-seance` 🟢, `b-fn-cloturer-seance` note « + `pieces_cardio` (15-09) », `b-tb-coin-ledger` note « raison `cardio_seance` » | 🟢 mesuré | la sonde : les 7 montants du §2.1 rendus par le serveur, le rejeu |
| l'app décode et affiche | `briques.ts` page flow : `b-flow-cardio-paie` (« la séance cardio paie, la dalle le dit ») | 🟢 | capture de la pile d'annonces avec « HIIT · +270 » sur le compte de test |
| piscine poussée et relue | `b-tb-piscine-longueurs` 🟢, `b-fn-seances-depuis` note | 🟢 | `count=exact` après push, `-pullNow` après désinstallation |
| l'IA raconte | `b-ed-narrate-cardio` (edge), `b-tb-recits-seance` | 🔵 → 🟢 | `POST /functions/v1/narrate-cardio` ×2 → la phrase puis `cache true` |
| la prose | `pages/coffre.mdx` : un paragraphe « ce qu'une séance cardio rapporte » avec le tableau du §2 en clair ; `pages/widgets.mdx` : les segments faits et les récups | — | — |

Chaque ligne part **dans le commit du changement** avec le livrable régénéré
(`npm run artefact` PUIS `npm run verif`), republié au même lien. Un état ne se
peint qu'après avoir été LU (la réponse du serveur, la capture) — jamais parce que
le code est écrit.

---

## 8. CE QUE JE TE DEMANDE (le reste est décidé par tes réponses d'aujourd'hui)

- **Q11 — les chiffres du §2.1** : les cinq exemples te paraissent-ils justes ? En
  particulier : les sprints courts à 19 km/h à 120, la longue course à 15 à 240.
- **Q12 — le tapis modéré** : 30 → 100 comme je propose, ou une autre fourchette ?
- **Q13 — la piscine** : un plafond à 300 par séance, ou pas de plafond ? 20 pièces
  par longueur quel que soit X mètres, ou 20 par 25 m ?
- **Q14 — l'IA** : A (elle raconte, le bonus est une règle sur `top_cardio`) — ma
  reco — ou B (elle choisit un bonus borné à 60) ?
- **Q15 — le double galet en récup** : au tap stop, le cadran passe sur la vitesse
  de RÉCUP (7 km/h la première fois, puis la dernière que tu as réglée) et l'encre
  dit « RÉCUP » ; au tap suivant il revient à ta vitesse d'effort. C'est ce qui
  permet d'écrire « 1 min à 9 km/h » sans que tu aies à baisser la vitesse à chaque
  repos — mais si tu la baisses, c'est ta valeur qui est écrite. OK ?

Dès ton go : les lignes ⚪ vont sur le site (avec ce fichier comme preuve), la
session back-end écrit la migration et le script, je fais le côté app — dans cet
ordre, et rien ne passe au vert sans la sonde.
