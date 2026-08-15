#!/usr/bin/env python3
"""Le profil RADIAL du flanc droit — RÉF vs MOI, en pt depuis l'arête.
C'est la sonde de la « poussée » : elle voit le fil, le sillon, la bande
intérieure et la diffusion, là où les médianes de zones ne voient rien.
Usage: profilD.py <capture.png>"""
import sys
import numpy as np
from PIL import Image

cap = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float32)
a = cap.mean(axis=2) / 255
x0, x1 = 60, 1146
band = a[1350:1600, x0+120:x1-120].mean(axis=1)
yT = 1350 + int(np.abs(np.diff(band)).argmax())
band2 = a[yT+330:yT+420, x0+120:x1-120].mean(axis=1)
yB = yT + 330 + int(np.abs(np.diff(band2)).argmax())

live = a[yT:yB, x0:x1]
ref = Image.open("/Users/kathryn/Desktop/woochoper-ios/tools/verre/reference-card.png").convert("RGB")
ref = np.asarray(ref.resize((x1-x0, yB-yT), Image.LANCZOS), dtype=np.float32).mean(axis=2) / 255

H, W = live.shape
s = W / 362.0
DS = [0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.9, 6.3, 8.4, 10.5, 14, 18]
print("  fy% |" + "".join(f"{d:>5.1f}" for d in DS))
tot, n, pires = 0.0, 0, []
for pct in (16, 21, 26, 30, 34, 40, 50, 60, 70, 80):
    y = int(pct / 100 * H)
    vals = {}
    for nom, img in (("R", ref), ("M", live)):
        row = img[y-1:y+2, :].mean(axis=0)
        vals[nom] = [float(row[max(W - 1 - int(round(d*s)), 0)]) for d in DS]
        print(f"  {pct:3d}{nom}|" + "".join(f"{v:5.2f}" for v in vals[nom]))
    dd = [m - r for m, r in zip(vals["M"], vals["R"])]
    print("     Δ|" + "".join(f"{v:+5.2f}" for v in dd))
    # DEUX COLONNES/RANGÉES MENTEUSES, mesurées puis écartées du score :
    #  - d=0 pt : le dernier pixel du crop est un bord à couverture
    #    partielle chez moi, lissé par le LANCZOS chez la réf (490 px
    #    étirés à 1086) — un décalage d'un demi-pixel, pas de la lumière ;
    #  - fy < 26 % : on est DANS l'arc du coin (rayon 26 pt), la sonde
    #    horizontale n'y mesure plus la même profondeur. Là-haut, c'est
    #    coinArc.py qui a le dernier mot.
    for d, v in zip(DS, dd):
        if d == 0 or pct < 26:
            continue
        tot += abs(v); n += 1
        pires.append((abs(v), pct, d, v))
pires.sort(reverse=True)
print(f"\nécart absolu moyen = {tot/n:.3f}")
print("les 5 pires :", ", ".join(f"y{p}% à {d}pt ({v:+.2f})" for _, p, d, v in pires[:5]))
