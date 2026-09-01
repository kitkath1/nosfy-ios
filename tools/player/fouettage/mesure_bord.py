"""LA MESURE DU BORD — l'instrument qui TRANCHE quand un juge pixel
accuse (§3.4bis) : la position de la frontière clair->noir du corps
player dans la colonne centrale, frame à frame. C'est la CINÉMATIQUE
réelle : vitesse légitime <= 230 px/frame (la borne du tween : 0,08 de
course x 2556 = 204, + bruit). Une « téléportation » du juge luminance
qui ne se voit pas ici est une falaise LÉGITIME (le bord traverse la
dalle ou le dôme clair).

Usage : python3 mesure_bord.py <dossier-frames> <f0> <f1>
"""
import os
import sys
from PIL import Image

dossier, a, b = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])


def bord(chemin):
    im = Image.open(chemin).convert("L")
    W, H = im.size
    col = im.crop((W // 2 - 150, 0, W // 2 + 150, H)).resize((30, H // 4))
    px = col.load()
    h4 = H // 4

    def moy(y0, y1):
        y0, y1 = max(0, y0), min(h4, y1)
        if y0 >= y1:
            return 0
        return sum(px[x, y] for y in range(y0, y1)
                   for x in range(30)) / (30 * (y1 - y0))

    for y in range(h4 - 12):
        if moy(y - 8, y - 1) > 45 and moy(y + 2, y + 10) < 18:
            return y * 4
    return None


prev = None
vmax = 0
for i in range(a, b + 1):
    chemin = os.path.join(dossier, f"f{i:04d}.png")
    if not os.path.exists(chemin):
        continue
    y = bord(chemin)
    d = (y - prev) if (y is not None and prev is not None) else None
    print(f"f{i}: bord={y}" + (f" d={d:+d}" if d is not None else ""))
    if d is not None:
        vmax = max(vmax, abs(d))
    prev = y if y is not None else prev
print(f"vitesse max {vmax} px/frame (legitime <= 230)")
sys.exit(0 if vmax <= 230 else 1)
