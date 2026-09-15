import xml.etree.ElementTree as E
import sys
ids={}; vals={}; n=0; seen=set()
for event,e in E.iterparse(sys.argv[1], events=['end']):
 if e.get('id') and e.tag in ['start-time','duration','string','thread','swiftui-update']:
  vals[e.get('id')]=(e.get('fmt') or '',e.text or '')
 if e.tag=='view-hierarchy' and e.get('id'):ids[e.get('id')]=E.tostring(e,encoding='unicode')
 if e.tag!='row':continue
 def get(i,raw=False):
  v=e[i];a=vals[v.get('ref')] if v.get('ref') else (v.get('fmt') or '',v.text or '')
  return a[1] if raw else a[0]
 if float(get(0,True))>25e9 and ('AnimatableAttribute<_RotationEffect>' in get(5) or 'UpdateFilter' in get(5)):
  h=ids.get(e[7].get('ref') or e[7].get('id')); fmt=E.fromstring(h).get('fmt')
  if fmt not in seen:
   seen.add(fmt);print(get(0),get(5),get(9));print(fmt);n+=1
  if n>=8:break
 e.clear()
