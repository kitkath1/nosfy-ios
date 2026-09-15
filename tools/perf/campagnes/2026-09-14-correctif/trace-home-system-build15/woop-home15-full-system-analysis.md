# Home normale build15 — attentes main comparées au prototype B11

Analyse en lecture seule, sans action d'appareil, build ni modification de source. Deux preuves distinctes : journal du lancement à 09:06:34, puis System Trace à 09:14:23.305–09:14:32.571 +02:00 le 15 septembre 2026. Elles ne décrivent pas la même fenêtre thermique.

## Résultat principal

**La Home normale reproduit les attentes Core Animation / RenderBox observées dans le prototype B11.** Le prototype natif n'est donc pas nécessaire pour observer ce mécanisme. Dans la nouvelle trace, quatre microhangs de **250,706 à 435,976 ms** coïncident exactement avec les plages où le main ne revient pas en attente d'événements. Le main passe **6,110 s explicitement Blocked** dans les appels de synchronisation identifiés, sur **8,729 s** où son état est attribué.

Les appels montrent `CAContext.waitForCommitId`, `RB::SharedSurfaceGroup::wait_for_allocations`, `RBLayer.display`, et un mutex également utilisé par les workers `SharedSurfaceGroup::prune_removed_locked`. Ils n'identifient toujours pas un calque applicatif précis, le processus distant attendu ou une saturation GPU.

## Contexte exact de la nouvelle trace

- Source `/private/tmp/woop-home15-full-system.trace`, Woop PID **17908**, main TID **1445303** (`0x160db7`). Durée totale **9,265953063 s**.
- Home réelle, ambiance complète et protection temporairement désactivée : contexte communiqué par root. Aucun prototype liseré natif demandé pour cette capture.
- Table thermique : **Serious, non induit, sur 100 % de la trace**. Cette trace ne doit pas être présentée comme une capture en état thermique nominal.
- Exports non vides : thread-state **25 114** lignes, thread-narrative **40 970**, syscall **15 994**, potential-hangs **4**, runloop-events **3 403**. Résolution complète des références XML `id/ref` avant attribution.
- Sur main : 7 418 intervalles d'état, 6 508 syscalls, 2 393 événements runloop. États attribués de **0,537285375 à 9,265953063 s** ; Running **797,772 ms**, Blocked **7 898,465 ms**. Blocked comprend aussi les attentes normales d'événements, contrairement aux 6,110 s isolées ci-dessous.

## Les quatre microhangs

Temps relatifs au début de trace ; les quatre bornes correspondent exactement, à la nanoseconde, aux plages runloop entre fin et reprise de `waiting_for_events`.

| Début microhang (s) | Durée (ms) | Attente dominante du main | Début syscall (s) | Durée syscall (ms) |
|---:|---:|---|---:|---:|
| 0,564919375 | 435,975958 | Mach sous `Context::ping / waitForCommitId` | 0,575353083 | 424,149417 |
| 1,297185541 | 374,333125 | Mutex sous `Context::synchronize / waitForCommitId` | 1,299449875 | 370,435625 |
| 1,863187666 | 393,145209 | Mach sous `Context::ping / waitForCommitId` | 1,878794125 | 375,911791 |
| 2,295815750 | 250,705916 | Mach sous `Context::ping / waitForCommitId` | 2,297913416 | 247,239167 |

Stack principale commune, feuille vers racine :

```text
mach_msg2_trap → [deux frames libsystem_kernel non symboliquées]
CA::Context::ping()
-[CAContext waitForCommitId:timeout:]
RB::CommitMarker::Observer::test_displayed(bool, double)
RB::SharedSurfaceGroup::wait_for_allocations(RB::SharedSurfaceClient&)
RB::SharedSurfaceGroup::add_subsurface(...)
-[RBLayer displayWithBounds:callback:] → -[RBLayer display]
CA::Layer::layout_and_display_if_needed(CA::Transaction*)
CA::Context::commit_transaction(...) → CA::Transaction::commit()
CA::Transaction::flush_as_runloop_observer(bool)
_UIApplicationFlushCATransaction → ... → __CFRunLoopRun
```

