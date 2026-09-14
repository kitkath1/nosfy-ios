#!/bin/zsh
# LE CATALOGUE DES POP-UPS ET DES TOASTERS (14-09, Kathryn : « fais des screenshots de
# toutes les variantes de pop-up qu'on a, toutes les robes, et les toaster notifications,
# nomme-les bien en composant pour qu'on puisse éditer ou pas ») — une capture par variante,
# prise au simulateur sur le banc de chaque composant, FIGÉE quand le banc le permet.
#
#   tools/docsite/capturer-popups.sh [UDID-simulateur] [Woop.app]
#   → tools/docsite/shots/pop-<nom>.png (1206 × 2622), puis `cd docs/site && npm run captures`.
#
# Chaque ligne : nom · arguments de lancement · délai (s) avant la capture.
set -u
SIM=${1:-D8A31930-1D84-42BF-A129-051BB6B9195B}
APP=${2:-/private/tmp/claude-501/-Users-kathryn-Desktop-woochoper-ios/814d894b-8a59-4029-ab4d-ac3d8b350f45/scratchpad/dd-chambre/Build/Products/Debug-iphonesimulator/Woop.app}
ICI="$(cd "$(dirname "$0")" && pwd)"
SHOTS="$ICI/shots"
mkdir -p "$SHOTS"
BID=fr.kathryn.woop

xcrun simctl boot $SIM 2>/dev/null || true
xcrun simctl install $SIM "$APP" || exit 1

capturer() {
  local nom=$1 delai=$2; shift 2
  xcrun simctl terminate $SIM $BID 2>/dev/null
  xcrun simctl launch --terminate-running-process $SIM $BID "$@" >/dev/null 2>&1 || { echo "✗ $nom : lancement"; return; }
  sleep $delai
  xcrun simctl io $SIM screenshot "$SHOTS/pop-$nom.png" >/dev/null 2>&1 && echo "● pop-$nom  ($*)"
}

# ── RewardPopup : les 7 robes (RewardLab, la nuit vraie, figées à mi-course, sans bandeau)
for robe in spotlight halo neon galet fire welcome welcomeTexte; do
  capturer "reward-$robe" 5 -rewardLab -robe $robe -rewardFreeze 0.6 -rewardNu
done
# ── la card Welcome Back de PRODUCTION telle qu'elle s'ouvre aujourd'hui (sans sa vidéo).
#    ⚠️ Elle n'est DUE que si le compte du banc a une séance finie et n'a pas pris son +10
#    du jour : libérer la ligne coin_ledger du jour avant, la remettre après (claim).
capturer "welcome-back-prod" 14 -skipAuth -sessionAdoptee -sansVisite
# ── la pop-up de première fois : 2 robes (galet = la vraie ; test = Nosfy de face) — la home
#    arrive après le splash DEBUG (3,4 s), la pop-up 3 s plus tard : 13 s.
capturer "premiere-galet"  13 -skipAuth -welcomePremiere galet -sansVisite
capturer "premiere-entree" 13 -skipAuth -welcomePremiere test -sansVisite
# ── les 3 toasters (NotifLab, empilés, figés, sans bandeau) puis chacun seul
capturer "notifs-pile" 4 -notifLab -notifFige -notifNu
for i in 1 2 3; do capturer "notif-$i" 4 -notifLab -notifFige -notifNu -notifSeule $i; done
# ── la card STOP (figée, sans bandeau)
capturer "stop" 4 -stopLab -stopFige -stopNu
# ── la pop-up BOOSTER (« Ouvrir ») sur la home — après une RÉINSTALLATION : une session
#    gardée puis révoquée au serveur rendrait la porte malgré -skipAuth (C0).
xcrun simctl terminate $SIM $BID 2>/dev/null; xcrun simctl uninstall $SIM $BID; xcrun simctl install $SIM "$APP"
capturer "booster" 13 -skipAuth -boosterPopup
# ── la card à gratter du chemin, 5 cas
for cas in coins black boosters rare legendary; do capturer "chemin-$cas" 5 -skipAuth -rewardChemin $cas; done
echo "→ $(ls "$SHOTS"/pop-*.png 2>/dev/null | wc -l | tr -d ' ') captures dans $SHOTS"
