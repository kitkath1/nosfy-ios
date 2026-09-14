# LE RASANT — LA HOME EN SÉANCE, V3 (06-09)

> **Rien n'est codé depuis son 0/10.** Ce plan remplace la partie design des V1/V2 ;
> le diagnostic du calque (mesuré) reste au `PLAN-FOYER-V2.md §1`, les faits de code
> vérifiés au `PLAN-FOYER.md`.
>
> **Méthode** : quatre directions dessinées indépendamment (la profondeur · la
> matière · l'éclairagiste · la nuit), deux juges (son goût / l'ingénieur), deux
> contradicteurs (le piège du calque, rejoué à l'arithmétique · le coût réel).
> **Son goût couronne LE RASANT (84)** ; l'ingénieur couronne LA DALLE BROSSÉE (76)
> pour son fond cuit. Le plan ci-dessous est **LE RASANT, avec le fond de LA DALLE
> greffé dedans** — les deux juges demandaient précisément cette greffe.
>
> Ses contraintes du jour, en plus du brief : **« pas de braises marrons !! on a
> jamais voulu cette couleur, c'est ROUGE BLANC NOIR »** (mesuré vrai : la braise
> actuelle est à G/R = 0,52, un rouge est ≤ 0,22) · **« pas de pastille dans la
> Dynamic Island, c'est redondant »** (le contrat de l'île vit chez la session
> pastille ; sur CET écran, la pastille ne s'affiche pas — gate au châssis).

---

## §0 · L'IDÉE

**Il n'y a qu'une lampe dans cet écran : le feu, en bas à gauche.** Tout ce qu'on
voit — le bord d'une dalle floue, la lèvre du bouton, la pente des chiffres du
chrono — n'est que ce que cette lampe atteint. Ce qu'elle n'atteint pas est à
**#000000, littéralement, sur la moitié de l'écran**.

Et comme la séance dure, **la lumière MONTE** : les widgets flous du milieu ne sont
pas posés là, ils **SORTENT du noir minute après minute**. La progression de la
séance est racontée par ce que la lumière révèle — pas par une jauge.

Le fond n'est pas une nappe : c'est une **matière** — le grain brossé vertical de la
Dalle, cuit une fois en image, multiplié par l'enveloppe du feu. Une matière a des
creux à zéro ; elle ne PEUT pas redevenir un aplat.

---

## §1 · LES LOIS DE L'ÉCRAN — chacune se vérifie à la pipette, aucune ne se discute

1. **UNE SEULE LAMPE.** Rien ne brille par le haut. Si un pixel brille au-dessus du
   plafond de lumière, une deuxième lampe s'est glissée dans la pièce et on la tue.
   ⚠️ Il y en a deux aujourd'hui : **l'île de la pastille** (le halo orange en haut
   des captures) — le gate la retire de cet écran — et tout fond hérité de la home.
2. **LE TEST D'EXTINCTION est la porte de tout verdict** : `-sansFlammes` ⇒ l'écran
   devient **littéralement noir sauf le texte**. Un calque survit à l'extinction de
   sa source ; de la lumière, non. Aucune capture ne se juge avant celle-là.
3. **DU VRAI NOIR** : ≥ 45 % de la hauteur à #000000 exact (V1 mesurée : 2,3 % sous
   8/255, médiane 24). Et le gradient existe dans les DEUX axes : ≥ 25 niveaux de
   bas en haut, ≥ 12 de gauche à droite à hauteur égale (V1 : 1 et 0).
4. **ROUGE · BLANC · NOIR — l'orange est interdit.** Tout pixel de feu est soit
   BLANC (G/R ≥ 0,80 — les crêtes), soit ROUGE (G/R ≤ 0,22 — les corps), mesuré sur
   les pixels CLAIRS de chaque zone. La bande 0,30-0,60 est celle du marron : la
   rampe actuelle y vit (stop à vert 0,54 → G/R mesuré 0,52), la nouvelle la
   traverse **vite** (crête blanche fine, corps rouge). Et R ≥ B partout, toujours.
