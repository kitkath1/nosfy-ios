# NAV V2 — LA NAV FIXE + LA PILULE VAGABONDE (dicté par Kathryn le 04-09)

**État : PLAN DURCI (adversaire Fable passé, 12 failles fusionnées), rien
codé.** Le pivot dicté après l'arrêt du chantier repli : « on remet la
navigation SANS réduction mini dans la partie noire ; pas de background, mais
à son survol l'aspect liquid glass (le composant natif) ; le player devient la
partie VAGABONDE — une grosse pilule noire qu'on peut bouger/drag partout, qui
affiche le player ; attention à la fiche exercice avec le galet blanc ; et
RABAISSE la nav, elle prend trop de place. »

---

## §0 · LE MODÈLE — deux objets, deux vies

1. **LA NAV, FIXE ET TAP-ONLY.** Quatre glyphes + la braise, une seule
   hauteur pour toujours. **Le repli mini est MORT** : plus de drag de bande,
   plus d'états, plus de card qui s'allonge. Pas de fond ; au toucher, un
   verre s'allume sous le glyphe pressé (§2, avec la vérité sur le verre).
2. **LA PILULE VAGABONDE = LE PLAYER en séance.** Une pilule noire FLOTTANTE
   (l'idée d'origine, l'école Live Activity) : draguable partout, tap →
   l'overlay du player. Elle REMPLACE la dalle dockée.
3. ⚠️ **Ce pivot RETIRE la dalle canonique (68,1100,0,76) et son invariant**
   (des heures de verdicts) — dicté par Kathryn le 04-09, assumé ; le
   fouettage ultime du player sera re-matricé (J5).

## §1 · CE QUE LE PIVOT SIMPLIFIE — et ce qui est déjà réglé par construction

- **La guerre iOS meurt** : Reachability = swipe descendant né du bord, Home
  = swipe montant — AUCUN ne vole une touche immobile. Le tap-only est
  imprenable (seule réserve honnête : une touche née dans les tout derniers
  pt du bord peut être livrée avec un léger retard système). Le drag, lui,
  déménage sur la pilule — reprise à ≥16-20 pt des flancs (aimant JAMAIS
  collé au bord : le flanc gauche de la fiche porte le swipe-back du
  NavigationStack).
- **La card retrouve UNE hauteur** : `dockH` constant, plus de layout animé.
- **Croisement des gestes, déjà presque réglé** : le tiroir home est démonté
  en séance (HomeNuit:2862) or la pilule n'existe QUE en séance — zéro
  conflit ; le PanMaitre du player ne reçoit que player OUVERT ; les gestes
  de page perdent contre la pilule tant que le doigt NAÎT sur elle (la vue
  du dessus gagne le hit-test SwiftUI).
- ⚠️ **RÈGLE ARCHITECTURALE ABSOLUE** (la leçon des 2 jours) : le drag de la
  pilule est un **DragGesture SwiftUI SUR la pilule elle-même** — JAMAIS un
  pan en `.background` (affamé), JAMAIS un pan-fenêtre (il verrait tout
  l'écran et exigerait un rect vivant : la machine à bugs qu'on enterre).
- **On jette (J3, liste MESURÉE au grep)** : NavEtat.mini/suivi/enSuivi/r/
  suivre/commettre/poser/basculer/armerChien/volVers + navH variable,
  NavPanHote + sa pose au châssis, NavMini + rampes de NavBande, le grabber
  (trait + tap), le slot dalle + tap dalle de PageCard, WoopApp:1156
  (mini=true au départ de séance), `.animation(value: dockH)`. **UN lot
  compilable d'un bloc**, banc re-matricé dans le même lot.
- **On garde** : `NavEtat.page` + le pont onglets ; **la publication
  `bandeVisiblePubliee`/`bandeEnSeance` de PageCard** (elle devient l'entrée
  du retrait de la pilule — `bandeRectFenetre` peut mourir avec le pan) ;
  **MoteurNav RÉAFFECTÉ** en moteur de vol de la pilule (l'aimantation à
  l'élan en a besoin — on ne jette pas pour réécrire) ; les fixes CHAUFFE ;
  le bouclier racine (WoopApp:1516) ; le banc à vrais touchers (outil
  intact, matrice à refaire) ; toutes les leçons payées.

## §2 · LA NAV RABAISSÉE + LE VERRE AU TOUCHER (la vérité d'abord)

- **Cotes** : rangée ~52 pt (cibles 44 conservées), plus de grabber, bande
  totale **~54-56 pt** (au lieu de 82) — la card regagne ~26-28 pt.
- **« Re-mordre » le bas ou pas = DÉCISION KATHRYN (§6.3)** : le tap étant
  imprenable, la bande PEUT redescendre vers l'esthétique du 01-09 — au prix
  d'un tap possiblement retardé au ras du bord. Quel que soit le choix : le
  `contentShape` des cibles s'arrête AU-DESSUS du plancher physique (le
  dessin peut mordre, la zone tactile jamais).
- ⚠️ **LE VERRE SUR DU NOIR PUR EST QUASI INVISIBLE** (loi payée : « une
  vitre sur du noir uniforme est invisible — le contenu EST le verre »). Le
  banc J2 comparera D'OFFICE trois variantes, annoncé d'avance pour que le
  banc soit une comparaison, pas une déception : ① capsule
  `glassEffect(.clear.interactive())` nue (risque : invisible), ② la même
  AVEC une lueur douce dessous (du contenu à réfracter — l'école validée de
  la molette iPod), ③ la calotte `liquidLens`. Taille FIXE, née en opacité,
  jamais un resize (verre aux bounds vivants = blur plat). `.regular`
  INTERDIT, comme toujours.

## §3 · LA PILULE VAGABONDE — la mécanique exacte

- **UN hôte GLOBAL au châssis**, monté `if enSeance` seulement (le rideau).
  **zIndex entre 5 et 8,5** (au-dessus du panneau départ, SOUS le player
  monde, les annonces (9) et la StopCard (13) — son stop ouvre la StopCard
  par-dessus elle).
- **L'état** : `PiluleEtat` **@Observable** (l'école PlayerEtat/NavEtat) —
  JAMAIS un @State sur le châssis (la page ré-évaluée par image + le mur
  type-checker de mainBody, 337a6e3). Position possédée, écrite SEC au drag,
  lue par LA SEULE vue pilule. **Persistée en RATIO d'écran** (pas en points
  — survit aux tailles d'appareil), par séance.
