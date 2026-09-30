#!/usr/bin/env python3
"""La planche d'une légendaire en main (30-09) — captures du SIMULATEUR (le
vrai shader), faites par capturer.sh.

    planche.py <légendaire> <épique témoin> <dossier des captures>


    ligne 1  la Quatre Lunes neuve, trois inclinaisons
    ligne 2  même angle : Trois Lunes · Quatre Lunes d'aujourd'hui · neuve
    ligne 3  crops ×3 de la neuve (le feu, la créature, le ciel, le cadre)
    ligne 4  les MÊMES crops, la Quatre Lunes d'aujourd'hui
    ligne 5  la lampe du pouce (avec / sans doigt, même angle) et le
             filigrane du cadre (penché à gauche / à droite)

Les zones des crops viennent des masques cuits (le point le plus chaud, la
matière la plus dense), comme la maquette du 20-09 — rien à la main.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

ICI = os.path.dirname(os.path.abspath(__file__))
LEG, TEM, CAP = sys.argv[1], sys.argv[2], sys.argv[3]
KIT = os.path.join(ICI, "..", "matiere", LEG)
TITRES = {n: json.load(open(os.path.join(ICI, "..", "matiere", n, f"{n}-matiere.json")))
          for n in (LEG, TEM)}
TILTS = ["-0.5,0", "0,0", "0.5,0.2"]
LABELS = ["penchée à gauche (−0,5)", "posée (0)", "penchée à droite (+0,5 · +0,2)"]
# Le rectangle extérieur du cadre, en fractions du canvas (CarteLune.metal).
FX0, FX1, FY0, FY1 = 0.1133, 0.8849, 0.0559, 0.9392


def charger(nom):
    return np.asarray(Image.open(os.path.join(CAP, nom)).convert("RGB"))


def boite(img):
    """Le rectangle du cadre à l'écran (pixels non noirs de la capture)."""
    m = img.max(-1) > 22
    # La barre d'accueil et les bannières du simulateur ne sont pas la carte.
    m[:300] = False
    m[2350:] = False
    ys, xs = np.nonzero(m)
    return xs.min(), ys.min(), xs.max(), ys.max()


def vers_ecran(b, cx, cy):
    x0, y0, x1, y1 = b
    return (x0 + (cx / 1086 - FX0) / (FX1 - FX0) * (x1 - x0),
            y0 + (cy / 1448 - FY0) / (FY1 - FY0) * (y1 - y0))


def zones():
    atlas = np.asarray(Image.open(os.path.join(KIT, f"{LEG}-matiere.png"))).astype(np.float32) / 255
    rel, vie = atlas[:1448, :1086], atlas[:1448, 1086:]
    souffle = atlas[1448:, :543]
    # Le feu, ou la nacre au monde des Bois (pas de feu).
    src = vie[..., 0] if vie[..., 0].max() > 0.2 else np.asarray(
        Image.fromarray((souffle[..., 2] * 255).astype(np.uint8)).resize((1086, 1448))) / 255.0
    feu = ndi.gaussian_filter(src, 12)
    fy, fx = np.unravel_index(np.argmax(feu), feu.shape)
    # La créature : le centre de SON sujet (cuit dans le json du kit).
    meta = TITRES[LEG]
    mx, my = meta["centre"][0] * 1086, meta["centre"][1] * 1448
    return {"le feu / la nacre": (fx, fy), "la créature": (mx, my),
            "le ciel": (543, 250), "le cadre et les lunes": (250, 1300)}


