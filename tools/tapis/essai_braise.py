#!/usr/bin/env python3
"""
essai_braise.py — LA BRAISE DES DEUX PASTILLES, CUITE SANS BUILDER.

    python3 tools/tapis/essai_braise.py            # les recettes + les paliers
    python3 tools/tapis/essai_braise.py <capt.png> # sonde une capture réelle

L'école `tools/stop/essai_fond.py` : composer et TRANCHER en deux minutes, au
lieu de rejuger des builds à l'œil. Ici on ne compose pas une approximation :
on RE-JOUE `glowShade` / `eclipseWorld` (Nosfy/LiquidLens.metal:488-628) à la
constante près, en numpy. Les nombres sortent du même calcul que le téléphone.

⚠️ LA FAUTE DU 31-08, MESURÉE, QUE CE FICHIER EXISTE POUR NE PAS REFAIRE.
Les deux pastilles du J0 sont sorties GRISES — verdict de Kathryn : « les
couleurs sont noir dégradé beurk ». Mesuré sur la capture, encre masquée :
    aura chrono   R 0,189 G 0,131 B 0,100   G/R 0,694   B/R 0,528
    aura vitesse  R 0,213 G 0,178 B 0,160   G/R 0,833   B/R 0,747
La loi de la maison (Nosfy/VerreCoulant.metal:72, LiquidLens.metal:90-105) :
    « R reste à 1,000, TOUJOURS. On va vers le rouge en baissant le VERT,
      jamais en baissant le rouge ni en montant le bleu. »
    braise = G/R 0,30-0,45   ·   B/R ≤ 0,03   ·   le feu de la maison n'a
    PAS de bleu (duo-feu-rouge.mp4 tient B/R = 0,001).

⚠️ LA CAUSE EXACTE, TROUVÉE PAR ABLATION — `LiquidLens.metal:604` :
        float niv = max(max(max(c.r, c.g), c.b), 0.55);   // ← LE PLANCHER
        c = mix(c, float3(1.00, 0.97, 0.93) * niv, mTip);
Ce plancher INVENTE un blanc à 0,55 de luminance là où le lit local est
sombre. Dans le monde muscu il est inoffensif (le lit y est déjà ≥ 0,55 :
traînée d'encre + spotlight + 4 voix) et la langue lit comme une pointe
chaude. Dans un carré local VIDE, cette langue blanche EST le pixel le plus
clair de l'image — donc elle EST « l'aura » qu'on mesure. Prédiction du
modèle : 101/98/94. Mesure sur ma capture : 101/94/91. Le même pixel.

⚠️ AGGRAVANT : mon masque radial (stops 0,44 / 0,86 sur endRadius = côté/2)
coupait la BRAISE et gardait le GRIS — au pic de la nappe (r = R) il ne
laissait passer que 33 %, et il supprimait tout le lit large (là où le
shader est à G/R 0,26).

⚠️ CE QU'IL NE PROUVE PAS : la réfraction de `liquidLens` (elle DÉPLACE des
pixels, elle n'en fabrique aucun) et la teinte du verre `.clear` sur fond
saturé. Il tranche LA PALETTE — les 7 paliers et les deux états. Le verdict
esthétique reste à Kathryn : un juge qui affirme ne remplace pas une sonde
qui mesure, et une sonde qui mesure ne remplace pas ses yeux.
"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

# ── LES CONSTANTES, chacune avec sa raison ────────────────────────────────
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = REPO + "/Nosfy/Fonts/Inter-Medium.otf"
VIG = REPO + "/tools/tapis/vignettes"      # planches : NOM FIXE, écrasé

R = 100.0          # rayon de lentille, en unités du shader (cote*0.36)
DEMI = 260         # le demi-champ rendu : 2,6·R — au-delà, napp est mort
N = 521            # échantillons par axe (impair : un pixel pile au centre)
T = 11.0           # l'horloge : un instant quelconque du régime de veille
PULSE = 0.0        # neutre en teinte (LiquidLens.metal:613, pur gain)

# LA LOI, EN CHIFFRES (mémoire woop-harmonisation-rouge, mesurée sur
# home-fond-flamme.mp4 : racines 0,155 → chaud 0,418, B/R 0,010).
GR_MIN, GR_MAX, BR_MAX = 0.30, 0.45, 0.05
P_CLAIRS = 90      # percentile de sélection des pixels clairs

# LES 7 PALIERS — (ig, biais de heat). DEUX leviers, et c'est nécessaire :
# `heat` seul ne déplace la teinte que de 0,07 sur toute la course (mesuré :
# G/R 0,317 → 0,387), ce qui ne se LIT pas. `ig` porte la flamme (la nappe
# est ×ig, LiquidLens.metal:571), `heat` porte la teinte le long de la rampe
# de la vidéo (:562-564). Le feu MONTE et CHAUFFE ensemble, comme un vrai feu.
# ⚠️ `ig` reste libre parce que la voix blanche est éteinte dans la recette :
# sinon elle naîtrait à ig > 0,55 (:152) et regriserait tout.
# ⚠️ `ig` progresse en GÉOMÉTRIE, pas en addition : l'œil lit des RAPPORTS de
# luminance. Une suite arithmétique (0,30 · 0,42 · 0,55 …) donne des sauts de
# ×1,60 en bas et ×1,08 en haut — mesuré : les trois derniers paliers se
# lisaient comme un seul. ig = 0,235 · (1/0,235)^(k/6) ⇒ ~×1,28 partout.
PALIERS = [
    (0.235, -0.34),  # P0 — zéro set : la braise dort
    (0.302, -0.22),  # P1
    (0.388, -0.11),  # P2
    (0.499, +0.01),  # P3 — braise franche
    (0.641, +0.14),  # P4
    (0.824, +0.30),  # P5
    (1.000, +0.50),  # P6 — plein feu (≥ 6 sets), la teinte SATURE ici
]


# ── LE PORT FIDÈLE DU SHADER (Nosfy/LiquidLens.metal) ──────────────────────
def fract(x):
    return x - np.floor(x)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def lhash21(px, py):                                   # LiquidLens.metal:18-22
    p3 = fract(np.stack([px, py, px], -1) * 0.1031)
    dot = (p3 * (np.stack([p3[..., 1], p3[..., 2], p3[..., 0]], -1) + 33.33)).sum(-1)
    p3 = p3 + dot[..., None]
    return fract((p3[..., 0] + p3[..., 1]) * p3[..., 2])


def lnoise(px, py):                                    # :24-32
    ix, iy = np.floor(px), np.floor(py)
    fx, fy = px - ix, py - iy
    ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = lhash21(ix, iy), lhash21(ix + 1, iy)
    c, d = lhash21(ix, iy + 1), lhash21(ix + 1, iy + 1)
    bas = a + (b - a) * ux
    return bas + ((c + (d - c) * ux) - bas) * uy


def vfbm(px, py):                                      # :55-63 — 3 octaves
    v = np.zeros_like(px)
    a = 0.5
    for _ in range(3):
        v = v + a * lnoise(px, py)
        px, py = px * 2.03 + 17.1, py * 2.03 + 9.3
        a *= 0.5
    return v


# Les quatre voix (LiquidLens.metal:106-130). La voix 2 est LA BLANCHE.
COLS = np.array([[1.00, 0.17, 0.02], [1.00, 0.46, 0.03],
                 [1.00, 0.96, 0.90], [1.00, 0.29, 0.02]])
SPEED = np.array([6.2832 / 47.0, -6.2832 / 29.0, 6.2832 / 19.0, -6.2832 / 71.0])
PHASE = np.array([0.4, 2.6, 4.4, 5.6])
RHO0 = np.array([1.02, 0.98, 1.01, 1.14])
SRS = np.array([0.34, 0.19, 0.23, 0.42])
STS = np.array([0.66, 0.50, 0.58, 0.72])
BPER = np.array([13.0, 8.1, 5.2, 21.0])
BBASE = np.array([0.72, 0.62, 0.50, 0.66])
BAMP = np.array([0.28, 0.38, 0.50, 0.30])
WGT = np.array([0.55, 0.85, 1.05, 0.50])
KAP = np.array([5.0, 9.0, 11.0, 3.5])
DLY = np.array([0.30, 0.00, 0.55, 0.12])

# La rampe de la vidéo (22-08) — LiquidLens.metal:562-564.
V_RACINE = np.array([1.00, 0.13, 0.005])
V_CORPS = np.array([1.00, 0.30, 0.015])
V_CHAUD = np.array([1.00, 0.44, 0.035])


def eclipse_world(dx, dy, r, t, ig, rimK, occK, voix_blanche=True):
    """Les quatre voix orbitales — LiquidLens.metal:72-250."""
    nx = np.where(r > 0.5, dx / np.maximum(r, 1e-6), 0.0)
    ny = np.where(r > 0.5, dy / np.maximum(r, 1e-6), -1.0)
    inside = 1.0 - smoothstep(R - 1.0, R + 0.5, r)
    occ = 1.0 + (smoothstep(R - 0.5, R + 1.8, r) - 1.0) * occK
    angP = np.arctan2(dy, dx)
    light = np.zeros(dx.shape + (3,))
    rim_glow = np.zeros_like(light)
    back_tint = np.zeros_like(light)
    blanc = np.zeros_like(dx)
    for i in range(4):
        poids = WGT[i]
        if i == 2 and not voix_blanche:
            continue                       # RETOUCHE 2 : la voix blanche éteinte
        igv = np.clip((ig - DLY[i]) / (1.0 - DLY[i]), 0, 1)
        igv = igv * igv * (3 - 2 * igv)
        if igv < 0.003:
            continue                       # :151-153 — la voix n'existe pas
        ang = PHASE[i] + t * SPEED[i]
        hdx, hdy = np.cos(ang), np.sin(ang)
        grow = 0.97 + (RHO0[i] - 0.97) * igv
        rho = R * (grow + 0.05 * np.sin(t * 6.2832 / (BPER[i] * 2.7) + PHASE[i] * 3.0))
        dAng = angP - ang
        dAng = dAng - 6.2832 * np.floor(dAng / 6.2832 + 0.5)
        q = ((r - rho) ** 2 / (SRS[i] * R) ** 2
             + (dAng * max(rho, 1.0)) ** 2 / (STS[i] * R) ** 2)
        breath = BBASE[i] + BAMP[i] * np.sin(t * 6.2832 / BPER[i] + PHASE[i] * 5.0)
        g = 0.52 * np.exp(-q) + 0.48 * np.exp(-q * 0.32)
        wv = poids * igv
        facing = np.maximum(nx * hdx + ny * hdy, 0.0)
        porteuse = np.array([1.00, 0.24, 0.02]) + \
            (np.array([1.00, 0.40, 0.03]) - np.array([1.00, 0.24, 0.02])) * igv
        s = igv * igv * (3 - 2 * igv)
        colv = porteuse + (COLS[i] - porteuse) * s
        light += colv * (g * breath * wv)[..., None]
        rim_glow += colv * (np.power(facing, KAP[i]) * breath * wv)[..., None]
        back_tint += colv * (np.power(facing, 2.5) * breath * wv)[..., None]
        if i == 2:
            blanc += g * breath * wv
    edge = np.power(np.clip(r / R, 0, 1), 5.0)
    cloth = 0.80 + 0.40 * vfbm(dx * 0.02 + 7.0, dy * 0.02 + 3.0)
    velvet = (np.array([0.008, 0.008, 0.011]) + back_tint * 0.05) * (edge * cloth)[..., None]
    velvet *= (inside > 0.001)[..., None]
    ring = np.exp(-((r - R) ** 2) / 1.35)
    acc = vfbm(dx * 0.05 + t * 0.11, dy * 0.05 - t * 0.07) ** 3
    rim = (0.05 + rim_glow * (0.55 + 2.2 * acc)[..., None]) * (ring * rimK)[..., None]
    rim *= (ring > 0.004)[..., None]
    c = light * occ[..., None] + rim + velvet * inside[..., None]
    out = 1.0 - np.exp(-c * 1.55)                       # :219 — le tone-map
    # LE TIRAGE BLANC (:244-247) : une MIX vers un blanc chaud, pas une addition.
    m_blanc = np.clip(blanc * occ * 2.20, 0, 1)
    niveau = out.max(-1)
    out = out + (np.array([1.00, 0.97, 0.94]) * niveau[..., None] - out) * m_blanc[..., None]
    return out


def glow_shade(dx, dy, r, t, ig, biais=0.0, pointes=True, voix_blanche=True):
    """La nappe de feu — LiquidLens.metal:488-615.

    `biais` décale `heat` le long de la rampe de la vidéo : c'est LE levier
    des paliers (barème :562-564 — heat 0,40 → G/R 0,254 ; 1,00 → 0,440).
    `pointes` : les langues blanches (:601-605), la RETOUCHE 1.
    """
    c = eclipse_world(dx, dy, r, t, ig, 0.02, 0.55, voix_blanche)
    napp = np.exp(-(r * r) / (1.55 * R * 1.55 * R))                    # :498
    napp = napp * (0.30 + 0.70 * smoothstep(0.72 * R, 1.06 * R, r))    # :503
    rr = np.maximum(r, 1.0)
    fdx, fdy = dx / rr, dy / rr
    Tf = 2.6
    ph0, ph1 = fract(np.array(t / Tf)), fract(np.array(t / Tf + 0.5))
    offx, offy = fdx * (R * 0.22 * Tf), fdy * (R * 0.22 * Tf)
    q0x, q0y = dx - offx * ph0, dy - offy * ph0
    q1x, q1y = dx - offx * ph1, dy - offy * ph1
    qr0 = q0x * fdx + q0y * fdy
    qr1 = q1x * fdx + q1y * fdy
    q0x, q0y = (q0x - fdx * qr0) + fdx * (qr0 * 0.55), (q0y - fdy * qr0) + fdy * (qr0 * 0.55)
    q1x, q1y = (q1x - fdx * qr1) + fdx * (qr1 * 0.55), (q1y - fdy * qr1) + fdy * (qr1 * 0.55)
    w0 = 1.0 - abs(2.0 * ph0 - 1.0)
    a1 = vfbm(q1x * 0.010 + 9.4, q1y * 0.010 + 2.6)
    a0 = vfbm(q0x * 0.010 + 3.7, q0y * 0.010 + 8.1)
    fl = a1 + (a0 - a1) * w0
    heat = np.clip(0.66 * fl + 0.52 * napp - 0.06, 0, 1)               # :557
    heat = np.clip(heat + 0.05 * np.sin(t * 0.45) + biais, 0, 1)       # :558 + LE PALIER
    lo = V_RACINE + (V_CORPS - V_RACINE) * (heat / 0.55)[..., None]
    hi = V_CORPS + (V_CHAUD - V_CORPS) * ((heat - 0.55) / 0.45)[..., None]
    warm = np.where((heat < 0.55)[..., None], lo, hi)                  # :562-564
    cl = 0.55 + 0.75 * fl
    c = c + warm * (napp * 0.50 * ig * cl)[..., None]                  # :571
    c = c * (0.72 + 0.55 * fl)[..., None]                              # :575
    if pointes:
        tip = np.power(np.maximum(fl - 0.34, 0.0) / 0.66, 1.25)        # :593
        m_tip = np.clip(napp * ig * tip * 2.70, 0, 1)                  # :601
        niv = np.maximum(c.max(-1), 0.55)                              # :604 ← LE PLANCHER
        c = c + (np.array([1.00, 0.97, 0.93]) * niv[..., None] - c) * m_tip[..., None]
    c = c * (1.0 + 0.12 * PULSE)                                       # :613
    return np.clip(c, 0, 1)


# ── LA SONDE — pixels CLAIRS **ET CHAUDS**, jamais la moyenne ─────────────
def mesure(img, zone=None):
    """Rend (R,G,B) moyens des pixels clairs CHAUDS.

    ⚠️ Le masque `R > G` n'est pas une coquetterie : sur une compo braise +
    encre blanche, les pixels du percentile 90 sont L'ENCRE (le blanc est par
    définition le plus lumineux). Sans lui, on mesure la typo et on annonce
    G/R 0,94 — c'est exactement ce qui m'est arrivé le 31-08.
    """
    z = img.reshape(-1, 3) if zone is None else img[zone].reshape(-1, 3)
    lum = z.max(axis=1)
    seuil = np.percentile(lum, P_CLAIRS)
    m = (lum >= seuil) & (z[:, 0] > z[:, 1]) & (z[:, 0] > 0.15)
    if m.sum() < 50:
        return None
    return z[m].mean(axis=0)


def verdict(nom, rgb, gr_min=GR_MIN, gr_max=GR_MAX, br_max=BR_MAX):
    """Valeur · attendu · verdict sur LA MÊME ligne (école cotes.py:59-61)."""
    if rgb is None:
        print("  %-30s aucun pixel chaud" % nom)
        return False
    r, g, b = rgb
    gr, br = g / max(r, 1e-9), b / max(r, 1e-9)
    ok = (gr_min <= gr <= gr_max) and (br <= br_max)
    print("  %-30s R%.3f G%.3f B%.3f   G/R %.3f  B/R %.3f   "
          "(attendu G/R %.2f-%.2f, B/R <= %.2f)   %s"
          % (nom, r, g, b, gr, br, gr_min, gr_max, br_max,
             "OK" if ok else "ECART"))
    return ok


# ── LE CHAMP ──────────────────────────────────────────────────────────────
def champ():
    ys, xs = np.mgrid[-DEMI:DEMI:complex(0, N), -DEMI:DEMI:complex(0, N)]
    return xs, ys, np.hypot(xs, ys)


def masque_radial(r, dedans, dehors, fin):
    """Le masque de TapisScene.swift:308-313, en fractions de `fin` (le
    endRadius). Rend l'alpha, comme le RadialGradient de SwiftUI."""
    a = np.ones_like(r)
    t = np.clip((r / fin - dedans) / max(dehors - dedans, 1e-6), 0, 1)
    return np.clip(a * (1 - t), 0, 1)


