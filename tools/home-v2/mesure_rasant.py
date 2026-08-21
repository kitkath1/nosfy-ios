#!/usr/bin/env python3
"""Mesure le rasant de la chambre noire contre les cibles du plan (§ 2.1).

    python3 tools/home-v2/mesure_rasant.py <capture.png>

Les cibles du jalon 1 :
  - sommet L ≈ 112 (la v1 monte à 200)
  - plus rien (L < 8) au-delà de x = 300 pt et de y = 330 pt
  - ≥ 78 % des pixels sous L = 24
  - zéro écrêtage (aucun pixel à 3 canaux > 252)
  - pas de brun : dans la queue, la saturation doit MONTER quand L descend
"""
import sys
import numpy as np
from PIL import Image


def lum(a):
    # Luma perceptuel sur les valeurs sRGB telles qu'affichées (c'est ce que
    # l'œil lit sur la capture, pas une luminance linéaire).
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def main(path, ang=32.0, y0pt=0.0):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    h, w, _ = a.shape
    scale = w / 402.0          # points -> pixels
    L = lum(a)

    # Par defaut on mesure TOUT le cadre : la capture doit venir de
    # `-isoRasant`, ou la barre de statut est cachee. Couper les 120 premiers
    # points pour l'eviter reviendrait a jeter la zone la plus claire du
    # rasant — c'est le piege du premier tour (sommet annonce 108 alors que le
    # champ plafonnait a 78 : la sonde mesurait l'heure).
    y0 = int(y0pt * scale)
    F = L[y0:, :]

    print(f"capture {w}x{h} ({w/scale:.0f}x{h/scale:.0f} pt), echelle x{scale:.1f}")
    print()
    print(f"  sommet L                 {F.max():6.1f}   (cible ~112)")
    print(f"  moyenne L                {F.mean():6.1f}")
    print(f"  part sous L=24           {100.0 * (F < 24).mean():6.1f} %  (cible >=78)")
    print(f"  part sous L=8            {100.0 * (F < 8).mean():6.1f} %")
    ecret = ((a[..., 0] > 252) & (a[..., 1] > 252) & (a[..., 2] > 252)).sum()
    print(f"  pixels ecretes           {ecret:6d}   (cible 0 hors ile/statut)")
    print()

    # L'extinction : le dernier x (et le dernier y) ou L depasse 8.
    colmax = F.max(axis=0)
    rowmax = F.max(axis=1)
    xs = np.nonzero(colmax > 8)[0]
    ys = np.nonzero(rowmax > 8)[0]
    x_mort = (xs[-1] / scale) if len(xs) else 0.0
    y_mort = ((ys[-1] + y0) / scale) if len(ys) else 0.0
    print(f"  mort en x (L<8 au-dela)  {x_mort:6.0f} pt  (cible <=300)")
    print(f"  mort en y (L<8 au-dela)  {y_mort:6.0f} pt  (cible <=330)")
    print()

    # Le coin haut-droit doit etre du noir absolu : c'est l'ecrin du lisere de
    # neon de la lune (elle vit a x = 334, y = 108).
    coin = L[int(60 * scale):int(280 * scale), int(300 * scale):]
    print(f"  coin haut-droit  max L   {coin.max():6.1f}   (cible <=4)")

    # Le profil de la diagonale du faisceau, tous les 40 pt.
    print()
    print(f"  profil du faisceau (le long de l'axe {ang:.0f} deg) :")
    for k in range(0, 11):
        d = k * 40.0
        x = int((-40 + d * np.cos(np.radians(ang))) * scale)
        y = int((24 + d * np.sin(np.radians(ang))) * scale)
        if 0 <= x < w and y0 <= y < h:
            print(f"    {d:5.0f} pt -> L {L[y, x]:6.1f}")

    # L'anti-brun : saturation par tranche de L.
    print()
    print("  saturation par tranche de L (elle doit MONTER quand L tombe) :")
    mx = a.max(axis=2)
    mn = a.min(axis=2)
    sat = np.where(mx > 1, (mx - mn) / np.maximum(mx, 1), 0.0)[y0:, :]
    for lo, hi in [(90, 130), (60, 90), (35, 60), (18, 35), (8, 18)]:
        m = (F >= lo) & (F < hi)
        if m.sum() > 200:
            print(f"    L {lo:3d}-{hi:3d}  sat {sat[m].mean():.3f}"
                  f"   ({100.0 * m.mean():5.2f} % des pixels)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "shots/j1.png")
