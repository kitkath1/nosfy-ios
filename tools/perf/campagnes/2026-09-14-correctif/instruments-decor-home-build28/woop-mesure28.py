from pathlib import Path
src=Path('/private/tmp/woop-valide28.py').read_text().split("run('installation'")[0]
exec(src.replace("Path('/private/tmp/woop-validation28')", "Path('/private/tmp/woop-validation28-mesure')"))
before=time.monotonic(); launch('home-mesure',True)
try:
 ui('home-prete','testHomePretePourMesure')
 assert time.monotonic()-before<36, 'Délai insuffisant pour la capture'
 run('power',['xcrun','xctrace','record','--template','Power Profiler','--device',udid,'--attach','Woop','--time-limit','15s','--output',str(out/'home28.trace')],40)
 run('nav-mesure',['python3','/private/tmp/woop-collect-id22.py','woop-validation28-mesure','--nav-only'],30)
finally:
 launch('home-finale-protegee')
run('toc',['xcrun','xctrace','export','--input',str(out/'home28.trace'),'--toc','--output',str(out/'home28-toc.xml')],30)
schemas=['ProcessSubsystemPowerImpact','SystemPowerLevel','device-thermal-state-intervals','metal-perf-overview-process-metric','DeviceChargingState','time-profile','life-cycle-period']
xpath='/trace-toc/run[@number="1"]/data/table['+' or '.join('@schema="'+s+'"' for s in schemas)+']'
run('export',['xcrun','xctrace','export','--input',str(out/'home28.trace'),'--xpath',xpath,'--output',str(out/'home28-mesures.xml')],45)
run('analyse',['python3','/private/tmp/woop-analyse-power.py',str(out/'home28')],30)
print((out/'analyse.log').read_text(),flush=True)
