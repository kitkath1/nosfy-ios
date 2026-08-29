# LA CARD « STOP » — le player pose sa question dans la lumière

**Plan du 29-08-2026, sur la demande de Kathryn** : *« rebosser l'overlay pour
stopper la session : c'est le même composant qui va être appelé dès que le user
clique sur stop dans le player, mais on va le transformer en pop-up. Un gros
"STOP" big text avec un spotlight dessus comme la card pop-up variant, texte
bien fondu comme ce screenshot [You Made It]. Devant, la vidéo de la
chauve-souris en continu (détourée), un titre et un sous-titre, et dessous
notre slider noir (celui de la homepage) où il y a écrit STOP, et un bouton
lien Cancel. Vidéo : ~/Downloads/chauve-souri_stop.mp4. Fais un plan, ne code
pas. Fais un magnifique design. »*

**Rien n'est codé.** Ce qui existe : la maquette aux cotes réelles
(`vignettes/maquette-v1.png`), la silhouette statique de la bête mesurée sur
les 121 images (`vignettes/matte-union-statique-1080.png`), et un simulateur
dédié **kat-stop** (`E9241D2D-EB46-43C8-A76A-DE5319DE48D6`, iPhone 17 Pro, créé
aujourd'hui, l'app du main courant installée dessus).

> **LA LOI DU CHANTIER** — la card ne dépend pas du mot pour être comprise.
> Le mot géant est une **atmosphère** (la bête se tient devant lui, elle en
> cache une partie, c'est voulu, comme le 4 devant YOU MADE IT) ; la
> **question** est portée par le titre, et la **décision** par le slider qui
> dit STOP en clair. Si un jour le mot doit être lu en entier, c'est la bête
> qu'on déplace, jamais le mot qu'on rapetisse.

> ⚠️ Deux autres sessions vivent dans l'arbre (flow/player : `PlayerSeance.swift`
> non tracké ; notifs : hunk `NotifBanc` dans `WoopApp.swift`). Ce chantier ne
> touche `WoopApp.swift` que par **trois hunks** nommés au §5, et ne committe
> que ses chemins (MULTI-SESSION.md).

---

## 1. L'état des lieux, mesuré dans le code

