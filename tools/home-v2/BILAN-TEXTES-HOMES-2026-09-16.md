# Textes des deux Homes et du pull — réalisation du 16 septembre

**Actualisation du 16-09 : les textes changent à chaque arrivée/retour réel sur
les deux Homes. La formulation de la Home noire se renouvelle toutes les cinq
minutes visibles ; le nombre reste à la minute réelle.** Aucun rattrapage ni
tirage en arrière-plan. Rouge 39 : trois variantes aux retours, PASS 21,732 s ;
noire 41 : trois variantes à trois minutes, PASS 27,896 s. Les captures montrent
le flou progressif. Haptique ressentie non confirmée.

La reprise chauffe mesure encore21 % CPU sur Home noire40 à thermique0/protection0.
42 réduit ce coût : natif/ancien/natif dans le même binaire,3 % /20 % /3 %,
animations actives et protections inactives. L’endurance a été interrompue :
[mesures et essais d’optimisation](../perf/campagnes/2026-09-16-retours-et-profil/etat.md).
La validation longue reste ouverte tant que les mesures et le retour d’usage
ne l’établissent pas.

## Historique de la première livraison

Le plan a été autorisé puis développé. **Version 37 compilée en Release et
installée sur l’iPhone à 09:44 ; lancement refusé par iOS (« Locked »).** La
version 36 avait été ouverte, mais l’utilisateur n’y voyait pas la prise de
parole demandée. Ce rejet est conservé ci-dessous ; un build réussi ne valide
pas le rendu.

## Ce qui est livré

- `home()` conserve ses anciens champs et ajoute `textes`, le lot de la langue
  du profil. La migration `20260916064928_home_textes_bilingues` est posée.
- `home_textes_lots` contient deux lots sans donnée personnelle, revision
  `ia-relue-20260916-03` : 27 départs et trois variantes de chacun des cinq états
  Home, soit **42 variantes par langue**. Les mêmes lots sont embarqués dans
  `Woop/Resources/home-textes.json` pour le hors-ligne.
- L’Edge Function `home-textes` génère des brouillons avec GPT-5, puis publie
  uniquement des lots relus. Le JWT est vérifié par la passerelle ; Supabase
  Auth vérifie en plus le droit administrateur. Aucun appel IA au pull ou par
  minute ; aucun prénom, profil ni historique envoyé au modèle.
- `HomeTextes` conserve les gabarits par langue/révision. Prénom et nombres sont
  injectés depuis les données actuelles, avec les pluriels. Le pull tire phrase
  et bouton ensemble, sans remise, une fois par ouverture, et garde son choix
  pendant le geste. Le serveur confirme la langue ; avant ce retour, le choix
  local ou, en l’absence de choix, la langue de l’appareil s’applique.
- À la demande de l’utilisateur, le français garde **quelques** touches :
  « Petit reset », « Go », « Let’s go », « Trouve ton flow ». Le reste est français.
- Dernière demande : alléger la Home. Les lots publiés font **7 à 12 mots**
  avec un prénom simple, salutation et compteur inclus. Le serveur refuse les
  futures variantes dépassant 14 mots (jetons comptés pour deux mots). Un prénom
  composé peut ajouter des mots ; la ligne se réduit si elle dépasse sa largeur.

## Animation 37

`ParoleLigne` reprend le calendrier exact de `MotsFlou` (onboarding) : durée des
mots et pauses de ponctuation. Chaque mot se révèle avec un flou **12 → 0**, une
opacité **0 → 1**, une montée de 5 points et une échelle **0,96 → 1**, courbe de
1,05 seconde. Un impact haptique `soft`, intensité 0,28, accompagne chaque mot.
La lecture attend que le texte entre à l’écran. Le composant laisse passer les
gestes ; les quatre lignes et le raccord du pull conservent leurs cotes.

Les tâches s’arrêtent hors écran ou sous la bienvenue. Reduce Motion affiche
le texte complet sans effet ni haptique ; VoiceOver lit une phrase complète.
Sur la Home noire, le nombre de minutes évolue seul entre deux paliers ; une
nouvelle formulation apparaît désormais toutes les 5 minutes pendant que la
Home noire est visible (précision utilisateur après la version 38).
L’ancien balayage `SouffleTexte` en boucle est retiré. Les nouvelles animations
finissent après la phrase ; **cela ne constitue pas une mesure thermique**.

## Vérifications réalisées

Preuves conservées dans [validation-textes-2026-09-16](validation-textes-2026-09-16/).

