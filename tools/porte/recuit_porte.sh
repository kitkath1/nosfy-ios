#!/bin/zsh
# LE RECUIT DE LA PORTE — jalon J0 de tools/porte/PLAN-PORTE.md.
#
# Quatre fichiers pour l'entrée dans l'app, tous au MÊME canevas :
#
#   · onb-arrivee.mp4     le film d'arrivée, joué UNE fois (5,00 s)
#   · onb-lune-loop.mp4   sa queue en ping-pong — prend le relais à l'image
#   · onb-exos-loop.mp4   le header de la page 2 (les trois pavés)
#   · onb-track-loop.mp4  le header de la page 3 (le kettlebell, RELEVÉ)
#
# La page 4 ne passe pas ici : elle réutilise booster-loop.mp4, déjà au bundle.
#
# ⚠️ UN SEUL CANEVAS, ET IL EST CALCULÉ, PAS CHOISI. Le header fait 0,70 × 874 =
# 612 pt sur 402 de large, soit un ratio de 0,656863. À 1080 px de large (la
# largeur maison), la hauteur tombe donc à 1644 px : 1080/1644 = 0,656934. Écart
# 7,1e-5, soit moins de 0,05 pt sur la hauteur du cadre. **Ratio exact = rien
# n'est rogné par resizeAspectFill** — la même loi qui sauve la flamme de la home
# aujourd'hui. Toute autre cote fera déborder la couche, et le clipShape de
# SwiftUI NE RATTRAPE PAS une couche UIKit (piège payé sur la card exos).
#
# ⚠️ SORTIE À 30 IMG/S, ET C'EST UNE LOI. Les sources sont à 24. À 60 Hz, du 24
# bat en 3:2 — une image sur deux tient deux fois plus longtemps que sa voisine —
# et sur un mouvement de caméra lent, ce battement SE VOIT (la leçon des stories,
# qui le contournent en jouant à 1,25). À 30, chaque lecteur tourne à rate = 1,0,
# le défaut de CalqueVideo, et le problème n'existe pas.
#
# ⚠️ LE ZOOM EST CUIT ICI, PAS DANS SWIFTUI. Un scaleEffect posé après un masque
# compose dans un tampon non zoomé puis l'agrandit : zoom rastérisé, donc flou.
# Les sources portent déjà leur propre mouvement de caméra — on ne rajoute rien,
# on choisit la FENÊTRE.
#
# ⚠️ AUCUNE LIGNE DE project.pbxproj À TOUCHER. Groupes synchronisés Xcode 16 :
# déposer le .mp4 dans Woop/Media/ suffit (vérifié sur le bundle construit : 21
# .mp4 dans Media/, 21 à la RACINE de Woop.app, aucun sous-dossier). En revanche
# un nom de fichier doit être unique dans TOUT Woop/, pas seulement dans son
# dossier — les sous-dossiers sont aplatis.
set -e
cd "$(dirname "$0")"

SRC=~/Downloads
DEST=../../Woop/Media
ASSETS=../../Woop/Assets.xcassets
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

X264=(-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p
      -g 60 -keyint_min 60 -sc_threshold 0 -movflags +faststart -an)

# Le nombre d'images d'un fichier, compté (pas lu dans l'en-tête).
nbf() { ffprobe -v error -select_streams v:0 -count_frames \
          -show_entries stream=nb_read_frames -of csv=p=0 "$1" }

# ── LE PING-PONG ────────────────────────────────────────────────────────────
# On monte l'aller, on compte ses images, on colle le retour amputé de ses DEUX
# doublons (la dernière image de l'aller, et la première quand la boucle
# reboucle). Sans ces deux coupes, le mouvement MARQUE UN TEMPS aux deux
# extrémités — deux images identiques à 30 img/s, c'est 66 ms d'arrêt sur image.
pingpong() {           # $1 = aller (fichier), $2 = sortie
  local n=$(nbf "$1")
  ffmpeg -y -v error -i "$1" -filter_complex "\
[0:v]split[a][b];\
[b]reverse,trim=start_frame=1:end_frame=$((n-1)),setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,format=yuv420p[out]" \
    -map "[out]" "${X264[@]}" "$2"
}

