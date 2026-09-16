# Reprise iPhone — 16 septembre, à partir de 11:09 (Paris)

L’utilisateur ouvre Woop et redonne le contrôle. iPhone 15, iOS 26.6.1,
connexion filaire ; la capture montre la batterie en charge. Luminosité et
puissance de charge non mesurées. Le maintien éveillé est actif pour les essais.
Aucune suppression, déconnexion, création ou clôture de séance par le protocole.

## Version 37 : navigation et pull rétablis dans les preuves

- Version installée relue : **37**, lancement réussi à 11:09:40.
- Home → Exercices → Home → Profil → Réglages : **PASS, 10,754 s**, à 11:10:40.
  Les libellés de compte sont seulement vérifiés, jamais actionnés.
- Contrôle de la vraie Home, bienvenue absente/fermée, Profil accessible :
  **PASS, 3,128 s**, à 11:12:05. Capture relue : texte anglais, 4 séances
  comme le widget, prénom Kathryn ; aucune surcouche.
- Trois ouvertures/retours du pull puis Profil et Home : **PASS, 36,242 s**,
  à 11:15:18. Capture du troisième pull relue : apparition partielle avec flou
  visible. Ce test vérifie les destinations ; il ne mesure pas la continuité
  visuelle de chaque image du retour.

## Home rouge 37 : faible CPU, mais très peu de temps nominal

Journal `vol-20260916-111155.jsonl`, t = 15,2 à 144,1 s : 128 lignes,
CPU médian **1 % d’un cœur**, callbacks médian 60,1/s, intervalle maximal 17 ms,
aucun gel signalé. Les états nav confirment l’app active sur Home.

**124 lignes sont protégées (thermique 1 / protection 1)**. Le téléphone revient
à nominal à t = 141,1 s : seulement **4 lignes nominales**, médiane CPU 1,5 %.
Cette fin de fenêtre de trois secondes ne valide pas le rendu normal prolongé.
Le thermique repasse à 1 pendant le test de pull. Après les gestes, t > 215,2 à
270 s : 54 lignes, CPU médian 1 %, thermique 1. Le booster observé est hors
fenêtre, arrêté, compteur de rendus constant à 72.

Les chiffres CPU et callbacks ne sont ni des watts, ni une mesure GPU, ni des
degrés. Le téléphone n’est pas déclaré « ne chauffe plus ».

## Correctif 38 : la parole ne dépend plus du repos des décors

Lecture du code 37 : `FoyerPage.dort` inclut `ambianceAuRepos`, activé dès
l’état thermique fair (1). Utiliser `!dort` pour `paroleActive` coupait donc
aussi les mots et l’haptique de la Home noire, même si la page était visible.
C’est une condition de code établie ; aucun film de comparaison 37/38 à état
thermique identique n’a été réalisé.

38 sépare `pageInactive` du repos des décors. La réplique finie reste permise
à fair ; elle est coupée sous une couverture, hors onglet, en arrière-plan,
avec Reduce Motion ou à serious/critical. Les décors conservent leur protection.
Le backend et le lot 03 restent identiques.

Release 38 compilée avec succès, installée puis lancée à **11:17:09** sur le
banc `-homeSeance`. Ce banc affiche la Home noire et un chrono local, sans
écrire de séance. Les mesures de ce banc ne valent pas une séance complète.

Capture 38 relue à 11:18 : texte « 1 minute » et chrono **1:17**, cohérents ;
quatre lignes courtes sans débordement. Capture seule, pas un film de l’arrivée.

Journal `vol-20260916-111709.jsonl`, t = 15,2 à 166,5 s : **150 lignes**, CPU
médian **2,5 %**, pic 37 %, callbacks médian 60,1/s, intervalle maximal 69 ms,
aucun gel marqué. **Toutes les lignes sont en thermique 1 / protection 1.**
Le faible CPU ne valide donc pas le rendu intégral ni la chauffe à long terme.
Attention : le champ sonde `seance=0` ne reconnaît pas ce banc visuel. Le contexte
noir est établi par l’argument de lancement et la capture, pas par ce champ.

Lancement normal avec `-sansSondeVol -ecranEveille -openTab home` accepté après
collecte ; le banc noir est retiré. Les petites vibrations restent à confirmer
par l’utilisateur : la sonde et les captures ne peuvent pas mesurer le ressenti.

**Quatre cycles Exercices → Home → Profil (défilement) → Home sur 38 : PASS,
66,259 s**, fin à 11:21:57. Compteurs éteints pendant ce parcours. Aucune
nouvelle mesure thermique n’est donc attribuée à ces quatre cycles. La Home
est la destination finale ; le maintien éveillé expire 30 minutes après le
lancement de 11:20. Aucun nouvel échec de liaison ou d’automatisation ici.

Capture finale relue à 11:22:54 : Home habituelle, aucun HUD de sonde. Le glyphe
Profil reste clair dans la barre alors que la Home est visible ; cette différence
de sélection visuelle est conservée dans la capture, sans bloquer les parcours testés.
