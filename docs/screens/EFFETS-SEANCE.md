# Les effets de la séance — où ils vivent, ce qui les cause, comment les éteindre

**À quoi sert ce fichier.** Quand un effet bugue, la question n'est jamais
« lequel est-ce ? » mais **« où est-il, et comment je l'éteins pour savoir
si c'est lui ? »**. Ce catalogue répond aux deux en une ligne. Chaque effet a
un **barreau** (`-sansXxx`) : sans lui, on ne peut ni l'accuser ni le
disculper.

Écrit le 24-09-2026. Toute session qui ajoute un effet à la séance l'ajoute
**ici, dans le même commit**.

⚠️ **Aucun de ces effets n'a été mesuré sur son iPhone.** Le simulateur ne
mesure que le simulateur, et il n'a pas de moteur haptique.

---

## 1. L'ouverture — le passage en particules

Le passage qui remplace un écran par un autre. **Il ne joue plus qu'UNE fois
par séance**, à l'ouverture (le Go). Tous les autres changements d'écran
passent par la coupe sourde (§2).

| l'effet | où | la cause | le barreau |
|---|---|---|---|
| le nuage de 900 000 points | `Particules.metal` + `OuvertureParticules.swift` | `CoupeEtat.jouer` — 2 sites, tous deux à l'ouverture de la séance | `-sansOuverture` (alias `-sansFlamme`, `-sansCoupe`) |
| le grain sous le pixel | `Particules.metal : particuleFragment` | — | (la chute est `a⁴`, cœur visible ≈ 0,4 px) |
| l'haptique de combustion | `OuvertureParticules.swift : Frisson` | le même `jouer` | `-sansHaptique` |

**Ses bancs** : `-ouvertureLab <p>` fige le passage à l'avancement `p` (c'est
lui qui a prouvé le calque fantôme du 24-09) · `-ouvertureUneFois` le joue une
fois, 5 s après l'arrivée, et rien d'autre — le seul moyen de vérifier en
capture que l'écran est PROPRE après · `-ouvertureBoucle` le rejoue sans fin ·
`-ouvertureSansGeste` coupe l'honoration par le rendu, pour prouver que le
chien de garde délivre quand même le geste confié.

### ⚠️ Les trois pièges de cet effet, tous payés

1. **La fin se CALCULE** (`CoupeEtat.fin`, `.queue`) depuis les constantes du
   shader. Un nombre en dur (`1,35`) a laissé les étincelles — dont la vie a
   été multipliée par 2,8 le 23-09 — **figées vivantes** à l'écran.
2. **On ne met JAMAIS le calque en pause sans avoir dessiné un cadre vide.**
   Un `MTKView` en pause laisse sa dernière image. Trois portes mènent à
   l'extinction (fin du passage, arrière-plan, rendu qui se tait) : toutes
   passent par `nettoyer(_:)`.
3. **Le geste confié n'est pas décoratif** — `onChoisirExo` AJOUTE l'exercice
   à la séance. `honorer()` est le seul chemin, et un chien de garde le
   délivre si le rendu ne tourne pas.

---

## 2. La coupe sourde — la même coupe, sans le feu

Un voile noir de 0,30 s, sans une particule, sans haptique.

| où | la cause | pourquoi elle existe |
|---|---|---|
| `CoupeEtat.couper` | 5 sites : le galet play, l'onglet Exercices, le chevron de la page, la fermeture d'une fiche, le lancement d'un exercice | elle tient l'écran pendant que **trois choses se réordonnent** (la fiche se dépile, l'onglet est rendu, le lecteur se pose) |

⚠️ **Ne la supprimez pas en croyant supprimer un ornement.** Sans elle, on
revoit la page exercices entre les deux — le défaut refusé le 22-09. C'est le
COSTUME qu'on a retiré le 24-09 (« trop de fois l'effet paillette »), pas la
coupe.

⚠️ **Le garde-fou du noir tenu** : un compteur de tour (`tourVoile`). Sans
lui, un voile annulé efface celui qui vient de prendre sa place — et l'écran
reste noir.

---

## 3. Le point de séance — le témoin

`Nosfy/Views/PointRec.swift` · barreau **`-sansRec`**

| l'effet | ce qu'il fait | sa période |
|---|---|---|
| le disque blanc | 14 pt, opacité 0,55 → 1,00 **et** échelle 0,88 → 1,10 | 1,15 s |
| le pulsar | 3 anneaux d'un demi-point, nés sur le disque, jusqu'à ×2,35 | 1,9 s, décalés d'un tiers |
| les paillettes | 7 grains d'un point, périodes 1,3 · 1,7 · 2,1 · 2,3 · 2,9 · 3,1 · 3,7 s | aucune multiple d'une autre |
| le néon de braise | blanc chaud → orange → rouge qui meurt | 1,9 s |