def main():
    try:
        f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 26)
        f2 = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 20)
    except OSError:
        f = f2 = ImageFont.load_default()
    neuves = [charger(f"neuve_{t}.png") for t in TILTS]
    b = boite(neuves[1])
    pad = 30
    x0, y0, x1, y1 = b[0] - pad, b[1] - pad, b[2] + pad, b[3] + pad

    def vue(img, w=560):
        c = Image.fromarray(img[y0:y1, x0:x1])
        return c.resize((w, round(c.height * w / c.width)), Image.LANCZOS)

    ligne1 = [vue(i) for i in neuves]
    angle = TILTS[2]
    ligne2 = [vue(charger(f"trois_{angle}.png")), vue(charger(f"produit_{angle}.png")),
              vue(neuves[2])]
    lab2 = [f"Trois Lunes ({TEM}) — inchangée", "Quatre Lunes AUJOURD'HUI (produit)",
            "Quatre Lunes NEUVE (banc)"]

    # Les crops ×3 : 180 px d'écran autour de chaque zone, sur la vue penchée.
    bb = boite(neuves[2])
    crops_n, crops_p = [], []
    prod = charger(f"produit_{angle}.png")
    for nom, (cx, cy) in zones().items():
        sx, sy = vers_ecran(bb, cx, cy)
        sx, sy = int(sx), int(sy)
        h = 90
        for src, dest in ((neuves[2], crops_n), (prod, crops_p)):
            c = Image.fromarray(src[sy - h:sy + h, sx - h:sx + h])
            dest.append((nom, c.resize((540, 540), Image.BICUBIC)))

    # La lampe et le filigrane : crops ×3 au pouce (avec / sans) et au coin
    # du cadre (penché à gauche / à droite).
    crops_l = []
    lampe_img = charger("lampe_0,0.png") if os.path.exists(os.path.join(CAP, "lampe_0,0.png")) else None
    if lampe_img is not None:
        b0 = boite(neuves[1])
        c0 = TITRES[LEG]["centre"]
        lx, ly = (int(v) for v in vers_ecran(b0, c0[0] * 1086, c0[1] * 1448))
        for nom, src in (("la lampe du pouce", lampe_img), ("sans doigt, même angle", neuves[1])):
            c = Image.fromarray(src[ly - 90:ly + 90, lx - 90:lx + 90])
            crops_l.append((nom, c.resize((540, 540), Image.BICUBIC)))
        # La boîte de la carte POSÉE pour les deux : penchée, la lueur au
        # pied de la carte élargit la boîte détectée et décale le point.
        for nom, src, b_ in (("filigrane, penchée à gauche", neuves[0], b0),
                             ("filigrane, penchée à droite", neuves[2], b0)):
            fx, fy = (int(v) for v in vers_ecran(b_, 140, 420))
            c = Image.fromarray(src[fy - 90:fy + 90, fx - 90:fx + 90])
            crops_l.append((nom, c.resize((540, 540), Image.BICUBIC)))

    gut = 28
    largeur = max(3 * 560 + 4 * gut, 4 * 540 + 5 * gut)
    h1 = ligne1[0].height
    hauteur = 60 + h1 + 70 + h1 + 70 + 540 + 70 + 540 + 90 + (620 if crops_l else 0)
    pl = Image.new("RGB", (largeur, hauteur), (4, 4, 6))
    d = ImageDraw.Draw(pl)
    y = 16
    d.text((gut, y), f"{LEG} ({TITRES[LEG]['monde']}) — la Quatre Lunes NEUVE, trois "
           "inclinaisons (capture simulateur, vrai shader)", fill=(215, 220, 230), font=f)
    y += 44
    x = gut
    for v, lab in zip(ligne1, LABELS):
        pl.paste(v, (x, y)); d.text((x, y + h1 + 6), lab, fill=(160, 165, 175), font=f2)
        x += 560 + gut
    y += h1 + 50
    d.text((gut, y), "Même angle (+0,5 · +0,2)", fill=(215, 220, 230), font=f)
    y += 36
    x = gut
    for v, lab in zip(ligne2, lab2):
        pl.paste(v, (x, y)); d.text((x, y + h1 + 6), lab, fill=(160, 165, 175), font=f2)
        x += 560 + gut
    y += h1 + 50
    for titre, crops in (("Crops ×3 — NEUVE, penchée à droite", crops_n),
                         ("Les mêmes crops ×3 — AUJOURD'HUI (produit)", crops_p),
                         ("La lampe du pouce et le filigrane du cadre — crops ×3", crops_l)):
        if not crops:
            continue
        d.text((gut, y), titre, fill=(215, 220, 230), font=f)
        y += 36
        x = gut
        for nom, c in crops:
            pl.paste(c, (x, y)); d.text((x, y + 544), nom, fill=(160, 165, 175), font=f2)
            x += 540 + gut
        y += 540 + 40
    out = os.path.join(ICI, f"planche-{LEG}-en-main.jpg")
    pl.save(out, quality=88)
    print("OK", out, pl.size)


if __name__ == "__main__":
    main()
