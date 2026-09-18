# Validation du commit isolé Nosfy — 18 septembre 2026

Préparation au-dessus de `172ea553` avec un index privé et une copie exportée.
567 déplacements partent des blobs de HEAD. Les changements non committés
Forge, chauffe, stories, Home et Live Activity restent dans l'arbre partagé.
Les modifications de cette session concernent le nom, la configuration Apple,
le contrôle de production et le départ de Route sur un compte vide.

## Vérifié dans la copie du commit

- Xcode reconnaît le projet, les cibles et schémas Nosfy / NosfyWidgets.
- Inscription :12 contrôles Swift PASS ; session :15 PASS, nouveaux chemins.
- Route vide :34 contrôles Swift PASS. L'ancien code échoue au premier cas ;
  le nouveau démarre au premier galet à J0/J1/J40, sans fait ni date inventée.
- Documentation : `npm run artefact` puis `npm run verif` PASS,23 tests,
  dix pages sans débordement à390px, livrable identique octet pour octet au
  build. Taille1 919 612 octets. Quatre captures État / Compte,390 et1440px,
  inspectées : panneau du premier galet lisible et réserves visibles.
- Le site partagé a aussi été reconstruit et vérifié :23 tests PASS,
  quatre captures inspectées, changements parallèles conservés.
- Diff de code sans erreur d'espaces. Les journaux bruts restent inchangés.

Journaux : `commit-artefact.log`, `commit-verif.log` ; Route :
`../../duolingo/preuves-compte-vide-2026-09-18/tests.log`.

## Limites explicites

La Release74 installée est issue de l'arbre partagé. Ce commit n'est pas
présenté comme une nouvelle Release complète compilée ou installée : les
interfaces UI antérieures encore non committées sont hors de cette session.
Le téléphone demeure réservé à la session chauffe. Le correctif Route attend
son contrôle physique. La progression non vide reste en démo par défaut.

Les fichiers `tools/nav/PLAN-ILE-TOUCHABLE.md` et
`tools/serveur/tests/forge_raretes.mjs`, cités par des briques existantes,
sont encore non committés par leurs sessions. Dans ce commit, ces deux
références deviennent « preuve à citer », avec leur dette explicitée ; les
fichiers des autres sessions ne sont pas ajoutés. Dans l'arbre partagé,
les références d'origine restent en place car leurs fichiers y existent.

La documentation conserve les blocages de production : intégrité des gains,
vrai échange/révocation Apple, rapprochement de l'historique et qualification
iPhone intégrée. La clé privée n'est pas dans Git. Aucun push effectué.
