# La séance v7 dans l'app — plan d'implémentation (30-09-2026)

Demande de Kathryn (30-09, après dix versions en artefact) : « je préfère la
version 7 avec l'effet liquid glass et la suppression d'une série, et surtout
tous mes UI de l'app déjà présents […] code ».

Maquette de référence : la v7 de l'artefact
<https://claude.ai/artifact/5UbBfJ33Bn5P7KNRV9iz5y> (sélecteur « v7 »).

⚠️ **Le premier jet (un cadran, des roues et un repos refaits) a été REFUSÉ
le 30-09 au soir** : « tu as changé mon cadran », « t'as zappé tout le
contexte de l'app ». `CadranV7.swift` est supprimé. La page est désormais
écrite contre la liste validée :
[LISTE-APP-A-RESPECTER-2026-09-30.md](LISTE-APP-A-RESPECTER-2026-09-30.md).

## La règle

La page v7 remplace le lecteur (`GrandPlayer`), et rien d'autre. Une série se
lance par SA fiche, SON départ, SON cadran, SA saisie, SON repos ; ses
toasters, ses pop-ups et « Encore une série ? » passent par les chemins
existants. Tout est derrière `-seanceV7` (clé `nosfy.seanceV7`).

## Ce qui est construit, et où

| Fichier | Ce qui change |
|---|---|
| `Nosfy/Views/SeanceV7.swift` | NEUF — l'état (`SeanceV7Etat`), la page, les grosses cartes, les rangées, la flamme qui prend feu, la feuille Ajouter, le banc |
| `Nosfy/NosfyApp.swift` | un hunk : si `SeanceV7.actif`, la page remplace `GrandPlayer` au même endroit ; `onChoisirExo` = `ouvrirFicheDeSeance`, comme le lecteur |
| `Nosfy/Views/ExerciseDetailView.swift` | `lancerDepuisLaSeanceV7()` (la série demandée par la page part aussitôt : porte posée ou tapis) ; le chevron note son feu (`dernierFeu`) |
| `Nosfy/Views/PiluleVagabonde.swift` | `CarreZoneMini`, `HaloCarte`, `ChaleurTete` passent de `private` à interne (aucun autre changement) |
| `Nosfy/LiquidLens.metal` | NEUF `eclipseGlowBraise` : le feu du cadran plus orangé rouge, sa couronne relevée (même arité qu'`eclipseGlow`) |
| `Nosfy/Views/LiquidLensLab.swift` | le cadran appelle `eclipseGlowBraise` ; le trait blanc du repos (`traitRepos`) |

## Ses composants, réutilisés tels quels

- la tête : `InviteAnimee` (l'état qui s'anime), `MiniCardJour(flotte:)` + `HaloCarte`, `TicketSeries`, `ChaleurTete`, `BraisesVague` (gelées hors pose) ;
- les lignes : `SetHistoryRow` (« Set 2 », reps · kg · s, « +20 » et la pièce ; la série à faire porte son cheveu blanc et son titre qui brille) ;
- le départ : `SliderObsidienne` (compte au slider) ou `BoutonPrimaire` « Allez, go » (compte au galet : sa fiche, où le galet attend le doigt) ;
- les carrés de zones : `CarreZoneMini` (ils respirent, chacun à sa période) ;
- la cérémonie : `CeremonieFlamme` ;
- les passages : `CoupeEtat.jouer` (les comètes) et `CoupeEtat.couper` (la coupe sourde) ;
- tout le reste du parcours sans une ligne touchée : `LiquidLensLab`, `SetEntrySheet`, `SeriesCoinFlight`, `ToasterSerie`, `RewardPopup`, `RestartPopup`, `TapisScene`, `StopCardHote`, `FileAnnonces`, `StoryPortal`, la Route, le booster.

## Les choix validés le 30-09 (« go »)

1. **Départ** : celui de Réglages, en bas de la page.
2. **Verre** : le vrai verre (`glassEffect(.clear)`) sur la tête des cartes seulement — barreau `-sansVerreV7`.
3. **Flamme** : « elle prend feu » dans sa ligne (fil orange d'un point, naissance par le pied, `CeremonieFlamme`, cinq braises), une fois, à l'arrivée sur la page.
4. **Comètes** : au premier lancement de chaque exercice, et une fois à la séance complète — barreau `-sansFeuV7`. ⚠️ Cela revient sur son verdict du 24-09 (« pas au lancement d'un exercice ») : à reconfirmer à l'œil.
5. **Cadran** : halos plus orangé rouge et plus visibles (barreau `-cadranAvant`) + trait blanc au repos (barreau `-sansTraitRepos`).
6. **Lignes** : les siennes (`SetHistoryRow`), dans les grosses cartes.
7. **Terminer** : la capsule de verre en haut (la maquette v7) — non tranché par elle, gardé par défaut.

## Les données

- une série faite = `StrengthSet(isDone: true)`, écrit par la fiche (`ancrerSerie`), jamais par la page ;
- les séries PRÉVUES vivent en mémoire (`SeanceV7Etat.plan`) : rien de neuf n'est envoyé au serveur ;
- supprimer une série FAITE = `context.delete(StrengthSet)` : capacité NEUVE, locale, avant la clôture. **À porter au site de doc au commit** (le snapshot `synchroniser_seance` enverra la séance sans elle).

## Vérifié au simulateur (30-09 soir, iPhone 15, `-skipAuth`)

- la page : sa tête, ses lignes, le verre des têtes, le slider en bas ; au galet, « Allez, go · Série 2 » ;
- `-v7Banc lancer -envolFire` : comètes → cadran (3-2-1-GO, repos avec le trait blanc qui se vide) → envol → pièces et toaster « +20 COINS » sur la fiche → « Encore une série ? » ;
- `-v7Banc allume` : les flammes prennent feu, ligne après ligne ;
- `-v7Banc fiche` : page → coupe → fiche (graphe) → coupe → page ;
- `-cadranAvant` contre le nouveau feu, moyenne sur le repos : vert/rouge 0,664 → 0,576, bleu/rouge 0,497 → 0,400, pixels clairs du halo +34 % ;
- un départ de séance (`-boucleAuto`) : le film 1-2-3-GO, les comètes, puis la page v7.

## Reste ouvert

- ⚠️ **Rien n'est mesuré sur l'iPhone.** Suspects à passer à la sonde (`-sondeVol`), un barreau chacun : le verre des têtes sur les braises (`-sansVerreV7`), le slider à 60 Hz tant que la page est posée, `InviteAnimee` à 20 Hz, les braises (`-sansBraisesV7`).
- le retour réel « Choisir un autre exercice » est rejoué par le banc (`ouvrirLecteur`), pas au doigt ;
- la Live Activity phase par phase, et l'interrupteur dans Réglages ;
- le site de doc (la suppression d'une série faite) au commit.
