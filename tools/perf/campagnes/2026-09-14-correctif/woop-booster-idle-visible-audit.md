# Booster visible au repos — audit de source borné, après build12

Lecture seule de ProfilLune.swift, BoosterLab.swift, BoosterPack.swift et booster.bin. Aucune nouvelle mesure d'appareil, aucun build ni changement de source. Le contraste communiqué par root (~41 % CPU Profil au sommet, ~15 % défilé après arrêt effectif du booster) ne répartit pas à lui seul le coût entre tous les éléments visibles du sommet.

## Priorité 1 : supprimer les triangles systématiquement jetés

BoosterPack.swift:547–552 crée **deux géométries complètes identiques**, corps et bande, avec leurs shaders respectifs. Le corps jette les fragments de `v > 0.8896` (ligne157), la bande ceux de `v < 0.8896` (ligne183). La séparation en v reste constante pendant la déchirure ; le front mobile est traité ensuite.

Le fichier réel `Woop/Media/booster.bin` contient 12 995 sommets, 62 424 indices, **20 808 triangles**. Classification des triangles par UV, sans modifier les données :

| Lot géométrique | Triangles |
|---|---:|
| Tous les sommets strictement sous v=0,8896 | 17 406 |
| Tous les sommets strictement au-dessus | 3 060 |
| Croisant ou touchant la couture | 342 |

Conserver les indices du corps + les 342 triangles de couture dans le corps, et les indices de la bande + les mêmes 342 triangles dans la bande, conserve chaque fragment potentiellement visible. **41 616 triangles soumis actuellement → 21 150**, soit **−49,2 %**. Les sources de sommets/normales/tangentes/UV, les deux shaders, les matériaux et les deux nœuds restent identiques. Les handlers de gestes ne changent pas, mais leur résultat hitTest doit être considéré séparément (voir complément ci-dessous). Il n'est pas nécessaire de découper ou d'interpoler les triangles de couture.

C'est le levier qui préserve le mieux le dessin. Il réduit du travail de géométrie et de rasterisation jetée ; **le gain CPU ou GPU n'est pas mesuré**, et les deux draw calls restent. Précautions : conserver la couture dans les deux lots, les indices d'origine et leur ordre, les sources et leurs bounding boxes ; ne pas dédupliquer les sommets/exporter une nouvelle géométrie approximative. Vérifier recto/dos, début et fin d'arrachement ; un futur shader modifiant la frontière v nécessiterait de revoir la partition. Un drapeau de comparaison dédié peut sélectionner les indices partitionnés, sans changer les paramètres du rendu.

## Priorité 2 : réduire la surface du géant, pas sa taille apparente

ProfilLune.swift:1154–1170 monte le géant dans **560×700 pt**, incliné −8°, puis déplacé de **385 pt vers le bas**. À l'état stable, son centre est donc 35 pt sous le bas de l'hôte ; avant rotation, seuls les 315 pt supérieurs du rectangle peuvent entrer à l'écran. Le géant est non interactif côté SceneKit (`allowsHitTesting(false)`) ; le tap/tirage est porté par une zone SwiftUI séparée de 300×180 pt (ligne1193 et suivantes).

Le renderer conserve le rectangle complet. Si son échelle réelle est 3× — à vérifier dans un diagnostic, pas mesurée ici — cela représente **1680×2100 = 3,528 millions de pixels par image**, soit 105,84 millions/s à 30 Hz avant MSAA et posttraitements. Le réduire à 2× en conservant les 560×700 pt réduit cette surface théorique à 1,568 million de pixels, **−55,6 %**. Cadrage, mouvement et gestes restent identiques ; le risque est une moindre netteté des fins détails et du bord en biais. Il faut limiter ce réglage au géant, laisser le sheet interactif et le manège à leur qualité actuelle et comparer visuellement. On ne peut pas en déduire une baisse proportionnelle de CPU.

Autre option conservant la densité de pixels : rendre seulement le rectangle visible via une projection décentrée qui maintient exactement le cadrage virtuel 560×700. Plus complexe et risquée pendant traction/retour/inclinaison : une simple réduction de `.frame` changerait le cadrage. Ce n'est pas la première modification à faire.

## Ce qui est effectivement actif, et ce qui ne justifie pas un chantier

