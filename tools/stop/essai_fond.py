#!/usr/bin/env python3
"""
essai_fond.py — INVERSER LE MUR : le noir derrière la bête, le gris au sol.

Idée de Kathryn (29-08) : le glitch des oreilles ne se voit QUE parce que le
mur est clair juste derrière elles. Silhouette statique + oreilles qui bougent
= un écart à chaque image ; sur du noir, cet écart n'existe plus. On met donc
le quasi-noir en haut (derrière le mot et la bête) et on fait monter le gris
du BAS de la card.

Ce script compose le rendu EXACT, sans builder : le mur, le mot (Inter-Bold
128 avec ses trois masques), le masque de la bête, la vidéo, et le cône du
spot en `.screen`. Il rend la card à la taille RÉELLE du téléphone
(314 × 455 pt), pas à celle du plan.

⚠️ Il ne remplace pas un verdict à l'écran : la poudre, le liseré, l'ombre
blanche et le balayage vivant n'y sont pas. Il sert à TRANCHER UN FOND.
"""
import os, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy import ndimage as ndi

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MP4 = f"{REPO}/Woop/Media/stop-bat-loop.mp4"
MASK = f"{REPO}/Woop/Assets.xcassets/stop-bat-masque.imageset/stop-bat-masque.png"
FONT = f"{REPO}/Woop/Fonts/Inter-Bold.otf"
VIG = f"{REPO}/tools/stop/vignettes"
SW, SH = 1080, 1562                     # la vidéo livrée
ECH = 3.07                              # px/pt du téléphone (iPhone 17 Pro)
LPT, HPT = 314.0, 455.0                 # la card RÉELLE : min(0,80·393, 332)
W, H = int(LPT * ECH), int(HPT * ECH)
CENTRE_MOT = 112.0                      # pt, absolu (le texte ne suit pas la card)


def gradient(stops):
    y = np.linspace(0, 1, H)
    return np.interp(y, [s[0] for s in stops], [s[1] for s in stops])


