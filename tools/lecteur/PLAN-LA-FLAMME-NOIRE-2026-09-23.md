# Le lecteur de séance : la flamme noire, et une interface qui répond

**Plan pour une prochaine session. RIEN N'EST CODÉ.**
Dicté par Kathryn le 23-09-2026, après avoir vécu le build 83 sur son iPhone.

Planche visuelle, tout calculé sur les vraies captures :
<https://claude.ai/artifact/Bm7uhJb4YTHAjFhRtavoUA>
Maquettes et scripts de rendu : `maquettes-2026-09-23/`.

---

## 0. Ce qui est MORT, et qu'il ne faut surtout pas reconstruire

Ce plan remplace une première version écrite le matin même. Deux choses y étaient
proposées, **toutes deux refusées par Kathryn dans la journée** :

- ❌ **Le cercle blanc** (`Nosfy/Views/CoupeBlanche.swift`, posé le 22-09) :
  « la transition blanche est trop cheap », « elle est horrible l'animation ».
  Une forme géométrique blanche sur du noir se lit comme un effet de logiciel.
- ❌ **Le point qui respire** près du titre, et ❌ **le sticker « EN COURS »** :
  « pas un simple point qui respire : cet effet est trop cheap », « supprime le
  sticker En cours ». Et plus largement : « évite les animations génériques comme
  les pulsations ou les points qui respirent ».

**Ce qui reste validé du build 83** : les séries avec le « 01 », les flammes, le
nombre de sets. Elle le dit explicitement. Ne pas y toucher.

---

## 1. Ce qu'elle demande

> « l'expérience manque encore fortement d'impact visuel et de micro-interactions »

Trois chantiers :

1. **« Ajouter un exercice »** — animer le fond du bouton ET de la page entière.
   « L'environnement doit réagir et guider naturellement le regard vers l'ajout. »
2. **« Exercice en cours »** — animer le fond général, animer le sticker carré de
   la date, **mettre en évidence la série en cours**, micro-animations premium sur
   les séries et les transitions d'état. « L'utilisateur doit comprendre
   immédiatement qu'une séance est active grâce au comportement global de
   l'interface, pas grâce à une simple étiquette. »
3. **La transition** — « beaucoup plus spectaculaire et mémorable […] une grande
   flamme noire qui apparaît, explose et se diffuse dans l'écran, avec un impact
   visuel puissant, un blur dynamique et une déformation ».

---

## 2. LA THÈSE, qui tient tout le reste

> **« Vivant » ne veut pas dire « qui boucle ». Ça veut dire « qui répond ».**

C'est pour ça que la pulsation sonne faux : elle tourne qu'on fasse quelque chose
ou non. Le sentiment qu'une séance est active vient de ce que **chaque geste
laisse une marque**.

Conséquence directe, et c'est la règle d'ingénierie de ce plan : **presque tout
est un ÉVÉNEMENT, donc gratuit au repos.** Un seul moteur continu, celui qui
existe déjà.

---

## 3. LA LIGNE À NE PAS FRANCHIR

**Un passage peut être cher. Un fond, jamais.**

- La flamme dure 0,64 s. Dix fois par séance = six secondes de calcul cher. On a
  le droit d'y mettre un shader, un flou, une déformation.
- **Un fond animé dure 45 minutes, dans une salle, souvent dans une poche.** Une
  page immobile de cette app coûte déjà **27 à 39 % de processeur** (mesures du
  05-09). Un fond vivant de plus, c'est le téléphone qui chauffe et la home qui
  gèle par vagues — le gros bug du 14-09.
- **Donc : le fond ne gagne AUCUN moteur neuf.** Il réutilise `BraisesVague`, qui
  tourne déjà dans le lecteur à 15 img/s, gelée hors pose. On change son foyer et
  son intensité : deux valeurs.

⚠️ Charger `.claude/skills/woop-performance/SKILL.md` avant la première ligne.

---

## 4. Chantier 1 — « Ajouter un exercice » : le feu remonte sous le bouton

Maquette : `maquettes-2026-09-23/ajout.jpg`.

- Les cinq carrés **quittent l'état « en cours »** (montés seulement si
  `seanceVide` ou `zone != nil`). C'est l'idée de Kathryn, et c'est elle qui sépare
  les deux états d'un seul coup.
