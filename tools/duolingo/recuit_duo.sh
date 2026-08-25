#!/bin/zsh
# LA CUISSON DE LA DUOLINGUO_PAGE (24-08, 2e salve) — produit les 8
# fichiers Woop/Media/duo-*.mp4 + leurs 8 poses, depuis les sources.
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
#  7. DEUX FRONTIERES pleine capsule (2/3 rouge a gauche, 4/5 rouge-bleu a
#     droite) — verdict 2e salve : la continuite prime tout, le crop exos
#     (duo-verre-rouge) est mort.
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

# LE GAIN (verdict 24-08 2e salve : « diminue leur force ») : les trois
# canaux ensemble — la SATURATION tient (min/max scalent pareil), la loi
# anti-brun est sauve. En RGB, jamais sur les plans YUV.
gainStep() { # $1 gain -> imprime le bout de graphe
  echo "format=gbrp,lutrgb=r=val*$1:g=val*$1:b=val*$1,"
}

# LE FEU UNIQUE (4e salve, LOI F2) : une couture de feu = UN fichier — le
# feu qui monte (moitie haute) et son double suspendu (moitie basse,
# vflip+hflip+decale dans le temps). La jonction : chaque moitie MEURT en
# fondu (120 px) dans la zone de recouvrement (rangees 480-600), puis les
# deux se SOMMENT en blend screen (gbrp AVANT le blend, la loi exos) — le
# coeur du feu est la somme de deux lumieres qui s'eteignent en douceur :
# aucune arete n'existe, par construction. Les deux bouts du fichier
# meurent a ZERO VRAI (l'invariant F1).
# ⚠️ JAMAIS `-loop 1` sur un masque/une image de filtre : l'entree devient
# INFINIE, le graphe n'a pas de fin — 115 Mo sans moov, tue au timeout
# (paye ici meme). Les images nues en overlay (repeatlast) suffisent.
cuireFeu() { # $1 nom  $2 source  $3 crop  $4 gain  $5 roll(frames)
  local n=$(nbf "$2")
  ffmpeg -y -v error -i "$2" -i "$TMP/scrim-moitieA.png" \
    -i "$TMP/scrim-moitieB.png" -i "$TMP/scrim-feu.png" \
    -filter_complex "\
[0:v]split=3[sa][sb1][sb2];\
[sa]crop=$3,scale=804:600,$(gainStep $4)format=gbrp[ac];\
[ac][1:v]overlay=0:0[af];\
[af]pad=804:1080:0:0:black,format=gbrp[A];\
[sb1]trim=start_frame=$5,setpts=PTS-STARTPTS[b1];\
[sb2]trim=end_frame=$5,setpts=PTS-STARTPTS[b2];\
[b1][b2]concat=n=2:v=1[bs];\
[bs]crop=$3,vflip,hflip,scale=804:600,$(gainStep $4)format=gbrp[bc];\
[bc][2:v]overlay=0:0[bf];\
[bf]pad=804:1080:0:480:black,format=gbrp[B];\
[A][B]blend=all_mode=screen[mm];\
[mm][3:v]overlay=0:0[sc];\
[sc]split[pa][pb];[pb]reverse,trim=start_frame=1:end_frame=$((n-1)),setpts=PTS-STARTPTS[r];\
[pa][r]concat=n=2:v=1,format=yuv420p[out]" \
    -map "[out]" $X264 "$OUT/$1.mp4"
}

nbf() { ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 "$1" }

