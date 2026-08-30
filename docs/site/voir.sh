#!/bin/zsh
# Ouvre le site de documentation — UN SITE NEXT.JS, EN LOCAL, TOUJOURS ALLUMÉ.
#
#   ./docs/site/voir.sh            http://localhost:3111 — LA référence (next dev, service de session)
#   ./docs/site/voir.sh --fichier  le fichier unique index.html (avion, file://, l'artefact)
#   ./docs/site/voir.sh --dev      next dev au premier plan, dans ce terminal (pour voir ses logs)
#
# Le serveur est un service de session : ~/Library/LaunchAgents/fr.kathryn.woop.doc.plist
# (démarre à l'ouverture de session, se relance s'il tombe, logs dans
# ~/Library/Logs/woop-doc.log). Il sert la SOURCE (content/, app/, components/) : une
# modification de content/*.ts se voit au rechargement, sans build.
set -e
ICI="$(cd "$(dirname "$0")" && pwd)"
URL="http://localhost:3111"
AGENT=fr.kathryn.woop.doc
case "$1" in
  --dev)
    cd "$ICI"; [ -d node_modules ] || npm ci
    launchctl bootout gui/$(id -u)/$AGENT 2>/dev/null || true   # libère le port 3111
    (sleep 3 && open "$URL") &
    exec npm run dev ;;
  --fichier)
    SITE="$ICI/index.html"
    [ -f "$SITE" ] || { print -u2 "livrable introuvable : $SITE — lance \`npm run artefact\` dans docs/site"; exit 1 }
    recent=$(find "$ICI/content" "$ICI/app" "$ICI/components" "$ICI/public" -type f -newer "$SITE" 2>/dev/null | head -1)
    [ -n "$recent" ] && print -u2 "⚠️ index.html est plus vieux que la source ($recent) : \`npm run artefact\` avant de juger."
    print "ouverture de $SITE"; open "$SITE" ;;
  *)
    [ -d "$ICI/node_modules" ] || (cd "$ICI" && npm ci)
    if ! curl -s -o /dev/null "$URL"; then
      print "le serveur ne répond pas : je (re)lance le service $AGENT"
      launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$AGENT.plist 2>/dev/null || launchctl kickstart -k gui/$(id -u)/$AGENT
      for i in {1..15}; do sleep 2; curl -s -o /dev/null "$URL" && break; done
      curl -s -o /dev/null "$URL" || { print -u2 "toujours rien sur $URL — lis ~/Library/Logs/woop-doc.log"; exit 1 }
    fi
    print "ouverture de $URL"; open "$URL" ;;
esac
