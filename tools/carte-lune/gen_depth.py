#!/usr/bin/env python3
"""Depth map de carte-lune-1.png — v1 « fenêtre ».

Convention : 0 = plan de l'écran (le cadre, la marge noire), 1 = fond du ciel.
Le paysage recule par bandes (forêt proche → montagnes → nuages → ciel), et
les silhouettes d'arbres (pixels quasi noirs du bas) sont RAMENÉES vers
l'avant : ce sont elles qui donnent le frémissement de sous-bois.
Sortie : carte-lune-1-depth.png (demi-résolution, niveaux de gris).
"""
import numpy as np
from PIL import Image, ImageFilter

SRC = "carte-lune-1.png"
OUT = "carte-lune-1-depth.png"

img = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32) / 255
H, W, _ = img.shape
lum = 0.299 * img[..., 0] + 0.587 * img[..., 1] + 0.114 * img[..., 2]

ys = np.linspace(0, 1, H, dtype=np.float32)[:, None] * np.ones((1, W), np.float32)
xs = np.ones((H, 1), np.float32) * np.linspace(0, 1, W, dtype=np.float32)[None, :]

# Bandes mesurées par mesure.py : art 0.083..0.891, pic de braise ~0.55.
# ÉTAGEMENT v2 (le remède au « décollé ») : le plan 0,45 est le PIVOT — dans
# le shader, ce qui est à 0,45 reste collé au cadre, le ciel recule d'un
# côté, les sapins avancent de l'autre. Et les couches doivent avoir des
# vitesses FRANCHEMENT différentes : ciel 1,0 / nuages ~0,72 / montagnes au
# pivot / forêt 0,10 — plate, la depth map fait coulisser 70 % de l'image
# d'un seul bloc, et l'œil lit « affiche qui glisse », pas « profondeur ».
base = np.interp(ys, [0.00, 0.44, 0.52, 0.58, 0.62, 0.75, 1.00],
                     [1.00, 1.00, 0.80, 0.50, 0.45, 0.26, 0.10]).astype(np.float32)

def sstep(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)

# Les nuages : dans la bande 0,24..0,58, la matière éclairée est un plan
# plus PROCHE que le ciel noir étoilé — c'est cette différence de vitesse
# entre nuages et ciel qui fait respirer la moitié haute. La lune, elle,
# reste collée au fond du ciel (disque protégé du masque nuages).
cloud = (sstep(0.022, 0.060, lum) * sstep(0.24, 0.30, ys)
         * (1 - sstep(0.52, 0.58, ys)))
moon = 1 - sstep(0.045, 0.075, np.sqrt((xs - 0.500) ** 2
                                       + ((ys - 0.272) * H / W) ** 2))
cloud *= (1 - moon)
depth = base * (1 - 0.28 * cloud)

# Les arbres : sous y=0.55, le quasi-noir est une silhouette PROCHE.
darkness = sstep(0.020, 0.062, lum)          # 1 = éclairé, 0 = silhouette
treezone = sstep(0.55, 0.62, ys)
pull = (1 - darkness) * treezone             # 1 sur un sapin du bas
depth = depth * (1 - 0.55 * pull)

# PLUS AUCUN masque de vitre ici : depuis le pivot médian, toute rampe de
# profondeur qui descend vers 0 TRAVERSE 0,45 — et de part et d'autre de
# cette ligne, la scène glisse en sens OPPOSÉS : c'était la gélatine du
# médaillon au drag. La depth map est donc du PUR PAYSAGE ; l'extinction
# près du cadre, de la plaque et du disque est ANALYTIQUE dans le shader
# (env, inWin, calm) : elle multiplie le vecteur entier vers zéro, sans
# jamais lui faire changer de signe.
depth = np.asarray(Image.fromarray((np.clip(depth, 0, 1) * 255)
                                   .astype(np.uint8))
                   .filter(ImageFilter.GaussianBlur(5)),
                   np.float32) / 255

out = Image.fromarray((np.clip(depth, 0, 1) * 255).astype(np.uint8))
out = out.resize((W // 2, H // 2), Image.LANCZOS)
out.save(OUT)
print(f"OK {OUT} {out.size}, depth min/max dans l'art :",
      float(depth[150:1250, 150:900].min()), float(depth[150:1250, 150:900].max()))
