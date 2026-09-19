# L'ÎLE QU'ON PEUT TOUCHER — le plan, fondé sur une carte mesurée (06-09-2026)

Ce que Kathryn demande, verbatim, 05/06-09 :

> « Partout, à la simple tap ou drag **peu importe où sur la display island**,
> je peux faire sortir la pilule, plus morphisme — **comme les appels
> iPhone**. » · « Impossible de faire sortir la pilule du display, bug à fix. »
> · « Je peux la sortir **nulle part** et déclencher la pop-up **stop jamais**.»
> · « Faut que ce soit **super fluide**. »

## V9 — DESIGN ET GESTES VALIDÉS, HALO ALLÉGÉ51

L'utilisatrice confirme la sortie et le design blanc à17:33.51 garde le
placement et les gestes50, change seulement le moteur de lumière : fondu de
textures au compositeur. Quatre tests de gestes51 passent au simulateur ;
deux parcours du composant sur iPhone passent dans la comparaison. CPU du
lab :1 % natif /16 % SwiftUI à thermique0/protection0,17 lignes chacun.
51 est installée et relue ; retour normal sans sonde réussi17:42:43.
[Mesure51 et limites](../perf/campagnes/2026-09-16-ile-seance/performance51.md).

## V8 — CHRONO À GAUCHE, STOP À DROITE (16-09,50)

Dernière demande : commandes à hauteur du capteur, aucune rangée sous l'île ;
halo blanc intérieur sur Home noire.50 dessine une capsule274×54 y6–60,
chrono/stop centrésy33 de part et d'autre du capteur, sans réserve de page.
Le contour monte à282×58 au contact. La barre de statut se masque en séance
pour ne pas superposer l'heure et les icônes aux commandes.

Le tap/drag garde la sortie de pastille ; Home ouvre directement le détail.
Le stop a répondu au tap sur son centre(292,7;33) au simulateur. Les six
scénarios ciblés possèdent une exécution positive ; les premières passes
invalides restent consignées.50 installée et lancée sur iPhone à17:22:46.
Le contrôle de séance réelle est ignoré : aucune séance active au contrôle.
La validation physique et le coût sont désormais consignés dans V9.

Le repère foreground de l'app est distinct de la Live Activity système
background, qui garde ses deux tests de retour.49 rétablissait les gestes
mais son placement/couleur ont été refusés. Les sectionsV4–V7 ci-dessous
restent historiques, pas le comportement final50.
[Preuves50](../perf/campagnes/2026-09-16-ile-seance/rendu50.md).

## V7 — LE BESOIN RESTE DANS WOOP OUVERT (16-09,16:14)

Verdict explicite : la pastille manque **dans Woop ouvert**. Le montage47
la cache en la rangeant dans une Live Activity qu’iOS masque au premier plan.
La demande de vraie île n’autorise pas à déclarer ce comportement satisfaisant.
Les deux parcours natifs passés sur simulateur prouvent l’arrière-plan et le
retour ; ils ne valident pas le contrat de présence dans l’app.

Compilation propre48 réussie, signature vérifiée, installation et version48
relues sur l’iPhone à16:29. Reprise16:31 après déverrouillage : lancement48
réussi, Home sans sonde capturée et relue ; aucun parcours d’île48 validé.
Un cache vidé ne change
pas la visibilité système. Aucun ancien décor refusé, décalage de page ou
zone invisible n’est réintroduit pour prétendre résoudre cette contradiction.
[État et limite Apple](../perf/campagnes/2026-09-16-ile-seance/native.md).

## V6 — LA VRAIE DYNAMIC ISLAND IOS (16-09)

Décision explicite après rejet des propositions43 et44 : **« dans la vraie
ÎLE […] comme toutes les apps »**. Les anciennes versions ci-dessous sont
l'historique d'un décor dessiné dans l'app, pas l'île système demandée.

Le parcours normal de `PiluleVagabonde` ne monte plus aucun décor d'île, aucun
halo autour du capteur ni zone tactile cachée. Le prototype reste uniquement
dans `PiluleLab` (`ileNative: false`) pour conserver le travail historique.
Les pages gardent leur montage et leur hauteur d'origine.

