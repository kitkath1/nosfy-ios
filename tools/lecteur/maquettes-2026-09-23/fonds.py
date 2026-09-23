# -*- coding: utf-8 -*-
"""Les deux fonds proposés, calculés sur la vraie capture."""
import numpy as np
from PIL import Image

def charge(p, w=760):
    im = Image.open(p).convert("RGB"); im.thumbnail((w, w*4), Image.LANCZOS); return im

def lueur(a, cx, cy, rx, ry, force, teinte=(1.0, 0.42, 0.12)):
    """Une lueur additive, ovale. Additive = de la lumière, pas un lavis gris."""
    h, w = a.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xs - cx*w)/(rx*w))**2 + ((ys - cy*h)/(ry*h))**2)
    g = np.clip(1.0 - d, 0, 1) ** 2.1 * force
    return np.clip(a + g[..., None] * np.array(teinte, np.float32), 0, 1)

def noircir(a, y0, y1):
    h = a.shape[0]; a[int(y0*h):int(y1*h)] *= 0.02; return a

# ── 1. AJOUTER UN EXERCICE : la braise remonte derrière le bouton
im = charge("lab-final.png")
a = np.asarray(im, np.float32)/255.0
a = noircir(a, 0.392, 0.492)                      # les carrés s'en vont
a = lueur(a, 0.5, 0.60, 0.62, 0.30, 0.30)         # le foyer du bas monte
a = lueur(a, 0.5, 0.443, 0.46, 0.055, 0.55)       # et se ramasse sous le bouton
a = lueur(a, 0.5, 0.443, 0.20, 0.028, 0.35, (1,.75,.45))
Image.fromarray((a*255).astype(np.uint8)).save("pub7/im/ajout.jpg", quality=88)

# ── 2. EN COURS : le foyer plus chaud, et la SÉRIE en cours portée
a = np.asarray(im, np.float32)/255.0
a = lueur(a, 0.5, 0.97, 0.85, 0.26, 0.42)         # le foyer respire plus près
a = lueur(a, 0.42, 0.633, 0.50, 0.030, 0.26, (1,.5,.18))   # la série 2, en cours
Image.fromarray((a*255).astype(np.uint8)).save("pub7/im/encours-fond.jpg", quality=88)

charge("lab-final.png").save("pub7/im/encours-avant.jpg", quality=88)
print("ok")
