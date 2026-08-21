# ARCHIVE — LA HOME v1 « AURORE + OBSIDIENNE »

Gelée le **2026-08-20** sur ordre de Kathryn, avant la refonte v2 (« Apple
like premium, presque noir, la lumière par la gauche »). Rien n'est
supprimé : cette page reste **rejouable au pixel** par les chemins ci-dessous.
Ce qu'elle a demandé de garder par-dessus tout : **la carte obsidienne et ses
halos jaunes**.

## Les preuves

| Fichier | Ce qu'il montre |
|---|---|
| `shots/home-v1-aurora.jpg` | la page entière, 1206×2622, simulateur `kat-cal-18`, `-skipAuth -demoData` |
| `shots/carte-obsidienne-halos.jpg` | la carte « Objectif hebdomadaire » seule : le halo d'or versé au bord GAUCHE, la matrice de points, la rangée de trophées |
| `etat-arbre-2026-08-20.patch` | le diff `HEAD → arbre de travail` du jour (`Woop/` + `project.pbxproj`), l'état exact capturé |

État git au gel : `HEAD = a734fe2` + l'arbre de travail du patch ci-dessus.
Le binaire capturé : `dd-booster/…/Woop.app`, dylib du 20-08 18:13.

## L'anatomie de la v1 (où vit chaque pièce)

**La page** — `Woop/Views/HomeAuroraView.swift`
- `HomeAuroraView` : salut + coffre, `weeklyCard`, `swapSection`.
- `AuroraHomeBackground` : `Color.black` + `AuroraFloor` + `StarDustCeiling`
  (masqué au bas) + `WoopGrain` ; amorce le gyroscope (`SkyMotion.start`).
- `AuroraFloor` → shader `bgAuroraHome` (**`Woop/AuroraBg.metal:364`**), tilt
  `BgTilt`, naissance `ConnexionCine.birth`.
- `StarDustCeiling` → shader `nebulaStars` (`Woop/DemonSky.metal:561`).

**La carte obsidienne (LA pièce à garder)**
- `ObsidianGlassCard`, `ObsidianSurface`, `ObsidianCardPressStyle` :
  `Woop/Views/ObsidianCard.swift`
- Matière : `obsidianSurface` (**`Woop/ObsidianCard.metal:231`**)
- Banc de réglage : **`-obsidianLab`** (`Woop/Views/ObsidianCardLab.swift`)
- Contenu : `ShimmeringNumber` (`Woop/Views/ObjectiveCard.swift:226`),
  `TrophyRow` (`Woop/Views/HomeView.swift:275`)

**Le reste de la page**
- `CoffreFortCoinButton` (la lune-coffre en haut à droite) :
  `Woop/Views/CoffreFortCoin.swift:37` + la fumée `CoinSmoke`
- `SachetVignette` (le bouton d'essai booster, temporaire) :
  `Woop/Views/BoosterPopup.swift:643`
- `CarnetHome` (le carnet de cuir de la collection) :
  `Woop/Views/CarnetLab.swift:569`, banc `-carnetLab`
- `SwapDeck` + `SwapWorkoutCard` (la pile, remplacée par le carnet mais
  vivante) : ce fichier, banc `-deckLab` / `-deckSwiped` / `-deckBurst`
- `JewelTabBar` + galet play : `Woop/Views/JewelTabBar.swift`, matière
  `Woop/NavMonolith.metal`, banc `-navLab`

## Comment la revoir

```sh
# la page telle qu'elle était, sur le simulateur
xcodebuild -project Woop.xcodeproj -scheme Woop -configuration Debug \
  -destination 'id=E307BE14-B36F-48DE-ABB1-CD933B5C6EAD' \
  -derivedDataPath dd-booster build
xcrun simctl install <UDID> dd-booster/Build/Products/Debug-iphonesimulator/Woop.app
xcrun simctl launch --terminate-running-process <UDID> fr.kathryn.woop -skipAuth -demoData

# la carte obsidienne seule, réglable au doigt
… fr.kathryn.woop -obsidianLab

# le code d'origine, si l'arbre a divergé
git show a734fe2:Woop/Views/HomeAuroraView.swift
git apply tools/home-v1-archive/etat-arbre-2026-08-20.patch   # l'état du gel
```

## Les constantes qui ont fait « trop beau » (à ne pas perdre)

L'aurore v6 « or de néon » (mesurée, pas devinée — outil
`~/Downloads/woop-aurora/mesures/sim2.py`) :
`AU_BASE 1,00/0,54/0,24` · `AU_CREME 1,00/0,90/0,60` · `AU_AMP 1,069` ·
dôme à sommet plat largeur q 0,19, exposant ~2,9 · `LAM_UP 0,105` ·
porte de nuit `smoothstep(0,28 ; 0,55)` · `K = 1,75` · `HAUT_LO 0,60` ·
grain 0,28 · respirations ±7/9 % sur périodes 33 s / 23 s.
Garde-fous tenus : zéro écrêtage (aucun pixel à 3 canaux > 252), reflet des
cartes en `plusLighter` à p95 = 191.

**La v2 ne remplace pas ce fichier : elle vit à côté** (`-homeV2`), le temps
que Kathryn tranche laquelle des deux est la home.
