# PROGRESS v2 — « ON ATTERRIT SUR UNE PAGE, PAS SUR L'iPOD »

> ## ÉTAT AU 30-08, 16 h 30 — CODÉ P0 → P7, NON COMMITÉ (les commits sont à Kathryn)
>
> **Fait, build vert (`dd-progress`, sim dédié `kat-progress`), tout en
> captures dans `tools/progress/shots/` :**
> - **P0** — `CalLab.swift` : `MoisLaunch`, `CalStoryLaunch`, `CalSlot`,
>   `MoisIpod`, `DemoMonth` internes ; `StickerDayCell` reçoit `jour: JourCase?`
>   (nil = la démo, intacte) ; `DemoSession.workout` (la story et la partition
>   viennent du `Workout`). `HomeNuit.swift` : `MiniCardJour(date: Date?,
>   vide:)`, `SemaineJour`, `SemaineStrip(jours:videsVisibles:jouet:flou:)`,
>   pas adaptatif, `dragMini` sorti. `DepartCine.swift` : `chauffer()`
>   (− `home-fond-loop`, + `story-pilule-droite`). **Non-régression vue** :
>   `-calLab` et la home `-thisWeek` inchangées.
> - **P1 → P3** — `Woop/Views/ProgressPage.swift` (la page, `CalendrierMois`,
>   `WoopSticker.pour`, `DemoSession.depuis`). **Écarts assumés avec le plan** :
>   `ArriveeFloue` reste dans `CoffreV2.swift` (interne, appelable — le
>   déménager ne changeait rien) ; `GrandeCardExos` **n'est pas** paramétré, la
>   card a son propre fond à deux `CalqueVideo` (l'école `DepartCine`) et
>   n'emprunte à `ExosFond` que ses cotes et `FormeCardExos` ; **une mini par
>   JOUR** dans « This week » (la démo sème neuf séances : neuf minis à pas 30
>   ne se lisaient plus).
> - **P4** — filmée (`tools/progress/filmer.sh`) : **0 flash en V** ; la card
>   naît en fondu (ajouté au film : la pill claquait avant l'encre).
> - **P5** — `-progressStory 21` ouvre la story v2 in-tree ✓ ;
>   `-progressLecteur` ouvre l'iPod sur les vraies séances du mois ✓.
> - **P6** — la levée est REÇUE (PageCard, session player) ; `-progressLevee
>   96` : arête à 778, 40 pt d'air ✓. Aucun player monté par la page.
> - **P7** — `WoopApp.swift:1066` monte `ProgressPage(onBack: retourHome)` ;
>   `-openTab progress` atterrit sur la page ✓ ; l'ancienne page vit sous
>   `-calLab`.
> - **P8** — fiche `docs/screens/progress.md`. **CADENCE AU SIM, machine calme,
>   même run** (`-fps`, `SondeCadence`) : la home **37 img/s** (55 → 28) ·
>   Progress **15,8** · Progress sans verre 16,2 · **Progress sans le bouton
>   diamant : 60,0**. La cause est UNIQUE et mesurée : le `DiamondPrimaryButton`
>   — un `colorEffect` (fbm, rim, souffle) dans une `TimelineView` à **30 Hz
>   permanente** (`ConnexionButtonLab.swift:200-217`), même au repos. Le sim
>   émule le GPU ; **le juge est le téléphone** (le coffre porte ce bouton sur
>   ses quatre pages, la porte et les sheets aussi). Si le téléphone confirme :
>   le remède est dans le composant partagé — une horloge qui DORT au repos
>   (10 Hz, ou en pause hors appui), pas sur cette page. Banc :
>   `-progressSansBouton` / `-progressSansVerre`.
>   **RÉSOLU le soir même** : sur son screenshot d'inspiration (« Appliquer le
>   thème »), le primaire est devenu **`BoutonPrimaire`** (`Woop/Views/
>   BoutonPrimaire.swift`, banc `-boutonLab`, 8 tours au sim avec ses
>   verdicts : plus de capitales, capsule 58 du « locked », noir, nappe
>   blanc-gris au pied, souffle du texte à peine là, **poudre des cards au tap
>   seulement** — `PoudreMini`, horloge qui dort) ; `DiamondPrimaryButton` est
>   une coquille dessus → tous les sites l'ont pris sans une ligne. Mesuré :
>   **Progress 60,0 img/s**.
>
> **Option B** cuite (`recuit_pill_bas.sh` → `progress-pill-bas.mp4`, 1206 ×
> 2592, 30 i/s palindrome, **11 Mo**) : la pill verticale prend toute la card,
> son dôme traverse le header — spectaculaire, mais elle couvre tout. À
> trancher à l'œil (captures `progress-161624.png` vs `progress-161403.png`).
>
> **Restent** : ses verdicts (A/B de la pill, flamme vide contour vs sticker
> `-progressFlammeSticker`, « Aujourd'hui »), la cadence et les gestes **sur le
> téléphone**, le rect de la mini pour son portail, et l'iPod sur une séance
> cardio (« 0 séries · 0 reps » — à la session iPod).

> Chantier ouvert le **30-08-2026**, sur sa demande et sa maquette (deux frames :
> la page habillée, puis le fond seul). **RIEN N'EST CODÉ** — « fais un plan, ne
> code pas ». Tout ce qui est écrit ici sans marque est **vérifié dans le code**
> (`fichier:ligne`, arbre de travail au 30-08, HEAD `8e8a0cc`) : six lentilles
> de lecture puis six vérificateurs ont relu **475 citations** (14 lignes
> recalées, aucune fausse). Les vidéos sont **mesurées** (ffprobe + numpy), pas
> regardées. Ce qui attend une décision porte **?**. Le premier coup de pioche
> est **P0** (les extractions) — il ne change rien à l'écran et ne demande aucun
> verdict.

---

## §0. LA DEMANDE, DÉCOMPOSÉE

Verbatim (30-08), et ce que chaque phrase engage :

| # | Sa phrase | Ce que ça engage |
|---|---|---|
| D1 | « today on atterrit sur l'iPod ! non je veux plus, on atterrit sur une **vraie page plus allégée** » | L'onglet Progrès cesse de forcer l'iPod (`WoopApp.swift:1046`, `ouvreIpod: true`). Une page neuve, **`ProgressPage`**. L'iPod devient une **destination** (D9), plus un atterrissage. |
| D2 | « en haut header **chevron** et "**Progress**" en **dégradé de blanc**, même size que **Rewards** dans la page coffre » | La robe existe déjà deux fois et se cite elle-même : `CoffreV2.swift:3206` dit « sa cote est celle de `CalLab.enTeteBac` ». Inter-Bold 30, tracking −0,4, `WoopGradient.titleFade`. §4. |
| D3 | « apparition des composants **à l'Apple : blur** » | La grammaire d'arrivée du coffre — `ArriveeFloue` (`CoffreV2.swift:1159`) — en cascade, **transitoire**, rayon remis à ZÉRO exact. Jamais sous le doigt. §4. |
| D4 | « tu remets en haut le **widget "This week"** avec les mini cards » qu'on a enlevé de la home hier | `SemaineStrip` (`HomeNuit.swift:1283`) n'est pas parti : il vit derrière `-thisWeek` (`:1851`). On le **remonte tel quel**, sur une autre page. §5. |
| D5 | « un **variant joli de la mini card vide** : si le user a choisi **4** entraînements, il voit le reste des cards non faites, avec un petit **logo flamme vide**, un peu comme les **galets du chemin** » | Le variant n'existe pas : les places non faites sont à **opacité 0** (`HomeNuit.swift:1570`). L'objectif est `Goal.cleHebdo` (`Models.swift:566-583`, choix 3→7). La flamme vide des galets est le SF `flame` en contour `ultraLight` (`GaletEtape.swift:779`). §5. |
| D6 | « en dessous on remet notre composant **calendrier**, on peut **switch de mois** » | La bascule existe DÉJÀ dans la carte dépliée (`CalLab.swift:403` `monthStep`, `:1082` les ‹ ›) — mais tout est `private` et soudé au morph semaine↔mois. On extrait le **pur** (`CalSlot`, `StickerDayCell`) et on pose une grille **fixe**. §6. |
| D7 | « **toute la page est une card qu'on peut drag** (pour le futur **lecteur de la session en cours**) comme la home ou la page exercice » | Le patron exos (`ExercisesView.swift:7`) : une card qui se **raccourcit par le bas** (masque, jamais un frame) et découvre une bande — la lune hors séance, le player en séance. §7. C'est le crochet du `PLAN-PLAYER-CARD.md`. |
| D8 | « en background une **grosse pill rouge liquid glass en vidéo** qui tourne en fond (elle peut **partir du bas**, jolie) » | Mesuré : la maquette est **`story-pilule-droite.mp4` + `home-fond-flamme.mp4`**, deux fichiers déjà dans le bundle, déjà cuits pour l'écran, zéro recuit. « Partir du bas » = l'option B, une source de `~/Downloads` à recuire. §3. |
| D9 | « au **clic d'un jour** sur le calendrier on lance bien la **story 2**, et le **tap d'un jour** [dans This week] pareil » | Un jour entraîné → flash 140 ms → `StoryPortal` **dans l'arbre** (la loi de l'iPod, `CalLab.swift:2479-2495`), sur `StorySession(workout:)` (`StoryFlow.swift:111`) — la vraie séance, plus la démo. §6.3. |
| D10 | « sous le calendrier — enfin **dedans**, sous les jours — un bouton **primary "Voir dans le lecteur"** qui ouvre l'**iPod** avec les sessions du mois » | `DiamondPrimaryButton` (le primaire canonique, `ConnexionButtonLab.swift:145`) au pied de la card calendrier → `MoisIpod` sur **le mois affiché**, portail depuis le bouton. §6.4. |
| D11 | « **ignore les autres sessions** » | Trois fichiers sont le WIP d'autres sessions (§13). On ne les touche pas, on commit par chemins. |

**Sa maquette** (§2) tranche deux choses que les phrases ne disaient pas : la page
est vue **en séance** (le player docké sous la card, « Session du 21 août »), et
la pill vit **à mi-hauteur derrière le calendrier**, son feu au pied de la card.

---

## §1. CE QUI EXISTE — et pourquoi on atterrit sur l'iPod

**L'onglet.** `WoopApp.swift:1041-1047` monte `CalendarStickersPage(onBack:
retourHome, ouvreIpod: true)` sous `Tab("Progrès")`, barre bijou cachée. Le menu
de la home y route par `destinations = [.profile, .progress, .exercises]`
(`HomeNuit.swift:1700`, `:2054`) et le mot est déjà « Progress »
(`MenuNappe.swift:551`). `retourHome()` (`WoopApp.swift:707`) rend la main.

**Pourquoi l'iPod couvre tout.** `CalLab.swift:262` : à l'apparition, `if
Self.ipodBanc || ouvreIpod, moisOuvert == nil` pose `MoisLaunch(month:
DemoMonth.recent.first, rect: .zero, …)` → `.fullScreenCover(item: $moisOuvert)
{ MoisIpod(…) }` (`:285-294`). ⚠️ `onAppear` rejoue à **chaque retour d'onglet**
et la fermeture remet `moisOuvert = nil` : l'iPod se **rouvre d'office** à chaque
entrée. « Atterrir sur l'iPod » est une décision de l'onglet (§23 du 25-08,
`CalLab.swift:57-59`), pas de la page — la page nue (`-calLab`, `-homeRoute
progress` `HomeNuit.swift:4088`) arrive sur la grille **dépliée** (`:66-69`,
`:162-163`).

**Ce que porte la page actuelle** (`CalendarStickersPage`, `CalLab.swift:54`,
**4 794 lignes**, ses commentaires parlent déjà du type-checker qui s'enlise
`:486-488`) :

| couche | où | état |
|---|---|---|
| fond vidéo `FondCalendrier` — `background-calendar-loop.mp4` | `:807-833`, monté `:172` sous voile `0,52` (`:131`) | vivant. **Ce n'est pas une pill** : une nébuleuse au croissant (§3). Un representable maison SANS pose, SANS clip, SANS `dismantle`, SANS reprise au premier plan — six crans sous `CalqueVideo`. |
| en-tête « Calendrier » `enTeteBac` | `:670-688` | vivant — **c'est la robe de Rewards** (§4) |
| la carte-calendrier `CardMorph` (Animatable sur `p`, semaine ↔ mois) | `:935`, montée `:376-401` | vivante, `private`, pilotée par le scroll du bac |
| les ‹ › de mois | `:1082-1103`, `monthStep :403` | vivants, **des `Button`** sous un `DragGesture(min 10)` d'ancêtre (`:400`) — le piège §11 |
| le bac des pochettes-mois `MonthVinyle` | `:449-668` | vivant, démo |
| tap d'un jour → story | `:319` `openStory` → `:356` `launchStory` → `:296` **fullScreenCover** `StoryPortal` | vivant, **sur `DemoSession.at(day)`** (hash) |
| une `SessionSlate` de DÉMO (`workout: nil`, drafts en dur) | `:195-202` | montée dans l'onglet de prod |
| console du verre : appui long 0,6 s | `:239-243` | **actif partout**, même hors `-calTune` |

⚠️ **Aucune séance réelle nulle part dans ce fichier** : zéro `@Query`, zéro
`FetchDescriptor`. Les jours entraînés, les stickers, les pochettes, l'iPod et
la story tapée sortent tous du hash `WoopSticker.demoCategory`
(`:4782-4791`, ~2 jours sur 7). Le seul calendrier qui lit des `Workout` est
`CalendarSection` (`CalendarView.swift:13-29`, `byDay` sur
`startOfDay(startedAt)`), monté par `ProgressionView` (`:51`) — **qu'aucun site
n'appelle** (`docs/screens/reward-popup.md:239` le dit aussi). Code mort, mais
il compile (dossier synchronisé `project.pbxproj:53`).

**L'iPod** (`MoisIpod`, `CalLab.swift:2316`, `private`) reçoit **un**
`DemoMonth` (`:4090`, `start` + `sessions: [DemoSession]`), se ferme par
`RangeeChips(retour: onClose)` (`:2625`), et lance sa story **dans l'arbre**
(`StoryPortal` `zIndex(10)`, `:2484-2495`) après le verdict `:2479-2483` : « le
cover imbriqué ouvrait une ancienne fenêtre en plus… le titre de la story 2
coupé ». `jouer()` (`:3883`) indexe `month.sessions[index]` — **un mois vide le
ferait planter**.

**« This week »** : `SemaineStrip` (`HomeNuit.swift:1283-1599`) et sa mini
`MiniCardJour` (`:1233-1281`) sont dans l'arbre ; la card ROUTE les a remplacés
sur la home (`:2980`, commit `6557a90`) ; `-thisWeek` (`:1851`) les remonte aux
**mêmes ancres** (`:3005`). Le tap d'une mini ouvre aujourd'hui **la route**
(`:3023 ouvrirChemin()`), l'index `i` est jeté — « le jour où une mini ouvrira la
story de SA séance, c'est ici que l'index servira » (`:3021-3022`). C'est ce
jour.

---

## §2. LA MAQUETTE, LUE

Deux frames Figma, même cadre.

**Frame gauche — la page habillée.**
- Header : chevron en chip + « Progress » **sur la même ligne**, à gauche —
  la ligne du coffre, pas le titre centré du profil.
- Un widget « **This week.** / Your last sessions » : l'ardoise translucide et
  **cinq minis** aux dates « 22. AOÛT » … « 26. AOÛT », stickers (bras, flamme,
  basket, abricot, chocolat). Le **rouge de la pill traverse l'ardoise** à
  droite : l'ardoise est en **verre** (`ArdoiseFond(verre: true)`), nourrie.
- La card calendrier, plus haute : `‹ chip` · **Août 2026** · `‹ ›` à droite ;
  sept **capsules** LUN … DIM avec **MER** allumée (le point rouge du jour
  au-dessus) ; six rangées de cases sombres, les jours entraînés portent
  sticker + flamme, **26** (aujourd'hui) en case claire liserée ; en bas de la
  card une **poignée** « — ».
- Le tout dans une grande card noire aux **coins bas arrondis**, dont le bas
  s'embrase (orange), et **sous** elle le player docké « Session du 21 août ·
  En séance · 0 min » avec son stop. → **la page est vue EN SÉANCE**, la card
  raccourcie, le lecteur dessous : exactement D7.

**Frame droite — le fond seul.** Une pill de verre rouge, **tête ronde à
gauche (à ~4 % du bord), corps qui sort à droite**, centrée à ≈ 0,5 de la
hauteur, reflet blanc sur le dôme, feu jaune-orange au cœur bas de la tête ; et
au pied de la card une nappe de feu orange. Sur la frame gauche, ce que l'on
voit de la pill, c'est **ce qui dépasse autour de la card calendrier** : sa tête
à gauche, sa traînée rouge à droite, son feu en bas. La card de verre **la
réfracte** — « le verre n'existe que par la lumière qu'il réfracte » (la loi de
la carte, mémoire du 18-08).

Ce que la maquette **ne dit pas** et que le plan tranche : la poignée « — » au
bas du calendrier est celle de l'ancienne carte-feuille — elle **meurt**, le
bouton « Voir dans le lecteur » prend sa place (D10) ; le chip `‹` à gauche de
« Août 2026 » est l'ancien chevron-retour de la carte — **?** §12.

---

## §3. LES VIDÉOS — mesurées, pas devinées

Tout ce qui, dans `Woop/Media` et `~/Downloads`, ressemble à une pill rouge.
Planches-contact dans `tools/progress/refs/`.

| fichier | format | images · durée · poids | ce que c'est |
|---|---|---|---|
| `background-calendar-loop.mp4` | 1170×2078 · 24 i/s | 290 · 12,1 s · 2,7 Mo | **Le fond ACTUEL du calendrier : une nébuleuse brune, un croissant orange en haut à gauche.** Pas une pill. Aucune recette dans `tools/` (commit `c72f9a5` : « palindrome pré-encodé ») ; source probable `~/Downloads/backgorund_calendar.mp4` (sic). |
| `home-fond-loop.mp4` | 1620×3522 · 24 | 859 · 35,8 s · 14 Mo | La pill couchée dans le coin haut-droit + la flamme, cuites ensemble (`recuit_fond.sh:79-95`). **Orphelin** : `HomeFondVideo` (`HomeNuit.swift:867`) n'a plus aucun site, mais `AssetsVideo.chauffer()` le préchauffe encore (`DepartCine.swift:306`). |
| `home-fond-pilule.mp4` | 1206×964 · 24 | 859 · 35,8 s · 3,1 Mo | La pill SEULE de la home, corps qui sort à **gauche** (`recuit_calques.sh:87-98`). Joué par `CalqueVideo` alignée haut, additif (`DepartCine.swift:685`). |
| **`story-pilule-droite.mp4`** | **1206×964 · 24** | 859 · 35,8 s · 3,1 Mo | **La même en miroir (`hflip`, `recuit_story_ended.sh:121-132`) : tête à gauche, corps qui sort à DROITE — c'est la frame droite de la maquette.** Objet mesuré (lum > 28) : x 0,05→1,00 · y 0,03→0,96 ; bord droit lumineux (43-53/255) = le corps **sort** du cadre, à poser contre le bord droit de la card. 1206 px = **3 × 402 pt** : cuite pour la largeur de l'écran, 321 pt de haut. Poster `story-pilule-droite-poster` ✓. |
| **`home-fond-flamme.mp4`** | **604×642 · 24** | 859 · 35,8 s | **Le feu du pied de la home = la nappe orange au bas de la maquette.** Objet y 0,52→1,00, bord bas lumineux (45) : cuite pour être **coupée par le bas**. Alignée bas dans la home (`DepartCine.swift:641`). Poster ✓. |
| `story-pilule-top.mp4` | 2648×1664 · 30 | 716 · 23,9 s · 17 Mo | La pill ÉNORME de la story TOP, 1,5 écran de large (`StorySuite.swift:993`). Trop lourde pour un fond permanent. |
| `exos-fond-loop.mp4` | 1620×3522 · 24 | 852 · 35,5 s · 16 Mo | La calotte rouge qui entre par le flanc droit à mi-hauteur + flamme (page exo, `recuit_fond_exos.sh:86-105`). |
| `molette-glass-loop.mp4` | 1080² · 30 | 416 · 13,9 s · 3,0 Mo | Le « noir qui brûle » de la molette iPod (`recuit_molette.sh:52-58`). |

Les **sources** de `~/Downloads` (toutes 2160×3836, 24 i/s, bords à vrai zéro
sur les quatre côtés) :

| source | images · durée | couture de boucle (voisines) | objet | ce qu'elle montre |
|---|---|---|---|---|
| **`Video rouge_liquid.mp4`** | 169 · 7,0 s | **16,5** (0,57) → palindrome obligatoire | x 0,24-0,79 · y 0,17-0,80 | **Une pill VERTICALE de verre rouge qui se redresse, son liquide de feu qui MONTE du pied.** La seule qui « part du bas ». |
| `forme_glass_red_2.mp4` | 169 · 7,0 s | 14,2 (0,46) | x 0,30-0,75 | Capsule verticale qui tourne — la source de la molette et du fond exos. |
| `pills_glass.mp4` | 145 · 6,0 s | 12,3 (1,14) | x 0,26-0,76 | Capsule qui penche, le liquide qui se remplit. |
| `pills_2.mp4` | 145 · 6,0 s | 20,2 (0,61) | x 0,24-0,80 | La source de `home-fond-*` (couchée à 75° au recuit). |
| `Video noir_liquid.mp4` | 193 · 8,0 s | 5,2 (0,07) | x 0,25-0,75 | Verre NOIR transparent — pas rouge. |

### La recommandation — A, puis B au banc

**Option A — la maquette, sans recuit (RECO).** Deux `CalqueVideo` dans la card,
l'école exacte de la home (`DepartCine.swift:641-711`) :
1. `home-fond-flamme` alignée **bas**, pleine largeur, coupée par le pied de la
   card — la nappe de feu ;
2. `story-pilule-droite` pleine largeur (402 × 321 pt), **centre vertical à
   ≈ 0,50 H**, collée au bord droit (son corps sort), décalée de **−24 pt** vers
   la gauche pour que la tête entre à ~4 % comme sur la maquette — réglage
   `-progressPill <dy> <dx>` ;
3. les deux en `.blendMode(.plusLighter)` sur le noir et **UN SEUL
   `compositingGroup()` en dernier** (`:704-711`, sinon l'additif fusionne
   contre le noir) ; poses DANS le representable (`:246-249`) ; `rate: 0`
   quand la page n'est pas visible (onglet quitté, story ou iPod ouverts —
   l'école `CalLab.swift:2829-2835`).
   Coût : 2 lecteurs, le régime de la home (60 img/s au téléphone).

**Option B — « elle peut partir du bas » : `Video rouge_liquid.mp4` recuite.**
Recette : crop sur la pill (x 0,24-0,79, y 0,17-1,00 : on garde le pied et son
liquide), scale à 1206 de large, `minterpolate` 30 i/s, **palindrome amputé de
ses deux doublons** (`recuit_molette.sh:35-42` `pingpong`), **jamais `-ss`**
(trim dans le graphe), une seule passe, poster cuit depuis l'image 0. Posée
**alignée bas** : la pill monte du pied de la card, son feu liquide au bord
bas, son dôme de verre sombre derrière le calendrier. Elle remplace alors la
flamme ET la pill d'A (un seul lecteur). À tourner à 30 i/s (le 24 bat en 3:2 à
60 Hz — la leçon de la porte).

**Comment on tranche** : P1 monte A ; `-progressPillBas` monte B ; **deux
captures côte à côte**, même build. Kathryn choisit à l'œil, le plan ne choisit
pas pour elle — mais A coûte zéro cuisson et **c'est sa maquette**.

⚠️ Dans les deux cas : ajouter le fichier joué à `AssetsVideo.chauffer()`
(`DepartCine.swift:304-307`) — sinon il se parse à froid au premier affichage,
« la vidéo lag » du 26-08 — et en retirer `home-fond-loop` (orphelin).

⚠️ **Pas de voile global.** La page calendrier en met un à 0,52 sur sa nébuleuse
(`CalLab.swift:174`) ; ici la pill DOIT arriver aux cards de verre. La
lisibilité vient de la teinte des cards elles-mêmes (la carte-calendrier en
`noir 0,5`, la loi du 18-08) et se **mesure** en P1 : luminance sous l'encre du
calendrier sur les pixels clairs, pas en moyenne de ligne.

---

## §4. LA ROBE — le header, l'apparition à l'Apple

### 4.1 Le header « Progress »

La recette, telle qu'elle est écrite deux fois :

```
HStack(spacing: 14) {
    ChipVerre(symbole: "chevron.left", label: "Retour", action: onBack)   // ChipVerre.swift:10-81
    Text("Progress")
        .font(.inter(30, .bold)).tracking(-0.4)                             // Inter-Bold, le FICHIER (Theme.swift:11)
        .foregroundStyle(WoopGradient.titleFade)                            // Theme.swift:170-179
    Spacer()
}
```
— `CalLab.swift:670-688` (`enTeteBac`, « Calendrier ») et `CoffreV2.swift:3135-3152 + 3213-3224` (« Rewards »).

`titleFade` = blanc 1,0 → 0,90 à 0,32 → 0,60 à 0,68 → 0,25 à 1,0, en **diagonale**
(`topLeading → bottomTrailing`) : fait pour un titre d'UNE ligne, jamais une
phrase (mesuré `PorteEntree.swift:680-690`).

**La cote — UNE seule, et c'est celle de la loi.** Le dépôt en a trois pour « la
même » rangée : le coffre à `22 / 63` physique (`CoffreV2.swift:3147-3151`, page
en `ignoresSafeArea`), `enTeteBac` à `20 / safeTop + 6` (`CalLab.swift:682-683`),
`RangeeChips` à `20 / 4` dans la zone sûre (`ChipVerre.swift:99-100`) — pour un
même `ChipVerre.swift:83-85` qui dit « la position du chevron ne bouge JAMAIS
d'une page à l'autre ». **Progress prend `RangeeChips` : leading 20, top
safeTop + 4** (le profil et l'iPod, prouvés au pixel le 24-08 : chevron `x
111→133, y 245→283` sur les deux pages). Le coffre a dérivé de 2 pt : c'est sa
dette, on ne la copie pas. Le titre à 14 du chevron, sur sa ligne.

Garde de toucher : le chevron est **sourd tant que l'arrivée n'a pas passé 0,6**
(`CalLab.swift:687` `allowsHitTesting(p2 > 0.6)`), et le titre est toujours
sourd (`ProfilLune.swift:234`).

### 4.2 L'apparition « à l'Apple : blur » — les lois d'abord

- `.blur` pose un **voile uniforme sur le rectangle de l'hôte** et coûte
  **27 img/s par objet** (skill §2/§5). Donc : **transitoire**, et le rayon
  retombe à **ZÉRO EXACT** (`q > 0.995 ? 0 : …`, `CoffreV2.swift:1155-1158`).
  Jamais en permanence, **jamais pendant un drag** (le verre qui bouge :
  36,8 → 60 img/s, `HomeNuit.swift:2704`).
- Le flou vit sur les **GLYPHES et l'encre**, pas sur les boîtes : sur une boîte
  il gonfle les bornes du rayon et floute toute la surface (1,47 Mpix/image,
  `HomeNuit.swift:395-398`).
- Un blur sur du **verre natif** empile deux passes → plafond **6 pt**
  (`HomeNuit.swift:2949-2954`).
- Un `.mask`/clip est dimensionné sur son hôte : **le halo du flou se coupe au
  bord** (`HomeNuit.swift:437-449`). Ici les composants sont à ≥ 20 pt des bords
  de la card (marge 24 de l'ardoise) : un rayon de 9 n'atteint jamais le clip.

**La forme retenue = `ArriveeFloue`** (`CoffreV2.swift:1159-1170`), le
`ViewModifier` du coffre, déjà cité par `BoosterCard.swift:264` :
`q = clamp((p − 0,055·rang) / 0,62)` · `blur(q > 0,995 ? 0 : 9(1−q))` ·
`offset(y: 9(1−q))` · `opacity(q)`. Il sort de `CoffreV2.swift` vers un fichier
partagé (**P0**) — `ChipVerre.swift` est déjà le fichier des composants
d'en-tête, il l'accueille.

**La cascade de Progress** — une seule horloge `arrivee` 0→1, **linéaire 1,0 s
après 0,18 s** (le tempo de « Rewards », `CoffreV2.swift:3701` : linéaire 1,18
retard 0,22 — sa page validée, sa robe) :

| rang | ce qui arrive | comment |
|---|---|---|
| 0 | le titre « Progress » | `ArriveeFloue` plein (9 pt) — de l'encre |
| 0 | le chevron | **opacité + 9 pt de montée, SANS blur** (verre natif) |
| 1 | l'ardoise « This week » | la coquille `ArdoiseFond` : opacité + montée · **son contenu** (titre, minis, stickers) : `ArriveeFloue` |
| 2 | la card calendrier | idem : coquille sans blur, contenu (mois, capsules, cases) en `ArriveeFloue` |
| 2 | « Voir dans le lecteur » | arrive **avec** sa card (même rang), en opacité |

Le drag de page (§7) n'est **armé qu'à `arrivee ≥ 1`** : aucun flou sous un
doigt, par construction. Et la sortie (chevron) est une extinction en opacité
0,25 s — le blur n'a qu'un sens, celui de l'arrivée (la porte : « un objet lourd
se pose lentement », `PorteEntree.swift:1851-1870`).

---

## §5. « THIS WEEK » ET LE VARIANT VIDE

### 5.1 Ce qu'on remonte, tel quel

`SemaineStrip(faits:prevus:arrivee:materialises:onTap:lisere:verre:sousTitre:)`
(`HomeNuit.swift:1283-1301`). Ses cotes RÉELLES — le plan home v2 est périmé
(`PLAN-HOME-V2.md:988` dit 354×122/24, 70×87, ±9°) :

- ardoise **354 × 128**, rayon **26** (`:1317`), coquille `ArdoiseFond`
  (`:1362`, `WidgetsCards.swift:430-502`) ;
- minis **70 × 78**, rayon 10, plaque 0,060→0,030, cheveu 6 %, grain 0,05
  (`:1243`) ; date à deux étages « 22. » Inter 10 bold / « AOÛT » Inter 5,5
  semibold blanc 0,45 (`:1261`, formateurs `fr_FR` `:1594` — **LA source des
  dates de la maison**, `DateGalet` la lit aussi `GaletEtape.swift:71`) ;
  sticker asset 36 pt à (0,443 L ; 0,590 H), tranché par le bord bas (`:1273`) ;
- layout **fixe + transforms** (jamais un HStack, `:1344-1345`) : alternance
  0° / 6°, une mini sur deux montée de 10 pt, **pas 51**, z croissant vers la
  droite (`:1346-1354`) ; `n = max(prevus, 1)` emplacements TOUJOURS posés et
  centrés sur `n` (`:1314`, `:1347-1351`) ;
- titre « This week. » Inter 20 semibold blanc 0,94, sous-titre system 8,5
  tracking 3 % `CardTon.encreDouce` (`:1381`) ; padding top 16 / leading 22.

Ancres sur la home (à reprendre en esprit, pas en chiffres) : `leading 24`,
pose = dernier tiers de l'arrivée + 14 pt (`:1484`). **`verre: true`** sur
Progress : la pill passe derrière, le verre est nourri (la home l'éteint quand
`homeDort` — ici il n'y a pas de nuit).

### 5.2 Le variant VIDE — ce qui manque, et la recette

**Aujourd'hui** : `mini(i)` rend `MiniCardJour(... faite: i < solides ...)`
puis `.opacity(faite ? 1 : 0)` (`:1564-1571`) et `.allowsHitTesting(i < solides)`
(`:1422`). Le seul reste du « à faire » est `scaleEffect(faite ? 1 : 0.7)` sur
le sticker (`:1277`). Les **fantômes de verre** `.clear` par emplacement ont été
**tués** au commit `18f57a6` (verdict 22-08 « enlève les carrés bizarres gris
clair » : un verre à jeun sur l'ardoise sombre est un rectangle gris,
`:1365-1372`). ⚠️ Le doc-commentaire `:1202-1216` décrit encore les fantômes —
il ment, ne pas le lire comme l'état.

**Le layout est déjà prêt** : `ForEach(0..<n)` monte `n` minis (`:1392`), leurs
places, leur z, leur secousse sont calculés. **Rendre le vide = changer
`mini(i)`, rien du layout.**

**La recette du vide, dans la loi des galets** (`GaletEtape.swift:624-631` :
« un jour à venir est en MODE EMPTY : le verre creux, la flamme fantôme, et rien
d'autre » ; `:633` « l'état se dit par la CLARTÉ, jamais par la couleur ») :

| | mini FAITE | mini VIDE (nouveau) |
|---|---|---|
| plaque | 0,060 → 0,030 + cheveu 0,06 | la même forme, **fumée 0,20** — un disque creux, la pill passe au travers (le profil `.verrouille` du galet `:678-682`) ; cheveu 0,04 |
| date | « 22. / AOÛT » | **aucune date.** La loi de la route : « un jour futur qui afficherait sa date promettrait un contenu qu'on n'a pas » (`DuolinguoPage.swift:490-492`, `dateReelle` rend nil `:471-473`). `MiniCardJour.date` devient optionnelle. |
| glyphe | sticker asset 36 pt | **SF `flame` en contour, `.ultraLight`** — le fantôme d'une flamme (`GaletEtape.swift:779-793`, `DuolinguoPage.swift:1229` : « le cheveu seul »), taille **18 pt** (0,26 × Ø du galet transposé à la mini), à la place du sticker, laque 0,92→0,74 à **0,45 × 0,85** |
| geste | tap → story (§6.3) | **inerte** (`allowsHitTesting(false)`) |
| arrivée | `ArriveeFloue` | idem, mais elle « se matérialise » ensuite quand une séance se clôt (le `materialises` existant, ressort 0,55/0,80, `:3873-3881`) |

**?** L'autre flamme éteinte de la maison — `StickerFlamme` de la jauge de séries
(`FlammeJauge.swift:1279-1316`) : le **sticker** `sticker-flamme-serree` à
**0,16** d'opacité, « c'est la place vide qui se lit, pas un objet de plus »
(`:1275-1278`), et sa rangée `FlammesRow` calcule déjà « les séances restantes de
l'objectif » (`vides = objectif − faites`, `:1241-1243`). Deux flammes vides
cohabitent dans l'app ; elle a dit « comme les galets » → **reco : le contour
SF**, et le sticker à 0,16 en **A/B d'une ligne** au banc P2. §12.

### 5.3 Combien de minis, quelles dates, quel sticker

- **`n = max(objectif, faites)`** — on ne cache jamais une séance faite. À
  objectif 7, le groupe fait `6 × 51 + 70 = 376 > 354` : les deux minis du bord
  seraient tranchées par le clip. **Le pas s'adapte** : `pas = min(51,
  (354 − 44 − 70) / (n − 1))` → 40 à sept minis. **?** §12.
- L'objectif = `@AppStorage(Goal.cleHebdo)` défaut `Goal.weeklyTarget` (5),
  **la même clé que la home** (`HomeNuit.swift:1619`, `Models.swift:566-583`).
  ⚠️ `Goal.hebdo` n'est lu nulle part ; les pages mortes lisent encore la
  constante 5 (`CalendarView.swift:125`) — un objectif réglé à 4 donne 4 minis
  ici et « 5 » ailleurs. Dette à part, pas ce chantier.
- **Les dates deviennent VRAIES.** Aujourd'hui `date(i)` invente « les derniers
  jours jusqu'à aujourd'hui » (`:1578-1583`) et le sticker est un modulo
  (`:1567`, table de 7 `:1327`). `SemaineStrip` reçoit une liste
  **`jours: [JourFait]`** (`date`, `workout`, `sticker`) au lieu de `faits:
  Int` — les faites dans l'ordre chronologique, puis les vides. Source :
  `SemaineStats` (`WidgetsCards.swift:2185-2270`, semaine **lundi**, séances
  `!isActive`, `startedAt` dans la semaine ; `joursFaits` `:2258`), **calculée
  UNE fois** à l'apparition et au retour de séance (`HomeNuit.swift:2397,
  2499`), jamais dans un `body`. `faits: Int` survit comme repli pour les bancs.
- Le sous-titre « Your last sessions » reste — avec des vides il dit encore
  vrai (les faites SONT les dernières). **?** « 2 of 4 planned » — §12.
- Sur Progress les minis ne sont **plus un jouet** : pas de port au doigt, pas
  de poudre (`:1428` `DragGesture(min 0)`, `:1461` `d > 24 → semer`) — un
  enfant qui a un geste bat le drag de la page (§11). Un drapeau `jouet: false`
  → les minis faites portent `contentShape + highPriorityGesture(TapGesture)`
  → `onTap(i)`. La secousse au poignet (`SkyMotion`, `:1537`) reste : un
  transform, pas un geste.

---

## §6. LE CALENDRIER

### 6.1 Ce qu'on extrait, ce qu'on réécrit

`CardMorph` (`CalLab.swift:935`) est un **morph** semaine↔mois piloté par un
curseur de scroll, dépendant de `GlassTuning`, avec sa console. Progress veut
une grille **fixe, dépliée, dans une card** — l'état `p = 1` de `CardMorph`
sans sa mécanique. On ne remonte pas le morph : on écrit **`CalendrierMois`**
(dans `ProgressPage.swift`) à partir des briques PURES, dé-privatisées en P0 :

| brique | où | ce qu'on en fait |
|---|---|---|
| `CalSlot.month(of:calendar:)` | `CalLab.swift:904-925` — pure : une case par jour, `col = i % 7`, `row = i / 7`, lundi d'abord | réutilisée telle quelle |
| `calendar.firstWeekday = 2` | `:143-147` — comme `SemaineStats` (`WidgetsCards.swift:2203`) | la même semaine partout |
| `StickerDayCell(day:size:isToday:calendar:flashing:onTap:)` | `:1175-1278` : plaque 0,055 (aujourd'hui 0,10 + cœur chaud + liseré `LisereMedaillon.crans` + bague floutée `:1237-1248`), sticker catégorie 0,52·s, flamme 0,34·s à 12°, « ×2 » 0,38·s, flash au tap `:1253`, tap → rect `.global` `:1268-1276` | réutilisée, **une chirurgie** : elle appelle `WoopSticker.demoCategory` en interne (`:1202`) → elle reçoit `categorie: WoopSticker?` et `double: Bool` en entrée (la page démo continue de lui passer le hash) |
| les en-têtes LUN…DIM | `:962-967` (trois lettres des symboles courts, réordonnés) ; rangée `:1107-1135` : pastille 0,07, point rouge du jour à y − 11 | reprises en **capsules** (la maquette) : 7 capsules blanc 0,07, texte 9 semibold tracking 1 `encreDouce` ; le jour courant = capsule 0,16 + encre 0,94 + le point rouge |
| les ‹ › et `monthStep` | `:1082-1103`, `:403-409` (`byAdding: .month`, ressort 0,42/0,86, `pushEdge`) ; transition `.push(from:)` sur `.id(monthTitle)` `:1163` | reprises — mais plus des `Button` : `contentShape + highPriorityGesture(TapGesture)` (§11) |
| `CalGeo` | `:842-900` : `padFull 14`, `gapFull 6`, `sFull = (L − 28 − 36) / 7` | seules ces trois cotes ; le reste (semaine-pivot, `safeTop`) est le morph |

### 6.2 La card

- **L = 354**, rayon 26, coquille `ArdoiseFond(verre: true)` — **la même
  matière que « This week »**, une seule ardoise pour deux cards.
- Titre du mois « Août 2026 » en **Inter 20 semibold 0,94** — le registre de
  « This week. » : un seul registre de titre de card sur la page. À gauche,
  padding 22. Les ‹ › à droite, 44 × 44 chacun, glyphe 15 semibold.
- Les capsules LUN…DIM à 12 sous le titre, la grille à 12 sous les capsules.
- **Six rangées toujours** (`sFull ≈ 41,4`, hauteur de grille `6 × 41,4 + 5 × 6
  = 278`) : la card **ne change pas de taille** d'un mois à l'autre — rien ne
  saute au ‹ › (loi : ce qui bouge ne change pas une taille).
- Sous la grille, à 16 : **`DiamondPrimaryButton(title: "Voir dans le
  lecteur")`**, 58 de haut (`ConnexionButtonLab.swift:182`, la grille « 58, là
  sur toutes les pages », `CoffreV2.swift:1334`), padding horizontal 26, le
  bijou d'obsidienne, capitales tracking 4,6 (`:227`). Puis 18 de pied.
