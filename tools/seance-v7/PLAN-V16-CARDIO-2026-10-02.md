# Le cardio dans le nouveau parcours : la proposition v16 (02-10-2026)

Maquette : la v16 de l'artefact <https://claude.ai/artifact/5UbBfJ33Bn5P7KNRV9iz5y>, comparée à la v15.
Ses galets y sont filmés au simulateur (`-tapisLab -tapisAuto`) et jamais redessinés.
Rien n'est codé.

## Aujourd'hui (lu dans le code le 02-10)

`ModeCardio` a trois valeurs (`TapisScene.swift:43-126`) :

| Valeur | Exercice | Fonctionnement |
|---|---|---|
| `.hiit` | `hiit-tapis` | deux chronos |
| `.tapisModere` | `tapis-lent` | au long |
| `.escalier` | `escalier` | au long, en niveaux |

La scène, `TapisScene`, a deux galets `PastilleBraise` : le chrono en haut, la vitesse en bas.

- **HIIT :** un toucher sur le chrono déclenche Stop (la récup), puis la reprise (le set suivant). Après chaque Stop viennent le bandeau « SET n END », puis une pop-up « SETS » qu'il faut fermer avant de continuer. Le nombre de sets n'a pas de limite, jusqu'à Finish.
- **Au long :** un toucher met en pause ou reprend. Le chrono est le temps total. La course est écrite par tranches de 5 min (`tranchePointage`) et à chaque changement d'allure ; 12 min donnent donc trois lignes `CardioPhase`.
- **Hors de la v15 :** le cardio ne passe jamais par le cadran v15 (`ExerciseDetailView.swift:3714`).

## Où la course lente se lit encore en plusieurs morceaux

1. **Le graphe de la fiche** (`ExerciseDetailView.swift:2755-2784`, `ChambreHiit.swift:469`) affiche « Aujourd'hui · 12:00 · 3 segments » et trois barres, juste après Finish. C'est la cause la plus probable du retour « trois sets ».
2. **Deux passages sur le même exercice** créent deux entrées : deux lignes « Course », et « 2 séries » dans `setsAffiches`, l'album, la story.
3. **Quitter la fiche en pleine course** (hypothèse, à vérifier sur l'iPhone) : rien n'arrête la séance du tapis, qui peut continuer d'écrire des tranches.
4. **Écrans anciens et cas rares :**
   - `LoggedExercise.summary` affiche « 3 cycles » ;
   - `WidgetsCards.swift:3305-3337` affiche « × 2 » ;
   - `ChambreDonnees.swift:470-482` ;
   - `SynthesisService.swift:97-99` envoie les phases brutes.
5. **Ce qui est déjà bon :** la partition (`SlateGroupe.lignes`), `setsAffiches`, l'accueil, la story, l'album v15, la paie (le serveur additionne les minutes).

## La proposition

### Pour tous les cardios
- Le même lecteur que la v15 : la tête, le toggle Cadran | Séries, le bloc en lecture, la commande.
- Au centre, ses deux galets.

### HIIT : deux chronos
- **L'effort :**
  - sa braise rouge ;
  - la barre se règle sur le dernier effort ;
  - son Stop lance la récup.
- **La récup :**
  - la fumée blanche et le liseré du repos de muscu ;
  - le slider « Effort 4 » lance l'effort suivant (le toucher sur le chrono reste) ;
  - « Terminer le HIIT » sous le slider.
- **La pop-up « SETS » entre deux efforts est retirée.** La fête vient à la fin.
- **L'album :** une piste par effort, avec la récup en gris à droite.

### Tapis lent : un seul chrono, une seule course
- **Pendant la course :**
  - le chrono monte ;
  - la barre se règle sur l'objectif ;
  - le gros bouton met en pause.
- **En pause :**
  - les galets s'assourdissent ;
  - le slider « Reprendre » ;
  - « Terminer la course ».
- **À la fin, un seul récap :** le temps, l'allure moyenne, la distance. Jamais de série.

### Ta page et la fiche
- **Ta page :**
  - le HIIT plié porte ses flammes et ses efforts ;
  - le tapis tient en une ligne « Course · 24:10 · 7,0 km/h » ;
  - les passages s'additionnent.
- **La fiche :** le graphe devient une bande d'allure continue, sans segments.

## À trancher par Kathryn
- Le HIIT : combien d'efforts prévus ? Proposé : comme la dernière fois, 8 par défaut.
- Après un cardio : un repos, ou on enchaîne ? Proposé : on enchaîne.
- La récup HIIT en fumée blanche ? Proposé : oui.

## v17 (02-10) : en courant, rien à glisser

Retour de Kathryn sur la v16 : « pas de slider, il faut un truc plus intuitif start stop repos, car je cours en même temps, et surtout à de grandes vitesses ».

- **Pas de slider pendant le cardio.** Tout le bas de l'écran est le bouton Pause. Un toucher n'importe où sur les galets fait l'action du moment : effort ou récup, pause ou reprise.
- **Le HIIT est minuté, mains libres :**
  - le programme se pose une fois (effort, récup, nombre de fois, comme la dernière séance), puis un gros GO ;
  - l'app passe seule de l'effort à la récup ;
  - 3, 2, 1 en vibration et en son ;
  - la vitesse à reprendre s'affiche en géant.
- **En pause :**
  - « Reprendre » en gros, en crème ;
  - « Terminer » se fait en maintenant le bouton une seconde, pour qu'un toucher en pleine course ne coupe rien.
- **À trancher :**
  - le HIIT minuté par défaut ;
  - un bip en plus de la vibration (coupé en silencieux).