- BoosterLab.swift:1304–1310 : MSAA **2× sur appareil** ; ProfilLune:1107–1109 : cadence **30 Hz**, flag existant `-profil60Hz` pour comparaison. `rendersContinuously` est actif lorsque visible. Les géométries lisent `scn_frame.time` pour le bombé (BoosterPack:271–286), et le berceau porte bob/sway continus (lignes925–945) : la scène n'est pas visuellement immobile. Couper simplement le rendu changerait la respiration.
- BoosterPack.swift:499–525 : matière physicallyBased, diffuse + émission, normal map et clearCoatNormal ; caméra HDR, exposition fixe, bloom 0,55/rayon12 (lignes795–807), lumière directionnelle, omni et environnement HDR (816–835). Supprimer HDR/bloom/vernis altère la recette ; ce n'est pas un gain transparent. Aucune activation explicite d'ombres, de SSAO ou de profondeur de champ dans cette scène : ne pas leur attribuer le coût sans trace de passe correspondante.
- Textures réelles : booster-color et booster-emiss **2048×2048**, booster-normal **1024×1024**. Le cache UIImage existe déjà (BoosterPack:1410–1422). Le chargement du maillage se fait à l'init, pas à chaque image : un cache de chargement améliore les montages, pas nécessairement le repos déjà monté.
- Dix clones (ringCount=10, ligne1077) et le sol miroir sont construits même hors galerie, mais **cachés** (lignes729–772) ; ils ne sont révélés que sous `gallery=true` (843–847). Éviter leur construction hors galerie économiserait mémoire/montage/traversée éventuelle ; leur coût de rendu continu n'est pas démontré.
- Le géant a `gallery=false` : pas de gyro, de rotation inertielle ni de placement démarrés par attach ; celui-ci ne lance que l'invite au repos (BoosterLab:1871–1905). Le Timer déclenche un balayage de 0,9 s toutes les 4,2 s (1526–1548, BoosterPack:1211–1224) ; ce n'est pas une boucle CPU Swift à 30 Hz.
- Les deux systèmes de particules ont `birthRate=0` par défaut (BoosterPack:1430/1466). La perle est cachée mais son animation de scale est installée (665–676) ; `-boosterNoFront` permet déjà d'isoler son sous-arbre (713), sans ajouter un mode. Intérêt borné pour exclusion, priorité faible : pas de pluie de 4200 particules/s tant qu'aucune découpe n'est engagée. Ce taux n'apparaît que dans setSparking(true).
- `-boosterStill` est lu par BoosterLab, alors que TirageBooster transmet explicitement `still:false` : ce flag seul ne fige pas le booster Profil. `-boosterBreath 0` enlève le bombé du shader, mais pas bob/sway ni l'invite ; ne pas appeler cela un isolement total du mouvement.

**Proposition** : commencer par les indices partitionnés (même dessin), puis un A/B de densité limité au géant si la charge demeure. Les performances attendues sont des hypothèses de travail ; les nombres de triangles et dimensions ci-dessus sont les faits issus du code et de l'asset.

## Complément demandé : invariant, hitTest et bounds

- **Invariant sur tous les chemins actuels** : discards littéraux `bv > 0.8896` / `bv < 0.8896` (BoosterPack:157/185), et aucune écriture des UV ni remplacement ultérieur de ces shaders. Les paramètres de déchirure (`tearU`, curl, skew, flutter, release), les déplacements de nœuds et le reparentage de la carte ne changent pas cette frontière. Les autres robes partagent ces mêmes shaders. La constante Swift vCut n'est actuellement pas la source des littéraux shader : éviter toute divergence future.
- **Ne pas couper les triangles de couture** : capGeometry déforme volontairement même les sommets sous la frontière (commentaire BoosterPack:219–222), ce qui conserve une interpolation correcte pendant le peeling. Les 342 triangles traversants doivent garder tous leurs indices/sommets dans les deux géométries. Les effectifs ont aussi été revérifiés avec le seuil Float32 exact `0.8895999789237976` et une marge de ±10⁻⁵ : résultats identiques.
- **HitTest n'est pas démontré identique partout** : hold accepte corps OU bande (BoosterLab:1638–1641), et pan prend le premier hit corps/bande puis `hit.localCoordinates.y > stage.yTear - 0.07` (2915–2924). Au repos les deux géométries réunies conservent toute la surface ; pendant les déformations, la suppression de triangles auparavant invisibles peut changer un résultat ou son ordre. Le géant n'utilise pas ces hits (zone SwiftUI distincte) : commencer exclusivement par lui évite de modifier le contrat du sheet et du manège.
- **Bounds** : ne pas supposer que des sources de sommets complètes suffisent à conserver les boîtes calculées après changement d'indices. Appliquer explicitement la boîte originale aux deux géométries (`SCNBoundingVolume.setBoundingBoxMin:max:` existe dans le SDK local) conserve le culling antérieur ; le problème devient particulièrement sensible avec la bande déformée par shader hors de sa boîte géométrique locale.

Aucun prototype source ajouté. Cette proposition attend un A/B séparé après la validation des changements en cours.
