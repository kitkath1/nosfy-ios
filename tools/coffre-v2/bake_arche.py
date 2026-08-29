#!/usr/bin/env python3
"""LE FOND « ARCHE DE VERRE NOIR » — cuit à la place de l'écran.

Verdict du 29-08 : *« essaie avec le background finalement `test-Backgorund`
sur mon bureau, il faut que ça fasse un peu fondu noir bien sûr pour que ça
passe dans l'écran d'iPhone et qu'on voit le bas avec les boutons et la
progress bar »*.

⚠️ **CE N'EST PAS UN RÉGLAGE, C'EST UN CHANGEMENT DE NATURE.** Le spotlight
était un ÉCLAIRAGE — une lumière qui tombe, qu'on peut teinter. Ceci est un
DÉCOR : une architecture qui encadre, et qui a sa propre couleur. Les deux ne
se règlent pas pareil, et ils ne se jugent pas sur la même page (voir §23.5 du
plan : le risque de ce fond est sur les pages ARGENT et NOIRE, pas sur
l'orange).

Mesuré sur la source (941 × 1672, rapport 0,5628 quand l'écran est à 0,4600) :

    sommet de SON socle .......... 0,701 H
    largeur de son socle ......... 59 % de la largeur
    ouverture de l'arche ......... x 0,26 → 0,72
    le bas (0,80 → 1,00 H) ....... L 20,8 — le plus CLAIR de l'image

⚠️⚠️ **SON SOCLE DEVIENT LE SOCLE** (« non, enlève le nôtre »). Le premier jet
faisait l'inverse — glisser l'image pour poser son socle sur le nôtre, et
effacer le sien. C'est `coffre-podium.png` qui disparaît de la page.

La contradiction restante : son image est composée avec sa lumière EN BAS,
et le pied (compte, règle, jauge, « Ouvrir ») vit entre 0,75 et 0,95 H. Le
fondu du bas commence donc SOUS la base de son socle (0,862 de l'image) — on
perd les caustiques du sol, et c'est le prix explicitement demandé.

⚠️ **AJUSTÉ À LA LARGEUR, JAMAIS EN `aspectFill`.** 18 % de largeur en trop —
mais ici, contrairement au spotlight, **les bords PORTENT le sujet** : les
montants de l'arche et les gouttes vivent dans les 26 % extérieurs. Les couper
serait couper le décor.

Usage : python3 tools/coffre-v2/bake_arche.py
"""

import os
import numpy as np
from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MEDIA = os.path.join(RACINE, "Woop", "Media")
SORTIE = os.path.join(RACINE, "tools", "coffre-v2", "vignettes")
SOURCE = os.path.expanduser("~/Desktop/test-Backgorund.png")

CIBLE = (1206, 2622)             # l'écran au 3×

# ⚠️⚠️ **VERDICT DU 29-08 : « NON, ENLÈVE LE NÔTRE ».** Le premier jet
# glissait l'image pour poser SON socle sur le NÔTRE et effaçait le sien.
# C'est l'inverse : **son socle devient LE socle**, et `coffre-podium.png`
# disparaît de la page. Conséquence assumée, et elle est lourde — toute la
# géométrie (`yHaut`, `yBas`, `podCentre`, la pose des objets, la marche des
# voisins, l'atterrissage, la gerbe, et **le masque des flaques**) se
# raccroche désormais à un socle qui vit DANS le fond.
#
# Son socle, mesuré au LISERÉ ORANGE saturé (R−B > 45) et non à la luminance,
# parce que les caustiques du sol traversent toute la largeur et polluent
# toute mesure de « bande claire » :
#
#     surface de pose ...... 0,742 H de l'image
#     base ................. 0,860 H
#     largeur du plateau ... 0,447 W     centre x 0,506 W
#
# L'image est posée AJUSTÉE À LA LARGEUR et alignée en haut : les montants de
# l'arche et les gouttes vivent dans les 26 % extérieurs, un `aspectFill` les
# couperait. Sa surface de pose tombe alors à **0,6064 H de l'écran** — c'est
# la nouvelle valeur de `podiumY`.
SON_SOCLE = 0.742                # surface de pose, dans l'image
SON_BAS = 0.860                  # base du socle, dans l'image
# ⚠️ Le fondu du bas commence SOUS sa base : au-dessus, il mangerait le socle
# qu'on vient d'adopter. On perd les caustiques du sol — c'est le prix
# explicitement demandé (« qu'on voit le bas avec les boutons et la progress
# bar »).
EFFACE0, EFFACE1 = 0.862, 0.960
COTE = 0.09                      # le fondu latéral

