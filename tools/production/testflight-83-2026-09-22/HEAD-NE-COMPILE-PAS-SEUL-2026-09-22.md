# Le dépôt ne compile pas seul — mesuré le 22-09-2026, avant le build 83

## Ce qui a été fait

Un arbre PROPRE a été sorti à `e7cc9ef8` (`git worktree add --detach`), puis
archivé en Release. **`ARCHIVE FAILED`, 12 erreurs.** L'archive du build 83 a
donc été faite, comme les builds 79 à 82, depuis une **copie figée de l'arbre
de travail partagé** — qui contient le travail non commité d'autres sessions.

**Conséquence, à dire telle quelle : le binaire 83 n'est pas rejouable depuis
l'historique.** Aucun SHA ne le reproduit.

## Les 12 erreurs, à HEAD seul

| Fichier | Erreur | Cause probable |
|---|---|---|
| `Nosfy/Services/Annonces.swift` (×5) | `cannot find 'ToasterGain' in scope` | `NotifCard.swift` (ou son équivalent) n'est jamais entré dans l'historique |
| `Nosfy/Views/RewardCard.swift:1002` | `cannot find 'claimEtFermer' in scope` | raccord du 20-09 resté dans l'arbre |
| `Nosfy/NosfyApp.swift:1147` | `extra argument 'onStopViaPause' in call` | `PlayerSeance.swift` de HEAD n'a pas encore ce paramètre ; la version de l'arbre, si |
| `Nosfy/Views/SondeVol.swift:305-306` | `BacMotion` n'a pas de membre `actif` | sonde modifiée dans l'arbre, non commitée |
| `Nosfy/Views/RecentWorkoutCard.swift:40` | `switch must be exhaustive` | un cas d'énumération ajouté dans l'arbre |
| `Nosfy/Views/ProfilLune.swift:1528` | mur du type-checker | découpage fait dans l'arbre, non commité |
| `Nosfy/NosfyApp.swift:2713` | mur du type-checker | idem |

**Aucune de ces erreurs ne vient du chantier du lecteur de séance** (`e7cc9ef8`) :
ses huit fichiers compilent, l'archive Release de l'arbre figé est passée sans
une seule erreur.

## Ce qu'il faudrait pour lever le blocage

Chaque session propriétaire commite ses raccords, par chemins — surtout celle
qui tient `ToasterGain` / `NotifCard`, `claimEtFermer` dans `RewardCard`, et
`PlayerSeance.onStopViaPause`. Tant que ce n'est pas fait, chaque envoi
TestFlight part d'un état que personne ne peut reconstituer.
