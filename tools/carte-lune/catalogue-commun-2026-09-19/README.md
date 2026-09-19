# Backend Coffre / Cartes et catalogue mélangé — 19 septembre 2026

Demande : afficher le backend validé en vert et garantir que les nouvelles
scènes rejoignent le même tirage que les 14 références actuelles.

## Récompenses validées

Les gains et reçus sont enregistrés côté serveur. Attribution, exemplaire et
scellement du sachet sont atomiques ; la reprise garde la même carte sans
nouveau débit. Vingt appels simultanés donnent un exemplaire, huit préparations
d’un noir donnent un seul débit. Comptes isolés et collection relue après
reconnexion : 28 API Cartes et 53 contrôles Coffre PASS le 19-09.

Preuves : `../profil-coffre-2026-09-19/qa-api.json`,
`../profil-coffre-2026-09-19/qa-coffre.log` et
`parcours-api-reference.log` et `swift-live-reference.log` (44 API et
20 contrôles des clients Swift connectés). Provenance et empreintes conservées
dans `provenance-preuves.json`. Aucun de ces tests n’est relancé
ou présenté comme nouveau dans cette passe documentaire.

## Le mélange est déjà dans la fonction déployée

Lecture seule effectuée le 19-09 : `verification.json` et
`attribuer-carte-deployee.sql`. Le corps de la fonction déployée est identique
à celui de la migration du 18-09. Catalogue actif, 14 références publiées.

Le serveur choisit la rareté, puis une référence parmi **toutes les cartes
publiées de cette rareté**. Il n’existe ni lot initial à terminer, ni seuil de
14 cartes, ni classement par date de publication. Les légendaires encore
inconnues sont prioritaires parmi tout ce même catalogue.

Dès qu’une nouvelle scène est publiée, elle rejoint ce tirage pour tous. Une
nouvelle carte peut donc être obtenue alors que des cartes initiales manquent
encore. Avec 50 références publiées, les 50 participent ensemble, selon leur
rareté et les garanties existantes. Les tirages personnels peuvent différer ;
l’identité, l’illustration et la finition d’une référence sont communes.
Une ouverture déjà scellée conserve sa carte après extension du catalogue.

Cette passe ne génère ni ne publie d’image. Les 36 propositions restent sans
art ; le total prévu reste 50. La lecture prouve la sélection du code déployé,
pas une expérience utilisateur effectuée avec 50 images déjà disponibles.
La chauffe, le rendu iPhone et la distribution de l’app gardent leurs états
séparés : ils ne sont pas validés par ce contrôle backend.

## Vérification documentaire

Le bilan backend affiché en vert est calculé depuis ses briques validées ;
les compteurs globaux continuent d’inclure les mesures de l’app ouvertes.
Artefact régénéré, 23 tests PASS, dix pages à 390 px sans débordement. Captures
Coffre 390 et Cartes 1440 regardées ; règle de mélange et statut vert lisibles.
La première vérification a détecté la modification simultanée du texte Stories
par une autre session. Ses changements ont été conservés, puis le livrable a
été régénéré et vérifié identique au build final (`verif.log`).

Aucune modification Swift ou SQL de production, aucun art généré ou publié,
commit ciblé demandé ensuite par Kathryn. Fichiers de cette passe :

- `docs/site/components/BilanBackend.tsx`
- `docs/site/components/GalerieCartes.tsx`
- `docs/site/content/briques.ts` (bilans backend, tirage commun et état du conseil IA)
- `docs/site/content/pages/coffre.mdx`, `forge.mdx`
- `docs/site/index.html` et les captures documentaires générées
- `tools/carte-lune/PLAN-50-SCENES-2026-09-19.md`
- `tools/carte-lune/catalogue-50-scenes-2026-09-19.json`
- ce dossier de preuves et la seule entrée de session de `MULTI-SESSION.md`

Les fichiers partagés portent aussi des changements d’autres sessions ;
le commit demandé est préparé et vérifié dans un worktree isolé, avec les seuls
ajouts de cette passe. L’index partagé est conservé.

## Question complémentaire : historique et IA de la fiche exercice

Le 19-09, lecture de `ExerciseDetailView.rafraichirPassages` : pour le même
exercice, les séries faites des séances enregistrées alimentent passages,
charges, répétitions et record. Ce contrôle de code ne constitue pas une
nouvelle validation visuelle sur iPhone.

La liste des fonctions déployées a été relue sans écriture :
`fiche-exercice-ia.json`. **`conseil-exercice` est absent.** L’app l’appelle
via `CoachServeur.conseil`, puis utilise `phraseLocale()` si aucun texte n’est
rendu. Le conseil IA par exercice n’est donc pas livré ; sa brique reste
absente. Aucun serveur IA créé ou déployé dans cette session.

Le journal Swift copié garde son constat historique de reçu manquant après
pull ; la session Stories a depuis traité ce point séparément. Il n’est pas
utilisé ici pour annoncer un défaut actuel des Stories.

## Vérification de la sélection à committer

La source et le livrable isolés passent les 23 tests documentaires et le
contrôle des dix pages à 390 px (`commit-artefact.log`, `commit-verif.log`).
Les captures de l’état général et de Coffre/Cartes ont été regardées ; les
captures ciblées sont dans `commit-captures/`. Le site partagé a également
été régénéré puis vérifié (23 tests, `partage-verif.log`).
Les travaux non commités des autres sessions restent dans le site partagé ;
le livrable du commit ne les emporte pas. Aucune compilation iOS relancée
pour cette modification uniquement documentaire.
