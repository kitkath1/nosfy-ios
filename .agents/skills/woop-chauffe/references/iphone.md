# Mesures Woop sur l'iPhone

## Connexion et outils

Identifier l'appareil actuel avec `xcrun devicectl list devices --json-output …`.
Le téléphone de la campagne du15-09 est un iPhone15, bundle `fr.kathryn.woop`.
Ne pas imposer son identifiant dans un script réutilisable : le lire dans la liste.
Pour Xcode, employer le hardwareUDID ; pour devicectl, l'identifiant CoreDevice.

Un appareil « available (paired) » peut être seulement détecté par le réseau.
Vérifier `device info details`, puis `device info lockState`, avec un timeout.
`idevice_id -l` vide ne prouve l'absence USB que si la commande avait accès aux
services du Mac. Une erreur XPC en sandbox ne signifie pas que le câble est absent.
Employer les permissions prévues par l'environnement, sans contourner un refus.

Installer le `.app` Release déjà compilé si ses sources sont celles à vérifier :

```sh
xcrun devicectl device install app --device "$woop_device" --timeout 45 "$woop_app"
xcrun devicectl device info apps --device "$woop_device" --bundle-id fr.kathryn.woop --json-output /tmp/woop-app-installee.json
xcrun devicectl device process launch --terminate-existing --device "$woop_device" --timeout 20 fr.kathryn.woop -- -sondeVol -ecranEveille -navProbe -openTab home
```

Le séparateur `--` avant les arguments de l'app est nécessaire. Le maintien
éveillé `-ecranEveille` expire après30min par lancement ; il ne déverrouille pas
iOS. `-sansProtectionThermique` est un diagnostic temporaire (60s), pas un réglage
de production ni un argument d'endurance. Un essai dont le rendu change à son
expiration doit être segmenté.

## Automatisation et collecte

Chercher le runner et ses sources dans la **dernière campagne**, ou créer un test
XCTest ciblé. Les fichiers `/private/tmp/woop-nav-runtime-qa` étaient un outil de
la session du15-09 ; leur existence future n'est pas garantie.

Parcours utile : Home → Exercices → Home → Profil → Réglages ; plusieurs retours
Exercices/Profil avec défilement ; ouverture/fermeture du tiroir de départ sans
lancer une séance. Vérifier les destinations et les boutons accessibles.
Fermer « Later » si la bienvenue du jour recouvre la Home ; ne pas toucher Claim.
Une assertion sur le libellé « Supprimer mon compte » ne valide pas sa suppression.

Si le runner échoue **avant** le test (`Locked`, `Timed out while enabling
automation mode`, liaison rompue), ne pas annoncer un échec de navigation de
Woop. Conserver le journal ; une reprise bornée après contrôle de la connexion
suffit. Ne pas empiler des runners identiques en espérant débloquer la liaison.
Continuer le travail indépendant et demander seulement l'action matérielle
manquante si nécessaire.

Utiliser `XCUIApplication.screenshot()` pour le rendu complet : les captures
internes UIKit peuvent montrer du noir à la place d'une AVPlayerLayer. Une image
noire ainsi obtenue ne prouve pas que les flammes sont absentes sur l'iPhone.

Lister `Documents` avec `device info files`, puis copier les fichiers de la
session avec `device copy from` (`--domain-type appDataContainer`,
`--domain-identifier fr.kathryn.woop`). `vol-DATE.jsonl` contient la sonde,
`nav-DATE.jsonl` les états/événements. Relever les noms exacts ; le dernier fichier
après une relance peut appartenir au mauvais processus. En cas de liaison
CoreDevice rompue et USB réellement présent, `tools/perf/collecte_usb.py` est le
repli existant à lire avant usage. Ne pas supprimer les journaux du téléphone.

## Interpréter les fenêtres

Exemple depuis le dépôt :

```sh
python3 .agents/skills/woop-chauffe/scripts/analyse_sonde.py /tmp/essai-vol.jsonl --start 15 --end 180
```

Le résumé exclut les lignes où la Home est explicitement recouverte ou engagée,
ainsi que les phases de bissection. Il signale les champs manquants et les trous
de journal. Il ne peut pas détecter à lui seul une porte, une visite ou un popup
non instrumenté : corroborer avec le journal nav et la capture. Vérifier aussi
`applicationState=0` (active) dans nav : la sonde peut continuer en état1
(inactive), comme pendant l'échec d'initialisation XCTest du16-09. Une cadence
normale dans cet état ne valide pas un écran utilisable. Pour comparer
des variantes, examiner des fenêtres de même contexte, durée et état thermique,
et lire la chronologie entière. Ne pas présenter la dernière valeur comme médiane.

Pour une endurance, viser d'abord une fenêtre de plusieurs minutes adaptée au
symptôme (par exemple10min Home puis4cycles et5min de récupération). Interrompre
le stress si l'état thermique atteint2/3. Une courte fenêtre à0 ne garantit pas
le confort après une longue séance. Documenter le câble/charge : il peut compter
dans le contexte, mais le gel initial a aussi été observé sans câble en Release.

## Instruments et instrumentation

Pour Power Profiler/Time Profiler, récupérer le PID vivant et attacher `xctrace`
**par PID** : l'attache par nom Woop a échoué (E48). Une capture de15s nécessite
du temps de préparation/sauvegarde ; l'enveloppe90s de la campagne était adaptée.
Lancer sans HUD pour contrôler son surcoût et conserver la trace brute.
Les colonnes anonymes d'énergie ne sont pas des watts ; une trace sans métrique
Metal par processus ne permet pas une attribution GPU.

La sonde d'animations natives `-sondeAnimations` est ponctuelle et bornée. E53 :
des nombres infinis de CALayer transmis à `NSJSONSerialization` ont fait planter
la sonde elle-même. Conserver valeurs finies ou textuelles et validation JSON ;
`try?` ne capture pas une exception Objective-C.

## Dépôt partagé et preuves documentaires

E56 : une classe présente seulement dans la refonte non commitée d'une autre
session ne doit pas devenir une dépendance implicite de notre commit. Vérifier
les changements sélectionnés contre HEAD. Si la préparation d'un patch échoue,
ne pas exécuter ses opérations de stage dépendantes.

Le build du working tree et celui d'un checkout isolé ont des portées différentes.
Le15-09, le checkout isolé échouait sur des dépendances étrangères ; cela n'a pas
été masqué par le build du téléphone. Les six références documentaires invalides
étaient également signalées (E51).

Pour le site, lire ses commandes actuelles ; à cette date `npm run artefact`
précédait `npm run verif`. Ne pas répéter le blocage sandbox déjà décrit E33.
Lire les noms des captures réellement produites au lieu d'inventer `qa-390.png`.