- À leur place, **« Ajouter un exercice » en pointillés, sous la tête**, à place
  fixe. Il remplace la rangée du bas de la partition (donc retirer `onAjouter`
  de `SlateListe`).

### ⚠️ L'ALLER-RETOUR — un seul bouton, au même pixel, qui se retourne

Précision de Kathryn le 23-09 au soir : « les carrés disparaissent, ils
n'apparaissent que quand on clique sur ajouter un exercice **et la page change**,
mais je peux revoir aussi l'état de la session en cours ».

Donc une machine à deux états, et **un seul bouton pour les deux sens** :

| État | Corps | Le bouton, au MÊME pixel |
|---|---|---|
| **Ta séance** | la partition | `+ Ajouter un exercice` |
| **Choisir** | les cinq carrés, **SOUS le bouton**, puis la liste | `← Ma séance` |

Les carrés arrivent **sous** le bouton, jamais à sa place : le pouce apprend une
position, pas une icône. Même loi que le Stop, qui ne bouge jamais d'une séance.
Maquettes : `maquettes-2026-09-23/ajout.jpg` et `choisir-retour.jpg`.

### Les DEUX ÉCHELLES DU MÊME FEU

Changer d'écran et changer de contenu ne sont pas le même geste.

- **La grande flamme** — changer d'écran (le Go, la fiche, le retour) : l'écran
  brûle entièrement, 0,64 s, shader sur photographie. Chantier 3.
- **Le foyer qui monte** — changer de contenu (ta séance ⇄ choisir) : la vague de
  braises **surgit une fois** et, quand elle redescend, le contenu a changé.
  **Aucun moteur de plus**, deux valeurs poussées puis relâchées, ~0,3 s.

Brûler veut dire « tu changes d'endroit ». Le foyer qui monte veut dire « tu
restes ici, mais tu changes de métier ». Deux signaux, jamais confondus, tirés de
la même matière.
- **Le foyer de `BraisesVague` monte et se ramasse derrière le bouton.** Le bouton
  est un trou dans la matière : à travers ses pointillés, on voit le feu.

⚠️ **Ce n'est pas un balayage** (loi rappelée quatre fois) : la lumière ne
traverse pas l'écran, elle **monte depuis sa source** — le foyer qui est en bas
depuis le premier jour — et s'arrête où il y a quelque chose à faire.

---

## 5. Chantier 2 — « En cours » : les événements

Maquette : `maquettes-2026-09-23/encours-fond.jpg`.

| Ce qui répond | Le geste | Coût |
|---|---|---|
| **La série validée s'imprime** | la rangée descend d'1 pt, l'encre fonce, le « +20 » et la lune arrivent de la droite au ressort, une vibration nette | événement |
| **Le ticket de séries bascule** | le nombre TOURNE comme un panneau d'aéroport, il ne se fond pas — c'est du papier | événement |
| **La rangée qui arrive pousse les autres** | au retour d'un exercice, elle glisse depuis sous la tête | événement |
| **La série EN COURS, pas l'exercice** | « Set 3 » se détache : numéro blanc plein, les autres gris, cheveu blanc de 1 pt à gauche | statique |
| **Le foyer suit la séance** | plus chaud et plus près pendant une série, calme entre deux | 2 valeurs |
| **La carte du jour prend la lumière** | relief cuit ; l'inclinaison du téléphone fait glisser la lumière dessus | ⚠️ gyroscope |

⚠️ `SlateRang` est **PARTAGÉ AVEC LA STORY DE FIN** : tout ajout passe par un
paramètre optionnel, valeur par défaut = comportement actuel.

⚠️ Le gyroscope est la seule vraie prise de risque : il a chauffé le téléphone le
21-09 parce qu'il ne s'arrêtait jamais. Il ne revient qu'avec sa porte — lecteur
ouvert, écran allumé — et **en dernier**, seulement si la chauffe des autres
laisse de la place.

### Les vibrations qui manquent

