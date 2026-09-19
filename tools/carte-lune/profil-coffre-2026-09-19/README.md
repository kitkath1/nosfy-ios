# Profil, Coffre et catalogue commun — 19 septembre 2026

## Changements

Bouton de rejeu « ▶ Nosfy » et état associé retirés de la racine. Les quatre
registres partagent une colonne de lunes de44pt ; constantes inutilisées
4/11/4/6 retirées. Les vrais compteurs restent lus depuis `totaux_cartes()`.

Kathryn demande50 scènes dans les trois mondes, sans génération maintenant,
un shiny très marqué et des personnages récurrents dans des poses/actions très
différentes. Plan séparé : `../PLAN-50-SCENES-2026-09-19.md`,14 publiées et36
compositions proposées, sans PNG supplémentaire ni publication.

## Backend relu

- `qa-api.log` et `qa-api.json` :28PASS, deux comptes temporaires supprimés.
  Identité commune entre comptes, vrais doublons,20 appels simultanés pour un
  seul exemplaire,8 préparations d’achat pour un débit, gratuité des noirs
  possédés, collection après reconnexion, stocks et reçus cohérents.
- `qa-coffre.log` :53PASS, compte neuf temporaire supprimé. Conversion,
  idempotence de clôture, versement quotidien, fuseau, flamme et droits. La
  garde d’un galet futur est vérifiée ; conversion par galet non rejouée ici,
  preuve déployée antérieure dans integration-2026-09-18/qa-galets-garanties.log.
- `catalogue-distant.json` :14 références relues, mêmes UUID/références/SHA256
  que le manifeste publié ;5/3/3/3, mondes4/6/4. Les `published:false` obsolètes
  du manifeste d’atelier sont corrigés. Aucun art existant changé.

## Versions et validation visuelle

Build iPhone Debug79 réussi et installation relue (bundleVersion79). Premier
essai de build sandbox refusé faute d’accès aux signatures ; reprise autorisée
réussie. Le build contient l’état partagé, pas un commit isolé. Aucun commit.
Build simulateur79 réussi ; ajout d’un banc DEBUG `-cartesQA -cartesQACoupure`
qui perd une seule réponse après attribution réelle. Une nouvelle tentative
utilise la même opération ; aucun jeton ni compte personnel dans le binaire.
Le banc UI vérifie Réessayer sur orange et relance sur noir, sur compte jetable.

À compléter avec le verdict UI. Test physique lancé puis retenu par le verrou
iOS : aucune mesure thermique79 acquise à ce stade. Pas de verdict « tout bon »
pour la chauffe du Coffre/Profil ou pour le shiny animé.
