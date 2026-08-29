#!/bin/zsh
# LE TOUR DE BOUCLE DU BANC DE LA CARD STOP.
#
#   ./tools/stop/voir.sh [args du banc...]
#   ./tools/stop/voir.sh -stopFige -stopNu
#   ./tools/stop/voir.sh -stopAuto
#
# Build NU — JAMAIS de pipe : `xcodebuild | grep` rend le code de GREP, et on
# installe alors une app PÉRIMÉE en croyant juger son propre code (payé 3×).
# Ici le `if !` porte le code de xcodebuild lui-même, et il est `set -e`-sûr
# (avec `set -e`, un `E=$?` derrière la commande n'est JAMAIS atteint).
#
# DerivedData À SOI (`dd-stop`) : deux builds sur le même DerivedData
# verrouillent la base et se sabotent — deux autres sessions vivent ici.
set -e

SIM=E9241D2D-EB46-43C8-A76A-DE5319DE48D6   # kat-stop, iPhone 17 Pro
DD=dd-stop
OUT=tools/stop/captures
LOG=/tmp/stop-build.log
mkdir -p "$OUT"

# ⚠️ `E=$?` DANS un `if ! cmd` rend le code de la NÉGATION (0 quand la
# commande a échoué) — on croit lire xcodebuild et on lit l'inverse. La seule
# forme juste : `cmd || E=$?` (et le `||` protège aussi du `set -e`).
E=0
xcodebuild -project Woop.xcodeproj -scheme Woop -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DD" build > "$LOG" 2>&1 || E=$?
if [ $E -ne 0 ]; then
  echo "BUILD KO (exit $E)"
  grep -E "error:|BUILD INTERRUPTED" "$LOG" | head -20
  exit $E
fi

APP="$DD/Build/Products/Debug-iphonesimulator/Woop.app"
# C'est la DATE DU DYLIB qu'on lit : elle prouve que le binaire posé est le
# nôtre, pas celui d'avant.
echo "dylib : $(stat -f '%Sm %z' "$APP/Woop.debug.dylib" 2>/dev/null || echo ABSENT)"
# La preuve que la bête est bien DANS le paquet (le groupe Xcode est
# synchronisé, mais un fichier qui manque ne dit rien à personne).
echo "bête  : $(stat -f '%z octets' "$APP/stop-bat-loop.mp4" 2>/dev/null || echo ABSENTE)"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"

# LANCER DEUX FOIS avant toute capture : le premier lancement paie les
# caches (shaders, fontes, première image du décodeur) et ment sur le rendu.
# `--terminate-running-process` est OBLIGATOIRE : sans lui une app déjà
# vivante revient au premier plan AVEC SES ANCIENS ARGUMENTS.
for i in 1 2; do
  xcrun simctl launch --terminate-running-process "$SIM" fr.kathryn.woop \
    -stopLab "$@" > /dev/null
  sleep 4
done

PNG="$OUT/stop-$(date +%H%M%S).png"
xcrun simctl io "$SIM" screenshot "$PNG"
echo "$PNG"
