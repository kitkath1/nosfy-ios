# Fermeture des overlays widgets — 17 septembre2026

## Signalement et reproduction

Kathryn : « j’ai du mal à fermer l’overlay […] ça sautille vers le haut à la fin ».
Version59 du banc : un tirage vertical depuis le contenu (45 % →69 % de la
hauteur écran) laisse la chambre Regularity ouverte. XCTest échoue sur cette
fermeture en25,382s ; l’ouverture a bien été constatée. Aucun appel serveur
(-sansServeur), aucune donnée du téléphone personnel modifiée.

Le code explique les deux limites : geste uniquement sur l’en-tête ; seuil
120pt / projection320pt ; `etat.fermer(); tirage = 0` remet la feuille en haut
alors que sa transition de sortie commence vers le bas.

## Correctif60

Le contenu reconnaît aussi le tirage, uniquement commencé en haut et vers le
bas. Le booléen de frontière du ScrollView ne publie pas chaque pixel. Un geste
commencé dans du contenu déjà défilé reste du défilement. L’en-tête garde son
geste ; la poignée accepte aussi un tap. Seuil72pt, ou impulsion projetée180pt
avec au moins16pt réels. Le dernier offset est conservé pendant la sortie,
puis disparaît avec la vue ; une fermeture ne peut être déclenchée deux fois.
Un geste interrompu remet la prise au repos, sans garder de décalage résiduel.
Aucun moteur permanent, shader ou lecteur ajouté ; dessin et verre conservés.

Seuls les hunks UI de ChambreLongue.swift sont modifiés ; les changements
serveur/compte déjà présents dans le fichier sont conservés et exclus de notre
delta. Le travail est resté non commité jusqu’à l’ordre explicite du17-09, après validation physique.

## Validation et limites

Trois parcours prévus : contenu en haut ; petit drag annulé puis fermeture
courte par l’en-tête ; défilement conservé et fermeture par l’en-tête.
Le runner du test initial reste bloqué après son verdict : son xcodebuild seul
est arrêté. Ensuite Xcode ne retrouve plus la destination du simulateur réservé,
et simctl attend le service. Aucun autre simulateur ni service partagé arrêté.
Le service simulateur revient ensuite (appareil réservé retrouvé Booted). À la
demande « fais sur mon tel », la compilation du simulateur et son compilateur
resté actif sont arrêtés de façon ciblée pour prioriser la Release iPhone.
Aucun parcours corrigé n’a été exécuté au simulateur. Le téléphone est connecté,
version59 relue avant installation. Release60 compilée avec succès, installée
le17-09 à11:19, puis version60 relue via CoreDevice. Woop est relancé avec
`-sansSondeVol -sansVisite -openTab home -chambreLongue regularite` pour le
contrôle utilisateur. Le lancement est confirmé ; aucun geste ni film du rendu
corrigé n’a encore été collecté sur l’appareil. Aucun verdict de chauffe durable
ou d’énergie tiré de la lecture du code.

## Documentation

Source Widgets et note QA actualisées. Artefact construit dans une copie
isolée de HEAD avec les seuls ajouts de cette tâche : 1 996 271 octets,
`npm run verif` complet réussi. Captures État 390/1440 consultées. Le livrable
isolé reste dans `/tmp/woop-widget60/docs-snapshot/docs/site/index.html` ;
le `index.html` partagé, déjà modifié par une autre session, est conservé.
Aucune publication du lien externe réalisée.

## Reprise61 — retour physique négatif sur60

Kathryn : « ça glitch encore quand je la descends vers le bas ». Ce retour
invalide la fluidité de60 ; son installation ne valait pas validation.
Le DragGesture utilisait les coordonnées locales de la feuille qui bouge ;
le ScrollView pouvait aussi rebondir en parallèle.61 mesure dans l’espace
écran fixe et applique le suivi sans animation implicite. Le rouleau local
garde son défilement mais son rebond est désactivé, puis restauré au démontage.
La fermeture prolonge le même offset avec la vitesse du doigt ; la suppression
de la feuille et le retour de la nav attendent sa sortie complète. Aucun
timer ni geste natif supplémentaire n’est ajouté.

