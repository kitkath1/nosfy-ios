# Quel effet, si le feu n'y arrive pas

**Proposition. RIEN N'EST CODÉ, RIEN N'EST RENDU.**
Écrit le 23-09-2026, après dix refus.

---

## 1. Pourquoi le feu ne marchera pas, et il faut le dire une fois

Elle a testé le shader **au simulateur, en mouvement**. Donc ce n'est pas un
problème d'images fixes : c'est l'effet lui-même.

Le feu procédural échoue pour une raison structurelle : **le bruit fractal
n'a pas de tourbillons.** Une flamme est un fluide ; ses enroulements
viennent de la mécanique. Huit passes d'amélioration (rampe à douze paliers,
langues, déformation de domaine, trois nappes, poussée d'Archimède,
filaments, exposition, roussissure) l'ont chaque fois rapproché sans jamais
le faire franchir la barre.

**Et il y a pire que « pas assez beau » : le feu n'est pas de sa matière.**
Nosfy est faite d'obsidienne, de papier, de gravure et de nacre. Les braises
y sont une AMBIANCE — un foyer en bas d'écran, un sticker flamme, des
flammes sur les séries. Une flamme plein écran, c'est un effet de jeu vidéo
posé sur une app de bijoutier.

---

## 2. Le principe à tenir

Les transitions qui se lisent comme chères ne sont jamais des effets posés
par-dessus. **Ce sont des OBJETS qui bougent.** Et l'objet doit être celui
de l'app.

L'objet de Nosfy, c'est **la carte**. Toute son économie en est faite :
boosters, collection, raretés, la carte du jour dans la tête du lecteur.

---

## 3. Les trois propositions, par ordre de conviction

### A — LA CARTE QUI SE RETOURNE ★ recommandée

L'écran EST une carte. Au tap, elle se retourne : rotation autour de l'axe
vertical, perspective réelle, et au passage par la perpendiculaire **elle
n'est plus qu'un trait de lumière d'un pixel**. Puis le dos arrive : c'est
l'écran suivant.

Pourquoi c'est elle :

- **C'est sa matière.** Nosfy est une app de cartes. Retourner une carte
  n'est pas un effet, c'est le geste du jeu.
- **C'est littéralement sa loi** : « la brillance vient de la blancheur,
  jamais de l'épaisseur ». Au moment le plus spectaculaire, il n'y a qu'un
  cheveu blanc sur du noir.
- **Ce n'est pas un balayage** : rien ne traverse l'écran. Un objet tourne
  sur son axe, et la lumière glisse sur sa tranche — une lumière qui a une
  cause et un bord.
- **Ça ne coûte rien** : une rotation 3D, deux faces, aucun bruit, aucun
  shader, aucune texture. Moins cher que ce qui tourne aujourd'hui.
- **Personne ne le fait.** Pas dans une app de sport.

Les détails qui feraient la différence : la tranche qui capte la lumière
comme du verre fumé, une ombre portée qui se déplace pendant la rotation,
et le dos qui arrive **déjà net** — pas de flou, pas de fondu.

### B — LE PLI DU PAPIER

L'écran se plie en deux le long d'une arête, comme le ticket de séries.
L'arête capte un cheveu de lumière ; derrière le pli, l'écran suivant.
Même matière (le papier du ticket), même loi, même coût.
Moins évident à réussir que A : un pli mal éclairé se lit comme un bug.

### C — LE GALET

L'écran se contracte en **galet d'obsidienne** — la pierre de la Route —
qui tombe, et l'écran suivant s'ouvre depuis lui. C'est son vocabulaire
(les galets du chemin), et c'est une belle idée de continuité.
Plus risqué : une contraction plein écran peut se lire comme un bug d'app.

---

## 4. Ce que je ne propose PAS, et pourquoi

- **Rien de procédural** (feu, fumée, particules, bruit) : huit passes ont
  montré que ça ne franchit pas la barre sur un téléphone.
- **Aucun flou plein écran** : c'est la chose la plus chère de cette app, et
  ça n'a jamais convaincu.
- **Aucun fondu** : un fondu, c'est l'absence de transition.

---

## 5. Ce qui se passe ensuite

1. Elle choisit A, B ou C — ou dit que rien ne lui va, et on retire l'effet.
2. **Je rends la séquence en mouvement AVANT de toucher à l'app** : une
   rotation se juge en tournant, pas en quatre images.
3. Si elle valide, c'est trente lignes de SwiftUI. Pas de Metal, pas de
   texture, pas de banc thermique — une rotation 3D ne chauffe pas.

---

## 6. L'état de l'arbre en attendant

- Le shader du feu (`FlammeNoire.swift`, `.metal`, assets `flamme-*`) et ses
  bancs **tournent toujours** ; ils partent le jour où elle tranche.
- Ce qu'elle a validé et qui reste : les carrés réservés au choix, le chevron
  du retour, la braise du header, la série en cours portée.
- Rien n'est commité.
