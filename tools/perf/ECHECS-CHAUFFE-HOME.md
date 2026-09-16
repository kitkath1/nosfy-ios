# Chauffe Home — registre des échecs et des mesures invalides

### E67 — Halo52 : distinguer build installé et candidat Git isolé

**16-09.** Halo renforcé hors Home noire, validé par Kathryn. Release52
compilée/installée et parcours iPhone passé50,175s. Coût du composant :
1 % CPU médian,17 lignes/16,3s, therm0/protection0 ; pas de nouvelle A/B52.
La collecte d’abord refusée est autorisée après vérification du schéma
technique et du scénario synthétique, puis archivée sans données de compte.

Le banc du seul commit se monte, mais compile en échec sur
HomeAuroraView:196 → VolDePieces. Même référence dans HEAD fc06e4b,
aucune définition suivie ; fichier inchangé. Ne pas importer les autres
sessions pour annoncer un build isolé vert. La Release de l’arbre partagé
et le test physique ne suppriment pas cette limite.
[Preuves52 et périmètre](campagnes/2026-09-16-ile-seance/halo52.md).

### E66 — Halo51 : gain CPU mesuré, sans généraliser à la chauffe de la Home

**16-09.** Le design blanc et la sortie50 sont validés par l'utilisatrice.
Le halo SwiftUI coûte encore16 % CPU dans le lab à therm0/protection0.
51 garde les gestes et confie le fondu de deux textures au compositeur.
Comparaison dans51, même appareil, ordre natif puis SwiftUI : **1 % /16 %**
CPU médian,17 lignes par fenêtre t15,2–31,5,60,1 callbacks/s, pire17ms,
therm0/protection0. Les deux parcours du composant passent49,269s/49,818s.
La rotation àt48 du premier test est hors fenêtre de coût et reste signalée.

Les champs de contexte du lab ne décrivent pas la Home de l'app ; analyser
la fenêtre du composant explicitement, pas les valeurs Home par défaut.
Pas de troisième retour mesuré, ni watts/GPU/endurance. Ne pas clôturer la
QA chauffe. La prise latérale50 avait également passé le test physique
(chrono x100,5/y33) : la première inquiétude utilisateur sur le drag est
levée par sa confirmation, aucun nouveau seuil de geste livré.51 installée,
version relue17:38:40 ; retour normal sans sonde réussi17:42:43.
[Protocole et données51](campagnes/2026-09-16-ile-seance/performance51.md).

### E65 — Le bon geste ne valide pas un mauvais placement

**16-09,49–50.**49 rétablit le composant dans Woop après l'absence47/48,
mais garde stop à gauche et chrono à droite sous le capteur. Refus explicite :
les placer de part et d'autre à hauteur de l'île, halo blanc intérieur Home.
50 corrige ce dessin. La première capture constate un chevauchement de la
barre de statut : masquée en séance avant installation. Les éléments internes
d'accessibilité doivent être contenus, sinon l'id du parent masque le chrono.

Le contrôle50 valide au simulateur le stop visé directementy33, la sortie,
le drag, la pose, le jet et le retour, ainsi que Home → détail. Les tests
natifs de retour passent aussi. Le premier lancement de plusieurs lots garde
un processus sans sonde ; rejeté, puis arrêt explicite dans le lanceur XCTest
et Profil positif12,162s. Ne pas modifier l'auth ni annoncer un lot complet
vert sur cette base. Compilation générique Intel inutile et reprise avec DB
encore verrouillée consignées dans la campagne ; ne pas redémarrer avant
l'arrêt effectif de sa propre compilation.

49 sur iPhone : un parcours du composant en lab passe49,922s. Sonde protégée
therm1/protection1,17 lignes stables, CPU médian0 %,60,1 callbacks/s : pas une
Home réelle ni une mesure d'animation active.50 installée/lancée17:22:46 ;
contrôle de séance ignoré car aucune active. Mesures50/51 terminées ; voir E66.
[Preuves et limites50](campagnes/2026-09-16-ile-seance/rendu50.md).

### E64 — Demande d'île native : ne pas valider une imitation ni zéro test

**16-09.** Kathryn tranche : la vraie Dynamic Island iOS. Le décor SwiftUI
des versions43/44 et sa zone tactile ne sont plus montés dans le parcours
normal. La Live Activity WidgetKit porte le rendu. Le système contrôle
sa visibilité et ses gestes : ne pas promettre le souffle infini ou le
drag de l'ancien prototype dans ce composant.

