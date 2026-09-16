# Séance dans la Dynamic Island système

**Reprise16:14 : Kathryn précise que l’absence est DANS WOOP OUVERT.
Le parcours natif47 ne satisfait donc pas le repère en séance au premier
plan. iOS réserve cette Live Activity à l’usage hors de son app. Cette limite
n’est pas un cache et les tests natifs sur simulateur ne valident pas le
besoin complet. Nettoyage des builds/caches effectué ; Release48 compilée, signée et
installée, version relue à16:29:46. Chauffe durable toujours ouverte.**

Le16-09, Kathryn tranche explicitement pour la vraie île iOS. Le décor SwiftUI
des versions43/44 ne répondait pas à cette demande. Il est retiré du parcours
normal ; seul le lab historique le conserve. Profil et Exercices ne sont pas
abaissés. Le bouton blanc ajouté sur Home est également absent du parcours.

Le composant est `WoopWidgets/WorkoutLiveActivity.swift`, déjà intégré et déclaré
dans le projet. La braise occupe les régions natives et réagit aux mises à jour
avec une animation de0,6s. Le chrono est le Text timer du système. Aucune nouvelle
horloge n'est ajoutée à l'app. Son contrôleur retrouve l'activité de la séance
par sa date de départ et termine les anciennes activités sur une liste capturée,
pour qu'une fin différée n'attrape pas la nouvelle séance.

Le tap système utilise le lien WidgetKit `woop://session/<départ>`, vérifié
contre la séance active ; l'ancien callback d'activité reste en compatibilité. Après le splash,
sur Home il ouvre le GrandPlayer ; sur les autres onglets il retrouve la
pastille libre à sa position conservée. Le système gère l'appui long/expansion.
Les gestes de sortie arbitraire dans la main et le fond blanc de l'ancien
prototype ne sont pas des capacités de cette Live Activity native.

