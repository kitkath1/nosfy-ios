# ×20 : le feu doit VIVRE

**Plan pour une prochaine session.** Verdict de Kathryn, 23-09 tard :
« pas assez réaliste et fin, trop trop cheap », « plus fou, comme une vraie
braise », « monte le niveau de fois 20 ».

Planches, dans l'ordre où elles ont été faites :
1. le temps + la déformation de domaine — <https://claude.ai/artifact/Fq8gH8KfnnE16j5bXnLfNo>
2. **LE VOLUME** (la cible actuelle) — <https://claude.ai/artifact/Dbo2oxVQjZikw1U1ZXmhun>

Cibles et scripts : ce dossier. `cible.py` (temps + déformation, `c1..c4`,
`t1`, `t2`), **`cible2.py` (LA CIBLE À VISER, `v1..v4`)**.

---

## 0. Où on en est — l'état vrai

**Le shader EST codé et il tourne** : `Nosfy/Views/FlammeNoire.metal` +
`FlammeNoire.swift`, déclenché aux trois passages du parcours, vérifié au film
sur le simulateur. Les textures sont cuites par
`tools/lecteur/flamme/cuire_flamme.py` (assets `flamme-bruit`, `flamme-rampe`).
Bancs : `-flammeLab <p>` (figée), `-flammeSonde` (les textures), `-sansFlamme`.

**Mais il n'est pas au niveau.** Et la cause est précise.

---

## 1. LE DIAGNOSTIC — pourquoi ça se lit « cheap »

> **Dans le shader d'aujourd'hui, le feu AVANCE mais il ne BOUGE pas.**

Sa turbulence est une texture FIGÉE. Un front qui progresse sur un bruit
immobile se lit comme **une image qu'on révèle**, jamais comme une combustion.
Et la forme du front est rectiligne : elle monte tout droit, parce qu'un simple
seuil sur du bruit n'a pas de structure.

Preuve dans la planche : deux rendus au **même avancement**, seule la phase du
temps change — la forme du feu est entièrement différente.

---

## 2. LES TROIS LEVIERS, du plus rentable au plus cher

### Levier 1 — LE TEMPS (presque gratuit, à faire en premier)

Le champ **dérive vers le haut** et les vecteurs de déformation glissent, donc
la forme ÉVOLUE pendant la combustion.

Dans `cible.py` : décalage de `phase*130` px pour le champ, `×1,7` et `×2,3`
avec dérives latérales opposées pour les deux champs de déformation.

**Dans le shader** : deux offsets d'UV pilotés par `avance`. Pas une texture de
plus, pas une passe de plus. **Meilleur rapport de tout le document.**

### Levier 2 — LA DÉFORMATION DE DOMAINE (cheap, gros gain)

On n'échantillonne pas le bruit à `uv`, mais à `uv + vecteur(uv)`, **deux fois
de suite**. C'est CE calcul qui donne les volutes, les léchages, les
enroulements — la structure que le feu a et qu'un seuil n'aura jamais.

Recette mesurée dans `cible.py` (`deforme_domaine`) :

```
x1 = x + (wx-0.5)*26        y1 = y + (wy-0.5)*26
q  = base(x1, y1)
x2 = x + (wy(x1,y1)-0.5)*16 + (q-0.5)*9.6
y2 = y + (wx(x1,y1)-0.5)*16 - 5.6      ← le biais vertical : le feu MONTE
champ = base(x2, y2)
```

**Dans le shader** : deux canaux de déformation à ajouter à `flamme-bruit`
(il en reste un libre : R = champ, G = turb lente, B = turb fine → il faut une
SECONDE texture `flamme-warp` avec R = wx, G = wy). Quatre lectures de texture
au lieu d'une. Reste bon marché.

### Levier 3 — LE FEU DOIT TOUCHER L'ÉCRAN (le plus cher, les 30 % restants)

Aujourd'hui la flamme est un **voile posé PAR-DESSUS** (`colorEffect` sur un
`Rectangle`) : elle ne peut ni roussir l'image, ni l'éclairer, ni la faire
trembler. Il lui faut LIRE ce qu'il y a dessous.

Ce que ça débloque, et rien d'autre ne le donne : la **roussissure réelle** sur
le contenu, la **lumière portée**, la **halation**, le **tremblement de
chaleur**.

**Ce que ça demande** : passer à un `layerEffect` appliqué au contenu de l'app.
⚠️ Piège connu, déjà payé : *le calque d'un `layerEffect` est GONFLÉ de
`maxSampleOffset` de chaque côté et s'adresse en positions NÉGATIVES* — garder
l'habitude du `return half4(rgb, c.a)`.

---

## 3. L'ORDRE, et la mesure

1. **Levier 1** (le temps) — quasi gratuit, mesurer la chauffe.
2. **Levier 2** (déformation de domaine) — cuire `flamme-warp`, mesurer.
3. **Arrêter là si l'iPhone chauffe.** À vue de nez, 1+2 portent les deux tiers
   de l'écart.
4. **Levier 3** seulement si la mesure le permet.

⚠️ **Rien n'est mesuré sur son iPhone**, ni le shader actuel ni la cible.
Barreau : `-sansFlamme`.