5. **JAMAIS FROID SOUS CHAUD** : aucun pixel où B > R (le calque V1 était bleuté
   sous un haut chaud — c'est ce qui trahit un objet posé).
6. **LA LOI DE CHUTE** : la lumière d'une dalle tombe à **zéro avant 40 % de sa
   hauteur**. Sinon trois zones tièdes se rejoignent et on refait la V1 avec des
   coins arrondis. C'est une loi, re-mesurée à chaque changement d'alpha.
7. **UNE SEULE HORLOGE À L'ÉCRAN : la braise.** Le chrono passe à
   `Text(timerInterval:)` **natif** (le système avance les chiffres, le body n'est
   jamais ré-évalué). Tout le reste est valeur animable posée une fois — et le
   souffle du fond est une **opacité de calque** (0,86 ↔ 1,00, 7,3 s), jamais un
   rayon, jamais un redessin.
8. **ZÉRO VERRE NATIF, zéro capitale de section.** « ● SÉANCE EN COURS » meurt —
   un point de 5 pt qui respire suffit (sa propre règle des chambres : « zéro
   séparateur, zéro majuscule de section »). Le compte de séries dit déjà que ça
   tourne.

---

## §2 · LA COMPOSITION — une seule arête, x = 24, cotes en fractions de B

`B` = hauteur réelle du slot de page (709 sur iPhone 15), **jamais**
`UIScreen.bounds.height`. Le bouton et les cibles vont de x=24 à W−24 ; leur bord
GAUCHE tient l'arête.

| y (iPhone 15) | pièce |
|---|---|
| 34 | **le point** — 5 pt, blanc, x=24, respire en opacité (2,9 s). Seul. |
| 74 → 218 | **la phrase** — `PhraseVue` inchangée : 4 fragments, clair/sourd, Inter 30, x=24. ~~Le souffle continu MEURT (§6)~~ → **il REVIENT, tranché par elle (§12.4)**. |
| 250 → 432 | **LA CHAMBRE — les widgets flous, « au milieu, qu'on aperçoit »** : trois dalles à x=24, qui SE RECOUVRENT — W3 188×68 (la plus loin) · W2 246×84 · W1 312×108 devant. §4. |
| 462 → 520 | **le chrono** — x=24, 80 pt ultraLight, `monospacedDigit`, format heures. `foregroundStyle` en dégradé vertical blanc 0,96 (bas) → 0,62 (haut) : **les chiffres sont éclairés par en dessous**. ⚠️ Greffe des deux juges : il **CHEVAUCHE W1** — des chiffres nets posés DEVANT un objet flou, c'est la preuve de profondeur en un coup d'œil. Cible = tout le bloc 345×74 → ouvre le player. |
| 534 → 550 | **la barre des séries** (§5) |
| 570 → 628 | **le bouton** — `BoutonPrimaire("Choisissez un exercice")`, pleine colonne, + LA LÈVRE : un arc de 1 pt sur les 140° bas, blanc chaud α 0,34 → 0. On ne l'éclaire pas, on le RASE. |
| 640 → 656 | **« Terminer la séance »** (§7) |
| 668 → 709 | **la braise** — 41 pt, 11 colonnes, flou 7 (rapport 0,171 ≈ la loi 0,16), 20 Hz au pas commun, `fige: dort`. **Plancher : elle ne monte jamais au-dessus de `terminerBas + 10`.** |

Le « grand vide » de 35 % n'existe plus : **il EST la chambre**.

---

## §3 · LE FOND — la matière, cuite, et pas une nappe

**La réverbération n'est plus un dégradé lisse** (un lisse plein écran reste une
passe de mélange par image, et à un cheveu d'un aplat) : c'est **la greffe de la
Dalle** — une tuile de **grain brossé vertical** (colonnes de 1-4 pt, crêtes 4 →
14/255, **R = G = B dans la tuile**), multipliée par :

- **l'enveloppe verticale du feu** — six stops, du bas vers le haut, avec un **stop
  explicite à ZÉRO** (pas une queue asymptotique). Les MINUTES portent le plafond :
  `uPlafond = 0,62 − 0,20 · min(1, minutes/45)` — la lumière monte avec la séance.
  Les SÉRIES portent la force : `α₀ = 0,100 + 0,060 · paliers[series]`.
- **la cloche horizontale** `h(x) = 0,35 + 0,65·exp(−((x−0,34W)/0,55W)²)` — le foyer
  est décentré **à gauche**, du même côté que l'arête du texte : tous les objets
  sont éclairés depuis le bas-gauche. ⚠️ La cloche est **fusionnée dans la cuisson**,
  jamais un `.mask` (une passe plein écran de plus).

**Le tout est CUIT en une image** (grain × enveloppe × cloche, teintée rouge —
§1.4), à la résolution **native** (⚠️ contradicteur : une tuile étirée ×6 lisse le
grain et garantit le banding). Ce qui vit : son **opacité** (le souffle, 0,86 ↔
1,00, 7,3 s) et un `offset` lent. Deux valeurs animables, zéro redessin. La cuisson
se fait **hors des moments chauds** (jamais pendant une transition).

⚠️ **Ce que le fond n'a PAS le droit d'avoir** : un grain additif PLEIN écran (à
0,02-0,03 il pose 5-8/255 partout et tue le « vrai noir » — le grain n'existe que
DANS la zone éclairée, il est dans la cuisson) ; un blend additif plein écran ; un
rayon animé ; un capteur (pas de CoreMotion : un scalaire écrit 20×/s est le régime
à 33-38 %).

---

## §4 · LA CHAMBRE — les widgets flous, et la réfraction

⚠️ **On ne floute pas de vraies cards** : sans verre elles sont OPAQUES (bezel
0,014) et elles assombrissent ; avec verre on rallume le poste n°1. Les dalles sont
des **SILHOUETTES** : les formes des widgets de la home (rayon `0,1175 × largeur`,
comme `CardCorps`), **dessinées comme des bords de lumière, pas comme des plaques**.

Chaque dalle, du plus loin au plus près (W3 → W1) :

1. **l'arête que la lumière rase** — un contour 1,1 pt dont **seule la lèvre basse
   brille** (blanc chaud, α 0,30 en bas → 0,012 en haut) ;
2. **LA RÉFRACTION** — le cœur de sa demande : dans la dalle, **une copie du dégradé
   de la braise qui a traversé le verre** : mêmes couleurs exactes (prouvable à la
   pipette), **écrasée** (`scaleEffect(y: 0,30, anchor: .bottom)`), **remontée de
   10 pt** (une vitre DÉPLACE l'image — c'est la signature optique d'une
   réfraction), floutée 16, masquée par la forme. Opacité × distance (1,00 / 0,58 /
   0,31) × chaleur des séries. À 3 séries sur W1 : un pic rouge à contraste 3,3:1
   sur son fond local — **on la voit**. Sur W3 : on la devine ;
3. **le nombre de séries en gros chiffre deviné** (Inter 62 semibold, blanc 0,20)
   dans W1 — les widgets flous ne sont pas de la décoration, ils portent une
   information qu'on connaît déjà, lisible à trois distances (net sous le chrono /
   deviné dans la dalle / senti par la chaleur) ;