- Hauteur de card ≈ **476** (§9).
- Le mois affiché est un `@State monthAnchor` (`CalLab.swift:62`), initialisé
  à aujourd'hui ; la page **ne recale pas** sur le mois courant en douce (le
  repli de `CardMorph` le faisait, `:420-423`) — c'est la bascule qui commande.

### 6.3 Le tap d'un jour → la story

La chaîne d'aujourd'hui, gardée : `onTap(rect)` d'ENFANT (`:1273`, un
`onTapGesture` survit à un drag d'ancêtre) → `flashDay` → **140 ms** →
`CalStoryLaunch(rect:session:)` → 500 ms → extinction du flash (`launchStory`,
`:356-364`). Deux changements :

1. **La séance est VRAIE** : `StorySession(workout:)` (`StoryFlow.swift:111-145`
   — titre = catégorie, « Séance du d MMMM », minutes, exos, séries, `groupes`
   depuis `orderedExercises`), le même constructeur que la story de fin de
   séance (`WoopApp.swift:555-566`, commit `8e8a0cc` de ce matin). Plus jamais
   `DemoSession.storySession`.
2. **Le portail est DANS L'ARBRE**, `zIndex(10)`, pas un `fullScreenCover`
   (`CalLab.swift:296`) : la loi de l'iPod (`:2479-2495`) et de la racine
   (`WoopApp.swift:548-566`). Une page-card qui se drag au-dessus d'un futur
   lecteur ne peut pas empiler un modal — c'est la classe de bug du gel
   `e9521cf`. `StoryPortal(from: rect, fromRadius: s × 0,28, session:)`
   (`StoryFlow.swift:553-558`), fermeture `:614-621`. Pendant la story, la pill
   passe à `rate: 0`.

