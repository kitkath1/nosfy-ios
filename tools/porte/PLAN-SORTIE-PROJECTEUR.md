# LA SORTIE DU FILM DE NOSFY — LE PROJECTEUR DESCEND DE L'ÎLE

*13-09-2026 · plan, rien n'est codé · suite de `PLAN-ILE-HALO.html` §04*

Le verdict sur `p4-sortie.png` (ALLEZ / MARGAUX / GO !, le 4 sous un galet, Entrer) :
« ok bien mais » — quatre demandes.

1. **Le nombre choisi en liquid glass**, seul — pas un chiffre pâle sous un galet.
2. **Un spotlight qui part du HAUT du téléphone**, pour être la continuité du halo
   blanc et de la braise des quatre écrans précédents.
3. **Un effet d'apparition « wahou »**.
4. **Un zoom cinématique** pour conclure.

---

## 0. Ce que la mesure dit AVANT de dessiner

### La lumière actuelle ne vient PAS de l'île — et c'est le vrai défaut

`NightSpotlight` est un shader (`EclipseHalo.metal:236`) dont la source est **codée en
dur** :

```
float2 src = float2(size.x * (0.17 + 0.035 * sin(t / 37.0)), …)   // 17 % de la largeur
float ang  = 1.06 + 0.045 * sin(t / 29.0);                           // ~61°, vers le bas-droite
```

Elle part du **coin haut-GAUCHE** et descend en diagonale. Pendant quatre écrans la
lumière était centrée derrière l'île ; à la sortie elle saute dans un coin. C'est
exactement la rupture que Kathryn nomme « pas la continuité ». Aucun réglage ne
corrige ça : la source n'est pas un paramètre.

Le shader sert à trois bancs (`SuccessLab`, `CounterLab`, `LiquidLensLab`) — on ne le
modifie pas. **On ne s'en sert pas ici.**

### Le halo des questions est déjà le bon objet

`HaloIle` (NosfyOnboarding.swift) : une capsule blanche floutée derrière l'île, deux
braises en `plusLighter`, une respiration lente et un embrasement quand Nosfy parle.
Il est centré sur le trou physique (126 × 37 à 11 pt, mesuré). **La continuité, c'est
de ne pas le tuer** — aujourd'hui `if etape != .bienvenue` le retire d'un coup.

### Le chiffre de verre existe, et il a ses lois

- `GaletVerre(naissance:)` (RewardCard.swift:852) : le GROS GALET de vrai verre natif
  qui se promène sur le chiffre de la robe `.galet` et le réfracte.
- La lentille liquide (banc `-lensLab`, commit 558344b) porte des **INTERDITS payés** :
  1. *toute transition qui traverse ou balaie* le verre ;
  2. *les particules-points* (confettis, billes) ;
  3. *perdre le verre* — ses spéculaires ne doivent **jamais** s'éteindre ni
     clignoter pendant une transformation.
- Loi mesurée : **un verre natif redimensionné image par image tombe à 14 img/s** et
  son flou reste plat définitivement. Le verre ne participe à AUCUN zoom.

### Ce que ça coûte aujourd'hui, et ce que ça coûtera

