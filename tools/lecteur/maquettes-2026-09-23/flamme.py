# -*- coding: utf-8 -*-
"""LA FLAMME NOIRE — rendue sur les vraies captures, pour juger la direction.
Ce n'est PAS le code de l'app : c'est le calcul qui montre à quoi ça ressemble.
Le principe tient en une image : l'écran qu'on quitte BRÛLE depuis le point
touché. Le front de flamme porte un cheveu incandescent (blanc au cœur, braise
qui meurt derrière), le brûlé est noir absolu, et le verre se déforme au bord.
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import map_coordinates, gaussian_filter

RNG = np.random.default_rng(7)

def charge(p, w=560):
    im = Image.open(p).convert("RGB")
    im.thumbnail((w, w * 4), Image.LANCZOS)
    return im

def bruit(h, w, octaves=5):
    """Bruit fractal : des octaves de grain lissé, sommées."""
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = 2 ** (o + 2)
        g = RNG.random((n, int(n * w / h) + 1)).astype(np.float32)
        g = np.array(Image.fromarray((g * 255).astype(np.uint8))
                     .resize((w, h), Image.BICUBIC), np.float32) / 255.0
        out += g * amp; tot += amp; amp *= 0.55
    out /= tot
    return (out - out.min()) / (out.max() - out.min())

def champ(h, w, foyer=(0.5, 0.86)):
    """Le champ de combustion : le bruit, biaisé par la distance au POINT TOUCHÉ.
    C'est ce biais qui donne sa CAUSE à la flamme — elle part du pouce."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = foyer[0] * w, foyer[1] * h
    d = np.sqrt(((xs - cx) / w) ** 2 + ((ys - cy) / h) ** 2)
    d /= d.max()
    return 0.62 * d + 0.38 * bruit(h, w)

def deforme(arr, masque, force):
    """Le verre chauffe et gondole au bord du front. Déplacement le long du
    gradient du masque : la matière fuit la flamme."""
    if force <= 0: return arr
    gy, gx = np.gradient(gaussian_filter(masque.astype(np.float32), 9))
    h, w = masque.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    ys = np.clip(ys + gy * force, 0, h - 1)
    xs = np.clip(xs + gx * force, 0, w - 1)
    out = np.empty_like(arr)
    for c in range(3):
        out[..., c] = map_coordinates(arr[..., c], [ys, xs], order=1, mode="nearest")
    return out

def brule(im, p, flou, deform):
    """p = avancement de la combustion, 0 rien brûlé, 1 tout noir."""
    a = np.asarray(im, np.float32) / 255.0
    h, w = a.shape[:2]
    f = champ(h, w)
    seuil = p * (f.max() + 0.10)
    brule_ = f < seuil
    # le front : une bande étroite juste devant le brûlé
    bord = np.clip(1.0 - np.abs(f - seuil) / 0.019, 0, 1)
    coeur = np.clip(1.0 - np.abs(f - seuil) / 0.006, 0, 1)   # le cheveu blanc

    a = deforme(a, brule_, deform)
    if flou > 0:
        a = np.asarray(Image.fromarray((a * 255).astype(np.uint8))
                       .filter(ImageFilter.GaussianBlur(flou)), np.float32) / 255.0
    a *= (1.0 - brule_[..., None] * 0.995)                   # le brûlé = noir
    # LA BRAISE QUI MEURT derrière le front, puis LE BLANC au cœur.
    braise = np.stack([bord * 0.72, bord * 0.17, bord * 0.03], -1)
    a = np.clip(a + braise, 0, 1)
    a = np.clip(a + coeur[..., None] * 1.0, 0, 1)
    return Image.fromarray((a * 255).astype(np.uint8))

def arrive(im, flou, echelle, voile):
    """Le lecteur arrive de l'avant, encore trouble."""
    w, h = im.size
    r = im.resize((int(w * echelle), int(h * echelle)), Image.LANCZOS)
    x, y = (r.size[0] - w) // 2, (r.size[1] - h) // 2
    r = r.crop((x, y, x + w, y + h)).filter(ImageFilter.GaussianBlur(flou))
    return Image.blend(r, Image.new("RGB", (w, h), (0, 0, 0)), voile)

quitte = charge("reel/popup2.png")
vient  = charge("go-carres.png")

etapes = [
    ("f1", quitte,                              "0 ms"),
    ("f2", brule(quitte, 0.16, 1.0,  6.0),      "90 ms"),
    ("f3", brule(quitte, 0.42, 3.0, 14.0),      "190 ms"),
    ("f4", brule(quitte, 0.72, 6.0, 20.0),      "290 ms"),
    ("f5", brule(quitte, 0.95, 9.0, 22.0),      "380 ms"),
    ("f6", arrive(vient, 20.0, 1.06, 0.66),     "470 ms"),
    ("f7", arrive(vient,  5.0, 1.015, 0.20),    "560 ms"),
    ("f8", vient,                               "640 ms"),
]
for n, im, _ in etapes:
    im.save("pub7/im/%s.jpg" % n, quality=88)
print("écrit :", [n for n, _, _ in etapes])
