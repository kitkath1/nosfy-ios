#!/bin/zsh
# LE TOUR DE BOUCLE DU BANC DU PLAYER TAPIS.
#
#   ./tools/tapis/voir.sh [args du banc...]
#   ./tools/tapis/voir.sh -tapisFige -tapisNu
#   ./tools/tapis/voir.sh -tapisAuto
#
# Build NU — JAMAIS de pipe : `xcodebuild | grep` rend le code de GREP, et on
# installe alors une app PÉRIMÉE en croyant juger son propre code (payé 3×).
#
# DerivedData À SOI (`dd-tapis`) : deux builds sur le même DerivedData
# verrouillent la base et se sabotent — d'autres sessions vivent ici.
set -e

SIM=${TAPIS_SIM:?poser TAPIS_SIM (UDID de kat-tapis)}
DD=dd-tapis
OUT=tools/tapis/captures
LOG=/tmp/tapis-build.log
mkdir -p "$OUT"

# ⚠️ `E=$?` DANS un `if ! cmd` rend le code de la NÉGATION. La seule forme
# juste : `cmd || E=$?` (le `||` protège aussi du `set -e`).
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

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"

# LANCER DEUX FOIS avant toute capture : le premier lancement paie les caches
# (shaders, fontes) et ment sur le rendu. `--terminate-running-process` est
# OBLIGATOIRE : une app vivante revient avec SES ANCIENS ARGUMENTS.
for i in 1 2; do
  xcrun simctl launch --terminate-running-process "$SIM" fr.kathryn.woop \
    -tapisLab "$@" > /dev/null
  sleep 4
done

PNG="$OUT/tapis-$(date +%H%M%S).png"
xcrun simctl io "$SIM" screenshot "$PNG"
echo "$PNG"
