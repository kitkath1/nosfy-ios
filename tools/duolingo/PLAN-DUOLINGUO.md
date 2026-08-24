# LA DUOLINGUO_PAGE — « LE CHEMIN DE FEU »

Plan dicté le 2026-08-24, **fouetté avant présentation** (deux salves de
trois juges adverses : technique, design, complétude — leurs verdicts sont
intégrés, les arbitrages qu'ils n'ont pas le droit de trancher sont en §10).

Session UI PURE : les fonds, les transitions, les galets-boutons. La
stratégie de gamification (paliers, récompenses, challenges) est
explicitement remise à plus tard — mais la SURFACE de jeu (compteurs,
nœud-trésor) est de la session UI : une page sans un seul compteur ne se
lit pas gamifiée, elle se lit vide.

Le brief en une phrase : **une descente de cinq écrans où le feu change de
couleur — noir, blanc, rouge, rouge-et-bleu, bleu — chaque frontière tenue
par un objet de verre ou une flamme, et un chemin de galets de verre
légèrement 3D qui serpente dans le noir entre eux, comme Duolingo mais dans
l'univers Apple minimal luxury de Woop.**

Références : les 5 maquettes + la légende, ARCHIVÉES dans
`tools/duolingo/shots/maquette-ecran-{1..5}.png` et
`maquette-legende-videos.png` (copiées du Bureau le 24-08, MESURÉES au
numpy — §2bis). Réf UX : le screenshot de la home Duolingo (conversation du
24-08, 09:33 — à déposer dans shots/ en `maquette-ref-duolingo.png`).

---

## 1. LA DOCTRINE (quatre lois, elles tranchent tous les micro-débats)

**LOI 1 — LA COLONNE EST UN SEUL FILM.** Les cinq écrans ne sont pas cinq
pages : une seule descente, une seule histoire de température
(noir → blanc → rouge → rouge-et-bleu → bleu). Chaque frontière entre deux
écrans appartient à UN objet — un galet de verre qui la chevauche ou une
flamme qui s'y éteint — jamais deux ; pendant la frontière, ce qui n'est
pas cet objet s'efface (le voile sortant, §7). Le galet rouge-et-bleu EST
la frontière 4/5 : une seule fenêtre à cheval sur la couture, et c'est le
scroll qui fait le voyage du rouge au bleu.

**LOI 2 — LE NOIR EST LA MATIÈRE, PAS LE VIDE** (héritée de la home v2).
Chaque écran a sa BANDE NOIRE mesurée dans la maquette (§2bis) : le chemin
n'a le droit de vivre que là. Portillon PAR ÉCRAN, pas dogmatique : p99 de
la luminance sous l'empreinte du serpentin ≤ 8/255 sur capture banc (les
maquettes elles-mêmes mesurent 87-99 % sous L=16 sur leur tiers central —
c'est LEUR noir qu'on protège, pas un chiffre unique).

**LOI 3 — LE FEU EST DANS LA VIDÉO, LE VERRE DU CHEMIN EST DESSINÉ.**
Toute la lumière vient des fichiers cuits — aucun shader de flamme, aucun
halo de fond. Les galets-étapes sont du verre PEINT (école LaunchPebble /
VerreGalet), pas du verre natif : la loi du verre à jeun
(HomeNuit.swift:536-549 : sur du noir, un petit objet natif = « un TROU
dans du métal ») condamne le natif exactement là où vit le chemin. ⚠️ Cet
arbitrage réinterprète le mot « liquid glass » du brief — il est en §10.1,
jugé sur J2. Le natif garde UN droit : la dalle de chapitre, nourrie par la
vidéo (§6.4).

**LOI 4 — LA GAMIFICATION EST MUETTE.** Pas de vert Duolingo, pas de badge
cartoon, pas de confetti, pas de pointillé board-game, pas d'anneau de
sélection, pas de shake de refus. Les états se disent par la matière et la
taille. Les seules couleurs de la page sont celles des vidéos ; le chemin
est monochrome blanc/obsidienne et EMPRUNTE la température de son écran
(liseré blanc chaud sur le rouge, froid sur le bleu). Une exception
possédée par la maison : le souffle d'or de l'« accompli parfait » —
l'or animé est une retouche de Kathryn elle-même sur la carte obsidienne
(précédent validé).

---

## 2. LES SOURCES — l'inventaire vrai (les noms MENTENT, mesuré le 24-08)

Sondé au ffprobe + planches-contact début/milieu/fin. Trois fichiers sur
six ne contiennent pas ce que leur nom annonce :

| Fichier (~/Downloads sauf mention) | Contenu RÉEL | Format | Durée | Rôle |
|---|---|---|---|---|
| `Video noir_liquid.mp4` | galet de verre NOIR, capsule pleine, centrée | 2160×3836, 24 i/s | 8,04 s | écran 1 haut |
| `Video rougeetbleu_liquid.mp4` ⚠️ | **la FLAMME BLANCHE** (plumes blanches douces) | 1080×1920, 24 i/s | 7,08 s | écran 1 bas + écran 2 haut (retournée) |
| `Video rouge_liquid.mp4` | galet de verre ROUGE/ambre, capsule pleine | 2160×3836, 24 i/s | 7,04 s | écran 2 bas |
| source exos (tools/exos-v2) ou `Woop/Media/exos-fond-loop.mp4` | le verre rouge couché entrant par la gauche | 1620×3522, 24 i/s | 35,5 s | écran 3 haut (la « continuation ») — RE-CUIT, voir §3.1 |
| `video_flamme_rouge.mp4` (21-08) | la flamme rouge/orange — la flamme de la famille home | 2160×3836, 24 i/s | 6,04 s | écran 3 bas + écran 4 haut (retournée) |
| `Video_Flamme_bleu_.mp4` ⚠️ | **le GALET ROUGE-ET-BLEU** (dôme rouge, ventre bleu) | 2352×3524, 24 i/s | 7,04 s | LA frontière 4/5 (LOI 1) |
| `video_flamme_bleu.mp4` | la flamme BLEUE | 1080×1920, 24 i/s | 7,08 s | écran 5 bas |

Mesures qui commandent la suite :

