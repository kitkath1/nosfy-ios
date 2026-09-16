# LA FICHE MUSCU — la courbe de charge et la ligne de coach, à la place de la description

**Plan du 15-09-2026 (fin d'après-midi), sur le verdict de Kathryn** (session cardio,
woochoper-ios-41) :

> *« ok la courbe et tout ce que tu as dit très bien ; il faut updater le backend du
> coup en plus et rajouter dans la documentation ; faire un état empty ; inspire-toi
> des magnifiques graphs des widgets, minimal, joli et peu de texte car ça fait IA
> (mais oui bien du texte par IA personnalisé) ; en mode Apple minimal, dégradé
> blanc qui apparaît au blur avec une mini animation d'étoile pour montrer que
> quelqu'un parle, sous le graph ; on supprime la description ; l'arrivée ok ; le
> geste oui très bien. »*

Ce que ça remplace : sous le titre de la fiche muscu, `DescriptionExo` (le « cue » et
« À éviter » du catalogue) — le même texte pour tout le monde, pour toujours. Ce qui
le remplace dit **ce que toi tu as fait** (la courbe), et **ce que tu peux faire
aujourd'hui** (la ligne de coach). La même loi que le cardio le matin : le slot n'est
pas une description, c'est une donnée.

**Rien n'est codé au moment où ce plan est posé.** La carte ci-dessous a été LUE (trois
lecteurs, fichier:ligne) ; le site de doc reste la référence des états.

---

## 0. L'ÉTAT DES LIEUX — ce qui existe, ce qui manque

