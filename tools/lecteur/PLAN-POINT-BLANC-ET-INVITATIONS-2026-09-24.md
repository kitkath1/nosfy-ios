# Le point blanc, et ce qui donne envie de choisir

**Plan du 24-09-2026, après son essai sur son iPhone.** Rien n'est codé.
Aucun banc n'est écrit. C'est un plan, et il s'arrête là.

---

## 1. Ce qu'elle a dit, mot pour mot

> « je revois le design de la pastille c'est horrible — pensais à un point
> blanc minimal avec pulsar effet et petites paillettes autour basta ! et il
> n'apparaît pas dans la vidéo compteur après avoir lancé la série. aussi une
> fois que la session commence, je vois les paillettes cool, mais certaines
> restent sur l'écran.
>
> animé s'il te plaît le carré avec le jour et le sticker ils flottent, et
> animé de manière "inégale" les carrés avec les catégories, les blancs
> s'illuminent assez fort pour inviter le user à choisir une session tu sais,
> ça ne donne pas encore envie de choisir une catégorie ou un exercice tu
> comprends »

Puis, dans la foulée :

> « et autre fix ! les paillettes de transition restent aussi une fois l'exo
> lancé, fix ça, ajoute dans ton plan »
>
> « elles doivent être encore plus fines genre 0,4px en dégradé »

Sept choses. **Deux sont des défauts que j'ai introduits hier**, cinq sont
du design. Les défauts passent d'abord : on ne pose pas d'animation sur un
écran qui garde des traces.

---

## 2. DÉFAUT — des paillettes restent sur l'écran

**Cause trouvée, et elle est chiffrée. Ce sont MES étincelles.**

Hier, pour « encore plus d'effet », j'ai donné aux 2,5 % d'étincelles une vie
**2,8 fois plus longue** que les autres points. Personne n'a refait le calcul
de la fin du passage.

| | |
|---|---|
| vie la plus longue d'une particule | `(0,18 + 0,55 + 0,14) × 2,80` = **2,436** |
| retard le plus tardif | `0,44 × 0,99 + 0,10` = **0,536** |
| **dernière mort** | **2,97** |
| or le calque gèle son horloge à | `avance = min(t, 1,35)` |
| et s'arrête à | `if t > 1,35 { isPaused = true }` |

Donc à 1,35 les étincelles sont **encore vivantes** — et un `MTKView` qu'on
met en pause **laisse sa dernière image à l'écran**. Elles ne disparaissent
pas : elles se figent. C'est exactement ce qu'elle voit.

**Le correctif, et il a deux moitiés — l'une sans l'autre ne suffit pas :**

1. **Aller jusqu'au bout.** Le passage doit courir jusqu'à la dernière mort,
   pas jusqu'à un nombre écrit à la main. La borne se CALCULE depuis les
   constantes du shader ; si on retouche une vie ou un retard, elle suit
   toute seule. Un `1,35` en dur redeviendra faux au prochain réglage.
2. **Éteindre avant de dormir.** Dessiner **une image vide** — rien, le
   cadre nettoyé — PUIS mettre en pause. Sinon la dernière image reste
   affichée, quelle qu'elle soit.

⚠️ **Et raccourcir la vie des étincelles n'est PAS le correctif.** Ce serait
soigner le symptôme et reperdre ce qu'elle a aimé (« je vois les paillettes,
cool »). On garde les étincelles longues, on corrige la fin.

### Ce que sa capture du 24-09 ajoute — c'est plus grave que je ne le disais

Elle a envoyé une photo de son écran, en pleine séance, APRÈS le passage.
On n'y voit pas « quelques paillettes oubliées » :

- des dizaines de points blancs sur **tout** l'écran, jusque dans les coins ;
- et **trois taches rouge sombre**, rectangulaires : une autour du carré du
  jour, une derrière « Squat à la barre », une derrière « session · 5:36 ».

⚠️ **CORRECTION DU 24-09, APRÈS MESURE — j'avais accusé les particules.**
J'ai d'abord écrit ici que les taches étaient la même image figée, la
population de fond née sur les pixels clairs. **C'est faux, et la capture du
simulateur le prouve** : sur un lecteur ouvert SANS qu'aucun passage n'ait
joué, les trois taches sont là, identiques. Ce sont **deux défauts
distincts** — les points blancs sont bien le calque figé (ci-dessus), les
taches orange sont un défaut du lecteur lui-même, traité au §13.

**Et c'est vérifiable avant d'écrire une ligne.** `-ouvertureLab 1.4` fige le
passage à 1,4 : si l'image obtenue ressemble à sa capture, la cause est
prouvée par l'image, et plus seulement par l'arithmétique. Une commande, une
capture, et on sait.

⚠️ **Ça déplace la gravité du défaut.** Ce n'est pas un ornement qui traîne :
c'est un calque fantôme complet, posé par-dessus le lecteur, avec de la
couleur sur un écran qui doit être noir. Ça passe avant tout le reste.

### Elle le voit à DEUX endroits, et c'est la même maladie

> « les paillettes de transition restent aussi une fois l'exo lancé »

Au départ de la séance, et au lancement d'un exercice. Les deux passent par
`CoupeEtat.jouer`, donc par le même calque et la même horloge : **une seule
cause, un seul correctif**. Ce n'est pas deux bugs.

