# CPU — Profil défilé, build 9, trace SwiftUI

**Après le démarrage du traceur, le CPU échantillonné reste partagé entre le main (57,80 %), les deux AsyncRenderer SwiftUI (20,15 %) et les autres workers (22,05 %). SceneKit continue réellement à rendre pendant chaque seconde, malgré le contexte de Profil défilé.** Les piles identifient du travail de rendu et d’animation ; leur attribution à une instance de vue demande les causes SwiftUI capturées par la session principale.

## Source et méthode

- XML : `/private/tmp/woop-profil9-time-profile.xml`, trace `/private/tmp/woop-profil-scroll-build9-swiftui.trace`, session vers 07:51:09–18 le 15 septembre 2026, Woop PID **17209** sur l’iPhone réel.
- Contexte fourni : **Profil défilé, bannière/avatar/booster hors écran**, sonde autour de 25 % CPU, 60 callbacks/s, thermique 2. Le CPU de cet enregistrement instrumenté ne remplace pas cette sonde.
- **26 185 lignes**, toutes `Running`, poids uniforme **100 µs**, soit **2 618,5 ms échantillonnées** ; premier échantillon t=0,456232416, dernier t=9,109934541. Dix threads. Résolution des `id/ref` avant comptage.
- Le dSYM est vérifié : **70F58404-C7E6-37AA-965C-4DA12F93A117**, arm64, base chargée **0x100c24000**. `atos` a traité 183 adresses Woop : 167 résultats nommés, dont 8 génériques ; 16 restent non résolues. Les cadres système sont déjà partiellement symboliqués dans l’XML.
- Les poids inclusifs ci-dessous comptent une fonction, un groupe ou un binaire **au plus une fois par pile** ; ils se recouvrent et ne s’additionnent pas. Une présence dans une pile n’est pas un nombre d’appels.

## Surcoût du traceur explicitement séparé

Les premières piles montrent `swiftUITraceRegister → Trace.Control.writeFields / flushWrittenTypes` : installation et sérialisation de types par **SwiftUITracingSupport**. Dans la première seconde relative, ce binaire apparaît dans **223,6 ms** de piles sur **262,1 ms** totales. Sur l’ensemble de la trace : **406,8 ms inclusives**, 70,1 ms en feuille.

Pour éviter de classer surtout ce démarrage, la lecture suivante prend **t ≥ 1 s**, jusqu’au dernier échantillon : **23 564 lignes, 2 356,4 ms**. Cela ne supprime pas tout le coût de capture : SwiftUITracingSupport reste présent dans **183,2 ms de piles (7,77 %)**, dont **68,2 ms en feuille**. Ce coût n’est pas soustrait artificiellement aux autres piles.

| Threads, t ≥ 1 s | Poids CPU échantillonné | Part |
|---|---:|---:|
| Main Thread, tid 1393886 | **1 362,1 ms** | **57,80 %** |
| Deux `com.apple.SwiftUI.AsyncRenderer` | **474,8 ms** | **20,15 %** |
| Autres workers | **519,5 ms** | **22,05 %** |

Sur la trace entière, main 1 601,4 ms (61,16 %), AsyncRenderer 485,4 ms (18,54 %). La différence illustre pourquoi le démarrage du traceur devait être isolé.

## Producteurs et piles réellement observés, t ≥ 1 s

### 1. SwiftUI produit des mises à jour de rendu sur main et workers

Chemin récurrent : `CA::Display::DisplayLink::dispatch_items → ViewGraphDisplayLink.displayLinkTimer → ViewGraphHost.displayLinkTimer → render / renderAsync → AttributeGraph`.

- Sur le main : `ViewGraphRootValueUpdater.render` **621,4 ms inclusives** (45,62 % du main) ; `DisplayList.ViewUpdater.render` **468,5 ms** ; `DisplayList.ViewUpdater.updateItemView` **429,2 ms**.
- Sur les AsyncRenderer : `renderAsync` **453,5 ms** (95,51 % de ces threads), `ViewGraph.updateOutputsAsync` **392,1 ms**, `AG::Subgraph::update` **192,2 ms**.
- Dans ces workers apparaissent bien **`AnimatableAttribute.updateValue` (57,5 ms), `AnimatableAttributeHelper.update` (50,3 ms), `AnimatorState.update` (34,0 ms)** et `AnimationBox.animate`. Tous threads, les piles contenant des fonctions de cette famille représentent **144,7 ms**.
- Feuilles principales, tous threads : **AttributeGraph 381,6 ms**, **SwiftUICore 328,8 ms**, **libswiftCore 294,5 ms**, kernel 175,4 ms, QuartzCore 169,6 ms. Ces poids exclusifs établissent le travail dans les frameworks, sans identifier à eux seuls l’animation applicative qui le déclenche.

