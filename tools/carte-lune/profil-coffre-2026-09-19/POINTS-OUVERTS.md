# Cartes : vérification des points encore ouverts — 19 septembre 2026

La citation « build 78 en préparation » décrit un état ancien. Le build 79 a
été installé ; le 80 a compilé pour iPhone et simulateur. Le runner physique
79 a attendu le déverrouillage puis a été arrêté avant tout scénario.
La réservation du téléphone par la session Erreur reste inscrite dans
MULTI-SESSION.md. Aucune nouvelle mesure physique n’est déduite de la compilation.

| Point | Preuve actuelle | Ce qui reste |
| --- | --- | --- |
| Chauffe Profil / manège | Défaut mesuré sur 76 ; protections incluses dans 79/80 | Refaire le parcours sur iPhone à thermique nominal, puis endurance. |
| Arrêt des moteurs du booster | Release 73 : compteur SceneKit stable à 546 après relais ; aucune vue 3D sur 115 relevés après fermeture ; CPU accueil médian 5 % avant/après | La thermique restait à 1. Ce parcours ne clôture pas la chauffe signalée ensuite sur 75 ; revalidation des corrections ultérieures. |
| Réponse réseau perdue | Deux tests UI avec vraie attribution serveur PASS : Réessayer orange, relance noir. Deux sachets et deux exemplaires relus | Mode avion réel au milieu du geste sur iPhone. |
| Endurance | Quelques minutes à thermique 0 sur le parcours Cartes du 18-09 | Une mesure prolongée au repos, en parcours et après fermeture ; pas de verdict d’endurance disponible. |
| Shiny animé | Foil et tilt génériques existants dans CarteVivante ; direction « très très marqué » inscrite pour les 50 scènes | Animation officielle par référence encore à réaliser, puis rendu et coût à mesurer. Ce n’est pas seulement un verdict d’œil manquant. Aucune image nouvelle générée. |
| Contraste des trois familles | 14 arts publiés et habillage réel contrôlé au simulateur | Lecture sur écran physique et verdict sur les trois univers. |

Sources : `README.md`, `ui-tests.log`, `ui80-tests.log`,
`ui-serveur-apres.json`, `iphone-tests.log` ; arrêt des moteurs :
`tools/perf/campagnes/2026-09-18-stories-langues-chauffe/cycle-vie.md`.

Les états de chauffe et de réalisation restent ouverts. Les 28 API Cartes et
53 contrôles Coffre réussis ne mesurent ni la température ni la qualité visuelle.
