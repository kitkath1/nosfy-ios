# LES CHANTIERS UX MANQUANTS — ce que le back-end rewards ATTEND

**Écrit le 25-08-2026.** La note demandée par Kathryn : tout ce qui doit
exister côté UI/UX pour que le back-end rewards
([PLAN-REWARDS-BACKEND.md](PLAN-REWARDS-BACKEND.md)) ait un sens. Rien
ici n'est codé ; c'est la liste de commande, en ordre de dépendance.

## 1. L'EXPÉRIENCE HIIT DÉCLARATIVE (décision du 25-08)

Le HIIT va être RETRAVAILLÉ pour être **déclaratif** : l'utilisateur
déclare ce qu'il a réellement fait (intervalles tenus, vitesse, durée) —
aujourd'hui les phases sont seulement *planifiées* (DraftPhase), et le
fact engine n'a rien de vrai à raconter. Ce chantier est LE prérequis
des Moments HIIT (« 3 × 40 s à 17 km/h ») : sans lui, le backend ne
reçoit que du programme, pas de la performance. À designer : le geste de
déclaration (pendant ? après chaque bloc ? en fin de séance ?), et ce
qu'on considère comme « tenu ».

## 2. Le bouton « Terminer » + la persistance (LE TROU CONNU)

`save()` n'est pas atteignable en muscu — « rien n'est écrit avant
Terminer » est la loi, mais le bouton Terminer n'existe pas encore. Le
règlement (`settle_session`) a besoin de ce moment. Sans lui, l'outbox
n'a pas de fin de séance.

## 3. Les PILLS du header (le comportement par défaut, ~60 %)

Les états Liquid Glass : `+20`, pièce animée qui entre dans le wallet,
`+20 · 140 cette séance`, incrément du compteur. Micro-animation,
aucune interruption. C'est la face visible de la loi des 20.

## 4. Les QUATRE variants de pop-up ouverts au contenu variable

Les trois existent (`.halo`, `.neon` — robe brume tranchée, `.galet`).
S'y ajoute **`.spotlight`** (demandé le 25-08) — son plan fin est dans
[PLAN-SPOTLIGHT-V4.md](PLAN-SPOTLIGHT-V4.md) : la lampe suspendue
visible et son cône (réf « 300 TPS »), le chiffre en métal sombre, la
pill de verre d'unité posée dessus, et DANS le chiffre uniquement
**la MATRICE** (réf du 25-08 soir) : une trame de micro-mots presque
noirs qui s'éclairent PAR VAGUES de blanc dégradé, coupées au milieu
des tokens, gyro + drag (le doigt devient une source de vague). Deux
choix à trancher sur captures : blanc ou pointe violette, tokens
aléatoires ou bribes réelles de ses séances.
Tous les quatre variants doivent accepter : gros chiffre, titre,
sous-titre, mini-stat, halo variable, atmosphère, avec ou sans vidéo.

## 5. Les 5 ATMOSPHÈRES en tokens

NEUTRAL / EFFORT / PERFORMANCE / REWARD / RARE — au banc, sur les
quatre variants, avec la loi anti-brun pour les chaudes.

## 6. Le SLOT VIDÉO du header de pop-up

Vidéo fond noir → fondu → corps Liquid Glass, lecture unique, stop sur
la dernière frame, titre/sous-titre dessous. Layout paysage (6 vidéos)
ET layout portrait (`chauve_welcome_back`). La couche halo/âme de
RewardPopup est déjà le slot prévu.

## 7. Le WALLET à deux monnaies

La pièce noire a besoin d'une existence dans le coffre : compteur
`blackCoins` distinct, son animation d'incrément, et l'entrée vers le
booster légendaire.

## 8. WELCOME BACK

Les deux variantes (la pleine avec vidéo portrait + une simple), le
bouton Claim, la pill qui s'anime après le claim.

## 9. Le sort de BRAVO (décision produit en attente)

Le plan la retire du flux par défaut. Reste à trancher : recyclée en
mise en scène de Moment « fin d'exo », ou morte. L'envol de fin de
repos (7495c85) pointe encore vers elle.

## 10. Le banc `-rewardScenarios`

Les 9 scénarios du plan produit rejoués en dur : série banale,
Woodchopper terminé, +4 kg, meilleur volume hebdo, 3 × 40 s à 17 km/h,
ON FIRE, bonus +40, pièce noire, Welcome Back. C'est l'outil de
validation de TOUT le reste.
