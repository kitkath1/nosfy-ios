# PLAN v2 — Le site de doc devient une app Next.js : hero de domaine, schémas obsidienne, structure Linear, animations Apple

> Plan écrit le 30-08-2026 ; **J0 → J4 livrés le même jour** (commits b4d721c, puis a74f2de pour les faits mesurés du pair — 127 pastilles) (Next.js compilateur,
> source typée `content/`, 7 pages, hero de domaine à teinte mesurée, schémas
> obsidienne pré-rendus, animations, loi réécrite, `npm run verif` vert). Restent **J5**
> (les 8 captures manquantes : un build, attend son feu vert) et **J6** (ses verdicts
> téléphone + la pose des ◌/⚑, commit à part). Mesures à côté : `ANNEXE-V2-SONDE.md`,
> `palette.py` → `palette.json` (rejouable). La v1 (commit 6fbd13f, `tools/docsite/PLAN-SITE-PREMIUM.md`) reste la base :
> tokens, composants, la page État, le flow en images — on la **porte**, on ne la refait
> pas. Tout ce qui est chiffré vient de l'app (`fichier:ligne`), d'une **mesure** (la
> palette des captures, le registre npm, la doc Vercel), ou du fichier v1 — jamais d'un goût.

## 0. Son retour sur la v1, décodé

