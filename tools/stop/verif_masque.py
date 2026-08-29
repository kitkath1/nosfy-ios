#!/usr/bin/env python3
"""
verif_masque.py — LE MASQUE COUPE-T-IL LE MUR SANS MORDRE LA BÊTE ?

Le portillon de bake_stop.py prouve la vidéo (noir exact, couture, cotes).
Il ne prouve PAS la seule chose qui fait l'illusion : que le TROU du masque
entoure la bête sur les 240 images, avec de l'aura et jamais de morsure.

Trois mesures, sur les images du fichier LIVRÉ :
  A. MORSURE — un pixel de bête (clair) que le masque laisse OPAQUE (le mur
     le recouvrirait) : doit être ZÉRO.
  B. AURA — la distance du bord de la bête au bord du trou : c'est le noir
     dans lequel elle se pose.
  C. la planche de contrôle : la bête, le trou en rouge, et la composition
     réelle (mur gris + trou + vidéo) telle que SwiftUI la fera.
"""
import os, subprocess
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MP4 = f"{REPO}/Woop/Media/stop-bat-loop.mp4"
MASK = f"{REPO}/Woop/Assets.xcassets/stop-bat-masque.imageset/stop-bat-masque.png"
VIG = f"{REPO}/tools/stop/vignettes"
CW, CH = 1080, 1562
PT = CW / 332

# ⚠️ L'ALPHA, jamais la luminance : le masque est en RGBA blanc + alpha depuis
# la correction du 29-08 (`.mask` de SwiftUI lit l'alpha). Un `.convert("L")`
# rendrait 255 partout et cette sonde jurerait que tout va bien.
masque = np.asarray(Image.open(MASK).convert("RGBA"))[..., 3].astype(float) / 255.0
trou = masque < 0.5              # là où le mur est effacé
opaque = masque > 0.98           # là où le mur couvre à plein

p = subprocess.Popen(["ffmpeg", "-v", "error", "-i", MP4,
                      "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                     stdout=subprocess.PIPE)
morsure_max, morsure_tot, n = 0, 0, 0
enveloppe = np.zeros((CH, CW), bool)
frames = []
while True:
    b = p.stdout.read(CW * CH * 3)
    if len(b) < CW * CH * 3:
        break
    fr = np.frombuffer(b, np.uint8).reshape(CH, CW, 3)
    luma = fr.max(axis=2)
    # « de la bête » = franchement visible (au-dessus du bruit d'encodage)
    bete = luma > 12
    enveloppe |= bete
    m = int((bete & opaque).sum())
    morsure_max = max(morsure_max, m)
    morsure_tot += m
    if n in (0, 60, 120, 180):
        frames.append((n, fr.copy()))
    n += 1
p.wait()

print(f"[A] {n} images. MORSURE (bête claire sous mur opaque) : "
      f"max {morsure_max} px sur une image, total {morsure_tot} — attendu 0")

# B. l'aura : distance du bord de l'enveloppe au bord du trou.
dist_hors = ndi.distance_transform_edt(~enveloppe)   # px depuis la bête
bord_trou = trou & ~ndi.binary_erosion(trou)
d = dist_hors[bord_trou]
print(f"[B] AURA (bête → bord du trou) : min {d.min():.0f} px "
      f"({d.min() / PT:.1f} pt), médiane {np.median(d):.0f} px "
      f"({np.median(d) / PT:.1f} pt), max {d.max():.0f} px ({d.max() / PT:.1f} pt)")
deborde = int((enveloppe & ~trou).sum())
print(f"[B] bête HORS du trou : {deborde} px "
      f"({100 * deborde / max(1, enveloppe.sum()):.2f} % de l'enveloppe)")

# C. la planche : brut · trou en rouge · composition réelle
fond = np.zeros((CH, CW, 3), np.uint8)
stops = [(0.00, 0.012), (0.09, 0.062), (0.26, 0.125), (0.44, 0.098),
         (0.68, 0.045), (0.90, 0.010), (1.00, 0.0)]
ys = np.linspace(0, 1, CH)
val = np.interp(ys, [s[0] for s in stops], [s[1] for s in stops])
fond[:] = (val[:, None, None] * 255).astype(np.uint8)

vign = []
for idx, fr in frames:
    rouge = fr.copy()
    rouge[trou, 0] = np.minimum(255, rouge[trou, 0].astype(int) + 90)
    # LA COMPOSITION RÉELLE, à la lettre de ce que fait SwiftUI : le mur est
    # posé SUR la vidéo avec l'alpha du masque. Rien d'autre (pas de
    # `maximum` : ce n'était pas le rendu, c'était un vœu).
    a = masque[:, :, None]
    comp = (fond * a + fr * (1 - a)).round().astype(np.uint8)
    vign += [(f"f{idx}", fr), (f"f{idx} trou", rouge), (f"f{idx} composé", comp)]

tw = 300
th = int(tw * CH / CW)
planche = Image.new("RGB", (tw * 3, th * 4), (24, 24, 24))
for k, (_, im) in enumerate(vign):
    planche.paste(Image.fromarray(im).resize((tw, th), Image.LANCZOS),
                  ((k % 3) * tw, (k // 3) * th))
out = f"{VIG}/stop-verif-masque.png"
planche.save(out)
print(f"[C] planche (brut · trou · composé) → {out}")
