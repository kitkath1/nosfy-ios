#!/usr/bin/env python3
"""Tranches haute et basse : pics (et chromie R-B en haut) vs la référence.
Usage: tranches.py <capture.png>"""
import sys
import numpy as np
from PIL import Image

BAS = {1:0.05, 4:0.07, 6:0.55, 9:0.43, 13:0.49, 18:0.59, 23:0.67, 28:0.80,
       31:0.87, 33:0.94, 38:0.77, 43:0.63, 48:0.58, 53:0.53, 58:0.51,
       62:0.57, 67:0.53, 72:0.58, 77:0.58, 82:0.55, 87:0.51, 92:0.56, 97:0.13}
HAUT = {1:(0.01,0.000), 7:(0.37,0.004), 13:(0.46,0.020), 18:(0.72,0.027),
        24:(0.54,0.024), 30:(0.72,-0.004), 36:(0.51,0.008), 44:(0.45,0.008),
        50:(0.47,0.012), 56:(0.50,0.027), 61:(0.50,0.110), 67:(0.49,0.145),
        73:(0.52,0.173), 78:(0.57,0.216), 84:(0.57,0.259), 87:(0.48,0.235),
        90:(0.42,0.106), 93:(0.35,0.031), 96:(0.03,0.016)}

rgb = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float32) / 255
a = rgb.mean(axis=2)
x0, x1 = 60, 1146
band = a[1350:1600, x0+120:x1-120].mean(axis=1)
yT = 1350 + int(np.abs(np.diff(band)).argmax())
band2 = a[yT+330:yT+420, x0+120:x1-120].mean(axis=1)
yB = yT + 330 + int(np.abs(np.diff(band2)).argmax())

print("=== TRANCHE BASSE (pic fil) ===")
bad = 0
for pct, ref in sorted(BAS.items()):
    x = x0 + int(pct / 100 * (x1 - x0))
    moi = float(a[yB-2:yB+3, x].max())
    d = moi - ref
    f = "  <--" if abs(d) > 0.12 else ""
    if abs(d) > 0.12: bad += 1
    print(f"  {pct:3d}  ref={ref:.2f}  moi={moi:.2f}  {d:+.2f}{f}")
print("écarts >0,12 :", bad, "/", len(BAS))

print("=== TRANCHE HAUTE (pic + chromie R-B) ===")
bad = 0
for pct, (ref, refc) in sorted(HAUT.items()):
    x = x0 + int(pct / 100 * (x1 - x0))
    seg = rgb[yT-1:yT+4, x, :]
    i = int(seg.mean(axis=1).argmax())
    r, g, b = seg[i]
    moi = float((r + g + b) / 3); moic = float(r - b)
    d, dc = moi - ref, moic - refc
    f = "  <--" if (abs(d) > 0.12 or abs(dc) > 0.08) else ""
    if abs(d) > 0.12 or abs(dc) > 0.08: bad += 1
    print(f"  {pct:3d}  ref={ref:.2f}/{refc:+.3f}  moi={moi:.2f}/{moic:+.3f}  {d:+.2f}{f}")
print("écarts :", bad, "/", len(HAUT))
