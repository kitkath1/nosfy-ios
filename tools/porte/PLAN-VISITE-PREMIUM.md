# LA VISITE — v4 « LA BRUME » (le plan ; rien n'est codé, sur son ordre)

*14-09-2026, nuit · la suite de PLAN-PREMIERE-ARRIVEE.md § 2 ⑥ · v1 refusée, v2 codée et
notée 0/10 sur son iPhone, v3 (« la lumière », anneaux) jamais codée et écartée par le même
verdict, v4 = ce plan*

## 0. Son verdict sur la v2, au téléphone — mot pour mot, et ce que chaque mot corrige

| elle dit | ce que c'était | ce que la v4 fait |
|---|---|---|
| « j'aime pas les encadrés, ça fait fake, pas naturel » | la fenêtre arrondie + liseré + halo, la card de verre, le bec | **AUCUNE forme** : ni fenêtre, ni trait, ni anneau, ni card. Un dégradé de brume noire floutée sur la Home, et l'objet qui reste net **sans contour** |
| « dégradé de blur noir, dégradé de la Home, la partie entourée moins fake » | — | c'est LA direction : la Home s'enfonce dans la brume, l'objet en sort, la frontière est un fondu de 140 pt, jamais une ligne |
| « tu inventes des boutons : "Claim" n'existe pas, c'est Commencer ou Start » | le Claim est la card **Welcome Back du jour** (30-08), ouverte EN MÊME TEMPS sur son iPhone (compte avec séances → `retour_disponible` vrai ; le banc ne la coupe pas) | **P0** : la première arrivée coupe le Welcome Back ce jour-là (le plan du 13-09 le disait, ce n'était pas fait) ; le CTA de la pop-up devient **« Commencer » / « Start »** ; la visite n'a **aucun bouton** |
| « la partie progrès montre la pop-up, alors que non, c'est le widget » | la fenêtre « progression » a montré la card Welcome Back posée par-dessus les widgets | sans Welcome Back, la brume s'ouvre sur les VRAIS widgets de progression |
| « dans la nav profil tu inventes un onglet de design, c'est pas le vrai onglet » | la fenêtre capsule + halo autour du glyphe, avec la lumière orange de la Home dessous : ça ressemblait à un onglet dessiné | **le vrai glyphe, tel quel**, dans une brume qui s'ouvre juste autour de lui — rien d'ajouté |
| « la lune pour le coffre est très mal entourée » | un cercle tracé autour de la pièce, la pastille « ▶ Nosfy » à cheval dedans | plus de cercle : la pièce reste nette dans une petite poche de brume ouverte, et c'est tout |
| « c'est 0/10, refais un plan » | — | ce plan, sans une seule forme |

Et « c'est un tuto d'app de sport » : les textes restent ceux du 14-09 (§ 4).

## 1. LA DIRECTION v4 — la brume

**La Home ne change pas. On ne dessine rien dessus.** On la couvre d'une **brume** — le noir
et le flou — qui est **absente autour de l'objet du temps** et qui se referme en fondu tout
autour. Quatre temps = quatre endroits où la brume s'ouvre. C'est tout.

### a) La brume
Trois couches, plein écran, DÉMONTÉES à la fin :
1. `.ultraThinMaterial` (le premier flou) ;
2. `.regularMaterial` à 55 % (le second — le « blur de blur » : le grain du premier
   disparaît, on a la profondeur d'une photo, pas un verre dépoli) ;
3. le noir à 78 %.
Les trois portent **le même masque** : un dégradé radial centré sur l'objet — **transparent
jusqu'au rayon de l'objet, puis opaque 140 pt plus loin** (80 pt pour les petits objets : le
glyphe, la pièce). C'est ce masque qui fait tout : dedans, la Home est exactement elle-même ;
dehors, elle s'enfonce dans le noir flouté ; entre les deux, un fondu — jamais une arête.
Les rayons de flou ne bougent jamais (la loi) ; seuls le centre et le rayon du masque
s'animent.

### b) Ce qui s'ouvre, pour chaque temps (les vrais objets, rien d'ajouté)
| temps | l'objet (son ancre) | rayon clair | fondu |
|---|---|---|---|
| 1 · les galets | la card ROUTE (`visite-galets`) | sa demi-diagonale + 24 pt | 140 pt |
| 2 · la progression | la rangée des widgets (`visite-progression`) — les vrais, sans Welcome Back devant | demi-diagonale + 24 pt | 140 pt |
| 3 · le profil | le glyphe Profil de la nav (`visite-profil`, NavEncre) — tel quel | 40 pt | 80 pt |
| 4 · les pièces | la pièce du trésor (`visite-pieces`) | 40 pt (la pastille « ▶ Nosfy » qui la chevauche est de la Home : elle reste) | 80 pt |
Aucun contour, aucune échelle, aucun soulèvement : l'objet est simplement **le seul net**.

### c) Les mots — dans la brume, jamais sur le clair
Blanc, Inter 32 semibold, tracking −2 %, **mot par mot** (`MotsFlou`, le phrasé du film :
chaque mot naît du flou), posés DANS LA BRUME sous la poche claire — ou au-dessus quand
l'objet est bas (la nav) — à 28 pt du bord du clair, alignés à gauche dans 300 pt (la loi de
la phrase de la Home). Dessous, la ligne sourde (Inter 17, blanc 42 %, fondu + 4 pt à
+0,35 s). Puis, à +1,2 s, **l'invite** : « Touche pour continuer » (Inter 14, blanc 38 %, qui
respire 0,38 ↔ 0,6 sur 2,4 s) — au quatrième temps : « Touche pour commencer » / « Tap to
start ». **Pas de bouton, pas de points, pas de « Suivant ».** Au tap, les mots se
dissolvent dans le flou (0,3 s) ; les suivants naissent quand la poche s'est posée.

