#!/usr/bin/env python3
"""L'INSTRUMENT DE LA PIÈCE DE VERRE — chantier coffre v2, jalon C4.

Il compare MA pièce (une capture du simulateur) à LA RÉFÉRENCE de Kathryn
(une image du film `Liquid_pièces.mp4`, extraite en 4K natif) sur le seul
terrain qui compte : **le profil radial**.

POURQUOI LE PROFIL RADIAL ET PAS UNE DIFFÉRENCE D'IMAGES. Les deux objets
n'ont ni la même taille, ni le même lacet, ni la même place. Une soustraction
pixel à pixel ne mesurerait que ce décalage. Le profil radial, lui, est
INVARIANT à l'échelle et à la position : il dit où la matière commence, où
sont les arcs, quelle est la luminance et la saturation de chaque anneau.
C'est la seule mesure qui compare deux rendus d'un même OBJET.

⚠️ CALIBRAGE. Comme `compare_widget.py`, cet instrument est sensible : le
centre et les demi-axes se déduisent de la boîte englobante, donc une pièce
capturée avec un halo débordant décale tout de quelques pour cent. On mesure
donc TOUJOURS sur la même matière (seuil 14/255) et on lit les ÉCARTS de forme
du profil, pas ses valeurs absolues au dixième.

Usage :
    python3 compare_piece.py ref <image> [--y0 N --y1 N] --out ref.json
    python3 compare_piece.py cmp <capture> --ref ref.json [--y0 N --y1 N]
"""
import argparse
import json
import sys

import numpy as np
from PIL import Image

SEUIL = 14.0
BANDES = 26
PORTEE = 1.15


def _charge(chemin, y0=None, y1=None):
    im = Image.open(chemin).convert("RGB")
    a = np.asarray(im, dtype=float)
    if y0 is not None or y1 is not None:
        a = a[y0 or 0 : y1 or a.shape[0]]
    return a


def _ellipse(L):
    """Le centre et les demi-axes de la matière, par sa boîte englobante."""
    m = L > SEUIL
    if m.sum() < 200:
        sys.exit("pas de matière : seuil trop haut, ou image vide")
    ys, xs = np.where(m)
    cx = (xs.min() + xs.max()) / 2.0
    cy = (ys.min() + ys.max()) / 2.0
    rx = max((xs.max() - xs.min()) / 2.0, 1.0)
    ry = max((ys.max() - ys.min()) / 2.0, 1.0)
    return cx, cy, rx, ry


def profil(a):
    """Le profil radial : luminance, saturation, haut/bas, par anneau."""
    L = a.mean(axis=2)
    cx, cy, rx, ry = _ellipse(L)
    H, W = L.shape
    yy, xx = np.mgrid[0:H, 0:W]
    u = (xx - cx) / rx
    v = (yy - cy) / ry
    r = np.sqrt(u * u + v * v)
    ang = np.arctan2(v, u)

    bandes = []
    for i in range(BANDES):
        lo, hi = i / BANDES * PORTEE, (i + 1) / BANDES * PORTEE
        sel = (r >= lo) & (r < hi)
        if sel.sum() < 120:
            continue
        rgb = a[sel].mean(axis=0)
        mx = float(rgb.max())
        sat = 0.0 if mx < 1 else float((mx - rgb.min()) / mx)
        haut = sel & (ang < -0.6)
        bas = sel & (ang > 0.6)
        bandes.append(
            {
                "r": round((lo + hi) / 2, 4),
                "L": round(float(L[sel].mean()), 2),
                "Lmax": round(float(L[sel].max()), 1),
                "sat": round(sat, 3),
                "haut": round(float(L[haut].mean()) if haut.sum() > 20 else 0.0, 2),
                "bas": round(float(L[bas].mean()) if bas.sum() > 20 else 0.0, 2),
            }
        )
    return {
        "ratio": round(float(ry / rx), 4),
        "bandes": bandes,
    }


def _serie(p, cle):
    return np.array([b[cle] for b in p["bandes"]], dtype=float)


