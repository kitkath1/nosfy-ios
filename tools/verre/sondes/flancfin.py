#!/usr/bin/env python3
"""Le flanc droit au PAS FIN (loi 10) : fil, creux, flaque proche et
profonde — RÉF (redimensionnée) vs MOI, par 2 % de hauteur.
Usage: flancfin.py <capture.png>"""
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
s = W / 362.0   # px/pt

def ligne(img, y):
    row = img[max(y-2,0):y+3, :].max(axis=0)
    fil   = float(row[int(W - 3.0*s):].max())          # ±3 pt de l'arête
    creux = float(row[int(W - 2.8*s):int(W - 0.9*s)].min())
    f47   = float(row[int(W - 7.2*s):int(W - 2.9*s)].mean())
    f1020 = float(row[int(W - 14.5*s):int(W - 7.2*s)].mean())
    return fil, creux, f47, f1020

print("  fy% |  fil R/M Δ    | creux R/M Δ   | fl.3-7pt R/M Δ | fl.7-14 R/M Δ")
bad = 0
for pct in range(22, 99, 2):
    y = int(pct / 100 * H)
    fR, cR, aR, bR = ligne(ref, y)
    fM, cM, aM, bM = ligne(live, y)
    d1, d2, d3, d4 = fM-fR, cM-cR, aM-aR, bM-bR
    flag = ""
    if abs(d1) > 0.08: flag += " FIL"
    if abs(d2) > 0.10: flag += " CREUX"
    if abs(d3) > 0.07: flag += " FLQ"
    if flag: bad += 1
    print(f"  {pct:3d} | {fR:.2f}/{fM:.2f} {d1:+.2f} | {cR:.2f}/{cM:.2f} {d2:+.2f} |"
          f" {aR:.2f}/{aM:.2f} {d3:+.2f} | {bR:.2f}/{bM:.2f} {d4:+.2f}{flag}")
print(f"lignes hors tolérance : {bad}/39")
