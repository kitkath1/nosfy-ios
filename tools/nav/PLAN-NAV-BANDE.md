# LA NAV DU BAS — plan, et les onze pièges mesurés AVANT de coder

**État : ANALYSÉ, RIEN CODÉ.** Demandé par Kathryn le 01-09, analysé et
contre-vérifié le 02-09. Aucune ligne de Swift n'a été écrite pour ce chantier.

Ce document existe pour une seule raison : **une première analyse a été faite, et
six de ses six affirmations étaient fausses ou gravement incomplètes.** Elles ont
été démolies une par une avant d'atteindre le code. Ce qui suit est ce qui reste
debout, avec la preuve `fichier:ligne` de chaque point.

> ⚠️ Tout ce qui est écrit ici a été LU dans le code, pas déduit. Quand un
> commentaire du dépôt contredit le code, c'est le code qui fait foi — et
> plusieurs commentaires mentent (voir §6).

---

## §0 · CE QU'ELLE VEUT

1. Les quatre pages **toujours relevées** — le même espace noir en bas que
   pendant une séance, en permanence, pas seulement en séance.
2. Une **nav permanente** dans cet espace, qui **se réduit en points** pour
   alléger (déclenchée au drag, tranché le 02-09).
3. Le **slider de départ dans la card**, à ~12 pt de son bord bas — pas du bord
   de l'écran (il est cassé aujourd'hui, voir §7).
4. Un **morphing** où le player vient au-dessus de la nav.
5. L'**overlay du player** et l'**égalité des cotes** entre pages : intouchables.
6. Ça ne doit **pas prendre de hauteur**, surtout sur un iPhone SE.

**Trois lois posées par elle le 02-09, non négociables :**

- la nav **n'apparaît jamais pendant l'exercice en cours**, du galet blanc
  jusqu'à la fin du repos ;
- **ni au coffre, ni au profil** ;
- **QUATRE points** — corrigé par Kathryn le 02-09 : « la carte descend et on
  voit les **4 points** ». Une version antérieure de ce plan déduisait trois
  destinations du fait que le profil sort de la nav ; c'était une déduction, pas
  sa demande. Le code a bien quatre onglets (`WoopTab` = home, exercises,
  progress, profile — `WoopApp.swift:121`). ⚠️ Reste à réconcilier : **le profil
  est un point de la nav, mais la nav ne s'affiche pas SUR la page profil** —
  les deux ne sont pas contradictoires, mais il faut le dire explicitement.

## §0bis · LA MÉCANIQUE DU MINI, dictée le 02-09

Trois phrases d'elle, mot pour mot, et ce qu'elles imposent :

### « la mini nav en mode point ALLONGE la card »

**Ses mots, le 02-09 :** « la mini nav en mode point allonge la card — si je
drag légèrement au niveau de la nav, la card descend et ils deviennent des
points ».

⚠️ **Ne pas se tromper là-dessus, je m'y suis trompé deux fois.** Ce n'est pas
la nav qui rétrécit sur place, et ce n'est pas non plus la card qui glisse à
l'`offset` en gardant sa taille. **La card GAGNE VRAIMENT LA HAUTEUR** que la nav
libère : son bord bas descend, elle est plus longue. C'est un changement de
LAYOUT, assumé et voulu.

Le geste et le résultat sont une seule chose : **un drag léger au niveau de la
nav → la card s'allonge vers le bas, les glyphes deviennent des points.**

#### La réconciliation avec §3 — et elle existe

Le §3 dit qu'un repli qui fait grandir la card de 52 pt **en continu sous le
doigt** re-layoute les quatre pages à chaque image et déplace la molette, le
dôme, la pill `AVPlayerLayer` et le galet du menu. Cela reste vrai.

Mais la conclusion n'est pas « c'est interdit » : c'est **« pas en continu »**.

> **Pendant le geste, on suit le doigt SANS re-layouter ; à la fin du geste, on
> commet la hauteur EN UNE FOIS.**

Concrètement, deux régimes bien séparés :

1. **Sous le doigt** — la card ne change pas de hauteur. Le suivi est un
   `.offset` + un masque : les pixels descendent, la mise en page ne bouge pas.
   C'est l'école déjà payée (« il découpe, il ne réduit pas »,
   `ExercisesView.swift:286-297`).
2. **Au relâcher** — on commet une valeur **DISCRÈTE et PARTAGÉE** par les
   quatre pages, animée en 0,25 s. Le layout change **une seule fois**.

👉 **Ce régime existe déjà et il est éprouvé** : c'est exactement ce que fait
`bandeVisible` aujourd'hui (`PageCard.swift:184-185`, avec son
`.animation(.easeInOut(duration: 0.25))`). Quand le clavier sort sur Exercices,
la card gagne déjà 78 pt d'un coup, proprement. **La mini nav est un troisième
régime de la même mécanique**, pas une invention.

#### Ce que le changement discret déplace — un verdict par objet

Même commis une seule fois, les 52 pt font voyager quatre objets. Chacun demande
son verdict au doigt, pas une déduction :

| Objet | Où | Ce qu'il faut vérifier |
|---|---|---|
| La molette d'Exercices | `ExercisesView.swift:2138-2154` | `knobLift = 78` garde 34 pt d'air sous le verre — à recoter |
| Le dôme du galet (fiche) | `ExerciseDetailView.swift:795-801` | `.overlay(alignment: .bottom)` : son bas EST le bas de card |
| La pill vidéo de Progress | `ProgressPage.swift:239-250` | un `padding` sur un `AVPlayerLayer` — le lag déjà écrit |
| Le galet du menu (home) | `MenuNappe.swift:1418` | `.padding(.bottom, 24)`, la cote du bug des 17 pt |

⚠️ Et le piège de `39f95f9` s'applique au suivi : **les pixels et le hit-test
sont deux choses.** Pendant la phase 1, ce qui descend par `offset` continue de
manger les touchers à son ancienne place — `allowsHitTesting(false)` sur ce qui
a quitté sa place, ou la forme tactile portée avec l'offset.

### QUATRE états de bande, pas trois — et le drag marche dans les DEUX contextes

**Précisé le 03-09 :** « nav par défaut : je peux drag, ça transforme en mini nav
(avec animation, et inversement). Pareil quand il y a le player : je peux passer
de **player + nav** à **player + mini nav**. »

J'avais manqué l'état **player + nav**. Le repli n'est pas réservé au repos :
c'est le même geste, disponible dans les deux contextes.

| État | Contenu de la bande | `dockH` | Bande |
|---|---|---|---|
| nav | la nav seule | 76 | **78** |
| mini nav | les 4 points | 24 | **26** |
| player + nav | dalle 76 **sur** nav 78 | 154 | **156** |
| player + mini nav | dalle 76 **sur** points 26 | 100 | **102** |

