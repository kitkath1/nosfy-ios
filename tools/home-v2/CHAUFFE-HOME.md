# LA HOME CHAUFFE EN SÉANCE — dossier de débogage (02/03-09)

> **Verdict de Kathryn, sur son iPhone 15 :** « le téléphone chauffe et lag
> énormément » pendant une séance.
>
> Ce document existe pour qu'une autre session puisse trancher **sans refaire
> ma journée**. J'ai produit six hypothèses bien argumentées et fausses ; la
> seule chose qui vaille ici est le protocole et les ancres.

---

## 0. ⚠️ LA PREMIÈRE CHOSE À SAVOIR : L'INSTRUMENT EST CASSÉ

**Le simulateur ne mesure pas cette page.** Même binaire, machine calme
(`./tools/charge.sh` vert), à quelques minutes d'intervalle :

| | relevés successifs |
|---|---|
| home au repos | **8,7 · 18,7 · 5,6** img/s |
| séance | **4,5 · 5,1 · 6,5 · 10,0 · 12,2** img/s |

Et le coup de grâce, sur une version intermédiaire : **contour ALLUMÉ 12,2
img/s, contour ÉTEINT 8,0**. Le contour rendrait la page *plus rapide* — ce qui
est impossible. **Le bruit dépasse l'effet.**

→ **Ne conclus RIEN d'un relevé simulateur sur la home.** Tout ce qui suit se
juge sur le TÉLÉPHONE, à la chaleur et à l'œil.

Et une raison structurelle s'ajoute au bruit : **le gyroscope est mort au
simulateur**. Un des suspects ci-dessous n'y coûte donc rien par construction.

---

## 1. LE PROTOCOLE — dix minutes, une certitude

Quatre interrupteurs existent, **additifs et éteints par défaut** : ils ne
changent rien au comportement de l'app.

| drapeau | éteint | ancre |
|---|---|---|
| `-sansBord` | le contour de séance | `BordSeance.swift` |
| `-sansPiece` | la pièce du trésor (30 Hz **+ gyroscope**) | `CoffreFortCoin.swift` |
| `-sansGalet` | l'horloge à cadence libre du galet actif | `CardRoute.swift` → `GaletEtape.figee` |
| `-sansInvite` | la fumée d'invite (30 Hz **à opacité zéro**) | `HomeNuit.swift` |

**Le geste :**

```
# la référence
xcrun devicectl device process launch --device <UDID> fr.kathryn.woop \
  -- -skipAuth -homeSeance
# puis UN SEUL drapeau à la fois
… -- -skipAuth -homeSeance -sansPiece
```

Deux minutes de séance à chaque fois, main sur le dos de l'appareil. **Celui
qui fait tomber la chaleur est le coupable.** ⚠️ Un seul à la fois : deux
drapeaux ensemble ne disent pas lequel des deux comptait.

---

## 2. LES QUATRE SUSPECTS — vérifiés par LECTURE, pas par grep

### ① La pièce du trésor — le seul que le simulateur ne peut PAS voir

`MoonCoinLab.swift:60-63`, mot pour mot :

> « un abonnement au `tilt` d'un `@Observable` qui **réévalue toutes les
> pièces** au rythme du gyroscope — **invisible au simulateur (le tilt y reste
> nul), payé sur le téléphone** »

- `CoffreFortCoin.swift` monte `MoonCoinView(coinR:matte:onTap:)` — **sans
  `figee:`**, donc régime vif (horloge 30 Hz + lecture du tilt) ;
- elle est montée sur la home (`HomeNuit.swift`, la pièce du coin haut-droit)
  **hors de toute garde** — ni `verreMonte`, ni séance : aucun `if` dans les
  40 lignes qui l'entourent.

**C'est le suspect n°1 par élimination logique** : c'est le seul dont le coût
est nul au simulateur et réel sur l'appareil, ce qui est exactement le profil
du symptôme.

### ② Le galet actif de la card chemin — le seul qui soit NEUF

- `GaletEtape.swift` : sa `TimelineView` est en **`minimumInterval: nil`** —
  cadence libre, donc celle de l'écran ;
- `pauseTimeline` (`:415`) rend **`false`** dès que `etat == .actif` — il ne se
  met donc jamais en pause sur le nœud courant ;
- il porte en plus un `glassEffect(.clear)` et **quatre `.blur`**.

⚠️ **Et c'est une conséquence directe d'un changement du 02-09** : la card
chemin a été montée pendant la séance (`if verreMonte || enSeance`, commit
`7c697e6`) pour que le texte vivant ait quelque chose à animer. **Avant, cette
card n'était pas montée en séance, donc ce galet ne tournait pas.** C'est le
seul suspect dont on sait qu'il n'existait pas la veille.

### ③ Le contour de séance

`BordSeance.swift` — trois couches floutées, 20 Hz, montées **en `.overlay`
DANS `pageEnCard`** (`PageCard.swift`). Voir §3 : ce n'est probablement pas son
dessin qui coûte, mais son invalidation.