⚠️ **Mais le lancement d'un exercice ajoute un risque propre, qu'il faut
regarder en même temps** : la fiche s'ouvre PENDANT que les étincelles vivent
encore. Si le calque cesse d'être rendu parce qu'il est couvert — ou si
l'écran change de hiérarchie sous lui — `draw(in:)` ne tourne plus, et la
dernière image se fige exactement comme à la mise en pause. **Même symptôme,
autre porte.** Trois portes à fermer, donc :

1. la pause de fin (§ ci-dessus) ;
2. l'app qui passe en **arrière-plan** pendant le passage ;
3. l'écran qui **change de hiérarchie** pendant le passage.

La règle qui les ferme toutes les trois : **le calque ne se met jamais en
pause sans avoir d'abord dessiné une image vide.** Là où l'on éteint, on
nettoie d'abord.

---

## 3. DÉFAUT — le point n'est pas là pendant la vidéo compteur

Elle lance une série, l'écran du compteur prend tout — et le témoin
disparaît. **C'est logique, et c'est le signe que je l'ai mal posé.**

Le point est aujourd'hui posé **par-dessus la barre d'onglets**. Il n'existe
donc que là où la barre existe. Or la barre est masquée sur le lecteur, sur
la fiche immersive, et pendant le compteur : c'est-à-dire **pendant presque
toute la séance** — le seul moment où un témoin « ça tourne » a un sens.

**La question n'est pas « comment le ramener dans le compteur »**, c'est
**« de quoi ce point est-il le témoin ? »**

Deux réponses possibles, et il faut qu'elle tranche :

- **A. Le point est le témoin de la SÉANCE.** Alors il vit à la racine, au
  même endroit à l'écran quoi qu'il arrive — barre ou pas — et il ne bouge
  jamais. Il devient un repère, comme la pastille rouge d'un enregistreur.
  ⚠️ Mais il se superposerait au compteur, qui est une image plein écran :
  il faut lui trouver un coin qui ne gêne pas, et ce coin doit être le même
  partout.
- **B. Le point est le témoin de l'ONGLET.** Alors il reste où il est, et
  son absence pendant le compteur est normale : l'île Dynamic Island fait
  déjà le travail de témoin pendant la séance.

**Ma recommandation : B, plus une vérification.** L'île dit déjà « ça
tourne » en haut, et en permanence. Un deuxième témoin permanent en bas,
c'est deux choses qui disent la même. Le point garde alors son rôle : « ton
exercice t'attend derrière cet onglet ». Mais il faut **vérifier sur son
téléphone que l'île est bien allumée pendant le compteur** — si elle ne
l'est pas, alors A devient la bonne réponse et il n'y a plus de débat.

### ⚠️ TRANCHÉ PAR ELLE, le 24-09 — c'est A

Ce paragraphe a été écrit avant son message suivant. Elle n'a pas choisi
entre A et B : elle a dit que le point **n'est nulle part**.

> « le bouton REC (avec nouveau design) qui ouvre l'overlay composant du
> détail de la séance n'apparaît que dans le menu et sur aucune page, et il
> doit être centré à côté des autres icônes dans le menu. »

Donc : **témoin de la SÉANCE**, pas de l'onglet. Ma recommandation B tombe,
et la vérification de l'île n'est plus un préalable. La suite est au §7.

---

## 3bis. LE GRAIN — « encore plus fines, genre 0,4 px, en dégradé »

C'est un réglage de l'ouverture, pas du point blanc. Et il y a une chose
technique à dire avant de promettre quoi que ce soit.

**On ne peut pas écrire « 0,4 pixel » et l'obtenir.** Un point de moins d'un
pixel ne devient pas plus fin : le rasteriseur lui donne quand même un
fragment entier, à pleine intensité. On obtiendrait des grains **plus durs**,
pas plus fins — du poivre. C'est le piège inverse de celui d'hier.

**Ce qui donne vraiment « 0,4 px en dégradé »**, c'est la **chute** du
fragment, pas sa taille : on garde un point de deux à trois pixels et on
resserre fortement sa décroissance, pour que le **cœur visible** fasse une
fraction de pixel et que tout le reste soit un dégradé qui s'éteint. Le
centre est net et minuscule, le bord n'existe pas.

Trois conséquences, et la troisième est la plus importante :

1. **Le nuage va s'assombrir.** Resserrer la chute enlève de la lumière à
   chaque point. C'est mécanique.
2. **On la récupère par le NOMBRE, jamais par la taille ni par l'opacité.**
   C'est la leçon déjà payée deux fois le 23-09 (60 000 puis 320 000 points :
   de la poussière, deux fois). Il faudra donc **remonter le compte** — et
   c'est précisément ce qui coûte.
3. ⚠️ **Donc ce réglage a un prix, et il se mesure.** Aujourd'hui 900 000
   points, non mesurés sur son téléphone. Affiner le grain **et** remonter le
   nombre, sans avoir jamais pris un chiffre, ce serait avancer les yeux
   fermés sur le seul sujet où elle m'a dit que toute l'app a un souci.

**Ma proposition : on affine le grain, et on regarde ce que ça donne AVANT de
remonter le nombre.** Il est possible que le nuage plus fin lui plaise plus
sombre — c'est son œil qui décide, pas la moyenne de luminance.

