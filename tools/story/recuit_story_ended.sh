#!/bin/zsh
# LA RECUISSON DE « SESSION ENDED » — les quatre fichiers du plan
# (tools/story/PLAN-STORY-V2-ENDED.md, jalon E1).
#
#  · story-ended-verre-a.mp4   — la gélule de pills_2 COUCHÉE (le verre du mot
#                                « Session »), entière sur bande paysage noire
#  · story-ended-verre-b.mp4   — la gélule de rouge_liquid COUCHÉE (le verre
#                                du mot « Ended »), braise ambrée
#  · story-pilule-droite.mp4   — la pilule de la home EN MIROIR : mêmes
#                                paramètres que recuit_calques.sh + hflip,
#                                le corps sort du cadre à DROITE
#  · story-eclair-loop.mp4     — l'éclair de verre, déjà incliné dans la
#                                source, boîte utile, ralenti ×2
#
# Les écoles copiées, pas réinventées :
#  ⚠️ jamais -ss : tout trim vit DANS le graphe (un fondu sur fenêtre -ss
#     s'applique aux images jetées) ;
#  ⚠️ ping-pong amputé de ses DEUX doublons de bord (reverse + trim
#     start_frame=1:end_frame=N-1) — couture zéro par construction ;
#  ⚠️ UNE passe d'encodage (le double encodage pose des macro-blocs) ;
#  ⚠️ les boîtes utiles sont MESURÉES à pleine résolution, seuil 1/255,
#     union sur 8 frames (sonde du 26-08) :
#       pills_2       x 443..1829  y 408..3258   (145 img, 24 i/s)
#       rouge_liquid  x 489..1769  y 568..3144   (169 img)
#       éclair        x 560..1561  y 1072..2927  (145 img)
#  ⚠️ sorties NEUVES à 30 i/s (le 24 bat en 3:2 à 60 Hz — CalqueVideo lit à
#     rate 1,0) ; la pilule miroir reste à 24 comme sa jumelle home (même
#     matière, mêmes caustiques sous le seuil de perception).
#
# Le ralenti diffère de la home et c'est VOULU : la home veut un mouvement
# sous le seuil (setpts=3.0) ; la verrière veut qu'on VOIE la pills tourner
# dans les lettres (setpts=1.5). L'éclair « bouge » franchement : ×2.
set -e
cd "$(dirname "$0")"
DEST=../../Woop/Media

# ── LE VERRE A — « Session » (pills_2, la bande CLAIRE) ────────────────────
# v2 (verdict 26-08 : « on voit pas, c'est quasi tout noir — prendre la
# pills quand c'est ROUGE ou TRÈS CLAIR ») : plus la gélule entière (son
# centre est noir), mais la BANDE BASSE-GAUCHE du couché — le bulbe
# lumineux + le liseré rouge du bord — choisie sur pixels. Un petit lift
# eq (gamma 1,22) avec la SATURATION QUI MONTE (1,12 — loi anti-brun).
# pills_2 : 145 images → retour 143 → palindrome 288.
ffmpeg -y -v error \
  -i ~/Downloads/pills_2.mp4 \
  -filter_complex "\
[0:v]crop=1392:2856:440:404,transpose=1,crop=1000:600:40:560,\
eq=gamma=1.30:saturation=1.14,scale=1920:640[p];\
[p]split[a][b];[b]reverse,trim=start_frame=1:end_frame=144,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=1.5*PTS,minterpolate=fps=30:mi_mode=blend,format=yuv420p[out]" \
  -map "[out]" -c:v libx264 -preset slow -crf 18 \
  -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 \
  -movflags +faststart -an \
  "$DEST/story-ended-verre-a.mp4"
echo "verre A → $DEST/story-ended-verre-a.mp4"

# ── LE VERRE B — « Ended » (rouge_liquid, la bande CLAIRE) ─────────────────
# Même verdict, même bande : le bulbe ambré + le liseré rouge.
# rouge_liquid : 169 images → retour 167 → palindrome 336.
ffmpeg -y -v error \
  -i ~/Downloads/"Video rouge_liquid.mp4" \
  -filter_complex "\
[0:v]crop=1284:2580:488:566,transpose=1,crop=1100:660:0:220,\
eq=gamma=1.22:saturation=1.12,scale=1920:640[p];\
[p]split[a][b];[b]reverse,trim=start_frame=1:end_frame=168,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=1.5*PTS,minterpolate=fps=30:mi_mode=blend,format=yuv420p[out]" \
  -map "[out]" -c:v libx264 -preset slow -crf 18 \
  -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 \
  -movflags +faststart -an \
  "$DEST/story-ended-verre-b.mp4"
echo "verre B → $DEST/story-ended-verre-b.mp4"

