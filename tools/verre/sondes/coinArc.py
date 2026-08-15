#!/usr/bin/env python3
"""Les coins DROITS à l'arc : RÉF vs MOI, balayage angulaire (loi 9).
θ=0 côté flanc droit, θ=90 côté tranche (haute pour TR, basse pour BR).
La réf est redimensionnée à la taille de la carte live : mêmes
échantillonneurs, mêmes pixels — le delta est la seule vérité.
Usage: coinArc.py <capture.png>"""
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
scale = W / 362.0                     # px par pt
R = 26.0 * scale                      # rayon du coin fermé

def profil(img, cx, cy, dx, dy):
    rs = np.arange(R - 24*scale, R + 5*scale, 0.5)
    xs = np.clip((cx + dx*rs).astype(int), 0, W-1)
    ys = np.clip((cy + dy*rs).astype(int), 0, H-1)
    return rs, img[ys, xs]

def mesure(img, cx, cy, sx, sy, th):
    ang = np.radians(th)
    rs, prof = profil(img, cx, cy, sx*np.cos(ang), sy*np.sin(ang))
    pres = np.abs(rs - R) <= 2.5*scale/3.0*2   # ±~1,7 pt de l'arête
    fil = float(prof[pres].max())
    pk = int(np.argmax(np.where(pres, prof, 0)))
    half = fil * 0.5
    l = pk
    while l > 0 and prof[l] >= half: l -= 1
    r_ = pk
    while r_ < len(prof)-1 and prof[r_] >= half: r_ += 1
    largeur = (r_ - l) * 0.5 / scale           # en pt
    i27  = float(prof[(rs >= R - 7.2*scale) & (rs <= R - 2.2*scale)].mean())
    i714 = float(prof[(rs >= R - 14.5*scale) & (rs <= R - 7.2*scale)].mean())
    return fil, largeur, i27, i714

for nom, cy, sy in (("TR", R, -1), ("BR", H - R, +1)):
    cx = W - R
    print(f"--- COIN {nom} --- θ | fil R/M Δ | larg pt R/M | in2-7pt R/M Δ | in7-14 R/M Δ")
    bad = 0
    for th in range(0, 93, 3):
        fR, lR, iR, jR = mesure(ref,  cx, cy, +1, sy, th)
        fM, lM, iM, jM = mesure(live, cx, cy, +1, sy, th)
        df, di, dj = fM - fR, iM - iR, jM - jR
        flag = ""
        if abs(df) > 0.08: flag += " FIL"
        if abs(di) > 0.06: flag += " INT"
        if flag: bad += 1
        print(f"{th:3d} | {fR:.2f}/{fM:.2f} {df:+.2f} | {lR:4.1f}/{lM:4.1f} |"
              f" {iR:.2f}/{iM:.2f} {di:+.2f} | {jR:.2f}/{jM:.2f} {dj:+.2f}{flag}")
    print(f"coin {nom} : {bad}/31 angles hors tolérance")
