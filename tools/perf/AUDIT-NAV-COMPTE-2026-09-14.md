# Audit navigation compte et limites de SondeVol — 14 septembre 2026

**À lire avant de reprendre : [registre des échecs et mesures invalides](ECHECS-CHAUFFE-HOME.md).**

Lecture du working tree, sans réinitialisation ni suppression de compte.
Les builds et essais appareil sont conduits par la session principale ;
leurs traces et captures sont intégrées ci-dessous. Références lues :
`CLAUDE.md`, `MULTI-SESSION.md`, skill
performance, skill Supabase et documentation `serveur.ts`, `briques.ts`,
`mesures.ts`, `qa.ts`.

**Actualisation du 15-09, build 18 : Kathryn confirme la navigation possible.**
Le parcours Home → Exercices → Home → Profil → Réglages passe en 8,671 s à
11:20:02. QA07 est validée pour cet accès ; QA04 reste KO, puis Kathryn précise
que le téléphone est un peu moins chaud. Le cycle complet de compte n'est pas
validé. Les paragraphes suivants décrivent les étapes historiques de l'audit.

## Profil / QA 07

Le site conserve son retour positif sur les étapes 1–6, mais QA 04 reste KO
pour le lag et QA 07 bloquée sur téléphone chaud. À la première lecture,
aucun verrou spécifique au profil n'avait été confirmé.
La dégradation mesurée était alors l'explication prioritaire. Les logs ont
ensuite établi une panne distincte de reconnaissance du tap, corrigée par
le bouton du build 5 : le parcours automatique sur l'iPhone atteint
Exercices, Profil et Réglages. Le dernier retour utilisateur « inaccessible »
reste conservé. Le build 12 confirme le parcours automatique et arrête réellement
le booster hors écran (compteur de rendu immobile, puis reprise de la même
scène). Le Profil visible reste coûteux. Le build 15 montre ensuite la Home
saccadée dès thermique 0, avant la protection : l'endurance reste en échec.
Le parcours complet au doigt et le cycle du compte restent à revalider.

- `NavEncre.cible` publie bien `visite-profil` et appelle `NavBande.aller`.
  `WoopApp` relie `NavEtat.page` à la sélection du `TabView`.
- `VisiteHome` laisse un trou tactile autour de l'objet et `visiteAncre`
  termine la visite au tap. Cette lecture ne prouve pas la livraison réelle
  du geste sur l'iPhone.
- Le bouton Réglages du profil monte `ReglagesOverlay`, dont l'alerte appelle
  `Compte.supprimer`. Aucun test de suppression n'a été lancé.

Défauts voisins relevés, laissés hors de ce correctif :

1. `MenuItems.titres` contient Profile / Progress / Exercises, tandis que
   `HomeNuitPage.destinations` ne contient que profile / exercises. Progress
   route donc vers Exercices et la troisième ligne est ignorée. Profile,
   index 0, est correctement mappé. Aucun changement menu conservé.
2. Une session gardée suffit à masquer la porte au lancement
   (`WoopApp.showAuth`). Une interruption après Apple mais avant la fin de
   Nosfy peut donc ouvrir la Home sans onboarding terminé. Ce scénario
   distinct n'a pas été exécuté et ne prouve pas le blocage QA 07.

## SondeVol : ce que les chiffres permettent de dire

