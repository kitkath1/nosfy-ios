# Home avec vidéo, ornements au repos — 15 septembre, reprise de 20:15 à 20:40

**Retour utilisateur après installation28 : « un peu moins chaud, mais pas de beaucoup, et un peu plus fluide ». Chauffe toujours insuffisamment corrigée.** Le CPU froid à5 % ne clôt pas le problème. Prochaine comparaison ciblée : coût du verre sur la vidéo avec les ornements déjà au repos, combinaison encore non mesurée.

**État final à21:12 : build28 Release installé, navigation validée, sonde froide à5 % CPU. Chauffe durable encore à confirmer.**

Installé à21:05:58, UUID **E5520DC9-E54F-3BDA-BCFB-352E1CA34751**. Home → Exercices → Home → Profil → Réglages PASS en9,373s. Sonde35s à21:11, premières15s exclues :19 relevés stables, CPU médian5 %, callbacks60,1/s, pire intervalle17ms, thermique0/protection0, aucun gel marqué, aucun popup, aucune séance ni player, zéro tic décoratif dans les cinq groupes suivis. Le fond précomposé est monté ; aucun drapeau de décoration n’est passé au lancement28. Le diagnostic thermique ne change pas le rendu à nominal0.

**Restaurée à21:12:00 : Home normale, protection active, compteurs éteints, maintien éveillé demandé.** La sonde ne mesure ni les watts ni la cadence GPU. Ce relevé court confirme le coût CPU de l’implémentation28, pas une résolution durable de chaleur. Retour utilisateur demandé ; QA04 resteKO. Aucun cycle de compte, aucune suppression ou déconnexion, aucun commit.
Ce dossier remplace les hypothèses par les traces réelles du même iPhone. Le retour USB à 20:15:34 permet enfin Instruments. La liaison CoreDevice précédente, parfois utilisable pour lancer, ne suffisait pas aux captures tentées.

## Ce qui est établi

- Time Profiler27, Home vérifiée par XCTest, vidéo animée, sans sonde : environ **15,34 % CPU échantillonné après les quatre premières secondes**. Le travail dominant est le rendu SwiftUI/DisplayList/AttributeGraph. Le préchauffage BoosterScene au démarrage n’est pas une boucle persistante démontrée.
- Power Profiler27 normal à 20:22 : **15,49 % CPU**, thermique Fair. Sans verre à 20:23 : **19,36 %**, thermique Serious. Ces conditions différentes interdisent de chiffrer un gain causal du verre. Aucune baisse obtenue dans cette observation.
- Home complète27 avec vidéo et verre conservés, mais `-sansFumeeInvite -sansPiece -liserePose 0 -sansVieRoute -sansSouffleGalets` : **4,89 % CPU**, dont **1,02 % sur le main**, thermique Serious. Capture 20:27:52.944 → 20:28:09.986, terminée normalement. Le diagnostic thermique ne se termine qu’à 20:28:21.45 : la capture précède cette expiration. Cette combinaison justifie un correctif local de la Home, pas une annonce de chauffe résolue.
- L’utilisateur confirme que les flammes bougent. Le noir des captures UIKit ne prouve pas que la vidéo réelle soit noire ou arrêtée : AVPlayerLayer n’y est pas correctement représenté.

Le pourcentage CPU est la somme des poids des échantillons Running après t=4s, divisée par la durée restante de la trace. Il n’est ni une puissance en watts ni une température. Les captures courtes ne valident pas la durée ni l’autonomie. Comparer Fair et Serious ne mesure pas une économie énergétique.

## Correctif28

La Home transmet `decorHomeAuRepos` à son PageCard. Les liserés se posent, la pièce cesse son horloge/gyroscope de repos, la respiration des galets et les ornements permanents de la card Route s’arrêtent, la fumée d’invitation n’est plus montée. Les réponses aux appuis, données, boutons et le fond vidéo sont conservés. La protection thermique existante reste active en usage normal.

La portée est l’environnement de cette Home : la valeur est fausse par défaut pour les composants réutilisés ailleurs. `-decorHomeAnime` permet de retrouver le témoin. Aucun nouvel effet de rendu ni nouvelle horloge. Aucun changement de backend, aucune suppression ou déconnexion. Aucun commit.

