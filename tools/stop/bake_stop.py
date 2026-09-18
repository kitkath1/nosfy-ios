#!/usr/bin/env python3
"""
bake_stop.py — LA BÊTE DU STOP, cuite pour la card (J0 de PLAN-STOP-CARD.md).

Entrée  : ~/Downloads/chauve-souri_stop.mp4 (H.264 3836×2160, 24 img/s, 121 images,
          fond à 0,0 EXACT hors la bête — mesuré).
Sorties : Nosfy/Media/stop-bat-loop.mp4
              1080×1562 (= la card 332×480 pt à 3,253 px/pt), palindrome 240 images
              (10,0 s), NOIR EXACT + la bête posée.
          Nosfy/Assets.xcassets/stop-bat-masque.imageset/stop-bat-masque.png
              la silhouette STATIQUE INVERSE, EN RGBA (blanc + alpha) — le
              masque du MUR (fond + mot), jamais de la vidéo.
          tools/stop/vignettes/stop-bat-planche.png — la planche du raccord.

⚠️ CE QUE LA MESURE A TRANCHÉ (§3.1 du plan) : un matte « pixel ≠ 0 » image par
image ÉCHOUE sur cette bête — le pelage est lui-même à 0 exact sur 180-270 k px,
la silhouette varie de 40-46 % d'une image à l'autre. La bête est IMMOBILE (elle
respire) : la silhouette se cuit donc UNE fois, statique.

⚠️ MAIS PAS PAR L'UNION (verdict « le détourage est horrible », 29-08) —
l'union déborde la bête de ~6 % et laissait une AURA NOIRE sur le mur gris.
On prend la silhouette d'OCCUPATION (présent sur ≥ 50 % des images), et on
ÉRODE d'un cheveu au lieu de dilater : le mur mord la frange de poils (noire,
donc invisible) plutôt que de laisser du noir autour d'elle.

⚠️ LE MASQUE EST EN RGBA : `.mask` de SwiftUI lit l'ALPHA, jamais la
luminance. Un PNG en niveaux de gris est opaque partout — le masque ne troue
rien et la bête disparaît, sans une seule erreur.

⚠️ `-ss` ne coupe pas le graphe ffmpeg — ici la coupe et le palindrome se font
en numpy, l'encodeur reçoit les 240 images finies par un tube rawvideo.
"""
import os, subprocess, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SRC = os.path.expanduser("~/Downloads/chauve-souri_stop.mp4")
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_MP4 = f"{REPO}/Nosfy/Media/stop-bat-loop.mp4"
OUT_SET = f"{REPO}/Nosfy/Assets.xcassets/stop-bat-masque.imageset"
VIG = f"{REPO}/tools/stop/vignettes"

