#!/usr/bin/env python3
"""QA réseau Cartes sur deux identités jetables, aucun compte personnel modifié."""
from pathlib import Path
from datetime import datetime,timedelta,timezone
from concurrent.futures import ThreadPoolExecutor
import json,re,secrets,urllib.request,urllib.error,uuid,hashlib
R=Path(__file__).resolve().parents[2];URL='https://ytnnyjkramgiqyxdrkcu.supabase.co'
KEY=re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"',(R/'Nosfy/Services/Supabase.swift').read_text())[1]
ADMIN=(R/'.secrets/supabase-service-role').read_text().strip()
crees=[];checks=[]
def call(path,body=None,jwt=None,method='POST',admin=False):
 key=ADMIN if admin else KEY
 req=urllib.request.Request(URL+path,data=None if body is None else json.dumps(body).encode(),method=method,
  headers={'apikey':key,'Authorization':'Bearer '+(jwt or key),'Content-Type':'application/json','Prefer':'return=representation'})
 try:
  with urllib.request.urlopen(req,timeout=60) as res:return res.status,json.loads(res.read() or 'null')
 except urllib.error.HTTPError as e:return e.code,json.loads(e.read() or 'null')
def rpc(name,b,jwt,expected=200):
 code,j=call('/rest/v1/rpc/'+name,b,jwt)
 if name=='acquitter_annonces' and expected==200:expected=204
 assert code==expected,(name,code,j.get('message','') if isinstance(j,dict) else '')
 return j
def check(ok,label):
 assert ok,label
 checks.append(label);print('PASS',label,flush=True)
def account():
 email=f'nosfy-cartes-{uuid.uuid4()}@example.invalid';password=secrets.token_urlsafe(32)
 code,u=call('/auth/v1/admin/users',{'email':email,'password':password,'email_confirm':True,'app_metadata':{'nosfy_qa':'cartes-20260918'}},admin=True)
 assert code in (200,201);crees.append(u['id'])
 code,s=call('/auth/v1/token?grant_type=password',{'email':email,'password':password});assert code==200
 return u['id'],s['access_token'],email,password
def workout(uid,n=10):
 w=str(uuid.uuid4());e=str(uuid.uuid4());fin=datetime.now(timezone.utc)-timedelta(seconds=2)
 return {'p_workout':{'id':w,'user_id':uid,'started_at':(fin-timedelta(minutes=20)).isoformat(),'ended_at':fin.isoformat()},
  'p_exercices':[{'id':e,'user_id':uid,'workout_id':w,'exercise_id':'hip-thrust','position':0}],
  'p_series':[{'id':str(uuid.uuid4()),'user_id':uid,'logged_exercise_id':e,'reps':10,'weight':5,'position':i} for i in range(n)],
  'p_phases':[],'p_piscines':[]}
def pack(uid,noir=False,origine='cadeau',old=False):
 b={'user_id':uid,'origine':origine,'robe':'noire' if noir else 'lune'}
 if old:b['opened_at']=(datetime.now(timezone.utc)-timedelta(days=2)).isoformat()
 code,j=call('/rest/v1/user_boosters',b,admin=True);assert code==201;return j[0]['id']
def openpack(jwt,noir=False,op=None):
 return rpc('preparer_booster',{'p_operation':op or str(uuid.uuid4()),'p_legendaire':noir},jwt)
def edge(jwt,b,**extras):
 code,j=call('/functions/v1/forge-card',dict(booster_id=b,contract_version=2,**extras),jwt)
 assert code==200,('forge-card',code,j)
 return j