4. **la loi de chute** (§1.6) : tout tombe à zéro avant 40 % de la hauteur.

**Le flou est à rayon FIXE, le contenu est FIGÉ** → un `compositingGroup` par
dalle, payé une fois — **si l'hypothèse du §9.1 tient**. Les dalles ne bougent que
par offset (2-3 pt, périodes 13-23 s, premières entre elles).

---

## §5 · LA BRAISE ET LES SÉRIES — rouge, blanc, noir

**LA RAMPE CHANGE** (elle est à moi maintenant — la vague n'est plus montée que
dans le grand player) :

| stop | aujourd'hui | cible |
|---|---|---|
| crête | blanc | blanc, **fine** |
| corps | (1 · 0,54 · 0,18) → **G/R 0,52 = marron** | **(1 · 0,18 · 0,08) → G/R ≤ 0,22 = rouge** |
| base | (1 · 0,20 · 0,05) | (1 · 0,07 · 0,03) — rouge profond |

Vérifié **au relevé sur les pixels clairs**, jamais à l'œil — même script que la
mesure qui a condamné le marron. ⚠️ Conséquence pour le grand player (seul autre
client) : plus rouge, un peu moins lumineux à surface égale — la session pastille
est prévenue.

**LA BARRE DES SÉRIES** (y 534, x 24) — « il manque le nombre de séries faites » :

- un **trait par série faite** (3×16 pt, blanc 0,88) ; **trois traits « à venir »**
  à blanc 0,10 — une suite, pas une jauge, pas un objectif ;
- **le dernier trait fait est encore CHAUD, et il refroidit** : halo rouge α 0,30 →
  0 en 40 s, linéaire, armé par `.task(id: series)` — une animation qui s'arrête
  toute seule ;
- ⚠️ greffe du juge : **les trois derniers traits** portent une chaleur décroissante
  (0,45 / 0,30 / 0,18 vers la gauche) — le RYTHME se lit sans un mot ;