Dans le deuxième microhang, le sommet devient `psynch_mutexwait → _pthread_mutex_firstfit_lock_slow → CA::Context::synchronize → waitForCommitId`, puis reprend la même chaîne RenderBox. Le worker **0x1612a5** attend lui-même **370,476333 ms**, de t=1,299385333 à 1,669861666 s, dans `mach_msg2_trap → Context::ping → waitForCommitId → SharedSurfaceGroup::test_markers → prune_removed_locked`. Il déverrouille le **même mutex 0x10a2388d0** à 1,669870125 s, avant le retour du syscall mutex main à 1,669885500 s. Les adresses de mutex sont propres à chaque exécution et ne se comparent pas entre builds.

## Comparaison précise avec B11

| Indicateur | B11 prototype natif animé | Home15 normale, ambiance complète |
|---|---:|---:|
| Durée totale trace | 9,071008 s | 9,265953 s |
| Fenêtre avec états main attribués | 8,521980 s | 8,728668 s |
| Main Running | 353,416 ms | 797,772 ms |
| Syscalls main portant `waitForCommitId` | 142 / 1 018,258 ms | 335 / 5 427,843 ms |
| Mutex main sous `commit_transaction` | 48 / 5 242,540 ms | 18 / 1 056,849 ms |
| Attente queue commit handlers | 32 / 14,916 ms | 304 / 5,744 ms |
| **Union** temporelle de ces appels | **6 275,714 ms** | **6 119,990 ms** |
| État **Blocked** dans cette union | **6 269,160 ms** | **6 109,582 ms** |
| Microhangs >250 ms | 4 | 4 |
| Plages runloop hors attente d'événements >100 ms | 26 / 6 030 ms | 16 / 3 499,373 ms |

Les catégories de syscalls **ne s'additionnent pas** : dans Home15, le mutex de 370,436 ms porte aussi `waitForCommitId`. L'union ci-dessus déduplique les intervalles. B11 attendait surtout le mutex de commit détenu par un worker ; Home15 attend plus souvent directement les marqueurs d'affichage. Le chemin SharedSurface/Core Animation et la synchronisation avec les workers sont communs. Cette comparaison ne constitue pas un benchmark contrôlé des performances des deux builds.

## Preuve distincte : symptômes en état thermique nominal

Sources `/private/tmp/woop-build15-home-froid-vol.jsonl`, `-nav.jsonl`, `-sources.json`, issus de `vol-20260915-090634.jsonl`.

- **t=1,0–47,5 s : therm=0, protection=0**. À t=6,5 / 7,9 / 15,5 s, le journal enregistre des intervalles maximaux entre callbacks de **870 / 1085 / 905 ms**.
- Même après les premières secondes : **27 relevés entre t=20,6 et47,5 s**, encore therm0/protection0 ; médiane **29,3 callbacks/s**, intervalle maximal **417 ms**, médiane CPU **13 %**.
- Premier relevé de protection active à **t=48,5 s**, également premier therm1. Puis **161 relevés entre t=49,5 et211,9 s** : médiane **60,1 callbacks/s**, intervalle maximal **67 ms**, médiane CPU toujours **13 %**.

Ces `img` sont les callbacks mesurés par la sonde, pas un décompte de présentations GPU. Le journal prouve que l'état thermique élevé n'est pas une condition nécessaire aux symptômes ; il ne contient pas de stacks d'attente à therm0. Les stacks de la trace Serious ne doivent donc pas être rétro-attribuées aux pauses froides comme si elles avaient été capturées simultanément. L'amélioration après protection indique une piste de travail sur ce qu'elle met au repos, sans attribuer le problème à un composant isolé ni conclure sur la charge GPU.

## Artefacts reproductibles

- `/private/tmp/woop-home15-full-system-toc.xml`, exports `-thread-state.xml`, `-thread-narrative.xml`, `-syscall.xml`, `-potential-hangs.xml`, `-runloop-events.xml`, `-device-thermal-state-intervals.xml`.
- `/private/tmp/woop-home15-full-system-analyse.py` : adaptation du parseur B11 au PID17908 ; `-analysis.json`, `-analysis.txt`, `-main-resolved.json`.
- `/private/tmp/woop-home15-full-system-sync-analyse.py` : catégories, union d'intervalles et corrélation workers ; `-sync-summary.json`, `-sync-groups.json`, `-sync-analysis.txt`, `-workers.json`.
- `/private/tmp/woop-home15-full-runloop-analyse.py`, `-analysis.json`, `-intervals.json` : appariement START/END par type, mode, nesting, identifiant et runloop.
- Comparaison antérieure : `/private/tmp/woop-lisere11-system-analysis.md` et `/private/tmp/woop-lisere11-runloop-analysis.md`.
