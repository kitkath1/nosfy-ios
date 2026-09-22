# Le nombre de séries par semaine et par mois — où le mettre, et comment (22-09)

**Demandé par Kathryn le 22-09-2026 :** « il faut mettre le nombre de séries
faites par semaine et par mois dans la partie Regularity ou Peak ; tu récupères
ça avec la date de fin de séance ; ne code pas, analyse où le mettre dans le
back-end, quel widget, et adapte le design. »

> **22-09, 11:00 — « go pour Regularity » : CODÉ, POSÉ et MESURÉ** (chemin A du
> § 4.2 : les séries à la date de fin, les séances inchangées, le litige posé sur
> le site). Preuves et captures : `series-2026-09-22/README.md`. Non commité.

Cette note dit ce qui existait au matin (lu dans le code et sur le site,
`fichier:ligne`), ce que je recommandais, et les décisions qui restaient.

---

## 0. En trois lignes

1. **Le widget : Regularity.** Le nombre de séries par semaine, c'est la *dose*
   d'entraînement — la question « combien de fois, combien de travail », pas
   « à quel maximum » (Peak) ni « combien de kilos » (Volume). Et sa chambre a
   déjà les deux fenêtres (Semaine / Mois) et un bloc « Résumé » fait de lignes
   *chiffre · nom · contre la fenêtre d'avant · flèche* : la ligne des séries
   s'y pose **sans un composant nouveau**.
2. **Le back-end : deux clés de plus dans `widget_regularite`** (`series`,
   `series_precedent`), comptées sur `strength_sets` — la définition qui PAIE
   déjà les pièces. Le téléphone calcule pareil (`Workout.seriesPayantes`), le
   banc `verif_widgets.py` compare les deux.
3. **Une décision cachée dans « la date de fin »** : aujourd'hui les quatre
   widgets rangent une séance au jour où elle **commence**, la Route au jour où
   elle **finit**. Compter les séries à la fin sans aligner le reste mettrait
   deux règles dans le même bloc « Résumé ». Je recommande d'aligner tout le
   widget sur la fin de séance — c'est à elle de trancher (§ 4.2).

---

## 1. Ce qui existe, lu et mesuré par d'autres avant moi

### 1.1 « Une série faite » a déjà une seule définition, des deux côtés

| côté | la définition | où |
|---|---|---|
| téléphone | `Workout.seriesPayantes` = Σ des séries cochées (`isDone`) de la séance — « C'est LA ligne à changer si la règle bouge — et il n'y en a qu'une » | [Models.swift:391-396](../../Nosfy/Models.swift) |
| la poussée | seules les séries cochées partent au serveur (`orderedSets.filter(\.isDone)`) | [SupabaseSync.swift:406](../../Nosfy/Services/SupabaseSync.swift) |
| serveur | une ligne de `strength_sets` **est** une série faite (« Séries faites uniquement dans les nouveaux instantanés ; les séries prévues restent locales », brique `b-tb-strength-sets`) ; la clôture les compte (`count(*)`) et refuse de payer si le téléphone annonce un autre nombre — `series_verifiees` | [20260918083033:103-106](../../supabase/migrations/20260918083033_compte_gains_et_progression.sql) |

Donc **compter les séries d'une fenêtre = compter les lignes de `strength_sets`**
des séances terminées de la fenêtre. Pas de règle nouvelle, pas de `reward_rules`
à poser.

Deux pièges à ne pas payer :

- ⚠️ **`strength_sets.is_done` existe (0001_init.sql:45) mais n'est JAMAIS
  écrite** : la poussée ne l'envoie pas (`StrengthSetRow`, SupabaseSync.swift:34-41),
  elle vaut `false` partout. Un `where is_done` rendrait **0 séries pour tout le
  monde**. Ne pas filtrer dessus — et l'écrire sur la brique `b-tb-strength-sets`.
- **Une série chronométrée peut avoir 0 répétition** (note de `b-tb-strength-sets`)
  et reste une série faite : on compte des lignes, pas `reps > 0` ni `weight > 0`
  (le `s.weight > 0` de `widget_peak` sert aux records, pas au compte).

Et une frontière déjà tranchée le 15-09 : **le cardio n'est pas des séries**
(`seriesPayantes` ne le compte pas, Models.swift:398-403 ; il a son barème de
séance, `pieces_cardio_seance`). Les longueurs de piscine non plus. Une semaine
100 % tapis affiche donc **0 série** — comme la chambre Volume affiche 0 kg.

