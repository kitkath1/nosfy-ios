#!/bin/bash
# LE FOUETTAGE ULTIME DU PLAYER (§3.4bis du plan) — une page du
# protocole : lancement validé (signature status bar, avec retries —
# le sim avale des args par intermittence), film de 56 s du doigt
# fantôme (-playerDoigt), puis les juges.
#
# Usage :
#   tools/player/fouettage/fouette_page.sh <label> [args de lancement]
# Les 4 pages du protocole (toutes avec -activeWorkout
# -activeWorkoutLong pour une partition qui DÉBORDE) :
#   … home
#   … exos      -openTab exercises        (juge zones — page sombre)
#   … progress  -openTab progress
#   … fiche     -openTab exercises -openExercise woop-haute
#
# ⚠️ LES LOIS DE LA MESURE (payées, ne pas ré-apprendre) :
#   · ./tools/charge.sh AVANT : la charge machine invalide les films
#     (un build parallèle = des vols « affamés » de 2 frames, faux) ;
#   · les juges pixels ont des artefacts CONNUS : le player
#     MICRO-OUVERT masque la pilule et fusionne son trait à la boîte
#     de dalle (ymax +30-70 = artefact) ; le juge zones exos clignote
#     par transitions d'1 frame (physiquement impossibles) — TOUT
#     échec restant se TRANCHE à la mesure du BORD du corps :
#     vitesse légitime <= 230 px/frame (borne du tween 0,08 x 2556) ;
#   · la boîte de dalle au VRAI repos vaut (68, 1100, 0, 76) sur les
#     QUATRE pages — c'est l'égalité géométrique du protocole.
set -u
SCRATCH="${FOUET_DIR:-/tmp/fouettage-player}"
mkdir -p "$SCRATCH"
ICI="$(cd "$(dirname "$0")" && pwd)"
SIM="${FOUET_SIM:-kat-pagecard}"
APP=fr.kathryn.woop
LABEL=$1; shift

xcrun simctl terminate "$SIM" "$APP" 2>/dev/null
sleep 1
xcrun simctl launch --console-pty --terminate-running-process \
  "$SIM" "$APP" -skipAuth -demoData -playerDoigt -hitSonde "$@" \
  > "$SCRATCH/con-$LABEL.log" 2>&1 &
CONPID=$!
sleep 13

# LA SIGNATURE DE VALIDITÉ : status bar max >= 100 sur AU MOINS une de
# 5 prises espacées (le doigt fantôme peut couvrir l'écran au mauvais
# moment — on attend une phase page).
VAL=1
for k in 1 2 3 4 5; do
  xcrun simctl io "$SIM" screenshot "$SCRATCH/val-$LABEL-$k.png" >/dev/null 2>&1
  python3 - "$SCRATCH/val-$LABEL-$k.png" <<'PY' && { VAL=0; break; }
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("L")
W, H = im.size
mx = im.crop((0, 0, W, 120)).getextrema()[1]
print(f"  status-bar max {mx}")
sys.exit(0 if mx >= 100 else 1)
PY
  sleep 2
done
if [ $VAL -ne 0 ]; then
  echo "LANCEMENT INVALIDE ($LABEL) — signature status bar jamais vue"
  kill $CONPID 2>/dev/null
  exit 1
fi
echo "lancement valide ($LABEL)"

xcrun simctl io "$SIM" recordVideo --codec h264 "$SCRATCH/film-$LABEL.mp4" &
RECPID=$!
sleep 56
kill -INT $RECPID
wait $RECPID 2>/dev/null
sleep 2
kill $CONPID 2>/dev/null

case "$LABEL" in
  *exos*)
    # Page sombre : le juge à DEUX ZONES fait vol+saut+page d'un coup.
    echo "=== JUGE ZONES ($LABEL) ==="
    python3 "$ICI/juge_zones.py" "$SCRATCH/film-$LABEL.mp4" "$SCRATCH/fr-$LABEL"
    V1=$?; V2=$V1; V3=$V1
    ;;
  *)
    echo "=== JUGE VOL ($LABEL) ==="
    python3 "$ICI/juge_vol.py" "$SCRATCH/film-$LABEL.mp4" "$SCRATCH/fr-$LABEL"
    V1=$?
    echo "=== JUGE SAUT ($LABEL) ==="
    python3 "$ICI/juge_saut.py" "$SCRATCH/fr-$LABEL"
    V2=$?
    echo "=== JUGE PAGE ($LABEL) ==="
    python3 "$ICI/juge_page.py" "$SCRATCH/fr-$LABEL"
    V3=$?
    ;;
esac
echo "=== SONDE-HIT ($LABEL) ==="
grep 'SONDE-HIT' "$SCRATCH/con-$LABEL.log" | tail -12
NH=$(grep -c 'SONDE-HIT' "$SCRATCH/con-$LABEL.log")
echo "lignes SONDE-HIT : $NH"
echo "=== BILAN $LABEL : vol=$V1 saut=$V2 page=$V3 hits=$NH ==="
[ $V1 -eq 0 ] && [ $V2 -eq 0 ] && [ $V3 -eq 0 ]
