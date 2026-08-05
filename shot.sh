#!/bin/zsh
# Capture d'une scène du banc des icônes, sur le simulateur DÉDIÉ Woop-Icons.
#   ./shot.sh <scene> <sortie.png> [delai_s]
# scene : chocolat | bras | peche | trio | petit
set -e
DEV=85D02A02-7E4F-4E40-8169-91FE2E3BD1B9
APP=/Users/kathryn/Downloads/woop-icons/dd-icons/Build/Products/Debug-iphonesimulator/Woop.app
SCENE=${1:-trio}
OUT=${2:-/Users/kathryn/Downloads/woop-icons/shots/$SCENE.png}
DELAI=${3:-3.0}

xcrun simctl bootstatus "$DEV" -b >/dev/null 2>&1 || xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl terminate "$DEV" fr.kathryn.woop 2>/dev/null || true
xcrun simctl install "$DEV" "$APP"
xcrun simctl launch "$DEV" fr.kathryn.woop \
  -iconLab -icon "$SCENE" -iconFreeze -skipAuth >/dev/null
python3 -c "import time,sys; time.sleep(float(sys.argv[1]))" "$DELAI"
xcrun simctl io "$DEV" screenshot --type=png "$OUT" 2>/dev/null
echo "capture -> $OUT"