def vignette(img, cote=250):
    """Le rendu 8 bits d'un champ, prêt pour la planche."""
    return (np.clip(img, 0, 1) * 255).astype(np.uint8)


# ── LE TOUR ───────────────────────────────────────────────────────────────
def recettes(xs, ys, r):
    """Les quatre compositions : le rejet, puis les retouches, une par une."""
    print("\n=== LES RECETTES (anneau nr 0,9-1,4 : la zone qu'on VOIT) ===")
    anneau = (r >= 0.9 * R) & (r < 1.4 * R)
    out = []
    # A — LE J0 REJETÉ : pointes + voix blanche + le masque qui coupe la braise
    a = glow_shade(xs, ys, r, T, 1.0)
    a_masq = a * masque_radial(r, 0.44, 0.86, DEMI / 1.857)[..., None]
    out.append(("A - le J0 REJETE", a_masq))
    verdict("A  le J0 rejete", mesure(a_masq, anneau))
    # B — sans les langues blanches (la retouche 1)
    b = glow_shade(xs, ys, r, T, 1.0, pointes=False)
    b_masq = b * masque_radial(r, 0.44, 0.86, DEMI / 1.857)[..., None]
    out.append(("B - sans les pointes", b_masq))
    verdict("B  sans les pointes (:604)", mesure(b_masq, anneau))
    # C — + la voix blanche éteinte (la retouche 2)
    c = glow_shade(xs, ys, r, T, 1.0, pointes=False, voix_blanche=False)
    c_masq = c * masque_radial(r, 0.44, 0.86, DEMI / 1.857)[..., None]
    out.append(("C - + voix blanche off", c_masq))
    verdict("C  + voix blanche off", mesure(c_masq, anneau))
    # D — + le masque qui garde la braise (la retouche 3) = LA RECETTE
    d = glow_shade(xs, ys, r, T, 1.0, pointes=False, voix_blanche=False)
    d_masq = d * masque_radial(r, 0.72, 1.00, DEMI)[..., None]
    out.append(("D - LA RECETTE", d_masq))
    verdict("D  LA RECETTE", mesure(d_masq, anneau))
    return out


