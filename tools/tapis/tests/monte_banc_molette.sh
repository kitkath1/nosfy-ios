#!/bin/bash
# Copie jetable avec la vraie scène et des métadonnées de lecture uniquement.
# Usage : monte_banc_molette.sh /tmp/woop-molette
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
DEPOT="$(cd "$ICI/../../.." && pwd)"
COPIE="${1:?indiquer un dossier temporaire neuf}"
if [ -e "$COPIE" ]; then
  echo "Le dossier doit être neuf : $COPIE" >&2
  exit 1
fi
mkdir -p "$COPIE/NosfyUITests"
cp -cR "$DEPOT/Nosfy" "$DEPOT/NosfyShared" "$DEPOT/NosfyWidgets" "$DEPOT/Nosfy.xcodeproj" "$COPIE/"
python3 "$DEPOT/tools/nav/fouettage/applique_patch.py" "$COPIE/Nosfy.xcodeproj/project.pbxproj"
mkdir -p "$COPIE/Nosfy.xcodeproj/xcshareddata/xcschemes"
cp "$DEPOT/tools/nav/fouettage/NosfyUITests.xcscheme" "$COPIE/Nosfy.xcodeproj/xcshareddata/xcschemes/"
cp "$ICI/MoletteVitesseUITests.swift" "$COPIE/NosfyUITests/"
python3 - "$COPIE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / 'Nosfy/Views/TapisScene.swift'
s = p.read_text()
ancre = '            .highPriorityGesture(glisse)\n'
lecture = '''            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("test.molette")
            .accessibilityLabel("Molette")
            .accessibilityValue("vitesse=\\(Int(etat.valeur));arc=\\(etat.arcOuvert);prise=\\(etat.prise);sceau=\\(seance.vitesseScellee != nil);etat=\\(String(describing: seance.etat));")
'''
assert s.count(ancre) == 1
p.write_text(s.replace(ancre, ancre + lecture))
PY
