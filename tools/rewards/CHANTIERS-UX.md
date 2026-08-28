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

## 7. Le WALLET à deux monnaies — LE FLOW (revu le 28-08)

*Le détail du composant et ses mesures :
[../coffre-v2/PLAN-PIED-COFFRE.md](../coffre-v2/PLAN-PIED-COFFRE.md).*

**Le principe** : ce qu'on récolte se lit à DEUX endroits, et jamais
autrement — **le coffre** (la page entière, une pièce par écran) et **le
profil** (deux pills, en résumé). Le même nombre, une seule source.

### Le parcours

```
        SÉANCE                         TIRAGE SERVEUR (rare)
     20 pièces / série                p ≈ 1/30 séances
           │                                   │
           ▼                                   ▼
     ┌───────────┐                       ┌───────────┐
     │ PIÈCE OR  │  100 pièces = 1       │  PIÈCE    │  1 pièce = 1
     │           │  booster ORANGE       │ LEGENDARY │  booster NOIR
     └─────┬─────┘  (report cumulé)      └─────┬─────┘  (garanti légendaire)
           │                                   │
           ▼                                   ▼
   COFFRE page 1                        COFFRE page 2
   solde · règle · 62/100 · sachets      solde · règle · sachets
           │                                   │
           └──────────────┬────────────────────┘
                          ▼
                PROFIL : deux pills (orange, noire)
                          │
                          ▼
                 MANÈGE de la robe correspondante
```

### Ce que chaque page du coffre montre

| | page OR | page LEGENDARY |
| --- | --- | --- |
| le SOLDE | pièces **disponibles** (plus « earned ») | pièces disponibles |
| la RÈGLE | « 20 par série. 100 pour un booster. » | « Elle tombe rarement. Elle ouvre une légendaire, garantie. » |
| la PROGRESSION | **oui** — 62/100 vers le prochain | **non**, et c'est voulu |
| les BOOSTERS | le sachet ORANGE + le nombre d'ouvrables | le sachet NOIR + le nombre (= le solde) |

### Les trois règles qui tiennent ce flow

1. **« Earned » n'est pas « disponible ».** Dès qu'une pièce s'achète quelque
   chose, le total gagné cesse d'être le solde. C'est le pivot du §0 de
   [PLAN-REWARDS-BACKEND.md](PLAN-REWARDS-BACKEND.md), et le coffre est le
   premier écran où il se voit.
2. **Les deux pages ne sont pas symétriques, et il ne faut pas les forcer.**
   L'or s'accumule (une progression a du sens) ; la legendary tombe (il n'y a
   rien à accumuler). Une jauge sur la page legendary obligerait à exposer le
   *pity timer* — **jamais** : il deviendrait farmable, et la rareté est toute
   la valeur de cette pièce.
3. **Un nombre montré à deux endroits n'existe qu'une fois dans le code.**
   Aujourd'hui le coffre et le profil lisent DEUX maquettes indépendantes
   (`CoffreFortPurse.coins` calculée, `SacreEtat.boostersEnAttente` en
   mémoire) : elles peuvent déjà se contredire à l'écran.

### L'état au 28-08

- la **deuxième pill du profil est POSÉE** (noire + orange, côte à côte) ;
- la page argent du coffre **existe** (`manege = [.or, .argent]`), mais son
  compte est écrit **en dur à « 0 »** ;
- le pied (`PiedCoffre`) porte trois chaînes ; il doit porter **une donnée**
  (solde, règle, progression optionnelle, sachet + compte) ;
- le back-end lui doit `etat_coffre()` et la table `booster_progress`, qui
  **n'a pas été créée** par la migration du 28-08 (§4 undecies).

## 8. WELCOME BACK

Les deux variantes (la pleine avec vidéo portrait + une simple), le
bouton Claim, la pill qui s'anime après le claim.

### 8bis. CE QUE LE WELCOME BACK DONNE : **10 PIÈCES** (28-08)

Verdict : *« quand tu te connectes, à chaque connexion tu manges 10 pièces —
faudra le lier à la pop-up welcome back (les deux variants) et dans le
backend »*.

Le Welcome Back cesse donc d'être une politesse : **c'est un versement.** Il
avait déjà tout ce qu'il faut pour le dire — `RewardPopup(count:unit:)` —, il
passait juste `4 / "Sets"`. Il passera `10 / "Coins"`, dans les DEUX robes
(`WelcomeRobe.video` et `.texte`), et le bouton Claim devient le geste qui
encaisse.

⚠️ **UNE QUESTION À TRANCHER, ET ELLE N'EST PAS COSMÉTIQUE : « à chaque
connexion » est FARMABLE.** Tuer l'app et la relancer est une connexion ;
littéralement appliqué, dix pièces se gagnent en trois secondes, en boucle, et
toute l'économie du coffre (100 pièces = un booster) tombe. La règle qui
tient, et que je recommande : **une fois par JOUR CALENDAIRE**, au premier
lancement du jour. C'est ce que « je me connecte » veut dire pour un humain,
et c'est aussi ce qui rend le retour quotidien désirable.

⚠️ **ET LE CLAIM EST SERVEUR, PAS LOCAL.** Un compteur dans les préférences se
remet à zéro en réinstallant l'app. L'idempotence se pose au même endroit et
avec le même outil que le booster noir : un **index unique partiel** sur
(user, jour) dans `coin_ledger`. Deux appareils le même matin ne créditent
alors qu'une fois — sans verrou, sans transaction longue.

**Conséquence sur la page des gains** (`CoffreV2.pageGains`) : elle dérive
aujourd'hui des SÉANCES (`séries × 20`). Un versement de connexion n'est pas
une séance : il n'y apparaîtrait jamais. **C'est le fait qui force la
bascule** déjà annoncée au §17 du plan coffre — l'historique doit être lu du
`coin_ledger`, pas reconstruit depuis les entraînements. Une ligne « Retour
quotidien · +10 » avec sa date, à côté des « 12 séries · +240 ».

Et le solde du pied du coffre (`variantes`, `dispo`) doit inclure ces pièces —
même remarque, même remède : une seule source, le ledger.

## 9. Le sort de BRAVO (décision produit en attente)

Le plan la retire du flux par défaut. Reste à trancher : recyclée en
mise en scène de Moment « fin d'exo », ou morte. L'envol de fin de
repos (7495c85) pointe encore vers elle.

## 10. Le banc `-rewardScenarios`

Les 9 scénarios du plan produit rejoués en dur : série banale,
Woodchopper terminé, +4 kg, meilleur volume hebdo, 3 × 40 s à 17 km/h,
ON FIRE, bonus +40, pièce noire, Welcome Back. C'est l'outil de
validation de TOUT le reste.
