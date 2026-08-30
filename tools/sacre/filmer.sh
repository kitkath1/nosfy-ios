#!/bin/zsh
# FILMER LA CARD BOOSTER — une cinématique se FILME, elle ne se juge pas sur
# une capture immobile.
#
#   ./tools/sacre/filmer.sh <secondes> [args...]
#   ./tools/sacre/filmer.sh 26 -boosterPopup       # l'entrée (après ~10 s de splash) + le doigt
#
# L'app doit DÉJÀ être installée sur kat-stop (le build l'a fait) : ce script
# ne build pas, il relance et enregistre. `--terminate-running-process` reste
# obligatoire (une app déjà vivante revient AVEC SES ANCIENS ARGUMENTS).
# Analyse : python3 tools/stop/analyse_film.py <film.mov> (les pts, jamais le
# compte d'images — le recordVideo du simulateur est VFR). `charge.sh` AVANT.
set -e

SIM=E9241D2D-EB46-43C8-A76A-DE5319DE48D6   # kat-stop
DUREE=${1:-24}
shift || true
OUT=tools/sacre/films
mkdir -p "$OUT"
MOV="$OUT/booster-$(date +%H%M%S).mov"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl launch --terminate-running-process "$SIM" fr.kathryn.woop \
  -skipAuth "$@" > /dev/null

xcrun simctl io "$SIM" recordVideo --codec h264 --force "$MOV" &
REC=$!
sleep "$DUREE"
kill -INT $REC 2>/dev/null || true
wait $REC 2>/dev/null || true
echo "$MOV"
