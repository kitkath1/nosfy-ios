#!/bin/zsh
# LA CUISSON DE LA DUOLINGUO_PAGE (24-08) — produit les 9 fichiers
# Woop/Media/duo-*.mp4 + leurs 9 poses, depuis les sources de Kathryn.
# Plan : tools/duolingo/PLAN-DUOLINGUO.md §3. Les pieges payes qu'on ne
# repaie pas :
#  1. JAMAIS -ss : tout trim/roll DANS le graphe (trim+setpts). Un fondu
#     pose sur une fenetre -ss s'applique aux images JETEES.
#  2. LE PING-PONG ampute ses DEUX doublons de bord (ecole porte,
#     comptage d'images au REEL via nbf) : couture zero par construction.
#  3. RATIO FICHIER = RATIO FENETRE (ecole porte) : le crop se fait AVANT
#     tout, aux cotes EcranSpec — rien n'est rogne par resizeAspectFill.
#  4. LES NOMS DES SOURCES MENTENT (mesure aux planches-contact) :
#     "Video rougeetbleu_liquid.mp4" = la FLAMME BLANCHE,
#     "Video_Flamme_bleu_.mp4"       = le GALET ROUGE-ET-BLEU.
#  5. LES EXTINCTIONS SONT CUITES (scrims numpy) : chaque bord de fenetre
#     qui coupe en plein ecran meurt dans le fichier, pas en runtime.
#  6. LE RETOURNEMENT PREMIUM : vflip+hflip, puis ROTATION DE PHASE DU
#     PALINDROME (jamais de la source brute : sa coupure native PSNR
#     15-22 dB se cuirait au coeur de la boucle). Pas de ralenti :
#     minterpolate blend fabrique des fantomes sur les plumes.
#  7. duo-verre-rouge = CROP du fichier exos deja cuit (ralenti x3, scrim
#     et boucle embarques) — le fichier entier a 137 Mpix/s est interdit.
set -e
cd "$(dirname "$0")"
OUT=../../Woop/Media
ASSETS=../../Woop/Assets.xcassets
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

X264=(-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -g 48 -keyint_min 48 -sc_threshold 0 -movflags +faststart -an)
# ⚠️ LES GALETS SE CUISENT EN UNE PASSE ET A CRF 17 (mesure 24-08) : le
# double encodage master crf 16 -> final crf 20 posait des MACRO-BLOCS dans
# le degrade clair du ventre (zoom x4 : blocs a aretes droites, la source
# est propre). Le palindrome n'a pas besoin d'un master : le compte
# d'images se fait sur la SOURCE (le crop ne change pas le compte).
X264P=(-c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -g 48 -keyint_min 48 -sc_threshold 0 -movflags +faststart -an)
MASTER=(-c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p -an)

# galet en UNE passe : crop+scale+scrim+pingpong dans le meme graphe.
cuirePill() { # $1 nom  $2 source  $3 crop  $4 WxH
  local n=$(nbf "$2")
  ffmpeg -y -v error -i "$2" -i "$TMP/scrim-$1.png" \
    -filter_complex "[0:v]crop=$3,scale=${4/x/:}[v];[v][1:v]overlay=0:0[s];[s]split[a][b];[b]reverse,trim=start_frame=1:end_frame=$((n-1)),setpts=PTS-STARTPTS[r];[a][r]concat=n=2:v=1,format=yuv420p[out]" \
    -map "[out]" $X264P "$OUT/$1.mp4"
}

nbf() { ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 "$1" }

# ------------------------------------------------------------- fonctions
# etape A : crop (+flip) + scale + scrim -> master crf 16
cuireA() { # $1 nom  $2 source  $3 crop  $4 flip(0/1)  $5 WxH
  local flt="crop=$3"
  [[ "$4" == "1" ]] && flt="$flt,vflip,hflip"
  flt="$flt,scale=${5/x/:}"
  ffmpeg -y -v error -i "$2" -i "$TMP/scrim-$1.png" \
    -filter_complex "[0:v]${flt}[v];[v][1:v]overlay=0:0,format=yuv420p[out]" \
    -map "[out]" $MASTER "$TMP/$1-A.mp4"
}
# etape B : ping-pong (retour ampute de ses DEUX doublons) -> final ou master
pingpong() { # $1 in  $2 out  $3 "${(@)ENCODE}"
  local n=$(nbf "$1")
  ffmpeg -y -v error -i "$1" -filter_complex \
    "[0:v]split[a][b];[b]reverse,trim=start_frame=1:end_frame=$((n-1)),setpts=PTS-STARTPTS[r];[a][r]concat=n=2:v=1[out]" \
    -map "[out]" ${@:3} "$2"
}
# etape C (les -haut) : rotation de phase du PALINDROME (il boucle, son
# roll boucle aussi) — demi-tour, les jumelles ne battent jamais en phase.
roll() { # $1 in  $2 out
  local n=$(nbf "$1"); local k=$((n / 2))
  ffmpeg -y -v error -i "$1" -filter_complex \
    "[0:v]split[x][y];[x]trim=start_frame=$k,setpts=PTS-STARTPTS[a];[y]trim=start_frame=0:end_frame=$k,setpts=PTS-STARTPTS[b];[a][b]concat=n=2:v=1[out]" \
    -map "[out]" $X264 "$2"
}
pose() { # $1 nom
  mkdir -p "$ASSETS/$1-poster.imageset"
  ffmpeg -y -v error -i "$OUT/$1.mp4" -vf "select=eq(n\,0)" -vsync 0 -q:v 3 \
    "$ASSETS/$1-poster.imageset/$1-poster.jpg"
  cat > "$ASSETS/$1-poster.imageset/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "$1-poster.jpg", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
}