---

## 4. Les trois pièges déjà payés sur ce shader — à ne pas rejouer

1. **SwiftUI N'INTERPOLE PAS LES ARGUMENTS D'UN SHADER.** Un `withAnimation`
   sur un `@State` passé en `.float(...)` ne produit AUCUNE animation : le
   corps se rejoue une fois, à la valeur d'arrivée. Remède : un `ViewModifier`
   conforme à `Animatable`, dont `animatableData` porte l'avancement
   (`Combustion` dans `FlammeNoire.swift`).
2. **UNE VUE QUI NAÎT N'ANIME PAS.** Monter le voile et lancer la combustion
   dans la même passe faisait naître la vue déjà à 0,62 : écran noir instantané.
   Remède : monter à zéro, `DispatchQueue.main.async`, puis animer.
3. **LE MINIMUM DES DISTANCES FAIT DES MARCHES.** Six prises de langue prises
   au `min` se voyaient comme six marches, un velours côtelé en travers du feu.
   Remède : additionner des INTENSITÉS pondérées, pas des distances.

Et le quatrième, hérité : **l'arité**. Si la signature du `.metal` change sans
que l'appel Swift suive, SwiftUI ne dit rien et rend le `fill` — écran blanc.

---

## 5. ⭐ LEVIER 0 — LE VOLUME. Celui qui manquait le plus.

Verdict de Kathryn après la première cible : « encore plus, pas assez réaliste ».
Elle a raison, et voici ce qui manquait : **une vraie flamme n'est pas une
surface, c'est un VOLUME.** Une nappe unique sera toujours un décalque.

Rendu dans `cible2.py`. Comparer `c3.jpg` (une nappe) et `v3.jpg` (trois).

### A — TROIS NAPPES, en additif

| Nappe | Rôle | `larg` | `gain` | phase | étirement | langues |
|---|---|---|---|---|---|---|
| **fond** | large, froide, lente | 0,085 | 0,42 | ×0,70 | 0,34 | 34 pas ×2,0 |
| **corps** | porte la combustion | 0,058 | 1,00 | ×1,00 | 0,26 | 22 pas ×1,6 |
| **devant** | fine, chaude, rapide | 0,034 | 0,72 | ×1,45 | 0,18 | **9 pas ×1,3** |

⚠️ **La nappe de devant ne traîne presque pas.** Une longue traînée sur une
nappe fine fait des COLONNES verticales — artefact vu au premier rendu.

### B — LA POUSSÉE D'ARCHIMÈDE

Le feu monte **et accélère en montant** :
`yv = y·(1 − etire·haut) − phase·150·(0,5 + haut)` où `haut = 1 − y/h`.
Le bruit est étiré d'autant plus qu'on est haut, et advecté plus vite.
**Une dérive uniforme fait un tapis roulant, pas une flamme.** Gratuit.

### C — LES FILAMENTS NETS

`fil = (1 − dd/0,006)²`, versé en blanc `1,0 0,97 0,90` à 0,85. Les arêtes les
plus chaudes d'un vrai feu sont RASOIR ; un flou partout donne une aquarelle.
Gratuit.

### D — L'EXPOSITION QUI SE FERME

`expo = 1 / (1 + 2,4 · moyenne(intensité) · 9)`, multiplié sur toute l'image.
Une photo de feu est **sombre autour** : l'appareil expose pour la flamme.
C'est un tell cinéma très fort. Une multiplication.

### E — LES POCHES DÉTACHÉES

26 îlots (points gaussiens de rayon 4–10, aplatis ×1,45 verticalement) montent
de 30 à 170 px et meurent seuls, plus 150 étincelles.
⚠️ **Des POINTS, pas des blocs** : un pavé carré se voit comme un carré, même
flouté (artefact du premier rendu).

---

## 6. LES DEUX QUESTIONS OUVERTES

- **Le bleu de la base.** Dans un vrai feu de papier, la base de la nappe tire
  sur le bleu-violet — combustion complète. C'est l'un des tells les plus forts.
  ⚠️ **Sa loi dit : aucune couleur hors blanc, argent et braise.** Non mis.
  À lui demander.
- **Le feu devrait LIRE l'écran.** Le papier ne brûle pas pareil sur l'encre :
  texte et photos devraient charbonner autrement que le fond. Demande le
  levier 3 (`layerEffect`).

---

## 7. LE COÛT, revu

Trois nappes = **douze lectures de texture par pixel** au lieu de quatre.
Sur 0,6 s c'est peut-être tenable ; **ça ne se décide que sur son iPhone**.

**Repli** : deux nappes (fond + corps) gardent l'essentiel de la profondeur.

**À prendre quoi qu'il arrive, parce que c'est gratuit** : la poussée
d'Archimède, les filaments nets, l'exposition qui se ferme.

## 8. L'ordre revu

1. Poussée d'Archimède + filaments nets + exposition (gratuits).
2. Le temps (levier 1).
3. La déformation de domaine (levier 2).
4. La deuxième nappe, puis la troisième — **mesurer entre chaque**.
5. Le levier 3 (`layerEffect`) seulement si l'iPhone le permet.
