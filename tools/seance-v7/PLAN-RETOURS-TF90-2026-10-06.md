# Plan : retours du TestFlight 90 (06-10-2026)

Ses mots : « fixes issus du TestFlight : (1) j'ai du mal à scroller dans la liste des séries quand j'en ai plus de 10, on a du mal à avoir le bouton Ajouter ; (2) j'ai dû relancer l'app quand j'ai rajouté des séries d'un même exercice ; (3) les pop-up annonces disent +3 sets alors que je suis à 12 séries de Woodchopper — cf. ma dernière session Supabase ; (4) changer la couleur pendant mes repos, et au-delà de la séance en cours ; (5) modifier une série existante en muscu — juste ajuster reps et kilos quand je me trompe. Lance un plan avant de coder. »

## Son compte (06-10) : supprimé par elle et recréé — RÉSOLU, pas un bug

(Constaté vers 13:55, avant sa réponse « oui je l'ai supprimé et recréé ». Compte actuel : `c2a7290d`.)

- `34e85321` (son compte, historique compris) n'existe plus dans `auth.users` ; ses séances (dont `e7b812a2` du 05-10, lue à 11:57) non plus.
- Un nouveau compte Apple `c2a7290d` est né à 12:19:51, juste après l'installation du TF90. Sa séance de 12:32 à 13:20 y est.
- Seul `supprimer-compte` (edge function, `auth.admin.deleteUser`) supprime un compte. L'app l'appelle depuis Réglages (« Supprimer mon compte » puis l'alerte native), depuis le panneau du profil (banc) et depuis le banc `-suppressionAuto` (argument de lancement, impossible en TestFlight).
- Aucune tâche planifiée, aucun déclencheur sur `auth.users`, aucune autre session ce jour-là. `apple_revocations` et `apple_jetons` sont vides.
- Les journaux du serveur sont illisibles par l'API (« Backend error »). Aucune sauvegarde n'est listée (`pitr` faux, liste vide).
- **Question posée** : a-t-elle touché « Supprimer mon compte » ? Piste à vérifier : sur Réglages, depuis le 05-10, toute la page se tire vers le bas (`simultaneousGesture`). Un `Button` sous un tirage peut s'enclencher au lâcher (déjà vu sur la playlist le 05-10). L'alerte de confirmation reste pourtant obligatoire.

## Les cinq retours

| # | Ce qu'elle voit | La cause (lue) | Le correctif |
|---|---|---|---|
| 1 | Le scroll de la liste des séries « bug » au-delà de 10 ; « Ajouter » dur à atteindre | `PlaylistV7` : depuis le 05-10, toute la feuille se tire vers le bas (`simultaneousGesture`) ; faire défiler vers le haut tire la feuille au lieu de la liste | Tirer par la tête seule (ou seulement quand la liste est en haut) ; « Ajouter une série » fixé sous la liste, toujours visible ; même chose pour `AlbumV15` (l'onglet Séries du cadran) |
| 2 | L'app à relancer après avoir ajouté des séries d'un même exercice | Sa séance du 06-10 au serveur : Woodchopper en 5 blocs (1, 4, 5, 3, 3 séries). Chaque passage par la fiche ouvre un `LoggedExercise` neuf (`blocDuPassage`) | D'abord reproduire le gel au vrai doigt (XCUITest). Puis UN bloc par exercice et par séance, comme le cardio depuis le 02-10 |
| 3 | La pop-up dit « +3 sets » à 12 séries | Le rang vient des séries de la fiche (`sets.filter(\.isDone)`, le passage), pas de la séance | Le rang = les séries faites de CET exercice dans la séance, tous ses passages compris (`faitesEnSeanceV15`) + 1. **Exercice par exercice, jamais cumulé entre exercices** (sa règle du 06-10) : 16 séries de Woodchopper → « +16 », le crunch garde son propre compte |
| 4 | La couleur ne se change pas au repos, ni hors séance | Au repos, le shader passe en fumée blanche (`blanc`), la teinte ne se voit plus | La fumée prend la couleur choisie en pâle (le rouge garde la fumée blanche validée) ; le choix aussi dans Réglages |
| 5 | Corriger une série faite (reps, kg) | Rien ne l'ouvre : toucher une série faite ne fait rien | Toucher une série faite (playlist de la page, onglet Séries) : une feuille avec les molettes de la note, puis Enregistrer ; le `StrengthSet` est corrigé, le serveur suit au prochain envoi (upsert par id) ; les pièces ne bougent pas |

Prêt dans l'arbre, testé (test08 PASS) : le repos après la toute dernière série de la séance.

## Les preuves, avant de dire « fait »

- Bancs à vrais doigts (`tools/tapis/cardio-doigts-2026-10-05/joue.sh`) :
  - 15 séries ajoutées, défilement haut et bas, « Ajouter » touché ;
  - ajouter des séries puis lancer, sans gel ;
  - pop-up au bon rang ;
  - corriger une série faite.
- Au serveur après la séance du banc : UN `logged_exercise` par exercice, les reps et kg corrigés.
- Rien n'est commité sans son ordre.
