# -*- coding: utf-8 -*-
"""CUIRE LES TEXTURES DE LA FLAMME — la loi de la maison : rien ne se calcule
à l'écran, tout est cuit par script et posé dans les assets.

Deux fichiers, et c'est tout :

  · `flamme-bruit`  512×1024, trois canaux dans un seul fichier —
      R = le CHAMP DE COMBUSTION (8 octaves : le front déchire à toutes
          les échelles) ;
      G = la TURBULENCE LENTE (4 octaves : les masses de flamme) ;
      B = la TURBULENCE FINE (9 octaves : le crépitement et les fibres).
  · `flamme-warp`   512×1024, les VECTEURS DE DÉFORMATION DE DOMAINE —
      R = wx, G = wy (4 octaves chacun : on regarde le bruit À TRAVERS
          eux, deux fois de suite — c'est ce calcul qui fait les volutes,
          les léchages et les enroulements) ;
      B = les POCHES : du bruit à 7 octaves, seuillé, pour les îlots de
          feu qui se détachent du front et montent seuls.
  · `flamme-rampe`  64×1, la RAMPE DE CORPS NOIR à douze paliers —
      blanc bleuté, blanc chaud, jaune paille, jaune d'or, ambre, orange,
      orange rouge, vermillon, rouge de braise, braise sombre, brun de
      cendre, noir.

Le shader lit ces deux textures et compare un seuil. Il ne génère rien.

    python3 tools/lecteur/flamme/cuire_flamme.py
"""
import os
import numpy as np
from PIL import Image

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
ASSETS = os.path.join(RACINE, "Nosfy/Assets.xcassets")
W, H = 512, 1024

def bruit(h, w, octaves, graine, persist=0.56):
    """Du bruit fractal : des octaves de grain lissé, sommées. Il BOUCLE en
    x et en y — le shader échantillonne en `repeat`, une couture se verrait."""
    r = np.random.default_rng(graine)
    out = np.zeros((h, w), np.float32); amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = 2 ** (o + 2)
        g = r.random((n, n)).astype(np.float32)
        g = np.concatenate([g, g[:1]], 0)
        g = np.concatenate([g, g[:, :1]], 1)          # on referme la boucle
        g = np.array(Image.fromarray((g * 255).astype(np.uint8))
                     .resize((w, h), Image.BICUBIC), np.float32) / 255.0
        out += g * amp; tot += amp; amp *= persist
    out /= tot
    return (out - out.min()) / (out.max() - out.min())

# LA RAMPE : douze paliers, position (en centièmes de la distance au front)
# et couleur. Le cœur reste BLANC — « la brillance vient de la blancheur ».
RAMPE = [(0.0000, (1.00, 1.00, 0.99)), (0.0035, (1.00, 0.99, 0.90)),
         (0.0070, (1.00, 0.95, 0.68)), (0.0110, (1.00, 0.86, 0.40)),
         (0.0160, (1.00, 0.74, 0.24)), (0.0220, (1.00, 0.58, 0.13)),
         (0.0290, (0.99, 0.42, 0.07)), (0.0370, (0.92, 0.26, 0.04)),
         (0.0460, (0.74, 0.14, 0.02)), (0.0570, (0.44, 0.06, 0.01)),
         (0.0700, (0.16, 0.03, 0.01)), (0.0870, (0.00, 0.00, 0.00))]
LARGEUR = RAMPE[-1][0]          # la flamme s'éteint à 0,087

def imageset(nom, img):
    d = os.path.join(ASSETS, nom + ".imageset")
    os.makedirs(d, exist_ok=True)
    img.save(os.path.join(d, nom + ".png"))
    with open(os.path.join(d, "Contents.json"), "w") as f:
        f.write('{\n  "images" : [\n    {\n      "filename" : "%s.png",\n'
                '      "idiom" : "universal"\n    }\n  ],\n'
                '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  },\n'
                '  "properties" : {\n    "preserves-vector-representation" : false,\n'
                '    "template-rendering-intent" : "original"\n  }\n}\n' % nom)
    print("  %-16s %s" % (nom, img.size))

print("cuisson…")
champ = bruit(H, W, 8, 3, 0.56)
lente = bruit(H, W, 4, 21, 0.62)
fine  = bruit(H, W, 9, 41, 0.50)
rgb = np.stack([champ, lente, fine], -1)
imageset("flamme-bruit", Image.fromarray((rgb * 255).astype(np.uint8), "RGB"))

wx     = bruit(H, W, 4, 51, 0.60)
wy     = bruit(H, W, 4, 52, 0.60)
poches = bruit(H, W, 7, 99, 0.52)
wrp = np.stack([wx, wy, poches], -1)
imageset("flamme-warp", Image.fromarray((wrp * 255).astype(np.uint8), "RGB"))

n = 64
ramp = np.zeros((1, n, 3), np.float32)
for i in range(n):
    d = i / (n - 1) * LARGEUR
    for (d0, c0), (d1, c1) in zip(RAMPE, RAMPE[1:]):
        if d0 <= d <= d1:
            t = 0.0 if d1 == d0 else (d - d0) / (d1 - d0)
            ramp[0, i] = np.array(c0) * (1 - t) + np.array(c1) * t
            break
imageset("flamme-rampe", Image.fromarray((ramp * 255).astype(np.uint8), "RGB"))
print("la flamme s'éteint à %.3f de distance au front" % LARGEUR)