### 1.2 Personne ne compte les séries par fenêtre

- Le serveur rend, par fenêtre : séances (`widget_regularite.faites`), kilos et
  **répétitions** (`widget_volume.reps`), pics, records — jamais un nombre de
  séries ([widgets_complets.sql:110-127](../../supabase/migrations/20260913211000_widgets_complets.sql), :233-253).
- Le téléphone pareil : `ChambreFenetre` porte `faites / precedent / suite /
  recordSuite / jours / defi` pour la régularité ([ChambreDonnees.swift:113-121](../../Nosfy/Views/ChambreDonnees.swift)), des reps par exercice pour le volume (:401) — pas de séries.
- La home : `SemaineStats` compte `faites`, le volume, le HIIT, le pic ([WidgetsCards.swift:3058-3172](../../Nosfy/Views/WidgetsCards.swift)).

### 1.3 Les deux fenêtres existent déjà, avec leur loi

`fenetre_bornes(p_fenetre)` : **Semaine** = du lundi 00:00 (fuseau du compte) à
maintenant ; **Mois** = 30 jours glissants ; et la fenêtre précédente est bornée
**au même temps écoulé** (le correctif du 25-08, sinon on annonce « en recul »
tous les lundis) — [widgets_lecture.sql:56-80](../../supabase/migrations/20260905090000_widgets_lecture.sql).
Le téléphone applique les mêmes bornes ([ChambreDonnees.swift:203-225](../../Nosfy/Views/ChambreDonnees.swift)).
Les séries suivent ces bornes, rien d'autre : « par semaine et par mois » = le
sélecteur Semaine / Mois de la chambre, qui existe.

### 1.4 ⚠️ La date : les widgets et la Route ne rangent pas une séance au même jour

| qui | la séance appartient au jour où elle… | où |
|---|---|---|
| les quatre `widget_*` (serveur) | **commence** (`w.started_at >= debut and < fin`, terminée = `ended_at is not null`) | [widgets_complets.sql:43-47](../../supabase/migrations/20260913211000_widgets_complets.sql), :157-169, :287-307, :486 (45 mentions de `started_at` dans les définitions vives ; `widget_hiit` reprise le 15-09, 20260915150000, même règle) |
| `SemaineStats` et `ChambreDonnees` (téléphone) | **commence** (`startedAt`) | WidgetsCards.swift:3083-3099 · ChambreDonnees.swift:238-240 |
| la Route : `seances_chemin`, le plafond 2/jour, `jours_chemin` (un galet = un jour) | **finit** (`ended_at`, au fuseau de la séance `workouts.fuseau`) | [20260920120000:19-31](../../supabase/migrations/20260920120000_seances_chemin_kind_telephone.sql) · 20260921090000:26-33 |
| la clôture (les pièces) | **finit** (`ended_at` vérifié, `dates_invalides` sinon) | 20260918083033:102 |

Kathryn dit « la date de fin » — la règle de la Route, celle du galet et des
pièces. Ce n'est visible que pour une séance qui **enjambe** une borne
(commencée dimanche 23:50, finie lundi 00:20 ; ou à cheval sur l'instant
« il y a 30 jours ») : le widget la range dans la semaine d'avant, la Route dans
celle-ci. Rare, mais c'est **une deuxième règle**, et elle n'est écrite nulle
part sur le site. Décision § 4.2.

---

## 2. Quel widget — Regularity, et pourquoi pas Peak

### Regularity (recommandé)

- **Le sens.** « 48 séries cette semaine » répond à *combien j'ai travaillé*,
  la suite naturelle de « 3 séances cette semaine ». C'est le chiffre qu'un
  programme d'entraînement pilote (« 10 à 20 séries par semaine ») : une dose,
  donc de la régularité — pas une performance.
- **Le design est déjà là.** Le bloc « Résumé » de la chambre est fait de
  lignes `chiffre · nom · sous-ligne « Contre N la semaine passée » · flèche
  ▲/▼` ([ChambreRegularite.swift:41-71](../../Nosfy/Views/ChambreRegularite.swift)).
  La ligne des séries **est** cette ligne. Le sélecteur Semaine / Mois change
  la fenêtre, les textes suivent (« ce mois-ci », « le mois passé »).
- **Le serveur est déjà là.** `widget_regularite` rend `faites` et `precedent`
  sur les deux fenêtres ; `series` et `series_precedent` se rangent à côté,
  même forme, même loi du vide (des zéros, jamais un null).