def confirm(jwt,b):return rpc('confirmer_revelation',{'p_booster':b},jwt)
def total(jwt):return sum(x['nombre'] for x in rpc('ma_collection',{},jwt))
try:
 uid,jwt,email,pw=account();vid,vjwt,_,_=account()
 initial=rpc('etat_coffre',{},jwt)
 check(initial['boosters_or']==initial['boosters_noirs']==initial['solde_or']==0 and total(jwt)==0,'compte neuf vide')
 check(rpc('totaux_cartes',{},jwt)=={'common':5,'rare':3,'epic':3,'legendary':3},'14 références, totaux sans spoiler')
 code,c=call('/rest/v1/cards?select=id',jwt=jwt,method='GET');check(code==200 and c==[],'catalogue inconnu non dévoilé par REST')
 for name,body in [('attribuer_carte',{'p_booster':str(uuid.uuid4())}),('preparer_booster',{'p_operation':str(uuid.uuid4())})]:
  code,_=call('/rest/v1/rpc/'+name,body);check(code in (401,403),name+' refuse sans session')
 w=workout(uid);rpc('synchroniser_seance',w,jwt)
 args={'p_workout':w['p_workout']['id'],'p_series':10};gain=rpc('cloturer_seance',args,jwt);replay=rpc('cloturer_seance',args,jwt)
 check(gain['pieces_total']==200 and gain['coffre']['boosters_or']==3 and gain['coffre']['solde_or']==0,'10 séries :200pièces,3boosters,solde0')
 check(len(gain['booster_ids'])==3 and len(set(gain['booster_ids']))==3,'IDs des conversions et forfaitaire dans le reçu')
 check(gain['receipt_id']==replay['receipt_id'] and gain['events']==replay['events'] and replay['coffre']['boosters_or']==3,'rejeu : mêmes reçu, événements et stock')
 ordinary=openpack(jwt);card=edge(jwt,ordinary['booster_id'],workout_id=str(uuid.uuid4()),force_new=True,famille='La lune souveraine')
 check(card['card']['rarete']!='common','première ouverture ordinaire rare ou mieux')
 check(card['workout_id']==w['p_workout']['id'],'provenance réelle du serveur, paramètre client ignoré')
 check(openpack(jwt)['booster_id']==ordinary['booster_id'],'image non confirmée : reprise de la même carte')
 confirm(jwt,ordinary['booster_id'])
 before=rpc('etat_coffre',{},jwt)
 noir=pack(uid,True,old=True);op=str(uuid.uuid4());opened=openpack(jwt,True,op)
 check(opened['booster_id']==noir and opened['prix']==0,'noir offert repris après2jours sans argent')
 with ThreadPoolExecutor(max_workers=20) as pool:replies=list(pool.map(lambda _:edge(jwt,noir),range(20)))
 check(len({x['acquisition_id'] for x in replies})==1 and all(x['card']['rarete']=='legendary' for x in replies),'20appels simultanés :1exemplaire légendaire')
 check(total(jwt)==2,'attribution et collection atomiques')
 confirm(jwt,noir);reopened=openpack(jwt,True,op)
 check(reopened['booster_id']==noir,'opération rejouée après révélation ne consomme pas le suivant')
 after=rpc('etat_coffre',{},jwt)
 check(after['solde_argent']==before['solde_argent'] and after['boosters_or']==before['boosters_or'],'noir gratuit : argent et stock orange préservés')
 rpc('attribuer_carte',{'p_booster':noir},vjwt,404)
 check(total(vjwt)==0,'autre compte sans accès à la carte')
 code,_=call('/rest/v1/user_cards',{'user_id':vid,'card_id':card['card']['id']},vjwt);check(code in (401,403),'écriture directe d’une acquisition interdite')
 # Trois noirs chacun : mêmes références officielles, première série sans doublon légendaire.
 sets=[]
 for person,token in [(uid,jwt),(vid,vjwt)]:
  owned={c['card_id'] for c in rpc('ma_collection',{},token) if c['rarete']=='legendary'}
  while len(owned)<3:
   pack(person,True);bo=openpack(token,True)['booster_id'];j=edge(token,bo);owned.add(j['card']['id']);confirm(token,bo)
  sets.append(owned)
 check(sets[0]==sets[1] and len(sets[0])==3,'deux comptes découvrent les mêmes3légendaires')
 row=next(c for c in rpc('ma_collection',{},jwt) if c['card_id'] in sets[0])
 with urllib.request.urlopen(URL+'/storage/v1/object/public/cards/'+row['art_path'],timeout=60) as res:png=res.read()
 check(hashlib.sha256(png).hexdigest()==row['art_sha256'],'mêmes pixels canoniques, SHA256 vérifié')
 code,s=call('/auth/v1/token?grant_type=password',{'email':email,'password':pw});assert code==200
 check(rpc('ma_collection',{},s['access_token'])==rpc('ma_collection',{},jwt),'reconnexion : collection et vrais exemplaires restaurés')
 events=rpc('annonces_en_attente',{},jwt);check(len({e['id'] for e in events})==len(events) and len(events)>=4,'annonces durables, identités distinctes')
 rpc('acquitter_annonces',{'p_ids':[e['id'] for e in events]},vjwt)
 check(rpc('annonces_en_attente',{},jwt)==events,'un autre compte ne peut acquitter les annonces')
 rpc('acquitter_annonces',{'p_ids':[e['id'] for e in events]},jwt)
 check(rpc('annonces_en_attente',{},jwt)==[],'annonces acquittées non rejouées')
 check(rpc('cloturer_seance',args,jwt)['events']==[],'reçu relu après acquittement sans nouvelle annonce')
 rpc('tirer_noeud_chemin',{'p_noeud':8,'p_pieces':False},jwt,409)
 check(True,'galet futur reste verrouillé par la progression')
 # Le noir payé garde son contrat : une pièce seulement, même opération concurrente.
 code,_=call('/rest/v1/coin_ledger',{'user_id':vid,'delta':1,'raison':'cadeau','currency':'silver'},admin=True);assert code==201
 op=str(uuid.uuid4())
 with ThreadPoolExecutor(max_workers=8) as pool:paid=list(pool.map(lambda _:openpack(vjwt,True,op),range(8)))
 check(len({b['booster_id'] for b in paid})==1 and rpc('etat_coffre',{},vjwt)['solde_argent']==0,'argent→noir :8appels,un seul débit et sachet')
 b=paid[0]['booster_id'];check(edge(vjwt,b)['card']['rarete']=='legendary','noir acheté toujours légendaire');confirm(vjwt,b)
 print(f'{len(checks)} contrôles API PASS',flush=True)
 (R/'tools/carte-lune/integration-2026-09-18/qa-api.json').write_text(json.dumps({'checks':checks,'resultat':'PASS'},ensure_ascii=False,indent=2)+'\n')
finally:
 for u in crees:
  status,_=call('/auth/v1/admin/users/'+u,admin=True,method='DELETE')
  print('Nettoyage identité QA :',status,flush=True);assert status in (200,204)
