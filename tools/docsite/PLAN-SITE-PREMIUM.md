# PLAN — Le site de doc devient PREMIUM (noir Apple · Inter · verre · l'état d'un coup d'œil)

> Plan écrit le 30-08-2026 ; **J0 → J3 livrés le même jour** (robe, rail + lune,
> accueil « État », onglets, 4 captures du flow, loi §I réécrite, `verifier.sh`).
> Restent **J4** (les 8 captures manquantes : un build, attend son feu vert) et
> **J5** (ses verdicts téléphone + la pose des ◌ et des ⚑, commit à part).
> Règle du 29-08 : l'analyse vit dans un `.md` du dépôt avant la première ligne. Annexes de preuves à côté :
> `ANNEXE-TODO-BACKEND.md` (les 58 issues lues dans le code) et `ANNEXE-DESIGN-APP.md`
> (les tokens de l'app, sourcés). Tout ce qui est chiffré ci-dessous vient soit de
> l'app (`fichier:ligne`), soit des 6 captures de référence, soit d'une mesure sur le
> site actuel — jamais d'un goût.

## 0. Contexte

`docs/site/index.html` est LA référence du projet (un fichier, un lien qui ne bouge
pas). Il est juste, mais il a une gueule de « design IA » : 88 paragraphes de récit,
108 pastilles-badges toutes pareilles, des emoji dans les titres, trois polices, un
gris violacé qui n'est pas celui de l'app, et une page d'accueil qui est un flowchart
géant — rien ne dit l'état en un coup d'œil. Kathryn veut :

1. **Un accueil = la to-do backend qui reste, type Linear** — savoir en UN coup d'œil ce
   qui marche, ce qui ment, ce qui manque. Zéro blabla.
2. **La robe de l'app** : noir Apple, titres en dégradé de blanc, Inter fine, Liquid
   Glass sur les pastilles, bouton primaire « en matière de noir » (le slider
   obsidienne), navigation latérale premium noire avec **le logo lune**, hover léger
   dans la bordure, liste très fine, badge discret.
3. **Des cards à dégradé** (« Today's News »), un accueil à **halo orange/rouge**
   (« Workspace »).
4. **Des images du flow de l'app** en fondu noir.

**Ce qui ne change PAS** (la loi du site, CLAUDE.md + README) : un seul fichier
autonome, rouvert par `./docs/site/voir.sh`, republié au **même lien** ; **aucune
pastille ne change d'état pendant la refonte** — compte avant = après :
**🟢 35 · 🟡 5 · 🔵 30 · ⚪ 27 · 🔴 11** (+ 1 de chaque dans la légende) ; la carte du
serveur reste exhaustive ; les 19 schémas restent (restylés) ; le site part dans le
commit du changement.

---

## 1. Ce qu'on prend des 6 références

| # | référence | on PREND | on LAISSE |
|---|---|---|---|
| 1 | **Lunor** (sidebar) | sidebar 240 px : logo + nom en tête, groupes séparés par un filet, item actif = fond +4 % + filet 1 px, icônes filaires 1,5 px, texte 13 px gris 60 % / blanc actif ; **la card en bas de sidebar** → chez nous la loi + la légende | breadcrumb, cards placeholder, « Upgrade » |
| 2 | **Menu compte** | panneau flottant rayon 16, fond `#1A1A1E → #101014`, filet 1 px 10 %, rangées 48 px icône + libellé 15 px ; la pill à halo doux = notre pill de compteur | l'avatar, le rose |
| 3 | **Acme Knowledgebase** | **la liste** : rangées 44 px, séparateur 1 px 6 %, **badge 18 px** très discret (le badge de domaine), onglets en pills (actif = verre teinté) | feux tricolores |
| 4 | **Acme Workspace** | **le hero** : une lumière en haut qui fond dans un rouge-brun puis le noir ; libellés de section en petites capitales 11 px +0,08 em à 40 % ; « Hi, Stephen » 17 px + titre 32 px | la photo → **l'aurore de l'app** |
| 5 | **Today's News** | **LA card d'état** : rayon 20, teinte (vert/rouge) au coin haut-gauche qui meurt dans le noir, fines rayures verticales 3 %, titre 24 px dont la fin s'éteint (dégradé de blanc), **4 segments** de progression, bouton rond ↗ | rien |
| 6 | **Ask anything** | le **champ de glyphes mono** à 6 % en fond (chez nous : de VRAIES lignes de nos migrations) ; le menu déroulant rayon 12, item survolé +6 % | le halo bleu, le bouton violet |

**Verdict de style** : Linear pour la densité et la liste, Apple pour la lumière (halos
doux, verre, dégradés de blanc), Woop pour la matière (l'obsidienne, l'aurore, la lune).

---

## 2. Pourquoi le site actuel fait « IA cheap » — 12 signes, prouvés

| # | signe | preuve `index.html` |
|---|---|---|
| 1 | emoji dans 1 h1, 3 h2, 14 h3 et dans la nav (`◇`, `🧨`) | L1469, L392/537/866, L980-1551, nav L300-314 |
| 2 | cards « emoji 26 px + gras + phrase » (feature grid) ×13 | `.idee .em` L164, L337-362, L1092-1095, L1161-1163 |
| 3 | 3 familles, 8 graisses, mono sur 14 rôles (th, légendes, pied) | `<link>` L4 ; h1 800 L100 ; mono L64…L278 |
| 4 | 108 badges identiques 10,5 px MAJUSCULES + fond teinté 10 % + bordure teintée 38 % (Bootstrap), et une légende collante de 8 badges | `.p` L126-136 ; `.legende` L141-144, L319-329 |
| 5 | card dans card, bordure sur bordure (`.bloc` > `figure > .plan` > `code`) | L170-173 dans L979, L1356, L1393 ; `code{border}` L123 |
| 6 | prose datée (« aujourd'hui » ×9, rail 29 août vs contenu 30-08) | L392, 441, 460, 945, 980, 1115, 1155, 1174, 1515 ; L295 vs L506 |
| 7 | 88 `<p>` = 16 125 car., dont un prompt d'image de 529 car. et 25 prompts (6 800 car.) dupliqués de `tools/carte-lune/PROMPTS.md` | L1219 ; L1223-1270 |
| 8 | « Diagnostic express » = un quiz | L801-878 |
| 9 | doublons (`woop.phone` ×2, la chaîne causale en prose ET en schéma, `user_cards` ×4) | L394≈L1358 ; L395≈L1401 ; L444=L715=L872=L1192 |
| 10 | aucune hiérarchie de blanc : encre plate `#EDEAF2`, gris violacés, **zéro dégradé** ; `#6B6480` sur `#131119` = 3,4:1 à 10-13 px | L19-21 ; L66, 72, 148, 176, 188, 228 |
| 11 | rayons 4/6/7/8/12/99 sans échelle | L123, 199, 77, 233, 154, 130 |
| 12 | accents venus de nulle part : platine `#C9D1E0`, or, corail, `--argent` morte, noir « violet » `#0A090E` — l'app est `#000` (`Theme.swift:27`) | L14, L23-26 |

Et le fade-up d'entrée à chaque onglet (`@keyframes entre` L96), le tic des maquettes.
**Et une chose plus grave** : le site cite **zéro** `fichier:ligne` alors que son README
en fait la loi (L52-55) — 6 sondes HTTP (L789-792, L1032, L1335-1339) sont ses seules
preuves dures.

---

## 3. La robe

### 3.1 Tokens `:root` — chaque valeur vient de l'app

```css
:root{
  --noir:#000;                                        /* Theme.swift:27 woopCard = .black ; HomeNuit.swift:172 */
  --panneau:linear-gradient(180deg,#0F0F0F,#080808); /* HomeNuit.swift:1248-1250  white .060 → .030 */
  --filet:rgba(255,255,255,.06);                      /* HomeNuit.swift:1251, 1 px */
  --filet-verre:rgba(255,255,255,.08);                /* ChipVerre.swift:69-70 */
  --encre-1:rgba(255,255,255,.96);                    /* Theme.swift:57 inkPrimary */
  --encre-2:rgba(255,255,255,.55);                    /* Theme.swift:58 inkSecondary */
  --encre-3:rgba(255,255,255,.42);                    /* HomeNuit.swift:328 — .34 rejeté à la mesure (2,9:1) */
  --titre:linear-gradient(160deg,#fff 0%,rgba(255,255,255,.90) 32%,rgba(255,255,255,.60) 68%,rgba(255,255,255,.25) 100%); /* Theme.swift:166-176 titleFade, DIAGONAL obligatoire */
  --argent:linear-gradient(180deg,#fff 0%,rgba(255,255,255,.80) 62%,rgba(255,255,255,.68) 100%);                        /* Theme.swift:150-158 silverText */
  --aurore-1:#FFE699; --aurore-2:#FF8A3D; --aurore-3:#FFF2F0; --plancher:#210C03;   /* AuroraHome.metal:592-594 ; AuroraBg.metal:525 */
  --reflet:rgba(255,255,255,.18);                     /* Theme.swift:118-124 diamondRim, 1er arrêt ramené pour 1 px */
  --ok:#5FC98C; --loc:#E3B341; --srv:#5AA9E6; --abs:#8E8E93; --men:#E56A6A;         /* les 5 états du site — ⚪ passe de #7A748A (violacé pour #0A090E) à #8E8E93 (gris neutre sur #000) */
  --rail:240px; --lire:62ch;
}
```

Supprimés : `--sol #0A090E`, `--panneau2`, `--trait #2A2634`, `--trait-vif`, `--platine`,
`--or`, `--argent` (l'ancienne), `--corail`. **Aucun gris en hex** : tous les gris sont
du blanc-alpha sur `#000` — c'est ce qui fait qu'une capture d'app posée sur la page
n'a pas de rectangle.

### 3.2 Typographie — Inter seule, plus fine

`<link href="https://fonts.googleapis.com/css2?family=Inter:opsz,wght@14..32,300..600&display=swap">`
(un seul woff2 variable ; l'axe `opsz` bascule sur le dessin « Display » au-dessus de
24 px — c'est le rendu Apple). Pile : `Inter, -apple-system, "SF Pro Text", system-ui`.
Mono : `ui-monospace, "SF Mono", Menlo, monospace` — **aucune police mono externe**
(zéro requête). `-webkit-font-smoothing:antialiased` ; `font-variant-numeric:tabular-nums`
partout où des nombres sont en colonne (= `.monospacedDigit()`, `SessionSlate.swift:477`).

| niveau | px / lh | graisse | tracking | encre |
|---|---|---|---|---|
| display (hero) | 40 / 44 · 390 px : 30 / 34 (`HomeNuit.swift:316-317`) | **300** | −0,022 em | `--titre` |
| h1 d'onglet | 28 / 32 | 500 | −0,021 em | `--titre` (angle `100deg` si une ligne) |
| h2 | 20 / 26 | 500 | −0,017 em | `--argent` |
| h3 | 15 / 24 | 500 | −0,009 em | `--encre-1` plein |
| corps | 15 / 24, `max-width:62ch` | 400 | −0,009 em | `rgba(255,255,255,.72)` |
| rangée de liste / cellule | 13 / 20 | 400 | −0,003 em | `.86` brique · `--encre-3` méta |
| petit / figcaption | 12 / 16 | 400 | 0 | `--encre-3` |
| libellé de section (WORKFLOW) | 11 / 16, capitales | 500 | +0,08 em | `rgba(255,255,255,.40)` |
| chiffre compteur | 20 / 24, tabular | 500 | −0,017 em | couleur d'état |
| mono | 12,5 / 20 | 400 | 0 | `.62`, fond `.04`, rayon 4, `1px 5px` |
| libellé obsidienne | 12 / 12, capitales | **600** (seul emploi) | +0,18 em (2,4/13,5, `Theme.swift:354`) | dégradé `.94 → .54` |

Règles : **300 seulement ≥ 28 px** (en dessous ça se délave), **600 seulement sur le
bouton**, jamais 700+. **Mot vif / mot sourd** (`HomeNuit.swift:328-337`) : même
graisse, même taille, vif `1.0` / sourd `.42` (`.54` sur la lumière du hero) — la
hiérarchie se fait par la lumière, jamais par le gras. Plancher absolu du texte porteur
de sens : `.42` (3,9:1 sur noir).

### 3.3 Les dégradés de blanc — 3 recettes, et leurs pièges

```css
.encre{-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent;display:inline-block;max-width:100%;padding-bottom:.08em}
.encre-titre{background-image:var(--titre)}      /* display, h1, titre de card (2-3 lignes : la dernière s'éteint = Today's News) */
.encre-sous{background-image:var(--argent)}      /* h2 — ligne 2 reste ≥ .68, jamais « grisé » */
.encre-chiffre{background-image:linear-gradient(180deg,rgba(255,255,255,.98),#C7C9D6 55%,rgba(255,255,255,.40))} /* StorySuite.swift:2860-2863 */
```
- `160deg` ≡ `topLeading → bottomTrailing` de `Theme.swift:171` : un dégradé
  **horizontal fait clignoter** les titres sur deux lignes ; sur UNE ligne large, la
  diagonale devient verticale et les lettres « coulent » → `--angle:100deg` +
  `width:max-content` pour les h1 d'une ligne.
- Un emoji dans un texte clippé **disparaît** (Safari) → aucun emoji dans un titre
  (règle §2-1 de toute façon).
- Jamais `text-shadow`/`filter`/`transform:scale` animé sur un texte clippé.
- `--titre` (bout à `.25`) **≤ 2 éléments par vue** (display + h1, ou titre de card) ;
  tout le reste en blanc-alpha plein. C'est le garde-fou contre « le dégradé partout ».

### 3.4 La lumière — où flouter, et où pas

- `backdrop-filter` **≤ 7 éléments, tous statiques, tous à taille fixe** : les 6 pills
  de compteur du hero (elles sont SUR l'aurore — le seul endroit où il y a quelque chose
  à flouter) et la barre haute mobile (52 px). **Zéro** sur les 108 pastilles (fond uni
  = rien à flouter, 108 couches de composition = scroll qui accroche au téléphone), zéro
  sur les cards, zéro sur la sidebar. Aucune `transition` sur un filtre (loi 60 → 14 img/s).
- Le « flou » demandé se livre autrement : halos en `radial-gradient` (net, gratuit),
  ombres molles en `box-shadow` noir, captures en `mask-image`.
- **Un seul halo coloré par site : l'aurore du hero de l'accueil.** 0 pixel orange sur
  les 10 autres onglets. Aucune ombre colorée nulle part.

### 3.5 Espaces, rayons, filets, états

- **Grille** : sidebar 240 px (≥ 900 px), contenu `max-width:920px`, gouttières 40 px
  (20 px à 390), rythme 8 / demi-pas 4. Section 64 · h2 48 · h3 24 · card gap 12 ·
  rangée 44 · item de nav 32 · barre mobile 52.
- **Rayons (jeu fermé)** : 8 rangée/item · 12 bouton/menu · 16 panneau · 20 card ·
  28 capture · 999 pill/obsidienne.
- **Filets** : toujours 1 px blanc-alpha — `.06` structure, `.08` verre, `.10` panneau
  flottant, `.16` hover/actif plafond. Ombre **seulement** sur ce qui flotte (menu :
  `0 12px 32px rgba(0,0,0,.60)`).
- **Trois états** (item de nav, rangée, pill), la bordure réservée en transparent pour
  que rien ne bouge :

| état | fond | bordure (inset) | texte | transition |
|---|---|---|---|---|
| repos | transparent | `0 0 0 1px transparent` | `.62` nav · `.86` rangée | — |
| **hover « léger dans la bordure »** | `rgba(255,255,255,.03)` | `0 0 0 1px rgba(255,255,255,.08)` | `.96` | 140 ms sur background/box-shadow/color — jamais transform |
| actif | `rgba(255,255,255,.05)` | `0 0 0 1px rgba(255,255,255,.08)` | `#fff` | pressé `.07`, 60 ms |

`:focus-visible` : `outline:1px solid rgba(255,255,255,.35);outline-offset:2px`. Plus
d'`@keyframes entre`.

---

## 4. Les composants — CSS prêt à coller

### 4.1 Le rail (sidebar) + la lune + les icônes

```css
.rail{position:sticky;top:0;height:100vh;width:var(--rail);padding:16px 12px;display:flex;flex-direction:column;background:#000;border-right:1px solid var(--filet)}
.marque{display:flex;align-items:center;gap:10px;height:44px;padding:0 8px;margin-bottom:14px}
.marque svg{width:24px;height:23px}                                   /* la lune */
.marque b{font:600 14px Inter;letter-spacing:-.01em;color:var(--encre-1)} .marque span{display:block;font:400 11px Inter;color:var(--encre-3)}
.menu-titre{margin:18px 10px 6px;font:500 11px Inter;letter-spacing:.08em;text-transform:uppercase;color:rgba(255,255,255,.40)}
.rail a{display:flex;align-items:center;gap:10px;height:32px;padding:0 10px;border-radius:8px;font:400 13px Inter;color:rgba(255,255,255,.62);box-shadow:inset 0 0 0 1px transparent;transition:background-color .14s,box-shadow .14s,color .14s}
.rail a svg{width:16px;height:16px;stroke:currentColor;stroke-width:1.5;fill:none;opacity:.55}
.rail a:hover{background:rgba(255,255,255,.03);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08);color:var(--encre-1)}
.rail a.on{background:rgba(255,255,255,.05);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08);color:#fff} .rail a.on svg{opacity:.9}
.rail a .n{margin-left:auto;font:500 11px Inter;font-variant-numeric:tabular-nums;color:var(--encre-3)}   /* nb de 🔴 de l'onglet, point 5 px --men devant */
.rail .loi{margin-top:auto;padding:14px;border-radius:12px;background:var(--panneau);border:1px solid var(--filet)}  /* la légende + la loi, voir 5.4 */
```
- **La lune** : `Woop/AppIcon.icon/Assets/lune (2).svg` (749×718, 4,5 Ko) → on garde
  **le premier `<path d="M292.169 …Z">`** et son `<linearGradient>` blanc → blanc `.70`
  vertical (c'est déjà le dégradé de blanc de la marque) ; on jette le `<foreignObject>`
  (backdrop-filter Figma), le `<filter>`, le `<clipPath>` et le second path `stroke` →
  ≈ 1,2 Ko inline dans `.marque`. Pas de halo orange dessus (règle 3.4).
- **Icônes** : 11 glyphes filaires 24×24 (tracés Lucide, MIT) dans un
  `<svg style="display:none"><symbol id="i-…">` en tête, consommés par `<use>` :
  `gauge` État · `layout-grid` Six dessins · `server` Carte · `database` Schéma ·
  `activity` Diagnostic · `route` Flow · `bell` Coffre & annonces · `flame` Forge ·
  `book-open` Stories · `user-round` Compte · `triangle-alert` Manège. **Zéro emoji dans
  la nav.**
- **Ordre** : *(sans libellé)* **État** `#etat` → **COMPRENDRE** six · carte · schema ·
  diag → **DOMAINES** flow · regles · forge · histoire · porte → **CAS D'ERREUR** manege.
  À droite des onglets qui portent un 🔴 : point 5 px `--men` + le nombre (JS).
- **390 px** (bascule à `max-width:900px`, le seul seuil du site aujourd'hui, L281) :
  barre `52px sticky top:0;background:rgba(0,0,0,.72);backdrop-filter:blur(20px);border-bottom:1px solid var(--filet)`
  = lune 20 px + titre de l'onglet courant 14/500 + bouton menu 36×36 ; tiroir = la
  même sidebar en `width:280px;transform:translateX(-100%)` → `0` en
  `220ms cubic-bezier(.2,.8,.2,1)` (transform seul), scrim `rgba(0,0,0,.60)` sans flou.
  Fermé au clic sur un item.

### 4.2 La pastille en verre (`.p`) — le HTML des 108 ne bouge pas, seule la feuille change

```css
.p{display:inline-flex;align-items:center;gap:6px;height:22px;padding:0 9px 0 7px;border-radius:999px;
   font:500 11px/1 Inter;letter-spacing:.02em;text-transform:none;color:rgba(255,255,255,.78);white-space:nowrap;
   background:linear-gradient(180deg,rgba(255,255,255,.08),rgba(255,255,255,.03));
   border:1px solid var(--filet-verre);box-shadow:inset 0 1px 0 rgba(255,255,255,.12);transition:border-color .14s}
.p:hover{border-color:rgba(255,255,255,.16)}
.p-ok,.p-loc,.p-srv,.p-abs,.p-men{ /* AUCUN fond ni bordure teintés : la couleur, c'est l'emoji (12 px) */ }
.p-cx{color:var(--encre-2);background:rgba(255,255,255,.035);border-color:rgba(255,255,255,.06);box-shadow:none}
```
- Fin du JetBrains Mono 10,5 px MAJUSCULES (le look « outil de dev ») et des 5 fonds
  teintés (le sapin). Le verre = dégradé `.08 → .03` + filet `.08` + reflet `.12`.
  L'emoji reste la seule couleur — c'est la loi du site, et ça garde `grep -c 'p-ok'`
  intact.
- Dans une table, la colonne pastille est **la première et étroite** : l'œil balaie une
  colonne de points, c'est la colonne « status » de Linear.
- Les **points d'état CSS** (bille de verre, 8 px) n'existent que là où il n'y a pas
  d'emoji : les pills du hero, les rangées de l'accueil, les cards :
  `background:radial-gradient(circle at 35% 30%,rgba(255,255,255,.55),transparent 45%),var(--c);box-shadow:inset 0 0 0 .5px rgba(255,255,255,.25),0 0 0 3px color-mix(in srgb,var(--c) 14%,transparent)`
  — variante **creuse** « non mesuré » : `background:transparent;box-shadow:inset 0 0 0 1px rgba(255,255,255,.28)`.

### 4.3 Le bouton obsidienne (`.obs`) — le slider (`NavMonolith.metal:549-838`) × le velours (`Theme.swift:341-378`)

```css
.obs{--mx:50%;position:relative;isolation:isolate;display:inline-flex;align-items:center;justify-content:center;height:44px;padding:0 24px;
  border-radius:999px;border:0;cursor:pointer;background:#000;
  background-image:radial-gradient(circle at var(--mx) 50%,rgba(255,255,255,.06),transparent 66px),                 /* lampe de surface, discrète */
                   linear-gradient(180deg,rgba(255,255,255,.10) 0 20%,rgba(255,255,255,0) 60%);                       /* le voile 10 % qui MEURT à 60 % — metal:617-621 */
  box-shadow:inset 0 0 0 3px #000,                     /* l'anneau d'obsidienne h×.056 — metal:612 */
             inset 0 1px 0 rgba(219,227,242,.12),      /* le cheveu de crête — metal:664-667 */
             0 10px 18px -4px rgba(0,0,0,.70),         /* Theme.swift:352 */
             0 0 18px rgba(0,0,0,.62);                 /* metal:816-819 */
  transition:box-shadow .16s,transform .12s}
.obs::before{content:"";position:absolute;inset:0;border-radius:inherit;padding:1.3px;pointer-events:none;   /* liseré de flanc : vif aux CALOTTES, éteint au milieu — metal:648-660 */
  background:linear-gradient(90deg,rgba(247,250,255,.24),transparent 22%,transparent 78%,rgba(247,250,255,.24));
  -webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);-webkit-mask-composite:xor;mask-composite:exclude}
.obs .lib{font:600 12px/1 Inter;text-transform:uppercase;letter-spacing:.18em;                                    /* Theme.swift:352-356 */
  background:radial-gradient(circle at var(--mx) 50%,rgba(255,255,255,.50),transparent 66px),                    /* LA LAMPE qui suit le pouce, masquée par le texte — SliderObsidienne.swift:373-383 */
             linear-gradient(180deg,rgba(255,255,255,.94),rgba(255,255,255,.54));                                /* encre .94 → .54 — :353-365 */
  background-blend-mode:screen;-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.obs:hover::before{background:linear-gradient(90deg,rgba(247,250,255,.37),transparent 22%,transparent 78%,rgba(247,250,255,.37))}  /* ×1,55 à l'armement — :269 */
.obs:active{transform:scale(.985)}
```
```js
// 3 lignes, pas de flou animé : un centre de radial-gradient qui bouge sur UN bouton
document.querySelectorAll('.obs').forEach(b=>{b.addEventListener('pointermove',e=>{const r=b.getBoundingClientRect();b.style.setProperty('--mx',(e.clientX-r.left)+'px')});b.addEventListener('pointerleave',()=>b.style.removeProperty('--mx'))});
```
- **Un seul par page.** Accueil : « Ouvrir dans Supabase ↗ » dans le hero — lien réel
  `https://supabase.com/dashboard/project/ytnnyjkramgiqyxdrkcu/editor` (vérifié : c'est
  le premier des 5 `.sb` de L406-410, là où elle édite `reward_rules` à la main). Onglet
  carte : le même. Nulle part ailleurs — pas de « Republier » (un bouton qui ne peut rien
  publier est un contrôle qui ment).
- L'ombre noire est invisible sur `#000` : le relief vient du voile + anneau + liseré.
  C'est voulu, comme sur le slider.

### 4.4 Pill de filtre, bouton secondaire, menu

```css
.pill{display:inline-flex;align-items:center;gap:6px;height:30px;padding:0 12px;border-radius:999px;font:500 12.5px Inter;color:var(--encre-2);
  background:rgba(255,255,255,.04);border:1px solid var(--filet-verre);transition:border-color .14s,color .14s}
.pill:hover{border-color:rgba(255,255,255,.16);color:rgba(255,255,255,.80)}
.pill.on{color:#fff;background:linear-gradient(180deg,rgba(255,255,255,.10),rgba(255,255,255,.05));border-color:rgba(255,255,255,.18);box-shadow:inset 0 1px 0 var(--reflet)}
.pill.on[data-etat]{background:color-mix(in srgb,var(--c) 14%,transparent);border-color:color-mix(in srgb,var(--c) 40%,transparent)}  /* verre teinté (Acme « Content ») */
.btn2{height:40px;padding:0 18px;border-radius:12px;font:500 14.5px Inter;color:var(--encre-1);background:rgba(255,255,255,.05);border:1px solid var(--filet-verre);box-shadow:inset 0 1px 0 rgba(255,255,255,.10)} /* Theme.swift:381-382 */
.menu>div{position:absolute;z-index:20;margin-top:6px;min-width:220px;padding:6px;border-radius:12px;background:linear-gradient(180deg,#1A1A1E,#101014);
  border:1px solid rgba(255,255,255,.10);box-shadow:0 12px 32px rgba(0,0,0,.60),inset 0 1px 0 rgba(255,255,255,.06)}   /* réf. 2 et 6 ; <details> natif, zéro JS */
.menu a{display:flex;gap:10px;align-items:center;height:32px;padding:0 10px;border-radius:8px;font:400 13px Inter;color:rgba(255,255,255,.80)} .menu a:hover{background:rgba(255,255,255,.06);color:#fff}
```

### 4.5 La card de domaine (`.dom`) — « Today's News »

```css
.dom{--t:255,255,255;position:relative;display:grid;grid-template-rows:auto 1fr auto;min-height:176px;padding:18px 20px 16px;border-radius:20px;
  border:1px solid var(--filet-verre);box-shadow:inset 0 1px 0 rgba(255,255,255,.10);overflow:hidden;transition:border-color .16s;
  background:repeating-linear-gradient(90deg,rgba(255,255,255,.025) 0 1px,transparent 1px 28px),          /* les fines rayures verticales */
             linear-gradient(155deg,rgba(var(--t),.26) 0%,rgba(var(--t),.06) 45%,#0A0A0A 100%)}          /* la teinte part du coin haut-gauche et meurt dans le noir */
.dom:hover{border-color:rgba(255,255,255,.16)}
.dom.men{--t:229,106,106}  .dom.ok{--t:95,201,140}  /* neutre = blanc à .10 : l'argent de la card « bearish » */
.dom .sur{font:500 11px Inter;letter-spacing:.08em;text-transform:uppercase;color:var(--encre-2)}        /* le domaine */
.dom h3{margin:14px 0 0;font:500 24px/1.15 Inter;letter-spacing:-.02em;max-width:14ch}                    /* + .encre .encre-titre : « 5 briques mentent » */
.dom .sous{margin-top:6px;font:400 12.5px Inter;font-variant-numeric:tabular-nums;color:var(--encre-2)}   /* « 12 briques · 5 ment · 6 absent · 1 branché » avec des points CSS, pas des emoji */
.dom .seg{display:flex;gap:6px;margin-top:16px} .dom .seg i{flex:1;height:2px;border-radius:2px;background:rgba(255,255,255,.15)} .dom .seg i.on{background:rgba(255,255,255,.90)}
.dom .aller{position:absolute;top:14px;right:14px;width:32px;height:32px;border-radius:999px;display:grid;place-items:center;color:rgba(255,255,255,.85);
  background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.12);box-shadow:inset 0 1px 0 var(--reflet)}  /* ↗ 14 px stroke 1.5 → montrer(onglet) */
```
- **Teinte = une règle, pas un goût** : **rouge** si le domaine porte ≥ 1 🔴 ; **vert** si
  tout est 🟢 ; **argent** (neutre) sinon — pas d'ambre ni de bleu (4 rouges + 2 ambre
  + 1 bleu serait un sapin ; rouge/vert/argent est exactement la référence).
- Segments allumés = `floor(4 × 🟢 / total)` du domaine — jamais arrondi vers le haut.
- Grille : 3 colonnes à 1440 (`gap:12px`, ≈ 2 rangs pour 7 cards) ; à 390 **une bande
  horizontale** (`flex; overflow-x:auto; scroll-snap`, cards `flex:0 0 264px`) — 7 cards
  empilées feraient 1 200 px avant la liste.

### 4.6 Le hero aurore (`.hero`) — l'aurore de l'app, tournée vers le haut

```css
.hero{position:relative;isolation:isolate;overflow:hidden;height:360px;padding:56px 40px 32px;background:#000}
.hero::before{content:"";position:absolute;inset:0;z-index:-2;background:
  radial-gradient(60% 70% at 48% -10%,#FFE699 0%,rgba(255,230,153,0) 60%),                                   /* AU_CREME, le cœur */
  radial-gradient(90% 80% at 50% -15%,#FF8A3D 0%,rgba(255,138,61,.55) 38%,rgba(255,138,61,0) 72%),          /* AU_BASE, le pic */
  radial-gradient(45% 55% at 12% 4%,rgba(255,122,46,.50),rgba(255,122,46,0) 70%),                            /* épaule x .122 — metal:601 */
  radial-gradient(50% 60% at 84% 8%,rgba(199,201,214,.22),rgba(199,201,214,0) 70%),                          /* épaule x .833 — ARGENT, pas bleu */
  linear-gradient(180deg,#210C03 0%,#000 100%)}                                                              /* le plancher rouge-brun = le « rouge/brun » de Workspace */
.hero::after{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(180deg,rgba(0,0,0,0) 34%,rgba(0,0,0,.62) 66%,#000 100%)}   /* noir ABSOLU à 360 px : rien ne déborde sur les cards */
.hero .grain{position:absolute;inset:0;z-index:-1;opacity:.05;mix-blend-mode:overlay;background:url("data:image/svg+xml,…feTurbulence baseFrequency='.8'…") 0 0/200px 200px}  /* la trame metal:632-637 ; le seul remède au banding orange→noir sur OLED */
.glyphes{position:absolute;inset:0;z-index:-1;margin:0;padding:24px 32px;columns:440px;column-gap:40px;overflow:hidden;pointer-events:none;user-select:none;
  font:400 11px/18px ui-monospace,monospace;color:rgba(255,255,255,.06);white-space:pre;
  -webkit-mask-image:radial-gradient(80% 70% at 50% 40%,#000 30%,transparent);mask-image:radial-gradient(80% 70% at 50% 40%,#000 30%,transparent)}
```
- Contenu du `<pre class="glyphes" aria-hidden>` : 6 **vraies** lignes de
  `supabase/migrations/20260829120000_annonces.sql` (L96-98, 108, 110, 140, 152 :
  `insert into public.reward_rules (key, value) values ('popups_max_seance', '4'::jsonb) …`)
  répétées 4× ; les colonnes CSS les répartissent, sans JS. C'est le champ de glyphes de
  « Ask anything », mais c'est notre code.
- Déclarer la pile `background` une première fois sans `in oklch`, puis une seconde avec
  (`radial-gradient(in oklch, …)`) : la chroma tient entre orange et crème (loi anti-brun
  « R reste à 1,00 », `woop-architecture` §verre) et une déclaration invalide n'annule
  pas tout. Fins en `rgba(teinte,0)`, jamais `transparent` (gris de passage).
- **390 px** : `height:260px;padding:36px 20px 24px`, les 2 épaules supprimées (elles se
  superposent au pic et brûlent), pic `at 50% -20%`.
- **Ailleurs : aucun halo.** Les 10 autres onglets ouvrent sur du `#000` — c'est la
  retenue qui rend l'accueil précieux.

### 4.7 La liste (`.liste`) — la rangée Linear

```css
.liste li{display:grid;grid-template-columns:22px minmax(0,1fr) auto 18px 44px minmax(0,230px) 16px;gap:12px;align-items:center;height:44px;padding:0 12px;
  border-bottom:1px solid var(--filet);border-radius:8px;cursor:pointer;box-shadow:inset 0 0 0 1px transparent;transition:background-color .14s,box-shadow .14s}
.liste li:hover{background:rgba(255,255,255,.03);box-shadow:inset 0 0 0 1px var(--filet)} .liste li:hover .chev{opacity:.6;transform:translateX(2px)}
.liste .pt{width:8px;height:8px;border-radius:50%}                                           /* la bille 4.2 ; creuse si data-etat=nm ; anneau pointillé si data-litige */
.liste .t{font:400 13px Inter;color:rgba(255,255,255,.86);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}   /* ≤ 60 caractères */
.liste .d{font:400 11px Inter;color:var(--encre-3)}                                          /* nom du domaine, masqué < 900 px */
.liste .bd{width:18px;height:18px;border-radius:5px;background:rgba(255,255,255,.05);border:1px solid var(--filet-verre);font:600 8.5px/16px Inter;letter-spacing:.04em;color:var(--encre-2);text-align:center}  /* ÉC CH ST AN FO CO SY — le badge 18 px d'Acme */
.liste .c,.liste code{font:400 10.5px ui-monospace,monospace;color:var(--encre-3);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}   /* coût en toutes lettres « 1 h · 1 j · chantier » ; preuve fichier:ligne */
.liste .chev{width:16px;height:16px;stroke:currentColor;stroke-width:1.5;opacity:.25;transition:opacity .14s,transform .14s}
.liste .grp{position:sticky;top:0;height:30px;display:flex;align-items:center;gap:8px;background:#000;border-bottom:1px solid var(--filet);font:500 11px Inter;letter-spacing:.08em;text-transform:uppercase;color:var(--encre-2)}
@media(max-width:900px){.liste li{grid-template-columns:22px 1fr 16px;grid-template-areas:"pt t chev" ". m chev";height:58px} /* ligne 2 = badge + coût + preuve ellipsés */}
```
Les tableaux existants des onglets reçoivent la même robe **sans réécrire un seul
`<tr>`** : `tr{height:44px} td{padding:0 12px;border-bottom:1px solid var(--filet);font:400 13px Inter;color:rgba(255,255,255,.86)} th{font:500 11px Inter;letter-spacing:.08em;text-transform:uppercase;color:rgba(255,255,255,.40)} tr:hover td{background:rgba(255,255,255,.03)}`.

### 4.8 Les images du flow (`.flow`)

```css
.flow{display:flex;gap:20px;padding:8px 0 0;overflow-x:auto;scroll-snap-type:x mandatory;scrollbar-width:none;
  -webkit-mask-image:linear-gradient(90deg,transparent,#000 6%,#000 94%,transparent);mask-image:linear-gradient(90deg,transparent,#000 6%,#000 94%,transparent)}
.ecran{flex:0 0 300px;margin:0;scroll-snap-align:start}
.ecran img{display:block;width:300px;aspect-ratio:1206/2622;border-radius:28px;border:1px solid var(--filet-verre);
  -webkit-mask-image:linear-gradient(180deg,#000 55%,transparent 100%);mask-image:linear-gradient(180deg,#000 55%,transparent 100%)}  /* le fondu noir — jamais un voile (qui grise) */
.ecran figcaption{margin-top:-120px;font:500 11px Inter;letter-spacing:.08em;text-transform:uppercase;color:var(--encre-3);text-align:center}
```
- Toutes les captures du dépôt sont en **1206×2622** ; réduites à 300 px de large en
  JPEG q78 ≈ 40 Ko chacune, en **data URI** (un seul fichier, CSP de l'artefact).
  Budget : ≤ 60 Ko par image, ≤ 700 Ko au total (garde-fou dans le script).
- **Prêtes aujourd'hui (4)** : home `tools/road/shots/j4-home-serpentin.png` · chemin
  `road-2-etats-etape5.png` · départ `road-1-branchee.png` · STOP
  `tools/stop/captures/stop-134059.png` (fond `#000` pur, se fond parfaitement).
- **À capturer (8)** : porte · player · page exo (l'archive `tools/verre/archives/…/g9-ferme.png`
  est le vieux verre) · BRAVO · story · coffre (v1 seulement) · booster · calendrier ·
  profil — bancs `-porteLab -ipodLab -exoLab -bravoLab -storyLab -coffreLab -boosterLab -calLab -profilLab`,
  **UN build, N lancements** (jamais deux builds sur le même DerivedData), `-skipAuth`
  pour tous sauf `-porteLab`, **pas de `-demoData`** (il sème une séance ouverte
  persistante). → jalon J4, **attend son feu vert** (la machine était saturée le 29-08).
- Je ne peux pas générer d'images raster : le flow sera fait de **vraies captures**,
  fondues au noir par le masque. C'est plus honnête et plus beau qu'un rendu inventé.

### 4.9 Mermaid — UN thème, plus 19

- Retirer les 19 directives `%%{init:…}%%` (comptées : 19) et les `classDef` en dur
  (`#12251B #2A2410 #152233 #2A1618 #1A1922`) ; **garder** les 31 lignes `class A,B ok`
  (comptées : 31 ; aucune forme `:::ok`).
- Remplacer L1632-1643 par un seul `initialize({theme:'base', fontFamily:'Inter',
  themeVariables:{background:'#000', primaryColor:'#121212', primaryTextColor:'#E8E8E8',
  primaryBorderColor:'#2A2A2A', lineColor:'#5C5C5C', mainBkg:'#121212', nodeBorder:'#2A2A2A',
  clusterBkg:'#070707', edgeLabelBackground:'#000', actorBkg:'#121212', noteBkgColor:'#1A1608',
  noteBorderColor:'#E3B341', attributeBackgroundColorOdd:'#0E0E0E', attributeBackgroundColorEven:'#121212'},
  themeCSS:'.node rect{rx:10;stroke-width:1px} .node.ok rect{fill:#0C1A12;stroke:rgba(95,201,140,.55)} .node.loc rect{fill:#1A1608;stroke:rgba(227,179,65,.55)} .node.srv rect{fill:#0C1620;stroke:rgba(90,169,230,.55)} .node.abs rect{fill:#121212;stroke:rgba(142,142,147,.55);stroke-dasharray:4 3} .node.bad rect{fill:#1C0E0F;stroke:rgba(229,106,106,.55)}'})`
  — `themeVariables` en **hex seulement** (khroma dérive des teintes, un `rgba` casse
  `darken()`). La couleur reste l'état dans le dessin.
- **À vérifier sur le schéma #1 (L370) AVANT de toucher aux 18 autres** : qu'un
  `class A ok` sans `classDef` pose bien la classe sur `g.node`. Repli : une ligne
  `classDef ok stroke-width:1px` par classe. Le `stateDiagram-v2` (#13, L1142) garde son
  `classDef` (DOM différent) tant que ce n'est pas vérifié.
- Conteneur : `figure{background:#050505;border:1px solid var(--filet);border-radius:16px;padding:18px}`
  — plus de `.bloc` bordé autour (fin de la card dans la card).

---

## 5. Écran 1 — l'accueil « État » (`<section class="page on" id="etat">`, page par défaut)

### 5.1 Composition à 1440 × 900 (ce qu'on voit dans les 3 premières secondes)

```
┌─240─────────┬────────────────────────────────────────────────────────────────┐
│ ☾ Woop      │  ░░░░░░░░ aurore crème→orange→rouge-brun→noir (0→360) ░░░░░░░ │
│  chambre…   │  ·insert into reward_rules ('popups_max_seance','4'::jsonb)·   │ ← glyphes à 6 %
│             │  BACK-END · ÉTAT VÉRIFIÉ                                       │ 11 px +.08em .42
│ ◉ État    11│  Ce qui marche,                                                │ 40 px 300, --titre
│             │  ce qui ment, ce qui manque.                                   │
│ COMPRENDRE  │  Chaque pastille a été lue dans le code. Rien n'est déduit.    │ 15 px .54
│ ▫ 6 dessins │                                                                │
│ ▫ Carte     │  (● 35 branchées)(● 5 locales)(● 30 serveur seul)(○ 27 absentes)(● 11 mentent)(◌ 22 à mesurer)   ← 6 pills de verre (blur) = filtres
│ ▫ Schéma    │                                              [ OUVRIR DANS SUPABASE ↗ ]  ← l'obsidienne
│ ▫ Diagnostic│ ───────────────────────────────────────────────────── 360 px ── noir absolu
│             │ ┌ COMPTE ──── rouge ┐ ┌ ÉCONOMIE ── rouge ┐ ┌ ANNONCES ── rouge ┐         │
│ DOMAINES    │ │ 5 briques          │ │ 3 briques         │ │ 1 brique          │  ↗     │ 24 px, --titre
│ ▫ Flow     1│ │ mentent            │ │ mentent           │ │ ment              │        │
│ ▫ Coffre &  │ │ 12 · 5● 6○ 1●      │ │ 14 · 3● 4● 5○     │ │ 9 · 1● 5● 3○      │        │ 12,5 tabular
│   annonces  │ │ ▬ ▭ ▭ ▭            │ │ ▬ ▭ ▭ ▭           │ │ ▭ ▭ ▭ ▭           │        │ 4 segments
│ ▫ Forge    2│ └────────────────────┘ └───────────────────┘ └───────────────────┘        │
│ ▫ Stories   │ ┌ FORGE ───── rouge ┐ ┌ CALENDRIER · argent┐ ┌ SYNC ──── argent ┐ ┌ STORIES · argent ┐
│ ▫ Compte   5│ …                                                                         │
│             │ ─────────────────────────────────────────────────────────── ~ 900 px ─────
│ CAS D'ERREUR│ (Tout)(Économie)(Chemin)(Stories)(Annonces)(Forge)(Compte)(Sync)          ← pills de domaine
│ ▫ Manège    │ MENT · 10 ─────────────────────────────────────────────────────────────
│             │ ● Une porte qui écrit la session — woop.phone jamais écrit  Compte CO 1 h  Supabase.swift:27-35  ›
│ ┌─────────┐ │ ● Le mur du profil « N / 4 » ment tant qu'il lit la mémoire  Forge  FO 1 j  SacreAccueil.swift:12-13 ›
│ │ Un état │ │ …                                                                          44 px chacune
│ │ se véri-│ │ À MESURER · 22 ─────────────────────────────────────────────────────────
│ │ fie…    │ │ ◌ SupabaseSync n'a qu'un push : écrire pull                  Sync  SY chantier SupabaseSync.swift:70 ›
│ │ 🟢🟡🔵⚪🔴 │ │ …
│ │ 29 août │ │ LE FLOW ── [porte] [home] [chemin] [départ] [player] … captures fondues au noir
│ └─────────┘ │ pied : une seule date
└─────────────┴────────────────────────────────────────────────────────────────┘
```
Au-dessus du pli : le titre, les 6 nombres, 3 cards rouges. **Trois rouges, zéro
verte — c'est le verdict, et il est honnête.** Rien d'autre : pas de légende de 8
badges, pas de schéma, pas de chapo, pas de capture, pas d'emoji hors pastille.

**À 390 × 844** : barre 52 → hero 260 (titre 30/34 sur 2 lignes) → les 6 pills en
défilement horizontal (`scroll-snap`, 128 px) → cards en bande horizontale 264 px →
la liste sur 2 lignes (58 px), groupes 🔵/⚪ en `<details>` fermés → `scrollWidth === 390`.

### 5.2 Le contrat JS (≈ 40 lignes, remplace la légende collante) — le site ne peut pas mentir sur lui-même

1. **Les compteurs ne sont jamais tapés à la main** :
   `n = k => document.querySelectorAll('.page:not(#etat) .p.p-'+k).length` pour
   `ok loc srv abs men` → 35/5/30/27/11 aujourd'hui. Le hero porte `data-attendu="108"` :
   si la somme diffère, une 7ᵉ pill rouge pointillée apparaît « ⚠ 107 ≠ 108 attendues ».
2. **L'état d'une rangée n'est pas écrit dans la rangée** : chaque `<li data-src="b-…">`
   pointe vers l'`id` de la pastille source dans son onglet ; le JS lit sa classe `.p-*`
   et pose `data-etat`. Pas de source → `data-etat="nm"` (bille creuse « à mesurer ») +
   `console.warn`. `data-litige="1"` → bille de l'état du site + anneau pointillé.
   **La page `#etat` ne contient aucun `.p.p-*`** : le compte 35/5/30/27/11 ne bouge pas
   par construction.
3. **Cards** : les pastilles des onglets reçoivent `data-dom="eco|chemin|stories|annonces|forge|compte|sync"`
   (sur le `<tbody>`/`<section>` quand la table est homogène, sur le `<tr>` sinon —
   mapping en §5.3) ; par domaine : total, 🟢, présence d'un 🔴 → teinte, phrase du pire
   état, segments `floor(4×🟢/total)`.
4. **Filtres** : deux `Set` (état, domaine), `li.hidden`, groupes vides masqués,
   compteurs de groupe = `li:not([hidden])`. Clic sur une rangée → `montrer(onglet)` +
   `scrollIntoView` sur `#b-…` + `outline` 1,2 s qui s'éteint.
5. **Nav** : point 5 px + nombre de `.p-men` par onglet.

### 5.3 Attribution des domaines (`data-dom`) — pour les cards

carte : `coin_ledger user_boosters reward_rules booster_progress` + les 12 fonctions
d'argent + `pieces_* prix_* rare_*` → `eco` · `workouts logged_exercises strength_sets cardio_phases`
→ `sync` · `cards user_cards forge-card` → `forge` · `syntheses weekly-synthesis` →
`stories` · `regles_annonces` + les 15 clés 🔵 de rythme + `welcome_*` → `annonces`.
schema : idem par table. diag : par cible. flow → `chemin` sauf L921 `stories`, L923 `eco`,
L924-925 `annonces`. regles → `annonces` sauf L1122-1126 `eco`. forge → `forge`.
histoire → `stories` sauf L1325 `sync`. porte → `compte`. manege → `forge`.
Aujourd'hui : **Compte, Économie, Annonces, Forge = rouge ; Calendrier-chemin, Sync,
Stories = argent.** Ordre des cards = les bloqueurs d'abord (§5.5) : Compte · Sync ·
Économie · Annonces · Forge · Calendrier · Stories.

### 5.4 La légende

Quitte le haut (`.legende` L319-329, son `backdrop-filter` L143, le
`scroll-margin-top:72px` L94 → 16). Elle vit dans **la card du bas du rail** (et au bas
du tiroir à 390) : « Un état se vérifie, il ne se déduit pas. » 12/500 `.86` ·
« 108 pastilles · dernière passe 29 août 2026 » 11/400 `.42` (JS + une constante) · les
5 pills `.p` hors `.page` (donc hors compte, exactement comme aujourd'hui) · les 3 coûts.

### 5.5 LE CONTENU — les 67 rangées (73 pastilles non vertes du site + 58 issues lues dans le code, dédoublonnées)

Conventions : **état = celui du site** (ligne `L…` = l'`id` à poser sur la source) ·
**◌ = à mesurer** (rien sur le site, ou « ? ») avec entre parenthèses ce que le code
laisse lire — **à mesurer, pas à peindre** · **⚑ = litige** : le site et le code se
contredisent sur un FAIT (déployé / appelé) — la pastille du site reste, la rangée
porte l'anneau pointillé. Domaines : ÉC Économie · CH Calendrier-chemin · ST Stories ·
AN Annonces · FO Forge · CO Compte · SY Sync. Coût : 1 h · 1 j · chantier.

| # | titre (≤ 60) | dom | état · source | coût | preuve | onglet |
|---|---|---|---|---|---|---|
| 1 | Faire lire `etat_coffre()` à la home et au profil | ÉC | 🔴 L870 | 1 h | ProfilLune.swift:129 · HomeAuroraView.swift:246 · HomeNuit.swift:2279 | regles |
| 2 | Le sachet noir n'est jamais consommé (compteur qui ne descend pas) | ÉC | 🔴 L871 | 1 h | SacreServeur.swift:325 · 20260829150000_ouvrir_booster.sql | manege |
| 3 | `ouvrir_booster` : 🟢 sur le site, « NON DÉPLOYÉE » dans le code | ÉC | 🟢 ⚑ L460 | 1 h | SacreServeur.swift:325-326 · EconomieWoop.swift:274-279 | carte |
| 4 | `claim_booster_legendaire` : appelée (:109), répond 500 P0002 | ÉC | 🔵 ⚑ L467 | 1 h | SacreServeur.swift:109 · PLAN-REWARDS-BACKEND.md:1320-1324 | carte |
| 5 | `solde_argent` : « sans appelant » sur le site, appelée en :99 | ÉC | 🔵 ⚑ L466 | 1 h | SacreServeur.swift:99 | carte |
| 6 | Retirer `solde_noir()` et `solde_or()` — jamais appelées du client | ÉC | ⚪ L468 | 1 h | booster_noir.sql:191 · gains_coffre.sql:25 | carte |
| 7 | Clés `rare_*` « cachées » — mais `reward_rules` est lue en REST | ÉC | 🟢 ⚑ L510 | 1 j | SacreServeur.swift:402 · annonces.sql:179 · PLAN-REWARDS-BACKEND.md:1272-1275 | carte |
| 8 | `booster_progress` : table morte — supprimer ou réalimenter | ÉC | ⚪ L446 | 1 h | wallet_coffre.sql:50 · annonces.sql:24,46 | carte |
| 9 | Constantes locales à retirer : perSeries 20, +20, retour 10 | ÉC | ◌ (🟡) | 1 h | CoffreFortPurse.swift:28-29 · BravoLab.swift:642 · ExerciseDetailView.swift:2269-2270 | regles |
| 10 | Trancher la conversion automatique pièces → sachets | ÉC | ◌ (⚪) | 1 j | coffre-rewards.md:287-292 · BACKEND-COFFRE.md:114-123 | regles |
| 11 | Trancher le fuseau du « jour » (UTC vs profil) | ÉC | ◌ (🟡) | 1 j | SacreServeur.swift:248-253 · coffre-rewards.md:254-262 | regles |
| 12 | Policies d'écriture des tables wallet / boosters | ÉC | ◌ (?) | 1 j | SUPABASE-A-FAIRE.md:113-114 | carte |
| 13 | Le coffre n'est pas dans le parcours (la pop-up part au manège) | ÉC | ⚪ L923 | 1 h | preuve à citer | flow |
| 14 | Profil : noir caché à 0, or sans place, argent et géant absents | ÉC | ⚪ L1123 (+1124-1126) | 1 h | preuve à citer | regles |
| 15 | Le jour d'une séance : `endedAt` local, jours « faits » en démo | CH | 🟡 L1012 (+h3 L1005) | 1 h | AUDIT-CHEMIN-CALENDRIER-STORIES.md:51-58 · BUGS-RESTANTS.md:467-469 | flow |
| 16 | Le retour au CHEMIN après « Terminer » n'existe pas | CH | ⚪ L922 | 1 h | preuve à citer | flow |
| 17 | Récompense déjà réclamée : lue au serveur, tour complet pas vu | CH | 🔵 L1017 (sonde 200 `[]`) | — | SacreServeur.swift:380 · site L1032 | flow |
| 18 | Chapitre 1 / sur 9 : du serveur ; où il commence : nulle part | CH | 🔵 L1022 | chantier | regles_chemin.sql:16-23 · duolingo-chemin.md:304-307 | flow |
| 19 | Trancher « un nœud = un jour » vs « = une séance » | CH | ◌ (🔴) | chantier | AUDIT…:92-114 | flow |
| 20 | Sticker : même choix sur les deux écrans, et une source | CH | ◌ (🔴 / ⚪) | 1 h | AUDIT…:69-86 | histoire |
| 21 | Définir « fait », « parfait », et l'après-35 séances | CH | ◌ (⚪) | 1 j | duolingo-chemin.md:308-316 | flow |
| 22 | Remonter le tirage du chemin, la pitié et le journal par nœud | CH | ◌ (🟡) | 1 j | RewardChemin.swift:73-76, 123-145 · duolingo-chemin.md:277-292 | flow |
| 23 | Un moteur de faits (`workout_facts` → 404) | ST | ⚪ L1320 (sonde 404) | chantier | AUDIT…:122-124 · site L1339 | histoire |
| 24 | Brancher TOP SESSION + les pages record muscu / cardio | ST | ⚪ L1321 (+1322, diag L874) | 1 j | preuve à citer (L1306) | histoire |
| 25 | Le variant décidé et mémorisé au serveur | ST | ⚪ L1323 | 1 j | preuve à citer (L1311) | histoire |
| 26 | Point d'entrée de la story en fin de séance | ST | ⚪ L921 (+L1324) | 1 j | AUDIT…:120-121 | flow |
| 27 | Écrire `narrate-reward` (contrat JSON + bornes) | ST | ◌ (⚪) | chantier | reward-popup.md:226, 243-255 | histoire |
| 28 | `weekly-synthesis` : 🔵 sur le site, « pas déployée » au README | ST | 🔵 ⚑ L519 | 1 h | supabase/README.md:51 · SynthesisService.swift:109 | carte |
| 29 | `ProgressionView` jamais montée ; `syntheses` à monter ou supprimer | ST | 🔵 L716 (+L445) | 1 h | ProgressionView.swift:14 · 0001_init.sql:77 | schema |
| 30 | Deux annonces s'enchaînent (capsule +1,6 s, pop-up +5,2 s) | AN | 🔴 L925 | 1 h | preuve à citer | flow |
| 31 | La pop-up booster est un overlay monté sur la home | AN | 🟡 L924 | 1 j | preuve à citer | flow |
| 32 | Appeler `regles_annonces()` — personne ne l'appelle | AN | 🔵 L465 | 1 j | annonces.sql:174 · 0 appel Swift | carte |
| 33 | Les 17 clés de rythme : en base, lues par personne | AN | 🔵 L1064 (+15 clés L495-509) | chantier | annonces.sql:98-151 | regles |
| 34 | Clés `welcome_*` (30-08) : 🔵 sur le site, aucune sonde HTTP | AN | 🔵 ⚑ L506 (+507-508) | 1 j | 20260830090000_welcome_chaque_connexion.sql:37-44 · ANALYSE-WELCOME-BACK.md:43-47 | carte |
| 35 | Welcome Back : porte de prod, bouton Claim, `PiecesNotif` | AN | ⚪ L1095 | 1 j | ANALYSE-WELCOME-BACK.md:90-99 · reward-popup.md:223 | regles |
| 36 | Créditer les pop-ups `.moment` / `.reward` | AN | ◌ (🔴) | 1 j | reward-popup.md:222 | regles |
| 37 | `DecideurSerie` (10/5/3 %) → moteur serveur + facts dans l'outbox | AN | ◌ (🟡) | chantier | reward-popup.md:220 · OutboxGains.swift:42-51 | regles |
| 38 | Trancher `notif_consomme_budget` et `ecart_exige_les_deux` | AN | 🔵 L499 (+L502) | 1 h | PLAN-REWARDS-BACKEND.md:1315-1318 | carte |
| 39 | Le contrat par catégorie (quelle robe pour quel événement) | AN | ◌ (⚪) | 1 j | reward-popup.md:224 | regles |
| 40 | Le mur du profil « N / 4 » ment tant qu'il lit la mémoire | FO | 🔴 L1193 | 1 j | SacreAccueil.swift:12-13, 48 | forge |
| 41 | Le set défini à un seul endroit (Swift + Deno + totaux) | FO | 🔴 L1195 | 1 j | SUPABASE-A-FAIRE.md:36-39, 101-106 | forge |
| 42 | Lire `user_cards` — `ma_collection()` + `CollectionStore` | FO | 🔵 L1192 (+L444, L715, L872) | 1 j | SUPABASE-A-FAIRE.md:45-54 | forge |
| 43 | Passer `booster_id` à `forge-card` (sceller, garantie légendaire) | FO | ⚪ L1190 (+L1163, L1191) | 1 h | ForgeServeur.swift:39-43 · BoosterLab.swift:2260 · WoopApp.swift:1222-1223 | forge |
| 44 | Passer `workout_id` à `forge-card` (colonne toujours nulle) | FO | ◌ (🟡) | 1 h | ForgeServeur.swift:36 | forge |
| 45 | Les doublons comptés en base (raison `doublon` jamais écrite) | FO | ⚪ L1194 | 1 h | SUPABASE-A-FAIRE.md:115-117 | forge |
| 46 | Garde d'idempotence serveur sur `forge-card` | FO | ◌ (⚪) | 1 j | SUPABASE-A-FAIRE.md:78-82 | forge |
| 47 | Cache disque des PNG ; générer `depth_path` (null partout) | FO | ◌ (⚪) | 1 j | SUPABASE-A-FAIRE.md:56-60, 109-111 | forge |
| 48 | Manège interrompu : rien ne le détecte (marqueur, reprise, pop-up) | FO | ⚪ L1505 | 1 h | preuve à citer | manege |
| 49 | Fermer la sortie par le chevron (ne consomme pas le sachet) | FO | ◌ (coût seul L1564) | 1 h | preuve à citer (L1510) | manege |
| 50 | Rattrapage hors-ligne du booster (l'outbox ignore la forge) | FO | ◌ (⚪) | 1 j | OutboxGains.swift:42-51 · SUPABASE-A-FAIRE.md:91-94 | manege |
| 51 | Une porte qui écrit la session — `woop.phone` n'est jamais écrit | CO | 🔴 L1442 (+L396, diag L869) | 1 h | Supabase.swift:27-35 | porte |
| 52 | Identifiants, mot de passe dérivable, clé anon : hors du binaire | CO | 🔴 L1446 | chantier | Supabase.swift:11,16,27-35 · ForgeServeur.swift:15-16 | porte |
| 53 | Le jeton dans le Keychain (part dans les sauvegardes) | CO | 🔴 L1447 | 1 h | preuve à citer | porte |
| 54 | « Supprimer mon compte » ne supprime rien (bloquant App Store) | CO | 🔴 L1448 | 1 j | preuve à citer | porte |
| 55 | « Se déconnecter » : plus aucun écran pour rentrer | CO | 🔴 L1449 | 1 h | preuve à citer | porte |
| 56 | Sign in with Apple : capability, entitlements, provider | CO | ⚪ L1444 | chantier | aucun `.entitlements` dans le dépôt | porte |
| 57 | Création de compte réelle (signup, OTP ou magic link) | CO | ⚪ L1445 | 1 j | preuve à citer | porte |
| 58 | Une table de profil (nom, avatar, fuseau) | CO | ⚪ L1450 | 1 j | preuve à citer (« Kathryn » en dur ×3) | porte |
| 59 | Dire à l'écran qu'on n'est pas connectée | CO | ⚪ L1451 | 1 h | décision ① L1458 | porte |
| 60 | Migrer la maquette locale vers le compte | CO | ⚪ L1452 | chantier | preuve à citer | porte |
| 61 | Retirer le repli `jwtBanc()` du chemin de production | CO | ◌ (🔴) | 1 h | ForgeServeur.swift:90-100 · BoosterLab.swift:2253-2260 | porte |
| 62 | Sortir le token perso du compte pro (`.secrets`) | CO | ◌ (🔴) | 1 h | SUPABASE-A-FAIRE.md:7-12 · supabase/README.md:6-21 | porte |
| 63 | Valider le JWT dans `weekly-synthesis` (préfixe seul) | CO | ◌ (?) | 1 h | reward-popup.md:241 | carte |
| 64 | `SupabaseSync` n'a qu'un `push` : écrire `pull` (workouts + enfants) | SY | 🟡 L1325 | chantier | SupabaseSync.swift:70 · AUDIT…:147-149 | histoire |
| 65 | Commiter les 3 migrations en `??` (…160000, …170000, …090000) | SY | ◌ (🔵) | 1 h | `git status` | carte |
| 66 | Réparer `schema_migrations` avant tout `db push` | SY | ◌ (🔴) | 1 h | supabase/README.md:34-44 | carte |
| 67 | `cardio_phases` : à retravailler (décision 29-08) | SY | ⚪ L442 | — | preuve à citer | carte |

Décompte : 10 🔴 (les 11 pastilles → L396 est un renvoi vers #51) · 3 🟡 (5 pastilles :
L869 et L1005 sont des doublons) · 11 🔵 dont 4 ⚑ · 19 ⚪ · 2 🟢 ⚑ · 22 ◌.
**6 litiges site ↔ code, à mesurer avant de repeindre** : #3 `ouvrir_booster` (🟢 /
« NON DÉPLOYÉE » `SacreServeur.swift:325`) · #4 `claim_booster_legendaire` (« sans
appelant » / appelée `:109`) · #5 `solde_argent` (idem `:99`) · #7 `rare_*` (« jamais
exposées » / `reward_rules` en `select` `:402`) · #28 `weekly-synthesis` (🔵 / « PAS
déployée » README:51) · #34 `welcome_*` (🔵 / aucune sonde du 30-08).
Les 14 « preuve à citer » sont une dette **visible et voulue** (le README exige un
`fichier:ligne`, le site n'en a aucun).

**Dépendances (l'ordre des cards)** : #64 `pull` bloque #15, #19, #20, #23, #26 ·
#19 bloque #18, #21 · #23 bloque #24-27, #37, #39 · #1 bloque #9 · #2/#3 bloquent #43
→ #46, #42 · #32 bloque #33, #34, #38 · #66 bloque #65, #3 · #52 bloque #61.

---

## 6. Les onglets — ce qui change, ce qu'on coupe, ce qui reste

**Ordre dans chaque onglet** : h1 (28/500, `--titre`) → *slot* bande d'images 200 px
(quand une capture existe) → **la liste / les tables** (robe 4.7) → les schémas
(4.9) → `<details class="savoir">` « Ce qu'il faut savoir · N lignes » (la prose
survivante, `p{max-width:62ch;font:400 13.5px/1.55 Inter;color:rgba(255,255,255,.72)}`).
**Chaque onglet ouvre sur un tableau ou un schéma, jamais sur un chapo.**

| # | on coupe | remplacé par |
|---|---|---|
| 1 | les 25 prompts `dl.prompts` L1223-1270 (6 800 car.) | un `<details>` plié « Les 25 prompts du set » + lien `tools/carte-lune/PROMPTS.md` — zéro poids visuel, rien de perdu |
| 2 | L1219 (prompt d'image, 529 car.) | rien |
| 3 | L1346, L1347, L1006, L1025 (récits) | « un seul chantier bloque deux écrans » · lien `AUDIT-CHEMIN-CALENDRIER-STORIES.md` · rien · rien |
| 4 | L1342 dilué | « `SupabaseSync` n'a qu'un `push` » |
| 5 | L394 + L395 (doublons de L1358 et du schéma L1401) | rien — le schéma dit déjà la chaîne |
| 6 | les 6 cards pédagogiques L339-364 (emoji 26 px) | 6 légendes ≤ 70 car. sous les 6 dessins |
| 7 | « aujourd'hui / depuis aujourd'hui / le 29-08 » ×11 (L441, 460, 981, 1006, 1017, 1022, 1092, 1174, 1331, 1359, 1515) | dates absolues en `<time>` 12 px `.42`, ou rien ; rail et pied lisent UNE constante JS |
| 8 | 11 des 15 `.verdict/.trancher` (récit de méthode) | rien, ou une pastille + une ligne ; les 4 vrais restent en `.decision` (filet gauche 2 px `rgba(242,191,83,.6)`) |
| 9 | commentaires de méthode L795, L1032, L1337 | un seul `<details>` « Méthode » en pied |
| 10 | les 18 emoji de titres (§2-1) | l'emoji sort du `h*` (il vit dans la pastille ou le nœud) |
| 11 | Bricolage, Instrument Sans, JetBrains Mono, `#0A090E`, `--platine/--or/--corail/--argent`, `.bloc` bordé autour des figures, `@keyframes entre` | §3 |

Règle maîtresse : **un `<p>` survit s'il énonce un défaut, une preuve ou une décision,
en ≤ 120 caractères.** Cible : 88 `<p>` → ≤ 30 ; 16 125 → ≤ 5 000 car. L1516 (le
meilleur paragraphe du site, 312 car.) est l'unique exception : il devient une citation
(filet gauche 1 px `.12`, 15/24, `.72`).

**Ce qui reste, mis en scène** : les 108 pastilles + 52 `.p-cx` (texte et classes
intouchés) · la carte du serveur exhaustive (11 tables, 13 fonctions, 22 règles, 2 edge,
6 videurs) · les **6 sondes HTTP** → un bloc « preuve » mono par sonde
(`GET /rest/v1/rpc/noeuds_chemin_reclames → 200 []`, code de statut en `.96`) · les
phrases de défaut en une ligne (L444, 446, 684, 686, 703, 717, 1195, 1516, 1522) · les 4
décisions ouvertes (L1000, L1310, L1458 ①②) qui sont déjà des rangées de l'accueil.
« Diagnostic express » reste (ses 6 pastilles comptent dans les 108) — candidat à la
coupe dans une passe ultérieure, pas dans celle-ci.

---

## 7. Jalons

| jalon | ce qu'on livre | fichiers | vérifié par |
|---|---|---|---|
| **J0 — Fondations** | `tools/docsite/PLAN-SITE-PREMIUM.md` (ce plan) · tokens 3.1 · Inter · reset du `<style>` (L6-287 réécrit) · rail + lune + 11 icônes + compteurs 🔴 · légende déménagée · thème Mermaid unique + retrait des 19 `%%init%%` (**classDef vérifié sur le schéma #1 d'abord**) · page `#etat` vide par défaut · barre + tiroir mobile | `docs/site/index.html`, `tools/docsite/PLAN-SITE-PREMIUM.md`, `tools/docsite/verifier.sh` | `verifier.sh` (§8) : invariant 36/6/31/28/12 + 2 captures regardées |
| **J1 — L'accueil** | hero aurore + glyphes + grain · 6 pills-compteurs JS + témoin 108 · obsidienne « Ouvrir dans Supabase » · 7 cards de domaine (`data-dom` posés) · la liste des 67 (45 `id="b-…"` posés sur les sources, `data-src` sur les rangées) · filtres · le JS de 5.2 · nav avec compteurs | `docs/site/index.html` | idem + `console.warn` = 0 pour les 45 sources + test du coup d'œil 1440/390 |
| **J2 — Les onglets** | pastilles en verre · tables → liste fine · prose → `savoir` · les 11 coupes du §6 · emoji hors titres · dates absolues · `.decision` · blocs « preuve » des 6 sondes · figures sans card-dans-card | `docs/site/index.html` | idem + `<p>` ≤ 30, aucun > 240 car. hors `<details>` |
| **J3 — Le flow (4 captures) + la loi** | `tools/docsite/embarquer.py` (sips → JPEG q78 300 px → base64 entre `<!-- flow:début -->`/`<!-- flow:fin -->`, refuse > 60 Ko/image ou > 700 Ko total) · bande `.flow` sur l'accueil avec les 4 captures prêtes · `README.md` §Notes techniques + `SKILL.md` §I réécrits (§9) · republication au même lien | `docs/site/index.html`, `docs/site/README.md`, `.claude/skills/woop-schema/SKILL.md`, `tools/docsite/embarquer.py` | poids < 1 Mo · l'artefact rouvert au téléphone |
| **J4 — Les 8 captures manquantes** *(attend son feu vert : un build)* | `tools/docsite/capturer.sh` (UN build `dd-docsite`, 9 bancs, `-skipAuth` sauf porte, sans `-demoData`, 2 lancements chacun) → `tools/docsite/shots/*.png` → `embarquer.py` | `tools/docsite/capturer.sh`, `tools/docsite/shots/` | les 12 écrans dans l'ordre du flow, regardés |
| **J5 — Verdicts** | ses verdicts téléphone (aurore sans banding sur OLED, lisibilité du `.42`, la liste à 390) ; puis, **dans un commit à part**, la pose des 22 ◌ et des 6 ⚑ (une mesure par ligne — jamais dans la refonte) | — | elle |

Un commit par jalon (J0 seul puis J1… ou J0+J1 ensemble si J0 n'a pas de sens visuel
seul), **jamais** de commit où l'invariant n'est pas vérifié. Pas de trailer, pas de
signature (règle CLAUDE.md).

---

## 8. Vérification — `tools/docsite/verifier.sh` (lancé avant chaque commit)

```sh
# 1. l'invariant — les pastilles n'ont pas bougé (contenu + légende)
for k in ok loc srv abs men; do printf '%s ' "$k"; grep -c "class=\"p p-$k\"" docs/site/index.html; done   # attendu 36 6 31 28 12
# 2. la robe — vérifiable au grep
grep -cE '<h[123][^>]*>[^<]*[🟢🟡🔵⚪🔴🧨🧭🚩⛔]' docs/site/index.html                                      # 0 emoji dans un titre
grep -oE 'font-weight:[0-9]+' docs/site/index.html | sort -u                                                 # ⊆ {300,400,500,600}
grep -oE 'border-radius:[^;]+' docs/site/index.html | sort -u                                                # ⊆ {4,5,8,12,16,20,28,999}
grep -c 'backdrop-filter' docs/site/index.html                                                               # ≤ 3 règles CSS
grep -cE "aujourd'hui|ce matin|depuis la refonte" docs/site/index.html                                      # 0
grep -oE 'font-family:[^;]+' docs/site/index.html | sort -u                                                  # Inter + ui-monospace seulement
# 3. les deux captures — regardées, pas supposées (Chrome 152 est là ; réseau requis pour Inter + le CDN Mermaid)
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; U="file://$PWD/docs/site/index.html"
"$C" --headless --disable-gpu --hide-scrollbars --virtual-time-budget=8000 --window-size=1440,2400 --screenshot=tools/docsite/captures/site-1440.png "$U"
"$C" --headless --disable-gpu --hide-scrollbars --virtual-time-budget=8000 --window-size=390,2400  --screenshot=tools/docsite/captures/site-390.png  "$U"
# 4. le poids
wc -c docs/site/index.html                                                                                    # < 1 000 000
```
Puis, **à l'œil sur les deux captures** (loi du fouettage : on regarde, on ne suppose
pas) : le test du coup d'œil de 5.1 (titre, 6 nombres, 3 cards rouges au-dessus du pli ;
rien d'autre) · fond `#000` exact à la pipette hors hero · aucun pixel orange hors hero ·
les nombres alignés (tabular) · `scrollWidth === 390` · l'aurore éteinte à la ligne de
base du hero · le `.42` lisible sur un vrai écran (pas seulement Chrome) · les 19 schémas
rendus (aucun `.sans-plan`) · les captures d'app sans rectangle visible.

**Check-list « pas cheap » (binaire)** : aucun emoji dans un titre/nav/card · une
famille · ≤ 3 graisses · mono seulement dans `code`/`pre`/`td` · aucun texte centré
< 20 px · filets 1 px ≤ .10 repos / ≤ .16 hover · rayons du jeu · pas de card dans une
card · ≤ 7 `backdrop-filter` statiques, 0 animé · un seul halo (le hero) · aucun dégradé
à deux teintes, violet ou bleu-rose · aucune ombre colorée · aucun mot en MAJUSCULES sans
tracking ≥ .06 em · hover = bordure + fond, jamais scale/ombre/couleur · aucun texte
< 11 px, plancher `.42` · `--titre` ≤ 2 éléments par vue · hero ≤ 360/260 · une card = titre
+ compte + 4 segments + ↗, pas d'icône, pas de % · une seule date · aucune animation
d'entrée · 35/5/30/27/11.

---

## 9. Ce qui change dans la loi (même commit que J3)

`.claude/skills/woop-schema/SKILL.md` §I « LA ROBE » dit aujourd'hui « aucune couleur
dans le CSS, aucun dégradé, aucune ombre, rayon ≤ 12 » — la commande de Kathryn
(dégradés, verre, aurore, cards teintées, rayon 20) la contredit. Réécriture, courte :

| règle actuelle | nouvelle formulation |
|---|---|
| `--sol #08070B`, « pas #000 : une pointe de violet » | `--noir #000` — le noir de l'app, sans température : les captures s'y fondent |
| `--panneau #121017`, `--trait #262230` | `--panneau linear-gradient(#0F0F0F,#080808)` ; filets blanc-alpha 1 px, `.06` repos, `.16` plafond |
| encre calme `.62 → .30` | encre vive `--titre` 160° ; encre calme `.55` plat ; **plancher `.42`** |
| « **Aucune couleur dans le CSS**, la couleur ne vient que des emoji » | « **La couleur est sémantique, jamais décorative** : l'emoji d'état, la teinte de card qui en découle (≥ 1 🔴 rouge · tout 🟢 vert · sinon argent), et l'aurore du hero de l'accueil. Zéro accent de marque, zéro couleur de lien ou d'onglet actif. » |
| « Interdits : ombres, dégradés décoratifs, néon, arrondis > 12, bordures > 1 px » | « Interdits : ombre colorée (toute ombre est noire), dégradé à deux teintes ou violet/bleu-rose, néon, halo hors hero, rayon hors {8, 12, 16, 20, 28, 999}, bordure > 1 px, flou animé, > 7 `backdrop-filter`. » |
| typo Sans 700-800 ; Mono pour « tout ce qui est technique » | « **Inter 300/400/500/600** (300 ≥ 28 px, 600 sur le bouton seul), titres 500 à −0,02 em. Mono **seulement** dans une cellule, un `code`, un `pre`. Jamais titre, nav, légende, pied. » |
| « un emoji par nœud, jamais pour décorer un titre » | « … ni dans un `h1/h2/h3`, ni dans la nav, ni comme icône de card. Un emoji vit dans un nœud de schéma ou dans une pastille, nulle part ailleurs. La pastille est un verre neutre (22 px, 999, filet `.08`) autour de l'emoji, qui est sa seule couleur. » |
| §V ⑦ thème Mermaid | « un seul thème dans le JS ; fills = état à 14 % sur noir, strokes = état à 55 % ; jamais de `%%{init}%%` ni de `classDef` coloré dans un bloc » |

`docs/site/README.md` : « Notes techniques » (Inter, `#000`, les 7 flous, les images
en data URI + `embarquer.py`) et « Ce qu'il contient » (l'accueil « État » en tête).
`CLAUDE.md` ne change pas.

---

## 10. Les décisions prises (à contester ici, pas en cours de route)

1. **Hero 360 px** (260 à 390) — plus bas que la référence Workspace, parce que les 3
   premières secondes doivent montrer 3 cards, pas seulement une lumière.
2. **Pastilles en verre NEUTRE, l'emoji est la couleur** — pas de fond teinté, pas de
   `backdrop-filter` (108 couches). Les billes CSS colorées n'existent que là où il n'y a
   pas d'emoji (hero, rangées, cards).
3. **Cards rouge / vert / argent** — pas d'ambre ni de bleu (sapin). Aujourd'hui 4 rouges,
   3 argent, 0 verte : c'est vrai.
4. **Un seul bouton obsidienne par page**, et il fait quelque chose de réel (ouvrir
   Supabase). Pas de « Republier ».
5. **Mono système** (`ui-monospace`), aucune police mono externe.
6. **L'accueil est un rendu JS des 108 pastilles existantes** ; les 58 issues lues dans
   le code entrent comme ◌ « à mesurer » avec leur preuve, jamais peintes dans cette
   passe ; les 6 litiges portent un anneau pointillé. La pose = un commit à part (J5).
7. **Cards par domaine** (7), pas par onglet — ce qui demande ≈ 108 `data-dom`, posés sur
   les conteneurs quand la table est homogène.
8. **Les 25 prompts restent**, pliés. « Diagnostic express » reste. Les 19 schémas restent.
9. **Les images du flow sont de vraies captures** fondues au noir ; 4 maintenant, 8 après
   son feu vert pour un build (J4).
10. Le JS ne fait jamais **dire** un état au site : il compte, il lit, il filtre — et il
    se dénonce si la somme n'est pas 108.
