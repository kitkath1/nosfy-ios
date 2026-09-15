# Chauffe et gels de la Home — correctif du 14 septembre 2026

**Concession visuelle confirmée par l’utilisateur sur30 : le widget Chapitre a perdu ses animations.** Le fond liquide (`FondLiquide`) et le liseré tournant (`LisereTournant`) ne sont plus montés quand `decorHomeAuRepos` est vrai ; les halos/ondes d’appel sont retirés et la respiration du halo interne du galet est figée. Ce changement est permanent sur la Home actuelle, même à froid ; ce n’est pas seulement la protection thermique. Il contribue potentiellement au gain global28, sans attribution isolée de chacun de ces effets. Le rendu complet demandé reste donc à restaurer avec un coût maîtrisé. Les deux chevrons natifs30 sont un autre composant, pas une remise en animation du Chapitre.

**15-09 à21:55 : build30 installé, navigation PASS9,267s, chevrons natifs visiblement animés. Chauffe toujours ouverte.** Retour utilisateur sur30 : « je trouve que ça chauffe beaucoup moins ». Amélioration nette ressentie, durée prolongée encore à confirmer. La mesure30 à1 % CPU est en thermique1/protection1 : elle ne prouve pas le gain du rendu animé. La Home normale restaurée à21:54:42 repasse de0 à1 ; le branchement pendant le retour utilisateur n’est pas précisé. [État30, captures, sources et mesures](campagnes/2026-09-14-correctif/chevrons-natifs-build30/etat.md).

Le verre n’est pas retiré : les traces28 nominales donnent4,962 % CPU avec verre contre4,897 % sans, sans gain clair des scores de puissance disponibles. L’invitation29 isole3 % CPU normale contre1 % retirée (20 relevés,15<t≤35s ; l’ancien résumé4 % retenait19 relevés,t≥16). Le30 garde le texte et le mouvement avec Core Animation ; sa mesure froide reste à faire. Le29 ferme les lecteurs Home/Exos au démontage, journaux rate0/items0 vérifiés. QA04 reste KO ; aucun cycle complet de compte ni suppression. Registre50 entrées.


**À lire avant de reprendre : [registre des échecs et mesures invalides](ECHECS-CHAUFFE-HOME.md).**

**État historique28 — 15-09 à 21:12 : build 28 installé, navigation validée, CPU médian 5 % à froid. Chauffe durable à confirmer.**

La Home garde la vidéo et pose ses petits ornements par défaut, y compris après fermeture/réouverture. Le relevé final de 35 s donne 19 échantillons stables après exclusion des 15 premières secondes : CPU médian 5 %, 60,1 callbacks/s, pire intervalle 17 ms, thermique 0 et protection 0, aucun popup, aucun gel marqué. Les callbacks ne sont pas des images GPU ; ce relevé ne mesure ni watts ni autonomie.

Home → Exercices → Home → Profil → Réglages passe sur 28 en 9,373 s. Compteurs éteints et Home normale restaurée à 21:12. La capture Power Profiler 28 reste inexploitable (délai dépassé) ; elle est remplacée par ce relevé de sonde. QA04 reste KO jusqu’au retour d’usage. QA07 valide l’accès ; aucun cycle de compte ni suppression. Registre : 47 entrées.
[Résultat 28, sources, journaux et limites](campagnes/2026-09-14-correctif/instruments-decor-home-build28/etat.md).

Les états ci-dessous sont historiques ; l'indisponibilité d’Instruments à20:13 a pris fin à20:15.

**État au 15-09 à 16:28 : build25 installé ; Home protégée à 1 % CPU, chauffe à valider.**
Le banc complet vérifie cette fois l'absence de fenêtres de bienvenue et produit
six captures. Première capture lue : vraie Home. CPU médian 1 % au début et à
la fin, environ 60 callbacks/s, thermique/protection 1 sur toute la mesure.
Restauration complète et arrêt de sonde confirmés. Le coût du rendu animé à
froid et la chaleur ressentie ne sont pas validés : QA04 reste KO. Navigation24
PASS à 16:20:50 en 8,973 s ; pas de cycle de compte ni de suppression.
[Résultat25, captures et limites](campagnes/2026-09-14-correctif/banc-verifie-build25/etat.md).
Les anciens chiffres23/24 gardent une réserve majeure : Welcome back n'était
pas exclu (E43). Registre central : 43 échecs, essais insuffisants et incidents.

**Reprise du 15-09, 20:13 : build27 installé, diagnostic à froid ; chauffe ouverte.**
Le banc attend maintenant la vraie Home puis nominal0. Sans fumée : la Home
reste irrégulière. Avec la pièce en pose : cadence60,1 mais CPU15–16 %.
Bordures natives20–21 % ; bordures SwiftUI en pose21 % au début puis thermique1.
Ces variantes ne suffisent pas. Test séparé du verre dynamique en cours.
Les flammes sont confirmées animées par l’utilisateur ; les captures UIKit
ne représentent pas correctement leur couche. Instruments voit l’iPhone
hors ligne, aucune puissance mesurée. Registre central porté à45 entrées.
[Mesures27 et limites](campagnes/2026-09-14-correctif/fumee-isolee-build27/etat.md).

État historique précédent :

**État au 15-09 à 14:43 : build 22 installé, navigation vérifiée, chauffe encore ouverte.**
Le build 22 est posé à 14:25:47. Home → Exercices → Home → Profil → Réglages
passe à 14:31:39 en 9,301 s, téléphone en thermique 2. Le diagnostic sans
protection expire bien après 60 s. La comparaison réelle deux lecteurs / fond
unique donne environ 13,74 / 13,57 % d'un cœur échantillonné, avec des états
thermiques différents et sans mesure de cadence GPU : **aucun gain durable de
chauffe démontré**. Les détails et limites sont dans
[le relevé du build 22](campagnes/2026-09-14-correctif/protection-bornee-build22/etat.md).
Après interruption des traces SwiftUI, l'automatisation rend la Home normale
à 14:42:49 (PASS 4,048 s), sans sonde, écran éveillé pour 30 min.

Les paragraphes ci-dessous conservent l'historique antérieur à cette reprise.
Kathryn confirme sur le build 18 : « Navigation possible, mais le téléphone
chauffe encore », puis « mais c'est un peu moins chaud ». Le parcours automatique
Home → Exercices → Home → Profil → Réglages passe en 8,671 s à 11:20:02.
QA07 valide cet accès ; QA04 reste KO. Le cycle complet avec suppression n'a
pas été exécuté. Les captures du parcours sont dans `route-sommeil-build18/`.

Les corrections établies portent sur la reconnaissance des boutons, le rendu
du booster caché et la suspension des décors hors écran. La protection thermique
immobilise certains décors dès Fair ; elle évite des blocages dans les fenêtres
mesurées, mais ne démontre pas une résolution durable de la chauffe. La Home a
également saccadé à thermique nominal : le bridage ne suffit pas à expliquer le
défaut. Les traces montrent des attentes Core Animation / RenderBox, y compris
sans Sonde ; elles ne prouvent ni le calque fautif ni une saturation GPU.

Kathryn demande de simplifier le rendu par vidéo précalculée. Le **build 21 est
installé à 12:09:30** : il fusionne les deux vidéos et le scrim sur le Mac, puis
utilise un seul lecteur natif, H.264 786 × 1418, 859 images à 24 i/s. Le montage
réel est prouvé par le nav et la capture Home. Ce cadrage concerne 393 × 709 pt ;
les autres tailles gardent les calques existants. Le premier fichier 660 pt
n'a jamais été utilisé, le garde de cadrage ayant correctement fait repli.

La capture CPU 21, sans SondeVol, écran maintenu éveillé et Home active,
échantillonne environ 18,2 % d'un cœur sur 13,208 s ; thermique Fair puis Serious.
**Aucun gain causal ou durable de chauffe n'est déclaré.** La liaison se coupe
avant le contrôle de mouvement, la navigation 21 et le témoin. Une restauration
via XCTest est ensuite refusée : certificat développeur du runner non fiable.
Le build 22 ajoute une expiration automatique à 60 s du mode sans protection,
pour qu'une coupure de connexion ne puisse plus le laisser actif indéfiniment.
Le maintien d'écran QA, demandé par Kathryn, est limité à 30 min et non persisté.

La comparaison CPU 18 avec/sans sonde reste non concluante : la veille n'était
pas contrôlée pour son essai sans sonde. Les résultats détaillés sont datés
ci-dessous ; les verdicts récents remplacent les états historiques. Aucun
commit, aucune suppression de compte. La navigation 18 est confirmée ; le
cycle de compte et la chauffe restent à valider sur le téléphone.

## Périmètre et travail préservé

Référence demandée : commit `c313012`. Travail effectué dans le working tree
existant, en conservant ses nombreuses modifications antérieures, notamment
le compte et les réglages. Aucun reset, suppression de compte ou commit.
Les changements ci-dessous décrivent ce correctif ; le diff global contient
aussi le travail préexistant et ne doit pas être attribué en bloc à la chauffe.

## Mesures sur l'iPhone

Sources : les `.verdict` de référence et d'isolation présents dans
`campagnes/2026-09-14-correctif/`, avec leurs JSONL. Toutes ces mesures sont
sans séance, avec catégorie thermique **2 au départ, en médiane et au maximum**.
Les neuf premières concernent Home ; la dernière concerne Profil.

