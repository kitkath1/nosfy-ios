from pathlib import Path
import json,statistics,collections,sys
base=Path('/private/tmp');prefix=sys.argv[1] if len(sys.argv)>1 else 'woop-build17-metal-long'
def read(suffix):return [json.loads(s) for s in (base/f'{prefix}-{suffix}.jsonl').read_text().splitlines() if s.strip()]
nav=read('nav');vol=read('vol');origin=nav[0]['t'];events=[]
for row in nav:
 if row.get('evenement')!='fond-metal':continue
 data=dict(s.split('=',1) for s in row['destination'].split(';'))
 for k in ('gpuComplete','b','p'):data[k]=int(data[k])
 data['t']=row['t'];data['depuis_premier_event']=row['t']-origin
 for k in ('braise','pilule'):
  data[k+'_temps']=float(data[k].split('@')[1]) if '@' in data[k] else None
 events.append(data)
segments=[];wraps=[]
for a,b in zip(events,events[1:]):
 dt=b['t']-a['t'];segment={'debut':a['depuis_premier_event'],'fin':b['depuis_premier_event'],'dt_nav':dt,'completions_s':(b['gpuComplete']-a['gpuComplete'])/dt,'b_s':(b['b']-a['b'])/dt,'p_s':(b['p']-a['p'])/dt,'compteurs_monotones':all(b[k]>=a[k] for k in ('gpuComplete','b','p'))}
 for texture,counter in [('braise','b'),('pilule','p')]:
  t0=a[texture+'_temps'];t1=b[texture+'_temps']
  if t0 is not None and t1 is not None and t1<t0:
   wraps.append({'flux':texture,'t_nav':b['t'],'intervalle_nav':[a['depuis_premier_event'],b['depuis_premier_event']],'timestamps':[t0,t1],'nouvelles_images':b[counter]-a[counter],'completions':b['gpuComplete']-a['gpuComplete'],'compteurs_monotones':segment['compteurs_monotones'],'temps_video_avec_une_boucle':35.791667+t1-t0,'dt_nav':dt})
 segments.append(segment)
metrics={}
for start,end in [(15,45),(15,65),(45,65),(15,80),(45,80),(80,89)]:
 rows=[r for r in vol if start<=r['t']<=end]
 if not rows:continue
 metrics[f'{start}_{end}']={'n':len(rows),'premier_t':rows[0]['t'],'dernier_t':rows[-1]['t'],'callbacks_medians':statistics.median(r['img'] for r in rows),'cpu_median':statistics.median(r['cpu'] for r in rows),'pire_max':max(r['pire'] for r in rows),'pire_median':statistics.median(r['pire'] for r in rows),'gel':sum(r['gel'] for r in rows),'therm':dict(collections.Counter(r['therm'] for r in rows)),'protection':dict(collections.Counter(r['protection'] for r in rows))}
regimes={}
for start,end in [(15,65),(15,86),(45,65),(0,92)]:
 rows=[r for r in events if start<=r['depuis_premier_event']<=end]
 if len(rows)<2:continue
 a,b=rows[0],rows[-1];dt=b['t']-a['t']
 regimes[f'{start}_{end}']={'debut_nav':a['depuis_premier_event'],'fin_nav':b['depuis_premier_event'],'secondes_nav':dt,**{k+'_par_seconde_nav':(b[k]-a[k])/dt for k in ('gpuComplete','b','p')}}
result={'regimes':regimes,'source':prefix,'nav_rows':len(nav),'vol_rows':len(vol),'metal_events':events,'segments':segments,'boucles_observees':wraps,'vol_fenetres':metrics,'piece_repos':[r for r in nav if r.get('evenement')=='piece-repos']}
(base/f'{prefix}-loop-analysis.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('metal_events','segments','piece_repos')},indent=2,ensure_ascii=False))
print('EVENEMENTS METAL')
for e in events:print(round(e['depuis_premier_event'],3),e['gpuComplete'],e['b'],e['p'],e['braise'],e['pilule'])
