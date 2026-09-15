# Fond Metal build 17 — lecture longue et deux boucles réelles

Campagne root du 15 septembre 2026 : lancement 10:29:27, première sélection Nav 10:29:28,400732, Woop PID18831. Sources `/private/tmp/woop-build17-metal-long-{vol,nav}.jsonl` : 87 lignes SondeVol jusqu'à t88,6, 113 événements Nav jusqu'à environ+90,8s, dont 19 diagnostics `fond-metal`. Les deux fichiers sont collectés successivement ; leurs fins diffèrent donc légèrement.

**Les deux vidéos franchissent deux boucles et continuent à alimenter le GPU. Le bénéfice contre les longs gels est également observé à thermique 2 : pire trou 154ms sur la fenêtre 15–80s, contre des trous >2s dans la référence 17 précédente au même niveau thermique. La fluidité 60 n'est pas atteinte ; l'économie d'énergie n'est pas démontrée. Ce prototype ne constitue pas encore une résolution générale de la chauffe.**

## Boucles : progression réelle des deux outputs

Tous les 19 diagnostics indiquent `deuxVideos=true`, sans retour au poster observé. Les dimensions sont toujours 604×642 pour la braise, 1206×964 pour la pilule ; drawable 1179×1980, BGRA8. Les compteurs restent monotones.

| Intervalle depuis première sélection Nav | Timestamp vidéo des deux flux | Nouvelles images braise / pilule | Command buffers terminés |
|---|---|---:|---:|
| +35,633→40,582s | 35,167→4,417s | +95 / +94 | +126 |
| +70,733→75,760s | 34,542→3,792s | +115 / +115 | +141 |

Chaque retour de timestamp est cohérent avec une boucle de 35,791667s : en ajoutant une durée de fichier, l'avance vidéo entre ces diagnostics est 5,041667s. Les compteurs croissants écartent ici une simple remise à zéro du renderer ou un poster conservé. Les checkpoints espacés d'environ 5s démontrent le franchissement ; ils ne démontrent pas un raccord visuellement parfait ni l'absence d'une image répétée/perdue au raccord.

Dernier événement : gpuComplete2467, b1898, p1899 ; les deux timestamps sont18,833s après deux boucles. Depuis le premier buffer, 90,416334s de temps vidéo se sont écoulées pour 90,434867s entre publications Nav : cadence temporelle globale proche de 1×, avec les limites de timestamp ci-dessous.

## Trois cadences à distinguer

- Régime +15,442→85,773s : **27,43 command buffers terminés/s**, **21,03 nouvelles images braise/s**, **20,99 nouvelles images pilule/s**.
- Avant la période TimeProfiler, +15,442→60,712s : 27,46 completions/s et 21,18/21,10 nouvelles images/s.
- Source vidéo 24fps ; MTKView demande 24 mais aboutit ici à une cadence de rendu voisine de27–30 selon les périodes. Les nouveaux buffers consommés sont environ 21/s, donc la cadence de la source n'est pas intégralement restituée par ce banc.

Une completion prouve le travail GPU terminé pour le command buffer, pas sa présentation à l'écran. Nav écrit l'événement sur le main après la completion ; des délais de publication peuvent déplacer ses bornes. Les quotients sur des dizaines de secondes sont des estimations de débit, pas des mesures de présentation. `img` dans SondeVol mesure encore autre chose : les callbacks CADisplayLink de l'interface.

## Interface et période de profilage

TOC `/private/tmp/woop-metal17-cpu-toc.xml` : TimeProfiler 10:30:36,479→10:30:45,726, durée 9,246915s, soit +68,078→77,325s depuis la première sélection Nav. Cette origine est proche du lancement de Sonde mais n'est pas son horodatage t0 explicitement publié ; les fenêtres choisies hors capture gardent une marge.

| Fenêtre Sonde | n | Callbacks médians/s | CPU médian | Pire trou publié | Thermique / protection |
|---|---:|---:|---:|---:|---|
| 15–45s | 30 | 50,8 | 24% | 154ms | 2 / 0 partout |
| 15–65s, avant TimeProfiler | 49 | 50,4 | 24% | 154ms | 2 / 0 partout |
| 45–65s, avant TimeProfiler | 19 | 50,2 | 24% | 67ms | 2 / 0 partout |
| 15–80s, inclut TimeProfiler | 64 | 49,25 | 24% | 154ms | 2 / 0 partout |
| 80–89s, après TimeProfiler | 9 | 40,8 | 22% | 72ms | 2 / 0 partout |

Aucun `gel=1` dans ces fenêtres. Le niveau thermique 2 est persistant et l'interface demeure sous 60 callbacks/s. Le CPU de 24% ne mesure pas la puissance totale ; comparer à la référence gelée à 2% CPU ne permet pas de conclure sur l'énergie. La référence 17 était une autre exécution, au même niveau thermique catégoriel 2, pas un état thermique/GPU strictement identique. Cette comparaison est encourageante pour la suppression des grands trous mais reste un banc opt-in au repos, sans validation complète des transitions ni du dessin.

## Limite de la trace système

Le paquet System 17 a été interrompu pendant la sauvegarde par un timeout 50s. Son export échoue code 10, « Trace is malformed; instrument run data is missing ». Il n'existe donc aucune comparaison d'attentes CA/RenderBox 17 versus 15 à rapporter. Voir `/private/tmp/woop-metal17-system-analysis.md`. Le TimeProfiler 17 réussi est analysé séparément par l'agent galet ; ses échantillons Running ne mesurent pas les durées d'attente.

Calcul reproductible : `python3 /private/tmp/woop-metal17-loop-analyse.py`, détail `/private/tmp/woop-build17-metal-long-loop-analysis.json`. Analyse locale seulement : aucun appareil, build ou fichier source modifié.
