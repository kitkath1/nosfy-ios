# Fond natif précalculé, cadrage 393 × 709

Le build 20 avait volontairement conservé l'ancien rendu : le slot réel ne
correspondait pas au premier drawable du prototype Metal. Ce fichier est
recuit pour les bounds observés, sans déplacer séparément les deux éléments.
H.264, 786 × 1418, 859 images, 24 i/s, 35,791667 s, 3 551 499 octets.
Les deux sources totalisent 1 550 352 pixels/image ; le fichier unique en
porte 1 114 548, soit 28,1 % de moins. C'est un budget de pixels décodés,
**pas une mesure de CPU/GPU, de puissance ou de température**.

Le fond précalculé est sélectionné dans ce cadrage au repos. Les autres
cadrages, la pilule en entrée, le départ de séance et la protection thermique
conservent les calques existants. `-fondDeuxLecteurs` sélectionne le témoin
sur le même binaire. Fidélité d'arrivée/départ et toutes tailles d'écran ne
sont pas validées par ce test Home au repos.

Le contrôle `-ecranEveille`, indépendant des compteurs, est allongé à trente
minutes à la demande explicite de Kathryn (« force mon tel à rester allumé
avec l'automatisation »). Pas de préférence persistée ni de changement de
réglage système ; une relance normale rend la veille normale.

Compilation et mesures appareil en cours à ce stade. Le script de test
vérifie le montage du lecteur unique, enregistre le CPU sans SondeVol,
contrôle le mouvement par captures et rejoue la navigation avant le témoin.


## Mesure du 15-09, 12:09

Release21 installé à 12:09:30–34, UUID 7A3E3913-67A2-3ACB-8277-E467D2844F35.
Préparation Home PASS 4,373 s ; le nav prouve `fond-precompose`, 393 × 709,
un lecteur, masque intégré, application active et écran maintenu éveillé.
La capture PNG montre la vraie Home avec ce rendu, sans compteurs.

Time Profiler, PID20423, 13,207626 s : 2405 échantillons Running à 1 ms,
dont1939 ms main /466 ms workers (~18,2 % d'un cœur échantillonné). SwiftUICore
est inclus dans1465 ms du main ; ces coûts inclusifs ne s'additionnent pas.
Thermique Fair pendant6,876 s puis Serious pendant6,331 s. Aucun événement de
passage inactif dans le nav entre la préparation et la fin de cette capture.
La table de cycle de vie de la trace attachée indique Unknown ; le maintien
éveillé et le contexte viennent donc du journal app et de la préparation UI.

**Pas encore de gain causal démontré.** Le témoin à deux lecteurs n'a pas
été enregistré : la liaison devient indisponible avant le contrôle suivant
(test sans aucune assertion exécutée). Les deux captures de mouvement et le
parcours complet de navigation21 ne sont donc pas validés par cette exécution.
Aucun gain de puissance, température ou rendu GPU n'est attribué au fond unique.

La commande de restauration protégée a elle aussi échoué faute de connexion.
Une tentative via XCTest a été retardée par l'expiration de la revue automatique
d'autorisation ; son unique retry autorisé démarre à13:15, puis attend le
déverrouillage de l'iPhone. Le build22 borne le diagnostic sans protection à
60 secondes pour qu'une coupure ne puisse plus laisser ce mode actif à durée
indéfinie. Les états de validation doivent conserver ces limites.


Le retry XCTest de 13:15 est finalement refusé après l'attente de déverrouillage :
certificat développeur du **runner** non fiable (`Security`, code 65). Aucune
assertion d'app exécutée. Cela ne prouve pas un défaut de navigation 21, mais
empêche de la déclarer validée par ce test. Le maintien d'écran par lancement
XCTest avait bien passé sur 20 à 12:08 (4,097 s), avant ce refus.