⚠️ **Le chiffre qui inquiète : 156 pt.** Sur un iPhone SE (667 pt), l'état
« player + nav » mangerait **23 % de l'écran**. C'est exactement la crainte du
§0.6 (« ça ne doit pas prendre de hauteur, surtout sur un SE »). Deux issues
possibles, à trancher : soit l'état « player + nav » n'existe pas sur petit écran
(on naît directement en « player + mini nav »), soit la dalle maigrit quand la
nav est déployée. **À mesurer avant de choisir.**

### « et plus fluide »

Demandé le 03-09. Le dépôt a **déjà payé cette question** sur le player, et le
résultat a été validé par elle (« plus fluide de fou », commit `6141653`). La
recette est donc à reprendre, pas à réinventer — elle est extraite en §4bis.

### « le player va au-dessus, pas en dessous »

Le morphing : quand une séance tourne, la dalle du player **passe PAR-DESSUS** la
nav — elle ne se range pas à côté d'elle ni en dessous. La nav reste là, sous
lui, réduite en points.

### « au léger drag elle se relève »

Le retour est un geste **léger** — pas la même course que le repli. À mesurer au
doigt : la remontée doit demander moins d'engagement que la descente, sinon on se
retrouve enfermé dans l'état mini.

### « attention à l'overlay pour ces gestions »

C'est le §2 ⚠️ 4 de ce document : la garde du PanMaitre est
`PlayerEtat.shared.ouvert`, une **intention** posée 0,68 s avant l'écran à
l'ouverture et retirée 0,68 s avant l'écran à la fermeture. Pendant ces deux
fenêtres, l'overlay et les gestes sont désalignés — et c'est exactement là que
« le player au-dessus » et « la nav qui se relève au drag » vont se croiser.
**Remède : trois états (fermé / en vol / ouvert), pas un booléen.**

---

## §1 · LA CONCLUSION

**Tout est faisable, mais pas dans la bande de `PageCard`.**

La bande de 78 pt n'est pas le bon logement, pour trois raisons de code et non
de goût :

1. **Elle n'existe pas hors séance.** `PageCard` ne construit la bande que sous
   `if enSeance, bandeVisible` ; hors séance la card descend au bord PHYSIQUE
   (`hPage = Hs + safeBottom`). Une nav « permanente » n'y a aucune place
   réservée. — `PageCard.swift:78, 103-112`
2. **Elle disparaît en pleine séance.** La fiche coupe la bande entière dès
   `flood ≥ 0,01` ou `running != nil` ; Exercices la coupe quand le clavier sort.
   — `ExerciseDetailView.swift:607-617`, `ExercisesView.swift:471`
3. **Son geste appartient déjà à la dalle.** Voir §2, piège n°1.

Et le Profil n'utilise pas `PageCard` du tout : la nav y disparaîtrait.
— `WoopApp.swift:1096-1101`

### L'architecture qui survit à tous les pièges

**UNE réserve unique, au châssis, de hauteur CONSTANTE.**

- Un `safeAreaInset(edge: .bottom)` au châssis, réservé **une fois** à sa hauteur
  maximale. Il raccourcit les quatre pages **en permanence** — c'est exactement
  « les pages toujours relevées » du §0.1, obtenu sans toucher à `PageCard`.
- **La nav vit dedans.** Le repli en points est **purement graphique** : masque
  et offset à l'intérieur d'une réserve qui ne bouge jamais. Jamais un `padding`
  ni un `frame` animé.
- **L'état du repli vit dans un observable partagé** (le patron de
  `PlayerEtat.shared`), jamais dans un `@State` de vue — il y a quatre instances
  de `PageCard`, donc quatre `@State` distincts, donc quatre hauteurs.
- **Le player** : soit sa dalle partage la réserve en largeur avec la nav
  repliée, soit il devient la pastille flottante et la réserve ne porte que la
  nav. Dans les deux cas la réserve garde la même hauteur.

**La règle en une phrase : la réserve est constante, la nav bouge dedans.**

---

## §2 · LES SIX AFFIRMATIONS DÉMOLIES

Chacune paraissait raisonnable. Chacune aurait produit un bug.

### ❌ 1. « La direction du drag tranche : haut = player, bas = nav »

**FAUX, bloquant.** La dalle porte `.contentShape(Rectangle())` sur 76 des 78 pt
de la bande, et son `DragGesture(minimumDistance: 3)` reconnaît sur la **norme**
— haut, bas et latéral, sans aucun filtre de signe.
— `PageCard.swift:149-166`

Un geste enfant bat un geste d'ancêtre : une nav posée sur la bande **ne
recevrait jamais un `onChanged`**, sauf sur les 2 pt de marge. Symptôme :
« ça marche une fois sur vingt ».

Pire : chaque tentative appelle `saisir()`, qui pose `monte = true` et
`couvre = true` — donc **monte tout l'arbre du player** (le piège du « rideau »,
payé le 30-08) et **met les vidéos de fond à rate 0**. Le fond de la page se fige
à chaque doigt qui traîne de 3 pt sur la bande.
— `PlayerMonde.swift:165-179, 192-208`

### ❌ 2. « La prise de la lune ne réagit qu'au drag vers le haut »

**FAUX, bloquant.** `max(0, -v.translation.height / course)` clampe la **valeur**,
pas la **reconnaissance**. Le `DragGesture(minimumDistance: 4)` s'active à 4 pt
dans n'importe quelle direction et possède alors la séquence de touchers.
— `PageCard.swift:217-224`

C'est le pire cas possible : `levee` reste à 0, donc **aucun retour visuel**. Le
toucher est mangé en silence. Et la prise étant le dernier enfant du `ZStack`,
elle occulte le hit-test de tout ce qui est dessous.

Sur Exercices, Progress et la fiche hors séance, une nav placée là serait morte,
sans le moindre indice au débogage. Symptôme : « la nav ne réagit pas, mais
seulement en bas, mais pas sur la home » (la home est exemptée par
`luneAuDrag: false`).

### ❌ 3. « Le voile clignoterait si un geste écrivait `p` par erreur »

**FAUX, sérieux.** Le voile est clampé À LA SOURCE :
`Color.black.opacity(0.55 * min(max(etat.p, 0), 1))`.
— `PlayerMonde.swift:907-908`

La butée basse écrit bien `p ∈ [−0,05 ; 0[`, mais l'opacité vaut alors
rigoureusement 0. **Le voile est aveugle** : il ne peut servir de détecteur, dans
aucun des deux sens. On aurait testé, rien vu, conclu « pas de conflit », et
commité — pendant que tout l'arbre du player se montait à chaque geste.

