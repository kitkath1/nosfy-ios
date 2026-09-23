# Le lecteur de séance — où on en est

**Mis à jour le 23-09-2026, après codage de l'ouverture.** Ce fichier existe parce que ce chantier
a produit six plans contradictoires en une journée. Le voici démêlé.

---

## ✅ CE QUI EST FAIT ET VALIDÉ par Kathryn

Commité en **`e7cc9ef8`** :

- le lecteur tient toute la séance ; « Page exercices » est retiré ;
- **la home reste derrière du Go jusqu'à la story** — c'est ÇA qui a réglé
  « je vois encore la page exercice », et c'était une cause structurelle,
  pas cosmétique : le bouton changeait d'onglet et l'onglet ne revenait
  jamais ;
- le pied ne porte que le Stop, aucun bouton ne propose d'exercice.

Dans l'arbre, **non commité**, et elle a dit « c'est nickel » :

- les cinq carrés réservés au mode CHOISIR ;
- le chevron du retour, à gauche du carré de date ;
- la braise qui respire dans le header pendant la séance ;
- la série en cours portée par une braise.

Captures : <https://claude.ai/artifact/BCyvc6t4eQVaeVFh9jZnyn>

---

## 🔴 CE QUI EST REFUSÉ — onze propositions de transition

Le cercle blanc, le flou, la comète, la flamme noire (huit passes
successives : rampe douze paliers, langues, déformation de domaine, trois
nappes, poussée d'Archimède, filaments, exposition, roussissure), la
simulation de fluide, la card qui devient l'écran, la carte qui se retourne.

**Toutes refusées.** Ses mots : « trop cheap », « horrible », « hyper fake »,
« ça fait 10 essais horribles ».

⚠️ **Elle a testé le feu AU SIMULATEUR, en mouvement.** Ce n'est donc pas un
problème d'images fixes : c'est l'effet.

Les plans de ces directions sont dans `archives-refusees/`, avec leurs
scripts de rendu. **Ne pas les reprendre sans qu'elle le redemande.**

---

## ✅ CODÉE ET QUI TOURNE : l'ouverture en particules

**C'est SA demande, formulée par elle le 23-09 au soir**, après onze refus :

> « je veux de la matière, du shader, de l'ouverture magique, avec des
> milliers de particules inférieures à 0,6 px, like three.js — particules
> noir, orange, rouge »

`particules-2026-09-23/` — **l'écran se défait en dizaines de milliers de
particules.** Chacune naît à l'endroit d'un vrai pixel et en emporte la
lumière ; elles montent, s'enroulent, refroidissent du blanc chaud au rouge
de braise puis au noir. L'écran suivant apparaît derrière.

Planche : <https://claude.ai/artifact/UAXNDrV7Axm1nVUbhkq5Sa>
Script de rendu : `particules-2026-09-23/particules.py`

### Ce qui fait le grain — et une seule chose compte

⭐ **LE DÉPÔT SOUS LE PIXEL.** Chaque particule est répartie sur ses quatre
pixels voisins au prorata de sa position fractionnaire : elle n'occupe
jamais un pixel entier. **C'est ça, « inférieur à 0,6 px »**, et c'est
impossible à obtenir avec du bruit.

Puis : un **champ en ROTATIONNEL** (divergence nulle → les particules
tournent sans s'entasser, c'est lui qui fait les volutes) ; chaque particule
**emporte la luminosité du pixel d'où elle vient** (l'écran se défait en
lui-même, il ne se couvre pas) ; une **rampe de huit paliers** du blanc
chaud au noir, aucune autre couleur.

### ⚠️ L'ARCHITECTURE, et c'est la bonne nouvelle

**Un pipeline de POINTS Metal**, dans un petit calque dédié : un sommet par
particule, sa position calculée dans le VERTEX shader à partir d'une graine
et du temps. **Aucun travail sur le processeur, aucune particule stockée, un
seul appel de dessin.** Le champ rotationnel tient dans une texture 128×256
cuite par script.

**C'est deux ordres de grandeur moins cher que le feu** : le shader de feu
fait douze lectures de texture PAR PIXEL, soit des millions ; ici c'est une
lecture par particule, soit quelques dizaines de milliers.

### ✅ CODÉE le 23-09, dans l'arbre, NON COMMITÉE

`Nosfy/Views/OuvertureParticules.swift` + `Nosfy/Views/Particules.metal` +
l'asset `particules-curl` (cuit par `particules/cuire_curl.py`). Un seul
raccord dans `NosfyApp.swift` : `couvercles` monte `Ouverture()`. **Aucun des
sept appelants de `CoupeEtat.jouer` n'a changé.**

