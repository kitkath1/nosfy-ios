---
name: woop-chauffe
description: Diagnostiquer la chauffe, la consommation et les saccades de Woop sur iPhone réel, et vérifier le coût des modifications de ses animations, vidéos ou vues persistantes. Utiliser pour une régression thermique ou une validation de performance de Woop ; conserver le dessin et les gestes demandés.
---

# Woop — maîtriser la chauffe

Travailler dans le dépôt Woop qui contient `Woop/Views/SondeVol.swift` et
`tools/perf/ECHECS-CHAUFFE-HOME.md`. Ce skill mémorise la méthode et les erreurs
payées ; il ne garantit pas qu'une version future ne chauffera jamais.

## Reprendre sans repartir de zéro

Lire d'abord le début du **registre des échecs** et les entrées concernant le
symptôme, puis le rapport de campagne qu'il désigne et `docs/site/content/qa.ts`.
Ils portent l'état actuel ; les numéros de builds historiques ci-dessous ne le
remplacent pas. Lire aussi `CLAUDE.md` et `MULTI-SESSION.md` dans ce dépôt partagé.

- Le 15 septembre 2026, le petit point animé du dernier jour de séance entretenait
  un coût SwiftUI important, même avec `corps=0` et `tics=0`. La comparaison33
  à thermique1/protection1 donnait **12 % CPU médian avec son souffle, 1 % sans**.
  Le rendu natif34 a ensuite tenu **1 % sur trois minutes**, y compris à
  thermique0 avec animations actives. Détails et limites :
  `tools/perf/campagnes/2026-09-15-reprise-autonome/etat.md` (E55).
- Le CPU faible ne clôt pas la chauffe : après les allers-retours34, l'état
  thermique restait1. La sonde ne mesure ni le GPU, ni des watts, ni des degrés.
- Les anciens 27–39 % CPU de la Home immobile étaient le **défaut**, pas un budget
  acceptable. Une vidéo décodée matériellement n'est pas une preuve d'énergie
  négligeable. Les coûts du verre et des animations varient selon le montage.
- Ne pas rejouer le banc complet des décorations. Pour rouvrir une piste déjà
  écartée, identifier l'observation nouvelle qui rend l'essai utile (E45–E49).

## Choisir la prochaine preuve

Énoncer le symptôme reproductible, la question encore ouverte et la mesure qui
peut y répondre. Un correctif déjà mesuré mérite un test de régression, pas une
nouvelle bissection identique. Distinguer les objectifs suivants :

| Objectif | Preuve utile |
|---|---|
| Diminuer le coût d'un moteur | Même binaire, un seul moteur différent, contexte et état thermique comparables ; A/B alterné si le téléphone le permet |
| Réparer un gel ou un bouton inaccessible | Parcours tactile réel avec assertions, y compris quand le téléphone est chaud |
| Vérifier la chauffe durable | Home normale plusieurs minutes, navigation répétée, puis récupération ; trajectoire thermique, contexte de charge et observation utilisateur |
| Préserver le design | Captures ou film du vrai écran montrant l'appel du Chapitre, les flammes, les états vides/faits et le retour du pull |

Un essai chaud reste utile pour la robustesse. Il ne devient pas un essai froid
par filtrage des seules dernières lignes. Une catégorie thermique identique ne
garantit pas des fréquences CPU/GPU identiques. Ne pas additionner ces preuves
pour annoncer une validation qu'aucune d'elles n'établit.

## Mesurer le bon écran et le bon binaire

Pour piloter l'appareil, lire [references/iphone.md](references/iphone.md).

1. Relever la version **installée**, les arguments, la date, le type de connexion
   et, si accessibles, charge/batterie/luminosité. Un build compilé ou un message
   d'installation ne prouve pas que le scénario a été exécuté.
2. Vérifier la vraie Home : aucune porte/onboarding/visite, fenêtre de bienvenue,
   séance, lecteur ou tiroir superposé. Lire les champs de contexte de la sonde
   **et** constater l'écran. `onglet=home` seul ne suffit pas (E43).
