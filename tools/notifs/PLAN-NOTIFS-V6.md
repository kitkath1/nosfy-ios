# NOTIFICATIONS V6 — le halo remplace le chrome, et LA BONNE VIDÉO

Verdict de Kathryn du 29-08 sur « La Châsse ». Quatre demandes, une
question — et la réponse à la question était dans son dossier
Téléchargements.

---

## §A — LE VARIANT 1 EN CAPITALES (je te le devais depuis hier)

Tu l'avais demandé au tour précédent (« garde en majuscule dans le variant
1 ») et **je ne l'ai fait que dans le variant 3**. La card 1 dit encore
« coins earned » et « Vault progress » en bas de casse.

```
+20  COINS EARNED        ← capitales, tracking +0,8
VAULT PROGRESS           ← capitales, tracking +1,4, gris
```

Le tracking positif n'est pas un ornement : des capitales serrées font un
mur.

---

## §B — LE CHIFFRE : LE CHROME SAUTE, UN HALO LE REMPLACE

Ton verdict : *« les dégradés dans le chiffre n'ont rien à voir avec +20 ;
un halo de lumière, fondu, et animé »*.

**Le chrome irisé était MA proposition, tu l'as vue, elle ne va pas. Elle
saute.** Les deux passes croisées (l'arc angulaire à 6 °/s et la bande
linéaire en sens inverse) disparaissent, et avec elles le socle de métal
froid assombri.

### Ce qui le remplace — et la maison a déjà la recette

`nappesOr` (`StorySuite.swift:1934`) fait littéralement ce que tu décris :
**« la lumière naît DANS les lettres — périodes premières entre elles,
jamais un balayage »**. C'est ça, un halo fondu et animé : pas un reflet qui
passe, une lueur qui respire à l'intérieur du chiffre.

Trois couches, et rien de plus :
1. **Le chiffre net**, blanc argent, propre — c'est l'information.
2. **Les nappes DANS le glyphe** — deux ou trois nappes douces aux périodes
   premières (jamais de `repeatForever` : fonctions pures de `t`), masquées
   par le chiffre. La lumière naît dedans et s'y déplace lentement.
3. **Le halo DERRIÈRE** — le radial froid qui existe déjà à 0,085 devient le
   sujet : plus large, plus présent, et il respire sur sa propre horloge.

⚠️ **Ce qu'on garde de l'épisode chrome, parce que ça a été payé** : un
additif a besoin de **mi-tons sous lui** pour se lire, et le métal opaque
est ce qui cache le biseau presque blanc. Les nappes seront donc posées sur
un chiffre à valeur MOYENNE, pas sur du blanc pur — sinon elles ne se
verront pas plus que l'irisation (chroma mesurée 2,9/255 avant correction).

---

## §C — L'ALIGNEMENT : c'est un vrai bug, et il est mesuré

*« et c'est pas aligné »* — tu as raison, et ce n'est pas un réglage d'œil.

`ChiffreChrome` porte `.frame(width: corps * 2.6, height: corps * 1.25)` et
le glyphe est **centré** dans ce cadre, tandis que « COINS EARNED » est au
bord gauche de la colonne. Relevé sur la capture : **~21 pt de décalage**.

Remède : le glyphe s'aligne **leading** dans son cadre (ou le cadre épouse
le glyphe). Les deux lignes partiront alors du même bord.

---

## §D — LE GALET QUI « FAIT BIZARRE »

Tu dis *« ça fait bizarre le galet qui bouge, mais ok »*. Je pense que tu as
raison et je sais pourquoi.

Sa dérive vient de la card reward : ±46 pt en x, ±34 en y, **dans une card
PORTRAIT**. Là-bas, ça flotte. Sur une bande de 138 pt de haut et 356 de
large, le même mouvement ne flotte plus — **il GLISSE**, latéralement, comme
un objet qu'on pousse. Je l'avais déjà rentré à 0,34 ; ce n'est pas assez
parce que ce n'est pas une question d'échelle, c'est une question de
**registre** : dans une bande, un objet doit RESPIRER, pas voyager.

**Remède : amplitude 0,34 → 0,12, et les périodes ralenties.** Il ne
traverse plus, il palpite sur place. La réfraction (le seul intérêt du
galet) ne demande pas de trajet.

Et si tu préfères : **le figer complètement** est une constante à zéro, et
**le supprimer** est une ligne. Dis-le et c'est fait.

---

## §E — TA QUESTION : « comment améliorer avec la chauve-souris ? »

*« des dégradés de blanc dans le background, ou je dois te générer une
petite vidéo de spotlight ? »*