**« Story 2 » = la story v2**, le flux entier (ouverture → détails → analyse →
butin, `StoryFlow.swift:275-283`). Dans le code, « l'écran 2 » est la page
**Détails** (`StorySuite.swift:3`, `SlateListe` `StoryFlow.swift:65-68`) —
`StoryFlow` n'a **aucun paramètre de page de départ** (`page = 0`, `:251`). Si
elle veut atterrir directement sur Détails : un `pageDepart` à ajouter à
`StoryFlow` et `StoryPortal` (deux lignes). **?** §12.

Une **mini faite** de « This week » ouvre la **même** story, depuis son propre
rect (`onTap(i)` → `jours[i].workout`). Deux séances le même jour : la mini
porte la sienne (la liste est par séance), la case du calendrier ouvre la
**première** et porte « ×2 ».

### 6.4 « Voir dans le lecteur » → l'iPod du mois

`MoisIpod` est typé sur la démo : `month: DemoMonth` (`CalLab.swift:2316`), avec
`MoisLaunch(month:rect:precedentNom:precedentCompte:precedentReps:)` (`:775-782`)
pour sa phrase de comparaison. Trois gestes, tous en P0/P5 :

1. `DemoMonth`, `DemoSession`, `MoisIpod`, `MoisLaunch` passent **internes**
   (`private` → rien). `DemoSession` gagne `init(workout: Workout)` : `cat` =
   sticker de la séance (§8), `series = setCount`, `reps` = somme, `name` =
   « Session du … » déjà formaté par la date ; `storySession` devient
   `StorySession(workout:)` quand un `Workout` est là. **Aucun renommage** —
   la page démo continue de tourner.
