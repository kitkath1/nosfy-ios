import importlib.util,contextlib,io,json,collections
spec=importlib.util.spec_from_file_location('a','/private/tmp/woop-lisere11-system-analyse.py');m=importlib.util.module_from_spec(spec)
with contextlib.redirect_stdout(io.StringIO()):spec.loader.exec_module(m)
mutex='4487430160'
rs=[r for r in m.allrows['syscall'] if r.get('arg1')==mutex and 'mutex' in (r.get('call') or '')]
print('Mutex',hex(int(mutex)),'calls',len(rs))
print(collections.Counter((r['thread'],r['call']) for r in rs))
for a,b in [(2.998,3.364),(5.360,5.727),(5.760,6.143)]:
 print('\nINTERVAL',a,b)
 for r in rs:
  if a-0.001 <= r['start']/1e9 <=b+0.001:
   print(r['start']/1e9,r['duration']/1e6,r['thread'],r['call'])
   if 'Main Thread' not in (r['thread'] or ''):print(' -> '.join(f['name'] for f in r['backtrace'][:20]))
g=json.load(open('/private/tmp/woop-lisere11-system-sync-groups.json'))
intervals=sorted((r['start'],r['start']+r['duration']) for rs in g.values() for r in rs)
merged=[]
for a,b in intervals:
 if merged and a<=merged[-1][1]:merged[-1][1]=max(b,merged[-1][1])
 else:merged.append([a,b])
blocked=sum(max(0,min(b,r['start']+r['duration'])-max(a,r['start'])) for a,b in merged for r in m.main['thread-state'] if r['state']=='Blocked')
print('\nALL_SYNC_UNION_MS',sum(b-a for a,b in merged)/1e6,'BLOCKED_INSIDE_MS',blocked/1e6)
print('STATE_RANGE',min(r['start'] for r in m.main['thread-state'])/1e9,max(r['start']+r['duration'] for r in m.main['thread-state'])/1e9)
for filename in ['woop-build11-lisere-b-complet-vol.jsonl','woop-build11-native-pose0-vol.jsonl']:
 try:
  rows=[json.loads(line) for line in (m.P/filename).read_text().splitlines() if line.strip()]
  print('VOL',filename,'count',len(rows))
  print(rows[:1]);print(rows[-3:])
 except Exception as e:print(e)
