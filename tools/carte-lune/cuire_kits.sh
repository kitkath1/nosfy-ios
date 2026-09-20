#!/bin/zsh
# LE KIT DE TOUTES LES CARTES PUBLIÉES (20-09, sur son « le même effet pour les autres cartes »).
# Pour chaque référence de profondeur/publiees.json : profondeur vraie + détourage
# (cuire_profondeur.py), puis six plans + fond/relief reconstitués par LaMa (cuire_plans.py).
# Sortie : profondeur/<nom>/ (nom = dernier segment de la référence).
cd "$(dirname "$0")"
python3 - <<'PY'
import json, subprocess, os, time
REPO=os.path.abspath(os.path.join(os.getcwd(), '..', '..'))
pub=json.load(open('profondeur/publiees.json'))
for c in pub:
    nom=c['reference'].split('/')[1]; src=os.path.join(REPO, c['fichier'])
    if os.path.exists(f'profondeur/{nom}/plans/plans.json'):
        print('déjà cuit', nom); continue
    t=time.time()
    r=subprocess.run(['python3','cuire_profondeur.py',src,nom],capture_output=True,text=True)
    if r.returncode: print('ÉCHEC profondeur', nom, r.stderr[-300:]); continue
    r=subprocess.run(['python3','cuire_plans.py',nom,src],capture_output=True,text=True)
    if r.returncode: print('ÉCHEC plans', nom, r.stderr[-300:]); continue
    print(f'OK {nom} ({c["rarete"]}, {c["monde"]}) en {time.time()-t:.0f} s', flush=True)
PY
