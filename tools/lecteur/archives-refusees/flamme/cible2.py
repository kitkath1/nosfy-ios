# -*- coding: utf-8 -*-
"""LA CIBLE ×20 — ce qui manque encore.

La version d'avant avait la déformation de domaine et le temps. Elle reste
PLATE. Ce qui suit est ce qui sépare « une belle image de feu » d'une
photographie de combustion :

  A. LA PROFONDEUR. Une vraie flamme n'est pas une surface : c'est un
     VOLUME, fait de nappes qui se superposent, chacune à sa distance,
     sa phase et sa température. On en empile TROIS, en additif.
  B. LA POUSSÉE D'ARCHIMÈDE. Le feu monte, et il ACCÉLÈRE en montant :
     le bruit est étiré verticalement de plus en plus haut on va, et
     advecté plus vite. Une dérive uniforme fait un tapis roulant.
  C. LES FILAMENTS NETS. Les arêtes les plus chaudes d'un vrai feu sont
     RASOIR. Un flou partout donne une aquarelle.
  D. L'EXPOSITION QUI SE FERME. Une photo de feu est sombre autour :
     l'appareil expose pour la flamme. Plus le feu grandit, plus le reste
     de l'écran s'assombrit.
  E. LES POCHES DÉTACHÉES. Le feu lâche des îlots qui montent et meurent
     tout seuls, séparés du front.
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import map_coordinates, gaussian_filter, shift as nshift
from braise2 import charge, bruit, rampe, langues

def ech(c, x, y):
    h, w = c.shape
    return map_coordinates(c, [np.clip(y,0,h-1), np.clip(x,0,w-1)], order=1, mode="wrap")

def nappe(h, w, graine, phase, etire, k1, k2):
    """UNE NAPPE de flamme : bruit déformé deux fois, étiré vers le haut,
    et advecté de plus en plus vite avec la hauteur (poussée d'Archimède)."""
    base = bruit(h, w, 8, graine, 0.56)
    wx   = bruit(h, w, 4, graine + 31, 0.60)
    wy   = bruit(h, w, 4, graine + 32, 0.60)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)

    # B. L'ÉTIREMENT ET L'ACCÉLÉRATION : plus on est haut, plus le bruit est
    # tiré et plus il a dérivé. C'est ça, la poussée.
    haut = 1.0 - ys / h
    yv = ys * (1.0 - etire * haut) - phase * 150.0 * (0.5 + haut)

    x1 = xs + (ech(wx, xs, yv) - 0.5) * k1
    y1 = yv + (ech(wy, xs, yv) - 0.5) * k1
    q  = ech(base, x1, y1)
    x2 = xs + (ech(wy, x1, y1) - 0.5) * k2 + (q - 0.5) * k2 * 0.6
    y2 = yv + (ech(wx, x1, y1) - 0.5) * k2 - k2 * 0.4
    return ech(base, x2, y2)

def flamme(h, w, foyer, p, phase, graine, etire, k1, k2, larg, gain,
           nl=30, pl=1.7, dl=0.907):
    """Une nappe rendue : sa couleur et son intensité."""
    c = nappe(h, w, graine, phase, etire, k1, k2)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xs-foyer[0]*w)/w)**2 + ((ys-foyer[1]*h)/h)**2); d /= d.max()
    f = 0.56*d + 0.44*c
    s = p*(f.max()+0.10)
    dd = np.abs(f - s)
    i = np.clip(1 - dd/larg, 0, 1) ** 1.1
    i = langues(i * (0.45 + 0.55*c), nl, pl, dl)
    return rampe(dd*(0.087/larg)) * (i*gain)[..., None], f, s

