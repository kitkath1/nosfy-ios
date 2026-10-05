# Plan : gainage, crunch, chevilles dans les widgets et au serveur (05-10-2026)

Sa demande (05-10) : « les règles gainage et tout dans le backend et dans le widget, comme les autres ».

## Ce qui est déjà juste (lu le 05-10)

| Où | Gainage (temps seul) | Crunch, chevilles (reps seules) | Preuve |
|---|---|---|---|
| Saisie, fiche, courbe, story | le temps tenu | les reps | `Exercise.Saisie` (Models.swift:95-132) |
| Live Activity (île) | rien de faux (pas de kg) | « 12 reps » | `LiquidLensLab.livePhase`, `WorkoutLiveFocus.detail` |
| Serveur : la série | `strength_sets.duree_s` | reps, kg 0 | migration 20260930150000, bout en bout mesuré le 30-09 |
| Serveur : le catalogue | `exercices.saisie = tempsSeul` | `repsSeules` | migration 20260930150100 |
| Galet de la Route | compte (toute série compte) | compte | `seances_chemin()` (20260920120000) |
| Pièces | payées (une ligne = une série) | payées | `cloturer_seance` compte les lignes |
| Widget Régularité | compte les séries | compte | `widget_regularite.series` |

## Ce qui manque

1. **Widget Record (`widget_peak`)** : `where s.weight > 0` — un exercice au sol n'a JAMAIS de record. Choix du 30-09 (« le poids du corps n'y entre pas »).
2. **Widget Volume (`widget_volume`)** : le volume est en kg × reps ; un exercice au sol y vaut 0 et tombe hors du top 3. Rien ne dit « 3:20 tenus » ni « 60 reps ».
3. **Île pendant le repos d'un gainage** : aucune ligne de détail (on pourrait dire « 0:45 »).

## La règle proposée (la même grammaire que la courbe de la fiche : kg, reps ou secondes)

1. **Record** : chaque exercice au sol a son record dans SA mesure — gainage = le plus long temps tenu en une série, crunch/chevilles = le plus de reps en une série. Même logique que la charge : précédent record, « premier » sans delta, le meilleur progrès en tête. Pas d'e1RM hors charge. App : « 1:30 » / « 25 reps » au lieu de « kg ».
2. **Volume** : les kg restent des kg (aucun kg inventé au poids du corps). La liste des exercices montre aussi les exercices au sol avec leur total : « Gainage · 3:20 tenus », « Crunch au sol · 60 reps ».
3. **Île** : au repos d'un gainage, « 0:45 » (le temps tenu).

## Le geste

- Migration : `widget_peak` et `widget_volume` lisent `exercices.saisie` et `strength_sets.duree_s` ; réponse enrichie (`saisie`, `secondes`, `mesure`), compatible avec l'app actuelle (les champs anciens ne changent pas pour la muscu chargée).
- App : `ChambreServeur.peak/volume` + les vues qui écrivent « kg » ; `WorkoutLivePhase` + `detail`.
- Mesure : sonde avec le jeton du compte de test (une séance gainage + crunch + charge), réponses lues ; bancs Swift ; site (`b-tb-strength-sets`, widgets, `b-saisie-poids-du-corps`) dans le même commit.
- Rien n'est posé au serveur sans son « go ».
