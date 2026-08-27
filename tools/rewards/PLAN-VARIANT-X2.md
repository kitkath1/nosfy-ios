# LE VARIANT « ×2 » — le jour où on y va DEUX FOIS

**Écrit le 27-08-2026 (nuit du 26), sur le brief de Kathryn. Le plan
a été écrit d'abord (« code pas, fais un plan »), puis CODÉ le 27-08
sur le « fais un code » — l'état réel du code est au §10.** Un NOUVEAU variant rewards
ET une page d'exception de la story, comme TOP SESSION — mais pour un
autre fait : l'utilisateur est allé DEUX FOIS à la salle le même jour.
Une note backend l'accompagne (PLAN-REWARDS-BACKEND.md §4 septies).

> Le brief, recollé : « un autre variant de rewards, à ajouter dans le
> backend (encore une Nième note). Le cas comme la story exceptionnelle
> des meilleures sessions de la semaine cardio et musculation : des
> fois les users vont DEUX FOIS PAR JOUR à la salle — là on voit ce
> variant, et à la place tu mets la pastille ×2 (PAILETE_FOIS_2 sur
> mon bureau, trop belle). Dans le calendrier, ajouter un nouveau
> sticker "fois 2" qui se met AVEC les autres stickers dans le jour
> (STICKER_FOIS_2 sur le bureau). Je veux quand même un truc DIFFÉRENT
> du variant cardio/muscu : un mode DARK/WHITE très puissant ; dans le
> footer de la card une ALTERNANCE DE FUMÉE rouge, noire et blanche,
> trop belle, animée ; la sorte de HALO ROUGE ×2 dans la belle
> pastille ; les halos tout autour de l'écran dans un style différent
> — noir, rouge, orange — qui PULSE PLUS FORT ; un univers de card
> très très premium et FOLLE, car deux fois : c'est fou. »

---

## 1. CE DONT ON HÉRITE (mesuré, pas supposé)

### 1.1 La page d'exception existe : `StoryTopScene`

`Woop/Views/StorySuite.swift:757` — c'est LE moule à cloner, il porte
déjà tout le squelette :

- **la pills énorme** (`pills`, :800) — `story-pilule-top` 2648×1664,
  1,5 écran de large, reflux depuis le plein cadre (transform seul) ;
- **le halo de page** (`halo`, :828) — `RoundedRectangle(52)`, trois
  strokes : rouge 30 pt flou 26 (0,55), rouge 10 pt flou 8 (0,35),
  arête blanche 2,2 pt (0,85) avec l'AMORCE à deux à-coups (C13) ;
  respiration `0,86 + 0,14·sin(0,9·t)` ; `plusLighter`,
  `ignoresSafeArea` ;
- **la card** (`carte`, :871) — `l = min(0,80·W, 332)`, `h = 1,32·l`,
  fond `0,105 → 0,05`, plongée 1,6 → 1 + `SoftBlur`, SLAM
  (`SwapFeedback.slam()`), settle à masse C8, texte géant rouge en
  haut (`texteGeant` :959, nappes :1016), fil rouge d'arête, crête
  angulaire A1, poudre `PoudreStory(gain: 1,7)` ;
- **la pastille** (`pastille`, :1057) — `0,34·l`, née APRÈS le slam,
  catch-light apériodique (`JaugeVent.flicker`), ombre vraie, pose
  C9 (−6 pt + squash 1,03/0,97) ;
- **la mini-card néon** (`miniNeon`, :1157) — odomètre + néon qui
  s'amorce ambre → vert, « Best week », en OVERLAY à droite
  (`x = 0,50·W + 0,44·l`, `y = 0,55·H − 0,30·h`), rotation 14 → 7°.
- **la partition** `TopCine` (:736) : `poseFor 0,9`, `cardAt 5,0 /
  0,85`, `slamAt`, `haloFor 0,55`, `miniAt 6,35 / 0,45`, `sousAt
  6,15`.

