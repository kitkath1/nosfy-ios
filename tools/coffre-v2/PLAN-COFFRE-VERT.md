# La card « Le coffre » au vert — le plan (15-09-2026, session coffre)

**ÉTAT (16-09 matin)** : §1 à §4 CODÉS, construits (copie jetable, le fichier Codex
`FondVideoMetal.swift` ne compile pas pour le simulateur — patché dans la copie seulement),
CAPTURÉS (tools/coffre-v2/captures/, compte de test + maquette), le site repeint (page coffre :
**10 🟢, tout vert** — la ligne « vidéos de la chauve-souris » est passée au vert le 16-09 sur les
9 captures et le tirage serveur de la session annonces, synchro demandée par Kathryn), `npm run
verif` vert, livrable republié au même lien. **RIEN N'EST COMMITÉ** (son ordre attendu). Non mesuré :
au doigt sur son téléphone. Incident du 15-09 soir : le compte de test avait un carnet à
−8 087 (124 conversions nées des crédits cardio effacés par verif_cardio) — nettoyé par la
session annonces, noté sur b-tb-coin-ledger.

**Le but, dans ses mots** : « le but est d'avoir la card en verte pour que tout soit nickel ».
**La source** : `docs/site/content/{briques,mesures}.ts`, page `coffre` — 8 lignes, 5 vertes,
3 qui restent. Le SERVEUR du coffre est entièrement vert et mesuré (`etat_coffre`,
la conversion 100 → sachet, `claim_*`, les portes fermées au client) : **aucune migration**.
Tout ce qui reste est du front, plus les verdicts qu'elle a rendus ce soir.

## §0 — Ses verdicts (15-09 soir, ses mots)

| sujet | la décision |
|---|---|
| **le « 20 en dur »** | « ce que je sais c'est qu'on gagne 20 pièces par série faite et 10 par connexion » — les nombres ne bougent PAS ; ce qui change, c'est que l'app arrête de *connaître* le 20 et le *lit* au serveur (voir §1) |
| **le profil** | « quick win : mettre les pills sur la même ligne, juste la pièce en or et pas son wording ; au clic des 4 pastilles liquid glass ça ramène sur la page coffre au bon item » |
| **le géant** | « deux variants : N SACHETS À OUVRIR ; et en cas de pas possible, la jauge (même composant que dans le coffre) pour dire le nombre de pièces qu'il faut » |
| **la langue** | « comme les autres blocs, une en anglais et une en français selon le choix de l'onboarding » — le coffre (et le géant) passent par `L(fr, en)` |
| **la liste des gains** | « j'imagine que dans la liste de ce qui est collecté on voit les pièces et les boosters aussi » — oui (`historique_gains`, pièces et sachets mêlés) ; deux lignes neuves du 15-09 (`cardio_seance`, `bonus_progres`) n'ont pas de titre et s'affichent en nom de raison brut → à titrer (§4) |

## §1 — Le « 20 en dur », vulgarisé

Ce que tu vois : le « +20 » à droite de chaque série dans l'ardoise du player, le « +20 »
de BRAVO, et le solde de secours quand on ouvre le coffre sans réseau. Ces trois-là
lisent un **20 tapé dans le code** (`CoffreFortPurse.perSeries`, CoffreFortPurse.swift:28).
La pill « +20 · 100 this session » et la page Or du coffre, elles, lisent le **serveur**
(`etat_coffre().pieces_par_serie`, posé dans `EconomieWoop.piecesParSerie`).

Aujourd'hui les deux disent 20 : rien ne ment. Mais il y a deux endroits où le nombre
vit, et le jour où tu le changes en base, l'ardoise dirait l'ancien. Le geste :
`perSeries` devient une **lecture** de `EconomieWoop.piecesParSerie` (20 en secours,
avant la première réponse — le même secours que partout). **Rien ne change à l'écran.**
Les 7 sites d'appel ne bougent pas. Preuve : `grep` → plus aucun `= 20` dans
CoffreFortPurse ; l'ardoise et la pill impriment le même nombre, celui du journal
`[coffre]`.

## §2 — Le profil : quatre pastilles, une ligne (ProfilLune.swift)

