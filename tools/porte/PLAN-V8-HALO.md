# PLAN V8 — LE HALO : TUER LES CERCLES, RENDRE LE ROUGE DIFFUS

Verdict Kathryn du 26-08 : « les cercles ronds et halo sont trop saccadés,
l'animation n'est pas fluide, je veux du fondu, quelque chose de très fluide
et beau dans le design — le cercle rouge n'est pas assez diffus ».

**Rien n'est codé.** Le diagnostic ci-dessous est mesuré ET lu dans le code,
et les deux concordent au rayon près.

---

## 1. LES « CERCLES RONDS » NE SONT PAS UN ARTEFACT — ILS SONT ÉCRITS

`LogoMonolith.metal`, lignes 1391-1401. Deux anneaux gaussiens **explicites**,
posés à la main :

```metal
// L'ANNEAU DE HALO — le cercle de glace des nuits froides, le
// 22 degrés des photographes de lune. Un cerne fin, à peine là.
float ringD = (rC - mix(172.0, 118.0, blood)) / mix(30.0, 22.0, blood);
float ring  = exp(-ringD*ringD) * 0.032 * night.x
            * (1.0 + 0.6*smoothstep(0.55, 0.90, blood));
// Au pic, le cerne se DÉDOUBLE
float ring2D = (rC - mix(280.0, 192.0, blood)) / 34.0;
ring += exp(-ring2D*ring2D) * 0.013 * night.x * smoothstep(0.50, 0.85, blood);
```

L'intention est belle (le halo à 22° des photographes de lune). **Le réglage,
lui, est faux d'un facteur cinq.**

### La preuve, par le calcul

Au pic du sang (`blood = 1`), au rayon 118 pt — le centre de l'anneau :

| couche | valeur |
|---|---|
| halo diffus (`skyE`, ciel clair) | **0,0103** |
| ANNEAU 1 à son sommet | **0,0512** |

**L'anneau est 5,0× plus brillant que le halo qu'il est censé souligner.** Le
commentaire dit « à peine là » ; le chiffre dit qu'il domine. Un liseré cinq
fois plus fort que la nappe qu'il ourle, ce n'est plus un cerne : c'est un
cercle dessiné.

### La preuve, par la mesure à l'écran

Profil radial dans un secteur VIDE (loin du ventre du croissant), à t = 3,1 s :

```
  r =  90 pt   5,14   ← le creux
  r = 105 pt   6,81
  r = 120 pt   8,25   ← LE SOMMET DE L'ANNEAU  (+60 % sur le creux)
  r = 150 pt   5,53
  r = 185 pt   2,13
```

Le sommet mesuré tombe à **120 pt**. Le code place l'anneau à **118 pt**.
Le code et l'écran disent la même chose.

⚠️ **Piège de mesure à ne pas repayer** : un profil radial pris depuis le
centre de l'écran est INEXPLOITABLE ici — la source est un CROISSANT, pas un
point, et sa géométrie fabrique de fausses bosses. Il faut mesurer dans un
secteur angulaire vide.

---

## 2. LE SANG AGGRAVE LE DÉFAUT — TROIS FOIS, ET DANS LE MÊME SENS

C'est pour ça que Kathryn voit **le cercle ROUGE** et pas les autres :

| ce que fait `blood` | effet |
|---|---|
| le halo se CONTRACTE (échelle 150 → 96 pt) | ×0,64 |
| le halo S'ASSOMBRIT (`1 − 0,35·blood`) | ×0,65 |
| l'anneau S'ÉCLAIRE (`1 + 0,6·smoothstep`) | **×1,60** |

**Le rapport anneau/halo est multiplié par 4,5 entre l'état ① et l'état ③.**

L'intention « la lumière meurt, le cerne se resserre » est juste. Mais un cerne
doit mourir AVEC la lumière qui le crée, pas s'allumer quand elle s'éteint —
là, physiquement comme graphiquement, c'est à l'envers.

---

## 3. « PAS ASSEZ DIFFUS » — LA NAPPE EST TROP MAIGRE ET TROP COURTE

Deux causes, mesurables :

1. **L'amplitude de base est 0,055** (`skyE = moonGlow * (0.055 + 0.16*cloud)`).
   La nappe n'existe vraiment que là où il y a des nuages ; sur ciel clair elle
   est quasi absente, et c'est l'anneau qui tient tout le champ.
