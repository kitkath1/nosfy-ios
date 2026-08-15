#!/usr/bin/env python3
"""CollapsedGlassControlMap — extraite de la référence de Kathryn.

Pipeline (le brief, point 14) : crop exact de la carte → normalisation →
suppression de la basse fréquence du corps → isolation des highlights
blancs (R), des hotspots spéculaires (G), de la chaleur (B) et d'une
rugosité (A) → pack RGBA. La map porte la GÉOGRAPHIE des accidents ; la
physique du shader garde le comportement. Les zones de CONTENU (textes,
médaillon, poignée, gouttes, jauge) sont neutralisées : la map ne doit
porter que l'empreinte optique du VERRE.

Usage : controlmap.py <reference-card.png> <sortie.png>
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

src = Image.open(sys.argv[1]).convert("RGB")
rgb = np.asarray(src, dtype=np.float32) / 255.0
lum = rgb.mean(axis=2)
h, w = lum.shape

# ---- le masque du contenu (fractions de carte, mêmes zones que l'atlas)
mask = np.zeros_like(lum, dtype=bool)
def kill(fx0, fy0, fx1, fy1):
    mask[int(fy0*h):int(fy1*h), int(fx0*w):int(fx1*w)] = True
kill(.03, .28, .30, .98)   # médaillon
kill(.28, .30, .66, .78)   # Séries + Touchez
kill(.66, .32, .95, .60)   # gouttes
kill(.38, .02, .64, .18)   # poignée (élargie : elle fuyait dans le scatter)
kill(.02, .06, .26, .24)   # Training
kill(.26, .76, .97, .92)   # jauge
# LES TRANCHES SONT AU MODÈLE ANALYTIQUE (enveloppes mesurées pixel par
# pixel) : la map n'a pas le droit d'y doubler la lumière — bord mort.
B = 10
mask[:B, :] = True; mask[-B:, :] = True
mask[:, :B] = True; mask[:, -B:] = True

# ---- suppression de la basse fréquence : ce qui reste = les accidents
low = ndimage.gaussian_filter(lum, 11)
hp = lum - low

# R — scatter blanc / nappes laiteuses : passe-haut positif, échelle moyenne
scatter = ndimage.gaussian_filter(np.clip(hp, 0, None), 2.5)
scatter = np.clip(scatter / 0.06, 0, 1)

# G — hotspots spéculaires : les pics fins et forts
spec = np.clip(hp - 0.10, 0, None)
spec = np.clip(spec / 0.25, 0, 1)

# B — influence chaude : chromie R-B au-dessus du voile, échelle moyenne
warm = rgb[:, :, 0] - rgb[:, :, 2]
warm = warm - ndimage.gaussian_filter(warm, 15)
warm = ndimage.gaussian_filter(np.clip(warm, 0, None), 2.0)
warm = np.clip(warm / 0.10, 0, 1)

# A — rugosité : l'écart-type local du passe-haut (la microtexture)
rough = ndimage.generic_filter(hp, np.std, size=5)
rough = np.clip(rough / 0.04, 0, 1)

for c in (scatter, spec, warm, rough):
    c[mask] = 0.0

out = np.stack([scatter, spec, warm, rough], axis=2)
out = (out * 255).astype(np.uint8)
# ≥1536 px de large (le brief) — bicubique : la map porte des STRUCTURES,
# le grain sub-pixel reste procédural côté shader.
img = Image.fromarray(out, "RGBA").resize(
    (1536, int(1536 * h / w)), Image.BICUBIC)
img.save(sys.argv[2])
print("map :", img.size, "->", sys.argv[2])
