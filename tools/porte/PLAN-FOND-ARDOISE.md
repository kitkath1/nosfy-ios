# LE FOND DE L'ARDOISE — le plan, deuxième fois (14-09, midi)

*Son verdict : « non, pas d'effet balayage en background, je pensais une animation de
background jolie et subtile ! » puis « refais un plan, là tu changes rien, sérieux ».*

## 0. Pourquoi elle ne voit rien — mesuré, pas deviné

Ce que j'ai posé ce matin (deux disques flous Ø 240 et 170, flou 48 et 38, qui dérivent) :

| réglage | zone haut-droit (sur 255) | ce que l'œil voit |
|---|---|---|
| ardoise nue | 34, immobile | rien |
| flaques à 8,5 % / 6 % | 34 → 59 | **un voile gris** sur toute la card (refusé par moi) |
| flaques à 5,5 % / 3,8 % | 39 → 46 en 20 s | **rien** — 7/255 de variation, sous le seuil de l'œil |

La faute n'est pas dans l'intensité, elle est dans la FORME : un disque flou plus grand
que la card n'a pas de bord. Sans bord, un mouvement n'existe pas — il ne reste qu'un
niveau de gris qui monte et descend. Et le seul moyen de le rendre visible, c'est de le
monter jusqu'au voile. Les deux issues sont mauvaises parce que l'objet est mauvais.

**La loi qui sort de la mesure : une lumière qui bouge doit avoir un BORD lisible, et le
noir autour d'elle doit rester noir.** C'est le contraste qui rend un mouvement visible,
jamais la luminance.

## 1. La direction — « de la lumière qui a une forme, et qui vient de quelque part »

Trois sources, chacune visible comme une forme, aucune plus large que 40 % de la card.
Tout reste une valeur animée dans une feuille (offset, opacité, rotation) — les flous
sont constants et déplacés, la loi du 05-09 tient.

### F1 — LE RAYON DE LUNE (la lumière principale)
Une ellipse douce **150 × 90 pt, flou 22** (le bord se lit), blanc **12 %**, posée
au-dessus de la matière, `plusLighter`. Elle **traverse lentement l'ardoise sur un arc**
— de la gauche du texte jusque derrière les galets et retour — en **21 s** (x : −110 →
+120 ; y : −30 → +10 sur 27 s, deux périodes premières = une courbe, pas un rail). Elle
passe DERRIÈRE le texte et les galets (ils sont dessus) : on la voit glisser sous les
lettres, c'est ça la profondeur. Coût : un flou constant déplacé.

**Ce que ça donne en chiffres, pour qu'on puisse dire si c'est visible** : entre deux
captures à 10 s d'écart, le centre de l'ellipse s'est déplacé de ≥ 60 pt, et le pic local
vaut ≈ +30/255 sur un fond qui reste à 34 hors de l'ellipse. C'est ce que l'œil voit :
une tache qui se déplace, pas un niveau qui change.

### F2 — LA LUEUR DU GALET SUR L'ARDOISE (la lumière qui vient d'un objet)
Le galet du jour ÉCLAIRE la matière sous lui : un disque **Ø 110, flou 18**, blanc
**9 %**, centré sur le galet actif dans la bande, qui **respire** (0,7 ↔ 1,0 d'opacité,
3,1 s — pas la période du galet, on ne peut pas s'y accorder, mais assez proche pour se
lire comme la même vie). C'est la seule lumière qui a une RAISON d'être là : elle vient
du galet. Elle remplace `HaloVierge` (qui n'existait qu'à vide) et vit dans les deux
états.

### F3 — LA PROFONDEUR (téléphone seulement : le gyroscope)
Le rayon de lune, la lueur du galet et la crête du liseré **glissent avec l'inclinaison
du téléphone** : ±14 pt pour le rayon, ±6 pt pour la lueur, ±4° pour la crête — trois
vitesses, donc trois plans, donc une fenêtre sur de la profondeur. C'est LE geste Apple
(l'écran verrouillé, les cards de l'App Store), et il ne coûte aucune horloge :
`GyroFond` (CoffreV2) existe, le gyroscope est mesuré innocent (skill § 4). **Invisible
au simulateur — à juger sur l'iPhone uniquement.**

### F4 — LA CRÊTE SUR LE LISERÉ (gardée, montée)
C'est la seule chose de ce matin qui se lisait sur les planches. Elle reste (22 s), le
pic passe de 0,55 à **0,75** et la crête s'affine (0,46 → 0,50 → 0,54 au lieu de 0,40 →
0,60) : un point de lumière qui fait le tour, pas une moitié de contour qui s'allume.