**Où il vit** : monté à la RACINE, dans `couvercles` (`NosfyApp.swift`) —
c'est la seule route qui passe au-dessus de la barre native — mais il ne
s'affiche que **là où la barre existe**, c'est-à-dire sur l'Accueil seul.

✅ **VÉRIFIÉ SUR SON iPHONE, le 24-09 au soir** — son verdict, mot pour mot :
« je ne vois jamais le coureur, c'est que le REC, et on ne voit plus la page
exercice quand la session est en cours ». C'est la seule chose de ce catalogue
qui soit confirmée sur le vrai téléphone : les **quatre portes** vers les
exercices sont fermées (le binding du TabView, `routerVers`, le bouton de la
home, le pont `NavEtat`), et le témoin tient sa place.

⚠️ **Il a vécu quelques heures sur tous les écrans, et c'était une erreur**
(corrigée le 24-09 au soir, après son essai sur le téléphone). Posé par-dessus
le compteur d'une série, un témoin est un intrus : ces pages-là sont
immersives, elles n'ont pas de barre **justement** pour qu'on ne regarde
qu'elles. Il est l'onglet Exercices pendant une séance, rien d'autre.

### ⚠️ Les pièges

- **Un item d'onglet natif n'accepte aucune vue vivante** : une `View` à
  `@State` dans un `label:` n'est jamais ré-évaluée, un `if/else` y fige la
  branche prise au montage, et `Image(uiImage:)` y est ignoré. Trois essais
  mesurés le 23-09 — la surimpression à la racine est la seule route.
- **Sa cote se mesure depuis le bas de l'ÉCRAN** (40 pt, glyphe d'onglet à
  2436 px sur la dalle de l'iPhone 15), et la vue `ignoresSafeArea` pour que
  ce soit vrai. Le 23-09, supposer le conteneur l'a mis 34 pt trop bas.
- **Saturé et serré, sinon c'est du MARRON.** Des couleurs chaudes à
  mi-opacité étalées sur du noir font de la fumée brune. Un néon, c'est
  l'inverse : très opaque, sur un petit rayon.

---

## 4. Le lecteur — la tête

| l'effet | où | la cause | le barreau |
|---|---|---|---|
| la chaleur de la tête | `PiluleVagabonde.swift : ChaleurTete` | montée seulement en séance, lecteur posé | `-sansChaleurTete` |
| le halo de la carte du jour | `PiluleVagabonde.swift : HaloCarte` | idem (période 4,7 s) | `-sansChaleurTete` |
| le flottement de la carte + du sticker | `HomeNuit.swift : MiniCardJour` (`flotte:`, opt-in) | 5,7 s et 4,1 s, **en sens inverse** | `-sansFlottement` |
| le titre balayé | `PiluleVagabonde.swift : InviteAnimee` | `TimelineView` à 20 Hz, avec sa porte `fige:` | — |

### ⚠️ LE PIÈGE LE PLUS COÛTEUX DE LA JOURNÉE — le calque orange

Trois rectangles orange derrière la tête, le 24-09. **Deux causes, et il
fallait les deux** :

1. **Un modificateur posé sur un `@ViewBuilder` qui rend PLUSIEURS vues est
   appliqué à CHACUNE.** `teteLigne` rendait trois vues sœurs : le
   `.background { ChaleurTete() }` était dessiné trois fois, à la taille de
   chaque vue. Remède : la branche rend UNE vue, avec l'espacement du parent
   repris à l'identique.
2. **Un dégradé dont le rayon dépasse son cadre est TRANCHÉ net au bord** — et
   une lumière coupée net EST un rectangle. Remède : `EllipticalGradient` en
   **fractions** (`endRadiusFraction: 0.5`), transparent avant son bord quelle
   que soit la taille. **Tous les halos de la séance sont désormais en
   fractions.**

⚠️ Et j'ai d'abord accusé les particules figées. Une cause se **prouve par une
capture** avant d'être écrite : `-grandPlayerOuvert` montre le lecteur sans
qu'aucun passage n'ait joué — les taches y étaient.

---

## 5. Le lecteur — les trois états

La tête dit **l'état**, la partition dit **le sujet**.

| état | quand | la tête dit |
|---|---|---|
| 1 | il reste une série à faire | **En cours** |
| 2 | plus aucune série en attente | **Exercice terminé** |
| 3 | l'écran de choix | **Ajouter un exercice** |

⚠️ **L'état 2 ne s'invente pas, il se LIT** : `exerciceFini` = l'exercice en
tête de partition n'a plus une seule série en attente. C'est la même vérité
qui fait vivre le cheveu blanc de la série en cours depuis le 23-09. Aucun
drapeau nouveau — donc rien qui puisse diverger.

