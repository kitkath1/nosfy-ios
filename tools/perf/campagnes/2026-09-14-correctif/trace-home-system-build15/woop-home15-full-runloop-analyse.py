from pathlib import Path
import xml.etree.ElementTree as E
from collections import Counter,defaultdict
import json
BASE=Path('/private/tmp');PID='17908';TID='1445303'
def load(name):
 r=E.parse(BASE/name).getroot();ids={x.attrib['id']:x for x in r.iter() if 'id'in x.attrib};refs=Counter()
 def res(x):
  while 'ref'in x.attrib:refs[x.tag]+=1;x=ids[x.attrib['ref']]
  return x
 def v(x):
  x=res(x);return x.text or x.attrib.get('fmt','')
 cols=[c.findtext('mnemonic') for c in r.findall('.//schema/col')];rows=[]
 for row in r.findall('.//row'):
  cs=list(row);d=dict(zip(cols,[v(x) for x in cs]))
  if 'thread'in cols:
   th=res(cs[cols.index('thread')]);d['tid']=v(th.find('tid'));p=res(th.find('process'));d['pid']=v(p.find('pid'));d['thread_label']=th.attrib.get('fmt')
  rows.append(d)
 return rows,dict(refs)
rl,rr=load('woop-home15-full-system-runloop-events.xml');h,hr=load('woop-home15-full-system-potential-hangs.xml')
main=sorted([r for r in rl if r['tid']==TID and r['pid']==PID],key=lambda r:int(r['timestamp']))
mainhangs=[r for r in h if r['tid']==TID and r['pid']==PID]
pending=defaultdict(list);pairs=defaultdict(list);unmatched=[]
for r in main:
 key=(r['interval-type'],r['nesting-level'],r['interval-identifier'],r['mode'],r['runloop-pointer'])
 t=int(r['timestamp']);event=r['event-type']
 if event=='1':pending[key].append(r)
 elif event=='2':
  if pending[key]:
   start=pending[key].pop();a=int(start['timestamp']);assert t>=a;pairs[r['interval-type']].append([a,t])
  else:unmatched.append(r)
 else:raise ValueError(event)
assert not unmatched,unmatched
for key,rs in pending.items():
 for row in rs:unmatched.append(row)
waits=sorted(pairs['waiting_for_events']);iters=sorted(pairs['individual_iteration']);begin=int(main[0]['timestamp']);end=int(main[-1]['timestamp'])
for i,(a,b)in enumerate(waits):
 assert begin<=a<=b<=end
 if i:assert a>=waits[i-1][1]
# Complement of explicit waiting intervals; these are NOT proof of CPU execution.
busy=[];cursor=begin
for a,b in waits:
 if a>cursor:busy.append([cursor,a])
 cursor=b
if cursor<end:busy.append([cursor,end])
def dur(xs):return sum(b-a for a,b in xs)
def ov(a,b,xs):return sum(max(0,min(b,y)-max(a,x))for x,y in xs)
def records(xs):return [{'start_ns':a,'end_ns':b,'duration_ns':b-a} for a,b in xs]
hangs=[]
for row in mainhangs:
 a=int(row['start']);b=a+int(row['duration'])
 overlaps=[]
 for x,y in busy:
  n=max(0,min(b,y)-max(a,x))
  if n:overlaps.append({'busy_start_ns':x,'busy_end_ns':y,'busy_duration_ns':y-x,'overlap_ns':n,'starts_offset_from_hang_ns':x-a,'ends_offset_from_hang_ns':y-b})
 hangs.append({'start_ns':a,'end_ns':b,'duration_ns':b-a,'type':row['hang-type'],'explicit_wait_ns':ov(a,b,waits),'outside_explicit_wait_ns':ov(a,b,busy),'iteration_overlap_ns':ov(a,b,iters),'busy_intervals':overlaps,'near_events':[{'timestamp_ns':int(r['timestamp']),'type':r['interval-type'],'event':r['event-type']} for r in main if a-1000000<=int(r['timestamp'])<=a+1000000 or b-1000000<=int(r['timestamp'])<=b+1000000]})
summary={'total_rows':len(rl),'main_rows':len(main),'main_mode_counts':dict(Counter(r['mode'] for r in main)),'main_accuracy_counts':dict(Counter(r['timestamp-accuracy']for r in main)),'resolved_refs_runloop':rr,'resolved_refs_hangs':hr,'observed_start_ns':begin,'observed_end_ns':end,'observed_span_ns':end-begin,'paired_iterations':len(iters),'paired_waits':len(waits),'unmatched':unmatched,'iteration_total_duration_ns':dur(iters),'explicit_wait_ns':dur(waits),'outside_explicit_wait_ns':dur(busy),'outside_explicit_wait_pct':100*dur(busy)/(end-begin),'longest_explicit_waits':records(sorted(waits,key=lambda x:x[1]-x[0],reverse=True)[:10]),'longest_iterations':records(sorted(iters,key=lambda x:x[1]-x[0],reverse=True)[:15]),'longest_outside_explicit_wait':records(sorted(busy,key=lambda x:x[1]-x[0],reverse=True)[:15]),'outside_explicit_wait_over_100ms':records([(a,b)for a,b in busy if b-a>=100000000]),'hang_total_duration_ns':sum(x['duration_ns'] for x in hangs),'hangs':hangs}
(BASE/'woop-home15-full-runloop-analysis.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False));(BASE/'woop-home15-full-runloop-intervals.json').write_text(json.dumps({'individual_iteration':records(iters),'waiting_for_events':records(waits),'outside_waiting_for_events':records(busy)},indent=2))
print(json.dumps(summary,indent=2,ensure_ascii=False))