| Essai / fichier | Échantillons | Callbacks/s médiane | Pire intervalle médian / maximal, ms | CPU médian |
|---|---:|---:|---:|---:|
| Référence antérieure — `avant.verdict` | 103 | 10,5 | 512 / 1981 | 4 % |
| Premier correctif — `apres-premier.verdict` | 189 | 27,9 | 156 / 1819 | 13 % |
| Groupe de cinq effets coupé — `diagnostic-sans-ambiance.verdict` | 41 | 60,1 | 17 / 17 | 13 % |
| Fumée seule coupée — `sans-fumee.verdict` | 109 | 24,4 | 236 / 1470 | 10 % |
| Souffle galets seul coupé — `sans-souffle-galets.verdict` | 76 | 28,3 | 142 / 1597 | 14 % |
| Vie Route seule coupée — `sans-vie-route.verdict` | 70 | 27,1 | 212 / 1922 | 10 % |
| Verre Home seul coupé — `sans-verre-home.verdict` | 47 | 25,1 | 219 / 1791 | 13 % |
| Fond vidéo en pose — `fond-pose.verdict` | 124 | 43,1 | 83 / 220 | 19 % |
| Fond en pose + fumée coupée — `fond-pose-sans-fumee.verdict` | 135 | 48,3 | 62 / 173 | 18 % |
| Profil direct avant pause/30 Hz — `profil-direct.verdict` | 83 | 60,1 | 17 / 48 | 49 % |

Le groupe est exactement `-sansFumeeInvite -sansSouffleGalets -sansVieRoute
-fondPose -sansVerreHome`. Sur le premier correctif, les tics galets sont à
zéro : cette horloge s'est tue, mais Kathryn rapporte encore une Home chaude
et un Profil inaccessible. Le fond en pose améliore les intervalles dans
ces essais sans retrouver seul la régularité du groupe. L'ordre, les durées
et les températures physiques ne sont pas contrôlés : pas de campagne A/B
alternée, pas d'attribution causale exclusive au GPU ou à un seul effet.

`SondeVol.img` compte les callbacks CADisplayLink sur le fil principal,
**pas les nouvelles images GPU présentées**. `cpu` somme la charge récente
lissée des threads du processus, en pourcentage d'un cœur ; ni GPU ni énergie.
Les tics ne couvrent que les sites instrumentés. Deux mesures en thermique 2
ne garantissent pas des fréquences CPU/GPU identiques.

## Changements de source

- **Galets — `GaletEtape.swift`.** Les poses de lumière aux deux extrêmes
  sont composées avec `plusLighter`, suivant la courbe et la période de
  respiration existantes. Verre, glyphes et flous constants sortent de
  l'horloge répétée ; interactions et retours d'appui restent vivants.
  L'interpolation du halo est exacte ; celle du soft-clip exponentiel du
  shader reste une approximation : un balayage numérique abstrait en double
  a observé au maximum **2,4575/255 en alpha et 0,2214/255 par canal RGB**.
  Ce n'est ni une borne démontrée sur tout le domaine ni une mesure de
  pixels : demi-précision GPU, quantification et compositeur sont exclus.
  Ces chiffres concernent uniquement les galets, pas le rendu MTK. Témoins :
  `-galetsHorloge`, `-sansSouffleGalets`.
- **Fumée — `FumeeInviteMetal.swift`, `HomeNuit.metal`, `HomeNuit.swift`.**
  Le ciel cité dans l'ancien dossier appartient à la Home archivée ; le
  panache d'invitation est réellement monté. Nouveau candidat MTKView à
  20 Hz, surface indépendante 315 × 300 pixels (1,5 pixel/point), contre
  630 × 600 à l'échelle 3. Même fonction `panacheCouleur`, mêmes paramètres
  de dessin et souffle ; résolution et moteur de composition changent.
  Acquisition du drawable et commandes hors du fil principal, deux images
  en vol au plus, image décorative sautée si le budget est occupé.
  Témoins : `-fumeeSwiftUI`, `-fumeeNative`. Aucun gain ni équivalence visuelle
  globale n'est déduit du seul portage.
- **Foyer couvert — `CouvertureFoyer`, `Foyer.swift`, châssis du Player.**
  Le foyer ne dort qu'après couverture effective par le grand Player ;
  les jetons d'ouverture et de déplacement empêchent une ancienne fin
  d'animation de refermer la porte pendant un nouveau geste. Le décor
  reste visible pendant le mouvement puis se tait sous l'écran qui le couvre.
- **Profil — `ProfilLune.swift`, pont `BoosterStage` de `BoosterLab.swift`.**
  Les deux boosters suivent onglet caché, scène inactive et manège ; le
  géant garde sa pause lorsqu'il disparaît au scroll. SceneKit, six
  displayLinks, Timer d'invitation et crédit CoreMotion suivent la pause,
  sans démontage ni reprise du Sacre. Profil demande 30 Hz ; `-profil60Hz`
  restitue 60 pour comparaison. Les autres hôtes et cérémonies gardent 60.
  Le build 5 donne ensuite 38 % CPU médian sur le Profil ; cette mesure du
  processus n'isole ni SceneKit ni le gain propre au passage à 30 Hz.
- **Profil hors écran — `DosVide`, `BanniereHalos` dans `ProfilLune.swift`,
  build 6 installé et testé.** Les 25 dos vides avaient chacun une boucle
  d'allumage, même hors onglet et hors viewport. La tâche suit désormais
  l'onglet, la scène, Reduce Motion et l'intersection des deux viewports
  imbriqués ; annulation au repos, phases remises à zéro sans animation,
  reprise après un nouveau délai de 5–9 s. Seul le dessin change d'identité
  à la pause pour interrompre aussi les interpolations déjà différées ;
  le bouton reste stable. Les matériaux et les durées visibles sont conservés,
  sans horloge ajoutée. Le halo de bannière suspend son TimelineView quand
  il sort du scroll, de l'onglet ou de la scène, ainsi qu'avec Reduce Motion ;
  shader, paramètres et cadence visible de 30 Hz conservés. Analyses
  syntaxiques et diff réussis. Les fenêtres du build 6 sont ci-dessous ;
  elles n'isolent pas le gain de chacune de ces portes.
- **Dernières portes Profil — builds 7/8.** Avatar, flèches et poignée
  suivent désormais onglet, scène active, Reduce Motion et leur visibilité ;
  les flèches/poignée se taisent au fondu exactement nul. Le build 8 corrige
  aussi la tâche d'invitation du grand booster : annulation hors écran,
  pendant un geste, avec panneau ouvert ou sachet enterré/planqué ; remise
  à zéro sans animation et retour porté par la tâche annulable. Dessin et
  gestes conservés. Ces sources sont compilées et installées dans le build 8,
  dont l'essai appareil reste attendu.
- **Sonde — `SondeVol.swift`.** Chaque droit Mach renvoyé par `task_threads`
  est libéré, puis le tableau ; buffer `thread_basic_info` correctement
  dimensionné. Preuve locale de propriété des droits : références
  3 → 4 → 5 → 6 sans libération, stables avec libération. Le contexte
  Player inclut `couvre` ; le contexte de protection est publié. Cette
  réparation de la mesure n'est pas une preuve de baisse de chauffe.
- **Navigation — `NavEncre.swift`.** La cible devient un `Button`, avec
  effet pressé lu dans son `ButtonStyle`, à géométrie identique. Son ancre
  publie seulement le cadre ; la fin de visite passe dans l'action du
  bouton. Cela retire le tap prioritaire, le long-press décoratif et le
  tap simultané de visite de cette cible. Le diagnostic conserve les
  événements tap/aller/page/sélection ; le trajet automatique du build 5
  fonctionne sur l'iPhone, avec validation utilisateur encore attendue.
  Le pont UIKit expérimental et ses trois intégrations
  ont été retirés après l'échec 4b.

## Protection thermique automatique — nouveau build

`ProtectionThermique` dans `RythmeEcran.swift` observe l'état iOS dès son
initialisation, puis ses notifications. Dès **thermalState != .nominal**
(donc dès fair, sans attendre serious), elle reprend le groupe testé :
vidéos de fond sur leurs poses, fumée coupée, galets posés, vie Route au
repos et lentilles natives Home remplacées par le rendu du témoin sans verre.
Au retour nominal, l'ambiance doit se réarmer. Les portes de protection ne
désactivent aucun geste dans le code. La navigation automatique fonctionne
après le correctif séparé du build 5 ; le dernier verdict utilisateur reste
KO en attente d'un nouvel essai au doigt. `-sansProtectionThermique` sert de
témoin explicite.

Piste vidéo non appliquée : l'audit des assets relève deux vidéos distinctes
à 24 images/s et 35,79 s, 1206 × 964 et 604 × 642, soit 37,21 millions
de pixels vidéo/s. Une première vidéo à 804 × 644 réduirait ce total
théorique de 41,6 %, avec un risque de netteté. Aucun asset n'a été modifié,
aucun gain énergétique n'est mesuré ; ce n'est pas le correctif livré.

La porte est étendue au Foyer et à `BraisesVague` pour les braises du grand
Player. Cette extension n'a pas été mesurée par l'essai Home sans séance.
La Home noire d'entraînement voulue par Kathryn garde son rôle ; les décors
sont calmés par la température, sans supprimer le parcours sportif.

**Écart de dessin déclaré :** lorsque le téléphone chauffe, l'ambiance
s'immobilise et les lentilles natives se retirent comme dans le groupe
manuellement testé. Ce filet réagit à la température ; il ne prouve pas que
l'ambiance nominale ne la fera plus monter. Mesures automatiques du build 3,
avec **le seul `-sondeVol`**, thermique 2 et protection active :

