#!/usr/bin/env python3
"""Gains, synchronisation atomique et Route sur des comptes API jetables uniquement."""
from pathlib import Path
from datetime import datetime,timedelta,timezone
from concurrent.futures import ThreadPoolExecutor
import json,re,secrets,urllib.request,urllib.error,uuid
R=Path(__file__).resolve().parents[2]
URL='https://ytnnyjkramgiqyxdrkcu.supabase.co'
KEY=re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"',(R/'Nosfy/Services/Supabase.swift').read_text())[1]
ADMIN=(R/'.secrets/supabase-service-role').read_text().strip()
crees=[];ok=0

def appel(path,body=None,jwt=None,method='POST',admin=False):
 key=ADMIN if admin else KEY
 req=urllib.request.Request(URL+path,data=None if body is None else json.dumps(body).encode(),method=method,
  headers={'apikey':key,'Authorization':'Bearer '+(jwt or key),'Content-Type':'application/json','Prefer':'return=representation'})
 try:
  with urllib.request.urlopen(req,timeout=45) as r:return r.status,json.loads(r.read() or 'null')
 except urllib.error.HTTPError as e:return e.code,json.loads(e.read() or 'null')

def rpc(nom,corps,jwt,attendu=200):
 code,obj=appel('/rest/v1/rpc/'+nom,corps,jwt)
 assert code==attendu,f'{nom}: HTTP{code}, attendu{attendu}, code={obj.get("code") if isinstance(obj,dict) else "?"}'
 return obj

def check(condition,nom):
 global ok
 assert condition,nom
 ok+=1;print('PASS '+nom,flush=True)

def compte():
 email=f'nosfy-integrite-{uuid.uuid4()}@example.invalid';mdp=secrets.token_urlsafe(32)
 code,u=appel('/auth/v1/admin/users',{'email':email,'password':mdp,'email_confirm':True,'app_metadata':{'nosfy_qa':'integrite-20260918'}},admin=True)
 assert code in (200,201);crees.append(u['id'])
 code,s=appel('/auth/v1/token?grant_type=password',{'email':email,'password':mdp});assert code==200
 return u['id'],s['access_token']

def instantane(uid,n=1,genre='muscu',ancien=0):
 w=str(uuid.uuid4());e=str(uuid.uuid4());fin=datetime.now(timezone.utc)-timedelta(days=ancien,seconds=2)
 body={'p_workout':{'id':w,'user_id':uid,'started_at':(fin-timedelta(minutes=12)).isoformat(),'ended_at':fin.isoformat(),'notes':'QA jetable'},
  'p_exercices':[],'p_series':[],'p_phases':[],'p_piscines':[]}
 if n:
  body['p_exercices']=[{'id':e,'user_id':uid,'workout_id':w,'exercise_id':{'muscu':'hip-thrust','cardio':'tapis-lent','piscine':'piscine'}[genre],'position':0}]
  if genre=='muscu':body['p_series']=[{'id':str(uuid.uuid4()),'user_id':uid,'logged_exercise_id':e,'reps':10,'weight':5,'position':i} for i in range(n)]
  if genre=='cardio':body['p_phases']=[{'id':str(uuid.uuid4()),'user_id':uid,'logged_exercise_id':e,'kind':'effort','seconds':600,'speed':10,'incline':2,'cycle_index':0,'position':0}]
  if genre=='piscine':body['p_piscines']=[{'user_id':uid,'logged_exercise_id':e,'longueurs':20,'metres_par_longueur':25}]
 return body

def cloturer(b,jwt,n=None,attendu=200):
 return rpc('cloturer_seance',{'p_workout':b['p_workout']['id'],'p_series':len(b['p_series']) if n is None else n},jwt,attendu)
