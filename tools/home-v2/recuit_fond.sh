#!/bin/zsh
# LA RECUISSON DU FOND DE LA HOME (jalon V1, plan §9) — reproduit
# Woop/Media/home-fond-loop.mp4 depuis les deux sources de Kathryn.
#
# Sources : ~/Downloads/pills_2.mp4 + ~/Downloads/flamme.mp4
#           (2160×3836, 24 i/s, 6 s, noirs à VRAI 0 — mesuré)
#
# Les quatre gestes, et leurs pièges payés :
#  1. LE VERRE EST COUCHÉ (verdict « c'est incliné sur le côté, sous le
#     texte ») — sa maquette ne montre pas une pilule debout : un VERRE EN
#     DIAGONALE qui entre par le bas-gauche, passe SOUS la phrase, et dont
#     le dôme (la grande caustique blanche) se pose en haut à droite.
#     Angle et pose trouvés par RECOUVREMENT DE MASQUES contre sa maquette
#     (le profil de bord seul se faisait piéger par la nappe du bas) :
#     **75° horaire, contenu de 440 × 269 pt, bord droit à 330, haut à
#     175, corps qui SORT par la gauche (x = −110)** — IoU 0,46 pour deux
#     vidéos différentes (sa maquette est montée sur pills_glass).
#     ⚠️ Le placement se fait en `overlay` sur un fond noir, PAS en `pad` :
#     seul overlay accepte des coordonnées NÉGATIVES, et le corps du verre
#     doit sortir du cadre.
#     + LE RALENTI ×2 (setpts=2.0*PTS, verdict « on capte que c'est une
#     vidéo ») : chaque frame tenue deux fois, le pas de mouvement passe à
#     ~0,35 de luminance — sous le seuil — et le décodeur travaille moitié
#     moins. La boucle dure 24 s.
#  2. LA FUSION EN RGB (`format=gbrp` AVANT `blend`) — un blend "screen"
#     sur du yuv420p fusionne les PLANS YUV : le neutre chroma (128)
#     passé en screen fabrique du MAGENTA et soulève les noirs à 37.
#  3. LE SCRIM DE LA PHRASE CUIT DANS LE FICHIER (scrim.png, généré
#     ci-dessous) : le coin haut-gauche + une pastille gaussienne sous la
#     queue de « sur 5 prévus. » (le liseré du dôme y montait à 182 aux
#     frames pleines). Mesuré après cuisson : L1-L4 p95 = 0, L5 ≤ 52 au
#     pire frame (la flaque validée du J2 était à 55).
#  5. LE GLITCH NOIR (verdict 21-08 « des fois glitch noir, résous
#     ⚠️ SORTIE PORTÉE À 1620 x 3522 (22-08). Elle était en 540 x 1174 pour
#     ménager le SIMULATEUR, qui décode en logiciel — mais l'écran fait
#     1206 x 2622 : la vidéo était déjà agrandie 2,23x AU REPOS, et le zoom
#     cinématique x2 la poussait à 4,5x. Verdict : « on dirait qu'elle est
#     pixel », et c'est mesuré. Le téléphone décode en MATÉRIEL et avale ça
#     sans broncher ; on ne paie plus la qualité du produit pour le confort
#     ⚠️ GOP COURT (-g 12) POUR LE SCRUB — la technique de la page AirPods :
#     un pixel de geste = une frame, aucun moteur 3D, juste un seek. Avec une
#     clé toutes les 48 frames, chaque seek décodait jusqu'à 48 images et le
#     geste hachait. MESURÉ : en toutes-clés (-g 1) le fichier montait à
#     99 Mo — l'intra-only compresse trop mal à cette définition. À -g 12 le
#     pire seek ne décode plus que 12 images et le poids reste tenable.
#     (Ancien commentaire : le simulateur décode
#     en LOGICIEL, et à 1080 x 2348 il rate des frames ; une frame ratée sur
#     une couche opaque, c'est du NOIR plein écran. Le contenu est mou
#     (fumée, verre) : la moitié de résolution ne se voit pas. GOP court
#     (une clé toutes les 2 s) pour que la boucle reprenne franc. Et une
#     IMAGE DE POSE est cuite dans les assets, posée SOUS la vidéo.
#
#  4. LE PING-PONG (aller + retour sans doubler les frames de bord) :
#     couture mesurée 1,0-1,35 pour un bruit entre voisines de 0,7 —
#     sous le seuil visible. En direct, la couture valait 12.
set -e
cd "$(dirname "$0")"

python3 - <<'EOF'
import numpy as np
from PIL import Image
W,H=1080,2348
x=np.linspace(0,W-1,W)[None,:]; y=np.linspace(0,H-1,H)[:,None]
def smooth(a,lo,hi):
    t=np.clip((a-lo)/(hi-lo),0,1); return t*t*(3-2*t)
fy=1-smooth(y,400,980); fx=1-smooth(x,480,1020)
coin=0.58*fy*fx
# LE FONDU DE GAUCHE (verdict 21-08, le carre vert) : le corps du verre ne
# doit pas avoir de bord a gauche, il doit FONDRE dans la nuit. Rampe
# horizontale 0,92 -> 0 sur 130 pt (349 px), fenetree en y pour laisser la
# nappe de flamme du bas intacte.
fg=0.92*np.clip(1-x/349.0,0,1)**1.35
fen=np.clip((1400-y)/300.0,0,1)*np.clip(y/60.0,0,1)
a=np.clip(coin+fg*fen,0,0.94)
img=np.zeros((H,W,4),dtype=np.uint8); img[...,3]=(a*255).astype(np.uint8)
Image.fromarray(img).save("scrim-fond.png")
EOF

ffmpeg -y -v error \
  -i ~/Downloads/pills_2.mp4 \
  -i ~/Downloads/flamme.mp4 \
  -i scrim-fond.png \
  -filter_complex "\
[0:v]crop=1368:2829:448:408,rotate=75*PI/180:ow=3088:oh=2055:fillcolor=black,scale=1469:978[pill];\
color=c=black:s=1080x2348:r=24,format=gbrp[bg];\
[bg][pill]overlay=x=-360:y=348:shortest=1,format=gbrp[p];\
[1:v]pad=w=2160:h=4316:x=0:y=480:color=black,crop=1984:4316:88:0,scale=1080:2348,format=gbrp[f];\
[p][f]blend=all_mode=screen[m];\
[m][2:v]overlay=0:0[s];\
[s]split[a][b];[b]reverse,trim=start_frame=1:end_frame=144,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=3.0*PTS,minterpolate=fps=24:mi_mode=blend,scale=1620:3522,format=yuv420p[out]" \
  -map "[out]" -c:v libx264 -preset slow -crf 21 \
  -pix_fmt yuv420p -g 12 -keyint_min 12 -sc_threshold 0 \
  -movflags +faststart -an \
  ../../Woop/Media/home-fond-loop.mp4

# L'IMAGE DE POSE : la première frame, en dur dans les assets. La vidéo est
# posée DESSUS — si le décodeur rate une frame ou si la couche n'est pas
# encore prête, c'est elle qu'on voit, jamais du noir.
ffmpeg -y -v error -i ../../Woop/Media/home-fond-loop.mp4 \
  -vf "select=eq(n\,0)" -vsync 0 -q:v 3 \
  ../../Woop/Assets.xcassets/home-fond-poster.imageset/home-fond-poster.jpg
echo "pose  → Assets/home-fond-poster" 
echo "cuit → Woop/Media/home-fond-loop.mp4"
