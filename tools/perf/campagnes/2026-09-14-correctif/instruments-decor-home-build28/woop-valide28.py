from pathlib import Path
import subprocess, time, json, datetime, plistlib
out=Path('/private/tmp/woop-validation28'); out.mkdir(exist_ok=True)
core='022244AD-484B-5489-A884-6B781A82E372'; udid='00008120-001E4CDC0A85A01E'; bundle='fr.kathryn.woop'
app=Path('/private/tmp/woop-chauffe-dd/Build/Products/Release-iphoneos/Woop.app')
info=plistlib.loads((app/'Info.plist').read_bytes()); assert info['CFBundleVersion']=='28', info['CFBundleVersion']
events=[]
def run(name,cmd,timeout=55):
 print(datetime.datetime.now().isoformat(), name, flush=True)
 begin=time.monotonic()
 with (out/(name+'.log')).open('w') as f:
  try: result=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=timeout); rc=result.returncode
  except subprocess.TimeoutExpired: rc=124
 events.append({'nom':name,'commande':cmd,'code':rc,'duree_s':round(time.monotonic()-begin,3),'fin':datetime.datetime.now().isoformat()})
 (out/'etapes.json').write_text(json.dumps(events,ensure_ascii=False,indent=2))
 print(name,rc,flush=True)
 if rc: raise RuntimeError(name+' '+str(rc))
def launch(name,diagnostic=False):
 flags=['-sansSondeVol','-ecranEveille','-navProbe','-openTab','home']
 if diagnostic: flags+=['-sansProtectionThermique']
 run(name,['xcrun','devicectl','device','process','launch','--terminate-existing','--device',core,'--timeout','20',bundle,'--']+flags,35)
def ui(name,test):
 run(name,['xcodebuild','test-without-building','-xctestrun','/private/tmp/woop-nav-runtime-qa/dd/Build/Products/NavRuntimeUITests_iphoneos26.5-arm64.xctestrun','-only-testing:NavRuntimeUITests/NavRuntimeUITests/'+test,'-destination','platform=iOS,id='+udid,'-destination-timeout','15','-parallel-testing-enabled','NO','-maximum-concurrent-test-device-destinations','1','-resultBundlePath',str(out/(name+'.xcresult'))],70)
run('installation',['xcrun','devicectl','device','install','app','--device',core,'--timeout','30',str(app)],45)
mesure_erreur=None
before=time.monotonic(); launch('home-mesure',True)
try:
 ui('home-prete','testHomePretePourMesure')
 assert time.monotonic()-before<36, 'Délai de protection insuffisant pour une trace valide'
 run('power',['xcrun','xctrace','record','--template','Power Profiler','--device',udid,'--attach','Woop','--time-limit','15s','--output',str(out/'home28.trace')],40)
except Exception as exc:
 mesure_erreur=str(exc); print('Mesure incomplète:',mesure_erreur,flush=True)
finally:
 launch('retour-protection')
ui('navigation','testNavigationApresRelance')
launch('home-finale')
run('nav-final',['python3','/private/tmp/woop-collect-id22.py','woop-validation28','--nav-only'],60)
if mesure_erreur:
 (out/'mesure-erreur.txt').write_text(mesure_erreur)
 raise SystemExit('Navigation vérifiée, mesure non validée : '+mesure_erreur)
run('toc',['xcrun','xctrace','export','--input',str(out/'home28.trace'),'--toc','--output',str(out/'home28-toc.xml')],30)
schemas=['ProcessSubsystemPowerImpact','SystemPowerLevel','device-thermal-state-intervals','metal-perf-overview-process-metric','DeviceChargingState','time-profile','life-cycle-period']
xpath='/trace-toc/run[@number="1"]/data/table['+' or '.join('@schema="'+s+'"' for s in schemas)+']'
run('export',['xcrun','xctrace','export','--input',str(out/'home28.trace'),'--xpath',xpath,'--output',str(out/'home28-mesures.xml')],45)
run('analyse',['python3','/private/tmp/woop-analyse-power.py',str(out/'home28')],30)
print((out/'analyse.log').read_text(),flush=True)
