#!/usr/bin/env python3
"""Le TROU de la jauge (loi 11) : gorge noire, lèvre basse dorée, lèvre
haute froide — RÉF (redimensionnée) vs MOI, par x.
Usage: jauge.py <capture.png>"""
import sys
import numpy as np
from PIL import Image

cap = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float32) / 255
a = cap.mean(axis=2)
x0, x1 = 60, 1146
band = a[1350:1600, x0+120:x1-120].mean(axis=1)
yT = 1350 + int(np.abs(np.diff(band)).argmax())
band2 = a[yT+330:yT+420, x0+120:x1-120].mean(axis=1)
yB = yT + 330 + int(np.abs(np.diff(band2)).argmax())

liveC = cap[yT:yB, x0:x1]
refI = Image.open("/Users/kathryn/Desktop/woochoper-ios/tools/verre/reference-card.png").convert("RGB")
refC = np.asarray(refI.resize((x1-x0, yB-yT), Image.LANCZOS), dtype=np.float32) / 255

H, W, _ = liveC.shape
s = W / 362.0

def gorgeY(img):
    lum = img.mean(axis=2)
    zone = lum[int(0.62*H):int(0.93*H), int(0.40*W):int(0.90*W)].mean(axis=1)
    return int(0.62*H) + int(np.argmin(zone))

def mesure(img, yg, fx):
    lum = img.mean(axis=2)
    xa, xb = int(fx*W) - int(1.5*s), int(fx*W) + int(1.5*s)
    col = lum[:, xa:xb].mean(axis=1)
    g = float(col[yg-1:yg+2].min())
    lh = float(col[yg - int(2.6*s):yg - int(0.6*s)].max())
    zb = col[yg + int(0.6*s):yg + int(3.3*s)]
    ib = int(np.argmax(zb))
    lb = float(zb[ib])
    ylb = yg + int(0.6*s) + ib
    rgb = cap[0,0]*0  # placeholder
    rgb = img[ylb, xa:xb].mean(axis=0)
    return g, lh, lb, rgb

ygR, ygM = gorgeY(refC), gorgeY(liveC)
print(f"gorge : RÉF fy={ygR/H:.3f}  MOI fy={ygM/H:.3f}")
print("  x%  | gorge R/M Δ  | l.haut R/M Δ | l.bas R/M Δ  | RGB bas RÉF -> MOI")
bad = 0
for fx in (0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85, 0.92, 0.96):
    gR, hR, bR, cR = mesure(refC, ygR, fx)
    gM, hM, bM, cM = mesure(liveC, ygM, fx)
    dg, dh, db = gM-gR, hM-hR, bM-bR
    flag = " <-- " if (abs(db) > 0.06 or abs(dh) > 0.06 or abs(dg) > 0.06) else ""
    if flag: bad += 1
    print(f" {fx*100:3.0f} | {gR:.2f}/{gM:.2f} {dg:+.2f} | {hR:.2f}/{hM:.2f} {dh:+.2f} |"
          f" {bR:.2f}/{bM:.2f} {db:+.2f} |"
          f" ({cR[0]:.2f},{cR[1]:.2f},{cR[2]:.2f}) -> ({cM[0]:.2f},{cM[1]:.2f},{cM[2]:.2f}){flag}")
print(f"colonnes hors tolérance : {bad}/9")
