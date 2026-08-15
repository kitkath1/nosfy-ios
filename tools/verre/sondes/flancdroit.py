#!/usr/bin/env python3
"""Enveloppe du fil droit : ma capture vs la référence, par % de hauteur.
Usage: flancdroit.py <capture.png>"""
import sys
import numpy as np
from PIL import Image

# la référence (mesurée une fois pour toutes, % hauteur -> pic luma)
REF = {2:0.02, 7:0.03, 11:0.06, 14:0.24, 19:0.62, 23:0.48, 28:0.49,
       33:0.55, 38:0.64, 43:0.75, 48:0.85, 52:0.88, 57:0.93, 62:0.91,
       67:0.88, 72:0.90, 77:0.86, 81:0.86, 86:0.66, 89:0.15, 93:0.08}

a = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float32).mean(axis=2) / 255
x0, x1 = 60, 1146
band = a[1350:1600, x0+120:x1-120].mean(axis=1)
yT = 1350 + int(np.abs(np.diff(band)).argmax())
band2 = a[yT+330:yT+420, x0+120:x1-120].mean(axis=1)
yB = yT + 330 + int(np.abs(np.diff(band2)).argmax())
print("   %   REF   MOI   delta")
bad = 0
for pct, ref in sorted(REF.items()):
    y = yT + int(pct / 100 * (yB - yT))
    moi = float(a[y-2:y+3, x1-5:x1+4].max())
    d = moi - ref
    flag = "  <-- " if abs(d) > 0.12 else ""
    if abs(d) > 0.12: bad += 1
    print(f"  {pct:3d}  {ref:.2f}  {moi:.2f}  {d:+.2f}{flag}")
print("écarts >0,12 :", bad, "/", len(REF))
