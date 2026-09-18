#!/usr/bin/env python3
"""Fixture QA Cartes isolée : un compte jetable (3 orange / 3 noirs), ses jetons
posés dans les Documents de l'app au simulateur. `creer <sim-udid>` puis
`nettoyer <sim-udid>` — aucun compte personnel touché."""
import json,re,secrets,subprocess,sys,urllib.request,urllib.error,uuid
from pathlib import Path
R=Path(__file__).resolve().parents[3];URL='https://ytnnyjkramgiqyxdrkcu.supabase.co'
KEY=re.search(r'"(sb_publishable_[A-Za-z0-9_-]+)"',(R/'Nosfy/Services/Supabase.swift').read_text())[1]
ADMIN=(R/'.secrets/supabase-service-role').read_text().strip()
ETAT=Path(__file__).with_name('fixture-etat.json')
def call(path,body=None,jwt=None,method='POST',admin=False):
 key=ADMIN if admin else KEY
 req=urllib.request.Request(URL+path,data=None if body is None else json.dumps(body).encode(),method=method,
  headers={'apikey':key,'Authorization':'Bearer '+(jwt or key),'Content-Type':'application/json','Prefer':'return=representation'})
 try:
  with urllib.request.urlopen(req,timeout=60) as res:return res.status,json.loads(res.read() or 'null')
 except urllib.error.HTTPError as e:return e.code,json.loads(e.read() or 'null')
def documents(sim):
 c=subprocess.check_output(['xcrun','simctl','get_app_container',sim,'fr.kathryn.woop','data'],text=True).strip()
 return Path(c)/'Documents'
def creer(sim):
 email=f'nosfy-cartes-{uuid.uuid4()}@example.invalid';pw=secrets.token_urlsafe(32)
 code,u=call('/auth/v1/admin/users',{'email':email,'password':pw,'email_confirm':True,'app_metadata':{'nosfy_qa':'cartes-ouverture-20260918'}},admin=True)
 assert code in (200,201),(code,u);uid=u['id']
 code,s=call('/auth/v1/token?grant_type=password',{'email':email,'password':pw});assert code==200,(code,s)
 for robe in ['lune']*3+['noire']*3:
  code,j=call('/rest/v1/user_boosters',{'user_id':uid,'origine':'cadeau','robe':robe},admin=True);assert code==201,(code,j)
 code,e=call('/rest/v1/rpc/etat_coffre',{},s['access_token']);assert code==200,(code,e)
 assert e['boosters_or']==3 and e['boosters_noirs']==3,e
 d=documents(sim);d.mkdir(parents=True,exist_ok=True)
 (d/'cartes-qa-session.json').write_text(json.dumps({'access':s['access_token'],'refresh':s['refresh_token'],'user':uid}))
 ETAT.write_text(json.dumps({'user':uid,'sim':sim}))
 print('fixture OK',uid[:8],'orange=3 noir=3 ->',d/'cartes-qa-session.json')
def etat(jwt_user=None):
 e=json.loads(ETAT.read_text())
 code,c=call('/rest/v1/user_boosters?select=robe,opened_at&user_id=eq.'+e['user'],method='GET',admin=True)
 code2,col=call('/rest/v1/user_cards?select=card_id,rarete&user_id=eq.'+e['user'],method='GET',admin=True)
 print(json.dumps({'boosters':c,'cartes':col if code2==200 else code2}))
def nettoyer(sim):
 e=json.loads(ETAT.read_text())
 code,_=call('/auth/v1/admin/users/'+e['user'],method='DELETE',admin=True);print('compte supprimé',code)
 for f in ['cartes-qa-session.json']:
  p=documents(sim)/f
  if p.exists():p.unlink()
 ETAT.unlink();print('jetons retirés')
if __name__=='__main__':
 {'creer':creer,'nettoyer':nettoyer,'etat':lambda s:etat()}[sys.argv[1]](sys.argv[2])
