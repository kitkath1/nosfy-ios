#!/bin/bash
# MONTE LE BANC DE FOUETTAGE PILULE (lot 2, pivot 04-09) dans une COPIE
# jetable — le pbxproj du dépôt n'est JAMAIS touché (l'école
# woop-piege-arbre-partage-ne-compile-pas).
# Idempotent : re-lancer re-synchronise le code du jour et re-pose le banc.
#
# Usage :  tools/nav/fouettage/monte_banc_pilule.sh [dossier-copie]
# Défaut : /tmp/woop-piluletest
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
DEPOT="$(cd "$ICI/../../.." && pwd)"
COPIE="${1:-/tmp/woop-piluletest}"

mkdir -p "$COPIE"
rsync -a --delete --exclude .git --exclude 'dd-*' --exclude build \
  --exclude docs --exclude tools --exclude WoopUITests \
  --exclude 'Woop.xcodeproj/xcuserdata' \
  "$DEPOT/Woop" "$DEPOT/WoopShared" "$DEPOT/WoopWidgets" \
  "$DEPOT/Woop.xcodeproj" "$COPIE/" || exit 1

# 1) le pbxproj : la cible WoopUITests (patch par ANCRES, refuse si déjà là)
python3 "$ICI/applique_patch.py" "$COPIE/Woop.xcodeproj/project.pbxproj" || exit 1

# 2) le scheme partagé
mkdir -p "$COPIE/Woop.xcodeproj/xcshareddata/xcschemes"
cp "$ICI/WoopUITests.xcscheme" "$COPIE/Woop.xcodeproj/xcshareddata/xcschemes/"

# 3) les hooks app
cp "$ICI/hooks/FouettagePilule.swift" "$COPIE/Woop/Views/"
python3 "$ICI/applique_hooks_pilule.py" "$COPIE" || exit 1

# 4) les fichiers de test
mkdir -p "$COPIE/WoopUITests"
cp "$ICI/tests/BancPilule.swift" \
   "$ICI/tests/FouettagePiluleUITests.swift" \
   "$ICI/tests/IleNativeUITests.swift" \
   "$ICI/tests/IleDansAppUITests.swift" \
   "$ICI/tests/DiagGestePilule.swift" "$COPIE/WoopUITests/"

# 5) la preuve que la structure tient
plutil -lint "$COPIE/Woop.xcodeproj/project.pbxproj" || exit 1
xcodebuild -project "$COPIE/Woop.xcodeproj" -list 2>/dev/null | grep -q WoopUITests || {
  echo "la cible WoopUITests n'est pas dans le projet de la copie"; exit 1; }

echo "BANC PILULE MONTÉ dans $COPIE"