def paliers(xs, ys, r):
    """Les 7 paliers du SET (le fond qui rougit) + l'ENTRE-SETS.

    Le levier est `heat` (biais), jamais une constante de couleur : la teinte
    remonte la rampe de la vidéo, qui EST la loi anti-brun.
    L'ENTRE-SETS n'est pas une cendre grise — elle n'existe pas dans cette
    maison : `heat -> 0` rend `vRacine (1,00 · 0,13 · 0,005)`, le rouge le
    plus PROFOND. Le feu ne devient pas gris, il RENTRE DANS SES RACINES.
    """
    print("\n=== LES 7 PALIERS DU SET (heat pour la TEINTE, ig pour la FLAMME) ===")
    anneau = (r >= 0.9 * R) & (r < 1.4 * R)
    masq = masque_radial(r, 0.72, 1.00, DEMI)[..., None]
    out, hors = [], 0
    prec_gr, prec_lum, monotone = 0.0, 0.0, True
    for k, (ig, biais) in enumerate(PALIERS):
        img = glow_shade(xs, ys, r, T, ig, biais=biais,
                         pointes=False, voix_blanche=False) * masq
        rgb = mesure(img, anneau)
        ok = verdict("P%d  ig %.2f  biais %+.2f" % (k, ig, biais), rgb,
                     0.14 if k < 3 else GR_MIN, GR_MAX, BR_MAX)
        hors += (not ok)
        gr = rgb[1] / rgb[0] if rgb is not None else 0.0
        lum = img.max(-1).mean()
        # ⚠️ DEUX paliers voisins doivent être VISIBLEMENT différents : la
        # leçon LiquidLens.metal:96 (à 0,36/0,54/0,56 trois voix se lisaient
        # comme un aplat) et le plancher 0,55 s de la Lune de sang. On exige
        # +8 % de luminance ET une teinte qui monte.
        if k:
            saut = lum / max(prec_lum, 1e-9)
            # La LUMINANCE est le critère qui porte : c'est elle que l'œil lit
            # à un mètre. La teinte, elle, SATURE en haut de rampe (vChaud
            # plafonne à G/R 0,44) — on lui demande seulement de ne pas
            # REDESCENDRE de plus de 0,02, pas de monter indéfiniment.
            fin = (saut < 1.15) or (gr < prec_gr - 0.02)
            monotone &= not fin
            print("       ecart au precedent : G/R %+.3f   luminance x%.2f   %s"
                  % (gr - prec_gr, saut, "TROP PROCHE" if fin else "lisible"))
        prec_gr, prec_lum = gr, lum
        out.append(("P%d set" % k, img))
    print("  progression monotone et lisible : %s" % ("OUI" if monotone else "NON"))
    print("\n=== L'ENTRE-SETS — le feu rentre dans ses racines ===")
    # ig 0.42 : sous 0,55 la VOIX BLANCHE n'existe pas (LiquidLens.metal:152)
    # — le refroidissement se fait par le shader lui-même, pas par un gris.
    # L'ENTRE-SETS depuis le palier COURANT : la règle mesurée de la maison —
    # « le feu refroidit ET baisse ensemble ». On reprend l'ig du palier N-2
    # (plancher P0) et on retire encore du heat : la teinte RENTRE vers les
    # racines (vRacine G/R 0,13) au lieu de virer au gris.
    ig_n, biais_n = PALIERS[4]
    ig_repos, biais_repos = PALIERS[max(4 - 2, 0)][0] * 0.62, biais_n - 0.42
    repos = glow_shade(xs, ys, r, T, ig_repos, biais=biais_repos,
                       pointes=False, voix_blanche=False) * masq
    verdict("ENTRE-SETS (depuis P4)", mesure(repos, anneau), 0.05, 0.30, BR_MAX)
    lum_set = glow_shade(xs, ys, r, T, ig_n, biais=biais_n,
                         pointes=False, voix_blanche=False) * masq
    l1, l2 = lum_set.max(-1).mean(), repos.max(-1).mean()
    print("  luminance moyenne  SET %.4f  vs  ENTRE-SETS %.4f   "
          "(rapport %.2fx — attendu >= 2,0 pour que l'etat se LISE)"
          % (l1, l2, l1 / max(l2, 1e-9)))
    out.append(("ENTRE-SETS", repos))
    print("\n%d palier(s) hors la loi sur 7" % hors)
    return out


