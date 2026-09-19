# LA BALISE DE L'ÎLE — « amène la bulle ICI » (17-09, plan, RIEN CODÉ)

Sa demande, en deux temps le 17-09 :
1. *« Sur la page blanche avec le galet qu'on doit amener en haut de l'écran, mets des
   flèches, les users sont perdus, ils ne captent pas qu'il faut le monter tout en haut —
   très minimal, élégant. »* → trois chevrons posés (commit 6d21a26), puis son verdict
   après l'avoir vu : *« ils doivent rester plus longtemps, limite jusqu'à ce que le user
   mette tout en haut ; plus petits ; un geste très léger du doigt pour montrer qu'il faut
   l'amener en haut ; en gris dégradé. »* → chevrons v2 POSÉS dans l'arbre, non commités,
   non lancés (§1).
2. *« Limite un petit design derrière le Dynamic Island pour faire comprendre qu'il faut
   l'amener ici — très premium. »* → ce plan (§2-§5), sur son « fais un plan, ne code pas,
   ne build pas, tu lanceras sur simu après ».

## 0. L'écran, tel qu'il est (LiquidLensLab.swift, `whiteWorld` l.407-485)

Papier crème (0,956 / 0,952 / 0,942) + grain ; le nom de l'exercice à y = 0,42 h ; la
BULLE de verre liquide (shader `liquidLens`, un cœur de braise) posée au bord bas ; le
doigt la tire vers le haut (`climb` 0 → 1). « Start Training » apparaît à 0,60 h pendant
la montée. Le sommet (`fingerMoved` l.793) s'arme à **climb ≥ 0,985** : la bulle plonge
dans la nuit, le cadran de la série descend du bord haut (`SummitCine`). Le Dynamic
Island (iPhone 15 : capsule 126 × 37,3 pt à 11 pt du bord haut, `IleGeo`, centre
y ≈ 29,7) est la destination : dans l'app, la pastille de séance vit DANS l'île.

Repères mesurés par les designers (w 393, h 852) : le bord haut de la bulle est à
y ≈ 250 à climb 0,55 (elle couvre les chevrons), 136 à 0,70, **elle touche l'île à
0,82**, la recouvre à 0,90 — et le sommet ne s'arme qu'à 0,985 : **≈ 100 pt de doigt
sur une île déjà couverte, où rien ne se passe** (§4, Q1).

Lois : aucune horloge nouvelle (la page a sa `TimelineView` 60 Hz, `t` est là) ; on anime
des valeurs, on ne redessine pas ; jamais un rayon de flou animé ; pas de verre sur du
papier ; tout est fonction pure de `t` et `climb` ; ce qui est SOUS le `layerEffect` est
réfracté par la bulle (le titre, les chevrons), un overlay ne l'est pas.

## 1. Les chevrons v2 (posés dans l'arbre, à montrer au simu)

`montee(t:climb:w:h:)` : trois `chevron.up` de **10 pt** (13 avant), **15 pt d'écart**
(22 avant), en **gris dégradé** (`LinearGradient` white 0,30 → 0,62, bas → haut : l'encre
s'éclaircit vers là où ça va), à y = 0,33 h. **Le geste** : le trio glisse vers le haut de
16 pt en 1,7 s (montée lissée), naît et s'éteint en douceur aux deux bouts (`sin(πu)`),
chaque chevron s'allume un peu après celui du dessous — la trace d'un doigt qui pousse.
**Visibles jusqu'au sommet** : `1 − sstep(0,85, 1,0, climb)` (avant : éteints dès 0,45).

## 2. Les trois propositions (un workflow : trois designers, deux juges)

| | l'idée | juge « école Apple » | juge « Kathryn » |
|---|---|---|---|
| **P1 Le Berceau** | l'île est une PRISE creusée dans le papier : une ombre ambiante sans contour derrière l'île (sous le grain), qui respire à peine au métronome des chevrons, s'ouvre à l'approche, et une lueur tiède au contact | 38/50 — premium et minimal, mais **on le sent, on ne le voit pas** : un creux dit « un objet est là », pas « amène-la ici » | 38/50 — même verdict ; et la lueur orange sur le crème vire beige |
| **P2 L'écho** | toutes les 3,4 s (= 2 × la poussée des chevrons), l'île exhale UN écho : un fil gris de la forme exacte de la capsule, hairline, qui s'élargit de 44 pt vers le bas et s'éteint — Apple Pay « Hold Near Reader » ; à l'approche l'écho revient s'amarrer contre l'île (« ici » devient « viens ») | 37/50 — clair, mais **c'est un TRAIT** sur une page de matière ; risque « seconde île » quand la lentille le grossit | **43/50, gagnant** — la seule qui montre l'île ; risque à trancher sur capture |
| **P3 La goutte** | l'ombre de l'île (le siège) + toutes les 3,4 s une goutte d'ombre qui file en accélérant le long d'un fuseau et disparaît sous l'île, qui la reçoit d'un « toc » (le docking de la Dynamic Island) | **39/50, gagnant** sans son fuseau | 38/50 — trois choses, dont un fuseau de 180 pt sur le crème : une traînée |

Les deux juges convergent sur quatre points, et c'est ça le design final :
- **le siège** (de P1) : une ombre ambiante derrière l'île, sous le grain — c'est « le
  petit design derrière le Dynamic Island », littéralement ;
- **un appel de l'île, verrouillé en phase avec les chevrons** (une poussée du doigt sur
  deux, l'île répond) — l'écho de P2 ou la goutte de P3 ;
- **l'aimantation à l'approche** (de P2) : le signal cesse d'appeler et revient se serrer
  sur l'île ; rien ne « valide » avant le VRAI sommet ;
- **aucune couleur sur le papier** : la seule chaleur est la braise que la bulle porte
  déjà, au sommet.

## 3. La recommandation — LE SIÈGE + L'ÉCHO

Je recommande l'écho plutôt que la goutte : elle a demandé « un petit design DERRIÈRE
le Dynamic Island », pas quelque chose qui traverse la page ; le chemin, ce sont déjà les
chevrons ; et l'écho est la grammaire Apple exacte de « approche ici » (Apple Pay). La
goutte reste la variante si l'écho se lit « double île » à la capture.

**Le siège** — `Ellipse().fill(EllipticalGradient)` 206 × 96 pt, `Color(white: 0,20)`,
arrêts [α 0,11 @ 0 ; 0,075 @ 0,36 ; 0,022 @ 0,70 ; clear @ 1], centrée sur x = w/2,
5 pt SOUS le centre de l'île (la lumière vient du haut, l'ombre se ramasse dessous) ;
posée **sous le grain** (entre `Self.paper` et `WoopGrain`) — le grain vend la matière et
casse toute bande. Au repos : opacité × (0,86 + 0,14 · s), s = souffle calé sur le `u` des
chevrons (au sommet de leur poussée, le creux s'enfonce d'un rien). L'île devient un
objet POSÉ dans le papier, une place vide qui attend.