# ---------------------------------------------------------------- scrims
# Rampe smoothstep^1.1 (une rampe lineaire laisse une arete a son depart).
# Un scrim par sortie : les bords de fenetre qui coupent EN PLEIN ecran.
export TMP_SCRIM="$TMP"
python3 - <<'EOF'
import numpy as np, os
from PIL import Image
def scrim(name, W, H, top, bottom):
    y = np.linspace(0, H-1, H)[:, None]
    a = np.zeros((H, 1))
    if top:
        t = np.clip(1 - y/float(top), 0, 1); a = np.maximum(a, (t*t*(3-2*t))**1.1)
    if bottom:
        t = np.clip(1 - (H-1-y)/float(bottom), 0, 1); a = np.maximum(a, (t*t*(3-2*t))**1.1)
    img = np.zeros((H, W, 4), dtype=np.uint8)
    img[..., 3] = np.broadcast_to((np.clip(a,0,1)*255).astype(np.uint8), (H, W))
    Image.fromarray(img).save(os.path.join(os.environ["TMP_SCRIM"], f"scrim-{name}.png"))
for spec in [
    ("duo-galet-noir",          1206, 1560,   0, 130),
    ("duo-flamme-blanche",       804,  524,  90,   0),
    ("duo-flamme-blanche-haut",  804,  646,   0,  90),
    ("duo-galet-rouge",         1206,  600,  80,   0),
    ("duo-verre-rouge",         1206,  840,   0, 110),
    ("duo-flamme-rouge",         804,  600,  90,   0),
    ("duo-flamme-rouge-haut",    804,  608,   0,  90),
    ("duo-galet-rougebleu",     1080, 2100,  90,  90),
    ("duo-flamme-bleue",         804,  466,  90,   0),
]:
    scrim(*spec)
EOF

DL=~/Downloads

# --- ecran 1 haut : le galet noir (fenetre 402x520, ventre aux 4/5)
# MESURE 24-08 (numpy, frame 96) : capsule x 537-1635, ventre (rangee la
# plus claire) y 2878. La maquette ZOOME : la capsule remplit ~85 % de la
# largeur, le col sort par le haut, le ventre aux 4/5 de la fenetre.
cuirePill duo-galet-noir "$DL/Video noir_liquid.mp4" "1292:1672:440:1557" "1206x1560"

# --- ecran 1 bas / 2 haut : la flamme blanche (le fichier au nom menteur)
cuireA duo-flamme-blanche "$DL/Video rougeetbleu_liquid.mp4" "1080:704:0:1216" 0 "804x524"
pingpong "$TMP/duo-flamme-blanche-A.mp4" "$OUT/duo-flamme-blanche.mp4" $X264
cuireA duo-flamme-blanche-haut "$DL/Video rougeetbleu_liquid.mp4" "1080:868:0:1052" 1 "804x646"
pingpong "$TMP/duo-flamme-blanche-haut-A.mp4" "$TMP/duo-flamme-blanche-haut-P.mp4" $MASTER
roll "$TMP/duo-flamme-blanche-haut-P.mp4" "$OUT/duo-flamme-blanche-haut.mp4"

# --- ecran 2 bas : le dome du galet rouge (decale a gauche, cadrage CUIT)
# MESURE 24-08 : capsule x 528-1718 (centre 1123), sommet y 642. Le dome de
# la maquette fait ~65 % de la largeur, centre a 0,37.
cuirePill duo-galet-rouge "$DL/Video rouge_liquid.mp4" "1214:604:674:582" "1206x600"

