#!/bin/zsh
# Vérifie le site de doc AVANT de commiter : l'invariant des pastilles, la robe au
# grep, deux captures sans tête (1440 et 390) à REGARDER, et le poids.
#   ./tools/docsite/verifier.sh            # tout
#   ./tools/docsite/verifier.sh 114        # avec le compte de contenu attendu
set -e
cd "$(dirname "$0")/../.."
SITE=docs/site/index.html
ATTENDU="${1:-$(grep -o 'id="etat" data-attendu="[0-9]*"' $SITE | grep -oE '[0-9]+')}"

print "── 1. l'invariant (contenu + 1 de légende par état)"
total=0
for k in ok loc srv abs men; do
  n=$(grep -o "class=\"p p-$k" $SITE | wc -l | tr -d ' ')
  print "   $k = $n  (contenu $((n-1)))"
  total=$((total + n - 1))
done
if [ "$total" = "$ATTENDU" ]; then print "   ✔ $total pastilles de contenu = data-attendu"; else print "   ✗ $total ≠ data-attendu $ATTENDU — l'accueil va afficher l'alerte"; fi

print "── 2. la robe"
e=$(grep -cE '<h[123][^>]*>[^<]*[🟢🟡🔵⚪🔴🧨🧭🚩⛔⚠️🎴]' $SITE || true); print "   emoji dans un titre : $e (attendu 0)"
print "   graisses : $(grep -oE 'font-weight:[0-9]+' $SITE | sort -u | tr '\n' ' ')(attendu ⊆ 300 400 500 600)"
print "   flous    : $(grep -c 'backdrop-filter' $SITE) règles (attendu ≤ 4)"
print "   familles : $(grep -oE 'font-family:[^;]+' $SITE | sort -u | wc -l | tr -d ' ') (attendu 2 : Inter + mono système)"
print "   dates relatives : $(grep -cE "depuis aujourd|posé.? aujourd|réparé aujourd|ce matin" $SITE || true) (attendu 0)"
print "   %%{init}%% : $(grep -c '^%%{init' $SITE || true) · classDef : $(grep -cE '^\s*classDef ' $SITE || true) (attendu 0 · 0)"

print "── 3. le poids"
print "   $(wc -c < $SITE | tr -d ' ') o (attendu < 1 000 000)"

print "── 4. les captures (à REGARDER, pas à supposer)"
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
U="file://$PWD/$SITE"
mkdir -p tools/docsite/captures
"$C" --headless --disable-gpu --hide-scrollbars --virtual-time-budget=20000 --window-size=1440,2400 --screenshot=tools/docsite/captures/site-1440.png "$U" 2>/dev/null
"$C" --headless --disable-gpu --hide-scrollbars --virtual-time-budget=20000 --window-size=390,2400  --screenshot=tools/docsite/captures/site-390.png  "$U" 2>/dev/null
"$C" --headless --disable-gpu --virtual-time-budget=20000 --window-size=1440,2400 --dump-dom "$U" 2>/dev/null > tools/docsite/captures/dom.html
print "   $(grep -o 'id="etat"[^>]*' tools/docsite/captures/dom.html)"
print "   compteurs : $(grep -o 'data-compte="[a-z]*">[^<]*' tools/docsite/captures/dom.html | sed 's/data-compte="//;s/">/=/' | tr '\n' ' ')"
print "   cards : $(grep -o 'class="dom[^"]*"' tools/docsite/captures/dom.html | sed 's/class="dom//;s/"//' | tr '\n' '|')"
print "   → tools/docsite/captures/site-1440.png · site-390.png"
