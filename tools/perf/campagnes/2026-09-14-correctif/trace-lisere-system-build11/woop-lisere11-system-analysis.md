# System Trace — liseré Core Animation animé, build 11

Trace réelle : `/private/tmp/woop-lisere11-native-system.trace`, Woop PID 17521, fil principal TID 1412807 (`0x158ec7`). Enregistrement du 15 septembre 2026, **08:29:18.603–08:29:27.674 +02:00**, durée 9,071008 s. Cette capture concerne le prototype B11 animé, pas la Home de référence antérieure. Aucun appareil, build ou fichier source modifié pendant cette analyse.

## Conclusion étayée

**Le fil principal attend effectivement des synchronisations Core Animation / RenderBox pendant les saccades.** Les quatre microhangs détectés par Instruments durent 366,771 à 415,900 ms. Les trois premiers sont dominés par une attente de mutex dans `CA::Context::commit_transaction`; le quatrième par un appel Mach sous `CAContext.waitForCommitId`, lors de l'allocation de sous-surfaces RenderBox.

Le parcours des workers précise la chaîne : pendant les trois attentes de mutex main, un worker est lui-même dans `CA::Context::ping → waitForCommitId → RB::SharedSurfaceGroup::test_markers → prune_removed_locked`. Ce worker déverrouille ensuite **le même mutex `0x10b78c010`**, juste avant le retour du main. La trace révèle ainsi une dépendance concrète de présentation/synchronisation, sans identifier le calque responsable ni démontrer une saturation GPU.

## Quatre pauses mesurées

Temps relatifs au début de la trace ; les périodes de microhang correspondent **exactement à la nanoseconde** aux quatre plus longues plages main entre fin et début d'attente d'événements runloop.

| Début microhang (s) | Durée microhang (ms) | Attente dominante sur main | Début syscall (s) | Durée syscall (ms) | Temps main Blocked dans le microhang (ms) |
|---:|---:|---|---:|---:|---:|
| 2,996560000 | 366,771375 | `psynch_mutexwait` sous `commit_transaction` | 2,998598958 | 362,989792 | 362,955125 |
| 5,359178083 | 367,279292 | Même mutex | 5,360823416 | 364,552000 | 364,536750 |
| 5,758756666 | 383,829084 | Même mutex, puis attente de queue | 5,760484916 | 367,680000 | 381,344624 |
| 7,988506000 | 415,900333 | `mach_msg2_trap` sous `waitForCommitId` | 7,990201583 | 413,505292 | 413,442166 |

Dans le troisième microhang, `kevent_id` ajoute ensuite **13,688583 ms** à t=6,128297083 s, sous `_dispatch_event_loop_wait_for_ownership → __DISPATCH_WAIT_FOR_QUEUE__ → _dispatch_sync_f_slow → CA::Transaction::run_commit_handlers → commit_transaction`.

Stack main des trois mutex, de la feuille vers la racine :

```text
psynch_mutexwait
_pthread_mutex_firstfit_lock_slow
CA::Context::commit_transaction(CA::Transaction*, double, double*)
CA::Transaction::commit()
CA::Transaction::flush_as_runloop_observer(bool)
_UIApplicationFlushCATransaction
__setupUpdateSequence_block_invoke_2
_UIUpdateSequenceRunNext
schedulerStepScheduledMainSectionContinue
UC::DriverCore::continueProcessing()
__CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__
__CFRunLoopDoSource0 → __CFRunLoopDoSources0 → __CFRunLoopRun
```

