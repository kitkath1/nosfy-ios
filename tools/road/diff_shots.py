#!/usr/bin/env python3
"""LA SONDE DE NON-RÉGRESSION — deux captures, un verdict chiffré.

    python3 tools/road/diff_shots.py avant.png apres.png [--zone x0 y0 x1 y1]

Un juge qui affirme ne remplace pas une sonde qui mesure : un refactor « qui
ne change rien » se PROUVE, il ne se raconte pas.

⚠️ **MAIS PAS SUR LA PAGE DU CHEMIN — MESURÉ LE 29-08.** Deux captures du
MÊME build, gelées (`-duoFreeze`), diffèrent de **37 %** des pixels : le film
du verre noir tourne derrière tout, et `-duoFreeze` ne l'arrête pas. Le bruit
écrase le signal (un changement de code en donnait 45 %). Sur cette page, la
non-régression se prouve sur les VALEURS (le diff normalisé des deux
implémentations, ou une sonde qui écrit l'état des 45 nœuds), jamais au pixel.
Cette sonde reste bonne pour un banc SANS vidéo — la card ROUTE de la home,
par exemple, si son fond est gelé.

Elle rend trois nombres :
  · pixels différents (et leur part) ;
  · l'écart maximum sur un canal ;
  · le centre de gravité des différences — c'est lui qui dit OÙ ça a bougé
    quand ça a bougé (une date qui a tourné n'est pas un galet qui a changé
    d'état).
"""
import sys
import numpy as np
from PIL import Image


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) < 2:
        print(__doc__)
        return 2
    a = np.asarray(Image.open(args[0]).convert("RGB")).astype(np.int16)
    b = np.asarray(Image.open(args[1]).convert("RGB")).astype(np.int16)
    if a.shape != b.shape:
        print(f"TAILLES DIFFÉRENTES : {a.shape} vs {b.shape}")
        return 1
    if "--zone" in sys.argv:
        i = sys.argv.index("--zone")
        x0, y0, x1, y1 = (int(v) for v in sys.argv[i + 1:i + 5])
        a, b = a[y0:y1, x0:x1], b[y0:y1, x0:x1]

    d = np.abs(a - b)
    par_pixel = d.max(axis=2)
    n = int((par_pixel > 0).sum())
    total = par_pixel.size
    print(f"pixels différents : {n} / {total}  ({100 * n / total:.3f} %)")
    print(f"écart max         : {int(par_pixel.max())} / 255")
    if n:
        ys, xs = np.nonzero(par_pixel)
        print(f"boîte des écarts  : x {xs.min()}–{xs.max()}  "
              f"y {ys.min()}–{ys.max()}")
        # Les vingt lignes les plus touchées : une date qui a changé tient sur
        # une bande, un état qui a changé tache tout un galet.
        lignes = np.argsort(-(par_pixel > 0).sum(axis=1))[:5]
        for y in sorted(lignes):
            c = int((par_pixel[y] > 0).sum())
            if c:
                print(f"  ligne {y:5d} : {c} pixels")
    print("✅ IDENTIQUE" if n == 0 else "⚠️ ÇA A BOUGÉ")
    return 0


if __name__ == "__main__":
    sys.exit(main())
