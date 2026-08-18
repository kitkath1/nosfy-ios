# Cuit le froissé de manipulation DANS booster-normal.png (pipeline maison).
# Le froissé vrai d'un film : des PLIS DROITS entre facettes plates — les
# arêtes d'un diagramme de Voronoï — plus quelques grands plis maîtres en
# diagonale. Concentré vers les sertis, doux au centre de la face.
# Usage : python3 bake_crumple.py <orig.png> <out.png> [strength]
import sys

import numpy as np
from PIL import Image

orig_path, out_path = sys.argv[1], sys.argv[2]
strength = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0

rng = np.random.default_rng(77)
im = Image.open(orig_path).convert("RGB")
W, H = im.size
n = np.asarray(im, dtype=np.float32) / 255.0 * 2.0 - 1.0  # [-1;1]

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
u = xx / W
v = yy / H

# ---- 1. le champ de plis : arêtes de Voronoï ----------------------------
# Distance au bord de cellule = (d2 - d1) : nulle sur l'arête.
NSEED = 60
sx = rng.uniform(0, W, NSEED).astype(np.float32)
sy = rng.uniform(0, H, NSEED).astype(np.float32)
d = np.full((2, H, W), 1e9, dtype=np.float32)  # d1, d2
for i in range(NSEED):
    di = np.sqrt((xx - sx[i]) ** 2 + (yy - sy[i]) ** 2)
    closer = di < d[0]
    d[1] = np.where(closer, d[0], np.minimum(d[1], di))
    d[0] = np.where(closer, di, d[0])
edge = d[1] - d[0]  # 0 sur l'arête, croît vers le cœur de cellule
crease = np.exp(-(edge / 9.0) ** 2)  # plis souples (~9 px de demi-largeur)

# Deuxième réseau, plus fin et plus faible (les petits plis secondaires).
NS2 = 320
sx2 = rng.uniform(0, W, NS2).astype(np.float32)
sy2 = rng.uniform(0, H, NS2).astype(np.float32)
d2 = np.full((2, H, W), 1e9, dtype=np.float32)
for i in range(NS2):
    di = np.sqrt((xx - sx2[i]) ** 2 + (yy - sy2[i]) ** 2)
    closer = di < d2[0]
    d2[1] = np.where(closer, d2[0], np.minimum(d2[1], di))
    d2[0] = np.where(closer, di, d2[0])
crease2 = np.exp(-((d2[1] - d2[0]) / 4.0) ** 2)

# ---- 2. les grands plis maîtres : segments diagonaux doux ---------------
def master_fold(x0, y0, x1, y1, width, amp):
    px, py = x1 - x0, y1 - y0
    ll = px * px + py * py
    t = np.clip(((xx - x0) * px + (yy - y0) * py) / ll, 0, 1)
    dist = np.sqrt((xx - (x0 + t * px)) ** 2 + (yy - (y0 + t * py)) ** 2)
    prof = np.exp(-(dist / width) ** 2)
    fade = np.sin(np.pi * t)  # le pli meurt à ses deux bouts
    return amp * prof * fade

masters = (
    master_fold(0.18 * W, 0.30 * H, 0.46 * W, 0.62 * H, 11, 1.0)
    + master_fold(0.55 * W, 0.18 * H, 0.40 * W, 0.55 * H, 9, 0.8)
    + master_fold(0.30 * W, 0.78 * H, 0.62 * W, 0.66 * H, 10, 0.9)
    + master_fold(0.70 * W, 0.40 * H, 0.55 * W, 0.80 * H, 9, 0.7)
    + master_fold(0.10 * W, 0.55 * H, 0.35 * W, 0.40 * H, 8, 0.6)
)

# ---- 3. la pondération : fort vers les sertis, doux au centre,
# et un MASQUE DE COUVERTURE — un sachet manipulé a des plages lisses,
# le froissé ne couvre pas tout (sinon c'est un sachet roulé en boule).
wgt = 0.45 + 0.55 * (
    np.clip((0.16 - v) / 0.10, 0, 1) + np.clip((v - 0.80) / 0.10, 0, 1)
)
wgt = np.clip(wgt, 0, 1.15)


def _smooth_noise(freq, seed):
    small = np.random.default_rng(seed).uniform(0, 1, (freq, freq))
    return np.asarray(
        Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC),
        dtype=np.float32,
    ) / 255.0


cover = np.clip((_smooth_noise(7, 12) - 0.35) / 0.30, 0, 1)  # ~60 % couvert
cover = 0.25 + 0.75 * cover

height = (crease * 0.55 + crease2 * 0.22 + masters * 0.9) * wgt * cover

# ---- 4. hauteur → normale, composée sur la carte d'origine --------------
gy, gx = np.gradient(height.astype(np.float32))
AMP = 2.6 * strength  # pente des plis dans la carte
n[..., 0] = n[..., 0] - gx * AMP
n[..., 1] = n[..., 1] + gy * AMP  # +Y : conventions carte (Y vers le haut)
norm = np.sqrt((n**2).sum(axis=2, keepdims=True))
n /= np.maximum(norm, 1e-6)

out = ((n + 1.0) * 0.5 * 255.0).clip(0, 255).astype(np.uint8)
Image.fromarray(out).save(out_path)
print("ok", out_path, "| plis max", float(np.abs(height).max()))
