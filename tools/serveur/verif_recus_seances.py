#!/usr/bin/env python3
"""Bilans historiques : comptes QA seulement, aucun paiement pendant la lecture."""
from pathlib import Path
from datetime import datetime, timedelta, timezone
import json, re, secrets, urllib.request, urllib.error, uuid

ROOT = Path(__file__).resolve().parents[2]
BASE = 'https://ytnnyjkramgiqyxdrkcu.supabase.co'
KEY = re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"', (ROOT/'Nosfy/Services/Supabase.swift').read_text())[1]
ADMIN = (ROOT/'.secrets/supabase-service-role').read_text().strip()
crees = []
n = 0

def req(path, body=None, jwt=None, admin=False, method='POST'):
    key = ADMIN if admin else KEY
    r = urllib.request.Request(BASE+path, method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={'apikey': key, 'Authorization': 'Bearer '+(jwt or key), 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(r, timeout=30) as x: return x.status, json.loads(x.read() or 'null')
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read() or 'null')

def rpc(name, jwt, body=None):
    code, obj = req('/rest/v1/rpc/'+name, body or {}, jwt)
    assert code in (200, 204), (name, code)
    return obj

def check(ok, texte):
    global n
    assert ok, texte
    n += 1
    print('PASS '+texte, flush=True)

def compte():
    email = 'nosfy-recus-'+str(uuid.uuid4())+'@example.invalid'; password = secrets.token_urlsafe(30)
    code, u = req('/auth/v1/admin/users', {'email':email, 'password':password, 'email_confirm':True}, admin=True)
    assert code in (200,201)
    crees.append(u['id'])
    code, s = req('/auth/v1/token?grant_type=password', {'email':email,'password':password})
    assert code == 200
    return u['id'], s['access_token']

def seance(jwt, heure, poids=5, regler=True):
    wid, eid, sid = [str(uuid.uuid4()) for _ in range(3)]
    rpc('synchroniser_seance', jwt, {'p_workout':{'id':wid,'started_at':heure.isoformat(),'ended_at':(heure+timedelta(minutes=10)).isoformat()},
        'p_exercices':[{'id':eid,'workout_id':wid,'exercise_id':'hip-thrust','position':0}],
        'p_series':[{'id':sid,'logged_exercise_id':eid,'reps':10,'weight':poids,'position':0}],
        'p_phases':[], 'p_piscines':[]})
    return wid, rpc('cloturer_seance',jwt,{'p_workout':wid,'p_series':1}) if regler else None

def lecture(jwt, ids): return rpc('recus_seances', jwt, {'p_workouts':ids})

try:
    uid, jwt = compte(); uid2, autre = compte()
    jour = datetime.now(timezone.utc).replace(hour=6,minute=0,second=0,microsecond=0)-timedelta(days=2)
    a, ca = seance(jwt, jour)
    b, cb = seance(jwt, jour+timedelta(hours=3), poids=15)
    foreign, _ = seance(autre, jour)
    non_reglee, _ = seance(jwt, jour+timedelta(days=1), regler=False)
    code, _ = req('/rest/v1/rpc/recus_seances',{'p_workouts':[a]})
    check(code in (401,403), 'lecture interdite sans session')
    check(lecture(jwt,[]) == [], 'liste vide : aucun bilan')
    check(lecture(jwt,[str(uuid.uuid4())]) == [], 'séance absente : aucun bilan inventé')
    check(lecture(jwt,[non_reglee]) == [], 'séance non réglée : aucun paiement déclenché')
    check(lecture(autre,[a,b]) == [], 'autre compte : reçus inaccessibles')
    rows = lecture(jwt,[a,b,foreign,a]); bilans = {r['workout_id']:r['bilan'] for r in rows}
    check(len(rows)==2 and all(r['user_id']==uid for r in rows), 'liste mélangée : uniquement les deux séances du compte, sans doublon')
    check(bilans[a]['pieces']==ca['pieces_total'] and bilans[a]['boosters']==len(ca['booster_ids']), 'première séance : montant et sachets du vrai reçu')
    top = next((f['kind'] for f in cb['faits'] if f['kind'].startswith('top_')), None)
    double = next((f['detail'] for f in cb['faits'] if f['kind']=='double_jour'), None)
    check(top is not None and bilans[b]['top']==top, 'record historique conservé')
    check(double is not None and bilans[b]['heuresDouble']==double['heures'] and bilans[b]['minutesDouble']==double['minutes'], 'deux séances : heures et durée du fait serveur conservées')
    avant = rpc('etat_coffre',jwt); events = rpc('annonces_en_attente',jwt)
    for _ in range(3): check(lecture(jwt,[a,b])==rows, 'lecture répétée : mêmes bilans')
    check(rpc('etat_coffre',jwt)==avant and rpc('annonces_en_attente',jwt)==events, 'lectures seules : coffre et annonces inchangés')
    rpc('acquitter_annonces',jwt,{'p_ids':[e['id'] for e in events]})
    check(lecture(jwt,[a,b])==rows, 'acquittement des annonces : bilans intacts')
    code,_=req('/rest/v1/rpc/recus_seances',{'p_workouts':[a]*501},jwt)
    check(code==400, 'requête au-delà de 500 UUID refusée')
    # Reproduire sur UNE séance QA la période antérieure à cartes_prive.recus.
    # Les lignes du carnet et sachets restent ; leur receipt_id devient null.
    token=(ROOT/'.secrets/supabase-access-token').read_text().strip()
    query="delete from cartes_prive.recus where user_id='"+uid+"'::uuid and cause='seance:"+a+"';"
    r=urllib.request.Request('https://api.supabase.com/v1/projects/ytnnyjkramgiqyxdrkcu/database/query',
        headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'},data=json.dumps({'query':query}).encode())
    with urllib.request.urlopen(r,timeout=30) as x: x.read()
    check(lecture(jwt,[a])[0]['bilan']==bilans[a], 'séance antérieure aux reçus : gains retrouvés dans les écritures conservées')
    check(lecture(autre,[a])==[], 'ancien carnet également isolé entre comptes')
    print(f'{n} contrôles reçus historiques PASS',flush=True)
finally:
    for uid in crees:
        code,_=req('/auth/v1/admin/users/'+uid,admin=True,method='DELETE')
        assert code==200
    print(f'Comptes QA supprimés : {len(crees)} ; aucun compte personnel modifié',flush=True)