- une série validée : un coup net (c'est le moment le plus fréquent, et il est
  muet aujourd'hui) ;
- la rangée qui tombe dans la liste : un coup doux ;
- les carrés qui s'ouvrent : un coup léger ;
- le Stop : deux coups, pas un.

Jamais deux vibrations qui se chevauchent, rien pendant un geste continu.

---

## 6. Chantier 3 — La flamme noire

Huit images rendues sur les vraies captures :
`maquettes-2026-09-23/f1.jpg` → `f8.jpg`. Le script qui les produit :
`maquettes-2026-09-23/flamme.py` — **ce n'est PAS le code de l'app**, c'est la
démonstration de la direction.

**Le principe.** Du point que le pouce touche, le feu part et mange l'écran. Le
front porte **un cheveu blanc** au c&oelig;ur et une **braise qui meurt** derrière.
Ce qui a brûlé est **noir absolu**. Le verre gondole au bord. Puis le lecteur
arrive de l'avant, encore trouble, et se pose.

Minutage rendu : 0 · 90 · 190 · 290 · 380 · 470 · 560 · 640 ms.

**Comment ça se fait.** Un shader sur une **photographie** de l'écran qu'on
quitte (`ImageRenderer` ou un instantané de couche) :

1. un champ de bruit fractal, **biaisé par la distance au point touché** — c'est
   ce biais qui donne sa CAUSE à la flamme ;
2. un seuil qui monte : sous le seuil, noir ;
3. une bande étroite devant le seuil : braise, avec un c&oelig;ur blanc encore plus
   étroit ;
4. un déplacement le long du gradient du masque : la déformation.

Une passe, une texture, rien n'est redessiné.

**Pourquoi c'est ça et pas autre chose** : Nosfy est une app de braises — sticker
flamme sur la carte du jour, flammes sur les séries, foyer rouge au bas de chaque
écran. Une app qui brûle doit brûler pour changer d'écran. Ce n'est pas un effet,
c'est sa matière.

Barreau obligatoire : `-sansFlamme` (et `-sansCoupe` disparaît avec le cercle).

---

## 7. L'ordre de travail

1. ✅ **FAIT le 23-09, dans l'arbre, non commité.** Les carrés quittent « en cours »,
   le bouton en pointillés à place fixe, son retournement en « Ma séance », et le
   titre qui suit le mode. Banc `-lecteurChoisit`. Build vert, trois états capturés
   au simulateur : <https://claude.ai/artifact/BCyvc6t4eQVaeVFh9jZnyn>
   **Reste à voir sur son iPhone, et la bascule n'a pas encore le foyer qui monte
   (point 3) : pour l'instant c'est un ressort, pas du feu.**
2. **Les événements** : la série qui s'imprime, le ticket qui bascule, la rangée
   qui pousse, la série en cours mise en évidence. Aucun ne tourne au repos.
3. **Le foyer qui suit la séance** et qui monte sous le bouton. Deux valeurs.
4. **La flamme noire.** À mesurer avant de garder.
5. **Le gyroscope sur la carte du jour**, en dernier et sous condition.

---

## 8. Ce qui reste à trancher avec elle

- **D1** — La durée de la flamme : 0,64 s, c'est long pour dix passages par séance.
- **D2** — Le feu part-il du point touché, ou toujours du bas de l'écran ?
- **D3** — Les flammes des séries restent-elles des emoji système, ou deviennent-
  elles le sticker de l'app ? (L'emoji casse le noir de l'écran.)
- **D4** — ✅ **TRANCHÉ le 23-09** : les carrés disparaissent complètement, et
  n'apparaissent que sur « Ajouter un exercice ». Le retour se fait par le même
  bouton, retourné en « Ma séance ».

---

## 9. Ce qui est vrai au moment où ce plan est écrit

- Build TestFlight **83** posé et en test (`tools/production/testflight-83-2026-09-22/`).
- Le lecteur de séance est commité en `e7cc9ef8`.
- **Aucune chauffe n'a jamais été mesurée** sur le lecteur, le cercle blanc compris.
- La rangée « Ajouter un exercice » du bas de la partition n'a **jamais été vue
  rendue** : le simulateur ne fait pas défiler.
- ⚠️ **Le dépôt ne compile pas seul** : 12 erreurs venues d'autres chantiers non
  commités (voir
  `tools/production/testflight-83-2026-09-22/HEAD-NE-COMPILE-PAS-SEUL-2026-09-22.md`).
