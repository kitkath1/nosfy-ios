# NOTIFICATIONS V3 — le fondu premium (verdict de Kathryn sur la V2)

Ce plan REMPLACE le §B de `PLAN-NOTIFS-V2.md` et complète son §A. Tout le
reste tient : la dalle noire, la pièce de la maison, le banc `-notifLab`,
`dd-notif`, `kat-notif`.

**Verdict du 28-08, en clair** : « sinon pas mal » — donc on ne rejoue rien
de ce qui est acquis (le mot d'une ligne qui déborde, la lampe du haut, les
zones noires, la pièce au centre, le titre sauté, le count-up). Trois
demandes, et une seule est structurelle.

---

## §A — CARD A : LA BARRE (deux corrections nettes)

### A1. Encore plus fine — 4 → 3 pt

Le trait perd un point. À 3 pt il n'est plus un objet, il est une ligne de
lumière — ce qui est le but quand le sujet de la card est le « +20 ».

### A2. ⚠️ LES GRAINS NE SORTENT PLUS — et pas en baissant l'amplitude

Ton verdict : *« des particules dedans, elles ne sortent pas »*.

La V2 a déjà réduit leur oscillation (±5,8 → ±4 pt) et **ça n'a pas suffi** :
sur la capture, des grains vivent encore au-dessus et au-dessous du trait.
Baisser encore l'amplitude est le mauvais remède — c'est un réglage qu'un
grain un peu gros ou un peu rapide reviendra violer.

**Le vrai remède est un CLIP.** Le `Canvas` pose le chemin de la capsule
REMPLIE (`ctx.clip(to:)`) avant de dessiner un seul grain : à partir de là,
aucune particule ne PEUT sortir — ni au-dessus, ni au-dessous, ni au-delà du
front. Ce n'est plus un réglage, c'est une garantie.

