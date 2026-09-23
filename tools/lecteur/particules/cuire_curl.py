# -*- coding: utf-8 -*-
"""CUIRE LE CHAMP ROTATIONNEL des particules.

Un seul fichier : `particules-curl`, 128×256.
  R = u, G = v — le champ de vitesse, encodé autour de 0,5.
  B = une graine par position, pour désynchroniser les particules.

⚠️ POURQUOI UN ROTATIONNEL et pas du bruit : sa DIVERGENCE EST NULLE. Les
particules tournent sans jamais s'entasser ni se raréfier. C'est ce qui
fait les volutes ; un champ de bruit pris tel quel crée des puits et des
sources, et le nuage se troue.

On l'obtient en dérivant un potentiel bruité : (u, v) = (∂p/∂y, −∂p/∂x).

    python3 tools/lecteur/particules/cuire_curl.py
"""
import os
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
ASSETS = os.path.join(RACINE, "Nosfy/Assets.xcassets")
W, H = 128, 256

def potentiel(h, w, graine, echelle):
    r = np.random.default_rng(graine)
    p = r.random((max(2, h//echelle)+2, max(2, w//echelle)+2)).astype(np.float32)
    # on referme la boucle : le shader échantillonne en `repeat`
    p = np.concatenate([p, p[:1]], 0); p = np.concatenate([p, p[:, :1]], 1)
    p = np.array(Image.fromarray((p*255).astype(np.uint8))
                 .resize((w, h), Image.BICUBIC), np.float32)/255.0
    return gaussian_filter(p, 3.0, mode="wrap")

# deux échelles : les grandes volutes et les petits remous
p1 = potentiel(H, W, 11, 24)
p2 = potentiel(H, W, 12, 9)
p = p1 + 0.45*p2

gy, gx = np.gradient(p)
u, v = gy, -gx                       # LE ROTATIONNEL
n = max(np.abs(u).max(), np.abs(v).max()) + 1e-6
u = u/n*0.5 + 0.5
v = v/n*0.5 + 0.5

graine = np.random.default_rng(21).random((H, W)).astype(np.float32)

rgb = np.stack([u, v, graine], -1)
d = os.path.join(ASSETS, "particules-curl.imageset")
os.makedirs(d, exist_ok=True)
Image.fromarray((np.clip(rgb,0,1)*255).astype(np.uint8)).save(
    os.path.join(d, "particules-curl.png"))
with open(os.path.join(d, "Contents.json"), "w") as f:
    f.write('{\n  "images" : [\n    {\n      "filename" : "particules-curl.png",\n'
            '      "idiom" : "universal"\n    }\n  ],\n'
            '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n')
print("cuit : particules-curl %dx%d" % (W, H))