| Source | Échantillons | Callbacks/s médiane | Pire intervalle médian / maximal, ms | CPU médian |
|---|---:|---:|---:|---:|
| `protection-automatique.verdict`, premier relevé | 18 | 60,1 | 17 / 17 | 12 % |
| `protection-automatique-parcours.verdict`, même lancement prolongé | 37 | 60,1 | 17 / 83 | 12 % |
| `protection-relance.verdict`, après relance à 16:57:29 | 267 | 60,1 | 17 / 72 | 12 % |

Les deux premières lignes se recouvrent : elles ne sont pas indépendantes.
La relance retient t15 → t285 s, environ 4 min 30, après les 15 premières
secondes de lancement. Les tics instrumentés de cette fenêtre
restent nuls et `protection=1`. Le retour au nominal n'est pas observé.
À ce stade du build 3, le verdict de navigation reste KO malgré cette cadence
régulière ; la preuve de navigation du build 5 est distincte, ci-dessous.

## QA et validations

Après `-openTab profile` à 16:32:13, Kathryn confirme que **Profil et
Réglages fonctionnent**. Le trajet Home → Profil est ensuite exécuté par
XCTest sur le build 5 ; le parcours complet onboarding → quitter/réouvrir →
suppression et la validation au doigt par Kathryn restent à rejouer.
QA 04 et QA 07 restent KO,
leurs paroles et verdicts backend sont conservés dans `docs/site/content/qa.ts`.

**Navigation, build 4b — expérience antérieure non concluante.** Build Release réussi,
installé à 17:27:51, lancé à 17:27:54 avec `-sondeVol -navProbe
-navSystemeVivante`. `NavDiagnostic.swift` journalise la chaîne appui → tap
→ `aller` → page → sélection, les gardes et, une fois par seconde via la
sonde, les cibles UIKit aux trois centres de navigation. Le hit-test sans
événement est une cible théorique ; seuls les callbacks du même toucher
peuvent démontrer le recognizer qui l'a reçu.

`BarreSystemeMuette.swift` était intégré dans les trois onglets du châssis.
Il retrouve publiquement le `UITabBarController`, masque sa barre native
et retire son interaction et ses éléments d'accessibilité. Aucun moteur
périodique ni recherche de classe privée. `-navSystemeVivante` désactive
ce pont pour le témoin ; une relance sans ce drapeau permet la comparaison.
Le précédent du 13-09 justifie cette piste, **pas sa responsabilité dans
le blocage actuel**. Le build avec pont actif est relancé à 17:29:55.
Premiers journaux lus :

- `nav-systeme-temoin.jsonl` ne couvre que **1 s / 2 lignes** : barre
  déjà cachée, alpha 0, interaction autorisée ; cible `HostingView` aux
  trois centres. Ce témoin trop court ne permet pas de comparaison causale.
- `nav-systeme-correctif.jsonl` couvre **33,5 s / 34 lignes** : sur les
  33 relevés d'état, barre cachée, alpha 0 et interaction interdite.
  `enVol`/`enSuivi` faux, bande visible, visite fermée. Le pont agit bien
  sur la barre ; aucun événement appui, tap ou `aller` n'est enregistré.
- Aucune cible relevée n'est une UITabBar. Les cibles passent par
  HostingView (21 relevés), verre UIKit (8), CinematicPlayerHost (3),
  PlatformGroupContainer (1). Les changements de hiérarchie évoquent une
  présentation réelle — CinematicPlayer sert notamment Coffre/Story/Bravo —
  sans capture ni contexte modal suffisant pour l'affirmer. Ces cibles
  mélangées ne prouvent pas qu'un seul calque recouvre la Home.

La question utilisateur renvoyée à 17:31 confirme finalement **KO sur 4b** :
rien ne fonctionne selon elle, animations coupées et téléphone toujours chaud.
Le pont natif n'a donc pas de succès tactile observé.

**Preuve : action perdue avant le routage.** Le journal complet
`nav-echec-utilisateur.jsonl` comporte 105 lignes sur 95,4 s, dont
5 appuis et 5 relâchements (2 sur Exercices, 3 sur Profil), **0 tap et
0 `aller`**. À ces instants : gardes `enVol`/`enSuivi` fausses, visite
fermée, bande visible, page et sélection toujours Home. Les durées
appui → relâchement vont de 62 à 114 ms. Le toucher atteint donc la cible
NavEncre, mais son action TapGesture n'arrive jamais ; ni l'accès à la page
Profil ni une garde de routage ne peuvent expliquer ces cinq refus.

Le code du build 5 utilise un bouton unique avec effet pressé par ButtonStyle et
une ancre de visite passive, sans les recognizers Tap/LongPress concurrents.
Il s'agit de corriger l'étage désigné par les logs ; la part respective du
tap de visite et du long-press n'a pas été isolée. Le pont UIKit expérimental
est retiré. Les essais suivants apportent une preuve sur l'appareil.

**Build 5 compilé et installé à 17:39:32.** Sa première tentative de lancement à
17:39:38 est refusée par iOS : appareil verrouillé (`Locked`). Kathryn est
invitée à déverrouiller et ouvrir l'app à 17:40. Les essais réels ont ensuite
pu être exécutés, sans reset ni lancement direct du Profil :

- `nav-build5-test.jsonl` suit le même toucher Profil : appui → tap → `aller`
  → page → sélection `profile`, **89 ms depuis l'appui, 46 ms depuis le tap**.
  Les gardes restent fausses. Le callback perdu dans 4b est bien livré.
- `nav-build5-parcours.jsonl` ajoute les trajets Home → Exercices → Home →
  Profil. Le test appareil ouvre ensuite Réglages et vérifie la présence
  des textes « Se déconnecter » et « Supprimer mon compte » avant d'écrire
  sa capture. **Aucune de ces deux actions n'est tapée.**
- [Profil après navigation](campagnes/2026-09-14-correctif/profil-apres-nav.png)
  est une capture réelle de 17:49, avec Profil, Retour et Réglages visibles.
  Le test de capture seule `testCaptureCurrentScreen` passe en 0,8 s.
  [Réglages après le parcours](campagnes/2026-09-14-correctif/reglages-apres-parcours.png)
  montre le panneau ouvert à 17:51. Le transport XCTest vers l'hôte a été
  perdu lors du parcours, mais le runner sur l'iPhone a continué jusqu'aux
  assertions et à cette écriture. Ce n'est pas un résultat PASS de la suite
  complète ; les traces et captures prouvent les étapes effectivement atteintes.

`build5-navigation-usage.jsonl` contient **96 échantillons Profil, tous en
thermique 2 : CPU médian 38 %, callbacks médian 60,1/s**. Le pire intervalle
médian est 17 ms, maximal 2 000 ms dans cette fenêtre avec interventions
UITest ; ce n'est pas un relevé isolé au repos. La capture à 17:49 montre le
Profil défilé et une sonde à 29 % CPU. Les petites pastilles boosters de la
bannière sont des images, pas des SCNView. Aucun de ces chiffres n'attribue
le coût au seul grand booster ; les boucles des dos vides et le halo hors
écran ont motivé les portes supplémentaires du build 6. Aucune suppression, déconnexion, séance créée ou récompense réclamée
pendant ces essais ; aucun compte réinitialisé. Le retour utilisateur
« inaccessible » demeure conservé, sans nouvelle validation manuelle affirmée.

### Build 6 — essais et fenêtres stables du 15-09

Release installé à **07:18:39**, lancé à **07:18:58**. Les cinq journaux
`test6-*.log` archivés attestent chacun un test PASS, zéro échec :

| Test appareil | Journal | Durée |
|---|---|---:|
| Home → Profil | `test6-home-profil.log` | 3,864 s |
| Profil → Home | `test6-profil-home.log` | 3,737 s |
| Home → Exercices → Home | `test6-exos.log` | 5,150 s |
| Défilement Profil | `test6-scroll.log` | 2,774 s |
| Fermeture de la pop-up de bienvenue | `test6-bienvenue.log` | 3,360 s |

Captures réelles : [Profil au sommet](campagnes/2026-09-14-correctif/woop-profil-build6.png),
[Profil défilé](campagnes/2026-09-14-correctif/woop-profil-scroll6.png),
[Home sans bienvenue](campagnes/2026-09-14-correctif/woop-home-sans-bienvenue6.png).
Ni déconnexion ni suppression n'a été déclenchée pendant ces tests.

Les fenêtres suivantes sont extraites de `build6-parcours.jsonl`, chacune
archivée en JSONL et `.verdict`. Toutes restent en **thermique 2, protection 1,
60,1 callbacks/s médians, pire intervalle médian et maximal 17 ms**, tics nuls.
Elles remplacent le premier relevé court de 23 points publié à chaud.

| Fenêtre / préfixe de fichier | t depuis lancement | n | CPU médian |
|---|---|---:|---:|
| `build6-home-avant-profil` | 15,4–44,8 s | 30 | 16 % |
| `build6-profil-sommet` | 75,3–179,9 s | 104 | 41 % |
| `build6-profil-defile` | 215,4–239,8 s | 25 | 25 % |
| `build6-home-retour` | 280,5–310,9 s | 31 | 16 % |

Au sommet, grand booster et bannière sont visibles ; après défilement, le
contenu et les effets visibles diffèrent. **Ce sont quatre scènes distinctes,
pas un A/B causal** : on ne peut attribuer 41 → 25 % aux seuls correctifs,
ni 16 % à une énergie acceptable. La Home protégée reste régulière avant et
après le Profil ; l'endurance depuis thermique 0 n'a pas été validée.

### Dernier build et limites de la trace CPU