2. `ProgressPage` fabrique `DemoMonth(start: 1er du mois affiché, sessions:
   séances du mois)` et le mois précédent pour la phrase, puis
   `.fullScreenCover(item: $moisOuvert)` avec `.presentationBackground(.clear)`
   — **le même cover qu'aujourd'hui** (`:285-294`), c'est une page entière, pas
   un overlay ; on ne le démonte jamais pendant une bascule d'onglet. Portail
   **depuis le rect du bouton** (mesuré en `.global`, `onGeometryChange`) : la
   cérémonie de `MoisIpod` sait partir d'un rect (`depuis:`).
3. **Un mois sans séance n'a pas de bouton** — la loi du coffre (« le bouton
   n'existe pas quand le solde est à 0 », `docs/screens/coffre-rewards.md:106`),
   et `jouer()` (`:3886`) ne peut plus indexer un tableau vide. **?** §12.

Et l'ancienne ouverture d'office meurt avec `ouvreIpod: true`
(`WoopApp.swift:1046`) — P7.

---

## §7. LA CARD QU'ON DRAG, ET CE QU'IL Y A DESSOUS

### 7.1 Le patron, en trois exemplaires qui ne partagent rien

| | exos (`ExercisesView.swift`) | home (`HomeNuit.swift`) | coffre (`CoffreV2.swift`) |
|---|---|---|---|
| forme | `FormeCardExos` Shape Animatable sur `levee` (`:259`), 4 coins 55, marge haut 10 (`ExosFond.swift:112`) | `GrandeCardVideo` marge 0 rayon 55 (`:984`), `.padding(.bottom, levee − encartBas)` (`:1124`) | `FormeScene`, coins hauts 0 (`:759`) — le patron exos « découpait le mur » (`:2724`) |
| état | `@Observable EtatExos`, `tirage` signé (`:100-230`) | `@State tirage` (`:1668`) | `@State tirage` (`:1605`) |
| geste | deux poignées `highPriorityGesture(min 10)` + `.gesture(min 2)` verrou 3 pt (`:816`), + le débord du scroll (`:1889`) | `simultaneousGesture(DragGesture(min 2))` sur `MenuHote`, verrou 4 pt (`:2167`, `:3313`) | UN geste page `min 0`, `enum Cible` à 10 pt (`:3332-3358`) |
| élastique | `160·tanh(t/150)` (`:774`) | `140·tanh(net/140)` (`:3345`) | `140·tanh(net/190)` (`:3451`) |
| lâcher | spring 0,50/0,86 (`:783`) | **plus aucun ressort** — timingCurve (`:3436`, « tu vas trop vite ») | spring 0,42/0,84 (`:3521`) |
| lune | `luneP = (−t−62)/56` (`:216`) + lune du HAUT (`:228`) | `(−t−70)/60` (`:2014`) | les constantes de la home (`:1722`) |
| levée séance | 106 (`:454`) | **96** = 6 · 76 · 14 (`:1968`) | 140 |

