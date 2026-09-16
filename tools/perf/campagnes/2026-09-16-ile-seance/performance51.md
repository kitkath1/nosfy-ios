# Halo51 — garder la marge pour les gestes

L'utilisatrice valide le dessin blanc et confirme le drag50. Garder le
seuil12pt, les ressorts, les zones et les comportements. L'allègement51
répond à16 % CPU médian du halo50 animé sur iPhone, thermique0/protection0
(17 lignes t15,2–31,5 dans le lab ; pas la vraie Home).

Deux textures du même halo sont calculées une fois à l'échelle de l'écran.
Le compositeur fait leur fondu ; plus de rampe SwiftUI permanente dans le
chemin normal. Le contour et la disposition restent ceux validés. Le souffle
combine4,1s et6,7s sur un raccord274,7s ; l'ancien éclat bref est remplacé
par ce fondu entre les deux intensités. Le chrono garde son horloge1Hz.

Pause en arrière-plan, Reduce Motion, couverture par le détail et protection
thermique. Le native conserve sa pose à la suspension ; la reprise redémarre
le cycle. Au démontage, retrait de son animation. `-ileHaloSwiftUI` garde
le témoin précédent dans le même binaire, `-sansSouffleIle` le repos.
Aucune réserve verticale de page ni nouveau geste.

Sources : sources51.json. Compilation Release51 et vérifications en cours.
Aucun gain CPU51 annoncé avant la mesure ; ni watts ni GPU ni chauffe
durable ne sont couverts par le protocole court.

Release51 réussie, signature vérifiée ; installation51 relue17:38:40.
Quatre tests simulateur du binaire final passent en39,860s, dont le drag
depuis le chrono(100,5;33) et le stop au centre de son dessin. La texture
Home est relue visuellement : home-halo-blanc51.png. Mesure physique en cours.

Premier relevé natif51 : therm0/protection0,17 lignes t15,2–31,5,
CPU médian1 %,60,1 callbacks/s, pire17ms. Le lab affiche le vrai composant,
mais ses champs Home par défaut ne décrivent pas la vraie Home. Le script
analyse_sonde exclut donc ce contexte ; médiane calculée explicitement pour
la fenêtre du composant. Données brutes conservées.

Parcours physique natif passé49,269s. Une rotation Landscape Left est
signalée àt48,07 du test, après la fenêtre de coût ; ne pas attribuer la
fin du parcours à un portrait constant. Le témoin suivant fixe le portrait.
Comparaison dans le même binaire en cours.

## Comparaison51 terminée

Même binaire, iPhone15 par câble, animations actives, therm0/protection0.
Fenêtres t15,2–31,5 :17 lignes et16,3s chacune.

| Moteur | CPU médian | Callbacks/s | Pire intervalle |
|---|---:|---:|---:|
| Natif51 | 1 % | 60,1 | 17ms |
| Témoin SwiftUI51 | 16 % | 60,1 | 17ms |

Ordre natif puis SwiftUI, sans troisième retour mesuré. Les deux parcours
du composant passent49,269s et49,818s. Ce relevé court établit un gain CPU
d'environ94 % dans le lab ; il ne chiffre ni GPU ni watts et ne clôt pas la
chauffe longue de Woop. Les protections sont restées actives.

Raw iPhone : `Documents/vol-20260916-173849.jsonl` puis
`Documents/vol-20260916-174132.jsonl`, copiés avant chaque relance.
Le témoin ajoute seulement `-ileHaloSwiftUI` aux arguments du banc.
Sources et scripts archivés ; aucun entraînement de compte créé, supprimé
ou terminé. Retour au moteur natif par défaut et `-sansSondeVol` réussi
à17:42:43. Capture de retour normal réussie6,031s à17:44:18, sans HUD.

La dernière capture est la vraie Home noire51 avec la séance de l'utilisatrice
(14min), chrono gauche/stop droite et halo blanc visibles, aucun HUD. Elle
confirme la présence au premier plan et la restauration ; les chiffres CPU
ci-dessus restent ceux du lab, pas une mesure de cette Home réelle.