def geometries():
    """QUEL CARRÉ POUR QUELLE LENTILLE — la question que le J0 n'a pas posée.

    La couronne vit jusqu'à ~2,6·R (au-delà, `napp` est mort). Mon carré du
    J0 faisait 1,39·R de demi-côté : il ne pouvait PAS contenir le feu, quel
    que soit le masque. On cherche le plus petit carré qui garde la braise.
    """
    print("\n=== LA GEOMETRIE : quel demi-cote pour la lentille ? ===")
    out = []
    for demi_sur_r in (1.39, 1.80, 2.20, 2.60):
        demi = demi_sur_r * R
        n = 401
        ys, xs = np.mgrid[-demi:demi:complex(0, n), -demi:demi:complex(0, n)]
        r = np.hypot(xs, ys)
        img = glow_shade(xs, ys, r, T, 1.0, biais=+0.14,
                         pointes=False, voix_blanche=False)
        img = img * masque_radial(r, 0.72, 1.00, demi)[..., None]
        anneau = (r >= 0.9 * R) & (r < 1.4 * R)
        rgb = mesure(img, anneau)
        # LA COUPE : ce que le masque jette. Mesuré comme l'énergie perdue.
        plein = glow_shade(xs, ys, r, T, 1.0, biais=+0.14,
                           pointes=False, voix_blanche=False)
        perdu = 1.0 - img.sum() / max(plein.sum(), 1e-9)
        verdict("demi-cote %.2f R" % demi_sur_r, rgb)
        print("       energie du feu jetee par le cadre+masque : %.0f %%   %s"
              % (100 * perdu, "ACCEPTABLE" if perdu < 0.30 else "TROP"))
        out.append(("demi %.2fR" % demi_sur_r, img))
    return out


