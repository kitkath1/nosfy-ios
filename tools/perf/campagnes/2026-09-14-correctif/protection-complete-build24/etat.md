# Build 24 — protection installée, mesures avec fenêtres couvrantes non exclues

**Réserve découverte à 16:18 : ces bancs ne certifient pas la Home seule.**
Welcome back n'était ni exclu ni enregistré. Le test16:07 a fermé Later
avant sa capture. La preuve visuelle après fermeture ne vaut donc pas pour
les mesures d'avant. Voir [banc 25 corrigé](../banc-verifie-build25/etat.md).

Le banc 23 complet localise une charge persistante du mobilier de la Home
protégée : 12 % CPU contre 1 % fond seul. Les mesures ne désignent pas encore
le coût exact de chaque animation. La vérification du code trouve trois
échappements à ProtectionThermique : la pièce du header (shader à 30 Hz),
les liserés repeatForever et les deux chevrons de l'invite.

Correctif : ces trois décors suivent maintenant la protection normale dès
thermalState != nominal. Les contrôles restent montés, les taps et la lumière
de pression des liserés restent actifs. Les chevrons suivent aussi scenePhase.
Le fond et le rendu à froid ne sont pas modifiés par ce correctif. Ce filet
complété n'est pas une optimisation validée de l'ambiance animée à froid.

État historique de préparation : Release lancée à 16:02:26 ; build 23 encore
sur l'iPhone à cet instant. Résultats effectifs plus bas.
Comparaison préparatoire sur 23 à 16:02:49, mêmes trois interruptions de décor
par les arguments existants -sansInvite -sansPiece -liserePose 0 ; l'invite
est retirée dans ce témoin, tandis que le correctif24 la conserve posée.

## Compilation et installation

Release 24 réussie vers 16:05, UUID **E0F74FBF-EE87-3EE0-BEAD-B2F86BB73D92**.
Installation confirmée à 16:09:43, conteneur
`6A1AAD45-2360-4AD0-9B08-AEAF406287D5`, databaseSequenceNumber 5372.

Le témoin23 avec les trois coupures ne démontre pas de gain : au thermique 2,
CPU médian première phase complète 15 %, sans widgets 16 %, sans Route 14 %,
fond seul 18 %, nu 20 % (collecte avant la fin). Cadence ~60 callbacks/s.
Ce contexte diverge du premier banc à thermique 1, dont le fond seul/nu tombait
à 1 %. Les derniers chiffres empêchent d'attribuer tout le coût aux trois
décors. Correction24 gardée comme fermeture d'un trou de protection, pas
comme résolution acquise de la chauffe.

Trace CPU de 16:06 : sauvegardée après coupure appareil, TOC9,534063 s mais
table time-profile sans aucune ligne. Le parseur historique refuse min() sur
la liste vide : pas d'attribution possible. Capture native screenshotr refusée
(Invalid service) ; test XCTest Home prêt passe à 16:07:03 en 3,833 s et sa
capture confirme la vraie Home, sans panneau Welcome Back. Le test n'a pas
changé la version 23 ou les arguments.

Lancement24 à 16:10:29 refusé Locked, aucune mesure 24. Kathryn ouvre ensuite
Woop et autorise le test à 16:11. Lancement à 16:11:47 confirmé, avec seulement
-sansSondeVol -ecranEveille -navProbe -bancCoutHome -openTab home. La protection
normale reste active. Aucun autre outil de profilage ou test UI pendant ce banc.
## Banc 24 complet, collecte16:15

Vol16:11:52,161 lignes ; nav16:11:47,175 lignes. Six phases, restauration
à 16:14:37,323. Au premier plan, écran éveillé, thermique 2 sur tout le banc.
Après exclusions : complète initiale 1,5 % CPU(n20), sans widgets 1 %(n15),
sans Route 1 %(n16), fond seul 1 %(n15), nu 2 %(n15), complète finale 14 %(n15).
Toutes les fenêtres :60,1 callbacks/s, intervalle maximal17 ms.

Le gain initial ne se maintient pas. Surtout, le contrôle de pop-up manquait :
ces chiffres n'établissent ni une cause exclusive, ni une baisse de chauffe.
Le message intermédiaire annonçant un premier résultat encourageant a été
rectifié dès la lecture de la dernière phase, puis du contrôle de Later.