def rendu(im, p, phase, foyer=(0.5, 0.90)):
    a = np.asarray(im, np.float32)/255.0
    h, w = a.shape[:2]
    fin = bruit(h, w, 9, 41, 0.50)

    # A. TROIS NAPPES : le fond (large, froide, lente), le corps, le devant
    # (fine, chaude, rapide). C'est l'empilement qui fait le VOLUME.
    fond,  _,  _  = flamme(h, w, foyer, p*0.96, phase*0.70, 3,  0.34, 34, 20, 0.085, 0.42, 34, 2.0, 0.915)
    corps, f,  s  = flamme(h, w, foyer, p,      phase,      7,  0.26, 26, 16, 0.058, 1.00, 22, 1.6, 0.885)
    # ⚠️ LA NAPPE DE DEVANT NE TRAÎNE PRESQUE PAS : elle est fine, et une
    # longue traînée sur une nappe fine fait des COLONNES verticales —
    # l'artefact vu au premier rendu.
    devant,_,  _  = flamme(h, w, foyer, p*1.04, phase*1.45, 13, 0.18, 18, 11, 0.034, 0.72, 9, 1.3, 0.80)

    brule = f < s
    dd = np.abs(f - s); derr = np.clip(s - f, 0, None)

    # tremblement de chaleur
    chaud = gaussian_filter(np.clip(1-dd/0.05,0,1), 6)
    gy, gx = np.gradient(gaussian_filter(fin, 3))
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    o = np.empty_like(a)
    for c in range(3):
        o[...,c] = map_coordinates(a[...,c],
            [np.clip(ys+gy*chaud*340,0,h-1), np.clip(xs+gx*chaud*340,0,w-1)], order=1, mode="nearest")
    a = o

    # roussissure
    rs = (np.clip(1-(f-s)/0.05,0,1)*(f>=s))**1.6*(0.72+0.28*fin)
    a = a*(1-rs[...,None]) + (a*0.26 + np.array([0.30,0.16,0.07],np.float32)*0.74)*rs[...,None]

    feu = np.clip(fond + corps + devant, 0, 2.2)

    # lumière portée
    inten = feu.max(-1)
    porte = gaussian_filter(inten, 24)*1.5 + gaussian_filter(inten, 74)*1.15
    a = np.clip(a*(1+porte[...,None]*np.array([1.0,0.52,0.18],np.float32)), 0, 1)

    # D. L'EXPOSITION SE FERME : plus le feu prend, plus le reste s'assombrit.
    expo = 1.0 / (1.0 + 2.4 * float(inten.mean()) * 9.0)
    a *= expo

    a *= (1-brule[...,None]*0.995)
    char = np.clip(1-derr/0.15,0,1)*brule
    a = np.clip(a + (char*fin*0.14)[...,None]*np.array([0.46,0.28,0.21],np.float32), 0, 1)
    vie = np.clip(1-derr/0.07,0,1)**2.1
    br = (bruit(h,w,7,99,0.52) > 0.66)*vie*brule*(0.35+0.65*fin)
    a = np.clip(a + br[...,None]*np.array([0.95,0.30,0.06],np.float32)*0.6, 0, 1)
    lip = np.clip(1-np.abs(derr-0.004)/0.004,0,1)*brule
    a = np.clip(a + (lip*0.22)[...,None]*np.array([0.60,0.36,0.24],np.float32), 0, 1)

    a = np.clip(a + feu, 0, 1)

    # C. LES FILAMENTS NETS : on REND au cœur une arête non floutée.
    fil = np.clip(1 - dd/0.006, 0, 1) ** 2.0
    a = np.clip(a + fil[...,None]*np.array([1.0,0.97,0.90],np.float32)*0.85, 0, 1)

    # halation
    blanc = np.clip(a.max(-1)-0.82,0,1)/0.18
    a = np.clip(a + gaussian_filter(blanc,30)[...,None]*np.array([1.0,0.70,0.42],np.float32)*0.46
                  + gaussian_filter(blanc,96)[...,None]*np.array([1.0,0.55,0.26],np.float32)*0.30, 0, 1)

    # E. LES POCHES DÉTACHÉES + les étincelles
    r = np.random.default_rng(int(phase*100)+7)
    poche = np.zeros((h,w), np.float32)
    bd = np.argwhere((f > s-0.02) & (f < s+0.006))
    if len(bd):
        for y,x in bd[r.integers(0,len(bd),min(26,len(bd)))]:
            mm = r.integers(30,170); yy=int(np.clip(y-mm,0,h-1)); xx=int(np.clip(x+r.integers(-26,27),0,w-1))
            # ⚠️ UN POINT, PAS UN BLOC : un pavé carré se VOIT comme un
            # carré, même flouté (artefact du premier rendu).
            rr = int(r.integers(4, 10))
            yy0, yy1 = max(0, yy-rr*2), min(h, yy+rr*2)
            xx0, xx1 = max(0, xx-rr*2), min(w, xx+rr*2)
            gy2, gx2 = np.mgrid[yy0:yy1, xx0:xx1].astype(np.float32)
            g = np.exp(-(((gx2-xx)**2 + ((gy2-yy)*1.45)**2) / (2.0*rr*rr)))
            poche[yy0:yy1, xx0:xx1] = np.maximum(poche[yy0:yy1, xx0:xx1],
                                                 g*(1-mm/190.0)*0.85)
        for y,x in bd[r.integers(0,len(bd),min(150,len(bd)))]:
            mm = r.integers(8,96); yy=int(np.clip(y-mm,0,h-1)); xx=int(np.clip(x+r.integers(-15,16),0,w-1))
            poche[yy,xx] = max(poche[yy,xx], 1-mm/104.0)
    poche = gaussian_filter(poche, 1.4)*(0.5+0.5*fin)
    a = np.clip(a + poche[...,None]*np.array([1.0,0.58,0.20],np.float32), 0, 1)

    fum = langues(np.clip(1-dd/0.05,0,1)*0.6, 46, 3.4, 0.953)
    a = np.clip(a + gaussian_filter(fum,13)[...,None]*0.085*np.array([0.72,0.66,0.62],np.float32), 0, 1)
    return Image.fromarray((np.clip(a,0,1)*255).astype(np.uint8))

if __name__ == "__main__":
    im = charge("reel/popup2.png", 640)
    for n,(p,ph) in {"v1":(0.18,0.0),"v2":(0.36,0.40),"v3":(0.56,0.80),"v4":(0.78,1.2)}.items():
        rendu(im, p, ph).save("pub14/im/%s.jpg"%n, quality=96)
    print("ok")