SW, SH = 3836, 2160            # la source
CW, CH = 1080, 1562            # la card : 332 × 480 pt, ratio 1,4458
PT = CW / 332                  # px par pt
# ⚠️ COTES REVUES LE 29-08 (verdicts Kathryn) : la bête était TROP COLLÉE au
# titre. Elle monte (pieds 268 → 246) et rétrécit un peu (220 → 200) pour ne
# pas venir toucher la fente du spot. Sur un écran de 393 pt la card ne fait
# que 314 de large (`min(0,80·W, 332)`) : tout ce que porte la vidéo rétrécit
# de 5,3 %, alors que le TEXTE garde ses points — c'est là qu'ils se
# rencontraient.
BETE_H_PT, PIEDS_PT = 200, 246
MARGE = 24                     # px @4K autour de la boîte de la bête
R_FERME = 14                   # rayon de fermeture morphologique @4K
MIN_COMP = 8000                # une composante plus petite est une poussière
OCCUPATION = 0.5               # présent sur ≥ 50 % des images
EROSION_MASQUE = 1             # px @1080 — le mur mord la frange, jamais l'inverse
# ⚠️ LA POCHE D'OMBRE (29-08, tranché avec Kathryn) — un bord NET ne peut pas
# marcher : la silhouette est STATIQUE et les oreilles BOUGENT (elles sortent
# du trou de 1 553 px en médiane, 4 889 au pire). Aucun contour n'est donc
# juste sur les 240 images.
#
# La triche : on ne cherche plus le contour, on le NOIE. Le mur s'éteint en
# approchant d'elle, sur ~22 pt. Une oreille qui déborde tombe alors sur un
# mur déjà éteint — son erreur n'a plus rien à découper — et le halo large et
# doux ne se lit plus comme un détourage raté mais comme son ombre portée.
#
# MESURÉ : ce sont les LETTRES, pas le gris du fond, qui faisaient le halo (le
# T et le O passent pile sur ses oreilles). Le fond inversé seul ne bougeait
# le p95 que de 151 → 143 ; avec cette poche il tombe à 102.
OMBRE_PT = 22.0                # largeur du dégradé, en points de card
DILAT_DUR = 14                 # au-delà : NOIR forcé dans la vidéo (fond garanti)
# La boîte GÉNÉREUSE où la bête vit à coup sûr (mesurée : x 1350-2376,
# y 48-2074). Elle permet de ne décoder la source QU'UNE FOIS : on garde ce
# rectangle de chaque image en mémoire, et la géométrie exacte se décide
# après, quand la silhouette est connue. Deux passes de décodage 4K coûtaient
# 15 minutes.
BX0, BX1, BY0, BY1 = 1320, 2410, 20, 2110


