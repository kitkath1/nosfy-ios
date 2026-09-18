#!/usr/bin/env python3
"""LA CUISSON DES DEUX PIÈCES — chantier coffre v2, jalon C1.

Kathryn livre deux tours de manège rendus par IA (`gold_glass_piece.mp4`,
`silver_glass_piece.mp4`). Ils ont le même DESSIN, et trois défauts mesurés
qu'aucun réglage d'affichage ne rattrape — il faut les recuire.

LES TROIS DÉFAUTS, MESURÉS (proxy 468 px de large, seuil 10/255) :

  |                    | OR              | ARGENT          |
  |--------------------|-----------------|-----------------|
  | images             | 145             | 145             |
  | diamètre (hauteur) | 250 px          | 390 px  (×1,56) |
  | dérive du centre x | 14 px           | 30 px           |
  | dérive du centre y | 1 px            | 1 px            |
  | tranches aux images| 31 · 74 · 114   | 36 · 98         |
  | demi-tour          | ~41,5 images    | ~62 images      |

  1. **PAS LA MÊME TAILLE** — l'argent occupe 56 % de plus dans le cadre.
  2. **PAS LA MÊME VITESSE** — un tour complet vaut 83 images pour l'or et 124
     pour l'argent. Posées côte à côte, elles se désynchronisent en trois
     secondes.
  3. **ELLES DÉRIVENT LATÉRALEMENT** — jusqu'à 30 px, soit 8 % du diamètre.
     Sous le doigt, ça se lit comme un tremblement.

  Et un quatrième, plus sournois : **la vitesse de l'or n'est même pas
  constante** (43 images entre deux tranches, puis 40).

LA MÉTHODE — ON NE RECADRE PAS, ON RE-CHRONOMÈTRE.

  La largeur projetée d'un disque en lacet vaut `D·|cos θ|`, plus l'épaisseur
  du chant qui, elle, ne disparaît jamais. On mesure donc, image par image,
  la largeur ; on en DÉDUIT l'angle ; on déroule cet angle en continu (il
  franchit 90° à chaque tranche) ; puis on RE-ÉCHANTILLONNE sur une grille
  d'angles régulière. Le film de sortie tourne alors à vitesse rigoureusement
  constante — **et c'est le doigt qui fera la courbe**, jamais le fichier.

  Au passage, chaque image est recentrée sur le centre mesuré de la pièce et
  remise à l'échelle sur son diamètre : les deux pièces deviennent jumelles.

LE DÉTOURAGE. Le fond est à ZÉRO ABSOLU (vérifié : min 0, moyenne 0,000) donc
il n'y a rien à incruster. Mais la pièce est un objet SOMBRE : une alpha tirée
de la luminance la rendrait translucide et le sol clair de la chambre
traverserait sa face. On construit donc la silhouette par REMPLISSAGE — pour
chaque ligne, tout ce qui est entre le premier et le dernier pixel allumé
appartient à la pièce (exact pour une forme convexe, et un galet en est une) —
puis on adoucit le bord de deux pixels.

Sortie : une PLANCHE DE SPRITES PNG (grille de N cases carrées, alpha
prémultipliée) + un petit JSON de métadonnées. **On ne seeke jamais dans une
vidéo** (`DepartCine.swift:15-26` : 4 295 img/s demandées, 15 à 25 servies).

Usage :
    python3 recuit_pieces.py --src ~/Downloads/gold_glass_piece.mp4 \\
                             --nom piece-or --cases 96 --cote 384
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

SEUIL = 8.0


def _frames(src, larg, dossier):
    """Sort les images du film à une largeur de travail donnée."""
    subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", src,
         "-vf", f"scale={larg}:-1", os.path.join(dossier, "f-%04d.png")],
        check=True,
    )
    return sorted(
        os.path.join(dossier, f) for f in os.listdir(dossier) if f.endswith(".png")
    )


def _silhouette(L):
    """La silhouette pleine, par remplissage ligne à ligne puis colonne à
    colonne. Exact pour une forme convexe ; le croisement des deux passes
    rattrape les lignes où la pièce est coupée en deux par un reflet noir."""
    m = L > SEUIL
    plein = np.zeros_like(m)
    for i in range(m.shape[0]):
        idx = np.flatnonzero(m[i])
        if idx.size:
            plein[i, idx[0]: idx[-1] + 1] = True
    colonne = np.zeros_like(m)
    for j in range(m.shape[1]):
        idx = np.flatnonzero(m[:, j])
        if idx.size:
            colonne[idx[0]: idx[-1] + 1, j] = True
    return plein & colonne


def _mesure(fichiers):
    """Pour chaque image : la boîte de la pièce et son centre."""
    out = []
    for f in fichiers:
        L = np.asarray(Image.open(f).convert("L"), dtype=float)
        m = L > SEUIL
        if m.sum() < 50:
            out.append(None)
            continue
        ys, xs = np.where(m)
        out.append(
            {
                "x0": int(xs.min()), "x1": int(xs.max()),
                "y0": int(ys.min()), "y1": int(ys.max()),
                "cx": float((xs.min() + xs.max()) / 2),
                "cy": float((ys.min() + ys.max()) / 2),
                "w": float(xs.max() - xs.min()),
                "h": float(ys.max() - ys.min()),
            }
        )
    return out


def _extremes(w, lissage=5):
    """Les images où la pièce est de FACE (largeur maximale) et de TRANCHE
    (largeur minimale). Ce sont les seuls repères d'angle FIABLES du film."""
    n = len(w)
    k = np.ones(lissage) / lissage
    liss = np.convolve(np.pad(w, (lissage // 2, lissage // 2), mode="edge"),
                       k, mode="valid")[:n]
    hi, lo = liss.max(), liss.min()
    amp = max(hi - lo, 1e-6)
    faces, tranches = [], []
    marge = max(3, n // 40)
    for i in range(marge, n - marge):
        fen = liss[i - marge: i + marge + 1]
        if liss[i] == fen.max() and (liss[i] - lo) / amp > 0.80:
            if not faces or i - faces[-1] > marge:
                faces.append(i)
        if liss[i] == fen.min() and (liss[i] - lo) / amp < 0.20:
            if not tranches or i - tranches[-1] > marge:
                tranches.append(i)
    if liss[0] >= liss[1] and (liss[0] - lo) / amp > 0.80:
        faces.insert(0, 0)
    return faces, tranches


def _angles(w):
    """L'angle de lacet DÉROULÉ — **ancré sur les extrêmes, pas déduit de la
    largeur image par image.**

    ⚠️ POURQUOI PAS UN `arccos` DIRECT (ce que faisait le premier jet). La
    largeur projetée vaut `D·|cos θ|` : sa dérivée est `−D·sin θ`, donc elle
    est NULLE au voisinage de la face. Là où la pièce est presque frontale, la
    largeur ne bouge plus et l'angle devient indéterminé — l'inversion y rend
    du bruit. Mesuré sur le film d'or : 96 cases demandées, **41 images
    distinctes servies**, toutes tassées autour des tranches.

    La forme juste : on ne se sert de la largeur que pour repérer les
    ÉVÉNEMENTS — face (θ = 180°·k) et tranche (θ = 90° + 180°·k) — qui sont,
    eux, des extrêmes nets. Entre deux repères, l'angle avance LINÉAIREMENT.
    C'est exact si la rotation est régulière par morceaux, et c'est
    parfaitement conditionné partout, y compris à la face.
    """
    w = np.asarray(w, float)
    faces, tranches = _extremes(w)
    reperes = sorted([(i, "f") for i in faces] + [(i, "t") for i in tranches])
    if len(reperes) < 2:
        # Rien de net : on retombe sur une rampe linéaire, honnêtement.
        return np.linspace(0.0, 2 * np.pi, len(w))

    # On numérote les repères en quarts de tour à partir du premier.
    ang = []
    a = 0.0 if reperes[0][1] == "f" else np.pi / 2
    for k, (_, kind) in enumerate(reperes):
        if k > 0:
            a += np.pi / 2
        ang.append(a)
    idx = [r[0] for r in reperes]

    th = np.interp(np.arange(len(w)), idx, ang)
    # Avant le premier repère et après le dernier, `np.interp` tient la valeur :
    # on prolonge à la pente locale pour ne pas figer le début du film.
    if idx[0] > 0 and len(idx) > 1:
        pente = (ang[1] - ang[0]) / max(idx[1] - idx[0], 1)
        th[: idx[0]] = ang[0] - pente * (idx[0] - np.arange(idx[0]))
    if idx[-1] < len(w) - 1 and len(idx) > 1:
        pente = (ang[-1] - ang[-2]) / max(idx[-1] - idx[-2], 1)
        th[idx[-1]:] = ang[-1] + pente * (np.arange(idx[-1], len(w)) - idx[-1])
    return np.maximum.accumulate(th - th.min())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--nom", required=True, help="ex. piece-or")
    ap.add_argument("--cases", type=int, default=96, help="images pour 360°")
    ap.add_argument("--cote", type=int, default=384, help="côté d'une case, px")
    ap.add_argument("--marge", type=float, default=1.18,
                    help="la case vaut ce multiple du diamètre")
    ap.add_argument("--travail", type=int, default=1000, help="largeur de travail")
    ap.add_argument("--out", default="Nosfy/Media")
    args = ap.parse_args()

    tmp = tempfile.mkdtemp(prefix="recuit-piece-")
    try:
        fs = _frames(args.src, args.travail, tmp)
        mes = _mesure(fs)
        bons = [i for i, m in enumerate(mes) if m]
        if len(bons) < 20:
            sys.exit("trop peu d'images exploitables")

        h = np.array([mes[i]["h"] for i in bons])
        w = np.array([mes[i]["w"] for i in bons])
        # ⚠️ LE DIAMÈTRE EST LA HAUTEUR, PAS LA LARGEUR. La largeur RESPIRE :
        # c'est elle qui porte le tour. La hauteur, elle, est constante à 1 %
        # près (mesuré) — c'est la seule cote sur laquelle caler l'échelle.
        diam = float(np.median(h))
        epais = float(np.min(w))
        print(f"  diamètre médian {diam:.1f} px · épaisseur du chant {epais:.1f} px "
              f"({100*epais/diam:.0f} %)")

        faces, tranches = _extremes(w)
        print(f"  faces aux images {faces}  ·  tranches aux images {tranches}")
        th = _angles(w)
        print(f"  angle parcouru : {np.degrees(th[-1]):.0f}°  "
              f"({np.degrees(th[-1])/360:.2f} tour)")
        if th[-1] < np.pi * 1.9:
            print("  ⚠️ moins d'un tour complet : la boucle sera imparfaite")

        # LA GRILLE RÉGULIÈRE — un tour exactement, à pas constant.
        cible = np.linspace(0.0, 2 * np.pi, args.cases, endpoint=False)
        if th[-1] < 2 * np.pi:
            cible = np.linspace(0.0, float(th[-1]), args.cases, endpoint=False)
        choix = [bons[int(np.argmin(np.abs(th - a)))] for a in cible]
        uniques = len(set(choix))
        print(f"  {args.cases} cases tirées de {uniques} images distinctes")
        if uniques < args.cases * 0.6:
            print("  ⚠️ beaucoup de doublons : le film manque d'images")

        cote = args.cote
        boite = diam * args.marge          # ce que la case couvre, en px source
        cols = int(np.ceil(np.sqrt(args.cases)))
        lignes = int(np.ceil(args.cases / cols))
        planche = Image.new("RGBA", (cols * cote, lignes * cote), (0, 0, 0, 0))

        for k, idx in enumerate(choix):
            src = Image.open(fs[idx]).convert("RGB")
            a = np.asarray(src, dtype=float)
            L = a.mean(axis=2)
            sil = _silhouette(L).astype(float)
            # Le bord adouci : deux pixels, pas plus — un fondu large ferait
            # un halo, et la pièce cesserait d'avoir une arête.
            doux = sil.copy()
            for _ in range(2):
                d = np.zeros_like(doux)
                d[1:-1, 1:-1] = (doux[1:-1, 1:-1] + doux[:-2, 1:-1] + doux[2:, 1:-1]
                                 + doux[1:-1, :-2] + doux[1:-1, 2:]) / 5.0
                doux = np.maximum(doux * 0.0, d)
            alpha = np.clip(np.minimum(sil + doux, 1.0), 0, 1)

            rgba = np.dstack([a, alpha * 255.0]).astype(np.uint8)
            im = Image.fromarray(rgba)

            m = mes[idx]
            # ⚠️ ON RECENTRE SUR LE CENTRE MESURÉ, pas sur le centre du cadre :
            # c'est ça qui tue la dérive (jusqu'à 30 px, soit 8 % du diamètre).
            g = int(round(m["cx"] - boite / 2))
            ht = int(round(m["cy"] - boite / 2))
            vign = im.crop((g, ht, g + int(round(boite)), ht + int(round(boite))))
            vign = vign.resize((cote, cote), Image.LANCZOS)
            planche.paste(vign, ((k % cols) * cote, (k // cols) * cote))

        os.makedirs(args.out, exist_ok=True)
        chemin = os.path.join(args.out, f"{args.nom}.png")
        planche.save(chemin)
        meta = {
            "cases": args.cases, "cote": cote, "colonnes": cols, "lignes": lignes,
            "diametre_dans_la_case": round(1.0 / args.marge, 4),
            "tour_degres": round(float(np.degrees(cible[-1] + (cible[1] - cible[0]))), 1),
            "source": os.path.basename(args.src),
        }
        with open(os.path.join(args.out, f"{args.nom}.json"), "w") as f:
            json.dump(meta, f, indent=1)
        ko = os.path.getsize(chemin) / 1024
        print(f"  → {chemin}  ({cols}×{lignes} cases de {cote} px, {ko:.0f} Ko)")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
