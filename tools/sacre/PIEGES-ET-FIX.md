# LE SACRE — les problèmes payés et leurs correctifs

**Session du 15-08-2026** (20 commits, de `e6c0857` à `d57d7b3`).
Le flow « LE SACRE » = du cercle des boosters à la carte posée dans la
collection. Ce fichier ne raconte QUE cette session : chaque entrée part
du symptôme vu à l'écran, remonte à la cause réelle, donne le correctif.

Banc du flow complet :

    -profilLab -profilSacre -boosterCine -boosterNouveau -boosterRarete legendary

---

## 1. « Le booster tourne à la fin de l'arrachement »

**Symptôme** — le sachet ENTIER culbute sur place, 3 frames, juste après
la rupture. Refusé une dizaine de fois ; deux correctifs précédents
(tuer le tumble de la bande, écrire des triplets d'euler) n'avaient rien
changé.

**Cause réelle** — le pack vit à `eulerAngles.y = π`. À ce lacet, la
décomposition d'euler est ambiguë : le getter rend `(x, π, z)` ou la
forme alternative `(π−x, 0, π±z)` selon le bruit flottant. Or la
respiration animait `eulerAngles.z` (une COMPOSANTE), et le blend-out de
0,15 s de son retrait interpolait vers la valeur RELUE — si la forme
avait basculé, le blend balayait z de 0 à π.

**Correctif** — un nœud **berceau** (`swayNode`), près de l'identité,
entre la racine et le pack : il porte toute la respiration et le
tremblement. Le pack garde son lacet π **statique**, écrit une seule
fois en triplet entier. → `e6c0857`

**La loi** — animer/relire une composante d'euler DÉCOMPOSE (roulette à
lacet π) ; écrire un triplet entier COMPOSE (sûr). Voir aussi §2.

---

## 2. « La carte qui sort en déformation dégueulasse », puis « je n'aime
pas qu'elle tourne »

**Symptôme** — la carte se déforme à la sortie, et une fois sur N elle
culbute en diagonale au lieu de faire un demi-tour propre.

**Causes** — trois, empilées :
1. le pincement ×0,75 hérité du sachet, **grossi par le zoom** ;
2. le dépincement joué pendant le demi-tour ;
3. après `card.transform = world` (le bake), le getter d'euler rend
   **toujours** la forme alternative `(±π, 0, ∓π)` — mesuré par sondes
   compilées. L'animation implicite du flip interpole le vecteur euler
   composante par composante : x ET z balayaient π→0 ensemble.

**Correctifs** — scale uniforme dès la frame du bake (la carte n'est
jamais rendue pincée), orientation renormalisée en triplet canonique, et
surtout : **le flip a été supprimé** sur verdict. La carte sort face
visible et glisse à sa place en translation pure ; le sacre (bloom,
carillon, paume) éclate à l'arrivée. Ce qui ne tourne jamais ne peut plus
culbuter. → `e6c0857`

**Piège annexe** — le **dé-tangage de la caméra** pendant la montée
change la perspective du plan et **se lit comme une rotation de la
carte**. La caméra bouge désormais en z pur.

---

## 3. « Une transformation rouge à la fin du booster »

**Symptôme** — le sachet vire au rouge sombre en mourant.

**Causes** — deux sources : le sillage thermique de la lèvre mixait vers
un rouge sombre `(0.75, 0.12, 0.02)` ; et surtout la mort du sachet
baissait l'**intensité** des néons orange sur fond noir — une baisse
d'orange traverse fatalement le marron (la loi anti-brun : c'est la
saturation qui tient, jamais la luminance qui descend seule). L'audit a
trouvé deux complices : l'omni braise de scène et la `tearLight`
(téléphone) restaient allumées pendant l'effacement.

