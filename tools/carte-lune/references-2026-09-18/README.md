# Cartes — quatre références du 18 septembre 2026

Statut : atelier artistique. Génération et retouches par l’outil intégré
`image_gen`, sans appel au tirage de l’app. Les images ci-dessous ne sont pas
publiées dans le catalogue Supabase. Noms éditoriaux FR/EN. Kathryn demande
de sceller cette première famille avec Les Cimes Éteintes le 18 septembre.
Nom de famille : **La Forêt des Veilles / The Vigil Woods**.

## Références proposées

| Rareté | Français | English | Fichier retenu pour la revue |
| --- | --- | --- | --- |
| Commune | La Veille | The Vigil | [Illustration v2](01-commune-la-veille-v2.png) |
| Rare | Les Veilleuses | The Watchers | [Illustration v3](02-rare-les-veilleuses-v3.png) |
| Épique | Le Passage | The Passage | [Illustration v2](03-epique-le-passage-v2.png) |
| Légendaire | Le Souverain | The Sovereign | [Illustration v3](04-legendaire-le-souverain-v3.png) |

Les versions antérieures restent disponibles pour comparaison. Prompts complets :
[génération](prompts.json), [retouches v2 et v3](retouches.json).
Les dimensions et empreintes de tous les PNG sont archivées dans `images.json`.

## Direction demandée et progression

Quatre références, une par rareté. Un monde sombre et poétique : pins anciens,
rivière, brume, nuit, lune et braise discrète. Créatures belles et mémorables.
Kathryn apprécie le lien entre les mondes et leur cohérence ; elle demande ensuite
une différence plus forte pour les rares et légendaires, avec un côté shiny.

- Commune : proximité, écorce mouillée, petit papillon, profondeur calme.
- Rare : trois chauves-souris liées, individualité et ailes nacrées.
- Épique : oiseau immense en plein passage, nuages sculptés et vallée.
- Légendaire : cerf souverain, pelage noir argenté, bois d’obsidienne et braise.

Le niveau de finition reste élevé partout. La rareté se lit dans la présence,
la composition et la matière. Le code actuel ajoute déjà une, deux, trois ou
quatre lunes ; le cadre légendaire est argenté (`LuneForge.swift`,
`nomDuCadre`, `lunesRarete` et `lunes`). Les images générées n’incluent ni cadre
ni texte. Le full art et ce cadre sont conservés.

## Revue réellement effectuée

Les quatre v1 ont été regardées, puis les quatre v2 ; les v3 rare et légendaire
ont été regardées après la demande de reflets supplémentaires.

- Les quatre paysages partagent une palette et une profondeur cohérentes.
- La v2 épique rétablit les extrémités de l’aile dans l’image nue.
- Les visages des chauves-souris sont plus sobres en v2 ; la v3 rend les membranes
  plus réfléchissantes et leurs nervures mieux perceptibles.
- La v3 légendaire renforce l’argent du pelage et la braise dans les bois,
  tout en conservant le cerf noir et son paysage.
- Le croissant peint varie encore malgré la référence au logo : sa silhouette
  n’est pas reproduite à l’identique. À harmoniser avant publication.
- L’aile droite de la rare reste proche du bord. Le cadrage sous le vrai cadre,
  le contraste en vignette et la reconnaissance des raretés sur iPhone restent
  à vérifier. Aucune capture du téléphone ne valide ces références à ce stade.

La v3 est une proposition montrée après le retour positif sur le monde ;
ce retour ne vaut pas validation finale de chaque fichier.

## Contrat de collection

Une référence publiée possède une image, un nom et une rareté stables pour tous
les joueurs. L’image est générée en atelier, puis conservée ; chaque propriétaire
reçoit un exemplaire de cette référence commune.

Une première collection rassemble ces quatre degrés dans un même monde. De
futures collections pourront en explorer d’autres lieux ; leur nombre et leur
contenu ne sont pas arrêtés. Les quatre références servent à fixer la direction,
elles ne définissent pas à elles seules la taille du catalogue de lancement.

La découverte se fait au fil des séances. Garder les emplacements vides comme
dans le profil, sans dévoiler le nom ou l’art des cartes non obtenues. Pas de page
catalogue complète visible d’avance. Comparaison avec les amis reportée.

Le shiny de cette passe est une matière peinte commune à tous, sans nouveau
tirage de variante. Une variante collectionnable future aurait sa propre
référence officielle. Aucun nouveau moteur d’animation n’a été ajouté.

Texte blanc minimal : nom court à la découverte et près de la carte ; une phrase
poétique et le souvenir d’acquisition peuvent vivre dans le détail. L’attachement
vient du monde reconnaissable, des découvertes et des souvenirs de séances.
Conserver le manège existant et le sachet noir à légendaire garantie.

## Suite pour le branchement

1. Vérifier les quatre références dans le cadre réel à taille de téléphone,
   harmoniser le croissant et fixer les noms ; produire l’ensemble retenu.
2. Publier des références stables et sélectionner uniquement dans ce catalogue.
   Préserver les illustrations déjà possédées et traiter chaque rareté vide.
3. Sceller le sachet et attribuer son exemplaire dans une seule transaction,
   avec provenance de séance, rejeu et reprise après coupure.
4. Conserver l’identifiant exact jusqu’au profil, compter les vrais doublons,
   alimenter les totaux du catalogue sans divulguer les cartes manquantes.
5. QA avec deux comptes, coupure, double appel, réinstallation et sachet noir.
   Vérifier les effets existants et leur coût sur iPhone lors du branchement.

Le défaut d’attribution et le groupement actuel par famille sont analysés dans
`../ANALYSE-CARTES-2026-09-17.md`. Aucun correctif backend n’a été déployé dans
cette étape artistique. La mesure `m-cartes-qualite` reste ouverte dans la
documentation ; aucune carte « Tout est bon » ne résulte de cette seule revue.
