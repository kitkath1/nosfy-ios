#!/bin/zsh
# LA RECUISSON EN DEUX CALQUES — remplace recuit_fond.sh (qui aplatissait).
#
# Même géométrie, même ping-pong, même ralenti que recuit_fond.sh : au repos,
# la SOMME des deux fichiers doit rendre home-fond-loop.mp4 au pixel. Ce qui
# change : on ne fusionne plus, on livre deux plans.
#
#  · home-fond-pilule.mp4  — la branche pills_2 seule, sur noir, CANEVAS COMPLET
#  · home-fond-flamme.mp4  — la branche flamme seule, sur noir, CANEVAS COMPLET
#
# ⚠️ AUCUN ROGNAGE, AUCUNE LIGNE DE COUPE. Mesuré : au seuil 1/255 la pilule
# descend jusqu'à la ligne 1232 et la braise remonte à 1208 — elles se
# RECOUVRENT sur 24 lignes. Une coupe franche perdrait de la matière, une coupe
# en fondu demande deux rampes complémentaires à caler. Le canevas complet, lui,
# est exact PAR CONSTRUCTION : chaque calque est noir là où l'autre porte le
# contenu, et noir + contenu = contenu.
#
# ⚠️ CHAQUE CALQUE EST ROGNÉ À SA BOÎTE UTILE, À LA DENSITÉ DE L'ÉCRAN.
# ⚠️ LES BOÎTES SONT MESURÉES À PLEINE RÉSOLUTION, PAS SUR UNE VIGNETTE. Payé :
# j'avais relevé les boîtes sur des vignettes réduites 4×, qui perdent les pixels
# faibles — le rognage coupait alors **26 lignes en haut, 19 en bas et 29
# colonnes à droite** de la pilule, et **233 lignes** de la braise. Verdict :
# « la vidéo de la pilule est coupée en haut et sur les côtés ».
# Boîtes vraies, seuil 1/255, 8 images du canevas 1080×2348 en pleine
# définition : pilule **lignes 434..1229, colonnes 0..1009** · braise **à partir
# de la ligne 1227**. Les rognages ci-dessous prennent une marge et gardent la
# largeur ENTIÈRE (les 70 colonnes économisées à droite ne valaient pas le
# risque) ; et 1620 px de large pour un écran qui en affiche 1206 est un
# sur-échantillonnage de 1,34x qui ne se voit pas. Budget de décodage :
#   avant  pilule 1620x3522 = 5,71 Mpix -> 137 Mpix/s (301 pendant le film,
#          quand le rate montait à 2,2 — au pire moment possible)
#   après  pilule 1094x838  = 0,92 Mpix -> 22 Mpix/s
# Soit 5,7x moins en tout. Les marges du rognage (20 lignes en haut, 28 en bas,
# 39 colonnes à droite) laissent de quoi ne pas raboter un bord au sous-pixel.
# ⚠️ LE COÛT EST AUSSI PAYÉ SUR LA DÉFINITION DE LA BRAISE. Gradient mesuré
# p99 : 11/24 pour la pilule (c'est l'objet net), 2,0 pour la braise (c'est un
# dégradé). La braise sort donc à la MOITIÉ de la définition — invisible, et le
# décodage tombe au quart.
#
# ⚠️ GOP NORMAL. Le scrub est mort : on ne fait plus un seul seek, on LIT. Le
# -g 12 de recuit_fond.sh coûtait du poids pour rien. (Il avait été mis pour un
# scrub qui, mesuré, ne pouvait rien rendre : 859 images demandées en 0,2 s,
# 4 295 img/s, et le fichier est un PALINDROME — l'image 858 vaut l'image 0 à
# 0,71/255 près. Le geste ne changeait pas d'image.)
set -e
cd "$(dirname "$0")"

# LE SCRIM SORT DU FICHIER. Il protégeait la phrase du dôme de la pilule ; si on
# le cuit dans le calque pilule, il VOYAGE avec elle et noircit la braise à
# l'arrivée. Il devient un asset, posé en SwiftUI au-dessus des deux calques.
python3 - <<'EOF'
import numpy as np
from PIL import Image
W,H=1080,2348
x=np.linspace(0,W-1,W)[None,:]; y=np.linspace(0,H-1,H)[:,None]
def smooth(a,lo,hi):
    t=np.clip((a-lo)/(hi-lo),0,1); return t*t*(3-2*t)