def images(src, taille):
    """Les images RGB pleine résolution, une à une (jamais 121 × 4K d'un coup)."""
    p = subprocess.Popen(["ffmpeg", "-nostdin", "-v", "error", "-i", src,
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         stdout=subprocess.PIPE)
    n = taille[0] * taille[1] * 3
    while True:
        b = p.stdout.read(n)
        if len(b) < n:
            break
        yield np.frombuffer(b, np.uint8).reshape(taille[1], taille[0], 3)
    p.wait()


def closing_edt(mask, r):
    """Fermeture morphologique par transformée de distance (rapide sur 8 Mpx)."""
    dil = ndi.distance_transform_edt(~mask) <= r
    return ndi.distance_transform_edt(dil) > r


# ── L'UNIQUE PASSE DE DÉCODAGE ─────────────────────────────────────────────
# On accumule DEUX choses : le compte d'occupation par pixel (pleine
# résolution) et le rectangle généreux de chaque image (pour poser ensuite,
# sans redécoder).
compte = np.zeros((SH, SW), np.uint16)
gard = []
for fr in images(SRC, (SW, SH)):
    compte += (fr.max(axis=2) > 0)
    gard.append(fr[BY0:BY1, BX0:BX1].copy())
n_src = len(gard)
union = compte > 0
brut = compte >= max(1, int(round(OCCUPATION * n_src)))
print(f"[1] {n_src} images lues ; union {int(union.sum())} px, "
      f"occupation ≥{OCCUPATION:.0%} {int(brut.sum())} px "
      f"({100 * brut.sum() / max(1, union.sum()):.0f} % de l'union) ; "
      f"{sum(a.nbytes for a in gard) / 1e6:.0f} Mo gardés")

sil = closing_edt(brut, R_FERME)
sil = ndi.binary_fill_holes(sil)
lab, k = ndi.label(sil)
tailles = np.asarray(ndi.sum(sil, lab, range(1, k + 1)))
sil = np.isin(lab, 1 + np.where(tailles > MIN_COMP)[0])
ys, xs = np.where(sil)
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
Hb, Wb = y1 - y0 + 1, x1 - x0 + 1
assert BX0 <= x0 and x1 < BX1 and BY0 <= y0 and y1 < BY1, \
    f"la bête ({x0}-{x1}, {y0}-{y1}) SORT de la boîte gardée — élargir BX/BY"
print(f"[1] silhouette {int(sil.sum())} px, {int((tailles > MIN_COMP).sum())} "
      f"pièce(s), boîte {Wb}×{Hb} (ratio {Wb / Hb:.3f}), x {x0}-{x1}, y {y0}-{y1}")

# ── LA GÉOMÉTRIE DE POSE ────────────────────────────────────────────────────
s = (BETE_H_PT * PT) / Hb                        # échelle source → card
cy0, cy1 = max(BY0, y0 - MARGE), min(BY1, y1 + MARGE + 1)
cx0, cx1 = max(BX0, x0 - MARGE), min(BX1, x1 + MARGE + 1)
cw, ch = int(round((cx1 - cx0) * s)), int(round((cy1 - cy0) * s))
pieds = PIEDS_PT * PT
py = int(round(pieds - Hb * s - (y0 - cy0) * s))   # haut du crop sur le canevas
px = int(round(CW / 2 - ((x0 + x1) / 2 - cx0) * s))
print(f"[2] échelle {s:.4f} → bête {Wb * s:.0f}×{Hb * s:.0f} px "
      f"({Wb * s / PT:.0f}×{Hb * s / PT:.0f} pt), crop {cw}×{ch} posé en ({px},{py}), "
      f"pieds à {pieds:.0f} px = {PIEDS_PT} pt, tête à "
      f"{(pieds - Hb * s) / PT:.0f} pt")


def poser(arr, mode):
    """`arr` est déjà découpé dans la boîte gardée : coordonnées relatives."""
    a = arr[cy0 - BY0:cy1 - BY0, cx0 - BX0:cx1 - BX0]
    im = Image.fromarray(a).resize((cw, ch), Image.LANCZOS)
    can = np.zeros((CH, CW) if mode == "L" else (CH, CW, 3), np.uint8)
    a = np.asarray(im)
    yy0, xx0 = max(0, py), max(0, px)
    yy1, xx1 = min(CH, py + ch), min(CW, px + cw)
    can[yy0:yy1, xx0:xx1] = a[yy0 - py:yy1 - py, xx0 - px:xx1 - px]
    return can


sil_card = poser((sil * 255).astype(np.uint8)[BY0:BY1, BX0:BX1], "L") > 127
dur = ndi.binary_dilation(sil_card, iterations=DILAT_DUR)     # dehors = noir forcé
# ÉRODÉ, jamais dilaté (voir l'en-tête) : le mur mord la frange noire.
serre = ndi.binary_erosion(sil_card, iterations=EROSION_MASQUE)
# LA POCHE D'OMBRE : plus de plume gaussienne étroite — un smoothstep sur la
# DISTANCE à la silhouette. 0 dans la bête (le trou), 1 à OMBRE_PT d'elle.
d_sil = ndi.distance_transform_edt(~serre) / (OMBRE_PT * PT)
t = np.clip(d_sil, 0, 1)
alpha_mur = t * t * (3 - 2 * t)
masque_inverse = (255 * alpha_mur).round().astype(np.uint8)

# ── LES 240 IMAGES VERS L'ENCODEUR (posées à la volée) ─────────────────────
ordre = list(range(n_src)) + list(range(n_src - 2, 0, -1))   # 0..120, 119..1
print(f"[3] palindrome : {len(ordre)} images = {len(ordre) / 24:.2f} s à 24 img/s")

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
fuites = 0
cache = {}
for i in ordre:
    if i not in cache:
        can = poser(gard[i], "RGB")
        fuites += int((can.max(axis=2)[~dur] > 0).sum())
        can[~dur] = 0                              # le fond est NOIR EXACT, garanti
        cache[i] = can
    enc.stdin.write(cache[i].tobytes())
enc.stdin.close()
enc.wait()
print(f"[3] pixels non noirs hors bête AVANT forçage : {fuites}")
print(f"[4] {OUT_MP4} : {os.path.getsize(OUT_MP4) / 1e6:.2f} Mo")

# ── LE MASQUE — EN RGBA, L'INFORMATION DANS L'ALPHA ────────────────────────
os.makedirs(OUT_SET, exist_ok=True)
rgba = np.zeros((CH, CW, 4), np.uint8)
rgba[..., :3] = 255
rgba[..., 3] = masque_inverse
Image.fromarray(rgba).save(f"{OUT_SET}/stop-bat-masque.png")
with open(f"{OUT_SET}/Contents.json", "w") as f:
    json.dump({"images": [{"filename": "stop-bat-masque.png", "idiom": "universal"}],
               "info": {"author": "xcode", "version": 1}}, f, indent=2)
print(f"[5] masque RGBA {CW}×{CH} : trou (alpha 0) "
      f"{int((masque_inverse == 0).sum())} px, plume "
      f"{int(((masque_inverse > 0) & (masque_inverse < 255)).sum())} px")

# ── LE PORTILLON — on re-lit le FICHIER livré, pas la mémoire ──────────────
prb = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames",
                      "-show_entries", "stream=width,height,nb_read_frames,pix_fmt,"
                      "color_space,color_range,r_frame_rate",
                      "-of", "default=noprint_wrappers=1", OUT_MP4],
                     capture_output=True, text=True).stdout.strip().replace("\n", " · ")
