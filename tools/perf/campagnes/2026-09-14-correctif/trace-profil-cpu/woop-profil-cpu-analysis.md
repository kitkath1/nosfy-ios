# Time Profiler réel — build 5, Profil avec Réglages ouvert

**Constat : le travail CPU échantillonné est majoritairement sur le fil principal (74,67 %), dans SwiftUI/AttributeGraph et le runtime Swift.** Ce relevé montre du travail CPU récurrent ; il ne démontre pas une attente du GPU ni la cause précise d’un geste perdu.

## Périmètre et méthode

- Source : `/private/tmp/woop-profil-cpu-build5-samples.xml`, export de `/private/tmp/woop-profil-cpu-build5.trace`, processus Woop PID 13696 sur l’iPhone réel. Contexte fourni et vérifié par capture : **Profil avec le panneau Réglages ouvert**, pas Home nue.
- La sonde d’onglet ne décrit pas les panneaux superposés. Le relevé du matin annoncé « Home, CPU 28, thermique 1 » correspondait à la fenêtre « Welcome back / +10 » ouverte : il ne constitue pas un témoin Home immobile nue.
- Parseur reproductible : `/private/tmp/woop-profil-cpu-analyse.py`. Chaque `id/ref` des lignes, threads, piles, cadres et binaires est résolu avant comptage ; 14 280 identifiants uniques, aucune référence manquante. Données calculées : `/private/tmp/woop-profil-cpu-analysis.json` ; piles entièrement résolues : `/private/tmp/woop-profil-cpu-resolved-samples.json`.
- **3 829 échantillons, chacun de poids 1 ms**, tous déclarés `Running`, 9 threads, tous PID 13696. 3 828 piles et 1 sentinelle sans pile. Les 3 829 ms sont des poids de CPU échantillonné, pas une durée d’attente.
- Premier échantillon à 0,341881 s ; dernier à 9,753880 s, soit 9,412 s entre les extrêmes. La consigne d’enregistrement « 8 s » ne donne donc pas le dénominateur exact : aucun taux CPU de la trace n’est calculé ici à partir de 8 s.
- « Feuille » = binaire du premier cadre, attribution exclusive. « Inclusif » = présence du binaire quelque part dans la pile, comptée **une seule fois par échantillon**, même si récursive. Les pourcentages inclusifs se recouvrent et ne s’additionnent pas.

## Répartition des threads

| Groupe | Poids échantillonné | Part du total |
|---|---:|---:|
| Main Thread, tid 1130238 | 2 859 ms | 74,67 % |
| 8 autres threads | 970 ms | 25,33 % |
| dont thread nommé `com.apple.scenekit.scnview-renderer` | 24 ms | 0,63 % |

SceneKit intervient aussi sur d’autres workers : limiter son coût au seul thread portant son nom le sous-estimerait. Les 3 829 échantillons sont attribués aux quatre E cores dans cet export ; ce fait n’explique pas à lui seul la politique d’ordonnancement ou le niveau thermique.

## Binaires dominants, tous threads

Pourcentages rapportés aux 3 829 ms. Les racines de boucle système en inclusif indiquent un chemin d’appel, pas leur propre coût exclusif.

| Binaire | Feuille (ms) | Feuille (%) | Inclusif (ms) | Inclusif (%) |
|---|---:|---:|---:|---:|
| libswiftCore | 566 | 14,78 | 717 | 18,73 |
| SwiftUICore | 532 | 13,89 | 2 358 | 61,58 |
| AttributeGraph | 504 | 13,16 | 1 278 | 33,38 |
| libobjc | 279 | 7,29 | 294 | 7,68 |
| QuartzCore | 248 | 6,48 | 2 675 | 69,86 |
| libsystem_pthread | 232 | 6,06 | 1 004 | 26,22 |
| libsystem_malloc | 208 | 5,43 | 209 | 5,46 |
| libsystem_kernel | 190 | 4,96 | 190 | 4,96 |
| CoreFoundation | 118 | 3,08 | 2 914 | 76,10 |
| SceneKit | 113 | 2,95 | 314 | 8,20 |
| RenderBox | 70 | 1,83 | 300 | 7,83 |
| UIKitCore | 51 | 1,33 | 2 856 | 74,59 |
| SwiftUI | 38 | 0,99 | 2 860 | 74,69 |
| Woop | 2 | 0,05 | 2 860 | 74,69 |

