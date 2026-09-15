from pathlib import Path
src=Path('/private/tmp/woop-valide28.py').read_text().split("run('installation'")[0]
exec(src.replace("'/private/tmp/woop-validation28'", "'/private/tmp/woop-invite30-compare'").replace("info['CFBundleVersion']=='28'", "info['CFBundleVersion']=='30'"))
try:
 for nom,extra in [('swiftui',['-chevronsSwiftUI']),('sans-invite',['-sansInvite'])]:
  run(nom+'-lancement',['xcrun','devicectl','device','process','launch','--terminate-existing','--device',core,'--timeout','20',bundle,'--','-sondeVol','-ecranEveille','-navProbe','-openTab','home','-sansProtectionThermique']+extra,30)
  print(nom,'relevé35s',flush=True); time.sleep(35)
  launch(nom+'-retour-normal')
  run(nom+'-collecte',['python3','/private/tmp/woop-collect-id22.py','woop-invite30-compare-'+nom,'--nav'],35)
finally:
 launch('home-finale-sans-sonde')
