# Séance dans l’île — corrections du16 septembre2026

Version52 installée et validée visuellement par Kathryn. Chrono à gauche du
capteur, stop à droite, capsule horizontale en haut de l’écran sans abaisser
les pages. Sur la Home noire : halo blanc et tap vers le détail. Ailleurs :
halo rouge vivant, tap/drag vers la pastille libre, déplacement fluide et jet
vers l’île. La Live Activity système garde le suivi hors de Woop ; son lien
explicite reprend la bonne séance dans l’app.

Le halo utilise deux textures mises en cache et un fondu Core Animation.
Le chrono reste à1Hz, indépendant des pauses du décor. Reduce Motion,
protection thermique, arrière-plan et détail suspendent le souffle.

- [État final52, tests, coût et périmètre du commit](halo52.md).
- [Comparaison51 : CPU médian1 % natif /16 % SwiftUI](performance51.md).
- [Placement latéral et gestes50](rendu50.md).
- [Restauration du composant au premier plan49](restauration49.md).
- [Live Activity et retour explicite45–48](native.md).
- [Reprises du contour43–44](capsule.md), [essai initial et limites](etat.md).

Ces preuves ne clôturent pas la chauffe durable de Woop. Le build isolé du
commit bloque sur une dépendance préexistante absente de HEAD (VolDePieces),
sans incidence démontrée sur le build52 installé depuis l’arbre partagé.
Les fichiers sourcesXX.json identifient les snapshots de build, y compris
leurs dépendances d’autres sessions ; ils ne définissent pas le périmètre Git.