| | téléphone | serveur |
|---|---|---|
| les séries d'un exercice | SwiftData `Workout → LoggedExercise → StrengthSet` (reps, weight, order, isDone, durationSeconds) ; la fiche lit `@Query workouts` (ExerciseDetailView.swift:29) | `strength_sets` (reps, weight, position — SANS isDone ni durée), poussée par `SupabaseSync.pousser` (SupabaseSync.swift:328-331) |
| la liste des PASSAGES d'un exercice | **n'existe pas** — `lastLogged` ne rend qu'un passage (:3044-3051, le PREMIER bloc, pas le dernier) ; le squelette « tous les passages » vit dans `ChambreDonnees.peak` (:553-560) | **n'existe pas** — `widget_peak` raisonne par fenêtre, l'ascension n'est calculée que pour le meilleur exo (widgets_complets.sql:505-522) ; `seances_depuis` rend tout l'arbre |
| le record par exercice, tous temps | **n'existe pas** (par fenêtre seulement) | idem (`precedent` dans widget_peak) |
| la charge proposée pour la série suivante | `DraftSet` 12 reps / 20 kg en dur (ExerciseEditor.swift:5-13) ; la LENTILLE repart de 12/20 à chaque montage (LiquidLensLab.swift:136-138, site d'appel :1105-1131 sans reps/kilos) | — |
| l'IA | `ChambreServeur.bilan` appelle l'edge `bilan-periode` (ChambreServeur.swift:73-108) | edge `bilan-periode` : JWT `admin.auth.getUser`, langue `profils.langue`, chiffres relus par RPC AVEC le jeton de la personne, gpt-5 `reasoning_effort: minimal` (Claude si `ANTHROPIC_API_KEY`, jamais posée), cache table `syntheses` (unique user/période/début, réécrit si `seances` ou `langue` bouge) — 3,6 s à froid, 1,5 s en cache |
| les règles | — | `reward_rules` + `regle_num(key, défaut)` (widgets_lecture.sql:41-50) ; le barème cardio en lit 25 |
| le langage visuel | `PaliersVue` (barres = segments, pic à Pointe + étiquette + foyer, tap par position, silhouette, cascade `apparu`), `AscensionVue` (marches du record : la dernière brûle, le passé recule par l'opacité 0,35 → 0,85, fil pointillé), `ChambreFmt`, `CardTon.chaleur`, `ChambreTon.graphite/encre4`, `.chambreVide` | — |
| l'intégration dans la fiche | `GrapheCardioFiche` (CardioFiche.swift:20-67) : 138 pt, `ArriveeDouce` 0,48 / 0,60 / 0,76, monté en `if` au `else` de :1729-1734 ; cache `rafraichirSegments` hors du corps | — |

⚠️ Deux pièges lus qui décident du dessin :
- `LoggedExercise.maxWeight` / `volume` ne filtrent PAS `isDone` (Models.swift:498-502) : le
  max d'un passage se calcule sur `orderedSets.filter(\.isDone)`.
- le `else` à remplacer (:1729-1734) sert AUSSI à la piscine : `if isStrength` explicite,
  la piscine garde sa description.

---

## 1 bis. LE DESSIN v3 — « encore plus Apple, plus d'haptique » (15-09, 22 h) — POSÉ, VALIDÉ

> **16-09, 00 h 30 — la v3 est CODÉE (Swift Charts) et VALIDÉE par Kathryn en direct au
> banc (« c'est good », « il faut le cas empty aussi » → posé). Captures :
> `captures/planche-courbe-coach-v3-16-09.png` (première fois · 6M · le lollipop · M · S),
> `captures/v3-vide-16-09.png`. Ce qui est posé suit le plan ci-dessous à ces détails
> près : la pilule S · M · 6M a la matière des chips (verre `.regular` fumé noir) ; la
> capsule du lollipop est un `chartOverlay` (une annotation au-dessus du tracé se faisait
> couper) ; le fil se révèle par un masque (0,9 s) ; le voile de chaleur est à 0,20 ;
> `-sansCourbe` n'est PAS encore posé. Côté serveur : GO donné à la session back-end
> (§2, contrat : phrase ≤ 60 signes, sans tiret, un chiffre ; `premier` sans IA), qui
> demande le feu vert du déploiement (modèle payant) à Kathryn en direct. Côté app :
> `CoachServeur.conseil` (8 s, `-sansServeur`) est branché, mesuré contre l'edge absente
> (`[coach] hip-thrust → pas de phrase (http_404) · 56 ms`, repli local lu). Rien commité.**


Verdict sur la v2 (vue en direct au simulateur, touchée) : « encore plus Apple + haptique,
je trouve pas assez Apple design, refais un plan, ne code pas ». Ce qui manque à la v2
pour être un graphe d'Apple Santé, et ce que je propose :

### A. Le graphe se dessine avec Swift Charts — le cadre d'Apple, pas un dessin à nous
La v2 est un `Path` à la main. Apple Santé, Fitness, Bourse : tous leurs graphes sont
**Swift Charts** — c'est ça, l'ADN visuel qu'on cherche (les courbes, les axes, le
lollipop, les transitions de période). Le cadre est dans iOS, sans horloge, animé par
SwiftUI, accessible d'office. On le HABILLE aux couleurs de la maison, on n'invente
plus le squelette :
- `LineMark` interpolé `catmullRom`, 2,5 pt, dégradé graphite → chaleur ;
- `AreaMark` dessous, chaleur 0,35 → transparent ;
- `PointMark` fins ; le dernier point allumé (halo) ;
- **la ligne du record** : un `RuleMark` horizontal en pointillé fin, chaleur, avec
  « 67,5 » à droite — la ligne d'objectif d'Apple Santé ;
- **la grille** : trois lignes horizontales en pointillé à 7 % de blanc (Apple en met
  toujours, c'est ce qui fait « instrument » et pas « illustration »), et les kg à
  DROITE en 10 pt gris (Santé les met à droite) ; les mois en bas, même gris.

### B. Le bloc du nombre, à la façon de Santé
Au-dessus du nombre, une étiquette en petites capitales, 9,5 pt, gris, espacée :
**DERNIÈRE CHARGE**. Puis le nombre (34 léger), « kg » petit, l'écart « +2,5 » en
chaleur. À droite du même rang, **le sélecteur de période** : une pilule de verre (la
matière des chips du header) à trois positions **S · M · 6M** — la semaine (une par
séance), le mois, les six mois. C'est le geste d'Apple Santé ; le tap sur un mois sous
la courbe (v2) disparaît au profit de ça : un seul moyen, évident.

### C. Le doigt — le lollipop de Santé
Le doigt glisse sur la courbe : un fil vertical fin, le point choisi grossit avec un
anneau blanc, et une **étiquette flottante** au-dessus du fil, dans une petite capsule
obsidienne à liseré (pas de verre sur du noir), qui suit le doigt avec un ressort :
« 55 kg » en clair, « 21.07 · 12 10 8 » dessous, gris. Levé, tout s'efface en fondu.
`chartXSelection` fait exactement ça.

### D. L'haptique — la table
| geste | retour | pourquoi |
|---|---|---|
| le doigt passe d'un point à l'autre | `UISelectionFeedbackGenerator.selectionChanged()` | le tic des sélecteurs d'Apple, un par point, jamais en continu |
| changer de période (S · M · 6M) | `.impact(.soft)` | le geste d'un segment |
| une série qui bat le record, en séance | `.notification(.success)` + le point pulse une fois + la ligne du record se déplace vers le haut | le seul moment qui mérite un « bravo » physique |
| la phrase de coach qui arrive | aucun | Apple ne vibre pas pour du texte ; l'étoile suffit |
| l'arrivée de la courbe | aucun | idem |
Tous préparés à l'apparition (`prepare()`), la loi de la maison sur la latence.

### E. Le mouvement
- l'arrivée : le fil se trace (0,9 s), l'aire monte en fondu, les points en cascade —
  comme la v2 ;
- **le changement de période** : la courbe se REDÉPLOIE en ressort (Swift Charts anime
  le domaine : les points glissent à leur nouvelle place, la grille suit) — plus de
  fondu croisé ;
- le lollipop suit le doigt en ressort court ; le point choisi grossit en 0,12 s ;
- le nouveau record : le point pulse (échelle 1 → 1,6 → 1, 0,5 s) une fois.

### F. La phrase de coach — le reveal d'Apple Intelligence
Elle garde l'étoile qui respire pendant l'attente et l'éclat à l'arrivée. Le texte
n'arrive plus au blur mais **au shimmer** : une lumière fine balaie les lettres de
gauche à droite une seule fois (0,8 s) — le reveal des outils d'écriture d'Apple —
puis l'encre se pose en dégradé blanc. Un masque de dégradé qui se déplace : une
valeur animable, aucune horloge. Une ligne, courte, sans tiret (inchangé).

### G. Le vide
La même grille, la même ligne du record (absente), la courbe en silhouette grise
(loi de la maison, jamais « aucune donnée »), l'étiquette DERNIÈRE CHARGE sans nombre,
la coach « Première fois ici. Pars léger, on mesure. ».

### H. Ce que ça coûte, et ce qu'il faut mesurer
Swift Charts rend via SwiftUI : aucune horloge, mais son coût de mise en page sur
une fiche déjà lourde (photo, galet, lentille) N'EST PAS CONNU — il se mesure sur son
téléphone (la paire img/cpu, thermique 0), avec un barreau `-sansCourbe`. Le shimmer
est un masque animé une fois : pas de coût au repos.

### I. Ce qui ne change pas
Les données (le téléphone d'abord, les séries faites), la coach servie par le serveur
(§2 inchangé, la phrase courte), la description supprimée, la piscine intacte.

**Ordre** : ce plan → ton verdict → le code sur hip-thrust → montré → puis la phrase IA.

## 1. LE DESSIN

> **v2 (15-09 soir)** — la v1 à barres (une barre par passage, ligne de tête, légende,
> rail des dates) a été REFUSÉE : « beaucoup plus minimal, trop de texte, pas assez
> premium Apple ; ça ne marche pas sur six mois ; enlève les tirets ; refais le design
> très très premium ». La v2 posée et montrée (`captures/planche-courbe-coach-v2-15-09.png`,
> `film-arrivee-coach-15-09.png`) : **un grand nombre** (le dernier poids, léger, « kg »
> petit, l'écart « +2,5 » en chaleur s'il monte), **une courbe dans le TEMPS** (six mois
> au plus, dix jours au moins ; un fil du graphite au chaud, un voile de chaleur dessous,
> des points fins, le dernier allumé, le record cerclé ; les mois à peine écrits en gris
> sourd ; sous le doigt un fil vertical et « 55 kg · 21.07 · 12 10 8 ») ; **le zoom**
> (« je clique sur un mois, je vois le détail ? ») : un mois touché sous la courbe
> s'ouvre (son nom en chaleur à gauche, les jours 8 · 15 · 22 · 29), touché à nouveau il
> se referme ; **la coach** en UNE ligne courte, sans tiret ; **aucune ligne de tête,
> aucune légende**. Le §1.1 ci-dessous décrit la v1 et reste pour l'histoire ; le code
> fait foi (`Woop/Views/ChargeFiche.swift`). Verdict de Kathryn sur la v2 : en attente.


### 1.1 La courbe de charge — `CourbeChargeFiche`

Le slot de `GrapheCardioFiche`, la même hauteur (138 pt : à 190 le rail passait sous
le galet, mesuré), la même arrivée (`ArriveeDouce`), la même loi du vide.

- **Une barre par passage** sur cet exercice, les 12 derniers, du plus ancien à gauche
  au plus récent à droite ; hauteur = le **poids le plus lourd** du passage (séries
  FAITES), plancher 10 pt, plafond 110 ; largeur égale, gouttière 6 (10 si ≤ 6).
- **La lumière** : la dernière barre brûle (chaleur), le **record** tous temps brûle
  aussi et porte la Pointe + l'étiquette « 65 kg » + le foyer radial de `PaliersVue`
  (:333-355) ; le passé recule en graphite par l'opacité 0,35 → 0,85 (`AscensionVue`
  :99-192). Si le record EST la dernière : une seule barre chaude, la pointe dessus.
  Jamais d'ambre, jamais un gris réchauffé : `CardTon.chaleur(t)` seulement.
- **Le rail** : la date `ChambreFmt.jourCourt` (« 08.09 ») sous chaque barre si n ≤ 7,
  une sur deux au-delà ; le nombre de séries N'EST PAS écrit sous la barre (peu de
  texte) — il vit dans la ligne de tête et sous le doigt.
- **La ligne de tête** (la grammaire de la chambre, une seule ligne) : « Mardi 15.09 ·
  3 séries · 45 kg » = le dernier passage ; « Maintenant · … » si la séance est en cours.
- **La légende** : deux capsules — chaleur « Record » · graphite « Passages ». Rien
  d'autre.
- **Le geste** (« oui très bien ») : UN `onTapGesture { location in }` sur la vue,
  résolu par les x (cible élargie à 24 pt, PaliersVue :263-270) ; la barre choisie
  reste pleine, les autres tombent à 0,62, une ligne de lecture apparaît en fondu
  au-dessus du rail : « 08.09 · 12 · 10 · 8 reps · 45 kg » ; re-tap = désélection ;
  désarmé sur le vide.
- **L'arrivée** (« ok ») : `apparu` unique, chaque barre pousse de 2 pt à sa hauteur,
  `timingCurve(0.2, 0.9, 0.25, 1, 0.6).delay(i × 0.05)` ; la pointe et l'étiquette du
  record n'existent qu'après ; la laque `.opacity(apparu)`. Aucune horloge, jamais.
- **Le vide** (« faire un état empty ») : la silhouette `[40, 45, 45, 50, 55, 52, 60]`
  (jamais deux pareilles, le 13-09 l'a payé), `.chambreVide` (saturation 0, opacité
  0,55), la ligne de tête « — · 0 série · — kg », les tirets à la place des chiffres,
  le tap désarmé, et la ligne de coach en mode « première fois » (§1.2).

### 1.2 La ligne de coach — `LigneCoach`

Sous la courbe, à la place de la légende du cardio (la légende de la courbe passe
au-dessus du rail, plus fine). **Une ligne, deux au plus**, ≤ 90 signes.

- **L'encre** : dégradé blanc `encreMetal` (#FFFFFF → #DCDCDC, ChambreLongue.swift),
  `.inter(13, .medium)`, `lineLimit(2)`.
- **L'étoile** : `sparkle` (SF) 12 pt à gauche, en chaleur douce. Elle dit « quelqu'un
  parle » : pendant que le serveur écrit, elle **respire** (opacité 0,35 → 0,9, 1,1 s,
  `phaseAnimator`, valeur animable — pas une horloge, et bornée par l'attente) ; quand
  la phrase arrive, elle fait **un** éclat (`keyframeAnimator` : échelle 0,6 → 1,18 → 1,
  rotation 0 → 24° → 0, 0,7 s), puis se pose et ne bouge plus.
- **Le texte arrive au blur** (« dégradé blanc qui apparaît au blur ») : `blur 14 → 0`,
  opacité 0 → 1, offset 6 → 0, `.easeOut(0.9)` — le rayon retombe à ZÉRO exact une fois
  posé (la loi d'`ArriveeDouce`), rien ne reste flou.
- **Ce qu'elle dit** — trois cas, tous servis par le serveur (§2) :
  - **première fois** (aucun passage) : la phrase de la règle, pas d'IA : « Première
    fois ici : pars léger, on mesure aujourd'hui. » (fr) — la loi du vide ne dit jamais
    « rien à afficher » ;
  - **l'IA a répondu** : sa phrase, dans la langue du profil, avec UN chiffre déjà
    calculé (« Dernière fois 45 kg × 12, vise 47,5 aujourd'hui. ») ;
  - **le serveur n'a pas répondu** (hors ligne, `-sansServeur`, délai > 8 s) : la
    phrase que le téléphone sait écrire seul, sans règle et sans invention :
    « Dernière fois 45 kg × 12. » — jamais une cible inventée côté app (la règle vit au
    serveur, une constante Swift qui la double est une bombe).
- **Aucun spinner, jamais** : avant la réponse il y a l'étoile qui respire et le vide
  sous elle ; après, la phrase. Le retour de la fiche ne redemande pas : la réponse
  est gardée en mémoire le temps de la page (et le serveur, lui, rend le stocké).

### 1.3 Ce qui disparaît

`DescriptionExo` n'est plus montée pour la muscu (« on supprime la description »). Le
composant reste (la piscine s'en sert encore) ; `cue` / `mistake` restent dans le
catalogue : le serveur les lit dans `exercices.consigne` pour la première fois.

---

## 2. LE SERVEUR (session back-end) — ce qu'il faut poser

Le motif est celui de `bilan-periode` + `syntheses`, à l'exercice près. Trois pièces,
une migration, une edge function, un script de vérification.

### 2.1 Les règles — `reward_rules`

| clé | défaut | rôle |
|---|---|---|
| `coach_reps_haut` | 12 | le haut de la fourchette : toutes les séries FAITES du dernier passage à ≥ 12 reps → on monte |
| `coach_pas_kg` | 2.5 | le cran d'au-dessus |
| `coach_passages` | 12 | combien de passages la fonction rend |
| `coach_series_min` | 3 | il faut au moins 3 séries faites pour proposer de monter |

Lues par `regle_num`, écrites par migration seulement, documentées sur la carte.

### 2.2 La lecture — `historique_exercice(p_exercice text) returns jsonb`

`stable security definer set search_path = public`, `auth.uid()` (sinon
`{erreur: sans_session}`), `revoke from public, anon` + `grant to authenticated`.
Séances FINIES seulement (`ended_at is not null`), `strength_sets` de la personne pour
`logged_exercises.exercise_id = p_exercice`, `weight > 0`.

Rend :
```
{ exercice: "hip-thrust", nom, premier: bool,
  passages: [ { workout_id, date, series: [{reps, kg}], max_kg, n_series } ]  // 12 derniers, du plus ancien au plus récent
  dernier:  { workout_id, date, max_kg, n_series, reps_min }                    // null si premier
  record:   { kg, date }                                                        // tous temps, null si premier
  regle:    'premier' | 'monter' | 'tenir',
  cible_kg, cible_reps, delta_kg,                                                // null si premier ; delta = cible − dernier.max_kg (0 si tenir)
  phrase_regle_fr, phrase_regle_en,                                              // la phrase déterministe, prête
  cle_fraicheur }                                                               // = dernier.workout_id (null si premier) — la clé du cache
```
La règle : `monter` si `n_series ≥ coach_series_min` et `reps_min ≥ coach_reps_haut`
→ `cible_kg = max_kg + coach_pas_kg` ; sinon `tenir` → `cible_kg = max_kg` ;
`cible_reps = coach_reps_haut`. ⚠️ Le serveur ne connaît pas `isDone` (push ne l'envoie
pas) : il compte toutes les séries d'une séance finie — c'est le choix déjà fait par
`widget_peak` (:485), on le garde et on le DIT sur la carte. Exercice inconnu →
`200 {raison: 'exercice_inconnu'}`, jamais un `raise`.

### 2.3 La phrase — edge `conseil-exercice`

Corps `{ exercice }`. JWT → `admin.auth.getUser` (401 `sans_session`) ; langue =
`profils.langue` ; `historique_exercice` appelée par RPC **avec le jeton de la
personne** (jamais le service role : `auth.uid()` serait null).

- `premier` → rend `{phrase: phrase_regle_<langue>, regle: 'premier', cache: false,
  modele: 'regle'}` — pas d'appel payant pour une première fois.
- sinon, cache : table `conseils_exercice (user_id, exercice_id, cle_fraicheur uuid,
  langue, phrase, modele, cible_kg, created_at, updated_at, unique (user_id,
  exercice_id))`, RLS select own, AUCUNE policy d'écriture (service role seul). Si une
  ligne existe avec la même `cle_fraicheur` ET la même `langue` → `{…, cache: true}`.
- sinon le modèle (gpt-5, `reasoning_effort: minimal`, 1500 jetons, la clé OpenAI de
  la forge) avec un RÉSUMÉ nommé, jamais les séries brutes : `{nom, dernier_max_kg,
  dernier_series: "12 · 10 · 8", record_kg, record_battu: bool, cible_kg, delta_kg,
  regle, consigne}` et la consigne : « Une phrase, 90 caractères au plus, tutoiement,
  dans la langue demandée. Appuie-toi sur UN chiffre présent. NE FAIS AUCUN CALCUL :
  la cible et l'écart sont donnés. Pas d'accueil, pas d'emoji, pas de liste. » Réponse
  vide → `502 modele_muet` ; clé absente → `503 cle_absente` ; dans les deux cas l'app
  retombe sur `phrase_regle`.
- upsert du cache, rend `{phrase, phrase_regle, regle, cible_kg, cible_reps, delta_kg,
  record_kg, langue, cache, modele}`.

### 2.4 La vérification — `tools/serveur/verif_coach.py`

Sur le compte de test, comme `verif_cardio.py` (semer, appeler, LIRE, nettoyer y
compris le cache) : sans jeton → 401 ; exercice inconnu → 200 `exercice_inconnu` ;
aucun passage → `regle premier`, `modele regle` ; deux séances semées (3 × 12 à 45)
→ `regle monter`, `cible_kg 47.5`, `delta_kg 2.5` ; une séance à 12 · 10 · 8 →
`tenir`, `cible_kg 45` ; l'appel IA une fois `cache false`, la seconde `cache true` ;
`profils.langue = 'en'` → phrase en anglais, `cache false` (la langue invalide) ; le
`finally` efface séances, faits, cache.

### 2.5 La carte du serveur (dans le même commit que la migration)

`b-rg-coach` (règle, 4 clés) · `b-fn-historique-exercice` (fonction) ·
`b-tb-conseils-exercice` (table) · `b-edge-conseil-exercice` (edge) — 🔵 à la pose,
🟢 quand `verif_coach.py` a LU les réponses, et 🟢 sur la brique app quand le journal
`[coach]` du banc a été lu.

---

## 3. LE TÉLÉPHONE (moi) — ce qu'il faut poser

### 3.1 Les passages — `PassageCharge` et `rafraichirPassages()`

```swift
struct PassageCharge: Identifiable, Equatable {
    let id: UUID            // le LoggedExercise
    let date: Date
    let enCours: Bool       // la séance est ouverte (« Maintenant »)
    let series: [(reps: Int, kg: Double)]   // FAITES seulement, dans l'ordre
    var maxKg: Double { series.map(\.kg).max() ?? 0 }
}
```
Construit hors du corps, comme `rafraichirSegments` : `for w in workouts { for l in
w.orderedExercises.reversed() where l.exerciseID == exercise.id { let faites =
l.orderedSets.filter(\.isDone) ; if !faites.isEmpty { … } } }`, du plus récent au plus
ancien, puis renversé, coupé à 12 pour la courbe ; le record se calcule sur TOUT (pas
seulement les 12). Appelé à `onAppear` et après `ancrerSerie` (après le `save()`).
`@State passages: [PassageCharge]`, `@State recordKg: Double?`, `@State titreCharge:
String` — jamais `workouts` lu dans `collapsingHeaderBack` (un `GeometryReader`
fonction de `headerY` : tout ce qu'il lit est ré-évalué au pixel de scroll).

### 3.2 La courbe — `Woop/Views/ChargeFiche.swift`

`CourbeChargeFiche(passages:recordKg:titre:vide:vu:)` → `CourbeCharge` (le dessin :
barres, pointe, rail, lecture, silhouette) + `LegendeCharge`. Un rang = une fonction
nommée (le mur du type-checker, ChambreHiit.swift:512). Aucune closure en propriété.

### 3.3 La ligne de coach — `LigneCoach` + `CoachServeur`

`CoachServeur.conseil(_ exerciceID: String) async -> Conseil` : le motif de
`ChambreServeur.bilan` (POST `functions/v1/conseil-exercice`, `timeoutInterval 8`,
barreau `-sansServeur`, jamais un throw, toujours un `Conseil` avec `raison`).
`@State conseil: Conseil?` posé au retour dans un `withAnimation` ; la fiche demande
UNE fois à l'apparition (`.task`), et redemande après `ancrerSerie` (la clé de
fraîcheur a bougé : le serveur répond neuf). Fallback local (§1.2) construit depuis
`passages.last`.

### 3.4 La piscine ne bouge pas

`if isStrength { CourbeChargeFiche … } else { DescriptionExo … }` au `else` de
:1729-1734 — la piscine garde sa description, le cardio son graphe.

### 3.5 Les bancs

- `-chargeBanc <n>` : sème n passages FAITS de cet exercice dans SwiftData au banc
  (dates espacées de 3 jours, charges 40 → record, un « tenir » au milieu) — le
  simulateur n'a pas d'historique ; `-chargeBanc 0` = le vide.
- `-coachPhrase "<texte>"` : la ligne rendue sans serveur (pour la capture et le
  fouettage de l'arrivée) ; `-coachAttente` : l'étoile figée en « il écrit ».
- `-sansCoach` : LE BARREAU — ni étoile animée, ni appel : ce que ce moteur coûte se
  mesure au téléphone, en ABBA, thermique 0 au départ.
- `-sessionBanc … -coachBanc` : le journal `[coach] hip-thrust → « … » · monter ·
  47,5 · cache|gpt-5` (la preuve de la brique).

### 3.6 Le site (dans le commit de l'app)

`b-flow-courbe-charge` (🟡 : téléphone seul, mesuré au sim) · `b-flow-coach-exercice`
(🟡 tant que l'edge n'est pas posée, 🟢 quand le journal `[coach]` a été lu au banc
sur le compte de test) · note sur `b-flow-fiche-cardio` (la description muscu est
retirée).

---

## 4. À TRANCHER (mes recommandations en premier)

| | question | reco |
|---|---|---|
| **Q1** | La lentille repart de 12 / 20 à chaque série (LiquidLensLab.swift:136-138) : la coach dit « vise 47,5 » et la feuille s'ouvre à 20 kg. **Pré-remplir la lentille** avec la cible du coach (première série du passage) puis avec la série précédente ? | **oui** — un paramètre d'entrée sur `LiquidLensLab` (reps, kilos initiaux) posé au montage ; sans ça la ligne ment dès qu'on tape. Jalon J4, après ton verdict |
| **Q2** | La première fois : phrase de la règle (gratuite, instantanée) ou l'IA aussi ? | **la règle** — rien à personnaliser, rien à payer |
| **Q3** | Combien de passages sur la courbe ? | **12** (comme les segments HIIT ; `coach_passages`) — au-delà les barres passent sous 14 pt |
| **Q4** | Le serveur compte toutes les séries d'une séance finie (il n'a pas `isDone`) ; le téléphone ne compte que les faites. Pousser `is_done` ? | **pas maintenant** : la fiche muscu n'écrit que du fait, le pull pose `isDone: true` ; on le DIT sur la carte (litige ⚑ sur `b-tb-strength-sets`), on tranchera avec la session compte |
| **Q5** | La ligne de coach en séance : redemander après chaque série ? | **oui**, après `ancrerSerie` — c'est là que la phrase change (« record ! ») ; le serveur rend le stocké si rien n'a bougé |

---

## 5. LES JALONS, dans l'ordre

| | quoi | preuve |
|---|---|---|
| **S1** (back-end) | migration `20260915*_coach_exercice.sql` : règles, table, `historique_exercice` ; `db push` ; carte 🔵 | `verif_coach.py` partie SQL ✓ |
| **S2** (back-end) | edge `conseil-exercice` déployée ; cache mesuré (2e appel `cache true`) ; carte 🟢 | `verif_coach.py` complet ✓, latence lue |
| **J1** (moi) | `PassageCharge` + `CourbeChargeFiche` + vide + geste + arrivée, à la place de la description ; `-chargeBanc` | captures : vide, 3 passages, 12 passages avec record, une barre tapée |
| **J2** (moi) | `LigneCoach` + `CoachServeur` + fallback + bancs ; branché sur l'edge dès S2 | film de l'arrivée (étoile → phrase au blur) ; journal `[coach]` au banc sur le compte de test |
| **J3** (moi) | le site : les deux briques, la note cardio, artefact + verif, republié | vert |
| **J4** (verdict Q1) | la lentille pré-remplie avec la cible | capture de la feuille ouverte à 47,5 |
| **T** (téléphone) | ABBA `-sansCoach`, thermique 0 ; le toucher sur la barre | la paire (img, cpu) |

---

## 6. LES PIÈGES DÉJÀ PAYÉS QUI S'APPLIQUENT

- Une closure en propriété de vue la rend inégalable (l'échelle est un enum) ; un rang de
  ForEach = une fonction nommée ; la loi du vide = le même dessin en silhouette, jamais
  une phrase « rien » ; 138 pt max sous le titre ; `apparu` + délais, jamais de
  `TimelineView` ; `chaleur(t)` sur la rampe, jamais un dégradé vers un gris.
- Le tap sur une barre est UN geste résolu par position, pas un `onTapGesture` par barre ;
  sur la fiche il vit au-dessus du drag d'ancêtre (`highPriorityGesture` si besoin).
- Le cache serveur se réécrit sur la clé de fraîcheur ET la langue (le motif
  `syntheses`) ; le rejeu se teste (2e appel `cache true`) ; gpt-5 ne calcule jamais
  (la cible et l'écart sont donnés) ; `reasoning_effort: minimal` sinon réponse vide.
- Le 404 PostgREST ment (signature) ; `revoke from public` sinon `grant` ne ferme rien ;
  déploiement par la CLI, jamais par le MCP.
- L'arbre partagé : ExerciseDetailView.swift est propre à HEAD au moment du plan ; les
  autres sessions ont été prévenues (compte, annonces, coffre, pastille).
