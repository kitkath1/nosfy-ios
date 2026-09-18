#!/bin/zsh
# LA VIDÉO « GALET » DE LA POP-UP WELCOME PREMIÈRE FOIS (13-09, nuit).
#
# Source : ~/Downloads/video_gaet.mp4 — Nosfy avance sur un chemin de galets de
# verre et s'éloigne dans la nuit ; le fichier finit par un fondu au noir
# (mesuré : la lumière descend de 82 à 64 entre 6,9 s et 8,6 s, noir dès 8,1 s
# au seuil 0,06). 3840 × 2160, 24 img/s, 9,04 s, avec son.
#
# Verdict Kathryn : « fais en fondu cette vidéo plutôt, et à la fin elle
# s'arrête sur le galet et elle se rejoue en loop ».
#
# La cuisson :
#  · coupée à 7,0 s — AVANT le fondu de la source : la dernière image tenue
#    montre les galets, pas le noir ;
#  · l'image du galet est TENUE 1,8 s (tpad clone) — « elle s'arrête sur le
#    galet » ;
#  · fondu d'entrée 0,5 s et de sortie 0,6 s (pendant la tenue) : la boucle
#    (la robe rejoue la vidéo en `boucle: true`) passe par le noir, jamais une
#    coupe sèche ;
#  · 16:9 gardé (la tête réduite de la card, `tete: 0.40`, est presque 16:9 :
#    aspect fit, rien de coupé), 1280 × 720, muette, H.264 slow crf 21 ;
#  · LES NOIRS ÉCRASÉS + UNE VIGNETTE (verdict 14-09 : « pas assez fondue, on voit
#    la bordure du haut coupée avec le background noir ») — mesuré : le fond de la
#    source n'est PAS noir (bande haute à 35/255, coins à 17-26) et son rectangle
#    se lisait sur la card. `curves` envoie tout ce qui est sous 0,12 à zéro en
#    gardant les hautes lumières des galets ; `vignette` éteint les bords.
#
# ⚠️ À lancer depuis la racine du dépôt.
set -e
SRC="$HOME/Downloads/video_gaet.mp4"
OUT="Nosfy/Media/welcome-galet-premiere.mp4"
ffmpeg -y -v error -i "$SRC" -an \
  -vf "trim=end=7.0,setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=1.8,curves=all='0/0 0.12/0 0.30/0.22 0.60/0.60 1/1',vignette=angle=PI/3.6:mode=forward,fade=t=in:st=0:d=0.5,fade=t=out:st=8.2:d=0.6,scale=1280:720:flags=lanczos,format=yuv420p" \
  -c:v libx264 -preset slow -crf 21 -movflags +faststart "$OUT"
ls -la "$OUT"
ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height,nb_frames -of default=nw=1 "$OUT"