- **La forme du posé** : la pilule vit en **`.position()` dans un ZStack
  plein écran dédié** (un nœud, taille intrinsèque fixe) ; pendant le suivi
  les pixels suivent le doigt ; **la position COMMISE au relâcher est du
  vrai layout** — jamais un `.offset` résiduel (39f95f9 : les pixels et le
  hit-test sont deux choses).
- **Tap + drag + stop sur le même objet** (topologie vérifiée) : drag =
  `DragGesture(minimumDistance: ~6)` (un min-0 affamerait le tap) ; tap
  ouvrir = `onTapGesture` simple (frère du drag) ; **stop =
  `highPriorityGesture`** (il bat le drag qui l'ENVELOPPE — c'est un
  ancêtre : la bonne topologie). Gardes « pas de tap pendant le vol
  d'aimant » (l'école enVol/enSuivi).
- **Le doigt tenu** : ⚠️ PAS de chien-minuteur (le sachet booster qui se
  refermait SOUS le doigt, payé le 30-08) — la forme juste est
  **`@GestureState` + `.updating`** (SwiftUI le remet à faux LUI-MÊME si le
  geste meurt sans onEnded), puis `onChange(doigtPose)` commet/aimante.
- **L'aimantation** : au relâcher, vol possédé (MoteurNav réaffecté), durée
  = 3·distance/vitesse (la recette payée) ; **butées de POSE** : jamais sous
  la status bar, jamais dans le strip système, **jamais sur la bande nav**
  (butée basse = le HAUT de la bande), et plus généralement **aucune pose
  dans les ~150 pt du bas** (la molette d'Exercices, les sliders — le galet
  n'est qu'un cas du mobilier bas) ; flancs à ≥16-20 pt du bord.
