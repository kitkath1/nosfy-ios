#!/bin/zsh
# LE RECUIT DE LA MOLETTE — la vidéo sous le verre natif du donut.
#
# Source : ~/Downloads/forme_glass_red_2.mp4 (2160×3836, 24 i/s, 7,04 s,
# 169 images — le galet de verre rouge sombre sur noir). Le donut la
# réclame ZOOMÉE 2× : la fenêtre centrale, « le noir qui brûle ».
#
# ⚠️ LE ZOOM EST CUIT ICI, PAS DANS SWIFTUI (la loi de la porte) : un
# `scaleEffect` posé après un masque compose dans un tampon non zoomé
# puis l'agrandit — zoom rastérisé, donc flou. On choisit la FENÊTRE.
#
# ⚠️ AUCUNE LIGNE DE `project.pbxproj` À TOUCHER : groupes synchronisés
# Xcode 16 — déposer le .mp4 dans Woop/Media/ suffit. Nom UNIQUE dans
# tout Woop/ (les sous-dossiers sont aplatis dans le bundle).
set -e
cd "$(dirname "$0")"

SRC=~/Downloads
DEST=../../Woop/Media
ASSETS=../../Woop/Assets.xcassets
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# La recette 30 i/s de la porte : GOP 2 s à 30 (à 60 Hz, du 24 bat en
# 3:2 et ça se voit — d'où le minterpolate plus bas).
X264=(-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p
      -g 60 -keyint_min 60 -sc_threshold 0 -movflags +faststart -an)

nbf() { ffprobe -v error -select_streams v:0 -count_frames \
          -show_entries stream=nb_read_frames -of csv=p=0 "$1" }

# Le ping-pong maison (recuit_porte) : le retour amputé de ses DEUX
# doublons (première et dernière image) — couture à ZÉRO par
# construction, la dernière image EST la voisine de la première.
pingpong() {
  local n=$(nbf "$1")
  ffmpeg -y -v error -i "$1" -filter_complex "\
[0:v]split[a][b];\
[b]reverse,trim=start_frame=1:end_frame=$((n-1)),setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,format=yuv420p[out]" \
    -map "[out]" "${X264[@]}" "$2"
}

# ── L'ALLER ──────────────────────────────────────────────────────────
# Crop carré de la moitié centrale : x=(2160−1080)/2=540,
# y=(3836−1080)/2=1378. Centrage MESURÉ (signalstats) : YAVG 25–42,
# YMAX 193–221 dans la fenêtre — le noir-qui-brûle, avec du combustible
# pour le verre ; les bandes voisines portent la même matière, rien
# d'amputé. minterpolate APRÈS le crop (4× moins de pixels à
# interpoler). Aucun -ss : on prend les 169 images. Sortie 1080 : pas
# d'upscale (le GPU resize gratuitement au rendu).
ffmpeg -y -v error -i "$SRC/forme_glass_red_2.mp4" \
  -vf "crop=1080:1080:540:1378,minterpolate=fps=30:mi_mode=blend,format=yuv420p" \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -an "$TMP/molette-aller.mp4"
echo "aller  → $(nbf "$TMP/molette-aller.mp4") images (attendu ≈ 211 ; 169 = minterpolate avalé)"

# ── LE PALINDROME ────────────────────────────────────────────────────
pingpong "$TMP/molette-aller.mp4" "$DEST/molette-glass-loop.mp4"
echo "boucle → $DEST/molette-glass-loop.mp4 ($(nbf "$DEST/molette-glass-loop.mp4") images, attendu 2n−2 ≈ 420)"

# ── L'IMAGE DE POSE ──────────────────────────────────────────────────
# Dans le representable, SOUS le playerLayer : sans elle le raté du
# looper devient un FLASH — quasi noir ici, mais ceinture et bretelles.
D="$ASSETS/molette-glass-poster.imageset"
mkdir -p "$D"
ffmpeg -y -v error -i "$DEST/molette-glass-loop.mp4" -vf "select=eq(n\,0)" \
  -vsync 0 -q:v 3 "$D/molette-glass-poster.jpg"
cat > "$D/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "molette-glass-poster.jpg",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
echo "pose   → $D/molette-glass-poster.jpg"
ls -la "$DEST"/molette-glass-loop.mp4
