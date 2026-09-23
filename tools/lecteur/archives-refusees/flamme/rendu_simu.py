# -*- coding: utf-8 -*-
"""Rendre la SIMULATION sur la vraie capture. Le carburant dit ce qui a
brûlé, la chaleur dit la température — et la température choisit la couleur
dans la rampe de corps noir."""
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, zoom
from braise2 import charge, rampe, bruit

carbs = np.load("simu_carb.npy"); chals = np.load("simu_chal.npy")

def rendu(im, k):
    a = np.asarray(im, np.float32)/255.0
    h, w = a.shape[:2]
    f = carbs.shape[1]/h, carbs.shape[2]/w
    carb = zoom(carbs[k], (h/carbs.shape[1], w/carbs.shape[2]), order=1)[:h,:w]
    chal = zoom(chals[k], (h/chals.shape[1], w/chals.shape[2]), order=1)[:h,:w]
    fin  = bruit(h, w, 9, 41, 0.50)

    brule = carb < 0.30
    # LA TEMPÉRATURE → la rampe. `chal` élevé = près du blanc.
    # ⚠️ LA FLAMME EST LÀ OÙ ÇA RÉAGIT, pas là où il reste de la chaleur :
    # sans ce masque, le charbon refroidi restait orange (premier réglage).
    T = np.clip(chal, 0, 1.3)/1.3
    T = T * np.clip((T-0.18)/0.22, 0, 1)
    d = (1.0 - np.clip(T*1.25,0,1)) * 0.087
    feu = rampe(d) * np.clip(T*1.6, 0, 1)[..., None]

    # la lumière portée
    porte = gaussian_filter(T, 22)*1.5 + gaussian_filter(T, 70)*1.1
    a = np.clip(a*(1+porte[...,None]*np.array([1.0,0.52,0.18],np.float32)), 0, 1)

    # la roussissure : le carburant entamé mais pas consommé
    rs = np.clip((1.0-carb)*1.5, 0, 1)*(~brule)
    a = a*(1-rs[...,None]) + (a*0.26+np.array([0.30,0.16,0.07],np.float32)*0.74)*rs[...,None]

    # l'exposition se ferme
    a *= 1.0/(1.0 + 16.0*float(T.mean()))
    a *= (1-brule[...,None]*0.995)

    # le charbon et ses braises
    char = brule*(0.35+0.65*fin)*np.clip(carb/0.30,0,1)
    a = np.clip(a + char[...,None]*np.array([0.30,0.17,0.12],np.float32)*0.30, 0, 1)
    br = brule*(fin>0.70)*np.clip(T*3.0,0,1)
    a = np.clip(a + br[...,None]*np.array([0.95,0.30,0.06],np.float32)*0.5, 0, 1)

    a = np.clip(a + feu, 0, 1)
    # les filaments : le gradient de température le plus vif
    gy, gx = np.gradient(gaussian_filter(T, 1.0))
    fil = np.clip(np.sqrt(gx*gx+gy*gy)*7.0, 0, 1)*np.clip(T*2.2,0,1)
    a = np.clip(a + fil[...,None]*np.array([1.0,0.97,0.92],np.float32)*0.55, 0, 1)
    # halation
    blanc = np.clip(a.max(-1)-0.82,0,1)/0.18
    a = np.clip(a + gaussian_filter(blanc,30)[...,None]*np.array([1.0,0.70,0.42],np.float32)*0.46
                  + gaussian_filter(blanc,94)[...,None]*np.array([1.0,0.55,0.26],np.float32)*0.30, 0, 1)
    return Image.fromarray((np.clip(a,0,1)*255).astype(np.uint8))

if __name__ == "__main__":
    im = charge("reel/popup2.png", 620)
    for k in range(len(carbs)):
        rendu(im, k).save("pub15/im/s%d.jpg" % k, quality=96)
    print("ok", len(carbs))
