# Écran — LE CHEMIN (page Duolingo)

`Woop/Views/DuolinguoPage.swift` · état partagé `DepartEtat.shared`
(`Woop/Views/DepartSeance.swift`) · nœuds `Woop/Views/GaletEtape.swift` ·
récompenses `Woop/Views/RewardChemin.swift`.

> **Convention de ce document.** Ce qui est écrit sans marque est **vérifié
> dans le code**. Ce qui porte **?** n'est pas sûr et attend une décision ou
> une vérification. Ce qui porte **CIBLE** est ce que Kathryn a dicté le
> 28-08 et qui **n'existe pas encore** — la section [Flow de fin de séance](#6--flow-de-fin-de-séance)
> dit précisément où le code s'arrête aujourd'hui.
> Les tables de la base ne sont pas décrites ici : seulement ce que le backend
> doit **décider** et **renvoyer**.

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
(CIBLE), et c'est là que la récompense se propose.

---

## 2 · Affiche

**La structure.** Cinq écrans (« chapitres ») empilés verticalement, 9 nœuds
chacun, en serpentin. Le chemin **descend** : le passé est en haut, l'avenir
en bas. Composition d'un chapitre : `S S S ◆ S S S S ☾` — **sept séances**,
une récompense au rang 3 (**pièce** sur les chapitres pairs, **lune** sur les
impairs) et le **trésor** de fin au rang 8. Deux récompenses par chapitre, pas
plus.

**Les huit états d'un nœud** (`etatDe`, `DuolinguoPage.swift:1242`) :

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

> **Révisé le 29-08.** Le claim d'une récompense **s'enregistre désormais côté
> serveur** (§ 7.4). Tout le reste de l'écran — l'étape du jour, les jours
> faits, les dates — est encore **entièrement local** : SwiftData pour les
> séances, `UserDefaults` pour le chemin.

| Action | Ce qui se passe | Appel backend |
|---|---|---|
| **Tap sur un nœud** | ouvre le panneau. Un nœud à venir tapé pendant qu'un panneau est ouvert le **ferme** (le vide et l'inutile ferment pareil) | aucun |
| **`Start`** | ouvre une séance en base si aucune n'est ouverte, ferme la route, bascule sur l'onglet Exercices | aucun — écriture SwiftData locale |
| **`View`** | ? — le CTA existe, **je n'ai pas vérifié** ce qu'il ouvre réellement pour un jour passé | ? |
| **`Claim`** | grave le nœud (`reclamees`), tire, **poste le gain**, puis ouvre la card à gratter | **`reclamer_noeud_chemin(nœud, pièces, monnaie, boosters)`**, par l'outbox. ⚠️ Le **tirage** reste au front (`TirageRecompense.tirer`) : le serveur ENREGISTRE ce que le client a tiré, il ne le décide pas encore |
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
| `Claim` sur une lune ou une pièce | **la card à gratter**, par-dessus le chemin (le chemin reste monté dessous) |
| Fermeture de la card | retour au chemin. **CIBLE : un toaster des gains puis redirection immédiate vers le COFFRE** — n'existe pas |
| Geste vers la droite / retour | **la home** |
| `Later` / `Close` | reste sur le chemin |

---

## 5 · États

| État | Aujourd'hui |
|---|---|
| **Chargement** | ⚠️ **il n'y en a pas.** `etapeEtFaits` est un calcul synchrone sur les séances locales : la page s'affiche pleine ou fausse, jamais « en cours ». À prévoir quand le chemin viendra du serveur |
| **Vide** (aucune séance jamais faite) | le chemin **commence aujourd'hui** : rang 0 = actif, tout le reste verrouillé, les deux récompenses éteintes |
| **Démo** (le défaut, et c'est la règle pour l'instant) | deux séances faites, la troisième en cours, le reste en flamme. `-cheminReel` bascule sur la vraie dérivation par dates. ⚠️ **La démo existe parce que la base contient des séances vieilles de plusieurs semaines** : compter les jours depuis la première envoyait le chemin au chapitre 5, tout allumé |
| **Erreur** | ⚠️ **aucune gestion visible, et c'est un choix** : le claim part par l'**outbox**, donc l'écran n'attend jamais le réseau — il affiche le gain tout de suite et le registre rattrape. En pratique l'état `claiming` du § 7.1 **n'existe pas dans l'UI**. Conséquence à assumer : si le gain est refusé côté serveur, **l'écran ne le saura pas**. ? — faut-il un rattrapage visible, ou l'idempotence suffit-elle ? |
| **Au-delà du chemin** | borné à 5 × 9 nœuds = **35 séances**. ? — ce qui se passe à la 36ᵉ n'est pas défini |

