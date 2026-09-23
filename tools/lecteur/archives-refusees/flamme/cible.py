# -*- coding: utf-8 -*-
"""LA CIBLE — ce que la flamme doit atteindre. ×20.

Ce que le shader d'aujourd'hui n'a PAS, et qui le fait lire « cheap » :

  1. LE DÉFORMATION DE DOMAINE (domain warping). On n'échantillonne pas le
     bruit à `uv`, mais à `uv + vecteur(uv)`, deux fois de suite. C'est CE
     calcul qui donne les volutes, les léchages, les enroulements — la
     structure que le feu a et qu'un simple seuil sur du bruit n'a jamais.
  2. LE TEMPS. Le champ DÉRIVE vers le haut et évolue. Un feu qui avance
     sans bouger se lit comme une texture qu'on révèle ; un feu qui
     ondule se lit comme du feu.
  3. LE FEU QUI TOUCHE LE CONTENU : roussissure réelle sur l'image,
     lumière portée, halation, tremblement de chaleur.
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import map_coordinates, gaussian_filter, shift as nshift
from braise2 import charge, bruit, rampe, langues

def echant(champ, x, y):
    """Échantillonnage bilinéaire d'un champ, coordonnées en pixels."""
    h, w = champ.shape
    return map_coordinates(champ, [np.clip(y, 0, h-1), np.clip(x, 0, w-1)],
                           order=1, mode="wrap")

def deforme_domaine(base, wx, wy, k1, k2, h, w):
    """LA DÉFORMATION DE DOMAINE, deux passes. C'est elle qui fait les
    volutes : on regarde le bruit à travers un bruit."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    x1 = xs + (wx - 0.5) * k1
    y1 = ys + (wy - 0.5) * k1
    q = echant(base, x1, y1)
    x2 = xs + (echant(wy, x1, y1) - 0.5) * k2 + (q - 0.5) * k2 * 0.6
    y2 = ys + (echant(wx, x1, y1) - 0.5) * k2 - k2 * 0.35   # le feu MONTE
    return echant(base, x2, y2)

def rendu(im, p, phase, foyer=(0.5, 0.88)):
    a = np.asarray(im, np.float32)/255.0
    h, w = a.shape[:2]

    base = bruit(h, w, 8, 3, 0.56)
    wx   = bruit(h, w, 4, 51, 0.60)
    wy   = bruit(h, w, 4, 52, 0.60)
    fin  = bruit(h, w, 9, 41, 0.50)
    # LE TEMPS : tout le champ DÉRIVE vers le haut, et les vecteurs de
    # déformation glissent, donc la forme du feu ÉVOLUE.
    d = int(phase * 130)
    base = nshift(base, (-d, 0), order=1, mode="wrap")
    wx   = nshift(wx,   (-d*1.7, d*0.4), order=1, mode="wrap")
    wy   = nshift(wy,   (-d*2.3, -d*0.3), order=1, mode="wrap")

    champ_b = deforme_domaine(base, wx, wy, 26.0, 16.0, h, w)

    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    dist = np.sqrt(((xs-foyer[0]*w)/w)**2 + ((ys-foyer[1]*h)/h)**2); dist /= dist.max()
    f = 0.56*dist + 0.44*champ_b
    seuil = p*(f.max()+0.10)
    brule = f < seuil
    dd = np.abs(f - seuil)
    derr = np.clip(seuil - f, 0, None)

    # LE TREMBLEMENT DE CHALEUR
    chaud = gaussian_filter(np.clip(1-dd/0.05, 0, 1), 6)
    gy, gx = np.gradient(gaussian_filter(fin, 3))
    o = np.empty_like(a)
    for c in range(3):
        o[..., c] = map_coordinates(a[..., c],
            [np.clip(ys+gy*chaud*330,0,h-1), np.clip(xs+gx*chaud*330,0,w-1)],
            order=1, mode="nearest")
    a = o

    # LA ROUSSISSURE
    rs = np.clip(1-(f-seuil)/0.05, 0, 1)*(f >= seuil)
    rs = rs**1.6*(0.72+0.28*fin)
    a = a*(1-rs[...,None]) + (a*0.28 + np.array([0.30,0.16,0.07],np.float32)*0.72)*rs[...,None]

    # LA FLAMME, avec les langues
    intens = np.clip(1-dd/0.062, 0, 1)**1.15 * (0.40+0.35*champ_b+0.32*fin)
    intens = langues(intens, 30, 1.8, 0.905)
    feu = rampe(dd*(0.087/0.062)) * intens[..., None]

    porte = gaussian_filter(intens, 24)*1.6 + gaussian_filter(intens, 72)*1.2
    a = np.clip(a*(1+porte[...,None]*np.array([1.0,0.52,0.18],np.float32)), 0, 1)
    a *= (1-brule[...,None]*0.995)

    char = np.clip(1-derr/0.15,0,1)*brule
    a = np.clip(a + (char*fin*0.14)[...,None]*np.array([0.46,0.28,0.21],np.float32), 0, 1)
    vie = np.clip(1-derr/0.07,0,1)**2.1
    br = (bruit(h,w,7,99,0.52) > 0.66)*vie*brule*(0.35+0.65*fin)
    a = np.clip(a + br[...,None]*np.array([0.95,0.30,0.06],np.float32)*0.6, 0, 1)
    lip = np.clip(1-np.abs(derr-0.004)/0.004,0,1)*brule
    a = np.clip(a + (lip*0.22)[...,None]*np.array([0.60,0.36,0.24],np.float32), 0, 1)
    a = np.clip(a + feu, 0, 1)

    blanc = np.clip(a.max(-1)-0.80, 0, 1)/0.20
    a = np.clip(a + gaussian_filter(blanc,32)[...,None]*np.array([1.0,0.70,0.42],np.float32)*0.44
                  + gaussian_filter(blanc,92)[...,None]*np.array([1.0,0.55,0.26],np.float32)*0.28, 0, 1)

    fum = langues(np.clip(1-dd/0.05,0,1)*champ_b, 44, 3.2, 0.95)
    a = np.clip(a + gaussian_filter(fum,12)[...,None]*0.08*np.array([0.72,0.66,0.62],np.float32), 0, 1)
    r = np.random.default_rng(int(phase*100)+7)
    fl = np.zeros((h,w), np.float32)
    bd = np.argwhere((f > seuil-0.016) & (f < seuil+0.004))
    if len(bd):
        for y,x in bd[r.integers(0,len(bd),min(140,len(bd)))]:
            mm = r.integers(8,88); yy=int(np.clip(y-mm,0,h-1)); xx=int(np.clip(x+r.integers(-13,14),0,w-1))
            fl[yy,xx] = 1-mm/96.0
    a = np.clip(a + gaussian_filter(fl,1.0)[...,None]*np.array([1.0,0.62,0.24],np.float32), 0, 1)
    return Image.fromarray((np.clip(a,0,1)*255).astype(np.uint8))

if __name__ == "__main__":
    im = charge("reel/popup2.png", 620)
    for n,(p,ph) in {"c1":(0.16,0.0),"c2":(0.34,0.35),"c3":(0.52,0.70),"c4":(0.74,1.0)}.items():
        rendu(im, p, ph).save("pub13/im/%s.jpg"%n, quality=95)
    # deux phases au MÊME avancement : c'est ça, « le feu vit »
    rendu(im, 0.40, 0.10).save("pub13/im/t1.jpg", quality=95)
    rendu(im, 0.40, 0.55).save("pub13/im/t2.jpg", quality=95)
    print("ok")
