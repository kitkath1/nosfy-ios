# L'ARCHIVE DE LA PAGE DU TRÉSOR v1

> Figée le 25-08-2026, au jalon C0 du chantier `tools/coffre-v2/`.
> **La v1 doit rester rejouable** — c'est la règle maison, payée sur la home v1.

## Ce qu'il y a ici

| Fichier | Quoi |
|---|---|
| `CoffreFortView.v1.swift` | le fichier COMPLET tel qu'il était avant la refonte (710 lignes, commit `f9f2da9` puis `2edc848`) |
| `coffre-v1.jpg` | la page à l'écran, cérémonie posée (`-coffreLab -coffreSkip`, sim `kat-vitrine`) |

## L'anatomie de la v1, pour la rejouer

**La page** : noir absolu · la cinématique du coffre en gros plan qui vient se
poser en haut (40 % de l'écran) · puis le titre « Ton trésor », son sous-titre
en deux lignes imposées, la grosse pièce vivante avec son reflet, et la
pastille de BRAVO qui porte le compte.

**Le film** : `Woop/Media/coffre-beau.mp4` — source 4K HEVC 10 bits de Kathryn,
ré-encodée **2560×1440** (parité au pixel : au zoom 2,15 l'écran affiche
2 592 px en 3×), tête d'une seconde coupée, **audio GARDÉ** (« il manque la
musique »), 6,2 Mo.

**La partition** (`CoffreFortCine`, recalée le 18-08 sur la dramaturgie
mesurée du fichier — noir jusqu'à 1,33 s, pic 5,42 s, recul jusqu'à la fin) :

| | |
|---|---|
| `restScale` | 1,25 *(1,50 essayé et refusé : « trop grosse dans le bandeau »)* |
| `slotRatio` | 0,40 |
| `zoom` / `zoomDrop` | 2,15 / 0,20 |
| `fadeIn` | 0,55 |
| `settleAt` / `settleFor` | 4,60 / 2,40 |
| `contentAt` | 6,85 |

**Le parcours** : `CoffreFortFlow` — un `ScrollView` paginé vertical, deux pages
en `containerRelativeFrame(.vertical)` : le trésor, puis **la page démon**
(`HaloDawnLab`). *(Ce pager MEURT à la v2, verdict Kathryn du 25-08 : « la page
démon aussi, plus besoin là ».)*

**Les bancs** : `-coffreLab` (avec son bouton rejouer) · `-coffreSkip` (le
raccourci part seul à 3 s — le simulateur ne tape pas).

## Ce qui a été SORTI du fichier au jalon C0 (et pourquoi)

Deux pièces vivaient dans ce fichier alors qu'elles servent ailleurs. Les
laisser dedans aurait fait dépendre **dix compilations** du sort d'un écran :

| Sortie vers | Sites consommateurs hors de la page |
|---|---|
| `Woop/Views/CoffreFortPurse.swift` | `HomeAuroraView` · `HomeNuit` · `ProfilLune` · `BravoLab` (`perSeries`) · `SetHistoryRow` |
| `Woop/Views/CinematicPlayer.swift` | `StoryVideo` (×2) · `BravoLab` (×3) |

`CoffreFortFlow(coins:onClose:)` reste, lui, le point d'entrée public de la
page — 4 sites (`HomeNuit`, `HomeAuroraView`, `ProfilLune`, `WoopApp`) — et il
**survivra en enveloppe mince à signature identique** : le pager meurt, pas la
porte.

## Les deux pièges payés sur cette page, à ne pas repayer

1. **`ignoresSafeArea` sur un `GeometryReader` lui fait rendre une encoche de
   ZÉRO.** Le chevron restait collé au bord physique (17 pt au lieu de 63)
   alors que le calcul était juste. Seul le défilement doit fuir la zone sûre,
   jamais le proxy qui mesure.
2. **`scrollPosition(id:)` ne vise pas une page que le `LazyVStack` n'a pas
   encore construite** — le saut ne bougeait pas d'un pixel.

Et un verdict, redit quatre fois avant d'être compris : **le tap sur la vidéo
ne change pas de page** (commit `2edc848`). Il pose la cérémonie et on RESTE
sur le trésor. « La page de détail » de la demande, c'était le trésor FINI.
