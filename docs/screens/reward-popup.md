# Écran — LA POP-UP DE RÉCOMPENSE (RewardPopup)

`Woop/Views/RewardCard.swift` (2694 l. — le composant et ses six robes) ·
décideur `Woop/Views/RestartSheet.swift:608` (`DecideurSerie`) · montage de
production `Woop/Views/ExerciseDetailView.swift:1069` · banc
`Woop/Views/RewardLab.swift` (`-rewardLab`).

> **Convention de ce document.** Ce qui est écrit sans marque est **vérifié
> dans le code** (29-08, lecture ligne par ligne). Ce qui porte **?** n'est pas
> sûr et attend une décision. Ce qui porte **CIBLE** est décidé mais n'existe
> pas encore. Les tables de la base ne sont pas décrites ici : seulement ce que
> le backend doit **décider** et **renvoyer**.

**Sa sœur** : [notification.md](notification.md). Les deux ne font qu'un
sujet — voir `tools/rewards/PLAN-ANNONCES.md`.

---

## 1 · Rôle

**Interrompre, quand ça vaut la peine.** C'est l'exact contraire de la
notification : la pop-up prend l'écran, éteint la page sous un scrim à 0,68, et
demande un geste pour repartir. Elle existe pour les ~40 % de fins de série
qui « méritent » quelque chose.

Elle porte trois intentions, aujourd'hui mélangées dans le même composant :

