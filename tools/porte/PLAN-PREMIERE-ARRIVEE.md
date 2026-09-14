# LA PREMIÈRE ARRIVÉE SUR LA HOME — l'étape qui manque après le film de Nosfy

*13-09-2026, nuit · analyse, RIEN n'est codé · la suite de PLAN-SORTIE-POPUP.md*

## 0. Sa consigne (l'essentiel, dans ses mots)

> « Il manque une étape essentielle pour terminer correctement l'onboarding et accompagner
> l'utilisateur lors de sa première arrivée sur la Home. Très simple, premium, Apple : peu de
> texte, beaucoup de focus visuel, animations douces, arrière-plan assombri ou flouté, **un
> seul élément mis en avant à la fois**. »

Six pièces : **① la Home dans la langue choisie** · **② un premier message personnalisé** («
Hey, Kathryn » + une phrase courte, même forme que la phrase actuelle) · **③ les widgets en vrai
état vide** · **④ le Chapitre 1 = point de départ évident** (le galet pulse, « Commencer ici » /
« Start here » à la place d'« Étape 2 sur 3 », le widget vivant) · **⑤ la pop-up Welcome
existante** avec Nosfy et un seul CTA « Démarrer » / « Start », quand elle entre dans cette
zone la première fois · **⑥ une visite guidée sur la Home** en quatre temps (galets →
progression → profil → pièces), tout le reste en blur noir profond, l'élément actif net avec
un halo très subtil, du texte blanc, très peu de mots, mot par mot ou fondu lent.

Le but : « qu'en quelques secondes l'utilisateur comprenne quatre choses — où commencer, où
suivre sa progression, où retrouver ses récompenses, à quoi servent ses pièces ».

---

## 1. L'état des lieux — ce qui existe, ce qui manque, pièce par pièce

| pièce | ce qui existe aujourd'hui (lu, fichier:ligne) | ce qui manque |
|---|---|---|
| **① la langue** | Le film demande la langue (`reponses.langue`, fr/en) et l'écrit au serveur (`profils.langue`, mesuré). **L'app n'a AUCUN mécanisme de langue** : pas de `.lproj`, pas de `Localizable`, aucune clé locale ; la Home est en anglais en dur (`HomeNuit.salut` : « Hello X, », « you've done N workouts this week. » ; « CHAPITRE n » et « Étape R sur T » en français dans CardRoute — la Home est déjà **bilingue malgré elle**) | une clé locale `woop.langue` posée par le film (et relue depuis `profil()` à l'entrée), et **une couche de textes FR/EN** : pour CE chantier, les textes de la première arrivée (② ④ ⑤ ⑥) ; **« toute la Home en français » est un chantier à part** (voir § 6) |
| **② le premier message** | La phrase de la Home = **quatre fragments clair/sourd/clair/sourd** (`HomeNuit.fragments(faits:prevus:prenom:)` :329), 300 pt de large (`PhraseParams`), ancrée par le haut, alternance sacrée, fin sur un sourd. Le prénom vient du profil (`ProfilServeur.prenomLocal`, cache `woop.prenom`) | **la variante de première arrivée** : mêmes quatre fragments, même place, même verre — « Hey Kathryn, » / « bienvenue dans » / « ta première nuit. » / « On commence. » (EN : « Hey Kathryn, » / « welcome to » / « your first night. » / « Let's begin. ») — tant qu'aucune séance n'est finie ; puis la phrase habituelle |
| **③ les widgets vides** | **Fait pour les chambres** : la loi du vide (`ChambreDonnees.calcule([])`, `.chambreVide`, b-ux-chambre-vide 🟡) et la démo qui ne se sème plus (b-ux-demo-plus-semee 🟢) : zéros et tirets, design intact | **rien à faire pour les chambres** — mais voir ④ : la card ROUTE, elle, ment |
| **④ le Chapitre 1** | `CardRoute` lit `EcranSpec.apercu(lecture)` ; **`DuolinguoPage.swift:341-345` rend la DÉMO** sans `-cheminReel`, ET, même avec, **rend la démo dès qu'aucune séance n'est finie** (`guard let j0 = … else { return demo() }`). Un compte neuf voit « CHAPITRE 2 · Étape 2 sur 3 » d'un chemin qui n'est pas le sien. Le galet actif a déjà une petite lumière qui respire (CardRoute :390-408, la valeur `s`) ; « Étape R sur T » est l'odomètre de `ligneBasse` (:439) | **une lecture VIERGE** du chemin (chapitre 1, étape 1, rien de fait — la première décision du chantier du chemin, pas du mien) ; « **Commencer ici** » / « **Start here** » à la place de l'odomètre tant que rien n'est fait ; le galet du chapitre 1 qui **pulse avec son halo** (une valeur animée `repeatForever`, jamais une horloge) ; le widget « vivant » : un souffle de lumière sur son fond (la lampe de la card), **pas** une vidéo sous verre (la loi) |
| **⑤ la pop-up Welcome** | Elle existe : `RewardPopup(style: .welcome, robe: .video)` — la vidéo de Nosfy en tête, « Welcome back », le bouton **Claim +10** et le lien « Later » (WoopApp :1732-1743). Sa porte : `DepartEtat.shared.welcomeOuverte`, allumée par le serveur (`retour_disponible`, une fois par jour, :100-110). Depuis ce soir elle sait aussi porter **une capsule de verre au libellé libre** (`bouton: .capsule(…)`, PLAN-SORTIE-POPUP § 11) | **la robe « première fois »** : la même card, la vidéo de Nosfy, titre « Bienvenue » / « Welcome », pas de Claim, pas de Later — **une seule capsule « Démarrer » / « Start »** ; sa porte : le **premier tap sur la zone des galets** (voir § 2) ; et **elle prime sur le Welcome Back du jour** (un compte neuf a `retour_disponible` vrai le premier jour : deux pop-ups le même soir, non) |
| **⑥ la visite guidée** | **Le mécanisme existe** sur la page exercices : `VoileTuto` (ExercisesView :2097 — un voile `.ultraThinMaterial` percé de fenêtres `evenOdd`, arrondies 20 pt), `tutoCouche(anchors)` (:1061 — fenêtres lues par `anchorPreference`, **cascade** : le voile tombe puis chaque fenêtre s'ouvre, une horloge `TimelineView` le temps du tuto), le doigt passe par la fenêtre, `DepartEtat.tutoDemande` l'arme depuis « Commencer » (DepartSeance :32). PLAN-COUNTDOWN-TUTO.md l'a déjà analysé : « la mécanique du voile percé » se garde, une fenêtre à la fois | **une `VisiteHome` à la RACINE** (au-dessus de la home ET de la nav : l'onglet Profil est une étape) : quatre fenêtres, une à la fois, quatre textes blancs de sept mots, tap partout = suivant ; les quatre ancres : la card ROUTE (les galets), la première card de progression, l'onglet Profil de `JewelTabBar`, la pastille des pièces de la Home (`ouvrirCoffre`, HomeNuit :3826) |
| **la mémoire** | `woop.onboarding.du` (UserDefaults, posé au verdict Apple) ; `profils.onboarding_termine_at` (serveur, posé par `definir_profil`) ; `profil().seances` (le nombre de séances finies, serveur) | **« la visite est faite »** : une clé locale `woop.visite.faite` ET une date serveur `profils.visite_home_le` (une réinstallation ne rejoue pas la visite ; et c'est une donnée : qui a vu la visite, quand) — la colonne et sa fonction sont à la session back-end |

---

## 2. Le parcours, dans l'ordre — ce qu'elle vit

```
 film de Nosfy → « Entrer » → la cérémonie (braises) → LA HOME, première fois
   │
   ├─ la phrase : Hey Kathryn, / bienvenue dans / ta première nuit. / On commence.
   ├─ les chambres : vides, grises, belles (fait)
   ├─ la card ROUTE : CHAPITRE 1 · « Commencer ici » · le galet 1 pulse — c'est elle qu'on regarde
   │
   └─ TAP sur la card ROUTE (la zone des galets), la première fois
        │
        ├─ la pop-up WELCOME : la vidéo de Nosfy · « Bienvenue » · [ Démarrer ]
        │      (Claim et Later n'existent pas ici ; le Welcome Back du jour se tait)
        │
        └─ « Démarrer » → LA VISITE, sur la Home, quatre temps, tap = suivant :
              1 · les galets       « Commence ici. Suis ton parcours. »
              2 · la progression   « Tes progrès. À ta façon. »
              3 · l'onglet Profil  « Tes Boosters et ta collection. »
              4 · les pièces       « Gagne des pièces. Ouvre des Boosters. »
           → le voile se lève · woop.visite.faite + profils.visite_home_le
           → la card ROUTE redevient une porte normale (le chemin, chapitre 1)
```

EN : « Start here. Follow your path. » · « Your progress. Your way. » · « Your Boosters and your
collection. » · « Earn coins. Open Boosters. »

**Pourquoi la pop-up au tap et pas à l'arrivée :** sa consigne (« lorsque l'utilisateur entre
dans cette zone pour la première fois ») — et parce qu'à l'arrivée il y a déjà la cérémonie,
l'aube de la home, la phrase. Deux mises en scène à la suite se mangent ; le tap est le
geste qu'elle a envie de faire (le galet pulse pour ça), et c'est là que Nosfy revient.

**Le voile de la visite, en Apple :** noir + `.ultraThinMaterial` (le voile percé existant :
« blur noir profond »), la fenêtre nette avec un liseré à 8 % de blanc et un halo doux (pas
de bordure lumineuse), le texte en blanc, Inter 22, **mot par mot** (`MotsFlou`, celui du
film — à rendre interne), posé sous la fenêtre (ou au-dessus quand la fenêtre est basse : la
nav, les pièces en haut). Le voile tombe en 0,6 s, chaque fenêtre s'ouvre en 0,4 s (la cascade
existante), le texte suit. Aucun bouton : un tap n'importe où = le temps suivant ; le dernier
tap lève le voile. La visite ne se rejoue jamais (mais un banc `-visiteHome` la rejoue).

---

## 3. Pièce par pièce — ce qu'il faudra construire

| # | pièce | où | ce qu'on pose | coût |
|---|---|---|---|---|
| P1 | **la langue locale** | `NosfyOnboarding` (fin) · `AppleAuth.entrer` | `woop.langue` posée par le film ; relue depuis `profil().langue` à chaque entrée Apple (le serveur gagne) ; un `Langue.courante` (fr/en) lu par ② ④ ⑤ ⑥ | ½ h |
| P2 | **la phrase de première fois** | `HomeNuit.fragments` | `fragmentsPremiereFois(prenom:langue:)` — quatre fragments, même forme ; choisie tant que `profil().seances == 0` et `woop.onboarding.du` ; mesure : chaque fragment tient dans 300 pt (« bienvenue dans » oui, « ta première nuit. » oui) | 1 h |
| P3 | **le chapitre 1 vierge** | `DuolinguoPage.lecture` · `CardRoute` | ⚠️ **dépendance** : une lecture VIERGE (chapitre 1, étape 1, `faits = []`) quand aucune séance n'est finie — aujourd'hui `demo()`. C'est **la décision du chantier du chemin** (b-ux-demo-plus-semee le dit : « la card ROUTE montre toujours la démo »). Puis : `ligneBasse` → « Commencer ici » / « Start here » quand vierge (une identité de vue de plus, fondu, jamais l'odomètre) ; **le galet 1 pulse** : sa lumière existante (`s`) en `repeatForever` 2,6 s, amplitude ×1,6 ; **le widget vivant** : la lampe du fond de la card respire (valeur animée), pas de vidéo | 1 j (dont ½ chez le chemin) |
| P4 | **Welcome première fois** | `RewardPopup` · WoopApp | une robe `.welcome` + `premiereFois: Bool` : titre « Bienvenue » / « Welcome », sous-titre « Nosfy t'attend. » / « Nosfy is waiting. », **pas de Claim, pas de Later, la capsule « Démarrer » / « Start »** (le `bouton: .capsule` de ce soir) ; porte : `DepartEtat.shared.welcomePremiereFois`, allumée par le premier tap sur la card ROUTE tant que `!woop.visite.faite` ; **elle coupe `welcomeOuverte`** ce jour-là | ½ j |
| P5 | **la visite** | `VisiteHome.swift` (nouveau), à la racine | le voile percé (`VoileTuto` rendu interne, ou copié : il fait 12 lignes), la cascade existante, quatre ancres publiées par `anchorPreference` (`"visite-galets"` CardRoute, `"visite-progression"` la première chambre, `"visite-profil"` JewelTabBar, `"visite-pieces"` la pastille), quatre textes FR/EN, `MotsFlou` ; tap = suivant ; barreau `-visiteHome` (rejoue), `-sansVisite` | 1 j |
| P6 | **la mémoire** | local + serveur | `woop.visite.faite` (à la fin de la visite) ; **serveur : `profils.visite_home_le` + `marquer_visite_home()`** — à la session back-end (sa migration, son contrat), appelée à la fin de la visite ; `profil()` la rend ; une réinstallation ne rejoue pas | ½ j (¼ serveur) |
| P7 | **les captures dans la doc** | `docs/site` | le bandeau « L'onboarding » sur la page Compte : une capture par étape du film (intro, accueil, langue, prénom, but, jours, « Bien. », la fin, la sortie) + les quatre temps de la visite quand elle existera — `captures.py` gagne un groupe `ONBOARDING` (mêmes lois : 300 px, q78, < 70 Ko chacune) | ½ j |

