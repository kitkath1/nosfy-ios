# -*- coding: utf-8 -*-
"""LA VRAIE BRAISE — ce qui manque à la version d'hier, rendu pour juger.

Hier : un seuil, une bande orange, du noir. Ça se lit comme un néon découpé.
Ce qu'une braise a VRAIMENT, et que chaque ligne ici ajoute :
  1. une RAMPE DE TEMPÉRATURE — blanc incandescent, jaune, orange, rouge
     sombre, puis noir. Une braise n'a jamais une seule couleur ;
  2. du CHARBON derrière le front : le papier ne devient pas noir d'un coup,
     il passe par un gris-brun grenu qui s'éteint ;
  3. du GRAIN dans la flamme elle-même : le feu a une texture, un dégradé
     lisse fait une lampe ;
  4. des ÉTINCELLES qui se détachent du front et montent ;
  5. un front DÉCHIQUETÉ à plusieurs échelles (8 octaves, pas 5).
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import map_coordinates, gaussian_filter

RNG = np.random.default_rng(11)

def charge(p, w=560):
    im = Image.open(p).convert("RGB"); im.thumbnail((w, w*4), Image.LANCZOS); return im

def bruit(h, w, octaves=8, graine=0):
    r = np.random.default_rng(graine)
    out = np.zeros((h, w), np.float32); amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = 2 ** (o + 2)
        g = r.random((n, max(2, int(n*w/h)))).astype(np.float32)
        g = np.array(Image.fromarray((g*255).astype(np.uint8))
                     .resize((w, h), Image.BICUBIC), np.float32)/255.0
        out += g*amp; tot += amp; amp *= 0.56
    out /= tot
    return (out-out.min())/(out.max()-out.min())

def champ(h, w, foyer):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xs-foyer[0]*w)/w)**2 + ((ys-foyer[1]*h)/h)**2); d /= d.max()
    return 0.58*d + 0.42*bruit(h, w, 8, 3)

def deforme(a, masque, force):
    if force <= 0: return a
    gy, gx = np.gradient(gaussian_filter(masque.astype(np.float32), 8))
    h, w = masque.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    ys = np.clip(ys+gy*force, 0, h-1); xs = np.clip(xs+gx*force, 0, w-1)
    o = np.empty_like(a)
    for c in range(3): o[..., c] = map_coordinates(a[..., c], [ys, xs], order=1, mode="nearest")
    return o

# LA RAMPE DE TEMPÉRATURE : distance au front → couleur.
# Blanc au cœur (1900 K), puis jaune, orange, rouge sombre, puis plus rien.
RAMPE = [(0.000, (1.00, 0.98, 0.94)),   # blanc incandescent
         (0.006, (1.00, 0.86, 0.52)),   # jaune
         (0.014, (1.00, 0.52, 0.14)),   # orange
         (0.026, (0.78, 0.16, 0.03)),   # rouge de braise
         (0.042, (0.22, 0.03, 0.01)),   # braise qui meurt
         (0.062, (0.00, 0.00, 0.00))]

def feu(d, grain):
    """d = distance signée au front. Rend la couleur de la flamme."""
    h, w = d.shape
    out = np.zeros((h, w, 3), np.float32)
    for (d0, c0), (d1, c1) in zip(RAMPE, RAMPE[1:]):
        m = (d >= d0) & (d < d1)
        t = np.where(m, (d-d0)/(d1-d0), 0)[..., None]
        out += m[..., None]*(np.array(c0)*(1-t) + np.array(c1)*t)
    # LE GRAIN : le feu n'est pas lisse. Il module l'intensité, pas la teinte.
    return out * (0.55 + 0.45*grain)[..., None]

def etincelles(h, w, seuil, f, n=70, graine=5):
    """Des points chauds qui se détachent du front et MONTENT."""
    r = np.random.default_rng(graine)
    out = np.zeros((h, w), np.float32)
    bande = np.argwhere((f > seuil-0.02) & (f < seuil+0.005))
    if len(bande) == 0: return out
    pick = bande[r.integers(0, len(bande), min(n, len(bande)))]
    for y, x in pick:
        monte = r.integers(6, 46)
        yy = int(np.clip(y-monte, 0, h-1)); xx = int(np.clip(x+r.integers(-7, 8), 0, w-1))
        out[yy, xx] = 1.0 - monte/52.0
    return gaussian_filter(out, 1.1)

def brule(im, p, flou, deform, foyer=(0.5, 0.86)):
    a = np.asarray(im, np.float32)/255.0
    h, w = a.shape[:2]
    f = champ(h, w, foyer)
    grain = bruit(h, w, 7, 21)
    seuil = p*(f.max()+0.10)
    brule_ = f < seuil
    d = np.abs(f - seuil)

    a = deforme(a, brule_, deform)
    if flou > 0:
        a = np.asarray(Image.fromarray((a*255).astype(np.uint8))
                       .filter(ImageFilter.GaussianBlur(flou)), np.float32)/255.0
    a *= (1.0 - brule_[..., None]*0.995)

    # LE CHARBON : derrière le front, une cendre grenue qui s'éteint.
    char = np.clip(1.0 - (seuil - f)/0.13, 0, 1)*brule_
    a = np.clip(a + (char*grain*0.13)[..., None]*np.array([0.42, 0.26, 0.20], np.float32), 0, 1)

    a = np.clip(a + feu(d, grain), 0, 1)
    e = etincelles(h, w, seuil, f)
    a = np.clip(a + e[..., None]*np.array([1.0, 0.72, 0.36], np.float32), 0, 1)
    return Image.fromarray((a*255).astype(np.uint8))

quitte = charge("reel/popup2.png")
for n, p, fl, df in [("v2", 0.16, 1.0, 6.0), ("v3", 0.42, 3.0, 14.0),
                     ("v4", 0.72, 6.0, 20.0)]:
    brule(quitte, p, fl, df).save("pub9/im/%s.jpg" % n, quality=92)
print("ok")
