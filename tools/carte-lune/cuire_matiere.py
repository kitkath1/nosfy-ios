#!/usr/bin/env python3
"""LA MATIÈRE D'UNE LÉGENDAIRE — le kit cuit, carte en main (30-09-2026).

Ce que la maquette du 20-09 (`maquette-legendaire-2026-09-20/maquette.py`)
calculait à chaque image en Python, cuit UNE fois par carte, pour le shader
`carteLuneV6` (Nosfy/CarteLune.metal). Tout est dérivé de l'illustration
publiée — aucune coordonnée écrite pour une carte précise — et le monde vient
du catalogue (`profondeur/publiees.json`).

Trois cartes dans l'espace du CANVAS composé (1086×1448, le cadre posé,
exactement comme `LuneForge.composer`), réunies dans UN atlas
`<nom>-matiere.png` de 2172×2172 — SwiftUI refuse plus de trois textures
par passage (« Too many texture arguments », payé au banc le 30-09) :

    en haut à gauche   le RELIEF   R, G la normale de la gravure (0,5 = plat)
                                   B son poids : la matière de la peinture
                                   (poil, bois, écailles), le filigrane du
                                   cadre argent et de ses croissants
    en haut à droite   la VIE      R les sources du feu (les pixels chauds)
                                   G le ciel (sombre et lisse) : paillettes
                                   B les éclats (reliefs clairs de la créature)
    en bas à gauche    le SOUFFLE  R le sujet (détourage du kit, sinon deviné)
      (demi-taille)                G la lueur des sources (qui respire)
                                   B les sources de nacre (les blancs froids)

et `<nom>-matiere.json` (référence, rareté, monde, centre du sujet, et le
chemin de l'illustration nue publiée — `poser_matiere_sim.sh` l'y prend).

Une carte non légendaire ne reçoit que le json : c'est la Trois Lunes
intacte du banc de comparaison.

    python3 cuire_matiere.py le-souverain          (un nom de publiees.json)
    python3 cuire_matiere.py --legendaires          (les légendaires publiées)
    python3 cuire_matiere.py le-passage             (une épique : illustration seule)
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.abspath(os.path.join(ICI, "..", ".."))
MEDIA = os.path.join(DEPOT, "Nosfy", "Media")
SORTIE = os.path.join(ICI, "matiere")

CW, CH = 1086, 1448
FEN = (0.118, 0.083, 0.881 - 0.118, 0.891 - 0.083)   # LuneForge.fenetre
MONDES = {"foret-des-veilles": 0, "cimes-eteintes": 1, "bois-sans-lune": 2}


def lum_of(rgb):
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def normalize(v):
    return v / (np.linalg.norm(v, axis=-1, keepdims=True) + 1e-9)


def fenetre_px():
    x, y = FEN[0] * CW, FEN[1] * CH
    return x, y, FEN[2] * CW, FEN[3] * CH


def composer(img, mode="RGB"):
    """L'aspect-fill de `LuneForge.composer` : centré dans la fenêtre,
    coupé à elle. Rend l'image au canvas et le masque de la fenêtre."""
    wx, wy, ww, wh = fenetre_px()
    s = max(ww / img.width, wh / img.height)
    tw, th = img.width * s, img.height * s
    img = img.convert(mode).resize((round(tw), round(th)), Image.LANCZOS)
    canvas = Image.new(mode, (CW, CH), 0)
    canvas.paste(img, (round(wx + ww / 2 - tw / 2), round(wy + wh / 2 - th / 2)))
    a = np.asarray(canvas).astype(np.float32) / 255
    inwin = np.zeros((CH, CW), np.float32)
    inwin[round(wy):round(wy + wh), round(wx):round(wx + ww)] = 1
    if a.ndim == 3:
        return a * inwin[..., None], inwin
    return a * inwin, inwin