`cpu` est la somme des charges récentes des threads Mach, correctement ramenée
en pourcentage d'un cœur. C'est une valeur lissée par l'ordonnanceur, pas un
delta de temps CPU sur la seconde publiée. Elle exclut GPU et autres process.
Le calcul de vieillissement est visible dans
[XNU, retrieve_thread_basic_info](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/thread.c#L1865).

`img` compte les callbacks `CADisplayLink` servis sur le fil principal ; ce
n'est pas un compteur de nouvelles images GPU présentées. `pire` mesure les
écarts entre leurs timestamps. Une chute de cadence avec CPU bas ne prouve
donc pas, seule, « le fil principal attend » ou « le GPU est bridé ». Apple
décrit le lien comme un minuteur synchronisé à l'affichage, dont la cadence
peut dépendre de la politique système :
[CADisplayLink](https://developer.apple.com/documentation/quartzcore/cadisplaylink).

`tics` et `corps` comptent uniquement les sites instrumentés, par intervalle de
publication. L'intervalle peut dépasser une seconde ; plusieurs vues partagent
un groupe. Zéro tic ne garantit ni GPU au repos ni absence d'animation.
`gel=1` signifie seulement un trou supérieur à 2 s ; malgré la pause en
arrière-plan, cela peut aussi être un vrai gel au premier plan.

## Correction de l'instrument

`task_threads` fournit un droit Mach par thread. La sonde libérait le tableau
avec `vm_deallocate`, mais conservait les droits. Reproduction C locale sur
macOS avec `mach_port_get_refs` : trois lectures sans libération des ports font
**3 → 4 → 5 → 6** références ; trois lectures avec libération restent
**6 → 6 → 6**. Cette preuve d'ownership n'est pas une mesure de chauffe iPhone.

`SondeVol.swift` libère désormais chaque port, déclare la taille réelle du
buffer `thread_basic_info`, et inclut `PlayerEtat.couvre` dans le champ
`player`. Commentaires corrigés ; format `tics` et méthode CPU conservés pour
la comparabilité. Validation : analyse syntaxique Swift réussie
(`swiftc -frontend -parse`). Aucun build ni mesure appareil dans cet audit.

## Reprise après l'essai du correctif

Après installation à 16:26:56, Kathryn rapporte encore « Profil toujours
inaccessible » et une Home entière qui chauffe. Mesure communiquée par la
session principale : thermique 2 pendant tout l'échantillon, médiane
27,9 callbacks/s / CPU 13 %, trou maximal 1 819 ms ; tics galets à zéro.
L'arrêt de cette horloge est observé, mais le résultat utilisateur reste KO.
Cette mesure chaude ne se compare pas directement à la référence froide.

Relecture ciblée de la navigation :

- Aucun verrou confirmé dans `NavEtat` → `selection` ; hôtes du départ,
  du stop et du booster sourds lorsque fermés. La visite doit être vérifiée
  par son état réel pour exclure une brume encore montée.
- Un précédent a prouvé une barre native encore hit-testable malgré
  `toolbarVisibility(.hidden)` : `tools/nav/MANGEUR-NAV-RESOLU.md`, dump du
  13-09. Il concernait le premier tap pendant environ 1–2 s ; il n'explique
  pas sans nouvelle preuve un blocage de plusieurs minutes.
- Les glyphes latéraux se dessinent par offsets hors du cadre initial du
  HStack. C'est une piste de géométrie, non une cause confirmée : les
  contentShapes intérieures suivent normalement leur offset. Aucun correctif
  posé sur cette supposition.
- `TirageBooster` monte une scène `BoosterStage` 560×700 à 60 Hz. Sa pause
  dépend du scroll et du Sacre, sans porte d'onglet caché ; `BoosterStage`
  applique uniquement le `paused` reçu. Ce coût mérite une vérification à
  l'ouverture puis au retour Home, sans le confondre avec une perte de tap.

La session principale isole les moteurs restants puis prévoit
`-openTab profile` : même session et vrai onglet du TabView, sans reset ni
suppression. Cela permet de séparer le montage du Profil du trajet tactile.
Ce lancement direct a été effectué à **16:32:13** ; Kathryn confirme ensuite
que **Profil et Réglages fonctionnent**. Cela valide ces écrans accessibles
directement, pas le trajet Home → Profil ni la suppression du compte.
Aucun nouveau changement de navigation ou backend n'a été posé.

La trace Metal de référence a été exportée, mais ses tables CPU/GPU et
événements bruts sont vides ; le thermique y vaut Unknown. Elle ne tranche
ni attente main, ni coût renderer, ni bridage GPU. Voir
`campagnes/2026-09-14-correctif/trace-reference/LECTURE.md`.

### Isolation groupée des effets — verdicts lus

Même appareil, onglet `home`, aucune séance ; catégorie thermique 2 au
départ et sur tous les échantillons retenus des deux fichiers :

| Essai | n | Callbacks/s médiane | Pire intervalle médian / maximal | CPU médian | Tics médians |
|---|---:|---:|---:|---:|---|
| Premier correctif, `apres-premier.jsonl` | 189 | 27,9 | 156 / 1 819 ms | 13 % | `[0,0,0,0,15]` |
| Isolation, `diagnostic-sans-ambiance.jsonl` | 41 | 60,1 | 17 / 17 ms | 13 % | `[0,0,0,0,0]` |

Sources : `campagnes/2026-09-14-correctif/apres-premier.verdict` et
`campagnes/2026-09-14-correctif/diagnostic-sans-ambiance.verdict`, avec les
JSONL correspondants. Drapeaux de l'isolation : `-sansFumeeInvite
-sansSouffleGalets -sansVieRoute -fondPose -sansVerreHome`.

Cette isolation groupée retrouve une cadence régulière malgré la catégorie
thermique 2. Elle resserre l'enquête sur les effets coupés ; elle n'identifie
pas lequel, ni leur éventuelle interaction, et ne mesure toujours pas le
GPU. Le même état thermique catégoriel ne garantit pas les mêmes fréquences
matérielles. Les durées diffèrent et l'ordre n'est pas alterné : ce n'est pas
une campagne A/B thermique validée, ni la preuve d'une baisse de chaleur.
La session principale mesure maintenant les leviers séparément.

### Leviers séparés et coût du profil — avant correction 3D

Verdicts lus dans le même dossier de campagne ; thermique 2 au départ,
en médiane et au maximum :

| Essai | n | Callbacks/s médiane | Pire intervalle médian / maximal | CPU médian |
|---|---:|---:|---:|---:|
| Profil direct, `profil-direct.verdict` | 83 | 60,1 | 17 / 48 ms | 49 % |
| Home sans fumée seule, `sans-fumee.verdict` | 109 | 24,4 | 236 / 1 470 ms | 10 % |
| Home sans souffle galets seul, `sans-souffle-galets.verdict` | 76 | 28,3 | 142 / 1 597 ms | 14 % |

La fumée seule ne suffit pas à rétablir la cadence, le souffle galets seul
non plus. Le profil est régulier, mais son processus consomme environ la
moitié d'un cœur d'après la sonde. Ce chiffre ne ventile pas le coût entre
SwiftUI et SceneKit et ne mesure ni GPU ni énergie.

### Correction du sommeil du booster du profil — à mesurer

`ProfilLune.swift`, `TirageBooster` : les deux scènes 3D suivent maintenant
`ongletCache`, `scenePhase` et le manège ; le géant conserve sa pause au
seuil de disparition par scroll. Le balancement SwiftUI du panneau et la
tâche d'invitation dorment aussi lorsque le profil est caché ou l'app inactive.
Les scènes du profil demandent **30 Hz**, avec `-profil60Hz` pour rejouer
la cadence antérieure. Ce choix réduit la fréquence demandée et garde
l'animation, avec une fluidité 3D à juger ; aucun gain CPU/GPU n'est encore
attribué à cette correction.

`BoosterLab.swift`, pont `BoosterStage` : la pause s'applique dès la création
du SCNView. Elle suspend rendu et scène, les six liens UIKit, le Timer
d'invitation, et rend le crédit CoreMotion seulement s'il était acquis.
La reprise conserve la scène et les intentions d'animation, sans démontage
qui déclencherait la sortie audio du Sacre. Le garde-fou `frozen` du raccord
reste prioritaire. Les autres hôtes gardent leur cadence 60 Hz ; la porte
d'entrée bénéficie de la suspension complète quand elle demandait déjà une
pause. Aucun réglage de matière, lumière, cadrage ni cérémonie modifié.

Validation locale : `swiftc -frontend -parse` des deux fichiers et
`git diff --check` réussis. Ces portes sont compilées dans les builds suivants.
Le build 5 fournit ensuite une mesure d'usage Profil, sans isoler le gain
30/60 Hz ni valider le panneau booster et le retour de la porte d'entrée.
QA 04/07 restent KO tant que le parcours et la chauffe ne sont pas revalidés.

## Navigation encore KO avec protection automatique

Build Release 3 installé à 16:56:13, puis relance à 16:57:29, seul argument
`-sondeVol`. `protection-relance.verdict` retient 267 points entre t15 et
t285 s : médiane 60,1 callbacks/s, intervalle médian 17 / maximal 72 ms,
CPU 12 %, thermique 2, protection active. Kathryn dit encore « La Home
entière reste bloquée » : chiffres de la sonde vivants, animations figées,
destinations Exercices et Profil inaccessibles. Les décors arrêtés sont
prévus par la protection ; la navigation bloquée ne l'est pas. Cette
mesure interdit d'assimiler callbacks réguliers et navigation fonctionnelle.

Relecture ciblée, sans changement de navigation :

- `NavEtat` est un singleton `@Observable`, `page` observée ; le pont du
  châssis lit directement `NavEtat.shared.page`, puis écrit la sélection.
  Les correspondances `exos → exercises` et `profil → profile` et leur
  inverse sont exactes. Aucun changement d'identité TabView lié à la
  protection n'est présent dans cette chaîne.
- `NavBande.aller` refuse seulement un `enVol`/`enSuivi` actif ou la page
  déjà sélectionnée. Les deux flags sont initialement faux ; le vieux
  `NavPanHote` n'est plus instancié dans la production lue. Leur blocage
  après un lancement neuf est moins plausible, sans être mesuré ici.
- La bande de `PageCard` n'est plus rendue : sa porte
  `!PlayerEtat.monte` ne désactive pas la nav racine. Les hôtes Chambre,
  Départ, Stop et Booster ont leur propre porte fermée lorsqu'ils sont
  inactifs. Le rattrapeur Home vit en background du mobilier.
- `NavEncre` associe tap prioritaire, appui long de 10 s pour l'effet
  pressé, et le tap simultané de `VisiteAncre`. Aucune compétition n'est
  démontrée sans traces de gestes. La visite de racine est conditionnée
  par `DepartEtat.visiteOuverte` ; sa poche utilise une forme even-odd.
- La barre UIKit native demeure une piste à vérifier sur la vraie cible,
  surtout maintenant que le refus concerne les deux onglets du bas.
  Le précédent du 13-09 prouve sa présence hit-testable à y769…852,
  mais pas sa présence dans le build courant. Exercices est au centre,
  Profil à droite ; viser seulement les anciens offsets serait trompeur.

La mesure décisive reste la chaîne du même tap : effet pressé → callback
TapGesture → entrée `aller` avec ses flags → `page` → `selection`.
Elle sépare cible recouverte, conflit de recognizers, refus par état et
défaut de routage. La session principale relève l'arbre/runtime ; aucun
correctif de navigation posé sur ces seules hypothèses.

### Build 4b : rendre le prochain toucher observable

Le build Release 4b est installé à 17:27:51 et lancé à 17:27:54 avec
`-sondeVol -navProbe -navSystemeVivante`. Les hooks `NavDiagnostic` suivent
appui, relâchement, tap, entrée `aller`, page et sélection ; la sonde ajoute
les gardes et les cibles UIKit à 1 Hz. Aucun recognizer n'est ajouté.

Le pont `BarreSystemeMuette`, monté dans les trois onglets, est un candidat :
API publique de contenance, masquage de la barre native, interaction et
accessibilité de ce doublon coupées. Le dernier drapeau le neutralise pour
le témoin ; le test suivant le retire. Rien ne prouve encore que la barre
native soit la cible fautive sur ce build, ni que cette correction rende
les onglets accessibles. Succès tactile encore attendu.

Journaux reçus : témoin natif 2 lignes / 1 s, correctif 34 lignes / 33,5 s.
Le pont rend la barre native non interactive sur les 33 relevés d'état ;
elle était déjà cachée et alpha 0 dans le témoin. Les gardes sont fausses,
la bande visible, la visite fermée ; aucun appui/tap/aller n'est enregistré.
Aucun hit-test relevé ne cible la barre. Les cibles et leurs ancêtres
changent (HostingView, verre UIKit, CinematicPlayerHost, groupe de scroll),
compatibles avec une présentation réelle, sans capture ni état modal pour
le confirmer. Le témoin de 1 s et cette hétérogénéité interdisent d'attribuer
la panne, ou sa correction, à la seule barre native. Voir les deux
`nav-systeme-*.jsonl` de la campagne et le rapport principal.

### Échec utilisateur instrumenté : l'action tap n'arrive pas

Le retour du build 4b est KO. `nav-echec-utilisateur.jsonl` étend son
journal à 105 lignes / 95,4 s : **5 appuis + 5 relâchements, 0 tap,
0 aller**, sur Exercices (2) et Profil (3). Gardes fausses, visite fermée,
bande visible et sélection Home pendant ces touches ; durées 62–114 ms.
La cible NavEncre reçoit les touches, mais la chaîne s'arrête avant
TapGesture. C'est désormais la panne concrète à corriger. La navigation
centrale est bien utilisée pour ces cinq touches ; la piste du menu et
son défaut d'indices distinct ne les expliquent pas.

La session principale prépare alors le build 5 : Button et ButtonStyle pressé,
ancre passive pour cette nav, fin de visite portée par son action, retrait
du pont UIKit expérimental. Le long-press et le tap de visite n'ont pas
été isolés séparément ; les essais suivants attestent la nouvelle chaîne
de navigation sur l'appareil.

Le build 5 compile et est installé à 17:39:32. Premier lancement automatique refusé
à 17:39:38 : iPhone verrouillé (`Locked`). Demande de déverrouillage et
d'essai manuel transmise à 17:40 ; validation utilisateur toujours attendue. Le pont
UIKit a été retiré du code final, le diagnostic et le bouton standard
restent. Aucune suppression ni déconnexion, aucun compte réinitialisé.

### Build 5 : parcours automatique effectivement exécuté sur l'iPhone

Les blocages initiaux du runner (signature sandbox, puis approbation
interrompue) ont ensuite été dépassés. Le test appareil a réellement effectué
**Home → Exercices → Home → Profil → Réglages**, sans `-openTab profile`.
Sources dans `campagnes/2026-09-14-correctif/` :

- `nav-build5-test.jsonl` : appui Profil à t811093559,069971, tap à
  t811093559,113457, `aller` à t811093559,113606, sélection `profile` à
  t811093559,159353. **89 ms appui → sélection, 46 ms tap → sélection**.
  La chaîne inclut aussi page et relâchement ; gardes fausses.
- `nav-build5-parcours.jsonl` prolonge ce journal et ajoute les callbacks
  appui/tap/aller/page/sélection sur Exercices, Home puis Profil.
- [Profil après navigation](campagnes/2026-09-14-correctif/profil-apres-nav.png),
  capture réelle de 17:49 : Profil, Retour et Réglages visibles.
  `testCaptureCurrentScreen`, capture seule, passe en 0,8 s.
- [Réglages après parcours](campagnes/2026-09-14-correctif/reglages-apres-parcours.png),
  à 17:51 : panneau ouvert. Le runner n'écrit ce fichier qu'après les
  assertions de présence des textes « Se déconnecter » et « Supprimer mon
  compte ». Il ne touche ni la déconnexion ni la suppression.

Le transport XCTest vers l'hôte a été perdu, mais le runner appareil a
continué et produit cette dernière capture après ses assertions. **La suite
complète n'a pas de verdict PASS** ; les étapes attestées ne sont pas pour
autant des déductions à partir des seuls callbacks de SondeVol. Le nouveau
Button livre réellement les taps qui se perdaient dans 4b, et les captures
prouvent les écrans atteints. Cela ne remplace ni le retour manuel de Kathryn,
ni le parcours onboarding → quitter/réouvrir → supprimer → recommencer.
QA 04/07 restent KO ; aucune nouvelle validation de chauffe affirmée.

### Profil encore coûteux ; portes supplémentaires du build 6

`build5-navigation-usage.jsonl` contient **96 échantillons Profil**, tous en
thermique 2 : **38 % CPU médian, 60,1 callbacks/s**, pire intervalle médian
17 ms et maximal 2 000 ms. La fenêtre inclut des interventions UITest ; elle
n'isole pas le repos ni SceneKit. Le chiffre 49 % du premier Profil direct
ne constitue pas un A/B contrôlé avec ce 38 %. La capture à 17:49 montre le
Profil déjà défilé, sans grand booster visible, avec une sonde à 29 % CPU.
Les petites pastilles boosters hors du haut sont des images statiques.

Deux défauts de sommeil ont été corrigés dans `ProfilLune.swift`, puis
**compilés et installés dans le build 6** :

- `DosVide` : les 25 cellules montées avaient chacune une boucle d'allumage
  toutes les 5–9 s, y compris hors onglet et viewport. La tâche est désormais
  annulée quand l'onglet est caché, la scène inactive ou la cellule hors de
  l'intersection des viewports vertical et horizontal, ainsi qu'avec
  Reduce Motion. Reprise après un délai neuf ;
  phases remises à zéro sans animation. Seul le sous-arbre dessiné change
  d'identité à la pause/reprise pour arrêter les interpolations déjà différées ;
  le bouton et ses gestes restent stables. Dessin, durées visibles et
  haptique conservés, sans horloge supplémentaire.
- `BanniereHalos` : le TimelineView suit montage, visibilité dans le scroll,
  onglet, scène active et Reduce Motion. Shader, paramètres et cadence de
  30 Hz lorsqu'il est visible sont inchangés.

Parse Swift et `git diff --check` réussis. Les mesures du build 6 ci-dessous
n'isolent pas le coût propre à ces composants ni le gain de leurs portes.

### Build 6 : cinq tests appareil PASS le 15-09

Release installé à **07:18:39**, lancé à **07:18:58**. Journaux archivés dans
`campagnes/2026-09-14-correctif/`, chacun avec zéro échec :

| Parcours | Journal | Durée PASS |
|---|---|---:|
| Home → Profil | `test6-home-profil.log` | 3,864 s |
| Profil → Home | `test6-profil-home.log` | 3,737 s |
| Home → Exercices → Home | `test6-exos.log` | 5,150 s |
| Défilement Profil | `test6-scroll.log` | 2,774 s |
| Fermeture de la pop-up de bienvenue | `test6-bienvenue.log` | 3,360 s |

Captures appareil : [Profil sommet](campagnes/2026-09-14-correctif/woop-profil-build6.png),
[Profil défilé](campagnes/2026-09-14-correctif/woop-profil-scroll6.png),
[Home sans bienvenue](campagnes/2026-09-14-correctif/woop-home-sans-bienvenue6.png).
Ces tests valident les actions énoncées ; ni suppression, ni déconnexion,
ni séance créée, ni récompense réclamée, ni réinitialisation du compte.

Quatre fenêtres stables, JSONL et `.verdict` archivés séparément :

| Préfixe de fichier | t depuis lancement | n | CPU médian |
|---|---|---:|---:|
| `build6-home-avant-profil` | 15,4–44,8 s | 30 | 16 % |
| `build6-profil-sommet` | 75,3–179,9 s | 104 | 41 % |
| `build6-profil-defile` | 215,4–239,8 s | 25 | 25 % |
| `build6-home-retour` | 280,5–310,9 s | 31 | 16 % |

Toutes : **thermique 2, protection 1, 60,1 callbacks/s médians et intervalle
maximal 17 ms**, tics nuls. Elles remplacent le premier relevé court de
23 points. Au sommet, grand booster et bannière restent visibles. Le passage
à 25 % après défilement change la scène affichée : ce n'est pas un A/B
causal des corrections. Le retour Home retrouve 16 % dans cette fenêtre ;
la cadence régulière ne valide ni l'énergie ni une endurance depuis thermique 0.

### Trace CPU exploitable et dernier build encore à tester

Le Time Profiler du build 5 est distinct de la trace Metal vide. Il observe
**Profil avec Réglages ouverts**, pas Home : 3 829 échantillons Running de
poids 1 ms ; **74,67 % du poids total sur le main**, avec travail soutenu
SwiftUICore/AttributeGraph/runtime Swift. Ces trois familles représentent
55,93 % des feuilles main. SceneKit est présent sur plusieurs workers
(8,20 % inclusifs du total) ; le seul thread nommé renderer n'en décrit pas
tout le coût. Poids CPU, pas attente ni occupation GPU. Symboles de fonctions
absents : aucune vue précise ne peut être désignée sur cette trace seule.
Les échantillons XML, le parseur et [l'analyse](campagnes/2026-09-14-correctif/trace-profil-cpu/woop-profil-cpu-analysis.md)
sont archivés dans `trace-profil-cpu/`.

Les références de `CLAUDE.md` et du skill performance sont rectifiées : les
27–39 % historiques sont le défaut signalé, pas un budget acceptable ;
cadence, CPU et énergie sont distincts, et `onglet=profile` ne dit pas si
Réglages le recouvre.

Le build 7 ajoute les portes avatar, flèches et poignée : scène, onglet,
Reduce Motion et visibilité ; dessins conservés. Release PASS, installé
à **07:25:57** ; lancement à **07:26:46** refusé avec `Locked`, demande de
déverrouillage transmise. Pas de résultat appareil attribué à ce build.
Le build 8 complète la tâche d'invitation du booster : elle s'annule hors
écran, sous le panneau, enterrée/planquée ou pendant un geste ; son retour
est annulable aussi. **Build 8 Release compilé à 07:30:34, installé de
07:30:43 à 07:30:46**, succès confirmé ; app d'abord laissée fermée en attente du
déverrouillage, puis lancée pour les captures et la trace Metal ci-dessous.
QA 04/07 restent KO jusqu'à la validation au doigt, au cycle
complet du compte et à l'endurance depuis thermique 0. Les notes QA et le livrable du site sont actualisés au 15-09 vers 07:33.
`npm run artefact`, puis `npm run verif` passent : 23 tests, types,
reconstruction déterministe, captures générées et 10 pages sans débordement
à 390 px. Aucune republication au lien Claude : outil indisponible.

### Build 9 : parcours complet de navigation après relance, PASS

Build 9 installé à **07:46:13** puis lancé. Les journaux sont archivés dans
`campagnes/2026-09-14-correctif/` :

- `test9-home-profil.log` : Home → Profil PASS **3,981 s**, fin 07:47:30.
- `test9-profil-scroll.log` : défilement PASS **2,826 s**, fin 07:49:16.
- `test9-navigation-relance.log` : relance puis **Home → Exercices → Home →
  Profil → Réglages**, PASS **10,156 s**, zéro échec, fin **08:00:58**.
  [La capture Réglages](campagnes/2026-09-14-correctif/woop-reglages9.png)
  montre le panneau réellement ouvert.

Le test précédent pages/réglages avait échoué à 07:59:22 sur sa précondition
« app déjà lancée », avant tout parcours ; `test9-pages-reglages.log` est
conservé aussi. `xctrace --launch` avait terminé l'app à la fin de sa capture.
Le test explicite après relance a ensuite passé. Aucune suppression,
déconnexion, séance créée, récompense réclamée ou remise à zéro du compte.
La validation au doigt par Kathryn et le cycle avec suppression restent
distincts de ce succès automatique ; **QA 04/07 restent KO**.

### Build 9 : chauffe persistante et contextes de mesure séparés

Le brut `woop-build9-parcours.jsonl` est archivé sans filtre. Les lignes
t15–45 sont Home **avec panneau START**, pas la Home à widgets ; le Profil
au sommet arrive vers t74, le Profil défilé à t185+. Cette dernière plage
contient la trace SwiftUI instrumentée de **07:51:09–18** : ni médiane globale
ni comparaison avec les widgets comme s'il s'agissait du même écran.
Les observations d'usage restent autour de **41–44 % CPU au sommet et
22–27 % défilé, thermique 2**. Les arrêts du galet de menu transparent et
des liserés Home cachés sont installés dans le build 9 ; leur gain propre
n'est pas démontré et le téléphone chauffe toujours selon Kathryn.

Deux nouvelles analyses sont archivées avec leurs petits calculs et rapports :

- [Metal réel, build 8](campagnes/2026-09-14-correctif/trace-home-metal-build8/woop-metal8-analysis.md),
  Home avec widgets protégée, **Fair** pendant l'enregistrement 07:45:18–27.
  GPU Active sur 32,53 % de la couverture, principalement dans `backboardd` ;
  maintien d'une surface **1,880 s**, dont **1,708 s GPU Idle** continu.
  La trace ne prouve pas un GPU saturé ou bridé ; le retard de présentation
  reste à expliquer, avec perturbation possible des instruments. Les
  échanges de surfaces ne sont pas les callbacks de la sonde.
- [CPU Profil défilé, build 9](campagnes/2026-09-14-correctif/trace-profil-cpu-build9/woop-profil9-cpu-analysis.md).
  Après la première seconde : main **57,80 %**, AsyncRenderer **20,15 %**,
  autres workers **22,05 %** du poids CPU échantillonné. Rendu SceneKit
  récurrent chaque seconde (10,08 % inclusifs), sans propriétaire SCNView
  identifié ; `SliderObsidienne` rencontré sous TimelineView, sans cadence
  ou instance déduite. L'instrumentation SwiftUI reste visible dans les
  piles. Ces poids Running ne mesurent ni énergie, ni attente GPU, ni durée
  bloquée de `wait_for_lock`.

Une trace SwiftUI distincte, lancée avec l'app de **07:57:34,787 à
07:58:20,904** (46,116949 s), apporte ensuite l'identité d'un producteur.
Lancement direct Profil, défilement PASS à 07:57:51 : **2 910 updates de
rotation après t25 s**, hiérarchies passant par `RondAvatar` dans le ScrollView.
La [capture](campagnes/2026-09-14-correctif/trace-profil-swiftui-build9/woop-profil-scroll9-trace.png)
montre le Profil défilé ; [les hiérarchies](campagnes/2026-09-14-correctif/trace-profil-swiftui-build9/woop-profil9-rotations.txt)
et deux parseurs sont archivés. Ces updates ne chiffrent pas l'énergie de
l'avatar et ce lancement direct ne valide pas la navigation Home.

Les traces volumineuses et grands exports, dont l'XML SwiftUI de 1,2 Go,
restent dans `/private/tmp` ; leurs chemins figurent dans les rapports copiés.
**Build 10 installé à 08:08:04** : pause du slider caché,
intersection géométrique avatar/bannière avec le viewport, `.id(immobile)`
sur le dessin avatar pour interrompre les rotations installées, sonde SCNView.
Son premier test marqué PASS est recouvert par Welcome Back, d'après
`woop-profil-scroll10.png` archivée : **aucun défilement validé par ce premier essai**. Le
CPU 40–45 % décrit Profil + modal, grand booster actif. Le runner doit fermer
Later et vérifier un déplacement de Deux Lunes supérieur à 100 pt avant le
retest. Celui-ci passe ensuite à **08:10:18,679 en 2,980 s**, zéro échec,
avec cette assertion et la [capture vérifiée](campagnes/2026-09-14-correctif/woop-profil-scroll10-verifie.png).
Journal `test10-profil-scroll-verifie.log`, diagnostics `woop-nav10.jsonl` et
`woop-vol10.jsonl` archivés. Vers t132, avatar/bannière au repos ; une SCNView
560×700 relevée, alpha cumulé 0, lecture et rendu continu arrêtés, scène en
pause. Après t160 hors trace, CPU **25–28 %** avec `navProbe` encore actif :
aucun gain thermique établi. La lecture des flags de pause est ensuite
contredite par le compteur de rendu du build 11, ci-dessous.

### Build 12 : arrêt réel du booster caché, reprise et navigation attestés

Sur le build 11, la SCNView du booster caché reste à **environ 30 rendus/s** :
compteur 1 054 → 1 542 en 16,244 s, malgré alpha cumulé 0,
`isPlaying=false`, `rendersContinuously=false` et `scenePaused=true`.
`woop-build11-profil-{vol,nav}.jsonl` sont archivés. Les flags ne prouvaient
pas l'arrêt du moteur de rendu.

Le build 12 détache `SCNView.scene` pendant la pause, conserve la même scène,
caméra et son temps, puis les réattache avec vérification d'identité à la
reprise. Installé **08:35:09–25**, lancé **08:35:26** avec
`-sondeVol -navProbe -openTab profile`. Les trois tests réels sont archivés :

| Test | Résultat | Preuve |
|---|---|---|
| Défilement, déplacement réellement vérifié | PASS **4,728 s**, fin **08:35:43,474** | `test12-profil-scroll.log`, [capture](campagnes/2026-09-14-correctif/woop-profil-scroll12.png) |
| Remontée, booster revenu | PASS **2,843 s**, fin **08:36:22,901** | `test12-profil-remonte.log`, [capture](campagnes/2026-09-14-correctif/woop-profil-reprise12.png) |
| Retour → Home → Exercices → Home → Profil → Réglages | PASS **22,027 s**, fin **08:37:49,175** | `test12-navigation-reglages.log`, [Réglages](campagnes/2026-09-14-correctif/woop-reglages12.png) |

Les paires `woop-build12-profil-{vol,nav}.jsonl` et
`woop-build12-profil-reprise-{vol,nav}.jsonl` montrent le compteur **449
immobile environ 39 s** avec `scene=nil`, puis une reprise autour de 30/s.
Même vue `0x109f02580`, même scène `0x109dc7f00`, même caméra `0x11076b980` :
la reprise ne recrée pas le booster. `scenePaused=null` pendant la pause
signifie ici qu'aucune scène n'est attachée, pas que le moteur a repris.

Les dernières 30 s du relevé défilé (t20,3–49,7, n30) donnent **15 % CPU
médian, 60,1 callbacks/s, intervalle maximal 17 ms, thermique 2**. Le Profil
au sommet reste autour de **41 % CPU** avec le booster visible. L'arrêt
hors écran est démontré ; la chauffe globale et l'endurance à froid ne le
sont pas. Aucune suppression, déconnexion, séance créée, récompense réclamée
ou réinitialisation du compte. **QA 04/07 restent KO** : ces tests automatiques
ne remplacent ni le retour au doigt ni le cycle complet du compte.

### Prototype 11 laissé désactivé : CPU bas avec retards de présentation

Le prototype `-lisereCoreAnimation` a été compilé et mesuré ; il reste
**désactivé par défaut**. Les trois bruts et captures A/B/pose zéro sont
archivés. Sur leurs 30 dernières secondes respectives, thermique 2 :

| Variante | CPU médian | Callbacks/s médians | Intervalle maximal |
|---|---:|---:|---:|
| A de référence, t20,3–49,8, n30 | 13,5 % | 60,1 | 67 ms |
| B animé, t469,0–497,9, n28 | 3 % | 17,5 | 412 ms |
| B posé à zéro, t21,3–50,7, n30 | 12 % | 60,1 | 31 ms |

Le B complet après t15 contient 444 publications, 16,6 callbacks/s médians,
avec un intervalle maximal de 877 ms. Les quatre microhangs de **366,771 à
415,900 ms** appartiennent à une fenêtre System Trace distincte de 9,071 s,
08:29:18–27 : ils ne résument pas toutes les saccades. Le main y attend
réellement des synchronisations `commit_transaction` / `waitForCommitId` ;
les workers attendent dans SharedSurface puis libèrent le même mutex.
L'union des attentes de synchronisation couvre 6,276 s, dont 6,269 s où le
main est explicitement Blocked. Le total Blocked inclut aussi l'attente
normale du runloop ; il ne faut pas l'appeler durée totale de gel.

Cette preuve concerne **le prototype B11 animé** : ni calque précis,
ni processus distant responsable, ni saturation GPU ne sont établis.
[L'analyse System Trace](campagnes/2026-09-14-correctif/trace-lisere-system-build11/woop-lisere11-system-analysis.md),
les petits résultats et parseurs sont archivés ; les grandes traces restent
dans `/private/tmp`. La pose à zéro rétablit une cadence régulière dans
son essai séparé, sans valider la variante animée.

Un [écran noir réellement nu](campagnes/2026-09-14-correctif/woop-ecran-nu12.png)
est lancé à **08:38:50** pour laisser refroidir l'appareil. Dernières 30 s
(t59,9–89,3, n30) de `woop-build12-ecran-nu-vol.jsonl` : **1 % CPU,
60,1 callbacks/s, intervalle usuel 17 ms / maximal 32 ms**, thermique 2
encore. Ce contexte n'est pas la Home et ne constitue pas sa réparation.
Les sources des rapports et QA sont actualisées ; aucun artefact documentaire
n'est régénéré dans cette mise à jour.


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
