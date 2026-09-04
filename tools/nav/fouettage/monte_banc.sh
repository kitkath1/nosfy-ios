#!/bin/bash
# MONTE LE BANC DE FOUETTAGE NAV dans une COPIE jetable — le pbxproj du
# dépôt n'est JAMAIS touché (l'école woop-piege-arbre-partage-ne-compile-pas).
# Idempotent : re-lancer re-synchronise le code du jour et re-pose le banc.
#
# Usage :  tools/nav/fouettage/monte_banc.sh [dossier-copie]
# Défaut : /tmp/woop-navtest
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
DEPOT="$(cd "$ICI/../../.." && pwd)"
COPIE="${1:-/tmp/woop-navtest}"

mkdir -p "$COPIE"
rsync -a --delete --exclude .git --exclude 'dd-*' --exclude build \
  --exclude docs --exclude tools --exclude WoopUITests \
  --exclude 'Woop.xcodeproj/xcuserdata' \
  "$DEPOT/Woop" "$DEPOT/WoopShared" "$DEPOT/WoopWidgets" \
  "$DEPOT/Woop.xcodeproj" "$COPIE/" || exit 1

# 1) le pbxproj : la cible WoopUITests (patch par ANCRES, refuse si déjà là)
# (le rsync vient de remettre le pbxproj VIERGE du dépôt : le patch
#  s'applique à chaque montage — un échec ici = une ancre a bougé)
python3 "$ICI/applique_patch.py" "$COPIE/Woop.xcodeproj/project.pbxproj" || exit 1

# 2) le scheme partagé
mkdir -p "$COPIE/Woop.xcodeproj/xcshareddata/xcschemes"
cp "$ICI/WoopUITests.xcscheme" "$COPIE/Woop.xcodeproj/xcshareddata/xcschemes/"

# 3) les hooks app (FouettageNav.swift + 2 édits par ancres)
cp "$ICI/hooks/FouettageNav.swift" "$COPIE/Woop/Views/"
python3 "$ICI/applique_hooks.py" "$COPIE" || exit 1

# 4) les fichiers de test
mkdir -p "$COPIE/WoopUITests"
cp "$ICI/tests/BancNav.swift" "$ICI/tests/FouettageNavUITests.swift" \
   "$ICI/tests/FouettageNavFilm.swift" "$COPIE/WoopUITests/"

# 5) la preuve que la structure tient
plutil -lint "$COPIE/Woop.xcodeproj/project.pbxproj" || exit 1
xcodebuild -project "$COPIE/Woop.xcodeproj" -list 2>/dev/null | grep -q WoopUITests || {
  echo "la cible WoopUITests n'apparaît pas"; exit 1; }
echo "BANC MONTÉ dans $COPIE (code du jour re-synchronisé)"
