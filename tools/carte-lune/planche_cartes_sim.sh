#!/bin/zsh
# LA PLANCHE DE PLUSIEURS CARTES AU SIMULATEUR (banc -mondeLab -mondeCarte <nom>).
# Pour chaque nom donné : lance le banc en automatique (le tap seul à 1,2 s), capture
# le monde ouvert (relief, puis plans), et assemble une planche `planche-cartes-<mode>.png`
# dans maquette-legendaire-2026-09-20/. Usage : planche_cartes_sim.sh le-souverain corbeau-de-suie …
SIM=FD3651DD-7D4E-4C70-B4C3-B6C4D90818F0
cd "$(dirname "$0")"
OUT=maquette-legendaire-2026-09-20/cartes
mkdir -p "$OUT"
xcrun simctl boot $SIM 2>/dev/null; xcrun simctl bootstatus $SIM -b >/dev/null 2>&1
for MODE in relief plans; do
  FL="-mondeRelief"; [ "$MODE" = plans ] && FL=""
  for NOM in "$@"; do
    xcrun simctl terminate $SIM fr.kathryn.woop 2>/dev/null
    xcrun simctl launch $SIM fr.kathryn.woop -mondeLab -mondeCarte "$NOM" $FL -mondeAuto -skipAuth >/dev/null 2>&1
    sleep 4.6
    xcrun simctl io $SIM screenshot "$OUT/$NOM-$MODE.png" >/dev/null 2>&1
  done
done
python3 - "$OUT" "$@" <<'PY'
import sys, os
from PIL import Image, ImageDraw, ImageFont
out, noms = sys.argv[1], sys.argv[2:]
try:
    f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 16)
except OSError:
    f = ImageFont.load_default()
for mode in ("relief", "plans"):
    ims = []
    for n in noms:
        p = f"{out}/{n}-{mode}.png"
        if os.path.exists(p):
            im = Image.open(p); h = 640; ims.append((n, im.resize((int(im.width * h / im.height), h))))
    if not ims:
        continue
    W = sum(im.width for _, im in ims) + 10 * (len(ims) + 1)
    pl = Image.new("RGB", (W, 640 + 44), (4, 4, 6)); d = ImageDraw.Draw(pl); x = 10
    for n, im in ims:
        pl.paste(im, (x, 34)); d.text((x, 8), f"{n} · {mode}", fill=(200, 205, 215), font=f); x += im.width + 10
    pl.save(f"{out}/planche-cartes-{mode}.png"); print("planche", mode, pl.size)
PY
