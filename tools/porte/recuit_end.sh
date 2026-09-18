#!/bin/zsh
# LA FIN « END » (13-09) — Nosfy/Media/nosfy-end.mp4 + poster, depuis ~/Downloads/end.mp4
# (2160×3840 PORTRAIT HEVC 10 bits, 8,04 s, sa piste AAC −23,8 LUFS). Plan : PLAN-INTRO-NUIT.md §8.
#  Un plan portrait est fait pour l'écran entier : pas de crop, scale 1080×1920, les flancs
#  sont déjà noirs — seuls le haut et le bas s'éteignent (8 %). Un plan, une fois. Son gardé,
#  fondu de sortie cuit sur la dernière seconde.
set -e
SRC="$HOME/Downloads/end.mp4"; OUT="Nosfy/Media/nosfy-end.mp4"
POSTER_DIR="Nosfy/Assets.xcassets/nosfy-end-poster.imageset"
X264=(-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -g 48 -keyint_min 48 -sc_threshold 0 -movflags +faststart)
GEQ="geq=lum='lum(X,Y)*min(1,Y/154)*min(1,(1919-Y)/154)':cb='128+(cb(X,Y)-128)*min(1,Y/77)*min(1,(959-Y)/77)':cr='128+(cr(X,Y)-128)*min(1,Y/77)*min(1,(959-Y)/77)'"
ffmpeg -v error -y -i "$SRC" \
  -vf "scale=1080:1920:flags=lanczos,format=yuv420p,${GEQ},fade=t=in:st=0:d=0.3" \
  -af "afade=t=out:st=6.95:d=1.0" -c:a aac -b:a 128k -ar 44100 \
  -r 24 "${X264[@]}" "$OUT"
mkdir -p "$POSTER_DIR"
ffmpeg -v error -y -i "$OUT" -vf "select=eq(n\,72)" -frames:v 1 "$POSTER_DIR/nosfy-end-poster.png"
cat > "$POSTER_DIR/Contents.json" <<'JSON'
{ "images" : [ { "filename" : "nosfy-end-poster.png", "idiom" : "universal", "scale" : "1x" }, { "idiom" : "universal", "scale" : "2x" }, { "idiom" : "universal", "scale" : "3x" } ], "info" : { "author" : "xcode", "version" : 1 } }
JSON
echo "── end cuite :"; ls -la "$OUT" | awk '{print $5, $9}'; ffprobe -v error -show_entries stream=codec_type,width,height,duration -of csv=p=0 "$OUT"
