# 22-09 — le tirage de la home, mesuré sur son iPhone (Wi-Fi, sans câble)

**Installé** : Release de l'arbre du 22-09 08:50 (les correctifs du 21-09 + le retour
court à chaud), par `devicectl` en Wi-Fi, lancée `-sondeVol -navProbe -ecranEveille`.
**Parcours** : elle, seule, sans consigne de timing : deux appuis Exercices/Home
(t 12-19), puis trois tirages de la home à la suite (t 31-41). Son verdict après :
« c'est pas encore super fluide ». Aucune marque (elle n'a pas tapé la capsule).
**Thermique : 0 pendant tout le relevé** — le téléphone était froid ; les portes
« à chaud » posées le matin n'ont donc rien changé à ce qu'elle a vu.

## Les trois tirages (journal de navigation)

| t | événement | e |
|---|---|---|
| 31,27 | prise (le film part) | 0,00 |
| 33,23 | prise (le doigt attrape le film presque fini) | 1,81 |
| 33,35 | fermeture (0,12 s de doigt ont ramené la scène) | 0,15 |
| 34,12 | prise | 0,00 |
| 36,47 | prise (tiroir ouvert) | 1,95 |
| 36,55 | fermeture | 0,54 |
| 37,29 | prise | 0,00 |
| 39,93 | prise (tiroir ouvert) | 1,95 |
| 40,01 | fermeture | 0,35 |

Chaque cycle : tirer (le film de 1,95 s joue), reprendre aussitôt, relâcher (fermeture
0,375 à 0,45 s). Aucun état orphelin, aucun film qui traîne : les deux correctifs du 20-09
tiennent, et le retour court aussi (il ne s'applique qu'à chaud, ici c'est la
proportion `max(e/T, 0,30)` qui a fait les 0,375 s).

## La sonde pendant ces dix secondes

| t | img/s | pire | cpu | tics film (4) | tics galets (2) |
|---|---|---|---|---|---|
| 31,5 | 59,1 | 30 ms | 33 % | 13 | 12 |
| 32,5 | **60,1** | 17 ms | 38 % | 60 | 0 |
| 33,5 | 54,3 | **67 ms** | 50 % | 59 | 23 |
| 34,5 | 57,1 | **50 ms** | 33 % | 38 | 55 |
| 35,6 | **60,1** | 17 ms | 37 % | 61 | 0 |
| 36,6 | **60,1** | 17 ms | 27 % | 46 | 0 |
| 37,6 | 53,2 | **67 ms** | 31 % | 39 | 53 |
| 38,6 | **60,1** | 17 ms | 38 % | 61 | 0 |
| 39,6 | **60,1** | 17 ms | 30 % | 49 | 0 |
| 40,6 | 43,3 | **183 ms** | 25 % | 24 | 49 |

Lecture, sans rien deviner :
- **Le film lui-même tient 60 images par seconde** (32,5 · 35,6 · 36,6 · 38,6 · 39,6 :
  pire 17 ms, l'horloge à 60 tics), pour 27-38 % d'un cœur — c'est le coût de la page
  entière reconstruite à chaque image (la loi « redessiner pour animer »).
- **Les à-coups sont aux TRANSITIONS**, jamais au milieu du film : la seconde de la
  prise/fermeture (33,5 · 34,5 · 37,6 : 50-67 ms) et l'atterrissage du dernier retour
  (40,6 : **183 ms**). À chacun de ces instants les galets rejouent (tics 2 = 23-55, à 0
  pendant le film) et le verre natif se démonte ou se remonte (`verreMonte`, et les
  widgets remontés à `net ≥ 0,995`). C'est ce qu'elle sent comme « pas super fluide » :
  une image de 50 à 183 ms au moment où elle attrape et au moment où ça se pose.
- Home immobile avant et après : 60,1 img/s, 5-10 % — rien ne traîne après le geste.

## Ce que ce relevé NE dit PAS

- Rien sur le téléphone CHAUD : c'est là qu'elle décrit « plusieurs secondes de blur »
  (le gel documenté BUG-CHAUFFE-GEL-HOME). À reproduire thermique ≥ 1, capsule tapée.
- Il ne désigne pas lequel des deux (galets qui rejouent, verre remonté) pèse le plus :
  il faut un barreau par piste et un A/B, ou une trace SwiftUI « View Body ».

## Suites proposées (rien de posé)

1. Pendant le film et ses transitions, les galets de la card Route ne rejouent pas
   (ils sont floutés/en mouvement, personne ne les lit) — barreau `-galetsFilm`.
2. Ne plus démonter/remonter le verre des widgets au seuil `net ≥ 0,995` en fin de
   retour (le 183 ms) : le garder monté et le couvrir — à montrer, le verre natif
   ignore l'opacité (loi payée).
3. Les générateurs haptiques créés à la volée au cran et au lâcher : `prepare()` une
   fois, réutiliser.
