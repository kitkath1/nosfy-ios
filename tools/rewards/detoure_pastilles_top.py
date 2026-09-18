#!/usr/bin/env python3
# LE DÉTOURAGE DES PASTILLES « TOP SESSION » (TS1) — la recette de
# PLAN-WELCOME-V2-DETOURAGE.md §2.1, rejouée pour la basket et
# l'haltère. LA LOI : un sticker sombre sur fond sombre ne se détoure
# JAMAIS par la luminance — il se détoure par sa SILHOUETTE (masque
# binaire, fondu de 1,5 px sur le SEUL contour), et la matière
# intérieure n'est jamais touchée. Sonde de sortie : alpha moyen dans
# le sujet > 0,98, sinon on recommence.
import numpy as np
from PIL import Image
from scipy import ndimage
import glob, os, json

SORTIES = [
    ("~/Desktop/paillete_basket.png", "sticker-pastille-basket"),
    ("~/Desktop/pailette_halt*.png", "sticker-pastille-haltere"),
]
ASSETS = os.path.join(os.path.dirname(__file__),
                      "..", "..", "Nosfy", "Assets.xcassets")

for pat, nom in SORTIES:
    src = glob.glob(os.path.expanduser(pat))[0]
    im = Image.open(src).convert("RGB")
    rgb = np.array(im)
    lum = rgb.max(axis=2).astype(float)

    # 1. LE MASQUE PAR LUMINANCE A MORDU LE FLANC GAUCHE (mesuré sur la
    #    première passe : la matière du bord y descend sous 8/255 —
    #    l'ÉCLAIRAGE n'est pas la FORME). Or la silhouette est CONNUE :
    #    un squircle. On la trace donc ANALYTIQUEMENT — la bbox au seuil
    #    très bas (l'existence), le rayon à 0,22 · côté (celui du rendu,
    #    `PastilleLuneReward.cornerRadius = cote * 0.22`).
    m = lum > 3
    m = ndimage.binary_fill_holes(m)
    lab, n = ndimage.label(m)
    if n > 1:
        tailles = ndimage.sum(m, lab, range(1, n + 1))
        m = lab == (1 + int(np.argmax(tailles)))
    ys0, xs0 = np.where(m)
    by0, by1, bx0, bx1 = ys0.min(), ys0.max(), xs0.min(), xs0.max()
    H0, W0 = by1 - by0 + 1, bx1 - bx0 + 1
    r = 0.22 * min(W0, H0)
    # 2. Le rectangle arrondi, en champ de distance signé : dedans si
    #    la distance au rectangle rétréci de r est < r.
    yy, xx = np.mgrid[0:rgb.shape[0], 0:rgb.shape[1]].astype(float)
    dx = np.maximum(np.maximum(bx0 + r - xx, xx - (bx1 - r)), 0)
    dy = np.maximum(np.maximum(by0 + r - yy, yy - (by1 - r)), 0)
    m = np.sqrt(dx * dx + dy * dy) <= r
    # 3. Alpha = 1 DEDANS, fondu de 1,5 px sur le SEUL contour
    #    (distance transform — jamais un flou global qui remange la
    #    matière).
    dist = ndimage.distance_transform_edt(m)
    alpha = np.clip(dist / 1.5, 0, 1)
    # 4. LA SONDE : l'alpha moyen dans le sujet.
    dedans = dist > 3
    moyen = alpha[dedans].mean()
    assert moyen > 0.98, f"{nom} : alpha moyen {moyen:.3f} — recette à revoir"

    a8 = (alpha * 255).astype(np.uint8)
    ys, xs = np.where(a8 > 0)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    # marge de 2 px, comme la lune
    y0 = max(0, y0 - 2); x0 = max(0, x0 - 2)
    y1 = min(rgb.shape[0], y1 + 2); x1 = min(rgb.shape[1], x1 + 2)
    out = np.dstack([rgb, a8])[y0:y1, x0:x1]

    d = os.path.join(ASSETS, f"{nom}.imageset")
    os.makedirs(d, exist_ok=True)
    Image.fromarray(out, "RGBA").save(os.path.join(d, f"{nom}.png"))
    json.dump({"images": [
        {"filename": f"{nom}.png", "idiom": "universal", "scale": "1x"},
        {"idiom": "universal", "scale": "2x"},
        {"idiom": "universal", "scale": "3x"}],
        "info": {"author": "xcode", "version": 1}},
        open(os.path.join(d, "Contents.json"), "w"), indent=2)
    print(f"{nom}: {out.shape[1]}x{out.shape[0]}  alpha_sujet={moyen:.3f}")
