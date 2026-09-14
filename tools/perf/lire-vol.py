#!/usr/bin/env python3
"""LA LECTURE D'UNE MANCHE DE LA SONDE (skill woop-performance) — jamais un chiffre nu.

  lire-vol.py <vol.jsonl> [chauffe=15]   → la médiane des secondes t > chauffe, gel == 0 :
                                            (img/s, pire ms, cpu %, therm, n), + la preuve de
                                            l'écran (onglet, séance) et le therm de départ.
                                            Écrit <vol>.verdict (JSON) à côté.
  lire-vol.py --bilan <dossier>          → toutes les manches du dossier, par barreau.
"""
import json, os, statistics, sys


def lire(chemin):
    lignes = []
    with open(chemin) as f:
        for l in f:
            l = l.strip()
            if not l:
                continue
            try:
                lignes.append(json.loads(l))
            except json.JSONDecodeError:
                pass
    return lignes


def verdict(chemin, chauffe=15):
    L = lire(chemin)
    if not L:
        return None
    depart = L[0]
    utiles = [x for x in L if x.get('t', 0) > chauffe and not x.get('gel', 0)]
    if not utiles:
        return {'fichier': os.path.basename(chemin), 'n': 0, 'therm_depart': depart.get('therm', -1)}
    med = lambda k: statistics.median(x[k] for x in utiles if k in x)
    onglets = sorted({x.get('onglet', '?') for x in utiles})
    v = {
        'fichier': os.path.basename(chemin),
        'n': len(utiles),
        'img': round(med('img'), 1),
        'pire_ms': round(med('pire')),
        'pire_max_ms': round(max(x['pire'] for x in utiles)),
        'cpu': round(med('cpu')),
        'therm': round(med('therm')),
        'therm_depart': depart.get('therm', -1),
        'therm_max': max(x.get('therm', 0) for x in utiles),
        'onglet': ','.join(onglets),
        'seance': max(x.get('seance', 0) for x in utiles),
        'marques': sum(x.get('marque', 0) for x in L),
        'tics': [round(statistics.median(x['tics'][i] for x in utiles)) for i in range(5)] if utiles and 'tics' in utiles[0] else [],
    }
    return v


def dire(v):
    if not v or not v.get('n'):
        print('   ✗ rien d\'utile dans %s (therm départ %s)' % (v and v['fichier'], v and v.get('therm_depart')))
        return
    print('   %-14s %5.1f img/s · pire %4d ms (max %4d) · cpu %3d %% · therm %d (départ %d, max %d) · n=%d · écran %s%s · tics %s' % (
        v['fichier'], v['img'], v['pire_ms'], v['pire_max_ms'], v['cpu'], v['therm'], v['therm_depart'], v['therm_max'],
        v['n'], v['onglet'], ' EN SÉANCE' if v['seance'] else '', v['tics']))
    if v['onglet'] != 'home':
        print('   ⚠️ l\'écran mesuré n\'est pas la home seule (%s) — piège n° 2 du skill' % v['onglet'])


if __name__ == '__main__':
    if len(sys.argv) >= 3 and sys.argv[1] == '--bilan':
        dossier = sys.argv[2]
        par = {}
        for f in sorted(os.listdir(dossier)):
            if f.endswith('.jsonl'):
                v = verdict(os.path.join(dossier, f))
                nom = f.split('-', 1)[1].rsplit('.', 1)[0] if '-' in f else f
                par.setdefault(nom, []).append(v)
                dire(v)
        print('── par barreau (médiane des manches)')
        for nom, vs in par.items():
            vs = [v for v in vs if v and v.get('n')]
            if not vs:
                continue
            print('   %s : %5.1f img/s · pire %4d ms · cpu %3d %% · %d manche(s)' % (
                nom, statistics.median(v['img'] for v in vs), statistics.median(v['pire_ms'] for v in vs),
                statistics.median(v['cpu'] for v in vs), len(vs)))
        sys.exit(0)
    chemin = sys.argv[1]
    chauffe = float(sys.argv[2]) if len(sys.argv) > 2 else 15
    v = verdict(chemin, chauffe)
    dire(v)
    if v:
        with open(chemin.rsplit('.', 1)[0] + '.verdict', 'w') as f:
            json.dump(v, f, indent=1)
