#!/usr/bin/env python3
"""Tracé vectoriel EXACT de la silhouette d'une référence noir-sur-noir.

Le corps est noir sur fond noir : sa frontière n'existe que par le liseré de
lumière. On seuille très bas, on soude le liseré en une frontière continue,
on remplit l'intérieur, on prend le contour extérieur, et on le simplifie
jusqu'au nombre de sommets voulu — en surveillant l'IoU, parce qu'un sommet
de trop coûte moins cher qu'un angle perdu.

Le polygone sort en coordonnées du banc : origine au centre de la planche,
y vers le haut, demi-côté = 1. Le shader le rejoue tel quel.

    python3 trace.py ref/peche.png peche 200
"""
import json
import os
import sys
import cv2
import numpy as np
from PIL import Image


def masque(path, ferme=9, seuil=24.0, ronge=7):
    """Le masque du corps, calé sur la CRÊTE du liseré.

    Piège payé : au seuil du bruit (2/255) le halo s'étend sur 30 à 45 px et
    gonfle le masque d'autant — mesuré, les pixels lumineux se retrouvaient à
    d ≈ +30..+95 à l'intérieur. On seuille donc franchement au-dessus du halo
    (24/255), on soude les interruptions du liseré par une fermeture large,
    puis on ronge de la demi-largeur restante pour poser le bord sur la crête.
    """
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float64)
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    h, w = lum.shape
    brut = (lum > seuil).astype(np.uint8)

    # Fermeture juste assez large pour souder le liseré en frontière continue.
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * ferme + 1,) * 2)
    m = cv2.morphologyEx(brut, cv2.MORPH_CLOSE, k)

    # Remplissage : on inonde depuis le bord, ce qui reste est l'intérieur.
    ff = m.copy()
    bord = np.zeros((h + 2, w + 2), np.uint8)
    cv2.floodFill(ff, bord, (0, 0), 1)
    m = (m | (1 - ff)).astype(np.uint8)

    # On ne garde que l'amas principal : les poussières du halo dégagent.
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    if n > 1:
        principal = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        m = (lab == principal).astype(np.uint8)
    if ronge:
        m = cv2.erode(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE,
                                                   (2 * ronge + 1,) * 2))
    return m, lum


def simplifier(cnt, cible):
    """Cherche l'epsilon d'approxPolyDP qui donne ~`cible` sommets."""
    peri = cv2.arcLength(cnt, True)
    lo, hi, best = 1e-5, 0.05, cnt
    for _ in range(60):
        mid = 0.5 * (lo + hi)
        s = cv2.approxPolyDP(cnt, mid * peri, True)
        if len(s) > cible:
            lo = mid
        else:
            hi = mid
            best = s
        if abs(len(s) - cible) <= 1:
            best = s
            break
    return best


def tracer(path, nom, cible):
    m, lum = masque(path)
    h, w = m.shape
    cnts, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    cnt = max(cnts, key=cv2.contourArea)

    poly = simplifier(cnt, cible).reshape(-1, 2).astype(np.float64)

    fill = np.zeros((h, w), np.uint8)
    cv2.fillPoly(fill, [poly.astype(np.int32)], 1)
    inter = int((fill & m).sum())
    union = int((fill | m).sum())

    print(f"\n=== {nom} ===")
    print(f"[masque]   aire {100*m.mean():.2f} %   perimetre {len(cnt)} px")
    print(f"[polygone] {len(poly)} sommets")
    print(f"[fidelite] IoU polygone / masque : {100*inter/union:.3f} %")

    q = poly.copy()
    q[:, 0] = 2 * q[:, 0] / w - 1
    q[:, 1] = -(2 * q[:, 1] / h - 1)
    json.dump({"nom": nom, "n": len(q), "pts": q.round(5).tolist()},
              open(f"trace/{nom}.json", "w"))
    Image.fromarray(m * 255).save(f"trace/{nom}-masque.png")
    Image.fromarray(fill * 255).save(f"trace/{nom}-poly.png")
    print(f"[ecrit] trace/{nom}.json")
    return q


if __name__ == "__main__":
    os.makedirs("trace", exist_ok=True)
    tracer(sys.argv[1], sys.argv[2], int(sys.argv[3]))