**Vérifiés : compilation28, navigation et coût CPU par la sonde sans drapeaux décoratifs. À confirmer : chauffe en usage.** Le contrôle final ne reprend pas les six variantes. La capture Instruments échoue et est remplacée par un unique relevé35s de la sonde existante.

## Erreurs et limites des instruments

Le premier Power Profiler de 20:17:55 démarre après l’expiration du diagnostic à 20:17:52 : il mesure la Home protégée, pas le témoin animé. Ne pas le présenter comme un gain de vidéo.

Les valeurs CPU Instructions/s sont des instructions par seconde, pas des nanosecondes CPU. Les colonnes anonymes de ProcessSubsystemPowerImpact ne sont pas des watts. Le niveau système en %/h à zéro pendant la charge n’est pas une preuve d’énergie nulle. Les scores Power Impact sont des scores, selon Apple : https://developer.apple.com/videos/play/wwdc2025/226/.

Le brouillon d’agrégation GPU mélangeait quatre séries statistiques par intervalle. Ses moyennes sont rejetées (double comptage et division par zéro). La couche Metal observée ne couvre pas nécessairement toute la Home, notamment AVPlayer et le compositeur. Aucun verdict de saturation ou d’innocence du GPU.

L’essai sans verre du banc froid démarré à 20:13:25 a été interrompu à 20:16:52 avant d’avoir atteint nominal : aucune donnée de sonde récente, ancien fichier non réutilisable. La collecte intermédiaire sans pièce à 20:01 échoue (CoreDevice socket closed) ; seule la collecte finale est utilisée.

## Preuves et reprise

Les sous-dossiers portent les noms et heures d’origine ; journaux, tables exportées, analyses JSON et scripts sont conservés. Les grosses tables XML sont compressées sans perte (`gzip -dc fichier.xml.gz > fichier.xml` pour les relire). Les traces brutes restent dans les dossiers homonymes sous `/private/tmp/`. `sources28/` conserve les six fichiers de rendu au départ du build ; SHA256SUMS les identifie.

Ne pas relancer les essais isolés fumée/pièce/liseré sans nouvelle raison : leurs limites sont dans E45. Reprendre ici avec la validation28 et le retour utilisateur.

## Blocage de livraison constaté vers20:55

Le build28 reste actif, sans erreur émise. À20:50, son compilateur a88,83s CPU pour8min48s de vie. Le Mac utilise22,7Go de swap, avec environ4060 pages libres de16Ko ; plusieurs simulateurs d’autres sessions sont actifs. Aucun ancien xctrace significatif trouvé à fermer. Demande d’accord avant interruption des autres simulations ; aucune interruption effectuée sans réponse. Le premier automate, borné à6min supplémentaires, expire sans avoir lancé installation ou tests ; le build lui-même continue.

À20:54:44, la relance de la Home27 pour renouveler le maintien éveillé est refusée par iOS avec Locked. Il ne s’agit pas d’un test thermique ni d’une installation28 échouée. Ne pas redemander le déverrouillage avant que le build soit prêt. Preuve : `woop-rearme-attente28.log`.

## Contrôle28 : incidents conservés

Le premier automate a installé28 et validé Home prête, mais le démarrage de XCTest a consommé trop de la fenêtre de60s. Garde déclenché AVANT de lancer Power Profiler : aucun chiffre à tirer de cette tentative. Retour protégé réussi puis navigation PASS. Le test Home lui-même dure1,706s, le délai venait surtout de la mise en route de l’outillage.

À21:08:22, nouvelle ouverture, Home prête PASS, puis Power Profiler15s à21:08:29. Le processus dépasse40s et est interrompu par la limite externe ; le bundle `home28.trace` est incomplet, sans résultat énergétique exploitable. Retour normal réussi à21:09:09. Ne pas remplacer cette absence par une ancienne trace27.

Repli final : sonde existante sur Home28 pendant35s, puis fermeture et réouverture avec `-sansSondeVol`. Collecte récente vérifiée, champs Welcome/arrivée/home/protection lus. Aucun autre essai de décoration effectué.

Les six sources28 archivées sont identiques aux fichiers de rendu actuels lors de la validation. Compilation initiale lente sur Mac sous pression mémoire ; un second échantillon du compilateur montre ensuite les passes d’optimisation SIL, puis BUILD SUCCEEDED à21:05. Les simulateurs tiers n’ont pas été arrêtés.
