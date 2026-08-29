# NOTIFICATIONS V4 — les rampes synchronisées, et LE TROISIÈME VARIANT

Ce plan s'ajoute à `PLAN-NOTIFS-V3.md` (livré). Rien de la V3 n'est repris :
la matrice dans le mot, les bords fondus, le halo radial, le trait à 3 pt et
les grains clippés restent.

---

## §A — LES RAMPES (les quatre demandes du 29-08)

### A1. UNE SEULE RAMPE POUR LE CHIFFRE ET POUR LA BARRE

Ton verdict : *« la progress bar part du début et va à la fin le temps que
le chiffre passe de 0 à 20 »*.

Aujourd'hui les deux sont pilotés par le `pose` du banc, sous un **ressort**
(`spring(response: 0.62)`). Un ressort n'a pas de fin nette : il dépasse,
il revient, et le chiffre — qui, lui, s'arrondit à l'entier — se fige avant
que la barre n'ait fini de trembler. Ils PARAISSENT désynchronisés parce
qu'ils le sont.

**Le remède** : les deux quittent le ressort et partagent **une seule rampe**
— `easeOut`, ~1,1 s, posée par la card elle-même dans un `onChange(of: pose)`
(le modèle déjà en place dans `NotifGrosTexte`). Le chiffre atteint 20 à
l'instant exact où la barre atteint sa cible.

⚠️ **Un seul `withAnimation` par card et par tour.** Deux au même tour ne
font RIEN (loi payée). La descente de la dalle garde son ressort, mais elle
vit chez l'hôte (`EntreeNotif`), pas dans la card.

⚠️ **Une chose que je ne devine pas** : « va à la fin ». Deux lectures.
- *Ma lecture* : la barre parcourt sa course jusqu'à **sa cible** (62 %,
  la vraie progression du coffre), en temps exact avec le chiffre. C'est
  ce que je fais.
- *L'autre* : elle va littéralement à **100 %**, jusqu'au bout du trait.
  C'est plus spectaculaire mais la jauge cesse de dire la vérité sur le
  coffre.

Un mot de toi et je bascule — c'est une constante.

### A2. LE « +20 » S'ANIME À CHAQUE FOIS

Il monte déjà à l'entrée, mais **seulement à la première**. Au rejeu, la
card est remontée avec `pose` déjà à `false` puis `true` : la rampe rejoue.
Ce qui ne rejoue pas, c'est le cas où la card reste montée et où seul
`pose` bascule. Le `onChange(of: pose)` de A1 règle les deux d'un coup :
**toute bascule de `pose` relance la rampe**, montée neuve ou pas.

### A3. LE « +20 COINS » DU VARIANT 2 MONTE AUSSI

Il est aujourd'hui un `Text` figé qui apparaît en fondu. Il devient le même
`ChiffreQuiMonte` (`Animatable`, corps 13), sur **la même rampe** que le
mot qui s'allume — les six lettres et le chiffre finissent ensemble.

### A4. LE VARIANT 1 PASSE EN CAPITALES

*« garde en majuscule dans le variant 1 »* :

```
+20  COINS EARNED          ← capitales, tracking +0,8
VAULT PROGRESS             ← capitales, tracking +1,4, gris
▬▬▬▬▬▬▬▬·:·▬▬▬░░░░░░
```

Le chiffre garde son corps 24 ; les capitales, plus étroites en apparence,
prennent un tracking positif — sans lui, des capitales serrées font un mur.

---

## §B — LE TROISIÈME VARIANT : CE QUE JE PROPOSE

Tu poses trois pistes et tu demandes ce que j'en pense. Voici ma réponse,
franchement.

### B0. Pourquoi je n'irais PAS au « grand texte chrome derrière la
chauve-souris »

