#!/bin/zsh
# L'INTRO « NUIT » (13-09) — Woop/Media/nosfy-nuit.mp4 + poster, depuis ~/Downloads/nuit.mp4
# (3840×2160 HEVC 10 bits, 8,04 s, sa piste AAC −27,8 LUFS). Plan : PLAN-INTRO-NUIT.md §5.
#  1. JAMAIS -ss.  2. Le crop d'abord, au ratio de la fenêtre : bande 330×220 pt (3:2) →
#  990×660 px ; dans la source le centre, 8 → 92 % (crop 3240×2160 à x=300).
#  3. LES QUATRE BORDS S'ÉTEIGNENT DANS LE FICHIER (10 %) : c'est une scène pleine, sinon le
#  rectangle se voit.  4. Pas de ping-pong : un plan, une fois.  5. LE SON EST GARDÉ, avec
#  un fondu de sortie cuit sur sa dernière seconde — c'est là que ma musique monte.
set -e
SRC="$HOME/Downloads/nuit.mp4"; OUT="Woop/Media/nosfy-nuit.mp4"
POSTER_DIR="Woop/Assets.xcassets/nosfy-nuit-poster.imageset"
X264=(-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -g 48 -keyint_min 48 -sc_threshold 0 -movflags +faststart)
# 2e cuisson (13-09 soir, « mal fondue, pas beau ») : les rampes LINÉAIRES sur quatre
# bords se lisent comme un rectangle adouci. Une VIGNETTE ELLIPTIQUE en smoothstep —
# pleine jusqu'à r = 0,6, noire à r = 1,25 — se lit comme un projecteur : jamais un cadre.
# (La petite lune du premier plan, dans le coin, ne reste qu'en lueur ; la vraie lune,
# celle de 5,8 s, est au centre et pleine.)
T_L="clip((1.25-sqrt(pow((X-495)/495,2)+pow((Y-330)/330,2)))/0.65,0,1)"
T_C="clip((1.25-sqrt(pow((X-247.5)/247.5,2)+pow((Y-165)/165,2)))/0.65,0,1)"
GEQ="geq=lum='lum(X,Y)*0.92*(${T_L})*(${T_L})*(3-2*(${T_L}))':cb='128+(cb(X,Y)-128)*(${T_C})*(${T_C})*(3-2*(${T_C}))':cr='128+(cr(X,Y)-128)*(${T_C})*(${T_C})*(3-2*(${T_C}))'"
ffmpeg -v error -y -i "$SRC" \
  -vf "crop=3240:2160:300:0,scale=990:660:flags=lanczos,format=yuv420p,${GEQ},fade=t=in:st=0:d=0.8,setpts=1.5*PTS" \
  -af "atempo=0.6667,afade=t=out:st=10.6:d=1.3" -c:a aac -b:a 128k -ar 44100 \
  -r 24 "${X264[@]}" "$OUT"
mkdir -p "$POSTER_DIR"
ffmpeg -v error -y -i "$OUT" -vf "select=eq(n\,12)" -frames:v 1 "$POSTER_DIR/nosfy-nuit-poster.png"
cat > "$POSTER_DIR/Contents.json" <<'JSON'
{ "images" : [ { "filename" : "nosfy-nuit-poster.png", "idiom" : "universal", "scale" : "1x" }, { "idiom" : "universal", "scale" : "2x" }, { "idiom" : "universal", "scale" : "3x" } ], "info" : { "author" : "xcode", "version" : 1 } }
JSON
echo "── nuit cuite :"; ls -la "$OUT" | awk '{print $5, $9}'; ffprobe -v error -show_entries stream=codec_type,width,height,duration -of csv=p=0 "$OUT"
