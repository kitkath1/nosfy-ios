# PASSATION — 17-09-2026 · Stories, toaster, chauffe et liaison Supabase

## Plan et verdict actuels — reprise du17-09

**Cette section remplace les consignes de reprise historiques ci-dessous.**
Dernier arbitrage de Kathryn : finir le périmètre initial et l’afficher dans les
cartes en verre de <http://localhost:3111>. **Forge, Compte / Sign in with Apple
et vraie Live Activity passent à plus tard.** La pilule s’étire depuis l’île
à l’intérieur de Woop. Aucun commit demandé.

| Étape | Travail et preuve | Verdict de cette session |
|---|---|---|
| 1. Stories | Géométrie du zoom corrigée, arrêt du capteur et des moteurs hors écran ; iPhone69, trois parcours complets puis180s de récupération, PASS393,377s ; interruption PASS19,309s | Parcours et arrêt des moteurs validés ; ligne verte dédiée |
| 2. Toaster | Hôte commun, capsule noire au sommet, pièces → sachet → disparition ; iPhone69 PASS22,219s, captures relues ; morph filmé au simulateur | Position et file validées ; ressenti haptique **pas encore vérifié**, réponse de Kathryn le17-09 |
| 3. Coffre / annonces / stories et Supabase | Vrai client Swift : renouvellement concurrent, décodage coffre et règles ; faits de clôture mesurés et liaison à la story relue ; session conservée et navigation sur iPhone PASS20,692s | Vérifications acquises ; ne valent pas une première séance complète de nouvel utilisateur dans l’interface |
| 4. Chauffe durable | Thermique0 → 1 avant les stories avec câble et charge, puis1 en récupération ; aucun gel sur69 | **Contrôle sans câble en attente à la demande de Kathryn** (« Garde ce contrôle en attente »,17-09) ; ne pas le relancer automatiquement |
| 5. Documentation | Plan visible dans Test QA et lié depuis État ; détails des cartes calculés depuis les mêmes lignes ; artefact puis vérificateur et captures | La carte affiche « Tout est bon » uniquement quand toutes ses lignes le sont |

Vérification finale : artefact régénéré, contrôle complet **PASS43s** ;
localhost relu dans Chrome, liens du plan testés et captures bureau/mobile
regardées. Coffre11/11 ; Stories6/7 ; Annonces4/5.

Le coffre garde sa carte verte. Stories et Annonces montrent les points acquis
en vert et leur contrôle restant en clair ; leur carte complète attend cette
dernière validation. Le statut de chauffe n’est pas effacé pour rendre la carte
verte. Les chantiers reportés ne sont pas repris pour clôturer ce périmètre.

Rapport et preuves :
`tools/perf/campagnes/2026-09-17-story-session-ile/etat.md`.
Version69 déjà installée ; dernière restitution normale confirmée à17:08:03,
uniquement `-sansSondeVol`. Aucun nouveau build nécessaire pour ces mises à jour
documentaires. Pas de nouveau test téléphone après la mise en attente demandée.

**Reprise ultérieure de Forge uniquement :** audit interrompu avant tout correctif
SQL ; risque constaté dans `forge-card` : scellement du sachet et insertion dans
la collection en deux écritures, avec retour anticipé au rejeu. À reproduire et
traiter dans la session Forge ; aucune nouvelle migration créée ici.

---

## Passation historique, avant les correctifs et validations ci-dessus

Prompt de reprise pour une autre session. **Lire d'abord le site de vérité local
<http://localhost:3111>** (règle absolue CLAUDE.md), puis ce fichier.

> ⚠️ Kathryn est excédée par la lenteur et par les commits qui emportent le
> travail d'autres sessions. **Ne jamais faire un `git commit` nu** : hunk-stager
> par chemins, ne commiter QUE ses propres enregistrements. **Ne commiter que sur
> ordre explicite.** Auteur = `kathryndsvergne`, **aucun trailer** Claude /
> Co-Authored-By / 🤖. Mesurer avant de peindre une pastille (un état se vérifie,
> il ne se déduit pas). Aller au bout d'UN sujet avant d'en ouvrir un autre.

---

## 0. Ce qui est déjà commité par CETTE session (propre, vérifié)

- **b063cd9** — Story branchée : `EconomieWoop.dernierFaits` + `WoopApp.sessionAvecFaits`
  (la story de fin lit les faits du serveur → robe TOP muscu/cardio, ×2) ; la muscu
  attend `clotureRepondue` comme le cardio ; doc Histoire au vert + catalogue des
  variants. Hunk-stagé (uniquement les enregistrements story dans briques.ts, etc.).
- **f71bcb0** — WIP toaster « depuis l'île » (Annonces.swift seul). **Pas fini** (cf. §1).

