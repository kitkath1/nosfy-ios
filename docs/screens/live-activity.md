# Live Activity de séance — lune, muscu et cardio

Décision de Kathryn, 18 septembre 2026 : reprendre le logo lune exact et faire
comprendre l’exercice en cours. La grande carte verrouillée et l’île
déployée portent le portrait `nosfy_yeux_rouge.png` choisi sur le Bureau. Les
formats compact et minimal gardent le logo lune. La demande
d’autorisation reste une présentation gérée par iOS, pas une nouvelle modale Home.

## Ce que la carte dit

| Situation | Information principale | Temps | Mouvement |
|---|---|---|---|
| Séance sans exercice lancé | Séance en cours, résumé acquis | Depuis le départ de séance | Lune stable |
| Muscu | Nom, numéro de série | Effort écoulé | Reflet au changement de phase |
| Saisie muscu | Nom, saisie de la série | Effort figé au temps du player | Transition courte |
| Repos muscu | Nom, série, reps et kg saisis | Décompte, borné à zéro | Jauge système |
| HIIT | Nom, effort n / récupération, km/h | Temps écoulé dans la phase | Nouveau palier à la bascule ou au sceau d’allure |
| Tapis continu / escalier | Nom, km/h / niveau | Temps actif, figé en pause | Paliers à chaque allure validée |
| Piscine | Nom, longueurs et mètres enregistrés | Chrono de séance | Reflet à la correction du compteur |

Le nom vient de l’exercice lancé, jamais du dernier écran consulté. Les textes
et les nombres suivent la langue FR/EN choisie dans l’app. Aucun nombre total de
séries ni objectif de durée n’est inventé. HIIT et cardio continu sont libres :
la récupération cardio monte, le repos muscu programmé descend.

La frise conserve au plus douze allures. La hauteur représente la vitesse ou le
niveau ; la largeur ne représente **pas** la durée du segment. L’effort est ambre,
la récupération et la pause sont atténuées ; les mots restent visibles pour que
la couleur ne soit jamais la seule indication.

## Animation et cycle de vie

Le portrait original est une ressource locale partagée entre app et widget,
rendu en 64, 128 et 192 px (1x/2x/3x) depuis le 20-09 : une image plus grande
que la présentation ne s’affiche pas sur iPhone (règle Apple, ActivityKit),
fixe et sans moteur d’animation. `MoonShape` réutilise le contour exact du logo
dans les petits formats. Un reflet traverse ce contour à
une mise à jour, sans rotation ni pulsation permanente. Les paliers apparaissent
par une transition brève. Reduce Motion et l’écran atténué retirent ces mouvements.
Les chronos et la jauge de repos sont confiés à iOS : aucun nouveau Timer,
TimelineView ou envoi périodique n’est ajouté au suivi.

La comète sur 90 minutes n’est plus montée dans la Live Activity de production.
Son ancien banc reste archivé et ne démontre pas le nouveau rendu.

Les gestes du player publient un instantané ; la molette publie à son relâcher,
pas à chaque mouvement du doigt. Les notifications ActivityKit sont sérialisées.
Une ancienne vue ne peut pas effacer le focus d’une autre fiche. Fin d’exercice
ou sortie de fiche : retour au résumé ; Stop ou annulation de séance :
`end(..., dismissalPolicy: .immediate)`, sans attendre les updates en file. Une
séance arrêtée est mémorisée pendant ce processus pour ignorer les callbacks
tardifs, même si leur ancien modèle paraît encore actif. Une ancienne séance
fermée ne peut pas faire disparaître la nouvelle.
Une activité balayée n’est pas recréée par les mises à jour du même processus.
Au redémarrage à froid, le résumé de la séance est restauré ; un player conservé
uniquement en mémoire n’est pas prétendu restauré.

## Données et backend

`ContentState` garde ses trois champs historiques et ajoute deux champs
optionnels : le focus de l’exercice et la langue. L’ancien format reste décodable.
Le focus contient des dates, des valeurs saisies et une courte frise, jamais un
flux d’images ou un échantillonnage de capteur.

Aucune migration Supabase, RPC, table, règle de gain ou notification push ajoutée.
Hors séance, lancer réellement un effort ouvre maintenant la séance locale dès
ce lancement pour permettre son suivi. L’observateur existant de `NosfyApp`
synchronise cette même séance ; consulter une fiche seule ne l’ouvre pas.
Les séries/phases/longueurs continuent d’être écrites par leurs chemins existants.

Les limites et résultats mesurés sont consignés dans
[le rapport de validation](../../tools/live-activity/ETAT-2026-09-18.md), ainsi que
dans la brique `b-flow-live-lune`, la mesure `m-live-lune-iphone` et QA16.

## Vérification physique encore ouverte

Sur iPhone, parcourir muscu, HIIT, tapis continu, escalier et piscine. Contrôler
la bannière verrouillée et les trois formats d’île, récupération, pause/reprise,
fin d’exercice et Stop. Stop doit fermer la carte ; un callback tardif ne la
recrée pas. Vérifier aussi le tap de reprise, le refus d’autorisation, le balayage,
l’arrière-plan, le repos à zéro, Reduce Motion et l’écran atténué. Les69 contrôles
de modèles/pilote et l’aperçu du simulateur ne valident pas ActivityKit réel ni
la consommation ou la chauffe. Les réserves sont signalées dans l’index Flow.
