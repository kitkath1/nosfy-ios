#!/usr/bin/env python3
"""LE JUGE DU SOUFFLE — le contour de séance respire-t-il, et de combien ?

    python3 tools/home-v2/juge_souffle.py <film.mov> [--fps 10]

Une respiration NE SE JUGE PAS SUR UNE IMAGE FIXE : c'est un mouvement, et le
dépôt le dit — « une cinématique se FILME ». Cette sonde lit, image par image,
la braise sur l'ARÊTE de l'écran, et rend la courbe.

CE QU'ELLE MESURE, et pourquoi comme ça :
  · un ANNEAU de 6 à 24 pt depuis le bord — c'est là que vivent les quatre
    passes du contour, et ça exclut le contenu de la page ;
  · le p95 du canal ROUGE sur les pixels CLAIRS de cet anneau. Jamais une
    moyenne : sur du noir une moyenne tire vers le beige et invente de la
    lumière partout (règle de la maison, payée deux fois).

CE QU'ON VEUT LIRE :
  · un min et un max NETS (la braise respire), mais un min qui n'est PAS zéro
    (un signe d'état qui s'éteint par moments se lit comme un bug) ;
  · une courbe qui ne repasse pas par le même état — deux périodes premières
    entre elles. Un seul sinus se reconnaît en trois cycles et devient un
    clignotant : c'est la loi des liserés, et elle vaut ici.
"""
import subprocess
import sys
import tempfile
import os
import glob
import numpy as np
from PIL import Image


def braise(path, dedans_pt=24.0, dehors_pt=6.0):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    h, w, _ = a.shape
    s = w / 393.0
    di, de = int(dedans_pt * s), int(dehors_pt * s)
    R = a[..., 0]
    # L'anneau : tout ce qui est à moins de `dedans` du bord, moins le coeur.
    masque = np.zeros((h, w), dtype=bool)
    masque[de:di, de:-de] = True          # haut
    masque[-di:-de, de:-de] = True        # bas
    masque[de:-de, de:di] = True          # gauche
    masque[de:-de, -di:-de] = True        # droite
    vus = R[masque]
    clairs = vus[vus > 12]                # les pixels CLAIRS, jamais la moyenne
    if clairs.size < 50:
        return 0.0
    return float(np.percentile(clairs, 95))


def main(argv):
    film = argv[0]
    fps = 10
    if "--fps" in argv:
        fps = int(argv[argv.index("--fps") + 1])
    tmp = tempfile.mkdtemp(prefix="souffle-")
    subprocess.run(["ffmpeg", "-v", "error", "-i", film, "-vf", f"fps={fps}",
                    os.path.join(tmp, "f%05d.png")], check=True)
    frames = sorted(glob.glob(os.path.join(tmp, "f*.png")))
    vals = [braise(f) for f in frames]
    if not vals:
        print("aucune image")
        return

    lo, hi = min(vals), max(vals)
    print(f"{len(vals)} images à {fps} img/s — {len(vals)/fps:.1f} s\n")
    print(f"  min {lo:6.1f}   max {hi:6.1f}   amplitude {hi - lo:5.1f} "
          f"({100 * (hi - lo) / max(hi, 1):.0f} % du max)")
    print()
    # La courbe, en barres — on VOIT la respiration au lieu de la déduire.
    for i, v in enumerate(vals):
        n = int(round((v - lo) / max(hi - lo, 1e-6) * 44))
        print(f"  {i/fps:5.1f}s {v:6.1f} {'█' * n}")
    print()
    if lo < 1:
        print("⚠️  la braise S'ÉTEINT complètement à un moment — un signe "
              "d'état qui disparaît se lit comme un bug.")
    else:
        print(f"✅ plancher à {lo:.1f} : elle ne s'éteint jamais.")
    print(f"\nimages : {tmp}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1:])
