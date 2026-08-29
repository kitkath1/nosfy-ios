# VARIANT 3 — « LA CHÂSSE »

*(une châsse : le coffret d'orfèvrerie où l'on garde une relique)*

Proposition du 29-08, à la demande de Kathryn : *« refais une proposition
incroyable inspirée de mes pop-ups variants, la cuisine luxe »*.

---

## §1 — CE QU'IL Y A DANS LA CUISINE (relevé, pas supposé)

Six recettes de haute couture dorment dans ce dépôt. **Cinq n'ont jamais
quitté la card reward ou la story.** Aucune n'est dans une notification.

| Recette | Où | Ce qu'elle fait |
|---|---|---|
| **Le chrome irisé à DEUX PASSES CROISÉES** | `StorySuite.swift:1742` (`motOr`) | socle de métal froid à six paliers + biseau + gravure, puis **un arc-en-ciel angulaire qui tourne à 6 °/s CROISÉ avec une bande irisée qui descend en sens inverse** |
| **Le galet de VRAI verre** | `RewardCard.swift:2337` (`GaletVerre`) | un `glassEffect(.clear)` de 152 pt qui dérive et **réfracte ce qu'il survole**, saisissable, ressort au lâcher, haptique |
| **La poudre de diamant** | `StorySuite.swift:846` | Canvas 30 Hz, grains-étoiles **déterministes par hash**, l'additif demandé AU CONTEXTE — et dans StoryWin **elle naît DU mouvement** |
| **Les nappes d'or** | `StorySuite.swift:1934` | la lumière naît DANS les lettres (périodes premières, jamais un balayage) |
| **Le holo à la prise** | `StorySuite.swift:2208` | un irisé cyan→magenta→or dont **la teinte tourne avec le doigt**, à 24 °/s |
| **La lévitation glaciale** | école CalLab | ±2 pt, horloges premières, **jamais de `repeatForever`** : tout est fonction pure de `t` |

Deux leçons PAYÉES qui commandent tout ce qui suit :

- **« Une seule nappe fait un dégradé, c'est leur CROISEMENT qui fait le
  chrome. »** Mesuré au film : l'irisation à 0,45 multipliée par l'opacité
  du mot (0,28) ne pesait que 0,13 — le mot rendait **gris**. D'où les deux
  passes.
- **L'horloge du chrome se QUANTIFIE à 20 Hz.** Recomposé à 60 Hz, le mot de
  la story coûtait **41 img/s**. À 20 pas par seconde ses entrées ne changent
  qu'une image sur trois.

---

## §2 — LA PROPOSITION

### Le registre, d'abord — pourquoi cette card et pas une autre

- **Variant 1 « la jauge »** dit *où tu en es*. C'est un **état**. Calme,
  informatif, horizontal.
- **Variant 2 « le gros texte »** dit *tu as gagné*. C'est une
  **exclamation**. Typographique, plein cadre.
- **Variant 3 doit être une MATIÈRE.** Ni une jauge, ni une typo : un objet
  précieux qu'on a envie de regarder. C'est le seul registre qui manque, et
  c'est exactement celui que ta cuisine sait faire mieux que tout.

C'est aussi pourquoi je continue à écarter « le grand texte chrome derrière
la chauve-souris » : ce serait le variant 2 avec une autre peinture. Trois
variants doivent offrir trois réponses.

### La composition

```
┌──────────────────────────────────────────────┐
│                                              │
│   ╔═══╗                    /\  __  /\        │
│   ║+20║ ← CHROME IRISÉ    ( o\/  \/o )       │
│   ╚═══╝   deux passes      \  NOSFY  /       │
│   COINS EARNED              \_/\__/\_/       │
│                          ·  ˙  ·   ˙  ·      │
│                        la poudre naît des    │
│         ◯ ← le galet de VRAI verre, qui      │
│              dérive et le réfracte           │
└──────────────────────────────────────────────┘
```

**Quatre couches, de l'arrière vers l'avant :**

1. **NOSFY AU CENTRE** — `nosfy_grands.mp4` recuit en boucle de 1,5 s, sur
   son noir vrai. ✅ **Aucun détourage, donc aucun masque** : il se fond dans
   la dalle comme la vidéo de `DepartSeance`. C'est la seule vidéo des trois
   cards qui ne coûte pas de rendu hors écran.

2. **LA POUDRE QUI NAÎT DE SES AILES.** Pas une pluie décorative posée
   par-dessus : la règle de StoryWin est que **la poudre naît DU mouvement**.
   Ici la cause est littérale — les grains montent des pointes d'ailes, et
   leur densité suit le battement. Canvas 30 Hz, grains déterministes par
   hash, additif demandé au contexte.

3. **LE « +20 » EN CHROME IRISÉ**, à gauche, corps ~56. La recette `motOr`
   en robe renversée, entière : le socle de **métal froid** (sans lui,
   l'irisation seule fait une flaque d'essence — il faut du métal dessous
   pour que ça reste un chiffre), le biseau champagne au bord haut, la
   gravure (l'ombre interne sous l'encre : imprimé, pas posé), **les deux
   passes croisées**, et les nappes d'or qui naissent dedans.

   ⚠️ **C'est le chiffre qui est le bijou, pas un mot décoratif.** Toute la
   dépense d'orfèvrerie tombe sur l'information — c'est ça qui distingue
   cette card d'un fond d'écran.