**L'écho** — UNE `Capsule().strokeBorder` concentrique à l'île, cadre FIXE (214 × 125),
inset animé (la forme s'ouvre de 44 pt vers le bas en 2,4 s puis 1 s de silence), trait
0,9 → 0,5 pt, `LinearGradient` gris 0,42 (bas) → 0,72 (haut), opacité pic ≈ 0,40 (à
trancher sur SON téléphone au soleil), période **3,4 s = 2 × 1,7 s** verrouillée en
phase : l'écho naît à l'instant où une poussée des chevrons meurt en haut de sa glisse —
le doigt pousse, l'île répond « ici ». Un seul anneau à la fois, jamais deux.

**L'approche** (climb 0,70 → 0,88, `near = sstep`) : l'écho cesse d'être émis et l'anneau
REVIENT s'amarrer à 1,5 pt de l'île, opacité 0,34, trait 0,9 ; le siège se creuse
(× 1,6 d'alpha, `scaleEffect` 1 → 1,22 vers le bas) — l'île inspire, « ici » devient
« viens ». Les chevrons continuent jusqu'au sommet (§1).

**Le sommet** (0,90 → 0,985) : le trait passe 0,34 → 0,54 et tiédit vers la braise
(1,00 ; 0,52 ; 0,14) mixée à 0,45 au plus — la seule couleur, calée sur le VRAI sommet ;
puis `nightFill` avale tout avec le monde blanc (zoom + blur de `SummitCine`) : zéro code
de mort. Si l'anneau grossi dans la lentille se lit « double île » entre 0,82 et 0,90, le
fondre dès 0,90 et laisser le siège + la braise porter l'arrivée.

**Où** : sous le `layerEffect`, dans `whiteWorld`, deux `private func` nommées après
`montee` (`siege(...)`, `echo(...)`), `.allowsHitTesting(false)`. **Coût** : par image,
une ellipse à dégradé constant sous une opacité, une capsule en trait sous une opacité,
six scalaires — pas de flou, pas de masque, pas de `blendMode`, pas de `compositingGroup`
nouveau, pas d'horloge. **Barreau** : `-sansBalise` (la loi : tout moteur arrive avec de
quoi l'accuser).

## 4. À trancher (mes recos en premier)

| | question | reco |
|---|---|---|
| **Q1** | **La mécanique du sommet** : la bulle touche l'île à 0,82, la recouvre à 0,90, et le sommet ne s'arme qu'à 0,985 — cent points de doigt où rien ne se passe. Abaisser le seuil de `fingerMoved` (l.793) à ~0,90 pour que « la bulle couvre l'île » SOIT le sommet ? | **oui** — les deux juges le disent : c'est probablement l'autre moitié du « ils ne captent pas », et aucun dessin ne la remplace |
| **Q2** | L'écho (le fil qui s'élargit) ou la goutte (l'ombre qui file se docker) ? | **l'écho** — c'est derrière l'île, comme demandé ; la goutte traverse la page |
| **Q3** | L'écho : un seul, toutes les 3,4 s, en phase avec les chevrons ? | **oui** — une poussée du doigt sur deux, l'île répond |
| **Q4** | La chaleur : uniquement au vrai sommet (0,90 → 0,985), jamais au simple contact ? | **oui** — on ne récompense pas un non-sommet |
| **Q5** | Les chevrons v2 (§1) : à montrer tels quels au simu, ou déjà un réglage ? | **tels quels**, verdict à la capture |

## 5. L'ordre

Ton verdict → le code (`siege`, `echo`, le barreau, Q1 si oui) → build simu → captures
`-lensFreeze 0,00 / 0,60 / 0,78 / 0,86 / 0,95` (la page figée à ces montées) + un film du
repos (les chevrons qui poussent, l'écho qui répond) → montré → ton verdict → A/B sur ton
téléphone (thermique 0) avant tout mot sur la chauffe → commit sur ton ordre.
