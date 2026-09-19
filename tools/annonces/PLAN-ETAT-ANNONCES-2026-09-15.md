# État des lieux — LES ANNONCES (pop-ups, toasters, événements)

**15-09-2026.** Demandé par Kathryn : « on attaque les annonces… fais un plan sur l'état
des lieux qui manque pour les tests, back-end selon la documentation ET le front que ça
marche bien aussi ».

**Sources de cet état** : lecture du site de doc (page *Annonces* : `b-rg-rythme`,
`b-wb-porte`, `b-rg-le-versement` ; page *Flow* : `b-flow-deux-annonces`, `b-flow-overlay`,
`b-flow-story2`, `b-flow-coffre-parcours`), et survol du front (RestartSheet, PlayerSeance,
ExerciseDetailView, Annonces.swift, NotifCard/NotifChasse, DuolinguoPage). Rien codé.

Deux familles, comme elle les a posées :
1. **Pendant les exercices** — le gain (toaster de pièces) et les pop-ups en séance.
2. **Les autres événements** — booster, « Nosfy has something for you », Welcome Back.
Plus deux sujets transversaux : **l'overlay flamme → pop-up**, et **la langue FR/EN**.

---

## §0 — CE QUI MARCHE DÉJÀ (testable tel quel)

| Brique | État | Où |
|---|---|---|
| Le **rythme** des pop-ups (QUAND : rangs 3/5/10 puis tirage 5-8, budget 4/1/1, écart 3 séries ET 6 min) — lu du serveur, appliqué | 🟢 | `regles_annonces()` → `DecideurSerie` (RestartSheet:612-798) |
| **Welcome Back — la PORTE** (quand la montrer, jamais sous l'onboarding/splash, jamais le 1er jour, serveur `retour_disponible`) | 🟢 | `Compte.proposerWelcomeBack()` (Compte.swift:206) |
| La **clôture** qui paie (muscu + cardio) et rend pièces/sachet/argent/faits | 🟢 | `cloturer_seance` (6014fff) |

→ Le *cerveau* des annonces (quand, combien, quelle règle) est en place et mesuré. Ce qui
manque, c'est surtout **le corps visible** : les bonnes robes, aux bons endroits, dans la
bonne langue, et effectivement VUES à l'écran.

---

## §1 — PENDANT LES EXERCICES

### 1a. Le toaster de pièces gagnées — LE POLI N'EST PAS BRANCHÉ 🔴 (ce qu'elle voit)
- Ce qui s'affiche AUJOURD'HUI : `PillGain` (rudimentaire, RestartSheet.swift:536) appelé en
  séance par `ExerciseDetailView.swift:1243` ; `PiecesNotif` (PlayerSeance.swift:260) sur la
  home / le chemin. **C'est le « rudimentaire » qu'elle décrit.**
- Le toaster POLI qu'on a travaillé (`NotifCard.swift` + `NotifChasse.swift` : jauge / gros
  texte / châsse Nosfy, gabarit OPAL 138 pt) **vit UNIQUEMENT au banc `-notifLab`** — jamais
  commité, jamais branché dans la vraie chaîne.
- Manque aussi la **4e robe = booster** (jauge avec un sachet détouré `booster-orange` qui
  bouge à la place de la pièce) : tranchée le 29-08, **jamais codée**.
- **À faire** : brancher `NotifCard` à la place de `PillGain` (séance) et `PiecesNotif`
  (home) ; coder la 4e robe booster ; les robes VARIENT (aucune clouée à un moment — sa
  règle). Front. Plans existants : `tools/notifs/PLAN-NOTIFS-V8/V9.md`, fiche
  `docs/screens/notification.md`.

