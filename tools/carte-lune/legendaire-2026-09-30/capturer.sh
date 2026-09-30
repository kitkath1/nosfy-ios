#!/bin/bash
# LA PREUVE (30-09) : une légendaire en main, au simulateur.
# Trois cartes au MÊME angle, pour la planche :
#   neuve       la légendaire avec sa matière (carteLuneV6)
#   produit     la même telle que l'app la montre aujourd'hui (-sansMatiere, V5)
#   trois       l'épique de son monde (V5, intacte)
# puis un film de 12 s de la neuve, inclinaison libre (le balancement du banc).
#   capturer.sh <udid> <légendaire> <épique témoin> [drapeaux en plus…]
#   ex. capturer.sh <udid> le-souverain le-passage
# Les captures brutes vont HORS du dépôt ($CAPTURES, défaut /tmp) ;
# planche.py en tire la planche, qui seule reste comme preuve.
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
SIM="${1:?udid}"; LEG="${2:?légendaire}"; TEM="${3:?épique témoin}"; shift 3
EN_PLUS=("$@")
CAP="${CAPTURES:-/tmp/nosfy-legendaire}/$LEG"; mkdir -p "$CAP"
attendre() { python3 -c "import time; time.sleep($1)"; }

lancer() {  # lancer <nom> <tilt ou -> [drapeaux…]
  local nom="$1" tilt="$2"; shift 2
  local args=(-luneLab -luneCarte "$nom")
  [ "$tilt" != "-" ] && args+=(-luneTilt "$tilt")
  xcrun simctl launch --terminate-running-process "$SIM" fr.kathryn.woop \
    "${args[@]}" "$@" ${EN_PLUS[@]+"${EN_PLUS[@]}"} > /dev/null
}

for t in "-0.5,0" "0,0" "0.5,0.2"; do
  lancer "$LEG" "$t";               attendre 5
  xcrun simctl io "$SIM" screenshot "$CAP/neuve_$t.png" > /dev/null 2>&1
  lancer "$LEG" "$t" -sansMatiere;  attendre 5
  xcrun simctl io "$SIM" screenshot "$CAP/produit_$t.png" > /dev/null 2>&1
  lancer "$TEM" "$t";               attendre 5
  xcrun simctl io "$SIM" screenshot "$CAP/trois_$t.png" > /dev/null 2>&1
  echo "capturé : $LEG $t"
done

# Le film : la vie (braises, neige, souffle, paillettes) et la lampe du monde
# qui suit l'inclinaison. simctl enregistre en cadence VARIABLE (piège
# payé le 24-09) : le film se ré-encode à 30 i/s constants.
lancer "$LEG" -; attendre 4
xcrun simctl io "$SIM" recordVideo --codec h264 --force "$CAP/film-brut.mp4" > /dev/null 2>&1 &
REC=$!
attendre 12
kill -INT "$REC"; wait "$REC" 2>/dev/null || true
ffmpeg -y -loglevel error -i "$CAP/film-brut.mp4" -vf "fps=30,scale=590:-2" \
  -c:v libx264 -pix_fmt yuv420p -crf 20 "$ICI/$LEG-en-main.mp4"
rm -f "$CAP/film-brut.mp4"
echo "film : $ICI/$LEG-en-main.mp4"
python3 "$ICI/planche.py" "$LEG" "$TEM" "$CAP"
