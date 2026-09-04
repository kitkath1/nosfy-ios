# LE PAN MAÎTRE DE BANDE — conception durcie (workflow arbitrage-drag-nav, 03-09)

Verdict de l'adversaire : **tient-avec-corrections** (10 failles trouvées et corrigées, intégrées ci-dessous).

## Les chaînes de défaillance (chacune avec preuve fichier:ligne)

### a1 — EN SÉANCE, nav DÉPLOYÉE : drag DOWN voulu « grosse nav → mini », le doigt tombe sur la dalle → le monde du player se monte, et le lever peut l'OUVRIR
① Géométrie réelle (iPhone 15, safeBottom 34) : la bande = grabber 18 + dalle 76 + nav 76 + air 2, descendue de 18 pt — donc, comptées depuis le bord physique : nav 18→94, DALLE 94→170, grabber 170→188. La nav déployée est BASSE ; le pouce qui vise « la bande de nav » se pose naturellement vers 100-150 pt du bord = LA DALLE. ② Le DragGesture(minimumDistance: 3) de la dalle reconnaît sur la NORME, sans filtre de signe — un drag DESCENDANT le déclenche pareil. ③ Premier onChanged → suivreDelta(-v.translation.height) → comme enSuivi est faux, saisir() : moteur arrêté, pAncre=p, enSuivi=true, monte=true, couvre=true — TOUT L'ARBRE DU PLAYER SE MONTE et les vidéos de fond passent à rate 0 (le figeage visible = « l'overlay se déclenche »). ④ Pendant tout le geste, delta est négatif → p reste collé à ~0 (butée élastique tanh ≤ 5 %) : AUCUN retour visuel du player, mais la nav ne reçoit RIEN (frères SwiftUI : celui qui a pris garde jusqu'au lever, aucune passation) — le repli voulu n'arrive jamais. ⑤ Au lever, commettre(velocite: v.velocity.height) : si le doigt décolle avec un micro-rebond vers le HAUT (velocity.height < −450, le jerk de fin de geste), cible = 1 → ouvert = true, vol complet → L'OVERLAY S'OUVRE EN GRAND alors qu'elle voulait replier. Sinon cible = 0 : le monde redescend, mais le flash couvre/monte a déjà eu lieu.

*Preuves* : PageCard.swift:65,69,72,119 (grabber 18, descente 18, offset de bande) ; PageCard.swift:151,164-166 (dalle 76) ; NavEncre.swift:208 (navH 76) ; PageCard.swift:178-187 (DragGesture min 3 → suivreDelta/commettre, velocity non inversée) ; PLAN-NAV-BANDE.md:236-249 (§2 ⚠️1 : reconnaissance sur la norme + saisir() qui monte l'arbre) ; PlayerMonde.swift:165-179 (saisir : monte=true, couvre=true), :192-212 (suivreDelta, butée ≤ 5 %), :250-253 (velocite < −450 → cible 1 quel que soit p) ; PLAN-NAV-BANDE.md:611-619 (§4ter : aucune passation entre frères).

### a2 — EN SÉANCE, nav DÉPLOYÉE : la pose hésitante (< 3 pt) meurt en TAP → ouvrir()
① Le doigt se pose sur la dalle (94→170 pt du bord) pour amorcer le repli, bouge de moins de 3 pt (minimumDistance du drag), et se lève. ② Aucun drag reconnu → le .onTapGesture de la dalle gagne → Haptique.moyen() + PlayerEtat.shared.ouvrir() → monte, couvre, ouvert=true, vol de 0,68 s : l'overlay s'ouvre PLEIN sur une intention de repli. C'est le « quand je tap ça ouvre le player, c'est un bug » déjà consigné au plan (§6bis, bug 2) — la version en-séance du même trou.

*Preuves* : PageCard.swift:171-174 (onTapGesture → ouvrir), :179 (minimumDistance 3) ; PlayerMonde.swift:57-70 (ouvrir : monte/couvre/ouvert + volVers(1)) ; PLAN-NAV-BANDE.md:871-893 (§6bis : le tap de la bande ouvrait le player).

### b1 — EN SÉANCE, nav MINI : drag UP voulu « mini → grosse » → GESTE HOME, l'app se ferme
① En mini, la nav fait 24 pt et vit à 18→42 pt du bord physique (bande descendue de 18) : sa MOITIÉ BASSE (18→34) est DANS la zone de l'indicateur home (inset 34 pt). Le dépli demandé est précisément un swipe UP démarrant là. ② Le système capte le swipe montant né sur/sous l'indicateur = geste Home. ③ RIEN ne le diffère hors de la home : le grep exhaustif du dépôt ne trouve `defersSystemGestures(on: .bottom)` QUE dans HomeNuit.swift:2495 — sur Exercices, Progress et la fiche (les trois autres PageCard), aucun deferral ; le plan §6quater C2 l'a déjà constaté (« rien ne déclare defersSystemGestures au châssis »). ④ Résultat : l'app passe en fond — « je me retrouve sur la home iPhone ». Même sur la home, le deferral ne fait que DIFFÉRER : le premier glissement revient à l'app, le second (ou un swipe sur l'indicateur ré-affiché) part au système — l'app ne peut pas le désactiver.

*Preuves* : NavEncre.swift:208 (navH mini 24) ; PageCard.swift:69,119 (descente 18 : la bande mord le bas physique) ; HomeNuit.swift:2489-2495 (le seul defersSystemGestures du dépôt + « ne DÉSACTIVE pas… elle la DIFFÈRE ») ; PLAN-NAV-BANDE.md:753-767 (§6quater C2 : Reachability/Home, fix châssis jamais posé) ; ExercisesView.swift:475, ProgressPage.swift:126, ExerciseDetailView.swift:611 (les trois PageCard sans deferral).

### b2 — EN SÉANCE, nav MINI : le drag UP rate la cible de 24 pt, tombe 2 pt trop haut → LA DALLE → le player s'ouvre au lieu du dépli
① La cible du dépli fait 24 pt de haut (18→42), coincée entre la zone système (dessous) et la dalle player 76 pt (42→118, dessus). ② Un départ à ≥ 42 pt du bord tombe sur la dalle : son DragGesture prend, suivreDelta reçoit un delta POSITIF (drag up) → p SUIT le doigt, le corps du player monte à l'écran. ③ Au lever, commettre : p > 0,2 → cible 1 (ou flick : velocite < −450 → cible 1) → le player S'OUVRE. La fenêtre de réussite du dépli est une bande de 24 pt visée au pouce, collée au bord — structurellement ratable ; et le commit du dépli, lui, n'aurait demandé qu'un flick de −140 pt/s ou 34 pt de course.

*Preuves* : PageCard.swift:151,164-187 (dalle 76 + DragGesture) ; PlayerMonde.swift:192-212 (p suit le doigt), :250-253 (p > 0,2 ou élan → cible 1) ; NavEncre.swift:155-166 (commettre nav : seuils −140 / 0,78 depuis mini), :197 (course 34 pt).

### c1 — HORS SÉANCE : le repli (drag DOWN) est pris pour REACHABILITY — tout l'écran descend
① Hors séance la bande = grabber 18 + nav 76 + air 2, descendue de 18 : la nav vit à 18→94 pt du bord. Le repli est un tirage VERS le bord bas ; le point de départ naturel du pouce est 24-34 pt du bord — PILE la bande que le système se réserve (le constat est écrit dans le code de la home, payé le 26-08 : « le geste qu'on demande ici commence naturellement à 24-34 pt du bord bas »). ② Reachability = glisser vers le bas sur le bord bas : le système prend, TOUT l'écran descend (status bar comprise, chevron gris au-dessus) — la capture du 03-09 au téléphone est exactement ça (§6quater C2 : « la page poussée ~60 % vers le bas, noir + chevron ^ »). ③ Sur la home le deferral absorbe le premier glissement ; sur les trois autres pages, rien. ④ En prime, quand le système vole le doigt APRÈS que NavBande a pris, le DragGesture meurt SANS onEnded : seul le chien de NavEtat (0,45 s) commet — l'état stable revient, mais avec un à-coup différé.

*Preuves* : HomeNuit.swift:2479-2495 (Reachability, le « bord bas est à nous d'abord », deferral home seule) ; PLAN-NAV-BANDE.md:753-762 (C2 : la capture du 03-09 = Reachability, la mini nav dans la zone du geste système) ; NavEncre.swift:421 (DragGesture min 4), :119-121,182-194 (le chien, un DragGesture peut mourir sans onEnded).

### c2 — HORS SÉANCE (et en séance pareil) : le repli LÉGER démarré sur un glyphe finit en TAP → changement de page
① La course TOTALE du repli fait 34 pt (NavEtat.course) : un repli « léger » est par nature un geste de 10-25 pt, lent. ② Chaque glyphe porte contentShape 44×44 + highPriorityGesture(TapGesture) — et highPriorityGesture BAT le drag de l'HÔTE NavBande, qui est son ANCÊTRE (la doc du composant le dit elle-même : « il gagne contre le drag de l'hôte »). ③ Tant que le doigt reste dans la tolérance de mouvement du TapGesture, le tap reste en course ; au lever → onChoix(d) → aller(d) → NavEtat.page change → le pont du châssis bascule le TabView : NAVIGATION au lieu du repli. ④ Les glyphes couvrant l'essentiel de la surface utile de la nav, « démarrer sur un glyphe » est le cas nominal, pas l'exception. C'est le C3 du plan, mesuré le 03-09 (« parfois changement de page »).

*Preuves* : NavEncre.swift:197 (course 34), :322-338 (cible 44 pt + highPriorityGesture, « il gagne contre le drag de l'hôte »), :434-444 (aller → page) ; WoopApp.swift:1119-1123 (le pont NavEtat.page → selection) ; PLAN-NAV-BANDE.md:769-781 (§6quater C3, le fix promis).

### d1 — DÉRIVE nav→dalle : le dépli continué vers le haut ne peut JAMAIS ouvrir le player
① Un drag UP démarre sur la nav (NavBande prend à 4 pt) et continue haut, le doigt traverse visuellement la dalle puis la page. ② Entre gestes SwiftUI FRÈRES il n'y a aucune passation : NavBande garde le doigt jusqu'au lever. ③ La nav arrive en butée (sur-course élastique ≤ 6 %) et reste là ; le player ne s'ouvre pas, quelle que soit la distance parcourue. Bénin mais incohérent avec l'attente « je continue vers le haut donc le player vient ».

*Preuves* : NavEncre.swift:420-430 (le tirage de NavBande), :136-139 (butée élastique) ; PLAN-NAV-BANDE.md:611-619 (§4ter : « un repli poursuivi vers le haut… le player ne s'ouvre jamais ») ; NavEncre.swift:416-419 (le commentaire du composant qui promet le pan maître pour cette raison exacte).

### d2 — DÉRIVE dalle→nav : le drag descendu sur la nav continue de piloter le player — la nav ne se replie jamais, et le monde est monté pour rien
① Un drag démarré sur la dalle (même descendant, cf. a1) appartient au DragGesture de la dalle jusqu'au lever. ② Le doigt descend sur la nav puis dessous : suivreDelta continue de recevoir — saisir() a DÉJÀ posé monte/couvre (arbre du player monté, vidéos à rate 0 : le « lag » perçu du §6bis). ③ La nav ne reçoit jamais rien → pas de repli. ④ Si le doigt sort de l'écran ou est volé par le système : pas de onEnded — le chien du player (0,4-0,45 s) commet à velocite 0 → p < 0,2 → cible 0 : retour au calme, mais APRÈS un gel visible.

*Preuves* : PLAN-NAV-BANDE.md:618-619 (« l'inverse est vrai aussi… la nav ne se replie jamais »), :888-890 (§6bis : le geste parasite EST le lag) ; PlayerMonde.swift:165-179 (saisir), :214-229 (armerChienSuivi), :253 (p < 0,2 → 0).

### d3 — DÉRIVE sous le bord : le geste volé par le système laisse 0,4 s d'état suspendu, puis un commit que la main n'a pas choisi
① Un repli qui finit dans la zone système (c1/b1) se fait ANNULER : DragGesture SwiftUI ne reçoit pas toujours onEnded (piège payé sur la lune et le player). ② Pendant ~0,4 s, enSuivi reste vrai : la bande est figée sur la dernière frame du doigt. ③ Le chien commet alors à velocite 0 : depuis déployée, cible = (suivi > 0,45) — un repli interrompu à mi-course peut donc se COMMETTRE en mini (ou rester déployé) selon le pixel où le système a volé : l'utilisatrice voit la nav « décider seule », en retard. Le filet existe (jamais d'état inventé), mais l'expérience du vol système reste un à-coup différé.

*Preuves* : NavEncre.swift:119-121,181-194 (le chien : 0,45 s, commettre(velocite: 0)), :160-163 (les seuils du commit) ; le même patron player : PlayerMonde.swift:218-229 ; skill woop-architecture §4 (un DragGesture n'appelle pas toujours onEnded).

---

# LE PAN MAÎTRE DE BANDE — conception durcie (v2, après relecture adverse ligne à ligne)

Exécution du J4 du plan (`tools/nav/PLAN-NAV-BANDE.md:942-949`) et de la promesse écrite dans le composant (`NavEncre.swift:416-419`) : **UN UIPanGestureRecognizer posé sur TOUTE la bande** (grabber + dalle + nav + air), l'école du `PanMaitre` du player (`PlayerMonde.swift:646-789`) posée sur la bande et non sur la fenêtre — ce que §4.9 prescrit mot pour mot (plan :537-541). Il REMPLACE les deux `DragGesture` SwiftUI concurrents (dalle `PageCard.swift:178-187`, nav `NavEncre.swift:420-430`) — « deux recognizers dans 96 pt, c'est un bug, pas un arbitrage » (plan :542). Les TAPS restent aux vues SwiftUI (§6). Précédent maison du geste-unique-de-rangée : `JewelTabBar.swift:313-318`. **PlayerMonde.swift : ZÉRO ligne touchée.**

## Ce que ça tue, ce que ça laisse (l'honnêteté d'abord)

MORT : a1 (drag descendant sur la dalle → plus jamais de `saisir()` : il route au repli — plus de flash d'overlay, plus d'ouverture surprise au micro-rebond) · c2/C3 (repli né sur un glyphe → plus de changement de page, sous réserve de la sonde §10-⑥) · d1/d2 (un seul propriétaire : plus de geste enfermé chez le mauvais frère) · le toucher-sous-le-noir du vol de fermeture (§4ter:642-650, porte §5) · le suspect n°3 du FIX 2 du plan (:842-846 — « la nav prend le doigt sous le player ouvert » : tirage supprimé + porte `!monte` = mort par construction).

AMÉLIORÉ : d3 — un recognizer UIKit volé par le système reçoit `.cancelled` IMMÉDIATEMENT : on commet à la vélocité du vol, sans attendre le chien (le 0,4 s de flottement ne reste qu'en filet) · b1/c1 — geste Home et Reachability DIFFÉRÉS sur toutes les pages (§7), premier swipe à l'app ; le second reste au système, c'est la loi d'iOS (`HomeNuit.swift:2489-2493`), aucune conception ne l'abolit.

RÉSIDUEL, dit et assumé : **a2 s'élargit de 3 à ~10 pt** — une pose qui bouge de moins de ~10 pt puis lève reste un TAP de dalle → ouverture pleine (le tap est une affordance voulue, indiscernable d'un poke court). En échange : sous 10 pt plus AUCUN montage d'arbre (le flash actuel dès 3 pt meurt), au-dessus tout drag bas est un repli propre. À sentir au doigt ; escalade possible (tap UIKit avec `require(toFail:)`) seulement sur verdict. · b2 (rater la mini nav de 2 pt vers le haut ouvre le player) ne meurt qu'avec l'option de zone §2 ou l'option B §7 — au doigt. · Le claquement de rattrapage d'un commit nav en vol (re-saisir pendant les 0,25 s : `rAncre` lit la cible pendant que l'écran est à mi-vol) est un défaut du MOTEUR NavEtat (`NavEncre.swift:173-179`, prédit par §4bis:586-592), pas du pan — hors périmètre, à ne pas lui imputer au fouettage. · Reachability et le 2ᵉ swipe : au système, pour toujours.

## 0 · Pourquoi la BANDE et pas la fenêtre — et le pari nommé

Le PanMaitre du player est window-level parce qu'il doit battre un `UIScrollView` partout sur le corps ouvert. La bande n'a pas ce problème : rectangle fixe, sans scroll, monté quatre fois (HomeNuit.swift:2360, ExercisesView.swift:475, ProgressPage.swift:126, ExerciseDetailView.swift:611), une seule visible et hit-testable à la fois. Le pan SUR la UIView de bande : le recognizer meurt avec sa vue (démontage `bandeVisible == false` — clavier d'Exercices, fiche en flood, plan :201-203 — gratuits), pas de cible zombie (PlayerMonde.swift:652-663), quatre bandes = zéro conflit (un doigt, une UIView).

**LE PARI ④, nommé** : les touches doivent atteindre notre UIView (hit-test UIKit du sous-arbre de page) PENDANT que les gestes SwiftUI (recognizers de la hosting view, ancêtre) continuent de les voir. C'est le comportement UIKit attendu (la dalle ne contient AUCUNE autre UIView — `WorkoutPill` est du pur SwiftUI, vérifié), mais AUCUN précédent identique dans ce dépôt : il se PROUVE à la sonde au premier build (§10-①②), avec le plan B fenêtre complet prêt (§10bis). On ne déclare rien avant ces lignes.

## 1 · Le POSTE

Dans `PageCard.bande` (PageCard.swift:153-195), en `.background` du VStack, AVANT le `.offset(y: descente)` extérieur (:119) — la UIView épouse tout le VStack (grabber 18 + [dalle 76] + nav navH + air 2) et, vraie UIView, elle est réellement déplacée par la mise en page : **zone tactile = pixels**, la loi du commit 39f95f9 et de §4.4 (plan :522-524) respectée par construction. Bénéfice : le grabber, aujourd'hui sans forme tactile (plan :608-609), devient prenant — une prise de repli HAUTE (170→188 pt du bord en séance déployée, 118→136 en mini), loin de la zone système. La UIView s'arrête PILE au bas de la card (`bandeH` décompte la descente, PageCard.swift:70-72) : elle ne mord jamais la page.

## 2 · Les ZONES — par position Y de DÉPART du toucher

Coordonnées locales de la bande (y=0 en haut). Les cotes viennent d'un `enum BandeCote { grab = 18 ; dalle = 76 }` déclaré dans PanBande.swift et CONSOMMÉ AUSSI par PageCard (:65, :151) — une seule source, jamais deux calculs qui divergent (la doctrine de `dockH`, NavEncre.swift:199-207).

EN SÉANCE — bande = 18 + 76 + navH + 2 :
· y ∈ [0, 18)  → GRABBER → repli/dépli (NavEtat)
· y ∈ [18, 94) → DALLE   → player en UP, repli en DOWN (§3)
· y ≥ 94       → NAV (+ air) → repli/dépli — la borne basse n'est PAS relue : la zone nav est « le reste », robuste au navH 24/76.

HORS SÉANCE — bande = 18 + navH + 2 : tout est GRABBER/NAV → repli/dépli.

La zone se fige à la DÉCISION à partir du point de POSE (`location − translation`) et ne se relit plus jamais.

Option à trancher AU DOIGT (verdict téléphone) : en nav MINI, élargir la zone nav de 12 pt vers le haut (dalle [18, 82), nav [82, …]) — la cible de dépli passe de 24 à 36 pt et le résidu b2 meurt. Coût : un drag-up d'ouverture du player né très bas part en dépli. Un chiffre dans `zoneDe`, rien d'autre.

## 3 · La DÉCISION — un seul verdict, verrouillé jusqu'au lever

Dans `gestureRecognizerShouldBegin` — LE bon endroit du plan §4.9 (:543-545) : un refus ICI rend le toucher intact, aucun `touchesCancelled` (le piège « un refus dans onChanged ne rend jamais le toucher » contourné à la racine).

· |tx| > |ty| → **return false** : le toucher continue de vivre (tap, geste latéral).
· vertical, départ DALLE, ty < 0 (UP) → mode **.player** — l'ouverture au doigt, inchangée.
· vertical, départ DALLE, ty > 0 (DOWN) → mode **.repli** — LE fix de a1. **Conforme au plan** : c'est la lettre de §4.9 « bas → la nav » (:540).
· vertical, départ GRABBER ou NAV → mode **.repli**, les deux sens (`NavEtat.suivre` gère dépli, repli et ses butées, NavEncre.swift:131-144). **ÉCART EXPOSÉ à la lettre de §4.9/J4** (« haut → le player ») : à la lettre, un drag-up né sur la MINI NAV ouvrirait le player et le dépli mini→big serait IMPOSSIBLE — le contraire exact de la demande. Le routage par zone+direction est le seul compatible ; §4.9/J4 seront mis à jour dans le commit du code.

**Une fois `mode` posé, ON NE CHANGE PLUS jusqu'au lever** — l'école de la rafale (PlayerMonde.swift:684-687). Seuil effectif ≈ 10 pt (interne UIPan) ; le suivi étant RELATIF à l'ancre du `.began`, aucune course n'est perdue (contrat : min 4 + 34 pt hier, ~10 + 34 pt demain — à sentir au téléphone ; l'école `.changed` à 6 pt du player reste l'alternative si la mesure l'exige, avec son coût : elle décide après le cancel des taps).

## 4 · La MACHINE À ÉTATS

`mode ∈ {indecis, player, repli}` · `zone` · `tyAncre` · `rAncre`.

· `.began` → fige `tyAncre` ; mode .player → `PlayerEtat.shared.suivreDelta(-(ty−tyAncre))` (le 1ᵉʳ appel fait `saisir()` ET arme le chien — PlayerMonde.swift:192-195, API existante) ; mode .repli → `rAncre = NavEtat.shared.r` puis `NavEtat.shared.suivre(depuis: rAncre, delta: ty−tyAncre)` (saisir + SON chien — NavEncre.swift:123-144).
· `.changed` → le même appel. Le pan n'écrit AUCUN layout : il parle aux deux moteurs.
· `.ended`, `.cancelled`, `.failed` → `commettre(velocite: g.velocity(in:).y)` du moteur du mode, puis `mode = .indecis`. Signes = ceux des appels actuels (PageCard.swift:184-187, NavEncre.swift:424-429) ; UIPan et SwiftUI partagent la convention y-positif-vers-le-bas. **Gain d3** : le vol système livre `.cancelled` immédiatement → commit à la vélocité du vol ; les chiens des moteurs (PlayerMonde.swift:218-229, NavEncre.swift:182-194) restent le filet — le pan n'en ajoute pas.

## 5 · Les PORTES — deux portes DISTINCTES, et l'ordre des modificateurs est la moitié du fix

**Porte du pan** : `gestureRecognizer(_:shouldReceive:) → !PlayerEtat.shared.monte && !DepartEtat.shared.pauseOuverte`. `monte` est vrai de `ouvrir()`/`saisir()` (PlayerMonde.swift:63, :171) jusqu'à la FIN du vol de fermeture (:88-93) : les « trois états » du plan §4.10 en UNE lecture, zéro ligne dans PlayerMonde. Consultée À LA POSE du toucher seulement — jamais en cours de geste : le pan qui a pris garde le doigt même quand son propre `saisir()` fait basculer `monte`.

**Porte des taps** : `.allowsHitTesting(!PlayerEtat.shared.monte)` sur le VStack de la bande, posée **AVANT** `.background { PanBande }` dans la chaîne. ⚠️ L'ORDRE EST NORMATIF : posée après, elle couvrirait la UIView du pan — et le premier `suivre` d'un drag d'ouverture (`saisir()` → `monte = true`) couperait le hit-testing SOUS le doigt en plein geste, comportement UIKit non garanti (risque d'auto-annulation du geste vedette). Avant, elle n'éteint QUE le contenu SwiftUI : tap dalle, glyphes, stop — sourds pendant vols et posé (le yoyo du toucher-sous-le-noir, §4ter:642-650, meurt ici), le pan restant gouverné par sa seule `shouldReceive`. `monte` flippe deux fois par geste, jamais par frame (PlayerMonde.swift:22-28) : la ré-évaluation de PageCard est bon marché.

Table de coexistence avec le PanMaitre FENÊTRE (porte : `ouvert && !pauseOuverte`, PlayerMonde.swift:735-739) :

| Moment | pan de BANDE | taps bande | PanMaitre FENÊTRE |
|---|---|---|---|
| Fermé au repos | ✅ | ✅ | ✖ |
| Suivi au doigt (notre pan) | possède | (cancel) | ✖ (`ouvert` faux, saisir n'y touche pas — plan :640) |
| Vol d'ouverture (0,68 s) | ✖ | ✖ | ✅ (rafale payée) |
| Ouvert posé | ✖ | ✖ | ✅ |
| Vol de fermeture (0,68 s) | ✖ | ✖ | ✖ — PERSONNE, voulu (§4ter:639) |

Jamais deux preneurs : le `shouldRecognizeSimultaneouslyWith true` inconditionnel du PanMaitre (:730-733, l'avertissement du plan :551-553) n'a personne à rencontrer — disjonction structurelle par les portes. Notre propre réponse à la simultanéité : **false**.

## 6 · La stratégie TAP — le pan n'en gère AUCUN

Réglages : `cancelsTouchesInView = true` · `delaysTouchesBegan = false` (zéro latence de tap) · `maximumNumberOfTouches = 1` · delegate = le coordinateur.

· **Tap immobile** (< ~10 pt) : le pan n'atteint jamais `.began` → les touches suivent leur route SwiftUI : dalle `.onTapGesture → ouvrir()` (PageCard.swift:171-174, désormais gardée par la porte des taps), glyphes `highPriorityGesture(TapGesture) → aller` (NavEncre.swift:322-338, forme maison anti-Button conservée), stop du pill (`WorkoutPill.swift:79-84`). Aucun hit-test manuel, aucune duplication de `aller`.
· **Drag décidé** (vertical, `.began` franchi) : les taps meurent — MÉCANISME EXACT : pas `cancelsTouchesInView` (il ne coupe que la livraison aux vues, pas les recognizers SwiftUI de la hosting view), mais l'**exclusivité d'arène** : notre pan reconnu + notre delegate refusant la simultanéité → les autres recognizers de la même touche sont empêchés. ⚠️ La simultanéité est accordée si UN SEUL des deux delegates dit oui — le côté SwiftUI n'est pas sous notre contrôle : **c'est un point de SONDE obligatoire (§10-⑥)**, pas un acquis. Escalade mesurée si le tap survit : `gestureRecognizer(_:shouldBeRequiredToFailBy:)` → true pour tout recognizer dont la vue est un ANCÊTRE de la nôtre mais PAS la fenêtre (les gestes SwiftUI attendent alors l'échec du pan — résolu au lever, imperceptible ; PanMaitre et gates système, sur la fenêtre, exclus).
· **Geste horizontal** : `shouldBegin` → false → pas de cancel → un tap un peu glissé survit.
· **VoiceOver** : le double-tap synthétisé ne bouge pas → le pan ne commence jamais → toutes les activations passent ; la UIView du pan n'est pas un élément d'accessibilité (défaut). Polish hors périmètre : trait `.isButton` sur les cibles.

## 7 · Le GESTE SYSTÈME — couverture réelle et géométrie chiffrée

① `.defersSystemGestures(on: .bottom)` — **posé sur LA RACINE DE PageCard** (le GeometryReader de body), PAS au châssis : ExercisesView et la fiche vivent AUSSI dans un fullScreenCover (HomeNuit.swift:2433-2464) = un autre view controller que mainBody — au châssis, b1/c1 resteraient vivants précisément là. Sur PageCard, la protection voyage avec la bande partout (onglet, push, cover, bancs) ; le doublon avec HomeNuit:2495 est inoffensif. `.persistentSystemOverlays(.hidden)` (l'indicateur disparaît) : ÉCART VISUEL — à faire valider par Kathryn avant de le poser, même endroit. Couvre : le PREMIER swipe du bord revient à l'app (donc au pan) ; ne couvre JAMAIS : le second swipe, et Reachability (différée, jamais désactivable — HomeNuit.swift:2489-2493). C'est la part qui reste au système quoi qu'on code.

② LA PRISE REMONTE : le grabber prenant (§1) offre un repli/dépli à 118-188 pt du bord. La descente, deux options :
· **Option A, défaut — AUCUN écart visuel** : `descente` reste 18 (verdict 01-09 sacré). Mini nav 18→42 pt du bord, moitié basse dans la home-bar : à ① posé, l'essentiel de b1/c1 tombe au premier geste.
· **Option B, à faire VALIDER (écart au verdict 01-09, exposé, jamais décidé ici)** : `descente` 18 → 10 ; centre des points ~38 pt > 34 : les swipes répétés restent à l'app.
· Dans les deux cas, le conditionnement SE (plan :652-667) : `descente = safeBottom > 0 ? 18 : 0`. ⚠️ Plomberie réelle : `descente`/`bandeH` sont des computed properties sans accès aux insets (PageCard.swift:64-72) — elles deviennent des fonctions de `g.safeAreaInsets.bottom` lu dans body (:84). À la liste de coordination.

## 8 · Les retouches EXACTES hors du fichier nouveau (PlayerMonde.swift : ZÉRO ligne)

· `PageCard.swift` (⚠️ session home/BordSeance — coordination J1 obligatoire, plan :923-925) : SUPPRIMER le `.gesture(DragGesture…)` de la dalle (:178-187 ; le tap :171-174 RESTE) ; sur `bande` : `.allowsHitTesting(!PlayerEtat.shared.monte)` PUIS `.background { PanBande(enSeance: enSeance) }` — dans CET ordre (§5) ; `grabH`/`dalleH` lisent `BandeCote` ; la plomberie descente/safeBottom (§7-②) ; (option B seulement) la valeur.
· `NavEncre.swift` (notre fichier) : SUPPRIMER `.gesture(tirage)` (:397), `tirage` (:420-430), `ancre` (:432) **ET `.contentShape(Rectangle())` (:396)** — sa seule raison d'être était le tirage ; gardé, il maintient une surface interactive pleine bande au-dessus de la UIView du pan (le pari ④ aggravé pour rien). Les cibles 44 pt des glyphes gardent leurs formes. Le banc `-navEncre` monte PageCard (:567-573) → hérite du pan sans retouche.
· `WoopApp.swift` (châssis partagé, ⚠️ main ne compile pas seul — hunks datés avant tout geste) : le co-requis d'une ligne du plan (:793-802) : `.animation(.easeInOut(duration: 0.25), value: dockH)` sur `pageEnCard` — sans lui, le commit du repli fait SNAPPER la card de 52 pt et le pan sera accusé à tort. (Les modificateurs système partent sur PageCard, plus au châssis — §7.)
· Build : PanBande.swift entre dans le target.
· À dire à la session player : la conception DÉPEND de `monte`, `suivreDelta`, `commettre`, `ouvrir`, `pauseOuverte` — un renommage casse en silence.

## 9 · Le PSEUDO-CODE (fichier nouveau `Woop/Views/PanBande.swift`)

```swift
import SwiftUI
import UIKit

/// Les cotes de la bande — UNE source, consommée ici ET par PageCard.
enum BandeCote {
    static let grab: CGFloat = 18
    static let dalle: CGFloat = 76
}

/// LE PAN MAÎTRE DE BANDE (plan §4.9/§4ter/J4) — l'école de PanMaitre
/// (PlayerMonde.swift:646-789) posée sur LA BANDE : un seul propriétaire
/// du drag vertical du bas ; les taps restent aux vues SwiftUI.
struct PanBande: UIViewRepresentable {
    var enSeance: Bool

    final class Coord: NSObject, UIGestureRecognizerDelegate {
        var enSeance = false
        enum Mode { case indecis, player, repli }
        enum Zone { case grabber, dalle, nav }
        var mode: Mode = .indecis
        var zone: Zone = .nav
        var tyAncre: CGFloat = 0
        var rAncre: CGFloat = 0
        let crie = CommandLine.arguments.contains("-gesteSonde")

        func zoneDe(_ y: CGFloat) -> Zone {
            if y < BandeCote.grab { return .grabber }
            if enSeance, y < BandeCote.grab + BandeCote.dalle { return .dalle }
            return .nav
        }

        // LA PORTE DU PAN — lue à la POSE du toucher, jamais en cours de
        // geste : `monte` couvre vol d'ouverture + posé + vol de fermeture
        // (PlayerMonde.swift:63, 88-93, 171) = les « trois états » de §4.10.
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldReceive t: UITouch) -> Bool {
            !PlayerEtat.shared.monte && !DepartEtat.shared.pauseOuverte
        }

        // LA DÉCISION, AVANT de consommer le doigt : un refus ici REND le
        // toucher — aucun touchesCancelled (plan §4.9 :543-545).
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pan = g as? UIPanGestureRecognizer,
                  let v = pan.view else { return false }
            let t = pan.translation(in: v)
            guard abs(t.y) >= abs(t.x) else { return false }   // latéral
            // La zone au POINT DE POSE, jamais à la position courante.
            zone = zoneDe(pan.location(in: v).y - t.y)
            // Routage exposé §3 : dalle-UP → player ; tout le reste → repli
            // (dalle-DOWN = la lettre de §4.9 « bas → la nav » ; nav-UP =
            // l'écart exposé, seul compatible avec le dépli mini→big).
            mode = (zone == .dalle && t.y < 0) ? .player : .repli
            if crie { print("GESTE-SONDE bande DÉCIDE \(mode)/\(zone)") }
            return true
        }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            guard let v = g.view else { return }
            let ty = g.translation(in: v).y
            switch g.state {
            case .began:
                tyAncre = ty
                if mode == .repli { rAncre = NavEtat.shared.r }
                suivre(ty)
            case .changed:
                suivre(ty)          // UNE FOIS DÉCIDÉ, ON NE CHANGE PLUS.
            case .ended, .cancelled, .failed:
                // .cancelled = le vol système : commit IMMÉDIAT à la
                // vélocité du vol (gain d3) ; les chiens des moteurs
                // restent le filet.
                let vy = g.velocity(in: v).y
                switch mode {
                case .player: PlayerEtat.shared.commettre(velocite: vy)
                case .repli:  NavEtat.shared.commettre(velocite: vy)
                case .indecis: break
                }
                if crie { print("GESTE-SONDE bande COMMET v=\(Int(vy))") }
                mode = .indecis
            default: break
            }
        }

        private func suivre(_ ty: CGFloat) {
            switch mode {
            case .player:
                // 1er appel = saisir() + chien (PlayerMonde.swift:192-195).
                // Signe : celui de la dalle d'hier (PageCard.swift:181-183).
                PlayerEtat.shared.suivreDelta(-(ty - tyAncre))
            case .repli:
                // saisir() + chien inclus (NavEncre.swift:123-144).
                NavEtat.shared.suivre(depuis: rAncre, delta: ty - tyAncre)
            case .indecis: break
            }
        }

        // Quand la bande prend, elle POSSÈDE. (⚠️ La simultanéité est
        // accordée si UN des deux delegates dit oui : ce false ne verrouille
        // que NOTRE côté — l'extinction des taps se PROUVE à la sonde
        // §10-⑥ ; escalade mesurée : shouldBeRequiredToFailBy → true pour
        // les recognizers d'ANCÊTRES hors fenêtre.)
        func gestureRecognizer(
            _ g: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer
        ) -> Bool { false }
    }

    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = true    // ≠ la sonde du player : ICI la vue REÇOIT.
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coord.pan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true
        pan.delaysTouchesBegan = false       // taps sans latence
        pan.delegate = context.coordinator
        v.addGestureRecognizer(pan)
        context.coordinator.enSeance = enSeance
        return v
    }

    func updateUIView(_ v: UIView, context: Context) {
        context.coordinator.enSeance = enSeance
    }
    // Pas de dismantle : le pan vit sur NOTRE vue et meurt avec elle — la
    // cible zombie (PlayerMonde.swift:652-663) n'existe pas au niveau bande.
}
```

Et dans `PageCard.bande` — **l'ordre des deux derniers modificateurs est normatif (§5)** :

```swift
private var bande: some View {
    VStack(spacing: 0) {
        Capsule() /* grabber inchangé, :155-159 */
        if enSeance {
            dalle
                .frame(height: dalleH)          // dalleH = BandeCote.dalle
                .contentShape(Rectangle())
                .onTapGesture {                  // LE TAP RESTE — résidu a2
                    Haptique.moyen()             // ÉLARGI à ~10 pt, assumé
                    PlayerEtat.shared.ouvrir()   // et dit (§ résidus).
                }
                // ⚠️ le DragGesture(min 3) MEURT ici — remplacé par PanBande.
        }
        nav   // NavBande SANS .gesture(tirage) NI .contentShape plein
    }
    .padding(.bottom, 2)
    .allowsHitTesting(!PlayerEtat.shared.monte)  // ① les TAPS sourds sous
                                                 //    monte (yoyo mort)…
    .background { PanBande(enSeance: enSeance) } // ② …et le PAN HORS de
                                                 //    cette porte : sa
                                                 //    shouldReceive suffit,
                                                 //    jamais coupée en vol
                                                 //    de son propre geste.
}
```

## 10 · La VÉRIFICATION prescrite (rien n'est « fait » sans ces lignes)

`-gesteSonde` imprime déjà SAISIR/COMMETTRE/maitre PREND (PlayerMonde.swift:175-177, 238-241, 694-708) ; le pan crie DÉCIDE/COMMET ; SondeHit (`-hitSonde`, PlayerMonde.swift:874-893) dit QUI répond au point dalle. Au premier build :
① tap dalle → ouvrir ; tap glyphe → aller ; tap stop → panneau (le pan ne began pas) ;
② drag down né sur la dalle → lignes NAV seulement, JAMAIS « player SAISIR » (a1 mort, prouvé) ;
③ drag up sur la mini nav → dépli (lignes NAV) ;
④ pendant un vol (0,68 s) → aucune ligne bande ; **tap dalle pendant le vol de fermeture → RIEN** (le yoyo mort, prouvé) ;
⑤ player OUVERT : drag bas né sur la zone bande → lignes « maitre PREND » (fenêtre) uniquement — jamais bande ;
⑥ **drag vertical de 15-25 pt né SUR un glyphe → au lever, `NavEtat.page` INCHANGÉ** (l'extinction des taps prouvée — si elle échoue : escalade `shouldBeRequiredToFailBy`, §6) ;
⑦ **drag d'ouverture lent depuis la dalle, tenu 1 s puis poursuivi → le suivi CONTINUE après le flip de `monte`** (F1 prouvé mort) ;
⑧ le protocole du FOUETTAGE ULTIME en entier (la porte de tout verdict player) + cadence au téléphone après `./tools/charge.sh` — jamais au simulateur.
Si ① ou ② montrent que la UIView ne reçoit pas (le pari ④ perdu) → §10bis, le jour même.

## 10bis · LE PLAN B COMPLET — l'école fenêtre avec garde de position

Si le hit-test affame la UIView de bande : MÊME coordinateur, mêmes zones, mêmes moteurs, mêmes signes — seul le POSTE change. Le pan part sur la FENÊTRE (le patron exact de PlayerMonde.swift:759-783) ; la UIView de PanBande reste montée mais passe `isUserInteractionEnabled = false` : elle devient la SONDE DE COORDONNÉES. La porte s'enrichit d'une garde de position : `shouldReceive` = (porte actuelle) ET `sonde.bounds.contains(sonde.convert(touch.location(in: fenêtre), from: fenêtre))` — seule la bande VISIBLE contient le point (les pages cachées d'un TabView sont détachées : leur convert échoue ou tombe hors bounds). `zoneDe` lit le y converti dans la sonde — les zones de §2 inchangées. Discipline zombie OBLIGATOIRE : `dismantleUIView` → retirer le pan de la fenêtre (l'école PlayerMonde.swift:652-663, `fenetrePosee`). Coexistence avec le PanMaitre : inchangée — les portes `!monte` / `ouvert` restent disjointes, deux pans de fenêtre ne prennent jamais le même toucher. Bascule = un drapeau de build.

## RISQUES ADMIS (mis à jour)

① FICHIERS D'AUTRES SESSIONS — PageCard.swift (chantier home/BordSeance, J1 :923-925) et WoopApp.swift (châssis ; main ne compile pas seul — dater tout hunk étranger, committer par CHEMINS, jamais `git add -A`). PlayerMonde.swift zéro ligne, mais dépendance d'API (monte/suivreDelta/commettre/ouvrir/pauseOuverte) — à dire à la session player.
② L'INVARIANT SACRÉ « taille fixe partout » — option A : aucune cote ne bouge. Option B (descente 18→10), `persistentSystemOverlays(.hidden)` (l'indicateur disparaît sur les 4 pages), et le conditionnement SE : trois ÉCARTS VISUELS à exposer à Kathryn AVANT de coder.
③ LE CANCEL À ~10 pt — un tap gras glissé de 10-15 pt est avalé (prix de C3 mort) ; et le résidu a2 élargi (3→~10 pt, §résidus). À MESURER AU DOIGT.
④ LE HIT-TEST — le pari central, sondé au premier build (§10-①②), plan B complet prêt (§10bis). Ne rien déclarer sans les lignes de sonde. Même incertitude en miroir : si un overlay SwiftUI (panneau départ, etc.) ne bloque PAS la UIView du pan, étendre la porte `shouldReceive` — à sonder au même build.
⑤ LES LOIS PAYÉES — aucun withAnimation sur les valeurs suivies ; sans `.animation(value: dockH)` le commit SNAPPE la card de 52 pt (plan :793-802) ; mode verrouillé (rafale) ; chiens conservés ; `allowsHitTesting(!monte)` éteint AUSSI le stop de la dalle pendant vols et posé — cohérent avec « personne pendant les vols », changement à dire au verdict.
⑥ CE QUE LE PAN NE RÉPARE PAS — Reachability et le 2ᵉ swipe (système, pour toujours) ; b2 résiduel (option de zone §2 ou option B, au doigt) ; le claquement de rattrapage du commit nav (moteur NavEtat, §4bis:586-592 — hors périmètre, à ne pas imputer au pan) ; le « lag » global de séance = C1/BordSeance (hypothèse `-sansBord` à prouver) — le pan supprime seulement le `saisir()` parasite ; un 2ᵉ doigt qui tape un glyphe pendant un repli reste possible (multitouch, préexistant, mineur).
⑦ LE BANC — NavEncreLab hérite du pan via PageCard (rien à faire) ; PageCardLab (:541) monte PageCard sans slot nav : le pan y route .repli vers une NavEtat sans nav visible — inoffensif, à savoir en capture. Après intégration : fouettage ultime COMPLET (la constante de la dalle du régime player+mini a bougé — plan J6 :957-962). Chaque jalon MONTRÉ avant commit (la règle de la maison).

## Les failles corrigées par l'adversaire

- **F1 — SÉVÈRE. L'ordre des modificateurs du snippet §9 rend le pan sourd à SON PROPRE geste : `.allowsHitTesting(!PlayerEtat.shared.monte)` est posé APRÈS `.background { PanBande }`, donc la porte couvre la UIView du pan. Or en mode .player, le premier `suivre` du pan appelle `saisir()` qui pose `monte = true` AU MILIEU du geste (PageCard relit `monte` dans body → ré-évaluation → hit-testing coupé sur le sous-arbre, pan compris). Si SwiftUI propage la coupure à `isUserInteractionEnabled` de la UIView, UIKit ANNULE le pan en vol : chaque drag d'ouverture meurt à ~10 pt (commit à v≈0 → p<0,2 → retour à 0) — le geste vedette cassé par sa propre porte. Même si ça survit sur cet iOS, c'est un comportement non documenté empilé sur le pari ④.**
  Correction : Inverser l'ordre : `.allowsHitTesting(!PlayerEtat.shared.monte)` sur le VStack de la bande AVANT `.background { PanBande }`. La porte ne couvre alors QUE le contenu SwiftUI (grabber, tap dalle, glyphes, stop) — exactement ce qu'on veut éteindre sous `monte` (le toucher-sous-le-noir §4ter:642-650 reste mort) — et le pan reste hors de sa portée : sa propre porte est `shouldReceive`, consultée uniquement À LA POSE d'un toucher, jamais en cours de geste. Aucune dépendance à un comportement non défini.
- **F2 — « a2 est couvert » est FAUX : la fenêtre du tap-qui-ouvre S'ÉLARGIT de 3 pt à ~10 pt. Une pose hésitante qui bouge de moins de ~10 pt (seuil interne d'UIPan) puis lève ne fait jamais commencer le pan → le `.onTapGesture` de la dalle (conservé) tire → OUVERTURE PLEINE. Aujourd'hui, un poke descendant de 3-10 pt déclenche le DragGesture(min 3) → flash de montage puis refermeture ; demain le même poke ouvre en grand. Le commentaire du snippet (« a2 est couvert par allowsHitTesting + le pan qui absorbe les micro-drags ») masque un résidu réel.**
  Correction : Le dire, pas le maquiller : le tap de la dalle est une affordance voulue, indiscernable d'un poke court sans tuer le tap. Le gain net réel à revendiquer : sous 10 pt plus AUCUN saisir() (le flash de montage 3 pt de a1/a2 meurt), et tout mouvement ≥ 10 pt vers le bas devient un repli propre. Résidu au verdict téléphone ; si Kathryn le sent, l'escalade propre existe (UITapGestureRecognizer maison sur la vue du pan avec require(toFail:) du pan) — à n'ouvrir que sur mesure.
- **F3 — Les deux modificateurs « au châssis » RATENT les PageCard présentées en fullScreenCover. Le chemin de la home présente ExercisesView (et sa fiche poussée) dans un cover imbriqué : un fullScreenCover = un AUTRE view controller — la préférence posée sur le ZStack de mainBody ne s'y applique pas. b1 (geste Home) et c1 (Reachability) resteraient vivants précisément sur ces écrans-là.**
  Correction : Poser `.defersSystemGestures(on: .bottom)` (et l'option `.persistentSystemOverlays(.hidden)` si Kathryn la valide) sur LA RACINE DE PageCard (le GeometryReader de body) : un seul endroit, la protection voyage avec la bande dans TOUS les contextes — onglet, push, cover, bancs. Le doublon avec HomeNuit:2495 est inoffensif. (PageCard = fichier de la session home : à la liste de coordination J1.)
- **F4 — Le mécanisme d'extinction des taps est MAL ATTRIBUÉ, et la ligne de sonde qui le prouverait MANQUE. « cancelsTouchesInView envoie touchesCancelled aux vues → les TapGesture enfants meurent » : cancelsTouchesInView ne coupe que la livraison aux VUES ; les gestes SwiftUI vivent dans des recognizers de la hosting view (ANCÊTRE) qui n'en sont pas affectés. Ce qui les tue, c'est l'exclusivité d'arène quand notre pan passe .began — SAUF si le delegate SwiftUI répond true à la simultanéité (il suffit qu'UN des deux delegates accepte ; notre false ne verrouille rien). Si le tap survit, un repli léger né sur un glyphe ferait repli ET navigation au lever — C3 déclaré mort sans l'être, en silence.**
  Correction : ① Ajouter la vérification manquante : drag vertical de 15-25 pt né SUR un glyphe → lignes NAV à la sonde, et au lever PAGE INCHANGÉE (NavEtat.page). ② Si le tap survit : escalade UIKit nommée — dans le delegate du pan, `gestureRecognizer(_:shouldBeRequiredToFailBy:)` → true pour les recognizers dont la vue est un ANCÊTRE de la vue du pan mais PAS la fenêtre (les recognizers SwiftUI attendent l'échec du pan — résolu au lever, zéro latence perçue ; le PanMaitre fenêtre et les gates système, posés sur la fenêtre, restent exclus).
- **F5 — Le repli fenêtre (si le pari ④ tombe) est une PHRASE, pas une conception. « L'école fenêtre pure avec garde de position dans la bande » ne dit ni comment on obtient la géométrie de la bande VISIBLE (les pages cachées d'un TabView ont une géométrie morte — l'argument §0 de la conception elle-même), ni la coexistence avec le PanMaitre fenêtre existant, ni la discipline anti-zombie. Or ④ est le pari technique central : son plan B doit être exécutable le jour même de l'échec de la sonde.**
  Correction : Spécifier le PLAN B complet (durcie §10bis) : même coordinateur, pan posé sur la FENÊTRE ; la UIView de bande reste montée en SONDE DE COORDONNÉES (isUserInteractionEnabled=false, l'école de PlayerMonde:759-763) ; porte shouldReceive enrichie d'une garde de position (le point du toucher converti dans la sonde, `bounds.contains`) — seule la bande VISIBLE contient le point ; retrait au démontage via dismantleUIView (l'école :652-663) ; coexistence inchangée (portes disjointes par shouldReceive). Bascule = un drapeau de build, mêmes zones, mêmes moteurs, mêmes signes.
- **F6 — Le `.contentShape(Rectangle())` de NavBande devient un ORPHELIN dangereux. La conception supprime `.gesture(tirage)` mais laisse la forme tactile pleine bande (sa seule raison d'être était le tirage). Gardée, elle maintient une surface interactive SwiftUI pleine largeur AU-DESSUS de la UIView du pan — précisément la configuration où le hit-test peut préférer la hosting view et affamer le pan (le pari ④ aggravé pour rien) — et elle n'attrape plus aucun geste.**
  Correction : Supprimer `.contentShape(Rectangle())` (:396) avec `tirage` (:420-430) et `ancre` (:432). Les cibles de glyphe gardent leurs contentShape 44 pt à elles (:327-328) ; le « doigt entre deux points » est désormais le travail de la UIView du pan — c'est ELLE la forme tactile pleine de la bande.
- **F7 — Un écart au plan est passé SOUS SILENCE : le routage nav-UP. §4.9 et J4 routent par DIRECTION seule (« haut → PlayerEtat.suivreDelta, bas → la nav » ; « haut → la dalle/le player »). À la lettre, un drag-up né sur la MINI NAV irait au player — le dépli mini→big serait impossible et b1 deviendrait « drag up sur la mini nav ouvre le player ». La conception route par ZONE+direction (juste), mais ne signale que l'écart dalle-down — alors que dalle-down→repli est en fait CONFORME au plan (« bas → la nav ») et que le vrai écart est nav-up→dépli. Règle de la maison : tout écart s'expose.**
  Correction : Exposer les DEUX lignes de routage et leur justification dans la conception montrée (durcie §3) : départ dalle + bas → repli (conforme au « bas → la nav » du plan, tue a1) ; départ nav/grabber + haut → dépli (écart à la lettre de §4.9/J4, seul routage compatible avec « mini → big au drag ») ; mettre §4.9/J4 à jour dans le commit du code.
- **F8 — Résidu non dit : le CLAQUEMENT DE RATTRAPAGE du commit nav n'est pas réglé par le pan. Re-saisir pendant le commit 0,25 s : `rAncre = NavEtat.r` lit la valeur DÉJÀ à la cible (mini flippe instantanément sous withAnimation) pendant que l'écran est à mi-vol → l'écriture sèche fait SAUTER le dessin. C'est exactement le bug 2 que §4bis prédit pour tout withAnimation sur une valeur suivie — il est DANS NavEtat.poser aujourd'hui, et le pan le laisse. Au fouettage, ce claquement serait imputé au pan.**
  Correction : Hors périmètre du pan (c'est le moteur NavEtat ; course 34 pt, fenêtre 0,25 s — rarement senti) mais À ÉCRIRE dans les risques pour que le verdict téléphone ne l'impute pas au pan ; le fix éventuel est connu et payé : le tween possédé, l'école du player (PlayerMonde §3.4decies F1).
- **F9 — Imprécisions de chaînes (aucune ne renverse un verdict) : a1① « le pouce se pose naturellement vers 100-150 pt » est une rationalisation — la preuve réelle est le symptôme de Kathryn lui-même plus l'absence de toute frontière visible dalle/nav (deux noirs, aucun trait) ; b2 « le commit du dépli n'aurait demandé qu'un flick de −140 ou 34 pt de course » — en réalité ~8 pt suffisent (depuis mini, suivi < 0,78 ⇔ 0,22 × 34 ≈ 7,5 pt) : le contraste raté/réussi est encore plus violent que dit ; d3 sous-vend le pan : au vol système, un recognizer UIKit reçoit un `.cancelled` IMMÉDIAT → commit à la vélocité du vol, le flottement de 0,4 s ne reste qu'en filet — le pan AMÉLIORE d3, la conception ne le revendique pas ; et la conception ne revendique pas non plus qu'elle SUPPRIME le suspect n°3 du FIX 2 du plan (« la nav prend le doigt sous le player ouvert ») : tirage supprimé + porte !monte = suspect mort par construction.**
  Correction : Intégré à la durcie : a1① reformulé (frontière invisible + symptôme comme preuve), b2 chiffré à ~8 pt, d3 et FIX 2 revendiqués comme gains du pan.
- **F10 — Plomberie oubliée, trois points : (a) `descente = safeBottom > 0 ? 18 : 0` est impossible tel quel — `descente` est une computed property SANS accès aux insets (lus dans body seulement) : il faut la paramétrer par `g.safeAreaInsets.bottom` et propager à `bandeH` — une vraie retouche PageCard à lister pour la coordination J1 ; (b) les cotes de zone (grabH 18, dalleH 76) sont RECOPIÉES dans le Coord alors que la doctrine du dépôt est « une seule fonction, pas deux calculs qui divergent » ; (c) le fichier nouveau doit entrer dans le target Xcode.**
  Correction : (a) listé dans les retouches PageCard de la durcie ; (b) un `enum BandeCote { grab = 18, dalle = 76 }` dans PanBande.swift, consommé par le Coord ET par PageCard (deux lignes dans la retouche déjà prévue) ; (c) une ligne de checklist build.

---

## ÉCARTS ASSUMÉS À L'IMPLÉMENTATION (03-09, relecture lot 1 passée)

1. **SE hors périmètre** : la plomberie `descente = safeBottom > 0 ? 18 : 0`
   (§7-②, F10-a) n'est PAS faite — verdict de Kathryn du 02-09 : « pour le SE
   on verra plus tard ». La descente reste inconditionnelle ; à faire le jour
   où le SE entre au périmètre.
2. **F6 amendé** : le `.contentShape(Rectangle())` de NavBande SURVIT — il a
   gagné une nouvelle raison d'être après la conception : le TAP-DÉPLOIE de
   l'item 11 (en mini, tout tap sur la bande déploie). Le `tirage` et `ancre`
   sont bien morts. Risque pari ④ noté, tranché à la sonde.
3. **La lune** : sa prise n'est plus branchée (élastique mort). Décision de
   Kathryn en attente (mort actée + nettoyage, ou re-logement sur une zone du
   pan) — exposée au rapport du lot 1, rien supprimé en attendant.
4. **Bouclier complété hors PageCard** : Profil (pas de PageCard) reçoit la
   paire au châssis ; les covers MoisIpod et CoffreV2Page reçoivent la leur
   (grief sérieux de la relecture).