**La distinction des deux écrans** : `basculer()` pose `repli = choisit ? 1 : 0`
— tête GRANDE en séance, RÉDUITE en choix. Un carré de zone **ne touche plus
au repli** : il n'ouvre et ne referme que sa liste.

**La transition** obéit à une seule phrase : *ce qui arrive descend de la
tête, ce qui part s'en va par le bas* (`depuisLaTete`).

---

## 6. Le lecteur — les carrés de zones

`PiluleVagabonde.swift : CarreZoneMini` · barreau **`-sansPulseZone`**

| l'effet | le détail |
|---|---|
| le souffle | **les cinq** respirent (pas seulement la zone choisie), périodes 2,3 · 3,1 · 2,7 · 3,7 · 2,9 s, avances et amplitudes propres |
| le bloom | deux copies floutées de la zone blanche (4 px pour l'aura, 2 px pour le cœur), **posées dessous** |
| le flottement | ±2,5 pt et ±0,55°, périodes 3,3 · 4,1 · 3,6 · 4,9 · 4,4 s, un carré sur deux en sens inverse |
| la bordure choisie | un dégradé à **source fixe** (vive en haut à gauche) + un ressort à la sélection |
| l'haptique | franc quand on OUVRE une zone, léger quand on la referme |

⚠️ **Au-delà de 1, l'opacité ne donne plus rien** : pousser le néon blanc
passe par le BLOOM, jamais par un trait plus épais. Les deux flous restent
sous 5 px — c'est sa loi.

⚠️ **Le flottement ne déplace que les pixels** : la zone qui prend le doigt
est posée par le parent (`contentShape`) sur le cadre de mise en page, qui ne
bouge pas. On ne vise jamais une cible mouvante.

⚠️ **Aucune période n'est multiple d'une autre.** Cinq carrés sur la même
horloge, c'est une guirlande de Noël — et une guirlande, c'est cheap.

---

## 7. Le bouton « Ajouter un exercice »

`Nosfy/Views/BoutonAjouter.swift`

| l'effet | le détail | le barreau |
|---|---|---|
| le thème | celui du `BoutonPrimaire` — capsule de 58, plaque noire, lumière qui monte du bas sous le doigt | — |
| le liseré | **en pointillé** : c'est la seule différence avec le primaire, et c'est elle qui dit « celui-ci ajoute » | — |
| les particules du bord | trois nappes cuites une fois, seules leurs opacités s'animent, décalées | `-sansBordParticules` |
| l'onde au tap | deux anneaux nés sur le contour, qui s'en éloignent de 6 % | — |
| **l'invitation** | quand un exercice se termine, le bouton joue SA propre onde : l'app fait le geste qu'elle attend | — |

⚠️ **L'invitation est armée par `task(id:)`, pas par `onChange`.** Le bouton
peut naître DÉJÀ dans l'état terminé (elle revient de la fiche, la vue se
monte), et un `onChange` ne voit jamais la valeur d'arrivée : l'invitation
partirait une fois sur deux, ce qui est pire que jamais.

⚠️ **Les nappes de particules ne glissent pas** : elles s'allument et
s'éteignent SUR PLACE. Aucune bande ne parcourt le bord — les balayages sont
morts depuis le 26-08.

⚠️ **Le rayon du contour suit la forme** (`min(h, w) / 2`) : dessiné avec un
coin fixe sur une capsule, il sèmerait les points à côté du bord et on verrait
deux traits.

---

## 8. La partition — ce qui désigne

| l'effet | où |
|---|---|
| l'exercice en cours : lame d'argent **même replié**, numéro à 0,92, nom en **blanc plein** (les autres à 0,46) | `SessionSlate.swift : SlateRang.courant` |
| la série en cours : un cheveu blanc de 2 pt, et le titre en semi-gras | `SetHistoryRow.courante` |

⚠️ **La place du cheveu est TOUJOURS réservée**, même quand il ne se voit pas :
sinon les lignes glissent de 2 pt quand l'actif change.

⚠️ **Rien n'est désigné quand tout est fait** — on ne désigne pas au hasard.
C'est cette absence qui sert à lire l'état « exercice terminé » (§5).

---

## 8bis. ⚠️ LA MESURE DU 24-09 — un seul moteur bat, et c'est le bon suspect

Journal de sonde pris pendant une **vraie séance sur son iPhone**, 148 s.

| écran | cadence | processeur | thermique | pire intervalle |
|---|---|---|---|---|
| home | 60,1 img/s | 38 % | 2 | 17 ms |
| **exercices / séance** | **53,9 img/s** | 35 % | 2 | **54 ms** |
| lecteur | 60,1 img/s | 34 % | 2 | 17 ms |

**Qui bat, et où** — médiane des tics par seconde :

