# Lune de la visite et description exercice — 17 septembre2026

Demande : allumer aussi la petite lune à la quatrième étape, après Profil ;
ajouter sous Choose an exercise une description FR/EN sur l’ajout à la séance ;
commiter seulement ces changements. Ajout en cours de tâche : une haptique
sous la vidéo count, à inclure dans le même commit.

## Implémentation59

Le contour MoonShape de la marque est cuit une fois en UIImage. Le compositeur
anime son opacité avec le même moteur que Profil. Pendant cette étape, la pièce
sous-jacente reste de face au repos ; son shader et le gyroscope n’ajoutent pas
une animation sous le glyphe. À la sortie, l’overlay est démonté et la pièce
retrouve son comportement habituel. Gestes existants conservés.

Reduce Motion, protection thermique, onglet caché et arrière-plan figent le
blanc. Le barreau existant -sansAppelProfilVisite fige les deux glyphes. Aucun
TimelineView ni repeatForever SwiftUI ajouté. Le coût et la chauffe durable
ne sont pas déduits de ces choix de code : aucune nouvelle mesure sur iPhone.

Sous le titre du guide exercice : « Il s’ajoutera à votre séance. » /
« It will be added to your session. », selon la langue d’onboarding. Le texte
sourd17pt apparaît après le titre, avec le même phrasé fini que la visite Home.
Passer/Skip et le tap sur la vraie carte restent disponibles.

## Validation

Copies de compilation déjà validées58, seuls trois fichiers app recopiés.
Premier build59 réussi ; quatre parcours ciblés réussis au simulateur :
FR23,112s, EN11,834s, liste10,062s et Profil → Pièces → Passer12,901s. Aucun banc ni fixture
n’est exécuté sur le téléphone personnel. Le travail backend/story reste
hors du commit. Documents et HTML construits depuis HEAD + nos seuls hunks.


## Haptique du décompte

Quatre impulsions aux apparitions de 1, 2, 3 puis GO (0,2 / 1,9 / 3,45 /
4,8s, calage sur les images du fichier24fps). Trois impacts rigid à0,7,
puis heavy à1 sur GO. Un observateur AVPlayer de frontières du temps vidéo,
pas de minuterie ni horloge par image. Pause en arrière-plan ; observateur
retiré au tap, à la fin, à l’échec et au démontage. Garde contre les callbacks
tardifs et les doublons ; aucun rattrapage en rafale. Reduce Motion passe déjà
le film et n’arme pas l’observateur. Barreau -sansHaptiqueCount.

L’ajout arrive après les quatre parcours59 de la lune et du texte. Rebuild
final59 et régression ciblée du lecteur (tap/pause/reprise et départ réel vers
le guide) ; le simulateur ne prouve pas la sensation haptique sur iPhone.

Rendu constaté sur captures59 : le croissant passe du contour sombre au blanc
plein, puis retrouve sa pièce à la sortie. Descriptions FR/EN visibles, mode
liste conservé. Livrable documentaire final reconstruit et contrôlé intégralement
en20s (types, contenu, HTML déterministe, captures, dix pages à390px).
Le lien externe n’est pas republié par cet environnement.

## Livraison finale59

Builds Release appareil et simulateur réussis après l’ajout haptique.
Régression finale : passage/tap/arrière-plan/reprise49,401s et Start → vidéo
→ titre/description FR → Passer → aller-retour d’onglet137,878s, zéro échec.
Ces durées sont celles du banc XCTest, pas une mesure de latence tactile.
Les quatre parcours visuels précédents restent valables : leurs trois fichiers
app n’ont pas changé lors de l’ajout au lecteur.

Version58 relue avant installation,59 installée puis relue par devicectl.
Aucune séance créée ni test de données lancé sur l’iPhone personnel.
Le ressenti haptique et la chauffe durable sur iPhone restent à confirmer ;
les parcours du simulateur ne les mesurent pas. La version finale est livrée
sans nouvelle boucle de relances sur le téléphone.