**L'ordre :** P1 → P2 → P4 → P5 (la visite se construit sur des ancres qui existent déjà) → P6
→ P3 quand le chemin rend une lecture vierge (sans elle, « Commencer ici » s'écrirait sur un
chemin de démo — on ne le fait pas) → P7 avec les captures de la visite.

---

## 4. Le back-end — ce qui existe, ce qu'il faut, ce que dit le site

| donnée | où | état |
|---|---|---|
| la langue choisie | `profils.langue` (écrite par `definir_profil`, rendue par `profil()`) | 🟢 mesuré ce soir ; **personne ne la LIT dans l'app** |
| le prénom | `profils.prenom` → `woop.prenom` (la home le lit) | 🟢 |
| l'onboarding fini | `profils.onboarding_termine_at` (l'aiguillage de la porte) | 🟢 écrit, lecture à la porte non mesurée (maquette) |
| le nombre de séances finies | `profil().seances` | 🟢 rendu — c'est LUI qui dit « première fois » côté phrase et chapitre |
| le Welcome Back du jour | `retour_disponible` (M1), `claim_retour_quotidien` | 🟢 — ⚠️ vrai dès le premier jour : à taire le jour de la première arrivée |
| **la visite faite** | `profils.visite_home_le` + `marquer_visite_home()` | ⚪ **n'existe pas** — à la session back-end |
| l'objectif hebdo | `user_prefs.objectif_hebdo` (relayé par `definir_profil`) | 🟢 |

