#!/bin/zsh
# ════════════════════════════════════════════════════════════════════════
# POSER LA CLÉ « SIGN IN WITH APPLE » CHEZ SUPABASE — 13-09 soir
#
# La seule chose que le serveur attend encore pour révoquer les jetons Apple à la
# suppression d'un compte (App Store 5.1.1 v). Trois secrets, jamais dans le dépôt.
#
# Avant : portail développeur Apple → Certificates, Identifiers & Profiles → Keys → +
#   · un nom, cocher « Sign in with Apple », Configure → l'App ID fr.kathryn.woop
#   · Continue, Register, DOWNLOAD (une seule fois possible : AuthKey_XXXXXXXXXX.p8)
#   · noter le Key ID (10 caractères) ; le Team ID est en haut à droite du portail
#
# Usage, depuis la racine du dépôt :
#   tools/porte/poser-cle-apple.sh ~/Downloads/AuthKey_XXXXXXXXXX.p8 XXXXXXXXXX TEAMID1234
#
# Puis la mesure, faite ici même : apple-jeton avec un code bidon doit répondre
# « apple_400 » (Apple a lu une signature valide et refusé le code), plus jamais
# « cle_absente ». La vraie révocation se mesure ensuite UNE fois sur son téléphone,
# avec un Apple ID qu'elle accepte de « cesser d'utiliser » pour Woop.
# ════════════════════════════════════════════════════════════════════════
set -eu
if [ $# -ne 3 ]; then
  echo "usage : $0 <AuthKey_XXXX.p8> <KEY_ID> <TEAM_ID>"; exit 2
fi
P8=$1; KID=$2; TEAM=$3
[ -f "$P8" ] || { echo "✗ fichier .p8 introuvable : $P8"; exit 1 }
grep -q "BEGIN PRIVATE KEY" "$P8" || { echo "✗ ce fichier n'est pas une clé PEM"; exit 1 }
[ ${#KID} -eq 10 ] || { echo "✗ un Key ID fait 10 caractères"; exit 1 }
[ ${#TEAM} -eq 10 ] || { echo "✗ un Team ID fait 10 caractères"; exit 1 }

export SUPABASE_ACCESS_TOKEN=$(cat .secrets/supabase-access-token | tr -d '\n')
REF=ytnnyjkramgiqyxdrkcu
echo "── les trois secrets (+ le client id) chez Supabase"
supabase secrets set --project-ref $REF \
  APPLE_KEY_ID="$KID" APPLE_TEAM_ID="$TEAM" APPLE_CLIENT_ID=fr.kathryn.woop \
  APPLE_PRIVATE_KEY="$(cat "$P8")"

echo "── mesure : apple-jeton avec un code bidon (attendu : apple_400, plus jamais cle_absente)"
URL=https://$REF.supabase.co; KEY=sb_publishable__EHzc8KHeG_f3TdA6x2iag_F3fIW7v2
JWT=$(curl -s -X POST "$URL/auth/v1/token?grant_type=password" -H "apikey: $KEY" -H "Content-Type: application/json" \
  -d '{"email":"kat44426+woop-forge-test@gmail.com","password":"forge-test-2026"}' \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))')
sleep 5   # le temps que les fonctions relisent leurs secrets
curl -s -X POST "$URL/functions/v1/apple-jeton" -H "apikey: $KEY" -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" -d '{"code":"mesure-cle"}' -w "  → HTTP %{http_code}\n"
echo "Si tu lis « apple_400 » : la clé est bonne. Mets la doc à jour (b-ed-apple-jeton) avec cette réponse."