# ⚠️ **L'IMAGE REMONTE DE 130 px, ET C'EST LE PIED QUI L'EXIGE.** Posée en
# haut, sa surface de pose tombait à 0,6064 H — **cinquante points plus bas**
# que le socle qu'on remplaçait (0,5564). Tout ce qui vit dessous perdait
# autant : mesuré sur capture, la barre de crans se retrouvait POSÉE SUR le
# socle, et le bouton « Ouvrir » à 37 pt du bord de l'écran.
#
# On rogne donc 130 px du haut — la couronne de l'arche, qui est du décor pur
# et dont on ne perd que 6 %. La surface de pose revient à **0,5568 H**, soit
# la cote d'avant à un demi-millième près : toute la mise en page du bas
# retrouve exactement l'air qu'on lui avait réglé.
MONTE = 130


def cosinus(t):
    """Une rampe à tangente nulle aux deux bouts.

    ⚠️ Jamais une rampe droite : sa dérivée SAUTE là où elle commence, et sur
    un fond aussi sombre l'œil voit l'arête immédiatement.
    """
    return 0.5 - 0.5 * np.cos(np.pi * np.clip(t, 0, 1))


def main():
    im = Image.open(SOURCE).convert("RGB")
    k = CIBLE[0] / im.width
    vue = im.resize((CIBLE[0], round(im.height * k)), Image.LANCZOS)
    a = np.asarray(vue).astype(float)
    H, W, _ = a.shape

    # ── LE FONDU, dans l'espace de l'IMAGE ─────────────────────────────
    y = np.arange(H) / H
    bas = 1 - cosinus((y - EFFACE0) / (EFFACE1 - EFFACE0))
    x = np.arange(W) / W
    cote = np.ones(W)
    cote[x < COTE] = cosinus(x[x < COTE] / COTE)
    m = x > 1 - COTE
    cote[m] = cosinus((1 - x[m]) / COTE)
    a *= bas[:, None, None] * cote[None, :, None]

    # ── REMONTÉE : c'est SON socle qui commande, mais le pied a son mot ──
    plaque = np.zeros((CIBLE[1], CIBLE[0], 3), float)
    n = min(H - MONTE, CIBLE[1])
    plaque[:n] = a[MONTE:MONTE + n]

    sortie = Image.fromarray(np.clip(plaque, 0, 255).astype(np.uint8))
    sortie.save(os.path.join(MEDIA, "coffre-arche.png"))

    L = np.asarray(sortie.convert("L")).astype(float)
    HH = CIBLE[1]
    print("test-Backgorund.png %dx%d → coffre-arche.png %dx%d"
          % (im.width, im.height, *CIBLE))
    print("  ⚠️ podiumY À REPORTER DANS `CoffreV2Cotes` : %.4f"
          % ((SON_SOCLE * H - MONTE) / CIBLE[1]))
    print("     base du socle à l'écran : %.4f H"
          % ((SON_BAS * H - MONTE) / CIBLE[1]))
    print("     l'image finit à %.4f H — en dessous, du noir"
          % ((H - MONTE) / CIBLE[1]))
    print("  luminance par hauteur :", " ".join(
        "%.2f:%.0f" % (f, L[int(f * HH), W // 2 - 80:W // 2 + 80].mean())
        for f in (0.05, 0.20, 0.35, 0.50, 0.556, 0.65, 0.75, 0.90)))
    print("  bords : gauche %.1f · droite %.1f"
          % (L[:, :25].mean(), L[:, -25:].mean()))
    print("  ⚠️ le PIED (0,75 → 0,95 H) : L moyenne %.1f  %s"
          % (L[int(HH * 0.75):int(HH * 0.95)].mean(),
             "✓ noir" if L[int(HH * 0.75):int(HH * 0.95)].mean() < 3 else
             "⚠ encore clair"))
    os.makedirs(SORTIE, exist_ok=True)
    sortie.resize((CIBLE[0] // 3, CIBLE[1] // 3), Image.LANCZOS) \
          .save(os.path.join(SORTIE, "arche-1x.png"))


if __name__ == "__main__":
    main()
