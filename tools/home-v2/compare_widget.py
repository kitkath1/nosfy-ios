#!/usr/bin/env python3
"""LE COMPARATEUR DES CARDS — l'instrument de fouettage du jalon V3.

Kathryn veut la référence « à 100 %, tous les détails » et une note de
9,8/10. Une note se MESURE, sinon c'est un avis. Ce script :

  1. découpe ma card dans une capture du simulateur,
  2. la ramène à la taille de la card de référence,
  3. compare région par région (en-tête, graphe, pied, arêtes),
  4. sort une note sur 10 et l'image côte à côte qui montre où ça cloche.

Usage :
    python3 compare_widget.py <capture.png> <x> <y> <l> <h> [--ref chemin]

    x y l h = le rect de MA card dans la capture, en POINTS
              (la capture est à 3 px par point).

La note pondère ce qui compte pour l'œil : la structure d'abord (où sont
les choses), la matière ensuite (les niveaux), le détail en dernier.
"""

import sys
import numpy as np
from PIL import Image

ICI = "/Users/kathryn/Desktop/woochoper-ios/tools/home-v2"
DEFAUT_REF = ("/private/tmp/claude-501/-Users-kathryn-Desktop-woochoper-ios/"
              "53ed7d3b-1d7b-4935-ad5d-451b63a9b153/scratchpad/ref-volume.png")

# Le corps de la card DROITE dans la référence (mesuré, § 12 du plan).
REF_RECT = (757, 217, 607, 613)

# Les régions à noter, en fraction du corps (x0, y0, x1, y1) et leur poids.
# Les arêtes portent la signature de la card : elles pèsent lourd.
REGIONS = [
    ("en-tête",  (0.00, 0.00, 1.00, 0.34), 1.6),
    ("graphe",   (0.00, 0.34, 1.00, 0.72), 2.4),
    ("pied",     (0.00, 0.72, 1.00, 1.00), 1.4),
    ("arête or", (0.62, 0.00, 1.00, 0.34), 1.8),
    ("arête blanche", (0.00, 0.66, 0.38, 1.00), 1.2),
]


def lum(img):
    a = np.asarray(img.convert("RGB"), dtype=np.float32)
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def note_region(A, B):
    """0 → 1. Trois termes : la STRUCTURE (où sont les masses), le NIVEAU
    (est-ce aussi clair) et le CONTRASTE (est-ce aussi tranché)."""
    a, b = A.astype(np.float64), B.astype(np.float64)
    ma, mb = a.mean(), b.mean()
    sa, sb = a.std(), b.std()
    # structure : corrélation croisée normalisée
    da, db = a - ma, b - mb
    den = np.sqrt((da * da).sum() * (db * db).sum()) + 1e-6
    struct = float((da * db).sum() / den)
    struct = max(0.0, struct)
    # niveau et contraste : rapports symétriques
    niveau = 1 - abs(ma - mb) / (max(ma, mb) + 6.0)
    contraste = 1 - abs(sa - sb) / (max(sa, sb) + 6.0)
    return 0.55 * struct + 0.25 * niveau + 0.20 * contraste


def main():
    if len(sys.argv) < 6:
        print(__doc__)
        sys.exit(1)
    cap = sys.argv[1]
    x, y, w, h = (int(float(v)) for v in sys.argv[2:6])
    ref_path = DEFAUT_REF
    if "--ref" in sys.argv:
        ref_path = sys.argv[sys.argv.index("--ref") + 1]

    rx, ry, rw, rh = REF_RECT
    ref = Image.open(ref_path).convert("RGB").crop((rx, ry, rx + rw, ry + rh))

    src = Image.open(cap).convert("RGB")
    ech = src.width / 402.0                      # px par point
    mien = src.crop((int(x * ech), int(y * ech),
                     int((x + w) * ech), int((y + h) * ech)))
    mien = mien.resize((rw, rh), Image.LANCZOS)

    A, B = lum(ref), lum(mien)
    total, poids = 0.0, 0.0
    print(f"{'région':16s} {'note':>6s}")
    print("-" * 24)
    for nom, (fx0, fy0, fx1, fy1), p in REGIONS:
        sx0, sy0 = int(fx0 * rw), int(fy0 * rh)
        sx1, sy1 = int(fx1 * rw), int(fy1 * rh)
        n = note_region(A[sy0:sy1, sx0:sx1], B[sy0:sy1, sx0:sx1])
        print(f"{nom:16s} {n * 10:6.2f}")
        total += n * p
        poids += p
    globale = total / poids * 10
    print("-" * 24)
    print(f"{'GLOBALE':16s} {globale:6.2f} / 10")

    # l'image du verdict : référence | mien | différence
    diff = np.abs(A - B)
    dimg = Image.fromarray(
        np.clip(diff * 2.2, 0, 255).astype(np.uint8)).convert("RGB")
    out = Image.new("RGB", (rw * 3 + 24, rh), (30, 30, 30))
    out.paste(ref, (0, 0))
    out.paste(mien, (rw + 12, 0))
    out.paste(dimg, (rw * 2 + 24, 0))
    out.save(f"{ICI}/shots/verdict-widget.png")
    print(f"\nréf | mien | écart  →  {ICI}/shots/verdict-widget.png")
    return globale


if __name__ == "__main__":
    main()
