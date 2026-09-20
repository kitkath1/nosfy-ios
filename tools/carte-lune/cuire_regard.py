#!/usr/bin/env python3
"""M3 — LA TÊTE ET LES YEUX de la créature (kit v3, 20-09 nuit). Heuristique,
puis VALIDÉE À L'ŒIL sur la planche : c'est le seul geste humain du kit.

Depuis le détourage (`<nom>-sujet.png`) et l'illustration :
    tête  = le tiers haut de la boîte du sujet, resserré sur la matière ;
    yeux  = dans la tête, les deux taches les plus BRILLANTES ou les plus
            CHAUDES (les yeux de braise du dragon, l'œil clair du corbeau),
            petites (< 0,3 % de l'image), les plus symétriques par rapport au
            centre de la tête.
Sorties : `plans/<nom>-regard.json` {tete: [x0,y0,x1,y1], yeux: [[x,y,r]…]}
(fractions de l'art) — corrigeable à la main ; et `planche-regard.png`
(sept cartes, la tête en cadre, les yeux en cercles).
"""
import json, os, sys
import cv2, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ICI = os.path.dirname(os.path.abspath(__file__)); REPO = os.path.abspath(os.path.join(ICI, "..", ".."))

def regard(art, sujet):
    H, W, _ = art.shape
    a = art.astype(np.float32) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    ys, xs = np.nonzero(sujet > 0)
    if len(ys) == 0:
        return None
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    ht = y0 + int((y1 - y0) * 0.34)
    bande = sujet[y0:ht]
    bys, bxs = np.nonzero(bande > 0)
    if len(bxs) == 0:
        return None
    tx0, tx1 = x0 + 0, x1 + 0
    tx0, tx1 = int(bxs.min()), int(bxs.max())
    tete = (tx0 / W, y0 / H, tx1 / W, ht / H)
    # les candidats yeux : brillants OU chauds, petits, dans la tête
    zone = np.zeros_like(sujet, np.uint8); zone[y0:ht, tx0:tx1 + 1] = sujet[y0:ht, tx0:tx1 + 1]
    brillant = ((lum > 0.72) | ((r > 0.6) & (r - b > 0.3))) & (zone > 0)
    lab, n = ndi.label(brillant)
    cands = []
    for k in range(1, n + 1):
        comp = lab == k
        s = comp.sum()
        if s < 6 or s > 0.003 * H * W:
            continue
        cy, cx = ndi.center_of_mass(comp)
        cands.append((cx, cy, np.sqrt(s / np.pi), float(lum[comp].mean() + r[comp].mean())))
    yeux = []
    if len(cands) >= 2:
        cxm = (tx0 + tx1) / 2
        best, bs = None, 1e9
        for i in range(len(cands)):
            for j in range(i + 1, len(cands)):
                (ax, ay, ar, _), (bx, by, br, _) = cands[i], cands[j]
                sym = abs((ax - cxm) + (bx - cxm)) / (tx1 - tx0 + 1) + abs(ay - by) / (ht - y0 + 1) * 2
                if abs(ax - bx) < 0.02 * W:
                    continue
                if sym < bs:
                    bs, best = sym, (cands[i], cands[j])
        if best and bs < 0.6:
            yeux = [[x / W, y / H, max(rr, 3) / W] for x, y, rr, _ in best]
    elif len(cands) == 1:
        x, y, rr, _ = cands[0]; yeux = [[x / W, y / H, max(rr, 3) / W]]
    return {"tete": [round(v, 4) for v in tete], "yeux": [[round(v, 4) for v in e] for e in yeux]}

pub = json.load(open(os.path.join(ICI, "profondeur", "publiees.json")))
vues = []
for c in pub:
    nom = c["reference"].split("/")[1]
    ps = os.path.join(ICI, "profondeur", nom, f"{nom}-sujet.png")
    if not os.path.exists(ps): continue
    art = np.asarray(Image.open(os.path.join(REPO, c["fichier"])).convert("RGB"))
    sujet = (np.asarray(Image.open(ps).convert("L").resize((art.shape[1], art.shape[0]), Image.NEAREST)) > 127).astype(np.uint8)
    if sujet.mean() < 0.03 or sujet.mean() > 0.60: continue
    rg = regard(art, sujet)
    json.dump(rg, open(os.path.join(ICI, "profondeur", nom, "plans", f"{nom}-regard.json"), "w"))
    im = Image.fromarray(art).copy(); d = ImageDraw.Draw(im); W, H = im.size
    if rg:
        x0, y0, x1, y1 = rg["tete"]; d.rectangle([x0 * W, y0 * H, x1 * W, y1 * H], outline=(0, 255, 255), width=4)
        for x, y, r in rg["yeux"]: d.ellipse([x * W - r * W * 2, y * H - r * W * 2, x * W + r * W * 2, y * H + r * W * 2], outline=(255, 0, 255), width=4)
    vues.append((nom, im.resize((300, 450))))
    print("OK", nom, rg)
pl = Image.new("RGB", (len(vues) * 310 + 10, 470), (4, 4, 6)); x = 10
for nom, v in vues: pl.paste(v, (x, 10)); x += 310
pl.save(os.path.join(ICI, "profondeur", "planche-regard.png")); print("planche-regard.png", len(vues))
