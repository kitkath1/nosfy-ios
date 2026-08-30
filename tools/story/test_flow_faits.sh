#!/bin/zsh
# ═══════════════════════════════════════════════════════════════════════════
# TEST DE FLOW DU MOTEUR DE FAITS — SANS SIMULATEUR
#
#   ./tools/story/test_flow_faits.sh [jeton_de_gestion]
#
# ⚠️⚠️ **LE JETON SE PASSE EN ARGUMENT, PAS PAR L'ENVIRONNEMENT.** `~/.zshenv`
# exporte un `SUPABASE_ACCESS_TOKEN` — et `.zshenv` est relu par TOUT zsh, donc
# par ce script : la valeur exportée avant l'appel est SILENCIEUSEMENT écrasée
# par celle du profil. Les deux jetons faisant 44 caractères, une vérification
# de longueur n'y voit rien ; seule leur EMPREINTE les distingue. C'est ce qui
# a fait échouer le nettoyage trois fois (« Unauthorized ») et croire, le matin
# même, que la CLI n'avait pas de droits.
#
# Il joue ce que l'app fera à la clôture d'une séance, contre le VRAI serveur,
# avec un VRAI jeton d'utilisateur (le compte de test de la maison, celui de
# `ForgeServeur.jwtBanc()`).
#
# ⚠️ POURQUOI CE TEST EXISTE. La vérification du 30-08 passait par l'API de
# gestion, donc par le rôle `postgres` : `auth.uid()` n'était jamais évalué, et
# la capture d'`unique_violation` PAR LA FONCTION n'a jamais été exercée — seul
# l'index l'avait été. Un tuyau vérifié des deux côtés dont il manque le milieu,
# c'est exactement le défaut que ce dépôt collectionne.
#
# Ce qu'il prouve, dans l'ordre :
#   ① la fonction écrit sous un vrai utilisateur (`auth.uid()` renseigné) ;
#   ② LE REJEU ne double rien — `connus`, pas une erreur ;
#   ③ un `kind` inconnu est IGNORÉ, pas refusé (sinon l'outbox se boucherait) ;
#   ④ le propriétaire relit ses faits (la policy RLS) ;
#   ⑤ `detail` revient au format que `DoubleFait(heures:minutes:)` attend ;
#   ⑥ l'utilisateur ne peut PAS écrire en direct : seule la fonction écrit.
#
# Le nettoyage demande `SUPABASE_ACCESS_TOKEN` (l'app n'a pas le droit de
# supprimer — c'est le point ⑥). Sans lui le test tourne quand même et le dit.
# ═══════════════════════════════════════════════════════════════════════════
set -u

URL="https://ytnnyjkramgiqyxdrkcu.supabase.co"
K="sb_publishable__EHzc8KHeG_f3TdA6x2iag_F3fIW7v2"
REF="ytnnyjkramgiqyxdrkcu"
# Le compte de test de la maison — jamais un vrai compte (loi du back-end).
MAIL="kat44426+woop-forge-test@gmail.com"
PASS="forge-test-2026"
# Deux séances fictives, reconnaissables, effacées à la fin.
W1="aaaaaaaa-0000-4000-8000-00000000f1a1"
W2="aaaaaaaa-0000-4000-8000-00000000f1a2"
JOUR=$(date -u +%Y-%m-%d)
# Le jeton de gestion, pour le seul nettoyage. En ARGUMENT (voir l'en-tête) ;
# l'environnement ne sert que de repli, et il est piégé.
TOKEN="${1:-${SUPABASE_ACCESS_TOKEN:-}}"

ok=0; ko=0
verdict() { # verdict <attendu> <obtenu> <libellé>
  if [ "$1" = "$2" ]; then printf "   ✅ %s\n" "$3"; ok=$((ok+1))
  else printf "   ❌ %s\n      attendu : %s\n      obtenu  : %s\n" "$3" "$1" "$2"; ko=$((ko+1)); fi
}

# ⚠️ ON EFFACE AVANT, PAS SEULEMENT APRÈS. Un test qui suppose une table propre
# et ne la rend pas propre lui-même échoue au deuxième tour — et pire, il
# échoue en accusant le code. Payé au premier run : le script était mort avant
# son nettoyage, et le tour suivant lisait `connus: 2` là où il attendait
# `poses: 2`.
# ⚠️⚠️ **NE JAMAIS COMPTER `len()` D'UN JSON QUI PEUT ÊTRE UNE ERREUR.** Payé
# ici même : l'API rend une LISTE quand tout va bien et un OBJET
# `{"message": …}` quand ça casse — et `len()` d'un objet à une clé vaut **1**.
# Le nettoyage a donc annoncé « 1 ligne effacée » trois fois de suite alors
# qu'il n'effaçait RIEN, et le test a accusé le serveur d'un défaut qui était
# le sien. Une sonde qui ne sait pas dire « j'ai échoué » ment.
menage() {
  [ -n "${TOKEN}" ] || return 0
  curl -s -X POST "https://api.supabase.com/v1/projects/$REF/database/query" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "{\"query\":\"delete from public.workout_facts where workout_id in ('$W1','$W2') returning workout_id\"}" \
    | python3 -c 'import json,sys
d = json.load(sys.stdin)
print(len(d) if isinstance(d, list) else "❌ ÉCHEC : " + json.dumps(d)[:160])'
}

