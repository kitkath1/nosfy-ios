from pathlib import Path
import subprocess, time, json, datetime, plistlib
out=Path('/private/tmp/woop-validation35'); out.mkdir(exist_ok=True)
core='022244AD-484B-5489-A884-6B781A82E372'; udid='00008120-001E4CDC0A85A01E'; bundle='fr.kathryn.woop'
app=Path('/private/tmp/woop-chauffe-dd/Build/Products/Release-iphoneos/Woop.app')
info=plistlib.loads((app/'Info.plist').read_bytes()); assert info['CFBundleVersion']=='35', info['CFBundleVersion']
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
try:
 run('home-mesure',['xcrun','devicectl','device','process','launch','--terminate-existing','--device',core,'--timeout','20',bundle,'--','-sondeVol','-ecranEveille','-navProbe','-sondeAnimations','-openTab','home'],35)
 for i in range(3):
  time.sleep(30)
  if i in (0,2):
   run('collecte-'+str(i),['python3','/private/tmp/woop-collect-id22.py','woop-home35-'+str(i),'--nav'],35)
   print((out/('collecte-'+str(i)+'.log')).read_text()[:1100],flush=True)
finally:
 launch('home-sans-sonde')
ui('pull-chapitre','testRetourPullEtChapitre')
run('collecte-pull',['python3','/private/tmp/woop-collect-id22.py','woop-pull35','--nav-only'],35)
launch('home-avant-navigation')
ui('navigation','testNavigationApresRelance')
launch('home-finale')
