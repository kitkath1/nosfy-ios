#!/usr/bin/env python3
"""LE JUGE DU RACCORD — la ligne qu'on lit saute-t-elle à la bascule ?

    python3 tools/home-v2/juge_raccord.py <film.mov> [--fps 30]

CE QU'IL MESURE, ET POURQUOI C'EST LE SEUL TEST QUI VAILLE.

Pendant le film de départ, la phrase d'accueil DESCEND et la phrase d'arrivée
MONTE ; à `basculeAt` (0,94 × T) elles se substituent en 0,12 s. Les deux blocs
sont censés avoir leurs BAS confondus À CHAQUE IMAGE — c'est ce qui fait lire
l'échange comme une métamorphose et non comme un remplacement.

Donc : **le bas de l'encre ne doit pas SAUTER** d'une image à l'autre. S'il
saute d'une hauteur de ligne (~38 pt), `DepartCine.courseTexte` est faux —
c'est exactement le défaut qu'introduit une phrase d'accueil qui perd une ligne
sans recalage, puisqu'elle est ancrée par le HAUT et l'arrivée par le BAS.

⚠️ On mesure sur les PIXELS CLAIRS d'une bande étroite (la gouttière du texte),
jamais en moyenne : sur du noir une moyenne tire vers le beige et invente de
l'encre. Et on ignore les images où le bloc est trop flou pour porter de
l'encre franche (le flou de la cloche monte à 15 pt) — une absence n'est pas
un saut.
"""
import subprocess
import sys
import tempfile
import os
import glob
import numpy as np
from PIL import Image


def bas_encre(path, seuil=150, mini=4):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    L = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    h, w = L.shape
    s = w / 393.0
    # La gouttière du texte, et rien d'autre : le slider et la bulle vivent
    # ailleurs. On s'arrête à 760 pt pour ne pas attraper le slider.
    b = L[:int(760 * s), int(24 * s):int(300 * s)]
    cl = (b > seuil).sum(axis=1)
    ys = [y for y, v in enumerate(cl) if v >= mini]
    return (ys[-1] / s if ys else None), s


def main(argv):
    film = argv[0]
    fps = 30
    if "--fps" in argv:
        fps = int(argv[argv.index("--fps") + 1])
    tmp = tempfile.mkdtemp(prefix="raccord-")
    subprocess.run(
        ["ffmpeg", "-v", "error", "-i", film, "-vf", f"fps={fps}",
         os.path.join(tmp, "f%05d.png")], check=True)
    frames = sorted(glob.glob(os.path.join(tmp, "f*.png")))
    print(f"{len(frames)} images à {fps} img/s\n")

    print(f"{'t (s)':>7} {'bas encre (pt)':>15} {'saut':>8}")
    prec = None
    sauts = []
    for i, f in enumerate(frames):
        bas, _ = bas_encre(f)
        t = i / fps
        if bas is None:
            prec = None
            continue
        d = "" if prec is None else f"{bas - prec:+.1f}"
        if prec is not None and abs(bas - prec) > 12:
            sauts.append((t, prec, bas))
            d += "  <<<"
        print(f"{t:7.2f} {bas:15.1f} {d:>8}")
        prec = bas

    print()
    if not sauts:
        print("VERDICT : aucun saut > 12 pt — le bas de l'encre est CONTINU.")
    else:
        print(f"VERDICT : {len(sauts)} saut(s) > 12 pt :")
        for t, a, b in sauts:
            print(f"  à t={t:.2f}s : {a:.1f} -> {b:.1f} pt ({b - a:+.1f})")
    print(f"\nimages : {tmp}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1:])
