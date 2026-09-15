# Prototype fond Metal build17 — CPU observé

**Le principal poste CPU observé reste SwiftUI sur le fil principal. Le flux vidéo apparaît, mais cette trace n'établit pas que la conversion BGRA ou VideoToolbox soit le poste dominant.**

Capture `/private/tmp/woop-metal17-cpu.trace`, Time Profiler, PID18831, du **15-09-2026 10:30:36.479 au 10:30:45.726 +02:00**, durée9.246914863s. La table thermique donne **Serious, non induit, pendant100% de la capture**. Le dSYM17 fourni et le binaire XML concordent : UUID `1CB3019A-05CC-3A55-9863-E4E6E511A893`, arm64, adresse chargée `0x1044d8000`.

## Échantillons et hotspots

**2291 échantillons, tous Running, poids1ms chacun** : 1469ms sur main (64.12%), 822ms sur les autres threads (35.88%). Premier échantillon relatif0.277688458s, dernier9.246686291s. Références XML `id/ref` intégralement résolues ; cadres Woop vérifiés avec `atos` et le dSYM fourni.

| Chemin observé | Temps CPU échantillonné inclusif | Part des2291ms | Main / workers |
|---|---:|---:|---:|
| SwiftUICore, inclusif | 1118 ms | 48.80 % | 1118 / 0 ms |
| ViewGraphRootValueUpdater.render | 1054 ms | 46.01 % | 1054 / 0 ms |
| DisplayList.ViewUpdater.render | 658 ms | 28.72 % | 658 / 0 ms |
| CA::Context::commit_transaction | 232 ms | 10.13 % | 232 / 0 ms |
| FondVideoMetal, tous chemins nommés | 281 ms | 12.27 % | 5 / 276 ms |
| AVPlayerItemVideoOutput.copyPixelBuffer | 134 ms | 5.85 % | 0 / 134 ms |
| AVPlayerItemVideoOutput.hasNewPixelBuffer | 42 ms | 1.83 % | 0 / 42 ms |
| CVMetalTextureCacheCreateTextureFromImage | 36 ms | 1.57 % | 0 / 36 ms |
| FumeeInviteMetal | 37 ms | 1.62 % | 2 / 35 ms |
| VideoToolbox / VTPixelBufferConformer* | 12 ms | 0.52 % | 0 / 12 ms |

**Les lignes se chevauchent et ne s'additionnent pas.** `DisplayList.ViewUpdater.render` est notamment inclus dans le rendu ViewGraph. Les appels de lecture et de création de texture sont dans `FondVideoMetal`. SwiftUICore représente76.11% des échantillons main.

## Ce que montre le flux vidéo

`FondVideoMetal.Flux.lire` apparaît dans231ms ; 134ms portent `copyPixelBuffer`,42ms `hasNewPixelBuffer`,36ms la création du pont `CVMetalTexture`. Ce coût est visible tout au long de la capture, pas uniquement lors de la boucle.

Une stack observée sous `copyPixelBuffer` passe par :

```text
_platform_memset
→ dispatch_mach_send_with_result_and_wait_for_reply
→ xpc_connection_send_message_with_reply_sync
→ FigXPCConnectionSendSyncMessageCreatingReply
→ FigXPCRemoteClientSendSyncMessageCreatingReply
→ rvcCopyImageForTime
→ AVPlayerItemVideoOutput.copyPixelBuffer
→ FondVideoMetal.Flux.lire
```

Ces134ms **ne sont pas une mesure de conversion BGRA**, et un nom de fonction contenant `wait` dans un échantillon Running ne donne aucune durée bloquée. Les12ms VideoToolbox portent `VTPixelBufferConformerCopyConformedPixelBuffer` / `IsConformantPixelBuffer`, avec vérifications `CVPixelBufferIsCompatibleWithAttributes`. Aucun cadre de fonction `vImage*` ni `VTPixelTransfer*` n'est observé. Leur absence ne prouve pas que la conversion soit gratuite : la capture ne mesure ni le GPU, ni le décodeur matériel, ni le calcul des processus distants.

La fumée native apparaît dans37ms (35ms workers,2ms main). Il reste38ms portant `AnimatableAttribute` et29ms portant `TimelineView`; aucune image `ImageRenderer` observée. Ces nombres n'identifient pas à eux seuls une feuille SwiftUI responsable du coût global. Les chemins applicatifs SondeVol20ms/NavDiagnostic7ms n'incluent pas nécessairement tout le rendu indirect déclenché par leurs données.

## Vérification du contenu et limites

Le journal `woop-build17-metal-long-nav.jsonl` confirme `deuxVideos=true`, textures604×642/1206×964 et drawable1179×1980. Pendant la capture : à10:30:39.134, compteurs b/p1481/1481, vidéo34.542s ; à10:30:44.161,1596/1596, vidéo3.792s. **Les vidéos avancent et traversent une boucle ; le renderer ne montre donc pas seulement ses posters.** `gpuComplete` compte des commandes GPU terminées, pas des présentations effectives à l'écran.

Journal long après20s : médianes **48.3callbacks/s, CPU24%**, intervalle maximal154ms, therm2. Cette fenêtre est plus large que la capture CPU. Les résultats initiaux prototype56.6/CPU27/therm1 contre référence8.1/CPU2/therm2 n'étaient pas appariés : aucun gain CPU, énergie ou thermique ne peut être déduit de cette comparaison. La trace actuelle décrit uniquement les postes Running du prototype.

## Artefacts

Exports `woop-metal17-cpu-{toc,time-profile,device-thermal-state-intervals}.xml` dans `/private/tmp`. Parseur `woop-metal17-cpu-analyse.py`, résultats `-analysis.json`, `-resolved-samples.json`, `-symbolicated-samples.json`, symboles `-atos.json`, motifs et exemples `-hotspots.json`. Rapport : `woop-metal17-cpu-analysis.md`.

Aucune action appareil, aucun build ni changement de source dans cette analyse.
