#!/usr/bin/env python3
"""
bake_dot.py — LA VIDÉO EST LE MUR : le fond de la card booster + les points.

Entrée  : ~/Downloads/video_dot.mp4 — H.264 3836 × 2160 PAYSAGE, 24 img/s,
          121 images / 5,04 s, une piste audio (jetée). Une constellation de
          points dorés sur une grille, en x 24-76 %, y 38-61 % de l'image.
Sortie  : Woop/Media/booster-dot-loop.mp4 — PORTRAIT 1080 × 1512 (= la card
          314 × 440 pt à 3,44 px/pt, ratio 1,40), palindrome 240 images, 10 s.

CE QUE LA MESURE A TRANCHÉ (PLAN-BOOSTER-CARD.md §2) :
  · le noir de la source N'EST PAS NOIR : décodé, p95 24/255, teinté chaud
    (R 10,8 · G 7,3 · B 5,2). Posé tel quel : un rectangle brun sur la card.
    → on ÉCRASE sous 26.
  · la couture de boucle est sale (|f0−f120| = 0,73 contre 0,16 entre deux
    voisines, × 4,5) → PALINDROME amputé (0→120, 119→1), la grammaire de la bête.
  · une fenêtre portrait 1:1,40 ne fait que 40 % de la largeur, les points en
    occupent 52 % → on ne recadre PAS : la bande paysage ENTIÈRE, mise à la
    largeur de la card.

LA FORME : le fichier contient LE FOND DE LA CARD LUI-MÊME (les six stops de
`BoosterCard.fond`, en pixels) et la bande de points en ÉCRAN dessus, sous une
vignette cuite qui meurt ~180 px avant ses bords. Ainsi, dans SwiftUI, la vidéo
est bord à bord, opaque, SANS masque (la loi), et ses bords valent exactement
le fond que la card dessine dessous : pendant l'entrée elle fond dans un mur
identique — aucune couture possible. Et comme vidéo = fond + points, baisser
son OPACITÉ sur ce même fond ne fait que baisser les points : c'est le réglage
d'intensité, sans rien recuire.

⚠️ `-ss` ne coupe pas le graphe ffmpeg — la coupe et le palindrome se font en
numpy, l'encodeur reçoit les 240 images finies par un tube rawvideo.
"""
import os, subprocess
import numpy as np
from PIL import Image, ImageDraw

SRC = os.path.expanduser("~/Downloads/video_dot.mp4")
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_MP4 = f"{REPO}/Woop/Media/booster-dot-loop.mp4"
HERO = f"{REPO}/Woop/Assets.xcassets/booster-hero.imageset/booster-hero.png"
VIG = f"{REPO}/tools/sacre/vignettes"

CW, CH = 1080, 1512                  # la card 314 × 440 pt
PT = CW / 314.0
SW, SH = 3836, 2160
# ⚠️ LE ZOOM (30-08, mesuré sur la première cuisson) : la bande à la largeur
# de la card donnait des points de 5 px de médiane = 0,7 pt sur le téléphone —
# 57 points, max 255, et RIEN À VOIR. Les points vivent en x 24-76 % de la
# source, centre (51 %, 49,5 %) : on met la bande à 1,9 × la largeur de la
# card (2052 px — encore une RÉDUCTION du 4K, donc net) et on garde une
# fenêtre 1080 × 800 sur son centre. Le champ remplit la card, la vignette
# fond ses bords, et un point fait ~2,7 pt.
# 1,9 → 1,5 (verdict Kathryn 30-08 : « diminue la vidéo pour que les lumières
# paraissent plus petites ») : un point passe de ~11 à ~7 px, la grille reste.
ZOOM = 1.5
ZW = int(round(CW * ZOOM))
ZH = int(round(SH * ZW / SW)) // 2 * 2
BW, BH = CW, 800                     # la fenêtre gardée dans la bande zoomée
ZX0 = (ZW - BW) // 2                 # centrée en x
ZY0 = int(round(0.495 * ZH - BH / 2))   # centrée sur le centre des points
CENTRE_PT = 136.0                    # le centre du sachet (§4 du plan)
BY0 = int(round(CENTRE_PT * PT - BH / 2))
ECRASE = 26.0                        # le p95 du fond mesuré, + 2
FONDU_X, FONDU_Y = 180, 130          # la vignette, en px, depuis les bords de la fenêtre
STOPS = [(0, .006), (.36, .014), (.62, .050), (.74, .066), (.86, .028), (1, .008)]


