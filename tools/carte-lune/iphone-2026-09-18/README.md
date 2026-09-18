# Cartes sur SON iPhone — 18-09, 16:38 → 16:41

Sur « vas-y » de Kathryn. Build Debug de l'arbre partagé (commit 42b370d9 + hunks
non commités des autres sessions), installé sur « iPhone de Frédéric » (iPhone 15,
iOS 26.5), lancé `-sondeVol -ecranEveille -navProbe`, **son compte Apple**
(9f5b775d), aucune remise à zéro, aucune suppression. Relancé `-sansSondeVol` à
16:50, téléphone libéré (MULTI-SESSION.md).

## Ce qu'elle a fait, ce que le serveur dit

Avant (`serveur-avant.json`) : 2 sachets orange intacts (gagnés en séance le 18-09
à 06:40 et 07:48 UTC), 0 noir, 0 carte.

Elle a ouvert les DEUX sachets orange, au doigt, après le film d'arrivée du coffre,
et envoyé les deux cartes dans la collection par l'envol. Son mot : « je crois que
c'est bon » ; elle n'a pas fait la sortie par le chevron (« quand le manège tourne,
j'ai ouvert tout »).

Après (`serveur-apres.json`) : sachet 1 ouvert 14:38:50 UTC, révélé 14:38:58, carte
`6ab3e4be` ; sachet 2 ouvert 14:39:53, révélé 14:40:00, carte `1ff5a6c5` ;
`user_cards` : 2 lignes, chacune liée à son sachet et à sa séance. Rien d'autre
n'a bougé sur le compte.

## La chronologie (journal nav, t depuis le lancement 16:38:03)

| t | ce qui se passe |
|---|---|
| 25 s | Profil ; le géant SceneKit (`role=booster`, alpha 1) rend en continu |
| 41,6 s | coffre orange ouvert (2ᵉ vue SceneKit, la pose du sachet) — à-coup 359 ms |
| 43,9 s | **Ouvrir tapé après le film** → `haptique-booster-demarre` (le manège) |
| 55,0 s | `haptique-carte-demarre` : carte révélée (serveur 14:38:58 ✓) |
| 76 s | envol → retour Profil (`selection profile`, `haptique-carte-arrete`) |
| 94 s | home puis Profil à 96 s |
| 104,7 s | coffre 2 — à-coup 345 ms |
| 107,0 s | manège 2 ; 117,0 s carte révélée (serveur 14:40:00 ✓) ; 124,5 s envol → Profil |
| 130-186 s | Profil immobile, géant SceneKit toujours alpha 1 |

## La sonde (`vol-20260918-163803.jsonl`, 183 lignes, médianes par fenêtre)

| fenêtre | n | img/s méd (min) | cpu % méd (max) | pire | therm |
|---|---|---|---|---|---|
| home immobile 3-25 s | 22 | 60,1 (42,5) | 9 (58) | 312 ms | 0 |
| profil, géant SceneKit 26-41 s | 15 | 60,1 (37,4) | 41 (53) | 212 ms | 0 |
| **manège 1** 44-55 s | 11 | 59,4 (42,0) | **30 (48)** | 354 ms | 0 |
| résultat 1 → envol 55-76 s | 20 | 60,1 (55,2) | 35,5 (49) | 67 ms | 0 |
| profil après envol 77-94 s | 17 | 60,1 (58,1) | 17 (41) | 50 ms | 0 |
| coffre 2 96-107 s | 11 | 59,6 (37,4) | 41 (69) | 345 ms | 0 |
| **manège 2** 107-117 s | 10 | 59,5 (51,2) | **30 (48)** | 123 ms | 0 |
| résultat 2 → envol 117-124 s | 7 | 60,1 (56,2) | 46 (49) | 82 ms | 0 |
| profil immobile après 130-186 s | 56 | 60,1 (46,3) | 39 (64) | 241 ms | 0 |

- **Thermique 0 du début à la fin** (3 min, deux manèges complets), aucun `gel`,
  aucune protection déclenchée. Ce n'est PAS une endurance : trois minutes ne
  disent rien d'une chauffe à dix.
- Les à-coups > 300 ms sont aux **ouvertures du coffre** (41,6 s et 104,7 s : le
  fullScreenCover + le film + la pose SceneKit qui naissent ensemble) et à la
  naissance du manège (46,7 s). Pas de gel, cadence revenue à 60 la seconde suivante.
- Le **Profil immobile à 39 % CPU** avec le géant SceneKit à alpha 1 en rendu
  continu (`rendersContinuously`) est le sujet chauffe connu (CLAUDE.md, « 27-39 % »),
  pas celui de cette passe.
- `cpu` = charge des threads (100 = un cœur), pas l'énergie ; `img` = callbacks
  CADisplayLink, pas les images GPU.

## Ce que ça ferme, ce que ça laisse ouvert

Fermé sur iPhone : Ouvrir au doigt après le film (×2), le manège orange, la
révélation d'une carte officielle, l'envol vers la collection, la cohérence
serveur (sachet → carte → collection), et l'absence de montée thermique sur deux
manèges d'affilée.

Ouvert : le manège **noir** (0 sachet noir sur son compte — rien inventé), la
sortie par le **chevron** pendant le manège, la **coupure réseau** pendant
l'ouverture, l'endurance thermique, et ses verdicts d'œil (shiny, contraste des
trois familles : elle a dit « je crois que c'est bon », pas un verdict par point).