Sur le site (page Compte) : `b-po-premiere-arrivee` (⚪ le chantier), `b-po-langue-home` (⚪
la langue choisie n'est lue par personne), `b-po-route-vierge` (🔴 la card ROUTE montre la démo
à un compte neuf), `b-po-visite-home` (⚪ la visite, avec sa mémoire serveur à créer).

---

## 5. Ce que ça coûte (à mesurer sur son téléphone)

- **Le voile** : un `.ultraThinMaterial` plein écran = un flou de page, le prix connu du tuto
  exercices — il ne vit que le temps de la visite (≈ 20 s), puis il est DÉMONTÉ, pas caché.
  Une seule horloge (la cascade), qui meurt avec lui.
- **Le galet qui pulse** : une valeur animée `repeatForever` sur la lumière existante — pas
  une `TimelineView` (la loi du 05-09 : 3 à 8 × moins cher).
- **Le widget vivant** : la lampe de la card ROUTE en valeur animée ; **jamais une vidéo sous
  le verre** de la card (un verre sur une vidéo ne met rien en cache — mesuré).
- **La pop-up Welcome** : la card reward, déjà mesurée.

---

## 6. Ce que ce chantier NE fait PAS — et pourquoi

- **« Toute la Home en français. »** La Home n'a aucune mécanique de langue : « Hello X, »,
  « you've done N workouts this week. », « Welcome back », « Coins », « This week », les noms
  des chambres, la page Progress, la story, la card reward, les annonces… Tout est en anglais
  en dur (et « CHAPITRE » / « Étape » en français). Rendre la Home bilingue = un chantier de
  localisation (`String(localized:)` + deux catalogues, ~1 à 2 j, et une règle : chaque
  nouveau texte naît dans les deux langues). **Ce plan pose la clé `woop.langue` et rend
  bilingue ce qu'il crée** (la phrase de première fois, « Commencer ici », la pop-up, les quatre
  textes) ; le reste attend le chantier langue — à trancher : avant ou après la première
  arrivée ?
