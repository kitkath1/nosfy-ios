import xml.etree.ElementTree as E
from pathlib import Path
from collections import Counter,defaultdict
import json
P=Path('/private/tmp')
def parse(schema):
 root=E.parse(P/f'woop-home15-sans-sonde-system-{schema}.xml').getroot()
 ids={n.attrib['id']:n for n in root.iter() if 'id' in n.attrib}
 def resolve(n):
  while n is not None and 'ref' in n.attrib: n=ids[n.attrib['ref']]
  return n
 def value(n):
  n=resolve(n)
  if n is None or n.tag=='sentinel':return None
  return n.text or n.attrib.get('fmt')
 def fmt(n):
  n=resolve(n)
  return None if n is None or n.tag=='sentinel' else n.attrib.get('fmt',n.text)
 def stack(n):
  n=resolve(n)
  if n is None or n.tag=='sentinel':return []
  trace=resolve(n.find('backtrace')) if n.tag!='backtrace' else n
  if trace is None:return []
  out=[]
  for f in trace:
   f=resolve(f)
   b=resolve(f.find('binary'))
   out.append({'name':f.get('name'),'addr':f.get('addr'),'binary':b.get('name') if b is not None else None})
  return out
 cols=[n.findtext('mnemonic') for n in root.findall('.//schema/col')]
 rows=[]
 for row in root.findall('.//row'):
  d={k:value(n) for k,n in zip(cols,row)}
  for k,n in zip(cols,row):
   if k in ('thread','process','call','note','summary','narrative','state','hang-type'):d[k]=fmt(n)
   if k=='backtrace':d[k]=stack(n)
  for k in ['start','duration','cputime','waittime','timestamp']:
   if d.get(k) is not None:d[k]=int(d[k])
  rows.append(d)
 return rows
allrows={k:parse(k) for k in ['thread-state','thread-narrative','syscall','potential-hangs']}
main={k:[r for r in rs if 'Main Thread (' in (r.get('thread') or '') and '(Woop, pid: 18446)' in (r.get('thread') or '')] for k,rs in allrows.items()}
result={'row_counts':{k:len(rs) for k,rs in allrows.items()},'main_counts':{k:len(rs) for k,rs in main.items()},'hangs':main['potential-hangs']}
print(json.dumps(result,indent=2))
for schema in ['thread-state','thread-narrative','syscall']:
 rs=main[schema]
 print('\nTABLE',schema,'FIRST/LAST',min(r['start'] for r in rs)/1e9,max(r['start']+r['duration'] for r in rs)/1e9)
 if schema=='thread-state':
  counter=Counter()
  for r in rs:counter[r['state']]+=r['duration']
  result['main_state_ns']=counter
  print('STATE TOTALS',json.dumps(counter))
 print('LONGEST')
 top=sorted(rs,key=lambda r:r['duration'],reverse=True)[:18]
 result[f'{schema}_longest']=top
 for r in top:
  print(json.dumps(r))
print('\nHANG OVERLAPS')
for h in main['potential-hangs']:
 a=h['start'];b=a+h['duration'];states=Counter();calls=[];narr=[]
 for r in main['thread-state']:
  overlap=max(0,min(b,r['start']+r['duration'])-max(a,r['start']))
  if overlap:states[r['state']]+=overlap
 for r in main['syscall']:
  overlap=max(0,min(b,r['start']+r['duration'])-max(a,r['start']))
  if overlap:calls.append({**r,'overlap_ns':overlap})
 for r in main['thread-narrative']:
  overlap=max(0,min(b,r['start']+r['duration'])-max(a,r['start']))
  if overlap>1e6:narr.append({**r,'overlap_ns':overlap})
 h['state_overlap_ns']=states
 h['syscalls']=sorted(calls,key=lambda r:r['overlap_ns'],reverse=True)[:8]
 h['narratives']=narr
 print(json.dumps(h))
(P/'woop-home15-sans-sonde-system-analysis.json').write_text(json.dumps(result,indent=2))
(P/'woop-home15-sans-sonde-system-main-resolved.json').write_text(json.dumps(main,indent=2))
