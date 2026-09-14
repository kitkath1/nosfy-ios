#!/bin/zsh
# LA VIDÉO DE LA ROBE WELCOME « PREMIÈRE FOIS » (13-09, nuit) — Kathryn : « prends cette vidéo
# à mettre dans son header, fondue, comme une autre robe qui a déjà une vidéo fondue en loop ».
# Source : ~/Downloads/welcome_nosfy_onbaordin.mp4 — 3840 × 2160 paysage, HEVC 10 bits, 24 i/s,
# 7,04 s, 19 Mo, bords noirs vrais (mesuré : 0-4 / 255), scène sombre au centre.
#
# Le header de la card reward fait 332 × 245 pt (0,56 × 438), la vidéo y est en `aspectFit`
# (VideoReward.entier, robe welcome) : on la cuit en 4:3 (le centre, x = 480 → 2880 × 2160),
# 1200 × 900, en PING-PONG cuit (aller + retour, les doublons de bord amputés : la boucle ne
# rebrousse jamais dans le lecteur), muette. Aucun fondu cuit : la card pose son dégradé du
# bas et son masque des flancs sur toute vidéo de header (RewardCard, « 5 ter »).
set -e
cd "$(dirname "$0")/../.."
SRC=~/Downloads/welcome_nosfy_onbaordin.mp4
OUT=Woop/Media/welcome-nosfy-premiere.mp4
X264=(-c:v libx264 -preset slow -crf 21 -pix_fmt yuv420p -g 48 -movflags +faststart -an)
ffmpeg -v error -y -i "$SRC" -filter_complex "\
[0:v]crop=2880:2160:480:0,scale=1200:900:flags=lanczos,format=yuv420p,split[a][b];\
[b]reverse,trim=start_frame=1,setpts=PTS-STARTPTS[r];\
[a]trim=end_frame=168,setpts=PTS-STARTPTS[f];\
[f][r]concat=n=2:v=1:a=0[v]" -map "[v]" -r 24 "${X264[@]}" "$OUT"
echo "── welcome première fois cuit :"; ls -la "$OUT" | awk '{print $5, $9}'
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,duration,nb_frames -of csv=p=0 "$OUT"