Le coffre a **tout recopié** et rien promu ; les modificateurs des exos
(`CarteLevee :290`, `MonteAvecLaCard :303`, `CadreCarte :372`, `BandeExos :1213`,
`EclatLune :1190`) sont `private` ET couplés à `EtatExos`. Un quatrième
exemplaire vit **non commité** dans `ExerciseDetailView.swift:606-625` (« LE
RIDEAU », WIP d'une autre session : `pageContenu.offset(y: −pageLevee·ampl)`,
`playerDessous` = `WorkoutPill(docked:)` + `SlateListe`) — c'est exactement « le
lecteur sous la card », **on ne le touche pas** (§13).

⚠️ **LE PARTAGE DU 30-08** (Kathryn, via la session player *woochoper-ios-30*,
mandatée pour unifier le player) : **le player = UN composant `PageCard`, en bas
partout, même geste ; au drag de la dalle, c'est la PAGE qui est poussée vers le
haut et la partition naît dessous.** Chaque page est une « grosse card ». Deux
lois qu'elle a payées aujourd'hui : *la partition ne se MONTE que pendant le
drag (`levee > 0.02`), jamais en continu* (un `WorkoutPill + SlateListe` rendu
caché derrière la page = téléphone qui chauffe, mémoire
`woop-piege-rideau-player-derriere`) ; *offset + masque, jamais un frame animé ;
données figées à la prise*.