---

## 6 · Flow de fin de séance

C'est le flow dont cette page dépend. **Il ne fait pas ce qui est décrit
ci-dessous** — voici les deux versions côte à côte.

### 6.1 · Ce que le code fait AUJOURD'HUI

`WoopApp.swift:415 terminerSeance()` :

```
Stop dans le player  →  overlay de pause  →  « Terminer »
   ├─ ferme le panneau, écrit endedAt, sauve (SwiftData)
   ├─ WorkoutActivityController.end()
   ├─ si gain > 0 : WoopCelebration.workoutFinished()
   ├─ selection = .home            ← RETOUR HOME, immédiat
   ├─ push([snapshot]) en tâche de fond    ← LE SEUL APPEL BACKEND
   ├─ +1,6 s : notifPieces = séries × 20   (capsule sur la home)
   ├─ +4,6 s : notifPieces = nil
   └─ +5,2 s : SacreEtat.proposer()        (l'overlay booster, SUR LA HOME)
```

**Le gain est `séries × 20`** et une séance sans série ne propose rien.

### 6.2 · Le flow CIBLE (dicté le 28-08)

```
Stop (n'importe quel player)  →  overlay  →  « Terminer »
        ↓
   STORY 2  (l'écran retravaillé — document séparé)
        ↓   même si le user tape très vite, elle va au bout
   LE CHEMIN  (cette page)
        ↓   à l'arrivée, immédiatement
   POP-UP « ouvrir un booster »   (aujourd'hui un overlay → deviendra une pop-up)
        ↓ tap
   LE COFFRE — il voit ses gains, et un bouton « ouvrir booster »
        ↓   (page pas encore commitée — c'est la chambre au trésor)
   LE MANÈGE — flow d'ouverture du booster
        ↓
   PROFIL — il voit sa carte collectée
        ↓ il revient sur le chemin
   LE NŒUD LUNE MIS EN AVANT — overlay + Nosfy : « tu peux claim »
        ↓ Claim → card à gratter → révélation
   TOASTER des gains  →  LE COFFRE, immédiatement
```

### 6.3 · Les cinq écarts à combler

1. **`terminerSeance` va à la home**, pas à la story. `StoryFlow` n'est
   aujourd'hui lancé **que depuis le calendrier** (le portail de `CalLab`) —
   il n'a aucun point d'entrée en fin de séance.
2. **Rien ne ramène au chemin** après la story.
3. **La pop-up booster s'ouvre sur la HOME** (`SacreEtat.proposer()` à
   +5,2 s), pas sur le chemin.
4. ⚠️ **Le coffre n'a toujours aucun point d'entrée.** Les onglets sont
   `home · exercises · progress · profile` — il n'y a pas d'onglet Coffre. Le
   coffre atteignable dans l'app reste l'**ancien** (`CoffreFortFlow`), ouvert
   depuis la pièce du **profil**. La page « Rewards » (`CoffreV2`) a été
   largement retravaillée et commitée le 29-08 (`b4f2c1d`), mais elle n'est
   encore accessible **que par le banc `-coffre2`**. Sa fiche :
   [coffre-rewards.md](coffre-rewards.md).
5. **Le nœud lune n'est pas mis en avant** au retour : le panneau Nosfy existe,
   mais il faut **taper le galet** pour l'ouvrir. Rien ne le propose tout seul.

**TRANCHÉ le 28-08** : le coffre est bien une **étape AVANT le manège**. La
pop-up mène au coffre, on y voit ses gains, et c'est **de là** qu'on ouvre le
booster. Le code fait aujourd'hui pop-up → manège **directement** : il manque
donc cette escale.

---

## 7 · Les récompenses — tous les cas

### 7.1 · Les quatre états d'un nœud de récompense

| État | Signification | Ce que le backend doit trancher |
|---|---|---|
| `locked` | les séances d'avant ne sont pas toutes faites | la condition de déblocage — aujourd'hui `etape > id`, c'est-à-dire **le chemin a dépassé le nœud** |
| `available` | le halo respire, `Claim` est offert | — |
| `claiming` | l'aller-retour serveur, le bouton attend | ⚠️ **un échec REVIENT à `available`** |
| `claimed` | créditée. La card se rouvre **sans se re-gratter** | l'idempotence : rejouer un claim ne redonne rien |

### 7.2 · Ce que le tirage produit

Deux pistes séparées, selon la nature du nœud.

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
zéro. Compteur **par utilisateur ET par piste**.

### 7.3 · Ce que le backend doit garantir

