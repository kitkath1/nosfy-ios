#!/bin/zsh
# LE TOUR DE BOUCLE DU BANC DE LA ROUTE (et de la card ROUTE de la home).
#
#   ./tools/road/voir.sh -homeChemin -duoEtape 5
#   ./tools/road/voir.sh -routeCard milieu
#
# Build NU — JAMAIS de pipe : `xcodebuild | grep` rend le code de GREP, et on
# installe alors une app PÉRIMÉE en croyant juger son propre code (payé 3×).
#
# DerivedData À SOI (`dd-route`) : deux builds sur le même DerivedData
# verrouillent la base et se sabotent — d'autres sessions vivent ici.
set -e

# ⚠️ SON PROPRE SIMULATEUR (29-08) : `kat-road` est occupé par une autre
# session, et un `install` + `launch --terminate-running-process` lui tuerait
# son app sous les doigts. Un chantier = un simulateur, comme un chantier = un
# DerivedData.
SIM=CAA8ED6A-0322-4902-A19E-FAEFE5AD94AA   # kat-cardroute, iPhone 17 Pro
DD=dd-route
OUT=tools/road/shots
LOG=/tmp/route-build.log
mkdir -p "$OUT"

# ⚠️ `E=$?` DANS un `if ! cmd` rend le code de la NÉGATION. La seule forme
# juste : `cmd || E=$?` (et le `||` protège aussi du `set -e`).
E=0
xcodebuild -project Nosfy.xcodeproj -scheme Nosfy -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DD" build > "$LOG" 2>&1 || E=$?
if [ $E -ne 0 ]; then
  echo "BUILD KO (exit $E)"
  grep -E "error:|BUILD INTERRUPTED" "$LOG" | head -20
  exit $E
fi

APP="$DD/Build/Products/Debug-iphonesimulator/Nosfy.app"
# C'est la DATE DU DYLIB qu'on lit : elle prouve que le binaire posé est le
# nôtre, pas celui d'avant.
echo "dylib : $(stat -f '%Sm %z' "$APP/Woop.debug.dylib" 2>/dev/null || echo ABSENT)"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"

# LANCER DEUX FOIS avant toute capture : le premier lancement paie les caches
# (shaders, fontes, première image du décodeur) et ment sur le rendu.
# `--terminate-running-process` est OBLIGATOIRE : sans lui une app déjà vivante
# revient au premier plan AVEC SES ANCIENS ARGUMENTS.
#
# ⚠️ **LA SPLASH DURE ~10 s** — à 5 s de pause, la capture rendait la LUNE, pas
# la page. `PAUSE` est réglable pour les bancs qui montent plus lentement.
PAUSE=${PAUSE:-15}
for i in 1 2; do
  xcrun simctl launch --terminate-running-process "$SIM" fr.kathryn.woop \
    -skipAuth "$@" > /dev/null
  sleep "$PAUSE"
done

PNG="$OUT/route-$(date +%H%M%S).png"
xcrun simctl io "$SIM" screenshot "$PNG"
echo "$PNG"
