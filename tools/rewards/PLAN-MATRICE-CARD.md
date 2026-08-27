# LA CARD MATRICE — PLAN 7 : LA VIDÉO REMPLACE LE CODE

27-08. Verdict : *« enlève les chiffres, tu comprends pas […] prends
cette vidéo en background, trop belle, fond_paliette […] et archive ton
effet »*.

Elle a raison : sa vidéo fait en 7 secondes ce que j'ai raté en huit
tours. J'archive, je branche, je ne discute pas.

---

## § 1 — ARCHIVER L'EFFET CODÉ (pas le supprimer)

Ce qui sort de la card et part à l'archive :

- `PluieCard` — la pluie plein card, ses fondus, sa diagonale ;
- `TrameCard` — la grille de caractères en Canvas ;
- `AccentsMatrice` — les accents blancs ;
- `HaloReward` — le halo, ses deux ondes qui se relaient ;
- les grains migrants.

**Où** : `tools/rewards/archive/pluie-codee.swift.txt` (non compilé) +
une note dans ce dossier disant d'où ça vient et ce que ça faisait.
Le git le garde de toute façon, mais l'archive explicite est ce qu'elle
a demandé — et ça sort ~450 lignes de `RewardCard.swift`.

**Ce qui NE part pas** : la matrice DANS le chiffre (`ChiffreMatrice`,
composant validé), la poudre de diamant, le banc.

---

## § 2 — LA VIDÉO DE FOND

### Ce qu'elle est (mesuré)

`~/Downloads/fond_paliette.mp4` — 2160 × 3840, HEVC **10 bits**, 24 i/s,
7,04 s, 169 images, **18 Mo**. Une pluie de chiffres verticale sur noir,
avec une lumière qui enfle au centre puis retombe.

Son noir est VRAI : médiane 5 → 18 selon l'image, 5ᵉ centile à 2. Elle
se fondra donc naturellement sur une card noire — c'est ce qui rend le
§ 3 possible.

### La recuisson (obligatoire)

Telle quelle elle est intenable dans une card : 4K, 10 bits, 18 Mo.
La loi de la maison (les 9 vidéos reward recuites le 25-08) :

- **H.264 8 bits**, `yuv420p` — le 10 bits HEVC coûte cher au décodeur ;
- **1080 de haut** suffit largement : la card fait 321 × 424 pt, soit
  963 × 1272 pixels sur l'appareil ;
- **muette** (piste audio retirée) ;
- **débits propres** — les seuls mesurés sains sur ce projet sont
  1,25 et 2,5 Mb/s ;
- cible : **≤ 2 Mo**.

### LE PING-PONG CUIT DANS LE FICHIER

L'aller-retour se **cuit** (aller + retour concaténés), il ne se joue
jamais par un seek qui rebrousse : **le décodeur ne suit pas** (la loi
du manège, et la recette déjà appliquée à `reward-welcome-loop.mp4`).
Durée finale ~14 s, boucle infinie, raccord invisible puisque la
dernière image de l'aller est la première du retour.

### Le montage dans la card

- composant : `VideoReward` / `VideoVivante` existent déjà (AVPlayerLayer,
  aspectFill, **`clipsToBounds` + `masksToBounds`** — la loi de la vidéo
  qui déborde son cadre : un `clipShape` SwiftUI ne rattrape pas UIKit) ;
- **elle occupe TOUTE la card, bord à bord.** C'est la seule pose
  légale : « une vidéo posée ailleurs qu'en bord de card laisse
  TOUJOURS voir son rectangle » (4 essais, 4 démarcations, 26-08) ;
- la dalle sous elle reste **noir plein**.

---

## § 3 — LA VIDÉO BIEN FONDUE DANS LE BACKGROUND

> *« qu'elle soit bien fondue dans le background »*

Un masque sur le calque vidéo, les quatre bords :

- **haut** : fondu long — c'est de là que descend la lumière de FOUR
  (§ 4), les deux doivent se rencontrer sans couture ;
- **côtés** : fondus symétriques ;
- **bas** : fondu jusqu'au noir sous « Sets / Close ».

Le noir de la vidéo étant déjà vrai, ces fondus n'ont qu'à éteindre les
colonnes de bord — il n'y a pas de rectangle clair à cacher.

---

## § 4 — FOUR EN HAUT, ÉCLAIRÉ PAR LE HAUT

> *« fais FOUR en haut […] et que FOUR soit aussi fondu, sa lumière de
> FOUR vient du haut de la card, et après le bas du gros texte en fondu
> noir »*

- **FOUR monte tout en haut** de la card ;
- **sa lumière descend DU BORD HAUT** : le texte est clair en crête et
  s'assombrit en descendant — la source est au-dessus de lui, hors
  card ;
- **son pied se noie dans le noir** : fondu vertical jusqu'à zéro, le
  bas du mot n'existe plus ;
- les fondus latéraux restent (le mot peut se couper, « pas grave »).

⚠️ Le sens du dégradé s'INVERSE par rapport à maintenant : aujourd'hui
la crête se noie et le corps est clair. Là c'est la crête qui est
lumineuse et le pied qui meurt.

---

## § 5 — CE QUI RESTE EN PLACE

- **le 4 de verre** (`VerreQuatre`) avec ses nuances rouge et blanc —
  « enlève les chiffres » visait la pluie du fond, pas lui. *À confirmer
  d'un mot si je me trompe.*
- la **matrice validée** derrière le verre, que le verre réfracte ;
- la **poudre de diamant** ;
- « Sets » et « Close » ;
- le banc **`-rewardLab`** et ses gels.

---

## § 6 — ORDRE

| # | Quoi | Ce qui se juge |
|---|---|---|
| 1 | Recuire la vidéo (H.264, 1080, muette, ping-pong cuit, ≤ 2 Mo) | `ffprobe` : poids, codec, durée ; dernière image = première du retour |
| 2 | Archiver l'effet codé, sortir 450 lignes de la card | Le fichier archive existe, la card compile sans |
| 3 | La vidéo bord à bord + ses 4 fondus | Capture : aucun rectangle, aucune démarcation |
| 4 | FOUR en haut, lumière du haut, pied noyé | Capture |
| 5 | Cadence | Sonde par régime : vidéo + verre, c'est le vrai coût |

Go et je déroule.