Le paramétrage par sport : `enum TopSport` (`StoryFlow.swift:23`) —
`pastille`, `bigLines`, `sousTexte`, `titre`. La story monte la page
quand `StorySession.top: TopSport?` est non nul ; la table des rôles
(`PageRole` : ouverture / resume / details / analyse / butin) fait le
compte des pages. `StoryEnded(mode: .top)` monte `StoryTopScene`.

### 1.2 Le pop-reward : les robes de `RewardCard`

`RewardCard.swift:59` — `enum RewardStyle { halo, neon, galet,
spotlight, fire, welcome }`. **Il n'y a pas encore de `.top`** : le
variant TOP côté pop-reward est une NOTE (§4 quater), pas du code. Le
×2 s'écrit dans le même état : une robe `.double` notée, à coder
avec `.top` quand le chantier pop-reward s'ouvre.

### 1.3 Le calendrier et ses stickers

- `enum WoopSticker` (`CalLab.swift:4747`) : `flamme, basket, abricot,
  chocolat, bras, jambes, piscine` — `asset = "sticker-\(rawValue)"`,
  démo par hash (`demoCategory`) : UNE catégorie par jour entraîné.
- `StickerDayCell` (:1175) : une composition FIXE à deux places — la
  catégorie `0,52·s` en `(0,44 ; 0,38)`, la flamme `0,34·s` tournée
  12° en `(0,70 ; 0,54)`, le numéro du jour en bas. Pas de troisième
  place aujourd'hui.
- Le VRAI calendrier (`CalendarView.swift:27`) groupe déjà les
  séances par `startOfDay` et passe `count` à `DayCell` — **la notion
  « deux séances le même jour » EXISTE dans les données** (`count ≥
  2`), personne ne l'exploite encore. Aucune table catalogue côté
  backend : un sticker de plus ne demande AUCUNE migration (mémoire
  Supabase) — c'est un sticker de FAIT, dérivé du compte.
