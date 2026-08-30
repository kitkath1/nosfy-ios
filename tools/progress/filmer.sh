#!/bin/zsh
# FILMER LE BANC PROGRESS — une arrivée se FILME, elle ne se juge pas sur
# une capture immobile (l'école tools/stop/filmer.sh).
#
#   ./tools/progress/filmer.sh <secondes> [args du banc...]
#   ./tools/progress/filmer.sh 10                    # l'arrivée
#   ./tools/progress/filmer.sh 12 -progressStory 21  # l'arrivée puis la story
#
# L'app doit DÉJÀ être installée (voir.sh l'a fait) : ce script relance et
# enregistre. Le recordVideo du simulateur est VFR sous charge : toute mesure
# de temps se lit sur les pts, jamais sur un compte d'images.
set -e
cd "$(dirname "$0")/../.."
SIM=4DA91F1B-CF13-47DC-A2A6-9BE3BD9AC2B7   # kat-progress
DUREE=${1:-10}
shift || true
OUT=tools/progress/films
mkdir -p "$OUT"
MOV="$OUT/progress-$(date +%H%M%S).mov"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl launch --terminate-running-process "$SIM" fr.kathryn.woop \
  -skipAuth -progressLab "$@" > /dev/null

xcrun simctl io "$SIM" recordVideo --codec h264 --force "$MOV" &
REC=$!
sleep "$DUREE"
kill -INT $REC 2>/dev/null || true
wait $REC 2>/dev/null || true
echo "$MOV"
