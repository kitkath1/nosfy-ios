import json, pathlib, subprocess, sys, time
appareil, journal = sys.argv[1:3]
base = pathlib.Path('/tmp/woop-story-session-ile')
fichier = base/'vol-watch.jsonl'
precedent = None
sans_battement = 0

def arreter(raison):
    p = base/'watch-processes.json'
    subprocess.run(['xcrun','devicectl','device','info','processes','--device',appareil,'--json-output',str(p)], check=True, stdout=subprocess.DEVNULL, timeout=15)
    for a in json.loads(p.read_text())['result']['runningProcesses']:
        if a.get('executable','').endswith('/Woop.app/Woop'):
            print('ARRET', raison, 'pid', a['processIdentifier'], flush=True)
            subprocess.run(['xcrun','devicectl','device','process','terminate','--device',appareil,'--pid',str(a['processIdentifier'])], check=True, timeout=15)
            return
    print('App déjà terminée : surveillance finie.', flush=True)

for _ in range(48):
    subprocess.run(['xcrun','devicectl','device','copy','from','--device',appareil,'--domain-type','appDataContainer','--domain-identifier','fr.kathryn.woop','--source','Documents/'+journal,'--destination',str(fichier)], check=True, stdout=subprocess.DEVNULL, timeout=15)
    lignes=[]
    for l in fichier.read_text().splitlines():
        try: lignes.append(json.loads(l))
        except json.JSONDecodeError: pass
    if lignes:
        x=lignes[-1]
        sans_battement = sans_battement + 1 if x['t']==precedent else 0
        precedent=x['t']
        print({k:x[k] for k in ('t','cpu','therm','story','mouvement','chemin')}, flush=True)
        if x['therm'] >= 2:
            arreter('thermique serious/critical');break
        if sans_battement >= 2:
            arreter('sonde sans nouveau battement pendant 20 s');break
    time.sleep(10)
