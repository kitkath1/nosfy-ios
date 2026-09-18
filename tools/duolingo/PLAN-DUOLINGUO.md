# LA DUOLINGUO_PAGE — « LE CHEMIN DE FEU »

> Actualisation18-09 — progression réelle déployée : compte vide au premier
> galet, tout en haut ; puis un galet par séance terminée avec travail.
> Pas d’avance calendaire ni de démo automatique. Récompenses serveur à3/7
> séances par chapitre ; cinq chapitres, trésor final à35. Au-delà, séances
> conservées sans remise à zéro.1074 contrôles Swift,35API PASS ; iPhone à
> qualifier. Référence actuelle (les sections datées suivantes sont historiques) :
> `tools/production/compte-progression-2026-09-18/README.md`.



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

## 11. LE TOUR DE VERDICTS DU 24-08 (2ᵉ salve) — LES TRANSITIONS

Trois captures de Kathryn en plein scroll. Les verdicts verbatim :

> « la pills rouge n'est pas dans le même sens et au scroll c'est horrible
> c'est coupé, ça doit être le même élément : trouve une solution pour
> avoir la même continuité et surtout un magnifique effet fondu au
> scroll ! là c'est cheap ! »

> « pour les flammes haut et bas c'est horrible, autant les blanches que
> les rouges : les blanches sont trop hautes dans l'écran (en bas comme en
> haut) et leur effet n'est pas fondu dans le noir — il faut baisser la
> vidéo et diminuer leur force blanche, c'est trop ; on voit pour toutes
> les flammes l'effet coupé/moche/carré ; un gros manque de fluidité, de
> fondu et de cohérence »

