#!/usr/bin/env python3
"""Fond de comparaison : composition hors téléphone, même mouvement à 24 i/s.

La géométrie est celle du slot Home observé sur l'iPhone 15 (393 x 709 pt).
Ce fichier n'est utilisé que si le slot réel correspond ; aucune mise à
l'échelle d'un plein écran ne doit déplacer la pilule ou la braise.
"""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Woop/Media/home-fond-precompose-393x709.mp4"
POSTER = ROOT / "Woop/Assets.xcassets/home-fond-precompose-393x709.imageset"
W, H, SCALE = 393, 709, 2
K = 874 / 2348
width = round(1080 * K * SCALE)
bh = round(1148 * K * SCALE)
ph = round(864 * K * SCALE)
py = round(400 * K * SCALE)
x = round((W * SCALE - width) / 2)
# L'addition se fait en RGB, jamais sur les plans chromatiques YUV.
filters = (
 f"[0:v]setsar=1,scale={width}:{bh}:flags=lanczos,format=gbrp,"
 f"pad={width}:{H*SCALE}:0:{H*SCALE-bh}:black,"
 f"crop={W*SCALE}:{H*SCALE}:{-x}:0[braise];"
 f"[1:v]setsar=1,scale={width}:{ph}:flags=lanczos,format=gbrp,"
 f"pad={width}:{H*SCALE}:0:{py}:black,"
 f"crop={W*SCALE}:{H*SCALE}:{-x}:0[pilule];"
 "[braise][pilule]blend=all_mode=addition[addition];"
 f"[2:v]scale={width}:{874*SCALE}:flags=lanczos,format=rgba,"
 f"crop={W*SCALE}:{H*SCALE}:{-x}:0[scrim];"
 "[addition][scrim]overlay=format=rgb:shortest=1,setsar=1,format=yuv420p[out]"
)
cmd = ["ffmpeg", "-y", "-v", "error", "-threads", "2",
 "-i", str(ROOT/"Woop/Media/home-fond-flamme.mp4"),
 "-i", str(ROOT/"Woop/Media/home-fond-pilule.mp4"),
 "-loop", "1", "-framerate", "24", "-i",
 str(ROOT/"Woop/Assets.xcassets/home-fond-scrim.imageset/home-fond-scrim.png"),
 "-filter_complex_threads", "2", "-filter_complex", filters,
 "-map", "[out]", "-an", "-c:v", "libx264", "-threads", "2",
 "-preset", "medium", "-crf", "19", "-movflags", "+faststart", str(OUT)]
subprocess.run(cmd, check=True)
POSTER.mkdir(parents=True, exist_ok=True)
subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(OUT),
 "-frames:v", "1", str(POSTER/"poster.png")], check=True)
(POSTER/"Contents.json").write_text(json.dumps({"images": [{"filename": "poster.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, indent=2)+"\n")
print(OUT)
