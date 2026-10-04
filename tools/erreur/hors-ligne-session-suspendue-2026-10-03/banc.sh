#!/bin/bash
# Banc de la session suspendue (03-10) : build propre, puis 4 scénarios.
S=/private/tmp/claude-501/-Users-kathryn-Desktop-woochoper-ios/7ff4d5c8-9be2-4a3a-bb4e-1d951f94a33e/scratchpad
SIM=5CEDF372-FEEE-4CB1-925B-8DE025D80BD0
B=fr.kathryn.woop
O=$S/reseau
DD=$S/dd-reseau
mkdir -p $O
cd /Users/kathryn/Desktop/Nosfy
xcodebuild -project Nosfy.xcodeproj -scheme Nosfy -configuration Debug \
  -destination "id=$SIM" -derivedDataPath $DD build > $O/build.log 2>&1
E=$?; echo "BUILD EXIT=$E"
[ $E -ne 0 ] && { grep -E "error:" $O/build.log | head -10; exit 1; }
APP=$DD/Build/Products/Debug-iphonesimulator/Nosfy.app
attendre() { perl -e "select(undef,undef,undef,$1)"; }
lancer() { # $1 nom, $2 durée, reste = arguments
  local nom=$1 duree=$2; shift 2
  xcrun simctl terminate $SIM $B 2>/dev/null
  xcrun simctl launch --console-pty --terminate-running-process $SIM $B "$@" > $O/$nom.log 2>&1 &
  local P=$!
  attendre $duree
  xcrun simctl io $SIM screenshot $O/$nom.png > /dev/null 2>&1
  kill $P 2>/dev/null; wait $P 2>/dev/null
  echo "── $nom ($*)"
  grep -E "\[session\]|\[compte\]|\[reseau\]|\[erreur\]|effacé" $O/$nom.log | sort | uniq -c | head -12
}
neuf() {
  xcrun simctl uninstall $SIM $B; xcrun simctl install $SIM $APP
  xcrun simctl launch $SIM $B -skipAuth > /dev/null; attendre 4   # le 1er lancement perd ses arguments
}
xcrun simctl boot $SIM 2>/dev/null
# S1 : séance en cours, réseau là, refresh refusé
neuf
lancer s1-seance-refus 30 -sessionFactice -activeWorkout
# S2 : relance HORS LIGNE (la salle) — séance toujours ouverte
lancer s2-horsligne 22 -erreurHorsLigne
# S3 : relance EN LIGNE, séance encore ouverte : pas de porte
lancer s3-enligne-seance 22
# S4 : sans séance, réseau là : la porte de reconnexion
neuf
lancer s4-sans-seance-refus 30 -sessionFactice
# S5 : relance hors ligne après S4 : l'accueil, pas d'écran d'erreur
lancer s5-horsligne-home 22 -erreurHorsLigne
echo fini
