# Écran — LE CHEMIN (page Duolingo)

> Actualisation18-09 — progression réelle déployée : compte vide au premier
> galet, tout en haut ; puis un galet par séance terminée avec travail.
> Pas d’avance calendaire ni de démo automatique. Récompenses serveur à3/7
> séances par chapitre ; cinq chapitres, trésor final à35. Au-delà, séances
> conservées sans remise à zéro.1074 contrôles Swift,35API PASS ; iPhone à
> qualifier. Référence actuelle (les sections datées suivantes sont historiques) :
> `tools/production/compte-progression-2026-09-18/README.md`.



`Woop/Views/DuolinguoPage.swift` · état partagé `DepartEtat.shared`
(`Woop/Views/DepartSeance.swift`) · nœuds `Woop/Views/GaletEtape.swift` ·
récompenses `Woop/Views/RewardChemin.swift` · **la card de la home**
`Woop/Views/CardRoute.swift` (§ 8 bis).

> **La source unique** (29-08). Ce qu'un nœud EST — son état, sa date, son
> glyphe — et ce qu'un chapitre RACONTE — son nom, son compte — vivent dans
> `EcranSpec.Lecture` et `EcranSpec.apercu`, pas dans la page. C'est ce qui
> permet à la card de la home de dire exactement la même chose que la route :
> deux objets qui doivent s'accorder LISENT la même source, ils ne recopient
> pas la même intention.

