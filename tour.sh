#!/bin/zsh
# Un tour de boucle : build → export → confrontation.
#   ./tour.sh peche v3
set -e
cd /Users/kathryn/Downloads/woop-icons
ICONE=${1:-peche}
TAG=${2:-x}

xcodebuild -project Woop.xcodeproj -scheme Woop -configuration Debug \
  -destination "id=85D02A02-7E4F-4E40-8169-91FE2E3BD1B9" \
  -derivedDataPath ./dd-icons build 2>&1 | grep -E "error:|BUILD FAILED" && exit 1

./export.sh "$ICONE" "shots/$ICONE-$TAG.png" 4
python3 compare.py "$ICONE" "shots/$ICONE-$TAG.png"
