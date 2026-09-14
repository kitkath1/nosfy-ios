# LE FOYER V2 — LA BASCULE (verdict de Kathryn, 06-09 : **0/10**)

> ⚠️ **DÉPASSÉ PAR LE V3** (`PLAN-FOYER-V3.md`, « LE RASANT ») — ce fichier reste
> pour son §1 : le diagnostic MESURÉ du calque, qui a donné les lois du V3.

> Ses mots, sur la capture `captures/foyer-05.png` : « pourquoi il y a une sorte
> de **gros calque** !! » · « le bouton **Terminer pas clair du tout** ??? » ·
> « on voit pas les **braises se réfracter** ! » · « **ni les widgets en mode
> blur dans le noir** » · « c'est **super moche** !!! » · « je veux que ça soit
> **aligné sur le côté gauche comme Apple** » · « il **manque le nombre de
> séries faites** » · « bref **pas assez Apple, pas beau du tout, 0/10** ».
>
> Le V1 (`PLAN-FOYER.md`) garde tout ce qui a été VÉRIFIÉ (le code, les pièges,
> les bancs, le protocole de mesure). **Ce document remplace sa partie DESIGN.**
> Rien n'est codé depuis le verdict.

---

## §1 · LE CALQUE — la cause, MESURÉE sur sa capture

| point de mesure | RGB |
|---|---|
| « vide » à gauche (y = 900) | (26, 27, 31) |
| « vide » au centre (y = 900) | (29, 30, 34) |
| « vide » à droite (y = 900) | (29, 30, 34) |
| même zone, 600 px plus bas | (30, 30, 35) |
| haut de la page | **(30, 20, 18)** |

**Deux faits, et ils suffisent :**

