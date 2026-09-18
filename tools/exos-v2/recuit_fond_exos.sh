#!/bin/zsh
# LA RECUISSON DU FOND DE LA PAGE EXERCICES (22-08) — produit
# Nosfy/Media/exos-fond-loop.mp4 depuis les deux sources de Kathryn.
#
# Sources : ~/Downloads/forme_glass_red_2.mp4 (le verre rouge, 169 frames)
#           ~/Downloads/flamme_2.mp4          (la nappe de feu, 145 frames)
#           2160x3836, 24 i/s, noirs a VRAI 0.
#
# C'est le jumeau de ../home-v2/recuit_fond.sh : les quatre pieges y sont
# deja payes, on ne les repaie pas.
#  1. LE VERRE EST COUCHE ET IL ENTRE PAR LA DROITE (arbitrage de Kathryn) :
#     rotation +90 (horaire) — le dome de la forme devient une CALOTTE qui
#     entre par le flanc droit a mi-hauteur, son corps sort du cadre. Le
#     placement se fait en `overlay` sur un fond noir, JAMAIS en `pad` :
#     seul overlay accepte de laisser deborder la forme hors du cadre.
#     + LE RALENTI x3 (setpts) : chaque frame tenue trois fois, le pas de
#     mouvement passe sous le seuil ou l'oeil « capte que c'est une video ».
#  2. LA FUSION EN RGB (`format=gbrp` AVANT `blend`) — un blend "screen" sur
#     du yuv420p fusionne les PLANS YUV : le neutre chroma (128) passe en
#     screen fabrique du MAGENTA et souleve les noirs a 37.
#  3. LE SCRIM CUIT DANS LE FICHIER (scrim-fond-exos.png, genere ci-dessous) :
#     le bandeau du titre en haut (la nuit doit y etre franche, le petit
#     titre du scroll s'y pose), et un voile sur la nappe de flamme — sans
#     lui les graduations BLANCHES de la molette se posent sur du feu vif et
#     ne se lisent plus. La lumiere ne vit qu'aux BORDS : flanc droit
#     (le verre), bas (la braise).
#  4. LE PING-PONG (aller + retour sans doubler les frames de bord) : les
#     deux sources sont tronquees a 144 frames pour que la couture tombe
#     juste. En direct, la couture d'une boucle nue vaut 12.
#  5. L'IMAGE DE POSE, cuite dans les assets et posee SOUS la video : le
#     simulateur decode en LOGICIEL et rate des frames — une frame ratee sur
#     une couche opaque, c'est du NOIR plein ecran (« des fois glitch noir »).
set -e
cd "$(dirname "$0")"

python3 - <<'EOF'
import numpy as np
from PIL import Image
W,H=1080,2348
x=np.linspace(0,W-1,W)[None,:]; y=np.linspace(0,H-1,H)[:,None]
def smooth(a,lo,hi):
    t=np.clip((a-lo)/(hi-lo),0,1); return t*t*(3-2*t)