> **La règle qui commande tout : la récompense est TIRÉE AU CLAIM, jamais par
> l'animation.** Le grattage ne décide rien — il révèle une décision déjà prise
> et déjà créditée.

Ce que l'appel de claim doit faire, en un seul aller-retour :

1. **Vérifier le droit** — le nœud est-il vraiment dépassé pour cet
   utilisateur ? Le front ne doit pas pouvoir réclamer un nœud verrouillé.
2. **Être idempotent par nœud** — un second claim du même nœud **relit** le
   tirage, il n'en fait pas un nouveau. (C'est déjà le comportement local :
   `journal[id]` est relu s'il existe.)
3. **Tirer** avec les taux ci-dessus, **et tenir le compteur de pitié
   côté serveur** — au front il est falsifiable.
4. **Créditer dans le même mouvement**, pas à la fin du grattage : tuer l'app
   en plein scratch ne doit pas coûter la récompense.
5. **Renvoyer le payload** : type, monnaie, montant, liste de boosters, rareté.

### 7.4 · Le crédit — le trou est bouché, et voici jusqu'où

> **Historique, et il faut le garder.** La première version de cette fiche
> (28-08) disait : « rien n'est réellement crédité ». C'était exact. La
> fonction `reclamer()` n'écrivait que `UserDefaults` **pendant que la card
> affichait « Added to your balance »** — l'écran mentait sur le gain, et une
> réinstallation rendait tous les nœuds re-réclamables.

**Ce qui existe maintenant** (chantier coffre/gains, 28 et 29-08) :

| Pièce | État |
|---|---|
| `reclamer_noeud_chemin(nœud, pièces, monnaie, boosters)` | **déployée** — migration `20260828190000_gains_coffre.sql` |
| Idempotence par nœud | **tenue côté serveur** : index uniques `coin_ledger_chemin_unique` et `user_boosters_chemin_unique` sur *(utilisateur, nœud)*. C'est la seule raison pour laquelle rejouer la file est sûr |
| `OutboxGains` | **en place** — le gain part par une file, donc jamais perdu si le réseau tombe, jamais doublé |
| L'appel dans `reclamer()` | **commité** le 29-08 (`97cf6d9`) — le gain part APRÈS l'ouverture de la card, et **seul un tirage NEUF est posté** (relire le journal n'est pas un gain) |
| Lecture du solde | `solde_or` / `solde_argent` / `etat_coffre` existent côté serveur (`SacreServeur`) |

**Ce qui reste ouvert, et il faut le dire** :

1. ⚠️ **`CoffreFortPurse.coins(doneSeries:) = séries × 20` existe toujours**, et
   c'est encore lui que lisent la **home** et le **profil**. Tant que ces deux
   écrans ne lisent pas le solde serveur, **il y a deux vérités sur l'argent**
   dans l'app — et elles ne diront pas le même nombre dès la première
   récompense créditée.
2. **Le tirage reste au front, donc falsifiable** — la pitié aussi. Ce qui est
   garanti aujourd'hui, c'est **qu'un nœud ne paie qu'une fois**, quoi que
   raconte l'app. Remonter le tirage au serveur est la cible, pas cette étape.
3. ⚠️ **`SacreEtat.boostersEnAttente` reste un compteur LOCAL**, initialisé à
   `1` en dur. Le serveur reçoit bien les boosters gagnés (`user_boosters`),
   mais la réserve que l'app affiche et décompte ne le lit pas. Même problème
   que le solde : deux vérités.

### 7.5 · Ce qui reste stocké localement

| Clé | Contenu | Devenir |
|---|---|---|
| `chemin.reclamees` | les ids de nœuds réclamés | doublé par le serveur (l'index tient) |
| `chemin.tirages` | le tirage par nœud (le « journal ») | à remonter le jour où le serveur tire |
| `chemin.revele` | les nœuds déjà grattés | ? — purement cosmétique, peut rester local |
| `chemin.secs.coins` / `chemin.secs.boosters` | les deux compteurs de pitié | **doit passer au serveur** — au front il est falsifiable |

⚠️ Tout ça est **par appareil**. L'idempotence serveur empêche désormais de
**re-payer** un nœud après réinstallation, mais l'app, elle, **le réaffichera
comme réclamable** : le chemin lit `chemin.reclamees`, pas le serveur.

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

Simulateur dédié : **`kat-road`**.

---

## 10 · À vérifier au téléphone

Rien de ce qui suit n'est jugeable au simulateur, et **rien n'a encore été
validé** : le port d'un galet, le port de Nosfy, le grattage, l'haptique, la
prise des sachets de booster, l'allumage du holo. Et la **cadence réelle** de
la page comme de la card — elle n'a pas été mesurée.
