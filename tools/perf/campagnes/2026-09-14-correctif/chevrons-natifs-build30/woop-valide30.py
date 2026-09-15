from pathlib import Path
src=Path('/private/tmp/woop-valide28.py').read_text().split("run('installation'")[0]
src=src.replace("'/private/tmp/woop-validation28'", "'/private/tmp/woop-validation30'").replace("info['CFBundleVersion']=='28'", "info['CFBundleVersion']=='30'")
exec(src)
run('installation',['xcrun','devicectl','device','install','app','--device',core,'--timeout','30',str(app)],45)
launch('home-normale')
ui('navigation','testNavigationApresRelance')
run('collecte-navigation',['python3','/private/tmp/woop-collect-id22.py','woop-navigation30','--nav-only'],45)
launch('home-finale')
run('collecte-finale',['python3','/private/tmp/woop-collect-id22.py','woop-home30','--nav-only'],45)