# LE BANDEAU DU TITRE : nuit franche jusqu'a 300, dissoute a 620. C'est la
# zone du chevron, du grand « Exercice » et du petit titre du scroll.
haut = 0.80*(1-smooth(y,300,620))
# LA NAPPE DE BRAISE : le feu de flamme_2 monte trop haut et trop clair pour
# des graduations blanches. On le tient sous la molette et on eteint
# franchement ce qui remonte au-dessus d'elle.
bas  = 0.58*smooth(y,1500,1950)
# LA FLAQUE SOUS LA MOLETTE (mesuree a la capture) : le disque de verre fume
# posait un galet BLANC LAITEUX sur le feu vif, et les graduations blanches
# s'y perdaient. Une pastille gaussienne centree sur le knob (bas de card,
# centre horizontal) calme le foyer LA OU l'objet se pose, sans eteindre la
# braise autour — c'est le scrim de la phrase de la home, applique a un
# instrument.
cx, cy = W*0.50, H*0.915
flaque = 0.44*np.exp(-(((x-cx)/340.0)**2 + ((y-cy)/260.0)**2))
# Le flanc GAUCHE reste nuit : la colonne gauche du Pinterest y vit, et la
# lumiere de cette page appartient a la droite (le verre) et au bas (le feu).
gauche = 0.30*(1-smooth(x,30,300))*smooth(y,520,900)*(1-smooth(y,1500,1900))
a=np.clip(haut+bas+gauche+flaque,0,0.92)
# LES RAMPES DE BORD (verdict 22-08 : « on voit sur les cotes comme des
# traits »). Mesure a la capture : au flanc DROIT, a 8 pt du bord de la card,
# la video montait a 249 de rouge sur 752 lignes — le verre TRANCHE NET par le
# bord arrondi, et un bord franc de lumiere se lit comme un trait pose sur la
# page. Le correctif est celui de la home, mot pour mot : le corps du verre ne
# doit pas avoir de bord, il doit FONDRE dans la nuit. Rampes en puissance 1,1
# (une rampe lineaire laisse une arete visible a son depart), et elles
# EMPORTENT le reste du scrim (max, pas somme) : au bord, c'est noir, point.
# ⚠️ LES RAMPES ONT FONDU (22-08 bis). Elles faisaient 120 et 90 px du temps
# ou la card etait rentree de 10 pt : il fallait que le verre FONDE avant son
# arete, sinon il y lisait un trait. Depuis que la card prend les deux flancs,
# son bord EST le bord de l'ecran — une lumiere qui sort de l'ecran est
# normale, c'est une lumiere qui s'arrete AVANT lui qui se lit comme une
# bordure noire (verdict : « on voit encore des border noir sur les cotes »,
# mesure : 14 pt de braise en sourdine). Il ne reste qu'un souffle, juste de
# quoi qu'aucun pixel vif ne soit tranche net.
bordD = 0.98*np.clip(1-(W-1-x)/16.0,0,1)**1.1
bordG = 0.98*np.clip(1-x/16.0,0,1)**1.1
bordB = 0.90*np.clip(1-(H-1-y)/14.0,0,1)**1.2
a=np.maximum(np.maximum(a,bordD),np.maximum(bordG,bordB))
img=np.zeros((H,W,4),dtype=np.uint8); img[...,3]=(a*255).astype(np.uint8)
Image.fromarray(img).save("scrim-fond-exos.png")
EOF

ffmpeg -y -v error \
  -i ~/Downloads/forme_glass_red_2.mp4 \
  -i ~/Downloads/flamme_2.mp4 \
  -i scrim-fond-exos.png \
  -filter_complex "\
[0:v]trim=end_frame=144,setpts=PTS-STARTPTS,crop=1520:2760:400:520,\
rotate=90*PI/180:ow=2760:oh=1520:fillcolor=black,scale=1560:860[verre];\
color=c=black:s=1080x2348:r=24,format=gbrp[bg];\
[bg][verre]overlay=x=396:y=612:shortest=1,format=gbrp[p];\
[1:v]trim=end_frame=144,setpts=PTS-STARTPTS,pad=w=2160:h=4120:x=0:y=284:color=black,\
crop=1984:4120:88:0,scale=1080:2348,format=gbrp[f];\
[p][f]blend=all_mode=screen[m];\
[m][2:v]overlay=0:0[s];\
[s]split[a][b];[b]reverse,trim=start_frame=1:end_frame=143,setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,setpts=3.0*PTS,minterpolate=fps=24:mi_mode=blend,\
scale=1620:3522,format=yuv420p[out]" \
  -map "[out]" -c:v libx264 -preset slow -crf 18 \
  -pix_fmt yuv420p -g 48 -keyint_min 24 -sc_threshold 0 \
  -movflags +faststart -an \
  ../../Nosfy/Media/exos-fond-loop.mp4

mkdir -p ../../Nosfy/Assets.xcassets/exos-fond-poster.imageset
ffmpeg -y -v error -i ../../Nosfy/Media/exos-fond-loop.mp4 \
  -vf "select=eq(n\,0)" -vsync 0 -q:v 3 \
  ../../Nosfy/Assets.xcassets/exos-fond-poster.imageset/exos-fond-poster.jpg
echo "pose  → Assets/exos-fond-poster"
echo "cuit  → Nosfy/Media/exos-fond-loop.mp4"