### d) Passer, et le doigt qui traverse
« Passer » / « Skip » : un mot, en haut à gauche sous la barre d'état (Inter 15 medium, blanc
50 %, zone 44 pt), né avec la brume. Un tap partout = le temps suivant. Le doigt **traverse**
la poche claire : taper la card ROUTE ouvre la route, taper la pièce ouvre le coffre — et la
visite se termine. Ce mécanisme existe (v2), il reste.

### e) Le mouvement — peu, et doux
```
 t = 0,00  la brume tombe (opacité 0 → 1, 0,8 s, courbe 0.22 / 1 / 0.36 / 1),
           la poche est DÉJÀ sur le premier objet (rien ne « s'ouvre » : c'est la brume qui
           arrive autour de lui)
 t = 0,60  les mots, mot par mot · t = 0,95 la sourde · t = 2,1 l'invite
 ── tap ──
 t = 0,00  tic clair (DialTick) + main légère · les mots se dissolvent (0,3 s)
 t = 0,05  la poche GLISSE vers l'objet suivant et prend son rayon (0,7 s, courbe
           0.3 / 0.8 / 0.2 / 1) — la brume se referme derrière, s'ouvre devant, en fondu
 t = 0,55  les nouveaux mots
 ── dernier tap / Passer ──
 t = 0,00  paillette (NosfyPaillette) + main moyenne · les mots se dissolvent
 t = 0,10  la brume se lève (0,7 s) — la Home revient entière ; le galet 1 respire
 t = 0,85  démontage · mémoire (woop.visite.faite + marquer_visite_home)
```
Pas de recul de la page, pas d'anneau, pas de battement : la brume, les mots, le glissement.
`accessibilityReduceMotion` : tout à 0 s, sans respiration.

### f) Le son et la main
Un temps qui change : `DialTick` 45 % + `.light`. La fin : `NosfyPaillette` 60 % + `.medium`.
« Passer » : `.light` seul. Jamais `NosfyTap` (le son de porte : « triste »).

## 2. P0 — ce que la v2 a laissé passer, à corriger AVEC la v4

1. **Le Welcome Back du jour se tait le jour de la première arrivée** : tant que
   `premiere_fois` (le cache `woop.premiere_fois`), `welcomeOuverte` ne s'allume pas
   (WoopApp : la porte `eco.retourDisponible`). Le serveur le tient déjà pour un compte sans
   séance (S4) ; l'app doit le tenir aussi pour un compte qui en a (le sien, au banc).
2. **Le CTA de la pop-up : « Commencer » / « Start »** (à la place de « Démarrer »).
3. Rien d'autre ne bouge dans la pop-up : « Nosfy_galet_onboarding » (`.nosfyGaletOnboarding`,
   LA VRAIE : Nosfy saute sur les galets), variant « pop-nosfy_onboarding/test »
   (`.popNosfyOnboardingTest`, Nosfy de face) gardé.