def coffre(jwt):return rpc('etat_coffre',{},jwt)
def gains(c):return c['solde_or'],c['solde_argent'],c['boosters_or']
try:
 uid,jwt=compte();autre,ajwt=compte()
 neuf=coffre(jwt);check(gains(neuf)==(0,0,0),'compte neuf : aucun gain')
 check(rpc('seances_chemin',{},jwt)==[],'compte neuf : progression vide')
 for f,b in [('synchroniser_seance',instantane(uid)),('cloturer_seance',{'p_workout':str(uuid.uuid4()),'p_series':1}),('seances_chemin',{})]:
  status,_=appel('/rest/v1/rpc/'+f,b);check(status in (401,403),f+' interdit sans session')
 absent=instantane(uid);cloturer(absent,jwt,attendu=503)
 check(gains(coffre(jwt))==gains(neuf),'séance absente : aucun gain, refus rejouable')
 ouvert=instantane(uid);row=dict(ouvert['p_workout'],ended_at=None)
 check(appel('/rest/v1/workouts',row,jwt)[0]==201,'fixture séance ouverte')
 cloturer(ouvert,jwt,attendu=503);check(gains(coffre(jwt))==gains(neuf),'séance ouverte non payée')
 partiel=instantane(uid);check(appel('/rest/v1/workouts',partiel['p_workout'],jwt)[0]==201,'fixture sauvegarde partielle')
 cloturer(partiel,jwt,attendu=503);check(gains(coffre(jwt))==gains(neuf),'sauvegarde partielle non payée')
 etrangere=instantane(autre);rpc('synchroniser_seance',etrangere,ajwt)
 cloturer(etrangere,jwt,attendu=403);check(gains(coffre(jwt))==gains(neuf),'séance étrangère non payée')
 lien={'id':str(uuid.uuid4()),'user_id':uid,'workout_id':etrangere['p_workout']['id'],'exercise_id':'hip-thrust','position':0}
 code,_=appel('/rest/v1/logged_exercises',lien,jwt);check(code in (401,403),'REST : rattachement à une séance étrangère refusé')
 invalide=instantane(uid);invalide['p_series'][0]['reps']=-1
 rpc('synchroniser_seance',invalide,jwt,400)
 code,rows=appel('/rest/v1/workouts?id=eq.'+invalide['p_workout']['id'],jwt=jwt,method='GET')
 check(code==200 and rows==[],'instantané invalide : aucune écriture partielle')
 tardif=instantane(uid,ancien=40);rpc('synchroniser_seance',tardif,jwt)
 pull=rpc('seances_depuis',{'p_depuis':(datetime.now(timezone.utc)-timedelta(minutes=5)).isoformat()},jwt)
 check(any(w['id']==tardif['p_workout']['id'] for w in pull['seances']),'pull : séance ancienne nouvellement sauvegardée retrouvée')
 cloturer(tardif,jwt,n=99,attendu=503)
 check(gains(coffre(jwt))==gains(neuf),'nombre déclaré gonflé : aucune pièce')
 r=cloturer(tardif,jwt);check(r['series_verifiees']==1 and r['pieces']==20 and r['booster_neuf'],'une série reçue :20 pièces et un sachet')
 avant=gains(coffre(jwt));r=cloturer(tardif,jwt)
 check(r['rejeu'] and gains(coffre(jwt))==avant,'clôture rejouée sans doubler les gains')
 with ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(lambda _:cloturer(tardif,jwt),range(6)))
 check(gains(coffre(jwt))==avant,'six clôtures concurrentes idempotentes')
 rpc('synchroniser_seance',tardif,jwt)
 check(len(rpc('seances_chemin',{},jwt))==1,'renvoi du même instantané : un seul galet')
 vide=instantane(uid,n=0);rpc('synchroniser_seance',vide,jwt);r=cloturer(vide,jwt)
 check(not r['booster_neuf'] and gains(coffre(jwt))==avant,'séance vide complète : aucun faux sachet')
 check(len(rpc('seances_chemin',{},jwt))==1,'séance vide : aucune avance')
 rpc('tirer_noeud_chemin',{'p_noeud':3,'p_pieces':True},jwt,409)
 check(gains(coffre(jwt))==avant,'récompense du troisième galet verrouillée avant3séances')
 for genre in ['cardio','piscine']:
  b=instantane(uid,genre=genre);rpc('synchroniser_seance',b,jwt);r=cloturer(b,jwt)
  check(r['pieces_cardio']>0 and r['booster_neuf'],genre+' seul payé et sachet attribué')
 check(len(rpc('seances_chemin',{},jwt))==3,'muscu, cardio et piscine font chacun avancer')
 r=rpc('tirer_noeud_chemin',{'p_noeud':3,'p_pieces':True},jwt)
 check(not r.get('raison') and not r.get('deja_reclame'),'récompense disponible après3séances')
 avant=gains(coffre(jwt));r=rpc('tirer_noeud_chemin',{'p_noeud':3,'p_pieces':True},jwt)
 check(r['deja_reclame'] and gains(coffre(jwt))==avant,'récompense de galet rejouée sans gain doublé')
 check(gains(coffre(ajwt))==(0,0,0),'isolation : aucun gain sur le second compte')
 rpc('tirer_noeud_chemin',{'p_noeud':44,'p_pieces':False},jwt,409)
 check(gains(coffre(jwt))==avant,'trésor final verrouillé avant35séances')
 for _ in range(32):rpc('synchroniser_seance',instantane(uid),jwt)
 check(len(rpc('seances_chemin',{},jwt))==35,'35séances sauvegardées : fin du cinquième chapitre')
 r=rpc('tirer_noeud_chemin',{'p_noeud':44,'p_pieces':False},jwt)
 check(not r.get('raison') and not r.get('deja_reclame'),'trésor final réclamable à35séances')
 rpc('synchroniser_seance',instantane(uid),jwt);avant=gains(coffre(jwt))
 r=rpc('tirer_noeud_chemin',{'p_noeud':44,'p_pieces':False},jwt)
 check(len(rpc('seances_chemin',{},jwt))==36 and r['deja_reclame'] and gains(coffre(jwt))==avant,'36e séance conservée sans nouveau trésor final')
 for f,b in [('cloturer_seance_validee_interne',{'p_workout':tardif['p_workout']['id'],'p_series':999}),('cloturer_seance_brut',{'p_workout':tardif['p_workout']['id'],'p_series':999}),('tirer_noeud_chemin_valide_interne',{'p_noeud':8,'p_pieces':False})]:
  status,_=appel('/rest/v1/rpc/'+f,b,jwt);check(status in (401,403,404),f+' inaccessible au client')
 print(f'{ok} contrôles PASS',flush=True)
finally:
 for uid in crees:
  status,_=appel('/auth/v1/admin/users/'+uid,admin=True,method='DELETE')
  print('Nettoyage compte QA :',status,flush=True)
  assert status in (200,204)
