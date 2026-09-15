from pathlib import Path
import xml.etree.ElementTree as E
from collections import Counter,defaultdict
import json
TRACE_END=9627343893
allres={}
for p in sorted(Path('/private/tmp').glob('woop-metal8-state-*.xml')):
 root=E.parse(p).getroot()
 ids={x.attrib['id']:x for x in root.iter() if 'id' in x.attrib}
 refs=Counter()
 def resolve(x):
  while 'ref' in x.attrib:
   refs[x.tag]+=1
   x=ids[x.attrib['ref']]
  return x
 def val(x):
  x=resolve(x)
  return x.text if x.text is not None else x.attrib.get('fmt','')
 cols=[c.findtext('mnemonic') for c in root.findall('.//schema/col')]
 rows=[dict(zip(cols,[val(x) for x in row])) for row in root.findall('.//row')]
 for row in rows:
  for k in ['start','duration','end']:
   if k in row:row[k]=int(row[k])
 key=next((k for k in ['thermal-state','gpu-performance-state','state'] if k in cols),None)
 durations=Counter();counts=Counter();intervals=[];durarrays=defaultdict(list);allvalues={}
 bins=defaultdict(Counter)
 for row in rows:
  a,b=row['start'],row['start']+row['duration']
  s=row[key]
  durations[s]+=row['duration'];counts[s]+=1;intervals.append((a,b));durarrays[s].append(row['duration'])
  for sec in range(max(0,a//10**9),min(9,(b-1)//10**9)+1):
   overlap=max(0,min(b,(sec+1)*10**9,TRACE_END)-max(a,sec*10**9))
   bins[sec][s]+=overlap
 for k in cols:
  if k not in ['start','duration','end','narrative','label']:
   cv=Counter(r[k] for r in rows)
   if len(cv)<=20:allvalues[k]=dict(cv)
 intervals.sort();merged=[];overlaps=0
 for a,b in intervals:
  if merged and a<merged[-1][1]:overlaps+=1
  if merged and a<=merged[-1][1]:merged[-1][1]=max(b,merged[-1][1])
  else:merged.append([a,b])
 union=sum(b-a for a,b in merged)
 gaps=[(merged[i][0]-merged[i-1][1],merged[i-1][1],merged[i][0]) for i in range(1,len(merged))]
 out={'file':str(p),'rows':len(rows),'columns':cols,'refs_resolved':dict(refs),'value_counts':allvalues,'sum_duration_ns':sum(durations.values()),'union_ns':union,'trace_end_ns':TRACE_END,'first_start_ns':min((a for a,b in intervals),default=None),'last_end_ns':max((b for a,b in intervals),default=None),'overlapping_interval_count':overlaps,'gap_count':len(gaps),'largest_gaps':sorted(gaps,reverse=True)[:10],'state_durations_ns':dict(durations),'states':{},'per_second_ns':dict(bins)}
 for s,ds in durarrays.items():
  ds.sort();n=len(ds)
  out['states'][s]={'rows':counts[s],'duration_s':durations[s]/1e9,'pct_trace':durations[s]/TRACE_END*100,'pct_recorded_duration':durations[s]/sum(durations.values())*100,'median_duration_us':ds[n//2]/1000,'p95_duration_us':ds[min(n-1,int(.95*n))]/1000,'max_duration_ms':ds[-1]/1e6}
 allres[p.stem]=out
 print(json.dumps(out,indent=2))
 if 'gpu-performance' in p.name:
  Path(str(p).replace('.xml','-resolved.json')).write_text(json.dumps(rows,indent=2))
Path('/private/tmp/woop-metal8-state-analysis.json').write_text(json.dumps(allres,indent=2))