👉 **Le vrai détecteur** est la sonde `-gesteSonde`, qui imprime chaque prise et
chaque commit (`GESTE-SONDE player SAISIR`, `COMMETTRE`, `maitre LAISSE`,
`maitre PREND`). — `PlayerMonde.swift:175-177, 238-241, 694-708`

### ⚠️ 4. « Le PanMaitre ne reçoit que lorsque le player est ouvert »

**NUANCÉ, sérieux.** Sa seule garde est `PlayerEtat.shared.ouvert`, qui est une
**intention** posée AVANT le vol, pas un état de l'écran.
— `PlayerMonde.swift:57-70, 735-739`

Il est donc désaligné de ce qui est affiché **pendant 0,68 s à chaque
ouverture et à chaque fermeture** :

- **au vol d'ouverture** : il reçoit déjà alors que la nav est encore pleinement
  visible ; et `shouldRecognizeSimultaneouslyWith` renvoie `true` **sans
  condition** (`:730-733`) — donc la nav ET le player bougent au même doigt, et
  les boutons de la bande se font annuler par `touchesCancelled` ;
- **au vol de fermeture** : l'inverse, le toucher traverse le player encore
  visible jusqu'à la nav.

### ⚠️ 5. « Les glyphes ne peuvent pas être des `Button` (annulés à 2 pt) »

**NUANCÉ, sérieux.** La conclusion est bonne, la raison est fausse, et la forme
de remplacement n'était pas dite.

Le danger n'est **pas un seuil** : un `Button` est annulé dès qu'un recognizer
simultané d'ancêtre reconnaît, à 2 pt comme à 8. Monter `minimumDistance` ne
répare rien.

**La forme tranchée dans ce dépôt** est :
`.contentShape(<forme>)` + zone de doigt portée à 44 pt AVANT le geste +
`.highPriorityGesture(TapGesture().onEnded { … })`.
— `WorkoutPill.swift:79-84` et `:529-541`

⚠️ Le `.onTapGesture` de `PageCard:153` **n'est pas le précédent à copier** : il
est posé sur la même vue que le drag, pas sur un descendant, et il ne survit que
grâce au `minimumDistance: 3`.

### ⚠️ 6. « Le tiroir de la home volera le drag de la nav »

**NUANCÉ — l'accusation est fausse.** Le `tirageGeste` est bien un drag
page-large à 2 pt (`HomeNuit.swift:3500`), mais il est attaché **DANS** le slot
`page:`, sur `MenuHote` (`HomeNuit.swift:2706`). Il n'est donc **pas un ancêtre
de la bande** : la bande est un frère, monté après par `PageCard`.

Mais deux choses restent vraies :

- les **trous entre les points** de la nav repliée seraient au tiroir si la nav
  ne déclare pas un `.contentShape(Rectangle())` sur **toute** la bande, pleine
  largeur ;
- « réparer » ce vol inexistant casserait le pull, dont la fluidité a été payée
  en mesures (36,8 → 60,1 img/s). La loi du dépôt : **on démonte un geste, on ne
  remonte pas son seuil**. — `HomeNuit.swift:2704`

### ✅ Deux griefs ÉCARTÉS — les sceptiques ont dépassé, eux aussi

Par honnêteté de méthode : la contre-vérification a rejeté deux de ses propres
accusations, faute de preuve.

- **« Double geste nav + player pendant le vol d'ouverture »** — écarté : le
  voile est déjà bouclier dans ce sens (`PlayerMonde.swift:342-343`). Seul le
  player bouge. Le symptôme réel est plus étroit : le player fait le yoyo, la nav
  ne bouge pas.
- **« Ressort fantôme de la lune »** (le chien à 0,35 s) — écarté : un
  `withAnimation` sur une valeur déjà à 0 ne coûte rien de visible.

👉 La règle de la maison s'applique aux sceptiques comme au reste : **un juge qui
affirme ne remplace pas une sonde qui mesure.**

---

## §2bis · LES PIÈGES QUE PERSONNE N'AVAIT VUS

### Hors séance, six objets occupent déjà cet espace

Hors séance la page va au **bord physique** (`hPage = Hs + safeBottom`, padding
bas zéro) : il n'y a pas de bande, et six objets vivent là.

> ⚠️ **CES COTES SONT PÉRIMÉES — À RE-MESURER.** Elles ont été relevées avant le
> commit `d2d504a → 693f0ee` de la session home, qui a corrigé
> `.frame(width: W, height: Hs, alignment: .bottom)` dans `PageCard.swift`.
> Hors séance, le plus grand enfant du `ZStack` fait `Hs + safeBottom` : une
> frame de hauteur `Hs` CENTRAIT le dépassement, donc la card débordait de
> `safeBottom / 2` = **17 pt en haut ET en bas**. Après correction, **les six
> objets ci-dessous ont remonté de 17 pt**, et cela vaut pour les **quatre**
> pages, pas seulement la home. Le galet du menu est passé de 7 pt d'air à
> 24,0 (mesuré iPhone 15). Ne recote rien d'après ce tableau : re-mesure.

Cotes relevées **avant** ce commit, au-dessus du bord physique :

| Objet | Occupe | Où |
|---|---|---|
| Le slider de départ | 10 → 72 | `HomeNuit.swift:2914-2938` |
| La poignée du pull | 0 → 112 | `HomeNuit.swift:3500` |
| Le galet du menu | 24 → 86 | `MenuNappe.swift:1418` |
| Le bouton cardio (fiche) | 0 → 82 | `ExerciseDetailView.swift` |
| Le galet / dôme de la fiche | 0 → 160 | `ExerciseDetailView.swift:795-801` |
| La prise basse d'Exercices | 0 → 156 | `ExercisesView.swift` |

**À trancher avant la première ligne :** soit la nav ne vit qu'en séance (aucun
de ces six ne bouge), soit les quatre pages cèdent la bande hors séance aussi —
et alors ces six objets remontent **un par un, avec un verdict chacun**.

### `bandeVisible` est piloté par des états ÉTRANGERS — la nav clignoterait

- Sur Exercices, ouvrir la recherche fait sortir le clavier → `bandeVisible`
  passe à false → **la nav disparaît**, la card se rallongeant par-dessus en
  0,25 s. — `ExercisesView.swift:471`
- Sur la fiche, `flood` monte **dès `driveMoved`** — au premier point du doigt
  sur le galet. La nav s'éteint avant même que tu aies décidé de démarrer.
  — `ExerciseDetailView.swift:613`

