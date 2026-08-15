#!/usr/bin/env python3
"""La preuve à SON échelle : le coin TL des deux vérités, à la taille de
ses screenshots (~1,7 px/pt), côte à côte. Le bijou doit se lire ICI.
Usage: echelle.py <capture.png> <sortie.png>"""
import sys
import numpy as np
from PIL import Image

cap = Image.open(sys.argv[1]).convert("RGB")
a = np.asarray(cap, dtype=np.float32).mean(axis=2) / 255
x0 = 60
band = a[1350:1600, x0+120:1026].mean(axis=1)
yT = 1350 + int(np.abs(np.diff(band)).argmax())

# MOI : zone coin TL généreuse (-10..120pt x, -10..70pt y) puis ÷1,76
moi = cap.crop((x0 - 30, yT - 30, x0 + 360, yT + 210))
moi = moi.resize((int(moi.width / 1.76), int(moi.height / 1.76)), Image.LANCZOS)

# ELLE : même zone depuis la référence (1,353 px/pt → même échelle finale)
ref = Image.open("/Users/kathryn/Desktop/woochoper-ios/tools/verre/reference-card.png").convert("RGB")
rz = ref.crop((0, 0, int(120 * 1.353), int(70 * 1.353)))
sc = 1.7 / 1.353
rz = rz.resize((int(rz.width * sc), int(rz.height * sc)), Image.LANCZOS)
fond = Image.new("RGB", (rz.width + 17, rz.height + 17), (2, 2, 2))
fond.paste(rz, (17, 17))

H = max(fond.height, moi.height)
p = Image.new("RGB", (fond.width + moi.width + 10, H), (15, 15, 20))
p.paste(fond, (0, 0)); p.paste(moi, (fond.width + 10, 0))
p.save(sys.argv[2])
print("échelle Kathryn ->", sys.argv[2])
