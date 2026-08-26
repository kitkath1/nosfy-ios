# LE VARIANT 2 REFAIT — « You Made It » : le texte travaillé, le spotlight, le chiffre de VERRE

**Écrit le 26-08-2026 sur le brief et la réf de Kathryn — RIEN n'est
codé.** Précision d'elle le 26-08 au matin : ce design remplace **LE
VARIANT 2** — la card « type Apple » (l'actuelle robe néon réf WWDC,
la brume diluée). **La robe néon MEURT**, remplacée par ce design.
(Le variant 4 « matrice » est un sujet SÉPARÉ : recalé lui aussi, son
sort — retravail ou mort — reste à trancher, voir §À trancher.)

## La réf, décomposée (l'image « You Made It »)

1. **La lampe** : un petit plafonnier-barre accroché au bord HAUT de la
   card (l'objet se voit : une barrette sombre), avec son éventail de
   lumière blanche qui S'OUVRE vers le bas — court, doux, réaliste.
2. **LE TEXTE DERRIÈRE, TRAVAILLÉ** : trois rangées de mots ÉNORMES
   (« You / Made / The ») qui remplissent toute la card, rognés par les
   flancs. Matière : un gris-argent métallique, ÉCLAIRÉ PAR LA LAMPE —
   la rangée haute est claire (elle prend le cône), les rangées
   descendent dans l'ombre, les pieds meurent dans le noir. Un léger
   dégradé vertical DANS chaque lettre. C'est de la typo mise en
   lumière, pas un effet.
3. **LE CHIFFRE DE VERRE** : le « 4 » du résultat en VERRE MASSIF
   transparent, posé DEVANT le texte — bords épais, rondeurs de blob,
   dispersion chromatique sur les arêtes (les liserés orangés/bleus de
   la réf), le texte derrière se DÉFORME à travers lui. Police
   ultra-arrondie et grasse.
4. **Le sous-titre** en bas, petit et calme (« A new milestone has been
   reached. »).

## Ce qu'on construit (les moyens de la maison)

### A. Le chiffre de verre — LE VRAI, natif, et SAISISSABLE

L'idée clé : **le glyphe devient une Shape** (le contour du chiffre via
CoreText, `CTFontCreatePathForGlyph` → `Path`), et cette shape reçoit
`glassEffect(.clear.interactive(), in: FormeChiffre)` — le VRAI Liquid
Glass d'Apple DANS la silhouette du chiffre. Le texte géant derrière est
alors RÉELLEMENT réfracté par le verre du chiffre (le même mécanisme,
prouvé, que le galet sur le 4). Police du glyphe : SF Rounded black (la
rondeur de la réf).

- **Saisissable comme le galet** (le brief) : la recette GaletVerre
  recopiée — DragGesture min 0, dérive lissajous discrète + gyro,
  haptique prise/lâcher, ressort au lâcher SUR LE MODIFICATEUR (la
  leçon). Le chiffre-verre qu'on promène sur le texte, et le texte qui
  ondule à travers : c'est LE moment de la card.
- La dispersion chromatique de la réf : le verre natif en donne un peu ;
  si le verdict la veut plus riche, un liseré arc-en-ciel TRÈS fin
  (gradient conique masqué au bord de la shape) — jamais un shader
  freestyle (le stitchable a ses pièges payés).
- 2 chiffres (« 12 ») : deux glyphes → un Path composé ; la shape se
  recalcule au changement de valeur, PAS par frame (bounds constants
  pendant le geste — la loi du verre).
- Le count-up : le glyphe change pendant la montée (le Path se refait à
  chaque valeur — 4-5 recalculs, pas 60/s) ; le verre garde son cadre.

### B. Le texte géant — la typo mise en lumière

- Trois rangées max (ex. « YOU / MADE / IT », ou 2 rangées + le mot
  contextuel), `fixedSize`, rognées par les flancs, en `background` hors
  layout (la fente ne gonfle pas), clip card constant.
- Matière : argent sombre (blanc 0,35 → 0,10 par rangée descendante),
  ET le CÔNE fait la lumière : un masque-gradient conique descendant de
  la lampe éclaire la rangée haute plus fort — la lumière est UN SEUL
  champ partagé (lampe → texte → sol), jamais trois effets séparés.
- Les mots : à TRANCHER — fixes (« YOU MADE IT ») ou contextuels (le
  fait raconté : « NEW / BEST / SET »). Reco : contextuels plus tard
  (l'IA du plan backend les fournira), fixes au banc.

### C. La lampe et son éventail

- La barrette : un petit rectangle sombre arrondi collé au bord haut
  (dans la réf elle CHEVAUCHE le bord — à oser : elle mord sur le
  liseré), liseré fin.
- L'éventail : un trapèze COURT et doux (pas le grand cône de la V1) —
  dégradé blanc 0,5 → 0 sur ~90 pt, flancs fondus au masque horizontal
  (jamais d'arête franche : la loi des stries), un souffle de bloom à la
  bouche. Il n'éclaire pas tout : il POSE la lumière sur la crête du
  texte, le reste vit du dégradé du texte lui-même.
- Gyro : l'éventail oscille d'1° — un murmure.

### D. Le squelette commun

Scrim, dalle, verre, voile SOMBRE partout (la nuit gagne — la leçon de
la V1 laiteuse), header standard REMPLACÉ ? — à trancher : la réf n'a
NI titre ni congrats en haut (le texte géant EST le message) ; reco :
en spotlight V2, le bloc titre/sous-titre du haut disparaît, seul le
sous-titre bas reste. Close inchangé. Poudre : non (la nuit nue).
L'entrée : fondu noir commun, puis la lampe s'allume D'ABORD, le texte
émerge dans sa lumière, le chiffre de verre SE POSE en dernier (scale
0,94 → 1), count-up dedans.

## Les pièges déjà payés qui s'appliquent

- Bounds du verre CONSTANTS (jamais de resize animé) ; le drag est un
  offset ; le ressort sur le MODIFICATEUR.
- La fente (texte débordant en background hors layout, clip constant).
- L'encre au-dessus du verre… ici INVERSÉ à dessein : le texte est
  DERRIÈRE le verre — c'est le but (réfraction), pas un accident.
- Le verre rend selon le scheme de SA vue → `.dark` forcé.
- Pas de nappe pleine > 0,5 sur le verre (frost).
- Nyquist 3× si un grain revient un jour.

## Jalons (une capture validée par Kathryn à chaque pas)

- **T1 — le texte en lumière** : les 3 rangées + la lampe + l'éventail,
  sur la scène nue. (Choix des mots au banc : fixes.)
- **T2 — le chiffre de verre statique** : la shape-glyphe en glassEffect
  posée sur le texte, la réfraction jugée sur capture.
- **T3 — le geste** : drag + dérive + gyro + haptique (recette galet),
  count-up dans la shape.
- **T4 — les finitions** : dispersion si voulue, l'entrée orchestrée,
  le sous-titre, non-régression des 3 autres robes + démo.

## À trancher par Kathryn

1. Les MOTS du fond (fixes ou contextuels — et lesquels au banc).
2. Le bloc titre/congrats du haut : mort dans cette robe (reco — le
   texte géant EST le message) ou gardé.
3. La dispersion chromatique : verre natif nu, ou liseré spectral fin.
4. LE SORT DU VARIANT 4 « matrice » (lui aussi recalé) : retravaillé un
   jour, ou mort — et dans ce cas la rotation revient à 4 robes (galet,
   You-Made-It, halo, + une place libre).