**Une nav qui clignote n'est pas une nav.** C'est l'argument le plus fort pour la
sortir de `PageCard` : `bandeVisible` gouverne **la dalle du player** (son cas
§2.17 d'origine), pas une barre de navigation.

### Les 18 pt sous la zone sûre, et l'absence de filet

La bande **dessinée** fait 96 pt et occupe **16 → 112** au-dessus du bord
physique — les 78 sont seulement ce que la *card cède*. Ses 18 derniers points
sortent du cadre de leur `ZStack` par le `.offset(y: descente)`.

Et `.defersSystemGestures(on: .bottom)` n'existe **que sur la home**
(`HomeNuit.swift:2450`) : sur Exercices, Progress et la fiche, un glissement bas
peut partir à la Reachability du système.

👉 **Ne coter aucune cible de nav sous 34 pt du bord physique**, et mesurer avec
`-hitSonde` (`PlayerMonde.swift:874-893`) avant de coter — jamais déduire.

### ⚠️ CE QUI CHANGE PAR IMAGE *DANS* LA CARD PAIE LA VIDÉO ET LE VERRE

**Loi payée par la session home le 02-09** (`tools/home-v2/ANALYSE-HOME-VIVANTE.md`,
§FLUIDITÉ), et c'est la plus chère de ce document parce qu'elle a coûté quatre
remèdes ratés.

Son contour de séance n'était **pas cher à dessiner**. Il **invalidait la card à
chaque image** — et cette card porte une vidéo vivante et trois panneaux de verre
natif. Les quatre remèdes tentés (moins de flous, moins de couches, un shader
une-passe, des foyers à opacité fixe) **ont tous échoué de la même façon** :

> **Tout ce qui change par image DANS la composition de cette card paie la vidéo
> et le verre avec lui.** Ce n'est pas le coût du dessin, c'est l'invalidation.

**Conséquence directe pour la nav** — son repli anime une opacité et des `offset`
à la cadence de l'écran. Deux règles en découlent :

1. **La nav doit rester un FRÈRE de `pageEnCard`, jamais un enfant.** C'est déjà
   le cas de la bande dans `PageCard` (le `ZStack` monte `pageEnCard` et `bande`
   côte à côte, `PageCard.swift:81-112`) — c'est la bonne place, et il ne faut
   pas la quitter.
2. **L'état du repli doit réveiller la nav SEULE.** Un `@Observable` partagé le
   garantit — l'Observation ne réveille que la vue qui LIT la propriété touchée.
   Un `@State` remonté chez un hôte commun réveillerait toute la page, et on
   repaierait la vidéo et le verre à chaque image du geste.

⚠️ **À MESURER SUR LE TÉLÉPHONE avant tout verdict**, pas au simulateur : la même
session mesure 18,7 puis 5,6 img/s sur le même binaire à quelques minutes
d'écart, machine calme. Le simulateur n'est pas un instrument sur cette page.

**Préavis reçu** : la signature de `PageCard` ne bougera pas, mais ses internes
peut-être (l'overlay du contour pourrait sortir de `pageEnCard` pour devenir un
frère découpé à la forme de la robe). Le slot `dalle:` et la géométrie ne
changent pas. Le drapeau **`-sansBord`** éteint le contour pour juger une card
nue, ou pour bisecter un coût.

### Le voile du tuto d'Exercices mange les taps

Au premier lancement, `overlayPreferenceValue` est posé **SUR** `PageCard`, donc
au-dessus de la bande : un tap sur un onglet éteint le tuto au lieu de naviguer.
Invisible à toute lecture de la bande. — `ExercisesView.swift:476-478, 1134-1143`

Même contrôle à faire pour les trois autres couches qui vivent au-dessus de
`PageCard` : le monde flottant de la fiche (`ExerciseDetailView.swift:622`), la
story de Progress, et les hôtes du châssis.

---

## §3 · LA GÉOMÉTRIE — pourquoi le repli ne doit RIEN re-layouter

### La formule, vérifiée

```
bandeH = grabH(18) + dockH(76) + 2 − descente(18) = 78
hPage  = enSeance ? Hs : Hs + safeBottom
card   = hPage − (bandeVisible && enSeance ? bandeH : 0)
```

`grabH`, `descente` et le « +2 » sont des `private var` **en dur, sans paramètre
d'init** : le seul levier est `dockH`. — `PageCard.swift:36, 58, 62, 65`

### Le fait qui commande tout

**`bandeH` n'a qu'UN consommateur dans tout le fichier, et c'est un modifier de
LAYOUT** : `.padding(.bottom, bandeVisible && enSeance ? bandeH : 0)`.
— `PageCard.swift:184`

La hauteur de card est donc une **fonction affine de `bandeH`, de pente 1**. Et
le bas de la card et le haut de la bande dessinée sont **la même expression** —
ils sont soudés par construction.

**Conséquence : une nav qui se réduit de 78 à 26 pt fait grandir la card de
52 pt, en continu sous le doigt.**

### Ce que ces 52 pt déplaceraient — tout ce qui a déjà coûté des bugs

| Ce qui bouge | Où | Pourquoi c'est grave |
|---|---|---|
| La molette d'Exercices | `ExercisesView.swift:711-716, 2138-2154` | `knobLift = 78` est calculé « pour garder 34 pt d'air sous le verre ». Elle finirait dans la home-bar. Son `ArcSmoke` (Metal) se recompose à chaque image. |
| Le dôme du galet (fiche) | `ExerciseDetailView.swift:795-801` | `.overlay(alignment: .bottom)` : son bas EST le bas de la card. Et la fiche aurait **trois** hauteurs (681 → 733 au drag, puis 759 au galet enclenché). |
| La pill vidéo de Progress | `ProgressPage.swift:239-250` | Positionnée par un **`padding` sur un `AVPlayerLayer`**. La loi est déjà écrite dans le dépôt : c'est ça qui « laggue quand on drag la card ». |
| Le galet du menu de la home | `MenuNappe.swift:1418` | `.padding(.bottom, 24)` : la cote **exacte** du bug des 17 pt réparé le 02-09. |

### Les deux pièges de cotes en prime

- **Quatre instances de `PageCard`** (une par page). L'égalité actuelle tient
  uniquement au défaut d'init `dockH = 76` — ce n'est **pas un contrat**. Un
  repli piloté par un `@State` local donnerait **quatre hauteurs différentes**,
  et aucun outil du dépôt ne le signalerait.
- **À 26 pt, la dalle est écrasée** : `dockH` tomberait à 24, or `WorkoutPill` a
  22 pt de padding interne et un `hauteurDock = 76` **en dur** que personne ne
  passe. Il resterait 2 pt pour le titre et le chrono.
  — `WorkoutPill.swift:165-168, 258-262`

### Les états où les quatre pages divergent DÉJÀ

Il existe aujourd'hui **trois** bas de card distincts, pas un :

| Bas de card | Quand | Pages |
|---|---|---|
| 0 pt (bord physique) | hors séance | les 4 |
| 34 pt | en séance + bande cachée | fiche (galet/série), exos (clavier) |
| 112 pt | en séance + bande visible | les 4 |

---

## §4 · LES RÈGLES À TENIR

1. **La réserve est constante.** Le repli ne traverse jamais
   `.padding(.bottom, …)`. La réserve garde sa hauteur maximale, toujours.
2. **Le repli est graphique.** Masque + offset, ou `scaleEffect(anchor: .bottom)`
   — l'école déjà payée : « **il découpe, il ne réduit pas** »
   (`ExercisesView.swift:286-297`) et « `offset` et non un inset animé : la place
   est déjà réservée, rien ne re-layoute » (`WoopApp.swift:1144`).
3. **L'état vit dans un observable partagé**, jamais un `@State` de vue.
4. **La forme tactile se déclare AVANT l'offset** de la bande — sinon 18 pt
   d'écart entre les pixels et la zone prenante (`PageCard.swift:103-105`
   vs `:149`). Piège déjà payé au commit `39f95f9`.