| Vérification | Résultat et portée |
|---|---|
| `home()` réel, rôle authenticated, profil QA FR puis EN | Chaque langue reçoit son lot 03 et 27 départs ; anciens champs conservés. Les changements de langue sont dans une transaction annulée. |
| Appel REST réel du compte QA | HTTP 200, langue FR, révision 03. |
| Droits | Le client ne peut insérer dans la table ; anon ne peut ni la lire ni appeler `home()`. L’Edge refuse sans jeton et avec un vrai jeton utilisateur (401). Un administrateur atteint le validateur (400 sur une action volontairement inexistante). |
| Publication | Les deux lots relus 03 sont publiés ensemble, réponse `ok: true`. |
| Validation TypeScript | Lots valides ; doublons, nombres inventés, mauvais pull, jetons inconnus, lots incomplets et phrases trop longues refusés. Typage Edge sans erreur. |
| Modèles Swift | FR/EN, prénom réel, nombres 0/1/2/123 et trois sacs complets sans répétition : PASS. |
| Largeur des lignes littérales | Mesure Inter SemiBold 30, tracking −0,4 : les dépassements FR ont été raccourcis. Aucun dépassement de 300 points au dernier contrôle. |
| Compilation | Release iPhone 37 et simulateur 37 : PASS. Le correctif de compilation de `FondVideoMetal` est limité au simulateur ; le chemin iPhone est conservé. |
| Films simulateur 37, rouge/noire FR/EN | Apparition progressive et flou visibles ; texte stable ensuite, prénom long Éléonore sans débordement. Un simulateur ne prouve ni haptique ni consommation iPhone. |

**Encore à confirmer sur 37** : rendu ressenti et haptique sur iPhone, navigation
complète, pull interrompu/repris, Reduce Motion/VoiceOver en interaction, coût
après lecture et séance longue. Aucune suppression de compte ni création de
séance n’a été faite pour ces tests. QA chauffe reste ouverte ; la courte mesure
sur Home noire 35 ne valide pas 37.

## Échecs et corrections — ne pas recommencer les mêmes essais

| Essai | Échec constaté | Correction ou limite |
|---|---|---|
| CLI Supabase avec l’environnement global | 401, jeton d’un autre projet | Wrapper chargeant explicitement le jeton Woop de `.secrets`, sans l’imprimer. |
| Premier build 36 | Accès à `HomeTextes` isolé MainActor depuis `PhraseTexte` | Isolation de `PhraseTexte` explicitée ; compilation reprise avec succès. |
| Déploiement Edge sans vérification JWT | Refus de la revue automatique | Déploiement avec vérification JWT activée. Aucune désactivation retenue. |
| Comparaison littérale de la clé administrateur | Refus 401 d’une clé de service valide | Vérification effective du droit par Auth ; utilisateur ordinaire ensuite testé et refusé. |
| Génération de fragments complets | Mauvaises places des salutations et compteurs | Brouillons refusés, non publiés. Le modèle n’écrit plus que les champs libres ; le serveur assemble les faits. |
| Premiers textes français | Sept lignes dépassaient la largeur visée | Relecture et raccourcissement avant publication ; demande ultérieure de brièveté intégrée au lot 03. |
| Premier build simulateur | `addPresentedHandler` indisponible dans ce SDK simulateur | Callback de fin de commande uniquement dans le chemin simulateur. |
| 36 à 09:21 puis 37 à 09:44 | Installation réussie, lancement « Locked » | Ne pas présenter l’installation comme une démonstration. 36 lancé après déverrouillage ; 37 attend l’ouverture de l’appareil. |
| XCTest Home 36 à 09:24 | Le bouton Profil existe mais `isHittable` est faux | Échec conservé ; capture seule réussie à 09:27. Aucune conclusion de navigation réparée tirée de cette capture. |
| Rendu 36 | L’utilisateur ne voit pas l’effet de parole demandé | Remplacement de l’essai CATextLayer par les mots SwiftUI du phrasé d’onboarding, flou et haptique en 37 ; début conditionné à la visibilité. Cause exacte de l’essai 36 non prouvée. |
| Premier build du site | Valeur de coût QA appareil hors du type autorisé | Rétablissement de la valeur chantier, validation appareil restant ouverte. |
| Mesure SQL initiale | L’API ne rendait que le dernier SELECT, donc EN | Une nouvelle sonde agrège FR et EN dans un seul résultat, transaction annulée. |

Les advisories Supabase avant/après restent les **53 alertes préexistantes**, sans
nouvelle alerte relevée ; ce n’est pas un audit de sécurité global réussi.
`db push` a fini avec succès malgré un avertissement local de cache Docker absent.
La migration vérifie la définition précédente de `home()` avant de la remplacer.
Le déploiement vérifié porte sur le projet existant ; un reset complet d’une base
vierge n’a pas été testé, et les migrations historiques d’autres sessions ne sont
pas incluses dans ce commit.

Le site local a été régénéré et son vérificateur termine au vert (16 secondes),
capture mobile relue. Le livrable HTML est mis à jour avec les sources. Aucun
outil de cette session ne permet de republier l’artefact Claude au lien externe
historique : cette republication n’est pas annoncée comme faite.
Les films archivés sont des copies réduites à 590 pixels de large ; les planches
montrent une image toutes les demi-secondes. Ce sont des preuves de rendu.

## Maintenance

`tools/home-v2/gerer-textes.py generer fr /tmp/lot-fr.json` produit un brouillon,
puis idem EN. Relire les deux lots, exécuter `test-home-textes.mts`, vérifier les
dimensions, puis `publier fichier-fr fichier-en revision`. La publication ne met
pas à jour automatiquement les JSON embarqués : les mettre en cohérence pour la
prochaine version. Les clés restent dans les secrets, jamais dans les preuves.

Références officielles consultées : [fonctions Postgres](https://supabase.com/docs/guides/database/functions),
[authentification Edge](https://supabase.com/docs/guides/functions/auth),
[sorties structurées](https://developers.openai.com/api/docs/guides/structured-outputs).
