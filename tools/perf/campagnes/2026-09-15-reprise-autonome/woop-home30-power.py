from pathlib import Path
src=Path('/private/tmp/woop-valide28.py').read_text().split("run('installation'")[0]
src=src.replace("info['CFBundleVersion']=='28'", "info['CFBundleVersion']=='30'")
exec(src.replace("Path('/private/tmp/woop-validation28')", "Path('/private/tmp/woop-home30-power')"))
run('processus',['xcrun','devicectl','device','info','processes','--device',core,'--timeout','15','--json-output',str(out/'processus.json')],25)
rows=json.loads((out/'processus.json').read_text())['result']['runningProcesses']
pids=[r['processIdentifier'] for r in rows if r.get('executable','').endswith('/Woop.app/Woop')]
assert len(pids)==1,pids
run('power',['xcrun','xctrace','record','--template','Power Profiler','--device',udid,'--attach',str(pids[0]),'--time-limit','15s','--output',str(out/'home30.trace')],90)
run('toc',['xcrun','xctrace','export','--input',str(out/'home30.trace'),'--toc','--output',str(out/'home30-toc.xml')],30)
schemas=['ProcessSubsystemPowerImpact','SystemPowerLevel','device-thermal-state-intervals','metal-perf-overview-process-metric','DeviceChargingState','time-profile','life-cycle-period']
xpath='/trace-toc/run[@number="1"]/data/table['+' or '.join('@schema="'+s+'"' for s in schemas)+']'
run('export',['xcrun','xctrace','export','--input',str(out/'home30.trace'),'--xpath',xpath,'--output',str(out/'home30-mesures.xml')],45)
run('analyse',['python3','/private/tmp/woop-analyse-power.py',str(out/'home30')],30)
print((out/'analyse.log').read_text(),flush=True)
