# -*- coding: utf-8 -*-
"""LA COMÈTE QUI DESSINE — abstrait, très fin, jamais du néon.

UN POINT de lumière se déplace et LAISSE UN TRAIT. Le dessin se construit
sous les yeux, comme une main qui trace ; quand il se referme, l'écran est
prêt. C'est le CHARGEMENT de l'app, réutilisable partout.

Lois tenues :
  · la brillance vient de la BLANCHEUR, jamais de l'épaisseur — trait 1 px,
    halo court, NOIR ABSOLU entre ;
  · blanc et argent seuls ;
  · la lumière a une cause et un bord : c'est un POINT, il a une position ;
  · rien ne balaie : le point TRACE, il ne traverse pas.
"""
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

S = 2                       # on trace en double, on réduit : anticrénelage
H, W = 1200 * S, 560 * S
CX, CY = W / 2, H / 2

def chemin(t, forme):
    a = t * 2 * np.pi
    if forme == "cercle":
        r = 150 * S
        return CX + r * np.cos(a - np.pi/2), CY + r * np.sin(a - np.pi/2)
    if forme == "spirale":
        r = (24 + 140 * t) * S
        return CX + r * np.cos(a * 2.7), CY + r * np.sin(a * 2.7)
    if forme == "lissajous":
        return CX + 168*S * np.sin(3*a), CY + 168*S * np.sin(2*a + 1.05)
    if forme == "trois":
        k = min(2, int(t * 3)); u = (t * 3) % 1
        b = k * 2*np.pi/3 + u * 2.15 - 1.07
        r = (112 + 36 * k) * S
        return CX + r * np.cos(b), CY + r * np.sin(b)
    raise ValueError(forme)

def pose(buf, x, y, v):
    """Un point, réparti sur ses quatre voisins : le trait reste FIN et lisse."""
    xi, yi = int(np.floor(x)), int(np.floor(y))
    fx, fy = x - xi, y - yi
    for dx, dy, w in ((0,0,(1-fx)*(1-fy)), (1,0,fx*(1-fy)),
                      (0,1,(1-fx)*fy),     (1,1,fx*fy)):
        px, py = xi+dx, yi+dy
        if 0 <= px < W and 0 <= py < H:
            buf[py, px] = max(buf[py, px], v * w * 4)

def trace(forme, p, pas=5200, graine=3):
    rng = np.random.default_rng(graine)
    trait = np.zeros((H, W), np.float32)     # le dessin déjà posé — ARGENT
    tete  = np.zeros((H, W), np.float32)     # la comète — BLANC
    part  = np.zeros((H, W), np.float32)     # les particules

    n = max(2, int(pas * p))
    QUEUE = int(pas * 0.085)                 # la queue de la comète
    for i in range(n):
        x, y = chemin(i / pas, forme)
        d = n - i
        if d > QUEUE:
            pose(trait, x, y, 0.42)          # le trait qui reste
        else:
            u = 1 - d / QUEUE                # 0 au bout de la queue, 1 à la tête
            pose(trait, x, y, 0.42)
            pose(tete,  x, y, u ** 2.2)
        if d < pas * 0.34 and rng.random() < 0.055:
            for _ in range(3):
                px = x + rng.normal(0, 10*S); py = y + rng.normal(0, 10*S) - 6*S
                if 0 <= px < W-1 and 0 <= py < H-1:
                    pose(part, px, py, (1 - d/(pas*0.30)) * rng.uniform(0.35, 1.0))

    # LE NOYAU DE LA COMÈTE — le point le plus blanc de l'écran, 1 px,
    # posé à la dernière position. C'est lui qui fait lire « comète » et
    # pas « cercle qui se dessine ».
    if n > 1:
        nx, ny = chemin((n - 1) / pas, forme)
        noyau = np.zeros((H, W), np.float32)
        pose(noyau, nx, ny, 1.0)
    else:
        noyau = np.zeros((H, W), np.float32)

    def reduit(b):
        return np.array(Image.fromarray((np.clip(b,0,1)*255).astype(np.uint8))
                        .resize((W//S, H//S), Image.LANCZOS), np.float32)/255.0
    t_, h_, p_, n_ = reduit(trait), reduit(tete), reduit(part), reduit(noyau)

    # LE HALO : court. 2,2 px pour le trait, 5 px pour la tête. Jamais plus.
    img = (t_ * 0.58 + gaussian_filter(t_, 2.2) * 0.22
           + h_ * 1.35 + gaussian_filter(h_, 3.0) * 1.20
           + n_ * 3.2 + gaussian_filter(n_, 1.6) * 5.0
           + gaussian_filter(n_, 6.0) * 4.2
           + p_ * 1.1 + gaussian_filter(p_, 2.4) * 0.8)
    img = np.clip(img, 0, 1)
    rgb = np.stack([img, np.clip(img*0.995,0,1), np.clip(img*1.05,0,1)], -1)
    return Image.fromarray((np.clip(rgb,0,1)*255).astype(np.uint8))

for forme in ("cercle", "spirale", "lissajous", "trois"):
    for k, p in enumerate([0.22, 0.55, 0.85, 1.0], 1):
        trace(forme, p).save("pub10/im/%s%d.jpg" % (forme, k), quality=93)
print("ok")
