# PORTE V2 — LE MANÈGE : le vrai carrousel 3D en page 4

Plan dicté le 2026-08-22 au soir. **Rien ne se code tant que ce plan n'a pas le
GO.** Frère de `PLAN-V2-OUVERTURE.md` et `PLAN-V2-VIVANT.md`.

Le verdict, mot pour mot : « la partie de fin des boosters doit être **le vrai
carrousel 3D, le manège qui tourne !!** et on peut **tourner les boosters** —
et **arrivée évidemment cinématique** quand on arrive à son onglet. »

**Ce verdict INVERSE l'arbitrage du premier plan** (§ 4.1 : la vidéo
`booster-loop` en petit). L'ancien arbitrage tombe ; ses raisons ne
disparaissent pas — elles deviennent les contraintes de ce plan-ci.

---

## 1. CE QUE LA RECON A ÉTABLI (lignes vérifiées, pas supposées)

### 1.1 Les bonnes nouvelles — le danger d'hier est plus petit que prévu

- **Le pan ne peut JAMAIS déclencher la cérémonie.** `commitGallery`
  (l'engagement complet : forge serveur, dolly, découpe) n'a qu'UN appelant :
  le tap (`BoosterLab.swift:2537`). Le hold ne s'arme qu'en mode `.idle`,
  inatteignable en galerie. **Tourner au doigt est donc inoffensif par
  construction** — le geste qu'elle demande existe déjà, complet : attraper
  l'anneau (`.galleryScrub`, offset au doigt, crans haptiques, poudre par
  cran), pichenette du sachet central (`.ringSpin`), vol d'inertie borné à
  ±2 crans avec ressort k=170.
- **La cinématique d'arrivée existe, native et complète** : `beginPlacing`
  (`BoosterLab.swift:1861`) — caméra posée loin et haute (0 ; 1,6 ; 7,5),
  rideau du sol, constellation de lunes, la roue qui se dévisse depuis
  −1,45 cran, plongée de caméra avec overshoot (z 3,96 → 4,0), FOV 34 → 42,
  atterrissage haptique + bouffée de poudre à t = 2,6, pose finale à
  **t = 2,9 s** (⚠️ le commentaire « ~1,45 s » au-dessus est PÉRIMÉ — les
  constantes font foi : `placingFlightEnd = 2.6`, `placingPose = 2.9`).
- **L'éclipse de la home ne peut pas se déclencher** : `manegePose` n'est
  publié à la pose QUE si `SacreEtat.manegeOuvert` (l. 2025-2027). Un décor
  monté hors du flow du Sacre ne publie rien.
- Le **gyroscope de la galerie** est déjà celui qu'elle aime : l'anneau
  contre-pivote de ±1,6° avec le poignet (`0,045 × LuneMotion.tilt.x`), bande
  morte 0,0005, crédit LuneMotion à compteur. On le GARDE.

### 1.2 Les trois verrous qui demandent du code (petit, et localisé)

1. **Le tap est dangereux et non désactivable de l'extérieur** : les trois
   recognizers sont installés dans `makeUIView` (pan 1275, tap 1278, hold
   1284), et seuls pan/hold sont retenus par le Coordinator — le tap n'est
   pas exposé. → **flag `panOnly` sur `BoosterStage`** : `makeUIView`
   n'installe QUE le pan. (Le tap deviendra plus tard, s'il plaît, une
   bouffée de poudre + tic haptique — jamais l'engagement.)
2. **La cinématique et la nappe audio sont soudées** : `gallery + still:false`
   démarre `BoosterAmbience` à l'attach (1709-1711), et `placingStep` attend
   0,25 s de nappe (1923). Sur un écran de connexion, la musique du manège
   n'a rien à faire (et l'utilisateur n'a rien demandé). → **flag `muet`** :
   l'attach saute l'ambience, et `placingStep` saute la porte des 0,25 s.