**Décision, alignée** : Progress est une **grosse card** — `FormeCardExos`
(interne, réutilisée telle quelle) qui clippe son contenu, un `levee` qu'elle
**REÇOIT**. Le geste de levée, la dalle et la partition appartiennent à
`PageCard` — **Progress n'écrit aucun geste de player**. Si `PageCard` n'est
pas là au moment de P6, un `EtatProgress` provisoire (copie fidèle des exos :
`160·tanh(t/150)`, `luneP` 62/56, lâcher en **timingCurve** sans ressort — la
loi de la home du 26-08, **pas un quatrième réglage**) tient la card jusqu'à la
convergence, et meurt quand `PageCard` arrive. Question posée à la session
player : la cote de levée en séance (96 de la home ou 106 des exos) — Progress
réserve la zone qu'on lui dira.

### 7.2 La card vidéo

`GrandeCardExos` joue `exos-fond-loop` **en dur** (`ExosFond.swift:57`, poster
`:154`) ; son commentaire `:11-18` explique le jumeau par le chantier de la home,
pas par une impossibilité. **P0 : `GrandeCardExos` reçoit `video:` et `pose:`
(défauts = exos)** — zéro troisième jumeau. Progress lui passe **deux** calques
(§3 A) : la card devient `Color.black.overlay(Color.clear.overlay { ZStack {
poses ; flamme alignée bas ; pill à 0,50 H } }.clipShape(forme))` — l'hôte
NEUTRE tient la taille (`:130-165`, l'incident des 2,3 pt), `clipsToBounds +
masksToBounds` (`:55`), marge haut **10**, coins **55**.

### 7.3 Le geste — et pourquoi la page ne scrolle pas

Header + This week + calendrier + bouton tiennent dans l'écran (§9) : **pas de
`ScrollView`**. C'est ce qui rend le drag propre — « on ne partage pas un doigt
avec un ScrollView » (`ExercisesView.swift:750-757`), et c'est ce qui autorise
**l'école de la home** : `.simultaneousGesture(DragGesture(minimumDistance: 2))`
sur le contenu de la card (`HomeNuit.swift:2167` — « jamais `.gesture` : il
affamerait slider, galet, cards »), donc :

| le doigt sur… | qui gagne | forme |
|---|---|---|
| le chevron | `ChipVerre` (un `Button`) | survit au `simultaneousGesture` d'ancêtre — comme sur la home |
| « Voir dans le lecteur » | `DiamondPrimaryButton` (un `Button`) | idem — et il **garde son appui** (le remède du coffre `allowsHitTesting(false) + highPriorityGesture`, `CoffreV2.swift:1426-1429`, perd le `isPressed` du shader : `DiamondPressStyle` `ConnexionButtonLab.swift:375-383` — on n'en a pas besoin ici) |
| les ‹ › | `contentShape + highPriorityGesture(TapGesture)` | ce ne sont plus des `Button` (aujourd'hui `:1094`) |
| une case entraînée | `onTapGesture` d'enfant | survit (`SessionSlate.swift:448-452`, `CalLab.swift:1273`) |
| une mini faite | `highPriorityGesture(TapGesture)` | `jouet: false` (§5.3) |
| n'importe où, vertical | le drag de page | verrou d'axe décidé **une fois** à 4 pt (`:3313-3319`), course morte de 2 pt retranchée (`:3345`) |
| horizontal | personne | réservé (le verrou l'ignore) |

Les trois gardes payées : **remise à plat sur `startLocation`** en tête de
`onChanged` (`:3301-3306`), **chien de garde 0,30 s à jeton** qui rejoint
`reposCard` — l'état STABLE, jamais un état inventé — (`:3500-3515`), et
**`allowsHitTesting(false)` sur la story/l'iPod ouverts** (les pixels et le
hit-test sont deux choses).

### 7.4 Ce qu'il y a dessous

- **Hors séance** : tirage vers le haut → la card se **raccourcit par le bas**
  (masque `FormeCardExos(levee:)`, jamais un frame — « un padding animé
  redimensionne l'AVPlayerLayer 60×/s, c'est ça qui laggue »,
  `ExercisesView.swift:194-208`) et découvre **`LuneSecrete`** (`HomeNuit.swift:1162`,
  interne, réutilisée par exos et coffre), construite UNE fois à `p = 1` et
  modulée par opacité + échelle (`EclatLune`, `:1190-1199`) ; haptique `.soft`
  une fois par découverte (`:790`). Tirage vers le bas : élastique seul, rien
  n'est révélé (pas de lune du haut — c'est une page, pas un tiroir).
- **En séance** (dérivée de la base : `@Query(filter: endedAt == nil)`,
  `ExercisesView.swift:407`, jamais un drapeau) : levée FIXE — **96** (`6 · 76 ·
  14`, `HomeNuit.swift:1968`) sauf si la session player en dit une autre —
  jouée dans un `withAnimation(initial: true)` (`ExercisesView.swift:544`, le
  `@Query` arrive après la première image). **Progress ne monte AUCUN player** :
  ni `WorkoutPill`, ni `SessionSlate`, ni `SlateListe`, ni visible ni caché
  (la loi du rideau). La dalle dans la bande découverte — l'état de la maquette
  — est celle de `PageCard`, le composant commun à toutes les pages
  (`PLAN-PLAYER-CARD.md`, session player). La forme ACCEPTÉE reste la dalle
  dockée, « la carte flottante est morte — deux fois » (`PlayerSeance.swift:5-6`).
- **Le crochet** : la page **dégage la zone** par sa levée fixe, expose `busy`
  (la dalle en main → tout geste de la page se tait, l'école
  `CalLab.swift:400` `isEnabled: !slateBusy`), et accepte d'être **poussée**
  (son `levee` vient de `PageCard`). Rien d'autre à prévoir : la zone est là,
  le composant est à eux.

---

## §8. LES DONNÉES — de vraies séances, une seule fonction de sticker

**Ce que la page lit** : `@Query(sort: \Workout.startedAt)` (le pattern vivant
de `CoffreFortView.swift:523`), filtre `!isActive` (`Models.swift:332`),
groupement par **`startOfDay(startedAt)`** (`CalendarView.swift:27-29`,
`SemaineStats` `WidgetsCards.swift:2200`). Un dictionnaire `[Date: [Workout]]`
en `@State`, rempli **une fois** à l'apparition et au retour de séance — jamais
une propriété calculée relue par le corps (skill §2, règle 1).

⚠️ **Le jour d'une séance a deux définitions dans l'app** : `startedAt` (le
calendrier, `SemaineStats`) et `endedAt` (le chemin) — l'audit `tools/road/
AUDIT-CHEMIN-CALENDRIER-STORIES.md` §2 ne l'a pas tranché. Une séance à cheval
sur minuit tombe sur deux jours selon la page. **Reco : `startedAt`** (deux
lecteurs sur trois), et une seule fonction `Workout.jour(calendar:)` que le
chemin adoptera à son tour. **?** §12.

**Le sticker.** Trois sources aujourd'hui, aucune vraie : la home (`stickers[i %
7]`, `HomeNuit.swift:1567`), le calendrier (le hash, `CalLab.swift:4782`), la
story (une heuristique sur le TITRE, `StorySuite.swift:368-400` — `planche`,
privée). Le serveur n'a **aucune colonne** (`workouts?select=sticker` → 400,
mémoire). Mais la donnée existe DÉJÀ dans le modèle : `Workout.categories`
(`Models.swift:378-386`, depuis `logged.exercise?.category`) sur
`ExerciseCategory { haut, abdos, bas, fessiers, cardio }` (`:9-14`). **Une
fonction, trois écrans** :

```
WoopSticker.pour(_ w: Workout) -> WoopSticker
  .haut → .bras · .abdos → .chocolat · .bas → .jambes · .fessiers → .abricot · .cardio → .basket
  (la catégorie DOMINANTE = la première de `categories` ; la nage n'existe pas dans le modèle → .piscine reste à la story)
  vide → .flamme
```
— le mapping tranché le 26-08 (mémoire stickers : bras = haut, jambes = bas,
abricot = fessiers, chocolat = abdos, basket = cardio). Le calendrier pose
**toujours la flamme** + la catégorie par-dessus (`StickerDayCell`, `:1202-1226`),
« ×2 » quand deux séances le même jour (`:1217`, aujourd'hui `demoDouble` — un
autre hash) — le variant ×2 devient un **fait**, plus un tirage.

**Ce que ça vaut au site de doc** : rien ne change côté serveur — pas de
`select`, pas de fonction, pas de migration → **ce n'est pas une modification
backend** au sens de `CLAUDE.md` ; les pastilles restent 🟡 (« l'historique du
calendrier ne survit pas à une réinstallation », `docs/site/index.html:1654-1682`
@HEAD : « `SupabaseSync` n'a qu'un `push` », `SupabaseSync.swift:70-139`, tout
POST). Le jour où un `select` de `workouts` entre, c'est 🟡 → 🟢 **après appel
réel lu**, même commit, même URL. Deux choses à **signaler** sans les faire ici :
la pastille `b-flow-story2` ⚪ (`:1288`) est **périmée depuis `8e8a0cc`** (la
story de fin de séance existe, `WoopApp.swift:515-525`) ; et la figure
« Calendrier · à capturer » (`:704`) se remplira avec cette page (P8). ⚠️
`docs/site/index.html` de l'arbre est **réécrit par une autre session** (build
v2, `docs/site/content/*.ts`) : on ne touche pas au HTML.

---

## §9. L'ANATOMIE — la chaîne de cotes (iPhone 17 Pro, 402 × 874, safeTop 59, encart bas 34)

```
   0 ┌──────────────────────────────────────┐  page noire
  10 │╭────────────────────────────────────╮│  la card (marge haut 10, coins 55) — la pill + le feu dedans
  63 ││ [‹]  Progress                      ││  RangeeChips : 20 / safeTop+4 · 44 de haut · titre 30 bold à +14
 107 ││                                    ││
 123 ││   ╭── This week. ──────────────╮   ││  354 × 128 · leading 24 · verre nourri
     ││   │  Your last sessions        │   ││  n = max(objectif, faites) minis 70 × 78, pas 51 (40 à 7)
 251 ││   ╰────────────────────────────╯   ││
 265 ││   ╭── Août 2026 ·········· ‹ › ╮   ││  354 × ~476 · verre · titre 20 semibold
     ││   │  LUN MAR MER JEU VEN SAM DIM │   ││  capsules 0,07, le jour à 0,16 + point rouge
     ││   │  ┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐┌──┐│   ││  sFull = (354−28−36)/7 ≈ 41,4 · gap 6 · SIX rangées fixes = 278
     ││   │  … 6 rangées …               │   ││
     ││   │  ┌────────────────────────┐  │   ││  DiamondPrimaryButton 58 · « VOIR DANS LE LECTEUR »
 723 ││   │  └────────────────────────┘  │   ││
 741 ││   ╰────────────────────────────╯   ││
 778 │╰──────────────── ⌒ ────────────────╯│  EN SÉANCE : la card s'arrête ici (levée 96 = 6 + 76 + 14)
     │   ▭ WorkoutPill docké 76, à 14 du bas │
 874 └──────────────────────────────────────┘  HORS SÉANCE : la card va au bord, la lune se lève sous elle au tirage
```

Budget : 59 + 4 + 44 + 16 + 128 + 14 + 476 = **741**, pour une arête de séance à
778 → **37 pt d'air** au-dessus du player. À 7 minis ou en changeant de mois,
**rien ne bouge** (pas adaptatif, six rangées). ⚠️ Ces cotes sont un budget, pas
une mesure : elles se **posent au banc** (P1) et se lisent à la capture — la
marche de 34 pt de l'encart (`HomeNuit.swift:1108-1124`) et le `GeometryReader`
qui doit RESPECTER la zone sûre pendant que son contenu l'ignore
(`ExercisesView.swift:463-467`) sont deux pièges de layout qui ne se voient
qu'en pixels.

---

## §10. LES JALONS — chacun son banc, chacun sa mesure

Simulateur **dédié** (école kat-story/kat-coffre : les captures des sessions
parallèles s'écrasaient sur le sim partagé), `-derivedDataPath dd-progress`, et
`pgrep -fl xcodebuild` avant chaque build. Le code de sortie du build se lit sur
`$?` **sans pipe** ; la date du `Woop.debug.dylib` avant toute capture.

| jalon | ce qu'on fait | banc | ce qui prouve |
|---|---|---|---|
| **P0 — les extractions** (rien ne change à l'écran) | `ArriveeFloue` → `ChipVerre.swift` · `GrandeCardExos(video:pose:)` · `CalSlot`, `StickerDayCell(categorie:double:)`, `MoisIpod`, `MoisLaunch`, `DemoMonth`, `DemoSession(+init(workout:))` internes · `MiniCardJour` état vide + `date` optionnelle · `SemaineStrip(jours:jouet:)` · `WoopSticker.pour(_:)` · `AssetsVideo.chauffer()` (+ le fichier joué, − `home-fond-loop`) | `-calLab`, `-exosLab`, `-thisWeek`, `-coffre2` | build vert ; **non-régression MESURÉE** : la page calendrier, la page exo, la home `-thisWeek` et le coffre se capturent avant/après — diff sur les VALEURS (le diff pixel est inutilisable sur du film qui tourne, preuve du 29-08) |
| **P1 — la page nue** | `ProgressPage` : card vidéo (§3 A) + header + rien d'autre | `-progressLab` (page seule, sans TabView) · `-progressPill <dy> <dx>` · `-progressPillBas` (option B) | capture A / capture B côte à côte, même build → **son choix** ; luminance sous la zone du calendrier sur les pixels clairs ; `-fps` au repos après `./tools/charge.sh` |
| **P2 — This week + le vide** | l'ardoise en verre, les vraies dates, le variant vide, `jouet: false` | `-progressFaits <k>` · `-progressPrevus <n>` (l'école `-galetChoisit`) · `-progressFlammeSticker` (l'A/B §5.2) | captures n = 3…7 × k = 0…n ; le tranchage des minis mesuré (le commentaire « à mi-corps » `:1270` est périmé, vérificateur §5 pt 5) |
| **P3 — le calendrier** | `CalendrierMois` : capsules, six rangées, ‹ ›, aujourd'hui, bouton ; les vraies séances (`@Query`) | `-progressMois <±n>` · `-demoData` (⚠️ sème une séance OUVERTE qui persiste → uninstall pour le repos) | la card ne change pas de hauteur d'un mois à l'autre (mesuré) ; les ‹ › répondent sous le drag (au doigt) |
| **P4 — l'apparition** | la cascade §4.2 | `-progressAuto` (arrivée en boucle) · `-progressFige <p>` | **filmée** (`simctl io recordVideo`, SIGINT), fouettage au détecteur de flash ; à `arrivee = 1` **aucun `.blur` > 0** (lecture du code + capture nette) ; `-fps` pendant l'arrivée |
| **P5 — les portes** | tap jour / tap mini → story in-tree ; « Voir dans le lecteur » → `MoisIpod` du mois affiché, portail depuis le bouton ; bouton absent à 0 séance | `-progressStory <jour>` · `-progressLecteur` | la story s'ouvre depuis le **rect** tapé (pas la carte 220×282 du filet, `StoryFlow.swift:579-582`) ; retour de l'iPod → la page, pas la home ; `-orphanProbe` ne liste aucun conteneur résiduel |
| **P6 — la levée** | la card **reçoit** `levee` (de `PageCard` si elle est là ; sinon l'`EtatProgress` provisoire, copie exos), la bande hors séance (lune), `busy`, la zone dégagée en séance — **aucun player monté par la page** | `-progressTirage <pt>` (l'école `-exosTirage`) · `-fps -pullAuto` | cadence pendant le tirage (le sim est aveugle aux gels Metal : **téléphone**) ; le geste annulé (arrière-plan en plein drag) rejoint le repos ; rien de SwiftData rendu derrière la page (la loi du rideau) |
| **P7 — le branchement** | `WoopApp.swift:1046` → `ProgressPage(onBack: retourHome)` ; `-homeRoute progress` (`HomeNuit.swift:4088`) au diapason ; l'ancienne `CalendarStickersPage` reste sous `-calLab` (archive vivante, l'école `-coffreV1`) | `-openTab progress` | l'iPod ne s'ouvre plus d'office ; la `SessionSlate` de démo et l'appui long console ne sont plus dans l'onglet de prod |
| **P8 — mesures et fiche** | `docs/screens/progress.md` (rôle · affiche · actions · sorties · états · ce qui ment) ; la capture « calendrier » du site | `./tools/charge.sh` puis `-fps` repos / drag / arrivée ; SondeCadence sur le **téléphone** | non-régression home / exos / coffre mesurée ; ce qui n'a pas pu être vérifié est **dit** |

Les verdicts au doigt (gestes, haptiques, réfraction du verre sur la pill)
restent à Kathryn, sur le téléphone — le simulateur ne pose pas de doigt et
`osascript` est refusé.

---

## §11. LES PIÈGES À NE PAS REPAYER

- **Tout est `private` dans `CalLab.swift`** (`CardMorph :935`, `StickerDayCell
  :1175`, `MoisIpod :2316`, `DemoMonth :4090`, `MoisLaunch :775`, `CalStoryLaunch
  :788`, `CalSlot :904`, `CalGeo :842`) — rien n'est appelable d'un autre
  fichier ; et écrire la page DANS ce fichier de 4 794 lignes, c'est le mur du
  type-checker (skill §1, commit `337a6e3`). → P0, un fichier neuf.
- **Un `Button` sous un `DragGesture` d'ancêtre est annulé à 2 pt** (skill §4).
  Les ‹ › du calendrier le sont aujourd'hui (`:1094` sous `:400`). Remède :
  `contentShape + highPriorityGesture(TapGesture)`, jamais remonter le seuil.
  Et un `simultaneousGesture` de page (la home) laisse vivre les `Button`.
- **Un enfant qui a un geste bat le drag de son parent** (`HomeNuit.swift:
  3009-3020`, `GaletEtape.swift:161-181`) : les minis à `DragGesture(min 0)`
  volaient la porte de la route → `jouet: false`.
- **`.allowsHitTesting` sur un ancêtre éteint toute la descendance**
  (`HomeNuit.swift:3211-3225`) — la cause du « This week mort au doigt ».
- **La card ne MONTE pas, elle se RACCOURCIT** par un masque Animatable ;
  `offset(y: max(tirage, 0))` ne fait RIEN vers le haut (`CoffreV2.swift:2729`) ;
  un `padding`/`frame` animé par image redimensionne l'`AVPlayerLayer` = le lag
  (`ExercisesView.swift:194-208`).
- **Le verre à jeun est un rectangle gris** (`HomeNuit.swift:1365-1372`) : le
  vide se PEINT (fumée 0,20), il n'est pas un verre `.clear` posé sur l'ardoise.
- **Le verre aux bounds vivants devient un blur plat** : la coquille de chaque
  card garde une taille CONSTANTE ; la matérialisation d'un vide est un fondu
  de calques par-dessus (`:1214-1216`).
- **Le blur** : transitoire, rayon à zéro exact, jamais sur le verre au-delà de
  6, jamais sous le doigt, sur l'encre et pas sur la boîte (§4.2). Le `.blur(3)`
  plein écran du théâtre exo a été **retiré le 30-08** : deux passes hors écran
  = gel 60 → 14 img/s, invisible au sim (`ExercisesView.swift:335`).
- **La couche vidéo** : le player naît DANS le representable (`CalLab.swift:801-806`,
  sinon il atterrit au-dessus des frères SwiftUI) ; pose dessous, effacée sur
  `isReadyForDisplay` ; `clipsToBounds + masksToBounds` ; hôte neutre
  `Color.clear` (l'incident des 2,3 pt) ; un seul `compositingGroup()` en
  dernier ; `rate` réécrit seulement au changement (`DepartCine.swift:413-417`).
- **Un cover imbriqué depuis une page à gestes** : le gel `e9521cf` (modal
  orphelin) et le verdict de l'iPod (`:2479-2483`) → la story **in-tree** ;
  l'iPod reste un cover parce qu'il est une page, et on ne le démonte jamais
  pendant une bascule d'onglet.
- **Un état par image sur la vue qui contient tout** (skill §2) : `tirage` n'est
  lu que par des `ViewModifier` et la bande, jamais par le corps ; `stats` et le
  dictionnaire des jours se calculent une fois.
- **La marche de 34 pt** (`HomeNuit.swift:1108-1124`) et **le `GeometryReader` à
  l'endroit** (`ExercisesView.swift:463-467`) — deux pièges de layout, invisibles
  sauf en pixels.
- **`-demoData` sème une séance OUVERTE qui persiste** → uninstall pour
  retrouver le repos ; et la démo ne nourrit la semaine courante que sur les
  jours 0 et 1 (`WoopApp.swift:1755-1760`) → `-progressFaits <k>` pour voir
  quatre faites.
- **Le rect du portail** : `.zero` = le filet (carte 220×282 au centre,
  `StoryFlow.swift:579-582`) — mesurer en `.global` AVANT de poser le launch.
- **Une seule source pour les dates** (`SemaineStrip.jour/mois`, `fr_FR`) : un
  formateur recopié a déjà donné « 26 AUG » à côté de « 26. AOÛT ».
- **Le diff pixel ne prouve rien sur un fond qui tourne** (37 % entre deux
  captures du même build, 29-08) : la non-régression se lit sur les valeurs,
  ou vidéo en pause (`rate: 0` au banc).

---

## §12. LES QUESTIONS — avec ma reco

| # | la question | ma reco |
|---|---|---|
| Q1 | **La pill** : A `story-pilule-droite` à mi-hauteur + le feu (sa maquette, zéro recuit) ou B `Video rouge_liquid` qui **part du bas** (un recuit palindrome) ? | **A d'abord**, B au même banc en une capture ; elle tranche à l'œil (P1). |
| Q2 | **« Story 2 »** : le flux entier de la story v2 (ouverture → butin), ou atterrir directement sur la page Détails ? | **Le flux entier** — c'est la story de fin de séance rejouée pour un jour passé. Si Détails direct : `pageDepart`, deux lignes. |
| Q3 | **La flamme vide** : le contour SF `flame` des galets (ses mots) ou le sticker `sticker-flamme-serree` à 0,16 de la jauge de séries ? | **Le contour SF** ; l'autre en A/B d'une ligne (P2). |
| Q4 | **Le chip `‹` à gauche de « Août 2026 »** dans la maquette : il meurt (deux chevrons-retour sur une page = deux portes), ou il devient **« Aujourd'hui »**, visible seulement quand le mois affiché n'est pas le courant ? | **« Aujourd'hui »** — le retour au mois courant se sent (l'école « le chemin revient à aujourd'hui quand on le lâche », `28e5cb7`). |
| Q5 | **Combien de minis** : `n = max(objectif, faites)` avec un pas qui se resserre (40 à sept), ou plafonner à 5 comme la jauge de séries (`FlammesRow`, cap 5) ? | **`max(objectif, faites)`** — l'objectif est choisi 3→7, la card doit le montrer entier. |
| Q6 | **Le jour d'une séance** : `startedAt` (calendrier, `SemaineStats`) ou `endedAt` (chemin) ? | **`startedAt`**, et une seule fonction que le chemin adopte ensuite. |
| Q7 | **Un mois sans séance** : pas de bouton « Voir dans le lecteur » (la loi du coffre), ou un bouton verrouillé (« la matière sans le bijou », `CoffreV2.swift:1438`) ? | **Pas de bouton** — et la grille dit déjà que le mois est vide. |
| Q8 | **Le sous-titre** de This week : « Your last sessions » (vrai, même avec des vides) ou « 2 of 4 planned » ? | Garder **« Your last sessions »** ; le compte est déjà dans les vides. |

---

## §13. COORDINATION, ET CE QUE CE PLAN NE TOUCHE PAS

**Les WIP d'autres sessions au 30-08** (`git diff HEAD`, HEAD `8e8a0cc`) :
`SessionSlate.swift` (`buildGroupes`), `ExerciseDetailView.swift` (+139, « le
rideau »), `ActiveWorkoutView.swift` (+12), `CalLab.swift` (le « cycle fermé »
de `ManegeVue`, `:2166-2178`), `PlayerSeance.swift` et `OrphanProbe.swift` (non
suivis), `docs/site/index.html` (rebuild v2). **Aucune ligne de ce plan n'y
entre**, sauf `CalLab.swift` pour les dé-privatisations de P0 — des hunks de
**un mot** (`private` retiré) et la chirurgie de `StickerDayCell`, à committer
**par hunk** (`git add -p`), jamais le fichier. `WoopApp.swift` est propre
aujourd'hui ; P7 y change **une ligne** (`:1046`).

**Le partage tranché par Kathryn le 30-08** (transmis par la session player) :
**le PLAYER est à la session *woochoper-ios-30*** — `WorkoutPill.swift`,
`SessionSlate.swift`, `ActiveWorkoutView.swift`/`ActiveWorkoutSheet`, les zones
player d'`ExerciseDetailView` (le rideau) et de `HomeNuit` (la bande révélée,
`tirageGeste`) : **on n'y écrit pas**. Progress, la doc et le backend sont à
nous. Ce plan y frôle : `HomeNuit.swift` **seulement** `MiniCardJour` /
`SemaineStrip` (`:1233-1599`) et le montage `-thisWeek` (`:3005`) ;
`ExosFond.swift` (`GrandeCardExos(video:pose:)` — la card vidéo de la page exo,
pas le player) — signalé à la session player.

**Ce qui bouge** : `Woop/Views/ProgressPage.swift` (neuf), `ChipVerre.swift`
(+`ArriveeFloue`), `ExosFond.swift` (deux paramètres), `HomeNuit.swift`
(`MiniCardJour`, `SemaineStrip`), `CoffreV2.swift` (−`ArriveeFloue`),
`DepartCine.swift` (la liste de `chauffer`), `CalLab.swift` (P0),
`WoopApp.swift:1046` (P7), `docs/screens/progress.md` (P8),
`tools/progress/` (ce plan, ses refs, ses captures).

**Ce que ce plan laisse exprès** : le morph semaine↔mois et le bac des
pochettes (ils vivent sous `-calLab`) ; `CalendarView.swift` et
`ProgressionView.swift` (morts, compilent — à supprimer un jour, pas ici) ; la
lecture serveur qui manque (`SupabaseSync` n'a qu'un `push` — le chantier
« 🟡 local », mémoire) ; le moteur de faits côté app (TOP / ×2 restent des
drapeaux de banc) ; `Goal.hebdo` jamais lu ; la dérive de 2 pt du header du
coffre ; la pastille `b-flow-story2` périmée (à la session du site).

---

*Refs : `tools/progress/refs/` — les planches-contact des vidéos mesurées au
§3. Les mémoires voisines : `woop-calendrier-stickers`, `woop-card-route-home`,
`woop-home-v2-chambre-noire`, `woop-story-v2-ended`, `woop-page-coffre-v2`,
`woop-backend-lecture-manquante`, `woop-story-variants-faits`.*