**Fait le 14-09 sur ses mots, hors tuto (trois lignes)** : la porte du Welcome Back coupée
tant que `premiere_fois` (WoopApp), le CTA « Commencer » / « Start », le variant renommé.

## 3. Ce qu'on garde de la v2 — le socle, prouvé
Les quatre ancres (`visiteAncre`, les six arrivent), la racine (`overlayPreferenceValue`), la
traversée du doigt, la mémoire, les bancs (`-visiteHome [1-4]`, `-sansVisite`,
`-visiteFlou1`), les captures à refaire. On JETTE : la fenêtre evenOdd, le liseré, le halo,
la flaque, la vignette, le recul de la page, l'avance de l'objet, la card de verre, le bec,
les points, « Suivant », « Terminer », le battement du noir.

## 4. Les textes (inchangés — sport, deux lignes, deux langues)

| temps | claire | sourde |
|---|---|---|
| 1 | Commencer. (son mot, 14-09 : « juste un mot, comme Tes progrès ») | Ton parcours, séance après séance. |
| 2 | Tes progrès. | Chaque séance compte. |
| 3 | Ton profil. | Tes Boosters et ta collection. |
| 4 | Tes pièces. | Gagne-les en t'entraînant. Ouvre des Boosters. |

EN : « Start your workout. » / « Your path, workout after workout. » · « Your progress. » /
« Every workout counts. » · « Your profile. » / « Your Boosters and your collection. » ·
« Your coins. » / « Earn them by training. Open Boosters. » · invites « Tap to continue »,
« Tap to start » · « Skip ».

## 5. Ce que ça coûte
Moins que la v2 : deux matières + un noir, sous UN masque radial (une vue Animatable sur
trois nombres — centre x, y, rayon — ré-évaluée pendant le glissement de 0,7 s seulement),
aucun verre, aucune horloge ; ~20 s, démonté. À mesurer sur son téléphone (sonde, thermique
0), barreau `-sansVisite`. Code : `VisiteHome.swift` réécrit (~250 lignes, plus court que la
v2), la porte du Welcome Back (3 lignes), le CTA (1 mot) — **½ j**. Captures à refaire.

## 6. Aucune question
Tout est tranché par ses mots. Elle dit « code » ; sinon rien ne bouge.

## 7. État (14-09, matin — « ok bien, commit que ça et continue le plan en // »)
**CODÉE** : `VisiteHome.swift` v4 (la brume = `Brume`, vue Animatable sur x, y, l, h, rayon,
masquée par une poche floutée à rayon constant ; `Perce` pour le toucher ; les mots dans la
brume ; l'invite qui respire ; « Passer » ; la cascade § 1 e ; tic + paillette). Le recul de
la page et le focus de la v2 sont retirés (WoopApp, DepartEtat). Le P0 (Welcome Back coupé,
CTA « Commencer ») est commité dans b7035c7. Vue au simulateur (captures onb-11…14), à juger
sur son iPhone, non mesurée. Et, en parallèle, LA PHRASE DE LA HOME VIENT DU SERVEUR
(`home().phrases`, session back-end, 14-09) : `PhraseTexte.serveur(_:nombre:)` lit le cache
`woop.phrases`, le nombre du téléphone dans le troisième fragment ; mes textes ne sont plus
que le repli.

**Son verdict sur la v4 (14-09, matin) : « OK c'est mieux. »** Et trois retouches, posées :
« plus d'haptique » (la brume qui tombe = main douce `.soft`, les mots = légère, le temps
suivant = moyenne, la poche posée = douce, la fin = `.success`) ; « apparition plus blur, jolie »
(la poche NAÎT large — 1,6 × l'objet — et se resserre sur lui pendant que la brume monte en
1,1 s ; la sourde et l'invite naissent du flou aussi ; la sortie rouvre la poche en s'éteignant)
; « dégradé de noir » (le noir n'est plus plat : 66 % en haut → 90 % en bas, plus une vignette
radiale de 22 %). Le wording FR/EN de la visite et de la pop-up est transmis à la session
back-end (elle le tiendra pour `home().visite` le jour où elle voudra le voir servi).
