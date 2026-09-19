# Reprise stories, session Supabase et pilule — 17 septembre 2026

## Autorisation et périmètre

Audit initial en lecture seule, puis « go ». Kathryn précise ensuite : pilule
qui s’étire dans Woop ; vraie Live Activity plus tard. Aucun commit demandé.
Les changements des autres sessions dans les fichiers partagés sont conservés.

## Corrections

- Stories : le capteur BacMotion est détenu par ses lecteurs, libéré par la
  story à sa sortie, pause ou interruption. La fermeture d’un lecteur ne coupe
  pas un autre lecteur encore présent. Les portails suspendent les pages
  recouvertes via RythmeEcran, sans changer l’onglet sélectionné.
- L’horloge principale se suspend pendant l’appui long et l’inactivité. Le
  temps d’interruption ne consomme pas les pages. Les particules suivent la
  pause et Reduce Motion ; les décors se posent à thermique serious. La poudre
  du doigt cesse ses réveils après la dernière particule.
- Annonces : masque noir de capsule vers dalle, bornes de layout fixes,
  contenu révélé ensuite, réserve caméra et CarillonIle à l’entrée.
  `-sansMorphAnnonces` isole ce morph, Reduce Motion utilise un fondu.
- SupabaseSession : expiration avec marge60s, un refresh pour les appels
  concurrents, réponse ancienne invalidée par déconnexion/changement de compte.
  Le401 de l’outbox invalide seulement le jeton qui a reçu le refus.
- Forge : la même rareté est conservée sur les chemins pool, neuf et pool vide.

## Preuves acquises

- `tools/serveur/verif_session.py` :15 assertions PASS, vrai actor compilé avec
  réseau/Keychain en mémoire. Dont30 appels concurrents pour un refresh, panne
  réseau, refus, changement de compte et déconnexion pendant le refresh.
- `tools/serveur/verif_session.py --live` : session QA dédiée ouverte,12 appels
  concurrents obtiennent le même jeton renouvelé, identité conservée,
  `etat_coffre`200. Logout local de cette seule session, aucun gain écrit.
- `node tools/serveur/tests/forge_raretes.mjs` :30 000 tirages déterministes,
  proportions60/27/10/3 pour pool/neuf/pool vide ; garantie légendaire conservée.
  Code de décision extrait du vrai fichier, aucun appel de génération.
- Forge v6 : déployée ACTIVE, JWT vérifié conservé. Archive ESZIP distante
  relue (source et code transpilé : deux occurrences attendues), nouveau choix
  présent, ancien choix uniforme absent. Appel sans session401. Aucun tirage
  payant ni gain de compte de production créé.
- Release62 puis63 : compilation iPhone réussie.63 installée après branchement.
- Simulateur63 : deux retours + interruption PASS21,605s à la reprise avec
  navProbe. Premier essai : blocage au deuxième passage, cause non attribuée.
- Toaster63 : absent du film simulé ;64 sort la lecture de la file observable
  du GeometryReader. Validation en cours, aucun feu vert du rendu à ce stade.

## Validation physique encore ouverte

Premier contrôle CoreDevice : appareil appairé mais tunnel indisponible,
`ddiServicesAvailable=false`, détails incomplets puis erreurs1011 pour version
installée/verrouillage. Aucun lancement, aucune installation sur ce passage.
Branchement et déverrouillage demandés pendant les vérifications indépendantes.

Le banc `-storyProbe` ouvre une story depuis la vraie Home, sans créer/terminer
de séance ni toucher l’économie. Il sert au retour répété et à l’interruption.
La sonde ajoute les champs `story` et `mouvement` ; ils ne mesurent ni watts
ni GPU. Les comparaisons de Home doivent exclure `story=1`.

Prochaine preuve physique : Home dégagée, story jusqu’à sa carte avec capteur,
fermeture, récupération sur la même Home ; répéter puis endurance à froid.
Conserver le contexte câble, la catégorie thermique et les données brutes.
La baisse du CPU et la chauffe durable sont deux verdicts distincts.

La clé Apple .p8, le parcours réel Apple et la reproductibilité du travail
Compte non commité restent ouverts. Aucun de ces points n’est validé par
les tests de renouvellement.

## Première campagne iPhone63, câble branché en charge