# ------------------------------------------------------------- fonctions
# etape A : crop (+flip) + scale (+gain) + scrim -> master crf 16
cuireA() { # $1 nom  $2 source  $3 crop  $4 flip(0/1)  $5 WxH  [$6 gain]
  local flt="crop=$3"
  [[ "$4" == "1" ]] && flt="$flt,vflip,hflip"
  flt="$flt,scale=${5/x/:}"
  if [[ -n "$6" ]]; then
    flt="$flt,$(gainStep $6)format=yuv420p"
  fi
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
# 4e salve 24-08 (LOI F1, l'invariant du zero) : les capsules emergent du
# noir sur 200 px ; les feux uniques portent leurs queues a zero dans
# scrim-feu ; les 4 fichiers de flammes separees sont MORTS (LOI F2).
for spec in [
    ("duo-galet-noir",          1206, 1560,   0, 220),
    ("duo-galet-rouge",         1080, 2100, 200, 200),
    ("duo-galet-rougebleu",     1080, 2100, 200, 200),
    ("duo-flamme-bleue",         804,  440, 198,   0),
]:
    scrim(*spec)
# §17/§18 (LA VÉRITÉ DU BUNDLE, restaurée au fouettage §18) : les braises
# sont des LARMES — fondu aux DEUX bouts (plus de miroir, plus
# d'overshoot : le socle horizontal de la source posait un TRAIT), et la
# VIGNETTE 2D ELLIPTIQUE « de peintre » : aucune structure droite ne
# survit. Basses 804x430 (215 pt), suspendues 804x260 (130 pt, cuites
# pre-flip puis vflip du canevas entier + roll demi-boucle).
scrim("basse", 804, 430, 200, 130)
scrim("haute", 804, 260, 90, 130)
def vig2d(name, W, H, cx, cy, sx, sy):
    xx, yy = np.meshgrid(np.arange(W), np.arange(H))
    g = np.exp(-(((xx-cx)/sx)**2 + ((yy-cy)/sy)**2))
    v = (g*255).astype(np.uint8)
    Image.fromarray(np.stack([v,v,v], axis=-1)).save(
        os.path.join(os.environ["TMP_SCRIM"], f"{name}.png"))
vig2d("vig-basse", 804, 430, 402, 300, 250, 200)
vig2d("vig-haute", 804, 260, 402, 185, 230, 130)
EOF

DL=~/Downloads

# --- ecran 1 haut : le galet noir (fenetre 402x520, ventre aux 4/5)
# MESURE 24-08 (numpy, frame 96) : capsule x 537-1635, ventre (rangee la
# plus claire) y 2878. La maquette ZOOME : la capsule remplit ~85 % de la
# largeur, le col sort par le haut, le ventre aux 4/5 de la fenetre.
cuirePill duo-galet-noir "$DL/Video noir_liquid.mp4" "1292:1672:440:1557" "1206x1560"

# --- §15 LE CHEMIN D'ABORD : les feux uniques 540 pt sont MORTS (le
# decor est un parfum). Chaque couture de feu garde une BRAISE DE POSE :
# 160 pt visibles + 80 pt d'overshoot en BASE MIROIR fondue (la matiere
# continue sous le bord physique — jamais un pad noir : la jonction
# contenu/noir posait une ligne dure, payee au frame). Le POINT NOIR de
# la source s'ECRASE (lutrgb clip) : le voile gris laiteux du fond meurt,
# le coeur remonte a pleine echelle — baisser le gain fabriquait du gris
# (le piege « baisser pour fondre »). Et la VIGNETTE gaussienne laterale
# (multiply) garantit du noir aux flancs par construction.
# LA BRAISE BASSE (804x430) : crush du point noir (le voile gris de la
# source meurt — jamais par le gain), vignette 2D multiply, fondu cuit
# aux deux bouts (scrim), palindrome, crf 17 une passe.
cuireBraiseBasse() { # $1 nom  $2 source  $3 crop  $4 point_noir  $5 nbf
  ffmpeg -y -v error -i "$2" -i "$TMP/vig-basse.png" -i "$TMP/scrim-basse.png" \
    -filter_complex "\
[0:v]crop=$3,scale=804:430,format=gbrp,\
lutrgb=r='clip((val-$4)*255/$((255-$4)),0,255)':g='clip((val-$4)*255/$((255-$4)),0,255)':b='clip((val-$4)*255/$((255-$4)),0,255)',format=gbrp[c];\
[1:v]format=gbrp[vg];[c][vg]blend=all_mode=multiply[vv];\
[vv][2:v]overlay=0:0[s];\
[s]split[a][b];[b]reverse,trim=start_frame=1:end_frame=$(($5-1)),setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1,format=yuv420p[out]" \
    -map "[out]" $X264P "$OUT/$1.mp4"
}
# LA BRAISE SUSPENDUE (804x260) : cuite comme une basse PETITE, puis
# vflip du canevas ENTIER (les plumes pendent) + ROLL demi-boucle du
# palindrome (jamais en phase avec la basse de sa couture).
cuireBraiseHaute() { # $1 nom  $2 source  $3 crop  $4 point_noir  $5 nbf
  local k=$(($5))
  ffmpeg -y -v error -i "$2" -i "$TMP/vig-haute.png" -i "$TMP/scrim-haute.png" \
    -filter_complex "\
[0:v]crop=$3,scale=804:260,format=gbrp,\
lutrgb=r='clip((val-$4)*255/$((255-$4)),0,255)':g='clip((val-$4)*255/$((255-$4)),0,255)':b='clip((val-$4)*255/$((255-$4)),0,255)',format=gbrp[c];\
[1:v]format=gbrp[vg];[c][vg]blend=all_mode=multiply[vv];\
[vv][2:v]overlay=0:0,vflip[s];\
[s]split[a][b];[b]reverse,trim=start_frame=1:end_frame=$(($5-1)),setpts=PTS-STARTPTS[r];\
[a][r]concat=n=2:v=1[pp];\
[pp]split[x][y];[x]trim=start_frame=$k,setpts=PTS-STARTPTS[ra];[y]trim=start_frame=0:end_frame=$k,setpts=PTS-STARTPTS[rb];\
[ra][rb]concat=n=2:v=1,format=yuv420p[out]" \
    -map "[out]" $X264P "$OUT/$1.mp4"
}
NBLANC=$(nbf "$DL/Video rougeetbleu_liquid.mp4")
NROUGE=$(nbf "$DL/video_flamme_rouge.mp4")
# crops rim-safe (44 rangees au-dessus du lisere du cadre arrondi source)
cuireBraiseBasse duo-flamme-blanche "$DL/Video rougeetbleu_liquid.mp4" "1080:578:0:1298" 70 $NBLANC
cuireBraiseBasse duo-flamme-rouge   "$DL/video_flamme_rouge.mp4"       "2160:1155:0:2637" 24 $NROUGE
cuireBraiseHaute duo-flamme-blanche-haut "$DL/Video rougeetbleu_liquid.mp4" "1080:349:0:1527" 70 $NBLANC
cuireBraiseHaute duo-flamme-rouge-haut   "$DL/video_flamme_rouge.mp4"       "2160:699:0:3093" 24 $NROUGE
# (mort au §15 : cuireFeu duo-feu-blanc "1080:806:0:1114" 0.62 85)

# --- LA FRONTIERE 2/3 : la capsule rouge ENTIERE (verdict 2e salve :
# « ca doit etre le meme element »). Ecole rougebleu : plein pied, fenetre
# 360x700 ancree a GAUCHE. MESURE : capsule x 528-1718 (centre 1123),
# y 642-3081 ; le centre de la capsule a 0,417 de la fenetre (dome au
# bas-gauche de l'ecran 2, la maquette), sommet a 12 % du crop.
# duo-verre-rouge (le crop exos) est MORT : la continuite prime la parite.
cuirePill duo-galet-rouge "$DL/Video rouge_liquid.mp4" "1778:3458:382:227" "1080x2100"

# (mort au §15 : cuireFeu duo-feu-rouge "2160:1612:0:2224" 0.80 72)

# --- la frontiere 4/5 : le galet rouge-et-bleu (l'autre nom menteur)
cuirePill duo-galet-rougebleu "$DL/Video_Flamme_bleu_.mp4" "1812:3524:270:0" "1080x2100"

# --- ecran 5 bas : la flamme bleue (alignee sur la salve : 220 pt, x0,85)
cuireA duo-flamme-bleue "$DL/video_flamme_bleu.mp4" "1080:592:0:1328" 0 "804x440" 0.85
pingpong "$TMP/duo-flamme-bleue-A.mp4" "$OUT/duo-flamme-bleue.mp4" $X264

# ------------------------------------------------------------------ poses
for n in duo-galet-noir duo-flamme-blanche duo-flamme-blanche-haut duo-galet-rouge \
         duo-flamme-rouge duo-flamme-rouge-haut duo-galet-rougebleu duo-flamme-bleue; do
  pose $n
done

# ------------------------------------------------- portillons (mesures)
echo ""
echo "== PORTILLONS J0 =="
for n in duo-galet-noir duo-flamme-blanche duo-flamme-blanche-haut duo-galet-rouge \
         duo-flamme-rouge duo-flamme-rouge-haut duo-galet-rougebleu duo-flamme-bleue; do
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
names = ["duo-galet-noir","duo-flamme-blanche","duo-flamme-blanche-haut","duo-galet-rouge",
         "duo-flamme-rouge","duo-flamme-rouge-haut","duo-galet-rougebleu","duo-flamme-bleue"]
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
echo "cuit -> Woop/Media/duo-*.mp4 (6) + Assets duo-*-poster (6)"
