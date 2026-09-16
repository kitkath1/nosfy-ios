# Pastille de séance dans l’île — 16 septembre 2026

> Historique43, rendu refusé ensuite : forme pyramidale et pages abaissées.
> La correction courante est décrite dans [capsule.md](capsule.md).

## Changement de rendu

La V3 dessinait une capsule claire 176 × 40 sous le capteur (y 46–86).
La V4 conserve le contenu de cette baby (stop à gauche, chrono à droite,
ligne physique y 66), dans un seul contour noir qui part de y 5 et englobe
le capteur. La tête se resserre sur le capteur ; le bas garde ses coins de
20 pt. Au contact, le contour s’ouvre vers 214 × 87 et des coins de 34 pt.
La position du contenu reste fixe. Les trois couches de lueur conservent
couleurs, flous et formules ; le noir opaque est passé devant elles pour
empêcher l’intérieur gris de reformer visuellement une pastille sous le trou.

Sur la Home en séance : capsule blanche compacte 148 × 55, sans contenu,
tap dans sa partie basse → détail. Le capteur matériel reste noir : les captures
XCTest de cette campagne l’omettent ; les captures simctl le montrent. L’état de la pastille et sa
dernière place restent mémorisés en changeant d’onglet.

Les pages Exercices et Profil réservent la place du contour et de sa marge
tactile basse pendant toute la séance. Aucun déplacement de page pendant
un geste ni pendant le vol. Le geste reste sur le parent, le seuil de sortie
à 12 pt, les ressorts et le matched geometry à source unique sont conservés.

## Chauffe : protections et portée

Skills lus : woop-chauffe, woop-performance, registre E62 et campagne42.
Aucune horloge ni couche de flou ajoutée. La forme est native au dessin SwiftUI.
Le souffle et le morphisme gardent des attributs animables distincts.
Le décor se fige en arrière-plan, sous le player, avec Reduce Motion ou
la protection thermique. La rampe infinie est démontée lors de cette pause.
Le chrono visible garde sa cadence de 1 Hz quand seule l’ambiance est figée.
La Home blanche ne monte aucun souffle. Cela ne constitue pas une mesure
CPU/GPU ni une preuve d’absence de chauffe durable.

## Vérification sur simulateur iPhone15 / iOS26.5

Banc dans une copie isolée ; aucune séance du téléphone créée ni terminée.
Onze cas passent au premier parcours complet : nav pleine, premier tap de
nav, ouverture du player, pose, mouvement latéral lent, jet/tap de l’île,
tap tremblant, stop, sortie au drag, retours d’onglets, Home blanche → détail.
Le douzième détecte le chevauchement de la marge tactile avec le titre :
titre y94, prise jusqu’à y104. La réserve est augmentée de18pt ; le cas
ciblé repasse en13,284s. Les onze autres cas n’ont pas été rejoués après
cette seule correction de marge. La grille historique test99 n’est pas rejouée.
Captures finales ci-jointes ; fichiers xcresult originaux dans /tmp/woop-ile-20260916-*.

## Incidents de validation

L’ancien hook du player cherchait une fin de fonction juste après sondeCadence,
alors que le cycle de vie de CouvertureFoyer y ajoute maintenant onDisappear.
Le hook a été réancré sur la ligne unique de sonde, dans la copie seulement.
Une première compilation a été interrompue après cette préparation incomplète.
L’export xcresult initial est refusé par le bac à sable ; reprise avec accès Xcode.
Un premier test géométrique ne vérifiait pas encore le titre : sa capture a
révélé que safeAreaInset était ignoré par le cadrage explicite de PageCard.
La réserve est donc du padding au-dessus de ce cadre, puis elle inclut aussi
la marge tactile. Ces premières captures ne sont pas des preuves finales.

## Téléphone

Release43 finale compilée et installée ; version relue après installation :43.
Version auparavant installée lue :42.
Les derniers journaux42 ont été conservés avant toute relance.
Le test physique préparé utilise -piluleLab, sans mutation des séances du compte.
Le lancement est refusé par iOS à13:42:40 : Locked. Le runner tactile a été
interrompu dès lecture de ce refus ; aucune boucle de relance. Déverrouillage
demandé à l’utilisatrice. Aucun coût de cette version mesuré sur le téléphone,
aucun rendu réel de43 constaté. Le refus survient avant exécution des arguments
-sondeVol. La version43 reste installée pour le prochain lancement normal.