Le build 7 Release compile et est installé à **07:25:57** ; son lancement à
**07:26:46** échoue avec `Locked`. Déverrouillage demandé à Kathryn. Aucun
essai des portes du build 7 n'est donc affirmé. Le build 8 ajoute la source
finale de l'invitation hors écran : **Release compilée à 07:30:34, installation
confirmée de 07:30:43 à 07:30:46** (séquence 4644). L'app a d'abord été laissée
fermée en attendant le déverrouillage ; une capture et la trace Metal ci-dessous
ont ensuite pu être réalisées. Le parcours complet du compte et le verdict
au doigt de Kathryn restent ouverts.

Traçabilité du build 8 : SHA-256 du binaire
`0fe0ce66c40ebbc4afa7e898b2a2b615f61fe016c6bb53423d9a5ea1f7dd81f7` ;
UUID dSYM `382D237C-48A2-3B29-968B-18275EFC9388`, copie conservée à
`/private/tmp/woop-20260915-build8.app.dSYM`. Ce dSYM ne correspond pas à la
trace CPU du build 5 et ne sert pas à la symboliquer.

La trace Metal de référence a été enregistrée mais ne contient aucune ligne
exploitable CPU/GPU : 43 tables exportées, seulement deux lignes Unknown
(thermique et cycle de vie). Elle ne mesure ni attente main ni renderer ni
bridage GPU. Voir `campagnes/2026-09-14-correctif/trace-reference/LECTURE.md`.

Une **autre trace, Time Profiler du build 5 avec Profil + Réglages ouverts**,
est exploitable : 3 829 échantillons Running de poids 1 ms, dont **74,67 %
sur le fil principal**. SwiftUICore, AttributeGraph et libswiftCore représentent
55,93 % du poids main en feuilles ; activité récurrente dans chaque seconde
complète, pas seulement un pic d'ouverture. SceneKit est présent sur plusieurs
workers (8,20 % inclusifs du total), pas seulement son thread nommé renderer.
Ces poids CPU ne mesurent ni attente ni charge GPU. Les fonctions ne sont pas
symboliquées ; pas de nom de vue ou d'observable fautif déduit. Export,
parseur et [analyse détaillée](campagnes/2026-09-14-correctif/trace-profil-cpu/woop-profil-cpu-analysis.md)
sont archivés dans `trace-profil-cpu/`.

### Build 9 : navigation après relance validée par XCTest, chauffe toujours KO

Les pièces légères sont archivées dans `campagnes/2026-09-14-correctif/` :

| Test réel | Résultat | Fin | Journal |
|---|---|---|---|
| Home → Profil | PASS, 3,981 s | 07:47:30 | `test9-home-profil.log` |
| Défilement Profil | PASS, 2,826 s | 07:49:16 | `test9-profil-scroll.log` |
| Relance puis Home → Exercices → Home → Profil → Réglages | PASS, 10,156 s, zéro échec | 08:00:58 | `test9-navigation-relance.log` |

La [capture Réglages du build 9](campagnes/2026-09-14-correctif/woop-reglages9.png)
montre le panneau ouvert. Un essai précédent, `test9-pages-reglages.log`,
échoue à 07:59:22 sur la précondition « app déjà lancée », avant le parcours :
`xctrace --launch` avait terminé l'app à la fin de sa capture. Il est conservé
avec le PASS explicite après relance. Aucune suppression,
déconnexion, séance créée, récompense réclamée ou réinitialisation du compte.

Le brut `woop-build9-parcours.jsonl` est conservé intégralement. **Ne pas
agréger ses états comme une Home ou un Profil au repos unique** : t15–45
correspond à Home recouverte par le panneau START, pas aux widgets ; vers
t74 commence le Profil au sommet, puis t185+ le Profil défilé. La trace
instrumentée de 07:51:09–18 est incluse dans ce dernier état. Hors transitions,
les observations restent autour de **41–44 % CPU au sommet et 22–27 % défilé,
thermique 2**. Le build 9 ne prouve donc pas une baisse de chauffe ; le CPU
bas d'un panneau Home ne doit pas servir de témoin des widgets.

### Nouvelles traces : GPU réel et CPU du Profil défilé

**Metal, build 8, Home avec widgets sous protection, Fair.** L'enregistrement
07:45:18–27 contient cette fois des exécutions GPU et des échanges de surfaces.
L'union Active couvre 32,53 % du temps GPU renseigné ; le travail est surtout
attribué à `backboardd`, qui compose aussi les éléments système. Une surface
reste présentée **1,880 s**, dont une plage GPU Idle continue de **1,708 s** ;
la présentation suivante a 1,793 s de latence CPU→display. **Ce n'est pas une
preuve de GPU saturé ou bridé par la chaleur.** L'origine de ce retard reste
ouverte, et l'instrumentation peut perturber l'exécution. Lire une texture
vidéo ne prouve pas que son lecteur continue de décoder. Rapport et calculs
légers : [analyse Metal build 8](campagnes/2026-09-14-correctif/trace-home-metal-build8/woop-metal8-analysis.md).

**CPU, build 9, Profil défilé, 07:51:09–18.** Après la première seconde du
traceur, 2 356,4 ms de CPU échantillonné : main **57,80 %**, deux AsyncRenderer
SwiftUI **20,15 %**, autres workers **22,05 %**. Des piles d'animation SwiftUI
et un rendu SceneKit existent chaque seconde ; SceneKit représente 10,08 %
inclusifs, sans identifier le propriétaire du SCNView. `SliderObsidienne`
apparaît sous un TimelineView pendant ce Profil ; présence mesurée, cadence
et instance non déduites. SwiftUITracingSupport conserve 7,77 % de poids
inclusif après la première seconde : les pourcentages ne sont pas une nouvelle
mesure d'usage normal. Toutes les lignes sont Running ; le poids inclusif
de `wait_for_lock` n'est pas une durée d'attente. Rapport, symboles et calculs :
[analyse CPU build 9](campagnes/2026-09-14-correctif/trace-profil-cpu-build9/woop-profil9-cpu-analysis.md).
Les traces volumineuses et grands exports restent dans `/private/tmp` ;
leurs chemins d'origine sont documentés, pas copiés dans le dépôt.

**Trace SwiftUI depuis lancement, build 9, 07:57:34,787–07:58:20,904**
(46,116949 s) : lancement direct `-openTab profile`, puis test de défilement
PASS à 07:57:51. Après t25 s, la lecture des updates compte **2 910
AnimatableAttribute de rotation** ; les hiérarchies exactes désignent
`RondAvatar` dans le ScrollView alors que la capture montre le Profil défilé.
Cela identifie ici un producteur d'animation hors écran, sans en mesurer
seul l'énergie. [Hiérarchies](campagnes/2026-09-14-correctif/trace-profil-swiftui-build9/woop-profil9-rotations.txt),
[capture](campagnes/2026-09-14-correctif/trace-profil-swiftui-build9/woop-profil-scroll9-trace.png)
et parseurs sont archivés ; l'XML de 1,2 Go ne l'est pas. Ce lancement direct
ne sert pas de preuve du trajet Home → Profil.

Le build 10 prépare la pause du slider caché, les portes géométriques
avatar/bannière et une sonde des SCNView. L'avatar utilise l'intersection
avec le viewport et `.id(immobile)` sur son seul dessin pour supprimer les
rotations déjà installées. **Installé à 08:08:04**, UUID
`50291601-FF95-3778-9FE4-0461BF55494E`. Le premier `test10-profil-scroll`
est techniquement PASS, mais la capture `woop-profil-scroll10.png` archivée
montre **Welcome Back devant le Profil** : ce test ne prouve aucun défilement.
Les 40–45 % CPU observés décrivent Profil + panneau, grand booster actif,
pas le Profil défilé. Le runner est renforcé pour fermer Later si présent
et vérifier le déplacement de Deux Lunes de plus de 100 pt avant le retest.
Ce **retest passe à 08:10:18,679 en 2,980 s**, zéro échec, dans
`test10-profil-scroll-verifie.log` ; la
[capture vérifiée](campagnes/2026-09-14-correctif/woop-profil-scroll10-verifie.png)
montre les registres défilés sans le panneau. `woop-nav10.jsonl` et
`woop-vol10.jsonl` sont archivés : vers t132, les portes avatar/bannière
sont au repos et le diagnostic relève une seule SCNView 560×700, alpha
cumulé 0, `isPlaying=false`, `rendersContinuously=false`, scène en pause.
Après t160, hors trace mais avec `navProbe` encore actif, CPU autour de
**25–28 %**. Ces états confirment les portes observées, **pas un gain thermique**.
L'analyse de la trace CPU du build 10 est encore en cours.

Le prototype de liserés Core Animation a ensuite été compilé et mesuré dans
le build 11. Il reste **désactivé par défaut**, réservé au drapeau
`-lisereCoreAnimation` ; les résultats ci-dessous ne justifient pas son activation.

### Builds 11/12 : le booster caché rendait malgré les flags de pause

`woop-build11-profil-nav.jsonl` fournit le compteur de fin de rendu de la vue
identifiée `booster`. Cachée, alpha cumulé 0, `isPlaying=false`,
`rendersContinuously=false`, `scenePaused=true`, elle passe de 1 054 à 1 542
rendus en 16,244 s : **environ 30 rendus/s réels**. La lecture des seuls flags
dans le build 10 ne suffisait donc pas à démontrer l'arrêt.

