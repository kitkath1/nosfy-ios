# -*- coding: utf-8 -*-
"""LE PAPIER QUI BRÛLE — poussé au maximum.

Ce que la version précédente n'avait pas encore, et qui sépare « une belle
flamme » d'« une photo de papier qui brûle » :

  A. LA ROUSSISSURE — le papier BRUNIT avant de s'enflammer. Une bande de
     brun qui court devant le front. Sans elle, le papier passe du blanc
     au feu sans transition : c'est le signe le plus sûr du faux.
  B. LES BRAISES QUI SURVIVENT — sur le charbon, des points orange
     continuent de rougeoyer derrière le front, et s'éteignent lentement.
  C. LE BOURRELET — le papier se RECROQUEVILLE vers le feu : juste
     derrière le front, un liseré plus clair (la tranche qui se soulève)
     puis une ombre.
  D. LES CRAQUELURES — le charbon se fend en un réseau de fibres, un ton
     au-dessus du noir.
  E. LA HALATION — l'œil et l'objectif bavent autour des très hautes
     lumières. Un halo très large et très faible sur le seul blanc.
  F. LE TREMBLEMENT DE CHALEUR — au-dessus du front, l'air réfracte et
     l'image ondule.
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import map_coordinates, gaussian_filter, shift as nshift
from braise2 import charge, bruit, champ, rampe, langues, deforme

def brule(im, p, flou, deform, foyer=(0.5, 0.86)):
    a = np.asarray(im, np.float32)/255.0
    h, w = a.shape[:2]
    f       = champ(h, w, foyer)
    masses  = bruit(h, w, 4, 21, 0.62)
    crepite = bruit(h, w, 9, 41, 0.50)
    fibres  = bruit(h, w, 10, 77, 0.44)
    seuil   = p*(f.max()+0.10)
    brule_  = f < seuil
    d       = np.abs(f - seuil)
    devant  = f >= seuil                      # pas encore brûlé
    derr    = seuil - f                       # profondeur dans le charbon

    a = deforme(a, brule_, deform)

    # F. LE TREMBLEMENT DE CHALEUR, juste au-dessus du front
    chaud = gaussian_filter(np.clip(1-d/0.05, 0, 1), 6)
    gy, gx = np.gradient(gaussian_filter(crepite, 3))
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    amp = chaud * 5.0
    o = np.empty_like(a)
    for c in range(3):
        o[..., c] = map_coordinates(a[..., c],
                                    [np.clip(ys+gy*amp*60,0,h-1), np.clip(xs+gx*amp*60,0,w-1)],
                                    order=1, mode="nearest")
    a = o
    if flou > 0:
        a = np.asarray(Image.fromarray((a*255).astype(np.uint8))
                       .filter(ImageFilter.GaussianBlur(flou)), np.float32)/255.0

    # A. LA ROUSSISSURE — le papier brunit AVANT de brûler.
    rouss = np.clip(1 - (f - seuil)/0.055, 0, 1) * devant
    rouss = rouss ** 1.6 * (0.72 + 0.28*crepite)
    brun = np.array([0.30, 0.16, 0.07], np.float32)
    a = a*(1 - rouss[..., None]) + (a*0.30 + brun*0.70)*rouss[..., None]

    # LA FLAMME : rampe × turbulences, étirée vers le haut.
    intens = np.clip(1.0 - d/0.087, 0, 1) ** 1.25
    intens *= (0.42 + 0.38*masses + 0.30*crepite)
    intens = langues(intens)
    feu = rampe(d) * intens[..., None]
    coeur = np.clip(1-d/0.02, 0, 1)
    feu = np.maximum(feu, langues(rampe(d)*coeur[..., None]*0.9, 12, 1.6, .86))

    # LA LUMIÈRE PORTÉE sur ce qui n'a pas encore brûlé.
    porte = gaussian_filter(intens, 26)*1.5 + gaussian_filter(intens, 70)*1.1
    a = np.clip(a * (1 + porte[..., None]*np.array([1.0,0.52,0.18], np.float32)), 0, 1)

    # LE BRÛLÉ
    a *= (1.0 - brule_[..., None]*0.995)

    # C. LE BOURRELET : la tranche qui se soulève, puis son ombre.
    lip   = np.clip(1 - np.abs(derr-0.004)/0.004, 0, 1) * brule_
    ombre = np.clip(1 - np.abs(derr-0.016)/0.011, 0, 1) * brule_
    a = np.clip(a + (lip*0.20)[..., None]*np.array([0.60,0.36,0.24], np.float32), 0, 1)
    a *= (1 - (ombre*0.55)[..., None])

    # D. LES CRAQUELURES du charbon
    crete = 1 - np.abs(2*fibres - 1)
    craq = np.clip((crete-0.86)/0.14, 0, 1) * np.clip(1-derr/0.20, 0, 1) * brule_
    a = np.clip(a + (craq*0.20)[..., None]*np.array([0.55,0.30,0.16], np.float32), 0, 1)

    # cendre grenue
    char = np.clip(1.0 - derr/0.15, 0, 1)*brule_
    a = np.clip(a + (char*crepite*0.14)[..., None]*np.array([0.46,0.28,0.21], np.float32), 0, 1)

    # B. LES BRAISES QUI SURVIVENT sur le charbon
    r = np.random.default_rng(13)
    grumeaux = (bruit(h, w, 7, 99, 0.52) > 0.68)
    vie = np.clip(1 - derr/0.075, 0, 1) ** 2.1
    braises = grumeaux * vie * brule_ * (0.35 + 0.65*crepite)
    a = np.clip(a + braises[..., None]*np.array([0.95,0.30,0.06], np.float32)*0.55, 0, 1)
    a = np.clip(a + gaussian_filter(braises, 4)[..., None]
                  *np.array([0.85,0.26,0.05], np.float32)*0.28, 0, 1)

    a = np.clip(a + feu, 0, 1)

    # E. LA HALATION sur le seul blanc
    blanc = np.clip(a.max(-1) - 0.80, 0, 1)/0.20
    a = np.clip(a + gaussian_filter(blanc, 34)[..., None]
                  *np.array([1.0,0.70,0.42], np.float32)*0.42
                  + gaussian_filter(blanc, 95)[..., None]
                  *np.array([1.0,0.55,0.26], np.float32)*0.26, 0, 1)

    # la fumée et les flocons
    fumee = langues(np.clip(1-d/0.05,0,1)*masses, 40, 3.0, 0.945)
    a = np.clip(a + gaussian_filter(fumee, 11)[..., None]*0.075
                  *np.array([0.72,0.66,0.62], np.float32), 0, 1)
    flocons = np.zeros((h, w), np.float32)
    bande = np.argwhere((f > seuil-0.018) & (f < seuil+0.004))
    if len(bande):
        for y, x in bande[r.integers(0, len(bande), min(130, len(bande)))]:
            m = r.integers(8, 80); yy = int(np.clip(y-m,0,h-1)); xx = int(np.clip(x+r.integers(-12,13),0,w-1))
            flocons[yy, xx] = 1.0 - m/88.0
    flocons = gaussian_filter(flocons, 1.0)
    a = np.clip(a + flocons[..., None]*np.array([1.0,0.62,0.24], np.float32), 0, 1)
    return Image.fromarray((np.clip(a,0,1)*255).astype(np.uint8))

if __name__ == "__main__":
    im = charge("reel/popup2.png")
    for n, (p, fl, df) in {"r1":(0.10,0.6,4.0), "r2":(0.30,2.0,11.0),
                           "r3":(0.55,4.0,17.0), "r4":(0.80,6.5,21.0)}.items():
        brule(im, p, fl, df).save("pub12/im/%s.jpg" % n, quality=95)
    print("ok")