La première compilation de test45 contient bien `IleNativeUITests` (symbole
de classe présent dans le binaire), mais XCTest annonce **0 test exécuté**
avec « TEST SUCCEEDED ». Ce résultat est rejeté. Le simulateur présente
encore une app de version1 lors de la relecture, puis il est retrouvé
Shutdown au premier essai de purge du runner (SimError405). Reprise sur
le même simulateur isolé après boot et retrait du seul runner de test.
La cause du chargement de zéro test n'est pas établie par le succès de
compilation. Vérifier les cas réellement exécutés et la version installée.

46 montre bien l'île dans SpringBoard et son agrandissement, mais le callback
de retour implicite rouvre l'app sans atteindre la destination. La sonde
historique `seance` de PageCard n'est pas valable sur Profil ; le test natif
vérifie l'activité dans SpringBoard et part après le splash (`-porteVue`).
47 ajoute le lien de séance explicite et passe les deux parcours natifs
(37,773s et15,978s). Aucune validation de chauffe physique n'en est déduite.

Après déverrouillage,47 est lancée sur l’iPhone à15:41. Le contrôle physique
capture une Home sans séance active : **1 cas ignoré**, aucun agrandissement
ni retour natif testé. Ne pas transformer ce « TEST EXECUTE SUCCEEDED » en
validation d’île. Les traces montrent thermique0 puis1 ; sans séance et avec
une réouverture sans navProbe, elles ne mesurent pas le coût de l’île.

À16:14, précision décisive : l’absence concerne **Woop ouvert**. L’activité
native ne remplace pas le repère au premier plan, puisqu’iOS la masque alors.
Les tests d’arrière-plan ne suffisent donc pas à déclarer le besoin résolu.
La capture physique16:11 était déjà sur la story de fin ; ce cas ignoré ne
prouve pas non plus une activité manquante pendant une séance. Le nettoyage
de build demandé ensuite ne change pas cette règle de visibilité.

Rebuild propre48 réussi et installé à16:29, numéro relu sur l’iPhone.
L’ouverture automatique est ensuite refuséeLocked : ne pas confondre ce
nettoyage réussi avec un lancement48, un repère au premier plan ou un test
de chauffe validé. Aucune relance en boucle. Après « ok réessaie »,48 est
ouverte à16:31 : Home sans sonde capturée et relue, contrôle3,713s réussi.
Cela valide l’ouverture, pas le besoin d’île au premier plan ni la chauffe.

[État du parcours natif](campagnes/2026-09-16-ile-seance/native.md).

### E63 — L’île intégrée : réserver aussi la prise tactile, et distinguer installation et lancement

**16-09,43.** Premier contour intégré : la capture révèle que le safeAreaInset
ne déplace pas le titre dans le cadrage explicite de PageCard. Le padding de
la page corrige le dessin, puis l’assertion constate encore titre y94 / prise
jusqu’à y104 : la marge tactile invisible doit elle aussi être réservée.
Onze autres cas tactiles passent ; la réserve est corrigée et le douzième
cas ciblé passe en13,284s. Les premiers tests sans assertion de titre ne
validaient donc pas son dégagement. Profil capturé séparément sur simulateur.

Le hook historique du player est réancré après préparation de copie refusée.
L’export xcresult en sandbox est refusé puis réussi avec l’accès Xcode.
La Release43 est compilée et sa version installée relue. Le lancement physique
est refuséLocked : aucune mesure CPU/GPU ni validation de chauffe sur43.
Le runner est interrompu et le déverrouillage demandé, sans relances en boucle.
Le chrono visible a été séparé de l’arrêt thermique du souffle : protéger le
décor ne doit pas figer l’heure de la séance.

[Preuves et limites de la reprise](campagnes/2026-09-16-ile-seance/etat.md).

**Verdict utilisateur sur43 : refus du contour « pyramide » et des pages
abaissées, Profil cité explicitement.** Les tests de géométrie validaient un
placement que l’utilisatrice n’avait pas demandé. La reprise supprime le
contour à épaules et tout EspaceIleSeance ; la capsule se compacte dans le haut
disponible. Ne pas réintroduire une réserve de page pour résoudre ce rendu.
[Correction de la capsule](campagnes/2026-09-16-ile-seance/capsule.md).

**Rendu44 refusé aussi : l’animation doit être DANS l’île.** Le noir opaque
couvre les braises et ne laisse que leur halo à l’extérieur. Cinq tests de
geste et de coordonnées passent, mais ils ne valident pas le dessin. Ne pas
présenter cette version comme corrigée ni l’installer comme solution validée.
La capsule SwiftUI dessinée dans l’app et la Live Activity du système sont
deux composants distincts ; préciser lequel doit porter l’animation avant
d’inventer une autre extension autour du capteur.

### E62 — Ne pas confondre le gain42 et une endurance interrompue