2. **Elle tombe trop vite** : Moffat d'exposant −1,35 sur une échelle réduite à
   96 pt au sang. Mesuré, la falaise est brutale — de 43,3 à 22,4 entre 55 et
   60 pt, soit **−48 % en cinq points**. Une lueur diffuse ne perd pas la
   moitié de sa valeur en cinq points ; c'est un bord, pas un fondu.

---

## 4. CE QUE JE PROPOSE

L'ordre compte : chaque point se mesure avant de passer au suivant.

1. **Renverser la loi de l'anneau.** Il doit s'éteindre avec la lumière, pas
   s'allumer : `×1,6` → un facteur qui DESCEND avec `blood`. Et son amplitude
   passe sous celle de la nappe au même rayon — c'est la définition d'un cerne.
   **Cible : anneau ≤ 0,5× le halo diffus local**, contre 5,0× aujourd'hui.
2. **L'élargir en même temps qu'on le baisse.** Une gaussienne de 22 pt de
   large est un TRAIT. À 60-80 pt elle devient une respiration du champ, ce
   qui est l'effet cherché — et un bord large ne peut plus se lire comme un
   cercle.
3. **Le second anneau (192 pt) : je propose de le SUPPRIMER.** Il n'apparaît
   qu'au pic du sang, exactement quand la scène doit être la plus simple, et
   c'est lui le « deuxième cercle ». Le halo à 22° existe dans la nature ;
   deux cernes concentriques sur un écran de téléphone lisent « cible ».
4. **Épaissir la nappe** : monter l'amplitude de base (0,055) et allonger la
   portée au sang (96 pt est trop court), pour que le champ tienne le rayon
   120 pt de lui-même. C'est ça, « diffus ».
5. **Adoucir la falaise des 55-60 pt** : vérifier la passation entre le bloom
   du tube (`bloomE`) et la nappe de nuit (`skyE`). Une chute de 48 % en 5 pt
   est une couture entre deux couches, pas un dégradé.
6. **Le dither.** Une fois la nappe élargie, elle vivra dans la plage 2-12/255,
   là où l'OLED bande. `WoopGrain` est déjà posé sur la scène ; il faudra
   VÉRIFIER qu'il suffit (et le fichier a déjà un dither de la DONNÉE au
   § « terrasses », ligne 595 — la technique est connue de la maison).

⚠️ **Aucune de ces valeurs ne se choisit à l'œil.** Le protocole est celui qui
a servi ici : capture figée (`-luneSangFreeze <t>`), profil radial **dans un
secteur vide**, et le critère chiffré du point 1.

⚠️ **Ce shader est partagé.** `logoMonolith` sert aussi le splash archivé, la
home et le profil. Tout ce qui touche `night.*` doit être vérifié sur ces
écrans-là avant d'être livré — et la loi d'arité des stitchables interdit de
changer la signature sans changer l'appel Swift (page BLANCHE sans erreur).

---

## 5. ET « L'ANIMATION N'EST PAS FLUIDE »

⚠️ **Je n'ai pas encore isolé ça, et je ne veux pas le confondre avec les
cercles.** Deux hypothèses distinctes, à départager avant de toucher quoi que
ce soit :

- **(a) le halo BOUGE par marches** : `night.x` respire désormais (±3 %,
  ajouté aujourd'hui) et `moonGlow` suit `blood`, qui suit la courbe continue.
  Si le champ est quantifié, un anneau de 5× d'amplitude qui se déplace de
  quelques points fait un mouvement d'escalier très visible. Dans ce cas, ce
  sont les points 1-3 ci-dessus qui le règlent aussi — l'anneau supprimé, il
  n'y a plus de contour pour montrer les marches.
- **(b) des images réellement perdues** : le trou de 300-500 ms au démarrage à
  froid, jamais isolé (§ 3a du plan V7). C'est le point 2 de l'ordre de ce
  plan-là et il reste ouvert.

**Je mesurerai (a) avant de coder** : deux captures figées à 0,1 s d'écart au
milieu d'un fondu, et je regarde si le rayon de l'anneau saute ou glisse.

---

## CE QUE J'ATTENDS DE TOI

- **Le second anneau (192 pt), je le supprime ?** (Je recommande oui.)
- **Le premier, tu le veux encore présent** — un cerne à peine perceptible,
  cinq fois plus faible qu'aujourd'hui — **ou complètement parti**, ne laissant
  qu'une nappe qui se fond dans la nuit ?

Le reste (nappe plus épaisse, plus longue, falaise adoucie, dither) part sans
question dès ton feu vert.
