#!/usr/bin/env python3
"""MAQUETTE v2 de la légendaire « gravée sous verre » — 20-09-2026.

Ce n'est PAS le shader de l'app : une image (ou un film) cuit en Python qui
montre l'intention du plan (PLAN-LEGENDAIRE-PLONGEE-2026-09-20.md § 2), sur
les vraies illustrations et le vrai cadre argent. Tout est dérivé de l'image
de la carte — aucune coordonnée écrite pour une carte précise — et chaque
MONDE a sa météo :

    foret   neige fine + braises nées des pixels chauds (les bois du cerf)
    cimes   cendres qui tombent + lave : braises cuivre, plus nombreuses
    bois    PAS de feu : de la nacre qui monte des blancs de la peinture

Consigne du 20-09 : « tout le ciel et les détails doivent briller énormément,
limite mini-animation de la créature ». Donc :

    E1  la gravure   relief cuit (bords + ciselure dans le sens du poil), une
                     lampe déplacée par l'inclinaison ; un fil s'allume quand
                     sa pente fait face — jamais de bande
    E1b la silhouette cheveu de 1-2 px sur le bord de la créature qui fait
                     face à la lampe
    E2  le feu       braises depuis les sources de la carte, trois tailles,
                     bouffée au geste ; respiration des sources
    E3  le ciel      PAILLETTES : deux tailles de cellules sur tout le fond
                     sombre et lisse, chacune à son angle propre → un ciel qui
                     scintille ; + paillettes sur les reliefs clairs de la
                     créature (le poil, les écailles, les plumes)
    E3b la météo     neige / cendres / nacre, trois profondeurs, penchées par
                     le geste
    E5  le verre     cheveu sur le chant qui fait face, ombre du biseau,
                     réfraction le long du bord
    E6  le filigrane le cadre argent en rainure, même lampe
    E8  le grain     0,028
    film             l'inclinaison va et vient, la créature RESPIRE (sa cage
                     se soulève de 0,6 %), le feu vacille, les paillettes
                     clignotent, la météo tombe/monte

    python3 maquette.py <illustration.png> <nom> [--monde foret|cimes|bois] [--film]
"""
import os
import sys
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.abspath(os.path.join(ICI, "..", "..", ".."))
CADRE = os.path.join(DEPOT, "Nosfy", "Media", "carte-cadre-legendaire.png")

CW, CH = 1086, 1448
FEN = (0.118, 0.083, 0.763, 0.808)            # LuneForge.fenetre
WX, WY = int(FEN[0] * CW), int(FEN[1] * CH)
WW, WH = int(FEN[2] * CW), int(FEN[3] * CH)

MONDES = {
    "foret": dict(feu=(1.0, 0.55, 0.18), feu_n=200, meteo="neige",
                  meteo_col=(0.96, 0.97, 1.0), grav_col=(1.0, 1.0, 1.0)),
    "cimes": dict(feu=(1.0, 0.50, 0.16), feu_n=320, meteo="cendres",
                  meteo_col=(0.80, 0.72, 0.66), grav_col=(1.0, 0.96, 0.90)),
    "bois": dict(feu=None, feu_n=0, meteo="neige",
                 meteo_col=(0.96, 0.97, 1.0), grav_col=(0.95, 0.97, 1.0)),
}


def lum_of(rgb):
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def normalize(v):
    return v / (np.linalg.norm(v, axis=-1, keepdims=True) + 1e-9)


