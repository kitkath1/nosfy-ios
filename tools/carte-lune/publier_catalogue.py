#!/usr/bin/env python3
"""Publier les seuls PNG approuvés, sans écrasement ni génération pendant les tirages."""
from pathlib import Path
import hashlib,json,uuid,urllib.request,urllib.error,argparse
R=Path(__file__).resolve().parents[2]
REF='ytnnyjkramgiqyxdrkcu'; URL='https://'+REF+'.supabase.co'
OUT=R/'tools/carte-lune/integration-2026-09-18'
parser=argparse.ArgumentParser();parser.add_argument('--upload',action='store_true');parser.add_argument('--activer',action='store_true');a=parser.parse_args()
manifest=json.loads((R/'tools/carte-lune/familles-2026-09-18.json').read_text())
namespace=uuid.UUID('2b66d59d-d2ef-52d2-bc01-cddf7984633b')
def query(q):
 req=urllib.request.Request('https://api.supabase.com/v1/projects/'+REF+'/database/query',data=json.dumps({'query':q}).encode(),
  headers={'Authorization':'Bearer '+(R/'.secrets/supabase-access-token').read_text().strip(),'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=60) as res:return json.loads(res.read())
rows=[]
for family in manifest['families']:
 for c in family['cards']:
  data=(R/c['art']).read_bytes();digest=hashlib.sha256(data).hexdigest();assert digest==c['sha256'],c['key']
  reference=family['key']+'/'+c['key']+'/1'
  row={'id':str(uuid.uuid5(namespace,reference)),'reference':reference,'famille':c['name']['fr'],
   'monde':family['key'],'noms':c['name'],'personnage':c.get('character'),'rarete':c['rarity'],
   'finition':'peinte','art_sha256':digest,'art_path':'catalogue/2026-09/'+digest+'.png','scene':''}
  rows.append(row)
  if a.upload:
   admin=(R/'.secrets/supabase-service-role').read_text().strip()
   req=urllib.request.Request(URL+'/storage/v1/object/cards/'+row['art_path'],data=data,method='POST',
    headers={'Authorization':'Bearer '+admin,'apikey':admin,'Content-Type':'image/png','x-upsert':'false','cache-control':'max-age=31536000'})
   try:
    with urllib.request.urlopen(req,timeout=90) as res:res.read()
   except urllib.error.HTTPError as e:
    detail=e.read()
    if e.code not in (400,409) or b'Duplicate' not in detail and b'already exists' not in detail:raise
  if a.upload or a.activer:
   with urllib.request.urlopen(URL+'/storage/v1/object/public/cards/'+row['art_path'],timeout=90) as res:remote=res.read()
   assert hashlib.sha256(remote).hexdigest()==digest,'image distante différente'
   print('SHA256 distant confirmé :',reference,flush=True)
assert len(rows)==14 and {c['rarete'] for c in rows}=={'common','rare','epic','legendary'}
(OUT/'catalogue-publication.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
if a.activer:
 # dollarquote ne peut être injectée par les noms : le marqueur est contrôlé.
 payload=json.dumps(rows,ensure_ascii=False);assert '$catalogue$' not in payload
 q="""begin;
 insert into public.cards(id,reference,famille,monde,noms,personnage,rarete,finition,art_sha256,art_path,scene)
 select id,reference,famille,monde,noms,personnage,rarete,finition,art_sha256,art_path,scene
 from jsonb_to_recordset($catalogue$"""+payload+"""$catalogue$::jsonb) as c(id uuid,reference text,famille text,monde text,
 noms jsonb,personnage text,rarete text,finition text,art_sha256 text,art_path text,scene text)
 on conflict(reference) do nothing;
 do $$ begin
 if (select count(*) from public.cards where reference in (
 select reference from jsonb_to_recordset($catalogue$"""+payload+"""$catalogue$::jsonb) c(reference text)))<>14 then raise exception 'catalogue incomplet'; end if;
 end $$;
 update public.cards set publication='publiee' where reference in (
 select reference from jsonb_to_recordset($catalogue$"""+payload+"""$catalogue$::jsonb) c(reference text));
 update public.reward_rules set value='true'::jsonb where key='cartes_catalogue_actif';
 commit;
 select rarete,count(*) as references from public.cards where publication='publiee' group by rarete order by rarete;
 """
 print(json.dumps(query(q),ensure_ascii=False))
else:print('Manifeste prêt ; activation non demandée.')
