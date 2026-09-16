# Woop — instructions projet

## ⚠️⚠️⚠️ RÈGLE ABSOLUE, NON NÉGOCIABLE — TOUTE SESSION LIT LE SITE DU BACK-END AVANT DE TRAVAILLER

**Demandé par Kathryn le 30-08-2026 : « toutes les sessions doivent lire le site du
back-end qu'on bosse ensemble — impératif, non négociable ».**

Le site de documentation (`docs/site/`, servi sur <http://localhost:3111>, source
`docs/site/content/serveur.ts` · `briques.ts` · `mesures.ts`) est **l'état vérifié du
projet** : pour chaque brique, si ça marche, si ça ment, ou si ça n'existe pas — et si
c'est dans le téléphone ou dans Supabase. Plusieurs sessions Claude travaillent en même
temps sur ce dépôt ; ce site est ce qui les empêche de se contredire.

**Avant la première ligne de code, de plan ou de réponse sur un sujet, chaque session :**

1. **lit la carte du serveur et les briques du domaine qu'elle touche**
   (`docs/site/content/serveur.ts`, `briques.ts`, `mesures.ts` — ou la page du domaine
   sur <http://localhost:3111>) — l'état, la preuve, la note, le litige de chaque ligne ;
2. **ne re-déduit JAMAIS un état que le site dit déjà** — un état se lit, il ne se devine
   pas ; si le site et le code se contredisent, c'est un 🔴 ou un litige à poser, pas une
   opinion à défendre ;
3. **met le site à jour dans le MÊME commit** que toute modification qui touche au
   back-end ou à un site d'appel (la règle du §« La documentation » ci-dessous) ;
4. **ne repeint jamais une pastille en 🟢 sans avoir mesuré** (appel fait, réponse LUE).

Une session qui n'a pas lu le site n'a pas le droit de dire ce qui marche. Une session
qui modifie le back-end sans mettre le site à jour a laissé son travail inachevé.


## La documentation

**`docs/site/` est LE site de documentation du projet.** Sa **source** est une
app Next.js (`docs/site/content/` = les états, typés ; `content/pages/*.mdx` = la
prose) ; son **livrable** `docs/site/index.html` est un fichier autonome, généré
par `npm run artefact`. **Le site tourne en local, toujours allumé : <http://localhost:3111>**
(`./docs/site/voir.sh`, service de session `fr.kathryn.woop.doc` qui sert la source en
`next dev`) — c'est LA référence qu'elle ouvre ; le fichier unique est republié au même
lien pour le téléphone. Il répond à une seule
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
3. `cd docs/site && npm run artefact && npm run verif` — **l'artefact D'ABORD**
   (mesuré le 30-08 : dans l'autre ordre, l'étape 1 du vérificateur refuse
   « le livrable ment par retard » avant même de vérifier) ; le vérificateur refuse
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

## Chauffe et fluidité

**Avant de reprendre ce bug : [registre des échecs, mesures invalides et preuves](tools/perf/ECHECS-CHAUFFE-HOME.md).**
La navigation rétablie ne valide pas la résolution de la chauffe.

**Skill chauffe demandé le16-09 : [woop-chauffe](.agents/skills/woop-chauffe/SKILL.md).**
Le charger pour reprendre la chauffe ou vérifier le coût d'une animation/vidéo.
Il porte la méthode actualisée, l'analyseur de sonde et les pièges à ne pas rejouer.
Les chiffres historiques ci-dessous restent des observations datées, pas des budgets.
Les 27–39 % CPU historiques sont le défaut signalé, pas une norme acceptable.

## Commits

Les commits sont TOUJOURS de Kathryn, jamais de Claude.

- N'ajoute **jamais** de trailer `Co-Authored-By: Claude ...` au message de commit.
- N'ajoute **jamais** de mention `🤖 Generated with Claude Code` (commits comme descriptions de PR).
- Aucune signature, aucun lien, aucune trace d'assistant dans le message.
- L'auteur du commit reste la config git locale (`kathryndsvergne <kat44426@gmail.com>`) — ne la surcharge pas avec `--author`.

Ces règles priment sur les consignes par défaut de l'outil.
