import subprocess,time,json,pathlib,datetime
base=pathlib.Path('/private/tmp');qa=base/'woop-nav-runtime-qa';device='iPhone de Frédéric';udid='00008120-001E4CDC0A85A01E'
run=datetime.datetime.now().strftime('%H%M%S')

def command(args,**kwargs):
 return subprocess.run(args,check=True,timeout=kwargs.pop('timeout',40),**kwargs)
def launch(flags):
 command(['xcrun','devicectl','device','process','launch','--device',device,'--terminate-existing','--timeout','20','fr.kathryn.woop','--']+flags)
def test(label,name):
 with open(qa/f'test22-{label}-{run}.log','w') as f:
  command(['xcodebuild','test-without-building','-xctestrun',str(qa/'dd/Build/Products/NavRuntimeUITests_iphoneos26.5-arm64.xctestrun'),'-only-testing:NavRuntimeUITests/NavRuntimeUITests/'+name,'-destination',f'platform=iOS,id={udid}','-destination-timeout','30','-parallel-testing-enabled','NO','-maximum-concurrent-test-device-destinations','1','-resultBundlePath',str(qa/f'result22-{label}-{run}.xcresult')],stdout=f,stderr=subprocess.STDOUT,timeout=90)
def collect(label):
 command(['python3',str(base/'woop-collect-nom.py'),label,'--nav-only'],timeout=20)
 return [json.loads(l) for l in (base/(label+'-nav.jsonl')).read_text().splitlines()]
try:
 for label,extra in [('reference',['-fondDeuxLecteurs']),('precompose',[])]:
  prefix=f'woop-home22-{label}-{run}'
  launch(['-sansSondeVol','-ecranEveille','-navProbe','-sansProtectionThermique','-openTab','home']+extra)
  start=time.monotonic();time.sleep(3);test(label,'testHomePretePourMesure')
  rows=collect(prefix+'-avant')
  if label=='precompose':
   assert any(r['evenement']=='fond-precompose' for r in rows),'Fond unique non monté : arrêt de la comparaison'
   assert not any(r['evenement']=='fond-precompose-repli' for r in rows),'Taille non prévue : arrêt de la comparaison'
  command(['xcrun','devicectl','device','copy','from','--device',device,'--domain-type','appDataContainer','--domain-identifier','fr.kathryn.woop.NavRuntimeUITests.xctrunner','--user','mobile','--source','Documents/home-mesure.png','--destination',str(base/(prefix+'.png'))],stdout=subprocess.DEVNULL,timeout=20)
  time.sleep(max(0,20-(time.monotonic()-start)))
  p=base/(prefix+'-processes.json')
  command(['xcrun','devicectl','device','info','processes','--device',device,'--json-output',str(p)],stdout=subprocess.DEVNULL,timeout=20)
  pid=next(p['processIdentifier'] for p in json.load(open(p))['result']['runningProcesses'] if p.get('executable','').endswith('/Woop'))
  print('TRACE',prefix,pid,flush=True)
  with open(base/(prefix+'-cpu.log'),'w') as f:
   command(['xcrun','xctrace','record','--template','Time Profiler','--device',udid,'--attach',str(pid),'--time-limit','12s','--output',str(base/(prefix+'-cpu.trace'))],stdout=f,stderr=subprocess.STDOUT,timeout=180)
  collect(prefix+'-apres')
  if label=='precompose':
   test('precompose-apres','testHomePretePourMesure')
   command(['xcrun','devicectl','device','copy','from','--device',device,'--domain-type','appDataContainer','--domain-identifier','fr.kathryn.woop.NavRuntimeUITests.xctrunner','--user','mobile','--source','Documents/home-mesure.png','--destination',str(base/(prefix+'-apres.png'))],stdout=subprocess.DEVNULL,timeout=20)
   test('navigation','testNavigationApresRelance')
finally:
 # Rendu protégé et sonde éteinte ; maintien de veille demandé pour la QA.
 launch(['-sansSondeVol','-ecranEveille','-navProbe','-openTab','home'])
 print('RESTAURATION PROTECTION ET VEILLE QA OK',run,flush=True)
