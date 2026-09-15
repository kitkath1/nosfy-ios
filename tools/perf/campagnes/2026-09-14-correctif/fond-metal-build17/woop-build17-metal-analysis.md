# Fond Metal build 17 — première comparaison réelle, 15 septembre 2026

Release UUID 1CB3019A-05CC-3A55-9863-E4E6E511A893. Campagne root `/private/tmp/woop-compare17.log` : Metal lancé 10:20:45, référence lancée 10:21:31, restauration normale 10:22:17. Analyse locale uniquement, aucune action appareil/source/build par l'analyste.

**Verdict borné : les DEUX vidéos sont réellement consommées par Metal ; l'interface est beaucoup moins bloquée dans cet essai. Aucun gain énergétique ni causalité exclusive du moteur n'est démontré : Metal est mesuré à thermique 1, la référence suivante à thermique 2. Le raccord de boucle n'est pas encore observé.**

## Fenêtre SondeVol demandée : lignes dont 15 ≤ t ≤ 45

| Mesure | Metal | Référence AVPlayerLayer |
|---|---:|---:|
| Lignes / premier–dernier t | 29 / 15,6–44,0 s | 19 / 15,5–45,0 s |
| Callbacks CADisplayLink médians | 56,6/s | 8,1/s |
| Moyenne simple des cadences par ligne | 54,41/s | 13,06/s |
| CPU médian | 27 % | 2 % |
| Médiane du pire trou par ligne | 45 ms | 634 ms |
| Plus grand trou publié | 161 ms | >2 000 ms, valeur plafonnée |
| Lignes avec pire >100 / >300 / >1 000 ms | 1 / 0 / 0 | 16 / 14 / 5 |
| Lignes avec gel=1, trou réel >2 000 ms | 0 | 4 |
| Thermique / protection | 1 / 0 partout | 2 / 0 partout |

Les deux fenêtres sont `onglet=home`, séance/player/île/drag=0. Les captures `/private/tmp/woop-home17-metal.png` et `...reference.png` ont été inspectées : même Home avec widgets, sans modal couvrante. Elles ne suffisent pas à valider la fidélité colorimétrique ou l'animation.

`img` mesure les callbacks de l'interface, pas les images GPU présentées. Le nombre de lignes diffère parce qu'une publication Sonde peut être retardée par un gel. Le JSON plafonne `pire` à 2 000 ms (SondeVol.swift:280) ; `gel=1` signale le dépassement. Une intégration approximative pondérée par les intervalles de t donne 54,93 callbacks/s sur les 29 s disponibles [15,44] Metal, contre 10,48/s sur [15,45] référence. Ce calcul est indicatif, t étant arrondi à 0,1 s.

Le faible CPU du témoin gelé ne prouve pas une meilleure efficacité ; il est compatible avec les attentes documentées précédemment. Cette paire ne mesure ni puissance électrique, ni température physique, ni occupation/fréquence GPU.

## Preuve que le prototype ne montre pas seulement les posters

- Premier événement à +0,357 s depuis `selection` : gpuComplete=1, deuxVideos=false, b=0/p=0, poses utilisées.
- À +0,458 s : gpuComplete=4, deuxVideos=true, b=1/p=1, deux timestamps vidéo à 0,000 s.
- Jusqu'au dernier événement +41,875 s : b=721, p=722, timestamps 33,333/33,292 s. Tous les événements après le premier indiquent deuxVideos=true.
- Buffers réellement consommés : braise604×642 et pilule1206×964, BGRA8 ; drawable1179×1980 constant dans les événements.
- Régime +16,749→41,875 s, 25,126 s entre publications : gpuComplete184→925, soit **29,49 completions/s** ; b148→721, soit **22,81 images vidéo/s** ; p148→722, soit **22,85 images vidéo/s**. Les intervalles de 5 s stabilisés donnent environ 29,1–30,1 completions/s et 22,1–23,7 images nouvelles/s par flux.

La demande MTKView24 est donc arrondie vers environ30 ici ; ce n'est pas une mesure de24 rendus/s. Les sources sont24fps et la cadence effective de nouveaux buffers est un peu inférieure à24. Une completion prouve l'exécution du command buffer ayant ces textures, pas sa présentation à l'écran. Les timestamps des événements Nav sont écrits sur le main après completion : une interface bloquée peut retarder la publication ; les quotients ci-dessus sont des estimations entre publications, pas des mesures instrumentées de présentation.

## Début de lecture et boucle

Il existe un intervalle d'environ8 s sans avancement normal : les événements `piece-repos` des rayons23 et12 passent à true vers +3,636/+3,644 s, puis false à +11,702/+11,708 s. Le prochain diagnostic Metal arrive à +11,736 s avec les vidéos à3,167 s. Ce repos commun est compatible avec une inactivation de l'hôte/scène ; le journal ne nomme pas la cause. **Ne pas attribuer ce décalage au décodeur.** Le screenshot Metal porte un indicateur système de retour à une autre app, ce qui ne démontre pas à lui seul la cause de l'inactivation.

Les fichiers durent35,791667 s ; aucun timestamp vidéo n'atteint cette durée puis ne revient à0 dans ces journaux. La pause initiale rend les45 s murales insuffisantes pour démontrer le raccord. Les timestamps des deux flux sont proches (écart observé au plus une image, environ42 ms), mais leur synchronisation absolue n'est pas validée par ce relevé.

## Reproduction

Sources : `/private/tmp/woop-build17-{metal,reference}-{vol,nav}.jsonl`. Calcul : `python3 /private/tmp/woop-build17-metal-analyse.py`, sortie détaillée `/private/tmp/woop-build17-metal-analysis.json`. Le script conserve tous les événements Metal, les deltas de compteurs et les transitions de repos. Aucun défaut produit changé par cette analyse.