1. **Le MOMENT** — raconter un fait vrai de la séance en cours (« 12 reps at
   40 kg — that's 240 coins so far »).
2. **Le REWARD** — annoncer un gain, avec sa vidéo les grands jours.
3. **Le WELCOME BACK** — le versement de retour, seule robe à porter un
   bouton `Claim`.

⚠️ **Aujourd'hui aucune des trois ne crédite quoi que ce soit** (§3).

---

## 2 · Affiche

**La carte** : largeur `min(80 % de l'écran, 332 pt)`, ratio 1,32, rayon 36,
scrim noir 0,68, ombre **blanche** vers le bas, un tilt 3D au gyro. Sur toutes
les robes : 72 grains de poudre de diamant en `Canvas` 30 Hz, un tick de
cadran par chiffre qui monte, un boum à l'atterrissage, un arpège de cristal.

**Six robes** (`RewardStyle`), plus un dédoublement de la sixième
(`WelcomeRobe`) — donc **sept dressages** :

| Robe | Ce qu'on voit | Vidéo | Boutons |
|---|---|---|---|
| **`.halo`** | le voile s'OUVRE vers le bas, deux nappes blanches montent du sol en `.screen`, chiffre argent 190 pt, chiffres fantômes ±1 rognés par les flancs | optionnelle — ⚠️ **avec une vidéo, le halo et les fantômes disparaissent** et le chiffre tombe à 118 pt | Close |
| **`.neon`** | plus rien de néon : « YOU / MADE / IT » en mots géants, lampe en éventail, chiffre en **vrai verre** saisissable au doigt. **Pas de titre.** Le sous-titre seul en bas | — | Close |
| **`.galet`** | comme `.halo` mais halo de sol discret, et par-dessus le chiffre un **galet de verre** de 152 pt qui dérive, s'incline au gyro, se saisit | — | Close |
| **`.spotlight`** | ⚠️ **la carte n'est plus noire** (dégradé opaque gris→noir) ; vidéo de fond `fond-matrice-loop` **câblée en dur**, bord à bord ; le nombre **en toutes lettres** tout en haut ; chiffre en métal sombre sous une trame de micro-mots qui pleut. **Ni titre ni sous-titre** | fond en dur, + le slot | Close |
| **`.fire`** | braise rouge, chiffre à **430 pt quasi invisible** (blanc 0,028) que seul le balayage du spot révèle, sticker flamme au centre ; au tap, gerbe de 42 sprites + **secousse à force double** | optionnelle | Close |
| **`.welcome` / `.video`** | carte repeinte en **noir plein**, tilt 3D coupé, header vidéo en boucle sur 56 % de la hauteur, projecteur qui monte du bas, titre+sous-titre sous la vidéo | `reward-welcome`, **en boucle** | **Claim** + Later |
| **`.welcome` / `.texte`** | pas de vidéo ; « YOU'RE / BACK » en mots géants, pastille lune qui flotte, la chauve-souris **statique** au bord haut. Ni titre ni sous-titre | — | **Claim** + Later |

⚠️ **Le contrat de texte n'est pas uniforme** : `title` est **jeté** par
`.neon`, `.spotlight` et welcome/`.texte` ; `subtitle` est jeté par
`.spotlight` et welcome/`.texte` ; `unit` est jeté par `.neon` et `.welcome`.
Le backend peut remplir les quatre champs et n'en voir aucun à l'écran selon
la robe.

⚠️ **Aucun mot géant ne vient d'un champ de texte de l'API** — mais le fil
existe déjà, et c'est une nuance qui change le travail restant. Sur les trois
montages de `TexteGeant` : `.spotlight` **passe** `lignes:` (`:408`, le nombre
en toutes lettres dérivé de `count`), welcome/`.texte` **passe** deux
littéraux (`:503`), et `.neon` seul laisse jouer le défaut « YOU / MADE /
IT ». Il ne manque donc pas un fil à tirer : il manque **une source** — et le
commentaire du composant pose déjà la loi qui la borne, *« l'IA fournit les
MOTS, jamais la mise en forme d'une donnée »*.

**Ce que la production affiche vraiment** : `count: max(séries faites, 4)` —
⚠️ **un plancher de 4 en dur**, artefact de banc resté dans le chemin réel :
aux séries 1, 2 et 3 la carte annonce « 4 ». Titre `"Training"`, sous-titre
`"Congratulations, you've completed your training!"`, unité `"Sets"` — quatre
chaînes anglaises en dur au site d'appel, hors de tout catalogue.

---

## 3 · Actions

| # | Action | Geste | Appel backend |
|---|---|---|---|
| A1 | **Fermer** | le lien du bas (« Close », ou « Later » en welcome), 44 pt | **aucun** |
| A2 | **Claim** (welcome seulement) | la capsule de verre « Claim · +N » avec la pièce 3D | ⚠️ **aucun** — son action est *littéralement* `fermer`, la même que Later |
| A3 | **Fermer au scrim** | taper à côté de la carte | aucun |
| A4 | **Relancer la vidéo** | taper la vidéo (elle rembobine) | aucun |
| A5 | **Reculer la vidéo après le gel** | incliner le téléphone ou glisser — le playhead recule jusqu'à 2,4 s | aucun |
| A6 | **Saisir le verre** | le galet (`.galet`) ou le chiffre de verre (`.neon`) : prise, dérive, retour en ressort | aucun |
| A7 | **Attiser le feu** (`.fire`) | taper : 42 sprites de flamme + secousse | aucun |

⚠️⚠️ **AUCUN APPEL RÉSEAU DANS TOUT LE COMPOSANT NI DANS SA CHAÎNE.** `grep`
sur `URLSession|Supabase` dans `RewardCard.swift` : **zéro occurrence**. Le
geste de récompense est entièrement décoratif.

⚠️ **Le montant du Claim est faux** : le bouton affiche `count`, qui est un
**nombre de SÉRIES**, pas des pièces. Pour 4 séries il annonce « +4 » là où
l'économie de la maison en donne **80**.

⚠️ **La carte est inerte pendant 1,45 s** : `fermer()` sort immédiatement tant
que la rampe d'entrée n'est pas finie. Close, Later, Claim et le scrim sont
morts, sans aucun signe à l'écran.

### Ce qui l'ouvre

| Porte | Statut | Ce qu'elle produit |
|---|---|---|
| **fin de série** — `finirSerie` → `DecideurSerie.pour` → `jouerIssue` → `rewardShow = true` | **production** | série %10 → `.fire` + vidéo `reward-rare` · %5 → `.halo` · %3 → `.moment` en `.galet` · sinon la pill |
| **le chip « … » du header** (`ExerciseDetailView.swift:1846`) | ⚠️ **production, sans aucun drapeau** — commentaire : *« le geste du "…" est PRÊTÉ à la card reward le temps de l'atelier »* | fait tourner les **six** robes et ouvre une récompense **fausse** |
| neuf drapeaux de banc (`-rewardAuto`, `-spotLab`, `-rewardVideo`, `-rewardDemo`, `-fireLab`, `-welcomeTexte`, `-welcomeLab`, `-ymiLab`, `-rewardFlow`) | bancs | — |
| `RewardLab` (`-rewardLab`) · `RewardChemin` (`-rewardChemin refneon`) | bancs | — |

⚠️ **Le décideur ne sait produire que TROIS robes sur six** : `.fire`,
`.halo`, `.galet`. **`.neon`, `.spotlight` et `.welcome` n'ont aucun chemin
depuis le jeu** — elles ne s'ouvrent que par le chip « … » ou par un drapeau.

⚠️⚠️ **LE RANG EST DÉCALÉ D'UN CRAN.** `faites` est lu **synchroniquement**
juste après `settleSeries(f, coins: true)` — or cette écriture est **différée
de 0,55 s**. Le décideur juge donc le rang de la série **précédente** :

| ce que le code veut | ce qui arrive à l'écran |
|---|---|
| MOMENT à la 3ᵉ série | à la **4ᵉ** |
| pop-up `.halo` à la 5ᵉ | à la **6ᵉ** |
| vidéo rare à la 10ᵉ | à la **11ᵉ** |

Et la pill **sous-compte de 20 pièces** à chaque fois (`max(faites,1) * 20`) :
elle dit « 20 coins this session » sur la 2ᵉ série. ⚠️ Le banc `-serieFin`
passe `serie: n` en dur — **il ne reproduit pas le décalage, donc il ne peut
pas le révéler**.

---

## 4 · Sorties

| Depuis | Vers |
|---|---|
| **Close / Later / Claim / scrim** | la carte s'efface en 0,42 s, puis `onClose()` |
| `onClose` depuis la fin de série | le panneau **« Recommencer ? »**, +0,26 s — *« un seul chemin vers le panneau »*, et le code le tient |
| `onClose` depuis le chip « … » | rien : on reste sur la fiche |
| `onClose` sous `-rewardDemo` | la **combinaison suivante** (12 combos en boucle) |

**Qui entre ici** : uniquement la **fiche exo**. La pop-up n'est montée nulle
part ailleurs en production — ni sur la home, ni sur le chemin, ni en fin de
séance (qui a ses propres annonces).

---

## 5 · États

| État | Aujourd'hui | CIBLE |
|---|---|---|
| **entrée** | une rampe de 1,45 s (chiffre qui monte, sons, atterrissage). ⚠️ **Tous les boutons sont morts pendant ce temps**, sans aucun signe | quand Claim fera un vrai appel, ce trou d'1,45 s devra être **distingué d'un échec** |
| **chargement** | **n'existe pas** — rien n'est distant | le Claim devra avoir un état d'attente **et revenir à son état** si l'appel échoue (jamais un bouton mort) |
| **vide** | ⚠️ **n'existe pas non plus, et c'est un bug** : sous 4 séries la carte affiche « 4 » (plancher en dur) | le vrai compte, ou pas de carte |
| **erreur** | **aucune gestion** ; si la vidéo manque du bundle, la vue reste **un rectangle noir muet**, sans repli ni message | un repli visible ; le Claim doit dire son échec, il a coûté un geste |
| **vidéo finie** | gel sur la dernière image (`actionAtItemEnd = .pause`), puis elle « revit » au tilt (recul jusqu'à 2,4 s) ; ⚠️ **une seule finit sur du noir** (`reward-fire`, YAVG 16) — les autres gèlent sur une image claire | **?** le gel sur une image claire est-il voulu ? |
| **welcome en boucle** | ⚠️ la boucle est un `seek(.zero)` sur `didPlayToEndTime` — **la forme que la maison interdit par écrit** (elle laisse une image noire au raccord) ; et l'observateur **n'est jamais retiré** (pas de `dismantleUIView`) : chaque ouverture laisse un lecteur vivant | `AVPlayerLooper`, et la vidéo palindrome qui existe déjà (§6) |
| **reduceMotion** | ⚠️ **non respecté** par trois `TimelineView` (la lumière des mots géants, la lampe en éventail, le projecteur de welcome) : ils balaient à 30 Hz quoi qu'il arrive | à corriger |

---

## 6 · Les vidéos

**Douze fichiers de la famille, 15,1 Mio.** Toutes 1080p H.264 24 fps, muettes.

| vidéo | poids · durée | qui la joue |
|---|---|---|
| `reward-rare` | 1,28 Mio · 8,04 s | **production** — la seule que le moteur sait montrer (série %10) |
| `reward-nosfy-coins` | 2,66 Mio · 14,00 s | **production** — la card à gratter du chemin, **en boucle infinie** dans un header de 232 pt |
| `duo-nosfy-reward` | 0,30 Mio · 5,92 s | **production** — la fente du panneau de départ (210×234, cuite au ratio) |
| `reward-welcome` | 0,99 Mio · 7,04 s **portrait** | production *par le chip « … »* seulement |
| `reward-fire` · `reward-lune` · `reward-piece-1..5` | 7,93 Mio | ⚠️ **bancs uniquement** — jamais vues par une utilisatrice |
| `reward-welcome-loop` | 1,91 Mio · 14,00 s | ⚠️ **ORPHELINE** — son nom n'apparaît nulle part dans le code |

⚠️ **`reward-welcome-loop` est le palindrome cuit de `reward-welcome`** — la
vidéo faite pour boucler proprement, et c'est **mesuré au pixel**, pas déduit
d'une durée : la différence moyenne entre l'image `t` et son symétrique vaut
**0,37 à 0,58** contre un témoin de **5,15 à 7,35** entre deux instants
réellement différents, et sa première moitié est `reward-welcome` (écart 0,12
à 0,19). ⚠️ Elle fait **336 images = 169 + 167**, pas le double exact : un
palindrome correct ne redouble pas ses deux images extrêmes — un fichier
« exactement double » serait justement un palindrome **raté**.

La robe welcome boucle donc **la mauvaise vidéo** — la version non
palindromique, recousue par un `seek(.zero)`. **?** remplacement oublié, ou
fichier abandonné ?

⚠️ **6,14 Mio de vidéo morte partent dans le binaire** :
`reward-welcome-loop`, `coffre-salle-loop`, `coffre-salut`. Le groupe `Woop`
est synchronisé **sans exceptions** — tout ce qui est dans le dossier est
copié.

⚠️ **Deux `reward-piece-*` n'ont PAS de chauve-souris** : `piece-3` (deux
pièces de verre en rotation) et `piece-5` (une pièce dans un cube). Vérifié à
plusieurs instants. Elles sont pourtant rangées dans la même table de rotation
que les autres — **?** plans « objet nu » voulus, ou prises à refaire ?

⚠️ **Aucune version courte n'existe**, alors que le plan la déclare
obligatoire (*« 7-9 s c'est LONG en pleine séance »*). `reward-rare`
immobilise **8 s de séance toutes les 10 séries**, et rien ne l'écourte.

**La recuisson du 25-08 n'a laissé aucun script** : la recette (4K HEVC →
1080 H.264, `trim + setpts` dans le graphe) ne vit qu'en prose. La prochaine
vidéo se recuit de mémoire, et le piège du `-ss` se repaie.

---

## 7 · Le backend et ses règles

> Le détail vit dans `tools/rewards/PLAN-REWARDS-BACKEND.md` (§2 pacing,
> §3 faits, §4 IA, §5 contrat design) et l'analyse du couple dans
> `tools/rewards/PLAN-ANNONCES.md`.

### 7.1 Ce que le backend doit fournir, et qui n'existe pas

| Ce qu'il faut | État |
|---|---|
| **le moteur de décision** (budget, écart minimal, priorité) | ⚠️ **n'existe pas** — ce qui décide est `serie % 10 / 5 / 3`, exactement le « déclencheur à position fixe » que le plan §2 **interdit** nommément |
| **le fact engine** (`{kind, value, unit, comparison, window, rank}`) | ⚠️ **n'existe pas**, ni serveur ni local. Aucune référence historique n'est chargée |
| **le crédit d'une pop-up** | ⚠️ **n'existe pas** : `.moment` et `.reward` ne font que `rewardShow = true` |
| **le claim du Welcome Back** | ✅ **branché le 29-08** : `.retourQuotidien` est posté au retour au premier plan (`SacreServeur.reglerRetourQuotidien`). ⚠️ Mais le bouton `Claim` de la card, lui, n'appelle toujours rien — et la robe n'a **aucune porte de production** |
| **le contrat par catégorie** (quelle robe pour quel événement) | ⚠️ annoncé au §4 du plan, **jamais écrit** |
| **les clés de pacing dans `reward_rules`** | ⚠️ la table ne porte que **quatre prix** ; aucune des 8 lignes de la table v1 |
| **l'IA qui écrit le texte** (`narrate-reward`) | ⚠️ **n'existe pas** — voir §7.2 |

### 7.2 L'IA : ce qui existe vraiment

Deux edge functions, et **une seule tourne en production** :

- **`forge-card`** — ✅ appelée par le manège du Sacre. GPT-5 écrit une
  *scène*, `gpt-image-1` la peint, l'URL revient. ⚠️ Le texte de GPT-5 n'est
  **jamais affiché** : c'est un prompt pour le peintre. La clé vit dans
  l'edge function, l'appelant est vérifié (`admin.auth.getUser`), la rareté
  n'est **jamais** acceptée du client, et une garde d'idempotence rend la même
  carte pour un booster déjà scellé. **C'est le patron à copier.**
- **`weekly-synthesis`** — Claude écrit 4-6 phrases françaises.
  ⚠️ **C'est du code mort** : la seule vue qui l'affiche (`SynthesisCard`) vit
  dans `ProgressionView`, qui **n'est montée nulle part** — l'onglet Progrès
  affiche le calendrier depuis le 18-08. ⚠️ Son auth ne vérifie que le préfixe
  « Bearer », sans valider le jeton.

⇒ **Aucune IA n'a jamais écrit un texte affiché dans cette app.** On ne peut
pas dire « ça marche déjà, on recopie » : ni la latence, ni le rendu, ni
l'échec n'ont été vus.

Ce qui manque pour que l'IA écrive un titre de pop-up :
1. **un contrat JSON typé** — les deux fonctions rendent du texte libre ;
2. **des bornes de longueur** — il n'y en a **nulle part** : ni dans le
   prompt, ni côté serveur, ni au rendu (`Text` sans `lineLimit` ni
   `minimumScaleFactor`). Un titre de 40 signes casse la carte ;
3. **une persistance** — un texte non stocké se regénère : la même série
   raconterait deux histoires ;
4. **un budget de latence** — `forge-card` assume 60-90 s ; une fin de série
   n'a pas ce budget, et il n'existe ni pré-chauffe, ni gabarit de secours.

⚠️ Et **ne pas copier** de `ForgeServeur` le repli sur un **compte de test aux
identifiants en dur dans le binaire** : une fonction facturée au token serait
ouverte à qui désassemble l'app.

---

## 8 · Bancs

| Argument | Effet |
|---|---|
| `-rewardLab` | le banc : la carte seule sur du noir, rien d'autre monté |
| `-robe <nom>` | `halo\|neon\|galet\|spotlight\|fire\|welcome\|welcomeTexte` |
| `-rewardFreeze <p>` | cloue la rampe d'entrée (captures) |
| `-rewardT <s>` | fige l'horloge des vies |
| `-rewardMire` | graduations 20 pt + axes |
| `-rewardAuto` | balaye les six robes en boucle, depuis la fiche |
| `-rewardDemo` | 12 combos (robe, vidéo) enchaînés par « Close » |
| `-rewardVideo` · `-rewardFlow` | la table des vidéos ; une série sur cinq porte une vidéo |
| `-spotLab` · `-fireLab` · `-welcomeLab` · `-welcomeTexte` · `-ymiLab` | une robe à la fois |
| `-serieFin <n>` | rejoue l'issue de la n-ième série (rang passé en dur — il ne pouvait donc pas révéler le décalage, corrigé le 29-08) |
| **`-rewardAtelier`** | rend le chip « … » du header, qui fait tourner les six robes. **Sans lui, la pop-up n'a plus qu'une seule porte : la fin de série** |

⚠️ **Le banc ne couvre pas les combinaisons robe + vidéo** : il ne passe
`videoNom` que pour welcome. Or `.halo` **perd son halo et ses fantômes** avec
une vidéo, et c'est `.fire` **avec** `reward-rare` que la production sert.

---

## 9 · À vérifier au téléphone

Rien n'a été validé sur l'appareil : la saisie du galet et du chiffre de
verre, le recul de la vidéo au gyro, la secousse du `.fire`, les sons et
haptiques, la cadence des robes à deux décodeurs (`.spotlight` + vidéo), et
le trou d'inertie de 1,45 s au doigt.

---

## 10 · Le ménage

### ✅ Fait le 29-08

| Quoi | Ce qui a changé |
|---|---|
| **Le décalage d'un rang** | le rang est calculé en tenant compte de l'écriture différée (la série en cours compte pour elle-même) **et MÉMORISÉ** dans `rangIssue` — une relecture de `sets` changerait de valeur sous la card, entre sa naissance (+0,34 s) et l'écriture (+0,55 s). Le MOMENT retombe à la 3ᵉ série, la pop-up à la 5ᵉ, la vidéo rare à la 10ᵉ, et la pill ne sous-compte plus |
| **Le plancher `max(…, 4)`** | ne vaut plus que pour l'**atelier**, là où il avait été écrit. Le jeu dit le vrai rang |
| **Le chip « … »** | derrière **`-rewardAtelier`**. Il n'est plus dans l'app livrée — il ouvrait une récompense fausse, atteignait le Welcome Back en deux taps, et sa fermeture **ouvrait le panneau « Recommencer ? »** |
| **Le Claim en séries** | la robe welcome annonce des **pièces** (`10`) avec l'unité `Coins`. ⚠️ Constante Swift **provisoire**, à remplacer par `regles_annonces()` |

### Ce qui reste

| Quoi | Où |
|---|---|
| ⚠️ le **`seek(.zero)`** et l'**observateur jamais retiré** | `RewardCard.swift:2560` |
| ⚠️ `reduceMotion` ignoré par trois horloges | — |
| ⚠️ la constante `piecesRetourQuotidien = 10` doublant la base | `ExerciseDetailView.swift` |
| code mort : `disqueNuit`, `ChiffreNeon`, `UnitePlate` (~150 l.) | `RewardCard.swift` |
| 6,14 Mio de vidéo orpheline dans le bundle | `Woop/Media` |
