#!/usr/bin/env python3
"""LE FOND SPOTLIGHT — la boucle, et son image de pose.

Verdict du 28-08 : *« enlève la vidéo blanche avec néon, on passe en mode
sombre noir : un rendu spotlight qui se reflète sur le podium. »*
Puis du 29-08 : *« mais t'as pas utilisé la vidéo, t'as mis un vieux
spotlight »*.

⚠️⚠️ **ELLE AVAIT RAISON, ET MON ERREUR EST INSTRUCTIVE.** Le premier jet
partait de `~/Desktop/spotlight .png`. J'avais comparé ce PNG à sa référence
SUR LA TEINTE (V−B : +9 contre +8) et conclu que c'était le même rendu. **Je
n'avais jamais comparé le CONTENU.** Mesuré au même cadrage :

    spotlight .png (20 h 08)   514 pixels de braise · luminance moyenne  8,5
    video_crop.mp4 (21 h 12)  3738 pixels de braise · luminance moyenne 20,3

**7× plus de braises, 2,4× la luminance** — et l'horodatage le disait déjà.
Le PNG est un rendu ANTÉRIEUR, une colonne douce presque sans étincelles.
**Deux mesures qui concordent sur une couleur ne disent rien du dessin.**

Ce script part donc de la VIDÉO, et en tire les deux fichiers :

  · `coffre-spot-loop.mp4` — la boucle
  · `coffre-spot.png`      — son image de pose (⚠️ OBLIGATOIRE : le décodeur
    du simulateur est LOGICIEL et rate des images ; sans poster dessous, le
    raté DEVIENT un glitch noir plein écran — c'est pourquoi `salle-poster`
    existait)

Trois opérations, chacune pour une raison mesurée :

**① ON COUPE LE SOCLE.** Il doit rester un PNG à part : toute la géométrie de
la page est accrochée à `podCentre`/`yHaut`/`yBas`, et depuis le §18 les
flaques prennent l'image du socle comme MASQUE. ⚠️ Son sommet réel se trouve
par son ARÊTE et non par sa lumière : il remonte jusqu'à **0,775 H** en fin de
travelling. On coupe à 0,75 (voir la constante `COUPE`).

**② ON MET EN PING-PONG.** Le socle passe de 0,690 à 0,836 de la largeur de
façon MONOTONE : la vidéo ne boucle pas, un `AVPlayerLooper` la ferait sauter
de 21 % toutes les 8 secondes. Aller + retour = 16 s sans raccord, et le
travelling devient une RESPIRATION — c'est lire le matériau pour ce qu'il est.

**③ ON RECUIT À LA TAILLE D'AFFICHAGE.** 2160 de large pour un écran qui en
demande 1206, c'est décoder quatre fois trop de pixels par image.
⚠️ La source est en 10 bits et l'image est un DÉGRADÉ SOMBRE : c'est le cas
d'école du banding en 8 bits. On garde donc un débit large et on demande le
tramage explicitement.

Le fondu du bord bas est cuit ici plutôt que masqué au runtime : un `.mask`
sur une couche vidéo force une passe hors écran à chaque image.

Usage : python3 tools/coffre-v2/bake_spot.py
"""

import os
import subprocess
import numpy as np
from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MEDIA = os.path.join(RACINE, "Woop", "Media")
SORTIE = os.path.join(RACINE, "tools", "coffre-v2", "vignettes")
SOURCE = os.path.expanduser("~/Downloads/video_crop.mp4")

SRC = (2160, 3840)
# ⚠️⚠️ **LA COUPE S'EST FAITE EN DEUX TEMPS, ET LA PREMIÈRE ÉTAIT FAUSSE.**
# J'ai d'abord cherché le socle par sa LUMIÈRE (« une large bande claire ») et
# trouvé 0,855 → 0,875 H. Coupé à 0,845, un **fantôme d'ellipse** restait
# visible à l'écran, sous notre propre socle : le verre sombre du socle
# commence bien PLUS HAUT que sa partie éclairée.
#
# Cherché par son ARÊTE (un saut vertical de luminance sur plus de 30 % de la
# largeur), il apparaît à 0,832 H à t = 0 et **remonte à 0,775 H à t = 7,9**
# en grossissant. C'est ce minimum-là qui commande, pas la moyenne. On coupe à
# 0,75 — deux points et demi de marge.
#
# **Chercher un objet par sa lumière trouve sa partie éclairée, pas l'objet.**
COUPE = 0.75
LARGE = 1206                     # la largeur d'écran au 3×
BAS = 0.10                       # le fondu du bord bas, en fraction de hauteur
COTE = 0.10                      # et des bords latéraux