Rien d'autres sessions n'a été emporté (vérifié `git show --stat`). Périmètres en cours :
**7c** = forge/compte (ForgeServeur, AppleAuth, Supabase, SupabaseSync, forge-card,
migrations forge/profil/compte, briques b-fo/b-dg/b-po + serveur.ts) ; **41** = fiche
exercice (ExerciseDetailView, ChargeFiche, CardioFiche, ChambreHiit, LaunchPebble).
**Ne pas toucher leurs fichiers.**

⚠️ `docs/site/index.html` (le livrable unique) n'est **pas** régénéré : il embarque le
source de TOUTES les sessions. Convention retenue avec 7c : on commite chacun sa SOURCE
par chemins ; le livrable est régénéré+commité **en dernier, par une seule session**,
une fois toutes les sources posées. Kathryn a tranché : **toute la doc reste sur le site
local 3111**, pas de republication en ligne pour l'instant (ne PAS reparler du « 2 Mo »).

---

## 1. TOASTER « DEPUIS LE DYNAMIC ISLAND » — le vrai sujet front, à FINIR

**Demande de Kathryn (répétée, ferme)** : « je veux que les toaster viennent du display
island comme une vraie notif Apple ». Aujourd'hui (avant cette session) ils glissaient du
bord haut et se posaient sous l'île.

**Fait (WIP f71bcb0, `Woop/Services/Annonces.swift`, `PileAnnoncesHote`)** : une transition
`sortieDeLIle` — le toaster naît à l'échelle 0,30 ancrée en haut, remonté à la place de
l'île, et grandit vers le bas (scale + offset, pas de re-layout). Banc `-pileTest` (joue
pièces → sachet sur la home). C'est le VRAI hôte : tous les toasters (clôture, Welcome
Back, cardio, sachet) en héritent.