- **Les horloges** : la veine de WorkoutPill est gatée par `\.ongletCache` —
  qui n'existe PAS au châssis : **recâbler** `vivante = pas de drag en cours
  && player pas monté && app active` (sinon la comète repart à 30 Hz
  permanent — la chauffe re-payée).
- **Sous le player ouvert** : hitTesting coupé ET horloges gatées.

## §4 · LES TRANSITIONS DE VIE (les oubliées classiques)

1. **Naissance** : DIFFÉRÉE à la fin de la cinématique de départ
   (conditionnée à l'ÉTAT, jamais un asyncAfter — une vue qui naît pendant
   un film = le trou de 224 ms payé le 26-08), entrée dessinée (fondu/scale
   depuis un bord). **App relancée avec séance déjà ouverte** : la pilule
   naît au lancement, position par défaut à définir.
2. **Mort** : fondu à la clôture (avant la story).
3. **Exercice en cours** : elle se retire (l'entrée = la publication
   `bandeVisiblePubliee` de la PageCard visible — PAS un état par page
   qu'un hôte global ne voit pas) et **revient à la position persistée**.
   ⚠️ Cette loi inclut aujourd'hui le CLAVIER (Exercices :
   `!etat.clavier`) : la pilule doit-elle disparaître pendant la saisie ?
   → décision §6.
4. **Player ouvert** : l'atterrissage du player fermait vers la dalle ;
   demain, idéalement il naît/meurt **vers la pilule** (fondu dirigé ou
   morphing — décision Kathryn : elle a déjà rejeté des transitions
   « cheap »).

## §5 · LE GALET BLANC — reformulé en DRAG

Le galet est un **slide-to-launch** (DragGesture min 6, LaunchPebble:705),
pas un tap : l'exclusion protège une **zone de SAISIE de drag ascendant**.
**A et B sont des COMPLÉMENTS, pas des alternatives** : A = aimant
d'exclusion au relâcher (on peut survoler, jamais se poser) ; B = esquive
automatique à l'OUVERTURE de la fiche quand la position persistée tombe dans
la zone (le cas « posée là AVANT d'ouvrir » n'est couvert par rien d'autre).
C (rien) reste déconseillé.

## §6 · LES DÉCISIONS — TRANCHÉES PAR KATHRYN LE 04-09

1. **Hors séance : la pilule N'EXISTE PAS.** ✓
2. **Le galet** : A+B (aimant au relâcher + esquive à l'ouverture) — non
   contredit, appliqué.
3. **La hauteur de la nav** : reste à trancher SUR CAPTURES (3 cotes, dont
   une qui re-mord le bas — le tap est désormais sans danger).
4. **Le verre au toucher de la nav** : reste à trancher sur les 3 variantes.
5. **Le clavier : la pilule DISPARAÎT pendant la saisie.** ✓
6. **L'atterrissage du player : MORPHISME avec la pilule** (le player naît
   d'elle et meurt vers elle). ✓ — le chantier d'animation se coordonne
   avec la session player (PlayerMonde est à elle).
7. **La forme** (dictée) : la pilule est LARGE (« comme une navigation »,
   l'école Live Activity) → pleine largeur moins marges ; on la pose à
   n'importe quelle HAUTEUR (drag partout pour le fun, l'x se recentre à
   l'élan au relâcher). **Robe : liquid glass NOIR → TRANSPARENT.**
   ⚠️ Loi payée : verre natif ANIMÉ = 60→14 img/s — donc verre AU REPOS,
   doublure mate PENDANT le drag (l'école VerreOuMat du player).

## §7 · LES JALONS (chacun MONTRÉ avant d'avancer)

1. **J1 — le banc pilule** (`-piluleLab`) : drag/aimants/tap/stop + les cas
   durs : doigt IMMOBILE 1 s puis reprise, drag tué sans onEnded
   (backgrounding), rafale tap/drag, poses interdites (nav/galet/strip),
   reprise depuis le flanc. Verdict à son doigt AVANT d'intégrer.
2. **J2 — la nav rabaissée** : cotes + verre, sur captures comparées.
3. **J3 — le démontage du repli** : la liste mesurée du §1, UN lot
   compilable, banc re-matricé dans le même lot.
4. **J4 — la pilule au châssis** + transitions §4 + règle du galet.
5. **J5 — les bancs re-matricés** : nav v2 à vrais touchers (taps 4 pages,
   drag pilule partout, poses interdites, tap→player, reprise flanc gauche
   sur la fiche) + film + **le fouettage player re-matricé** (l'ouverture
   par tap pilule à N positions ; la fermeture inchangée — le PanMaitre ne
   reçoit que ouvert).
6. **Verdicts TÉLÉPHONE, dits d'avance comme seuls juges** : gestes système
   réels, haptique, cadence (charge.sh avant).


---

## §8 · LA RÈGLE DES FLAMMES (Kathryn, 04-09) — vaut PARTOUT

**Une flamme = une série ACCOMPLIE. Jamais une promesse.**

- **Aucune flamme pour ce qui est à venir**, même à l'état vide : « on ne
  devine pas le nombre — mettre 4 flammes à l'état *upcoming* ne sert à
  rien, ça n'arrivera jamais ».
- **Au-delà de 4 flammes**, la dernière porte **« +N »** avec le compte —
  on ne prolonge pas la rangée.
- Appliqué le 04-09 dans `FlammesRow` (`FlammeJauge.swift` : `vides = 0`,
  `pleines = min(done, 4)`), donc **partout** où la rangée est montée
  (partition du player, cards, calendrier).
- ⚠️ **À porter aussi côté SERVEUR** (règle de gain / d'affichage) : la
  source ne doit jamais promettre un total de séries — elle compte ce qui
  est fait. À poser dans les règles back-end et sur le site de doc.

---

## §9 · LE LOT « TROIS ONGLETS » (dicté par Kathryn le 04-09, ANALYSÉ)

### Ce qui est tranché par elle
1. **La nav reste dans la partie noire**, fixe. **Le TAP la replie/la fait
   disparaître** — pas un drag (le bord bas appartient à iOS : c'est la
   leçon des deux jours, on n'y rouvre pas de geste).
2. **Au toucher : le verre liquide natif qui zoome, sur fond PLEIN NOIR.**
3. **Nav disparue → les page cards prennent TOUTE la page.**
4. **Le player par-dessus**, tel qu'il vient d'être construit (884112d).
5. **Trois onglets : Accueil · Exercices · Profil.** Progression est
   ARCHIVÉE, **et le calendrier + l'iPod avec elle** (inaccessibles dans
   l'app, gardés dans le code).
6. **La pop-up STOP doit être condensée.**

### Ce que le code dit (mesuré, pas supposé)
- La nav est montée sur QUATRE pages (home, exercices, progress, fiche) et
  **jamais** sur profil ni coffre : sa règle « pas sur profil/coffre » est
  **déjà tenue**, rien à retirer. Retirer Progress laisse **trois** pages
  porteuses ; le profil reste une DESTINATION sans porter la nav.
- Retirer l'onglet touche **huit endroits** : `WoopTab` (:112), l'ordre des
  onglets (WoopApp:375 et HomeAuroraView:19), la migration `openTab`
  (WoopApp:329 — une install qui a « progress » en mémoire ne doit pas
  atterrir dans le vide : la rabattre sur `.home`), le `Tab` lui-même
  (:1094-1105), la garde :725, `MenuCouronne` (:200/:221),
  `HomeNuit.destinations` (:1892), et `NavDest` (NavEncre:28) qui perd
  `prog`.
- **Le calendrier et l'iPod vivent DANS ProgressPage** (`CalendrierMois`,
  `MoisIpod`) : les archiver = archiver la page entière. Le fichier RESTE
  (aucune suppression), il n'a simplement plus de site d'appel — comme
  `HomeAuroraView` aujourd'hui.
- **La pop-up stop** : `StopCard` fait `l = min(largeur × 0,80, 332)` et une
  hauteur de **l × 480/332** — soit ~332 × 480 pt : elle occupe presque tout
  l'écran. La condenser = revoir ce ratio (une card, pas une page) + les
  cotes internes (titre 22, corps 15, bouton 44, `padding.bottom 36`).

### Le geste de la nav qui disparaît — la forme SÛRE
- **Tap sur la nav → elle s'efface** ; la card reprend toute la page (c'est
  le contrat `bandeVisible: false` qui EXISTE DÉJÀ et est éprouvé : il sert
  au clavier d'Exercices et à l'exercice en cours).
- **Elle revient** : par un tap sur la zone laissée libre, OU au changement
  d'onglet. ⚠️ **Le retour ne doit JAMAIS être un drag depuis le bord bas.**
- **Le verre au toucher** : ⚠️ la loi payée — un verre sur du noir uniforme
  est quasi INVISIBLE (« le contenu EST le verre »), et `.regular` est
  interdit. Sur fond plein noir demandé, il faudra lui donner quelque chose
  à réfracter (une lueur douce sous la capsule) — à comparer AU BANC sur
  captures avant d'intégrer, jamais à l'aveugle.

### L'ordre proposé (chaque jalon montré avant le suivant)
1. **J1 — Trois onglets** : archiver Progress + les huit sites, `NavDest` à
   trois, migration `openTab` rabattue. Lot compilable d'un bloc.
2. **J2 — La nav qui s'efface au tap** (via `bandeVisible`, le contrat
   existant) + son retour.
3. **J3 — Le verre au toucher**, sur captures comparées (3 variantes).
4. **J4 — La pop-up stop condensée**, sur captures.
5. **J5 — Le banc re-matricé** (le fouettage vit toujours) + verdicts doigt.

### Ce qui reste à trancher par Kathryn
- **Comment la nav REVIENT** une fois effacée (tap sur le bas ? au
  changement de page ? au scroll vers le haut ?) — je recommande le tap sur
  la zone libérée, symétrique de la disparition.
- **La pop-up stop condensée** : quelle silhouette ? (une card courte
  centrée ~332 × 300 ? un bandeau bas ?) — à voir sur captures.