- à droite : `3 séries` — le chiffre blanc 0,86, le mot blanc 0,34, **pas de
  capitales espacées** ;
- source : `Workout.seriesPayantes`, jamais `setCount`.

Compression au-delà de 24 : espacement 4 ; au-delà de 40 : un trait pour deux — la
barre ne fait jamais deux lignes.

---

## §6 · LE TEXTE — un écart déclaré

La phrase reste **exactement** ce qu'elle est (4 fragments, arrivée au flou qui se
résorbe, réécriture aux paliers **au sommet du flou** — les fade-in qu'elle a
demandés). **Mais le souffle continu MEURT** : les deux juges et deux directions
l'ont condamné (un balayage permanent sur un écran d'éclairagiste est un effet de
landing page, et c'était un masque animé plein bloc).

⚠️ **C'est un écart avec sa demande du 05-09** (« un texte qui bouge en continu
comme une IA ? » — avec un point d'interrogation). Ce qui « bouge » désormais :
la phrase **se réécrit** aux événements, la lumière **monte** sous elle. Si elle
veut le balayage quand même : il revient en une ligne, au banc, en A/B.

---

## §7 · « TERMINER » — une action, plus une étiquette

- **« Terminer la séance »** — un verbe seul est une étiquette, un verbe + son objet
  est une action (la grammaire Apple) ;
- Inter 13,5 medium, **blanc 0,52** (V1 : 0,38) — de « décor » à « lisible » sans
  passer par « lampe » ;
- **encre NEUTRE sur SOL CHAUD** : sa lisibilité vient de son sol (la réverbération
  du feu à cet endroit ≈ (24,14,8)), jamais chaud-sur-chaud (ça flirte avec le
  brun) ;
- cible **345 × 44** pleine colonne, `contentShape` + `highPriorityGesture`, jamais
  un `Button` ;
- au tap : `Haptique.leger()` → la carte de stop existante. Zéro chemin neuf.
- *(au banc, en A/B : le filet de 14 pt à gauche du texte — du chrome, ne se commite
  pas d'office.)*

---

## §8 · CE QUI MEURT — et le commit le dit

`LueursFoyer` (le calque) · `SouffleTexte` (le masque animé plein bloc) ·
`SigneSeance` avec son libellé en capitales (le point seul survit) · la nappe
`teinte` posée par-dessus la braise (elle rentre DANS la rampe, au même endroit que
la couleur) · **la pastille et son île sur cet écran** (gate au châssis — la
deuxième lampe) · toute cote depuis `UIScreen`.

---

## §9 · LA MESURE AVANT LA PREMIÈRE LIGNE — deux hypothèses portent tout

1. ⚠️ **« Un flou à rayon FIXE sur du contenu FIGÉ est rasterisé une fois puis
   translaté » n'a JAMAIS été mesuré dans cette maison** (la loi existante couvre le
   rayon animé). Les quatre directions — et ce plan — reposent dessus. **Le banc de
   trente lignes se joue d'abord** : une forme floutée figée + `offset` + `opacity`
   animés, `./tools/charge.sh`, sonde, téléphone. Si ça tombe, la chambre change de
   technique (dalles cuites en PNG) — pas de composition.
2. **Prouver que la home est DÉMONTÉE, pas couverte** (compteur dans un body, ou
   `SondeVol`) : le budget est à **zéro** (écran nu 1 %, page immobile 27-39 %) et
   plus aucun chiffre ne se donne « contre la V1 » — la seule économie réelle est ce
   qui tournait et ne tourne plus.

---

## §10 · LES JALONS — le test d'extinction est la porte de chacun

