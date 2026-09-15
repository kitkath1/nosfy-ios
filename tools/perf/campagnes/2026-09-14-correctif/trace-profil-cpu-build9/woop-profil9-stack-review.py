import json
from collections import Counter,defaultdict
s=json.load(open('/private/tmp/woop-profil9-resolved-samples.json'))

def report(name,ss):
 w=sum(x['weight'] for x in ss)/1e6
 leaf=Counter();inc=Counter();app=Counter();bins=Counter()
 for x in ss:
  fs=x['frames'];v=x['weight']/1e6
  if fs:leaf[(fs[0]['binary'],fs[0]['name'])]+=v
  for k in {(f['binary'],f['name']) for f in fs}:inc[k]+=v
 print('\nGROUP',name,'rows',len(ss),'ms',round(w,3))
 print('LEAF')
 for k,v in leaf.most_common(22):print(round(v,3),round(v/w*100,3),k)
 print('INCLUSIVE (non-root focus)')
 for k,v in inc.most_common():
  if k[0] in ['SwiftUICore','AttributeGraph','SceneKit','SwiftUITracingSupport','Woop','QuartzCore']:
   print(round(v,3),round(v/w*100,3),k)
   if sum(1 for kk,vv in inc.most_common() if vv>=v and kk[0] in ['SwiftUICore','AttributeGraph','SceneKit','SwiftUITracingSupport','Woop','QuartzCore'])>=45:break
 return inc
ss=[x for x in s if x['time']>=1e9]
report('after1_all',ss)
report('after1_main',[x for x in ss if x['thread'].startswith('Main Thread')])
report('after1_AsyncRenderer',[x for x in ss if 'AsyncRenderer' in x['thread']])
scene=[x for x in ss if any(f['binary']=='SceneKit' for f in x['frames'])]
report('after1_SceneKit_paths',scene)
# Representative stacks for recurring producer classes, root to leaf.
for word in ['SceneKit','AsyncRenderer','ViewGraphDisplayLink']:
 hit=[x for x in ss if (word in x['thread'] or any(word in f['binary'] or word in f['name'] for f in x['frames']))]
 counts=Counter(tuple((f['binary'],f['name']) for f in x['frames']) for x in hit)
 print('\nREPRESENTATIVE',word,'total_samples',len(hit))
 for stack,n in counts.most_common(2):
  print('samples',n)
  for f in reversed(stack):print(' ',f)
