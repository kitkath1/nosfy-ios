#!/usr/bin/env python3
"""LE MÉDAILLON — la sonde unique du chantier (atlas : tools/verre/MEDAILLON.md).

Elle mesure la RÉFÉRENCE et le RENDU avec exactement la même recette, et rend
un verdict PASS/FAIL ligne à ligne. Les cibles ne sont pas écrites en dur :
elles sont RECALCULÉES sur la référence à chaque exécution — c'est la seule
façon d'être sûr que les deux côtés passent par le même code.

CONVENTIONS (atlas §0.1)
  angles : 0° = droite, 90° = BAS, 180° = gauche, 270° = haut (y descend)
  luma L : moyenne des 3 canaux encodés ; chromie X : R − B
  R canonique = R50, le rayon à mi-hauteur de la CHUTE EXTERNE (bord visible)
  tout est exprimé en fraction de R50 : la taille du disque peut donc changer
  sans invalider une seule cible.

PIÈGES CÂBLÉS DANS LA SONDE (tous payés au moins une fois)
  - la géométrie se DÉTECTE, jamais ne se suppose : trois rayons différents
    coexistent (gradient, crête du fil, R50) et les confondre fausse tout ;
  - REF_CROP fait foi pour les NIVEAUX (REF_HD a les noirs écrasés et n'est
    qu'un ré-agrandissement ×1,19) ; les deux concordent sur les FORMES ;
  - le glyphe est masqué (L > seuil, dilaté) avant toute statistique de fond ;
  - sous r/R = 0,50 il ne survit presque aucune cellule au masque : les
    cibles y sont faiblement contraintes, la sonde le signale au lieu de mentir.
Usage: medaillon.py <capture.png>
"""
import sys
import numpy as np
from PIL import Image

REF_PATH = "/Users/kathryn/Desktop/woochoper-ios/tools/verre/reference-card.png"

# ---------------------------------------------------------------- chargement
def carte_du_simu(path):
    cap = np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255
    g = cap.mean(axis=2)
    x0, x1 = 60, 1146
    band = g[1350:1600, x0+120:x1-120].mean(axis=1)
    yT = 1350 + int(np.abs(np.diff(band)).argmax())
    return cap[yT:yT+375, x0:x1], 3.0

def carte_de_ref():
    a = np.asarray(Image.open(REF_PATH).convert("RGB"), dtype=np.float64) / 255
    return a, a.shape[1] / 362.0

# ---------------------------------------------------------------- géométrie
def ech(img, x, y):
    """échantillonnage bilinéaire en pixels"""
    H, W, _ = img.shape
    x = np.clip(x, 0, W - 1.001); y = np.clip(y, 0, H - 1.001)
    x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int)
    fx = x - x0; fy = y - y0
    return (img[y0, x0].T * (1-fx) * (1-fy) + img[y0, x0+1].T * fx * (1-fy)
          + img[y0+1, x0].T * (1-fx) * fy + img[y0+1, x0+1].T * fx * fy).T

def rayon_profil(img, s, cx, cy, th, r0, r1, pas=0.05):
    rs = np.arange(r0, r1, pas)
    p = ech(img, (cx + rs*np.cos(th)) * s, (cy + rs*np.sin(th)) * s)
    return rs, p.mean(axis=1)

def detecte(img, s, boite, nom):
    """centre + R50, par ajustement itératif sur le front descendant externe"""
    H, W, _ = img.shape
    L = img.mean(axis=2)
    xa, xb, ya, yb = [int(v*s) for v in boite]
    Z = L[ya:yb, xa:xb]
    m = Z > np.percentile(Z, 92)
    ys, xs = np.mgrid[0:Z.shape[0], 0:Z.shape[1]]
    cx = (xs[m].mean() + xa) / s; cy = (ys[m].mean() + ya) / s
    R = 29.0
    for _ in range(6):
        pts = []
        for th in np.linspace(0, 2*np.pi, 180, endpoint=False):
            rs, p = rayon_profil(img, s, cx, cy, th, R-8, R+8)
            # LE BORD SE DÉTECTE AU GRADIENT, PAS À LA BRILLANCE.
            # Piège payé : chercher « le maximum » dans une fenêtre attrape
            # l'INTÉRIEUR du bol dès que le bol est trop clair (mon cas) —
            # la sonde rendait alors un rayon 13 % trop petit, vérifié faux
            # à l'œil sur un calque. La chute externe, elle, existe toujours.
            g = np.gradient(p)
            k = int(len(rs) * 0.25)
            i = k + int(np.argmin(g[k:]))              # la descente la plus raide
            haut = np.median(p[max(i-int(1.5/0.05), 0):i])
            dehors = np.median(p[i+int(2.0/0.05):])
            seuil = (haut + dehors) / 2
            j = i
            while j > 0 and p[j] < seuil: j -= 1
            while j < len(p)-1 and p[j] > seuil: j += 1
            pts.append((th, rs[j]))                    # R50 de cet angle
        th = np.array([q[0] for q in pts]); rr = np.array([q[1] for q in pts])
        med = np.median(rr); bon = np.abs(rr - med) < 2.5
        # recentrage : le décalage du centre module le rayon en cos/sin
        A = np.c_[np.cos(th[bon]), np.sin(th[bon]), np.ones(bon.sum())]
        sol, *_ = np.linalg.lstsq(A, rr[bon], rcond=None)
        cx += sol[0]; cy += sol[1]; R = sol[2]
    print(f"  {nom} : centre ({cx:.2f}, {cy:.2f}) pt — R50 {R:.2f} pt (Ø {2*R:.2f})")
    return cx, cy, R