### Peak Effort (pas recommandé)

- **Le sens.** Peak = **le maximum** : un exercice, une charge, une marche
  battue (« L'ascension », « Le compte », « Autres pics », « Records »,
  [ChambrePeak.swift:3-12](../../Nosfy/Views/ChambrePeak.swift)). Un nombre de
  séries est une quantité, pas une intensité : il y dilue l'idée.
- **La place.** « Le compte » est une `Portee` à trois colonnes (charge · 1RM ·
  depuis le dernier record) ; une quatrième cramponne à 390 pt (≈ 76 pt par
  colonne, « Depuis le dernier record » passe déjà sur deux lignes). La card de
  la home n'a pas de grammaire semaine/mois : sa face retournée est la marche du
  record (« 60 kg × 8 · previous best 55 »), pas un mois.
- **Le serveur.** `widget_peak` est **par exercice** (`pics[]`, `ascension`) ;
  un total de séries y serait le seul scalaire hors sujet.

**Si elle le veut quand même dans Peak**, la place la moins fausse : le texte de
droite du titre de bloc « Le compte » — `BlocTitre(droite: "48 séries")`, mono
11 pt, encre sourde — le même motif que « L'ascension · 5 marches » et « Autres
pics · Cette semaine ». Pas de quatrième colonne. Serveur : les deux mêmes clés,
dans `widget_peak` au lieu de `widget_regularite`.

### Volume (le candidat qu'elle n'a pas nommé)

Les séries sont les voisines des répétitions et des kilos ; « Le compte » de la
chambre Volume n'a que deux colonnes (Par séance · Record de la semaine,
[ChambreVolume.swift:66-71](../../Nosfy/Views/ChambreVolume.swift)) : une
troisième « Séries » y tient sans forcer. Je ne le recommande pas en premier
parce que la question de Kathryn est « combien de séries **par semaine** »,
une question de rythme, et que le Volume, lui, compte des kilos. À garder en
tête si elle trouve que le Résumé de Regularity doit rester « pas un kilo »
(le commentaire de la chambre, ChambreRegularite.swift:8).

---

## 3. Le design adapté (Regularity)

### 3.1 La chambre — bloc « Résumé », une ligne de plus

Aujourd'hui deux lignes (séances ; semaines d'affilée). Demain trois, **la ligne
des séries en deuxième** : on lit le gros compte (séances), puis le compte fin
(séries), puis le temps (la suite de semaines), qui ferme le bloc.

```
Résumé
  8     Séances cette semaine                              ▲ +2
        Contre 6 la semaine passée
  48    Séries cette semaine                               ▲ +12
        Contre 36 la semaine passée
  3     Semaines d'affilée
        Ton record : 5 semaines
```

Mois (le sélecteur) :

```
  21    Séances ce mois-ci                                 ▲ +19
        Contre 2 le mois passé
  184   Séries ce mois-ci                                  ▲ +170
        Contre 14 le mois passé
```

Vide (la loi du 13-09 : le même dessin, en gris, des zéros) :

```
  0     Séances cette semaine
        Aucune la semaine passée
  0     Séries cette semaine
        Aucune la semaine passée
  0     Semaines d'affilée
        Ton record : 0 semaine
```

- Même composant `ligne(valeur:nom:sous:delta:)` : chiffre Inter 26 semibold
  encre métal (colonne ≥ 52 pt, « 1 240 » s'élargit tout seul), nom 13 pt encre
  douce, sous-ligne 10,5 pt encre 4, flèche ▲ verte / ▼ rouge mono 12 pt. Pas
  un pixel nouveau, pas de verre, pas d'horloge.
- Textes : FR « Séries cette semaine » / « Séries ce mois-ci », sous-ligne
  « Contre 36 la semaine passée » / « Contre 14 le mois passé » / « Aucune la
  semaine passée » ; EN « Sets this week » / « Sets this month », « Vs 36 last
  week » / « Vs 14 last month » / « None last week ». Le mot « série » reste
  singulier à 1 (« 1 série »).
- Première fenêtre de l'historique : pas de flèche (le précédent vaut 0 →
  « Aucune la semaine passée »), comme les séances.
- Semaine 100 % cardio : « 0 · Séries cette semaine · Contre 36 la semaine
  passée · ▼ −36 ». Honnête, et la chambre Volume explique déjà une fois que le
  cardio ne pèse rien. Je ne propose **pas** de phrase spéciale (« que du cardio
  cette semaine ») — verdict du 13-09 : pas de mini-textes parasites. Décision § 6.