def sstep(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# ───────────────────────────── la carte ─────────────────────────────

def composer(art_path):
    art = Image.open(art_path).convert("RGB")
    s = max(WW / art.width, WH / art.height)
    art = art.resize((round(art.width * s), round(art.height * s)), Image.LANCZOS)
    canvas = Image.new("RGB", (CW, CH), (0, 0, 0))
    canvas.paste(art, (WX + (WW - art.width) // 2, WY + (WH - art.height) // 2))
    a = np.asarray(canvas).astype(np.float32) / 255
    inwin = np.zeros((CH, CW), np.float32)
    inwin[WY:WY + WH, WX:WX + WW] = 1
    return a * inwin[..., None], inwin


class Cuisson:
    """Tout ce qui se cuit UNE fois par carte (le kit) : relief, matière,
    sujet, sources de feu, sources de nacre, masque de ciel, cadre."""

    def __init__(self, art, inwin, monde):
        self.monde = MONDES[monde]
        self.art0 = art
        self.inwin = inwin
        lum = lum_of(art)
        self.lum = lum
        # — le relief (E1)
        gx = ndi.sobel(ndi.gaussian_filter(lum, 1.2), axis=1)
        gy = ndi.sobel(ndi.gaussian_filter(lum, 1.2), axis=0)
        jxx = ndi.gaussian_filter(gx * gx, 4.0)
        jyy = ndi.gaussian_filter(gy * gy, 4.0)
        jxy = ndi.gaussian_filter(gx * gy, 4.0)
        tr = jxx + jyy
        det = jxx * jyy - jxy * jxy
        disc = np.sqrt(np.maximum(tr * tr / 4 - det, 0))
        coher = (2 * disc) / (tr + 1e-6)
        theta = 0.5 * np.arctan2(2 * jxy, jxx - jyy)
        yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
        hatch = np.sin(2 * np.pi * (xx * np.cos(theta) + yy * np.sin(theta)) / 4.5)
        detail = ndi.gaussian_filter(np.hypot(gx, gy), 5.0)
        matiere = np.clip((detail - 0.04) / 0.08, 0, 1)
        matiere *= np.clip((lum - 0.04) / 0.08, 0, 1)
        matiere *= np.clip((0.90 - lum) / 0.15, 0, 1)
        matiere *= np.clip((coher - 0.22) / 0.30, 0, 1)
        self.matiere = ndi.gaussian_filter(matiere, 3.5) * inwin
        h = 2.0 * ndi.gaussian_filter(lum, 2.2) + 1.1 * hatch * self.matiere
        self.n = normalize(np.dstack([-ndi.sobel(h, axis=1) / 8,
                                      -ndi.sobel(h, axis=0) / 8, np.ones_like(h)]))
        # — le sujet (la créature) : là où la matière cohérente est dense
        suj = ndi.gaussian_filter(self.matiere, 14.0) > 0.16
        lab, nlab = ndi.label(suj)
        if nlab:
            tailles = ndi.sum(suj, lab, range(1, nlab + 1))
            suj = lab == (int(np.argmax(tailles)) + 1)
            suj = ndi.binary_fill_holes(suj)
        self.sujet = ndi.gaussian_filter(suj.astype(np.float32), 10.0) * inwin
        ys, xs = np.nonzero(self.sujet > 0.5)
        self.centre = (xs.mean(), ys.mean()) if len(xs) else (CW / 2, CH / 2)
        sx = ndi.sobel(ndi.gaussian_filter(self.sujet, 3.0), axis=1) / 8
        sy = ndi.sobel(ndi.gaussian_filter(self.sujet, 3.0), axis=0) / 8
        self.sil_g = (sx, sy)
        # — les reliefs clairs de la créature : là où les paillettes de détail vivent
        self.eclats = np.clip((lum - 0.30) / 0.30, 0, 1) * np.clip(detail / 0.10, 0, 1) * inwin
        # — le ciel : sombre et lisse (pas seulement en haut : tout le fond)
        smooth = ndi.gaussian_filter(np.hypot(gx, gy), 3.0)
        self.ciel = ((lum < 0.55) & (smooth < 0.07)).astype(np.float32) * inwin
        self.ciel = ndi.gaussian_filter(self.ciel, 2.0)
        # — les sources de feu
        r, g, b = art[..., 0], art[..., 1], art[..., 2]
        chaud = ((r > 0.55) & (r - b > 0.30) & (inwin > 0)).astype(np.float32)
        self.chaud = ndi.gaussian_filter(chaud, 1.0)
        # — les sources de nacre (les blancs froids de la peinture)
        sat = art.max(-1) - art.min(-1)
        nacre = ((lum > 0.62) & (sat < 0.12) & (inwin > 0)).astype(np.float32)
        self.nacre = ndi.gaussian_filter(nacre, 1.0)
        # — le cadre
        c = np.asarray(Image.open(CADRE).convert("RGBA")).astype(np.float32) / 255
        self.cadre_rgb, self.cadre_a = c[..., :3], c[..., 3]
        hc = ndi.gaussian_filter(lum_of(self.cadre_rgb) * self.cadre_a, 0.8) * 6.0
        self.n_cadre = normalize(np.dstack([-ndi.sobel(hc, axis=1) / 8,
                                            -ndi.sobel(hc, axis=0) / 8, np.ones_like(hc)]))
        # — les particules (déterministes : le film les fait vivre)
        rng = np.random.default_rng(20260920)
        self.rng = rng
        self.braises = self._semer(self.chaud, self.monde["feu_n"], rng) if self.monde["feu"] else []
        self.motes = self._semer(self.nacre, 260, rng) if monde == "bois" else []
        self.flocons = []
        couches = [(90, 0.8, 0.30, 0.4, 14.0), (60, 1.4, 0.80, 0.8, 26.0), (36, 2.2, 1.0, 1.6, 40.0)]
        if self.monde["meteo"] == "cendres":
            couches = [(70, 0.9, 0.40, 0.9, 9.0), (50, 1.5, 0.65, 1.5, 16.0), (30, 2.3, 0.75, 2.4, 24.0)]
        for n, size, alpha, gite, vit in couches:
            for _ in range(n):
                self.flocons.append(dict(x=rng.uniform(WX + 2, WX + WW - 3),
                                         y=rng.uniform(WY + 2, WY + WH - 3),
                                         size=size, alpha=alpha, gite=gite, vit=vit,
                                         ph=rng.uniform(0, 6.28), per=rng.uniform(2.5, 6.0)))
        # — les paillettes : deux grilles de cellules sur le ciel, une sur les reliefs
        self.grilles = [self._grille(3, 0.48, rng), self._grille(5, 0.36, rng), self._grille(2, 0.42, rng)]
        # — l'ombre du biseau
        yy_, xx_ = np.mgrid[0:CH, 0:CW]
        d = np.minimum.reduce([xx_ - WX, WX + WW - 1 - xx_, yy_ - WY, WY + WH - 1 - yy_])
        self.bord_d = d
        self.ombre = np.clip((16 - d) / 16, 0, 1) * (d >= 0)
        self.bande = np.clip((12 - d) / 12, 0, 1).astype(np.float32) * (d >= 0)

    @staticmethod
    def _semer(masque, n, rng):
        ys, xs = np.nonzero(masque > 0.25)
        if len(xs) == 0 or n == 0:
            return []
        w = masque[ys, xs]
        w = w / w.sum()
        idx = rng.choice(len(xs), size=n, p=w)
        out = []
        for i in idx:
            u = rng.random()
            size = 1.0 if u < 0.55 else (1.6 if u < 0.85 else rng.uniform(2.2, 2.8))
            out.append(dict(x=float(xs[i]), y=float(ys[i]), size=size,
                            vie=rng.uniform(1.6, 4.0), naissance=rng.uniform(0, 4.0),
                            rise=rng.uniform(70, 260), per=rng.uniform(0.6, 1.6),
                            ph=rng.uniform(0, 6.28), amp=rng.uniform(3, 9)))
        return out

    @staticmethod
    def _grille(c, gate, rng):
        gh, gw = CH // c + 1, CW // c + 1
        return dict(c=c, on=(rng.random((gh, gw)) < gate).astype(np.float32),
                    jx=rng.uniform(0.2, 0.8, (gh, gw)), jy=rng.uniform(0.2, 0.8, (gh, gw)),
                    ph=rng.uniform(0, 6.28, (gh, gw)),
                    taille=np.where(rng.random((gh, gw)) < 0.10, 1.6, 0.8) * np.where(rng.random((gh, gw)) < 0.02, 1.4, 1.0))


# ───────────────────────────── les lumières ─────────────────────────────

def lampe(tilt):
    tx, ty = tilt
    L = normalize(np.array([0.30 + 1.35 * tx, -0.45 + 1.35 * ty, 1.0], np.float32))
    return L


def eclairer(n, L, expo):
    H = normalize(L + np.array([0, 0, 1.0], np.float32))
    return np.clip(n @ H, 0, 1) ** expo


def paillettes(g, masque, tilt, t):
    """Une grille de cellules : dans chacune UN éclat à son angle propre —
    allumé quand l'inclinaison (et le temps) passe dessus. Vectorisé."""
    c = g["c"]
    tx, ty = tilt
    yy, xx = np.mgrid[0:CH, 0:CW]
    cy, cx = yy // c, xx // c
    on = g["on"][cy, cx]
    px = (cx + g["jx"][cy, cx]) * c
    py = (cy + g["jy"][cy, cx]) * c
    ph = g["ph"][cy, cx]
    taille = g["taille"][cy, cx]
    tw = np.maximum(np.cos(ph + 2.6 * tx + 1.9 * ty + t * 0.9), 0) ** 6
    d2 = (xx - px) ** 2 + (yy - py) ** 2
    sig = 0.48 * taille
    coeur = np.exp(-d2 / (2 * sig * sig))
    croix = 0.0
    return on * tw * (coeur + croix) * masque


def splat(img, x, y, size, color, alpha):
    r = int(np.ceil(size * 1.6)) + 1
    x0, x1 = int(x) - r, int(x) + r + 1
    y0, y1 = int(y) - r, int(y) + r + 1
    if x0 < 0 or y0 < 0 or x1 > CW or y1 > CH:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    d2 = (xx - x) ** 2 + (yy - y) ** 2
    sig = max(size / 2.6, 0.45)
    k = np.maximum(np.exp(-d2 / (2 * sig * sig)), (d2 <= 0.36).astype(np.float32))
    img[y0:y1, x0:x1] += (k * alpha)[..., None] * np.asarray(color, np.float32)


def feu(k, t, tilt, bouffee):
    """E2 — les braises vivent : âge = (t − naissance) mod vie."""
    add = np.zeros((CH, CW, 3), np.float32)
    col0 = k.monde["feu"]
    if not col0:
        return add
    tx, _ = tilt
    for b in k.braises:
        age = ((t - b["naissance"]) % b["vie"]) / b["vie"]
        x = b["x"] + b["amp"] * np.sin(b["ph"] + t * 6.28 / b["per"]) - 18 * tx * age - bouffee * 30 * age
        y = b["y"] - b["rise"] * age * (1 + 0.6 * bouffee)
        if age < 0.08:
            col, a = (1.0, 0.86, 0.62), 1.0
        elif age < 0.5:
            col, a = col0, 1.0
        elif age < 0.85:
            u = (age - 0.5) / 0.35
            col = (col0[0] - 0.4 * u, col0[1] - 0.43 * u, col0[2] - 0.16 * u)
            a = 1.0 - 0.5 * u
        else:
            col, a = (0.35, 0.05, 0.01), 0.5 * (1 - (age - 0.85) / 0.15)
        splat(add, x, y, b["size"], col, a)
    # les étincelles : 1 px blanc-chaud, crachées vite des pointes, vie courte
    for j, b in enumerate(k.braises[::2]):
        age = ((t * 2.3 - b["naissance"]) % 1.0)
        x = b["x"] + (j % 7 - 3) * 6 * age + b["amp"] * 0.4 * np.sin(b["ph"] + t * 9)
        y = b["y"] - 90 * age
        splat(add, x, y, 0.8, (1.0, 0.92, 0.75), (1 - age) ** 1.5)
    # la respiration des sources (deux houles) + le vacillement
    resp = 0.42 + 0.16 * np.sin(t * 6.28 / 7.3) + 0.08 * np.sin(t * 6.28 / 1.9) + 0.06 * np.sin(t * 6.28 / 0.37)
    chaud = np.clip(ndi.gaussian_filter(k.chaud, 4.5) * resp * 0.8, 0, 1)
    coeur = np.clip(ndi.gaussian_filter(k.chaud, 1.4) * 0.35, 0, 1)
    warm = chaud[..., None] * np.array([col0[0], col0[1] * 0.9, col0[2] * 0.8]) \
        + coeur[..., None] * np.array([1.0, 0.80, 0.50])
    warm = np.minimum(warm, np.array([1.0, 0.62, 0.30]))    # jamais blanc cramé
    return add + warm


def nacre(k, t, tilt):
    """Les Bois : de la nacre qui MONTE des blancs de la peinture."""
    add = np.zeros((CH, CW, 3), np.float32)
    for b in k.motes:
        age = ((t - b["naissance"]) % b["vie"]) / b["vie"]
        x = b["x"] + 0.5 * b["amp"] * np.sin(b["ph"] + t * 6.28 / (b["per"] * 2))
        y = b["y"] - 0.45 * b["rise"] * age
        a = np.sin(age * np.pi) ** 0.7
        splat(add, x, y, min(b["size"], 2.2), (0.96, 0.97, 1.0), a)
    return add


def meteo(k, t, tilt):
    """E3b — neige ou cendres : trois profondeurs, penchées par le geste."""
    add = np.zeros((CH, CW, 3), np.float32)
    tx, _ = tilt
    col = k.monde["meteo_col"]
    for f in k.flocons:
        y = WY + ((f["y"] - WY) + f["vit"] * t) % WH
        x = f["x"] + 4 * f["gite"] * np.sin(f["ph"] + t * 6.28 / f["per"]) + 22 * f["gite"] * tx
        n = 2 if f["size"] > 2 else 1
        for i in range(n):
            splat(add, x + i * f["gite"] * tx * 0.9, y - i * 0.8, f["size"] * (1 - 0.3 * i), col, f["alpha"] * (1 - 0.45 * i))
    return add


def respirer(art, k, t):
    """La mini-animation : la cage de la créature se soulève de 0,6 %."""
    s = 1.0 + 0.006 * np.sin(t * 6.28 / 4.2)
    cx, cy = k.centre
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    w = k.sujet
    sx = xx + (xx - cx) * (1 - 1 / s) * w * 0.5
    sy = yy + (yy - cy) * (1 - 1 / s) * w
    return np.dstack([ndi.map_coordinates(art[..., c], [sy, sx], order=1, mode="nearest") for c in range(3)])


def rendre(k, tilt, t=2.1, bouffee=0.0, anime=False):
    L = lampe(tilt)
    tx, ty = tilt
    art = respirer(k.art0, k, t) if anime else k.art0
    # E5 la réfraction le long du bord, l'ombre du biseau
    shifted = np.dstack([ndi.shift(art[..., c], (-3.0 * ty, -3.0 * tx), order=1, mode="nearest") for c in range(3)])
    art = art * (1 - k.bande[..., None]) + shifted * k.bande[..., None]
    art = art * (1 - 0.30 * k.ombre[..., None])
    # E1 la gravure — les fils, sur la matière ; forts, mais des fils
    grav = eclairer(k.n, L, 110.0) * k.inwin * k.matiere
    grav *= np.clip((k.lum - 0.02) / 0.12, 0.15, 1.0)
    # E1b la silhouette qui fait face
    sx, sy = k.sil_g
    gmag = np.hypot(sx, sy)
    facing = np.clip((sx * L[0] + sy * L[1]) / (np.hypot(L[0], L[1]) * (gmag + 1e-6)), 0, 1) ** 2
    rim = np.clip((gmag - 0.010) / 0.010, 0, 1) * facing * k.inwin
    rim = rim * 0.0   # la silhouette attend la vraie profondeur du kit (sans elle : des rubans)
    blanc = np.array(k.monde["grav_col"], np.float32)
    lum_add = (np.clip(grav * 1.9 + rim, 0, 1))[..., None] * blanc
    # E3 les paillettes : le ciel entier, puis les reliefs de la créature
    ciel = paillettes(k.grilles[0], k.ciel, tilt, t) * 1.3 + paillettes(k.grilles[1], k.ciel, tilt, t) * 1.4
    eclats = paillettes(k.grilles[2], k.eclats, tilt, t)
    pail = np.clip(ciel + eclats * 1.8, 0, 1)
    pail = pail + ndi.gaussian_filter(pail, 0.9) * 0.35         # bloom minuscule
    lum_add += np.clip(pail, 0, 1.3)[..., None] * np.array([1.0, 0.98, 0.94])
    # E2 le feu / la nacre, E3b la météo
    lum_add += feu(k, t, tilt, bouffee)
    lum_add += nacre(k, t, tilt)
    lum_add += meteo(k, t, tilt)
    # E6 le filigrane, E5 le chant
    fil = eclairer(k.n_cadre, L, 130.0) * np.clip(k.cadre_a * 3, 0, 1)
    chant = np.zeros((CH, CW), np.float32)
    x0, x1, y0, y1 = WX, WX + WW - 1, WY, WY + WH - 1
    chant[y0:y1, x1] += max(0.0, tx) * 1.2
    chant[y0:y1, x0] += max(0.0, -tx) * 1.2
    chant[y1, x0:x1] += max(0.0, ty) * 1.2
    chant[y0, x0:x1] += max(0.0, -ty) * 1.2
    chant = np.clip(chant, 0, 1) + ndi.gaussian_filter(chant, 1.2) * 0.35
    lum_add += (fil * 0.8 + np.clip(chant, 0, 1))[..., None] * np.array([0.95, 0.97, 1.0])
    # composition : l'art sous le cadre, les lumières en écran
    base = art * (1 - k.cadre_a[..., None]) + k.cadre_rgb * k.cadre_a[..., None]
    out = 1 - (1 - base) * (1 - np.clip(lum_add, 0, 1))
    out = lunes(out, 4)
    out += k.rng.normal(0, 0.018, (CH, CW, 1)).astype(np.float32)
    return np.clip(out, 0, 1)


def lunes(img, n):
    """Quatre vrais croissants (disque moins son jumeau décalé), blanc froid."""
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    r, y = 7.0, 1316.0
    masque = np.zeros((CH, CW), np.float32)
    for i in range(n):
        cx = 212.0 + i * 24
        A = (xx - cx) ** 2 + (yy - y) ** 2 <= r * r
        B = (xx - (cx + r * 0.42)) ** 2 + (yy - (y - r * 0.30)) ** 2 <= r * r
        masque += (A & ~B).astype(np.float32)
    halo = ndi.gaussian_filter(masque, 2.0) * 0.45
    col = np.array([0.93, 0.95, 1.0], np.float32)
    img = 1 - (1 - img) * (1 - np.clip(halo, 0, 1)[..., None] * col)
    return img * (1 - masque[..., None]) + col * masque[..., None]


# ───────────────────────────── les sorties ─────────────────────────────

def crops(img, k, z=3, w=200, h=200):
    src = k.chaud if k.monde["feu"] else k.nacre
    sm = ndi.gaussian_filter(src, 12)
    cy, cx = np.unravel_index(np.argmax(sm), sm.shape)
    sc = ndi.gaussian_filter(k.matiere * k.eclats, 10)
    sy_, sx_ = np.unravel_index(np.argmax(sc), sc.shape)
    boxes = {
        "le feu / la nacre": (int(np.clip(cx - w // 2, WX, WX + WW - w)), int(np.clip(cy - h // 2, WY, WY + WH - h))),
        "la créature": (int(np.clip(sx_ - w // 2, WX, WX + WW - w)), int(np.clip(sy_ - h // 2, WY, WY + WH - h))),
        "le ciel": (WX + WW // 2 - w // 2, WY + 30),
        "le coin du cadre": (150, 1190),
    }
    outs = {}
    for nom, (x, y) in boxes.items():
        c = img[y:y + h, x:x + w]
        im = Image.fromarray((np.clip(c, 0, 1) * 255).astype(np.uint8)).resize((w * z, h * z), Image.BICUBIC)
        outs[nom] = im
    return outs


def planche(nom, rendus, labels, cropsets):
    s = 0.6
    vues = [Image.fromarray((r * 255).astype(np.uint8)).resize((int(CW * s), int(CH * s)), Image.LANCZOS) for r in rendus]
    try:
        f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 18)
        f2 = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 14)
    except OSError:
        f = f2 = ImageFont.load_default()
    cw = 600
    largeur = max(3 * vues[0].width + 4 * 24, 4 * cw + 5 * 24)
    hauteur = vues[0].height + 24 * 3 + cw + 70
    pl = Image.new("RGB", (largeur, hauteur), (4, 4, 6))
    d = ImageDraw.Draw(pl)
    x = 24
    for v, lab in zip(vues, labels):
        pl.paste(v, (x, 36))
        d.text((x, 10), lab, fill=(200, 205, 215), font=f)
        x += v.width + 24
    y = 36 + vues[0].height + 30
    d.text((24, y - 22), f"{nom} — crops ×3 de la vue penchée à droite", fill=(200, 205, 215), font=f2)
    x = 24
    for lab, c in cropsets.items():
        pl.paste(c, (x, y))
        d.text((x, y + cw + 4), lab, fill=(150, 155, 165), font=f2)
        x += cw + 24
    d.text((24, hauteur - 22),
           "MAQUETTE Python (pas le shader) — image fixe : le film montre la vie (respiration, feu, météo, paillettes)",
           fill=(120, 125, 135), font=f2)
    return pl


def film(k, nom, duree=8.0, fps=12):
    dossier = os.path.join(ICI, f"{nom}-film")
    os.makedirs(dossier, exist_ok=True)
    n = int(duree * fps)
    for i in range(n):
        t = i / fps
        tx = 0.55 * np.sin(t * 6.28 / 6.0)
        ty = 0.22 * np.sin(t * 6.28 / 8.5 + 1.0)
        vit = abs(0.55 * 6.28 / 6.0 * np.cos(t * 6.28 / 6.0))    # la vitesse du geste = la bouffée
        r = rendre(k, (tx, ty), t=t, bouffee=min(vit / 0.6, 1.0) * 0.6, anime=True)
        Image.fromarray((r * 255).astype(np.uint8)).save(os.path.join(dossier, f"{i:04d}.png"))
        if i % 12 == 0:
            print(f"  film {nom}: {i}/{n}", flush=True)
    out = os.path.join(ICI, f"{nom}-film.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps),
                    "-i", os.path.join(dossier, "%04d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "17", out], check=True)
    for f_ in os.listdir(dossier):
        os.remove(os.path.join(dossier, f_))
    os.rmdir(dossier)
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    art_path, nom = args[0], args[1]
    monde = sys.argv[sys.argv.index("--monde") + 1] if "--monde" in sys.argv else "foret"
    args = [a for a in args if a != monde]
    art, inwin = composer(art_path)
    k = Cuisson(art, inwin, monde)
    tilts = [(-0.5, 0.0), (0.0, 0.0), (0.5, 0.2)]
    labels = ["penchée à gauche (−0,5)", "posée (0)", "penchée à droite (+0,5 · +0,2)"]
    rendus = [rendre(k, tl) for tl in tilts]
    for tl, r in zip(tilts, rendus):
        Image.fromarray((r * 255).astype(np.uint8)).save(os.path.join(ICI, f"{nom}-tilt{tl[0]:+.1f}.png"))
    pl = planche(nom, rendus, labels, crops(rendus[2], k))
    pl.save(os.path.join(ICI, f"{nom}-planche.png"))
    print("OK planche", nom, pl.size, flush=True)
    if "--film" in sys.argv:
        print("OK film", film(k, nom))


if __name__ == "__main__":
    main()