5. **Elle couvre toute la largeur**, pas seulement sous les glyphes.
6. **Les glyphes ne sont pas des `Button`** : `contentShape` + 44 pt +
   `highPriorityGesture(TapGesture())`.
   ⚠️ **`highPriorityGesture` ne bat que les ANCÊTRES.** Un frère dessiné
   par-dessus éteint sans recours. — `HomeNuit.swift:3428-3436`
7. **Chien de garde obligatoire** : un `DragGesture` peut mourir sans `onEnded`.
   Le dépôt le fait déjà pour la lune (`armerChien`) et pour le player
   (`armerChienSuivi`, 0,45 s).
8. **Aucun accès à `p`.** La nav et le player sont deux états, deux moteurs,
   zéro passerelle. Et le voile ne le montrera JAMAIS (clamp
   `PlayerMonde.swift:908`) : les deux seuls détecteurs valides sont
   **`-gesteSonde`** et **le figeage de la vidéo de fond**.
9. **Un seul propriétaire du geste, et il est UIKit.** Un pan maître **de bande**
   (patron `PlayerMonde.swift:646-789`, mais posé sur la bande et non sur la
   fenêtre) décide à la première frame nette (≥ 6 pt) et route : haut →
   `PlayerEtat.suivreDelta`, bas → la nav, latéral → la sélection d'onglet. La
   dalle, la prise lune et la nav ne portent plus de `DragGesture` concurrent.
   **Deux recognizers dans 96 pt, c'est un bug, pas un arbitrage.**
   Un refus dans `onChanged` (un `guard`, un `max(0, …)`) **ne rend jamais un
   toucher déjà consommé** : le seul endroit où l'on refuse AVANT de prendre le
   doigt est un `gestureRecognizerShouldBegin` UIKit qui lit la vélocité.
10. **Trois états, pas un booléen.** `ouvert` est une intention, désalignée de
    l'écran 0,68 s dans les deux sens. Il faut **fermé / en vol / ouvert** : la
    nav ne prend le doigt que sur « fermé », le PanMaitre que sur « ouvert »,
    personne pendant les vols. Le voile reste bouclier tant que `p > 0,02`, pas
    tant que `ouvert`.
    ⚠️ Et `shouldRecognizeSimultaneouslyWith` rend `true` à **tout le monde sans
    condition** (`PlayerMonde.swift:730-733`) : il devra refuser **nommément**
    les recognizers de la nav.

---

## §4bis · LA FLUIDITÉ — la recette est déjà payée, on ne la réinvente pas

Kathryn a demandé « plus fluide » le 03-09. Le dépôt a **déjà** répondu à cette
question sur le player, et elle a validé le résultat (« plus fluide de fou »,
commit `6141653`). Tout ce qui suit est **prouvé par le code**.

### Ce qui a vraiment produit la fluidité

Le plan l'attribue explicitement à **la possession du geste**, pas au réglage
d'animation : « Le pan maître A réglé le drag » (`PLAN-PLAYER-CARD.md:1403`).
Avant lui, **dix itérations d'affinage n'avaient rien donné**, parce que le
ScrollView de la partition volait les drags descendants.

👉 **Conséquence n°1 pour la nav : la fluidité ne se trouvera pas dans les
courbes.** Elle se trouvera dans « qui possède le doigt ».

### Les quatre pièces, avec leurs chiffres

