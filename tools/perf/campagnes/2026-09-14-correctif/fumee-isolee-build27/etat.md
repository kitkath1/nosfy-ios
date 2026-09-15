# Build27 — isoler la fumée d’invite à froid

Release UUID `8894F428-792E-323A-B0A8-1A7F053A27CF`.
La vidéo des flammes/pilule reste active ; seule la petite fumée sous
« pull to start » est retirée avec `-sansFumeeInvite`.
Arguments du lancement : `-sansSondeVol -ecranEveille -navProbe
-bancCoutHome -bancFroidHome -sansFumeeInvite -openTab home`.

La préparation attend le contexte Home, puis pose le châssis sans décor
jusqu’à six lectures nominales consécutives, espacées d’une seconde.
Attente bornée à environ cinq minutes et annulation si la page change.
La sonde commence ensuite et les six phases habituelles sont exécutées.
Ce diagnostic ne désactive pas la protection thermique et restaure la Home
sans intervention du Mac. L’argument sans fumée concerne ce lancement ;
un témoin avec fumée sur ce même binaire est nécessaire avant de conclure.

Résultats en attente. Pas de baisse de température ni de puissance déclarée.

## Sans fumée, froid confirmé

Installation19:53:16, lancement19:53:21. Refroidissement autonome puis
départ nominal à19:54:22. Sonde vol-20260915-195422 : fin après169,5 s,
restauration et arrêt confirmés. Thermique0 sur les six phases ; tics fumée0.

| Phase | n stable | CPU médian | Callbacks/s | Pire intervalle |
|---|---:|---:|---:|---:|
| complete | 21 | 14 % | 44.8 | 196 ms |
| sansWidgets | 16 | 15.0 % | 60.1 | 17 ms |
| sansRoute | 16 | 10.0 % | 49.099999999999994 | 124 ms |
| fondSeul | 16 | 1.0 % | 60.1 | 17 ms |
| nu | 16 | 1.0 % | 60.1 | 17 ms |
| complete | 16 | 12.5 % | 47.3 | 67 ms |

Le retrait de la fumée ne suffit pas : la Home complète reste irrégulière
et coûteuse côté CPU. Ce constat ne nécessite pas de lui attribuer une
part précise de l’énergie. Pas de témoin27 avec fumée encore mesuré.
Sans widgets : callbacks réguliers mais CPU encore élevé ; la charge
continue et les irrégularités peuvent avoir plusieurs contributeurs.

**Limite de capture repérée** : les images UIKit du banc26 montrent un fond
noir dans la phase fondSeul et de la vidéo seulement derrière certains verres
en phase complète. Ces captures internes ne prouvent pas la vidéo effectivement
présentée à l’écran. Vérification par capture système/utilisateur à obtenir ;
le log fond-precompose prouve le montage, pas les images GPU présentées.

À19:58:25, même binaire relancé avec les mêmes arguments plus `-sansPiece`,
pour isoler la pièce du header ; résultats en attente.

Retour utilisateur pendant le test : « Oui, les flammes bougent ».
Le fond animé est donc confirmé visible sur le téléphone ; le noir des
captures internes ne doit pas devenir un verdict sur le rendu réel.

Le premier relevé sans pièce, nominal0, montre une Home complète à15 % CPU
et60,1 callbacks/s (21 secondes stables, pire17 ms). Reste du banc à récupérer.
À20:01:21, collecte intermédiaire interrompue : CoreDevice7000/socket fermé.
Analyse non obtenue, absence de nav ; ce n’est pas un résultat de performance.

## Pièce figée, fumée toujours retirée, même binaire27

Départ à froid19:59:32 ; fin du banc après168,5 s, restauration vérifiée.

| Phase | n stable | CPU médian | Callbacks/s | Pire intervalle | Thermique |
|---|---:|---:|---:|---:|---|
| complete | 21 | 15 % | 60.1 | 17 ms | [0] |
| sansWidgets | 16 | 8.5 % | 60.1 | 17 ms | [0] |
| sansRoute | 16 | 9.5 % | 60.1 | 17 ms | [0] |
| fondSeul | 15 | 1 % | 60.1 | 17 ms | [0] |
| nu | 17 | 1 % | 60.1 | 17 ms | [0] |
| complete | 16 | 16.0 % | 60.1 | 17 ms | [0] |

La pièce figée restaure une cadence régulière dans les phases complètes
de ce passage. Le CPU reste élevé : pas de résolution de chauffe démontrée.
Le test suivant ajoute uniquement `-lisereCoreAnimation` pour vérifier
l’ancien prototype dans cette configuration, sans le promouvoir en production.

## Variante des bordures Core Animation

Lancement20:03:24, froid obtenu20:04:47. Première phase complète :
21 secondes stables, CPU médian20 %, 60,1 callbacks/s, thermique0.
Le CPU ne baisse pas par rapport aux15 % du rendu SwiftUI avec pièce
figée et fumée absente. Aucune promotion du prototype à ce stade.

Variante native complète :

| Phase | CPU médian | Callbacks/s | Thermique |
|---|---:|---:|---|
| complete | 20 % | 60.1 | [0] |
| sansWidgets | 9.0 % | 60.1 | [0] |
| sansRoute | 2.5 % | 60.1 | [0] |
| fondSeul | 1.0 % | 60.1 | [0] |
| nu | 0.0 % | 60.0 | [0] |
| complete | 21 % | 60.1 | [0] |

Prototype natif toujours désactivé par défaut. Test suivant : retour au
liseré SwiftUI, angle au repos (`-liserePose 0`), les autres exclusions
inchangées. Comparaison au témoin27 sans pièce/sans fumée, pas attribution
à partir de la variante native qui change le moteur.

## Bordures SwiftUI au repos

Départ froid20:10:06 : première phase complète CPU21 % médian,
60,1 callbacks/s, 21 secondes stables, thermique0. Passage à thermique1
pendant sansWidgets : les chiffres suivants protégés ne sont pas des
mesures du rendu animé. Le repos des seuls liserés ne suffit pas.
La protection thermique coupe aussi le verre via VerreHomeBanc : les
faibles coûts protégés ne doivent pas être attribués seulement aux horloges.

Fin du test en pose confirmée, 167,7 s. L’état thermique1 arrive dès45,7 s
après le début de la sonde. Dernière Home protégée1 % CPU : ne pas la comparer
à la première Home nominale21 % comme si seul le liseré avait changé.
À20:13:25, ajout de `-sansVerreHome` aux mêmes arguments, sur le même27.
Les autres exclusions restent identiques ; le moteur des flammes reste actif.
