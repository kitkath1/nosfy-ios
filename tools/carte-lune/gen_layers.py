#!/usr/bin/env python3
"""Découpe de carte-lune-1.png en COUCHES pour la caméra multiplane.

Palier 2 de l'immersive : quatre plans réels, chacun complété par
inpainting derrière le plan qui le précède — quand la caméra les écarte,
aucun trou n'apparaît. Recadré à l'AIRE DE L'ART (le monde n'a pas de
cadre) : x 0,118..0,881 · y 0,083..0,891 (mesure.py).

  L0  le ciel et la lune   (opaque, inpaint derrière nuages+montagnes+forêt)
  L1  les nuages           (alpha, inpaint derrière montagnes+forêt)
  L2  montagnes et braise  (alpha, inpaint derrière la forêt)
  L3  la forêt et sa brume (alpha, l'image telle quelle)

Sorties : carte-lune-L0..L3.png + layers-debug.png (planche de contrôle).
"""
import numpy as np
import cv2
from PIL import Image

img = np.asarray(Image.open("carte-lune-1.png").convert("RGB"))
H, W, _ = img.shape
lum = (0.299 * img[..., 0] + 0.587 * img[..., 1]
       + 0.114 * img[..., 2]).astype(np.float32) / 255

ys = np.linspace(0, 1, H, dtype=np.float32)[:, None] * np.ones((1, W), np.float32)
xs = np.ones((H, 1), np.float32) * np.linspace(0, 1, W, dtype=np.float32)[None, :]

def sstep(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)

# La profondeur pleine résolution — les formules de gen_depth.py.
base = np.interp(ys, [0.00, 0.44, 0.52, 0.58, 0.62, 0.75, 1.00],
                     [1.00, 1.00, 0.80, 0.50, 0.45, 0.26, 0.10]).astype(np.float32)
cloud = (sstep(0.022, 0.060, lum) * sstep(0.24, 0.30, ys)
         * (1 - sstep(0.46, 0.58, ys)))
moon = 1 - sstep(0.045, 0.075, np.sqrt((xs - 0.500) ** 2
                                       + ((ys - 0.272) * H / W) ** 2))
cloud *= (1 - moon)
depth = base * (1 - 0.28 * cloud)
darkness = sstep(0.020, 0.062, lum)
treezone = sstep(0.55, 0.62, ys)
depth = depth * (1 - 0.55 * (1 - darkness) * treezone)
depth = cv2.GaussianBlur(depth, (0, 0), 4)

# La plaque du médaillon et son disque appartiennent au CADRE : ils doivent
# DISPARAÎTRE du monde — inpaintés dans toutes les couches, alpha zéro
# partout (sinon le logo flotte dans le ciel de la vallée).
ax, ay, bx, by = 0.118, 0.205, 0.315, 0.056
sd = (bx - ax) * (ys - ay) - (by - ay) * (xs - ax)
plate = 1 - sstep(0.000, 0.022, sd)
disc = 1 - sstep(0.110, 0.150, np.sqrt((xs - 0.200) ** 2
                                       + ((ys - 0.135) * H / W) ** 2))
badge = np.maximum(plate, disc)

# Les alphas de plans — des bandes de profondeur, à lisière douce.
m3 = sstep(0.34, 0.20, depth) * (1 - badge)          # forêt proche
m2 = sstep(0.62, 0.50, depth) * (1 - m3) * (1 - badge)  # montagnes + braise
m1 = np.clip(cloud * (1 - m2 - m3), 0, 1) * (1 - badge)  # nuages
m1 = cv2.GaussianBlur(m1, (0, 0), 3)
m2 = cv2.GaussianBlur(m2, (0, 0), 3)
m3 = cv2.GaussianBlur(m3, (0, 0), 3)

def inpaint(rgb, mask):
    """Complète l'image là où `mask` (0..1) retire un plan plus proche."""
    m8 = (np.clip(mask, 0, 1) > 0.25).astype(np.uint8) * 255
    m8 = cv2.dilate(m8, np.ones((7, 7), np.uint8))
    return cv2.inpaint(rgb, m8, 11, cv2.INPAINT_TELEA)

bgr = img[..., ::-1].copy()
L0 = inpaint(bgr, np.maximum(np.maximum(np.maximum(m1, m2), m3), badge))
# L'inpaint du ciel strie (Telea tire la braise en colonnes) : cette zone
# n'est jamais vue qu'en LISIÈRE, on la fond en atmosphère — un grand flou,
# mélangé là où l'inpaint a travaillé.
L0soft = cv2.GaussianBlur(L0, (0, 0), 18)
w0 = cv2.GaussianBlur(np.maximum(np.maximum(m1, m2), np.maximum(m3, badge)),
                      (0, 0), 6)[..., None]
L0 = (L0soft * w0 + L0 * (1 - w0)).astype(np.uint8)
L1 = inpaint(bgr, np.maximum(np.maximum(m2, m3), badge))
L2 = inpaint(bgr, np.maximum(m3, badge))
L3 = bgr

# Recadrage à l'aire de l'art, RESSERRÉ d'un cheveu : les lisérés du cadre
# bavent dans l'aire mesurée, et une bande orange qui flotte entre deux
# plans trahit tout. Les alphas fondent aussi sur 12 px de bord — le
# sur-balayage des plans (échelle de base 1,14) recouvre la lisière.
x0, x1 = int(0.127 * W), int(0.872 * W)
y0, y1 = int(0.092 * H), int(0.882 * H)
def crop(a): return a[y0:y1, x0:x1]

cw, ch = x1 - x0, y1 - y0
fx = np.minimum(np.arange(cw) / 20.0, np.minimum(1, (cw - 1 - np.arange(cw)) / 20.0))
fy = np.minimum(np.arange(ch) / 20.0, np.minimum(1, (ch - 1 - np.arange(ch)) / 20.0))
edge = np.clip(fy[:, None], 0, 1) * np.clip(fx[None, :], 0, 1)

def save(name, bgr_img, alpha=None):
    rgb = bgr_img[..., ::-1]
    if alpha is None:
        out = Image.fromarray(crop(rgb))
    else:
        a8 = (np.clip(crop(alpha) * edge, 0, 1) * 255).astype(np.uint8)
        out = Image.fromarray(np.dstack([crop(rgb), a8]))
    out.save(name)
    return out.size

print("L0", save("carte-lune-L0.png", L0))
print("L1", save("carte-lune-L1.png", L1, m1))
print("L2", save("carte-lune-L2.png", L2, m2))
print("L3", save("carte-lune-L3.png", L3, m3))

# La planche de contrôle : chaque plan sur damier, à plat.
def board(p):
    im = Image.open(p).convert("RGBA")
    bg = Image.new("RGBA", im.size, (24, 24, 28, 255))
    for yy in range(0, im.size[1], 64):
        for xx in range(0, im.size[0], 64):
            if (xx // 64 + yy // 64) % 2 == 0:
                bg.paste((40, 40, 46, 255), (xx, yy, min(xx + 64, im.size[0]),
                                             min(yy + 64, im.size[1])))
    bg.alpha_composite(im)
    return bg.convert("RGB").resize((im.size[0] // 3, im.size[1] // 3))

tiles = [board(f"carte-lune-L{i}.png") for i in range(4)]
sheet = Image.new("RGB", (tiles[0].size[0] * 4 + 30, tiles[0].size[1]), (0, 0, 0))
for i, t in enumerate(tiles):
    sheet.paste(t, (i * (t.size[0] + 10), 0))
sheet.save("layers-debug.png")
print("OK layers-debug.png")
