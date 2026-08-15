# LE PARCOURS BOOSTER — de la home à la carte posée

**Décidé le 15-08-2026 avec Kathryn.** C'est LA source de vérité du flow.
Le back-end Supabase se lit à travers ce document : chaque étape dit ce
qu'elle demande au serveur. Le « comment » côté base est dans
[SUPABASE-PIPELINE.md](SUPABASE-PIPELINE.md) ; les trous restants dans
[SUPABASE-A-FAIRE.md](SUPABASE-A-FAIRE.md).

Nom du flow : **LE SACRE** (du manège de boosters à la carte posée dans
la collection).

---

## Le parcours en une ligne

    HOME ──▶ pop-up booster ──▶ MANÈGE ──▶ cérémonie ──▶ RÉSULTAT ──▶ envol ──▶ PROFIL (la carte se pose)
      ▲            │                │                       │
      └── Plus tard┘         chevron ┘               chevron ┘
                              (→ HOME)                (→ HOME)

    Reprise différée :  PROFIL ─(pill booster du header)─▶ MANÈGE

**Règle de navigation** : le Manège **n'est pas dans l'onglet Profil**.
Il s'ouvre par-dessus toute l'app, depuis la home comme depuis le profil.
On reste dans le flow où on était.

---

## 1. HOME — le déclenchement

**Aujourd'hui (banc)** : un bouton d'essai dans la ligne du salut ouvre
la pop-up. C'est temporaire et assumé.

**Demain (le vrai)** : la pop-up apparaît quand l'utilisateur termine un
entraînement (le bouton « Terminer » de `ActiveWorkoutView.finish()`).
**Ce branchement n'est PAS fait** : le flow de fin de séance n'est pas
validé. On teste la chaîne bouton par bouton d'abord.

> **Serveur** — rien à cette étape, sauf : savoir s'il y a un booster à
> proposer. À terme, la fin de séance CRÉE le booster (voir §7).

---

## 2. LA POP-UP BOOSTER

Centrée à l'écran (pas ancrée en bas — ce n'est pas un sheet), quatre
coins arrondis à 34 pt, la recette de verre de la maison :
`.glassEffect(.regular.tint(black 0.30))` recouvert du dégradé
noir 0,95 → 0,25, liseré blanc 0,16 → transparent sur le tiers haut.
Même grammaire que le panneau « Recommencer » de la fiche d'exercice
([RestartSheet.swift](../../Woop/Views/RestartSheet.swift)).

- **Header** : la vidéo `video_booster` en boucle (les trois sachets en
  éventail, fumée orangée sur noir), composée en `plusLighter`.
- **Titre / sous-titre** puis le primaire **« Ouvrir un Booster »**
  (`DiamondPrimaryButton`) et, en lien nu, **« Plus tard »**.

**Sorties** :
- *Ouvrir un Booster* → **le Manège** s'ouvre directement (on ne passe
  PAS par l'onglet Profil).
- *Plus tard* / tap hors du panneau → retour à la home. **Le booster
  n'est pas perdu** : il reste réclamable (§6).

> **Serveur** — le nombre de boosters en attente, et le solde de pièces
> si l'ouverture est payante.

---

## 3. LE MANÈGE (le carrousel des sachets)

S'ouvre **au niveau racine de l'app** (au-dessus du `TabView` et de la
barre bijou de [WoopApp.swift](../../Woop/WoopApp.swift)), pas dans un
onglet.

- En **haut à gauche**, le chevron retour — *le même composant que sur la
  page profil et la fiche d'exercice* (`RangeeChips(retour:)` de
  [ChipVerre.swift](../../Woop/Views/ChipVerre.swift)) : c'est la
  grammaire de sortie de la maison.
- **Chevron → HOME.** Directement, quel que soit l'endroit d'où on est
  venu.

> **Serveur** — combien de sachets tournent sur le manège = le nombre de
> boosters **non ouverts** de l'utilisateur.

---

## 4. LA CÉRÉMONIE (l'ouverture)

Engagement du sachet → charge au maintien → découpe → la carte sort et
se pose → musique selon la rareté.

**Pas de bouton retour ici.** Une fois l'ouverture lancée, la séquence va
jusqu'au bout. C'est une décision de mise en scène : on n'interrompt pas
un sacre.

> **Serveur — LE MOMENT CRITIQUE.** C'est ici que le tirage se joue.
> Il doit être **idempotent** : un booster consommé une fois, une seule.
> Le tirage doit **consommer** un booster non ouvert dans la même
> transaction que l'insertion de la carte. Voir la garde d'idempotence
> dans [SUPABASE-PIPELINE.md](SUPABASE-PIPELINE.md).
>
> Ce que l'app doit recevoir : la **rareté** (elle choisit la musique
> AVANT que la carte n'apparaisse), la **famille**, l'**URL de l'art**,
> et **est-ce un doublon**.