Dans `BoosterLab.swift`, le build 12 détache maintenant `SCNView.scene` pendant
la pause, conserve scène, caméra et `sceneTime`, puis les réattache si la même
scène est toujours celle du coordinateur. Aucun `attach`/`teardown` de scène
ou redémarrage de cérémonie. Installé **08:35:09–25**, lancé **08:35:26** avec
`-sondeVol -navProbe -openTab profile` :

| Vérification réelle | Résultat / preuve |
|---|---|
| Défilement avec assertion de déplacement | PASS **4,728 s**, fin **08:35:43,474**, `test12-profil-scroll.log` |
| Pause, Profil défilé | Compteur **449** inchangé pendant environ **39 s** ; alpha cumulé 0, `scenePaused=null` car `scene=nil` |
| Remontée du Profil | PASS **2,843 s**, fin **08:36:22,901**, `test12-profil-remonte.log` ; booster visible à nouveau |
| Reprise de rendu | Même vue `0x109f02580`, scène `0x109dc7f00`, caméra `0x11076b980` ; compteur repart à environ **30/s** |
| Retour → Home → Exercices → Home → Profil → Réglages | PASS **22,027 s**, fin **08:37:49,175**, `test12-navigation-reglages.log` |

Captures : [Profil défilé](campagnes/2026-09-14-correctif/woop-profil-scroll12.png),
[booster revenu](campagnes/2026-09-14-correctif/woop-profil-reprise12.png),
[Réglages](campagnes/2026-09-14-correctif/woop-reglages12.png). Les paires
`woop-build12-profil-{vol,nav}.jsonl` et `woop-build12-profil-reprise-{vol,nav}.jsonl`
sont archivées. Les dernières 30 s du premier relevé (t20,3–49,7, n30) donnent
**15 % CPU médian, 60,1 callbacks/s, intervalle maximal 17 ms, thermique 2**.
Le Profil au sommet reste autour de **41 % CPU**, avec son booster vivant.
L'arrêt et la reprise de cette instance sont démontrés ; cela ne valide ni
une baisse durable de température ni tout le cycle du compte. Aucune suppression,
déconnexion, séance créée, récompense réclamée ou réinitialisation du compte.

### Prototype de liseré 11 : CPU plus bas, saccades — laissé désactivé

Les trois bruts et [captures A](campagnes/2026-09-14-correctif/woop-lisere11-a.png),
[B](campagnes/2026-09-14-correctif/woop-lisere11-b.png),
[B posé à zéro](campagnes/2026-09-14-correctif/woop-lisere11-native-pose0.png)
sont archivés. Tableau calculé sur les **30 dernières secondes** de chaque
fichier, thermique 2 ; les fenêtres et scènes ne sont pas interchangeables :

| Essai / fichier | t | n | CPU médian | Callbacks/s médians | Intervalle maximal |
|---|---|---:|---:|---:|---:|
| A, `woop-build11-lisere-a-vol.jsonl` | 20,3–49,8 | 30 | 13,5 % | 60,1 | 67 ms |
| B animé, `woop-build11-lisere-b-complet-vol.jsonl` | 469,0–497,9 | 28 | 3 % | 17,5 | 412 ms |
| B `-liserePose 0`, `woop-build11-native-pose0-vol.jsonl` | 21,3–50,7 | 30 | 12 % | 60,1 | 31 ms |

