# WELCOME BACK v2 — « You're Back » : le texte géant, la pastille-lune et la chauve-souris qui TIENT la card

**Écrit le 26-08-2026 sur le brief de Kathryn — RIEN n'est codé.**
Deuxième robe de retour, à côté du `.welcome` livré (vidéo portrait +
bouton Claim, commit `9695c38`). Elle emprunte sa grammaire au variant 2
« You Made It » : du TEXTE GÉANT travaillé derrière, un spotlight qui
tombe du haut, et un objet premium au centre.

> **NOTE POUR LE PLAN BACKEND** — Kathryn : « de toute façon les textes
> seront plus tard dynamiques, ils changeront grâce à l'IA, on ne fait
> que les layouts ». Donc : **les mots ne sont JAMAIS en dur dans la
> robe** — ils entrent par paramètre, et la robe doit tenir avec
> n'importe quelle paire de mots courts (1 à 2 lignes, de 3 à 9 signes
> par ligne). À reporter dans `PLAN-REWARDS-BACKEND.md` §4 (la sortie
> de l'IA porte déjà `title`/`subtitle` : y ajouter `bigLine1` /
> `bigLine2` pour les robes à texte géant, avec une longueur MAXIMALE
> contractuelle, sinon la typo casse).

---

## 1. La scène, de bas en haut

1. **La card** — le squelette commun (scrim, dalle noire, verre, voile
   sombre) ; nuit totale, comme les robes à texte géant.
2. **LE TEXTE GÉANT DERRIÈRE** — « YOU'RE / BACK » sur DEUX lignes,
   énorme, rogné par les flancs, en argent qui meurt vers le bas, avec
   son ombre continue (une ligne se porte sur l'autre) et le fondu
   majestueux (côtés + bas) — la recette exacte de `TexteGeant`, qui
   devient donc **paramétrable** (aujourd'hui « YOU / MADE / IT » en
   dur, demain deux ou trois lignes fournies).
3. **LE SPOTLIGHT DU HAUT** — la lampe sans objet (l'ouverture de
   lumière au bord haut) + son éventail diffus, qui BALAIE de droite à
   gauche ; la lumière posée sur le texte suit la même horloge
   (`balayageSpot`, déjà partagée).
4. **LA PASTILLE-LUNE au centre** (§2).
5. **LA CHAUVE-SOURIS QUI TIENT LA CARD**, au-dessus du bord haut (§3).
6. L'encre : pas de bloc titre (le texte géant EST le message), le
   sous-titre calme en bas, le bouton **Claim** de verre à la pièce
   (celui du `.welcome` v1, déjà écrit) et le lien « Later ».

---

## 2. LA PASTILLE-LUNE — l'objet du centre

**L'asset** : `~/Desktop/pailette_lune.png` (1254 × 1254, fond noir,
PAS d'alpha) — une pastille carrée à coins arrondis, noire et
PAILLETÉE, avec la lune gravée en creux et un liseré de crête clair.
Elle est superbe telle quelle : on ne la retouche pas, on l'ÉCLAIRE.

- **Elle bouge** : flottement lent (deux ou trois horloges premières
  entre elles, comme la flamme du variant Fire) + une inclinaison de
  quelques degrés qui suit le gyro. ⚠️ Rappel de la loi payée : PAS de
  `rotation3DEffect` sur un verre natif — ici la pastille est une IMAGE,
  donc la rotation 3D lui est permise (c'est le bouton Claim, lui, qui
  interdit le tilt à toute la card).
- **Elle est ÉCLAIRÉE** — c'est là que se joue le premium :
  - une **nappe spéculaire** qui balaie sa face au rythme du spotlight
    (même horloge) : le paillettage s'allume au passage de la lumière ;
  - un **liseré de crête** qui tourne avec l'inclinaison ;
  - la **lune gravée** qui prend un souffle chaud quand le faisceau la
    traverse (masque limité au creux de la lune) ;
  - des **paillettes** propres à la pastille : 10-14 étoiles infimes
    masquées PAR sa silhouette (la recette `Scintilles`), plus denses
    du côté éclairé.
- **Le fond noir de l'asset** : la pastille est carrée sur du noir — sur
  une card noire ça se fond, mais son coin peut se deviner. Deux
  parades : soit un détourage alpha au préalable (le noir devient
  transparent), soit un masque radial doux au montage. **À trancher sur
  capture** — la seconde est gratuite, la première est plus propre.
- Option (à valider) : la pastille est **saisissable** comme le galet
  (drag + ressort + haptique). Belle idée, mais elle ajoute un geste sur
  une card qui en a déjà deux (Claim, Later) : à ne faire que si le
  reste est calé.

---

## 3. LA CHAUVE-SOURIS QUI TIENT LA CARD

**L'asset** : `~/Desktop/chauve_qui_tient.png` (1448 × 1086, fond noir,
pas d'alpha) — la chauve-souris de face, ses deux pattes griffues
agrippées au bord haut d'un **rectangle blanc** (le repère que Kathryn a
mis pour dire « ici, la card »).