**16-09,42 : natif/ancien/natif à thermique0/protection0 =3 % /20 % /3 % CPU
médians.** Respectivement105,31 et25 lignes retenues ;60,1 callbacks/s, pire17ms.
Le fond seul41 ne suffisait pas ;42 déplace aussi les braises au compositeur et
met en cache les silhouettes floutées. Les moteurs restent animés à froid.
Ce gain du processus ne mesure pas les watts ni le GPU et ne clôt pas la chauffe.

Le lancement42 initial est refuséLocked après installation ; la capture copiée
ensuite était encore celle de41, donc rejetée comme preuve42. Après déverrouillage,
un bandeau d’appel apparaît : les premières secondes sont exclues, la capture
portant le contact n’est pas archivée. L’essai long suivant devient inactif après
56,4s, avec Welcome Back sur la dernière ligne. Les libellés accessibles restent
présents sous la couverture ; ce n’est pas une preuve de visibilité. Le test
palier est interrompu sans toucher à l’appel. Ne pas annoncer dix minutes ni
un palier5min validé avec ces seules données. La collecte suivante montre
399s sans lignes, trois lignes de reprise, puis `scene-background` : toujours
aucune endurance continue. Le runner annulé laisse un xcresult incomplet.
Le contrôle documentaire refuse ensuite un titre trop long, corrigé ; son
lancement Chrome échoue dans le bac à sable après23 tests réussis, avant reprise
avec le droit de lancement.

[Fenêtres, sources et limites](campagnes/2026-09-16-retours-et-profil/etat.md).

### E60 — Retour de Home assimilé à une réplique déjà lue

**16-09, demande utilisateur : nouveau texte à chaque arrivée/retour, jamais de
lecture en arrière-plan.** La clé précédente identifiait le texte et son palier,
mais pas la visite : revenir sur le même état ne rejouait pas les mots. Le réveil
des minutes tournait toutes les 30 secondes dès qu’une séance existait, même
quand la Home était cachée. `HomeLecture` distingue désormais une visite réelle
d’un recalcul ; le sac par état/langue évite la répétition immédiate. L’horloge
se recale sur la prochaine minute et s’annule hors écran. Pas de rattrapage des
paliers manqués ; formulation toutes les cinq minutes visibles.

39 : Home rouge, trois phrases différentes aux retours Exercices/Profil,
XCTest PASS 21,732 s ; captures montrant le flou progressif. Le test noir 40
échoue : la protection serious coupait aussi le choix de la phrase. 41 sépare
visibilité, sélection et animation ; le texte reste lisible et à jour même
quand l’animation est coupée. Retours noirs PASS 27,896 s, trois formulations
au même compteur de trois minutes. Les tests du modèle vérifient zéro tirage
caché, absence de rejeu au recalcul et retour unique après plusieurs paliers.

### E61 — Panneaux superposés et prototype du booster sans gain établi

La référence 38 lancée sur Home finit sur Profil avec le panneau du booster,
hors protocole ; le test qui attendait le bouton Home échoue à juste titre.
La capture montre le panneau, pas une Home bloquée. Son SceneKit tourne à
30 rendus/s et le CPU est élevé ; cela ne prouve pas qu’il est seul responsable.

Le prototype 40 déplace son balancement de SwiftUI vers Core Animation. Sur
le panneau dégagé : CPU médian 41,5 % (24 lignes, thermique1/protection1).
Aucun gain suffisant établi : prototype archivé puis retiré. Le témoin A/B est
invalide car Welcome Back apparaît **après** la première assertion du runner.
Le runner attend désormais la bienvenue asynchrone avant de fermer Later et
lire le contexte. Essai interrompu quand thermique2 apparaît ; aucune moyenne
sous Welcome Back n’est attribuée au panneau seul. Une garde de préparation
de l’archive échoue avant toute écriture (compte de hunks erroné) ; reprise après
relecture du diff, sans toucher au travail des autres sessions.

**La Home noire 40 revenue à thermique0/protection0 consomme encore 21 % CPU
médian sur 119 lignes (t248,7–368,5).** Le faible CPU protégé ne valide donc pas
l’usage animé. La trace SwiftUI expose du travail récurrent de cadres, opacités,
flous et Canvas ; vues créées avant l’attache non nommées, donc pas d’attribution
exclusive à une vue. 41 déplace seulement le fond au compositeur : coût encore
voisin de 19–20 %, amélioration insuffisante. Les essais suivants concernent
les braises et les silhouettes, en conservant leur dessin.

[Campagne, données brutes et limites](campagnes/2026-09-16-retours-et-profil/etat.md).

### E59 — La protection des décors coupait aussi la parole ponctuelle

