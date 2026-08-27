#!/usr/bin/env python3
# LE LISERÉ HOLO DE LA POCHETTE (page WIN, verdict « quand je bouge
# les boosters, leur bordure terne — là où c'est holo — s'allume ») :
# on extrait la FRISE IRISÉE du sticker par SATURATION — les reflets
# du plastique sont blancs (S≈0), la frise est colorée (S haut) — et
# on en fait un masque blanc à alpha, que SwiftUI colore d'un dégradé
# irisé pendant la prise. Dilaté de 2 px + flou 1 px : le trait doit
# LUIRE, pas dessiner un fil dur.
import numpy as np
from PIL import Image
from scipy import ndimage
import json

src = "Woop/Assets.xcassets/sticker-booster.imageset/sticker-booster.png"
im = Image.open(src).convert("RGBA")
rgba = np.array(im)
hsv = np.array(im.convert("RGB").convert("HSV")).astype(float) / 255
S, V, A = hsv[..., 1], hsv[..., 2], rgba[..., 3].astype(float) / 255

holo = (S > 0.22) & (V > 0.30) & (A > 0.5)
# les crans du haut/bas et le plastique n'ont pas de couleur — mais on
# s'assure de ne garder que la FRISE : composantes assez grandes.
lab, n = ndimage.label(ndimage.binary_dilation(holo, iterations=3))
tailles = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
garde = np.zeros_like(holo)
for k, taille in enumerate(tailles, start=1):
    if taille > 400:
        garde |= (lab == k)
holo &= garde
# LES SEGMENTS GRIS DE LA FRISE (mesuré : haut-droite, bas-droite) ne
# sont pas saturés — on ouvre un COULOIR de 14 px autour de la frise
# colorée et on y prend les pixels clairs : la frise se referme sans
# que les reflets du plastique (hors couloir) ne s'invitent.
couloir = ndimage.binary_dilation(holo, iterations=14)
holo |= couloir & (V > 0.42) & (A > 0.5)
holo = ndimage.binary_closing(holo, structure=np.ones((5, 5)))
m = ndimage.binary_dilation(holo, iterations=2).astype(float)
m = ndimage.gaussian_filter(m, 1.0)
alpha = np.clip(m, 0, 1) * A

a8 = (alpha * 255).astype(np.uint8)
out = np.dstack([np.full_like(a8, 255), np.full_like(a8, 255),
                 np.full_like(a8, 255), a8])
d = "Woop/Assets.xcassets/sticker-booster-holo.imageset"
import os; os.makedirs(d, exist_ok=True)
Image.fromarray(out).save(f"{d}/sticker-booster-holo.png")
json.dump({"images": [
    {"filename": "sticker-booster-holo.png", "idiom": "universal", "scale": "1x"},
    {"idiom": "universal", "scale": "2x"},
    {"idiom": "universal", "scale": "3x"}],
    "info": {"author": "xcode", "version": 1}},
    open(f"{d}/Contents.json", "w"), indent=2)
couv = (a8 > 40).mean() * 100
print(f"sticker-booster-holo : {out.shape[1]}x{out.shape[0]}  couverture {couv:.2f} %")
# une planche de contrôle : le masque en cyan sur le sticker
ctrl = rgba.copy().astype(float)
ctrl[..., 0] = ctrl[..., 0] * (1 - alpha) + 0 * alpha
ctrl[..., 1] = ctrl[..., 1] * (1 - alpha) + 255 * alpha
ctrl[..., 2] = ctrl[..., 2] * (1 - alpha) + 255 * alpha
Image.fromarray(ctrl.astype(np.uint8)).resize((397, 639)).save(
    "/private/tmp/claude-501/-Users-kathryn-Desktop-woochoper-ios/05782a0d-49e5-44d4-b3a9-b0491c7a39bf/scratchpad/holo_ctrl.png")