---

## 5. LE RÉSULTAT (l'étage d'enregistrement)

La carte au centre, les **lunes de rareté** dessous, le mot **NOUVEAU**
en dégradé blanc si c'est une première, et l'invite au balayage
au-dessus.

- **Chevron retour → HOME** (comme le manège).
- **Balayage vers le haut** → la carte s'incline et s'envole comme un
  avion, écran noir, et l'accueil s'enchaîne.

> **Serveur** — « nouvelle ou doublon » vient de la collection. C'est
> donc la **lecture de `user_cards`** qui décide de l'affichage de
> NOUVEAU. Aujourd'hui c'est un store en mémoire : tout s'oublie au
> relancement.

---

## 6. L'ACCUEIL DANS LE PROFIL (la carte se pose)

L'app bascule sur l'onglet **Profil**, la page défile toute seule
jusqu'au registre de la rareté, la carte descend en fumée et **se clipse
dans le premier emplacement libre**, à la suite des précédentes.
Haptique de sertissage, éclat de pose, le compteur tique.

> **Serveur — la règle du placement.** L'ordre « à la suite » vient de
> `obtained_at` : les cartes d'un registre sont triées par date
> d'obtention, l'emplacement visé est le prochain vide. Les **doublons**
> ne prennent pas un nouvel emplacement : ils incrémentent la pastille
> ×N de la vignette existante.
>
> Les totaux affichés (**4 / 11 / 4 / 6**) sont aujourd'hui **codés en
> dur à trois endroits**. Ils doivent venir du serveur.

---

## 7. LA REPRISE DIFFÉRÉE — si on a dit « Plus tard »

Le booster **n'est jamais perdu**. Deux chemins pour y revenir :

1. **La pill Booster du header du profil** — *nouvelle*, à côté de la
   pill des pièces, sur le même modèle (verre en capsule, contenu
   compact) : le **logo booster 3D** + le **nombre de boosters
   disponibles**. Un clic ouvre **directement le Manège**.
2. **Le booster géant tirable** de la page profil (`TirageBooster`) —
   il existe déjà : on le tire vers le haut, son panneau s'ouvre.

> **Serveur** — le compteur de la pill EST le nombre de boosters non
> ouverts. C'est la même requête que celle du manège (§3). Il doit
> survivre à la fermeture de l'app : c'est exactement pour ça qu'il faut
> une table `user_boosters`.

---

## Ce que le parcours EXIGE du back-end (résumé)

| # | Étape | Ce que l'app demande | Où ça vit |
|---|---|---|---|
| 1 | Fin de séance | créer un booster (une séance = un booster) | `user_boosters` |
| 2 | Pop-up | y a-t-il un booster ? le solde de pièces ? | `user_boosters`, `coin_ledger` |
| 3 | Manège | combien de sachets non ouverts | `user_boosters` |
| 4 | Cérémonie | **ouvrir UN booster, une seule fois** → rareté, famille, art | `open-booster` (garde d'idempotence) |
| 5 | Résultat | nouvelle ou doublon ? | `user_cards` |
| 6 | Accueil | l'ordre des emplacements, les totaux par registre | `user_cards` triée, `cards` |
| 7 | Pill | le compteur qui survit au relancement | `user_boosters` |

**Et le cas réel qu'on ne peut pas ignorer** : la séance se termine
souvent **sans réseau** (la salle). Le booster doit être promis
localement et réclamé au premier lancement connecté.

---

## L'état de l'implémentation (15-08-2026)

**Fait et vérifié** : la cérémonie complète, l'étage de résultat, les
quatre musiques, l'envol, l'accueil dans le profil avec auto-scroll,
descente, fumée et pose au bon emplacement (alignement mesuré à 0,0 pt).

**Ce chantier-ci** : la pop-up, la vidéo, le montage du Manège à la
racine, les deux chevrons, la pill booster, l'état partagé.

**Le piège tranché** — une simple notification (`woop.ouvrirCarrousel
Boosters`) ne suffit pas : le contenu d'un onglet est construit
**paresseusement**, donc au premier clic la page profil n'existe pas
encore et n'écoute personne. On passe par un **état partagé observable**
(`SacreEtat`) lu à la racine de l'app — le Manège n'a plus besoin que
qui que ce soit ait été instancié avant lui.

**Pas fait, volontairement** : le branchement sur le vrai « Terminer »,
et toute la couche Supabase (rien ne se fait sans Kathryn).
