import subprocess,json,time
from pathlib import Path
base=Path('/private/tmp');device='022244AD-484B-5489-A884-6B781A82E372';udid='00008120-001E4CDC0A85A01E';manifest=[]
def run(tag,args,timeout=100):
 with open(base/(tag+'.log'),'w') as f:subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,check=True,timeout=timeout)
def launch(tag,extra):
 run(tag+'-launch',['xcrun','devicectl','device','process','launch','--terminate-existing','--device',device,'--timeout','12','fr.kathryn.woop','--','-sondeVol','-ecranEveille','-navProbe']+extra)
def test(tag,method):
 run(tag+'-test',['xcodebuild','test-without-building','-xctestrun','/private/tmp/woop-nav-runtime-qa/dd/Build/Products/NavRuntimeUITests_iphoneos26.5-arm64.xctestrun','-only-testing:NavRuntimeUITests/NavRuntimeUITests/'+method,'-destination','platform=iOS,id='+udid,'-destination-timeout','15','-parallel-testing-enabled','NO','-resultBundlePath',str(base/(tag+'.xcresult'))])
def collect(tag):
 run(tag+'-collect',['python3','/private/tmp/woop-collect-id22.py',tag,'--nav']);r=[json.loads(x) for x in open(base/(tag+'-vol.jsonl'))];print(tag,r[-1],flush=True);return r[-1]
for label,extra in [('ancien',['-profilDanseSwiftUI']),('native2',[])]:
 tag='woop-parole40-'+label
 launch(tag,['-openTab','profile','-profilTirage']+extra)
 test(tag,'testPanneauProfilPret')
 debut=collect(tag+'-debut');manifest.append({'tag':tag,'debut_stable':debut['t']+5})
 if debut['therm']>=2:print('Stress suspendu : thermique >=2',flush=True);break
 time.sleep(35)
 fin=collect(tag)
 if fin['therm']>=2:print('Stress suspendu : thermique >=2',flush=True);break
(base/'woop-parole40-comparaison-fenetres.json').write_text(json.dumps(manifest,indent=2))
launch('woop-parole40-noire',['-openTab','home','-homeSeance'])
test('woop-parole40-noire-prete','testHomePretePourMesure')
collect('woop-parole40-noire-debut')
print('Home noire ouverte, aucune séance réelle créée.',flush=True)