120s d’accueil au départ en thermique fair (1), protection active, CPU autour
5–6 %, cadence60 callbacks/s. Trois ouvertures sur l’introduction/résumé,
sans page analyse : le capteur n’est donc pas exercé dans CETTE campagne.
Le premier retour retrouve la Home ; le deuxième ouvre la route sans ordre
explicite du test (trace route.start-propose àt155,6, film relu). CPU autour
38 % sur cette route. Thermique2 àt178,9 ; arrêt du scénario à190,925s.
Dernière ligne t189 : CPU87 %,32,9 callbacks/s,pire157ms, route1,story0,
capteur0. Cette fin n’est PAS une mesure de Home dégagée. La chauffe est
reproduite mais n’est pas attribuable aux seules stories par cet essai.

Le scénario court suivant passe sur l’iPhone (21,498s) : deux retours et
interruption en arrière-plan. Cela ne vaut pas preuve thermique. La sonde
est désactivée par ce lancement, app terminée à la fin.

65 garde la couverture jusqu’au démontage et rend le TabView insensible
aux gestes pendant la story. Le contrôle vérifie maintenant route0 après
chaque fermeture ; le scénario thermique traverse les quatre pages, dont
l’analyse qui détient réellement le capteur.

## QA complémentaire

- Simulateur68 : test de la pilule PASS. La trace67 confirmait file reçue et
  corps invalidé, mais aucun montage de la branche dans GeometryReader.
 68 revient au socle VStack permanent ; le masque et CarillonIle sont gardés.
- iPhone65, première passe des quatre pages : arrêt propre après136,009s,
  assertion page2. Le tap y18 % était dans SlateListe après son apparition,
  il dépliait les détails au lieu de naviguer. Le banc vise désormais y8,5 %
  (titre hors liste). Ce refus de navigation n’est pas un échec thermique.
  Baseline utile t15–115 :99 lignes, CPU médian6 %, thermique1.
- Documentation : artefact1 856 521o ; vérification complète PASS57s à ce stade.

## Gel confirmé sur iPhone65

Le premier parcours complet passe : démarrage capteur àt134,0, arrêt136,8,
fermeture140,7. CPU redescend à6–8 %, route0, capteur0,60 callbacks/s.
Àt151,9, deuxième ouverture : les journaux cessent après story-ouverte et
le démontage des deux vidéos Home. XCTest ne reçoit plus de snapshot.
Arrêt forcé ciblé du processus41756 à16:10:21. Aucun verdict de récupération
sur trois passages. Le téléphone reste au repos pendant l’investigation.

Le prélèvement du premier gel simulé montre StoryEnded et la mise à jour du
graphe SwiftUI.69 mesure les tailles locales des glyphes puis déduit leur
position dans le HStack fixe ; les rectangles sous le zoom animé ne réinjectent
plus leur position dans le calcul du zoom. Comparaison répétée en cours.

## Comparaison du gel au simulateur

Même simulateur isolé, même scénario de six introductions et retours.
68 (géométrie ancienne) bloque au deuxième passage : processus22051 à100 %
CPU, prélèvement conservé dans /tmp/woop-story-session-ile/sim68-intro-freeze.sample.
69 (tailles locales, seule différence applicative depuis68) passe les six
réouvertures en67,074s. Ce test est fonctionnel ; les builds simulés68/69
sont compilés sans optimisation pour accélérer cette isolation, aucun verdict
thermique n’en est tiré. La Release iPhone69 conserve les réglages du projet.

## Installation69 et reprise physique

Release69 compilée avec les réglages Release du projet, installée sur l’iPhone.
Le runner final est prêt. À16:24:30, pré-vol Xcode refusé : appareil verrouillé,
avant tout scénario. Déverrouillage demandé ; ce blocage n’est pas un échec
fonctionnel de69. La validation physique finale reste en attente à cet instant.

À16:29, verrouillage confirmé (passcodeRequired=true), aucune réponse au
besoin matériel de déverrouillage à ce stade. Pré-vol Xcode en attente annulé
(SIGINT du seul runner25116) : aucun scénario69 ne partira ultérieurement
sans surveillance. Le lancement normal -sansSondeVol est aussi refusé par iOS
Locked ; le réglage persistant de sonde reste donc à effacer après déverrouillage.
Le simulateur de cette campagne a été arrêté ; aucune autre destination touchée.

Documentation finale : artefact régénéré, vérification complète PASS17s.
Aucun commit ni stage. Les dépendances Compte non commitées restent celles du
working tree partagé ; ce build ne prouve pas un checkout isolé prêt à livrer.

### Reprise après déverrouillage

1. Release69 est déjà installée ; ne pas recompiler sans changement.
2. Runner prêt : /tmp/woop-story-session-ile/runner-device-dd/Build/Products/
   NavRuntimeUITests_iphoneos26.5-arm64.xctestrun.
