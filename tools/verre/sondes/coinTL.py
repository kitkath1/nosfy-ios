#!/usr/bin/env python3
"""Le coin TL au microscope : RÉF | MOI, même zone, même échelle.
Usage: coinTL.py <capture.png> <sortie.png>"""
import sys
import numpy as np
from PIL import Image

cap = Image.open(sys.argv[1]).convert("RGB")
a = np.asarray(cap, dtype=np.float32).mean(axis=2) / 255
x0, x1 = 60, 1146
band = a[1350:1600, x0+120:x1-120].mean(axis=1)
yT = 1350 + int(np.abs(np.diff(band)).argmax())

# MOI : zone du coin TL — de -12pt à +75pt en x, -12pt à +80pt en y (3px/pt)
moi = cap.crop((x0 - 36, yT - 36, x0 + 225, yT + 240))

# RÉF : même zone. reference-card.png = la carte seule (1,38 px/pt), pas
# d'air autour — on la pose sur fond noir avec la même marge.
ref = Image.open("/Users/kathryn/Desktop/woochoper-ios/tools/verre/reference-card.png").convert("RGB")
# échelle réf : 490px/362pt = 1.353 px/pt ; zone 75×80pt → 101×108px
rz = ref.crop((0, 0, int(75 * 490 / 362), int(80 * 490 / 362)))
fond = Image.new("RGB", (rz.width + 16, rz.height + 16), (2, 2, 2))
fond.paste(rz, (16, 16))

H = 620
def rs(img):
    return img.resize((int(img.width * H / img.height), H), Image.LANCZOS)
t1, t2 = rs(fond), rs(moi)
p = Image.new("RGB", (t1.width + t2.width + 10, H), (18, 18, 24))
p.paste(t1, (0, 0)); p.paste(t2, (t1.width + 10, 0))
p.save(sys.argv[2])
print("planche coin ->", sys.argv[2])