# ── ① LE FILM D'ARRIVÉE ─────────────────────────────────────────────────────
# splash_1 est en HEVC 10 BITS (yuv420p10le) — tout le reste du projet est en
# yuv420p 8 bits. On convertit, on n'embarque pas tel quel.
#
# LA FENÊTRE V2 (l'arbitrage du 22-08 au soir : « la vidéo est trop belle, elle
# doit durer plus longtemps ») : 1,60 → 8,042 s — on part à la NAISSANCE de la
# lumière (mesurée : 8,5/255 de moyenne à 1,60 s), elle fait partie du
# spectacle — PLUS un ralenti de 30 % (`setpts × 1,30`) : le recul devient un
# glissement. C'est la recette éprouvée du fond de la home, qui tourne à
# `setpts=3.0` + minterpolate blend sans que ça se voie ; 1,30 est très en
# dessous. Sortie : 6,442 × 1,30 = 8,374 s = 251 images à 30.
#
# ⚠️ LE FONDU D'ENTRÉE DE 0,45 s N'EST PAS COSMÉTIQUE. La lune de sang meurt au
# noir ; à 1,60 s la source est déjà allumée (max 218), donc sans lui la
# couture redeviendrait une coupe sèche. Le fondu rend le raccord
# noir-sur-noir, qui est le seul raccord introuvable.
#
# ⚠️ **LA FENÊTRE SE COUPE DANS LE GRAPHE, PAS AVEC -ss. PIÈGE PAYÉ DEUX FOIS.**
# Un `-ss` placé APRÈS `-i` est une recherche de SORTIE : ffmpeg décode et filtre
# le clip DEPUIS LE DÉBUT, puis jette les images d'avant le point de coupe. Donc
# `fade=t=in:st=0` s'applique aux images... jetées, et **le fondu n'existe pas
# dans le fichier livré** — sans un mot d'avertissement. Mesuré à la planche de
# contact : image 0 à une moyenne de 21,3/255 au lieu de 0. (Et `-ss` AVANT `-i`
# ne sauve rien : il tombe sur le keyframe le plus proche et la fenêtre glisse.)
# La seule forme juste : `trim` DANS le graphe, puis on remet l'horloge à zéro —
# et le RALENTI s'écrit dans le même setpts : (PTS-STARTPTS)*1.30.
# ── LE ZOOM CINÉMATIQUE, CUIT (V3, verdict 23-08 : « retravaille-la pareil »).
# La source RECULE toute seule ; on ajoute un serrage qui se DESSERRE avec
# elle : 1,16 → 1,00. Les deux mouvements vont dans le même sens, donc l'un
# amplifie l'autre au lieu de le combattre — et l'arrivée se pose en
# S'OUVRANT, ce qui est exactement ce que le plan avait relevé comme la bonne
# mise en scène de ce plan-là.
#
# ⚠️ `zoompan` PUIS `scale`, jamais l'inverse : il travaille sur le canevas
# PLEINE définition (2160 de large) et la réduction finale à 1080 divise par
# deux son erreur d'arrondi — c'est ce qui tue le tremblement de sous-pixel
# pour lequel ce filtre est connu.
# ⚠️ `d=1` : une image par image d'entrée (sans quoi zoompan en fabrique 25).
# ⚠️ **`minterpolate` RESTE, ET AVANT `zoompan`.** Payé : `setpts` ne change
# que les HORODATAGES, il ne fabrique aucune image — et le `fps=30` de
# zoompan ne fait que réétiqueter. Sans minterpolate, le fichier sortait à
# 164 images / 5,47 s au lieu de 277 / 9,24 : le ralenti avait disparu et la
# boucle, coupée plus loin que la fin, ne faisait plus que 16 images.
# zoompan à `d=1` ne rééchantillonne PAS le temps : les deux cohabitent.
# ⚠️ ET SON `fps=30` EST OBLIGATOIRE QUAND MÊME — payé juste après : sans lui
# zoompan retombe sur son défaut de 25, et le fichier sortait à 274 images
# pour 10,96 s (donc lu 20 % trop lent, et la partition Swift à côté).
# ⚠️ La rampe se pilote à `ot` (le temps de SORTIE, en secondes) : `nb_frames`
# n'existe pas dans le vocabulaire de zoompan — l'écrire fait ÉCHOUER le
# graphe (« Undefined constant »), au moins bruyamment.
# Durée de sortie = (8,041667 − 1,20) × 1,35 = 9,236 s.
ARR_T=9.236
ffmpeg -y -v error -i "$SRC/splash_1.mp4" \
  -vf "trim=start=1.20:end=8.041667,setpts=(PTS-STARTPTS)*1.35,\
crop=2160:3288:0:276,minterpolate=fps=30:mi_mode=blend,\
zoompan=z='1.16-0.16*min(ot/$ARR_T\,1)':d=1:fps=30:s=2160x3288\
:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)',\
scale=1080:1644,fade=t=in:st=0:d=0.45,format=yuv420p" \
  "${X264[@]}" "$DEST/onb-arrivee.mp4"
