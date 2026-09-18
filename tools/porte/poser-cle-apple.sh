#!/bin/zsh
# Configure la clé Sign in with Apple de Nosfy sans afficher son contenu.
# Usage : tools/porte/poser-cle-apple.sh <AuthKey_XXXX.p8> <KEY_ID> <TEAM_ID>
# Le test avec un code factice ne valide pas une vraie connexion/révocation.
set -eu
exec python3 "${0:A:h}/poser_cle_apple.py" "$@"