def lisse(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


# ── LE FOND DE LA CARD, en pixels ──────────────────────────────────────────
v = np.interp(np.linspace(0, 1, CH), [s[0] for s in STOPS], [s[1] for s in STOPS])
fond = np.repeat(v[:, None], CW, axis=1)          # 0..1, neutre

# ── LA VIGNETTE de la bande ────────────────────────────────────────────────
xs = np.arange(BW); ys = np.arange(BH)
vx = lisse(np.minimum(xs, BW - 1 - xs) / FONDU_X)
vy = lisse(np.minimum(ys, BH - 1 - ys) / FONDU_Y)
vig = vy[:, None] * vx[None, :]

# ── LES IMAGES, décodées DIRECTEMENT à la taille de la bande ──────────────
p = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", SRC, "-an",
                    "-vf", f"scale={ZW}:{ZH}:flags=lanczos,crop={BW}:{BH}:{ZX0}:{ZY0}",
                    "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True)
n = BW * BH * 3
src = [np.frombuffer(p.stdout[i * n:(i + 1) * n], np.uint8).reshape(BH, BW, 3).astype(float)
       for i in range(len(p.stdout) // n)]
print(f"[1] {len(src)} images : bande zoomée {ZW}×{ZH}, fenêtre {BW}×{BH} à ({ZX0},{ZY0})")

def poser(fr):
    k = np.clip((fr - ECRASE) / (255.0 - ECRASE), 0, 1) * vig[:, :, None]   # écrasé, vignetté
    can = np.repeat(fond[:, :, None], 3, axis=2).copy()
    zone = can[BY0:BY0 + BH]
    can[BY0:BY0 + BH] = 1 - (1 - zone) * (1 - k)                            # ÉCRAN
    return (can * 255).round().astype(np.uint8)

posees = [poser(fr) for fr in src]
ordre = list(range(len(posees))) + list(range(len(posees) - 2, 0, -1))
print(f"[2] bande posée en y {BY0}→{BY0 + BH} ({BY0 / PT:.0f}→{(BY0 + BH) / PT:.0f} pt) ; "
      f"palindrome {len(ordre)} images = {len(ordre) / 24:.2f} s")

os.makedirs(os.path.dirname(OUT_MP4), exist_ok=True)
enc = subprocess.Popen(
    ["ffmpeg", "-nostdin", "-y", "-v", "error",
     "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{CW}x{CH}", "-r", "24", "-i", "-",
     "-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p",
     "-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-crf", "17",
     "-g", "48", "-keyint_min", "48", "-sc_threshold", "0",
     "-x264-params", "no-dct-decimate=1:aq-mode=3",
     "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709",
     "-color_trc", "bt709", "-movflags", "+faststart", "-an", OUT_MP4],
    stdin=subprocess.PIPE)
for i in ordre:
    enc.stdin.write(posees[i].tobytes())
enc.stdin.close(); enc.wait()
print(f"[3] {OUT_MP4} : {os.path.getsize(OUT_MP4) / 1e6:.2f} Mo")

# ── LE PORTILLON — sur le FICHIER décodé ──────────────────────────────────
p = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", OUT_MP4,
                    "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True)
n = CW * CH * 3
dec = [np.frombuffer(p.stdout[i * n:(i + 1) * n], np.uint8).reshape(CH, CW, 3)
       for i in range(len(p.stdout) // n)]
attendu = (fond * 255)
M = 12
pire = 0.0
for fr in dec[::20]:
    L = fr.astype(float).max(axis=2)
    for bande in (L[:M] - attendu[:M], L[-M:] - attendu[-M:],
                  L[:, :M] - attendu[:, :M], L[:, -M:] - attendu[:, -M:]):
        pire = max(pire, float(np.abs(bande).max()))
haut = np.abs(dec[60].astype(float).max(axis=2)[BY0 - 4:BY0 + 4] - attendu[BY0 - 4:BY0 + 4]).max()
bas = np.abs(dec[60].astype(float).max(axis=2)[BY0 + BH - 4:BY0 + BH + 4] - attendu[BY0 + BH - 4:BY0 + BH + 4]).max()
deltas = [float(np.abs(dec[i].astype(int) - dec[i + 1].astype(int)).mean()) for i in range(len(dec) - 1)]
couture = float(np.abs(dec[0].astype(int) - dec[-1].astype(int)).mean())
print(f"[4] {len(dec)} images décodées ; écart bords ↔ fond attendu : max {pire:.1f}/255 "
      f"(≤ 2 attendu) ; arête haute/basse de la bande : {haut:.1f} / {bas:.1f} ; "
      f"couture f0↔f{len(dec) - 1} : {couture:.3f} vs médiane voisines {np.median(deltas):.3f}")
# ⚠️ PAS UN PERCENTILE : des points minuscules ne pèsent pas 0,1 % de l'image,
# un p99,9 les rate et annonce « 35/255 » alors qu'ils sont à 255. On COMPTE
# les points et on mesure leur TAILLE — c'est elle qui décide s'ils se voient.
from scipy import ndimage as ndi
Lm = dec[60].max(axis=2)
lab, k = ndi.label(Lm > 60)
tailles = np.asarray(ndi.sum(Lm > 60, lab, range(1, k + 1))) if k else np.array([0])
print(f"[4] les points (image 60) : {k} distincts, max {int(Lm.max())}/255, taille médiane "
      f"{np.median(tailles):.0f} px → ~{np.sqrt(np.median(tailles)) / PT:.1f} pt de côté "
      f"(la 1re cuisson : 5 px = 0,7 pt, invisibles)")

# ── LA PLANCHE : raccord, et LA COMPOSITION AVEC LE SACHET à 3 intensités ─
os.makedirs(VIG, exist_ok=True)
tw, th = 240, int(240 * CH / CW)
planche = Image.new("RGB", (tw * 6, th), (24, 24, 24))
for k2, i in enumerate((0, 60, 118, 121, 180, 239)):
    planche.paste(Image.fromarray(dec[i]).resize((tw, th), Image.LANCZOS), (k2 * tw, 0))
planche.save(f"{VIG}/dot-raccord.png")

hero = Image.open(HERO).convert("RGBA")
hh = int(round(176 * PT)); hw = int(round(hero.width * hh / hero.height))
hero = hero.resize((hw, hh), Image.LANCZOS)
base = dec[60].astype(float) / 255.0
tw2 = 320; th2 = int(320 * CH / CW)
comp = Image.new("RGB", (tw2 * 3, th2), (0, 0, 0))
for k2, op in enumerate((0.6, 0.8, 1.0)):
    im = fond[:, :, None] + op * (base - fond[:, :, None])           # l'opacité = l'intensité des points
    im = np.clip(im, 0, 1)
    # la lueur de scène : une ellipse radiale orange sous le sachet
    yy, xx = np.mgrid[0:CH, 0:CW]
    cx, cy = CW / 2, CENTRE_PT * PT + 12 * PT
    r = np.sqrt(((xx - cx) / (hw * 0.95)) ** 2 + ((yy - cy) / (hw * 1.05)) ** 2)
    g = np.clip(1 - r, 0, 1) ** 1.6 * 0.42
    lueur = np.array([1.0, 0.55, 0.20])
    im = im + g[:, :, None] * lueur[None, None, :] * 0.55
    pil = Image.fromarray((np.clip(im, 0, 1) * 255).astype(np.uint8))
    pil.paste(hero, (int(cx - hw / 2), int(CENTRE_PT * PT - hh / 2)), hero)
    comp.paste(pil.resize((tw2, th2), Image.LANCZOS), (k2 * tw2, 0))
d = ImageDraw.Draw(comp)
for k2, op in enumerate((0.6, 0.8, 1.0)):
    d.text((k2 * tw2 + 10, th2 - 24), f"points a {op:.1f}", fill=(200, 200, 200))
comp.save(f"{VIG}/dot-composition.png")
print(f"[5] planches → {VIG}/dot-raccord.png · {VIG}/dot-composition.png (0,6 / 0,8 / 1,0)")
