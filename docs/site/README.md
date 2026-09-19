# Le site de documentation de Nosfy

**C'est la référence du projet.** Il répond à **une seule question**, sur chaque
brique du produit : *est-ce que ça marche, est-ce que ça ment, ou est-ce que ça
n'existe pas* — et si c'est dans le téléphone ou dans Supabase.

**C'est un site Next.js, en local, toujours allumé : <http://localhost:3111>** — LA
référence. Un service de session (`~/Library/LaunchAgents/fr.kathryn.woop.doc.plist`)
lance `next dev` à l'ouverture de session et le relance s'il tombe ; il sert la source,
donc une modification de `content/*.ts` se voit au rechargement, sans build.

    ./docs/site/voir.sh            # ouvre http://localhost:3111 (relance le service s'il dort)
    ./docs/site/voir.sh --fichier  # le fichier unique index.html (avion, file://)
    ./docs/site/voir.sh --dev      # next dev au premier plan, pour lire ses logs

Le même contenu, en un fichier, republié au même lien à chaque changement backend
(pour le téléphone, hors réseau) :
<https://claude.ai/code/artifact/17333ad1-6bae-442f-981f-ab5b88f44026>

---

## Une source, un livrable

| | où | quoi |
|---|---|---|
| **la source** | `docs/site/content/` | `serveur.ts` (la carte du serveur), `briques.ts` (les briques des pages), `mesures.ts` (les ◌ « à mesurer »), `pages.ts` (les 10 pages, les teintes mesurées), `qa.ts` (le Test QA : les étapes du flow de bout en bout, deux verdicts chacune — front et back), `sondes.ts`, `schemas/*.mmd` (les 19 schémas) et `pages/*.mdx` (la prose) |
| **le compilateur** | `docs/site/app/`, `components/`, `scripts/` | Next.js 16 en export statique, **un seul composant client, vide (`Boot`, qui réveille `site.js` après l'hydratation), zéro React dans le livrable** ; `scripts/schemas.mjs` rend les schémas en SVG dans le Chrome installé et les passe à l'obsidienne ; `scripts/inliner.mjs` fait UN fichier de l'export ; `scripts/captures.py` embarque les captures |
| **le livrable** | `docs/site/index.html` | un seul fichier autonome (Inter, SVG, captures et `site.js` inlinés), commité, ouvert par `voir.sh`, republié au même lien |

On édite la source, on génère le livrable (`npm run artefact`), on lit le livrable.
**Les états sont écrits à la main** dans `content/*.ts` ; le build ne fait que la mise
en forme. Rien ne génère un état.

## La langue

Cinq pastilles, les mêmes partout — une pastille est **un enregistrement**, écrit une
fois, rendu partout :

| | | |
|---|---|---|
| 🟢 | **BRANCHÉ** | l'écran parle à Supabase, et ça a été vérifié |
| 🟡 | **LOCAL** | ça marche, mais ça vit dans le téléphone — perdu à la réinstallation |
| 🔵 | **SERVEUR SEUL** | c'est écrit et déployé, personne ne l'appelle |
| ⚪ | **ABSENT** | n'existe pas encore |
| 🔴 | **MENT** | l'écran affirme quelque chose que le code ne fait pas |

Et le coût, en texte : 1 h · 1 j · chantier. Une ligne « à mesurer » (◌, bille creuse)
n'a **pas** d'état : elle dit ce que le code laisse lire, et attend une mesure.

## La loi de ce site

⚠️ **UN ÉTAT SE VÉRIFIE, IL NE SE DÉDUIT PAS.** Chaque brique porte sa **preuve**, et le
type la rend obligatoire : un fichier et ses lignes (`fichier:ligne`), une sonde HTTP
avec sa réponse, un fait git — ou la dette **visible** « preuve à citer ». Une brique
sans preuve ne compile pas.

Deux corollaires payés :

* **🔵 n'est pas 🟢.** Une fonction déployée et vérifiée en HTTP n'est pas une fonction
  branchée. La moitié des surprises de l'audit du 29-08 étaient des tuyaux complets
  **des deux côtés** dont il manquait l'appel au milieu.
* **🔴 mérite sa propre couleur.** « L'écran affiche un solde » et « l'écran affiche le
  VRAI solde » sont deux affirmations différentes, et seule la seconde est vraie.

## Le tenir à jour

### ⚠️ Toute modification backend met le site à jour, dans le MÊME commit

La règle est inscrite à deux endroits pour qu'elle ne se rate pas : `CLAUDE.md` (lu à
chaque démarrage) et `.claude/skills/woop-backend/SKILL.md` §8. Elle s'applique **sans
qu'on la demande**.

