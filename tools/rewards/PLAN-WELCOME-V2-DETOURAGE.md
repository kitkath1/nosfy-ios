# WELCOME BACK v2 — LE PLAN DE RÉPARATION : des stickers PLEINS, et la chauve-souris « à la Nosfy »

**Écrit le 26-08-2026 après le premier montage — RIEN n'est codé ici.**
Le montage (texte géant, spotlight, pastille, chauve-souris) est en
place au banc `-welcomeTexte`, mais **les deux stickers sont
FANTOMATIQUES**. Ce document dit pourquoi, et comment on répare.

---

## 1. LE DIAGNOSTIC (mesuré, pas supposé)

J'ai détouré les deux assets avec **alpha = luminance**. Sur un objet
CLAIR posé sur du noir, c'est une bonne ruse. **Sur un objet NOIR posé
sur du noir, c'est une faute** : l'objet lui-même devient transparent,
puisque sa propre matière est sombre.

Mesuré sur les fichiers importés :

| asset | alpha moyen DANS le sujet | pixels sous 50 % |
| --- | --- | --- |
| pastille-lune | 0,85 | 17 % |
| **chauve-souris** | **0,46** | **61 %** |

→ La chauve-souris est à moitié effacée, la pastille perd sa matière
dans ses zones noires (son paillettage, la gravure de la lune). C'est
exactement ce que Kathryn voit : « trop transparente », « en
transparence bizarre ».

**LA LOI À ÉCRIRE** : un sticker sombre sur fond sombre ne se détoure
JAMAIS par la luminance. Il se détoure par sa **SILHOUETTE** — un
masque binaire (dedans = 1, dehors = 0), adouci de 1 à 2 px sur le seul
CONTOUR. La matière intérieure ne doit jamais être touchée.

---

## 2. LA RÉPARATION DES ASSETS

### 2.1 La pastille-lune — un carré arrondi PLEIN

Sa silhouette est un rectangle à coins arrondis : facile et sûr.

1. Seuil bas (lum > 8) → masque grossier ; **remplissage des trous**
   (`binary_fill_holes`) ; **plus grande composante connexe** seulement
   (les poussières du fond sautent).
2. **Fermeture morphologique** (dilate puis erode, ~5 px) : les bords
   dentelés se referment.
3. Alpha = 1 DEDANS, 0 dehors, et un fondu de **1,5 px sur le seul
   contour** (distance transform, pas un flou global : un flou global
   remange la matière).
4. Vérification (la sonde du diagnostic) : **alpha moyen dans le sujet
   > 0,98**, sinon on recommence.
5. Contrôle visuel sur gris ET sur nuit : le paillettage et la gravure
   doivent être aussi denses que dans le fichier de Kathryn.

### 2.2 La chauve-souris — silhouette, oreilles comprises

Plus délicate : ses oreilles sont fines, ses contours sont doux, et son
corps est presque noir.

1. Masque de départ : **lum > 6** (très bas — on cherche l'existence,
   pas la clarté) sur la moitié HAUTE de l'image seulement (sous la
   ligne des griffes, tout appartient au rectangle blanc : déjà coupé,
   §2.3).
2. **Fermeture** (~7 px) pour souder les oreilles au crâne, puis
   **remplissage des trous** (l'œil brillant, les creux).
3. **Plus grande composante connexe** → la silhouette.
4. Alpha = 1 dedans, fondu 1,5 px sur le contour.
5. Vérification : **alpha moyen > 0,97**, et les DEUX oreilles
   présentes (mesure de la boîte : la largeur doit couvrir les pointes).
6. ⚠️ Garde-fou : si la fermeture soude la chauve-souris au bord du
   cadre, réduire le rayon — jamais forcer.

### 2.3 Le rectangle blanc (déjà résolu, à garder)

La coupe nette sous la ligne des griffes fonctionne : tout ce qui est
sous `y0 + 132` appartient au rectangle (blanc, liseré, ombre) et
disparaît ; les griffes, au-dessus, survivent. **Ne pas y retoucher.**

---

## 3. LA COMPOSITION « À LA NOSFY » (la réf de Kathryn)

Le screenshot montre la grammaire exacte à copier :

- Le personnage est **PLEINEMENT OPAQUE** — aucun fondu, aucune
  transparence. Il se découpe franchement sur ce qu'il y a derrière.
- Il est **PETIT** : sa tête fait environ **un quart de la largeur** de
  la card (chez nous : 0,26 à 0,30 — j'étais à 0,46, encore trop gros).
- Il est **posé SUR le bord haut** : seule sa tête dépasse, et ses
  mains/griffes **reposent sur le liseré**, à peine en dessous. Le
  reste de son corps est masqué par la card.
- Il est **centré** horizontalement.
- La card, elle, ne change pas : le personnage est un ajout, pas une
  déformation.

**Conséquence de montage** : le sticker est ancré `.top`, décalé vers le
haut d'environ **55 à 60 % de sa propre hauteur** (et non d'une
fraction de la largeur de la card, comme je l'avais fait — d'où le
mauvais calage). À régler sur capture, pas au calcul.

**La pastille**, elle, reste au centre de la card, PLEINE, avec ses
effets de lumière (nappe spéculaire au rythme du spotlight, paillettes
dans sa silhouette, flottement, gyro) — ces effets-là sont bons, c'est
seulement sa matière qui doit redevenir opaque.

---

## 4. CE QUI EST DÉJÀ BON (ne pas y toucher)

- Le texte géant « YOU'RE / BACK » deux lignes, paramétrable.
- Le spotlight du haut qui balaie.
- Le bouton Claim de verre à la pièce, et « Later ».
- La robe VIDÉO du Welcome Back (l'autre variant) : **intacte**, les
  deux cohabitent (`WelcomeRobe.video` / `.texte`).
- Les animations de la pastille (flottement, gyro, nappe, paillettes).

## 5. JALONS

- **R1 — les assets réparés** : les deux stickers re-détourés par
  silhouette, sonde d'opacité > 0,97, contrôle sur gris et sur nuit.
- **R2 — le calage Nosfy** : la chauve-souris petite, opaque, ses
  griffes sur le liseré ; capture validée.
- **R3 — la pastille pleine** dans la scène, ses lumières revérifiées
  sur sa matière opaque.
- **R4 — fouettage** : les deux robes du Welcome, non-régression des
  autres cards, film de l'entrée.

## 6. À TRANCHER

1. La chauve-souris doit-elle **passer devant** le texte géant (elle est
   au-dessus de tout) ou **derrière** lui ? (Nosfy est devant.)
2. Son ombre portée sur le bord haut de la card : oui (elle pose
   vraiment) ou non (la nuit suffit) ?
3. La taille finale : un quart de la card comme Nosfy, ou un peu plus
   présente ?
