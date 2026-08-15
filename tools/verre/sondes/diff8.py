#!/usr/bin/env python3
"""Le triptyque de preuve : REFERENCE | LIVE | DIFF ×8 (et ×4).
Usage: diff8.py <capture.png> <sortie.png>"""
import sys
import numpy as np
from PIL import Image

cap = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float32)
a = cap.mean(axis=2) / 255
x0, x1 = 60, 1146
band = a[1350:1600, x0+120:x1-120].mean(axis=1)
yT = 1350 + int(np.abs(np.diff(band)).argmax())
band2 = a[yT+330:yT+420, x0+120:x1-120].mean(axis=1)
yB = yT + 330 + int(np.abs(np.diff(band2)).argmax())

live = Image.fromarray(cap[yT:yB, x0:x1].astype(np.uint8))
ref = Image.open("/Users/kathryn/Desktop/woochoper-ios/tools/verre/reference-card.png").convert("RGB")
ref = ref.resize(live.size, Image.LANCZOS)

L = np.asarray(live, dtype=np.float32)
R = np.asarray(ref, dtype=np.float32)
d = np.abs(L - R)
d8 = np.clip(d * 8, 0, 255).astype(np.uint8)
d4 = np.clip(d * 4, 0, 255).astype(np.uint8)

W = 1080
def rs(img):
    return img.resize((W, int(img.height * W / img.width)), Image.LANCZOS)
tiles = [rs(ref), rs(live), rs(Image.fromarray(d4)), rs(Image.fromarray(d8))]
h = tiles[0].height
p = Image.new("RGB", (W, h*4 + 30), (12, 12, 16))
for i, t in enumerate(tiles):
    p.paste(t, (0, i * (h + 10)))
p.save(sys.argv[2])
lum = d.mean() / 255
print(f"diff moyenne = {lum:.4f} (0 = identique) ; planche -> {sys.argv[2]}")
