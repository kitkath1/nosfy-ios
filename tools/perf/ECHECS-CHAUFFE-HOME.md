# Chauffe Home — registre des échecs et des mesures invalides

**Concession visuelle confirmée par l’utilisateur sur30 : le widget Chapitre a perdu ses animations.** Le fond liquide (`FondLiquide`) et le liseré tournant (`LisereTournant`) ne sont plus montés quand `decorHomeAuRepos` est vrai ; les halos/ondes d’appel sont retirés et la respiration du halo interne du galet est figée. Ce changement est permanent sur la Home actuelle, même à froid ; ce n’est pas seulement la protection thermique. Il contribue potentiellement au gain global28, sans attribution isolée de chacun de ces effets. Le rendu complet demandé reste donc à restaurer avec un coût maîtrisé. Les deux chevrons natifs30 sont un autre composant, pas une remise en animation du Chapitre.

**15-09 à21:55 : build30 installé, navigation PASS9,267s, chevrons natifs visiblement animés. Chauffe toujours ouverte.** Retour utilisateur sur30 : « je trouve que ça chauffe beaucoup moins ». Amélioration nette ressentie, durée prolongée encore à confirmer. La mesure30 à1 % CPU est en thermique1/protection1 : elle ne prouve pas le gain du rendu animé. La Home normale restaurée à21:54:42 repasse de0 à1 ; le branchement pendant le retour utilisateur n’est pas précisé. [État30, captures, sources et mesures](campagnes/2026-09-14-correctif/chevrons-natifs-build30/etat.md).

Le verre n’est pas retiré : les traces28 nominales donnent4,962 % CPU avec verre contre4,897 % sans, sans gain clair des scores de puissance disponibles. L’invitation29 isole3 % CPU normale contre1 % retirée (20 relevés,15<t≤35s ; l’ancien résumé4 % retenait19 relevés,t≥16). Le30 garde le texte et le mouvement avec Core Animation ; sa mesure froide reste à faire. Le29 ferme les lecteurs Home/Exos au démontage, journaux rate0/items0 vérifiés. QA04 reste KO ; aucun cycle complet de compte ni suppression. Registre50 entrées.


Mis à jour le **15 septembre 2026**. Point d'entrée demandé par Kathryn pour
retrouver les essais et éviter de les recommencer sans élément nouveau.

**Retour30 : le téléphone chauffe beaucoup moins selon Kathryn.** La tenue prolongée reste à confirmer. La navigation
est maintenant confirmée par Kathryn (build 18), puis par XCTest (builds22,24,28,29 et30).
Cela ne valide ni la chauffe, ni le cycle complet création → onboarding →
quitter/réouvrir → suppression du compte. Aucun compte supprimé pendant ces essais.

Les identifiants E01… restent stables. Les chiffres CPU sont des pourcentages
d'un cœur ; les « callbacks/s » viennent de CADisplayLink, **pas des images GPU
présentées**. Une compilation, une navigation réussie ou un CPU bas pendant un
gel ne sont pas des preuves de résolution thermique.

## Retrouver un échec

