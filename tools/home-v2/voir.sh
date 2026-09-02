#!/bin/zsh
# LE TOUR DE BOUCLE DE LA HOME V2 — l'app RÉELLE (châssis + PageCard), pas le
# banc de page : c'est la géométrie du CHÂSSIS qu'on vient mesurer.
#
#   ./tools/home-v2/voir.sh <nom> [args...]
#   ./tools/home-v2/voir.sh pose            → la home posée
#   ./tools/home-v2/voir.sh tiroir -tiroirOuvert
#
# ⚠️ Build NU, JAMAIS de pipe : `xcodebuild | grep` rend le code de GREP, et on
# installe alors une app PÉRIMÉE en croyant juger son propre code (payé 3×).
# ⚠️ DerivedData À SOI (`dd-home2`) : deux builds sur le même DerivedData
# verrouillent la base — d'autres sessions vivent dans cet arbre.
# ⚠️ `--terminate-running-process` est OBLIGATOIRE : sans lui une app déjà
# vivante revient au premier plan AVEC SES ANCIENS ARGUMENTS.
set -e

SIM=${WOOP_SIM:-kat-home2}
DD=dd-home2
OUT=tools/home-v2/captures
LOG=/tmp/home2-build.log
mkdir -p "$OUT"

NOM=${1:-pose}
shift || true

if [ "${SKIP_BUILD:-0}" != "1" ]; then
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
fi

APP="$DD/Build/Products/Debug-iphonesimulator/Woop.app"
# C'est la DATE DU DYLIB qu'on lit : Xcode 16+ met un stub de 58 Ko en binaire
# principal, le vrai code est là.
echo "dylib : $(stat -f '%Sm %z' "$APP/Woop.debug.dylib" 2>/dev/null || echo ABSENT)"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"

# La barre d'état FIGÉE : sans elle l'heure change entre deux captures et
# aucune comparaison avant/après ne tient.
xcrun simctl status_bar "$SIM" override --time "09:41" --batteryState charged \
  --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null || true

# LANCER DEUX FOIS : le premier lancement paie les caches (shaders, fontes,
# première image du décodeur) et ment sur le rendu.
# ⚠️ 14 s : le splash de la lune dure ~10 s, puis l'arrivée de la phrase
# 1,46 s. À 6 s on capture une home À MOITIÉ ARRIVÉE — la phrase n'est pas
# encore là et on mesure du vide (payé au premier tour).
for i in 1 2; do
  xcrun simctl launch --terminate-running-process "$SIM" fr.kathryn.woop \
    -skipAuth "$@" > /dev/null
  sleep 14
done

PNG="$OUT/$NOM-$(date +%H%M%S).png"
xcrun simctl io "$SIM" screenshot "$PNG"
echo "$PNG"
