#!/usr/bin/env python3
"""LA VIE VIOLENTE — le kit v3, première brique : les MASQUES de la vie (20-09 nuit).

Pour chaque référence publiée (`profondeur/publiees.json`), depuis son
illustration nue : trois masques dans un PNG RGB, `profondeur/<nom>/plans/<nom>-vie.png`
(taille de l'illustration) —
    R  le FEU      : les pixels chauds (r > 0,55, r − b > 0,30), dilatés vers
                     le haut (12 px) — là où les flammes naissent ;
    G  l'ÉMISSIF   : chauds ET saturés (la lave, la braise dans la matière) —
                     ce qui pulse ;
    B  le CIEL     : sombre et lisse (les nuages, la nuit) — là où le ciel vit.
Et, une fois par MONDE, un BRUIT CUIT tuilable (`profondeur/bruit-<monde>.png`,
512×512, R = bruit lent, G = bruit rapide) : deux octaves de bruit de valeur
périodique — pas de procédural à l'écran, la texture est cuite (la règle du
ciel de la home). Le shader `carteVie` lit les deux.

    python3 cuire_vie.py            (toutes les publiées)
    python3 cuire_vie.py <nom>      (une seule)
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ICI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(ICI, "..", ".."))


def bruit_tuilable(taille=512, graine=7):
    """Deux octaves de bruit de valeur PÉRIODIQUE (tuilable), lissées."""
    rng = np.random.default_rng(graine)
    out = np.zeros((taille, taille, 2), np.float32)
    for c, (cell, cell2) in enumerate(((16, 32), (48, 96))):
        acc = np.zeros((taille, taille), np.float32)
        for k, (n, amp) in enumerate(((cell, 1.0), (cell2, 0.5))):
            g = rng.random((n, n)).astype(np.float32)
            # interpolation bicubique périodique : on répète la grille 3×3 et on recadre
            big = np.tile(g, (3, 3))
            up = np.asarray(Image.fromarray((big * 255).astype(np.uint8)).resize((taille * 3, taille * 3), Image.BICUBIC)).astype(np.float32) / 255
            acc += amp * up[taille:2 * taille, taille:2 * taille]
        acc = (acc - acc.min()) / (acc.max() - acc.min() + 1e-6)
        out[..., c] = acc
    # L'ÉCLAIR (M2) : un tracé cuit dans le canal B — une marche aléatoire qui
    # descend, se ramifie deux fois, trait de 1,5 px, halo serré de 4 px.
    bolt = np.zeros((taille, taille), np.float32)
    def trace(x, y, dy_total, largeur, branches):
        pts = [(x, y)]
        while y < min(taille - 1, dy_total):
            x += rng.normal(0, 6.0) + (0.15 * (taille / 2 - x)) * 0.1
            y += rng.uniform(4, 12)
            pts.append((int(np.clip(x, 2, taille - 3)), int(np.clip(y, 0, taille - 1))))
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            cv2.line(bolt, (int(x0), int(y0)), (int(x1), int(y1)), float(largeur), 2)
        for _ in range(branches):
            i = rng.integers(len(pts) // 4, 3 * len(pts) // 4)
            bx, by = pts[i]
            trace(bx + rng.normal(0, 3), by, min(taille - 1, by + rng.uniform(80, 200)), largeur * 0.6, 0)
    trace(taille * 0.5 + rng.normal(0, 30), 0, taille * 0.78, 1.0, 2)
    halo = ndi.gaussian_filter(bolt, 2.5) * 0.6
    bolt = np.clip(np.maximum(bolt, halo), 0, 1)
    rgb = np.dstack([out[..., 0], out[..., 1], bolt])
    return Image.fromarray((rgb * 255).astype(np.uint8))


def masques(art, sujet=None):
    a = art.astype(np.float32) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    sat = a.max(-1) - a.min(-1)
    chaud = ((r > 0.55) & (r - b > 0.30)).astype(np.float32)
    # LA LUNE NE BRÛLE PAS (payé au banc : des flammes sur le croissant). Le
    # feu, ce sont les composantes chaudes qui TOUCHENT la créature (les bois,
    # la gueule) ou qui vivent dans le bas de l'image (lave, horizon) ; une
    # composante chaude du HAUT, hors créature, c'est la lune (ou une lueur
    # de ciel) : elle sort du feu, et sa position nourrit M2.
    H, W = chaud.shape
    lab, n = ndi.label(chaud > 0)
    lune = None
    if n:
        proche = cv2.dilate(sujet, np.ones((31, 31), np.uint8)) if sujet is not None else np.zeros_like(chaud)
        for k in range(1, n + 1):
            comp = lab == k
            ys, xs = np.nonzero(comp)
            if ys.mean() < 0.40 * H and not (proche[comp] > 0).any():
                if lune is None or comp.sum() > lune[2]:
                    lune = (float(xs.mean() / W), float(ys.mean() / H), int(comp.sum()), float(max(xs.max() - xs.min(), ys.max() - ys.min()) / 2 / W))
                chaud[comp] = 0
    # le feu naît des pixels chauds et monte : dilatation vers le haut, 12 px
    noyau = np.zeros((25, 7), np.uint8)
    noyau[12:, 2:5] = 1          # la partie BASSE du noyau = le pixel s'étend vers le haut
    feu = cv2.dilate((chaud * 255).astype(np.uint8), noyau)
    feu = ndi.gaussian_filter(feu.astype(np.float32) / 255, 3.0)
    feu = np.clip(feu * 1.4, 0, 1)
    emissif = ((r > 0.62) & (sat > 0.45) & (r - b > 0.35)).astype(np.float32)
    emissif = np.clip(ndi.gaussian_filter(emissif, 2.0) * 1.3, 0, 1)
    gx = ndi.sobel(ndi.gaussian_filter(lum, 1.2), axis=1)
    gy = ndi.sobel(ndi.gaussian_filter(lum, 1.2), axis=0)
    lisse = ndi.gaussian_filter(np.hypot(gx, gy), 3.0)
    ciel = ((lum < 0.55) & (lisse < 0.07)).astype(np.float32)
    ciel = ndi.gaussian_filter(ciel, 4.0)
    return feu, emissif, ciel, lune


def main():
    pub = json.load(open(os.path.join(ICI, "profondeur", "publiees.json")))
    voulu = sys.argv[1] if len(sys.argv) > 1 else None
    mondes = set()
    for c in pub:
        nom = c["reference"].split("/")[1]
        if voulu and nom != voulu:
            continue
        art = np.asarray(Image.open(os.path.join(REPO, c["fichier"])).convert("RGB"))
        ps = os.path.join(ICI, "profondeur", nom, f"{nom}-sujet.png")
        sujet = (np.asarray(Image.open(ps).convert("L").resize((art.shape[1], art.shape[0]), Image.NEAREST)) > 127).astype(np.uint8) if os.path.exists(ps) else None
        if sujet is not None and (sujet.mean() < 0.03 or sujet.mean() > 0.60):
            sujet = None
        feu, emi, ciel, lune = masques(art, sujet)
        vie = np.dstack([feu, emi, ciel])
        d = os.path.join(ICI, "profondeur", nom, "plans")
        os.makedirs(d, exist_ok=True)
        Image.fromarray((vie * 255).astype(np.uint8)).save(os.path.join(d, f"{nom}-vie.png"))
        json.dump({"lune": None if lune is None else {"x": round(lune[0], 4), "y": round(lune[1], 4), "r": round(max(lune[3], 0.02), 4)}},
                  open(os.path.join(d, f"{nom}-vie.json"), "w"))
        print("   lune :", None if lune is None else f"({lune[0]:.2f}, {lune[1]:.2f}) r {max(lune[3], 0.02):.3f}")
        mondes.add(c["monde"])
        print(f"OK {nom} : feu {feu.mean() * 100:.1f} % · émissif {emi.mean() * 100:.1f} % · ciel {ciel.mean() * 100:.1f} %")
    for i, m in enumerate(sorted(mondes)):
        p = os.path.join(ICI, "profondeur", f"bruit-{m}.png")
        bruit_tuilable(512, graine=11 + i).save(p)
        print("bruit + éclair cuits :", p)


if __name__ == "__main__":
    main()
