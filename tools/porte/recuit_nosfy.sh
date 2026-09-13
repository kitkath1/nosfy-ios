#!/bin/zsh
# LA CUISSON DE L'ACCUEIL DE NOSFY (13-09) — produit Woop/Media/nosfy-accueil-loop.mp4
# et le poster, depuis ~/Downloads/welcome_nosty.mp4 (3840×2160 HEVC 10 bits, 7,04 s,
# 169 images, fond noir vrai, la bête au centre, oreilles au bord haut, corps coupé
# par le bord bas — mesuré). Plan : tools/porte/PLAN-ACCUEIL-NOSFY.md §2.
# Les pièges payés qu'on ne repaie pas (école recuit_duo.sh) :
#  1. JAMAIS -ss : tout vit DANS le graphe.
#  2. LE CROP D'ABORD, AU RATIO DE LA FENÊTRE : 190×300 pt → 600×900 px (2:3).
#     Dans la source : le tiers médian, 1440 large (40 pt de marge de chaque
#     côté de la bête), pleine hauteur.
#  3. LES EXTINCTIONS SONT CUITES : 6 % du haut (les oreilles au bord), 15 % du
#     bas (le corps coupé) — en geq APRÈS le scale (geq sur du 4K = une heure).
#  4. LE PING-PONG AMPUTE SES DEUX DOUBLONS DE BORD : l'aller garde 0..168, le
#     retour va de 167 à 1 (ni 168 ni 0 en double) → 169 + 167 = 336 images = 14 s.
set -e
SRC="$HOME/Downloads/welcome_nosty.mp4"
OUT="Woop/Media/nosfy-accueil-loop.mp4"
POSTER_DIR="Woop/Assets.xcassets/nosfy-accueil-poster.imageset"
X264=(-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -g 48 -keyint_min 48 -sc_threshold 0 -movflags +faststart -an)
# H = 900 ; haut 6 % = 54 ; bas 15 % = 135 (luma) ; chroma à demi-résolution.
# 13-09, 2e cuisson (« un peu plus fondue ») : haut 12 % (108), bas 28 % (252),
# flancs 10 % (60) — les ailes touchaient les bords — et un gain global de 0,88.
GEQ="geq=lum='lum(X,Y)*0.88*min(1,Y/108)*min(1,(899-Y)/252)*min(1,X/60)*min(1,(599-X)/60)':cb='128+(cb(X,Y)-128)*min(1,Y/54)*min(1,(449-Y)/126)*min(1,X/30)*min(1,(299-X)/30)':cr='128+(cr(X,Y)-128)*min(1,Y/54)*min(1,(449-Y)/126)*min(1,X/30)*min(1,(299-X)/30)'"
ffmpeg -v error -y -i "$SRC" -filter_complex \
  "[0:v]crop=1440:2160:1200:0,scale=600:900:flags=lanczos,format=yuv420p,${GEQ},split[a][b];[b]reverse,trim=start_frame=1:end_frame=168,setpts=PTS-STARTPTS[r];[a][r]concat=n=2:v=1:a=0,format=yuv420p[v]" \
  -map "[v]" -r 24 "${X264[@]}" "$OUT"
mkdir -p "$POSTER_DIR"
ffmpeg -v error -y -i "$OUT" -frames:v 1 "$POSTER_DIR/nosfy-accueil-poster.png"
cat > "$POSTER_DIR/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "nosfy-accueil-poster.png", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
echo "── cuit :"; ls -la "$OUT" "$POSTER_DIR/nosfy-accueil-poster.png" | awk '{print $5, $9}'
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,nb_frames,duration -of default=noprint_wrappers=1 "$OUT"