3. Pour la sonde : `-sondeVol -ecranEveille -navProbe -openTab home`. Conserver
   les protections normales lors de l'endurance. Écarter les 15 premières secondes
   d'un lancement pour le coût stable ; écarter séparément les transitions du
   parcours. Conserver aussi les pics et la durée des gels.
4. Collecter les journaux **avant** toute relance. Garder les données brutes, le
   nom de fichier sur l'appareil et les fenêtres analysées. Ne pas réécrire les
   traces pour satisfaire un contrôle de style.
5. Utiliser `scripts/analyse_sonde.py` pour séparer contexte et groupes
   `(therm, protection)`. Il produit un résumé, jamais un verdict « ne chauffe pas ».
   Les médianes portent sur les lignes retenues ; publier leur nombre et leur durée.

`img` compte les callbacks CADisplayLink, pas les images réellement présentées
par le GPU. `cpu` estime la charge des threads du processus (100 % = un cœur),
pas l'énergie. `corps/tics=0` n'innocente pas le graphe SwiftUI ni le compositeur.
`therm=0/1/2/3` signifie nominal/fair/serious/critical, sans température exacte.

Si le CPU baisse mais que la chauffe persiste, examiner une trace d'énergie/rendu
et le travail encore visible ou caché. Ne pas inventer de métrique GPU à partir
de colonnes anonymes. Les mesures sans HUD servent à contrôler le coût de la sonde.

## Corriger en préservant l'intention visuelle

Préférer une intervention liée à la preuve : isoler une animation de son parent,
mettre en cache un dessin constant, ou arrêter un moteur hors écran. Pour un
effet simple, une texture stable animée en opacité/transform par Core Animation
est une option éprouvée ici (`AppelChapitre.swift`, `PerleSemaineNative.swift`).
Un `repeatForever` SwiftUI reste à mesurer ; ce n'est pas un moteur gratuit.
Ne pas convertir toutes les flammes en code ni tous les effets en vidéo sans
comparaison utile. Le nombre d'écrans ne prédit pas leur coût par image.

Vérifier les cycles de vie : sortie d'onglet, vue recouverte, arrière-plan,
réapparition, Reduce Motion, protection thermique. Une opacité nulle n'arrête
pas un lecteur vidéo ou SceneKit. Au démontage, libérer lecteurs/loopers/observers
et invalider les rappels asynchrones ; vérifier qu'ils ne continuent pas après
plusieurs passages. Ne pas attribuer une fuite à la navigation si la charge
était déjà présente avant le premier appui.

Conserver la pose pendant les gestes et les pauses thermiques : une bascule de
lecteurs ou un retour au poster peut provoquer un saut sans expliquer la chauffe
(E54). Tester aussi une reprise du geste en cours. L'onde d'appel du jour actif
ne signifie pas que tous les anciens fonds/liserés du Chapitre sont restaurés.
Décrire toute concession visuelle ; l'utilisateur a demandé un Chapitre vivant.

## Fermer l'essai et transmettre

Arrêter la campagne lorsqu'une nouvelle mesure n'apporterait plus d'information,
ou si la liaison empêche de contrôler l'écran. Ne pas chauffer le téléphone par
une boucle de relances. En cas de thermique serious/critical, suspendre le stress
et observer la récupération avec les protections actives.

Relancer avec **`-sansSondeVol`** après collecte : son activation persiste dans les
préférences. Vérifier le retour normal et signaler tout échec de restauration.
Conserver les données du compte ; un test thermique n'implique ni déconnexion,
ni suppression, ni validation d'une séance.

Archiver dans `tools/perf/campagnes/DATE-SUJET/` : scénario, version réelle,
sources modifiées, commandes, preuves, résultat et limites. Ajouter les échecs
et mesures invalides au registre, y compris ceux de l'automatisation. Mettre à
jour les notes QA concernées sans passer toute la QA au vert pour un accès Profil
réparé. Suivre les règles locales du livrable documentaire et des commits ;
l'autorisation déjà donnée dans la session reste valable. Dans les fichiers
partagés, ne sélectionner que les changements de cette tâche.

Rapporter séparément : **installé**, **parcours testé**, **coût mesuré**,
**rendu constaté**, **chauffe durable établie ou encore ouverte**.