Sortie actuelle : `NightSpotlight` = une `TimelineView` à 30 Hz qui **redessine** un
shader plein écran (la loi : redessiner coûte 3 à 8 × qu'animer). Le plan ci-dessous le
**retire** et le remplace par une couche animée en valeur — c'est un gain net, pas un
coût. Le seul ajout est le verre du chiffre, au repos.

---

## 1. LA CONTINUITÉ — le halo ne s'éteint pas, il se PENCHE

**Le geste :** à l'arrivée sur la sortie, `HaloIle` reste. Ses deux braises s'éteignent
en 0,9 s (la couleur quitte la scène — la fin n'est plus dans l'univers noir de Nosfy,
elle est sur elle). La **capsule blanche** derrière l'île, elle, **s'étire vers le bas**
et devient un cône : le projecteur.

Techniquement, une seule couche nouvelle, animée en valeur (jamais redessinée) :

| couche | forme | animation | mode |
|---|---|---|---|
| le cône | `LinearGradient` blanc → clair dans un trapèze (sommet = centre de l'île, base = 0,78 × largeur au bas du bloc de texte), `blur 28` | `scaleEffect(y:)` 0 → 1 depuis le sommet, 0,7 s, `easeOut` | `plusLighter` |
| le halo blanc existant | la capsule de `HaloIle` | opacité 0,50 → 0,80, `scaleEffect` 1 → 1,25 | inchangé |
| les braises existantes | les deux disques de `HaloIle` | opacité → 0 en 0,9 s | inchangé |

Le cône est **ancré au sommet** (`anchor: .top`) : il *pousse* depuis l'île, il ne
grandit pas depuis son centre. C'est ce qui fait « ça part du haut du téléphone ».

⚠️ Aucun `.mask` sur le texte pour le « révéler » par le cône — c'est un balayage, et
même hors du verre c'est la famille d'effets que les interdits nomment. La lumière
arrive, puis les mots ; ils ne sont pas grattés par elle.

**Coût :** zéro horloge. Trois valeurs animées par `withAnimation`, en keyframes (pas
deux `withAnimation` au même tour — le piège du double).

---

## 2. LE NOMBRE EN LIQUID GLASS, SEUL

Aujourd'hui : un `Text("4")` à 34 % d'opacité sous un rectangle `.glassEffect(.clear)`
de 178 × 200. Ni chiffre ni verre : un fantôme sous une vitre.

**Le geste :** le nombre devient un **objet de verre** — la robe `.galet` de la maison,
pas une imitation.

- Le chiffre en `Inter Heavy 190`, blanc plein (il doit exister pour être réfracté).
- **`GaletVerre(naissance:)` par-dessus**, tel qu'il est écrit — c'est lui qui a été
  validé sur la card reward, avec son déplacement lent qui réfracte le chiffre.
- Le cône de lumière **passe DERRIÈRE** le galet : c'est lui qui donne les spéculaires
  (« la lumière vient de la vidéo à travers le verre » — la loi des widgets, mesurée).
  Sans source derrière, un verre est opaque et gris.
- Position : sous les trois mots, centré, **sans chevaucher MARGAUX** — le 4 par-dessus
  le prénom (capture actuelle) rendait les deux illisibles.

⚠️ Le galet ne change **jamais** de taille : il naît en opacité (0 → 1 sur 0,5 s), il ne
« pop » pas en échelle. Les spéculaires sont allumées dès la première image.

**Sans prénom** (question passée) : deux lignes (`ALLEZ / GO !`), `TexteGeant` passe seul
à 128 pt, le nombre descend d'autant. **Sans objectif** (passé) : le défaut serveur vaut 5
et Nosfy l'a dit (« Cinq, alors ») — on montre 5, pas rien.

---

## 3. L'APPARITION « WAHOU » — l'île allume la scène

Une chorégraphie de **2,4 s**, à l'horloge, en quatre temps. Chaque temps a son
haptique — deux voix distinctes, comme dans le film : *léger* = elle, *moyen* = lui.

| t | ce qui se passe | haptique |
|---|---|---|
| 0,00 | la page des jours part en fondu-flou (existant) ; l'écran ne porte que le halo | — |
| 0,25 | **l'anneau de l'île flashe blanc** (épaisseur ×2,2 pendant 0,18 s, puis retombe) — c'est l'interrupteur | `moyen` |
| 0,30 → 1,00 | **le cône descend** depuis l'île (§1) ; les braises s'éteignent | — |
| 0,85 → 1,90 | **les trois mots** arrivent par `MotsFlou`/`TexteGeant` — chaque mot sort du flou en montant, 40 ms entre eux (la loi du film) — *dans* la lumière, déjà posée | `léger` au premier mot |
| 1,90 → 2,40 | **le nombre de verre** naît en opacité sous les mots ; **la poudre de diamant** (`PoudreDiamant`, RewardCard.swift:911 — celle de la maison, validée sur cette card) sème 44 grains **autour** du galet, jamais dessus | `léger` ×2 à 90 ms |
| 2,40 | Entrer arrive (fondu-flou) | — |

Pourquoi c'est « wahou » et pas « animé » : un seul événement déclenche tout — l'île
s'allume — et tout le reste en découle dans l'ordre d'une scène réelle : la lampe, puis
ce qu'elle éclaire, puis l'objet précieux sous la lampe. La lumière **avant** le texte,
la loi de la maison.

⚠️ La poudre respecte l'interdit n° 2 par sa position : elle est *autour* du verre, elle
ne le traverse pas. Si au téléphone un seul grain passe devant le galet, on la déplace.

---

## 4. LE ZOOM CINÉMATIQUE — la caméra entre dans la lumière

Au tap (la page entière, ou Entrer) :

| t | ce qui se passe | haptique |
|---|---|---|
| 0,00 | `moyen` ; **le galet de verre est remplacé par son jumeau plat** (même chiffre, même place, opacité 1) — invisible à l'œil, obligatoire par la loi des 14 img/s | `moyen` |
| 0,00 → 0,55 | **la caméra avance** : `scaleEffect` 1 → 1,38 sur toute la page, `easeIn` — vers le nombre, qui est le centre de l'échelle (`anchor` au centre du chiffre) | — |
| 0,20 → 0,55 | **le cône monte au blanc** : opacité → 1, blur → 60, il mange l'écran par le haut | `léger` à 0,35 |
| 0,55 | **coupe sur blanc.** L'écran est blanc pur pendant 3 images | — |
| 0,55 → 1,10 | **la home arrive depuis le blanc** — pas depuis le noir. Un voile blanc sur la home, opacité 1 → 0, `easeOut` | — |

C'est la seule différence entre un fondu et un plan de cinéma : **on ne passe pas par le
noir, on passe par la lumière** — et c'est la lumière qu'on a tenue pendant tout le
film.

⚠️ La poudre de diamant du départ (existante) reste : elle se sème à 0,00 et monte
pendant que la caméra avance — elle est devant le blanc, c'est le dernier détail visible.

---

## 5. Ce qui touche à la racine — et qui n'est PAS dans ce plan

Le banc `-nosfy` s'arrête aujourd'hui sur un `print`. La coupe sur blanc vers la home
demande le câblage racine (`WoopApp.swift`, le bloc `if showAuth`) : `onFini` →
`showAuth = false` + le voile blanc au-dessus de la home. C'est le jalon 3 du plan de la
porte, il sera fait quand l'aiguillage Apple sera réel (provider armé, échange mesuré).
Ici : **la sortie se joue jusqu'à la coupe sur blanc**, et le banc s'arrête là.

---

## 6. L'ORDRE, et ce qu'on mesure

| rang | geste | couche | mesure |
|---|---|---|---|
| ① | retirer `NightSpotlight` de la sortie, garder `HaloIle` | −1 (une TimelineView 30 Hz en moins) | `-sondeVol` avant/après |
| ② | le cône ancré à l'île, les braises qui s'éteignent | +1, animée en valeur | cadence au téléphone, thermique à 0 |
| ③ | le nombre : `Text` plein + `GaletVerre` au repos | +1 verre, statique | cadence — un verre = le quart d'une page, on le sait |
| ④ | l'apparition en 4 temps + haptiques | 0 | film + fouettage |
| ⑤ | le zoom : jumeau plat, push-in, coupe sur blanc | 0 | film (le blanc doit être **pur**, mesuré sur les pixels) |

Chaque rang se filme avant le suivant. On s'arrête si ② ou ③ fait chuter la cadence
sous ce que la page des questions tient déjà.

**Verrous :** le verre ne change jamais de taille · aucun balayage sur le texte ni sur le
verre · la poudre autour, jamais dessus · le blanc de la coupe est pur.
