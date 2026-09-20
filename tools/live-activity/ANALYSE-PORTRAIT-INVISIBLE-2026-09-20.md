# Live Activity — le portrait « Nosfy aux yeux rouges » n'apparaît pas sur l'iPhone

Retour TestFlight de Kathryn, 20-09-2026, build 81 : « on voit pas l'image de
Nosfy aux yeux rouges sur l'écran iPhone ». Analyse seule, **rien codé**, sur
son ordre.

## Ce qu'elle voit

La Live Activity s'affiche (chrono, exercice, phase), mais la case du portrait,
à gauche de la grande carte de l'écran verrouillé et de l'île déployée, est vide.

## Ce qui a été mesuré

| Point | Mesure | Preuve |
|---|---|---|
| L'image est bien dans le build 81 | `Assets.car` du widget de l'archive contient `LiveNosfyPortrait` | `assetutil --info` sur `Nosfy-81.xcarchive/…/NosfyWidgets.appex/Assets.car` |
| Sa taille dans le build | **1448 × 1086 px, échelle 1, ARGB, 537 Ko** dans le catalogue compilé | idem |
| Le fichier source | copie sans retouche du Bureau (`nosfy_yeux_rouge.png`, 746 Ko), un seul slot `universal` sans 1x/2x/3x | `NosfyShared/LiveAssets.xcassets/LiveNosfyPortrait.imageset/Contents.json` |
| Où l'image est affichée | grande carte (64 pt) et île déployée (48 pt) ; compact et minimal montrent la **lune**, pas le portrait, par choix | `WorkoutLiveCard.swift:39-52`, `WorkoutLiveActivity.swift:16-41` |
| Le portrait a-t-il déjà été vu dans une vraie Live Activity ? | **Non.** Les captures du 18-09 viennent d'un banc SwiftUI dans l'app au simulateur ; « ActivityKit réel » est noté ouvert | `tools/live-activity/COMMIT-2026-09-18.md`, `proofs/portrait/muscu-hiit.png`, brique `b-flow-live-lune` |

## La cause (la plus probable, documentée par Apple)

Apple, documentation ActivityKit « Displaying live data with Live Activities » :

> The system requires image assets for a Live Activity to use a resolution
> that's smaller or equal to the size of the presentation for a device. If you
> use an image asset that's larger than the size of the Live Activity
> presentation, the system might fail to start the Live Activity.

Le portrait fait 1448 × 1086 px pour une case de 64 pt (192 px à 3×). Il est
vingt fois trop large en pixels pour la présentation. Sur l'iPhone, le système
refuse une image plus grande que la présentation ; au simulateur cette règle
n'est pas appliquée, et le banc du 18-09 dessinait le composant dans l'app, pas
dans ActivityKit. C'est pour ça que « ça marchait » et que ça ne marche pas
chez elle. Des développeurs mesurent la même chose sur le forum Apple : une
image de 1224 × 599 passe, 1224 × 600 casse (fil 722545, sans réponse d'Apple).

Ce que fait `.resizable().scaledToFill().frame(64)` n'y change rien : la règle
porte sur les pixels de la ressource, pas sur la taille affichée.

## Deux autres suspects, à écarter par mesure et non par avis

1. **`.blendMode(.screen)`** sur le portrait (`WorkoutLiveCard.swift:49`).
   Le rendu de la Live Activity est fait hors de l'app, par le système ; un
   mode de fusion sur un fond que le système compose lui-même n'est pas
   garanti. Sur l'île (noir) et sur la carte (teinte quasi noire) le résultat
   devrait être l'image telle quelle, mais ce n'est pas mesuré. À retirer le
   temps d'un essai si le redimensionnement seul ne suffit pas.
2. **L'attente sur l'île compacte.** En compact et minimal, c'est la lune qui
   est dessinée, jamais le portrait. Si Kathryn regardait l'île fermée, l'absence
   du portrait est le comportement voulu le 18-09, pas un défaut. À confirmer
   avec elle : grande carte de l'écran verrouillé, ou pilule fermée ?

## Ce qu'il faudrait faire (à son ordre, pas fait)

1. Refaire le portrait à la taille de sa case : 64 pt → trois rendus 64, 128 et
   192 px (1x, 2x, 3x) dans le même imageset, à partir du PNG du Bureau, sans
   toucher au fichier original. Le poids passerait de 537 Ko à quelques dizaines
   de Ko et la mémoire du widget respire.
2. Retirer `.blendMode(.screen)` ou le garder derrière un barreau
   (`-sansBlendPortrait`) pour l'accuser ou le disculper sur l'iPhone.
3. Mesurer sur SON iPhone, pas au simulateur : lancer une séance, verrouiller,
   lire la grande carte ; ouvrir l'île. Une capture par présentation.
4. Passer la brique `b-flow-live-lune` de 🔴 à 🟡 seulement après cette lecture.

## État posé sur le site

- `docs/site/content/briques.ts` : `b-flow-live-lune` → 🔴 (`etat: "men"`),
  litige complété avec cette cause.
- `docs/site/content/mesures.ts` : `m-live-portrait-iphone` ajoutée.

## Correctif posé le 20-09 (sur son « fix »), dans l'arbre, non commité

- `LiveNosfyPortrait.imageset` : `portrait@1x/2x/3x.png` = 64, 128, 192 px,
  coupe carrée centrée (1086 × 1086) du PNG du Bureau puis rééchantillonnage
  `sips` ; le PNG du Bureau n'est pas touché ; l'ancien fichier de 746 Ko retiré
  du catalogue. Poids : 3 + 9 + 19 Ko.
- `WorkoutLiveCard.swift` : `.blendMode(.screen)` retiré. Mesuré : les quatre
  coins et le bord du PNG sont noir pur (0,0,0), la carte est teintée à
  0,016 ; le fusionnage ne changeait rien à l'œil et restait un inconnu hors de
  l'app.
- Build app + widget pour le simulateur `nosfy-live-lune-20260918` : **BUILD
  SUCCEEDED** ; `assetutil` sur le widget compilé : `LiveNosfyPortrait`
  192 × 192 px, échelle 3, 12 Ko.
- **Non mesuré sur son iPhone.** Il faut une séance lancée, l'écran verrouillé
  (grande carte) puis l'île déployée. La brique reste 🔴 jusqu'à cette lecture.
