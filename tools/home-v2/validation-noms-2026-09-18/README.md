# Accueil : bilan et prénoms — 18 septembre 2026

Le bilan utilise « Bonjour Kathryn, / Cette semaine, / 1 séance / Bien joué. »
En anglais : « Hello Kathryn, / This week, / 1 workout / Well done. ».
Les trois variantes ne changent que le dernier encouragement ; les autres états
éditoriaux restent inchangés. Les révisions `fr-bilan-20260918-02` et
`en-bilan-20260918-02` ont été publiées puis relues dans Supabase.

Quand la salutation dépasse la largeur disponible, le prénom entier passe
sur une deuxième ligne. Les widgets et leurs emplacements en édition suivent
la ligne supplémentaire, ainsi que le raccord animé vers le départ.

## Validation

- Build Debug arm64 simulateur réussi.
- Validateur du catalogue et tests Swift du modèle réussis.
- Trois tests UI réussis, zéro échec, 63,378 secondes.
- Captures inspectées : Kathryn / 1 séance, Anne-Charlotte / 3 séances,
  Christopher-James / 1 workout. Texte entier visible, espace avec les cartes.
- Documentation compilée et vérifiée dans une copie isolée : PASS sans captures
  ni sondes. Le livrable partagé appartient aussi aux sessions en cours ; il
  n'est pas emporté dans ce commit.

Banc : `tools/home-v2/HomePrenomsUITests.swift`, compte local sans serveur,
`-phraseFige 1 -semaineFaits N -woop.prenom NOM -woop.langue fr|en`.
Simulateur dédié iPhone 15 / iOS 26.5 :
`B84E4C32-4874-4F79-BE45-C4120AB9D0A1`.
Build et résultat XCTest : `/tmp/woop-home-noms-20260918/`.
Les textes serveur sont publiés ; la disposition exige une nouvelle app.
Aucune installation sur l'iPhone ni mesure thermique physique dans cette session.