3. **Rejouer la mise en place à chaque arrivée** : `beginPlacing` est privé,
   et `Coordinator.stage` aussi — `BoosterHandle.coordinator` n'expose rien
   d'utile. Deux voies évaluées :
   - ~~(a) remonter la vue avec `.id()` à chaque arrivée~~ — **ÉCARTÉ par le
     coût mesuré** : chaque `BoosterScene.init` recharge `booster.bin` +
     **7 `UIImage(contentsOfFile:)` sans cache** + 10 clones copiés + la
     réflexion du sol, et la première frame **compile les pipelines Metal**
     (c'est pour ça que `placingStep` attend `sceneDidRender`). Payer ça sur
     le fil principal à CHAQUE glissement vers la page 4, c'est le hoquet
     garanti sous le doigt.
   - **(b) une méthode interne d'une ligne** : `func rejoueLaPose()
     { beginPlacing() }` sur le Coordinator, atteignable via
     `BoosterHandle.coordinator`. `beginPlacing` remet lui-même caméra,
     feux, studio et offset à zéro et repart — et pendant qu'il joue, le
     gyro se tait tout seul (il n'écrit qu'en `.galleryIdle`). **C'est la
     voie retenue.**

**Total du code à toucher dans BoosterLab.swift : deux flags et une méthode
d'une ligne.** Rien dans BoosterPack.swift.

---

## 2. L'ARCHITECTURE DANS LA PORTE

### 2.1 Le manège sort du système des créneaux

Les créneaux pair/impair MONTENT et DÉMONTENT au fil du doigt — exactement ce
que le manège ne supporte pas (coût d'instanciation ci-dessus). Il devient
donc un **troisième calque fixe** de `PorteHeader` :

```
PorteHeader
├── créneau A (pages paires : vidéos)         ← inchangé
├── créneau B (pages impaires : vidéos)       ← la page 3 en SORT
└── LE MANÈGE (BoosterStage, monté UNE fois)  ← nouveau calque
      opacity  = proximité(p, 3)   — le même fondu que les créneaux
      paused   = proximité < 0,02  — ⚠️ paused, JAMAIS opacity(0) seul :
                                      une SCNView effacée par l'opacité
                                      rend quand même à 60 fps (payé,
                                      documenté, ProfilLune 976-977)
```

- **Montage paresseux** : le calque n'existe pas tant que `p` n'a jamais
  atteint **2,05** (on ne paie pas bin + textures + compilation au premier
  lancement, où l'utilisateur peut ne jamais visiter la page 4). Une fois
  monté, il RESTE monté — `paused` fait le reste.
- L'appel : `BoosterStage(still: false, gallery: true, panOnly: true,
  muet: true, handle: handlePorte, paused: …)` dans un cadre **402 × 612**.
  ⚠️ Le cadrage z 4,0 / FOV 42° est taillé pour un plein écran ; dans ce
  ratio les voisins ±1 peuvent se couper autrement — à vérifier à la capture
  au jalon M2, curseur = la caméra du décor (recul léger si besoin).
- `allowsHitTesting` : **ACTIF quand la page 4 est posée** (c'est le geste
  demandé), **coupé dès que `p < 2,98`** — pendant un glissement, le doigt
  appartient au scroll. (L'école du géant du profil, qui fait l'inverse pour
  d'autres raisons : zone de toucher dédiée.)
- ⚠️ Le pan du manège vs le scroll horizontal de la pagination : les deux
  veulent le même doigt sur la page 4. Tranché : **sur la page 4 posée, le
  pan HORIZONTAL appartient au manège** (c'est la demande), et la pagination
  se reprend par les zones hors manège (le bas de page, les dots) ou en
  arrivant du bord. Si le téléphone dit que ça coince, le cran de repli est
  une bande de pagination en pied. Verdict M4.

### 2.2 La cinématique d'arrivée — à chaque pose sur la page 4

- Déclencheur : `p` **se pose** sur 3 (franchit 2,98 en montée et s'y
  stabilise), avec anti-spam 1,5 s. → `handle.coordinator?.rejoueLaPose()`.
- La première arrivée n'appelle rien : le montage initial joue déjà
  `beginPlacing` nativement (attach → galerie non-still).
- Pendant la cinématique (2,9 s), le hit-testing reste coupé : on regarde la
  roue se poser, on la touche après. (Elle est interruptible au prochain
  glissement : `paused` la gèle, et le retour la rejouera proprement.)
- Les haptiques de la pose (lock, brake, dust puff) viennent avec —
  gratuites, elles sont dans `placingStep`.

### 2.3 La vie et la mort

- **teardown** : rien à gérer tant que la stratégie est « monté une fois » —
  SwiftUI appelle `dismantleUIView` quand la PORTE se démonte (la connexion).
  ⚠️ L'oublier n'est pas une option douce : un CADisplayLink retient sa
  cible, le coordinateur ne meurt jamais, et **la nappe chanterait par-dessus
  la home pour toujours** (payé le 15-08) — avec `muet`, le risque devient
  CoreMotion qui réveille le fil 60×/s. Le jalon M3 VÉRIFIE le démontage.
- ⚠️ `paused` ne coupe ni le gyroLink ni CoreMotion (seul teardown les rend) :
  budget accepté tant que la porte vit — c'est ~le coût d'une page de l'app
  qui tourne. Mesuré au jalon M3 à la SondeCadence.
- Suspendre le décor si le VRAI Sacre s'ouvre par-dessus : impossible dans la
  porte (le Sacre vit derrière l'auth) — pas de garde à écrire.

### 2.4 Ce que devient la page 4 vidéo

`booster-loop.mp4` reste au bundle (la pop-up l'utilise), mais le créneau
vidéo de la page 3 disparaît. La pose du calque manège avant `sceneDidRender`
est couverte par le **rideau du sol de `beginPlacing`** (il naît noir, studio
éteint) — pas de flash de scène nue par construction ; à vérifier au film M2.

---

## 3. LE BUDGET, DIT FRANCHEMENT

| poste | coût |
|---|---|
| montage initial (une fois, en approche de la page 4) | bin + 7 PNG + 10 clones + compilation pipelines — LE gros ; amorti par le four (mêmes pipelines, déjà chauds dans le process) et par le montage paresseux |
| page 4 posée | ~416 k triangles ×2 (réflexion du sol, resolutionScale 0,4) + gyro 60 Hz — le prix d'un vrai manège, celui que le Sacre paie déjà plein écran |
| pages 1-3 (manège monté, paused) | GPU : zéro (isPlaying=false). CPU : gyroLink + CoreMotion 60 Hz — mesuré au M3 |
| glissement 2→3 | 1 vidéo (créneau A page 2) + flamme + manège qui se réveille |

⚠️ **LE SIMULATEUR NE PEUT PAS JUGER CETTE PAGE** : les omni de SceneKit y
rendent le cube noir (la saga payée du booster), LuneMotion y reste muet, les
haptiques aussi. Le sim vérifie la mécanique (montage, pauses, cadence) ; la
matière, la lumière et le geste se jugent **au téléphone uniquement**.

---

## 4. LES JALONS

| | jalon | vérification |
|---|---|---|
| **M1 ✅** | Les 3 retouches BoosterLab | **FAIT 22-08 soir.** `panOnly` (tap et hold non installés — l'engagement inatteignable par construction), `muet` (pas de nappe, mais `nappeT0` se pose quand même : la porte-nappe de placingStep est une horloge), `rejoueLaPose()` (coupe scroll/ringSpin puis rejoue `beginPlacing`). Le banc `-boosterLab` VIVANT (23,4 % de pixels allumés au smoke test) — les défauts valent false, le flow réel ne les voit pas. |
| **M2 ✅** | Le calque manège dans PorteHeader | **FAIT.** Hors créneaux, opacity = proximité(p,3), `paused` sous 0,02, hors parallaxe (la scène a la sienne : le gyro contre-pivote l'anneau), hit-testing seulement page posée. Le `allowsHitTesting(false)` global du header est descendu sur le ZStack des vidéos — sinon il affamait le manège. Filmé : l'anneau des sachets en page 4, fondus d'entrée/sortie propres, retour page 1 à 60 img/s. |
| **M3 ✅** | La vie | **FAIT, avec UN vrai coût mesuré et déplacé** : la naissance (bin + 7 PNG + compilation pipelines, fil principal) volait **696 ms EN PLEIN GESTE** à p > 2,05 → déplacée **à la pose sur la page 3** (604 ms pendant qu'on lit, le geste suivant à 56-60). Anti-spam 1,5 s sur la pose rejouée ; première pose = la cinématique native du montage. Teardown : structurel (dismantleUIView à la connexion — le chemin payé du 15-08). |
| **M4** | **Verdict téléphone** | ⚠️ LE SIM NE PEUT PAS JUGER CETTE PAGE (omni = cube noir, gyro muet, haptique muette) : la matière, la lumière du studio, le pan vs la pagination, le gyro, les haptiques de pose — tout est M4. Et le souffle de 604 ms à la naissance : à re-mesurer sur l'appareil. |

L'ordre des trois plans V2 : **OUVERTURE d'abord** (O1 est un bug), puis
VIVANT (V1 est une correction), puis MANÈGE (le plus gros morceau, sur une
base saine).
