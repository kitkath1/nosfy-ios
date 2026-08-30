# LE PIED DU COFFRE — le composant qui dit ce qu'on a, et ce que ça ouvre

**Analyse du 28-08-2026, sur la demande de Kathryn** : *« dans la page
coffre… on va refaire le composant : faut montrer le nombre de coins
disponibles, autant pour la pièce or que argent (qui ouvre le booster noir),
et expliquer la règle ! et montrer aussi deux choses : la progression pour
avoir un prochain booster (nécessaire en pièces) et le nombre de boosters
disponibles — dans la page avec le coin or on met le booster orange, dans la
page avec le coin argent on met le booster noir. Ce qu'on récolte, on le
retrouve ici et dans la page profil. »*

**Rien n'est codé ici** : c'est l'analyse, les asymétries qu'elle révèle, et
ce qu'elle demande au back-end. Le flow est écrit dans
[../rewards/CHANTIERS-UX.md](../rewards/CHANTIERS-UX.md) §7, la dette
serveur dans [../rewards/PLAN-REWARDS-BACKEND.md](../rewards/PLAN-REWARDS-BACKEND.md)
§4 undecies.

> ⚠️ Une AUTRE SESSION travaille sur les cards rewards dans la route. Ce
> chantier ne touche que `CoffreV2.swift` (le pied) et `ProfilLune.swift`
> (les pills) — deux fichiers qu'elle n'a pas ouverts.

---

## 1. L'état des lieux, mesuré dans le code

| ce qui existe | où | ce qu'il fait |
| --- | --- | --- |
| le carrousel à DEUX pièces | `CoffreV2.swift:1048` | `manege = [.or, .argent]` — la page argent existe DÉJÀ |
| le pied | `PiedCoffre`, `CoffreV2.swift:791` | trois chaînes : `compte` / `mot` / `ligne`, dans une plaque de verre 352 × 86 |
| ses textes | `compte(_:)`, `CoffreV2.swift:1067` | page or → `"\(coins)"` · `coins earned` · *20 coins for every set you finish.* ; page argent → `"0"` · `legendary coins` · *One opens a legendary card booster.* |
| la bourse | `CoffreFortPurse.swift` | `coins(doneSeries:) = séries × 20` — **une maquette assumée**, tenue en un seul endroit |
| le banc | `-coffreArgent` | ouvre directement sur la page argent |

**Trois choses sautent aux yeux en lisant :**

1. le `"0"` de la page argent est **écrit en dur** — la pièce argent n'a
   jamais eu de source ;
2. `coins` est un **total GAGNÉ**, calculé, jamais débité. Le mot `earned`
   est donc juste aujourd'hui… et faux demain ;
3. le commentaire du code le dit déjà : *« l'économie n'est tranchée qu'à
   MOITIÉ : `perSeries = 20` dit ce qu'une série RAPPORTE, et rien nulle part
   ne dit ce qu'une pièce ACHÈTE »*. Ce chantier est exactement ce qui manque.

---

## 2. Le point dur : « earned » n'est pas « disponible »

Tant qu'aucune pièce ne se dépense, les deux mots désignent le même nombre.
**Le booster à 100 pièces les sépare** — et c'est ce que Kathryn demande
d'afficher (« le nombre de coins DISPONIBLES »).

Conséquence, et elle dépasse ce composant : le solde affiché ne peut plus
être `séries × 20`. C'est le pivot déjà écrit au §0 de la note rewards — **le
solde calculé meurt, tout gain devient une ligne de `coin_ledger`**. Le pied
du coffre est le premier écran où ça se VOIT.

**Tant que le ledger n'est pas branché**, le pied peut afficher
`séries × 20 − 100 × (boosters déjà ouverts)` : c'est faux dès qu'un autre
mouvement existe (bonus, cadeau, migration), mais c'est honnête avec la
maquette actuelle. À écrire dans `CoffreFortPurse`, jamais dans la page.

---

## 3. LES DEUX PAGES NE SONT PAS SYMÉTRIQUES — et vouloir les rendre symétriques ferait mentir

C'est la découverte de l'analyse, et elle commande tout le dessin.

| | page OR | page ARGENT |
| --- | --- | --- |
| comment la pièce s'obtient | **par le travail** : 20 par série, déterministe | **par la chance** : tirage serveur (p ≈ 1/30 séances), jamais gagné à l'effort |
| ce qu'elle achète | 1 booster orange pour **100 pièces** | 1 booster noir pour **1 pièce** |
| une progression a-t-elle un sens ? | **OUI** : 62/100, il en manque 38 | **NON** : il n'y a rien à accumuler |
| « boosters disponibles » | un compte **distinct** du solde (`user_boosters` non ouverts) | **le solde lui-même** — le sachet noir naît au claim, 3 pièces argent = 3 boosters |

**Deux conséquences de dessin :**

- **La page argent n'a pas de barre de progression.** Y en mettre une
  obligerait à inventer une jauge — ou pire, à exposer le *pity timer* (la
  garantie douce après X séances sans drop). **Ne jamais montrer le pity** :
  il deviendrait farmable, et la rareté est tout ce qui fait la valeur de
  cette pièce. À sa place : la RÈGLE, qui est déjà le wahou (« elle tombe
  rarement — elle ouvre une légendaire, garantie »).
- **La page argent ne montre qu'UN nombre.** Solde et boosters ouvrables y
  sont le même chiffre : l'écrire deux fois ferait croire à deux stocks.

---

## 4. Le conflit de vocabulaire — à trancher, il fait déjà des dégâts

Le même objet porte **trois noms** selon l'endroit :

| où | comment il s'appelle |
| --- | --- |
| l'app | `PlanchePiece.argent`, *« legendary coins »* |
| les plans | « la pièce NOIRE » (partout dans la note rewards) |
| la base, **déployée le 28-08** | `currency = 'black'`, `raison = 'ouverture_booster_noir'`, `claim_booster_legendaire()` |

**Recommandation : ne pas renommer la base.** Elle est en ligne, et un
renommage coûte une migration plus une passe de code pour un gain nul.

**La règle de nommage qui règle le sujet** : à l'écran, la pièce se nomme
par **CE QU'ELLE OUVRE**, pas par sa couleur — *legendary coin*. La couleur
est un fait de rendu (elle est argentée, elle ouvre un sachet noir) ; le nom
est un fait de jeu. Dans le code et la base, `black` reste `black`.

---

## 5. Ce que le composant doit porter — l'anatomie

Quatre faits par page, dans cet ordre de lecture :

```
┌──────────────────────────────────────────────────────────┐
│  1 240        │  20 coins per set.        │   [sachet]   │
│  COINS        │  100 for a booster.       │      2       │
│  ▓▓▓▓▓▓░░ 62/100 → next booster           │   BOOSTERS   │
└──────────────────────────────────────────────────────────┘
```

- **le SOLDE** (gros chiffre, `contentTransition(.numericText())` — déjà là) ;
- **la RÈGLE**, en deux temps : ce qui rapporte, ce que ça achète. Le pied ne
  dit aujourd'hui que le premier ;
- **la PROGRESSION** vers le prochain booster (page or seulement) ;
- **LE SACHET** — la vignette du booster de CETTE page (orange à gauche du
  manège, noir à droite) et le nombre d'ouvrables.

**Ce qui change dans la structure** : `PiedCoffre` prend aujourd'hui trois
`String`. Il doit prendre **une donnée**, pas trois chaînes —

```
PiedVariante {
  solde: Int, monnaie: .or | .legendaire,
  regle: [String],          // 1 ou 2 lignes
  progression: (reste: Int, palier: Int)?,   // nil sur la page argent
  boosters: Int, robe: RobeBooster
}
```

C'est la même loi que les robes du booster : **le composant ne devine rien,
on lui donne un contrat**. Et ça évite le `compte(piedIdx).0/.1/.2` actuel,
qui appelle la fonction trois fois par rendu.

**La taille va devoir grandir** : 352 × 86 aujourd'hui, pour trois lignes de
texte. Quatre faits + une barre demandent ~352 × 112. `PiedCoffre.taille` est
une `static let` lue par la page — un seul endroit à changer.

---

## 6. Le verre — une décision à prendre les yeux ouverts

`PiedCoffre` utilise `glassEffect(.regular.tint(black 0.55))`. La loi de la
maison dit **`.regular` INTERDIT** pour tout objet « liquid glass ».

Mais la nuance de la loi s'applique ici et joue dans l'autre sens : `.clear`
**givre l'intérieur et réfracte aux bords**, donc il ne convient qu'à du
contenu DOUX — or ce pied porte du **texte net et des chiffres**, exactement
ce que `.clear` abîme. Trois sorties possibles :

1. garder `.regular` teinté, **assumé** : ce n'est pas un objet de verre
   liquide, c'est une plaque sombre lisible ;
2. passer en matériau non-verre (une nappe noire + liseré), ce qui règle la
   question et coûte le moins cher en GPU ;
3. `.clear` **plus** une pastille opaque sous les chiffres — deux matériaux
   pour un composant, c'est la solution la plus fragile.

→ **Recommandation : 1 ou 2**, et l'écrire dans le code pour que la loi ne
soit pas violée en silence. À trancher à l'œil, sur capture.

---

## 7. La consistance avec le profil

*« Ce qu'on récolte, on le retrouve ici et dans la page profil. »*

La deuxième pill **existe déjà** : elle a été posée le 28-08 avec la porte du
booster noir (`ProfilLune.swift` — pill noire, puis pill orange, puis les
pièces). Ce qui manque n'est donc pas l'affichage, c'est **la source unique** :

- aujourd'hui le profil lit `SacreEtat.boostersEnAttente` (maquette mémoire)
  et le coffre lit `CoffreFortPurse.coins(doneSeries:)` (maquette calculée) —
  **deux maquettes indépendantes qui peuvent déjà se contredire à l'écran** ;
- demain les deux doivent lire **le même état**, alimenté par un seul appel
  serveur (§4 undecies).

Règle à tenir : *un nombre montré à deux endroits n'a le droit d'exister
qu'une fois dans le code.*

---

## 8. Ce qu'il faut au back-end (détaillé au §4 undecies)

1. **`solde` par monnaie** — `solde_noir()` existe (déployée) ; il manque son
   jumeau jaune, ou une fonction qui rend les deux.
2. **`booster_progress`** — la table du §4 sexies (le report 0-99 de la
   conversion 100 pièces = 1 booster) **n'a PAS été créée** par la migration
   du 28-08 : elle ne couvrait que `user_boosters` et `coin_ledger`. Sans
   elle, pas de « 62/100 » juste.
3. **Le compte de boosters ouvrables** par famille (`origine <> 'legendaire'`
   / `= 'legendaire'`).
4. **Un seul appel pour tout** : `etat_coffre()` rendant
   `{ solde_jaune, solde_noir, boosters_jaunes, reste }`. Quatre allers-retours
   pour un composant qui doit s'ouvrir instantanément, c'est trois de trop —
   et c'est aussi ce qui garantit que le coffre et le profil ne peuvent pas
   afficher deux vérités.

---

## 10. v2 — LA MATIÈRE, L'ASSISE, LE VERRE (28-08, verdict sur le premier rendu)

*« ça fait cheap ; en plus c'est pas la même matière que l'autre. Baisse-le
un peu dans la card liquid glass, et retravaille la card liquid glass. »*

### 10.1 LE VRAI SUJET : les deux sachets ne viennent pas du même monde

Ce n'est pas une affaire de taille ni de pose. **Mesuré sur les deux
vignettes** (`Woop/Media`, 120 × 214 toutes les deux) :

| | `booster-pill` (orange) | `booster-pill-noir` |
| --- | --- | --- |
| p99 de luminance | **214** | 189 |
| pixels > 200 (les spéculaires) | **1,6 %** | **0,3 %** — cinq fois moins |
| contraste local (bords) | **66,7** | **36,3** — presque moitié |
| alpha | non (composé en `plusLighter`) | oui (composé normalement) |

L'orange est **un rendu 3D éclairé** : il a des plis, des reflets qui
courent dessus, une arête qui accroche la lumière. Le noir est **un aplat 2D
découpé** — mon bake de son dessin à plat. Posés côte à côte, l'un lit
« photo » et l'autre « autocollant ». **C'est ça, le cheap** : aucun réglage
de layout ne le rattrapera, et le grossir l'a rendu plus visible, pas moins.

**Trois routes, une seule tient :**

- **(a) RENDRE LES DEUX DEPUIS LA MÊME SCÈNE 3D — recommandé.**
  `BoosterScene(robe:)` existe déjà et porte les deux robes, avec le même
  studio, les mêmes plis (`booster-normal`), la même laque. Un banc
  d'export monte la scène en robe X, cadre le sachet de face, et écrit le
  PNG. Les deux vignettes deviennent des **jumeaux** : même lumière, même
  objectif, même matière — et rejouables le jour où une robe change.
  ⚠️ **Le piège technique, et sa sortie** : `SCNView.snapshot()` rend une
  image OPAQUE, or il faut de l'alpha (un sachet noir composé en additif ne
  laisserait que son filet). La sortie exacte : rendre **deux fois**, sur
  fond NOIR puis sur fond BLANC, et résoudre analytiquement —
  `alpha = 1 − (blanc − noir)`, `couleur = noir / alpha`. C'est exact, pas
  approché, et ça se vérifie au pixel.
  ⚠️ La robe noire est MATE par décision (rugosité 0,62, vernis 0,30) : elle
  restera moins brillante que la laque orange. Mais elle aura **le même
  relief, les mêmes plis, le même liseré de lumière** — elle lira « une
  autre matière du même monde », plus « un autre monde ».
- (b) Repeindre des reflets sur l'aplat noir → c'est refaire à la main ce
  que le moteur fait juste, et ça se verra.
- (c) Capturer le sachet dans le manège → l'éclairage et l'objectif du
  manège ne sont pas ceux d'une vignette ; on hérite d'un cadrage qui n'est
  pas fait pour ça.

### 10.2 L'ASSISE — « baisse-le un peu dans la card »

Aujourd'hui : **50 pt dedans, 116 dehors** (70 % au-dessus du bord). Elle le
veut plus bas. Proposition : **78 pt dedans, 88 dehors** (≈ 53 % dehors) —
il reste un objet qui sort, mais il est POSÉ dans la carte, plus perché
dessus.

⚠️ **Une conséquence à régler en même temps** : la pastille `×N` vit
aujourd'hui sur le bas du sachet. S'il s'enfonce de 28 pt, elle passe SOUS
la surface de la plaque. Elle doit quitter le sachet et devenir un élément
de la plaque — une petite capsule à son pied, dans la grammaire de la carte.

### 10.3 CE QUI MANQUE POUR QU'IL SOIT « ENCRÉ » : le contact

Le sachet n'a aujourd'hui qu'une ombre EXTÉRIEURE. Rien ne dit qu'il touche
la carte — il flotte devant. Trois gestes, tous discrets, qui font la
différence entre collé et posé :

1. **une ombre de contact** sur la plaque, au pied du sachet (courte, dense,
   qui s'écrase vers le bas) ;
2. **le liseré de la plaque qui s'interrompt** derrière lui — un bord qui
   continue à travers un objet dit que l'objet est un décalque ;
3. **une lumière de rebond** très faible sur la plaque, juste sous lui, de la
   couleur de sa page (braise à gauche, froide à droite).

### 10.4 LE VERRE — la loi et sa nuance

`PiedCoffre` utilise `glassEffect(.regular.tint(black 0.55))`. La loi dit
**`.regular` INTERDIT** ; mais sa nuance interdit aussi `.clear` ici (il
givre l'intérieur et réfracte aux bords — or ce pied porte du texte NET et
des chiffres). Les deux options honnêtes :

- **A — la plaque NON-VERRE** (recommandée) : nappe d'encre, liseré fin,
  une seule lumière de bord en haut. Elle ne viole aucune loi, elle coûte
  le moins cher en GPU, et elle laisse toute la scène derrière visible.
- **B — `.regular` assumé et écrit** : ce n'est pas un objet de verre
  liquide, c'est une plaque sombre lisible. Défendable, mais il faut le
  DIRE dans le code, sinon la loi est violée en silence.

Dans les deux cas, la carte gagne **un creux** : le sachet entre dedans, il
ne se pose pas dessus (§10.3).

## 11. v3 — LES BONS ASSETS, ET LA PARTIE BASSE QU'ON NE COMPREND PAS

*« Prends l'asset, le BON booster, pas l'aplat : `Booster_orange` et
`booster noir` sur le bureau. Diminue un peu leur taille. Et revois l'UI de
la partie basse : on comprend rien, il faut un liquid glass beaucoup mieux
structuré. »*

### 11.1 Les deux rendus du bureau règlent le §10.1 — mesuré

`~/Desktop/Booster_orange.png` et `~/Desktop/booster noir .png`, tous deux
**1054 × 1492**, tous deux des rendus 3D du même studio :

| | orange | noir | l'aplat que j'avais baké |
| --- | --- | --- | --- |
| p99 de luminance | 252 | 242 | 189 |
| pixels spéculaires (> 200) | 3,45 % | 2,67 % | **0,3 %** |
| contraste local (bords) | 21,0 | 25,1 | 36,3\* |

\* le contraste de l'aplat était HAUT pour la mauvaise raison : des traits
nets sans matière autour. Les deux rendus, eux, ont le même **grain de
plastique** — sertissages crantés, pli brillant, halo au sol. Leurs écarts
sont ceux de deux robes, plus ceux de deux techniques. **Le chantier de
rendu 3D du §10.1 devient inutile** : elle avait déjà les jumeaux.

**Le bake** (`tools/coffre-v2/bake_vignettes.py`, à écrire) :

1. rogner chaque rendu sur sa silhouette, à la même règle ;
2. **même hauteur de sachet dans les deux fichiers** — c'est ça qui fait
   « jumeaux » : deux sachets de tailles différentes dans deux pages qui se
   feuillettent, l'œil le voit tout de suite ;
3. sortir en 240 × 428 (le double de l'actuel — le sachet est GROS
   maintenant, 120 × 214 le rendrait mou) ;
4. **aucun détourage** : les deux vivent sur du noir et se composent en
   `plusLighter`, comme l'orange le fait déjà. Le fond disparaît tout seul,
   le halo au sol devient une lueur sur la plaque, et il n'y a pas d'alpha à
   entretenir. ⚠️ À VÉRIFIER À L'ŒIL sur le noir : s'il perd trop de corps
   en additif, on repasse par l'alpha à deux fonds (§10.1).

⚠️ **`booster-pill.png` est PARTAGÉ** : le remplacer change aussi la pill
du profil. C'est voulu (un objet, une image), mais ça se regarde.

### 11.2 La taille

96 × 166 → **84 × 145** à l'écran (−13 %). Assez pour rester un objet,
assez peu pour cesser d'écraser la plaque. L'ancrage suit le §10.2 : il
descend, il sort à ~53 % au lieu de 70 %.

### 11.3 « On comprend rien » — le diagnostic

La partie basse porte **cinq éléments de texte de poids voisin**, empilés :
`COINS` · *20 coins for every set you finish.* · *100 coins open one
booster.* · la barre · *40 / 100 to your next booster*. Aucun n'a de rang.
Et surtout, ils répondent à **trois questions différentes** qui sont
mélangées :

| la question | ce qui y répond aujourd'hui |
| --- | --- |
| **ce que j'ai** | le grand chiffre, et le mot `COINS` orphelin dessous |
| **où j'en suis** | la barre, et sa légende qui répète le palier |
| **comment ça marche** | deux phrases complètes, au même poids que le reste |

### 11.4 La structure proposée — trois zones, trois rangs

```
┌──────────────────────────────────────────────┐
│  1 140 coins                    ┌─────────┐  │  ① CE QUE J'AI
│                                 │ sachet  │  │
│  ─────────────────────────────  │   ×1    │  │
│  ▓▓▓▓▓▓▓░░░░░░░  60 to go       └─────────┘  │  ② OÙ J'EN SUIS
│                                              │
│  20 per set · 100 per booster                │  ③ LA RÈGLE (gris, 1 ligne)
└──────────────────────────────────────────────┘
```

Cinq gestes, et chacun a sa raison :

1. **`coins` passe À CÔTÉ du chiffre**, plus dessous. Un nombre et son unité
   sont UNE chose ; les séparer crée un label orphelin qu'on lit deux fois.
2. **La règle tombe à UNE ligne, en gris**, avec un point médian :
   *20 per set · 100 per booster*. C'est une note de bas de page, pas un
   paragraphe — deux phrases complètes au même poids que le solde, c'est ce
   qui noie la lecture.
3. **La jauge dit CE QUI RESTE, pas la fraction** : *60 to go* plutôt que
   *40 / 100*. Un reste est actionnable, une fraction est un calcul. (Le
   palier, lui, est déjà dit par la règle — il n'a pas à l'être deux fois.)
4. **Un filet sépare ① de ②** : ce que j'ai / où j'en suis sont deux
   informations, pas une liste.
5. **Le sachet et sa pastille forment un BLOC à droite**, aligné sur les
   deux premières zones — c'est lui qui donne sa colonne à la carte, et
   c'est ce qui rend le tout « structuré » plutôt qu'empilé.

**Page argent** : mêmes zones, la ② disparaît (rien à accumuler), et la
règle devient *A rare drop · opens a legendary*. Le squelette ne change
pas — c'est ce qui le rend scalable.

### 11.5 Le verre, décidé

Le §10.4 laissait deux options. Avec un sachet qui doit s'y ENFONCER, la
plaque doit porter une ombre de contact et un liseré qui s'interrompt
derrière lui : ni `.regular` ni `.clear` ne savent faire ça, ils ne savent
que se peindre. **→ plaque NON-VERRE** (nappe d'encre + liseré fin +
lumière de bord), qui accepte les trois gestes du §10.3 et ne viole aucune
loi. Le mot « liquid glass » reste vrai pour la SCÈNE, pas pour ce socle.

## 12. v4 — LE PIED FAIT QUATRE MÉTIERS, ET C'EST ÇA LE PROBLÈME

*« C'est pas clair, la jauge et 60 to go, on comprend pas — et encore moins
20 coins par séance. Ça, remove. Il faut un i ou autre, et au tap on
explique. Je suis pas convaincue. Ou est-ce qu'il faut une page dédiée au
clic du booster ? Ou c'est overkill ? Ou on mélange trop ? »*

**Son instinct est juste, et il vaut mieux que les réglages qu'on lui
oppose.** Ce n'est pas une affaire de taille de police : le pied essaie
d'être QUATRE choses à la fois.

| métier | ce qu'il fait dans le pied | à quelle fréquence on le lit |
| --- | --- | --- |
| un **portefeuille** | le solde | à chaque visite, d'un coup d'œil |
| un **compteur d'état** | la jauge, le reste | à chaque visite, d'un coup d'œil |
| un **mode d'emploi** | *20 per set · 100 per booster* | **une ou deux fois dans une vie** |
| une **porte** (ouvrir un booster) | le sachet, muet | quand on en a un |

Le troisième est l'intrus. **Une règle est une RÉFÉRENCE, pas une lecture** :
la relire à chaque visite ne l'apprend pas, elle encombre. Et tant qu'elle
occupe une ligne au même endroit que l'état, l'œil ne sait plus lequel des
deux il regarde. C'est exactement ce que « on comprend pas » désigne.

### 12.1 La règle qui règle tout : **UN ÉTAT, PAS UN COURS**

> Le pied du coffre dit **ce que j'ai**. Il ne dit pas comment ça marche.

Ce qui reste : le solde, le sachet, et son compte. Ce qui part : la ligne de
règle, entièrement.

### 12.2 La jauge : elle n'était pas floue, elle était MAL ATTACHÉE

« 60 to go » flottait entre le solde et la règle — visuellement rattachée
aux pièces, alors qu'elle ne parle PAS des pièces : **elle parle du
booster**. L'œil cherchait le lien et ne le trouvait pas.

→ **La progression appartient au SACHET.** Posée sous lui (ou en anneau
autour de lui), elle n'a plus rien à expliquer : on voit un sachet à moitié
rempli, on comprend qu'il arrive. Et le pied retrouve **deux blocs** au lieu
de quatre lignes : *ce que j'ai* à gauche, *ce qui vient* à droite.

Corollaire : quand on a déjà des boosters, la jauge n'a plus à s'afficher —
le compte `×2` la remplace. Un seul objet, deux états.

### 12.3 La page dédiée : NON — le panneau existe DÉJÀ

Sa question (« une page au clic du booster ? overkill ? on mélange trop ? »)
a une réponse que le dépôt donne tout seul : **`BoosterPopupHote` existe**,
il est monté à la racine, il est déjà validé, et il porte exactement les
trois choses qu'une page dédiée porterait :

1. **le sachet en grand**, dans son plan vidéo ;
2. **la phrase qui explique** (titre + sous-titre, déjà variables par robe) ;
3. **le bouton d'action** — « Ouvrir un Booster ».

**Créer une page de plus, ce serait le mélange qu'elle craint** : le booster
aurait alors TROIS présentations (la pill du profil, le panneau, la nouvelle
page) pour un seul objet. Le tap sur le sachet du coffre doit ouvrir **ce
panneau-là**. Une porte, pas deux.

⚠️ **Mais le panneau doit apprendre un deuxième état.** Aujourd'hui il
suppose qu'on a un booster (« Un booster t'attend ! »). Ouvert depuis le
coffre avec zéro sachet, il doit dire ce qu'est l'objet et où on en est —
et son bouton primaire n'est plus une action :

| | on a un sachet | on n'en a pas |
| --- | --- | --- |
| titre | *Un booster t'attend !* | *Le booster du set Lune* |
| sous-titre | *Une carte du set Lune dort à l'intérieur.* | *20 pièces par série. 100 pièces l'ouvrent.* |
| jauge | — | **60 pièces avant le prochain** |
| bouton | **Ouvrir un Booster** | *(aucun)* — « Plus tard » devient « Fermer » |

**C'est là que la règle va vivre**, et c'est sa vraie place : dans l'écran
qu'on ouvre quand on veut savoir, pas dans celui qu'on traverse.

### 12.4 Le « i » : le sachet EST l'affordance

Une pastille « i » serait un cinquième objet dans un composant qui en a déjà
trop. **Le sachet est ce qu'on veut comprendre — c'est donc lui qu'on
touche.** Il est grand, il dépasse, il bouge sous le doigt : rien dans cette
carte n'appelle autant le toucher.

⚠️ Une conséquence à trancher : il porte DÉJÀ un geste (le tirage). Tap =
le panneau, glissé = on le prend. Les deux cohabitent (`TapGesture` +
`DragGesture(minimumDistance: 2)`), mais il faut le décider — ou renoncer au
tirage, qui est un jouet, au profit du tap, qui est une porte.

### 12.5 Ce que le pied devient

```
┌──────────────────────────────────────────────┐
│                                 ┌─────────┐  │
│  1 140                          │ sachet  │  │
│  coins                          │  ▓▓▓░░  │  │   ← la jauge SOUS le sachet
│                                 └─────────┘  │      (ou ×2 si on en a)
└──────────────────────────────────────────────┘
```

Deux blocs. Aucune phrase. La plaque peut **maigrir** (128 → ~96) puisqu'elle
ne porte plus trois lignes, et le sachet **descend encore** (68 → 90 sur 145 :
il n'en sort plus qu'à 38 %), ce qui le rend plus posé et moins perché.

### 12.6 Ce qui reste à trancher

1. **La jauge sous le sachet ou en anneau autour ?** Sous : lisible, banal.
   Anneau : c'est le sachet qui se remplit, plus beau, plus lent à lire.
