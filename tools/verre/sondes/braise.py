#!/usr/bin/env python3
"""LA BRAISE DU BAS — les trois objets (17-08), RÉF et MOI mesurés
EXACTEMENT de la même façon, chacun à sa résolution native :

  1. LE CHEVEU EN ARC couché sur l'arête basse — enveloppe et épaisseur.
  2. LE RAYON À 41° — sa trace en chromie, hauteur par hauteur.
  3. LE HALO dans l'air sous la carte.

DEUX PIÈGES payés ici, d'où la forme de la sonde :
 - la crête se CHERCHE (maximum du profil vertical entre -2 et +2,5 pt) ;
   l'arête détectée au gradient peut tomber 1,3 pt à côté, et sur un cheveu
   de σ 0,5 ça divise la mesure par quatre ;
 - la trace du rayon se cherche en CHROMIE et **jamais au-delà de x=88 %** :
   au-delà, le lait du coin bas-droit gagne toujours et la sonde annonce un
   « rayon à 94,8 % » qui est le coin.
Toutes les valeurs sont des MOYENNES RVB (même convention des deux côtés).
Usage: braise.py <capture.png>"""
import sys
import numpy as np
from PIL import Image

DEHORS = {2: 0.19, 4: 0.12, 5: 0.09, 7: 0.06, 9: 0.05}   # capture Bureau 21.09.42
XARC = (0.52, 0.55, 0.58, 0.61, 0.64, 0.67, 0.70, 0.73, 0.76)
HRAY = (3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0)

cap = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float64) / 255
g = cap.mean(axis=2)
x0, x1 = 60, 1146
band = g[1350:1600, x0+120:x1-120].mean(axis=1)
yT = 1350 + int(np.abs(np.diff(band)).argmax())
band2 = g[yT+330:yT+420, x0+120:x1-120].mean(axis=1)
yB = yT + 330 + int(np.abs(np.diff(band2)).argmax())
MOI = cap[yT:yB, x0:x1]
REF = np.asarray(Image.open("/Users/kathryn/Desktop/woochoper-ios/tools/verre/"
                            "reference-card.png").convert("RGB"), dtype=np.float64) / 255

def mk(img):
    H, W, _ = img.shape
    s = W / 362.0
    def val(fx, hpt, chroma=False):
        y = H - 1 - hpt * s
        y0 = int(np.floor(y)); f = y - y0; y0 = min(max(y0, 0), H - 2)
        xa = int((fx - 0.006) * W); xb = max(int((fx + 0.006) * W), xa + 1)
        def row(r):
            z = img[r, xa:xb]
            return (z[:, 0] - z[:, 2]).mean() if chroma else z.mean()
        return row(y0) * (1 - f) + row(y0 + 1) * f
    return val

vR, vM = mk(REF), mk(MOI)

def crete(val, fx, hmin=-2.0):
    """hmin=0 pour la RÉFÉRENCE : son crop s'arrête à l'arête, il n'a pas
    d'air dessous — chercher plus bas fait buter la sonde sur la dernière
    ligne (elle rend alors une « épaisseur » égale à toute la fenêtre)."""
    hs = np.arange(hmin, 2.6, 0.1)
    v = np.array([val(fx, h) for h in hs])
    i = int(np.argmax(v)); pk = v[i]; half = pk * 0.5
    a = i
    while a > 0 and v[a] >= half: a -= 1
    b = i
    while b < len(v) - 1 and v[b] >= half: b += 1
    return pk, hs[b] - hs[a]

print("1. LE CHEVEU EN ARC — crête cherchée, pas supposée")
print("   x%  | elle | moi  |   Δ   | épaisseur elle/moi")
bad = 0
for fx in XARC:
    pr, er = crete(vR, fx, 0.0); pm, em = crete(vM, fx)
    d = pm - pr
    if abs(d) > 0.08: bad += 1
    print(f"  {fx*100:3.0f}  | {pr:.2f} | {pm:.2f} | {d:+.2f} |  {er:4.2f} / {em:4.2f} pt"
          + ("  <--" if abs(d) > 0.08 else ""))
print(f"   arc hors tolérance : {bad}/{len(XARC)}")

def trace(val, h):
    xs = np.arange(0.58, 0.885, 0.004)
    v = np.array([val(c, h, True) for c in xs])
    r = v - np.polyval(np.polyfit(xs, v, 1), xs)
    i = int(np.argmax(r))
    return xs[i], r[i]

print("\n2. LE RAYON À 41° — trace en chromie (x du sommet, fond retiré)")
print("  hauteur |  elle  |  moi   |   Δ    | relief elle/moi")
badR = 0
for h in HRAY:
    xr, rr = trace(vR, h); xm, rm = trace(vM, h)
    d = xm - xr
    ko = abs(d) > 0.025 or rm < 0.006
    if ko: badR += 1
    print(f"   {h:4.1f} pt | {xr*100:5.1f}% | {xm*100:5.1f}% | {d*100:+5.1f}% |"
          f" {rr:+.3f} / {rm:+.3f}" + ("  <--" if ko else ""))
print(f"   rayon hors tolérance : {badR}/{len(HRAY)}")

print("\n3. LE HALO DEHORS (cœur x=64 %)")
H, W, _ = MOI.shape ; s = W / 362.0
badH = 0
for hpt, cible in sorted(DEHORS.items()):
    y = yB + int(hpt * s)
    v = cap[y:y+2, x0+int(0.62*W):x0+int(0.66*W)].mean()
    d = v - cible
    if abs(d) > 0.04: badH += 1
    print(f"   {hpt:2d} pt | {cible:.2f} | {v:.2f} | {d:+.2f}" + ("  <--" if abs(d) > 0.04 else ""))
print(f"   halo hors tolérance : {badH}/{len(DEHORS)}")