- `tresorBanniere` : les deux rangs (`rangReserves` / `rangMonnaies`) deviennent UNE
  `HStack` — noir · orange · argent · or, dans l'ordre du manège du coffre lu de droite
  à gauche (l'or, le plus près du pouce).
- `pastillePieces` perd le mot « pièces » : la pièce et le nombre, comme l'argent.
- **Le tap des quatre ouvre le coffre AU BON ITEM** : `CoffreFortFlow(coins:pageInitiale:onClose:)`
  → `CoffreV2Page.pageInitiale` (or 0 · sachet Lune 1 · argent 2 · noir 3, l'ordre de
  `variantes`), posé dans `demarrer()` comme `-coffrePage` le fait déjà. Le manège des
  pills (`ouvrirReserve`) n'est plus la porte du profil : le coffre l'est, et son bouton
  « Ouvrir » ouvre le manège (le chemin qui existe déjà). Le paramètre a un défaut : les
  quatre autres appelants de `CoffreFortFlow` ne bougent pas d'un caractère.
- La place : mesurée sur la capture du 15-09 (profil-sans-flamme), quatre pills sans le
  mot ≈ 60 + 58 + 65 + 70 pt + 3 × 8 = 277 pt ; la bannière en offre ≈ 288 à droite de
  l'avatar (378 − 90). Ça tient à un chiffre ; à deux chiffres partout (65 sachets, 43
  pièces) il faut resserrer : espacement 6, padding 11. À MESURER sur la capture du
  compte de test (65 · 0 · 0 · 43) avant de dire que ça tient.

## §3 — Le géant : deux variants, plus jamais « Utiliser 100 pièces » (TirageBooster.sheet)

Le panneau disait « Utiliser 100 pièces pour ouvrir un booster ? » — l'achat est mort
depuis le 30-08 (les 100 pièces deviennent un sachet toutes seules), donc le texte
promettait une transaction qui n'existe plus : un 🔴 posé sur le site (b-rg-le-geant).

- `economie.boosters > 0` → titre `L("N sachets à ouvrir", "N packs to open")`
  (singulier à 1), le trône, le primaire `L("OUVRIR", "OPEN")` → `ouvrirManege()`.
- `== 0` → titre `L("Il te manque N pièces", "N more coins to go")`, **la jauge du coffre**
  (`BarreFine(.compte(courant: reste, cible: prix, monnaie: .or))`, la même lueur que la
  page du sachet Lune) et le bouton MAT du coffre (`L("Verrouillé", "Locked")`, la 5ᵉ loi
  d'Opal : même place, même hauteur, le bijou en moins).
- `RETOUR` → `L("Retour", "Back")`.
- La branche « Il t'en restera N » disparaît : le solde ne dépasse plus 99, elle ne
  pouvait plus jamais s'écrire.

## §4 — La langue du coffre (CoffreV2.swift · EconomieWoop.titre)

Tout texte visible passe par `L(fr, en)` (Langue.swift : le cache `woop.langue`, posé par
le film et rafraîchi par `home()`) : les quatre en-têtes (`nom`, `phrase`, `sousPill`),
les mots des boutons (Ouvrir / Verrouillé), l'horloge (« +10 pièces dans 4 heures » ·
« +10 pièces à réclamer »), « Découvrir l'histoire », « Mes gains » / « Rewards » (un seul
titre dans les deux langues), la phrase du vide, Retour / Fermer / Passer, et les deux
récits (quatre paragraphes chacun, réécrits en français ; le récit Lune disait
« A hundred coins buy another » — on ne les achète plus : « en deviennent un »).
Les titres du journal (`EconomieWoop.titre`) : les deux langues, plus les deux raisons
neuves du 15-09 : `cardio_seance` → « Séance cardio » / « Cardio session »,
`bonus_progres` → « Bonus de progrès » / « Progress bonus ».

## §5 — Ce qui ne bouge pas

- Le serveur : rien. Les prix, les soldes, le journal viennent d'`etat_coffre` /
  `historique_gains`, mesurés le 30-08 et le 15-09.
- La pile d'annonces, la pill « +20 », les rangs : session annonces (woochoper-ios-05).
- Les hunks des autres dans ProfilLune.swift (le prénom — session compte ; les portes de
  sommeil du géant — Codex) : édition ciblée, jamais un Write du fichier, stage par hunk.

## §6 — Les preuves à lire avant de repeindre le site

| ligne du site | la mesure qui l'autorise |
|---|---|
| ◌ m-constantes-locales-a-retirer → fermée | `grep -rn "perSeries = " Woop` → 0 ; sim compte de test : l'ardoise et la pill disent le nombre du journal `[coffre]` |
| ⚪ b-rg-piece-d-or → 🟢 | capture du profil (compte de test) : une ligne, la pièce et son nombre, le tap ouvre le coffre sur l'or |
| ⚪ b-rg-le-geant → 🟢 | deux captures : `-profilTirage` avec sachets (« N sachets à ouvrir ») et sans (la jauge « 43 / 100 », Verrouillé) ; le tap OUVRIR monte le manège |
| langue (ligne neuve) | deux captures du coffre, `woop.langue` fr puis en |
