#!/usr/bin/env python3
"""Planche de comparaison : ma capture vs la référence, zone par zone.
Usage: planche.py <capture.png> <out-prefix>
La carte fermée vit à x=20pt, y≈expandedHeader+4+safeTop, w=écran-40.
On la détecte finement par la ligne la plus brillante (le fil droit)."""
import sys
from PIL import Image

cap = Image.open(sys.argv[1]).convert("RGB")
out = sys.argv[2]
W, H = cap.size          # 1179 x 2556 @3x
S = 3                    # px/pt

# La carte fermée : x = 20pt = 60px ; y = (12+225+8+118+4)pt + safe top (59pt)
# = 367+59 = 426pt = 1278px. Hauteur ~ carteFermeeH (~190pt = 570px).
# On scanne autour pour trouver le bord haut réel (le trait).
x0, x1 = 60, W - 60
import numpy as np
a = np.asarray(cap, dtype=np.float32)
band = a[1150:1500, x0+30:x1-30].mean(axis=(1, 2))
y_top = 1150 + int(band.argmax())          # le fil du haut = ligne la plus claire
# le bord bas : scan sous y_top+400
band2 = a[y_top+380:y_top+750, x0+30:x1-30].mean(axis=(1, 2))
y_bot = y_top + 380 + int(band2.argmax())
print("carte detectee: y_top=%d y_bot=%d (h=%dpt)" % (y_top, y_bot, (y_bot-y_top)/3))

padv = 100
card = cap.crop((max(x0-padv,0), max(y_top-padv,0), min(x1+padv,W), min(y_bot+padv,H)))
card.save(out + "-carte.png")

cw, ch = card.size
def crop4(img, name, box, scale=3):
    c = img.crop(box)
    c = c.resize((c.width*scale//2, c.height*scale//2), Image.LANCZOS)
    c.save(name)

crop4(card, out + "-hg.png", (0, 0, 320, 300))
crop4(card, out + "-hd.png", (cw-400, 0, cw, 320))
crop4(card, out + "-bg.png", (0, ch-320, 420, ch))
crop4(card, out + "-bd.png", (cw-440, ch-320, cw, ch))
print("crops ok:", out)