| ce qu'on vient de faire | ce qui bouge ici |
|---|---|
| une migration posée | une ligne de `content/serveur.ts` : fonction, table, index, règle |
| une fonction ajoutée ou changée | son `etat` et sa `preuve` — **une** fois, rendu partout |
| **un site d'appel ajouté côté app** | la brique passe 🔵 → 🟢 — *le plus oublié* |
| un site d'appel retiré | elle repasse 🔵, et la `note` dit pourquoi |
| une constante Swift qui part en `reward_rules` | la règle, dans `serveur.ts` |
| un défaut trouvé, même non corrigé | une brique 🔴 et sa phrase, ou une ◌ dans `mesures.ts` |

⚠️ **UN SEUL COMPTE, D'UN BOUT À L'AUTRE.** Les compteurs du hero, les cards, les groupes de la liste, les nombres du rail et le hero de chaque page sortent tous de `compterFamilles()` — qui écarte les lignes `reference: true`. Mesuré le 30-08 au soir : une card comptée par DOMAINE annonçait « 1 à valider » et ouvrait une page qui disait « rien à faire pour toi » (la brique vivait sur une autre page) ; un hero de page comptait avec `compter()` et affichait « 87 briques » quand sa card en annonçait 55. Le seul nombre qui reste sur l'autre règle est le témoin `data-attendu` (toutes les pastilles rendues), qui n'est pas fait pour être lu.

⚠️ **On ne repeint pas une pastille en 🟢 parce qu'on vient d'écrire le code.** On la
repeint quand l'appel a été fait et la réponse **lue**. Tant que ça n'a pas été mesuré,
la pastille ne bouge pas — et on écrit que ça n'a pas été mesuré.

### Le geste

    cd docs/site
    # 1. éditer content/serveur.ts ou content/briques.ts (etat + preuve)
    npm run verif        # tsc · tests · build · inliner · robe au grep · captures · sondes PIL · largeur à 390
    npm run artefact     # régénère docs/site/index.html

