# LA SORTIE EN POP-UP — le projecteur reste, les mots et le nombre entrent dans une card

*13-09-2026, nuit. « Fais un plan, ne code pas. » Rien de ce qui suit n'est codé.*

## 0. Sa consigne, mot pour mot

> « pour l'écran de fin je pensais garder le **spotlight comme tu as fait qui part du display** —
> mais à la place du texte et du nombre je préfère les mettre dans une **pop-up avec Entrer au
> clic**, même si on clique partout ça rentre (un peu comme la pop-up de rewards tu sais, Welcome
> Back ou de gain) ; et simplement on met le **chiffre en liquid glass, pas de galet** ; on garde
> GO "nom" et LET'S, et **au-dessus le chiffre** en liquid glass (comme une pop-up qui existe
> déjà) ; et **en bas de l'écran, fondue, une grosse pilule noire** (première vidéo de la pilule,
> celle du haut) — mais là tu la mets en bas de l'écran, fondue. Et garde la nouvelle musique
> et tout le reste. »

Ce qui est dit, ligne à ligne :

| elle dit | ça veut dire |
|---|---|
| le spotlight qui part du display | `HaloIle(projecteur:)` + `IleNosfy` flash : **inchangés** |
| une pop-up comme les rewards | **le châssis de `RewardPopup`** — la card 36 pt continue, 80 % de large (332 max), ratio 1,32, la dalle noire + le verre `.regular.tint` + le voile, l'arrivée en 1,45 s qui **tressaille** et **boum** à la pose |
| Entrer au clic, mais partout ça rentre | le bouton **et** le tap n'importe où font la même chose (la loi du scrim de `RewardPopup:224`) |
| le chiffre en liquid glass, pas de galet | **`ChiffreVerre`** (RewardCard:2153) — le verre coulé DANS la silhouette du chiffre, saisissable ; `GaletVerre` sort |
| au-dessus le chiffre, on garde GO / nom / LET'S | dans la card, de haut en bas : **le chiffre de verre · ALLEZ / MARGAUX / GO ! · Entrer** |
| en bas de l'écran, fondue, une grosse pilule noire | **`story-pilule-top.mp4`** (la pilule du haut des pages story — 2648 × 1664, 24 s, 17 Mo) recuite, posée **en bas** de l'écran, fondue dans le noir |
| garde la nouvelle musique et tout le reste | G ou H (à dire), la pluie de diamant, la coupe sur blanc, les taps qui sautent à la fin complète, la porte éteinte |

**TRANCHÉ (13-09, nuit) : ni l'une ni l'autre.** « Je parle de la pilule noire / blanche du
chapitre 1 "le verre noir" dans la route Duolingo — debout, coupée, fondue, en bas de la
dernière page avec la nouvelle pop-up. » C'est **`duo-galet-noir.mp4`** (DuolinguoPage:74, écran
1 « Le verre noir » : 1206 × 1560, 16 s, 24 i/s, 5,0 Mo, poster `duo-galet-noir-poster`) — un
galet de verre noir DEBOUT, blanc en arêtes, **déjà cuit pour l'app et déjà dans le bundle** :
aucun fichier nouveau, aucune cuisson. Il est monochrome — le film reste blanc sur noir.

## 1. Ce qui ne bouge pas

- Le film entier jusqu'à `.fin` (end.mp4), puis `.bienvenue`.
- **L'interrupteur** : à 0,25 s l'anneau flashe, `Haptique.fort()`, le halo se penche en cône — *la lumière avant tout*.
- La **pluie de diamant** plein écran quand la fin est complète ; les **taps avant la fin sautent à la fin complète**, jamais à la home.
- **La sortie** : `partir()` — tap, musique qui s'éteint, poudre, zoom 1,38 vers le centre de la card, voile blanc, coupe à 0,55 s, `onEntrer()`. Puis la racine : porte **éteinte** (corrigé ce soir, posé sur ton téléphone), braises, home.
- La musique G ou H (`NosfyFin.m4a`, `NosfySon.fete`).

## 2. La card — ce qu'elle emprunte, ce qu'elle change

**Elle emprunte à `RewardPopup` (RewardCard.swift) :**