### 1b. Les pop-ups EN séance — le décideur décide, mais l'UI est une pill, pas une pop-up 🟡
- `b-rg-rythme` (doc) : « NON appliqués : le plafond des dalles (**la pill n'est pas une
  pop-up**), les bonus en pièces (J5, l'IA des mots) ». Le décideur choisit QUAND montrer
  quelque chose au rang 3/5/10… mais ce « quelque chose » n'est pas encore une **vraie
  pop-up** (carte plein cadre) — c'est la pill.
- **À faire** : la vraie pop-up en séance (même famille que les pop-ups coffre/reward), dont
  le **contenu texte vient de l'IA** = `narrate-reward` (voir §2d, PAS fait). Front + back.

### 1c. La pile d'annonces après la clôture — codée mais JAMAIS VUE 🔵
- `b-flow-deux-annonces` : `FileAnnonces` (Annonces.swift) empile pièces / sachet / argent /
  +10 ; après la story : [pièces, sachet] puis argent/sachets convertis. **« La pile n'a pas
  encore été vue à l'écran (il faut une clôture au sim). »**
- **À faire** : la faire tourner sur une vraie clôture au simulateur (compte de test) et la
  regarder — c'est un test, pas du code (sauf bug trouvé). Front.

---

## §2 — LES AUTRES ÉVÉNEMENTS

### 2a. Le booster (« Ouvrir », le manège) 🟡
- `b-flow-overlay` : la pop-up booster est un overlay monté sur la home à +3,4 s après la
  story (8e8a0cc). `b-flow-coffre-parcours` ⚪ : le coffre n'est pas dans le parcours, la
  pop-up part directement au manège. Codé, à **tester/mesurer** au sim.

### 2b. « Nosfy has something for you » 🟡 — ANGLAIS SEUL
- Existe : `DuolinguoPage.swift:1371` (`titre: e.special ? "Nosfy has something for you"`) —
  sur les nœuds spéciaux du chemin. **Texte anglais en dur.** → voir §4 (langue).

### 2c. Welcome Back — la porte 🟢, le versement 🔵, le TEXTE anglais seul 🔴 langue
- Porte OK (§0). Le Claim (+10 au tap, minuit Paris) : **codé, tap jamais mesuré**
  (`b-rg-le-versement` 🔵 ; le jour du compte de test était pris — à mesurer après minuit).
- Sa dalle parle **anglais seul** : « Your next session is waiting for you » — un texte de
  l'app. Kathryn : le **texte généré du Welcome Back reste TOUJOURS en français** ; le reste
  suit la langue de l'onboarding (§4).

### 2d. narrate-reward — l'IA qui écrit les MOTS des pop-ups 🔴 PAS FAIT (J5 du plan)
- C'est le chaînon qui donne aux pop-ups en séance (§1b) et à la prochaine annonce leur
  phrase (les mots viennent de l'IA, les chiffres des faits). **Jamais écrit** (edge
  function). Back (à moi). Doit sortir dans la **langue de l'onboarding** (§4), gros texte
  « YOU WIN » excepté (reste EN).

---

## §3 — L'OVERLAY FLAMME « CONTINUER UNE SÉRIE » → POP-UP (sa demande)
- Aujourd'hui : un overlay vidéo `flamme_overlay` (RestartSheet.swift:379, `.overlay`).
- **À faire** (front) : le transformer en **pop-up de la même taille que les pop-ups**, et
  **ajouter cette robe comme un variant** de la famille pop-up. (Design à valider par elle.)

---

## §4 — LA LANGUE FR/EN SELON L'ONBOARDING (transversal — back + doc)
- **Règle** (Kathryn) : les textes d'annonce (courants) suivent le choix FR/EN de l'onboarding,
  comme les widgets. Exceptions : **TOUS les GROS TEXTES restent en anglais** (« YOU WIN »,
  « You're on fire », « YOU'RE BACK », « LET'S GO »… — c'est le design) ; et le **bilan généré
  du Welcome Back reste toujours en français**.
- **Mécanique existante** : `L(fr,en)` lit `woop.langue`, posé par l'onboarding
  (`WoopApp.swift:378`) — déjà en place (prouvé sur les widgets). Les textes SERVEUR
  (`narrate-reward`, phrases servies) lisent la langue du profil (`profils.langue`), comme
  `bilan-periode`.
- **À faire** : (1) audit des textes d'annonce en anglais en dur (« Nosfy has something for
  you », « Your next session is waiting », dalles) → passer en `L()` ; (2) `narrate-reward`
  et tout texte servi = langue du profil ; (3) **le documenter dans le site ET le backend**
  (la règle « quelle langue, d'où elle vient » sur les briques annonces).

---

## §5 — ORDRE PROPOSÉ (pour tester vite), et QUI fait quoi

**Kathryn (15-09) : je prends le FRONT ET le BACK** de tout ce chantier annonces. Les fichiers
partagés avec d'autres sessions (perf/Codex, cardio-app, compte) se montent par hunks — ne
jamais emporter leur travail en cours.

1. **Voir la pile d'annonces sur une vraie clôture** (§1c) — test au sim, zéro code : sait-on
   déjà ce qui s'affiche ? (débloque le reste). — *test*
2. **Brancher le toaster poli** `NotifCard` (§1a) à la place de PillGain/PiecesNotif + 4e robe
   booster. — *front*
3. **L'overlay flamme → pop-up** (§3). — *front + design*
4. **narrate-reward** (§2d) : l'edge function qui écrit les mots, dans la langue du profil. —
   *back (moi)*
5. **La vraie pop-up en séance** (§1b) branchée sur narrate-reward. — *front + back*
6. **Langue FR/EN** (§4) : audit + `L()` + textes servis + doc. — *back + doc, un peu de front*
7. **Welcome Back** : mesurer le Claim après minuit + texte FR (§2c). — *test + front*

⚠️ Chaque pas backend met le site à jour DANS le même commit (règle du dépôt). Rien n'est 🟢
sans avoir été VU/mesuré au sim ou au téléphone. Rien de commité sans son ordre.
