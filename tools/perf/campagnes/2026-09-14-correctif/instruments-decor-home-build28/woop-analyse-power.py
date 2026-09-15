from pathlib import Path
import json
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict

prefix = Path(sys.argv[1])
toc = ET.parse(str(prefix) + '-toc.xml').getroot()
root = ET.parse(str(prefix) + '-mesures.xml').getroot()
schemas = {i + 1: e.get('schema') for i, e in enumerate(toc.findall('.//run/data/table'))}
ids = {e.get('id'): e for e in root.iter() if e.get('id')}
duration = float(toc.findtext('.//summary/duration'))

def resolve(e):
    while e is not None and e.get('ref'):
        e = ids[e.get('ref')]
    return e

nodes = {}
for node in root.findall('node'):
    index = int(re.search(r'table\[(\d+)\]$', node.get('xpath')).group(1))
    nodes[schemas[index]] = node

result = {'trace': str(prefix), 'debut': toc.findtext('.//summary/start-date'),
          'fin': toc.findtext('.//summary/end-date'), 'duree_s': duration,
          'fin_raison': toc.findtext('.//summary/end-reason'),
          'lignes': {s: len(n.findall('row')) for s, n in nodes.items()}}

result['thermique'] = [resolve(e).text for r in nodes['device-thermal-state-intervals'].findall('row')
                      for e in r if e.tag == 'thermal-state']
process = defaultdict(list)
for row in nodes['metal-perf-overview-process-metric'].findall('row'):
    cols = {e.tag: resolve(e) for e in row}
    process[cols['metal-performance-overview-process-metric-name'].text].append(
        (float(cols['fixed-decimal'].text), float(cols['duration'].text) / 1e9))
result['metriques_processus'] = {name: sum(v * w for v, w in values) / sum(w for _, w in values)
                               for name, values in process.items() if sum(w for _, w in values)}

weight = 0
main_weight = 0
leaf = Counter()
main_frames = Counter()
samples = 0
for row in nodes['time-profile'].findall('row'):
    cols = {e.tag: resolve(e) for e in row}
    if cols['thread-state'].text != 'Running' or float(cols['sample-time'].text) < 4e9:
        continue
    w = int(cols['weight'].text)
    samples += 1
    weight += w
    main = cols['thread'].get('fmt', '').startswith('Main Thread')
    if main:
        main_weight += w
    tagged = cols.get('tagged-backtrace')
    stack = resolve(tagged.find('backtrace')) if tagged is not None else None
    if stack is not None:
        frames = [resolve(f) for f in stack]
        if frames:
            binary = resolve(frames[0].find('binary'))
            leaf[binary.get('name') if binary is not None else '?'] += w
        if main:
            for name in {f.get('name', '?') for f in frames}:
                main_frames[name] += w
result['cpu_apres_4s'] = {'n': samples, 'poids_ms': weight / 1e6,
                         'pourcent_echantillonne': weight / 1e7 / (duration - 4),
                         'main_pourcent_echantillonne': main_weight / 1e7 / (duration - 4),
                         'bibliotheques_feuille_ms': [(k, v / 1e6) for k, v in leaf.most_common(12)],
                         'piles_main_ms': [(k, v / 1e6) for k, v in main_frames.most_common(35)]}
result['limites'] = ('CPU échantillonné, instructions/s documentées dans la table Apple. '
                     'Ne pas interpréter les colonnes sans nom comme des watts. '
                     'Comparaison thermique et vérification de la Home nécessaires.')
Path(str(prefix) + '-analyse.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
print(json.dumps({k: v for k, v in result.items() if k != 'cpu_apres_4s'}, ensure_ascii=False, indent=2))
print('CPU après4s', result['cpu_apres_4s']['pourcent_echantillonne'])
