# Île horizontale50 — 16 septembre2026

Demande précisée : chrono à gauche du capteur, stop à droite, aucun
contrôle dessiné sous l’île ; halo blanc intérieur sur Home noire.
Tap/drag sortent la pastille ailleurs ; Home ouvre directement le détail.

Capsule274×54 à y6–60, contenu centré y33 ; capteur central laissé libre
sur138pt. Le contact passe à282×58 sans déplacer le contenu ni les pages.
Halo blanc sur Home, braise rouge ailleurs, centre noir ; un seul flou
de rayon fixe5, opacités sur la rampe existante. `-sansSouffleIle` permet
le témoin immobile. Chrono1Hz indépendant de la protection du décor.
La barre de statut est masquée pendant la séance : sa présence chevauchait
le chrono et le stop dans la première capture50.

Le rendu de premier plan est porté par l’app ; la Live Activity WidgetKit
reste distincte en arrière-plan. La capture XCTest omet le masque physique
du capteur : ne pas inventer un capteur dans l’image pour masquer ce fait.

Simulateur50 : drag/pose/jet/récupération PASS13,494s ; stop visé directement
à(292,7;33) PASS6,981s ; Home → détail PASS8,120s. Premier lancement Profil
invalide (porte, sonde absente), reprise ciblée en cours.

Échecs du banc : première commande49 ciblait iOS au lieu d’iOS Simulator
(exit70). Première compilation50 générique a aussi commencé Intel ;
arrêt explicite de notre arbre de processus, reprisearm64. Une reprise
trop précoce trouve la base de build verrouillée, rejetée ; reprise
après arrêt effectif réussie. Première capture50 : chevauchement système
et identifiant chrono masqué par son parent ; corrigés avant installation.

Release50 en compilation. Pas encore installée, ni mesurée sur l’iPhone.

Release50 compilée et signature vérifiée ; app et widget intégrés.
Installée et relue à17:22:46, lancement normal réussi sans sonde.
Profil passé12,162s après arrêt explicite de l'app dans le lanceur de
test. Avant correction du lanceur, le premier processus ne fournissait
pas la sonde attendue ; les tests suivants du même lot passaient.
La relance n'est pas un correctif d'authentification de l'app.
Retours de l'île native :2 cas passés31,999s et14,242s, après un premier
cas Profil invalide dans le même lot ; ne pas présenter le lot entier vert.
Six scénarios ont finalement une exécution valide et positive sur50.

Le contrôle physique50 commence après l'installation ; aucune performance
ni réussite tactile50 sur le téléphone annoncée avant son résultat.

## Validation physique et verdict utilisateur

Composant50 :1 cas passé49,833s sur iPhone, captures et assertions de
position chrono/stop. Home blanche du composant :1 cas passé25,257s, tap
→ détail. Drag latéral depuis le chrono(100,5;33), et non la lèvre basse :
1 cas passé9,442s. Ces essais sont en lab ; la séance réelle était absente
du téléphone au contrôle initial (1 ignoré3,990s).

Thermique0/protection0 au lab50 : animation active, CPU médian16 % sur17
lignes t15,2–31,5,60,1 callbacks/s, pire17ms. Fenêtre des gestes t33–49 :
16 lignes, médiane17 %, maximum31 %, pire56ms. Ce n'est ni une métrique
GPU ni une mesure de la vraie Home ; ses contextes par défaut sont ignorés.
Le coût du halo motive51 : textures stables et fondu au compositeur.

À17:33, l'utilisatrice confirme que la sortie fonctionne (« my bad ça
marche bien »), après avoir validé le design blanc avec côtés gauche/droite.
Conserver les gestes : seuil12pt et ressort0,55s ; les essais provisoires
6pt/0,28s n'ont pas été installés et sont retirés.
App normale rendue à17:33:06 avec `-sansSondeVol -ecranEveille`.
