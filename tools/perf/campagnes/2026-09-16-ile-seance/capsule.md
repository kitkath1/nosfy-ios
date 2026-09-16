# Capsule compacte — correction du rendu43

**Rendu44 également refusé par Kathryn : « DANS le display island l’animation,
pas à côté ou en dessous ».** Les cinq tests ci-dessous prouvent les gestes
et les coordonnées de cette proposition, pas la conformité du dessin demandé.
Ne pas installer cette version comme solution validée. Le fond noir opaque
placé devant les trois braises masque leur intérieur et laisse un halo extérieur :
c’est le défaut constaté dans le code et la capture de Profil.

La suite doit distinguer le décor SwiftUI de l’app (`IleDecor`) et la vraie
Live Activity (`WoopWidgets/WorkoutLiveActivity.swift`), qui existe déjà.
Aucune nouvelle géométrie ni migration vers ActivityKit n’est décidée par
ce constat. Les pages doivent garder leur hauteur d’origine.

Le16-09, Kathryn refuse la silhouette pyramidale et l’abaissement des pages,
constatés sur le simulateur. `FormeIle` et `EspaceIleSeance` sont supprimés,
ainsi que les deux appels de ce modificateur dans WoopApp. Aucun padding
compensatoire n’est déplacé dans une autre vue.

Le cadre devient une Capsule régulière, de176×67 au repos (y5–72) à214×87
sous le doigt. La ligne de contenu passe à59 dans les deux états. Le stop
visuel est réduit de25,8 à22,1pt ; chrono14pt conservé. La largeur intérieure
est136pt. La prise de l’île ne déborde plus sous le cadre sur les pages ;
la Home blanche conserve une marge de12pt, jusqu’à72. Le banc vise y62 pour
sortir l’île et (centre−44,59) pour le stop. Les pages restent à leur place.

La phase du souffle, les trois flous, le chrono1Hz et les protections de43
restent identiques. Aucune horloge ni animation permanente ajoutée. Ces
constats de code ne valent pas mesure de chauffe sur le téléphone.

Validation sur simulateur iPhone15/iOS26.5 : les cinq cas ciblés passent
(tap de sortie26,133s ; stop18,472s ; drag24,849s ; Home blanche→détail15,309s ;
cadre et hauteur du titre19,190s). Le contrôle du titre exige maintenant
son origine y<65 et une prise d’île finissant au plus à72,5 : il ne valide
plus une page déplacée pour éviter l’île. Captures Exercices et Profil lues.
Le Profil retrouve son fond sous la barre d’état et ses boutons à leur hauteur
initiale. Le titre d’Exercices est visible sous la capsule.

La première copie Release contenait WoopApp actualisé par une autre session
mais son EconomieWoop précédent : deux méthodes de fin de séance manquaient
à cette copie. Compilation interrompue, copie complète resynchronisée ; aucune
modification ni annulation du travail de cette autre session dans le dépôt.

La version43 encore installée
sur le téléphone porte l’ancien contour ; la correction ne sera annoncée
installée qu’après compilation et relecture de la version.


## Connexion physique

Le contrôle avant installation44 ne retrouve plus l’iPhone (CoreDevice1011).
La liste des appareils confirme ensuite le même iPhone15 « unavailable »,
sans appareil de remplacement connecté. Aucun essai de lancement ni de stress
physique n’est relancé. La dernière version installée et relue était43 ;
44 n’est pas installée à ce stade. Les captures44 sont celles du simulateur.


La compilation Release44 a été arrêtée après confirmation de la perte de
connexion, sans installation. Elle n’est pas validée et devra être reprise
avant de poser un binaire sur le téléphone. La compilation Debug et les
cinq tests du simulateur sont terminés et réussis ; la correction y reste
visible sur Profil. Aucun verdict de chauffe physique pour44.
