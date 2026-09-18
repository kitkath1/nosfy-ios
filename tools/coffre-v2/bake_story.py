#!/usr/bin/env python3
"""LES DEUX CINÉMATIQUES DE BOOSTER — recuites à la place de l'écran.

Verdict du 29-08 : *« quand on clique sur le booster noir, ça lance une vidéo
qu'on peut passer, puis on arrive sur une page »* — et pour l'orange, *« tu
prends booster_orange dans Downloads »*.

Sources (mesurées, IDENTIQUES en specs) :

    ~/Downloads/video_booster-nooir.mp4   2160 × 3840 · HEVC 10 bits · 8,04 s · AAC · 19 Mo
    ~/Downloads/booster_orange.mp4        2160 × 3840 · HEVC 10 bits · 8,04 s · AAC · 16 Mo

Trois faits qui commandent la recette :

  1. ⚠️ **ELLES ONT DU SON.** Toutes les boucles de l'app sont muettes ; une
     cinématique peut en avoir. On GARDE la piste AAC (copie, pas
     ré-encodage) — et c'est au lecteur de respecter l'interrupteur silencieux
     (`AVAudioSession` en `.ambient`).
  2. **Elles ne bouclent pas, et c'est voulu** : la noire finit en poussière
     d'étoiles, c'est SA transition vers la page. On ne coupe rien.
  3. **9:16 contre 0,46** : le sujet est centré et la macro remplit le cadre,
     un `aspectFill` qui rogne 18 % de largeur ne perd rien. ⚠️ Le tramage
     est demandé explicitement : 10 bits → 8 bits sur du noir étoilé, c'est
     le cas d'école du banding.

19 Mo pour 8 s, c'est 19,5 Mb/s — décoder du 4K pour un écran de 1206 de
large, c'est quatre fois trop de pixels par image. Cible : ~5 Mo.

Usage : python3 tools/coffre-v2/bake_story.py
"""

import os
import subprocess

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MEDIA = os.path.join(RACINE, "Nosfy", "Media")
DL = os.path.expanduser("~/Downloads")

CIBLE = (1206, 2622)
SOURCES = [("video_booster-nooir.mp4", "story-booster-noir.mp4"),
           ("booster_orange.mp4", "story-booster-lune.mp4")]


def main():
    for src, dst in SOURCES:
        entree = os.path.join(DL, src)
        sortie = os.path.join(MEDIA, dst)
        # aspectFill : on met à l'échelle sur la HAUTEUR, puis on rogne la
        # largeur au centre.
        filtre = (f"scale=-2:{CIBLE[1]}:flags=lanczos,"
                  f"crop={CIBLE[0]}:{CIBLE[1]},"
                  "format=yuv420p")
        cmd = ["ffmpeg", "-v", "error", "-y", "-i", entree,
               "-vf", filtre,
               "-c:v", "libx264", "-profile:v", "high", "-preset", "medium",
               "-crf", "20", "-pix_fmt", "yuv420p",
               "-c:a", "copy",
               "-movflags", "+faststart", sortie]
        subprocess.run(cmd, check=True)
        o = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0",
                            "-show_entries", "stream=width,height,duration,bit_rate",
                            "-of", "default=nw=1", sortie],
                           capture_output=True, text=True).stdout
        print("%s → %s" % (src, dst))
        for l in o.strip().split("\n"):
            print("  " + l)
        print("  poids %.1f Mo" % (os.path.getsize(sortie) / 1e6))


if __name__ == "__main__":
    main()
