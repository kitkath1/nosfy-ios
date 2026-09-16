# Rétablir la pastille dans Woop —49

Demande de reprise : « un jour tu avais réussi ». Le montage47–48 avait
laissé `dansIle=true` tout en retirant le composant tactile de l’app. La
Live Activity, masquée au premier plan, n’en assurait pas le remplacement.

49 rétablit la branche île ⇄ pastille dans l’app, son geste stable au parent,
le stop et l’accès au détail. La Home garde son accès direct au détail.
WidgetKit conserve la Live Activity hors de Woop : ce sont deux présentations
avec des responsabilités distinctes, pas une prétendue prise UIKit du capteur.

Le contour compact garde les cotes176×67 à y5–72, sans déplacement des pages.
La différence visuelle avec44 est explicite : les braises sont composées
devant le noir puis découpées par le contour commun, et les ombres extérieures
sont retirées. Le dessin et les gestes restent à constater avant validation.
Le capteur physique n’accepte pas les touchers de l’app ; le banc vise la
partie visible sous ce capteur. Ne pas prétendre tester toute la surface
physique de l’île ni rétablir une géométrie antérieure comme déjà approuvée.

Les pauses hors écran, Reduce Motion et protection thermique sont conservées.
Aucun nouveau moteur d’animation n’est ajouté. Cela ne prouve pas le coût
CPU/GPU du montage rétabli ni une chauffe durable résolue.

Sources de production : `sources49.json`. Le banc isolé utilise
`IleDansAppUITests` pour présence, tap, détail, drag, pose, jet, récupération,
stop et Home. `IleNativeUITests` conserve le contrôle d’arrière-plan et des
retours ; ses attentes au premier plan sont corrigées pour exiger le repère.

Compilation Release49 réussie, signature vérifiée. App et widget portent49.
Installation réussie, version49 relue sur l’iPhone à16:55:13 et lancement
normal réussi avec `-sansSondeVol -ecranEveille`. Tests en cours : aucun
parcours tactile49 annoncé validé à ce stade.

La première compilation de tests simulateur a été interrompue volontairement
(exit75) pendant une pression mémoire élevée :22Go de swap utilisé. Le
simulateur isolé est arrêté et la compilation iPhone termine seule. Le banc
simulateur est repris ensuite. Ce n’est pas un échec de code de l’app.

## Résultats49 et nouveau verdict

Sur iPhone, le contrôle de séance existante est ignoré (3,599s) : aucune
séance active n'est présente. Aucun entraînement n'est créé pour le test.
Le lab du vrai composant passe1 cas en49,922s : tap de sortie, déplacement,
jet vers l'île, drag de sortie et ouverture du détail. Ce n'est pas une
preuve du parcours de séance dans les vraies pages du téléphone.

Le lab reste à thermique1/protection1 : décor au repos. Fenêtre stable
t15,2–31,5 :17 lignes, CPU médian0 %,60,1 callbacks/s, pire17ms. Les champs
de contexte Home de la sonde sont les valeurs par défaut du lab : cette
fenêtre ne mesure PAS la Home. Ni GPU ni chauffe durable établis.
Retour normal réussi à16:59:01 avec `-sansSondeVol`.

Le contrôle simulateur49 n'a pas démarré : destination saisie `platform=iOS`
pour un simulateur. Exit70 ; aucun test49 simulé revendiqué.

Nouveau verdict utilisateur : stop à droite, chrono à gauche, halo blanc
intérieur sur Home noire.49 ne répond pas à cette disposition et n'est
pas retenue comme rendu validé. Reprise50.
