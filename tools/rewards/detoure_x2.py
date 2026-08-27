#!/usr/bin/env python3
# LES DEUX ASSETS DU VARIANT « ×2 » (X1, plan PLAN-VARIANT-X2.md §1.4).
#
# 1. LA PASTILLE `PAILETE_FOIS_2.png` (1254², fond noir) : la recette
#    ANALYTIQUE des pastilles TOP — bbox au seuil 3, squircle r = 0,22 ·
#    côté, fondu 1,5 px sur le seul contour, sonde alpha > 0,98.
#
# 2. LE STICKER `STICKER_FOIS_2.png` (1254², fond BLANC 253-255, liseré
#    die-cut blanc, OMBRE PORTÉE douce) — un cas NOUVEAU, mesuré : le
#    liseré (237-254) n'est PAS séparable du fond par la luminance, mais
#    l'ombre qui le longe tombe à 153-233 JUSTE CONTRE lui (un bord net,
#    profil relevé aux lignes 560/700/850). Recette « cœur + couronne » :
#    le cœur rouge et son biseau (min-canal < 238), une ZONE de 48 px
#    autour, et dans la zone on ne garde que le BLANC (≥ 236) — l'ombre
#    reste dehors ; trous remplis, plus grande composante, fondu 1,5 px.
import numpy as np
from PIL import Image
from scipy import ndimage
import os, json

ASSETS = os.path.join(os.path.dirname(__file__), "..", "..",
                      "Woop", "Assets.xcassets")
CTRL = os.environ.get("CTRL_DIR", "/tmp")


def ecrire(nom, rgb, a8, taille=None):
    ys, xs = np.where(a8 > 0)
    y0, y1 = max(0, ys.min() - 2), min(rgb.shape[0], ys.max() + 3)
    x0, x1 = max(0, xs.min() - 2), min(rgb.shape[1], xs.max() + 3)
    out = Image.fromarray(np.dstack([rgb, a8])[y0:y1, x0:x1], "RGBA")
    if taille:
        # carré centré, puis ré-échantillonné à la taille de la famille
        w, h = out.size
        c = max(w, h)
        carre = Image.new("RGBA", (c, c), (0, 0, 0, 0))
        carre.paste(out, ((c - w) // 2, (c - h) // 2))
        out = carre.resize((taille, taille), Image.LANCZOS)
    d = os.path.join(ASSETS, f"{nom}.imageset")
    os.makedirs(d, exist_ok=True)
    out.save(os.path.join(d, f"{nom}.png"))
    json.dump({"images": [
        {"filename": f"{nom}.png", "idiom": "universal", "scale": "1x"},
        {"idiom": "universal", "scale": "2x"},
        {"idiom": "universal", "scale": "3x"}],
        "info": {"author": "xcode", "version": 1}},
        open(os.path.join(d, "Contents.json"), "w"), indent=2)
    return out


def sonde(alpha, m):
    dist = ndimage.distance_transform_edt(m)
    moyen = alpha[dist > 3].mean()
    assert moyen > 0.98, f"alpha moyen {moyen:.3f} — recette à revoir"
    return moyen


# ---------- 1. la pastille ----------
im = Image.open(os.path.expanduser("~/Desktop/PAILETE_FOIS_2.png")).convert("RGB")
rgb = np.array(im)
lum = rgb.max(axis=2).astype(float)
m = ndimage.binary_fill_holes(lum > 3)
lab, n = ndimage.label(m)
if n > 1:
    t = ndimage.sum(m, lab, range(1, n + 1))
    m = lab == (1 + int(np.argmax(t)))
ys0, xs0 = np.where(m)
by0, by1, bx0, bx1 = ys0.min(), ys0.max(), xs0.min(), xs0.max()
r = 0.22 * min(by1 - by0 + 1, bx1 - bx0 + 1)
yy, xx = np.mgrid[0:rgb.shape[0], 0:rgb.shape[1]].astype(float)
dx = np.maximum(np.maximum(bx0 + r - xx, xx - (bx1 - r)), 0)
dy = np.maximum(np.maximum(by0 + r - yy, yy - (by1 - r)), 0)
m = np.sqrt(dx * dx + dy * dy) <= r
dist = ndimage.distance_transform_edt(m)
alpha = np.clip(dist / 1.5, 0, 1)
moy = sonde(alpha, m)
p = ecrire("sticker-pastille-fois2", rgb, (alpha * 255).astype(np.uint8))
print(f"sticker-pastille-fois2 : {p.size[0]}x{p.size[1]}  alpha_sujet={moy:.3f}  bbox {bx1-bx0+1}x{by1-by0+1} r={r:.0f}")

# ---------- 2. le sticker ----------
im = Image.open(os.path.expanduser("~/Desktop/STICKER_FOIS_2.png")).convert("RGB")
rgb = np.array(im)
mn = rgb.min(axis=2).astype(int)
coeur = mn < 238
coeur = ndimage.binary_fill_holes(
    ndimage.binary_closing(coeur, structure=np.ones((5, 5))))
lab, n = ndimage.label(coeur)
t = ndimage.sum(coeur, lab, range(1, n + 1))
coeur = lab == (1 + int(np.argmax(t)))
zone = ndimage.binary_dilation(coeur, iterations=48)
blanc = zone & (mn >= 236)
m = ndimage.binary_fill_holes(coeur | blanc)
m = ndimage.binary_closing(m, structure=np.ones((3, 3)))
lab, n = ndimage.label(m)
t = ndimage.sum(m, lab, range(1, n + 1))
m = lab == (1 + int(np.argmax(t)))
# la largeur RÉELLE de la couronne obtenue (contrôle de la mesure)
dist_c = ndimage.distance_transform_edt(~coeur)
couronne = m & ~coeur
print(f"  couronne : largeur médiane {np.median(dist_c[couronne]):.0f} px, max {dist_c[couronne].max():.0f} px ; "
      f"gris (<236) dans la couronne : {(mn[couronne] < 236).mean()*100:.1f} %")
dist = ndimage.distance_transform_edt(m)
alpha = np.clip(dist / 1.5, 0, 1)
moy = sonde(alpha, m)
s = ecrire("sticker-fois2", rgb, (alpha * 255).astype(np.uint8), taille=768)
print(f"sticker-fois2 : {s.size[0]}x{s.size[1]} (famille jambes)  alpha_sujet={moy:.3f}")

# ---------- la planche de contrôle ----------
fond = Image.new("RGBA", (900, 460), (30, 23, 21, 255))
# la pastille dans son squircle, deux tailles
for i, cote in enumerate((226, 113)):
    pp = p.resize((cote, cote), Image.LANCZOS)
    fond.alpha_composite(pp, (30 + i * 250, 230 - cote // 2))
# le sticker seul, et sur une case 33×51 (3x) à côté d'une flamme
fond.alpha_composite(s.resize((200, 200), Image.LANCZOS), (520, 30))
case = Image.new("RGBA", (99, 153), (40, 40, 40, 255))
fl = os.path.join(ASSETS, "sticker-flamme.imageset")
fl_png = [f for f in os.listdir(fl) if f.endswith(".png")][0]
flamme = Image.open(os.path.join(fl, fl_png)).convert("RGBA").resize((34, 34), Image.LANCZOS)
case.alpha_composite(flamme, (57, 45))
case.alpha_composite(s.resize((36, 36), Image.LANCZOS), (12, 82))
fond.alpha_composite(case.resize((198, 306), Image.NEAREST), (700, 120))
fond.save(os.path.join(CTRL, "x2_planche.png"))
print("planche :", os.path.join(CTRL, "x2_planche.png"))