| jalon | geste | preuve |
|---|---|---|
| **J0** | Les DEUX mesures du §9. | Les chiffres, téléphone froid, paire (cadence · processeur · thermique · n). |
| **J1** | **Le noir** : tout ce qui meurt (§8) meurt ; le fond cuit (§3) ; la braise passée au rouge (§5). | **Test d'extinction** (`-sansFlammes` ⇒ noir littéral) + pipette : ≥ 45 % à #000000, gradients ≥ 25/12 niveaux, G/R ≤ 0,22 corps · ≥ 0,80 crêtes, aucun B > R. |
| **J2** | **La colonne** : tout à x=24, chrono chevauchant W1, barre des séries, « Terminer la séance ». | Capture + juge de cotes sur l'arête réelle. **C'est le jalon du goût.** |
| **J3** | **La chambre** : les trois dalles, la réfraction, le chiffre deviné. | Les **12 vignettes 40×40** : refus si σ < 1,5/255 dans un vide (aplat) ou si un pixel hors silhouette/braise > 10/255 (nappe). Extinction re-passée. |
| **J4** | Les **7 paliers** (`-foyerPalier 0…6`) — le mode d'échec d'un écran qui chauffe est **en fin de course** (la capsule cerclée d'orange = néon). | 7 captures, relevé G/R sur chacune. |
| **J5** | Téléphone, 2 min de séance vraie, main sur le dos. | La paire de chiffres + son verdict. |

**Chaque jalon est montré avant le suivant. Rien n'est commité avant son œil.**

---

## §11 · À TRANCHER PAR ELLE

1. **Le souffle du texte** : mort par défaut (§6) — le veut-elle quand même ?
2. **Le filet devant « Terminer la séance »** : A/B au banc.
3. **Le morph d'arrivée** (pastille → page) : toujours en attente de D1 du V1 — il
   se montre seul, en film, et pas avant J2.
4. **Le gros chiffre deviné dans W1** : si à l'écran il se lit trop (ou pas assez),
   c'est un réglage d'opacité qu'ELLE donne sur capture.

---

## §12 · LES RETOUCHES DU VERDICT `rasant-03` (dicté le 06-09, après le go)

Ses mots : « tu as pris l'ancien overlay » · « on voit pas assez les flammes » ·
« on comprend pas qu'on peut cliquer — au tap mets une sorte de halo blanc ou
autre ! » · « anime le texte devant avec effet de blur ou animation noir dans le
background ».

1. **L'« ancien overlay » n'est pas un défaut de design — c'est un build en
   retard.** Le câblage tap-chrono → `ouvrirGrandPlayer()` (le dernier composant)
   était déjà écrit quand elle a testé ; l'arbre ne compilait plus (le faux mur —
   en réalité un **ordre d'arguments inversé** dans l'init memberwise, qui
   déclenche la recherche d'overloads la plus chère au lieu d'une erreur nette :
   diagnostic de la session pastille, leçon nouvelle pour tout le monde).
   Corrigé + le call site **découpé** en `ongletHome` (prophylaxie du vrai mur).

2. **LES FLAMMES, PLUS PRÉSENTES.** Deux crans à montrer côte à côte, elle
   tranche sur capture : ① `force` plancher 0,40 → **0,55** ; ② idem + hauteur
   41 → **56 pt** (flou 9, le rapport 0,16 tenu). Le plancher reste :
   jamais au-dessus de `terminerBas + 10`.

3. **LE HALO DE TAP** — l'affordance du bloc-chrono : **au toucher**, un halo
   blanc doux naît sous le bloc (dégradé radial pré-peint, **opacité seule**
   0 → 0,14, 0,12 s à l'attaque, 0,35 s à l'extinction au relâcher) — DÉCLENCHÉ,
   jamais en boucle, zéro flou vivant, zéro passe. Même geste que le reste :
   `DragGesture(minimumDistance: 0)` pour sentir la prise, jamais un `Button`.

4. **LE TEXTE ANIMÉ DEVANT — le souffle REVIENT.** L'écart du §6 est tranché par
   ELLE (« anime le texte devant ») : le balayage revient, dans sa seule forme
   licite — un dégradé FIXE plus large que le bloc, déplacé par `.offset`
   (l'école D2), période lente (~7 s), amplitude discrète (0,74 → 1,0).
   ⚠️ **Pas un rayon de flou animé** (loi du skill : jamais mis en cache) — le
   « blur » vivant reste celui des réécritures aux paliers, qui existe déjà.
   Et l'« animation noir dans le background » : le **rideau de noir** qui dérive
   sur le grain (soustraction pure, incapable de lever un pixel) passe de
   théorique à réglé-pour-se-voir — deux voiles noirs lents (61 s · 89 s) sur la
   zone éclairée SEULEMENT.

**Preuves du lot** : capture des deux crans de flammes · film 8 s du halo de tap
(attaque/extinction) · film 10 s du souffle · re-passage du test d'extinction et
des pipettes du §10-J1 (le souffle et le rideau ne doivent pas changer UN chiffre
des critères de noir).
