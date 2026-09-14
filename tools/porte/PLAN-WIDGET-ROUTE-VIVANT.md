# LE WIDGET ROUTE VIVANT — l'état vide et l'état « déjà fait » (le plan, puis le banc)

*14-09-2026, matin · sa commande : « améliore l'UI du widget Commence ton entraînement à
l'état vide et à l'état déjà fait, qu'on ait envie de cliquer dessus ; trouve des micro-
animations pour rendre le composant putain de vivant ; fais un plan et sur un banc montre-moi
ces deux états »*

## 0. Ce que le widget est aujourd'hui (lu, CardRoute.swift)

Une ARDOISE 354 × 138 (`ArdoiseFond`, la même matière que les widgets : noir 0,94, deux
lumières radiales, le grain, un liseré conique 1,6 pt + son flou, et **une lueur de bord**
qui ne s'allume qu'au doigt — `lueur` 0 → 1, deux traits de plus). À gauche, deux lignes :
« CHAPITRE 1 » interlettré gris, et la ligne basse — « Commence ton entraînement » (vierge,
15 pt sur deux lignes) ou « Étape R sur 9 » (l'odomètre). À droite, LA BANDE : les neuf
nœuds du chapitre en `LazyVStack` vertical, fondus aux deux bords, centrés sur aujourd'hui,
qui reviennent à leur place quand on lâche (ressort + haptique). Le galet actif RESPIRE déjà
(le halo de `GaletEtape`, 0,72, sur sa propre horloge — `-sansGalet` la fige). Le tap de la
card entière ouvre la route.

**Ce qui manque pour donner envie** : rien ne bouge au repos hors le halo du galet ; le
texte est posé, sans appel ; rien ne répond au doigt qui se pose (pas de press) ; et l'état
« déjà fait » ne dit rien de ce qu'on vient d'accomplir — c'est le même widget avec « 2 » à
la place de « 1 ».

## 1. LA DIRECTION — trois lois, puis des gestes

1. **Tout est une valeur animée, jamais une horloge** (la loi du 05-09 : redessiner coûte
   3 à 8 × plus qu'animer). Chaque geste ci-dessous est une opacité, une échelle, un offset
   ou une largeur sous `repeatForever` ou un ressort — la phase vit dans une FEUILLE (le
   piège du `repeatForever` avalé par un parent ré-évalué : la card se ré-évalue pendant
   l'arrivée de la page et à chaque phase de scroll).
2. **Le widget appelle sans crier** : la lumière et le mouvement restent dans la grammaire
   de la maison (le liseré, la nacre, le blanc dégradé) — pas de couleur neuve, pas d'icône
   neuve, pas de bouton.
3. **Il répond au doigt** : un objet qu'on a envie de toucher est un objet qui bouge quand
   on le touche.

## 2. LES GESTES — l'état VIDE (« Commence ton entraînement »)

| # | quoi | comment (valeur animée) | période |
|---|---|---|---|
| V1 | **La lampe qui appelle** : le liseré de l'ardoise respire — la lueur de bord qui existe pour le doigt s'allume seule, lentement | `LueurAppel` (feuille) : les deux traits de la lueur en overlay, opacité 0 ↔ 0,42, `repeatForever` | 3,6 s |
| V2 | **Le reflet sur le titre** : une bande de lumière traverse « Commence ton entraînement » de gauche à droite — le « slide to unlock » | `Reflet` (modificateur, feuille) : un dégradé clair / blanc 55 % / clair de 70 pt en overlay du texte, masqué par le texte, `offset x` −L → +L, linéaire, `repeatForever(autoreverses: false)` | 2,8 s |
| V3 | **Le chevron qui invite** : « › » après le titre, qui avance de 3 pt et revient | `offset x` 0 ↔ 3, easeInOut, `repeatForever(autoreverses: true)` | 1,2 s |
| V4 | **L'onde du galet 1** : un anneau naît du galet d'aujourd'hui et s'élargit en s'éteignant — « c'est ici » | `OndeAppel` (feuille) : un cercle stroke 1,5 pt, échelle 0,9 → 2,1, opacité 0,45 → 0 en 1,3 s easeOut, relancé par une boucle async recalée sur l'horloge | 3,8 s |
| V5 | **Le galet 1 respire plus fort** : sa lueur sous lui (`HaloVierge`, déjà écrite — mais posée dans la colonne, pas dans la bande : on la déplace dans la bande) | opacité 0,10 ↔ 0,34, échelle 0,92 ↔ 1,04 | 2,6 s |
| V6 | **« CHAPITRE 1 » plus présent** : le sur-titre passe de gris 0,52 à 0,66 dans l'état vide | constant | — |

## 3. LES GESTES — l'état DÉJÀ FAIT (une séance finie, « Étape 2 sur 9 »)

| # | quoi | comment | période |
|---|---|---|---|
| F1 | **Le trait de progression** : sous « Étape 2 sur 9 », un fil de 2 pt (blanc 14 %) et sa part faite (blanc 90 % + une lueur) qui S'ÉTIRE à l'arrivée — 1/9, 2/9… c'est le premier pas qu'on voit | `TraitProgres` (feuille) : largeur 0 → 152 × rang/total, ressort 0,7 / 0,8, 0,5 s après l'arrivée | une fois |
| F2 | **L'éclat du galet fait** : le dernier galet accompli reçoit une onde brève et blanche (l'éclat d'un objet qu'on vient de poser) | `EclatFait` (feuille) : un anneau 2 pt, échelle 0,8 → 1,9, opacité 0,7 → 0 en 0,9 s, une fois, 0,9 s après l'arrivée | une fois |
| F3 | **Le galet d'aujourd'hui respire** (existant) et **l'onde d'appel** revient, plus rare — le prochain pas | `OndeAppel`, période 6 s | 6 s |
| F4 | **L'odomètre qui roule** (existant, `.numericText()`) quand l'étape avance | — | — |

## 4. LES GESTES — les deux états

| # | quoi | comment |
|---|---|---|
| T1 | **Le press** : le doigt se pose → la card recule à 0,982 et sa lueur de bord s'allume (celle du scroll), ressort 0,32 / 0,72 ; il se lève → elle revient ; haptique légère au contact | `onLongPressGesture(minimumDuration: 10, maximumDistance: 40, pressing:)` — la forme tranchée de la maison (le glyphe de la nav), qui n'affame ni le tap ni le scroll de la bande |
| T2 | **Le tap** ouvre la route (existant) — et il part avec la card déjà en mouvement (le press) : on sent qu'on a appuyé sur quelque chose | — |
| T3 | (téléphone seulement, à mesurer) **la parallaxe** : les galets glissent de ±3 pt avec l'inclinaison (`CarteGyro` de la card reward) | option, pas dans ce banc |

## 5. Le banc — `-duoLab -routeCard vide` / `-routeCard fait` / `-deuxEtats`

`RouteCardLab` gagne deux cas : `vide` (chapitre 1, rang 1, rien de fait = `debut`) et `fait`
(rang 2, le galet 1 accompli avec sa date d'hier), et `-deuxEtats` les empile — les deux
widgets l'un sous l'autre, vivants, sur le noir. C'est là qu'elle juge ; les captures ne
montrent qu'un instant, le banc montre le mouvement.

## 6. Ce que ça coûte
Six valeurs animées `repeatForever` (opacité, échelle, offset) dans des feuilles + une
boucle async (l'onde) + deux gestes une fois (trait, éclat) : rien qui redessine. Le galet
actif garde son horloge existante. À mesurer au téléphone sur la Home (sonde, thermique 0)
— si la card vide coûte > +3 % de processeur, on éteint V2 (le reflet) en premier.

## 7. Aucune question
Elle juge sur le banc, puis sur son iPhone.

## 8. État (14-09, matin) — CODÉ, vu au simulateur, NON commité

Tout le § 2–5 est posé dans `CardRoute.swift` (six feuilles : `LueurAppel`, `RefletTexte`
+ `RefletBande`, `ChevronInvite`, `OndeAppel`, `EclatFait`, `TraitProgres` ; `HaloVierge`
déplacée dans la bande ; `presse` par `onLongPressGesture` ; `dejaFait` / `dernierFait` /
`partFaite`), derrière le barreau **`-sansVieRoute`**. Banc :
`-duoLab -routeCard vide -deuxEtats -skipAuth` (⚠️ sans `-skipAuth` l'écran reste noir —
la porte). Seize images à 0,35 s : l'onde naît et s'éteint sur le galet 14 dans les deux
états, le halo vierge respire, la lampe du bord monte et descend, le trait 1/9 est ouvert.

**Corrigé au banc** : le reflet V2 était INVISIBLE (mesuré : +6 % de luminance au passage)
— une bande blanche sur un texte blanc n'éclaire rien. Le titre de l'état vide passe en
blanc cassé 0,80 et la bande en blanc pur (96 pt, cœur à 1,0) : le glint d'Apple est un
texte gris clair que la lumière traverse.

**Deuxième piège payé au banc** : `.mask(content)` posé directement sur la bande mobile
(96 pt) emportait le masque avec elle — le texte apparaissait DÉDOUBLÉ et glissant (image 3
de la séquence). Remède : la bande dans un cadre plein (la taille de l'overlay = celle du
texte), le masque sur ce cadre. Vérifié sur vingt images à 0,3 s : la lumière traverse les
lettres (« Comme » puis « ton » / « ement »), aucun dédoublement.

**Pas jugeable au simulateur** : le press (T1) — aucun doigt sur cette machine — et le
poids réel de l'onde + halo + lampe sur la Home (à mesurer au téléphone, § 6).

---

# ×10 — LE PLATEAU ET LES MICRO-DÉTAILS (14-09, son verdict : « oui, et anime davantage
# encore le background, le plateau, plus jolie encore ; un plan pour améliorer dix fois plus
# en micro-détails »)

## 9. La direction, en une phrase
Aujourd'hui la card est un objet posé sur lequel des choses bougent. Demain c'est une
MATIÈRE qui vit — de l'obsidienne sous une lampe qui se déplace — et chaque chose qui
bouge dessus est éclairée par la même lumière. Une seule source, plusieurs surfaces :
c'est ce qui sépare « animé » de « vivant ». Tout reste une valeur animée dans une
feuille ; les flous sont construits une fois et DÉPLACÉS, jamais recalculés.

## 10. LE PLATEAU — la matière (chapitre codé en premier, sur son ordre)

| # | quoi | comment | période |
|---|---|---|---|
| P1 | **Les deux flaques qui dérivent** : la lumière chaude du haut-droit et la froide du bas-gauche de l'ardoise ne sont plus posées, elles GLISSENT lentement — la lampe bouge au-dessus de l'obsidienne | `PlateauVivant` (feuille) : deux cercles blancs flous (Ø 250 flou 48 · Ø 180 flou 38, flous CONSTANTS donc en cache), `plusLighter`, 8,5 % et 6 %, `offset` animé sur deux diagonales, coupés par la forme de la card | 13 s et 17 s (premiers entre eux : jamais en phase) |
| P2 | **La lumière qui tourne sur le liseré** : une crête blanche parcourt le contour de la card, lentement, sans fin — le reflet d'une bague qu'on tourne | `LisereTournant` (feuille) : la technique de `LisereRespirant` — un carré de dégradé conique (√2 de la card) qui TOURNE, masqué par le trait du contour (1,4 pt + 5 pt flouté 2,6) ; 55 % à vide, 35 % après | 22 s, linéaire |
| P3 | **Un seul balayage de nacre** : une bande de lumière traverse TOUTE la card en diagonale, et c'est ELLE qui allume le titre au passage — le reflet V2 n'a plus sa propre horloge, il est la trace du même rayon sur les lettres | `NacreTraverse` (feuille, 4,5 %, 150 pt, 18°) + `RefletBande` recalée : même délai, même durée, même période (`Balayage`), le décalage du titre (−100 pt du centre) pris en compte | 6,4 s, traversée 2,4 s |
| P4 | **L'allumage à l'arrivée** : les lumières du plateau ne sont pas là quand la card se pose — elles S'ALLUMENT 0,3 s après (1,4 s, easeIn), comme une lampe qu'on tourne | `allume` 0 → 1 dans `PlateauVivant` | une fois |
| P5 | **Le doigt éclaire** : au press, les flaques montent ×1,6 et la crête du liseré passe à 90 % ; au lâcher, ressort | `presse` lu par les deux feuilles (attribut opacité distinct de la dérive) | — |
| P6 | **Le grain** reste immobile : une texture qui bouge se lit comme du bruit vidéo, pas comme une matière | — | — |
| P7 | (téléphone, plus tard) **la parallaxe** : les flaques et la crête suivent l'inclinaison (±10 pt, `GyroFond`) — l'obsidienne sous une vraie lampe | option, à mesurer | — |

Barreau : **`-sansPlateau`** (P1–P5 seuls), en plus de `-sansVieRoute` (tout). En séance le
plateau n'est pas monté : la card en séance est au chantier du Foyer.

## 11. LE LISERÉ ET LE TEXTE

| # | quoi | comment |
|---|---|---|
| L1 | **La lampe V1 et la crête P2 sont la même lumière** : quand la crête passe au coin bas-gauche (le blanc du conique), la lampe V1 monte — la respiration se cale sur la rotation | la phase de V1 déduite de P2 : période 22/… → à trancher au banc, ou V1 supprimée si P2 suffit |
| T1 | **Le titre arrive mot après mot, dans le flou** (la grammaire de `MotsFlou`, 32 → 15 pt), une fois, à l'arrivée de la card ; pas de fondu plat | `.fonduFlou` sur « Commence ton entraînement » avec `base` 0,5 s |
| T2 | **Le sur-titre s'interlettre au press** : « CHAPITRE 1 » passe de 1,6 à 2,2 de kerning quand le doigt se pose (l'objet respire) | `kerning` n'est pas animable → un `Text` en `Animatable` sur le tracking, ou deux textes fondus ; à trancher |
| T3 | **La pointe du trait** (F1) : un point de 4 pt au bout de la part faite, qui respire (2,2 s) — c'est là que tu en es | feuille `PointeTrait` |
| T4 | **L'odomètre s'illumine** quand il roule (« 2 » → « 3ent ») : les chiffres arrivent avec une lueur qui s'éteint en 0,8 s | `.contentTransition(.numericText())` + un overlay blanc flou constant sous opacité, déclenché par `onChange(of: apercu.rang)` |
| T5 | **Le chevron V3 devient une flèche qui « tire »** au press : il avance de 6 pt et revient au lâcher (le geste dit « ça part par là ») | `presse` lu par `ChevronInvite` |

## 12. LES GALETS ET LA BANDE

| # | quoi | comment |
|---|---|---|
| G1 | **L'onde est double** : deux anneaux à 0,35 s d'écart, le second plus fin (1 pt) — de l'eau, pas un radar | `OndeAppel` : un second cercle sur la même boucle, décalé |
| G2 | **Le galet suivant respire à peine** : la flamme du « prochain » (rang +1) monte de 0,50 à 0,62 d'opacité sur 5 s — ce qui vient après existe déjà un peu | feuille sur le galet `prochain` de la bande ; `GaletEtape` non touché (partagé) |
| G3 | **Les galets s'approchent en grandissant** : dans la bande, un nœud à 0,92 aux bords et 1,0 au centre, porté par le défilement (aucune horloge : la valeur est la position de scroll) | `.scrollTransition { c, phase in c.scaleEffect(1 − 0,08·|phase.value|) }` |
| G4 | **Le recentrage éclaire** : quand la bande revient à aujourd'hui (ressort 0,55 s), le galet du jour reçoit un éclat court (le même que F2, 0,5 s) | `EclatFait` réutilisée, déclenchée par `recentrages` |
| G5 | **Le galet fait porte la lumière du plateau** : quand la flaque chaude passe sur lui (P1), sa date s'éclaire de 0,55 → 0,72 — même lampe, autre surface | dérive P1 lue par la feuille du galet (une opacité) ; à trancher sur capture |
| G6 | **La date du jour « 14 » vit** : à l'arrivée, elle roule d'un cran (odomètre) comme si la page tombait sur aujourd'hui | `.numericText()` + valeur de départ « 13 » pendant 0,4 s ; petit, mais c'est le détail qu'on remarque |

## 13. LE DOIGT, L'ARRIVÉE, LA TRANSITION D'ÉTAT

| # | quoi | comment |
|---|---|---|
| D1 | **Le tap qui ouvre** : la card recule à 0,982 (press), puis au lâcher elle AVANCE à 1,012 pendant 0,18 s avant que la route s'ouvre — on sent qu'on a appuyé sur quelque chose ; haptique `doux` | `onTap` enveloppé : `withAnimation` puis appel après 0,18 s |
| D2 | **La cascade d'arrivée** (0 → 2,5 s) : la card se pose (0,4) → les lumières s'allument (0,3 → 1,7) → le titre mot après mot (0,5 → 1,3) → le trait s'étire (0,5) → l'éclat du galet fait (0,9) → la première onde (1,2) → le premier balayage (1,0 → 3,4). Un ordre, pas un tas | les délais existants alignés sur cette partition ; à jouer au banc `-avance` |
| D3 | **Vide → déjà fait** (la première séance vient de finir) : la lampe V1 s'éteint (0,6 s), l'odomètre roule « — » → « 2 », le trait pousse de 0, le galet 1 reçoit l'éclat, l'onde passe à 6 s. Aujourd'hui la card est DÉMONTÉE par le film de départ, donc la plupart se joue gratis au remontage — à vérifier avec `-avance` (rien de codé pour ce passage) | `-duoLab -routeCard vide -avance` comme juge |
| D4 | **Reduce Motion** : chaque feuille se fige à sa valeur médiane (déjà), le plateau reste allumé mais immobile | — |
| D5 | **Le son** : rien au repos, jamais. Le tap = `NosfySon.tic()` (le même que la visite) avant que la route s'ouvre | — |

## 14. Ce que ça coûte, et comment on le saura
Le plateau ajoute deux flous constants déplacés, un carré conique tourné sous masque, une
bande sous `plusLighter` — trois calques de plus composés à chaque image sur la Home.
C'est exactement le genre de chose que la loi du 05-09 autorise (animer, pas redessiner)
et exactement celui qu'on ne croit pas sans chiffre. Campagne au téléphone, thermique 0,
Home immobile, ABBA : `-sansVieRoute` contre rien, puis `-sansPlateau` contre rien ; on
publie (cadence, processeur). Si le plateau coûte > +4 % de processeur : P3 (le balayage)
s'éteint d'abord, puis P2 passe à 40 s, puis P1 garde une seule flaque.

## 14 bis. État du plateau (14-09, midi) — CODÉ, vu au simulateur, NON commité
P1–P5 posés (`PlateauVivant`, `LisereTournant`, `NacreTraverse`, `Balayage` + `balayer()`),
barreau `-sansPlateau`. Quarante images à ~0,5 s : la lumière du haut-droit dérive (39 → 50
sur 255, contre 34 immobile avant), la crête tourne sur le bord, le balayage traverse et
allume le titre au passage (image 27 : 2 184 pixels blancs dans les lettres, le même
instant où la nacre couvre la moitié gauche du plateau). **Piège payé** : à 8,5 % / 6 % la
card entière devenait GRISE (34 → 59) — l'obsidienne doit rester noire, la lampe ne fait
que passer : 5,5 % / 3,8 %. Posé sur son iPhone (`-skipAuth -welcomePremiere`). Le reste
(§ 11–13) attend son go ; le coût (§ 14) n'est pas mesuré.

**Verdict (14-09, midi) : « non, pas d'effet balayage en background — je pensais une
animation de background jolie et subtile ».** P3 (le balayage de nacre) est RETIRÉ ; le
reflet du titre reprend sa propre horloge (1,5 s / 3,4 s). Restent P1 (les flaques, qui
ERRENT désormais sur deux axes chacune — 13/19 s et 17/23 s, une lampe qui se promène, pas
un pendule), P2 (la crête, 22 s), P4 (l'allumage), P5 (le doigt). La loi qui sort de ce
verdict : **le fond ne fait jamais d'événement** — il dérive, il ne passe pas ; ce qui
« passe » appartient au texte et aux galets.

**Second verdict (14-09, midi) : « refais un plan, là tu changes rien, sérieux ».** Mesuré :
la dérive des flaques déplace la lumière de 7/255 en 20 s — invisible. Un disque flou plus
grand que la card n'a pas de bord, donc pas de mouvement lisible. → Le fond a son propre
plan : **`tools/porte/PLAN-FOND-ARDOISE.md`** (le rayon de lune, la lueur du galet sur
l'ardoise, la profondeur au gyroscope, la crête, la règle « le noir reste noir »). Rien de
codé tant qu'elle n'a pas choisi.

## 15. Ordre proposé
P1–P5 (codé maintenant, sur son mot) → son verdict → G3 + D1 + T3 (un jour) → D2 la
partition (une demi-journée) → G1 G2 G4 T1 T4 (un jour) → mesure → L1, G5, G6, T2, T5, P7
selon ce que la mesure laisse.