La Live Activity standard apparaît dans l'île lorsque Woop est en arrière-plan.
Sources Apple : [présentations et cycle](https://developer.apple.com/videos/play/wwdc2023/10184/),
[retour vers l'app](https://developer.apple.com/documentation/activitykit/launching-your-app-from-a-live-activity),
[animations sur mise à jour](https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities).

Validation en cours sur le simulateur isolé AA36EA2C-0220-4292-9190-A78E13C759AE,
iPhone15/iOS26.5, copie temporaire avec hooks de test, version45. La preuve
attendue porte sur SpringBoard et non sur une vue de Woop. Sources dans
`sources45.json`. Aucune validation physique de rendu, de CPU ou de chauffe
à ce stade ; l'iPhone de Frédéric est de nouveau connecté au contrôle préalable.

## Reprise46

La compilation45 est réussie mais son exécution de tests est invalide :
**zéro cas exécuté**, malgré le symbole `IleNativeUITests` présent dans le
binaire. Aucun rendu ni geste n'est validé par ce résultat. Le simulateur
est redémarré après constat Shutdown ; le runner est retiré pour que la
reprise installe explicitement les produits recompilés.

46 ajoute le respect de Reduce Motion / de l'affichage atténué à la braise,
compte les séries cochées plutôt que les lignes prévues, et ne recrée pas
une activité fermée par l'utilisatrice à chaque série. Un tap sur une activité
ancienne ne doit pas être reporté sur une séance future. Les anciens tests
de capsule sont archivés dans `tools/nav/fouettage/tests/archive/` ; le banc
natif les remplace, les cas de la pastille libre sont conservés.

La Release46 de la copie de production a compilé avec succès. Les quatre
sources concernées correspondent à `sources46.json`. L'iPhone est connecté
mais `passcodeRequired: true` au contrôle de14:50 ; aucun lancement physique
ni nouvelle séance de test n'y est demandé.

## Retour explicite47

46 : le déplacement de la pastille libre passe en16,948s. La braise et le
chrono sont constatés dans SpringBoard, puis l'appui long ouvre bien la
présentation agrandie. Le retour ouvre Woop mais laisse la séance rangée :
le callback implicite ne réalise pas la destination demandée. Ce défaut
reste après correction des préconditions du banc (la sonde de séance
PageCard est absente sur Profil ; `-porteVue` évite le splash au départ).

47 déclare le schéma `woop` dans Info.plist et fournit `widgetURL` pour les
présentations de l'activité. La route compare le lien à la date de départ de
la séance active : aucun lien d'une ancienne séance ne déclenche la suivante,
et aucun lien ne termine une séance. La restauration rafraîchit également
la présentation, pour remplacer le lien d'une activité créée avant la mise
à jour de l'app. Sources dans `sources47.json`.

La signature46 a d'abord été refusée par le contrôle en sandbox
(`CSSMERR_TP_NOT_TRUSTED`), puis vérifiée avec succès avec accès au trousseau.
La version relue sur l'iPhone avant installation reste43.

## Parcours47 vérifiés sur simulateur

Deux tests réellement exécutés, deux réussis, aucun ignoré. Résultat
`/tmp/woop-ile-native47.xcresult`, appareil isolé iPhone15/iOS26.5 ci-dessus.
La version47 et son schéma `woop` ont été relus dans le bundle installé
avant l'essai. Le runner a été remplacé explicitement.

- Profil → écran d'accueil iOS → appui long sur l'île native → agrandissement
  → tap → pastille libre → jet vers l'île → récupération au tap → détail :
  **37,773s, réussi**.
- Home → écran d'accueil iOS → tap sur l'île native → GrandPlayer, sans
  pastille ajoutée sur Home : **15,978s, réussi**.
- Le déplacement / la pose de la pastille libre avaient passé le contrôle
  ciblé sur46, en16,948s ; ce geste n'a pas été modifié entre46 et47.

Captures lues : `native47-compacte.png`, `native47-agrandie.png`,
`native47-profil.png`, `native47-pastille.png`, `native47-detail-home.png`.
Le Profil garde sa hauteur initiale et le GrandPlayer est visible après le
retour Home. Les captures XCTest de pages n'incluent pas toujours le masque
physique du capteur ; l'ancienne capsule n'est pas reconstruite pour le simuler.
`native46-compacte.png` est une capture directe simctl du même rendu natif,
avant la correction du lien47, et ne valide pas ce lien.

Ces constats ne sont pas une mesure CPU/GPU ni une validation de chauffe
durable sur l'iPhone. La Live Activity n'ajoute pas de moteur continu à l'app.

## Installation physique47

Compilation Release47 réussie, signature vérifiée avec accès au trousseau,
sources conformes à la copie de production. L'ancienne version43 est relue
juste avant l'installation. Installation réussie à15:18, puis relecture de
`Bundle Version: 47` à15:19 via devicectl. Journaux et JSON correspondants
conservés dans ce dossier. Aucune donnée de compte ou de séance n'est modifiée
pour cet essai ; aucune séance de démonstration n'est créée sur l'iPhone.

Le contrôle de verrouillage à15:17 indique `passcodeRequired: true`. Aucun
lancement refusé ni boucle de réveils supplémentaire n'est tenté. Le retour
normal avec `-sansSondeVol`, si une activation historique persiste, ne peut
pas être vérifié tant que l'appareil reste verrouillé. Les parcours et les
captures47 cités ci-dessus restent exclusivement ceux du simulateur.


## Reprise physique après déverrouillage

Version47 relue à15:39 ; passcodeRequired=false, iPhone15/iOS26.6.1, liaison
filaire. Lancement réussi à15:41:39 avec `-sondeVol -ecranEveille -navProbe
-openTab home`. Le téléphone est en charge sur la capture ; luminosité non
relevée. Aucun drapeau de séance de démonstration, de laboratoire ou de
fermeture n’est utilisé.

Le runner séparé `physique47/NavRuntimeUITests.swift` active uniquement
l’app installée. À15:44, la capture `physique47/home-sans-seance.png` montre
la Home avec « pull to start », et la sonde indique seance=0. Aucune activité
« Séance en cours » dans SpringBoard. **Un cas exécuté, un ignoré en19,371s** :
aucune assertion d’appui long ou de retour natif n’a donc pu être exécutée.
Le résultat global « TEST EXECUTE SUCCEEDED » ne les valide pas. La demande
de démarrer sa séance a été adressée à l’utilisatrice ; le banc n’en crée pas.

Traces originales copiées avant relance dans `physique47/`. La première
session `154139` s’arrête à52s après un passage en arrière-plan. Une nouvelle
trace `154232` existe après réouverture, sans journal nav correspondant :
les fenêtres de cette trace ne permettent pas d’affirmer un premier plan
ininterrompu. Analyse exploratoire t120–170 :49 lignes, thermique0 puis1 à
t161,4 ; CPU médian9 %,60,1 callbacks/s. Ce n’est ni le coût de l’île (aucune
séance), ni une comparaison avec42, ni une preuve de chauffe résolue. Les
résumés et leurs bornes sont dans les fichiers `analyse-*.json`.

Relance `-sansSondeVol` réussie à15:46:11 après collecte. Les données de compte
et de séance sont conservées. Contrôle de restauration réussi en3,592s ; capture `physique47/home-sans-sonde.png` relue, sans HUD et toujours sans séance active.


## Clarification du besoin au premier plan et build propre48

À16:11, le contrôle physique commence déjà sur la story de fin de séance,
puis la capture suivante montre le booster. Il ne prouve donc pas l’absence
d’une Live Activity pendant une séance active. Le cas est ignoré, sans
assertion d’expansion ni de retour exécutée ; voir `physique47/controle-1611.log`
et `controle-1611-story-fin.png`. Le journal système change ensuite de PID
SpringBoard et signale des processus terminés ; la cause n’est pas établie.

Kathryn précise ensuite : **« Dans Woop ouvert »**. Le montage47 cache la
pastille dès que dansIle=true, alors qu’iOS masque la Live Activity de l’app
au premier plan. Cette absence est une conséquence du choix d’interface,
pas une preuve de corruption du cache. Ne pas considérer la demande de
vraie île comme une acceptation de perdre le repère dans Woop.
[Consigne Apple sur la visibilité](https://developer.apple.com/design/human-interface-guidelines/live-activities).

Sur demande explicite de repartir à zéro, les dossiers de build de ce
chantier `/tmp/woop-ile-20260916-release` et `/tmp/woop-ile-20260916-dd` sont
supprimés, avec leurs ModuleCache/CompilationCache/SDKStatCaches. Une copie
neuve des sources actuelles est créée dans `/tmp/woop-ile48-propre-prod`,
manifeste `sources48.json`. Compilation Release48 app+widget dans un nouveau
DerivedData `/tmp/woop-ile48-propre-dd`, sans réemploi des produits47.
Ce nettoyage ne modifie pas les données du compte ni les séances du téléphone.
Il ne modifie pas non plus la règle de visibilité d’iOS.


### Résultat du rebuild48

Compilation Release propre réussie, puis `codesign --verify --deep --strict`
réussi. App et widget portent tous deux CFBundleVersion48. Installation
réussie à16:29, suivie de la relecture de48 sur l’iPhone à16:29:46. Les caches
et produits47 de ce chantier ont bien été retirés avant le build48.

La durée vient d’une reconstruction complète ; un échantillon du compilateur
à16:27 montre l’optimisation LLVM, après la vérification des types. Neuf
compilateurs Swift étaient actifs sur le Mac au relevé de concurrence. Le
simulateur isolé de ce chantier a été arrêté pour libérer des ressources.

Les sources de48 correspondent à la copie prise avant compilation, décrite
par `sources48.json`. Une modification concurrente de `ChambreHiit.swift`
arrive pendant la compilation et ne fait pas partie de cette copie ; le
fichier du dépôt n’est pas écrasé. Aucun nouveau changement de comportement
de l’île ni de données du compte n’est inclus dans ce nettoyage.


Le lancement48 demandé à16:29:44 avec `-sansSondeVol` est refusé par iOS :
CoreDevice10002, FBSOpenApplicationErrorDomain7, raison **Locked**. Aucune
nouvelle tentative en boucle ni aucun test tactile48 n’est lancé. L’installation
et la relecture48 sont réussies ; le lancement, le rendu et la chauffe48 ne
sont pas validés. La sonde avait été retirée sur47, vérifiée à15:46 ; elle
n’a pas été réactivée depuis. Le téléphone doit être déverrouillé pour ouvrir48.


### Reprise48 après déverrouillage,16:31

À la demande « ok réessaie », lancement `-sansSondeVol` réussi à16:31:09.
Version48 relue immédiatement sur l’iPhone. L’obstacle Locked de16:29 est
levé ; le constat d’absence de repère au premier plan reste distinct.

Contrôle de capture réussi en3,713s, un test exécuté sans échec. Image relue
`physique48-home-sans-sonde.png` : Home visible, sans sonde ni surcouche,
invitation « pull to start ». Ce contrôle confirme l’ouverture48 ; il ne
valide ni l’île pendant une séance, ni la chauffe durable.

## Reprise50 au premier plan

La clarification foreground impose le repère tactile dans Woop. Après49
refusée pour son placement,50 aligne chrono gauche/stop droite à hauteur du
capteur et pose le halo blanc intérieur Home. La Live Activity décrite plus
haut reste le parcours background, avec deux tests de retour50 passés.
[État50](rendu50.md).