---

## 4. LE POINT BLANC — ce qu'il devient

Le diamant est **mort**. Elle l'a dit en un mot : horrible. Il ne revient
pas, et il n'y a rien à en sauver : huit facettes dans 26 points, c'était un
bijou regardé à la loupe et un caillou brun sur le téléphone.

> « un point blanc minimal avec pulsar effet et petites paillettes autour
> basta ! »

**Trois éléments, et RIEN d'autre. Le mot « basta » fait partie du cahier
des charges.**

### Le point
Un disque **blanc pur**, petit — de l'ordre de 8 à 10 points, pas 26. Pas de
dégradé, pas de facette, pas de braise rouge au centre. Du blanc sur du noir.
C'est sa loi appliquée à la lettre : la brillance vient de la blancheur.

### Le pulsar
Un **anneau qui naît sur le point et s'en éloigne en s'effaçant**, puis un
autre. Pas un clignotement du point lui-même : le point reste stable, c'est
l'onde qui part de lui.

⚠️ **Ce n'est pas un balayage, et il faut savoir pourquoi** : l'anneau a une
**cause** (le point), un **bord** net, et il part du centre dans toutes les
directions. Un balayage, c'est une bande qui traverse une surface sans
raison. Ici la lumière naît d'un objet visible et le quitte. C'est la
différence entre une onde et un projecteur.

Deux anneaux au plus, décalés d'une demi-période. Trois font une cible de
radar.

### Les paillettes
**Cinq à sept points d'un pixel**, blancs, semés autour à des distances
différentes, qui s'allument et s'éteignent **chacun à son rythme** — jamais
ensemble, jamais en cercle régulier. Elles ne tournent pas, elles ne
glissent pas : elles apparaissent et disparaissent sur place.

Elles sont le rappel des paillettes de l'ouverture qu'elle vient d'aimer —
c'est le même vocabulaire, en tout petit.

### Ce que ça coûte
**Rien, et c'est le point de la proposition.** Un disque, deux anneaux, sept
points : toutes les animations sont des **opacités et des échelles** — des
valeurs que le système interpole seul, sans jamais reconstruire le dessin.
On reste du bon côté de la loi mesurée le 05-09 (animer : 4-18 % ;
redessiner : 33-38 %). Le `Canvas` et son `drawingGroup` disparaissent avec
le diamant.

---

## 5. Le carré du jour et le sticker — ils flottent

> « animé s'il te plaît le carré avec le jour et le sticker ils flottent »

**Deux objets, deux flottements différents.** S'ils montent et descendent
ensemble, ce n'est pas du flottement, c'est un ascenseur.

- **Le carré de la date** : une dérive verticale très courte — deux ou trois
  points — sur une période lente, cinq ou six secondes, avec une inclinaison
  d'un demi-degré qui suit le mouvement. Un objet qui flotte ne monte pas
  droit : il roule un peu.
- **Le sticker des séries** : sa propre période, plus courte et **non
  multiple** de celle du carré (par exemple 4,1 s contre 5,7 s), et son
  propre angle. C'est le décalage qui fait croire à deux objets libres ; deux
  périodes proportionnelles les recollent au bout de quelques secondes et
  l'illusion tombe.

⚠️ **Le sticker est déjà posé de travers sur le carré.** Il faut regarder au
ralenti que son flottement ne le fasse pas sortir du carré ni cogner le bord
du ticket : c'est un décalage de quelques points, mais à cette taille ça se
voit.

Tout est en `offset` et `rotationEffect` — animable, donc gratuit.

---

## 6. Les carrés de catégories — le vrai sujet

> « animé de manière "inégale" les carrés avec les catégories, les blancs
> s'illuminent assez fort pour inviter le user à choisir une session tu
> sais, ça ne donne pas encore envie de choisir une catégorie ou un exercice
> tu comprends »

**Je comprends, et je crois que le défaut n'est pas l'animation : c'est que
rien n'appelle.** Hier je n'ai fait respirer QUE la zone déjà choisie. Donc
la seule chose qui bouge est celle qu'on a déjà, et les quatre autres — les
choix possibles — restent éteintes. **J'ai animé la réponse, pas la
question.** C'est exactement l'inverse de ce qu'il faut.

### Ce qui change

1. **Les cinq respirent**, pas seulement celle où l'on est. Ce sont les
   choix qu'on éclaire.
2. **Inégalement, et c'est son mot.** Chaque carré a **sa propre période**,
   tirée de son rang et jamais un multiple des autres (par exemple 2,3 ·
   3,1 · 2,7 · 3,7 · 2,9 secondes), et **sa propre avance au départ**. Elles
   ne se rattrapent jamais. Cinq carrés sur la même horloge, c'est une
   guirlande de Noël — et une guirlande, c'est cheap.
3. **Plus fort qu'hier.** La lueur monte franchement, jusqu'au blanc vif, et
   redescend bas. Hier j'étais entre 0,58 et 1,00 : trop timide, ça se voit à
   peine. Il faut descendre plus bas et monter plus haut — c'est l'écart qui
   attire l'œil, pas le niveau moyen.
4. **La zone où l'on est reste distinguée** — mais par son **bord**, qui est
   déjà là, pas par la lueur. Sinon on ne sait plus lire ce qui est choisi.

