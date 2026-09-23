# -*- coding: utf-8 -*-
"""LA BRAISE HYPER-RÉALISTE — toutes les nuances, du blanc au noir.

Ce que la version d'avant n'avait pas, et qui fait la différence entre
« un contour orange » et « du papier qui brûle » :
  1. UNE RAMPE DE CORPS NOIR à douze paliers — blanc bleuté, blanc, jaune
     paille, jaune d'or, ambre, orange, orange rouge, vermillon, rouge de
     braise, braise sombre, brun de cendre, noir ;
  2. LES LANGUES : le feu MONTE. La couche de flamme est étirée vers le
     haut avec une traînée décroissante — sans ça, c'est un contour ;
  3. LA LUMIÈRE PORTÉE : le papier NON BRÛLÉ est ÉCLAIRÉ par le feu. C'est
     le détail qui manquait le plus — une vraie flamme éclaire ce qu'elle
     n'a pas encore mangé ;
  4. LA TURBULENCE : deux bruits à échelles différentes modulent la
     flamme, un lent pour les masses, un fin pour le crépitement ;
  5. LA FUMÉE : un voile gris qui monte au-dessus du front ;
  6. LA CENDRE : des flocons sombres qui se détachent et montent.
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import map_coordinates, gaussian_filter, shift as nshift

def charge(p, w=600):
    im = Image.open(p).convert("RGB"); im.thumbnail((w, w*4), Image.LANCZOS); return im

def bruit(h, w, octaves=8, graine=0, persist=0.56):
    r = np.random.default_rng(graine)
    out = np.zeros((h, w), np.float32); amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = 2 ** (o + 2)
        g = r.random((n, max(2, int(n*w/h)))).astype(np.float32)
        g = np.array(Image.fromarray((g*255).astype(np.uint8))
                     .resize((w, h), Image.BICUBIC), np.float32)/255.0
        out += g*amp; tot += amp; amp *= persist
    out /= tot
    return (out-out.min())/(out.max()-out.min())

def champ(h, w, foyer):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xs-foyer[0]*w)/w)**2 + ((ys-foyer[1]*h)/h)**2); d /= d.max()
    return 0.56*d + 0.44*bruit(h, w, 8, 3)

# ── LA RAMPE DE CORPS NOIR, douze paliers. Du plus chaud au plus froid.
RAMPE = [(0.0000, (1.00, 1.00, 0.99)),   # blanc, presque bleuté — le plus chaud
         (0.0035, (1.00, 0.99, 0.90)),   # blanc chaud
         (0.0070, (1.00, 0.95, 0.68)),   # jaune paille
         (0.0110, (1.00, 0.86, 0.40)),   # jaune d'or
         (0.0160, (1.00, 0.74, 0.24)),   # ambre
         (0.0220, (1.00, 0.58, 0.13)),   # orange
         (0.0290, (0.99, 0.42, 0.07)),   # orange rouge
         (0.0370, (0.92, 0.26, 0.04)),   # vermillon
         (0.0460, (0.74, 0.14, 0.02)),   # rouge de braise
         (0.0570, (0.44, 0.06, 0.01)),   # braise sombre
         (0.0700, (0.16, 0.03, 0.01)),   # brun de cendre
         (0.0870, (0.00, 0.00, 0.00))]

def rampe(d):
    h, w = d.shape
    out = np.zeros((h, w, 3), np.float32)
    for (d0, c0), (d1, c1) in zip(RAMPE, RAMPE[1:]):
        m = (d >= d0) & (d < d1)
        if not m.any(): continue
        t = np.where(m, (d-d0)/(d1-d0), 0)[..., None]
        out += m[..., None]*(np.array(c0, np.float32)*(1-t) + np.array(c1, np.float32)*t)
    return out

def langues(couche, n=26, pas=2.0, decr=0.90):
    """LE FEU MONTE : une traînée vers le haut, de plus en plus faible.
    Marche pour une couche grise (h,w) comme pour une couleur (h,w,3)."""
    dec = (-pas, 0) if couche.ndim == 2 else (-pas, 0, 0)
    out = couche.copy(); a = 1.0
    for k in range(1, n):
        a *= decr
        d = tuple(v*k for v in dec)
        out = np.maximum(out, nshift(couche, d, order=1, mode="constant") * a)
    return out

def deforme(a, masque, force):
    if force <= 0: return a
    gy, gx = np.gradient(gaussian_filter(masque.astype(np.float32), 8))
    h, w = masque.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    ys = np.clip(ys+gy*force, 0, h-1); xs = np.clip(xs+gx*force, 0, w-1)
    o = np.empty_like(a)
    for c in range(3): o[..., c] = map_coordinates(a[..., c], [ys, xs], order=1, mode="nearest")
    return o

def brule(im, p, flou, deform, foyer=(0.5, 0.86)):
    a = np.asarray(im, np.float32)/255.0
    h, w = a.shape[:2]
    f       = champ(h, w, foyer)
    masses  = bruit(h, w, 4, 21, 0.62)          # la turbulence lente
    crepite = bruit(h, w, 9, 41, 0.50)          # le crépitement fin
    seuil   = p*(f.max()+0.10)
    brule_  = f < seuil
    d       = np.abs(f - seuil)

    a = deforme(a, brule_, deform)
    if flou > 0:
        a = np.asarray(Image.fromarray((a*255).astype(np.uint8))
                       .filter(ImageFilter.GaussianBlur(flou)), np.float32)/255.0

    # LA FLAMME : la rampe, modulée par les deux turbulences, puis ÉTIRÉE
    # vers le haut. C'est l'étirement qui fait les langues.
    intens = np.clip(1.0 - d/0.087, 0, 1) ** 1.25
    intens *= (0.42 + 0.38*masses + 0.30*crepite)
    intens = langues(intens)
    feu = rampe(d) * intens[..., None]
    feu = np.maximum(feu, langues(rampe(d) * np.clip(1-d/0.02, 0, 1)[..., None] * 0.9, 12, 1.6, .86))

    # LA LUMIÈRE PORTÉE — le papier pas encore mangé est ÉCLAIRÉ par le feu.
    porte = gaussian_filter(intens, 26) * 1.5 + gaussian_filter(intens, 70) * 1.1
    a = np.clip(a * (1 + porte[..., None] * np.array([1.0, 0.52, 0.18], np.float32)), 0, 1)

    # LE BRÛLÉ, et sa cendre grenue
    a *= (1.0 - brule_[..., None]*0.995)
    char = np.clip(1.0 - (seuil - f)/0.15, 0, 1)*brule_
    a = np.clip(a + (char*crepite*0.16)[..., None]*np.array([0.46,0.28,0.21], np.float32), 0, 1)

    a = np.clip(a + feu, 0, 1)

    # LA FUMÉE au-dessus du front, et les FLOCONS de cendre qui montent
    fumee = langues(np.clip(1-d/0.05,0,1)*masses, 40, 3.0, 0.945)
    a = np.clip(a + gaussian_filter(fumee, 11)[..., None]*0.075
                  * np.array([0.72,0.66,0.62], np.float32), 0, 1)
    r = np.random.default_rng(7)
    flocons = np.zeros((h, w), np.float32)
    bande = np.argwhere((f > seuil-0.018) & (f < seuil+0.004))
    if len(bande):
        for y, x in bande[r.integers(0, len(bande), min(110, len(bande)))]:
            m = r.integers(8, 70); yy = int(np.clip(y-m,0,h-1)); xx = int(np.clip(x+r.integers(-10,11),0,w-1))
            flocons[yy, xx] = 1.0 - m/78.0
    flocons = gaussian_filter(flocons, 1.0)
    a = np.clip(a + flocons[..., None]*np.array([1.0,0.62,0.24], np.float32), 0, 1)
    return Image.fromarray((np.clip(a,0,1)*255).astype(np.uint8))

if __name__ == "__main__":
    im = charge("reel/popup2.png")
    for n, (p, fl, df) in {"h1":(0.10,0.6,4.0), "h2":(0.30,2.0,11.0),
                           "h3":(0.55,4.0,17.0), "h4":(0.80,6.5,21.0)}.items():
        brule(im, p, fl, df).save("pub11/im/%s.jpg" % n, quality=94)
    print("ok")
