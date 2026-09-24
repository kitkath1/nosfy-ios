#!/bin/zsh
# LA CUISSON DES DEUX NOUVELLES ROBES (24-09) — produit
# Nosfy/Media/nosfy-aile-loop.mp4 et nosfy-clin-loop.mp4 depuis les sources
# de ~/Downloads (aile.mp4, cline_d'oleil.mp4).
#
# Les pieges payes qu'on ne repaie pas :
#  1. JAMAIS -ss : tout trim/reverse DANS le graphe (trim+setpts). `-ss` ne
#     coupe pas le graphe ffmpeg (ecole duo).
#  2. AUCUNE COUPE SECHE N'EST BOUCLABLE ICI — mesure du 24-09 : la
#     meilleure paire (i,j) de aile.mp4 donne une couture 2,53x le plancher
#     et celle de cline_d'oleil.mp4 8,1x (la tete derive sans jamais
#     revenir). L'ecole NotifChasse fixe le plafond a ~2x. Donc PING-PONG :
#     le retour est ampute de ses DEUX doublons de bord, couture ZERO par
#     construction (ecole duo/porte).
#  3. L'AILE SE JOUE A L'ENVERS. La source part aile DEPLOYEE (img 0-84) et
#     la REPLIE a la fin (img 90-120). A l'endroit, la bete range son aile
#     pendant que la dalle arrive. Retournee, elle l'OUVRE — et le toaster
#     ne vit que ~2,3 s : l'ouverture doit tomber dans la premiere seconde.
#     On part donc de l'image 104 (aile repliee) : deploiement a 0,1-0,85 s.
#  4. LE CLIN EST A 1,3 s DANS LA SOURCE (mesure du piqué des yeux :
#     le compte de pixels > 200 dans la zone des yeux tombe de ~40 a 13 aux
#     images 31-47, en DEUX battements). On coupe a l'image 6 pour le
#     ramener a ~1,05 s — dans la fenetre lisible du toaster.
#  5. NOIR VRAI DES DEUX COTES : aucun detourage, donc AUCUN MASQUE — la
#     seule facon de ne pas forcer un rendu hors ecran par image
#     (loi NotifChasse).
#  6. ⚠️⚠️ 30 IMG/S, JAMAIS 24 — son verdict du 24-09 (« effet glitch sur la
#     video du Nosfy »), et ce n'est PAS un defaut d'image : les deux
#     sources sont en 24 img/s, et 60 / 24 = 2,5. Sur un ecran 60 Hz chaque
#     image tient donc 2 puis 3 rafraichissements, en alternance — le
#     pulldown 3:2. Sur une aile qui balaie lentement, ca SACCADE. Preuve :
#     les images du film au simulateur sont propres une par une (aucun
#     artefact, aucun saut de contenu : pas max 0,91 pour un median 0,42),
#     le defaut est TEMPOREL. Le remede ne duplique ni n'interpole rien
#     (minterpolate fabrique des fantomes sur les membranes) : on RE-DATE
#     les memes images a 30 img/s (setpts=N/30/TB). Chaque image tient alors
#     exactement 2 rafraichissements a 60 Hz, 4 a 120 — cadence parfaitement
#     reguliere. Le film joue 25 % plus vite, ce qui SERT un toaster qui ne
#     vit que ~2,3 s.
set -e
cd "$(dirname "$0")"
OUT=../../Nosfy/Media
DL=~/Downloads
mkdir -p "$OUT"

X264=(-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -g 48 -keyint_min 48
      -sc_threshold 0 -movflags +faststart -an)

nbf() { ffprobe -v error -select_streams v:0 -count_frames \
        -show_entries stream=nb_read_frames -of csv=p=0 "$1" }

# --- L'AILE : crop du contenu, retournement, ping-pong, une seule passe.
# bbox mesuree sur l'enveloppe du film (seuil 12/255) : x 0,235-0,927,
# y 0,044-0,978 de 3836x2160 -> 880..3580 / 70..2140, avec sa marge.
# 105 images retournees + 103 de retour = 208 images (6,93 s a 30 img/s).
ffmpeg -y -v error -i "$DL/aile.mp4" -filter_complex "\
[0:v]trim=end_frame=105,setpts=PTS-STARTPTS,reverse,\
crop=2700:2070:880:70,scale=480:-2,format=yuv420p[s];\
[s]split[a][b];\
[b]reverse,trim=start_frame=1:end_frame=104,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=N/30/TB,format=yuv420p[out]" \
  -map "[out]" -r 30 $X264 "$OUT/nosfy-aile-loop.mp4"

# --- LE CLIN : la tete seule, petite (elle vit a ~66 pt de large).
# bbox : x 0,189-0,792, y 0,089-0,833 de 1440x1440 -> 260..1160 / 110..1210.
# 56 images + 54 de retour = 110 images (3,67 s a 30 img/s), clin a ~0,84 s.
ffmpeg -y -v error -i "$DL/cline_d'oleil.mp4" -filter_complex "\
[0:v]trim=start_frame=6:end_frame=62,setpts=PTS-STARTPTS,\
crop=900:1100:260:110,scale=200:-2,format=yuv420p[s];\
[s]split[a][b];\
[b]reverse,trim=start_frame=1:end_frame=55,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=N/30/TB,format=yuv420p[out]" \
  -map "[out]" -r 30 $X264 "$OUT/nosfy-clin-loop.mp4"

# ------------------------------------------------- portillons (mesures)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for n in nosfy-aile-loop nosfy-clin-loop; do
  nf=$(nbf "$OUT/$n.mp4")
  ffmpeg -y -v error -i "$OUT/$n.mp4" -vf "select=eq(n\,0)" -vsync 0 "$TMP/$n-f0.png"
  ffmpeg -y -v error -i "$OUT/$n.mp4" -vf "select=eq(n\,$((nf-1)))" -vsync 0 "$TMP/$n-fN.png"
  ffmpeg -y -v error -i "$OUT/$n.mp4" -vf "select=eq(n\,1)" -vsync 0 "$TMP/$n-f1.png"
done
TMP="$TMP" python3 - <<'EOF'
import numpy as np, os
from PIL import Image
tmp = os.environ["TMP"]; out = "../../Nosfy/Media"
print(f"{'fichier':22s} {'imgs':>5s} {'couture':>8s} {'plancher':>9s} {'ratio':>6s} {'Ko':>7s}")
for n in ["nosfy-aile-loop", "nosfy-clin-loop"]:
    f0 = np.asarray(Image.open(f"{tmp}/{n}-f0.png").convert("L")).astype(float)
    f1 = np.asarray(Image.open(f"{tmp}/{n}-f1.png").convert("L")).astype(float)
    fN = np.asarray(Image.open(f"{tmp}/{n}-fN.png").convert("L")).astype(float)
    couture = np.abs(fN - f0).mean()          # derniere image -> premiere
    plancher = np.abs(f1 - f0).mean()         # deux images consecutives
    ko = os.path.getsize(f"{out}/{n}.mp4") / 1024
    r = couture / plancher if plancher else 0
    print(f"{n:22s} {'':5s} {couture:8.3f} {plancher:9.3f} {r:6.2f} {ko:7.1f}")
EOF
echo ""
for n in nosfy-aile-loop nosfy-clin-loop; do
  echo "$n : $(nbf "$OUT/$n.mp4") images · $(ffprobe -v error -show_entries stream=width,height -of csv=p=0:s=x -select_streams v:0 "$OUT/$n.mp4")"
done
