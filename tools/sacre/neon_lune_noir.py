#!/usr/bin/env python3
"""LE NÉON BLANC DE LA LUNE — sur la face du sachet NOIR (18-09).

Verdict de Kathryn sur son iPhone : « on voit pas assez la lune au milieu —
néon blanc ». La lune de la face noire est un EMBOSS (un relief dans le dessin,
sans lumière) ; celle du sachet jaune est un néon orange DESSINÉ dans l'émissive.
On donne donc à la noire ce que la jaune a : un fil de lumière — blanc.

Le tracé vient de l'emboss lui-même : dans le panneau FACE de l'atlas couleur
noir, l'écart au fond (médiane 24·24·24) dessine le double contour du
croissant (seuil 30, ~1 500 px, boîte y 699→1042 · x 224→387 dans le panneau
retourné). On le blanchit, on lui donne un cœur net et un halo doux, et on
l'AJOUTE à l'émissive noire existante (le liseré irisé reste tel quel).

Entrées : Nosfy/Media/booster-noir-color.png, Nosfy/Media/booster-noir-emiss.png
Sortie  : Nosfy/Media/booster-noir-emiss.png (l'ancienne copiée dans
          tools/sacre/noir/booster-noir-emiss-avant-neon.png), preview-face-emiss-neon.png
Intensité côté matière inchangée (emission.intensity 0,6, comme le jaune).
"""
import os, shutil
import numpy as np
from PIL import Image, ImageFilter

R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MEDIA = os.path.join(R, "Nosfy", "Media"); SORTIE = os.path.join(R, "tools", "sacre", "noir")
FACE = (722, 57, 1318, 1990)
COEUR = (236, 240, 255)      # blanc à peine bleuté : le foil irisé rend toute couleur qu'on lui donne
SEUIL, HALO_PX, HALO_GAIN = 22, 8, 0.5

color = Image.open(os.path.join(MEDIA, "booster-noir-color.png")).convert("RGB")
emiss_path = os.path.join(MEDIA, "booster-noir-emiss.png")
emiss = Image.open(emiss_path).convert("RGB")
avant = os.path.join(SORTIE, "booster-noir-emiss-avant-neon.png")
if not os.path.exists(avant): shutil.copy(emiss_path, avant)

face = np.asarray(color.crop(FACE)).astype(float)          # non retourné : mêmes coordonnées que l'atlas
zone = (slice(FACE[3]-FACE[1]-1050, FACE[3]-FACE[1]-640), slice(150, 460))   # la lune, en coordonnées atlas (retourné)
z = face[zone]; fond = np.median(z, axis=(0, 1)); d = np.abs(z - fond).max(axis=2)
masque = (d > SEUIL).astype(np.uint8) * 255
m = Image.fromarray(masque)
m = m.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MedianFilter(7)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(0.8))  # refermé (dilaté, médian), puis aminci : un tube continu de ~5 px
halo = m.filter(ImageFilter.GaussianBlur(HALO_PX))
coeur = np.asarray(m).astype(float) / 255.0; h = np.asarray(halo).astype(float) / 255.0
neon = np.clip(coeur + HALO_GAIN * h, 0, 1)
rgb = np.zeros(z.shape); 
for c in range(3): rgb[..., c] = neon * COEUR[c]

e = np.asarray(emiss).astype(float)
panel = e[FACE[1]:FACE[3], FACE[0]:FACE[2]]
panel[zone] = np.clip(panel[zone] + rgb, 0, 255)             # ADDITIF : le liseré reste
e[FACE[1]:FACE[3], FACE[0]:FACE[2]] = panel
Image.fromarray(e.astype(np.uint8)).save(emiss_path)
prev = Image.fromarray(e[FACE[1]:FACE[3], FACE[0]:FACE[2]].astype(np.uint8)).transpose(Image.FLIP_TOP_BOTTOM)
prev.resize((310, 1005)).save(os.path.join(SORTIE, "preview-face-emiss-neon.png"))
print("néon posé :", int((coeur > 0).sum()), "px de fil, halo", HALO_PX, "px → booster-noir-emiss.png")
