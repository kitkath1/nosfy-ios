#!/bin/bash
# Pose les kits de matière (tools/carte-lune/matiere/<nom>/) dans les
# Documents de l'app au SIMULATEUR : Documents/matiere/<nom>/, avec
# l'illustration nue publiée (le chemin est dans <nom>-matiere.json).
#   tools/carte-lune/poser_matiere_sim.sh <udid-du-simulateur> [nom…]
# Sans nom : tous les kits cuits. L'app doit être installée sur ce simulateur.
set -euo pipefail
ICI="$(cd "$(dirname "$0")" && pwd)"
DEPOT="$(cd "$ICI/../.." && pwd)"
SIM="${1:?udid du simulateur}"
shift || true
CONTENEUR="$(xcrun simctl get_app_container "$SIM" fr.kathryn.woop data)"
mkdir -p "$CONTENEUR/Documents/matiere"
if [ $# -eq 0 ]; then
  set -- $(ls "$ICI/matiere")
fi
for nom in "$@"; do
  dest="$CONTENEUR/Documents/matiere/$nom"
  mkdir -p "$dest"
  cp "$ICI/matiere/$nom/"* "$dest/"
  illu=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['illustration'])" \
    "$ICI/matiere/$nom/$nom-matiere.json")
  cp "$DEPOT/$illu" "$dest/$nom-illustration.png"
  echo "posé : $nom"
done
