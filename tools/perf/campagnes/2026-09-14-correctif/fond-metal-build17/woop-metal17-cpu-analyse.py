from pathlib import Path
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
import json
p=Path('/private/tmp/woop-metal17-cpu-time-profile.xml')
root=ET.parse(p).getroot()
ids={}
for e in root.iter():
    if 'id' in e.attrib:
        assert e.attrib['id'] not in ids, ('duplicate',e.attrib['id'])
        ids[e.attrib['id']]=e
refs=Counter()
def resolve(e):
    if e is None:return None
    while 'ref' in e.attrib:
        refs[e.tag]+=1
        e=ids[e.attrib['ref']]
    return e
samples=[]
for row in root.iter('row'):
    col={e.tag:resolve(e) for e in row}
    thread=col['thread']
    proc=col['process']
    tagged=col.get('tagged-backtrace')
    stack=resolve(tagged.find('backtrace')) if tagged is not None else None
    fs=[]
    if stack is not None:
        for rf in stack:
            f=resolve(rf)
            binary=resolve(f.find('binary'))
            fs.append({'address':f.get('addr'),'name':f.get('name'),'binary':binary.get('name') if binary is not None else '?','binary_meta':binary.attrib if binary is not None else {}})
    samples.append({'time':int(col['sample-time'].text),'thread':thread.get('fmt'),'tid':int(resolve(thread.find('tid')).text),'pid':int(resolve(proc.find('pid')).text),'weight':int(col['weight'].text),'state':col['thread-state'].text,'core':col['core'].get('fmt'),'frames':fs})

def stats(ss):
    weight=sum(s['weight'] for s in ss)
    leaf=Counter();incl=Counter();leaf_frames=Counter();incl_frames=Counter();threads=Counter()
    for s in ss:
        w=s['weight']; fs=s['frames']; threads[s['thread']]+=w
        if fs:
            leaf[fs[0]['binary']]+=w
            leaf_frames[(fs[0]['binary'],fs[0]['address'],fs[0]['name'])]+=w
        for b in {f['binary'] for f in fs}:incl[b]+=w
        for f in {(f['binary'],f['address'],f['name']) for f in fs}:incl_frames[f]+=w
    def top(c,n=20):return [(k,round(v/1e6,3),round(v/weight*100,3)) for k,v in c.most_common(n)]
    return {'count':len(ss),'weight_ms':weight/1e6,'leaf':top(leaf),'inclusive':top(incl),'leaf_frames':top(leaf_frames),'inclusive_frames':top(incl_frames),'threads':top(threads,100)}
main=[s for s in samples if s['thread'].startswith('Main Thread')]
workers=[s for s in samples if not s['thread'].startswith('Main Thread')]
meta={'input':str(p),'rows':len(samples),'ids':len(ids),'references_resolved':dict(refs),'processes':dict(Counter(s['pid'] for s in samples)),'states':dict(Counter(s['state'] for s in samples)),'weight_distribution_ns':dict(Counter(s['weight'] for s in samples)),'first_time_s':min(s['time'] for s in samples)/1e9,'last_time_s':max(s['time'] for s in samples)/1e9,'cores':dict(Counter(s['core'] for s in samples)),'total':stats(samples),'main':stats(main),'workers':stats(workers)}
app_frames=Counter()
for s in samples:
    for f in {(f['address'],f['name']) for f in s['frames'] if f['binary']=='Woop'}:app_frames[f]+=s['weight']
meta['app_frames']=[(k,v/1e6) for k,v in app_frames.most_common()]
meta['app_leaf_count']=sum(bool(s['frames']) and s['frames'][0]['binary']=='Woop' for s in samples)
meta['symbolicated_frame_occurrences']=sum(not f['name'].startswith('0x') for s in samples for f in s['frames'])
Path('/private/tmp/woop-metal17-cpu-analysis.json').write_text(json.dumps(meta,indent=2))
Path('/private/tmp/woop-metal17-cpu-resolved-samples.json').write_text(json.dumps(samples))
print(json.dumps(meta,indent=2))