| Symptôme / piste | Entrées |
|---|---|
| « CPU bas, donc optimisé », GPU accusé sans preuve, mauvais écran mesuré | [E01–E04](#e01) |
| Premier correctif, fond figé, effets coupés, protection thermique | [E05–E07](#e05) |
| Profil toujours inaccessible malgré les premiers correctifs | [E08–E09](#e08) |
| Tests UI trompeurs, scène 3D cachée encore active | [E10–E12](#e10) |
| Liseré natif, suppression du flou, images, pièce figée | [E13–E16](#e13) |
| Vidéos, fumée, Metal, rendu natif racine | [E17–E21](#e17) |
| Sonde accusée à partir d'un écran potentiellement verrouillé | [E22](#e22) |
| Vidéo unique : mauvais cadrage, comparaison sans gain établi | [E23–E25](#e23) |
| Téléphone branché mais « unavailable », traces vides, restauration échouée | [E26–E30](#e26) |
| Collecte, signature, build documentation, publication | [E31–E34](#e31) |
| Compilation 23, maintien de veille, installation | [E35](#e35), [E36](#e36), [E37](#e37), [E38](#e38), [E39](#e39) |
| Instruments réel : trace tardive, verre confondu, colonnes GPU | [E46](#e46) |
| Répétition des essais et absence de décision concrète | [E47](#e47) |
| Attache Instruments par nom, verre sans gain clair | [E48](#e48) |
| Invitation coûteuse, mesure30 protégée non concluante | [E49](#e49) |
| Chapitre figé : concession visuelle insuffisamment signalée | [E50](#e50) |
| Nouveaux tests à froid : fumée, pièce, bordures | [E45](#e45) |
| Banc abandonné pendant le chargement, ancien journal récupéré | [E44](#e44) |
| Mauvais écran possible dans les bancs23/24 | [E43](#e43) |
| Trois décors coupés, résultat divergent à chaud | [E42](#e42) |
| Essai autonome par gros blocs | [Interruption E40](#e40), [collecte E41](#e41), [état du banc](#banc-23) |

Preuves détaillées : [rapport chronologique](CORRECTIF-CHAUFFE-2026-09-14.md),
[audit navigation et instrument](AUDIT-NAV-COMPTE-2026-09-14.md),
[mesures initiales du commit c313012](BUG-CHAUFFE-GEL-HOME.md),
[campagne et journaux](campagnes/2026-09-14-correctif/).
Les passages historiques de ces rapports peuvent conserver un verdict ancien ;
le présent état et les actualisations datées doivent être lus avant eux.

## Erreurs de méthode et d'interprétation

<a id="e01"></a>

### E01 — Prendre une charge excessive pour une norme

Le skill présentait 27–39 % CPU sur une page immobile comme une référence usuelle.
C'est précisément une partie du problème signalé. Les 30 % CPU de la Home froide
du 14-09 ne deviennent pas acceptables parce qu'ils sont reproductibles.
La formulation a été corrigée dans CLAUDE.md et le skill. **Ne plus employer
cette ancienne « norme » pour déclarer la performance bonne.**
Preuve : [dossier initial, mesures et contexte](BUG-CHAUFFE-GEL-HOME.md).

<a id="e02"></a>

### E02 — Attribuer le gel au seul GPU bridé par la chaleur

La première hypothèse n'était pas une preuve. Le build 15 saccade aussi en
thermique nominal : 29,3 callbacks/s médians, trou maximal 905 ms avant la
protection. La trace Metal 8 donne 32,53 % d'activité GPU en union ; dans une
attente de surface de 1,880 s, le GPU est inactif pendant 1,708 s. Les traces
système suivantes établissent des attentes de présentation, sans désigner un
composant unique. **Ne pas conclure « GPU saturé » à partir du CPU bas.**
Preuves : [analyse GPU 8](campagnes/2026-09-14-correctif/trace-home-metal-build8/woop-metal8-analysis.md),
[états GPU 8](campagnes/2026-09-14-correctif/trace-home-metal-build8/woop-metal8-state-analysis.md),
[trace système 15](campagnes/2026-09-14-correctif/trace-home-system-build15/woop-home15-full-system-analysis.md).

<a id="e03"></a>

### E03 — Confondre les compteurs avec de l'énergie ou du rendu réel

`img` mesure les callbacks du main ; `cpu` est une charge récente lissée des
threads Mach, pas l'énergie de l'app ; `tics=0` ne couvre que les sites
instrumentés. Une même catégorie thermique n'implique pas une fréquence CPU/GPU
identique. Des captures espacées prouvent un changement entre deux instants,
pas une animation continuellement fluide. **Conserver ces limites avec chaque
verdict**, même quand les chiffres semblent meilleurs.
Le brouillon du parseur23 écartait aussi `gel=1` sans preuve de veille : corrigé avant le relevé final, ces lignes sont conservées et le plafond 2 000 ms signalé. Aucun gel marqué dans le relevé23 actuel, chiffres inchangés.
Preuve : [définition et correction de SondeVol](AUDIT-NAV-COMPTE-2026-09-14.md).

<a id="e04"></a>

### E04 — Comparaisons dont le contexte n'est pas établi

Les pièges historiques du skill incluent la Porte mesurée à la place de la Home,
la veille qui fait chuter artificiellement le CPU, et les essais consécutifs qui
chauffent le témoin. Le coût d'une page ne s'attribue pas en comparant Home,
sommet du Profil et Profil défilé. Les valeurs 16 / 41 / 25 % du build 6
concernent trois scènes différentes. **Identifier écran, premier plan, veille,
arguments, binaire et thermique avant de comparer.**
Preuves : [skill, méthode et pièges](../../.claude/skills/woop-performance/SKILL.md),
[rapport, fenêtres du build 6](CORRECTIF-CHAUFFE-2026-09-14.md).

## Correctifs insuffisants et prototypes rejetés

<a id="e05"></a>

### E05 — Premier correctif et coupures isolées insuffisants

Après installation du premier correctif le 14-09 à 16:26:56 : Kathryn répond
« Profil toujours inaccessible ». Téléphone chaud, 27,9 callbacks/s, CPU 13 %,
trou maximal 1 819 ms ; les tics galets sont pourtant à zéro.

| Essai chaud | Callbacks/s médians | CPU médian | Trou maximal |
|---|---:|---:|---:|
| Fumée seule coupée | 24,4 | 10 % | 1 470 ms |
| Souffle galets seul coupé | 28,3 | 14 % | 1 597 ms |
| Vie Route seule coupée | 27,1 | 10 % | 1 922 ms |
| Verre Home seul coupé | 25,1 | 13 % | 1 791 ms |
| Fond vidéo en pose | 43,1 | 19 % | 220 ms |
| Fond en pose + fumée coupée | 48,3 | 18 % | 173 ms |

Ces branches n'ont pas résolu le problème. Le fond figé améliore ici les
intervalles, avec davantage de CPU. **Ne pas refaire ces mêmes coupures isolées
en les présentant comme une nouvelle solution.**
Preuves : [table des mesures et fichiers .verdict](CORRECTIF-CHAUFFE-2026-09-14.md).

<a id="e06"></a>

### E06 — Couper cinq effets et conclure trop largement

`-sansFumeeInvite -sansSouffleGalets -sansVieRoute -fondPose -sansVerreHome`
donne 60,1 callbacks/s, maximum 17 ms, CPU 13 %. Cela isole un groupe influent,
sans déterminer l'effet responsable ni démontrer un gain thermique durable.
L'animation coupée ne satisfait pas non plus, à elle seule, le résultat demandé.
Preuve : [verdict du groupe coupé](campagnes/2026-09-14-correctif/diagnostic-sans-ambiance.verdict).

<a id="e07"></a>

### E07 — Protection thermique prise pour une résolution de la chauffe

Les captures protégées atteignent 60,1 callbacks/s, CPU autour de 12–13 % ;
Kathryn signale encore chauffe et animations arrêtées. La protection limite le
travail lorsque le téléphone est déjà chaud ; elle ne prouve pas que la Home
normale ne le chauffe plus. **Garder distincts protection, fluidité et endurance.**
Preuves : [protection et retours utilisateur](CORRECTIF-CHAUFFE-2026-09-14.md).

<a id="e08"></a>

### E08 — Lancement direct sur Profil pris pour un test de navigation

Kathryn confirme Profil et Réglages accessibles après `-openTab profile`.
La Home reste ensuite inaccessible au toucher. Ouvrir directement la destination
ne teste pas le chemin Home → Profil. Le Profil direct coûtait aussi 49 % CPU
dans la première capture. **Tester le bouton habituel depuis la vraie Home.**
Preuves : [audit navigation](AUDIT-NAV-COMPTE-2026-09-14.md),
[Profil direct](campagnes/2026-09-14-correctif/profil-direct.verdict).

<a id="e09"></a>

### E09 — Pont pour neutraliser la barre UIKit : échec utilisateur du build 4b

Installé à 17:27, relancé avec le pont actif à 17:29 : aucun succès tactile
observé. Kathryn répond que rien ne fonctionne et que le téléphone chauffe.
Le témoin ne dure qu'une seconde ; un hit-test théorique n'établit pas le
recognizer réellement appelé. Le journal complet révèle ensuite cinq appuis et
relâchements de 62–114 ms, **zéro tap, zéro `aller`**, gardes ouvertes.
Le pont a été retiré. **Ne pas réintroduire ce pont sans nouvelle preuve.**
Le bouton unique du build 5 corrige l'action perdue ; c'est une réussite de
navigation, distincte de l'échec thermique.
Preuve : [touchers perdus](campagnes/2026-09-14-correctif/nav-echec-utilisateur.jsonl),
[explication et parcours suivant](CORRECTIF-CHAUFFE-2026-09-14.md).

<a id="e10"></a>

### E10 — Un test UI vert qui ne prouvait pas le défilement

Build 10 : test de scroll PASS mais capture montrant encore la pop-up de
bienvenue. Le test ne démontrait pas le déplacement du Profil. Il a été renforcé :
fermer « Plus tard », vérifier le déplacement d'une ligne de plus de 100 points.
Le nouveau test passe. **Ne pas reprendre l'ancien PASS comme preuve de scroll.**
Preuve : [rapport, builds 9–12](CORRECTIF-CHAUFFE-2026-09-14.md).

<a id="e11"></a>

### E11 — Test de navigation lancé alors que l'app n'était plus en cours

Build 9 : précondition `notRunning` après un `xctrace --launch` qui avait terminé
l'app. Ce résultat ne désigne pas une régression du bouton. Le parcours après
relance passe. **Rétablir la précondition avant d'interpréter une assertion UI.**
Preuve : [rapport, navigation après relance du build 9](CORRECTIF-CHAUFFE-2026-09-14.md).

<a id="e12"></a>

### E12 — Mettre SceneKit en pause sans vérifier son compteur

Malgré `scene.isPaused`, `isPlaying=false`, `rendersContinuously=false` et alpha
cumulé nul, le booster caché continuait de rendre. Les flags seuls n'ont donc pas
arrêté son coût. Le build 12 détache `scene=nil` : compteur 449 immobile environ
39 s, puis même scène et caméra qui reprennent à la remontée. **Cette fuite hors
écran est corrigée et mesurée ; cela ne rend pas le Profil visible peu coûteux.**
Preuves : [audit booster](campagnes/2026-09-14-correctif/woop-booster-idle-visible-audit.md),
[compteurs pause/reprise](CORRECTIF-CHAUFFE-2026-09-14.md).

<a id="e13"></a>

### E13 — Liseré Core Animation : CPU bas mais saccades

Build 11 animé : CPU 3 %, mais 17,5 callbacks/s et trou maximal 412 ms.
Même variante en pose : CPU 12 %, 60,1 callbacks/s, maximum 31 ms.
La trace système trouve environ 6,071 s bloquées dans des attentes de
présentation. **Le CPU bas de la variante animée n'est pas un gain utilisable.**
Prototype conservé désactivé.
Preuves : [analyse système du liseré](campagnes/2026-09-14-correctif/trace-lisere-system-build11/woop-lisere11-system-analysis.md),
[note CPU](campagnes/2026-09-14-correctif/trace-lisere-system-build11/woop-lisere11-cpu-note.md).

<a id="e14"></a>

### E14 — Retirer le flou parent ne répare pas ce liseré

Build 13, `-sansFlouWidgetsParent` : même médiane 23,7 callbacks/s et CPU 4 %
que le prototype natif de référence ; trous 649 / 712 ms. Les états thermiques
diffèrent en cours d'essai. **Pas de solution validée ; variante désactivée.**
Preuve : [rapport, build 13](CORRECTIF-CHAUFFE-2026-09-14.md).

<a id="e15"></a>

### E15 — Liseré par images : aucun gain CPU net établi

Build 14 : images CPU 12 %, 58,15 callbacks/s, maximum 83 ms ; référence
CPU 12 %, 60,1 callbacks/s, maximum 100 ms. Mesures chaudes. Aucun gain de
chauffe démontré ; prototype désactivé.
Preuve : [rapport, build 14](CORRECTIF-CHAUFFE-2026-09-14.md).

<a id="e16"></a>

### E16 — Figer la pièce ou les liserés ne suffit pas

Build 14, pièce figée : Home CPU 11 % contre 12 % de référence. Build 18,
liseré en pose / actif : environ 13 / 14 %, callbacks proches de 60,1/s.
Écarts faibles, conditions limitées, chauffe persistante. Le Profil défilé n'est
pas un témoin équivalent de la Home ; la navigation tardive a été exclue des
fenêtres du build 18. **Pas de composant unique innocenté ou condamné.**
Preuves : [rapport](CORRECTIF-CHAUFFE-2026-09-14.md),
[résultats du build 18](campagnes/2026-09-14-correctif/route-sommeil-build18/resultats18.md).

<a id="e17"></a>

### E17 — Fond vidéo, fumée et verre : bisection sans résolution

Build 15 : fond posé + fumée coupée + verre coupé atteint CPU 17 % et
60,1 callbacks/s ; fond posé seul coûte 20,5 % avec 48,3 callbacks/s. La variante
fumée SwiftUI tombe à 3,9 callbacks/s, trous plafonnés à 2 s. Ces essais ne
résolvent pas la chauffe. **Ne pas remettre la fumée SwiftUI comme remède.**
La trace sans SondeVol garde 5,463 s d'attentes sur 8,777 s : la sonde n'est
pas nécessaire au gel.
Preuves : [bisection 15](CORRECTIF-CHAUFFE-2026-09-14.md),
[trace sans sonde](campagnes/2026-09-14-correctif/trace-home-sans-sonde-build15/woop-home15-sans-sonde-system-analysis.md).

<a id="e18"></a>

### E18 — AVPlayerLayer en couche racine : essai négatif

Build 16 : variante racine 27 callbacks/s, maximum 1 199 ms, CPU 10 % ;
référence 31 callbacks/s, maximum 653 ms, CPU 12 %. Deux versions saccadent,
aucun remède démontré. Drapeau désactivé.
Preuve : [rapport, build 16](CORRECTIF-CHAUFFE-2026-09-14.md).

<a id="e19"></a>

### E19 — Fusion vidéo avec Metal : charge encore élevée

Build 17 prolongé : CPU médian 24 %, 50,4 callbacks/s, maximum 154 ms ; deux
boucles du fichier vérifiées. Réduction des grands gels dans cet essai, mais
pas de faible coût énergétique démontré, ni de 60 images GPU/s établies.
Le prototype ne constitue pas la solution à la chauffe et reste désactivé.
Preuve : [lecture prolongée Metal](campagnes/2026-09-14-correctif/fond-metal-build17/woop-build17-metal-long-analysis.md).

<a id="e20"></a>

### E20 — Combiner Metal et liseré natif : régression

Build 17 combiné : CPU 10 %, 15,95 callbacks/s, maximum 1 063 ms ; puis
12,6 callbacks/s et trous supérieurs à 2 s. Retour normal retardé par la
liaison jusqu'à 11:19:28. **Ne pas réactiver cette combinaison.**
Preuve : [essai combiné rejeté](campagnes/2026-09-14-correctif/fond-metal-build17/essai-combine-17.md).

<a id="e21"></a>

### E21 — Cycle de vie de Route : utile, chauffe toujours ouverte

Build 18 : endormissement des feuilles décoratives de Route lorsqu'elles sont
cachées. Kathryn confirme la navigation puis « le téléphone chauffe encore »,
ensuite « un peu moins chaud ». Ce retour positif partiel ne valide pas
l'endurance et n'attribue pas causalement le ressenti au seul changement Route.
Preuve : [résultats et limites du build 18](campagnes/2026-09-14-correctif/route-sommeil-build18/resultats18.md).

<a id="e22"></a>

### E22 — Comparaison avec et sans sonde invalide

Build 18 : capture sans Sonde à environ 1 % CPU, mais contrôle Home effectué
plus de deux minutes auparavant, sans maintien de veille indépendant. L'écran
pouvait être verrouillé. Le contrôle après mesure peut le réveiller.
**Ne pas annoncer une Home à 1 % CPU ni un surcoût de sonde de 13 points.**
Le maintien d'écran indépendant a été ajouté ensuite.
Preuve : [comparaison CPU 18 explicitement invalidée](campagnes/2026-09-14-correctif/route-sommeil-build18/comparaison-cpu18-limitee.md).

<a id="e23"></a>

### E23 — Première vidéo unique non utilisée par la Home

Build 20 : fond précalculé pour 393 × 660, alors que la surface réelle vaut
393 × 709. Le garde de cadrage utilise le repli à deux lecteurs.
**La capture 20 ne teste donc pas une vidéo unique.** Mauvais assets retirés
de l'app ; fichier ajusté à la géométrie réelle au build 21.
Preuve : [limite du build 20](campagnes/2026-09-14-correctif/fond-precompose-build20/limite20.md).

<a id="e24"></a>

### E24 — Vidéo unique correctement montée, chauffe non validée

Build 21 : fichier 786 × 1418, 859 images à 24 i/s, surface logique 393 × 709,
montage confirmé par le journal. 28,1 % de pixels décodés en moins est un calcul
sur les dimensions, **pas une mesure d'énergie économisée**. Capture CPU autour
de 18,2 % avec thermique Fair → Serious ; comparaison interrompue par CoreDevice.
Pas de correspondance image par image des couleurs validée non plus.
Preuve : [état et preuves du build 21](campagnes/2026-09-14-correctif/fond-precompose-build21/etat.md).

<a id="e25"></a>

### E25 — Comparaison vidéo du build 22 : écart non concluant

Installé le 15-09 à 14:25. Deux lecteurs : 13,74 % CPU échantillonné sur
13,306 s, Fair puis Serious ; vidéo unique : 13,57 % sur 13,143 s, Serious.
Home active et éveillée vérifiée, sonde éteinte. Conditions thermiques différentes,
captures courtes, aucune cadence GPU ni énergie mesurée : **aucun gain durable
de chauffe établi**. Navigation complète PASS 9,301 s à 14:31:39 ; QA04 reste KO.
Preuve : [état et comparaison 22](campagnes/2026-09-14-correctif/protection-bornee-build22/etat.md).

## Échecs de mesure, de lancement et de restauration

<a id="e26"></a>

### E26 — Diagnostic sans protection resté actif après coupure

Le build 21 pouvait rester lancé avec `-sansProtectionThermique` lorsque le
retour normal échouait à cause du transport. C'était un défaut du protocole de
test. Le build 22 fait expirer cet argument après 60 s ; expiration observée
le 15-09 à 14:31:25,602. **Toute réduction diagnostic doit se restaurer sur le
téléphone sans dépendre du Mac.** Le banc 23 conserve la protection normale.
Preuve : [journal d'expiration et état 22](campagnes/2026-09-14-correctif/protection-bornee-build22/etat.md).

<a id="e27"></a>

### E27 — Traces sans données exploitables

- Première Metal de référence : 43 tables, zéro donnée CPU/GPU exploitable,
  états Unknown ; aucune conclusion sur le GPU.
- Symboles CPU du build 5 tentés avec dSYM du build 8 : UUID différents,
  attribution aux fonctions impossible. Employer le dSYM du binaire mesuré.
- Capture Metal 17 : sortie incorrecte ou export partiel mal formé, code 10 ;
  collecte environ 39 s pour 8 s demandées. Ne pas confondre compteur de lecture
  de fichiers et preuve de présentation continue des vidéos.
- Build 20, Time Profiler + Power Profiler : trace sauvée mais export TOC
  terminé par segmentation fault 139. Aucune mesure énergétique exploitable.

Preuves : [première trace](campagnes/2026-09-14-correctif/trace-reference/LECTURE.md),
[rapport des captures](CORRECTIF-CHAUFFE-2026-09-14.md),
[limite 20](campagnes/2026-09-14-correctif/fond-precompose-build20/limite20.md).

<a id="e28"></a>

### E28 — SwiftUI 22 : plusieurs captures interrompues, pas de coupable trouvé

15-09 : collecte refusée à 14:32 et 14:33 (CoreDevice 1011). Attachement
SwiftUI à 14:34:49 : coupure à 14:34:52, soit 3,368328 s au lieu des 8 s
demandées ; export `swiftui-updates` sans aucune ligne. Lancement SwiftUI
suivant à 14:38 également interrompu. **Ne pas accuser une animation à partir
de ces traces vides, ni répéter indéfiniment cette voie de capture.**
Preuve : [état et incidents 22](campagnes/2026-09-14-correctif/protection-bornee-build22/etat.md).

<a id="e29"></a>

### E29 — « Unavailable » malgré le câble : diagnostic de liaison incomplet

Le 15-09, macOS voit en USB le numéro de série du même iPhone, tandis que
CoreDevice alterne connected, unavailable, erreur 1011 et tunnel interrompu
4000. Une liste connected ne garantit pas que l'appel suivant réussira.
`launchctl kickstart` échoue avec code 113 (service introuvable sous ce nom).
La relance ciblée du processus CoreDeviceService ne rétablit pas durablement
devicectl. **Ne plus déduire « câble débranché » de ce seul état.**
XCTest ouvre pourtant la Home normale à 14:42:49, PASS 4,048 s. La lecture
de journal à 14:47 échoue encore ; elle ne renseigne pas la température.
Preuve : [retour normal et limites de liaison 22](campagnes/2026-09-14-correctif/protection-bornee-build22/etat.md).

<a id="e30"></a>

### E30 — Installation, verrouillage et confiance du runner confondus

Plusieurs lancements échouent avec `Locked` après installation réussie
(notamment builds 5 et 22). D'autres échouent parce que l'appareil est
indisponible (builds 7, 19, certaines tentatives 21/22). À 13:15 le 15-09,
l'iPhone refuse aussi l'autorisation du runner XCTest. Ces motifs sont
différents. Signatures app/runner vérifiées valides hors sandbox, profils
valables jusqu'en septembre 2027. **Un contrôle de confiance impossible en
sandbox ne signifie pas une app mal signée.** Ne pas déclarer une version
installée ou lancée sur la seule réussite du build.
Preuves : [rapport chronologique](CORRECTIF-CHAUFFE-2026-09-14.md),
[état historique 22](campagnes/2026-09-14-correctif/protection-bornee-build22/etat.md).

<a id="e31"></a>

### E31 — Outils de collecte et résultats réutilisés

Le collecteur attendait des événements `etat` produits par la sonde : sonde
éteinte, IndexError. Correction avec lecture nav seule et tolérance à l'absence
de ces événements. Un ancien `vol` peut rester le plus récent : vérifier les
dates et le manifeste de provenance. Autre erreur : chemin `.xcresult` déjà
existant, sortie 64 avant les tests. **Ce ne sont pas des échecs de navigation.**
Preuves : [état 20](campagnes/2026-09-14-correctif/fond-precompose-build20/limite20.md),
[campagnes et provenances](campagnes/2026-09-14-correctif/).

<a id="e32"></a>

### E32 — Attentes d'outils qui ont prolongé les essais

Le 15-09, une demande d'exécution hors sandbox reste bloquée de 12:12 à
13:15 ; la reprise atteint ensuite le refus de confiance du runner. Cet
intervalle n'est ni une mesure de chauffe ni du temps de compilation utile.
Les coupures successives ont aussi empêché certaines restaurations immédiates
(E20, E26, E28). **Borner les essais et restaurer localement leurs flags.**
Preuves : [état 21](campagnes/2026-09-14-correctif/fond-precompose-build21/etat.md),
[état historique 22](campagnes/2026-09-14-correctif/protection-bornee-build22/etat.md).

<a id="e33"></a>

### E33 — Build documentation bloqué en sandbox

Le build Next est resté immobile plus de trois minutes ; seuls ses propres
processus ont été interrompus, puis la commande relancée hors sandbox.
Artefact et vérifications passent ensuite, puis à nouveau à 14:45–14:46
(45 s de vérification). **La documentation vérifiée ne valide pas l'app sur
l'iPhone.** Ne pas attendre indéfiniment une commande immobile.
Preuve : [état et logs documentation 22](campagnes/2026-09-14-correctif/protection-bornee-build22/etat.md).

<a id="e34"></a>

### E34 — Documentation locale différente d'une publication en ligne

La source Next et `docs/site/index.html` ont été mis à jour ; l'outil Artifact
pour republier au lien Claude n'est pas disponible. **Ne pas annoncer que le
lien externe a été actualisé.** Ce registre est dans le dépôt, accessible par
les liens placés en tête des trois rapports de chauffe/navigation.
Preuve : [état de publication 22](campagnes/2026-09-14-correctif/protection-bornee-build22/etat.md).

<a id="e35"></a>

### E35 — Compilation 23 enlisée dans la résolution des types

Première compilation interrompue après plus de dix minutes sans résultat.
Un échantillon du processus `swift-frontend` montre le solveur de contraintes
Swift actif, pas une installation iPhone. Le format JSON de SondeVol a été
simplifié (un littéral au lieu d'une longue addition de chaînes), puis une
compilation 23b lancée avec journal des durées de fonctions. La simplification
est une tentative ciblée ; l'échantillon seul ne nomme pas la fonction fautive.
Aucun résultat appareil ne peut être attribué à cette première compilation. La Release 23b et son lanceur compilent finalement vers 15:21. Les durées finales (SondeVol.ecrire : 7,02 ms ; plusieurs vues : 6–12 s chacune) ne permettent pas d’attribuer toute l’attente à l’expression ajoutée.
Preuves : [échantillon compilateur](campagnes/2026-09-14-correctif/banc-blocs-build23/compilation-initiale-sample.txt).

<a id="e36"></a>

### E36 — Maintien d'écran pendant la compilation : lancement non exécuté

Le 15-09 à 15:15, `testOuvrirHomeEveillee` ne démarre pas : destination
ineligible, « Device is busy (Connecting to iPhone de Frédéric) », expiration
de l'attente de destination. Aucune assertion exécutée. Le maintien de veille
n'a donc pas été renouvelé par cette tentative ; ce n'est pas une preuve de
verrouillage physique ni de débranchement. Ne pas annoncer un lancement réussi.
Preuve : [journal XCTest](campagnes/2026-09-14-correctif/banc-blocs-build23/test22-eveille-attente23-1516.log).

<a id="e37"></a>

### E37 — Chemin de liste Swift incorrect dans le contrôle direct

Le contrôle direct de types a d'abord utilisé `Woop.build/Woop.SwiftFileList` :
« unexpected input file », aucun contrôle effectué. Le fichier réel est dans
`Objects-normal/arm64/`. La commande corrigée progresse, puis est interrompue
car le vrai build Release vient de réussir. Le second PID visé par l’arrêt avait déjà disparu : cette erreur de kill ne concerne pas l’iPhone. Plus tard, `codesign --extract-certificates PREFIX` échoue en prenant PREFIX pour un fichier ; la forme locale correcte est `--extract-certificates=PREFIX`, et la comparaison suivante réussit. Aucun certificat n’a été modifié.
Preuve : [erreur de chemin](campagnes/2026-09-14-correctif/banc-blocs-build23/typecheck-chemin-incorrect.log).

Une passe typographique sur le registre a aussi ajouté des espaces dans des
chemins de liens. Corrigé avant livraison ; tous les liens locaux concernés
ont ensuite été vérifiés.

<a id="e38"></a>

### E38 — Installation 23 sans confirmation après 30 secondes

Le 15-09 à 15:23:16, tunnel acquis, puis activation des services développeur.
La commande dépasse 30 s et s'arrête sans confirmer l'installation. Une reprise
par nom d'appareil avec délai 60 s est lancée ; elle confirme finalement l’installation à 15:26 (conteneur `09260A50-F02E-4F4D-A37F-11DBB89DEA2A`). Le premier échec reste conservé. Un timeout ne prouve ni la réussite
ni l'absence de modification du conteneur.
Preuve : [première installation](campagnes/2026-09-14-correctif/banc-blocs-build23/installation23-premiere.log).

<a id="e39"></a>

### E39 — Build 23 installé, lancement direct refusé par iOS

Le 15-09 à 15:27:47, `devicectl process launch` échoue avec Security : iOS
mentionne signature, droits ou confiance du profil, sans distinguer la cause.
Vérification hors sandbox : signature app valide, exigences désignées satisfaites,
profil incluant cet iPhone, expiration le 06-09-2027, identifiant app et équipe
concordants, `get-task-allow=true`. Ces contrôles locaux ne prouvent pas la
confiance effective sur le téléphone. Une tentative via XCTest est ensuite
bornée à 80 s côté Mac. Ne pas présenter ce refus comme une mesure de chauffe,
ni comme un certificat local invalide démontré. Le runner démarre à 15:29:46, mais son appel à ouvrir Woop échoue en 0,164 s avec le même refus. App et runner emploient le même certificat, présent dans leurs profils. À 15:33:56, le lancement direct réussit pendant une collecte système bornée ; SpringBoard confirme Woop actif et visible. Aucun changement de signature entre ces deux lancements, cause du refus non établie.
Preuves : [refus iOS](campagnes/2026-09-14-correctif/banc-blocs-build23/lancement-direct23-refuse.log),
[signature](campagnes/2026-09-14-correctif/banc-blocs-build23/signature23.log),
[profil vérifié](campagnes/2026-09-14-correctif/banc-blocs-build23/profil23-resume.json).

<a id="e40"></a>

### E40 — Premier banc 23 interrompu par le passage en arrière-plan

Lancé à 15:33:56, sonde à 15:34:02. Phases effectivement enregistrées : complète
35 lignes, sans widgets 25 lignes, sans Route seulement deux lignes. Passage
inactive/background vers 15:35:05 : restauration automatique complète, événement
`banc-home-fin`, arrêt de la sonde. Les phases fond seul et nu n'ont pas eu lieu.
Le maintien d'écran n'interdit pas un changement d'application. Cause du passage
en arrière-plan non attribuée à l'utilisateur ou à un outil faute de preuve.

Complète après préparation : CPU médian 16 %, 48,75 callbacks/s, thermique et
protection 0 puis 1. Sans widgets après 10 s : CPU 8 %, 60,1 callbacks/s,
thermique/protection 1. **La transition thermique confond cette comparaison** ;
ce n'est ni le coût exclusif des widgets ni une preuve de baisse de chauffe.
La reprise unique de 15:36:56 est refusée avec **Locked** : aucun nouveau banc. Déverrouillage demandé à Kathryn. [Journal du refus](campagnes/2026-09-14-correctif/banc-blocs-build23/reprise23-refusee-verrouillage.log).
Preuves : [analyse incomplète](campagnes/2026-09-14-correctif/banc-blocs-build23/woop-banc23-interrompu-analyse.json),
[journal et restauration](campagnes/2026-09-14-correctif/banc-blocs-build23/woop-banc23-intermediaire-nav.jsonl).

<a id="e41"></a>

### E41 — Collecte du banc complet bloquée, puis contournée par HouseArrest

Le lancement confirmé à 15:42:12 a produit les six phases et leur restauration.
La collecte CoreDevice à partir de 15:45 échoue avec 1011, malgré USB présent,
nom lu par ideviceinfo et liste Xcode parfois connected. Les premiers essais
afcclient avec --documents échouent aussi. Le conteneur de développement
`afcclient --container fr.kathryn.woop`, commandes ls/get fournies immédiatement
sur stdin, permet finalement de copier les nouveaux journaux à 15:54–15:55.
**Ne pas refaire un banc dont les données attendent déjà dans l'app.**
Repli : [collecteur USB](collecte_usb.py), limité aux journaux et au bon iPhone.
Preuves : [état détaillé](campagnes/2026-09-14-correctif/banc-blocs-build23/etat.md),
[analyse complète](campagnes/2026-09-14-correctif/banc-blocs-build23/woop-banc23-complet-usb-analyse.json).

<a id="e42"></a>

### E42 — Trois décors coupés, charge toujours présente à thermique 2

Témoin23 lancé à 16:02:49 avec -sansInvite -sansPiece -liserePose 0.
Premières fenêtres stables : complète 15 %, sans widgets 16 %, sans Route 14 %,
fond seul 18 %, nu 20 %. Thermique2, environ60 callbacks/s. Collecte avant la
dernière phase. Contrairement au premier banc à thermique 1, le coût persiste
quand le mobilier est démonté. **Pas de gain établi, pas de cause unique
attribuable aux trois décors.** La capture suivante confirme la vraie Home.
La trace CPU 16:06 est vide après déconnexion (durée TOC9,534 s, zéro sample) ;
son parseur historique échoue sur min(liste vide). Screenshotr iOS refuse le
service, remplacé par la capture XCTest (test Home prêt PASS16:07:03).

Le build 24 ferme néanmoins les trois échappements de décor à la protection
thermique trouvés dans le code. Compilé et installé, il n'est pas déclaré
correctif validé de la chauffe. Premier lancement16:10 refusé Locked ;
ouverture par Kathryn puis lancement du banc 16:11:47 confirmé.
Preuves et état24 : [protection complétée](campagnes/2026-09-14-correctif/protection-complete-build24/etat.md).

<a id="e43"></a>

### E43 — « Onglet Home » ne prouve pas l'absence de Welcome back

Banc 24 : première phase complète 1,5 % CPU, finale 14 %, même thermique 2.
Le premier chiffre encourageant ne tient pas au remontage. Plus grave :
le banc 23/24 ignorait les pop-ups. L'automatisation Home prêt16:07 a
**touché Later** avant de capturer la Home ; cette capture ne pouvait donc
pas prouver le bon écran pendant la mesure d'avant. Pièce de rayon12 dans
les journaux : celle du bouton Claim de RewardCard est encore montée.

**Les attributions des bancs23/24 à la Home seule sont non certifiées.**
Les nombres restent conservés avec cette réserve, sans annoncer de gain.
Le banc 25 ferme uniquement Welcome back comme Later, interdit toute fenêtre
couvrante dans sa garde, écrit welcome/premiere et prend six captures.
[Preuve du tap Later](campagnes/2026-09-14-correctif/protection-complete-build24/woop-banc23-decor-ecran-1606.log),
[réparation du banc 25](campagnes/2026-09-14-correctif/banc-verifie-build25/etat.md).

<a id="e44"></a>

### E44 — Cinq secondes ne garantissent pas que la Home soit prête

À 19:38, le banc25 s’interrompt après un appui Exercices : deux secondes,
aucune stable. Relance à 19:39:56 : le banc quitte à cinq secondes, avant la
première mesure ; le décor apparaît ensuite à dix secondes. La garde fautive
n’était pas enregistrée. Le collecteur retourne alors l’ancien vol de 19:38 :
**un fichier le plus récent n’est pas nécessairement celui du lancement testé.**
Le diagnostic26 attend la préparation effective, borne l’attente et écrit les
obstacles ainsi que les annulations. Power Profiler échoue aussi à se connecter
(`Timed out waiting for device to boot`, code13) : aucune donnée énergétique.
[Chronologie et journaux](campagnes/2026-09-14-correctif/reprise-froide-build26/etat.md).

<a id="e45"></a>

### E45 — À froid : enlever une animation ne suffit toujours pas

Le banc27 attend désormais nominal0. Sur le même binaire : enlever la fumée
laisse la Home irrégulière (44,8 /47,3 callbacks/s, CPU14 /12,5 %). Ajouter
la pièce figée donne60,1 callbacks/s mais encore15 /16 % CPU. Le liseré
Core Animation donne20 /21 % CPU à60,1 callbacks/s : pas retenu. Le liseré
SwiftUI en pose donne21 % CPU dans sa première phase froide, puis iOS passe
à thermique1. Le verre est aussi coupé par la protection thermique ; ne pas
attribuer tout son gain aux seules animations posées.
Les captures UIKit ne montrent pas correctement les vidéos : fond noir,
mais l’utilisateur confirme « Oui, les flammes bougent » sur l’iPhone.
[Mesures, arguments et limites27](campagnes/2026-09-14-correctif/fumee-isolee-build27/etat.md).

<a id="banc-23"></a>

## État actuel du banc

**15-09 à21:55 : build30 installé, navigation PASS9,267s, chevrons natifs visiblement animés. Chauffe toujours ouverte.** Retour utilisateur sur30 : « je trouve que ça chauffe beaucoup moins ». Amélioration nette ressentie, durée prolongée encore à confirmer. La mesure30 à1 % CPU est en thermique1/protection1 : elle ne prouve pas le gain du rendu animé. La Home normale restaurée à21:54:42 repasse de0 à1 ; le branchement pendant le retour utilisateur n’est pas précisé. [État30, captures, sources et mesures](campagnes/2026-09-14-correctif/chevrons-natifs-build30/etat.md).

Le verre n’est pas retiré : les traces28 nominales donnent4,962 % CPU avec verre contre4,897 % sans, sans gain clair des scores de puissance disponibles. L’invitation29 isole3 % CPU normale contre1 % retirée (20 relevés,15<t≤35s ; l’ancien résumé4 % retenait19 relevés,t≥16). Le30 garde le texte et le mouvement avec Core Animation ; sa mesure froide reste à faire. Le29 ferme les lecteurs Home/Exos au démontage, journaux rate0/items0 vérifiés. QA04 reste KO ; aucun cycle complet de compte ni suppression. Registre50 entrées.

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
