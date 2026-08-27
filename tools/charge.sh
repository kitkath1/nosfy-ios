#!/bin/zsh
# LA CHARGE DE LA MACHINE — à lancer AVANT toute mesure de cadence (-fps).
#
# Pourquoi : une mesure d'images par seconde compare l'app à l'horloge de
# l'écran. Si le Mac est saturé, le simulateur (qui rend en logiciel) n'a
# plus de CPU : on mesure la MACHINE, pas l'app. Les chiffres deviennent
# faux dans le mauvais sens — ils accusent un code innocent.
#
#   charge  = le nombre de travaux qui attendent un cœur (load average 1 min)
#   cœurs   = ce que la machine peut mener de front
#   ratio   = charge / cœurs   → au-dessus de 1, ça attend ; au-dessus de 3,
#                                toute mesure de cadence est à jeter.

L1=$(sysctl -n vm.loadavg | awk '{print $2}')
NC=$(sysctl -n hw.ncpu)
R=$(echo "$L1 $NC" | awk '{printf "%.1f", $1/$2}')

echo "charge 1 min : $L1   cœurs : $NC   ratio : $R"

BUILDS=$(pgrep -c xcodebuild 2>/dev/null || echo 0)
SIMS=$(xcrun simctl list devices | grep -c Booted)
CLAUDE=$(pgrep -fc "native-binary/claude" 2>/dev/null || echo 0)
echo "builds en cours : $BUILDS   simulateurs allumés : $SIMS   sessions Claude : $CLAUDE"

echo
awk -v r="$R" 'BEGIN {
  if (r < 1.0)      print "✅ MACHINE CALME — les mesures de cadence sont fiables."
  else if (r < 2.0) print "🟡 CHARGÉE — mesures indicatives, à confirmer au calme."
  else              print "🔴 SATURÉE — NE PAS MESURER de cadence : le chiffre serait faux."
}'

if [ "$BUILDS" -gt 1 ]; then
  echo "   → $BUILDS builds tournent ensemble : chacun prend tous les cœurs."
fi
if [ "$SIMS" -gt 1 ]; then
  echo "   → $SIMS simulateurs allumés : chacun rend en continu, même caché."
  echo "     éteindre les autres :  xcrun simctl shutdown <nom>"
fi
