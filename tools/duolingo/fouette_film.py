#!/usr/bin/env python3
"""Fouettage d'un film de la duo-page : flash en V + coupes + cadence.

Usage : python3 fouette_film.py <film.mp4>

- flash : une frame dont la luminance moyenne tombe sous ~45 % de la
  moyenne de ses deux voisines (le V), scan de TOUTES les frames.
- coupe : delta frame-a-frame max par rangee (saut de rangee) — le
  detecteur du chantier (§11). ⚠️ piege 14 : il ne distingue pas une
  pastille brillante en VOL d'une arete — verifier les pires frames a
  l'oeil avant de conclure. Les 4 premieres secondes (naissance +
  zoom de lancement) sont exclues.
- cadence : frames uniques / duree (mpdecimate compte les doublons).
"""
import subprocess, sys, os, re, tempfile
import numpy as np
from PIL import Image

film = sys.argv[1]
frames = tempfile.mkdtemp(prefix="fouette_")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", film,
                "-vf", "scale=302:654", f"{frames}/f%04d.png"], check=True)
fs = sorted(os.listdir(frames))
imgs = [np.asarray(Image.open(os.path.join(frames, f)).convert("L")).astype(float) / 255
        for f in fs]
lum = np.array([a.mean() for a in imgs])
p = subprocess.run(["ffmpeg", "-i", film, "-vf", "mpdecimate", "-f", "null", "-"],
                   capture_output=True, text=True)
m = re.findall(r"frame=\s*(\d+)", p.stderr)
kept = int(m[-1]) if m else len(fs)
dm = re.findall(r"Duration: (\d+):(\d+):([\d.]+)", p.stderr)
dur = float(dm[0][2]) + 60 * float(dm[0][1]) if dm else len(fs) / 30
print(f"frames {len(fs)}, uniques {kept}, duree {dur:.1f}s, cadence utile ~{kept/dur:.1f} img/s")
debut = int(4 * len(fs) / max(dur, 1))
flashs = 0
for i in range(max(1, debut), len(lum) - 1):
    v = (lum[i - 1] + lum[i + 1]) / 2
    if v > 0.02 and lum[i] < 0.45 * v:
        flashs += 1
        print(f"  FLASH frame {i} : {lum[i]:.3f} vs voisines {v:.3f}")
print(f"flashs en V : {flashs}")
pire, pire_i = 0.0, 0
for i in range(max(1, debut), len(imgs)):
    mx = float(np.abs(imgs[i] - imgs[i - 1]).mean(axis=1).max()) * 255
    if mx > pire:
        pire, pire_i = mx, i
print(f"coupe max apres 4 s : {pire:.1f} (frame {pire_i}) — piege 14, verifier a l'oeil")
