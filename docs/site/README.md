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
peut le désynchroniser en silence. **Sauf nous.**

### ⚠️ Toute modification backend met le site à jour, dans le MÊME commit

La règle est inscrite à deux endroits pour qu'elle ne se rate pas :
`CLAUDE.md` (lu à chaque démarrage) et `.claude/skills/woop-backend/SKILL.md`
§8 (lu avant d'écrire une migration). Elle s'applique **sans qu'on la demande**.

| ce qu'on vient de faire | ce qui bouge ici |
|---|---|
| une migration posée | la carte du serveur : fonction, table, index |
| une fonction ajoutée ou changée | sa ligne, et son état |
| **un site d'appel ajouté côté app** | la brique passe 🔵 → 🟢 — *le plus oublié* |
| un site d'appel retiré | elle repasse 🔵, et on dit pourquoi |
| une constante Swift qui part en `reward_rules` | la table des règles, et l'onglet qui la citait |
| un défaut trouvé, même non corrigé | une pastille 🔴 et sa phrase |

⚠️ **On ne repeint pas une pastille en 🟢 parce qu'on vient d'écrire le code.**
On la repeint quand l'appel a été fait et la réponse **lue**. Tant que ça n'a
pas été mesuré, la pastille ne bouge pas — et on écrit que ça n'a pas été
mesuré.

⚠️ **Le fichier part dans le commit du changement**, jamais dans un commit de
documentation à part. Un site mis à jour « plus tard » ne l'est jamais.

### Le geste

    ./docs/site/voir.sh          # relire dans le navigateur

Puis republier au **même lien** (l'URL ne bouge jamais) en repassant
`docs/site/index.html` à l'outil Artifact avec cette URL.

## Ce qu'il contient

| | |
|---|---|
| ◉ | **État** — l'accueil : le compte des pastilles (refait par le JS à chaque ouverture, jamais tapé à la main — un témoin `data-attendu` le dénonce s'il diverge), une card par domaine teintée par son pire état, et **la liste de tout ce qui reste à faire côté serveur**, 🔴 d'abord. Une rangée = une brique ; son état est LU dans la pastille source de l'onglet (`data-src`). Bille creuse = à mesurer avant de peindre ; anneau pointillé = le site et le code se contredisent |
| ◇ | **Le back-end en 6 dessins** — les six idées dont tout dépend, sans jargon |
| ◇ | **La carte du serveur** — tables, fonctions, index, les 22 règles éditables, liens directs vers le tableau de bord |
| 1 | **Le flow** — les deux entrées, et les cinq écarts avec le code |
| 2 | **Coffre, notifs, pop-ups** — le rythme, le Welcome Back, ce qui manque au profil |
| 3 | **La forge** — le cycle d'un sachet, et **l'accès rapide aux 25 prompts du set** |
| 4 | **Historicité & stories** — les variants, et le moteur de faits qui n'existe pas |
| 5 | **Onboarding & compte** — le trou qui débranche tout le reste |
| 🧨 | **Le manège interrompu** — le seul endroit où on peut perdre quelque chose |

## Notes techniques

* **Un seul fichier.** Les schémas sont en Mermaid natif dans l'artefact (en
  `file://` le moteur vient du CDN), avec **un seul thème** dans le JS — jamais
  de `%%{init}%%` ni de `classDef` dans un bloc ; la typo est **Inter** via
  Google Fonts (la police de l'app) ; les captures du flow sont **embarquées en
  data URI** par `tools/docsite/embarquer.py` (300 px, JPEG q78, ≤ 60 Ko
  chacune) ; tout le reste est en ligne.
* **Une seule robe : la nuit de l'app.** Le noir `#000` de `Theme.swift`, des
  blancs en dégradé, un seul halo (l'aurore de l'accueil), la couleur réservée
  à l'état. La loi complète : `.claude/skills/woop-schema/SKILL.md` §I ; le plan
  chiffré : `tools/docsite/PLAN-SITE-PREMIUM.md`.
* **Avant chaque commit** : `./tools/docsite/verifier.sh` — l'invariant des
  pastilles (= `data-attendu` sur la section `#etat`, **à incrémenter quand on
  en pose une**, sinon l'accueil affiche l'alerte), la robe au grep, et deux
  captures sans tête (1440 et 390) qu'on **regarde**. Compter ~3 min : chaque
  capture attend les 19 schémas.
* **Le cardio est laissé en blanc** (décision du 29-08 : il va être retravaillé).
