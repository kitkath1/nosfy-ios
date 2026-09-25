# Le chevron de la fiche, en séance — analyse du 25-09-2026

Retour TestFlight de Kathryn : « en séance, quand je clique sur le chevron d'un
détail d'exercice, je reviens sur la page exercices avec les catégories — on
avait dit non » ; « pareil pour le détail d'exercice cardio : il doit ramener
l'overlay de séance en cours ».

**CODÉ le 25-09 sur son « code » (F1 + F2 + la tenue du noir), NON commité.**
Vérifié au simulateur à 60 i/s (`-skipAuth -boucleAuto`, sans compte, rien
écrit au serveur) : fiche → noir → lecteur, aucune image de la page
Exercices ni de la home. Premier film SANS tenue : la page passait 66 ms,
la home 170 ms — d'où `couper(tenue: 0.25)` sur ce seul chemin. Non mesuré
sur son iPhone. Vu en passant, NON corrigé : à l'aller lecteur → fiche, la
home reste visible ~0,5 s au simulateur.

## Ce qu'elle voit

1. Séance ouverte, elle choisit un exercice dans le lecteur.
2. La fiche s'ouvre (muscu ou cardio, peu importe).
3. Chevron en haut à gauche → la page Exercices apparaît, sur l'accueil
   des zones. Or cette page n'existe qu'HORS séance (règle du 22-09).

## La cause — une seule pour les deux fiches

- La fiche cardio et la fiche muscu sont **la même vue** depuis le 15-09
  (`ExerciseDetailView`, « la robe muscu pour tout le monde »). Un seul
  chevron, donc un seul défaut.
- Pour ouvrir la fiche, le lecteur **passe par l'onglet Exercices** :
  il bascule l'onglet, et la page Exercices pousse la fiche par-dessus
  elle (`NosfyApp.swift:2142-2145`, `ExercisesView.swift:598-606`).
- Le chevron fait un simple retour arrière :
  `RangeeChips(retour: { guideRetour = false; dismiss() })`
  (`ExerciseDetailView.swift:2297`). Il dépile la fiche… et ce qui est
  dessous, c'est la page Exercices. L'onglet reste sur Exercices.
- La bonne sortie **existe déjà** : `rendreLaBibliotheque()`
  (`ExerciseDetailView.swift:3281`) — coupe noire sourde, la fiche se
  dépile, l'onglet revient à la home, le lecteur se pose. Mais elle n'est
  branchée QUE sur « Choisir un autre exercice » de la pop-up flamme.
- Aggravant depuis le 24-09 (`7b1bbdfd`) : après la pop-up flamme, le
  chevron **s'allume pour inviter à le toucher** — il invite donc vers la
  page interdite.

Dans le build 83 (TestFlight du 23-09) le chevron était déjà un simple
`dismiss()` : le défaut est dans ce qu'elle tient en main **et** dans
l'arbre d'aujourd'hui.

C'est le **quatrième costume** du même défaut (22-09 « Page exercices »,
22-09 chevron de la page, 24-09 « Choose an exercise ») : la règle « en
séance, on revient au lecteur » était écrite chez certains appelants, pas
à la porte de sortie de la fiche.

## Le correctif proposé

**F1 — une seule porte de sortie de la fiche** (`ExerciseDetailView.swift`).
Une fonction `quitterLaFiche()` que le chevron ET « Choisir un autre
exercice » empruntent :

- séance ouverte (`active != nil`) → le chemin de `rendreLaBibliotheque()`
  tel quel : coupe sourde (pas de paillettes, c'est un retour), dépile,
  home, lecteur posé ;
- hors séance → `dismiss()` comme aujourd'hui (retour à la page Exercices,
  sur la zone où elle était).

Même geste pour muscu et cardio, puisque c'est la même vue. La scène du
double galet (tapis) n'a pas de chevron : elle n'est pas concernée.

**F2 — le filet de la page Exercices** (`ExercisesView.swift:821`).
Aujourd'hui son chevron ne rend le lecteur en séance QUE depuis l'accueil
(`if montreAccueil, enSeance`) ; depuis une zone, il rend les catégories.
Passer à `if enSeance` : si la page venait encore à se découvrir en
séance, son chevron ramènerait quand même au lecteur. Un mot retiré.

## Ce qu'on vérifiera

- Simulateur, séance ouverte : fiche muscu → chevron → lecteur ; fiche
  cardio → chevron → lecteur ; pop-up flamme → « Choisir un autre
  exercice » → lecteur (inchangé) ; chevron allumé après la pop-up →
  lecteur. Hors séance : chevron → page Exercices, zone conservée.
- Film image par image : la page Exercices ne doit apparaître sur
  AUCUNE image entre la fiche et le lecteur.
- Son iPhone : au prochain TestFlight seulement.
- Site de doc : ligne 🔴 « chevron de la fiche en séance → page
  Exercices (build 83) » posée avec le correctif, dans le même commit.
