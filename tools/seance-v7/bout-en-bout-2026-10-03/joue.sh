#!/bin/bash
# LA SÉANCE DE BOUT EN BOUT, À VRAIS TOUCHERS — monte une COPIE jetable avec
# la cible NosfyUITests (le pbxproj du dépôt n'est jamais touché), puis joue
# les cas un par un, chacun filmé, sur un compte propre.
#
# Usage : joue.sh <copie> <preuves> <sim> [test01 test02 test03]
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
DEPOT="$(cd "$(cd "$ICI" && pwd -P)/../../.." && pwd)"   # le vrai dossier : woochoper-ios n'est fait que de liens
FOUET="$DEPOT/tools/nav/fouettage"
COPIE="$1"; PREUVES="$2"; SIM="$3"; shift 3
if [ $# -eq 0 ]; then CAS=(test01_videAjoutTroisSeriesTerminer test02_refaire test03_hiit)
else CAS=("$@"); fi
APP=fr.kathryn.woop
DD="$COPIE/dd-beb"
mkdir -p "$COPIE" "$PREUVES"

# 1) la copie : le code du jour + la cible de test
rsync -a --delete --exclude .git --exclude 'dd-*' --exclude build \
  --exclude docs --exclude tools --exclude NosfyUITests \
  --exclude 'Nosfy.xcodeproj/xcuserdata' \
  "$DEPOT/Nosfy" "$DEPOT/NosfyShared" "$DEPOT/NosfyWidgets" \
  "$DEPOT/Nosfy.xcodeproj" "$COPIE/" || exit 1
python3 "$FOUET/applique_patch.py" "$COPIE/Nosfy.xcodeproj/project.pbxproj" || exit 1
mkdir -p "$COPIE/Nosfy.xcodeproj/xcshareddata/xcschemes" "$COPIE/NosfyUITests"
cp "$FOUET/NosfyUITests.xcscheme" "$COPIE/Nosfy.xcodeproj/xcshareddata/xcschemes/"
rm -f "$COPIE/NosfyUITests/"*.swift
cp "$ICI/tests/BoutEnBoutUITests.swift" "$COPIE/NosfyUITests/"

XCB=(xcodebuild -project "$COPIE/Nosfy.xcodeproj" -scheme NosfyUITests
     -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD")

# 2) build-for-testing — code de sortie lu NU
E=0
"${XCB[@]}" -configuration Debug build-for-testing > "$PREUVES/build.log" 2>&1 || E=$?
echo "BUILD EXIT=$E"
[ "$E" -ne 0 ] && { grep -E "error:" "$PREUVES/build.log" | head -10; exit "$E"; }

xcrun simctl boot "$SIM" 2>/dev/null
# 3) chaque cas : app ET runner désinstallés (le piège du runner en cache), filmé
for c in "${CAS[@]}"; do
  xcrun simctl uninstall "$SIM" "$APP" 2>/dev/null
  xcrun simctl listapps "$SIM" 2>/dev/null | grep -o '"fr.kathryn.woop[^"]*xctrunner"' | tr -d '"' |
    while read -r r; do xcrun simctl uninstall "$SIM" "$r"; done
  rm -f "$PREUVES/$c.mp4"
  xcrun simctl io "$SIM" recordVideo --codec=h264 "$PREUVES/$c.mp4" > /dev/null 2>&1 & REC=$!
  perl -e 'select(undef,undef,undef,1.5)'
  E=0
  TEST_RUNNER_BEB_PREUVES="$PREUVES/$c" "${XCB[@]}" test-without-building \
    -only-testing:"NosfyUITests/BoutEnBoutUITests/$c" \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 300 \
    -resultBundlePath "$PREUVES/$c.xcresult" > "$PREUVES/$c.log" 2>&1 || E=$?
  kill -INT "$REC" 2>/dev/null; wait "$REC" 2>/dev/null
  echo "CAS $c EXIT=$E"
  grep -E "BEB |error:|failed|passed" "$PREUVES/$c.log" | grep -v "^Test Suite" | head -60
done
echo fini
