# Trace Metal de référence — aucune donnée de coût exploitable

Fichier source : `/private/tmp/woop-home-reference.trace`. Enregistrement attaché
à Woop, PID 12949, sur iPhone 15, iOS 26.6.1. Fenêtre du **14 septembre,
16:24:44.187–16:25:00.739 Paris**, durée **16,551623 s**. Template Metal System
Trace, limite demandée 15 s, arrêt « Time limit reached ». Ancien binaire,
avant installation du correctif.

La commande a produit une trace et les exports aboutissent, mais **les tables
utiles ne contiennent aucune ligne**. Ce n'est pas une mesure de GPU à 0 %.

| Tables exportées | Lignes | Ce qui peut être conclu |
|---|---:|---|
| `time-sample`, `time-profile`, `thread-info` | 0 chacune | Aucun temps CPU, aucune pile, aucun classement main/renderer |
| `metal-gpu-intervals`, `metal-application-intervals`, `metal-command-buffer-completed` | 0 chacune | Aucun travail CPU/GPU Metal chronométré |
| `ca-client-buffer-wait-interval`, `potential-hangs`, `runloop-events` | 0 chacune | Aucune preuve d'attente ou d'absence d'attente |
| `display-compositor-interval`, `displayed-surfaces-per-second` | 0 chacune | Aucune cadence de présentation/composition mesurée |
| `gpu-performance-state-intervals`, `gpu-counter-value` | 0 chacune | Aucun état de performance ni compteur GPU |
| Les 27 tables `kdebug` du TOC | 0 chacune | Même absence dans les événements bruts exportables |
| `device-thermal-state-intervals` | 1 | **Unknown** sur les 16,55 s |
| `life-cycle-period` | 1 | **Unknown** : cible attachée, aucune transition observée |

`RunIssues.storedata`, lu en SQLite sans écriture, porte une seule entrée :
« Data stream: Time Mapping » à t=0. Cela ne suffit pas à identifier la cause
de l'absence de données. Les 13 Mo du paquet ne prouvent pas une collecte :
environ 10 Mo appartiennent au fichier `form.template`.

Il faut distinguer le fil principal de Woop, ses éventuels threads de rendu,
le compositeur système et le GPU. Cette trace ne mesure le coût d'aucun des
quatre et ne permet donc pas d'affirmer « main attend », « renderer saturé »
ou « GPU bridé ». Le thermique exact demeure inconnu ; aucune comparaison
avant/après n'est possible avec cet enregistrement.

Les petits exports XML, le TOC et `export-summary.json` sont conservés ici.
Aucune nouvelle capture ni action sur l'appareil n'a été lancée pour cet audit.