**Correctifs** — la teinte froide du mix devient un **or profond**
`(1.0, 0.55, 0.18)` ; un uniforme `deathGold` glisse toute l'émission
vers un or-blanc de même luminance en fin de chaîne (donc texture, lune
et lèvre d'un coup) ; l'intensité garde un plancher ; `setEmberLights`
éteint l'omni et la tearLight **avec** le sachet. → `e6c0857`

---

## 4. Le sachet qui s'évapore sur place

**Symptôme** — pas un bug : une demande. « Le paquet doit disparaître
par animation cinématique vers le bas. »

**Correctif** — plus d'opacité qui fond : à `t = 2,9` le sachet **plonge
hors cadre** par le bas (lâché en cubique), doré jusqu'au bout. Ce qui
sort du cadre n'a pas à s'éteindre — et les deux peaux du sachet aminci
n'ont plus à se battre en transparence. → `e6c0857`

---

## 5. « On ne comprend pas la comète » (l'invite du balayage)

**Symptôme** — le point de lumière qui montait au-dessus de la carte se
lisait « paillette », pas « balaie vers le haut ».

**Correctifs, en deux temps** :
- d'abord **la carte qui rêve de partir** : toutes les 3,6 s son nez se
  lève, elle monte comme retenue par un fil, se repose avec un rebond —
  l'objet démontre son propre geste ; l'insistance grandit si personne ne
  répond. Plus **le courant ascendant** : deux couches de poussières qui
  montent, devant et derrière la carte. → `f82612b`
- puis, comme le geste restait implicite, **le chevron de poussière** :
  les poussières convergent en double chevron (la FORME des flèches, la
  MATIÈRE de la maison), il monte en s'éclaircissant, elles se libèrent.
  Candidate alternative gardée au banc : **les feux de piste**
  (`-boosterInvite feux`). → `583d71b`

---

## 6. Les quatre verdicts de l'étage d'enregistrement

| Symptôme | Cause | Correctif |
|---|---|---|
| Poussières trop épaisses | tailles 1,1-3,4 px, opacité 0,5 | 0,5-1,9 px, opacité ≤ 0,28 |
| **La carte est sur le côté** | la bande du courant (`cardW + 96`) était **plus large que l'écran** : un enfant trop large décale toute la pile d'un `GeometryReader` | cadre plein écran sur la TimelineView + bandes bornées à `geo.width` |
| Traits de vitesse « trop cheap » | poussières étirées à l'envol | supprimés → **fumée d'envol** (volutes floues nées sur la trajectoire passée) |
| Lunes et « NOUVEAU » visibles pendant la plongée | l'hôte ignorait la plongée | `onDive` : CarteVivante prévient l'hôte, registre + rêve + courant se taisent |

→ `a28c95a`

---

## 7. « Elle tombe pas à la même hauteur » / « elle dépasse » /
« les dos sont coupés, on voit plus les bordures arrondies »

**Symptôme** — la carte posée ne s'insère pas dans son emplacement : plus
grande que les dos vides, qui eux ont perdu leurs coins arrondis.

**Causes** — deux, dont une que j'avais créée :
1. la rangée d'accueil était **avancée à 1,06** au moment de
   l'atterrissage : la carte visait un slot agrandi et décalé ;
2. un padding de 2,5 pt ajouté aux dos (pour une lune que je croyais
   coupée — la mesure a montré qu'elle ne l'était pas) rendait l'image
   **plus petite que son cadre** : le `clipShape` ne la touchait plus,
   donc **les coins arrondis disparaissaient** (le PNG a des coins
   carrés), et les dos ne remplissaient plus leur gabarit.

**La mesure qui a tout débloqué** — le liseré du dos vide vaut **0,6464**
et celui de la carte forgée **0,6479** : la même silhouette à 0,2 % près.
L'écart venait uniquement des **marges noires** différentes autour des
PNG (6,3 % contre 10,1 %). Et le dos importé dans le projet
(`back_card.png`, 941×1672) n'était pas la bonne image : la bonne
(`empty_card_dos.png`, 2:3) dormait sur le bureau.

**Correctifs** — la rangée se repose avant l'atterrissage ; le padding
est mort ; `carte-dos-vide.png` régénéré depuis la bonne source recadrée
sur son liseré (922×1423) ; l'art des vignettes recadré sur le sien par
`GabaritCarte.vignette()` ; et un **gabarit partagé** (largeur, ratio
0,648, rayon) règne sur les trois vues — dos vide, vignette posée, carte
qui descend. Alignement mesuré à l'écran : **0,0 pt d'écart** en hauteur,
sommet et base. → `1f7aed7`, `d57d7b3`

---

## 8. Les musiques

**Symptômes successifs** — « j'aimais pas la musique », « pas de
carillon, pas de son d'église, pas de gong », « au-delà des ahh : du
piano, de la mélancolie, un côté poétique sombre et majestueux »,
« élégant et volatile, pas mystique, pas féérique, pas bébé, pas fake ».

**Correctifs** — quatre pistes, une par typologie
(`common` / `rare` / `epic` / `legendary`), choisies par la rareté de la
carte et déclenchées à l'appui fort qui fait entrer dans la carte. Puis
**v2, le piano mène** : un piano feutré synthétique (partiels
inharmoniques, marteau doux — jamais une cloche), en phrases éparses de
mi mineur au rubato écrit à la main ; le chœur passe **en retrait** ;
la légendaire monte à mi 5 puis **redescend se poser**. La rare
(`sacre-lune`) est restée intouchée, elle était validée.
→ `ec7eaf5`, `3d3dbb9` — bake : `dd-booster/bake_sacres.py`

**Contrainte de composition** — la plongée ne laisse entendre que ~10 s :
tous les sommets sont écrits **tôt** (4-8 s).

---

## 9. Pièges d'outillage payés dans la session

- **Le staging chirurgical par mots-clés peut orpheliner une accolade**
  seule dans son propre hunk → un commit qui ne compile pas. Toujours
  lire les hunks « laissés » avant de conclure. (Rattrapé par `--amend`.)
- **`-boosterOpen` ne montait pas l'overlay** : il posait la carte dans
  la scène mais laissait `handle.revealed` à faux — le banc ne montrait
  qu'une carte nue, sans registre ni invite. Réparé : il atterrit
  désormais sur le vrai état final.
- **En `appMode` + `-boosterCine`, la galerie ne doit pas être forcée** :
  `autoCeremony` n'arme que sur `mode == .idle`, jamais depuis le manège.
- **HEAD ne compile pas toujours seul** : la session parallèle édite les
  mêmes fichiers. Attendre qu'elle finisse plutôt que de « réparer » son
  code ; ne jamais stager ses hunks (fonds `.clear` de la page profil,
  par exemple).

---

## Ce qui reste ouvert

**À traiter avec Supabase** (les règles de collection, sur décision de
Kathryn — rien ne se fait sans elle) : les totaux des registres sont des
maquettes (4/11/4/6) alors que la forge annonce 25 familles ; le
comportement d'un registre plein ; les doublons ; et le placement quand
le slot visé est hors du défilement horizontal de sa rangée.

**À juger au téléphone** : toute la partition haptique (le simulateur est
sourd), la parallaxe du poignet (pas de gyro au simulateur), et la
fluidité réelle de la cérémonie.

**Sans verdict à l'écran** : chevron de poussière ou feux de piste ;
et le fouettage des trois musiques au piano.
