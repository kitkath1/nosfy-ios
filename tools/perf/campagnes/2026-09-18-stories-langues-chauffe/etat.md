# Stories FR/EN et chauffe après booster — 18 septembre 2026

Kathryn signale une chauffe qui persiste à l’accueil après les stories et le
booster, et des stories qui mélangent le français et l’anglais. Elle autorise
la relance de Woop malgré la séance encore présente au moment de la capture.
Aucune séance ni récompense créée ou terminée par le diagnostic.

## Observation avant correction

Version70 installée par la campagne molette/welcome précédente, processus46674.
Trace Time Profiler de15s collectée AVANT relance : iOS indique `Serious` sur
16,19s de trace. Arrêt des essais d’animation demandé par ce seuil. Le runner
d’observation capture ensuite l’écran sans lancer/terminer l’app et la place
en arrière-plan à08:36:23. Cette capture montre une série active, pas une Home
nue : elle ne permet pas d’attribuer l’activité de la trace au retour Home.
La séance affichée lors de la capture est conservée.

La trace porte1335ms de poids CPU échantillonné : SwiftUI/AttributeGraph dominent,
SceneKit apparaît dans2ms seulement. Ce prélèvement ne démontre pas une scène
3D tournant en permanence après le booster. Pas de mesure GPU, de watts ni de
température en degrés. Câble branché ; charge/luminosité non relevées.

Premier export `time-profile` : sortie139. Export `time-sample` réussi, puis
symbolication locale et nouvel export `time-profile` réussi. Ne pas relancer
le stress pour contourner un défaut d’export. Traces brutes locales :
`/tmp/woop-stories71-avant.trace`, `/tmp/woop-stories71-avant-symbols.trace`.

## Corrections

- Stories : titres, phrases d’analyse, résumé, unités, dates, records, double
  séance et butin suivent `Langue` (langue choisie dans Woop). Les29 exercices
  du catalogue ont un nom anglais. Les identifiants et données restent stables.
- Les mots géants français adaptent leur taille ; les clés de géométrie du
  travelling restent stables, pour préserver le correctif69 contre le gel.
- La démo de story est reconstruite dans la langue courante à chaque ouverture ;
  les dates du calendrier de démonstration suivent aussi ce choix.
- Booster : la scène3D et les horloges du résultat se suspendent en arrière-plan.
  Dès le relais à la carte SwiftUI, la scène3D est détachée et ses liens de
  rendu/gyroscope coupés ; elle restait auparavant attachée à sa vue masquée.
  Le démontage devient définitif et idempotent : scène détachée, actions et
  particules retirées, références libérées, moteur haptique arrêté. Un rappel
  tardif ne peut plus réarmer les liens de rendu. Il s’agit d’une correction
  de cycle de vie ; la cause complète de la chauffe signalée reste à mesurer.
- Banc `-storyProbe` : bouton de cérémonie sans `appMode` ni `-boosterScelle`,
  donc sans forge et sans consommation de sachet. Tests thermiques gardés
  directement par l’état iOS du processus XCTest, indépendamment du fil de Woop.

## Validation

Release71 puis72 compilées ;73 ajoute aussi la date du calendrier de démo.
Release73 compilée et installée à09:01 ; version installée relue via CoreDevice.
Aucun succès de compilation ou d’installation n’est assimilé à une preuve thermique.

Les essais physiques71 à08:46 sont sautés à thermique2. À08:54, thermique0 :
le résumé FR passe, puis l’assertion de ligne Détails arrive pendant le fondu.
Le test attend désormais l’apparition effective. Le premier contrôle simulé
attendait une phrase abdos alors que la démo a davantage de volume en haut du
corps : le texte « Belle poussée » observé est correct ; attente corrigée.
Le test des quatre exceptions TOP/×2 FR/EN passe au simulateur en62,996s.
La compilation simulateur à deux architectures a été interrompue, puis reprise
sur arm64 avec deux tâches et réussie ; aucun service partagé n’a été arrêté.

Le lot physique73 attend d’abord le déverrouillage iOS, puis démarre à thermique0.
Résultats et collecte terminés : voir le bilan ci-dessous.

## Résultats finaux sur iPhone — Release 73

Les quatre tests passent (330,764 s au total) :

| Parcours | Résultat |
| --- | --- |
| Quatre pages, français puis anglais | PASS 37,674 s |
| TOP cardio/muscu et double séance, FR/EN | PASS 54,896 s |
| Stories → booster → accueil et 120 s de récupération | PASS 220,326 s |
| Carrousel : arrière-plan, reprise, fermeture sans ouverture | PASS 17,868 s |

Captures relues dans `preuves/` : résumé, détails, analyse, butin, exceptions,
carrousel avant/après interruption, accueil avant/après parcours. La forge est
inactive dans ce banc ; aucune carte ni récompense consommée pour le contrôle.

La vue 3D cesse de rendre dès le relais à la carte : compteur stable à 546 sur
cinq relevés. Après démontage, les 115 états suivants n’ont aucune vue SceneKit.
La pause/reprise du carrousel garde la même scène et la même caméra ; son
compteur reste à 192 pendant l’interruption, puis le dessin reprend à l’écran.
Le capteur de la story est libéré à la fermeture.

| Fenêtre stable sur la Home dégagée | Avant | Après |
| --- | --- | --- |
| Bornes (secondes depuis le lancement) | 15 < t ≤ 60 | 105 < t ≤ 215 |
| Lignes retenues / étendue | 45 / 44,7 s | 108 / 108,6 s |
| CPU médian (100 % = un cœur) | 5 % | 5 % |
| Callbacks par seconde, médiane | 60,1 | 60,1 |
| Plus grand intervalle | 17 ms | 17 ms |
| Thermique / protection | 1 / 1 | 1 / 1 |

L’activité revient au niveau d’avant, sans gel ni surcoût CPU persistant observé
sur ce parcours. Les callbacks ne sont pas un comptage des images GPU.
Thermique 0 puis 1 à t=9,1 s, AVANT les stories (ouvertes après 60 s), et 1 jusqu’à
la fin. Câble et charge présents : le symbole de charge est visible sur la
capture du carrousel. Pas de mesure de watts, de degrés ou de confort après une
séance longue. La chauffe durable n’est donc pas déclarée résolue.

Woop relancé en fonctionnement normal à 09:11:08 avec `-sansSondeVol`, sans
argument de banc. Simulateur isolé arrêté. Aucune donnée personnelle remise
à zéro ; aucun commit effectué dans le dépôt partagé.

Documentation régénérée (index autonome : 1 872 220 octets). Vérificateur passé :
types, contenu, 23 tests, reconstruction identique et règles de style/autonomie.
Exécution sans nouvelles captures du site, ses changements étant textuels ;
`next build --webpack` remplace le mode Turbopack déjà bloqué par son ouverture
de port dans cet environnement. Copie adaptée du vérificateur en `/tmp`, sans
modification de son fichier dans le dépôt. Un premier titre de mesure de
65 caractères a été raccourci pour respecter sa limite de 60.
