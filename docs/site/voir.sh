#!/bin/zsh
# Ouvre le site de documentation.
#
#   ./docs/site/voir.sh          le LIVRABLE : index.html, un seul fichier, sans Node ni réseau
#   ./docs/site/voir.sh --dev    la SOURCE : next dev sur http://localhost:3111 (Node 24)
#
# La source (content/, app/, components/) demande Node ; le livrable, non. On ne
# double-clique JAMAIS out/ (ses chemins /_next/ sont absolus) : c'est le rôle du
# livrable, produit par `npm run artefact`.
set -e
ICI="$(cd "$(dirname "$0")" && pwd)"
if [ "$1" = "--dev" ]; then
  cd "$ICI"
  [ -d node_modules ] || npm ci
  (sleep 3 && open "http://localhost:3111") &
  exec npm run dev
fi
SITE="$ICI/index.html"
[ -f "$SITE" ] || { print -u2 "livrable introuvable : $SITE — lance \`npm run artefact\` dans docs/site"; exit 1 }
# Le livrable ment par retard s'il est plus vieux que la source.
recent=$(find "$ICI/content" "$ICI/app" "$ICI/components" "$ICI/public" -type f -newer "$SITE" 2>/dev/null | head -1)
[ -n "$recent" ] && print -u2 "⚠️ index.html est plus vieux que la source ($recent) : \`npm run artefact\` avant de juger."
print "ouverture de $SITE"
open "$SITE"
