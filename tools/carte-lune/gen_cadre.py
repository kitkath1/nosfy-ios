#!/usr/bin/env python3
"""Extraction du CADRE FIXE de carte-lune-1.png.

Le cadre = toute la carte SAUF l'aire où vit l'art. La fenêtre mesurée
(x 0,118..0,881 · y 0,083..0,891, mesure.py) est le rectangle CONTRAT :
c'est là que l'app glissera l'art généré, sous le cadre. Mais le cadre
possède du mobilier DANS ce rectangle — un liseré intérieur en octogone
(verticales x≈162 et x≈923, chanfreins aux quatre coins) et ses gouttières
noires. Le trou est donc l'octogone intérieur, resserré de 2 px (aucune
couture quand l'art passe dessous), lisière adoucie d'un feather gaussien.

Le MÉDAILLON (plaque + disque du logo, cotes de gen_layers.py verbatim)
appartient au cadre : plaque gardée jusqu'à mi-rampe (le liseré diagonal
vit à sd≈0,008), disque gardé à cœur de rampe (r 0,110) dilaté de 2 px.
Les chanfreins TR/BR/BL sont ajustés sur les cœurs orange du liseré
(résidus < 1,5 px), reculés de 7 px côté art (trait + halo + 2 px).

Sorties : Nosfy/Media/carte-cadre.png (RGBA, taille de la carte)
        + ~/Downloads/woop-carte-lune/cadre-debug.png (cadre sur magenta).
"""
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "Nosfy" / "Media" / "carte-lune-1.png"
DST = ROOT / "Nosfy" / "Media" / "carte-cadre.png"
DBG = Path.home() / "Downloads" / "woop-carte-lune" / "cadre-debug.png"

img = np.asarray(Image.open(SRC).convert("RGBA"))
H, W, _ = img.shape

# La fenêtre contrat, en pixels — l'app pose l'art généré dans CE rectangle.
x0, x1 = int(0.118 * W), int(0.881 * W)
y0, y1 = int(0.083 * H), int(0.891 * H)
print(f"fenêtre : x={x0} y={y0} w={x1 - x0} h={y1 - y0}")

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
xs, ys = xx / W, yy / H

def sstep(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)

# Le médaillon (gen_layers.py, verbatim) : plaque en biseau + disque du logo.
ax, ay, bx, by = 0.118, 0.205, 0.315, 0.056
sd = (bx - ax) * (ys - ay) - (by - ay) * (xs - ax)
rpx = np.sqrt((xx - 0.200 * W) ** 2 + (yy - 0.135 * H) ** 2)

# Le trou : l'octogone intérieur, chaque bord reculé de 2 px côté art.
# Verticales : cœurs de liseré x 160..164 et 921..925, art à 166/919.
# Chanfreins : droites ajustées sur les cœurs orange, -7 px côté art.
hole = ((xx >= 169) & (xx <= 916) & (yy >= y0 + 2) & (yy <= y1 - 2)
        & (sd > 0.011)                       # plaque du médaillon
        & (rpx > 0.110 * W + 2)              # disque du logo, dilaté
        & (xx < 1.0340 * yy + 738.2)         # chanfrein haut-droit
        & (xx < -0.9784 * yy + 2122.6)       # chanfrein bas-droit
        & (xx > 1.0169 * yy - 1089.1))       # chanfrein bas-gauche

# Le feather : un flou gaussien doux sur le masque entier.
m8 = Image.fromarray(((1 - hole) * 255).astype(np.uint8))
alpha = np.asarray(m8.filter(ImageFilter.GaussianBlur(2)))

out = img.copy()
out[..., 3] = np.minimum(out[..., 3], alpha)
Image.fromarray(out).save(DST)
print(f"OK {DST} ({W}x{H})")

# Planche de contrôle : le cadre posé sur magenta uni — l'octogone doit
# être entièrement magenta, médaillon, liserés et chanfreins intacts.
DBG.parent.mkdir(parents=True, exist_ok=True)
board = Image.new("RGBA", (W, H), (255, 0, 255, 255))
board.alpha_composite(Image.fromarray(out))
board.convert("RGB").save(DBG)
print(f"OK {DBG}")
