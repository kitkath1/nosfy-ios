# Symbolication Profil build9

Source : `/private/tmp/woop-profil9-time-profile.xml`, processus Woop PID 17209.

**dSYM correspondant vérifié** : UUID `70F58404-C7E6-37AA-965C-4DA12F93A117`, architecture arm64, `/private/tmp/woop-chauffe-dd/Build/Products/Release-iphoneos/Woop.app.dSYM/Contents/Resources/DWARF/Woop`. Base image vérifiée dans le XML : `0x100c24000`.

**183 adresses applicatives distinctes** extraites après résolution globale des références XML `id/ref` sur les cadres et binaires, puis soumises telles quelles à `xcrun atos -arch arm64 -o <dSYM> -l 0x100c24000`. Mapping complet adresse originale → réponse atos : `/private/tmp/woop-profil9-symbols.json`.

167 réponses nomment un symbole (dont 8 `<deduplicated_symbol>` génériques) ; **16 restent des adresses** et ne constituent pas une résolution fonctionnelle. Les fichiers et lignes `/<compiler-generated>:0` ou `WoopApp.swift:0` ne sont pas des localisations source précises.

XML : 26,185 échantillons du processus ciblé, poids total **2618.5 ms**. Les poids bruts ont été additionnés, sans supposer un poids de 1 ms. Une adresse est comptée au plus une fois par échantillon pour son poids inclusif.

| Adresse | Poids inclusif | Symbole atos |
|---|---:|---|
| `0x101379fd0` | 1583.4 ms | main (in Woop) (WoopApp.swift:0) |
| `0x101241610` | 18.4 ms | @objc SondeVol.coup(_:) (in Woop) (/<compiler-generated>:0) |
| `0x101240f08` | 17.7 ms | SondeVol.coup(_:) (in Woop) (SondeVol.swift:189) |
| `0x1011a2338` | 15.5 ms | specialized closure #1 in TimelineView<>.init(_:content:) (in Woop) + 180 |
| `0x100dca1f0` | 12.3 ms | thunk for @escaping @callee_guaranteed (@guaranteed CMDeviceMotion?, @guaranteed Error?) -> () (in Woop) (/<compiler-generated>:0) |
| `0x100cb8bfe` | 11.0 ms | <deduplicated_symbol> (in Woop) + 2 |
| `0x10119a5f0` | 9.2 ms | closure #5 in DosVide.body.getter (in Woop) (/<compiler-generated>:0) |
| `0x10119a81c` | 9.2 ms | closure #1 in closure #5 in DosVide.body.getter (in Woop) + 88 |
| `0x1011a9bdc` | 9.0 ms | partial apply for closure #1 in closure #5 in DosVide.body.getter (in Woop) (/<compiler-generated>:0) |
| `0x101241228` | 7.2 ms | SondeVol.publier(cadence:pire:t:) (in Woop) (/<compiler-generated>:0) |
| `0x10132a58c` | 5.3 ms | closure #1 in SkyMotion.start(reduceMotion:) (in Woop) (/<compiler-generated>:0) |
| `0x101241000` | 4.9 ms | SondeVol.publier(cadence:pire:t:) (in Woop) (/<compiler-generated>:0) |
| `0x10132a614` | 3.5 ms | closure #1 in SkyMotion.start(reduceMotion:) (in Woop) (/<compiler-generated>:0) |
| `0x101236190` | 2.4 ms | closure #1 in closure #1 in SliderObsidienne.body.getter (in Woop) (SliderObsidienne.swift:219) |
| `0x101236278` | 2.2 ms | closure #1 in closure #1 in SliderObsidienne.body.getter (in Woop) (/<compiler-generated>:0) |
| `0x101241098` | 2.2 ms | SondeVol.publier(cadence:pire:t:) (in Woop) (/<compiler-generated>:0) |
| `0x101241574` | 1.8 ms | SondeVol.publier(cadence:pire:t:) (in Woop) (SondeVol.swift:207) |
| `0x101236fac` | 1.7 ms | closure #5 in closure #1 in closure #1 in SliderObsidienne.body.getter (in Woop) (SliderObsidienne.swift:228) |

**Interprétation** : `0x101379fd0` est `main`, racine des piles, pas une fonction applicative consommant 1 583,4 ms en propre. Les poids inclusifs des adresses ci-dessus se chevauchent : ne pas les additionner entre appelants/appelés. Plusieurs adresses peuvent également appartenir à la même fonction.

Les cadres SondeVol sont la sonde elle-même ; les premiers échantillons XML contiennent par ailleurs l’enregistrement de `SwiftUITracingSupport` (`writeFields`, `flushWrittenTypes`, `swiftUITraceRegister`). La capture inclut donc du travail d’instrumentation. La fréquence de passage dans une closure d’application n’attribue pas à elle seule tout le travail de rendu effectué ensuite par SwiftUI.

Détails par adresse, poids feuille/inclusif, nombre d’échantillons, poids par seconde et références résolues : `/private/tmp/woop-profil9-symbols-analysis.json`. Script reproductible : `/private/tmp/woop-profil9-symbolicate.py`. Aucun build, accès appareil ou changement du dépôt.
