#!/bin/bash
# Monte le banc des verrous dans une COPIE jetable (le dépôt n'est jamais touché).
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
DEPOT=/Users/kathryn/Desktop/Nosfy
NAV="$DEPOT/tools/nav/fouettage"
COPIE="$ICI/copie"
mkdir -p "$COPIE"
rsync -a --delete --exclude .git --exclude 'dd-*' --exclude build \
  --exclude docs --exclude tools --exclude NosfyUITests \
  --exclude 'Nosfy.xcodeproj/xcuserdata' \
  "$DEPOT/Nosfy" "$DEPOT/NosfyShared" "$DEPOT/NosfyWidgets" \
  "$DEPOT/Nosfy.xcodeproj" "$COPIE/" || exit 1
python3 "$NAV/applique_patch.py" "$COPIE/Nosfy.xcodeproj/project.pbxproj" || exit 1
mkdir -p "$COPIE/Nosfy.xcodeproj/xcshareddata/xcschemes"
cp "$NAV/NosfyUITests.xcscheme" "$COPIE/Nosfy.xcodeproj/xcshareddata/xcschemes/"
cp "$ICI/hooks/SondeVerrous.swift" "$COPIE/Nosfy/Views/"
python3 "$ICI/applique_hooks.py" "$COPIE" || exit 1
python3 "$ICI/patchs_copie.py" "$COPIE" || exit 1
mkdir -p "$COPIE/NosfyUITests"
cp "$ICI/tests/VerrousUITests.swift" "$COPIE/NosfyUITests/"
plutil -lint "$COPIE/Nosfy.xcodeproj/project.pbxproj" || exit 1
xcodebuild -project "$COPIE/Nosfy.xcodeproj" -list 2>/dev/null | grep -q NosfyUITests || {
  echo "cible NosfyUITests absente"; exit 1; }
echo "BANC MONTÉ dans $COPIE"