- **Aucune ne boucle nativement** : PSNR première/dernière image 15,0-21,8 dB
  sur les six (identiques mesureraient 40+). Palindrome cuit OBLIGATOIRE.
- **Le trait violet de l'écran 4 n'est PAS dans la vidéo** (strip de 6
  frames : capsule stable). **VERDICT KATHRYN 24-08 : MORT** (« pas le
  trait violet, tout c'était pour faire des maquettes ») — et la fidélité
  aux maquettes est un GUIDE, pas un évangile au pixel (« si c'est pas à
  100 % pareil voilà quoi ») : le portillon silhouette ±4 % devient un
  garde-fou de cadrage, le verdict final est à l'œil, le sien.
- La « `Video rouge_liquid_continuation` » des annotations n'existe pas en
  fichier — le cadrage voulu est celui d'`exos-fond-loop` (vérifié à la
  planche-contact), et le brief le dit (« pour les scroll 3 et 4 il peut
  prendre les flammes de la homepage »). Mais le fichier exos TEL QUEL est
  interdit de séjour : 1620×3522 @ 24 = **137 Mpix/s de décodage à lui
  seul** — très exactement le coût que la maison vient de tuer au TOUR 4 de
  la scène de départ (316 → 29 Mpix/s). La parité exos est une parité de
  MATIÈRE, pas de fichier : on re-cuit un crop (§3.1).

## 2bis. LES MAQUETTES MESURÉES (numpy, cadre détecté, profil par ligne)

