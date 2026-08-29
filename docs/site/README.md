# Le site de documentation

**C'est la référence du projet.** Un seul fichier, `index.html`, autonome : pas
de build, pas de dépendance, pas de serveur. On l'ouvre, on lit.

    ./docs/site/voir.sh

En ligne (privé, ouvrable au téléphone) :
<https://claude.ai/code/artifact/17333ad1-6bae-442f-981f-ab5b88f44026>

---

## Ce qu'il dit, et ce qu'il ne dit pas

Il répond à **une seule question**, sur chaque brique du produit : *est-ce que
ça marche, est-ce que ça ment, ou est-ce que ça n'existe pas* — et si c'est
dans le téléphone ou dans Supabase.

Il ne remplace pas les plans (`tools/*/PLAN-*.md`) ni les fiches d'écran
(`docs/screens/*.md`). Ceux-là racontent **comment** une chose est faite ;
celui-ci dit **où on en est**.

## La langue

Cinq pastilles, les mêmes partout :

| | | |
|---|---|---|
| 🟢 | **BRANCHÉ** | l'écran parle à Supabase, et ça a été vérifié |
| 🟡 | **LOCAL** | ça marche, mais ça vit dans le téléphone — perdu à la réinstallation |
| 🔵 | **SERVEUR SEUL** | c'est écrit et déployé, personne ne l'appelle |
| ⚪ | **ABSENT** | n'existe pas encore |
| 🔴 | **MENT** | l'écran affirme quelque chose que le code ne fait pas |

Et une seconde pour le coût : ⏱️ une heure · ⏳ une journée · 🧗 un chantier.

## La loi de ce site

⚠️ **UN ÉTAT SE VÉRIFIE, IL NE SE DÉDUIT PAS.** Chaque pastille de ce site a
été posée après avoir lu le code (`fichier:ligne`) ou appelé le serveur pour de
vrai. Une pastille posée « à vue » est pire qu'une case vide : elle se lit
comme une mesure.

Deux corollaires payés :

* **🔵 n'est pas 🟢.** Une fonction déployée et vérifiée en HTTP n'est pas une
  fonction branchée. La moitié des surprises de l'audit du 29-08 étaient des
  tuyaux complets **des deux côtés** dont il manquait l'appel au milieu.
* **🔴 mérite sa propre couleur.** « L'écran affiche un solde » et « l'écran
  affiche le VRAI solde » sont deux affirmations différentes, et seule la
  seconde est vraie. Un site qui n'a pas de mot pour ça finit par mentir aussi.

## Le tenir à jour

Il est écrit à la main, et c'est volontaire — rien ne le génère, donc rien ne
peut le désynchroniser en silence. **Quand une pastille change, on change la
pastille**, dans le même geste que le code.

Après toute modification :

    ./docs/site/voir.sh          # relire dans le navigateur

Puis republier au **même lien** (l'URL ne bouge jamais) en repassant
`docs/site/index.html` à l'outil Artifact avec cette URL.

## Ce qu'il contient

| | |
|---|---|
| ◇ | **Le back-end en 6 dessins** — les six idées dont tout dépend, sans jargon |
| ◇ | **La carte du serveur** — tables, fonctions, index, les 22 règles éditables, liens directs vers le tableau de bord |
| 1 | **Le flow** — les deux entrées, et les cinq écarts avec le code |
| 2 | **Coffre, notifs, pop-ups** — le rythme, le Welcome Back, ce qui manque au profil |
| 3 | **La forge** — le cycle d'un sachet, et **l'accès rapide aux 25 prompts du set** |
| 4 | **Historicité & stories** — les variants, et le moteur de faits qui n'existe pas |
| 5 | **Onboarding & compte** — le trou qui débranche tout le reste |
| 🧨 | **Le manège interrompu** — le seul endroit où on peut perdre quelque chose |

## Notes techniques

* **Un seul fichier.** Les schémas sont en Mermaid natif (aucune librairie),
  la typo vient de Google Fonts, tout le reste est en ligne.
* **Une seule robe : la nuit.** C'est un cahier d'atelier qu'on ouvre à côté du
  code, pas une page qui suit le thème de qui la lit. Toutes les couleurs sont
  donc peintes explicitement, jamais laissées au navigateur.
* **Le cardio est laissé en blanc** (décision du 29-08 : il va être retravaillé).
