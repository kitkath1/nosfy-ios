import json,statistics,collections
from pathlib import Path
base=Path('/private/tmp')
windows=[('native1-fin',90,None),('ancien',20,None),('endurance',20,None)]
results=[]
for nom,debut,fin in windows:
 p=base/('woop-parole42-'+nom+'-vol.jsonl')
 if not p.exists():continue
 rows=[json.loads(x) for x in p.read_text().splitlines()]
 kept=[x for x in rows if x['t']>debut and (fin is None or x['t']<=fin) and x['onglet']=='home' and not x['welcome'] and not x['premiere']]
 groups=collections.defaultdict(list)
 for x in kept:groups[x['therm'],x['protection']].append(x)
 for k,v in groups.items():results.append({'nom':nom,'therm':k[0],'protection':k[1],'n':len(v),'debut':v[0]['t'],'fin':v[-1]['t'],'cpu_med':statistics.median(x['cpu'] for x in v),'cpu_max':max(x['cpu'] for x in v),'callbacks_med':statistics.median(x['img'] for x in v),'pire_ms':max(x['pire'] for x in v),'gels':sum(x['gel'] for x in v)})
print(json.dumps(results,ensure_ascii=False,indent=2))
