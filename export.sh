#!/bin/zsh
# Export d'une icône seule en planche carrée 1020 px.
#   ./export.sh <chocolat|bras|peche> <sortie.png>
# La scène d'export dessine un carré de 340 pt centré ; à ×3 il fait
# exactement 1020 px. On capture l'écran entier puis on recadre au centre —
# `sips -c` recadre centré, donc le carré tombe juste.
set -e
ICONE=$1
OUT=$2
BRUT=/Users/kathryn/Downloads/woop-icons/shots/_brut-$ICONE.png

/Users/kathryn/Downloads/woop-icons/shot.sh "$ICONE" "$BRUT" 4 >/dev/null
sips -c 1020 1020 "$BRUT" --out "$OUT" >/dev/null
echo "export -> $OUT ($(sips -g pixelWidth -g pixelHeight "$OUT" | tail -2 | tr -d ' \n'))"
