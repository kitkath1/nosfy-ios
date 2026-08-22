# LE MODE ÉDITION DES WIDGETS — « LA VITRINE »

Plan dicté le 2026-08-22 sur brief de Kathryn. **Rien n'est codé — le plan
attend le GO.** Il s'appuie sur l'état réel du code (lecture du 22-08 :
`WidgetsCards.swift`, `HomeNuit.swift`, `Models.swift`, `MenuNappe.swift`,
`BoosterLab.swift`) — chaque pièce citée existe, chaque piège cité a déjà
été payé.

Le brief en une phrase : **on pose le doigt sur un widget, il se met à
respirer ; une lune propose ; « Changer » éteint la pièce et pose le widget
seul dans la lumière, au milieu d'une vitrine qu'on fait tourner du pouce.**

---

## 1. LA DOCTRINE (les lois qui tranchent les micro-débats)

**LOI 1 — ON ÉDITE UN OBJET, PAS LA PAGE.** L'appui long se fait SUR un
widget (le choix de Kathryn, et il est juste : l'utilisateur comprend
immédiatement CE qu'il modifie). Rien d'autre sur la home ne déclenche ce
mode. Et chaque pastille édite SA card.

**LOI 2 — LA VIBRATION EST UNE RESPIRATION, PAS LE JIGGLE D'iOS.** Pas le
shake caricatural du springboard : une oscillation de **±1,4°**, lente
(périodes **2,9 s et 3,7 s**, une par card, premières entre elles — sinon
elles battent ensemble), en opposition de phase. Et la lumière obéit : la
crête du liseré angulaire **contre-tourne** de l'angle d'oscillation — la
lampe reste fixe dans la pièce pendant que l'objet penche. C'est ça, « le
Liquid Glass qui réagit au mouvement » : pas un effet ajouté, la loi 1 de
la maison appliquée au wiggle.

**LOI 3 — LA LUNE DIT « MODIFIER », PAS « SUPPRIMER ».** La pastille n'est
pas une croix de suppression : c'est la porte des choix. La destruction est
UN des deux choix, jamais le visage du mode.

**LOI 4 — LA VITRINE N'EST PAS UN CONFIGURATEUR.** Jamais quatre cards en
grille. Un seul widget dans la lumière, à sa vraie taille ; les autres
reculent, plus petits, sombres, flous. On tourne, la lumière change de
main, on confirme. (Et un seul VERRE à la fois : seul le widget au centre
porte le `glassEffect` — les voisins sont des clones peints. C'est la loi
de perf et la loi de lecture en une seule règle.)

**LOI 5 — LA HOME GARDE TOUJOURS UN WIDGET.** On peut supprimer 1 des 2,
jamais le dernier. Et le refus est DOUX : pas de rouge, pas d'alerte
système — une pop-up de verre flottante qui s'excuse presque, la vibration
d'erreur de la maison (`RefusalHaptic`, les deux `rigid` à 90 ms), et elle
part toute seule.

**LOI 6 (maison) — UN GESTE = UN CURSEUR.** Chaque transition tient à UNE
grandeur `p` animée une fois, fenêtres dérivées (`fen(a,b)` + adoucisseur,
l'école `MenuNappe.swift:1105-1121`). Jamais une chaîne d'`asyncAfter`
(la leçon du § 13.4 du plan home). La lumière passe avant la géométrie, et
la fermeture se fait dans le silence.

---

## 2. LE FLOW COMPLET (la machine à états)

```
REPOS
 │ appui tenu 0,50 s sur une card (immobile < 10 pt)
 ▼
ÉDITION  — haptic sec, zoom arrière de la zone, respiration, 2 pastilles lune
 │  ├─ tap hors widgets ────────────────────────────► REPOS
 │  └─ tap sur une lune
 ▼
LISTE  — drop-list « Changer / Supprimer » pendue à la pastille
 │  ├─ tap dehors ──────────────────────────────────► ÉDITION
 │  ├─ Supprimer, dernier widget ──► REFUS (pop-up 2,2 s) ─► ÉDITION
 │  ├─ Supprimer, sinon ──► paillettes, le slot devient FANTÔME ─► ÉDITION
 │  └─ Changer
 ▼
VITRINE  — la home recule, le bas se masque, le widget vole au centre,
 │         le carousel spatial autour de lui
 │  ├─ tap sur le scrim ──► le widget d'origine revole à son slot ─► ÉDITION
 │  ├─ swipe = crans (haptique à chaque centre), appui = chambre (aperçu)
 │  └─ tap sur le widget centré = CONFIRMER
 ▼
SNAP  — l'élu vole vers le slot, la home revient ─► REPOS (silence)
```

Le fantôme de slot (voir § 3.5) offre le chemin d'AJOUT que le brief ne
disait pas : tap sur le fantôme → VITRINE directement (il faut bien pouvoir
remettre un second widget).

---

## 3. L'ANATOMIE, PIÈCE PAR PIÈCE

### 3.1 Le déclenchement — et l'arbitrage qu'il impose

Chaque card possède DÉJÀ un geste riche (`WidgetsCards.swift:507/750`) :
un `DragGesture(minimumDistance: 0)` où le tap < 0,28 s bascule la chambre,
et l'appui tenu fait un APERÇU de la chambre refermé au relâchement. Le
fichier porte la loi en toutes lettres (l.749) : *un `onLongPressGesture`
volerait le tap*.

**Le long press d'édition s'intègre donc DANS cette machine, il ne s'ajoute
pas à côté** : dans `onChanged`, si le doigt est posé depuis **0,50 s** sans
avoir fui de plus de 10 pt → édition. Conséquence à assumer : **l'aperçu de
la chambre meurt sur la home** (sa fenêtre 0,28 → 0,50 s devient trop
courte pour exister). La chambre reste au tap — et elle retrouve son rôle
d'aperçu à l'appui DANS la vitrine (§ 3.6), où le long press n'a plus de
sens. C'est l'arbitrage A du § 11.

Au déclenchement : le doigt est encore posé — l'édition s'arme SOUS le
doigt (haptic `.rigid` sec, le zoom arrière commence), et le relâchement ne
fait rien de plus. Un seul geste, trois issues : tap, édition, drag ignoré.

**Les guards, tous nécessaires** (payés ailleurs) :
- `tirageGeste` (le drag de page, `HomeNuit.swift:2356`) prend un
  `guard !enEdition` — sinon un doigt qui dérive nourrit le tirage ;
- le panneau de l'objectif se ferme à l'entrée en édition
  (`reglageOuvert = false`) et son rattrapeur de tap (`HomeNuit.swift:2341`)
  apprend à ignorer les taps du mode édition ;
- les minis de la semaine gardent leur geste (elles ne sont pas dans la
  zone), mais le film de départ (`depart/ferme`) refuse de se lancer
  pendant l'édition.

### 3.2 L'état édition : la respiration des cards

À `pEdit` 0 → 1 (0,42 s, `timingCurve(0.22,1,0.36,1)`) :

- **le zoom arrière** : la rangée entière à l'échelle **0,96**, ancre au
  centre de la rangée. Précédent licite : le retrait du menu fait déjà un
  `scaleEffect` sur le mobilier verre compris (`MenuNappe.swift:1139`) —
  un transform ne touche pas les bounds du verre ;
- **la respiration** (loi 2) : rotation ±1,4°, périodes 2,9/3,7 s,
  opposition de phase, crête du liseré en contre-rotation. Elle vit dans un
  enfant `Animatable` à ses horloges (les cards ont déjà deux
  `TimelineView` — 12 Hz liseré, 24 Hz mois — on ne pose pas une troisième
  horloge sur la page, piège « la page ré-évaluée par image ») ;
- **les pastilles** arrivent en dernier : `fen(0.55, 1.0)`, scale
  0,6 → 1,06 → 1,00 (l'école des cinq points), 70 ms d'écart entre les
  deux cards.

Sortie : tap n'importe où hors des widgets. Pas de bouton « OK », pas de
temporisation — le mode reste tant qu'on ne le quitte pas (grammaire iOS).

### 3.3 La pastille lune

**`Medaillon(taille: 22) { GlypheLune }` — le bol noir peint, PAS du verre
natif.** La raison est une loi payée : le verre natif à jeun sur un coin
noir ne montre rien (p95 = 23, § 7 quinquies du plan home). Le
`Medaillon` (`MenuCouronne.swift:135`) est déjà la surface « Liquid Glass
noir » de la maison : bol radial décentré, liseré angulaire à quatre
événements neutres, cheveu, double ombre qui décolle — il brille sur
n'importe quoi parce qu'il peint. Dedans, `CroissantLune(taille: 11)`
(`ProfilLune.swift:1753`), blanc 0,72 — le logo, très discret, jamais un
pictogramme braillard.

Pose : **coin haut-droit** de chaque card, centre de la pastille posé SUR
le coin (elle déborde de ~8 pt — un objet posé sur l'objet, pas un badge
dans le cadre). La pastille suit la respiration de sa card (même transform,
elle est DE la card).

Son geste : un seul `DragGesture(minimumDistance: 0)` (la loi), tap =
LISTE, haptic `.soft` à la pose.

### 3.4 La drop-list — « très Apple : deux lignes, énormément de vide »

- **Panneau** : verre natif `.clear`, **156 × 106**, coins 24, pendu à la
  pastille par son bord DROIT (la grammaire du panneau de l'objectif, qui
  pend par un bord — `PLAN-HOME-V2 § 7 quinquies` ; à droite pour que la
  card 2, qui finit à x = 378, reste dans l'écran ; clamp à 12 pt du bord).
  Il s'ouvre vers le BAS. Sur la vidéo, ce verre a de quoi manger — et pour
  le « blur noir » du brief, la recette existe déjà dans la card même : une
  **plaque noire 0,50 posée SUR le verre, SOUS l'encre**
  (`WidgetsCards.swift:260`, la plaque de la chambre). L'encre vit
  AU-DESSUS du conteneur (la loi du galet de l'objectif) ;
- **Deux items** : `Changer` / `Supprimer`. `.inter(15, .regular)`,
  interlignes généreux (les deux lignes dans 106 pt de haut : le vide EST
  le luxe), pas de séparateur, pas de chevron, pas de rouge sur
  « Supprimer » (loi 5 : la destruction ne crie pas) ;
- **La sélection = la mise au point**, pas un chip (la loi § 13.7 du plan
  home : rien derrière un mot) : sous le doigt le mot densifie (deux
  `Text` croisés Regular↔Medium, tracking qui se resserre), l'autre pâlit.
  Tap direct OU drag depuis la pastille avec relâchement sur l'item — le
  même geste que la loupe du menu, en deux crans ;
- **Naissance** : le panneau naît de la pastille — masque à taille
  constante (`scaleEffect` d'un masque 0,24 + 0,76·p, ancre la pastille,
  l'école `MenuCouronne.swift:567`), JAMAIS des bounds animés. Et il se
  DÉMONTE sous p < 0,01 (le verre natif ignore `.opacity`) ;
- Fermeture : tap dehors → retour ÉDITION.

### 3.5 Supprimer — les paillettes, le fantôme, le refus

**La suppression autorisée** : la card part en **paillettes** (le verdict
gravé : « swap = paillettes, plus jamais de dissolution » — la mort d'un
widget est un swap vers rien). La poudre maison existe (`semer()`,
les systèmes de poudre de la home) ; la card se comprime à 0,94 puis la
poudre l'emporte en ~0,5 s, haptic `.soft` puis silence.

**Le slot ne devient pas un trou : il devient un FANTÔME.** La grammaire
existe déjà sur cette page — les mini-cards « à faire » de la semaine sont
des fantômes `.clear` nourris par la vidéo (§ 9.5). Le slot vide = la
silhouette de la card en verre nu, SANS encre, avec au centre un `+`
hairline blanc 0,25. Tap sur le fantôme → VITRINE directement (le chemin
d'ajout). Hors mode édition, le fantôme reste — discret, c'est un objet de
verre vide sur la vidéo, il dit « il y a une place ici » sans le crier.
⚠️ Bounds constants : le fantôme fait exactement 170 × 170, la
matérialisation inverse (fantôme → card pleine) est un fondu de calques
par-dessus le verre, le verre ne se démonte jamais (la loi de la semaine,
`PLAN-HOME-V2 § 9.9`).

**Le refus (dernier widget)** :

> Gardez au moins un widget
> Votre Home a besoin d'un aperçu actif.

Pop-up flottante : verre `.clear` **300 × 64**, coins 22, posée 24 pt
au-dessus de la rangée, plaque noire 0,45 sous l'encre, titre
`.inter(14, .semibold)` blanc 0,92, sous-titre `.inter(12)` blanc 0,55.
`RefusalHaptic` (les deux `rigid` à 90 ms — le « non » universel maison,
`GaletSlide.swift:848`, à déplacer hors du fichier archivé). Elle naît par
masque (mêmes lois de verre), respire 2,2 s, part en fondu descendant.
Jamais deux à la fois (un garde).

### 3.6 « Changer » — LA VITRINE (le vrai moment premium)

**a) La home s'éteint.** La mécanique existe et elle est validée : le
retrait de `MenuHote` (`MenuNappe.swift:1119-1146`) — `retrait =
max(montee, recul)` devient `max(montee, recul, vitrine)` : le MOBILIER
recule (blur 7 pt + scale 0,974 + extinction), **la vidéo ne recule
jamais** (couche UIKit, elle saute — la loi `HomeNuit.swift:1813`), et un
scrim noir **0,30** se pose sur elle (« s'enfonce dans le noir » — mais
jamais noir total : le verdict « l'écran noir non ! » du 22-08 tient, la
vidéo doit continuer de nourrir le verre du widget central). Pas un seul
`.blur` plein écran par image : on floute le mobilier, petites surfaces.

**b) Le bas disparaît.** Tout ce qui vit sous la card : le galet home →
`rangerDemande` + `verrouille` (les deux entrées existent,
`MenuNappe.swift:979-990`) ; `SliderObsidienne` → son masquage piloté
existe (opacity + échelle UNIFORME + blur coupé net,
`HomeNuit.swift:2140-2170` — jamais un `scaleEffect(x:)` sur le SDF) ;
`InviteTirage` (« Pull to start ») → `allowsHitTesting` + opacity déjà
pilotés (l.2322) ; `FumeeInvite` → **DÉMONTÉE** (`if`), jamais
`opacity(0)` (l.2301). La phrase et la semaine partent avec le retrait du
mobilier.

**c) Le widget se détache physiquement.** L'overlay de la vitrine vit
au-dessus de `MenuHote` (l'école `DepartPanneauHote`,
`HomeNuit.swift:1872`) — posé DANS `contenu:` il hériterait du blur et de
l'offset du tirage. Le vol : la frame globale du slot est connue (ancres
fixes : leading 24, top 0,375 × h, 170 × 170), un clone vole du slot au
centre de la scène (x = centre écran, y ≈ 42 % de la hauteur — le bas est
masqué, la vitrine vit haut) ; position interpolée par UN curseur
`Animatable` (jamais deux `withAnimation` sur la même valeur), **échelle
1,00 constante** — le widget flotte à sa vraie taille, c'est le brief, et
ça règle d'office la loi des bounds du verre. L'original est démonté à
l'instant où le clone naît (pas deux verres superposés).

**d) Le carousel spatial.** La mathématique du manège du booster,
transposée en SwiftUI plat (on prend les nombres, pas SceneKit —
`BoosterLab.swift:1617-2144`) :

- offset en **crans flottants**, pas de **210 pt** ; chaque widget du
  catalogue : `d = index − offset` ;
- position `x = d × 210`, échelle `1 − 0,14·min(|d|, 1,3)`, voile noir
  `0,45·min(|d|,1)`, flou `2,6·min(|d|,1)` — les voisins sont « légèrement
  reculés, plus petits, sombres et floutés », exactement le brief ;
- **seul le centre porte le verre** (loi 4) : les voisins sont des clones
  `verre: false` (l'ardoise peinte de `CardCorps` tient toute seule) ; au
  passage du centre, le verre se DÉMONTE sur le sortant et se monte sur
  l'entrant sous le fondu du voile — bounds constants, jamais un
  `glassEffect` flouté ni scalé ;
- scrub : `offset = grabOffset − dx/210` ; relâcher : vitesse clampée,
  cible `(offset + vel×0,35).rounded()` bornée à **±2 crans**, ressort
  quasi critique ; **cran haptique** (`UISelectionFeedbackGenerator`) à
  chaque changement de centre — le clic de barillet du manège ;
- **le widget actif porte UNIQUEMENT un fin reflet blanc sur son
  contour** : c'est le liseré angulaire EXISTANT de la card, crête blanche
  montée, crête OR ÉTEINTE (pas de grosse border, pas d'orange — et on ne
  rallume pas l'or, la loi du 22-08). Le reflet respire ±3° comme au
  repos : l'objet est vivant, pas surligné ;
- sous le centre, en encre 11 pt majuscules tracking 2,4 blanc 0,38 :
  `01 — RÉGULARITÉ` (le nom seul, une ligne, rien d'autre) ;
- **l'appui tenu sur le centre = LA CHAMBRE** (l'aperçu existant des
  cards) : « 17.0 km/h · 40 s · ×4 » — le geste retrouvé, au seul endroit
  où il a du sens ;
- tap sur un voisin = il vient au centre (un cran). Tap sur le centre =
  **CONFIRMER**.

**e) La confirmation et le retour.** `CommitHaptic` (les 3 coups montants).
Les voisins s'effacent D'ABORD (60 ms), puis l'élu vole vers le slot
pendant que le retrait se relâche — « on voit partir ce qu'on a choisi »,
la grammaire de fermeture du menu. Le slot matérialise la nouvelle card
(fondu de calques sur le verre). Puis le silence : aucune haptique à la
repose (la loi : un geste qui finit en silence se sent plus cher).

**f) L'annulation.** Tap sur le scrim : le widget d'ORIGINE revole à son
slot, rien n'a changé, retour ÉDITION.

---

## 4. LES QUATRE WIDGETS (le catalogue)

| # | nom | ce qu'il dit | état |
|---|---|---|---|
| 01 | **Régularité** | 4 / 5 · les 7 jours de la semaine | = `CardSeances`, existe |
| 02 | **Volume** | 8.4 kg · volume hebdo, +12 % | = `CardVolume`, existe |
| 03 | **HIIT Peak** | 17.0 km/h · 4 × 40 s — le meilleur segment haute intensité | à créer |
| 04 | **Peak Effort** | PEAK · le moment le plus fort de la semaine, tous types | à créer |

Les deux nouveaux réutilisent **`CardCorps<Contenu>`** (générique, tout en
fraction du corps — n'importe quelle taille, la pastille miniature
comprise) : même écrin, même liseré, même chambre. La famille reste UNE
famille.

**03 — HIIT PEAK.** Surtout pas un graphe cardio. **La ligne de vitesse** :
une ligne horizontale de minuscules segments à 45 % de la hauteur — la
grammaire de `CardBarre` (rails sombres + segments laqués) COUCHÉE. La
meilleure portion est plus dense et plus lumineuse : les segments du pic
sont plus hauts, plus serrés, et montent vers le blanc (rampe **en
canaux** — on éteint le bleu puis le vert — jamais un `mix`, la loi
anti-brun). Sous la ligne, le chiffre : `17.0 km/h` en dégradé métallique
(#FFFFFF → #DCDCDC, celui des cards), et `4 × 40 s` en gris #949392.
Chambre à l'appui : `17.0 km/h · 40 s · ×4`, très sobre.
⚠️ Je challenge le brief sur UN mot : des segments « de verre » à cette
taille sont interdits par une loi payée (à 9 pt un verre ne rend rien de
lisible — le refus des cinq points, § 2.3 du plan home ; et N verres =
N passes). Les segments sont PEINTS, laqués comme ceux de `CardBarre` —
même lecture, zéro passe.

**04 — PEAK EFFORT** (choisi contre Training Density — je suis d'accord :
un highlight humain bat un score abstrait, et le widget change de visage
chaque semaine ; Training Density reste au § 12 en plan B). Le highlight
de la semaine, peu importe le type :

```
PEAK                    PEAK
17.0 km/h        ou     Hip Thrust
40 sec × 4              +10 kg
```

Le design : **une seule forme liquide noire au centre** — un galet
organique peint (l'école `galetMedaillon` : un shader qui peint son
cristal, brille sur tout fond), presque invisible au repos, qui **attrape
un reflet blanc quand un nouveau peak est détecté** — un liseré PAR
ÉVÉNEMENT (la loi du médaillon à flamme : le liseré neutre, allumé par les
événements), qui traverse la forme en 1,2 s puis meurt.
⚠️ Je challenge la « quasi-invisibilité » : à côté de deux cards denses,
un widget presque vide se lit comme un bug. La forme reste discrète, mais
le PEAK et sa valeur vivent en encre pleine (sur-titre 11 pt tracking 2,4
+ valeur en dégradé métallique) — c'est un widget de données qui a un
secret, pas un secret qui cache ses données.

**Pas de doublon** : le widget déjà posé sur l'AUTRE slot n'apparaît pas
dans la vitrine. Le carousel montre donc 3 choix (ou 4 si un slot est
fantôme), centré au départ sur le widget actuel.

---

## 5. LES DONNÉES — l'état vrai, mesuré le 22-08

Le modèle (`Models.swift`) : `Workout → LoggedExercise → StrengthSet
(reps, weight, isDone, durationSeconds) / CardioPhase (kind, seconds,
speed, incline, cycleIndex, order)`. Ce qui en sort :

| widget | calculable aujourd'hui ? | avec quoi |
|---|---|---|
| Régularité | **OUI** | `startedAt` + weekday (le pattern de `CalendarView:18-28`) |
| Volume | **OUI** | Σ `totalVolume` sur la semaine (le pattern de `ProgressionView:93-98`) |
| HIIT Peak | **PARTIEL** | vitesse/durée/`isEffort`/cycles existent ; les répétitions s'INFÈRENT en matchant (kind, speed, seconds) à travers les `cycleIndex` |
| Peak Effort | **PARTIEL** | `maxWeight` hebdo vs max historique antérieur (le pattern de `ProgressionView:120-130`) ; meilleure vitesse idem |

**Les trois trous, et comment on vit avec :**
1. **`CardioPhase` n'a AUCUNE notion de réalisé** (pas d'`isDone`, pas de
   vitesse mesurée — tout est le plan saisi). Décision proposée : **v1
   calcule sur le PLAN des séances TERMINÉES** (`endedAt != nil`) — une
   séance finie vaut exécution de son plan. Honnête pour un widget ;
   l'extension `isDone` cardio est un chantier modèle séparé (et le sync
   Supabase n'a pas non plus ces colonnes — `SupabaseSync.swift:30-49`).
2. **`totalVolume`/`maxWeight` ignorent `isDone`** — et le demo data n'a
   AUCUN set `isDone` (un filtre strict afficherait 0 en `-demoData`).
   Décision : v1 compte les séances terminées sans filtrer `isDone` ;
   trancher le filtre au jalon E5, avec le demo data enrichi.
3. **`speed` n'est pas homogène** : l'escalier stocke un NIVEAU machine,
   pas des km/h. HIIT Peak filtre `.intervals` (+ `.steady` tapis pour le
   cas « 15.1 km/h · 5:08 continuous ») et exclut l'escalier.

**La forme du score HIIT Peak** (à fouetter à E5, la forme d'abord) :
groupes de phases `isEffort` identiques (kind, speed, seconds) dans un
exercice → `reps` = leur compte à travers les cycles → score =
`vitesse × secondes × reps`, départage à la vitesse. Un `.steady` concourt
comme un groupe ×1. **Peak Effort** : trois candidats (Δcharge sur un
mouvement / meilleure vitesse HIIT / volume hebdo record), priorité
charge > vitesse > volume — l'ordre exact se fouette sur le demo data.

**L'architecture des calculs** : une struct **`SemaineStats`** calculée
dans des vues FEUILLES à entrées stables — jamais un `@Query` + `reduce`
dans le body de `HomeNuitPage`, qui vit sous une TimelineView 60 Hz (le
piège « la page ré-évaluée par image »). Et **`Goal.hebdo` partout** :
`HomeAuroraView`/`HomeView` lisent encore `weeklyTarget` figé à 5
(`Models.swift:452` réclame déjà la correction) — les widgets ne recréent
pas la divergence.

**Le demo data doit être enrichi à E5** (deux vices mesurés) : aucun set
`isDone`, et les phases appariées `cycleIndex = i/2` — des paires
arbitraires qui ne sont pas des cycles répétés. Il faut de VRAIS cycles
(même cycle × N) et un record hebdo visible (le +5 kg hip-thrust existe
déjà entre J−14 et J−4).

---

## 6. LA PERSISTANCE

Deux clés `@AppStorage`, le précédent maison étant `Goal.cleHebdo` :

```
widgetSlot0 : String = "regularite"   // regularite | volume | hiitPeak | peakEffort | vide
widgetSlot1 : String = "volume"
```

Un petit `enum WidgetKind: String` porte le catalogue (nom, numéro, la
card, la donnée). `vide` = le fantôme. Pas de doublon (§ 4). L'état
d'ÉDITION, lui, ne se persiste jamais — et il vit dans `HomeNuitPage`,
PAS dans les cards : leurs `@State` sont perdus à chaque démontage
(`verreMonte` les démonte pendant le film de départ,
`HomeNuit.swift:2242/2505`).

---

## 7. LA CHORÉGRAPHIE (les fenêtres sur p)

**Entrée en édition** — `pEdit`, 0,42 s, `timingCurve(0.22,1,0.36,1)` :

| pièce | fenêtre |
|---|---|
| haptic `.rigid` sec | à 0 (au seuil des 0,50 s) |
| zoom arrière (rangée → 0,96) | 0,00 → 0,55 |
| la respiration monte (0 → ±1,4°) | 0,25 → 1,00 |
| pastilles (scale 0,6 → 1,06 → 1) | 0,55 → 1,00, +70 ms card 2 |

**La liste** — `pListe`, 0,34 s : masque depuis la pastille 0 → 0,7 ;
items (fondu + montée 8 pt) 0,45 → 1,00, +55 ms le second.

**La vitrine** — `pVitrine`, 0,62 s :

| pièce | fenêtre |
|---|---|
| retrait du mobilier + scrim 0,30 | 0,00 → 0,50 (la lumière d'abord) |
| le bas se range (galet, slider, invite, fumée) | 0,00 → 0,35 |
| le vol du widget slot → centre | 0,15 → 0,85 |
| les voisins entrent des flancs (x ±40 → pose, flou 6 → 2,6) | 0,55 → 1,00 |
| le nom sous le centre | 0,80 → 1,00 |

Sortie (confirm) : miroir, mais les voisins partent EN PREMIER (fenêtre
0 → 0,25), l'élu vole 0,15 → 0,80, le retrait se relâche 0,45 → 1,00.

**Les haptiques** (le silence en fait partie) :

| moment | recette |
|---|---|
| seuil d'édition | `.rigid` sec |
| pose sur pastille / item | `.soft` |
| cran de la vitrine (centre change) | `UISelectionFeedbackGenerator` |
| confirmation | `CommitHaptic` (3 coups montants) |
| refus min-1 | `RefusalHaptic` (2 rigid à 90 ms) |
| suppression | `.soft` puis rien |
| fermeture / repose | **rien** |

**Reduce Motion** : pas de respiration (les pastilles arrivent en fondu,
les cards restent droites — le mode se lit aux pastilles seules), vitrine
en fondus croisés 0,25 s sans vol ni crans animés (le snap reste), pas de
parallaxe. Le chemin court existe partout dans la page (`HomeNuit:719`).

---

## 8. L'ARCHITECTURE ET LES PIÈGES

**Fichiers** :
- `Woop/Views/WidgetEdition.swift` — neuf : l'état (`enum EditionEtape`),
  la pastille (Medaillon+lune), la drop-list, la pop-up de refus, la
  VITRINE (l'hôte overlay, le carousel, le vol), les bancs ;
- `WidgetsCards.swift` — s'étend : `CardHiitPeak`, `CardPeakEffort`,
  `CardFantome`, `WidgetKind`, et `CardsRangee` apprend à lire les slots
  et à remonter les événements (l'état d'édition vit AU-DESSUS) ;
- `HomeNuit.swift` — se branche : guards du tirage, `retrait =
  max(..., vitrine)`, l'overlay vitrine à côté de `DepartPanneauHote` ;
- corriger au passage : le `contentShape(cornerRadius: 26)` HARDCODÉ des
  cards (l.505/747) — faux à toute autre taille que 170.

**Les pièges convoqués** (chacun déjà payé, source entre parenthèses) :
1. `onLongPressGesture` vole le tap → tout tient dans les
   `DragGesture(minimumDistance: 0)` existants (WidgetsCards:749).
2. Le verre natif ignore `.opacity` → DÉMONTER (`if p > 0.01`), révéler
   par masque à taille constante (MenuCouronne:518).
3. Bounds vivants = flou plat définitif → aucune taille de verre
   n'anime jamais ; transforms seulement (mémoire projet).
4. L'encre au-dessus du CONTENEUR, jamais dedans (le chiffre-trou).
5. Pas de `.blur` plein écran par image ; la vidéo ne recule JAMAIS
   (HomeNuit:1626, 1813) → le retrait de MenuHote est LE mécanisme.
6. Deux `withAnimation` sur la même valeur = rien ne joue → les
   aller-retours (pose de pastille, pulse) en `keyframeAnimator`.
7. Rampes échelonnées sous `withAnimation` ne jouent qu'au doigt → les
   cascades vivent dans des `View, Animatable` (l'école PhraseVue).
8. La page vit sous une TimelineView 60 Hz → aucun `@State` écrit par
   image depuis la vitrine ; horloges locales pausables.
9. Un `Color.clear` parmi des `.position` n'attrape pas les gestes →
   les zones de tap de la vitrine ont un cadre forcé.
10. Blur sur verre natif = deux passes, plafond 6 pt (HomeNuit:2249) —
    les voisins du carousel sont PEINTS, le flou vit sur eux.
11. Le sim n'a AUCUNE haptique et ne sait ni long-press ni drag → les
    bancs auto dès le premier jour (§ 10) ; vérifier les noms de flags
    contre `WoopApp.swift:142-149` (la leçon `-menuRejoue`).
12. `xcodebuild | grep` masque l'échec → `stat` du dylib avant capture ;
    et une autre session édite ces fichiers → committer par chemins, ne
    stager que ses hunks (la méthode gravée le 22-08).

---

## 9. CE QUE JE CHALLENGE (invité par le brief)

1. **Les segments « de verre » du HIIT Peak → peints** (loi des 9 pt +
   une passe par verre). Même lecture, zéro coût, cohérence avec
   `CardBarre`. (§ 4)
2. **Peak Effort « presque invisible » → discret mais lisible** : la
   forme liquide garde son mystère, l'encre garde les données. (§ 4)
3. **La pastille en verre natif → `Medaillon` peint** : un `.clear` de
   22 pt sur un coin noir est à jeun ; le bol peint EST le rendu
   « Liquid Glass noir » voulu, garanti sur tout fond. (§ 3.3)
4. **« S'enfonce dans le noir » → scrim 0,30, jamais noir total** : le
   verdict « l'écran noir non ! » tient, et le widget central a BESOIN
   que la vidéo vive dessous pour que son verre mange. (§ 3.6a)
5. **Le brief n'avait pas de chemin d'AJOUT** après suppression → le
   fantôme de slot, grammaire déjà validée sur la semaine. (§ 3.5)
6. **L'aperçu-chambre actuel entre en collision avec le long press** →
   il meurt sur la home, renaît dans la vitrine. (§ 3.1, arbitrage A)

---

## 10. LES JALONS (un commit, un banc, un verdict téléphone chacun)

| # | ce qu'on juge | bancs |
|---|---|---|
| **E1** | l'entrée en édition : respiration + contre-rotation du liseré + zoom arrière + pastilles | `-editWidgets` (le mode ouvert au lancement), `-editFige <p>` |
| **E2** | la lune et la liste : drop-list, mise au point, suppression → paillettes → fantôme, le refus min-1 | `-editListe <0|1>`, `-editRefus`, `-editVide` (un slot fantôme) |
| **E3** | les deux widgets neufs, matière seule (données de banc) : la ligne de vitesse, la forme liquide + le reflet-événement | `-widgetHiit`, `-widgetPeak` (dans l'école `-cardsLab`) |
| **E4** | LA VITRINE : le vol, les crans, le reflet blanc, la chambre à l'appui, confirm/annule | `-vitrineLab <widget>`, `-vitrineAuto` (scrub en boucle — le sim ne drague pas) |
| **E5** | les données vraies : `SemaineStats`, `@Query`, demo data enrichi (cycles réels + isDone), `Goal.hebdo` unifié | verdicts sur `-demoData` |
| **E6** | le verdict téléphone : les haptiques (invisibles au sim), la cadence, les noirs OLED, la batterie | `SondeCadence` |

E1 → E2 → E4 se jugent avec les cards ACTUELLES (le mode édition n'attend
pas les widgets neufs) ; E3 et E5 peuvent se glisser en parallèle.

---

## 11. LES ARBITRAGES À RENDRE PAR KATHRYN

| # | question | ma recommandation |
|---|---|---|
| **A** | L'aperçu-chambre à l'appui tenu (actuel) meurt-il au profit du long press d'édition ? | **oui** — tap = chambre, 0,50 s = édition, l'aperçu renaît dans la vitrine |
| **B** | Après suppression : slot fantôme avec `+` (et tap → vitrine), ou le survivant seul ? | **le fantôme** — grammaire de la semaine, et c'est le chemin d'ajout |
| **C** | Doublons : le widget déjà posé sur l'autre slot apparaît-il dans la vitrine ? | **non** — exclu, le carousel n'offre que le possible |
| **D** | La langue de la drop-list et du refus : les cards parlent anglais, la page français | **anglais** (`Change / Remove`, `Keep at least one widget`) — la zone widgets est déjà anglaise, et le parcours a basculé le 22-08 |
| **E** | HIIT Peak v1 sur le PLAN des séances terminées (pas de « réalisé » cardio dans le modèle) ? | **oui** — l'extension `isDone` cardio est un chantier modèle+sync séparé |
| **F** | Le seuil du long press : 0,50 s (vif) ou 0,65 s (sûr) ? | **0,50 s** avec tolérance 10 pt — à fouetter au téléphone à E6 |
