import xml.etree.ElementTree as ET
from pathlib import Path
from collections import Counter,defaultdict
import json, statistics

def parse(path):
    root=ET.parse(path).getroot()
    ids={}
    for e in root.iter():
        if 'id' in e.attrib:
            assert e.attrib['id'] not in ids, e.attrib['id']
            ids[e.attrib['id']]=e
    def resolve(e):
        while 'ref' in e.attrib:e=ids[e.attrib['ref']]
        return e
    def val(e):
        e=resolve(e)
        if e.tag=='sentinel':return None
        t=(e.text or '').strip()
        return t if len(e)==0 else e.get('fmt',t)
    out={}
    for node in root.findall('node'):
        schema=node.find('schema')
        if schema is None:
            print('NO_SCHEMA_NODE',node.attrib,'rows',len(node.findall('row')))
            continue
        cols=[c.findtext('mnemonic') for c in schema.findall('col')]
        rows=[]
        for row in node.findall('row'):
            assert len(row)==len(cols),(schema.get('name'),len(row),len(cols))
            rows.append(dict(zip(cols,map(val,row))))
        out[schema.get('name')]={'columns':cols,'rows':rows}
    return out

def union(intervals):
    total=0; left=right=None
    for s,e in sorted(intervals):
        if right is None:left,right=s,e
        elif s<=right:right=max(right,e)
        else:total+=right-left;left,right=s,e
    return total+(right-left if right is not None else 0)

def descr(values,scale=1e6):
    a=sorted(float(x)/scale for x in values if x is not None)
    if not a:return {'n':0}
    return {'n':len(a),'sum':sum(a),'min':a[0],'median':statistics.median(a),'p95':a[min(len(a)-1,int(.95*len(a)))],'p99':a[min(len(a)-1,int(.99*len(a)))],'max':a[-1]}

if __name__=='__main__':
    for part in ['gpu-intervals','display-waits']:
        data=parse('/private/tmp/woop-metal8-'+part+'.xml')
        Path('/private/tmp/woop-metal8-'+part+'.json').write_text(json.dumps(data))
        for name,table in data.items():
            rs=table['rows']; print('\nTABLE',name,'rows',len(rs),'columns',table['columns'])
            for key in ['state','process','channel-name','event-depth','category','display-name','direct-to-display','event-label']:
                if key in table['columns']:
                    c=Counter(r[key] for r in rs); print(key,'unique',len(c),'top',c.most_common(12))
            if 'duration' in table['columns']: print('duration_ms',descr([r['duration'] for r in rs]))
            for key in ['start-latency','cpu-to-display-latency']:
                if key in table['columns']:print(key,descr([r[key] for r in rs]))