| écran | la famille qui bat |
|---|---|
| home | *aucune* |
| **exercices / séance** | **lentille de série : 19/s** |
| lecteur | *aucune* |

**Un seul suspect, un seul écran, et c'est le même.** La lentille
(`LiquidLensLab.swift`) redessine TOUT l'écran — `compositingGroup` +
`layerEffect` Metal + Canvas — à chaque battement, pendant chaque série et
tout son repos.

⚠️ **Sa porte thermique MARCHAIT** : 19 Hz et non 60, parce que le téléphone
était à thermique 2. Le défaut n'est donc pas une porte manquante — c'est
qu'à son régime le plus bas, ce moteur redessine encore l'écran entier vingt
fois par seconde. Et la loi de la maison dit : *redessiner pour animer coûte
3 à 8 fois plus que d'animer*.

⚠️ **Ce que cette mesure ne dit PAS.** Le thermique était à 2 dès la première
seconde — au-dessus de 1, iOS bride, donc ces pourcentages ne se comparent
pas aux 5-10 % relevés sur la home le 22-09. Et une partie de cette chaleur
venait des builds posés juste avant. **`corps = 0` sur toute la balade** :
SwiftUI ne recalcule aucune vue, les douze effets déclaratifs de la séance ne
passent pas par le fil principal.

### L'A/B naturel caché dans le journal

La lentille ne bat pas en continu : elle **s'arrête et repart** pendant la même
séance, sur le même écran. Le journal contient donc quatre fenêtres muettes —
secondes 15-16, 39-42, 56-57, 72-74 — et tout le reste bruyant.

| sur l'écran exercices/séance | n | cadence | processeur | pire intervalle |
|---|---|---|---|---|
| la lentille bat | 34 s | **46,0 img/s** | 36 % | **62 ms** |
| la lentille se tait | 11 s | **60,1 img/s** | 32 % | **17 ms** |

⚠️ **Et les deux groupes sont identiques sur TOUT le reste du contexte** que la
sonde capture : `corps` 0, `mouvement` 0, `drag` 0, `ile` 1, `story` 0. Ce
n'est donc pas « page au repos contre page active » : c'est le même écran, le
même contexte, quatre fois de suite, avec et sans ce moteur.

⚠️ **Ce que ça reste quand même : un faisceau, pas une preuve.** On ne sait pas
POURQUOI la lentille se tait dans ces fenêtres — si quelque chose d'autre varie
avec elle, il varie aussi. Onze secondes muettes, c'est peu. Et le thermique
était à 2 du début à la fin.

**Ce qui clôt le débat, et rien d'autre** : téléphone froid, une balade avec
`-sansLentille`, une sans, en alternant — trois fois soixante secondes de
chaque côté. Le barreau existe maintenant ; la question tient en quatre
minutes.

**Fait depuis** : la lentille a enfin son barreau (`-sansLentille`) et un cran
de plus à l'état critique (10 Hz). **Reste à décider, et ça se voit** :
descendre sa cadence à thermique 2, ou l'endormir pendant le REPOS entre deux
séries — les deux changent ce qu'on voit, donc ce n'est pas à moi de trancher.

---

## 9. La loi qui vaut pour tout ce qui précède

- **Redessiner pour animer coûte 3 à 8 fois plus que d'animer** (mesuré sur
  son iPhone le 05-09 : `TimelineView` à 20 Hz = 33-38 % de processeur ; la
  même image en valeur animable + `repeatForever` = 4-18 %). **Tout ce
  catalogue n'anime que des opacités, des échelles, des décalages et des
  rotations.** Aucun pixel n'est recalculé.
- **Un `repeatForever` posé par un PARENT se fait avaler** dès que ce parent
  est ré-évalué, et l'animation s'arrête sans rien dire. L'état de phase vit
  dans la FEUILLE et se ré-arme en `.task(id:)`.
- **Toute lumière a une cause et un bord.** Jamais de balayage.
- **La brillance vient de la blancheur, jamais de l'épaisseur** : cheveux de
  1 pt, blooms ≤ 5 px, noir absolu entre.

---

## ⚠️ Ce qui n'est PAS fait

- **Aucune mesure de chauffe**, sur aucun de ces effets. Le lecteur porte
  désormais une douzaine d'animations permanentes pendant toute la séance,
  là où il n'en portait aucune le 22-09. C'est le premier poste à mesurer.
- **L'haptique** n'est vérifiable que sur son iPhone.
- **Le site de documentation** (`docs/site/content/briques.ts`) décrit encore
  le point REC en diamant et le bouton sans bordure — il n'a pas pu être mis à
  jour le 24-09 : une autre session a des modifications non commitées dans ce
  même fichier, et on ne porte jamais le travail d'une autre session.
