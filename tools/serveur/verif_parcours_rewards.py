#!/usr/bin/env python3
"""Compte neuf → séances → lune → cartes → reconnexion, API réelle.

Identités QA e-mail jetables : ne valide ni la feuille Apple ni les gestes iPhone.
Aucun crédit ni carte injectés : chaque récompense passe par les RPC publiques.
"""
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
 return u['id'],s,email,mdp

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
def collection(jwt):return rpc('ma_collection',{},jwt)
def etat(jwt):
 return {nom:rpc(nom,{},jwt) for nom in ['profil','seances_chemin','noeuds_chemin_reclames','ma_collection','annonces_en_attente','etat_coffre']}
def ouvrir(booster,jwt):
 code,carte=appel('/functions/v1/forge-card',{'booster_id':booster,'contract_version':2},jwt)
 assert code==200, f'Ouverture : HTTP{code}'
 return carte
try:
 uid,session,email,mdp=compte();vid,vs,_,_=compte()
 jwt=session['access_token'];autre=vs['access_token']
 initial=etat(jwt)
 check(initial['profil']['onboarding_termine'] is False and initial['seances_chemin']==[], 'nouveau compte : inscription et Route vierges')
 check(initial['ma_collection']==[] and initial['annonces_en_attente']==[] and initial['noeuds_chemin_reclames']==[], 'nouveau compte : cartes, annonces et claims vides')
 check(gains(initial['etat_coffre'])==(0,0,0) and initial['etat_coffre']['boosters_noirs']==0, 'nouveau compte : aucune monnaie ni reward')
 p=rpc('definir_profil',{'p_prenom':'Parcours QA','p_langue':'fr','p_but':'force','p_objectif_hebdo':4},jwt)
 check(p['ok'] and p['onboarding_termine'], 'inscription enregistrée')
 rpc('marquer_visite_home',{},jwt)
 recus=[];workouts=[]
 for n in range(1,8):
  b=instantane(uid);workouts.append(b['p_workout']['id'])
  rpc('synchroniser_seance',b,jwt);gain=cloturer(b,jwt);recus.append(gain['receipt_id'])
  check(len(rpc('seances_chemin',{},jwt))==n and gain['series_verifiees']==1, f'séance{n} : travail sauvegardé, gain confirmé, progression{n}')
  if n==1:
   check(gain['pieces_total']==20 and gain['coffre']['boosters_or']==1, 'première séance :20pièces et1sachet réels')
  if n==3:
   mi=rpc('tirer_noeud_chemin',{'p_noeud':3,'p_pieces':True},jwt)
   check(bool(mi['receipt_id']), 'premier galet reward réclamable au seuil3')
  if n==6:
   rpc('tirer_noeud_chemin',{'p_noeud':8,'p_pieces':False},jwt,409)
   check(True, 'lune encore verrouillée avant la septième séance')
 moon=rpc('tirer_noeud_chemin',{'p_noeud':8,'p_pieces':False},jwt)
 check(bool(moon['receipt_id']) and bool(moon['events']), 'septième séance : lune délivre reçu et annonces confirmés')
 claims=[n['noeud_id'] for n in rpc('noeuds_chemin_reclames',{},jwt)]
 check(8 in claims and 3 in claims, 'les deux galets réclamés sont mémorisés au serveur')
 before=coffre(jwt);again=rpc('tirer_noeud_chemin',{'p_noeud':8,'p_pieces':False},jwt)
 check(again['deja_reclame'] and again['receipt_id']==moon['receipt_id'] and coffre(jwt)==before, 'double appui lune : aucun gain ni tirage doublé')
 # Ouvrir chaque sachet réellement issu du reçu lunaire, sans crédit administrateur.
 packs=moon['booster_ids']
 check(bool(packs), 'récompense de la lune : sachets identifiés disponibles')
 code,stocks=appel('/rest/v1/user_boosters?select=id,robe,origine',jwt=jwt,method='GET');assert code==200
 noirs={b['id']: b['robe']=='noire' or b['origine']=='legendaire' for b in stocks}
 restants=set(packs);ouverts=set()
 for _ in range(32):
  if not restants:break
  cible=next(iter(restants))
  pret=rpc('preparer_booster',{'p_operation':str(uuid.uuid4()),'p_legendaire':noirs[cible]},jwt)
  booster=pret['booster_id']
  card=ouvrir(booster,jwt);replay=ouvrir(booster,jwt)
  check(card['acquisition_id']==replay['acquisition_id'], 'ouverture depuis le vrai stock : acquisition atomique et reprise identique')
  rpc('confirmer_revelation',{'p_booster':booster},jwt)
  restants.discard(booster);ouverts.add(booster)
 check(not restants, 'chaque sachet de la lune peut être ouvert depuis son stock')
 check(sum(c['nombre'] for c in collection(jwt))==len(ouverts), 'toutes les cartes ouvertes sont dans la collection')
 code,acquisitions=appel('/rest/v1/user_cards?select=booster_id',jwt=jwt,method='GET')
 check(code==200 and set(packs)<={c['booster_id'] for c in acquisitions}, 'provenance des cartes : tous les sachets du reçu lunaire retrouvés')
 # Une nouvelle session, comme un autre appareil, relit la totalité des données.
 avant=etat(jwt)
 code,s=appel('/auth/v1/token?grant_type=password',{'email':email,'password':mdp});assert code==200
 apres=etat(s['access_token'])
 check(avant==apres, 'reconnexion : même profil,7séances,galets,pièces,sachets,cartes et annonces')
 rows=rpc('seances_depuis',{'p_depuis':None},s['access_token'])['seances']
 check({w['id'] for w in rows}==set(workouts), 'nouvelle session : les7séances sont restituées au client')
 code,sets=appel('/rest/v1/strength_sets?select=id',jwt=s['access_token'],method='GET')
 check(code==200 and len(sets)==7, 'les séries nécessaires à la Route et aux stories sont restituées')
 other=etat(autre)
 check(other['seances_chemin']==[] and other['ma_collection']==[] and other['noeuds_chemin_reclames']==[] and gains(other['etat_coffre'])==(0,0,0), 'autre utilisateur : aucune progression,carte ou reward héritée')
 rpc('tirer_noeud_chemin',{'p_noeud':8,'p_pieces':False},autre,409)
 check(True, 'lune de l’autre compte toujours verrouillée')
 code,_=appel('/rest/v1/rpc/attribuer_carte',{'p_booster':packs[0]},autre)
 check(code==404,'autre compte : ouverture du sachet personnel refusée')
 ids=[e['id'] for e in avant['annonces_en_attente']]
 code,_=appel('/rest/v1/rpc/acquitter_annonces',{'p_ids':ids},s['access_token']);assert code==204
 check(rpc('annonces_en_attente',{},s['access_token'])==[], 'annonces vues : acquittement durable')
 check(rpc('tirer_noeud_chemin',{'p_noeud':8,'p_pieces':False},s['access_token'])['events']==[], 'relecture lune après annonces : aucune annonce rejouée')
 print(f'{ok} contrôles parcours API PASS — feuille Apple et rendu iPhone hors banc',flush=True)
finally:
 for u in crees:
  status,_=appel('/auth/v1/admin/users/'+u,admin=True,method='DELETE')
  assert status in (200,204,404),f'Nettoyage QA HTTP{status}'
 print(f'{len(crees)} identités QA nettoyées ; compte iPhone préservé',flush=True)
