# Simuler le feu, puis le cuire — la seule voie qui reste

**Plan pour une prochaine session. NON RÉSOLU CE SOIR : lire le §5 en entier
avant de recommencer.**

Verdicts de Kathryn, 23-09 au soir, dans l'ordre :
« pas assez réaliste et fin, trop trop cheap » → « encore plus » →
**« c'est pas du tout assez réaliste, c'est hyper fake »** →
**« et plus lent, qu'on voie la combustion élégamment »**.

---

## 1. LE CONSTAT, et il est définitif

**Le bruit empilé restera du bruit.** Quatre passes l'ont montré : rampe à
douze paliers, langues, déformation de domaine, trois nappes empilées,
poussée d'Archimède, filaments nets, exposition qui se ferme. Chaque passe
améliore, aucune ne franchit la barre du « vrai ».

**La cause est structurelle : le bruit fractal n'a pas de TOURBILLONS.** Une
flamme est un fluide. Ses vortex, ses enroulements, ses décrochements
viennent de la mécanique, pas d'une somme d'octaves. Aucun `fbm`, si déformé
soit-il, ne les fabrique.

---

## 2. LA VOIE : simuler une fois, cuire, lire

On ne dessine plus le feu, on le **SIMULE hors ligne**, puis on cuit le
résultat en atlas. C'est exactement la loi de la maison — « cuit par script à
la publication » — et à l'écran **ça coûte UNE lecture de texture**.

C'est aussi, paradoxalement, **beaucoup moins cher** que le shader actuel :
plus de bruit à déformer, plus de nappes à empiler. Un atlas, un index de
temps, une interpolation.

### Le solveur (Stam 1999, suffisant)

Écrit dans `simu.py` de ce dossier :

- advection semi-lagrangienne du carburant et de la chaleur ;
- **flottabilité** : le chaud monte, proportionnellement à sa température ;
- **CONFINEMENT DE VORTICITÉ** — l'étape qui fait tout. Elle réinjecte les
  petits tourbillons que la grille mange. Sans elle, une simulation de feu
  est molle et ressemble à de la fumée ;
- projection (Poisson par Jacobi) pour l'incompressibilité ;
- combustion : le carburant s'allume au-dessus d'un seuil, devient chaleur,
  la chaleur diffuse vers le carburant voisin et propage le front.

### Ce qu'on cuit

Un atlas de N images (16 à 24 suffisent, interpolées) portant deux canaux :
**R = carburant restant** (ce qui a brûlé), **G = température** (la couleur,
via la rampe de corps noir déjà cuite dans `flamme-rampe`).

⚠️ Le front doit partir **du point touché**. Deux façons : simuler plusieurs
foyers et choisir, ou simuler un front générique et le PLIER au runtime par
la distance au doigt. La seconde est plus simple et suffit.

---

## 3. ⚠️ LES TROIS ÉCHECS DÉJÀ PAYÉS SUR LE SOLVEUR — ne pas les rejouer

1. **LES TACHES PLATES.** Grille 170×340, taux de combustion 0,34, peu de
   vorticité → de grandes zones orange uniformes à bords durs. **Pire que le
   bruit.** Il faut une grille fine (≥ 260×520) et une zone de réaction
   ÉTROITE.
2. **L'EXTINCTION SUR PLACE.** Taux 0,055, dissipation 0,952, diffusion 0,30
   → le front n'avance pas, la flamme meurt. **La diffusion est ce qui
   PROPAGE** : la chaleur doit passer au carburant voisin pour l'allumer.
3. **L'EMBRASEMENT PUIS LA MORT.** Taux 0,20, dissipation 0,974, diffusion
   0,62 → 46 % de l'écran brûle en 60 pas, puis la chaleur tombe à zéro et
   plus rien ne bouge. **C'est l'état où le plan s'arrête ce soir.**

**Le réglage est un équilibre à trois, et il ne se trouve pas au hasard :**
taux de combustion × dissipation × diffusion. La bonne méthode est de tracer
« % brûlé » et « chaleur max » à chaque pas (le script le fait déjà) et de
chercher une progression LINÉAIRE du brûlé avec une chaleur max STABLE. Tant
que la chaleur max s'effondre, le réglage est faux.

---

## 4. ⚠️ ET ELLE VEUT PLUS LENT

« Plus lent, qu'on voie la combustion élégamment. » La transition actuelle
dure 0,64 s. Viser **1,1 à 1,4 s**, et accepter que ce soit long : c'est un
moment, pas un passage. À trancher avec elle, parce que ça se voit dix fois
par séance.

Corollaire technique : plus c'est lent, plus il faut d'images dans l'atlas
(24 plutôt que 16), et plus l'interpolation entre images doit être propre.

---

## 5. L'ÉTAT VRAI, ce soir

- **Ce qui TOURNE dans l'app** : le shader une-nappe (`FlammeNoire.metal` +
  `FlammeNoire.swift`), déclenché aux trois passages, vérifié au film.
  Textures `flamme-bruit`, `flamme-warp`, `flamme-rampe` cuites.
  Bancs : `-flammeLab <p>`, `-flammeSonde`, `-sansFlamme`.
  **Elle le juge FAKE. Il ne restera pas.**
- **Ce qui est ÉCRIT mais pas intégré** : `cuire_flamme.py` cuit déjà
  `flamme-warp` (déformation de domaine + poches) que le shader n'utilise
  pas encore.
- **Ce qui est ÉCRIT et NON RÉSOLU** : `simu.py` (le solveur) et
  `rendu_simu.py` (le rendu sur capture). Le solveur marche mécaniquement,
  son réglage de combustion est faux — voir §3.
- **Rien n'est mesuré sur son iPhone.** Rien n'est commité.

---

## 6. L'ordre pour la prochaine session

1. **Régler le solveur** jusqu'à une progression linéaire du brûlé et une
   chaleur max stable. C'est 80 % du travail, et ça se fait entièrement en
   Python, sans toucher à l'app.
2. **Montrer les images** à Kathryn AVANT de coder quoi que ce soit. Si la
   simulation ne la convainc pas en image fixe, elle ne la convaincra pas à
   l'écran.
3. Cuire l'atlas, remplacer le shader (il devient trivial : une lecture).
4. Mesurer la chauffe sur son iPhone, avec `-sansFlamme` pour comparer.
