#!/usr/bin/env python3
"""Mesure de carte-lune-1.png : cadre orange, bandes du paysage.

Sort les bornes du cadre (en fraction d'image), le rayon d'angle approximatif,
et un profil de luminance par ligne pour situer les bandes (ciel / braise /
montagnes / forêt) — la base de la depth map.
"""
import numpy as np
from PIL import Image

img = np.asarray(Image.open("carte-lune-1.png").convert("RGB")).astype(np.float32) / 255
H, W, _ = img.shape
r, g, b = img[..., 0], img[..., 1], img[..., 2]
lum = 0.299 * r + 0.587 * g + 0.114 * b
# Le liseré du cadre : orange vif (R haut, B bas).
orange = (r > 0.55) & (b < 0.35) & (r - b > 0.3)

# Bornes du cadre : première/dernière ligne et colonne contenant du liseré.
rows = np.where(orange.any(axis=1))[0]
cols = np.where(orange.any(axis=0))[0]
print(f"image {W}x{H}")
print(f"cadre  y: {rows[0]}..{rows[-1]}  ({rows[0]/H:.4f}..{rows[-1]/H:.4f})")
print(f"cadre  x: {cols[0]}..{cols[-1]}  ({cols[0]/W:.4f}..{cols[-1]/W:.4f})")

# À mi-hauteur, où sont les liserés gauche/droit (épaisseur du double trait) ?
mid = H // 2
xs = np.where(orange[mid])[0]
if len(xs):
    print(f"liserés à mi-hauteur : x={xs.min()}..{xs.max()}, groupes:",
          np.split(xs, np.where(np.diff(xs) > 5)[0] + 1)[0][[0, -1]],
          np.split(xs, np.where(np.diff(xs) > 5)[0] + 1)[-1][[0, -1]])
# À mi-largeur, liserés haut/bas.
midx = W // 2
ys = np.where(orange[:, midx])[0]
if len(ys):
    gr = np.split(ys, np.where(np.diff(ys) > 5)[0] + 1)
    print("liserés à mi-largeur :", [(int(a[0]), int(a[-1])) for a in gr])

# Profil de luminance par ligne DANS le cadre (moyenne des colonnes internes).
x0, x1 = cols[0] + 30, cols[-1] - 30
prof = lum[:, x0:x1].mean(axis=1)
print("\nprofil (y/H, luminance moyenne) :")
for i in range(0, H, H // 28):
    bar = "#" * int(prof[i] * 120)
    print(f"  {i/H:.3f}  {prof[i]:.3f} {bar}")

# La ligne la plus lumineuse (cœur de la braise / horizon).
inner = prof[rows[0] + 40 : rows[-1] - 40]
peak = int(np.argmax(inner)) + rows[0] + 40
print(f"\nhorizon (pic de braise) : y={peak} ({peak/H:.4f})")
