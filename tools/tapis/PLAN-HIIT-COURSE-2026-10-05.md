# Plan : le HIIT en courant (05-10-2026, retours du TestFlight 87)

Ses mots : « je veux mettre un km/h et lancer play : ça marche pas, ça n'enregistre rien » ; « comme je tape partout, ça lance la pop-up de fin, flamme, bravo pour le set » ; « quand je cours c'est horrible, rien ne marche » ; « pas de gros bouton pour terminer ; quand je termine un set, deux choix, je dois cliquer le chevron pour revenir en arrière ». Puis : « fais un plan, ne code pas ».

## Ce qu'elle a vu, et pourquoi (lu dans TapisScene.swift)

| # | Ce qu'elle voit | La cause |
|---|---|---|
| 1 | Le km/h réglé, puis ▶ : il retombe à 0, le set s'écrit à 0 km/h | `relancer` remettait la vitesse à 0 à chaque reprise (règle du 03-10, pensée quand la récup avait sa vitesse) — au ▶ du 87, elle efface le réglage |
| 2 | Un toucher en courant arrête le set et lance « bravo » | la pastille du chrono est un bouton caché (`zonesTactiles`, 252 pt de diamètre en haut) depuis août |
| 3 | Le ▶ ne répond pas après un set | la pop-up flammes attend un toucher et bloque la commande (`guard !popupVisible`) |
| 4 | Le médaillon ne répond pas en courant | un appui de plus de 0,45 s est pris pour le début d'un « maintenir » et ne fait rien |
| 5 | Aucun moyen visible de terminer | « maintiens pour terminer » retiré le matin (sa demande) : il ne reste que le chevron |
| 6 | Tout l'écran réagit | la zone de la molette couvre l'écran de la pastille km/h jusqu'au bas ; chaque toucher l'ouvre |

## L'écran, moment par moment

**A. Avant le premier set.** « SET 1 », GO qui scintille, temps total 0:00. Le km/h se règle. Un seul bouton : ▶ Lancer (88 pt). Le km/h réglé ici part avec le set.

**B. Pendant un set.** Le chrono du set dans la pastille du haut — ce n'est plus un bouton. Le km/h dans la pastille du bas. Un seul bouton : ■ Stop (88 pt) ; un toucher, court ou appuyé, arrête. Rien d'autre à l'écran ne réagit à un toucher.

**C. Un set fini.** « SET 1 TERMINÉ », 0:00, le km/h à 0. La confirmation du set (« SET 1 · 1:30 · 12 km/h ») passe en haut, sans rien bloquer. DEUX boutons, comme le minuteur d'Apple : ✓ Terminer à gauche, ▶ Reprendre à droite. Le km/h réglé pendant la pause part avec le set suivant ; la pause s'écrit à 0 km/h.

**D. Terminer.** L'écran « Tout est fait. » de la board (rangée 7) : temps total, nombre d'efforts, chaque set (temps · km/h), le max, le graphe, puis « Retour à la séance ».

**E. Le graphe.** Les sets en barres, les pauses en gris (board, onglet Graphe).

## Ses décisions (avant de coder)

1. **Régler le km/h en courant** — recommandé : deux gros boutons − / + sous le km/h (1 km/h par toucher, maintenir pour défiler), la molette retirée. C'était le principe de la v16 qu'elle avait validé : « en courant, rien à glisser ». Sinon : garder la molette, mais elle ne réagit plus qu'à un glissé horizontal.
2. **La pop-up flammes à chaque set** — recommandé : plus de pop-up en courant ; la dalle de confirmation seule (2 s, en haut), et la fête des flammes à « Tout est fait ». Sinon : la pop-up en 2 s, sans bloquer.
3. **Maintenir pour terminer** — recommandé : retiré, le bouton Terminer suffit.
4. **Le graphe** — recommandé : seulement à la fin (« Tout est fait »), pas pendant la course.

## Le geste, une fois décidé

- `SeanceTapis.relancer` (la vitesse reste), `TapisScene` (la pastille n'est plus un bouton, la pop-up ou la dalle, les deux boutons, − / + ou la molette), l'écran de fin, le banc `-cardioAuto` qui règle la vitesse AVANT le ▶.
- Preuves : un banc XCUITest à vrais doigts au simulateur (régler 10 km/h → ▶ → Stop → la phase écrite à 10 ; toucher la pastille du chrono → rien ; Reprendre ; Terminer → « Tout est fait »), puis la lecture au serveur de la séance (vitesse des phases).
- Puis le TestFlight 88.

## État de l'arbre

Avant son « ne code pas », un premier jet est entré dans `Nosfy/Views/TapisScene.swift` (causes 1 à 5 : vitesse gardée au ▶, pastille sans bouton, pop-up 2,4 s sourde au doigt, toucher à 0,7 s, Terminer / Reprendre en pause). Non construit, non commité. À garder comme base, ou à retirer.

Voir aussi : `tools/widgets/PLAN-EXOS-AU-SOL-WIDGETS-2026-10-05.md` (gainage et exercices au sol dans les widgets et au serveur, en attente de son « go »).
