import xml.etree.ElementTree as E
from collections import defaultdict,Counter
import json
p='/private/tmp/woop-metal8-state-metal-gpu-state-intervals.xml'
r=E.parse(p).getroot(); ids={x.attrib['id']:x for x in r.iter() if 'id' in x.attrib}
def v(x):
 while 'ref' in x.attrib:x=ids[x.attrib['ref']]
 return x.text if x.text is not None else x.attrib.get('fmt','')
a=defaultdict(list)
for row in r.findall('.//row'):
 x=list(row);start=int(v(x[0]));dur=int(v(x[1]));state=v(x[2]);a[state].append((start,start+dur))
merged={}
for state,intervals in a.items():
 m=[]
 for start,end in sorted(intervals):
  if m and start<=m[-1][1]:m[-1][1]=max(m[-1][1],end)
  else:m.append([start,end])
 merged[state]=m
sweep=defaultdict(Counter)
for state,ms in merged.items():
 for start,end in ms:sweep[start][state]+=1;sweep[end][state]-=1
cur=Counter();last=None;durations=Counter();persec=defaultdict(Counter)
for t,ev in sorted(sweep.items()):
 if last is not None:
  key=','.join(sorted(s for s,n in cur.items() if n>0)) or 'Uncovered'
  durations[key]+=t-last
  for sec in range(last//10**9,(t-1)//10**9+1):
   persec[sec][key]+=max(0,min(t,(sec+1)*10**9)-max(last,sec*10**9))
 cur.update(ev);last=t
out={'state_union_ns':{s:sum(b-a for a,b in ms) for s,ms in merged.items()},'exclusive_duration_ns':dict(durations),'top_contiguous':{s:sorted([(b-a,a,b) for a,b in ms],reverse=True)[:10] for s,ms in merged.items()},'per_second_exclusive_ns':dict(persec)}
print(json.dumps(out,indent=2));open('/private/tmp/woop-metal8-state-union.json','w').write(json.dumps(out,indent=2))