### E1. ⚠️ **NI L'UN NI L'AUTRE D'ABORD : TU AS DÉJÀ LE BON PLAN.**

Dans ton dossier Téléchargements :

- **`nosfy_pièces_sol.mp4`** (3840×2160, 7,04 s) — **Nosfy debout, et DEVANT
  LUI DES PILES DE PIÈCES D'OR.**
- `Nsfy_rewards.mp4` (même format) — Nosfy qui TIENT un booster
  holographique.

Le plan que j'ai monté (`nosfy_grands`) est une chauve-souris qui vole. Elle
est belle, mais **elle ne dit rien de l'or**. Pour une notification qui
annonce « +20 coins », le plan aux PIÈCES met le sujet et la récompense dans
la même image — c'est le fond qui raconte au lieu de décorer.

Et `Nsfy_rewards` n'est pas pour cette card-ci : c'est la notification du
jour où tu gagnes un **booster**. Un quatrième cas, gratuit, déjà tourné.

⚠️ **Ce qu'il faut vérifier avant de s'en réjouir** : ce plan est composé en
HAUTEUR (la bête en haut, les pièces au sol en bas) et notre dalle fait
2,6:1. Dans une bande de 138 pt on verra soit la bête, soit les pièces.
**La boîte utile se MESURE avant de trancher** (comme pour `nosfy_grands` :
c'est la mesure qui a donné le recadrage et le cycle de battement). Trois
issues possibles, dans l'ordre de préférence :
1. un recadrage serré qui tient les deux (si la composition le permet) ;
2. la dalle du variant 3 devient **plus haute** que les deux autres — une
   notification « riche » a le droit d'être plus grande ;
3. on garde `nosfy_grands` et les pièces attendent une autre card.

### E2. LE FOND — le code d'abord, la vidéo seulement s'il échoue

- **En code** : une nappe blanche douce qui descend du bord haut — la même
  grammaire que le halo du variant 2, déjà écrite et validée. **Gratuit,
  réglable au pixel, aucun asset, aucune génération.**
- **En vidéo** : ce qu'une nappe ne sait PAS faire, c'est la lumière
  **volumétrique** — les rais dans le faisceau, la poussière qui traverse.
  Ça, seule une vidéo le donne.

**Ma recommandation : essaie le halo codé d'abord** (c'est une demi-heure et
on le voit tout de suite). Ne génère une vidéo de spotlight que s'il rend
plat — ce serait dommage de brûler une génération pour ce qu'un
`RadialGradient` fait déjà.

⚠️ Et si on va à la vidéo de lumière : **elle devra être BORD À BORD**. La
loi de la maison est catégorique — *« une vidéo posée ailleurs qu'en bord de
card laisse TOUJOURS voir son rectangle : 4 essais, 4 démarcations »*. Un
faisceau posé en médaillon au milieu de la dalle se verrait comme un timbre.

---

## §F — LES JALONS

| # | Ce qui sort | Comment on le juge |
|---|---|---|
| **V6-1** | Variant 1 en capitales | capture |
| **V6-2** | L'alignement du chiffre (les 21 pt) | **sonde** : les deux lignes au même x |
| **V6-3** | Le chrome retiré, les nappes + le halo à sa place | capture + **film** (un halo animé ne se juge pas sur une image) |
| **V6-4** | Le galet rentré à 0,12 | film |
| **V6-5** | La boîte utile de `nosfy_pièces_sol` | **mesure** — et la décision de recadrage tombe là, pas avant |
| **V6-6** | Le fond : la nappe blanche codée | capture — **c'est ici qu'on décide si une vidéo de spotlight est nécessaire** |
| **V6-7** | Ton verdict | — |

---

## §G — CE QUI EST ACQUIS ET QU'ON NE REJOUE PAS

- **La cadence est mesurée** : La Châsse seule à **60,0 img/s, pire trou
  17 ms** sur sept secondes ; les trois cards empilées à 55-60. (Au
  simulateur, sous charge 🟡, avec le simulateur d'une autre session
  allumé. Le téléphone reste le vrai juge.)
- Le recuit de `nosfy_grands` : 4,7 Mo → **78 Ko**, boucle de 1,500 s dont
  la couture est mesurée (0,996 contre un plancher de 0,48 — une coupe
  sèche à 1,5 s donnait 2,58, cinq fois le plancher).
- Le galet doit être posé SUR la bête : sans nourriture, `.clear` n'est
  qu'un givre — il rendait un disque gris.
- Les grains de la jauge sont CLIPPÉS (encre sur 10 px, exactement 0
  au-dessus et au-dessous).