`WorkoutLiveActivity`, dans l'extension WidgetKit, fournit la braise et le
chrono aux régions compactes/minimales/agrandies d'iOS. Le chrono est animé par
le système ; la braise a une transition de0,6s lors d'une mise à jour réelle.
Pas de boucle d'animation ni de réveil de l'app pour entretenir cet effet.
L'appui long et l'expansion appartiennent à iOS. Au tap système, le lien
`woop://session/<départ>` est vérifié contre la séance active : retour vers
le détail sur Home, vers la
pastille libre à sa dernière place sur les autres onglets. Le drag de la
pastille reste dans l'app ; iOS ne transmet pas le drag de l'île à cette vue.

Comme pour une Live Activity standard, l'île présente la séance quand Woop est
en arrière-plan. Le système garde le contrôle de sa visibilité, de son fond
noir et des gestes. L'ancien fond blanc Home et le souffle continu SwiftUI
ne sont donc plus des promesses du parcours natif.

La validation native passe par `IleNativeUITests`, qui cherche la séance dans
**SpringBoard** et teste l'appui long puis le retour dans Woop. Les anciens
tests06/07/09/10 de prise sur une capsule dans l'app ne prouvent pas ce contrat.
[État, preuves et limites](../perf/campagnes/2026-09-16-ile-seance/native.md).

## ⚡ LIVRÉ LE 06-09 — ET VALIDÉ AU DOIGT

> **« Mais ça marche ton fix de pouvoir la sortir et la rentrer ! »** — Kathryn,
> 06-09, sur kat-flow-15.

### LE CONTRAT DE LA PASTILLE — la loi, dictée par elle, mot pour mot

> **« La pastille VIT, dans toute l'app.** En séance elle vole dans l'île ;
> **tap (ou drag) n'importe où sur le bloc → elle SORT**, posée juste dessous,
> et le même doigt peut la porter ; **un jet vers le haut la re-cache** ; **tap
> sur la pastille → le player**. **Une seule exception : la home noire
> « session en cours » (le Foyer)** — c'est ELLE qui n'affichera pas la
> pastille, chez elle, pour alléger son UI. »

S'y ajoutent, prouvés au banc à vrais touchers (5/5) : le **stop du pont bas
est un vrai bouton** (le premier qui ait jamais marché — l'ancien vivait en
zone morte), et aucun déplacement lent ou pose ne l'aspire par accident.

⚠️ Deux malentendus d'un matin, écrits pour ne pas les repayer : « pas de
pastille / tap ouvre l'overlay » était adressé au FOYER (sa page, son gate) —
un pivot qui tuait la pastille a été codé puis ANNULÉ ; et « les braises
marron » appartiennent aussi à l'autre session — la couleur du feu ne se touche
pas d'ici.

La capsule a ensuite été resserrée (« pourquoi la pill est aussi grosse ?? ») :
**214 × 87** (largeur 250 → 214, bas 96 → 92 — le contenu du pont reste centré
à ~71, au-dessus de la frontière vivante mesurée à ~70).

→ **06-09 après-midi : V2 demandée** — même resserrée, « elle mange toute
l'UI de l'écran ». La capsule d'appel ne meurt pas : elle devient **l'état de
PASSAGE sous le doigt**. Le plan V2 est au chapitre suivant ; les §1-6
ci-dessous restent le socle (la carte du toucher et la mécanique acquise ne
bougent pas).

---

## V5 — CAPSULE RÉGULIÈRE, PAGES À LEUR HAUTEUR D’ORIGINE (16-09)

**V5 refusée également : l’animation reste à l’extérieur de l’île.** Les valeurs
ci-dessous documentent l’essai44, pas une solution acceptée. Les tests de geste
ne valident pas l’intégration visuelle. Ne pas reprendre cette géométrie comme
référence approuvée et ne pas abaisser les pages lors de la prochaine correction.

**Refus explicite de la V4** : « on dirait une pyramide », puis « tu as baissé
les pages, cf Profil !! non ». Les épaules du contour et toute réserve de
hauteur dans les pages sont supprimées. Ne pas les réintroduire pour dégager
l’île : c’est elle qui doit tenir dans le haut de l’écran.

Le contour est désormais une `Capsule` SwiftUI, 176×67 de y5 à72. Stop et
chrono sur la ligne59, avec le stop réduit à22pt visuels. Aucun tablier tactile
sous l’île des pages ; la Home conserve sa prise jusqu’à72. Le gonflement
214×87, le ressort, le vol et les protections du souffle restent en place.
Exercices et Profil retrouvent exactement leur montage antérieur.
Les constats V4 ci-dessous restent l’historique d’une version refusée.

[Validation de la capsule compacte](../perf/campagnes/2026-09-16-ile-seance/capsule.md).

---

## V4 — UN SEUL CONTOUR AUTOUR DU CAPTEUR (16-09)

