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

## Seconde passe, 17:10 → 17:20 — le manège NOIR (sachet de test), sur son « vas-y »

Son compte n'avait aucun sachet noir : sur sa demande explicite (« teste le manège
noir ici »), UN sachet noir de test a été posé côté serveur (`noir-test-pose.json`,
id `9dd137cd`, origine cadeau, 14:48:22 UTC). Il laisse une légendaire réelle dans
sa collection — à retirer si elle le demande. App relancée avec la sonde à 16:48:22.

Elle a ouvert le noir à ~17:01 : serveur `serveur-apres-noir.json` — sachet ouvert
15:01:43 UTC, révélé 15:01:51, carte `1d5e44d0` **legendary** ; `user_cards` = 3
(rare `6ab3e4be`, common `1ff5a6c5`, legendary `1d5e44d0`). Journal nav
(`nav-20260918-164822.jsonl`, t depuis le lancement) : Profil 785,9 s → manège
794,9 s → carte révélée 808,6 s → envol / retour Profil 815,0 s → carte rouverte
depuis la collection 821,7-831,7 s.

**Le chevron n'apparaît PAS dans le journal** : aucun `selection home` entre le
départ du manège (794,9 s) et la révélation (808,6 s), et une seule ouverture côté
serveur. Soit l'étape n'a pas été faite, soit le tap n'a rien fait — le journal ne
permet pas de trancher ; à lui redemander. Le chevron reste ◌.

Sonde (`vol-20260918-164822.jsonl`, 869 lignes) :

| fenêtre | n | img/s méd (min) | cpu % méd (max) | pire | therm |
|---|---|---|---|---|---|
| home immobile 15-300 s | 281 | 60,1 (59,9) | 9 (14) | 19 ms | 0→1 (à 273 s) |
| home immobile 300-785 s | 478 | 60,1 (60,1) | 9-10 (15) | 17 ms | 0/1 |
| Profil 786-795 s | 8 | 52,5 (**10,1**) | 51,5 (79) | **1010 ms** | 0 |
| coffre noir + film 795-800 s | 5 | 58,1 (55,4) | 40 (56) | 88 ms | 0→1 |
| **manège noir** 800-809 s | 9 | 60,1 (48,3) | **31 (39)** | 199 ms | 1 |
| légendaire → envol 809-815 s | 6 | 60,1 (58,1) | 48,5 (49) | 49 ms | 1 |
| Profil, carte rouverte 815-869 s | 53 | 60,1 (50,2) | 14 (51) | 187 ms | 1 |

- Le manège noir coûte comme l'orange (31 % contre 30 %), à 60 img/s.
- **Deux observations hors périmètre, à transmettre** : (1) la home laissée 13 min
  écran allumé, au câble, à 9 % CPU et 60 img/s, atteint **thermique 1 à 4,5 min**
  (contexte home vérifié : welcome=0, séance=0, story=0) — le câble charge et
  chauffe, la sonde ne dit pas la cause ; (2) **un gel d'1,01 s** à l'ouverture du
  Profil après ces 13 min (img 10, cpu 79 : la relecture de la collection et la
  naissance du géant SceneKit ensemble ?). Ni l'un ni l'autre n'est un verdict.
- **Son verdict d'œil** : le sachet noir dans le manège est « très beau » de loin
  mais « trop mat, pas assez réaliste » — « pas très beau ». C'est un chantier de
  matière (le sachet noir du manège), à ouvrir ; il ne bloque pas le parcours.

Fermé en plus : le manège noir de bout en bout (Ouvrir → légendaire → envol →
collection). Toujours ouvert : le chevron, la coupure réseau, l'endurance.

## Troisième passe, 18:40 → 18:47 — LE CHEVRON pendant le manège (sachet orange de test)

Sur son « vas-y » : un sachet orange de test posé (`orange-test-chevron-pose.json`,
id `74b39e3d`, origine cadeau, 15:37:44 UTC), app du commit 8bbccfb0 relancée avec
la sonde (`nav-20260918-173744.jsonl`, `vol-20260918-173744.jsonl`). Son mot :
« oui c'est good j'ai testé ».

Journal nav (t depuis 17:37:44) : Profil 60,8 s → coffre → **manège 74,6 s →
chevron → `selection home` 75,9 s** → Profil 87,0 s → coffre → manège 97,4 s
(reprise) → carte révélée 106,3 s → envol, retour Profil 110,4 s.

Serveur (`serveur-apres-chevron.json`) : le sachet de test n'a été ouvert QU'UNE
fois — 15:39:23 UTC (= t ≈ 99 s, le second manège), révélé 15:39:31, carte
`f6b1fc9e` ; `user_cards` = 4. Le premier manège, quitté par le chevron, n'a rien
consommé : **le chevron rend la home sans perdre le sachet, et le manège reprend.**

Sonde : thermique 0 sur toute la passe ; manège 1 → chevron 41,5 % CPU (n = 2),
home après le chevron 9 % (60 img/s), reprise du manège 30,5 % (60 img/s, à-coup
153 ms), envol 50 %. Un `gel` de 2 s à t = 18,6 s sur la HOME à 2 % CPU — avant
tout geste Cartes, l'app probablement passée inactive (verrouillage ou lancement) ;
pas le manège.

Fermé : la sortie par le chevron pendant le manège (home, sachet intact, reprise).
Toujours ouvert : la coupure réseau pendant l'ouverture, l'endurance thermique,
ses verdicts d'œil sur le shiny et le contraste des trois familles.
