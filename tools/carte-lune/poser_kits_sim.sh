#!/bin/zsh
# Copie les kits cuits (profondeur/<nom>/plans + depth) dans Documents/monde/<nom>/ de l'app au SIMULATEUR.
SIM=${1:-FD3651DD-7D4E-4C70-B4C3-B6C4D90818F0}
cd "$(dirname "$0")"
CONT=$(xcrun simctl get_app_container $SIM fr.kathryn.woop data) || exit 1
REPO=$(cd ../.. && pwd)
python3 - "$CONT" "$REPO" <<'PY'
import json, os, shutil, sys
cont, repo = sys.argv[1], sys.argv[2]
pub = json.load(open('profondeur/publiees.json'))
n = 0
for c in pub:
    nom = c['reference'].split('/')[1]
    d = f'profondeur/{nom}'
    if not os.path.exists(f'{d}/plans/plans.json'):
        continue
    dst = os.path.join(cont, 'Documents', 'monde', nom)
    os.makedirs(dst, exist_ok=True)
    shutil.copy(os.path.join(repo, c['fichier']), f'{dst}/monde-art.png')
    shutil.copy(f'{d}/{nom}-depth-nue.png', f'{dst}/monde-depth-nue.png')
    shutil.copy(f'{d}/{nom}-depth.png', f'{dst}/monde-depth.png')
    shutil.copy(f'{d}/plans/plans.json', f'{dst}/monde-plans.json')
    plans = json.load(open(f'{d}/plans/plans.json'))
    for k, p in enumerate(plans, start=1):
        shutil.copy(f'{d}/plans/{p["fichier"]}', f'{dst}/monde-plan-{k}.png')
    shutil.copy(f'{d}/plans/{nom}-fond.png', f'{dst}/monde-fond.png')
    shutil.copy(f'{d}/plans/{nom}-fond-depth.png', f'{dst}/monde-fond-depth.png')
    n += 1
print(f'{n} kits posés dans Documents/monde/')
PY
