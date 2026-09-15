# Liseré animé build11 — main runloop et microhangs

Sources : `woop-lisere11-system-runloop-events.xml` et `woop-lisere11-system-potential-hangs.xml`, sous `/private/tmp`. PID 17521, main TID 1412807. Contexte fourni : trace 08:29:18.603–08:29:27.674, liseré natif animé. Aucun résultat de l’essai statique de 08:34 n’est contenu dans ces XML.

**Les quatre microhangs coïncident exactement, au nanoseconde près, avec les quatre plus longues plages du main runloop entre une sortie et une nouvelle entrée en attente d’événements.**

| Début relatif | Fin relative | Durée | Chevauchement `waiting_for_events` |
|---:|---:|---:|---:|
| 2.996560000 s | 3.363331375 s | 366.771375 ms | 0 ns |
| 5.359178083 s | 5.726457375 s | 367.279292 ms | 0 ns |
| 5.758756666 s | 6.142585750 s | 383.829084 ms | 0 ns |
| 7.988506000 s | 8.404406333 s | 415.900333 ms | 0 ns |

Total des quatre microhangs : **1.533780084 s**. Il y a aussi **26 plages hors attente dépassant 100 ms**, totalisant **6.029828501 s** ; les 22 autres mesurent environ 151–236 ms. Cela décrit une succession de périodes longues, pas seulement quatre événements isolés.

**« Hors attente d’événements » ne signifie pas « CPU en exécution ».** Le main peut bloquer dans une attente de pilote, un verrou ou une synchronisation alors que le runloop est en train de traiter son travail. Les états de thread, appels système et piles doivent départager ces cas. La coïncidence avec `potential-hangs` est cohérente avec une détection fondée sur ce même runloop ; elle ne constitue pas une preuve indépendante de la cause.

## Couverture et méthode

- 2959 lignes runloop réelles, dont **1973 sur le main** ; toutes `recorded`, `kCFRunLoopDefaultMode`, niveau d’imbrication 1.
- Résolution globale des `id/ref`, puis appariement START/END par thread, type, niveau, identifiant, mode et pointeur : **533 itérations complètes**, **453 attentes complètes**. Aucune fin orpheline ; un seul START d’itération final sans END.
- Fenêtre exploitable du main : **0.549931333→8.887239958 s**, soit **8.337308625 s**. Aucune extrapolation avant/après.
- Attente explicite d’événements : **1.703581407 s** ; complément : **6.633727218 s**, soit **79.5668 %** de la fenêtre, sans attribution CPU.
- Plus longue attente explicite : **20,586666 ms** (t=1,032700500→1,053287166). Les freezes de 367–416 ms ne sont donc pas de longues plages `waiting_for_events`.
- Les itérations complètes incluent leurs attentes : ne pas appeler « busy CPU » leur durée brute ni les additionner au complément des attentes.

## Artefacts

- `/private/tmp/woop-lisere11-runloop-analyse.py` — script reproductible.
- `/private/tmp/woop-lisere11-runloop-analysis.json` — résumé, plages longues, chevauchements et événements autour des quatre microhangs.
- `/private/tmp/woop-lisere11-runloop-intervals.json` — toutes les paires et plages complémentaires.