Puis republier au **même lien** (l'URL ne bouge jamais) en repassant `docs/site/index.html`
à l'outil Artifact. **La source ET le livrable partent dans le commit du changement**,
ajoutés explicitement — jamais `git add -A` (`node_modules/`, `.next/` et `out/` sont
ignorés, mais on ne joue pas avec ça).

`npm run verif` **refuse** si `index.html` est plus vieux que la source (le livrable
ment par retard), si le compte des pastilles rendues diverge de la source, si la robe
sort de la loi (emoji dans un titre, graisse 700, flou animé, `/_next/`, CDN…), ou si
le livrable dépasse 2 Mo.

## Ce qu'il contient

| | |
|---|---|
| ◉ | **État** — l'accueil parle en **quatre familles, par QUI agit** (30-08, « je veux savoir ce que JE dois faire ») : **à trancher** (elle — une ◌ « Trancher / Définir / Décider… » ou une brique « décision ① »), **à valider ensemble** (elle et moi — 🔴), **en chantier** (moi — 🟡 🔵 ⚪, les autres ◌, une 🟢 à litige), **bon** (personne — 🟢). Il ne montre OUVERT que ce qui la concerne : le h1 (« 12 choses t'attendent »), une ligne **« Commencer par … »** qui nomme et vise la première, **deux** compteurs en grand (à trancher · à valider — les deux autres sur une ligne grise), **une card par PAGE** — le même nom, le même nombre et la même destination que le rail — avec son **badge en toutes lettres** dans sa couleur (la teinte va à la famille la plus nombreuse), la légende d'une ligne, puis la liste : « à trancher » et « à valider » ouvertes, **« en chantier » et « bon » PLIÉES** (un clic les déplie). Sur l'accueil, la bille d'une rangée porte la **famille**, pas l'état — et ni coût ni preuve : ils vivent sur la page de la brique. Les cinq états restent la vérité de la source (`content/index.ts` `famille`), regroupés à l'affichage |
| ▤ | **Serveur** — la carte : 12 tables, 15 fonctions, 26 règles, 2 edge functions, 6 videurs, les sondes HTTP, le lexique, le dictionnaire plié |
| ◇ | **Flow · Widgets · Le coffre · Les annonces · Forge · Stories · Compte** — chaque page ouvre sur son hero (la couleur MESURÉE de l'écran de l'app, la capture fondue dedans, le verdict calculé ; **vert** quand tout y est branché et que rien n'y ment — la règle des cards, rendue sur la page), puis « Ce qui ment », un schéma, « Ce qui reste », « Ce qui tient », une décision, et la prose pliée. Le 30-08, « Économie & annonces » est devenue deux pages (`tools/annonces/PLAN-COFFRE-ANNONCES.md` §7) |
| ☑ | **Test QA** (14-09, Kathryn : « un onglet Test QA avec ce flow qu'on valide ensemble niveau front et back ») — `content/qa.ts` : le compte du login à la suppression, une étape par rangée, ce qu'elle voit (front) et ce que le serveur ou le téléphone tient (back), **deux verdicts par étape** (☐ à valider · ✓ validé, daté · ✗ KO). Ce ne sont PAS des pastilles : le témoin `data-attendu` ne les compte pas, la robe est `.qv` (`components/QA.tsx`). Au téléphone, une étape = un bloc. Le hero compte des étapes, pas des briques ; pas de card sur l'accueil |

## Notes techniques

* **Les schémas sont des SVG pré-rendus** à la build (`npm run schemas`) : le vrai
  moteur Mermaid, dans le Chrome déjà installé (aucun Chromium téléchargé), **un par un**,
  avec la même Inter ; puis l'obsidienne (fond noir dégradé, rayon 12, bordure en
  dégradé blanc posée en attribut, un `<defs>` par SVG, la couleur d'état = une bille de
  6 px). Chaque `.svg` porte le sha1 de son `.mmd` ; un SVG périmé fait échouer `verif`.
  **Aucun moteur au runtime** : ça marche en `file://`, en avion, dans l'artefact.
* **Inter est auto-hébergée** (`fonts/InterVariable-latin.woff2`, 100 Ko, la variable
  d'Inter 4 sous-ensemble latin), inlinée dans le livrable — la même Inter que l'app, hors
  ligne.
* **Les captures** vivent dans `public/captures/` (`npm run captures` : flow 300 px q78,
  hero 480 px q72) et sont inlinées par l'inliner. Les écrans manquants s'affichent
  « à capturer ».
* **Une seule robe : la nuit de l'app.** Le noir `#000` de `Theme.swift`, des blancs en
  dégradé, une lumière blanche immobile par surface (le spotlight), et la couleur à
  quatre emplois seulement — l'emoji d'état, la teinte de card qui en découle, l'aurore
  de l'accueil, le hero de domaine **teinté par la palette mesurée de son écran**
  (`tools/docsite/palette.py`). La loi complète : `.claude/skills/woop-schema/SKILL.md` §I ;
  le plan chiffré : `tools/docsite/PLAN-SITE-V2-NEXT.md`.
* **Le seul script** est `public/site.js` (onglets, tiroir, filtres, lampe, l'arrivée
  une fois, le témoin du compte). Les animations sont trois `@keyframes` en CSS, les
  valeurs de la home de l'app (`HomeNuit.swift:343-357`), coupées par
  `prefers-reduced-motion`.
* **Le cardio est laissé en blanc** (décision du 29-08 : il va être retravaillé).
