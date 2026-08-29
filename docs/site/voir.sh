#!/bin/zsh
# LE SITE DE DOCUMENTATION — on l'ouvre, c'est tout.
#
#   ./docs/site/voir.sh
#
# Un seul fichier autonome : pas de build, pas de serveur, pas de dépendance.
# ⚠️ On l'ouvre par un chemin ABSOLU : ouvrir un chemin relatif depuis un autre
# dossier rend une page blanche sans le dire.
set -e
SITE="$(cd "$(dirname "$0")" && pwd)/index.html"
[ -f "$SITE" ] || { print -u2 "introuvable : $SITE"; exit 1 }
print "ouverture de $SITE"
open "$SITE"
