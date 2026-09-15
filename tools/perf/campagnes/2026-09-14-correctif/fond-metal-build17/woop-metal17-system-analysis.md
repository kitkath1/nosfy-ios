# System Trace Metal17 — capture inexploitable

Le 15 septembre 2026, le script root `woop-traces17-retry.py` a attaché System Trace au processus Woop18791, puis a interrompu l'outil après50s pendant la sauvegarde. Le log atteint « Recording completed. Saving output file… » sans confirmation de sauvegarde terminée. La capture avait une durée demandée de8s ; ces50s incluent préparation et sauvegarde, pas50s d'exécution observée de l'app.

Vérification locale effectuée :

```
xcrun xctrace export --input /private/tmp/woop-metal17-system.trace --toc --output /private/tmp/woop-metal17-system-toc.xml
```

Retour10 : `Export failed: Trace is malformed; instrument run data is missing`.

Aucune table exploitable, aucune durée d'attente CA/RenderBox mesurée dans ce paquet. Il ne permet ni de confirmer ni d'exclure les attentes documentées dans `/private/tmp/woop-home15-full-system-analysis.md`. Ce défaut appartient à la collecte et à son timeout de sauvegarde ; il ne constitue pas un échec de l'app ni du prototype.

Les parseurs d'analyse adaptés restent prêts dans `/private/tmp/woop-metal17-system-analyse.py`, `...-sync-analyse.py`, et `/private/tmp/woop-metal17-runloop-analyse.py`. Ils n'ont pas été exécutés sur des données valides. La comparaison des journaux de la première campagne reste distincte : `/private/tmp/woop-build17-metal-analysis.md`.