3. Rejouer testChauffeRetourStory seul : deux minutes avant, trois parcours
   complets, trois minutes après. Surveiller depuis le Mac avec surveille.py
   dans le dossier temporaire (nom exact du NOUVEAU fichier vol à fournir).
4. Si ce parcours passe, testRetourStoryEtInterruption + testToasterDepuisIle.
   Relire captures ; haptique ressentie uniquement par Kathryn.
5. Copier les journaux et relancer sans banc avec -sansSondeVol. Actualiser
   cette preuve et mesures.ts ; artefact puis verif.


## Reprise physique du17-09, 16:45–16:52 — version69

Contrôle automatique autorisé à nouveau. L’iPhone15 est confirmé en version69,
connexion filaire (`wired`), batterie en charge visible sur la capture. Premier
lancement bloqué par le verrou iOS ; après déverrouillage le scénario démarre.
`testChauffeRetourStory` **PASS393,377s** :120s Home, trois parcours complets
(introduction → détails → analyse avec capteur → récompense), fermeture par tirage,
puis180s Home. Les trois retours affirment mouvement0/couverture0/route0.
Le gel de deuxième ouverture n’est pas reproduit avec69 sur ce parcours physique.

Sonde complète383 lignes, sans trou >2,5s. Au repos initial t15,2–71,0,
thermique0/protection0 :56 lignes, CPU médian5 %, callbacks médian60,1/s.
Le thermique monte à1 àt72,1, AVANT la première story, et y reste jusqu’à la fin.
Récupération t210,1–388,8 :177 lignes sur178,7s, CPU médian6 %, maximum24 %,
callbacks médian60,1/s, intervalle maximum86ms. Story, mouvement et route à0.
Aucun état serious/critical. Cette mesure valide le retour et l’absence de gel
sur ce scénario ; **elle ne clôt pas la chauffe durable**, ni les watts/GPU.

Le surveillant externe a vu l’app terminée par XCTest et s’est arrêté. La tentative
de le terminer ensuite rend « no such process » : aucun surveillant laissé pour
tuer le lancement suivant. Le téléphone se reverrouille avant le lot suivant ;
la session réelle, l’interruption et la pilule physique restent en attente à ce stade.

### Contrat front/backend relu et appelé

`verif_session.py --live` compile maintenant aussi le vrai `SacreServeur.swift` et
le vrai `ReglesAnnonces` extrait de RestartSheet. Sur une session QA dédiée :
12 demandes concurrentes rendent le même nouveau jeton ; coffre décodé avec les
vrais soldes, sachets, tarifs et date ; annonces décodées avec rangs, budgets,
vidéos et écarts ; historique60 lignes et collection7 familles ; coffre401 avec
un faux jeton. Fermeture de cette seule session QA, aucun gain écrit.
Ce contrôle n’est pas une clôture de séance réelle dans l’interface du téléphone.
La chaîne existante clôture → EconomieWoop.dernierFaits → sessionAvecFaits est
relue ; la note serveur qui disait encore l’appelant absent est corrigée.

Configuration Supabase relue : Apple activé, durée JWT3600s, les trois secrets
APPLE_KEY_ID / APPLE_TEAM_ID / APPLE_PRIVATE_KEY toujours absents. La révocation
Apple et une nouvelle création Apple complète restent à valider avant de dire
le parcours des nouveaux comptes prêt.


### Lot final physique — 16:54–16:55, trois tests PASS62,220s

Après déverrouillage, même version69 :
- Session conservée, sans `-skipAuth` ni banc de données : Home → Exercices → Home
  → Profil → retour, PASS20,692s. Captures Home et Profil relues.
- Story analyse, arrière-plan puis retour à la même page, deux fermetures avec
  mouvement0/couverture0/route0 : PASS19,309s.
- Pilule : annonce pièces120 au sommet, puis booster1, puis disparition :
  PASS22,219s. Les deux captures physiques sont relues et archivées. Le passage
  animé a été testé automatiquement ; ces captures montrent la position finale,
  le film simulé antérieur montre le morph. Le ressenti haptique reste humain.

Relance normale à16:55:52 avec la session conservée, sans sonde, console et
maintien éveillé temporaire pour la trace. Réponses physiques : `home()` donne
35 séances, objectif3, langueen, profil existant ; `seances_depuis` est à jour ;
`regles_annonces()` donne rangs3/5/10, budget4/1/1 et sept vidéos ; les seuils
cardio viennent du serveur. Le premier `etat_coffre` est annulé (-999) au
lancement, puis les messages Welcome Back passent du garde « serveur absent »
à « retour_disponible faux », ce qui confirme `eco.serveur=true` après relecture
(Compte.proposerWelcomeBack). Ce n’est donc pas une panne persistante du coffre.
Une alerte AttributeGraph isolée au lancement est conservée dans la console ;
elle n’est pas attribuée aux stories ni utilisée comme preuve de gel.

