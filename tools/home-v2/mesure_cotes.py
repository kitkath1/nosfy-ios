#!/usr/bin/env python3
"""Les COTES VERTICALES de la home — où chaque bloc commence et finit, en points.

    python3 tools/home-v2/mesure_cotes.py <capture.png>
    python3 tools/home-v2/mesure_cotes.py <capture.png> --bande 24 340
    python3 tools/home-v2/mesure_cotes.py <capture.png> --seuil 90 --min 3

Pourquoi cet outil existe : la colonne de la home est posée en coordonnées
ABSOLUES (0,375 h et 0,620 h) et les cotes qui traînent dans les commentaires
(« bas à 291 », « slider 768..830, écran 840 ») datent d'avant le passage en
plein écran physique de `PageCard`. Une cote se LIT sur le rendu ; elle ne se
déduit pas d'un commentaire — le dépôt s'est déjà trompé de 38 pt sur ce même
calcul.

⚠️ On mesure sur les PIXELS CLAIRS d'une bande, jamais en moyenne de ligne :
sur du noir, une moyenne tire vers le beige et invente de l'encre partout
(règle de la maison). Ici : une ligne « porte de l'encre » si au moins `--min`
pixels de la bande dépassent `--seuil`.
"""
import sys
import numpy as np
from PIL import Image


def lum(a):
    # Luma perceptuel sur les valeurs sRGB telles qu'affichées.
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def bandes(porte, min_haut=2):
    """Les runs contigus de lignes qui portent de l'encre (en INDEX de ligne)."""
    out, debut = [], None
    for y, on in enumerate(porte):
        if on and debut is None:
            debut = y
        elif not on and debut is not None:
            if y - debut >= min_haut:
                out.append((debut, y - 1))
            debut = None
    if debut is not None and len(porte) - debut >= min_haut:
        out.append((debut, len(porte) - 1))
    return out


def main(argv):
    path = argv[0]
    x0pt, x1pt = 24.0, 340.0
    seuil, mini, minh = 90.0, 3, 2
    i = 1
    while i < len(argv):
        if argv[i] == "--bande":
            x0pt, x1pt = float(argv[i + 1]), float(argv[i + 2]); i += 3
        elif argv[i] == "--seuil":
            seuil = float(argv[i + 1]); i += 2
        elif argv[i] == "--min":
            mini = int(argv[i + 1]); i += 2
        elif argv[i] == "--minh":
            minh = int(argv[i + 1]); i += 2
        else:
            i += 1

    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    h, w, _ = a.shape
    # L'échelle se prend sur la LARGEUR : c'est la seule dimension dont on
    # connaisse la valeur en points sans supposer la safe area.
    ptw = 393.0 if abs(w / 1179.0 - 1) < 0.02 else 402.0
    scale = w / ptw
    L = lum(a)

    x0, x1 = int(x0pt * scale), int(x1pt * scale)
    bande = L[:, x0:x1]
    clairs = (bande > seuil).sum(axis=1)
    porte = clairs >= mini

    print(f"capture {w}x{h} px = {w/scale:.0f}x{h/scale:.0f} pt (echelle x{scale:.2f})")
    print(f"bande x {x0pt:.0f}..{x1pt:.0f} pt · encre = >{seuil:.0f} L sur >={mini} px")
    print()
    print(f"{'haut(pt)':>9} {'bas(pt)':>9} {'haut(px)':>9} {'bas(px)':>9} "
          f"{'p95 L':>7} {'px max':>7}")
    for y0, y1 in bandes(porte, minh):
        seg = bande[y0:y1 + 1]
        vus = seg[seg > seuil]
        p95 = float(np.percentile(vus, 95)) if vus.size else 0.0
        print(f"{y0/scale:9.1f} {y1/scale:9.1f} {y0:9d} {y1:9d} "
              f"{p95:7.1f} {int(clairs[y0:y1+1].max()):7d}")
    print()
    # Le bas PHYSIQUE de l'écran est h ; la safe area basse d'un iPhone à
    # indicateur d'accueil vaut 34 pt. On donne les deux repères pour que
    # personne n'ait à les redéduire.
    print(f"bas physique : {h/scale:.1f} pt ({h} px)")
    print(f"bas zone sure (indicateur 34 pt) : {h/scale - 34:.1f} pt "
          f"({int(h - 34*scale)} px)")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1:])