Filmée sur le VRAI Go au simulateur, avec ses crops ×3 :
<https://claude.ai/artifact/JVwUjT1znhp2vssHcr7VqD>

Bancs : `-sansOuverture` (le barreau), `-ouvertureLab <p>` (figée à
l'avancement `p`), `-ouvertureBoucle` (elle rejoue sans fin).

### ⚠️ LES QUATRE PIÈGES PAYÉS EN LA CODANT — ne pas les rejouer

1. **Un fragment ne reçoit pas la structure de sortie du sommet.**
   `[[point_size]]` y est interdit : il faut une seconde structure, étiquetée
   `[[user(...)]]`, et `[[stage_in]]`.
2. **C'EST LE NOMBRE QUI FAIT LA MATIÈRE.** 60 000 points ⇒ luminance
   moyenne **2,4** sur 255. 320 000 ⇒ **0,6** une fois le voile posé. De la
   poussière, deux fois. Il en faut **900 000**. Grossir les points donne du
   coton, les éclaircir donne du néon : seule la densité marche.
3. **Le planton est l'effet, pas le bonus.** Faire naître la braise de la
   luminosité de l'écran est ce qui rend le passage crédible — mais cette
   app est NOIRE. Sans une émission de base forte, il ne se passe rien.
4. **UNE SEULE CHOSE DOIT ÉTEINDRE.** La rampe, l'éclat ET un facteur d'âge
   s'éteignaient ensemble : la braise était noire au quart de sa vie et le
   front n'avait pas de traîne (écran vide à l'avancement 0,58). La rampe
   finit déjà sur du noir : elle suffit.

⚠️ **Et un piège de BANC** : `-ouvertureLab` fige l'horloge mais ne
photographie rien — un banc qui ne passe pas par `jouer` montre un effet
mort et fait croire à un échec. Tous les bancs appellent `jouer`.

**Pas encore jugée par elle. Aucune chauffe mesurée sur son iPhone.**

---

## 💤 SECONDE OPTION, non jugée : le verre

`verre-2026-09-23/` — l'écran devient une dalle de verre fumé qui pivote :
perspective vraie, Fresnel, réfraction, une tranche d'un pixel qui s'embrase
à la perpendiculaire.
Planche : <https://claude.ai/artifact/2LSKqVTJpM8z9Fp7j3XrVm>

Proposée AVANT qu'elle demande les particules. Elle ne l'a pas jugée. À
garder sous le coude, pas à construire sans son mot.

---

## 🧹 LA FLAMME NOIRE EST SUPPRIMÉE (23-09)

`FlammeNoire.swift`, `FlammeNoire.metal` et les imagesets `flamme-bruit`,
`flamme-warp`, `flamme-rampe` sont **retirés du dépôt**. `-sansFlamme` et
`-sansCoupe` survivent comme **alias** de `-sansOuverture` : ils sont cités
dans les plans depuis le 22-09.

`CoupeEtat.jouer` garde sa signature exacte, donc **aucun appelant n'a
changé** (NosfyApp ×4, PiluleVagabonde, ExercisesView, ExerciseDetailView).

---

## 📌 CE QUI EST PLUS UTILE QU'UNE TRANSITION

Trois chantiers commencés, aucun fini, tous dans
`PLAN-LA-FLAMME-NOIRE-2026-09-23.md` (§ chantier 2) :

1. **les événements** — la série validée qui s'imprime dans le papier, le
   ticket de séries qui bascule, la rangée qui pousse les autres ;
2. **les quatre vibrations** — la série validée (le moment le plus fréquent
   de la séance, et il est muet), la rangée qui tombe, les carrés qui
   s'ouvrent, le Stop à deux coups ;
3. **le champ de recherche** en tête de la liste d'une zone.

---

## ⚠️ Rappels qui valent pour toute reprise

- **Aucune chauffe n'a jamais été mesurée** sur le lecteur.
- **Rien de tout ça n'est commité** sauf `e7cc9ef8`. L'ouverture, la
  suppression de la flamme et les réglages du lecteur attendent son ordre.
- **L'ouverture est branchée sur LES SEPT appels** — le Go, le chevron,
  « Ajouter un exercice », la fiche, le retour. 1,5 s sur un geste fréquent,
  c'est peut-être trop : question posée, pas tranchée.
- **Le dépôt ne compile pas seul** : 12 erreurs d'autres chantiers non
  commités (`tools/production/testflight-83-2026-09-22/`).
