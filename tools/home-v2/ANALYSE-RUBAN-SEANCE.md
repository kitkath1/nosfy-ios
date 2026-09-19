# ANALYSE — LE RUBAN DE SÉANCE : les « trois traits », le gros ruban, le lag (03-09)

> **Rien n'est codé.** Ses verdicts du 03-09, sur l'iPhone : « l'animation lag
> quand le tel est en mode session active », « c'est pas beau, on voit TROIS
> TRAITS », « on voit une sorte de gros ruban, très cheap », « tout chauffe, je
> peux pas me balader dans l'app » — **« sur la home aussi »**. Elle aime le
> STYLE (une braise qui court autour de la card) ; c'est l'exécution qui est
> refusée.
>
> **La pièce maîtresse : sa capture TÉLÉPHONE** —
> `captures/bord-tel-080235.png` (page Exercices, séance ouverte, 08:02).
> C'est la première image du contour prise sur l'appareil ; tout ce que le
> simulateur ne pouvait pas montrer (CHAUFFE-HOME.md §0) y est visible.
>
> Ce document PROLONGE deux dossiers, il ne les répète pas :
> `CHAUFFE-HOME.md` (les 4 interrupteurs, le protocole téléphone) et
> `ANALYSE-HOME-VIVANTE.md` §FLUIDITÉ (le coût est l'INVALIDATION, prouvé par
> le shader qui a lagué autant que tout le reste).

---

## §0 — LA CAPTURE, DÉCODÉE

