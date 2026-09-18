from pathlib import Path
import xml.etree.ElementTree as E,collections,json
r=E.parse('/tmp/nosfy-chauffe75-profil-metal-metal-gpu-intervals.xml').getroot();ids={e.get('id'):e for e in r.iter() if e.get('id')}
def res(e):
 while e is not None and e.get('ref'):e=ids[e.get('ref')]
 return e
intervals=collections.defaultdict(list)
for row in r.iter('row'):
 c={e.tag:res(e) for e in row}
 if c.get('gpu-state') is None or c['gpu-state'].get('fmt')!='Active':continue
 pro=c.get('process');name=pro.get('fmt') if pro is not None else 'non attribué'
 start=int(c['start-time'].text);end=start+int(res(row[1]).text)
 intervals[(name,'tous')].append((start,end))
 intervals[(name,c['gpu-channel-name'].get('fmt'))].append((start,end))
def union(a):
 total=0;end=-1
 for x,y in sorted(a):
  total+=max(0,y-max(end,x));end=max(end,y)
 return total/1e6
out={'duration_trace_s':11.678581,'limite':'Union des intervalles GPU Active exportés, sur tous les niveaux. Ni watts ni attribution des surfaces composées par backboardd. Les canaux et processus peuvent se chevaucher.','gpu_active_union_ms':{f'{p} / {c}':round(union(a),3) for (p,c),a in intervals.items()}}
Path('/tmp/nosfy-chauffe75-gpu-union.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
print(json.dumps(out,ensure_ascii=False,indent=2))