Conséquences à assumer :
- le halo du front et la tête se dessinent **avant** le clip (eux ont le
  droit de déborder : c'est de la lumière, pas de la matière) ;
- les grains deviennent plus fins (rayon 0,35 → 0,9 au lieu de 0,5 → 1,5) et
  plus nombreux (26 → 40) : dans un trait de 3 pt, un gros point bouche la
  jauge, alors qu'un flux dense la fait respirer.

### A3. Ce qu'on ne touche pas

Le dégradé blanc froid → blanc pur, la tête, le halo discret (0,17/15 pt —
il a déjà été corrigé parce qu'il lisait comme un morceau de barre en plus),
la pièce lente qui mord le bord.

---

## §B — CARD B : LA MATRICE, ET LE FONDU DES BORDS

### B0. ⚠️⚠️ LA VIDÉO SPOTLIGHT — CE QUI MANQUAIT

Verdict de Kathryn : *« t'as pas mis la vidéo spotlight »*. Elle a raison, et
c'est la pièce maîtresse : depuis son tout premier message elle demandait
« en mode spotlight », et le mode spotlight de cette app a un fichier —
**`fond-matrice-loop.mp4`** (1080×1426, 14 s), la trame de micro-caractères
traversée par une colonne de lumière qui dérive.

La grammaire est écrite dans la robe `.spotlight` de la card reward, et on
la reprend telle quelle : **« le glyphe rogne tout : la matrice n'existe QUE
dans le mot »**. Les lettres cessent d'être peintes — elles deviennent une
FENÊTRE sur la matrice, et c'est la colonne de lumière de la vidéo qui les
allume en passant.

Ce que ça remplace : la copie claire à plat + le champ radial posé dessus.
Ce que ça garde : la base sombre (la matière des lettres hors lumière), le
halo du haut, les zones noires.

**Les trois lois que ça engage, et qu'on ne discute pas :**

1. ⚠️ **BORD À BORD, C'EST LA SEULE POSE LÉGALE.** Le commentaire de la card
   reward est catégorique : *« une vidéo posée ailleurs qu'en bord de card
   laisse TOUJOURS voir son rectangle — 4 essais, 4 démarcations, 26-08 »*.
   La vidéo occupe donc la dalle ENTIÈRE, `resizeAspectFill`, et c'est le
   glyphe qui découpe. Son noir est vrai (médiane 5-18, 5ᵉ centile 2) : il
   n'y a aucun rectangle clair à cacher.
2. ⚠️ **Le cadrage.** Le fichier est portrait (0,76:1), la dalle fait 2,6:1 :
   en `aspectFill` on n'en voit qu'une **bande horizontale**. C'est sans
   danger — la trame est faite de colonnes, une bande en garde le grain — et
   la colonne de lumière balaie toujours. Mais ça se REGARDE sur capture
   avant d'être déclaré bon.
3. ⚠️ **Le coût.** Un masque sur une couche vidéo force un **rendu hors
   écran de tout le plan à chaque image** (loi payée). La card reward paie
   ce prix sur une card plein cadre ; ici la dalle fait 356×138, l'hors-écran
   est bien plus petit. Acceptable — **mais ça se mesure**, et c'est le seul
   endroit de ces deux cards où une vidéo entre.
   Corollaire : `AVPlayerLooper` (jamais un `seek(.zero)` sur
   `didPlayToEndTime` — il laisse une image noire au raccord), le looper
   RETENU par le coordinateur, et muet.

### B1. ⚠️ LE RENVERSEMENT : le mot ne se COUPE plus, il s'ÉTEINT

C'est le point structurel, et il inverse une décision de la V2.

- **Ce que je te disais au J1** : ta réf « éteint » ses lettres sur les
  côtés, or toi tu voulais du coupé net — donc j'ai écrit une coupe franche.
- **Ce que tu dis maintenant** : *« ils doivent être dégradés et fondus sur
  les côtés de la notification, et top, et bordé comme cette card. »*

Les deux tiennent ensemble, et c'est ça la V3 : **le mot déborde toujours**
(il est plus large que la dalle, donc on n'en voit jamais la totalité —
ton prérequis de rognage est intact), **mais ses bords se noient dans le
noir au lieu d'être tranchés par une arête.**

La technique est celle de `TexteGeant` dans la card reward, à la lettre —
**deux masques croisés** :

1. **Le masque HORIZONTAL** : transparent au bord gauche → plein au tiers →
   plein aux deux tiers → transparent au bord droit. Les lettres sortent de
   la nuit et y rentrent.
2. **Le masque VERTICAL** : le pied se noie franchement vers le bas (la
   grammaire déjà écrite), **et le sommet s'adoucit aussi** — tu as dit
   « et top ». Donc : atténué en haut, plein au milieu, éteint en bas.

⚠️ **Ce que ça coûte, et je te le dis avant de le faire** : la sonde de
rognage change de sens. « L'encre touche le bord » ne veut plus rien dire
puisque le bord est justement là où l'encre s'éteint. La mesure devient
**la largeur rendue du mot contre la largeur de la dalle** — elle doit
rester ≥ 1,25× (aujourd'hui ~1,39×). C'est ça qui garantit qu'on n'a pas
silencieusement rétréci le texte pour le faire « tenir ».

### B2. LE HALO DU SPOT — PLUS FLOU

Ton verdict : *« le halo spotlight plus blur stp !! »*

- **Le cône visible cesse d'être un trapèze.** L'`Eventail` a des FLANCS :
  même fondus, ce sont deux droites, et une droite sur du noir se lit comme
  de l'encre, pas comme de la lumière. Il devient un **dégradé radial très
  large et très doux** accroché au bord haut, sans arête d'aucune sorte.
- ⚠️ **PAS de `.blur`.** La loi du dépôt est sans appel : `.blur` pose un
  voile UNIFORME sur tout le rectangle de son hôte (ce n'est pas un flou
  local), et il coûte **27 img/s par objet** — mesuré. Le « flou » se
  fabrique avec des dégradés à arrêts multiples, jamais avec le modificateur.
- **Le champ posé sur les lettres s'adoucit** : rayon 152 → 170 pt et une
  rampe à quatre arrêts au lieu de trois, pour que le passage lumière/nuit
  soit long.
  ⚠️ **Sans perdre les zones noires** — c'est un acquis mesuré (pic 214 sur
  « OU », creux 8-30 sur « WIN », rapport 7×). Un halo plus doux qui
  éclairerait tout le mot serait une régression, et la sonde le dira : après
  le changement, le rapport pic/creux doit rester **≥ 5×**.

### B3. LE FONDU « PREMIUM » DES LETTRES

- La base descend encore un peu (0,12 → 0,10 en haut) et **son dégradé
  vertical se creuse** : les lettres sont matière en haut, presque rien en
  bas. C'est ce qui fait le « premium » de ta réf — pas un gris uniforme,
  une matière qui meurt.
- L'ombre portée continue reste (chaque rangée porte son ombre : le relief
  coule de haut en bas).

### B4. LE LISERÉ « COMME CETTE CARD »

Ta réf a un bord visible, surtout en haut, là où la lampe le touche. Notre
dalle est à blanc 0,07 → 0,02, c'est-à-dire presque rien.

- Il passe à **~0,16 en haut → 0,03 en bas** : la lumière vient d'en haut,
  le liseré doit le dire.
- Il reste **1 pt** : au-delà ce n'est plus un liseré, c'est un cadre.
- ⚠️ Il s'applique aux **DEUX** cards — c'est le socle commun, et deux
  dalles qui ne portent pas le même bord ne sont plus une famille.

### B5. Ce que je NE fais pas sans que tu le demandes

Ta réf porte un **champ d'étoiles** dans la card. Tu ne l'as pas demandé et
je ne l'ajoute pas : c'est un objet de plus à la cadence de l'écran, sur une
card qui en porte déjà trois. Si tu le veux, dis-le et il entre au jalon
V3-5.

---

## §C — LES JALONS

| # | Ce qui sort | Comment on le juge |
|---|---|---|
| **V3-1** | Card B : **la matrice vidéo rognée par le glyphe** (bord à bord) | capture + **film** — le cadrage de la bande se juge en mouvement |
| **V3-2** | Card B : les deux masques croisés (côtés + haut + bas) | capture + **sonde de largeur** : mot rendu ≥ 1,25× la dalle |
| **V3-3** | Card B : le cône radial doux, le champ élargi | capture + **sonde** : rapport pic/creux ≥ 5× (non-régression des zones noires) |
| **V3-4** | Card A : trait à 3 pt, grains CLIPPÉS, plus fins et plus nombreux | capture + **sonde** : aucune encre de grain hors de la bande du trait |
| **V3-5** | Le liseré des deux dalles | capture |
| **V3-6** | **La cadence**, les deux régimes | `charge.sh` puis mesure — c'est ici que la vidéo masquée se paie |
| **V3-7** | *(optionnel)* les étoiles | seulement si tu le demandes |
| **V3-8** | Ton verdict | — |

La matrice passe en tête : tout le §B se dresse dessus (le fondu des bords
et le champ du spot se règlent CONTRE elle, pas contre un dégradé à plat).

---

## §D — LA DISCIPLINE (inchangée, et elle a déjà servi trois fois aujourd'hui)

1. **`xcodebuild` NU, jamais dans un pipe ni derrière un `echo`.** Payé
   ce soir même : la tâche de fond a rapporté « exit 0 » pendant
   qu'`xcodebuild` sortait **65** — c'est le `stat` du dylib qui a tranché.
2. **`stat` du `Woop.debug.dylib` avant CHAQUE capture.**
3. **Un juge qui affirme ne remplace pas une sonde qui mesure.** Deux fois
   aujourd'hui mon œil a inventé un défaut que la mesure a démenti (une
   « arête verticale » à 6/255), et une fois il a validé un rognage qui
   n'existait pas (0-6/255 sur cent points de dalle). **La mesure gagne.**
4. **Mesurer sur les PIXELS CLAIRS** de la zone, jamais en moyenne de ligne
   (le noir tire tout vers le bas).
5. **La cadence** : `./tools/charge.sh` avant tout `-fps`, et **la vraie se
   mesure sur le TÉLÉPHONE**. Ce que je ne peux pas prouver, je le dis.
6. **Multi-session** : commit par chemins explicites, jamais de `git stash`,
   `git diff HEAD` (l'index ment). `WoopApp.swift` ne porte qu'**un seul**
   hunk à moi.