### ④ La fumée d'invite

`HomeNuit.swift` — `InviteTirage` est montée **sans garde de séance** : sa
seule protection est un `.opacity(enSeance ? 0 : …)`, et son horloge n'est
pausée que par `homeDort` (vrai **uniquement sous la page chemin**). Elle bat
donc à 30 Hz pendant toute la séance **pour peindre du vide**.

C'est exactement le péché que ce fichier dénonce lui-même vingt lignes plus
haut pour `FumeeInvite` : « MONTÉE, PAS SEULEMENT TRANSPARENTE — une
`.opacity(0)` ne l'arrêterait pas ».

---

## 3. LE MULTIPLICATEUR — pourquoi ce n'est pas une simple addition

Ces horloges vivent **dans ou au-dessus d'une card qui porte une vidéo vivante
et trois panneaux de verre natif**. Une capture de fond de verre natif force la
résolution en texture de tout le composite situé dessous — le dépôt l'a déjà
chiffré (`HomeNuit.swift`, la note sur `verreAt = 0.26`).

Ce n'est donc pas « sept horloges » : c'est **sept horloges × le prix d'une
recomposition**.

### 🔴 La preuve, et elle a coûté six essais

Pour le contour, j'ai essayé dans l'ordre : deux `.blur` plein cadre → sept
`strokeBorder` à dégradé angulaire → un **shader `colorEffect` d'UNE passe** →
cinq anneaux concentriques → des foyers dont seule l'opacité anime. **Les cinq
ont lagué.**

Le shader est la preuve décisive : une passe GPU, aucune couche empilée, ça
devrait être quasi gratuit. Ça ne l'a pas été. **Donc le coût n'est pas le
DESSIN — c'est l'INVALIDATION.**

> **Piste non tranchée** (essayée le 03-09, annulée pour un défaut VISUEL, pas
> de perf) : sortir le contour de `pageEnCard` pour le poser en **frère**
> au-dessus, découpé à la forme de la robe. Son horloge ne réveillerait alors
> que lui. ⚠️ Le premier jet **débordait dans la bande noire** sous la card —
> la géométrie du frère (`hPage` + `clipShape(robeCard)`) ne coïncide pas avec
> ce que l'`.overlay` donnait. **La piste reste bonne, son implémentation est à
> refaire.**

---

## 4. CE QUE JE N'AI PAS MESURÉ, ET QU'IL NE FAUT PAS SUPPOSER

- **Aucune mesure sur le téléphone.** Le classement ①→④ ci-dessus est un ordre
  de plausibilité, pas un résultat. Il peut être faux.
- **La part du GPU contre celle du fil principal** : `SondeCadence` compte les
  battements servis (`CADisplayLink`) — elle voit le fil principal, pas la
  chaleur GPU. Pour la chauffe, Instruments (Time Profiler + Metal) dirait
  quelque chose que ma sonde ne dit pas.
- **Les couches vidéo** : la home porte `home-fond-loop`, plus deux couches de
  `DepartCine`. Une couche `AVPlayerLayer` ne coûte presque rien (décodage
  matériel) — mais ce qu'un verre natif lui fait recomposer par-dessus, si.
  Non isolé, aucun interrupteur.

---

## 5. LES LOIS DU DÉPÔT QUI S'APPLIQUENT ICI

Toutes déjà écrites, toutes payées avant moi — je les répète parce que je les
ai enfreintes aujourd'hui :

- **`./tools/charge.sh` AVANT tout `-fps`** (🔴 au-dessus de 2). Je l'ai oublié
  deux fois et j'ai produit deux mesures à jeter, dont une qui accusait un code
  innocent.
- **« Un juge qui affirme ne remplace pas une sonde qui mesure. »**
- **« La vraie cadence se mesure sur le TÉLÉPHONE. »** Sur cette page, ce n'est
  pas une précaution : c'est la seule option.
- **`xcodebuild | grep` rend le code de grep.** Payé une fois de plus le 02-09
  (`install … | tail` → `EXIT=0` faux).

---

## 6. LES RELEVÉS TÉLÉPHONE (registre unique — sessions nav + BordSeance)

### Relevé 1 — 03-09 ~13h50, `-sansBord` seul (session nav)

- **Protocole** : app relancée sur l'iPhone 15 de Kathryn via devicectl,
  `-sansBord` SEUL, séance réelle en cours, ~2 min d'usage, main sur le dos.
- **Verdict de Kathryn (mot pour mot)** : « La chaleur est un peu retombée,
  mais globalement, ça chauffe quand même. » Le lag entre pages persiste
  (« quand je passe d'une page à l'autre, ça met du temps à charger, ça
  chauffe »).
- **Lecture** : le ruban `BordSeance` PÈSE (baisse sensible) mais n'est PAS
  seul — il reste au moins une autre source. Prochain barreau : `-sansPiece`
  seul (suspect ① du §3 : le gyroscope 30 Hz de la pièce), puis `-sansGalet`,
  puis `-sansInvite`.