2. **Tap et tirage sur le même objet**, ou le tap seul ?
3. **Le panneau à deux états** — est-ce qu'il vaut le coup, ou est-ce que le
   coffre se contente d'ouvrir le manège quand on a un sachet, et de ne
   RIEN faire quand on n'en a pas (l'explication vivant seulement dans la
   proposition de fin de séance) ?
4. **Le mot `coins`** reste-t-il, ou le solde se suffit-il à côté d'une
   pièce dessinée ?

## 13. v5 — CE QUE LA MESURE TRANCHE : « grand sachet » et « ne pas empiéter » sont INCOMPATIBLES

*« Pas convaincue. Il faut pas que la card soit trop grosse pour empiéter
sur la pièce et le socle. Réfléchis à une UI ; si besoin on peut jouer sur
un overlay, à voir ? »*

**J'ai mesuré ce que le composant mange à la scène** (capture `pied4-or`,
écran 874 pt) :

| | position |
| --- | --- |
| la scène — le reflet du socle — **meurt à** | **693 pt** |
| le haut de la PLAQUE | 721 pt |
| le haut du SACHET | **644 pt** |

**La plaque n'empiète pas** : elle commence 28 pt sous la fin de la scène.
**C'est le sachet qui mord** — il monte 49 pt DANS le reflet du socle.

Et voici ce que ça implique, arithmétiquement : pour qu'il ne dépasse plus
la scène, son débordement doit tomber sous 28 pt. Sur un sachet de 145 pt,
ça veut dire **117 pt ancrés dans une plaque qui en fait 128** — c'est-à-dire
qu'il ne dépasse plus du tout.

> **« Un grand sachet qui sort de la carte » et « ne pas empiéter sur la
> scène » ne peuvent pas être vrais en même temps à cet endroit.** Ce n'est
> pas un compromis à trouver, c'est une contradiction à trancher. Mon §12
> proposait de le descendre de 68 à 90 : il aurait encore mordu de 27 pt.

### 13.1 La sortie : une BANDE, et le grand sachet dans l'overlay

Puisque le grand objet ne peut pas vivre là, **il vit ailleurs — et
l'ailleurs existe déjà** (§12.3 : `BoosterPopupHote`, qui a un plan vidéo
plein cadre fait pour ça).

En bas de la page, il ne reste que **l'état** :

```
        …la scène respire jusqu'à 693 pt…


   ┌────────────────────────────────────────────┐   ← 793 pt
   │  ◉  1 140                    ▯ ×1      ›   │     56 pt de haut
   └────────────────────────────────────────────┘   ← 849 pt
     ▔▔▔▔▔▔▔▔▔▔▔▔▔▔░░░░░░░░░░░░  le bord bas EST la jauge
```

| | avant | après |
| --- | --- | --- |
| masse visuelle en bas | 128 + 77 de débordement = **205 pt** | **56 pt** |
| ce qui mord la scène | 49 pt | **0** |
| distance à la fin de la scène | −49 pt | **+100 pt** |

Un quart de l'encombrement, et la scène retrouve tout son bas.

### 13.2 Les quatre choix qui font cette bande

1. **La jauge EST le bord bas de la carte.** Pas une barre posée dessus, pas
   un texte : le liseré du bas se remplit. Zéro objet ajouté, aucune légende
   à comprendre — et le §12.2 est respecté (elle appartient au sachet, elle
   est du même côté que lui).
2. **Le sachet redevient un marqueur** (≈ 20 × 34, la taille de la pill du
   profil), pas un sujet. Un sujet a besoin d'espace ; il l'aura dans
   l'overlay, en plein cadre.
3. **Une pièce dessinée remplace le mot `coins`** — la planche `piece-or` /
   `piece-argent` existe déjà et tourne (`PlanchePiece`). Un glyphe dit
   l'unité mieux qu'un mot, et il dit AUSSI de quelle page on parle.
4. **Un chevron** à droite : sans lui, rien ne dit que la bande s'ouvre.

### 13.3 L'overlay — ce qu'il porte, et pourquoi c'est le panneau existant

Au tap : `BoosterPopupHote`, dans ses **deux états** (§12.3) — le sachet en
grand dans son plan vidéo, la phrase qui explique, la progression en toutes
lettres, et le bouton **Ouvrir un Booster** quand il y a quelque chose à
ouvrir. La règle vit là, et nulle part ailleurs.

C'est aussi ce qui répond à « on mélange trop » : **un objet, une
présentation grande, un endroit**. La bande du coffre n'est plus une vitrine
du booster, c'est un compteur.

### 13.4 Ce qu'on perd, et il faut le dire

- **Le sachet saisissable disparaît du coffre.** À 20 × 34 il n'y a plus rien
  à prendre. Le jouet peut renaître dans l'overlay, où il a la place — et
  là-bas il n'entre en conflit avec aucun geste de page.
- **Le « il sort de la card »** est abandonné à cet endroit. C'était une
  belle idée ; la scène le refuse. Il reste vrai dans l'overlay.

### 13.5 Ce qui reste à trancher

1. **Bande avec plaque, ou sans ?** Sans plaque (le contenu posé sur le noir,
   un filet au-dessus) c'est encore plus léger — mais le tap perd sa cible
   visible. Reco : **une plaque très fine**, elle donne sa cible au doigt.
2. **La jauge en bord bas** : sur toute la largeur, ou seulement sous le
   bloc du sachet ?
3. **Que montre la bande quand le solde est à zéro** — le compteur à 0, ou
   une invitation ?
4. **La page argent n'a pas de jauge** : son bord bas reste-t-il nu, ou
   porte-t-il autre chose ?

## 14. v6 — LA VRAIE QUESTION N'EST PAS LE COMPOSANT : C'EST « OÙ VIVENT LES BOOSTERS »

*« Le user, quand il se rend sur la page Coffre, il peut voir ses boosters.
Donc peut-être que c'est pas la bonne solution ? »*

Elle a raison, et sa remarque déplace la question. J'ai passé quatre
versions à redessiner un composant alors que **le désaccord est en amont** :
personne n'a jamais tranché où un booster se REGARDE.

Aujourd'hui il apparaît à **trois endroits**, et à chaque fois autrement :

| où | comment | ce que ça dit |
| --- | --- | --- |
| la pill du profil | 15 × 26, un compteur | « tu en as » |
| le panneau de fin de séance | plein cadre, un plan vidéo | « ouvre-le » |
| le pied du coffre (mes v1-v5) | tantôt 96, tantôt 20 | on ne sait pas |

C'est ce flou qui fait que le pied ne tombe jamais juste : on lui demande de
choisir, à sa place, ce que le produit n'a pas décidé.

### 14.1 Trois modèles cohérents — et un seul répond à sa phrase

**M1 — Le coffre est le PORTEFEUILLE.** Il montre la monnaie ; les boosters
vivent au profil. C'était mon §13. **Sa phrase le réfute** : elle veut les
voir là.

**M2 — Le coffre est LE TRÉSOR, et le booster a SA PAGE.** Le carrousel du
coffre est déjà une suite d'objets posés sur un socle, un par écran. Le
booster en devient un. Il est GRAND, éclairé, sur le socle — et il n'empiète
sur rien, **puisqu'il EST la scène**.

**M3 — Le booster est DANS LA PIÈCE**, debout dans la pénombre derrière le
socle, comme une marchandise sur une étagère. Beau, atmosphérique — mais on
ne compte pas des sachets dans le noir, et on n'agit pas sur eux.

→ **M2.** C'est le seul qui satisfait « je veux les voir dans le coffre » ET
« ne pas empiéter », et il n'invente aucune grammaire : il applique celle de
la page.

### 14.2 Ce que M2 rend gratuit (et c'est ce qui le rend évident)

**Le géant du profil EXISTE.** `ProfilLune` monte déjà un `BoosterStage`
plein page — un sachet 3D qui flotte, qu'on fait tourner au doigt, avec sa
matière, ses plis et sa lumière. C'est, mot pour mot, la vitrine qu'on
cherche depuis quatre versions.

Sur une page du coffre, ce même `BoosterStage` posé sur le socle donne :

- **un sachet en grand**, sans rogner la scène — il en est le sujet ;
- **la prise au doigt, gratuite** — il tourne déjà, c'est son geste natif ;
  plus besoin du tirage bricolé du §12.4, ni de son conflit avec le geste de
  page ;
- **la même matière que la cérémonie** — c'est la MÊME scène 3D, pas une
  image de lui ;
- et la robe suit : `robe: .lune` ou `.noire`, déjà en place.

### 14.3 La loi qui en découle, et qui range tout

> **Le pied décrit TOUJOURS l'objet posé sur le socle.**

Une règle, quatre pages, aucun cas particulier :

| page | sur le socle | ce que le pied dit |
| --- | --- | --- |
| 1 | la pièce d'or | `1 140` — son solde |
| 2 | le booster orange | `×2` ouvrables · *60 pièces avant le prochain* · **Ouvrir** |
| 3 | la pièce d'argent | `1` — son solde |
| 4 | le booster noir | `×1` ouvrable · *elle tombe rarement* · **Ouvrir** |

Et trois choses se rangent d'elles-mêmes :

1. **la jauge retrouve son sujet** — elle est sur la page DU booster, elle ne
   parle que de lui, plus rien à expliquer ;
2. **le bouton « Ouvrir » trouve sa place** — c'est la question qu'elle
   posait au tour précédent (« un bouton open booster dans le détail ? ») :
   le détail, c'est cette page ;
3. **la règle a son écran** sans en créer un — elle tient sous le sachet, sur
   sa page, là où elle est enfin à propos.

### 14.4 Ce que ça coûte — dit d'avance

- **Le carrousel passe de 2 à 4 pages.** Dans une chambre au trésor, flâner
  est le sujet — mais c'est un choix produit, pas un détail.
- **Une `SCNView` de plus dans une page déjà chargée.** Le remède existe et
  est documenté : `BoosterStage(paused:)` — une `SCNView` effacée par
  l'opacité rend QUAND MÊME, il faut la suspendre hors écran. Le profil le
  fait déjà.
- **Le pied redevient simple** (une bande, un chiffre, parfois un bouton) :
  tout le travail des v1-v5 sur ses quatre faits **disparaît**. C'est du
  travail jeté, et c'est la bonne nouvelle — il n'existait que pour
  compenser l'absence de page.

### 14.5 Ce qui reste à trancher

1. **L'ordre des pages** : or → booster or → argent → booster noir (par
   économie), ou les deux monnaies puis les deux boosters (par nature) ?
2. **Le booster tourne-t-il sur le socle** comme la pièce, ou reste-t-il
   posé de face ?
3. **Une page de booster VIDE** (zéro sachet) : on la montre quand même,
   avec la jauge et « pas encore » — ou elle n'existe pas tant qu'on n'a
   rien ? (Reco : **on la montre** — c'est elle qui donne envie, et une page
   qui apparaît/disparaît fait sauter la navigation.)

## 15. v7 — LA QUESTION QUI TUE : « le user, comment il SAIT ? »

*« T'es sûr que le user comprend mieux ? Quand on arrive on voit la pièce
lune or, mais on sait pas qu'on a des boosters. Il faut une synthèse ? Je
suis perdue. »*

### 15.1 Non. Et c'est MOI qui ai fait reculer les choses.

Il faut le dire net : **ma v6 a réglé la mise en scène et cassé la
découvrabilité.** Avant, le sachet était dans le pied de CHAQUE page — laid,
mais il ANNONÇAIT. Maintenant il est superbe, sur son socle… **et invisible
tant qu'on n'a pas deviné qu'il faut glisser.**

Un carrousel sans indice est un couloir sans porte : rien à l'écran ne dit
qu'il existe une page 2, encore moins qu'il y a quelque chose à toi dedans.
Le coffre n'a même pas de points de pagination. **Sa question est le
diagnostic**, pas une remarque de détail.

### 15.2 Les deux besoins sont en tension, et un seul écran ne peut pas les servir

| besoin | ce qu'il demande |
| --- | --- |
| **la fierté** — voir son trésor en majesté | un objet, une scène, du vide autour |
| **la clarté** — savoir ce que j'ai | tout, ensemble, d'un coup d'œil |

Mes six versions ont essayé de faire tenir les deux dans le MÊME écran.
C'est pour ça qu'aucune ne tombait juste : à chaque fois, l'un mangeait
l'autre. Ce n'est pas un problème de composant, c'est **un écran qui
manque**.

### 15.3 La sortie — et c'est son mot : LA SYNTHÈSE

> **On arrive sur l'INVENTAIRE. On entre dans la VITRINE.**

```
   ┌──────────────────┐         ┌────────┐  ┌────────┐  ┌────────┐
   │   MON TRÉSOR     │         │   ◉    │  │   ▯    │  │   ▯    │
   │                  │  tap →  │ pièce  │  │ booster│  │ booster│
   │  ◉ 1 140  ▯ ×1   │  ←──    │  d'or  │  │ orange │  │  noir  │
   │  ◉ 1      ▯ ×1   │ retour  │        │  │ Ouvrir │  │ Ouvrir │
   │  ▓▓▓▓░░ 60 to go │         └────────┘  └────────┘  └────────┘
   └──────────────────┘
        l'arrivée                      les vitrines
```

- **La synthèse est la page d'arrivée.** Quatre tuiles : pièces d'or,
  booster orange, pièces d'argent, booster noir — chacune avec son compte.
  En arrivant, on voit TOUT ce qu'on possède. La question « comment il
  sait ? » n'existe plus.
- **Chaque tuile est une PORTE.** On la touche, on entre dans sa vitrine.
  Le glissé continue de marcher, mais il n'est plus le seul chemin — et
  surtout il n'est plus le chemin qu'il faut deviner.
- **La vitrine garde tout ce qui a été gagné en v6** : l'objet sur le socle,
  le projecteur, le reflet, le pied qui ne parle que de lui, le bouton
  « Ouvrir ».

C'est la structure de toutes les collections qui marchent : **un sommaire,
puis des fiches.** Pocket ne fait pas autre chose.

### 15.4 L'ANIMATION EST CE QUI REND LE PASSAGE COMPRÉHENSIBLE

