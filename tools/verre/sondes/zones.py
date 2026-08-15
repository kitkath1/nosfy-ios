#!/usr/bin/env python3
"""Verdict des 7 zones : capture vs cibles de la référence (médianes).
Usage: zones.py <capture.png>  — détecte la carte, imprime la table."""
import sys
import numpy as np
from PIL import Image

CIBLES = {
    "centre":      ((.30, .35, .70, .65), 0.050),
    "droite int":  ((.88, .20, .97, .80), 0.179),
    "bas int":     ((.20, .85, .80, .97), 0.123),
    "haut int":    ((.20, .03, .80, .15), 0.106),
    "gauche int":  ((.03, .20, .12, .80), 0.204),
    "coin TR int": ((.85, .02, .98, .20), 0.102),
    "coin BR int": ((.85, .80, .98, .98), 0.252),
}

a = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float32).mean(axis=2) / 255
# carte : x fixe (encarts 20pt), bord haut par pic de gradient
x0, x1 = 60, 1146
band = a[1350:1600, x0+120:x1-120].mean(axis=1)
yT = 1350 + int(np.abs(np.diff(band)).argmax())
band2 = a[yT+330:yT+420, x0+120:x1-120].mean(axis=1)
yB = yT + 330 + int(np.abs(np.diff(band2)).argmax())          # 127 pt @3x
cw, ch = x1-x0, yB-yT
print(f"carte: yT={yT} yB={yB}")
ok = True
for nom, ((fx0, fy0, fx1, fy1), cible) in CIBLES.items():
    z = a[yT+int(fy0*ch):yT+int(fy1*ch), x0+int(fx0*cw):x0+int(fx1*cw)]
    med = float(np.median(z))
    d = med - cible
    verdict = "OK " if abs(d) <= 0.02 else ("HAUT" if d > 0 else "BAS ")
    if abs(d) > 0.02: ok = False
    print(f"{nom:12} med={med:.3f} cible={cible:.3f} delta={d:+.3f}  {verdict}")
print("PHASE 3 :", "VALIDÉE" if ok else "à retoucher")
