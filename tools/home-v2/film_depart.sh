#!/bin/zsh
# LE FILM DU DÉPART — la seule façon de juger le fondu croisé.
#
#   ./tools/home-v2/film_depart.sh [secondes]
#
# ⚠️ Une cinématique se FILME, jamais screenshot par screenshot (~4 s l'image
# au simulateur : on ne verrait ni le rythme ni le raccord). Le banc
# `-departAuto` rejoue la scène en boucle — cycle : 1,2 s de repos · le film
# (1,95 s) · 1,4 s de pose · la fermeture.
#
# ⚠️ L'INSTANT QUI COMPTE est la BASCULE : `basculeAt` 0,94 × T = 1,83 s après
# le début du film, sur 0,12 s. C'est LÀ que les deux blocs de texte se
# substituent, et c'est le seul endroit où un mauvais `courseTexte` se voit.
#
# ⚠️ Le film se referme par SIGINT (`kill -INT`), jamais SIGKILL : simctl
# n'écrit l'en-tête du .mov qu'à la fermeture propre.
set -e

SIM=${WOOP_SIM:-kat-home2}
DD=dd-home2
OUT=tools/home-v2/films
DUREE=${1:-24}
mkdir -p "$OUT"

APP="$DD/Build/Products/Debug-iphonesimulator/Woop.app"
xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch --terminate-running-process "$SIM" fr.kathryn.woop \
  -skipAuth -departAuto > /dev/null
sleep 14   # le splash de la lune + l'arrivée de la page

MOV="$OUT/depart-$(date +%H%M%S).mov"
xcrun simctl io "$SIM" recordVideo --codec h264 --force "$MOV" &
PID=$!
sleep "$DUREE"
kill -INT $PID
wait $PID 2>/dev/null || true
echo "$MOV"
