---
name: woop-schema
description: Documenter et DESSINER pour Woop — schémas de base de données, diagrammes de parcours, fiches de table, dictionnaires de données, et le site de documentation. À charger dès qu'il faut produire un diagramme (ERD, séquence, états, arbre de décision) ou décrire un schéma PostgreSQL. Couvre la robe (le noir de l'app, des blancs en dégradé, Inter, la couleur sémantique : emoji, card d'état, aurore du hero), les règles de conception du schéma, le format de sortie en quatre parties, les huit pièges de rendu Mermaid payés au banc, et la vérification d'un schéma sans base locale.
---

# Dessiner et documenter — le cahier d'atelier de Woop

Ta lectrice **n'est pas experte back-end**. Elle doit comprendre vite, repérer
d'un coup d'œil ce qui ne va pas, et lancer une correction sans lire de SQL.

Deux principes, et tout le reste en découle :

**① Un dessin par idée, et l'idée tient dans son titre.**
Si un schéma demande un paragraphe pour être compris, c'est le schéma qu'il
faut refaire, pas le paragraphe qu'il faut écrire.

**② Un état se VÉRIFIE, il ne se déduit pas.**
Une pastille posée à vue est pire qu'une case vide : elle se lit comme une
mesure.

---

# I. LA ROBE

## Le noir de l'app, et des blancs en dégradé — rien d'autre

C'est un cahier d'atelier qu'on ouvre à côté du code. Il ne suit pas le thème
de qui le lit : **une seule robe, la nuit de l'app**, peinte explicitement.
Chaque valeur vient de l'app (`fichier:ligne`), jamais d'un goût — le relevé est
dans `tools/docsite/ANNEXE-DESIGN-APP.md`, le plan dans
`tools/docsite/PLAN-SITE-PREMIUM.md`.

```
--noir      #000000                            le noir de l'app (Theme.swift:27), SANS température :
                                               une capture d'écran posée dessus n'a pas de rectangle.
--panneau   linear-gradient(#0F0F0F,#080808)   les blocs (HomeNuit.swift:1248-1250).
--filet     rgba(255,255,255,.06)              1 px, blanc-alpha : .06 au repos, .08 sur le verre,
                                               .16 au plafond (hover, actif). Aucun gris en hex.
```

**Les blancs sont des DÉGRADÉS de blanc**, jamais des gris :

```
--titre    160deg, #fff → .90 @32 % → .60 @68 % → .25     Theme.swift:166-176 (titleFade).
           DIAGONAL obligatoire : l'horizontal fait clignoter un titre sur deux lignes.
           Sur ≤ 2 éléments par vue (le display + un h1, ou le titre d'une card).
--argent   180deg, #fff → .80 @62 % → .68                  Theme.swift:150-158 (silverText) — les h2.
encres     .96 vive · .55 calme · .42 sourde — plancher ABSOLU .42 (HomeNuit.swift:328).
```

Le dégradé n'est pas un effet : c'est ce qui fait qu'un titre blanc sur du noir
**pèse** au lieu de flotter. Un blanc plat sur du noir est violent ; un blanc
qui s'éteint vers le bas est du métal. ⚠️ Mais un emoji dans un texte clippé
**disparaît** (silhouette blanche) : **aucun emoji dans un h1/h2/h3**.

## ⚠️ LA COULEUR EST SÉMANTIQUE, JAMAIS DÉCORATIVE

Trois sources de couleur, et pas une de plus :

