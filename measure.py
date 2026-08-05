#!/usr/bin/env python3
"""Mesure objective d'une planche d'icône noir-sur-noir.

Ce que la référence nous doit, en chiffres — pour qu'on cesse de discuter
d'impressions : le noir du fond, le noir du corps, la hauteur et la LARGEUR
du liseré de lumière, la décroissance du halo hors silhouette, et la chroma
(y a-t-il seulement de la couleur dans cette image ?).

    python3 measure.py ref/peche.png
"""
import sys
import numpy as np
from PIL import Image


def charger(path):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float64) / 255.0
    return a


def lin(c):
    """sRGB -> linéaire, la seule échelle où la lumière s'additionne."""
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def rapport(path):
    rgb = charger(path)
    h, w, _ = rgb.shape
    L = lin(rgb)
    lum = 0.2126 * L[..., 0] + 0.7152 * L[..., 1] + 0.0722 * L[..., 2]
    # Luminance perceptuelle (sRGB, 0-255) — pour parler la même langue que l'œil.
    lum8 = (0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]) * 255

    print(f"\n=== {path}  ({w}x{h}) ===")

    # --- Chroma : la lumière est-elle vraiment blanche ? -----------------
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    sat = np.where(mx > 0.02, (mx - mn) / np.maximum(mx, 1e-6), 0.0)
    vifs = mx > 0.25          # là où il y a réellement de la lumière
    print(f"[chroma] saturation moyenne sur les pixels lumineux : {sat[vifs].mean():.4f}")
    print(f"[chroma] saturation p99 sur les pixels lumineux     : {np.percentile(sat[vifs], 99):.4f}")
    for i, c in enumerate("RGB"):
        print(f"[chroma] {c} moyen sur les pixels lumineux : {rgb[..., i][vifs].mean():.4f}")

    # --- Les niveaux : fond, corps, lumière -------------------------------
    coin = np.concatenate([lum8[:60, :60].ravel(), lum8[:60, -60:].ravel(),
                           lum8[-60:, :60].ravel(), lum8[-60:, -60:].ravel()])
    print(f"[niveaux] fond (coins)      : moy {coin.mean():6.2f}  max {coin.max():6.2f}")
    for p in (50, 75, 90, 95, 99, 99.5, 99.9):
        print(f"[niveaux] percentile {p:5.1f}   : {np.percentile(lum8, p):6.2f}")
    print(f"[niveaux] max               : {lum8.max():6.2f}")
    print(f"[niveaux] part des pixels > 128 : {100 * (lum8 > 128).mean():.3f} %")
    print(f"[niveaux] part des pixels >  32 : {100 * (lum8 > 32).mean():.3f} %")
    print(f"[niveaux] part des pixels >   8 : {100 * (lum8 > 8).mean():.3f} %")

    # --- La silhouette : tout ce qui n'est pas le fond --------------------
    seuil = coin.mean() + 3.0
    masque = lum8 > seuil
    ys, xs = np.nonzero(masque)
    if len(xs):
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        print(f"[forme] boite : x {x0}-{x1} ({x1-x0+1} px, {100*(x1-x0+1)/w:.1f} % de la planche)")
        print(f"[forme]         y {y0}-{y1} ({y1-y0+1} px, {100*(y1-y0+1)/h:.1f} % de la planche)")
        print(f"[forme] couverture du masque : {100*masque.mean():.2f} %")
        cx, cy = xs.mean(), ys.mean()
        print(f"[forme] centre de masse : ({cx/w:.3f} ; {cy/h:.3f}) en fractions de planche")

    # --- Le liseré : hauteur et largeur des crêtes ------------------------
    # On balaie les lignes horizontales et on mesure chaque crête de lumière :
    # sa hauteur, et sa largeur à mi-hauteur. C'est ça, la finesse d'un rim.
    crete_h, crete_w = [], []
    for y in range(0, h, 3):
        ligne = lum8[y]
        i = 1
        while i < w - 1:
            if ligne[i] > 60 and ligne[i] >= ligne[i - 1] and ligne[i] > ligne[i + 1]:
                pic = ligne[i]
                mi = pic / 2
                g = i
                while g > 0 and ligne[g] > mi:
                    g -= 1
                d = i
                while d < w - 1 and ligne[d] > mi:
                    d += 1
                crete_h.append(pic)
                crete_w.append(d - g)
                i = d + 1
            else:
                i += 1
    if crete_h:
        crete_h = np.array(crete_h)
        crete_w = np.array(crete_w)
        print(f"[liseré] {len(crete_h)} crêtes détectées (seuil 60)")
        print(f"[liseré] hauteur : med {np.median(crete_h):6.1f}  p90 {np.percentile(crete_h,90):6.1f}  max {crete_h.max():6.1f}")
        print(f"[liseré] largeur à mi-hauteur : med {np.median(crete_w):5.1f} px"
              f"  p10 {np.percentile(crete_w,10):5.1f}  p90 {np.percentile(crete_w,90):5.1f}")
        print(f"[liseré] largeur médiane rapportée à la planche : {100*np.median(crete_w)/w:.3f} %")

    # --- Le halo : décroissance hors silhouette ---------------------------
    # Distance au masque, par dilatations successives — sans scipy.
    if len(xs):
        m = masque.copy()
        print("[halo] luminance moyenne par anneau hors silhouette :")
        prev = m
        for k, r in enumerate([4, 8, 16, 32, 64, 128]):
            dil = dilate(masque, r)
            anneau = dil & ~prev
            if anneau.any():
                print(f"[halo]   0-{r:3d} px : {lum8[anneau].mean():6.3f}"
                      f"   (max {lum8[anneau].max():6.2f})")
            prev = dil


def dilate(mask, r):
    """Dilatation carrée de rayon r par sommes cumulées — rapide et sans dépendance."""
    h, w = mask.shape
    ii = np.zeros((h + 1, w + 1), dtype=np.int64)
    ii[1:, 1:] = np.cumsum(np.cumsum(mask.astype(np.int64), axis=0), axis=1)
    ys = np.arange(h)[:, None]
    xs = np.arange(w)[None, :]
    y0 = np.clip(ys - r, 0, h)
    y1 = np.clip(ys + r + 1, 0, h)
    x0 = np.clip(xs - r, 0, w)
    x1 = np.clip(xs + r + 1, 0, w)
    s = ii[y1, x1] - ii[y0, x1] - ii[y1, x0] + ii[y0, x0]
    return s > 0


if __name__ == "__main__":
    for p in sys.argv[1:]:
        rapport(p)