- Le gris du bloc suit la règle existante (`.chambreVide(f.vide && f.suite == 0)`).

### 3.2 La card de la home — rien sur la face (v1)

La face dit « 35 / 3 · Sessions this week », les sept perles, le pied (« goal
reached » / « 1 session left »). Y ajouter un chiffre, c'est le mini-texte
qu'elle a fait retirer le 13-09 (« aère, enlève tous ces mini-textes »). Le
nombre de séries vit dans la chambre, comme la suite de semaines et le défi.

**Option, si elle le veut sur la home :** la face retournée (tap 1) — « This
month » + la grille des 31 points ([WidgetsCards.swift:1430-1436](../../Nosfy/Views/WidgetsCards.swift)) —
reçoit, **à droite du libellé, sur sa ligne d'œil**, « 128 sets », même corps
(0,05 H), encre douce. Réserve : cette grille est le **mois calendaire** ; la
chambre en Mois compte **30 jours glissants**. Deux « mois » = deux nombres
différents pour la même idée. Si elle veut ce chiffre sur la card, il faut
qu'il dise le mois calendaire (le mois de la grille), et le savoir.

### 3.3 Chauffe

Aucun moteur nouveau : du texte statique dans un rouleau. Rien à mesurer de
plus que ce que la chambre coûte déjà ; pas de barreau à créer. Un contrôle
visuel sur son iPhone à l'ouverture de la chambre, et c'est tout.

---

## 4. Le back-end — où, et quoi exactement

### 4.1 `widget_regularite(p_fenetre)` : deux clés de plus

Réponse d'aujourd'hui : `fenetre · defi · debut · fin · faites · objectif ·
reste · precedent · delta · suite_semaines · record_suite · jours`
([widgets_complets.sql:110-127](../../supabase/migrations/20260913211000_widgets_complets.sql)).

À ajouter, **sans rien retirer ni renommer** (la règle du 13-09) :

| clé | ce que c'est | comment on la compte, en mots |
|---|---|---|
| `series` | les séries faites de la fenêtre | le nombre de lignes de `strength_sets` dont l'exercice appartient à une séance **terminée** de la personne, dont la **fin** tombe dans [`debut`, `fin`) |
| `series_precedent` | la même chose sur la fenêtre d'avant | idem sur [`debut_prec`, `fin_prec`) — la fenêtre précédente **au même temps écoulé** (`fenetre_bornes`) |

- `series_delta` par symétrie avec `delta` (= `faites − precedent`) : pas
  indispensable, l'app dérive ; à ajouter si on veut que `bilan-periode` n'ait
  jamais à calculer (§ 4.5).
- Le vide rend `0`, jamais `null` (`b-fn-widgets-vide`).
- La fonction reste `stable`, `security definer` : filtrer sur `w.user_id = v_uid`
  **et** `s.user_id = v_uid` (la leçon d'`effort_seance` : SECURITY DEFINER
  contourne RLS, on filtre soi-même à chaque table).
- Pas de `is_done`, pas de `reps > 0`, pas de `weight > 0` (§ 1.1).
- `sync_complete_at` : les widgets ne le lisent pas aujourd'hui ; la poussée
  est atomique (`synchroniser_seance`), une séance sans ses séries n'existe
  pas au serveur. On ne l'ajoute pas — sauf si § 4.2 aligne tout sur la Route,
  qui le lit.

Coût serveur mesuré ailleurs : `widget_regularite` répond en 18-150 ms ; deux
`count(*)` de plus sur un index existant (`strength_sets_exercise_idx`,
`logged_exercises_workout_idx`, `workouts_user_started_idx`) ne changent pas
l'ordre de grandeur. À lire dans la réponse, pas à supposer.

### 4.2 La date de fin — la décision

**Ce qu'elle a dit :** on compte à la date de fin de séance.

**Le problème :** dans le même bloc « Résumé », « 3 séances » serait compté au
jour de **début** (règle actuelle des widgets) et « 48 séries » au jour de
**fin**. Une séance de dimanche soir qui finit après minuit donnerait « 0 séance
· 12 séries » lundi matin. Rare, mais faux à lire.

**Les deux chemins :**

