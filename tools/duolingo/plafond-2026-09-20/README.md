# Le plafond du jour — deux séances comptées, pas trois (20-09-2026)

Sa règle : « maximum deux séances par jour dans la Route de galets, pour pas
tricher et avoir trop de boosters ; le galet déjà fait se montre « une séance
faite », la pop-up duo dit « lancer une deuxième séance aujourd'hui ? », et une
fois faites, pop-up erreur : pas d'autre séance, attendez demain — en pop-up
native Apple. » Analyse et décisions : `PLAN-PLAFOND-2-SEANCES-JOUR-2026-09-20.md`.

## Le serveur — POSÉ, MESURÉ

Migration `supabase/migrations/20260920160000_chemin_plafond_deux_seances_par_jour.sql`,
posée par l'API de gestion puis `supabase migration repair --status applied`
(`pose-migration.log`) — sans toucher la migration `20260920120000` de la
session Route, toujours locale.

| pièce | ce qu'elle fait |
|---|---|
| `reward_rules.chemin_seances_par_jour_max = 2` | la règle du jeu, la même pour tous |
| `reward_rules.chemin_plafond_depuis = 2026-09-21` | rien ne rétroagit : son compte avait quatre séances avec travail le 20-09 au matin |
| `workouts.fuseau` | le fuseau du téléphone (IANA), posé par `synchroniser_seance` ; inconnu → null → le jour de la maison |
| `seances_chemin_plafonnees()` | PAR-DESSUS `seances_chemin()` (inchangée) : les deux premières séances avec travail de chaque jour local, `rang_jour` 1-2 |
| `cartes_prive.tirer_noeud_chemin` | la garde des lunes compte les plafonnées |
| `cartes_prive.cloturer_seance` | au-delà du plafond : `plafond_jour`, 0 pièce, pas de sachet, faits vides, solde vrai ; le reçu le garde au rejeu |

`python3 tools/duolingo/verif_plafond_jour.py` → **24 PASS, 0 FAIL** sur la base
posée, en transaction annulée (`verif_plafond_jour.log`) : trois séances →
deux comptées, 3e clôture `plafond_jour` et solde inchangé (40 → 40), rejeu
identique, lune du rang 3 refusée à deux puis accordée avec une séance
d'hier, Pago Pago = la veille (rattachée à son jour), fuseau inconnu → null,
séance vide sans effet, tout compte avant la date d'entrée en vigueur, compte
étranger vide. Comptes réels relus après la pose : Kathryn 8 séances avec
travail = 8 comptées.

## Le téléphone — MESURÉ AU SIMULATEUR

`Nosfy/Services/PlafondJour.swift` (la règle, la même que le serveur ; l'alerte
native `alertePlafondJour`) ; `EcranSpec.etapeEtFaits` ne compte que les deux
premières du jour ; `DuolinguoPage` : le panneau dit « Start a second session
today? » après une, et à deux le tap du galet actif ouvre l'alerte ; la Home
(`lancer`, `ouvrirSeanceEnBase`) et la racine (`startWorkout`,
`demarrerDepuisChemin`) refusent de même ; `SupabaseSync` envoie le fuseau.

- `route-deuxieme-seance.png` — une séance faite : « Start a second session today? ».
- `route-alerte-native.png` — deux faites (le 2e galet porte le ×2 posé par la
  session Route), la troisième n'est pas un galet, le tap sur « Today » ouvre
  l'alerte « Deux séances aujourd'hui — C'est le maximum d'une journée pour la
  Route. Revenez demain ! ».
- `home-porte-refusee.png` — « tire pour commencer » ne s'ouvre pas, aucun film,
  la même alerte ; la card Route dit « Étape 3 sur 9 ».

Bancs : `-plafondBanc N` (N séances finies avec travail semées aujourd'hui, une
série cochée chacune — la démo n'en coche aucune), `-plafondJourDepuis AAAA-MM-JJ`
(la date d'entrée en vigueur ; `2026-01-01` pour jouer aujourd'hui),
`-cheminAuto` (la Route s'ouvre à 7 s) + `-duoAutoTap` (le galet actif se tape à
+3 s), `-departAuto` (la porte de la Home).

## Ouvert

- **Son téléphone**, le 21-09 ou après : deux vraies séances, la troisième aux
  trois portes, le passage de minuit ; le fuseau lu au serveur depuis une vraie
  séance (`workouts.fuseau`, 🔵 au site).
- **La fiche exercice** (`ExerciseDetailView`, quatre créations de séance
  implicite) ne refuse pas encore : une troisième séance peut y naître sans
  pop-up — le serveur ne la compte ni ne la paie. À fermer par la session fiche.
- La migration `20260920120000` (les libellés HIIT) reste à poser par la
  session Route ; le plafond la reprendra automatiquement (il lit `seances_chemin()`).
- `double_jour` (la story ×2) reste au jour Europe/Paris, toute séance : la
  décision 3 du plan TestFlight.