Les tests d’interface n’ont créé ni séance ni gain. La pilule de test utilise
les deux événements de démonstration, dans l’hôte réel de toutes les annonces.


### Trace sans HUD — Power Profiler

Attache au PID42180 de la relance normale69, durée enregistrée22,994s.
La trace et les exports sont archivés. L’état thermique est Fair sur toute
cette courte fenêtre, sonde d’écran désactivée. Les colonnes NOMMÉES du
modèle Power Profiler donnent : CPU impact médian1 (26 lignes, max2),
Display impact2 (26 lignes), GPU impact médian0,1 (26 lignes, max1), réseau0
(5 lignes). Ce sont les indices du modèle, **pas des watts ni une température** ;
aucune conversion ni verdict « énergie faible » n’en est tiré. La table Metal
par processus est vide : aucun détail de rendu par moteur ne peut en sortir.
Cette trace conserve la preuve que le thermique fair persiste sans HUD ;
elle ne permet pas d’attribuer la chauffe à une vue ou de la déclarer résolue.

Lancement `npm run artefact` tenté par erreur depuis la racine : absence de
package.json, puis commande reprise dans docs/site. Aucun succès annoncé
sur cette tentative ; seul le contrôle complet dans docs/site compte.


### Restitution du téléphone

17:01:27 : lancement normal confirmé par CoreDevice, uniquement `-sansSondeVol`.
Les arguments de démonstration, de console, de navigation et de maintien éveillé
ne sont plus présents. Les deux lots XCTest, le surveillant et Power Profiler
sont terminés. Aucune session ni donnée du compte du téléphone n’a été effacée.
Aucun commit. Les points non clos restent : chauffe durable, ressenti haptique,
création Apple neuve complète et clés de révocation Apple.

Documentation finale : artefact régénéré, vérificateur complet PASS191s ;
site local3111 et livrable concordants. Changements laissés sans commit.

## Périmètre final et mise en attente décidée par Kathryn

17-09, après les validations : Forge, Compte / Sign in with Apple et vraie
Live Activity sont reportés. La priorité est le périmètre initial et son plan
dans la documentation locale, avec les cartes en verre « Tout est bon » lorsque
les preuves permettent ce verdict.

Réponses explicites : contrôle de chauffe sans câble « Garde ce contrôle en
attente » ; ressenti haptique du toaster « Pas encore vérifié ». Aucun nouveau
stress physique après ces réponses. Contrôle en lecture seule à17:14 : version69
toujours installée, liaison filaire, écran verrouillé. Dernière restitution
normale confirmée à17:08:03, uniquement `-sansSondeVol` ; aucun banc en attente.

La documentation distingue désormais deux résultats acquis (retours stories
avec arrêt des moteurs ; toaster au sommet avec file et disparition) des deux
contrôles ouverts (chauffe durable ; ressenti haptique). Les mêmes enregistrements
alimentent les pages et les cartes. Le plan est dans Test QA, lié depuis État,
et en tête de la passation ; les notes historiques restent datées comme telles.


### Vérification documentaire du plan

Artefact régénéré, contrôle complet PASS43s : types, contenu, invariants,
identité du livrable reconstruit, captures et largeur des dix pages. Lecture
dans Chrome sur localhost : Coffre11/11 « Tout est bon », Annonces4/5 avec
ressenti haptique ouvert, Stories6/7 avec chauffe en attente. Le lien État →
plan, puis plan → Stories et plan → Annonces passent. Vue mobile390px sans
débordement ; captures bureau et mobile relues et archivées dans preuves/.

Le premier contrôle de navigation a trouvé l’attribut de lien incorrect :
remplacé par data-saut, utilisé par le routeur du site. Un essai intermédiaire
a lancé la génération malgré un chemin Python relatif incorrect ; la correction
arrivée après la génération a été refusée par le contrôle de fraîcheur, puis
le livrable a été reconstruit. Une assertion du navigateur lisait les capitales
CSS avec innerText ; elle lit maintenant textContent, puis vérifie aussi les
changements réels de page. Seule la dernière passe complète est retenue.
Aucun changement applicatif, aucune migration, aucun nouveau test physique ni
commit dans cette clôture documentaire.