echo "═══ ⓪ TABLE RASE ═══"
if [ -n "${TOKEN}" ]; then
  echo "   lignes de test effacées avant de commencer : $(menage)"
else
  echo "   ⚠️ SUPABASE_ACCESS_TOKEN absent : le test suppose la table déjà propre."
fi

echo "═══ ① LE JETON DU COMPTE DE TEST ═══"
JWT=$(curl -s -X POST "$URL/auth/v1/token?grant_type=password" \
  -H "apikey: $K" -H "Content-Type: application/json" \
  -d "{\"email\":\"$MAIL\",\"password\":\"$PASS\"}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))")
[ -n "$JWT" ] && printf "   ✅ jeton obtenu (%d caractères)\n" "${#JWT}" && ok=$((ok+1)) \
              || { printf "   ❌ pas de jeton — le reste n'a aucun sens\n"; exit 1; }

rpc() { # rpc <corps json>
  curl -s -X POST "$URL/rest/v1/rpc/poser_faits_seance" \
    -H "apikey: $K" -H "Authorization: Bearer $JWT" \
    -H "Content-Type: application/json" -d "$1"
}

# Ce que l'app calculera à la clôture : « 12 séries, ton record de la semaine
# était 9 » — et « deuxième séance du jour », avec ses heures.
FAITS='[{"kind":"top_muscu","mesure":"series","valeur":12,"precedent":9},
        {"kind":"double_jour","detail":{"heures":["07:12","19:40"],"minutes":114}}]'

echo "═══ ② LA CLÔTURE : deux faits posés sous un VRAI utilisateur ═══"
R=$(rpc "{\"p_workout\":\"$W1\",\"p_jour\":\"$JOUR\",\"p_faits\":$FAITS}")
echo "   $R"
verdict '{"poses": 2, "connus": 0, "ignores": 0}' "$R" "deux faits rangés, aucun ignoré"

echo "═══ ③ LE REJEU — l'outbox rappelle sans savoir ═══"
R=$(rpc "{\"p_workout\":\"$W1\",\"p_jour\":\"$JOUR\",\"p_faits\":$FAITS}")
echo "   $R"
verdict '{"poses": 0, "connus": 2, "ignores": 0}' "$R" "rien de doublé, et AUCUNE erreur"

echo "═══ ④ UN kind INCONNU — il doit être ignoré, pas refuser l'appel ═══"
R=$(rpc "{\"p_workout\":\"$W2\",\"p_jour\":\"$JOUR\",\"p_faits\":[{\"kind\":\"record_du_futur\"},{\"kind\":\"top_cardio\",\"mesure\":\"hiit_secondes\",\"valeur\":900,\"precedent\":600}]}")
echo "   $R"
verdict '{"poses": 1, "connus": 0, "ignores": 1}' "$R" "le connu passe, l'inconnu est compté et jeté"

echo "═══ ⑤ LA RELECTURE — la policy RLS, et le format que la story attend ═══"
LU=$(curl -s "$URL/rest/v1/workout_facts?select=kind,mesure,valeur,precedent,detail&workout_id=eq.$W1&order=kind" \
  -H "apikey: $K" -H "Authorization: Bearer $JWT")
echo "   $LU"
N=$(printf '%s' "$LU" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
verdict "2" "$N" "le propriétaire relit ses deux faits"
H=$(printf '%s' "$LU" | python3 -c "
import json,sys
d={r['kind']:r for r in json.load(sys.stdin)}
print(json.dumps(d.get('double_jour',{}).get('detail',{}), sort_keys=True))" 2>/dev/null)
verdict '{"heures": ["07:12", "19:40"], "minutes": 114}' "$H" "detail au format DoubleFait(heures:minutes:)"
T=$(printf '%s' "$LU" | python3 -c "
import json,sys
d={r['kind']:r for r in json.load(sys.stdin)}
t=d.get('top_muscu',{}); print(f\"{t.get('mesure')} {t.get('valeur')} sur {t.get('precedent')}\")" 2>/dev/null)
verdict "series 12 sur 9" "$T" "la page TOP peut dire EN QUOI elle s'est dépassée"

echo "═══ ⑥ L'ÉCRITURE DIRECTE — elle doit être REFUSÉE (seule la fonction écrit) ═══"
C=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$URL/rest/v1/workout_facts" \
  -H "apikey: $K" -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
  -d "{\"workout_id\":\"$W2\",\"kind\":\"top_muscu\",\"jour\":\"$JOUR\"}")
[ "$C" = "401" ] || [ "$C" = "403" ] || [ "$C" = "42501" ] && C="refusé"
verdict "refusé" "$C" "aucune policy d'insertion : le client ne peut pas écrire à la main"

echo "═══ NETTOYAGE ═══"
if [ -n "${TOKEN}" ]; then
  echo "   effacés : $(menage)"
else
  echo "   ⚠️ SUPABASE_ACCESS_TOKEN absent : les faits de test RESTENT en base."
fi

echo
printf "═══ VERDICT : %d ✅   %d ❌ ═══\n" "$ok" "$ko"
[ "$ko" -eq 0 ] || exit 1