### Et une chose de plus, qu'elle n'a pas demandée mais qui répond à « ça ne
donne pas envie »

Les quatre exercices proposés dessous sont des rangées grises, immobiles,
toutes pareilles. **Le carré invite, la liste refroidit.** Je pense que la
première rangée — celle que Nosfy propose — mérite le même traitement : sa
vignette s'éclaire doucement, elle seule. Une seule ligne vivante dans une
liste morte, ça se remarque plus que cinq.

⚠️ **C'est une proposition, pas une décision.** Si elle dit non, on ne touche
qu'aux carrés.

---

## 7. DÉFAUT — le point n'existe que sur la home, et pas à sa place

> « n'apparaît que dans le menu et sur aucune page, et il doit être centré à
> côté des autres icônes dans le menu. »

**Vérifié dans le code — ce n'est pas une impression, c'est mécanique :**

- `PointRecSurBarre` est posé en **surimpression à la racine**, en bas
  (`NosfyApp.swift`) — c'était la seule route qui marchait, un item d'onglet
  natif refusant toute vue vivante (les trois essais du 23-09) ;
- mais les deux autres onglets **masquent la barre** :
  `.toolbarVisibility(.hidden, for: .tabBar)` sur Exercices **et** sur Profil ;
- donc le point ne peut apparaître **que sur l'onglet Accueil**. Partout
  ailleurs — fiche, compteur, catalogue, profil — la barre n'est pas là, et
  lui non plus.

### Ce qu'il devient

1. **Un composant, une place, mesurée.** Bas de l'écran, à la hauteur des
   icônes. Quand la barre est là, il se pose **sur** l'item Exercices ; quand
   elle n'est pas là, il reste **au même endroit**, seul sur le noir. L'œil
   ne le voit jamais sauter d'un écran à l'autre.
