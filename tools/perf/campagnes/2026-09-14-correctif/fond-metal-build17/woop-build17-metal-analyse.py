import json, statistics, collections
from pathlib import Path
BASE=Path('/private/tmp')
def lire(nom):
 return [json.loads(l) for l in (BASE/nom).read_text().splitlines() if l.strip()]
def stats(rows):
 chosen=[r for r in rows if 15 <= r['t'] <= 45]
 result={'n':len(chosen),'t_debut':chosen[0]['t'],'t_fin':chosen[-1]['t']}
 for k in ('img','cpu','pire'):
  values=[r[k] for r in chosen]
  result[k]={'mediane':statistics.median(values),'moyenne_lignes':statistics.mean(values),'min':min(values),'max':max(values)}
 for k in ('therm','protection','onglet','seance','player','ile','drag','gel'):
  result[k]=dict(collections.Counter(r.get(k) for r in chosen))
 for k,limit in [('img',30),('img',50),('pire',100),('pire',300),('pire',1000)]:
  result[f'{k}_{"moins" if k=="img" else "plus"}_{limit}']=sum(r[k]<limit if k=='img' else r[k]>limit for r in chosen)
 # Approximation intégrée, t étant arrondi à 0,1s dans le journal.
 previous=0; duration=0; beats=0; cpu=0
 for r in rows:
  overlap=max(0,min(r['t'],45)-max(previous,15))
  if overlap:
   duration+=overlap;beats+=r['img']*overlap;cpu+=r['cpu']*overlap
  previous=r['t']
 result['integration_approximative']={'duree':duration,'callbacks_moyens':beats/duration,'cpu_moyen':cpu/duration}
 return result
summary={mode:stats(lire(f'woop-build17-{mode}-vol.jsonl')) for mode in ('metal','reference')}
nav=lire('woop-build17-metal-nav.jsonl');first=nav[0]['t'];events=[]
for row in nav:
 if row.get('evenement')!='fond-metal':continue
 data=dict(part.split('=',1) for part in row['destination'].split(';'))
 for k in ('gpuComplete','b','p'):data[k]=int(data[k])
 data['t']=row['t'];data['rel_selection']=row['t']-first
 events.append(data)
segments=[]
for previous,current in zip(events,events[1:]):
 dt=current['t']-previous['t']
 segment={'debut':previous['rel_selection'],'fin':current['rel_selection'],'secondes_nav':dt}
 for k in ('gpuComplete','b','p'):segment[k+'_par_seconde_nav']=(current[k]-previous[k])/dt
 for key in ('braise','pilule'):
  if '@' in previous[key] and '@' in current[key]:
   t0=float(previous[key].split('@')[1]);t1=float(current[key].split('@')[1])
   segment[key+'_retour_temps']=t1<t0
 segments.append(segment)
summary['metal_evenements']=events;summary['metal_segments']=segments
start=next(e for e in events if e['rel_selection']>=16);end=events[-1];dt=end['t']-start['t']
summary['metal_regime']={'debut':start['rel_selection'],'fin':end['rel_selection'],'secondes_nav':dt,**{k+'_par_seconde_nav':(end[k]-start[k])/dt for k in ('gpuComplete','b','p')}}
summary['piece_repos']=[{'t':r['t']-first,'destination':r.get('destination')} for r in nav if r.get('evenement')=='piece-repos']
(BASE/'woop-build17-metal-analysis.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items() if k in ('metal','reference','metal_regime')},ensure_ascii=False,indent=2))