- Les stickers sont posés aussi sur la STORY CARD (`.story` :
  planche par titre) et dans l'ouverture du calendrier (`MotCine.
  sticker`, la pièce qui se plaque sur le paragraphe).

### 1.4 Les deux assets du bureau (sondés)

| fichier | taille | fond | lecture |
| --- | --- | --- | --- |
| `~/Desktop/PAILETE_FOIS_2.png` | 1254² RGB, pas d'alpha | NOIR (bords 0-1) | la pastille : un squircle de granit noir pailleté, « x2 » rouge laqué GRAVÉ, tranche visible en bas — la famille exacte de `sticker-pastille-lune/basket/haltere` |
| `~/Desktop/STICKER_FOIS_2.png` | 1254² RGB, pas d'alpha | BLANC (253-255) | le sticker : « x2 » rouge laqué, LISERÉ BLANC die-cut, OMBRE PORTÉE douce (min-canal 200-250 autour) |

**La pastille** se détoure par la recette ANALYTIQUE de
`detoure_pastilles_top.py` (bbox au seuil 3, squircle `r = 0,22·côté`,
fondu 1,5 px, sonde alpha > 0,98) — rejouée telle quelle →
`sticker-pastille-fois2`.

**Le sticker est un cas NOUVEAU — mesuré ce soir** : le liseré blanc
du die-cut n'est PAS séparable du fond par la luminance (fond à
253-255, liseré à 236-255 à cause de l'ombre qui le traverse ; les
seuils testés `min < 252/245/235/220` mordent soit l'ombre soit le
liseré). Or un die-cut EST un offset du glyphe : la seule forme
robuste est **cœur + couronne analytique** — le cœur rouge (`min <
235`, `fill_holes`, plus grande composante), DILATÉ de W px (W = la
largeur du liseré, mesurée sur le canevas 1254 — ~30-40 px à l'œil, à
MESURER), RGB forcé au blanc de la famille sur la couronne, fondu
1,5 px, l'ombre JETÉE. Sonde de sortie : alpha moyen dans le sujet >
0,98 (PIÈGE 1 de PIEGES-STICKERS.md). Sortie `sticker-fois2` en 768²
(la taille de `sticker-jambes`, la story card tire à ~519 px en 3x).

---

## 2. LE FAIT — ce qui déclenche, et ce que ça n'est pas

**« ×2 » = la DEUXIÈME séance RÉGLÉE le même jour local** (le jour de
l'utilisateur, pas UTC — la TZ du device part avec le settle). Il
s'allume au deuxième `settle_session` du jour, UNE fois par jour :

- la story de la 2ᵉ séance ouvre sur la page ×2 (la 1ʳᵉ séance du
  jour a eu une story ordinaire — elle ne savait pas encore) ;
- une séance ne compte que si elle est VALIDE au sens du settle
  (le même seuil que la série/streak — à trancher §8 Q5 : deux
  séances de 3 min ne font pas un ×2) ;
- une 3ᵉ séance le même jour ne rallume rien (le fait est « deux
  fois », pas « encore ») — Q2 ;
- ×2 ET TOP le même jour : deux exceptions — ordre à trancher (Q3) ;
  le moule accepte les deux pages (table des rôles), rien ne casse.

Le CALENDRIER dérive le sticker `fois2` du compte par jour (`count ≥
2`) — une donnée, pas un état : il apparaît dans le passé aussi, dès
que la règle existe.

---

## 3. LA SCÈNE — DIFFÉRENTE de TOP, de bas en haut

Le principe qui fait la différence : **TOP est rouge sur noir ; ×2
est NOIR ET BLANC — le rouge n'y existe qu'en TROIS points** : le
« x2 » de la pastille, la fumée, le halo de page. Tout le reste est
un dark/white « très puissant » : un noir plus profond que TOP, un
blanc plus pur, aucun gris tiède.

1. **Le noir** de la story.
2. **LA PILLS ÉNORME** — la même (`story-pilule-top`), mais **par la
   GAUCHE** (miroir : `x = −w·0,28` au lieu de `W − 0,72·w`) — le
   premier signe que ce n'est pas TOP, gratuit. Option : recuit
   `story-pilule-x2` en désaturant le rouge vers le noir-blanc (scrim
   numpy, jamais un filtre SwiftUI sur la vidéo) — Q6.
3. **LE HALO DE PAGE « noir, rouge, orange, qui pulse plus fort »** —
   TROIS couches, dans cet ordre (du dehors au dedans) :
   - **le NOIR** : une vignette — `strokeBorder(black 0,70,
     lineWidth 44, blur 34)` — qui MANGE les bords de l'écran avant
     tout le reste (le noir n'est pas une couleur qui s'ajoute, c'est
     l'écran qui s'éteint au bord) ;
   - **l'ORANGE** : `(1,0 ; 0,55 ; 0,10)`, 26 pt, flou 22, 0,50 ;
   - **le ROUGE** : `(1,0 ; 0,20 ; 0,05)`, 12 pt, flou 8, 0,45 —
     PAS d'arête blanche (elle appartient à TOP) ;
   - **la PULSATION** : amplitude 0,30 (TOP : 0,14) sur LE RYTHME ×2
     (§4) — deux coups rapprochés puis le repos, la signature de la
     page. Anti-brun : R = 1,00 tenu, on ne désature que le vert.
     ⚠️ MESURÉ À LA SONDE de luminance sur pixels clairs (la leçon
     du halo à +2,2), et le `plusLighter` à pleine intensité SATURE
     AU BLANC (payé ce soir sur le holo des boosters) : l'orange se
     règle en additif RETENU.
4. **LA CARD** — le moule TOP re-costumé :
   - **fond** : `0,07 → 0,015` (plus noir que TOP), la crête
     angulaire A1 en BLANC plus franc (0,42) — la seule lumière
     froide de la scène ;
   - **le texte géant** en haut : l'école du mot ARGENT de la story 3
     (`StoryCard` — pas le rouge de TOP) — blanc pur → argent →
     graphite, traîne longue qui fond dans le noir, nappes BLANCHES
     diffuses ; deux lignes `bigLines` — candidats §5 ;
   - **la pastille** au centre : `sticker-pastille-fois2`, 0,34·l,
     même naissance/pose/catch-light — PLUS **le HALO ROUGE ×2 dans
     la pastille** : un `RadialGradient` rouge `(1,0 ; 0,22 ; 0,06)`
     masqué à la zone du glyphe (ellipse `0,58 × 0,36` du côté,
     centre `(0,52 ; 0,50)`), `plusLighter`, 0,18 au repos, qui
     BAT sur le rythme ×2 jusqu'à 0,42 — le « x2 » gravé s'éclaire
     de l'intérieur, comme une braise sous le laqué ; plus un
     mince fil rouge sur la tranche basse du squircle (l'écho) ;
   - **le footer : LA FUMÉE** (§3.1) ;
   - **titre + sous-titre** (le registre des autres cards, SF 25 +
     15) : « Double day » / « Two sessions today. » — posés SUR la
     fumée, blanc pur ;
   - **pas de mini-card néon vert** (c'est TOP). À sa place, le fait
     qui justifie l'exception : **la mini-card des DEUX HEURES**, à
     GAUCHE (miroir), néon BLANC PUR (dark/white) — « 07:12 · 19:40 »
     en odomètre (les deux heures roulent), kicker « Twice today ».
     Le blanc néon = encre blanche + deux ombres blanches (3 / 12),
     le seul néon de la scène. En overlay, jamais dans le flux.
5. **Les segments** `StoryProgress`, inchangés.

### 3.1 LA FUMÉE DU FOOTER — « une alternance de fumée rouge, noire
### et blanche, trop belle, animée »

Il n'existe aucune fumée dans la bibliothèque (ni vidéo, ni shader).
Deux voies, une recommandée :

- **SHADER (recommandé)** — un `Rectangle().colorEffect(ShaderLibrary
  .fumeeX2(...))` borné à la BANDE du footer (`l × 0,34·h`), jamais
  plein écran (la loi du Canvas/shader plein écran : on rasterise ce
  qu'on borne). Un fbm à 3 octaves advecté lentement (deux champs de
  vent à périodes premières, 0,07 et 0,11 rad/s), TROIS PANACHES qui
  montent du bord bas, chacun avec SA teinte — et l'alternance est
  une PARTITION, pas un cycle : la teinte de chaque panache glisse
  rouge → noir → blanc → rouge sur ~14 s, décalées d'un tiers, de
  sorte qu'à tout instant les trois couleurs coexistent et qu'aucune
  ne domine deux fois de suite. Le NOIR se rend en SOUSTRACTIF (il
  assombrit la card — donc le footer est légèrement plus clair que
  le corps, `0,11`, pour que le noir se lise), le BLANC et le ROUGE
  en additif retenu (`plusLighter` ≤ 0,55, jamais saturé). La fumée
  FOND vers le haut (masque vertical, morte à `0,34·h`) et déborde
  un peu des flancs sous la coupe de la card (elle vit DANS la card,
  coupée par sa forme — la poche des boosters, même école).
  Uniformes : `time`, `size`, `teintes[3]`, `battement` (le rythme
  ×2 fait FRISSONNER la fumée à chaque coup — turbulence +20 %
  pendant 0,15 s). Pièges payés à respecter : arité du stitchable
  (page BLANCHE sans erreur), `float4` à ZÉRO au runtime, un
  uniforme = UN rôle, sondes couleur pour diagnostiquer.
- **VIDÉO CUITE** — pas de rush de fumée dans le dépôt ; il faudrait
  en générer (ffmpeg n'en fait pas de belle) — écartée sauf si
  Kathryn a un rush.

Cadence : un shader sur 332×150 pt à 60 Hz est de l'ordre du coût
du halo — à MESURER au banc (`mpdecimate`), objectif ≥ 75 img/s sur
la page (WIN tient 76-80 avec sa poudre).

---

## 4. LE RYTHME ×2 — la signature de la page

Une seule horloge, partagée par le halo de page, le halo de la
pastille, la fumée et les haptiques : **deux coups à 0,28 s
d'intervalle, puis 1,9 s de repos** (période 2,46 s, un battement de
cœur qui dit « deux »). Fonction pure de `t` :
`bat(t) = pulse(φ) + pulse(φ − 0,28)` avec `φ = t mod 2,46`, `pulse`
= une cloche `exp(−(φ/0,09)²)`. Jamais un sinus nu : c'est le rythme
qui rend le ×2 lisible sans l'écrire.

L'ARRIVÉE : la card plonge et SLAM (TOP) — puis un SECOND coup 0,28 s
après (échelle 1,0 → 1,025 → 1,0 en cloche, haptique rigide plus
courte) : le premier battement ×2 est l'atterrissage lui-même. Le
halo de page s'allume sur le second coup (pas le premier — le retard
fait le wahou, comme la mini-card de TOP). La pastille naît après le
second coup ; la fumée MONTE du bord bas de la card pendant 1,2 s
(elle n'est pas là avant : la card se pose, puis elle fume).

Haptiques : slam (lourd) + second coup (rigide 0,7) à l'arrivée ; puis
au repos, RIEN — le rythme visuel suffit (un téléphone qui bat toutes
les 2,5 s fatigue). Un grain doux à la naissance de la pastille (D16).

---

## 5. LE TEXTE — les deux lignes

| ligne 1 / ligne 2 | ton |
| --- | --- |
| `TWICE` / `TODAY` | le fait, sec |
| `DOUBLE` / `DAY` | descriptif, court |
| `AGAIN` / `TODAY` | le geste (elle est revenue) |
| `TWO` / `TIMES` | littéral |

Le contrat `bigLines` (3-9 signes) tient pour tous. Titre « Double
day », sous-titre « Two sessions today. » — VRAIS (du fact engine),
gabarit déterministe d'abord. Une variante muscu/cardio n'existe PAS
ici : le fait est le même quel que soit le sport (Q1 pour le mot).

---

## 6. LE CALENDRIER — le sticker `fois2` « avec les autres »

- **Le registre** : `WoopSticker` gagne `fois2` (asset
  `sticker-fois2`) — un sticker de FAIT, pas de catégorie : il ne
  remplace ni la catégorie ni la flamme, il s'AJOUTE.
- **La case** (`StickerDayCell`) : une TROISIÈME place — `0,36·s`,
  tournée −10°, en `(0,30 ; 0,66)`, sous la catégorie et à gauche de
  la flamme, PAR-DESSUS (z le plus haut : c'est l'exception). La
  composition à trois se vérifie à la taille RÉELLE d'une case (33 ×
  51 px en 3x mesurés par la session stickers) — si ça fait soupe, la
  variante : la flamme se DÉCALE de 6 % vers la droite les jours ×2.
- **La donnée** : `count ≥ 2` par `startOfDay` (déjà calculé dans
  `CalendarView`) ; la démo `CalLab` a besoin d'un hash « jour
  double » (~1 jour sur 11 entraînés) pour montrer le sticker au
  banc.
- **La story card** : `fois2` entre dans la planche des stickers les
  jours ×2 (il porte le fait).
- **L'ouverture du calendrier** (`CineBilan`) : rien à changer —
  `MotCine.sticker` accepte n'importe quel `WoopSticker`.

---

## 7. LE POP-REWARD — la robe `.double`

Comme TOP §5 : le MÊME variant côté récompenses, `RewardStyle.double`
(noté au backend §4 septies), boutons Claim/Later vivants, le halo de
page vit sur le SCRIM (noir/rouge/orange, pulsé), la fumée dans le
footer de la card reste, la pills énorme devient un fond. Le moteur
décide QUAND (2ᵉ settle du jour), jamais le client. À coder AVEC
`.top` — les deux robes d'exception naissent ensemble dans
`RewardCard`.

---

## 8. LES JALONS (une capture validée à chaque pas)

- **X1 — les deux assets.** `sticker-pastille-fois2` (squircle
  analytique rejoué) + `sticker-fois2` (cœur + couronne analytique —
  W mesuré d'abord — RGB blanc forcé, ombre jetée, sonde alpha) ;
  planche de contrôle : la pastille dans le squircle aux deux tailles,
  le sticker sur une case 33×51 à côté de la flamme et d'une
  catégorie.
- **X2 — la fumée au banc.** Le shader seul, dans une card noire
  (`-fumeeLab`) : les trois panaches, l'alternance, le noir qui se
  lit, le frisson du battement ; cadence mesurée ; sondes couleur.
- **X3 — la scène.** `StoryDoubleScene` cloné de `StoryTopScene` :
  pills à gauche, halo noir/rouge/orange, card dark/white, mot
  argent, pastille + halo rouge ×2, fumée, titre/sous-titre ; le
  rythme ×2 partagé ; banc `-storyDouble` (sim kat-story).
- **X4 — l'arrivée.** Slam + second coup, halo au second coup,
  pastille puis fumée ; mini-card des deux heures à gauche ; film,
  détecteur de flash, sonde de luminance du halo.
- **X5 — le branchement story.** `StorySession.double: DoubleFait?`
  (les deux heures), la table des rôles (5 pages ce jour-là, 6 si
  TOP aussi — Q3), `StoryEnded(mode: .double)` ; non-régression du
  flow normal, TOP, WIN.
- **X6 — le calendrier.** `fois2` au registre + la troisième place
  de la case + le hash de démo + la planche story ; sur le VRAI
  calendrier, `count ≥ 2`.
- **X7 — verdicts téléphone** (haptiques du double coup, la fumée
  à l'œil, le halo mesuré). La robe `.double` du pop-reward et la
  règle backend s'implémentent avec leurs chantiers.

---

## 9. À TRANCHER PAR KATHRYN

1. **Le mot** : `TWICE / TODAY`, `DOUBLE / DAY`, `AGAIN / TODAY`,
   ou pas de mot (la pastille dit déjà ×2) ?
2. **Trois séances le même jour** : rien de plus (« deux fois » est
   le fait), ou la pastille dit ×3 (il faudrait un asset) ?
3. **×2 et TOP le même jour** : deux pages d'exception à la suite
   (×2 d'abord — c'est le jour, TOP ensuite — c'est la semaine), ou
   une seule (laquelle) ?
4. **La mini-card** : les DEUX HEURES (« 07:12 · 19:40 ») ou le total
   (« 96 min today ») ?
5. **La séance valide** : quel minimum pour qu'une séance compte
   (durée, séries réglées) — le seuil du streak ?
6. **La pills** : la même que TOP en miroir (gratuit), ou une
   `story-pilule-x2` recuite noir-blanc (le rouge de la vidéo est le
   seul rouge « gratuit » de la scène — le garder ou l'éteindre) ?
7. **La fumée** : shader (recommandé — rien à cuire, réglable au
   banc), ou un rush vidéo si tu en as un ?
8. **Le sticker dans la case** : troisième place à gauche-bas
   (proposé), ou il remplace la flamme les jours ×2 ?

---

## 10. CE QUI EST CODÉ (27-08, jalons X1→X6 — « fais un code »)

Tout tourne au banc `-storyLab -storyAuto -storyDouble` (sim
kat-story). Les questions du §9 ont été tranchées EN CODANT ; ce qui
reste ouvert est marqué.

- **X1 — les assets** (`tools/rewards/detoure_x2.py`) :
  `sticker-pastille-fois2` (944×882, squircle analytique r = 193,
  alpha sujet 1,000) et `sticker-fois2` (768² comme la famille,
  alpha 1,000). LA RECETTE NOUVELLE, mesurée : le liseré die-cut
  (237-254) n'est pas séparable du fond blanc (253-255) — mais
  l'OMBRE qui le longe tombe à 153-233 juste contre lui. Donc :
  cœur (min-canal < 238, trous remplis, plus grande composante),
  ZONE de 48 px autour, et dans la zone on ne garde que le BLANC
  (≥ 236) — l'ombre reste dehors. Couronne obtenue : 15 px médians.
  Planche de contrôle : la pastille aux deux tailles + le sticker
  sur une case 33×51 à côté de la flamme.
- **X2/X3 — la scène** (`StoryDoubleScene`, StorySuite) : pills à
  GAUCHE (miroir `scaleEffect(x: -k)` — zéro recuit, Q6 tranchée),
  halo noir/orange/rouge sans arête blanche, card 0,07 → 0,015, mot
  ARGENT « TWICE / TODAY » (Q1 tranchée), pastille ×2 avec sa
  BRAISE qui bat, fumée au footer, titre « Double day » /
  « Two sessions today. ».
- **LA FUMÉE** (`Woop/FumeeX2.metal`) : trois panaches, fbm 3
  octaves + déformation à une octave, enveloppe large (0,15 +
  0,30·hauteur) et rampe longue (0,30 → 0,82) — c'est la RAMPE qui
  fait le diffus ; teintes passées en uniformes (la partition vit en
  Swift : rouge → noir → blanc sur 14 s, décalées d'un tiers) ;
  BRUME CLAIRE au pied (0,16/0,13/0,12) — sans elle la fumée noire
  ne se lit pas sur du noir ; horloge quantifiée à 30 Hz.
  ⚠️ **LA MONTÉE EN CHALEUR EST MORTE** (jouée puis retirée le
  27-08 : « l'effet flamme est tout much, laisse comme c'était
  avant ») — la vibration, la poussée et le réchauffement orange
  sont supprimés du shader ET de Swift. Ne pas les ressusciter.
- **X4 — l'arrivée** : slam, puis le SECOND COUP 0,28 s après
  (cloche d'échelle 2,5 % + haptique rigide) ; le halo s'allume sur
  le SECOND, la pastille naît après, la fumée monte ensuite. Le
  RYTHME ×2 (`DoubleCine.battement` : deux cloches à 0,28 s,
  période 2,46 s) est partagé par le halo, la braise et la
  turbulence de la fumée.
- **LE PROJECTEUR** (verdict « un effet spotlight sur le x2 au
  niveau de Twice today ») : la mini-card n'est plus posée à côté,
  elle est LA SOURCE — un éventail à deux nappes (`EventailX2`,
  proportionnel : le `Eventail` de la robe spotlight est `private`
  et calé en points fixes) descend de son bord, penché de 19° vers
  le centre, et s'avive au battement.
- **X5 — le branchement** : `StorySession.double: DoubleFait?`
  (heures + minutes), `StoryEnded.Mode.double`, la table des rôles
  passe par `exception` (×2 d'abord, TOP ensuite — la loi complète
  est au backend §4 octies), banc `-storyDouble`.
- **X6 — le calendrier** : `WoopSticker.fois2` + `demoDouble` (~1
  jour entraîné sur 4) + la TROISIÈME place de la case (0,38·s,
  −10°, (0,30 ; 0,66), par-dessus) — vérifié au banc `-calLab` :
  le ×2 se lit à côté de la flamme et de la catégorie.

### La cadence — MESURÉE, et pas encore payée

| variante | img/s uniques (mpdecimate, 5 s) |
| --- | --- |
| complet (1er jet) | 39 |
| sans la fumée | 44 |
| sans le halo | 53 |
| complet, halo RASTERISÉ (`drawingGroup`) | **44** |

Le halo coûtait 14 img/s à lui seul (trois flous plein écran
recalculés par image) : son contenu est CONSTANT, il est désormais
rasterisé une fois et seule l'opacité bouge — +5 img/s. La fumée
coûte ~5. On reste sous les 76-80 de WIN : restent à essayer, dans
l'ordre, la bande de fumée en `drawingGroup` animé par le seul
`colorEffect`, un halo cuit en image, et le `SoftBlur` de l'entrée.
Fouettage : un seul saut de luminance > 25 sur 475 images, à la
COUPE de la verrière — la transition voulue, pas un flash.

### Les questions qui restent

Q2 (une 3ᵉ séance : rien de plus ?), Q4 (les deux heures — codé —
ou le total ?), Q5 (le seuil de séance valide), Q7 (la fumée en
shader — codée — ou un rush ?), Q8 (la place du sticker — codée en
3ᵉ place). Q1/Q3/Q6 tranchées.
