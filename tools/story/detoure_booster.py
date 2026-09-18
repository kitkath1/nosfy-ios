#!/usr/bin/env python3
# LE DÉTOURAGE DE LA POCHETTE BOOSTER (page WIN, W1) — par SILHOUETTE
# (l'école des pastilles) : le liseré holographique FERME le contour,
# donc seuil bas + remplissage des trous capture le corps noir. PAS de
# tracé analytique ici : la forme est crantée (les crêtes du haut/bas).
import numpy as np
from PIL import Image
from scipy import ndimage
import os, json

src = os.path.expanduser("~/Desktop/booster_1.png")
im = Image.open(src).convert("RGB")
rgb = np.array(im)
lum = rgb.max(axis=2).astype(float)

m = lum > 6                       # l'existence, pas la clarté
m = ndimage.binary_closing(m, structure=np.ones((7, 7)))
m = ndimage.binary_fill_holes(m)
lab, n = ndimage.label(m)
if n > 1:
    tailles = ndimage.sum(m, lab, range(1, n + 1))
    m = lab == (1 + int(np.argmax(tailles)))
# ⚠️ LE BAS SE DÉCHIRAIT (mesuré sur la première passe) : les crans
# sombres passent sous le seuil et le REFLET du sol s'invitait. Le
# VRAI bas du paquet est la dernière rangée franchement claire (la
# bande des crans) — on coupe là, puis on remplit PAR COLONNES pour
# souder les crans à la silhouette.
claires = (lum > 100).sum(axis=1)
y_bas = int(np.where(claires > 40)[0].max()) + 4
m[y_bas:, :] = False
for x in range(m.shape[1]):
    ys_c = np.where(m[:, x])[0]
    if len(ys_c) > 1:
        m[ys_c.min():ys_c.max() + 1, x] = True
dist = ndimage.distance_transform_edt(m)
alpha = np.clip(dist / 1.5, 0, 1)
dedans = dist > 3
moyen = alpha[dedans].mean()
assert moyen > 0.98, f"alpha moyen {moyen:.3f} — recette à revoir"

a8 = (alpha * 255).astype(np.uint8)
ys, xs = np.where(a8 > 0)
y0, y1 = max(0, ys.min() - 2), min(rgb.shape[0], ys.max() + 3)
x0, x1 = max(0, xs.min() - 2), min(rgb.shape[1], xs.max() + 3)
out = np.dstack([rgb, a8])[y0:y1, x0:x1]

d = "Nosfy/Assets.xcassets/sticker-booster.imageset"
os.makedirs(d, exist_ok=True)
Image.fromarray(out).save(f"{d}/sticker-booster.png")
json.dump({"images": [
    {"filename": "sticker-booster.png", "idiom": "universal", "scale": "1x"},
    {"idiom": "universal", "scale": "2x"},
    {"idiom": "universal", "scale": "3x"}],
    "info": {"author": "xcode", "version": 1}},
    open(f"{d}/Contents.json", "w"), indent=2)
print(f"sticker-booster : {out.shape[1]}x{out.shape[0]}  alpha_sujet={moyen:.3f}")
