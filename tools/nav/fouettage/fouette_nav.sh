#!/bin/bash
# LE FOUETTAGE DE LA NAV — build + 10 cas XCUITest + volet film, sur LA
# COPIE jetable montée par monte_banc.sh (le pbxproj du dépôt n'est
# jamais touché). Code de sortie xcodebuild lu NU (loi du dépôt).
#
# Usage :  fouette_nav.sh [tout|cas|film|sonde ...]
#   tout (défaut) : build + 10 cas + film + bilan
#   sonde <args>  : rejouer à la main, prints -gesteSonde/-hitSonde en pty
# Variables : FOUET_COPIE (déf /tmp/woop-navtest) · FOUET_SIM (déf kat-nav)
#             FOUET_DIR (déf /tmp/fouettage-nav) · FOUET_DD
# ⚠️ Le SIM doit être à CE banc : un test INSTALLE l'app de la copie —
#    jouer sur le sim d'une autre session écraserait la sienne.
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
DEPOT="$(cd "$ICI/../../.." && pwd)"
COPIE="${FOUET_COPIE:-/tmp/woop-navtest}"
SCRATCH="${FOUET_DIR:-/tmp/fouettage-nav}"
SIM="${FOUET_SIM:-438D6B78-0A21-44C2-B57D-24148C31F9A0}"   # kat-nav
APP=fr.kathryn.woop
DD="${FOUET_DD:-$COPIE/dd-navtest}"
MODE="${1:-tout}"
mkdir -p "$SCRATCH"

# mode sonde : rejouer un échec à la main, prints visibles au pty
if [ "$MODE" = "sonde" ]; then
  shift; xcrun simctl boot "$SIM" 2>/dev/null
  echo "console-pty (Ctrl-C pour finir) — drapeaux : $*"
  exec xcrun simctl launch --console-pty --terminate-running-process \
    "$SIM" "$APP" -skipAuth -fouettageNav -gesteSonde -hitSonde "$@"
fi

# 0) la copie est-elle montée ? (jamais builder le dépôt : la cible n'y est pas)
xcodebuild -project "$COPIE/Nosfy.xcodeproj" -list 2>/dev/null | grep -q NosfyUITests || {
  echo "COPIE NON MONTÉE ($COPIE) — lancer d'abord : $ICI/monte_banc.sh"; exit 2; }

XCB=(xcodebuild -project "$COPIE/Nosfy.xcodeproj" -scheme NosfyUITests
     -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD")

# 1) la charge (du DÉPÔT — la copie exclut tools/)
"$DEPOT/tools/charge.sh"
RATIO=$(sysctl -n vm.loadavg | awk -v nc="$(sysctl -n hw.ncpu)" '{printf "%.2f", $2/nc}')

# 2) build-for-testing — code de sortie NU
E=0
"${XCB[@]}" -configuration Debug build-for-testing > "$SCRATCH/build.log" 2>&1 || E=$?
if [ "$E" -ne 0 ]; then
  echo "BUILD KO (exit $E)"; grep -E 'error:' "$SCRATCH/build.log" | head -20; exit "$E"
fi
echo "build ok"

# 3) le sim propre (le piège de la séance ouverte qui persiste)
xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl uninstall "$SIM" "$APP" 2>/dev/null
CAS=SAUTE; FILM=SAUTE

# 4) les 10 cas — minuterie par test (un gel = timeout, jamais un hang)
if [ "$MODE" = "tout" ] || [ "$MODE" = "cas" ]; then
  rm -rf "$SCRATCH/cas.xcresult"; E=0
  "${XCB[@]}" test-without-building -only-testing:'NosfyUITests/FouettageNavUITests' \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 240 \
    -resultBundlePath "$SCRATCH/cas.xcresult" > "$SCRATCH/cas.log" 2>&1 || E=$?
  CAS=$E
fi

# 5) le volet film — machine calme exigée, uninstall AVANT (openTab propre)
if [ "$MODE" = "tout" ] || [ "$MODE" = "film" ]; then
  if awk -v r="$RATIO" 'BEGIN{exit !(r < 2.0)}'; then
    xcrun simctl uninstall "$SIM" "$APP" 2>/dev/null
    # ⚠️ recordVideo REFUSE d'écraser (payé : « File exists » = la caméra
    # ne démarre jamais, témoin 0 frame) — on balaye le film d'avant.
    rm -f "$SCRATCH/film-nav.mp4"
    rm -rf "$SCRATCH/fr-nav"
    xcrun simctl io "$SIM" recordVideo --codec h264 "$SCRATCH/film-nav.mp4" & RECPID=$!
    sleep 2; EF=0
    "${XCB[@]}" test-without-building -only-testing:'NosfyUITests/FouettageNavFilm/testFilmRepliDepli' \
      -test-timeouts-enabled YES -default-test-execution-time-allowance 240 \
      > "$SCRATCH/film.log" 2>&1 || EF=$?
    kill -INT "$RECPID" 2>/dev/null; wait "$RECPID" 2>/dev/null; sleep 2
    if [ "$EF" -eq 0 ]; then
      if python3 "$ICI/juge_film_nav.py" "$SCRATCH/film-nav.mp4" "$SCRATCH/fr-nav"
      then FILM=OK; else FILM=ECHEC; fi
    else FILM="ECHEC (scénario exit $EF — le film n'est pas jugé : re-réparer les cas d'abord)"; fi
  else
    echo "machine chargée (ratio $RATIO >= 2) — FILM REFUSÉ, pas jugé."
    FILM="REFUSE (charge $RATIO)"
  fi
fi

# 6) le bilan
echo; echo "═══ BILAN FOUETTAGE NAV ═══"
RES=0
if [ "$CAS" != "SAUTE" ]; then
  python3 "$ICI/resume_cas.py" "$SCRATCH/cas.xcresult" "$SCRATCH/cas.log"; RES=$?
  if [ "$CAS" -eq 0 ] && [ "$RES" -eq 0 ]; then echo "CAS : 10/10 ✓"
  else echo "CAS : ÉCHEC (xcodebuild $CAS) — détail ci-dessus ; rejouer un cas :"
       echo "      fouette_nav.sh sonde …, ou -only-testing:…/testNN_…"; fi
fi
echo "FILM : $FILM"
[ "$CAS" = "SAUTE" ] || { [ "$CAS" -eq 0 ] && [ "$RES" -eq 0 ]; } || exit 1
[ "$FILM" = "OK" ] || [ "$FILM" = "SAUTE" ] || exit 1
exit 0
