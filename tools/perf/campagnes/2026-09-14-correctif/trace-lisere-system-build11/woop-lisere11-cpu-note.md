# CPU prototype liseré Core Animation — build 11

Source : `/private/tmp/woop-lisere11-native-cpu.xml`.
Processus Woop 17521 ; charge de Woop 0x1044b4000 ; UUID D648E94D-F8AE-34B0-ABB4-6984E8291610, conforme au dSYM build11.

436 échantillons, tous marqués Running, pondérés à 1 ms : 360 sur le fil principal, 76 sur les autres fils. Premier échantillon à 0,313029 s, dernier à 9,009027 s. Les absences entre échantillons ne mesurent ni une durée d'attente ni une durée de gel.

## Résultats bornés

- Aucune frame nommée ImageRenderer, LisereCoreAnimation ou SCN observée. Les symboles applicatifs ont été vérifiés par atos avec le dSYM et la charge du XML. Aucune preuve de régénération périodique des bitmaps dans cette capture ; l'absence dans un échantillonnage n'est pas une preuve d'absence absolue.
- CA::Context::commit_transaction : 85 ms de poids inclusif, toutes sur le fil principal, soit 23,6 % de ses 360 ms échantillonnées. CA::Transaction::commit : 91 ms inclusives. Ces poids se recouvrent : ne pas les additionner.
- ViewGraphRootValueUpdater.render : 198 ms inclusives sur le fil principal. DisplayList.ViewUpdater.render : 110 ms. SwiftUICore apparaît dans 237 des 360 échantillons principaux (65,8 %). Ces ensembles se recouvrent également.
- Le performWithoutAnimation observé (111 ms inclusives) est celui de ViewGraph.renderDisplayList / renderOnMainThread de SwiftUI ; aucun appel du prototype ni UIViewRepresentableContext.animate n'est identifié dans ces stacks.
- AnimatableAttributeHelper : 4 ms ; TimelineView.UpdateFilter : 10 ms. MoonCoinView apparaît dans 2 ms ; ChevronAppel.battre et SkyMotion apparaissent aussi. Ces observations ne justifient pas un nouveau chantier sur ces composants.

## Chemin de synchronisation à corréler à System Trace

Sur le fil principal, aux temps 0,313029 s, 2,961030 s et 8,402028 s :

CA::Context::commit_transaction → CA::Layer::layout_and_display_if_needed → RBLayer.display → RB::SharedSurfaceGroup::add_subsurface → wait_for_allocations → RB::CommitMarker::Observer::test_displayed → CAContext.waitForCommitId.

Aux deux dernières occurrences, la pile passe aussi par CA::Context::synchronize / _CASSynchronize. wait_for_allocations est présent dans 4 échantillons principaux au total (dont un sans waitForCommitId visible). waitForCommitId apparaît dans 8 échantillons tous fils confondus, dont ces 3 sur main.

Ce chemin persiste jusqu'à 8,4 s dans la capture : il ne se limite pas au premier échantillon. Il fournit une cible d'attribution à System Trace, mais Time Profiler Running ne permet pas de dire combien de temps le fil attend ni quel calque provoque la synchronisation. En particulier, il ne prouve pas que le masque UIKit du prototype est la surface concernée.

## Artefacts

- `/private/tmp/woop-lisere11-analyse.py` : adaptation du parseur profil10, résout toutes les références XML.
- `/private/tmp/woop-lisere11-cpu-analysis.json` : statistiques globales, main et autres fils.
- `/private/tmp/woop-lisere11-resolved-samples.json` : échantillons et piles résolus.
- `/private/tmp/woop-lisere11-atos.json` : symbolication des 18 adresses applicatives distinctes.
- `/private/tmp/woop-lisere11-cpu-findings.json` : poids inclusifs et timestamps des motifs examinés.

Aucune source d'app modifiée, aucune commande d'appareil ni build.