print(f"[6] ffprobe : {prb}")
idx = [0, 40, 80, 118, 119, 120, 121, 122, 160, 200, 238, 239]
gardees, deltas, pire_fond, p99 = {}, [], 0, 0.0
prev = premiere = None
enveloppe = np.zeros((CH, CW), bool)
morsure = 0
opaque = masque_inverse > 250
n_out = 0
for fr in images(OUT_MP4, (CW, CH)):
    luma = fr.max(axis=2)
    dehors = luma[~dur]
    pire_fond = max(pire_fond, int(dehors.max()))
    p99 = max(p99, float(np.percentile(dehors, 99.9)))
    bete = luma > 12
    enveloppe |= bete
    morsure += int((bete & opaque).sum())
    if prev is not None:
        deltas.append(float(np.abs(fr.astype(int) - prev.astype(int)).mean()))
    else:
        premiere = fr.copy()
    prev = fr.copy()
    if n_out in idx:
        gardees[n_out] = fr.copy()
    n_out += 1
couture = float(np.abs(premiere.astype(int) - prev.astype(int)).mean())
yb, xb = np.where(enveloppe)
print(f"[6] {n_out} images ; fond hors bête : max {pire_fond}/255, p99,9 {p99:.1f} "
      f"(≤ 2 attendu) ; écart image à image : médiane {np.median(deltas):.3f}, "
      f"max {max(deltas):.3f} ; couture f0↔f{n_out - 1} : {couture:.3f}")
print(f"[6] bête décodée : {xb.max() - xb.min()}×{yb.max() - yb.min()} px, "
      f"pieds à {yb.max() / PT:.0f} pt, tête à {yb.min() / PT:.0f} pt")
print(f"[7] MORSURE (bête claire sous mur opaque) : {morsure} px sur "
      f"{n_out} images — ici on ACCEPTE quelques px : le mur doit mordre la "
      f"frange noire plutôt que laisser un halo")
dist = ndi.distance_transform_edt(~enveloppe)
bord = (masque_inverse < 128) & ~ndi.binary_erosion(masque_inverse < 128)
d = dist[bord]
print(f"[7] AURA (bête → bord du trou) : médiane {np.median(d) / PT:.2f} pt, "
      f"max {d.max() / PT:.2f} pt — VISÉE : ~0, c'est elle qu'on voyait")

# ── LA PLANCHE-CONTACT du raccord ──────────────────────────────────────────
os.makedirs(VIG, exist_ok=True)
tw, th = 270, int(270 * CH / CW)
planche = Image.new("RGB", (tw * 4, th * 3), (30, 30, 30))
for k2, i in enumerate(idx):
    if i in gardees:
        planche.paste(Image.fromarray(gardees[i]).resize((tw, th), Image.LANCZOS),
                      ((k2 % 4) * tw, (k2 // 4) * th))
planche.save(f"{VIG}/stop-bat-planche.png")
print(f"[8] planche → {VIG}/stop-bat-planche.png")