Tu le sens toi-même (*« ou c'est too much ? »*), et je pense que oui — mais
pas pour une raison de goût. **Ce serait le variant 2 avec une chauve-souris
à la place de la pièce.** Même composition, même mécanique, même registre.
Trois variants doivent proposer trois RÉPONSES, pas deux réponses et une
redite. Le variant 2 est déjà le spectaculaire ; si le troisième l'est aussi,
tu n'as plus qu'un choix entre deux.

### B1. CE QUE JE PROPOSE : « LA PIÈCE QUI VA À NOSFY »

**Le seul des trois registres qui raconte un ÉVÉNEMENT et pas un état.**

- Le variant 1 dit *où tu en es* (un état).
- Le variant 2 dit *tu as gagné* (une exclamation).
- Le variant 3 dirait *voilà ce qui vient de se passer* — **un geste**.

```
┌────────────────────────────────────────────┐
│                                            │
│   +20 COINS          ●———————→   /\_/\     │
│   Nosfy is fed        ↑ la pièce  (o o)    │
│  ▬▬▬▬▬▬▬▬▬▬▬▬▬▬·:·▬▬▬┘  glisse   /  ⌒  \   │
│   └─ sa traînée EST la progress bar        │
└────────────────────────────────────────────┘
```

**Le cœur de l'idée, et c'est ce qui la rend juste** : *« j'aime bien
l'animation de la progress bar dégradé mais on peut faire autre chose »* —
alors on ne la jette pas, **on lui donne un sens**. La barre cesse d'être un
trait décoratif : elle devient **le CHEMIN de la pièce**. La pièce glisse
de gauche à droite, la traînée blanche à grains se remplit derrière elle, et
elle arrive à la chauve-souris qui bat des ailes. Un objet, un geste, une
arrivée.

Ce que ça réutilise, tel quel : `BarreParticules` (le `Canvas`, les grains
clippés, le dégradé, la tête), `PieceSprite`, `ChiffreQuiMonte`, le socle,
le liseré. Ce qu'il faut écrire : la couche vidéo de Nosfy, et le fait que
la tête de la barre porte la pièce au lieu d'un point.

⚠️ **La chauve-souris est AU CENTRE, comme tu l'as dit** — et c'est
justement ce qui marche : la pièce part du bord gauche et va vers elle, donc
le mouvement traverse la card et **finit sur le sujet**. Le texte tient dans
le tiers gauche, sous le départ de la course.

### B2. LES DEUX AUTRES, SI TU LES PRÉFÈRES

- **« NOSFY SEUL »** — la chauve-souris centrée, grande, sur la nuit ; le
  texte minuscule en bas ; rien d'autre. Le plus premium des trois, le moins
  bavard. Le risque : sans geste, c'est une vignette, pas une notification.
- **« LE CHROME »** (ta piste a) — le grand texte derrière. Je le code si tu
  le veux, mais voir B0.

### B3. LA VIDÉO — CE QU'ELLE EXIGE AVANT D'ENTRER

`~/Downloads/nosfy_grands.mp4` : **3836×2160, 5,04 s, 24 img/s, 4,7 Mo**,
la chauve-souris centrée, ailes déployées, **sur du noir vrai**.

1. ✅ **Le noir est vrai** : elle se fondra dans la dalle **sans détourage**,
   comme la vidéo de `DepartSeance`. Aucun masque, donc aucun rendu hors
   écran — contrairement à la matrice du variant 2.
2. ⚠️ **Elle est HORS DÉPÔT et beaucoup trop lourde.** 4K pour un objet de
   ~110 pt, c'est 35× la résolution utile. Elle se **recuit avant d'entrer** :
   recadrage serré sur la bête, sortie ~440×440, et surtout la **boucle de
   1,5 s** que tu demandes.
3. ⚠️ **La boucle se cuit dans le FICHIER, pas au lecteur.** Et
   `-ss` NE COUPE PAS le graphe ffmpeg — la seule forme juste est
   `trim + setpts` **dans** le graphe (loi payée). Le raccord se vérifie
   sur une planche de contact avant/après la couture : une chauve-souris
   qui claque à la reprise se voit au premier coup d'œil.
4. ⚠️ **Le fichier va dans `Woop/Media`**, qui contient des ressources NUES :
   `Image("nosfy…")` n'y trouverait RIEN, en silence. Le chargement passe
   par `Bundle.main.url(forResource:withExtension:)`. Et le dossier `Woop`
   est un groupe synchronisé : le fichier entre dans la cible tout seul,
   **mais il faut le `git add`** (trois fichiers ont déjà manqué au dépôt).
5. `AVPlayerLooper`, muet, looper RETENU par le coordinateur, jamais de
   `seek(.zero)` sur `didPlayToEndTime`.

---

## §C — LES JALONS

| # | Ce qui sort | Comment on le juge |
|---|---|---|
| **V4-1** | Le variant 1 en capitales | capture |
| **V4-2** | La rampe unique : chiffre et barre synchronisés, à chaque bascule | **film** — la sonde ne voit pas une désynchro, l'œil oui |
| **V4-3** | Le « +20 COINS » du variant 2 qui monte | film |
| **V4-4** | Le recuit de `nosfy_grands` : recadrage, 440×440, boucle 1,5 s | **planche de contact du raccord** avant d'écrire une ligne de Swift |
| **V4-5** | Le variant 3 « LA PIÈCE QUI VA À NOSFY » | capture + film |
| **V4-6** | La cadence, les trois cards | `charge.sh`, puis **le téléphone** |
| **V4-7** | Ton verdict | — |

L'ordre met le recuit de la vidéo AVANT le code : un fichier mal coupé se
voit à la première capture et fait recommencer le variant entier.

---

## §D — CE QUE ÇA COÛTE, ET QUE JE NE CACHERAI PAS

Le banc montrera bientôt **trois** cards empilées dont **deux portent une
vidéo** — l'une d'elles masquée par un glyphe (rendu hors écran de tout le
plan à chaque image). Ce n'est PAS la situation réelle : dans l'app, une
seule notification est à l'écran à la fois. Je mesurerai donc **deux
régimes** : le banc entier (le pire cas, celui du réglage) et **une card
seule** (le cas vrai, celui qui décide).

Et je le redis parce que ça n'a toujours pas été fait : **la cadence de ces
cards n'a jamais été mesurée**, ni au simulateur ni au téléphone. Tant que
ce n'est pas fait, tout ce que je peux dire de la fluidité est une opinion,
pas une donnée.