| | A. les séries seules à la fin | B. tout le widget à la fin (recommandé) |
|---|---|---|
| ce qui change | les deux nouvelles clés seulement | `started_at` → `ended_at` dans les filtres de fenêtre des quatre `widget_*` (18 filtres de fenêtre + les regroupements par jour, semaine et mois : 45 mentions dans widgets_complets, 27 dans widget_hiit du 15-09), `SemaineStats.calcule` (WidgetsCards.swift:3083-3099), `ChambreDonnees.fenetre` et la grille des jours (ChambreDonnees.swift:238-240, 296-345), le défi et la suite de semaines (par `started_at` aujourd'hui) |
| ce qu'on obtient | la demande, au mot | **une seule règle dans l'app** : une séance appartient au jour où elle finit — le jour du galet, le jour des pièces, le jour du widget |
| ce que ça coûte | rien de plus | + ½ journée, et **re-mesurer** les 31 preuves de `verif_widgets.py` (elles comparent téléphone et serveur : les deux bougent ensemble, le banc doit rester TOUT VERT) |
| ce qui change pour elle | rien de visible, sauf le bloc Résumé incohérent une nuit sur cent | les séances à cheval sur minuit dimanche → lundi changent de semaine dans les widgets (comme dans la Route) |

Dans les deux cas, le fait « widgets = début, Route = fin » doit être **posé sur
le site** (litige sur `b-fn-fenetre-bornes`), qu'on le résolve ou non.

Fuseau : les bornes viennent de `fuseau_jour()` (le fuseau du compte) ; la Route
lit `workouts.fuseau` (celui de la séance) avec repli sur `fuseau_jour()`. Pour un
compte qui ne voyage pas, c'est le même. Si B, prendre la règle de la Route
(`coalesce(w.fuseau, fuseau_jour())`) pour la grille des jours — un seul jour
local dans toute l'app.

### 4.3 Le téléphone, le miroir

La règle ② de `ChambreServeur` ne bouge pas : le téléphone est la source tant
qu'il a une séance sur la fenêtre, le serveur seulement s'il n'en a aucune.

| où | quoi |
|---|---|
| [ChambreDonnees.swift:113-121](../../Nosfy/Views/ChambreDonnees.swift) | `ChambreFenetre` : `series`, `seriesPrec` (zone « Régularité »), `seriesDelta` dérivé comme `delta` |
| ChambreDonnees.swift:258-264 (`regularite`) | `series = Σ seriesPayantes` sur `cette`, `seriesPrec` sur `prec` — **la même ligne que les pièces** (Models.swift:394) |
| ChambreDonnees.swift:167-175 (`sansRien`) | `seriesPrec = 0` (la loi du vide entière : une fenêtre vide ne montre rien d'ailleurs) |
| [ChambreServeur.swift:174-178](../../Nosfy/Services/ChambreServeur.swift) (`regularite`) | lire `series`, `series_precedent` ; clé absente → 0 (une part grise, jamais un chiffre inventé) |
| [ChambreRegularite.swift:41-54](../../Nosfy/Views/ChambreRegularite.swift) (`resume`) | la troisième ligne (§ 3.1) |
| [WidgetsCards.swift:3175-3184](../../Nosfy/Views/WidgetsCards.swift) (`imprimerBanc`) | le journal `[widgets]` imprime `series` et `series_precedent` |
| [tools/serveur/verif_widgets.py:28](../../tools/serveur/verif_widgets.py), :66-75 | `CHAMPS` += `series`, `series_precedent` → 31 → 35 preuves (2 champs × 2 fenêtres) |

La home (`SemaineStats`) n'a rien à porter tant que la card n'affiche rien (§ 3.2).

### 4.4 La migration, et sa pose

- Un fichier `supabase/migrations/20260922HHMMSS_widget_regularite_series.sql` :
  `create or replace` de `widget_regularite` **depuis la définition vive**
  (`pg_get_functiondef`, la méthode du 13-09, « par remplacements assertés »),
  les deux clés ajoutées, rien retiré. Si B (§ 4.2) : les quatre fonctions dans
  le même fichier, avec l'en-tête qui dit pourquoi.
- Pose par l'API de gestion puis `migration repair` (la méthode du 20-09), et
  `b-migrations-posees` passe de 54 à 55.
- Mesure **avant** la pastille : un compte jetable dans une transaction
  annulée (la méthode du 05-09 : semer, lire, rollback, zéro ligne laissée) —
  une séance de 8 séries dont une à 0 rép, une séance cardio seule (→ 0), une
  séance finie lundi 00:20 commencée dimanche (→ la règle de date, lue) ; puis
  `verif_widgets.py` sur le compte de test : téléphone = serveur, les deux
  fenêtres.

### 4.5 Ce qu'on ne touche pas, et pourquoi

- **`bilan-periode` (la phrase de l'IA)** lit `widget_regularite` et construit
  `seances {faites, periode_precedente, ecart_seances, …}`
  ([index.ts:114-118](../../supabase/functions/bilan-periode/index.ts)). Donner
  les séries au modèle = un nombre de plus qu'il sera tenté de soustraire
  lui-même (le piège payé le 15-09 : « deux de moins que ton objectif », faux).
  **Pas en v1.** Si un jour oui : fournir `series`, `series_precedente` **et**
  `ecart_series` déjà calculé, jamais les deux bruts seuls.
- **`home()`** (la phrase de la home) : « 3 workouts this week » ne parle pas
  de séries. Rien.
- **`cloturer_seance`, la story de fin, la card STOP** : elles comptent déjà les
  séries d'UNE séance ; rien à changer, c'est leur définition qu'on réutilise.
- **`widget_volume.reps`** reste ce qu'il est ; les séries n'y vont pas (§ 2).

---

## 5. Le site de doc — dans le même commit que le chantier

À faire quand ça se code (règle absolue : la source ET le livrable partent avec
le changement, `npm run artefact` PUIS `npm run verif`, republication au même
lien). Les enregistrements exacts :

| enregistrement | où | quoi |
|---|---|---|
| `b-fn-widget-regularite` | serveur.ts:170 | `quoi` : + `series` / `series_precedent` ; `note` : mesure (compte jetable, valeurs lues) ; `preuve` : la réponse REST + le journal `[widgets]` |
| `b-wd-semainestats` | serveur.ts:135 | `preuve` rejouée : 35 preuves, `series` égales des deux côtés |
| `b-tb-strength-sets` | serveur.ts:59 | `note` : « `is_done` n'est jamais écrite (toujours false) : toute ligne EST une série faite, ne pas filtrer dessus » |
| `b-fn-fenetre-bornes` | serveur.ts:173 | `litige` : widgets au jour de début, Route au jour de fin — tranché A ou B (§ 4.2), avec la date |
| `b-migrations-posees` | serveur.ts:166 | 54 → 55 |
| `widgets.mdx`, tableau « Vide et plein », ligne Regularity | content/pages/widgets.mdx | vide : « 0 · Séries cette semaine · Aucune la semaine passée » ; plein : « 48 · Séries cette semaine · Contre 36 · ▲ +12 » |
| `<Savoir>` de widgets.mdx | idem | une phrase : les séries comptées par fenêtre = les lignes de `strength_sets`, la définition qui paie |

Tant que rien n'est mesuré, **aucune pastille ne bouge** : `b-fn-widget-regularite`
reste 🟢 sur ce qu'elle rend aujourd'hui, et la note dira « séries : posées, non
mesurées » jusqu'à la lecture de la réponse.

---

## 6. Les décisions qui l'attendent

1. **Regularity** (recommandé) — ou Peak, avec la place minimale décrite au § 2 ?
2. **La date** : B, tout le widget au jour de fin, une seule règle avec la Route
   (recommandé) — ou A, les séries seules ?
3. **La card de la home** : rien en v1 (recommandé) — ou « 128 sets » sur la
   face retournée « This month », en sachant que c'est le mois calendaire ?
4. **La semaine cardio** : « 0 séries · ▼ −36 » tel quel (recommandé) — ou une
   phrase ?
5. **L'IA du bilan** reçoit-elle les séries ? Non en v1 (recommandé).

---

## 7. Le coût et l'ordre de marche (quand elle dira go)

| étape | coût | preuve attendue |
|---|---|---|
| 1. serveur : migration + pose + mesure sur compte jetable | ½ j | réponses REST lues, rollback à zéro ligne |
| 2. app : `ChambreFenetre`, `ChambreDonnees`, `ChambreServeur`, `ChambreRegularite`, banc `-widgetsBanc` | ½ j | capture de la chambre en Semaine, en Mois, à vide (simulateur, compte de test), puis son iPhone |
| 3. banc + site : `verif_widgets.py` 35 preuves, les sept enregistrements du § 5, artefact + verif, republication | ½ j | TOUT EST VERT, `npm run verif` vert |
| si B (§ 4.2) : les quatre `widget_*` + `SemaineStats` + `ChambreDonnees` au jour de fin, 31 preuves rejouées | + ½ j | le banc reste vert, le litige du site se ferme |

Un seul commit, par chemins, sur son ordre — code, migration, banc, site.