| pièce | où | ce qu'on prend |
|---|---|---|
| la forme | `RewardScene.forme` (:202) | `RoundedRectangle(36, .continuous)`, `l = min(largeur × 0,80, 332)`, `h = l × 1,32` |
| la matière | `carte()` (:252-286) | 1 · dalle noire — 2 · verre `.regular.tint(black 0,40)` en `.dark` — 3 · le voile qui s'ouvre vers le bas |
| la robe | `.spotlight` (:344-361) | **gris en tête, noir au pied** — c'est dans ce gris que le cône du halo « tombe » sur la card |
| l'arrivée | `RewardPopup.onAppear` (:134-140) | `p : 0 → 1` linéaire 1,45 s, `posee` → **secousse** + **boum** (`.heavy`), `Paillettes.announce` |
| le count-up | `valeurCourante` (:246) | le chiffre monte 0 → n entre p = 0,32 et 0,86, un **tick de cadran** par chiffre (`LensChime.flare`) |
| la sortie | `fermer()` (:155-166) | `p → 0` en 0,42 s easeOut ; le chiffre reste **figé** |
| le tap partout | le scrim (:223-224) | ici il n'y a pas de scrim (le film est déjà noir) : c'est **toute la page** qui est tappable — comme aujourd'hui (`SortieProjecteur:823`) |
| la tenue en main | `CarteGyro` (:2626) | le tilt 3D au doigt et au gyroscope — la card se tient |

**Elle change :** le contenu. Trois étages, de haut en bas, tous **dans** la card :

```
┌──────────────────────────────┐   ← crête noire, gris juste dessous (la robe spotlight)
│                              │
│            ╭─╮               │   1 · LE CHIFFRE DE VERRE — ChiffreVerre(valeur: n)
│            │4│  ← verre      │       192 × 192, .clear.interactive(), il dérive,
│            ╰─╯               │       il se saisit ; count-up 0 → n avec les ticks
│                              │
│         A L L E Z            │   2 · LES MOTS — TexteGeant(lignes: [ALLEZ, MARGAUX, GO !])
│       M A R G A U X          │       échelonné sur la LARGEUR DE LA CARD (utile = l − 24),
│           G O !              │       pas sur l'écran ; même règle `avance = 86`
│                              │
│        (  Entrer  )          │   3 · ENTRER — la capsule de verre du Claim (BoutonClaim:1748),
│                              │       .clear.interactive() dans un GlassEffectContainer
└──────────────────────────────┘       à taille fixe, le libellé « Entrer » / « Enter »
```

- **Le chiffre en haut, les mots dessous** : c'est l'inverse de la card « You Made It » (mots en
  haut, chiffre qui descend) — sa consigne est explicite : « au-dessus le chiffre ».
- **Le prénom peut être long.** Dans la card, `tenirDansLEcran` vise **la largeur de la card**
  (≈ 308 pt utiles), pas 356 : « MARGAUX » (7 × 86 = 602) tombe à ≈ 0,51 → ~57 pt par lettre.
  Les trois lignes gardent leur rapport, c'est le bloc qui s'échelonne. Sans prénom : deux lignes.
- **Entrer** : la capsule de verre du Claim plutôt que `BoutonPrimaire` — dans une card, le
  bouton pleine largeur d'une page ferait une barre ; la capsule est la langue des pop-ups de la
  maison. Le libellé suit la langue.

