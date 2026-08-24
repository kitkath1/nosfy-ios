#!/usr/bin/env python3
"""LA SONDE DE LIGNE (4e salve, F0) — condamne les calques.

Une ligne de calque = un saut de rangee COHERENT sur la largeur : la
moyenne du saut est forte ET son ecart-type est faible (un gradient de
matiere a un saut incoherent ; une arete de fenetre saute PAREIL partout).
Score d'une frame = max sur les rangees de |mean_x(dy)| quand
std_x(dy) < max(6, 2*|mean|). Calibre sur les captures de Kathryn du
24-08 (positifs) contre les poses (negatifs) : le detecteur doit
CONDAMNER les captures avant d'avoir le droit d'absoudre quoi que ce soit.

Usage : sonde_ligne.py image1 [image2 ...]  -> imprime le score par image.
"""
import sys
import numpy as np
from PIL import Image

def score(chemin, zone=(0.16, 0.92)):
    """zone : sous la dalle ET son retour a l'atterrissage (16 %) et au-dessus du bord bas. La largeur se
    reduit au tiers central x2 (les 70 % du milieu) : les flancs portent
    les chassis (sim, bezel des captures d'ecran de Kathryn)."""
    im = Image.open(chemin).convert("L")
    im.thumbnail((240, 10_000))
    a = np.asarray(im).astype(float)
    h, w = a.shape
    a = a[int(zone[0]*h):int(zone[1]*h), int(0.15*w):int(0.85*w)]
    d = np.diff(a, axis=0)                     # saut par rangee, par colonne
    m = np.abs(d.mean(axis=1))                 # coherence : la moyenne...
    s = d.std(axis=1)                          # ...contre la dispersion
    # LA COHERENCE EST STRICTE (payee a la calibration) : l'arc du ventre
    # du galet noir rendait mean 23 / std 43 et passait avec "std < 2m" —
    # un VRAI calque rend std << mean (14/3,7 sur la capture de Kathryn).
    lignes = np.where(s < np.maximum(4.0, 0.9*m), m, 0.0)
    return float(lignes.max())

if __name__ == "__main__":
    for c in sys.argv[1:]:
        print(f"{score(c):7.2f}  {c}")
