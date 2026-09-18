#!/usr/bin/env python3
"""LES DEUX VIGNETTES DE SACHET — jumelles, DEPUIS DES ALPHAS QUI EXISTENT.

⚠️⚠️ **LA LEÇON DE CE FICHIER, ET ELLE A COÛTÉ QUATRE VERSIONS : JE
RECONSTRUISAIS UNE SILHOUETTE QUE QUELQU'UN AVAIT DÉJÀ DÉTOURÉE.**

Les trois premiers jets partaient des rendus du bureau (`Booster_orange.png`,
`booster noir .png`) — des rendus **sur fond noir**, où le sachet est noir
lui aussi. Détourer du noir sur du noir est mal posé par nature : j'ai essayé
un seuil de luminance (impossible, mesuré : intérieur du sachet à 12, halo à
14 sur la même ligne), puis les pics de GRADIENT ligne par ligne, puis trois
garde-fous successifs. Chaque tour rendait une mesure meilleure — le bord est
tombé de 23 px à 2 px — **et le résultat restait faux**, parce que le
remplissage se fait par SPAN horizontal : chaque ligne est pleine du bord
gauche au bord droit. Sur du noir ça ne se voyait pas. Sur un damier, on voit
la vérité : un RECTANGLE.

Verdict de Kathryn : *« c'est pénible, t'arrives pas le détourage, c'est pas
compliqué »*. Elle avait raison, et pour une raison que je n'avais pas
cherchée : **l'alpha existait déjà**, dans le catalogue, à côté.

    booster-orange.imageset   1054 × 1408   cœur opaque 170→882 sur le corps,
                                            149→904 au cran, lueur en dégradé
    sticker-booster.imageset   794 × 1278   94,8 % d'alpha plein, bord de 2 px

Ce sont de vrais détourages, faits hors d'ici. **On ne dérive plus rien : on
les prend.** Toute la machinerie de silhouette (seuils, gradients, enveloppe
du cran, prolongement du pied, garde-fous) est SUPPRIMÉE — elle n'existait que
pour reconstruire ce qui était déjà là.

Deux traitements restent, et deux seulement :

1. ⚠️ **ON DURCIT.** L'alpha des assets porte la LUEUR du rendu en dégradé
   (22 % de pixels mi-transparents sur l'orange). La loi posée au §18.5 tient :
   *la lueur appartient à la scène, pas au sprite* — un sprite qui transporte
   sa lumière ne peut pas être ré-éclairé ni changer de couleur selon la page.
   On garde le cœur, on jette la lueur ; la scène la refait (`CoffreV2.
   lueurObjet`).

2. ⚠️ **ON COUPE LE REFLET DE L'ORANGE.** Mesuré : son alpha contient le
   sachet ET son reflet au sol, séparés par un trou net à **y = 1310** (la
   largeur opaque y tombe de 857 px à 22). Sans cette coupe, la vignette
   traîne une flaque orange sous elle. Le noir n'en a pas.

Puis les deux sont mis à la MÊME LARGEUR DE CORPS et alignés sur leur PIED :
c'est ça qui fait les jumeaux — deux sachets de tailles différentes dans deux
pages qui se feuillettent, l'œil le voit tout de suite.

Sortie : 252 × 435 — 3× la taille d'affichage de la pill (84 × 145).

Usage : python3 tools/coffre-v2/bake_vignettes.py
"""

import os
from PIL import Image
import numpy as np

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MEDIA = os.path.join(RACINE, "Nosfy", "Media")
CATALOGUE = os.path.join(RACINE, "Nosfy", "Assets.xcassets")
SORTIE = os.path.join(RACINE, "tools", "coffre-v2", "vignettes")

CIBLE = (252, 435)
# La largeur du CORPS du sachet dans la vignette. Les deux y sont ramenés,
# et c'est la seule cote qui les rend jumeaux — pas la taille du fichier.
CORPS_CIBLE = 196

SOURCES = [
    # (nom, fichier du catalogue, coupe basse ou None, sortie)
    ("orange", "booster-orange", 1310, "booster-pill.png"),
    ("noir", "sticker-booster", None, "booster-pill-noir.png"),
]


def chemin(nom):
    return os.path.join(CATALOGUE, nom + ".imageset", nom + ".png")


def durcir(al):
    """La lueur part, le cœur reste.

    ⚠️ Le seuil bas est à 0,55 et pas à 0,99 : couper net à l'opacité pleine
    donnerait un bord en escalier (l'antialiasing du détourage vit justement
    entre 0,1 et 1). En remappant 0,55 → 0 et 1,00 → 1, on jette la lueur ET
    on garde le pixel de transition qui rend le bord lisse.
    """
    return np.clip((al / 255.0 - 0.55) / 0.45, 0, 1)


