# ANALYSE — les 4 demandes de la home (02-09)

> **Rien n'est codé.** Ce document est la lecture du code existant, ancre par
> ancre (`fichier:ligne`). Tout ce qui est affirmé a été LU ; ce qui n'a pas été
> mesuré est dit comme tel (§10).
>
> Méthode : 7 lecteurs en parallèle sur les 7 sous-systèmes touchés, puis 8
> juges adverses chargés de RÉFUTER les risques bloquants. **7 tiennent, 1 est
> tombé** (§9) — et trois d'entre eux ont corrigé ma première lecture. Les
> corrections sont marquées ✏️.

---

## §J−1 — LES COTES, MESURÉES (02-09, 08h40)

**Fait**, et ça tranche Q0. App RÉELLE (châssis + `PageCard`), pas le banc de
page — sim `kat-home2`, **iPhone 15, 393 × 852 pt**, exactement le format de ses
captures. Outils écrits pour ça : `tools/home-v2/voir.sh` et
`tools/home-v2/mesure_cotes.py`. Captures : `tools/home-v2/captures/pose-083906.png`
(la home posée) et `tiroir-084032.png` (`-tiroirOuvert`, l'écran du slider).

| Cote | **Mesuré** | Ce que le code suppose | Écart |
|---|---|---|---|
| Bas du galet (bord bas, Ø 62 centré sur son glyphe à 814) | **845 pt** sur 852 → **7 pt d'air** | `.padding(.bottom, 24)` | **−17 pt** |
| Bas d'encre de la phrase d'accueil | **312 pt** | « bas à 291 » (`DepartCine.swift:63`) | +21 pt |
| Bas d'encre de la phrase d'arrivée | **721 pt** | 291 + 403 = 694 | +27 pt |
| **Raccord du fondu croisé** (arrivée − accueil − courseTexte) | **+6,3 pt** | 0 | **6 pt** |
| Ligne de la zone sûre basse | 818 pt | — | — |

**Ce que ces quatre nombres disent :**

1. 🟢 **Le fondu croisé N'EST PAS déjà cassé.** L'écart vaut 6 pt — invisible
   sous un flou de 15. **L'hypothèse d'une dérive antérieure (§1, §3) est
   ÉCARTÉE** : les deux cotes du commentaire ont bougé ensemble (+21 / +27),
   leur différence a tenu. Il n'y a rien à réparer avant J1.
2. 🔴 **Mais retirer une ligne ferait passer ce raccord de 6 pt à ≈ 41 pt.**
   C'est le seuil où ça se voit. `courseTexte` devra donc passer de 403 à
   **≈ 438** — et **se re-mesurer** après coup avec le même outil.
3. 🔴 **Le galet a 7 pt d'air là où le code lui en donne 24 : 17 pt sont
   avalés par le débordement du conteneur de page.** C'est la cause chiffrée
   de « collée en bas », et elle n'est pas dans le padding — elle est dans le
   plein écran physique de `PageCard`. Le remède le plus honnête est donc de
   **rendre ces 17 pt**, pas d'empiler un padding par-dessus.
4. ⚠️ Le débordement mesuré (17 pt) est **la moitié de la safe area basse
   (34)** — cohérent avec un enfant de hauteur `Hs + safeBottom` centré dans
   une `.frame(height: Hs)` (`PageCard.swift:112`). Cohérent, **pas prouvé** :
   c'est une mesure sur le galet, pas sur le conteneur.

> ⚠️ **Charge machine au moment de la mesure : load 2,07** — au-dessus du
> plancher de 2. Sans effet ici (ce sont des cotes géométriques sur capture
> figée, pas de la cadence), mais aucune mesure de cadence n'est valide dans
> cette session tant que la charge n'est pas retombée.

---

## §J0 — LA PASTILLE AU PULL : FAIT, MESURÉ (02-09, 08h47) — **pas commité**

Deux fichiers touchés, rien d'autre.

**`HomeNuit.swift`** — la home dit enfin à `MenuHote` de l'éteindre :

- `seuilCache = 10 pt` : le seuil d'engagement du pull ;
- `pullEngage` — **dérivé de `tirage`, pas un `@State`** : rien à remettre à
  plat aux trois endroits du geste, donc rien à laisser coincé le jour où la
  Reachability vole le drag sans `onEnded` ; il suit aussi la fermeture animée
  sans repasser par le doigt, **et il se juge au banc `-tirageFige <pt>`** ;
- `galetEteint = (!enSeance && (pullEngage || tiroirOuvert)) || vitrineSlot != nil`,
  passé **à la fois** en `verrouille:` et en `galetCache:`.
  ⚠️ **Les deux rôles basculent au même instant, et c'est le point** : une
  pastille invisible qui garde sa prise ouvrirait le menu au contact puis
  suivrait le doigt. Avant ce changement, `verrouille` valait `tiroirOuvert`,
  qui n'arrive **qu'au cran (52 pt)** — la pastille était donc pleine ET
  vivante pendant toute la première moitié du pull, au coin exact où le pouce
  se pose.

**`MenuNappe.swift`** — `galetCache` force AUSSI la doublure mate
(`transport`) : le corps du galet est un `GlassEffectContainer`, et **le verre
natif ignore `.opacity`**. Une extinction par opacité seule aurait retiré
l'encre et laissé la capsule de verre peinte sur l'arête — la tranche serait
restée. C'est la correction que l'analyse avait annoncée (§4).

### Le verdict, à la sonde (pas à l'œil)

Captures dans `tools/home-v2/captures/`, sonde : pixels clairs (> 110) sur la
place de la navette encastrée (x 0..18 pt, y 690..800), et le glyphe maison
blanc (> 200) sur la place normale du galet.

| État | Tranche | Glyphe maison | |
|---|---|---|---|
| Repos, **avant** (`pose-083906`) | 0 | 1492 | le galet est là |
| Tiroir ouvert, **avant** (`tiroir-084032`) | **888** | — | 🔴 la tranche |
| Tiroir ouvert, **après** (`j0b-tiroir-084623`) | **0** | — | 🟢 éteinte |
| Pull engagé 30 pt (`j0b-fige30`) | 0 | **0** | 🟢 éteint dès l'engagement |
| Pull à 5 pt (`j0b-fige5`) | 0 | **1510** | 🟢 **contrôle** : sous le seuil, il reste |

Le dernier essai est le plus important : il prouve que **ce n'est pas le banc
qui masque le galet**, et que le seuil de 10 pt ne s'éteint pas sur un
tremblement.

**Non-régression sur ce qu'on n'a pas voulu changer** (`pose-083906` avant vs
`j0b-pose-084829` après) — le fond est une vidéo qui tourne, l'égalité exacte
est impossible, on lit donc un écart :

| Zone | Avant | Après | Écart |
|---|---|---|---|
| Glyphe du galet au repos | 1492 | 1464 | −1,9 % |
| Encre de la phrase | 45 170 | 45 242 | +0,2 % |
| Encre des deux cards | 21 534 | 21 464 | −0,3 % |

La home posée est intacte.

### 🔴 Ce que ce verdict NE dit PAS

- **Le seuil de 10 pt n'a pas été senti au doigt.** `-tirageFige` pose une
  course, il ne joue pas un geste : la sensation (« ça s'éteint trop tôt / trop
  tard ») ne se juge que sur l'appareil.
- **Le fondu de 0,22 s n'a pas été filmé.** L'échange verre → doublure mate est
  instantané au premier instant du fondu ; sur capture figée on ne peut pas voir
  s'il « pope ». À filmer (`simctl io recordVideo`) ou à juger au doigt.
- Le rangement (`rangerDemande`) joue toujours au cran, désormais **sous une
  pastille déjà invisible** : c'est du travail pour rien, mais ça garde
  `onRange` — donc le slider reprend bien la largeur libérée. Laissé tel quel
  volontairement ; le simplifier demanderait de re-vérifier la largeur du
  slider.

---

## §J1 — LA PHRASE À 4 LIGNES : FAIT, MESURÉ — **pas commité**

**Tranché par elle le 02-09 : le galet de l'objectif est SUPPRIMÉ**, en
connaissance de cause (option « on le supprime »).

- `PhraseTexte.fragments` rend **4** fragments ; le dernier est
  « this week. » — **sourd**, donc la phrase s'éteint au lieu de claquer, et
  l'alternance clair/sourd tient à la lettre.
- ⚠️ **Le point final est une décision de copie que j'ai prise** : la phrase
  perdait la ponctuation qui la fermait. À défaire d'un caractère si tu la
  préfères ouverte.
- **La découpe 4+1 du masque disparaît** : elle n'existait que pour épargner la
  transparence du galet. `horsMasque` ne vaut plus `nil` que parce que plus
  aucun fragment ne porte d'`objectif` — **la branche reste écrite**, rendre
  `objectif:` à un fragment la rallume, galet et panneau 3→7 compris. Tout le
  bloc passe donc sous **un seul dégradé**, ce que la loi de la maison demande
  (« UN seul dégradé pour tout le bloc, jamais un par ligne »).
- 🔴 **La dette, écrite dans le code** : `prevus` reste LU (la card « / N », le
  pied « N sessions left to hit your goal », `SemaineStats`, la vitrine,
  ProgressPage) et n'est plus ÉCRIT nulle part.

### `courseTexte` : 403 → 441, et le chiffre est mesuré

La phrase d'accueil est ancrée par le HAUT, la phrase d'arrivée par le BAS :
perdre une ligne remonte le bas de l'accueil et **désaligne le fondu croisé**.

**Pas de ligne mesuré = 38,35 pt** — sommets d'encre de « Hello Kathryn, »
(131,0) et de « 6 workouts » (207,7), soit deux pas. Vérifié après coup :
les trois premiers sommets sont **identiques au pixel** avant et après
(131,0 / 169,7 / 207,7), donc seule la dernière ligne est partie.
403 + 38,35 ≈ **441**.

⚠️ **Défaut latent constaté au passage, pas corrigé** : `PhraseVue.sourd(_:)`
calcule la hauteur de ligne comme `taille × 1,14 + interligne` = **36,2**,
alors que le pas réel est **38,35**. La lampe lit donc la mauvaise hauteur, de
2,15 pt par ligne. Sans conséquence visible (le champ est très doux à cette
échelle) — signalé, pas touché.

⚠️ **`duréeTotale = duree + 4 × retard` n'a PAS été touché.** Le « 4 » est
`count − 1` pour 5 fragments ; à 4 fragments la dernière ligne finit à
p = 0,904 et les 140 dernières ms de la fenêtre ne portent plus rien —
**invisible** (tout est déjà arrivé, aucun `completion` n'y est accroché). Le
corriger désynchroniserait la reconstitution du banc (`(t − 0,38)/1,46`, en
clair à `HomeNuit.swift:4114`) et les fenêtres d'arrivée des cards, qui sont
calées sur `arr`. **Laissé exprès.**

---

## §J2 — LES 3 CARDS REMONTENT : FAIT, MESURÉ — **pas commité**

Les deux fractions deviennent **une seule source**, `yCards(_:)` et
`yRoute(_:)`, lues par les **sept** sites (la rangée, la card route, l'ardoise
du banc, l'origine du vol de la vitrine, la drop-list d'édition, la poudre
d'adieu, la pop-up de refus). Plus aucun littéral `0.375` / `0.620` dans le
fichier.

⚠️ **La remontée est ABSOLUE (38 pt), pas fractionnaire** : ce qu'on récupère
est le trou laissé par une ligne de texte, dont la hauteur est en points. Une
fraction aurait fait remonter plus sur un grand téléphone que la ligne n'y
occupait.

**Verdict à la sonde** (`pose-083906` avant vs `j2-pose-090530` après) : le
premier bloc d'encre de la card « Sessions » passe de **444,3 pt à 406,3 pt** —
**−38,0 pt**, exactement la remontée demandée, sur les deux rangées.

---

## §Q2 — LES 17 pt RENDUS : `PageCard`, alignement bas

**Tranché par elle : « rends les 17 pt ».**

Hors séance, le plus grand enfant du ZStack de `PageCard` fait
`Hs + safeBottom` (la card plein écran physique) ; la `.frame(height: Hs)`
**centrait** ce dépassement — donc `safeBottom / 2 = 17 pt` en haut ET en bas.
Un seul mot change : `alignment: .bottom`. Le dépassement passe entièrement en
haut, où il ne coûte rien (la card n'a pas de coins hauts, « le haut fond dans
l'heure », §2.18).

⚠️ **En séance rien ne bouge** : `hPage == Hs`, aucun enfant ne dépasse,
l'alignement n'a aucun effet. Ce sont les **quatre pages hors séance** qui
remontent ensemble — home, exercices, progress, fiche.

### Le verdict, et c'est un test décisif

Je prédisais **17 pt** avant de toucher au code. Mesuré après :

| | Air sous le galet | Bord bas du galet |
|---|---|---|
| Avant (`pose-083906`, `j2-pose-090530`) | **7,0 pt** | 845,0 |
| Après (`q2-pose-090714`) | **24,0 pt** | 828,0 |

**+17,0 pt au dixième**, et 24,0 est exactement ce que `.padding(.bottom, 24)`
promet. Le mécanisme du débordement n'est plus une hypothèse : il est prouvé.

**Et le slider « Send it » remonte du même coup** (`q2-tiroir-090834`) : sa
flèche passe de 805,7 à **788,7 pt — −17,0**. La deuxième moitié de la demande
n°2 est donc servie **sans toucher à `leveeTiroir`**, donc sans re-caler
l'élastique du pull ni le budget de la gerbe de poudre.

### Les autres pages de `PageCard`

| Page | Banc | Verdict |
|---|---|---|
| Progress (`q2-progress-100135`) | `-progressLab` | 🟢 intacte — rien de rogné, « Voir dans le lecteur » respire |
| Fiche exo (`q2-fiche-100205`) | `-exoLab` | 🟢 intacte — le dôme et « Start exercise » entiers |
| **Exercices** | — | ⚪ **NON CAPTURÉE** |

⚠️ Pour Progress et la fiche je n'ai pas de capture AVANT : je peux dire
« rien n'est cassé », pas « ça a remonté de 17 pt ». Et **l'onglet Exercices
n'a pas été vu du tout** — la bascule d'onglet par `defaults write openTab`
n'a pas pris (l'app réécrit la clé au lancement).

### 🔴 Ce qui n'a PAS été vérifié
- **Le raccord du fondu croisé après `courseTexte = 441` n'a pas pu être jugé
  au simulateur.** Le film a été tourné (`tools/home-v2/films/depart-090903.mov`,
  banc `-departAuto`, 58 Mo, non versionné) et il montre pourquoi : **à
  l'instant de la bascule il ne reste AUCUNE encre** — la substitution se joue
  sous le sommet du flou. C'est d'ailleurs l'explication de l'ancien décalage
  de 6,3 pt resté invisible pendant des semaines.
  Ce qui tient est l'argument mécanique, et il est solide : les trois premiers
  sommets de ligne sont **identiques au pixel** avant/après (131,0 / 169,7 /
  207,7), donc seule la dernière ligne est partie ; un bloc ancré par le haut
  qui perd une ligne remonte son bas d'exactement un pas ; le pas est mesuré
  (38,35) ; j'ai ajouté 38. **Le raccord reste donc à ±0,35 pt de ce qu'il
  était** — il ne s'améliore pas, il ne se dégrade pas.
- Le seuil de 10 pt de l'extinction de la pastille, et le fondu de 0,22 s :
  **au doigt seulement.**

---

# §FLUIDITÉ — POURQUOI LE RUBAN SACCADE, ET CE QUE J'AI CESSÉ DE COMPRENDRE

> Son verdict, après cinq essais : **« la bordure animée que tu avais faite
> était cool, il faut juste la rendre plus fluide. »** Le LOOK est validé — les
> trois couches floutées (14 / 5 / 1,6 pt), le dégradé qui tourne, un tour en
> 9 s. Il ne reste qu'un défaut, et un seul.

## F.1 — Ce qui a été essayé, et ce que chacun a coûté

| version | verdict |
|---|---|
| 3 couches floutées, 20 Hz | ✅ **le look validé** — « j'aime bien l'épaisseur », mais « pas trop fluide » |
| 2 couches + cœur chaud, 60 Hz | « ça lag » |
| 7 `strokeBorder`, aucun flou, 60 Hz | « on voit les pixels », puis « ça lag de fou » |
| un shader `colorEffect`, UNE passe GPU | « ça lag de fou » |
| foyers fixes, seule l'opacité anime | rejeté — ce n'était plus l'effet |

## F.2 — 🔴 LE FAIT QUI RENVERSE MON DIAGNOSTIC

**Le shader a lagué aussi.** Une seule passe GPU, calculée par pixel, sans
aucune couche empilée — ça devrait être quasi gratuit. Ça ne l'a pas été.

Donc **le coût de dessin du contour n'est PAS le problème**. J'ai passé quatre
tours à rendre le ruban moins cher (moins de flous, moins de couches, un
shader) et chaque fois le résultat a été identique ou pire. Quand quatre
remèdes différents échouent de la même façon, c'est qu'on soigne le mauvais
organe.

**Ce que le contour fait vraiment, c'est INVALIDER LA CARD À CHAQUE IMAGE.**
Il est posé en `.overlay` sur `pageEnCard`, donc *à l'intérieur* de la
composition de la card — et cette card contient une **vidéo vivante** et
**trois panneaux de verre natif**. Une capture de fond de verre natif force la
résolution en texture de tout le composite situé dessous, et le dépôt l'a déjà
chiffré. Le contour n'est pas la dépense : il est le **déclencheur** qui la
fait payer soixante fois par seconde.

## F.3 — 🔴 ET L'INSTRUMENT EST CASSÉ : on ne peut PAS régler ça au simulateur

Toutes les mesures ci-dessous sont machine calme (`charge.sh` vert), même
binaire, à quelques minutes d'intervalle :

| | relevés |
|---|---|
| home au repos | 8,7 · 18,7 · 5,6 img/s |
| séance, contour allumé | 4,5 · 5,1 · 6,5 · 10,0 · 12,2 img/s |

Et le coup de grâce, sur la version à foyers : **contour ALLUMÉ 12,2 img/s,
contour ÉTEINT 8,0**. Le contour rendrait la page *plus rapide* — ce qui est
impossible. **Le bruit de l'instrument dépasse l'effet qu'on veut mesurer.**

> Régler la fluidité du ruban au simulateur est hors de portée. Le drapeau
> **`-sansBord`** existe désormais et fait la bisection exacte (même page, même
> séance, le contour seul change) : **il faut la lancer sur le TÉLÉPHONE.**

## F.4 — Les trois pistes, par ordre de promesse

**① SORTIR LE CONTOUR DE LA COMPOSITION DE LA CARD.** C'est la piste que le
§F.2 désigne. Aujourd'hui il est *dans* `pageEnCard`, avant son `clipShape` :
son invalidation entraîne la vidéo et le verre. Le poser en **frère au-dessus
de la card**, découpé à la forme de la robe, donnerait le même rendu — dans la
card, s'arrêtant au-dessus du player, comme elle l'a demandé — sans traîner le
composite avec lui. **C'est un déplacement, pas un redesign : le ruban validé
ne change pas d'un pixel.**

**② LE `.mask` ET LE `.blendMode` DU RUBAN.** Les deux forcent un groupe de
composition à la taille de la card, à chaque image. Le fondu du haut pourrait
venir d'un dégradé DANS les couleurs des trois couches plutôt que d'un masque ;
`plusLighter` peut se poser sur chaque couche au lieu du groupe. Deux passes
hors écran en moins, sans toucher au look.

**③ LA CADENCE, EN DERNIER.** 20 Hz montre le pas d'horloge sur une lumière qui
court ; 60 Hz coûte trois fois plus. **Ce choix ne se tranche qu'une fois ① et
② faits** — sinon on arbitre entre deux symptômes.

## F.5 — Ce que je ne ferai pas

Rien de tout ça n'est codé. ① touche `PageCard`, que l'autre session lit en ce
moment pour la nav du bas — je l'ai prévenue du déplacement de 17 pt, je ne
vais pas y toucher une seconde fois sans que Kathryn ait tranché.

---

# §BORD — LE CONTOUR DE SÉANCE : FAIT, MESURÉ (02-09, 12h20) — **pas commité**

`Woop/Views/BordSeance.swift`, monté au châssis (`WoopApp.swift`, zIndex 9,5).
Banc : **`-bordSeance`** (la braise sans séance en base).

**Ce qui est prouvé :**

- il vit bien **au CHÂSSIS** — la première capture est tombée sur l'onglet
  *Exercices* et le contour y était (`captures/bord-121626.png`) ; monté dans
  la home il se serait éteint au changement d'onglet ;
- il **respire**, mesuré sur le film `films/bord-121834.mov` par
  `tools/home-v2/juge_souffle.py`, sur la **bande haute** (noir pur, hors de la
  braise orange de la page qui contaminait la première sonde) :

  | | valeur |
  |---|---|
  | plancher | **11** |
  | sommet | **31** |
  | amplitude | **20, soit 65 % du sommet** |

  → il respire franchement **et ne s'éteint jamais** : un signe d'état qui
  disparaît par moments se lirait comme un bug.

**Les lois tenues :**

- **deux périodes incommensurables**, 6,1 s et 9,7 s — et volontairement PAS
  celles de la fumée d'invite (7,3 / 11,7) : deux respirations qui partagent
  une période finissent par battre ensemble, et on lit un métronome ;
- **aucun `.blur`, aucun `Canvas`, aucun `compositingGroup`** — quatre passes
  de `strokeBorder` en `plusLighter`. `plusLighter` étant associatif, le groupe
  de composition ne changeait rien au rendu et coûtait une passe **hors écran
  plein cadre à 20 Hz** : retiré ;
- `strokeBorder` et non `stroke` (un `stroke` est centré sur le chemin : la
  moitié tomberait hors écran) ;
- `.allowsHitTesting(false)` — il couvre l'écran entier, sans ça il mangerait
  tous les touchers de l'app pendant la séance ;
- 20 Hz, pas 60 : un souffle de 6 s n'a pas besoin de plus ;
- loi anti-brun respectée (R à 1,00, c'est le vert qu'on désature).

**Premier jet refusé, et pourquoi** : à opacités 0,10 / 0,16 / 0,26 / 0,55 le
contour était **une alarme incendie** (`captures/bord-121626.png`). Divisé par
~4 (0,022 / 0,038 / 0,065 / 0,16) et élargi (40 / 18 / 7 / 1,2 pt) : la lueur
est plus large ET plus douce.

🔴 **Ce qui n'est PAS jugé** : le rendu au téléphone. Le simulateur est aveugle
au coût GPU ; et une braise se juge sur un écran OLED, pas sur un LCD de Mac.

---

# §IA — LES TEXTES GÉNÉRÉS, ET LEUR LIEN AU BACK-END (02-09, 12h)

> Sa demande : « les textes seront générés par IA et adaptés à la session,
> avant, pendant la session et à la fin » + « faudrait lier au back-end ça dans
> la doc ». Plus : **un contour rouge qui respire autour de l'écran** pendant
> la séance.

## IA.1 — Ce que le site de doc dit, et il fallait le lire avant tout

| Brique | État au site | Preuve (mesurée le 30-08) |
|---|---|---|
| `weekly-synthesis` (edge) | **⚪ ABSENTE** | `supabase functions list` → **forge-card SEULE** (ACTIVE v4) ; `POST /functions/v1/weekly-synthesis {}` → **404 NOT_FOUND** |
| `syntheses` (table) | 🔵 serveur seul | `ProgressionView.swift:14` — la vue qui l'appelle n'est montée nulle part |
| `forge-card` (edge) | 🟢 branchée | sondée 30-08 14:35, rejeu identique |

Source : `docs/site/content/serveur.ts:18`, `:78`, `:79`.

> **Le patron existe, il n'est PAS déployé.** `weekly-synthesis` est écrite,
> elle appelle déjà **Anthropic `claude-opus-5`**
> (`supabase/functions/weekly-synthesis/index.ts:96-97`), avec `effort: "low"`,
> le fallback serveur et le refus géré — mais elle n'a jamais été poussée.
> C'est exactement ce que le site sert à empêcher : partir en croyant qu'une
> brique existe.

## IA.2 — Le patron est bon, et sa raison d'être est écrite

`weekly-synthesis/index.ts:1-8` : « La clé Anthropic ne quitte jamais le
serveur : **c'est toute la raison d'être de cette fonction.** » Toute
génération de texte passe donc par une edge function. Jamais de clé dans l'app.

## IA.3 — 🔴 LA LATENCE DÉCIDE DE TOUTE L'ARCHITECTURE

Un texte de home qui se métamorphose **pendant** la séance ne peut pas attendre
un aller-retour LLM à chaque série : la cloche dure 1,62 s, un appel réseau en
dure plusieurs.

> **Donc : on ne génère pas AU MOMENT, on génère À L'AVANCE.**
> Au départ de séance, un seul appel produit **les trois textes** (avant /
> pendant / fin) ; ils sont stockés ; la home ne fait plus que les **lire**.
> La métamorphose devient locale, instantanée, et hors ligne elle joue quand
> même.

Trois conséquences directes :

1. **Un repli LOCAL est obligatoire.** Hors ligne, première séance, appel qui
   échoue : la home doit avoir des phrases écrites en dur qui tiennent le rôle.
   Précédent : `forge-card` a le même problème (pool commun ~1 s contre une
   carte neuve 60-90 s) et le résout par un pool.
2. **Une génération par séance, pas par appel** — idempotence par index, la loi
   n°2 du back-end. Un rejeu ne doit pas refacturer un appel LLM.
3. **La sortie est un SCHÉMA, pas de la prose.** Le modèle doit rendre
   exactement **4 fragments**, alternance clair/sourd, finissant sur un sourd,
   en anglais, chacun tenant dans **300 pt à Inter 30 semibold**
   (`PhraseParams.largeur = 300`). Une phrase trop longue casse la mise en page ;
   un nombre de lignes différent **casse le raccord du film de départ**
   (`courseTexte = 441`, calé sur quatre lignes ancrées par le haut).

## IA.4 — Ce qu'il faudra écrire au site, et quand

⚠️ **Rien ne part sans elle** (loi du back-end §6). Et la pastille ne se
repeint **qu'après un appel fait et une réponse lue** — jamais parce que le
code est écrit.

| Geste | Ce qui bouge au site |
|---|---|
| la fonction de génération déployée | sa ligne passe ⚪ → 🔵 |
| l'app l'appelle vraiment | 🔵 → 🟢 (**le plus oublié**) |
| la table de stockage posée | un enregistrement de plus, avec sa preuve |
| `weekly-synthesis` déployée ou supprimée | sa ligne ⚪ tranchée dans un sens ou l'autre |

## IA.5 — Le contour rouge qui respire (pur front)

C'est le meilleur véhicule pour « l'app est vivante » — bien meilleur qu'un
halo de card, parce qu'il dit l'état **de l'app**, pas d'un widget.

Trois lois à tenir, toutes déjà payées ici :

- il vit **au CHÂSSIS**, au-dessus des quatre pages, pas dans la home — sinon
  il disparaît quand on change d'onglet, alors que la séance, elle, continue ;
- `.allowsHitTesting(false)`, et **une seule horloge** pour lui et le pulsar ;
- **deux périodes incommensurables** et une amplitude tenue : « une invite qui
  se voit est une alarme » (`HomeNuit.swift:4441-4453`). Un contour rouge qui
  bat trop fort devient une alerte médicale.

---

# DEUXIÈME TOUR (02-09, 11h) — les trois demandes suivantes

> Demandé : la card chemin **vivante en séance** (texte + halo renforcé + mini
> pulsar blanc), le **texte de la home qui change en séance avec l'effet
> d'apparition au flou**, et **renforcer la fluidité du pull**.
> Plus sa question : « les pages ne peuvent plus se lever au drag avec la
> lune ? c'est le fix des 17 pt ? ».
>
> ⚠️ **Rien n'est codé ici.** Ce tour est une lecture. Les ancres ci-dessous
> ont été lues une par une.

## §A — LA FLUIDITÉ DU PULL

### A.0 — 🔴 LA CONCLUSION D'ABORD : on ne sait plus où on en est

**La seule mesure du pull qui existe date du 26-08, et l'arbre qu'elle a mesuré
n'existe plus.** Trois refontes sont passées depuis :

| Quand | Quoi | Ce que ça invalide |
|---|---|---|
| 30-08 (`6557a90`) | la **card ROUTE** remplace l'ardoise « This week » | la ligne « flou de la semaine coupé 35,6 » a été mesurée sur `SemaineStrip`, **pas** sur `CardRoute` |
| 01-09 (`647cdbb`) | le châssis **`PageCard`** enveloppe toute la home | un `clipShape` de plus sur tout le plan |
| 02-09 (ce matin) | la phrase passe de 5 à 4 lignes, les cards remontent | la géométrie du bloc a changé |

> **Aucun chiffre actuel n'existe.** Dire aujourd'hui « le pull est plus
> fluide » ou « voilà ce qui coûte » serait une opinion déguisée en mesure.
> **Le premier jalon du pull est une re-mesure, pas un correctif.**

Et la bisection elle-même est trouée : **trois des plus gros suspects ne sont
éteints par AUCUNE valeur de `-pullSonde`** (le slider, la pièce du trésor, le
`ScrollView` de la card route). Il faut d'abord **élargir les interrupteurs**,
sinon on re-mesurera le même angle mort.

### A.1 — Ce que le dépôt a DÉJÀ mesuré (à lire comme une ARCHIVE du 26-08)

`HomeNuit.swift:2913-2918`, sonde de cadence pendant un tirage
(`-fps -pullAuto`, bisection `-pullSonde`) :

| Régime | img/s | min | trou |
|---|---|---|---|
| tout monté | **36,8** | 6,5 | **681 ms** |
| sans le mobilier | **60,0** | 51 | 170 ms |
| flou des widgets coupé | 53,5 | 39 | 359 ms |
| flou de la semaine coupé | 35,6 | 7,0 | 566 ms |
| flou de la pièce coupé | 36,0 | 7,3 | 563 ms |

La leçon a été appliquée : `enGeste` coupe `flouCards` sous le doigt
(`HomeNuit.swift:2943`). **On devrait donc être à ~53,5 aujourd'hui.**

### A.2 — 🟢 Le pan maître UIKit est HORS DE CAUSE (c'était mon principal suspect)

`PlayerMonde.swift:733-738` :

```swift
func gestureRecognizer(_ g: UIGestureRecognizer,
                       shouldReceive touch: UITouch) -> Bool {
    PlayerEtat.shared.ouvert && !DepartEtat.shared.pauseOuverte
}
```

Hors séance le player est fermé ⇒ **le pan posé sur la fenêtre ne reçoit aucun
toucher**. Il ne coûte rien pendant le pull et n'entre dans aucun arbitrage.
Le recognizer reste attaché à la fenêtre (`PlayerMonde.swift:771-778`), mais
sourd. **Fait établi, pas une impression.**

### A.3 — 🔴 LE LEVIER RESTANT : le verre natif, au-dessus d'une vidéo vivante, à opacité zéro

Trois faits, chacun lu :

1. Les trois cards montent leur verre sur `verre: !DepartEtat.shared.homeDort`
   — `HomeNuit.swift:3143` (rangée), `:3195` (card route), `:3238` (ardoise du
   banc). Or **`homeDort` n'est vrai que SOUS LE CHEMIN** (`DepartSeance.swift`),
   jamais pendant le pull.
2. `ArdoiseFond` monte alors un `GlassEffectContainer` + `glassEffect(.clear)`
   — `WidgetsCards.swift:292-297`.
3. Pendant le geste, leur opacité vaut `1 − net` (`HomeNuit.swift:3164`,
   `:3206`, `:3252`) : **elle tombe à zéro** pendant que le doigt monte.

> On paie donc **trois captures de fond de verre natif, par image, au-dessus
> d'une chaîne vidéo vivante, pour peindre quelque chose dont l'opacité va à
> zéro.**

Et ce n'est pas une théorie : le fichier a **déjà nommé et payé exactement ce
péché**, pour le film cette fois (`HomeNuit.swift:3120`) —

> « `verreAt = 0.26` était déclaré et lu NULLE PART : les deux cards gardaient
> leur `glassEffect(.clear)` ET leur gaussienne de 6 pt pendant 1,69 s des
> 1,95 s du film, à opacité ZÉRO. Une capture de fond de verre natif force la
> résolution en texture de tout le composite situé dessous — donc de toute la
> chaîne vidéo — deux fois par image, pour peindre du vide. »

La gaussienne a été coupée (pour le film via `verreMonte`, pour le doigt via
`enGeste`). **Le verre lui-même n'a jamais été coupé pour le doigt.**

🟢 **Et le robinet existe déjà**, à un seul endroit —
`HomeNuit.swift:2683-2684` :

```swift
.environment(\.verreDemonte, menuOuvert || DepartEtat.shared.homeDort)
```

Le doigt n'y est pas. C'est la plus petite intervention possible, et elle est
exactement dans la grammaire de la maison (« on ne voile pas du verre, on le
DÉMONTE » — la doublure mate prend le relais, `WidgetsCards.swift:310`).

⚠️ **À trancher avant de coder** : démonter le verre au premier point du geste
ferait-il un POP visible au début du pull (le verre disparaît d'un coup) ?
La parade existe (le seuil, comme la pastille à 10 pt), mais **ça se juge à la
capture, pas au raisonnement.**

### A.4 — 🟠 Une bisection faite sous un confondant

« flou de la semaine coupé : 35,6 » et « flou de la pièce coupé : 36,0 » se
lisent comme « ces deux flous ne coûtent rien ». **Mais ces deux mesures ont
été prises quand le flou des widgets était encore vivant** — et lui seul valait
36,8 → 53,5. Un coût de 5 img/s masqué sous un coût de 17 ne se voit pas.

Or `flouSemaine` et `flouPiece` sont **toujours vivants sous le doigt** : seul
`flouCards` est gardé par `enGeste` (`HomeNuit.swift:2943-2944`), et les deux
autres restent `.blur(radius: 6 * net * …)` (`:3206`, `:3252`).

> **La bisection est à REFAIRE**, maintenant que le confondant est parti. C'est
> une mesure, pas une opinion — et elle décidera si ces deux flous méritent le
> même traitement que le premier.

### A.5 — ⚠️ `-pullAuto` n'est pas un banc de GESTE

`HomeNuit.swift:2430-2439` : un `Timer` à 60 Hz qui pose `tirageDebut = .zero`
et écrit `tirage` sur un sinus. **Aucun `DragGesture`** — donc ni verrou d'axe,
ni chien de garde, ni arbitrage de recognizers, ni la cadence réelle des
événements du doigt.

> `-pullAuto` mesure le **coût du RENDU**. Le coût du **GESTE** ne se mesure
> qu'au doigt, et « la vraie cadence se mesure sur le TÉLÉPHONE ».
> Dire « le pull est plus fluide » sur la seule foi de `-pullAuto` serait un
> mensonge de méthode.

---

## §B — LE TEXTE DE LA HOME QUI CHANGE EN SÉANCE (l'effet blur)

### B.1 — 🟢 La machinerie EXISTE, entièrement, et elle est gratuite

`DepartCine.swift:186-192` — **la cloche est une fonction pure d'un scalaire** :

```swift
static func clocheTexte(_ e: Double) -> CGFloat {
    let monte = sstep(clocheAt, clocheSommet, e)   // 0,10 → 1,00
    let tombe = sstep(clocheSommet, clocheFin, e)  // 1,00 → 1,62
    return flouMax * CGFloat(monte * (1 - tombe))  // flouMax = 15
}
```

et `bascule(e) = sstep(0,94 · 0,12)` (`DepartCine.swift:76`, `:196-198`) :
**le changement de mots est caché au sommet du flou**. Le commentaire le dit
tel quel : « c'est ce qui fait qu'on lit une transformation et pas un
remplacement ».

**Trois pièces sont déjà en place :**

| Pièce | Ancre | État |
|---|---|---|
| `PhraseVue` accepte déjà un `flouDepart` | `HomeNuit.swift:399`, posé `:485` | ✅ |
| Le flou vit sur les **glyphes**, pas sur un conteneur | `HomeNuit.swift:481-485` | ✅ |
| `Chambre<Contenu>: View, Animatable` — le pont qui livre un scalaire par image | `WidgetsCards.swift:2805-2815` | ✅ |

> **Il ne manque ni la machinerie, ni le pont, ni le paramètre.** Il manque un
> déclencheur, une source de texte, et l'échange des fragments au sommet.

⚠️ **Ce qu'il ne faut PAS faire** : rejouer `lancer()` (il écrit `naissance`
ET `arrivee`, `HomeNuit.swift:4060-4068` — ça rallumerait la lampe de toute la
pièce), ni réveiller la `TimelineView` racine (`:2478-2480`, « volontairement
pausée au repos, la réveiller rejouerait le piège de la page ré-évaluée par
image »). Un `Chambre` local suffit.

### B.2 — 🔴 Ce qui manque vraiment : LA SOURCE

- `SemaineStats.calcule` **filtre les séances non terminées**
  (`WidgetsCards.swift:2200-2210`) ⇒ **`stats` ne peut pas nourrir un texte
  vivant en séance.**
- L'état de séance existe côté home : `enSeance = !seancesOuvertes.isEmpty`
  et `debutSeance` (`HomeNuit.swift:1842-1847`).
- Le précédent le plus proche est `dalleHome` (`HomeNuit.swift:2439-2455`), qui
  fabrique déjà un libellé de player (« Woodchopper poulie haute · In session ·
  0 min », vu à la capture `seance-090131.png`).
- ⚠️ **Le texte doit être une CHAÎNE DÉJÀ FAITE**, rangée dans un `@State` et
  recalculée **sur événement** — l'école `majLectureChemin()` / `stats` : deux
  sites, jamais dans un `body`. `dalleHome` fait déjà tourner `seriesPayantes`
  (boucle sur tous les exos × toutes les séries) à chaque évaluation : y ajouter
  une phrase dérivée dans le corps la paierait 60 fois par seconde pendant le
  pull.

### B.3 — ⚠️ L'identité des lignes

`ForEach(Array(masquees.enumerated()), id: \.offset)` (`HomeNuit.swift:459`) —
l'identité est l'**index**. Si le texte change de nature en cours de vie, les
rangées échangeront leurs contenus sans transition et la dernière
apparaîtra/disparaîtra sèchement. Une identité de **rôle** (pas d'offset) est le
prérequis d'un texte qui change à chaud.

---

## §C — LA CARD CHEMIN VIVANTE EN SÉANCE

### C.1 — 🔴 Le prérequis reste entier

Rappel du premier tour, revérifié : `verreMonte` est mis à `false` par
`lancer()` (`HomeNuit.swift:3645`) et n'est remis à `true` que par `fermer()`
(`:3698`) et `rendreLaHome()` (`:2634`) — cette dernière n'étant appelée que
quand `enSeance` passe à **faux** (`:2408`).

> **Sur le flow slider → chemin → séance, la card chemin n'est pas montée
> pendant la séance.** Il n'y a rien à animer tant que ce n'est pas réparé.
> (Vu à la capture `seance-090131.png` : au banc `-homeSeance`, où `lancer()`
> n'a jamais tourné, le mobilier EST là — c'est le cas « app relancée ».)

### C.2 — 🟢 Le halo : la bonne porte, et une correction de ce que j'avais dit

`ArdoiseFond.lueur` **n'est pas un halo derrière la card** : c'est **le liseré
de la card, repassé une fois de plus, plus large et plus clair**
(`WidgetsCards.swift:490-497`).

Et il a été **conçu pour être animé par image** — son commentaire, `:440-447` :

> « posée sur le liseré qui existe déjà — jamais une taille, jamais un `.blur`
> de plus : ce qui bouge par image ne doit pas re-layouter, et un flou par
> objet coûte 27 img/s ici. […] Elle n'existe pas au repos (`lueur` = 0 → rien
> n'est composé), donc elle ne coûte que pendant le geste. »

Il est déjà nourri par `CardRoute` via `lueur: (defile || lueurForcee) ? 1 : 0`
(`CardRoute.swift:228`), et `lueurForcee` est déjà exposé (`:213`).

> **C'est le véhicule exact d'un halo qui pulse : gratuit au repos, animable
> par image, sans re-layout et sans flou.**

⚠️ **L'autre candidat est un piège** : le halo du galet ACTIF vaut 0,95 × Ø et
**sort de son propre cadre dès Ø > 57,8** — on est à 54 (`CardRoute.swift:156-161`) ;
la bande porte un `.mask(fonduBords)` et la card est `clipShape`ée (`:237`) : il
serait **tranché deux fois**. Et `GaletEtape` est **partagé** avec la page route
(validée) et `DuolinguoPage` — le toucher repeindrait la route.

**❓ À trancher : « le halo » = le liseré de la card, ou l'anneau autour du
galet « 2 » ?** C'est la seule ambiguïté qui bloque.

### C.3 — Le pulsar blanc, et les lois contre lesquelles « renforcer » pousse

- Le patron maison d'une respiration permanente : `WorkoutPill.swift:365-367`,
  `:417-420`, `:443` — un `@State` + `.animation(.easeInOut(duration: 2.6)
  .repeatForever(autoreverses: true), value:)` + `.onAppear` — « UNE animation
  `repeatForever`, jamais une TimelineView de plus ».
- ⚠️ Mais un `@State` posé **dans** `CardRoute` **meurt au démontage
  `verreMonte`** : la phase sauterait à chaque aller-retour de la home. Une
  fonction **pure du temps** n'a pas ce défaut.
- ⚠️ Le pulsar doit être `.allowsHitTesting(false)` : la porte de la route
  passe par le tap de la card entière, et un enfant qui a une zone tactile la
  volerait — bug déjà payé deux fois (`CardRoute.swift:145-149`), et la raison
  pour laquelle les neuf galets sont `inerte: true`.
- 🟠 **« Renforcer beaucoup » pousse contre une loi payée trois fois ici** :
  deux périodes incommensurables (7,3 s et 11,7 s) pour ne pas faire clignotant,
  et **amplitude basse** — « une invite qui se voit est une alarme »
  (`HomeNuit.swift:4441-4453`). Ce n'est pas un refus : c'est un arbitrage à
  faire **à l'œil, au banc, en le sachant**.

---

## §D — « LES PAGES NE PEUVENT PLUS SE LEVER AU DRAG AVEC LA LUNE ? »

### D.1 — Où la prise lune existe, page par page

`PageCard.swift:103-112` — et **les deux branches sont exclusives** :

```swift
if enSeance, bandeVisible { bande }          // le dock du player
else if bandeVisible, luneAuDrag { prise }   // la prise lune, 30 pt
```

| Page | `luneAuDrag` | Prise lune |
|---|---|---|
| **Home** | `false` (`HomeNuit.swift:2243`) | **jamais** — écrit le 01-09 |
| Progress | défaut `true` (`ProgressPage.swift:124-127`) | oui, **hors séance** |
| Exercices | défaut `true` (`ExercisesView.swift:469-473`) | oui, **hors séance** |
| Fiche exo | défaut `true` (`ExerciseDetailView.swift:607-615`) | oui, **hors séance** |

> **Dès qu'une séance est ouverte, la prise lune n'existe sur AUCUNE page** :
> la bande du bas devient le dock du player. C'est exactement ce qu'elle
> décrit (« là où il y a le player quand une session est ouverte »), et c'est
> par construction depuis le §3.

### D.2 — L'effet du correctif des 17 pt : il devrait AMÉLIORER, pas casser

La prise fait 30 pt et est alignée en bas du ZStack. **Avant** le correctif, le
contenu débordait de `safeBottom / 2 = 17 pt` sous le bas de la frame : la
prise était donc **à cheval sur la bande basse qu'iOS se réserve** pour ses
propres gestes de bord — le piège que ce dépôt documente déjà
(`MenuNappe.swift:1420-1422` : « il n'en reste que 13 pt à l'écran, collés à
l'arête — et le système se réserve cette bande pour ses propres gestes »).
**Après**, elle est entièrement dans la zone sûre.

Et c'est un **alignement de layout**, pas un `.offset` : pixels et zone tactile
se déplacent ensemble.

> 🔴 **Non vérifié au doigt** — le simulateur ne pose pas de doigt. Si sa plainte
> est ANTÉRIEURE à ce matin, l'hypothèse la plus probable est que la prise était
> mangée par la bande système, et **le correctif la répare**. À confirmer par
> elle sur l'appareil.

### D.3 — Toutes les causes possibles, par probabilité

1. **Elle a testé sur la HOME** → n'a jamais existé (`luneAuDrag: false`).
2. **Elle a testé pendant une séance** → n'existe sur aucune page.
3. **La prise tombait dans la bande système** (17 pt sur 30) → réparé ce matin,
   à confirmer au doigt.
4. Le chien de garde de `tirageLune` / un `onEnded` manqué qui laisserait
   `levee` coincée — à re-lire si 1-3 sont écartées.

---

## §0 — Les 4 demandes, telles que dites

1. **La phrase à 4 lignes max**, en enlevant « out of 4 planned. ». Plus tard,
   ce texte CHANGERA (même pendant la séance) et s'animera légèrement pour dire
   que l'app est vivante. Look Apple gardé. « Ça va remonter un peu nos 3 cards. »
2. **Remonter la pill de nav** collée en bas (comme le pull), et **pareil sur
   l'écran de slide** (« You showed up » / « Send it »).
3. **La nav-pastille du côté disparaît COMPLÈTEMENT quand on pull.**
4. **Séance en cours → le widget chemin devient vivant** : les deux lignes
   changent de texte, un petit point blanc pulse légèrement, et le halo de
   séance pulse beaucoup plus.

⚠️ Et l'avertissement : « la home c'est une grosse card, NE CASSE RIEN —
normalement je peux drag vers le haut la home et avoir la petite lune comme les
autres pages. » → **§7 : ce point contredit le code.**

---

## §1 — La phrase : passer de 5 à 4 fragments

### Ce qui est vrai aujourd'hui

- 5 `PhraseFragment`, écrits à la main, alternance clair/sourd —
  `HomeNuit.swift:302-313`. Montage `:2953-2962`, **ancré par le HAUT**
  (`.padding(.top, 48)`, `:2968`).
- Le rendu traite **la dernière ligne à part** : `fragments.dropLast()` sous le
  masque, puis `fragments.last` hors du masque — `HomeNuit.swift:430-456`. La
  raison est écrite : le galet de verre vit dans la dernière ligne, et un
  `.mask` posé dessus lui mangerait sa transparence.

### 🔴 LE RISQUE N°1 — la ligne qu'on enlève porte le SEUL réglage de l'objectif

`ObjectifTouche` (le galet de verre + son panneau 3→7) n'est monté que dans la
branche `f.objectif != nil` — `HomeNuit.swift:463-476`, et **un seul fragment
porte un `objectif` : le 5ᵉ** (`:309`). Un seul site d'appel dans tout le dépôt
(défini `:679`), et son `choisir()` (`:818-826`) est l'unique écrivain.

Vérifié par grep sur la clé elle-même (`Goal.cleHebdo = "objectifHebdo"`,
`Models.swift:574`) : **aucun autre `UserDefaults.set`**. `ProgressPage.swift:80`
déclare le même `@AppStorage` mais ne fait que LIRE (`:350`).

> **Supprimer la ligne 5 supprime la seule porte de réglage de l'objectif
> hebdomadaire.**

✏️ **Deux corrections de portée, apportées par les juges — ne pas dramatiser :**

- **Ce n'est pas « toute l'app ».** `Goal.hebdo` n'a aucun site d'appel, et les
  pages anciennes (`HomeView`, `HomeAuroraView`, `CalendarView`,
  `SynthesisService`) lisent la **constante** `Goal.weeklyTarget = 5`, jamais la
  clé. La perte réelle se limite à **deux écrans** : la home v2 (la card
  « / N », le pied « N sessions left to hit your goal ») et ProgressPage.
- **Ce n'est pas « figé à 5 ».** La valeur reste celle qu'elle a déjà choisie —
  4 sur sa capture. Le mot juste : **figé sur la dernière valeur choisie, plus
  jamais modifiable**, sans aucun message.

**Trois sorties** (à trancher, Q1) :
- **A.** Le galet déménage sur une autre ligne (« 11 of ⟨4⟩ workouts ») ;
- **B.** Il déménage hors de la phrase — la card « Sessions this week » porte
  déjà le « / 4 », c'est son lieu naturel ;
- **C.** On assume la perte. **Dette visible, à écrire quelque part.**

### 🔴 LE RISQUE N°2 — le fondu croisé du départ perd son raccord

Quand on pull, la phrase d'accueil DESCEND et la phrase d'arrivée (« You showed
up… ») MONTE, et **leurs bas sont confondus à chaque image** : c'est ce qui
autorise le fondu croisé sans que la ligne qu'on lit ne bouge d'un pixel
(`HomeNuit.swift:2904-2911`).

- l'accueil est ancré par le HAUT (`:2968`) et descend de `chute` (`:2999`) ;
- l'arrivée est épinglée par le BAS (`.frame(…, alignment: .bottomLeading)` +
  `.padding(.bottom, leveeTiroir + 6)`, `:2900-2903`) — **son bas ne dépend pas
  de son nombre de lignes** ;
- la course est une constante : **`DepartCine.courseTexte = 403`**
  (`DepartCine.swift:66`), dérivée de « bas à 291 → bas à 694 ».

Enlever une ligne remonte le bas de l'accueil d'une hauteur de ligne (**≈ 34 à
36 pt** selon qu'on lit `DepartCine.swift:48` ou `taille × 1,14 + interligne` —
c'est justement pourquoi ça se **mesure**).

✏️ **Formulation corrigée par le juge, et elle est plus utile que la mienne :**
rien ne « saute » en vol — les deux blocs partagent le même `chute`, donc
l'écart est **constant** pendant toute la chute. Ce qu'on verra est un **FAUX
RACCORD** à l'instant du fondu croisé (`basculeAt 0,94`, `0,12 s`,
`DepartCine.swift:76`) : le bloc sortant et le bloc entrant sont désalignés de
~35 pt au moment précis où ils se substituent. C'est exactement la
« métamorphose » validée qui redevient un remplacement.

> **Le vrai remède : ré-ancrer la phrase d'accueil par son BAS**, comme
> l'arrivée. Elle devient alors immunisée au nombre de lignes — ce dont la
> demande « le texte changera même en séance » aura besoin de toute façon.
> Le calcul `403 + 35 ≈ 438` est une estimation : **la cote se lit sur le
> rendu** (`-arriveeFige`, `-departFige`), elle ne se déduit pas.

🟠 **Et il y a un doute ANTÉRIEUR à cette demande**, soulevé par deux lecteurs
indépendamment : les cotes 291 / 694 / 403 (et « slider 768..830, écran 840 »)
datent d'AVANT le passage en plein écran physique de `PageCard`. Si le
conteneur a grandi de la safe area basse, **le fondu croisé est peut-être déjà
décalé aujourd'hui**. Empiler un changement de lignes par-dessus une dérive non
mesurée, c'est empiler deux erreurs. → **mesurer d'abord** (Q0).

### 🟡 Les deux casses mécaniques — plus petites que je ne l'ai dit

✏️ **Le pied du dégradé — cosmétique mineur, et dans l'autre sens.** Si la
dernière ligne devient « this week » (texte nu), elle passe par la branche
`else` (`:478`) qui appelle `mot()` **sans `atenu`** (défaut 1, `:493-494`) et
sort du masque. Mais « this week » est `clair: false` : son alpha passe de
**≈ 0,398 à ≈ 0,442** — +11 % relatif sur une ligne déjà sourde, qui reste
**deux fois plus sombre** que la ligne au-dessus. Pas la marche de luminosité
que j'annonçais.

> Remède propre quand même : **si le galet quitte la phrase, le cas spécial de
> la dernière ligne n'a plus de raison d'être** — les 4 fragments rentrent dans
> le `VStack` masqué et `atenu` disparaît. Le fichier le dit lui-même : cette
> exception n'existe QUE pour le galet de verre (`:422-429`).

✏️ **`duréeTotale = duree + 4 × retard` (`:366`) — hygiène, pas un bug.** Le
`4` est bien `count − 1` en dur, et à 4 fragments l'arrivée finit à p = 0,904.
Mais pendant ces 140 ms tout est déjà à u = 1 : **rien ne bouge, rien ne
« traîne »**, aucun `completion` n'y est accroché. Et la reconstitution du banc
(`avanceePhrase(t) = (t − 0,38)/1,46`, `:4114-4117`) ne se décale pas non plus,
puisque `duréeTotale` ne dépend pas du nombre de fragments. → à rendre honnête
en passant, **pas un prérequis de livraison**.

### 🔴 DÉFAUT PRÉSENT, découvert au passage (rien à voir avec la demande)

`faitsAffiche` (`:1968-1971`) lit `stats?.faites` et nourrit la phrase
(`:2956-2957`). Or **`stats` est réassigné à `:2643`, dans `rendreLaHome()`,
APRÈS la fermeture du `withAnimation` de `:2639`** : le chiffre de la phrase
**saute** aujourd'hui à la clôture d'une séance, au lieu de rouler. Le
`.contentTransition(.numericText())` posé sur chaque mot (`:503`) est là, il
n'est simplement jamais dans une transaction. **C'est un 🔴 gratuit à corriger
en même temps que J1.**

---

## §2 — « Ça va remonter un peu nos 3 cards » : NON, pas tout seul

**Rien ne coule.** Dans le `ZStack(alignment: .topLeading)` de `mobilierScene`
(`HomeNuit.swift:2864`), la phrase et les cards sont **frères**, posés en
coordonnées absolues :

| Bloc | Ancre | Cote |
|---|---|---|
| La phrase | `:2968` | `.padding(.top, 48)` |
| Les 2 cards | `:3052` | `.padding(.top, h × 0.375)` |
| Card ROUTE | `:3097` | `.padding(.top, h × 0.620)` |
| Ardoise « This week » (banc) | `:3140` | `.padding(.top, h × 0.620)` |

Et **`0.375` est répété 4 fois de plus** (5 sites en tout), tous à re-caler
ensemble :

- `origineSlot()` — l'origine du vol de la vitrine : `cy = h × 0.375 + 85` (`:2012`)
- la drop-list du mode édition : `h × 0.375 + 14` (`:3170`)
- la poudre d'adieu d'un widget supprimé : `h × 0.375 − 30` (`:3176`)
- la pop-up de refus : `h × 0.375 − 88` (`:3181`)

> Enlever une ligne de phrase ne remonte RIEN : ça creuse ~35 pt de vide.
> Remonter les cards est un **second geste explicite**, et il touche 5 sites
> pour `0.375` + 2 pour `0.620`.
>
> **Remède : sortir les deux fractions en constantes nommées** et les lire
> partout — sinon la prochaine session en oubliera une, et le vol de la vitrine
> partira d'une case vide sans que personne ne fasse le lien.

✏️ **Précision d'un juge** : le précédent que j'avais cité (« la prise de relais
saute de 4 pt et de 4 % », commentaire `:2005-2014`) parle du **zoom du mode
édition** (`z = 1 − 0,04 × editionP`), **pas** de la fraction. Le risque tient,
le précédent était mal choisi.

⚠️ **Le `geo` de tout `mobilierScene` est la géométrie de la PAGE**
(`GeometryReader` de `:2138`, passé à `pageContenu(geo)` `:2150`), pas celle du
conteneur réel — la card de `PageCard` fait `Hs + safeBottom`. **Toute cote
dérivée de `geo.size.height` porte donc un décalage de safe area.** Ne calculer
aucune nouvelle cote de tête : mesurer au banc.

Le ScrollView est MORT (`:2964-2967`) : « la home tient sur un écran, c'est le
TIRAGE qui la déplace ». Il n'y a aucun flux à laisser faire.

---

## §3 — Remonter la pill de nav et le slide

### D'abord : ce n'est PAS `JewelTabBar`

`JewelTabBar` est **morte** — `WoopApp.swift:1119-1121` : « §23 : la home v2 n'a
PLUS de nav bar […] la barre bijou ne se montre plus nulle part, le code reste
pour l'archive de la v1 » (`barreBijouVisible` toujours faux, `:721-726`).
🔴 **Éditer `WoopApp.swift` compilerait, se commiterait, et ne se verrait nulle
part.** Et le banc `-navLab` (`NavLab.swift:11-56`) ne monte QUE cette barre
morte : un verdict pris là porterait sur un composant qui n'existe plus.

L'objet visé est le **galet maison** de `MenuHote` — `MenuNappe.swift:1029`,
dessin `:1376`, place `.padding(.leading, 24)` + `.padding(.bottom, 24 + placeDy)`
(`:1405-1406`). Banc juste : **`-menuLab`**, puis la home réelle avec
**`-tirageFige <pt>`**.

### 🔎 POURQUOI ça paraît « collé en bas » — la vraie cause

Hors séance, **la card-page est PLEIN ÉCRAN PHYSIQUE** : `PageCard.swift:76-79`
pose `hPage = Hs + safeBottom` et décale la page de `+safeBottom`. La page
descend **sous la home bar**. Les 24 pt du galet et de l'invite se mesurent donc
depuis un bas de card déjà ~34 pt sous la zone sûre.

🟠 **Et il y a peut-être pire** : le `ZStack` reçoit `.frame(width: W, height: Hs)`
(`PageCard.swift:112`) alors que son enfant fait `Hs + safeBottom` — un enfant
plus grand que sa frame est **centré**, donc il déborde en haut ET en bas. Un
lecteur chiffre le débordement bas à ~17,5 pt. **Je n'ai pas mesuré** : le
layout SwiftUI d'un enfant surdimensionné dans une `.frame` fixe ne se déduit
pas de tête. → **Q0 : mesurer le bas de la home au banc avant de choisir un
chiffre.** Si le débordement est réel, c'est une dette antérieure qui remonte
les **quatre** pages de `PageCard` d'un coup, et il ne faut pas la cumuler avec
une remontée de la pill : les deux ensemble feront trop.

### Comment remonter, et ce qui casse en cascade

- 🔴 **Jamais un `.offset(y: -N)`.** Les pixels monteraient, la zone tactile
  resterait collée en bas — la loi payée du tapis v5, et déjà payée sur CET
  objet (« parfois je suis bloquée, j'arrive plus à la tirer »). **Passer par
  `placeDy`** (`HomeNuit.swift:2530`), le seul paramètre relu à la fois par le
  dessin (`MenuNappe.swift:1406`), le centre de la couronne (`:1705-1708`), la
  borne de rangement (`:1986`) et la géométrie de la couronne (`:1889`).
- ⚠️ **La navette rangée suit la place** : `hauteurRange = 72` est un **écart**,
  pas un absolu (`:1197`). Remonter la place remonte la tranche de l'écran
  slide — et la cote qui la justifiait (« MESURÉ au banc `-homeSeance` ») devient
  fausse. Décider les DEUX places ensemble.
- ⚠️ **La borne du transport devient asymétrique** : la butée basse suit
  `placeDy` (`3 + placeDy`), la butée haute reste absolue (`107 − hauteur`,
  `:1986`). La plainte « j'arrive plus à la ranger » peut revenir par l'autre
  bout. Vérifier les deux butées au doigt.
- 🔴 **CHANGEMENT DE COMPORTEMENT NON DEMANDÉ** : le galet couvre aujourd'hui le
  coin bas-gauche de la poignée du pull (112 pt) et lui prend le doigt (il est
  peint après `contenu()`). **Le remonter LIBÈRE cette surface — et le tap de
  cette poignée appelle `lancer()`** (`HomeNuit.swift:3246-3259`), donc lance une
  séance. Un pouce posé bas à gauche déclencherait désormais un départ.
- ⚠️ **La poignée du pull fait 112 pt** (`Self.poigneePull`, `:2111`), montée en
  `ZStack(alignment: .bottom)` (`:3226-3236`). Remonter le DESSIN de l'invite ne
  remonte pas la BANDE DE PRISE. **Les deux ensemble, toujours.**
- ⚠️ **La fumée d'invite est clouée au chevron** : `FumeeInvite.assise = 96`
  (`:4470`). Si l'invite monte, `assise` monte d'autant, sinon la fumée se
  décolle des mots.

### L'écran de slide (« Send it ») — ce n'est pas une page

C'est **la même home**, card soulevée de `leveeTiroir = 140` (`:2093`) :

- la phrase d'arrivée est épinglée `.padding(.bottom, leveeTiroir + 6)`
  (`:2903`) — elle suit la card toute seule ;
- le slider `SliderObsidienne(height: 62)` vit **dans la bande noire sous la
  card**, `.padding(.horizontal, 12)` + `.padding(.bottom, 10)` (`:2918-2938`).

🟠 **Le bas de cet écran est un budget géométrique FERMÉ** :
`140 = 34 (l'air de la gerbe de poudre du commit, qui monte à 33,8 pt hors
cadre) + 62 (slider) + 10 + 34 (réserve d'indicateur)` — `:2933-2938`.

> Remonter le slider de N mange N sur ces 34 pt. **Deux chiffres, pas un** : si
> le slider monte de X, `leveeTiroir` doit monter de X — mais `leveeTiroir` est
> aussi le **diviseur du `tanh`** de l'élastique du pull (`:3467-3469`) et le
> repos de la card (`:2115-2118`). Le toucher, c'est re-caler tout le geste.
> **Alternative honnête : rester sous ~24 pt et raboter sciemment la gerbe.** (Q3)

✏️ **Ambiguïté à lever avec elle** : sur l'écran de slide il y a DEUX objets
« en bas » avec deux constantes différentes — la **navette** (écart 72,
`MenuNappe.swift:1197`) et le **slider « Send it »** (padding 10,
`HomeNuit.swift:2938`). Lui faire pointer l'objet sur la capture avant d'écrire
une ligne.

---

## §4 — La pastille qui disparaît au pull

### Le crochet existe déjà… et il ne suffira probablement pas

`MenuNappe.swift:1066-1069` porte, mot pour mot, sa demande :

> « §3.4quater (verdict 01-09) : *on ENLÈVE la pastille home quand on pull et
> voit le slider* — le rangement l'ENCASTRE, ce drapeau l'ÉTEINT (opacité
> animée, jamais un démontage en plein geste). » — `var galetCache: Bool = false`

Appliqué `:1413-1414`. **`grep -rn galetCache Woop/` ne rend que ces 3 lignes :
aucun site d'appel.** La home ne le passe jamais (`HomeNuit.swift:2482-2530`).

Et la tranche qu'on voit est **voulue, pas un offset raté** : au pull le galet
passe en mode `range` — une capsule 26 × 84 encastrée dans le mur, dont il reste
« **13 pt à l'écran**, collés à l'arête » (`MenuNappe.swift:1420`).

### 🔴 CORRECTION MAJEURE — `galetCache` seul ne l'effacera pas

Le corps du galet, hors transport, est un `GlassEffectContainer` +
`.glassEffect(.clear.interactive())` — `MenuNappe.swift:232-241`. Et le dépôt
écrit **deux fois, mesuré**, que **le verre natif IGNORE `.opacity`** :
`MenuNappe.swift:239-241` (« Le verre natif IGNORE `.opacity` — mais l'encre,
elle, se DÉMONTE ») et `HomeNuit.swift:2570-2579` (« L'extinction du menu ne peut
rien contre du verre natif […] les carcasses des deux cards restaient
lisibles »).

> `.opacity(0)` retirera l'ENCRE et laissera la **capsule de verre** peinte.
>
> **L'échappatoire est déjà écrite dans le fichier** : `transport` échange le
> verre contre une **doublure mate** dessinée à la main (`:117-125`, `:200-232`),
> et le reste de la home fait pareil via `\.verreDemonte` (`HomeNuit.swift:2578`).
> La direction : que le drapeau de disparition force AUSSI la doublure (ou
> retire le conteneur de verre par un `if`), pas seulement l'opacité.
> **Et le prouver à la CAPTURE, pas au raisonnement.**

### 🔴 CORRECTION DE CE QUE J'AI DIT — le galet N'EST PAS sourd pendant le pull

J'ai écrit que le piège du hit-test ne s'appliquait pas. **C'est faux avant le
cran.** Les deux drapeaux ont la même condition :

```
rangerDemande: (tiroirOuvert && !enSeance) || vitrineSlot != nil   // HomeNuit:2514
verrouille:    (tiroirOuvert && !enSeance) || vitrineSlot != nil   // HomeNuit:2519
```

et **`tiroirOuvert` ne devient vrai qu'au COMMIT** (`lancer()`, `:3644`). Donc
pendant tout le drag — la moitié du geste — le galet est **plein, visible et
vivant** (`allowsHitTesting(!verrouille)`, `MenuNappe.swift:1455`). Un pouce qui
commence le pull dans le coin bas-gauche **ouvre le menu au contact** (`:1502`)
puis, à 5 pt, **emporte le galet avec le doigt** (`:1537-1549`).

**Deux conséquences directes :**

1. « dès qu'on pull » ne peut pas être branché sur `tiroirOuvert` — il arrive
   trop tard. Il faut un signal du DÉBUT du geste. (Q4)
2. ⚠️ **Ne pas piloter la disparition par une valeur VIVANTE** (une opacité
   fonction de `tirage`) : `MenuHote` est un sous-arbre de ~2 200 lignes avec
   verre natif, `TimelineView` et shader de fumée — le réévaluer à chaque image
   sous le doigt, c'est le régime où la home a déjà été mesurée à 36,8 img/s.
   **Un booléen qui bascule une fois**, l'animation de 0,22 s est déjà écrite.
3. ⚠️ Et le drapeau doit se remettre à plat aux **trois** endroits déjà écrits —
   changement de `startLocation`, `onEnded`, **chien de garde** — comme
   `cranSenti` et `luneSentie` (`HomeNuit.swift:3406-3412`, `:3605-3621`). Ce
   geste-ci est précisément celui que la Reachability d'iOS vole sans appeler
   `onEnded` : sinon la pastille reste invisible pour toujours.

### ⚠️ Deux animations sur le même objet

Si `galetCache` bascule au même instant que `rangerDemande`, le galet joue son
**encastrement** (spring 0,42 s) pendant qu'on lui demande son **extinction**
(easeOut 0,22 s). Le dépôt a déjà payé « deux `withAnimation` au même tour ne
jouent rien ». → **Trancher qui commande** : si la pastille s'éteint au pull, le
rangement n'a plus lieu d'être au pull (il ne sert plus qu'à la vitrine). **Un
seul mécanisme, pas deux superposés.**

---

## §5 — Le chemin vivant en séance

### 🔴 LA PRÉMISSE EST FAUSSE SUR LE FLOW PRINCIPAL

`verreMonte` commande le montage des cards ET de la card chemin
(`HomeNuit.swift:3023`, `:3085`). Ses trois écritures :

| Ligne | Fonction | Valeur |
|---|---|---|
| `:3645` | `lancer()` — le film de départ | **`false`** |
| `:3698` | `fermer()` — on referme le tiroir | `true` |
| `:2634` | `rendreLaHome()` — **après qu'une séance se CLÔT** | `true` |

Et `rendreLaHome()` n'est appelée que par
`.onChange(of: enSeance) { _, encore in guard encore else { rendreLaHome(); return } }`
(`:2408`) — **c'est-à-dire quand `enSeance` passe à FAUX.**

> **Sur le chemin slider → chemin → séance, `verreMonte` reste `false` pendant
> toute la séance : la card CHEMIN n'est même pas MONTÉE.** Le commentaire de
> `:3639-3643` le dit pour l'avoir payé : « SEULE `fermer()` remontait — jamais
> appelée sur le chemin slider → chemin → séance → fin. C'est la cause entière
> de la "home vide" du verdict. »
>
> **L'exception** : si l'app est relancée alors qu'une séance est ouverte,
> `verreMonte` naît à `true` (`:1909`) et `lancer()` n'est jamais appelée — là,
> le mobilier EST à l'écran. C'est probablement dans cet état-là qu'elle a vu la
> card pendant une séance.

**→ Avant d'écrire un texte de séance dans cette card, il faut répondre : « la
home montre-t-elle son mobilier pendant une séance ? »** (Q7) C'est la famille
de la « home vide », déjà payée deux fois.

### Le fil qui manque

`CardRoute` reçoit **cinq choses** : `lecture`, `pose`, `verre`, `lisere`,
`onTap` (`CardRoute.swift:136-149`). **Aucun signal de séance.** La home, elle,
le connaît : `enSeance = !seancesOuvertes.isEmpty` (`HomeNuit.swift:1842-1844`),
et `debutSeance` avec.

⚠️ **Ne pas donner un `@Query` à `CardRoute`** : elle est aussi montée par son
banc `RouteCardLab` (`CardRoute.swift:516-613`), qui n'a ni home ni
`ModelContainer` — un `@Query` **planterait le banc**, c'est-à-dire la seule
boucle courte pour juger le dessin. L'information descend comme `lecture`
descend déjà : un **paramètre de valeur**, nourri au site d'appel `:3086` où
`enSeance` est déjà en portée.

⚠️ Et elle se calcule **chez l'hôte**, jamais dans le `body` — `CardRoute.swift:137-139`.
Le patron maison est `majLectureChemin()` / `stats` : **deux sites seulement**
(l'arrivée sur la page, la clôture d'une séance), jamais dérivé dans un corps.
`dalleHome` fait déjà tourner `seriesPayantes` (boucle sur tous les exos × toutes
les séries) à chaque évaluation — la phrase de séance doit être une **chaîne
déjà faite**, rangée dans un `@State`.

⚠️ **`SemaineStats.calcule` filtre les séances non terminées**
(`WidgetsCards.swift:2200-2210`) : `stats` **ne peut pas** nourrir un texte
vivant pendant la séance. Il faudra une autre source (la séance ouverte
elle-même) — ou un champ « en cours » séparé, sans toucher au compte de la
semaine qui doit rester celui des séances FINIES.

### 🔴 Les deux lignes : le texte peut passer SOUS les galets

`texte` et `bande.padding(.leading, 146)` sont frères dans un `ZStack(.topLeading)`
(`CardRoute.swift:225-234`), et `texte` porte `.frame(width: Self.L /* 354 */,
alignment: .leading)` avec `.padding(.leading, 22)` — **ni `lineLimit`, ni
largeur bornée**. Aujourd'hui « Étape 3 sur 9 » est court, donc ça ne se voit
pas. **Un libellé de séance plus long passera sous les pierres**, et le défaut
ne se verra qu'à l'appareil. → borner à sa gouttière réelle (≈ 354 − 22 − 146 =
186 pt) **avant** d'écrire le nouveau texte.

⚠️ Les deux `Text` portent `.contentTransition(.numericText())` (`:262`, `:268`) —
c'est une transition conçue pour des **chiffres qui roulent**. La faire jouer
sur un changement de PHRASE donnera un roulement de lettres. **Deux transitions
différentes selon ce qui change** : `.numericText()` tant que seuls les nombres
bougent ; une identité de vue + fondu/glissement quand c'est la nature du texte
qui change.

⚠️ Le rang affiché **ne bougera pas** pendant la séance : l'étape n'avance qu'à
la clôture (`HomeNuit.swift:2658-2662`), et l'aperçu est de la démo qui rend
toujours « étape 3 » (`CardRoute.swift:534-539`). Si le texte de séance remplace
« Étape 3 sur 9 », on perd le seul chiffre de la card ; s'il ne le remplace pas,
on affiche deux vérités. (Q5)

### 🟢 Le halo : l'entrée existe déjà, et elle est gratuite au repos

**Ne pas amplifier le halo du galet actif.** Il vaut 0,95 × Ø et **sort de son
propre cadre dès Ø > 57,8** (`CardRoute.swift:156-161`, on est à 54) ; la bande
porte en plus un `.mask(fonduBords)` (`:330-337`, `:371`) et la card est
`clipShape`ée (`:237`). Il serait **tranché deux fois**. Et `GaletEtape` est un
composant **partagé** avec la page route (validée) et `DuolinguoPage` : toucher
ses coefficients repeindrait la route dans le même geste.

> **La bonne porte : `ArdoiseFond.lueur`** — le halo à l'échelle de la CARD.
> Il existe (`WidgetsCards.swift:447`, rendu `:490-496`), il est **déjà nourri**
> par `CardRoute` (`lueur: (defile || lueurForcee) ? 1 : 0`, `:228`), le
> paramètre `lueurForcee` est **déjà exposé** (`:213`, utilisé par le banc `:571`),
> et il **ne coûte rien au repos** : `if lueur > 0.01 { … }`.

### ✏️ Le point qui pulse : moins cher que je ne l'ai dit

Un juge a **réfuté** mon avertissement « une respiration permanente réveillerait
une page volontairement endormie » (§9). Les faits, vérifiés :

- il y a **six** `TimelineView` dans `HomeNuit.swift` + une dans `WorkoutPill` ;
  **seule celle de `:2478` est pausée** par `depart`/`ferme` ;
- **`InviteTirage` bat déjà à 30 Hz en permanence** (`:4514-4515`), y compris
  pendant toute la séance — elle n'est que masquée par `.opacity` (`:3237`) ;
- les 681 ms de trou étaient **le flou**, et il a été corrigé (`:2837-2838`).

**La règle qui reste vraie, et la seule :** ne pas réveiller la `TimelineView`
RACINE (`:2478`) — c'est le seul endroit où une horloge ré-évalue tout le body
de la page, et le fichier l'écrit lui-même (`:2564-2566`).

> **Le patron maison pour un souffle permanent existe et n'ajoute AUCUNE
> horloge** — `WorkoutPill.swift:365-367 / 417-420 / 443` :
> ```swift
> @State private var lueur = false
> …
> .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: lueur)
> .onAppear { lueur = true }
> ```
> « UNE animation `repeatForever`, jamais une TimelineView de plus. »

⚠️ Deux gardes tout de même :
- **le `@State` d'une pulsation posée DANS `CardRoute` meurt** au démontage
  `verreMonte` → la phase sauterait à chaque aller-retour de la home. Une
  fonction pure du temps (l'école `LaunchPebble.breath`) n'a pas ce défaut.
- **le point est décoratif : `.allowsHitTesting(false)`.** La porte de la route
  passe par le tap de la card entière, et une vue qui s'intercale avec sa propre
  zone tactile la volerait — le bug déjà payé deux fois (« je n'arrive pas à
  activer la route en cliquant sur le widget This week »), et la raison pour
  laquelle les 9 galets sont `inerte: true`.

🟠 Enfin : « pulse **beaucoup** plus » pousse contre une loi payée trois fois ici
(« une invite qui se voit est une alarme », deux périodes incommensurables,
amplitude basse — `HomeNuit.swift:4441-4453`). Ce n'est pas un refus : c'est un
arbitrage à faire à l'œil, au banc, **en le sachant**.

---

## §6 — Ce qui juge, et ce qui ne juge PAS

- 🔴 **Aucune sonde ne surveille cette colonne.** Les juges du fouettage
  comparent la **bande basse** (`tools/player/fouettage/juge_page.py:5-13`,
  boîte canonique 68/1100/0/76) : un décalage vertical de la phrase ou des cards
  leur est **totalement invisible**. `mesure_rasant.py` ne juge que la lumière.
  → **Le verdict de J1 et J2 se prend en CAPTURE**, pas au juge automatique.
- ⚠️ **Mais J3 et J4 changent les pixels de la bande basse** : le juge PAGE
  exigera l'égalité à ±6 px et **échouera — légitimement**. Il faut
  **re-baseliner délibérément** les 4 pages avant/après et le dire dans le
  rapport. Sinon un échec réel se confondra avec l'échec attendu.
- Bancs utiles, tous vérifiés existants : `-homeV2`, `-phraseLab`,
  `-phraseFige <p>`, `-arriveeFige <s>`, `-departFige`, `-phraseRejoue`,
  `-phraseScroll <pt>`, `-galetOuvert`, `-galetChoisit <n>`, `-semaineFaits <n>`,
  `-homeSeance`, `-homeChemin`, `-tiroirOuvert`, `-tirageFige <pt>`, `-pullAuto`,
  `-cotes`, `-menuLab`, `-vitrineAuto`, `-pullSonde <n>`, `-fps`.
- ⚠️ Beaucoup de ces drapeaux **ne montent pas le banc à eux seuls** : ils se
  cumulent avec `-homeV2` ou `-phraseLab`, sinon on lance l'app entière (splash
  + auth).
- ⚠️ `./tools/charge.sh` **avant** tout `-fps` (🔴 au-dessus de 2), et **la vraie
  cadence se mesure sur le TÉLÉPHONE**.

---

## §7 — 🔴 LE LITIGE : « je drag vers le haut la home et j'ai la petite lune »

C'est l'avertissement le plus important, et **le code dit le contraire.**
Trois lecteurs indépendants et un juge adverse ont convergé.

- `PageCard` porte bien la petite lune, révélée par une prise invisible de 30 pt
  — **mais seulement si `luneAuDrag` est vrai** (`PageCard.swift:105-112`).
- **La home passe explicitement `luneAuDrag: false`** — `HomeNuit.swift:2149`,
  avec sa raison écrite : « le tiroir de la home possède déjà le geste du bas —
  pas de prise lune du moteur ici ». Même chose côté `PageCard.swift:31-33`.
- `luneFond` EST monté (`PageCard.swift:88-91`), mais `levee` n'est écrite que
  par `tirageLune`, qui n'est pas monté : elle reste à 0, et `luneFond` module
  sur `min(1, levee × 7)` = 0. **Invisible.** (Et c'est un petit « rideau » :
  un sous-arbre à trois passes d'ombre qui peint du vide en continu.)
- Le `luneP` de la home (`:2124-2127`) ne pilote **qu'une haptique** — « la
  braise du secret » (`:3512-3519`). Aucun rendu.

> **Verdict lu, pas déduit : aujourd'hui, tirer la home vers le haut ouvre le
> pull-to-start ; ça ne révèle aucune lune.** Les deux gestes ne cohabitent
> pas — l'un a été retiré pour l'autre le 01-09, hier.

**Trois lectures possibles, à trancher (Q6) :**

1. **« ne casse pas la lune sur les AUTRES pages »** (exercices, progress,
   fiche) → rien à faire, mais toute modification du bas doit être re-jugée là ;
2. **« c'est une régression, remets-la »** → chantier à part entière : rebrancher
   la prise poserait un `DragGesture` concurrent dans les 30 derniers points,
   **pile dans la poignée du pull (112 pt)** et pile dans la bande que la
   Reachability d'iOS se réserve. Si ça revient un jour, ce doit être **un
   dérivé de `tirage`** (`luneP` existe déjà) — **jamais un second geste** ;
3. **elle parle du croissant en haut à droite** — qui est le bouton du coffre
   (`CoffreFortCoinButton`, `HomeNuit.swift:3275-3278`), et lui n'est pas menacé.

⛔ **Tant que ce n'est pas tranché, je ne touche pas au bas de l'écran.**

### La liste noire — ce qu'on ne touche pas, quoi qu'il arrive

- **`tirageGeste`** est en `.simultaneousGesture` et **non** en `.gesture`
  exprès (`HomeNuit.swift:2601`) : en exclusif il affamerait le slider, le
  galet, les cards et l'ardoise. Seuil 2 pt, verrou d'axe 4 pt — recalés trois
  fois sur verdicts. **Aucune nouvelle surface tactile dans les 112 derniers
  points, aucun changement de type de geste.** Si une zone doit bouger, on la
  déplace, on n'en ajoute pas.
- **`enSeance ? nil : tirageGeste`** reste intact. Réactiver le tirage en séance
  ferait cohabiter un drag d'ancêtre page-large avec le **pan maître de la
  fenêtre** (`PlayerMonde.swift:730-739`) — c'est le verdict n°1 du 26-08 (« le
  bouton Stop ne répond pas… je ne peux pas non plus ouvrir le menu »). Toute
  interaction de séance sur la home passe par des **taps d'enfants**.
- **Le site de montage du player et son zIndex** : le pan maître est unique par
  fenêtre (`static weak var fenetrePosee`, `PlayerMonde.swift:648-662`) et n'est
  retiré qu'au `dismantleUIView`. Le déplacer = un pan zombie, ou plus de pan du
  tout.
- **`LuneSecrete` / `GlypheLune`** sont définies dans `HomeNuit.swift:1177` mais
  consommées par `PageCard`, `ExercisesView` et `CoffreV2`. **Ce n'est pas du
  code mort** — seuls `luneP` / `luneSentie` sont orphelins côté home.
- **Toute bande ajoutée au bas du châssis** change `PlayerEtat.hauteurCourse`
  (`PlayerMonde.swift:356-361`), donc le rapport delta→p du suivi au doigt :
  la sensibilité validée du drag change même si rien n'a l'air d'avoir bougé.
  → **re-passer le fouettage.**

---

## §8 — Ce qu'il faut trancher avant de coder

| # | Question | Pourquoi elle bloque |
|---|---|---|
| **Q0** | Mesurer d'abord le bas réel de la home (débordement de safe area) — avant de choisir le moindre chiffre. | Les cotes des commentaires datent d'avant le plein écran physique ; deux lecteurs pensent que le fondu croisé est **déjà** décalé (§1, §3) |
| **Q1** | Le galet de l'objectif : il déménage (où ?) ou on assume de perdre le réglage ? | Seule porte de réglage, sur deux écrans (§1) |
| **Q2** | Remonter le bas : paddings, ou réparer le débordement ? | Le second remonte les 4 pages de `PageCard` d'un coup (§3) |
| **Q3** | De combien remonte le slider « Send it » — et est-ce bien le slider, ou la navette ? | Au-delà de ~24 pt il faut re-caler `leveeTiroir`, donc tout le pull (§3) |
| **Q4** | La pastille s'éteint à quel instant : premier point du drag, cran, ou progressif ? | `tiroirOuvert` arrive trop tard pour « dès qu'on pull » (§4) |
| **Q5** | Que DISENT les deux lignes du chemin en séance — et gardent-elles le rang ? | Rien n'est décidé, et le rang n'avance pas en séance (§5) |
| **Q6** | 🔴 La « petite lune au drag de la home » : invariant, régression, ou malentendu ? | Le code dit qu'elle n'existe pas sur la home (§7) |
| **Q7** | 🔴 La home montre-t-elle son mobilier PENDANT une séance ? | Sur le flow principal la card chemin n'est pas montée : la demande 4 n'aurait rien à animer (§5) |

---

## §9 — L'ordre de travail proposé

Du moins risqué au plus risqué. **Chaque jalon se montre avant d'être commité.**

- **J−1 — la MESURE (Q0).** `-tiroirOuvert`, `-arriveeFige`, `-cotes` : lire en
  pixels le bas des deux blocs de texte et le bas réel de la card. Rien d'autre.
  C'est ce qui rend tous les chiffres suivants honnêtes.
- **J0 — la pastille au pull** (§4). Le drapeau est écrit ; il reste à lui
  ajouter la doublure mate (le verre ignore l'opacité), à choisir son instant
  (Q4), et à le remettre à plat aux trois endroits du geste. Bancs
  `-tiroirOuvert`, `-tirageFige`, `-menuLab`.
- **J1 — la phrase à 4 lignes** (§1) : galet réglé par Q1, **ré-ancrage par le
  BAS**, `courseTexte` re-mesuré, cas spécial de la dernière ligne supprimé, et
  le `stats` de `:2643` remis dans sa transaction (le chiffre qui saute
  aujourd'hui). Bancs `-phraseLab`, `-phraseRejoue`, et **`-pullAuto`
  obligatoire** — c'est le fondu croisé qui se casse en silence.
- **J2 — les cards qui remontent** (§2) : fractions en constantes nommées,
  5 + 2 sites recalés. Bancs `-cotes`, `-vitrineAuto`, `-widgetsVides`.
- **J3 — le chemin vivant** (§5) : **après Q7**. Le fil `enSeance`, le texte
  borné en largeur, la bonne transition, le halo par `ArdoiseFond.lueur`, le
  souffle au patron `WorkoutPill`, le point sourd au doigt. Bancs `-homeSeance`,
  `-homeChemin`, puis `-fps` après `charge.sh`.
- **J4 — remonter le bas** (§3) : **après Q6**, et jugé au fouettage avec
  re-baseline assumée.

---

## §10 — Ce que je n'ai PAS vérifié

- **Rien n'a été lancé ni mesuré** : pas de build, pas de capture, pas de film.
  Tout ci-dessus est de la lecture de code.
- **Le débordement de `PageCard.swift:112`** (un enfant `Hs + safeBottom` dans
  une `.frame(height: Hs)`) est un **raisonnement de layout, pas une mesure**.
  Un lecteur l'estime à ~17,5 pt. C'est Q0.
- **La loi « le verre natif ignore `.opacity` »** est écrite deux fois dans le
  dépôt comme mesurée (`MenuNappe.swift:239-241`, `HomeNuit.swift:2570-2579`) ;
  je ne l'ai pas re-mesurée ici. C'est pourquoi §4 dit « probablement » et
  demande une capture.
- **La hauteur d'une ligne de phrase** : 34,2 pt (`DepartCine.swift:48`) ou
  36,2 pt (`taille × 1,14 + interligne`) selon la source. **Se mesure.**
- **Le comportement réel du drag vers le haut sur la home** (§7) est établi par
  lecture, pas rejoué au simulateur. **Si l'écran contredit cette lecture,
  l'écran gagne.**
- Le site de doc (`docs/site/`) ne couvre aucune de ces quatre demandes : elles
  sont purement côté téléphone, **aucune brique back-end n'est touchée — rien à
  mettre à jour côté site pour cette analyse.**
