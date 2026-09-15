import xml.etree.ElementTree as E
from collections import Counter
import sys
ids={}; cn=Counter(); tm=Counter(); total=0
for event,e in E.iterparse(sys.argv[1], events=['end']):
 if e.get('id') and e.tag in ['start-time','duration','string','thread','swiftui-update']:
  ids[e.get('id')]=(e.get('fmt') or '',e.text or '')
 if e.tag!='row':continue
 def get(i,raw=False):
  v=e[i]
  a=ids[v.get('ref')] if v.get('ref') else (v.get('fmt') or '',v.text or '')
  return a[1] if raw else a[0]
 t=float(get(0,True))/1e9
 if t>float(sys.argv[2]):
  k=(get(3),get(9),get(5)); cn[k]+=1;tm[k]+=float(get(1,True))/1e6;total+=1
 e.clear()
print('updates',total,'after',sys.argv[2])
for k,n in cn.most_common(65):print(n,round(tm[k],2),'ms',k)
