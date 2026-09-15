# Captures CPU 18 : comparaison non concluante sur le coût de la sonde

| Capture | Durée | Échantillons Running à 1 ms | Thermique | Écran éveillé prouvé pendant toute la capture |
|---|---:|---:|---|---|
| Sans Sonde, 11:28:01 | 9,379 s | 108, dont 69 main | Fair | Non |
| Avec Sonde + navProbe, 11:31:xx | 9,248 s | 1263, dont 1141 main | Fair | Maintien de veille Sonde, callbacks continus |

La préparation XCTest du premier essai date de 11:25:57, plus de deux minutes
avant la capture ; le contrôle après mesure peut réveiller l'écran. La table
`life-cycle-period` indique Unknown pour toute la capture attachée, sans
transition. L'activité CoreMotion ne prouve pas que la Home était visible.
**Ne pas annoncer ~1 % CPU au premier plan ni attribuer l'écart à la sonde.**
Le build 19 ajoute un drapeau indépendant `-ecranEveille` (pas de compteur, pas
mémorisé, expire à trois minutes) et les états application/veille aux événements
navProbe. Compilation réussie ; installation tentée mais refusée, appareil
indisponible. Le build 20 reprend ce contrôle pour sa comparaison vidéo.

La version normale sans compteurs a été restaurée à 11:32:05 ; sa préparation
XCTest passe. Kathryn confirme ensuite que le téléphone est un peu moins chaud,
ce qui reste un ressenti distinct de ces captures non comparables.