**⚠️ CE QUI NE VA PAS (verdict Kathryn 17-09, à corriger) :**
1. **Le toaster est encore TROP BAS** — il doit se poser **tout en haut**, collé sous l'île
   (aujourd'hui `degagementHaut = safeAreaTop + 6` ; viser plus haut / repositionner).
2. **Il ne « sort » pas assez de l'île** — cible = la vraie notif Apple : la **pilule
   noire de l'île qui s'ÉTIRE** en dalle (morph type `matchedGeometryEffect`), pas une
   petite dalle qui grandit. Réutiliser la grammaire de `PiluleVagabonde` (elle morphe
   déjà la pastille de séance DEPUIS l'île — `dansIle`, `matchedGeometryEffect id
   "pilule-vol"`, ressorts) et son `CarillonIle`.
3. **HAPTIQUE manquante** à l'apparition (Kathryn : « + haptique »). Voir `CarillonIle.entree()`
   dans PiluleVagabonde (CoreHaptics) — le rejouer quand le toaster sort de l'île.

**Loi perf** : scale/offset/opacity/clip seulement, jamais un cadre animé qui re-layoute
(commentaire d'`EntreeNotif`). Charger le skill **woop-performance** avant d'animer.

**Comment montrer** : build device (l'arbre réel compile — le faux mur n'a pas mordu au
17-09), install sur **iPhone de Frédéric** (`022244AD-484B-5489-A884-6B781A82E372`,
iPhone 15), `devicectl … process launch --terminate-existing … fr.kathryn.woop -- -pileTest
-skipAuth`. Kathryn veut le voir **sur le vrai téléphone branché**, pas au sim.

---

## 2. DOC 3111 — l'état vérifié (mesuré au curl + capture le 17-09)

**Le site local 3111 EST à jour** (serveur `fr.kathryn.woop.doc` restarté). Vue « État » :

| card | état | note |
|---|---|---|
| **Le coffre** | 🟢 TOUT BON (11/11) | |
| **Les annonces** | 🟢 TOUT BON (3/3) | la card EST présente — si Kathryn ne la voit pas, c'est le **cache navigateur** (Cmd+Shift+R) |
| **Stories** | 🟢 TOUT BON (5/5) | branché cette session (b063cd9) |
| **Widgets** | 🟠 EN CHANTIER (31/35) | cf. ci-dessous |
| Flow | 2 à trancher | mesures chemin (sticker, « un nœud = un jour/séance », « fait/parfait ») |
| Forge / Compte | 2 / 1 à valider | périmètre 7c |
| Serveur | 58/59 branchées | |

**Widgets — pourquoi pas vert (à trancher avec Kathryn)** : 3 bloquants, tous NON-story :
- `m-foyer-chauffe-longue` — la home noire optimisée + commitée (session perf, cf9ffb6),
  mais **la chauffe durable n'est PAS confirmée** (endurance interrompue — écrit noir sur
  blanc dans `tools/perf/campagnes/2026-09-16-retours-et-profil/etat.md`) ;
- `m-home-voix-fr-en` — mots animés OK, mais **haptique non confirmée par l'utilisateur** ;
- `b-edge-home-textes` — edge éditorial admin, **le téléphone ne l'appelle jamais** (🔵 par
  choix ; la home lit la TABLE `home_textes_lots`, elle 🟢). Candidat à `reference: true`.

👉 Kathryn pense widgets « terminé et testé ». Le site dit 2 mesures **device** en attente.
Soit on **mesure sur son iPhone** (endurance chauffe sans interruption + elle confirme
l'haptique) → les 2 passent au vert ; soit elle valide au doigt et on peint avec SON
verdict. **Ne pas peindre vert sans l'un des deux.**

---

## 3. LES TROIS GROS BLOCS BACKEND — « ready to go » pour de VRAIS comptes

Objectif Kathryn : **coffre + annonces + story au vert et prêts pour de vrais users qui
créent des comptes.** État vérifié :

- **Coffre** 🟢 — solde dérivé du `coin_ledger`, prix en `reward_rules`, conversion
  100 pièces→sachet, idempotence par index. Mesuré (verif scripts). Card verte.
- **Annonces** 🟢 — `regles_annonces()` lues du serveur par l'app EN DIRECT (vu au
  journal `[annonces]` sur device : rangs/budget/pool) ; Welcome Back +10 crédité,
  idempotent, mesuré. Card verte.
- **Story** 🟢 — `cloturer_seance` rend `faits` (verif_faits.py **14 ✓** sur compte propre,
  17-09) ; l'app les lit et ouvre la bonne robe (b063cd9). Card verte.

**Ce qui reste pour de VRAIS comptes (le vrai « ready to go »)** — c'est le domaine
**COMPTE/PORTE**, périmètre **7c** :
- chaîne nouvel user → user existant (Apple Sign-In, `definir_profil`, langue) ;
- `Compte.swift` (WIP 7c) dépend de méthodes non commitées (`oublier()` sur EconomieWoop/
  ChambreEtat/SupabaseSession, `SupabaseSync.pousser/cleDepuis`) → **HEAD ne compile pas
  seul** sans ce WIP ; à sceller par 7c ;
- « à valider » côté Compte : `b-po-jeton-une-heure`, refresh token Apple, révocations.
- Vérifier de bout en bout sur le **compte de test** (`kat44426+woop-forge-test@gmail.com`)
  ET sur une **vraie création de compte** : premier lancement → onboarding Nosfy → profil
  posé → coffre/annonces/story fonctionnent avec les vrais soldes serveur (pas la maquette).

⚠️ Un téléphone neuf repart vide devant un serveur plein pour le **calendrier / l'étape du
chemin** (dérivés de SwiftData) — la story, elle, ne dérive plus (elle lit la clôture).
Audit : `tools/road/AUDIT-CHEMIN-CALENDRIER-STORIES.md`.

---

## 4. CHAUFFE & CONNEXION SUPABASE — les deux garde-fous à tenir

- **Chauffe** : skill **woop-performance** OBLIGATOIRE avant toute mesure/animation. La
  home noire est optimisée (−85 % CPU mesuré, cf9ffb6) mais **l'endurance longue reste
  ouverte** (thermique à confirmer sur SON iPhone, froid au départ, sans câble). Toute
  nouvelle animation (dont le toaster §1) arrive avec son barreau `-sansXxx` et se mesure
  sur le téléphone, jamais au sim. Registre : `tools/perf/ECHECS-CHAUFFE-HOME.md`.
- **Connexion serveur / tables Supabase** : projet `ytnnyjkramgiqyxdrkcu`. Vérifier que
  chaque écriture d'argent est idempotente (index unique partiel + `unique_violation`),
  que les soldes se DÉRIVENT (`sum(delta)` sur `coin_ledger`, jamais une colonne balance),
  que les prix vivent en `reward_rules` (pas de constante Swift qui double). L'outbox
  (`OutboxGains`) ne rejoue que parce que le serveur est idempotent. Migrations par la CLI,
  jamais le MCP. Skill **woop-backend**. Table par table : `serveur.ts` (carte du serveur,
  58/59 branchées) est la référence — la garder exhaustive et mesurée.

---

## 5. Premiers gestes conseillés pour la session qui reprend

1. Lire 3111 (coffre/annonces/story verts, widgets en chantier) + `serveur.ts`.
2. **Toaster** (§1) : reprendre f71bcb0 → morph pilule-qui-s'étire depuis l'île + tout en
   haut + haptique, montrer sur l'iPhone de Frédéric, itérer avec Kathryn (elle juge en
   mouvement, boucle courte).
3. **Widgets** (§2) : trancher les 2 mesures device avec Kathryn (mesurer ou valider).
4. **Ready for real users** (§3) : se coordonner avec 7c (compte/forge) — c'est là qu'est
   le vrai reste pour de vrais comptes.
5. Ne rien commiter sans ordre ; hunk-stager ; régénérer `index.html` en dernier.