La V3 ci-dessous est l’historique, pas le rendu courant. Son cadre clair à
y46–86 formait encore une pastille SOUS l’île. La V4 garde stop + chrono sur
la ligne66, dans un seul fond noir qui enveloppe le capteur dès y5. Les
lueurs sont derrière le noir opaque ; aucune bordure ne sépare le capteur
du contenu. La tête se resserre, les coins bas restent20, la grande ouvre
le cadre vers214×87 sous le doigt. Le contenu conserve sa place pendant
le morphisme ; le seuil12pt, les ressorts et la source matched unique restent.

Home noire : île blanche compacte148×55, sans pastille ni chrono ; tap sur
la partie basse → détail. L’état et la dernière pose survivent aux onglets.
Exercices/Profil réservent aussi la marge TACTILE de l’île pendant la séance,
pour qu’un titre visible ne soit pas couvert par une prise invisible.

Banc simulateur :11 cas passés, réserve tactile corrigée puis12e cas ciblé
passé. Le chrono continue à1Hz quand la protection thermique immobilise
le souffle. La Home blanche ne monte aucun souffle. Le rendu et le coût
sur le téléphone sont consignés séparément dans le
[rapport de validation](../perf/campagnes/2026-09-16-ile-seance/etat.md).
La chauffe durable n’est pas close par un parcours tactile réussi.

---

## V3 — LA BABY PASTILLE (07-09, CODÉ, 11/11 au banc — remplace la fine de V2)

Son verdict sur la fine, le soir même : **« c'est pas encore ce que je veux —
j'ai demandé la baby pastille comme avant, qui se morphe avec ton état plus
gros ; et en vrai tout ce que tu as dit ne fonctionne malheureusement pas, on
n'arrive pas à drag et tap sur l'île — même bug que ce matin. »** Puis, après
analyse : **« oui c'est ça, fais — et après elle devient notre pastille
normale qu'on balade partout ; une fois passée de baby à plus grosse, la
normale vient se mettre au-dessus de la nav bar quasiment, ou peu importe,
qu'on peut bouger et cacher partout. Tap ou drag hyper fluide sur le display
island, ça fait ça. »**

### Pourquoi la fine ÉTAIT le bug de ce matin (mesuré, pas honteux — payé)

La fine ENVELOPPAIT le trou (y 5→74) : les deux tiers de son corps vivaient
dans la bande morte du système (y ≤ ~50, la carte du toucher). On voyait une
pilule, on tapait dedans, rien n'arrivait. Mon banc tapait la lichette basse
(vivante) → 7/7 vert pendant que son doigt mourait sur le corps visible —
**un banc vert n'est pas un doigt**, deuxième leçon du même jour.

### La chaîne, telle que codée

```
  REPOS                 SOUS LE DOIGT              APRÈS
  LA BABY      →tap/drag→  LA GRANDE      →seuil/tap→  LA NORMALE
  176×40, y 46→86       la 214×87 : son toit       tap : descend en vol
  COLLÉE au trou,       monte avaler le trou,      matched à sa place
  100 % vivante         flancs + rayon s'ouvrent   commise (~au-dessus de
  stop+chrono y 66      contenu quasi fixe (→71)   la nav) · drag : en main
```

