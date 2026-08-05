#!/usr/bin/env python3
"""Extraction de la GÉOMÉTRIE d'une référence noir-sur-noir.

Le corps est noir sur fond noir : la silhouette n'existe que par sa lumière.
On la récupère en seuillant très bas, puis en bouchant les trous (l'intérieur
du corps est aussi sombre que le fond — sans remplissage on ne récupère qu'un
contour creux).

Sorties : masque PNG, boîte, aire, centroïde, et le profil radial r(theta)
depuis le centroïde — la description compacte qui sert à caler un SDF.

    python3 extract.py ref/peche.png masque/peche
"""
import sys
import numpy as np
from PIL import Image


def masque_silhouette(path, seuil=3.0):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float64)
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    h, w = lum.shape
    coins = np.concatenate([lum[:60, :60].ravel(), lum[:60, -60:].ravel(),
                            lum[-60:, :60].ravel(), lum[-60:, -60:].ravel()])
    brut = lum > (coins.mean() + seuil)

    # Fermeture : dilate puis érode, pour souder le liseré en une frontière
    # continue avant de remplir.
    ferme = erode(dilate(brut, 6), 6)
    # Remplissage : tout ce qui n'est pas atteignable depuis le bord est
    # intérieur. Propagation par vagues sur le complémentaire.
    dehors = flood_bord(~ferme)
    plein = ~dehors
    # Ouverture : on efface les poussières du halo restées accrochées.
    return dilate(erode(plein, 4), 4), lum


def dilate(m, r):
    h, w = m.shape
    ii = np.zeros((h + 1, w + 1), dtype=np.int64)
    ii[1:, 1:] = np.cumsum(np.cumsum(m.astype(np.int64), 0), 1)
    ys, xs = np.arange(h)[:, None], np.arange(w)[None, :]
    y0, y1 = np.clip(ys - r, 0, h), np.clip(ys + r + 1, 0, h)
    x0, x1 = np.clip(xs - r, 0, w), np.clip(xs + r + 1, 0, w)
    return (ii[y1, x1] - ii[y0, x1] - ii[y1, x0] + ii[y0, x0]) > 0


def erode(m, r):
    return ~dilate(~m, r)


def flood_bord(libre):
    """Composante de `libre` connectée au bord — par vagues de dilatation."""
    h, w = libre.shape
    vu = np.zeros_like(libre)
    vu[0, :] = libre[0, :]; vu[-1, :] = libre[-1, :]
    vu[:, 0] = libre[:, 0]; vu[:, -1] = libre[:, -1]
    while True:
        suivant = dilate(vu, 1) & libre
        if suivant.sum() == vu.sum():
            return vu
        vu = suivant


def rapport(path, sortie):
    m, lum = masque_silhouette(path)
    h, w = m.shape
    ys, xs = np.nonzero(m)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    cx, cy = xs.mean(), ys.mean()

    print(f"\n=== {path} ===")
    print(f"[masque] aire {100*m.mean():.2f} % de la planche")
    print(f"[masque] boite x {x0}-{x1} ({x1-x0+1} px)  y {y0}-{y1} ({y1-y0+1} px)")
    print(f"[masque] centroide ({cx/w:.4f} ; {cy/h:.4f})")
    # Repère normalisé du banc : origine au centre de la planche, y vers le
    # haut, demi-côté = 1.
    def norm(px, py):
        return (2 * px / w - 1, -(2 * py / h - 1))
    nx0, ny1 = norm(x0, y0)
    nx1, ny0 = norm(x1, y1)
    print(f"[repere] boite normalisee : x [{nx0:+.4f} ; {nx1:+.4f}]  y [{ny0:+.4f} ; {ny1:+.4f}]")
    ncx, ncy = norm(cx, cy)
    print(f"[repere] centroide normalise : ({ncx:+.4f} ; {ncy:+.4f})")

    # Profil radial depuis le centroïde : pour chaque angle, le rayon du
    # dernier pixel appartenant au masque.
    N = 72
    rmax = int(np.hypot(w, h) / 2)
    print(f"[profil] r(theta) depuis le centroide, en fraction du demi-cote "
          f"({N} pas, theta 0 = droite, sens antihoraire) :")
    lignes = []
    for k in range(N):
        th = 2 * np.pi * k / N
        dx, dy = np.cos(th), -np.sin(th)
        r = 0
        for t in range(1, rmax):
            px, py = int(cx + dx * t), int(cy + dy * t)
            if not (0 <= px < w and 0 <= py < h):
                break
            if m[py, px]:
                r = t
        lignes.append(f"{np.degrees(th):5.0f}:{2*r/w:.4f}")
    for i in range(0, N, 6):
        print("[profil]  " + "  ".join(lignes[i:i + 6]))

    Image.fromarray((m * 255).astype(np.uint8)).save(f"{sortie}-masque.png")
    print(f"[masque] ecrit -> {sortie}-masque.png")


if __name__ == "__main__":
    rapport(sys.argv[1], sys.argv[2])
