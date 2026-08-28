# AUDIT — LA ROUTE (« le chemin de feu »), le geste, la flamme

## POUR LE BACKEND — LA RÈGLE DES RÉCOMPENSES DU CHEMIN (27-08, dictée)

> « On a **une lune par chapitre à la fin**, et **des fois au milieu**, et une
> **pastille pièce** aussi. **Deux récompenses par chapitre maximum.** »

**Ce que le serveur devra dire, et que le front ne doit pas inventer :**

| ce qui se décide | valeur aujourd'hui (front, en dur) | ce qu'il faudra |
|---|---|---|
| taille d'un chapitre | 9 nœuds : **7 séances + 2 récompenses** | le serveur donne la liste des nœuds d'un chapitre |
| récompense de FIN | toujours une **lune** (rang 8) | idem, mais c'est le serveur qui la crée |
| récompense du MILIEU | **rang 3**, alternée : pièce sur les chapitres impairs, lune sur les pairs | c'est **« des fois »** : le serveur décide s'il y en a une, et laquelle |
| plafond | 2 par chapitre, jamais 3 | **règle dure côté serveur** |
| ce qu'une lune donne | `SacreEtat.proposer()` → un booster | une ligne `user_boosters`, origine `chemin_lune` |
| ce qu'une pièce donne | « +40 » affiché par la capsule | une ligne **`coin_ledger`**, raison `chemin_piece`, **montant décidé au serveur** (+20/+30/+40, plafond de séance) |
| « déjà réclamée » | `UserDefaults` (`chemin.reclamees`) | **la source de vérité est le ledger** : sans lui, une récompense se re-réclame à chaque lancement (boosters et pièces infinis) |
| clé d'idempotence | — | **(user, chapitre, rang)** — surtout PAS `session_uuid` : le chemin n'est pas une séance |

⚠️ **Le rang 3 n'est pas cosmétique** : il place la récompense du milieu
**après trois séances**, ce qui la laisse éteinte tant que la troisième est en
cours. Une récompense se mérite ; elle ne s'offre pas à l'ouverture du
chapitre.

⚠️ **Le calendrier compte les SÉANCES, pas les nœuds** : une récompense
glissée entre deux séances n'est pas un jour (sans quoi il existe des « jours
fantômes » où aucun galet n'est actif).

---

## POUR LE BACKEND — LA RÉCOMPENSE : LE SERVEUR TIRE, LE FRONT RÉVÈLE (28-08, dictée)

> « La récompense doit être déterminée côté backend **avant ou au moment du
> claim**, pas générée arbitrairement par l'animation front. Le scratch et les
> animations ne font que **révéler une récompense déjà attribuée**. »

C'est la règle qui commande toute l'architecture de la card. Elle interdit trois
choses d'un coup : un tirage au front, un rejeu qui redonne, et une divergence
entre ce que l'écran montre et ce que le compte porte.

**Le flux complet :**

`galet disponible` → `halo` → `Claim` → `card lune` → `on range Nosfy` →
`on gratte la lune` → `révélation` → `Coins OU Boosters` → `créditée` → `claimed`

### Les quatre états

| état | ce que ça veut dire | ce que le front en fait |
|---|---|---|
| `locked` | les séances d'avant ne sont pas toutes faites | glyphe éteint, **pas de halo**, le tap ouvre le panneau « Reach this step… » |
| `available` | réclamable | **le halo respire** (0,62, rayon 0,68 Ø — voir § 5 sexies), bouton `Claim` |
| `claiming` | l'aller-retour serveur | le bouton attend ; **un échec REVIENT à `available`**, jamais un galet mort |
| `claimed` | créditée | glyphe sourd, la card se rouvre **sans se re-gratter** |

### Le payload

```
GET  /chemin/recompense/{chapitre}/{rang}
  etat          locked | available | claiming | claimed
  claimable     bool
  card_opened   bool      ← la card a déjà été ouverte
  reveal_played bool      ← l'animation de révélation a déjà été jouée
  credited      bool      ← réellement portée au compte

POST /chemin/recompense/{chapitre}/{rang}/claim
  clé d'idempotence : (user, chapitre, rang)     ← surtout PAS session_uuid
  rend le payload DÉJÀ TIRÉ :
    reward_type              coins | boosters
    · coins    → coin_type   standard | black
                 amount
                 is_legendary_currency
    · boosters → boosters    [orange | legendary_black, …]   ← une LISTE
    rarity                   common | rare | legendary
```

⚠️ **`boosters` est une LISTE, jamais « 2 orange » en dur.** Le front compose la
scène à partir du résultat : `[orange, orange]`, `[orange, legendary_black]`,
`[legendary_black, legendary_black]`, et tout ce qu'on ajoutera ensuite.

### Trois conséquences que le front tient déjà

1. **`credited` bascule AU CLAIM**, pas à la fin du grattage. Tuer l'app en
   plein scratch ne coûte pas la récompense.
2. **`reveal_played`** rouvre une card déjà grattée dans son état révélé —
   sinon on redemande le travail, ou pire, on laisse croire à un second tirage.
3. **`claiming`** existe pour le réseau : sans lui, un échec laisse un galet
   dans un état qu'aucun geste ne rattrape.

### LE VARIANT « WIN » DE LA REWARD CARD — ce qui vient du serveur (28-08)

C'est un **nouveau variant**, monté sur les pièces de la robe « YOU MADE IT »
(`TexteGeant` + `LampeEventail`, sorties de `private` — visibilité seulement,
cinq lignes, aucun comportement touché). **La robe existante n'est pas
modifiée.**

**Deux choses seulement varient, et elles viennent du backend :**

| ce qui varie | où ça s'affiche | champ |
|---|---|---|
| **le NOMBRE** | la **deuxième des trois lignes géantes** (`WIN` / `2` / `BOOSTERS`) | `boosters.count` |
| **les BOOSTERS montrés** | la **poche, au pied de la card** — un sachet par entrée, avec sa robe | `boosters: [orange \| legendary_black, …]` |

Tout le reste est fixe : les mots « WIN » et « BOOSTERS », la lampe, le
dégradé, la lèvre de la poche.

⚠️ **La liste commande le rendu, jamais un compteur seul.** Le front lit
`boosters` et compose : deux orange, un orange + un légendaire, deux
légendaires, et tout ce qu'on ajoutera. Un `count` sans la liste ne dirait pas
QUELS sachets montrer.

⚠️ **Le nombre affiché est `boosters.count`, jamais un champ séparé.** Deux
sources pour la même vérité divergent à la première retouche : si le serveur
envoie trois sachets et un `count` de 2, la card ment.

⚠️ **Trois sachets au plus sont montrés** (la poche en contient trois poses).
Au-delà, c'est un cas à trancher — pas encore rencontré, pas encore codé.

### Les taux, et la pitié

| piste | résultat | taux |
|---|---|---|
| **pièces** | `standard`, 100-200 | **94 %** |
| | `black` × 1 | **6 %** |
| **boosters** | `[orange, orange]` | **88 %** |
| | `[orange, legendary_black]` | **11 %** |
| | `[legendary_black, legendary_black]` | **1 %** |

Deux récompenses par chapitre, donc cinq nœuds de chaque sur les cinq
chapitres. À 6 %, une pièce noire tombe tous les ~17 nœuds — tous les trois
chapitres et demi : assez rare pour être un événement, assez fréquente pour
qu'une joueuse régulière en voie une. Le légendaire cumulé à 12 % tombe tous
les ~8 nœuds. Le double légendaire à 1 % est celui qu'on raconte.

⚠️ **LA PITIÉ EST CE QUI MOTIVE**, plus que le taux lui-même : après **12 nœuds
communs d'affilée** sur une piste, le taux rare **DOUBLE à chaque nœud suivant**
jusqu'à ce qu'il tombe, puis se remet à zéro. Sans elle, une série sèche
ressemble à une punition ; avec elle, à une montée. Le compteur vit **par
utilisateur ET par piste** (`pity_counter`), et **côté serveur** — sinon il est
falsifiable.

### La monnaie noire

`coin_type: black` est la monnaie rare, liée aux récompenses et cartes
légendaires. Son visuel n'est pas à créer : c'est **`piece-argent`**, la planche
du coffre (`CoffreV2.swift`, 72 cases, cerclage chrome froid). Elle est jouée
par `PieceSprite`, donc elle **TOURNE** à la révélation — l'or, lui, reste posé.
C'est la différence qui se lit sans légende.

---

## POUR LE BACKEND — LA RÈGLE DES JOURS : UN JOUR N'EXISTE QUE QUAND IL EST FAIT (28-08, dictée)

> « Quand c'est **à venir**, on ne voit pas les jours, c'est une **flamme**.
> Car les jours **apparaissent le jour où le user a terminé / fait sa
> séance**. »

**La date n'est pas une position dans le chemin, c'est un ESTAMPILLAGE.**

| | avant | maintenant (codé 28-08) |
|---|---|---|
| date d'un galet FAIT | `Date() + (rang − rang_actif)` jours | **son estampille**, remontée avec lui (`Workout.endedAt` → `EtatDuo.datesFaites`) |
| date d'un galet À VENIR | déjà `nil` — flamme seule ✅ | inchangé : **le serveur n'en renvoie aucune**, elle n'existe pas encore |
| date du galet ACTIF | dérivée du rang | **aujourd'hui, calculé à l'affichage** — le jour où le user est connecté ; elle ne se FIGE qu'à la complétion |
| date d'un jour RATÉ | dérivée du rang | dérivée du rang — **et c'est juste** (voir ci-dessous) : il n'a pas d'estampille, mais c'est un jour PASSÉ et il doit dire lequel |

⚠️ **PRÉCISION, parce que la première version de cette note accusait trop
large.** La formule par le rang n'était pas fausse *en soi* : dans la
dérivation réelle (`-cheminReel`), `rang(d) = jours écoulés depuis la
première séance`, donc **le rang EST le calendrier** et `aujourd'hui +
(rang − rang_actif)` retombe exactement sur le bon jour. Le mensonge venait
de la **DÉMO** : elle pose `étape = jour 2` et `faits = {jour 0, jour 1}`
quels que soient les vrais `endedAt`. L'axe des rangs y est **fabriqué** —
donc deux séances réellement faites les 22 et 26 s'affichaient « avant-hier »
et « hier ».

La table d'estampilles reste le bon dessin pour les deux raisons qui
comptent : **c'est ce que le serveur enverra** (une date par nœud fait, pas
un axe à reconstituer), et elle **survit à n'importe quel axe de rangs** —
le jour où un chapitre ne sera plus « un rang = un jour », la formule, elle,
tombe.

**Ce que le serveur renvoie par nœud** : `rang`, `nature`, `statut`
(`fait` / `actif` / `a_venir`), et **`completed_at` UNIQUEMENT si `fait`**.
Le front n'invente aucune date pour l'avenir.

---

## POUR LE BACKEND ET LE FRONT — LE SENS DU CHEMIN : ON DESCEND (28-08, dictée)

> « Au-dessus du jour marqué **today**, il devrait y avoir soit une **lune
> accomplie**, soit des **jours faits** — et pas d'état empty, **le chemin a
> déjà été fait**. Au contraire, **sous** le jour marqué avec le halo, les
> autres galets à venir sont des flammes ou des lunes. »

**Le passé est EN HAUT, l'avenir EN BAS.** Aujourd'hui est la charnière.

Le front faisait l'inverse (`y = 740 − rang × 67,5` : le rang MONTE), alors
que les chapitres, eux, s'empilent vers le BAS (`ecran × 874`). Le chemin
grimpait à l'intérieur d'un chapitre puis se téléportait au bas du suivant
pour regrimper : **cinq échelles empilées, lues vers le haut, dans un
document lu vers le bas**. Aucune continuité lisible — et c'est la vraie
cause du verdict « on ne comprend rien à la continuité », que le serpentin
seul ne pouvait pas régler.

Conséquences, toutes mécaniques :
- l'air minimum ne bouge pas (**31,6 pt**) — un miroir vertical ne change
  aucune distance ;
- le **trésor** (rang 8) passe du haut au bas du chapitre : sa garde sous la
  dalle est à remesurer ;
- le panneau `dessous` s'inverse : il était posé pour couvrir le **passé**,
  qui sera désormais **au-dessus** ;
- l'ordre des rangs, les ids contigus, l'aimant de chapitre et le calendrier
  des séances sont inchangés.

⚠️ **Règle de lecture qui en découle, et qui vaut pour le serveur** : un
nœud placé AU-DESSUS de l'actif ne peut pas être `a_venir`. Si le serveur
renvoie un tel état, c'est une incohérence de données, pas un cas
d'affichage.

---

## LE PANNEAU FERMÉ NE CHANGE RIEN (28-08, dictée)

> « Si je ferme l'overlay qui demande de commencer la session, le jour J
> reste toujours en mode **halo**, et quand je retape dessus je revois
> l'overlay. »

