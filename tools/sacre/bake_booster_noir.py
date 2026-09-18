#!/usr/bin/env python3
"""LE BAKE DE LA ROBE NOIRE — les deux dessins de Kathryn → l'atlas du maillage.

Le maillage `booster.bin` lit UNE texture 2048² qui porte les DEUX peaux du
sachet côte à côte. Les rectangles sont MESURÉS sur l'atlas jaune existant
(`Nosfy/Media/booster-color.png`, le reste de l'image est du noir pur) :

    FACE : colonnes 722 → 1317, lignes 57 → 1989   (596 × 1933)
    DOS  : colonnes 1428 → 2023, lignes 57 → 1989  (596 × 1933)

LA RECETTE, retrouvée sur l'atlas jaune et VÉRIFIÉE (corrélation 0,90 sur la
face, après flou — les fins néons ne se corrèlent pas au pixel) :

    1. rogner le dessin sur sa SILHOUETTE (le fond noir autour ne compte pas)
    2. RETOURNER verticalement (l'origine UV du maillage est en bas)
    3. étirer sur le rectangle du panneau (596 × 1933) — l'étirement est
       ÉNORME (ratio 0,58 → 0,31) et c'est NORMAL : le nœud du sachet porte
       une échelle (0,75 · 1 · 0,45) qui rend au dessin ses proportions.
    4. coller, le reste de l'atlas reste noir pur.

⚠️ LE DOS NOIR N'EST PAS UN SACHET, C'EST UNE TRAME. Là où `dos_booster.png`
(le jaune) était un dos de sachet complet — sertissages, liseré, trame à
l'intérieur —, `dos_booster_noir.png` est une trame de croissants PLEIN
CADRE : ni bord, ni sertissage. Or les sertissages sont IMPRIMÉS dans la
texture (le maillage a leur relief, pas leur dessin). On COMPOSE donc le dos :
la menuiserie (sertissages + liseré irisé + bords du sachet) vient de la FACE
noire, la trame remplit l'intérieur. C'est ce qui donne un dos cohérent avec
la face, et avec le dos jaune.

L'ÉMISSIVE : le liseré du sachet jaune est un NÉON (il émet) ; celui du noir
est un FOIL IRISÉ (il réfléchit). On en tire quand même une émissive FAIBLE,
qui garde la couleur de l'irisation : sans elle, un sachet noir sur un sol
d'encre disparaît dans l'anneau. Son intensité se règle ensuite côté matière
(`emission.intensity`, 0,6 pour le jaune) — le fichier, lui, reste doux.

Usage :  python3 tools/sacre/bake_booster_noir.py
Entrées : ~/Desktop/face_booster_noir.png, ~/Desktop/dos_booster_noir.png
Sorties : Nosfy/Media/booster-noir-color.png, Nosfy/Media/booster-noir-emiss.png
          tools/sacre/noir/preview-*.png (les planches de verdict)
"""

import os
from PIL import Image, ImageFilter
import numpy as np

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUREAU = os.path.expanduser("~/Desktop")
MEDIA = os.path.join(RACINE, "Nosfy", "Media")
SORTIE = os.path.join(RACINE, "tools", "sacre", "noir")

ATLAS = 2048
FACE_RECT = (722, 57, 1318, 1990)   # x0, y0, x1, y1 (exclusifs à droite/bas)
DOS_RECT = (1428, 57, 2024, 1990)
PANNEAU = (FACE_RECT[2] - FACE_RECT[0], FACE_RECT[3] - FACE_RECT[1])  # 596×1933


def silhouette(im, seuil=6):
    """Le rectangle du DESSIN, le fond noir écarté."""
    a = np.asarray(im.convert("L")).astype(float)
    m = a > seuil
    ys = np.where(m.any(axis=1))[0]
    xs = np.where(m.any(axis=0))[0]
    return int(xs[0]), int(ys[0]), int(xs[-1]) + 1, int(ys[-1]) + 1


