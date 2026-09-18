#!/bin/zsh
# OPTION B DU FOND DE PROGRESS — « elle peut partir du bas » (plan §3).
#
#   ./tools/progress/recuit_pill_bas.sh
#
# Source : ~/Downloads/Video rouge_liquid.mp4 (2160×3836, 24 i/s, 169 img,
# bords à vrai zéro) — la pill VERTICALE de verre rouge dont le liquide de
# feu MONTE du pied. Mesuré (numpy, image 84) : pill x 0,24→0,79, y 0,17→0,80 ;
# couture de boucle 16,5 pour des voisines à 0,57 → PALINDROME obligatoire.
#
# La fenêtre = la card à 3× (1206 × 2592). Pill centrée en x (centre source
# 1112 → x0 = 1112 − 603 = 509), son pied posé à ~95 % de la fenêtre (bas de
# pill à 3069 → y0 = 3069 / 0,95 − 2592 ≈ 639) : elle PART DU BAS, son feu
# liquide au bord bas de la card, son dôme de verre derrière le calendrier.
#
# Les écoles (recuit_story_ended.sh, recuit_molette.sh) : jamais -ss (tout
# trim vit dans le graphe), minterpolate 30 i/s (le 24 bat en 3:2 à 60 Hz),
# ping-pong AMPUTÉ de ses deux doublons de bord, UNE passe d'encodage, la pose
# cuite depuis l'image 0 et posée DANS le representable (CalqueVideo).
set -e
cd "$(dirname "$0")/../.."
SRC="$HOME/Downloads/Video rouge_liquid.mp4"
DEST=Nosfy/Media
POSTER=Nosfy/Assets.xcassets/progress-pill-bas-poster.imageset
TMP=$(mktemp -d)

nbf() {
  ffprobe -v error -select_streams v:0 -count_frames \
    -show_entries stream=nb_read_frames -of csv=p=0 "$1" | tr -d ','
}

# L'ALLER : crop d'abord (la fenêtre), interpolation ensuite (moins de pixels).
ffmpeg -y -v error -i "$SRC" \
  -vf "crop=1206:2592:509:639,minterpolate=fps=30:mi_mode=blend,format=yuv420p" \
  -an -c:v libx264 -preset medium -crf 16 "$TMP/aller.mp4"

# LE PALINDROME, amputé de ses deux doublons (image 0 et image N−1 du retour).
n=$(nbf "$TMP/aller.mp4")
ffmpeg -y -v error -i "$TMP/aller.mp4" -filter_complex "\
[0:v]split[a][b];\
[b]reverse,trim=start_frame=1:end_frame=$((n-1)),setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,format=yuv420p[out]" \
  -map "[out]" -an -c:v libx264 -preset slow -crf 18 -g 30 \
  -movflags +faststart "$DEST/progress-pill-bas.mp4"

# LA POSE : l'image 0, dans le catalogue, au format des autres posters.
ffmpeg -y -v error -i "$DEST/progress-pill-bas.mp4" -vf "select=eq(n\,0)" \
  -frames:v 1 -q:v 2 "$TMP/pose.jpg"
mkdir -p "$POSTER"
cp "$TMP/pose.jpg" "$POSTER/progress-pill-bas-poster.jpg"
sed 's/home-fond-flamme-poster/progress-pill-bas-poster/g' \
  Nosfy/Assets.xcassets/home-fond-flamme-poster.imageset/Contents.json \
  > "$POSTER/Contents.json"

echo "aller $n img → $(nbf "$DEST/progress-pill-bas.mp4") img"
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,nb_frames,duration \
  -of csv=p=0 "$DEST/progress-pill-bas.mp4"
du -h "$DEST/progress-pill-bas.mp4" "$POSTER/progress-pill-bas-poster.jpg"
rm -rf "$TMP"
