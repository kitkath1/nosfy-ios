#!/usr/bin/env python3
"""Simulation déterministe du contrat6/8ouvertures et2/3séances, sans serveur."""
from pathlib import Path
import json,random,collections,statistics
R=Path(__file__).resolve().parents[2];rng=random.Random(18092026)
catalogue=json.loads((R/'tools/carte-lune/familles-2026-09-18.json').read_text())
pool=collections.defaultdict(list)
for f in catalogue['families']:
 for c in f['cards']:pool[c['rarity']].append(f['key']+'/'+c['key'])
out=[]
for packs in [1,2,3,5]:
 for black in [False,True]:
  rates=collections.Counter();premiere=[];intervalles=[];complet=[];nouvelles=[]
  for player in range(2000):
   owned=set();seenLegend=False;opens=0;since=0;common=0;lastSession=0;first=None;last=None
   for session in range(1,201):
    for idx in range(packs+int(black and session%7==0)):
     noir=idx==packs
     if noir or since+1 >= (8 if seenLegend else 6) or session-lastSession >= (3 if seenLegend else 2):rarity='legendary'
     else:
      roll=rng.random()
      if opens==0 or common>=2:roll=.45+roll*.55
      rarity='common' if roll<.45 else 'rare' if roll<.80 else 'epic' if roll<.95 else 'legendary'
     rates[rarity]+=1
     candidates=pool[rarity]
     if rarity=='legendary':candidates=[c for c in candidates if c not in owned] or candidates
     owned.add(rng.choice(candidates))
     if not noir:opens+=1
     if rarity=='legendary':
      since=0;seenLegend=True;lastSession=session
      if first is None:first=session;premiere.append(first)
      if last is not None:intervalles.append(session-last)
      last=session
     elif not noir:since+=1
     if not noir:common=common+1 if rarity=='common' else 0
     assert common<=2 and since<8
    if session==3:nouvelles.append(len(owned))
    if len(owned)==14:complet.append(session);break
   assert first<=2
  def stats(xs):return {'mediane':statistics.median(xs),'p95':sorted(xs)[int(.95*(len(xs)-1))],'maximum':max(xs)}
  out.append({'boosters_par_seance':packs,'noir_toutes_7_seances':black,'joueurs':2000,
   'premiere_legendaire_seances':stats(premiere),'ecart_legendaire_seances':stats(intervalles),
   'catalogue_complet_seances':stats(complet),'complet_avant_200':len(complet),
   'decouvertes_apres_3_seances_moyenne':statistics.mean(nouvelles),
   'taux_effectifs':{k:round(v/sum(rates.values()),5) for k,v in rates.items()}})
(R/'tools/carte-lune/integration-2026-09-18/rythme-simule.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(out,ensure_ascii=False,indent=2))
