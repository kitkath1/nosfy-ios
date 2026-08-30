#!/bin/zsh
# LE TOUR DE BOUCLE DU BANC PROGRESS (plan tools/progress/PLAN-PROGRESS-V2.md).
#
#   ./tools/progress/voir.sh                      # la page seule (-progressLab)
#   ./tools/progress/voir.sh -progressPillBas     # l'option B du fond
#   ./tools/progress/voir.sh -progressFaits 2 -progressPrevus 4
#   ./tools/progress/voir.sh -progressMois -1 -progressFige 1
#
# Build NU — JAMAIS de pipe (`xcodebuild | grep` rend le code de GREP : on
# installe alors une app PÉRIMÉE, payé 3×). DerivedData À SOI (dd-progress),
# SIMULATEUR À SOI (kat-progress : un install + launch --terminate sur le sim
# d'une autre session lui tue son app sous les doigts).
set -e
cd "$(dirname "$0")/../.."
SIM=4DA91F1B-CF13-47DC-A2A6-9BE3BD9AC2B7   # kat-progress, iPhone 17 Pro
DD=dd-progress
OUT=tools/progress/shots
LOG=/tmp/progress-build.log
mkdir -p "$OUT"

if pgrep -fl xcodebuild > /dev/null; then
  echo "⚠️ un xcodebuild tourne déjà :"; pgrep -fl xcodebuild
fi

# ⚠️ `E=$?` DANS un `if ! cmd` rend le code de la NÉGATION. La seule forme
# juste : `cmd || E=$?` (et le `||` protège aussi du `set -e`).
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

# LANCER DEUX FOIS avant toute capture : le premier lancement paie les caches.
# `--terminate-running-process` est OBLIGATOIRE (sinon les anciens arguments).
# La splash dure ~10 s : PAUSE 15 par défaut.
PAUSE=${PAUSE:-15}
for i in 1 2; do
  xcrun simctl launch --terminate-running-process "$SIM" fr.kathryn.woop \
    -skipAuth -progressLab "$@" > /dev/null
  sleep "$PAUSE"
done

PNG="$OUT/progress-$(date +%H%M%S).png"
xcrun simctl io "$SIM" screenshot "$PNG"
echo "$PNG"