Sa question (« il faut jouer avec l'animation, plus finement ? ») touche
exactement le bon nerf, et la réponse est oui — mais pas comme décoration :

**la tuile qu'on touche DEVIENT l'objet sur le socle.** Une transition
d'identité (`matchedGeometryEffect`) : la vignette grandit, se déplace, se
pose sous le projecteur. En un mouvement, l'utilisateur apprend trois
choses sans un mot — d'où il vient, où il est, et comment revenir.

C'est ça qui remplace les explications. Un carrousel où les pages
apparaissent sans lien se comprend par déduction ; un objet qu'on voit
GRANDIR depuis sa tuile se comprend sans réfléchir.

Deux autres animations qui portent du sens (et pas du vernis) :

1. **la jauge se remplit à l'arrivée** sur la synthèse (0 → 40 en 0,6 s) :
   elle attire l'œil sur la seule chose qui bouge, donc sur la progression ;
2. **le retour rend la tuile à sa place** par le même chemin — une sortie
   qui ne rejoue pas l'entrée à l'envers laisse l'utilisateur perdu.

### 15.5 Les sachets « mal découpés » — la cause, et le vrai remède

Elle a raison, et je sais pourquoi : **mon alpha est un RECTANGLE.** La
luminance ne sait pas séparer le sachet de son halo (mesuré : 12-50 des deux
côtés), j'ai donc posé une silhouette géométrique — un rectangle plein. À
la taille de la pill, invisible ; **sur le socle, en grand, ça se voit** :
le halo est coupé net sur les côtés, et la vraie silhouette du sachet (les
sertissages crantés, les coins pincés) n'est pas suivie.

Trois remèdes, par ordre de justesse :

1. **Elle réexporte les deux rendus AVEC un fond transparent** — son outil
   le fait, `Booster_orange.png` a déjà un canal alpha (mais entièrement
   opaque). C'est exact, définitif, et ça coûte un export. **→ le vrai
   remède.**
2. **Détourer depuis le maillage** : `BoosterScene` a le sachet en 3D ; un
   rendu de sa silhouette donnerait un masque exact. Faisable, mais c'est
   fabriquer ce qu'un export donne gratuitement.
3. Affiner le masque à la main (spline sur les crans) — long, fragile,
   à refaire à chaque nouvelle robe.

### 15.6 Ce que ça coûte, et ce que ça range

- **Un écran de plus** — mais il REMPLACE la page d'arrivée actuelle, il ne
  s'ajoute pas au parcours.
- **Le pied disparaît de la synthèse** : les tuiles portent les nombres.
- **Les points de pagination deviennent utiles** (5 crans), et le retour à
  la synthèse a un geste évident (le chevron, déjà là).

### 15.7 À TRANCHER — une seule question, les autres en découlent

> **La synthèse est-elle une PAGE du carrousel (cran 0, on y revient en
> glissant) ou un ÉCRAN au-dessus (on y revient par le chevron) ?**

- **Page** : un seul geste pour tout, cohérent avec ce qui existe ; mais
  l'inventaire devient « une vitrine parmi d'autres », ce qu'il n'est pas.
- **Écran au-dessus (recommandé)** : la hiérarchie est claire — sommaire →
  fiche —, la transition d'identité est naturelle, et le chevron retrouve
  son sens (il ferme le coffre depuis la synthèse, il remonte à la synthèse
  depuis une vitrine).

## 16. AUTO-CHALLENGE — une de mes deux affirmations est FAUSSE, et ma reco est probablement trop lourde

*« Tu es sûr ? Re-challenge — peut-être que tu as raison aussi ? »*

### 16.1 « Les sachets sont mal découpés à cause de mon alpha rectangulaire » — FAUX, mesuré

J'ai affirmé ça au vu d'un zoom, sans sonde. C'est exactement l'erreur que
la maison a payée (*un juge qui affirme ne remplace pas une sonde qui
mesure*), et je me la suis faite à moi-même.

**Sonde au bord présumé du rectangle d'alpha** (x = 143 pt), sur la page du
booster orange :

```
   y = 40 %  →  13,5   13,4   13,5   14,8   16,2
   y = 55 %  →   2,0    3,0    4,0   12,1   28,4
```

Aucune marche : une rampe douce. Idem au-dessus du sachet (255 → 169 → 87 →
66 → 59, c'est le dégradé de la scène). **Le rectangle d'alpha ne se voit
pas** à cette taille.

**La vraie cause est ailleurs, et elle est dans l'asset** : dans les deux
rendus, le sachet touche le BAS du cadre —

| | dernière ligne de l'image | 30 lignes plus haut |
| --- | --- | --- |
| `Booster_orange` | luminance 242 | 247 |
| `booster noir` | 50 | 71 |

Une image qui finit à 242 de luminance sur sa dernière ligne n'est pas
finie : **son pied et son reflet sont coupés par le cadre du rendu.** C'est
ça qu'on lit comme « mal coupé », et aucun détourage ne le réparera.

→ **Le remède est un ré-export avec de la marge sous le sachet** (et, tant
qu'à faire, un fond transparent — §15.5). Deux clics dans son outil ; moi je
ne peux que deviner ce que le rendu, lui, sait.

### 16.2 « Il faut une synthèse » — probablement TROP LOURD, et voici pourquoi

Quatre arguments contre ma propre recommandation :

1. **Quatre objets FIXES ne sont pas un inventaire.** Un sommaire gagne son
   écran quand la collection grandit (des cartes, une boutique). Ici, ce
   serait un menu de quatre boutons — administratif, là où la page est un
   écrin.
2. **Ça change la nature du coffre.** Son premier écran est aujourd'hui une
   scène (« Find what you worked for », le halo, le socle). Arriver sur une
   grille de tuiles, c'est troquer un écrin contre un relevé de compte.
3. **Ça ajoute un étage** : accueil → coffre → objet, pour un portefeuille à
   deux monnaies.
4. **Et surtout : l'affordance EXISTE DÉJÀ et je ne l'ai pas vue.** Sur mes
   propres captures, les voisins du carrousel sont là, flous, aux deux bords
   — ces disques sombres à gauche et à droite du sachet. Le carrousel DIT
   déjà qu'il y a autre chose. **Il le dit trop bas** : à 2-13 de luminance,
   personne ne les lit.

### 16.3 La proposition qui remplace la mienne : **la synthèse tient dans une barre de 20 points**

Plutôt qu'un écran, une **rangée de crans en bas de scène** — mais des crans
qui sont **les objets eux-mêmes**, pas des points :

```
        ◉    ▯¹   ◉    ▯¹        ← 4 glyphes, 20 pt de haut
        ●    ○    ○    ○           celui de la page est plein
```

Elle dit les trois choses qui manquaient, en une bande :

- **ce qui existe** (quatre objets, donc quatre pages) ;
- **où je suis** (le cran plein) ;
- **ce que je possède** — un petit badge sur le glyphe quand le compte est
  > 0. *C'est la réponse exacte à « comment il sait qu'il a des boosters »* :
  il le voit en arrivant, sans changer d'écran.

Et deux réglages qui coûtent trois lignes :

1. **remonter les voisins** de 2-13 à ~35-45 de luminance : on reconnaît un
   sachet orange au bord, donc on sait qu'il y a un sachet ;
2. **une pichenette à l'arrivée** (le rail avance de 14 pt et revient) — le
   geste s'apprend en le voyant.

### 16.4 Ce qui départage les deux — une question de PRODUIT, pas de design

> **Le coffre contiendra-t-il un jour plus que ces quatre objets ?**

- **Non** (deux monnaies, deux boosters, pour toujours) → **la barre de
  crans**. Elle règle la découvrabilité sans rien coûter à la scène.
- **Oui** (trophées, sets de cartes, objets à venir) → **la synthèse**
  devient nécessaire, et autant la poser maintenant.

**Mon avis, révisé : la barre de crans.** Ma v7 réglait le bon problème par
un moyen disproportionné — je l'avais choisi parce qu'il était structurant,
pas parce qu'il était juste.

### 16.5 Sur l'animation, en revanche, je ne change pas d'avis

Elle a raison et ça reste vrai dans les deux scénarios : **le passage doit
être un mouvement d'identité**, pas une apparition. Avec la barre de crans,
c'est le glyphe touché qui grandit vers le socle. Sans ce lien, un carrousel
se comprend par déduction ; avec lui, il se comprend sans réfléchir.

---

## 9. À TRANCHER

1. **Le mot de la deuxième pièce à l'écran** : *legendary coin* (recommandé),
   *silver coin*, ou *black coin* ?
2. **Le verre du pied** : `.regular` assumé, ou nappe non-verre ?
3. **La page argent à zéro** : que dit-elle quand on n'a aucune pièce ? Le
   compte à 0 et la règle (recommandé : elle explique, elle ne console pas),
   ou une invitation ?
4. **Le prix du booster orange — 100 pièces** est écrit dans la note rewards
   (§4 sexies) mais nulle part dans le code. Le pied du coffre serait le
   premier écran à l'annoncer : on le confirme ?
5. **La progression, en barre ou en texte ?** Une barre dit l'avancée d'un
   coup d'œil ; un texte (« 38 coins to go ») tient dans la ligne de règle et
   ne demande pas de place.

---

## 17. v8 — LA LEÇON D'OPAL, ET LE DÉTOURAGE QUI EST FAUX (28-08)

Verdict : *« je vois pas le détourage / je trouve pas encore l'interface
claire / remonte le background de 15 % / comment je vois une vue d'ensemble
de tout ce que j'ai ? / regarde OPAL on a pas piqué des trucs dedans ? »*

### 17.1 Le détourage — il est BIEN dans le build, et il est FAUX

Vérifié d'abord côté mécanique, parce que « je ne vois pas » a deux causes
possibles et l'une est bête : le bundle installé sur `kat-booster` porte
`booster-pill.png` du **28-08 18:43** (le bake est de 18:42). Elle regarde
bien la nouvelle vignette. Ce n'est donc pas un build périmé.

**C'est le détourage lui-même qui est faux, et seulement sur l'orange.**
Profil de la silhouette, ligne par ligne, largeur opaque :

| y (sur 435) | orange | noir |
|---|---|---|
| 100 → 350 | 207-214 | 205-209 |
| **375** | **239** | 221 |
| **400** | **246** (x 0 → 246) | 225 |

Le noir tient sa largeur jusqu'en bas. **L'orange s'évase jusqu'aux BORDS DU
CADRE sur ses 60 dernières lignes — 14 % de sa hauteur.** Son pied n'est pas
un pied : c'est une dalle. Le garde-fou de la médiane (§ `bake_vignettes.py`)
laisse passer cette ligne-là parce que son débord reste sous la tolérance en
coordonnées source ; elle est ensuite recopiée vers le bas par le
prolongement. Bug à moi, dans le bake.

**Et sous ce bug, la cause de fond, déjà mesurée et toujours vraie : ses deux
rendus sont COUPÉS par le cadre du rendu.** Dernière ligne du fichier orange
à L 242 — en pleine lumière. Le sachet n'a pas de pied dans le fichier. Aucun
algorithme ne détoure des pixels qui n'ont jamais été rendus ; mon fondu de
26 px lui en INVENTE un. Il faut le ré-export, avec de la marge sous le
sachet — idéalement sur fond transparent, et alors toute cette machinerie
disparaît.

**Troisième point, et c'est le point d'UI, pas de bake : sur une page noire,
un détourage ne se voit presque pas.** L'alpha ne change que ce qu'on voit
DERRIÈRE ; derrière, depuis qu'on a retiré la card de verre, il n'y a que du
noir. Un détourage ne vaut que ce qu'il CHEVAUCHE. Chez Opal, la gemme
chevauche le rocher, la faille, ses voisines — c'est de là que vient
l'impression d'objet posé dans un monde.

### 17.2 Opal contre nous, mesuré sur les deux captures

| | Opal (sa capture) | Coffre v7 (mesuré) |
|---|---|---|
| centre du sujet | **0,28 H** | **0,52 H** |
| frontière décor / noir | aucune | **0,418 H**, franche |
| largeur du sujet | ~38 % W | 24,5 % W |
| sol | 0,38 → 0,70 H, sombre, TEXTURÉ | socle 0,66 → 0,72 H |
| entre le sol et le premier texte | 0 (le texte est SUR le sol) | 190 pt de noir mort + une barre de crans |
| voisins visibles | **oui, coupés aux deux bords** | non |

Son « remonte de 15 % » est juste et **sous-évalué : l'écart est de 24
points de hauteur d'écran.**

### 17.3 Les cinq lois d'Opal qu'on peut prendre

1. **UNE SCÈNE CONTINUE, PAS UN FOND DANS UNE BOÎTE.** Opal n'a ni card, ni
   plaque, ni séparateur : la faille, le ciel, le rocher courent d'un bord à
   l'autre, de la barre d'état à la tab bar. Notre mur, lui, **MEURT à
   0,418 H** : une frontière horizontale en travers de l'écran, et sous elle
   l'objet flotte dans une autre pièce que son propre décor. Chez Opal la
   lumière décroît, la matière continue.

2. **LE SUJET EST HAUT.** 0,28 H contre 0,52. Concrètement : néon vers
   0,20-0,22 H, sachet centré vers 0,36 H, dessus du socle vers 0,50 au lieu
   de 0,665. Ça libère tout le tiers bas — précisément ce qui manque depuis
   le §13, où « grand sachet » et « ne pas empiéter » avaient été déclarés
   incompatibles. **Ils l'étaient à cadrage constant. Ils ne le sont plus si
   la scène remonte.**

3. **LE SOL EST GRAND, SOMBRE, ET NE DIT RIEN.** Le rocher d'Opal prend 30 %
   de la hauteur et ne porte AUCUNE information — c'est un plancher de
   théâtre. Et c'est ce plancher qui autorise le texte à être écrit DESSUS,
   sans card : « Analyse de ton score… » est posé à même la pierre.
   **C'est ça qui tue notre pied.** Notre pied est une plaque parce que le
   texte n'a nulle part où se poser. Si le sol grandit, la plaque disparaît
   et le texte devient une inscription — et la question « le composant verre
   fait cheap » ne se pose plus : il n'y a plus de composant.

4. **LA LUMIÈRE VIENT DE L'OBJET.** La gemme éclaire le rocher en vert ; la
   gemme verrouillée n'éclaire rien. Chez nous, le socle est éclairé par le
   néon de la pièce — **la même lumière pour les quatre objets**, et c'est
   la vraie raison pour laquelle les quatre pages se ressemblent. Chaque
   objet doit tenir sa flaque : or chaud, argent froid, booster orange en
   braise, booster noir en violet sourd. La transition d'identité devient
   alors gratuite — en traversant, la couleur du sol change AVANT que
   l'objet n'arrive.

5. **LE VERROUILLÉ SE DIT PAR LA MATIÈRE, PAS PAR UN CADENAS.** Sa 4ᵉ
   capture : la gemme verrouillée est la même silhouette, en pierre grise —
   couleur et lumière retirées. Le cadenas ne vient qu'APRÈS, petit, dans le
   bouton. Matière d'abord, icône ensuite. Transposable tel quel : un
   booster qu'on ne peut pas payer, c'est le même sachet, MAT, sans braise ;
   le jour où on peut le payer, il s'allume. Une jauge qu'on n'a pas besoin
   de lire.

### 17.4 « Comment le user voit tout ce qu'il a ? » — le diagnostic

Le problème n'est pas qu'il manque un écran de synthèse. **C'est qu'à
l'arrivée, rien à l'écran ne dit que la page a des voisines.** Les quatre
crans font 6 pt, vivent à 0,80 H, dans le noir, à 200 pt sous l'objet.
Personne ne regarde là.

**La réponse d'Opal est dans sa propre capture n°4 : LES VOISINS DÉPASSENT.**
La boule d'opale entre par le bord gauche, à moitié coupée, un autre rocher
par le bord droit. Pas de légende, pas de geste à deviner : on VOIT qu'il y
en a d'autres, de quel côté, et à peu près combien. Zéro surface nouvelle,
zéro vocabulaire nouveau, permanent, et actif exactement à l'instant qui
l'inquiète — l'arrivée.

**Le prix à payer, et il est architectural :** les voisins doivent être
éclairés et dans le MÊME espace. Les quatre socles doivent former **un rail
unique**, pas quatre pages indépendantes. C'est ce qui rend possible, ensuite
et presque gratuitement, le dézoom.

### 17.5 Ses trois idées, classées

- **LE DÉZOOM — oui, mais en second.** C'est la vraie « vue d'ensemble », et
  elle devient quasi gratuite une fois le rail en une seule scène. Deux
  règles : il se déclenche sur l'OBJET (pincement) ou sur la barre de crans —
  qui cesse alors d'être un décor pour devenir une commande —, et il se
  referme du même geste. Un aller-retour, jamais un aller simple.
- **LA POP-UP RÉCAP — non.** Elle couvre exactement ce dont elle parle, elle
  s'impose au lieu de s'offrir, et il faut la congédier. Surtout : **la
  page des gains existe déjà**, en haut à droite. Deux récaps, c'est aucun
  des deux lu. Le travail n'est pas d'en faire une autre, c'est de rendre
  celle-là trouvable.
- **LA PASTILLE ANIMÉE — bonne idée, mauvais endroit.** Une pastille dit un
  NOMBRE, pas un QUOI. Elle ne répond pas à « qu'est-ce que j'ai », elle
  répond à « quelque chose est arrivé ». Sa place est à l'ENTRÉE du coffre
  (home, profil) et sur le bouton des gains — pas au milieu de la page. Chez
  Opal c'est exactement la pastille flamme « 1 » en haut à droite : deux
  glyphes, minuscule, permanente.
- **FAIRE VIBRER LES QUATRE — non, et c'est une ligne de motion design.**
  Un mouvement qui rejoue à chaque arrivée devient du bruit en trois visites,
  et il fait paraître les objets INSTABLES. **Chez Opal, les objets ne
  bougent jamais** : seules la lumière et la caméra bougent. Tenons ça. Le
  coup de coude d'arrivée, lui, reste — mais UNE fois, à la première visite.

### 17.6 Ce que je ne prendrais PAS à Opal

Sa home est un TABLEAU DE BORD (rangée de chips, pile de cards, chiffres du
jour). Le coffre est une SALLE DU TRÉSOR. On ne prend ni les chips, ni la
pile de cards, ni surtout la preuve sociale (« Obtenue par 98 % ») : nous
n'avons pas de cohorte, et un pourcentage inventé est un mensonge.

### 17.7 L'ordre des travaux

1. **Le ré-export des deux rendus, avec marge sous le sachet** (elle) — plus
   le correctif du bake sur l'évasement de l'orange (moi). Tant que le pied
   est une dalle, tout jugement de cadrage est faussé.
2. **Remonter la scène de ~20 points** : néon 0,332 → 0,21, socle 0,665 →
   0,50, sachet centré vers 0,36.
3. **Les voisins qui dépassent** — le rail en une seule scène.
4. **Tuer la plaque du pied** : la règle et le compte écrits à même le sol.
5. **La flaque de lumière propre à chaque objet** (identité + transition).
6. **Le verrouillé en matière mate**, cadenas seulement dans le bouton.
7. **Le dézoom**, si 3 n'a pas suffi.

### 17.8 v8 — CE QUI EST CODÉ, ET CE QUE ÇA A COÛTÉ

**Le détourage (17.7 §1).** Deux bugs à moi dans `bake_vignettes.py`, et
aucune tolérance globale ne pouvait les couvrir : à 2 % de W l'orange perdait
ses crans du HAUT, à 2,5 % il gardait l'évasement du BAS. Changement de
principe — **le cran du haut donne l'enveloppe, et rien en dessous n'a le
droit d'en sortir** ; et le pied inventé recopie la MÉDIANE des trente
dernières lignes, plus la dernière (une seule ligne fausse définissait tout le
pied sur 110 lignes).

Puis la mesure m'a corrigé : ce que je prenais pour un évasement de silhouette
était **le halo à 0,85 d'alpha** — 217/255, indistinguable d'un aplat. Plafonné
à 0,55 et éteint sur les 60 dernières lignes avec le corps. Résultat, largeur
opaque ligne par ligne :

| | cran haut | corps | cran bas |
|---|---|---|---|
| orange | 224 | 207 | 221 |
| noir | 224 | 205 | 220 |

Symétriques, et identiques entre les deux robes. Ce qui dépasse encore (242)
n'est plus opaque : c'est la lueur.

**La scène (17.7 §2).** `barreY` 0,375 → 0,225 · `podiumY` 0,665 → 0,545 ·
`piece` 130 → 150. Mesuré sur capture : le néon passe de **0,332 à 0,187 H**,
le centre du sujet de **0,487 à 0,415 H**, sa largeur de **24,0 à 28,4 % W**.

⚠️ **ET LE NŒUD DU §13 ÉTAIT LE TITRE.** Trois lignes de 30 pt descendaient à
235 pt ; le titre ne vit que sur le mur ÉCLAIRÉ (encre sombre), donc la barre
ne pouvait jamais monter au-dessus de 0,315 H — et sous cette barre, le sachet
à sa vraie taille ne rentrait plus. « Grand sachet » et « ne pas empiéter »
n'étaient pas contradictoires : ils l'étaient À CADRAGE CONSTANT, et le
cadrage était cloué par un texte. Le titre passe à 17 pt et garde tout ce qui
le fait lui (trois lignes, la cascade, les deux encres).

**Le pied (17.7 §4).** Plus de plaque. Compte, règle, jauge, **le reste SOUS
la jauge** (le verdict « la jauge et 60 to go on comprend pas » venait de les
avoir mis côte à côte : un nombre à droite d'une barre se lit comme une
légende d'axe), puis « Ouvrir » en capsule large — la place qu'Opal donne à
« Verrouillée ».

**Les flaques (17.7 §5).** Une par objet, dans sa couleur. Mesuré sur le
dessus du socle :

| page | R | V | B | R−B |
|---|---|---|---|---|
| pièce d'or | 165 | 122 | 65 | **+100** |
| booster lune | 166 | 102 | 51 | **+114** |
| booster noir | 136 | 95 | 123 | **+13** (violet) |

Premier réglage trop fort (0,16 + 0,50) : le socle noir virait au mauve
d'aplat, la matière ne se lisait plus. **Une flaque teinte une matière, elle
ne la remplace pas** → 0,11 + 0,40.

**Les voisins (17.7 §3).** Pas de rail à refaire : ils EXISTAIENT déjà, ils
étaient illisibles. Luminance mesurée **0 → 19** dans la bande du sol, 50-54
sur le voisin lui-même (contre 2-13 avant). Flou 5,0 → 3,4 · assombrissement
−0,17 → −0,13 · **et la flaque, qui fait le plus gros du travail : on ne voit
pas l'objet, on voit qu'il y a quelque chose de posé là.**

Contrecoup mesuré et corrigé au deuxième tour : le sujet passé à 150, le
voisin a grossi avec lui — **32 % de la largeur d'écran contre 33 % pour le
sujet**. Un voisin aussi gros que ce qu'on présente se dispute la vedette. Il
recule (échelle 0,87 → 0,76) et s'éloigne (`pas` 0,38 → 0,415 W).

**Pas encore fait :** le verrouillé en matière mate (17.7 §6) et le dézoom
(§7). Et il manque toujours **le ré-export des deux rendus avec de la marge
sous le sachet** : leur pied est INVENTÉ par le bake, sur 111 lignes pour
l'orange.

---

## 18. v9 — PLAN : « REWARDS », LES HALOS QUI FONT CALQUE, LA POUDRE, ET LE DÉTOURAGE QUI NE PEUT PAS MARCHER

Verdict du 28-08 : *« très bien enlève le texte Find what.. / tu mets Rewards
en dégradé de noir (même taille que titre sur la page calendrier) et baisse un
peu le podium de 10 px / et les halos font pas naturel on dirait des calques,
améliore / et fais un effet de poudre de paillette quand on passe de l'un à
l'autre / aussi pour la partie booster avec la jauge anime-la davantage / et
le détourage va pas des boosters pourtant tu as bien réussi sur les autres
pop-up rewards »*

### 18.1 « REWARDS » — et il RÉPARE le cadrage au lieu de le contraindre

Le titre de la page Calendrier, relevé (`CalLab.enTeteBac`) :
`.font(.inter(30, .bold)).tracking(-0.4)` + `WoopGradient.titleFade`.
Ce dégradé-là est BLANC (1,00 → 0,25, topLeading → bottomTrailing) : il est
fait pour du fond sombre. Le titre du coffre vit sur le mur ÉCLAIRÉ — il lui
faut son **miroir noir**, mêmes arrêts, même diagonale, de `.black` 0,92 à
`.black` 0,25. C'est exactement son « dégradé de noir ».

⚠️ **ET ÇA DÉFAIT LE NŒUD DU §17.8.** J'avais dû rapetisser le titre à 17 pt
parce que TROIS lignes de 30 pt descendaient à 235 pt et clouaient la barre
néon. **Un seul mot ne fait qu'une ligne** : chevron jusqu'à 101, titre de 117
à 155, néon à 197 → **42 pt d'air**. Le titre reprend donc ses 30 pt sans rien
coûter, et il en reste même pour monter la barre plus haut si elle le mérite.

Le podium descend de 10 px : `podiumY` 0,545 → **0,5564** (10 / 874).

### 18.2 LES HALOS FONT CALQUE — le diagnostic, et il est mérité

Ma flaque est une `Ellipse` remplie d'un dégradé radial, composée en
`plusLighter` **PAR-DESSUS** l'image du socle. Autrement dit : c'est
littéralement un calque. Quatre raisons pour lesquelles l'œil le voit :

1. **Elle a une empreinte géométrique parfaite.** Une ellipse alignée sur les
   axes, à décroissance radiale régulière : aucune lumière réelle ne tombe
   comme ça sur un cylindre.
2. **Elle ne connaît pas la matière qu'elle éclaire.** Elle allume le socle,
   le sol et le vide derrière le socle avec la même valeur — or une lumière
   ne se voit QUE sur ce qu'elle touche.
3. **Elle n'éclaire pas l'objet.** Une flaque de lumière sous un sachet
   renvoie forcément sur son dessous. Le nôtre reste noir : d'où
   « posé sur un disque de couleur » au lieu de « éclairé par en dessous ».
4. **Elle s'ajoute à un additif.** Le socle est DÉJÀ en `plusLighter`
   (`CoffreV2Podium`) : deux additifs empilés saturent, et une zone saturée
   n'a plus de matière — c'est le plat qu'elle voit.

**LE REMÈDE, EN QUATRE POINTS — et le 2 est le principal :**

1. **DEUX lumières, pas une.** Une *tache de contact* — petite, chaude,
   décroissance courte, au point de pose exact — et un *lavis d'ambiance* —
   très large, très faible, sans bord visible. Une seule ellipse essayait
   d'être les deux et ne lisait ni comme l'une ni comme l'autre.
2. ⚠️ **LA LUMIÈRE SE MASQUE PAR LA MATIÈRE.** Le calque de couleur passe en
   `.mask(Image("coffre-podium"))` : il n'existe plus que là où il y a du
   socle. La texture du socle module alors la lumière (ses reflets, son
   biseau, son ombre propre), et le bord de l'ellipse disparaît puisque c'est
   le socle qui découpe. **C'est ce seul changement qui fait la différence
   entre « une lumière » et « un calque ».**
3. **Le retour sur l'objet.** Une deuxième copie de la couleur, masquée par
   l'alpha du sachet lui-même, en bas seulement (dégradé vertical), à ~0,10 :
   le dessous du sachet prend la teinte du sol. C'est ce détail qui fait
   qu'un objet est DANS la scène.
4. **La perspective.** La flaque est vue de trois quarts : son centre est
   légèrement DERRIÈRE le point de contact, pas dessus, et son écrasement
   vertical doit suivre celui du dessus du socle (l'ellipse du socle est
   mesurée dans `CoffreV2Podium`, on lui emprunte son rapport).

⚠️ Et le plafond de force reste : mesuré, le socle noir virait à
R136 V95 B123 — un mauve d'aplat. **Une flaque teinte une matière, elle ne la
remplace pas.**

### 18.3 LA POUDRE DE PAILLETTE — et elle doit faire un travail, pas décorer

La proposition : la poudre est émise par l'objet **qui s'en va**, au moment où
il quitte le socle, et elle prend la **couleur de celui qui arrive**. La
poudre EST le passage de témoin — l'animation raconte l'identité au lieu de
l'illustrer.

Trois règles de fabrication, et elles sont toutes payées ailleurs dans la
maison :

1. ⚠️ **ELLE SE PILOTE PAR `page`, PAS PAR UNE HORLOGE.** Un grain dont la
   position vient d'un `TimelineView` joue une séquence ; un grain dont la
   position vient de `page` **suit le doigt** — on tire à moitié, la poudre
   est à moitié, on relâche, elle revient. C'est la différence entre un effet
   et une matière.
2. ⚠️ **LE `Canvas` NE VIT QUE PENDANT LE VOYAGE.** Loi de la maison : un
   `Canvas` rastérise toute sa surface même vide. Il se monte à
   `|page − round(page)| > 0,004` et se démonte au repos. Au repos, coût zéro.
3. ⚠️ **AUCUN `@State` ÉCRIT PAR IMAGE** sur la vue qui contient la page —
   le piège `woop-piege-page-reevaluee`. Les grains sont une fonction pure de
   (graine, `page`) ; rien ne s'écrit.

Réglages de départ : 70 grains, tailles 0,8 → 2,2 pt, dispersion en cône vers
le haut depuis le dessus du socle, vitesse proportionnelle à |Δpage|, extinction
en fin de course. Vérification obligatoire : `SondeCadence` avant/après, et
`./tools/charge.sh` avant toute mesure (⚠️ la charge machine invalide les
cadences).

### 18.4 LA JAUGE — ce qui lui manque, c'est l'APRÈS

Elle se remplit une fois à l'arrivée, puis elle est morte. Quatre ajouts, du
plus utile au plus décoratif :

1. **Le nombre COMPTE.** « 60 to go » apparaît ; il devrait **descendre** de
   100 à 60 en même temps que la barre se remplit (`contentTransition
   (.numericText())` est déjà en place sur le solde, ici il faut animer la
   valeur elle-même). Un chiffre qui bouge se lit comme une mesure ; un
   chiffre qui apparaît se lit comme une étiquette.
2. **La tête de la barre porte une braise** — un point lumineux à l'extrémité
   remplie, dans la couleur de la page. Il dit « c'est ici que ça avance ».
3. **Un lustre qui passe** — un reflet qui balaie la partie REMPLIE toutes
   les ~3,2 s, en 0,9 s. Lent, faible (0,25), et seulement sur le rempli :
   c'est ce qui distingue « en cours » de « figé ».
4. **La passation à pleine jauge.** Quand le compte suffit, la jauge cesse
   d'être le sujet : elle s'éteint doucement et **c'est le bouton « Ouvrir »
   qui prend la lumière** (une pulsation lente sur sa capsule). Une page ne
   doit jamais avoir deux choses qui appellent en même temps.

### 18.5 LE DÉTOURAGE — pourquoi il ne peut PAS marcher, et ce qui marche

Elle a raison, et la mesure dit pourquoi. J'ai comparé mes vignettes à
l'asset des pop-up rewards :

| asset | taille | alpha > 250 | alpha entre 10 et 250 | **largeur du bord** |
|---|---|---|---|---|
| `sticker-booster` (rewards) | 794 × 1278 | **94,8 %** | 0,4 % | **2 px** |
| `booster-orange` (rewards) | 1054 × 1408 | 62,4 % | 22,1 % | 113 px |
| `booster-pill` (le mien) | 252 × 435 | 76,5 % | 16,2 % | **23 px** |

**`sticker-booster` est un VRAI détourage** : 2 px de transition, 94,8 % de
pixels pleins. Le mien a un bord de 23 px sur une vignette de 252 — **9 % de
sa largeur en flou**. Voilà ce qu'elle voit : pas un objet découpé, un objet
qui s'estompe.

Et la cause n'est pas l'algorithme, elle est dans la SOURCE :

⚠️⚠️ **LE RENDU ORANGE PORTE SON PROPRE HALO DANS SES PIXELS.** Un détourage
peut retirer un fond ; il ne peut pas retirer une lueur qui est peinte
AUTOUR de l'objet et qui déborde son bord. Mon bake essayait de garder cette
lueur (en alpha proportionnel à la lumière) — d'où les 16 % de pixels
mi-transparents, d'où le flou. Le noir, dont le rendu n'a presque pas de
halo, s'en sort d'ailleurs bien mieux à l'œil, et c'est cohérent.

**LA DÉCISION À PRENDRE, ET ELLE EST STRUCTURANTE :**

> **La lueur appartient à la SCÈNE, pas au sprite.**

Un sprite qui transporte sa propre lumière ne peut pas être ré-éclairé, ne
peut pas changer de couleur selon la page, et son halo se lira toujours comme
un rectangle de brume sur tout fond qui n'est pas celui du rendu. Donc :

1. **L'alpha devient la silhouette SEULE** — plus de terme de halo, bord de
   2-3 px comme `sticker-booster`. La vignette devient un objet net.
2. **La lueur est refaite en SwiftUI**, derrière l'objet, masquée par sa
   propre silhouette et floutée : elle devient réglable par page, et elle
   partage sa couleur avec la flaque du §18.2. Un seul système de lumière
   pour la page, au lieu d'un sprite qui s'éclaire tout seul.
3. **Reste le pied INVENTÉ.** Les deux rendus sont coupés par leur cadre
   (dernière ligne de l'orange à L 242) ; le bake fabrique 111 lignes de pied
   sur l'orange. Aucune de ces deux étapes ne peut l'inventer juste. **Le
   ré-export avec de la marge sous le sachet reste nécessaire**, et sur fond
   transparent il rend d'ailleurs tout le §18.5 caduc.

### 18.6 L'ORDRE

1. « Rewards » + le podium à −10 px (petit, et ça rend de l'air au cadrage).
2. Le détourage : alpha = silhouette seule, lueur rendue en scène.
3. Les flaques masquées par la matière (§18.2) — c'est le gros gain visuel.
4. La jauge (§18.4).
5. La poudre (§18.3), en dernier parce que c'est la seule qui coûte de la
   cadence, et elle se mesure.

### 18.7 CE QUI EST CODÉ (v10), ET LES DEUX MESURES QUI TRANCHENT

**« Rewards ».** `inter(30, .bold)`, tracking −0,4 — la cote du titre
Calendrier — dans le miroir NOIR de `WoopGradient.titleFade` (0,92 → 0,22, même
diagonale). Et il rend de l'air au lieu d'en prendre : un mot ne fait qu'une
ligne, le titre s'arrête à 155 pt, le néon est à 197. Podium à −10 px.

**Le détourage.** Le halo est sorti de l'alpha. Mesuré :

| | opaque | mi-transparent | **bord** |
|---|---|---|---|
| `sticker-booster` (la référence) | 94,8 % | 0,4 % | **2 px** |
| `booster-pill` AVANT | 76,5 % | 16,2 % | **23 px** |
| `booster-pill` APRÈS | 76,7 % | **4,4 %** | **2 px** |

La cote exacte de la référence. Et la lueur est refaite dans la scène
(`lueurObjet`), où elle prend la couleur de la page, suit le voyage et
s'éteint quand l'objet quitte la lumière — trois choses qu'un halo peint dans
des pixels ne saura jamais faire.

**Les flaques.** Trois couches au lieu d'une ellipse : la tache de contact
**masquée par la luminance de l'image du socle**, un lavis d'ambiance, la
lueur de l'objet. ⚠️ Masquée par la LUMINANCE et pas par l'alpha : le PNG du
socle a un fond noir OPAQUE (il se compose en additif), masquer par l'alpha
aurait rendu le rectangle qu'on voulait tuer.

Preuve que la lumière suit la matière — le liseré du socle contre son corps :

| page | liseré | corps | rapport |
|---|---|---|---|
| booster lune | R138 V89 B50 | R53 V38 B25 | **2,61 ×** |
| booster noir | R122 V84 B84 | R48 V36 B34 | **2,57 ×** |

Un calque plat les aurait éclairés à l'identique. C'est là toute la différence
entre « une lumière » et « un calque ».

⚠️⚠️ **ET UNE LOI EST TOMBÉE EN ROUTE : UN DÉGRADÉ RADIAL DOIT ATTEINDRE ZÉRO
AVANT LE BORD DE SA FORME, SINON LA FORME DEVIENT LE BORD.** Mon lavis était
une `Ellipse` de 185 × 30 remplie d'un radial de rayon 96 : à 15 px du centre —
son bord bas — le dégradé était encore à ~85 %, et la forme le coupait net.
Mesuré sur la capture : **une marche horizontale en travers de tout l'écran à
0,656 H**. Exactement le défaut de calque qu'on venait de corriger, sous une
autre forme. Remède géométrique : un DISQUE dont le dégradé meurt pile à son
rayon, écrasé ensuite par `scaleEffect`. Saut maximal mesuré **6,7 → 2,8 /
255** — imperceptible.

**La jauge.** Le nombre DESCEND de 100 à 60 avec la barre (un chiffre qui
bouge est une mesure, un chiffre qui apparaît est une étiquette) · une braise
en tête, dans la couleur de la page · un lustre toutes les 3,2 s sur la partie
remplie, en `repeatForever` sur un `@State` lu par un `offset` — **jamais un
`TimelineView`**, qui ré-évaluerait un corps par image · et **la passation** :
quand un sachet attend déjà, la jauge tombe à 0,62 et c'est le bouton qui
respire. Une page ne doit jamais avoir deux choses qui appellent en même temps.

**La poudre.** Émise par l'objet qui PART, dans la couleur de celui qui
ARRIVE — le passage de témoin, pas un confetti. Pilotée par `page` et non par
une horloge : elle suit le doigt, on tire à moitié elle est à moitié. Le
`Canvas` ne se monte qu'au-delà de `|page − round(page)| > 0,004` et se
démonte à la pose (au repos, coût zéro — vérifié sur capture figée à
`-coffrePage 1` : aucun grain).

**Reste à mesurer** : la cadence PENDANT le voyage, qui demande un vrai doigt
(⚠️ `./tools/charge.sh` d'abord — la charge machine invalide toute mesure de
cadence). Et toujours le ré-export des deux rendus avec de la marge sous le
sachet : le pied reste inventé sur 111 lignes pour l'orange.

### 18.8 LE DÉTOURAGE — L'ERREUR ÉTAIT DE LE FAIRE

Verdict : *« c'est pénible, t'arrives pas le détourage, c'est pas
compliqué »*. Elle avait raison, et la cause n'était dans aucune des quatre
versions : **je reconstruisais une silhouette que quelqu'un avait déjà
détourée.**

Les quatre jets partaient des rendus du bureau — **fond noir, sachet noir**.
Détourer du noir sur du noir est mal posé par nature. J'ai essayé un seuil de
luminance (impossible, mesuré : intérieur du sachet à 12, halo à 14 sur la
même ligne), puis les pics de gradient ligne par ligne, puis trois garde-fous
successifs. **Chaque tour améliorait une mesure — le bord est tombé de 23 px à
2 px — et le résultat restait faux**, parce que le remplissage se fait par
SPAN horizontal : chaque ligne pleine d'un bord à l'autre. Un RECTANGLE.

⚠️⚠️ **ET C'EST LA VRAIE LEÇON : SUR DU NOIR, UN DÉTOURAGE FAUX EST
INVISIBLE.** Quatre versions fausses sont passées parce que je les jugeais sur
la page, qui est noire. Sur un damier, la vérité saute aux yeux en une
seconde. **Toute vignette à alpha se juge désormais sur damier**, et le bake
produit sa planche de verdict sur damier, plus jamais sur du noir.

L'alpha existait, dans le catalogue, à côté :

| asset | taille | ce qu'il contient |
|---|---|---|
| `booster-orange.imageset` | 1054 × 1408 | vrai détourage + la lueur en dégradé + **le reflet au sol** |
| `sticker-booster.imageset` | 794 × 1278 | vrai détourage, 94,8 % d'alpha plein, bord de 2 px |

Le bake ne dérive donc plus RIEN. Toute la machinerie (seuils, gradients,
enveloppe du cran, prolongement du pied, garde-fous, médiane des trente
dernières lignes) est SUPPRIMÉE. Il ne reste que deux gestes :

1. **On durcit** — la lueur des assets part (0,55 → 0 · 1,00 → 1, ce qui jette
   le halo mais garde le pixel d'antialiasing, donc le bord reste lisse). La
   loi du §18.5 tient : la lueur appartient à la scène.
2. **On coupe le reflet de l'orange** — mesuré, son alpha contient le sachet
   ET son reflet au sol, séparés par un trou net à **y = 1310** (la largeur
   opaque y tombe de 857 px à 22).

Puis les deux sont ramenés à la MÊME LARGEUR DE CORPS (196 px) et **alignés
sur leur PIED, pas sur leur centre** — ils posent sur le même socle, c'est
leur bas qui doit coïncider. Les deux canevas font 252 × 435, soit exactement
84/145 : le `scaledToFit` de `SachetVignette` ne rogne rien.

| | opaque | mi-transparent | bord |
|---|---|---|---|
| `booster-pill` | 60,4 % | **4,2 %** | 3 px |
| `booster-pill-noir` | 58,2 % | **0,8 %** | 2 px |

Et surtout : **le pied du sachet est maintenant son vrai cran**, plus une
coupe inventée sur 111 lignes. Le ré-export n'est plus nécessaire.

---

## 19. v11 — PLAN : L'EN-TÊTE SUR UNE SEULE LIGNE, ET LA PAGE HISTORIQUE

Verdict du 28-08 : *« mets Rewards au niveau de la ligne du chevron, et la
pill historique est pas alignée / pour la partie Historique le texte est trop
décalé, il doit être plus sur la droite, même taille que le titre Rewards,
dégradé blanc Apple like, et apparition Apple like blur, et la liste en
dessous avec blur / et pour fermer je drag vers le bas, ça ferme la page »*

### 19.1 L'EN-TÊTE — la pill est bien désalignée, de 7 pt

Mesuré sur la capture (écran de 874 pt) :

| | haut | bas | **centre** | taille |
|---|---|---|---|---|
| chevron (`ChipVerre`) | 63 | 107 | **85** | 44 × 44 |
| pill historique | 59 | 97 | **78** | 38 × 38 |
| « Rewards » | 130 | 152 | 141 | — |

**Sept points d'écart, et deux tailles différentes** — c'est exactement ce
qu'elle voit. La pill est posée par `.position(y: 78)`, une cote écrite à la
main qui ne connaît pas le chevron.

⚠️ **LE CHEVRON NE BOUGE PAS, C'EST LES AUTRES QUI S'ALIGNENT.** Loi déjà
écrite dans ce fichier : *« la position du chevron ne bouge JAMAIS d'une page
à l'autre »* (`RangeeChips`). Donc : le chevron reste à `top 63`, la pill
passe à **44 × 44 centrée sur 85**, et « Rewards » entre dans la MÊME rangée.

Le titre rejoint donc le chevron dans un `HStack` — plus de `VStack` avec un
titre en dessous. Place disponible, vérifiée : chevron de 22 à 66, titre de 30
pt ≈ 130 pt de large, la pill commence à 343 — il reste 147 pt de marge.

⚠️ Et ça libère encore le mur : le titre ne descend plus à 152 mais s'arrête à
107. Le néon (197) gagne 45 pt d'air de plus. À garder en réserve, ne pas le
dépenser dans le même tour.

### 19.2 LA PAGE HISTORIQUE — le titre

`inter(30, .bold)`, tracking −0,4 : la cote de « Rewards » et du titre
Calendrier. Et cette fois **le VRAI `WoopGradient.titleFade`**, le blanc
(1,00 → 0,25 en diagonale) — la page des gains est noire, c'est le sens pour
lequel il a été fait. (Sur le coffre il fallait son miroir noir parce que le
mur est éclairé ; ici, pas de miroir.)

**« Il doit être plus sur la droite » — deux lectures, et je tranche.**
Le titre est aujourd'hui à 26 pt du bord, les vignettes des lignes aussi, et
le TEXTE des lignes à 26 + 40 + 14 = **80**. La page a donc deux marges
gauches qui se contredisent. La lecture qui fait une RÈGLE plutôt qu'un
décalage : **le titre s'aligne sur la colonne de texte des lignes (80)**, et
seules les vignettes débordent à gauche. La page gagne un seul axe vertical
fort — titre, intitulés, dates — et les objets pendent à sa gauche.
⚠️ À confirmer d'un coup d'œil : c'est le point le plus interprétatif du lot.

### 19.3 L'APPARITION — la cascade, pas une transition

« Apple like blur » : c'est exactement le vocabulaire que la maison a déjà,
dans `CoffreV2.titre` et dans la home — **flou 9 → 0, décalage 9 → 0, opacité
0 → 1**, en cascade avec un retard par élément (`retard 0,14`, `durée 0,90`).

- le titre part le premier ;
- **chaque ligne de la liste suit, décalée de 0,05 s** — c'est ce qui fait
  « la liste en dessous avec blur » : ce n'est pas un flou permanent posé sur
  la liste, c'est son ARRIVÉE. Un flou permanent rendrait les dates
  illisibles.
- au-delà de ~8 lignes, la cascade se plafonne : sinon la dernière arrive une
  seconde et demie après la première et la page a l'air lente.

⚠️ **PAS DE `.blur` PERMANENT SUR UNE LISTE QUI DÉFILE** : `.blur` force une
passe hors écran, et sur un `ScrollView` c'est une passe PAR IMAGE de défilement.
Le flou ne vit que pendant l'arrivée, puis il vaut exactement 0 (`p > 0,995 →
radius 0`, comme `titre` le fait déjà).

En complément, et c'est le vrai « Apple like » d'une liste : un **bandeau de
verre en haut** qui la fait disparaître sous le titre. ⚠️ `glassEffect(.clear)`
et pas `.regular` (le givré est interdit), et il n'est légitime ici que parce
que ce qui passe dessous est du contenu DOUX en mouvement — pas du texte net
immobile.

### 19.4 FERMER AU DOIGT — et ⚠️ un bug qui existe DÉJÀ

**Trouvé en préparant ce point, et il est indépendant du geste demandé :
`gestePage` n'a AUCUNE garde sur `gainsOuverts`.** Le geste de la page est
posé sur un ancêtre plein écran ; aujourd'hui, un doigt promené sur la page
des gains **fait tourner le manège derrière l'overlay opaque**. Personne ne
l'a vu parce que rien ne le montre — mais le compte des pièces et la page
courante changent dans le dos de l'utilisateur.

Le geste de fermeture se pose donc en cinq points, tous des lois déjà payées
dans cette maison :

1. ⚠️ **LA PAGE PREND LE DOIGT AVANT L'ANCÊTRE.** Un geste d'enfant sous un
   `DragGesture` d'ancêtre plein écran se fait AFFAMER dès que l'ancêtre
   reconnaît (loi payée sur le stop du player, et sur le bouton « Ouvrir » de
   ce fichier). Donc `highPriorityGesture` — **et** une garde
   `guard !gainsOuverts` dans `gestePage`, qui règle le bug ci-dessus. Les
   deux, pas l'une des deux : la garde protège le manège, la priorité fait
   marcher le geste.
2. ⚠️ **IL NE S'ARME QU'EN HAUT DE LISTE.** Sinon un défilement vers le bas
   ferme la page au lieu de remonter. Il faut donc lire l'offset du
   `ScrollView` — `onScrollGeometryChange`, ⚠️ avec la sonde du §piège :
   **une sonde constante ne rappelle JAMAIS**, il en faut une par scroll et
   elle doit renvoyer une valeur qui CHANGE.
3. **La page suit le doigt** (translation + un rien d'opacité), se ferme
   au-delà de ~120 pt ou à la vitesse, et revient au ressort sinon. Une page
   qui ne suit pas le doigt pendant qu'on la tire n'est pas une page qu'on
   tire.
4. ⚠️ **UN DRAG PEUT MOURIR SANS `onEnded`** (doigt volé au bord, appel
   entrant) : remise à plat depuis `startLocation` **et** chien de garde qui
   COMMET la sortie si le seuil était franchi. C'est exactement la panne du
   chemin Duolingo — sans ça, on récupère une page à moitié tirée et jamais
   fermée.
5. ⚠️ **FERMÉE, ELLE NE PREND PLUS RIEN.** `allowsHitTesting(false)` dès
   qu'elle quitte sa place : *déplacer des pixels ne déplace pas la zone
   tactile* — la page invisible mangerait tous les touchers du coffre. C'est
   le gel app-wide de `CheminHote`, mot pour mot.

Le bouton `xmark` reste : un geste ne s'annonce pas, il faut toujours une
porte visible.

### 19.5 L'ORDRE

1. L'en-tête sur une ligne (chevron · Rewards · pill à 44, centres à 85).
2. La garde `gainsOuverts` dans `gestePage` — **c'est un bug, il passe avant
   le reste**.
3. Le titre de l'historique : taille, dégradé blanc, colonne de texte.
4. La cascade d'arrivée (titre puis lignes), et le bandeau de verre.
5. Le drag pour fermer, avec ses cinq points.

### 19.6 CODÉ (v11)

**Le bug d'abord.** `gestePage` porte maintenant `guard !gainsOuverts`. Il
n'existait aucune garde : un doigt promené sur la page des gains faisait
tourner le manège derrière l'overlay opaque, et la page courante changeait
dans le dos du user. Invisible, donc jamais signalé.

**L'en-tête.** Le titre a quitté son `VStack` pour rejoindre le chevron dans
un `HStack(alignment: .center)`. ⚠️ **L'alignement n'est plus une cote, il est
STRUCTUREL** — deux vues centrées dans la même rangée ne peuvent pas dériver,
là où `.position(y: 78)` écrite à la main ne connaissait pas le chevron. La
pill des gains passe de 38 à `Self.chip` (44) et sa position est DÉRIVÉE
(`63 + chip/2`). Mesuré après : pill à **84,8 pt pour 43,7 de haut**, contre
78 / 38 avant. La croix de la page des gains prend la même règle : **84,8 /
43,7**. Trois ronds, une seule règle.

**Le titre de l'historique.** `inter(30, .bold)`, tracking −0,4, et le VRAI
`WoopGradient.titleFade` — le blanc. Mesuré en travers du mot : **238 → 119**
de luminance, il s'éteint. Et il s'aligne sur la **colonne de texte des
lignes** (26 + 40 + 14 = 80 ; mesuré à 82 avec l'approche de la glyphe), pas
sur le bord de la page : l'écran avait deux marges gauches qui se
contredisaient, il n'en a plus qu'une, et seules les vignettes pendent à sa
gauche.

**L'arrivée.** `ArriveeFloue` sort en `ViewModifier` : flou 9 → 0, décalage
9 → 0, opacité 0 → 1, retard de 0,055 s par rang. Le titre au rang 0, chaque
ligne ensuite. ⚠️ **Cascade PLAFONNÉE à huit rangs** — sinon la vingtième
ligne arrive une seconde et demie après la première. ⚠️ **Et le rayon retombe
à ZÉRO exact** (`q > 0,995`) : un `.blur` même minuscule force une passe hors
écran par image, et sur un `ScrollView` c'est par image de DÉFILEMENT. Le flou
est une arrivée, jamais un état.

**Le geste.** `highPriorityGesture` sur la page (le geste du coffre est sur un
ancêtre plein écran, un enfant s'y fait affamer) · armé seulement `enHaut`,
lu par une sonde qui renvoie l'OFFSET — une sonde constante ne rappelle jamais
· la page suit le doigt, résistance ×0,18 vers le haut où elle n'a nulle part
où aller · seuil 120 pt **ou** vitesse (`predictedEndTranslation > 260`) ·
⚠️ **chien de garde à 450 ms qui COMMET la sortie** si le seuil était franchi,
parce qu'un drag peut mourir sans `onEnded` et qu'une page à moitié tirée et
jamais fermée, c'est le gel app-wide du chemin Duolingo · et le tap de la
croix en `highPriorityGesture` lui aussi, pour ne pas parier sur l'arbitrage
de SwiftUI.

**Reste à juger au doigt** (le simulateur ne peut pas) : le seuil de 120 pt,
la résistance vers le haut, et que le défilement de la liste ne ferme jamais
la page par accident.

---

## 20. v12 — PLAN : LE FOND PASSE AU NOIR, LE MUR ÉCLAIRÉ MEURT

Verdict du 28-08 : *« enlève la vidéo blanche avec néon, on passe en mode
sombre noir : un rendu spotlight qui se reflète sur le podium comme cette
image. Le reste du flow ne bouge pas, je veux juste le background. Il faudra
plus de noir sur les côtés. Je pense que pour les effets de scroll, c'est bien
que le podium soit une image à part de la vidéo du spotlight. »*

Assets : `~/Desktop/spotlight .png` (852 × 1846, **le faisceau SEUL**) ·
`~/Desktop/background_podium.png` (la référence complète) ·
`~/Downloads/video_crop.mp4` (2160 × 3840, HEVC 10 bits, 8 s, 24 i/s).

### 20.1 Le podium reste une image à part — et c'est une CONTRAINTE, pas un goût

Son intuition est juste, et plus forte qu'elle ne le dit. Tout est accroché à
`podCentre` / `yHaut` / `yBas` : la pose des objets, la lévitation, la MARCHE
entre le dessus du socle et le sol des voisins, l'atterrissage, la gerbe — et
depuis le §18, **les flaques masquées par la LUMINANCE de l'image du socle**.
Un socle cuit dans une vidéo devrait être suivi image par image pour que tout
ça reste vrai.

### 20.2 La vidéo ne peut PAS être recadrée telle quelle — mesuré

Largeur du socle, image par image :

| t | 0 s | 2 s | 4 s | 6 s | 7,9 s |
|---|---|---|---|---|---|
| largeur / W | 0,690 | 0,720 | 0,757 | 0,794 | **0,836** |

**+21 % de façon monotone, et ça ne revient jamais.** Conséquences :

1. ⚠️ **ELLE NE BOUCLE PAS.** Un `AVPlayerLooper` ferait SAUTER le décor de
   21 % toutes les 8 secondes. C'est une coupe franche, pas un raccord.
2. ⚠️ **Même recadrée au faisceau seul, le problème reste** : le cône
   s'élargit avec le travelling, donc il respire puis SAUTE.
3. ⚠️ **Elle est en 9:16 (0,5625) quand l'iPhone est en 0,4600** — il faudrait
   rogner **18 % de la largeur**, c'est-à-dire précisément les bords sombres
   qu'elle veut garder pour le fondu.

Deux remèdes existent — un **ping-pong** (aller + retour = 16 s qui bouclent
sans raccord, et le travelling devient une respiration au lieu d'un saut), ou
un contre-zoom qui stabilise. Le ping-pong est le bon : il SE SERT du mouvement
au lieu de le combattre.

### 20.3 Mais `spotlight .png` est déjà meilleur que tout ça

Le faisceau seul, sans podium, sur noir, **et déjà au bon format** (0,4615
contre 0,4600 pour l'écran — rien à rogner). Pour un fond qui doit rester
IMMOBILE derrière une scène qui se feuillette, une image bat une vidéo sur
tous les tableaux :

- **zéro décodage par image** — la vidéo actuelle est une couche `AVPlayer`
  plein écran, et la maison a déjà mesuré ce que coûte une couche plein écran ;
- **aucun raccord de boucle**, donc aucun saut ;
- **pas d'image de pose à entretenir** — `SalleFond` ne porte `salle-poster`
  que parce que le décodeur du simulateur rate des images et peint du NOIR ;
- elle se masque, se teinte et se décale librement.

Le seul avantage de la vidéo, c'est **la poussière qui dérive**. Il est réel.
Mais cette page a déjà de la lumière qui bouge : les flaques, la poudre au
changement de page, la lévitation, le lustre de la jauge. Une boucle de
particules permanente coûte de la cadence pour quelque chose que l'œil cesse
de voir en trois secondes.

> **Recommandation : le PNG.** Et si la poussière manque, on l'anime nous-mêmes
> ensuite — mais en la MESURANT avant de la garder.

### 20.4 ⚠️ CE QUE LE PASSAGE AU NOIR CASSE — à savoir AVANT

1. ⚠️⚠️ **LE TITRE DISPARAÎT.** « Rewards » est un dégradé **noir**
   (`encreFade`) précisément parce qu'il vit sur le mur ÉCLAIRÉ. Sur du noir,
   il n'existe plus. Il repasse au vrai `WoopGradient.titleFade`, le blanc —
   une ligne, mais dans le même souffle.
2. ⚠️⚠️ **LA BARRE NÉON EST L'ANCRE DE TOUTE LA SCÈNE.** `ySalle` fait
   GLISSER le décor pour que le néon tombe sur `barreY` ; et surtout
   `Projecteur` **et** `Atterrissage` partent de `scene.barre.midY`. Plus de
   néon → cette ancre doit être remplacée. La nouvelle ancre naturelle est le
   HAUT DE L'ÉCRAN (la source du spot), ce qui est plus simple qu'aujourd'hui.
3. ⚠️ **DEUX FAISCEAUX.** `Projecteur` dessine DÉJÀ un faisceau qui descend
   sur l'objet présenté. Un faisceau photographique derrière lui en ferait
   deux. Il faut trancher : je garderais `Projecteur` pour ce qu'il sait faire
   et que l'image ne saura jamais — il SUIT l'objet, il force au tap — et je
   laisserais le fond ne porter que l'ambiance et le sol.
4. ⚠️ **`SalleFond.clarte`** éteint le décor quand on ouvre un objet (le
   théâtre). Sur un décor déjà presque noir, il n'y a plus rien à éteindre :
   cet effet devra passer sur les flaques.
5. ⚠️ **LE VERRE.** Le chevron et la pill sont en `glassEffect(.clear)`. Sur
   un mur clair ils se lisent ; sur du quasi-noir ils peuvent s'évanouir. **À
   mesurer, pas à supposer** — et `.regular` reste interdit.

### 20.5 Le fondu des bords

Sa demande (« plus de noir sur les côtés »). Le PNG y arrive presque seul : il
est déjà sur fond noir et au bon rapport. Il suffit d'un masque radial doux
qui éteint les bords et le bas, posé sur l'image — **pas un `.blur`**, qui
poserait un voile uniforme sur tout le rectangle de l'hôte.

### 20.6 Ce qui reste à trancher

1. **La poussière** : PNG immobile (recommandé), ou vidéo en ping-pong ?
   ⚠️ Si vidéo : elle devra être **régénérée sans podium**, ou stabilisée —
   celle d'aujourd'hui coûte 18 % de largeur au recadrage.
2. **Le faisceau** : celui de l'image, celui du `Projecteur`, ou les deux avec
   des rôles séparés ?

### 20.7 « Je n'arrive pas à régénérer la vidéo » — on n'en a pas besoin

⚠️ **ET JE CORRIGE UNE DE MES AFFIRMATIONS DU §20.2.** J'avais écrit que le
recadrage au format iPhone coûterait « précisément les bords sombres qu'elle
veut garder ». **C'est faux, mesuré.** Un `aspectFill` garde x 0,090 → 0,910 ;
le faisceau vit entre 0,13 et 0,78 selon la hauteur. Il tient. Une seule ligne
déborde à 0,926 à t = 7,9 s, et c'est une braise isolée, pas le cône.

Trois routes, aucune ne demande de régénérer quoi que ce soit :

**① LE PNG SEUL — disponible tout de suite, coût nul.**
`spotlight .png` est déjà le bon asset, au bon format. Pas d'animation. C'est
ce que je recommande pour voir la page en noir DÈS CE SOIR, quitte à ajouter
du mouvement après.

**② SA VIDÉO, RECADRÉE ET MISE EN PING-PONG — ffmpeg seul.**
- couper le bas au-dessus du socle (il commence à **0,78 H**) → plus de podium,
  et la contradiction du §20.1 disparaît ;
- `aspectFill` pour le format : 18 % de largeur perdus, **et le faisceau
  tient** (mesuré ci-dessus) ;
- **ping-pong** (aller + retour) : la boucle devient sans raccord, et le
  travelling de +21 % devient une RESPIRATION au lieu d'un saut.
⚠️ Coût à mesurer : une couche `AVPlayer` plein écran. `./tools/charge.sh`
d'abord — la charge machine invalide toute mesure de cadence.

**③ FABRIQUER LA BOUCLE DEPUIS LE PNG — ffmpeg aussi, et c'est le plus propre.**
Son image fixe + une poussière qui dérive, composée en ffmpeg sur une
trajectoire **sinusoïdale de période égale à la durée** : la boucle est alors
sans raccord PAR CONSTRUCTION, pas par chance. On garde son image exacte, au
bon format, sans podium, et le fichier pèse ce qu'on veut.

**Ordre proposé : ① tout de suite, puis ③ si le fond paraît trop mort.** ②
n'est utile que si la poussière de SON rendu est irremplaçable — c'est le seul
truc que ③ ne copiera pas à l'identique.

### 20.8 CODÉ — la salle éclairée est morte

**Route ① prise.** `bake_spot.py` cuit `spotlight .png` en `coffre-spot.png`
(1206 × 2622, ×1,42), avec un fondu des bords et du bas **en cosinus et pas
linéaire** : une rampe droite laisse une ARÊTE là où elle commence (la dérivée
saute), et sur un fond aussi sombre l'œil la voit tout de suite.

`SalleFond` n'est plus qu'une `Image` posée plein cadre. Ce qui disparaît avec
elle : la couche `AVPlayer` plein écran, `salle-poster` (qui n'existait que
parce que le décodeur du simulateur rate des images et peint du noir), et
**`SalleVideo` — 59 lignes de code mort supprimées**. ⚠️ `BoosterLoopLayerView`
est GARDÉ : cinq autres vues s'en servent.

**Les cotes du néon sont mortes avec le film.** `barreSalle = 0,5071` était une
cote MESURÉE DANS UN FICHIER, au pic de gradient — on ne recalera plus jamais
une mise en page sur un pixel de vidéo. `barre` devient `sourceY = 0,012` : la
lumière descend du haut de l'écran, et `Projecteur`/`Atterrissage` gardent leur
ancre.

**Les cinq conséquences, traitées — et deux se sont vues à la mesure :**

1. **Le titre** repasse au vrai `titleFade` blanc. `encreFade` et `encreMur`
   supprimés : ils n'avaient de sens que sur un mur éclairé.
2. ⚠️ **LES DEUX FAISCEAUX S'ADDITIONNAIENT.** Mesuré sur la bande centrale,
   l'excès de vert sur le bleu :

   | y/H | avant | après | sa référence |
   |---|---|---|---|
   | 0,06 | **+19** | +8 | +8 |
   | 0,12 | **+20** | +7 | +7 |
   | 0,20 | **+18** | +7 | +7 |

   La crème du `Projecteur` (V 0,80 · B 0,55) s'ajoutait en `plusLighter` et
   virait le faisceau au KAKI. Il tombe à 0,34 au repos et garde toute sa
   réponse au geste — il fait deux choses que l'image ne saura jamais faire :
   il SUIT l'objet, et il FORCE au tap.
3. ⚠️ **LE VERRE DU CHEVRON ÉTAIT UNE DALLE GRISE.** Mesuré : **65 de
   luminance contre 18 pour la pill**. `ChipVerre` portait déjà la loi —
   `clarte` 0 = la nuit, 1 = une lumière — et le coffre lui disait encore
   « lumière ». Passé à 0 : **11 contre 18**, ils sont enfin de la même
   famille.
4. **`clarte`** garde son rôle : elle éteint le spot à l'ouverture d'un objet.
5. **Le fondu des bords** est dans le bake, pas au runtime.

⚠️ **PIÈGE DE BANC, ET IL M'A COÛTÉ DEUX CAPTURES FAUSSES** : le simulateur
booté n'était plus le mien. J'ai capturé une build périmée sur l'un, puis le
BANC DES NOTIFICATIONS de l'autre session sur l'autre. **Vérifier sur quel
appareil on installe ET on lance** — `simctl list devices booted` ment moins
que l'habitude.

**Reste** : la poussière ne bouge plus (route ③ si le fond paraît mort), et
tous les verdicts au doigt.

---

## 21. v13 — PLAN : LE BON SPOTLIGHT, C'EST LA VIDÉO

Verdict du 29-08 : *« mais t'as pas utilisé la vidéo, t'as mis un vieux
spotlight »*.

### 21.1 ⚠️ MON ERREUR, ET ELLE EST NETTE

J'ai comparé le PNG à sa référence **sur la TEINTE** (V−B : +9 contre +8) et
j'en ai conclu que c'était le même rendu. **Je n'ai jamais comparé le
CONTENU.** Mesuré maintenant, au même cadrage et à la même échelle :

| | pixels de braise | luminance moyenne |
|---|---|---|
| `spotlight .png` (20 h 08) | **514** | 8,5 |
| `video_crop.mp4` (21 h 12) | **3 738** | 20,3 |

**7× plus de braises, 2,4× la luminance.** Et l'horodatage le dit aussi : la
vidéo est POSTÉRIEURE aux deux PNG. Le PNG est un rendu antérieur, plus pâle,
presque sans étincelles — son faisceau est une colonne douce là où celui de la
vidéo est un cône avec de la matière dedans.

**Deux mesures qui concordent sur une couleur ne disent rien du dessin.**

### 21.2 Le cadrage — et je corrige une deuxième cote

⚠️ **J'avais dit que le socle commençait à 0,78 H. C'est faux** : 0,78 était
son LISERÉ éclairé. Le haut réel du socle est à **0,855 → 0,875 H** selon
l'instant (il monte en grossissant). On coupe donc à **0,845 H** — et on garde
7 points de hauteur de plus que ce que j'annonçais, donc moins à rogner sur les
côtés.

**Le corps du faisceau survit au recadrage, mesuré aux deux bouts du clip :**

| | t = 0 | t = 7,9 s |
|---|---|---|
| y = 0,10 | 0,356 → 0,606 | 0,282 → 0,674 |
| y = 0,30 | 0,319 → 0,620 | 0,255 → 0,655 |
| y = 0,70 | 0,301 → 0,627 | 0,218 → 0,748 |

Tout tient dans 0,157 → 0,843. Ce qui débordait dans ma mesure précédente,
c'étaient des **braises isolées** au seuil 14 — invisibles si on les perd.

**Deux façons de le poser, et je recommande la seconde :**

- **`aspectFill`** — on rogne ~31 % de la largeur. Le faisceau tient, mais on
  jette de la matière pour rien.
- **AJUSTÉ À LA LARGEUR** — rien n'est rogné. La vidéo couvre alors le haut
  jusqu'à ~0,69 H, et le bas reste noir : c'est exactement là que vivent notre
  socle (0,556 H) et son sol. Il faut juste **éteindre son bord bas en fondu**,
  sinon la fin de l'image fait une arête horizontale.

### 21.3 La boucle — le ping-pong n'est pas un pis-aller

Rappel mesuré : le socle passe de 0,690 à 0,836 de la largeur, **de façon
monotone**. La vidéo ne boucle pas ; un `AVPlayerLooper` la ferait sauter de
21 % toutes les 8 secondes.

**Aller + retour = 16 s sans raccord**, et le travelling devient une
RESPIRATION. Ce n'est pas contourner le défaut, c'est lire le matériau pour ce
qu'il est : un spot qui s'approche et s'éloigne, c'est ce qu'on aurait demandé
si on avait su le demander.

### 21.4 ⚠️ CE QUE ÇA REND, ET QU'ON VENAIT DE GAGNER

On remet exactement ce qu'on a retiré hier, et il faut le savoir :

1. **Une couche `AVPlayer` plein écran.** C'est le coût qu'on venait
   d'économiser. ⚠️ **À MESURER, pas à supposer** — et `./tools/charge.sh`
   d'abord, la charge machine invalide toute cadence.
2. **L'image de pose revient**, obligatoire : le décodeur du simulateur est
   LOGICIEL, il rate des images, et sans poster dessous le raté DEVIENT un
   glitch noir plein écran. (C'est pour ça que `salle-poster` existait.)
3. **`SalleVideo` revient**, mais plus simple : plus de glissement, plus de
   calage sur un pixel (`barreSalle` reste mort et enterré).
4. **Le ré-encodage** : 2160 × 3840 HEVC 10 bits pour un écran qui en demande
   1206 de large, c'est décoder quatre fois trop de pixels par image. On recuit
   à la taille d'affichage — et sur une image presque noire, le fichier tombe.

### 21.5 LES DEUX ROUTES

**①bis — UNE IMAGE FIXE, MAIS TIRÉE DE LA VIDÉO.**
Corrige exactement son reproche (« un vieux spotlight ») **à coût nul** : on
garde l'architecture d'hier, on change juste la source du bake. Disponible
tout de suite. Ce qu'on n'a pas : les braises qui dérivent.

**② — LA VIDÉO, recadrée + ping-pong.**
Le rendu qu'elle veut, en mouvement. Coût : une couche vidéo plein écran, un
poster, et une mesure de cadence.

> **Ma recommandation : ①bis d'abord, ce soir, et ② dans la foulée si la
> poussière manque.** Parce que ①bis règle le vrai grief (le mauvais rendu) et
> que ② n'ajoute que le mouvement — deux questions séparées, qu'on avait
> mélangées.

### 21.6 Ce que ça ne change PAS

Les cinq corrections du §20.8 tiennent quelle que soit la route : le titre en
blanc, le `Projecteur` à 0,34 (les deux faisceaux s'additionnaient), le
chevron en `clarte: 0`, le fondu des bords, l'ancre au haut de l'écran. Elles
ne dépendent pas de la source, seulement du fait que le fond est noir.

### 21.7 CODÉ — la vidéo est en place

`bake_spot.py` part maintenant de `video_crop.mp4` et rend **deux** fichiers :
`coffre-spot-loop.mp4` et son image de pose `coffre-spot.png`.

| | |
|---|---|
| sortie | 1206 × 1608, H.264 High, yuv420p |
| durée | 16,08 s (ping-pong), 386 images |
| débit | 1,18 Mb/s · **2,4 Mo** |
| raccord de boucle | écart moyen **0,61 / 255** — contre 5,65 entre deux images éloignées |

⚠️⚠️ **LA COUPE S'EST FAITE EN DEUX TEMPS, ET LA PREMIÈRE ÉTAIT FAUSSE.**
J'ai d'abord cherché le socle par sa LUMIÈRE (« une large bande claire ») et
trouvé 0,855 → 0,875 H. Coupé à 0,845, **un fantôme d'ellipse restait visible
à l'écran**, sous notre propre socle : le verre sombre du socle commence bien
plus haut que sa partie éclairée.

Cherché par son **ARÊTE** (un saut vertical de luminance sur plus de 30 % de
la largeur), il apparaît à 0,832 H au début et **remonte à 0,775 H à la fin du
travelling** — c'est ce minimum-là qui commande. Coupé à 0,75, le fantôme a
disparu.

> **Chercher un objet par sa lumière trouve sa partie éclairée, pas l'objet.**

⚠️ Et la cote du fichier a changé avec la coupe (1810 → 1608) : `SalleFond
.ratio` doit bouger AVEC elle, sinon la vue étire la vidéo sans rien dire.

`SpotVideo` remplace `SalleVideo` : même école (`AVPlayerLooper`, jamais un
seek), mais sans glissement ni calage sur un pixel. Ajustée à la largeur,
posée en haut, bord bas éteint **dans le fichier** — un `.mask` sur une couche
vidéo forcerait une passe hors écran à chaque image.

**RESTE, ET C'EST LA SEULE CHOSE QUI MANQUE :** la cadence n'est pas mesurée.
On vient de remettre une couche `AVPlayer` plein écran, exactement ce qu'on
avait économisé. ⚠️ `./tools/charge.sh` AVANT toute mesure — la charge machine
invalide les cadences, et c'est déjà payé.

---

## 22. PLUS DE ROUGE DANS LE HALO ? — mesuré (29-08)

Question de Kathryn : *« tu peux rajouter plus de rouge au niveau du halo
orange, ou c'est chaud pour ne pas être différent de notre univers ? »*

### 22.1 Ce n'est pas chaud du tout — l'univers va déjà bien plus loin

Teinte de la palette chaude de la maison (0° = rouge pur, 36° = or) :

| | R V B | teinte | saturation |
|---|---|---|---|
| rouge profond (`StorySuite`) | 255 · 51 · 13 | **9,4°** | 1,00 |
| braise sombre | 255 · 46 · 8 | **9,2°** | 1,00 |
| liseré de la fiche exo | 255 · 107 · 33 | 20,0° | 1,00 |
| **braise du booster** (`.lune`) | 255 · 125 · 43 | **23,2°** | 1,00 |
| braise de la maison | 255 · 143 · 51 | 27,1° | 1,00 |
| or du coffre (`.or`) | 255 · 189 · 87 | 36,4° | 1,00 |

**Notre halo est à 23,1°, au MILIEU de la bande.** La maison utilise déjà du
9° — il reste **14 degrés de marge** avant d'atteindre son propre rouge le
plus profond. Et sa référence à elle est à **19,2°**, donc plus rouge que ce
qu'on affiche : aller vers le rouge, c'est aller vers sa maquette.

Trois crans possibles, tous à saturation pleine :

| | R V B | teinte |
|---|---|---|
| un cran | 1,00 · 0,42 · 0,14 | 19,5° ← sa référence |
| deux crans | 1,00 · 0,36 · 0,12 | 16,4° |
| trois crans | 1,00 · 0,30 · 0,10 | 13,3° |

### 22.2 ⚠️ LE DANGER N'EST PAS LA TEINTE, C'EST LA SATURATION

**Rouge + saturation qui baisse = BRUN.** C'est la loi anti-brun, payée
partout dans ce dépôt (`FlammeJauge` : « sur toute la rampe orange, la
saturation ne se perd JAMAIS en descendant »).

    (1,00 · 0,36 · 0,12)  → 16,4°  sat 1,00   ✓
    (0,72 · 0,34 · 0,22)  → 14,4°  sat 0,53   ✗ brun

Donc : **R reste à 1,00, on ne descend QUE le vert et le bleu.** C'est
exactement la recette de l'harmonisation rouge de la page exo.

### 22.3 ⚠️ MAIS OÙ ? — et là il y a un vrai piège

Deux endroits possibles, et ils n'ont pas du tout le même effet :

**① LA FLAQUE de la page booster orange** (`ObjetSocle.lueur` pour `.lune`).
N'affecte QUE cette page. Sans risque. C'est ce que je recommande.

**② LE FAISCEAU DU FOND** (une étalonnage dans le bake).
⚠️ **Le fond est le MÊME pour les quatre pages.** Le rougir le rougit aussi
sous la pièce d'ARGENT (identité froide, bleu) et sous le booster NOIR
(violet). On se battrait contre les deux identités qu'on vient d'installer au
§18 — et la mesure du §18 disait justement que c'est la flaque qui porte
l'identité, pas le décor.

> **Si le fond doit changer, c'est dans l'autre sens : le DÉSATURER vers le
> neutre**, pour que chaque flaque puisse le colorer. C'est le principe du
> §18 poussé au bout — la lumière appartient à l'objet.

### 22.4 Ce que je propose

1. **La flaque `.lune` passe à 19,5°** (1,00 · 0,42 · 0,14) — la teinte exacte
   de sa référence, saturation pleine.
2. **On regarde**, et on descend d'un cran de plus si elle en veut (16,4°).
3. **On ne touche pas au fond** tant que les quatre pages n'ont pas été jugées
   côte à côte.

⚠️ Et une chose à vérifier en même temps : le halo mesuré à l'écran est à
**saturation 0,55** contre **0,67** pour sa référence. Il est donc déjà un peu
LAVÉ — possible que ce qu'elle lit comme « pas assez rouge » soit en partie un
manque de saturation, pas de teinte. Les deux se règlent, mais ce n'est pas le
même réglage.

### 21.8 « ELLE RESPIRE TROP » — mesuré et calmé (29-08)

⚠️ **D'ABORD, LA MESURE ÉTAIT MAUVAISE.** J'ai voulu quantifier la respiration
par la LARGEUR du faisceau : elle donnait 81 → 80 → 89 → 100 → 107, une suite
non monotone qui tremblait de ±8 % sans que rien ne bouge — les braises
traversent le seuil et faussent tout. La bonne mesure est **l'AIRE ÉCLAIRÉE**,
qui varie comme le carré du zoom et ne tremble pas.

| | amplitude | vitesse |
|---|---|---|
| avant (toute la source, demi-période 8 s) | **+26,5 %** | 3,32 %/s |
| après (0 → 3 s, ralenti ×2, demi-période 6 s) | **+10,0 %** | **1,67 %/s** |

**Amplitude ÷2,6, vitesse ÷2,0.** Le fichier tombe à 1,4 Mo, 144 images.

Deux réglages nommés, qui ne font pas la même chose :
`FIN` coupe l'AMPLITUDE (on ne garde que le début du travelling) ·
`LENT` étale la VITESSE.

⚠️ **RALENTIR N'AJOUTE PAS DE SACCADE, ET C'EST CONTRE-INTUITIF.** Le
déplacement PAR IMAGE SOURCE ne dépend que de `FIN` — c'est la même image
suivante, montrée plus tard (0,14 % dans les deux cas). `LENT` ne change que
la FRÉQUENCE des mises à jour : le pas ne grandit pas, il revient moins
souvent.

⚠️ `trim` + `setpts` **dans le graphe**, jamais `-ss` : `-ss` positionne la
lecture sans couper le graphe, et `reverse` embarquerait les images d'avant.
Piège déjà payé dans cette maison.

**Ce que je n'ai pas pu mesurer** : la saccade elle-même. On est passé de 24 à
12 mises à jour par seconde ; les chiffres disent que le pas ne grossit pas,
mais seul l'œil dira si les braises stroboscopent.

### 22.5 LA POUDRE DU PASSAGE — le régime diamant de la maison (29-08)

Verdict : *« les petites particules sont trop grosses, prends la petite
poussière de diamant présente sur les pop-up de l'app »*.

Elle avait raison, **et la maison avait déjà payé exactement cette leçon.**
`PoudreGrattage` (la card à gratter du chemin) porte ce commentaire :
*« 0,30 → 0,95 pt : le grain le plus gros reste SOUS le point. Avant, le plus
petit faisait déjà 1,2. »* Mes grains faisaient **0,8 à 2,2 pt** — deux fois
et demie les siens.

⚠️ **ET CE N'EST PAS QU'UNE QUESTION DE TAILLE : C'EST LE RÉGIME.** Ce qui
fait « diamant » plutôt que « grouillement », c'est la RARETÉ des crêtes —
des grains presque tous sourds, quelques-uns qui éclatent (`sin⁴`). Une taille
uniforme donne de la semoule. Plus le détail qui fait tout : **une paillette
sur cinq tire vers le froid**, et c'est ce qui fait diamant plutôt que craie.

Les trois cotes sortent en `static` sur `PoudreGrattage` — `eclat`, `rayon`,
`teinte`. **Deux poudres dans une app, ce sont deux vérités sur ce qu'est une
paillette ;** il n'y en a plus qu'une, et le coffre l'appelle.

Mesuré à l'écran, en plein vol : pixels de grain **3 721 → 2 110** (−43 %).

⚠️⚠️ **ET J'AI RATÉ LA MOITIÉ DE LA LEÇON — « je vois rien ».** Passer au
grain fin sans toucher au NOMBRE a divisé l'encre totale par **9** (338 pt²
avant, 37 après, calculé sur ma propre formule). **Une poudre fine n'est pas
une poudre grosse en plus petit : c'est PLUS DE GRAINS.** La poudre du
grattage en met 90 sur la largeur d'un pouce ; la mienne traverse tout
l'écran avec 70. Passée à **340**, elle rend 64 % de l'ancienne encre avec des
grains 2,3× plus fins — le même poids à l'œil, sans le confetti.

⚠️ **CE QUE J'AI GARDÉ, ET QU'ELLE PEUT REFUSER** : le passage de témoin. Le
grain reste du diamant (blanc, un sur cinq froid) et ne prend qu'**un tiers**
de la couleur de la page — il part dans la teinte de l'objet qui s'en va et
arrive dans celle de l'autre, sans virer à l'orange. Si elle veut la poudre
strictement blanche comme dans les pop-up, c'est le `0.34` qui tombe à zéro.

---

## 23. v14 — PLAN : `test-Backgorund.png`, l'arche de verre noir (29-08)

Verdict : *« essaie avec le background finalement `test-Backgorund` sur mon
bureau, il faut que ça fasse un peu fondu noir bien sûr pour que ça passe dans
l'écran d'iPhone et qu'on voit le bas avec les boutons et la progress bar »*.

### 23.1 Ce que c'est — et ce n'est pas un spotlight

941 × 1672, rapport **0,5628** (l'écran est à 0,4600). Une **arche de verre
noir** à liseré orange, des gouttes suspendues sur les montants, un sol
réfléchissant à caustiques… **et son propre socle.**

Mesuré :

| | |
|---|---|
| sommet de SON socle | **0,701 H** |
| largeur de son socle | 59 % de la largeur |
| ouverture de l'arche | x 0,26 → 0,72, jusqu'à ~0,55 H où elle se referme |
| le bas (0,80 → 1,00 H) | L moyenne **20,8** — c'est le plus clair de l'image |

C'est un changement de nature, pas de réglage : le spotlight était un
ÉCLAIRAGE (une lumière qui tombe), ceci est un **DÉCOR** (une architecture qui
encadre). Les deux ne se règlent pas pareil.

### 23.2 ⚠️ LA CONTRADICTION À RÉGLER EN PREMIER

**Son image est composée avec sa lumière EN BAS ; notre page a besoin que le
bas soit noir.** Le pied — compte, règle, jauge, bouton « Ouvrir » — vit entre
0,75 et 0,95 H, exactement là où cette image est la plus claire (L 20,8, son
maximum). Un fondu noir à cet endroit **éteint son point focal**.

Trois sorties, et la troisième est la bonne :

1. **Fondre le bas** — on garde le cadrage, on perd le sol à caustiques et le
   socle. Il ne reste que l'arche, coupée aux genoux.
2. **Descendre le pied** — impossible, il est déjà à 0,95 H au plus bas.
3. ⚠️ **FAIRE GLISSER L'IMAGE VERS LE HAUT** pour que SON socle tombe là où
   vit LE NÔTRE (0,556 H). L'arche encadre alors notre socle, le sol à
   caustiques passe derrière notre pied, et il reste du noir en dessous. C'est
   le même geste que faisait l'ancienne salle (`ySalle` glissait pour poser le
   néon sur `barreY`) — sauf qu'on glisse sur un socle, pas sur un pixel.

### 23.3 ⚠️ ET SON SOCLE ? — la question qui décide de tout

Elle en a un, nous aussi. **Notre socle ne peut pas partir** : `podCentre`,
`yHaut`, `yBas`, la pose des objets, la MARCHE des voisins, l'atterrissage, la
gerbe — et depuis le §18 **les flaques le prennent comme MASQUE de luminance**.
C'est la contrainte du §20.1, inchangée.

Donc deux socles à l'écran, sauf si :

- **(a)** on efface le sien (fondu local au-dessus de 0,70 H) et on pose le
  nôtre dans l'ouverture de l'arche — **recommandé** ;
- **(b)** on les superpose au pixel près — fragile, et son socle est vu d'un
  autre angle que le nôtre ;
- **(c)** on adopte le sien et on refait toute la géométrie — c'est le
  chantier entier, pas un fond.

### 23.4 Le format

0,5628 contre 0,4600 : **18 % de largeur en trop**. Mais ici, contrairement au
spotlight, **les bords PORTENT le sujet** — les montants de l'arche et les
gouttes vivent à x 0,05-0,26 et 0,72-0,95. Un `aspectFill` les couperait.

→ **Ajusté à la largeur**, comme la vidéo : rien n'est rogné, l'image couvre
le haut, et le bas reste noir pour le pied. Ses bords sont déjà sombres (L 2,1
et 2,7) : le fondu latéral est presque gratuit.

### 23.5 ⚠️ CE QUE ÇA REND CADUC

- **Le faisceau.** `Projecteur` a été baissé à 0,34 parce que le fond en
  portait un (§20.8). Ici il n'y a **plus de faisceau du tout** dans le fond —
  il faut le remonter, sinon l'objet n'est plus désigné par rien.
- **La flaque du socle.** L'arche éclaire par ses liserés orange, latéralement.
  Notre flaque, elle, vient du dessus. À vérifier qu'elles ne se contredisent
  pas.
- **La page ARGENT et la page NOIRE.** L'arche est franchement ORANGE. Sous la
  pièce d'argent (froide) et le booster noir (violet), c'est le même conflit
  qu'au §22.3 — sauf qu'ici il est bien plus fort qu'un simple halo.
  **⚠️ C'est le vrai risque de ce fond, et il ne se voit pas sur la page 2.**

### 23.6 L'ordre

1. Cuire le fond : glissé pour que son socle tombe sur le nôtre, son socle
   effacé, bords et bas éteints en cosinus.
2. Remonter `Projecteur`.
3. **Regarder les QUATRE pages** avant de garder quoi que ce soit — c'est là
   que ce fond se jugera, pas sur la page orange.

### 23.7 CODÉ — l'arche est le décor, et son socle est LE socle

Verdict : *« non, enlève le nôtre »*. `coffre-podium.png` a quitté la page.
`bake_arche.py` cuit `test-Backgorund.png` à la taille exacte de l'écran, avec
les bords et le bas éteints en cosinus. `-coffreSpot` ramène le spotlight.

**La géométrie s'est raccrochée à un socle qui vit dans le FOND** — c'était le
pari du §20.1, et il tient : `podL`, `podH`, `yHaut`, `yBas`, `podCentre` sont
maintenant des mesures faites sur l'image, plus des proportions de PNG. Le
masque des flaques prend l'image de fond au lieu du socle. La pose des objets,
la marche des voisins, l'atterrissage, la gerbe : rien d'autre n'a bougé.

⚠️ **TROIS COTES ONT DÛ ÊTRE MESURÉES AU LIEU D'ÊTRE DÉDUITES, ET CHACUNE
M'AVAIT EU :**

1. **Le socle se mesure au LISERÉ ORANGE, pas à la luminance** — les
   caustiques du sol traversent toute la largeur et rendent toute mesure de
   « bande claire » fausse (0,897 de largeur à 0,66 H, ce qui ne veut rien
   dire).
2. **L'image a dû REMONTER de 130 px.** Posée en haut, sa surface de pose
   tombait 50 points plus bas que notre ancien socle : la barre de crans se
   posait SUR le socle et « Ouvrir » finissait à 37 pt du bord.
3. ⚠️ **`podFin` N'EST PAS `yBas`.** L'empreinte VISUELLE du socle (ses
   anneaux, leur lueur) descend à **0,715 H** quand sa base est à 0,653.
   Déduit, le pied remontait de 60 pt — et la barre de crans retombait sur le
   socle une deuxième fois. **Une empreinte visuelle se mesure sur l'image
   qu'on affiche, elle ne se déduit pas d'une cote de géométrie.**

⚠️⚠️ **ET LE PIÈGE MAISON M'A REPRIS EN PLEIN.** `Woop/Media` sont des
ressources NUES : `Image("coffre-arche")` cherche dans le catalogue, ne trouve
rien, **et ne dit rien**. Le fond était simplement absent, et ce que je
regardais était notre `Projecteur` sur du noir. Pire, ça a révélé que
`Image("coffre-spot")` échouait DEPUIS LE DÉBUT : **l'image de pose du
spotlight — celle dont j'avais écrit qu'elle était OBLIGATOIRE — n'a jamais
été affichée une seule fois.** Un filet qu'on croit posé et qui n'existe pas
est pire que pas de filet. Le chargement passe maintenant par le bundle
(`FondCoffre`), avec cache.

### 23.8 ⚠️ LE COÛT, MESURÉ : L'IDENTITÉ DES PAGES S'EST EFFONDRÉE

C'est le risque annoncé au §23.5, et il est chiffré. Teinte du plateau (R−B) :

| page | fond spotlight | **fond arche** |
|---|---|---|
| pièce d'or | +100 | +47 |
| booster lune | +114 | +50 |
| pièce d'argent | **+13** | **+28** |
| booster noir | +13 (violet) | +27 |
| **écart entre les extrêmes** | **101** | **23** |

**Les quatre pages tiennent maintenant dans 23 points au lieu de 101 : le
signal d'identité est quatre fois plus faible.** L'arche est un DÉCOR, elle a
sa couleur, et elle gagne contre la flaque. Le spotlight était un ÉCLAIRAGE :
il se laissait teinter.

Trois sorties, à trancher au regard :
1. **Monter la force des flaques** (0,11 + 0,40 → plus) — le moins cher.
2. **Désaturer l'arche vers le neutre** dans le bake, pour qu'elle redevienne
   un support de couleur au lieu d'une couleur.
3. **Assumer** : un seul décor, et l'identité se dit par l'objet et le texte,
   plus par la lumière.

---

## 24. PLAN : ANIMER LES NÉONS DU SOCLE (29-08)

Verdict : *« en vrai c'est très beau, tu peux animer dessus des néons qui sont
dans le podium ? »*

### 24.1 Ce qu'on peut en tirer — mesuré

En isolant les pixels saturés (R−B > 40) de `coffre-arche.png` :

| bande | % de pixels néon | L moyenne |
|---|---|---|
| 0,4 → 0,5 H | 5,7 % | 16,5 |
| **0,5 → 0,6 H** | **21,5 %** | **37,9** |
| 0,6 → 0,7 H | 9,9 % | 20,8 |
| 0,7 → 1,0 H | ~0 % | ~0 |

> **Les néons portent 35,9 % de la lumière TOTALE de l'image**, dont 28,8 %
> dans la seule bande du socle. Les anneaux vivent entre **0,500 et 0,690 H**.

Autrement dit : les animer, ce n'est pas ajouter un effet — **c'est prendre la
main sur plus d'un tiers de l'image, exactement là où il faut.**

### 24.2 ⚠️ CE QUE CETTE ANIMATION DOIT FAIRE, ET PAS SEULEMENT ÊTRE

Deux lois de la maison s'appliquent, et elles pointent au même endroit :

- *« un mouvement qui rejoue à chaque arrivée devient du bruit en trois
  visites »* (§17.5) — cette page a déjà les flaques, la poudre, la
  lévitation, le lustre de la jauge et la respiration du bouton ;
- **et le §23.8 vient de mesurer que l'identité des pages s'est effondrée** :
  101 points d'écart entre les extrêmes avec le spotlight, **23** avec
  l'arche. Le décor a gagné contre la flaque.

> **La meilleure animation possible ici est donc celle qui RÉPARE l'identité.**
> Le néon est l'objet le plus lumineux de l'écran ; s'il prend la couleur de la
> page, ce n'est plus de la décoration, c'est le signal.

### 24.3 Trois animations, classées par ce qu'elles font

**① LA TEINTE PAR PAGE — la seule qui travaille.**
Le néon du socle vire à l'or, à la braise, à l'argent froid, au violet en
traversant. C'est le §18 (*la lumière appartient à l'objet*) appliqué à ce qui
éclaire le plus. Ce n'est pas une boucle : c'est une TRANSITION, donc elle ne
peut pas devenir du bruit. **Elle devrait ramener l'écart bien au-delà de 23.**

**② L'ÉCLAT À LA POSE — une réponse, pas une boucle.**
L'anneau encaisse quand l'objet se pose (flash court, ~0,25 s, puis retour) et
quand la jauge finit de se remplir. Elle ne joue que quand il se passe quelque
chose — donc elle ne s'use pas.

**③ LE BALAYAGE ANGULAIRE — la vie, et le seul risque.**
Un reflet qui court autour de l'anneau, une révolution en ~6 s. C'est ce qui
fait « néon allumé » plutôt que « néon peint ». ⚠️ Permanent, donc c'est celle
qui peut lasser : à garder FAIBLE (un sur-éclat de +25 %, pas un phare), et à
juger en dernier.

> **Ordre : ① puis ②, et ③ seulement si la page paraît figée.**

### 24.4 La technique — et le point délicat est la SOUSTRACTION

**Au bake, deux fichiers au lieu d'un :**

- `coffre-arche-neon.png` — les liserés seuls. ⚠️ **Alpha = une RAMPE sur la
  saturation, jamais un seuil** : un seuil binaire dessine un escalier sur un
  dégradé, et tout ici est dégradé (leçon du détourage, §18.5).
- `coffre-arche.png` — l'arche **PRIVÉE de ses néons**.

⚠️⚠️ **C'EST CETTE SOUSTRACTION QUI DÉCIDE DE TOUT.** Si on se contente de
SUPERPOSER un néon coloré sur l'image intacte, on ajoute à de l'orange qui est
déjà là : on peut le SURCHARGER, jamais le faire virer au bleu. Pour qu'un
socle devienne froid sur la page d'argent, **il faut d'abord lui retirer son
orange**. Les néons étant de la lumière ADDITIVE dans le rendu, les retirer
est une soustraction, et elle se mesure : la base doit retomber à la luminance
du verre nu là où l'anneau passait.

**Au runtime :**

```
fond            Image(coffre-arche)                     — statique
néon            Image(coffre-arche-neon) en plusLighter — teinté par la page
balayage (③)    le même, masqué par un AngularGradient en rotation
```

### 24.5 ⚠️ LES PIÈGES, NOMMÉS D'AVANCE

1. ⚠️ **`FondCoffre`, pas `Image(nom)`.** Les fichiers vivent dans
   `Woop/Media` : ce sont des ressources NUES, `Image("coffre-arche-neon")`
   ne trouvera rien **et ne dira rien**. Le piège vient de me reprendre.
2. ⚠️ **Deux images plein écran au lieu d'une** : la mémoire double (≈3 → 6 Mo
   décodés). Acceptable, mais c'est un fait à connaître.
3. ⚠️ **La teinte ne doit pas désaturer** — loi anti-brun : R reste haut, on
   descend V et B. Un néon désaturé est un néon éteint.
4. ⚠️ **Le balayage coûte une passe hors écran par image** (`.mask` animé sur
   une image plein écran). Il ne se monte que pendant qu'il tourne, et se
   mesure — `./tools/charge.sh` d'abord.
5. ⚠️ **Faut-il que l'ARCHE vire aussi, ou seulement le SOCLE ?** Toute la
   scène qui change de couleur par page, c'est très fort — peut-être trop.
   **Je propose deux masques : le socle vire, l'arche reste orange.** Le décor
   garde son identité, l'objet garde la sienne.

### 24.6 L'ordre

1. Le bake à deux fichiers, avec la soustraction — et **vérifier sur damier**
   que la base n'a plus de liseré (le noir cache tout, §18.5).
2. ① la teinte par page, puis **remesurer l'écart R−B des quatre pages** :
   c'est le chiffre qui dira si ça a marché.
3. ② l'éclat à la pose.
4. ③ le balayage, en dernier, faible, et mesuré à la cadence.

### 24.7 CODÉ — et l'identité est plus forte qu'elle ne l'a JAMAIS été

`bake_neon.py` sort deux fichiers de `coffre-arche.png` : les anneaux seuls en
niveaux de gris, et la base **socle éteint**. Mesuré sur la bande du socle :
saturation R−B **21,9 → 8,9**, luminance −44 %. Et hors bande : **R−B 3,4 →
3,4** — l'arche n'a pas bougé d'un point, comme voulu.

Au runtime, une couche en `plusLighter`, teintée au `colorMultiply` par une
couleur **interpolée entre les deux pages voisines** : le socle vire pendant le
voyage, il ne saute pas au cran — il annonce l'objet qui arrive avant qu'il ne
soit posé. Plus l'éclat à la pose (+75 % sur `chocForce`).

**Teinte des anneaux (les 8 % les plus clairs de la bande) :**

| page | R V B | R−B |
|---|---|---|
| pièce d'or | 185 · 148 · 97 | **+88** |
| booster lune | 187 · 126 · 82 | **+105** |
| pièce d'argent | 153 · 155 · **162** | **−9** |
| booster noir | 147 · 115 · **164** | **−16** |

| | écart entre les extrêmes |
|---|---|
| spotlight | 101 |
| arche seule | **23** |
| **arche + néon** | **121** |

⚠️ **Et l'argent et le noir passent en NÉGATIF** — le bleu dépasse le rouge.
Ce n'était jamais arrivé : même le spotlight n'avait pu descendre qu'à +13. Le
socle est franchement froid sur la page d'argent, franchement violet sur la
noire. **C'est la soustraction qui l'a permis**, pas la superposition.

⚠️ **ET MA PREMIÈRE MESURE DISAIT 28.** J'échantillonnais le PLATEAU (la
surface de verre), pas les ANNEAUX — c'est-à-dire tout sauf l'endroit où le
néon vit. Sur les mêmes pixels, avant le néon : 23 ; après : 121. **Mesurer au
mauvais endroit donne un chiffre juste sur une question qu'on ne se posait
pas.**

**Reste** : ③ le balayage angulaire, à ne poser que si la page paraît figée —
et à mesurer à la cadence, parce qu'un `.mask` animé sur une image plein écran
coûte une passe hors écran par image.

### 24.8 CODÉ — ③ le balayage angulaire

⚠️⚠️ **LE PREMIER JET NE TOURNAIT PAS, ET C'EST LE PIÈGE MAISON DES RAMPES
SOUS `withAnimation`.** J'avais écrit `AngularGradient(angle: .degrees(tour))`
avec `tour` animé en `repeatForever`. Un `AngularGradient` est un
`ShapeStyle`, **pas un modificateur** : SwiftUI ne l'interpole jamais. Il
évalue le corps une fois, à la valeur d'arrivée — et 360° est identique à 0°.
Mesuré : l'écart de luminance gauche/droite des anneaux restait à **−4,7
pendant 5 secondes**, parfaitement immobile.

Remède : le dégradé est FIGÉ dans un carré qu'on fait tourner par
`rotationEffect`, qui est un modificateur. Mesuré après : l'écart passe de
**−4,9 à +2,9** sur 5,6 s — le reflet court.

Réglages tenus court, parce que c'est la seule des trois qui joue en
permanence : une SEULE crête (un phare, pas un gyrophare), +30 %, une
révolution en 7 s.

⚠️ **COÛT NON MESURÉ** : un `.mask` animé sur une image plein écran force une
passe hors écran par image. Le simulateur est aveugle à ça — il faut la sonde
sur le téléphone, `./tools/charge.sh` d'abord.

---

## 25. PLAN : LE PIED, LA JAUGE ET LES POLICES (29-08)

Verdict : *« pour moi c'est pas assez clair · la progress doit être en blanc
dégradé très premium, le gris ça fait cheap, ça donne pas envie · et certaines
polices sont trop petites, c'est pas Apple style avec les polices claires et
identifiables · comment améliorer les composants ? »*

### 25.1 Les polices — elle a raison, et c'est chiffrable

Ce que le pied porte aujourd'hui, contre l'échelle iOS :

| | taille | opacité | équivalent Apple |
|---|---|---|---|
| le compte (« 1 140 ») | 30 | 0,96 | Title 1 (28) ✓ |
| le mot (« coins ») | **13** | **0,50** | Footnote |
| la règle | **12** | **0,44** | Caption 1 |
| « 60 to go » | **11** | **0,50** | **Caption 2** — le plus petit d'iOS |
| « Ouvrir » | **14,5** | — | entre Subhead et Callout |

**Quatre des cinq lignes vivent dans le registre des LÉGENDES.** Caption 1 et
2 sont faits pour de la densité — une liste, un tableau —, pas pour un écran
héros où il n'y a que cinq lignes à lire. Et à 0,44 d'opacité sur du noir, la
règle est deux fois moins contrastée que le compte.

**Proposition — on monte d'un cran et demi, et on remonte les opacités :**

| | avant | **après** | pourquoi |
|---|---|---|---|
| le compte | 30 · 0,96 | **44 · 1,00** | c'est LE nombre : il doit se lire de loin |
| le mot | 13 · 0,50 | **17 · 0,62** | Body — la plus petite taille qu'Apple appelle « lisible » |
| la règle | 12 · 0,44 | **15 · 0,58** | Subheadline |
| le reste | 11 · 0,50 | **13 · 0,66** | Footnote, et il porte un chiffre |
| le bouton | 14,5 | **17 · semibold** | Body : un bouton se lit, il ne se devine pas |

### 25.2 La jauge — le gris fait cheap parce que c'est un gris

Aujourd'hui : rail `blanc 0,09`, remplissage `blanc 0,80` **plat**, **3 pt**
de haut, 196 de large.

Trois choses la rendent pauvre, et aucune n'est la couleur :

1. ⚠️ **Elle est PLATE.** Un aplat de blanc à 0,80 ne dit rien ; ce qui fait
   « premium », c'est qu'une barre ait une LUMIÈRE — donc un dégradé le long
   du remplissage, franc à la tête, plus doux à la queue. Une barre éclairée
   se lit comme de l'énergie ; une barre peinte, comme un rectangle.
2. ⚠️ **Elle est trop FINE.** 3 pt, c'est la moitié d'une `ProgressView`
   Apple. À cette épaisseur, un dégradé ne peut même pas se voir.
   → **5 pt**, en capsule.
3. **Le rail est trop clair.** 0,09 de blanc sur un fond qui n'est plus noir
   (l'arche a de la lumière partout) : il se noie. → un rail plus SOMBRE que
   le fond, pas plus clair — c'est un creux, pas un trait.

**Proposition** : rail `noir 0,45` cerclé d'un liseré blanc 0,08 · remplissage
en dégradé blanc `1,00 → 0,72` de la tête vers la queue · 5 pt · et la braise
de tête garde la couleur de la page — c'est le seul point coloré, donc c'est
lui qui relie la jauge à l'objet.

### 25.3 ⚠️ LE VRAI DÉFAUT : LES DEUX VARIANTES NE SONT PAS LE MÊME COMPOSANT

C'est ça, « pas assez clair ». Les quatre pages font **deux anatomies** :

- **avec** jauge et bouton (booster orange) ;
- **sans** ni l'un ni l'autre (or, argent, et noir à zéro) — et alors le pied
  s'arrête après deux lignes, laissant **40 % de l'écran vide** sous lui.

Sa capture de la page argent le montre : le texte, puis un trou noir jusqu'en
bas. Le composant n'a pas l'air d'avoir deux états, il a l'air **amputé**.

> **Remède : le bouton EXISTE TOUJOURS.** Sur les pages où l'on ne peut rien
> faire, il dit ce qui manque au lieu de disparaître.

| page | bouton |
|---|---|
| pièce d'or | **« 60 coins to go »** — verre mat, inactif |
| booster orange | **« Ouvrir »** — capsule blanche, actif |
| pièce d'argent | **« A rare drop »** — verre mat, inactif |
| booster noir (0) | **« Locked »** — verre mat, inactif |
| booster noir (≥1) | **« Ouvrir »** — actif |

C'est la 5ᵉ loi d'Opal, déjà écrite au §17.3 : *le verrouillé se dit par la
MATIÈRE, pas par un cadenas*. Un bouton mat, non éclairé, à la même place et
de la même taille que l'actif — et le mot dit pourquoi.

**Bénéfice second, et il est gros : les quatre pages retrouvent la MÊME
ANATOMIE**, donc la même hauteur, donc plus de trou. Une grille, quatre pages,
deux états — c'est la loi du §12 (« le pied décrit toujours l'objet posé »)
menée à son terme.

### 25.4 Et la jauge sur les pages sans progression ?

Elle reste absente — mais son ESPACE ne l'est pas : le bouton remonte à sa
place. Le bloc garde donc une hauteur unique (compte · règle · [jauge] ·
bouton), et c'est le bouton qui absorbe la différence.

### 25.5 L'ordre

1. Les polices et les opacités (§25.1) — le moins risqué, le plus visible.
2. La jauge (§25.2), et **remesurer son contraste contre le fond de l'arche**.
3. Le bouton toujours présent (§25.3) — c'est celui qui change la structure,
   donc le dernier, et à juger sur les quatre pages côte à côte.

### 25.6 CODÉ — une grille, quatre pages, deux états

**Les polices quittent le registre des légendes.** Le compte 30 → **44**, le
mot 13 → **17** (Body), la règle 12 → **15** (Subheadline), le reste 11 →
**13** (Footnote — c'était Caption 2, le plus petit corps d'iOS, et il porte
un chiffre). Les opacités montent avec : 0,50 → 0,62 · 0,44 → 0,58 · 0,50 →
0,66.

**La jauge.** Ce n'était pas la couleur, c'était trois choses :
un remplissage **PLAT** (un aplat ne fait pas premium, une lumière oui →
dégradé blanc 0,72 → 1,00 vers la tête) · **3 pt**, la moitié d'une
`ProgressView` Apple, où un dégradé ne peut même pas se voir (→ **5 pt**) ·
et un rail en blanc 0,09 qui se noyait sur un fond qui n'est plus noir
(→ **un creux** : noir 0,45 cerclé d'un cheveu blanc). La braise de tête
grossit à 7 pt et garde la couleur de la page — c'est le seul point coloré,
donc c'est lui qui relie la jauge à l'objet.

**Le bouton est le primaire de la maison** (`DiamondPrimaryButton`), et il
**existe sur les quatre pages** :

| page | bouton |
|---|---|
| pièce d'or | « 60 COINS TO GO » — verre mat |
| booster orange | **« OUVRIR »** — le bijou |
| pièce d'argent | « A RARE DROP » — verre mat |
| booster noir (0) | « LOCKED » — verre mat |

⚠️ **IL FAUT LE PRENDRE EN PRIORITÉ HAUTE.** `DiamondPrimaryButton` est bâti
sur un `Button`, et le geste de la page vit sur un ancêtre plein écran avec
`minimumDistance: 0` : un `Button` d'enfant s'y fait AFFAMER dès que le drag
reconnaît. On lui passe une action VIDE et c'est le tap prioritaire qui commet
l'ouverture — deux chemins vers la même action l'ouvriraient deux fois.

⚠️ **ET LE BOUTON EST ANCRÉ EN BAS, PAS EMPILÉ.** Le bloc passe à 196 de haut
et garde cette hauteur sur les quatre pages : sur celles sans jauge, c'est le
`Spacer` qui absorbe, pas le bouton qui remonte. Un bouton qui se déplace
d'une page à l'autre se cherche à chaque fois.

**Reste** : le bouton primaire est posé tel quel — *« on va le retravailler
plus tard »*. Et sa hauteur (58) + son débord de halo (34) n'ont pas été
mesurés contre le bas de l'écran sur un petit iPhone.

---

## 26. PLAN : LA POLICE, LA RÈGLE, ET LA BARRE (29-08)

Verdict : *« 60 to go c'est pas clair · le 100 coins opens one devrait être
dans une pill liquid glass au-dessus du booster comme pour le booster
légendaire · et la progress bar est pas belle du tout · et c'est pas la font
Apple aussi · tu vas trop vite »*.

### 26.1 La police — le fait, et il n'est pas celui que je croyais

J'ai d'abord cru à un bug : les cinq `.otf` d'Inter sont dans le bundle, et
**`UIAppFonts` est absent partout** — ni dans le pbxproj, ni dans l'Info.plist
généré. Sans cette clé, iOS n'enregistre rien et `Font.custom` retombe
silencieusement sur SF Pro. J'allais l'annoncer.

⚠️ **C'était faux, et j'ai bien fait de continuer à chercher.**
`WoopApp.init()` les enregistre À LA MAIN :

```swift
for url in Bundle.main.urls(forResourcesWithExtension: "otf", …) {
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}
```

**L'app est donc bien en Inter, et elle a raison : ce n'est pas la police
d'Apple.**

Le levier est **une seule fonction** — `WoopFont.inter(_:_:)`, dans
`Theme.swift`, appelée **270 fois**. La faire rendre
`.system(size:weight:)` bascule toute l'app d'un caractère.

⚠️⚠️ **MAIS LA PORTÉE N'EST PAS LE COFFRE : C'EST L'APP ENTIÈRE**, et une
autre session travaille sur d'autres écrans en ce moment. Ce n'est pas un
réglage à glisser dans un lot « pied du coffre ».

**Trois questions à trancher, et elles sont produit :**
1. **Toute l'app, ou le coffre seul ?** Deux polices dans une app, c'est deux
   voix — je déconseille.
2. **SF Pro Text/Display ou SF Rounded ?** L'app est sombre, précieuse,
   métallique : SF Pro (pas Rounded).
3. Si on bascule, **le nom `inter` devient un mensonge** sur 270 sites : il
   faut renommer, sinon la prochaine personne cherchera une police qui n'est
   plus là.

### 26.2 « 60 to go » — la vraie cause est une REDONDANCE que j'ai créée

Ce n'est pas la formulation. C'est que **le même nombre est écrit deux fois,
à 40 pt l'un de l'autre** :

```
        ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
             60 to go              ← sous la barre
      [   60 COINS TO GO   ]       ← sur le bouton (§25.3, ajouté par moi)
```

L'œil lit deux fois, cherche la différence, n'en trouve pas — et doute des
deux. C'est moi qui l'ai introduit hier en mettant l'état sur le bouton.

> **Remède : la barre perd son étiquette.** Une barre à moitié pleine sous un
> bouton qui dit « 60 COINS TO GO » n'a besoin de rien de plus. Une ligne en
> moins, et chaque chose dite une fois.

### 26.3 La règle monte dans une pill de verre, au-dessus de l'objet

Sa demande, et elle est juste : *« 100 coins open one » devrait être dans une
pill liquid glass au-dessus du booster*.

Ce que ça change, et c'est plus qu'un déplacement : **la règle cesse d'être
une note de bas de page et devient une ÉTIQUETTE DE PRIX**, accrochée à
l'objet. On lit « ce sachet coûte 100 pièces » en regardant le sachet, pas en
lisant sous le socle.

| page | la pill dit |
|---|---|
| pièce d'or | *(aucune — une pièce n'a pas de prix)* |
| booster orange | **100 COINS** |
| pièce d'argent | *(aucune)* |
| booster noir | **1 SILVER COIN** |

⚠️ **`glassEffect(.clear)`, jamais `.regular`** : le givré laiteux est
interdit, et ce qui passe dessous est le décor de l'arche — du contenu doux,
donc exactement le cas où `.clear` est légitime.

⚠️ **Et le pied perd une ligne.** Il reste : le compte, la barre, le bouton.
Trois choses au lieu de cinq — c'est ça, « plus clair ».

⚠️ **Question ouverte** : les pages SANS prix (les deux pièces) n'ont alors
pas de pill. On retombe sur le problème du §25.3 — deux anatomies. Soit la
pill y dit autre chose (« RARE DROP » pour l'argent ?), soit on assume que
seul un objet ACHETABLE porte un prix. **Je penche pour la deuxième** : un
prix ne s'invente pas pour faire symétrie.

### 26.4 La barre — pourquoi elle est laide, et c'est moi

Vue de près, le diagnostic est net et il y a **trois causes** :

1. ⚠️⚠️ **ELLE RESSEMBLE À UN SLIDER.** La braise de tête est un DISQUE PLEIN
   posé au bout du remplissage : c'est exactement le pouce d'un `Slider` iOS.
   Une barre de progression n'a pas de pouce — et celle-ci invite à la tirer.
   **C'est le défaut principal, et il est fonctionnel avant d'être esthétique.**
2. ⚠️ **LE DÉGRADÉ L'A RENDUE GRISE.** J'ai mis `blanc 0,72 → 1,00` en croyant
   faire « premium ». Mais **l'œil lit un dégradé par son arrêt le plus
   SOMBRE** : les deux tiers de la barre sont à 0,72, donc elle est grise. J'ai
   produit exactement ce qu'elle reprochait, en essayant de le corriger.
3. **Le rail a disparu.** Noir 0,45 sur un fond noir : on ne voit plus « le
   chemin qui reste ». Une jauge sans son reste ne montre pas une progression,
   elle montre un trait.

**Trois remèdes, classés :**

**A — LA BARRE HONNÊTE (recommandé, tout de suite).**
Remplissage **blanc PLEIN** (1,00, aucun dégradé dans la matière) · **pas de
pouce** — la tête est une LUEUR diffuse dans la couleur de la page, sans
contour, qui déborde de la barre au lieu de s'y poser · rail **visible**
(blanc 0,12) · 4 pt, 240 de long. C'est la `ProgressView` d'Apple, en plus
lumineux. Le « premium » vient de la lueur, pas d'un dégradé dans le blanc.

**B — LES SEGMENTS.**
Dix capsules, une par tranche de 10 pièces. On lit « il en manque trois » sans
compter. Plus clair que tout le reste, moins précieux.

**C — L'ANNEAU DU SOCLE DEVIENT LA JAUGE.** *(l'ambition)*
Le néon qu'on vient d'extraire se remplit sur son pourtour. Spectaculaire,
natif à la scène, et **la couche existe déjà** (`coffre-arche-neon`). ⚠️ Mais
la lecture est imprécise sur une ellipse en perspective, et le chiffre est
loin. À garder pour quand l'anatomie sera figée.

### 26.5 L'ordre

1. **A** — la barre honnête, et la braise cesse d'être un pouce.
2. **La pill de prix** au-dessus de l'objet, et le pied perd sa ligne de règle.
3. **L'étiquette sous la barre disparaît** (la redondance du §26.2).
4. **La police** : à trancher séparément, parce que c'est l'app entière.

---

## 27. ⚠️ POURQUOI JE TOURNE EN ROND — et ce qui casse la boucle (29-08)

Verdict : *« ou sinon faut mixer 100 coins et 60 to go, c'est pas clair, avec
une mini pièce jaune — pareil pour la légendaire, c'est pas clair — et la
progress bar pas belle du tout, tu vas trop vite, je voulais quelque chose
d'archi premium, tu tournes en rond »*.

Elle a raison sur les deux points, et le second explique le premier.

### 27.1 Le diagnostic que je n'avais pas fait

J'ai réglé cette barre **quatre fois** : plus épaisse, un dégradé, un rail plus
sombre, une braise plus grosse. Chaque tour a produit un autre défaut — le
dégradé l'a rendue GRISE, la braise en a fait un SLIDER. Je réglais les
symptômes.

> ⚠️⚠️ **UNE BARRE EST PLATE PAR NATURE. ON NE REND PAS UNE BARRE PREMIUM :
> ON LA REMPLACE.**
>
> Le premium de cette maison, c'est du verre noir, un cheveu de liseré, et une
> lumière qui vient de DEDANS. Un rectangle rempli n'a ni dedans, ni
> épaisseur, ni matière — il n'a qu'une longueur. Aucun réglage ne lui donnera
> ce qu'il n'a pas.

C'est ça, tourner en rond : chercher dans un objet une qualité que sa forme
interdit.

### 27.2 Et « 100 coins » + « 60 to go » sont UNE SEULE PHRASE coupée en deux

Sa proposition — les mixer, avec une mini pièce — est la bonne, et elle dit
pourquoi c'était confus :

```
   « 100 coins open one. »     ← ce que ça COÛTE
   « 60 to go »                ← ce qu'il MANQUE
```

Deux lignes, deux endroits, et il faut faire la soustraction soi-même pour
comprendre qu'on est à 40. **Le fait unique, c'est : « 40 sur 100 ».** Le prix
et le reste sont la même information vue de deux côtés.

### 27.3 LA PROPOSITION : la pill EST la jauge

Un seul objet remplace la règle, la barre et son étiquette :

```
        ╭───────────────────────────────╮
        │ 🪙   40 / 100                 │   ← capsule de verre
        ╰───────────────────────────────╯
          ▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░     le remplissage EST le fond
```

- **une capsule de verre** (`glassEffect(.clear)`) — de la matière, pas un
  trait ; elle a une épaisseur, un liseré, un dedans ;
- **le remplissage vit DANS la capsule**, comme un liquide qui monte : c'est
  la lumière qui vient de l'intérieur, la seule chose que la maison appelle
  premium ;
- **la mini pièce** à gauche (le sprite existe : `piece-or`, cases de
  320 × 320 px — largement de quoi tenir 20 pt) dit de quelle monnaie on
  parle sans un mot ;
- **« 40 / 100 »** dit le prix ET le reste d'un coup.

**Et elle règle le §26.2 :** plus d'étiquette sous une barre, plus de
redondance avec le bouton — il ne reste qu'un objet.

**Pour la légendaire, la même grammaire, et ça la rend claire :**

| page | la pill |
|---|---|
| pièce d'or | 🪙 **1 140** *(pas de « / » : rien à atteindre)* |
| booster orange | 🪙 **40 / 100** |
| pièce d'argent | 🪙 argent **0** |
| booster noir | 🪙 argent **0 / 1** |

⚠️ **« 0 / 1 » est exactement ce qui manquait à la légendaire.** « One silver
coin opens it » demandait de savoir combien on en a ; « 0 / 1 » le dit et
donne le prix dans le même geste. Et **la même forme pour les quatre pages**
règle enfin les deux anatomies du §25.3 — sans inventer de prix là où il n'y
en a pas : c'est le « / » qui apparaît ou non.

### 27.4 Où elle vit — et c'est sa demande du message précédent

**Au-dessus de l'objet**, flottant dans la scène, pas sous le socle. C'est une
ÉTIQUETTE DE PRIX : on la lit en regardant l'objet.

⚠️ Conséquence : **le pied ne porte plus que deux choses** — le compte en
grand, et le bouton. C'est là que « plus clair » se gagne : cinq lignes
deviennent deux, et la troisième information est montée avec l'objet.

⚠️ **À vérifier avant de coder** : la pill au-dessus du sachet tombe entre
0,30 et 0,38 H, c'est-à-dire **en plein dans le faisceau de l'arche**. Du
verre `.clear` sur une zone claire peut disparaître. Il faudra le MESURER, pas
l'espérer — et c'est exactement le genre de chose qui m'a déjà eu deux fois
sur cette page (le chevron, l'image de pose).

### 27.5 Ce que je ne fais PAS

- Je ne retouche plus la barre : elle disparaît.
- Je ne garde pas « 60 to go ».
- Je ne touche pas à la police avant qu'elle ait tranché (§26.1) : c'est
  l'app entière, 270 appels, et une autre session travaille dessus.

### 27.6 CODÉ — la pill remplace la règle, la barre et son étiquette

La barre a disparu, avec son rail, son lustre, sa braise-pouce et son
étiquette : **6 300 caractères de code retirés**. À leur place, une capsule de
verre au-dessus de l'objet, la mini pièce à gauche, et le remplissage qui vit
DEDANS.

| page | la pill |
|---|---|
| pièce d'or | 🪙 1 140 |
| booster orange | 🪙 **40 / 100** |
| pièce d'argent | 🪙 0 |
| booster noir | 🪙 **0 / 1** |

Le pied ne porte plus que **deux choses** : le compte, et le bouton.

⚠️ **« LA POLICE EST BIZARRE » — CE N'ÉTAIT PAS LA POLICE.** Vu de près, le
défaut était l'APPARIEMENT : à 44 contre 17 sur une ligne de base commune, le
mot tombe au pied d'un chiffre trois fois plus haut — il a l'air DÉCROCHÉ, pas
petit. Corrigé sans toucher à Inter : le nombre à 40, et le mot devient une
**étiquette en capitales espacées** (15, tracking 1,5) — comme sur le bouton.
Des capitales tracées se lisent comme une UNITÉ accolée au nombre, pas comme
un mot qui a glissé. ✅ **Et la police reste Inter** : elle a tranché.

⚠️⚠️ **UN DÉFAUT MESURÉ QUI RESTE : LES DEUX PIÈCES NE SE DISTINGUENT PAS À
22 pt.** Leur cerclage donne R−B **+20** pour l'or et **+1** pour l'argent —
la différence existe mais elle est faible, et surtout **le croissant orange à
l'intérieur est IDENTIQUE sur les deux**. Or toute la raison d'être de cette
mini pièce est de dire DE QUELLE MONNAIE on parle. Trois remèdes possibles :
grossir la pièce (22 → 28), poser un anneau de couleur derrière elle, ou
teinter le verre de la pill par la monnaie. **À trancher au regard.**

⚠️ **Et le pied a l'air vide sur les pages sans jauge** : le compte, puis
180 px de noir, puis le bouton ancré en bas. C'est le prix de la grille
unique (§25.3) — le bouton ne se déplace pas d'une page à l'autre. À juger :
soit on assume, soit le bloc se resserre quand il n'y a que deux lignes, et on
perd l'ancrage.

---

## 28. PLAN : LA DESCRIPTION, LES BOUTONS EN MOINS, ET LA PAGE DU BOOSTER NOIR (29-08)

Verdict : *« rajoute une phrase de description sous les éléments, on comprend
pas · enlève les boutons "60 coins to go" sous la pièce orange et celle argent
· "legendary booster" c'est trop long en titre · quand on clique sur le
booster noir, ça lance une vidéo (qu'on peut passer) puis on arrive sur une
page : header avec un booster fondu noir, un chevron pour revenir au coffre,
sous le header un texte à la Apple assez grosse police, et une grosse pièce
silver dans un coin »*.

### 28.1 LE PIED — la description prend la place du bouton

**La description.** Une phrase sous le compte, qui dit d'où vient l'objet et à
quoi il sert. C'est la règle du §12 (*le pied décrit l'objet posé*) enfin
dite en mots, pas en chiffres :

| page | compte | description |
|---|---|---|
| pièce d'or | 1 140 **COINS** | *20 coins for every set you finish.* |
| booster orange | 1 **BOOSTER** | *Won after every session — or 100 coins.* |
| pièce d'argent | 0 **SILVER** | *A rare drop from the path. Never earned, never bought.* |
| booster noir | 0 **LEGENDARY** | *One silver coin opens it. A legendary card, guaranteed.* |

Corps 15, opacité 0,62, centrée, deux lignes maximum — c'est la ligne qu'on
avait retirée au §27, qui revient avec un VRAI contenu et non un doublon du
prix.

**Les boutons mats disparaissent** sur les deux pages de pièces. « 60 COINS TO
GO » sous la pièce d'or était un doublon de la pill « 40 / 100 » ; « A RARE
DROP » était une description déguisée en bouton. ⚠️ On revient donc à **deux
anatomies** (compte + description · compte + description + bouton) — mais
c'est la description qui donne maintenant son poids au pied, plus le bouton.
Le vide du §27.6 se règle par du SENS, pas par un objet de remplissage.

**Le titre** : « LEGENDARY BOOSTERS » → **« LEGENDARY »**. Le sachet est sur
le socle, il n'a pas besoin qu'on lui dise qu'il est un booster.

### 28.2 LA VIDÉO — mesurée, et trois faits qui comptent

`~/Downloads/video_booster-nooir.mp4` : 2160 × 3840, HEVC 10 bits, 24 i/s,
**8,04 s**, **19 Mo** à 19,5 Mb/s. Quatre temps : le sachet dans les étoiles →
il grossit → macro sur le croissant → **il se dissout en poussière d'étoiles**.

1. ⚠️ **ELLE A DU SON** (AAC). Toutes les boucles de l'app sont muettes ;
   celle-ci est une cinématique, le son est légitime — mais il doit respecter
   l'interrupteur silencieux (`AVAudioSession` en `.ambient`, jamais
   `.playback`). Sinon un coffre ouvert dans le métro fait du bruit.
2. **Elle ne boucle pas, et c'est voulu** : c'est un film à sens unique, qui
   finit dans un fondu. Ça tombe bien — **sa dernière image EST la transition
   vers la page** : le sachet qui se dissout en poudre laisse place au sachet
   « fondu noir » du header. Il faut caler la coupe là, pas avant.
3. **Elle est en 9:16**, l'écran en 0,46. Le sachet est centré et la macro
   remplit le cadre : un `aspectFill` qui rogne 18 % de largeur ne perd rien.
   Recuite à 1206 × 2622 en H.264 (`crf 20`, tramage pour le 10 bits) —
   estimation **4 à 6 Mo** au lieu de 19.

**Le lecteur existe déjà** : `CinematicPlayer` + `film(sc)` + `passerDevant()`
+ `terminer(fondu:noir:)` — c'est l'intro du coffre. Même mécanique : **un tap
n'importe où passe**, et une mention « Passer » discrète apparaît après ~1 s
(un geste ne s'annonce pas, une porte doit être visible).

### 28.3 LA PAGE — ce que sa maquette dit

Relevé sur sa capture Figma :

| zone | y (fraction) | ce qu'il y a |
|---|---|---|
| chevron | 0,06 | en haut à gauche, 44 pt — la règle des trois ronds |
| sachet | 0,12 → 0,37 | centré, ~30 % de la largeur, **fondu vers le noir en bas** |
| titre | 0,45 → 0,52 | deux lignes, blanc, ~34 pt |
| corps | 0,55 → 0,78 | gris, ~17 pt |
| pièce d'argent | 0,85 → hors cadre | **en bas à DROITE**, coupée par le bord |

⚠️ **Elle écrit « coin gauche » ; sa maquette la met à DROITE.** Je suis la
maquette (le dessin est plus fiable qu'un mot tapé vite) — à confirmer.

**Le header.** Pas la scène 3D : une `SCNView` dans une page, c'est le lag
lui-même (loi de la maison). `SachetVignette(.noire)` en grand, avec un
**masque en dégradé** blanc → transparent sur son tiers bas : c'est ça, le
« fondu noir ». ⚠️ Un masque, pas un `.blur` — un flou poserait un voile
uniforme sur tout le rectangle de l'hôte.

**Le texte.** « À la Apple » : titre `inter(34, .semibold)` blanc plein sur
deux lignes, corps `inter(17)` à 0,58. On garde **Inter** (tranché). Arrivée
en `ArriveeFloue`, titre puis corps, comme la page des gains.

**La pièce.** `PieceSprite(.argent)` à ~220 pt, ancrée en bas à droite et
**coupée par le bord** — une pièce entière posée dans un coin fait vignette,
une pièce qui déborde fait décor. Cases de 320 px : elle tient. Immobile, ou
la `Levitation` de la maison ; pas de rotation permanente (bruit).

**Le retour.** Le chevron **et** le drag vers le bas — la même fermeture que
la page des gains (`gesteFermer` : armé, chien de garde, plus de zone tactile
une fois fermée). Retour au coffre **sur la page noire**, sans rejouer la
vidéo.

### 28.4 ⚠️ CE QUE ÇA CHANGE DANS L'ARCHITECTURE DE LA PAGE

1. **Le tap sur l'objet change de sens sur une page.** Aujourd'hui, taper
   l'objet ouvre la LOUPE (il grossit, lévite). Sur la page noire, le même
   geste ouvrirait la vidéo. **Même geste, deux résultats selon la page** —
   c'est le genre d'incohérence qu'on paie en confusion. Deux options :
   - **(a)** sur la page noire, le tap = l'histoire, et la loupe n'y existe
     pas (le sachet fermé n'a rien à montrer de près) — **recommandé** ;
   - **(b)** un point d'entrée dédié (la pill de prix devient tapable, ou un
     petit ⓘ) et la loupe reste partout.
2. **C'est la première SOUS-PAGE du coffre.** Comme la page des gains : en
   OVERLAY, pas en `sheet` (le coffre est un `fullScreenCover`, une feuille
   dessus donne la poignée grise), avec **la garde sur `gestePage`** — sans
   elle, un doigt sur la page ferait tourner le manège derrière (le bug du
   §19.4, déjà payé une fois).
3. **La vidéo, une fois ou à chaque fois ?** Une cinématique de 8 s à chaque
   tap devient un péage dès la troisième visite. Recommandation : **à chaque
   fois, mais passable d'un tap** — et si on la trouve lourde, un « vue une
   fois » en `UserDefaults` la saute d'office ensuite. À trancher au doigt.
4. **Le booster orange** n'a pas cette page. Il pourrait l'avoir plus tard
   avec `video_booster.mp4` (déjà dans les téléchargements) — la structure
   doit accepter une robe en paramètre dès le départ, pas être écrite pour le
   noir seul.

### 28.5 L'ORDRE

1. Le pied : descriptions, boutons retirés, titre court — **sans risque**.
2. Recuire la vidéo (format, poids, son en `.ambient`), et vérifier sur
   quelle image elle se coupe.
3. La page (header fondu, texte, pièce, chevron, drag) — en overlay, avec la
   garde.
4. Le tap sur l'objet noir → vidéo → page, avec « Passer ».
5. Banc `-coffreStoryNoir` pour arriver directement sur la page.
6. **Juger au doigt** : le passage vidéo → page, la pièce coupée, la
   lisibilité du header sur l'arche.

### 28.6 CODÉ — le pied, la cinématique, la page

**Le pied.** Une DESCRIPTION sous le compte, une phrase par page, sans tirets
(verdict explicite). Les boutons mats des deux pages de PIÈCES disparaissent :
« 60 COINS TO GO » doublait la pill, « A RARE DROP » était une description
déguisée en bouton. Et « legendary boosters » devient **« legendary »** — le
sachet est sur le socle, il n'a pas besoin qu'on lui dise ce qu'il est.

**Les cinématiques.** `bake_story.py` recuit les deux sources à la taille de
l'écran :

| | source | recuit |
|---|---|---|
| noir | 2160 × 3840 · 19 Mo | 1206 × 2622 · **7,9 Mo** |
| lune | 2160 × 3840 · 16 Mo | 1206 × 2622 · **5,7 Mo** |

⚠️ **La piste audio est CONSERVÉE** (copiée, jamais ré-encodée) : toutes les
boucles de l'app sont muettes, une cinématique peut parler. Mais
`AVAudioSession` en **`.ambient`** et jamais `.playback` — sinon un coffre
ouvert dans le métro fait du bruit.

**Le deuxième tap.** Verdict : *« à la tap il peut ouvrir une loupe de base,
c'est à la deuxième tap »*. Premier tap la loupe, deuxième l'histoire. Le même
geste ne change pas de sens selon la page : **il va plus loin**. Sur une
pièce, le deuxième tap referme la loupe comme avant — une pièce n'a pas
d'histoire à raconter.

⚠️⚠️ **PIÈGE PAYÉ : UN DRAPEAU À VALEUR NE SE LIT PAS DANS
`CommandLine.arguments`.** `-coffreStory noir` ne s'est jamais déclenché, et
**sans la moindre erreur** : iOS parse les paires `-clé valeur` dans le
domaine d'arguments de `UserDefaults`. La maison l'avait déjà payé sur
`-coffrePage` (d'où le helper `nombre(_:)`) et je ne l'ai pas relu. La page ne
s'ouvrait pas, le drapeau était nil, rien ne le disait.

### 28.7 CODÉ — le récit qui défile, et le bouton en moins

Verdict du 29-08 : *« dans la page de détail des boosters : fais un texte à
apparition Apple cinématique blur, rajoute plus de texte, et fais un scroll
blur très premium · pareil pour la page détail booster Lune · et enlève le
bouton passer, car on peut taper dessus et ça enlève »*.

**Le header ne défile pas, le texte oui.** Un sachet qui monterait avec le
texte redeviendrait une illustration d'article ; fixe, il reste l'objet dont
on parle, et le texte passe DESSOUS. ⚠️ **C'est ce passage sous le fondu qui
fait le premium — pas un effet ajouté, une profondeur.**

Quatre paragraphes par robe, chacun arrivant dans le flou (`ArriveeFloue`, un
rang de retard par bloc). ⚠️ Le masque du haut est OBLIGATOIRE : sans lui la
première ligne apparaît d'un coup au bord du header, comme coupée au couteau.
⚠️ Et le rayon retombe à **zéro exact** — un `.blur` même minuscule force une
passe hors écran à chaque image, et sur un `ScrollView` c'est à chaque image
de DÉFILEMENT.

**Le bouton « Passer » disparaît.** Je l'avais mis au nom de « une porte doit
être visible ». Mais ici **la porte, c'est tout l'écran** : n'importe quel tap
passe. Un bouton qui double un geste déjà universel n'ajoute qu'un objet à
regarder pendant un film.

**« Mes gains » repasse à gauche.** Il était calé sur la colonne de texte des
lignes pour donner un seul axe vertical — mais **quand la liste est vide il
n'y a plus de colonne à quoi s'aligner** : il ne reste qu'un titre poussé vers
la droite sans raison. ⚠️ *Un alignement qui dépend d'un contenu absent n'est
pas un alignement.*

### 28.8 VÉRIFIÉ — et deux mesures m'ont retenu de « corriger » du vide

**Les deux pages marchent**, cinématique comprise. Séquence mesurée sur le
banc `-coffreStory lune` (luminance du haut et du bas de l'écran) :

| | haut | bas | |
|---|---|---|---|
| +9 s | 24,3 | 19,0 | le coffre |
| +12 s | 1,2 | 1,8 | **la cinématique** |
| +15 s | 2,5 | 11,3 | **la page** |

⚠️ **MA PREMIÈRE CAPTURE MONTRAIT UN TEXTE FANTÔME, ET CE N'ÉTAIT PAS UN
BUG** — les mots se chevauchaient parce que j'avais capturé PENDANT la
cascade d'arrivée. Vérifié en comparant deux captures à trois secondes
d'écart : l'écart tombe à **2,0 sur 255**, la page est posée et le texte est
net. J'ai failli aller « réparer » une animation qui marchait.

⚠️ **ET UNE CAPTURE À 24 s MONTRAIT LE COFFRE AU LIEU DE LA PAGE** — un
enchaînement `terminate` + `launch` trop serré, pas un défaut de l'app. La
séquence mesurée ci-dessus le prouve. **Une capture qui contredit une mesure
est d'abord suspecte elle-même.**

**Ce qui était un vrai défaut : la pièce mordait sur le texte.** Posée à
0,90 / 0,94 en pleine lumière, ses anneaux clairs traversaient le gris du
troisième paragraphe. Comme le texte DÉFILE, la collision était certaine à un
moment ou à un autre : il fallait qu'elle cesse d'être un objet pour devenir
une lueur. Reculée à 1,02 / 1,02 et baissée à 0,5 :

| | L moyenne du coin | pixels > 120 |
|---|---|---|
| avant | 36,1 | 30 827 |
| après | **14,5** | **11 806** |

Deux fois et demie moins de lumière sur la zone de lecture.

---

## 29. PLAN : LA GRAMMAIRE D'OPAL — le nom, la pill en bas, la barre fine (30-08, relu par quatre juges)

**Rien n'est codé.** Verdict de Kathryn, avec sa capture d'Opal (« Gem
Ambitieuse ») en référence :

> *« enlève le titre de l'asset (exemple Booster), en place police 14 dégradé
> et en dessous une petite phrase en une ligne sans tiret : qu'est-ce que
> c'est. Exemple pour la pièce Or : "Or Piece" et description "sert à ouvrir un
> Booster Lune" (booster lune = le booster orange). Et à la place de "60 coins"
> en bas tu mets la pill avec la mini pièce et le nombre, et en dessous une
> petite progress bar très fine comme Opal (+10 prévu dans 24 h, avec la
> récompense journalière). Pareil pour le booster Lune : enlève la pastille du
> haut, mets le titre et le sous-titre. Et tu mets la petite pastille avec le
> nombre et le mini booster, et en dessous une mini progress bar avec le
> nombre de pièces manquant 60/100, et tu gardes le bouton primaire Open ! Je
> veux le nom. »* — puis : *« et bouton Ouvrir pas en majuscules, juste le O »*.

> ⚠️ **Ce §29 a été démoli par quatre juges adverses** (fidélité / technique /
> backend / dessin) puis chaque grief re-vérifié par un sceptique : **10 griefs
> tenus, 0 réfuté**, 12 non vérifiés relus à la main. Les trois qui changent
> tout : (1) **une autre session a tranché le versement quotidien AVANT ce
> plan** — Claim au tap, minuit Paris, `retour_disponible` rendu par le
> serveur — et sa migration est déjà dans l'arbre ; (2) **« Ouvrir, juste le
> O » est déjà dans HEAD** (`9a7c429`, 18:25, cinq minutes après la première
> version de ce §29) ; (3) ma lecture « nom en haut » et mes capitales espacées
> n'étaient pas ses mots. Tout ce qui suit est la version corrigée.

### 29.1 Ce qu'elle demande, page par page — et DEUX lectures, pas une

| | page OR (1) | page LUNE (2) |
|---|---|---|
| **le nom** — 14, dégradé · **une phrase** d'une ligne, sans tiret | « Pièce Or » · *Sert à ouvrir un Booster Lune.* (ses mots) | « Booster Lune » · une phrase à valider (§29.5) |
| **l'objet** | inchangé | inchangé |
| **la pill** | **mini pièce + le solde** | **mini sachet + le nombre de sachets** |
| **la barre très fine** dessous | le versement quotidien, *« +10 dans N h »* | la jauge du prochain sachet, *« 40 / 100 »* |
| **le bouton** | aucun (comme aujourd'hui) | **« Ouvrir »** — gardé ; la casse est déjà faite (§29.9) |

**Où vont le nom et la phrase — deux lectures, et sa phrase n'en exclut
aucune :**

- **(A) EN HAUT, à la place de la pill de prix** (0,222 H, `PillPrix`,
  `CoffreV2.swift:3167-3175`) — c'est la grille d'Opal (titre à 0,139 H,
  §29.3), c'est « enlève la pastille du haut, mets le titre et le
  sous-titre », et c'est « je veux le nom » en position de nom.
  **Recommandé.**
- **(B) DANS LE PIED, à la place de « BOOSTER » / « COINS »** — la lecture
  littérale de *« enlève le titre de l'asset… en place police 14 »* : le
  titre de l'asset, c'est l'étiquette du pied (`Text(v.mot.uppercased())`,
  `:1380`), « en place » = à sa place ; la pill et la barre dessous, rien à
  0,222 H. ⚠️ Le pied ne tient plus dans 320 × 196 : nom 17 + 5 + phrase 18
  + 12 + pill 44 + 12 + barre 3 + 16 + légende 18 + bouton 58 = **203 > 196**
  → `podFin + 103` et `PiedCoffre.taille` à recoter.

Sa phrase sur la page Lune ne dit ni « à la place », ni « en haut ». Le §29
est écrit pour **A** ; **② et §29.4 sont conditionnels à sa réponse**
(§29.14, question 0).

Le « 60 coins » et le « 60/100 » de son message sont **les nombres de SON
téléphone** (solde 60 → jauge 60 / 100), pas une consigne de calcul : la
jauge garde la forme tranchée au §27 — `courant / prix` — et non « ce qui
manque » (§26.2 : « 60 to go » a déjà été jugé illisible). ⚠️ À confirmer
d'un mot si elle voulait vraiment le manque (§29.14).

### 29.2 L'état d'aujourd'hui — mesuré sur le sim kat-coffre, ET CE QUI A BOUGÉ DEPUIS

Captures `refs/s29-or-avant.png` / `refs/s29-lune-avant.png` (402 × 874 pt,
build **18:10**) ; Opal : `refs/s29-opal-ref.png`.

| élément | page OR | page LUNE | où dans le code (HEAD `9a7c429`) |
|---|---|---|---|
| pill du haut, centre 0,222 H = **194 pt** (172 → 216) | `🪙 1240` (pas de « / ») | `🪙 40 / 100`, liquide à 40 % | `PillPrix`, `:1208` ; posée `:3167-3175` |
| barre de crans | **604 pt** | idem | `barreDeCrans`, `:3181` |
| pied, cadre 320 × 196 centré à `podFin + 103` = **728 pt** (630 → 826) | « **1 240** COINS » (40 + 15 caps, tracking 1,5) · *20 coins for every set you finish.* | « **1** BOOSTER » · *Won after every session, or bought for 100 coins.* · bouton | `PiedCoffre`, `:1309` ; `haut` `:1368-1397` ; `variantes`, `:2382-2435` |
| bouton | — | `DiamondPrimaryButton(title: "OUVRIR")`, 58, ancré en bas | `:1426`, texte `:2408` |

**Trois faits, dont deux ont changé pendant qu'on capturait :**

1. ⚠️ **« Ouvrir, juste le O » EST DÉJÀ FAIT — dans HEAD, pas dans la
   capture.** Commit `9a7c429` (30-08 **18:25**, l'autre session) : *« LA
   CASSE DES BOUTONS : UNE PHRASE — la première lettre en majuscule, le
   reste en minuscules, le « Locked » compris »*. `String.enPhrase`
   (`BoutonPrimaire.swift:181-184`) est appliqué par `BoutonPrimaire`
   (`:156`, à 18 semibold, tracking **−0,2** `:157-158`) — dont
   `DiamondPrimaryButton` n'est qu'une coquille
   (`ConnexionButtonLab.swift:159-162`) — et par le mat du verrouillé du
   coffre (`CoffreV2.swift:1439`). « OUVRIR » se rend donc déjà « Ouvrir »,
   « LOCKED » déjà « Locked ». **La capture `s29-lune-avant` (18:20, build
   18:10) précède ce commit** : elle est à refaire sur HEAD avant tout
   verdict, et « Ouvrir » sort du périmètre de ce plan.
2. **Le remplissage de la pill (`remplie`, 0 → 1 à l'arrivée) est la seule
   chose qui bouge sur la page posée** (`:1645-1648`) — il migre dans la
   barre. Sa courbe réelle : `.spring(response: 0.80, dampingFraction:
   0.75).delay(0.45)` (`:2690-2691`), pas « 0,6 s ».
3. ⚠️⚠️ **LE « +10 » A ÉTÉ TRANCHÉ AUTREMENT, AVANT CE PLAN, ET LA MIGRATION
   EST DÉJÀ ÉCRITE.** `tools/annonces/PLAN-COFFRE-ANNONCES.md` (commit
   `168f548`, 17:58) §0 :23 — *ses mots, rien de déduit* : **« bouton Claim
   dans la pop-up, chaque jour à minuit chez elle (pas UTC) ; les +10
   partent au tap »** ; §5.3 :276-281 : `reglerRetourQuotidien()` quitte le
   `scenePhase`, la home lit `etat_coffre().retour_disponible`, Claim poste
   `.retourQuotidien`, **le marqueur UTC local disparaît**. Loi écrite depuis
   dans `.claude/skills/woop-backend/SKILL.md:190-199` : *le jour est une
   clé serveur, `fuseau_jour` — jamais le fuseau du client*. Et
   **`supabase/migrations/20260830210000_conversion_jour_flamme.sql`** (dans
   l'arbre, `??`, **ni commitée ni déployée** — le sceptique a sondé le
   compte de test : `etat_coffre` rend encore 7 clés) fait déjà sortir
   `jour`, **`retour_disponible`**, **`retour_prochain`** (le prochain minuit
   Paris, calculé AU SERVEUR) et `flamme` (`:423-431`), sur `jour_courant()`
   = `(now() at time zone fuseau_jour())::date` (`:40-56`). **Seul le
   MONTANT `pieces_retour_quotidien` manque** à cette fonction (grep : 0).
   Le 10 en dur de `ExerciseDetailView.swift:2270` est condamné par le §5.3
   de ce même plan.

   ⚠️ **Et cette migration CONVERTIT** : à 100 pièces un sachet naît tout
   seul (`convertir_pieces`, `:85-121`, déclencheur sur tout crédit jaune),
   **les pièces retombent** ; `claim_booster` est fermée (`:439-441`) et
   `acheterBooster()` part (§5.4). Conséquence pour NOS deux pages : **une
   fois M1 posée, `solde_or < 100` toujours, donc `reste == solde`** — la
   pill de la page OR (« 40 ») et la barre de la page Lune (« 40 / 100 »)
   disent le MÊME nombre. Ce n'est pas un défaut, c'est sa demande (« la
   jauge : les pièces retombent ») ; mais il faut le savoir en dessinant.

### 29.3 Opal, mesurée (sa capture, 1179 × 2556, écran 393 × 852 pt) — re-mesurée par le juge dessin

| élément | mesure |
|---|---|
| titre | haut à **0,139 H**, hauteur de capitale 16 pt → corps ≈ **23**, semibold, blanc plein, **casse de phrase** |
| sous-titre | **2 lignes**, ≈ 17, gris sur les fûts **(176,183,186) ≈ blanc 0,69**, **14 pt** sous le titre |
| pill « Obtenue par 93 % » | centre **0,266 H**, **≈ 30 pt** de haut (la nôtre fait 44), texte teinté (184,247,230) |
| objet | **0,315 → 0,61 H** ; **102 pt d'air** entre l'objet et la barre |
| **la barre** | **3,0 pt** · **249 pt** de long (0,633 W, marges 72) · centre **0,732 H** · rail **(23,27,26)** ≈ blanc 0,10 sur du noir à ZÉRO · remplie à **60 %** |
| son remplissage | dégradé **(180,223,247) → (183,252,225)** : bleu pâle → menthe, **jamais sous L 220** — clair de bout en bout, aucun pouce, aucune tête |
| légende « 6/10 heures » | **16 pt** sous la barre, corps ≈ **17** (chiffre de 11,7 pt de haut), gris (147,157,155) ≈ 0,60 |
| bouton « Verrouillée » | haut à **0,80 H**, ≈ 46-52 de haut (seuil), fond (17,20,19), label (84,93,91) ≈ 0,35, marges 32 |

**Ce qui fait que SA barre marche, alors que les nôtres ont été jetées quatre
fois (§26.4, §27.1)** : elle est **fine** (3 pt : un trait, pas un objet), son
remplissage est **clair partout** (le dégradé va d'un clair à un autre clair —
l'œil ne trouve pas d'arrêt sombre à lire, la faute du §26.4 ②), **sans
pouce**, sur **un sol noir absolu**, avec **une légende DESSOUS, à 17** (pas à
côté : posée sous, elle se lit comme sa valeur — §25). Elle n'est pas
« premium », elle est **discrète** ; le premium est ailleurs. C'est ça qu'on
copie.

> ⚠️ Le §27 avait écrit *« une barre est plate par nature, on la remplace »*.
> C'est Kathryn qui la rétablit, avec un modèle sous les yeux — et le modèle
> tient parce qu'il ne demande PAS à la barre d'être belle. On ne rejoue pas le
> §26.4 : pas de dégradé sombre, pas de tête, pas de 5 pt.

### 29.4 L'anatomie proposée (lecture A) — cotes sur 402 × 874

```
   63 ┌ ‹  Rewards                                 ≡ ┐   (inchangé)
      │                                              │
  174 │               Pièce Or                       │  ← le nom : 14 semibold, casse de phrase, dégradé
  196 │        Sert à ouvrir un Booster Lune.        │  ← 15 medium, blanc 0,62, UNE ligne
      │                                              │
      │                 ( l'objet )                  │  haut mesuré : sachet 280 pt · pièce 323 pt
      │                                              │
  604 │                ● ○ ○ ○                       │  (crans, inchangés)
  630 │           ╭──────────────────╮               │
      │           │ 🪙  1 240        │               │  ← la pill descend (verre .clear, plus de liquide)
  674 │           ╰──────────────────╯               │
  686 │      ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬░░░░░░░░░░░░░░         │  ← 3 pt, 240 de long, rail blanc 0,10
  705 │              +10 dans 6 h                    │  ← 15 medium, blanc 0,60, 16 pt sous la barre
      │                                              │
  768 │      ┌──────────────────────────────┐        │
      │      │            Ouvrir             │        │  ← page LUNE seulement ; 58, ancré en bas
  826 │      └──────────────────────────────┘        │
```

- **Le bloc du haut** remplace `PillPrix` à la MÊME cote (centre 0,222 H) :
  nom (≈ 17 de ligne) + 5 + phrase (≈ 18) = **40 pt** (174 → 214), la hauteur
  de la pill qu'il remplace. **Mesuré** (juge dessin, PIL sur les captures) :
  le haut du sachet est à **280 pt**, celui de la pièce à **323 pt** — même
  un titre à la Opal (23 + 5 + 15 = 51 pt, 168 → 220) laisserait **60 pt
  d'air**. Le choix 14 / 23 est un choix de ROBE, pas de place.
- **Le pied garde son cadre 320 × 196 et son ancre** (`podFin + 103`) — la
  grille unique du §25.6 tient : pill 44 → 12 → barre 3 → 16 → légende ≈ 18
  → `Spacer` → bouton 58 = **151 ≤ 196**. Sur les pages sans bouton, le
  `Spacer` absorbe, comme aujourd'hui.
- **La légende à 15 medium** (la taille de la phrase du pied, `:1405`), pas
  13 : le registre des légendes iOS (11-13) a déjà été jugé « trop petit,
  pas Apple » sur ce pied même (`:1370-1375`), et Opal est à 17.
- **La barre fait 240 pt** (0,60 W) — Opal 0,63 ; 40 pt de marge dans le cadre
  de 320. 3 pt, capsule, deux fois plus longue que la pill : c'est l'axe du
  composant, la pill est posée dessus.

### 29.5 Les textes — quatre pages, une seule grammaire

| page | le nom (14, dégradé, casse de phrase) | la phrase (15, une ligne, sans tiret) | la pill | la barre |
|---|---|---|---|---|
| 1 · pièce d'or | **Pièce Or** | *Sert à ouvrir un Booster Lune.* — **ses mots** | 🪙 or **1 240** | *+10 dans 6 h* |
| 2 · booster Lune | **Booster Lune** | *Un sachet de cartes du set Lune.* — **à valider** | sachet orange **1** | *40 / 100* |
| 3 · pièce d'argent | **Pièce Argent** | *Sert à ouvrir un Booster Légendaire.* | 🪙 argent **0** | *(pas de barre — §29.10)* |
| 4 · booster noir | **Booster Légendaire** | *Une carte légendaire, garantie.* | sachet noir **0** | *(pas de barre — §29.10)* |

- **Le nom, à la lettre** : elle a écrit « Or Piece » — **casse de phrase,
  tracking nul**, pas des capitales. Deux commits d'aujourd'hui le disent
  aussi fort qu'elle (`c56db68` 18:01 *« plus de capitales »*, `9a7c429`
  18:25 *« la première lettre en majuscule et le reste en minuscules, normal
  quoi »*). Les capitales espacées de la première version de ce plan
  reprenaient la grammaire exacte de l'étiquette qu'elle demande d'enlever
  (`:1380-1392`, 15 semibold tracking 1,5). Elles restent une alternative
  nommée (§29.14), pas la reco.
- **Seule la phrase de la page OR est la sienne.** Celle de la page Lune ne
  peut pas dire « une carte » : le code de cette page refuse d'écrire le
  nombre de cartes d'un sachet (`:2169-2171`, *« on ne l'invente pas ici »*)
  et le récit dit « a hand » (`:2183`). ⚠️ Or le serveur scelle **une**
  `card_id` par sachet (`user_boosters`, forge-card rejouée rend la même
  carte — site `b-fo-garantie-legendaire-du-sachet-noir`) : le récit et le
  commentaire sont en désaccord avec la base. Ce n'est pas ce plan qui
  tranche ; la phrase proposée n'affirme aucun nombre.
- ⚠️ **La langue.** La page est en anglais (« Rewards », les descriptions, les
  récits `:2172-2187`) et son bouton en français. Ses exemples sont en
  français. **Reco : français sur ces quatre lignes** ; « Rewards » et les
  récits ne bougent pas dans ce lot. À trancher d'un mot (§29.14).
- **Une ligne, garantie** : `lineLimit(1)` + `minimumScaleFactor(0.85)` sur
  320 pt. La plus longue (« Sert à ouvrir un Booster Légendaire. », 35
  caractères à 15 medium ≈ 250 pt) tient sans réduire — le facteur est un
  filet, pas un réglage.

### 29.6 Le nom à 14 en dégradé — la loi du dégradé, et un piège mesurable d'avance

Le dégradé de la maison est `WoopGradient.titleFade` (`Theme.swift:170-179`) :
blanc → 0,25 en diagonale, **fait pour un titre de 30** — le commentaire du
fichier prévient : *« on s'arrête à 0,25 — plus bas, les dernières lettres
cessent d'être lisibles »*. ⚠️ **Sur une seule ligne de 14 pt, la diagonale
devient quasi horizontale et les dernières lettres tombent à 0,25 sur 60 pt
de course : « Pièce Or » finit en « Pièce O_ ».** Mesuré nulle part encore →
c'est le premier point à capturer (luminance du dernier glyphe : sous L 90 sur
le noir, le nom est tronqué à l'œil).

**Reco** : un `etiquetteFade` court, blanc 1,00 → 0,55, même diagonale — le
« dégradé » est là, la dernière lettre reste au-dessus du seuil. Corps **14
semibold, casse de phrase, tracking normal** (§29.5). Alternatives nommées :
14 en capitales espacées (l'étiquette) · 23 semibold blanc plein à la Opal —
**qui tient à la même place** (§29.4 : 60 pt d'air), donc un choix de robe.

### 29.7 La barre de la page OR = le versement quotidien — SUR LA DÉCISION DU 30-08, pas sur l'ancien UTC

**Ce qui est tranché, et par qui** (§29.2 fait 3) : *bouton Claim, minuit chez
elle, les +10 partent au tap* — `PLAN-COFFRE-ANNONCES.md:23`, `§5.3 :276-281`,
loi `woop-backend:190-199`. Le jour est `jour_courant()` dans `fuseau_jour`
(Europe/Paris), **une règle serveur** ; l'échéance est **rendue** par le
serveur : `etat_coffre().retour_prochain` (timestamptz) et
`retour_disponible` (M1 `:423-431`). **L'app ne calcule aucun jour, aucun
minuit** — ni UTC, ni local. À Paris 18 h, le prochain versement est à minuit
Paris : **« +10 dans 6 h »**.

**Les deux états de la barre**, et rien d'autre :

| état (`retour_disponible`) | remplissage | légende |
|---|---|---|
| **`false`** — versé aujourd'hui | l'horloge : `1 − (retour_prochain − now) / 24 h` (18 h Paris → **0,75**) | *+10 dans 6 h* (heures entières ; sous 1 h : *dans 40 min*) |
| **`true`** — à réclamer | **1,00** — il est dû | *+10 à réclamer* — **c'est la card Welcome Back et son bouton Claim qui paient** (§5.3), jamais la barre, jamais « la connexion » |

Ce n'est pas une jauge vers quelque chose qu'on gagne par l'effort : c'est
une **horloge**, et elle ne promet que ce que `claim_retour_quotidien()` fait.

⚠️ **Tant que `WoopApp.swift:83-92` poste encore au premier plan** (la porte
Claim du §5.3 n'est pas codée), « à réclamer » ne se verra qu'hors ligne ;
après la porte, c'est l'état normal du matin. La barre est juste dans les deux
mondes parce qu'elle lit `retour_disponible` et rien d'autre.

⚠️ **Le passage de minuit** : la page ouverte à 00 h 05 Paris a un
`retour_prochain` dépassé et un `retour_disponible` périmé. Règle : quand
`now ≥ retour_prochain`, la barre passe à l'état « à réclamer » **localement**
jusqu'à la prochaine lecture d'`etat_coffre()` — c'est le `TimelineView` qui
bat la minute qui porte ce test (§29.11 ④). Jamais une horloge neuve à
« dans 24 h » sur un versement dû.

**Ce qu'il faut pour la dessiner sans mentir — et ce que ce plan NE fait PAS :**

1. **Lire** `retour_disponible`, `retour_prochain` (et `jour`) dans
   `SacreServeur.EtatCoffre` → `EconomieWoop`. **Décodés, jamais calculés.**
2. **Le montant** : `pieces_retour_quotidien` doit sortir de `etat_coffre()`
   — le seul manque réel de M1. **Ce plan ne touche pas M1** (c'est le
   fichier de l'autre session, non commité) : le champ s'ajoute soit à M1
   avant sa pose (à négocier avec elle), soit dans une migration **ordonnée
   APRÈS `20260830210000`** qui repart de SON corps (`:389-433`), jamais de
   `20260830160000:435-469`. ⚠️ Deux `create or replace` sur la même
   fonction depuis deux chantiers : celui qui passe en dernier efface
   l'autre — c'est pour ça qu'il n'y a PAS de migration « §29 » parallèle.
3. **Aucun helper de jour côté app.** Le marqueur `woop.retour.dernierJourUTC`
   (`SacreServeur.swift:286-289`) est condamné par §5.3 ; on ne construit
   rien dessus.
4. **La maquette** (`-demoData`, pas de compte : `EconomieWoop.possible`
   faux, `:153-157`) : `retourDisponible = false`, `prochainRetour` = un
   minuit fictif à +6 h, l'horloge tourne — une maquette qui dirait « à
   réclamer » pour toujours serait un mensonge de banc.

⚠️ **Le site, dans le même commit que la migration qui ajoute le montant** :
`b-fn-etat-coffre` (`serveur.ts:21` — le `quoi` passe aux clés de M1 + le
montant, la `preuve` = la sonde rejouée, réponse LUE) ;
`b-rg-pieces-retour-quotidien` (`:39`) **reste 🟢**, seule sa `preuve` gagne
le lecteur côté app ; `b-fn-claim-retour-quotidien` (`:25`, le `quoi` sous la
décision au tap) ; `b-rg-le-versement-lui-part-vraiment` (`briques.ts:37-38`,
litige « au tap / Paris » → la barre s'y conforme) ; `m-trancher-le-fuseau-du`
(`mesures.ts:10`, sa `lecture` change quand M1 est posée) ; et une brique
nouvelle « la barre du versement » — 🔵 tant que l'écran ne lit pas, 🟢 après
capture. `npm run verif && npm run artefact`, republication au même lien.

### 29.8 La pill du bas — `PillPrix` descend, perd son liquide, garde son verre

C'est le composant existant, déplacé : `.clear` (jamais `.regular` — donc
**pas la recette de `PillBooster`**, `BoosterPopup.swift:813`, qui est en
`.regular` teinté, l'interdit de la maison), liseré 0,13, ombre. Ce qui
change :

- **le remplissage liquide meurt** (il va dans la barre) → `part` et
  `remplie` quittent la pill ; elle ne porte plus qu'**un glyphe et un
  nombre** ;
- **le glyphe dépend de l'objet** : `PieceSprite(planche:, tour: 0,
  diametre: 22)` sur les pages de pièces, **`SachetVignette(largeur: 15,
  hauteur: 26, robe:)`** sur les pages de sachets — les 15 × 26 de la pill du
  profil, un objet déjà validé à cette taille ;
- **le nombre** : le solde (pièces) ou le compte de sachets, 17 semibold,
  `numericText` — celui qui vivait en 40 dans le pied et qu'on ne voit plus
  qu'ici : **un nombre, un endroit** ;
- ⚠️ **le défaut connu reste** (§27.6) : à 22 pt les deux pièces ne se
  distinguent pas (R−B +20 contre +1, même croissant). Le nom (« Pièce
  Argent ») le compense — une raison de plus de vouloir le nom. À remesurer
  sur capture.

⚠️ **Le verre `.clear` dans le pied est posé sur du NOIR ABSOLU.** La loi dit
que `.clear` convient au contenu doux ; ici il n'y a RIEN dessous — un verre
sur du noir n'a rien à réfracter (`HomeNuit:536-542`, le galet refusé). Il
peut lire « plat ». Repli déjà validé dans la maison : la recette de
`PiecesNotif` (`PlayerSeance.swift:291-302`) — noir 0,35 + `.clear` derrière +
liseré 0,12. À juger sur capture, pas d'avance.

### 29.9 Le bouton — « Ouvrir » est fait ; reste le MOT du verrouillé, et un tracking à trancher

- **La casse** : imposée par le composant depuis `9a7c429` (§29.2 fait 1) —
  changer la chaîne `"OUVRIR"` (`:2408`) est un no-op cosmétique. **Hors
  périmètre.**
- ⚠️ **Le MOT du verrouillé** : `enPhrase` rend `"\(prix − reste) COINS TO
  GO"` (`:2409`) en « 60 coins to go » et `"LOCKED"` (`:2432`) en « Locked ».
  Avec la barre « 40 / 100 » à 50 pt au-dessus, « 60 coins to go » est **la
  redondance du §26.2 qui revient** ; et sous M1 l'achat n'existe plus (§5.4 :
  *« le pied n'a plus que Ouvrir, le "N coins to go" devient la jauge »*).
  → le mat dit **« Verrouillé »** (Opal : « Verrouillée ») sur la page Lune à
  zéro sachet comme sur la page noire. Une langue, un mot.
- ⚠️ **Le tracking des deux états n'est PAS le même** : le primaire est à
  −0,2 / 18 semibold (`BoutonPrimaire.swift:157-158`), le mat à **1,6 / 15**
  (`CoffreV2.swift:1440-1441`). Même casse depuis ce matin, pas même
  lettrage : deux états d'un composant doivent partager le lettrage. **Reco :
  aligner le mat sur le primaire** (−0,2 / 18) — c'est le composant qui
  commande, pas la capsule mate.
- Priorité haute, action vide, `highPriorityGesture` : inchangés
  (`:1413-1429`), c'est la loi des gestes de cette page.

### 29.10 Les pages 3 et 4 — pas demandées, mais la grille ne se fait pas à moitié

*« Une seule grille pour les quatre pages »* (§25.6) : on ne pose pas deux
grammaires sur un manège qui se feuillette.

- **Page argent** : nom + phrase ; pill 🪙 argent **N** ; **pas de barre** —
  la loi du §3 tient toujours : la pièce TOMBE (p ≈ 1/30, pitié 45, cooldown
  10, `cloturer_seance`), une jauge exposerait le *pity timer* et rendrait la
  rareté farmable. Le créneau reste vide, le `Spacer` absorbe ; pas de bouton.
- **Page noire** : nom + phrase ; pill sachet noir **N** ; **pas de barre non
  plus** — rien ne s'accumule VERS le sachet noir, il naît d'une pièce
  entière, et une barre `courant / 1` écrirait **« 2 / 1 »** avec deux pièces
  d'argent (`boostersNoirs = argent + noirsOuverts`, `EconomieWoop.swift:94`,
  cible 1 à `:2428`). La pill porte le compte, le bouton « Ouvrir » /
  « Verrouillé » dit s'il y en a un.

### 29.11 Ce que ça change dans le code — nommé, pour que le type-checker ne morde pas

⚠️ **`CoffreV2.swift` est PARTAGÉ** : l'autre session y a commité `9a7c429`
à 18:25 (`:1435-1439`, le mat en `enPhrase`) cinq minutes après la première
version de ce plan. Le plan se relit contre HEAD `9a7c429` ; skill
architecture §10 : `git diff HEAD` avant tout commit, chemins et hunks
explicites, on ne touche pas à son hunk, jamais `git add -A`.

| # | où | quoi |
|---|---|---|
| ① | `PiedVariante` (`:1268-1307`) | gagne `nom: String` ; `mot` meurt ; `pill: PillPrix.Contenu?` devient `compte: CompteObjet` (glyphe + nombre) et **`jauge: Jauge?` qui porte des DONNÉES, pas des valeurs rendues** : `enum Jauge { case compte(courant: Int, cible: Int) ; case horloge(montant: Int, disponible: Bool, prochain: Date?) }` (entrées stables, loi §2.3 — jamais une closure, jamais un `part` calculé dans `variantes`) ; `bouton` garde `(mot, actif)` |
| ② | nouveau `EnTeteObjet: View` **(lecture A)** | nom + phrase, `.id(piedIdx)` + `.transition(.opacity)`, posé à `sc.H * 0.222` à la place de `PillPrix` (`:3167-3175`) ; `.opacity(pageOp * texteOp)` gardé |
| ③ | `PillPrix` → `PillCompte` | sans `part`/`remplie` ; le glyphe en `enum` (pièce / sachet) — deux `if` nommés, pas une expression |
| ④ | nouveau `BarreFine: View` | rail `Capsule` blanc 0,10 + remplissage `Capsule`, 240 × 3, dégradé clair → clair ; **`animatableData = remplie`** seule (l'arrivée, même transaction que `remplie` aujourd'hui : `.spring(0.80 / 0.75).delay(0.45)`, `:2690-2691`) ; largeur rendue = `part × remplie`. **`part` et `legende` se calculent DANS la vue** : `.compte` → statique ; `.horloge` → enveloppé dans `TimelineView(.periodic(from:by: 60))`, `part` et légende dérivés de `context.date` et de `prochain`, et le test « `now ≥ prochain` → à réclamer » (§29.7). La page n'est pas relue. |
| ⑤ | `PiedCoffre` (`:1347-1361`) | `haut` et `description` meurent ; `pill` · `barre` · `Spacer` · `bouton` — quatre propriétés nommées ; le mat aligné sur le lettrage du primaire (§29.9) |
| ⑥ | `variantes` (`:2382-2435`) | les quatre textes du §29.5 ; « Verrouillé » à `:2409` et `:2432` ; **ne calcule ni `part` ni légende** |
| ⑦ | `EconomieWoop` | `piecesRetourQuotidien: Int` (lu), `retourDisponible: Bool` et `prochainRetour: Date?` **décodés, jamais calculés** ; `appliquer(RetourQuotidien)` pose `retourDisponible = false` ; la maquette pose `false` + un minuit fictif |
| ⑧ | `SacreServeur.EtatCoffre` | trois clés : `pieces_retour_quotidien` (Int), `retour_disponible` (Bool), `retour_prochain` (ISO 8601 → un lecteur `Date` à côté de `n(_:_:)`, `:84`). ⚠️ **Clé absente = valeur INCHANGÉE, jamais un défaut** : un serveur sans M1 (« deux dialectes, par construction », `:120-126`) ne doit pas écraser en `false`/`nil` ce que `appliquer(RetourQuotidien)` ou la maquette ont posé — sinon chaque premier plan finit sur une barre fausse toute la journée (`WoopApp:88-92` : claim → vider → `rafraichir()` en dernier) |
| ⑨ | — | **supprimé** : aucun `JourUTC`, aucun minuit côté app |
| ⑩ | `ExerciseDetailView:2270` | la constante `10` meurt, lue depuis ⑦ (le §5.3 le demande aussi — une seule mort) |
| ⑪ | migration | **aucune parallèle à M1** ; le seul ajout (`pieces_retour_quotidien` dans `etat_coffre()`) va dans M1 ou dans une migration ordonnée après elle, repartant de son corps (§29.7 ②) |
| ⑫ | `docs/site/content/*.ts` | §29.7, même commit que ⑪ |

### 29.12 Les pièges, nommés d'avance

1. **Le dégradé qui mange la dernière lettre** (§29.6) — mesurer la luminance
   du dernier glyphe sur la capture.
2. **Une vue `Animatable` sur `remplie`, pas un `frame` qui change** — une
   courbe écrite dans le corps n'est jamais jouée (mémoire
   `woop-piege-rampes-withanimation`, payé sur le calendrier ; `PieceSprite`
   l'applique déjà, `:332-337`).
3. **Le verre sur du noir** (§29.8) — capture, et repli `PiecesNotif`.
4. **`.id(piedIdx)` + `.transition(.opacity)`** : le bloc du haut et le pied
   changent au CRAN, pas sur `page` (la note de `piedIdx`, `:1638-1643` :
   deux matériaux en fondu croisé par image = « pas fluide au drag »).
5. **Rien ne se calcule côté app sur le jour** : `retour_prochain` est lu,
   point. Le seul calcul est `prochain − now` pour la légende, à la minute.
6. **La maquette doit vivre** : `-demoData` n'appelle pas le serveur ; sans
   `retourDisponible = false` et un minuit fictif, la barre du banc dirait
   « à réclamer » pour toujours.
7. **Clé absente ≠ valeur** (⑧) : l'app se déploie avant ou après la base ;
   un `?? false` ferait mentir la barre pendant tout l'écart.
8. **La pastille du profil** (`PillBooster`) affiche le même nombre de sachets
   que la nouvelle pill du pied : elles lisent toutes deux
   `EconomieWoop.boosters`, rien à faire — à vérifier sur capture
   (non-régression).
9. **Sous M1, la page OR et la page Lune montrent le même nombre** (§29.2
   fait 3) : « 40 » puis « 40 / 100 ». Voulu — mais à regarder en feuilletant.
10. **La ligne unique** : `lineLimit(1)` + `minimumScaleFactor(0.85)`, la plus
    longue mesurée tient à 1,0.
11. **Le sim ne fabrique pas de doigt** : les quatre pages se capturent par
    `-coffrePage 0|1|2|3` (les deux formes de l'argument, `nombre(_:)`,
    `:1712-1717`) ; le drag et le tap se jugent au téléphone.
12. **L'autre session** : `git status` porte ~50 fichiers modifiés (dont
    `SacreServeur.swift`, `WoopApp.swift`, `HomeNuit.swift`, le site entier,
    la fiche du coffre) et M1 non suivie. ⑦⑧ touchent `EconomieWoop.swift`
    (propre) et **`SacreServeur.swift` (modifié par elle)** → ses hunks
    d'abord, ou attendre son commit ; par chemins explicites.

### 29.13 L'ordre

| jalon | quoi | risque |
|---|---|---|
| **J0** | ①②③⑤⑥ : le bloc du haut (lecture A, ou B si elle tranche B), la pill en bas, la barre **avec la jauge Lune seule** (« 40 / 100 », `courant = reste`, `cible = prix` — déjà lus) ; « Verrouillé » et le lettrage du mat ; captures des 4 pages **sur HEAD** | aucun serveur ; c'est là que se jugent le nom à 14, le dégradé, le verre sur le noir |
| **J1** | ⑦⑧ les champs (clé absente = inchangée), la maquette ; la barre OR en **horloge** sur la maquette seule | l'écran est complet AVANT que le serveur parle ; **rien n'est mesuré sur un vrai compte** tant que M1 n'est pas posée |
| **J2** | **attend la pose de M1 par l'autre session** (`migration list` avant/après, `etat_coffre` appelée et la réponse LUE) ; ⑪ le montant + ⑫ le site, **un commit** ; ⑩ la constante meurt | lecture seule : rien à rembobiner ; dépendance nommée, pas cachée |
| **J3** | non-régression mesurée : crans, objet, projecteur, arrivée (`remplie`), la pastille du profil | ce qu'on n'a pas voulu changer |
| **J4** | verdicts téléphone : le dégradé du nom, la finesse de la barre, le lettrage du mat | ce que le sim ne montre pas |

J0 seul est déjà sa demande entière, hors le « +10 » ; J1-J2 rendent le
« +10 » vrai au lieu de décoratif — et J2 ne peut pas partir avant M1.

### 29.14 Ce qu'elle seule peut trancher (rien ici n'est dans le dépôt)

0. **Le nom et la phrase : en haut, à la place de la pill (A, reco) — ou dans
   le pied, à la place de « BOOSTER » / « COINS » (B, la lettre de « en
   place ») ?** Le §29 est écrit pour A ; B recote le pied (203 > 196).
1. **La langue** des quatre noms et phrases : français (reco — ses mots, et
   le bouton) ou anglais (le reste de la page) ?
2. **« 60/100 »** : la forme `courant / prix` d'aujourd'hui (reco, §27) — ou
   vraiment le **manque** (« 60 à obtenir ») ?
3. **Le nom à 14** : casse de phrase (reco, « Or Piece » à la lettre) — ou
   capitales espacées — ou 23 à la Opal (tient à la même place) ?
4. **La phrase de la page Lune** (§29.5) : « Un sachet de cartes du set
   Lune. » — ou la sienne.
5. **Pages argent et noire sans barre** : confirmé ? (la seule barre possible
   exposerait la pitié, ou écrirait « 2 / 1 ».)
6. **Le lettrage du mat « Verrouillé »** : aligné sur le primaire (−0,2 / 18,
   reco) ou gardé à 1,6 / 15 ?

### 29.15 CODÉ — J0, sur HEAD `8d9d4eb` (30-08, 18:59), NON commité

Ses réponses : **« ok »** (les recos), **« anglais »**, **« page argent et
noir sans barre »**, **« et le mat oui »**. Lecture **A** (le nom en haut).

**Ce qui est dans l'arbre** (`Woop/Views/CoffreV2.swift` +299/−206,
`Woop/Services/EconomieWoop.swift` +25) :

- `PillPrix` **meurt** → `PillCompte` (glyphe + nombre, verre `.clear`, plus
  de liquide) · `JaugeCoffre` (`.compte` / `.horloge` — des DONNÉES) ·
  `BarreFine` (3 × 240, rail blanc 0,10, remplissage `lueur.mix(blanc 0,55)
  → blanc`, `Animatable` sur `remplie`, l'horloge dans un
  `TimelineView(60 s)` qui porte aussi le test « minuit passé ») ·
  `EnTeteObjet` (14 semibold casse de phrase, fondu 1,00 → 0,55 ; phrase 15
  medium 0,62, une ligne) · `PiedVariante` réécrite (`nom`, `phrase`,
  `glyphe`, `nombre`, `jauge?`, `robe`, `bouton`, `lueur`).
- `PiedCoffre` = pill · barre · `Spacer` · bouton ; le mat au lettrage du
  primaire (18 semibold, −0,2). Les chaînes restent `"OUVRIR"` / `"LOCKED"`
  (la casse est celle du composant : « Ouvrir » / « Locked »).
- `variantes` en anglais : *Gold Coin — Opens a Lune Booster.* · *Lune
  Booster — A pack of cards from the Lune set.* · *Silver Coin — Opens a
  Legendary Booster.* · *Legendary Booster — One legendary card, guaranteed.*
  Pas de barre sur ③ et ④. `contenu()` lit la variante UNE fois (`let v`).
- `EconomieWoop` : `piecesRetourQuotidien` (10), `retourDisponible`,
  `prochainRetour: Date?` — **maquette seule** (un minuit fictif à +6 h, posé
  une fois, uniquement si `!possible`) ; `appliquer(RetourQuotidien)` pose
  `retourDisponible = false`. **Sur un vrai compte `prochainRetour` reste nil
  → pas d'horloge** tant que ⑧ (le décodage) et M1 ne sont pas là.

**Mesuré** sur kat-coffre (`refs/s29-j0-page0..3.png`, planche
`s29-j0-planche.jpg`, 402 × 874) :

| | page OR | page LUNE |
|---|---|---|
| le nom | L max 252 (1ᵉʳ glyphe) → **221** (dernier) : le fondu court garde la dernière lettre ; fond derrière médiane **L 42**, p90 83 | 253 → 222, fond L 53 |
| la phrase | une ligne, L max 255 | une ligne (« …Lune set. » frôle la goutte de verre à droite, dans les 320) |
| la barre | **y 687, 3,0 pt, rail 81 → 321 (240 pt), rail L 25 ≈ blanc 0,10, fond L 0** ; remplie à **0,75** (+10 in 6 h), (255,227,186) → (254,255,254) | remplie à **0,40** (40 / 100), (255,201,169) → (254,253,252) |
| la pill · la légende | texte y 642-662 · légende y 708-719 | idem |
| le bouton | — | « Ouvrir » (page 3 : « Locked » mat, 18 / −0,2) |

**Non vérifié** : l'arrivée de la barre (`remplie`, ressort 0,80/0,75) n'est
pas filmée — la capture à 8 s la montre posée ; le feuilletage, le tap et le
drag se jugent au téléphone. **Rien n'est commité** (par chemins :
`CoffreV2.swift`, `EconomieWoop.swift`, ce plan, `refs/s29-*`).

**Reste** : ⑧ le décodage (`SacreServeur.swift`, modifié par l'autre session
— attendre son commit), M1 posée par elle, le montant ajouté à `etat_coffre()`
+ le site dans le même commit (J2), et ses verdicts téléphone (J4).

### 29.16 CODÉ — ses cinq retours sur J0 (30-08, 19:16), NON commité

*« Bien espacer davantage la pastille et la progress bar — j'adore · une
petite ligne de description sous la pastille des pièces, ça fait trop vide ·
un bouton "Discover history" qui mène sur la page avec l'histoire et la vidéo
· sous la barre du booster Lune, 40/100 avec une petite pièce or pour le
rappel · sous la barre de la pièce or, "+10 pièces in 6 hours" · et prends le
booster détouré Lune de la pop-up de fin, on a réussi à le faire et c'est
good. »*

| retour | ce qui est codé | mesuré (`refs/s29-j0-page0..3.png`, remplacées) |
|---|---|---|
| l'air pill → barre | 12 → **24** (20 quand la ligne est là) | page Lune : pill 630-674, barre **698** |
| la ligne sous la pill | `PiedVariante.sousPill`, 14 medium 0,55, une ligne — *20 coins for every set you finish.* (taux serveur) · *A rare drop from the path.* | page Or : 687-700 |
| « Discover history » | `PiedVariante.histoire: RobeBooster?` sur les pages de PIÈCES (l'or → l'histoire du sachet Lune, l'argent → celle du légendaire : chaque récit parle de sa pièce) ; même capsule que le mat, encre 0,92, liseré 0,16, lettrage du primaire, `highPriorityGesture` → `ouvrirHistoire(robe)` (la vidéo puis la page). Les pages de sachets y vont déjà par le 2ᵉ tap sur l'objet | pages Or et Argent : 780-838 |
| « 🪙 40 / 100 » | `JaugeCoffre.compte(courant:cible:monnaie:)` — la mini pièce (16 pt) devant la légende | page Lune : 718-734 |
| « +10 coins in 6 hours » | en toutes lettres, singulier/pluriel (`hour`/`hours`, `minute`/`minutes`), « +10 coins to claim » | page Or : 743-755 |
| le sachet détouré | `Image("booster-hero")` (l'asset de `BoosterCard`, 795 × 1334 RGBA, alpha réel) dans `PillCompte` pour `.sachet(.lune)` ; le noir garde `SachetVignette` | page Lune : la pastille |

⚠️ **Le cadre 196 était PLEIN sur la page Or** (44 + 13 + 13 + 21 + 3 + 19 +
12 + 13 + 58) : 13 pt entre la légende et le bouton. → **`PiedCoffre.taille`
196 → 208**, ancre `podFin + 103 → + 109` : le haut reste à 630, les crans à
597-607, le bouton passe à **780-838** (25 pt sous la légende), le bas à 838
sous la zone sûre (840).

**Non vérifié** : le tap « Discover history » (le sim ne fabrique pas de
doigt — la porte appelle `ouvrirHistoire`, la même que le 2ᵉ tap de l'objet,
vérifiée au §28.8) ; l'arrivée ; le téléphone.