⚠️ **COLLÉE, PAS DÉTACHÉE** (son verdict sur la première capture, 07-09 :
« très bien mais elle doit être DANS le display island, pas en dessous —
c'est bizarre ») : le toit de la baby (46) se glisse de ~2 pt sous le bord du
trou (48,3) — la pilule et l'île ne font qu'un bloc, comme la bannière
d'appel. Rien de touchable ne remonte dans la bande morte.

✅ **VÉRIFIÉ le 13-09** (kat-flow-15, capture `tools/flow/captures/baby-collee.png`
+ banc à vrais touchers) : la baby collée rend bien (elle APPARAÎT après ~2 s,
le temps que le fond vidéo de la page charge — une capture trop tôt la rate) ;
banc **10/11**, TOUS les cas pastille verts (tap, tap tremblant, stop baby,
drag, pose, carte du toucher). Le seul rouge, test08, est le **2ᵉ mangeur de
nav du châssis** (home ∧ séance, le glyphe dont l'action n'est jamais appelée
— zone Foyer/PanBande, signalé), PAS la pastille : il passait à 11/11 le 07-09,
c'est une régression du châssis dans les 6 jours écoulés. ⚠️ Reste ouvert au
verdict d'elle : la baby MORD le titre de page (« Exercices ») — elle flotte
au-dessus des pages comme la normale ; à remonter/décaler si ça la gêne.

- **Le contenu ne bouge JAMAIS** (ligne 71 dans les deux robes) : au
  gonflement, seul le cadre travaille — toit, flancs, rayon (20→34). C'est ce
  qui rend le morphisme lisible.
- **Le tap joue la chaîne entière** : `sortirEnMain(vers: .placeCommise)` —
  la normale descend en vol matched à sa place commise (yRatio persisté,
  0,82 par défaut = au-dessus de la nav). Ce n'est PLUS la téléportation du
  05-09 : le voyage se voit. Le drag garde `.sousLIle` (naît dans la main).
- **La prise = le bloc île entier** (`PriseIle` : toit 47 jusqu'à y 5,
  flancs 20, tablier 18 → plancher ~y 110) — tout toucher que iOS livre
  autour du trou tombe dans le geste.
- Banc : **11/11** (dont les 3 cas nav re-verts après le fix Foyer), purge du
  runner adoptée (piège prouvé par la session Foyer). Carte baby : centre et
  aile-D vivants 55→75 ; rang 80 = 3 morts inexpliqués en fin de course
  (81 s de test, cas de comportement tous verts) — noté, pas élucidé.
- ⚠️ Vu à la capture, à trancher par elle : la baby (y 52→92) passe DEVANT
  le titre des pages (« Exercices », y ~64) — elle flotte au-dessus de tout,
  comme la normale.

---

## V2 — LA CAPSULE FINE AU REPOS (06-09 — REMPLACÉE PAR V3 le 07-09)

Sa demande, verbatim (deux captures à l'appui) :

> « Je veux qu'elle soit comme ça [capture 1 : la capsule FINE, serrée sur
> l'île], pas aussi grande [capture 2 : la capsule d'appel 214×87] — elle
> mange toute l'UI de l'écran. Mais elle peut devenir **comme tu as fait quand
> on drag, avant de se transformer en pastille**. Et assure-toi de la fluidité
> de drag ou tap peu importe où — on a trop galéré. »

Décodé : **trois états, un seul voyage.**

```
   REPOS                    SOUS LE DOIGT                 EN MAIN / POSÉE
  la FINE          →tap/drag→   la GRANDE        →seuil→    la PASTILLE
  serre l'île                gonfle en 0,3 s              (mécanique acquise,
  (~262 × 69)                (la 214 × 87 d'aujourd'hui)   matched + fondu)
```

La capture 1 est l'ANCIEN dessin (l'anneau du 05-09) — elle le cite pour la
TAILLE, pas pour son toucher : son stop (à gauche, y ≈ 53) était précisément
**le bouton qui n'a jamais marché** (§1, la carte). La V2 reprend sa
silhouette, pas son erreur.

### V2.1 — LA FINE (l'état de repos)

Cotes de départ, à geler par la mesure (§V2.5) puis à l'œil sur capture :

- **largeur 262, y 5 → 74** (haut 69) — le trou (126 pt) garde des ailes de
  68 ; le rayon 34 en fait une vraie pilule. Elle ne descend plus sur la page
  (la grande mordait jusqu'à y 92, sur le « Alright Kathryn » de la home).
- **Le contenu vit dans les coins bas des ailes** (centres à y ≈ 58), à côté
  du bas du trou — plus de pont sous le trou : c'est la silhouette de sa
  capture.
- ✅ **LE MIROIR EST DISSOUS PAR LA RE-MESURE** (06-09, grille fine 21 cases,
  onglet Exercices — là où la capsule vit) : **TOUT arrive dès y 55, ailes
  comprises.** Le « mort à gauche 55-70 » de la carte V1 n'était PAS le
  système : c'était un mangeur de touchers de la HOME (le menu de fumée,
  corrigé `5c21bd3`) — et la V1 se mesurait sur la home, où la capsule ne
  vit plus (le gate du Foyer est posé au châssis depuis le 06-09 :
  `WoopApp`, `selection != .home`). **Le stop reste donc À GAUCHE, comme sur
  sa capture**, chrono à droite — l'ordre de la grande, rien ne se croise au
  gonflement. Prouvé en comportement par le cas 06c (compteur de stop).
- La ligne d'honnêteté, réduite à sa vraie taille : **la bande du trou
  (y ≤ ~50) reste sourde pour toujours** — c'est le système. Tout le reste de
  la fine est vivant, et la PRISE invisible descend encore à y ≈ 106 (V2.3) ;
  le GONFLEMENT répond au premier toucher arrivé — le retour visuel apprend
  au doigt où toucher.

