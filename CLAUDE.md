# Nosfy — instructions projet

**Nom du produit décidé par Kathryn le 18-09-2026 : Nosfy.** Employer Nosfy
dans tous les textes affichés, les nouveaux documents et les échanges. Le dépôt
garde ses identifiants historiques (`fr.kathryn.woop`, clés de stockage et module
Swift `Woop`) pour préserver la compatibilité des comptes et des installations.
Dossier principal du Bureau : `/Users/kathryn/Desktop/Nosfy` (renommé le 18-09).
L’ancien chemin reste un accès local masqué pour les sessions déjà ouvertes ;
ouvrir les nouvelles sessions dans Nosfy.
Projet et schéma : `Nosfy.xcodeproj` / `Nosfy`. Sources : `Nosfy/`,
`NosfyShared/`, `NosfyWidgets/` ; entrée : `Nosfy/NosfyApp.swift`. Utiliser ces
chemins pour les nouveaux builds et commits. Les anciens chemins locaux ne
sont que des liens de transition pour les sessions ouvertes, hors du projet.

## Catalogue du lancement — règle de Kathryn, 19-09

Les 50 cartes font partie du lancement demandé. Ne pas présenter les 36 cartes
encore à produire comme reportées après TestFlight : une autre session Cartes
travaille dessus. Ce prérequis reste ouvert jusqu’à publication et vérification
du catalogue complet ; les sessions Parcours/Compte ne modifient pas ses assets.

## ⚠️⚠️⚠️ LA LÉGENDAIRE (Quatre Lunes) — règle HARDCORE de Kathryn, 20-09-2026

Une Quatre Lunes doit être reconnue **à 100 %, de loin, sans lire les lunes**,
par sa **matière** et sa **vie** — jamais par une étiquette ni une couleur.
Trois Lunes reste **intacte** (« excellentes ») : on ne l'étend pas, on ne
l'empile pas. Ce qui suit lie toutes les sessions, sans exception.

1. **JAMAIS DE BALAYAGE.** Aucune bande, lame, nappe, lobe, « éclair », sweep
   — automatique ou au geste. Dit quatre fois (26-08, slider, première
   arrivée, 20-09 : « les balayages c'est cheap, on a déjà parlé de ça »).
   Toute lumière a une **cause** : l'inclinaison du téléphone sur un **relief
   cuit**, ou le pouce (**la lampe** : rien ne bouge tant que le doigt ne bouge
   pas). Une lumière qui bouge a un **bord**.
2. **La brillance vient de la blancheur**, jamais de l'épaisseur : cheveux de
   lumière 1 px, blooms ≤ 5 px, noir absolu entre. Ses mots de rejet :
   « opaque » (lavis gris), « fake » (trait épais, néon), « coton »
   (procédural), « peau de girafe » (grille visible).
3. **Aucune couleur** hors blanc, argent, braise très sombre, rouge de braise
   qui meurt. Jamais d'arc-en-ciel, de néon, de cartoon.
4. **L'effet est dérivé de l'image de chaque carte** — sa gravure de ses
   propres bords, ses braises de ses propres pixels chauds, sa nacre de ses
   propres blancs — **cuit par script à la publication**. Aucune coordonnée
   écrite pour une carte précise (la plongée-film de carte-lune-1 est **morte**).
   Ça doit tenir pour **50 cartes et 3 mondes** sans main humaine, et chaque
   monde a **sa météo** : Forêt = neige fine + braises ; Cimes = cendres qui
   tombent + lave ; Bois = nacre qui monte, **pas de feu**.
5. **Le doigt conduit, jamais un film** : la caméra ne zoome pas au-delà des
   pixels de la peinture (×2 maximum), ne se pose jamais seule sur un
   détail, ne dure pas. **Jamais de vidéo** non plus (« en vidéo ce n'est pas
   possible, c'est cheap », 20-09) : la créature vit par le shader et ses
   masques cuits (respiration, feu, paillettes), pas par une boucle filmée.
   **Sa musique est à part** : majestueuse, au piano, très belle — jamais de
   carillon (`tools/sacre/PLAN-MUSIQUE-LEGENDAIRE-2026-09-20.md`).
6. **Rien ne se juge à taille de carte seule** : crops ×3 obligatoires sur
   toute planche montrée — elle les regarde. **Rien ne se pose sans mesure
   chauffe sur son iPhone** (le profil est 🔴) ; chaque effet arrive avec son
   barreau (`-sansRelief`, `-sansBraises`, `-sansNeige`, `-sansLampe`).
7. **Le plan et les maquettes** : `tools/carte-lune/PLAN-LEGENDAIRE-PLONGEE-2026-09-20.md`
   et `tools/carte-lune/maquette-legendaire-2026-09-20/` (Python, pas le
   shader). Le shader (`CarteLune.metal`) ne reçoit aujourd'hui **aucun**
   paramètre de rareté : c'est le défaut de départ, mesuré le 20-09.


## Compte vide et Route — règle de Kathryn,18-09

Sans séance terminée, commencer tout en haut du chapitre1, au premier galet.
Aucun fait, date ou gain inventé pour remplir l'écran. Garder ce contrat dans
Compte, Flow, Serveur et QA. Banc : `tools/duolingo/verif_route_vide.py`.
⚠️ **Règle du 21-09 : UN GALET = UN JOUR.** Un jour local avec au moins une
séance terminée avec travail vaut un galet ; la deuxième séance de la journée
ne pose pas de galet — elle pose le sticker ×2 sur celui du jour et rejoue sa
fête. Le plafond « deux séances comptées par jour » ne bouge pas, et la clôture
PAIE toujours la deuxième (sa décision : ce sont les galets qui s'épuisaient
trop vite, pas les pièces). Les lunes 3/7 et le trésor 35 comptent des JOURS
(serveur : `jours_chemin()`, migration `20260921090000`). Sept jours par
chapitre, cinq chapitres ; après 35, historique conservé sans nouveau cycle.
Un galet à deux séances ouvre, au « View », la pop-up NATIVE des heures.
Preuves : `tools/duolingo/galet-jour-2026-09-21/`. (Avant le 21-09 : un galet
par SÉANCE, implémenté le 18-09 — cette règle est morte.)1074 contrôles Swift et35 API PASS.
Contrôle iPhone distinct ; preuves : tools/production/compte-progression-2026-09-18/.

## Production et documentation — rappel explicite de Kathryn, 18-09-2026

« Tout est bon » est un verdict mesuré, jamais un objectif transformé en état.
À chaque changement **ou défaut découvert**, actualiser les preuves et réserves
dans `docs/site/content/`, puis régénérer le livrable et exécuter son vérificateur.
Une brique branchée, un test backend nominal ou une compilation dans l'arbre
partagé ne valent pas validation de la version à publier. Les blocages de
production et les tests iPhone encore ouverts restent visibles en page QA.
Référence du contrôle du 18-09 : `tools/production/ETAT-PRODUCTION-2026-09-18.md`.

Tester séparément un compte neuf et un compte existant. Conserver l'historique
personnel ; ne jamais remettre son compte à zéro pour préparer la QA sans un
accord explicite couvrant cette suppression. Coordonner toute utilisation du
téléphone avec les sessions Forge / chauffe via `MULTI-SESSION.md`.

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