1. **La valeur ne bouge pas d'un bord à l'autre ni de haut en bas** (3/255
   d'écart). Un dégradé dont la somme est constante **n'est plus un dégradé,
   c'est un aplat** — donc une plaque grise posée sur du noir. C'est ça, le
   « gros calque », et il est de moi : `LueursFoyer` empilait TROIS nappes
   radiales de rayon **plus grand que l'écran** en `.blendMode(.plusLighter)`.
   Additionnées, 0,17 + 0,13 + 0,10 donnent une constante. J'ai monté leur force
   parce qu'« on ne les voyait pas » — je les ai rendues visibles en les
   transformant exactement en ce que le dépôt appelle un calque.
2. **Elle est FROIDE (B > R de 5) pendant que le haut de l'écran est CHAUD
   (R > B de 12).** Deux ambiances qui se contredisent sur le même écran : c'est
   la seconde raison pour laquelle ça se lit comme un objet POSÉ, et pas comme
   une profondeur.

⚠️ **LA LOI QUI EN SORT** (elle manquait, elle est payée) :
**un halo ne se voit que par son GRADIENT. Si son rayon dépasse l'écran, il n'y
a plus de gradient : il n'y a qu'un voile.** Un halo doit avoir du **vrai noir
autour de lui**, sinon ce n'est pas une lumière, c'est un fond.

---

## §2 · LA BASCULE — la lumière vient du FEU, jamais d'un voile

C'est le cœur du V2, et ça règle trois de ses griefs d'un coup.

**Avant (faux)** : un voile gris au milieu de l'écran pour « faire premium »,
et une braise décorative en bas.

**Après (juste)** : **il n'y a qu'UNE source de lumière dans cet écran, et c'est
le feu en bas.** Tout le reste est noir. Ce qu'on voit « briller » ailleurs,
c'est cette lumière-là **RÉFRACTÉE** — et ce qui la réfracte, ce sont **les
widgets en verre, flous, dans le noir**.

C'est exactement ce que sa capture d'origine montrait, et ce que la mesure du V1
§7 disait déjà : *la lumière ne venait pas des cards, elle venait de ce qui
passait à travers leur verre.* Le V1 en avait fait une question ouverte (D4) ;
son verdict la tranche : **les widgets reviennent, en verre, très flous, dans le
noir — et c'est eux le « premium »**, pas un halo.

> **Une seule source, et tout ce qui brille est une réfraction.**

---

## §3 · TOUT À GAUCHE — et c'est ÇA, « comme Apple »

Sa correction la plus importante, et la plus simple : **plus rien n'est centré.**

Aujourd'hui la phrase est à gauche (x 24) et tout le reste est **centré** : le
signe, le chrono, le bouton, « Terminer ». Un écran qui aligne son titre à
gauche puis centre tout le reste n'a pas de colonne — il a deux mises en page
qui se disputent, et l'œil ne trouve aucune arête à suivre. **C'est ça qui fait
« pas Apple », plus que n'importe quel réglage de lumière.**

→ **UNE colonne, une seule arête : x = 24**, celle de la phrase. Tout s'y aligne.

---

## §4 · L'ÉCRAN, PIÈCE PAR PIÈCE

| pièce | avant | après |
|---|---|---|
| la phrase | à gauche, 4 lignes | **inchangée** — c'est la seule chose qui allait |
| le signe « séance en cours » | centré | **à gauche**, sur l'arête |
| **le compte de séries** | absent | **REVIENT** — « il manque le nombre de séries faites ». À gauche, sous le signe ou collé au chrono (§7) |
| le chrono | centré, 72 pt | **à gauche**, même corps |
| le bouton | capsule centrée | **à gauche**, ou pleine largeur de la colonne (§7) |
| « Terminer » | centré, blanc 0,38 | **à gauche**, et **remonté en contraste** (§6) |
| le fond | un voile gris | **NOIR. Rien.** Le calque meurt. |
| les widgets | absents | **en verre, très flous, dans le noir** — ils réfractent le feu |
| la braise | un halo plat en bas | la **source unique**, en bas, et **on doit la voir se réfracter** dans le verre au-dessus |

---

## §5 · LE COÛT DU VERRE — pourquoi ce n'est PAS le même cas qu'avant

Le skill `woop-performance` dit : le verre pèse **le quart**, et *« un verre posé
sur une vidéo ne peut RIEN mettre en cache : ce qu'il y a dessous change à chaque
image »*.

⚠️ **Ici, ce qu'il y a dessous NE CHANGE PAS** : la vidéo de fond est démontée en
séance (V1 §9), il ne reste que du noir. Un verre sur un fond **constant** peut
cacher son backdrop — c'est une situation structurellement différente, et
favorable. **Mais je ne l'ai pas mesurée, et je ne l'affirme pas.**

La conséquence de conception, elle, est immédiate : **le verre ne doit pas
recouvrir la braise.** Si le verre chevauche la zone qui bat, son backdrop
redevient vivant et on repaie le poste n°1.

→ **La braise vit SOUS les widgets, pas derrière eux.** Ce qu'on voit d'elle dans
le verre, c'est ce qui déborde par en dessous et lèche leur bord bas. C'est
aussi, visuellement, la bonne réponse : une lumière qui vient **d'en dessous**.

---

## §6 · « TERMINER PAS CLAIR »

Deux causes, et la première n'est pas le contraste :

1. **Il était posé sur mon calque gris**, pas sur du noir : blanc 0,38 sur (30,30,35)
   ne fait plus un lien discret, il fait un mot effacé. Le calque parti, la moitié
   du problème part avec.
2. **0,38 est trop bas de toute façon.** À monter, et à mesurer sur les **pixels
   clairs** (jamais en moyenne de ligne). Cible : lisible sans devenir un bouton
   — on ne met pas de lumière sur ce qu'on ne veut pas encourager, mais on
   n'efface pas une sortie.

---

## §7 · CE QUI RESTE À TRANCHER — 4 questions, courtes

1. **Le compte de séries : où ?** Collé au chrono (« 18:52 · 3 séries »), ou une
   ligne à part sous le signe ? *(défaut : une ligne à part, sous le signe.)*
2. **Le bouton : pleine largeur de la colonne, ou capsule calée à gauche ?**
   *(défaut : pleine largeur — c'est ce qui lit le plus « Apple ».)*
3. **Le grand vide entre la phrase et le chrono** : on le garde (c'est du noir
   assumé), ou on remonte le bloc bas ? *(défaut : on remonte — aligné à gauche,
   le vide se lit déjà mieux, mais 35 % reste beaucoup.)*
4. **Les widgets flous : lesquels ?** Les deux du haut seulement, ou aussi la
   card route ? *(défaut : les deux du haut.)*

---

## §8 · LES JALONS — et le premier est une CAPTURE, pas du code

| jalon | geste | preuve |
|---|---|---|
| **J1** | **Tuer le calque** : `LueursFoyer` supprimée. Le fond redevient noir. | Capture + **mesure** : la zone vide doit retomber sous (12,12,12), et R ≥ B (jamais froid). |
| **J2** | **Tout à gauche** + le compte de séries + « Terminer » lisible. | Capture. C'est le jalon du GOÛT : c'est là qu'elle dit si « Apple » est atteint. |
| **J3** | **Les widgets en verre, flous, dans le noir**, la braise dessous. | Capture — et **c'est elle qui dit si la réfraction se voit**. Puis `-sondeVol` sur téléphone froid : le verre sur fond constant coûte-t-il vraiment moins ? |
| **J4** | Le morph (V1 §4), toujours en attente de sa décision D1. | Film, seul. |

⚠️ **J1 et J2 avant toute autre ligne.** Le calque et l'alignement sont les deux
défauts qu'elle a nommés en premier ; tant qu'ils tiennent, aucun réglage de
lumière ne sera jugeable.

---

## §9 · CE QUE J'AI MAL FAIT, pour ne pas le repayer

1. **J'ai monté une lumière parce qu'on ne la voyait pas, sans me demander
   POURQUOI on ne la voyait pas.** La réponse était : parce qu'un halo plus large
   que l'écran n'a pas de gradient. Monter sa force ne pouvait donc produire
   qu'un aplat — c'était prévisible à l'arithmétique, avant la capture.
2. **J'ai centré le mobilier sous un titre aligné à gauche** et je ne l'ai pas
   vu, alors que c'est le défaut le plus visible de la capture.
3. **J'ai retiré le compte de séries de la page** alors que sa phrase visait la
   PASTILLE. Le V1 §7 bis avait pourtant écrit noir sur blanc que « le nombre de
   reps ne remplace pas le compte de séries » — je l'ai noté, puis fait quand
   même l'erreur que je venais de décrire.