| pièce | où | ce qu'elle fait aujourd'hui |
|---|---|---|
| **Le stop actuel** | `PausePanneauHote` → `PausePanneau`, `Woop/Views/PlayerSeance.swift:15-198` (**fichier non tracké**) | Panneau BAS : voile noir 0,12 tapable, « Terminer la séance ? », un `bilan` (durée · séries · pièces, l.190-197), `DiamondPrimaryButton("Terminer", smokeWarmth 0.55)`, lien « Continuer la séance ». Transition `.move(.bottom)`, ressort 0,45/0,86, drag de rangement > 90 pt + chien de garde 0,5 s (l.165-188). Aucune vidéo. Une sonde `print("[SONDE-STOP] …")` encore active (l.48). |
| **Le montage** | `WoopApp.swift:1077-1088` | Enfant du ZStack racine de `mainBody`, **monté inconditionnellement**, `.zIndex(5)`. C'est le composant qui gère son vide (`if ouverte`, `.allowsHitTesting(ouverte)`). Signature : `ouverte / duree / series / gain / onTerminer / onContinuer`. |
| **L'état** | `DepartEtat.shared.pauseOuverte`, `DepartSeance.swift:35` | Singleton `@Observable`. Trois écrivains à `true` : `WorkoutPill.demanderLaPause()` (:207, le bouton stop des **5** players — home, ardoise, setup card, fiche flottante, bande exos), `galetPlayTenu()` (WoopApp:654), `onStopViaPause` (:679). Remplacer l'hôte à la racine remplace le stop PARTOUT d'un coup. |
| **Confirmer** | `terminerSeance()`, `WoopApp.swift:431-492` | Garde `active`, ferme le panneau, **SAVE jamais discard** (`endedAt` + `save()`), fin de Live Activity, trophée si gain > 0, `selection = .home` (0,3 s), `Task.detached { push ; reglerFinDeSeance }`, notif pièces +1,6 s, booster à +5,2 s. **On ne touche pas à cette fonction.** |
| **Annuler** | `onContinuer` (WoopApp:1083-1087) | `pauseOuverte = false`, easeOut 0,22. Rien d'autre. |
| **L'orphelin** | `StopSessionSheet.swift` + `Woop/Media/pause-overlay-loop.mp4` | L'ancien stop À VIDÉO (perdu au commit 83bd44d). Sa vidéo n'est PAS une chauve-souris (une nébuleuse, YMIN = 10 : pas du noir vrai), composée en `.plusLighter` + `.mask` — les deux gestes que la loi vidéo interdit. **On ne le ressuscite pas** ; on s'en inspire pour une chose : le chemin `clotureDemandee` (différer la clôture après une sortie) existe encore à la racine (WoopApp:1283-1288) mais on n'en a pas besoin (voir §5). |
| **La card à spotlight** | `RewardScene` (private) dans `RewardCard.swift:168-898` | `min(0,80·W, 332)` × 1,32, rayon 36 continu, scrim 0,68, ombre BLANCHE r38 y30, entrée `p` linéaire 1,45 s sur une vue `Animatable`, `clipShape` qui rogne le mot. Les pièces sont **internal et déjà réutilisées ailleurs** (RecompenseBoosters, RewardCheminVariants.swift:152-339 — « un nouveau variant, et on ne touche pas à l'autre ») : `TexteGeant` (:1825), `LampeEventail` (:1958) + `Eventail` (:1942), `PoudreDiamant` (:905), `Scintilles` (:2049), `balayageSpot` (:1812). Restent private : `sstep`, `CarteGyro`, `Secousse`, `VideoReward`. |
| **Le slider** | `SliderObsidienne`, `Woop/Views/SliderObsidienne.swift:28-54` | `label:` (mis en capitales par le composant), `height:` (62 sur la home), `validate:`, `onConfirm:` (à NOMMER, jamais en closure traînante), `onMood:`, `braise:`. Largeur = celle qu'on lui offre. Seuil 0,72 ; au commit : filament + gerbe + `CommitHaptic` + `Paillettes.announce`, puis reset à **+0,45 s**. Le texte de piste est en police **système**, pas Inter (c'est le composant, partout). |
| **Le lien** | `BoosterPopup.swift:434-445` ≡ `PlayerSeance.swift:94-101` | `Text(…).font(.inter(15, .medium)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())`, `.buttonStyle(.plain)`. |
| **La vidéo Nosfy** | `VideoNosfy`, `NotifChasse.swift:438-485` | **Aucun détourage dans la maison** : noir VRAI livré au tournage, posé nu sur `Color.black`. `AVPlayerLooper` RETENU, muet, `clipsToBounds` ET `masksToBounds`. Loi : jamais de `.mask` sur une couche vidéo (rendu hors écran par image) ; une vidéo ne se fond que **bord à bord** ; jamais une lumière DERRIÈRE un plan opaque (elle dessine le rectangle). |
| **La source** | `~/Downloads/chauve-souri_stop.mp4` | H.264 3836×2160, 24 img/s, **121 images / 5,04 s**, piste AAC (à jeter). Mesuré : fond à **0,0 exact** partout hors la bête ; bête debout, immobile, elle respire (PSNR 27 dB entre deux images quelconques) ; **couture de boucle NON propre** (image 0 ↔ 120 : 27,3 dB, autant que deux images quelconques) → ping-pong obligatoire. Boîte de la bête : 1022 × 2024 px (ratio 0,505). |

Ce que je n'ai **pas** pu voir : le panneau actuel à l'écran — aucun banc ne
lève `pauseOuverte`, et le simulateur n'a pas de doigt. Le §6 crée ce banc.

---

## 2. LA CARD — l'anatomie du design

Réf : la card You Made It (variant 2) pour la lumière et le mot ; la châsse
Nosfy pour la bête ; la home pour le slider. Monochrome, aucune couleur : la
seule chaleur autorisée est celle que le slider fabrique lui-même au commit
(la flèche qui refroidit blanc → or → rouge sombre — déjà codée).

### 2.1 Les cotes (iPhone 17 Pro, `min(0,80·W, 332)` de large)

**332 × 480 pt** (ratio **1,445** — plus haute que la reward 1,32 : elle porte
un slider), rayon 36 continu, centrée à l'écran. Tout en y depuis le haut :

