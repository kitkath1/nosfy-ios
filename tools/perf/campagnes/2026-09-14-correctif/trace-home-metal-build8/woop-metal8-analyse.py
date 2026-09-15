import json,sys
from collections import Counter,defaultdict
sys.path.insert(0,'/private/tmp')
from importlib.machinery import SourceFileLoader
p=SourceFileLoader('parser','/private/tmp/woop-metal8-parse.py').load_module()
r=json.load(open('/private/tmp/woop-metal8-gpu-intervals.json'))['metal-gpu-intervals']['rows']
D=9.627344*1e9
print('GPU first,last',min(float(x['start']) for x in r)/1e9,max(float(x['start'])+float(x['duration']) for x in r)/1e9)
for key in ['process','channel-name','event-depth','channel-subtitle','iosurface-accesses']:
 groups=defaultdict(list)
 for x in r:groups[x[key]].append(x)
 print('\nGROUP',key)
 for name,rr in sorted(groups.items(),key=lambda a:-sum(float(x['duration']) for x in a[1]))[:12]:
  intervals=[(float(x['start']),float(x['start'])+float(x['duration'])) for x in rr]
  print(name,'rows',len(rr),'sum_ms',sum(e-s for s,e in intervals)/1e6,'union_ms',p.union(intervals)/1e6,'union_share_trace',p.union(intervals)/D*100,'latency',p.descr([x['start-latency'] for x in rr]))
print('\nPER SECOND UNION_MS total/backboard/Woop')
for sec in range(10):
 vals=[]
 for proc in ['ALL','backboardd (70)','Woop (17148)']:
  intervals=[]
  for x in r:
   if proc!='ALL' and x['process']!=proc:continue
   s=max(sec*1e9,float(x['start']));e=min((sec+1)*1e9,float(x['start'])+float(x['duration']))
   if e>s:intervals.append((s,e))
  vals.append(round(p.union(intervals)/1e6,3))
 print(sec,*vals)
a=json.load(open('/private/tmp/woop-metal8-display-waits.json'))['displayed-surfaces-interval']['rows']
print('\nTOP DISPLAY DURATION')
for x in sorted(a,key=lambda a:-float(a['duration']))[:12]:print(x)
print('\nTOP CPU TO DISPLAY LATENCY')
for x in sorted((x for x in a if x['cpu-to-display-latency'] is not None),key=lambda a:-float(a['cpu-to-display-latency']))[:10]:print(x)
print('\nDISPLAY counts/sec/starttime')
for sec in range(10):
 ss=[x for x in a if sec*1e9<=float(x['start'])<(sec+1)*1e9]
 print(sec,len(ss))
