#!/usr/bin/env python3
"""LE PETIT BOUT juste avant le coin gauche : la barre de la tranche
haute (x 2-30 %). RÉF | MOI à l'échelle de Kathryn, puis à 3×.
Usage: bout.py <capture.png> <sortie.png>"""
import sys
import numpy as np
from PIL import Image

cap = Image.open(sys.argv[1]).convert("RGB")
a = np.asarray(cap, dtype=np.float32).mean(axis=2) / 255
x0 = 60
band = a[1350:1600, x0+120:1026].mean(axis=1)
yT = 1350 + int(np.abs(np.diff(band)).argmax())

# la zone : x 0..110pt, y -8..+30pt autour du fil haut
moi = cap.crop((x0, yT - 24, x0 + 330, yT + 90))
ref = Image.open("/Users/kathryn/Desktop/woochoper-ios/tools/verre/reference-card.png").convert("RGB")
rz = ref.crop((0, 0, int(110 * 1.353), int(38 * 1.353)))

# échelle Kathryn (~1,7 px/pt) et microscope (3 px/pt)
def at(img, src_ppt, dst_ppt):
    f = dst_ppt / src_ppt
    return img.resize((int(img.width * f), int(img.height * f)), Image.LANCZOS)

rows = []
for ppt in (1.7, 3.0):
    r_ = at(rz, 1.353, ppt); m_ = at(moi, 3.0, ppt)
    h = max(r_.height, m_.height)
    row = Image.new("RGB", (r_.width + m_.width + 12, h + 8), (15, 15, 20))
    row.paste(r_, (0, 4)); row.paste(m_, (r_.width + 12, 4))
    rows.append(row)
W = max(r.width for r in rows)
p = Image.new("RGB", (W, sum(r.height for r in rows) + 12), (15, 15, 20))
y = 0
for r in rows:
    p.paste(r, (0, y)); y += r.height + 12
p.save(sys.argv[2])
print("le bout ->", sys.argv[2])