| ce qu'elle a dit | ce que ça veut dire | § |
|---|---|---|
| « Pas mal. La page État est pas mal. Très bonne idée le flow en image. » | la v1 est la base ; l'accueil et les captures restent | 7 |
| « Pour chaque domaine, en haut, une **grosse card de couleur** comme ça (à la place de l'image avec le ciel), quitte à mettre de la couleur, et **le fond de l'écran en question au milieu, fondu**. » | un **hero par page de domaine** : la couleur de l'écran de l'app (**mesurée** sur sa capture), la capture au centre qui fond dans la couleur, la couleur qui meurt dans le noir — comme le ciel de sa référence | 3 |
| « J'aime bien le **noir dégradé spotlight** et la **structure de cet écran** » | les panneaux `#0F0F0F → #080808` restent ; la structure de Compte (display → phrase → panneau → h2 → schéma) devient celle de toutes les pages ; un spotlight blanc en haut de page | 4 |
| « Dans les schémas **ça marche pas quand on quitte l'artefact** → fais un site **Next.js**, plus simple à maintenir. » | en `file://` le moteur venait du CDN ; la vraie réponse = **schémas pré-rendus en SVG** ; Next.js devient le compilateur d'une **source typée** (une pastille = une ligne d'un fichier `.ts`) | 1, 5, 8 |
| « Les schémas **noirs, bordure radius 12 px, dégradé de noir et de blanc**, trop beau. » | nœuds **obsidienne** : fond noir dégradé, rayon 12, bordure en dégradé blanc — la couleur d'état devient un point de 6 px | 5 |
| « **Aérer**, des **animations de texte à la Apple** (blur, dégradé de blanc), **alléger** pour que ça respire. » | l'échelle d'espacement doublée ; l'arrivée cinématique de la home de l'app (`HomeNuit.swift:343-357`) portée en CSS ; 95 `<p>` → ≤ 30, 55 pills de coût → du texte, 32 figcaptions → 0 | 4, 6 |
| « **Les 6 dessins je comprends pas** — à la **Linear**, plus simple, minimal. » | 11 onglets → **7 pages** ; « Six dessins » devient un lexique de 6 lignes ; « Diagnostic » devient les sondes du Serveur ; le manège devient un cas d'erreur de la Forge | 2 |
| « Refais un plan, encore plus premium, Apple. » | ce document | — |

**Ce qui tient** : un état se vérifie, il ne se déduit pas · toute modification backend
met le site à jour dans le même commit · **aucune pastille ne change d'état dans une
refonte** (🟢35 🟡5 🔵37 ⚪26 🔴11 = 114, vérifié par section) · pas de flou animé en
continu · le site contient des **secrets de conception** (`index.html:1727` : deux
numéros en dur et un mot de passe dérivé ; l'id Supabase ×15) → **jamais public**.

---

## 1. La décision d'architecture — Next.js comme COMPILATEUR, pas comme site

**Le diagnostic honnête.** « Plus simple à maintenir » n'est pas vrai pour elle (elle
n'édite pas le site, elle l'ouvre) ; c'est vrai pour **la vérité** : aujourd'hui 114
pastilles sont 114 `<span>` à la main dans 2 275 lignes, et 69 rangées d'accueil les
pointent par `id` — un pointeur faux n'est qu'un `console.warn`. Demain une pastille est
**une ligne typée**, et un pointeur faux **ne compile pas**. Ce qui cassait hors de
l'artefact (le CDN Mermaid) se règle par des SVG pré-rendus — ça, Next ne l'apporte pas,
le build l'apporte.

**Tranché : Next.js 16.3.3 (App Router, `output:'export'`), TypeScript, MDX pour la
prose, zéro composant client, zéro React au runtime** — et le livrable reste **UN
fichier commité, `docs/site/index.html`**, produit par un inliner après le build.
Quatre conditions mesurables, sinon on n'y va pas :

| # | condition | vérifié par |
|---|---|---|
| 1 | le livrable est un seul fichier, sans `/_next/`, sans CDN, ≤ 1 `<script>` (le `site.js` inliné), s'ouvre par `open` **hors réseau** avec ses 19 schémas | `grep -c '/_next/' = 0` · `grep -c '<script' = 1` · `grep -c 'cdn.' = 0` · test avion à chaque jalon |
| 2 | une pastille = une ligne dans **un** fichier (`content/briques.ts` ou `serveur.ts`) ; la prose ne porte jamais un état | `tsc --noEmit` ; compte rendu = 114 |
| 3 | `npm run verif` en une commande, ≈ 1 min (plus de CDN à attendre) | §9 |
| 4 | deux builds consécutifs donnent le même fichier (diff du « même commit » lisible) | `git diff --stat` = 0 après re-build |

**Ce qu'on ne fait PAS en v2, et pourquoi (mesuré)** :
- **Pas d'hébergement.** Doc Vercel : « On the Hobby plan … your production domain
  remains publicly accessible » ; la protection de la prod = Pro 20 $/mois, le mot de
  passe = add-on 150 $/mois. Le téléphone garde **le même lien d'artefact** (on y
  republie le fichier unique) ; une URL Vercel Pro est une décision à part, **après**
  que les secrets aient quitté le contenu (rangée #52 de l'accueil).
- **Pas de `motion`/framer-motion** (4,8 Mo, hydratation) : 3 `@keyframes`.
- **Pas de Mermaid au runtime** (3,4 Mo bundlé = 10 × le site) : pré-rendu à la build.
- **Pas de CSS modules, pas de Tailwind, pas de `next/image`** : classes stables
  (`.p.p-ok` reste greppable), captures en data URI lues par `fs` à la build.
- **Ni `git add -A` ni `npm i` avant le `.gitignore`** : `node_modules/` n'est pas
  ignoré aujourd'hui (le dépôt a déjà payé `dd-*/` : 8,7 Go, 32 368 fichiers).

**L'alternative minimale si elle change d'avis** (0 dépendance, ≈ 1 jour) : rendre les
19 schémas une fois avec le Chrome installé et coller les SVG dans le HTML ; le hero
en 5 × 14 lignes de CSS ; 3 animations en 30 lignes. On garde le fichier à la main ;
on n'a ni source typée, ni composants, ni MDX — et la coupe de la densité se fait
dans 2 275 lignes sans filet.

---

## 2. La structure à la Linear — 7 pages, 114 pastilles conservées

| page | vient de (v1) | pastilles | hero |
|---|---|---|---|
| **État** | `etat` | 0 (agrège) | l'aurore (inchangée) |
| **Serveur** | `carte` 52 + `schema` 9 + `diag` 6 + `six` 1 | **68** | aucun — display + spotlight |
| **Flow** | `flow` | 9 | home (ambre mesuré) |
| **Économie & annonces** | `regles` | 8 | coffre (ambre mesuré, capture v1 → v2 à J4) |
| **Forge** | `forge` 11 + `manege` 1 (section « Si le manège s'interrompt ») | 12 | le sachet orange (l'objet du domaine) |
| **Stories** | `histoire` | 6 | noir + spotlight (aucune capture → à mesurer) |
| **Compte** | `porte` | 11 | la porte = la lune (ambre mesuré `#703913`, 9,6 %, `PorteEntree.swift:1296-1303`) |

68 + 9 + 8 + 12 + 6 + 11 = **114** ✓ — par **déplacement**, jamais par retrait (la dédup
des renvois, 114 → 113, = J5 à part). Rail : 7 items, un seul intertitre « DOMAINES »,
les nombres en `.42` **sans point rouge** ; la légende quitte le rail pour une ligne en
pied d'État.

- « Six dessins » → **lexique** de 6 lignes ≤ 90 car. en pied de Serveur (Le carnet ·
  Le videur · Idempotent · La file d'attente · RLS · Les prix vivent en base) ; sa
  seule pastille (un renvoi vers Compte) garde son id. La vraie cause du « je comprends
  pas » : **1 pastille pour 6 cards pleine largeur** — la densité, pas le dessin.
- « Diagnostic » → section **Sondes** de Serveur : les 6 sondes HTTP en blocs mono
  (`GET /rest/v1/rpc/noeuds_chemin_reclames → 200 []`), l'arbre plié.
- Serveur : Tables · Fonctions · Règles · Sondes · Lexique · Dictionnaire plié — **≤ 6 h2**
  au lieu de 14 ; un seul `<details class="menu">` « Ouvrir dans Supabase » (7 entrées)
  au lieu de 10 pills `.sb`.

**L'anatomie d'une page de domaine** (celle qu'elle aime sur Compte) :

```
1  h1 display 48/52/300 --titre          « Compte »
2  la phrase 15/24 .55, 62ch, UNE par page « Sans compte, tout le back-end rend zéro. »
3  LE HERO (§3)                           la couleur mesurée, l'écran fondu, le verdict calculé
4  h2 « Ce qui ment »   → rangées         les 🔴 de la page
5  h2 + LE schéma       → panneau spotlight, UN schéma (les autres pliés)
6  h2 « Ce qui reste »  → rangées         🟡 🔵 ⚪ dans cet ordre
7  .decision (≤ 1 par page)               le panneau noir dégradé : la seule décision ouverte
8  <details> pliés                        prose « savoir », dictionnaire, DDL, schémas secondaires, les 25 prompts
```
Tout ce qui est un défaut est une **rangée** ; tout ce qui est de la méthode est **plié**.
Chaque page ouvre sur des faits, jamais sur un chapo.

---

## 3. Le hero de domaine — « une grosse card de couleur, l'écran au milieu, fondu »

### 3.1 Géométrie

| | 1440 (rail 240, contenu 1040) | 390 |
|---|---|---|
| card | pleine largeur, **hauteur 400**, rayon **24**, marge `24px 0 64px` | hauteur **320**, rayon 20 |
| capture | **240 px** de large (source 480 px = 2× retina, JPEG q72 ≈ 55 Ko), centrée, `top:40px`, rayon 28, **sans bordure** | 160 px |
| visible de l'écran | les 55 % du haut (l'aurore, la phrase, le serpentin) — la capture **s'éteint** à 78 % de la card | idem |
| texte dans la card | bas-gauche : `.sur` 11 px caps `.54` « FLOW · 9 BRIQUES » · le **verdict** 36/40/300 `--titre` 100° « 1 brique ment » · la ligne des comptes 12,5 px avec les billes `.pt` | verdict 28/32 |

Pourquoi 400 : à 1440×900, `56 + 64 (h1) + 48 (phrase) + 400 + 64 = 632` → le h2 « Ce
qui ment » et **5 rangées** restent au-dessus du pli. Le titre de page vit **hors** de la
card (la structure qu'elle aime) ; dans la card, le verdict **calculé** au build — jamais
tapé, comme les cards d'État.

### 3.2 La couleur = la palette MESURÉE de l'écran (jamais choisie)

Mesure (PIL, 200 px, HSV, pixels `V > .25 & S > .30`, histogramme de teinte par 10°,
médiane du pas dominant) — `tools/docsite/palette.py`, commité, rejouable :

| page | écran source | mesuré (part) | famille |
|---|---|---|---|
| Flow | `tools/road/shots/j4-home-serpentin.png` | **#8F3F02** (9,2 %), 2ᵉ #661700 | ambre h26 |
| Économie & annonces | `tools/coffre-v2/ARCHIVE/coffre-v1.jpg` | **#5F3F18** (2,7 %) | ambre h33 — v1, à re-mesurer sur la capture v2 (J4) |
| Forge | `booster-orange.png` (l'objet) | **#60210A** (5,8 %) | rouge-brun h16 |
| Stories | aucune capture | — | **noir** tant que non mesuré (le seul hero noir à la sortie) |
| Compte | `onb-lune-loop-poster.jpg` = la porte (le 1er écran EST la lune) | **#703913** (9,6 %), 2ᵉ #DA9F4F — mesuré au rejeu de `palette.py` | ambre h26 : **teinté**, la lune au centre |
| chemin (`road-2`), départ (`road-1`), stop | 0 % · 0,1 % · 0,004 % de pixels colorés | — | ces écrans n'ont **pas** de couleur : jamais de teinte inventée |

**Deux faits qui empêchent l'arc-en-ciel** : l'app n'a que **deux familles** de couleur
(ambre h10-40 sur 8 captures sur 12, bleu h180-220 sur 3) — cinq heros = une famille,
cinq valeurs ; et les teintes mesurées sont **sombres** (V 37-56). Règle : **H et S
mesurés, V fixé à 62 pour tous** (le seul écart à la mesure, écrit dans la loi) ; la
lumière vient d'un radial **blanc** (le « ciel »), pas d'une saturation. Un écran à
< 1 % de pixels colorés → hero **noir** à spotlight blanc.

### 3.3 La recette

```css
.hero-dom{--t1:#9E4503;--t2:#9E2300;   /* palette.py · j4-home-serpentin.png · #8F3F02 h26 S99 9,2 % (2e #661700) — V posé à 62 */
  position:relative;isolation:isolate;overflow:hidden;height:400px;margin:24px 0 64px;border-radius:24px;
  padding:0 40px 32px;display:flex;flex-direction:column;justify-content:flex-end;
  border:1px solid rgba(255,255,255,.08);box-shadow:inset 0 1px 0 rgba(255,255,255,.14);
  background:
    radial-gradient(70% 60% at 50% 0%,rgba(255,255,255,.12),rgba(255,255,255,0) 70%),            /* LE CIEL : une lumière blanche, pas une teinte */
    radial-gradient(45% 55% at 10% 0%,var(--t2),rgba(0,0,0,0) 70%),                               /* l'épaule = 2e couleur mesurée */
    linear-gradient(180deg,var(--t1) 0%,color-mix(in srgb,var(--t1) 55%,#000) 46%,#000 100%)}      /* l'aplat qui MEURT dans le noir */
.hero-dom img{position:absolute;z-index:-1;left:50%;top:40px;width:240px;transform:translateX(-50%);border-radius:28px;
  -webkit-mask-image:radial-gradient(70% 62% at 50% 34%,#000 38%,transparent 100%),linear-gradient(180deg,#000 55%,transparent 92%);
  -webkit-mask-composite:source-in;mask-image:radial-gradient(70% 62% at 50% 34%,#000 38%,transparent 100%),linear-gradient(180deg,#000 55%,transparent 92%);mask-composite:intersect}
.hero-dom::after{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(180deg,rgba(0,0,0,0) 52%,rgba(0,0,0,.70) 78%,#000 100%)}  /* noir ABSOLU sous le texte */
.hero-dom .grain{opacity:.04}                          /* une seule texture ; 0 sur un hero noir (son seul rôle : le banding teinte → noir sur OLED) */
.hero-dom.noir{--t1:#0F0F0F;--t2:transparent}          /* écran sans couleur : la même structure, l'obsidienne */
.hero-dom.noir .lune{position:absolute;z-index:-1;left:50%;top:64px;width:120px;transform:translateX(-50%)}  /* Compte seulement */
@media(max-width:900px){.hero-dom{height:320px;border-radius:20px;padding:0 24px 24px}.hero-dom img{width:160px;top:32px}}
```
- **Masque, jamais un voile** : un `rgba(0,0,0,x)` par-dessus grise la capture ET
  l'aplat (« photo assombrie » = le tic SaaS) ; le masque garde les noirs de la capture
  à 100 % et laisse l'aplat traverser — l'écran **fond** dans sa couleur.
- Forge : l'image = le PNG alpha du sachet (240 px), même masque — l'objet flotte dans
  sa propre couleur. Compte : le poster de la lune (`onb-lune-loop-poster.jpg`, 1080×1644)
  recadré au format écran, même masque — la porte EST la lune.
- Sur un hero, **aucune couleur d'état** : le verdict est blanc, l'état vit dans les
  billes de la ligne des comptes. La teinte n'apparaît nulle part ailleurs sur la page
  (sonde PIL : 0 pixel `S > .30` sous la ligne de base du hero).

---

## 4. Le spotlight, l'air, et ce qui est allégé

**Le spotlight** — une lumière par surface, blanche, immobile (jamais un flou) :

| surface | recette |
|---|---|
| page (toutes sauf État) | `.page::before` : `radial-gradient(600px 320px at 50% 0, rgba(255,255,255,.05), transparent)` — le hero se pose dans cette lumière |
| panneau (`.bloc`, `.plan`, `.decision`) | `var(--panneau)` + `radial-gradient(60% 50% at 50% 0%, rgba(255,255,255,.04), transparent 70%)` + reflet `.04` + filet `.06` ; rayon 16 ; padding **28 32** |
| hero | son « ciel » `.12` |
| rangées, pills, cards d'État, tables, rail | **aucun** |

**L'échelle d'espacement** (v1 → v2) : contenu 920 → **1040** ; gouttières 40 → **56**
(390 : 20) ; page top 44 → **56** ; section (h2) 48 → **96** (390 : 64) ; h2 → contenu
12 → **20** ; hero → h2 **64** ; panneau 18/20 → **28/32** ; pied 64 → **96** ; rangée
44 inchangée, **sans rayon au repos**.

**Ce qui est allégé** (compté sur la v1) : 55 pills de coût `.p-cx` → **du texte** `.42`
(« 1 h · 1 j · chantier », un seul vocabulaire) · 10 `.sb` → 1 menu · 15 `.verdict` → **≤ 7
`.decision`** (une par page) · 32 `<figcaption>` → **0** (une ligne ≤ 90 car. seulement
quand elle dit autre chose que le dessin) · 49 `.bloc` → **≤ 7** + les pliés · 95 `<p>` →
**≤ 30** hors `<details>`, aucun > 240 car. · titres « 1 · Le flow » → « Flow » ·
`.glyphes` du hero d'État **supprimés** (3 textures dans un hero = bruit) · rail : 6
points rouges → nombres `.42` · le quadrillage de points des figures → supprimé.

**La typo v2** : display **48/52/300 −.025em** `--titre` 160° (390 : 34/38) — le même
display partout, accueil compris ; verdict du hero 36/40/300 (angle 100°, une ligne) ;
h2 **22/28/500** `--argent` ; h3 16/24/500 ; la phrase **15/24 `.55`** (un sous-titre
plus petit que le corps est timide — Apple met le sous-titre au corps, en sourd) ;
corps 15/24 `.72` ; rangée 13/20 `.86`, méta 11 `.42`. Règle nouvelle : **un h1 d'une
ligne ne finit jamais sous `.55`** (angle 100°, l'arrêt `.25` réservé aux titres de 2+
lignes) — fin du dernier mot gris qu'on voit sur « Onboarding & compte ».

**Inter auto-hébergée** : `fonts/InterVariable-latin.woff2` (Inter 4, axes `opsz,wght`,
sous-ensemble latin par `pyftsubset` — fonttools 4.60.2 est installé) ≈ 110 Ko,
commité, inliné en base64 dans le livrable → **zéro requête réseau**, la même Inter
hors ligne que l'app. Repli si le WOFF2 ne peut pas être obtenu : Google Fonts comme
aujourd'hui.

---

## 5. Les schémas obsidienne — pré-rendus, noir et blanc, la couleur en un point

**Le rendu : à la build, dans le Chrome 152 déjà installé**, via `puppeteer-core`
(`executablePath`, zéro téléchargement de Chromium), avec `mermaid@11.17.2` en
devDependency et **la même Inter** chargée dans la page de rendu (les boîtes se
mesurent avec la bonne police). `render('woop-'+id, code)` **un par un** (piège ④),
`viewBox` réparé (⑥). 19 `.mmd` → 19 `.svg` commités, chacun avec `<!-- mmd:<sha1> -->`
(un SVG périmé fait échouer `verif`). Le site livré ne contient **aucun JS de diagramme**
— `file://`, avion, artefact : partout. `beautiful-mermaid` (zéro navigateur) est
rejeté : son README ne documente ni `class` ni `<br/>`, et nos 19 schémas en ont 36 et 87.

**La matière** (`tools/docsite/obsidienne.mjs`, post-traitement déterministe) :
- fond `#101010 → #000` vertical ; rayon **12** ; bordure **1 px, dégradé blanc `.35` haut
  → `.06` bas** ; texte `.90` ; traits `.30` ; pointes `.45` ; libellés d'arête `.55` sur `#000` ;
- **l'état = une bille de 6 px au coin haut-droit du nœud** (la même `.pt` que
  l'accueil), rien d'autre ; `abs` = trait pointillé `4 3` + bille creuse ; `mut` = texte
  `.42` sans bille ; `bad` = bille `--men`. Fini les 5 fonds teintés ;
- **un `<linearGradient>` par SVG, dans ses propres `<defs>`, id unique** (`obs-b-7`),
  posé **en attribut** (`stroke="url(#obs-b-7)"`) — jamais un sprite partagé (payé en v1 :
  Safari ne résout pas un serveur de peinture dans un svg caché ; deux SVG à id égal se
  superposent) ;
- même pierre pour `rect.actor`, `.er.entityBox`, `.statediagram-state rect` ; notes en
  `#0A0A0A`/`.12` (fin de la note ambre) ;
- le conteneur = le **panneau spotlight** (§4), plus de trame de points, plus de `.bloc`
  autour (card dans card) ; `flowchart LR` par défaut (le TD de Compte fait 920 px de
  haut) ; ≤ 8 nœuds par schéma, sinon on coupe en deux.
- **Vérifier sur le schéma #1 avant les 18 autres** ; `stateDiagram-v2` et les deux
  `erDiagram` en second (DOM différent). Contrôle : `grep -c '<linearGradient id="obs-b-'`
  = 19 · fills teintés = 0 · `%%{init` = 0 · `classDef` = 0.

---

## 6. Les animations de texte à la Apple — l'arrivée de la home, portée en CSS

**La source est dans l'app** : `HomeNuit.swift:343-357` — flou de départ **1 em**, retard
**0,14 s** entre fragments, durée **0,90 s**, montée **22 pt**, échelle **1,05 → 1,00**
ancrée à gauche (« le couple flou + échelle fait la mise au point, jamais le flou
seul ») ; les valeurs rejetées « pas assez Apple » : flou 14 / 0,42 s / 0,09 s.
Courbe : `cubic-bezier(.16,.84,.22,1)` (`PorteEntree.swift:1868`, « une courbe qui
décélère, jamais de rebond »). **Tranché : CSS pur, 3 `@keyframes`, 14 lignes de JS.**

```css
:root{--courbe:cubic-bezier(.16,.84,.22,1)}
@keyframes arrive{from{opacity:0;filter:blur(1em);transform:translateY(22px) scale(1.05)}to{opacity:1;filter:blur(0);transform:none}}
@keyframes allume{from{background-position:100% 100%}to{background-position:0 0}}   /* le dégradé de blanc ARRIVE avec la mise au point */
.js .page>h1,.js .page>.phrase,.js .hero-dom>*{transform-origin:left center;animation:arrive .9s var(--courbe) both}
.js .page>.phrase{animation-delay:.14s} .js .hero-dom .sur{animation-delay:.28s} .js .hero-dom .verdict{animation-delay:.42s} .js .hero-dom .comptes{animation-delay:.56s}
.js .page>h1{background-size:200% 200%;animation:arrive .9s var(--courbe) both,allume 1.2s var(--courbe) .1s both}
.js .reveal{opacity:0;transform:translateY(12px);transition:opacity .48s var(--courbe),transform .48s var(--courbe)} .js .reveal.in{opacity:1;transform:none}
@media(prefers-reduced-motion:reduce){.js *{animation:none!important;transition:none!important}.js .reveal{opacity:1;transform:none}}
```
- Durée totale d'une page : **1,46 s** (= `duréeTotale` de l'app, `HomeNuit.swift:359`).
- **S'anime** : h1, la phrase, les 3 lignes du hero, les cards d'État (12 px, 50 ms de
  décalage), les blocs h2 + contenu (`.reveal`, comme UN bloc).
- **Ne s'anime PAS** : le rail, les pastilles, les rangées (20 rangées en cascade = le
  pop-in cheap), les tables, **les schémas**, les compteurs, les changements de page
  (noir → noir, instantané), le hover (fond + bordure 140 ms, jamais transform).
- Rejoue **une fois** (`body.entree` posée au chargement, retirée à 1,5 s ; `montrer()`
  n'y touche pas). Sans JS (capture headless, artefact sans script) : tout est visible.
- Garde-fous : `grep -c '@keyframes'` ≤ 3 · `grep -c 'transition:.*filter'` = 0.

---

## 7. L'accueil « État » — gardé, allégé

Le hero aurore, les 6 compteurs, les 7 cards, la liste, le flow : **gardés**. Allégés :
les `.glyphes` disparaissent · les compteurs deviennent des **texte-boutons tabulaires**
(soulignés à l'actif) plutôt que des pills en verre · les cards perdent les 4 segments
et le ↗ (la card est le lien) et gardent **une** ligne « 13 briques · 6 mentent » ·
la rangée = point · titre · domaine · coût · preuve (le badge 2 lettres et le chevron
partent) · à 390 : rien de coupé (`scrollWidth = 390`), filtres sur une ligne.
Tout est **dérivé** de `content/` : compteurs, phrases, groupes, nombres de 🔴 du
rail — plus de JS qui recompte, un test qui refuse un build faux.

---

## 8. Le modèle de contenu, la migration, l'arborescence

### 8.1 Le type qui empêche de mentir (`content/types.ts`)

```ts
export type Etat = 'ok'|'loc'|'srv'|'abs'|'men';
export type Domaine = 'eco'|'chemin'|'stories'|'annonces'|'forge'|'compte'|'sync';   // = data-dom actuels
export type Page = 'serveur'|'flow'|'regles'|'forge'|'histoire'|'porte';
export type Cout = '1 h'|'1 j'|'chantier';
export type Preuve = { fichier:string; lignes?:string } | { sonde:string; reponse:string } | { git:string } | { aCiter:true };  // la dette VISIBLE (14 aujourd'hui)
export interface Brique { id:string; titre:string; page:Page; domaine:Domaine; etat:Etat; preuve:Preuve;   // preuve OBLIGATOIRE : tsc refuse
  cout?:Cout; litige?:string; note?:string; genre?:'table'|'fonction'|'index'|'regle'|'edge'; nom?:string; quoi?:string; valeur?:string }
export interface Mesure extends Omit<Brique,'etat'> { lecture?:Etat }   // les 22 ◌ « à mesurer » : ce que le code laisse lire, JAMAIS peint
```
Fichiers : `content/serveur.ts` (11 tables · 15 fonctions · 6 videurs · 26 règles · 2
edge = 52), `content/briques.ts` (≈ 54 après fusion des doublons : `user_cards` porte
4 pastilles aujourd'hui = 1 enregistrement rendu 4 fois par `<Brique id/>`),
`content/mesures.ts` (22), `content/domaines.ts` (7 pages : libellé, capture, teinte
mesurée + sa preuve), `content/schemas/*.mmd` (19) + `*.svg`, `content/pages/*.mdx`
(la prose, composants `<Hero/> <Liste/> <Brique id/> <Schema id/> <Decision/> <Savoir/> <Sonde/>`).
Le compte de build = **occurrences rendues** = même sémantique que le grep v1 → **114**.

### 8.2 La migration — `tools/docsite/migrer.py` (stdlib, une fois)

Lit `docs/site/index.html` v1 : pour chaque `span.p.p-*` hors `#etat`, l'hôte
(`tr/li/p/div.bloc`), son `id="b-…"` (102 posés) sinon un id généré **flagué**, le
`data-dom` le plus proche (160 posés ; absent = erreur bloquante), le coût frère, la
preuve (regex `fichier:ligne` sinon le `<code>` de la rangée d'accueil qui le pointe,
sinon `{ aCiter:true }`) ; les 69 rangées → `titre`/`litige`/`preuve` ; les 19 `pre.mermaid`
→ `.mmd` (décodage en 4 temps, `&amp;` en dernier) ; la prose → MDX brut. Produit
`tools/docsite/migration/RAPPORT.md` : compte par page × état (attendu carte 22/0/27/3/0 ·
schema 6/0/2/1/0 · diag 0/1/1/2/2 · flow 0/3/2/3/1 · regles 2/0/1/5/0 · forge 4/0/3/2/2 ·
histoire 0/1/1/4/0 · porte 1/0/0/5/5 · manege 0/0/0/1/0 · six 0/0/0/0/1 = **35/5/37/26/11**),
ids générés, `aCiter`, doublons fusionnés. **À relire à la main** (≈ 1 jour) : ≈ 20 ids
générés, les 14 `aCiter`, les `quoi` des 52 lignes serveur, les 3 `Note`/`subgraph`.

### 8.3 L'arborescence et les gestes

```
docs/site/
  index.html                LE LIVRABLE — généré, commité, 1 fichier, < 2 Mo (même chemin : CLAUDE.md reste vrai)
  README.md · voir.sh       voir.sh = open index.html (sans Node) ; voir.sh --dev = next dev + open localhost
  package.json · package-lock.json · next.config.ts (output:'export') · tsconfig.json · mdx-components.tsx · .nvmrc (24)
  app/layout.tsx (rail + lune + <defs>) · app/page.tsx (les 7 sections empilées — la source du fichier unique)
  app/styles/{tokens,robe,hero,schema,liste,anim}.css     portés de la v1, valeurs inchangées, CSS global
  components/{Hero,Liste,Brique,Pastille,Schema,Card,Rail,Decision,Savoir,Sonde,Obsidienne}.tsx
  content/{types,domaines,serveur,briques,mesures,schemas,index}.ts · pages/*.mdx · schemas/*.mmd + *.svg
  fonts/InterVariable-latin.woff2 · public/site.js (≤ 120 lignes) · public/captures/{hero,flow}/*.jpg
  tests/{contenu,invariant,robe}.test.ts
tools/docsite/
  construire.sh (npm ci → schemas → build → inliner → verif) · inliner.mjs · schemas.mjs · obsidienne.mjs
  captures.py (ex-embarquer : sips → jpg 480/300) · palette.py · migrer.py · verifier.sh (wrapper de npm run verif)
```
`.gitignore` racine, **au J0 avant le premier `npm i`** : `node_modules/`, `.next/`,
`docs/site/out/`, `*.tsbuildinfo`. Commités : lockfile, SVG, captures, WOFF2, `index.html`.
`.gitattributes` : `docs/site/index.html linguist-generated`.

**Le geste « même commit » v2** : une migration posée → `content/serveur.ts` (l'`etat` et
la `preuve` de l'enregistrement, **une fois**) → `npm run verif` → `npm run artefact` →
`supabase/migrations/…sql` + `content/serveur.ts` + `docs/site/index.html` partent
**ensemble, ajoutés explicitement**. Un site d'appel ajouté côté app → même geste sur
`briques.ts`, 🔵 → 🟢 **après** lecture de la réponse. `verifier.sh` refuse si
`index.html` est plus vieux que `content/` (le site qui ment par retard).

---

## 9. Vérification — `npm run verif` (≈ 1 min)

1. `tsc --noEmit` — une brique sans `preuve` ne compile pas.
2. `tests/contenu` : ids uniques · titres ≤ 60 sans emoji · **chaque `preuve.fichier`
   existe** dans le dépôt et `lignes` ≤ sa longueur · chaque `.svg` porte le sha1 de son
   `.mmd` · chaque page a son `.mdx`.
3. `next build` + `inliner.mjs` → `tests/invariant` sur le livrable : `p-ok/loc/srv/abs/men`
   = **35/5/37/26/11** (113 après la dédup J5) · 0 emoji dans `h1/h2/h3` · `backdrop-filter`
   ≤ 4 · graisses ⊆ {300,400,500,600} · 0 date relative · `/_next/` 0 · `<script` 1 · `cdn.`
   0 · `%%{init` 0 · fills teintés 0 · `feTurbulence` 1 · `figcaption` 0 · `.verdict` 0 ·
   `<p` ≤ 45 · `@keyframes` ≤ 3 · `transition:.*filter` 0 · poids < 2 000 000.
4. Captures Chrome headless (`--virtual-time-budget=3000`, plus de CDN) : État, Compte,
   Flow à 1440 et 390 → `tools/docsite/captures/`, **regardées**.
5. Sondes PIL sur les captures : pixel (50 %, 95 %) du hero = `#000` ± 2 · 0 pixel
   `S > .30` sous la ligne de base du hero · première rangée à y ≤ 640 (1440) / ≤ 560
   (390) · `scrollWidth = 390`.
6. Déterminisme : second build → `git diff --stat docs/site/index.html` = 0.

**Le test du coup d'œil v2 — Compte, 1440×900** : 0-1 s le rail (7 items, « Compte »
actif, sans point rouge), « Compte » 48/300 qui arrive par mise au point, la phrase
« Sans compte, tout le back-end rend zéro. » ; 1-2 s la card ambre `#9E501B → #000` de 1040×400,
la lune du poster au centre, en bas à gauche `COMPTE · 11 BRIQUES` puis « 5
briques mentent » ; 2-3 s à y ≈ 630 « Ce qui ment » et **5 rangées** 🔴 —
`Supabase.swift:27-35` à droite. **On ne voit pas** : de schéma, de panneau de prose,
de pill, de numéro « 5 · », de figcaption, de bordure dans une bordure, d'autre couleur
que les 5 emoji et le blanc. **Flow** : la card ambre `#9E4503 → #000`, la home au centre
(son serpentin rouge fond dans la card — c'est le « ciel »), « 1 brique ment » ; pas un
pixel ambre sous la card.

---

## 10. La loi réécrite (même commit que J3)

| où | aujourd'hui | demain |
|---|---|---|
| `CLAUDE.md:5-6` | « Un seul fichier autonome, ouvert par voir.sh » | « Sa **source** est une app Next.js (`docs/site/content/` = les états, `content/pages/` = la prose) ; son **livrable** `docs/site/index.html` est un fichier autonome, généré par `npm run artefact`, ouvert par `voir.sh`. » |
| `CLAUDE.md:31-32` | « `docs/site/index.html` — changer les pastilles touchées… » | « `docs/site/content/serveur.ts` ou `briques.ts` — changer l'`etat` et la `preuve` de l'enregistrement (**une** fois, rendu partout), puis `npm run artefact`. » |
| `CLAUDE.md:35-39` | « Republier au même lien… Le fichier part dans le commit » | « Republier au même lien (`index.html` régénéré). **La source ET le livrable** partent dans le commit, ajoutés **explicitement** — jamais `git add -A`. » |
| `README.md:3-5, 55` | « pas de build, pas de dépendance… rien ne le génère » | « Un livrable autonome ; une source Next.js à côté (Node 24, `npm ci`). **Les états sont écrits à la main** dans `content/*.ts` ; le build ne fait que la mise en forme. Rien ne génère un état. » |
| `README.md` Notes techniques | Mermaid CDN, Google Fonts, `embarquer.py` | « Schémas = SVG pré-rendus à la build (`npm run schemas`), hash vérifié, aucun moteur au runtime. Inter auto-hébergée. Captures inlinées par `inliner.mjs`. `npm run verif` avant chaque commit. » |
| `SKILL.md woop-schema` §I couleur | trois sources | « **Quatre**, une par surface : (1) l'emoji d'état et sa bille ; (2) la teinte de card d'État qui en découle ; (3) l'aurore de l'accueil ; (4) **le hero d'une page de domaine, teinté par la palette MESURÉE de son écran** (`palette.py`, capture nommée, part en % ; H et S mesurés, V fixé à 62). *Une teinte de hero se mesure, elle ne se choisit pas.* Un écran à < 1 % de pixels colorés donne un hero noir. Sur un hero, aucune couleur d'état. » |
| `SKILL.md` §I flou | « flou animé interdit » | « Interdit : flou **continu** ou au survol. Permis : **une** arrivée ≤ 0,9 s jouée une fois — flou 1 em + montée 22 px + échelle 1,05, la courbe de la porte — sur h1, phrase et hero seulement, coupée par `prefers-reduced-motion`. » |
| `SKILL.md` §V ① ⑦ | le thème dans `initialize()`, CDN en file:// | « Les schémas sont des SVG pré-rendus (`schemas.mjs`, Chrome installé, un par un) puis passés à l'obsidienne (`obsidienne.mjs`) : fond noir, rayon 12, bordure dégradée en attribut, un `<defs>` par SVG à id unique, la couleur d'état = une bille de 6 px. Jamais de `%%{init}%%` ni de `classDef`. » |
| `woop-backend/SKILL.md` §8 | `docs/site/index.html` à jour dans CE commit | même sens, `content/*.ts` + `npm run artefact` |

---

## 11. Jalons, estimation, risques

| jalon | livre | porte de sortie (mesurée) | temps |
|---|---|---|---|
| **J0 — Squelette** | `.gitignore` + `.nvmrc` **d'abord** · `package.json` (next 16.3.3, react 19, @next/mdx, typescript ^5, vitest, mermaid + puppeteer-core en dev) · `next.config.ts` · `layout.tsx` avec rail + lune + tokens portés à l'identique · Inter WOFF2 sous-ensemble · `schemas.mjs` sur les 19 (**gate** : les 4 types rendus dans le Chrome installé, le #1 regardé d'abord) · `inliner.mjs` · `verifier.sh` v2 | `next build` vert ; capture 1440 : rail et fond identiques à la v1 ; 19 SVG ; `open` hors réseau ; diff de deux builds = 0 | 1 j |
| **J1 — Modèle + migration + État** | `types.ts` · `migrer.py` → `serveur.ts`, `briques.ts`, `mesures.ts`, `.mmd`, MDX bruts · `page.tsx` dérivé · tests contenu + invariant · État allégé (§7) | **35/5/37/26/11 = 114** ; `RAPPORT.md` relu ; `tsc` vert | 1,5 j + 1 j de relecture |
| **J2 — La coupe et les 7 pages** | 11 → 7 (§2) · anatomie de page · MDX ≤ 30 `<p>` · 0 figcaption / verdict / pill sans action / `.sb` · rail sans points rouges · échelle d'espacement · typo v2 | points 6-7-9-10 de §9 au grep ; captures regardées | 1 j |
| **J3 — Le hero et l'obsidienne** | `palette.py` commité + `domaines.ts` avec les teintes et leurs preuves · `<Hero>` sur 5 pages (4 teintés, Stories noir) · `captures.py` 480/300 · `obsidienne.mjs` · panneau spotlight | sondes PIL du hero ; `obs-b-` = 19 ; fills teintés 0 ; Flow et Compte regardés à 1440 et 390 | 1 j |
| **J4 — Animations + la loi** | `anim.css` + 14 lignes de `site.js` · `README.md`, `CLAUDE.md`, `SKILL.md` ×2 réécrits (§10) · `voir.sh` v2 · republication au **même lien** | capture après 2 s = capture finale ; l'artefact rouvert au téléphone ; schémas visibles hors artefact | 1 j |
| **J5 — Captures** (attend son feu vert : 1 build) | porte, story, coffre v2, player, exo, bravo, booster, calendrier, profil (`-skipAuth` sauf porte, jamais `-demoData`) → Stories et Économie prennent leur vraie teinte (Compte a déjà la sienne : 9,6 %) | poids < 2 Mo ; palette re-mesurée | — |
| **J6 — Verdicts** (commit à part) | ses verdicts téléphone (banding sur OLED, le `.42`, la liste à 390) ; pose des 22 ◌ et 5 ⚑ ; dédup des renvois (114 → 113) — **une mesure par enregistrement** | elle | — |

**Total ≈ 5,5 jours + 1 jour de relecture de la migration.** Un commit par jalon,
`npm run verif` vert avant chacun, jamais de trailer ni de signature.

| risque | parade |
|---|---|
| hydratation / mismatch | **zéro composant client** ; `site.js` n'ajoute que des classes |
| boîtes de schéma mal mesurées (police absente au rendu) | la page de rendu charge le même WOFF2 ; test : largeur d'un nœud identique entre deux rendus |
| `file://` sur l'export multi-pages (chemins `/_next/` absolus — vérifié dans la doc et les issues Next) | on ne l'ouvre **jamais** : `voir.sh --dev` sert ; le `file://` est le rôle du fichier unique |
| `node_modules` dans `git status` | `.gitignore` posé **au J0, avant `npm i`** |
| le livrable qui ment par retard (source commitée sans rebuild) | `verifier.sh` compare les mtime ; la règle est écrite dans CLAUDE.md |
| Turbopack + MDX + import dynamique | table d'imports statique ; repli `next build --webpack` |
| l'arc-en-ciel des domaines | teintes lues dans `palette.json` **généré**, jamais tapées ; `hue ∈ [10°,40°]` ou noir ; les 4 teintes mesurées sont h16-h33 : une famille |
| le hero qui pousse sous le pli | 400 px ; première rangée à y ≤ 640 / 560, lue sur la capture |
| animations qui rejouent à chaque onglet | `body.entree` 1,5 s, `montrer()` n'y touche pas |
| captures pixellisées | source = 2 × la largeur CSS (480 / 300), `width`/`height` posés |
| poids | seuil 2 Mo testé ; on baisse la qualité JPEG, jamais le nombre de captures |

## 12. Les 10 décisions (à contester ici, pas en cours de route)

1. **Next.js comme compilateur** : 1 route, 0 React au runtime, 0 hébergement en v2 ; le
   livrable reste **un fichier commité** — c'est ce qui garde l'artefact, `voir.sh`, l'avion.
2. **Pas de Vercel** tant que les secrets sont dans le contenu (Hobby ne protège pas la
   prod ; Pro = 20 $/mois) — décision à part, après la rangée #52.
3. **7 pages**, par déplacement de pastilles, jamais par retrait avant J6.
4. **Le titre hors de la card**, le verdict calculé dedans (la structure qu'elle aime).
5. **Teinte = mesure** (H, S) avec **V fixé à 62** ; un hero **noir** à la sortie (Stories,
   sans capture) — on ne peint pas pour faire joli ; Compte est ambré parce que le poster
   de la porte l'est (9,6 %), pas parce que c'est joli.
6. **La couleur d'un nœud est un point**, pas un fond ; les 36 lignes `class …` restent.
7. **Mermaid pré-rendu dans le Chrome installé** (mêmes dessins qu'aujourd'hui), SVG
   commités avec hash ; `beautiful-mermaid` rejeté (ni `class` ni `<br/>` documentés).
8. **Inter auto-hébergée** (WOFF2 ≈ 110 Ko, inliné) ; repli Google Fonts si le fichier
   ne peut pas être obtenu.
9. **CSS pur** pour les 3 animations, valeurs de l'app ; aucune animation sur les rangées,
   les tables, les schémas.
10. Poids plafond **2 Mo** ; pas de `motion`, pas de CSS modules, pas de Tailwind, pas de
    `next/image` : chaque « non » est une classe stable ou un Ko en moins.
