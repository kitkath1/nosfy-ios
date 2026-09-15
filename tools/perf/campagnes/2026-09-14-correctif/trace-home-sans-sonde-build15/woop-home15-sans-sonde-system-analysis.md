# Home build15 sans SondeVol — les attentes CA/RenderBox persistent

Analyse locale de la capture enregistrée par root. Aucune action d'appareil, aucun build ni modification du dépôt.

## Verdict

**Le CADisplayLink de SondeVol n'est pas nécessaire au mécanisme observé.** Sans SondeVol, la Home présente encore `CAContext.waitForCommitId → RB::SharedSurfaceGroup::wait_for_allocations → add_subsurface → RBLayer.display → commit_transaction`. Le fil principal passe **5.463563 s explicitement Blocked** dans l'union des synchronisations CA identifiées, sur **8.777865 s attribuées** (62.24 %). Un microhang de **306.643792 ms** porte exactement cette chaîne.

Cette observation exclut la sonde comme cause unique nécessaire, mais ne mesure pas son influence marginale : les captures sont successives, la première en thermique Serious, celle-ci en Fair. Ce n'est pas un A/B quantitatif à conditions identiques. System Trace reste attaché dans les deux cas. Aucune attribution à un calque applicatif précis ni preuve de saturation GPU n'en découle.

## Contexte

- Trace `/private/tmp/woop-home15-sans-sonde-system.trace`, PID **18446**, main TID **1488753 / 0x16b771**.
- Dates TOC : **2026-09-15 10:02:50.925–10:03:00.175 +02:00**, durée précise **9.250294923 s**.
- Thermique exportée : **Fair, non induit, pendant toute la trace**.
- Arguments communiqués par root : `-sansSondeVol -openTab home -sansProtectionThermique`, sans `-navProbe`. Home assertée par le test `test15-sans-sonde.log` PASS, selon root ; je n'ai pas relancé ni inspecté l'appareil.
- Vérification source : `SondeVolBanc.actif` renvoie false pour `-sansSondeVol` et WoopApp ne monte/démarre le HUD et la sonde que si actif. Le CADisplayLink distinct `SondeCadence` nécessite `-fps`, absent des arguments communiqués. Le compteur et ses journaux ne sont donc pas disponibles pour fournir un chiffre callbacks/s sur cette capture.
- Journal `/private/tmp/woop-home15-sans-sonde-system.log` vérifié : capture terminée et fichier enregistré avant export.

## Résolution et chiffres

Tous les exports XML sont résolus par leurs références `id/ref` avant attribution au PID/main.

- Lignes exportées : thread-state **30872**, thread-narrative **48802**, syscall **18158**, potential-hangs **1**.
- Main : **9234** intervalles d'état et **6983** syscalls.
- Fenêtre attribuée : **0.472430416–9.250294923 s**.
- Main Running **899.180783 ms** ; Blocked total **7838.166583 ms**. Le total Blocked inclut les attentes normales d'événements et ne doit pas être assimilé aux seules attentes de rendu.
- **430** syscalls main portant `waitForCommitId`, tous également sous `wait_for_allocations`, durée cumulée **4967.586788 ms**. Six dépassent 100 ms (230.219, 115.395, 231.371, 120.416, 303.404, 133.793 ms).

## Microhang identifié

Début **5.631108041 s**, durée **306.643792 ms**. Le syscall principal commence à **5.633620083 s** et dure **303.403917 ms** ; l'état Blocked pendant l'ensemble du microhang vaut **303.350292 ms**.

Stack du syscall, feuille vers racine :

```text
mach_msg2_trap (nom de syscall ; trois frames noyau non symboliquées)
CA::Context::ping()
-[CAContext waitForCommitId:timeout:]
RB::CommitMarker::Observer::test_displayed(bool, double)
RB::SharedSurfaceGroup::wait_for_allocations(RB::SharedSurfaceClient&)
RB::SharedSurfaceGroup::add_subsurface(...)
-[RBLayer displayWithBounds:callback:]
-[RBLayer display]
CA::Layer::layout_and_display_if_needed(CA::Transaction*)
CA::Context::commit_transaction(...)
CA::Transaction::commit()
CA::Transaction::flush_as_runloop_observer(bool)
_UIApplicationFlushCATransaction
```

## Comparaison descriptive avec la trace Home15 avec sonde

| Indicateur | Avec sonde, 09:14, Serious | Sans sonde, 10:02, Fair |
|---|---:|---:|
| Fenêtre main attribuée | 8.728668 s | 8.777865 s |
| Main Running | 797.772 ms | 899.181 ms |
| Syscalls main portant waitForCommitId | 335 / 5427.843 ms | 430 / 4967.587 ms |
| Mutex main sous commit_transaction | 18 / 1056.849 ms | 21 / 505.490 ms |
| Attente queue commit handlers | 304 / 5.744 ms | 357 / 3.583 ms |
| Union temporelle des appels CA | 6119.990 ms | 5476.660 ms |
| État Blocked dans cette union | 6109.582 ms | 5463.563 ms |
| Microhangs >250 ms | 4 | 1 |

Les catégories ne doivent pas être additionnées : l'union déduplique les chevauchements. L'écart de nombres/durées ne quantifie pas l'effet de la sonde, notamment à cause de l'état thermique différent. La conclusion robuste est la persistance de la même chaîne d'attente sans elle.

## Reproduction

Exports : `/private/tmp/woop-home15-sans-sonde-system-toc.xml`, `-potential-hangs.xml`, `-device-thermal-state-intervals.xml`, `-thread-state.xml`, `-thread-narrative.xml`, `-syscall.xml`.

Parseurs : `/private/tmp/woop-home15-sans-sonde-system-analyse.py` et `-sync-analyse.py`, adaptés des outils Home15 de l'agent energy au PID18446. Le second importe le premier et produit les JSON d'analyse, les intervalles main résolus et le résumé des unions. Commande locale :

```sh
python3 /private/tmp/woop-home15-sans-sonde-system-sync-analyse.py
```

Résultats principaux : `-analysis.json`, `-main-resolved.json`, `-sync-summary.json`, `-sync-groups.json`, `-workers.json`, `-sync-analysis.txt`. Comparaison initiale : `/private/tmp/woop-home15-full-system-analysis.md`.