### F5 — LE NOIR RESTE NOIR (une règle mesurable)
Aucune zone de 100 × 100 px de l'ardoise hors des trois lumières ne monte de plus de
**+4/255** par rapport à l'ardoise nue. Le banc le mesure (les sondes du script de
capture) avant que je lui montre. Si une lumière viole la règle, on réduit sa TAILLE,
jamais on ne la floute davantage.

## 2. Ce qui est retiré
Les deux flaques de ce matin (P1) — remplacées par F1 + F2. Le balayage (P3) — déjà
retiré sur son ordre. `HaloVierge` — absorbée par F2.

## 3. Trois robes à choisir au banc (`-fondRobe a|b|c`)
- **a — « rayon de lune »** : F1 + F2 + F4 (+ F3 au téléphone). *Ma recommandation.*
- **b — « deux lunes »** : F1 dédoublé (un second rayon, plus petit, 100 × 60, 8 %, qui
  va en sens inverse en 29 s), F2, F4. Plus de vie, plus de risque de gris.
- **c — « l'aurore »** : à la place de F1, un RUBAN courbe (une seule courbe de Bézier
  de 3 pt, flou 14, 10 %) dont les deux points de contrôle ondulent (`Animatable`, 17 s
  et 23 s) — c'est la seule robe qui REDESSINE (le flou ne se met pas en cache) : à ne
  garder que si la mesure au téléphone le permet.

Les trois s'affichent l'une sous l'autre avec `-fondPlanche`, sur l'état vide et l'état
déjà fait (six cards), captures à 0 s / 10 s / 20 s pour qu'on VOIE le déplacement sur
une planche — c'est là que je lui montre, pas sur une image seule.

## 4. Le coût, et comment on le saura
Robe a : deux flous constants déplacés + le carré conique — au plus le même poste que ce
matin, en plus petit (Ø 150 et 110 contre 240 et 170 : quatre fois moins de pixels
floutés). Robe c : un flou recalculé par image, à mesurer avant tout verdict. Campagne
au téléphone (thermique 0, Home immobile, ABBA `-sansPlateau` contre rien), la paire
(cadence, processeur) publiée.

## 5. Ordre
1. Retirer P1, poser F1 F2 F4 F5 + le banc `-fondRobe` / `-fondPlanche` (une demi-journée).
2. Planche 0/10/20 s → son verdict sur la robe.
3. F3 sur l'iPhone (une heure), mesure.

Rien de codé tant qu'elle n'a pas dit « go ».

---

## 6. Son ordre suivant (14-09, midi) — et ce qui est posé

« Fais-moi des propositions UI sexy », « garde le design que tu viens de faire mais
améliore-le drastiquement », **« fais un dégradé liquid glass noir → transparent qui change
et qui bouge dans le background, trop beau, un truc du genre »**. Ça remplace le § 1 :
plus de lumières blanches sur le noir — du NOIR qui bouge sur du VERRE.

**Posé dans CardRoute.swift, vu au simulateur, NON commité** : `FondRobe` (a/b/c),
`FondLiquide` + `MareeNoire` / `VerreRespire` / `GoutteNoire` — un dégradé construit une
fois, ce qui bouge est une rotation, un offset ou une échelle ; la crête du liseré
(`LisereTournant`) par-dessus ; sous le doigt le noir s'efface d'un tiers. Les flaques
floues sont retirées. Banc **`-duoLab -routeCard vide -fondPlanche -skipAuth`** : les trois
robes l'une sous l'autre EN VERRE sur `SceneDuBanc` (une aurore chaude en haut, une froide
en bas, qui dérivent — ce que la Home met sous la card ; sur du noir un verre est une
ardoise opaque et il n'y a rien à révéler). `-deuxEtats` monte aussi en verre avec la
scène. `-fondRobe a|b|c` choisit la robe partout (défaut : a).

Planche à 0 / 8 / 16 / 24 s : la marée fait le tour (la moitié sombre passe de gauche à
droite), le verre qui respire change de forme, la goutte erre. Cette fois ça se VOIT.
**Son choix (14-09, midi) : « ok le verre qui respire, et fais pareil pour l'état à
faire, et update le composant »** → `FondRobe.choisie` = `.respire` par défaut, dans les
deux états (vide et déjà fait — le fond est monté dès que la card n'est pas en séance) ;
a et c restent au banc. Reste : la mesure au téléphone (un verre dont la moitié change de
noir à clair oblige le verre à recomposer — c'est exactement le cas « verre sur vidéo »
du skill, à chiffrer avant tout 🟢).