def interieur(im, seuil=90, pad=0.014):
    """LE MASQUE DE L'INTÉRIEUR IMPRIMÉ (dedans le liseré), PAR SES BORDS.

    ⚠️ Une propagation depuis le centre sur les pixels sombres NE MARCHE PAS
    (essayée, mesurée) : le liseré irisé a des INTERRUPTIONS — les coins
    coupés, les languettes des flancs —, la tache s'échappe par une brèche et
    mange tout le sachet, sertissages compris. On a alors un dos entièrement
    trame, sans bord ni sertissage.

    On suit donc les BORDS eux-mêmes : par ligne, le pixel clair le plus à
    gauche dans le tiers gauche et le plus à droite dans le tiers droit. Une
    ligne sans bord (une brèche du liseré) HÉRITE de la précédente — les
    coins coupés sont suivis, les trous ne fuient pas. L'intérieur est ensuite
    rentré de `pad` pour ne jamais mordre le liseré.
    """
    L = np.asarray(im.convert("L")).astype(float)
    H, W = L.shape
    clair = L > seuil
    ys = np.where(clair.any(axis=1))[0]
    xs = np.where(clair.any(axis=0))[0]
    fy0, fy1, fx0, fx1 = int(ys[0]), int(ys[-1]), int(xs[0]), int(xs[-1])
    px, py = round(W * pad), round(H * pad * 0.5)

    gauche = np.full(H, -1)
    droite = np.full(H, -1)
    tiers = W // 3
    for y in range(H):
        g = np.where(clair[y, :tiers])[0]
        d = np.where(clair[y, W - tiers:])[0]
        if len(g):
            gauche[y] = g[0]
        if len(d):
            droite[y] = W - tiers + d[-1]
    # Les DEUX AUTRES bords, par colonne : sans eux le masque passe par-dessus
    # les traits HORIZONTAUX du liseré (cadre ouvert en haut et en bas, vu à
    # la première planche) et déborde sur les sertissages.
    haut = np.full(W, -1)
    bas = np.full(W, -1)
    tiersH = H // 3
    for x in range(W):
        h = np.where(clair[:tiersH, x])[0]
        b = np.where(clair[H - tiersH:, x])[0]
        if len(h):
            haut[x] = h[0]
        if len(b):
            bas[x] = H - tiersH + b[-1]

    def combler(v):
        """Une ligne sans bord hérite de la plus proche qui en a un."""
        dernier = -1
        for i in range(len(v)):
            if v[i] >= 0:
                dernier = v[i]
            elif dernier >= 0:
                v[i] = dernier
        dernier = -1
        for i in range(len(v) - 1, -1, -1):
            if v[i] >= 0:
                dernier = v[i]
            elif dernier >= 0:
                v[i] = dernier
        return v

    gauche, droite = combler(gauche), combler(droite)
    # LES TRAITS HORIZONTAUX SE TROUVENT PAR LES RAILS, PAS PAR LE HAUT.
    # Le sertissage cranté est CLAIR lui aussi (métal qui accroche la
    # lumière) : le premier pixel clair d'une colonne est presque toujours une
    # dent, pas le liseré — le masque montait dans le sertissage et y semait
    # des croissants (deux planches payées). On repère donc le rail gauche
    # (position médiane du bord sur les lignes du milieu), et l'étendue
    # verticale du cadre est la plage CONTIGUË de lignes où ce rail est là.
    rail = int(np.median(gauche[H // 4:3 * H // 4]))
    tol = max(6, round(W * 0.05))
    sur_rail = np.abs(gauche - rail) < tol
    y_haut, y_bas = H // 2, H // 2
    while y_haut > 0 and sur_rail[y_haut - 1]:
        y_haut -= 1
    while y_bas < H - 1 and sur_rail[y_bas + 1]:
        y_bas += 1

    masque = np.zeros((H, W), bool)
    for y in range(max(fy0, y_haut + py), min(fy1 + 1, y_bas - py + 1)):
        a, b = gauche[y] + px, droite[y] - px
        if 0 <= a < b < W:
            masque[y, a:b + 1] = True
    return masque


def poser(atlas, dessin, rect):
    """Rogner sur la silhouette → retourner → étirer → coller."""
    d = dessin.crop(silhouette(dessin))
    d = d.transpose(Image.FLIP_TOP_BOTTOM).resize(PANNEAU, Image.LANCZOS)
    atlas.paste(d, (rect[0], rect[1]))


def main():
    face = Image.open(os.path.join(BUREAU, "face_booster_noir.png")).convert("RGB")
    trame = Image.open(os.path.join(BUREAU, "dos_booster_noir.png")).convert("RGB")
    os.makedirs(SORTIE, exist_ok=True)

    # ---- le DOS composé : la menuiserie de la face, la trame dedans ----
    plaque = face.crop(silhouette(face))
    masque = interieur(plaque)
    ys = np.where(masque.any(axis=1))[0]
    xs = np.where(masque.any(axis=0))[0]
    boite = (int(xs[0]), int(ys[0]), int(xs[-1]) + 1, int(ys[-1]) + 1)
    # La trame REMPLIT l'intérieur en gardant son échelle de motif : on la
    # couvre (cover), on centre, on ne l'étire pas — un croissant ovale se
    # verrait (c'est la faute du sachet jaune qu'on ne refait pas).
    bw, bh = boite[2] - boite[0], boite[3] - boite[1]
    k = max(bw / trame.width, bh / trame.height)
    t = trame.resize((max(1, round(trame.width * k)), max(1, round(trame.height * k))),
                     Image.LANCZOS)
    ox, oy = (t.width - bw) // 2, (t.height - bh) // 2
    t = t.crop((ox, oy, ox + bw, oy + bh))

    dos = plaque.copy()
    a_dos = np.asarray(dos).copy()
    a_t = np.zeros_like(a_dos)
    a_t[boite[1]:boite[3], boite[0]:boite[2]] = np.asarray(t)
    a_dos[masque] = a_t[masque]
    dos = Image.fromarray(a_dos)

    # ---- l'atlas couleur ----
    atlas = Image.new("RGB", (ATLAS, ATLAS), (0, 0, 0))
    poser(atlas, face, FACE_RECT)
    poser(atlas, dos, DOS_RECT)
    atlas.save(os.path.join(MEDIA, "booster-noir-color.png"))

    # ---- l'émissive : l'irisation seule, douce, sa couleur gardée ----
    # LE CALIBRAGE EST MESURÉ SUR LE JAUNE, pas choisi au jugé : `booster-emiss`
    # est un fichier SOMBRE (moyenne 0,8, p99 = 38) — c'est un fil de néon, pas
    # une nappe. Une première passe à seuil 70 sans atténuation rendait une
    # émissive noire trois fois plus chaude que le néon jaune (moyenne 2,5,
    # p99 = 97) : le sachet noir aurait ÉMIS plus que celui qui a des néons
    # dessinés. Seuil haut + force basse ramènent son profil sur celui du
    # jaune, `emission.intensity = 0,6` reste donc valable sans retoucher la
    # matière.
    SEUIL, FORCE = 95.0, 0.42
    a = np.asarray(atlas).astype(float)
    L = a.max(axis=2)
    gain = np.clip((L - SEUIL) / 90.0, 0, 1)[..., None] * FORCE
    emiss = Image.fromarray((a * gain).astype(np.uint8))
    emiss = emiss.filter(ImageFilter.GaussianBlur(1.2))
    emiss.save(os.path.join(MEDIA, "booster-noir-emiss.png"))
    e = np.asarray(emiss.convert("L")).astype(float)
    print("émissive : moyenne %.2f  p99 %.0f   (le jaune : 0,80 et 38)"
          % (e.mean(), np.percentile(e, 99)))

    # ---- LA VIGNETTE (la pill du profil, le panneau) ----
    # `booster-pill.png` (120×214) est un rendu du sachet JAUNE, composé en
    # `plusLighter` : son fond noir disparaît tout seul et il ne reste que
    # ses néons. Le sachet noir n'a pas de néon — en `plusLighter` il ne
    # resterait de lui que le filet irisé, invisible à 15×26 pt. La vignette
    # noire porte donc un ALPHA (silhouette découpée par la luminance,
    # rebouchée ligne par ligne, adoucie d'un pixel) et se compose
    # normalement. Un gain de 1,5 la rend lisible à cette taille sans la
    # sortir du noir : à 20 px de large, un objet vraiment noir sur un verre
    # sombre n'est plus un objet, c'est un trou.
    boiteVignette = silhouette(face)
    vign = face.crop(boiteVignette)
    lum = np.asarray(vign.convert("L")).astype(float)
    masque = lum > 6
    for y in range(masque.shape[0]):
        xs = np.where(masque[y])[0]
        if len(xs):
            masque[y, xs[0]:xs[-1] + 1] = True
    rgb = np.clip(np.asarray(vign).astype(float) * 1.5, 0, 255)
    a = np.concatenate([rgb, (masque * 255)[..., None]], axis=2)
    pill = Image.fromarray(a.astype(np.uint8))
    pill = pill.filter(ImageFilter.SMOOTH)
    kVignette = min(120 / pill.width, 214 / pill.height)
    pill = pill.resize((max(1, round(pill.width * kVignette)),
                        max(1, round(pill.height * kVignette))), Image.LANCZOS)
    plaque = Image.new("RGBA", (120, 214), (0, 0, 0, 0))
    plaque.paste(pill, ((120 - pill.width) // 2, (214 - pill.height) // 2))
    plaque.save(os.path.join(MEDIA, "booster-pill-noir.png"))

    # ---- les planches de verdict ----
    # Les panneaux REDRESSÉS (dé-étirés au ratio du dessin) : c'est ce que
    # l'œil verra sur le sachet, pas le panneau étiré de l'atlas.
    for nom, rect in (("face", FACE_RECT), ("dos", DOS_RECT)):
        p = atlas.crop(rect).transpose(Image.FLIP_TOP_BOTTOM)
        p = p.resize((620, round(620 / 0.577)), Image.LANCZOS)
        p.save(os.path.join(SORTIE, "preview-%s.png" % nom))
        e = emiss.crop(rect).transpose(Image.FLIP_TOP_BOTTOM)
        e.resize((620, round(620 / 0.577)), Image.LANCZOS).save(
            os.path.join(SORTIE, "preview-%s-emiss.png" % nom))
    print("atlas :", os.path.join(MEDIA, "booster-noir-color.png"))
    print("émissive :", os.path.join(MEDIA, "booster-noir-emiss.png"))
    print("intérieur du dos :", boite, "trame ×%.3f" % k)


if __name__ == "__main__":
    main()
