# La story de fin de séance est-elle liée aux annonces, aux pièces et au coffre ?

Question de Kathryn, 20-09-2026, après le correctif de la story (e0e1d073) :
« c'est bien lié aux annonces, aux pièces et au coffre ? ne code pas ».
Réponse lue dans le site de doc (`docs/site/content/briques.ts`) et suivie
dans le code, sans rien modifier. Rien n'a été mesuré sur son iPhone ce jour.

## Réponse courte

Oui, en trois maillons, tous alimentés par **une seule réponse serveur** : la
clôture de la séance. Deux des trois maillons portent une correction encore
dans l'arbre (non commitée, absente du build TestFlight 81).

## 1. Story ↔ pièces

Ce qu'on voit : la page butin de la story roule « +N pièces gagnées » et
compte les sachets.

D'où ça vient : à la fin de la séance, l'app envoie la clôture au serveur
(`cloturer_seance`) et la story **attend sa réponse jusqu'à 6 s** avant de
s'ouvrir (`NosfyApp.swift`, `clotureRepondue`). La réponse est rangée **sur la
séance elle-même** comme un reçu (`ReglementSeance.recevoir` →
`workout.bilanRecompense`). La story lit ce reçu (`StorySession(workout:)` →
`recompense`) : pièces totales muscu + cardio, sachets gagnés.

Sans reçu (hors ligne, plafond de 6 s tombé) : « Récompenses en attente » et
un tiret — jamais un chiffre inventé (`StoryWin.pieces`, `recompenseEnAttente`).

Site : `b-story-bilan-recu` 🟢 (19-09, reçu HTTP réel), `b-story-recu-restaure`
🟢 (le reçu revient après un pull sur base neuve).

## 2. Story ↔ annonces (les toasters)

Ce qu'on voit : aucun toaster ne passe sous la story ; ils défilent sur la
Route quand la fête du galet a joué ; la pop-up booster arrive à la sortie de
la Route.

D'où ça vient : au début d'une fin de séance, l'économie retient les dalles
(`debutFinSeance` → `pousserApresStory`) ; les événements du reçu sont mis de
côté (`annoncer` → `evenementsRetenus`). Ils sont relâchés par
`viderFinSeance`, appelé quand la célébration du galet a joué
(`DuolinguoPage.onCelebrationJouee`, garde `recompensesApresRoute`) ; la
sortie de la Route est le filet (`libererFinSeance`). La pop-up booster attend
toujours cette sortie.

Site : `b-flow-deux-annonces` 🟡 avec **litige ouvert** — le relâchement au
galet est le retour TestFlight du 20-09, **commité dans ce83e640** (la Route :
cinématique du galet et correctifs TestFlight), après l'écriture de cette
page ; la pastille du site n'a pas été remesurée.

## 3. Story ↔ coffre

Ce qu'on voit : le coffre affiche le solde d'or et sa jauge « reste vers le
prochain sachet » ; la story dit « 100 pièces = 1 sachet · il t'en reste 27 ».

D'où ça vient : la même réponse de clôture rend `solde`, `reste`,
`prix_booster`, `sachets_convertis` ; l'économie les applique **sans
redemander** au serveur (`EconomieNosfy.appliquer(ClotureSeance)`) ; le coffre
lit `or` et `reste` (`CoffreV2`, jauge `.compte(courant: e.reste, cible: prix)`).
La phrase de conversion de la story lit `sachetsConvertis` et `reste` du reçu
(`BilanRecompenseSeance`) — **encore dans l'arbre, pas commitée, pas vue à
l'écran** (StorySuite.swift porte 321 lignes non commitées d'une autre session).

Site : `b-live-coffre-1909` 🟢 (53 contrôles Coffre, 44 API PASS),
`b-annonces-recus` 🟢.

## Réserves

1. **Build 81** n'a ni les annonces au galet, ni le prénom du profil (tous
   deux commités depuis, ce83e640), ni la phrase de conversion (encore dans
   l'arbre). Un nouveau build TestFlight est nécessaire pour les voir.
2. ⚠️ **L'index partagé porte 401 suppressions en attente** (dont
   `Nosfy/Services/ReglementSeance.swift`, le service qui range le reçu sur la
   séance), alors que les fichiers existent dans l'arbre et dans HEAD. Un
   `git commit` nu les emporterait : la story perdrait son reçu. Non touché,
   signalé ici — à relire avec `git diff --cached --name-status`.
3. Rien mesuré sur l'iPhone. Le commit e0e1d073 (Détails HIIT, Résumé
   intervalles, card à 4 lignes) ne touche que l'affichage, pas cette chaîne.
