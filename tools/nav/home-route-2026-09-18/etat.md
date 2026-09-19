# En-têtes Home et navigation de Route — 18 septembre 2026

Demande : remonter la phrase des Homes normale/noire et la lune de la Home
normale, au niveau du chevron et du titre des autres pages. Supprimer le menu
du bas sur Route.

## Correction

`EntetePage` reprend les cotes des chevrons : action de44pt à4pt de la zone
sûre, axe à26pt. La première ligne de36,3pt commence à7,85pt (au lieu de48),
et la lune de46pt à3pt (au lieu de43). Le Foyer noir utilise le même axe.
La Home noire conserve sa composition sans pièce. La course du texte vers le
slider est allongée de40,15pt pour garder le même point d’arrivée ; les deux
phrases du fondu gardent des bas alignés.

La nav du châssis était montée au même zIndex que Route, après elle : la
Home masquée continuait à publier sa demande de barre visible. La condition
racine exclut désormais `depart.cheminOuvert`. Les demandes des pages restent
intactes pour retrouver la nav au retour.

## Validation en cours

Compilation simulateur75 finale réussie. Les deux tests passent en59,919s :
Home normale → Exercices → Home → tiroir → Home noire ; puis Route → retour →
Exercices. Axe de la première ligne des deux Homes :87,983pt ; centre du chevron
Exercices :88pt sur ce simulateur. Les trois boutons de nav sont absents sur
Route, puis Entraînements redevient tappable après le chevron de retour.
Les six captures sont archivées dans `preuves/` et relues : première ligne
identique aux titres d’Exercices, lune sur le même axe, Foyer sans pièce,
texte de départ au-dessus du slider, Route sans nav, Exercices accessible au retour. Build iPhone75 en cours ; aucune validation
physique ni thermique déduite du simulateur. Aucune donnée du compte effacée,
aucune séance ou récompense créée pour cette correction.

## Suivi des builds

La session de renommage a libéré le téléphone après installation74 à09:37.
Nos builds utilisent le projet/schéma Nosfy et le bundle fr.kathryn.woop.
Le premier build75 iPhone a été interrompu avant livraison pour intégrer le
trajet du texte ; le build final est nosfy-home75-device-final-build.log.
Le simulateur a reçu le build final après recompilation de HomeNuit ; les
empreintes des quatre sources sont dans sources75.json. La capsule de banc
Nosfy visible sur les captures Debug ne fait pas partie de cette correction.
À09:40, la racine est renommée /Users/kathryn/Desktop/Nosfy par la session
voisine, avec lien de compatibilité. Les commandes suivantes utilisent les
permissions adaptées au nouveau chemin ; aucun dépôt dupliqué.

## Installation physique

Release75 finale compilée et signature vérifiée. Installation à09:42 ; lecture
CoreDevice à09:42:37 : Nosfy, fr.kathryn.woop, version75. L’iPhone indique
alors passcodeRequired:true : les tests ne sont pas lancés sous verrouillage.
Déverrouillage demandé ; contrôles physiques et retour normal restent à faire.

Vérificateur documentaire : première comparaison arrêtée après une génération
concurrente. Le build venait d’écrire1878045octets ; index.html en avait ensuite
1875759 tandis que le rebâti gardait1878045. Livrable régénéré, passe relancée.

Vérificateur final PASS en20s,23 tests et TypeScript verts, livrable rebâti
identique de1878045octets. Aucun fichier Swift de la correction n’a changé
après les builds et tests (empreintes contrôlées). À09:46:36, iOS réclame
encore le code : aucun essai physique lancé, aucune relance normale forcée.
L’app75 est installée ; reprise du contrôle physique après déverrouillage.
Aucune séance personnelle ouverte/terminée, aucun gain réclamé, aucun commit.