**Le travail d'asset (bloquant, à faire avant tout code)** :
1. **Enlever le rectangle blanc** : alpha = 0 sur le blanc pur — les
   GRIFFES, elles, sont sombres et doivent SURVIVRE (elles doivent
   déborder par-dessus le bord de la vraie card, sinon l'illusion
   tombe).
2. **Enlever le fond noir** : la chauve-souris déborde AU-DESSUS de la
   card, sur le scrim — un rectangle noir s'y verrait. Détourage par
   luminance (alpha = luminance) avec un seuil doux, puis vérification
   sur fond clair ET sur le scrim.
3. Sortie : un PNG à alpha, recadré au plus juste, importé comme
   imageset (`sticker-chauve-tient`).

**Le montage** : elle vit dans un `overlay(alignment: .top)` de la card,
décalée vers le haut pour que **ses pattes chevauchent le liseré** — la
card semble suspendue à elle. Sa largeur : ~70 % de la card.
⚠️ Piège de la fente : elle est plus large que son ancrage → elle vit
hors layout (overlay sur `Color.clear`), sinon elle élargit la card.
⚠️ Piège du clip : la card clippe son contenu — la chauve-souris doit
donc être montée **par-dessus** la card, pas dedans.

**Son animation** : un balancement très lent (elle « porte » un poids),
et la card qui suit d'un souffle — ou l'inverse : la card oscille
imperceptiblement et la chauve-souris la retient. Petite chose, gros
effet.

---

## 4. Ce qui devient paramétrable (dette à payer dans le code)

- `TexteGeant` : les mots et le nombre de lignes deviennent des
  paramètres (aujourd'hui « YOU / MADE / IT » en dur), avec des corps
  qui s'adaptent (2 lignes = plus gros que 3).
- `RewardPopup` : une entrée `bigLines: [String]` pour les robes à
  texte géant. Les tailles restent calculées par la robe — **jamais**
  fournies par l'IA (le Design System décide, la loi du plan backend).

## 5. Jalons (une capture validée à chaque pas)

- **W1 — les assets** : détourage de la chauve-souris (blanc + noir),
  décision sur le fond de la pastille. Capture des deux sur la nuit.
- **W2 — la scène** : texte géant deux lignes + spotlight du haut, sur
  la card nue.
- **W3 — la pastille** : posée, éclairée, qui bouge (nappe, liseré,
  paillettes, gyro).
- **W4 — la chauve-souris** : montée au-dessus, pattes sur le liseré,
  balancement.
- **W5 — les finitions** : le Claim, le sous-titre, l'entrée
  orchestrée, non-régression des autres robes.

## 6. À trancher par Kathryn

1. Le fond de la pastille : détourage alpha, ou masque radial doux ?
2. La pastille est-elle **saisissable** (comme le galet) ou juste
   vivante ?
3. Cette robe **remplace-t-elle** le `.welcome` v1 (vidéo chauve-souris)
   ou les deux cohabitent-elles (une pour le retour court, l'autre pour
   le retour long) ?
4. Le mot exact des deux lignes au banc (« YOU'RE / BACK » ?) — sachant
   qu'il deviendra dynamique.