### V2.2 — LA GRANDE (l'état de passage) et la rentrée

- La grande reste **exactement la 214 × 87 validée** (« comme tu as fait ») :
  stop à gauche + chrono à droite dans le pont bas, INCHANGÉS — la re-mesure
  ayant gardé le stop à gauche dans la fine, les deux robes partagent déjà
  l'ordre et rien ne se croise pendant le gonflement.
- **Le gonflement** : ressort court (`spring(response: 0.32, damping: 0.78)`),
  le trou ne bouge JAMAIS (la capsule pousse vers le bas et resserre ses
  ailes : 262→214 en largeur, 74→92 en bas, contenu y 58→71).
- **La sortie** : au seuil (drag) ou au relâcher (tap), `sortirEnMain()`
  inchangé — l'île s'éteint en fondu 0,30 s **depuis sa forme grande** pendant
  que la pastille naît : c'est mot pour mot « elle devient grande avant de se
  transformer en pastille ».
- **La rentrée (jet vers le haut) atterrit DIRECTEMENT sur la fine** — pas de
  passage par la grande au retour : le vol matched qui se resserre dans la
  petite capsule est le geste sobre ; un rebond fine→grande→fine à l'arrivée
  se lirait comme un glitch. Verdict au film si elle veut le rebond.
- Si le geste meurt sans sortie (chien de garde) : **dégonflement animé**,
  retour fine, rien ne sort.

### V2.3 — LA MÉCANIQUE DU GESTE (`gesteSortieIle`, PiluleVagabonde.swift:719)

Aujourd'hui la sortie part au TOUCH-DOWN (premier `onChanged`). En V2 elle
part au SEUIL — c'est ça qui crée la fenêtre où la grande existe :

*(Tel que CODÉ le 06-09 — une simplification sur le plan initial : pas de
`gonflee` manuel, le gonflement EST le `@GestureState` du doigt.)*

1. **le gonflement = `doigtIle`** : le `@GestureState` existant porte la robe
   (fine ↔ grande). Son `updating` pose le ressort (0,32/0,78) sur la
   transaction du premier événement ; sa `resetTransaction` (0,32/0,82)
   dégonfle TOUTE mort de geste — relâcher, doigt volé, arrière-plan — sans
   un minuteur ni une remise à plat à écrire. Pendant le fondu de sortie, le
   dégonflement est recouvert par `matchedGeometryEffect` (l'île qui s'éteint
   suit déjà le cadre de la pastille) ; une rentrée ne peut jamais naître
   gonflée (le reset a couru au relâcher précédent).
2. **premier `onChanged`** (`dansIle`, pas encore en main) : `origineIle`
   posée (⚠️ pas `!doigtIle` comme témoin — `updating` court AVANT
   `onChanged`, il est déjà vrai). **Rien ne sort encore.**
3. **le doigt tire** : dès 12 pt depuis `origineIle` → `enMainDepuisIle`,
   re-base de `sortieTranslation` (pas de saut), haptique moyenne,
   `etat.sortirEnMain()` + `etat.saisir()` — puis `suivre()` comme avant.
4. **relâcher AVANT le seuil = TAP** (`onEnded`) : `sortirEnMain()` — posée
   juste dessous, le contrat. Le gonflement a joué ~0,1 s : le tap a un
   accusé de réception visuel qu'il n'avait pas. (Garde-fou mesuré : un tap
   qui TREMBLE de 6 pt reste un tap — cas 06b.)
5. **chien de garde** (`onChange(doigtIle)`) : geste mort en main →
   `gesteMort()` (acquis) ; `origineIle` remise à nil dans tous les cas.
6. **le stop ne gonfle pas** : son `highPriorityGesture` gagne dans son
   disque (inchangé) — un doigt posé sur le stop fait un stop, pas une
   sortie ni un gonflement (cas 06c).

La prise (`PriseIle`, :546) : `sous` passe **14 → 32** — le plancher tactile
au repos reste y ≈ 106, EXACTEMENT celui de la grande validée 5/5. La fine ne
rend pas un point de la surface qui marche : elle rend des pixels, pas du
toucher.

### V2.4 — OÙ VIT LE CODE (et où il ne va PAS)