**16-09, reprise 11:09 : 37 lancée, navigation complète PASS 10,754 s, trois
retours du pull puis Profil PASS 36,242 s.** Dans le code 37, la Home noire
utilisait `!dort` pour ses mots : l’état thermique fair coupait aussi leur
apparition et l’haptique. **38 sépare l’inactivité de la page du repos des
décors**, sans supprimer leur protection ; la parole finie reste coupée à
serious/critical. Installation et lancement 38 réussis à 11:17.

Home rouge 37 : CPU médian 1 % sur 128 lignes, dont 124 protégées ; seulement
4 nominales. Home noire 38 au banc : 150 lignes, CPU médian 2,5 %, toutes
protégées. **Ni ces médianes, ni la capture du chrono ne valident la chauffe
prolongée.** Le champ sonde `seance=0` ne reconnaît pas le banc `-homeSeance` :
corroborer avec le lancement et l’écran. Sonde coupée après collecte.
[Données, gestes et limites](../home-v2/validation-textes-2026-09-16/reprise-1109/etat.md).

### E58 — Texte compilé, mais prise de parole non validée

**16-09 : le rendu 36 est rejeté par l’utilisateur (« je ne vois pas l’animation
des mots »).** Le premier moteur natif ne reproduisait pas le flou demandé.
37 utilise le phrasé de l’onboarding, flou mot par mot et haptique soft, avec
des phrases de 7 à 12 mots. Les quatre films simulateur (rouge/noire, FR/EN)
montrent l’apparition puis le repos. Installation iPhone 37 réussie à 09:44,
mais lancement refusé « Locked » : ni haptique ni coût thermique 37 validés.
Le test Profil 36 échouait sur `isHittable` ; la capture suivante n’était pas une
preuve de navigation. Ne pas confondre compilation, installation, capture et
parcours interactif. Les autres erreurs de ce chantier (génération, droits,
compilation, largeurs et documentation) et leurs corrections sont conservées
dans le [bilan des textes](../home-v2/BILAN-TEXTES-HOMES-2026-09-16.md).

### Reprise du 16-09 à 08:36

**16-09, 08:36 — complément E57 : automatisation rétablie après déverrouillage,
contrôle Home 35 réussi. Deux endurances interrompues par changement de contexte ;
aucune validation longue obtenue.** Observation courte sur Home noire : CPU médian
20 %, thermique 0, protection 0 ; elle ne valide pas la chauffe prolongée.
Sonde arrêtée à 08:36:11. La demande suivante porte sur un plan de textes FR/EN,
sans code. [Reprise, interruptions et preuves](campagnes/2026-09-16-validation35/reprise-0825/etat.md).

### État antérieur du 16-09, 07:30

**16-09,07:30 :35 réellement installé. Les deux tentatives XCTest échouent avant le premier geste (activation du mode automatisation). Les relevés sous Welcome Back puis app inactive ne valident pas la Home35.** À07:36, lancement Profil accepté avec `-sansSondeVol` ; affichage interactif non confirmé. Skill `woop-chauffe` créé et validé ; registre57 entrées. [Preuves et suite précise](campagnes/2026-09-16-validation35/etat.md). La chauffe durable reste ouverte.

### Dernière validation complète de navigation :34 (historique15-09)

**Concession visuelle confirmée par l’utilisateur sur30 : le widget Chapitre a perdu ses animations.** Le fond liquide (`FondLiquide`) et le liseré tournant (`LisereTournant`) ne sont plus montés quand `decorHomeAuRepos` est vrai ; les halos/ondes d’appel sont retirés et la respiration du halo interne du galet est figée. Ce changement est permanent sur la Home actuelle, même à froid ; ce n’est pas seulement la protection thermique. Il contribue potentiellement au gain global28, sans attribution isolée de chacun de ces effets. Le rendu complet demandé reste donc à restaurer avec un coût maîtrisé. Les deux chevrons natifs30 sont un autre composant, pas une remise en animation du Chapitre.

**15-09,23:02 : build34 installé et vérifié. CPU Home1 % médian pendant3min ; onde du Chapitre, chevrons et respiration du point conservés. Navigation PASS9,231s,3 retours du pull PASS35,164s,4 cycles Exercices/Profil PASS66,481s.** Après la balade, CPU1 % en récupération mais thermique1 : ne pas clore la chaleur ressentie. Sur3min immobiles, retour nominal à143,1s.35 compile pour rendre l’intégration commitable sans dépendance étrangère ; installation refusée23:28, liaison indisponible. Dernière installation confirmée34, sonde éteinte23:02:12. QA04 reste ouverte. Registre56 entrées. [État, données et captures](campagnes/2026-09-15-reprise-autonome/etat.md).

### État historique28

