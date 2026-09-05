#!/bin/bash
# LA RÉCEPTION DU PAN MAÎTRE — vrais touchers XCUITest sur le player.
# Le doigt fantôme (-playerDoigt) court-circuite le recognizer : lui seul
# ce banc-ci exerce la RÉCEPTION (shouldReceive, porte scroll, direction).
#
# Réutilise le banc nav (patron offert par la session 07, 03-09) :
# monte_banc.sh monte la copie jetable + la cible WoopUITests (dossier
# synchronisé : notre fichier déposé compile tout seul), puis on ne joue
# QUE la classe FouettageReceptionUITests, sur NOTRE sim.
#
# Usage :  tools/player/fouettage/fouette_reception.sh
# Variables : FOUET_COPIE (déf /tmp/woop-receptiontest — JAMAIS la copie
#             nav /tmp/woop-navtest d'une autre session)
#             FOUET_SIM   (déf kat-pagecard) · FOUET_DIR
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
DEPOT="$(cd "$ICI/../../.." && pwd)"
COPIE="${FOUET_COPIE:-/tmp/woop-receptiontest}"
SIM="${FOUET_SIM:-AAA47DD0-4F2A-4088-A775-1E26519C6355}"   # kat-pagecard
DD="$COPIE/dd-reception"
SCRATCH="${FOUET_DIR:-/tmp/fouettage-reception}"
APP=fr.kathryn.woop
mkdir -p "$SCRATCH"

# 0) la charge AVANT tout (un build parallèle = mesures fausses, loi du dépôt)
"$DEPOT/tools/charge.sh" || true

# 1) monter la copie (idempotent) + déposer NOTRE cas
"$DEPOT/tools/nav/fouettage/monte_banc.sh" "$COPIE" || exit 1
cp "$ICI/tests/FouettageReceptionUITests.swift" "$COPIE/WoopUITests/" || exit 1

XCB=(xcodebuild -project "$COPIE/Woop.xcodeproj" -scheme WoopUITests
     -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD")

# 2) build-for-testing — code de sortie NU (jamais de pipe sur la ligne)
E=0
"${XCB[@]}" -configuration Debug build-for-testing > "$SCRATCH/build.log" 2>&1 || E=$?
if [ "$E" -ne 0 ]; then
  echo "BUILD KO (exit $E)"
  grep -E 'error:' "$SCRATCH/build.log" | head -20
  exit "$E"
fi
echo "build ok"

# 3) le sim propre (piège -demoData : une séance OUVERTE persiste)
xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl uninstall "$SIM" "$APP" 2>/dev/null

# 4) les cas — minuterie par test (un gel = timeout, jamais un hang)
rm -rf "$SCRATCH/reception.xcresult"
E=0
"${XCB[@]}" test-without-building \
  -only-testing:'WoopUITests/FouettageReceptionUITests' \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 240 \
  -resultBundlePath "$SCRATCH/reception.xcresult" \
  > "$SCRATCH/cas.log" 2>&1 || E=$?
echo "CAS exit=$E"
grep -E "Test Case .*(passed|failed)" "$SCRATCH/cas.log" | sed 's/^.*Test Case/Test Case/' | tail -12
[ "$E" -ne 0 ] && grep -B2 -A6 "XCTAssertTrue failed" "$SCRATCH/cas.log" | head -40
exit "$E"