1. **l'emoji d'une pastille** (🟢🟡🔵⚪🔴) — et la bille CSS qui le remplace là
   où il n'y a pas d'emoji (compteurs et rangées de l'accueil) ;
2. **la teinte d'une card de domaine, qui en DÉCOULE** : ≥ 1 🔴 → rouge · tout
   🟢 → vert · sinon argent. Pas d'ambre, pas de bleu : quatre teintes font un
   sapin ;
3. **l'aurore du hero de l'accueil** (`AuroraHome.metal:592-594` : #FFE699 /
   #FF8A3D, plancher #210C03) — le seul halo du site, éteint à la ligne de base
   du hero. 0 pixel orange sur les autres onglets.

Zéro accent de marque, zéro couleur de lien, zéro couleur d'onglet actif. C'est
la règle qui rend le reste possible : dès qu'on ajoute un accent, les pastilles
cessent d'être ce qu'on repère en premier.

**Interdits, sans exception :** ombre colorée (toute ombre est `rgba(0,0,0,x)`),
dégradé à deux teintes ou violet / bleu-rose, néon, halo hors du hero, rayon
hors de {8, 12, 16, 20, 28, 999}, bordure de plus de 1 px, **flou animé**, plus
de 7 `backdrop-filter` — et jamais sur les pastilles : sur un fond uni un flou
ne floute rien et coûte une couche de composition chacun.

**La pastille** est un verre neutre — 22 px, rayon 999, dégradé blanc .08 → .03,
filet .08, reflet .12 — autour de l'emoji, qui est sa seule couleur. Pas de fond
teinté, pas de capitales. Dans une table, en première colonne, étroite : l'œil
balaie une colonne de points.

## La typographie

| rôle | famille | pourquoi |
|---|---|---|
| tout le texte | **Inter** — la police de l'app (`Woop/Fonts/`), via Google Fonts `opsz,wght@14..32,300..600` | une seule famille ; l'axe optique fait le « Display » au-dessus de 24 px |
| graisses | **300 / 400 / 500 / 600** — 300 seulement ≥ 28 px, 600 seulement sur le bouton obsidienne, **jamais 700+** | « plus fine » : la hiérarchie se fait par la lumière (vif 1.0 / sourd .42), pas par le gras |
| titres | 500, tracking −0,02 em, en dégradé | ça se lit à la volée sans crier |
| **tout ce qui est technique** | **Mono système** (`ui-monospace, "SF Mono", Menlo`), **seulement** dans une cellule, un `code`, un `pre` | nom de colonne, type SQL, `fichier:ligne`, code HTTP — jamais un titre, une nav, une légende, un pied |

⚠️ La séparation Sans / Mono **n'est pas décorative** : elle dit ce qu'on peut
copier-coller et ce qu'on doit lire. Un type SQL en Sans se lit comme une
opinion ; en Mono, comme un fait. Les nombres en colonne sont en `tabular-nums`
(= le `.monospacedDigit()` de l'app).

## Les cinq pastilles — les mêmes partout, sans exception

| | | |
|---|---|---|
| 🟢 | **BRANCHÉ** | l'écran parle au serveur, et ça a été vérifié |
| 🟡 | **LOCAL** | ça marche, mais ça vit dans le téléphone — perdu à la réinstallation |
| 🔵 | **SERVEUR SEUL** | c'est écrit et déployé, personne ne l'appelle |
| ⚪ | **ABSENT** | n'existe pas encore |
| 🔴 | **MENT** | l'écran affirme quelque chose que le code ne fait pas |

⚠️⚠️ **🔵 N'EST PAS 🟢, ET C'EST LA DISTINCTION QUI JUSTIFIE TOUT LE RESTE.**
Une fonction déployée et vérifiée en HTTP n'est pas une fonction branchée. La
moitié des défauts de cette app étaient des tuyaux complets **des deux côtés**
dont il manquait l'appel au milieu. Sans un mot pour cet état-là, une doc les
compte comme faits.

⚠️ **🔴 mérite sa propre pastille.** « L'écran affiche un solde » et « l'écran
affiche le VRAI solde » sont deux affirmations différentes, et seule la seconde
est vraie.

## Le coût, toujours collé à l'état

⏱️ une heure · ⏳ une journée · 🧗 un chantier

Un état sans son prix ne se hiérarchise pas : on ne sait pas par quoi commencer.

## Un emoji par nœud

Choisi pour ce que le nœud **est** — 🏋️ une séance, 📒 le carnet, 🎁 un sachet,
🎡 le manège, 🍎 Apple, 🚪 la porte — jamais pour décorer un titre de section :
**ni dans un `h1/h2/h3`, ni dans la nav, ni comme icône de card.** Un emoji vit
dans un nœud de schéma ou dans une pastille, nulle part ailleurs. Dans un schéma
dense, on retrouve un nœud par son emoji avant de lire son texte.

---

# II. LE SCHÉMA DE DONNÉES

## Règles de conception

1. **Normalisation stricte** (1NF → BCNF), une clé primaire unique et explicite
   par table.
2. **Clés étrangères indexées**, avec un `on delete` choisi et écrit :
   `cascade` quand l'enfant n'a pas de sens seul, `restrict` ou `set null`
   sinon.
3. **Types modernes** : `uuid` pour les identifiants, `timestamptz` avec
   `default now()`. Jamais `timestamp` nu, jamais un entier auto-incrémenté
   exposé au client.

## Les trois lois de la maison, qui priment

- **Un solde se DÉRIVE, il ne se stocke pas.** `sum(delta)` sur un journal.
  Toute colonne qui ressemble à un compteur est un bug en attente — payé sur
  `booster_progress.reste` : créée, lue par le coffre, **écrite par personne**,
  la jauge affichait 0/100 quel que soit le solde.
- **L'idempotence est un INDEX, jamais un compteur.** Un index unique partiel,
  et l'`unique_violation` attrapée pour répondre « déjà fait » sans erreur.
- **Un ledger ne se rembobine pas.** On n'efface pas une ligne, on en écrit une
  inverse.

## Deux choses qui ressemblent à des fautes et n'en sont pas — les DIRE

⚠️ **Un identifiant fabriqué par le client** (`workouts.id` vient de l'app) :
c'est ce qui rend un renvoi inoffensif. Sans la phrase, ça se lit comme une
erreur de conception.

⚠️ **`user_id` répété dans les tables enfants** : c'est ce qui permet au verrou
de sécurité de trancher sur place, sans remonter la chaîne jusqu'au parent.

---

# III. LE FORMAT DE SORTIE

```
## 1. Diagramme conceptuel (Mermaid ERD)
## 2. Dictionnaire des données
## 3. Scripts DDL
## 4. Notes de migration & retour arrière (Up / Down)
```

**Le dictionnaire** : une ligne par colonne — nom, type exact, nullabilité,
défaut, clé, et une description **en français simple**.

> La description dit *à quoi ça sert*, pas *ce que c'est*.
> « vide = séance en cours » vaut mieux que « timestamp nullable ».

**Ne décris jamais une table comme une liste de colonnes dans le corps du
texte.** Le dictionnaire est **plié** ; le corps parle de ce que le serveur
doit *décider* et *renvoyer*.

**Le DDL** : complet, index et contraintes compris — plié lui aussi. Il est là
pour être copié, pas pour être lu.

**Le Down d'une migration d'argent retire la FONCTION, jamais les LIGNES.**
Un carnet ne se rembobine pas ; les sachets ouverts l'ont été.

---

# IV. QUEL SCHÉMA, ET QUAND

| forme | quand |
|---|---|
| `flowchart` | un parcours, une cascade de conséquences, un arbre de décision |
| `sequenceDiagram` | **qui appelle qui, et quand** — c'est lui qui montre les appels manquants |
| `stateDiagram-v2` | le cycle de vie d'un objet (un sachet : gagné → en attente → ouvert → carte) |
| `erDiagram` | les tables et leurs liens |
| une **table HTML** | dès qu'il y a plus de six lignes de même nature — un schéma dense se lit moins bien qu'un tableau |

**Le diagramme qui manque le plus souvent** est celui des **conséquences en
chaîne** : « aucune série écrite → `setCount` = 0 → gain = 0 → pas de notif,
pas de sachet, pas d'appel serveur ». Il vaut dix paragraphes.

**Deux ou trois nœuds focaux au plus par schéma.** Ils se distinguent par le
poids du trait et la vivacité du blanc, jamais par une couleur.

---

# V. ⚠️ LES HUIT PIÈGES DE RENDU MERMAID

Tous payés au banc, tous à relire avant de livrer un schéma.

**① Il n'y a AUCUN moteur dans un fichier ouvert au navigateur.**
Les `<pre class="mermaid">` sont rendus nativement par la visionneuse
d'artefact ; en `file://` ils s'affichent en **texte brut**. Il faut charger le
moteur — et seulement s'il n'a pas déjà rendu, sinon on dessine deux fois.

**② `innerHTML` échappe les chevrons, et c'est la FLÈCHE qui meurt.**
`-->` revient en `--&gt;`, et Mermaid refuse tout le schéma (*« Expecting LINK,
got STR »*). Il faut redécoder — et `&amp;` **en dernier**, sinon un `&amp;gt;`
littéral deviendrait un vrai chevron au tour d'après.

**③ `textContent` mange les `<br>`** et recolle les mots : « 🏠 Homeslider en
bas ». On lit donc `innerHTML`, et on le capture **avant** tout rendu — un
rendu remplace la source par du SVG.

**④ Mermaid se nomme à l'horloge.**
Deux schémas rendus dans la même milliseconde reçoivent le **même id de SVG**
— or il scope sa feuille de style et ses pointes de flèches sur cet id. Deux
dessins se partagent alors un seul jeu de définitions et **se superposent**.
Remède : `render(monId, code)`, **un par un**, jamais `run()` sur un lot.

**⑤ Un conteneur en `display:none` mesure ZÉRO.**
Sur un site à onglets, un rendu global abîme toutes les pages masquées — et le
défaut ne se voit qu'en changeant d'onglet, c'est-à-dire jamais au moment où on
regarde. On ne rend que la page visible, et le reste à la bascule.

**⑥ Un SVG sans `viewBox` ne sait pas se redimensionner.**
Les diagrammes de séquence sortent avec `width`/`height` et rien d'autre : sous
un `height:auto` ils s'écrasent à 150 px. On leur reconstruit le cadre depuis
leurs propres cotes.

**⑦ Le thème ne descend pas partout — et il n'existe qu'UNE fois.**
`erDiagram` ignore `primaryColor` pour ses boîtes : il lui faut `mainBkg`,
`nodeBorder`, `textColor`, `attributeBackgroundColorOdd/Even`. Sans ça, les
entités sortent **en blanc plein** sur une page noire. Et le thème vit dans le
seul `initialize()` du JS (`themeVariables` en HEX — khroma dérive les teintes,
un `rgba` casse `darken()` — et `themeCSS` pour les classes `ok loc srv abs bad
neuf dit mut fait`) : **jamais de `%%{init}%%` ni de `classDef` dans un bloc**.
Les `class A,B ok` suffisent — vérifié : le nœud sort en `class="node default ok"`.

**⑧ Un schéma qui n'a pas pu être rendu doit le DIRE.**
Laisser du texte brut à sa place, c'est le laisser se faire passer pour un
schéma.

> ⚠️ **Et on REGARDE le rendu, on ne le suppose pas.** Ces huit pièges ont tous
> été trouvés en capturant la page, jamais en relisant le code.
> `./docs/site/voir.sh` ouvre le site ; une capture sans tête le mesure.

---

# VI. VÉRIFIER UN SCHÉMA SANS BASE LOCALE

**Les colonnes, par PostgREST, avec un témoin qui DOIT échouer :**

```
GET /rest/v1/<table>?select=<colonne>&limit=1
   200  → la colonne existe
   400  → "column … does not exist"
```

⚠️ **Le témoin n'est pas une coquetterie.** Sans une colonne inventée qui rend
400, quatre « 200 » d'affilée pourraient aussi bien vouloir dire que le serveur
répond n'importe quoi.

C'est la méthode qui a tranché une **divergence de migrations** que la lecture
ne pouvait pas résoudre : deux fichiers créaient `workouts` avec des colonnes
différentes. `created_at` → 200, `updated_at` → 400, témoin → 400. Verdict
rendu **par le serveur**, pas par une supposition.

**Les fonctions, en les appelant.** ⚠️ PostgREST résout un RPC par le **nom de
ses arguments** : un `404` veut dire « aucune signature ne correspond », pas
« la fonction n'existe pas ». Un `401 permission denied` prouve au contraire
qu'elle **existe**.

---

# VII. LA CHECK-LIST

- [ ] **La couleur est sémantique** — emoji d'état, teinte de card qui en découle, aurore du hero ; rien d'autre.
- [ ] Le noir `#000`, et **des blancs en dégradé** : `--titre` (≤ 2 par vue), `--argent`, plancher `.42`.
- [ ] Filets à **1 px** blanc-alpha, ombres noires seulement, rayons de l'échelle, ≤ 7 flous, **0 flou animé**.
- [ ] **Inter 300-600** pour tout, **Mono système** seulement dans `code`/`pre`/cellule ; **aucun emoji dans un titre**.
- [ ] `./tools/docsite/verifier.sh` passe : l'invariant des pastilles = `data-attendu`, les deux captures **regardées**.
- [ ] Chaque nœud porte son **emoji** et, s'il y a lieu, sa **pastille** + son **coût**.
- [ ] Chaque pastille a été **vérifiée**, et ce qui n'a pas pu l'être est **dit**.
- [ ] Le dictionnaire dit **à quoi ça sert**, pas ce que c'est ; il est plié.
- [ ] Les colonnes ambiguës sont tranchées **par le serveur**, témoin compris.
- [ ] Le `Down` d'une migration d'argent ne touche **aucune ligne**.
- [ ] Les schémas ont été **rendus et REGARDÉS** (les huit pièges du §V).
- [ ] `docs/site/index.html` est à jour et part dans **ce** commit.