4. **LE GALET DE VRAI VERRE**, ~92 pt, qui dérive lentement sur la moitié
   droite et **réfracte Nosfy**. Le seul objet de Liquid Glass des trois
   variants. Il ne demande rien au doigt (la notification n'interrompt
   rien) — mais si le doigt vient, il se laisse prendre et revient en
   ressort, comme sur la card reward.

---

## §3 — LES LOIS QUI CONTRAIGNENT CETTE CARD (et une qui la borne)

1. ⚠️ **`.clear` réfracte aux bords et GIVRE l'intérieur : il ne marche que
   sur du contenu DOUX.** Nosfy sur du noir est doux (une masse sombre, des
   ailes floues) → le galet peut passer sur lui. **Le chiffre en chrome est
   NET** → le galet ne doit PAS le survoler. **Sa dérive est donc bornée à
   la moitié droite de la dalle.** Ce n'est pas un choix de composition,
   c'est la loi du verre qui l'impose.

2. ⚠️ **Un verre natif animé fait tomber 60 → 14 img/s** — mesuré dans ce
   dépôt. **MAIS** ce galet-ci est à **taille CONSTANTE** et bouge par
   `offset` (une transformation, pas un redimensionnement) : c'est
   exactement ce que la card reward fait déjà, et elle vit. **C'est le
   risque n°1 et il se mesure avant tout le reste.**

3. ⚠️ **Le chrome tourne à 20 Hz, pas 60.** Non négociable (41 img/s payés).

4. ⚠️ `GaletVerre` est `private` dans `RewardCard.swift`. Deux voies : le
   passer `internal` (`RewardCard` n'est plus en vol dans une autre
   session), ou le copier — le dépôt l'a déjà fait pour `PoudreDiamant`, et
   son propre commentaire dit *« le jour où l'arbre est calme, l'une des
   deux meurt »*. **Je propose de le passer `internal`** : une recette, un
   endroit.

5. ⚠️ **Jamais de `repeatForever`** : la dérive, le battement, la poudre
   sont des **fonctions pures de `t`** (école CalLab). Une horloge par
   effet, périodes premières entre elles.

6. ⚠️ La vidéo se recuit **avant** d'entrer : 3836×2160 / 4,7 Mo pour un
   objet de ~110 pt, c'est 35× la résolution utile. Sortie ~440×440, boucle
   de 1,5 s cuite **dans le fichier** — et `-ss` NE COUPE PAS le graphe
   ffmpeg, la seule forme juste est `trim + setpts` DANS le graphe. Le
   raccord se vérifie sur une planche de contact avant la première ligne de
   Swift. Puis `Woop/Media` (ressources NUES : `Bundle.main.url`, jamais
   `Image(nom)`) et **`git add`** — le groupe est synchronisé mais trois
   fichiers ont déjà manqué au dépôt.

---

## §4 — LA CONSTRUCTION, PAR COUCHES ET AVEC UNE MESURE À CHAQUE ÉTAGE

C'est la card la plus chère des trois : une vidéo, un verre natif, un
Canvas de poudre et un chrome à deux passes. **On ne la monte pas d'un
coup** — chaque couche entre, se mesure, et ne reste que si elle se paie.

| # | Couche | Ce qu'on mesure avant de passer à la suivante |
|---|---|---|
| **C1** | Le recuit de la vidéo (440×440, boucle 1,5 s) | planche de contact du raccord |
| **C2** | Nosfy seul sur la dalle | cadence de référence |
| **C3** | Le « +20 » en chrome irisé (horloge 20 Hz) | cadence — et la sonde couleur : l'irisation doit se LIRE, pas rendre gris |
| **C4** | La poudre née des ailes | cadence |
| **C5** | **Le galet de verre** — en dernier, parce que c'est lui qui peut tuer la cadence | cadence, et **s'il coûte, il saute** |

**Deux replis, décidés d'avance plutôt que dans la panique :**
- **Sans le galet** : chrome + Nosfy + poudre. On garde ~80 % de l'effet
  pour ~30 % du coût. C'est le repli par défaut si C5 coûte cher.
- **Sans la poudre** : chrome + Nosfy + galet. Si c'est la poudre qui mord.

---

## §5 — CE QUE JE NE FAIS PAS, ET POURQUOI

- **Pas de mot géant derrière Nosfy** — ce serait le variant 2 repeint.
- **Pas de barre de progression ici** — elle appartient au variant 1, et
  trois cards qui portent la même jauge ne sont plus trois propositions.
- **Pas de holo au doigt** — c'est une recette de PRISE, et une
  notification qui n'interrompt rien ne demande pas la main. Elle reste
  disponible le jour où une card devient réclamable.

---

## §6 — CE QUE JE N'AI TOUJOURS PAS MESURÉ

**La cadence des deux cards déjà livrées.** Ni au simulateur, ni au
téléphone. Le variant 2 porte une vidéo **masquée par un glyphe** — un
rendu hors écran de tout le plan à chaque image — et personne n'a encore
mis un chiffre dessus. Tant que ce n'est pas fait, tout ce que je dis de la
fluidité de ces cards est une opinion.

Si tu veux, je passe la mesure **avant** de monter « La Châsse » : ce
serait plus honnête que d'ajouter une troisième card sur un socle dont on
ne connaît pas le prix.
