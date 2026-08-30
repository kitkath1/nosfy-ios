# Écran — PROGRESS (l'onglet Progrès)

`Woop/Views/ProgressPage.swift` (la page, la card calendrier `CalendrierMois`,
`WoopSticker.pour`, `DemoSession.depuis`) · l'ardoise « This week »
`SemaineStrip` + `MiniCardJour` (`Woop/Views/HomeNuit.swift`) · les briques du
calendrier `CalSlot` / `StickerDayCell` / `JourCase` et l'iPod `MoisIpod` /
`MoisLaunch` / `DemoMonth` / `DemoSession` (`Woop/Views/CalLab.swift`) · la
story `StoryPortal` / `StorySession(workout:)` (`Woop/Views/StoryFlow.swift`).
Plan : `tools/progress/PLAN-PROGRESS-V2.md`.

> **Convention.** Sans marque = **vérifié dans le code ou au banc**. **?** =
> pas sûr, attend une décision ou une mesure. **CIBLE** = décidé, pas encore
> là. Les tables de la base ne sont pas décrites ici.

---

## 1 · Rôle

**Là où l'on atterrit pour regarder en arrière.** Trois questions, dans cet
ordre : *qu'ai-je fait cette semaine* (l'ardoise « This week », avec les
places vides de l'objectif), *quels jours ce mois-ci* (le calendrier, un
sticker par séance), *rejouer une séance* (la story d'un jour) — et une
porte vers le **lecteur** (l'iPod du mois).

Depuis le 30-08 l'onglet **n'atterrit plus sur l'iPod** : l'iPod est une
destination (« Voir dans le lecteur »), plus un atterrissage forcé qui se
rouvrait à chaque retour d'onglet (`CalLab.swift:262`, `ouvreIpod`).

---

## 2 · Affiche

**Une grosse card sur la nuit** — le patron exos (marge de nuit 10 en haut,
coins 55, `FormeCardExos` qui se raccourcit par le bas). Dedans, de bas en
haut :

| couche | quoi | source |
|---|---|---|
| le feu | `home-fond-flamme.mp4`, collé au pied, coupé par le bas | `CalqueVideo`, additif |
| la pill de verre rouge | `story-pilule-droite.mp4` (tête à gauche, corps qui sort à droite), centrée à 0,50 H — **option A, sa maquette, zéro recuit** ; option B au banc (`-progressPillBas`, `progress-pill-bas.mp4`, la pill qui part du bas) | `CalqueVideo`, additif, un seul `compositingGroup` |
| le header | chevron `ChipVerre` + « Progress » Inter-Bold 30, tracking −0,4, `titleFade` — **la robe de « Rewards »** ; cote `RangeeChips` (20 / safeTop + 4) | `ProgressPage.header` |
| « This week. » | l'ardoise de la home (`SemaineStrip`, 354 × 128) en **verre** nourri par la pill ; une mini par jour fait (date + sticker), les places restantes de l'objectif en **VIDE** (plaque à peine là, contour SF `flame` ultraLight — le MODE EMPTY des galets, **sans date**) ; `n = max(objectif, jours faits)`, le pas se resserre à sept | `SemaineStrip(jours:videsVisibles:jouet:false)` |
| le calendrier | `CalendrierMois` 354 × ~477 : titre « Août 2026 » (Inter 20 semibold), « Aujourd'hui » quand le mois affiché n'est pas le courant, ‹ › (transition `push`), sept capsules LUN … DIM (celle du jour allumée + point rouge), **six rangées toujours** (la card ne change pas de taille), les cases `StickerDayCell` (sticker de catégorie + flamme, ×2 si deux séances, aujourd'hui liseré + bague), et le bouton | même ardoise en verre |
| « VOIR DANS LE LECTEUR » | `DiamondPrimaryButton`, 58, à 26 des bords — **absent quand le mois n'a aucune séance** | pied de la card calendrier |

**L'arrivée** : une horloge linéaire de 1,0 s (retard 0,18) ; la card naît en
fondu (1,015 → 1), le titre et l'encre des cards arrivent dans le flou
(`ArriveeFloue`, 9 → 0, **rayon à zéro exact** ensuite), les coquilles de
verre en opacité + 9 pt (jamais de blur sur du verre natif), en cascade de
0,12 s par rang. Filmée : **0 flash en V**.

**En séance** (dérivée de `@Query endedAt == nil`) : la card se **raccourcit
de 96** (6 · 76 · 14, la référence home) et dégage la zone du player — **la
page n'y monte rien** : la dalle est le composant PageCard de la session
player. Mesuré au banc `-progressLevee 96` : arête à 778, 40 pt d'air sous le
calendrier.

---

## 3 · Actions

| # | Action | Geste | Appel backend |
|---|---|---|---|
| A1 | **Revenir à la home** | chevron | aucun |
| A2 | **Changer de mois** | ‹ › (tap en priorité haute — pas des `Button`) | aucun |
| A3 | **Revenir au mois courant** | « Aujourd'hui » | aucun |
| A4 | **Rejouer une séance** | tap d'un jour entraîné (flash 140 ms, puis le portail depuis la case) · tap d'une mini faite | aucun — `StorySession(workout:)` sur la séance locale |
| A5 | **Ouvrir le lecteur** | « Voir dans le lecteur » → `MoisIpod` sur le mois affiché, portail depuis le bouton, le mois précédent pour sa phrase | aucun |
| A6 | **Tirer la card** | **CIBLE** — le geste appartient à PageCard (session player) ; la page reçoit `levee` | aucun |

⚠️ **Aucune action ne touche le réseau.** Tout est lu dans SwiftData.

---

## 4 · Sorties

| Depuis | Vers |
|---|---|
| chevron | la home (`retourHome`, `WoopApp.swift`) |
| un jour / une mini | la **story v2** (ouverture → détails → analyse → butin), **dans l'arbre** (`StoryPortal` en `zIndex(10)` — jamais un `fullScreenCover` depuis une page qu'on drag) ; la pill passe à `rate: 0` |
| « Voir dans le lecteur » | l'iPod (`fullScreenCover`, fond clair) ; retour → la page, pas la home |
| menu de la home → « Progress » | cette page (`destinations`, `HomeNuit.swift`) |

---

## 5 · États

| État | Aujourd'hui |
|---|---|
| **arrivée** | la cascade §2 — une fois ; le retour d'onglet ne la rejoue pas |
| **vide** (aucune séance) | l'ardoise ne montre que des places vides ; la grille sans sticker ; **pas de bouton lecteur** |
| **mois sans séance** | la grille vide, pas de bouton — la bascule ‹ › reste |
| **en séance** | la card raccourcie de 96 ; rien de monté dessous par la page |
| **story ouverte** | in-tree, la pill en pause |
| **chargement / erreur / hors ligne** | n'existent pas — rien n'est réseau |

---

## 6 · Les données, et où l'écran ment

| donnée | source | état |
|---|---|---|
| les séances du mois, de la semaine | `@Query Workout`, séances finies rangées au jour de **`startedAt`** (la définition de `SemaineStats` et de l'ancien `CalendarSection`) | 🟡 **local** — `SupabaseSync` n'a qu'un `push` : à la réinstallation, la page repart vide devant un serveur plein |
| l'objectif hebdo | `@AppStorage(Goal.cleHebdo)`, la clé du galet de la home | 🟡 local |
| le sticker d'une séance | `WoopSticker.pour(_:)` — la catégorie dominante de `Workout.categories` (haut → bras, abdos → chocolat, bas → jambes, fessiers → abricot, cardio → basket ; rien → flamme) | 🟡 dérivé en local — **aucune colonne serveur** (`workouts?select=sticker` → 400) ; la home (`-thisWeek`) et l'ancienne page calendrier (`-calLab`) lisent encore leurs sources d'avant (modulo, hash) |
| le ×2 | `count ≥ 2` séances le même jour | 🟡 local — plus un tirage |
| la story d'un jour | `StorySession(workout:)` — titre, date, minutes, exos, séries, partition | 🟡 local ; les variants TOP / ×2 de la story restent des drapeaux de banc (pas de moteur de faits côté app) |
| le lecteur | `DemoMonth` + `DemoSession.depuis(workout:)` : séries = `seriesPayantes` (les séries FAITES), reps cochées, la story et la partition depuis le `Workout` | 🟡 local ; ⚠️ une séance **cardio** y lit « 0 séries · 0 reps » — l'iPod ne connaît pas encore les minutes (**?** à la session iPod) |

Rien ici n'est une modification backend au sens de `CLAUDE.md` (aucun
`select`, aucune fonction, aucune migration) — les pastilles du site ne
bougent pas. Le jour où la lecture serveur arrive, c'est 🟡 → 🟢 **après appel
réel lu**, même commit, même URL.

---

## 7 · Les bancs

`-progressLab` (la page seule) · `-progressPill <dy> <dx>` · `-progressPillBas`
· `-progressFaits <k>` · `-progressPrevus <n>` · `-progressMois <±n>` ·
`-progressFige <p>` · `-progressStory <jour>` · `-progressLecteur` ·
`-progressLevee <pt>` · `-progressFlammeSticker` (l'A/B de la flamme vide) ·
`-fps`. Scripts : `tools/progress/voir.sh` (build nu, sim dédié
**kat-progress**, `dd-progress`), `tools/progress/filmer.sh`,
`tools/progress/recuit_pill_bas.sh`. Captures dans `tools/progress/shots/`,
films dans `tools/progress/films/`.

---

## 8 · Ce qui n'est pas vérifié

- **Au doigt** (le simulateur n'en pose pas) : le tap d'un jour / d'une mini,
  les ‹ ›, « Aujourd'hui », le bouton, le chevron — prouvés par les drapeaux
  `-progressStory` / `-progressLecteur`, pas par un doigt.
- **La cadence sur le téléphone** (le sim est aveugle aux gels Metal). Au sim,
  même run, machine calme : la home 37 img/s · Progress **15,8 avec le bouton
  diamant** (un `colorEffect` à 30 Hz permanent) · **60,0 avec le bouton
  NOIR** (`BoutonPrimaire`, 30-08 : ni shader ni horloge — `DiamondPrimaryButton`
  n'est plus qu'une coquille dessus, partout). Résolu au sim ; le téléphone
  reste le juge.
- **La réfraction du verre sur la pill** et le rendu OLED du feu.
- La story d'une **mini** part sans rect (le filet de `StoryPortal` : la carte
  centrale), pas depuis la mini — **?** la mini saura le dire.
