#!/bin/zsh
# CAMPAGNE DE LA HOME SUR SON IPHONE (14-09) — le protocole du skill woop-performance,
# joué en une commande : ABBA, thermique lu au départ de chaque manche, 60 s de home
# immobile après 15 s de chauffe, la sonde -sondeVol, la médiane des secondes.
#
#   tools/perf/campagne-home.sh <Woop.app déjà installé ? oui : on ne réinstalle pas>
#   MANCHES="A B B A A B"  DUREE=60  tools/perf/campagne-home.sh
#
#   A = aucun barreau (le vrai binaire)      B = -sansVieRoute (la vie de la card ROUTE éteinte)
#   C = -sansPlateau  (le fond noir→transparent et la crête seuls éteints)
#
# ⚠️ Le câble : le Wi-Fi lâche. ⚠️ Son compte doit être entré (session gardée → la home
# direct, aucun -skipAuth). ⚠️ Une manche avec therm ≥ 1 à la première seconde est REJOUÉE
# après 2 min de repos — jamais comparée (piège n° 3 du skill).
set -u
UDID=${UDID:-022244AD-484B-5489-A884-6B781A82E372}
APP_ID=fr.kathryn.woop
MANCHES=${MANCHES:-"A B B A A B"}
DUREE=${DUREE:-60}
CHAUFFE=15
ICI="$(cd "$(dirname "$0")" && pwd)"
SORTIE=${SORTIE:-"$ICI/campagnes/$(date +%Y-%m-%d-%H%M)"}
mkdir -p "$SORTIE"

drapeaux() {
  case "$1" in
    A) echo "" ;;
    B) echo "-sansVieRoute" ;;
    C) echo "-sansPlateau" ;;
    *) echo "manche inconnue : $1" >&2; exit 2 ;;
  esac
}

dernier_vol() {
  xcrun devicectl device info files --device $UDID --domain-type appDataContainer \
    --domain-identifier $APP_ID --username mobile --subdirectory Documents 2>/dev/null \
    | grep -o 'vol-[^" ]*\.jsonl' | sort | tail -1
}

manche() {
  local nom=$1 n=$2 flags="$(drapeaux $1)"
  echo "── manche $n : $nom ${flags:-(sans barreau)}"
  # ⚠️ Le téléphone se VERROUILLE 30 s après que l'app est tuée, et un téléphone
  # verrouillé refuse tout lancement (payé le 14-09 : « lancement refusé » en boucle).
  # Donc : on ne tue jamais entre deux manches — la sonde tient l'écran éveillé tant
  # que l'app tourne, on copie le fichier PENDANT qu'elle tourne, et la manche
  # suivante remplace la précédente d'un seul geste (--terminate-existing).
  local sortie_lancement
  sortie_lancement=$(xcrun devicectl device process launch --terminate-existing --device $UDID $APP_ID -- -sondeVol $flags 2>&1) \
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
  # le verdict thermique de la manche : ≥ 1 au départ → 2 min de repos, on rejoue
  if grep -q '"therm_depart": [1-9]' "$SORTIE/$i-$m.verdict" 2>/dev/null; then
    echo "   ⚠️ thermique ≥ 1 au départ : 2 min de repos, la manche $i est rejouée"
    sleep 120
    until manche $m $i; do sleep 30; done
  fi
  # (pas de souffle entre deux manches : l'app reste ouverte, l'écran éveillé)
done
echo "── fichiers dans $SORTIE"
python3 "$ICI/lire-vol.py" --bilan "$SORTIE"