# --- ecran 3 haut : le crop du fond exos (boucle, ralenti et scrim embarques)
# MESURE 24-08 (frame 420, mi-boucle : le verre ENTRE progressivement) : le
# verre vit a y 979-1900, pic de lumiere y 1711 — le crop demarre a 850.
ffmpeg -y -v error -i "$OUT/exos-fond-loop.mp4" -i "$TMP/scrim-duo-verre-rouge.png" \
  -filter_complex "[0:v]crop=1300:906:0:965,scale=1206:840[v];[v][1:v]overlay=0:0,format=yuv420p[out]" \
  -map "[out]" $X264 "$OUT/duo-verre-rouge.mp4"

# --- ecran 3 bas / 4 haut : la flamme rouge de la famille home
cuireA duo-flamme-rouge "$DL/video_flamme_rouge.mp4" "2160:1612:0:2224" 0 "804x600"
pingpong "$TMP/duo-flamme-rouge-A.mp4" "$OUT/duo-flamme-rouge.mp4" $X264
cuireA duo-flamme-rouge-haut "$DL/video_flamme_rouge.mp4" "2160:1632:0:2203" 1 "804x608"
pingpong "$TMP/duo-flamme-rouge-haut-A.mp4" "$TMP/duo-flamme-rouge-haut-P.mp4" $MASTER
roll "$TMP/duo-flamme-rouge-haut-P.mp4" "$OUT/duo-flamme-rouge-haut.mp4"

# --- la frontiere 4/5 : le galet rouge-et-bleu (l'autre nom menteur)
cuirePill duo-galet-rougebleu "$DL/Video_Flamme_bleu_.mp4" "1812:3524:270:0" "1080x2100"

# --- ecran 5 bas : la flamme bleue
cuireA duo-flamme-bleue "$DL/video_flamme_bleu.mp4" "1080:626:0:1294" 0 "804x466"
pingpong "$TMP/duo-flamme-bleue-A.mp4" "$OUT/duo-flamme-bleue.mp4" $X264

# ------------------------------------------------------------------ poses
for n in duo-galet-noir duo-flamme-blanche duo-flamme-blanche-haut \
         duo-galet-rouge duo-verre-rouge duo-flamme-rouge \
         duo-flamme-rouge-haut duo-galet-rougebleu duo-flamme-bleue; do
  pose $n
done

# ------------------------------------------------- portillons (mesures)
echo ""
echo "== PORTILLONS J0 =="
for n in duo-galet-noir duo-flamme-blanche duo-flamme-blanche-haut \
         duo-galet-rouge duo-verre-rouge duo-flamme-rouge \
         duo-flamme-rouge-haut duo-galet-rougebleu duo-flamme-bleue; do
  f="$OUT/$n.mp4"
  nf=$(nbf "$f")
  ffmpeg -y -v error -i "$f" -vf "select=eq(n\,0)" -vsync 0 "$TMP/$n-f0.png"
  ffmpeg -y -v error -i "$f" -vf "select=eq(n\,$((nf-1)))" -vsync 0 "$TMP/$n-fN.png"
done
TMP="$TMP" python3 - <<'EOF'
import numpy as np, os, glob
from PIL import Image
tmp = os.environ["TMP"]
out = "../../Woop/Media"
names = ["duo-galet-noir","duo-flamme-blanche","duo-flamme-blanche-haut",
         "duo-galet-rouge","duo-verre-rouge","duo-flamme-rouge",
         "duo-flamme-rouge-haut","duo-galet-rougebleu","duo-flamme-bleue"]
print(f"{'fichier':28s} {'couture':>8s} {'bordH p99':>10s} {'bordB p99':>10s} {'noir p50':>9s} {'Mo':>6s}")
total = 0.0
for n in names:
    f0 = np.asarray(Image.open(f"{tmp}/{n}-f0.png").convert("L")).astype(float)
    fN = np.asarray(Image.open(f"{tmp}/{n}-fN.png").convert("L")).astype(float)
    couture = np.abs(f0 - fN).mean()
    bh = np.percentile(f0[0:4, :], 99)
    bb = np.percentile(f0[-4:, :], 99)
    p50 = np.percentile(f0, 50)
    mo = os.path.getsize(f"{out}/{n}.mp4") / 1e6
    total += mo
    print(f"{n:28s} {couture:8.2f} {bh:10.1f} {bb:10.1f} {p50:9.1f} {mo:6.1f}")
print(f"{'TOTAL':28s} {'':8s} {'':10s} {'':10s} {'':9s} {total:6.1f}")
EOF
echo ""
echo "cuit -> Woop/Media/duo-*.mp4 (9) + Assets duo-*-poster (9)"
