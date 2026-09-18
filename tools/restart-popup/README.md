# Pop-up de relance — 18 septembre 2026

Le panneau inférieur après une série devient une carte centrée, de la famille
des récompenses : flamme existante, fond noir à 68 %, coins de 36 points,
bouton de verre « Recommencer », lien « Terminé » et croix. Texte FR/EN.
Le fond et l’action d’échappement VoiceOver ferment également la carte.

Le choix est verrouillé pendant le fondu de sortie pour ne rappeler qu’une fois
`exitRestart`. Le parcours d’enregistrement et de relance reste celui de la fiche.
La vidéo est suspendue en arrière-plan, en sortie, avec Réduire les animations
ou la protection thermique ; démontage du lecteur, du looper et des items à la
fermeture. L’ancienne horloge de caméra et de poussière du panneau est retirée.

## Validation

- Compilation Debug arm64 simulateur : **BUILD SUCCEEDED**.
- Quatre tests UI : **4 PASS, 0 échec**, 55,439 s.
- Français / Terminé : retour à la fiche sans nouvelle série.
- Anglais / Start again : disparition de la carte, décompte puis **SET 2**.
- Retour d’arrière-plan puis tap du fond : fermeture sans relance.
- Croix : fermeture sans relance.
- Captures française et de la série relancée inspectées.
- Documentation compilée dans une copie isolée ; vérificateur sans captures
  ni sondes : PASS. Le livrable partagé a été régénéré pendant ce travail et
  contient déjà la note : cette session ne l'a pas écrasé.

Tests dans `RestartPopupUITests.swift`, journal et captures dans `preuves/`.
Le banc lance `-skipAuth -porteVue -sansVisite -sansSondeVol -sansServeur
-exoLab -restartFire -woop.langue fr` (ou `en`). Il simule une fin de série,
sans compte serveur. La série est ensuite relancée par un vrai tap du test UI.

Simulateur dédié : iPhone 17 / iOS 26.5,
`FC51F39B-CB70-4BA6-9F4C-8B04E0B0908E`, éteint à la fin des tests.
Build, runner isolé et résultat XCTest conservés dans
`/tmp/woop-restart-popup-20260918/`.

Cette validation ne couvre pas l’iPhone physique, la chauffe durable ni
VoiceOver au geste. Aucune installation sur le téléphone et aucun simulateur
des autres sessions utilisé.

## Périmètre

- `Woop/Views/RestartSheet.swift` : `RestartPopup` et cycle de vie de sa vidéo.
- `Woop/Views/ExerciseDetailView.swift` : seul montage de la question de relance
  et ses commentaires ; le fichier contient aussi du travail d’autres sessions.
- `docs/site/content/pages/flow.mdx` : note dédiée à la nouvelle présentation.

Les diff propres à cette correction et les deux sources d’avant modification
sont conservés dans le dossier temporaire du banc pour une sélection précise
au prochain commit. Les annonces, les récompenses et leurs règles ne sont pas
modifiées par cette correction.