# ⚠️⚠️ **« ELLE RESPIRE TROP » (29-08), ET C'ÉTAIT MESURABLE.** Le travelling
# de la source fait +21 % sur le SOCLE, mais le faisceau, lui, gonfle de
# **+32 %** à mi-hauteur : le cône s'élargit en même temps que la caméra
# avance. Un aller-retour sur toute la durée, c'est donc une pompe de 32 % en
# 8 secondes — 4 % par seconde.
#
# Deux réglages, et ils ne font pas la même chose :
#   · `FIN` réduit l'AMPLITUDE — on ne garde que le début du travelling ;
#   · `LENT` réduit la VITESSE — le même mouvement, étalé.
#
# Premier réglage (4,0 s · ×1,5) : amplitude ÷1,9, vitesse ÷1,4 — mesuré,
# et pas assez. Deuxième (3,0 s · ×2,0) : **amplitude ÷2,7, vitesse ÷2,0**.
#
# ⚠️ **RALENTIR NE RAJOUTE PAS DE SACCADE, ET C'EST CONTRE-INTUITIF.** Le
# déplacement PAR IMAGE SOURCE ne dépend que de `FIN`, pas de `LENT` : c'est
# la même image suivante, montrée plus tard. Ici il vaut 0,14 % dans les deux
# cas. Ce que `LENT` change, c'est la FRÉQUENCE des mises à jour (24 → 12 par
# seconde) — le pas ne grandit pas, il revient moins souvent.
#
# ⚠️ La mesure d'amplitude se fait sur l'AIRE ÉCLAIRÉE (∝ zoom²), pas sur la
# largeur du faisceau : les braises traversent le seuil et font trembler une
# mesure de largeur de ±8 % sans que rien ne bouge.
DEBUT = 0.0
FIN = 3.0                        # secondes de source gardées → l'AMPLITUDE
LENT = 2.0                       # étalement du temps → la VITESSE


def rampe(W, H):
    """Le voile noir à alpha variable : bords et bas éteints EN COSINUS.

    ⚠️ Une rampe droite laisse une ARÊTE là où elle commence — sa dérivée
    saute, et sur un fond aussi sombre l'œil la voit tout de suite. Le cosinus
    part et arrive à tangente nulle : le fondu n'a pas de début.
    """
    x = np.arange(W) / W
    cx = np.ones(W)
    m = x < COTE
    cx[m] = 0.5 - 0.5 * np.cos(np.pi * x[m] / COTE)
    m = x > 1 - COTE
    cx[m] = 0.5 - 0.5 * np.cos(np.pi * (1 - x[m]) / COTE)

    y = np.arange(H) / H
    cy = np.ones(H)
    m = y > 1 - BAS
    cy[m] = 0.5 - 0.5 * np.cos(np.pi * (1 - y[m]) / BAS)

    garde = cy[:, None] * cx[None, :]
    a = np.zeros((H, W, 4), np.uint8)
    a[..., 3] = ((1 - garde) * 255).astype(np.uint8)   # noir, opaque aux bords
    return Image.fromarray(a, "RGBA")


def main():
    hcrop = int(SRC[1] * COUPE)
    hout = int(round(hcrop * LARGE / SRC[0]))
    hout -= hout % 2
    voile = os.path.join(SORTIE, "spot-voile.png")
    os.makedirs(SORTIE, exist_ok=True)
    rampe(LARGE, hout).save(voile)

    loop = os.path.join(MEDIA, "coffre-spot-loop.mp4")
    filtre = (
        # ⚠️ **`trim` + `setpts` DANS LE GRAPHE, JAMAIS `-ss`.** Piège déjà
        # payé dans cette maison : `-ss` positionne la LECTURE, il ne coupe
        # pas le graphe de filtres — les images d'avant continuent d'y entrer,
        # et `reverse` les embarque. La seule forme juste est celle-ci.
        f"[0:v]trim=start={DEBUT}:end={FIN},setpts=(PTS-STARTPTS)*{LENT},"
        f"crop={SRC[0]}:{hcrop}:0:0,"
        f"scale={LARGE}:{hout}:flags=lanczos,"
        "format=yuv420p10le[v];"
        "[v][1:v]overlay=0:0[o];"
        # ⚠️ Le ping-pong : aller, puis retour. `reverse` charge tout le clip
        # en mémoire — 193 images à cette taille, c'est tenable.
        "[o]split[a][b];[b]reverse[r];[a][r]concat=n=2:v=1[c];"
        # ⚠️ Le tramage AVANT la réduction à 8 bits : sans lui, un dégradé
        # sombre se met en escalier (banding), et toute cette image EST un
        # dégradé sombre.
        "[c]format=yuv420p[out]"
    )
    cmd = ["ffmpeg", "-v", "error", "-y", "-i", SOURCE, "-i", voile,
           "-filter_complex", filtre, "-map", "[out]",
           "-c:v", "libx264", "-profile:v", "high", "-preset", "slow",
           "-crf", "20", "-pix_fmt", "yuv420p",
           "-x264-params", "no-dct-decimate=1",
           "-movflags", "+faststart", "-an", loop]
    subprocess.run(cmd, check=True)

    # L'IMAGE DE POSE : la première image de la boucle, pour qu'elle raccorde
    # exactement avec ce que la vidéo affiche à t = 0.
    poster = os.path.join(MEDIA, "coffre-spot.png")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", loop,
                    "-frames:v", "1", poster], check=True)

    im = Image.open(poster).convert("L")
    a = np.asarray(im).astype(float)
    o = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0",
                        "-show_entries", "stream=nb_frames,duration,bit_rate",
                        "-of", "default=nw=1", loop],
                       capture_output=True, text=True).stdout
    print("video_crop.mp4 %dx%d → coffre-spot-loop.mp4 %dx%d"
          % (SRC[0], SRC[1], LARGE, hout))
    print("  coupe du socle à %.3f H · fondu bas %.2f · côtés %.2f"
          % (COUPE, BAS, COTE))
    for l in o.strip().split("\n"):
        print("  " + l)
    print("  poids %.1f Mo" % (os.path.getsize(loop) / 1e6))
    print("  poster : luminance moyenne %.1f · bord gauche %.1f · bas %.1f"
          % (a.mean(), a[:, :20].mean(), a[-20:, :].mean()))


if __name__ == "__main__":
    main()
