#!/bin/zsh
# CAMPAGNE « RELEASE CONTRE DEBUG » SUR SON IPHONE (14-09) — la même page, le même
# compte, la même source : seule la configuration du binaire change. Le protocole du
# skill woop-performance (ABBA, thermique lu au départ, 60 s de home immobile après
# 15 s de chauffe, la sonde -sondeVol, la médiane des secondes).
#
#   tools/perf/campagne-binaire.sh
#   MANCHES="R D D R"  DUREE=60  BIN_R=… BIN_D=…  tools/perf/campagne-binaire.sh
#
#   R = le binaire RELEASE (optimisations -O, sans les assertions ni la sonde SondeHit)
#   D = le binaire DEBUG   (celui qu'elle a dans la main depuis des semaines)
#
# Les deux binaires portent le même identifiant (fr.kathryn.woop) : on INSTALLE par-dessus
# (le conteneur reste : sa session, son cache, ses préférences → la home direct, sans
# porte), on ne DÉSINSTALLE jamais. La sonde n'est pas DEBUG-only (SondeVol.swift) : elle
# mesure les deux.
#
# ⚠️ Installer tue l'app ; le téléphone se verrouille 30 s après → on lance AUSSITÔT, et on
# réessaie toutes les 30 s si le lancement est refusé (elle déverrouille). ⚠️ Une manche
# avec therm ≥ 1 à la première seconde est REJOUÉE après 2 min de repos — jamais comparée.
set -u
UDID=${UDID:-022244AD-484B-5489-A884-6B781A82E372}
APP_ID=fr.kathryn.woop
SP=/private/tmp/claude-501/-Users-kathryn-Desktop-woochoper-ios/814d894b-8a59-4029-ab4d-ac3d8b350f45/scratchpad
BIN_R=${BIN_R:-"$SP/dd-release-phone/Build/Products/Release-iphoneos/Woop.app"}
BIN_D=${BIN_D:-"$SP/dd-phone/Build/Products/Debug-iphoneos/Woop.app"}
MANCHES=${MANCHES:-"R D D R"}
DUREE=${DUREE:-60}
CHAUFFE=15
ICI="$(cd "$(dirname "$0")" && pwd)"
SORTIE=${SORTIE:-"$ICI/campagnes/$(date +%Y-%m-%d-%H%M)-binaire"}
mkdir -p "$SORTIE"
installe=""   # la lettre du binaire posé en ce moment ("" = on ne sait pas)

binaire() { case "$1" in R) echo "$BIN_R" ;; D) echo "$BIN_D" ;; *) echo "manche inconnue : $1" >&2; exit 2 ;; esac }

dernier_vol() {
  xcrun devicectl device info files --device $UDID --domain-type appDataContainer \
    --domain-identifier $APP_ID --username mobile --subdirectory Documents 2>/dev/null \
    | grep -o 'vol-[^" ]*\.jsonl' | sort | tail -1
}

manche() {
  local nom=$1 n=$2 app; app="$(binaire $1)"
  echo "── manche $n : $nom  ($(basename "$(dirname "$app")"))"
  if [ "$installe" != "$nom" ]; then
    xcrun devicectl device install app --device $UDID "$app" >/dev/null 2>&1 \
      || { echo "   ✗ installation refusée (le câble ? verrouillé ?)"; return 1; }
    installe=$nom
    echo "   ● $nom posé (par-dessus, conteneur gardé)"
  fi
  local sortie_lancement
  sortie_lancement=$(xcrun devicectl device process launch --terminate-existing --device $UDID $APP_ID -- -sondeVol 2>&1) \
    || { echo "   ✗ lancement refusé : $(echo "$sortie_lancement" | grep -i 'error' | head -1)"; return 1; }
  sleep $((CHAUFFE + DUREE + 3))
  local f; f=$(dernier_vol)
  [ -n "$f" ] || { echo "   ✗ aucun fichier vol-*.jsonl"; return 1; }
  local local_f="$SORTIE/$n-$nom.jsonl"
  xcrun devicectl device copy from --device $UDID --domain-type appDataContainer \
    --domain-identifier $APP_ID --user mobile --source "Documents/$f" --destination "$local_f" >/dev/null 2>&1 \
    || { echo "   ✗ copie refusée"; return 1; }
  python3 "$ICI/lire-vol.py" "$local_f" "$CHAUFFE"
}

i=0
for m in ${=MANCHES}; do
  i=$((i + 1))
  until manche $m $i; do echo "   … on réessaie dans 30 s"; sleep 30; done
  if grep -q '"therm_depart": [1-9]' "$SORTIE/$i-$m.verdict" 2>/dev/null; then
    echo "   ⚠️ thermique ≥ 1 au départ : 2 min de repos, la manche $i est rejouée"
    sleep 120
    until manche $m $i; do sleep 30; done
  fi
done
echo "── fichiers dans $SORTIE"
python3 "$ICI/lire-vol.py" --bilan "$SORTIE"
