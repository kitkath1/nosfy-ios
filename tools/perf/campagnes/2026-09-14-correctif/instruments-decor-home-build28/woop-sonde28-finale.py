from pathlib import Path
src=Path('/private/tmp/woop-valide28.py').read_text().split("run('installation'")[0]
exec(src.replace("Path('/private/tmp/woop-validation28')", "Path('/private/tmp/woop-sonde28-finale')"))
run('lancement-sonde',['xcrun','devicectl','device','process','launch','--terminate-existing','--device',core,'--timeout','20',bundle,'--','-sondeVol','-ecranEveille','-navProbe','-openTab','home','-sansProtectionThermique'],35)
try:
 print('Relevé35s de la Home28 avec vidéo, sans drapeaux décoratifs',flush=True)
 time.sleep(35)
finally:
 launch('home-normale-sans-sonde')
run('collecte',['python3','/private/tmp/woop-collect-id22.py','woop-sonde28-finale','--nav'],45)
print('Relevé terminé et sonde éteinte.',flush=True)