def _cale(x):
    """Normalise une série de luminance sur son maximum : on compare des
    FORMES de profil, pas des expositions. Une pièce plus sombre mais de même
    structure doit sortir bonne — c'est le niveau qu'on règle après, pas la
    géométrie."""
    m = x.max()
    return x / m if m > 1e-6 else x


def note(ref, mien):
    """Une note sur 10, décomposée. Chaque terme est une distance normalisée."""
    n = min(len(ref["bandes"]), len(mien["bandes"]))
    if n < 8:
        sys.exit("profils trop courts pour comparer")

    rl, ml = _cale(_serie(ref, "L")[:n]), _cale(_serie(mien, "L")[:n])
    rs, ms = _serie(ref, "sat")[:n], _serie(mien, "sat")[:n]
    rh, mh = _cale(_serie(ref, "haut")[:n]), _cale(_serie(mien, "haut")[:n])
    rb, mb = _cale(_serie(ref, "bas")[:n]), _cale(_serie(mien, "bas")[:n])

    def score(d, tol):
        return max(0.0, 10.0 - float(np.abs(d).mean()) / tol * 10.0)

    termes = {
        "forme du profil": score(rl - ml, 0.30),
        "saturation": score(rs - ms, 0.30),
        "asymétrie haut": score(rh - mh, 0.40),
        "asymétrie bas": score(rb - mb, 0.40),
        "ratio d'ellipse": max(
            0.0, 10.0 - abs(ref["ratio"] - mien["ratio"]) / 0.10 * 10.0
        ),
    }
    poids = {
        "forme du profil": 0.40,
        "saturation": 0.20,
        "asymétrie haut": 0.15,
        "asymétrie bas": 0.15,
        "ratio d'ellipse": 0.10,
    }
    total = sum(termes[k] * poids[k] for k in termes)
    return total, termes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["ref", "cmp"])
    ap.add_argument("image")
    ap.add_argument("--ref", help="le json de référence (mode cmp)")
    ap.add_argument("--out", help="où écrire le json (mode ref)")
    ap.add_argument("--y0", type=int)
    ap.add_argument("--y1", type=int)
    args = ap.parse_args()

    a = _charge(args.image, args.y0, args.y1)
    p = profil(a)

    if args.mode == "ref":
        sortie = args.out or "ref.json"
        with open(sortie, "w") as f:
            json.dump(p, f, indent=1)
        print(f"référence écrite : {sortie}  (ratio {p['ratio']}, "
              f"{len(p['bandes'])} anneaux)")
        print(f"{'r/R':>6} {'L':>7} {'sat':>6} {'haut':>7} {'bas':>7}")
        for b in p["bandes"]:
            print(f"{b['r']:>6.2f} {b['L']:>7.1f} {b['sat']:>6.2f} "
                  f"{b['haut']:>7.1f} {b['bas']:>7.1f}")
        return

    if not args.ref:
        sys.exit("mode cmp : --ref est obligatoire")
    with open(args.ref) as f:
        ref = json.load(f)

    total, termes = note(ref, p)
    print(f"\n  NOTE : {total:.2f} / 10\n")
    for k, v in sorted(termes.items(), key=lambda kv: kv[1]):
        print(f"    {k:<20} {v:>5.2f}")
    print(f"\n  ratio d'ellipse : réf {ref['ratio']:.3f}  ·  moi {p['ratio']:.3f}")

    n = min(len(ref["bandes"]), len(p["bandes"]))
    rl, ml = _cale(_serie(ref, "L")[:n]), _cale(_serie(p, "L")[:n])
    print(f"\n  {'r/R':>6} {'L réf':>8} {'L moi':>8} {'écart':>8} "
          f"{'sat réf':>8} {'sat moi':>8}")
    for i in range(n):
        b, c = ref["bandes"][i], p["bandes"][i]
        print(f"  {b['r']:>6.2f} {rl[i]:>8.3f} {ml[i]:>8.3f} "
              f"{ml[i]-rl[i]:>+8.3f} {b['sat']:>8.2f} {c['sat']:>8.2f}")


if __name__ == "__main__":
    main()