- **La lecture vierge du chemin** (P3) appartient au chantier du chemin : sans elle,
  « Commencer ici » mentirait sur un chemin de démo.
- **Les textes** sont ceux de sa consigne, mot pour mot (les quatre temps, « Commencer ici »),
  avec l'anglais proposé ici ; la loi des mots géants ne s'applique pas (ce ne sont pas des
  mots géants) — mais si un jour l'IA les écrit, ils viendront du serveur, jamais la typo.

---

## 7. Deux questions, pas plus

1. **La pop-up Welcome au premier TAP sur la card ROUTE** (mon choix, § 2) — ou dès l'arrivée
   sur la Home, après la phrase ?
2. **La langue de la Home** : le chantier de localisation complet AVANT la première arrivée
   (la Home serait vraiment en français quand Nosfy l'a promis), ou APRÈS (ce plan d'abord,
   bilingue sur ce qu'il crée) ?

---

## 8. Les captures de l'onboarding dans la documentation (P7, la partie qu'on peut faire tout de suite)

Le film existe : ses étapes se capturent au simulateur (`-nosfy -nosfyAuto -rewardAuto`, une
capture par plan : intro à 3 s et 14 s, accueil, langue, prénom, but, jours, « Bien. », la fin,
la sortie) et entrent dans `docs/site/public/captures/onboarding/` par `captures.py` (groupe
`ONBOARDING`, 300 px, q78, < 70 Ko), rendues par un bandeau « L'onboarding » sur la page
Compte — la même robe que « Le flow ». Les quatre temps de la visite s'y ajouteront quand
elle existera (cadres « à capturer » d'ici là).

---

## 9. LA MÉCANIQUE DE LANGUE — le contrat (13-09, nuit : « fais déjà dans la documentation la mécanique de langue »)

**Sa réponse à la question 1 :** la pop-up Welcome arrive **3 s après l'arrivée sur la Home**,
pas au tap. **Sa réponse à la question 2, implicite :** la langue se documente maintenant, et
**la session back-end la gère** (« notifie au backend de gérer ça »).

### Une seule vérité, trois étages

| étage | quoi | qui |
|---|---|---|
| **le serveur** | `profils.langue` (« fr » / « en ») — écrite par `definir_profil` à la fin du film (fait, mesuré), **modifiable plus tard** par le même appel (`definir_profil(p_langue:)`, la page Profil), rendue par `profil()` et `home()`. **Tout texte que le serveur écrit pour la personne** (phrases générées, annonces, stories, mots géants) **naît dans cette langue** — le serveur lit `profils.langue`, l'app ne traduit jamais un texte serveur | back-end |
| **le cache** | `woop.langue` (UserDefaults) : posé par le film à la fin (avant même que le serveur réponde), **rafraîchi depuis `home().langue` à chaque apparition de la Home** (le serveur gagne, comme `woop.prenom`) ; à froid, sans rien : la langue de l'appareil (`Locale`) | app |
| **les textes de l'app** | `Langue.courante` (fr / en) lu par **un seul helper**, celui que le film utilise déjà : `L("texte français", "english text")` (NosfyOnboarding.swift). **Pas de catalogues `.strings`** : chaque texte vit à côté de son écran, dans les deux langues, et la règle de la maison devient : **un texte ne naît jamais dans une seule langue** | app |

### Ce que ça change, écran par écran (l'inventaire, à faire par passes)

| passe | textes | coût |
|---|---|---|
| 0 · le socle | `Langue.courante`, `woop.langue`, `L()` sorti du film et rendu commun, le rafraîchissement depuis `home()` | ½ h |
| 1 · la première arrivée | la phrase « Hey, Kathryn », « Commencer ici », la pop-up Welcome première fois, les quatre temps de la visite | dans le chantier |
| 2 · la Home | la phrase (`salut` / `alors` / `fragments…`), « This week », les titres des chambres, « CHAPITRE » / « Étape », les pastilles, le Welcome Back (« Welcome back », « Your next session… », « Claim », « Later ») | ½ j |
| 3 · le reste | Progress, la story, les cards reward (« YOU MADE IT », « Coins »), les annonces, le player, la page exos, le profil (« Se déconnecter », « Supprimer mon compte », CGU) | 1 j |
| 4 · le réglage | la page Profil : changer de langue (→ `definir_profil(p_langue:)`, puis la Home se relit) | ½ h |

**La loi des mots géants** (b-st-mots-geants) reste : les MOTS viennent du serveur dans la
langue de la personne, la typo reste à l'app.

### Ce qui est demandé à la session back-end

- `home()` rend `langue` (si ce n'est pas déjà le cas) — la Home s'en sert pour son cache ;
- **tout texte généré ou servi** (phrases de la Home, annonces, stories, mots géants) est
  produit **dans `profils.langue`** ; un compte sans langue = « fr » (le défaut du film) ;
- `definir_profil(p_langue:)` reste la porte pour changer de langue (déjà mesurée : un
  complément sans prénom garde le reste).

Sur le site : `b-po-langue-home` porte ce contrat (⚪ tant que le socle n'est pas posé).

---

## 10. État (13-09, nuit — après « vas-y pour la robe première fois »)

**Le serveur est là** (session back-end, mesuré) : `home()` rend `premiere_fois`, `visite_home`,
`langue` ; `marquer_visite_home()` ; `retour_disponible` faux sans séance (S4).

**Posé côté app, non commité :**
- **le socle de la langue** (§ 9) : `Woop/Services/Langue.swift` — `Langue.courante`, le cache
  `woop.langue` (posé par le film dans `ecrireProfil`, rafraîchi par `ProfilServeur.accueil()`
  depuis `home().langue`), le helper `L("fr", "en")` ;
- `ProfilServeur.Accueil` lit `premiere_fois` / `visite_home` / `langue` ; `dernierAccueil` ;
  `marquerVisiteHome()` ;
- **la robe « première fois »** : `RewardPopup(style: .welcome, robe: .video, videoNom:
  "welcome-nosfy-premiere", title: Bienvenue / Welcome, subtitle: « Laisse Nosfy te faire
  visiter. » / « Let Nosfy show you around. », bouton: .capsule(Démarrer / Start), tete: 0.40)`
  — le Claim se cache quand la card porte son bouton (RewardCard) ; **`tete`** (13-09, verdict
  « plus petit la vidéo de Nosfy fondue, un titre et un sous-titre qui invitent au tutoriel ») :
  la part de la card que prend la vidéo de tête, 0,40 ici contre 0,56 pour le Welcome Back
  (qui ne bouge pas : `nil` = la robe telle quelle) ; le titre suit dans le fondu ; tout en
  Inter (aucune autre police) ; la vidéo `~/Downloads/welcome_nosfy_onbaordin.mp4`
  cuite par `tools/porte/recuit_welcome.sh` (4:3 centre, 1200 × 900, ping-pong 14 s, muette,
  2,6 Mo → `Woop/Media/welcome-nosfy-premiere.mp4`) ;
- **sa porte** (`PremiereArrivee.ouvrirWelcomeSiDue`, une `.task` à la racine) : **3 s après
  la Home** (sa réponse), si `home().premiere_fois && !visite_home`, une fois par appareil
  (`woop.welcome.premiere.vue`), jamais sur un manège ou un panneau ; `DepartEtat.
  welcomePremiereOuverte` ; banc `-welcomePremiere` (+ `-skipAuth`).

**Posé ensuite (14-09, nuit — « lance le reste ») :**
- **P2** `PhraseTexte.fragmentsPremiereFois` : « Hey Kathryn, / bienvenue. / Première séance /
  commence ici. » (EN « Hey Kathryn, / welcome. / First workout / starts here. ») — choisie
  par `fragmentsPhrase()` tant que `PremiereArrivee.premiereFois` (le cache
  `woop.premiere_fois`, posé à vrai par le film, rafraîchi par `accueil()` depuis
  `home().premiere_fois` — la première Home est déjà la bonne, sans attendre le réseau) ;
- **P3** la lecture VIERGE côté card : `majLectureChemin()` rend `Lecture(etape: 0)` tant que
  première fois (la dérivation du chemin ne change pas) ; `CardRoute.vierge` → « Commencer
  ici » / « Start here » (identité de vue, fondu) et `HaloVierge` sous le galet 1 (valeur
  animée `repeatForever` dans une feuille, jamais une horloge) ;
- **la pop-up** en DEUX robes (`PremiereArrivee.PopRobe`) : `.welcomeGalet` (posée : Nosfy
  s'éloigne sur le chemin de galets, `welcome-galet-premiere` cuite par `recuit_galet.sh` —
  coupée à 7 s avant le fondu de la source, gel 1,8 s sur le galet, fondu d'entrée/sortie,
  16:9 1280 × 720, boucle par le noir) et `.welcomeEntree` (« Pop-robe variant welcome
  entrée », Nosfy de face — gardée sur son ordre), 20 pt de noir au-dessus de la vidéo, le
  bloc de texte rabaissé sous elle, sous-titre SPORT « Laisse Nosfy te guider : / séances,
  progrès, récompenses. » ; « Démarrer » ferme ET ouvre la visite ;
- **P5** la visite v1 (`VisiteHome.swift`, § 1 de PLAN-VISITE-PREMIUM.md) ; **P6**
  `PremiereArrivee.finirVisite()` : `woop.visite.faite` + `marquer_visite_home()` ; **P7**
  les captures onb-11…14 dans la doc.

**Ses verdicts du 14-09 sur la visite :** « il faut pouvoir skip ou passer en dessous, plus
d'effet Apple, pas assez premium, refais un plan » → **PLAN-VISITE-PREMIUM.md** ; puis « fais-le,
micro-détails et micro-animations comme Apple », « la musique est triste », « hardcore UI, plus
de noir, de fondu, de blur » → **la v2 est CODÉE sur ce plan** (VisiteHome.swift : la page
recule, le voile à cinq couches, la fenêtre à la forme de l'objet, la carte de verre, Passer,
la traversée, tic + paillette). La v1 est remplacée. Et ses deux mots : « Commence ton
entraînement » dans le widget (CardRoute, 15 pt sur deux lignes) ; la phrase « Hey Margaux, / ta
première séance / t'attend. / On y va. » (« le reste ne voulait rien dire »).

**Sa note du 14-09 (matin) :** « dans la Home à l'état vide tu as oublié le user name après
Hey ». Le prénom ne doit JAMAIS manquer : les mots du serveur (`home().phrases`) le portent
dans le premier fragment ; si le serveur salue sans prénom (« Salut, », « Hello there, »),
`PhraseTexte.serveur` remet celui que le téléphone connaît (`woop.prenom`) ; le repli local
lit aussi ce cache ; et au banc (`-welcomePremiere`, `-visiteHome`), sans aucun prénom
connu, « Kathryn » (`PremiereArrivee.prenomBanc`).

**Non mesuré sur un vrai compte** (la session back-end propose un compte jetable — il faut un
banc `-sessionBanc <email> <mdp>`) : la pop-up sur `premiere_fois`, l'appel
`marquer_visite_home()`, les mots du serveur dans la phrase. Le téléphone n'a pas reçu ce dernier build (injoignable : « Ensure the
device is unlocked and attached with a cable ») — il porte la pop-up Nosfy d'avant la robe galet.
