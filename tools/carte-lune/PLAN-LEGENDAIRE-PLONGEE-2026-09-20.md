# Cartes — la légendaire : un objet gravé sous verre, qui brûle et sous lequel il neige

Session d'analyse du 20 septembre 2026. **Rien n'est codé, rien n'est mesuré.**

Trois versions dans la journée, et ses verdicts :

- v1 (curseurs de shader par rareté) → « il faut aller beaucoup plus loin, un
  design exceptionnel et une expérience de fou » ;
- v2 (deux lobes qui se croisent, un éclair au dévoilement, un balayage à
  l'arrivée sur la collection) → **« les balayages c'est cheap, on a déjà parlé
  de ça »** (26-08 : « arrête les balayages blancs, c'est trop cheap » ; slider :
  « un reflet automatique tourne en rond quoi qu'on fasse, donc il ne dit rien —
  rien ne bouge tant que le doigt ne bouge pas ») ;
- puis : **« renforcer les braises, la neige et tout, vraiment un effet shiny de
  fou, et des détails — tu vas trop vite. »**

Cette v3 retire **tout balayage**, et prend chaque effet lentement : ce qu'elle
voit à taille de carte, ce qu'elle voit dans un crop zoomé (elle les regarde),
d'où vient la lumière, où est son bord, ce qui est cuit et ce qui est calculé,
ce que ça coûte, comment on le prouve.

Ses lois, qui bornent tout (mémoire et plans du 18/19-09) : noir absolu, blancs
en dégradé, braise **très sombre** ; jamais de néon, d'arc-en-ciel, de cartoon ;
**une lumière qui bouge a un bord** ; **rien ne bouge tant que le doigt ne bouge
pas** (sauf ce qui respire) ; la brillance vient de la **blancheur**, jamais de
l'épaisseur (« opaque », « fake » = rejet) ; les textures **cuites** battent le
procédural (« coton », « peau de girafe » = rejet) ; micro-détails partout ;
cadre et lunes de rareté conservés ; aucun moteur permanent sur la grille ;
Reduce Motion ; chauffe mesurée.

---

## 1. Ce que le code fait aujourd'hui — les trois causes (lu, inchangé)

### 1.1 « 1 / 5 » : le profil compte ce qui existe au serveur

`ProfilLune.swift:931` affiche `collection.totaux[rareté]`, lu par
`totaux_cartes` (`SacreAccueil.swift:106`) : les **références publiées**, 14 au
19-09 (5 / 3 / 3 / 3). Les 36 autres sont écrites (`PLAN-50-SCENES`, manifeste
avec `art: null`), pas peintes. Site : `b-cartes-cible-50` ⚪. Depuis le 19-09
le serveur ne génère plus à l'ouverture : produit, validé, publié, tiré — mêmes
pixels pour tous. La production est le chantier de l'autre session Cartes ;
**cette session n'y touche pas** — elle lui demande un **kit par carte** (§ 6).

### 1.2 Légendaire = Trois Lunes au rendu près

`CarteVivante` reçoit `rarete` (`CarteLuneLab.swift:252`) et ne s'en sert que
pour le **son** (`:752`). `carteLuneV5` (`CarteLune.metal:185-190`) n'a aucun
paramètre de rareté : foil or 0,38, poussière 1,35, liseré 0,42, vitre 0,055 —
**les mêmes pour les quatre**. Différences réelles : 4 croissants blancs
(`LuneForge.swift:493`), cadre argent (`carte-cadre-legendaire.png`, 28-08).
Et une contradiction : un foil **or** court sur un cadre **argent**. L'aigle
(Trois Lunes) et le cerf (légendaire) côte à côte : même niveau de peinture.
**L'illustration ne peut pas porter la rareté seule.**

### 1.3 La plongée : un film écrit pour UNE carte, joué sur toutes

`plonger()` = 14 s de caméra scriptée (`CarteLuneLab.swift:302`), chemin en
fractions de carte-lune-1 (`:322-330` : « la lune », « la vallée », « les pins
au ras du sol » — sur un loup, les pattes). Zoom ×4,8 sur 1024 px = flou.
Profondeur = **une rampe identique pour toutes** (`LuneForge.swift:522-550`).
Halo de lune et brume à coordonnées fixes (`CarteLune.metal`). Quatorze
secondes sans la main.

---

## 2bis. Ajouts de l'après-midi (ses mots, et les maquettes)

Verdicts sur les premières maquettes : « ça fait pas légendaire, **tout le
ciel et les détails doivent briller énormément**, limite **mini-animation de
la créature** » ; « prends en compte **50 cartes minimum avec les 3 mondes** ».
Règle HARDCORE posée dans `CLAUDE.md` sur son ordre. Ce que ça ajoute aux
fiches E1-E8 :

- **E3 devient LE CIEL QUI SCINTILLE** : plus « trois fois plus d'étoiles »
  mais un champ de **paillettes** sur tout le fond sombre et lisse de la
  carte — deux grilles de cellules (5 px et 9 px), un éclat par cellule à son
  angle propre, allumé quand l'inclinaison passe dessus, tailles en loi de
  puissance, bloom ≤ 3 px. Et une troisième grille **sur les reliefs clairs
  de la créature** (le poil, les écailles, les plumes) : la créature elle-même
  paillette. À taille de carte, le ciel doit se lire comme un ciel de
  diamants ; au crop, des points blancs durs, jamais un voile.
- **La météo par monde** (le monde est lu dans le catalogue) : Forêt = neige
  fine + braises ; Cimes = **cendres** qui tombent (gris chaud, plus lentes,
  plus de dérive) + lave (braises cuivre, deux fois plus) ; Bois = **pas de
  feu**, de la **nacre** qui monte des blancs de la peinture. Rien n'est
  choisi à la main : le feu vient des pixels chauds, la nacre des blancs
  froids.
- **La créature respire** (la mini-animation) : sa cage se soulève de 0,6 %
  sur 4,2 s, son feu vacille, ses paillettes clignotent. Dans l'app : un champ
  de déplacement cuit par carte (le masque du sujet vient de la vraie
  profondeur du kit), appliqué dans le même passage — ou la boucle vidéo (§ 4)
  si l'essai convainc.
- **La silhouette (E1b) attend la vraie profondeur** : devinée depuis le
  détail de la peinture, elle produit des rubans blancs sur le ciel (payé sur
  la maquette v2) — retirée tant que le kit ne fournit pas le masque du sujet.
- **Maquettes** : `maquette-legendaire-2026-09-20/` — `maquette.py` (Python,
  pas le shader ; `--monde foret|cimes|bois`, `--film`), planches ×3 mondes,
  film du cerf (8 s : inclinaison qui va et vient, respiration, feu, neige,
  paillettes). Une planche fixe montre la matière ; le film montre la vie.

## 2. LA LÉGENDAIRE — la matière, effet par effet

Le principe qui remplace le balayage : **la lumière a une cause, et la
peinture elle-même l'accroche.** Deux causes seulement — l'inclinaison du
téléphone (la lampe du monde) et le pouce (la lampe de la main). Et deux
choses qui respirent sans cause, parce que c'est la météo de la carte : les
braises montent, la neige tombe.

En une phrase, ce qu'elle voit : **un cerf gravé dans une lame d'obsidienne,
dont les bois brûlent pour de vrai, sous une neige fine qui tombe entre la
peinture et le verre — et quand elle penche la carte, ce sont les poils du
cerf, un à un, qui attrapent la lumière.** Aucune bande ne traverse jamais.

### E1 — Le relief gravé : la peinture qui accroche la lumière

**Ce qu'elle voit à taille de carte.** Le cerf n'est plus peint : il est
**gravé** dans le verre noir, comme une plaque d'argent ciselée. Quand elle
penche à gauche, sa crinière s'allume par fils, du haut vers le bas ; à
droite, ce sont les arêtes des bois, puis les lignes de la rivière, puis les
bords des nuages. Chaque fil s'allume, puis s'éteint quand son voisin
s'allume. Rien ne traverse : **la lumière se déplace de gravure en gravure**,
comme sur un vrai métal ciselé qu'on tourne sous une lampe.

**Dans un crop zoomé.** Des traits **de 1 px, blanc pur**, qui suivent le
sens du poil, le sens de l'arête, le sens du courant. Entre eux : le noir de
la peinture, intact. Aucun lavis gris, aucun bloom large — au plus 2-3 px de
halo sur les arêtes les plus vives (les bois). C'est le verre du splash
(« cheveux de lumière ») appliqué à une peinture.

**D'où vient la lumière, et son bord.** De l'inclinaison : le gyroscope (ou
le doigt qui penche) déplace une lampe virtuelle. Chaque pixel de la
gravure a une orientation (sa « pente ») ; il s'allume seulement quand sa
pente fait face à la lampe — et la réponse est **serrée** (un exposant de
spéculaire élevé) : un trait est allumé ou éteint, jamais à moitié. Le bord,
c'est le trait lui-même.

**Cuit ou calculé.** **Cuit**, une fois, hors ligne, par carte : une **carte
de relief** (normal map) à la résolution de l'art, faite de trois couches
fondues —
- le **macro** (la profondeur réelle : le cerf devant, la vallée derrière)
  — c'est la depth du § 6, dérivée en pentes ;
- le **méso** (les bords de la peinture : contours du cerf, arêtes des bois,
  lignes du courant, ourlets des nuages) — un champ de tangentes extrait de
  l'image, qui donne à chaque bord une pente dans son sens ;
- le **micro** (la ciselure : une hachure très fine, 1 px, qui suit le sens
  du poil) — posée **seulement** dans les zones de matière (le corps du cerf,
  les bois), jamais sur le ciel ni sur la brume. Les zones viennent du kit
  (§ 6). C'est ce qui fait « texturé », comme les cartes physiques
  embossées.
Au rendu : **un** échantillon de texture de plus dans le passage existant,
et une poignée d'opérations par pixel. Pas de bruit procédural.

**Ce que ça remplace.** Sur la légendaire, le foil-bande **disparaît**. La
Trois Lunes garde le sien, intact. C'est la différence la plus lisible qui
soit : *une carte avec un foil* contre *un objet gravé*.

**La preuve.** Crops à trois inclinaisons (−0,5 / 0 / +0,5), même carte :
on doit voir des traits différents allumés, et le noir entre eux.

### E2 — Les braises : le feu de la carte, pas un effet posé dessus

**Ce qu'elle voit à taille de carte.** Les bois du cerf **brûlent**. Pas un
halo : des braises **naissent aux pointes des bois** — là où la peinture est
déjà orange — se détachent, montent lentement en vacillant, refroidissent et
meurent avant le haut de la carte. En bas, la rivière en lâche quelques-unes
aussi (ses reflets sont chauds). Une quarantaine de braises vivantes en
permanence, carte posée. Quand elle **penche** brusquement, une **bouffée**
part des bois — la cause est son geste — et les braises **traînent** à
contre-sens du mouvement (l'inertie : elles sont *dans* la carte). Quand elle
pose le pouce près des bois, les braises **chauffent** (plus blanches, plus
vives) sous le doigt.

**Dans un crop zoomé.** Trois tailles, en loi de puissance : beaucoup de
**1 px**, quelques **2 px**, rares **3-4 px** avec un halo serré de 5 px
maximum. Une braise naît **blanc-orangé** 100 ms, passe **braise** (1,0 ·
0,55 · 0,18), puis **rouge sombre** (0,6 · 0,12 · 0,02), puis s'éteint en
point noir. Chaque braise a sa propre période de vacillement et sa propre
phase — **jamais deux qui bougent ensemble**, jamais un métronome. Aucune
n'est carrée, aucune n'est floue.

**D'où vient la lumière, et son bord.** Elles sont leur propre lumière ;
leur bord est leur taille (1 px = un bord). Leur *cause* : la carte (les
sources sont ses pixels chauds) et le geste (la bouffée, l'inertie, le
pouce).

**Cuit ou calculé.** Les **sources** sont cuites : un **masque de braise**
par carte (les pixels chauds de l'art, seuillés et affinés — les pointes des
bois, les reflets de la rivière, l'horizon). Les braises elles-mêmes sont
calculées dans le passage de shader, comme aujourd'hui (grille de cellules,
une braise par cellule, budget fixe) — mais en **trois couches** (les trois
tailles, trois vitesses), **ancrées au masque** (une cellule n'accouche que
si elle touche une source), avec un vecteur « bouffée » (vitesse
d'inclinaison) et un point « pouce » en entrées. Aujourd'hui les braises
n'existent qu'en plongée, sur une zone de profondeur, à une seule taille,
sans source ni geste.

**Sur les autres raretés.** Aucune braise au repos. (La Trois Lunes garde
ce qu'elle a.)

**La preuve.** Film de 10 s carte posée ; film de 5 s avec un coup de
poignet (la bouffée) ; crop d'une braise à chaque âge.

### E3 — La neige : il neige entre la peinture et le verre

**Ce qu'elle voit à taille de carte.** Une neige **fine** tombe, lente,
**devant** la peinture et **sous** le verre. Trois profondeurs : les flocons
lointains sont des points minuscules et lents ; les proches sont un peu plus
gros, un peu plus rapides, et **bougent plus** quand elle penche (la
parallaxe vend qu'ils sont dans l'épaisseur). Quand elle penche, la neige
**s'incline** (le vent, c'est son geste). Téléphone immobile plus de trois
secondes : la neige **se calme** (une dérive clairsemée) ; un geste : une
**rafale** brève, puis le calme revient. Dans le cône du pouce (E4), les
flocons qui passent **s'allument** — un catch-light — et retombent gris.

Et en haut, dans le ciel de la carte, les **étoiles** (la poussière de
diamants d'aujourd'hui) : trois fois plus nombreuses, en loi de puissance
(presque toutes 1 px, quelques-unes 2 px), qui **scintillent** à
l'inclinaison — chacune à son angle propre, comme aujourd'hui.

**Dans un crop zoomé.** Un flocon = un cœur **blanc dur** de 1-2 px, sans
halo — sauf la couche proche : 3 px de bloom. Les formes viennent d'un
**petit atlas cuit** de huit poussières réelles (pas huit gaussiennes) :
au zoom, deux flocons ne se ressemblent pas. Le noir de la peinture reste
noir entre eux.

**D'où vient la lumière, et son bord.** Les flocons sont blancs par
eux-mêmes ; leur bord est leur taille. Leur cause : la météo de la carte
(la neige tombe) et le geste (le vent, la rafale, le pouce qui les allume).

**Cuit ou calculé.** L'atlas est cuit. La chute est calculée comme les
braises (trois grilles décalées, une par profondeur, vitesses et gîtes
distinctes, jitter par cellule) — le même mécanisme que la grille de
braises d'aujourd'hui, retourné vers le bas. **Le piège** : elle voit une
grille tout de suite (« peau de girafe »). Parades : trois couches
décorrélées, jitter fort, tailles en loi de puissance, phase par flocon,
atlas de formes — et **la preuve en crop** avant de dire que c'est bon.

**Sur les autres raretés.** Pas de neige : c'est **le temps qu'il fait sur
une légendaire**. Les étoiles ×3 restent légendaires aussi.

**La preuve.** Film de 10 s au repos, puis avec un geste ; crop 4× d'un
coin de ciel.

### E4 — La lampe : le pouce éclaire la gravure

**Ce qu'elle voit.** Elle pose le pouce sur le cerf : autour du doigt, sur
~110 pt, **la gravure s'allume** — les traits E1 sous le pouce prennent la
lumière, comme une lampe de poche sur un métal ciselé. Elle glisse : la
lumière **suit avec un temps de retard** (60 ms, la masse — pas un curseur).
Elle relâche : elle **s'éteint en 0,5 s**. Les braises sous le pouce
chauffent (E2), les flocons qui le traversent s'allument (E3). **Rien ne
bouge tant que le doigt ne bouge pas.**

**Son bord.** Le cône a un bord visible : une lumière pleine au centre,
une chute nette sur les 20 derniers points, pas un dégradé qui s'étale sur
toute la carte.

**Ce que ça remplace.** La « caresse » d'aujourd'hui (frotter allume le
foil-bande plus fort) : sur la légendaire, frotter n'allume plus une bande,
ça allume **ce qui est sous le doigt**. C'est le pattern validé du slider
(« la lampe : le pouce est la source »).

**Cuit ou calculé.** Calculé : une position et une intensité de plus en
entrée du shader ; la lumière de E1 devient la somme de deux lampes (le
monde, la main).

### E5 — Le verre : une lame, pas une feuille

**Ce qu'elle voit.** La carte a une **épaisseur**. Quand elle penche, un
**cheveu de lumière de 1 px** apparaît sur le chant du côté qui fait face à
la lumière — et **disparaît de l'autre côté** (l'asymétrie du verre du
splash, validée après six itérations). Sur 10-12 pt le long du chant, l'art
se **réfracte** : décalé de 2-3 pt à contre-sens de l'inclinaison, comme
sous un biseau. Le reflet de vitre d'aujourd'hui (une nappe douce qui glisse)
est **retiré** sur la légendaire : c'est une bande, donc non.

**Dans un crop zoomé.** Le cheveu : 1 px blanc pur, bloom 3-4 px maximum,
noir absolu de part et d'autre. Le biseau : la peinture qui « plie » sur
quelques points, sans flou.

**Cuit ou calculé.** Calculé, sur la géométrie du cadre déjà mesurée (le
SDF du rectangle arrondi existe dans le shader) — deux termes de plus.

### E6 — Le filigrane : le cadre argent, gravé lui aussi

**Ce qu'elle voit.** Le cadre argent n'est plus un trait plat : une
**rainure**. Quand elle penche, l'un des deux flancs de la rainure
s'allume (un cheveu), l'autre s'éteint ; à l'inclinaison inverse, c'est le
contraire. Les **quatre croissants** sont des rainures aussi : ils
s'allument avec le cadre, dans le même sens. Aucune lueur, aucun halo.

**Cuit ou calculé.** **Cuit** : `bake_cadre_legendaire.py` fabrique déjà le
PNG argent ; on lui ajoute une **carte de relief du cadre** (les deux flancs
de chaque ligne), fondue dans la carte de relief E1. Au rendu, rien de plus
que E1.

### E7 — La braise qui respire, la lune qui cligne : la micro-vie

**Ce qu'elle voit.** Les pointes des bois (les pixels chauds du masque E2)
**respirent** : une lueur qui monte et retombe, sur deux houles
incommensurables (7,3 s et 1,9 s — le « halo deux houles » qu'elle a
validé), donc jamais la même deux fois. Le croissant de lune de la carte a
un **catch-light** : un point de 1 px qui pulse apériodiquement, comme un
œil. Tout cela est **minuscule** — c'est ce qu'on voit quand on regarde
longtemps, pas ce qu'on voit en premier.

**Cuit ou calculé.** La position de la lune vient du kit (§ 6) ; le reste
est deux sinus dans le passage existant.

### E8 — Le grain de nuit

Un grain argentique très fin (0,035, la valeur validée sur le variant TOP)
sur toute la carte ouverte : il casse le « propre » numérique, il fait
photographie. Calculé, un terme.

---

### Ce que la légendaire N'a PAS

- pas de foil-bande (il reste à la Trois Lunes) ;
- pas de nappe de vitre qui glisse ;
- pas d'éclair au dévoilement, pas de balayage à l'arrivée sur la
  collection, pas de lobe qui se croise — **aucune lumière sans cause** ;
- pas de couleur : blanc, argent, braise très sombre, rouge de braise qui
  meurt. Rien d'autre.

### L'échelle des quatre

| | Une Lune | Deux Lunes | Trois Lunes | Quatre Lunes |
|---|---|---|---|---|
| lumière | foil doux | foil d'aujourd'hui | foil d'aujourd'hui (intact) | **gravure** (E1) + lampe (E4), aucune bande |
| objet | carte | carte | carte | lame : chant, biseau, filigrane rainuré (E5, E6) |
| vie | — | — | brume qui dérive | braises depuis les sources (E2), neige à trois profondeurs (E3), respiration, catch-light (E7) |
| profondeur | vraie | vraie | vraie | vraie, + relief cuit |
| entrer dans la carte | non | non | oui (plans, air) | oui + le dos gravé |
| cérémonie | sachet | sachet | sachet | la porte de lumière (§ 3) |
| collection | — | — | — | vignette cuite en relief, registre argent |

---

## 3. La cérémonie — elle sort de la lumière (sans éclair)

| temps | ce qu'elle voit | ce qu'elle sent / entend |
|---|---|---|
| 0,0 s | **noir total**, le sachet a disparu | silence |
| 0,4 s | **un point blanc** au centre — une étoile — qui s'étire en **un cheveu vertical de 1 px** | le grondement grave enfle (`RocketHaptics`) |
| 0,9 s | le cheveu s'écarte en **une fente** de 12 pt, deux bords nets : une porte de lumière | — |
| 1,2 s | **le chant de la carte sort de la fente** : un trait vertical blanc de 1 px — son biseau éclairé par la porte — puis la lame **tourne vers elle** sur 1,2 s. En tournant, **sa gravure prend la lumière de la porte, arête après arête**, comme un objet qu'on tourne sous une lampe (E1 éclairé par la porte, pas par le gyroscope) ; les bois s'allument en dernier | le grondement monte ; le shimmer de poussière |
| 2,4 s | face à elle : **les braises se réveillent** aux bois (E2), **la neige commence** (E3) | la note de sacre légendaire |
| 2,6-4,0 s | **la porte se referme derrière la carte** et meurt : le monde s'éteint, il ne reste que la carte, éclairée par ses braises et ses cheveux de lumière. **Le temps ralentit** au tiers : la neige tombe lentement, les braises restent suspendues | deux battements doux quand elle se pose |
| 4,0 s | le temps reprend ; sous la carte, **gravé** : LE SOUVERAIN · Quatre Lunes · La Forêt des Veilles | — |

Option collection (backend, session serveur) : **« exemplaire n° 12 »** —
le rang de cette acquisition parmi toutes celles de la référence
(`user_cards` connaît les acquisitions ; une lecture). La carte numérotée.

Une orange sort du sachet ; une légendaire sort d'une porte de lumière qui
se referme sur elle. Rien ne tremble, rien n'explose : un point, un cheveu,
une lame, du temps ralenti.

---

## 4. Entrer dans la carte (remplace la plongée) — et le dos

Tap sur la carte ouverte :

- **Le verre s'ouvre.** Le cadre se dissout dans le noir, la scène s'étend
  bord à bord (1,2 s), **les plans se séparent** : le cerf vient devant, la
  vallée recule, le ciel plus loin. Caméra multiplane : quatre plans
  découpés et inpaintés (`gen_layers.py`, `CarteLuneWorld` + `carteLuneAir`
  — **écrits, débranchés** en attendant de vrais plans).
- **C'est elle qui bouge.** Gyroscope et doigt = la caméra glisse entre les
  plans ; pincer = avancer jusqu'à ×2 sur des plans à la résolution de la
  scène (jamais de flou). L'air entre les plans : la brume, et **les braises
  qui montent des bois** (le masque E2, plus une coordonnée fixe) ; la neige
  tombe devant tous les plans.
- **La lampe marche dedans** : le pouce sur le cerf éclaire sa gravure.
- **La créature vit** (à trancher sur UN essai, après E2/E3/E7 qui la font
  déjà respirer) : une boucle vidéo de 4-6 s générée en atelier à partir de
  la scène validée — décodage matériel, coût processeur quasi nul — jouée
  sous la gravure. Risque : le « fake » d'une vidéo générée ; verdict en
  crop et en mouvement avant d'en demander une deuxième.
- **Pas de durée.** Glisser vers le bas → la scène se recompose, le cadre se
  reforme, le verre se referme.
- **Le dos.** Glisser sur le côté → la carte se retourne, le chant passe
  (E5) : dos noir, filigrane rainuré (E6), nom, monde, quatre croissants,
  exemplaire. Un objet, pas un écran.

Les Trois Lunes ont l'entrée (plans, air) — sans braises ni neige ni dos.
Même look, plus juste, et une plongée qui ne zoome plus sur des pattes.

---

## 5. Dans la collection (sans balayage)

- Registre **Quatre Lunes** : pips blancs, titre argent, rangée un peu plus
  haute.
- Vignettes légendaires : **cuites** avec la gravure éclairée d'un angle
  fixe (haut-gauche), les cheveux du chant, quelques braises et flocons
  figés — une **photographie de l'objet**. Statiques. Aucun moteur sur la
  grille (règle du 19-09).
- Dos vides du registre légendaire : noirs, quatre croissants en rainure.
- Rien à l'arrivée sur la page. La lumière a une cause ou elle n'est pas.

---

## 6. Le kit par carte — ce que l'atelier livre avec chaque PNG

À demander à la session Cartes production (`publier_catalogue.py`) ; les 14
publiées le reçoivent après coup, leurs pixels ne changent pas :

| rareté | livré avec le PNG |
|---|---|
| toutes | une **vraie carte de profondeur** (estimation monoculaire, hors ligne, une fois) |
| Trois Lunes | + **4 plans** découpés et inpaintés |
| Quatre Lunes | + les plans ; + la **carte de relief** (E1 : macro + méso + micro, avec les **zones de matière** où la ciselure vit) ; + le **masque de braise** (E2) ; + la **position de la lune** (E7) ; + la **vignette cuite** (§ 5) ; + une boucle vidéo **si** l'essai du cerf convainc |

Tout se cuit une fois, sur le Mac, par des scripts à côté de `gen_depth.py`
et `gen_layers.py`. Rien de procédural au rendu.

---

## 7. Le coût, honnêtement (skill chauffe chargé)

- Tout vit dans **un** passage de shader, celui qui tourne déjà à 60 Hz
  quand une carte vivante est visible : E1 = un échantillon de texture de
  plus ; E2/E3 = le mécanisme de grille d'aujourd'hui, ×3 couches ×2
  populations ; E4/E5/E6/E7/E8 = des termes. **Aucune couche SwiftUI en
  plus, aucun flou, aucun `blendMode`, aucune horloge en plus.** Mais le
  profil est déjà 🔴 (`b-chauffe75-profil-systeme`, thermique 2 sur 76,
  correctif non re-mesuré) : **rien ne se pose sans la paire (cadence,
  processeur), thermique 0 au départ, A B B A.**
- Nouvelle fonction `carteLuneV6` (l'arité d'un stitchable est soudée —
  piège payé), un paramètre `finition` + les entrées lampe/bouffée + les
  textures du kit. Barreaux : `-sansRelief`, `-sansBraises`, `-sansNeige`,
  `-sansLampe` — chaque effet doit pouvoir être accusé seul.
- La cérémonie : 4 s, une fois, page noire (la home démontée derrière).
- Le diorama : 4 plans + air à 60 Hz **pendant que c'est ouvert**, une
  carte. Jamais mesuré sur son téléphone. Barreau `-sansMonde`.
- La vidéo : matérielle, quasi rien côté processeur ; mais un shader sur une
  vidéo ne met rien en cache → la gravure devient un calque additif
  au-dessus, la vidéo joue en dessous **sans masque**. À prouver sur un cerf.
- Reduce Motion : neige et braises figées en pose cuite, pas de diorama,
  cérémonie en fondu, carte lisible.
- Grille : rien n'y tourne.

---

## 8. Ordre de réalisation, si elle dit oui

1. **La gravure (E1) sur le cerf** : relief cuit à la main pour cette seule
   carte, banc `-luneLab -luneRarete legendary`, **crops à trois angles**
   côte à côte avec la Trois Lunes au même angle (`-luneTilt`). Son verdict
   avant tout le reste. Une journée (la cuisson est le gros).
2. **Braises (E2) et neige (E3)** : films au repos et au geste, crops. Une
   journée. Le piège de la grille se prouve ici.
3. **Lampe, verre, filigrane, micro-vie, grain (E4-E8)**. Une demi-journée.
4. **La cérémonie** sur le cerf, film sim. Une demi-journée.
5. **Le diorama** : plans faits à la main pour le cerf, `CarteLuneWorld`
   rebranché, entrée/sortie/dos. Une journée.
6. **Mesures iPhone** : Trois vs Quatre Lunes en main ; carte ouverte vs
   diorama ; chaque barreau. Sans ça, aucune pastille ne bouge.
7. **Le kit** demandé à la production pour les 5 autres légendaires ; site
   de doc dans le même commit.

Rien ne touche le backend ni le tirage — sauf l'option « exemplaire n° ».
Le téléphone : étape 6, coordonnée dans `MULTI-SESSION.md`.

---

## 9. Ce qui n'est pas prouvé ici

- Aucune capture, aucun film, aucune mesure. Les fiches sont des intentions
  de rendu, à **montrer en crops** ; elle regarde les crops.
- La cuisson du relief (E1) sur une peinture très sombre : la qualité du
  champ de tangentes et de la ciselure est à vérifier sur le cerf avant de
  promettre six cartes.
- La neige et les braises en grilles : le risque « peau de girafe » est
  réel ; c'est l'étape 2, et c'est elle qui juge.
- Le coût de tout ça sur son iPhone : inconnu ; le profil est déjà 🔴.
- « Exemplaire n° » suppose une lecture serveur non écrite.
