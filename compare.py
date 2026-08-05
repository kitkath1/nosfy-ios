#!/usr/bin/env python3
"""Confrontation d'un rendu à sa référence — chiffres, puis planche côte à côte.

    python3 compare.py peche shots/peche-v2.png
"""
import sys
import numpy as np
import cv2
from PIL import Image


def lum(path, n=1020):
    im = Image.open(path).convert("RGB").resize((n, n), Image.LANCZOS)
    a = np.asarray(im).astype(np.float64)
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def crete_largeur(L):
    """Largeur médiane à mi-hauteur des crêtes de lumière — la finesse du fil."""
    w = L.shape[1]
    larg = []
    for y in range(0, L.shape[0], 3):
        li = L[y]
        i = 1
        while i < w - 1:
            if li[i] > 60 and li[i] >= li[i - 1] and li[i] > li[i + 1]:
                mi = li[i] / 2
                g = i
                while g > 0 and li[g] > mi:
                    g -= 1
                dr = i
                while dr < w - 1 and li[dr] > mi:
                    dr += 1
                larg.append(dr - g)
                i = dr + 1
            else:
                i += 1
    return float(np.median(larg)) if larg else float("nan")


def ssim(a, b):
    """SSIM global, fenêtre gaussienne 11 — la mesure de structure."""
    a, b = a / 255.0, b / 255.0
    C1, C2 = 0.01 ** 2, 0.03 ** 2
    k = (11, 11)
    mu_a = cv2.GaussianBlur(a, k, 1.5)
    mu_b = cv2.GaussianBlur(b, k, 1.5)
    saa = cv2.GaussianBlur(a * a, k, 1.5) - mu_a ** 2
    sbb = cv2.GaussianBlur(b * b, k, 1.5) - mu_b ** 2
    sab = cv2.GaussianBlur(a * b, k, 1.5) - mu_a * mu_b
    s = ((2 * mu_a * mu_b + C1) * (2 * sab + C2)) / \
        ((mu_a ** 2 + mu_b ** 2 + C1) * (saa + sbb + C2))
    return float(s.mean())


def confronter(nom, rendu):
    R = lum(f"ref/{nom}.png")
    A = lum(rendu)
    print(f"\n=== {nom} : {rendu} ===")
    print(f"{'':22s} {'rendu':>9s} {'reference':>10s}")
    for p in (50, 90, 95, 99, 99.9):
        print(f"percentile {p:5.1f}      {np.percentile(A,p):9.2f} {np.percentile(R,p):10.2f}")
    print(f"max                  {A.max():9.2f} {R.max():10.2f}")
    for s in (8, 32, 128):
        print(f"part > {s:3d}            {100*(A>s).mean():8.3f}% {100*(R>s).mean():9.3f}%")
    print(f"largeur de crete     {crete_largeur(A):9.2f} {crete_largeur(R):10.2f}")

    mA, mR = A > 12, R > 12
    iou = 100 * (mA & mR).sum() / max((mA | mR).sum(), 1)
    print(f"IoU des zones lumineuses : {iou:.2f} %")
    print(f"SSIM : {ssim(A, R):.4f}")
    print(f"erreur absolue moyenne : {np.abs(A-R).mean():.2f}/255")

    # Planche : référence | rendu | différence
    diff = np.clip(np.abs(A - R) * 3, 0, 255)
    tri = np.hstack([R, A, diff]).astype(np.uint8)
    Image.fromarray(tri).resize((1200, 400)).save(f"shots/{nom}-confront.png")
    print(f"planche -> shots/{nom}-confront.png  (reference | rendu | ecart x3)")


if __name__ == "__main__":
    confronter(sys.argv[1], sys.argv[2])