def brins(theta, longueur=14, graine=20260930):
    """LES BRINS DE LA CISELURE : un bruit blanc moyenné LE LONG du sens du
    poil (intégrale de convolution de lignes) — des traits continus de
    1-2 px qui suivent la peinture. La maquette projetait une onde sur les
    coordonnées absolues de l'image : dès que le sens tourne, sa phase
    explose et les traits se cassent en SEL (payé au banc le 30-09).
    `theta` = orientation dominante du gradient ; le brin court à θ + 90°."""
    rng = np.random.default_rng(graine)
    bruit = ndi.gaussian_filter(rng.random((CH, CW)).astype(np.float32), 0.6)
    c2, s2 = np.cos(2 * theta), np.sin(2 * theta)      # champ π-périodique
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    acc = bruit.copy()
    poids = np.ones_like(bruit)
    for sens in (1.0, -1.0):
        x, y = xx.copy(), yy.copy()
        dx0, dy0 = -np.sin(theta) * sens, np.cos(theta) * sens
        for k in range(1, longueur + 1):
            c = ndi.map_coordinates(c2, [y, x], order=1, mode="nearest")
            s = ndi.map_coordinates(s2, [y, x], order=1, mode="nearest")
            t = 0.5 * np.arctan2(s, c)
            dx, dy = -np.sin(t), np.cos(t)
            flip = np.sign(dx * dx0 + dy * dy0 + 1e-6)          # garder le cap
            dx, dy = dx * flip, dy * flip
            x, y = x + dx, y + dy
            w = 1.0 - k / (longueur + 1)                          # fenêtre douce
            acc += w * ndi.map_coordinates(bruit, [y, x], order=1, mode="nearest")
            poids += w
            dx0, dy0 = dx, dy
    lic = acc / poids
    m = ndi.gaussian_filter(lic, 6.0)
    sd = np.sqrt(ndi.gaussian_filter((lic - m) ** 2, 6.0)) + 1e-4
    return np.clip((lic - m) / sd, -2.5, 2.5) / 2.5


def croissants(n=4):
    """Les lunes de rareté de `LuneForge.lunes` (même géométrie) : elles
    entrent dans le filigrane, rainurées comme le cadre."""
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    r, y = 7.0, 1316.0
    m = np.zeros((CH, CW), np.float32)
    for i in range(n):
        cx = 212.0 + i * 24
        a = (xx - cx) ** 2 + (yy - y) ** 2 <= r * r
        b = (xx - (cx + r * 0.42)) ** 2 + (yy - (y - r * 0.30)) ** 2 <= r * r
        m += (a & ~b).astype(np.float32)
    return m


def noms(cle):
    """Les noms FR/EN d'une carte ou d'un monde, lus dans le catalogue des
    familles (la cérémonie grave le nom sous la carte)."""
    d = json.load(open(os.path.join(ICI, "familles-2026-09-18.json")))
    trouve = []

    def fouiller(x):
        if isinstance(x, dict):
            if x.get("key") == cle and isinstance(x.get("name"), dict):
                trouve.append(x["name"])
            for v in x.values():
                fouiller(v)
        elif isinstance(x, list):
            for v in x:
                fouiller(v)
    fouiller(d)
    return trouve[0] if trouve else {"fr": cle, "en": cle}


