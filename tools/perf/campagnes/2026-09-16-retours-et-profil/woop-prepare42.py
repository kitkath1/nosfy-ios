import subprocess,json,time
from pathlib import Path
base=Path('/private/tmp');device='022244AD-484B-5489-A884-6B781A82E372';udid='00008120-001E4CDC0A85A01E'
def run(tag,args,timeout=100):
 with open(base/(tag+'.log'),'w') as f:subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,check=True,timeout=timeout)
def launch(tag,extra):
 run(tag+'-launch',['xcrun','devicectl','device','process','launch','--terminate-existing','--device',device,'--timeout','12','fr.kathryn.woop','--','-sondeVol','-ecranEveille','-navProbe','-openTab','home','-homeSeance']+extra)
def test(tag,method):
 run(tag+'-test',['xcodebuild','test-without-building','-xctestrun','/private/tmp/woop-nav-runtime-qa/dd/Build/Products/NavRuntimeUITests_iphoneos26.5-arm64.xctestrun','-only-testing:NavRuntimeUITests/NavRuntimeUITests/'+method,'-destination','platform=iOS,id='+udid,'-destination-timeout','15','-parallel-testing-enabled','NO','-resultBundlePath',str(base/(tag+'.xcresult'))])
def collect(tag):
 run(tag+'-collect',['python3','/private/tmp/woop-collect-id22.py',tag,'--nav']);r=[json.loads(x) for x in open(base/(tag+'-vol.jsonl'))];print(tag,r[-1],flush=True);return r[-1]
