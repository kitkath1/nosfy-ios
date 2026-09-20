#!/usr/bin/env python3
"""LA VRAIE PROFONDEUR D'UNE CARTE — le kit, première brique (20-09).

Jusqu'ici toutes les cartes partageaient une rampe (LuneForge.depthV0 : haut =
loin, bas = près) : sur un cerf, sa tête était traitée comme du ciel. Ici,
une estimation monoculaire (Depth Anything v2, petit modèle, ONNX, sur le
Mac) donne à chaque pixel sa distance, puis on la range dans la convention
du shader : 0 = plan de l'écran (le cadre), 1 = fond du ciel, 0,45 = le
pivot (ce qui reste collé au cadre).

Entrée : l'illustration nue (1024×1536, ou n'importe quoi de 2:3).
Sorties, à côté du script (dossier `profondeur/<nom>/`) :
    <nom>-depth.png        la profondeur au format LuneForge (demi-résolution
                           du canvas 1086×1448 → 543×724, gris, fenêtre posée,
                           0,45 sous le cadre) — CE QUE LE SHADER LIT
    <nom>-depth-nue.png    la profondeur de l'illustration seule (1024×1536)
    <nom>-sujet.png        le détourage de la créature (rembg, alpha)
    <nom>-planche.png      illustration · profondeur · sujet côte à côte

    python3 cuire_profondeur.py <illustration.png> <nom>
"""
import os
import sys

import numpy as np
from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
CW, CH = 1086, 1448
FEN = (0.118, 0.083, 0.763, 0.808)
WX, WY = int(FEN[0] * CW), int(FEN[1] * CH)
WW, WH = int(FEN[2] * CW), int(FEN[3] * CH)


def profondeur_relative(img):
    """Depth Anything v2 (small) en ONNX : plus c'est grand, plus c'est PRÈS."""
    import onnxruntime as ort
    from huggingface_hub import hf_hub_download
    chemin = hf_hub_download("onnx-community/depth-anything-v2-small", "onnx/model.onnx")
    sess = ort.InferenceSession(chemin, providers=["CPUExecutionProvider"])
    entree = sess.get_inputs()[0]
    # 518 est la taille native ; on garde le ratio 2:3 en multiples de 14
    w, h = 518, 770
    x = np.asarray(img.convert("RGB").resize((w, h), Image.BICUBIC)).astype(np.float32) / 255
    x = (x - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
    x = x.transpose(2, 0, 1)[None].astype(np.float32)
    y = sess.run(None, {entree.name: x})[0]
    d = y[0] if y.ndim == 3 else y[0, 0]
    d = (d - d.min()) / (d.max() - d.min() + 1e-6)
    return np.asarray(Image.fromarray((d * 65535).astype(np.uint16)).resize(img.size, Image.BICUBIC)).astype(np.float32) / 65535


def detourer(img):
    from rembg import remove
    out = remove(img.convert("RGBA"))
    return np.asarray(out)[..., 3].astype(np.float32) / 255


def main():
    src, nom = sys.argv[1], sys.argv[2]
    dossier = os.path.join(ICI, "profondeur", nom)
    os.makedirs(dossier, exist_ok=True)
    img = Image.open(src).convert("RGB")
    pres = profondeur_relative(img)                     # 1 = près, 0 = loin
    loin = 1.0 - pres                                   # la convention du shader : 1 = fond du ciel
    # le sujet détouré : on le TIENT devant (jamais de trou de profondeur au milieu du cerf)
    sujet = detourer(img)
    loin = np.where(sujet > 0.5, np.minimum(loin, np.percentile(loin[sujet > 0.5], 35)), loin)
    # étalement : le pivot 0,45 tombe sur la médiane de la scène — ce qui est
    # plus loin recule, ce qui est plus près avance, à courses comparables
    med = np.median(loin)
    haut = np.clip((loin - med) / (loin.max() - med + 1e-6), 0, 1)
    bas = np.clip((med - loin) / (med - loin.min() + 1e-6), 0, 1)
    depth_nue = 0.45 + 0.55 * haut - 0.35 * bas
    depth_nue = np.clip(depth_nue, 0.10, 1.0)
    Image.fromarray((depth_nue * 255).astype(np.uint8)).save(os.path.join(dossier, f"{nom}-depth-nue.png"))
    Image.fromarray((sujet * 255).astype(np.uint8)).save(os.path.join(dossier, f"{nom}-sujet.png"))
    # au format LuneForge : demi-canvas, 0,45 sous le cadre, l'illustration en aspect-fill dans la fenêtre
    canvas = np.full((CH // 2, CW // 2), 0.45, np.float32)
    s = max(WW / img.width, WH / img.height)
    dw, dh = round(img.width * s), round(img.height * s)
    d_img = Image.fromarray((depth_nue * 255).astype(np.uint8)).resize((dw // 2, dh // 2), Image.BILINEAR)
    d_arr = np.asarray(d_img).astype(np.float32) / 255
    ox, oy = (WX + (WW - dw) // 2) // 2, (WY + (WH - dh) // 2) // 2
    fx0, fy0, fx1, fy1 = WX // 2, WY // 2, (WX + WW) // 2, (WY + WH) // 2
    for y in range(fy0, fy1):
        sy = y - oy
        if 0 <= sy < d_arr.shape[0]:
            xs = np.arange(fx0, fx1)
            sx = xs - ox
            ok = (sx >= 0) & (sx < d_arr.shape[1])
            canvas[y, xs[ok]] = d_arr[sy, sx[ok]]
    Image.fromarray((canvas * 255).astype(np.uint8)).save(os.path.join(dossier, f"{nom}-depth.png"))
    # la planche
    W = 400
    vues = [img.resize((W, int(W * img.height / img.width))),
            Image.fromarray((depth_nue * 255).astype(np.uint8)).convert("RGB").resize((W, int(W * img.height / img.width))),
            Image.fromarray((sujet * 255).astype(np.uint8)).convert("RGB").resize((W, int(W * img.height / img.width)))]
    pl = Image.new("RGB", (3 * W + 40, vues[0].height + 20), (4, 4, 6))
    for i, v in enumerate(vues):
        pl.paste(v, (10 + i * (W + 10), 10))
    pl.save(os.path.join(dossier, f"{nom}-planche.png"))
    print("OK", nom, "— depth", canvas.shape[::-1], "· sujet", round(float((sujet > 0.5).mean()) * 100, 1), "% de l'image")


if __name__ == "__main__":
    main()