Test physique indépendant préparé : descente lente130pt/s, captures et film
conservés même en succès. Premier lancement sur60 bloqué par le verrouillage
iOS avant le test ; déverrouillage demandé. Puis le runner échoue avant le
scénario : Lost connection to testmanagerd. CoreDevice ne retrouve plus
l’appareil au contrôle suivant. Aucun film ni résultat tactile de60 recueilli,
pas de relance en boucle. La Release61 compile séparément.

Documentation61 : artefact isolé1 996 653 octets ; vérification complète
réussie en155s, capture État390 consultée. Le livrable partagé reste préservé.

Release61 : compilation réussie le17-09 ; version du bundle61 et SHA-256 de
l’exécutable archivés. Installation et validation physique restent distinctes
de cette réussite de compilation.

Installation61 tentée après le build : arrêt dès la lecture préalable de la
version installée, CoreDevice1011 (appareil introuvable). Aucun install ni
lancement61 exécuté. Le téléphone conserve la dernière version connue60 ;
reconnexion et déverrouillage nécessaires. Aucun commit réalisé.

## Reconnexion — installation61

Après « vasy », liaison rétablie : installation61 réussie le17-09 à11:51,
version61 relue via CoreDevice. Le contrôle tactile filmé est lancé sur ce
binaire ; les échecs précédents de connexion restent archivés séparément.

Validation physique61 : `testFermetureContinueDepuisLeContenu` PASS en10,090s,
une seule descente lente130pt/s. Avant : Regularity ouvert ; après : vraie Home
avec sa nav revenue. Film et captures consultés, conservés dans `iphone61/`.
Suivi du grabber par corrélation du motif : 81 positions fiables de4,3283s
à7,07s, aucun retour vers le haut supérieur à3pixels du film. La planche montre
le contenu qui reste solidaire de la feuille jusqu’à sa disparition. Cette
observation n’est ni une mesure de60fps présentées ni un verdict thermique.

Le test termine l’app ; relance normale confirmée à11:52:45 avec
`-sansSondeVol -sansVisite -openTab home -chambreLongue regularite`, pour le
contrôle manuel utilisateur. Aucun changement de séance, aucun commit.
Le geste annulé, les autres chambres et la chauffe durable ne sont pas clos
par cet unique parcours.

L’événement XCTest archivé va de383,40 à656,04pt (272,64pt), avec maintien
final0,2s. Dans le film, le grabber passe de211 à1029px avant la sortie
(818px, soit272,67pt à3×), puis reste stable pendant le maintien. Le dernier
mouvement prolonge ce décalage hors écran.
Documentation du résultat physique : artefact isolé1 996 938 octets,
vérification complète PASS en63s. Aucun fichier du livrable partagé remplacé.

## Validation utilisateur et commit demandé

Après installation61 et essai : « ok commti que ça top c cool ». Ce retour
valide la correction de la fermeture et autorise uniquement son commit. Les
autres travaux du dépôt partagé restent exclus. La note QA Widgets et cette
brique sont actualisées ; aucune conclusion thermique ajoutée.

Périmètre documentaire du commit : le dernier livrable commité vient de
e328a42 (53 images). Les sources story ajoutées ensuite dans HEAD portent
59 images et donnent2 047 408 octets ; l’inliner refuse ce dépassement.
Pour respecter « que ça », le livrable widgets est généré depuis sa dernière
révision commitée avec nos seuls changements documentaires ; ses53 images et
ses autres pages restent celles du livrable précédent. Les sources du commit
restent, elles, basées sur HEAD : les changements story déjà commités y sont
conservés. Le livrable partagé en cours d’édition n’est pas écrasé.

Le bloc SwiftUI sélectionné a exactement le même hash que celui de l’app61
compilée et testée. État serveur/compte et feedback objectif hors de ce bloc
restent ceux de HEAD dans le commit ; leurs changements étrangers restent
dans le working tree. Voir `perimetre-commit.json`.

Livrable du commit :1 997 094 octets,53 images strictement identiques à
celles du livrable précédent ; vérification complète PASS en16s.
