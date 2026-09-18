#!/usr/bin/env python3
"""Résumé des samples CPU Running de Time Profiler, pas de mesure d'énergie."""
import argparse
from collections import Counter
import json
from pathlib import Path
import xml.etree.ElementTree as ET
p = argparse.ArgumentParser()
p.add_argument('samples', type=Path)
p.add_argument('toc', type=Path)
a = p.parse_args()
r = ET.parse(a.samples).getroot()
ids = {e.get('id'): e for e in r.iter() if e.get('id')}
def resolve(e):
    while e is not None and e.get('ref'):
        e = ids[e.get('ref')]
    return e
weights = Counter()
for row in r.iter('row'):
    fields = {e.tag: resolve(e) for e in row}
    state = fields.get('thread-state')
    if state is None or state.get('fmt') != 'Running':
        continue
    weights[fields['process'].get('fmt')] += int(fields['weight'].text)
toc = ET.parse(a.toc).getroot()
duration = float(toc.findtext('.//run/info/summary/duration'))
print(json.dumps({
    'debut': toc.findtext('.//run/info/summary/start-date'),
    'duree_trace_s': duration,
    'cpu_running': [
        {'processus': name, 'poids_ms': weight / 1e6,
         'equivalent_pct_un_coeur': round(weight / (duration * 1e9) * 100, 2)}
        for name, weight in weights.most_common()
    ],
    'limite': 'Samples statistiques Running ; aucune mesure de watts ou de température.'
}, ensure_ascii=False, indent=2))
