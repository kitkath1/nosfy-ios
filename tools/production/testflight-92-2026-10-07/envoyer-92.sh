#!/bin/zsh
# TESTFLIGHT 92 (07-10-2026) — le geste du 91, ARBRE FIGÉ. Kathryn : « lance le TestFlight
#    avec tous les commits qui ne sont pas partis depuis le dernier ». main ne compile
#    toujours pas seul (NosfyPropose, PlayerSeance, ReglementSeance, PlafondJour : fichiers
#    jamais suivis, appelés par du code commité) : la copie de l’arbre porte les commits
#    depuis le 91 ET le travail non commité des autres sessions, comme le 91.
#
# ⚠️ ARBRE FIGÉ, PAS `git worktree` : le dépôt NE COMPILE PAS SEUL (mesuré le
#    22-09 : 12 erreurs à HEAD, et le 29-09 CoupeBanc/CoupeEtat déclarés deux
#    fois parce qu'une autre session a supprimé CoupeBlanche.swift sans
#    commiter la suppression). Le binaire se fait donc sur une COPIE de
#    l'arbre de travail, qui porte aussi le travail non commité des autres.
# ⚠️ LA CLÉ ASC EST OBLIGATOIRE à l'export : Xcode n'a aucune session ouverte,
#    sans elle c'est « No Accounts » + « No signing certificate ».
# ⚠️ NE JAMAIS finir la commande d'archive par `grep -c "error:"` : il rend 1
#    quand il n'y a AUCUNE erreur, et le fond de tâche croit que ça a échoué.
#    On lit « ARCHIVE SUCCEEDED », jamais le code de sortie.
set -u
BUILD=92
SRC=/Users/kathryn/Desktop/Nosfy
FIGE=/tmp/nosfy-tf$BUILD
OUT=$SRC/tools/production/testflight-$BUILD-2026-10-07
KEY_ID=JBXG6FH45V
ISSUER=7652dfba-fd23-4aac-a995-f09303625f22
mkdir -p "$OUT"

echo "== 1/5 arbre figé"
rm -rf "$FIGE"; mkdir -p "$FIGE"
rsync -a --delete \
  --exclude '.git' --exclude 'dd-*' --exclude 'node_modules' \
  --exclude '*.mov' --exclude 'build/' --exclude 'docs/site/.next' \
  --exclude 'docs/site/out' --exclude '.secrets' \
  "$SRC"/ "$FIGE"/ 2>&1 | tail -2
git -C "$SRC" rev-parse HEAD > "$OUT/head.txt"
git -C "$SRC" status --porcelain | wc -l | tr -d ' ' >> "$OUT/head.txt"
du -sh "$FIGE" | tail -1

echo "== 2/5 archive Release (build $BUILD)"
cd "$FIGE"
xcodebuild -project Nosfy.xcodeproj -scheme Nosfy -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$FIGE/Nosfy.xcarchive" \
  CURRENT_PROJECT_VERSION=$BUILD \
  archive > "$OUT/archive.log" 2>&1
if grep -q "ARCHIVE SUCCEEDED" "$OUT/archive.log"; then
  echo "ARCHIVE SUCCEEDED"
else
  echo "ARCHIVE FAILED — les erreurs :"
  grep -E "error:" "$OUT/archive.log" | sort -u | head -20
  exit 1
fi

echo "== 3/5 export (clé ASC)"
cp "$OUT/../testflight-83-2026-09-22/ExportOptions.plist" "$OUT/ExportOptions.plist"
rm -rf "$FIGE/export"
xcodebuild -exportArchive \
  -archivePath "$FIGE/Nosfy.xcarchive" \
  -exportPath "$FIGE/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_$KEY_ID.p8 \
  -authenticationKeyID $KEY_ID \
  -authenticationKeyIssuerID $ISSUER > "$OUT/export.log" 2>&1
if grep -q "EXPORT SUCCEEDED" "$OUT/export.log"; then
  echo "EXPORT SUCCEEDED"
else
  echo "EXPORT FAILED :"; tail -20 "$OUT/export.log"; exit 1
fi
shasum -a 256 "$FIGE/export/Nosfy.ipa" > "$OUT/ipa.sha256"
ls -la "$FIGE/export/"

echo "== 4/5 envoi chez Apple"
xcrun altool --upload-app --type ios \
  --file "$FIGE/export/Nosfy.ipa" \
  --apiKey $KEY_ID --apiIssuer $ISSUER > "$OUT/upload.log" 2>&1
UP=$?
tail -6 "$OUT/upload.log"
[ $UP -eq 0 ] && echo "UPLOAD OK" || { echo "UPLOAD KO ($UP)"; exit 1; }

echo "== 5/5 fini — le traitement Apple prend 5 à 20 min"