def bornes(al, seuil=0.5):
    lig = np.where((al > seuil).any(axis=1))[0]
    col = np.where((al > seuil).any(axis=0))[0]
    return int(col[0]), int(col[-1]), int(lig[0]), int(lig[-1])


def corps(al, y0, y1, seuil=0.5):
    """La largeur du CORPS — la médiane des lignes, pas le maximum : le cran
    déborde le corps, et c'est le corps qui doit s'accorder entre les deux."""
    larg = []
    for y in range(y0, y1 + 1):
        xs = np.where(al[y] > seuil)[0]
        if len(xs):
            larg.append(xs[-1] - xs[0])
    return float(np.median(larg)) if larg else 1.0


def main():
    os.makedirs(SORTIE, exist_ok=True)
    for nom, asset, coupe, dst in SOURCES:
        im = Image.open(chemin(asset)).convert("RGBA")
        a = np.asarray(im).astype(float)
        al = durcir(a[..., 3])
        # ⚠️ La coupe du reflet AVANT toute mesure : sinon le reflet entre
        # dans les bornes et dans la médiane du corps.
        if coupe is not None:
            al[coupe:, :] = 0

        x0, x1, y0, y1 = bornes(al)
        larg = corps(al, y0, y1)
        k = CORPS_CIBLE / larg

        rgba = np.dstack([a[..., :3], al * 255]).astype(np.uint8)
        vue = Image.fromarray(rgba).crop((x0, y0, x1 + 1, y1 + 1))
        vue = vue.resize((max(1, round(vue.width * k)),
                          max(1, round(vue.height * k))), Image.LANCZOS)

        # ⚠️ **ALIGNÉS SUR LE PIED, PAS SUR LE CENTRE.** Les deux sachets
        # posent sur le même socle : c'est leur bas qui doit coïncider. Centrés,
        # celui qui est un peu plus court flotterait au-dessus de l'estrade.
        plaque = Image.new("RGBA", CIBLE, (0, 0, 0, 0))
        marge_bas = 6
        plaque.paste(vue, ((CIBLE[0] - vue.width) // 2,
                           CIBLE[1] - marge_bas - vue.height))
        plaque.save(os.path.join(MEDIA, dst))

        # ⚠️ LA MESURE QUI COMPTE EST LA RAIDEUR DU BORD, pas la surface : elle
        # sépare un objet découpé d'un objet qui s'estompe. Référence à
        # battre, `sticker-booster` tel qu'il est livré : 2 px.
        av = np.asarray(plaque).astype(float)[..., 3]
        lig = np.where((av > 10).any(axis=1))[0]
        rang = av[(lig[0] + lig[-1]) // 2]
        pleins = np.where(rang > 245)[0]
        bord = 0
        if len(pleins):
            g = pleins[0]
            bord = next((g - k2 for k2 in range(g, 0, -1) if rang[k2] < 10), g)
        print("%-16s → %-22s corps %3d px  vignette %3d×%-3d  "
              "opaque %.1f %%  mi-transp %.1f %%  BORD %d px"
              % (asset, dst, CORPS_CIBLE, vue.width, vue.height,
                 100 * (av > 250).mean(),
                 100 * ((av > 10) & (av < 250)).mean(), bord))

    # ⚠️ LA PLANCHE DE VERDICT EST SUR UN DAMIER, PAS SUR DU NOIR. Sur du noir,
    # un détourage faux est INVISIBLE — c'est exactement comme ça que quatre
    # versions fausses sont passées. Le damier ne pardonne rien.
    v = [Image.open(os.path.join(MEDIA, d)) for _, _, _, d in SOURCES]
    L = sum(x.width for x in v) + 20 * (len(v) + 1)
    duo = Image.new("RGB", (L, CIBLE[1] + 40))
    px = duo.load()
    for y in range(duo.height):
        for x in range(duo.width):
            px[x, y] = (255, 0, 200) if ((x // 12) + (y // 12)) % 2 == 0 \
                else (255, 255, 255)
    x = 20
    for im in v:
        duo.paste(im, (x, 20), im)
        x += im.width + 20
    duo.save(os.path.join(SORTIE, "duo.png"))
    print("damier :", os.path.join(SORTIE, "duo.png"))


if __name__ == "__main__":
    main()