# ── LES DEUX MACROS (pages 2 et 3) — DÉFINITION NATIVE ─────────────────────
# « deux cadrages stp et en 4K sinon ça va faire caca » : AUCUN scale,
# les crops sortent à la définition de la source (2160×3836). Ralenti ×2,
# ping-pong, 30 i/s.
#
# macro-bas (page Détails), v2 TOUR 4 : l'arc n'est PAS un dôme posé —
# la Frame …228 le montre en DIAGONALE (il entre bas-gauche, la crête
# vers le haut-droit). La rotation se CUIT (+22°, l'école du verre
# couché de la home) — jamais un rotationEffect sur ce calque : ses
# bords de coupe entreraient dans l'écran en tournant.
# v3 TOUR 5 (« la pills est beaucoup plus grande, il faut vraiment un
# 4K ») : le crop 1720 était SOUS l'affichage (1,75·L ≈ 2110 px @3x) —
# la source se SUR-ÉCHANTILLONNE ×1,4 en lanczos AVANT la rotation
# (+29°, plus raide, la pente de la Frame …228) et la fenêtre sort à
# 2400×1820, AU-DESSUS de l'affichage.
ffmpeg -y -v error \
  -i ~/Downloads/pills_2.mp4 \
  -filter_complex "\
[0:v]crop=1392:2856:440:404,scale=1949:3998:flags=lanczos,\
rotate=29*PI/180:ow=3644:oh=4442:fillcolor=black,crop=2400:1820:744:374[m];\
[m]split[a][b];[b]reverse,trim=start_frame=1:end_frame=144,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=2.0*PTS,minterpolate=fps=30:mi_mode=blend,format=yuv420p[out]" \
  -map "[out]" -c:v libx264 -preset slow -crf 17 \
  -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 \
  -movflags +faststart -an \
  "$DEST/story-macro-bas.mp4"
echo "macro bas → $DEST/story-macro-bas.mp4"

# macro-flanc (page Story card), v2 TOUR 4 : LE BULBE ROND (Frame …230),
# pas l'épaule — le bas de la gélule debout, le noir NATUREL gardé
# autour : le contour courbe du verre est le VRAI bord de l'objet, il ne
# se masque pas.
ffmpeg -y -v error \
  -i ~/Downloads/"Video rouge_liquid.mp4" \
  -filter_complex "\
[0:v]crop=1500:1352:400:1948[m];\
[m]split[a][b];[b]reverse,trim=start_frame=1:end_frame=168,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=2.0*PTS,minterpolate=fps=30:mi_mode=blend,format=yuv420p[out]" \
  -map "[out]" -c:v libx264 -preset slow -crf 17 \
  -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 \
  -movflags +faststart -an \
  "$DEST/story-macro-flanc.mp4"
echo "macro flanc → $DEST/story-macro-flanc.mp4"

# ── LA PILULE MIROIR — l'acte B, en haut à droite ──────────────────────────
# La chaîne de recuit_calques.sh À LA LETTRE (crop, rotate 75°, overlay
# x=-360, ping-pong, setpts=3.0, blend 24, crop de boîte, scale 1206) puis
# hflip EN DERNIER : tout le canevas bascule, le corps sort à DROITE.
ffmpeg -y -v error \
  -i ~/Downloads/pills_2.mp4 \
  -filter_complex "\
[0:v]crop=1368:2829:448:408,rotate=75*PI/180:ow=3088:oh=2055:fillcolor=black,scale=1469:978[pill];\
color=c=black:s=1080x2348:r=24[bg];\
[bg][pill]overlay=x=-360:y=348:shortest=1[p];\
[p]split[a][b];[b]reverse,trim=start_frame=1:end_frame=144,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=3.0*PTS,minterpolate=fps=24:mi_mode=blend,crop=1080:864:0:400,scale=1206:-2,hflip,format=yuv420p[out]" \
  -map "[out]" -c:v libx264 -preset slow -crf 21 \
  -pix_fmt yuv420p -g 48 -keyint_min 48 -sc_threshold 0 \
  -movflags +faststart -an \
  "$DEST/story-pilule-droite.mp4"
echo "pilule miroir → $DEST/story-pilule-droite.mp4"

# ── L'ÉCLAIR ───────────────────────────────────────────────────────────────
# La source est déjà inclinée (l'attitude de la maquette) : boîte utile +
# marge, ralenti ×2, ping-pong, 720 de large (affiché ~150 pt = 450 px @3x,
# sur-échantillonnage 1,6×).
ffmpeg -y -v error \
  -i ~/Downloads/"éclair.mp4" \
  -filter_complex "\
[0:v]crop=1016:1872:552:1060,scale=720:-2[e];\
[e]split[a][b];[b]reverse,trim=start_frame=1:end_frame=144,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=2.0*PTS,minterpolate=fps=30:mi_mode=blend,format=yuv420p[out]" \
  -map "[out]" -c:v libx264 -preset slow -crf 18 \
  -pix_fmt yuv420p -g 60 -keyint_min 60 -sc_threshold 0 \
  -movflags +faststart -an \
  "$DEST/story-eclair-loop.mp4"
echo "éclair → $DEST/story-eclair-loop.mp4"

# ── LES POSES (une par fichier, première frame exacte) ─────────────────────
# ⚠️ La pose rentre DANS le UIViewRepresentable (sous le playerLayer,
# masquée sur isReadyForDisplay) — posée dehors en additif on verrait
# l'objet en double.
for n in story-ended-verre-a story-ended-verre-b story-pilule-droite story-eclair-loop story-macro-bas story-macro-flanc; do
  D=../../Woop/Assets.xcassets/$n-poster.imageset
  mkdir -p "$D"
  ffmpeg -y -v error -i "$DEST/$n.mp4" -vf "select=eq(n\,0)" -vsync 0 -q:v 3 \
    "$D/$n-poster.jpg"
  cat > "$D/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "$n-poster.jpg", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
  echo "pose → Assets/$n-poster"
done

ls -la "$DEST"/story-*.mp4