def lisse(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


# ── LE MOT « STOP » — Inter-Bold 128 pt, tracking −3, et ses trois masques ─
def mot_alpha():
    corps = int(round(128 * ECH))
    f = ImageFont.truetype(FONT, corps)
    tr = int(round(-3 * ECH))                       # tracking négatif
    lettres = "STOP"
    larg = [f.getbbox(c)[2] - f.getbbox(c)[0] for c in lettres]
    total = sum(larg) + tr * (len(lettres) - 1)
    # Une image large : le mot déborde la card, c'est voulu (le plan : 342 pt
    # pour 332) — ce sont les flancs qui le rognent, pas une réduction.
    im = Image.new("L", (max(total + 200, W), int(corps * 1.6)), 0)
    d = ImageDraw.Draw(im)
    x = (im.width - total) // 2
    haut = corps * 0.25
    for c, lw in zip(lettres, larg):
        bb = f.getbbox(c)
        d.text((x - bb[0], haut), c, font=f, fill=255)
        x += lw + tr
    a = np.asarray(im).astype(float) / 255.0
    ys = np.where(a.max(axis=1) > 0.02)[0]
    y0, y1 = ys.min(), ys.max()
    # 1. LE DÉGRADÉ PROPRE DU MOT : 0,40 → 0,17 → 0,06, du haut au bas des
    #    glyphes. C'est LUI le « fondu » — jamais une opacité globale baissée.
    g = np.interp(np.arange(a.shape[0]), [y0, (y0 + y1) / 2, y1], [0.40, 0.17, 0.06])
    a = a * g[:, None]
    # On recale le mot dans la card : son centre à CENTRE_MOT (absolu).
    cible = int(round(CENTRE_MOT * ECH))
    plein = np.zeros((H, W))
    dy = cible - (y0 + y1) // 2
    dx = (W - a.shape[1]) // 2
    for yy in range(a.shape[0]):
        ty = yy + dy
        if 0 <= ty < H:
            src = a[yy]
            if dx >= 0:
                plein[ty, dx:dx + a.shape[1]] = src[:W - dx]
            else:
                plein[ty] = src[-dx:-dx + W]
    # 2. LE FONDU DU CONTENEUR (vertical) et 3. LES FLANCS — les deux masques
    #    hôtes de TexteGeant, en fractions de la CARD.
    yv = np.linspace(0, 1, H)
    vert = np.interp(yv, [0, .42, .66, .82, .92], [1, .92, .45, .12, 0])
    flanc = np.interp(np.linspace(0, 1, W), [0, .24, .76, 1], [0, 1, 1, 0])
    return plein * vert[:, None] * flanc[None, :]


# ── LE CÔNE DU SPOT (LampeEventail au repos, balayage 0) ───────────────────
def cone():
    out = np.zeros((H, W))
    for haut_pt, a0, a1, flou, etroit in ((196, .33, .10, 13, 1.0),
                                          (148, .50, .15, 9, 0.55)):
        hp = int(haut_pt * ECH)
        im = Image.new("L", (W, hp), 0)
        d = ImageDraw.Draw(im)
        mx = W / 2
        d.polygon([(mx - 30 * ECH * etroit, 0), (mx + 30 * ECH * etroit, 0),
                   (mx + 118 * ECH * etroit, hp), (mx - 118 * ECH * etroit, hp)],
                  fill=255)
        im = im.filter(ImageFilter.GaussianBlur(flou * ECH / 3.253))
        a = np.asarray(im).astype(float) / 255.0
        vy = np.interp(np.linspace(0, 1, hp), [0, .5, 1], [a0, a1, 0])
        vx = np.interp(np.linspace(0, 1, W), [.04, .30, .70, .96], [0, 1, 1, 0])
        out[:hp] += a * vy[:, None] * np.clip(vx, 0, 1)[None, :]
    # La bouche : le trait de lumière sous la fente.
    im = Image.new("L", (W, H), 0)
    ImageDraw.Draw(im).rounded_rectangle(
        [W / 2 - 22 * ECH, 8 * ECH, W / 2 + 22 * ECH, 10 * ECH], radius=ECH, fill=140)
    out += np.asarray(im.filter(ImageFilter.GaussianBlur(2 * ECH))).astype(float) / 255.0
    return np.clip(out, 0, 1)


# ── LA VIDÉO et LE MASQUE, ramenés à la card réelle ────────────────────────
p = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", MP4,
                    "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True)
n = SW * SH * 3
frames = [np.frombuffer(p.stdout[i * n:(i + 1) * n], np.uint8).reshape(SH, SW, 3)
          for i in range(len(p.stdout) // n)]
alpha_src = np.asarray(Image.open(MASK).convert("RGBA"))[..., 3].astype(float) / 255.0
# L'image où les oreilles débordent LE PLUS : c'est là que ça casse.
deb = [int(((f.max(axis=2) > 12) & (alpha_src > 0.5)).sum()) for f in frames]
ipire = int(np.argmax(deb))
print(f"{len(frames)} images ; débordement des oreilles : médiane "
      f"{int(np.median(deb))} px, pire {max(deb)} px (image {ipire})")


def vers_card(a, couleur=False):
    im = Image.fromarray(a if couleur else (a * 255).astype(np.uint8))
    return np.asarray(im.resize((W, H), Image.LANCZOS)).astype(float) / (1 if couleur else 255.0)


video = vers_card(frames[ipire], couleur=True)
amask = vers_card(alpha_src)
mot = mot_alpha()
spot = cone()
dist = ndi.distance_transform_edt(amask > 0.5)   # px depuis le trou de la bête

FONDS = {
    "A — actuel (crête grise à 26 %)":
        [(0, .012), (.09, .062), (.26, .125), (.44, .098), (.68, .045),
         (.90, .010), (1, 0)],
    "B — inversé, lueur de sol BASSE":
        [(0, .006), (.35, .012), (.60, .045), (.72, .062), (.84, .028), (1, .008)],
    "C — inversé, lueur de sol PLUS HAUTE":
        [(0, .008), (.30, .022), (.55, .080), (.70, .105), (.85, .050), (1, .012)],
}

vign = []
for titre, stops in FONDS.items():
    mur_v = gradient(stops)[:, None] * np.ones((1, W))
    for lettres_meurent in ((False, True) if titre.startswith("B") else (False,)):
        m = mot.copy()
        if lettres_meurent:
            # LES LETTRES MEURENT EN APPROCHANT D'ELLE (dégradé de 22 pt) :
            # une lettre ne vient plus toucher un bord d'oreille, donc l'erreur
            # de contour n'a plus rien à découper. Ça se lit comme son ombre
            # portée sur le lettrage.
            m = m * lisse(dist / (22 * ECH))
        # le mur = fond + mot (le mot est SUR le fond, avec sa propre alpha)
        mur = mur_v[:, :, None] * (1 - m[:, :, None]) + 1.0 * m[:, :, None]
        # la card = mur masqué PAR-DESSUS la vidéo
        card = mur * amask[:, :, None] + (video / 255.0) * (1 - amask[:, :, None])
        # le cône, en SCREEN, par-dessus tout et SANS masque
        card = 1 - (1 - card) * (1 - spot[:, :, None])
        vign.append(((titre + (" + lettres qui meurent" if lettres_meurent else "")),
                     (np.clip(card, 0, 1) * 255).astype(np.uint8)))

# LA PLANCHE — on ne montre QUE la moitié haute : c'est là que tout se joue,
# et le bas de cette maquette est vide (ni titre, ni slider, ni poudre : ils
# demandent un build). Deux rangées : la scène, puis le zoom sur les oreilles
# — le seul endroit où le détourage se juge.
tw = int(W * 0.78)
th = int(H * 0.62 * 0.78)
zh = int(th * 0.78)
ETIQ = ["A - actuel (crete grise a 26%)", "B - inverse, lueur de sol BASSE",
        "B + lettres qui meurent pres d'elle", "C - inverse, lueur PLUS HAUTE"]
planche = Image.new("RGB", (tw * len(vign), th + zh + 34), (16, 16, 16))
d = ImageDraw.Draw(planche)
try:
    petite = ImageFont.truetype(f"{REPO}/Woop/Fonts/Inter-Medium.otf", 19)
except Exception:
    petite = None
for k, (_, im) in enumerate(vign):
    planche.paste(Image.fromarray(im[:int(0.62 * H)]).resize((tw, th), Image.LANCZOS),
                  (k * tw, 0))
    z = im[int(0.09 * H):int(0.30 * H), int(0.20 * W):int(0.80 * W)]
    planche.paste(Image.fromarray(z).resize((tw, zh), Image.LANCZOS), (k * tw, th))
    d.text((k * tw + 10, th + zh + 9), ETIQ[k], fill=(200, 200, 200), font=petite)
    d.line([(k * tw, 0), (k * tw, th + zh)], fill=(60, 60, 60))
out = f"{VIG}/stop-essai-fond.png"
planche.save(out)
for t, _ in vign:
    print(f"  · {t}")
print(f"planche → {out}")