Autres feuilles notables : IOKit 146 ms (3,81 %), libsystem_platform 101 ms (2,64 %), libdispatch 96 ms (2,51 %), AGXMetalG15 79 ms (2,06 %). Autres chemins inclusifs : UpdateCycle 2 636 ms (68,84 %), dyld 2 856 ms (74,59 %), GraphicsServices 2 856 ms (74,59 %), Metal 269 ms (7,03 %), IOGPU 265 ms (6,92 %).

## Travail effectivement observé sur le main

Pourcentages rapportés aux 2 859 ms du main.

| Binaire | Feuille (ms) | Feuille (%) | Inclusif (ms) | Inclusif (%) |
|---|---:|---:|---:|---:|
| libswiftCore | 563 | 19,69 | 714 | 24,97 |
| SwiftUICore | 532 | 18,61 | 2 358 | 82,48 |
| AttributeGraph | 504 | 17,63 | 1 278 | 44,70 |
| QuartzCore | 220 | 7,69 | 2 602 | 91,01 |
| libobjc | 200 | 7,00 | 209 | 7,31 |
| libsystem_malloc | 170 | 5,95 | 171 | 5,98 |

Les trois premières feuilles représentent **1 599 ms, soit 55,93 % du main**. Elles sont échantillonnées tout au long de l’enregistrement : dans chaque seconde complète de t=1 à t=9, elles totalisent 161 à 183 ms ; le main entier totalise 283 à 342 ms par seconde. Il ne s’agit donc pas seulement d’une unique pointe d’ouverture observée au début.

Sur les workers, principales feuilles : pthread 196 ms, SceneKit 112 ms, IOKit 98 ms, kernel 95 ms, dispatch 93 ms, objc 79 ms, AGXMetalG15 57 ms. Chemins inclusifs : SceneKit 313 ms (32,27 % des workers), Metal 191 ms, IOGPU 190 ms, AGXMetalG15 110 ms et RenderBox 108 ms. SceneKit est présent dans chaque seconde de la trace. Cela prouve du travail CPU associé à cette pile pendant ce panneau ; cela n’identifie pas la vue responsable ni une dépense inutile sans connaître son état visuel.

## Limites d’attribution et décision utile

Aucun nom de fonction de cet XML n’est symboliqué : les noms de cadres sont tous hexadécimaux. 45 ms de feuilles ont un binaire inconnu, plus 1 ms sans pile. Le binaire Woop porte l’UUID `6C0F7D6E-E380-369E-9437-0E1F42908373`, architecture arm64, base `0x100c84000`. Le dSYM local courant dans `woop-chauffe-dd` porte un autre UUID (`757CEBC3-43AE-32E2-9F2F-48B64251F1CA`, build ultérieur) ; il n’a pas été utilisé.

Le cadre Woop `0x1013d2124`, présent dans 2 856 ms de piles, se trouve à leur racine près du lancement de la boucle App/SwiftUI. **Son poids inclusif n’est pas le coût d’un corps de fonction applicative à optimiser.** Les deux plus fréquents autres cadres Woop sont `0x10129a028` (22 ms inclusifs) et `0x101299920` (21 ms). Sans dSYM correspondant, leur attribuer un nom serait inventé. Les 2 ms de feuilles Woop n’excluent pas une cause applicative : une vue peut provoquer beaucoup de travail dans les frameworks.

Ce relevé justifie d’examiner les mises à jour SwiftUI/AttributeGraph et les producteurs d’invalidation actifs pendant Profil + Réglages. Il ne permet pas de nommer l’observable fautif, d’attribuer le travail SceneKit à une vue précise ou de conclure sur le GPU. Des échantillons `Running` dans un pilote ou un noyau ne mesurent ni l’occupation GPU, ni la durée d’un blocage hors CPU. La Home nue et les interactions doivent être mesurées dans leur propre état visuel, puis comparées après une modification ciblée.