# ---------------------------------------------------------------- mesures
def masque_glyphe(img, s, cx, cy, R, seuil):
    """vrai là où le pixel N'EST PAS le glyphe (ni sa dilatation)"""
    H, W, _ = img.shape
    yy, xx = np.mgrid[0:H, 0:W]
    L = img.mean(axis=2)
    chaud = L > seuil
    # dilatation de 0,038 R
    k = max(int(0.038 * R * s), 1)
    d = chaud.copy()
    for dx in range(-k, k+1):
        for dy in range(-k, k+1):
            d |= np.roll(np.roll(chaud, dx, axis=1), dy, axis=0)
    return ~d

def bol(img, s, cx, cy, R, seuil):
    """L et RVB par anneau, glyphe masqué ; plus le fit directionnel"""
    ok = masque_glyphe(img, s, cx, cy, R, seuil)
    res = {}
    for f in (0.45, 0.55, 0.65, 0.75, 0.85, 0.90):
        vals = []; rgbs = []; angs = []
        for th in np.linspace(0, 2*np.pi, 24, endpoint=False):
            x = (cx + f*R*np.cos(th)) * s; y = (cy + f*R*np.sin(th)) * s
            xi, yi = int(x), int(y)
            if not (0 <= yi < ok.shape[0] and 0 <= xi < ok.shape[1]) or not ok[yi, xi]:
                continue
            p = ech(img, np.array([x]), np.array([y]))[0]
            vals.append(p.mean()); rgbs.append(p); angs.append(th)
        if len(vals) < 6:
            res[f] = None; continue
        vals = np.array(vals); rgbs = np.array(rgbs); angs = np.array(angs)
        A = np.c_[np.ones(len(angs)), np.cos(angs), np.sin(angs)]
        sol, *_ = np.linalg.lstsq(A, vals, rcond=None)
        phi = np.degrees(np.arctan2(sol[2], sol[1])) % 360
        amp = np.hypot(sol[1], sol[2]) / max(sol[0], 1e-6)
        res[f] = dict(L=float(np.median(vals)), n=len(vals), phi=phi, amp=amp,
                      rgb=np.median(rgbs, axis=0))
    return res

def secteur(img, s, cx, cy, R, f0, f1, a0, a1, quoi="L"):
    v = []
    for th in np.radians(np.arange(a0, a1, 2.0)):
        for f in np.arange(f0, f1, 0.01):
            p = ech(img, np.array([(cx + f*R*np.cos(th))*s]),
                         np.array([(cy + f*R*np.sin(th))*s]))[0]
            v.append(p.mean() if quoi == "L" else p[0] - p[2])
    return float(np.median(v))

def fil(img, s, cx, cy, R):
    """balayage angulaire du liseré : crête, largeur à mi-hauteur, chromie"""
    out = []
    for deg in range(0, 360, 5):
        th = np.radians(deg)
        rs, p = rayon_profil(img, s, cx, cy, th, R-6, R+6, 0.05)
        i = int(np.argmax(p)); pk = p[i]
        dehors = np.median(p[rs > rs[i] + 3])
        h = (pk + dehors) / 2
        a = i
        while a > 0 and p[a] > h: a -= 1
        b = i
        while b < len(p)-1 and p[b] > h: b += 1
        rgb = ech(img, np.array([(cx + rs[i]*np.cos(th))*s]),
                       np.array([(cy + rs[i]*np.sin(th))*s]))[0]
        out.append(dict(deg=deg, pic=pk, larg=(rs[b]-rs[a]), pos=rs[i]-R,
                        chr=rgb[0]-rgb[2], dehors=dehors))
    return out

def bague(img, s, cx, cy, R):
    """le test de sertissage : DEHORS (1,06-1,14 R) − DEDANS (0,90-0,96 R)"""
    out = {}
    for a0 in range(0, 360, 30):
        d = secteur(img, s, cx, cy, R, 1.06, 1.14, a0, a0+30)
        i = secteur(img, s, cx, cy, R, 0.90, 0.96, a0, a0+30)
        out[a0] = d - i
    return out

