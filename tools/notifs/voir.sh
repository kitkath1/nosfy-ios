#!/bin/zsh
# LE TOUR DE BOUCLE DU BANC DES NOTIFICATIONS.
#
#   ./tools/notifs/voir.sh [args du banc...]
#
# Build NU (jamais de pipe : `xcodebuild | grep` rend le code de GREP, et on
# installe alors une app PÉRIMÉE en croyant juger son propre code — payé 3×),
# `stat` du dylib avant capture, install, launch avec
# --terminate-running-process (sans lui, une app déjà vivante revient au
# premier plan AVEC SES ANCIENS ARGUMENTS), puis screenshot horodaté.
set -e

SIM=793977E8-595E-46F7-8E14-F2DF9EB79206   # kat-notif, iPhone 16 Pro
DD=dd-notif
OUT=tools/notifs/captures
mkdir -p "$OUT"

xcodebuild -project Nosfy.xcodeproj -scheme Nosfy -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DD" build > /tmp/notif-build.log 2>&1
E=$?
if [ $E -ne 0 ]; then
  echo "BUILD KO (exit $E)"
  grep "error:" /tmp/notif-build.log | head -10
  exit $E
fi

APP="$DD/Build/Products/Debug-iphonesimulator/Nosfy.app"
echo "dylib : $(stat -f '%Sm %z' "$APP/Woop.debug.dylib" 2>/dev/null || echo absent)"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch --terminate-running-process "$SIM" fr.kathryn.woop \
  -notifLab "$@" > /dev/null

sleep 3
PNG="$OUT/notif-$(date +%H%M%S).png"
xcrun simctl io "$SIM" screenshot "$PNG"
echo "$PNG"