1. **Le contour tourne sur la page EXERCICES.** Ce n'est pas un bug : c'est la
   construction. `BordSeance` est monté dans la robe commune de TOUTES les
   pages (`PageCard.swift:183`), et chaque onglet enveloppe sa page dans sa
   propre `PageCard` — home (`HomeNuit.swift:2356`), exercices
   (`ExercisesView.swift:469`), progress (`ProgressPage.swift:124`), fiche exo
   (`ExerciseDetailView.swift:607`, poussée par `navigationDestination`
   au-dessus d'Exercices → **deux robes empilées possibles**). « Sur la home
   aussi » : évidemment — c'est LA MÊME vue, le défaut est partout à la fois,
   et il se réparera partout à la fois.
2. **Les « trois traits »** : sur le flanc gauche de la capture, trois bandes
   lumineuses PARALLÈLES, séparables à l'œil. §3 en donne la cause exacte —
   elle est écrite dans le code.
3. **Le « gros ruban »** : sur le flanc droit, la crête s'étale en une nappe
   de plusieurs centaines de points. §2 : c'est la géométrie du dégradé
   ANGULAIRE sur un rectangle haut — aucun réglage de stops ne le corrige.
4. Le verre de la page (le galet-lentille rouge, à droite) **attrape la braise
   et l'amplifie** — observation sur la capture, pas mesurée, mais cohérente
   avec la loi du verre (il réfracte ce qui passe dessous).

---

## §1 — LE LAG A DEUX ÉTAGES, ET ILS SE TIENNENT

### Étage 1 : le pas d'horloge — arithmétique, pas opinion

`BordSeance.swift:70-74` : 20 Hz, rotation `t * 360 / 9` = **40°/s → 2° par
tick**. Or 2° d'angle, projetés sur le bord d'une card de ~393 × ~680 pt
(demi-largeur a = 196 pt), font un déplacement linéaire de la crête de
**a / cos²θ × 0,035 rad** :

| position sur le flanc | saut PAR TICK (20 Hz) |
|---|---|
| milieu du flanc (θ = 0°) | **≈ 7 pt** |
| à 45° | ≈ 14 pt |
| près du bout du flanc (θ ≈ 60°) | **≈ 27 pt** |

Une lumière qu'on suit des yeux qui saute de 7 à 27 pt vingt fois par seconde,
c'est EXACTEMENT « l'aspect pixel lag ». (Chiffres calculés depuis la
géométrie, à quelques points près — pas mesurés sur l'appareil.)

### Étage 2 : l'invalidation — le verrou déjà prouvé

`ANALYSE-HOME-VIVANTE.md` §F.2 : même un shader d'UNE passe a lagué → le coût
n'est pas le dessin, c'est la **ré-évaluation à chaque tick DANS le composite
de la card** (vidéo vivante + verres natifs). Donc :

> **lisse ⇒ 60 Hz ⇒ 3× d'invalidations ⇒ ça lag. 20 Hz ⇒ les marches se
> voient. Les deux branches perdent : l'architecture actuelle interdit la
> fluidité PAR CONSTRUCTION.** Ce n'est pas un réglage à chercher — c'est
> l'horloge elle-même qu'il faut supprimer (§5).

Micro-défaut au passage : `t` est replié modulo 900 s (`:73`). La rotation
retombe pile (900 × 40° = 100 tours exacts) mais **les deux sinus du souffle
non** (900/6,1 et 900/9,7 ne sont pas entiers) → un petit saut de luminosité
toutes les 15 minutes de séance. Anecdotique ; meurt avec §5 de toute façon.

---

## §2 — LE « GROS RUBAN » : l'angle affiché en longueur d'arc

La nappe est paramétrée en ANGLE (`AngularGradient`) mais se LIT en longueur
de bord. Sur un rectangle 1:1,73, la correspondance angle → bord n'est pas
uniforme : elle vaut a/cos²θ, soit **un facteur ~4 entre le milieu d'un flanc
et son extrémité**.

- La crête principale fait 4,4 % du tour (stops 0,150 → 0,194 = 15,8°,
  `BordSeance.swift:160-162`) : **≈ 55 pt de large au milieu du flanc,
  ~200 pt près des bouts** — c'est le « gros ruban » de la capture.
- Sa vitesse varie du même facteur : elle TRAÎNE au milieu des flancs et
  FILE dans les coins.

C'est structurel : aucun choix de stops, de cadence ou de flou ne rend
constant ce qui est projeté par une tangente.

---

## §3 — LES « TROIS TRAITS » : les phases +8° et +18°

`BordSeance.swift:99-107` : les trois couches tournent avec des DÉCALAGES DE
PHASE — lit +0°, ruban +8°, fil +18° — pensés pour « donner une tête à la
lumière ». Mais 8° et 18° d'angle, au milieu d'un flanc, font **≈ 28 pt et
≈ 64 pt d'écart linéaire** (le double à 45°, le quadruple aux bouts) :

> **Les trois crêtes ne se superposent pas — elles se POURSUIVENT, séparées
> de dizaines de points. On ne voit pas une lumière à trois épaisseurs, on
> voit TROIS LUMIÈRES.** C'est le « on voit trois traits » de sa capture, au
> code près.

S'y ajoutent, en second ordre : trois profils d'épaisseur à sommets décalés
(flous 14/4/1,2 sur largeurs 14/5/1,6 — les creux entre sommets restent
lisibles), et un banding 8 bits plausible sur les zones mortes à alpha 0,015
en `plusLighter` sur OLED (hypothèse — se juge sur capture, pas de mesure).

---

## §4 — LA BRAISE BRÛLE AUSSI POUR PERSONNE

Deux faits de lecture, nouveaux par rapport au dossier chauffe :

1. **Sous le player DÉPLOYÉ, le contour bat toujours.** Le player posé est un
   fond NOIR PUR plein cadre (`PlayerMonde.swift:387-401`) ; or la seule pause
   de `BordSeance` est `reduceMotion` (`:70-71`), sa seule garde `actif =
   enSeance` (`PageCard.swift:183`). Pendant l'essentiel d'une séance réelle —
   le player ouvert — le contour (et les trois autres horloges du dossier
   chauffe) animent des pixels **invisibles**. Même famille que `693f0ee`
   (« on ne rend plus ce qui est déjà invisible ») et que le piège du rideau.
2. **Un contour PAR PAGE.** Se balader en séance = chaque onglet visité paie
   le sien au-dessus de SON composite ; la fiche exo peut en empiler un
   deuxième au-dessus de celui d'Exercices. ⚠️ Les onglets NON visibles d'un
   `TabView` battent-ils aussi ? **Non prouvé** — une sonde d'une ligne le
   dira au moment du chantier.

### MISE À JOUR 03-09 après-midi — le téléphone et l'inventaire ont parlé

Source : barreau `-sansBord` joué par la session 07 sur l'appareil, puis son
inventaire à 34 agents (`tools/nav/ANALYSE-CHAUFFE-GESTES.md`, 13 items ;
relevés au registre `CHAUFFE-HOME.md` §6).

- **Verdict `-sansBord` (Kathryn, device)** : « un peu retombée, mais ça
  chauffe quand même » → le ruban CONTRIBUE mais n'est pas seul — la chauffe
  est une **addition**, et son poste n°1 est ailleurs : **5 décodeurs vidéo
  empilés** parce que le `TabView` garde les onglets montés (DepartCine ×2,
  ExosFond, ProgressPage ×2) + 3 chemins de réveil au déverrouillage
  (item 1, pris par la session 07).
- **La question ouverte du §8 est tranchée** : les onglets non visibles
  RESTENT montés (et leurs vidéos décodent). La porte de visibilité d'onglet
  **existe désormais** : `\.ongletCache` (clé `OngletCacheKey` définie dans
  `NavEncre.swift`, posée par `WoopApp` sur les 4 contenus d'onglet,
  ~1071-1110 ; consommateurs déjà branchés : WorkoutPill, GrandeCardExos,
  ProgressPage, `\.dort` composé pour la home). **BordSeance s'y branche**
  (item 5a) : un `@Environment` + un `&&` dans le `if actif`.
  ⚠️ **ORDRE DE COMMIT** : la clé vit dans le lot NON COMMITÉ de la session
  07 (NavEncre/WoopApp/PageCard) — committer un BordSeance qui la référence
  AVANT son lot recréerait le piège « main ne compile pas seul » (a3cce83).
  Le 5a ne part qu'APRÈS son commit.
- **Le doublon est CERTAIN** : la fiche poussée dans le `NavigationStack`
  d'Exercices monte un **2ᵉ ruban dans le même onglet**
  (`ExercisesView.swift:477` et `:535`, cotes de son arbre) — indépendant du
  litige des onglets cachés. À tuer au J1 (item 5b).
- ⚠️ **NE PAS remonter BordSeance au châssis** malgré son en-tête (`:8`,
  commentaire PÉRIMÉ de la version plein-écran) : `bandeVisible` varie par
  page. Le plan frère-dans-PageCard reste le bon ; l'en-tête sera corrigé au
  passage.
- La pièce/gyro reste le suspect ① pour le RÉSIDU de chauffe — barreau
  `-sansPiece` + `figee` dynamique + refcount SkyMotion : item 6, chez la
  session 07.

---

## §5 — LA CIBLE : le même style, sans horloge

Le principe : **plus aucune `TimelineView`, plus aucune ré-évaluation par
image.** Tout ce qui bouge devient une animation `repeatForever` posée UNE
fois — le patron maison, validé trois fois (`BadgeSetsNeon`,
`PageCard.swift:367-374` ; le liseré de la molette ; la barre blanche du
player). ⚠️ Avec son caveat écrit (`PageCard.swift:258-261`) : « un
`repeatForever` posé par `withAnimation` se fait avaler quand le parent est
ré-évalué » → la vue est une FEUILLE isolée, réarmée par
`onChange(of:initial:)` comme le badge.

1. **La rotation** : la nappe devient un PLAN carré de dégradé angulaire FIXE
   (côté ≥ diagonale de la card), en `.rotationEffect` animé
   `.linear(duration: 9).repeatForever(autoreverses: false)`. Rien à
   recalculer, jamais : l'interpolation vit dans le graphe de rendu, à la
   cadence NATIVE de l'écran — le pas d'horloge (§1.1) meurt par construction.
2. **Le ruban** : UNE SEULE couche. L'anneau (la forme de la robe, profil
   d'épaisseur continu : vif au bord, falloff doux vers l'intérieur, fondu
   haut compris) est **CUIT une fois en image** — le précédent maison des
   « textures BAKÉES » — et sert de MASQUE au plan qui tourne. Plus de flous
   vivants, plus de sommets multiples : **les « trois traits » meurent par
   construction.**
3. **La « tête » de la lumière** : elle revient DANS les stops de la nappe —
   une crête ASYMÉTRIQUE (bord d'attaque franc, traîne longue) fait une
   comète sans empiler des couches déphasées.
4. **Le souffle** : deux groupes d'opacité imbriqués, `easeInOut` 6,1 s et
   9,7 s en `autoreverses` — les deux périodes incommensurables tiennent, le
   plancher 0,40 aussi. ⚠️ Nuance honnête : aujourd'hui les stops > 1
   (écrêtés) gardent le cœur blanc quand `f` baisse ; en opacité de couche,
   tout baisse ensemble. Si ça se voit, le remède est un fondu croisé entre
   deux nappes cuites (douce/vive) — toujours sans horloge.
5. **Le montage** : en FRÈRE au-dessus de `pageEnCard`, plus jamais dedans
   (la piste ① de §F.4, dont le 1er jet a débordé dans la bande noire). La
   géométrie juste s'obtient **par construction, pas par re-dérivation** :
   reproduire la chaîne exacte de la card avec un contenu transparent —
   `Color.clear` + `.overlay { ruban }` + `.clipShape(robeCard)` +
   le MÊME `.padding(.bottom, bandeVisible && enSeance ? bandeH : 0)` et les
   MÊMES `.animation` — c'est le `padding(bandeH)` manquant qui a fait
   déborder le jet d'hier.
6. **Les gardes de l'invisible** : `actif = enSeance && !PlayerEtat.ouvert`
   (le contour s'endort sous le player déployé, §4.1) ; et selon la sonde
   §4.2, une pause quand l'onglet n'est pas à l'écran.

### Et le « gros ruban » du flanc (§2) — DEUX options, à trancher PAR ELLE

- **a. Rester angulaire, assumé** : crête resserrée, profil cuit — le ruban
  reste plus large au flanc qu'au coin (c'est la nature de l'angulaire), mais
  lisse, en une seule bande, sans marches. Zéro géométrie nouvelle.
- **b. La comète à VITESSE ET LARGEUR CONSTANTES** (longueur d'arc) : une
  `CAShapeLayer` du chemin de la robe, comète par `lineDashPhase` animée en
  `CABasicAnimation` (serveur de rendu, zéro fil principal). Plus fidèle à
  « une lumière qui fait le tour », mais une pièce UIKit de plus. (Le `trim`
  SwiftUI ferait pareil MAIS re-génère le path à chaque image au fil
  principal — moins bon.)

**Deux bancs côte à côte (`-bordSeance`), deux films, son œil tranche.**

---

## §6 — CE QUE ÇA NE RÈGLE PAS : la chauffe globale

Le ruban n'est qu'UNE des quatre horloges du dossier chauffe. « Tout chauffe,
je peux pas me balader dans l'app » peut tenir surtout à la pièce du trésor
(gyroscope, invisible au simulateur — suspect n°1), au galet à cadence libre,
à la fumée d'invite. **Le protocole de `CHAUFFE-HOME.md` §1 reste entier** :
quatre lancements de 2 min sur le téléphone, UN drapeau à la fois, la main
sur le dos de l'appareil. Refaire le ruban sans ce verdict peut ne rien
changer à la chaleur.

---

## §7 — L'ORDRE DES GESTES (quand elle dira go)

| jalon | geste | preuve |
|---|---|---|
| J1 | les gardes de l'invisible : player déployé ; TUER le doublon de la fiche (item 5b) ; brancher la porte d'onglet de la session 07 dès qu'elle existe (item 5a) | invisible à l'œil par construction ; chaleur |
| J2 | le frère à géométrie par construction (rendu inchangé) | capture avant/après identique |
| J3 | la nappe cuite UNE couche + `repeatForever` (plus d'horloge) | film au banc `-bordSeance` + téléphone |
| J4 | le choix de crête a/b (§5) | deux films côte à côte, son verdict |
| J5 | le protocole chauffe 4 interrupteurs pour le résiduel | la main sur le dos, 10 min |

---

## §8 — CE QUI N'EST PAS PROUVÉ ICI

- ~~Aucune cadence mesurée~~ → **le barreau `-sansBord` a été joué au
  téléphone** (03-09 après-midi, session 07) : chaleur « un peu retombée,
  mais ça chauffe quand même » — le ruban contribue, sans être seul (§4,
  mise à jour). Les §1-§3 restent fondés sur l'arithmétique et sa capture.
- La part exacte fil principal / serveur de rendu d'un `repeatForever` sur ce
  montage : se juge à l'instrument, sur téléphone, au moment de J3.
- ~~Les onglets non visibles d'un `TabView` : battent-ils ?~~ → **tranché**
  par l'inventaire de la session 07 : ils restent montés (5 décodeurs vidéo
  empilés — `ANALYSE-CHAUFFE-GESTES.md`, item 1).
- Le banding des zones mortes (alpha 0,015) : hypothèse de second ordre.
- Le rendu de la nappe cuite : « identique au style validé » se juge à la
  capture, pas sur ce papier.
