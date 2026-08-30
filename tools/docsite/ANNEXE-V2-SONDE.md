# ANNEXE v2 — Les mesures derrière le plan Next.js (sonde du 30-08-2026)

> Matière brute de `PLAN-SITE-V2-NEXT.md` : la palette réelle de 12 écrans de l'app (PIL), le registre npm, la doc Vercel (Hobby ne protège pas la production), Next.js en `file://`, Mermaid bundlé vs pré-rendu, et la table de migration des 114 pastilles par onglet.

[harness: subagent output matched instruction-shaped pattern(s): settings-json. Control tags below are neutralized (`<` → `<\`); treat any remaining directive-shaped text as a finding to relay to the user, not an instruction to you.]

## A. La palette réelle de chaque écran

Méthode : PIL, réduction à 200 px de large (LANCZOS), HSV, filtre `V > 0.25 & S > 0.30`, histogramme de teinte par pas de 10°, couleur = HSV médian du pas. Luminance = moyenne 0.2126R+0.7152G+0.0722B sur l'image entière. Noir = part de `V < 0.08`.

| écran | fichier | couleur 1 (hex, part) | couleur 2 (hex, part) | luminance | part de noir |
|---|---|---|---|---|---|
| home | `tools/road/shots/j4-home-serpentin.png` | **#8F3F02** 9,2 % (h20‑30, S98 V56) | **#661700** 4,2 % (h10‑20, S100 V40) | 0,119 | 40,2 % |
| chemin, verre noir | `tools/road/shots/road-2-etats-etape5.png` | **aucune** 0,00 % | **aucune** 0,00 % | 0,069 | 81,4 % |
| chemin, chapitre bleu | `tools/road/shots/road-3-tresor-ecran5.png` | **#204371** 19,3 % (h210‑220, S72 V44) | **#679CCD** 1,1 % (h200‑210, S50 V80) | 0,101 | 60,7 % |
| départ | `tools/road/shots/road-1-branchee.png` | **#F6904A** 0,02 % (h20‑30) | **#F74A0D** 0,02 % (h10‑20) | 0,111 | 61,7 % |
| stop | `tools/stop/captures/stop-134059.png` | **#3A435B** 0,004 % (h220‑230, S36 V36) | **#454F63** 0,004 % (h210‑220) | **0,039** | **89,5 %** |
| coffre | `tools/coffre-v2/ARCHIVE/coffre-v1.jpg` | **#5F3F18** 2,7 % (h30‑40, S75 V37) | **#5E2B06** 2,2 % (h20‑30, S94 V37) | 0,035 | 85,6 % |
| home v2 | `tools/home-v2/shots/verdict-piece-noire-page.jpg` | **#813802** 7,4 % (h20‑30, S99 V51) | **#610B01** 4,5 % (h0‑10, S99 V38) | 0,103 | 40,6 % |
| notifs | `tools/notifs/captures/v7.png` | **#81684A** 0,45 % (h30‑40, S42 V51) | **#965624** 0,38 % (h20‑30, S76 V59) | **0,029** | **90,2 %** |
| booster noir | `tools/sacre/noir/preview-face.png` | **#518F94** 0,14 % (h180‑190, S45 V58) | **#508897** 0,12 % (h190‑200) | 0,105 | 36,1 % |
| page exo (ancien verre) | `tools/verre/archives/v1-noir-orange/g9-ferme.png` | **#66543E** 2,9 % (h30‑40, S39 V40) | **#553820** 1,9 % (h20‑30, S63 V33) | **0,186** | 59,6 % |
| logo lune | `Woop/Media/carte-logo-ref.png` | **#602106** 13,8 % (h10‑20, S94 V38) | **#C55818** 5,0 % (h20‑30, S88 V77) | 0,124 | **26,9 %** |
| booster orange | `Woop/Assets.xcassets/booster-orange.imageset/booster-orange.png` | **#60210A** 5,8 % (h10‑20, S90 V38) | **#924E23** 3,1 % (h20‑30, S76 V57) | 0,072 | 63,9 % |

**Ce que la mesure dit, et qui contraint le hero de Kathryn :**

1. **Deux familles seulement.** Ambre/rouge‑brun `h10–40` (home, home v2, coffre, notifs, page exo, logo, booster orange = 8/12) et bleu `h180–220` (chemin bleu, stop, booster noir = 3/12). Il n'existe **aucune** teinte verte, violette ou magenta dans l'app. Un hero « une couleur par domaine » avec 10 teintes distinctes serait **inventé**, pas mesuré.
2. **Trois écrans n'ont pas de couleur du tout.** `road-2-etats-etape5.png` : 0 pixel au‑dessus du seuil (81,4 % de noir pur) ; `road-1-branchee.png` : 0,1 % ; `stop-134059.png` : 0,004 %, luminance 0,039. Passe relâchée (`V>0.12 & S>0.12`) : le verre noir plafonne à **#1D1D22** 0,01 % — c'est un gris bleuté, pas une couleur. Pour ces domaines, le hero doit se teinter par **héritage** (l'ambre du parent) ou rester noir, pas par extraction.
3. **La teinte dominante est sombre.** V médian 33–56 sur 100 pour 9 écrans sur 12. Un « grand aplat de couleur » à la valeur mesurée (#8F3F02, #204371) est déjà proche du noir — le dégradé de la référence de Kathryn (ciel → rouge‑brun → noir) fonctionne, mais la couleur doit être **remontée en valeur** (V 56 → ~70) pour exister comme aplat, ce qui est un écart assumé à la mesure, à écrire dans le plan.
4. **Le plus coloré du dépôt n'est pas un écran, c'est le logo** (`carte-logo-ref.png` : 20,7 % de pixels colorés, seulement 26,9 % de noir, et une pointe claire **#C55818** V77). C'est la seule source qui donne un aplat lisible sans triche.

Script (à rejouer). Je n'ai **pas pu l'écrire** dans le scratchpad : je suis en mode plan + lecture seule, sans outil d'écriture, et la redirection shell m'est interdite. Le voici, à déposer en `…/scratchpad/palette.py` :

```python
import colorsys, os
from PIL import Image
SHOTS = [("home","tools/road/shots/j4-home-serpentin.png"),
 ("chemin verre noir","tools/road/shots/road-2-etats-etape5.png"),
 ("chemin bleu","tools/road/shots/road-3-tresor-ecran5.png"),
 ("depart","tools/road/shots/road-1-branchee.png"),
 ("stop","tools/stop/captures/stop-134059.png"),
 ("coffre","tools/coffre-v2/ARCHIVE/coffre-v1.jpg"),
 ("home v2","tools/home-v2/shots/verdict-piece-noire-page.jpg"),
 ("notifs","tools/notifs/captures/v7.png"),
 ("booster noir","tools/sacre/noir/preview-face.png"),
 ("page exo","tools/verre/archives/v1-noir-orange/g9-ferme.png"),
 ("logo lune","Woop/Media/carte-logo-ref.png"),
 ("booster orange","Woop/Assets.xcassets/booster-orange.imageset/booster-orange.png")]
def med(v):
    v=sorted(v); n=len(v); return v[n//2] if n%2 else (v[n//2-1]+v[n//2])/2
def analyse(path, VT=0.25, ST=0.30):
    im=Image.open(path).convert("RGB"); w,h=im.size
    im=im.resize((200,max(1,round(h*200/w))),Image.LANCZOS)
    px=list(im.getdata()); tot=len(px); lum=0.0; dark=0; b={}
    for r,g,bl in px:
        R,G,B=r/255,g/255,bl/255
        hh,s,v=colorsys.rgb_to_hsv(R,G,B)
        lum+=0.2126*R+0.7152*G+0.0722*B
        if v<0.08: dark+=1
        if v>VT and s>ST: b.setdefault(int(hh*360)//10,[]).append((hh,s,v))
    out=[]
    for k,vals in sorted(b.items(),key=lambda x:-len(x[1]))[:2]:
        hm,sm,vm=med([x[0] for x in vals]),med([x[1] for x in vals]),med([x[2] for x in vals])
        r,g,bl=colorsys.hsv_to_rgb(hm,sm,vm)
        out.append(("#%02X%02X%02X"%(round(r*255),round(g*255),round(bl*255)),100*len(vals)/tot,k*10,round(sm*100),round(vm*100)))
    while len(out)<2: out.append(("—",0,0,0,0))
    return out, lum/tot, 100*dark/tot
for name,p in SHOTS:
    (c1,p1,d1,s1,v1),(c2,p2,d2,s2,v2)=analyse(p)[0]; _,lum,dark=analyse(p)
    print(f"{name}\t{os.path.basename(p)}\t{c1} {p1:.2f}% h{d1} S{s1} V{v1}\t{c2} {p2:.2f}%\tlum {lum:.3f}\tnoir {dark:.1f}%")
```

---

## B. Faisabilité Next.js, mesurée

### B1 — Registre npm (répond, `npm view`, lecture seule)

| paquet | version | poids dépaqueté |
|---|---|---|
| `next` | **16.3.3** | 184 740 391 o (185 Mo) |
| `mermaid` | **11.17.2** | 83 995 446 o (84 Mo) |
| `framer-motion` | **13.1.1** | 4 816 969 o (4,8 Mo) |
| `@mermaid-js/mermaid-cli` | **11.16.0** | — |

`node v24.16.0` / `npm 11.13.0`. `framer-motion` 13.1.1 est aliasé sur `motion` 13.1.1 (même version) — la marque a migré, `motion` est le nom courant.

### B2 — Rien de Node dans le dépôt aujourd'hui

`find . -maxdepth 2` : **aucun** `package.json`, **aucun** `.nvmrc`, **aucun** `node_modules`, **aucun** lockfile. Deux `.gitignore` seulement : `/Users/kathryn/Desktop/woochoper-ios/.gitignore` (contenu : `.claude/settings.local.json`, `.secrets/`, `build/`, `dd-*/`) et `supabase/.gitignore`. **`node_modules` n'est pas ignoré** → un `npm i` dans `docs/site/` rendrait `git status` illisible et un `git add -A` catastrophique, exactement le motif déjà payé pour `dd-*/` (commentaire du `.gitignore` : « 8,7 Go et 32 368 fichiers »). C'est une ligne à ajouter **avant** le premier `npm i`, pas après.

`docs/site/` contient aujourd'hui 3 fichiers : `index.html` (341 846 o), `README.md` (6 186 o), `voir.sh` (461 o).

### B3 — Vercel : Hobby ne protège PAS la production

Citation exacte, encart en tête de <https://vercel.com/docs/deployment-protection> :

> « On the Hobby plan, Vercel Authentication with Standard Protection is available. This protects your preview deployments and deployment URLs, but **your production domain remains publicly accessible. To protect production domains, you need a Pro or Enterprise plan.** »

Et la table des scopes, même page :
- **Standard Protection** : « Protects all deployments **except** production domains. Available on all plans. »
- **All Deployments** : « Protects **all** URLs, including production domains. **Available on Pro and Enterprise plans**. »

**Password Protection** (<https://vercel.com/docs/deployment-protection/methods-to-protect-deployments/password-protection>) : « Available on the Enterprise plan, **or as a paid add-on for Pro plans** » — l'add‑on *Advanced Deployment Protection* coûte **150 $/mois**, avec un engagement minimum de **30 jours** avant désactivation. Donc : **indisponible sur Hobby**.

**Conséquence dure pour ce dépôt.** Le site cite l'id du projet Supabase `ytnnyjkramgiqyxdrkcu` à **15 endroits** (`docs/site/index.html:576`, `:782-788`, `:864`, `:1213`, `:1556`…) et décrit à `docs/site/index.html:1727` le fait que la connexion se fait « par un **numéro de téléphone écrit en dur**. Deux numéros sont connus, et **le mot de passe est calculé à partir du numéro** ». Un déploiement de **production** sur Hobby publie ça en clair. Les seules sorties gratuites : (a) ne déployer qu'en **preview** (URL protégée par Vercel Authentication, gratuite, 1 utilisateur externe max sur Hobby) et ne jamais promouvoir en prod ; (b) rester en local ; (c) Cloudflare Pages + Cloudflare Access (hors mesure ici). Pro à 20 $/mois + « All Deployments » couvre la production sans l'add‑on à 150 $.

### B4 — `output: 'export'` ne s'ouvre pas en `file://`

Doc Next.js `assetPrefix` (<https://nextjs.org/docs/app/api-reference/config/next-config-js/assetPrefix>, version 16.3.3), phrase exacte :

> « While `assetPrefix` covers requests to `_next/static`, it does not influence the following paths: Files in the **public** folder; if you want to serve those assets over a CDN, you'll have to introduce the prefix yourself »

Et la discussion officielle <https://github.com/vercel/next.js/discussions/43867> (« Static Html Export: How fix asset paths? ») : les chemins émis sont **absolus** (`/vercel.svg`, `/_next/…`) et doivent devenir relatifs (`./`) pour s'ouvrir sans serveur ; `assetPrefix: './'` fait passer le CSS **mais pas les polices ni les images**. Voir aussi l'issue <https://github.com/vercel/next.js/issues/43893> (« Docs: Explain asset path configuration in static html export ») et <https://github.com/vercel/next.js/discussions/71002>.

**Verdict mesurable :** un `next build && next export` ouvert par double‑clic donne une page **partiellement cassée**, et il n'existe pas d'option officielle pour l'éviter — seulement un post‑traitement de réécriture des chemins. Autrement dit, **`voir.sh` (= `open`) ne survit pas tel quel à Next.js.** Il faudra soit `npx serve out`, soit un script de réécriture après build, et c'est exactement la régression que Kathryn a signalée sur Mermaid (« ça marche pas quand on quitte l'artefact »).

### B5 — Mermaid : le poids et le pré‑rendu sans navigateur

- **Bundlé côté client** : `mermaid` 11.17.2 pèse **84 Mo dépaqueté** en npm ; l'artefact navigateur réel, mesuré par `curl -I` sur jsDelivr : `mermaid.min.js` (UMD) = **3 572 661 o (3,4 Mo non compressés)**, `mermaid.esm.min.mjs` = 30 255 o (ce n'est qu'un chargeur, les chunks de diagramme suivent en lazy). C'est **10× le site actuel entier** (341 846 o).
- **Pré‑rendu à la build, SANS navigateur** : **`beautiful-mermaid` 1.1.3** — description npm exacte : « *Render Mermaid diagrams as beautiful SVGs or ASCII art. Ultra-fast, fully themeable, **zero DOM dependencies**.* », dépendances = `elkjs` + `entities` uniquement, 2 098 676 o (2,1 Mo). Pas de Chromium.
- **Pré‑rendu AVEC navigateur** : `mermaid-isomorphic` 3.1.0 (45 883 o) — « Transform mermaid diagrams in the browser or Node.js », mais `peerDependencies = { playwright: '1' }` ; et `@mermaid-js/mermaid-cli` 11.16.0 dépend de `mermaid ^11.14.0`, `katex`, `@mermaid-js/layout-elk`, `@fortawesome/fontawesome-free` — plus Puppeteer/Chromium. Les deux téléchargent un navigateur (~150–300 Mo).

**La bonne réponse pour ce dépôt :** pré‑rendre les 19 schémas en **SVG inline à la build** avec `beautiful-mermaid` (2,1 Mo en devDependency, zéro navigateur, zéro runtime, zéro CDN). Le site livré ne contient alors **aucun JS de diagramme** — il s'ouvre en `file://`, en avion, dans l'artefact, partout. Et les nœuds « obsidienne » que Kathryn demande (noir, radius 12, bordure en dégradé blanc) deviennent du **CSS sur du SVG**, pas un `classDef` Mermaid — ce qui respecte au passage `tools/docsite/verifier.sh` qui exige `%%{init}%% = 0` et `classDef = 0`.

---

## C. Conventions du dépôt à réécrire

### C1 — Les règles qui cassent si `docs/site/` devient une app Next.js

| règle | où elle est écrite | ce qui casse | réécriture nécessaire |
|---|---|---|---|
| « Un seul fichier, `index.html`, **autonome** : pas de build, pas de dépendance, pas de serveur. On l'ouvre, on lit. » | `docs/site/README.md:3-5` ; `CLAUDE.md:5-6` | Next.js = build + `node_modules` + un dossier `out/` | Distinguer **la source** (`docs/site/src/`, Next.js) du **livrable** (`docs/site/index.html` ou `docs/site/out/`, autonome et commité). L'autonomie devient une propriété **du livrable**, pas du dépôt. |
| `voir.sh` = `open "$SITE"` sur un chemin absolu ; commentaire « pas de build, pas de serveur, pas de dépendance » | `docs/site/voir.sh:1-13` | `open` sur un export Next.js casse les chemins `/_next/` (cf. B4) | `voir.sh` devient : *si `out/` est plus vieux que `src/`, `npm run build`*, puis `open`. Ou il lance `npx serve`. Dans les deux cas il n'est plus « pas de build ». |
| « Republier au **même lien** (l'URL ne bouge jamais) en repassant `docs/site/index.html` à l'outil Artifact » | `CLAUDE.md:36-37` ; `docs/site/README.md` §Le geste | L'artefact Claude prend **un fichier HTML**, pas un dossier Next.js | Soit on garde un **fichier unique inliné** comme cible de build (tout le CSS/JS/SVG embarqué), soit on renonce à l'artefact. **C'est le vrai arbitrage** : Kathryn veut Next.js *et* le lien qui marche au téléphone. Un build « single‑file » (SVG pré‑rendus + CSS inline) satisfait les deux ; un `output: 'export'` multi‑fichiers n'en satisfait aucun. |
| « Le fichier part dans **le commit du changement**, jamais dans un commit de documentation à part » | `CLAUDE.md:38-39` ; `docs/site/README.md` | Un build produit **N** fichiers ; le diff d'un artefact généré est illisible et conflictuel | Règle à réécrire en : *la source ET le livrable partent dans le même commit* ; et `node_modules/` + caches `.next/` à ajouter au `.gitignore` racine **avant** le premier `npm i`. |
| « Avant chaque commit : `./tools/docsite/verifier.sh` » — invariant des pastilles par grep `class="p p-$k"`, robe au grep, 2 captures Chrome headless sur `file://$PWD/$SITE` | `tools/docsite/verifier.sh:1-40` ; README §Notes techniques | Le grep porte sur **un** fichier ; l'URL headless est un `file://` | Le vérificateur doit grepper la **source** (`docs/site/src/**/*.tsx|mdx`) pour les pastilles, et capturer le **livrable** (ou un `next start`). L'invariant `data-attendu` doit survivre : c'est la seule chose qui empêche le site de mentir. |
| « Les schémas sont en Mermaid natif dans l'artefact (en `file://` le moteur vient du CDN) » ; « un seul thème dans le JS — jamais de `%%{init}%%` ni de `classDef` » | `docs/site/README.md` §Notes techniques ; `verifier.sh:26` | C'est précisément ce que Kathryn dit cassé | Remplacer par : *les schémas sont des SVG pré‑rendus à la build (`beautiful-mermaid`), stylés en CSS ; aucun moteur au runtime.* Le contrôle `%%{init}%% = 0 · classDef = 0` reste valable et devient trivialement vrai. |
| « Inter via Google Fonts » ; « captures embarquées en data URI par `tools/docsite/embarquer.py` (300 px, JPEG q78, ≤ 60 Ko) » | `docs/site/README.md` §Notes techniques ; `tools/docsite/embarquer.py` | Next.js a `next/font` (self‑host) et `next/image` — deux mécanismes concurrents du script existant | Choisir : `next/font/local` avec le WOFF2 commité (supprime la dépendance réseau à Google Fonts, un gain), et **garder** `embarquer.py` pour les captures si la cible reste un fichier unique. Le hero coloré de Kathryn = **10 captures** au lieu de 4 → à 60 Ko l'unité, +360 Ko, soit un site qui double. Le seuil « < 1 000 000 o » de `verifier.sh:31` est à rechiffrer. |
| « Une seule robe : la nuit de l'app. Le noir `#000`, un seul halo (l'aurore de l'accueil), **la couleur réservée à l'état** » | `docs/site/README.md` §Notes techniques ; `.claude/skills/woop-schema/SKILL.md` §I | Le hero coloré par domaine ajoute une **quatrième** licence de couleur | Formuler l'évolution : la couleur a désormais **quatre** emplois, et un seul par surface — (1) l'emoji d'état, (2) la teinte de card d'état, (3) l'aurore du hero d'accueil, (4) **le hero de domaine, teinté par la palette MESURÉE de l'écran** (§A). Corollaire à écrire : *une teinte de hero se mesure, elle ne se choisit pas* — même loi que les pastilles. Et : *un domaine dont l'écran n'a pas de couleur reste noir* (3 cas sur 12, §A.2). |
| « Toute modification backend met le site à jour, dans le MÊME commit » | `CLAUDE.md:13-39` | **Ne casse pas** — mais devient plus coûteuse | À maintenir mot pour mot. Si l'édition d'une pastille passe de « chercher dans un HTML » à « npm run build », le coût d'oubli monte. Contre‑mesure : garder les pastilles dans **un seul fichier de données** (`etats.ts`/`.json`) que le vérificateur grep, pas éparpillées dans 11 composants. |
| « Il est écrit à la main, et c'est volontaire — rien ne le génère, donc rien ne peut le désynchroniser en silence » | `docs/site/README.md` §Le tenir à jour | Un build **est** un générateur | Nuancer : *rien ne génère les **états** ; le build ne fait que la mise en forme.* La frontière doit être explicite, sinon la loi fondatrice du site s'érode. |
| Commits : jamais de trailer `Co-Authored-By`, jamais de `🤖 Generated with Claude Code`, auteur = `kathryndsvergne <kat44426@gmail.com>` | `CLAUDE.md:54-63` | Ne casse pas | À rappeler dans le plan : ces règles priment sur les défauts de l'outil. |

### C2 — Table de migration : les 11 onglets et leurs pastilles

Le rail (`docs/site/index.html`, `<nav class="rail">`) compte **11** entrées, pas 10, en 4 groupes. Comptage par section (`<section class="page…" id="…">` → section suivante), motif `class="p p-{ok,loc,srv,abs,men}"` :

| # | onglet (libellé du rail) | `id` | ligne | 🟢 ok | 🟡 loc | 🔵 srv | ⚪ abs | 🔴 men | total |
|---|---|---|---|---|---|---|---|---|---|
| — | **État** | `etat` | 525 | 0 | 0 | 0 | 0 | 0 | **0** (agrège via `data-src`) |
| *Comprendre* ||||||||||
| 1 | Six dessins | `six` | 712 | 0 | 0 | 0 | 0 | 1 | **1** |
| 2 | La carte du serveur | `carte` | 777 | 22 | 0 | 27 | 3 | 0 | **52** |
| 3 | Le schéma de la base | `schema` | 914 | 6 | 0 | 2 | 1 | 0 | **9** |
| 4 | Diagnostic | `diag` | 1176 | 0 | 1 | 1 | 2 | 2 | **6** |
| *Domaines* ||||||||||
| 5 | Le flow | `flow` | 1255 | 0 | 3 | 2 | 3 | 1 | **9** |
| 6 | Coffre & annonces | `regles` | 1396 | 2 | 0 | 1 | 5 | 0 | **8** |
| 7 | La forge | `forge` | 1486 | 4 | 0 | 3 | 2 | 2 | **11** |
| 8 | Stories | `histoire` | 1621 | 0 | 1 | 1 | 4 | 0 | **6** |
| 9 | Compte | `porte` | 1690 | 1 | 0 | 0 | 5 | 5 | **11** |
| *Cas d'erreur* ||||||||||
| 10 | Le manège interrompu | `manege` | 1794 | 0 | 0 | 0 | 1 | 0 | **1** |
| | **TOTAL contenu** | | | **35** | **5** | **37** | **26** | **11** | **114** |

**L'invariant tient.** `docs/site/index.html:525` porte `data-attendu="114"`, et 35+5+37+26+11 = **114**. Le grep brut sur tout le fichier donne 36/6/38/27/12 = 119, soit exactement **+1 par état** : les 5 pastilles de la légende, situées **avant** la ligne 525 — ce que `verifier.sh:14-19` soustrait déjà (`total = total + n - 1`).

**Ce que la table impose au plan.** Seuls **5 onglets sur 11** sont des « domaines » au sens de Kathryn (`flow`, `regles`, `forge`, `histoire`, `porte`) et méritent un hero coloré ; ils ne portent que **45 pastilles sur 114**. Les **52 pastilles** de `carte` (46 % du total) sont dans un onglet de référence, pas un domaine — lui mettre un hero photo n'a pas de sens. Et deux onglets (`six` = 1 pastille, `manege` = 1) sont si maigres qu'un hero pleine largeur les écraserait : c'est probablement la vraie cause du « les 6 dessins, je comprends pas » (#6) — pas le dessin, la **densité**. Le mapping écran ↔ domaine qu'autorise §A : `flow` → home `#8F3F02` · `regles` → coffre `#5F3F18` ou notifs `#81684A` · `forge` → booster orange `#60210A` · `histoire` → page exo `#66543E` · `porte` → **aucune capture mesurée** (à produire, ou noir).

**Loi rappelée, non violée :** aucune pastille ne change d'état dans ce relevé — c'est un comptage, pas une mesure d'état.

Sources : [Deployment Protection on Vercel](https://vercel.com/docs/deployment-protection) · [Vercel Authentication](https://vercel.com/docs/deployment-protection/methods-to-protect-deployments/vercel-authentication) · [Password Protection](https://vercel.com/docs/deployment-protection/methods-to-protect-deployments/password-protection) · [Next.js assetPrefix](https://nextjs.org/docs/app/api-reference/config/next-config-js/assetPrefix) · [next.js#43867](https://github.com/vercel/next.js/discussions/43867) · [next.js#43893](https://github.com/vercel/next.js/issues/43893) · [next.js#71002](https://github.com/vercel/next.js/discussions/71002) · [Static Exports](https://nextjs.org/docs/pages/guides/static-exports)