fy=1-smooth(y,400,980); fx=1-smooth(x,480,1020)
coin=0.58*fy*fx
fg=0.92*np.clip(1-x/349.0,0,1)**1.35
fen=np.clip((1400-y)/300.0,0,1)*np.clip(y/60.0,0,1)
a=np.clip(coin+fg*fen,0,0.94)
img=np.zeros((H,W,4),dtype=np.uint8); img[...,3]=(a*255).astype(np.uint8)
Image.fromarray(img).save("scrim-fond.png")
EOF

DEST=../../Woop/Media
SCRIM=../../Woop/Assets.xcassets/home-fond-scrim.imageset
mkdir -p "$SCRIM"
cp scrim-fond.png "$SCRIM/home-fond-scrim.png"
cat > "$SCRIM/Contents.json" <<'EOF'
{
  "images" : [
    { "filename" : "home-fond-scrim.png", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
echo "scrim → Assets/home-fond-scrim"

# ── LE CALQUE PILULE ────────────────────────────────────────────────────────
# La branche [0:v] de recuit_fond.sh, à la lettre : le verre COUCHÉ à 75°, posé
# en overlay (seul overlay accepte des coordonnées négatives — le corps du verre
# doit sortir par la gauche).
ffmpeg -y -v error \
  -i ~/Downloads/pills_2.mp4 \
  -filter_complex "\
[0:v]crop=1368:2829:448:408,rotate=75*PI/180:ow=3088:oh=2055:fillcolor=black,scale=1469:978[pill];\
color=c=black:s=1080x2348:r=24[bg];\
[bg][pill]overlay=x=-360:y=348:shortest=1[p];\
[p]split[a][b];[b]reverse,trim=start_frame=1:end_frame=144,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=3.0*PTS,minterpolate=fps=24:mi_mode=blend,crop=1080:864:0:400,scale=1206:-2,format=yuv420p[out]" \
  -map "[out]" -c:v libx264 -preset slow -crf 21 \
  -pix_fmt yuv420p -g 48 -keyint_min 48 -sc_threshold 0 \
  -movflags +faststart -an \
  "$DEST/home-fond-pilule.mp4"
echo "pilule → $DEST/home-fond-pilule.mp4"

# ── LE CALQUE BRAISE ────────────────────────────────────────────────────────
# La branche [1:v], MOITIÉ DÉFINITION (gradient p99 = 2,0 : c'est un dégradé).
ffmpeg -y -v error \
  -i ~/Downloads/flamme.mp4 \
  -filter_complex "\
[0:v]pad=w=2160:h=4316:x=0:y=480:color=black,crop=1984:4316:88:0,scale=1080:2348[f];\
[f]split[a][b];[b]reverse,trim=start_frame=1:end_frame=144,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=3.0*PTS,minterpolate=fps=24:mi_mode=blend,crop=1080:1148:0:1200,scale=604:-2,format=yuv420p[out]" \
  -map "[out]" -c:v libx264 -preset slow -crf 22 \
  -pix_fmt yuv420p -g 48 -keyint_min 48 -sc_threshold 0 \
  -movflags +faststart -an \
  "$DEST/home-fond-flamme.mp4"
echo "braise → $DEST/home-fond-flamme.mp4"

# LES DEUX IMAGES DE POSE, une par calque. ⚠️ Elles rentrent DANS le
# UIViewRepresentable (sous le playerLayer, masquées sur isReadyForDisplay) :
# en additif, une pose posée DEHORS s'AJOUTE à la vidéo et on verrait deux
# pilules, une fixe et une qui descend.
for n in pilule flamme; do
  D=../../Woop/Assets.xcassets/home-fond-$n-poster.imageset
  mkdir -p "$D"
  ffmpeg -y -v error -i "$DEST/home-fond-$n.mp4" -vf "select=eq(n\,0)" -vsync 0 -q:v 3 \
    "$D/home-fond-$n-poster.jpg"
  cat > "$D/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "home-fond-$n-poster.jpg", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
  echo "pose $n → Assets/home-fond-$n-poster"
done

ls -la "$DEST"/home-fond-*.mp4