echo "arrivée → $DEST/onb-arrivee.mp4  ($(nbf "$DEST/onb-arrivee.mp4") images)"

# ── ② LA BOUCLE DE LA PAGE 1 ────────────────────────────────────────────────
# ⚠️ ELLE SE COUPE DANS LE FICHIER D'ARRIVÉE, JAMAIS DANS LA SOURCE. La première
# image de la boucle doit être l'image de raccord DU MASTER : c'est ce qui rend
# l'échange invisible PAR CONSTRUCTION (les deux couches montrent la même image,
# donc un échange en une frame ne peut pas se voir). Recoupée depuis la source,
# elle porterait un autre grain de compression et un autre instant.
#
# LE RACCORD SE CALCULE, IL NE SE RECOPIE PLUS. On garde les 3,2 s finales
# (celles où la composition est posée) : `raccord = total − 96`. Le script
# IMPRIME le numéro, et le Swift (`imageRaccord:` dans PorteEntree) doit
# porter CE chiffre — les deux changent ensemble, et un recut qui déplace la
# fin sans qu'on relise cette ligne casserait le seul raccord invisible.
RACCORD=$(( $(nbf "$DEST/onb-arrivee.mp4") - 96 ))
echo "   ⚠️  IMAGE DE RACCORD = $RACCORD  (à reporter dans PorteEntree.swift)"
#
# ⚠️ TEMPO NATIF, AUCUN setpts ici. Le ralenti est déjà CUIT dans le master —
# la boucle en hérite en s'y découpant. Un second ralenti ferait changer la
# vitesse du mouvement à l'instant du relais — une cassure au pire endroit.
# ⚠️ On coupe EN IMAGES (`trim=start_frame=155`), pas en secondes : l'image de
# raccord est un NUMÉRO que le code Swift va rejouer au boundary observer. Une
# coupe en secondes laisse la porte ouverte à un décalage d'une image entre le
# fichier et la constante — et le raccord est justement ce qui ne se voit que
# lorsqu'il rate.
ffmpeg -y -v error -i "$DEST/onb-arrivee.mp4" \
  -vf "trim=start_frame=$RACCORD,setpts=PTS-STARTPTS" \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -an "$TMP/lune-aller.mp4"
pingpong "$TMP/lune-aller.mp4" "$DEST/onb-lune-loop.mp4"
echo "boucle lune → $DEST/onb-lune-loop.mp4  ($(nbf "$DEST/onb-lune-loop.mp4") images)"

# ── ③ LE HEADER DE LA PAGE 2 ────────────────────────────────────────────────
# La fenêtre y=274 garde les TROIS pavés (flamme, haltère, coureur) ; à y=548 le
# coureur sort du cadre par le bas (vérifié à la planche de contact).
ffmpeg -y -v error -i "$SRC/splash_2.mp4" \
  -vf "crop=2160:3288:0:274,scale=1080:1644,\
minterpolate=fps=30:mi_mode=blend,format=yuv420p" \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -an "$TMP/exos-aller.mp4"
pingpong "$TMP/exos-aller.mp4" "$DEST/onb-exos-loop.mp4"
echo "boucle exos → $DEST/onb-exos-loop.mp4  ($(nbf "$DEST/onb-exos-loop.mp4") images)"