Le halo appartient à l'**état** du galet (`.actif`), pas au panneau :
`fermerPanneau()` n'écrit que `panneauSur = nil`, `etape` n'est pas touché.
Fermer est donc sans effet sur le chemin — **« Plus tard » n'est pas un
refus, c'est un report**. Rien à écrire côté serveur : aucune trace, aucun
compteur, aucun cooldown.

⚠️ Une seule condition dans le code : `etat.branchee`. **Débranchée**, le tap
sur l'étape courante l'AVANCE au lieu de rouvrir le panneau — comportement de
banc, à ne jamais laisser fuiter en production.

---


## ÉTAT DU CHANTIER — 27-08, 10 h 40 : CODÉ SUR SON « GO », TROIS COMMITS

Sur son « go » (et deux verdicts : « en mode jouet », « point A »), les
jalons ont été codés dans l'ordre du § 10, chacun mesuré au sim
`kat-road`, aucun validé par elle :

| jalon | commit | état | mesuré |
|---|---|---|---|
| 0 — `etape` lit les séances, banc branchée + étape > 0 | `3f862a9` | **codé** | `-homeChemin -duoEtape n` montre les 5 états + panneau |
| 2 — ×1,5, 9/écran alterné ±60, ids contigus, point A `S1 S2 ¢ S3 S4 ☾ S5 S6 ☾`, pt absolus | `3f862a9` | **codé** | 30,4 pt d'air min ; trésor à 15 pt sous la dalle |
| 3 — les matières, **sa référence pour TOUS les états** (cheveu rare partout, plus de stroke SwiftUI, or dans les cheveux) | `3f862a9` + `a339141` | **codé** | fait µ 69 CV 0,77-0,80 FWHM 1,1-1,3 ; futur µ 118-145 ; lune verr. µ 60 |
| 4 — le panneau naît du galet (ancre, dessous sur le passé, scale ancré colonne, halo étiré, projecteur, conditionné) | `3f862a9` | **codé** | plus de glissement caché ; couvre le passé éteint |
| 6 — le jouet + `@GestureState` (bug latent) | `3f862a9` | **codé** | téléphone seulement |
| 1 — `CheminHote` en arbre, lune → booster, pièce → capsule +40, **sommeil de la home** | `a339141` | **codé** | route+home dormante ≈ home seule (machine chargée) ; réveil propre au retour |
| 5 — le geste vers la droite (enveloppeur mince, verrou d'axe, 28 % / élan) | `e2bc04f` | **codé** | téléphone seulement ; reste le tirage au sommet |
| 7 bis — la card reward robe `.piece` + `RewardHote` + `coin_ledger` | — | **à faire** | la capsule `PiecesNotif` tient lieu |
| 8 — la famille de stickers | — | **à faire** (contenu) | — |

Ce que le code a appris en plus de l'audit : **la sortie du cover coûte** —
home seule 50-59 img/s, route seule 59-60, ensemble **12-21** (machine
calme) ; le sommeil (`\.dort`, `paused:` sur 14 horloges, vidéos en pose,
verre démonté sur les widgets, l'ardoise et le galet du menu) ramène
route+home au niveau de la home seule sous la même charge. **À remesurer
sur machine calme et sur le téléphone.** Bancs neufs : `-homeChemin
-duoEtape n`, `-cheminSeul` (home démontée, isole la route), `-cheminRetourAuto`.

État au **27-08-2026, 00 h 20** de l'analyse ci-dessous (elle reste la
référence de conception). Simulateur dédié `kat-road`
(`E6A4E963-E90F-4534-AAF5-059657408D7D`, iPhone 17 Pro), DerivedData
`dd-road/`, build du 26-08 21 h 25 (`EXIT=0`). Les captures et les sondes
vivent ici : `tools/road/shots/`, `tools/road/mesure_etats.py`,
`tools/road/layout_x15.py` — le scratchpad est purgé entre deux sessions.
La planche visuelle (captures, mesures, mire des matières et de la flamme
dessinées) est l'artifact « La route de pierres noires ».

**Cet audit a été passé au fouet deux fois** (11 agents en lecture seule,
code cité, calculs python, historique git ; le critique de cohérence du 2e
tour a été coupé par la limite de session — la relecture de cohérence est
la mienne, §14). Quatre de mes propositions initiales étaient fausses (les
ids « en base 10 », la bulle latérale à bec, le LongPress nu, la « pierre
noire » du passé) et **ma première spec chiffrée du liseré du passé ne
passait pas son propre portillon** (§5 bis). Le texte ci-dessous est la
version corrigée ; §12-§13 disent ce qui a changé et pourquoi.

Les verdicts dictés le 26-08 au soir, dans son ordre : **(1)** le geste
« comme Spotify » au milieu de l'écran pour quitter la route sans le
chevron · **(3)** galets ×1,5 sans les coller · **(4)** deux galets Lune par
chapitre → le même overlay booster · **(5)** FAIT / EN COURS / À VENIR
lisibles instantanément · **(6)** l'overlay « Commencer » rattaché à SON
galet · **(7)** les galets se déplacent partout et se replacent en
s'animant · **(8)** le composant flamme « beaucoup plus Apple premium » ·
**(9)** un design de couturier — fin, liseré, magnifique. Et à 22 h 30, **la
précision** : « quand ce n'est pas des actifs (des sessions passées), je
veux que les liserés soient très fins et pas réguliers comme ce screenshot,
plus discret, plus premium pour l'état passé — fouette, et tant que ce n'est
pas ça ne reviens plus me voir ».

---

## 0. LE DIAGNOSTIC EN UNE PHRASE

La route se lit comme un **collier de perles identiques** : même taille,
même anneau **plein et régulier**, même lumière, qui se **touchent** ; le
panneau de départ flotte au **centre de la page** et **couvre trois galets**
(un en entier, deux à moitié) ; l'état ne se dit que par 15 à 20 points de
luminance ; la seule sortie est un chevron ; et **l'overlay booster ne peut
pas apparaître au-dessus de la route** telle qu'elle est montée. La flamme
est un emoji.

Tout ce qui suit est **mesuré** sur les captures (règle 10 : un juge qui
affirme ne remplace pas une sonde qui mesure).

| capture | banc | ce qu'elle montre |
|---|---|---|
| `shots/road-1-branchee.png` | `-skipAuth -homeChemin` | la route branchée, panneau né à +2,1 s |
| `shots/road-2-etats-etape5.png` | `-duoLab -duoEtape 5 -duoFreeze` | accompli ×4, raté, actif, prochain, verrouillé ×2, lune verrouillée |
| `shots/road-3-tresor-ecran5.png` | `-duoLab -duoEcran 5 -duoEtape 49` | la lune disponible (anneau d'or) |
| `shots/home-1.png` | `-skipAuth` | l'ardoise « This week » et son sticker flamme |
| `shots/planche-etats.png` | découpe numpy | les dix galets de l'écran 1, côte à côte |

**Trois faits transversaux qui conditionnent tout :**

- ⚠️ **En production `etat.etape` vaut 0 et n'avance jamais**
  (`DuolinguoPage.swift:219-220`, `:1247`, `:891-896`). Dans l'app réelle
  **aucun accompli, aucun raté, aucune lune disponible n'existe**, et le
  panneau naît toujours sur le galet 0 de l'écran 1. Les points 4, 5, 6 ne
  se jugent qu'au banc `-duoLab -duoEtape n` — **où la page n'est PAS
  branchée** (pas de panneau). **Aucun banc ne montre branchée + étape > 0**
  : il en faut un (`-homeChemin -duoEtape n`). La décision D2 (câbler
  `Workout.endedAt` → `etape`) est le **prérequis** de trois points sur huit.
- ⚠️ **Le working tree n'est pas HEAD** : `BoosterPopup.swift` est modifié
  non commité par la session WIN/story (`propositionEnAttente`) ; le point 4
  atterrit sur un fichier qu'une autre session édite — stager ses seuls
  hunks, committer par chemins.
- ⚠️ **Le simulateur ne pose pas de doigt** et n'a pas d'inertie de pan ;
  aucun `-xxxAuto` ne rejoue un tap de galet, un press, un port. Tout
  verdict de geste = l'appareil. Baseline de cadence : **~42-43 img/s au sim
  en transition** — déjà sous 60 avant ×1,5. `-demoData` sème une séance
  ouverte persistante : toute capture = uninstall + `-skipAuth`.

---

## 1. L'ARCHITECTURE D'ABORD — la route doit sortir du `fullScreenCover`

C'est le point qui **déverrouille trois de ses demandes** (1, 4 et 6), et il
faut le trancher avant tout le reste.

**Ce qui est écrit — CONFIRMÉ au fouet** : la route est présentée par
`.fullScreenCover(isPresented: $cheminOuvert)` (`HomeNuit.swift:2270`),
depuis la home qui vit dans l'onglet Home du `TabView`
(`WoopApp.swift:678`). La pop-up booster (`BoosterPopupHote`,
`WoopApp.swift:897`, `zIndex(6)`) et le Manège (`BoosterLab`,
`WoopApp.swift:910`, `zIndex(7)`) sont **frères du TabView** dans le ZStack
racine de `mainBody` — sous toute présentation modale. Aucun appelant de
`proposer()` ne vit dans la route ; aucun mécanisme « le cover se ferme
quand la pop-up se propose » n'existe. **La ligne « `tape` → `proposer()`
et rien d'autre » de `BUGS-RESTANTS.md §4` est donc fausse telle quelle.**

**Conséquences, par demande :**

- **(4) le galet Lune** : `SacreEtat.shared.proposer()` appelé depuis la
  route ouvrirait la pop-up **derrière le cover** — et c'est pire
  qu'invisible : l'haptique `.soft` joue, `popupOuverte` passe à `true`,
  l'entrée `.move` se joue sous le cover, la sonde `-fps` s'étiquette
  « panneau » ; à la fermeture de la route, la pop-up serait **déjà posée**
  sans son entrée. La famille exacte du bug 1a du 26-08.
- **(1) le geste Spotify** : un `fullScreenCover` n'a aucun renvoi
  interactif système. Nuance du fouet : un cover PEUT rendre son
  présentateur dessous (`.presentationBackground(.clear)`, l'école du
  portail de `CalLab`) et porter une sortie maison (l'école `StoryPortal`).
  Ce n'est donc pas « impossible » — mais la maison a déjà tranché **deux
  fois contre les covers imbriqués**, paie le ping-pong d'insets sous un
  cover (`cheminDemonte`), et l'**entrée continue au doigt** (Porte 2 du
  plan de branchement) n'existe qu'en arbre.
- **(6) l'overlay rattaché** n'est pas bloqué par le cover, mais la
  correction est la même famille : un objet qui vit dans le scroll de la
  route, jamais une carte posée sur l'écran.

**La forme juste — `CheminHote` à la racine**, pour les bonnes raisons :
l'entrée au doigt, l'unité de fenêtre, et le partage de l'état du TabView.
La route devient un overlay **en arbre** du ZStack de `mainBody`,
`zIndex(4)` (sous la pause 5, la pop-up 6, le Manège 7), piloté par
`DepartEtat.shared.cheminOuvert` — **`DepartEtat` est le bon porteur**
(`@Observable`, `static let shared`, déjà lu à la racine et observé en
`onChange`). La page se **monte et se démonte** (`if ouvert { … }`, l'école
`BoosterLab` en `appMode`) — jamais décalée hors écran. Les préférences VC
(`statusBarHidden`, `persistentSystemOverlays`) suivent le sous-arbre monté :
patron déjà en production dans ce ZStack (BoosterLab, PorteEntree) ; le
`.environment(\.colorScheme, .dark)` du cover devient redondant sous le
`preferredColorScheme(.dark)` de la racine.

**Le repli si le cover reste** : la grammaire existante de
`demarrerDepuisChemin` — la route se replie D'ABORD, puis `proposer()`
après la descente (~0,45 s), par un callback agnostique `onLune`. Un
voyage (la pop-up apparaît sur la home), pas une superposition. **Jamais**
un second `BoosterPopupHote` dans le cover.

**Le PRIX de la sortie du cover — dit juste, après le 2e fouet.** Ma
première version opposait un « sommeil » à l'éclipse `homeEclipsee` : faux
adversaire — l'éclipse n'a jamais concerné la route (elle n'est écrite que
par le Sacre). Ce qui compte : **le cover retirait la vue présentante
GRATUITEMENT** après sa transition ; en arbre, SwiftUI rend un frère occulté
(la loi payée du splash, `WoopApp.swift:658-666`). **Sans sommeil, l'hôte en
arbre est une régression mesurable contre le cover** : deux pages pleines
qui rendent.

- **Aucun mécanisme de sommeil réutilisable n'existe dans la home** :
  `verreDemonte` démonte (ce n'est pas une pause), `scenePhase` ne sert qu'à
  relancer, `SkyMotion` est un singleton partagé par toute l'app (« JAMAIS
  de stop() ici »). Le sommeil est une **clé d'environnement NEUVE** (l'école
  exacte de `verreDemonte`, `WidgetsCards.swift:189-198`) à brancher sur
  ~12 horloges : GaletMaison 30 Hz, MenuHalos 24, Panache/GaletFumee 30,
  sept widgets à 12 Hz, FumeeInvite 30 + son shader (13 Mpix/s tant qu'elle
  existe), InviteTirage 30, VerreGaletDur 20 + shader.
- **Ne PAS endormir les vidéos de la home** : `CalqueVideo` est l'original
  aux trois chemins qui ignorent `rate` (`DepartCine.swift:391, 396, 406,
  417`) ; un réveil 0→1 flushe la couche et la pose est cachée à vie
  (`:399-403`) ; un « Spotify » depuis n'importe où n'a aucun précurseur
  pour pré-réveiller. Les deux calques restent à rate 1 (27 Mpix/s mesurés) ;
  on endort horloges + shaders + verre, **et on mesure** (`-fps`, ≥ 58 route
  posée).
- Ce qui est vrai de l'éclipse : au remontage `deja` repart à `false` et
  `jouerArrivee()` rejoue la cinématique — incompatible avec « la home
  visible au premier point du doigt » (le « ~0,7 s mesurés » de ma première
  version était la désallocation sous le Manège, pas le remontage).
- **Les lecteurs de la route** : sous `if ouvert` ils sont DÉMONTÉS hors
  écran (`dismantle`) — ma première version se contredisait (« montée /
  démontée » ET « les lecteurs restent montés »). La seule fenêtre « sous la
  home » est **le geste de sortie** : 3 décodeurs vivants + le galet actif
  à la cadence de l'écran, pendant que la home se réveille — le pire cas, à
  mesurer. `gel` n'est lu qu'au prochain rappel de la sonde de scroll :
  « rate 0 hors écran » demande un appel explicite `gel = true ;
  piloter(y:)`. Le pré-réveil de `PLAN-BRANCHEMENT.md:136-140` n'est pas
  codé — et il est sans objet en `exoParRoute`.
- **Porte 2 (l'entrée continue au doigt) contredit `if ouvert`** : monter
  `DuolinguoPage` PENDANT le tirage de la home = ≈14 `AVQueuePlayer` +
  preroll + 50 `asyncAfter` de cascade sous le doigt (le piège « vue lourde
  qui naît pendant un film », trou de 224 ms mesuré). Soit la route est
  pré-montée endormie à l'amorce, soit Porte 2 attend une mesure de
  naissance. **À trancher au banc, pas ici.**

**Les pièges de l'hôte en arbre, complétés :**
- **Un double hôte est DÉJÀ vivant** : `DepartPanneauHote` est monté deux
  fois sur le même drapeau (racine `WoopApp.swift:888-896` ET overlay home
  `HomeNuit.swift:2200-2203`), avec deux `onCommencer` différents — visible
  au banc `-departPanneau`. `cheminOuvert` doit avoir UN hôte, la racine ;
  l'overlay `:2200` est le précédent à ne pas reproduire, à retirer dans le
  même chantier.
- **Exclusivité des états** : `proposer()` ne garde que `panneauOuvert` ;
  un panneau de départ ou de pause (5) peut s'ouvrir par-dessus une route
  (4) — définir qui ferme qui (l'école `SacreEtat.proposer()`).
- **Le geste de sortie et les insets** : la route contient un `ScrollView
  … .ignoresSafeArea()` ; un `.offset(x:)` sur l'hôte pendant le tirage
  rejoue le ScrollView hors écran (insets renégociés, toute la page
  respire). L'écriture par image = `visualEffect` (post-layout), **jamais**
  `.offset`/`.position` sur le conteneur. C'est une LOI.
- **Le verre de la home sous la route** : `SemaineStrip verre: true` et les
  `CardCorps` restent posés sur une vidéo vivante pendant que la route bouge
  au-dessus → `verreDemonte` sur la home AUSSI pendant le geste.
- **Deux sondes `-fps`** (« home » et « duo ») auront chacune leur
  `CADisplayLink` : lire l'étiquette `duo`, vérifier qu'elles ne s'altèrent
  pas.
- `defersSystemGestures(on: .bottom)` de la home pourrait s'appliquer à la
  fenêtre pendant la route (la home reste montée) — à vérifier sur appareil.
  La barre de statut pendant le geste : `statusBarHidden(!enSortie)` si la
  couture se voit.
- **Le départ depuis la racine** : ne PAS réutiliser `startWorkout()` (il
  rouvre la vieille feuille noire si une séance existe, `WoopApp.swift:454-458`)
  — réécrire la garde de `ouvrirSeanceEnBase` à la racine ; ajouter dans
  HomeNuit la branche `enSeance && tiroirOuvert → tirage = reposCard` (le
  `onChange(of: enSeance)` refuse la porte slider : la home reviendrait
  tiroir ouvert, card non levée) ; décider `tutoDemande` ; séquencer « la
  route part PUIS l'onglet bascule » ; supprimer `exoOuvert` /
  `cheminDemonte` / le cover imbriqué ; déplacer `-homeChemin` dans le
  `.task(id:)` racine et y ajouter `-duoEtape n` ; donner un `CheminHote`
  au banc `-homeV2` (il route par cover, sans racine).
- Banc pour VOIR la superposition sans coder : `-skipAuth -homeChemin
  -boosterPopup` — la pop-up se propose à +0,8 s, le cover s'ouvre à
  +1,2 s : elle disparaît sous la route et ressort posée à sa fermeture.

---

## 2. LE GESTE — « tirer la page, de n'importe où » (demande 1)

**L'axe, tranché** : sur les écrans 2 à 5, le vertical appartient au paging
(tirer vers le bas = le chapitre précédent). **« Au milieu de l'écran » =
l'horizontal, ou rien** ; le tirage vers le bas n'est une sortie qu'au
sommet de l'écran 1.

Le chevron est un `chevron.left` (`DuolinguoPage.swift:977`) : son jumeau
gestuel est le **glissement vers la droite**, sur toute la largeur — pas
les 20 pt de bord de l'iOS par défaut. C'est le geste de Spotify sur ses
pages, de Photos, de Music.

- **`.simultaneousGesture` sur la racine de la page, jamais `.gesture`**
  (exclusif, il perdrait contre les 50 `DragGesture(minimumDistance: 0)` des
  galets) **ni `.highPriorityGesture`** (il tue le scroll de ce toucher sans
  pouvoir échouer sur la direction). L'école exacte : le `tirageGeste` de la
  home (`HomeNuit.swift:3157-3186`).
- **Le verrou d'axe se décide UNE fois**, à `max(dx, dy) > 4`, jamais
  retesté par image. Seuil de reconnaissance **12 pt**, pas moins : le
  chevron et les boutons du panneau sont des `Button` nus sous un drag
  d'ancêtre (le stop du 26-08) — ou les taps en
  `highPriorityGesture(TapGesture())`, l'école `WorkoutPill`.
- **Interactif** : la page suit le doigt 1:1 en x ; la home apparaît dessous,
  décalée de −28 % → 0 (la parallaxe du pop de `UINavigationController`),
  sous un voile noir 0,35 → 0. Jamais d'élastique : c'est un pop. **L'offset
  s'écrit par image en `visualEffect` sur un mince enveloppeur de l'hôte**,
  jamais un `@State` de `DuolinguoPage`, jamais un `.offset` du conteneur.
- **« Très sensible »** : la sortie se confirme à **28 % de la largeur** OU
  à **450 pt/s** prédits ; sinon ressort 0,38 / 0,86. Haptique `.light` au
  passage du seuil (une fois), `.soft` à l'atterrissage — la paire de
  l'aller (`.soft` d'`ouvrirChemin`).
- **La seconde sortie, gratuite, au sommet seulement** : le rebond haut
  reste actif en `.paging`, lu **déjà** par la sonde composée
  (`DuolinguoPage.swift:1207`). L'école exacte : « LE REBOND EST LE
  TIRAGE » d'`ExercisesView` (`:1793-1829`, `160·tanh(sur/90)`). La page
  suit (échelle 1 → 0,94, coins 0 → 44), se ferme si le doigt lâche au-delà
  de **90 pt**. Trois filets : la sonde tombe une fois au premier layout sans
  doigt → garder par la phase `.interacting` ; au relâcher UIKit ramène
  l'offset à 0 EN MÊME TEMPS que la phase bascule → **latcher le seuil
  PENDANT le geste** et commettre à la sortie de `.interacting` ; aucun
  `scrollDisabled`.
- **Le chien de garde** : remise à plat sur `startLocation` + jeton 0,30 s
  (`HomeNuit.swift:3159-3174`) — légitime ici, le geste BOUGE (voir §7 pour
  le cas du press immobile). Les deux sources de reduceMotion coupent la
  parallaxe. Le verre (dalle, panneau, lentilles, ET celui de la home) se
  démonte pendant le geste.
- ⚠️ Se juge sur le téléphone, filmé.

---

## 3. LES GALETS ×1,5 — les chiffres, pas l'impression (demande 3)

**Mesuré sur la spec** (`EcranSpec.etapes`, `DuolinguoPage.swift:145`) :
Ø 62, pas vertical 58, sinusoïde lente. Écarts entre bords des voisins de
l'écran 1 (reproduits au fouet au dixième ; les écrans 3, 4 et 5 ont aussi
des négatifs) :

| paire | centres | écart bords |
|---|---|---|
| n0 → n1 | 58,5 | **−3,5** |
| n1 → n2 | 70,1 | 8,1 |
| n2 → n3 | 83,5 | 21,5 |
| n3 → n4 | 71,4 | 9,4 |
| n4 → n5 | 58,1 | **−3,9** |
| n5 → n6 | 73,9 | 11,9 |
| n6 → n7 | 81,8 | 19,8 |
| n7 → n8 | 65,8 | 3,8 |
| n8 → n9 (lune) | 60,5 | **−9,5** |

Trois paires **se chevauchent**. « Compact » n'est pas une impression.

**À ×1,5** (Ø 93, lune 117), sur 874 pt avec la dalle (bas à ≈ 125 pt) :
dix galets par écran est impossible, et **neuf avec la sinusoïde lente
donnent de −22 à −38 pt selon l'écran**. **L'ancienne proposition de
`BUGS-RESTANTS.md §3` (« pas 97, garder la base 10 ») est périmée sur ses
deux chiffres** : au pas 97 le 9e galet monte à y −46 (sous l'île), et
« les ids sautent le 9 » casse quatre sites qui indexent par l'étape.

**Le layout qui donne ≥ 30 pt d'air entre TOUTES les paires**
(`tools/road/layout_x15.py`, recalculé indépendamment au fouet) est le
**serpentin alterné**, la topologie exacte de Duolingo :

| layout ×1,5 | pas | écart min | lune du haut (dalle à 125) |
|---|---|---|---|
| 9/écran, sinus lent | 67,5 | **−22 à −38** | — |
| 9/écran, alterné ±55 | 67,5 | 24,1 | — |
| **9/écran, y 740 → 200, alterné ±60** | **67,5** | **30,0** | 141,5 ✓ |
| 9/écran, lune Ø 105 | 67,5 | 36,0 | 147,5 ✓ |
| 8/écran (6 + 2 lunes), pas 77 | 77 | 37,6 | ✓ |

**Retenu : 9 par écran** — `S1 S2 S3 S4 ☾ S5 S6 S7 ☾`, ou, avec le nœud
PIÈCE demandé le 27-08 (§ 4 bis), **`S1 S2 ¢ S3 S4 ☾ S5 S6 ☾`** (6 séances +
2 lunes + 1 pièce : les 30 pt tiennent ; à 10 nœuds ils tombent à 15-23) —,
y de 740 à 200, pas 67,5, dx = ±60 alterné. **L'amplitude minimale est 58,5** (à 55 : 24 pt) et
au-delà elle ne change plus rien : **le minimum de 30,0 est fixé par le PAS**
(`2 × 67,5 − 105` sur les paires même-côté k/k+2). De la marge = le pas, ou
la lune à Ø 105 (→ 36), ou 8 par écran (→ 37,6). L'organique vient de ±4 pt
de jitter en y et ±6° d'inclinaison par paire, jamais de l'amplitude. La
dalle ne s'échelonne pas par `k` alors que le chemin si : à 852 pt il reste
~11 pt sous la dalle — vérifier sur un sim 852.

**Ce que ×1,5 grossit qu'il ne faut PAS grossir :**
- **Tout le shader est en unités `rr`** (largeurs 0,017 / 0,014 en
  `exp(−(x/w)²)`, `GaletLisere.metal:354, 363`) et le liseré SwiftUI est **∝
  taille** (`GaletEtape.swift:409-422`) : à ×1,5, cheveux et traits
  épaississent ×1,5 — **l'inverse du point 9**. La largeur à 1/e vaut
  aujourd'hui 0,53 pt à Ø 62 (0,79 à Ø 93, 0,99 sur la lune Ø 117) : elle se
  fige **en pt absolus** par le slot libre `divers.y` (voir §5 bis pour la
  convention et le repli obligatoire).
- Le **halo** de l'actif fait D × 2,4 = **223 pt** à Ø 93 : trois voisins
  couverts — contradiction avec « lumière contrôlée » → en pt absolus (~150).
- Le **mois** fait `taille × 0,125` = 7,75 pt à Ø 62 (illisible) → 11,6 à
  ×1,5 : ne pas rescaler les polices à la baisse.
- **La mire `-duoGalets` ment** : elle rend `numero: n + 1` alors que la
  route rend dates / flammes / lune — la réaligner AVANT de juger ×1,5.

**Les pièges du changement (ma première version disait « garder la base
10 » — c'était FAUX) :**
- **Les ids doivent rester CONTIGUS** : quatre sites indexent le tableau
  par l'étape (`EcranSpec.etapes[etat.etape]`, `:804-805`, `:898`, `:905`,
  `:1436`). Donc `id = ecran × 9 + n` (0…44) **et un champ `n` stocké** ;
  les `e.id % 10` (`:792`, `GaletEtape.swift:815`) deviennent `n` ;
  `tresor: n == 8`, `lune: n == 4`.
- **Le jour fantôme** : `etape` compte les ids de lune comme des jours →
  **`etape` saute les lunes**.
- Le panneau (`py ± 116/124`) et l'illumination (`endRadius 72`) sont
  dimensionnés pour Ø 62 → ×1,5 ; `graine: Double(e.id)` change la forme de
  toutes les gouttes (et toutes les graines du portillon §5 bis) ;
  `GaletEtapeLab` en dur (62, `% 10`) ; commentaires périmés (`:140-142`,
  `:771`, `:986`, `:1275`, `GaletEtape:108-109`, `:160`).
- **La cascade de naissance** : 50 `asyncAfter` à 35 ms, chaque
  `nees.insert` ré-évalue les 50 galets (~2 500 corps en 1,75 s, chacun avec
  2 `.blur` de reflet au sol = **100 passes de flou par tour**). À ×1,5 :
  mesurer `-fps` sur la **naissance** — ou lever `nees` par écran.

---

## 4. LES DEUX LUNES — le même overlay, rien de neuf (demande 4)

**Ce qui existe** : une lune par chapitre (`tresor: n == 9`), Ø 78, glyphe
SF `moon.fill` ; l'état `.lune(dispo:)` et **son anneau d'or** quand elle
est disponible (mesuré écran 5) ; `tape()` ne connaît pas le cas lune.

**Ce qu'il reste** (une fois le §1 fait) :
1. `EtapeSpec.lune = (n == 4)`, `moon = tresor || lune` ; `etatDe`,
   `dateDe` lisent `moon` ; `etape` saute les lunes ;
2. `tape(_:)` : **le cas `e.moon` AVANT la garde `e.id == etat.etape`** ; sur
   une lune disponible → `proposer()` **hors de la transaction du geste**
   (`asyncAfter`) et rien d'autre ;
3. **la persistance** : rien ne persiste aujourd'hui → une lune re-tapable à
   chaque lancement = **boosters infinis**. La lune lit **la source qui
   s'écrit en ce moment** (`tools/rewards/PLAN-REWARDS-BACKEND.md`, « 1
   booster = 100 pièces, vu = enregistré ») ; d'ici là, `.lune(reclamee)` en
   mémoire de session ;
4. **la sortie du Sacre ne revient jamais sur la route** (`onCarteEnvolee` →
   `.profile`, `onRetourHome` → `.home`, `homeEclipsee` recrée la home —
   `EtatDuo` est un `@State` de la page, perdu). **Accepter que la route est
   quittée** après un booster (la sortie du parcours, la loi du Sacre), et
   **geler la route sous la pop-up** (elle porte une boucle vidéo ; au-dessus
   de 2-3 lecteurs vivants = 4-5 décodeurs) ;
5. un banc `-duoLune` : le tap Lune n'est pas rejouable au sim.

**Sa matière** : la lune a seule droit à la couleur — l'or (existant). Le
croissant : celui de la MAISON, `GlypheLune()` (`ProfilLune.swift:1060`),
pas le `moon.fill` de SF — ce qui règle le glyphe de `GaletEtape` (une
`String` SF partagée par la flamme et la lune → un `enum`). Verrouillée :
le croissant **en creux** dans le verre sombre, sans liseré. Disponible :
le croissant or, l'anneau d'or 0,85 (existant), le halo 0,62 (existant, en
pt absolus), et **un seul catch-light** qui parcourt l'anneau toutes les
~7 s. ⚠️ `FlammePalette.or` colore aussi ce liseré.

**La question fermée** : la lune du milieu est **passive** (disponible dès
S1-S4 faites, réclamable une fois, le chemin ne l'attend pas) — ou tient le
chemin ? Recommandé : passive — « on ne m'impose rien ».

---

## 4 bis. LE NŒUD PIÈCE — « un icon pièce dans le chemin, en plus de la lune » (27-08)

Sa demande du matin : un galet spécial **pièce**, qui, disponible, **ouvre un
overlay pour gagner X pièces** — le frère de la lune (qui ouvre le booster).

**Ce qui existe pour « gagner des pièces », et où ça vit** (vérifié) :

| brique | ce que c'est | où elle est montée |
|---|---|---|
| `PiecesNotif` | la mini-capsule liquid glass qui descend du haut, le compte qui roule (`depart.notifPieces`) | **la racine**, zIndex 9 (`WoopApp.swift:876`) — visible au-dessus d'une route en arbre |
| `RewardPopup` + robes `RewardStyle` (`halo, neon, galet, spotlight, fire, welcome`) | la card reward ; le token d'atmosphère **REWARD = « noir + lumière chaude + vidéo → bonus pièces »** (`PLAN-REWARDS-BACKEND §`) ; `.welcome` est déjà **un claim** (+20, Welcome Back) | **seulement dans `ExerciseDetailView:1069`** (l'issue de série) — **pas à la racine** : depuis la route, c'est exactement le trou du booster (§1) |
| vidéos `reward-piece-1…5.mp4`, `piece-bravo.mp4`, `piece-sol.mp4`, `CoinChink.wav` | la pièce filmée, le tintement | `Woop/Media` |
| `piece-or-mini` (planche 64 poses), `piece-or`, `piece-argent`, `piece-woop` | la pièce du podium de WIN (elle FLOTTE et se saisit), les glyphes | assets |
| `MoonCoinView` (coffre), `CoffreFortFlow` | la pièce qu'on prend au doigt, la page du trésor | home (cover) |
| le backend | **tout gain = une ligne de `coin_ledger` avec une raison**, claims idempotents par clé — bonus +20 / +30 / +40, plafond 60 par séance | `PLAN-REWARDS-BACKEND §0-2` |

**La forme juste — rien de neuf, deux briques existantes dans le bon
ordre :**
1. **Le tap sur une pièce disponible ouvre la card reward** en atmosphère
   REWARD (une robe **`.piece`** de la famille existante : noir, lumière
   chaude, une vidéo `reward-piece-n` en header — la grammaire de `.welcome`,
   qui est déjà un claim). Le montant est écrit sur la card : « **+40
   pièces** ». Un bouton : « Prendre ». Ce n'est PAS une nouvelle interface :
   c'est la card que la fin de série montre déjà.
2. **« Prendre »** ferme la card → **`PiecesNotif`** descend avec le gain qui
   roule (elle existe, à la racine), `CoinChink.wav`, et **le nœud se grave**
   (§ 5 quater : l'état *réclamée*, le montant en creux).
3. **Le backend** : une ligne `coin_ledger` `raison = 'chemin_piece'`, clé
   d'idempotence **(user, chapitre, rang)** — jamais `session_uuid`, le
   chemin n'est pas une séance. Sans ça, une pièce re-tapable à chaque
   lancement = pièces infinies (le même trou que la lune, §4).

⚠️ **Le même piège que le booster** : `RewardPopup` n'a **aucun hôte à la
racine** aujourd'hui. Depuis une route en arbre il faut un **`RewardHote`**
(le patron exact de `PausePanneauHote` / `BoosterPopupHote` : un état partagé,
un conteneur toujours monté, zIndex 6). Depuis un cover, la card serait
invisible — la loi du §1, encore.

**Sa matière — le disque contre l'anneau.** La couleur est rare et l'or est
à la lune ; une pièce EST or. Pour que les deux ne se confondent pas : **la
lune porte l'or en ANNEAU** (le liseré + le croissant), **la pièce porte l'or
en DISQUE** (la face de la pièce, petite, gravée — `piece-or-mini` pose 0 à
28 pt, ou un disque vectoriel au monolithe Woop) **et n'a pas d'anneau d'or**
: son bord reste le cheveu blanc de la famille. Taille **Ø 80** — entre la
séance (93) et la lune (117) : spéciale, mais la lune reste l'événement.
Verrouillée : la pièce **en creux**, sans or ; disponible : la face or, un
seul catch-light qui la traverse toutes les ~5 s, souffle 0,4 ; réclamée :
**le trou** — la pièce est partie, le montant gravé « +40 » en encre 0,45.

**Le layout — un dixième nœud ne tient pas au ×1,5 :**

| chapitre | nœuds/écran | pas | écart min |
|---|---|---|---|
| S1 S2 ¢ S3 S4 ☾ S5 S6 S7 ☾ (7 séances, ¢ Ø 80) | 10 | 60,0 | **15,0** |
| idem, lunes Ø 105, pièce Ø 72 | 10 | 61,1 | 23,2 |
| **S1 S2 ¢ S3 S4 ☾ S5 S6 ☾ (6 séances)** | **9** | **67,5** | **30,0** |
| S1 S2 ¢ S3 S4 S5 S6 S7 ☾ (¢ remplace la lune du milieu) | 9 | 67,5 | 30,0 |

Trois choix, à elle : **(a) 6 séances + 2 lunes + 1 pièce** (9 nœuds, les
30 pt tiennent — recommandé) ; **(b) 7 séances, la pièce à la place de la
lune du milieu** (9 nœuds, mais elle a demandé la lune avant la 5e) ; **(c)
7 séances + 2 lunes + 1 pièce** en acceptant **23 pt** d'air (lunes Ø 105,
pièce Ø 72). La pièce se place **tôt** (rang 3, après deux séances) : la
petite récompense rapide du chapitre, avant la lune du milieu.

**Le montant** : le plan dit +20 surprise / +30 progrès / +40 fort. Une pièce
de chemin est un jalon, pas un fait : **+40**, ou un tirage +20/+30/+40
(la surprise). Question fermée.

**Questions fermées** : (a) 6 + 2 + 1 à 30 pt, ou 7 + 2 + 1 à 23 pt ? (b)
la card reward (robe `.piece`, hébergée à la racine) ou la seule capsule
`PiecesNotif` ? (c) +40 fixe, ou un tirage ? (d) la pièce au rang 3 ?

---

## 5. FAIT / EN COURS / À VENIR — rare contre continu (demande 5)

**Mesuré** (`mesure_etats.py`, luminance des 10 % de pixels les plus clairs,
jamais une moyenne de ligne) :

| n | état | corps ↑ | anneau ↑ |
|---|---|---|---|
| 0, 1, 3, 4 | accompli | 167 – 186 | 234 – 237 |
| 2 | raté | 58 | 225 |
| 5 | **actif** | 205 | 245 |
| 6 | prochain | 176 | **253** |
| 7, 8 | verrouillé | 148 – 168 | 218 – 229 |
| 9 | lune verrouillée | 80 | 218 |

Accompli contre verrouillé : **15 à 20 points**. Le liseré d'état du 26-08
(`0c7ab1a`, codé **sans verdict**) a changé l'*opacité* d'un anneau dont les
pixels clairs plafonnent déjà. L'affirmation du FAIT **ne peut pas venir des
gains du shader** : `gains.x/gains.y` multiplient tout uniformément (aucune
variation angulaire), le soft-clip `1 − exp(−1,7·lignes)` plafonne, la
fumée est constante (0,52). Deux autres faits : le glyphe flamme du futur
est à **0,85 / 0,90 d'alpha — opaque**, l'inverse de « translucide » ; et
`.parfait` n'est jamais rendu par `etatDe` (état mort).

### 5 bis. LA PRÉCISION DE 22 h 30 — le liseré du PASSÉ, « très fin et pas régulier »

Son screenshot de référence (dalle « CHAPITRE 1 · La braise rouge », 7
galets NUMÉROTÉS 1-7, une braise orange en haut, une goutte rouge en bas)
montre ce qu'elle veut pour les **sessions passées** : des disques de verre
sombre dont le bord n'est **pas un anneau** — un **cheveu d'un pixel qui
n'existe qu'à deux ou trois endroits** (une lampe en haut, un contre-arc en
bas, une perle), mort partout ailleurs ; le corps presque noir, le chiffre
gris ; aucun halo.

**Ce qui rend l'anneau d'aujourd'hui « régulier », dans le code — CONFIRMÉ
au 2e fouet, et complété :**
- le shader pose un **PLANCHER** uniforme sous les lobes : `profExt = 0.45 +
  0.85·lobeL + 0.42·lobeC + 0.55·et1 + 0.40·et2` et `profInt = 0.32 + …`
  (`GaletLisere.metal:352, 362`) — **la seule composante indépendante de
  θ** ; c'est lui, l'anneau plein. Il est né avec `goutteVerre` lui-même
  (`0c82e60`, 25-08, le pivot « pastille-bijou ») ;
- **les étincelles sont HARMONIQUES** (piège que je n'avais pas vu) :
  `et1 = sin(2θ + φ)^10` = deux perles diamétralement opposées, `et2 =
  sin(3θ + φ)^12` = trois perles à 120° exactement (`:347-348`) ; seule la
  phase dépend de la graine — **dans chaque galet le motif est périodique**,
  l'inverse de « pas régulier » ;
- par-dessus, SwiftUI ajoute pour `.accompli` un `Circle().stroke` uniforme
  (0,30, `taille × 0,018`, `GaletEtape.swift:415`), posé à rr 1,00-1,036 —
  **HORS du masque du shader**, L ≈ 77 sur noir : un second anneau régulier
  à 1,2 pt du premier, ils fusionnent à l'œil (`.rate` n'en a pas déjà).

**Ma première spec (« plancher 0, gain 0,6, σ 1,0-1,3 pt ») ne passait pas
son propre portillon — calculé au 2e fouet (python, 50 graines, soft-clip
inclus) :** plancher 0 seul → **73 % du périmètre reste au-dessus de L 60**
et le CV n'est que 0,38-0,75 selon la graine (la moitié des galets recalés).
Cause : le soft-clip × le gain 1,7 (coefficient 2,89·gRim) **aplatit les
lobes larges (cos^3,5 / cos^4) en plateaux**. Retirer le plancher ne suffit
pas : il faut **resserrer les lobes**.

**La spec du PASSÉ, corrigée :**
- **profil réécrit** pour `.accompli` / `.rate` : plancher externe **0**,
  lampe **cos^12** (au lieu de 3,5), contre-arc **cos^14** (au lieu de 4),
  les deux étincelles harmoniques **MORTES**, remplacées par **UNE perle à
  angle seedé** `cos(θ − θet)^40` (θet = f(graine)) ; `gRim` 0,60. Calculé :
  **CV ≥ 1,05 sur TOUTES les graines**, 30-38 % du périmètre > 60, ≤ 8 %
  > 200, pic 203-209 ;
- anneau interne : plancher 0, `0,25·lobeL2` en cos^12 — ou mort. **Un**
  cheveu, pas deux ;
- le `Circle().stroke` de `.accompli` **meurt** ;
- **largeur en pt ABSOLUS — et la bonne convention** : la gaussienne est
  `exp(−(x/w)²)`, l'épaisseur VISIBLE (FWHM après soft-clip) vaut ~2,1·w.
  Pour **1,0-1,3 pt mesurés** il faut `w = 0,48-0,62 pt` — c'est-à-dire
  **figer le 0,53 pt d'aujourd'hui à Ø 62 en absolu** : `divers.y = 0,55 pt`
  (interne 0,45), lu dans le shader comme `float w = divers.y > 0.0 ?
  divers.y / R : 0.017` — **le repli est OBLIGATOIRE** (aujourd'hui l'appelant
  passe 0 : sans repli, `w = 0` → division par zéro → anneau MORT partout
  sans erreur, l'école de la page blanche). Ma « σ 1,0-1,3 pt » aurait rendu
  2,1-2,7 pt visibles — plus épais que ce qu'on fuit ;
- `glowOut` suit `profExt` : plus de bloom entre les cheveux, un souffle sous
  la lampe seule — conforme à « aucun halo » ;
- la **date** reste l'encre du FAIT (jour 0,92, mois 0,60 — 32 / 11,6 pt à
  ×1,5), le corps sombre. ⚠️ Entre les cheveux, sur le noir pur de l'écran 1,
  le disque tombe à **L ≈ 7** (le dôme 0,026 sous la fumée 0,52) : le galet
  ne se lit plus comme un disque, seulement comme deux arcs et une date —
  **c'est sa réf** (« corps presque noir »), mais à valider AU DOIGT avant de
  généraliser aux 4 accomplis × 5 écrans.
- ce que ça change au §5 d'avant : **la « pierre noire opaque à bord fermé »
  est morte**. Le contraste FAIT / À VENIR vient de **rare contre continu**.

**Deux chemins pour y arriver — la réf sur disque tranche.** Le 2e fouet a
daté son screenshot : le titre « La braise rouge » n'a été affiché sur la
dalle que de `f11ade5` à `ea0e67c` (remplacé par « CHAPITRE n » à
`0c82e60`), et des NUMÉROS pointent vers **l'ère `galetLisere`** — le cheveu
de la maison, **σ 0,60 pt ABSOLUS, fondu en cos θ de 44° → 110° (mort sur
les flancs), gain 0,34 pour l'accompli** (`ea0e67c:GaletEtape.swift
lisereShader`), **toujours compilé** (`GaletLisere.metal:70-225`). Mais
« 7 galets » ne colle à aucune ère commitée. Donc :
- **(a) reconstruire la goutte perlée** avec la spec ci-dessus (la v10-v13
  « cheveux perlés » de la mémoire §22 n'existe dans AUCUN commit — née et
  morte non commitée entre `ea0e67c` et `0c82e60` ; ne pas chercher un `git
  show`, seules ses formules survivent) ;
- **(b) rebrancher `galetLisere` sur l'état passé** — le cheveu en pt absolus
  existe déjà, il rend exactement « fin, rare, mort sur les flancs ».
Déposer **`tools/road/shots/ref-passe.png`** AVANT de choisir.

**Portillon mesurable — et sa règle : « fouette, et tant que ce n'est pas
ça, ne reviens pas me voir ».** La session qui codera itère sur capture
contre `ref-passe.png`, et ne montre rien avant que la sonde dise oui :
- profil de luminance **le long de l'anneau** (360 échantillons, bande
  **rr 0,93 → 1,05** — pour attester les DEUX anneaux morts, le stroke vit à
  rr ≥ 1,0) : **CV ≥ 0,6 sur le MIN des 45 graines**, jamais la moyenne
  (la spec calculée donne ≥ 1,05) ; **≤ 40 % du périmètre au-dessus de
  L 60** (35 % est le plancher atteignable avec deux arcs et une perle) ;
- épaisseur = **FWHM de luminance au pic de la lampe : 1,0-1,3 pt** à Ø 93 ;
- corps ↑ ≤ 70, date ↑ ≥ 200 ;
- le futur : **le seuil CV ≤ 0,25 ne discrimine rien** (le prochain
  d'aujourd'hui fait déjà 0,10) — le contraste rare / continu se prouve par
  **l'écart des deux CV, ≥ 0,8** entre passé et futur, pas par deux seuils
  indépendants ;
- le bruit de grille est négligeable (CV 0,017 mesuré en simulation sur un
  anneau uniforme) — aucune correction ;
- mesuré sur noir **et** sur capsule vidéo (le `.plusLighter` s'y délave),
  sur OLED.

### 5 ter. Les trois matières, corrigées

- **À VENIR = le verre à l'anneau CONTINU.** « Bordures beaucoup plus
  claires » : c'est ici que le plancher vit — et monte (0,45 → 0,70 pour le
  `.prochain`, 0,55 pour les lointains), en **double cheveu** (les deux
  surfaces d'un anneau de verre), en pt absolus (w 0,55 externe, 0,45
  interne). Le disque est creux : la lentille native `.clear`, la fumée
  baissée à 0,20. La flamme est un **contour** (§8) à **alpha 0,35-0,45**,
  pas 0,85. Cibles : anneau ↑ ≥ 245, corps ↑ ≤ 70, et l'écart de CV ≥ 0,8
  avec le passé.
- **FAIT = le verre sombre au cheveu RARE** (§5 bis). Date gravée claire,
  corps sombre, aucun halo.
- **EN COURS = la nacre.** Le halo 0,55 (mesuré +32,9) **en pt absolus**
  (~150, pas 223), taille ×1,08, la date du jour — et son panneau (§6).
- **RATÉ** : le verre sombre, l'encre à 0,22 (existant), les lobes à 0,35.
- **LUNE** : §4.

La tension « bordures plus claires (5) / liseré fin (9) » se résout **par
état** : clair et continu pour le futur, rare et fin pour le passé. Et
**« l'impression que l'étape a réellement été validée »** se joue au moment
de la validation : au retour de séance, le verre du jour **s'assombrit**
(fumée 0,20 → 0,52, 0,6 s), l'anneau continu **s'éteint en cheveux** (le
plancher tombe, les lobes se resserrent), la date **se grave**, une
étincelle d'or, haptique `.rigid`. La cérémonie de session du §21, à
brancher avec le flow de fin.

### 5 quater. LE CATALOGUE DES ÉTATS — « décris-moi tous les états » (27-08)

Trois familles de nœuds, et pour chacun : la matière, le bord, l'encre, la
lumière, le mouvement, la réponse au tap, la réponse au port. Les chiffres
sont la spec (à mesurer au portillon §5 bis) ; ce qui est **existant** est
marqué.

**A. Les nœuds SÉANCE (Ø 93)**

| état | quand | matière · bord | encre | lumière · mouvement | tap | port |
|---|---|---|---|---|---|---|
| **verrouillé** (lointain) | futur, > 1 rang après l'actif | verre creux (lentille native, fumée 0,20) · anneau **continu**, plancher 0,55, double cheveu w 0,55 / 0,45 pt | flamme **contour** `flame` .ultraLight, alpha 0,35 | aucune ; immobile | **refuse** : liseré froid 0,12 s, haptique `.rigid`, rien ne bouge (existant) | non — un caillou |
| **prochain** | le rang juste après l'actif | idem, plancher **0,70**, + un catch-light | flamme contour alpha 0,45 | aucune ; immobile | refuse (existant) | non |
| **actif** (aujourd'hui) | `etape == id` | nacre : fumée 0,52, anneau continu plancher 0,45 (existant) | **la date du jour** — jour 0,98 à 32 pt, mois 0,60 à 11,6 (existant, rescalé) | **halo blanc 0,55 qui respire** (`LaunchPebble.breath`, mesuré +32,9) en **pt absolus ~150** ; taille ×1,08 | **ouvre le panneau** (§6), press → fumée + `.medium` (existant) | oui — ressort au lâcher |
| **accompli** (fait) | passé + `faits` | verre sombre : fumée 0,52, **plancher 0,13** (28-08 — voir ci-dessous), lobes cos¹²/cos¹⁴ + **une perle seedée**, gain 1,0, w 0,55 pt absolu | **sa date** — jour 0,92, mois 0,60 | **aucun halo**, aucun anneau SwiftUI ; corps L ≈ 7 entre les cheveux | ouvre **sa story** (la séance passée — à brancher, D2) ; press existant | oui |
| **raté** | passé + non fait | idem accompli, lobes à 0,35 | sa date en **fantôme 0,22** (existant) | rien | rien (ou la story vide « pas de séance ce jour ») | oui, plus lourd (0,6·d) ? — question |
| **parfait** (record) | jamais rendu aujourd'hui (`.parfait` mort dans `etatDe`) | accompli + **le souffle d'or** dans la nappe basse (`chaud 0,5`, existant) | sa date | rien | sa story | oui |

**B. Le nœud LUNE (Ø 117) — l'or en ANNEAU**

| état | quand | matière · bord | glyphe | lumière | tap |
|---|---|---|---|---|---|
| **verrouillée** | les séances d'avant ne sont pas toutes faites | verre sombre, plancher 0,20 blanc (le plus sombre du chemin, existant `0,72`) | croissant `GlypheLune` **en creux**, alpha 0,42 (existant) | aucune | refuse (existant) |
| **disponible** | S1-S4 faites (milieu) / le chapitre fini (fin) | **anneau d'or 0,85** (existant), plancher 0,55 | croissant **or** | **halo 0,62 qui respire** (existant, pt absolus) + **un catch-light** qui parcourt l'anneau ~7 s | **`SacreEtat.shared.proposer()`** hors transaction → la pop-up booster existante (route en arbre, §1) |
| **réclamée** | après le booster | anneau d'or **éteint** 0,30, croissant gravé en creux or 0,35 | croissant or sourd | aucune | rien (ou rouvre la collection) |

**C. Le nœud PIÈCE (Ø 80) — l'or en DISQUE**

| état | quand | matière · bord | glyphe | lumière | tap |
|---|---|---|---|---|---|
| **verrouillée** | les séances d'avant pas faites | verre sombre, cheveu blanc de la famille (pas d'or) | la pièce **en creux**, alpha 0,42 | aucune | refuse |
| **disponible** | les séances d'avant faites | idem, cheveu 0,45 | **la face or** (`piece-or-mini` / disque au monolithe) | catch-light qui traverse la face ~5 s, souffle 0,4 | **la card reward robe `.piece`** (`RewardHote` à la racine) → « Prendre » → `PiecesNotif` + `CoinChink` + ligne `coin_ledger` |
| **réclamée** | après « Prendre » | **le trou** — un creux net, la pièce est partie | « **+40** » gravé, encre 0,45 | aucune | rien |

**D. Les états transitoires — ils s'ajoutent aux précédents**

| état | ce qui se passe | loi |
|---|---|---|
| **en naissance** (cascade) | échelle 0,92 → 1, opacité 0 → 1 (existant), 35 ms d'écart | ⚠️ opacité 0 mais **hit-testable** (existant) → `allowsHitTesting(nee)` ; la lentille native ignore l'opacité (à mesurer sous `compositingGroup`) |
| **pressé** | échelle 0,97 (0,99 verrouillé), tilt 4° vers le doigt, fumée 3 volutes, haptique `.medium` (existant) | ⚠️ le press annulé par le scroll reste posé (**bug latent**) → `@GestureState` |
| **porté** (le jouet, §7) | après t ms de maintien : ×1,06, ombre élargie, devant (zIndex > 5), lentille coupée, suit le doigt (élastique), `scrollDisabled` | seuls actif / accompli / lune et pièce disponibles ; borné sous la dalle |
| **posé** (le lâcher) | ressort 0,55 / 0,58, un dépassement, poussière, `.soft` | jamais deux `withAnimation` ; coupé sous reduceMotion |
| **sous projecteur** | panneau ouvert : tous les autres à 0,45, lentille coupée | le couple actif + panneau est le seul objet allumé |
| **en refus** | verrouillé tapé : liseré froid 0,12 s, `.rigid`, immobilité (existant) | la grammaire du refus — jamais un mouvement |
| **hors écran** | l'écran voisin, en voyage | lentille coupée hors ±1 écran (budget verre, existant) |

**E. Le panneau de départ (§6)** : *né* (scale depuis le galet, 0,42 s) ·
*ouvert* (le projecteur, la mini-card du jour, Commencer / Plus tard) ·
*résorbé* (Plus tard : retour dans le galet, 0,22 s) · *libéré* (Commencer :
0,18 s puis la séance) · *fermé par le port* (|translation| > 12).

**Ce que le catalogue tranche d'un coup d'œil** : le futur est **clair et
continu**, le passé **rare et fin**, l'aujourd'hui **respire**, l'or n'existe
qu'en anneau (lune) ou en disque (pièce), et **rien ne bouge sans le doigt**
sauf le halo de l'actif et le catch-light des nœuds disponibles.

### 5 quinquies. L'ANNEAU DU PASSÉ SE FERME — « les faites font trop EMPTY » (28-08)

À `plancher = 0`, un jour fait n'avait **que** deux lobes et une perle posés
sur du vide : mesuré, le creux de son anneau tombait **SOUS le fond**
(−16 et −6) — le galet lisait comme un TROU, pas comme une pierre, alors que
le catalogue promettait un « corps L ≈ 7 entre les cheveux ».

Le remède n'est pas de rendre le bord plus clair (ça le rend RÉGULIER, et sa
loi du 26-08 à 22 h 30 dit « très fin et **pas** régulier »), c'est de le
**fermer très bas**. Trois valeurs mesurées, pic et creux exprimés en écart
au fond, CV = irrégularité le long de l'anneau :

| plancher | pic | creux (l'anneau se ferme ?) | CV |
|---|---|---|---|
| **0** | 94 / 103 | **−16 / −6** — un trou | 0,55 / 0,82 |
| 0,22 | 109 / 106 | +51 / +48 | **0,25** — presque lisse, mord sur l'actif |
| **0,13** ✅ | 107 / 105 | **+34 / +30** | **0,41 / 0,37** |

L'échelle complète à 0,13, et elle est monotone sur les TROIS grandeurs :

| | actif | fait | à venir | lune éteinte |
|---|---|---|---|---|
| pic (clarté) | 151 | 107 / 105 | 77 / 73 | 62 |
| creux (l'objet existe) | 125 | 34 / 30 | 8 / 1 | −14 |
| CV (irrégularité) | **0,04** plein | 0,37-0,41 | 0,68-0,89 rare | 1,00 |

⚠️ **C'est le CV qui protège l'actif** : aujourd'hui reste le SEUL anneau
plein du chemin (0,04). Le passé s'en tient à dix fois plus d'irrégularité —
il existe, il ne prétend pas.

⚠️ **RESTE PRÉVU ET JAMAIS RENDU** : `.parfait` et son **souffle d'or** —
`etatDe` ne le renvoie jamais (`faits.contains ? .accompli : .rate`). C'est le
levier « plus voyant » encore disponible pour le passé, et il attend une
source : qu'est-ce qu'un record ?

---

## 6. LE PANNEAU NAÎT DU GALET (demande 6)

**Mesuré** (`shots/road-1-branchee.png`, chiffres affinés au fouet) : le
panneau est posé à `x: largeur / 2` (`DuolinguoPage.swift:828`) — le centre
de la page — alors que le galet actif est à x 270,5 : **69,5 pt de
décalage**. Posé à `py − 116` avec **≈ 118 pt** de haut, il couvre **n2 en
entier, n1 et n3 à moitié**. Une carte indépendante posée sur la route.

**Ma première proposition — une bulle LATÉRALE à bec — est morte au
fouet** : le serpentin d'aujourd'hui n'alterne pas ; même alterné, une bulle
de 118 pt à la hauteur d'un galet de 93 mord son voisin k±1 — **à cette
densité il n'existe aucune place libre pour 118 pt** ; le bec contredit une
décision écrite (`PLAN-BRANCHEMENT.md:96-99`, B3 : « PAS de queue de bulle
— la proximité fait l'ancrage ») ; « la vraie mini-card » interdit de
raccourcir sous ~110.

**La forme juste : le panneau ne cherche pas une place libre, il fait lire
qu'il VIENT du galet.** Quatre liens, et **ce que le 2e fouet a corrigé
dans chacun** :

1. **La position.** Lire `px/py` UNE fois (`:806-807`) et poser `x:
   clamp(px, 148 + m, largeur − 148 − m)`, `y: py ± offset × k` (les
   offsets 116/124 ne sont pas × k aujourd'hui alors que `py` l'est).
   ⚠️ **Le clamp n'absorbe que ±40-45 pt** (panneau 296 sur 393-402) alors
   que dx va à ±92 : résidu 17-21 pt à dx ±62, 47-52 à ±92. Pour |dx| > 45,
   ce sont **le halo et la naissance qui portent l'ancrage** — ou le panneau
   se resserre / inverse son flanc mini-card côté galet.
2. **La lumière partagée.** `LaunchPebble.breath` est une **fonction pure de
   t** : deux vues sont en phase gratuitement. Le halo de page (`:808-817`)
   atteint DÉJÀ l'arête proche du panneau mais n'y vaut que ≈ 0,03 sous une
   pellicule 0,32 qui mange un tiers : **l'étirer est un réglage
   d'intensité et de rayon, mesuré sur les pixels clairs**, pas de
   géométrie. Le halo respirant de l'actif (0,55, sous le verre) reste ; le
   contenu doux qui bouge sous un verre immobile est légal — **jamais faire
   respirer le verre**.
3. **La naissance — et un glissement caché.** L'ancre hors de [0, 1]
   FONCTIONNE (mesuré sur `_ScaleEffect`), mais la question était mal
   posée : la `.transition` est posée APRÈS `.position`, et `.position`
   remplit la taille de son parent — **la colonne entière (largeur × 5h)**.
   L'actuel `.scale(0,88)` s'ancre donc au centre de la colonne : **le
   panneau part 192-230 pt SOUS sa pose et remonte pendant le ressort**,
   caché par l'opacité 0 du départ. La forme juste : garder la transition
   après `.position` et donner l'ancre dans ce frame — `UnitPoint(x: px /
   largeur, y: py / (5 × hauteur))`, dans [0, 1], sans connaître la hauteur du
   panneau. Filmer `-homeChemin` à +2,1 s pour voir le glissement actuel.
4. **Le projecteur — et le voile.** `.opacity(0,45)` sur la matière peinte
   (`:797`) ET `lentille: … && !(departOuvert && e.id != etape)` (`:791`)
   pour le verre — le `verreDemonte` de la route. ⚠️ « Le verre ignore
   `.opacity` » a été mesuré HORS `compositingGroup` ; dans `GaletEtape` la
   lentille vit DANS un `.compositingGroup()` (`:343`) — deux cas non
   mesurés (elle réfracte encore → fantôme ; elle est déjà aplatie → le
   budget verre paie pour rien). **Mesurer** au banc `-duoLab -duoEcran 2
   -duoFreeze`, opacité 1 vs 0,45 sur un galet de bord au-dessus de la vidéo.
   Le voisin couvert, éteint, vu au travers d'un verre `.clear` à pellicule
   0,32 : le panneau ne cache pas, il voile.

**Ce qui compte plus que le lien — corrigé au 2e fouet :**
- **Le panneau naît HORS ÉCRAN** dès que l'actif n'est pas sur l'écran 1 :
  `ecranInitial` vaut toujours 0 en app, `naissance()` ne scrolle jamais.
  **Pas un `scrollTo` dans `naissance()`, et surtout pas animé** : la phase
  tombe (mesuré P0.2) → dalle démontée, feux voilés, thock ; un balayage
  ≥ 2 écrans réveille des lecteurs en vol (§19, écrans noirs). **La cible se
  DÉRIVE de l'étape** (`EcranSpec.etapes[etape].ecran`) et passe par le
  chemin existant de `onAppear` : `piloter(y: cible·h)` puis `ordre.scrollTo`
  **non animé avant le premier rendu** (`:1248-1250` — le chemin que
  `road-3-tresor-ecran5.png` prouve) ; `ecranInitial` cesse d'être un second
  paramètre à tenir en accord (une source). Et **conditionner la naissance à
  +2,1 s** à « posée sur l'écran de l'actif, `enGeste == false` » — elle est
  inconditionnelle aujourd'hui : un scroll pendant la cascade fait naître le
  panneau hors écran, même à l'étape 0.
- **Ma « date gelée » était FAUSSE** : `PanneauDepartChemin.jour/mois` sont
  des `static let` **MORTS** (aucune référence) ; la date affichée vient de
  `MiniCardJour(date: Date())`, vivante, même source que le galet. **À
  supprimer** (code mort au commentaire trompeur). La seule double source
  réelle est le **formateur du jour** : la mini-card écrit « 26. »
  (`SemaineStrip.jour`) et le galet « 26 » — visible sur `crop-panneau.jpg`.
  Un seul formateur.
- Fermeture : rien au scroll (le panneau défile avec le galet, c'est
  voulu) ; au tap d'un autre galet, un choix. `.shadow(radius: 20)` sur du
  verre natif = une passe hors écran.

**Les pièges du verre, tous payés** : taille CONSTANTE ; encre et boutons
HORS du conteneur (la recette actuelle) ; jamais `glassEffectUnion` ; le
panneau reste dans l'overlay posé APRÈS le `.compositingGroup()` ; scheme
`.dark` ; pas de seconde `TimelineView`. Tout galet sous le panneau est
intappable (zIndex 5) — acceptable, le panneau est modal.

**Question fermée** : le bec reste mort, B3 tient ? Recommandé : oui.

---

## 7. LES GALETS QU'ON DÉPLACE — la pierre au bout d'un élastique (demande 7)

**⚠️ Le point 7 est écrit DEUX fois dans le dépôt, à l'envers l'une de
l'autre.** `BUGS-RESTANTS.md:394-423` cite son verdict du midi — « les
galets ne sont **pas** draggables, on peut conserver une très légère
réaction physique » — et conclut « ne pas toucher `GaletEtape` ». Le soir
elle dicte l'inverse : « je veux qu'on puisse les déplacer partout et quand
je relâche elle s'anime et se replace ». **L'audit prend le verdict du soir**
— à lui faire confirmer avant tout code.

**Vérifié** : les galets de la route **ne bougent pas** (aucun offset, un
`scaleEffect` de 3 % et un tilt de 4°). Leur `DragGesture(min 0)` porte le
press, la fumée, les haptiques, le refus ET le tap. Le galet qui se promène
est celui du **menu** (`GaletMaison`, seuil 5 pt, borné à 8 pt du bord, hors
ScrollView) — et il revient par une **CHUTE** (`lacher()`,
`timingCurve(0.55, 0, 1, 0.45)` + écrasement), pas par un ressort.

⚠️ **Le bug latent est CONFIRMÉ par le code** (2e fouet) : `presseDepuis`
n'est remis à nil QUE dans `onEnded` (`GaletEtape.swift:178`) ; un drag
annulé par le pan laisse le galet à 0,97, tilté vers le dernier `doigt`, et
sa `TimelineView` tourne à chaque image (`:197-206`). Il ne se guérit qu'au
prochain toucher **du même galet** ; invisible au sim, cumulable après
chaque scroll né sur un galet. **Et le chien de garde de la home (jeton
0,30 s) n'est PAS le bon remède ici** : il suppose un geste qui bouge — un
press est immobile, un `DragGesture` ne rappelle pas un doigt immobile, le
minuteur relâcherait un maintien légitime (la molette a payé la même leçon,
à 0,6 s). **Le remède minimal, sans horloge** : (i) en tête d'`onChanged`,
`if debut != g.startLocation { debut = g.startLocation ; presseDepuis = nil }`
— guérit le toucher suivant ; (ii) un `@GestureState private var tenu` posé
par `.updating` sur le drag existant — il retombe à `false` quand le geste
finit OU est annulé, c'est sa raison d'être — et `.onChange(of: tenu)` libère
le press. Zéro minuteur, et il couvre aussi l'annulation par le port. À
confirmer d'un `print` au téléphone que `@GestureState` retombe bien sur
l'annulation par le pan.

**Le jouet — la forme corrigée aux deux fouets.** Ma première version disait
`LongPressGesture.sequenced(before: DragGesture)` nu : elle contredisait une
loi payée **trois fois** (« un `onLongPressGesture` même à 0,01 s VOLE le
tap qui le suit »). Mais dans un ScrollView `.paging`, un `DragGesture(min
0)` nu ne peut PAS porter, un `DragGesture` nu en `highPriorityGesture` sur
50 galets **tuerait le scroll**, et l'alternative maison `CardTouche`
(rendez-vous à l'horloge) **échoue dans un scroll** : elle décide à l'horloge
contre un état que l'annulation par le pan laisse périmé → un port qui naît
sur une page qui scrolle et un `scrollDisabled` en plein scroll (la loi payée
d'`ExercisesView`). La seule forme qui arbitre **dans le moteur de gestes,
par le temps ET la distance** :

- **Deux gestes sur le galet, chacun son rôle.** Le `DragGesture(min 0)`
  existant en `.gesture` garde le press, la fumée au contact, les haptiques,
  le refus et le tap court. Le port est une `LongPressGesture(minimumDuration:
  t).sequenced(before: DragGesture(minimumDistance: 0))` en
  **`highPriorityGesture`** — avant le maintien, le scroll garde la main
  (le LongPress échoue si le doigt bouge > 10 pt avant t) ; après, le galet
  est porté. **Aucun précédent exact dans la maison** (jamais highPriority +
  gesture sur la même vue, jamais un LongPress prioritaire sous un
  ScrollView) — plausible, soutenu par deux observations, **à trancher au
  téléphone**.
- **Le port répare ce qu'il casse** : à t la séquence ANNULE le drag bas
  sans `onEnded` → le `@GestureState` ci-dessus libère le press ; l'`onEnded`
  du port **ré-émet le tap** (ou le refus) quand la course est courte —
  `.second(true, nil)` (doigt jamais bougé après t) compte comme course 0, et
  la course du drag second part du point à t : « < 12 pt » tolère jusqu'à
  22 pt depuis le contact. Le premier rappel `.second(true, nil)` = « porté,
  translation zéro » : l'haptique de prise.
- **Le seuil t — à juger au téléphone EN PREMIER** : 0,14 s est **sous tous
  les seuils de maintien de la maison** (0,18 / 0,24 / 0,50 / 0,55) et **dans
  la durée d'un tap appuyé** — chaque tap lent paierait la prise (×1,06 +
  `.medium`) 140 ms après le `.medium` du press, puis le tap ré-émis. Repli
  **0,18-0,22 s** ; trancher quelle haptique porte la prise. Le compromis,
  dit : un swipe plus lent que 10 pt / t (71 pt/s à 0,14) devient un port.
- **La portabilité** : ne pas monter/démonter le modificateur selon l'état —
  `.highPriorityGesture(seq, including: portable ? .all : .subviews)`
  (l'école `ProfilLune.swift:600`) ; **jamais `.none`** (il éteindrait aussi
  le drag bas). **Seuls FAIT, ACTIF et la lune disponible se portent** — la
  loi du refus (`GaletEtape.swift:14-16`) : un verrouillé refuse par
  l'immobilité.
- **La prise** : ×1,06, ombre élargie, et le galet **passe devant** — le
  ZStack est ordonné par id : `.zIndex` posé par `CheminDuo` (`porte: Int?`
  dans `EtatDuo`, deux écritures par port), **> 5** (le panneau). ⚠️ **La
  dalle est un overlay AU-DESSUS du scroll** : rien ne passe jamais
  au-dessus d'elle — borner la course sous la dalle. Pendant la cascade, un
  galet non né est à opacité 0 mais hit-testable.
- **L'offset** : DANS `GaletEtape`, **AVANT** `contentShape` / `gesture` /
  `highPriorityGesture` (l'ordre du galet du menu, `MenuNappe.swift:1434-1447`)
  — posé après, il déplacerait le repère `.local` du drag avec la vue
  (translation qui s'auto-alimente) ; ou `coordinateSpace: .global`. Dans un
  `@State` du galet seul, jamais dans `EtatDuo`.
- **Le port** : loi élastique — 0,85 × d jusqu'à 120 pt, puis `120 +
  60·ln(1 + (d − 120) / 60)`. Le tilt suit la vitesse (≤ 8°). **La lentille
  native se coupe** (le verre qui bouge : 60 → 14). `.scrollDisabled` pendant
  le port : légal (précédent validé `ProfilLune.swift:149/620`, écrit DANS
  le `onChanged` d'un drag prioritaire) — une ceinture contre un second
  doigt, jamais posée depuis un rendez-vous à l'horloge. Le panneau ouvert se
  **ferme** dès que |translation| > 12.
- **Le lâcher** : ressort `0,55 / 0,58` — **un** dépassement, une pincée de
  poussière (`PebbleDust`), haptique `.soft`, durée coupée sous reduceMotion
  (les deux sources). Jamais deux `withAnimation` au même tour.
- **Le repli si SwiftUI échoue au téléphone** : la forme déterministe est
  UIKit — un `UILongPressGestureRecognizer` (0,14-0,18 s, `allowableMovement`
  10) hébergé par un representable avec delegate (l'école
  `BoosterLab.swift:1298-1310`) : le mécanisme même du réordonnancement des
  `UICollectionView`, le pan attend l'échec du maintien.
- **Le protocole téléphone** (filmé, `-fps`) : swipe rapide né sur un galet →
  scroll intact, sans retard perceptible ; swipe lent → port (le compromis) ;
  tap court → panneau ; maintien immobile 0,3 s puis lâcher → tap ré-émis,
  UNE seule ouverture ; maintien + déplacement → port, retour ressort, un
  dépassement ; scroll né sur un galet → vérifier qu'il n'est PAS resté
  enfoncé (`print` dans `pauseTimeline`).

**Questions fermées** : (a) c'est bien le verdict du soir (le jouet), pas
celui du midi ? (b) seuls fait / actif / lune disponible se portent ? (c) le
retour = **ressort** (un bijou qui se pose) alors que le galet du menu
**tombe** — deux grammaires, ou l'une s'aligne ?

---

## 8. LA FLAMME — un symbole, pas une illustration (demande 8)

**Aujourd'hui, cinq flammes, quatre grammaires** (élargi aux deux fouets) :

| où | quoi | fichier |
|---|---|---|
| galets à venir | SF `flame.fill`, 16 pt, `.regular`, alpha **0,85-0,90** (opaque) — `String` partagée avec `moon.fill` ; **44 à la fois** | `DuolinguoPage.swift:783`, `GaletEtape.swift:471` |
| mini-card (home, panneau, **menu, calendrier, story, carnet**) | `sticker-flamme` — PNG 384 px **emoji orange**, 71 % de marges vides ; **un sticker de CATÉGORIE d'une famille de 7** (`WoopSticker`), nommée de **trois façons** (l'enum, la table `SemaineStrip.stickers`, des littéraux nus) | `HomeNuit.swift:1272`, `MenuNappe.swift:879`, `CalLab`, `StorySuite`, `CarnetLab/Scene` |
| étage 11-19 pt (jauge exo, partition, story) | `sticker-flamme-serree` — le crop EXACT (bbox + 2 px) du PNG orange, puis Lanczos 2/3 et 1/3 (mesuré au pixel) ; **le script n'a jamais été commité** | `FlammeJauge.swift:1198-1301`, `b110608` |
| rail de la dalle | SF `flame.fill`, 11 pt, gris 0,60, en PAIRE avec la lune — « factice, inerte » | `DuolinguoPage.swift:1007` |
| card reward `.fire` | `sticker-flamme-noir` (PNG 1233 × 1276, **laque noire + liseré blanc**, 158 pt) — et **sa gerbe de 42 grains utilise le sprite ORANGE** | `RewardCard.swift:1333`, `:1397` |

L'emoji orange est le cartoon qu'elle refuse partout ailleurs — **et ses six
sœurs avec** ; la flamme noire est déjà la grammaire de la maison, mais
**6,29 Mo décodés**, un liseré à 0,9 px à 36 pt, et un bitmap ne sait pas
être translucide.

**Apple premium = une silhouette, une matière, la profondeur par la lumière
et jamais par le trait.** Deux chantiers, que ma première version
confondait — et deux corrections du 2e fouet :

**A. Sur la route.** **Mon « levier gratuit » était un no-op** :
`.symbolRenderingMode(.hierarchical)` sur `flame.fill` rend le pixel
IDENTIQUE (mesuré : une seule couche, diff 0 à trois poids), et `.light` ne
bouge que 1 % des pixels. Le seul réglage vivant est l'alpha — déjà porté
par `GaletEtape.swift:441-479` : ajouter un cas glyphe-futur à **0,40** en
**remplaçant** l'alpha d'état (pas en l'empilant : 0,34 effectif sinon). **Le
vrai levier gratuit de la robe `.verre`** : le **contour `flame`** (pas
`flame.fill`) à `.ultraLight` / `.thin` — 2 274 px couverts, alpha moyen 162
contre 5 480 / 238 pour le plein : **le cheveu seul, le fantôme d'une
flamme**, sans composant neuf — à essayer sur la route AVANT tout
`FlammeBijou`. `FlammeBijou` (une `Shape`, laque obsidienne, cheveu d'un
point par la normale, un catch-light) reste **réservé à `.braise`** —
l'actif, le streak : la langue interne allumée, or → cœur, le seul endroit
avec de la couleur et la seule micro-vie (pointe ±3° à 0,13 Hz, **aucun
point posé sur la matière**). Le glyphe vit déjà dans le `compositingGroup`
du galet (deux flous) : son coût marginal est nul, celui du galet ne l'est
pas — `-fps` avec 44 flammes. Bannir `.shadow` / `.blur` / `.mask` dans le
petit étage. Le rail (11 pt sur pellicule noire) reste une encre claire,
factice : on ne le touche pas.

**B. Les stickers — une FAMILLE, et un chantier de LAYOUT, pas seulement
de contenu.** `MiniCardJour` est data-driven : un cas vectoriel pour la
flamme créerait une **quatrième** famille. La forme juste : **re-forger les
7 stickers ensemble** en laque noire + liseré (la flamme noire de la card
reward est le prototype), en bitmaps **pré-rognés à la boîte utile,
1x/2x/3x**. Mais le 2e fouet a lu le pipeline : **`detoure_booster.py` ne
fait que le DÉTOURAGE** (entrée unique codée en dur, masque lum > 6,
fermeture, `fill_holes`, plus grande composante, une coupe du bas +
re-soudure par colonnes **propre aux crans de la pochette** — sur une flamme
elle déforme la pointe et bouche une langue ajourée), et **sort UN 1x à la
résolution source (794 × 1278, 4,06 Mo décodés) avec les slots 2x/3x
VIDES** : iOS servirait le 1x partout, exactement le coût que `b110608` a
tué. **L'étage 1x/2x/3x pré-rogné de `serree` est un crop bbox + 2 px puis
Lanczos 2/3 et 1/3 — un script jamais commité, taillé pour 19 pt** : il faut
l'écrire, coupé pour le plus grand site (≥ 474 px @3x, ~6,3 Mo pour 7) ou en
deux jeux petit / grand. Si la forge sort du transparent, aucun détourage.
Les implications : (1) les noms doivent survivre aux trois façons de
nommer ; (2) **~8 sites sont calibrés sur les marges actuelles (29-47 %)**
— home 36 pt « tranché à mi-corps », menu `0,42·côté`, calendrier
`0,52/0,34·s`, CineBilan 120, story `0,44·l`, carnet 54 : pré-rogner
agrandit le glyphe visible de ×1,46 à ×1,86 et déplace les centres → **8
recalages sur capture** ; (3) la gerbe `.fire` exige une flamme ORANGE →
garder l'asset orange sous un autre nom ou exclure la gerbe ; (4) le
détourage par silhouette n'existe que si le liseré ferme le contour sur
noir pur. **Coût réel : 7 forges + 1 script + 8 recalages.**

**Question fermée** : la famille de 7 se re-forge ensemble — ou la flamme
reste orange partout sauf sur la route ? Recommandé : la famille, en
connaissant son coût.

---

## 9. LE DESIGN, EN UN MOT — « la route de pierres noires »

Ce que les huit points et la précision dessinent ensemble : une route de
**pierres de verre sombre** dans le noir, pas un collier de perles. Trois
matières et rien d'autre — le verre à l'anneau continu de ce qui vient, le
verre au **cheveu rare** de ce qui est fait, la nacre du jour. Une seule
couleur, l'or, réservée à la lune ; une seule chaleur, la braise de la
flamme vive. Des cheveux de lumière d'un point — **en points absolus, la
taille ne les épaissit jamais** ; l'air entre les pierres (30 pt) est le
luxe. Le panneau **naît** de son galet et la route s'éteint autour d'eux.
La sortie est un geste, pas un bouton. Et la pierre qu'on soulève retombe
à sa place, comme une pierre.

---

## 10. L'ORDRE DE BATAILLE — un jalon, un banc, un portillon, une question

| # | jalon | banc | portillon mesurable |
|---|---|---|---|
| 0 | **Le prérequis** : `etape` câblé sur les séances (D2) + banc branchée + étape > 0 (`-homeChemin -duoEtape n`) + **`ref-passe.png` sur disque** | `-homeChemin -duoEtape 5` | les 5 états + panneau + dates visibles ENSEMBLE, branchés |
| 1 | **`CheminHote`** — la route en arbre, UN hôte (l'overlay `HomeNuit:2200` retiré), clé de sommeil neuve sur ~12 horloges (vidéos à rate 1), départ à la racine (garde de `ouvrirSeanceEnBase`, branche `enSeance && tiroirOuvert`), `-homeChemin`/`-duoEtape` au `.task` racine | `-homeChemin -fps`, `-skipAuth -homeChemin -boosterPopup` | ≥ 58 img/s posée (étiquette `duo`) ; pire cas = le geste de sortie ; la pop-up booster **visible** au-dessus |
| 2 | **Layout ×1,5** — 9/écran, alterné ±60, y 740 → 200, **ids contigus + `n`**, `etape` saute les lunes, largeurs (`divers.y` avec repli) et halo en **pt absolus**, mire réalignée | `-duoGalets`, sim 852, `-fps` naissance | écart min **≥ 30 pt** ; FWHM 1,0-1,3 pt à Ø 93 ; naissance sans trou > 33 ms |
| 3 | **Les matières** — passé = cheveu rare (profil réécrit cos^12/14 + une perle seedée, plancher 0, stroke mort) OU `galetLisere` rebranché — la réf tranche ; futur = anneau continu ; flamme = contour `flame` 0,4 | `-homeChemin -duoEtape 5 -duoFreeze` | **CV passé ≥ 0,6 sur le MIN des graines, écart passé/futur ≥ 0,8**, ≤ 40 % du périmètre > 60, bande rr 0,93-1,05 ; corps ≤ 70 ; date ≥ 200 ; = `ref-passe.png` — **sinon on ne montre pas** |
| 4 | **Le panneau qui naît du galet** — cible dérivée de l'étape, `piloter` + `scrollTo` non animé avant le premier rendu, naissance conditionnée, clamp × k, ancre `(px/largeur, py/5h)`, halo réglé à la sonde, projecteur mesuré sur la lentille, `static let` morts supprimés, un formateur du jour | `-homeChemin -duoEtape n`, `-duoEcran 2 -duoFreeze` | né à l'écran ; plus de glissement caché à +2,1 s ; centre à ±4 pt du px clampé ; halo sur l'arête ≥ +20 |
| 5 | **Le geste** — glissement droite (simultané, verrou d'axe, 12 pt, `visualEffect`) + tirage au sommet (latch en phase) ; verre démonté des deux côtés | téléphone, filmé | 0 flash ; sortie < 0,4 s ; chevron et boutons tappables |
| 6 | **Le jouet** — `@GestureState` sur le drag existant D'ABORD (le bug latent), puis le port (séquence prioritaire, t 0,18-0,22 à juger, tap ré-émis avec `.second(true, nil)`, `including: .subviews`, offset avant les gestes, zIndex > 5, lentille coupée, borné sous la dalle) ; repli UIKit | téléphone, `-fps`, protocole §7 | un dépassement, retour ≤ 0,8 s ; scroll intact sans maintien ; maintien 0,3 s = UNE ouverture ; aucun galet resté enfoncé |
| 7 | **Les lunes** → `proposer()` hors transaction, persistance par la source des rewards, route gelée sous la pop-up, `GlypheLune`, `-duoLune` | `-duoLune` | la pop-up existante monte ; pas de booster infini |
| 7 bis | **La pièce** — `EtapeSpec.piece` (rang 3), états verrouillée / disponible / réclamée, robe `.piece` de `RewardPopup`, **`RewardHote` à la racine** (le patron de `BoosterPopupHote`), « Prendre » → `PiecesNotif` + `CoinChink` + ligne `coin_ledger` `chemin_piece` idempotente (user, chapitre, rang), `-duoPiece` | `-duoPiece`, `-homeChemin -duoEtape 3` | la card monte AU-DESSUS de la route ; la capsule descend ; le nœud se grave « +40 » ; pas de pièce infinie |
| 8 | **La famille de stickers** — 7 forges (transparentes) + le script 1x/2x/3x + 8 recalages sur capture + la gerbe orange préservée ; `FlammeBijou.braise` | `-skipAuth`, faits ≥ 2 | l'emoji absent partout ; décodé ≤ 0,5 Mo pour l'ardoise |

**Les questions fermées** : (0) D2 d'abord — le chemin lit les séances ?
(1) les deux sorties ? (2) 7 séances + 2 lunes, `etape` saute les lunes ?
(3) la réf du passé sur disque ; goutte réécrite ou `galetLisere`
rebranché ? (4) le bec reste mort ? (6) le verdict du soir (le jouet) prime
celui du midi ; seuls fait / actif / lune se portent ; ressort ou chute ?
(7) la lune du milieu passive, la route quittée après un booster ? (7 bis)
la pièce : 6 + 2 + 1 à 30 pt ou 7 + 2 + 1 à 23 pt ; la card reward ou la
seule capsule ; +40 fixe ou tirage ; au rang 3 ? (8) la famille de 7
ensemble, à son vrai coût ?

---

## 11. LES LOIS QUI TIENNENT CE CHANTIER

1. **Ce qui doit être vu au-dessus d'un écran vit dans le même arbre que
   lui.** Un cover cache la racine — et ce qu'il donnait gratis (la vue
   présentante retirée), l'arbre le fait payer.
2. **On mesure, on ne déduit pas** — la géométrie (c'est le PAS qui fixe
   l'air), la lumière (les 10 % de pixels clairs, le profil LE LONG de
   l'anneau, sur le MIN des graines), jamais l'impression. Une loi mesurée
   ailleurs ne se transporte pas sans sonde.
3. **Une matière par état** : rare contre continu, avant clair contre
   sombre — et l'écart des deux se prouve, pas deux seuils.
4. **Les largeurs de lumière sont en points absolus**, dans la bonne
   convention (`exp(−(x/w)²)`, visible ≈ 2,1·w), avec un repli quand
   l'uniform vaut 0.
5. **Un motif harmonique en n·θ est régulier par construction** : une perle
   irrégulière a un angle seedé, pas une fréquence.
6. **Deux objets qui s'accordent lisent la même source** — une fonction pure
   de t, un seul formateur ; et on lit les usages avant d'accuser une
   définition (les `static let` morts).
7. **Un geste qui prend le doigt dans un scroll gagne par le temps ou par
   la direction, jamais par le seuil** — et ce qu'il annule, il le répare ;
   un press immobile ne se surveille pas à l'horloge.
8. **La couleur est rare** : l'or à la lune, la braise à la flamme vive.
9. **Les ids sont des index** : on ne troue jamais une numérotation qu'on
   indexe.
10. **Le simulateur ne pose pas de doigt, et n'a pas d'état** : les gestes se
    jugent sur le téléphone, les états au banc branché — et rien ne se
    montre avant que la sonde dise oui.

---

## 12. CE QUE LE 1er FOUET A CORRIGÉ (six agents, code cité)

| affirmation | verdict | ce qui change |
|---|---|---|
| le cover cache la pop-up booster | **CONFIRMÉE** | + l'haptique joue dans le vide ; repli « la route se replie d'abord » ; jamais un 2e hôte dans le cover ; `BUGS-RESTANTS §4` faux tel quel |
| un cover ne peut pas porter le geste | NUANCÉE | possible mais l'arbre gagne (entrée au doigt, unité de fenêtre) ; simultané + verrou d'axe, jamais `.gesture` / `highPriority` |
| ×1,5 : alterné ±60, « garder la base 10 » | NUANCÉE | amplitude min **58,5** ; le min 30 fixé par le **pas** ; ids **CONTIGUS** + `n` ; jour fantôme ; tout est en rr ; `BUGS-RESTANTS §3` périmé |
| la bulle latérale à bec | NUANCÉE (prémisse fausse) | pas de place à cette densité ; B3 interdit le bec → ancre + halo + naissance + projecteur |
| le jouet en `LongPress.sequenced` nu | NUANCÉE | loi payée 3× **sauf** si le port ré-émet le tap ; refus = immobilité ; le menu TOMBE ; **bug latent** du press |
| la flamme : un composant unique | NUANCÉE | vrai pour la route, faux pour la mini-card (famille de 7) → deux chantiers |

## 13. CE QUE LE 2e FOUET A CORRIGÉ (cinq agents ; le critique coupé)

| proposition corrigée | verdict | ce qui change |
|---|---|---|
| le liseré du passé : plancher 0, gain 0,6, σ 1,0-1,3 pt, CV ≥ 0,6 | NUANCÉE — **ne passait pas son portillon** | le soft-clip aplatit les lobes larges (73 % du périmètre > 60, CV 0,38-0,75) → lobes **cos^12 / cos^14**, étincelles harmoniques MORTES → **une perle seedée** ; largeur = **erreur ×2 de convention** → `w = 0,55 pt` avec **repli obligatoire** ; CV sur le **MIN**, écart passé/futur ≥ 0,8, bande rr 0,93-1,05 ; v10-v13 **irrécupérable** (jamais commitée) ; la réf date de l'ère **`galetLisere`** (σ 0,60 pt absolus, toujours compilé) — deux chemins, la réf sur disque tranche |
| le panneau v2 (ancre, halo, naissance, projecteur) | NUANCÉE | le clamp n'absorbe que ±45 pt ; l'ancre dans le frame de la colonne `(px/L, py/5h)` — et l'actuel `.scale(0,88)` glisse de 200 pt caché ; **pas de `scrollTo` dans naissance**, dériver + non animé avant le rendu, naissance conditionnée ; **« date gelée » RÉFUTÉE** (`static let` morts, à supprimer) — la double source est le formateur « 26. » ; le projecteur sur la lentille à MESURER (compositingGroup) |
| le jouet v2 (deux gestes, port prioritaire) | NUANCÉE | bug latent CONFIRMÉ ; le chien de garde 0,30 s **inadapté au press immobile** → `@GestureState` sans horloge ; 0,14 s **sous tous les seuils de la maison** → 0,18-0,22 à juger ; `including: .subviews`, jamais `.none` ; offset AVANT les gestes ; zIndex > 5 ; `.second(true, nil)` = course 0 (22 pt tolérés) ; `CardTouche` échoue dans un scroll ; repli UIKit ; aucun précédent exact — téléphone |
| l'hôte en arbre + sommeil | NUANCÉE | l'éclipse n'était pas l'adversaire : **le sommeil est le PRIX de la sortie du cover** ; aucun mécanisme réutilisable → clé neuve sur ~12 horloges, **vidéos de la home à rate 1** ; lecteurs de la route démontés (ma contradiction) ; **double hôte déjà vivant** ; exclusivité des états ; `visualEffect` obligatoire ; verre de la home démonté aussi ; départ à la racine ≠ `startWorkout()` ; Porte 2 contredit `if ouvert` |
| la flamme A/B | **RÉFUTÉE** sur A, NUANCÉE sur B | `hierarchical` = **no-op mesuré** ; le vrai levier = le **contour `flame`** à `.ultraLight` ; le pipeline **ne fait que détourer**, 1x seul aux slots vides ; `serree` = crop + Lanczos jamais commité → **script à écrire** ; **8 sites calibrés sur les marges** → recalages ; la gerbe exige l'orange |

## 14. LA RELECTURE DE COHÉRENCE (la mienne — le critique a été coupé)

- La « pierre noire » ne survit nulle part : §4 (« le croissant en creux
  dans le verre sombre »), §5 ter, §9 (« pierres de verre sombre ») sont
  alignés ; le nom de la planche reste « La route de pierres noires » — un
  nom, pas une matière.
- Le halo en pt absolus est repris en §3, §4, §5 ter, §10.
- Les largeurs : §3 renvoie à §5 bis pour la convention (`w`, pas σ) — un
  seul endroit chiffre.
- §1 ne dit plus « les lecteurs restent montés » ; il dit « démontés, sauf
  pendant le geste ».
- §6 ne parle plus de « date gelée » ; il parle du formateur du jour.
- Les questions fermées du §10 correspondent aux § 1-8 ; celle du §3 (« la
  réf tranche entre deux chemins ») est nouvelle et vient du 2e fouet.
- Ce qui reste **non mesuré et dit comme tel** : le CV réel de la capture
  (mon « ~0,15 » est un modèle + bruit, cohérent avec 0,065-0,119 calculés) ;
  la lentille sous `compositingGroup` ; le remontage de la home ; le
  glissement de 200 pt du panneau (à filmer) ; tout ce qui est geste.
