# TROIS PROPOSITIONS UX POUR LA HOME EN SÉANCE (14-09)

> Ses mots : « la hiérarchie va pas — rechallenge, il faut léger à la Apple et
> que le user comprenne direct. Je te laisse faire des propositions UX. »
>
> **Le diagnostic, mesuré au banc + lu sur sa capture** : (1) la « pression-
> porte » du §F est un geste que personne ne fait (poser-tenir-relâcher sans
> bouger : le banc à vrai doigt rend `overlay ouvert = false`) et rien ne
> l'annonce ; (2) quatre objets de même poids dans la moitié basse — rien ne
> domine ; (3) le chrono ultraLight ne pèse rien face au bouton blanc et au
> médaillon ; (4) carte+ticket = un objet décoratif sans lien lisible ; (5) deux
> actions primaires = pas de choix.

---

## LE PRINCIPE COMMUN AUX TROIS — une seule règle Apple

**Une donnée, une action, une sortie.** L'écran dit UNE chose (tu es en séance
depuis 24:52, 3 séries), propose UNE action évidente (continuer), et garde UNE
sortie discrète (arrêter). Tout le reste est du noir. Et **ce qui est tapable
ressemble à quelque chose qu'on tape** — pas à un chrono.

---

## PROPOSITION A — « LA CARD DE SÉANCE » *(reco)*

Le chrono, la date, les séries et l'accès au détail deviennent **UN SEUL
OBJET** : une card sombre, légèrement en relief sur le noir (la dalle
obsidienne de la maison, sans verre), à x = 24, pleine colonne.

```
┌──────────────────────────────────┐
│ 14 SEPT · en cours          ● │  ← petit, gris
│                                  │
│ 24:52                            │  ← LE HÉROS : 64 pt, weight regular
│ 3 séries                         │  ← 15 pt, blanc 0,55
│                                  │
│ Voir la séance               ›  │  ← la porte, LISIBLE : mot + chevron
└──────────────────────────────────┘

  [ Choisissez un exercice ]           ← BoutonPrimaire, pleine colonne

           ⏹  (petit, gris)            ← le médaillon redevient discret : Ø 44
```

- **La card ENTIÈRE est tapable** → le grand player. Le chevron « › » et le
  mot « Voir la séance » sont l'affordance : zéro invention, c'est la
  grammaire iOS que tout le monde lit.
- **Le chrono gagne du poids** : `regular` au lieu d'`ultraLight`, 64 pt —
  il domine enfin.
- **Le ticket « 3 SETS » meurt** ici (il vit dans le détail) : « 3 séries »
  en texte, sous le chrono, dans la même card — une donnée, pas un ornement.
- **Le médaillon redescend à Ø 44**, gris, en bas : une sortie, pas une
  deuxième action. (Le « 2× plus gros » d'hier servait à le VOIR ; dans cette
  hiérarchie, c'est la card qui le rend visible par contraste, pas sa taille.)
- La braise reste la seule lumière ; elle lèche le bas de la card.

*Pourquoi c'est la reco* : c'est la seule où l'utilisateur n'a rien à
deviner. Une card = un objet, un chevron = ça s'ouvre.

## PROPOSITION B — « LE CHRONO EST LE BOUTON »

Pas de card : le chrono lui-même devient une **capsule tapable**, très grande,
noire avec un liseré fin, le chevron à sa droite.

```
  ( 24:52  · 3 séries            › )   ← capsule 72 pt de haut, pleine colonne
  [ Choisissez un exercice ]
              ⏹
```

- Une capsule, ça se tape — l'affordance est dans la FORME.
- Plus léger que A (un objet de moins), mais la date et le sticker
  disparaissent de la home (ils vivent dans le détail).
- Risque : deux capsules superposées (chrono + bouton) se disputent — la
  hiérarchie tient par le contraste (chrono noir liseré / bouton blanc plein).

## PROPOSITION C — « LE GESTE iOS : TIRER VERS LE HAUT »

Le bas de l'écran porte une **poignée** (le trait système, comme une sheet) et
un mot : « Séance ›  ». On **tire vers le haut** pour révéler le détail — le
grand player monte du bas, ce qu'il fait déjà.

- Le geste le plus natif d'iOS pour « il y a quelque chose en dessous ».
- Garde le chrono en grand héros, seul, sans card.
- Risque : le drag du bas est déjà un territoire disputé dans cette app (nav
  tap-only, la pastille) — à vérifier au banc à vrais touchers AVANT.

---

## CE QUE LES TROIS ENTERRENT

- **La « pression qui allume l'écran »** (§F-B) : mesurée injouable au banc et
  illisible sur capture. On garde l'idée d'une RÉPONSE au toucher, mais comme
  un feedback (la card s'enfonce, `scaleEffect 0,98` à la pression — le
  langage iOS), jamais comme la porte elle-même.
- **L'impulsion périodique du ticket** (§F-A) : un objet qui bouge tout seul
  pour se faire remarquer, c'est un tic — pas Apple. Mort.
- **Le halo blanc au tap** : remplacé par l'enfoncement iOS standard.

## LES DEUX PRÉREQUIS, quel que soit ton choix

1. **Un poids par niveau** : héros (chrono) › action (bouton) › sortie
   (médaillon). Aujourd'hui ils sont à égalité — c'est ça, « la hiérarchie va
   pas ».
2. **Le « ▶ Nosfy » en haut à droite** (un hunk d'une session voisine) est
   un 4ᵉ objet tapable sur cet écran — il devra partir ou se ranger.

**Tranche A, B ou C** — je code la gagnante, capture à la clé.
