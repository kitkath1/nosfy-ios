# Commandes de validation53

Les chemins /tmp désignent les copies de compilation isolées de cette session.
La source du runner simulateur est tools/flow/CountdownUITests.swift ; la sonde
count-state est injectée par monte_banc_count.py uniquement dans cette copie.

```sh
bash tools/flow/recuit_count.sh
python3 tools/flow/monte_banc_count.py /tmp/woop-count53/banc
xcodebuild -project /tmp/woop-ile48-propre-prod/Woop.xcodeproj -scheme Woop -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/woop-ile48-propre-dd -jobs 2 CURRENT_PROJECT_VERSION=53 build
xcodebuild build-for-testing -project /tmp/woop-count53/banc/Woop.xcodeproj -scheme WoopUITests -configuration Debug -destination 'platform=iOS Simulator,id=6A504B5A-F76C-4EC1-B09A-E9CA4673B32A' -derivedDataPath /tmp/woop-count53/sim-dd -jobs 2 CURRENT_PROJECT_VERSION=53
xcodebuild test-without-building -xctestrun /tmp/woop-count53/sim-dd/Build/Products/WoopUITests_iphonesimulator26.5-arm64.xctestrun -destination 'platform=iOS Simulator,id=6A504B5A-F76C-4EC1-B09A-E9CA4673B32A' '-only-testing:WoopUITests/CountdownUITests' -resultBundlePath /tmp/woop-count53/tests.xcresult -parallel-testing-enabled NO
```

Le test REST reçoit WOOP_QA_EMAIL et WOOP_QA_PASSWORD dans l'environnement,
depuis les identifiants existants autorisés du banc, sans impression :

```sh
python3 tools/flow/verifie_depart_serveur.py
python3 tools/flow/verifie_depart_serveur.py --seance-app 55DA4BCB-B8FB-4943-9FDA-CEB6E9B89A57
```

Le second UUID a déjà été nettoyé : ne pas le rejouer comme une séance encore
présente. Un nouveau test UI produit son propre UUID, relu après arrêt de l'app.

Le runner physique est le projet externe NavRuntimeUITests de la campagne
île, copié dans /tmp/woop-count53/iphone ; seul son Swift est remplacé par
`tools/flow/CountdownIPhoneUITests.swift`. Il cible l'app Release installée.

```sh
xcodebuild test-without-building -xctestrun /tmp/woop-count53/iphone-dd/Build/Products/NavRuntimeUITests_iphoneos26.5-arm64.xctestrun -destination 'platform=iOS,id=00008120-001E4CDC0A85A01E' '-only-testing:NavRuntimeUITests/NavRuntimeUITests/testLecteurDepartSurIPhone' -resultBundlePath /tmp/woop-count53/iphone-tests.xcresult -parallel-testing-enabled NO
python3 /Users/kathryn/.codex/skills/woop-chauffe/scripts/analyse_sonde.py /tmp/woop-count53/vol-20260916-183903.jsonl --start 76 --end 96
```

L'analyse temporelle associe les lignes vol aux événements nav `etat` du même
processus, dans leur ordre ; nav.t +978307200 donne l'heure Unix. Fenêtres UTC
et résultats : preuves/mesure-lecteur.json. Le champ home_retenue de l'analyseur
n'est pas une preuve de Home : c'est ici le lecteur de lab.

Dans docs/site : npm run schemas, npm run artefact, puis npm run verif.
Source et livrable vérifiés ; outil de republication de l'artefact Claude absent.
