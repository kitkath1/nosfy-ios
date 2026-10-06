#!/bin/bash
# LA CONNEXION SOUS UN RÉSEAU FAIBLE (06-10, « la connexion n'est pas résolue »).
# Six cas au simulateur, l'app de dd-test (construite avant), trousseau remis à zéro.
S=/private/tmp/claude-501/-Users-kathryn-Desktop-woochoper-ios/7ff4d5c8-9be2-4a3a-bb4e-1d951f94a33e/scratchpad
SIM=5CEDF372-FEEE-4CB1-925B-8DE025D80BD0
B=fr.kathryn.woop
O=${1:-$S/connexion}
APP=$S/dd-test/Build/Products/Debug-iphonesimulator/Nosfy.app
mkdir -p $O
attendre() { perl -e "select(undef,undef,undef,$1)"; }
neuf() {
  xcrun simctl terminate $SIM $B 2>/dev/null
  xcrun simctl uninstall $SIM $B 2>/dev/null
  xcrun simctl keychain $SIM reset
  xcrun simctl install $SIM $APP
  xcrun simctl launch $SIM $B -skipAuth > /dev/null; attendre 5   # le 1er lancement perd ses arguments
  xcrun simctl terminate $SIM $B
}
lancer() { # $1 nom, $2 durée, reste = arguments
  local nom=$1 duree=$2; shift 2
  xcrun simctl launch --console-pty --terminate-running-process $SIM $B "$@" > $O/$nom.log 2>&1 &
  local P=$!
  attendre $duree
  xcrun simctl io $SIM screenshot $O/$nom.png > /dev/null 2>&1
  kill $P 2>/dev/null; wait $P 2>/dev/null
  echo "── $nom ($*)"
  grep -E "\[session\]|\[compte\]|\[erreur\]|effacé|PORTE" $O/$nom.log | sort | uniq -c | head -12
  echo "   suspendue = $(xcrun simctl spawn $SIM defaults read $B woop.session.identiteSuspendue 2>/dev/null || echo non)"
}
xcrun simctl boot $SIM 2>/dev/null
# A. un VRAI refus du serveur (refresh inconnu), réseau là : suspension (juste), l'app reste ouverte
neuf; lancer A-vrai-refus 30 -sessionFactice
# B. un portail Wi-Fi qui répond 403 en HTML : PAS de suspension
neuf; lancer B-portail 24 -sessionFactice -refreshPortail
# C. hors ligne : trois essais rapprochés, PAS de suspension, l'accueil
neuf; lancer C-hors-ligne 24 -sessionFactice -erreurHorsLigne
# D. la vérification de compte armée + hors ligne : l'accueil
neuf
xcrun simctl spawn $SIM defaults write $B woop.onboarding.verifier -bool true
xcrun simctl spawn $SIM defaults write $B woop.onboarding.du -bool false
xcrun simctl spawn $SIM defaults write $B woop.prenom -string Kathryn
lancer D-verif-hors-ligne 24 -sessionFactice -erreurHorsLigne
# E. la vérification armée + réseau là + refresh refusé PENDANT la lecture : avant, l'écran bloquait
neuf
xcrun simctl spawn $SIM defaults write $B woop.onboarding.verifier -bool true
xcrun simctl spawn $SIM defaults write $B woop.onboarding.du -bool false
xcrun simctl spawn $SIM defaults write $B woop.prenom -string Kathryn
lancer E-verif-refus 30 -sessionFactice
# F. le jeton d'accès gardé : session du compte de test, puis relance HORS LIGNE sans renouvellement
neuf; lancer F1-session-test 30 -sessionAdoptee
lancer F2-relance-hors-ligne 20 -erreurHorsLigne
xcrun simctl keychain $SIM reset
echo fini
