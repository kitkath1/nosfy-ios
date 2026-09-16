# Chauffe Home — registre des échecs et des mesures invalides

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