| Pièce | Valeur | Pourquoi |
|---|---|---|
| Pas de `withAnimation` sur la valeur suivie | tween maison CADisplayLink | la valeur du modèle **est** celle de l'écran, à chaque instant |
| Pas borné | **0,08** de course / image | un tween au TEMPS téléporte sous famine — mesuré **55 % d'amplitude en une image** |
| Élan de commit | **450 pt/s** | à 150, tout relâcher partait « à fond » (le « quand j'effleure, bim ») |
| Contenu figé en vol | `enMouvement = enSuivi \|\| enVol` | seuls le voile et l'offset relisent la valeur par image |

⚠️ **Les 450 pt/s ne se copient pas tels quels** : la course du player fait tout
l'écran, celle de la nav en fait 34. Le seuil doit être proportionné, et
**mesuré au doigt sur le téléphone**.

### Les deux bugs qu'un `withAnimation` achèterait

1. **La nav POURSUIT le doigt** avec le retard du spring — c'est exactement le
   défaut F1 déjà payé et supprimé.
2. **La nav CLAQUE** : un drag qui rattrape un repli en cours lit une fraction
   *déjà arrivée à la cible*. C'est le « ça bug quand je le fais vingt fois
   d'affilée ».

Et **jamais animer la HAUTEUR** : elle fait varier `bandeH`, donc le
`.padding(.bottom)` de la card, donc la page entière se re-layoute par image
(§0bis, §3).

## §4ter · L'ARBITRAGE DES QUATRE ÉTATS — ce que la mesure a tranché

### ✅ Ce qui marche : les zones disjointes

**La dalle ne peut PAS voler un toucher qui commence sur la nav.** La bande est
un `VStack` de frères aux cadres disjoints (`PageCard.swift:141-168`), et le
dépôt a déjà payé le précédent : « le doigt qui les touche ne rencontre jamais
le drag » (`ExercisesView.swift:1347-1357`). Séparer par zone est donc **la
bonne intuition**.

À savoir : **le grabber n'a aucune forme tactile déclarée** — seule la capsule
de 36×4 pt est prenante, les 18 pt de sa rangée sont transparents.

### ❌ Le vrai danger : il n'y a AUCUNE passation entre frères

**Celui qui a pris le doigt le garde jusqu'au lever.** Donc :

- un repli commencé sur la nav et poursuivi **vers le haut** continue de piloter
  le repli, même quand le doigt est visuellement sur la dalle — **le player ne
  s'ouvre jamais** ;
- l'inverse est vrai aussi : un drag parti de la dalle et descendu sur la nav
  continue de piloter le player — **la nav ne se replie jamais**.

C'est la raison écrite pour laquelle `JewelTabBar` refuse quatre gestes séparés
par case (`:313-316`) et n'en pose **qu'un seul** pour toute la rangée.

👉 **Remède : un seul propriétaire pour toute la bande**, qui décide à la
première frame nette et route ensuite — le patron du pan maître, mais posé sur
la bande. C'est la même conclusion que §4.9, désormais prouvée plutôt que
supposée.

### ⚠️ Les CINQ moments de `ouvert`, et pourquoi il ne peut pas garder la nav

`ouvert` n'est pas « le player occupe l'écran » : c'est **la dernière intention
commise**. Les fenêtres ne sont pas symétriques, elles sont **inverses** :

| Moment | PanMaitre reçoit | Voile bouclier | Corps prenant |
|---|---|---|---|
| Fermé au repos | non | non | non |
| **Vol d'ouverture (0,68 s)** | **oui, dès la 1ʳᵉ image** | oui | oui |
| Ouvert posé | oui | oui | oui |
| **Vol de fermeture (0,68 s)** | **non** | **non** | **non** |
| **Ouverture AU DOIGT** | non — `saisir()` ne touche jamais `ouvert`, même à p = 0,9 | | |

**Le bug concret de la fermeture** : pendant toute la descente, `ouvert` est
déjà faux alors que le corps noir couvre encore les pixels. La nav et la dalle
redeviennent prenantes **sous le noir** — un doigt qui suit le player vers le
bas et le rattrape trop bas retombe sur la bande, déclenche le `DragGesture` de
`PageCard.swift:157-166`, et **remonte le player qu'on vient de fermer**.

👉 **Remède : trois états (fermé / en vol / ouvert), et la nav ne prend le doigt
que sur « fermé ».** Le voile reste bouclier tant que `p > 0,02`, pas tant que
`ouvert`.

### 🔴 LE PIÈGE DU SE : 18 pt sous le bord physique

`bandeH` n'est que **le loyer que la card paie**. La bande **dessinée** fait
`grabH + dockH + 2` = `dockH + 20`, et elle est posée 18 pt plus bas
(`bande.offset(y: descente)`, `PageCard.swift:105`). Ses 18 derniers points
vivent donc **sous la zone sûre** — et cet offset **n'est conditionné à rien**.

Sur un appareil sans indicateur (**iPhone SE**, safe bottom = 0), ces 18 pt
passent sous le **bord physique** :

> En mini nav, le dock ne montrerait que **8 de ses 24 pt**, et le centre de la
> rangée de points tomberait **4 pt HORS de l'écran**.

Kathryn taperait sur les points, rien ne se passerait, et le verdict serait
« la mini nav ne marche pas » — alors que le défaut serait un offset de 18 pt
jamais conditionné à `safeAreaInsets.bottom`.

### Arithmétique corrigée

Le `+2` de la bande n'existe **qu'une fois** :

| État | dockH | Bande | (mon erreur) |
|---|---|---|---|
| nav | 76 | 78 | — |
| mini nav | 24 | 26 | — |
| player + nav | **152** | **154** | j'avais dit 156 |
| player + mini nav | **98** | **100** | j'avais dit 102 |

⚠️ Et l'état **player + nav n'existe nulle part dans le code** : c'est le
quatrième état demandé le 03-09, entièrement à écrire.

## §6 · L'INTÉGRATION — la nav validée du banc entre dans le système page card

**Verdict de Kathryn, 03-09 :** le banc sur la fausse home « marchait très
bien » — les quatre régimes **nav / mini nav / player + mini / fermée** sont LA
référence validée, y compris le player + mini EMPILÉ. Les quatre pages sont des
page cards (des jours de travail) : elles se lèvent au drag et laissent place au
player. **La consigne : intégrer la nav validée DANS ce système-là.**

⚠️ L'« option B » du §4quinquies est MORTE — c'était une mauvaise lecture d'un
« OK » : Kathryn avait déjà tranché en validant l'empilement au banc. Le coût
assumé de ce choix, connu et chiffré : en « player + mini », la dalle quitte sa
position canonique de 26 pt → **la constante du fouettage et les cinq juges
seront recalés, et le protocole §3.4bis repassé en entier** après intégration.
On ne relitige plus.

### Les six chantiers, dans l'ordre

**J1 — La spec `PageCard` (fichier de la session home : coordination
obligatoire, jamais une modification en douce).** La forme minimale : la bande
gagne un slot `nav:` à côté de `dalle:`, et `dockH` devient une fonction du
régime — une valeur **discrète** lue depuis `NavEtat.shared`, jamais continue.
`bandeVisible` garde exactement sa sémantique §2.17 (galet, chrono, clavier) et
coupe la bande ENTIÈRE, nav comprise — c'est la loi « jamais pendant
l'exercice ». Les quatre `PageCard` lisent le MÊME état : une seule hauteur à
tout instant, l'invariant inter-pages tient.

**J2 — Les trois sites d'appel libres.** `ExercisesView`, `ProgressPage`,
`ExerciseDetailView` passent la nav à leur `PageCard`. Leurs prédicats
existants ne bougent pas. Vérifs dédiées : le clavier d'Exercices, le `flood`
de la fiche, le voile du tuto (qui vit AU-DESSUS de `PageCard` et mangerait les
taps — §2bis).

**J3 — La home, avec la session qui la possède.** Même geste, plus deux
particularités : le tiroir (`tirageGeste` page-large, qui vit DANS le slot
`page:` donc ne vole pas la bande — prouvé §2 ⚠️ 6) et le slider, qui
retrouvera l'espace noir pour lequel il a été étalonné (§7).

**J4 — Le geste et le player.** Un **pan maître DE BANDE** (le patron de
`PlayerMonde.swift:646-789`, posé sur la bande, pas sur la fenêtre) : il décide
à la première frame nette (≥ 6 pt) et route — haut → la dalle/le player, bas →
le repli. Les taps des glyphes restent en `highPriorityGesture` (ils battent
l'ancêtre, jamais un frère). Chien de garde. **La nav n'écrit jamais `p`.** Et
la garde du player passe à TROIS états (fermé / en vol / ouvert) : la nav ne
prend le doigt que sur « fermé » — sinon les deux fenêtres de 0,68 s produisent
le player-yoyo et le toucher-sous-le-noir (§4ter).

**J5 — La sélection au châssis.** `NavEtat.page` pilote le `TabView`
(`selection: WoopTab`) ; la fiche allume l'onglet Exercices ; le point Profil
ROUTE vers l'onglet profil mais la page profil n'affiche pas de nav (elle n'a
pas de `PageCard` — la loi de Kathryn est déjà satisfaite par construction) ;
retour par son chevron existant.

**J6 — Le fouettage, en entier.** Recaler la dalle canonique du régime
« player + mini » (nouvelle constante dans `fouette_page.sh`), les cinq juges,
puis le protocole §3.4bis complet : cycles filmés ×4 pages, différentiel pixel,
retours ×5, cotes chiffrées égales, cadence sur le téléphone après
`./tools/charge.sh`. S'y ajoutent les points propres à la nav : le repli pendant
un vol du player, le clavier, le flood, le tuto.

**Chaque jalon est MONTRÉ avant d'être commité** — la règle de la maison, et
celle que ce chantier a déjà payée deux fois aujourd'hui.

## §4quinquies · ~~L'ARBITRAGE DU 03-09 : OPTION B~~ — ANNULÉ le 03-09 au soir (voir §6)

Le conflit entre les deux chantiers a été posé à Kathryn (la nav à 4 hauteurs de
bande sacrifiait l'invariant « taille fixe partout » du player), avec trois
options. **Elle a retenu l'option B :**

- **Deux cotes de bande, et seulement deux : 78 et 26.**
- **Hors séance** : nav déployée (78) ⇄ mini nav (26) au drag — la card
  s'allonge de 52 pt au repli, commit discret.
- **En séance : la bande vaut TOUJOURS 78, avec la dalle canonique INTACTE** —
  exactement les cotes fouettées du player, rien ne bouge, les cinq juges
  restent valides. La nav n'y existe qu'en **points dans la ligne du trait**
  (la zone de 18 pt au-dessus de la dalle — la capsule décorative de
  `PageCard.swift:142-146` n'est pas tactile).
- **Renoncement assumé** : l'état « player + nav déployée » empilé (154 pt)
  n'existe pas. C'était aussi le plus cher en écran.

⚠️ Pour l'intégration réelle, les points de séance vivront DANS la zone du
trait de `PageCard` — une retouche à coordonner avec la session qui possède ce
fichier. Au banc, ils sont posés en surimpression aux mêmes cotes.

## §4quater · LES DEUX FAUTES DU BANC DU 03-09 — payées, à ne pas refaire

Verdict de Kathryn sur les captures du banc : « c'est quoi ces conneries […]
la page détail exercice EST une page card comme toutes les autres […] ce rendu
de PageCard on l'avait grave bossé avec le player qui vient se glisser en
dessous — pourquoi autant de régression ! »

Elle a raison sur les deux points, et les fautes sont différentes.

### Faute n°1 — le banc a testé UN ÉTAT QUI N'EXISTERA JAMAIS

Le test `-navPage` montait la vraie page **plein écran, hors séance** (donc
avec son dôme / sa molette au bord bas, comme `PageCard` le veut hors séance),
puis posait la nav **par-dessus, en flottant au châssis**. Résultat : la nav
écrite en blanc sur le dôme crème de la fiche, les glyphes sur les graduations
de la molette.

**Ces « collisions » sont des artefacts du banc, pas des découvertes.** Dans le
monde cible, la page est TOUJOURS relevée : la card cède la bande, le dôme et
la molette remontent avec elle, et la nav vit dans le noir en dessous. L'état
« page pleine + nav flottante » n'existera jamais.

> **La loi qui en sort : un banc ne teste que des états qui existeront.** Une
> capture d'un état impossible est pire qu'aucune capture — elle se lit comme
> un verdict.

**La forme juste** — celle que Kathryn décrit : chaque page reproduite en
**contenu compact DANS la `PageCard` du banc** (comme la fake home) — la fiche
avec son dôme, Exercices avec sa molette, Progress avec son calendrier — et la
nav dans la bande. On juge alors le vrai monde : la card raccourcie, le mobilier
remonté, la bande en dessous.

### Faute n°2 — le régime « player + mini » a DÉFAIT la dalle travaillée

Le rendu de la dalle du player dans la bande (la `WorkoutPill` dockée, ses
76 pt, sa `descente` de 18 pt dans la home bar, le trait) a été **réglé au
pixel** par le chantier player (§3.4sexies, verdicts du 01-09). Mon banc l'a
empilée naïvement dans un `VStack` avec les points (`dockH: 100`) : la dalle a
quitté ses cotes, la descente s'applique à la pile entière, le rendu trahit ce
qui avait été validé.

**La forme juste** : en « player + mini », la dalle garde **exactement** sa
géométrie validée (les mêmes cotes que dans l'app), et les points prennent leur
place **sous elle** — c'est la bande qui s'agrandit vers le bas, pas la dalle
qui remonte. Le raccord entre la descente de la dalle et la rangée de points
est un réglage à part entière, pas un empilement.

S'ajoute le défaut de geste déjà trouvé par la contre-vérification : dans le
slot `dalle:`, la nav est **enfant** du geste de la dalle, pas sa sœur — elle
mange le drag d'ouverture du player. La bande du banc doit reproduire la
structure de frères de la vraie bande.

## §5 · CE QUI RESTE À TRANCHER

1. **La lune secrète** — elle vit exactement là où la nav veut aller. Elle meurt,
   elle migre, ou elle passe sur un appui long ?
2. **Le player en séance** — la dalle partage la réserve en largeur avec la nav
   repliée, ou le player devient la pastille flottante et la réserve ne porte que
   la nav ?
3. **Par où entre-t-on au profil et au coffre**, puisqu'ils sortent de la nav ?
4. **Le détail exercice** a-t-il droit à la nav ? Il a déjà un retour en haut à
   gauche : lui laisser la nav donne deux sorties concurrentes.
5. **Le slider au repos** — vit-il en permanence dans la card, et que devient
   alors le film du tiroir de 1,95 s ?
6. **Le stop universel par appui tenu — où vit-il ?** Le hunk `onPlayHold`
   (appui tenu 0,55 s sur le galet play → panneau « Terminer la séance ? ») est
   câblé **uniquement dans une branche morte** : `WoopApp.swift:1129`, à
   l'intérieur du `if barreBijouVisible` dont la condition est toujours fausse
   (`:723-726`, et le §23 le redit à `:1122-1124`). `galetPlayTenu` (`:751`)
   n'a **aucun autre appelant**. Ce geste est donc écrit, entretenu, et
   inatteignable en production. Si la nav prend le bas de l'écran, c'est à
   trancher : le stop reste sur la dalle du player, ou il migre sur la nav ?
   *(vérifié par la session woochoper-ios-72, 02-09)*

---

## §6 · LES COMMENTAIRES QUI MENTENT

`bandeH` est `private` : aucune page ne peut lire ce que la bande lui prend, donc
chacune l'a recopié — et de travers. **Ne code jamais sur ces phrases.**

| Où | Ce qui est écrit | Le réel |
|---|---|---|
| `HomeNuit.swift:2531` · `ExercisesView.swift:636` · `ProgressPage.swift:171` | « dock 86 » | **76** |
| `ProgressPage.swift:118-121` | « padding bas 110 en séance » | **78** |
| `HomeNuit.swift:2627` | « la bande du moteur réserve déjà 110 » | **78** |
| `PageCard.swift:150` | « le stop, **Button** enfant » | ce n'est plus un `Button` (`WorkoutPill.swift:245-249`) |

**À faire dans le même commit que la nav :** rendre `reserve` non-`private`, la
faire lire par les quatre pages, et corriger ces cinq commentaires.

### Cotes zombies à ne pas prendre pour vivantes

`ExercisesView.leveeSeance = 106` et toute sa chaîne (`leveeFixe`, `CarteLevee`,
`CadreCarte`, `MonteAvecLaCard`) ne sont appliquées **nulle part**.
`HomeNuitPage.playerP` est mort aussi.

---

## §7 · LE SLIDER CASSÉ (point §0.3)

**Cause trouvée, non corrigée.** À `HomeNuit.swift:2914-2938`, le slider est
ancré `.frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 10)` —
c'est-à-dire au bas du **conteneur de page**, donc de l'écran.

Son propre commentaire dit pourtant : « LE SLIDER VIT DANS L'ESPACE NOIR SOUS LA
CARD — celui que la card ouvre en se raccourcissant ». Cet espace n'existe plus
depuis que la page hors séance est plein écran physique : le slider s'est
retrouvé collé au bord, posé sur la vidéo.

Tout son étalonnage (arête de card à 734, slider 768..830) décrit un écran
disparu. **Rien ne le rattache à l'arête basse de la card.**

👉 Une réserve permanente au châssis (§1) recrée mécaniquement l'espace pour
lequel il a été dessiné.

---

## §8 · LE PROTOCOLE AVANT TOUT VERDICT

Le **fouettage ultime §3.4bis** s'applique intégralement — la nav touche
`PageCard` et la bande, donc le protocole entier, pas un extrait.
Voir `tools/player/PLAN-PLAYER-CARD.md:992-1025` et `tools/player/fouettage/`.

Rappels spécifiques à ce chantier :

- **Le point 4 du protocole** exige des cotes CHIFFRÉES ÉGALES sur les quatre
  pages. C'est précisément ce qu'un repli mal fait casse.
- La **dalle canonique** `(68, 1100, 0, 76)` est gravée dans
  `tools/player/fouettage/fouette_page.sh:25-26`. Toute nav qui change la bande
  doit **recaler cette constante et les cinq juges**.
- La sonde de hit-test de `PlayerMonde.swift:877-891` tape à `H − 60` : à recoter
  si la hauteur de la réserve change.
- `./tools/charge.sh` avant toute mesure de cadence (🔴 au-dessus de 2).
- La vraie cadence se mesure **sur le téléphone**, jamais au simulateur.

---

## §9 · COORDINATION MULTI-SESSION

Au 02-09, **une autre session travaille sur `PlayerMonde.swift` et les entrailles
du player** (habillage : suppression de la progress bar, chrono, animation
continue). Frontière convenue : elle ne touche ni aux cotes de la mini-card, ni à
son ancrage bas, ni au z-order du châssis ; ce chantier ne touche pas à
`PlayerSeance.swift` ni aux parties player d'`ActiveWorkoutView`/`SessionSlate`.

⚠️ **Le correctif `.frame(width: W, height: Hs, alignment: .bottom)` de
`PageCard.swift:134` — celui qui rend 17 pt à toutes les pages — n'était pas
commité au moment de cette analyse.** Kathryn le fait committer par la session
parallèle. Ne jamais réécrire ce bloc sans vérifier qu'il y est : sa perte se
lirait comme un défaut de la nouvelle nav, pas comme la régression qu'elle est.

### ⚠️ `main` NE COMPILE PAS SEUL — tout build vert est un faux vert

**Mesuré le 02-09 sur HEAD `693f0ee` :**

```
git show HEAD:Woop/WoopApp.swift        | grep onPlayHold  → 1125: onPlayHold: galetPlayTenu,
git show HEAD:Woop/Views/JewelTabBar.swift | grep -c onPlayHold  → 0
grep -c onPlayHold Woop/Views/JewelTabBar.swift  (arbre)   → 2
```

**L'appel est commité, le paramètre ne l'est pas.** Le site d'appel est entré le
25-08 avec `a3cce83`, un commit par chemins explicites où le chemin
`Woop/Views/JewelTabBar.swift` a été **oublié** — sa moitié dort sur le disque
depuis le 20-08.

Conséquences, dans l'ordre d'importance :

1. **Un `EXIT=0` local ne prouve rien** : l'arbre compile parce qu'il porte
   l'orphelin. Un clone frais de `main` échoue au type-check sur un label
   d'argument que le type n'a pas.
2. **Ne JAMAIS faire `git checkout --` ni `git stash` sur `JewelTabBar.swift`** :
   jeter ce hunk casse la compilation pour tout le monde.
3. Committer la nav laissera `main` cassé pour un clone frais tant que ce chemin
   n'est pas scellé. **Ce n'est pas au chantier nav de le réparer** — ça tient en
   un commit d'un seul chemin, la moitié manquante d'`a3cce83`, et c'est une
   décision de Kathryn.

👉 Cela **change le statut de la décision n°6** (§5) : le stop par appui tenu
n'est pas un câblage récent à arbitrer, c'est un **vestige de la v1 resté à
moitié commité**. Et le galet VIVANT (`GaletMaison` / `MenuHote`,
`MenuNappe.swift`) n'a aucun appui long : ses deux seules mentions (`:1468`,
`:1527`) sont des commentaires qui en **interdisent** un — « UN SEUL GESTE ». À
lire avant de coder quoi que ce soit qui ferait migrer le stop sur la bande.
*(vérifié par woochoper-ios-72, re-vérifié ici, 02-09)*

---

Commits **par chemins explicites**, jamais `git add -A`. Jamais de `git stash` :
il emporte le travail de l'autre session.

⚠️ **`HomeNuit.swift` a bougé d'environ 107 lignes PENDANT cette analyse**
(285 lignes non commitées, HEAD passé de `6141653` à `641826e`). **Toute cote
citée depuis ce fichier doit être re-vérifiée au moment de coder** — y compris
celles de ce document.
