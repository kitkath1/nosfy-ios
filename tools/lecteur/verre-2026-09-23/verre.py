# -*- coding: utf-8 -*-
"""LE VERRE — l'écran est une dalle de verre fumé, et elle tourne.

La plus belle chose de cette app existe déjà : l'écran de connexion, ses
cubes de verre noir aux arêtes de lumière. C'est SA matière. On ne pose
donc aucun effet sur l'écran : **l'écran DEVIENT cette matière**.

Ce qu'il faut pour que du verre se lise comme du verre, et pas comme une
image inclinée :

  1. LA PERSPECTIVE VRAIE — projection à point de fuite, pas un
     cisaillement. Une carte « retournée » en 2D se voit tout de suite.
  2. FRESNEL — le verre est TRANSPARENT de face et MIROIR à angle rasant.
     C'est la loi physique qui fait « verre ». Sans elle, c'est du carton.
  3. LA RÉFRACTION — ce qui est derrière la dalle est DÉVIÉ, d'autant plus
     qu'on la regarde de biais.
  4. LA TRANCHE — une arête d'un pixel qui s'allume quand elle passe par
     la lumière. « La brillance vient de la blancheur, jamais de
     l'épaisseur. »
  5. LE SPÉCULAIRE QUI GLISSE — la lumière ne balaie pas l'écran : elle
     reste fixe, et c'est la DALLE qui tourne sous elle. La lumière a une
     cause.
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import map_coordinates, gaussian_filter

def charge(p, w=520):
    im = Image.open(p).convert("RGB"); im.thumbnail((w, w*4), Image.LANCZOS); return im

def projete(src, fond, angle, focale=2.3):
    """Rend la dalle tournée de `angle` (radians) autour de l'axe vertical."""
    h, w = fond.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    # repère centré, normalisé
    X = (xs - w/2) / (w/2)
    Y = (ys - h/2) / (h/2)

    ca, sa = np.cos(angle), np.sin(angle)
    # on cherche u,v sur la dalle : x_ecran = u·cos / (1 + u·sin/f)
    # → u = x / (cos - x·sin/f)
    den = ca - X * sa / focale
    u = X / np.where(np.abs(den) < 1e-3, 1e-3, den)
    prof = 1.0 + u * sa / focale            # la profondeur du point
    v = Y * prof

    dedans = (np.abs(u) <= 1.0) & (np.abs(v) <= 1.0)
    sx = np.clip((u + 1) * (w/2), 0, w-1)
    sy = np.clip((v + 1) * (h/2), 0, h-1)

    dalle = np.empty_like(fond)
    for c in range(3):
        dalle[..., c] = map_coordinates(src[..., c], [sy, sx], order=1, mode="nearest")

    # 2. FRESNEL : réflexion = (1-cos)^5, forte à angle rasant.
    cosv = np.abs(ca - X * sa / focale) / np.sqrt(1 + (X*sa/focale)**2)
    fres = np.clip(0.035 + 0.965 * (1 - np.clip(cosv, 0, 1)) ** 5, 0, 1)

    # 3. RÉFRACTION : le fond est dévié derrière la dalle.
    dev = (1 - cosv) * 26 * np.sign(sa if sa != 0 else 1)
    bx = np.clip(xs + dev * np.sign(X + 1e-6), 0, w-1); by = ys
    derriere = np.empty_like(fond)
    for c in range(3):
        derriere[..., c] = map_coordinates(fond[..., c], [by, bx], order=1, mode="nearest")

    out = np.where(dedans[..., None], dalle * (1 - 0.45*fres[..., None]), derriere)

    # 5. LE SPÉCULAIRE : une source FIXE, à gauche. C'est la dalle qui
    # tourne dessous, donc la tache glisse d'elle-même.
    lum = np.clip(1.0 - np.abs(u + 0.55 - 1.4*sa), 0, 1) ** 9
    out = np.clip(out + (lum * dedans * fres * 1.5)[..., None]
                      * np.array([1.0, 0.99, 0.97], np.float32), 0, 1)

    # 4. LA TRANCHE : l'arête, un cheveu blanc, d'autant plus vif que la
    # dalle est de biais.
    bord = np.clip(1 - np.abs(np.abs(u) - 1.0) / 0.012, 0, 1) * dedans
    bord = np.maximum(bord, np.clip(1 - np.abs(np.abs(v) - 1.0) / 0.012, 0, 1) * dedans)
    # ⚠️ LA TRANCHE S'ALLUME À LA PERPENDICULAIRE. C'est LE moment : la
    # dalle n'est plus qu'un trait, et ce trait est la seule lumière de
    # l'écran. « La brillance vient de la blancheur, jamais de l'épaisseur. »
    vif = 0.30 + 3.4 * abs(sa) ** 6 + 0.55 * abs(sa)
    out = np.clip(out + (bord * vif)[..., None] * np.array([1.0, 1.0, 0.99], np.float32), 0, 1)
    halo = gaussian_filter(bord * vif, 3.2)
    large = gaussian_filter(bord * vif, 16.0)
    out = np.clip(out + halo[..., None] * np.array([0.95, 0.95, 1.0], np.float32) * 0.50
                      + large[..., None] * np.array([0.80, 0.86, 1.0], np.float32) * 0.40, 0, 1)
    return np.clip(out, 0, 1)

if __name__ == "__main__":
    av = np.asarray(charge("reel/popup2.png"), np.float32)/255.0
    ap = np.asarray(charge("go-carres.png"), np.float32)/255.0
    ap = np.asarray(Image.fromarray((ap*255).astype(np.uint8))
                    .resize((av.shape[1], av.shape[0]), Image.LANCZOS), np.float32)/255.0
    noir = np.zeros_like(av)
    angles = [0.0, 0.42, 0.95, 1.30, 1.50, 1.556]  # jusqu'à la perpendiculaire
    for i, a in enumerate(angles):
        src = av
        Image.fromarray((projete(src, noir, a)*255).astype(np.uint8)).save("pub17/im/v%d.jpg"%i, quality=95)
    # le dos qui revient
    for i, a in enumerate([1.40, 0.95, 0.42, 0.0]):
        Image.fromarray((projete(ap, noir, -a)*255).astype(np.uint8)).save("pub17/im/w%d.jpg"%i, quality=95)
    print("ok")
