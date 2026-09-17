# Reprise iPhone du 17 septembre — diagnostic55

USB connecté, transport wired, iPhone15/iOS26.6.1. Version53 relue à08:41.
Capture initiale de la Home normale ; ce n’était pas encore le panneau Start.
Le test suivant est bloqué avant exécution par Locked. Runner arrêté ; après
confirmation de déverrouillage, relance à08:45:56 avec -sansSondeVol,
-ecranEveille et -navProbe. La trace confirme ecranEveille=true.

Le premier parcours automatisé ne trouve pas Start : Later appartient alors
au Welcome, cible inaccessible (-1,-1), et la card Route ne s’ouvre pas.
Ce résultat ne prouve donc rien sur le bouton Start. Film examiné : Home.

Version55 compilée en Release depuis les mêmes sources que53, avec seulement
cinq points de trace NavDiagnostic ajoutés au départ (bouton, relais, racine,
montage du film, fin). Aucun changement de geste, de dessin ou de backend.
Ces traces sont inactives sans -navProbe ; pas de minuterie supplémentaire.
Sources complètes identifiées dans sources55.json.

Installation puis relance à08:48:20 avec -sansSondeVol -ecranEveille -navProbe
-homeChemin. Ce dernier argument ouvre la Route sans lancer de séance.
Le test du panneau passe5,334s : Later ferme, le galet du jour rouvre Start.
Start frame(148,67;448,33;73,67;34), hittable=true. Aucun tap automatique sur
Start du compte personnel. Les captures personnelles restent dans /tmp.

Version55 relue sur le téléphone à08:50:15. La version55 est un diagnostic, pas un correctif. Le prochain appui manuel
peut être relu après coup dans Documents/nav-*.jsonl : pas de fenêtre courte
imposée à l’utilisatrice. En attente de cet appui, cause et défaut encore ouverts.
Aucune mesure thermique ajoutée ; le scénario ne valide pas la chauffe durable.

Retour manuel : « Exercices s’ouvre sans la vidéo ». La capture suivante
(08:51, même PID37253, app runningForeground) montre pourtant encore Route
et Start. Le journal de ce processus ne contient pas les événements depart.* ;
seulement un appui/relâchement Accueil plus tard. Ne pas attribuer sans preuve
l’absence de film à Reduce Motion ou à la reprise d’une séance existante.
Vérification demandée sur l’identité de l’appareil utilisé. L’export de cette
capture a d’abord été rejeté par la validation automatique (limite d’usage),
puis autorisé après vérification de sa portée strictement locale dans /tmp.

Kathryn confirme que l’essai est sur ce même iPhone. Pour sortir de cette
divergence, banc56 préparé dans la copie /tmp seulement : garde
-startTactileLab après l’entrée de demarrerDepuisChemin, avant tout fetch,
insertion ou save de Workout. Le même bouton et le même lecteur sont utilisés ;
le banc ferme Route et révèle Exercices sous le film. Aucune création de séance
possible par ce callback. L’injection exacte et le test sont archivés ici.
Ce banc pourra valider le toucher/montage du film, pas l’écriture serveur.

## Reproduction56, puis correction57

Le test physique reproduit enfin l’absence de vidéo : Start touché, relais,
racine, garde de banc atteints ; sélection Exercices60ms plus tard. Aucun
événement film-monte. Le lecteur n’est donc pas monté ; cet essai exclut un
simple saut Reduce Motion ou un problème d’UUID de séance pour ce symptôme.
La capture après tap montre Exercices. Test échoué11,489s. Les traces sont à
therm1 ; cela ne nie pas la forte chauffe signalée par Kathryn juste après.
À09:01:39, Woop arrêté (PID37339) pour laisser refroidir. Aucun autre parcours
physique en boucle ; la suite se fait sur simulateur.

Correction57 : le film quitte overlayPreferenceValue de la visite et possède
son overlay indépendant. Route est démontée au Start, Exercices ne s’ouvre
qu’à la fin réelle ou au passage explicite du film. Un Start pendant une séance
déjà ouverte montre aussi le film en conservant la même séance. Le backend
reste déclenché par la création locale, indépendamment de la lecture.
La garde temporaire de banc56 est retirée de la copie de production57 et n’a
jamais été ajoutée au dépôt principal. Tests Release sans countProbe prévus :
la sonde ne doit plus être nécessaire au montage du film.

Validation57 : Release simulateur, test04 sans countProbe au départ PASS21,372s.
Film visible, fin puis Entraînements sélectionné ; relecture locale ensuite
avec countProbe : actives=1. -sansServeur pendant tout ce test, aucune nouvelle
séance serveur créée. Les tests du lecteur53 ne sont pas rejoués sans raison.
Premier lancement par un ancien xctestrun Debug : zéro test exécuté, ignoré.
Le vrai runner Release arm64-x86_64 a exécuté le test ci-dessus.
Build Release iPhone57 réussi, sources comparées au dépôt, injection56 absente.
Le parcours corrigé n’a pas été rejoué sur le téléphone après la forte chauffe.

Version57 installée et relue à09:11:33, sans lancement après installation.
L’iPhone est laissé au repos. Les captures QA du simulateur montrent le film
et l’arrivée à Exercices ; aucun écran personnel n’est incorporé aux preuves.

Documentation régénérée : index autonome1996782octets ; vérification du site
réussie16s et capture mobile examinée. Flow local actualisé ; publication au
lien Artifact externe toujours indisponible dans les outils de cette session.
Aucun commit de ce chantier demandé ni effectué.

## Confirmation utilisatrice et commit du départ

17-09, Kathryn confirme : « très bien ça a marché la vidéo » et demande un
commit limité à cette session, avec le flow à jour. Le parcours Start → vidéo
→ Exercices est donc confirmé sur son iPhone. Cette confirmation fonctionnelle
ne constitue pas une nouvelle mesure thermique. Les étapes de tutoriel et la
rapidité du panneau Start, demandées ensuite, restent hors de ce commit.