**15-09 à 21:12 : build 28 installé, navigation validée, CPU médian 5 % à froid. Chauffe durable à confirmer.**

La Home garde la vidéo et pose ses petits ornements par défaut, y compris après fermeture/réouverture. Le relevé final de 35 s donne 19 échantillons stables après exclusion des 15 premières secondes : CPU médian 5 %, 60,1 callbacks/s, pire intervalle 17 ms, thermique 0 et protection 0, aucun popup, aucun gel marqué. Les callbacks ne sont pas des images GPU ; ce relevé ne mesure ni watts ni autonomie.

Home → Exercices → Home → Profil → Réglages passe sur 28 en 9,373 s. Compteurs éteints et Home normale restaurée à 21:12. La capture Power Profiler 28 reste inexploitable (délai dépassé) ; elle est remplacée par ce relevé de sonde. QA04 reste KO jusqu’au retour d’usage. QA07 valide l’accès ; aucun cycle de compte ni suppression. Registre : 47 entrées.
[Résultat 28, sources, journaux et limites](campagnes/2026-09-14-correctif/instruments-decor-home-build28/etat.md).

### État historique du banc25

**Banc25 complet et contrôlé : Home protégée à 1 % CPU au début et à la fin.**
Absence de Welcome back et de première arrivée enregistrée ; première capture
lue, vraie Home. Thermique 1, environ 60 callbacks/s. Six captures créées,
restauration et arrêt de sonde confirmés. Le coût animé à froid et la baisse
de chaleur ressentie restent à vérifier. QA04 n'est pas passée au vert.
[Résultats, preuve et limites25](campagnes/2026-09-14-correctif/banc-verifie-build25/etat.md).

**Lire E43 avant les anciens chiffres23/24 : fenêtres couvrantes non exclues.**

### État historique du banc 23

**Banc complet obtenu ; chauffe toujours non résolue.**
[État complet, UUID, mesures et limites](campagnes/2026-09-14-correctif/banc-blocs-build23/etat.md).
Protection active et thermique 1 : complète finale 12 % CPU, sans widgets 8 %,
sans Route 11,5 %, fond seul/nu 1 %. Cadence médiane environ 60 callbacks/s,
intervalle maximal 17 ms sur ces fenêtres. Les phases successives localisent
un coût du mobilier, sans mesurer l'énergie ni disculper la vidéo animée :
le fond était protégé. La première phase traverse thermique 0 → 1 et reste
confondue. Restauration complète, arrêt de sonde et écran éveillé vérifiés.

Comparaison de l'invite seule lancée à 15:56:59 puis interrompue à 15:57:11
par le passage en arrière-plan. Cinq lignes, aucune stable : aucun verdict
sur cette piste. Données conservées dans le dossier `sans-invite-interrompu`.
La première tentative partielle de 15:34 et ses limites restent conservées.

<a id="e46"></a>

### E46 — Instruments revient, mais plusieurs comparaisons restent invalides

15-09, retour USB20:15. Premier Power Profiler20:17 trop tard : la protection a déjà repris, donc témoin animé invalide. A/B verre20:22/20:23 en Fair/Serious différents, aucun gain causal attribuable. Brouillon GPU mélangeant quatre séries statistiques et division par zéro : agrégats rejetés. Les colonnes CPU Instructions/s ne sont pas du temps CPU ; scores de puissance ne sont pas des watts. La trace complète avec décors au repos atteint4,89 % CPU avec vidéo conservée avant expiration du diagnostic ; durée courte, chauffe non validée.
[Traces, scripts et limites](campagnes/2026-09-14-correctif/instruments-decor-home-build28/etat.md).

<a id="e47"></a>

### E47 — Répéter les variantes sans livrer une décision vérifiable

Retour utilisateur du15-09 vers20:35 : quatre heures supplémentaires et impression de refaire les mêmes tests depuis deux jours. C’est un échec de conduite de l’investigation, même si les journaux existent. Les réessais des liserés et de la pièce ont prolongé une piste déjà insuffisante. La navigation réparée et les faibles CPU protégés n’ont pas répondu au symptôme ressenti.

Décision : ne plus rejouer le banc complet de variantes. La combinaison complète vidéo + verre + ornements au repos est intégrée localement à la Home dans28, puis vérifiée par une mesure et le parcours QA. Aucun chiffre court ne permet de clore la chauffe ; seul un retour d’usage durable peut compléter les mesures.

Complément E47,20:55 : l’attente de livraison s’allonge aussi sur le Mac. Compilation28 active ;88,83s CPU en8min48s,22,7Go de swap utilisés. Plusieurs simulations tierces actives, aucune arrêtée sans accord. L’automate de6min expire sans nouvelle mesure. La relance de maintien éveillé est refusée Locked à20:54:44 ; attendre le build prêt avant de redemander le déverrouillage. [Détails](campagnes/2026-09-14-correctif/instruments-decor-home-build28/etat.md).