Stack de l'attente main de 413,505292 ms :

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
```

## Workers corrélés aux trois attentes de mutex

| Microhang main (s) | Worker TID | Début appel Mach worker (s) | Durée appel (ms) | Déverrouillage même mutex (s) |
|---:|---|---:|---:|---:|
| 2,996560000 | `0x159348` | 2,993153750 | 368,398916 | 3,361561375 |
| 5,359178083 | `0x159354` | 5,355593125 | 369,741166 | 5,725345458 |
| 5,758756666 | `0x159354` | 5,755010583 | 373,130000 | 6,128150416 |

Chaque appel Mach worker porte la pile `CA::Context::ping → waitForCommitId → Observer::test_displayed → SharedSurfaceGroup::test_markers → prune_removed_locked → dispatch`. Les syscalls de déverrouillage portent `psynch_mutexdrop → _pthread_mutex_firstfit_unlock_slow → CA::Context::ping`, avec l'argument mutex identique à l'attente main. L'adresse du mutex est locale à cette exécution.

## Étendue du phénomène et limites

- `thread-state` attribue le main de t=0,549027500 à 9,071007966 s, soit **8,521980466 s** : Running **353,416 ms**, Blocked **8 148,896 ms**, Runnable 7,252 ms, Interrupted 10,785 ms, Preempted 1,632 ms. Le total Blocked inclut aussi l'attente normale d'événements ; il ne doit pas être présenté comme une durée totale de gel.
- Sur main : **48** `psynch_mutexwait` sous `commit_transaction`, durée cumulée **5 242,539919 ms** ; **142** syscalls portant `waitForCommitId`, **1 018,258211 ms** ; **32** `kevent_id` sous les commit handlers, **14,915629 ms**. L'union temporelle de ces ensembles est **6 275,713759 ms**, dont **6 269,159959 ms** explicitement Blocked dans `thread-state`.
- Le défaut dépasse le seuil des quatre microhangs : **26 plages runloop sans attente d'événements dépassent 100 ms**, total 6,030 s. Être hors attente d'événements ne signifie pas calculer : les attentes de mutex/Mach ci-dessus se trouvent justement à l'intérieur.
- Le Time Profiler Running seul avait aperçu `waitForCommitId` à 8,402028 s ; cette occurrence tombe dans l'appel maintenant mesuré **7,990201583–8,403706875 s**. Il n'était pas possible d'en déduire auparavant la durée d'attente.
- Les arguments Mach et stacks présents ne désignent pas le processus distant, une ressource GPU, un calque applicatif ni une pénurie mémoire précise. La synchronisation RenderBox/Core Animation est démontrée ; sa cause finale reste ouverte.
- Le retour à 60 callbacks/s rapporté après relance à 08:34:02 avec `-liserePose 0` est un A/B séparé. Il lie le mouvement du prototype au phénomène dans cette configuration, sans transformer cette trace système en mesure GPU ni établir la cause de tous les gels historiques.

## Reproduction et artefacts

Exports résolus avec un index complet `id/ref` par fichier : thread-state **11 388** lignes (4 009 main), thread-narrative **18 886** (8 607 main), syscall **7 625** (4 591 main), potential-hangs **4** (4 main), runloop-events **2 959** (1 973 main). Context-switch a également été exporté, **10 043** lignes ; les conclusions ci-dessus utilisent les tables précédentes.

Commande type : `xcrun xctrace export --input /private/tmp/woop-lisere11-native-system.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="thread-state"]' --output /private/tmp/woop-lisere11-system-thread-state.xml`.

- Parseur : `/private/tmp/woop-lisere11-system-analyse.py`; résultats `/private/tmp/woop-lisere11-system-analysis.json`, `-analysis.txt`, `-main-resolved.json`.
- Synchronisation : `/private/tmp/woop-lisere11-system-sync-detail.py`, `-sync-detail.txt`, `-sync-groups.json`, `-workers.json`.
- Relecture runloop indépendante : `/private/tmp/woop-lisere11-runloop-analysis.md` et artefacts `/private/tmp/woop-lisere11-runloop-*`.
- Note CPU antérieure : `/private/tmp/woop-lisere11-cpu-note.md` ; son dSYM build11 et le binaire du XML portent l'UUID D648E94D-F8AE-34B0-ABB4-6984E8291610.
