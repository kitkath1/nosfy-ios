# Archive — verre gonflé v1 « noir et orange » (15-08-2026, tours g1-g9)

La première matière shader de la carte des séries : deux lampes (blanche
haut-droite, orange bas-gauche) sur l'architecture de l'obsidienne —
épaule à facettes, flaque du flanc droit, lame du coin haut-droit, brumes
sépia, fumée qui dérive, trois rayons anamorphiques dans l'air, respiration
par portées (swell/coulée). Auto-jugée ~9,5 contre la photo ; **verdict
Kathryn : 2/10** — « trop clair, trop blur, card grise cheap », cellule
rectangulaire visible à ×16, corps 2-4× trop lumineux par zones.

Fichiers reconstitués à l'identique en rejouant les 34 écritures du
transcript de session (arrêt pile avant la réécriture « restauration »).
- `VerreCoulant.metal` — le shader v1 (rayons compris, pas de mode debug)
- `VerreCoulant.swift` — l'hôte v1 (TimelineView 30 Hz, pad 84, t vivant)
- `g9-ferme.png` / `g9-vs-ref.png` — l'état final v1 et sa planche

Pour la faire revivre : remplacer les deux fichiers homonymes (l'appel de
`carteSeries` dans ExerciseDetailView devra retirer le paramètre `mode`).
L'histoire complète des tours vit dans la mémoire de session
(`woop-carte-series-exo`, round 14) et la suite dans `woop-verre-restauration`.