Résultat final E46/E47, 21:12 : build 28 réussi et installé. Le premier contrôle annule la capture avant son lancement (démarrage de XCTest trop long pour la fenêtre de diagnostic). La seconde capture Power Profiler dépasse 40 s et laisse une trace incomplète : aucun résultat de puissance annoncé. Un unique relevé de la sonde existante donne 5 % CPU médian, à thermique 0, protection 0, Home sans popup, puis les compteurs sont désactivés. Navigation 28 PASS ; retour normal confirmé. La chauffe en usage reste à confirmer. Les simulateurs tiers n’ont pas été arrêtés.

Complément E37 : la première mise à jour finale des rapports utilise un répertoire courant incorrect (docs/site) et échoue avant écriture. Reprise avec chemins absolus ; le livrable doit être vérifié après la mise à jour effective, sans considérer le premier lancement d’artefact comme une preuve.

Complément E33 : le build documentaire28 est encore lancé à tort en sandbox, reproduisant le blocage déjà connu. Ses seuls processus (PIDs58874/58896/58897, identifiés par le journal ouvert) sont arrêtés avant reprise hors sandbox.

<a id="e48"></a>

### E48 — Attache par nom et essai du verre sans gain clair

15-09,21:20–21:30 : `xctrace --attach Woop` échoue à trouver l’app malgré un processus présent. PID obtenu par devicectl, puis attache **par PID**, réussit. La limite externe40s interrompait trop tôt les15s de capture + préparation/sauvegarde ;90s convient sans imposer90s de capture.

Sur28, traces nominales21:24 et21:28 : CPU après4s4,962 % avec verre contre4,897 % sans. Pas de gain clair des scores disponibles. Les colonnes anonymes ne sont pas renommées CPU/GPU ni traduites en watts ; aucune ligne de métrique Metal par processus. Le premier essai sans verre de21:19, thermique1, était confondu avec la protection. Verre restauré. Batterie93 % en charge à21:30 : contexte à contrôler, pas cause initiale prouvée.
[Traces et analyses](campagnes/2026-09-14-correctif/instruments-decor-home-build28/).

<a id="e49"></a>

### E49 — Invitation encore coûteuse et nouveau relevé protégé

29, à froid : invitation complète3 % CPU médian ; retirée1 %, même binaire,60,1 callbacks/s,17ms maximum,20 échantillons avec15<t≤35. Le résumé oral4 % utilisait16≤t≤35 (19 lignes). Cette piste justifie une modification précise : les chevrons30 utilisent Core Animation, courbes et dessin conservés, texte et gestes inchangés.

Navigation30 PASS9,267s. Huit captures montrent les chevrons et flammes animés. **Premier relevé30 non concluant pour le gain : thermique1/protection1 dès le départ**, malgré1 % CPU. Ne pas recycler ce chiffre en succès animé. Restauration normale21:54:42, compteurs éteints, commence nominal puis repasse à1. Le diagnostic de capture a été refermé après10s. Retour utilisateur suivant sur30 : ça chauffe beaucoup moins. Amélioration ressentie confirmée ; chauffe prolongée non clôturée et branchement non précisé. Garder30 comme base, ne pas relancer le banc complet. Le29 a aussi fermé les lecteurs Home/Exos au démontage (rate0/items0 prouvés), sans en faire la cause principale.
[Sources, arguments, mesures et captures30](campagnes/2026-09-14-correctif/chevrons-natifs-build30/etat.md).

Complément E37, finalisation30 : premier script documentaire refusé avant écriture (formatage `%` sur du texte contenant des pourcentages) ; seconde tentative écrit les rapports mais échoue sur un identifiant QA tronqué. L’artefact parti avant la correction QA est périmé. Identifiant corrigé en `qa-04-home-vide`, source relue puis artefact entièrement régénéré et vérifié. Aucun résultat du premier artefact considéré comme final.

<a id="e50"></a>

### E50 — Chauffe réduite avec une concession visuelle insuffisamment expliquée

**Concession visuelle confirmée par l’utilisateur sur30 : le widget Chapitre a perdu ses animations.** Le fond liquide (`FondLiquide`) et le liseré tournant (`LisereTournant`) ne sont plus montés quand `decorHomeAuRepos` est vrai ; les halos/ondes d’appel sont retirés et la respiration du halo interne du galet est figée. Ce changement est permanent sur la Home actuelle, même à froid ; ce n’est pas seulement la protection thermique. Il contribue potentiellement au gain global28, sans attribution isolée de chacun de ces effets. Le rendu complet demandé reste donc à restaurer avec un coût maîtrisé. Les deux chevrons natifs30 sont un autre composant, pas une remise en animation du Chapitre.