- `IleGeo` (:579) : + `fineBas = 74`, `fineLargeur = 262`, `fineCentreY` —
  les cotes `capsule*` existantes DEVIENNENT la grande, noms inchangés (les
  hooks du banc et la session perf s'y ancrent).
- `PiluleEtat.ancreGlobale` (:375) : cible `fineCentreY` (le vol de rentrée et
  le vol du coin de la fiche exo visent la fine — la fiche gèle sa cible au
  moment du tir, rien d'autre à toucher là-bas).
- `IleDecor` (:1110) : les cotes deviennent des paramètres pilotés par
  `gonflee` (frame, position du contenu — le `VStack+Spacer` devient un
  `ZStack` alignement haut). ⚠️⚠️ **`gonflee` n'entre JAMAIS dans
  `animatableData`** : la loi n° 2 de la campagne du 05-09 (« un attribut ne
  porte qu'une animation ») — fusionner gonfle dans la paire tuerait le
  `repeatForever` de 900 s du souffle. Le gonflement anime des attributs
  DISJOINTS (`.frame`/offsets standard, transaction du geste) pendant que `t`
  garde son animation à lui.
- `ile` (:866) : `.position` suit l'état (`gonflee ? capsuleCentreY :
  fineCentreY`) — animé par la même transaction que le gonflement, le trou
  reste cloué. Le commentaire d'époque « le tap ouvre le player » (:912) est
  périmé depuis le contrat (tap = sortie) : à rafraîchir dans la même passe.
- `ileCorps` (:888, rejeu `-souffleHorloge`) : **reste à la grande figée** —
  c'est la photo A/B de la session perf, on ne réécrit pas leur témoin ; noté
  pour eux.
- **Rien dans WoopApp** (la session Foyer y posera son gate au châssis — elle
  prévient avant), rien dans les pages, rien au téléphone.

### V2.5 — LA PREUVE DE SORTIE, dans l'ordre (la fluidité « on a trop galéré »)

1. ✅ **`test99` en grille FINE d'abord** (3 colonnes × 7 rangs, y 55→80,
   AVANT de coder les cotes, sim dédié `kat-pilule`, iPhone 15) — verdict :
   **21/21 ARRIVE dès y 55, ailes comprises.** La « frontière ~70 » de la V1
   n'existe pas sur les pages où la capsule vit : c'était le mangeur de la
   home (`5c21bd3`). Cotes gelées telles quelles (58 pour le contenu, marge
   ~8 pt sur la vraie frontière du trou).
   ⚠️ Découverte du même run, payée deux échecs : **le gate du Foyer est
   posé** (`WoopApp`, `selection != .home`) — un banc pastille lancé sur la
   home guette un corps jamais monté. Tous les cas pastille passent par
   `lancerEnSeanceAvecPilule()` (`-openTab exercises`).
2. ✅ Le banc : `centreIle()` garde `maxY−18` — sur la fine ça tombe à y 56,
   VIVANT d'après la carte du jour, et sur la grande au pont. Les ancres D
   (position à deux états) et D bis (compteur du stop) ré-ancrées dans
   `applique_hooks_pilule.py` — 8/8 au remontage.
3. **Les cas re-passés** + deux neufs : 06b « un tap qui tremble de 6 pt
   reste un tap » (le seuil ne mange pas les taps), 06c « le stop fin claque
   sans sortir » (compteur `stop=` dans la sonde). Le cas « geste mort avant
   seuil » n'est PAS automatisable en XCUITest (on ne peut pas tuer un
   toucher sans le relâcher) — le dégonflement y est structurel de toute
   façon (reset du @GestureState), dit honnêtement ici.
   ⚠️ **La carte re-jouée SUR la build fine a menti une heure** : colonnes
   gauche et centre « mortes » partout — en réalité chaque rang commençait
   par un tap aile-G qui pressait le STOP, sa card s'ouvrait, et le tap
   centre suivant la REFERMAIT (consommé par le scrim). Prouvé par
   L'ÉCHELLE (`DiagGestePilule.testF`, app fraîche, zéro stop) : centre
   y 58 · 65 · 72 · 80 · 88 → **5/5 SORT**. Une carte dont chaque case
   modifie l'état de l'app n'est lisible que si la case d'avant n'a rien
   ouvert — au banc comme au téléphone.
   📏 **La prise réelle du stop fin, mesurée** : son disque padded (50 pt,
   ×0,76) claime l'aile gauche jusqu'à y ≈ 80 — (88, 80) fait un STOP, pas
   une sortie. C'est le coin du stop, la loi des 44 pt d'Apple ; dit ici
   pour que personne ne le re-mesure en croyant à un bug.
4. **Films** (détecteur de flash) : tap (fine → éclosion → posée), drag (fine
   → grande sous le doigt → pastille en main), rentrée (jet → fine directe).
5. **Son doigt sur kat-flow-15** — le seul verdict. Pas de build téléphone
   (session perf), pas de commit sans son ordre.
   ⚠️ Le build PROPRE de l'arbre est retombé sur LE MUR du type-checker
   (`WoopApp:1216`, la ligne HomeNuitPage du Foyer — leur zone, prévenus) ;
   le banc tourne avec une extraction mécanique DANS LA COPIE JETABLE
   seulement (`ongletHomeFouettage`), sémantique identique.

### V2.6 — LA CHAUFFE (périmètre tenu)

**Zéro horloge de plus.** Le gonflement est un ressort one-shot sur des
attributs animables (jamais une taille suivie au doigt image par image — le
suivi du doigt reste sur la pastille, en offsets, acquis). Les gaussiennes de
braise se re-rendent pendant les ~0,3 s du ressort (bounds vivants,
transitoire assumé) ; au repos la fine peint MOINS de surface que la grande à
chaque battement 15 Hz — un petit gain, mesurable au banc de chauffe de la
session perf. `IleDecor` est leur structure : je les préviens quand ça se pose.

### V2.? — LA question (DISSOUTE par la mesure)

① ~~Le stop dans la fine : à droite (seule case vivante) ou pas de stop ?~~
La re-mesure du 06-09 a rendu la case gauche VIVANTE : **le stop reste à
gauche, exactement comme sur sa capture** — ni miroir, ni suppression.
Aucune question ne subsiste ; le reste est affaire de capture et de doigt.

---

## 1. LA MESURE QUI EXPLIQUE TOUT — la carte du toucher

Banc à VRAIS touchers (`tools/nav/fouettage/`, test `test99_carteDuToucher`,
06-09, simulateur iPhone) : dix-huit taps en grille autour de l'île, la sonde
d'état dit si chaque tap est ARRIVÉ à l'app.

| y (pt) | aile gauche (x 106) | centre (x 196) | aile droite (x 286) |
|---|---|---|---|
| 15 | mort | mort | mort |
| 30 | mort | mort | mort |
| 45 | mort | mort | mort |
| 55 | mort | mort | **ARRIVE** |
| 65 | mort | mort | **ARRIVE** |
| 80 | **ARRIVE** | **ARRIVE** | **ARRIVE** |

**Le verdict est sans appel : TOUTE la bande de la capsule visible (y 5→54)
est MORTE — ailes comprises.** iOS ne livre aucun toucher à l'app dans la
région de la Dynamic Island et de la barre d'état ; la frontière vivante
fiable est ~y 70-80. Ce n'est pas un bug de geste : **l'objet qu'on dessine
est posé dans une zone où le doigt n'existe pas.**

C'est pourquoi :
- « je peux la sortir nulle part » — ses taps visent la capsule (morte) ;
- « la pop-up stop JAMAIS » — le stop vit à y ≈ 30 : **il n'a jamais été
  tapable**, ni avant ni après les correctifs ;
- le banc passait 5/5 — il tape la lèvre basse (vivante), pas la capsule ;
- **aucun correctif de code ne pouvait suffire** : geste au parent, prise
  élargie, `minimumDistance 0` — tout ça est nécessaire (et prouvé), mais un
  geste ne peut pas entendre un toucher que le système ne livre pas.

## 2. CE QUI EST DÉJÀ ACQUIS (dans l'arbre, non commité, 5/5 au banc réel)

- **Le geste vit sur le PARENT** : il survit au démontage de l'île — on sort
  la pastille ET on la porte du même doigt (`gesteSortieIle`,
  `PiluleVagabonde.swift`).
- **La sortie se pose SOUS l'île** (`PiluleEtat.sortirEnMain`, yRatio 0) — la
  bannière d'appel, plus jamais une téléportation en bas d'écran.
- **Une seule source de géométrie** (`isSource:`) — les cadres ne sautent
  plus pendant le fondu croisé asymétrique.
- Prouvé au banc à vrais touchers : tap dans la zone vivante → sort sous
  l'île ; drag → sort ; jet vers le haut → entre ; pas d'aspiration
  accidentelle ; tap pastille → player. **Ce qui manque n'est pas la
  mécanique : c'est que la zone vivante et l'objet visible coïncident.**

## 3. LE DESSIN QUI RÉSOUT — LA CAPSULE D'APPEL (à trancher par Kathryn)

L'anatomie de la référence qu'elle nomme (l'appel iPhone) n'est PAS un anneau
serré autour du trou : c'est **une capsule plus HAUTE, le trou dans sa tête,
le contenu EN DESSOUS du trou** — précisément parce qu'Apple sait que la
bande du trou est intouchable.

```
   aujourd'hui (intouchable)            la capsule d'appel (tout touchable)
  ┌──────────────────────────┐         ┌──────────────────────────┐
  │ ⏹  (■■ trou ■■)  28:59  │ y 5-54  │      (■■ trou ■■)        │ y 5-48   ← zone morte : RIEN d'interactif
  └──────────────────────────┘         │                          │
     tout est dans la zone morte       │  ⏹ stop        28:59    │ y 56-92  ← zone VIVANTE : stop, chrono,
                                       └──────────────────────────┘            et tout tap/drag = la sortie
```

- la capsule descend jusqu'à **y ≈ 96** : sa moitié basse vit dans la zone
  mesurée vivante (y ≥ 70 partout, dès 55 à droite) ;
- **le trou reste nu** (on ne peint rien dessus, comme aujourd'hui) ;
- **stop à gauche, chrono à droite, dans le pont bas** — le stop redevient
  un bouton RÉEL (aujourd'hui il est décoratif sans que personne l'ait su) ;
- **tap ou drag n'importe où sur la capsule → la pastille sort dans la
  main** (la mécanique du §2, inchangée) ; le stop garde sa priorité dans
  son disque ;
- le souffle du pulsar habille la capsule entière — mêmes couches, même
  horloge 15 Hz, **zéro moteur de plus** (la seule chose qui change est une
  hauteur) ;
- bonus mesurable : chrono et stop quittent la ligne de l'heure système —
  **le chevauchement avec l'horloge et le wifi meurt par construction**.

### Les questions ouvertes — ? (une phrase chacune suffit)

① **La hauteur du pont bas** : 96 pt total (reco — la zone vivante commence
à ~70, le pont respire) ou plus compact (~84, plus proche du trou mais la
marge avec la frontière morte fond) ?

② **Le contenu du pont** : stop + chrono seuls (reco, « allège ») — ou
stop + chrono + le nom de l'exercice en petit ?

③ Le drag depuis la capsule **porte la pastille** (reco, déjà codé) ou
sort-et-pose seulement ?

④ **La vague de braises de la PASTILLE** (`BraisesVague` : un Canvas 9
colonnes + flou 11 + `plusLighter`, à 15 Hz, qui tourne toute la séance dès
que la pastille est dehors) : **on l'éteint aussi ?** Deux raisons de le
faire, remontées par la session Foyer : « allège » (ta règle du 05-09 — la
pastille n'a plus que nom + chrono + reps), et **« un seul feu à l'écran »** —
le Foyer pose son propre feu sur la home en séance, et personne n'avait
compté celui de la pastille. Reco : oui, on l'éteint (une horloge de moins,
et c'est mesurable au banc de chauffe). À noter, décision déjà assumée dans
`tools/foyer/PLAN-FOYER.md` §7 bis : depuis la mort du ticket « N SETS »,
le compte de séries ne se lit QUE dans le détail — les reps n'en tiennent
pas lieu, c'est voulu (« laisse que dans le détail »).

## 4. CE QUE ÇA TOUCHE (quand elle dit go)

`PiluleVagabonde.swift` seulement : `ileCorps` (la forme et le pont bas),
`IleGeo` (une hauteur de plus), `PriseIle` (la prise = la capsule entière,
plus besoin de lèvre invisible). Le banc : `centreIle()` peut ENFIN viser le
centre du pont (plus la lèvre), et `test99` reste comme garde de la carte.
Rien dans `WoopApp`, rien dans les pages.

## 5. LA PREUVE DE SORTIE (avant de la déranger)

1. `test99` (la carte) : le pont bas doit être vivant sur TOUTES les colonnes ;
2. les 5 cas du banc réel, re-passés, `centreIle()` visant le pont ;
3. un film de l'aller-retour (entrée au jet, sortie au tap) ;
4. le verdict « super fluide » : SON doigt, sur SON téléphone — pas de
   pastille verte avant ça.

## 6. LA CHAUFFE — rappel de périmètre

Rien ici n'ajoute d'horloge ni de flou ; la capsule d'appel est la même
matière en plus haut. Le dossier chauffe reste
`tools/perf/ANALYSE-RAME-TELEPHONE.md` (session perf, téléphone chez elle).