def planche(vign, nom_fichier):
    """Deux rangées : la pastille entière, puis LE ZOOM sur l'aura — le seul
    endroit où la teinte se juge (école essai_fond.py:172-198)."""
    tw = 250
    th = tw
    zh = int(th * 0.52)
    os.makedirs(VIG, exist_ok=True)
    pl = Image.new("RGB", (tw * len(vign), th + zh + 34), (16, 16, 16))
    d = ImageDraw.Draw(pl)
    try:
        petite = ImageFont.truetype(FONT, 17)
    except Exception:
        petite = None
    for k, (nom, img) in enumerate(vign):
        im = vignette(img)
        pl.paste(Image.fromarray(im).resize((tw, th), Image.LANCZOS), (k * tw, 0))
        # LE ZOOM : la bande de l'anneau (nr ~1,0), là où la braise vit
        y0 = int(N * 0.50 - N * 0.42)
        y1 = int(N * 0.50 - N * 0.20)
        z = im[y0:y1, int(N * 0.10):int(N * 0.90)]
        pl.paste(Image.fromarray(z).resize((tw, zh), Image.LANCZOS), (k * tw, th))
        d.text((k * tw + 8, th + zh + 9),
               nom.encode("ascii", "ignore").decode(), fill=(205, 205, 205), font=petite)
        d.line([(k * tw, 0), (k * tw, th + zh)], fill=(60, 60, 60))
    out = VIG + "/" + nom_fichier
    pl.save(out)
    return out