def cuire(entree):
    nom = entree["reference"].split("/")[1]
    rarete = entree["rarete"]
    monde = entree["monde"]
    dossier = os.path.join(SORTIE, nom)
    os.makedirs(dossier, exist_ok=True)
    source = os.path.join(DEPOT, entree["fichier"])
    meta = dict(reference=entree["reference"], nom=nom, rarete=rarete,
                monde=monde, monde_code=MONDES.get(monde, 0),
                illustration=entree.get("illustration", entree["fichier"]),
                noms=entree.get("noms") or noms(nom), monde_noms=noms(monde))
    if rarete != "legendary":
        json.dump(meta, open(os.path.join(dossier, f"{nom}-matiere.json"), "w"), indent=1)
        print(f"OK {nom} ({rarete}) : json seul (témoin sans matière)")
        return

    art, inwin = composer(Image.open(source))
    lum = lum_of(art)

    # — LE RELIEF (E1) : la pente de la peinture, plus une ciselure en BRINS
    #   qui suit le sens du poil (l'orientation du tenseur de structure),
    #   posée SEULEMENT là où la matière est cohérente — jamais le ciel.
    gx = ndi.sobel(ndi.gaussian_filter(lum, 1.2), axis=1)
    gy = ndi.sobel(ndi.gaussian_filter(lum, 1.2), axis=0)
    jxx = ndi.gaussian_filter(gx * gx, 4.0)
    jyy = ndi.gaussian_filter(gy * gy, 4.0)
    jxy = ndi.gaussian_filter(gx * gy, 4.0)
    tr = jxx + jyy
    det = jxx * jyy - jxy * jxy
    coher = 2 * np.sqrt(np.maximum(tr * tr / 4 - det, 0)) / (tr + 1e-6)
    theta = 0.5 * np.arctan2(2 * jxy, jxx - jyy)
    detail = ndi.gaussian_filter(np.hypot(gx, gy), 5.0)
    chemin_sujet = os.path.join(ICI, "profondeur", nom, f"{nom}-sujet.png")
    if not os.path.exists(chemin_sujet):
        # UNE NOUVELLE CARTE (les légendaires à venir, dont personne ne
        # connaît le dessin) : le détourage se fait ici, par rembg, comme le
        # kit du 20-09 (cuire_profondeur.detourer) — sinon il est deviné.
        try:
            from rembg import remove
            alpha = remove(Image.open(source).convert("RGBA")).getchannel("A")
            os.makedirs(os.path.dirname(chemin_sujet), exist_ok=True)
            alpha.save(chemin_sujet)
            print(f"   {nom} : détourage fait par rembg")
        except Exception as e:
            print(f"   {nom} : pas de détourage ({e}) — sujet deviné")
    if os.path.exists(chemin_sujet):
        sujet, _ = composer(Image.open(chemin_sujet), mode="L")
        sujet = (sujet > 0.5).astype(np.float32)
    else:
        sujet = None
    # « Texturé » se mesure à la carte : le détail médian de SA créature
    # (le cerf 0,17, le dragon 0,19, le Grand Silence 0,08 — mesuré le 30-09).
    # Un seuil absolu, calé sur le cerf, étouffait la peinture la plus noire.
    zone_ref = (sujet > 0.5) & (inwin > 0) if sujet is not None else inwin > 0
    echelle = max(0.05, 0.6 * float(np.median(detail[zone_ref])))
    # Le seuil de luminance descend AU NOIR PRÈS : les créatures sont peintes
    # très sombres (le cerf : luminance médiane 0,064, mesurée le 30-09) et
    # le seuil de la maquette (0,04 → 0,12) effaçait toute leur gravure.
    matiere = np.clip((detail - 0.04) / echelle, 0, 1)
    matiere *= np.clip((lum - 0.005) / 0.03, 0, 1)
    matiere *= np.clip((0.92 - lum) / 0.15, 0, 1)
    matiere *= np.clip((coher - 0.22) / 0.30, 0, 1)
    matiere = ndi.gaussian_filter(matiere, 3.5) * inwin

    # — LE SUJET (le vrai détourage du kit s'il existe, sinon deviné)
    if sujet is not None:
        origine_sujet = "détourage du kit"
    else:
        suj = ndi.gaussian_filter(matiere, 14.0) > 0.16
        lab, nlab = ndi.label(suj)
        if nlab:
            tailles = ndi.sum(suj, lab, range(1, nlab + 1))
            suj = ndi.binary_fill_holes(lab == (int(np.argmax(tailles)) + 1))
        sujet = suj.astype(np.float32)
        origine_sujet = "deviné (matière dense)"
    sujet_net = sujet * inwin

    # La gravure est PLEINE sur la créature (le héros de la carte), à 35 %
    # sur le paysage — et la ciselure suit la même règle.
    zone = 0.35 + 0.65 * ndi.gaussian_filter(sujet_net, 3.0)
    h = 2.0 * ndi.gaussian_filter(lum, 2.2) + 1.6 * brins(theta) * matiere * zone
    n_art = normalize(np.dstack([-ndi.sobel(h, axis=1) / 8,
                                 -ndi.sobel(h, axis=0) / 8, np.ones_like(h)]))
    poids_art = matiere * zone

    # — LE FILIGRANE (E6) : le cadre argent et ses quatre croissants en
    #   rainure — la même lampe, un flanc s'allume, l'autre s'éteint.
    c = np.asarray(Image.open(os.path.join(MEDIA, "carte-cadre-legendaire.png"))
                   .convert("RGBA")).astype(np.float32) / 255
    cadre_a = np.clip(c[..., 3] + croissants(), 0, 1)
    # Le relief du cadre déborde d'un pixel ou deux de chaque filet argent :
    # à σ 0,8 et ×6 (la maquette), le flanc allumé restait SUR le filet déjà
    # clair et ne se voyait pas (planche du 30-09) ; à σ 1,4 et ×10, un
    # cheveu de lumière longe le filet du côté qui fait face.
    hc = ndi.gaussian_filter(lum_of(c[..., :3]) * c[..., 3] + croissants() * 0.9, 1.4) * 10.0
    n_cadre = normalize(np.dstack([-ndi.sobel(hc, axis=1) / 8,
                                   -ndi.sobel(hc, axis=0) / 8, np.ones_like(hc)]))
    w = np.clip(cadre_a * 3, 0, 1)
    n = normalize(n_art * (1 - w[..., None]) + n_cadre * w[..., None])
    poids = np.clip(poids_art * (1 - w) + 0.85 * w, 0, 1)
    relief = np.dstack([n[..., 0] * 0.5 + 0.5, n[..., 1] * 0.5 + 0.5, poids])


    # — LA VIE : sources du feu, ciel des paillettes, éclats de la créature
    r, g, b = art[..., 0], art[..., 1], art[..., 2]
    chaud = ((r > 0.55) & (r - b > 0.30) & (inwin > 0)).astype(np.float32)
    lisse = ndi.gaussian_filter(np.hypot(gx, gy), 3.0)
    # Le ciel des paillettes : sombre et lisse, JAMAIS la créature (son flanc
    # noir est lisse aussi — des étoiles sur un cerf, c'est du bruit).
    ciel_net = ((lum < 0.55) & (lisse < 0.07)).astype(np.float32) * inwin
    ciel_net *= 1.0 - ndi.binary_dilation(sujet_net > 0.5, iterations=4)
    ciel = ndi.gaussian_filter(ciel_net, 2.0)
    eclats = np.clip((lum - 0.30) / 0.30, 0, 1) * np.clip(detail / 0.10, 0, 1) * inwin
    # Un ASTRE n'est pas un feu (la lune orange du cerf ne crache pas de
    # braises) : une tache chaude hors de la créature, dans le haut de la
    # fenêtre, ISOLÉE (aucun autre feu à 60 px) et assez grande pour être
    # un disque. Les petites braises peintes dans un ciel restent du feu.
    lab, nlab = ndi.label(ndi.binary_dilation(chaud > 0.5, iterations=3))
    wy_haut = FEN[1] * CH + 0.45 * FEN[3] * CH
    astres = 0
    for i in range(1, nlab + 1):
        tache = lab == i
        ys_t, _ = np.nonzero(tache)
        voisins = ndi.binary_dilation(tache, iterations=60) & (lab > 0) & ~tache
        if (tache.sum() > 300 and ys_t.mean() < wy_haut and not voisins.any()
                and (sujet_net[tache] > 0.5).mean() < 0.2):
            chaud[tache] = 0
            astres += 1
    vie = np.dstack([ndi.gaussian_filter(chaud, 1.0), ciel, eclats])

    sujet = ndi.gaussian_filter(sujet, 10.0) * inwin
    ys, xs = np.nonzero(sujet > 0.5)
    centre = (float(xs.mean()) / CW, float(ys.mean()) / CH) if len(xs) else (0.5, 0.5)
    sat = art.max(-1) - art.min(-1)
    # La nacre naît des blancs froids de CETTE peinture : ses 1,5 % les plus
    # clairs (au moins 0,30) — une carte presque noire a aussi ses blancs.
    seuil_nacre = max(0.30, float(np.percentile(lum[inwin > 0], 98.5)))
    nacre = ndi.gaussian_filter(((lum > seuil_nacre) & (sat < 0.15)
                                 & (inwin > 0)).astype(np.float32), 1.0)
    souffle = np.dstack([sujet, np.clip(ndi.gaussian_filter(chaud, 4.5), 0, 1), nacre])
    souffle_img = Image.fromarray((np.clip(souffle, 0, 1) * 255 + 0.5).astype(np.uint8))
    souffle_img = souffle_img.resize((CW // 2, CH // 2), Image.BILINEAR)

    def octets(a):
        return (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)

    atlas = np.zeros((CH + CH // 2, 2 * CW, 3), np.uint8)
    atlas[:CH, :CW] = octets(relief)
    atlas[:CH, CW:] = octets(vie)
    atlas[CH:, :CW // 2] = np.asarray(souffle_img)
    Image.fromarray(atlas).save(os.path.join(dossier, f"{nom}-matiere.png"), optimize=True)
    meta.update(centre=[round(centre[0], 4), round(centre[1], 4)],
                sujet=origine_sujet, astres_ecartes=astres,
                part_matiere=round(float((poids_art > 0.2).mean()), 4),
                part_feu=round(float((chaud > 0.5).mean()), 4),
                part_ciel=round(float((ciel > 0.5).mean()), 4),
                part_nacre=round(float((nacre > 0.5).mean()), 4))
    json.dump(meta, open(os.path.join(dossier, f"{nom}-matiere.json"), "w"), indent=1)
    print(f"OK {nom} ({monde}) : atlas relief + vie + souffle · sujet {origine_sujet} · "
          f"matière {meta['part_matiere']:.1%} · feu {meta['part_feu']:.2%} · "
          f"ciel {meta['part_ciel']:.1%} · nacre {meta['part_nacre']:.2%}")


def main():
    publiees = json.load(open(os.path.join(ICI, "profondeur", "publiees.json")))
    par_nom = {e["reference"].split("/")[1]: e for e in publiees}
    if "--legendaires" in sys.argv:
        noms = [n for n, e in par_nom.items() if e["rarete"] == "legendary"]
    else:
        noms = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not noms:
        sys.exit(__doc__)
    for nom in noms:
        if nom not in par_nom:
            sys.exit(f"inconnu : {nom} (publiées : {', '.join(par_nom)})")
        cuire(par_nom[nom])


if __name__ == "__main__":
    main()
