#!/bin/bash
# S6 (05-10) : la VÉRIFICATION DE COMPTE armée (une entrée Apple dont la lecture
# de profil a échoué) + aucun réseau au lancement suivant → avant : l'écran noir
# d'erreur, bloquant ; attendu : l'accueil, et le journal qui dit pourquoi.
S=/private/tmp/claude-501/-Users-kathryn-Desktop-woochoper-ios/7ff4d5c8-9be2-4a3a-bb4e-1d951f94a33e/scratchpad
SIM=5CEDF372-FEEE-4CB1-925B-8DE025D80BD0
B=fr.kathryn.woop
O=$S/reseau-s6
DD=$S/dd-test
mkdir -p $O
cd /Users/kathryn/Desktop/Nosfy
xcodebuild -project Nosfy.xcodeproj -scheme Nosfy -configuration Debug \
  -destination "id=$SIM" -derivedDataPath $DD -quiet build > $O/build.log 2>&1
E=$?; echo "BUILD EXIT=$E"
[ $E -ne 0 ] && { grep -E "error:" $O/build.log | head -10; exit 1; }
APP=$DD/Build/Products/Debug-iphonesimulator/Nosfy.app
attendre() { perl -e "select(undef,undef,undef,$1)"; }
xcrun simctl boot $SIM 2>/dev/null
xcrun simctl uninstall $SIM $B; xcrun simctl install $SIM $APP
xcrun simctl launch $SIM $B -skipAuth > /dev/null; attendre 5   # le 1er lancement perd ses arguments
xcrun simctl terminate $SIM $B 2>/dev/null
# la vérification armée, le questionnaire connu fini
xcrun simctl spawn $SIM defaults write $B woop.onboarding.verifier -bool true
xcrun simctl spawn $SIM defaults write $B woop.onboarding.du -bool false
xcrun simctl spawn $SIM defaults write $B woop.prenom -string Kathryn
xcrun simctl launch --console-pty --terminate-running-process $SIM $B -sessionFactice -erreurHorsLigne > $O/s6.log 2>&1 &
P=$!
attendre 24
xcrun simctl io $SIM screenshot $O/s6-horsligne-verification.png > /dev/null 2>&1
kill $P 2>/dev/null; wait $P 2>/dev/null
echo "── s6 (-sessionFactice -erreurHorsLigne, verifier=1)"
grep -E "\[session\]|\[compte\]|\[reseau\]|\[erreur\]|\[PORTE\]" $O/s6.log | sort | uniq -c | head -12
echo "verifier après : $(xcrun simctl spawn $SIM defaults read $B woop.onboarding.verifier 2>/dev/null)"
echo fini