2. **Sa position se mesure en X ET en Y.** Le 23-09 je n'ai relevé que la
   hauteur (40 pt d'écran → 6 pt sous la zone sûre) et j'ai **supposé** le
   centre horizontal parce qu'il y a trois onglets. Elle dit qu'il n'est pas
   « centré à côté des autres icônes » : je ne devine pas une deuxième fois.
   Une capture de son téléphone, barre visible, et on relève le centre du
   glyphe Exercices. **Une capture, deux nombres.**
3. **Il prend le doigt lui-même.** Aujourd'hui il laisse passer le tap à
   l'onglet dessous (`allowsHitTesting(false)`) — ce qui ne marche que là où
   il y a un onglet dessous. Hors barre il n'y a rien : il doit devenir un
   **vrai bouton** qui ouvre l'overlay, comme le fait la pilule de l'île.
   ⚠️ Conséquence : sur la barre, c'est LUI qui répondra, plus l'onglet — la
   route vers l'overlay doit donc être **la même des deux côtés** (§8).

### ⚠️ Le problème que ça pose, et que je ne peux pas résoudre seul

Le bas de l'écran **est déjà occupé** hors de la barre : sur le lecteur, le
galet Stop est au centre en bas — on le voit sur sa capture. Trois choses en
découlent :

- **Sur le lecteur, le point n'a rien à faire.** On y est déjà : un témoin
  qui dit « ta séance t'attend » devant la séance elle-même ne dit rien. Il
  ne s'y pose pas, et le conflit avec le Stop n'existe plus.
- **Sur le compteur, la fiche et le catalogue**, il faut vérifier que la
  place est libre. Trois captures à prendre sur son téléphone, une par écran.
- **Si une seule de ces places est prise**, alors « le même endroit partout »
  devient faux, et il faut choisir : soit le point monte au-dessus de ce qui
  occupe le bas, partout, soit il change de coin. Je ne tranche pas ça sur
  des suppositions — je le tranche sur les trois captures.

---

## 8. DÉFAUT — « Choose an exercise » ouvre la page rouge, pas l'overlay

> « sur la homepage le bouton "choose exercice" n'ouvre pas la page exercice
> rouge (celle qu'on a par défaut quand la session n'est pas lancée) mais
> bien notre composant overlay. »

**La garde existe déjà — elle est juste au mauvais endroit.** Le code tient
la règle « pendant une séance, Exercices = le lecteur » dans le *binding* du
TabView (`NosfyApp.swift:1497`) : taper l'**onglet** pendant une séance ne
change pas d'onglet, ça pose le lecteur.

Mais le bouton de la home ne passe pas par ce binding :

```
HomeNuit.swift:3437   onChoisir: { onRoute(.exercises) }
NosfyApp.swift:1083   func routerVers(_ dest:) { selection = dest }   ← en direct
```

`routerVers` **écrit la sélection sans passer par le binding**, donc sans
passer par la garde. Tout ce qui vient de la home entre par là : le bouton
« Choose an exercise », et aussi la porte de la route (`HomeNuit.swift:4807`).
Résultat : en pleine séance, ils ouvrent la page rouge.

**Le correctif n'est PAS d'ajouter une deuxième garde.** Deux gardes, c'est
deux vérités qui divergeront au premier changement. **Une seule porte** : une
fonction `allerAuxExercices()` qui porte la règle, et tout le monde l'emprunte
— le binding, `routerVers`, la porte de la route. Ce qui arrivera demain
passera par elle, ou ne marchera pas du tout ; c'est ce qu'on veut.

⚠️ **C'est la troisième fois que ce défaut revient sous un autre costume** :
le 22-09 « Page exercices » basculait l'onglet et n'en revenait jamais ; le
22-09 encore, le chevron de la page ; aujourd'hui le bouton de la home. La
cause est chaque fois la même — la règle est écrite **chez les appelants**
au lieu d'être écrite **à la porte**.

---

## 9. « Il y a trop de fois l'effet paillette » — la règle d'une fois par séance

> « conserve-le que [pour] l'arrivée par le compteur, mais pas [au]
> lancement d'un exercice (avec le galet blanc). »

Compté dans le code : **sept vrais sites d'appel** (plus deux dans le banc).

| | où | quand | |
|---|---|---|---|
| 1 | `NosfyApp:2442` | après le film du Go — l'arrivée sur le lecteur | **GARDÉ** |
| 2 | `NosfyApp:913` | le même instant, décompte coupé (`-sansCount`, animations réduites) | **GARDÉ** — même événement, autre route |
| 3 | `NosfyApp:1102` | le galet play en séance → **retour** au lecteur | retiré |
| 4 | `NosfyApp:1497` | l'onglet Exercices en séance → **retour** au lecteur | retiré |
| 5 | `ExerciseDetailView:3188` | on ferme la fiche → **retour** au lecteur | retiré |
| 6 | `ExercisesView:822` | le chevron en séance → **retour** au lecteur | retiré |
| 7 | `PiluleVagabonde:2465` | **lancer un exercice** | retiré — c'est celui qu'elle nomme |

**La règle qui en sort, et qui tient toute seule :** *le passage joue UNE
fois par séance, à l'instant où la séance s'ouvre. Jamais sur un retour,
jamais sur un lancement.* Cinq des six retraits sont des **retours** — on
revient là où on était déjà, il n'y a rien à ouvrir. Le sixième, c'est le
sien.

*(Ma lecture de « l'arrivée par le compteur » : le Go, le décompte, puis le
lecteur — les sites 1 et 2. Aucun des sept ne se déclenche au départ d'une
série ; il n'y a donc pas d'autre candidat.)*

**Deux effets de bord, tous les deux bons :**

- **Ça supprime le risque de données que j'ai bouché hier.** Le site 7
  confiait `onChoisirExo(exo)` — l'ajout **réel** de l'exercice à la séance —
  à la coupe. Sans coupe, le geste s'exécute directement : plus de chien de
  garde à espérer, plus de geste en attente à honorer.
- **Ça divise la chauffe par sept** : six passages de 900 000 points en moins
  par séance.

⚠️ **Mais ça ne corrige PAS le §2.** Un passage qui se fige une fois par
séance est toujours un passage qui se fige. Retirer des sites d'appel est un
réglage, pas un correctif — les deux se font, dans cet ordre : le correctif
d'abord.

---

## 13. DÉFAUT — le calque orange derrière la tête du lecteur

> « fix ça, le calque orange derrière » (24-09, sur un agrandissement)

Trois rectangles orange : un autour du carré du jour, un derrière le nom de
l'exercice, un derrière « session · 15:16 ». **Deux causes, et il faut les
deux** — corriger une seule laisse le défaut.

### Cause 1 — le modificateur était appliqué TROIS FOIS

`teteLigne(...)` est un `@ViewBuilder`. Sa branche « tête en grand » rendait
**trois vues sœurs** (la ligne de la carte, le titre, le chrono), c'est-à-dire
un *tuple*. Or un modificateur posé sur un tuple est appliqué **à chacune de
ses vues** : le `.background { ChaleurTete() }` était donc dessiné trois fois,
chaque fois à la taille de sa propre vue. D'où trois taches, exactement aux
trois bounding boxes.

**Correctif** : la branche rend UNE vue (un `VStack`), avec l'espacement du
parent repris à l'identique (`10 - 5 * r`) — la tête ne bouge pas d'un point.

### Cause 2 — une lumière coupée net est un rectangle

`ChaleurTete` était un `RadialGradient` de rayon **210 pt** posé en fond d'une
vue qui n'en fait pas 420. Le dégradé n'atteignait donc **jamais** son
`.clear` : il était tranché au bord du cadre. Une lumière a une cause **et un
bord** — un bord droit n'en est pas un, c'est la loi.

**Correctif** : `EllipticalGradient` en **fractions** (`endRadiusFraction:
0.5`). Quelle que soit la taille du fond, il finit transparent avant d'y
toucher. Le défaut ne peut plus revenir par un changement de taille.

⚠️ **La chaleur reste** — elle est à sa demande du 23-09 (« des couleurs de
flamme braise dans le header quand je suis en séance »). Ce qui part, c'est le
rectangle. Son barreau, qui n'existait pas : `-sansChaleurTete`.

---

## 14. La deuxième passe du 24-09 — ses retours sur le lecteur

### Les deux états se ressemblaient

> « quand je clique sur ajouter, j'ai le mode réduit direct, pour faire une
> vraie distinction entre les deux états »

`basculer()` ne touchait pas au repli : on pouvait entrer dans « choisir »
avec la tête en grand, et les deux écrans se ressemblaient. Désormais la tête
**dit** dans quel état on est — grande en séance, réduite en choix — et le
chevron rend la grande. Le carré de zone, lui, **ne touche plus au repli** :
il ouvre et referme SA liste (son « je dois pouvoir revenir en arrière »),
sans jamais rouvrir la tête, sinon la distinction s'efface.

### ⚠️ Ce qui la troublait vraiment : le lecteur parlait une autre langue

> « si on a le bouton "ajouter un exercice", faut pas écrire HipThrust ? »

**Ce n'est pas une question de formulation, et je ne l'aurais pas vu sans la
capture.** Sur le même écran, l'app en anglais affichait :

| | |
|---|---|
| la tête | « Hip thrust à la machine » — `exercise.name`, le nom SOURCE, français |
| la rangée de la partition | « Machine hip thrust » — le nom localisé |
| le bouton, les carrés, la liste | « Ajouter un exercice », « Haut / Abdos / Bas », « Squat à la barre » — français en dur |

Le même exercice, **deux noms, deux langues, à dix points d'écart**. Tout le
lecteur (écrit les 22→24-09) a été tapé en français en dur, alors que la règle
de la maison est écrite noir sur blanc dans `Langue.swift` : **« un texte ne
naît jamais dans une seule langue »**.

**Corrigé** : `nomLocalise` partout (tête, pilule, rangées, carrés) et `L(fr,
en)` sur les textes du lecteur. La tête et la rangée disent maintenant le même
mot.

⚠️ **Ce qui RESTE en français seul** : le champ `muscle` du catalogue
(« Quadriceps et fessiers »), affiché sous chaque exercice. Il n'a aucune
table anglaise, et je n'invente pas 29 traductions d'anatomie sans qu'elle les
relise.

⚠️ **Et la question du titre reste ouverte** : faut-il écrire le nom de
l'exercice en cours dans la tête de séance ? C'est ce qu'elle a demandé le
05-09 (« l'exercice en cours, pour montrer que c'est en cours »), et
« Choisissez un exercice » à cette place était précisément le défaut qu'elle a
relevé le 22-09 (la tête mentait au-dessus d'une partition pleine). Je garde
donc le nom — mais c'est elle qui tranche.

### Le reste de sa liste

- **Le néon des carrés** : les cinq gardent leurs périodes désaccordées, et
  ont maintenant des **creux et des pics inégaux** (aucune n'a la même
  course). Au-delà de 1 l'opacité ne donne plus rien : la lumière vient d'une
  **seconde copie de la zone blanche, floutée de 4 px, posée dessous** — un
  bloom, jamais un trait plus épais. Sans `blendMode` : sur du noir, un blanc
  posé normalement est déjà de la lumière.
- **Le bouton** : il n'avait **aucun contour**, seulement ses particules — de
  loin il ne se lisait plus comme un bouton. Il a un cheveu d'un point, qui
  monte sous le doigt. Et au relâché, **deux anneaux naissent sur son contour
  et s'en éloignent** (la même langue que le pulsar du point), pendant que le
  bord flambe une demi-seconde.
- **Le halo de la carte du jour** : renforcé, et **en fractions** comme la
  chaleur de la tête — il respire sur 4,7 s quand elle respire sur 5,4, donc
  elles ne se rattrapent jamais.

---

## 15. ANALYSE — « je ne comprends pas le comportement »

> « dans la page avec Machine hip thrust, ajoute : Terminer (car il est
> ajouté ?) je comprends pas la différence, et on a "choisir un exercice",
> tu vois cette incohérence… et en pleine session avec le chrono et tout,
> pas de menu — mais on peut ouvrir la pastille, effectivement. Donc il faut
> juste mettre "En cours" et animer la police de l'exo en question. »
> **Ne code pas, analyse-la.**

### Ce que l'app fait aujourd'hui, lu dans le code

| écran | ce que la tête DIT | l'action offerte | comment on FINIT |
|---|---|---|---|
| home, séance en cours | — | « Choose an exercise » | le galet Stop |
| lecteur, état **séance** | le NOM de l'exercice | « Ajouter un exercice » | le galet Stop, en pied |
| lecteur, état **choisir** | « Choisissez un exercice » | les 5 carrés | le galet Stop, en pied |
| fiche de l'exercice | le nom, en grand | le compteur | le Stop, dans la dalle |
| fin d'une série (`RestartSheet`) | « Encore une série ? » | **Recommencer** · **Choisir un autre exercice** · ✕ | *rien* |

### Incohérence 1 — deux verbes pour un seul geste

Le bouton promet **« Ajouter »**, l'écran qui s'ouvre répond
**« Choisissez »**. C'est le même geste, et il change de mot en chemin. Le
titre devrait tenir la promesse du bouton : un seul verbe, partout.

C'est *exactement* ce qu'elle nomme par « on a choisir un exercice, tu vois
cette incohérence ». Ce n'est pas une préférence de style : quand deux mots
désignent une chose, on croit qu'il y en a deux.

### Incohérence 2 — le mot « Terminer » n'existe nulle part

C'est le vrai trou, et il est plus grave que la formulation.

- La **fiche** ne porte aucun mot de fin.
- Le **carrefour de fin de série** propose de *recommencer*, ou de *changer
  d'exercice*, ou de *fermer la pop-up*. **Jamais de finir.**
- Le **seul chemin** qui termine une séance est le galet Stop : un carré
  blanc dans un rond. Un objet qu'on apprend, pas un mot qu'on lit. Le mot
  « Terminer » n'apparaît qu'APRÈS, dans le panneau de pause.

Donc « je ne comprends pas la différence » est **juste, et c'est l'app qui a
tort** : elle sait finir une séance, elle ne le dit jamais. Et sur l'écran où
le travail est visible — la partition, « 01 Machine hip thrust, Set 1 » — la
seule action nommée invite à en AJOUTER un de plus.

### Incohérence 3 — la tête change de métier

À la même place, le titre **nomme** en séance (« Machine hip thrust ») et
**ordonne** en choix (« Choisissez un exercice »). Deux registres, un seul
emplacement : l'œil ne sait pas si cette ligne le renseigne ou lui demande
quelque chose.

**Sa proposition règle ça, et c'est la bonne.** La tête dit d'abord OÙ ON EST,
et le nom de l'exercice devient le sujet, en dessous :

```
        En cours                    ← l'état, petit, sobre
   Machine hip thrust               ← le sujet, et c'est LUI qui vit
        session · 28:20
```

⚠️ **Et ça remet le balayage à sa place.** Le 05-09 elle avait demandé
« l'exercice en cours avec un effet de balayage de lumière très Apple pour
montrer que c'est en cours ». Aujourd'hui ce balayage est sur le TITRE — donc
il passe aussi sur « Choisissez un exercice », où il ne veut rien dire.
Déplacé sur le nom, il redevient ce qu'elle avait demandé : la lumière dit
« celui-ci est en cours ».

### Ce que je propose — trois décisions, aucune codée

1. **Un seul verbe.** Le bouton et le titre de l'écran de choix disent le même
   mot. Je recommande **« Ajouter un exercice »** des deux côtés : c'est la
   vérité de ce qui se passe (une ligne s'ajoute à la séance). Séance vide, le
   bouton n'existe pas — le titre peut y rester une invitation.
2. **« Terminer » doit exister en mot**, sur l'écran de la séance, à côté
   d'« Ajouter un exercice ». Deux actions nommées, côte à côte : *j'en ajoute
   un* / *j'ai fini*.
   ⚠️ **Mais alors le galet Stop devient une deuxième porte pour la même
   chose**, et « le Stop ne bouge jamais du début à la fin d'une séance » est
   une loi de la maison depuis le 04-09. Il faut choisir : soit le mot
   remplace le galet DANS le lecteur (le galet reste partout ailleurs), soit
   les deux cohabitent et on l'assume. **Je ne tranche pas ça seul.**
   ⚠️ Et je ne mettrais PAS « Terminer » dans le carrefour de fin de série :
   proposer d'arrêter après chaque série, c'est suggérer d'arrêter.
3. **La tête en deux lignes** : « En cours » + le nom, le balayage sur le nom.

### Ce que je n'ai pas tranché dans sa phrase

« ajoute : Terminer (car il est ajouté ?) » — je l'ai lue comme *« sur l'écran
de séance, il manque le mot Terminer à côté d'Ajouter »*. L'autre lecture
serait *« le bouton devrait dire Terminer au lieu d'Ajouter, puisque
l'exercice est déjà ajouté »* — mais alors on ne pourrait plus en ajouter un
second, et la séance à plusieurs exercices n'existerait plus. C'est pour ça
que je retiens la première.

---

## 16. Ce qui a été décidé et posé — la troisième passe

> « la logique sera donc de ne pas avoir Machine hip thrust mais l'état : Add
> an exercise même si redondance, ou En cours — et highlighter aussi l'exo en
> cours et le set en cours, pour avoir consistance… et il faut le même
> dégradé de texte »
> « trop de texte, faut choisir, faut faire comme Apple »

**La tête dit l'ÉTAT, la partition dit le SUJET.** C'est la réponse à la
question restée ouverte au §15, et elle est meilleure que les deux que
j'avais proposées :

| | avant | après |
|---|---|---|
| tête, en séance | « Machine hip thrust » | **« En cours »** |
| tête, en choix | « Choisissez un exercice » | **« Ajouter un exercice »** |
| deuxième ligne | « session · 56:52 » | inchangée |
| le nom de l'exercice | en tête ET dans la partition | **dans la partition seule, en blanc plein** |

Les deux écrans portent maintenant **la même ligne, au même endroit, avec le
même dégradé qui la traverse** — c'est sa « consistance ».

⚠️ **Et j'ai enlevé une ligne, pas ajouté.** La tête a porté un instant
« EN COURS » *au-dessus* du nom *au-dessus* de « session · 56:52 » : trois
lignes dont deux disaient la même chose. Il en reste deux.

**Dans la partition**, l'exercice en cours prend sa lame d'argent **même
replié**, son numéro passe à 0,92 et son nom au **blanc plein** ; les autres
descendent à 0,46. C'est l'ÉCART qui désigne — pas un fond, pas un cadre, pas
une couleur. (La série en cours, elle, avait déjà son cheveu blanc depuis le
23-09.)

**Le carré de catégorie choisi** : bordure en **dégradé** (vive en haut à
gauche, éteinte en bas à droite — une source fixe, jamais un anneau qui
tourne), un **ressort** à la sélection, et deux poids d'haptique : franc
quand on ouvre une zone, léger quand on la referme.

**Le galet Stop porte enfin son mot** — « Terminer », posé dessous. Il ne
crée pas une deuxième porte : il étiquette celle qui existait.

### ⚠️ L'ÉTAT DU MILIEU, qui manquait

> « il manque un état quand je dois comprendre que j'ai terminé un exercice
> et que je dois en ajouter un »

Il y avait **« En cours »** et **« Ajouter un exercice »**. Entre les deux,
rien ne disait que l'exercice était **fini**. La tête est donc à trois états :

| | quand | ce que la tête dit |
|---|---|---|
| 1 | il reste une série à faire | **En cours** |
| 2 | plus aucune série en attente | **Exercice terminé** |
| 3 | l'écran de choix | **Ajouter un exercice** |

⚠️ **Et l'état 2 ne s'invente pas — il se LIT.** Un exercice est fini quand il
ne lui reste aucune série en attente : c'est exactement la vérité qui fait
déjà vivre le cheveu blanc de la série en cours depuis le 23-09 (il ne
désigne plus rien quand tout est fait). Aucun drapeau nouveau, aucune donnée
à tenir à jour — donc rien qui puisse diverger un jour.

**Et l'app montre la suite du doigt.** Au moment où l'exercice se termine, le
bouton « Ajouter un exercice » joue **son onde** — celle du tap, deux anneaux
qui naissent sur son contour. L'app fait le geste qu'elle attend.
⚠️ Posé en `task(id:)` et pas en `onChange` : le bouton peut naître DÉJÀ dans
l'état terminé (elle revient de la fiche, la vue se monte), et un `onChange`
ne voit jamais la valeur d'arrivée — l'invitation serait partie une fois sur
deux, ce qui est pire que jamais.

---

## 10. Ce que ça coûte, et ce qu'il faut mesurer

**Tout ce plan tient en opacités, échelles, décalages et rotations.** Aucune
`TimelineView`, aucun `Canvas` par image, aucun shader. C'est la seule
architecture qui passe la loi du 05-09.

⚠️ **MAIS il y a un vrai sujet, et je ne veux pas le cacher** : hier soir,
l'app ne portait aucune animation permanente sur le lecteur. Après ce plan,
elle en porterait **douze en même temps** — un point, deux anneaux, sept
paillettes, un carré, un sticker, cinq carrés de zones — et toutes **pendant
toute la séance**, pas pendant 1,5 seconde.

Même une animation « gratuite » entretient le graphe SwiftUI (le piège E55
du registre). **Douze horloges qui ne s'arrêtent jamais, ça se mesure avant
de le garder, pas après.**

**Les barreaux à poser avec, un par famille** : le point (et son pulsar et
ses paillettes), le flottement, le souffle des zones. Sans quoi on ne pourra
ni les accuser ni les disculper.

**La campagne à faire, sur SON téléphone, thermique lu à 0 au départ** :
lecteur immobile, tout éteint · lecteur avec le point seul · lecteur avec le
flottement · lecteur avec les zones · lecteur complet. Cinq balades, un
moteur à la fois — deux changements dans une balade, c'est une balade perdue.

---

## 11. Ce qui n'est PAS dans ce plan

- **Rien n'est codé, et aucun banc n'est écrit.** Elle a demandé un plan.
- Le diamant n'est pas « retravaillé » : il est supprimé.
- Je ne touche pas à la trajectoire ni aux couleurs de l'ouverture : seulement
  à sa FIN (§2, un défaut) et à la finesse de son grain (§3bis).
- Je ne touche pas au bouton « Ajouter un exercice » ni à son bord : elle
  n'en a pas parlé.
- **Aucune chauffe n'est mesurée à ce jour**, sur rien de ce qui a été posé
  les 23 et 24-09.

## 12. L'ordre que je propose

1. **Le calque fantôme** (§2) — on ne pose rien sur un écran sale, et sa
   capture montre que c'est plus qu'un détail.
2. **Une fois par séance** (§9) — six sites en moins, donc six occasions de
   moins de voir le défaut, et la chauffe divisée d'autant.
3. **Une seule porte vers les exercices** (§8) — c'est de la navigation
   cassée, pas de la décoration : ça passe avant le beau.
4. **Le point blanc** (§4) et **sa place** (§7) — ensemble, c'est le même
   composant qu'on réécrit une seule fois.
5. **Le grain plus fin** (§3bis) — petit changement, à montrer tout de suite.
6. **Les carrés de catégories** (§6) — le sujet qui compte vraiment : « ça ne
   donne pas envie de choisir ».
7. **Le flottement** (§5) — le plus petit, le plus sûr.
8. **La campagne de chauffe** (§10) — avant de garder quoi que ce soit.

**Ce qu'il me faut d'elle avant de commencer** — plus une décision, trois
captures de son téléphone, en séance : le **compteur**, la **fiche d'un
exercice**, et le **catalogue**. Elles disent si le bas de l'écran est libre,
et donc si le point peut vraiment vivre au même endroit partout (§7). Le
reste, je peux le faire sans rien demander.
