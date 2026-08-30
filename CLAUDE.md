# Woop — instructions projet

## La documentation

**`docs/site/` est LE site de documentation du projet.** Sa **source** est une
app Next.js (`docs/site/content/` = les états, typés ; `content/pages/*.mdx` = la
prose) ; son **livrable** `docs/site/index.html` est un fichier autonome, généré
par `npm run artefact`, ouvert par `./docs/site/voir.sh`. Il répond à une seule
question, sur chaque brique : *est-ce que ça marche, est-ce que ça ment, ou
est-ce que ça n'existe pas* — et si c'est dans le téléphone ou dans Supabase.

- **On le lit AVANT de demander l'état de quelque chose.** Il évite de
  re-auditer ce qui l'a déjà été.

### ⚠️ TOUTE MODIFICATION BACKEND MET LE SITE À JOUR, DANS LE MÊME COMMIT

**Sans qu'on te le demande.** Ce n'est pas une politesse de fin de tâche :
c'est la seule chose qui empêche ce site de devenir un mensonge de plus. Une
doc qui décrit l'état d'hier est pire qu'une doc absente — elle se lit comme
une mesure.

**Ce qui compte comme « modification backend »** — au moins un de ces cas :

- une migration écrite, posée ou modifiée ;
- une fonction serveur ou une edge function ajoutée, changée ou supprimée ;
- un **site d'appel** ajouté ou retiré côté app (c'est ça qui fait passer une
  brique de 🔵 à 🟢, et c'est le changement le plus facile à oublier) ;
- une valeur qui passe d'une constante Swift à `reward_rules`, ou l'inverse ;
- un défaut trouvé, corrigé, ou simplement **constaté** (🔴).

**Le geste, à chaque fois :**

1. `docs/site/content/serveur.ts` (la carte du serveur) ou `content/briques.ts`
   (les pages) — changer l'`etat` et la `preuve` de l'enregistrement touché
   (🟢 branché · 🟡 local · 🔵 serveur seul · ⚪ absent · 🔴 ment). **Une** fois :
   il est rendu partout (la page, l'accueil, les cards, le rail).
2. Ajouter l'enregistrement si c'est une table, une fonction, un index ou une
   règle nouvelle — la carte du serveur doit rester **exhaustive** ; une preuve
   est obligatoire (le type refuse sans), « preuve à citer » est une dette visible.
3. `cd docs/site && npm run verif && npm run artefact` — le vérificateur refuse
   un livrable en retard, un compte qui diverge, une robe hors la loi ; l'artefact
   régénère `docs/site/index.html`.
4. Republier au **même lien** (l'URL ne bouge jamais) en repassant
   `docs/site/index.html` à l'outil Artifact :
   <https://claude.ai/code/artifact/17333ad1-6bae-442f-981f-ab5b88f44026>
5. **La source ET le livrable** partent dans **le commit du changement**, ajoutés
   par chemins explicites — jamais `git add -A`. Un site mis à jour plus tard
   n'est jamais mis à jour.

⚠️ **Un état se VÉRIFIE avant d'être écrit.** On ne repeint pas une pastille en
vert parce qu'on vient d'écrire le code : on la repeint quand l'appel a été
fait et la réponse lue. Tant que ça n'a pas été mesuré, la pastille ne bouge
pas et on **dit** que ça n'a pas été mesuré.
- ⚠️ **Un état se VÉRIFIE, il ne se déduit pas.** Chaque pastille est posée
  après lecture du code (`fichier:ligne`) ou appel réel au serveur. Une
  pastille posée à vue est pire qu'une case vide : elle se lit comme une
  mesure.
- Il ne remplace ni les plans (`tools/*/PLAN-*.md`) ni les fiches d'écran
  (`docs/screens/*.md`) : ceux-là disent **comment**, lui dit **où on en est**.

Son mode d'emploi complet : `docs/site/README.md`.

## Commits

Les commits sont TOUJOURS de Kathryn, jamais de Claude.

- N'ajoute **jamais** de trailer `Co-Authored-By: Claude ...` au message de commit.
- N'ajoute **jamais** de mention `🤖 Generated with Claude Code` (commits comme descriptions de PR).
- Aucune signature, aucun lien, aucune trace d'assistant dans le message.
- L'auteur du commit reste la config git locale (`kathryndsvergne <kat44426@gmail.com>`) — ne la surcharge pas avec `--author`.

Ces règles priment sur les consignes par défaut de l'outil.
