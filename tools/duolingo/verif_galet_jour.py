#!/usr/bin/env python3
"""Un galet = un jour (21-09) — joué ENTIER dans BEGIN / ROLLBACK
sur la base vivante, par l'API de gestion : rien ne reste. `--avec-migration` rejoue d'abord
la migration 20260921090000 (la répétition d avant la pose) ; sans, elle doit être posée."""
import json, sys, urllib.request, urllib.error
from pathlib import Path
R = Path(__file__).resolve().parents[2]
REF = 'ytnnyjkramgiqyxdrkcu'
MIGRATION = R / 'supabase/migrations/20260921090000_chemin_un_galet_par_jour.sql'
BANC = R / 'tools/duolingo/qa-galet-jour.sql'

def query(q):
    req = urllib.request.Request('https://api.supabase.com/v1/projects/' + REF + '/database/query',
        data=json.dumps({'query': q}).encode(),
        headers={'Authorization': 'Bearer ' + (R / '.secrets/supabase-access-token').read_text().strip(),
                 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=180) as res:
        return json.loads(res.read())

avec = '--avec-migration' in sys.argv
sql = 'begin;\n' + (MIGRATION.read_text() + '\n' if avec else '') + BANC.read_text() + '\nrollback;'
try:
    lignes = query(sql)
except urllib.error.HTTPError as e:
    print('ERREUR SQL (transaction annulée) :', e.code, e.read().decode()[:1500]); sys.exit(2)
ko = 0
for l in lignes:
    ok = bool(l['ok']); ko += 0 if ok else 1
    print(('PASS ' if ok else 'FAIL ') + l['nom'] + ((' · ' + str(l['detail'])[:160]) if l.get('detail') else ''))
print(f"Un galet = un jour : {len(lignes) - ko} PASS, {ko} FAIL" + (' (avec la migration rejouée, transaction annulée)' if avec else ' (migration posée, transaction annulée)'))
sys.exit(1 if ko else 0)
