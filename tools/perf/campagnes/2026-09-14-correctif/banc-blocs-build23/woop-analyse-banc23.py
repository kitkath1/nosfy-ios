import json, statistics, sys
from pathlib import Path
vol = Path(sys.argv[1]); nav = Path(sys.argv[2])
rows = [json.loads(s) for s in vol.read_text().splitlines() if s.strip()]
events = [json.loads(s) for s in nav.read_text().splitlines() if s.strip()]
assert rows and all('bancHome' in r for r in rows), 'Journal absent ou ancien : aucun bancHome'
expected = ['complete','sansWidgets','sansRoute','fondSeul','nu','complete']
groups=[]
for r in rows:
 if not groups or groups[-1][0]['bancHome'] != r['bancHome']:groups.append([])
 groups[-1].append(r)
summary=[]
for i,group in enumerate(groups):
 # Exclut les transitions et l'inertie de la charge Mach récente.
 start=group[0]['t']; warmup=15 if i==0 else 10
 stable=[r for r in group if r['t']>=start+warmup and r['onglet']=='home' and not any(r[k] for k in ['seance','player','drag','chemin'])]
 result={'phase':group[0]['bancHome'],'observations':len(group),'debut':start,'fin':group[-1]['t'],'exclusion_initiale_s':warmup,'n_stables':len(stable)}
 if stable:
  result.update(cpu_mediane=statistics.median(r['cpu'] for r in stable),callbacks_mediane=statistics.median(r['img'] for r in stable),pire_max_ms=max(r['pire'] for r in stable),therm=sorted(set(r['therm'] for r in stable)),protection=sorted(set(r['protection'] for r in stable)),tics_max=[max(r['tics'][j] for r in stable) for j in range(5)],gels_retenus=sum(bool(r['gel']) for r in stable),pire_plafonne=any(bool(r['gel']) for r in stable))
 summary.append(result)
result={'vol':str(vol),'nav':str(nav),'phases_attendues':expected,'parcours_complet':[g[0]['bancHome'] for g in groups]==expected,'resultats':summary,'evenements_banc':[e for e in events if 'banc-home' in e.get('evenement','')],'limites':'CPU Mach récent, callbacks CADisplayLink, pas énergie ni images GPU. Phases chaudes avec fond protégé potentiellement immobile.'}
print(json.dumps(result,ensure_ascii=False,indent=2))