> **Convention de ce document.** Ce qui est écrit sans marque est **vérifié
> dans le code** (`fichier:ligne`, relevés le 30-08 — ceux de `WoopApp.swift`
> bougent, une autre session l'édite : à re-relever avant de s'y fier). Ce qui
> porte **?** n'est pas sûr et attend une décision ou une vérification. Ce qui
> porte **CIBLE** est ce que Kathryn a **tranché le 30-08**
> (`tools/annonces/PLAN-COFFRE-ANNONCES.md` — §0 ses mots, §1 les dix défauts
> acceptés, §5.1 la chaîne, §6 le jalon J3) et qui **n'existe pas encore** —
> la section [Flow de fin de séance](#6--flow-de-fin-de-séance) dit
> précisément où le code s'arrête aujourd'hui. Ce qui porte **PÉRIMÉ** est
> gardé pour l'histoire, avec le commit ou la date qui l'a rendu faux.
> Les tables de la base ne sont pas décrites ici : seulement ce que le backend
> doit **décider** et **renvoyer**.

> **Révisé le 30-08.** Deux commits et une décision ont rendu faux ce que
> cette fiche disait la veille : `8e8a0cc` (la story est dans la vraie chaîne
> de fin de séance), `9ef6da1` (le chemin tire au serveur), et le plan du 30-08
> (la page noire, le retour sur le chemin, « Ouvrir » droit au manège, la
> dalle après la card). Les § 3, 4, 5, 6 et 7 sont réécrits à cette lumière ;
> **rien de la cible n'est codé** — c'est le jalon J3 du plan.

---

## 1 · Rôle

Le journal de progression, et le seul endroit où l'app **raconte le temps**.
Il répond à trois questions, dans cet ordre :

1. **Où j'en suis** — quel jour est aujourd'hui, ce qui est derrière, ce qui
   reste.
2. **Qu'est-ce que je fais maintenant** — c'est d'ici qu'on démarre une séance.
3. **Qu'est-ce que j'ai gagné** — les nœuds de récompense s'allument sur le
   chemin, on ne va pas les chercher ailleurs.

C'est aussi l'écran de **retour** du parcours : la fin de séance y ramène
(CIBLE 30-08 — aujourd'hui elle ramène à la **home**, § 6.1), et c'est là que
la pop-up « Ouvrir » se propose.

---

## 2 · Affiche

**La structure.** Cinq écrans (« chapitres ») empilés verticalement, 9 nœuds
chacun, en serpentin. Le chemin **descend** : le passé est en haut, l'avenir
en bas. Composition d'un chapitre : `S S S ◆ S S S S ☾` — **sept séances**,
une récompense au rang 3 (**pièce** sur les chapitres pairs, **lune** sur les
impairs) et le **trésor** de fin au rang 8. Deux récompenses par chapitre, pas
plus.

**Les huit états d'un nœud** (`etatDe`, `DuolinguoPage.swift:1472`) :

| État | Quand | Ce qu'on voit | Date affichée |
|---|---|---|---|
| `accompli` | jour passé, séance terminée | nacre calme, anneau fermé | **son estampille réelle** |
| `parfait` | ? — l'état existe dans `EtatGalet` mais **rien ne le produit** dans `etatDe` | souffle d'or dans le liseré | ? |
| `rate` | jour passé, aucune séance | encre presque fantôme | date dérivée du rang |
| `actif` | aujourd'hui | **la seule pierre entière** — anneau plein, halo 0,72 | la date du jour, calculée à l'affichage |
| `prochain` | la séance juste après aujourd'hui | flamme, glyphe à 30 % | **aucune** |
| `verrouille` | tout le reste du futur | flamme, obsidienne | **aucune** |
| `lune(dispo:)` / `piece(dispo:)` | nœud spécial non réclamé | halo **0,62** si `dispo`, éteint sinon | jamais de date |
| `reclame` | nœud spécial déjà réclamé | gravé, éteint | jamais de date |

⚠️ **La date est un ESTAMPILLAGE, pas une position.** Un jour à venir
n'affiche **aucune date** — « les jours apparaissent le jour où le user a
terminé sa séance ». Un jour fait porte **sa** date de complétion, remontée
avec lui.

**Le panneau** (overlay au tap d'un nœud) : une mini-card calendrier, un titre,
un CTA, un secondaire. Tout est en anglais.

| Nœud tapé | Titre | CTA | Secondaire |
|---|---|---|---|
| aujourd'hui | `Today's session` | `Start` | `Later` |
| jour fait / raté | `Session done` | `View` | `Later` |
| récompense **disponible** | `Nosfy has something for you` | `Claim` | `Close` |
| récompense **éteinte** | `Nosfy has something for you` | *aucun* + sous-titre `Reach this step to unlock your reward` | `Close` |
| récompense **réclamée** | idem | *aucun* + `Reward already claimed` | `Close` |

**Le halo du panneau** ne s'allume que sur *aujourd'hui* et sur une récompense
prête.

---

## 3 · Actions

> **Révisé le 30-08.** Le claim d'une récompense est **tiré ET crédité côté
> serveur** (`tirer_noeud_chemin`, `9ef6da1`, § 7.3-7.4) ; les nœuds déjà
> payés sont **relus du serveur** à l'`onAppear` de la home (§ 7.5). Tout le
> reste de l'écran — l'étape du jour, les jours faits, les dates — est encore
> **entièrement local** : SwiftData pour les séances, `UserDefaults` pour le
> chemin.

| Action | Ce qui se passe | Appel backend |
|---|---|---|
| **Tap sur un nœud** | ouvre le panneau. Un nœud à venir tapé pendant qu'un panneau est ouvert le **ferme** (le vide et l'inutile ferment pareil) | aucun |
| **`Start`** | ouvre une séance en base si aucune n'est ouverte, ferme la route, bascule sur l'onglet Exercices | aucun — écriture SwiftData locale |
| **`View`** | ? — le CTA existe, **je n'ai pas vérifié** ce qu'il ouvre réellement pour un jour passé | ? |
| **`Claim`** | `RewardCheminEtat.reclamer(id, pieces:)` (`RewardChemin.swift:191-221`) : si le journal local connaît déjà ce nœud, le relit ; sinon, avec un compte, **attend le serveur** (appel synchrone — la révélation a besoin du résultat), relit les soldes (`EconomieWoop.rafraichir`, :229), puis ouvre la card. `false` = rien n'est réclamé, la card ne s'ouvre pas, haptique d'avertissement, le galet **reste disponible** (`WoopApp.swift:678-688` : `depart.reclamer(id)` n'est appelé que sur `true`). Sans compte (`-demoData`) : le tirage local d'hier (`TirageRecompense.tirer`, :203-209), **montré, jamais posté** (:213-219) | **`tirer_noeud_chemin(p_noeud, p_pieces)`** (`SacreServeur.swift:141-145`) : le serveur tire, dérive la pitié de SON journal, crédite, rend `{deja_reclame, type, montant, monnaie, robes, rarete, solde, solde_argent}` — rejoué, le même. **PÉRIMÉ depuis `9ef6da1`** : « le tirage reste au front, `reclamer_noeud_chemin` par l'outbox » — `poster(noeud:)` est mort (`RewardChemin.swift:237-241`) |
| **Ranger Nosfy dans la card** | arme le grattage | aucun |
| **Gratter** | révèle. **Ne décide rien** — la récompense était déjà tirée au `Claim` | aucun |
| **Porter un galet (maintien + drag)** | le jouet — tous les galets se portent, ils reviennent en place | aucun |
| **Geste vers la droite** | quitte le chemin | aucun |
| **Tap dans le vide** | ferme le panneau | aucun |

---

## 4 · Sorties

| Depuis | Vers |
|---|---|
| `Start` | **onglet Exercices**, séance ouverte |
| `Claim` sur une lune ou une pièce | **la card à gratter**, par-dessus le chemin (le chemin reste monté dessous) — sur un tirage rendu par le serveur (`9ef6da1`, § 3) |
| Fermeture de la card | **retour au chemin**, et — pour un tirage en **pièces seulement** — la capsule `notifPieces = montant` à +0,3 s, retirée à +3,5 s (`RewardChemin.swift:281-296`) ; **rien** pour un tirage en sachets. **CIBLE 30-08** (plan §0 « nœud du chemin », §3, §5.4 pt 13) : la card à gratter **ET une dalle après** — robe pièces (« +176 ») ou robe **booster** (à coder) selon le tirage — et on **reste sur le chemin**. **PÉRIMÉ (tranché le 30-08)** : « un toaster des gains puis redirection immédiate vers le COFFRE » (cible 28-08) — abandonné, aucune redirection |
| Geste vers la droite / retour | **la home** |
| `Later` / `Close` | reste sur le chemin |

---

## 5 · États

| État | Aujourd'hui |
|---|---|
| **Chargement** | ⚠️ **il n'y en a pas.** `etapeEtFaits` est un calcul synchrone sur les séances locales : la page s'affiche pleine ou fausse, jamais « en cours ». Le **claim**, lui, attend le serveur (§ 3) sans état visible vérifié (**?**). À prévoir quand le chemin viendra du serveur — et la CIBLE 30-08 met « un petit chargement » sur la **page noire** d'avant le chemin (§ 6.2), pas sur la route |
| **Vide** (aucune séance jamais faite) | le chemin **commence aujourd'hui** : rang 0 = actif, tout le reste verrouillé, les deux récompenses éteintes |
| **Démo** (historique non vide seulement, provisoire) | deux séances faites, la troisième en cours, le reste en flamme. `-cheminReel` bascule sur la vraie dérivation par dates. ⚠️ **La démo existe parce que la base contient des séances vieilles de plusieurs semaines** : compter les jours depuis la première envoyait le chemin au chapitre 5, tout allumé |
| **Erreur** | **Révisé `9ef6da1`.** Le claim **attend** le serveur ; un échec — réseau, ou une réponse `200 {raison: noeud_invalide / piste_invalide}` que `depuisServeur` traduit en `nil` (`RewardChemin.swift:34-35`) — rend `false` : haptique d'avertissement, la card ne s'ouvre pas, le nœud n'est pas marqué réclamé (`RewardChemin.swift:196-199`, `WoopApp.swift:678-688`). Le commentaire `WoopApp.swift:671-677` dit que la page grave le galet au tap et le **dégrave** sur `false` ; ce geste dans `DuolinguoPage` n'a pas été relu le 30-08 (**?**). Pas de message à l'écran. **PÉRIMÉ** : « le claim part par l'outbox, l'écran affiche le gain tout de suite et ne saura pas s'il est refusé » |
| **Au-delà du chemin** | borné à 5 × 9 nœuds = **35 séances**. ? — ce qui se passe à la 36ᵉ n'est pas défini |

---

## 6 · Flow de fin de séance

C'est le flow dont cette page dépend. **Il ne fait pas ce qui est décrit en
6.2** — voici les deux versions côte à côte, relevées le 30-08.

### 6.1 · Ce que le code fait AUJOURD'HUI (relevé le 30-08)

`WoopApp.swift:455-536 terminerSeance()` :

```
Stop dans le player  →  card STOP  →  « Terminer »
   ├─ ferme le panneau de pause, écrit endedAt, sauve (SwiftData)    :476-480
   ├─ WorkoutActivityController.end()                                 :481
   ├─ gain = séries PAYANTES × piecesParSerie (taux lu du serveur)    :472-473
   ├─ si gain > 0 : WoopCelebration.workoutFinished()                 :485
   ├─ selection = .home            ← RETOUR HOME, immédiat            :489
   │    et celebrateFinishedWorkout() (:1666-1673, appelée :1501-1503)
   │    force .home UNE SECONDE FOIS                                  :1669
   ├─ Task.detached : push([snapshot]) PUIS cloturer_seance           :510-513
   │    jamais attendus ; la réponse EST lue (OutboxGains → EconomieWoop)
   │    mais AUCUNE annonce ne la regarde — la pièce d'argent finit dans un print
   ├─ gain == 0 : fin — rien ne se propose                            :514
   ├─ maquetteBoosters += 1 (la réserve MAQUETTE, sans compte)        :524
   ├─ +2,0 s : storyFin = StoryLaunch(workout:)  ← LA STORY, zIndex 15   :532-535, :565-575
   └─ à sa fermeture : enchainerApresStory()  — SUR LA HOME           :543-556
        ├─ +0,3 s : notifPieces = gain   (le calcul LOCAL, pas la réponse serveur)
        ├─ +3,3 s : notifPieces = nil
        └─ +3,4 s : SacreEtat.proposer()  (la card booster, zIndex 6 — :1265-1282)
```

**Le gain est `séries payantes × taux serveur`** (`Workout.seriesPayantes`,
`EconomieWoop.piecesParSerie`), et une séance sans série ne propose rien.

**Côté chemin, rien** : `DuolinguoPage` n'a aucune séquence « séance
terminée » — `:1951-1996` est la cascade d'OUVERTURE (`naissance`), qui joue à
chaque montée de la route ; `rafraichirReclamees()` ne part qu'à l'`onAppear`
de la home (`HomeNuit.swift:2400`, le `Task` :2500-2507) ; le seul mouvement
post-séance de l'app est le **pas de la card ROUTE** dans `rendreLaHome()`
(`HomeNuit.swift:2566-2613`, à +0,8 s) — c'est le modèle de l'animation à
venir (§ 6.2).

**Un seul créneau d'annonce** : `notifPieces: Int?` (`DepartSeance.swift:43`,
hôte `WoopApp.swift:1237-1244`, zIndex 9) — une seconde écriture **écrase** la
première ; robe pièces seule. Il n'y a **pas** de page noire : le noir de la
story n'est que son fond, elle se ferme sur le BUTIN
(`StoryFlow.swift:275-307`).

### 6.2 · Le flow CIBLE (tranché le 30-08)

Plan `tools/annonces/PLAN-COFFRE-ANNONCES.md` — §0 « la fin de séance »,
Q4 et Q6 acceptées, §5.1 points 3 à 6, jalon **J3**. **Rien n'en est codé.**

```
Stop (n'importe quel player)  →  card STOP  →  « Terminer »
        ↓
   LA STORY   (existe : 8e8a0cc, à +2,0 s)
        ↓   à sa fermeture
   LA PAGE NOIRE   (nouvelle — `PileAnnonces`, zIndex entre la story 15 et la poussière 20)
        │   fond noir, « un petit chargement » : elle ATTEND la réponse de
        │   cloturer_seance (borne 4 s ; hors ligne ou sans compte : repli
        │   « local », dit comme tel). Les dalles S'EMPILENT, une par événement :
        │   pièces → sachet(s) (forfaitaire, + convertis à 100) → pièce d'argent (1/30)
        ↓
   LE CHEMIN   (cette page — plus la home)
        │   actualisation (rafraichirReclamees À LA CLÔTURE, pas seulement à l'onAppear)
        │   + animation « séance terminée » : la pierre du jour s'ESTAMPILLE,
        │   la suivante prend le halo, la colonne avance d'un pas
        ↓   à la fin de l'animation (signal « route posée »)
   POP-UP « Ouvrir »   — une INVITATION (« ton sachet t'attend ») : le sachet
        │   a déjà été annoncé dans la pile, ce n'est pas une seconde annonce (Q4)
        ↓ tap
   LE MANÈGE   — DROIT, sans escale (Q6)
        ↓
   PROFIL — il voit sa carte collectée
```

Le nœud lune « mis en avant » au retour (cible du 28-08) **n'est pas tranché
le 30-08** — le plan n'en parle pas. Ce qui existe : § 23 « l'arrivée
propose » (`DuolinguoPage.swift:1981-1996`) — branchée, une fois la cascade
posée, le panneau naît sur le galet **actif**, pas sur la récompense. **?**

### 6.3 · Les écarts à combler (état du 30-08)

1. ~~**`terminerSeance` va à la home, pas à la story.**~~ **MORT depuis
   `8e8a0cc`** : la story est dans la chaîne, à +2,0 s (`:532-535`) — elle
   n'est plus lancée « que depuis le calendrier ». Ce qui reste vrai : l'app
   **atterrit sur la HOME**, deux fois (`selection = .home` :489 dans
   `terminerSeance`, et :1669 dans `celebrateFinishedWorkout`).
2. **Rien ne ramène au chemin** après la story — toujours vrai. La route n'a
   aucune séquence de fin de séance, et la lecture `cheminEtat` vit dans
   `HomeNuit` (`:3868`), pas à la racine — à partager (plan §5.1 pt 4).
3. **La pop-up booster s'ouvre sur la HOME**, à +3,4 s après la story
   (`:553-555`) — pas sur le chemin, pas au bout d'une animation.
4. **La page noire n'existe pas** : un créneau `notifPieces` (robe pièces,
   écrasé par la seconde écriture), et **rien ne regarde la réponse de
   `cloturer_seance`** — le sachet forfaitaire, la pièce d'argent, les sachets
   convertis n'ont aucune dalle ; les robes booster et argent ne sont pas
   codées (plan §2.1, §5.1 pt 1-3). Fiche : [notification.md](notification.md).
5. **Le coffre n'a toujours aucun point d'entrée** : les onglets sont
   `home · exercises · progress · profile` (`WoopApp.swift:114`), `CoffreV2`
   ne se monte que par le banc `-coffre2` (`:234`, `:890`), l'ancien
   `CoffreFortFlow` s'ouvre depuis la pièce du profil (`ProfilLune.swift:295`).
   **Mais depuis le 30-08 ce n'est plus un écart de CE flow** : « Ouvrir » va
   droit au manège (Q6). Sa fiche : [coffre-rewards.md](coffre-rewards.md).
6. **Le nœud lune n'est pas mis en avant** au retour — et ce n'est pas
   tranché (§ 6.2).

**PÉRIMÉ — tranché le 28-08, retranché le 30-08 (Q6).** Le 28-08 disait :
« le coffre est une étape AVANT le manège ; la pop-up mène au coffre, on y
voit ses gains, et c'est de là qu'on ouvre le booster ». Ses mots du 30-08
n'en parlent plus ; le défaut accepté est **« Ouvrir » va droit au manège,
comme le code le fait aujourd'hui**. L'escale coffre est abandonnée.

<details>
<summary>Historique — la cible dictée le 28-08 (périmée le 30-08)</summary>

```
Stop  →  overlay  →  « Terminer »
        ↓
   STORY 2
        ↓
   LE CHEMIN
        ↓   à l'arrivée, immédiatement
   POP-UP « ouvrir un booster »
        ↓ tap
   LE COFFRE — il voit ses gains, et un bouton « ouvrir booster »   ← abandonné (Q6)
        ↓
   LE MANÈGE
        ↓
   PROFIL
        ↓ il revient sur le chemin
   LE NŒUD LUNE MIS EN AVANT — overlay + Nosfy : « tu peux claim »   ← non tranché
        ↓ Claim → card à gratter → révélation
   TOASTER des gains  →  LE COFFRE, immédiatement                    ← abandonné (§ 4)
```

Ce qui l'a rendue fausse : `8e8a0cc` (la story existe), puis le plan du 30-08
(la page noire s'intercale, l'escale coffre tombe, la dalle du nœud reste sur
le chemin).
</details>

---

## 7 · Les récompenses — tous les cas

### 7.1 · Les quatre états d'un nœud de récompense

| État | Signification | Ce que le backend doit trancher |
|---|---|---|
| `locked` | les séances d'avant ne sont pas toutes faites | la condition de déblocage — aujourd'hui `etape > id`, c'est-à-dire **le chemin a dépassé le nœud** |
| `available` | le halo respire, `Claim` est offert | — |
| `claiming` | l'aller-retour serveur (`tirer_noeud_chemin`, synchrone depuis `9ef6da1`) | **un échec REVIENT à `available`** — c'est ce que fait le code : `reclamer` rend `false`, rien n'est gravé (`RewardChemin.swift:196-199`, `WoopApp.swift:678-688`) |
| `claimed` | créditée. La card se rouvre **sans se re-gratter** | l'idempotence : rejouer un claim ne redonne rien |

### 7.2 · Ce que le tirage produit

Deux pistes séparées, selon la nature du nœud. **Depuis `9ef6da1` ces taux
vivent en base** (`reward_rules` : `chemin_taux_piece_noire 0.06` ·
`chemin_taux_rare 0.11` · `chemin_taux_double_legendaire 0.01` ·
`chemin_pitie 12` · `chemin_pieces_min/max 100/200` — posés par la migration
`20260830160000_sachet_scelle_et_tirage.sql:39-49`, lus par
`tirer_noeud_chemin` :302-317 ; sondés le 30-08 14:36, carte du serveur) ; le
tableau ci-dessous est la lecture de la même règle.

**Piste PIÈCES** (nœud `piece`) :

| Cas | Taux | Payload |
|---|---|---|
| commun | 94 % | `coins` · `standard` · **100 à 200** |
| pièce d'argent | **6 %** | `coins` · `black` · **1** · `legendary` |

**Piste BOOSTERS** (nœuds `lune` et `tresor`) :

| Cas | Taux | Payload |
|---|---|---|
| commun | 88 % | `[orange, orange]` |
| rare | **11 %** | `[orange, legendaryBlack]` · `rare` |
| double légendaire | **1 %** | `[legendaryBlack, legendaryBlack]` · `legendary` |

**La pitié** : après **12** nœuds communs d'affilée **sur une piste**, le taux
rare **double à chaque nœud suivant** jusqu'à ce qu'il tombe, puis se remet à
zéro. Par utilisateur ET par piste — et **dérivée du journal serveur, jamais
un compteur** (migration :321-343). Les compteurs locaux `chemin.secs.*` ne
servent plus que la maquette sans compte (§ 7.5).

### 7.3 · Ce que le backend doit garantir

> **La règle qui commande tout : la récompense est TIRÉE AU CLAIM, jamais par
> l'animation.** Le grattage ne décide rien — il révèle une décision déjà prise
> et déjà créditée.

Ce que l'appel de claim doit faire, en un seul aller-retour — **et ce que
`tirer_noeud_chemin` fait depuis `9ef6da1`** (sondée le 30-08 14:35,
`tools/sacre/verif_backend_sachet.py`, 22 ✓, compte de test — la preuve est
sur la carte du serveur, `b-fn-tirer-noeud-chemin`) :

1. **Vérifier le droit** — le nœud est-il vraiment dépassé pour cet
   utilisateur ? Le front ne doit pas pouvoir réclamer un nœud verrouillé.
   **Partiel** : le serveur borne le nœud (0-44 ; `9001 → noeud_invalide`) et
   le rapproche de sa piste (`(3, false) → piste_invalide`) ; « dépassé pour
   CET utilisateur », il ne peut pas le dire — l'étape est dérivée localement
   (§ 8 pt 1), le serveur ne la connaît pas. **?**
2. **Être idempotent par nœud** — un second claim du même nœud **relit** le
   tirage, il n'en fait pas un nouveau. **Fait** : rejouée, même montant,
   `deja_reclame:true`. (Et le journal local `journal[id]` est relu avant
   même d'appeler.)
3. **Tirer** avec les taux ci-dessus, **et tenir la pitié côté serveur** — au
   front elle est falsifiable. **Fait** (§ 7.2 : dérivée du journal).
4. **Créditer dans le même mouvement**, pas à la fin du grattage : tuer l'app
   en plein scratch ne doit pas coûter la récompense. **Fait** : `solde` /
   `solde_argent` reviennent dans la réponse, relus par
   `EconomieWoop.rafraichir` (`RewardChemin.swift:229`).
5. **Renvoyer le payload** : type, monnaie, montant, liste de boosters, rareté.
   **Fait** : `RecompenseTiree.depuisServeur` le traduit sans le corriger
   (`RewardChemin.swift:32-51`, appelée :230).

### 7.4 · Le crédit — le trou est bouché, et voici jusqu'où

> **Historique, et il faut le garder.** La première version de cette fiche
> (28-08) disait : « rien n'est réellement crédité ». C'était exact. La
> fonction `reclamer()` n'écrivait que `UserDefaults` **pendant que la card
> affichait « Added to your balance »** — l'écran mentait sur le gain, et une
> réinstallation rendait tous les nœuds re-réclamables.

**Ce qui existe maintenant** (chantier coffre/gains, 28 et 29-08) :

| Pièce | État |
|---|---|
| `tirer_noeud_chemin(nœud, piste)` | **déployée** — migration `20260830160000_sachet_scelle_et_tirage.sql:186-421`, commit `9ef6da1` ; sondée le 30-08 14:35 (§ 7.3) |
| `reclamer_noeud_chemin(nœud, pièces, monnaie, boosters)` | **déployée** le 28-08 (`20260828190000_gains_coffre.sql`) ; **réécrite** le 30-08 (`20260830160000…sql:471-482`) : elle **ignore** montant, monnaie et robes du client et délègue à `tirer_noeud_chemin` |
| Idempotence par nœud | **tenue côté serveur** : index uniques `coin_ledger_chemin_unique` et `user_boosters_chemin_unique` sur *(utilisateur, nœud)*. C'est la seule raison pour laquelle rejouer la file est sûr |
| `OutboxGains` | **en place** — mais le chemin ne l'alimente plus (voir la ligne suivante) ; son cas `noeudChemin` reste pour vider une file héritée d'une version antérieure (`OutboxGains.swift:213`) |
| L'appel dans `reclamer()` | 29-08 (`97cf6d9`) : le gain partait par l'outbox APRÈS l'ouverture de la card, seul un tirage neuf était posté — **PÉRIMÉ depuis `9ef6da1`** : l'appel est `tirer_noeud_chemin`, **synchrone, AVANT** l'ouverture de la card (`RewardChemin.swift:195-202`) ; `poster(noeud:)` est mort (:237-241) |
| Lecture du solde | `solde_or` / `solde_argent` / `etat_coffre` existent côté serveur (`SacreServeur`) |

**Ce qui reste ouvert, et il faut le dire** :

1. ⚠️ **`CoffreFortPurse.coins(doneSeries:) = séries × 20` existe toujours**
   (`CoffreFortPurse.swift:29`), et le **profil** le lit encore
   (`ProfilLune.swift:129`) ; le plan du 30-08 (§2.4) constate que home et
   profil recalculent chacun un solde local. Tant que ces écrans ne lisent
   pas le solde serveur, **il y a deux vérités sur l'argent** dans l'app — et
   elles ne diront pas le même nombre dès la première récompense créditée.
2. ~~**Le tirage reste au front, donc falsifiable** — la pitié aussi.~~
   **FERMÉ le 30-08 (`9ef6da1`)** : le tirage et la pitié sont au serveur
   (§ 7.2-7.3). Ce qui reste : la maquette sans compte tire encore localement,
   le dit, et **n'écrit rien nulle part** (`RewardChemin.swift:203-219`).
3. ⚠️ **`SacreEtat.boostersEnAttente`** est encore décrémenté à l'ouverture
   d'un sachet (`WoopApp.swift:1338-1339`) ; depuis le 30-08 la réserve
   affichée passe par `EconomieWoop` — `maquetteBoosters` sans compte,
   `boostersServeur` avec (`WoopApp.swift:515-524`). Deux compteurs
   cohabitent ; non relu au-delà le 30-08 (**?**).

### 7.5 · Ce qui reste stocké localement

| Clé | Contenu | Devenir |
|---|---|---|
| `chemin.reclamees` | les ids de nœuds réclamés | **complété par le serveur** : `rafraichirReclamees()` fait l'UNION avec `noeuds_chemin_reclames()` (`DepartSeance.swift:104-116`), appelée à l'`onAppear` de la home (`HomeNuit.swift:2400`, le `Task` :2500-2507) — jamais remplacé (un claim peut dormir dans l'outbox) |
| `chemin.tirages` | le tirage par nœud (le « journal ») | **un cache** : relu AVANT le serveur (`RewardChemin.swift:192-194`) ; perdu à la réinstallation, mais le serveur rend le même tirage au rejeu (`deja_reclame:true`, § 7.3) |
| `chemin.revele` | les nœuds déjà grattés | ? — purement cosmétique, peut rester local |
| `chemin.secs.coins` / `chemin.secs.boosters` | les deux compteurs de pitié | **passé au serveur le 30-08** (`9ef6da1`) : ne servent plus que la maquette sans compte (`RewardChemin.swift:204-207`) |

⚠️ Tout ça est **par appareil**. L'idempotence serveur empêche de **re-payer**
un nœud après réinstallation. **PÉRIMÉ depuis `6557a90`** : « l'app le
réaffichera comme réclamable : le chemin lit `chemin.reclamees`, pas le
serveur » — la home relit `noeuds_chemin_reclames()` à son `onAppear` et
complète la clé locale. Ce qui n'est **pas mesuré** : le tour complet
(réinstaller, ouvrir la route, voir le nœud gravé) — la carte du serveur le
dit 🔵 « sonde 200 [], tour complet non mesuré » (`b-fn-noeuds-reclames`).

---

## 8 · Ce que le backend doit décider pour la page elle-même

Sans ça, la page reste en mode démo.

1. **Où commence un chapitre.** C'est le vrai blocage : la dérivation par
   dates réelles existe (`-cheminReel`) mais envoie au chapitre 5 parce que la
   base contient des séances vieilles de plusieurs semaines. Il faut une
   **origine de chapitre** décidée côté serveur.
2. **Ce qu'est un jour « fait »** — aujourd'hui : au moins une séance terminée
   ce jour-là. **?** Est-ce qu'une séance sans aucune série compte comme faite ?
   (Elle ne rapporte rien et ne propose rien, mais elle a un `endedAt`.)
3. **Ce qu'est un jour `parfait`** — l'état existe dans le code, **rien ne le
   produit**. ? À définir ou à supprimer.
4. **La composition d'un chapitre** — aujourd'hui figée dans le front
   (7 séances + 1 récompense au rang 3 + le trésor). Le jour où le serveur la
   dérive, une seule fonction change.
5. **Le comportement au-delà de 35 séances.** ?

---

## 8 bis · La card ROUTE de la home

`Woop/Views/CardRoute.swift` · lecture partagée `EcranSpec.Lecture` ·
coquille `ArdoiseFond` (`WidgetsCards.swift`).

**Ce qu'elle est.** La troisième card de la home, à la place de l'ardoise
« This week » (mise de côté le 29-08, `-thisWeek` la remonte). Deux lignes —
`CHAPITRE n` et `Étape X sur 9` — et **trois pierres du chemin** : le nœud
d'avant, aujourd'hui au halo, le prochain. C'est aussi **la seule porte de la
route depuis la home** : le tap vit sur la card, jamais sur les galets.

**Les trois règles tranchées le 29-08 :**

1. le galet du milieu porte **une date**, jamais un rang — la loi de la route
   (« la date est un estampillage, pas une position ») ; le rang est dit par le
   texte, à dix points de là ;
2. « étape X sur **9** » compte **tous les nœuds** du chapitre, récompenses
   comprises : le chiffre doit se vérifier au doigt sur la route ;
3. le nœud du haut s'affiche **tel quel**, même éteint — une récompense déjà
   réclamée reste ce qu'il y a juste avant aujourd'hui.

**Rien n'y est recopié de la route.** L'état d'un nœud, sa date, son glyphe, le
nom et le compte du chapitre viennent tous de `EcranSpec.Lecture` /
`EcranSpec.apercu` — les trois `private func` de la page en sont sorties le
29-08 pour ça. La coquille est celle de l'ardoise, extraite elle aussi : les
deux cards sont la MÊME matière, pas deux imitations.

**Les cotes, et pourquoi elles sont ce qu'elles sont** (354 × 138 — l'ardoise
qu'elle remplace en fait 128) :

| Contrainte | Conséquence |
|---|---|
| la poignée du « pull » mange les 112 derniers points | la card ne peut pas dépasser ~220 pt ; elle en fait 138 |
| l'air entre deux pierres vaut `√(A² + pas²) − (r₁+r₂)` | c'est le **serpentin** qui paie l'air, pas le pas — la hauteur, elle, est bornée |
| la route tient **31,6 pt** d'air pour des Ø 62 (rapport 0,51) | l'étalon : la card en tient 30,9 pour des Ø 48/54 |
| le halo vaut 0,95 × Ø et le pad Ø/2 + 26 | **au-delà de Ø 57,8 le halo sort de son cadre** — et ici la card le trancherait |
| le mois vaut 0,125 × Ø, plancher maison 5,5 pt | une pierre qui porte un mois ne descend pas sous Ø 44 → dans la card, **le jour seul** (`GaletEtape.jourSeul`), qui reprend la place du mois à 0,42 × Ø |

⚠️ **Trois pierres ne font pas un serpentin avec le `dx` de la route.** Sa
sinusoïde de période 4 (0, +76, 0, −76) donne **une fois sur deux
(+76, 0, −76) — une diagonale**. La card force l'alternance (les voisines d'un
flanc, l'actif de l'autre) et ne garde de la route que le SENS du virage, pris
sur le rang du jour : il bascule quand on avance.

⚠️ **Les voisines sont COUPÉES par les bords** (la loi des pochettes du bac :
la coupe est un choix). Ça renverse la contrainte de hauteur — entières, les
pierres devaient tomber à Ø 38 ; coupées, elles remontent à 48. Et c'est un
second argument pour le jour seul : une pierre coupée qui porterait le mois
sous son jour se ferait couper le mois.

⚠️ **Une récompense n'y est jamais plus petite qu'une séance.** Le rapport de
la route (pièce 53/62) multiplié par la coupe mettait la pièce à Ø 37,6 et il
n'en restait qu'un croissant. Ce qui distingue une récompense reste son glyphe
et son or, pas sa taille.

**Le galet y est INERTE** (`GaletEtape.inerte` → `allowsHitTesting(false)`) :
sur la home le doigt appartient à la page (le « pull to start ») et à la card
(la porte). Un galet qui garderait ses deux gestes mangerait les deux — c'est
le piège du bouton sous le drag d'ancêtre, et le bug des mini-cards qui
volaient déjà cette porte.

**Ce qu'elle coûte.** Mesuré au simulateur, A/B sur le même build contre
l'ardoise qu'elle remplace : **10,2 contre 10,9 img/s** en régime établi —
aucune régression mesurable. ⚠️ Les ~10 img/s absolus sont un artefact du
simulateur ; le juge reste le téléphone.

**Ce qu'elle ne sait pas encore dire.** Sans `-cheminReel`, elle affiche la
DÉMO du chemin — donc « Chapitre 1 · étape 3 » en permanence, sur la home, pas
seulement quand on ouvre la route. Le blocage est celui du § 8 : personne ne
dit où commence un chapitre.

> **Corrigé au passage (29-08).** La démo semait comme « jours faits » les deux
> séances les plus récentes, **aujourd'hui compris** : deux pierres voisines
> affichaient le même jour, à deux états différents. La dérivation réelle ne
> pouvait pas avoir ce défaut — son `guard i < etape` écarte la séance du jour ;
> la démo n'avait pas la garde. Elle l'a.

---

## 9 · Bancs

| Argument | Effet |
|---|---|
| `-homeChemin` | ouvre la page directement |
| `-homeChemin -duoEtape n` | branchée, à l'étape *n* |
| `-cheminReel` | dérive le chemin des **vraies** dates au lieu de la démo |
| `-duoLab` / `-duoGalets` | la page et les galets seuls |
| `-jouetSonde` | trace contact / PRISE / port / LÂCHER dans la console |
| `-rewardChemin <cas>` | force un tirage : `coins` · `black` · `boosters` · `rare` · `legendary` |
| `-rewardChemin <cas>R` | idem, card **déjà grattée** |
| `-duoLab -routeCard <cas>` | la **card ROUTE** seule : `debut` · `milieu` · `apresReward` · `finChapitre` · `chap2` |
| `-duoLab -routeCard <cas> -planche` | les réglages de géométrie côte à côte, l'air CALCULÉ sous chacun, et le fantôme de l'ardoise (354 × 128) par-dessus |
| `-duoLab -routeCard <cas> -planCas` | le même réglage dans quatre situations du chemin |
| `-duoLab -duoGalets -vitrine` | le galet HORS de la route : l'échelle des tailles, les cotes de l'encre, et trois compteurs qui prouvent l'inertie au doigt |
| `-thisWeek` | remonte l'ardoise « This week » à la place de la card ROUTE |

Simulateurs dédiés : **`kat-road`**, et **`kat-cardroute`** pour la card
(un chantier, un simulateur — un `install` tue l'app de la session voisine).
Tour de boucle : `./tools/road/voir.sh <args du banc>` (build nu, double
lancement, capture). ⚠️ Sa pause est à **15 s** : la splash dure ~10 s, et à
5 s la capture rendait la LUNE.

⚠️ **Le diff de pixels ne vaut RIEN sur cette page** (mesuré le 29-08) : deux
captures du MÊME build, `-duoFreeze` compris, diffèrent de **37 %** — le film
du verre noir tourne derrière tout, et le gel ne l'arrête pas. Une
non-régression s'y prouve sur les VALEURS (le diff normalisé des deux
implémentations), jamais au pixel. `tools/road/diff_shots.py` le dit en tête.

---

## 10 · À vérifier au téléphone

Rien de ce qui suit n'est jugeable au simulateur, et **rien n'a encore été
validé** : le port d'un galet, le port de Nosfy, le grattage, l'haptique, la
prise des sachets de booster, l'allumage du holo. Et la **cadence réelle** de
la page comme de la card — elle n'a pas été mesurée.

Pour la **card ROUTE** de la home (§ 8 bis), deux verdicts qu'aucune capture ne
peut rendre, et ils décident de son inertie :

1. un **tap sur une pierre** doit ouvrir la route — donc être compté par la
   CARD, jamais par le galet ;
2. un **« pull to start » né sur une pierre** doit partir quand même.

Le banc `-duoLab -duoGalets -vitrine` porte les trois compteurs qui les
tranchent d'un doigt. ⚠️ Ils ne peuvent pas être vérifiés autrement :
`osascript` n'a pas le droit de cliquer sur cette machine (accès d'aide
refusé), et `simctl` ne pose pas de doigt.
