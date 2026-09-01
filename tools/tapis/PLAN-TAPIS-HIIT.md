# LE PLAYER TAPIS — deux pastilles, le chrono qui se tape, la page qui s'embrase

**Plan du 31-08-2026, sur la demande de Kathryn** : *« pour le HIIT TAPIS,
l'affichage du chrono : deux boules. On part de la fiche détail, on slide le
galet (une autre session bosse dessus), et deux palets viennent sur la page
(le même design qu'actuellement), l'un vers le haut, l'autre vers le bas. Le
chrono se lance ; une petite phrase blanc dégradé Apple s'allume et s'éteint
("Tap to Stop") et un icon Stop blanc dégradé apparaît toutes les 3 secondes
dans la pastille, à la place du chrono. En dessous, la pastille du
kilométrage à 0, configurée avec une grosse molette blur de 0 à 20 km/h (à
17 km/h il faut trouver le bouton VITE). Un set se termine au clic sur stop
→ notification variant grosse pièce, "set 1 terminé + 20 pièces", et on
reste sur la page. Le chrono revient à 0, stop devient start, "tap to
start", ainsi de suite. Pour terminer la session : glisser le slider en bas.
Plus j'avance dans les sets, plus le fond de la page devient rouge. Fais un
plan, ne code pas, hésite pas à challenger. »*

**Rien n'est codé.** Tout ce qui suit est mesuré dans le code du 31-08 au
matin (arbre avec WIP multi-sessions : les `fichier:ligne` peuvent glisser).

> ⚠️ **Trois sessions vivent dans l'arbre** : le player/fiche
> (`PageCard.swift`, `ExerciseDetailView.swift`, `WorkoutPill.swift`,
> `PlayerSeance.swift` non tracké), le coffre (`WoopApp.swift` hunks), la
> progress. Les jalons J0-J2 de ce plan sont des **fichiers neufs + bancs**
> (zéro conflit) ; le J3 touche la fiche — il attend que la session du galet
> cardio ait posé, ou se coordonne avec elle. Commits par chemins explicites,
> jamais `git add -A`, jamais `git stash`.

---

---

# ⚠️ V2 — LE REJET DU J0 (31-08) ET CE QUI LE REMPLACE

**Son verdict, mot pour mot** : *« ça va pas du tout, les couleurs sont noir
dégradé beurk ; le premier est coupé par une claque noire ; on n'a pas la
grosse molette blur voulue qui prend tout le bas de l'écran pour changer le
km/h ; le slider n'est pas assez en bas ; quand je stop j'ai pas la
notification du set end avec mini recap + pièce ; bref ça va pas et c'est
pas clair je trouve au global. L'état "stop" et "end" pas assez
différenciants aussi en couleurs, on ne comprend pas ! Et en terme
d'animation aussi ! »*

**Le J0 est REJETÉ.** Ce qui suit remplace le §3 (anatomie) et précise le
§6. Rien n'est codé tant que cette V2 n'est pas validée.

## V2.1 — LE DIAGNOSTIC MESURÉ (mes trois fautes, pas des opinions)

**① LE GRIS : une lentille ne fabrique PAS de couleur, elle RÉFRACTE CE
QU'ELLE CONTIENT.** Mesuré sur ma capture, **sur les pixels clairs**
(jamais en moyenne) :

| zone | R | G | B | G/R | B/R | verdict |
|---|---|---|---|---|---|---|
| aura du chrono | 48 | 33 | 25 | 0,69 | 0,53 | brun sale |
| aura de la vitesse | 101 | 94 | 91 | **0,94** | **0,90** | **GRIS NEUTRE** |
| la loi de la maison (braise) | 1,00 | — | — | **0,30-0,45** | **≈0** | |

La cause est structurelle : sur le parcours muscu, la lentille vit sur un
**MONDE plein écran** (noir + spotlight + étoiles + **la traînée d'encre** +
le grain) et c'est ce monde COLORÉ qu'elle réfracte. Mon carré local ne
contenait QUE du noir et un anneau de halo : la lentille a réfracté du
vide, et rendu du gris. **La couleur ne se règle pas sur la lentille — elle
se met DEDANS.**

**② LA CLAQUE NOIRE : le carré opaque.** Saut de luminance mesuré à
**y = 1048 px : 231 sur 255**, c'est-à-dire un bord FRANC. Chaque pastille
portait son propre carré `Color.black` opaque posé sur la page : deux
plaques noires qui se coupent. C'est le mille-feuille que le plan player
interdit explicitement (§F : « à pleine levée l'écran est UNE surface »).
J'ai masqué le halo, pas le carré.

**③ LA MOLETTE ET LA NOTIF N'ÉTAIENT PAS LÀ — et c'était l'erreur de
découpage.** Je les avais rangées en J1/J2 en croyant livrer « la scène ».
Mais sans l'organe de la vitesse et sans la fête du stop, ce n'est pas une
scène incomplète : **c'est un écran qui ne raconte rien**. D'où « c'est pas
clair au global ». Un jalon qui ne se lit pas ne se montre pas.

## V2.2 — LES DEUX ÉTATS DOIVENT SE LIRE À UN MÈTRE (couleur ET animation)

Son grief central : *« l'état stop et end pas assez différenciants en
couleurs, on ne comprend pas — et en terme d'animation aussi »*. Le J0 avait
la MÊME robe pour les deux états : même aura, même vie, seul le glyphe
changeait. Un coup d'œil à 17 km/h ne peut pas trancher sur un glyphe.

**LA RÈGLE V2 : deux états = deux MATIÈRES, deux VIES, deux TEMPÉRATURES.**

| | ▶ **SET EN COURS** (ça brûle) | ⏸ **ENTRE-SETS** (ça refroidit) |
|---|---|---|
| **couleur** | **BRAISE VIVE** — R 1,00 · G 0,30-0,45 · B≈0. Et elle MONTE d'un palier à chaque set (le fond rouge de ta demande, porté aussi par la pastille) | **CENDRE** — la braise TOMBE (G/R ~0,80, très sombre), l'aura se contracte : le feu couve, il ne flambe pas |
| **animation** | **UN BATTEMENT PAR SECONDE** — la pastille pèse à chaque bascule (attaque 0,10 s), le halo bat avec ; la phrase « Tap to stop » pulse vite (2,6 s) | **UNE RESPIRATION LENTE** — inspire/expire sur ~4,5 s, AUCUN battement de seconde (le temps ne se compte plus pareil) ; le ▶ respire avec |
| **la bascule** | | **elle se VOIT** : au tap stop, la braise s'effondre en ~0,8 s (une décharge, pas un fondu) ; au tap play, elle se rallume d'un coup (0,25 s) puis s'installe |
| **encre** | chrono à pleine encre, gros | REST + le temps de repos en encre calme, le ▶ est le héros |

C'est ÇA qui rend l'écran lisible en courant : la couleur dit l'état avant
que l'œil lise un glyphe.

## V2.3 — LA NOUVELLE ANATOMIE (l'écran en trois étages, plus deux ronds posés)

Le J0 empilait quatre objets de même poids (phrase, rond, rond, slider) :
personne ne savait où regarder. **V2 : une hiérarchie explicite.**

```
 ┌───────────────────────────┐
 │        Tap to stop        │ ← la phrase, blanc dégradé qui pulse
 │      ╭───────────────╮    │
 │      │    SET 1      │    │ ← ① LE HÉROS : la pastille chrono,
 │      │     0:29      │    │   PLUS GROSSE (~300), braise vive,
 │      ╰───────────────╯    │   elle bat à la seconde
 │                           │
 │      ╭─────────╮          │ ← ② LE CADRAN VITESSE, plus PETIT
 │      │ 17 km/h │          │   (~170) et CALME : c'est un afficheur,
 │      ╰─────────╯          │   pas un deuxième héros. Tap = la molette
 │  ░░░░░░░░░░░░░░░░░░░░░░░  │
 │  ░  LA GROSSE MOLETTE  ░  │ ← ③ TOUT LE BAS, en verre fumé :
 │  ░  5   6   7  [8]  10  ░ │   les gros raccourcis EN HAUT du panneau
 │  ░ ▁▁▁▁▁│▁▁▁▁▁▁▁▁▁▁▁▁▁ ░ │   + la règle crantée EN DESSOUS,
 │  ░░░░░░░░░░░░░░░░░░░░░░░  │   chiffres énormes, cible ≥ 90 pt
 │ ⟮→        Finish        ⟯ │ ← ④ le slider COLLÉ AU BAS (~34 pt du bord)
 └───────────────────────────┘
```

1. **Deux ronds de tailles DIFFÉRENTES** — je challenge ta maquette ici :
   deux cercles identiques empilés, c'est ce qui rend l'écran illisible. Le
   chrono est le héros (il est l'exercice), la vitesse est un afficheur.
2. **La molette prend TOUT LE BAS** (ta demande) : verre fumé, ouverte au
   tap du cadran vitesse. Ouverte, elle COUVRE le slider — on ne finit pas
   une session pendant qu'on règle sa vitesse : le conflit se résout tout
   seul.
3. **Le slider descend** à ~34 pt du bord (au lieu de 78) — sous la molette
   fermée, au ras du bas comme ta maquette.
4. **PLUS AUCUN CARRÉ OPAQUE** : les pastilles n'ont plus de plaque noire.
   Deux chemins, à trancher (§V2.5-Q1).

## V2.4 — LA FÊTE DU STOP (ce qui manquait le plus)

Au tap stop, dans cet ordre :

1. **LA DALLE « SET 1 END »** avec **le mini-récap ET la pièce** — c'est ta
   demande littérale, et `NotifJauge` la porte déjà (la pièce de 92 pt qui
   mord le bord, `NotifCard.swift:140-165`) : `sousTitre` = « SET 1 END »,
   la ligne de récap = **« 0:45 · 17 km/h »**, le gain = +20 lu du serveur.
2. **LA POP-UP FLAMMES** à +0,4 s (robe `.fire`, ton sticker flamme noire)
   qui encourage, avec le crescendo qui monte avec les sets.
3. **LA BASCULE DE COULEUR** dans le même souffle : la braise s'effondre en
   cendre (§V2.2) et **le fond de la page monte d'un palier de rouge**.

Les trois partent ensemble : c'est UN événement, pas trois notifications.

## V2.4 bis — LA RECETTE, MESURÉE AU BANC (31-08, `tools/tapis/essai_braise.py`)

Le banc re-joue `glowShade`/`eclipseWorld` (`LiquidLens.metal:488-628`) **à la
constante près** en numpy : les nombres sortent du même calcul que le
téléphone, sans builder. Planches : `tools/tapis/vignettes/tapis-recettes.png`
et `tapis-paliers.png`.

**① LA CAUSE EXACTE DU GRIS — une ligne, `LiquidLens.metal:604` :**
```metal
float niv = max(max(max(c.r, c.g), c.b), 0.55);   // ← LE PLANCHER
c = mix(c, float3(1.00, 0.97, 0.93) * niv, mTip);
```
Ce plancher **invente un blanc à 0,55 de luminance** là où le lit local est
sombre. Dans le monde muscu il est inoffensif (le lit y est déjà ≥ 0,55 :
traînée d'encre + spotlight + 4 voix) et la langue lit comme une pointe
chaude. Dans mon carré local vide, **cette langue blanche EST le pixel le
plus clair de l'image** — donc elle EST « l'aura » que j'ai mesurée.
Prédiction du modèle : 101/98/94. Ma mesure : **101/94/91**. Le même pixel.

**② AGGRAVANT — mon masque coupait la braise et gardait le gris.** Stops
0,44/0,86 sur `endRadius = côté/2` : au pic de la nappe (r = R) il ne laissait
passer que **33 %**, et il supprimait tout le lit large — les deux seules
zones où le shader est à G/R 0,26-0,37.

**③ LA RECETTE (mesurée sur l'anneau, encre masquée) :**

| composition | R | G | B | G/R | B/R | |
|---|---|---|---|---|---|---|
| **A — le J0 rejeté** | 0,264 | 0,151 | 0,097 | **0,574** | **0,366** | 🔴 |
| B — sans les pointes (`:601-605`) | 0,263 | 0,115 | 0,043 | 0,438 | 0,164 | 🔴 |
| C — + la voix blanche #2 éteinte (`wgt[2]`) | 0,248 | 0,087 | 0,010 | 0,351 | 0,039 | ✅ |
| **D — + le masque 0,72/1,00 = LA RECETTE** | 0,772 | 0,259 | 0,020 | **0,336** | **0,026** | ✅ |

**④ LES 7 PALIERS — DEUX leviers, et il en faut deux.** `heat` seul ne
déplace la teinte que de 0,07 sur toute la course (mesuré : G/R 0,317 →
0,387) : **ça ne se lit pas**. On ajoute `ig`, qui porte la flamme (la nappe
est `×ig`, `:571`) — et `ig` est libre parce que la voix blanche est éteinte
(sinon elle naîtrait à `ig > 0,55`, `:152`, et regriserait tout).
**`ig` progresse en GÉOMÉTRIE, pas en addition** : l'œil lit des rapports.

| palier | `ig` | biais `heat` | G/R | B/R | saut de luminance |
|---|---|---|---|---|---|
| P0 (0 set) | 0,235 | −0,34 | 0,248 | 0,018 | — |
| P1 | 0,302 | −0,22 | 0,281 | 0,035 | ×1,36 |
| P2 | 0,388 | −0,11 | 0,318 | 0,031 | ×1,41 |
| P3 | 0,499 | +0,01 | 0,363 | 0,030 | ×1,46 |
| P4 | 0,641 | +0,14 | 0,392 | 0,031 | ×1,44 |
| P5 | 0,824 | +0,30 | 0,380 | 0,031 | ×1,36 |
| P6 (≥ 6 sets) | 1,000 | +0,50 | 0,387 | 0,033 | ×1,17 |

**Les 7 paliers sont dans la loi** (B/R ≤ 0,035 partout) et la progression est
**monotone et lisible**. La teinte sature vers G/R 0,39 en haut de rampe
(`vChaud` plafonne à 0,44) : c'est la luminance qui porte la fin — un feu qui
grossit plus qu'il ne change de couleur.

**⑤ LA CENDRE N'EXISTE PAS DANS CETTE MAISON — et c'est une bonne nouvelle.**
Le banc le prouve : `heat → 0` ne rend pas du gris, il rend **`vRacine`
(1,00 · 0,13 · 0,005)** — le rouge le plus PROFOND de la rampe. Chercher une
cendre grise, c'était re-fabriquer exactement le défaut que tu as rejeté.
**L'entre-sets, c'est le feu qui RENTRE DANS SES RACINES** : `ig` du palier
N−2 × 0,62 et `heat` −0,42.
Mesuré depuis P4 : **G/R 0,258 · B/R 0,022**, et surtout **3,93× moins
lumineux** que le set. C'est ce rapport-là qui fait qu'on lit l'état à un
mètre, pas une différence de teinte.

## V2.4 ter — LA V2 CONSTRUITE ET MESURÉE (31-08, au banc `-tapisLab`)

Ce qui est en place (non commité — le verdict d'abord) :

- **`braiseGlow`**, un point d'entrée NEUF dans `LiquidLens.metal` : le même
  feu, sans ses deux registres blancs. Le parcours muscu n'est pas touché —
  `eclipseWorld` reçoit un paramètre `voix2` **à défaut 1,05**, donc ses deux
  appels existants sont inchangés au caractère près.
- **La pastille = la couche de feu SEULE.** Plus de `Color.black`, plus de
  `layerEffect`, plus de `compositingGroup` : le carré noir faisait la claque,
  et le verre ajoutait ses reflets blancs (le second agent de grisaille). Une
  passe au lieu de deux.
- **La hiérarchie** : chrono 350 pt (héros), cadran vitesse 215 pt à 62 % de
  braise (afficheur). **La molette** prend tout le bas (raccourcis 5·7·10·14·17
  en cibles de 62 pt, puis la règle fine `FluidPicker` 0-20 pas 0,5, puis
  « Done ») ; ouverte, elle couvre le slider. **Le slider** descend à 34 pt du
  bord. **La fête** : dalle « SET n END · 0:03 · 0 KM/H » + pièce à +0 s,
  pop-up flammes à +0,4 s, dalle retirée à +3,2 s.
- **La fête vit DANS LE MODÈLE**, pas dans le geste : le banc `-tapisAuto`
  (le simulateur n'a pas de doigt) doit voir EXACTEMENT ce que le doigt
  déclenche — deux chemins qui divergent, c'est un banc qui ment.

**Les mesures, machine calme (`charge.sh` ✅ 0,8) :**

| régime | cadence | pire trou | |
|---|---|---|---|
| SET qui court | **60,0 img/s** | 17 ms | ✅ |
| molette ouverte (verre fumé plein bas) | **60,0 img/s** | 17 ms | ✅ |
| **la FÊTE (dalle + pop-up qui naissent)** | **40-43 img/s** | **60-76 ms** | 🔴 |

**🔴 DETTE MESURÉE, À DIRE PLUTÔT QU'À CACHER** : la naissance de la pop-up
flammes coûte deux trous de 60-76 ms. C'est le piège nommé de la maison —
« une vue lourde qui naît PENDANT un film est un MONTAGE, pas un fichier ».
Ça ne se voit pas au repos (les deux autres régimes tiennent 60), ça se voit
à l'instant précis du tap stop. Pistes, dans l'ordre, à mesurer et non à
supposer : pré-monter la pop-up hors écran au DÉBUT du set (elle a 30 s pour
naître tranquillement), ou alléger sa scène pour le tapis. **Et le vrai juge
reste le téléphone** : le simulateur est aveugle aux gels Metal.

**La couleur, RE-MESURÉE sur la capture livrée** (flancs de la couronne, sans
l'encre) : **G/R 0,322 et 0,361 · B/R 0,027 et 0,024** — la prédiction du banc
était 0,336 / 0,026. Le shader du téléphone et le port numpy disent la même
chose.

⚠️ **Loi de mesure re-payée** : ma première sonde de capture visait des
DEMI-ÉCRANS et rendait « G/R 0,515 · B/R 0,259 — ECART ». Elle mesurait les
bords antialiasés de l'encre blanche sur l'orange, qui passent le filtre
`R > G` en portant tout le bleu du blanc. On vise les FLANCS, jamais une
moitié d'écran.

---

# V5 — LE BAS DE L'ÉCRAN **EST** LA VITESSE (01-09)

> *« La molette s'ouvre pas et j'arrive pas à utiliser la molette. Et aussi
> quand je tourne sur les chiffres directe, ou trait — car quand on court on
> doit pouvoir toucher l'écran facilement en bas pour changer, surtout à
> grosse vitesse. »*

## V5.0 — SA DERNIÈRE PHRASE EST LA SPÉCIFICATION, ET ELLE TUE MA MOLETTE

*« Quand on court on doit pouvoir toucher l'écran facilement en bas pour
changer, surtout à grosse vitesse. »*

Ça ne demande pas de réparer l'ouverture du cadran. **Ça dit qu'il ne devrait
pas y avoir de cadran à ouvrir.** À 17 km/h, on ne vise pas une pastille de
168 pt pour déplier un panneau, puis on cherche une prise, puis on referme. On
tape le bas de l'écran et ça change.

Chaque étape que j'ai ajoutée — ouvrir, viser, fermer — est une étape de plus
à faire en courant. **Le meilleur correctif à « la molette ne s'ouvre pas »,
c'est qu'il n'y ait plus rien à ouvrir.**

## V5.1 bis — ⚠️ LA CAUSE, TROUVÉE (01-09) : `.offset` déplace les PIXELS, pas la ZONE TACTILE

Sa localisation — *« au-delà de la pastille »* — a suffi. La zone de prise
était construite ainsi :

```swift
VoileCadran(...)
    .offset(y: haut)            // ← déplace le DESSIN de 190 pt vers le bas
    .contentShape(Rectangle())  // ← définit la zone sur le cadre de LAYOUT,
    .highPriorityGesture(rotation)   //  resté en HAUT
```

`.offset` ne change pas le cadre de layout. Le `.contentShape` posé APRÈS lui
décrit donc un rectangle **à la place d'origine** : la bande prenante est
**190 pt trop haute**.

| élément | sa position | zone prenante (0 → 451) |
|---|---|---|
| le centre de la pastille | 418 pt | ✅ dedans |
| les graduations | 558 pt | ❌ dehors |
| **les chiffres** | 465 → 602 pt | ❌ **tous dehors** |

**Elle ne pouvait toucher QUE le vide au-dessus de la pastille.** Et comme le
`Color.clear` de fermeture est juste derrière, un doigt posé sur les chiffres
ne tombait pas dans le vide : **il fermait la molette** — d'où « la molette
s'ouvre pas », qui était en réalité « la molette se referme à chaque
toucher ».

C'est la loi maison déjà écrite, que je n'ai pas appliquée : **« les pixels et
le hit-test sont DEUX choses »**. Et c'est aussi la démonstration de §V4.0 :
mon banc appelait la fonction directement, donc il ne pouvait pas voir un
défaut qui vit entièrement dans la couche du toucher.

## V5.1 — POURQUOI ELLE NE S'OUVRE PAS : ce que je croyais ne pas savoir

J'ai vérifié la piste la plus crédible — que le slider « Finish » recouvre la
zone de tap. **C'est FAUX** : sa poudre est un `overlay` de 130 pt
explicitement `allowsHitTesting(false)` et **sans emprise de layout** (le
commentaire du fichier le dit : « un hôte plus haut posé en frère pousserait
tout le slider vers le bas »). Le slider n'occupe que 62 pt tout en bas.

Les deux zones de tap (chrono et vitesse) sont construites **exactement
pareil** — même `Color.clear`, même `contentShape(Circle())`, même
`highPriorityGesture` — et ne diffèrent que par leur position. Je ne trouve
pas la cause par la lecture, et **je refuse d'en inventer une sixième**.

**Ce que ça implique, et c'est important :** si le tap ne parvient pas à la
zone basse, une commande posée au même endroit échouerait pareil. **Donc la
sonde reste obligatoire** — mais elle devient une vérification (« le bas de
l'écran reçoit-il les touchers ? »), pas une enquête.

Une question à toi vaudrait toute la sonde : **le tap sur la pastille du HAUT
(stop / start du set) fonctionne-t-il ?** Si oui, les touchers arrivent et le
problème est local au bas. Si non, rien n'arrive à la scène et c'est un
niveau au-dessus.

## V5.2 — LE DESIGN V5 : plus rien à ouvrir, plus rien à fermer

```
 ┌───────────────────────────┐
 │      12 MIN · 4 SETS      │
 │        Tap to stop        │
 │        ╭─────────╮        │
 │        │  SET 5  │        │  ← le chrono, inchangé
 │        │  0:29   │        │
 │        │    ⏹    │        │
 │        ╰─────────╯        │
 │                           │
 │          ╭─────╮          │
 │          │ 17  │          │  ← la VALEUR, en grand
 │          │km/h │          │
 │          ╰─────╯          │
 │    15  16  ·  18  19      │  ← l'arc, EN VEILLEUSE en permanence,
 │  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌   │    qui S'ALLUME dès qu'un doigt touche
 │                           │
 │   ⟵  toute cette bande    │  ← LA COMMANDE : un glissement
 │      change la vitesse    │    HORIZONTAL n'importe où ici.
 │                           │    Rien à viser, rien à ouvrir.
 │  ⟮→      Finish      ⟯    │  ← sa propre bande, en bas
 └───────────────────────────┘
```

1. **Aucune ouverture, aucune fermeture.** La commande est là, tout le temps.
   Zéro état, donc zéro état qui puisse se coincer.
2. **La cible, c'est la moitié basse de l'écran** — des centaines de points de
   large, au lieu d'une pastille de 168. C'est ça, « toucher facilement en
   bas ».
3. **Le geste est un TRAIT horizontal** (tu l'acceptes : « ou trait »), à la
   recette de la molette de la maison qui marche : **position absolue depuis
   le point de pose**, ~62 pt par cran, élastique aux bornes. Elle ne peut pas
   dériver, elle n'a pas de centre, elle ne se perd pas si le doigt s'arrête.
4. **L'arc de chiffres reste ton design** — visible en permanence, en
   veilleuse, il **s'allume** sous le doigt (et la fumée avec). En courant, tu
   VOIS ta vitesse et ses voisines sans rien toucher.
5. **Le halo blanc** reste : il confirme au lâcher.

## V5.3 — CE QUE ÇA SUPPRIME (donc ce qui ne peut plus casser)

| supprimé | pourquoi il faisait mal |
|---|---|
| le tap d'ouverture | c'est **exactement** ce qui ne marche pas |
| le panneau qui monte / descend | une transition de plus à rater |
| la fermeture automatique (1,10 s) | elle se refermait sous ton doigt |
| le chien de garde (0,6 s) | il tuait le geste dès que tu hésitais |
| l'entrée angulaire | centre, déroulé ±π, dérive, instabilité au milieu |
| l'état `moletteOuverte` | un état de moins = un blocage de moins |

**Six mécanismes retirés d'un coup.** Le cadran ne devient pas plus simple par
goût : il devient plus simple parce que **chacune de ces six pièces était un
endroit où ça pouvait se coincer**, et qu'aucune ne servait ton usage réel.

## V5.4 — LE SEUL ARBITRAGE QUI RESTE : la vitesse contre « Finish »

Les deux sont des glissements horizontaux dans le bas de l'écran. Ma reco :
**deux bandes franches et séparées** — le slider « Finish » garde sa hauteur
propre tout en bas (62 pt + son air), la bande de vitesse s'arrête
au-dessus, avec un vide visible entre les deux. Aucun partage de doigt, aucune
règle subtile à deviner : deux zones, deux objets.

## V5.5 — CE QUE JE TE DEMANDE (et je ne code pas avant)

1. **Le tap sur la pastille du HAUT (stop/start du set) marche-t-il ?**
   C'est la question qui vaut le plus : elle dit si les touchers arrivent.
2. **Le design V5 te va** — plus de molette à ouvrir, le bas de l'écran EST la
   vitesse en permanence ?
3. **L'arc de chiffres en veilleuse permanente** (ma reco : on voit sa vitesse
   et ses voisines en courant) — ou seulement pendant qu'on touche ?

---

# V4 — POURQUOI LA MOLETTE NE MARCHE TOUJOURS PAS (01-09)

> *« Non, plus rien ne marche, tu vas trop vite ! Réanalyse et fais un plan,
> ne code pas. »*

Elle a raison, et sur les deux points. Ce qui suit commence par MON erreur de
méthode, parce que c'est elle qui explique pourquoi je lui ai dit cinq fois
« c'est prouvé » sur un objet qui ne marche pas.

## V4.0 — MON ERREUR DE MÉTHODE : un banc qui prouvait la MOITIÉ QUI N'ÉTAIT PAS EN DOUTE

Mon « doigt du banc » (`-tapisTourne`) **appelle `appliquer(point:cy:temps:)`
directement**. Il ne touche pas l'écran : il court-circuite tout le système
de SwiftUI — le hit-testing, la zone de prise, l'arbitrage entre gestes, le
repère de coordonnées d'un vrai toucher, la concurrence avec les taps de la
scène.

Donc quand j'annonçais « le banc atteint 20,0 km/h, même 46 pt au-delà des
chiffres », **je prouvais que ma trigonométrie était juste**. Ça ne l'a
jamais été en doute. **Ce qui est en doute, c'est qu'un toucher réel arrive
jusqu'au geste** — et de ça, mon banc ne dit RIEN.

C'est la faute exacte que la maison nomme : *un juge qui affirme ne remplace
pas une sonde qui mesure* — sauf qu'ici la sonde mesurait à côté. Une sonde
qui mesure la mauvaise chose est pire qu'un juge : elle a l'autorité d'un
chiffre.

## V4.1 — CE QUE JE SAIS VRAIMENT, ET CE QUE JE NE SAIS PAS

| | statut |
|---|---|
| La trigonométrie angle → valeur | ✅ **prouvée** (banc : 0 → 20, et hors anneau) |
| La cadence en régime établi | ✅ **mesurée** : 60,0 img/s, trou 17 ms |
| Le coût des chiffres du Canvas | ✅ **ablation faite** : nul (57/56/60/60 avec, 59/55/60/60 sans) |
| Les couleurs de braise | ✅ **mesurées** : G/R 0,32-0,36 · B/R 0,025 |
| **Qu'un toucher réel atteigne le geste** | ❌ **JAMAIS VÉRIFIÉ** |
| **Ce que voit l'app sous SON doigt** | ❌ **AUCUNE observation** |
| Le comportement quand le doigt s'arrête, hésite, sort de l'écran | ❌ jamais éprouvé |

**Trois de mes cinq « correctifs » (le lissage, le découpage, l'ablation) ont
donc traité une fluidité qui, en régime, était déjà à 60 img/s.** Ils ne sont
pas faux — le découpage était une vraie dette — mais aucun ne pouvait
réparer « ça ne marche pas ».

## V4.2 — LA CAUSE PROBABLE : J'AI PRIS L'ENTRÉE DU CARROUSEL, PAS CELLE DE LA MOLETTE

Voilà le fait que j'aurais dû voir au premier jour. **La molette de la maison
qui MARCHE — celle de la page exos, celle dont tu aimes le rendu — n'est PAS
pilotée par un angle. Elle est pilotée par une TRANSLATION HORIZONTALE**
(`ExercisesView.swift:915-940`) :

```swift
var p = etat.base - Double(v.translation.width - etat.morte) / 62.0
```

**62 points de glisse par cran, et la position est ABSOLUE** : `base` (la
valeur au moment où le doigt s'est posé) plus le déplacement total depuis ce
point. Elle ressemble à un cadran, elle se pilote comme un curseur.

Moi, j'ai copié l'entrée de `MoisIpod` — qui est un **carrousel de mois**,
pas un sélecteur de valeur — et qui accumule des deltas d'angle autour d'un
centre.

## V4.3 — LES CINQ FRAGILITÉS DE L'ENTRÉE ANGULAIRE (et la translation n'en a AUCUNE)

1. **Elle a besoin d'un CENTRE, dans le bon repère.** Je me suis trompé de
   190 pt une fois déjà, et rien ne le montrait à l'écran.
2. **Elle est INCRÉMENTALE** : elle additionne des deltas. Tout événement
   perdu, dupliqué, ou toute remise à zéro (le chien de garde !) fait DÉRIVER
   la valeur. Une translation, elle, est absolue : elle ne peut pas dériver.
3. **Elle a besoin du déroulé ±π**, et se trompe d'un tour entier si le doigt
   passe du mauvais côté.
4. **Elle est INSTABLE près du centre** : à 20 pt du centre, un millimètre de
   doigt fait 30° — soit deux crans. Or le centre du cadran, c'est là où
   s'affiche la valeur : la zone la plus naturelle à toucher est la pire.
5. **Elle exige un ARC.** Un pouce, surtout en courant, fait un TRAIT.

Et une sixième, propre à mon code : **le chien de garde de 0,6 s remet
`angleDoigt` à nil**. Si le doigt s'arrête six dixièmes de seconde — hésiter,
lire la valeur —, le geste est considéré comme mort, la molette se replie et
se ferme 1,1 s plus tard. **Trois mécanismes temporels (chien de garde,
fermeture auto, ressort de recalage) se battent au-dessus d'un geste
incrémental.** C'est très probablement ça, « plus rien ne marche ».

## V4.4 — LE PLAN V4 (rien de tout ça n'est codé)

**A. LA SONDE D'ABORD — je ne coderai plus une ligne à l'aveugle.**
Un drapeau `-tapisSonde` qui affiche en haut de l'écran, en direct : le
nombre de touchers reçus par le geste, la position du doigt, l'état
(posé/relâché), la valeur continue, la valeur crantée, et chaque déclenchement
du chien de garde ou de la fermeture. **Tu ouvres le banc, tu poses le doigt,
et on VOIT si le geste reçoit quoi que ce soit.** C'est la seule façon de
savoir si le problème est « le toucher n'arrive pas » ou « le toucher arrive
mal ». Tant que ce n'est pas su, tout le reste est de la devinette.

**B. L'ENTRÉE DEVIENT LINÉAIRE — le visuel ne change PAS.**
Le cadran garde exactement ce que tu as validé : le cercle, l'arc de chiffres
en dégradé de blanc, la valeur en grand au centre, la fumée, le halo. **Seule
l'entrée change** : glisser horizontalement (n'importe où dans la zone basse)
fait tourner l'anneau, à la recette de la maison — position absolue depuis le
point de pose, ~62 pt par cran, élastique aux bornes. Plus de centre, plus de
déroulé, plus d'accumulation, plus d'instabilité au milieu. Et le geste
devient celui que fait un pouce en courant : un trait.

**C. ON SUPPRIME LES TROIS HORLOGES QUI SE BATTENT.**
Sans accumulation, le chien de garde n'a plus de rôle (une translation absolue
ne peut pas rester « collée ») : il disparaît. La fermeture automatique
devient explicite — soit elle reste, mais **seulement après un vrai lâcher
suivi d'un silence**, soit on la retire et on ferme en tapant à côté. À
trancher (§V4.5).

**D. ON RE-MESURE, MAIS SUR LA BONNE CHOSE.** Le verdict n'est plus « 60
img/s » (déjà acquis) : c'est **« le doigt de Kathryn fait-il bouger la
valeur, du premier au dernier km/h, sans que rien ne se referme »**. Ça se
juge à l'écran, avec la sonde ouverte, et par toi.

## V4.5 — CE QUE JE TE DEMANDE (et je ne code pas avant)

1. **Le geste** : glisser **horizontalement** (ma reco, c'est ce que fait la
   molette de la maison qui marche) — ou tu tiens vraiment au mouvement
   circulaire, et j'assume alors de le fiabiliser autrement ?
2. **La fermeture automatique** : on la garde (après un lâcher franc), ou on
   la supprime et on ferme uniquement en tapant à côté ? Ma reco : **la
   supprimer** — c'est elle qui t'a le plus gênée, et un tap à côté est sans
   ambiguïté.
3. **Où ça coince exactement**, si tu peux le dire en un mot : la molette ne
   **s'ouvre pas** ? elle s'ouvre mais **ne bouge pas** ? elle bouge et **se
   referme** toute seule ? Chacune de ces trois réponses désigne une cause
   différente, et m'éviterait un tour de sonde.

---

# V3 — LA MOLETTE ROTATIVE, LE STOP PERMANENT, LA DURÉE DE SÉANCE (31-08)

**Ses trois verdicts** : *« la molette est pas assez claire et grosse et blur !
je cours là, c'est trop petit trop détaillé. Je veux un SIMPLE CERCLE BLUR
LIQUID GLASS où je peux TOURNER, c'est en dégradé de blanc et haptique. Ça
passe DANS LE CERCLE DES KM/H ! »* — puis : *« on doit voir l'icône stop dans
le chrono quand c'est en cours »* et *« la durée globale du set en haut
quelque part »*.

## V3.1 — CE QUE J'AI RATÉ, ET POURQUOI (l'analyse, pas l'excuse)

J'ai livré **quatre organes empilés** (titre, 5 raccourcis ronds, réglette
linéaire, bouton Done) sur ~338 pt de haut. « Trop détaillé » porte sur la
DENSITÉ, pas sur le verre : le fond `.regular.tint(noir 0,45)` est déjà la
bonne matière et il tient 60,0 img/s. Ce que j'ai fait, c'est **un formulaire
posé devant quelqu'un qui court**. Elle demande **un objet**, pas un panneau.

Et son instinct « ça passe DANS le cercle des km/h » est **techniquement le bon
appel**, pour une raison qu'elle ne peut pas connaître : *un verre posé sur du
noir absolu rend un TROU ou une bille de chrome* (mesuré, `HomeNuit:537-544` :
p95 = 23). Il faut le NOURRIR. Sur cette page, la pastille de braise EST le
« contenu doux » que `.clear` a le droit de recouvrir — c'est le seul écran de
l'app où le verre mange sans qu'on paie une passe de plus.

## V3.2 — L'ÉTAT DES LIEUX : deux molettes, aucune ne fait ce qu'elle veut

| | `MoisIpod` (CalLab) | `ArcDial` (ExercisesView) |
|---|---|---|
| entrée | **angulaire VRAIE** — `atan2` autour du centre (`:3729-3731`) | linéaire — `translation.width / 62 pt` |
| rendu | verre + vidéo + 6 calques, ~40 `@State` sur l'hôte | **UN `Canvas`** `Animatable`, 72 traits |
| haptique | générateur `.rigid` **tenu et préparé**, intensité 0,75 + ω·0,06, **plancher 40 ms** | `.sensoryFeedback(.selection)` |
| butée | **PATINE** (`×0,25`) puis toque UNE fois | élastique ×0,30 |

**Ce qu'elle demande = l'ENTRÉE de MoisIpod + le RENDU d'ArcDial.** Aucun des
deux ne le fait seul, et aucun n'est extractible tel quel (`MoisIpod` est une
PAGE aux `@State` soudés ; `ArcDial` est `private` et dépend d'un observable de
93 lignes qui porte le scroll, le clavier et la lune).

**Ce qui est VRAIMENT réutilisable** : les recettes numériques (le cran, le
lissage, la roue libre, l'haptique) et le pattern `Canvas + Animatable`. Le
reste se réécrit — mais avec des valeurs PAYÉES, pas inventées.

**Et « gros », ça se chiffre** : la bande du doigt de MoisIpod fait **72 pt**
de large — contre les **13 pt** de pas de ma réglette. C'est ça, l'écart entre
« je cours » et « je suis assise ».

## V3.3 — LE CADRAN PROPOSÉ (un seul organe)

```
        ╭─────────────────────╮
        │      6   7   8      │  ← les valeurs voisines, en arc,
        │    5  ╭───────╮ 10  │    dégradé de blanc, celle du centre
        │       │  7,0  │     │    à pleine encre, les autres qui
        │       │ km/h  │     │    s'éteignent (0,85 → 0,16)
        │       ╰───────╯     │
        │   ← on tourne ici → │  ← LA BANDE DU DOIGT : ~72 pt de large,
        ╰─────────────────────╯    tout autour. On n'a pas à viser.
```

- **Le disque de verre**, D ≈ 150-160 pt, **à taille CONSTANTE** : un verre
  redimensionné frame à frame retombe en blur plat **et n'en revient pas**
  (mesuré 60 → 14 img/s). L'ouverture se joue en translation du panneau (déjà
  en place, légal, mesuré 60,0) ou par un masque — **jamais un `scaleEffect`**.
- **Il se nourrit de la braise déjà là** : le disque vitesse a son anneau chaud
  à r ≈ 77-108 pt ; un verre de D ≈ 152 tombe pile dessus. Pas de troisième
  shader, pas de lueur en plus (un `colorEffect` permanent coûte 60 → 16).
- **L'encre vit AU-DESSUS du verre**, jamais dedans — c'est écrit noir sur
  blanc dans le code sous le nom de « la loi de la molette » : dedans, les
  chiffres sortent givrés et doublés de fantômes.
- **UN SEUL `Canvas`** porte les graduations + les valeurs + le cran d'index,
  `Animatable` sur (angle, engagement). Jamais N vues : « 72 calques hors
  écran par image, le vrai prix de la molette pas fluide ». Et jamais un
  `.shadow` par graduation.
- **Le dégradé de blanc se RESSERRE quand le corps grandit** : pour « 7,0 » en
  52-64 pt, `1,00 → 0,78`. Le dégradé de titre de la maison finit à 0,25 —
  mesuré illisible à ce corps (facteur 3,7 dans le sens de la lecture).
- **L'haptique** : générateur `.rigid` **tenu et préparé à la saisie** (la
  latence tue le crantage), intensité 0,75 poussée par la vitesse, **plancher
  40 ms — on saute des CLICS, jamais des crans** ; à la butée, la matière
  **patine à 25 %** et toque une seule fois.
- **Le filet obligatoire** : MoisIpod n'a **aucun** chien de garde. Ici il en
  faut un (0,6 s, le pattern d'ExercisesView) : ce cadran monte **par-dessus
  une séance qui tourne**, et un `DragGesture` tué en vol ne reçoit jamais son
  `onEnded` — le cadran resterait accroché au doigt d'un fantôme.

**⚠️ LE PIÈGE DE CADENCE, précis :** `seance.vitesse` est lu par l'encre du
cadran, qui vit **dans le même sous-arbre que les deux shaders de feu**. Un
cadran qui écrit la vitesse en continu (~60×/s) ré-invaliderait la braise à
chaque image. La loi de la maison est écrite : **on lit le CRAN (un `Int` qui
change une poignée de fois), jamais la position continue**. Donc : la vitesse
s'écrit **au cran**, ou l'encre sort du sous-arbre vivant.

## V3.4 — LE STOP PERMANENT (et ce que ça SIMPLIFIE)

*« On doit voir l'icône stop dans le chrono quand c'est en cours. »*

**Ça rend l'alternance inutile — et c'est une bonne nouvelle.** L'alternance
⏹ toutes les 3 s était un TUTORIEL : elle existait pour faire comprendre que
la pastille se tape. Si le stop est **là en permanence**, il n'y a plus rien à
apprendre. Garder les deux, ce serait un glyphe qui clignote à côté d'un
glyphe fixe : du bruit.

**Proposé** : sous le chrono, un ⏹ **petit et permanent** en blanc dégradé
(l'encre de la maison), pendant tout le set ; au repos il devient ▶, plus gros
(c'est lui l'action du moment). L'alternance disparaît. La phrase « Tap to
stop » reste : elle dit le geste, le glyphe dit l'état.

## V3.5 — LA DURÉE EN HAUT

*« La durée globale du set en haut quelque part. »*

⚠️ **Ambigu, et je ne veux pas deviner** : le chrono de la pastille DIT déjà la
durée du set en cours. Deux lectures :
- **(a) la durée de la SÉANCE** — le temps total depuis le début, tous sets et
  repos confondus. **Ma lecture** : c'est ce qui manque à l'écran, et c'est ce
  que ta phrase « globale » désigne.
- **(b) le cumul des sets seuls** — le temps sous effort, repos exclus (la
  mesure qui compte en HIIT).

**Proposé pour (a)** : en haut, au-dessus de la phrase, en petites capitales
espacées, discret — `24 MIN · 5 SETS`. Et la maison a déjà la recette : le
player affiche son chrono de séance **en MINUTES avec une horloge qui bat une
fois par minute** (« un player n'est pas un chronomètre »). Ça ne coûte rien,
et ça ne re-dessine pas la page 60 fois par seconde pour afficher un chiffre
qui bouge toutes les 60 s.

## V3.6 — CE QUE JE TE DEMANDE AVANT DE CODER

1. **Le cran** — 1 km/h par cran ? À 40° le cran (la valeur iPod), 0→20
   = 2,2 tours de doigt : trop pour quelqu'un qui court. **Ma reco : 20° par
   cran** (1,1 tour sur toute la plage), et **des demis (0,5 km/h) seulement
   si tu les veux** — sinon on reste en entiers, plus francs au doigt.
2. **La durée en haut** — (a) la séance entière, ou (b) le temps sous effort ?
3. **Le cadran remplace-t-il le panneau ?** Ma reco : le panneau blur qui monte
   du bas RESTE (il est mesuré à 60 img/s et il fait le fond), mais il ne
   contient plus **qu'une chose** : le cadran. Plus de raccourcis, plus de
   réglette, plus de « Done » — on ferme en tapant à côté.
4. **Le stop permanent tue-t-il l'alternance ?** Ma reco : oui (§V3.4).

## V2.5 — CE QUE JE DOIS TE DEMANDER AVANT DE RECODER

**Q1 — Comment on tue la claque noire ?** (le choix technique, tes yeux
tranchent le rendu)
- **(a) UN SEUL MONDE plein écran** que les deux pastilles réfractent
  ensemble — exactement le parcours muscu, la vraie « même matière » : la
  couleur revient toute seule, plus aucun bord. Coût : une passe de verre
  plein écran (le muscu tient 60 img/s ainsi) + une variante du shader à
  deux centres. **Ma reco** — c'est la seule qui rend la matière que tu
  aimes déjà.
- **(b) Chaque pastille garde son carré**, mais on met une VRAIE nappe de
  braise dedans et on éteint le bord en fondu. Moins cher, mais deux
  mondes séparés : le risque de re-lire « deux calques ».

**Q2 — La molette, permanente ou au tap ?** Ta phrase (« qui prend tout le
bas ») peut se lire des deux façons : **(a)** toujours là, le bas de
l'écran EST la molette (on voit le réglage en permanence, mais elle mange
l'écran pendant l'effort) ; **(b)** au tap du cadran vitesse, elle monte et
couvre le bas (ma reco : l'écran reste calme quand tu cours).

**Q3 — La couleur de l'ENTRE-SETS.** ⚡ **TRANCHÉE PAR LA MESURE** (§V2.4
bis-⑤) : la cendre grise n'existe pas dans cette maison — le shader, poussé
vers le froid, rend le rouge le plus PROFOND, pas du gris. L'entre-sets est
donc **le feu qui rentre dans ses racines** : même braise, 3,93× plus
sombre. Il reste à toi de dire si ce contraste te suffit à l'écran, ou s'il
faut aller plus loin (couper le feu presque entièrement).

**Q4 — Le palier de rouge, sur QUOI ?** Le fond de la page seul (le plan
d'origine) — ou **le fond ET la pastille** ensemble (ma reco : à 8 sets,
tout l'écran est chaud, c'est plus fort) ?

**Q5 — La méthode.** Je propose de **cuire les couleurs et les deux états
dans un banc Python d'abord** (l'école `essai_fond.py` de la card STOP :
composer le rendu exact, sans builder) et de te montrer **une planche
d'images — SET / ENTRE-SETS / les 6 paliers de rouge — AVANT de toucher au
Swift**. Ça t'évite de rejuger des builds à l'œil, et moi d'inventer une
matière de plus.

---

## 0. CE QUE JE CHALLENGE (avant l'anatomie)

1. **⚡ TRANCHÉ 31-08 (ok Kathryn) — deux « stop » à l'écran = confusion.**
   En mode tapis, la dalle masque son stop (`stopVisible: false`, le
   paramètre existe — `WorkoutPill.swift:154`) ; la SEULE fin de session
   sur cette page est le slider du bas. Sur les autres pages (home, liste),
   la dalle garde son stop : on peut toujours clore de partout.
2. **Le slider de la maquette dit « FINISH SET » mais termine la SESSION.**
   Piège de libellé pur : le set se finit au TAP, la session au SLIDE. Le
   slider doit dire **« Finish »** / « End session » — jamais « set ».
3. **⚡ TRANCHÉ 31-08 (ok Kathryn) — à 17 km/h, le tap d'abord.** Le
   panneau vitesse = une rangée de GROS raccourcis (l'éventail 5·6·7·8·10
   de ta maquette — le pattern `restChoices`/`restRow` existe,
   `SetEntrySheet.swift:29, 247`) + la grosse molette pour l'ajustement
   fin. Un tap = 90 % des cas ; la molette = le réglage posé, entre deux
   sets.
4. **⚡ TRANCHÉ 31-08 (verdict Kathryn) : la POP-UP OUI — au tap stop.**
   Mon challenge initial (« aucune pop-up en courant ») visait le mauvais
   instant : au tap stop on ne court PLUS (entre-sets = repos). Sa demande :
   *« quand j'ai tapé sur stop : notification pour dire "enregistré" + une
   pop-up stylée avec des flammes et tout, pour encourager »*. Donc CHAQUE
   fin de set = la notif grosse pièce (l'enregistrement, §6.1) **ET la
   pop-up flammes** (l'encouragement, §6.2). Ce qui RESTE interdit : une
   pop-up PENDANT qu'un set court, et le panneau « Recommencer ? » de la
   muscu (sans objet sur tapis).
5. **⚡ TRANCHÉ 31-08 (OK Kathryn) : l'alternance stop/chrono joue sur les
   2 premiers sets de la séance, puis s'éteint** (le « Tap to stop » qui
   pulse reste, lui, en permanence). Le seuil « 2 » reste réglable au banc.
6. **⚡ TRANCHÉ 31-08 (OK Kathryn) : le chrono survit au monde réel du
   tapis.** App en arrière-plan (musique), écran qui veut s'éteindre : le
   chrono est une **fonction pure d'une date-ancre** (la discipline
   `LightDial`, `Woop/Figures/LightDial.swift:134-136` — zéro accumulation),
   et la séance tapis pose `isIdleTimerDisabled` (l'écran ne dort pas tant
   qu'un set court).
7. **Un set de 3 secondes vaut-il 20 pièces ?** Le serveur ne vérifie pas
   (`p_series` est déclaré, §5). App perso : pas d'anti-farm à construire,
   mais le plan le DIT au lieu de le laisser découvrir (§10.6 propose un
   plancher optionnel).

---

## 1. L'ÉTAT DES LIEUX, mesuré dans le code

| pièce | où | verdict |
|---|---|---|
| **L'écran des maquettes** | nulle part | `"Tap to stop"`, `"select km/h"` : zéro occurrence. À construire — mais chaque brique existe. |
| **La pastille « éclipse »** | la **lentille liquide** du parcours muscu : `ShaderLibrary.liquidLens` en `layerEffect` + halos `eclipseGlow` (`LiquidLensLab.swift:1062-1088, 1178-1179` ; `Woop/LiquidLens.metal:52-76`) ; vie de la pastille `nightLens` :866-988, **fonction pure du temps** ; encre (titre `SET n` + chrono `m:ss`) :1131-1210 | ✅ « le même design qu'actuellement » = ELLE. L'`EclipseCounter` (`CounterLab.swift:66-242`) est son ancêtre de banc — on ne le ressuscite pas. |
| **Le chrono du parcours réel** | `TimelineView(.animation 1/60)` racine + dates-ancres `@State` (`LiquidLensLab.swift:209, 109-145`) | ✅ la discipline à recopier (jamais d'accumulation). |
| **Le flux cardio actuel** | `cardioPage` = un ScrollView d'ÉDITION (`ExerciseDetailView.swift:1427-1446`) + « Enregistrer l'exercice » → `save()` (:2087-2109, :2603) | 🔴 le cardio n'a AUCUN player vivant : il enregistre a posteriori. C'est le trou que ce plan comble. |
| **Le modèle de données** | `CardioPhase` : `seconds`, `speed` km/h, `cycleIndex`, `order`, `kind` (`Models.swift:523-549`) ; `hiit-tapis` = `.intervals` (:236-240) | ✅ le réceptacle existe. ❌ pas d'`isDone` : une phase est toujours du PRÉVU. |
| **La paie** | `Workout.seriesPayantes` = Σ `completedSets` = `sets.filter(\.isDone)` (`Models.swift:344-362, 463`) — « LA ligne à changer si la règle bouge » (:357) | 🔴 les phases paient 0 : **une séance 100 % tapis ne déclenche RIEN** (gardes `series > 0` : `WoopApp.swift:492`, `SacreServeur.swift:326`). |
| **Le serveur** | `cloturer_seance(p_workout, p_series)` 🟢 mesuré (site, `serveur.ts:20`) ; **`p_series` est un entier déclaré par le client**, jamais recoupé | ✅ payer les sets tapis ne demande AUCUNE migration. `pieces_par_serie` = 20 (`reward_rules`), lu par l'app (`EconomieWoop.piecesParSerie`, défaut :105). |
| **La table `cardio_phases`** | poussée par `SupabaseSync.swift:113-116` (`CardioPhaseRow` :39-49) ; le site la dit ⚪ « à retravailler (29-08) » (`serveur.ts:15`) | ⚠️ litige doc/code À POSER. Personne ne la lit : re-modelable à coût quasi nul. Ce chantier EST le retravail. |
| **La notif « grosse pièce »** | `NotifJauge(sousTitre:libelle:gain:fraction:pose:naissance:)` — pièce **92 pt** qui mord le bord, tour 9 s (`NotifCard.swift:140-165`) | ✅ existe, robe `RobeSocle` noir peint. ❌ montée au banc `-notifLab` SEULEMENT (`NotifLab.swift:52`) — jamais branchée. |
| **L'annonce en séance (muscu)** | `PillGain` locale à la fiche, zIndex 30, `allowsHitTesting(false)` (`RestartSheet.swift:536-582` ; montage `ExerciseDetailView.swift:1130-1139`) ; montant **lu du serveur** (:2355) | le précédent du « local à la page, passif ». `FileAnnonces` (racine, zIndex 9) ne sert que la clôture. |
| **La molette** | `FluidPicker` (réglette crantée générique, verre fumé, haptique par cran — `SetEntrySheet.swift:476-592`) ; physique de référence `ArcDial` (`ExercisesView.swift:810-1016`) ; haptique de référence `MoisIpod` (`CalLab.swift:3721-4029`) | ✅ `FluidPicker(title:"SPEED", unit:"km/h", range:0...20, step:0.5)` compile aujourd'hui. À GROSSIR. ⚠️ bug « molette 30× » jamais réglé (mémoire) : ne pas hériter de la physique ArcDial sans re-mesurer. |
| **Le slider** | `SliderObsidienne` (`label`, `height:62`, `validate`, `onConfirm:` NOMMÉ — `SliderObsidienne.swift:28`) ; déjà posé en pied de scène par la muscu (`LiquidLensLab.swift:1252`, y = h−78) | ✅ tel quel. |
| **Le contexte d'arrivée** | la fiche en séance = slot `page` de `PageCard` (`ExerciseDetailView.swift:601-606`) ; bande du bas RÉSERVÉE au player : `bandeH` = 110 pt (`PageCard.swift:76-78, 233`) ; au drag du player la page devient un **snapshot mort** (:376-386) | les pastilles vivent DANS la page ; le chrono figé pendant la levée est un état documenté, pas un bug. |
| **Le fond** | la scène du cadran muscu : `Color.black` + `NightSpotlight` + `NightStars` (`LiquidLensLab.swift:1154-1176`) | le fond qu'on teinte. Précédent rouge par paliers : la LUNE DE SANG (uniform par paliers, « 0,55 s PAR PALIER EST UN PLANCHER », `LuneDeSang.swift:19-40`) ; loi anti-brun (mémoire) : **R = 1,00, on désature le VERT, B ≈ 0** (braise : G/R 0,30-0,45). |

---

## 2. LA MACHINE À ÉTATS — un set tapis, du tap au ledger

```
   galet lancé (autre session)
        │  arrivée des pastilles (0,8 s)
        ▼
  ┌──────────────┐   tap sur la pastille chrono   ┌──────────────┐
  │  SET n COURT │ ─────────────────────────────▶ │  ENTRE-SETS  │
  │ chrono m:ss  │   • CardioPhase écrite          │ chrono 0:00  │
  │ "Tap to stop"│     (seconds mesurés, speed,    │ icône ▶ play │
  │ blink + ⏹/⏱  │      cycleIndex=n, faite)       │"Tap to start"│
  │ fond palier n│   • notif grosse pièce          │ sous-texte   │
  └──────────────┘     "SET n COMPLETE · +20"      │ "rest m:ss"  │
        ▲              • POP-UP FLAMMES (§6.2,     └──────┬───────┘
        │                l'encouragement — tap            │ tap play
        │                pour fermer, on reste            │
        │                en entre-sets)                   │
        │              • fond → palier n+1                │
        │              (easeOut ≥ 0,55 s)                 │
        └──────────────────────────────────────────────────┘
                                                   set n+1 démarre

  slider « Finish » (bas de page) ──▶ clôture de séance
    (la chaîne actuelle, intouchée : push + cloturer_seance,
     story, pile d'annonces, trophée)
```

- **L'état vit dans UN `@Observable` : `SeanceTapis`** (`etat: .court/.repos`,
  `setIndex`, `setDebut: Date?`, `reposDebut: Date?`, `vitesse: Double`,
  `setsFaits`). Jamais des `@State` éparpillés sur la fiche (la page porte
  déjà vidéos et shaders — piège de la page ré-évaluée). L'Observation ne
  réveille que les vues qui LISENT.
- **Le premier set démarre à l'arrivée des pastilles** (les maquettes : le
  chrono court déjà). Les suivants au tap play.
- **Le repos n'est pas un décompte** (pas de durée cible en HIIT libre) :
  l'état entre-sets affiche le temps ÉCOULÉ depuis le stop, petit, sous la
  pastille — utile (« repos ou très vite »), passif. À trancher (§10.4).
- **La vitesse du set** = la valeur de la molette au moment du STOP (si elle
  change en plein set, v1 garde la dernière — une phase par set, §10.5).
- **La séance tapis pose `isIdleTimerDisabled = true`** à l'arrivée des
  pastilles, le rend à la clôture / à la sortie de page.

---

## 3. L'ÉCRAN — l'anatomie

Tout vit dans le **slot `page`** de `PageCard` : un mode `tapisPage` de la
fiche, monté quand `exercise.tracking == .intervals && active != nil &&
seanceTapis.enCours` — la `cardioPage` d'édition reste la page hors séance.
La page ne scrolle PAS (rien à scroller entre deux pastilles : zéro conflit
de geste vertical). Les cotes fines se prennent au banc ; l'architecture :

| zone (haut → bas) | quoi |
|---|---|
| y ≈ 90 | **la phrase** « Tap to stop » / « Tap to start » — Inter-SemiBold ~20, le dégradé blanc « très Apple » de la maison ; **pulse** lent (opacité 0,35 → 0,9, période ~2,6 s, dérivée de l'horloge — jamais un `repeatForever` d'état) |
| y ≈ 150 → 400 | **la pastille CHRONO** : la lentille actuelle, telle quelle (liquidLens + eclipseGlow + encre `SET n` / `m:ss` Inter-Light). Dedans, l'**alternance** : toutes les ~3 s, crossfade 0,6 s chrono → glyphe ⏹ (blanc dégradé) → chrono ; en état repos, le glyphe ▶ REMPLACE le chrono (pas d'alternance : l'état se lit d'un coup). **Toute la pastille est la cible** (~250 pt), `contentShape` + `highPriorityGesture(TapGesture())` — jamais un `Button`. |
| y ≈ 440 | la légende « select km/h » (même encre discrète que les captions du cadran) |
| y ≈ 470 → 660 | **la pastille VITESSE** : même lentille, encre `7.0 km/h` (grand) ; halos FIGÉS ou au ralenti si la cadence l'exige (deux lentilles vivantes jamais mesurées ensemble — §8). Tap n'importe où → le panneau vitesse. |
| par-dessus, à la demande | **LE PANNEAU VITESSE** (in-tree, JAMAIS un sheet système — mort dans cette maison) : verre fumé `.regular.tint(noir 0,45)` (le pattern validé du popover stepper, `ExerciseEditor.swift:523-533`), montant du bas. Dedans : **la rangée de raccourcis** (4-6 grosses pastilles ≥ 60 pt : les vitesses récentes + favorites — l'éventail de ta maquette) puis **la GROSSE molette** : `FluidPicker` grossi (hauteur ~96, chiffres ~60, 0 → 20, pas 0,5, ~16 pt/cran), haptique par cran (`UISelectionFeedback`, `prepare()` obligatoire, plancher 40 ms — les leçons MoisIpod), session audio `.ambient + .mixWithOthers` (jamais par-dessus la musique de salle). Un tap raccourci ferme le panneau ; la molette laisse un « Done ». |
| par-dessus, au tap stop | **la notif grosse pièce** (haut, §6.1) puis **LA POP-UP FLAMMES** (§6.2) : `RewardPopup` robe `.fire`, tap pour fermer, on reste en entre-sets |
| y ≈ pageH − 78 | **le slider « Finish »** : `SliderObsidienne(label: "Finish", height: 62, validate: { active != nil }, onConfirm: finirSession)` — la place exacte du « Finish set » muscu (`LiquidLensLab.swift:1252`), AU-DESSUS de la bande du player (le bord physique appartient au drag de levée + Reachability). |
| la bande (110 pt) | la dalle player habituelle (`WorkoutPill(docked:true)`), **`stopVisible: false`** en mode tapis (§0.1). |

**Le mouvement d'arrivée** : un seul progrès `p` porté par une vue
`Animatable`, rampes en `sstep` (l'école StopCard, `StopCard.swift:128-141`) :
la pastille chrono descend du bord haut (la lentille SAIT déjà atterrir en
goutte — `nightLens` :916-937, on rejoue sa naissance), la pastille vitesse
monte du bord bas, la phrase et le slider fondent ensuite. ~0,8 s, haptique
`.impact(.medium)` à la pose, et le chrono du set 1 démarre à `p = 1`
(completion + drapeau, jamais une garde sur la valeur animée).

**Les textes** : ANGLAIS (tranché Coffre §29 ; la StopCard est déjà EN).
« Tap to stop » / « Tap to start » / « SET n » / « Finish » /
« SET 1 COMPLETE ».

---

## 4. LE FOND QUI S'EMBRASE — des paliers, jamais une horloge

**Le mécanisme** (l'avis mesuré du rapport fond, retenu) :

- Le fond du mode tapis = le noir de la scène + **une nappe de braise
  STATIQUE par palier** : 2-3 `RadialGradient`/`Ellipse` nées floues (jamais
  un `.blur` vivant), teintes **R = 1,00 · G 0,30-0,45 · B ≈ 0** (la loi
  anti-brun — un rouge qui monte en opacité sur du noir VIRE AU BRUN si le
  vert ne descend pas avec). Palette LOCALE au tapis — jamais `FlammePalette`
  (partagée avec la home).
- **Le pilote = `setsFaits`**, palier `k = min(setsFaits, 6)` : intensité +
  étendue croissantes, saturation du palier 6 (une séance de 15 sets ne
  finit pas blanche de rouge). Les valeurs des 7 paliers se cuisent au banc
  Python AVANT tout Swift (l'école `essai_fond.py` de la StopCard : composer
  et trancher en 2 min sans builder).
- **L'animation n'existe qu'à la transition** : au tap stop, UN
  `withAnimation(.easeOut(~0,7 s))` monte le palier — ≥ 0,55 s, le plancher
  mesuré de la Lune de sang (en dessous l'œil lit un dégradé, pas un état).
  Entre les sets : STATIQUE. Zéro `TimelineView` plein écran (60 → 16 img/s,
  mesuré), zéro couche pré-montée invisible (le piège du RIDEAU, payé
  30-08 : tel qui chauffe).
- **La lisibilité se mesure** : l'encre blanche des pastilles et la dalle
  (verre `.clear` qui TEINTERA sur fond saturé) se jugent sur capture au
  palier 6, pixels clairs — pas à l'œil sur le palier 1.
- **Le snapshot PageCard** : la nappe doit survivre à l'`ImageRenderer`
  (`PageCard.swift:376-386`) — pas de `blendMode(.plusLighter)` sur fond
  transparent (rendu divergent possible dans la capture) : des gradients
  opaques posés sur le noir. Vérifié à la capture au J3, pas à l'œil.

---

## 5. LES DONNÉES ET L'ARGENT — le miroir exact de la muscu

**Le principe : un set tapis = une série.** Même compteur, même taux, même
chaîne — zéro nouvelle définition du gain (la 9ᵉ copie a été tuée le 30-08).

1. **L'écriture, au tap stop** : une `CardioPhase(kind: .sprint,
   seconds: <mesuré au chrono>, speed: <molette>, cycleIndex: <n° du set>,
   order: 0)` + `context.save()` — le miroir du compteur muscu (« une série
   lancée au compteur arrive déjà cochée : elle a été faite, pas prévue »,
   `ExerciseDetailView.swift:2643-2647`). `kind = .sprint` ⇒ `isEffort`
   (`Models.swift:292`) : les secondes comptent pour le futur fait
   `hiit_secondes`.
2. **Prévu vs fait — `isDone` sur `CardioPhase`, LOCAL seulement.** L'éditeur
   écrit du prévu (`add(_:)`, :2652-2660) ; le player du fait. Sans
   distinction, la paie compterait du prévu. On ajoute `isDone` (défaut
   `false`, migration SwiftData légère) ; le player écrit `isDone: true`.
   **Pas de colonne serveur** : la muscu ne pousse pas non plus son `isDone`
   (`StrengthSetRow`, `SupabaseSync.swift:30-37`) — même dette, cohérente,
   dite au site ; conséquence assumée : une réinstallation perd le
   fait/prévu (la dette « la lecture qui manque » — `SupabaseSync` n'a qu'un
   `push` — déjà connue et générale). (L'alternative « convention sans
   champ » est fragile : un `save()` d'éditeur en pleine séance mélangerait
   tout.)
3. **La paie — LA ligne** : `Workout.seriesPayantes`
   (`Models.swift:360-362`) devient `Σ completedSets + Σ phases faites`
   (`phases.filter(\.isDone)`). Son commentaire (:344-359) désigne ce point
   unique ; ses trois consommateurs (gain de clôture, card STOP, `p_series`)
   suivent d'un coup. ⚠️ Réparer AUSSI `ProfilLune.swift:131` qui recompte
   `completedSets` en direct (bypass) — sinon le profil diverge en silence.
4. **Le serveur : RIEN.** `p_series` est déclaré ; `cloturer_seance` paie
   `p_series × pieces_par_serie` et reste idempotente par séance. Décision
   d'économie explicite (§10.6) : un set tapis vaut 20, comme une série.
5. **La notif lit le taux** : `EconomieWoop.shared.piecesParSerie`
   (`EconomieWoop.swift:105`) — jamais `20`, jamais `CoffreFortPurse.perSeries`.
6. **La sync** : `CardioPhaseRow` pousse déjà kind/seconds/speed/cycle/order
   (`SupabaseSync.swift:39-49, 113-116`) — les phases FAITES partent au
   serveur sans une ligne de plus.
7. **Les faits (hors périmètre, préparé)** : des phases réalisées rendent
   enfin possibles `hiit_secondes` et `vitesse_duree`
   (`moteur_faits.sql:98-109`) — la formule `vitesse_duree` n'est écrite
   nulle part (Σ speed×seconds sur les phases d'effort est l'interprétation
   naturelle) : à trancher AVANT que quiconque code le calcul client.
8. **⚠️ LE SITE DE DOC, dans les MÊMES commits** (règle absolue) :
   - poser le **litige** `cardio_phases` (⚪ « à retravailler » vs push réel
     `SupabaseSync.swift:113-116`) dès maintenant ;
   - au J2 : la brique `cardio_phases` change d'état (la table reçoit du
     FAIT), la règle `pieces_par_serie` reçoit la note « s'applique aussi aux
     sets tapis (client, `seriesPayantes`) » ;
   - au J3 : le site d'appel de la notif (si genre nouveau) ;
   - `npm run artefact` PUIS `npm run verif` (l'ordre mesuré), republier au
     même lien, source + livrable dans le commit du changement.

---

## 6. LA FIN DE SET SE FÊTE DEUX FOIS — la notif (l'enregistrement) + la pop-up flammes (l'encouragement)

Tranché le 31-08 : au tap stop, DEUX choses (dans cet ordre) — la notif qui
dit « c'est enregistré, +20 », puis la pop-up stylée flammes qui encourage.

### 6.1 La notif « grosse pièce » — brancher la robe, enfin

Elle décrit exactement **`NotifJauge`** : la dalle 138 pt à la pièce de
92 pt qui mord le bord (`NotifCard.swift:140-165`) — codée, validée au banc,
JAMAIS branchée (le vrai flow montre encore `PillGain`).

**Proposé : le tapis est le premier client de la robe.**
`NotifJauge(sousTitre: "SET \(n) COMPLETE", libelle: "COINS EARNED",
gain: piecesParSerie, fraction: <jauge du coffre>, …)` — la `fraction` lit
`EconomieWoop` (le solde jaune, < 100 par construction depuis la conversion,
sur le prix du sachet) — montée **locale à la page tapis** (le précédent PillGain : zIndex 30 local, `allowsHitTesting(false)`,
~3 s, transition `.move(.top)`) — pas via `FileAnnonces` (la pile racine
sert la clôture ; y injecter une robe 138 pt casserait sa grammaire capsule).

- Elle descend du haut : elle passera DEVANT la phrase « Tap to stop » 3 s —
  acceptable (elle arrive quand le set est FINI, l'état est au repos ;
  hit-testing false, rien n'est volé). À juger sur film au J2.
- ⚠️ Le strobe de la planche est MESURÉ (`PLAN-NOTIFS-V8.md` §A) : la pièce
  à 72 cases jouée lentement stroboscope — la robe actuelle a son réglage,
  ne pas y toucher.
- Repli si elle préfère la cohérence de la pile : `case serie(rang:gain:)`
  dans `Annonce` (trois switches exhaustifs, `Annonces.swift:38-42, 129,
  168`) — mais la pièce reste petite (20 pt), ce n'est PAS sa demande.
- La clôture, elle, ne change pas : story → `FileAnnonces` → pièces +
  sachet (la chaîne actuelle, intouchée).

### 6.2 LA POP-UP FLAMMES — l'encouragement (verdict 31-08)

**La base existe et elle est à ELLE** : la robe **`.fire`** de la card
reward — « le sticker FLAMME NOIRE au centre (l'asset de Kathryn) »
(`RewardCard.swift:49, 59-60` ; force ×2 sur son effet :704 ; banc
`-fireAuto` :1690-1692). La muscu la sort déjà à la série ×10
(`DecideurSerie`, `RestartSheet.swift:615` : `.reward(style: .fire, video:
"reward-rare")`) et la monte par `jouerIssue`
(`ExerciseDetailView.swift:2373-2397`). **Rien à inventer : une
`RewardPopup` en robe `.fire`, avec l'encre du tapis.**

- **Le contenu** : le sticker flamme au centre, un titre encourageant
  (copy EN, tiré au sort dans une petite liste — « KEEP BURNING » /
  « ON FIRE » / « ONE MORE » …), et le **bilan du set en sous-titre**
  (« SET 3 · 0:45 · 17 km/h ») — le seul endroit qui montre ce que le set
  a pesé. Pas de pièces dedans : l'argent est dit par la notif (§6.1), la
  pop-up ne parle que du feu.
- **Le crescendo** : la pop-up monte en intensité avec les sets — le MÊME
  pilote que le fond (`setsFaits`) nourrit sa force de flamme (le paramètre
  `force` existe déjà :704). Le fond rougit, la flamme grossit : une seule
  histoire.
- **La séquence au tap stop** : notif tout de suite (+0 s) → pop-up à
  +0,4 s (elle naît sous la notif qui descend, pas en même temps). Tap
  n'importe où pour fermer → retour à l'écran entre-sets. Le tap play du
  set suivant reste sur la pastille — fermer la pop-up ne relance JAMAIS un
  set (fermer ≠ repartir).
- **La cadence** : la robe `.fire` est validée mais jamais montée sur une
  page qui porte deux lentilles + une nappe de braise — la mesure du J2
  la couvre (film du tap stop complet : notif + pop-up + palier qui monte).
- **Ce qu'on n'importe PAS de la muscu** : le `DecideurSerie` (les rendez-
  vous %3/%5/%10) et le panneau « Recommencer ? » — sur tapis, chaque set
  sort la MÊME paire notif + pop-up, prévisible.

---

## 7. LE CÂBLAGE — fichiers neufs d'abord, la fiche en dernier

**Neufs (J0-J2, zéro conflit de session) :**
- `Woop/Views/TapisScene.swift` — `SeanceTapis` (@Observable), `TapisScene`
  (la page : phrase, deux pastilles, panneau vitesse, slider, nappes de
  braise), en **vues nommées** (le mur du type-checker a déjà cassé un build
  device). La lentille : **extraire de `LiquidLensLab` une
  `PastilleLentille` paramétrée** (titre, encre centrale, vie) — la
  discipline MedaillonStop/VeineOr : paramétrer, jamais copier ; avec
  **non-régression du parcours muscu mesurée** (`-lensLab` filmé
  avant/après). Si l'extraction s'avère trop invasive à la lecture fine
  (le fichier est un monde), repli assumé : composer localement les MÊMES
  shaders (`liquidLens` + `eclipseGlow`) — ~50 lignes, le précédent des 16
  `sstep` privés. Tranché au J0, à la lecture, pas avant.
- `Woop/Views/TapisLab.swift` — le banc (école `StopLab`/`NotifLab`).
- `tools/tapis/` — `voir.sh` (copie de `tools/stop/voir.sh`, `$?` capturé
  sur la ligne), `essai_fond.py` (les paliers de braise cuits sans builder),
  captures/, films/.

**La fiche (J3, coordination session player) :**
- `ExerciseDetailView.swift` : la branche `tapisPage` (montée si
  `.intervals` + séance + `seanceTapis.enCours`), le handoff du galet cardio
  (le point d'entrée de l'autre session : la branche `else` de :872) →
  `seanceTapis.demarrer()` + l'arrivée. La dalle passe
  `stopVisible: false` en mode tapis.
- `Models.swift` : `isDone` sur `CardioPhase` + `seriesPayantes` élargie
  (deux hunks chirurgicaux). `ProfilLune.swift:131` : le bypass réparé.
- La clôture, la StopCard, `terminerSeance()` : **zéro ligne.**

---

## 8. LES BANCS, LE SIM, LES MESURES

Sim dédié : **kat-tapis** (à créer). DerivedData : `dd-tapis`.
`./tools/charge.sh` avant TOUTE mesure (🔴 > 2 = ne pas mesurer) ;
`--terminate-running-process` obligatoire ; lancer deux fois avant capture.

| argument | effet |
|---|---|
| `-tapisLab` | la scène seule sur données bidon (sets, vitesse, paliers simulés au tap) |
| `-tapisFige` | naît posée (`p = 1`), captures immobiles |
| `-tapisT <s>` | les horloges (pulse, alternance, lentilles) clouées à l'instant s |
| `-tapisSet <n>` | naît avec n sets faits — UNE capture PAR PALIER de rouge |
| `-tapisAuto` | joue un cycle set→stop→notif→start en boucle — c'est lui qu'on FILME |
| `-fps` | `SondeCadence("tapis")` par régime (repos / set qui court / panneau ouvert / transition de palier) |

**Le vrai risque cadence : DEUX lentilles vivantes + la nappe + le pulse.**
Jamais mesuré ensemble (la muscu n'a qu'UNE lentille). Cibles : 60 au sim au
repos, pire trou < 34 ms ; verdict au TÉLÉPHONE. Si ça tombe : d'abord
`-tapisT` pour isoler, puis dégrader la lentille vitesse (halos figés) avant
de toucher au reste.

**Non-régression** : `-lensLab` (parcours muscu) filmé avant/après
l'extraction de la lentille — pas un pixel de différence attendu ;
`-homeSeance -fps` inchangé.

**L'économie se prouve en LISANT** : une clôture au compte de test
(`-skipAuth -sessionBanc -outboxBanc`) avec N sets tapis → la réponse de
`cloturer_seance` LUE (pieces = N × 20), le carnet lu. Jamais « ça doit
marcher ».

---

## 9. JALONS — chacun avec sa preuve

- **J0 — LA SCÈNE AU BANC.** `TapisScene` + `TapisLab` + l'extraction (ou le
  repli) lentille. Preuve : captures `-tapisFige` comparées aux maquettes
  (phrase, deux pastilles, slider) ; film `-tapisAuto` (arrivée 0,8 s, tap
  stop → état repos, tap play → set suivant) ; alternance et pulse dérivés
  de l'horloge (vérifié à `-tapisT`) ; cadence `-fps` après `charge.sh` ;
  non-régression `-lensLab`.
- **J1 — LA VITESSE.** Le panneau (raccourcis + grosse molette), haptiques
  préparées. Preuve : captures du panneau ; film ouverture/choix/fermeture ;
  le km/h de la pastille suit ; cadence panneau ouvert.
- **J2 — LES DONNÉES, L'ARGENT, LE ROUGE, LA FÊTE.** `isDone` +
  `seriesPayantes` + écriture au stop + `NotifJauge` branchée + **la
  pop-up flammes** (robe `.fire`, encre tapis, crescendo) + paliers de
  braise (cuits d'abord dans `essai_fond.py`). Preuves : les phases LUES en
  SwiftData après 3 sets au banc (sonde console) ; UNE clôture compte de
  test → réponse `pieces` lue ; capture PAR palier (`-tapisSet 0..6`), G/R
  mesuré sur pixels clairs (0,30-0,45) ; film du tap stop COMPLET (notif à
  +0 s, pop-up à +0,4 s, palier qui monte — cadence de la séquence
  mesurée) ; la pop-up fermée au tap ne relance pas de set (vérifié au
  film). **Le site de doc part dans le même commit** (§5.8).
- **J3 — LA FICHE.** Le branchement réel : galet cardio (coordination
  session player) → arrivée → sets → slider Finish → chaîne de clôture
  INTACTE (story, pile, trophée). Preuve : film du flow complet au sim ;
  le snapshot PageCard capturé avec les pastilles montées (levée du player
  pendant un set : chrono figé, rien de noir) ; dalle sans stop en mode
  tapis, stop présent ailleurs.
- **J4 — TON VERDICT, au téléphone, si possible SUR le tapis.** La molette
  au doigt à 17 km/h (le seul test qui compte), les haptiques réelles, la
  cadence, la lisibilité du palier 6, l'écran qui ne dort pas. J4 n'est pas
  automatique : tant que tu n'as pas tranché, le chantier est ouvert.

Commits par chemins, dans l'ordre des jalons ; `git log -1` avant chaque ;
message sans trace d'assistant.

---

## 10. À TRANCHER (mes recommandations en premier)

> ⚡ **31-08, « ok » de Kathryn** sur les points restants (fin de session,
> stop de dalle, raccourcis+molette, économie) : les recommandations
> s'appliquent. Les points mineurs non relistés partent AUSSI sur la reco,
> par défaut — réversibles au banc, un verdict à l'écran peut les rouvrir.

1. ~~La fin de session~~ — **TRANCHÉ 31-08 : le slider « Finish » de la
   page commet la clôture DIRECTEMENT** (glisser est déjà l'anti-accident,
   seuil 0,72 ; la StopCard reste la voie du stop de dalle sur les AUTRES
   pages).
2. ~~Le stop de la dalle en mode tapis~~ — **TRANCHÉ 31-08 : masqué**
   (`stopVisible: false`, §0.1).
3. ~~L'alternance chrono ⇄ ⏹~~ — **TRANCHÉ 31-08 : 2 premiers sets puis
   extinction** (le seuil reste réglable au banc).
4. **Le temps de repos affiché** — oui, petit « rest m:ss » sous la pastille
   en état repos (recommandé : HIIT = repos calibrés au feeling) / non
   (l'écran le plus nu possible).
5. **La vitesse en plein set** — v1 : une phase par set, la vitesse du STOP
   fait foi (recommandé — simple, honnête) / découper la phase à chaque
   changement (fidèle mais complexe, et le fait `vitesse_duree` n'existe
   même pas encore).
6. ~~L'économie~~ — **TRANCHÉ 31-08 : un set tapis = 20 pièces
   (`pieces_par_serie`), sans plancher de durée** — dit au site de doc au
   J2.
7. ~~La plage de la molette~~ — **TRANCHÉ 31-08 : 0 → 20 pas 0,5 +
   raccourcis récents/favoris** (la divergence 0-25 de l'éditeur est
   assumée ; le détail des raccourcis se règle au banc).
8. **Le carré noir** dans la pastille vitesse de la maquette — un glyphe
   tapis ? un vide ? (recommandé : rien — l'encre du km/h suffit, la
   lentille est la matière).
9. **`.steady` (tapis-lent)** — hors périmètre v1 (recommandé) / le même
   player avec un seul « set ».
10. **La pop-up flammes, ses mots** — copy EN tirée au sort (« KEEP
    BURNING », « ON FIRE », …) avec le bilan du set en sous-titre
    (« SET 3 · 0:45 · 17 km/h ») (recommandé) / un texte fixe. Et la
    vidéo : la robe `.fire` muscu embarque `reward-rare` — sur tapis,
    recommandé SANS vidéo (la flamme + le crescendo suffisent, et la
    cadence de la page est déjà chargée).
11. **La pop-up se ferme-t-elle seule ?** — non, tap obligatoire
    (recommandé : c'est l'instant de repos, elle a le temps, et une card
    qui s'enfuit n'encourage pas) / auto-fermeture ~4 s (le tap play reste
    accessible dès qu'elle part).

---

## 11. LES PIÈGES QUI S'APPLIQUENT (déjà payés ailleurs)

1. **Le mur du type-checker** — vues nommées, jamais un empilement
   d'expressions ; le banc = un `static let` + un `else if`.
2. **La page ré-évaluée par image** — le chrono/pulse/alternance vivent dans
   des `TimelineView` FEUILLES (la pastille seule), fonctions pures de
   dates-ancres ; l'hôte ne lit que des états discrets (`setIndex`, `etat`,
   `vitesse`) ; jamais `withAnimation(.repeatForever)` sur un état (avalé
   quand le parent se ré-évalue — payé 2×, `PageCard.swift:402-407` ;
   la fuite du souffle, `WorkoutPill.swift:409-443`).
3. **Deux horloges dérivent** — l'alternance, le pulse et le chrono dérivent
   de LA MÊME horloge (phase), jamais d'un `DispatchQueue`.
4. **Un `Button` sous un drag d'ancêtre est annulé** — les taps des
   pastilles : `contentShape` + `highPriorityGesture(TapGesture())` (loi
   `WorkoutPill.swift:498-514`).
5. **Un `DragGesture` peut mourir sans `onEnded`** — la molette et le slider
   gardent remise à plat sur `startLocation` + chien de garde qui COMMET si
   le seuil était franchi ; le bug « molette 30× » n'est PAS réglé : la
   physique se re-mesure AU DOIGT avant d'être déclarée saine.
6. **Le verre** — `.regular` nu INTERDIT ; le panneau vitesse = verre fumé
   teinté (pattern stepper) ; jamais un verre aux bounds vivants (blur plat
   définitif) ; le verre ne se reconstruit jamais par image.
7. **Le rideau** — rien ne se monte invisible « pour plus tard » : le
   panneau vitesse ne se monte qu'ouvert, la nappe du palier courant
   seulement (tel qui chauffe, payé 30-08).
8. **L'anti-brun** — R = 1,00, G désaturé, B ≈ 0 ; `mix` vers la teinte,
   jamais une addition ; mesuré sur pixels clairs, jamais en moyenne.
9. **`onConfirm:` nommé** sur SliderObsidienne (closures traînantes
   interdites — deux propriétés optionnelles suivent) ; le slider ne se
   démonte pas avant +0,45 s (son filament joue).
10. **Le montant se LIT** (`EconomieWoop.piecesParSerie`) — jamais 20 en dur
    (la 9ᵉ copie a été tuée le 30-08).
11. **Le build et la mesure** — `$?` sur la ligne, jamais `| grep` ;
    `charge.sh` avant `-fps` ; une cinématique se FILME ; le verdict est au
    téléphone ; `-demoData` sème une séance ouverte qui persiste
    (uninstall) ; `-skipAuth` pour capturer.
12. **Multi-session** — commits par chemins/hunks ; `PlayerSeance.swift`
    (untracked) et les hunks des autres ne se touchent JAMAIS ; le J3
    attend/coordonne la session du galet cardio.
13. **La doc** — toute modification qui touche la paie, la table ou un site
    d'appel embarque `docs/site/content/*.ts` + artefact + verif DANS le
    même commit (règle absolue du CLAUDE.md).