La seule présence d’un `repeatForever` dans le code ne prouvait pas où il s’exécutait. Cette trace montre désormais un travail d’animation du graphe SwiftUI ; le lien avec un élément précis reste à établir par les types/causes de mise à jour.

### 2. SceneKit rend encore, ce n’est pas seulement un thread dormant

Piles : `SCNDisplayLink._displayLinkCallbackReturningImmediately → SCNView._drawAtTime → SCNRenderer._drawScene → _renderSceneWithEngineContext → C3D::RenderGraph::execute → C3D::ScenePass / DrawNodesPass`, puis encodage Metal/AGX.

- **237,5 ms** de piles contenant SceneKit, soit **10,08 %** du CPU échantillonné après t=1 s.
- `SCNView._drawAtTime` : **216,8 ms inclusives** ; `SCNRenderer._drawScene` : **191,8 ms** ; `C3D::RenderGraph::execute` : **146,0 ms**.
- Présence chaque seconde complète t=1 à 9 : **22,8 / 37,1 / 30,3 / 28,6 / 27,1 / 30,4 / 30,0 / 27,7 ms**. Cela dépasse une simple dernière image rendue lors de la mise en pause.
- Le thread portant explicitement le nom `scnview-renderer` ne suffit pas à compter ce travail : SceneKit passe aussi par les workers génériques. La pile ne contient pas le propriétaire SwiftUI du SCNView ; elle ne prouve donc pas que le booster est cette instance.

### 3. Cadres applicatifs identifiés, à croiser avec les causes SwiftUI

Poids de piles comportant au moins un symbole du groupe, après t=1 s ; catégories non additives :

| Groupe symboliqué | Poids inclusif | Lecture limitée |
|---|---:|---|
| `SondeVol` | **17,5 ms** | Instrumentation de la sonde ; aucune preuve d’excès à partir de ce poids |
| `SliderObsidienne` | **14,8 ms** | Le corps du slider est effectivement rencontré sous un `TimelineView.UpdateFilter` |
| `DosVide` | **12,9 ms** | Corps et tâche des dos de cartes ; des piles passent par la programmation de `Task.sleep` |
| `SkyMotion` | **11,1 ms** | Callbacks de mouvement observés ; coût modeste dans cet échantillonnage |
| `MoonCoinView` | **0,7 ms** | Closure du corps observée, pas une mesure de coût du shader |

Exemple concret slider : `AccessibilityViewGraph.needsUpdate → AGGraphGetWeakValue → TimelineView.UpdateFilter.updateValue → specialized TimelineView.init closure → SliderObsidienne.body closure (SliderObsidienne.swift:205) → Text.foregroundStyle`. **Ce chemin existe pendant le Profil défilé ; sa présence ne donne pas sa cadence ni l’instance montée.** Les frames spécialisés TimelineView, tous hôtes confondus, représentent 15,4 ms ; ne pas les ajouter aux 14,8 ms du slider.

Le cadre Woop le plus fréquent, `0x101379fd0`, se résout en **`main (WoopApp.swift:0)`**, 1 583,4 ms inclusives sur la trace entière : c’est la racine de la boucle applicative, pas une fonction métier consommant ce temps.

## Attention au mot « attente »

`wait_for_lock` apparaît dans **281,0 ms** de piles du main après t=1 s. Mais **276,4 ms** de ces mêmes piles contiennent **`run_moved_callback`**, qui mène à l’exécution de travail de rendu. **Il serait faux de publier « 281 ms d’attente »** à partir du poids inclusif du verrou. Toutes ces lignes sont déclarées Running ; elles ne donnent pas une durée de blocage hors CPU et n’impliquent pas une attente GPU.

## Portée

Cette analyse établit des mises à jour et animations SwiftUI, ainsi qu’un rendu SceneKit récurrent dans l’état testé. Elle ne démontre pas quel observable ou quelle vue porte chaque travail. L’instrumentation SwiftUI est visible dans les piles et perturbe la mesure ; les pourcentages échantillonnés ne doivent pas être présentés comme une nouvelle valeur de CPU en usage normal. Aucune conclusion GPU/thermique n’est déduite de cette seule trace CPU.

Artefacts : `/private/tmp/woop-profil9-analyse.py`, `woop-profil9-cpu-analysis.json`, `woop-profil9-resolved-samples.json`, `woop-profil9-stack-review.py` et `.txt`, `woop-profil9-symbols.json`, `woop-profil9-symbols-report.md`. Tous sous `/private/tmp`. Aucun build, changement de code ou accès appareil.