Le B complet après t15 (444 publications) est à 16,6 callbacks/s médians,
maximal 877 ms : le défaut dépasse quatre accrocs isolés. Les **quatre
microhangs de 366,771 à 415,900 ms** appartiennent à la fenêtre System Trace
08:29:18–27. Cette trace mesure effectivement le main bloqué dans les
synchronisations Core Animation / RenderBox : mutex `commit_transaction`
attendant des workers en `waitForCommitId`/SharedSurface, puis attente Mach.
Les mutex corrélés désignent la dépendance, pas le calque fautif ni une
saturation GPU. Les 8,149 s de main Blocked incluent l'attente normale du
runloop et ne sont pas une durée totale de gel. Voir
[l'analyse System Trace](campagnes/2026-09-14-correctif/trace-lisere-system-build11/woop-lisere11-system-analysis.md),
ses parseurs, résultats et relecture runloop archivés. La pose à zéro est
un essai distinct ; elle ne valide pas le prototype animé.

Depuis **08:38:50**, un écran réellement nu sert à laisser refroidir l'appareil :
[capture noire](campagnes/2026-09-14-correctif/woop-ecran-nu12.png),
`woop-build12-ecran-nu-vol.jsonl`. Les dernières 30 s (t59,9–89,3, n30) donnent
**1 % CPU, 60,1 callbacks/s, intervalle usuel 17 ms / maximal 32 ms**, toujours
thermique 2. **Ce n'est pas la Home réparée** ; le contexte nu est distinct.
Le banc 13 sans flou du parent est ensuite mesuré ci-dessous. Le retour utilisateur, le cycle complet
du compte, la vraie séance et l'endurance depuis thermique 0 restent à revalider.


### Build 13 : retirer le flou parent ne résout pas le prototype natif

Build 13 installé à **08:42:51**, UUID
`5EF49BEE-2522-39A6-ADAE-B8AD121A97D8`. Le drapeau de comparaison
`-sansFlouWidgetsParent` retire le flou de `CardsRangee` ; le prototype natif
reste désactivé par défaut. Les deux essais conservent des trous :

| Configuration / journal archivé | Fenêtre après t15 | CPU médian | Callbacks/s médians | Intervalle maximal | Thermique |
|---|---|---:|---:|---:|---|
| Natif référence, `woop-build13-native-reference-vol.jsonl` | t15,1–53,9, n37 | 4 % | 23,7 | 712 ms | 1 |
| Natif sans flou, `woop-build13-native-sans-flou-vol.jsonl` | t15,0–98,1, n77 | 4 % | 23,7 | 649 ms | 1 puis 2 |
| Home par défaut, `woop-build13-default-home-vol.jsonl` | t15,2–77,2, n62 | 13 % | 60,1 | 83 ms | 2 |

Captures [référence](campagnes/2026-09-14-correctif/woop-home13-native-reference.png)
et [sans flou](campagnes/2026-09-14-correctif/woop-home13-native-sans-flou.png)
archivées. La Home par défaut est rétablie à **08:45:44** ; la cadence
médiane régulière n'efface pas les trous isolés. Une demande de retour au
doigt est envoyée à 08:47, sans réponse encore intégrée à cet état.
Le candidat d'images SwiftUI est ensuite mesuré dans le build 14 ci-dessous.

L'[audit du booster visible](campagnes/2026-09-14-correctif/woop-booster-idle-visible-audit.md)
reste une piste de source, sans prototype ni gain mesuré. Les deux géométries
soumettent 41 616 triangles ; une partition par la frontière UV fixe,
conservant tous les triangles de couture et les bounds, pourrait ramener
ce nombre à 21 150 (−49,2 %). Une éventuelle application commencerait par le
géant non interactif : les hit tests des scènes interactives doivent être
vérifiés séparément. Réduire la densité de pixels est une autre hypothèse,
avec risque de netteté. Aucune de ces propositions ne démontre une baisse
proportionnelle de CPU ni une résolution de la chauffe.


### Build 14 : images de liseré et pièce figée, sans gain net établi

Build 14 installé à **08:52:33**, UUID
`2839D489-93F4-34A2-B62E-21AD8B19A50E`. La variante `-lisereImages` conserve
un cache de trois `CGImage` par instance, avec les rotations et l'opacité de
pression animées par SwiftUI. Le rendu de référence reste le défaut.
La [capture de la variante](campagnes/2026-09-14-correctif/woop-home14-images.png)
est archivée ; il n'y a ni comparaison précise de pixels ni test de pression
validant cette variante. Elle reste expérimentale et activable par drapeau.

Les fenêtres suivantes couvrent chacune les **30 dernières secondes de son
relevé**, n30 et thermique 2 dans les quatre cas. Les journaux et leurs
petits fichiers de provenance sont archivés :

| Configuration / journal | t depuis lancement | CPU médian | Callbacks/s médians | Intervalle maximal |
|---|---|---:|---:|---:|
| Images, `woop-build14-images-home-vol.jsonl`, lancement 08:52:48 | 65,2–94,6 | 12 % | 58,15 | 83 ms |
| Référence, `woop-build14-default-home-vol.jsonl`, lancement 08:54:23 | 77,2–106,7 | 12 % | 60,1 | 100 ms |
| Home, pièce figée, `woop-build14-sans-piece-vol.jsonl` | 57,9–87,4 | 11 % | 60,1 | 17 ms |
| Profil défilé, même essai, `woop-build14-sans-piece-profil-vol.jsonl` | 157,5–186,9 | 15 % | 60,1 | 17 ms |

La comparaison images/référence **ne montre pas de gain net** : même CPU
médian, trous dans les deux relevés. `-sansPiece` fige `MoonCoinView` ; il ne
supprime pas la vue. La [Home de cet essai](campagnes/2026-09-14-correctif/woop-home14-sans-piece.png)
est archivée. Le passage Home → Profil passe à **08:57:45,434 en 3,907 s**
(`test14-sans-piece-vers-profil.log`), puis le défilement réellement vérifié
à **08:58:04,105 en 3,089 s** (`test14-sans-piece-profil-scroll.log`). Les
tests de préparation Home des trois variantes passent aussi ; ils ne valent
pas validation de leur rendu ou des gestes de pression.

Le second brut sans pièce contient Home, la transition puis Profil : sa
médiane globale mélangerait ces scènes. Les 15 % du Profil défilé sont
comparables en ordre de grandeur au build 12 ; cette isolation ne désigne
pas un responsable de la chauffe et ne démontre pas de gain net.

La relance de **08:59:19** affiche encore **Welcome Back devant le fond
noir** : la [capture initiale](campagnes/2026-09-14-correctif/woop-refroidissement14.png)
l'atteste. Les 19–24 % CPU observés alors ne décrivent pas un écran nu ;
les dernières 30 s du premier relevé `woop-build14-refroidissement-vol.jsonl`
(t56,8–86,3, n30) donnent 19 % CPU médian, 60,1 callbacks/s et un intervalle
maximal de 59 ms, thermique 2.

`test14-nu-verifie.log` passe à **09:02:06,694 en 1,698 s** : tap Later,
vérification de sa disparition et de l'absence des boutons `person` et
`Réglages`, puis [capture du noir vérifié](campagnes/2026-09-14-correctif/woop-ecran-nu14-verifie.png).
Le refroidissement sur écran effectivement nu commence **après cette fermeture**.
Le journal prolongé `woop-build14-refroidissement-verifie-vol.jsonl` contient
aussi la phase précédente avec panneau : seules ses dernières 30 s
(t184,7–214,2, n30) donnent ici **1 % CPU, 60,1 callbacks/s, intervalle maximal
17 ms, toujours thermique 2**. Ce n'est ni la Home ni une preuve de baisse
de température déjà obtenue.

Le relevé est ensuite prolongé jusqu'à t387,7, lu à **09:05:47** : le
retour à **thermique 0** apparaît à t328,8. La copie prolongée est archivée
séparément dans `woop-build14-refroidissement-nominal-vol.jsonl` pour conserver
la précédente. Ses dernières 30 s (t358,2–387,7, n30) donnent **1 % CPU,
60,1 callbacks/s, intervalle maximal 17 ms, thermique 0 / protection 0**.
L'appareil est donc bien revenu à l'état nominal avant l'essai Home du
build 15. Cela valide le contexte de départ de cet essai, pas la Home.

### Build 15 : saccades de la Home mesurées dès l'état thermique nominal

Build 15 installé de **09:06:21 à 09:06:34**, lancé à **09:06:34** avec
`-sondeVol -navProbe -openTab home`, **sans drapeau de variante visuelle**.
UUID `E920CC76-B491-333E-95B1-A22CD0EB1C28`. La préparation de la Home passe
à **09:06:42,628 en 5,099 s** (`test15-home-froid.log`) ; la
[capture de la vraie Home](campagnes/2026-09-14-correctif/woop-home15-froid.png)
est archivée avec `woop-build15-home-froid-{vol,nav}.jsonl` et leur provenance.
Ce test de préparation n'est pas le parcours de navigation complet.

Le seul changement applicatif du build 15 ajoute à MoonCoin le cycle de vie
de son propre hôte : son TimelineView se met en pause quand l'onglet est
caché ou la scène inactive, et la vue cesse alors de lire `SkyMotion.tilt`
pour éviter de rester abonnée au gyroscope. Les pièces des coffres et
cérémonies suivent leur propre hôte. Le dessin, les cadences et les gestes
visibles sont conservés ; `navProbe` ajoute un témoin `piece-repos`.
Cette correction ne constitue pas une mesure de gain énergétique.

| Fenêtre Home réelle | n | CPU médian | Callbacks/s médians | Intervalle maximal | Thermique / protection |
|---|---:|---:|---:|---:|---|
| t15,5–47,5, ambiance active | 32 | 12,5 % | 29,3 | 905 ms | 0 / 0 |
| t49,5–211,9, après activation de la protection | 161 | 13 % | 60,1 | 67 ms | 1 / 1 |

À l'état nominal, les publications vont de **14 à 41,8 callbacks/s** :
l'essai d'endurance de la Home normale échoue avant toute alerte thermique.
Le passage à thermique 1 / protection 1 arrive à **t48,5** ; ce point de
transition donne 33,5 callbacks/s et 140 ms, puis la fenêtre protégée
retrouve une cadence médiane régulière. Ses dernières 30 s
(t182,5–211,9, n30) restent à 13 % CPU, 60,1 callbacks/s, max 67 ms.

**Le bridage par la chaleur ne peut donc pas expliquer à lui seul le défaut.**
Les mesures distinguent le défaut avant l'alerte, la protection qui modifie
la scène, et les trous résiduels ; elles ne prouvent ni saturation GPU ni
cause unique. La charge CPU lissée de la sonde n'est pas l'énergie consommée,
et les callbacks ne sont pas un comptage d'images présentées.

Le parcours du build 15 passe ensuite à **09:15:16,436 en 11,536 s**,
zéro échec (`test15-navigation.log`) : fermeture de Later, **Home → Exercices
→ Home → Profil → Réglages**, présence de « Se déconnecter » et « Supprimer
mon compte » vérifiée sans les activer. La
[capture Réglages](campagnes/2026-09-14-correctif/woop-reglages15.png) et
`woop-build15-navigation-{vol,nav}.jsonl` sont archivés. Ce parcours est une
mesure distincte de l'endurance froide, à thermique 2.

Le témoin `piece-repos` de la pièce d'en-tête, rayon 23, suit effectivement
les changements d'onglet : **false sur Home → true sur Exercices → false
sur Home → true sur Profil**. Cela vérifie la commande de pause transmise
au composant, pas un gain CPU ou énergétique propre à la pièce.

### Trace système 15 : attentes réelles de présentation, sur Home à chaud

La [System Trace de la Home](campagnes/2026-09-14-correctif/trace-home-system-build15/woop-home15-full-system-analysis.md)
est capturée de **09:14:23,305 à 09:14:32,571**, durée 9,265953 s,
PID 17908. Ambiance complète, protection désactivée pour le diagnostic,
sans prototype de liseré natif. La table thermique est **Serious sur toute
la trace** : c'est une autre fenêtre que le lancement nominal de 09:06:34.

Elle confirme sur la Home les attentes Core Animation / RenderBox rencontrées
sur le prototype B11. **Quatre microhangs de 250,706 à 435,976 ms** coïncident
avec les plages où le main ne revient pas en attente d'événements. Les
appels passent par `CAContext.waitForCommitId`, `SharedSurfaceGroup.wait_for_allocations`
et `RBLayer.display`. Dans un cas, le main attend le même mutex qu'un worker
libère après `waitForCommitId` / `prune_removed_locked`.

| Mesure sur cette trace | Valeur |
|---|---:|
| Fenêtre avec états du main attribués | 8,728668 s |
| Main Running | 797,772 ms |
| Main Blocked total, attente normale du runloop comprise | 7,898465 s |
| Union des appels de synchronisation identifiés | 6,119990 s |
| Main explicitement Blocked dans cette union | 6,109582 s |
| Plages runloop hors attente d'événements supérieures à 100 ms | 16, total 3,499373 s |

Les catégories d'appels se recoupent et ne s'additionnent pas ; l'union les
déduplique. Ces piles prouvent des attentes de synchronisation à chaud,
**pas le calque applicatif responsable, le processus distant attendu ou une
saturation GPU**. Le prototype natif n'est pas nécessaire à ce mécanisme.
Les saccades à thermique 0 sont prouvées par un autre journal, sans stacks :
on ne leur attribue pas rétroactivement les piles capturées en Serious.
Rapport, parseurs, petits résultats et table thermique sont archivés dans
`trace-home-system-build15/` ; trace et grands exports restent dans `/private/tmp`.

### Bisection 15 : vidéos, fumée et verre, sans résolution thermique

Toutes ces variantes utilisent **`-sansProtectionThermique` uniquement pour
le diagnostic**. Les mesures ci-dessous sont limitées à **15 ≤ t < 60 s**,
ou à la fin du relevé si elle arrive avant. Elles ne forment pas un benchmark
contrôlé : fenêtres courtes, durées et états thermiques différents. Les cinq
paires `woop-build15-{groupeA,groupeB,fumee-swiftui,fond-pose,sans-fumee}-{vol,nav}.jsonl`
et leurs fichiers de provenance sont archivés.

| Variante | Fenêtre / n | CPU médian | Callbacks/s médians | Intervalle maximal | Thermique |
|---|---|---:|---:|---:|---|
| Groupe A : `-fondPose -sansFumeeInvite -sansVerreHome` | t15,3–38,6 / 24 | 17 % | 60,1 | 71 ms | 2 |
| Groupe B : `-fondPose -sansFumeeInvite` | t15,3–39,7 / 25 | 17 % | 58,1 | 50 ms | 2 |
| Fumée SwiftUI : `-fumeeSwiftUI` | t15,3–32,1 / 10 | 0 % | 3,9 | 2 000 ms | 2 |
| Fond posé seul : `-fondPose` | t15,4–59,2 / 44 | 20,5 % | 48,3 | 140 ms | 2 |
| Sans fumée seule : `-sansFumeeInvite` | t15,0–45,5 / 31 | 16 % | 42,4 | 156 ms | 0 puis 1 |

La vraie Home est préparée et vérifiée par `testHomePretePourMesure` pour
chaque variante : `test15-groupA.log` PASS 3,852 s à 09:16:31,806 ;
`test15-groupB.log` PASS 3,758 s à 09:17:11,127 ;
`test15-fumee-swiftui.log` PASS 4,513 s à 09:17:57,085 ;
`test15-fond-pose.log` PASS 4,433 s à 09:18:26,392 ;
`test15-sans-fumee.log` PASS 3,235 s à 09:58:27,229. Ces PASS de préparation
ne valident pas la fluidité des variantes.

Le brut fond posé contient ensuite une interruption majeure : après t61,3,
les publications passent notamment par t165,6 puis t2159,9. **Toute la
partie après 60 s est exclue de cette comparaison** ; ce trou n'est pas
présenté comme un gel continu de la Home au premier plan. Le brut complet
reste conservé pour que l'exclusion soit vérifiable.

Les grands blocages disparaissent dans les courtes fenêtres A/B, tandis
que les variantes isolées ne retrouvent pas une cadence régulière. La
fumée SwiftUI reste particulièrement bloquée malgré un CPU lissé proche
de zéro. Ces observations orientent la bisection, sans désigner un effet
unique ni démontrer une baisse durable de température. La variante sans
fumée commence à thermique 0 puis passe à 1 ; elle n'est pas directement
comparable aux autres à thermique 2.

L'app est remise en configuration normale à **09:59:05**, avant les essais
sans sonde puis le build 16 décrits ci-dessous.

### Home 15 sans SondeVol : les attentes persistent

La [contre-épreuve sans SondeVol](campagnes/2026-09-14-correctif/trace-home-sans-sonde-build15/woop-home15-sans-sonde-system-analysis.md)
est enregistrée de **10:02:50,925 à 10:03:00,175**, durée 9,250295 s,
PID 18446. Arguments : `-sansSondeVol -openTab home -sansProtectionThermique`,
sans `-navProbe` ni `-fps`. La Home est préparée et vérifiée par
`test15-sans-sonde.log`, PASS **6,877 s à 10:02:37,232**. Thermique **Fair
pendant toute la trace** ; ce n'est pas un A/B quantitatif contrôlé avec la
capture précédente en Serious.

Le main attend encore dans `waitForCommitId → SharedSurfaceGroup.wait_for_allocations
→ add_subsurface → RBLayer.display → commit_transaction`. L'union des
synchronisations identifiées couvre **5,476660 s**, dont **5,463563 s où le
main est explicitement Blocked**, sur 8,777865 s attribuées. Un microhang de
**306,643792 ms** porte cette chaîne. Le Blocked total, 7,838167 s, inclut
également les attentes normales d'événements.

**Le CADisplayLink de SondeVol n'est pas nécessaire à ce mécanisme.** Cette
contre-épreuve n'en mesure pas l'influence marginale : captures successives,
états thermiques différents et System Trace toujours attaché. Aucun chiffre
de callbacks/s n'est fourni sans la sonde, aucune attribution à un calque
précis ou à une saturation GPU. Rapport, parseurs et petits résultats sont
archivés dans `trace-home-sans-sonde-build15/` ; grands XML et trace restent
dans `/private/tmp`.

### Build 16 : couche vidéo racine, essai négatif conservé sous drapeau

Build 16 Release compilé avec succès (`woop-chauffe-build16.log`) et installé
avec succès, opération démarrée à **10:03:27** (`woop-install16.log`). UUID
`A9B39E7C-B942-366E-805A-0850DF795E28`. Le drapeau `-fondCoucheRacine` essaie
un `AVPlayerLayer` racine pour **les seuls deux lecteurs du fond Home**
(flamme et pilule). Les autres lecteurs et le rendu par défaut sont conservés.
Ce changement de structure ne retire ni le mélange ni le verre SwiftUI.

Les deux Home sont réellement préparées : `test16-racine2.log` PASS
**6,346 s à 10:04:41,996** ; `test16-reference2.log` PASS **3,877 s à
10:05:27,867**. Captures [racine](campagnes/2026-09-14-correctif/woop-home16-racine2.png)
et [référence](campagnes/2026-09-14-correctif/woop-home16-reference2.png),
paires `woop-build16-{racine2,reference2}-{vol,nav}.jsonl` et provenance
archivées. La protection est désactivée pour ces deux comparaisons,
thermique 2 dans toutes les publications retenues :

| Variante | Fenêtre après t15 / n | CPU médian | Callbacks/s médians | Intervalle maximal |
|---|---|---:|---:|---:|
| Couche racine, lancement 10:04:32 | t15,7–44,9 / 27 | 10 % | 27 | 1 199 ms |
| Référence, lancement 10:05:19 | t15,8–45,3 / 29 | 12 % | 31 | 653 ms |

**L'essai ne résout pas les saccades** et ne justifie pas l'activation par
défaut. La petite différence de CPU ne constitue pas un gain utile établi
avec de tels retards de callbacks. Les PASS de préparation prouvent l'écran
affiché, pas sa fluidité.

La protection est réactivée à **10:06:05**. Le test suivant
`test16-normal2.log` ne démarre aucun cas : à **10:06:38**, le lancement du
**runner XCTest** est refusé car son certificat développeur n'est pas
reconnu comme fiable. C'est une limite de validation de ce test, pas un
échec d'assertion ni une preuve de panne de l'app. L'app est fermée à
**10:07:12** pour laisser refroidir le téléphone.

### Build 17 : prototype vidéo Metal, grands gels réduits mais chauffe ouverte

Build 17 Release installé avec succès, opération démarrée à **10:20:18**,
UUID `1CB3019A-05CC-3A55-9863-E4E6E511A893`. Le compositeur des deux vidéos
Home est **expérimental, activé uniquement par `-fondMetal` et désactivé par
défaut**. Il ne constitue pas encore une résolution générale de la chauffe.
Les preuves de cette section sont archivées dans `fond-metal-build17/`.

La [première comparaison](campagnes/2026-09-14-correctif/fond-metal-build17/woop-build17-metal-analysis.md)
concerne Metal lancé à **10:20:45**, puis la référence AVPlayerLayer à
**10:21:31**, protection désactivée pour le diagnostic. Les vraies Home sont
préparées par les tests `test17-metal.log` (PASS 3,894 s) et
`test17-reference.log` (PASS 4,520 s), avec captures
[Metal](campagnes/2026-09-14-correctif/fond-metal-build17/woop-home17-metal.png)
et [référence](campagnes/2026-09-14-correctif/fond-metal-build17/woop-home17-reference.png).
Fenêtres limitées à **15 ≤ t ≤ 45 s** :

| Première comparaison | Fenêtre / n | CPU médian | Callbacks/s médians | Intervalle maximal | Thermique |
|---|---|---:|---:|---:|---|
| Metal | t15,6–44,0 / 29 | 27 % | 56,6 | 161 ms | 1 |
| Référence | t15,5–45,0 / 19 | 2 % | 8,1 | >2 000 ms, valeur plafonnée | 2 |

La référence contient quatre publications `gel=1` : `pire` plafonné à
2 000 ms ne borne pas le trou réel. Son CPU bas ne prouve pas une meilleure
efficacité. Les états thermiques diffèrent ; cette paire ne démontre ni un
gain énergétique ni une causalité exclusive du moteur de rendu.

Les diagnostics montrent que Metal utilise les buffers **des deux vidéos**,
604×642 et 1206×964, avec un drawable 1179×1980. Une pause commune des hôtes
d'environ huit secondes dans la première capture empêche d'en déduire la
boucle vidéo : elle n'est pas attribuée au décodeur. Les captures statiques
ne valident ni les couleurs précisément ni l'animation.

### Build 17 : lecture prolongée, deux boucles et trois cadences distinctes

La [lecture prolongée](campagnes/2026-09-14-correctif/fond-metal-build17/woop-build17-metal-long-analysis.md)
est lancée à **10:29:27**, PID 18831. Les deux flux franchissent chacun deux
retours de timestamp correspondant à leur durée de 35,791667 s, autour de
+35,6→40,6 s puis +70,7→75,8 s. Les compteurs de buffers et de commandes GPU
continuent à augmenter ; les 19 diagnostics indiquent `deuxVideos=true`,
sans retour au poster observé. Cela prouve le franchissement des boucles,
**pas un raccord visuellement parfait ni l'absence d'image répétée/perdue**.

Avant la capture Time Profiler, fenêtre Sonde **15–65 s**, n49 :
**50,4 callbacks/s médians, CPU médian 24 %, intervalle maximal 154 ms,
thermique 2 / protection 0**, aucun `gel=1`. Les longs gels de la référence
précédente ne réapparaissent donc pas dans cette fenêtre, cette fois au même
niveau thermique catégoriel 2. Ce sont néanmoins deux exécutions successives,
sans garantie du même état physique ou GPU, et les 60 callbacks/s ne sont
pas atteints.

Sur +15,442→85,773 s, les diagnostics donnent environ **27,43 commandes GPU
terminées/s**, **21,03 nouveaux buffers braise/s** et **20,99 pilule/s**, pour
des sources à 24 images/s. Une completion confirme l'exécution du command
buffer utilisant ces textures, pas sa présentation. Les événements Nav sont
publiés sur le main et peuvent être retardés. Ces estimations de débit,
la cadence source et les callbacks Sonde sont trois métriques distinctes ;
le prototype ne restitue pas intégralement la cadence source dans ce banc.
Ni puissance électrique, ni baisse durable de température n'est démontrée.

### Traces et navigation 17 : limites de collecte conservées

La [System Trace 17](campagnes/2026-09-14-correctif/fond-metal-build17/woop-metal17-system-analysis.md)
a été interrompue par un timeout de 50 s pendant sa sauvegarde, après une
capture demandée de 8 s. L'export échoue code 10 : paquet malformé, données
d'instrument manquantes. **Aucune table ni comparaison d'attentes CA/RenderBox
17 contre 15 n'est exploitable**. Les 50 s ne sont pas une durée de gel
mesurée dans l'app. Le Time Profiler de 10:30:36,479–10:30:45,726 a réussi ;
son analyse CPU est séparée et ne mesure pas les attentes.

`test17-metal-navigation3.log` atteint réellement Exercices, Profil et
Réglages, puis valide la présence de « Se déconnecter » et « Supprimer mon
compte » sans les activer. Le journal s'arrête ensuite pendant les dumps
redondants de hiérarchie d'accessibilité (t9,41 puis t21,16) avant verdict
final : **ce test n'est pas déclaré PASS complet**. Le runner est corrigé
en retirant ce dump superflu, sans modification de l'app ; son nouvel essai
reste à venir à ce stade.

Le rendu normal est restauré à **10:32:03** ; la préparation réelle Home
passe ensuite en **3,611 s à 10:32:16,857** (`test17-normal-apres-cpu.log`).
Le prototype demeure désactivé par défaut. Aucune suppression, déconnexion,
séance créée, récompense réclamée ou réinitialisation du compte. Aucun
nouveau retour au doigt n'est arrivé à la demande de 08:47. **QA 04/07 et
la chauffe restent KO.** Les sources sont actualisées, sans génération
d'artefact final.

`CLAUDE.md` et les sections de référence du skill performance ont été
rectifiés : **27–39 % décrit le défaut, pas une norme acceptable** ; CPU,
cadence et énergie ne se confondent pas, et le panneau réellement affiché
doit accompagner l'onglet de la sonde.

Analyses syntaxiques Swift et contrôles de diff réalisés. La session
principale a installé le **troisième build Release à 16:56:13**, avec
protection thermique, puis l'a lancé à 16:56:35 avec le seul `-sondeVol`.
La mesure prolongée est lue ci-dessus ; à ce stade du build 3, le retour
utilisateur signalait toujours les deux onglets inaccessibles depuis la Home.
Les preuves automatiques des builds suivants sont distinctes de ce retour.
Le livrable `docs/site/index.html` a été régénéré le 15-09 vers 07:33 avec
les preuves de navigation, les limites thermiques et l'installation du build 8.
`npm run artefact`, puis `npm run verif` réussissent : 23 tests, types,
reconstruction identique octet pour octet, captures générées 390/1440 et
10 pages sans débordement à 390 px. Livrable : **1 834 353 octets**.
Journaux : `/private/tmp/woop-chauffe-doc8-artefact.log` et
`/private/tmp/woop-chauffe-doc8-verif.log`.
Cet artefact précède les résultats des builds 9 à 17 et leurs analyses ; les
sources documentaires sont mises à jour, sans nouvelle génération dans cet audit.
Ces contrôles documentaires ne valident pas les gestes iPhone.

Test de logique `CouvertureFoyer` communiqué par la session principale :
15 assertions sur 8 scénarios passent dans une copie temporaire sans les
attributs Observation. Il valide les transitions logiques testées, pas la
macro, le graphe SwiftUI ni l'intégration Player. Les premières tentatives
UITest avaient été bloquées par la signature en sandbox puis une approbation
interrompue ; le runner a ensuite réellement exécuté les taps et captures
du build 5 décrits ci-dessus. La perte de transport limite le verdict de
suite, pas l'existence des étapes attestées sur l'appareil.
Aucune publication au lien Claude : outil indisponible. Aucun commit.

À revalider : protection activée sur téléphone chaud, réarmement au retour
nominal, endurance depuis thermique 0, navigation au doigt, puis vraie séance
et grand Player. Rapport complémentaire : `AUDIT-NAV-COMPTE-2026-09-14.md`.

## Reprise du 15-09, 11 h : résultat utilisateur toujours KO

Kathryn rapporte de nouveau que le téléphone chauffe et que la QA reste
inutilisable. Le travail n'est pas déclaré terminé. La synthèse des étapes
QA04/07 est raccourcie dans le site ; les preuves historiques restent ici.

La [capture CPU17](campagnes/2026-09-14-correctif/fond-metal-build17/woop-metal17-cpu-analysis.md)
attribue 1118 des 2291 échantillons Running à SwiftUICore, dont 658 à
DisplayList.ViewUpdater.render. Le renderer vidéo apparaît dans281,
la fumée dans37 ; ces catégories sont inclusives et se chevauchent.
Les 134 échantillons sous copyPixelBuffer ne prouvent pas un coût de
conversion BGRA. Cette trace ne mesure ni le GPU ni la puissance.

### Essai combiné17, transport interrompu

Après un premier refus de lancement dû au verrouillage (11:01), le banc
`-fondMetal -lisereCoreAnimation -sansProtectionThermique` est lancé à11:10:51.
La préparation de la vraie Home passe à11:11:18 (6,040s). Sa capture montre
un compte avec une séance affichée, pas une Home vierge après onboarding.
Le HUD y affiche ponctuellement9 callbacks/s,734ms,CPU2%,thermique2 :
cette image n'est ni une médiane ni une preuve de gain énergétique.
Le transport se coupe avant la récupération JSONL ; le témoin prévu
n'est pas lancé. Aucun verdict de performance complet ni validation
de chauffe pour cette combinaison ; ne pas l'activer par défaut.

La restauration `-sansSondeVol` échoue aussi, erreur CoreDevice1011.
Le téléphone n'a donc pas été confirmé revenu aux réglages normaux après
cet essai. Kathryn est invitée à fermer Woop. À la reconnexion : récupérer
le journal, relancer sans variantes avec `-sansSondeVol`, puis contrôler
la navigation. La sonde peut aussi être arrêtée par un maintien1,2s sur
ses chiffres ; cela n'enlève pas les arguments expérimentaux du process.

### Card Route cachée : correction de cycle de vie

Lecture de CardRoute.swift : le fond liquide, le liseré tournant, la lampe,
le halo, le chevron et les boucles de reflet/onde armaient leurs animations
dans une `.task` sans porte d'onglet ou de scène. La fermeture de l'onglet
ne démonte pas la card conservée par TabView.

Le modificateur ReposAmbianceRoute transmet maintenant une pause aux seules
feuilles décoratives et change leur identité à l'entrée/sortie de pause,
afin de retirer aussi les repeatForever. La card et la bande défilante
conservent leur identité. Les scènes inactives, la Home couverte et la
protection thermique ferment la même porte ; au retour, les animations
repartent. Les dessins, amplitudes et durées visibles sont conservés.
Ce correctif n'est pas une preuve de baisse de chauffe sur la Home visible.
Compilation Release18 en cours à ce stade, effet appareil non mesuré.


## 15-09, 11:24 : navigation confirmée par Kathryn, chauffe persistante

**Le verdict au doigt a changé : « Navigation possible, mais le téléphone
chauffe encore ».** Le build 18 Release est installé à 11:18:18 et le parcours
Home → Exercices → Home → Profil → Réglages passe automatiquement en 8,671 s à
11:20:02. [Preuves et comparaison des liserés](campagnes/2026-09-14-correctif/route-sommeil-build18/resultats18.md).
La capture montre Kathryn, K, @kathryn, Level 1 et les deux actions de compte.
QA07 valide cet accès ; QA04 reste KO. Aucune suppression ou déconnexion n'a été
exécutée. Le cycle complet de compte n'est pas validé par ce parcours.

Le journal exact du banc combiné 17 a depuis été récupéré :
[essai-combine-17.md](campagnes/2026-09-14-correctif/fond-metal-build17/essai-combine-17.md).
Il confirme de longs retards, sans gain énergétique démontré. La restauration
normale qui avait échoué à 11:12 a effectivement réussi à 11:19:28, après
l'installation 18. Les prototypes restent désactivés par défaut.

Le banc liserés posés / actifs du build 18 donne respectivement 13 / 14 % CPU
et 60,1 / 60,1 callbacks/s médians en thermique 1, protection active. La fenêtre
commune exclut le passage au Profil. Différence trop faible pour conclure sur
la chauffe ; aucun changement de dessin retenu sur cette base.


### Retour complémentaire et piste vidéo simple

Kathryn précise ensuite « mais c'est un peu moins chaud », tout en jugeant
l'investigation trop complexe. La chauffe reste ouverte : ce ressenti indique
une amélioration, pas une validation durable. Elle demande expressément de
chercher une solution par vidéo précalculée plutôt que d'accumuler du rendu codé.

Les deux sources du fond ont 859 images, 35,791667 s, 24 i/s. Un fichier de
comparaison les additionne en RGB sur le Mac et intègre le scrim. Il est destiné
au slot 393 × 660 pt observé sur cet iPhone, en résolution 2× (786 × 1320).
Même durée et cadence ; la pilule passe de ~3× à 2×, la braise est rééchantillonnée.
La couleur et la netteté doivent être vues sur l'appareil ; ce n'est pas encore
une preuve d'équivalence visuelle ou de gain énergétique. Autres dimensions,
fondu d'arrivée et départ de séance doivent conserver leurs ancrages séparés.
Le script reproductible est `tools/perf/precomposer_fond_home.py`.


## Dernier état du 15-09 vers 13:30 : build 22 prêt, téléphone indisponible

[État du build 22 et vérifications](campagnes/2026-09-14-correctif/protection-bornee-build22/etat.md).
Compilation Release et signatures valides. Installation non effectuée : dernier
état de découverte unavailable. Le build 21 reste installé, son gain de chauffe
non validé. Fermer complètement puis rouvrir Woop rend ses arguments normaux ;
le retour protégé distant n'a pas été confirmé après la coupure.

L'expiration automatique du diagnostic sans protection à 60 s est dans le
build 22 prêt à poser. La documentation locale a été générée et vérifiée,
QA04 reste KO et QA07 conserve la confirmation manuelle du build 18. La
publication au lien Claude demeure indisponible, aucun commit effectué.