Ne pas présenter30 comme un dessin intégralement préservé ni le gain global comme celui des seuls chevrons. Le retour utilisateur de chaleur est positif, le retour sur le Chapitre révèle un objectif visuel encore incomplet. Aucun effet rallumé à l’aveugle pendant cette clarification.

<a id="e51"></a>

### E51 — Vérifier les commits indépendamment du working tree partagé

Le15-09, à la demande de commits séparés, la série est extraite dans un checkout isolé. La compilation révèle une dépendance de notre `BancCoutHome` à `CompteEtat`, encore non commité par l’autre chantier. Corrigée : la racine publie directement au banc si splash/porte/onboarding tiennent l’écran ; état fermé par défaut, aucun modèle de compte requis. Le second build ne rapporte plus cette erreur.

Le checkout reste en échec sur des dépendances hors de cette sélection : `IleGeo.capsuleBas`, `VolDePieces`, switch de `RecentWorkoutCard`, argument `onStopViaPause`, puis erreur de type-check de la racine. Ne pas affirmer que le checkout est compilable au motif que le working tree complet a produit le build30. Les modifications des autres sessions sont conservées localement, pas absorbées pour masquer ces erreurs.

La documentation isolée se génère et passe les types, mais son test des preuves révèle6 références invalides déjà portées par le contenu hors de nos deux notes QA : PLAN-ILE-TOUCHABLE absent, Compte.swift absent (4 références), bornes de SupabaseSync. Le livrable commité est généré depuis les sources commitées + nos notes QA ; celui du working tree conserve aussi les publications des autres sessions. Aucun résultat « tout vert » annoncé pour le checkout isolé. Les journaux sont conservés dans `campagnes/2026-09-14-correctif/commits-base30/`.

Incidents de préparation : contrôle des espaces lancé à tort sur les journaux bruts (sortie énorme, aucun journal normalisé) ; commentaire de Réglages inclus par la découpe Avatar, retiré immédiatement du seul commit local nouveau avant de poursuivre. Aucun fichier de travail d’autrui réécrit.


<a id="e52"></a>

### E52 — Le faible CPU protégé30 ne se reproduit pas à froid

Reprise autonome22:18–22:27 : Power30 à froid, sans compteur, donne9,092 % de CPU échantillonné après4s. Le1 % de21:52 était protégé et ne devait pas être annoncé comme gain animé (E49). La nouvelle balade commence déjà à8–10 % avant les appuis ; les7 % après ne prouvent donc pas une fuite due aux allers-retours. Le booster caché est arrêté, compteur fixe577.

La comparaison des seuls chevrons donne10 % avec l’ancien SwiftUI et9 % invitation retirée, mais presque toutes les secondes stables sont thermique1 : **pas une comparaison froide certifiée**. Le coût persiste sans invitation ; aucun procès de Core Animation ni gain natif annoncé. Ne pas refaire toute la bissection. Les données et limites sont dans [la reprise autonome](campagnes/2026-09-15-reprise-autonome/etat.md).


<a id="e53"></a>

### E53 — Une nouvelle sonde provoque elle-même un plantage

31,22:36:21 : le relevé des animations natives provoque SIGABRT dans `NSJSONSerialization`, appelé par `NavDiagnostic.noter`. La mesure45s s’arrête à21,3s ;7 lignes seulement sont au-delà de15s. Valeur JSON exacte fautive non identifiée, origine instrumentation confirmée par le rapport iOS.32 enlève la sonde, compile mais n’est pas installé ;33 la reconstruit avec valeurs textuelles strictes, visite bornée et `isValidJSONObject`. Ne jamais assimiler un `try?` Swift à une capture des exceptions Objective-C. Le rapport de crash est [conservé](campagnes/2026-09-15-reprise-autonome/Woop-2026-09-15-223621.ips).

Collecte du rapport : première commande refusée car le répertoire cible n’existe pas, créé avant reprise ; option `--keep` utilisée, aucun journal effacé sur l’iPhone.

<a id="e54"></a>

### E54 — Les économies de rendu introduisent des ruptures de pose

Le fond précalculé30 change de lecteurs à e>0 puis à e=0. La protection thermique remonte le poster àfair, même au milieu du geste. Une prise en vol capture e puis l’écrase par T×g ; fermer sans gel pendant un départ imposaitT. Ces chemins expliquent des ruptures possibles, sans attribuer toute la chauffe à ce glitch.