**Où est la lumière.** Le cône du halo descend de l'île **derrière** la card ; la card est posée
un peu **haut** (centre à ≈ 44 % de l'écran) pour rester sous le faisceau et laisser la place à
la pilule. Le gris de tête de la robe spotlight est ce que le cône éclaire.

## 3. Le chiffre de verre — la loi du verre sur du noir

`ChiffreVerre` est validé sur la robe `.neon`, **posé sur du texte** qu'il réfracte. Ici il n'a
sous lui que la dalle grise de la card — et « sans matière derrière lui, un verre sur du noir est
un TROU » (loi mesurée, RewardCard:1778-1781, widgets). Deux gestes pour qu'il vive :

1. **une flaque de lumière derrière le chiffre, dans la card** — le « gros halo » de la robe
   `.halo` (RewardCard:292-315, deux ellipses `.screen`), mais **en tête** et plus petite : c'est
   elle que le verre plie, et elle dit « le projecteur tombe ici » ;
2. **la pluie de diamant passe derrière lui** (elle est déjà plein écran) — le verre la réfracte,
   comme `VerreQuatre` réfracte la matrice.

⚠️ `ChiffreVerre` et `FormeGlyphe` sont `private` dans RewardCard.swift → deux mots à retirer
(comme `GaletVerre`, `TexteGeant`, `PoudreDiamant` qui sont déjà partagés). Rien d'autre n'y change.

⚠️ `ChiffreVerre` dérive par une `TimelineView` à 60 Hz (RewardCard:2165) — un moteur qui
**redessine** (loi : 3 à 8 × le prix d'animer). On le reprend TEL QUEL d'abord (c'est le
composant validé), on **mesure sur ton téléphone** (`-sondeVol`), et s'il coûte, sa dérive passe
en valeurs animables `repeatForever` comme les autres horloges du 05-09. Pas avant.

## 4. La pilule — recuite, posée en bas, fondue

**Source :** `story-pilule-top.mp4` — 2648 × 1664, 23,9 s, 17 Mo. Trop grand, trop lourd, et
son cadre est celui d'une page story (elle y est en haut, rognée). Ici elle est **en bas**, et
seule sa **moitié haute** est dans l'écran : elle émerge du bord.

**La cuisson (`tools/porte/recuit_pilule.sh`, les lois de la maison) :**

| loi | le geste |
|---|---|
| crop au ratio de la fenêtre | on ne garde que la bande utile : la pilule et un peu de noir autour → **1180 × 720** (≈ la largeur d'écran ×3, 240 pt de haut) |
| extinctions **cuites** dans le fichier | fondu du **haut** (la pilule naît du noir), fondus des flancs — jamais un masque SwiftUI au-dessus d'une vidéo |
| jamais `-ss` | trim + `setpts` dans le graphe |
| boucle | la source fait 24 s : on prend **12 s en ping-pong cuit** (aller + retour, doublons de bord amputés) — un `AVPlayerLooper`, jamais un seek |
| préréglage | `-preset slow -crf 20 -pix_fmt yuv420p -g 48`, cible **≤ 3 Mo** |

**La pose :** `NosfyReel(nom: "nosfy-pilule", boucle: true, muet: true)` (le composant du film :
démonté à la sortie, barreau `-sansNosfyVideo`), `.frame(393 × 240)`, alignée **en bas**, avec
un `offset(y:)` qui laisse **≈ 110 pt** de pilule visible au-dessus du bord — fondue : opacité
qui monte en 0,8 s avec le temps 1 (le cône), et son bord haut est déjà noir dans le fichier.

⚠️ **Le verre ne passe JAMAIS au-dessus de la pilule** (un verre sur une vidéo ne met rien en
cache — mesuré) : la card s'arrête à ≈ 66 % de l'écran, la pilule commence à ≈ 72 %. Ils ne se
touchent pas, par construction.

⚠️ **C'est la première couleur du film.** Tout le film est blanc sur noir ; la pilule est noire à
cœur **rouge**. Elle arrive à la toute fin — juste avant la home, qui est rouge. C'est une
passerelle, pas une faute : la home commence ici.

## 5. La partition (à l'horloge, depuis `.bienvenue`)

| t | ce qui se passe | pièce |
|---|---|---|
| 0,00 | le halo seul, le noir | (inchangé) |
| **0,25** | l'île flashe · `Haptique.fort()` · le cône descend | `onInterrupteur` (inchangé) |
| 0,55 | **la pilule** monte du bord, fondue, 0,8 s | `NosfyReel` |
| **0,85** | **la card naît** : `p : 0 → 1` en 1,45 s — dalle, verre, gris de tête | `RewardScene` (châssis) |
| 1,30 → 2,10 | le chiffre de verre **compte** 0 → n, un tick par chiffre ; la flaque s'allume | `ChiffreVerre` + `LensChime` |
| 1,45 | les mots arrivent dans la card (fondu-flou) | `TexteGeant` |
| **2,30** | la card **se pose** : secousse, **boum** (`.heavy`), **la pluie** partout, Entrer | `posee` |
| … | elle regarde ; la card se tient au doigt (gyro) | `CarteGyro` |
| tap | `partir()` : musique off, poudre, la card **rentre** 0,42 s pendant que la caméra avance, voile blanc, coupe à 0,55 | (inchangé + `fermer`) |

Un tap avant 2,30 → **la fin complète d'un coup** (règle du 13-09), jamais la home.

## 6. Ce que ça coûte (à mesurer sur ton téléphone, pas au simulateur)

- **1 vidéo** (la pilule, `AVPlayerLayer`, sans verre dessus) — comme la bête de l'accueil.
- **3 verres** : le châssis de la card (`.regular.tint`, taille fixe), le chiffre
  (`.clear.interactive()`, 192 × 192), la capsule Entrer (`.clear.interactive()`, taille fixe).
  Aucun n'est jamais redimensionné (la loi des bounds vivants) ; au zoom de sortie, la card est
  déjà **retirée** (`fermer` d'abord, zoom après — l'ordre d'aujourd'hui avec le galet).
- **2 horloges** : la dérive du chiffre (60 Hz, RewardCard) et la poudre. Barreaux : `-sansPiluleFin`,
  et la sonde `-sondeVol` avant/après. Le chiffre est le suspect n° 1 s'il chauffe.
- Ce qui **sort** : `GaletVerre` (un verre de 204 pt), les deux cadres de poudre latéraux.

## 7. Le verrou du serveur — prêt chez la session chambres, les deux appels sont chez moi

Migration `20260913200000_profil` **déployée et mesurée** par la session chambres sur ton ordre
(« créer le profil pour plus tard même si c'est empty ») : `profils`, `profil()`,
`definir_profil(…)`, `choisir_exercices(…)` ; Swift prêt dans `Woop/Services/ProfilServeur.swift`.
**Aucun site d'appel posé** — ce sont les deux miens :

| où | aujourd'hui (INVALIDE) | demain |
|---|---|---|
| après l'échange Apple (`AppleAuth.entrer`) | « aucune ligne `user_prefs` = une nouvelle » — faux depuis que la chambre écrit `user_prefs` | `ProfilServeur.profil().onboardingTermine` → **true = home direct**, false = Nosfy |
| à la fin du film (`WoopApp` `onFini`) | `ChambreEtat.shared.choisir(n)` seul | **`definirProfil(langue:prenom:but:objectifHebdo:)`** — un appel, il relaie l'objectif et date la fin ; `choisir(n)` reste pour la clé locale immédiate |
| mode maquette | — | pas de serveur : `Maquette` rend un profil faux (nouvelle / connue), comme aujourd'hui |

Puis : mesurer (appel fait, réponse lue, sur le compte `b8dc40f5`), le site (`b-po-apple` +
les briques profil 🔵 → 🟢), le même commit. **J'attends ton go pour ces deux lignes** — elles
ne dépendent pas de la pop-up.

## 7 bis. Le prénom est OBLIGATOIRE (sa consigne, 13-09 nuit)

> « note dans le back-end : le user ne peut pas passer le prénom, donc pas de skip, mais un
> message qui devient rouge dans l'input si le user tape à côté »

| côté | aujourd'hui | demain |
|---|---|---|
| le film (`.prenom`) | « Passer » existe sur les trois questions ; `onSubmit` vide → on avance sans prénom ; la sortie prévoit « ALLEZ / GO ! » sans nom | **plus de « Passer » sur le prénom** (il reste sur le but et les jours) ; un tap **à côté du champ** ou un retour **vide** ne fait pas avancer : **le texte du champ passe au rouge** (le placeholder / l'aide « Votre prénom » → rouge de la maison, 0,25 s, haptique léger), le champ garde le focus ; il redevient blanc dès qu'on tape une lettre |
| la sortie | deux lignes possibles sans prénom | **toujours trois lignes** — le cas « sans prénom » meurt (le code reste tolérant, il ne peut plus arriver) |
| le serveur (`definir_profil`) | `p_prenom` nullable, rien ne refuse le vide | **le prénom est requis** : `definir_profil` refuse un prénom nul ou vide (relayé à la session chambres — c'est leur migration) ; `profils.prenom` NOT NULL une fois l'onboarding terminé |
| le site du back-end | — | la règle est posée (`b-st-prenom-obligatoire`), état ⚪ tant que rien ne l'applique |

**Le rouge** : le seul rouge du film. Il ne vient qu'après un geste faux, il part au premier
caractère. C'est un refus, pas une décoration.

## 8. Ce que je te demande

1. **G · ÉLAN ou H · SOLEIL** pour la fin (les deux aperçus sont dans la conversation).
2. **La pilule** : celle des pages story (couchée, § 0) — ou celle de Progress (debout) ?
3. **Go** pour la pop-up (§ 2-6), et **go** pour le verrou (§ 7) — séparément ou ensemble.

## 9. L'ordre, quand tu dis go

① recuire la pilule (mesurer le fichier : poids, noir vrai des bords) → ② `ChiffreVerre` /
`FormeGlyphe` en interne → ③ `CarteSortie` dans NosfyOnboarding.swift : le châssis emprunté, les
trois étages, l'arrivée, la sortie → ④ la pilule posée, le barreau → ⑤ `SortieProjecteur` :
la card remplace les mots et le galet, la partition § 5 → ⑥ build, sim (le tenu du prénom long,
la coupe), **ton téléphone** (le verre, la chauffe, l'haptique). Rien n'est repeint sur le site :
la pop-up n'est pas du back-end.

---

## 10. État (13-09, nuit — après « go vas-y »)

**Codé, non commité, en cours de build :**
- **La card** (`CarteSortie`, NosfyOnboarding.swift) : châssis emprunté (dalle, verre
  `.regular.tint`, robe gris→noir, 78 % / 320 max, ratio 1,32), flaque de lumière en tête,
  `ChiffreVerre` qui compte (ticks `LensChime`), `TexteGeant` échelonné sur la largeur de la
  card, `CapsuleEntrer` (le verre du Claim). Arrivée = opacité + 28 pt de montée, JAMAIS une
  échelle ; posée à 2,3 s = `Haptique.fort()` + `Paillettes.announce` + la pluie. Sortie =
  la card rentre 0,42 s → zoom 1,38 → voile blanc → coupe. `ChiffreVerre` / `FormeGlyphe`
  rendus internes dans RewardCard.swift (deux mots). Pas de `CarteGyro` : avec un verre natif
  dans la card, son tilt est coupé de toute façon (`sansTilt`) — à voir si la nappe gyro
  manque.
- **Le galet** : `duo-galet-noir.mp4` tel quel, `NosfyReel` 58 % de large, masque fondu en
  tête, opacité 0,74, 30 pt sous le bord ; la card s'arrête ≈ 10 pt au-dessus.
- **Le prénom obligatoire** : plus de « Passer » sur `.prenom` ; retour vide ou tap à côté →
  `refuserPrenom()` (prompt « Votre prénom » / « Your first name » et liseré en rouge
  `1.0/0.30/0.20`, haptique léger, focus gardé) ; blanc au premier caractère.
- **Le verrou serveur (§ 7)** : `AppleAuth.entrer` lit `ProfilServeur.profil().onboardingTermine`
  après `adopter` (panne → on joue le film) ; `WoopApp.ecrireProfil` appelle `definirProfil`
  à la fin du film (les deux chemins : porte et rejeu), rien en maquette
  (`AppleAuth.Maquette.active`). **Pas encore mesuré** — le site ne bouge pas avant.
- **La musique** : G2 · ÉLAN douce posée (`Woop/Sounds/NosfyFin.m4a`, −24 LUFS, 20 s) ;
  G, H, F en réserve dans `tools/porte/theme/`.

---

# SECOND PLAN (13-09, nuit) — « ça va pas, refais le plan »

**Ses trois verdicts au simulateur, mot pour mot :** « non, le 4 est au-dessus du texte ! » ·
« SUR le texte, pas au-dessus, comme dans la pop-up de base » · « la pilule : coupée, fondue
**vers le bas de l'écran**, pas au niveau de la pop-up ! » · « et le 4 n'est **pas liquid glass** ! »

**Ce que j'avais faux, et pourquoi :**

| j'avais fait | ce qu'elle voulait | la cause |
|---|---|---|
| le chiffre EN HAUT, les mots dessous (puis l'inverse) | **le 4 posé SUR le texte**, qu'il réfracte — la composition de la pop-up de base | j'ai lu « au-dessus » comme une position, c'était une SUPERPOSITION |
| `ChiffreVerre` seul (le verre coulé dans le glyphe) sur la dalle grise | **le 4 de la pop-up de base** : `ChiffreMatrice` (le chiffre plein, sa trame) + `VerreQuatre` (le vrai Liquid Glass coulé dans sa silhouette, par-dessus) | un verre sans matière derrière lui est un TROU — la loi mesurée, que le plan citait et que j'ai quand même payée : sur la dalle sombre, le glyphe se lisait gris et plat |
| le galet qui montait jusque sous la card (tête à ≈ 590 pt) | **le galet au ras du bas** : il émerge du bord, ≈ 110 pt visibles, sa tête fondue — loin sous la card | j'ai posé 30 pt sous le bord ; elle veut l'inverse : presque tout sous le bord |
| un châssis COPIÉ de RewardPopup | **RewardPopup lui-même**, robe « You Made It » | une copie n'a ni la lampe-barrette, ni la vidéo-matrice, ni la secousse, ni le gyro : elle n'est pas « la pop-up de base » |

## 11. La card = LA VRAIE `RewardPopup`, robe `.spotlight`, trois paramètres de plus

On ne copie plus le châssis : on MONTE la pop-up de base dans le film, telle qu'elle est —
la dalle, le verre, la robe gris→noir, **la lampe-barrette et son éventail**, la vidéo-matrice
en fond, le texte géant en tête, **le chiffre-matrice + le vrai Liquid Glass par-dessus**, la
secousse et le boum à la pose, le count-up avec ses ticks, la sortie 0,42 s, le gyro. Ce
qu'elle ne sait pas faire aujourd'hui et qu'on lui apprend — **trois paramètres optionnels,
à défaut `nil` = rien ne change pour les robes existantes** (RewardCard.swift, additif) :

| paramètre | défaut (aujourd'hui) | pour le film |
|---|---|---|
| `lignesGeantes: [String]?` | le nombre en toutes lettres (« FOUR ») | **`["ALLEZ", "MARGAUX", "GO !"]`** (EN : `LET'S`) — trois rangées au lieu d'une, échelonnées sur la largeur de la card (le mot le plus long décide ; cadre large, ses fondus tombent hors card) |
| `bouton: Bouton?` | le lien nu « Close » | **la capsule de verre** (celle du Claim, sans la pièce) au libellé **« Entrer » / « Enter »** |
| `scrim: Double` | 0,68 | **0** — le halo et son cône restent visibles derrière ; le scrim reste MONTÉ (transparent) : c'est lui qui porte le **tap partout = entrer** |

```
        ╲   le cône du halo, depuis l'île   ╱
┌──────────────────────────────┐   ← la lampe-barrette de la robe, gris en tête
│    ═══ éventail ═══          │
│         A L L E Z            │   les mots, TOUT EN HAUT (offset −0,355 h, la loi de la robe)
│       M A R G A U X          │
│          ╭───────╮           │
│         G│   4   │!          │   LE 4 : ChiffreMatrice ×1,22 + VerreQuatre PAR-DESSUS,
│          │ verre │           │   descendu de 46 pt (la loi de la robe) → il est SUR les
│          ╰───────╯           │   deux dernières rangées, qu'il réfracte
│                              │
│         ( Entrer )           │   la capsule de verre
└──────────────────────────────┘
              · · · pluie de diamant partout · · ·
   ─────────────────────────────────────────────── bas de l'écran
          ╭─────────╮  ← ≈ 110 pt du galet émergent, tête fondue
          │  verre  │     le reste est SOUS le bord
```

**Le 4 sur le texte, exactement comme la base :** la robe pose le texte géant à
`offset(y: −0,355 h)` et le chiffre à `+46 pt` ; avec trois rangées au lieu d'une, le bloc de
texte est plus haut (≈ 178 pt à l'échelle de MARGAUX) et descend jusqu'à ≈ 0,42 h ; le chiffre
(≈ 230 pt de haut à ×1,22), centré à ≈ 0,55 h, couvre « GO ! » et le bas de « MARGAUX » —
**il est sur le texte**, et ce texte est la matière que le verre plie. Rien à inventer : c'est
la géométrie de la robe, avec des mots plus nombreux.

**Ce que la robe apporte gratuitement :** le count-up (0 → n, un tick par chiffre), la
secousse + le **boum** à la pose (`.heavy`), `Paillettes.announce`, la nappe gyro, la vidéo-
matrice, l'arrivée 1,45 s et la sortie 0,42 s (`fermer` → `onClose`).

**Le cadencement (depuis `.bienvenue`) :** 0,25 s l'île flashe, le cône · 0,55 s le galet
monte du bord · **0,85 s la pop-up naît** (sa propre rampe) · ≈ 2,3 s posée : boum, la pluie
de diamant plein écran, Entrer · tap (bouton ou n'importe où) → `fermer` 0,42 s → **puis** zoom
1,38 → voile blanc → coupe → la home. Un tap avant la pose → la pose d'un coup (`-rewardAuto`
ferme la pop-up seule au banc, `-nosfyAuto` le passe).

## 12. Le galet — au ras du bas, cette fois

`duo-galet-noir.mp4` inchangé (58 % de large, 295 pt de haut), posé pour que **≈ 110 pt**
émergent au-dessus du bord bas ; le reste est sous l'écran. Sa tête est fondue dans le noir
(masque : clair → plein sur les 45 % du haut), opacité 0,6, il monte de 20 pt en 0,9 s. Il ne
s'approche jamais de la pop-up (≈ 140 pt d'air) — aucun verre au-dessus d'une vidéo.

## 13. Ce que ça coûte de plus que la base

Rien de neuf : la pop-up de base est déjà mesurée sur son téléphone (la card reward). Le film
y ajoute la vidéo du galet (sans verre dessus) et le halo. Barreaux : `-sansNosfyVideo`,
`-sondeVol`. Le chiffre-matrice et le texte géant redessinent (TimelineView 30 Hz) — c'est le
prix connu de la robe, pas un coût du film.

## 14. L'ordre, à ton go

① `RewardPopup` : les trois paramètres optionnels (`lignesGeantes`, `bouton`, `scrim`), aucun
changement de rendu pour les robes existantes (je le vérifie au banc `-rewardAuto` : la card
« You Made It » d'avant et d'après, deux captures identiques) → ② `SortieProjecteur` : la
pop-up de base montée à 0,85 s, `onClose` → le zoom et le voile ; le galet au ras du bas ;
`CarteSortie` / `CapsuleEntrer` de ce soir SUPPRIMÉES → ③ sim (les trois rangées + le 4
dessus, le galet), **ton téléphone** (le verre, le boum, le gyro) → ④ la mesure serveur
(`definir_profil` au banc `-sessionBanc`, `profil()` à ta vraie porte Apple), puis le site.

**Ce qui reste posé de ce soir, hors card :** le prénom obligatoire (refus rouge), le verrou
serveur (non mesuré), la musique ÉLAN douce, le correctif « Entrer » de la porte.

## 15. État (13-09, nuit — second plan POSÉ)

**Codé, vu au simulateur (`tools/porte/…/popup3`), posé sur l'iPhone (build tel25), NON
commité :** `RewardPopup` a ses trois paramètres optionnels (`lignesGeantes`, `bouton:
.capsule`, `scrim`) — derrière `nil`, aucune robe ne bouge (le seul changement inconditionnel :
`contentShape` sur le scrim, `Text(unit)` seulement si non vide). `SortieProjecteur` monte la
robe `.spotlight` à 0,85 s (`onClose` → zoom → voile → coupe), le galet émerge de 110 pt au ras
du bas. `CarteSortie` / `CapsuleEntrer` du premier jet : supprimées. Au sim : la pluie de
chiffres, le 4 en vrai verre SUR « GO ! », ALLEZ / MARGAUX entiers, Entrer, le galet.
Banc : `-nosfy -nosfyAuto -rewardAuto` (la pop-up se ferme seule). Restent : ses verdicts au
téléphone (le verre, le boum, la place de la card sous le cône), la mesure serveur.

## 16. La marche du galet, sur l'appareil (13-09, plus tard)

Au simulateur la marche avait disparu (mesurée sur les pixels) ; **sur son iPhone elle
restait** (« je vois toujours la marche, mais c'est mieux le background »). C'est la loi du
26-08 : sur l'appareil, une couche vidéo ne se fond pas — masque et mode écran ne mordent pas,
son rectangle couvre ce qu'il a sous lui. Ce qu'il avait sous lui : **la queue du cône**
(600 pt + 28 de flou, jusqu'à ≈ 660 pt) et **le grain**. Deux gestes, aucun sur la vidéo :
- `coneHauteur` 600 → **520** : le cône s'arrête au-dessus du galet (qui naît à 610 pt) ; la
  page y est vraiment noire, comme le fichier ;
- le **grain passe AU-DESSUS** du galet dans le ZStack (avant : dessous, donc coupé par le
  rectangle).
Le masque et l'écran restent (le simulateur en profite, l'appareil les ignore). Posé sur
l'iPhone ; son verdict attendu.