| y (pt) | quoi | cote |
|---|---|---|
| 9 | la **fente** du spot (`Capsule 44×2`, blanc 0,55, blur 2) | de `LampeEventail`, tel quel |
| 0 → 196 | le **cône** (`Eventail` 60 → 236 pt, deux nappes blur 13/9, `.screen`, balayage ±19° sur ~9,7 s) | tel quel — ses points fixes sont taillés pour une card de 332 |
| **112** (centre) | le mot **« STOP »** — `TexteGeant(lignes: ["STOP"])` : Inter-Bold **128** (une ligne ≤ 2 → corps plein), tracking −3 | **342 pt de large mesuré** avec la fonte du dépôt → 5 pt rognés par flanc, DANS le fondu des flancs. Le mot reste entier. Aucun corps à inventer. |
| 48 → **268** | **la bête** : 220 pt de haut (45,8 % de la card), 111 pt de large, pieds à 268, centrée | ses oreilles montent à 48 : elles croisent le mot (66 → 158) et en cachent le milieu (« TO ») — S et P restent pleins |
| 284 → 310 | **titre** Inter-SemiBold 22, dégradé blanc (le titre « très Apple » de la reward) | « Stop the session? » (à trancher, §8) |
| 316 → 334 | **sous-titre** Inter 15, gris 0,55 | **le bilan** : « 3 sets · 24 min · +60 coins » (l'info du panneau actuel, gardée) |
| 352 → 414 | **le slider** `SliderObsidienne(label: "Stop", height: 62)`, marges 20 → 292 pt de piste | pouce à ~27 % de la piste, comme la home |
| 414 → 458 | **le lien** « Cancel », 44 pt de haut, pleine largeur | style canonique (§1) |
| 480 | bord bas (22 pt d'air sous le lien) | |

### 2.2 Les couches, de l'arrière vers l'avant

1. **La dalle** : `RoundedRectangle(36).fill(.black)`. **Pas de verre** : la
   vidéo bord à bord est opaque, un `glassEffect` dessous ne serait jamais vu
   et coûterait (60 → 14 img/s au moindre mouvement).
2. **LA VIDÉO, bord à bord** : `stop-bat-loop.mp4` (1080 × 1562, le ratio
   exact de la card), `resizeAspectFill`, `clipsToBounds` + `masksToBounds`,
   `AVPlayerLooper` retenu, muette. Elle contient **la bête et du noir exact**
   — rien d'autre. Elle occupe la card ENTIÈRE : aucun bord de rectangle à
   voir (la loi des 4 démarcations), aucun masque sur la couche.
3. **LE GROUPE MASQUÉ** = ce qui vit DERRIÈRE la bête :
   - le **fond gris → noir** du spotlight, recopié de `RecompenseBoosters.fond`
     (RewardCheminVariants.swift:328-339 ; 7 stops, **le bord haut repart du
     noir**, crête 0,125 à 26 %) ;
   - le mot `TexteGeant` (dégradé interne 0,40 → 0,17 → 0,06 = son fondu de
     pied, copie claire révélée par le balayage, `Scintilles` dans les
     lettres), masque hôte des **flancs seuls** `clear / white .24 / .76 /
     clear` — **pas de masque de pied en plus** (il éteint le mot deux fois,
     leçon RewardCheminVariants:273-287) ;
   - le tout sous **UN** `.mask { Image("stop-bat-masque").resizable() }` :
     la silhouette INVERSE de la bête (blanc dehors, noir dedans, plume ~1,5
     pt). Par le trou on voit la vidéo : la bête, et son aura de noir exact.
   C'est ainsi que la bête est « devant » sans qu'aucune vidéo soit détourée
   ni masquée : **le masque est sur du SwiftUI, la vidéo reste nue.**
4. **Le cône** `LampeEventail`, NON masqué, en `.screen` : il éclaire le mot
   ET la bête (ses reflets montent sous le faisceau, le noir du pelage
   reste noir). La lumière vit DEVANT le plan — la seule place permise.
5. **La poudre** `PoudreDiamant(largeur: 332, hauteur: 480)`, 72 grains, non
   masquée : elle flotte devant tout, comme sur toutes les cards.
6. **L'encre** : titre, bilan, slider, lien.
7. **Le liseré** 1 pt, dégradé blanc 0,14 haut → 0,08 bas (la reward
   « autres robes »), puis `.clipShape(forme)` — obligatoire : `TexteGeant`
   est HORS layout (`Color.clear.overlay`), sans clip il déborde sur le scrim.

Autour : scrim `Color.black.opacity(0.70)` tapable (= Cancel), ombre BLANCHE
`0.14·p, r 38, y 30` (la profondeur sur la page éteinte). Pas de lueur
derrière la card (la reward-chemin en a une ; ici le spot suffit, et la loi
« rien ne sort de la card » vaut sur une page qui n'est pas noire).

### 2.3 Le mouvement

Un seul progrès `p`, porté par une vue `Animatable` (jamais des `.opacity`
sous un `withAnimation` nu). Toutes les rampes en `sstep(a, b, p)`.

**Entrée — 0,60 s linéaire** (une question, pas une cérémonie : la reward
prend 1,45 s parce qu'elle fête) :

| rampe | (a, b) | quoi |
|---|---|---|
| scrim | (0, 0,35) | 0 → 0,70 |
| card | (0, 0,30) | `scaleEffect 0,94 → 1` + opacité — une transform, jamais un resize |
| fente | (0,15, 0,35) | s'allume |
| cône | (0,25, 0,70) | monte à pleine force ; le mot est révélé par sa copie claire |
| vidéo | (0,30, 0,60) | la bête **entre dans la lumière** (fondu) |
| titre + bilan | (0,45, 0,75) | fondu + 6 pt de montée |
| slider + lien | (0,55, 0,90) | fondu + 8 pt de montée |
| **haptique** | à `p = 1` (completion) | `.impact(weight: .medium, intensity: 0.8)` — pas de chime : un stop ne fête rien |

**Cancel** (lien ou tap du scrim) : `easeOut 0,30`, `p → 0` (card 1 → 0,96 +
opacité), `onContinuer()` en completion. La vidéo joue jusqu'au démontage.

**STOP** (le slider commet) — l'ordre est le sujet :
1. `onConfirm` → le slider joue **son** filament + sa gerbe + `CommitHaptic`
   (0,45 s, on ne le démonte PAS pendant — piège §9) ;
2. à **+0,50 s** : `fermer()` = `easeOut 0,42`, `p → 0` ;
3. en completion : `onTerminer()` → `terminerSeance()` inchangé (home,
   trophée, notif pièces, booster). Son `pauseOuverte = false` tombe sur une
   card déjà partie : sans effet visible, c'est voulu.

Ni `Secousse` (une question ne tressaille pas), ni tilt gyro (`CarteGyro` est
private, et la vidéo est déjà la vie de la card).

### 2.4 Ce qui fait « magnifique », et qu'on protège

- **La bête sous le projecteur** : c'est la seule chose vivante ; elle
  respire au ralenti du ping-pong, le faisceau la cherche (±19°), ses
  reflets s'allument quand il passe. Rien d'autre ne bouge que la poudre.
- **Le mot n'est pas un texte, c'est un mur éclairé** : sombre au repos,
  révélé par la lampe, gravé derrière la bête. Baisser son opacité pour le
  « fondre » est LA régression classique (RewardCheminVariants:164-168) —
  il est sombre, la lumière fait le reste.
- **L'aura** : la plume du masque (~1,5 pt) fait que le gris du mur meurt
  autour de la bête avant de la toucher — elle se pose dans son ombre, elle
  ne se découpe pas. La maquette v1 le montre.
- **Le silence chromatique** : noir, blanc, la poudre. La seule couleur naît
  du geste (la flèche du slider qui refroidit).

---

## 3. LA BÊTE — ce que la mesure a tranché

### 3.1 Le « détourage » du brief, et pourquoi on ne le fait pas image par image

Le fond est à **0,0 exact** (mesuré sur les 4 coins et hors la colonne de la
bête : max = 0). On pourrait croire qu'un matte « pixel ≠ 0 » suffit. **Il ne
tient pas**, mesuré sur les 121 images :

- le **pelage lui-même est à 0 exact** sur 180 000 à 274 000 px par image
  (le ventre, les pattes) — ces zones touchent le fond, le bouchage de trous
  les MANGE : la bête perd le bas du corps (`vignettes/bete-matte-par-image-ECHEC.png`) ;
- la bête se coupe en **deux composantes** sur certaines images (les pieds) ;
- la silhouette varie de **40 à 46 %** d'une image à l'autre → scintillement
  garanti. Le noyau commun à toutes les images ne fait que 64 % de l'union ;
  la bande qui clignote a 12 px de médiane et 43 px au p90 (@1080p).

C'est la loi des stickers (PIEGES-STICKERS.md) portée à la vidéo : **un objet
noir sur noir ne se détoure pas par la luminance**, ni par le zéro.

### 3.2 La forme juste : une silhouette STATIQUE, cuite une fois

La bête est **immobile** (boîte englobante : dérive de 1 px en y sur 121
images). Donc :

1. **union** sur les 121 images de `max(r,g,b) > 0` ;
2. fermeture morphologique large (≈ 28 px @4K) + bouchage des trous ;
3. composantes > 8 000 px seulement (les poussières meurent) ;
4. la silhouette est **une seule pièce**, 331 000 px @1080p, pieds compris
   (`vignettes/matte-union-statique-1080.png`, aperçu composé
   `vignettes/bete-matte-union-apercu.png`) ;
5. dilatation 3 px + plume gaussienne 5 px (à 1080 de large) → **l'inverse**
   devient le masque du groupe (§2.2 couche 3).

Parce que le masque ne coupe **jamais la vidéo** (il coupe le mur derrière),
une silhouette un peu large ne fait qu'une aura noire autour de la bête — le
noir exact de la vidéo — jamais une bordure grise. C'est ce qui rend la
solution robuste à la respiration.

### 3.3 La cuisson — `tools/stop/bake_stop.py` (à écrire au J0)

Entrée `~/Downloads/chauve-souri_stop.mp4` → sorties `Woop/Media/stop-bat-loop.mp4`
(ressource NUE, lue par `Bundle.main.url`) et `stop-bat-masque` (imageset
1x dans `Assets.xcassets`, 1080 × 1562, L : 255 dehors / 0 dedans — c'est
`Image(...)` qui doit le trouver, donc un imageset, pas Media).

1. décoder les **121 images** en RGB pleine résolution (pas de `-ss` : la
   coupe se fait dans le graphe ou en numpy) ;
2. **recadrer** la boîte union (x 1352 → 2374, y 48 → 2072 @4K, + 24 px de
   marge) ;
3. **poser** chaque image sur un canevas noir **1080 × 1562** : bête à
   **716 px de haut** (= 220 pt), ~362 de large, pieds à **y = 872**
   (= 268 pt), centrée. Lanczos. Le canevas est noir exact (0), rien d'autre ;
4. **palindrome** amputé de ses doublons : images 0 → 120 puis 119 → 1 =
   **240 images, 10,0 s à 24 img/s**. Couture ZÉRO par construction ; la
   respiration à l'envers reste une respiration ;
5. encoder : `libx264 -profile:v high -preset slow -crf 17 -pix_fmt yuv420p
   -g 48 -keyint_min 48 -sc_threshold 0 -x264-params
   no-dct-decimate=1:aq-mode=3 -movflags +faststart -an` (la grammaire
   `recuit_duo.sh` / `bake_spot.py`, crf 17 parce que le contenu est sombre) ;
6. la **silhouette** (§3.2) subit la MÊME transformation (crop → échelle →
   pose) → PNG 1080 × 1562, inversée.

**Le portillon** (numpy, avant d'écrire une ligne de Swift) : fond hors
silhouette dilatée = **0 exact** sur les 240 images AVANT encodage, et
YMIN ≤ 16 (→ 0 décodé) APRÈS ; couture |f0 − f239| ; poids (attendu ≤ 2 Mo) ;
planche-contact 4 × 3 du raccord ; et la bête re-mesurée dans le fichier
livré (boîte à 716 px ± 2). Le décodeur du simulateur est LOGICIEL et rate
des images : sous la vidéo il y a la dalle noire — un raté est invisible.

### 3.4 Les deux alternatives, et pourquoi elles perdent

- **Tout cuire dans la vidéo** (mur + mot + spot + bête, « la vidéo a gagné »
  de la matrice) : robuste, zéro masque — mais le spot et le mot sont des
  composants **validés et vivants** (le faisceau qui cherche, la copie
  claire, les scintilles) ; les figer en pixels perd tout ça pour rien.
  Repli si la cadence du J2 est mauvaise, pas avant.
- **HEVC avec alpha** : jamais fait dans la maison, et le matte par image
  n'existe pas (§3.1). Non.
- **La bête statique** (`ChauveQuiTient`, un PNG) : le repli zéro-coût si la
  vidéo s'avérait impayable au téléphone. Elle existe déjà (RewardCard:1452).

---

## 4. LE SLIDER ET LE LIEN

- `SliderObsidienne(label: "Stop", height: 62, validate: { active != nil },
  onConfirm: …)` — **`onConfirm:` nommé** (deux propriétés optionnelles le
  suivent : une closure traînante irait se coller à `pose`). Largeur : la
  card moins 2 × 20. `braise: 0`, `diamants: true` (la home).
- Le composant met « STOP » en capitales lui-même ; ne pas passer « STOP ».
- Sa poudre (`Canvas` de 130 pt en overlay) et le rectangle de son shader
  (pad 52) débordent la piste de ~34/52 pt en **emprise nulle** : posés dans la
  card ils sont rognés par le `clipShape`, la gerbe du commit (33,8 pt de
  haut) reste visible au-dessus de la piste. Rien à changer.
- **Son commit joue l'arpège `Paillettes` du START.** À trancher (§8) : un
  STOP qui sonne comme un départ ? Recommandé : garder au J1, juger au
  téléphone — le composant n'a pas d'interrupteur de son, en ajouter un est
  une retouche d'un composant partagé (4 sites).
- **Le lien « Cancel »** : le bloc canonique (§1), un vrai `Button` — il n'y a
  **aucun drag d'ancêtre** dans cette card (pas de rangement au doigt), donc
  la loi highPriorityGesture ne s'applique pas ici. Le tap du scrim fait la
  même chose.

---

## 5. LE CÂBLAGE — trois hunks dans `WoopApp.swift`, un fichier neuf

**Nouveau : `Woop/Views/StopCard.swift`**
- `struct StopCardHote: View` avec **la signature exacte** de
  `PausePanneauHote` (`ouverte, duree, series, gain, onTerminer, onContinuer`).
  Toujours monté. `@State p`, `posee`, `naissance` (une `Date` posée au
  montage, jamais dans le corps). `.onChange(of: ouverte)` → `withAnimation`
  avec **completion** (la garde se fait sur le drapeau de completion, jamais
  sur la valeur de `p` : sous `withAnimation` le modèle saute à la cible dès
  la première image). `.allowsHitTesting(ouverte)`. Scrim tapable → `onContinuer`.
- `struct StopCard: View, Animatable` (le `p`) — le corps du §2.2, en
  **vues nommées** (`mur`, `bete`, `lampe`, `encre`, `pied`), jamais une
  expression : le type-checker de ce dépôt a déjà cassé un build device.
- `private struct VideoBoucle: UIViewRepresentable` (école `VideoNosfy` :
  looper retenu, muet, `automaticallyWaitsToMinimizeStalling = false`,
  `clipsToBounds` + `masksToBounds`, `resizeAspectFill`, `dismantle` qui
  coupe la boucle) avec `nom:` en paramètre. On n'emprunte pas
  `DepartLoopVideo` (pas de clips, fichier d'une autre session) ni
  `VideoReward` (boucle par `seek(.zero)`, le geste interdit).
- un `sstep` local (16 copies privées dans le dépôt, on ne dé-privatise pas).

**Hunk 1** — `WoopApp.swift:1077` : `PausePanneauHote(` → `StopCardHote(`
(mêmes arguments). **Hunk 2** — `.zIndex(5)` → **`.zIndex(13)`** : un stop
peut être demandé pendant la card à gratter (12) ou la notif pièces (9) ;
une question modale se pose AU-DESSUS (sous MoonDust 20). **Hunk 3** — le
banc (§6). `terminerSeance()` : **zéro ligne**.

Ce qui disparaît avec le panneau : le drag de rangement et son chien de
garde. Pas de geste mort possible ici (aucun drag sur la card ; le slider
porte le sien, `stale 0,18 s`). Le gel du 27-08 (page invisible qui mange les
touchers) ne peut pas renaître : `allowsHitTesting(ouverte)` reste, et rien
ne peut pousser la card hors écran.

`PausePanneau` reste dans `PlayerSeance.swift` (fichier de la session flow,
non tracké — on n'y touche pas ; ses deux sondes `[SONDE-STOP]` sont à elle).

---

## 6. LES BANCS, LE SIM, LES MESURES

Sim dédié : **kat-stop** (`E9241D2D-EB46-43C8-A76A-DE5319DE48D6`). DerivedData :
`dd-stop` à la racine (aujourd'hui le build est dans le scratchpad de la
session ; à ranger). Script : `tools/stop/voir.sh`, copie de
`tools/notifs/voir.sh` (build nu → `$?` capturé sur la ligne → `stat` du
`Woop.debug.dylib` → install → `launch --terminate-running-process` → lancer
DEUX fois avant toute capture → screenshot horodaté dans `tools/stop/captures/`).

| argument | effet |
|---|---|
| `-stopLab` | la card SEULE sur du noir (`StopLab.swift`, école `NotifLab` : `.id(tour)` pour rejouer, tap = fermer 0,3 s puis rouvrir), branché en TÊTE de `RootView.body` (un `static let` + un `else if`, rien d'autre) |
| `-stopFige` | naît posée (`p = 1`), pour les captures immobiles |
| `-stopT <s>` | les horloges (balayage, scintilles, poudre) clouées à l'instant s |
| `-stopNu` | sans bandeau |
| `-stopAuto` | ouvre / ferme en boucle (4 s) — c'est celui qu'on FILME |
| `-stopSliderAuto` | le slider rejoue son geste (`auto: true`) — le commit filmé sans doigt |
| `-stopOuvre` | **le vrai flow** : avec `-activeWorkout -skipAuth`, lève `pauseOuverte` à +1,2 s dans le `.task(id: showSplash \|\| showAuth)` (école `-departPanneau`) — la card sur la vraie home en séance |
| `-fps` | `SondeCadence("stop")` posée par le banc ; portillon `./tools/charge.sh` AVANT (🔴 > 2 = ne pas mesurer) ; lecture `simctl launch --console-pty` |

Cadence — **c'est le vrai risque** : la card empile quatre horloges
(`SliderObsidienne` 60 Hz + un `colorEffect`, `LampeEventail` 30 Hz,
`TexteGeant` 30 Hz, `PoudreDiamant` 30 Hz) + un groupe masqué (rendu hors
écran de 332 × 480 à 30 Hz) + une `AVPlayerLayer` (gratuite). Jamais mesurées
ensemble. Cibles : 60 au sim au repos, pire trou < 34 ms ; **verdict au
téléphone** (le sim décode en logiciel et n'a pas de gyroscope). Si ça tombe :
d'abord `-stopT` pour isoler l'horloge coupable, ensuite seulement le repli
§3.4.

Non-régression : `-homeSeance -fps` avant/après (la home en séance ne doit
pas changer d'un chiffre — l'hôte reste monté inconditionnellement comme
avant).

---

## 7. JALONS — chacun avec sa preuve

- **J0 — LA BÊTE CUITE, zéro ligne Swift.** `bake_stop.py` → `stop-bat-loop.mp4`
  + `stop-bat-masque`. Preuve : le portillon du §3.3 (noir exact hors bête,
  couture 0, poids, boîte à 716 px) et la planche-contact du raccord.
- **J1 — LA CARD AU BANC.** `StopCard.swift` + `StopLab.swift` + hunk 3.
  Preuve : capture `-stopLab -stopFige -stopNu` comparée à
  `vignettes/maquette-v1.png` (cotes du §2.1 à ± 2 pt : centre du mot, pieds
  de la bête, piste du slider) et à la réf You Made It (fente, cône, fondu
  des flancs). Le mot mesuré sombre au repos (pas une opacité baissée).
- **J2 — LE MOUVEMENT.** Film `-stopAuto` (entrée 0,60 s, Cancel 0,30 s) et
  film `-stopSliderAuto` (commit → +0,50 s → sortie). Détecteur de flash
  croisé aux `pts` (le recordVideo du sim est VFR sous charge). Cadence
  `-stopLab -fps` après `charge.sh`.
- **J3 — LE BRANCHEMENT.** Hunks 1 + 2, `-stopOuvre`. Preuve : film
  `-activeWorkout -skipAuth -stopOuvre` → card → (Cancel) → home intacte ;
  et → STOP → home + trophée + notif pièces (la chaîne `terminerSeance`
  inchangée). Non-régression `-homeSeance -fps`.
- **J4 — TON VERDICT, au téléphone.** Les haptiques du slider (muettes au
  sim), la cadence réelle, la bête sous le spot, et les textes du §8. J4
  n'est pas automatique : tant que tu n'as pas tranché, le chantier est
  ouvert.

Commits par chemins, dans l'ordre : J0 (`Woop/Media/stop-bat-loop.mp4`,
l'imageset, `tools/stop/`), J1 (`StopCard.swift`, `StopLab.swift`, le hunk
banc de `WoopApp.swift` **seul** — `git add -p`), J3 (hunks 1 + 2). Jamais
`git add -A` ; `git log -1` juste avant chaque commit ; message sans trace
d'assistant.

---

## 8. À TRANCHER (mes recommandations en premier)

1. **Les textes** — l'app mélange FR (le panneau actuel) et EN (home,
   rewards, libellés du slider). Recommandé **EN** : titre « Stop the
   session? », sous-titre = **le bilan** (« 3 sets · 24 min · +60 coins »),
   slider « Stop », lien « Cancel ». Alternative : un titre au registre des
   libellés tirés au sort (« Calling it a day? ») — le bilan en dessous garde
   la clarté.
2. **Le son du commit** — l'arpège du START sur un STOP : garder (recommandé
   pour juger d'abord) / couper (retouche du composant partagé).
3. **L'étage** — `zIndex(13)` (recommandé : au-dessus de la card à gratter et
   de la notif) / rester à 5.
4. **La hauteur** — 480 pt (recommandé : le slider respire) / 438 (le 1,32 de
   la reward, tout se serre de 42 pt).
5. **Le tilt** — non (recommandé) : `CarteGyro` est private, la vidéo vit déjà.
6. **Le geste de rangement** — mort avec le panneau (recommandé) : scrim +
   Cancel suffisent, et aucun geste mort possible.

---

## 9. LES PIÈGES QUI S'APPLIQUENT ICI (déjà payés ailleurs)

1. **Le mur du type-checker** — `mainBody` a déjà cassé tout build device
   (337a6e3). La card entre à la racine comme UNE vue nommée ; le banc = un
   `static let` + un `else if`.
2. **La fente detail** — `TexteGeant` est hors layout (`Color.clear.overlay`) ;
   sans `clipShape` sur la card il déborde sur le scrim. Et un `Text` de 128
   pt en offset gonfle son hôte : on ne le pose jamais en enfant de layout.
3. **Jamais de `.mask` sur une couche vidéo** — ici le masque est sur le
   groupe SwiftUI ; la vidéo reste nue, bord à bord, `clipsToBounds` +
   `masksToBounds`.
4. **Jamais une lumière derrière un plan opaque** — le cône est DEVANT la
   vidéo ; le mur gris n'existe que par le trou du masque.
5. **Le verre** — aucun ici ; s'il revenait : `.regular` interdit, `.clear`
   givre du contenu net, un verre aux bounds vivants devient un blur plat.
6. **`.blur`** — 27 img/s perdues par objet flouté ; `LampeEventail` se le
   permet sur deux formes, on n'en ajoute aucun.
7. **Le double `withAnimation`** au même tour = rien ; un aller-retour se fait
   en keyframes ; une garde sur la valeur d'un `@State` animé ne retient rien
   (completion + drapeau).
8. **`onConfirm:` nommé**, jamais traînant ; **le slider ne se démonte pas
   avant +0,45 s** (son filament joue) ; **`.fill(.white)` sur l'hôte de son
   shader**, jamais `.clear`.
9. **Un `Button` sous un `DragGesture` d'ancêtre est annulé** — pas de drag
   ici ; si un jour la card en reçoit un, Cancel passe en
   `highPriorityGesture` en FRÈRE (pas enfant).
10. **`Woop/Media` est nu** — `Image("stop-bat-loop")` ne trouve rien, en
    silence ; la vidéo se charge par `Bundle.main.url`, le masque vit en
    imageset. Le groupe Xcode est synchronisé : le `git add` reste manuel
    (trois fichiers ont déjà manqué au dépôt).
11. **Les arguments du banc** — `--terminate-running-process` obligatoire ;
    lancer DEUX fois avant une capture ; `-fps` ne produit rien là où
    personne n'a posé de sonde.
12. **Le build** — `$?` capturé sur la ligne, jamais derrière un `| grep` ;
    un `dd-stop` à soi ; c'est la date de `Woop.debug.dylib` qu'on lit.
13. **La mesure** — `charge.sh` avant `-fps` ; une couleur se mesure sur les
    pixels clairs ; une cinématique se filme ; le verdict est au téléphone.
14. **Le détourage d'un objet noir** — jamais par la luminance ni par le
    zéro image par image (§3.1) ; silhouette statique, union, plume sur le
    seul contour, et le masque ne coupe jamais la bête elle-même.
15. **`-ss` ne coupe pas le graphe ffmpeg** — la coupe temporelle vit dans
    `trim + setpts` ou en numpy ; `reverse` charge tout le clip en mémoire
    (121 images 4K : ~3 Go en RGB, passer par des PNG ou par demi-résolution).
