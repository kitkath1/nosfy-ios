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
