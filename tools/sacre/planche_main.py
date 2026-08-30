#!/usr/bin/env python3
"""
planche_main.py — UNE BOUCLE DE LA MAIN, découpée en 8 temps.

    python3 tools/sacre/planche_main.py tools/sacre/films/booster-HHMMSS.mov [t0]

La main et le texte « drag to open » vivent sur une boucle de 3,0 s : une
capture immobile tombe où elle tombe (verdict impossible). On prend donc le
FILM, on cherche l'instant où la card est POSÉE (la clarté de l'écran devient
stable après l'entrée), puis on tire 8 images sur une période — toutes les
0,375 s — recadrées sur le sachet et sa légende, et on les met en planche.

⚠️ Les instants se lisent sur les pts (le recordVideo du sim est VFR) : on
demande à ffmpeg l'image dont le pts est le plus proche de chaque temps, on ne
compte jamais les images.
"""
import sys, os, subprocess
import numpy as np
from PIL import Image, ImageDraw

MOV = sys.argv[1] if len(sys.argv) > 1 else None
if not MOV or not os.path.exists(MOV):
    sys.exit("usage: planche_main.py <film.mov> [t0]")
PERIODE = 3.0
N = 8

# ── la taille et la géométrie de l'écran ──────────────────────────────────
prb = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0",
                      "-show_entries", "stream=width,height", "-of", "csv=p=0", MOV],
                     capture_output=True, text=True).stdout.strip().split(",")
W, H = int(prb[0]), int(prb[1])
ech = W / 393.0
# la card : min(0,80·393, 332) = 314 × 440 pt, centrée ; le sachet centré à 136,
# la légende à 272 — on garde la fenêtre 20 → 300 pt de la card.
lp, hp = 314.0, 440.0
x0 = (W - lp * ech) / 2
y0 = (H - hp * ech) / 2
boite = (int(x0 + 40 * ech), int(y0 + 20 * ech), int(x0 + (lp - 40) * ech), int(y0 + 300 * ech))


def image_a(t):
    """L'image dont le pts est le plus proche de t (jamais un compte d'images)."""
    b = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-ss", f"{t:.3f}", "-i", MOV,
                        "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                       capture_output=True).stdout
    if len(b) < W * H * 3:
        return None
    return np.frombuffer(b[:W * H * 3], np.uint8).reshape(H, W, 3)


# ── t0 : la card est posée quand la clarté se stabilise ───────────────────
if len(sys.argv) > 2:
    t0 = float(sys.argv[2])
else:
    petits = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", MOV, "-vf", "scale=60:130",
                             "-f", "rawvideo", "-pix_fmt", "gray", "-"], capture_output=True).stdout
    fr = np.frombuffer(petits, np.uint8)[:len(petits) // 7800 * 7800].reshape(-1, 130, 60)
    pts = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0",
                          "-show_entries", "frame=pts_time", "-of", "csv=p=0", MOV],
                         capture_output=True, text=True).stdout.replace(",", " ").split()
    t = np.array([float(x) for x in pts if x])[:len(fr)]
    c = fr.reshape(len(fr), -1).mean(axis=1)
    # la card est posée : la clarté a atteint son plateau et ne bouge plus de 0,3 pendant 1 s
    t0 = None
    for i in range(len(c)):
        fin = t[i] + 1.0
        j = np.searchsorted(t, fin)
        if j < len(c) and c[i] > c.max() * 0.85 and np.abs(c[i:j] - c[i]).max() < 0.3:
            t0 = t[i]
            break
    if t0 is None:
        t0 = t[-1] - PERIODE * 2
print(f"film {W}×{H}, card posée à t0 = {t0:.2f} s ; 8 images de t0 + 1,5 s sur une période de {PERIODE} s")

tuiles = []
for k in range(N):
    tk = t0 + 1.5 + k * PERIODE / N
    im = image_a(tk)
    if im is None:
        break
    z = Image.fromarray(im).crop(boite)
    z = z.resize((int(z.width * 0.5), int(z.height * 0.5)), Image.LANCZOS)
    d = ImageDraw.Draw(z)
    d.text((8, 6), f"+{k * PERIODE / N:.2f} s", fill=(220, 220, 220))
    tuiles.append(z)
tw, th = tuiles[0].size
P = Image.new("RGB", (tw * 4, th * 2), (20, 20, 20))
for k, z in enumerate(tuiles):
    P.paste(z, ((k % 4) * tw, (k // 4) * th))
out = os.path.join(os.path.dirname(MOV), "..", "vignettes", "main-boucle.png")
out = os.path.normpath(out)
P.save(out)
print(f"planche → {out}")