def sonde_capture(chemin):
    """Le mode sonde : la MÊME loi appliquée à une capture réelle.

    ⚠️ ON VISE LES FLANCS, JAMAIS UNE MOITIÉ D'ÉCRAN. Payé DEUX fois : une
    moitié d'écran contient l'encre, et les bords antialiasés du blanc sur
    l'orange passent le filtre `R > G` en portant tout le bleu du blanc. Mesuré
    sur la même capture : moitié haute → G/R 0,515 · B/R 0,259 (« ECART »),
    les flancs de la couronne → G/R 0,322-0,361 · B/R 0,024-0,027 (dans la
    loi). Le premier chiffre décrivait la typo, pas le feu.
    """
    img = np.asarray(Image.open(chemin).convert("RGB")).astype(float) / 255.0
    h, w, _ = img.shape
    print("capture %dx%d px" % (w, h))
    for nom, (y0, y1, x0, x1) in [
            ("couronne chrono  gauche", (0.20, 0.34, 0.02, 0.22)),
            ("couronne chrono  droite", (0.20, 0.34, 0.78, 0.98)),
            ("couronne vitesse gauche", (0.54, 0.66, 0.04, 0.24)),
            ("couronne vitesse droite", (0.54, 0.66, 0.76, 0.96))]:
        z = img[int(h * y0):int(h * y1), int(w * x0):int(w * x1)]
        verdict(nom, mesure(z))


def main():
    if len(sys.argv) > 1:
        sonde_capture(sys.argv[1])
        return
    xs, ys, r = champ()
    v1 = recettes(xs, ys, r)
    v2 = paliers(xs, ys, r)
    v3 = geometries()
    p1 = planche(v1, "tapis-recettes.png")
    p2 = planche(v2, "tapis-paliers.png")
    p3 = planche(v3, "tapis-geometrie.png")
    print("\nplanche recettes  -> %s" % p1)
    print("planche paliers   -> %s" % p2)
    print("planche geometrie -> %s" % p3)


if __name__ == "__main__":
    main()