Cartes des 5 maquettes ≈ 396-398 px de large, ratio ~2,19 (≈ l'écran).
Bandes « allumées » (moyenne > 6 ou p95 > 24), converties pour 402×874 pt :

| Écran | bande haute allumée | bande basse allumée | interstice noir | noir 35-65 % mesuré |
|---|---|---|---|---|
| 1 | y 0→41 (col du galet au bord) **+ arc du ventre y 355→472** | flamme dès **y 612** | y 472→612 | 87 % |
| 2 | flamme jusqu'à **y 323** | dôme rouge dès **y 677** | y 323→677 | 97 % |
| 3 | verre rouge jusqu'à **y 280** | flamme dès **y 574** | y 280→574 | 99 % |
| 4 | flamme jusqu'à **y 304** | galet dès **y 588** (+ trait violet y 500→517) | y 304→588 | 99 % |
| 5 | galet bleu jusqu'à **y 265** | flamme dès **y 641** | y 265→641 | 99 % |

Ces nombres sont LA référence de fidélité : le portillon J1 se mesure
contre eux (silhouette, ±4 % par bord), jamais « à l'œil » seul. Quand
Kathryn repassera un écran, on re-mesure sa maquette et on rejoue le
mini-jalon de recalage (§9, R-n) — une édition de la table `EcranSpec`,
pas une chirurgie.

---

## 3. LA CUISSON — `tools/duolingo/recuit_duo.sh`

### 3.1 Les sorties (le bundle aplatit Woop/ : unicité absolue)

**Neuf** fichiers dans `Woop/Media/`, préfixe `duo-`, chacun cuit AU RATIO
EXACT de sa fenêtre §5 — la loi la plus bruyante de l'école porte
(recuit_porte.sh : « Ratio exact = rien n'est rogné par resizeAspectFill…
Toute autre cote fera déborder la couche ») s'applique aux flammes comme
aux galets : le crop se fait AVANT la rampe d'extinction, et les cotes
d'extinction sont dérivées des fenêtres, pas devinées.

| Sortie | Source | Fenêtre §5 (pt) | Cuisson (px) | Mpix/s |
|---|---|---|---|---|
| `duo-galet-noir.mp4` | noir_liquid | 402×520 | 1206×1560 | 45 |
| `duo-flamme-blanche.mp4` | rougeetbleu_liquid ⚠️ | 402×262 | 804×524 | 10 |
| `duo-flamme-blanche-haut.mp4` | la même | 402×323 | 804×646 | 12 |
| `duo-galet-rouge.mp4` | rouge_liquid | 402×200 | 1206×600 | 17 |
| `duo-verre-rouge.mp4` | source exos (sinon crop d'exos-fond-loop) | 402×280 | 1206×840 | 24 |
| `duo-flamme-rouge.mp4` | video_flamme_rouge | 402×300 | 804×600 | 12 |
| `duo-flamme-rouge-haut.mp4` | la même | 402×304 | 804×608 | 12 |
| `duo-galet-rougebleu.mp4` | Video_Flamme_bleu_ ⚠️ | 360×700 (frontière) | 1080×2100 | 54 |
| `duo-flamme-bleue.mp4` | video_flamme_bleu | 402×233 | 804×466 | 9 |

Galets nets à 3× (1206), flammes-gradients à 2× (804 — école braise home :
demi-définition légitime SI gradient p99 mesuré ≤ 3,0, portillon par
fichier ; un p99 au-dessus = 3× ou renoncer). Budget PAR ÉCRAN (somme des
lecteurs vivants, §4.2) : **≤ 90 Mpix/s en croisière, ≤ 150 à la
frontière** — portillon J0 chiffré ligne à ligne dans le script.

Poses jumelles : frame 0 de chaque fichier →
`Woop/Assets.xcassets/duo-*-poster.imageset/` (Contents.json au heredoc,
école recuit_porte). Neuf posters.

### 3.2 La recette (école home-v2 pour le 24 i/s, école porte pour le reste)

- Encodage : `-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -g 48
  -keyint_min 48 -sc_threshold 0 -movflags +faststart -an`.
- **24 i/s natif, PAS de conversion 30** : c'est l'école home-v2/exos (la
  porte, elle, a fait du 30 une loi contre le battement 3:2 — l'arbitrage
  est assumé : convertir 24→30 fabrique des images interpolées, et sur le
  verre NET des galets l'interpolation fantôme est pire que le battement).
  ⚠️ Le battement 3:2 des mouvements lents est au fouettage J1 ET J5 ; s'il
  se voit au téléphone, bascule 30 documentée (§10.9).
- Palindrome par la fonction `pingpong()` de recuit_porte : comptage
  d'images au réel (`nbf()`, ffprobe -count_frames), retour amputé de ses
  DEUX doublons de bord, couture zéro par construction. Portillon : delta
  frame-à-frame à la couture ≤ 2/255 au numpy.
- ⚠️ JAMAIS `-ss` : tout trim DANS le graphe (`trim=…,setpts=PTS-STARTPTS`)
  — le piège payé deux fois. Vérification : profil de luminance, image 0
  d'un fondu = 0,00.
- Fondus de bord CUITS dans le fichier (école dominante, « rien de tout ça
  ne se rattrape ici ») : chaque fichier reçoit son extinction aux cotes
  DÉRIVÉES de sa fenêtre — flammes basses : extinction haute ; flammes
  hautes : extinction basse ; galets : on MESURE les quatre bords de la
  boîte croppée et on cuit un voile partout où p99 > 4/255 (une boîte
  utile a par construction du contenu au bord — le voile est la norme, pas
  l'exception). Portillon J1 : p99 des quatre bords VISIBLES de chaque
  fenêtre POSÉE ≤ 4/255 sur capture banc — la mesure au fichier ne suffit
  pas, c'est la fenêtre qui fait foi.
- **Le noir H.264 vérifié** (piège payé) : p50 des zones noires de chaque
  fichier cuit ≤ 2/255 ; limited range soulevé = rabattu au `curves` dans
  le graphe, jamais en runtime.

### 3.3 Le retournement « premium » (recette NEUVE — aucun vflip dans le repo)

1. `vflip` — les plumes pendent du bord haut et lèchent vers le bas : le
   geste d'un feu suspendu.
2. `+ hflip` — décorrélation : la jumelle haute n'est jamais la symétrie
   exacte de la basse dans le même champ. ⚠️ C'est un écart délibéré aux
   maquettes — §10.7, à confirmer.
3. **Rotation de phase DU PALINDROME** (la forme juste, corrigée au
   fouettage du plan) : pingpong COMPLET d'abord — lui seul boucle — puis
   roll de phase du palindrome dans le même graphe (un roll dans une
   boucle sans couture reste sans couture). Jamais un ping-pong d'une
   demi-source, jamais un roll de la source brute (sa coupure native
   PSNR 15-22 dB se cuirait au cœur de la boucle).
4. **PAS de ralenti par défaut** : `minterpolate mi_mode=blend` fabrique
   des fantômes en double exposition sur les pointes de plumes — le
   « pas fluide » déjà condamné sur l'ember. Si les jumelles battent
   visiblement en phase malgré la rotation, un A/B filmé au J0 (natif /
   palindrome allongé / mci) tranche — au film, jamais à la recette
   (§10.10).
5. Portillon J0 dédié aux deux `-haut` : déphasage vérifié (diff des
   frames 0 des deux fichiers > seuil), film côte à côte jumelle
   haute/basse, p95 du ghosting frame-à-frame.

L'« effet premium » vit AUSSI à l'écran, pas que dans le fichier : la
flamme haute reçoit une dérive de température de liseré et le voile de
frontière (§7) — c'est la partition qui rend le retournement précieux.

---

## 4. L'ARCHITECTURE — la page, les couches, les lois

### 4.1 La colonne

`Woop/Views/DuolinguoPage.swift` — `struct DuolinguoPage: View`, le banc
`DuoLab` en bas du même fichier (école DepartSeance).

- **`ScrollView(.vertical)` + `VStack(spacing: 0)` NON-lazy** de cinq
  sections `containerRelativeFrame(.vertical)` + `.scrollTargetLayout()` +
  `.ignoresSafeArea()`. Pas de LazyVStack : elle ne garantit AUCUN voisin
  monté et ferait naître un lecteur EN PLEIN geste de frontière (poster
  figé contre jumelle vivante — le verdict « pas fluide » assuré ; la
  porte a payé ce problème et l'a résolu par créneaux, pas par lazy).
  Cinq écrans à hauteur fixe = layout trivial ; le coût se pilote au RATE
  (§4.2), pas au montage. L'argument « payé plein tarif » de CoffreFort
  visait des vidéos qui JOUENT derrière — un layer à rate 0 ne décode pas.
- **L'aimant, pas la page sèche** : `ScrollTargetBehavior` custom (école
  `BacAimant` de CalLab) aimanté aux cinq poses, règle « une page par
  geste » reprise telle quelle. ⚠️ Verdict au banc contre `.paging` sec
  (§10.3). Défaut : l'aimant.
- **UNE sonde composée** (la loi payée cinq fois) :
  `struct SondeDuo: Equatable { var y: CGFloat; var fin: CGFloat }`,
  offset normalisé `contentOffset + contentInsets`, écriture gardée →
  `@Observable final class EtatDuo` HORS corps ; le corps de la page n'en
  relit RIEN. La vitesse vient du paramètre `vieux` de l'action.
- Les mouvements pilotés par la position passent par `visualEffect` (tout
  se lit dans le proxy, zéro invalidation) ou des `ViewModifier` qui
  lisent `EtatDuo` ; les rampes d'apparition sont `Animatable`.
- **`EcranSpec`** : TOUTES les cotes de §5 vivent dans une table de
  constantes Swift unique (fenêtres, bandes, positions de galets par
  écran) — le recalage d'un écran repassé = le diff d'une ligne.

### 4.2 Les calques vidéo — `CalqueVideoPilote`

`CalqueVideo` (DepartCine.swift:255-364) est la bonne école (pose sous le
playerLayer effacée sur `isReadyForDisplay`, aspectFill + clipsToBounds +
masksToBounds, frame sous CATransaction) — mais il ne sait PAS naître en
pause : trois chemins forcent `play()` sans regarder `rate` (le
`makeUIView`, la complétion du preroll, le retour de foreground), et sa
garde `abs(c.rate - rate) > 0.01` ne re-pausera jamais un lecteur né à 0.
Le cas « né en pause » n'a jamais été payé dans le repo.

→ **`CalqueVideoPilote`** : la variante (ou le paramètre) où
`makeUIView` ne lance pas si le rate initial est 0, et où preroll-complétion
et foreground rejouent `p.rate = coordinator.rate` au lieu de `play()`.
C'est LA brique de la page (et de `-duoFreeze`).

- Fenêtre = `Color.clear.frame(w:h:).overlay { CalqueVideoPilote(...) }
  .clipped()` — l'overlay-sur-Color.clear, la seule forme qui ne gonfle
  pas l'hôte (piège detail-gonfle).
- **Taille de fenêtre CONSTANTE**, ratio fichier = ratio fenêtre (§3.1) ;
  parallaxe et dérives en `offset`/`scaleEffect` via visualEffect (« on
  transforme, on ne redimensionne jamais »).
- Boucle : `AVPlayerLooper` sur `AVQueuePlayer`, looper RETENU, fichiers
  palindromes. Muet, `automaticallyWaits… = false`, preroll sur KVO
  `.status` (avant readyToPlay il TUE l'app).
- **Le rate est le budget** : les ~10 lecteurs naissent UNE fois à la
  naissance de la page, `rate = 1` seulement pour l'écran courant et
  l'écran entrant (dérivé de la sonde, hystérésis d'un demi-écran),
  `rate = 0` partout ailleurs — un lecteur à 0 ne décode pas. Le calque
  frontière est compté NOMMÉMENT dans le budget : rate 0 hors écrans 4-5.
  Portillon J1 : lecteurs vivants = courant + entrant, jamais plus.

### 4.3 Le calque frontière et le chemin (l'ordre des couches)

Les deux vivent DANS le scroll, en overlay du VStack — jamais hors du
scroll piloté par la sonde (une frame de retard = le galet qui glisse
contre ses écrans, la marche à la couture que J4 bannit) :

1. le VStack des cinq écrans (fenêtres vidéo clouées) ;
2. `.overlay(alignment: .top)` → **le galet rouge-et-bleu** : UNE fenêtre
   360×700 pt, clouée à la couture 4/5 par un offset CONSTANT en
   coordonnées de contenu (centre à y = 4×874), ancrée trailing,
   `allowsHitTesting(false)` ; sa parallaxe via visualEffect (il EST dans
   le scroll). Les « vues » des écrans 4 (dôme rouge dès y 588) et 5
   (ventre bleu jusqu'à y 265) sont des CONSÉQUENCES du cadrage de cette
   fenêtre unique — plus de cotes indépendantes qui ne s'additionnent pas.
3. `.overlay` → **le chemin** (les galets dessinés, AU-DESSUS du verre
   vidéo), vues à entrées stables (id, position, état), aucune closure en
   propriété.

---

## 5. L'ANATOMIE DES CINQ ÉCRANS (cotes MESURÉES §2bis, pour 402×874 pt)

Toutes les fenêtres sont pleine largeur (402) sauf mention, clouées à leur
bord. La « bande du chemin » est l'interstice noir mesuré, rogné de 20 pt
de politesse à chaque bout.

**ÉCRAN 1 — LE VERRE NOIR** (l'ouverture : presque rien)
- Haut : `duo-galet-noir` 402×520, top — le col touche le bord (mesure
  y 0-41), l'arc du ventre à y 355-472. Parallaxe -0,10.
- Bas : `duo-flamme-blanche` 402×262, bottom (elle naît à y 612).
- Bande du chemin : y 492→592 → **1 galet** : le premier, SEUL. L'écran
  d'ouverture ne montre qu'une étape — très Apple, et c'est la maquette.

**ÉCRAN 2 — LA FLAMME SUSPENDUE**
- Haut : `duo-flamme-blanche-haut` 402×323, top.
- Bas : `duo-galet-rouge` 402×200, bottom, dôme décalé à gauche (centre
  ~x 150 — le cadrage est CUIT dans le fichier, pas un offset runtime).
- Bande du chemin : y 343→657 → **3 galets**, pas ~105 pt.

**ÉCRAN 3 — LE ROUGE (la parité exos, en matière)**
- Haut : `duo-verre-rouge` 402×280, top — le crop re-cuit du fond exos.
- Bas : `duo-flamme-rouge` 402×300, bottom (elle naît à y 574).
- Bande du chemin : y 300→554 → **2 galets**, pas ~127 pt.

**ÉCRAN 4 — LE FEU RENVERSÉ**
- Haut : `duo-flamme-rouge-haut` 402×304, top.
- Bas : le dôme ROUGE du calque frontière (§4.3), visible dès y 588.
- Le trait violet : fil spéculaire dessiné à y 500-517 (défaut :
  REPRODUIT — §2 et §10.2), incliné comme la maquette, école fil de crête.
- Bande du chemin : y 324→478 → **2 galets**, pas ~115 pt (le fil violet
  vit SOUS la bande, il ne la mange pas).

**ÉCRAN 5 — LE BLEU (l'arrivée)**
- Haut : le ventre BLEU du calque frontière — la fenêtre 700 pt étant plus
  généreuse que la maquette, le verre descend jusqu'à ~y 345 (mesuré au
  banc), pas 265.
- Bas : `duo-flamme-bleue` 402×233, bottom (elle naît à y 641).
- Bande du chemin : y **365**→621 → **2 galets + LE NŒUD-TRÉSOR** (§6.3),
  pas ~110 pt.

**Total : 11 étapes** (1+3+2+2+3) — l'arithmétique tient dans les bandes
mesurées, plus de chiffre de papier. Serpentin : amplitude ±62 pt autour
de l'axe, ajustée par écran dans `EcranSpec`.

---

## 6. LES GALETS DU CHEMIN — l'expérience Duolingo en verre

### 6.1 Le composant : `GaletEtape`

École LaunchPebble en petit (l'assemblage de référence — on réduit, on ne
réinvente pas) :

- Dôme : `Ellipse` en RadialGradient obsidienne/nacre (**6 stops**, école
  LaunchPebble) + FOYER en voile elliptique séparé blur ~10 (« un gradient
  radial ne sait faire que des ANNEAUX »).
- Liseré-lumière : `galetLisere` (colorEffect, GaletLisere.metal:70) — la
  cloche gaussienne iso-distance, jamais un stroke. (Précision payée au
  fouettage du plan : galetLisere composite en source-over, il n'a PAS la
  mécanique `× color.a` — celle-là appartient à la famille Aurora/BravoPill.
  L'hôte se choisit par la mécanique du shader, pas par réflexe.)
- **Le « légèrement 3D » servi pour de vrai** (il manquait) : un flanc de
  2-3 pt sous le dôme (l'épaisseur que le press mange), le foyer spéculaire
  qui dérive au gyro (±2 pt, école SkyMotion) et glisse VERS le doigt au
  press, `rotation3DEffect` ≤ 4° vers le point de contact. Pas de
  liquidLens (rien à réfracter dans le noir — LOI 3).
- Diamètre : 76 pt (84 pour l'ACTIF — la hiérarchie par la taille, le
  registre le plus Apple qui soit). Glyphe laqué (école galet play : corps
  mat, glyphe laqué).
- **Glyphes : le vocabulaire de la MAISON, jamais celui de Duolingo** —
  star/dumbbell/chest recopiés fabriqueraient le verdict « clone cartoon »
  dès J2. Défaut : le CHIFFRE d'étape laqué (école cadran EclipseCounter —
  le chemin est du verre peint, un chiffre y est légal) ; le croissant de
  lune pour les jalons. §10.4 pour trancher.
- ⚠️ Gardes du raster : toute énergie meurt avant le bord du pad (le CADRE
  FANTÔME) ; arité vérifiée au premier build (page BLANCHE sinon) ;
  scalaires sortis en `let` avant l'appel.

### 6.2 La grammaire des états (LOI 4 : la matière et la taille parlent)

| État | Taille | Matière | Vie |
|---|---|---|---|
| verrouillé lointain | 76 | obsidienne mate, glyphe gravé 22 % | aucune — un caillou |
| **verrouillé PROCHAIN** | 76 | idem, glyphe gravé **30 %** | l'appel silencieux du suivant |
| **actif** | **84** | nacre, glyphe laqué blanc plein | le souffle asymétrique du liseré (`breath(t, lag:)` de LaunchPebble) — UN seul signe de vie, pas d'anneau ; option : la progression DANS l'actif = un niveau de nacre qui monte dans le dôme (le liquide de verre) |
| accompli | 76 | nacre calme, glyphe blanc | liseré fixe éteint aux ¾ ; **accompli-récent** : une braise résiduelle une session |
| accompli PARFAIT | 76 | nacre | le souffle d'or dans le liseré (le précédent validé de la carte obsidienne) |

- Pressé : enfoncement **3 %** (« au-delà, un bouton qui rebondit se lit
  comme un jouet ») + le flanc qui se mange + rampe horodatée 0,10 s
  down / 0,26 s up en TimelineView (un uniform n'est pas animable — école
  pressLevel JewelTabBar) + haptique `.impact(.medium, 0.85)` au front
  montant (école des ButtonStyle maison — ObjectiveCardPressStyle et le
  style des cards exos).
- **Le refus d'un verrouillé = L'IMMOBILITÉ** (le fouettage a tué la
  micro-secousse : le wiggle est le geste passcode/Duolingo, exactement le
  shake qu'on prétendait éviter). Le press s'avorte à 1 %, retour froid ;
  le liseré s'allume une fois, froid, 0,12 s ; haptique `.rigid` sèche.
  Un caillou refuse en étant un caillou. (Et le piège du double
  withAnimation disparaît avec la secousse.)
- Tap sur l'actif = le passage d'étape, PARTITION en §7.

### 6.3 Le tracé, le trésor

- Serpentin par les positions SEULES — **pas de fil pointillé** (le trope
  board-game, la double faute : Duolingo lui-même n'en a pas, et un
  pointillé 1,5 pt se lit UI-kit cheap). Option en §10.6 : un filament
  spéculaire continu à cloche gaussienne (école liseré) qui n'existe qu'en
  mémoire derrière les étapes accomplies — défaut : RIEN.
- **LE NŒUD-TRÉSOR** ferme le chemin (fin d'écran 5) : le galet majeur
  96-100 pt, obsidienne, portant le moonCoin — le « chest » Duolingo, c'est
  le booster de Woop, et toute l'économie carte-lune existe déjà pour le
  nourrir plus tard. Inerte cette session : il ponctue, il promet, il ne
  s'ouvre pas.
- État initial : étape 1 active, le reste verrouillé ; flag `-duoEtape <n>`
  pour poser un état arbitraire (captures, allers-retours du fouettage).
  Le tap-avance ne persiste pas (session UI, reset au relaunch).

### 6.4 La dalle de chapitre + le rail de jeu

- **Verre natif `.clear` nourri par la vidéo** — tranché MAINTENANT (le
  « un jour » était une contradiction : la fenêtre haute de CHAQUE écran
  est pleine largeur au repos, la dalle est TOUJOURS posée sur de la
  vidéo — le cas exact que la loi affinée du 20-08 autorise : contenu doux
  dessous, l'encre AU-DESSUS du verre, jamais dans le conteneur).
  Fallback si le verre déçoit au banc : la dalle noire liseré (§10.5).
- Elle vit HORS scroll (école PorteEntree), **s'efface pendant le geste**
  (offset -12 + fondu du CONTENU ; le verre lui-même est démonté sous 1 % —
  la loi : le natif IGNORE `.opacity`) et revient à la pose.
- **Le titre change PAR ÉCRAN** en crossfade au passage de frontière — le
  beat cinématique gratuit : « CHAPITRE 1 » en petites capitales grises,
  puis le nom de l'écran (« Le verre noir », « La flamme suspendue »…).
- **Le rail de jeu** (l'amendement des juges : Kathryn remet la STRATÉGIE
  à plus tard, pas la surface — une page sans compteur se lit vide, et
  Woop possède déjà les monnaies) : sur la dalle, pastille moonCoin +
  compte, la flamme-jauge en glyphe braise statique, la pill booster.
  Chiffres FACTICES, inertes, monochromes, chiffres laqués. Zéro couleur
  inventée.

---

## 7. LES PARTITIONS (le « cinématique très belle » se compose, il ne se
constate pas)

**L'OUVERTURE (1,4 s, une horloge, école DepartCine — des fonctions pures
de e, pas des DispatchQueue)**
- t 0 : noir pur, tout à rate 0 sauf l'écran 1.
- t 0 → 0,45 : le galet noir s'allume — un voile noir 1→0 sur sa fenêtre
  (l'illumination, école iPod/porte) ; sa vidéo vit déjà dessous.
- t 0,35 → 0,95 : la flamme basse monte (voile 1→0, 0,6 s).
- t 0,50 : le premier galet naît (scale 0,92→1 + fondu, rampe Animatable).
- t 1,1 : la dalle se pose (offset -12→0 + fondu 0,3 s).

**LE PASSAGE D'ÉTAPE (tap sur l'actif)**
- t 0 : haptique medium 0,85 + l'enfoncement.
- t 0 → 0,25 : le liseré de l'actif se fige et monte d'un ton (l'adieu).
- t 0,25 : la bascule d'état en KEYFRAMES (le piège du double
  withAnimation) : nacre calme en 0,35 s, la taille 84→76 en spring doux.
- t 0,30 : le suivant s'allume — souffle qui part de zéro, 76→84.
- Si le suivant vit sur l'écran suivant : t 0,45, `scrollTo(y:)` vers la
  POSE AIMANTÉE de cet écran (0,7 s easeInOut) — jamais une position
  mi-écran que l'aimant re-happerait (la contradiction tranchée) ;
  haptique d'atterrissage à la pose (école CalLab, sans la poudre).

**LA FRONTIÈRE (pendant le geste — tout en visualEffect, zéro invalidation)**
- Le voile sortant : l'écran qui part reçoit un voile noir 0→12 % linéaire
  sur sa moitié de frontière — le « fondu noir quand nécessaire » du brief,
  version runtime ; la frontière appartient à UN objet, les autres
  s'effacent (LOI 1).
- La température du chemin : les liserés glissent (blanc chaud ↔ froid)
  avec la position de frontière.
- Parallaxe des galets vidéo : -0,10 à -0,14 (le verre est lourd, il prend
  du retard) ; les flammes restent clouées à leur bord.
- **La frontière 4/5, le morceau de bravoure** : le galet rouge-et-bleu
  suit une courbe en S (il s'attarde ~8 % au centre du viewport — la
  parallaxe non-linéaire en visualEffect), échelle 1,00→1,02→1,00, et UNE
  haptique light à la bascule rouge→bleu (hystérésis, une seule fois par
  traversée).
- L'atterrissage d'un écran : haptique `.impact(.medium, 0.9)` + la
  respiration de l'actif repart de zéro.

---

## 8. LES PIÈGES DÉJÀ PAYÉS QUI MONTENT LA GARDE ICI

| # | Piège | Où il frapperait | Garde |
|---|---|---|---|
| 1 | `-ss` ne coupe pas le graphe ffmpeg | tous les trims/fondus §3 | trim+setpts DANS le graphe, profil de luminance au portillon |
| 2 | le noir H.264 soulevé (limited range) | 9 fichiers sur page noire OLED | p50 zone noire ≤ 2/255, curves sinon |
| 3 | le trou du looper (1-3 images vides/tour) | chaque boucle | pose DANS la vue, effacée sur isReadyForDisplay |
| 4 | preroll avant readyToPlay = crash | chaque lecteur | preroll attaché à la KVO .status |
| 5 | la vidéo déborde son cadre (aspectFill UIKit) | toutes les fenêtres | clipsToBounds + masksToBounds + ratio fichier = ratio fenêtre |
| 6 | la fente detail gonfle son hôte | chaque fenêtre vidéo | overlay sur Color.clear, bords au gradient numpy |
| 7 | la page ré-évaluée par image | la sonde de scroll | @Observable EtatDuo, page qui n'en relit rien, visualEffect |
| 8 | la sonde constante / deux sondes | le ScrollView unique | UNE SondeDuo composée, champ vivant + stables |
| 9 | le ScrollView hors écran (ping-pong d'insets) | rien de prévu hors écran | interdit de monter un scroll offset sous le bord |
| 10 | rampes sur p sous withAnimation | apparitions, ouverture | struct Animatable |
| 11 | le double withAnimation | la bascule d'état du passage | keyframes (§7) |
| 12 | arité d'un stitchable = page BLANCHE | galetLisere/corpsLisere réutilisés | arité vérifiée au premier build |
| 13 | l'hôte d'un colorEffect mal choisi | GaletEtape | la mécanique du shader décide : `× color.a` avale tout (famille Aurora/BravoPill), galetLisere composite en source-over — lire le .metal avant de choisir l'hôte |
| 14 | le cadre fantôme au bord du pad | GaletEtape | énergie morte avant le bord, vérif zoom ×8 |
| 15 | grep masque l'échec du build | toutes les captures | stat du binaire avant capture |
| 16 | un AVPlayerLayer invisible décode quand même | les 10 lecteurs permanents | rate piloté par la sonde via CalqueVideoPilote (né-en-pause RÉGLÉ — §4.2), VStack non-lazy assumé |
| 17 | glassEffect à jeun sur noir | tentation verre natif sur les étapes | LOI 3 : le chemin est PEINT ; le natif vit sur la dalle nourrie |
| 18 | simctl launch ne relit pas les args | tous les lancements | --terminate-running-process systématique |
| 19 | reduceMotion ignoré | vidéos, respiration, -duoAuto, parallaxe | chemin court explicite : rate 0 + posters, respiration morte, parallaxe nulle, ouverture en fondu simple |
| 20 | les ancres de ligne sur CalLab périment | les citations de ce plan | CalLab bouge sous une session parallèle — citer par NOM (BacAimant, moletteScene), jamais par ligne |

---

## 9. LES JALONS — un commit, un banc, un verdict chacun, et le
MINI-FOUETTAGE À CHAQUE JALON (la règle : AUTOMATIQUE avant toute
présentation — film + détecteur de flash + allers-retours d'états ; le
complet en J5)

| # | Ce qu'on juge | Livrable / portillons chiffrés |
|---|---|---|
| **J0 — LA CUISSON** | les 9 fichiers + 9 posters + le script | `recuit_duo.sh` rejouable ; couture palindrome ≤ 2/255 ; fondus image 0 = 0,00 ; noir p50 ≤ 2/255 ; gradient p99 mesuré par flamme (≤ 3,0 sinon 3×) ; ratio fichier = ratio fenêtre, vérifié ; extinctions aux cotes EcranSpec ; déphasage des -haut vérifié + film côte à côte ; budget par écran ≤ 90 / 150 Mpix/s, sommé dans le script ; poids ≤ 45 Mo |
| **J1 — LA COLONNE NUE** | les 5 écrans + la frontière statique + l'aimant + le rate piloté (CalqueVideoPilote) | banc `-duoLab` ; **silhouette vs maquettes ±4 % par bord (numpy §2bis)** ; p99 des 4 bords visibles de CHAQUE fenêtre posée ≤ 4/255 ; lecteurs vivants = courant + entrant, prouvé au log ; **≥ 22 pixel-buffers/s par calque vivant** (SondeCadence est aveugle au diaporama vidéo — les DEUX nombres, la leçon de la scène de départ) ; `-duoAuto` filmé : zéro flash en V (< 45 % des voisines) ; battement 3:2 regardé ; LOI 2 par écran (p99 bande chemin ≤ 8/255) |
| **J2 — LE GALET-ÉTAPE** | `-duoGalets` : la grammaire §6.2 sur mire, press/refus/3D | pas de cadre fantôme ×8 ; enfoncement 3 % + flanc + tilt ≤ 4° au film ; rampes 0,10/0,26 mesurées ; arbitrage §10.1 (liquid glass) et §10.4 (glyphes) JUGÉS ICI ; non-régression LaunchPebble/CorpsNacre au gel si un shader partagé est touché |
| **J3 — LE CHEMIN + LA DALLE** | serpentin 1/3/2/2/3 + trésor + tap-avance + ouverture + dalle nourrie + rail | arbitrages §10.5/§10.6 tranchés AVANT ce code ; galets tous dans leur bande mesurée ; **zéro invalidation du body de page pendant un scroll filmé (compteur, école page-ré-évaluée)** ; l'ouverture au film |
| **J4 — LA FRONTIÈRE 4/5 + les partitions** | la courbe en S, les voiles sortants, la température des liserés, le trait violet | **delta de position du galet chevauchant ≤ 1 pt entre deux images du film à la couture** ; la bascule haptique une-fois vérifiée aux allers-retours ; `-duoViolet` comparé |
| **J5 — LE FOUETTAGE COMPLET + VERDICT TÉLÉPHONE** | la règle entière | transitions filmées + flash ; SondeCadence 60 tenus par régime, chaque trou > 33 ms expliqué, ET ≥ 22 pixel-buffers/s par calque ; battement 3:2 des lents ; **non-régression des archives** (gels avant/après des bancs voisins) ; relecture adverse de la table §8 ; allers-retours d'états (`-duoEtape`) ; noirs OLED + chauffe au téléphone — le sim est AVEUGLE aux gels Metal |
| **R-n — LE RECALAGE** (rejouable) | l'écran n repassé par Kathryn | re-mesure numpy de la maquette n → diff d'EcranSpec → re-cuisson du fichier touché seul → silhouette ±4 % |

Chaque jalon se commite PAR CHEMINS (la leçon des sessions parallèles),
messages en français, aucun trailer.

---

## 9bis. JALONS J0 + J1 — LIVRÉS LE 24-08 (banc `-duoLab`, sim kat-duo, dd-duo/)

**Livré** : `tools/duolingo/recuit_duo.sh` (9 fichiers `Woop/Media/duo-*.mp4`
+ 9 poses) ; `Woop/Views/DuolinguoPage.swift` (EcranSpec, EtatDuo,
CalqueVideoPilote, la colonne VStack + frontière 4/5 + voiles sortants +
parallaxe, le banc DuoLab) ; le branchement `-duoLab` dans RootView.
Sim dédié `kat-duo` (iPhone 17 Pro, 402×874), DerivedData `dd-duo/`.

**Mesuré (les portillons)** :
- couture palindrome : 0,29-1,76 /255 selon fichier (portillon 2) ✓
- bords de fenêtre en plein écran : p99 = 0,0 sur les 8 arêtes ✓ ; les
  seuls p99 élevés sont les bords d'ÉCRAN, où la flamme doit toucher ✓
- noir H.264 : zones noires à vrai 0 ✓ ; poids total 14,3 Mo (≤ 45) ✓
- bandes du chemin (LOI 2) : p99 = 0,0 sur les CINQ écrans ✓
- film `-duoAuto` (23,5 s, 1352 frames) : **zéro flash en V** hors
  lancement de l'app (frames 14-20 = la transition de launch) ✓ ;
  ~38 images distinctes/s au sim (norme 18-36) ✓
- fidélité maquettes : vérifiée écran par écran en côte à côte (deux
  recadrages payés, voir pièges) — le verdict final reste à Kathryn.

**Pièges payés (nouveaux, à ne pas repayer)** :
1. **La parallaxe sur minY absolu** : `visualEffect` +
   `frame(in: .scrollView).minY` donne la position dans le VIEWPORT — une
   fenêtre du bas vit à minY = 674 au repos, le `-minY × k` la décalait de
   −67 pt à la pose (le dôme rouge remontait dans la bande du chemin,
   mesuré p99 = 240). La parallaxe se calcule sur le DÉPLACEMENT
   `minY − restY`, avec le restY de CHAQUE fenêtre (haut = 0, bas =
   H − hFenêtre). Et un objet à cheval sur deux poses (la frontière) n'a
   PAS de repos unique → clouée en J1, chorégraphiée en J4.
2. **Le double encodage pose des macro-blocs** : master crf 16 → final
   crf 20 sur le dégradé clair du ventre du galet = blocs à arêtes
   droites au zoom ×4 (la source est propre). Les galets se cuisent en
   UNE passe à crf 17 — le palindrome n'a pas besoin d'un master, le
   compte d'images se lit sur la SOURCE.
3. **`$flt[v]` en zsh est un subscript** : dans un graphe ffmpeg composé
   en shell, écrire `"...$flt[v];..."` fait disparaître le filtre
   (« No such filter: '' ») — toujours `${flt}[v]`.
4. **Les cotes devinées mentent** : les deux premiers cadrages de galets
   étaient trop larges (capsule flottante au lieu du zoom de la maquette).
   La boîte utile SE MESURE (numpy : bbox > seuil + rangée la plus claire
   pour le ventre) avant de couper — c'est ce qui a donné x 537-1635 /
   ventre y 2878 (noir) et x 528-1718 / sommet y 642 (rouge).
5. **xcodebuild ne voit pas un sim fraîchement créé par id** : destination
   `generic/platform=iOS Simulator` puis `simctl install` — et jamais de
   pipe vers grep (le code de sortie est celui de grep).

**Reste ouvert (J1)** : le verre rouge de l'écran 3 VOYAGE dans la boucle
exos (tantôt gauche comme la maquette, tantôt droite) — c'est la parité
exos vivante, verdict Kathryn ; la largeur de la frontière (90 % de
l'écran) rend le galet 4/5 plus central que la maquette ; la preuve fine
« lecteurs vivants = courant + entrant » attend le téléphone (J5).

## 9ter. JALONS J2 + J3 — LIVRÉS LE 24-08 (même session)

**Livré** : `Woop/Views/GaletEtape.swift` (le galet-étape : dôme mat 6
arrêts, flanc que le press mange, foyer qui glisse vers le doigt,
micro-tilt ≤ 4°, liseré `galetLisere` par états, refus par l'immobilité,
mire `-duoGalets` sur deux fonds) ; le chemin dans la colonne (11 étapes
1/3/2/2/3, serpentin ±62 dans les bandes mesurées, nœud-trésor 98 pt à la
lune), le tap-avance (bascule 0,25 s + allumage du suivant + scrollTo la
POSE aimantée si l'écran change), la naissance en cascade (60 ms d'écart),
la dalle de chapitre (verre `.clear` nourri + pellicule noire + titre par
écran en crossfade + rail factice lune/flamme), l'effacement de la dalle
pendant le geste (sonde de PHASE, séparée de la géométrie), flags
`-duoEtape <n>`.

**Mesuré** : aller-retour filmé avec chemin + dalle : zéro flash en V,
~42 images distinctes/s au sim ; la cascade de naissance joue au film ;
l'encre de la dalle lisible sur les deux matières extrêmes (flamme
blanche / verre noir).

**Pièges payés (nouveaux)** :
6. **`domeRS.x` de galetLisere est un RAYON** (LaunchPebble passe D =
   rayon) — passé en diamètre, l'arc flottait à 38 pt HORS du dôme.
7. **`fondu` de galetLisere attend des COSINUS** (LaunchPebble:289-290 :
   `cos(deg × π/180)`) — en degrés bruts le fondu sature et le liseré
   fait un ANNEAU complet : le radio-button interdit, rendu par erreur.
8. **La boule de billard** : un écart trop grand entre le cœur et le bord
   du dégradé radial lit « balle de ping-pong » — la matière de la maison
   est MATE, le volume vient du flanc, du liseré et du foyer.
9. **L'encre sur verre nourri de matière claire se perd** : la pellicule
   noire (0,30) AU-DESSUS du verre, SOUS l'encre — l'école de la molette —
   règle la lisibilité ET calme l'anneau fantôme du bout de capsule.
10. **DragGesture(minimumDistance: 0) dans un ScrollView** : la fin d'un
    scroll qui passe sur un galet compte comme un tap — le tap se garde
    par la course (< 12 pt).

**Reste ouvert (J2/J3)** : le press/refus/tilt se jugent AU DOIGT (le sim
ne tape pas) ; « CHAPITRE 1 » encore discret sur flanc très clair ; le
léger halo au bout droit de la dalle (écran 1) ; verdicts téléphone.

## 9quater. JALON J4 — LIVRÉ LE 24-08 (même session)

La partition de la frontière : **la courbe en S** (le galet rouge-et-bleu
s'attarde au centre du viewport — retard en sin(π·u) culminant à +0,08 H à
mi-traversée, mort aux deux poses) + **la houle d'échelle** (2 %) en
visualEffect pur, et **la haptique de bascule** rouge→bleu quand la
couture traverse le centre du viewport (y = 3,5 H), hystérésis 60 pt, une
par traversée, dans `piloter()` (champs `@ObservationIgnored`). Les voiles
sortants étaient déjà posés depuis J1. Se juge AU DOIGT et au téléphone
(J5) : la courbe en S au film, le delta ≤ 1 pt à la couture.

---

## 10. LES ARBITRAGES EN ATTENTE (verdicts Kathryn — les défauts sont posés,
rien n'est codé avant J-concerné)

1. **« Liquid glass » → verre PEINT pour les étapes** (LOI 3). Le plan
   réinterprète le mot du brief : le natif sur petits objets sur noir rend
   un trou dans du métal — mais c'est TON mot, donc ton verdict, sur J2
   (un galet natif de comparaison sera sur la mire).
2. **Le trait violet de l'écran 4** — défaut : REPRODUIT (fil spéculaire,
   y 500-517). Banc `-duoViolet` pour le voir mort/vivant.
3. **Aimant doux contre `.paging` sec** — au doigt, sur J1.
4. **Les glyphes des étapes** — défaut : chiffres laqués + croissant de
   lune. (Star/dumbbell interdits même en provisoire.)
5. **La dalle de chapitre** — défaut : verre `.clear` nourri par la vidéo ;
   fallback : dalle noire liseré. Et son LIBELLÉ (« CHAPITRE 1 » ?) t'appartient.
6. **Le liant du serpentin** — défaut : RIEN (les positions seules) ;
   option : filament spéculaire mourant derrière les accomplis.
7. **Le hflip des flammes hautes** — défaut : OUI (décorrélation) ; c'est
   un écart aux maquettes, dis si tu le refuses.
8. **L'entrée/sortie de page dans l'app réelle** — hors session, mais le
   défaut proposé est écrit : `fullScreenCover` depuis la home (école
   coffre/story, il couvre la barre bijou). Le pattern Sacre reste
   possible si la page devient une cérémonie.
9. **24 contre 30 i/s** — défaut : 24 natif (zéro frame fabriquée) ; si le
   battement 3:2 se voit au téléphone (J5), bascule 30 re-cuite.
10. **Le ralenti des flammes hautes** — défaut : NON ; A/B au J0 seulement
    si les jumelles battent en phase malgré la rotation.