31 garde les deux calques pendant le pull et fixe la phase de prise ;3 retours et Profil passent35,475s, vidéos démontées seulement à la sortie Home.33 remplace le poster thermique par une pause sur l’image courante. L’onde du chapitre est visible sur12 captures ; son A/B donne10 % nominal contre12 % sans onde mais thermique0→1 : comparaison confondue, pas un gain causal. [Résultats et captures](campagnes/2026-09-15-reprise-autonome/etat.md).


<a id="e55"></a>

### E55 — Une respiration du widget hebdomadaire restait coûteuse

L’analyse s’était concentrée sur le Chapitre, la vidéo et l’invitation. La petite perle du dernier jour fait dans « séances cette semaine » gardait son `repeatForever` SwiftUI : opacité d’un dégradé et échelle.33, même binaire : après15s et en thermique1/protection1, normale12 % CPU médian(n12), souffle de cette seule perle posé1 %(n20),60,1 callbacks/s,17ms maximum. Les dernières secondes étaient13→1 ; ne pas appeler13 une médiane. Les fenêtres complètes sont thermiquement différentes, limite conservée.

34 calcule les deux robes minuscules une fois et confie leur fondu/échelle à Core Animation. Il conserve l’onde du Chapitre. Validation animée et prolongée encore attendue ; ce résultat ne clôt pas à lui seul la chauffe. [Données33](campagnes/2026-09-15-reprise-autonome/etat.md).


<a id="e56"></a>

### E56 — Une correction doit pouvoir être commitée sans absorber une refonte étrangère

Le premier patch de commit34 cherche `PerleSemaine` dans HEAD : la classe n’y existe pas, elle appartient à la refonte SwiftUI non commitée du fichier partagé. L’assertion arrête la préparation ; la tentative suivante de stage est refusée car le patch n’a pas été produit. Aucun changement étranger n’est indexé.

35 place notre rangée dans `PerlesSemaineNatives`, indépendante de cette classe, et ajoute une branche d’entrée qui existe aussi dans la base commitée. Les modifications de34 à l’intérieur de la classe étrangère sont retirées ; son travail reste intact, utilisé uniquement par le témoin. Le petit moteur natif validé34 est conservé. La sélection de commit est générée depuis HEAD et ne comprend que ce branchement et notre fichier neuf. Le nouvel agencement reçoit sa propre vérification sur téléphone.


Complément E56 :35 compile. L’installation23:28 échoue sur CoreDeviceError4000/connexion invalidée, puis l’iPhone est unavailable. Ne pas transférer les validations34 à35. Les fichiers du refus sont conservés avec la campagne. Le travail indépendant de la liaison (commits et documentation) continue.

Complément E37 : le vérificateur documentaire35 ne produit pas de fichier qa-390.png ; une ouverture de ce nom échoue. Les captures réellement produites Etat390/1440 sont ensuite ouvertes et relues. Aucun verdict visuel fondé sur le fichier inexistant.


<a id="e57"></a>

### E57 — Installation réussie, automatisation refusée avant le test

16-09 : la liaison CoreDevice réseau installe35 et relit son numéro. Deux runners XCTest échouent avec `Timed out while enabling automation mode`, sans exécuter d'assertion ni fermer Later. USB absent des relevés avec accès aux services du Mac ; verrouillage contrôlé. Le réseau n'est pas pour autant prouvé cause de l'échec. Aucun nouveau parcours35 annoncé comme réussi.

La collecte avant restauration donne269 lignes après15s, toutes `welcome=1` (CPU médian17 %, thermique0). La Home dégagée n'est pas mesurée. Autre invalidation : nav passe en inactive1 au lancement du runner,262 états sur284, alors que les callbacks de sonde continuent. Les compteurs qui bougent ne prouvent pas l'activité réelle de l'app. Lancement Profil sans sonde accepté07:36:24, puis app inactive ; aucune capture finale exploitable. La demande de rétablir la liaison est faite pendant le travail indépendant sur le skill. Pas de boucle de réessais ni de transfert des preuves34 à35. [Journaux](campagnes/2026-09-16-validation35/etat.md).

Le validateur officiel du skill manque d'abord de PyYAML ; le venv temporaire dédié résout ce manque, validation PASS. L'analyseur reproduit34 et refuse les données35 sous bienvenue ; sept contrôles PASS. Aucun logiciel global remplacé.

Complément E37 : le premier script documentaire16-09 est refusé avant toute écriture par une erreur de décodage UTF-8. La génération du site est néanmoins partie avec les anciennes notes : ce premier artefact n'est pas final. Le script est transféré dans un fichier UTF-8 explicite, exécuté puis relu avant une nouvelle génération. Ne pas poursuivre les opérations dépendantes après l'échec de leur préparation.
