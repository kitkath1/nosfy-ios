from pathlib import Path
from collections import Counter,defaultdict
import importlib.util,contextlib,io,json,statistics
P=Path('/private/tmp')
spec=importlib.util.spec_from_file_location('a',P/'woop-home15-sans-sonde-system-analyse.py');m=importlib.util.module_from_spec(spec)
with contextlib.redirect_stdout(io.StringIO()):spec.loader.exec_module(m)
groups=defaultdict(list)
for r in m.main['syscall']:
 names='\n'.join(f['name'] for f in r['backtrace'])
 if 'waitForCommitId' in names:groups['waitForCommitId'].append(r)
 if r['call']=='psynch_mutexwait' and 'CA::Context::commit_transaction' in names:groups['CA_commit_mutex'].append(r)
 if r['call']=='kevent_id' and 'CA::Transaction::run_commit_handlers' in names:groups['CA_commit_handlers_queue'].append(r)
intervals=sorted((r['start'],r['start']+r['duration']) for rs in groups.values() for r in rs)
merged=[]
for a,b in intervals:
 if merged and a<=merged[-1][1]:merged[-1][1]=max(b,merged[-1][1])
 else:merged.append([a,b])
blocked=sum(max(0,min(b,r['start']+r['duration'])-max(a,r['start'])) for a,b in merged for r in m.main['thread-state'] if r['state']=='Blocked')
summary={'groups':{k:{'count':len(rs),'duration_ns':sum(r['duration'] for r in rs),'wait_ns':sum(r.get('waittime') or 0 for r in rs)} for k,rs in groups.items()},'union_ns':sum(b-a for a,b in merged),'blocked_inside_ns':blocked,'state_start_ns':min(r['start'] for r in m.main['thread-state']),'state_end_ns':max(r['start']+r['duration'] for r in m.main['thread-state'])}
print(json.dumps(summary,indent=2))
for k,rs in groups.items():
 print(k)
 for r in sorted(rs,key=lambda r:r['duration'],reverse=True)[:4]:print(r['call'],r['start']/1e9,r['duration']/1e6,r['arg1'])
mutexes={r['arg1'] for r in groups['CA_commit_mutex'] if r['duration']>100_000_000}
for mutex in mutexes:
 rs=[r for r in m.allrows['syscall'] if r.get('arg1')==mutex and 'mutex' in (r.get('call') or '')]
 print('MUTEX',hex(int(mutex)),Counter((r['thread'],r['call']) for r in rs))
 for r in rs:
  if 1.297 <=r['start']/1e9<=1.675 and 'Main Thread' not in (r.get('thread')or''):
   print(r['thread'],r['call'],r['start']/1e9,' -> '.join(f['name'] for f in r['backtrace'][:14]))
workers=[]
for h in m.result['hangs']:
 a=h['start'];b=a+h['duration'];rs=[]
 for r in m.allrows['syscall']:
  if 'Main Thread' in (r.get('thread') or ''):continue
  names='\n'.join(f['name'] for f in r['backtrace'])
  if 'waitForCommitId' not in names:continue
  overlap=max(0,min(b,r['start']+r['duration'])-max(a,r['start']))
  if overlap>1_000_000:rs.append({**r,'overlap_ns':overlap})
 rs.sort(key=lambda r:r['overlap_ns'],reverse=True)
 workers.append({'hang_start_ns':a,'worker_calls':rs})
 for r in rs[:2]:print('WORKER',a/1e9,r['thread'],r['call'],r['start']/1e9,r['duration']/1e6,' -> '.join(f['name'] for f in r['backtrace'][:11]))
(P/'woop-home15-sans-sonde-system-sync-groups.json').write_text(json.dumps(groups,indent=2))
(P/'woop-home15-sans-sonde-system-sync-summary.json').write_text(json.dumps(summary,indent=2))
(P/'woop-home15-sans-sonde-system-workers.json').write_text(json.dumps(workers,indent=2))
