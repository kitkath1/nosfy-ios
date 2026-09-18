# Route et Profil — indicateurs fictifs retirés, 18 septembre 2026

Demande de Kathryn : retirer les compteurs lune/flamme du titre de Route,
et le niveau du Profil, sans reprendre le travail des autres sessions.

- `DalleChapitre` : suppression de lune240 et flamme7, deux constantes,
  ainsi que du helper de rendu privé `rail` devenu inutilisé.
- `ProfilLuneView.nomBloc` : suppression du badge constant « Level 1 »,
  de son bouton d’XP et de son état local ; prénom et pseudo conservés.
- Réglages du profil : suppression de « · Level 1 » ; solde conservé.

Les galets, claims, progression, pièces, sachets, cartes et gestes de la
bannière conservent leurs raccords. Aucun appel réseau ni schéma modifié.
Les changements parallèles de Compte/Cartes dans ces fichiers sont conservés.
Commit limité à ces suppressions UI et à leur documentation ; téléphone
laissé aux sessions chauffe/Compte. Rendu visuel à relire au prochain build.

## Validation

Analyse syntaxique Swift réussie sur les deux fichiers partagés et sur les
hunks isolés appliqués aux sources committées. Le diff propre à cette demande
est conservé séparément des raccords Compte/Cartes. Pas de compilation complète
de l’app ni de vérification visuelle iPhone dans cette passe.

Documentation du commit isolé : génération et vérificateur `--sans-captures`
réussis ;23 tests PASS.
