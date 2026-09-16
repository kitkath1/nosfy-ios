import json,sys,statistics
from collections import defaultdict
r=[json.loads(x) for x in open(sys.argv[1])];a=float(sys.argv[2]) if len(sys.argv)>2 else 15;b=float(sys.argv[3]) if len(sys.argv)>3 else 1e9
r=[x for x in r if a<x['t']<=b and x['onglet']=='profile' and not x['welcome'] and not x['premiere']];g=defaultdict(list)
for x in r:g[x['therm'],x['protection']].append(x)
for k,v in g.items():print(json.dumps({'therm_protection':k,'n':len(v),'t':[v[0]['t'],v[-1]['t']],'cpu_median':statistics.median(x['cpu'] for x in v),'cpu_max':max(x['cpu'] for x in v),'callbacks_median':statistics.median(x['img'] for x in v),'pire_max_ms':max(x['pire'] for x in v),'gels':sum(x['gel'] for x in v)},ensure_ascii=False))
