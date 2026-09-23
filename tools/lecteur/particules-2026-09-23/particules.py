# -*- coding: utf-8 -*-
"""L'OUVERTURE — l'écran se défait en MILLIERS DE PARTICULES.

Ce n'est plus un champ de bruit qu'on seuille : ce sont des POINTS, des
dizaines de milliers, chacun plus petit qu'un pixel. C'est leur
ACCUMULATION SOUS-PIXEL qui donne le grain fin — celui des rendus
three.js — impossible à obtenir avec du bruit.

Le principe :
  · chaque particule naît DANS l'écran, à l'endroit d'un pixel réel, et
    elle en emporte la luminosité ;
  · elle monte, portée par un champ de vitesse EN ROTATIONNEL (curl) —
    c'est lui qui fait les volutes, et il est divergence-nulle, donc les
    particules s'enroulent sans jamais s'entasser ;
  · elle refroidit en vieillissant : orange vif → rouge → braise → noir ;
  · elle est déposée en SPLAT BILINÉAIRE sur quatre pixels voisins. C'est
    ce dépôt fractionnaire qui la rend « inférieure à 0,6 px ».
  · l'écran, lui, s'efface là où ses pixels sont partis.
"""
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

def charge(p, w=520):
    im = Image.open(p).convert("RGB"); im.thumbnail((w, w*4), Image.LANCZOS); return im

def curl(h, w, graine=3, echelle=42.0):
    """UN CHAMP EN ROTATIONNEL : on dérive un potentiel bruité, puis on
    prend son rotationnel. Divergence nulle → les particules tournent au
    lieu de s'agglutiner. C'est ce qui fait les volutes."""
    r = np.random.default_rng(graine)
    p = r.random((int(h/echelle)+2, int(w/echelle)+2)).astype(np.float32)
    p = np.array(Image.fromarray((p*255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32)/255.0
    p = gaussian_filter(p, 9.0)
    gy, gx = np.gradient(p)
    return gy, -gx                       # (u, v) = (∂p/∂y, −∂p/∂x)

# la rampe des particules : du blanc chaud au noir, en passant par
# l'orange et le rouge de braise. Aucune autre couleur.
RAMPE = np.array([
    (1.00, 0.96, 0.88), (1.00, 0.78, 0.30), (1.00, 0.52, 0.10),
    (0.92, 0.28, 0.05), (0.62, 0.10, 0.02), (0.26, 0.03, 0.01),
    (0.06, 0.01, 0.00), (0.00, 0.00, 0.00)], np.float32)

def teinte(age):
    """age ∈ [0,1] → couleur, interpolée dans la rampe."""
    x = np.clip(age, 0, 1) * (len(RAMPE)-1)
    i = np.floor(x).astype(np.int32); f = (x - i)[:, None]
    i2 = np.minimum(i+1, len(RAMPE)-1)
    return RAMPE[i]*(1-f) + RAMPE[i2]*f

def splat(buf, x, y, col, poids):
    """DÉPÔT BILINÉAIRE : chaque particule se répartit sur ses quatre
    pixels voisins. C'est ça, « inférieur à 0,6 px » — elle n'occupe
    jamais un pixel entier."""
    h, w = buf.shape[:2]
    x0 = np.floor(x).astype(np.int32); y0 = np.floor(y).astype(np.int32)
    fx = (x - x0)[:, None]; fy = (y - y0)[:, None]
    for dx, dy, pw in ((0,0,(1-fx)*(1-fy)), (1,0,fx*(1-fy)),
                       (0,1,(1-fx)*fy),     (1,1,fx*fy)):
        px = np.clip(x0+dx, 0, w-1); py = np.clip(y0+dy, 0, h-1)
        np.add.at(buf, (py, px), col * pw * poids[:, None])

def rendu(im_av, im_ap, t, N=90000, graine=7):
    """t ∈ [0,1] : l'avancement de l'ouverture."""
    r = np.random.default_rng(graine)
    av = np.asarray(im_av, np.float32)/255.0
    ap = np.asarray(im_ap, np.float32)/255.0
    h, w = av.shape[:2]
    u, v = curl(h, w, graine)

    # LES PARTICULES naissent dans l'écran, réparties, et partent du BAS
    # d'abord : l'ouverture se propage vers le haut.
    px0 = r.random(N).astype(np.float32) * (w-2)
    py0 = r.random(N).astype(np.float32) * (h-2)
    # le retard de départ : plus on est haut, plus on part tard
    retard = (py0/h)                      # 0 en haut, 1 en bas
    naiss = np.clip(1.0 - retard, 0, 1) * 0.55 + r.random(N).astype(np.float32)*0.30
    age = np.clip((t - naiss) / 0.52, 0, 1.4)
    vivantes = (age > 0) & (age < 1.0)

    # la trajectoire : montée + rotationnel, intégrée en une fois
    d = age * 210.0
    ui = u[np.clip(py0.astype(int),0,h-1), np.clip(px0.astype(int),0,w-1)]
    vi = v[np.clip(py0.astype(int),0,h-1), np.clip(px0.astype(int),0,w-1)]
    x = px0 + ui * d * 72.0 + r.normal(0, 1.1, N) * d * 0.06
    y = py0 + vi * d * 72.0 - d * 0.62       # ça monte

    buf = np.zeros((h, w, 3), np.float32)
    m = vivantes & (x>0) & (x<w-2) & (y>0) & (y<h-2)
    if m.any():
        # chaque particule emporte la luminosité du pixel d'où elle vient
        lum = av[np.clip(py0[m].astype(int),0,h-1),
                 np.clip(px0[m].astype(int),0,w-1)].mean(-1)
        # ⚠️ ELLES SONT CHAUDES, PAS GRISES. Sans ce gain, le nuage se
        # lit comme de la poussière — le premier rendu, refusé.
        col = teinte(age[m]) * (0.55 + 0.75*lum)[:, None]
        # les plus jeunes sont les plus vives
        poids = np.clip(1.0 - age[m], 0, 1) ** 0.55 * 2.1
        splat(buf, x[m], y[m], col, poids)

    # L'ÉCRAN S'EFFACE là où ses pixels sont partis.
    partis = np.zeros((h, w), np.float32)
    dep = age > 0
    if dep.any():
        np.add.at(partis, (np.clip(py0[dep].astype(int),0,h-1),
                           np.clip(px0[dep].astype(int),0,w-1)), 1.0)
    partis = np.clip(gaussian_filter(partis, 2.2) * (h*w/N) * 2.6, 0, 1)
    reste = av * (1.0 - partis)[..., None]

    # l'écran suivant arrive derrière, à mesure
    arrive = np.clip((t-0.55)/0.45, 0, 1)
    fond = reste * (1-arrive) + ap * arrive * partis[..., None]

    # le halo : c'est lui qui fait « braise » plutôt que « grain ».
    out = np.clip(fond + buf*1.15 + gaussian_filter(buf, 2.4)*0.85
                       + gaussian_filter(buf, 9.0)*0.55
                       + gaussian_filter(buf, 30.0)*0.30, 0, 1)
    return Image.fromarray((out*255).astype(np.uint8))

if __name__ == "__main__":
    av = charge("reel/popup2.png")
    ap = charge("go-carres.png").resize(av.size, Image.LANCZOS)
    for i, t in enumerate([0.18, 0.38, 0.58, 0.80]):
        rendu(av, ap, t).save("pub18/im/p%d.jpg" % i, quality=96)
    print("ok")
