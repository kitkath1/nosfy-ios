#!/bin/zsh
# FILMER LE BANC DE LA CARD STOP — une cinématique se FILME, elle ne se
# juge pas sur une capture immobile.
#
#   ./tools/stop/filmer.sh <secondes> [args du banc...]
#   ./tools/stop/filmer.sh 14 -stopAuto        # l'entrée et le Cancel
#   ./tools/stop/filmer.sh 10 -stopSliderAuto  # le commit du slider
#
# L'app doit DÉJÀ être installée (`voir.sh` l'a fait) : ce script ne build pas,
# il relance et enregistre. `--terminate-running-process` reste obligatoire.
#
# ⚠️ Le `recordVideo` du simulateur est VFR sous charge : le nombre d'images
# ne dit RIEN de la durée. Toute mesure de temps se lit sur les `pts`, jamais
# sur un compte d'images — c'est `analyse_film.py` qui s'en charge.
set -e

SIM=E9241D2D-EB46-43C8-A76A-DE5319DE48D6   # kat-stop
DUREE=${1:-12}
shift || true
OUT=tools/stop/films
mkdir -p "$OUT"
MOV="$OUT/stop-$(date +%H%M%S).mov"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl launch --terminate-running-process "$SIM" fr.kathryn.woop \
  -stopLab -stopNu "$@" > /dev/null

xcrun simctl io "$SIM" recordVideo --codec h264 --force "$MOV" &
REC=$!
sleep "$DUREE"
kill -INT $REC 2>/dev/null || true
wait $REC 2>/dev/null || true
echo "$MOV"