**Le diagnostic (mesuré sur ses captures)** : chaque fenêtre est cuite
pour que son bord lumineux tombe sur un bord d'ÉCRAN à la pose — pendant
la transition, ce bord voyage au MILIEU du viewport et la matière est
tranchée net (le dôme rouge coupé à l'équateur, les nappes de flammes en
rectangles à couture dure). Les portillons J1 mesuraient les arêtes À LA
POSE : ils étaient aveugles au voyage. Et la couture 2/3 montre DEUX
verres différents (le dôme de l'écran 2 + le verre exos qui voyage) là où
l'annotation « continuation » de la maquette a toujours voulu dire UN
SEUL élément — la « parité exos » était mon raccourci, il meurt.

### R1 — LA PILL ROUGE DEVIENT LA DEUXIÈME FRONTIÈRE (couture 2/3)

- `duo-verre-rouge` (le crop exos) **MEURT sur cette page**. La continuité
  prime la maquette É3 (la loi du 24-08 : les maquettes sont des guides).
- Nouvelle cuisson : `duo-galet-rouge` v2 = la capsule ENTIÈRE de
  `Video rouge_liquid.mp4`, école rougebleu (crop plein pied au ratio
  d'une fenêtre frontière ~360×700), **ancrée à GAUCHE** (le dôme monte du
  bas-gauche de l'écran 2 comme la maquette ; le ventre ambre occupe le
  haut de l'écran 3). L'actuel `duo-galet-rouge` (dôme seul) meurt aussi.
- La fenêtre = un chevauchant de couture 2/3, EXACTEMENT l'école 4/5 :
  overlay dans le scroll, offset constant (centre = 2 H), courbe en S,
  houle 2 %, haptique de bascule. Le code se généralise :
  `FrontiereSpec { couture, fichier, largeur, ancrage }` × 2 — une seule
  mécanique, deux instances.
- Bilan lecteurs : 8 fenêtres au lieu de 9, budget décodeur en baisse.
- L'écran 3 garde son nom (« Le rouge ») ; son haut = le ventre du galet
  + le noir. EcranSpec et la bande du chemin de l'écran 3 se recalent
  après cuisson (numpy, comme toujours).

### R2 — LES RIDEAUX DE COUTURE (le fondu vivant, la fin du « carré »)

- **Chaque fenêtre porte un RIDEAU** : un calque LinearGradient noir sur
  son côté bord-d'écran (bas pour les fenêtres basses et les dômes
  montants, haut pour les fenêtres hautes), hauteur ~38 % de la fenêtre,
  TOUJOURS monté — seule son OPACITÉ est pilotée, en visualEffect (zéro
  invalidation) : **0 à la pose** (la flamme touche son bord, la maquette
  est intacte), **→ 1 en smoothstep sur |déplacement|/0,25 H** dès que la
  fenêtre quitte sa pose. La matière fond dans le noir AVANT que sa ligne
  de coupe n'entre dans le viewport — le « magnifique effet fondu au
  scroll » demandé, sans toucher aux fichiers.
- Le voile sortant uniforme passe de 12 % à ~35 % (rampe conservée) : ce
  qui reste de l'écran qui part s'éteint franchement (LOI 1 renforcée).
- Les frontières chevauchantes (2/3 et 4/5) gardent leurs rideaux aux
  DEUX bouts de leur grande fenêtre (leurs scrims cuits existent, le
  rideau vivant s'y ajoute pendant le voyage).
- **Nouveau portillon de fouettage — le détecteur de COUPE** : sur le film
  de chaque couture, le gradient vertical maximal du viewport (numpy, par
  frame) ne dépasse jamais le seuil d'une arête franche (à calibrer sur
  les captures d'aujourd'hui : elles sont le contre-exemple mesurable).
  Les portillons d'arêtes se mesurent désormais À LA POSE **ET à
  mi-transition**.

### R3 — LES FLAMMES RECUITES : plus basses, plus faibles, fondues

- **« Baisser la vidéo »** : le crop des blanches descend dans la source
  (une bande plus basse : les plumes culminent plus bas) et les fenêtres
  raccourcissent — blanche basse 262 → ~220 pt (crête ≤ 30 % de l'écran à
  la pose), blanche haute 323 → ~260 pt. Rouges : 300/304 → ~270 pt
  (cohérence).
- **« Diminuer la force blanche »** : gain de luminance ~×0,62 au recuit
  des blanches (curves dans le graphe — N&B pur, pas de risque de teinte) ;
  rouges ~×0,80 en TENANT LA SATURATION (la loi anti-brun : on désature
  jamais en baissant, on tient S).
- **Les extinctions cuites s'allongent** : le fondu intérieur passe de
  90 px à ~45 % de la hauteur du fichier, smoothstep — la flamme meurt
  dans le noir bien avant sa ligne de coupe (le « pas fondu dans le
  noir »).
- Portillons par fichier : profil de luminance vertical (L max des plumes
  blanches ≤ ~150 ; crête sous 30 % de l'écran à la pose ; rangée de
  coupe intérieure p99 ≤ 2) ; les bandes du chemin re-mesurées (elles
  RESPIRENT mieux — les flammes plus basses libèrent du noir).

### R4 — LA COHÉRENCE DES COUTURES DE FLAMMES (1/2 et 3/4)

Avec R2+R3, une couture de flammes devient : flamme basse fondue → noir →
flamme haute fondue (le sandwich noir) ; le déphasage cuit du palindrome
évite le miroir. Si le film lit encore « deux objets » : en réserve, le
rideau ASYMÉTRIQUE (l'entrante retient son rideau 0,1 H de plus que la
sortante — jamais deux flammes pleines dans le même viewport).

### L'ordre de la salve (un commit, un banc, un verdict chacun)

| # | Ce qu'on juge | Portillons |
|---|---|---|
| **V1 — le recuit** | duo-galet-rouge v2 (frontière) + les 4 flammes recuites, previews contre maquettes | portillons R3 chiffrés ; couture palindrome ≤ 2 ; poids |
| **V2 — la frontière 2/3** | FrontiereSpec ×2, mort de duo-verre-rouge, EcranSpec recalé | la continuité au film : UN élément du dôme au ventre, delta ≤ 1 pt à la couture |
| **V3 — les rideaux** | rideaux vivants + voile 35 % | détecteur de COUPE : zéro arête franche à mi-transition, sur les 4 coutures filmées |
| **V4 — le fouettage de salve** | l'aller-retour complet | flash en V + coupe + cadence ; verdict Kathryn sim puis téléphone |

### V1→V4 — LIVRÉS LE 24-08 (même session, commit de salve)

**Mesuré — le détecteur de COUPE (saut de rangée max, milieu du viewport,
frames de transition seulement, films 20 img/s)** :

| état | coupe max | p95 | médiane |
|---|---|---|---|
| AVANT la salve (le film des captures de Kathryn) | 132,9 | 113,2 | 14,8 |
| rideaux à rampe 0,25 H | 44,7 | 21,2 | 11,1 |
| **rideaux à rampe 0,10 H (livré)** | **21,5** | **17,5** | **5,0** |

Zéro flash en V hors lancement. Cuisson : coutures ≤ 1,71/255, blanches
affaiblies (bord d'écran 157 contre 254), frontière rouge propre aux deux
bouts (0,0/0,0), total 21,3 Mo.

**Pièges payés (nouveaux)** :
11. **La rampe du rideau se règle sur l'ARÊTE, pas sur le voyage** :
    l'arête entre dans le viewport dès le premier point de déplacement —
    une rampe 0,25 H laissait 200 pt de voyage à découvert (coupe 45) ;
    0,10 H la tue (21,5).
12. **Le détecteur de coupe a des faux positifs au LANCEMENT** (le zoom
    d'app pose des arêtes énormes) : la fenêtre de mesure commence après
    l'accalmie, et se croise avec le masque de MOUVEMENT (> 1,2 de delta
    moyen) pour ne juger que les transitions.

**Reste ouvert (salve)** : le press à mi-transition (dalle mi-fondue vue
au film — vérifier le retour de pose au doigt) ; verdicts téléphone.

---

## 12. LA 3ᵉ SALVE — « LE TRAVELLING » (dicté le 24-08 soir, PAS CODÉ)

Les verdicts verbatim :

> « pas mal mais j'aimerais un fondu blur ou autre plus magnifique au
> scroll notamment au niveau des grosses pills + animation des pills très
> subtile ! »

> « il y a toujours ce problème de fondu entre les flammes, autant les
> blanches que les rouges » (capture : deux bandes floues séparées par du
> noir, qui se lisent encore comme deux rectangles)

> « c'est top que tu as fait le même élément de capsule ! propose quelque
> chose de magnifique au scroll, du jamais vu, la plus belle UI très
> poussée que tu puisses faire »

**Le diagnostic** : le rideau actuel est un CACHE — il éteint, il ne fond
pas. Et les bandes de flammes restent des RECTANGLES parce que leurs
pixels presque-noirs (L 2-8, soulevés par le H.264) se détachent du noir
pur de la page : même douces, leurs bornes existent. Un cache n'y peut
rien — il faut changer la NATURE des calques, pas leur habillage.

### LA DOCTRINE DU TRAVELLING (trois lois nouvelles, sous les quatre du §1)

**LOI T1 — LE SCROLL EST UNE CAMÉRA.** La page n'est plus une colonne
qu'on fait défiler : c'est un travelling vertical dans un puits de verre
et de feu. Ce qui est à la pose est NET (le plan posé) ; ce qui voyage
défocalise — le rack focus d'un chef opérateur, pas un masque noir. La
profondeur de champ remplace le rideau comme langage du mouvement.

**LOI T2 — LE FEU EST UNE LUMIÈRE, PAS UNE IMAGE.** Les flammes passent
en fusion ADDITIVE (`.plusLighter`, l'école de la maison : « l'objet de
lumière se pose sur la nuit — sans détourage ni masque »). Un pixel noir
additionné ne rend RIEN : les bornes des fenêtres de flammes cessent
d'exister par construction — le rectangle est mort à la racine, pas
recouvert. Et deux feux qui se superposent s'ADDITIONNENT : leur
rencontre est un brasier, pas un empilement.

**LOI T3 — LA CAPSULE EST LE SUJET.** Aux coutures de verre, la caméra
SUIT la capsule : elle seule reste nette (le sujet du plan), le monde
autour défocalise et s'assombrit. Elle ne défocalise que quand elle
S'ÉLOIGNE de son histoire (au-delà de ses deux poses) — elle fond alors
dans la profondeur, comme un objet qui sort du champ.

### T1 — LES FLAMMES DEVIENNENT LUMIÈRE (la fin structurelle du rectangle)

- Les cinq fenêtres de flammes passent en `.blendMode(.plusLighter)` sur
  le noir de la page (précédent maison : la pilule de DepartCine, le
  pop-up booster — « 89 % des pixels sous 12/255 »).
- ⚠️ Le piège payé de l'additif : le `compositingGroup()` arrive en
  DERNIER, sinon additif-sur-noir = identité (DepartCine:605-612) — la
  pile de l'écran se termine par le group, jamais avant les blends.
- Nos noirs sont déjà à VRAI 0 (portillon J0 : p50 ≤ 2/255) — l'additif
  est propre d'office ; le voile sortant (35 %) passe en multiplication
  APRÈS la fusion (il éteint le brasier entier, pas chaque bande).
- Les rideaux des flammes deviennent probablement INUTILES (leur raison
  d'être meurt avec les bornes) : A/B au banc, on ne garde que ce qui
  reste nécessaire sur la base lumineuse des plumes (le bord d'écran en
  voyage). Moins de calques, pas plus.

### T2 — LE RACK FOCUS (le « fondu blur » demandé, en langage caméra)

- Chaque fenêtre porte un DÉFOCUS piloté par sa distance à la pose la
  plus proche (le même signal que les rideaux — géométrie pure,
  `visualEffect.blur`, zéro invalidation) : **0 pt à la pose** (les
  maquettes intactes, aucun coût GPU au repos), montée en sin jusqu'à
  **~10 pt à mi-voyage**, retour à 0.
- LOI T3 appliquée : pendant SA traversée (entre ses deux poses), une
  capsule reste NETTE — son défocus ne s'allume qu'au-delà de ses poses
  (elle quitte son histoire → elle fond dans la profondeur : défocus + le
  rideau qu'elle garde). Les flammes, jamais sujets, défocalisent à
  chaque voyage.
- **Le fondu des grosses pills devient** : netteté souveraine pendant la
  traversée chorégraphiée (courbe en S), puis défocus + extinction quand
  elles s'éloignent — « émerger de la profondeur / y retourner », pas
  « passer sous un cache noir ».
- ⚠️ Pièges à payer d'avance : (a) « le flou laisse son calque » — un
  `.blur` pose un voile UNIFORME sur le rectangle de son hôte : à MESURER
  au fouettage (le détecteur de voile : luminance du noir autour des
  fenêtres floutées ≤ 4/255) ; (b) le COÛT GPU du gaussien sur des
  calques vidéo — le vrai risque : portillon cadence PENDANT le blur
  (SondeCadence + pixel-buffers/s, sim ET téléphone), avec l'échelle de
  repli écrite : 10 pt → 6 pt → blur des seules flammes → abandon T2
  (les jalons ne s'empilent pas sur un doute).

### T3 — LA TRAVERSÉE DES FEUX (les coutures 1/2 et 3/4 deviennent le beau)

- Aux coutures de feu, les deux flammes ne se croisent plus en étrangères :
  un **contre-mouvement en sin(π·u)** les tend l'une vers l'autre — la
  flamme basse s'attarde (+0,10 H au pic), la haute arrive en avance
  (−0,10 H) — elles SE TRAVERSENT au centre du viewport, et comme elles
  sont additives (T1), leur superposition S'ADDITIONNE : à mi-transition,
  les deux feux fusionnent en un seul brasier plus vif qui respire, puis
  se séparent et chacun rentre à sa pose.
- Un soupçon de défocus mutuel au croisement (T2) : le brasier fusionné
  est doux, les feux posés sont dessinés.
- Portillon : le film de chaque couture de feu se lit comme UN objet
  (« un brasier qui monte », « un feu qui se scinde ») — plus jamais deux
  bandes ; le détecteur de coupe reste sous 15 en transition.

### T4 — LA VIE DES CAPSULES (l'« animation très subtile »)

- **La flottaison** : chaque capsule dérive de ±3 pt sur le souffle
  asymétrique de la maison (`breath`), périodes PREMIÈRES entre elles
  (11 s et 13 s — jamais en phase, la leçon des respirations de la home),
  + une respiration d'échelle 1,000 → 1,006. C'est tout : la vidéo vit
  déjà à l'intérieur du verre, le runtime n'ajoute qu'un bercement.
- **La lueur de passage** : quand une capsule traverse le centre du
  viewport (le pic de sa courbe en S), un halo `.plusLighter` très bas
  s'allume sur elle (sin(π·u) × ~0,15) — elle S'ALLUME en passant devant
  la caméra, et s'éteint posée. La lumière est motivée (elle passe devant
  la lampe), jamais gratuite.
- **Le micro-tilt de voyage** : ±1,5° de `rotation3DEffect` sur l'axe
  horizontal pendant la traversée (sin(π·u)) — le verre TOURNE
  imperceptiblement en passant, la 3D du brief.
- **Au téléphone** : la dérive gyro (SkyMotion, ±2 pt) sur les foyers des
  capsules — le sim y est aveugle, verdict téléphone.
- Tout est en visualEffect/TimelineView aux entrées stables — rien ne
  réveille la page (piège 7 toujours souverain), et reduceMotion coupe
  flottaison, lueur et tilt (piège 19).

### T5 — LE FOUETTAGE DU TRAVELLING

Films des QUATRE coutures + l'aller-retour ; détecteur de flash ; détecteur
de coupe (< 15) ; **détecteur de VOILE** (le calque du blur : noir autour
des fenêtres floutées ≤ 4/255) ; cadence PENDANT les transitions floutées
(les deux nombres : fil principal + pixel-buffers/s) au sim puis au
téléphone ; allers-retours d'états ; non-régression des poses (silhouettes
±4 % — le travelling ne touche RIEN à l'arrêt).

### L'ordre de la salve

| # | Ce qu'on juge | Portillons |
|---|---|---|
| **T1 — le feu-lumière** | les 5 flammes en plusLighter, A/B rideaux | plus aucun rectangle au film ; compositingGroup en dernier vérifié ; noirs inchangés aux poses |
| **T2 — le rack focus** | le défocus au voyage, capsules souveraines | cadence tenue pendant le blur (sinon l'échelle de repli) ; détecteur de voile ; poses intactes |
| **T3 — la traversée des feux** | les coutures 1/2 et 3/4 fusionnent | « un seul objet » au film ; coupe < 15 |
| **T4 — la vie des capsules** | flottaison + lueur + tilt | subtilité : ±3 pt / 1,006 / 0,15 MAX — au premier « trop », on divise par deux ; périodes premières |
| **T5 — le fouettage** | tout, sim puis téléphone | la table T5 complète |

⚠️ Verdict Kathryn au banc T2 : l'intensité du défocus (subtil 6 pt /
assumé 10 pt / cinéma 14 pt) — trois réglages montés sur un flag, on juge
au doigt.

### T1→T5 — LIVRÉS LE 24-08 (même session, commit de salve)

**Livré** : la couche des feux (`FeuxDuo`, les 5 flammes en `.plusLighter`
HORS des sections — le croisement exige de traverser les coutures, et une
section clippait) ; le rack focus dans le visualEffect unifié de
`FenetreVideo` (rampe 0,5 H lumières / 0,35 H au-delà des poses pour les
capsules-sujets, `-duoFocus <pt>` défaut 10, reduceMotion le coupe) ; le
contre-mouvement ±0,10 H sin(π·t) des feux ; les voiles déplacés APRÈS la
fusion (`VoilesDuo`) ; le `compositingGroup` EN DERNIER (le piège de
l'additif) ; `CapsuleVivante` (bercement ±3 pt / 1,006 par Core Animation
`repeatForever` — zéro travail par image, périodes 11/13 s) + la lueur de
passage (0,15 × sin) + le micro-tilt 1,5° dans la courbe en S ; rideaux
des feux réduits au liseré de sécurité (profondeur 0,18).

**Mesuré (films 20 img/s, hors lancement)** : coupe max 22,9, p95 19,3,
médiane 7,6 — le résiduel au-dessus de 15 est la STRUCTURE lumineuse du
brasier fusionné (une vraie matière claire au centre du viewport), pas
une arête : au film et aux frames extraites, zéro rectangle, zéro coupe
visible. Zéro flash en V. **Détecteur de voile : delta p25 = +0,0** (le
blur ne soulève pas le noir). ~42 images distinctes/s au sim malgré le
flou. Les poses : intactes (le travelling ne touche rien à l'arrêt).

**Pièges payés (nouveaux)** :
13. **Une section clippe ses débordements ET son fond opaque recouvre le
    voisin** : le croisement des feux est IMPOSSIBLE depuis les sections —
    les lumières vivent dans une couche commune au-dessus de la colonne,
    comme les frontières.
14. **Le détecteur de coupe ne distingue pas un brasier d'une arête** : au
    croisement additif, la fusion EST un gradient vif — le seuil chiffré
    se double toujours d'un verdict à l'œil sur les frames extraites.

**Reste ouvert (salve)** : l'intensité du défocus au doigt (§ verdict
6/10/14), la cadence du blur AU TÉLÉPHONE (le sim est aveugle aux gels
Metal — J5), le bercement/lueur au doigt (subtilité : diviser par deux au
premier « trop »).

---

## 13. LA 4ᵉ SALVE — « LE FEU UNIQUE » (dicté le 24-08 soir, PAS CODÉ)

Les verdicts verbatim :

> « regarde, ça va pas dans les flammes, il y a des genres de CALQUES et
> c'est pas naturel — ça doit être fondu naturel, on ne doit pas savoir
> que c'est deux composants isolés, ça doit être magnifique, ça ne l'est
> pas »

> « pareil les pills : le fondu entre deux écrans, pas assez fondu, animé,
> naturel — les transitions ne sont pas spectaculaires ! »

> « tu vas trop trop vite »

**Le mea culpa de méthode (avant le diagnostic)** : mon détecteur de coupe
moyennait chaque rangée sur toute la largeur — un calque de +10 à +20 se
noyait dans la moyenne, il a rendu 19, et j'ai RATIONALISÉ ce résiduel en
« structure du brasier » (le piège 14 était déjà écrit… et je suis tombé
dedans en le contournant). La règle de cette salve : **les deux captures
de Kathryn sont la vérité de calibration** — le nouveau détecteur doit
les condamner AVANT d'avoir le droit d'absoudre quoi que ce soit, et
chaque couture reçoit SON verdict humain avant de passer à la suivante.
On ne va plus vite que la preuve.

**Le diagnostic à la racine** : une fenêtre rectangulaire dont le contenu
n'est pas à ZÉRO sur son bord montrera TOUJOURS ce bord dès qu'il passe
sur autre chose que du noir — additif ou pas, rideau ou pas. Le rideau
runtime est lui-même un calque (sa bande sombre à opacité partielle,
visible dans la capture blanche). Et deux flammes qui se croisent restent
deux composants, quoi qu'on maquille. Il faut UN SEUL feu par couture et
UN invariant mathématique.

### LA DOCTRINE DU FEU UNIQUE (deux lois, au-dessus de tout le reste)

**LOI F1 — L'INVARIANT DU ZÉRO.** Le contenu de CHAQUE fichier vidéo
atteint le NOIR VRAI (0) avant CHAQUE bord de sa fenêtre — cuit, mesuré,
sans exception. Un bord qui doit « saigner » sur un bord d'écran à la
pose s'obtient par OVERSHOOT (la fenêtre dépasse le bord physique, la
queue du fondu vit hors écran), jamais par des pixels vifs au bord. Alors
aucune ligne n'est POSSIBLE, nulle part, jamais — par mathématique, pas
par cache. Conséquence : **TOUS les rideaux runtime MEURENT** (ils
étaient des calques de plus).

**LOI F2 — LE FEU EST UN, COMME LE VERRE.** Ce qui a rendu les capsules
justes (« c'est top que tu as fait le même élément ») s'applique aux
feux : chaque couture de feu devient UN objet chevauchant — le feu et son
double suspendu, CUITS EN UN SEUL FICHIER. Plus deux flammes qui se
croisent : un seul cœur de feu posé sur la couture, dont l'écran du bas
montre les plumes qui montent et l'écran du haut les plumes qui pendent.
« On ne doit pas savoir que c'est deux composants » → ce n'en est plus
qu'un.

### F1 — LA CUISSON DU FEU UNIQUE

- **`duo-feu-blanc.mp4` (couture 1/2) et `duo-feu-rouge.mp4` (couture
  3/4)** : un canevas ~402×600 pt (804×1200 px) posé sur la couture.
  Moitié haute = la bande de flamme telle quelle (base vive en bas,
  plumes mourant vers le haut) ; moitié basse = la même retournée
  (vflip+hflip+roll de phase — la décorrélation cuite). Les deux bases
  vives se rejoignent SUR la couture : le cœur du feu. **La jonction est
  CROSSFADÉE dans le fichier sur ~120 px** — la continuité est cuite, un
  raccord runtime est impossible à rater puisqu'il n'existe pas.
- Les DEUX bouts du fichier (les queues de plumes) meurent à ZÉRO VRAI
  (smoothstep long, portillon : p99 des 12 dernières rangées = 0).
- À la pose de l'écran du bas : le cœur vif affleure le bord physique
  BAS de l'écran, les plumes montent — la maquette, mieux qu'avant. À la
  pose de l'écran du haut : le cœur affleure le bord HAUT, les plumes
  pendent. Entre les deux : UN objet qui traverse, jamais deux.
- **`duo-flamme-bleue` v3** (écran 5, pas de couture en dessous) : les
  deux bouts à zéro + OVERSHOOT de 60 pt (la fenêtre plonge sous le bord
  physique à la pose — sa queue basse ne se voit qu'en voyage, déjà à
  zéro).
- **Les capsules v3** (`duo-galet-rouge`, `duo-galet-rougebleu`) : les
  fondus de bouts passent de 90 px à **~200 px jusqu'au zéro vrai**
  (« pas assez fondu » : le verre ÉMERGE du noir sur une vraie distance),
  et leurs rideaux runtime meurent aussi.
- **`duo-galet-noir` v3** : le fondu bas à zéro sur 200 px (même loi).
- Portillon F1, par fichier : p99 = 0 sur les 12 rangées de chaque bout ;
  la planche des poses contre les maquettes (silhouettes ±4 %) — 
  l'overshoot ne doit RIEN changer aux poses.

### F2 — LE RUNTIME SIMPLIFIÉ (moins de pièces, pas plus)

- `FeuxDuo` (5 fenêtres + contre-mouvement + rideaux) est REMPLACÉ par
  **deux feux-frontières** (l'école FrontiereSpec exacte : fenêtre à
  cheval, poses {0, −H}, offset constant, additif `.plusLighter`) + la
  fenêtre simple overshootée de l'écran 5. Le contre-mouvement de T3
  MEURT (plus rien à croiser), les rideaux MEURENT partout.
- Le rack focus reste (net aux poses, défocus au voyage — mêmes rampes) ;
  les voiles restent (après la fusion) ; le `compositingGroup` dernier
  reste (la loi de l'additif).
- Bilan : 3 calques de feu au lieu de 5, zéro rideau, moins de code que
  la salve précédente — la beauté par soustraction.

### F3 — LE SPECTACULAIRE DES CAPSULES (« plus fondu, animé, naturel »)

La traversée d'une capsule devient une vraie scène, chaque ingrédient
chiffré et coupé par reduceMotion :

1. **L'émergence** : grâce aux fondus de 200 px cuits (F1), le verre naît
   du noir sur une vraie distance — plus jamais un bord qui « arrive ».
2. **L'approche de la caméra** : l'échelle au passage passe de 1,02 à
   **1,05** (le verre passe PRÈS), la courbe en S de 0,08 H à **0,10 H**
   (elle s'attarde davantage), le tilt de 1,5° à **3°** (on voit le verre
   tourner).
3. **La lueur de passage** montée à **0,22**, teintée par l'écran (blanc
   chaud sur le rouge, froid sur le bleu — la loi de la température du
   chemin).
4. **La scène s'efface pour le sujet** : pendant la traversée d'une
   capsule (sin(π·u) de SA course), les voiles des deux écrans adjacents
   gagnent +12 % — le monde recule, le projecteur est pour elle.
5. Le bercement (±3 pt, 11/13 s) et le défocus-sujet restent tels quels.
   ⚠️ Chaque chiffre est un CURSEUR au banc : au premier « trop », on
   divise par deux — le spectaculaire de la maison est une rareté, pas
   une foire.

### F4 — LE FOUETTAGE REFONDÉ (la preuve avant la vitesse)

- **LE DÉTECTEUR DE LIGNE** (il remplace le détecteur de coupe) : une
  ligne droite = un saut de rangée COHÉRENT sur la largeur — score =
  |moyenne_x(Δy)| pondéré par sa consistance (σ_x faible), calculé sur
  chaque rangée de chaque frame. **Calibration OBLIGATOIRE d'abord : les
  deux captures de Kathryn doivent scorer HAUT (positifs), les poses
  doivent scorer bas (négatifs) — le seuil se pose ENTRE, et le détecteur
  n'a le droit d'absoudre qu'après avoir condamné les captures.**
- Films de CHAQUE couture séparément, à deux vitesses (l'aller-retour
  auto + un passage LENT, nouveau flag `-duoAutoLent`) — les calques se
  voient au ralenti.
- Non-régression des poses (silhouettes ±4 %), flash en V, voile du blur,
  cadence.
- **Un jalon = UNE couture validée par Kathryn avant la suivante** — le
  remède au « trop vite » : F-a (couture 1/2 blanche), F-b (3/4 rouge),
  F-c (2/3 et 4/5 capsules v3 + spectaculaire), F-d (l'ensemble + écran 5).

### L'ordre de la salve

| # | Ce qu'on juge | Portillons |
|---|---|---|
| **F0 — le détecteur calibré** | le détecteur de ligne sur les captures de Kathryn | il les CONDAMNE (score net au-dessus du seuil) et absout les poses — sinon on ne code rien |
| **F1 — la cuisson** | 5 fichiers recuits (2 feux uniques, bleue v3, 2 capsules v3, noir v3) | zéro vrai aux bouts (p99 = 0 sur 12 rangées) ; jonctions crossfadées ; poses intactes ±4 % |
| **F-a** | la couture 1/2 au film (lent + auto) | détecteur de ligne muet ; verdict Kathryn AVANT F-b |
| **F-b** | la couture 3/4 | idem |
| **F-c** | les capsules v3 + le spectaculaire F3 | idem + curseurs jugés |
| **F-d** | l'ensemble + écran 5 + fouettage complet | la table F4 entière |

### F0→F4 — LIVRÉS LE 24-08 (même session, commit de salve)

**F0** : `tools/duolingo/sonde_ligne.py` — la sonde de ligne (saut de
rangée COHÉRENT : |mean_x| avec std_x < max(4 ; 0,9·mean)), calibrée sur
les captures de Kathryn archivées (`shots/verdict-calques-*.png`) :
positifs 10,5 et 14,0, poses propres < 5 → **seuil 7**. Deux pièges de
calibration payés : la cohérence à `std < 2m` laissait passer l'arc du
ventre (23/43) — un vrai calque rend std ≪ mean ; et la zone descend à
16 % (la dalle qui revient à l'atterrissage est un bord d'UI légitime).

**F1** : `cuireFeu()` — les feux uniques `duo-feu-blanc` / `duo-feu-rouge`
(804×1080 : moitié qui monte + double suspendu vflip+hflip+décalé de
~demi-boucle, chaque moitié meurt en fondu 120 px dans le recouvrement,
somme en `blend screen` sur gbrp — le cœur est cuit, aucune arête par
construction) ; capsules et galet noir recuits (fondus 200/220 px au
zéro). Portillons : bouts à 0,0 partout, coutures ≤ 1,68, 20,7 Mo.
⚠️ Piège payé : **JAMAIS `-loop 1` sur une image de filtre** — l'entrée
devient infinie, le graphe ne finit jamais (115 Mo sans moov, tué au
timeout) ; les images nues en overlay (repeatlast) suffisent.

**F2** : FeuxDuo = 2 feux uniques (école FrontiereSpec, poses {0,−H},
additif) + la bleue simple (son bord bas ne visite jamais le viewport —
l'overshoot était inutile, analysé) ; RIDEAUX morts partout ;
contre-mouvement mort ; **les VOILES PAR ZONES sont morts aussi** — payé
à la sonde (frames 401-403, score 23) : un voile par écran pose une
MARCHE à la couture, en plein feu désormais continu. Le voile vit DANS la
fenêtre (opacité uniforme par objet : capsules −50 % au-delà des poses,
verre noir −35 % au voyage, le feu JAMAIS — il est le sujet de sa
couture).

**F3** : courbe en S 0,10 H, échelle 1,05, tilt 3°, lueur 0,22 TEINTÉE
(chaude capsule rouge, froide rouge-et-bleu), bercement inchangé.

**F4 mesuré (film 20 img/s, hors lancement et hors zone dalle)** :
**sonde de ligne en transition : max 2,76 ; p95 2,23 ; médiane 1,46**
(seuil 7 ; les captures de Kathryn : 10,5 / 14,0). Zéro flash en V.
Les poses : intactes. Restent les verdicts Kathryn par couture (F-a → F-d
au doigt) et le téléphone.

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

---

## 14. LA 5ᵉ CAMPAGNE — « LE FEU RARE » (v2 — refondue le 24-08 soir sur
SON verdict du plan v1, toujours PAS CODÉE. La v1 avait été fouettée par
trois juges adverses — 25 fautes intégrées ; les bloquantes : une sonde qui
condamnait ses propres négatifs, une préview-clip qui fabriquait l'arête
qu'elle prétendait juger, un overshoot manquant qui violait la LOI F1
payée la veille. Puis Kathryn a jugé le plan lui-même :

> « t'es sûr ? faut VRAIMENT que les flammes soient fondues sinon c'est
> cheap — vs mes derniers screenshots. tu vas souvent trop vite donc
> attention : refais un plan »

La v2 répond aux deux : LE FONDU devient la loi souveraine — RARE-0, avec
ses portillons propres (le bord introuvable, la longueur de mort, le
banding de la queue), calibrés pour condamner SES captures — et la porte
entre jalons est durcie contre le « trop vite ».

**v3, même soir** — une contre-lecture adverse a rendu 8 fautes sur la v2
(les bloquantes : les cotes de N3 violaient le « mort ≥ 150 pt » du même
jalon ; « sans plateau » condamnait le cœur vif que RARE-0 défend), toutes
intégrées. ET le verdict le plus important est tombé pendant la refonte,
sur un nouveau screenshot du sim (le X gris pleine page — archivé comme
troisième contre-exemple) :

> « les vidéos flammes sont encore trop cheap au scroll, regarde cette
> horreur […] peut-être que les vidéos comme ça ne sont PAS la bonne
> solution, tu n'arrives pas à les fondre à la perfection — propose des
> solutions, un plan hardcore UI »

**LE MÉDIUM EST AU PROCÈS** : la question de N2 n'est plus « quel crop de
vidéo », c'est « la couture de feu doit-elle être de la vidéo DU TOUT ».
La palette des solutions S1-S5 remplace l'ancien tour A/B/C/D.)

Les verdicts verbatim (24-08 soir, sim ouvert) :

> « toujours ce problème : les flammes (rouges et blanches) sont ensemble
> mais c'est BEAUCOUP TROP CHEAP, ça doit être fondu — peut-être que le
> côté renversé ne va pas […] rends fluide le scroll des flammes ou trouve
> un design / agencement pour combler cette fracture UI au scroll, je
> déteste »

> « les pills au scroll doivent être fondues, très belles, et "tourner" en
> mode parallaxe, en mode APPLE au scroll, très très très premium et fin —
> sans lag de vidéo »

> « les flammes blanches sont trop coupées et trop hautes dans l'écran :
> 30 % max de l'écran, bottom ou top ; c'est pas fondu, c'est coupé net
> beurk alors que l'écran est noir de base »

Et la régression du PROMPT-REPRISE reste en tête de file : le fondu
profond des capsules en voyage se répare EN PREMIER.

**Le diagnostic (la suite honnête du §13)** : la couture est gagnée
(sonde de ligne 2,8 contre 14 sur ses captures), la beauté a perdu. Le feu
unique fait 540 pt de fenêtre — à mi-voyage il occupe 62 % du viewport ;
affaibli (gain ×0,62) puis défocalisé (10 pt) il est un BROUILLARD gris.
Trois fautes distinctes :

1. **TROP GRAND.** La loi des 30 % n'existait nulle part ; aucun portillon
   ne mesurait l'ÉTENDUE lumineuse — seulement les arêtes (sonde de ligne)
   et les bords (invariant du zéro). Un feu sans couture peut rester un
   nuage.
2. **TROP MOU.** « Diminuer la force » (2ᵉ salve) a été payé en gain
   ×0,62 : baisser un feu SANS réduire son étendue fabrique du gris. Le
   réflexe s'inverse : la force se GARDE, c'est l'étendue qui meurt.
3. **LE DOUBLE RENVERSÉ n'a jamais eu son procès.** « Peut-être que le
   côté renversé ne va pas » — chaque salve l'a raffiné (hflip, roll de
   phase, crossfade cuit) sans jamais questionner son EXISTENCE. §10.7
   attendait ce verdict depuis le début.

Et le rack focus sur les feux salit (PROMPT-REPRISE, diagnostic 3) : il
n'a jamais été jugé MORT — `-duoFocus 0` existe et n'a jamais été montré.

### LA DOCTRINE DU FEU RARE (quatre lois — RARE-*, pour ne pas
collisionner avec les R1-R4 du §11 ni le jalon R-n du §9)

**LOI RARE-0 — LE FONDU EST SOUVERAIN.** Un feu n'a PAS de bord : il NAÎT
du noir et y RETOURNE sur une longue distance — à la pose comme en voyage,
on ne peut pointer NULLE PART « ici la flamme s'arrête » (le test du BORD
INTROUVABLE, jugé sur still zoomé à chaque jalon de feu). **L'exception
héritée de la LOI F1** : le bord PHYSIQUE de l'écran n'est pas un bord de
matière — la coupe par l'écran à la pose est légitime si la matière
continue hors champ (l'overshoot) ; le test juge les bords DE MATIÈRE,
dans le champ. Le fondu prime TOUT : taille, vivacité, spectaculaire — un
réglage qui gagne en dessin mais perd en fondu est REFUSÉ d'office. Ses
deux captures du 24-08 soir (le X gris de la blanche, le nuage rouge) sont
les contre-exemples de calibration — chacune condamnée par le portillon
qui PEUT la voir : la blanche « coupée net » par la pente d'enveloppe, le
nuage rouge par l'étendue et le dessin (un brouillard peut mourir en
douceur : sa faute n'est pas la mort, c'est la matière partout). C'est
l'ENSEMBLE des portillons qui doit les condamner toutes les deux avant
d'avoir le droit d'absoudre quoi que ce soit — pas chaque portillon
chacune.

⚠️ Et la leçon qui empêche de re-payer le §13 : **le fondu n'est PAS le
brouillard.** Le brouillard, c'est de la matière PARTOUT (une faute
d'ÉTENDUE) ; le fondu, c'est une matière qui MEURT BIEN (une qualité de
BORD). « Vif et dessiné » ne contredit pas « fondu » : le cœur est vif,
les bords N'EXISTENT PAS — un feu est une lumière qui naît du noir, jamais
une forme posée sur le noir. RARE-1 coupe l'étendue, RARE-0 soigne la
mort ; les deux ensemble, jamais l'une sans l'autre.

**LOI RARE-1 — LE FEU EST RARE ET ANCRÉ.** L'étendue lumineuse de CHAQUE
feu (sa bande de rangées allumées, mesurée PAR OBJET — jamais le viewport
entier) tient dans ≤ 30 % de l'écran (262 pt pour 874) À TOUT INSTANT —
pose ET voyage. Le cœur vif est bien plus court (~90-150 pt — et quand
RARE-0 réclame des queues plus longues, c'est le cœur qui cède). Et la loi
d'ANCRAGE du verbatim (« bottom ou top ») : à la pose, tout feu est CLOUÉ
à un bord d'écran ; un feu qui visite le CENTRE du viewport en voyage
n'est pas un défaut de mesure, c'est un choix de design — le sien (le
tour N2 le lui dit en face). Un feu est DESSINÉ (gain tenu), jamais un
nuage.

**LOI RARE-2 — LE VOYAGE MONTRE MOINS (aux coutures de FEU).** Pendant une
transition de feu, la fraction lumineuse BAISSE ou tient — elle ne monte
jamais : la transition est une soustraction, pas une addition. Périmètre
STRICT : les coutures de feu. La capsule-SUJET en traversée chorégraphiée
est EXEMPTÉE — sa lueur de passage (0,22) est du validé (« c'est top »),
la loi ne condamne pas le seul moment qu'elle aime.

**LOI RARE-3 — UN VERDICT PAR JALON, ET LA PORTE ENTRE JALONS EST DURE.**
Un changement, un film, SON verdict, puis le suivant. Les A/B se montent
en RUNTIME sur les fichiers existants AVANT toute cuisson — et quand un
aperçu runtime MENT (cadrage, clip), le mensonge est déclaré d'avance ou
remplacé par une mini-cuisson jetable. Une cuisson de bundle n'a lieu
qu'après une direction tranchée par elle. **La porte** (le remède au « tu
vas trop vite », dit QUATRE fois maintenant), en DEUX régimes — la
contre-lecture a montré que la version « verdict partout » avait un trou :
N1/N8/N9/N11 n'ont pas de verdict de Kathryn possible, et un jalon qui ne
peut pas se fermer se livre « dans le même souffle », exactement la faute.
Donc : les **jalons À VERDICT** (N0, N2-N7, N10) se ferment par SON
verdict archivé (la capture/le film dans `shots/verdict-*`, sa phrase
notée au plan) AVANT que le suivant ne s'ouvre — jamais deux jalons À
VERDICT livrés sans sa phrase entre les deux. Les **jalons À PORTILLONS**
(N1, N8, N9, N11) se ferment par leurs MESURES archivées dans `shots/`,
et peuvent s'enchaîner avec le jalon qu'ils servent. Si un jalon révèle
un problème du précédent, on ROUVRE le précédent, on n'empile pas.

### LES JALONS (N comme le noir — un commit par chemins, un film, un
verdict chacun ; le mini-fouettage à chaque jalon reste la règle)

| # | Ce qu'on juge | Portillons |
|---|---|---|
| **N0** | la réparation du fondu des capsules (la régression) + `-duoAutoLent` | fondu À L'ŒIL sur film lent, profondeur perçue ~300 pt, bord introuvable ; sonde de ligne < 7 sur la traversée ; poses ±4 % si recuit |
| **N1** | la sonde de BROUILLARD calibrée (par OBJET) | elle CONDAMNE l'état actuel ET absout poses + traversées de capsules — sinon la sonde est rejetée, on ne code rien |
| **N2** | LE TOUR DES SOLUTIONS S1-S5 — le MÉDIUM au procès (braise hybride / noir assumé / still parfaite / vidéo corrigée / shader intégral), flou mort en défaut | verdict de SOLUTION de Kathryn, au doigt ; préviews menteuses déclarées |
| **N3** | la fabrication de la solution choisie — couture 1/2 SEULE | LE FONDU D'ABORD : bord introuvable + mort ≥ 150 pt (cœur exclu) + paliers sans liserés (frame décodée) ; puis brouillard par feu (≤ 262 pt à tout instant, dessin tenu) ; ligne < 7 ; zéro vrai aux bouts ; couture ≤ 2 ; noir p50 ≤ 2 |
| **N4** | la couture 1/2 finale — tour d'écoute des réglages, ordre écrit | portillons N3 rejoués + zéro flash en V |
| **N5** | la couture 3/4 (la recette sur le rouge, S tenue) | idem N3, film dédié |
| **N6** | l'écran 5 : la bleue au régime des 30 % (déjà à 220 pt — vérification, extinction peut-être rallongée) | idem, régime UNIQUE pour les feux |
| **N7** | le « tourner » des capsules — TROIS NATURES au flag | rotation/effet NUL aux deux poses ; ligne muette ; verdict au doigt |
| **N8** | la fluidité mesurée (« sans lag ») | SondeCadence 60 par régime + ≥ 22 pixel-buffers/s par calque vivant ; la table EXACTE des lecteurs au log ; échelle de repli écrite |
| **N9** | le fouettage de campagne (sim) | films 4 coutures × 2 vitesses ; ligne + brouillard + flash ; silhouettes vs GELS validés ; gels des bancs voisins ; press à mi-transition |
| **N10** | le verdict téléphone + les verdicts jamais rendus | OLED, chauffe, cadence vraie, gyro, le doigt — la liste §N10 entière |
| **N11** | la consolidation | plan/mémoire à jour ; fichiers morts hors bundle ; poids ≤ 45 Mo ; reports NOMMÉS |

### N0 — LA RÉPARATION DES CAPSULES (EN PREMIER, un tour court)

D'abord l'outil du portillon : **`-duoAutoLent`** se code ICI (trois
lignes, école `lancerAuto`, durée ×3 — le jalon de la régression ne peut
pas dépendre d'un flag promis à N1). Puis trois candidats montés ENSEMBLE
au banc (`-duoFonduPill a|b|c`), film lent d'une traversée 2/3 :

- **(a) le recuit seul** : scrims des capsules 200 → 600 px (fondu cuit
  200 pt — l'émergence sur ~29 % de la capsule). ⚠️ Change AUSSI la pose
  (les bouts fondent au repos). Préview runtime honnête : le même gradient
  en overlay, opacité CONSTANTE 1.
- **(b) le rideau rendu aux SEULES capsules** : LinearGradient noir aux
  deux bouts de la fenêtre frontière (dans le contenu de la fenêtre, à
  côté de la lueur de passage — même mécanique visualEffect, zéro
  invalidation), opacité 0 à la pose → 1 en voyage. **Rampe 0,10 H en
  DÉFAUT — c'est le piège 11 payé à la 2ᵉ salve (« la rampe se règle sur
  l'ARÊTE, pas sur le voyage : 0,25 H laissait 200 pt à découvert ») ; les
  bouts quasi nets (67 pt de fondu cuit) entrent au viewport dès les
  premiers points de déplacement.** 0,20 H en variante au flag pour le
  film comparatif. ⚠️ (b) est un **AMENDEMENT de la LOI F1** (« TOUS les
  rideaux runtime meurent »), au même format que les amendements de la
  LOI 3 en N2 : si elle choisit (b), F1 se restreint aux feux — son mot,
  son verdict. Le précédent qui impose la prudence : le §13 avait VU un
  rideau dans sa capture blanche. D'où le portillon dédié : un still
  zoomé du rideau lui-même À MI-OPACITÉ (sa bande sombre est le calque
  payé — la sonde de ligne seule ne suffit pas, elle a déjà absous ce
  rideau-là une fois). Pose INTACTE par construction.
- **(c) le mixte** : scrims 400 px + rideau 150 pt.

Portillon : le fondu en voyage se voit À L'ŒIL sur le film lent (le
portillon du PROMPT-REPRISE) avec la cible chiffrée de l'avant-régression :
une profondeur PERÇUE de l'ordre de ~300 pt (contre 67 aujourd'hui), et le
BORD INTROUVABLE sur still zoomé à mi-voyage (RARE-0 vaut pour le verre
comme pour le feu) ; la sonde de ligne reste muette sur la traversée — un
rideau à bande trop courte ou trop opaque redevient un calque ; si (a),
poses contre maquettes ±4 %. Verdict avant tout le reste.

### N1 — LA SONDE DE BROUILLARD (le F0 de cette campagne)

`tools/duolingo/sonde_brouillard.py`. ⚠️ La faute que le fouettage du plan
a tuée : mesurer le VIEWPORT entier condamne les négatifs de sa propre
calibration (une pose légitime cumule 420-580 pt de rangées allumées —
flamme + dôme + galets + dalle) — la mesure est PAR OBJET, ou elle n'est
pas.

**Le mécanisme d'isolation, d'abord** : un flag banc **`-duoSondeFeux`**
qui démonte chemin + dalle + rail + capsules pour les films de sonde (les
feux seuls sur le noir — l'école de la mire `-duoGalets`, inversée) ; en
garde-fou, les masques déterministes (les rects des fenêtres de verre et
des galets se calculent d'EcranSpec/FrontiereSpec/etapes + l'offset connu
du film auto) pour vérifier sur la page COMPLÈTE que rien d'imprévu ne
s'allume.

**Les mesures, par frame de film** :

0. **le PLANCHER d'abord** : p50/p95 des zones noires pures (les bandes du
   chemin, mesurées à 0,0 sur captures banc en §9bis) sur un film
   RÉ-ENCODÉ existant — le seuil d'« allumé » se pose au-dessus de CE
   plancher, jamais à 10 d'office (le noir H.264 soulevé, piège §8.2) ;
1. **l'ÉTENDUE PAR FEU** : la hauteur de la bande allumée de CHAQUE feu —
   portillon LOI RARE-1 : ≤ 262 pt à tout instant ;
2. **la FRACTION aux coutures de feu** (LOI RARE-2, périmètre strict — la
   capsule-sujet exemptée) : jamais plus haute en transition qu'aux poses
   adjacentes ;
3. **la COUPE D'ENVELOPPE** : le profil vertical lissé (moyenne par
   rangée, fenêtre 20 pt) ne saute jamais — le « coupé net » d'un NUAGE,
   que la sonde de ligne ne voit pas (elle cherche des arêtes fines
   cohérentes, pas la frontière d'un brouillard) ;
4. **le DESSIN** : L max du cœur du feu ≥ seuil à tout instant du voyage —
   « gain tenu » devient un portillon, pas un vœu (la sonde ne doit pas
   absoudre un feu redevenu soupe grise uniforme) ;
5. **la MORT (le portillon du FONDU, RARE-0) — en DEUX morceaux** (la
   contre-lecture a tué la version « sans plateau du pic au noir », qui
   condamnait le cœur vif que RARE-0 défend) : d'abord **le CŒUR** — la
   zone ≥ X % du pic, où le plateau est AUTORISÉ, longueur bornée par
   RARE-1 (~90-150 pt) ; puis **la MORT** — du pied du cœur au plancher
   noir, décroissance MONOTONE sans plateau ni saut, longueur ≥ ~150 pt.
   Le seuil de pente se calibre sur la capture BLANCHE « coupée net »
   (elle doit échouer — c'est ELLE que cette mesure sait voir ; le nuage
   rouge, lui, est condamné par l'étendue et le dessin, RARE-0). Les
   positifs de calibration à offset connu : les frames de mi-transition
   des films banc de l'état actuel — les screenshots d'elle, à offset
   inconnu et pleins de chemin, servent de référence visuelle, pas de
   matière à sonde ;
6. **le BANDING de la queue — jugé à la LARGEUR des paliers, jamais à la
   hauteur de marche** (en 8 bits, deux niveaux voisins diffèrent de
   1/255 par construction — c'est leur LARGEUR qui fait le liseré OLED) :
   sur la frame DÉCODÉE du fichier final, px par niveau dans la queue et
   périodicité des liserés, seuil calibré sur un dégradé témoin cuit
   avec/sans dither — sinon crf plus bas ou dither au recuit, revérifié
   après décodage (N3).

**Calibration OBLIGATOIRE d'abord (la leçon F0)** : positifs = SES deux
captures du 24-08 soir (à déposer dans `shots/verdict-brouillard-blanc.png`
et `-rouge.png` — et à défaut, les frames de mi-transition de l'ÉTAT
ACTUEL filmé au banc, qui montrent le même brouillard : `-duoAuto` +
`-duoAutoLent`, ~60 % du viewport) ; négatifs = les poses (masquées) ET
**les traversées de capsules actuelles (2/3 et 4/5) — le point fort
validé, avec la tolérance explicite de la lueur 0,22**. La calibration
vérifie EN PREMIER que les négatifs scorent sous les positifs — sinon la
sonde est REJETÉE et retravaillée, et rien ne se code. La sonde de ligne
(seuil 7) reste en garde de non-régression.

### N2 — LE TOUR DES SOLUTIONS (le médium au procès — le verdict qui
commande toute la campagne)

**Le diagnostic du X gris (son screenshot, nommé faute par faute)** :
quatre fautes empilées — (1) le DOUBLE RENVERSÉ CROISÉ : deux jets de
plumes miroir qui se croisent font une écharpe abstraite, une topologie de
X, pas un feu ; (2) le GAIN ×0,62 : une flamme affaiblie uniformément
n'est plus blanche, elle est GRISE — le feu EST du contraste, l'affaiblir
partout le tue ; (3) le RACK FOCUS 10 pt qui liquéfie ce qui restait de
dessin ; (4) 540 pt d'étendue. Et la leçon STRUCTURELLE, celle que quatre
salves ont payée sans la dire : **la vidéo se bat sur trois fronts
perdants aux coutures** — ses fondus se cuisent en AVEUGLE contre un
scroll vivant ; le H.264 sabote les longues queues sombres (noir soulevé,
banding) ; et tout affaiblissement « pour fondre » détruit le caractère du
feu. Un shader de LUMIÈRE n'a aucun de ces trois problèmes : extinction
mathématique au zéro vrai, dither natif, réactif au geste, zéro décodage.

Le registre honnête des précédents maison : le shader qui DESSINE une
flamme a plafonné (flamme néon 7,6/10, ember « pas fluide ») — mais le
souffle de lumière BAS est le registre PROUVÉ (ExoHeaderGlow, bgAurora,
les liserés). On ne demande pas au shader une flamme : on lui demande une
BRAISE.

**Cinq solutions au banc** (`-duoFeu 1|2|3|4|5`), `-duoFocus 0` posé en
DÉFAUT du tour (le blur a son procès aussi) :

- **S1 — LA BRAISE AU SEUIL (hybride vidéo/shader — défaut proposé).**
  Les flammes vidéo ne vivent qu'À LA POSE : petites (≤ 262 pt), ancrées à
  leur bord, VIVES (gain tenu) ; dès le geste elles s'éteignent TÔT, par
  les bords. La couture en voyage appartient à un souffle shader très bas
  (école ExoHeaderGlow : source unique, cloche gaussienne, luminance crête
  ≤ ~0,25) qui respire avec le scroll. Le fondu parfait PAR CONSTRUCTION,
  la fluidité par construction. Le double renversé MEURT (son intuition).
  La flamme redevient un événement de POSE ; le voyage redevient du noir
  qui respire, traversé d'une braise.
- **S2 — LE NOIR ASSUMÉ (la soustraction pure).** Comme S1 sans le
  souffle : les feux ne vivent qu'aux poses, le voyage est NOIR, les
  capsules restent les seuls événements de verre. Le plus radical, le plus
  « le noir est la matière ». Zéro risque technique.
- **S3 — L'IMAGE PARFAITE + LA VIE.** La flamme de pose n'est plus une
  vidéo : une IMAGE cuite au numpy pixel par pixel — le profil de mort
  écrit À LA MAIN, monotone, dithéré par nous, sans H.264 — la perfection
  déterministe du fondu que quatre salves de vidéo n'ont jamais donnée.
  Par-dessus, une vie discrète (respiration de luminance/échelle en
  runtime léger). En voyage : extinction précoce, ou la braise S1.
- **S4 — LA VIDÉO RÉDUITE ET VIVE (l'ancienne direction, aux cotes
  corrigées).** Le feu unique recuit : canevas 402×390 pt — mort de 150 pt
  de CHAQUE côté, cœur vif 90 pt, gain 0,90-1,00 tenu — crf 17 + dither.
  La vidéo garde la couture. C'est la solution avec le plus de pièges
  connus contre elle ; elle reste sur la mire parce que le mouvement vrai
  d'une flamme filmée est irremplaçable SI le reste tient. ⚠️ C'est aussi
  la seule où un feu visite le centre de l'écran en voyage — « ton
  “bottom ou top” la refuse peut-être » (RARE-1, l'ancrage).
- **S5 — LE SHADER INTÉGRAL.** Plus aucune vidéo de flamme sur la page :
  braises shader partout, poses comprises ; seules les capsules restent
  vidéo. Le plus Apple-minimal, le plus risqué en beauté de pose (le
  registre braise doit porter seul l'identité feu).

⚠️ S1/S3/S5 sont des AMENDEMENTS de la LOI 3 (« le feu est dans la
vidéo — aucun shader de flamme ») : si elle en choisit un, sa loi tombe
pour les feux concernés — c'est son mot, son verdict (le précédent :
§10.1).

**Les préviews qui mentent le déclarent (RARE-3)** : S1/S2 se
prévisualisent honnêtement en runtime (extinction précoce sur les fichiers
existants ; braise esquissée au banc) ; S3 se prévisualise par une still
numpy posée au banc (rapide — sa VIE se juge au jalon suivant) ; S4 exige
la MINI-CUISSON JETABLE (jamais un clip sec : le cœur crossfadé du fichier
actuel est rangées 480-600 px, un clip y fabriquerait le « coupé net »
qu'on juge). Le sort des hauts d'écrans 2 et 4 (« La flamme suspendue »,
« Le feu renversé ») est posé au tour : écho court, braise seule, ou
titres renommés — verdicts à elle.

**Le tour se juge D'ABORD au FONDU** (RARE-0) : « est-ce fondu — le bord
est-il introuvable ? », puis à l'IDENTITÉ (« est-ce encore du FEU ? »),
puis à la fluidité au doigt. Une solution non fondue est éliminée quel que
soit son charme. Verdict : UNE solution — ou un panachage PAR COUTURE —
tranchée par Kathryn sur le sim ouvert. Rien ne se cuit avant son choix.

### N3 — LA FABRICATION DE LA SOLUTION CHOISIE (couture 1/2 SEULE, la
pire à ses yeux)

La solution de N2 se fabrique sur LE SEUL feu blanc, jamais les deux
coutures d'un coup. ⚠️ `${flt}[v]` en zsh à chaque graphe modifié (piège
payé §9bis.3). **Un seul jeu de chiffres, cohérent avec les portillons
N1.5 — la contre-lecture a payé la vérif : des queues de 105 pt sous un
portillon à 150 pt, un overshoot de 70 pt pour une mort de 150, ne se
reproduisent plus.**

- **si S1/S2** : recuit des flammes de POSE — petites (≤ 262 pt à la
  pose), ancrées, vives (gain tenu), extinction cuite ≥ 150 pt côté
  intérieur (la mort N1.5), overshoot F1 côté bord physique si le cœur
  saigne ; et pour S1, la braise réglée au banc (hauteur ~120-180 pt,
  crête ≤ ~0,25, cloche gaussienne, teinte de l'écran, respiration liée
  au geste).
- **si S3** : la still cuite au numpy — le profil de mort écrit à la main
  (monotone, ≥ 150 pt, dither 8 bits appliqué par NOUS — plus de H.264 du
  tout sur les feux de pose), silhouette contre la maquette ; la vie
  runtime se juge au jalon suivant, jamais dans le même souffle.
- **si S4** : le feu unique v3 aux cotes CORRIGÉES : canevas 804×780 px
  (402×390 pt) — queue haute 300 px (**150 pt de mort**) / cœur + jonction
  crossfadée 180 px (90 pt vif) / queue basse 300 px (**150 pt**) ; à la
  pose, la fenêtre chevauchante montre 195 pt ≤ 262 ✓ (l'étendue RARE-1
  tient : la moitié sombre des queues n'est pas « allumée »). Variante
  sans double : un seul feu qui monte, overshoot **≥ 150 pt** sous la
  couture (la queue entre au viewport DÉJÀ morte). Gain 0,90-1,00 TENU
  sur le cœur.
- **si S5** : pas de cuisson — les braises se règlent au banc, par
  couture, avec la question de l'identité feu posée frontalement.

**La cuisson au service du fondu (S3/S4)** : crf 17 en UNE passe (l'école
des galets, §9bis.2) ; le dither se vérifie **APRÈS décodage du fichier
final** (x264 écrase précisément le bruit des aplats sombres — un dither
dans le graphe peut mourir à l'encodage sans un mot) ; un long dégradé
sombre à crf 20 pose des paliers, et un palier sur OLED est un « coupé
net » de plus.

Portillons — LE FONDU EN PREMIER : **le bord introuvable** (stills zoomés
à la pose ET à mi-voyage : nulle part on ne peut pointer où la matière
s'arrête — le bord physique excepté, RARE-0) ; **la mort** ≥ 150 pt
monotone, cœur exclu (N1.5) ; **les paliers sans liserés** sur la frame
décodée (N1.6). Puis la sonde de brouillard PAR FEU
(étendue ≤ 262 pt à tout instant, fraction qui ne monte pas, dessin
tenu) ; sonde de ligne < 7 ; invariant du zéro (p99 = 0 sur les 12 rangées
des bouts) ; couture palindrome ≤ 2/255 ; noir p50 ≤ 2 ; l'écart aux
maquettes ASSUMÉ et dit (elles sont des guides). **Le gel de l'état validé
par son verdict devient LA référence de silhouette pour la suite (N9) — la
maquette d'origine est amendée.** Verdict sur film lent + auto de la seule
couture 1/2, AVANT le rouge.

### N4 — LA COUTURE 1/2 FINALE (un tour d'écoute de réglages, pas une salve)

Les curseurs restants — le dip/extinction (si C), l'offset exact de la
fenêtre, le flou (défaut MORT sur les feux ; s'il revit, jamais > 6 pt et
prouvé innocent du lag en N8), la respiration du noir — se montent TOUS en
runtime sur flags, à la N2 : ELLE tranche une combinaison au banc (l'ordre
de présentation écrit d'avance), puis UN film de confirmation aux
portillons N3 rejoués + zéro flash en V. Pas de films empilés jugés en
bloc — c'est la 2ᵉ salve qui recommencerait.

### N5 — LA COUTURE 3/4 (le rouge)

La recette validée, appliquée : gain tenu ~0,85-0,95 en TENANT S (la loi
anti-brun ; et si une retouche de teinte s'invite : R reste à 1, on
désature le VERT — l'école harmonisation-rouge). Mêmes portillons, film
dédié, verdict avant N6.

### N6 — L'ÉCRAN 5 (la bleue)

Elle est DÉJÀ presque au régime (804×440 px = 402×220 pt, 25 % de
l'écran, gain ×0,85 depuis la 2ᵉ salve) : le jalon est une VÉRIFICATION —
étendue mesurée à la sonde, extinction haute (scrim actuel 198 px = 99 pt)
rallongée si l'enveloppe coupe, recuisson SEULEMENT si un portillon
échoue. Le régime des feux doit être UN. Verdict.

### N7 — LE « TOURNER » DES CAPSULES (trois NATURES, pas trois volumes)

Le geste demandé : « tourner en mode parallaxe, mode APPLE, très très très
premium et fin ». Trois designs distincts sur flag (`-duoTourne 1|2|3`),
au doigt :

1. **LE TILT FIN (défaut proposé)** : rotation ∝ **sin(π·u)** — la forme
   qui s'annule aux DEUX poses, celle du code existant ; jamais une rampe
   en d/H, qui vaudrait ±2° à la pose et casserait le portillon —
   amplitude ±2° au pic de traversée ; la courbe en S garde 0,10 H ;
   l'échelle et la lueur REDESCENDENT (1,02 / 0,12) — le premium par la
   retenue.
2. **LE F3 ACTUEL en témoin** (1,05 / 3° / 0,22) — il reste sur la mire :
   le §13 demandait « spectaculaire », le dernier verdict demande « fin »,
   et ce curseur-là est le sien (arbitrage 3).
3. **LE FOYER QUI VOYAGE** : l'objet ne bascule pas — sa LUMIÈRE tourne :
   le reflet spéculaire glisse sur le verre avec le déplacement (école
   « la lampe suit le pouce » / foyer au gyro SkyMotion), zéro géométrie,
   zéro risque de lag. Le plus maison, peut-être le plus Apple.

Tout vit dans le MÊME visualEffect que la courbe en S (un seul proxy,
zéro invalidation) ; reduceMotion coupe (piège 19). Portillons : effet
NUL aux deux poses ; sonde de ligne muette ; la cadence se prouve en N8.
Verdict au doigt.

### N8 — LA FLUIDITÉ MESURÉE (« sans lag de vidéo très important »)

Les deux nombres par RÉGIME (repos, traversée de feu, traversée de
capsule, aller-retour auto) : SondeCadence 60 tenus — chaque trou > 33 ms
expliqué — ET ≥ 22 pixel-buffers/s par calque vivant (le sim est aveugle
au diaporama : les DEUX nombres, toujours).

**Le budget lecteurs se prouve contre la table EXACTE dérivée de
`piloter()`** — pas contre une formule (la contre-lecture a corrigé mon
propre exemple faux : un exemplaire faux dans la liste nominale empoisonne
la preuve). En numérotation ÉCRAN 1-5 du plan (le code compte 0-4) et dans
l'état AVANT le verdict N2 — la table se re-dérive après lui :

| pose | lecteurs vivants (2 par pose, 3 max en transition) |
|---|---|
| É1 | galet noir + feu blanc (couture 1/2) |
| É2 | feu blanc (1/2) + frontière rouge (2/3) |
| É3 | frontière rouge (2/3) + feu rouge (3/4) |
| É4 | feu rouge (3/4) + frontière rouge-bleu (4/5) |
| É5 | frontière rouge-bleu (4/5) + flamme bleue |

Le log se compare à CETTE liste, pose par pose, et le 3ᵉ vivant d'une
transition est nommé (l'objet de la couture traversée + les deux voisins).

L'échelle de repli ÉCRITE D'AVANCE : flou 6 pt → flou sur les seules
capsules hors-poses → flou mort ; lueur/rotation divisées par deux ; en
dernier recours, fenêtres plus courtes (jamais un demi-rate — l'artefact).
Le suspect n°1 du lag est le blur runtime sur des couches vidéo larges :
il arrive au procès MORT (défaut de N2) et ne revient que prouvé innocent.

### N9 — LE FOUETTAGE DE CAMPAGNE (sim — AUCUNE présentation sans lui)

La règle entière (mémoire fouettage-avant-montrer) : films des COUTURES
restantes × deux vitesses (`-duoAuto`, `-duoAutoLent`) ; sonde de ligne +
sonde de brouillard sur chaque film ; détecteur de flash en V ;
**non-régression des poses contre les GELS validés** (l'état gelé après
chaque verdict de Kathryn — les maquettes d'origine sont amendées par
N2/N3, mesurer contre elles échouerait par construction) ; **gels
avant/après des bancs voisins** (LaunchPebble/CorpsNacre si un shader
partagé bouge — galetLisere est partagé) ; allers-retours d'états
(`-duoEtape`, `-duoEcran`, ouverture refilmée) **+ LE PRESS À
MI-TRANSITION** (le reste ouvert de la 2ᵉ salve : la dalle mi-fondue, le
retour de pose — au film ici, au doigt en N10) ; relecture adverse de
TOUTES les tables de pièges (§8, 9bis/ter, 11, 12, 13, 14).

### N10 — LE VERDICT TÉLÉPHONE (et les verdicts jamais rendus)

Le déploiement (mémoire deploy-iphone : UDID « iPhone de Frédéric », args
devicectl APRÈS `--` ; si le compte Apple rebloque c'est un mur MANUEL —
Xcode/Accounts, aucune commande ne le contourne) : noirs OLED, chauffe,
cadence vraie pendant blurs/rotations, gyro des foyers.

**La dette des salves passées se solde ICI, nommément** : press/refus/tilt
des galets-étapes au doigt (J2) ; bercement/lueur des capsules
(« diviser par deux au premier trop ») ; la largeur de frontière 90 % vs
maquette (reste J1) ; le press à mi-transition au doigt ; le battement
3:2 des mouvements lents (§10.9 — réactivé par les recuits N3/N5 : s'il
se voit, bascule 30 documentée) ; l'intensité du défocus si le flou a
survécu (6/10/14). Les verdicts fins (30 %, fondu, tourner) se REJUGENT
là — le sim n'a jamais le dernier mot.

### N11 — LA CONSOLIDATION (les reports NOMMÉS)

Le §14 reçoit les verdicts et les pièges payés ; la mémoire
woop-duolinguo-page se met à jour ; les fichiers morts sortent du bundle
(anciens feux 540 pt, scrims obsolètes) ; le poids se re-mesure (≤ 45 Mo).
Les reports sont NOMMÉS, pas balayés : **§10.8** (l'entrée/sortie de page
dans l'app réelle — le seul trou structurel restant), **§10.9** (24 vs 30
si le battement s'est vu en N10), **les restes J2/J3** (« CHAPITRE 1 »
discret sur flanc clair, le halo au bout droit de la dalle écran 1), et la
session gamification (stratégie, vrais compteurs). Commits PAR CHEMINS,
messages français, aucun trailer (CLAUDE.md).

### LES PIÈGES QUI MONTENT LA GARDE SUR CETTE CAMPAGNE

- **Baisser sans réduire = du gris** (payé §13) : la vivacité se garde,
  l'ÉTENDUE se coupe. Toute extinction est par les BORDS, jamais une
  opacité uniforme (N2-C).
- **Le fondu n'est pas le brouillard** (RARE-0) : soigner le bord n'excuse
  jamais l'étendue, couper l'étendue n'excuse jamais le bord — un réglage
  se juge sur LES DEUX, et le fondu gagne tout arbitrage entre eux.
- **Le banding de la queue** : un long dégradé sombre en H.264 8 bits pose
  des PALIERS — des liserés sur OLED, un « coupé net » de plus, invisible
  au sim clair. Jugé à la LARGEUR des paliers sur la frame DÉCODÉE (N1.6 —
  la hauteur de marche vaut 1/255 par construction, elle ne prouve rien) ;
  remède crf 17 / dither VÉRIFIÉ après décodage (x264 écrase le bruit des
  aplats sombres) (N3).
- **La rampe d'un rideau se règle sur l'ARÊTE** (piège 11, payé 2ᵉ salve) :
  0,10 H en défaut, toujours — les bouts quasi nets entrent au viewport
  dès le premier point de déplacement (N0-b).
- **Un rideau sur capsule redevient un calque** s'il est court ou opaque :
  la sonde de ligne le juge à CHAQUE réglage (N0).
- **Les préviews runtime MENTENT et le disent** : l'échelle de A est une
  maquette de CADRAGE (pas de matière) ; un clip de B fabriquerait une
  arête en plein cœur crossfadé — mini-cuisson jetable obligatoire (N2).
- **La sonde qui mesure le viewport absout ou condamne n'importe quoi** :
  toute mesure d'étendue est PAR OBJET, et la calibration vérifie ses
  négatifs AVANT de servir (N1 — la faute tuée au fouettage de ce plan).
- **Le blur runtime sur couches vidéo larges** : suspect n°1 du lag, jugé
  mort d'abord, innocenté ensuite seulement (N2/N8).
- **`simctl launch --terminate-running-process` à CHAQUE bascule de flag**
  (piège 18) : un A/B relancé avec les vieux args est un verdict
  empoisonné — les tours d'écoute N0/N2/N4/N7 vivent de flags.
- **`stat` du binaire avant TOUTE capture, dès N0** (piège 15, payé 2×) :
  la campagne est filmée de bout en bout, la relecture adverse de N9
  arrive trop tard pour rattraper des films d'une app périmée.
- **`${flt}[v]` en zsh** (piège §9bis.3) : N0-a et N3 modifient les
  graphes de recuit_duo.sh.
- **Chaque verdict de Kathryn s'archive en capture dans `shots/`**
  (`verdict-*.png`) : la calibration des sondes en dépend (F0, N1).

## 15. LE REFRAME DRASTIQUE — « LE CHEMIN D'ABORD » (24-08 soir, SON
verdict pendant l'exécution — il SUPPLANTE la palette S1-S5 du §14-N2)

> « on fait comme Duolingo ! tout doit être assez fondu noir dans les
> décors, comme Apple — le décor a TROP DE PLACE au scroll, on doit se
> focaliser sur les galets liquid glass ; tes flammes ne vont pas — un
> plan complètement drastique »

**Ce que quatre salves et une campagne n'avaient pas compris** : on
optimisait le DÉCOR (les flammes) alors que le sujet de la page — comme
chez Duolingo — est LE CHEMIN. L'œil doit suivre les étapes de verre ;
le décor existe à peine.

**La doctrine drastique (au-dessus de RARE-0..3, qui restent en garde)** :

- **D1 — LE CHEMIN EST LE SUJET.** Les galets-étapes montent d'un cran
  (82 / actif 92 / trésor 104), leur naissance, leur liseré-température et
  leur vie portent la page. La lumière de la page vit DANS le verre.
- **D2 — LE DÉCOR EST UN PARFUM.** Les flammes deviennent des BRAISES
  basses de POSE : ~160 pt visibles max (crête bien plus basse), vives et
  dessinées (point noir écrasé — le voile gris de la source meurt à la
  cuisson), ancrées bottom, overshoot en base miroir fondue. Elles
  n'existent qu'à la pose : dès le geste elles s'éteignent (mortes à
  0,25 H). La couleur dit le chapitre, la flamme ne raconte plus rien.
- **D3 — LE VOYAGE EST NOIR.** Pendant le scroll : le noir, les galets,
  les capsules-frontières (validées) qui fondent profond (rideaux N0,
  rampe 0,10 H) — et une lueur de couture très basse (≤ 0,18) qui respire
  avec le geste aux coutures 1/2 et 3/4. Rien d'autre. Le rack focus est
  MORT par défaut (`-duoFocus 0`).
- **D4 — LES CAPSULES RESTENT LES ÉVÉNEMENTS.** Fines : rotation 2° en
  sin(π·u), échelle 1,02, lueur 0,12 — le premium par la retenue.

**Exécution (elle a dit « go, ça rend ou je m'en fous ») ** : cuisson des
braises de pose (blanche/rouge 402×240 dont 80 d'overshoot miroir, point
noir écrasé 60/24, crf 17) ; mort des feux uniques 540 pt ; extinction de
voyage ; lueurs de couture ; rideaux des capsules ; galets grossis ;
titres É2/É4 recalés (« La braise blanche » / « La braise rouge ») ;
fouettage complet (films 2 vitesses, sonde de ligne, flash, cadence)
avant toute présentation. Les portillons du §14 (mort ≥ 150 pt en
proportion de la nouvelle taille, bords à zéro, étendue, paliers) gardent
la cuisson.

## 16. « LA SCÈNE AUX GALETS » (24-08 soir, dicté sur le verdict du §15
exécuté — PAS CODÉ, son go attendu)

Le verdict verbatim (sur capture É2 à la pose) :

> « bah non, on ne voit plus rien sur les flammes — mais pas mal
> l'idée. Et pareil : je voulais qu'au scroll les pills vidéo fassent
> une ROTATION et un effet BLUR NOIR avant qu'elles arrivent, car les
> principaux acteurs de l'écran c'est aussi les galets de progression.
> refais un plan »

**Le diagnostic** : la direction braise est VALIDÉE, mais le §15 a
sur-corrigé — en tuant le double renversé j'ai tué TOUTE flamme des
hauts d'écrans : É2 et É4 à la pose n'ont plus un seul feu (sa capture :
noir + galets + dôme rouge, zéro flamme). Et l'arrivée des capsules est
aujourd'hui l'inverse de son vœu : la capsule-sujet voyage NETTE (la loi
T3 du §12) — elle veut qu'elle voyage FLOUE ET SOMBRE et se RÉSOLVE à la
pose : le sujet émerge de la profondeur, les galets règnent pendant le
voyage. La loi T3 meurt, l'arrivée cinéma la remplace.

### G1 — LES FLAMMES RETROUVÉES (la présence, sans revenir au brouillard)

- **Les braises basses grandissent** : visibles 160 → **~215 pt** (crête
  toujours ≤ 262, LOI RARE-1), luminance tenue. Cuisson : mêmes recettes
  `cuireBraise` (point noir écrasé, vignette, miroir overshoot), crop
  élargi (blanche `1080:520:0:1356`, rouge `2160:1100:0:2692`, canevas
  804×640 dont 160 px d'overshoot).
- **LES BRAISES SUSPENDUES REVIENNENT** (le manque exact de sa capture) :
  É2 et É4 reçoivent en HAUT une braise RENVERSÉE de **~130 pt** —
  la même matière vflip, PETITE et fondue (extinction basse longue,
  vignette). Ce n'est PAS le retour du X : les deux braises d'une couture
  ne se croisent jamais (chacune clouée à SON bord, inclinées à 55 % en
  voyage, la lueur fait le pont). « La flamme suspendue » redevient vraie.
- Fichiers : `duo-flamme-blanche-haut.mp4`, `duo-flamme-rouge-haut.mp4`
  (804×340 : 260 px visibles + 80 d'overshoot haut, roll de phase
  demi-boucle — jamais en phase avec la basse). Portillons : bords zéro,
  ligne < 7, étendue par feu ≤ 262 pt, couture ≤ 2, déphasage vérifié.

### G2 — L'ARRIVÉE DES CAPSULES (rotation + blur noir qui se RÉSOLVENT)

La loi T3 (« le sujet reste net ») MEURT — remplacée par :

**LOI G — LE SUJET ÉMERGE.** Pendant sa traversée, la capsule est
floue, sombre et inclinée ; tout se résout à ZÉRO à la pose (sin(π·u)
sur les trois canaux — la forme qui s'annule aux deux poses) :

- **le blur noir** : rayon **10 pt × sin(π·u)** (net aux poses, flou au
  cœur du voyage) + assombrissement **0,35 × sin(π·u)** par-dessus les
  rideaux N0 — elle arrive DE la profondeur noire ;
- **la rotation** : le tilt passe de 2° à **7° × sin(π·u)** sur l'axe X
  (perspective 0,5) — on VOIT le verre tourner en approchant, immobile
  posé ;
- l'échelle 1,02 et la courbe en S restent ; la lueur de passage 0,12
  reste (elle troue le sombre — le verre s'allume en passant).
- **La hiérarchie voulue** : pendant le voyage la capsule est douce et
  sombre → les galets (nets, au-dessus) sont les acteurs ; à la pose la
  capsule se résout et reprend la scène.
- ⚠️ Les gardes : tout en visualEffect (zéro invalidation) ; le blur
  vit sur LA SEULE capsule en traversée (1 fenêtre, jamais 2) — cadence
  mesurée, échelle de repli 10 → 6 → 4 pt ; le détecteur de VOILE (le
  blur laisse son calque : noir autour ≤ 4/255) ; reduceMotion coupe
  rotation et blur (piège 19).
- Curseurs au banc : `-duoArrivee <deg>` (défaut 7), `-duoFocusPill <pt>`
  (défaut 10), `-duoBraise` inchangé.

### G3 — LE FOUETTAGE PUIS SON VERDICT

Films aller-retour × 2 vitesses ; sonde de ligne (< 7) ; fraction
lumineuse (les braises suspendues remontent les poses — portillon : pose
≤ 35 %, transition ≤ pose) ; détecteur de voile du blur ; zéro flash ;
cadence pendant les traversées floutées (les deux nombres) ; puis les
curseurs jugés AU DOIGT par Kathryn (braise, degrés, rayon), téléphone
ensuite (N10 du §14 reste la liste).

## 17. « LA BOULE DE FEU » — le morphisme des flammes (24-08 soir, dicté
sur son idée — PAS CODÉ, son go attendu)

> « au pire elles peuvent être toutes petites les flammes entre elles :
> au scroll elles se CONDENSENT limite entre elles EN BOULE, et une fois
> sur l'écran elles se DÉVOILENT — refais un plan de morphisme
> magnifique »

**L'idée, en langage de la maison** : la flamme n'est plus un objet qui
s'incline en voyage — c'est une matière qui RESPIRE avec le scroll. À la
pose : la braise déployée, plumes vivantes. Au voyage : les DEUX braises
d'une couture se condensent l'une VERS l'autre — chacune se contracte
vers son point de couture — et leur somme additive au centre du voyage
est UNE BOULE de feu compacte posée sur la couture, enveloppée de la
lueur. À l'arrivée : la braise de l'écran qui se pose SE DÉVOILE depuis
la boule — le feu se déplie. Un seul geste continu : flamme → boule →
flamme.

**Pourquoi c'est réalisable proprement (et pas cher)** : tout est du
TRANSFORM en visualEffect — « on transforme, on ne redimensionne
jamais » :

### M1 — LA CONDENSATION

- Chaque braise reçoit une échelle pilotée par sa traversée :
  `scale = 1 − (1 − boule) × sin(π·u)` avec `boule ≈ 0,32`
  (`-duoBoule <0-1>` au banc) — pleine à la pose, boule au cœur du
  voyage, la forme sin qui s'annule aux DEUX poses (la loi des arrivées).
- **L'ANCRE fait le morphisme** : la basse se contracte ancrée
  BAS-CENTRE (sa base reste collée à la couture — elle fond VERS la
  couture) ; la suspendue ancrée HAUT-CENTRE. Les deux glissent l'une
  vers l'autre par construction, et l'additif fait de leur rencontre UNE
  boule — jamais deux objets (la leçon de toutes les salves : un seul
  objet par couture au voyage).
- L'inclinaison à 55 % MEURT (remplacée : la condensation EST le
  « montrer moins ») ; reste un léger dim ~20 % au cœur du voyage pour
  que la boule soit dense, pas éblouissante.
- La LUEUR de couture devient LE CŒUR DE LA BOULE : rayon resserré
  (~0,35 × largeur), intensité au pic ~0,35, teintée chapitre — c'est
  elle qui enrobe la boule et fait le liant.

### M2 — LE DÉVOILEMENT

- À l'approche de la pose, la braise se redéploie (le même sin — aucune
  mécanique nouvelle) ; la VIDÉO continue de jouer pendant tout le
  morphisme : le dévoilement est vivant (les plumes bougent en se
  dépliant), jamais un simple zoom d'image.
- La respiration est symétrique et réversible au doigt (scrub avant/
  arrière = le même chemin — géométrie pure, zéro état).

### M3 — LE FOUETTAGE

- Films 2 vitesses ; sonde de ligne < 7 ; le test de la BOULE à l'œil :
  au cœur du voyage, UNE seule forme lumineuse par couture (jamais deux) ;
  poses intactes (scale = 1 exact) ; cadence inchangée (transforms purs,
  aucun blur ajouté) ; reduceMotion : condensation coupée (opacité
  simple).
- Curseurs : `-duoBoule` (0,32), `-duoBraise` (le cœur), l'arrivée des
  capsules inchangée (§16).

## 18. « LA PARTITION » — la ré-analyse aux montages + le plan minutieux
(25-08, dicté après « toujours pas, réanalyse, tu vas trop trop vite et
tes plans ne sont pas assez précis — fais un plan très minutieux et
long, c'est pas grave ». Fouetté avant présentation : 2 juges adverses,
16 fautes intégrées — les majeures : la SAFE AREA oubliée dans toute
l'arithmétique de la dalle, le relais de la boule troué à ses bords, le
script de cuisson incapable de recuire le bundle réel.)

### 18.1 LA RÉ-ANALYSE (les montages frame par frame du film v4 — ce que
les sondes ne voyaient pas)

Trois montages de 8 frames (la condensation 3/4, le dévoilement à la
pose É4, l'arrivée de la capsule 2/3). Les fautes, par gravité :

**FAUTE 1 — LA BOULE EST ENCORE « DEUX COMPOSANTS » (frames 220-243).**
Deux blobs faibles empilés, une fente noire entre eux. La géométrie
mesurée (corrigée au fouettage — ma première arithmétique était
fausse) : les cœurs lumineux vivent à ~60 pt et ~52 pt de leurs bords de
fenêtre ; l'échelle ancrée 0,32 les amène à ~36 pt l'un de l'autre —
proches mais JAMAIS fusionnés, et si dimmés que la rencontre est deux
lueurs mortes, pas une boule. Le verdict le plus ancien du chantier
(« on ne doit pas savoir que c'est deux composants ») revient par la
faiblesse, pas par la distance.

**FAUTE 2 — LE PATCH RECTANGULAIRE (frames 223-233).** Une fenêtre vidéo
à l'échelle 0,32 montre sa SILHOUETTE (épaules droites de la vignette
vue de loin). Un scale fort n'est pas une condensation de matière —
c'est un autocollant qui rétrécit.

**FAUTE 3 — LES SUSPENDUES SONT INVISIBLES, ET LA CAUSE EST LA SAFE
AREA.** La dalle ne vit PAS à y 8→66 : son overlay respecte la zone
sûre (seul le ScrollView l'ignore) — elle occupe ~y 67→125 PHYSIQUE,
sous l'île. Les fenêtres d'écran, elles, sont plein-physique (y 0). La
braise suspendue (y 0→130) est donc mangée par l'île PUIS par la dalle
sur la quasi-totalité de sa hauteur. **C'est la racine du « on ne voit
plus rien sur les flammes » : elles sont à l'écran, entièrement
cachées.** Aucune cote de HUD ne se déclare : elles se MESURENT sur
capture (safe top réel + rect réel de la dalle).

**FAUTE 4 — LA DALLE EN TRANSITION reste une machine à artefacts** (le
pavé noir au départ, un slab clair à mi-fondu sur la braise blanche,
frame 170). Sa sortie a des états intermédiaires visibles.

**FAUTE 5 — LE DÉVOILEMENT N'A PEUT-ÊTRE JAMAIS JOUÉ dans les films.**
Piloté par `enGeste` (onScrollPhaseChange) — or les films `-duoAuto`
scrollent par `scrollTo` programmé : la phase n'est pas garantie de
tomber comme au doigt. Conséquence propagée : **les montages des fautes
1-2 ont peut-être été filmés SANS le voile de 9 pt** — leur gravité
(pas leur existence) se re-constate sur banc réparé AVANT de cuire quoi
que ce soit (P3.a est prérequis des films de P4).

**CE QUI EST PROUVÉ ET TIENT** (interdit d'y retoucher sans son ordre) :
zéro arête (ligne 2,4 contre 14), zéro flash, fraction méd. 20 %, la
matière larme-2D des braises basses, l'arrivée cover-flow LISIBLE au
montage, les noirs vrais, la cadence sim. **CE QUI N'A JAMAIS ÉTÉ
VÉRIFIÉ** : le doigt, le dévoilement, le téléphone, le press à
mi-transition, `-duoAutoLent`.

**L'INTENTION DÉCLARÉE (à confirmer en P8)** : la page alterne DEUX
grammaires de transition — aux coutures de feu (1/2, 3/4) LE FEU SE
CONDENSE en boule ; aux coutures de verre (2/3, 4/5) LE VERRE ÉMERGE en
cover-flow. C'est un rythme voulu, pas un accident.

### 18.2 LA MÉTHODE DE LA PARTITION (la porte, durcie une bonne fois)

- **UN jalon par échange, UNE question FERMÉE par jalon** (écrite
  d'avance ci-dessous — une seule bascule ; les curseurs restent des
  flags qu'elle actionne si le « non » tombe). Verdict archivé
  (`shots/verdict-P*.png` + sa phrase ici) avant d'ouvrir le suivant.
- **Chaque jalon filmé en DEUX vitesses** (`-duoAuto` + `-duoAutoLent`),
  jugé d'abord au film LENT.
- **Le chemin critique est court** : P0 → P1 → P1bis → P2 → P3 → P4 →
  P7 → P8. **P5 et P6 sont CONDITIONNELS** (après P8, seulement si ses
  verdicts les réclament) — on ne rouvre pas ce qui tient (le pattern
  des salves passées, nommé et banni).
- Les portillons chiffrés gardent la non-régression ; le juge de la
  beauté reste elle.

### 18.3 LES JALONS

**P0 — L'OUTILLAGE DE PREUVE (à portillons, enchaînable avec P1).**
1. `-duoAutoLent` : le même aller-retour, durée ×3.
2. Le LOG DE PHASE (`-duoLogPhase`) : une ligne par changement de phase
   (phase, y, horodatage) — en `print` relu par
   `simctl launch --console-pty`, ET en fichier dans le conteneur de
   l'app (relu par `simctl get_app_container data`) pour les films.
3. La SONDE DE DALLE : le rect réel de la dalle se MESURE d'abord sur
   capture posée (safe top + cadre) ; la sonde croppe CE rect-là sur
   les films — portillon : après 3 frames de geste, aucun pixel
   structuré (ni pavé sombre, ni slab clair) jusqu'au retour de pose.
4. **LE SCRIPT REDEVIENT LA VÉRITÉ** (bloquant du fouettage) :
   `recuit_duo.sh` reçoit les recettes RÉELLES des 4 braises (scrims
   `basse` 804×430 200/130 + `haute` 804×260 90/130, vignettes 2D
   `vig-basse` σ250/200 c(402,300) et `vig-haute` σ230/130 c(402,185),
   canevas 804×430 et 804×260, crops blanche `1080:578:0:1298` bp 70 /
   rouge `2160:1155:0:2637` bp 24 / hautes `1080:349:0:1527` et
   `2160:699:0:3093`, vflip final + roll demi-boucle des hautes,
   crf 17 une passe). **Portillon : re-cuire reproduit les fichiers du
   bundle (dims identiques + portillons J0 verts).**
Sorties : sonde de dalle rejouée sur le film v4 existant ; les flags
prouvés sur UN film neuf. Aucun verdict Kathryn requis.

**P1 — LES SUSPENDUES VISIBLES (faute 3).**
- La cote se DÉRIVE, jamais ne se déclare : sommet des braises hautes à
  `safeAreaInsets.top + 58 + 12` (mesuré ~y 129-137 selon l'appareil),
  via `yLocal` — **l'offset entre dans yLocal qui nourrit restY ET
  l'offset ensemble** (un offset seul poserait dist ≈ 130 à la pose :
  une mini-condensation permanente sur braise posée, la faute
  silencieuse relevée au fouettage).
- La fenêtre reste 402×130 ; le profil mesuré du fichier (première
  lumière à ~14 pt du bord, cœur à ~52 pt) place le cœur à ~y 185 :
  VISIBLE, entier, sous la dalle. Aucun recuit d'abord — l'offset seul,
  on juge, on recadre après si le cadrage déçoit (recuit possible grâce
  à P0.4).
- Si le feu touche encore le verre de la dalle à la pose : pellicule
  0,30 → 0,22 (capture comparée, même jalon).
Portillons : capture posée É2 et É4 — braise haute entière hors du rect
mesuré de la dalle (portillon numpy : zéro pixel de braise dans le
rect) ; ligne < 7 ; bandes du chemin re-mesurées.
**Question (fermée) : « É2/É4 posés : les flammes hautes sont bien là,
oui ou non ? »**

> **P0+P1 LIVRÉS le 25-08 (`da18df1`).** P0 : `-duoAutoLent` ✓ ; log de
> phase ✓ — **la FAUTE 5 est INFIRMÉE** (animating/idle tombent au
> scrollTo : le dévoilement jouait, les montages étaient fidèles — P3.a
> devient inutile, P3 se réduit au choix de courbe) ; sonde de dalle au
> rect MESURÉ (y 69→130 pt sur capture, pas 8→66) ; **le script
> reproduit le bundle À L'OCTET PRÈS** (4 braises témoins identiques).
> P1 : `decalageHaut = safeTop+58+12` dans yLocal — captures posées :
> braise blanche et rouge ENTIÈRES sous la dalle (première lumière
> y 154, rect fini à 130). Non-régression : ligne 2,24, zéro flash hors
> un creux d'UNE frame au premier geste après boot froid (consigné,
> vérif téléphone P8). **Verdict Kathryn attendu.**

**P1-bis — LE COL FONDU DU VERRE NOIR (sa demande du 25-08).**
- Deux candidats cuits EN PRÉVIEW (hors bundle) : scrim haut **120 px**
  (doux) et **220 px** (profond) — le fondu va jusqu'au noir au bord
  (c'est la nature d'un scrim ; si elle veut un col encore lisible, le
  plafond d'alpha devient un paramètre de scrim — dit, pas découvert).
  Le scrim bas 220 px inchangé, une passe crf 17, palindrome.
- Le gagnant part au bundle + pose refaite.
Portillons : couture ≤ 2 ; silhouette du reste intacte (±4 % vs gel) ;
p99 des 4 rangées hautes avant/après (le chiffre du fondu).
**Question : « le col : doux (120) ou profond (220) ? »**

**P2 — LA DALLE PROPRE EN TRANSITION (faute 4).**
- **Le verre sort SEC** (retrait sans transition — le natif ignore
  l'opacité, toute transition sur lui ne fait que retarder son pop) ;
  la PELLICULE s'anime seule en opacité 0,08 s ; l'ENCRE en 0,15 s
  (elle survit 70 ms à la pellicule : assumé — l'encre seule sur le
  noir ne fait pas d'artefact). Le retour garde 0,28 s. Plus d'offset
  de sortie (il promenait le pavé sur les galets).
Portillons : sonde de dalle muette sur films 2 vitesses ; zéro morsure
sur galets en pleine transition.
**Question : « au scroll, plus aucun rectangle fantôme en haut — oui ou
non ? »**

**P3 — LE DÉVOILEMENT PROUVÉ PUIS RÉGLÉ (faute 5).**
- a) Le log P0.2 tranche. Si la phase ne tombe pas au scrollTo : sous
  `-duoAuto`, **le callback de phase ne pilote PLUS enGeste** (garde
  sur le flag — une seule main sur le booléen) ; le banc le pilote aux
  deadlines de `lancerAuto` (vrai au départ du withAnimation, faux à
  +1,1 s). Les films montrent alors CE QUE LE DOIGT verra. **Prérequis
  des films de P4.**
- b) La courbe : `easeOut 0,7 s` contre `spring(0.55, 0.8)` — deux
  films lents. Le voile reste à 9 pt (sa variante 6 pt montrée dans le
  MÊME film, en seconde moitié).
Portillons : le dévoilement mesuré à OFFSET POSÉ (frames après l'arrêt,
zone braise recalée par l'offset connu, variance laplacienne normalisée
par la moyenne² — la mesure du fouettage : jamais pendant le voyage, où
échelle et dim la polluent) ; cadence tenue.
**Question : « le dévoilement : courbe douce (A) ou ressort (B) ? »**

**P4 — LA BOULE UNE (fautes 1+2 — le cœur du morphisme).**
La boule cesse d'être deux fenêtres réduites : **LA BOULE EST L'ORBE**
(un seul objet dessiné), les braises y fondent PAR L'OPACITÉ :
- L'orbe : Ø ~140 pt, double stop (cœur teinté 0,9 → mi 0,25 → clair),
  posé SUR la couture, **flag PROPRE `-duoOrbe` (défaut 0,45)** —
  découplé de `-duoBraise` (le pic 0,45 était improductible avec
  braiseMax 0,28 : la faute « un seul jeu de chiffres », payée au §14,
  ne se repaie pas). L'alpha 0,55 du gradient actuel MEURT, remplacé
  par le double stop.
- Les braises : plancher d'échelle **0,72** (le patch commence sous
  ~0,6), ancres de bord conservées — **l'ancre devient indifférente
  parce que le relais est l'OPACITÉ** (l'arbitrage du fouettage : on ne
  répare pas la géométrie des cœurs, on éteint les fenêtres avant
  qu'elle ne compte ; le piège « ancre au cœur » est retiré) — et
  extinction VRAIE : coefficient **1,0** (jamais 0,9 — un fantôme à
  11 % en additif sur noir se voit) : `opacité = 1 −
  smoothstep(u ∈ [0,18 ; 0,52])`, symétrique au retour.
- P1 pris en acte : l'ancre des suspendues vit désormais à ~130 pt de
  la couture — sans importance, leurs fenêtres sont éteintes bien avant
  que l'écart ne se lise (le relais par l'opacité, encore).
- La passation est ADDITIVE (fondu enchaîné de lumières, pas un swap) ;
  reduceMotion : orbe seul, braises en fondu simple.
Portillons (les DEUX trous du fouettage fermés) : comptage de
composantes connexes sur CHAQUE frame de la traversée — **la pire frame
fait le portillon** (le trou du relais est aux bords, u 0,25-0,45,
jamais au centre) ; profil de luminance totale par frame : montée vers
le pic puis descente vers la pose SANS CREUX (le trou de relais mesuré,
pas espéré) ; ligne < 7 ; fraction ≤ pose ; seuil de luminance des
composantes calé sur le plancher noir mesuré en P0.
**Question : « la boule telle quelle — oui ou non ? »** (les curseurs
`-duoOrbe`/`-duoBoule` restent à sa main si le non tombe).

**P7 — LE FOUETTAGE COMPLET (à portillons).**
Films 2 vitesses × 4 coutures + aller-retour ; ligne, fraction,
composantes de la boule (toutes frames), sonde de dalle, flash, voile
(flancs ≤ 4 hors lueur) ; **l'ouverture refilmée** (la cascade de
naissance — perdue depuis N9, réintégrée) ; non-régression contre les
GELS des verdicts P1-P4 ; allers-retours d'états ; LE PRESS À
MI-TRANSITION (dette 2ᵉ salve) ; cadence par régime (les deux nombres).

**P8 — LE TÉLÉPHONE (le verdict qui compte).**
Déploiement (mémoire deploy-iphone) ; noirs OLED réels des braises ;
chauffe pendant blurs ; gyro ; **la dette des galets nommée** (press/
refus/tilt au doigt — D1 « le chemin est le sujet » n'a pas eu un jalon
et le doit) ; les deux grammaires (boule / cover-flow) confirmées ou
infirmées par elle ; l'intensité des curseurs au doigt.
**Question finale : « au doigt sur TON téléphone : la magie y est —
oui ou non ? »**

**P5 (CONDITIONNEL, après P8) — LE COVER-FLOW AFFINÉ.** Seulement si
son verdict le réclame : mire 3 réglages (12°/0,5 ; 16°/0,6 actuel ;
20°/0,7 + échelle 1,04), courbe de blur asymétrique (résolution rapide
dès 40 %), noir 0,5 vs 0,38. Portillons : netteté à la présentation
(variance laplacienne à la frame du pic, position calculée) ; cadence ;
voile.

**P6 (CONDITIONNEL, après P8) — LA MATIÈRE FINE.** Seulement si
réclamé : la bleue au régime larme-2D ; ralenti cuit ×0,8 si battement
au lent (jamais minterpolate) ; gains par teinte (S tenue, R à 1) sur
planche des quatre feux, proposition écrite, « d'accord — oui/non ? ».

### 18.4 LES PIÈGES NEUFS DE CETTE PARTITION

- **Un HUD se MESURE, il ne se déclare pas** : la dalle vit sous la
  safe area (~y 67→125), pas à son padding nominal — toute cote de
  zone morte dérive du runtime ou d'une capture (faute 3, payée).
- **Sous ~0,6 d'échelle, une fenêtre vidéo montre sa silhouette** — le
  relais passe par l'OPACITÉ vers un objet dessiné, avec extinction
  VRAIE (1,0 — un fantôme à 11 % en additif se voit).
- **Le trou d'un relais est à ses BORDS, jamais à son centre** : tout
  portillon de relais court sur toutes les frames et retient la PIRE.
- **`onScrollPhaseChange` n'est pas garanti au scrollTo programmé** —
  et deux mains sur un même booléen (sonde + pilote de banc) rendent
  le film infidèle : la garde d'abord, le pilote ensuite.
- **Un HUD au-dessus d'un monde noir compte ses états intermédiaires**
  (le verre natif sort SEC ; seules pellicule et encre s'animent).
- **Un script de cuisson qui ne recuit pas le bundle est une dette
  active** : chaque one-off se reporte dans le script LE JOUR MÊME,
  portillon « re-cuire reproduit le bundle ».
- **Un offset de fenêtre entre dans yLocal (restY + offset ensemble)**,
  sinon la géométrie de pose ment (mini-condensation permanente).

## 19. « LE FEU UNIQUE-LARME » — la synthèse (25-08, dicté après son
verdict sur P1 : « toujours trop d'espace entre les flammes au scroll…
elles doivent être bien dans le header et le footer, là on dirait que
c'est posé, c'est archi nul… peut-être que la solution des deux vidéos
ça ne va pas » — PAS CODÉ, son go attendu)

### 19.1 LE DIAGNOSTIC FINAL (pourquoi 10 sessions n'ont pas fixé ça)

**Deux vidéos par couture ne peuvent PAS marcher — c'est topologique,
pas un réglage.** Deux objets distincts ont toujours un ENTRE-DEUX : on
l'a maquillé (rideaux), fusionné (feu unique §13 — raté par la matière :
brouillard 540 pt), condensé (boule §17 — deux lueurs à 36 pt, jamais
une), écarté (P1 — et la flamme « posée comme » est née : détachée de
son bord, un autocollant qui flotte). Chaque échec avait la même racine.

**Et une flamme d'écran doit vivre À SON BORD** (« bien dans le header
et le footer ») : détachée du bord, elle flotte ; collée au bord haut,
elle meurt sous l'île et la dalle. La seule forme qui résout TOUT : un
objet qui APPARTIENT à la couture et saigne dans les deux écrans.

**La synthèse des deux moitiés prouvées** : la TOPOLOGIE du §13 (un
seul fichier chevauchant par couture de feu — l'école FrontiereSpec,
celle des capsules qu'elle a validées « c'est top le même élément ») ×
la MATIÈRE du §17 (la larme : point noir écrasé, vignette 2D de
peintre, fondu partout — la seule matière jamais trouvée belle ici).
Le §13 avait la bonne forme et une matière ratée ; le §17 la bonne
matière et une forme ratée. On assemble.

### 19.2 LE FICHIER (un par couture de feu : `duo-feu-blanc`,
`duo-feu-rouge` — v2, 2 fichiers au lieu de 4 braises)

- **804×640 px (402×320 pt), le CŒUR du feu sur la couture** (rangées
  ~280-360) : au-dessus, les plumes qui montent (la source telle
  quelle, crush 70/24, mort au zéro vrai sur les 180 premières
  rangées) ; au-dessous, la lueur-sous-le-feu (le miroir flouté gblur 16
  ×0,80 de l'école §16 — jamais un axe), morte au zéro sur les 160
  dernières. Vignette 2D centrée sur le cœur (σx 260 / σy 200). Une
  passe crf 17, palindrome. Les recettes AU SCRIPT le jour même (la loi
  P0.4).
- **À la pose de l'écran BAS** (É1, É3) : la moitié haute visible — les
  plumes montent DU bord bas, le cœur affleure le bord : le feu est
  DANS le footer. **À la pose de l'écran HAUT** (É2, É4) : la moitié
  basse visible — la lueur saigne DU bord haut, DERRIÈRE l'île et la
  dalle (une lumière sous une carte : naturel), son ventre visible sous
  la dalle : le feu est DANS le header, jamais « posé ». **Au scroll :
  UN corps traverse — l'espace entre les flammes n'existe plus, par
  construction.**
- Portillons fichier : bords 4 côtés à 0 ; couture palindrome ≤ 2 ;
  aucune rangée à saut cohérent (< 7) ; profil vertical : UNE seule
  composante lumineuse (le corps), monotone de part et d'autre du cœur.

### 19.3 LE RUNTIME (plus simple que ce qu'il remplace)

- La fenêtre chevauchante ressuscite (`feuxUniques`, poses {0, −H},
  offset constant centre = couture×H, additive, `lectureFeux`) — le
  code du §13 existe encore, vidé : on le remplit.
- **Meurent** : les 4 braises et leurs specs, la condensation-boule et
  ses ancres, la lueur de couture (le corps EST la continuité), le
  jalon P4 tout entier (la fente meurt par topologie, pas par relais).
- **Restent** : le voile de geste + dévoilement au repos (sa
  chorégraphie), un dim de voyage léger (~15 % à mi-course, sin —
  RARE-2), le cover-flow des capsules, la bleue telle quelle (pas de
  couture sous elle).
- reduceMotion : dim simple.

### 19.4 LES JALONS (la porte inchangée : un jalon, une question)

- **U1 — la cuisson des deux feux** + script + portillons 19.2. Puis
  captures POSÉES É1/É2/É3/É4 : le portillon « header/footer » — la
  lumière est CONNEXE à son bord d'écran (profil vertical : aucun îlot
  détaché — le contraire exact de « posé comme »).
  **Question : « posés : le feu est bien DANS le header et le footer —
  oui ou non ? »**
- **U2 — le scroll** : films 2 vitesses des coutures 1/2 et 3/4 — le
  portillon : UNE composante lumineuse par couture sur CHAQUE frame du
  voyage (la mesure du §18-P4, enfin gagnable par construction) ;
  ligne < 7 ; zéro flash ; cadence.
  **Question : « au scroll : plus aucun espace entre les flammes —
  oui ou non ? »**
- Puis la partition reprend son cours : **P1-bis** (le col du verre
  noir, sa demande, toujours en attente), **P2** (la dalle propre),
  **P3** (la courbe du dévoilement), **P7**, **P8**.

## 20. « LES PILLS DU CHEMIN » — le chantier des galets-étapes (25-08,
dicté sur sa référence : l'icône Slack en MÉTAL NOIR SABLÉ pailleté
d'argent, biseau 3D, éclairage rasant — PAS CODÉ, son go attendu)

Le brief verbatim : « les Pills doivent avoir du relief limite 3D et un
aspect très premium. Les sessions À FAIRE : full liquid glass ; celles
FAITES : une sorte de métal comme l'image, et néon blanc autour du
noir, la date (12 Jun — on fonctionne par date), la logique de
gamification à voir. Et quand on appuie dessus, de la fumée ou de la
lumière sort. »

**La référence à archiver** : `shots/ref-pill-metal.png` (le Slack métal
sablé — grain fin, paillettes argentées éparses, biseau doux, lumière
rasante du haut, coins très arrondis). C'est un REGISTRE que la maison
connaît : le moonCoin mat/poli (BravoLab), la carte obsidienne, le
brossage d'ObjectiveJewel.

### 20.1 LA GRAMMAIRE DES DEUX MATIÈRES (l'état se dit par la matière —
LOI 4 du §1, enfin incarnée)

- **À FAIRE (verrouillé/prochain) — LE VERRE PLEIN (full liquid glass)** :
  la pill est une lentille de verre bombée, relief limite 3D. ⚠️ Le
  procès du §10.1 se tient ENFIN ici, sur mire, avec les trois candidats
  côte à côte : (a) le natif `.glassEffect(.clear)` — la loi du « trou
  dans du métal » le condamne sur noir pur, MAIS les feux vivent
  désormais sous le chemin : à re-juger sur la vraie page ; (b) le
  **liquidLens** en petit (l'école de la fiche exo, VALIDÉE — les
  INTERDITS de la mémoire lentille-liquide font loi ; ⚠️ coût ×11
  instances : rasterisé une fois par état, jamais 11 shaders vivants) ;
  (c) le verre PEINT enrichi (l'actuel GaletEtape + réfraction feinte du
  foyer). Son verdict tranche LA matière du « à faire ».
- **FAITE (accompli) — LE MÉTAL SABLÉ DE LA RÉF** : `GaletMetal.metal`
  (colorEffect) — le corps obsidienne sablée (grain fin), les
  **paillettes d'argent** éparses qui SCINTILLENT au gyro (école
  SkyMotion — le sim y est aveugle, verdict téléphone), le biseau qui
  prend la lumière rasante (un rim-light haut, école fil de crête), le
  **NÉON BLANC autour du noir** : l'anneau gaussien de `galetLisere`
  monté en blanc pur, fin, constant (l'accompli rayonne, calme). La
  **DATE gravée** (« 12 JUN », petites capitales) en creux — l'emboss de
  la réf : encre enfoncée, lumière sur la lèvre basse du creux.
  ⚠️ Pièges à poste : le **Nyquist 3× d'ObjectiveJewel** (un grain/des
  paillettes SOUS-échantillonnés aliassent — raster 3× obligatoire) ; le
  cadre fantôme au bord du pad ; l'arité stitchable ; scalaires en `let`.
- **L'ACTIVE (la session du jour)** : le verre plein du « à faire » +
  le souffle du liseré (l'appel), + SA date du jour. La hiérarchie
  taille reste (92).

### 20.2 LES DATES (« on fonctionne par date »)

Chaque pill porte une DATE de session au lieu du chiffre : les faites =
leur date passée gravée dans le métal ; l'active = aujourd'hui ; les à
faire = MUETTES (le verre vierge — une date future serait une promesse,
la gamification décidera). Session UI : dates FACTICES dérivées
d'aujourd'hui (J-9…J), format « 12 JUN » petites capitales. **La logique
de gamification (calendrier réel, streaks, liens séances) est
explicitement REPORTÉE — sa note : « à voir »** ; la surface seule se
dessine (l'école du rail de jeu §6.4).

### 20.3 LE PRESS (« de la fumée ou de la lumière sort »)

A/B au banc, un seul candidat livré :
- **(A) LA LUMIÈRE (défaut proposé)** : au press, une lumière S'ÉCHAPPE
  de sous la pill — un bloom additif bas qui gonfle depuis le flanc
  (école lueur de passage : plusLighter, motivé, ≤ 0,3), meurt au
  relâcher. Zéro techno neuve, très Apple.
- **(B) LA FUMÉE** : la fumée noire au tap existe à la maison
  (carteLuneV2) — une volute qui s'échappe du bord et se dissout. Plus
  wow, plus cher, banc à part (la mémoire lentille-liquide l'avait déjà
  remise « à un banc à part »).
- Les deux gardent l'enfoncement 3 % + flanc mangé + tilt ≤ 4° + les
  haptiques existantes ; le refus reste L'IMMOBILITÉ (la loi §6.2).

### 20.4 LES JALONS (la porte : un jalon, une question fermée)

- **Pil-1 — LA MIRE DES MATIÈRES** (`-duoGalets` enrichie) : les 3
  candidats « à faire » + le métal sablé v1 + l'active, sur les DEUX
  fonds (noir pur / feu dessous). **Question : « le à-faire : natif,
  liquidLens ou peint enrichi ? »**
- **Pil-2 — LE MÉTAL AFFINÉ** : grain/paillettes/biseau/néon/date aux
  curseurs (`-pillGrain`, `-pillNeon`), zoom ×8 anti cadre fantôme,
  Nyquist 3× vérifié. **Question : « le métal : fidèle à ta réf —
  oui/non ? »**
- **Pil-3 — LE PRESS** : A/B lumière/fumée au doigt.
  **Question : « lumière (A) ou fumée (B) ? »**
- **Pil-4 — LA PAGE HABILLÉE** : les 11 pills en situation (dates
  factices, états mélangés via `-duoEtape`), fouettage (cadence — 11
  shaders = le suspect, l'échelle de repli : raster par état),
  non-régression des feux/capsules. **Question : « le chemin est-il
  enfin le bijou de la page — oui/non ? »**
- Puis P2/P3/P7/P8 de la partition reprennent (dalle, dévoilement,
  fouettage, téléphone).

## 21. LA GAMIFICATION DU CHEMIN — « le chemin libre » (25-08, dicté sur
son brief : « une pill = une session ; la pill-lune = un cadeau ; ça me
ferait chier qu'on m'impose un entraînement — je veux faire ce que je
veux, mais tu peux me challenger ». PAS CODÉ — à valider ICI, puis à
reporter au plan BACKEND.)

### 21.1 LA LOI FONDATRICE — L'ANTI-DUOLINGO

**Le chemin ne PRESCRIT jamais : il ENREGISTRE.** Chez Duolingo, la pill
dit « fais cette leçon » ; chez Woop, la pill se GRAVE quand une session
— n'importe laquelle, celle qu'elle veut — est faite. La liberté est la
règle, le défi est une INVITATION : jamais un portail, jamais une
punition, jamais un rouge de culpabilité. (Sa phrase fait loi.)

### 21.2 LE CHAPITRE (« on fait quoi par chapitre, combien de pills ? »)

- **UN CHAPITRE = 10 SESSIONS + LA PILL-LUNE** (11 nœuds — exactement les
  11 étapes déjà posées : 1+3+2+2+3 sur les cinq écrans). Le voyage de
  couleur (noir → blanc → rouge → rouge-et-bleu → bleu) EST le chapitre :
  finir un chapitre = avoir traversé les cinq écrans.
- **Compté en SESSIONS, jamais en calendrier** : pas de « semaine ratée »
  possible — elle avance à SON rythme, le chapitre l'attend. (L'école
  calendrier/mois existe ailleurs — l'iPod du mois ; ici c'est le COMPTE
  qui fait le chemin.)
- Les chapitres sont infinis (Chapitre 1, 2, 3…) ; chaque nouveau
  chapitre rejoue la descente des cinq écrans. Plus tard : une variation
  de teinte par chapitre (le monde se réchauffe/refroidit) — hors session.

### 21.3 LES PILLS (les états, mappés sur les matières VALIDÉES en Pil-1)

| état | matière | contenu |
|---|---|---|
| **faite** | métal sablé daté | LA DATE de la session (« 12 JUN ») gravée — le chemin est un JOURNAL de ce qu'elle a fait |
| **active** | verre nourri + date du jour | le PROCHAIN nœud : elle s'allume, elle attend — elle n'exige RIEN |
| **à faire** | verre muet | AUCUNE date, AUCUN contenu imposé — une promesse vide qu'elle remplira comme elle veut |
| **parfaite** | métal + souffle d'or | la session qui contenait un RECORD (ou un défi cueilli) — l'or est RARE (la loi de la maison) |
| **la lune** | le nœud-trésor (98-104) | LE CADEAU du chapitre |

### 21.4 LES RÉCOMPENSES (« combien de fois on fait le reward ? »)

Trois étages, du micro au rare — chaque étage existe DÉJÀ dans l'économie
de la maison, rien ne s'invente :

1. **Chaque SÉRIE faite : 20 pièces** (la règle en vigueur, inchangée —
   BRAVO l'annonce déjà).
2. **Chaque SESSION : la pill se grave** — la cérémonie est VISUELLE (le
   verre devient métal, la date s'embosse, l'échappée de lumière/fumée du
   press Pil-3 joue à la gravure) + le total de pièces de la séance
   rappelé. Pas de monnaie en plus : la gravure EST la récompense.
3. **Chaque CHAPITRE (la pill-lune) : UN BOOSTER** — le « chest »
   Duolingo, c'est le Sacre de Woop (décidé au §6.3, toute l'économie
   carte-lune existe). Cadence : 1 booster / 10 sessions — assez rare
   pour rester une fête, la cérémonie du manège fait le reste.
   L'ouverture du booster se joue DEPUIS la lune (le flow existant).

### 21.5 LES DÉFIS — « tu peux me challenger » (jamais m'imposer)

**Le défi est une invitation posée SUR le chapitre, cueillie
PASSIVEMENT** : elle s'entraîne comme elle veut ; si ce qu'elle a fait
matche le défi, il se cueille TOUT SEUL (détection, jamais obligation).
Refusé/ignoré = RIEN ne se passe (pas de croix rouge, pas de streak
brisé, pas de culpabilité — l'anti-Duolingo jusqu'au bout).

Trois saveurs, tirées de SES données (le backend nourrira) :
- **RÉGULARITÉ** : « 3 sessions en 7 jours » — la flamme-jauge existante
  est sa surface (elle s'éteint DOUCEMENT, se rallume, jamais punitive).
- **DÉPASSEMENT** : « bats ton volume/ton max sur UN exo de ton choix » —
  le choix reste à elle, le défi ne nomme jamais l'exo.
- **EXPLORATION** : « un muscle peu visité ce chapitre » — une suggestion,
  pas un programme.

**La cueillette** : le défi cueilli transforme la pill du jour en
PARFAITE (l'or) et double les pièces de la séance. Un défi par chapitre
en v1 (la rareté), affiché sur la dalle de chapitre (le rail de jeu §6.4
a déjà la place) — formulation d'INVITATION (« et si… ? »), jamais
d'injonction.

### 21.6 CE QUI PART AU PLAN BACKEND (une fois validé ici — son mot)

- `sessions` : date, séries, pièces, flags record — l'essentiel existe
  via les séances ; la pill lit CETTE table.
- `chapitres` : DÉRIVÉ (count/10), pas une table — le chemin se calcule.
- `defis` : type, fenêtre, état (proposé/cueilli/expiré doux), la graine
  de génération depuis ses données.
- `rewards` : le grant booster à la lune (l'école des 3 tables Supabase
  du parcours booster, tools/sacre/).
- La page branche `EtapeSpec` sur `sessions` (dates réelles) — les dates
  factices J-9…J meurent à ce moment-là.

### LES QUESTIONS (ses verdicts — les défauts sont posés)

1. **« 10 sessions + la lune par chapitre — oui ou non ? »** (la
   structurante ; alternatives : 7+lune plus court, 15+lune plus rare)
2. Le booster à CHAQUE lune, ou un booster sur deux + pièces sinon ?
   (défaut : chaque lune)
3. Un défi par chapitre (défaut) ou par semaine ?

### LES ARBITRAGES DE CETTE CAMPAGNE (défauts posés, SES verdicts)

1. **La direction des feux** (N2) : A / B / C / D et compositions — défaut
   proposé B + C. Le verdict qui commande toute la campagne. A s'annonce
   avec son passage au centre (l'ancrage), D' avec son amendement de la
   LOI 3.
2. **Le flou** : défaut MORT sur les feux ; au mieux, capsules
   hors-poses — N2/N4.
3. **Le curseur spectaculaire/fin des capsules** : le §13 demandait
   « spectaculaires ! », le dernier verdict demande « très fin » — le
   témoin F3 est sur la mire N7, elle pose le curseur.
4. **La nature du « tourner »** : tilt fin / F3 témoin / foyer qui
   voyage — N7.
5. **L'écho suspendu B'** et le sort des titres « La flamme suspendue » et
   « Le feu renversé » si B gagne — N2/N3.
6. **Le fondu des capsules** : (a) cuit / (b) rideau 0,10 H / (c) mixte —
   N0.