# ── ④ LE HEADER DE LA PAGE 3, RELEVÉ ────────────────────────────────────────
# ⚠️ CETTE SOURCE EST PRESQUE VIDE, ET C'EST MESURÉ. Luminance moyenne 16,6/255 ;
# sur le tiers haut, 91,6 % des pixels sont sous L=4 et la matière (kettlebell,
# disque, haltère) tient dans la bande L ∈ [4;64], soit 7,9 % des pixels. Le
# tiers bas est LITTÉRALEMENT noir (max 2).
#
# ⚠️ LOI ANTI-BRUN, ET ELLE EST ÉLIMINATOIRE ICI. Un gamma global sur de l'orange
# sombre remonte le vert plus vite que le rouge en valeur relative : la
# saturation tombe, et une saturation qui baisse, C'EST DU BRUN. La courbe
# ci-dessous relève R > G > B, donc elle SATURE en relevant. Mesuré sur la bande
# de matière [4;64], aux trois instants du clip (le plus sombre → le plus clair) :
#     avant   p99 tiers haut  32 / 34 / 40      ratio R/G/B 1,000 / 0,684 / 0,429
#     après   p99 tiers haut  89 / 93 / 103     ratio R/G/B 1,000 / 0,519 → 0,538 / 0,170
# Cibles du plan : p99 ≥ 90 (tenue partout sauf 89 sur l'image la plus sombre),
# moyenne du cadre ≤ 40 (mesurée 2,4-2,8 — on relève la MATIÈRE, pas le noir :
# le point 0/0 est tenu, les 91,6 % de vide ne bougent pas d'un niveau).
#
# ⚠️ LA COURBE A ÉTÉ CHOISIE PAR LE VERT, PAS PAR LA LUMINOSITÉ. Trois crans
# essayés et MESURÉS sur trois images chacun :
#     doux    p99 80-93   g/r 0,547-0,568   → sous la cible sur 2 images / 3
#     RETENU  p99 89-103  g/r 0,519-0,538   → plus clair ET plus saturé
#     fort    p99 98-114  g/r 0,552-0,574   → le vert REPART : virage au brun
# Le cran fort est plus lumineux et pourtant moins bon : c'est exactement le
# piège que la loi décrit. On s'arrête au cran où g/r est au minimum.
LIFT="curves=\
r='0/0 0.05/0.17 0.15/0.40 0.40/0.70 1/1':\
g='0/0 0.05/0.13 0.15/0.31 0.40/0.59 1/1':\
b='0/0 0.05/0.08 0.15/0.21 0.40/0.45 1/1'"
ffmpeg -y -v error -i "$SRC/splash_3.mp4" \
  -vf "crop=1400:2131:278:0,$LIFT,scale=1080:1644,\
minterpolate=fps=30:mi_mode=blend,format=yuv420p" \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -an "$TMP/track-aller.mp4"
pingpong "$TMP/track-aller.mp4" "$DEST/onb-track-loop.mp4"
echo "boucle track → $DEST/onb-track-loop.mp4  ($(nbf "$DEST/onb-track-loop.mp4") images)"

# ── LES IMAGES DE POSE ──────────────────────────────────────────────────────
# ⚠️ Elles rentrent DANS le UIViewRepresentable, sous le playerLayer, effacées
# sur isReadyForDisplay. AVPlayerLooper vide sa couche 1 à 3 images à chaque
# tour : sans pose sous le lecteur, ce raté devient un FLASH NOIR.
for n in arrivee lune-loop exos-loop track-loop; do
  D="$ASSETS/onb-$n-poster.imageset"
  mkdir -p "$D"
  ffmpeg -y -v error -i "$DEST/onb-$n.mp4" -vf "select=eq(n\,0)" -vsync 0 -q:v 3 \
    "$D/onb-$n-poster.jpg"
  cat > "$D/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "onb-$n-poster.jpg", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
  echo "pose $n → Assets/onb-$n-poster"
done

# LA POSE DE LA PAGE 4 : booster-loop.mp4 est déjà au bundle (le trio de sachets
# de la pop-up), mais il n'a JAMAIS eu d'image de pose — son hôte historique
# (BoosterLoopVideo) vit sur un écran qui l'attend. La porte, elle, le monte à
# l'arrivée sur la page : sans pose, le trou du bouclage y devient un flash.
D="$ASSETS/onb-booster-poster.imageset"
mkdir -p "$D"
ffmpeg -y -v error -i "$DEST/booster-loop.mp4" -vf "select=eq(n\,0)" -vsync 0 -q:v 3 \
  "$D/onb-booster-poster.jpg"
cat > "$D/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "onb-booster-poster.jpg", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
echo "pose booster → Assets/onb-booster-poster"

ls -la "$DEST"/onb-*.mp4
