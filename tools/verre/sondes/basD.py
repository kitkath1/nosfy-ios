#!/usr/bin/env python3
"""LE BAS DE LA CARTE — la braise orange et la tranche basse, réf vs moi.
Trois lectures : le FIL lui-même (0 pt), la braise qui monte DANS le verre
(1/4/8/14 pt) et le souffle DEHORS (sous l'arête).
L'air sous la carte n'existe pas dans reference-card.png (c'est un crop de
la carte seule) : les cibles du dehors viennent de la capture Bureau de
Kathryn, mesurées une fois et inscrites ici.
Usage: basD.py <capture.png>"""
import sys
import numpy as np
from PIL import Image

# --- SES cibles DEHORS (capture 20.42.48, colonnes du rectangle rouge exclues)
#     luma sous l'arête, au cœur du souffle (x≈69 %)
DEHORS = {1: 0.46, 2: 0.18, 4: 0.11, 6: 0.07, 8: 0.05}

cap = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float64) / 255
a = cap.mean(axis=2)
x0, x1 = 60, 1146
band = a[1350:1600, x0+120:x1-120].mean(axis=1)
yT = 1350 + int(np.abs(np.diff(band)).argmax())
band2 = a[yT+330:yT+420, x0+120:x1-120].mean(axis=1)
yB = yT + 330 + int(np.abs(np.diff(band2)).argmax())
live = cap[yT:yB, x0:x1]
refI = Image.open("/Users/kathryn/Desktop/woochoper-ios/tools/verre/reference-card.png").convert("RGB")
ref = np.asarray(refI, dtype=np.float64) / 255

Hm, Wm, _ = live.shape ; sm = Wm / 362.0
Hr, Wr, _ = ref.shape ; sr = Wr / 362.0

def lit(img, s, H, W, ypt, fx):
    y = H - 1 - int(ypt * s)
    xa = int((fx - 0.008) * W) ; xb = max(int((fx + 0.008) * W), xa + 1)
    z = img[max(y-1, 0):y+2, xa:xb]
    return z.mean(), (z[:, :, 0] - z[:, :, 2]).mean()

print("=== LA TRANCHE BASSE (0-1 pt) : elle doit être SOMBRE, sauf sous la braise ===")
print("   x% " + "".join(f"{int(v*100):6d}" for v in np.arange(0.20, 0.99, 0.06)))
for ypt in (0, 1):
    lr = [] ; lm = []
    for fx in np.arange(0.20, 0.99, 0.06):
        a_, _ = lit(ref, sr, Hr, Wr, ypt, fx) ; b_, _ = lit(live, sm, Hm, Wm, ypt, fx)
        lr.append(a_) ; lm.append(b_)
    print(f"  {ypt}pt elle" + "".join(f"{v:6.2f}" for v in lr))
    print(f"      moi " + "".join(f"{v:6.2f}" for v in lm))
    print(f"      Δ   " + "".join(f"{m-r:+6.2f}" for r, m in zip(lr, lm)))

print("\n=== LA BRAISE QUI MONTE (son maximum dérive vers la DROITE) ===")
print("  haut | x cible | elle L/C | moi L/C | Δ")
bad = 0
for ypt, fx, cibleL, cibleC in ((1, 0.72, 0.55, 0.50), (4, 0.74, 0.41, 0.42),
                                (8, 0.78, 0.36, 0.33), (14, 0.80, 0.29, 0.25)):
    rl, rc = lit(ref, sr, Hr, Wr, ypt, fx)
    ml, mc = lit(live, sm, Hm, Wm, ypt, fx)
    flag = " <--" if (abs(ml-rl) > 0.07 or abs(mc-rc) > 0.08) else ""
    if flag: bad += 1
    print(f"  {ypt:2d}pt | {fx*100:4.0f} % | {rl:.2f}/{rc:+.2f} | {ml:.2f}/{mc:+.2f} |"
          f" {ml-rl:+.2f}/{mc-rc:+.2f}{flag}")
print(f"  hors tolérance : {bad}/4")

print("\n=== LE SOUFFLE DEHORS (cœur x≈69 %) ===")
print("  sous l'arête | sa cible | moi")
for ypt, cible in DEHORS.items():
    y = yB + int(ypt * sm)
    xa = x0 + int(0.681 * Wm) ; xb = x0 + int(0.699 * Wm)
    v = cap[y:y+2, xa:xb].mean()
    print(f"      {ypt:2d} pt   |   {cible:.2f}   | {v:.2f}  {v-cible:+.2f}")