# ---------------------------------------------------------------- rapport
def rapport(nom, img, s, boite, seuil):
    print(f"\n===== {nom} =====")
    cx, cy, R = detecte(img, s, boite, nom)
    H = img.shape[0] / s
    print(f"  assise : centre y / hauteur = {cy/H:.3f} · marge gauche {cx-R:.1f} pt"
          f" · marge basse {H-(cy+R):.1f} pt · marge haute {cy-R:.1f} pt")
    b = bol(img, s, cx, cy, R, seuil)
    ligne = " ".join(f"{f}:{b[f]['L']:.3f}" if b[f] else f"{f}:—" for f in (0.45,0.55,0.65,0.75,0.85,0.90))
    print(f"  bol L par anneau : {ligne}")
    if b[0.45] and b[0.85]:
        print(f"  chute L(0,45)/L(0,85) = {b[0.45]['L']/b[0.85]['L']:.2f}")
    for f in (0.60, 0.75, 0.85):
        bb = bol(img, s, cx, cy, R, seuil).get(f) if f == 0.60 else b.get(f)
        if f == 0.60:
            vals = []
            for th in np.linspace(0, 2*np.pi, 24, endpoint=False):
                p = ech(img, np.array([(cx+0.60*R*np.cos(th))*s]),
                             np.array([(cy+0.60*R*np.sin(th))*s]))[0]
                vals.append(p.mean())
            A = np.c_[np.ones(24), np.cos(np.linspace(0,2*np.pi,24,endpoint=False)),
                      np.sin(np.linspace(0,2*np.pi,24,endpoint=False))]
            sol, *_ = np.linalg.lstsq(A, np.array(vals), rcond=None)
            phi = np.degrees(np.arctan2(sol[2], sol[1])) % 360
            amp = np.hypot(sol[1], sol[2]) / max(sol[0], 1e-6)
            print(f"  dégradé @0,60 : phase {phi:5.1f}°  amplitude {amp*100:4.1f} %")
        elif bb:
            print(f"  dégradé @{f:.2f} : phase {bb['phi']:5.1f}°  amplitude {bb['amp']*100:4.1f} %")
    o1 = secteur(img, s, cx, cy, R, 0.80, 0.93, 240, 300)
    o2 = secteur(img, s, cx, cy, R, 0.80, 0.93, 0, 60)
    print(f"  ombre du bol : haut-gauche/bas-droite = {o1/o2:.2f}  (cible ≤ 0,90)")
    sf = secteur(img, s, cx, cy, R, 0.70, 0.80, 45, 105)
    op = secteur(img, s, cx, cy, R, 0.70, 0.80, 225, 285)
    print(f"  sous la flamme / opposé = {sf/op:.2f}  (cible 1,30-1,35)")
    # la douve
    rs, p = [], []
    for f in np.arange(0.60, 0.99, 0.01):
        rs.append(f); p.append(secteur(img, s, cx, cy, R, f, f+0.005, 150, 225))
    p = np.array(p); i = int(np.argmin(p))
    print(f"  douve : minimum à r/R = {rs[i]:.2f}, niveau {p[i]:.3f}  (cible 0,88 / 0,090)")
    F = fil(img, s, cx, cy, R)
    pics = np.array([x['pic'] for x in F]); larg = np.array([x['larg'] for x in F])
    chr_ = np.array([x['chr'] for x in F]); pos = np.array([x['pos'] for x in F])
    print(f"  fil : modulation {pics.max()/pics.min():.1f}× · largeur médiane {np.median(larg):.2f} pt"
          f" · position crête {np.median(pos):+.2f} pt · chromie médiane {np.median(chr_):+.3f}"
          f" (max {chr_.max():+.3f} à {F[int(np.argmax(chr_))]['deg']}°)")
    B = bague(img, s, cx, cy, R)
    ok = sum(1 for a in range(120, 241, 30) if B[a] >= 0.08)
    print(f"  bague (dehors−dedans) : " + " ".join(f"{a}°:{B[a]:+.3f}" for a in range(120, 241, 30))
          + f"   [{ok}/5 secteurs ≥ +0,08]")
    return dict(cx=cx, cy=cy, R=R, bol=b, fil=F, bague=B)

if __name__ == "__main__":
    ref, sr = carte_de_ref()
    moi, sm = carte_du_simu(sys.argv[1])
    rapport("RÉFÉRENCE (REF_CROP, la loi)", ref, sr, (25, 80, 40, 105), 0.28)
    rapport("MOI", moi, sm, (20, 75, 50, 115), 0.28)
