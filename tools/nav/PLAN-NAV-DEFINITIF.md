# LE PLAN DEFINITIF DE LA NAV — workflow nav-definitif (03-09, opus + adversaire)

Verdict adversaire : **tient-avec-corrections**. IMPLEMENTE le 03-09 au soir (etapes 1-3). Le banc XCUITest (fouettage nav) est la porte du verdict.

## Le gel

- Cause probable : Aucune boucle d'update DÉTERMINISTE n'existe dans lot 1 (je l'ai vérifié, pas déduit) : le seul motif qui pourrait geler — le pont bidirectionnel selection<->NavEtat.page dans WoopApp — est GARDÉ des deux côtés et bijectif, donc il termine. Le gel DUR observé (celui du revert) appartenait au lot geste-système reverté (bouclier RACINE + tap grabber + inset), pas à lot 1. Le plus fort risque de gel RUNTIME qui SUBSISTE dans lot 1 est la tempête de préférence SwiftUI 'Bound preference tried to update multiple times per frame' : lot 1 AJOUTE .defersSystemGestures(on:.bottom) + .persistentSystemOverlays(.hidden) au niveau de PageCard, alors que les pages hôtes les déclarent DÉJÀ (Home) et que Profil les redéclare une 3e fois — soit la MÊME préférence posée à plusieurs niveaux imbriqués, sur 4 onglets tous en .toolbarVisibility(.hidden) et TOUS maintenus montés par le TabView. C'est exactement le motif multi-niveaux signalé comme déclencheur de gel. HONNÊTETÉ / CALIBRAGE : les valeurs sont CONSTANTES (.hidden / .bottom), donc ce motif produit plus vraisemblablement une agitation de résolution qu'un blocage PERMANENT du fil principal — il doit être CONFIRMÉ sur téléphone (console) avant d'être peint comme prouvé. Tant qu'il n'est pas mesuré, je ne peux pas affirmer qu'il gèle : je dis qu'il PEUT geler et que c'est le suspect n°1 restant.
- Preuve : AJOUTS lot 1 (git diff HEAD) : PageCard.swift:160-161 (.defersSystemGestures(on:.bottom) + .persistentSystemOverlays(.hidden) posés sur le corps de PageCard — lignes '+') ; WoopApp.swift:1114-1115 (les MÊMES deux modificateurs sur Profil, qui n'a pas de PageCard). DÉJÀ présents chez l'hôte AVANT lot 1 : HomeNuit.swift:2495 (.defersSystemGestures sur HomeNuitPage, qui CONTIENT la PageCard de HomeNuit.swift:~2489) → double déclaration imbriquée pour Home ; convention .persistentSystemOverlays(.hidden) partout (grep : ~40 sites). Les 4 onglets sont montés+toolbar cachée : WoopApp.swift ~1072 (Home .toolbarVisibility(.hidden,.tabBar)), ~1086 (Exercices), ~1099 (Progrès), ~1101-1115 (Profil) ; le TabView garde les onglets visités montés (constaté dans ANALYSE-CHAUFFE-GESTES.md:7, WoopApp.swift:1064-1099). MÉCANISME : une préférence re-émise par des sous-arbres qui se ré-évaluent (TimelineView comète 30 Hz PageCard.swift:317 via WorkoutPill.swift:489, calques vidéo) sur plusieurs niveaux imbriqués → contention de résolution de préférence sur le fil principal. NON-CAUSES vérifiées : WoopApp onChange(of:NavEtat.shared.page)+onChange(of:selection,initial:true) gardés (selection!=cible / page!=d), bijectifs → terminent (confirmé sec ANALYSE-CHAUFFE-GESTES.md:96) ; PanBande.swift:143 updateUIView n'écrit qu'un Bool, pas de cycle ; PageCard.swift:205 .allowsHitTesting(!monte) = lecture seule ; NavEtat.armerChien (NavEncre.swift ~215) re-arme seulement si enSuivi, pas de boucle serrée.
- Fix : Dé-dupliquer la préférence système : la poser à UN SEUL niveau et jamais l'imbriquer. Concrètement — RETIRER .defersSystemGestures/.persistentSystemOverlays de PageCard.swift:160-161 (le composant partagé ne doit pas re-déclarer une préférence que ses hôtes portent déjà) et les déclarer UNE fois au châssis racine (au niveau du TabView dans WoopApp, hors des onglets), en supprimant aussi les copies par-page (HomeNuit.swift:2495 et la paire Profil WoopApp.swift:1114-1115 deviennent inutiles une fois la racine couverte). Une préférence, un seul émetteur, zéro imbrication. PUIS VÉRIFIER, ne pas déduire : lancer sur le TÉLÉPHONE (les gestes/gel se jugent au doigt, pas au simulateur) et surveiller la console Xcode pour 'tried to update multiple times per frame' — l'absence du message confirme que ce n'était pas la cause ; sa présence + le fil bloqué le prouve. Ne repeindre l'état 'gel réglé' qu'après cette lecture.
- Autres suspects : 2) CONTENTION DE TRANSITION (gel PERÇU, pas permanent) : la bascule d'onglet est un double withAnimation (aller() anime etat.page 0,38 s NavEncre.swift:440-442, puis le pont anime selection 0,30 s WoopApp.swift ~1122) pendant que le TabView COMPOSE les deux pages, et le premier montage d'un onglet crée du lourd (Progress : 2 AVQueuePlayer+Looper+preroll ProgressPage.swift). Sur un fil principal saturé -> plusieurs secondes d'app non réactive = 'gel' ressenti. Fortement MITIGÉ par lot 1 (gating ongletCache + cellier AssetsVideo pour Exercices). Réel mais transitoire. 3) LE PONT BIDIRECTIONNEL selection<->NavEtat.page : je l'ai EXAMINÉ en priorité (c'est le motif classique de gel) et je l'ÉCARTE — gardé des deux côtés + bijectif -> termine (WoopApp onChange x2 ; ANALYSE-CHAUFFE-GESTES.md:96). 4) PanBande en .background sous .allowsHitTesting(!monte) (PageCard.swift:205 + PanBande.swift:58) : problème de HIT-TEST (le drag peut ne pas atteindre le pan, ou la nav devient inerte quand monte=true) — c'est le soupçon B, PAS un gel : aucune écriture d'état, updateUIView trivial. 5) .animation(value:dockH) (PageCard.swift ~239) + bounds animés du UIView en .background pendant les 0,25 s de poser() : re-mesure par image le temps de l'anim -> chaleur bornée, pas un blocage permanent.

## Les cartes etat x geste

### hors-seance

HIT-TESTING : VERDICT : le pan en .background NE reçoit PAS le drag sur la nav ni sur la dalle — il n'est atteint QUE sur le grabber (18 pt), zone que l'offset a de surcroît déplacée hors du grabber visible. C'est la cause première de « le drag ne fait rien ». Confiance : haute (lecture + lois payées) ; jamais mesuré sur device (l'aveu est dans le code, PanBande.swift:132-135, « prouvé à la sonde au premier build » = PAS ENCORE FAIT).

PREUVE. Ordre de hit-test SwiftUI = avant vers arrière. Là où le contenu de devant revendique le point par contentShape, il gagne ; le .background est derrière. (a) NAV : NavBande a .contentShape(Rectangle()) + .onTapGesture (NavEncre.swift:425-428) -> elle capte tout point de la nav. Sur un DRAG, son TapGesture échoue (mouvement) et son onTapGesture ne tire pas ; mais le toucher a été revendiqué par le contenu de DEVANT, donc la hit-view n'est ni la UIView de PanBande ni un de ses descendants. Le UIPanGestureRecognizer de PanBande n'est donc pas dans la chaîne de répondeurs de la hit-view -> il ne reçoit jamais le drag. Loi payée : « entre frères SwiftUI aucune passation » — un contentShape de devant qui revendique n'offre AUCUN repli au frère de fond. (b) DALLE : même contentShape + onTapGesture (PageCard.swift:187-191) -> même affamement ; en séance, seul le TAP ouvre le player, le drag descendant censé router au repli (PanBande mode .repli, PanBande.swift:72) est mangé -> d'où le grief « en séance impossible mini<->nav, ça ouvre le player ou rien ». (c) GRABBER : seul élément SANS contentShape ni geste (PageCard.swift:175-179) -> les touchers y tombent jusqu'à la UIView de PanBande, la hit-view EST alors le pan, et lui SEUL reçoit le drag. C'est pourquoi le drag « marche parfois » (depuis le trait) et « ne fait rien » ailleurs.

AGGRAVANT (offset). La bande est .offset(y:18) (PageCard.swift:124) alors que le grabber fait 18 pt (grabH=18). Le grabber est donc DESSINÉ exactement dans les 18 pt SOUS sa propre boîte de layout — zéro chevauchement avec sa zone tactile de fond. Loi payée 39f95f9 : « .offset déplace les pixels, PAS la zone tactile ». Conséquence : la seule zone qui atteint le pan (grabber, sans contentShape) risque de vivre 18 pt AU-DESSUS du grabber visible, dans le bas visuel de la card ; et le grabber qu'on VOIT recouvre la zone tactile de la nav (contentShape affamante). Réserve : cet offset porte AUSSI la UIView représentable, qui peut suivre le transform ; à défaut de mesure device je le classe suspect fort, pas certitude — mais il ne change rien au verdict principal (a/b), qui tient sans lui.

DIRECTION DE FIX (hors périmètre, mais dicté par la preuve) : le propriétaire du drag doit être DEVANT les taps SwiftUI (une UIView plein-cadre en overlay, pas en .background), OU porter pan ET taps sur la MÊME UIView (les taps ré-exprimés en UITapGestureRecognizer requérant l'échec du pan), de sorte que le doigt tombe toujours sur la vue du pan quelle que soit la zone ; et supprimer le contentShape-tap-seul de NavBande/dalle qui affame, ou lui accorder la reconnaissance simultanée. Enfin retirer l'offset(18) ou déplacer la zone tactile avec lui.

- [E1 nav deployee | Tap sur un glyphe | ok] NavEncre.cible highPriorityGesture(TapGesture)->onChoix->aller(d) ; pas mini, page!=d -> NavEtat.page change + pont onChange (WoopApp:1144) porte a selection. Navigue. -> Un tap sur l'icone navigue vers l'onglet.
- [E1 nav deployee | Drag bas DEPUIS LE GRABBER | ok] Grabber sans contentShape -> tombe au pan (PanBande). shouldBegin: |y|>=|x| ok ; zone=.grabber, mode=.repli, rAncre=NavEtat.r=0. suivre: NavEtat.suivre 0->1, la nav se serre sous le doigt. commettre: mini=false -> cible=(v>300||suivi>0.45) -> mini=true, la card s'allonge en 0,25 s. MARCHE. -> Drag bas -> mini + card allongee.
- [E1 nav deployee | Drag bas DEPUIS LE CORPS DE LA NAV (la vraie cible) | casse] contentShape de NavBande (NavEncre:425) capte le point ; le pan en .background est AFFAME (verdict hit-test). Le TapGesture echoue (drag), onTapGesture ne tire pas et ne fait rien hors mini. RESULTAT : RIEN. -> C'est LA cible naturelle du repli : drag bas -> mini + card allongee.
- [E1 nav deployee | Drag haut depuis le grabber | ok] Pan .repli, rAncre=0, delta<0 -> brut<0 -> suivi=0.06*tanh(...) ~ rebond elastique negatif borne ; commettre: mini=false, cible=(v>300||suivi>0.45)=false -> reste deployee. -> Deja deployee : petit rebond elastique puis rien.
- [E1 nav deployee | Drag haut depuis le corps de la nav | ambigu] Pan affame (contentShape). RIEN. -> Deja deployee -> l'inaction est acceptable, mais ici pour la mauvaise raison (le geste n'atteint jamais l'arbitre).
- [E1 nav deployee | Drag oblique depuis le grabber | ok] shouldBegin exige |t.y|>=|t.x| (PanBande:69). Horizontal dominant -> refus, toucher RENDU intact (pas de touchesCancelled). Vertical dominant -> route au repli. -> Rejet propre du lateral, sans voler le toucher.
- [E1 nav deployee | Tap sur le grabber | peu-naturel] Grabber sans geste ; le pan exige un mouvement -> un tap immobile ne declenche rien. RIEN. -> Un trait de prise invite un tap pour basculer, ou au moins un feedback ; ici muet.
- [E2 mini (points) | Tap sur la nav / un point | ok] NavBande.onTapGesture { if mini { etat.poser(false) } } (NavEncre:426) ; aller() aussi garde mini->poser(false). Redeploie. MARCHE (c'est le seul geste que ni systeme ni player ne volent, item 11). -> Tap sur la mini -> redeploie.
- [E2 mini (points) | Drag haut DEPUIS LE GRABBER (redeployer) | ok] Pan .repli, rAncre=r=1, delta<0 -> suivi 1->0, la nav se redeploie sous le doigt ; commettre: mini=true -> cible=!(v<-140||suivi<0.78) -> deploie. MARCHE. -> Drag haut -> redeploie.
- [E2 mini (points) | Drag haut DEPUIS LA NAV (redeployer) | casse] Les glyphes en opacity 0 gardent leur hit + le contentShape de l'hote capte -> pan AFFAME. Seul le TAP redeploie ; le DRAG haut ne fait RIEN. -> Drag haut sur les points -> redeploie (comme au grabber).
- [E2 mini (points) | Drag bas (deja mini) | peu-naturel] Depuis grabber: pan .repli, suroverse elastique bornee (tanh), revient mini. Depuis la nav: affame -> rien. -> Rebond elastique dans les deux cas.
- [E2 mini (points) | Tap sur le grabber | peu-naturel] Grabber sans geste -> RIEN (le tap-pour-redeployer n'est cable QUE sur NavBande, pas sur le grabber). -> En mini, tout tap sur la bande devrait redeployer, grabber compris.
- [Transitions (tous etats) | Relacher apres un repli/depli (fin de course) | peu-naturel] commettre->poser() = withAnimation(.easeInOut duration:0.25) a DUREE FIXE (NavEncre:173-179). Ne prolonge PAS la vitesse du doigt. -> La fin de course continue la vitesse de la main (recette player: fin = 3*distance/vitesse) — 'comme de l'eau'.
- [Transitions (tous etats) | Drag interrompu / mort sans onEnded (vol systeme, presentation) | ok] PanBande gere .cancelled/.failed -> commit immediat a la velocite (PanBande:87-99) ; filet: chien NavEtat 0.45 s (NavEncre:182-193). Couvert. -> Ne jamais rester bloque a mi-course ; commit a l'etat stable le plus proche.
- [Global (geometrie) | Toucher le grabber VISIBLE | casse] bande .offset(y:18) avec grabH=18 : le grabber est DESSINE exactement sous sa boite de layout (zero chevauchement). Loi payee 39f95f9: l'offset deplace les pixels, pas la zone tactile. Le grabber qu'on voit recouvre la zone tactile de la nav (contentShape affamante) ; la seule zone atteignant le pan est ~18 pt plus haut, dans le bas visuel de la card. Reserve: la UIView representable peut suivre le transform (non mesure device). -> La zone tactile du grabber = le grabber visible.

### en-seance

HIT-TESTING : VERDICT : le pan en .background NE reçoit PAS le drag sur la nav ni sur la dalle — il est GOBÉ par les contentShape SwiftUI de devant. Il ne reçoit QUE sur la bande transparente du grabber. C'est la cause directe de « le drag ne marche pas ». Verdict de LECTURE (device non mesurable ici), mais mécaniquement certain.

PREUVE (chaîne de lois payées) :
1) Le pan vit DERRIÈRE. PageCard.swift:206 pose `.background { PanBande(...) }` sous le VStack {grabber, dalle, nav}. PanBande.swift:130-142 : UIPanGestureRecognizer sur une UIView qui, par construction de `.background`, est un FRÈRE placé DERRIÈRE le contenu (jamais un ancêtre de la nav/dalle).
2) La nav couvre TOUTE sa surface en avant. NavEncre.swift:425 `.contentShape(Rectangle())` sur NavBande (frame height navH) + `.onTapGesture` (426-428). La dalle pareil : PageCard.swift:187 `.contentShape(Rectangle())` + `.onTapGesture` (188-191), sur toute sa hauteur (76).
3) Loi UIKit : un UIPanGestureRecognizer ne voit un toucher que si la vue hitTest est SA vue ou une DESCENDANTE. Sur la nav/dalle, le hitTest résout vers le contenu SwiftUI interactif de DEVANT ; le pan (frère derrière) n'est pas dans la chaîne d'ancêtres du hit → il n'est jamais consulté, MÊME si le tap échoue ensuite parce que le doigt bouge. D'où : drag sur nav = RIEN ; drag sur dalle = RIEN (seul le TAP passe, via onTapGesture).
4) Le grabber est la SEULE fenêtre qui laisse passer : PageCard.swift:175-179, une Capsule 36×4 SANS contentShape ni geste dans une frame de 18 pt — le reste de la bande du grabber est transparent, le toucher retombe sur la UIView du pan → zone=.grabber → mode=.repli fonctionne. C'est pourquoi le repli « marche parfois » (au grabber) et « jamais » là où la spec le veut (sur la nav, sur la dalle).

CONSÉQUENCE DE CONCEPTION : l'architecture est à l'envers. Le propriétaire du drag doit être DEVANT (ou être la couche interactive elle-même), pas un .background. Tant que la nav et la dalle gardent un contentShape plein en avant d'un pan en fond, aucun réglage de zones/seuils dans PanBande ne servira : la moitié des cases de la matrice est morte à la racine.

ASIDE GEL (suspect A, hors schéma mais load-bearing) : deux restes du lot bouclier sont ENCORE dans lot 1 — PageCard.swift:160-161 `.defersSystemGestures(on:.bottom)` + `.persistentSystemOverlays(.hidden)` posés sur CHAQUE PageCard, or le TabView garde les 4 pages montées en même temps (4 émetteurs de préférence système simultanés) : candidat n°1 à la tempête « update multiple times per frame ». À remonter au châssis racine (une seule fois), pas par page. Second point mineur : `.allowsHitTesting(!monte)` (PageCard.swift:205) est appliqué AVANT `.background`, donc il ne couvre PAS le pan — seul `shouldReceive` (PanBande.swift:58) le garde en E5 ; asymétrie à connaître, pas un gel.

- [E3 séance · nav déployée · player fermé | tap sur la dalle | ok] onTapGesture → PlayerEtat.ouvrir() (PageCard.swift:188-191) → player monte (tween 0.68, PlayerMonde.swift:57-70) -> ouvrir le player
- [E3 séance · nav déployée · player fermé | drag HAUT depuis la dalle | casse] GOBÉ par le contentShape de la dalle (PageCard.swift:187) ; onTapGesture ne se déclenche pas sur mouvement → RIEN. Le routage prévu dalle+haut→player (PanBande.swift:71-72) est mort -> ouvrir le player au doigt (continuer la vitesse de la main)
- [E3 séance · nav déployée · player fermé | drag BAS depuis la dalle | casse] GOBÉ par le contentShape de la dalle → RIEN. Routage prévu dalle+bas→repli (PanBande.swift:72) mort -> replier la nav (mini) sans ouvrir l'overlay
- [E3 séance · nav déployée · player fermé | drag BAS depuis la nav | casse] GOBÉ par NavEncre.swift:425 contentShape ; onTapGesture (426) ne fire pas sur mouvement → RIEN -> nav → mini + la card s'allonge (au relâcher, poser(true), NavEtat.swift:173)
- [E3 séance · nav déployée · player fermé | drag BAS depuis le grabber | ok] passe au pan (zone transparente) → mode .repli (PanBande.swift:65-75) → NavEtat.suivre/commettre → mini + card allongée. SEUL drag de repli qui marche -> nav → mini + card allongée
- [E3 séance · nav déployée · player fermé | tap sur une icône nav | ok] NavEncre cible.highPriorityGesture(Tap) → onChoix → aller(d) → navigation (NavEncre.swift:452-465) -> changer d'onglet
- [E3 séance · nav déployée · player fermé | tap sur le grabber (capsule ou strip) | peu-naturel] aucun geste sur le grabber → RIEN -> acceptable (le grabber est une poignée de drag) ; un tap pourrait basculer mini
- [E4 séance · nav MINI · player fermé | tap n'importe où sur la bande nav | ok] NavBande.onTapGesture → if mini poser(false) (NavEncre.swift:426-428) → redéploie -> redéployer la nav
- [E4 séance · nav MINI · player fermé | tap là où une icône invisible se trouve | ok] cible.highPriorityGesture → aller → guard mini → poser(false) (NavEncre.swift:456-459) → redéploie -> redéployer (ne pas naviguer sur une cible invisible)
- [E4 séance · nav MINI · player fermé | drag HAUT depuis la nav | casse] GOBÉ par le contentShape ; le tap ne fire pas sur mouvement → RIEN (mais un TAP, lui, redéploie) -> redéployer au doigt (mini→grosse continu)
- [E4 séance · nav MINI · player fermé | drag HAUT depuis le grabber | ok] passe au pan → .repli → NavEtat.suivre (mini→déployé), commettre asymétrique (NavEtat.swift:158-164). SEUL drag de dépli qui marche -> redéployer au doigt
- [E4 séance · nav MINI · player fermé | tap sur la dalle | ok] onTapGesture → ouvrir() (dalle toujours présente en séance) -> ouvrir le player
- [E5 player OUVERT | tout geste sur la bande (tap/drag) | ok] foreground inerte (allowsHitTesting(!monte)=false, PageCard.swift:205) ET pan refusé (shouldReceive=!monte, PanBande.swift:58) ; le PlayerMondeHote au-dessus (WoopApp.swift:1311, zIndex 8.5) gère seul (drag bas → fermer) -> la bande est neutralisée, le player possède le geste
- [E6 exercice EN COURS | tout geste en bas | ok] bandeVisible=false (ExerciseDetailView.swift:618) → le bloc `if bandeVisible { bande }` (PageCard.swift:122-125) n'est pas rendu → aucune bande, aucun pan, aucune nav -> bande masquée pendant l'exercice — conforme
- [Transition · commit du repli | relâcher après drag grabber | peu-naturel] NavEtat.commettre → poser() withAnimation(.easeInOut 0.25) (NavEtat.swift:173-179) ; PageCard a .animation(0.25, value:dockH) (PageCard.swift:239) pour que la card ne SAUTE pas -> la fin de course doit PROLONGER la vitesse du doigt (modèle player : 3·dist/vitesse, PlayerMonde.swift:256-267), pas une durée fixe
- [Transition · seuils de commit | relâcher (élan) | ambigu] seuils asymétriques codés (NavEtat.swift:155-166) mais course=34 (NavEtat.swift:197) jamais mesurée au téléphone (commentaire l.152-154) -> seuils calés au doigt sur device
- [Transition · geste interrompu (doigt perdu / cancelled système) | drag depuis grabber avorté | ok] PanBande gère .cancelled/.failed → commettre(velocite) (PanBande.swift:87-99) + chien de garde NavEtat 0.45s (NavEtat.swift:182-194). Robuste -> toujours commettre à l'état stable le plus proche
- [E3/E4 · drag OBLIQUE depuis grabber | drag diagonal | peu-naturel] PanBande.shouldBegin refuse si |t.x|>|t.y| (PanBande.swift:69) → toucher rendu intact → RIEN (aucun geste horizontal n'existe) -> un geste à dominante verticale devrait quand même replier

## L'architecture

MODÈLE UNIFIÉ — « le pan maître du player, posé sur la bande ». Un SEUL propriétaire du drag vertical du bas : un UIPanGestureRecognizer AU NIVEAU DE LA FENÊTRE (le patron EXACT et PAYÉ de PlayerMonde.PanMaitre, PlayerMonde.swift:646-789), coopératif (shouldRecognizeSimultaneouslyWith→true), qui décide zone+direction depuis le POINT DE POSE. Les TAPS restent des gestes SwiftUI (glyphes→aller, dalle→ouvrir, mini→déployer). C'est un PAN + DES TAPS, jamais un recognizer unique.

POURQUOI CE VIRAGE (la cause première, LUE) : le pan actuel vit en .background (PageCard.swift:206), DERRIÈRE le VStack {grabber, dalle, nav}. Loi UIKit : un UIPanGestureRecognizer ne voit un toucher que si la hit-view est SA vue ou une descendante. Or NavBande revendique tout son cadre par .contentShape(Rectangle()) + onTapGesture (NavEncre.swift:425-428) et la dalle pareil (PageCard.swift:187-191). Le pan de fond n'est donc dans la chaîne du hit QUE sur le grabber (Capsule sans contentShape, PageCard.swift:175-179). Résultat mécaniquement certain : « le drag ne fait rien » sur la nav et sur la dalle — la moitié de la matrice est morte à la racine. Aucun réglage de zones/seuils dans un pan en .background ne la ressuscite.

DÉCISION (a) — fenêtre, PAS overlay-devant, PAS .background. Un overlay devant ne peut pas à la fois LAISSER PASSER les taps ET capter les drags sur son propre recognizer : une UIView à isUserInteractionEnabled=false laisse passer les taps mais son recognizer ne reçoit alors plus rien ; à true elle devient hit-view et affame les taps derrière. La seule sortie est le recognizer sur la FENÊTRE (elle voit TOUS les touchers quelle que soit la hit-view) + une SONDE non-interactive pour la géométrie — exactement PlayerMonde.swift:759-764 (sonde v.isUserInteractionEnabled=false) + :766-784 (pan ajouté à la fenêtre). On GARDE donc .background { PanBande(...) } (PageCard.swift:206) : la UIView n'est plus qu'une SONDE qu'on ne touche jamais — sa place n'a plus d'importance, seul son rect converti en fenêtre sert.

DÉCISION (b) — cohabitation sans vol, sans gel. Trois garde-fous : ① simultaneous→true : les recognizers de tap tournent indépendamment ; ② le pan ne devient actif qu'APRÈS un seuil de mouvement (~6 pt) — un tap pur ne l'arme jamais ; ③ même armé sur un drag, le tap de l'élément a déjà échoué (mouvement) → zéro double-action. Le drag n'écrit que du DESSIN (NavEtat.suivi/PlayerEtat.p), jamais du layout sous le doigt (la loi §0bis, NavEncre.swift:88-103 reste intacte).

DÉCISION (c) — système tenu par CONCEPTION, dit honnêtement. Reachability (down-swipe bord) et Home (up-swipe bord) sont NON désactivables (É5, loi payée) : defersSystemGestures ne fait que DIFFÉRER. Trois parades cumulées : ① GÉOMÉTRIE — la porte du pan (shouldReceive) REFUSE tout toucher né dans les ~safeAreaInsets.bottom du bas de la bande ; ② le TAP immobile de dépli (NavBande onTapGesture, NavEncre.swift:426) reste dispo PARTOUT, jamais volé ; ③ defersSystemGestures(on:.bottom) conservé mais UNE seule fois au châssis. On ne survend jamais : on ne peut pas abolir le geste système, on le dé-priorise.

DÉCISION (d) — fluidité comme le player (voir champ « fluidite »).

FIX GEL (suspect A, à confirmer console) : dé-dupliquer la préférence système. Elle est posée à PLUSIEURS niveaux imbriqués sur 4 onglets tous montés par le TabView : PageCard.swift:160-161 (×4 pages), WoopApp.swift:1114-1115 (Profil), HomeNuit.swift:2495 (Home, qui l'a alors DEUX fois avec PageCard). Motif classique de « Bound preference tried to update multiple times per frame ». Fix : RETIRER de PageCard.swift:160-161 (un composant partagé ne re-déclare pas une préférence de ses hôtes) et poser UNE fois au niveau du TabView (WoopApp.swift:1064, HORS des onglets) ; supprimer HomeNuit.swift:2495 et WoopApp.swift:1114-1115 devenus inutiles. La séance vit à la racine (« la route quitte le fullScreenCover pour un hôte à la racine », DepartSeance.swift:53) donc la racine la couvre ; les covers (Story/Coffre) gardent LEUR propre déclaration (déjà présente, ex. CoffreV2.swift:2824). Un émetteur, zéro imbrication.

## Par etat

Le pont selection⇄NavEtat.page (WoopApp.swift:1144-1154) est gardé des deux côtés et bijectif → il TERMINE, ce n'est pas la boucle de gel. active→mini one-shot (WoopApp.swift:1159-1161) OK.

E1 — HORS SÉANCE, NAV DÉPLOYÉE
· Tap glyphe → NavEncre.aller (NavEncre.swift:452-465) → navigue. OK (inchangé).
· Drag BAS depuis le CORPS de la nav (la vraie cible, aujourd'hui CASSÉ) → le pan fenêtre voit le toucher (il n'est plus derrière le contentShape), zone=.nav, mode=.repli, NavEtat.suivre 0→1 sous le doigt, la nav se serre ; relâcher → commettre avec ÉLAN → mini + la card s'allonge. RÉPARÉ.
· Drag BAS depuis le grabber → identique (zone=.grabber). OK.
· Drag HAUT (déjà déployée) → rebond élastique borné (tanh, NavEncre.swift:136-142) puis rien. OK.
· Drag oblique → shouldBegin exige |ty|>|tx| sinon mort=true, toucher RENDU (pas de touchesCancelled). OK.

E2 — HORS SÉANCE, NAV MINI (points)
· Tap n'importe où sur la bande → NavBande.onTapGesture → poser(false) redéploie (NavEncre.swift:426-428). OK — c'est le geste que NI système NI player ne volent.
· Drag HAUT depuis la NAV (aujourd'hui CASSÉ) → pan fenêtre, zone=.nav, mode=.repli, rAncre=r=1, suivi 1→0, redéploie sous le doigt + élan. RÉPARÉ.
· Drag HAUT depuis le grabber → identique. OK.
· Drag BAS (déjà mini) → sur-course élastique bornée, revient mini. OK.

E3 — SÉANCE, NAV DÉPLOYÉE, PLAYER FERMÉ
· Tap dalle → PlayerEtat.ouvrir() (PageCard.swift:188-191). OK.
· Drag HAUT depuis la DALLE (aujourd'hui CASSÉ) → zone=.dalle & ty<0 → mode=.player → PlayerEtat.suivreDelta → le player s'ouvre AU DOIGT (et hérite de l'élan payé du player). RÉPARÉ.
· Drag BAS depuis la DALLE (aujourd'hui CASSÉ) → zone=.dalle & ty>0 → mode=.repli (JAMAIS le player) → nav→mini. RÉPARÉ — c'est le fix direct de « ça ouvre le player quand je veux replier ».
· Drag BAS depuis la NAV (aujourd'hui CASSÉ) → zone=.nav → mode=.repli → mini + card allongée SOUS le player. RÉPARÉ.
· Drag depuis le grabber → .repli. OK.
· Tap icône → navigue. OK.

E4 — SÉANCE, NAV MINI, PLAYER FERMÉ
· Tap partout sur la bande → poser(false) redéploie. OK.
· Drag HAUT depuis la NAV (aujourd'hui CASSÉ) → .repli → mini→grosse au doigt + élan, SANS ouvrir l'overlay. RÉPARÉ.
· Tap dalle → ouvrir(). OK.

E5 — PLAYER OUVERT
· Bande neutralisée : les taps SwiftUI par allowsHitTesting(!monte) (PageCard.swift:205) ; le pan fenêtre par shouldReceive=!monte. Le PlayerMondeHote (zIndex 8,5, PlayerMonde.swift:306-309) possède seul le geste (drag bas→fermer). Les deux pans fenêtre (player + nav) coexistent mais leurs portes sont DISJOINTES (player=ouvert, nav=!monte) → jamais deux acceptent. OK.

E6 — EXERCICE EN COURS
· bandeVisible=false → le bloc if bandeVisible {bande} (PageCard.swift:122-125) n'est pas rendu → la SONDE se démonte → dismantleUIView RETIRE le pan de la fenêtre (patron PlayerMonde.retirer, PlayerMonde.swift:657-662,786-788) → aucune bande, aucun pan. Conforme.

## La fluidite

LE DÉFAUT (É7, LU) : le commit du repli est withAnimation(.easeInOut duration:0.25) à durée FIXE (NavEtat, NavEncre.swift:173-179) — il n'imite pas la recette PAYÉE du player, où la fin de course PROLONGE la vitesse du doigt : durée = 3·distance/vitesse, parce que la pente initiale d'un easeOut cubique vaut 3·distance/durée (PlayerMonde.swift:256-267). D'où « pas comme de l'eau ».

CE QU'ON GARDE : le SUIVI est déjà SEC (NavEtat.suivre écrit suivi sans withAnimation, NavEncre.swift:131-144) — c'est bon, on n'y touche pas. Le régime « layout au relâcher, jamais sous le doigt » (NavEncre.swift:88-103) reste SACRÉ.

CE QU'ON CHANGE — trois gestes seulement, tous dans NavEtat :

1) r LIT LE SUIVI PENDANT LE VOL. Aujourd'hui r = enSuivi ? suivi : (mini?1:0) (NavEncre.swift:117) : dès que le doigt lève (enSuivi=false), r saute lire mini et la fin de course est animée par diff de modificateurs SwiftUI (fixe). Nouveau : r = (enSuivi || enVol) ? suivi : (mini?1:0). Le suivi reste la valeur de dessin pendant TOUTE la fin de course.

2) commettre LANCE UN TWEEN CADisplayLink (pas un withAnimation) sur suivi, durée à l'ÉLAN. On reprend au mot la mécanique du player (MoteurVol PlayerMonde.swift:283-304 + volVers avec PAS BORNÉ anti-téléportation-sous-famine :100-129), mais normalisée sur NOTRE course=34 (pas 852) — cf. NavEncre.swift:152-154 qui prévenait déjà « les chiffres ne sont PAS ceux du player ». Formule : vP = |velocite|/course ; distance = |cible01 − suivi| ; aligné = (cible01>suivi && velocite>0) || (cible01<suivi && velocite<0) — attention au SIGNE : ici suivi=1 est MINI et un drag vers le BAS (velocite>0) augmente suivi, l'inverse du player ; duree = (aligné && vP>0.35) ? clamp(3·distance/vP, 0.12, tempoNav) : clamp(distance·tempoNav, 0.16, tempoNav), avec tempoNav ≈ 0.30 (à caler au doigt). On flicke → ça file ; on pose → ça se pose.

3) LE LAYOUT RESTE UN COMMIT DE 0,25 s, séparé. mini bascule au relâcher dans withAnimation(.easeInOut 0.25) → navH (NavEncre.swift:208) → NavBande.frame (les 4 call-sites passent hauteur:navH, ex. HomeNuit.swift:2368) ET dockH → padding de la card (le .animation(value:dockH) de PageCard.swift:239 empêche déjà le saut de 52 pt). C'est LA card qui « gagne la hauteur au relâcher » — Kathryn l'a demandée comme un commit, pas comme un élan. Les POINTS (suivi, sous le doigt) portent l'élan ; la STRUCTURE se pose en 0,25 s. (Perfectionnisme optionnel : passer la même duree au withAnimation ET à PageCard:239 pour souder les deux.)

poser(_:) est CONSERVÉ tel quel pour le chemin TAP (NavBande:427, aller:457) : un tap n'a pas de vélocité, un 0,25 s fixe y est juste. Le chien de garde (NavEncre.swift:182-194) reste le filet du doigt mort-sans-onEnded ; il est gardé par enSuivi donc il ne double jamais le commit du pan (qui a déjà mis enSuivi=false). Le pan gère .cancelled/.failed→commettre (le vol système), comme le player (PlayerMonde.swift:715-722).

MoteurNav = jumeau minuscule de MoteurVol (on ne touche PAS PlayerMonde.swift : MoteurVol y est private). Le poser dans NavEncre.swift ; ajouter import QuartzCore (ou UIKit) pour CADisplayLink — NavEncre n'importe que SwiftUI aujourd'hui (CACurrentMediaTime y est déjà utilisé, NavEncre.swift:183).

## Pseudo-code

// ═══ 1) PanBande RÉÉCRIT : sonde non-interactive + PAN SUR LA FENÊTRE ═══
// (garde .background{PanBande(enSeance:)} en PageCard.swift:206 — la sonde
//  n'est jamais un hit-target, seul son rect converti sert)
struct PanBande: UIViewRepresentable {
  var enSeance: Bool
  final class Coord: NSObject, UIGestureRecognizerDelegate {
    static weak var fenetrePosee: UIWindow?
    weak var sonde: UIView?; weak var panPose: UIPanGestureRecognizer?; weak var fenetre: UIWindow?
    var enSeance = false
    enum Mode { case indecis, player, repli }
    enum Zone { case dehors, grabber, dalle, nav }
    var mode: Mode = .indecis, actif = false, mort = false
    var tyAncre: CGFloat = 0, rAncre: CGFloat = 0

    func retirer() {
      if let p = panPose { fenetre?.removeGestureRecognizer(p) }
      if Coord.fenetrePosee === fenetre { Coord.fenetrePosee = nil }
    }
    // PORTE (lue à la pose) : player fermé, pas de pause, doigt DANS la bande,
    // HORS strip système (parade géométrique Reachability/Home).
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive t: UITouch) -> Bool {
      guard !PlayerEtat.shared.monte, !DepartEtat.shared.pauseOuverte,
            let s = sonde, let w = s.window else { return false }
      let r = w.convert(s.bounds, from: s)        // rect ON-SCREEN (offset 18 inclus)
      let p = t.location(in: w)
      return r.contains(p) && p.y < r.maxY - w.safeAreaInsets.bottom
    }
    func gestureRecognizer(_ g: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true } // coopératif

    func zoneDe(_ yLocal: CGFloat) -> Zone {           // y relatif au haut de la bande
      if yLocal < 0 { return .dehors }
      if yLocal < BandeCote.grab { return .grabber }
      if enSeance, yLocal < BandeCote.grab + BandeCote.dalle { return .dalle }
      return .nav
    }
    @objc func pan(_ g: UIPanGestureRecognizer) {
      guard let w = g.view as? UIWindow, let s = sonde else { return }
      let t = g.translation(in: w); let ty = t.y
      switch g.state {
      case .began: actif = false; mort = false
      case .changed:
        guard !mort else { return }
        if !actif {                                     // DÉCISION APRÈS SEUIL, une fois
          if abs(ty) < 6 && abs(t.x) < 6 { return }
          if abs(t.x) > abs(ty) { mort = true; return } // latéral → on rend le toucher
          let r = w.convert(s.bounds, from: s)
          let yPose = (g.location(in: w).y - ty) - r.minY   // POINT DE POSE, pas courant
          let zone = zoneDe(yPose)
          guard zone != .dehors else { mort = true; return }
          mode = (zone == .dalle && ty < 0) ? .player : .repli
          actif = true; tyAncre = ty
          if mode == .repli { rAncre = NavEtat.shared.r }
        }
        switch mode {                                   // UNE FOIS DÉCIDÉ, ON NE CHANGE PLUS
        case .player: PlayerEtat.shared.suivreDelta(-(ty - tyAncre))
        case .repli:  NavEtat.shared.suivre(depuis: rAncre, delta: ty - tyAncre)
        case .indecis: break }
      case .ended, .cancelled, .failed:
        if actif {
          let vy = g.velocity(in: w).y
          if mode == .player { PlayerEtat.shared.commettre(velocite: vy) }
          else if mode == .repli { NavEtat.shared.commettre(velocite: vy) }
        }
        actif = false; mort = false; mode = .indecis
      default: break }
    }
  }
  func makeCoordinator() -> Coord { Coord() }
  func makeUIView(context: Context) -> UIView {
    let v = UIView(); v.isUserInteractionEnabled = false        // SONDE
    context.coordinator.sonde = v; context.coordinator.enSeance = enSeance; return v
  }
  func updateUIView(_ v: UIView, context: Context) {
    context.coordinator.enSeance = enSeance
    DispatchQueue.main.async {                                   // patron PlayerMonde:766-784
      guard let w = v.window, Coord.fenetrePosee !== w else { return }
      let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coord.pan(_:)))
      pan.maximumNumberOfTouches = 1; pan.delegate = context.coordinator
      w.addGestureRecognizer(pan)
      Coord.fenetrePosee = w; context.coordinator.panPose = pan; context.coordinator.fenetre = w
    }
  }
  static func dismantleUIView(_ v: UIView, coordinator: Coord) { coordinator.retirer() }
}

// ═══ 2) NavEtat : suivi SEC (gardé) + FIN DE COURSE À L'ÉLAN ═══
var enVol = false
private let moteur = MoteurNav()
static let tempoNav: Double = 0.30
var r: CGFloat { (enSuivi || enVol) ? suivi : (mini ? 1 : 0) }   // ← lit suivi en vol

func commettre(velocite: CGFloat) {
  enSuivi = false
  let cible: Bool = mini ? !(velocite < -140 || suivi < 0.78)    // seuils asymétriques gardés
                         :  (velocite >  300 || suivi > 0.45)
  let c01: CGFloat = cible ? 1 : 0
  withAnimation(.easeInOut(duration: 0.25)) { mini = cible }     // LAYOUT = commit 0,25 s
  volVers(c01, velocite: velocite)                              // POINTS = élan
  Haptique.leger()
}
private func volVers(_ c01: CGFloat, velocite: CGFloat) {
  let depart = suivi
  guard abs(c01 - depart) > 0.001 else { moteur.arreter(); enVol = false; suivi = c01; return }
  let vP = Double(abs(velocite)) / Double(max(Self.course, 1))   // course = 34
  let dist = Double(abs(c01 - depart))
  let aligne = (c01 > depart && velocite > 0) || (c01 < depart && velocite < 0)
  let duree = (aligne && vP > 0.35) ? min(max(3*dist/vP, 0.12), Self.tempoNav)
                                    : min(max(dist*Self.tempoNav, 0.16), Self.tempoNav)
  enVol = true; let t0 = CACurrentMediaTime()
  moteur.demarrer { [weak self] maintenant in
    guard let self else { return }
    let t = min(max((maintenant - t0)/duree, 0), 1)
    let vise = depart + (c01 - depart) * CGFloat(easeOut(t))     // easeOut cubique
    let pas = vise - self.suivi
    self.suivi = abs(pas) > 0.12 ? self.suivi + (pas > 0 ? 0.12 : -0.12) : vise  // pas BORNÉ
    if t >= 1 { self.moteur.arreter(); self.enVol = false; self.suivi = c01 }
  }
}
// poser(_:) INCHANGÉ (chemin TAP) ; chien de garde INCHANGÉ (garde enSuivi).

// ═══ 3) MoteurNav = jumeau de MoteurVol (PlayerMonde.swift:283-304), car privé là-bas ═══
final class MoteurNav: NSObject {   // import QuartzCore
  private var lien: CADisplayLink?; private var pas: ((Double) -> Void)?
  func demarrer(_ pas: @escaping (Double) -> Void) {
    arreter(); self.pas = pas
    let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
    l.add(to: .main, forMode: .common); lien = l }
  @objc private func tick(_ l: CADisplayLink) { pas?(l.targetTimestamp) }
  func arreter() { lien?.invalidate(); lien = nil; pas = nil }
}

## Risques

1) GEL NON CONFIRMÉ AU DOIGT. Le suspect A (tempête de préférence multi-niveaux) est LU, pas mesuré : valeurs constantes (.hidden/.bottom) → plus probablement une agitation de résolution qu'un blocage PERMANENT. À PROUVER sur TÉLÉPHONE, console Xcode, message « Bound preference tried to update multiple times per frame » : présent+fil bloqué = prouvé ; absent = ce n'était pas ça. Ne repeindre « gel réglé » qu'après lecture. La dé-duplication (racine unique) est de toute façon saine.

2) COUVERTURE fullScreenCover après la dé-dup. En retirant PageCard.swift:160-161, vérifier que TOUT écran porteur de bande hérite de la préférence racine. La séance vit « à la racine » (DepartSeance.swift:53) → couverte. MAIS le confirmer au doigt (indicateur home qui ne clignote pas, 1er down-swipe rendu à l'app) ; si un écran à bande passait par un cover, y poser la paire UNE fois dans ce cover, jamais la remettre dans PageCard.

3) REACHABILITY/HOME — dit sans mentir. On ne les DÉSACTIVE pas (É5, loi payée). La parade est géométrique + tap. ÉCART À EXPOSER À KATHRYN : descente=18 (PageCard.swift:74,124) avec grabH=18 pousse le contenu INTERACTIF dans le strip système, et l'exclusion de strip (shouldReceive) mange alors le bas de la zone de drag de la nav. Réconciliation proposée SANS perdre l'invariant « bande mord 18 pt » : garder la MORSURE visuelle (la nappe NOIRE descend 18 pt) mais NE PAS offsetter le VStack interactif (grabber/dalle/nav restent en zone sûre). Si Kathryn refuse, assumer que les tout derniers pixels du bas partent au système au 1er glissement — le tap de dépli, lui, marche toujours.

4) DEUX PANS FENÊTRE (player + nav). Portes disjointes (ouvert vs !monte) → jamais double-acceptation ; à confirmer au doigt sur la bascule ouvrir/fermer. Chacun garde son static fenetrePosee distinct (ne pas partager la variable de PlayerMonde).

5) cancelsTouchesInView (défaut true, comme le player). Le pan ne s'arme qu'après mouvement, donc un tap déjà validé n'est pas annulé — mais VÉRIFIER au doigt que tap glyphe / tap dalle / tap mini survivent bien sous le pan coopératif. Repli possible : cancelsTouchesInView=false.

6) w.convert(sonde.bounds) doit refléter l'offset(18). L'offset SwiftUI applique un transform à la couche hôte → convert le suit normalement, mais c'est LE point non mesurable en lecture : sonder au 1er build (-gesteSonde existe déjà, PanBande log) que le rect fenêtre = la bande VISIBLE, sinon la zone glisse de 18 pt.

7) TOUT se juge AU DOIGT (É6), jamais au simulateur qui n'a pas de moteur haptique ni la vraie cadence. Les seuils (course=34 NavEncre.swift:197, tempoNav≈0.30, vP>0.35, pas borné 0.12) sont des points de DÉPART à caler sur device — commentaire NavEncre.swift:152-154 déjà prévenu.

8) CADisplayLink pendant ~0,2 s au commit : coût négligeable, mais il tombe pendant que le layout (dockH) s'anime 0,25 s — vérifier au film qu'aucune contention (re-mesure des 4 pages montées) ne hache le vol ; le pas borné est l'anti-téléportation si famine.

9) NavEncre.swift n'importe que SwiftUI : ajouter import QuartzCore (ou UIKit) pour CADisplayLink, sinon build rouge. Rappel MEMORY : main ne compile pas seul — croiser tous les call-sites (les 5 PageCard/NavBande listés) avant de sceller.

## Les failles corrigees par l'adversaire

- **MAJEUR — Le pan fenêtre est mis dans .background de PageCard, or PageCard est instancié 4× (un par onglet) et le TabView les garde TOUS montés → le static de garde n'enregistre QU'UN pan, lié à la sonde et au enSeance de la 1re instance (la home). Marche par coïncidence, casse E6.**
  Correction : NE PAS garder PanBande en .background (retirer PageCard.swift:206). Monter UN SEUL NavPanHote à la racine, jumeau de PlayerMondeHote, à côté d'elle (WoopApp.swift:1311). La SEULE PageCard visible publie dans NavEtat (nouveaux champs @ObservationIgnored) son rect de bande en coords fenêtre + enSeance + bandeVisible, via `.onGeometryChange(for: CGRect.self)` en espace .global, GARDÉ par `\.ongletCache` (déjà posé par onglet : WoopApp.swift:1078/1088/1100/1107 ; false = visible). Le pan racine lit ces valeurs partagées. Static fenetrePosee PROPRE, distinct de celui du player. Ça supprime la dépendance aux coïncidences (toutes les bandes au même bas, enSeance ~global, home toujours montée) ET règle E6 : la gate lit `bandeVisible` publié par la page visible, qui passe false au drive du galet.
- **MAJEUR — saisir() n'arrête pas le MoteurNav. Le pseudo-code de fluidité ajoute enVol/moteur/volVers mais ne redéfinit PAS saisir(). Reprise en plein vol = deux écrivains sur `suivi` (le tick CADisplayLink + le doigt) → tremblement, et enVol reste bloqué à true.**
  Correction : Dans saisir(), avant `enSuivi=true` : `moteur.arreter(); enVol=false` (copie exacte de PlayerMonde.swift:166-167). Sans ça, le flick-puis-rattrape jitte — exactement le défaut de fluidité qu'on cherche à tuer.
- **MOYEN — Le diagnostic GEL (suspect A) est non prouvé et surqualifié. Les préférences incriminées sont CONSTANTES ; une constante imbriquée ne déclenche pas « update multiple times per frame » (ce warning naît d'une valeur qui change EN RÉPONSE à sa lecture : cycle géométrie/préférence). Par l'aveu même de la proposition et du journal, le gel DUR observé était dans le lot REVERTÉ.**
  Correction : Ne pas ordonner « le GEL d'abord » comme un fix d'un gel connu. Faire la dé-dup comme HYGIÈNE : une seule émission au niveau TabView (WoopApp.swift:1064), retirer PageCard.swift:160-161 / WoopApp.swift:1114-1115 / HomeNuit.swift:2495 ; VÉRIFIER que Profil (sans PageCard, WoopApp.swift:1108) hérite bien de la racine. Puis MESURER sur téléphone (console, `-gesteSonde` existe déjà PanBande.swift:45) : ne repeindre « gel réglé » qu'après lecture, dire honnêtement que lot 1 n'a pas de gel prouvé.
- **MOYEN — Deux échelles de temps désynchronisées = « couture », pas « eau ». Les points volent en tween (durée ∝ élan, ~0,12–0,30 s) tandis que la hauteur de card se commet en durée FIXE 0,25 s ; un `.animation(value:)` fixe ne peut pas suivre une durée variable.**
  Correction : Trancher AVEC Kathryn, ne pas laisser en « perfectionnisme optionnel ». Son verdict journal (PARTIE 1 : « changement de layout commis au relâcher ») suggère qu'elle ACCEPTE la structure en commit — dans ce cas 0,25 s fixe est juste et il n'y a rien à corriger, la couture est voulue. Sinon, piloter le padding par un withAnimation explicite de même durée que le tween au moment du commit (le `.animation(value:dockH)` fixe ne suffira jamais). À montrer au doigt, jamais au simulateur.
- **MOYEN — La géométrie porteuse (rect fenêtre de la bande) doit inclure l'.offset(y: descente=18) et n'est PAS mesurable en lecture. Si l'offset n'est pas reflété, la gate `r.contains(p)` et l'exclusion `p.y < r.maxY - safeAreaInsets.bottom` sont fausses de 18 pt.**
  Correction : Avec le pan racine (faille 1), publier le rect via `.onGeometryChange` en espace .global au niveau où la bande est DÉJÀ offsettée : .global reflète l'offset par construction et supprime le doute sur convert(). Sonder au 1er build (`-gesteSonde`) que le rect fenêtre == la bande VISIBLE.
- **MOYEN — La parade géométrique (exclure le strip bas) rétrécit la zone de drag de la nav sous le seuil utile, et la réconciliation proposée change la structure de `bande` sans être dans le pseudo-code.**
  Correction : Séparer explicitement la nappe NOIRE (offset 18, purement visuel, via PanBande/PanNappe) du VStack interactif grabber/dalle/nav (sans offset, en zone sûre). OU exposer à Kathryn que les ~18 pt du bas partent au système. À trancher AVANT de coder (invariant PageCard sacré, MEMORY).
- **MINEUR — cancelsTouchesInView (défaut true) vs le tap-partout-déploie en mini. Un léger glissement (>~10 pt, seuil UIKit interne, pas le 6 pt custom) arme le pan (mode=.repli) et annule le tap de dépli.**
  Correction : Acceptable ; vérifier au doigt que tap glyphe (NavEncre.swift:353), tap dalle (PageCard.swift:188) et tap-mini survivent sous le pan coopératif. Repli prêt : cancelsTouchesInView=false.

## Le plan final

ORDRE : hygiène/mesure → architecture (le vrai cœur) → fluidité. PlayerMonde.swift : ZÉRO ligne (réutilise PlayerEtat.suivreDelta PlayerMonde:192 / commettre :236 ; MoteurVol private → jumeau).

ÉTAPE 0 — MESURER (avant toute ligne). Lancer lot 1 sur TÉLÉPHONE, console Xcode : chercher « Bound preference tried to update multiple times per frame ». Répondre honnêtement : lot 1 gèle-t-il ? (probablement non — le gel était dans le lot reverté, journal É4).

ÉTAPE 1 — HYGIÈNE PRÉFÉRENCE (pas « fix gel »). Poser .defersSystemGestures(on:.bottom) + .persistentSystemOverlays(.hidden) UNE fois au TabView (WoopApp.swift:1064, hors des onglets). RETIRER PageCard.swift:160-161, WoopApp.swift:1114-1115, HomeNuit.swift:2495. VÉRIFIER que Profil (sans PageCard, WoopApp.swift:1108) hérite (indicateur home estompé, 1er down-swipe rendu à l'app). Les covers (Coffre CoffreV2.swift:2824/2828, Story) gardent LEUR propre paire.

ÉTAPE 2 — ARCHITECTURE (règle faille 1). (a) Retirer `.background{PanBande}` de PageCard.bande (PageCard.swift:206). (b) NavEtat : ajouter @ObservationIgnored `bandeRectFenetre: CGRect`, `bandeEnSeance: Bool`, `bandeVisiblePubliee: Bool`. PageCard publie ces 3 via `.onGeometryChange(for: CGRect.self){ $0.frame(in: .global) } action:` sur la bande DÉJÀ offsettée, GARDÉ par `if !ongletCache` (lire @Environment(\.ongletCache)). (c) Nouveau NavPanHote (UIViewRepresentable, jumeau exact de PanMaitre PlayerMonde.swift:646-789 : sonde isUserInteractionEnabled=false PlayerMonde:761, pan sur w.window en updateUIView PlayerMonde:766-784, static fenetrePosee PROPRE, dismantle→retirer PlayerMonde:786-788), monté 1× à la racine à côté de PlayerMondeHote (WoopApp.swift:1311). (d) Gate shouldReceive = `!PlayerEtat.shared.monte && !DepartEtat.shared.pauseOuverte && NavEtat.bandeVisiblePubliee && rect.contains(p) && p.y < rect.maxY - w.safeAreaInsets.bottom` (rect = NavEtat.bandeRectFenetre). shouldRecognizeSimultaneouslyWith→true. (e) Handler : seuil mouvement, |ty|≥|tx| sinon mort (toucher rendu, pas de cancel) ; zone au POINT DE POSE via BandeCote.grab/dalle (PanBande.swift:47-51) et NavEtat.bandeEnSeance ; mode=(dalle && ty<0)?.player:.repli, VERROUILLÉ jusqu'au lever ; .changed→PlayerEtat.suivreDelta(-(ty-ancre)) ou NavEtat.suivre(depuis:rAncre,delta:ty-tyAncre) ; .ended/.cancelled/.failed→commettre(velocite:vy). (f) Taps INCHANGÉS : dalle PageCard.swift:188, glyphes NavEncre.swift:353, dépli NavBande.onTapGesture NavEncre.swift:426.

ÉTAPE 3 — FLUIDITÉ (dans NavEtat seulement, NavEncre.swift). (a) saisir() : ajouter `moteur.arreter(); enVol=false` (faille 2, copie PlayerMonde:166-167). (b) `r = (enSuivi || enVol) ? suivi : (mini ? 1:0)` (remplace NavEncre.swift:117). (c) commettre() : `withAnimation(.easeInOut(0.25)){ mini=cible }` PUIS volVers(c01, velocite) — tween CADisplayLink, durée ∝ élan avec le SIGNE nav (suivi=1 est MINI, drag bas velocite>0 augmente suivi : aligne = (c01>depart && v>0)||(c01<depart && v<0)), pas borné 0,12, tempoNav≈0,30. (d) MoteurNav = jumeau de MoteurVol (PlayerMonde:283-304). (e) poser() INCHANGÉ (chemin tap NavEncre:173-179), chien INCHANGÉ (gardé par enSuivi NavEncre:182-194). (f) `import QuartzCore` si le build rougit (CACurrentMediaTime résout déjà avec SwiftUI seul, NavEncre:143/183 — probablement inutile, à confirmer au build).

CE QUE ÇA NE CASSE PAS : PlayerMonde.swift 0 ligne ; les 6 call-sites PageCard gardent `nav:` déjà présent (HomeNuit:2360, ExercisesView:475, ProgressPage:126, ExerciseDetailView:611 vérifiés ; PageCardLab:564 garde le défaut EmptyView) ; le pont selection⇄NavEtat.page intact (WoopApp:1144-1154, bijectif) ; l'invariant PageCard taille fixe (dockH commit discret, dockH dépend de `mini` pas de `suivi` NavEncre:216-218 → zéro relayout sous le doigt) ; bandeVisible=false démonte toute la bande (E6) ; le tirageGeste de la home (HomeNuit:2860/3733, page-large, !enSeance) reste DISJOINT du pan nav (sous-arbre page vs gate rect-bande) — vérifié, pas de collision.

## Ce qui reste impossible (la verite dure)

1) REACHABILITY (down-swipe bord bas) et HOME (up-swipe bord) sont NON désactivables : .defersSystemGestures ne fait que DIFFÉRER (1er glissement rendu à l'app, 2e au système) — c'est écrit dans le code lui-même (HomeNuit.swift:2489-2494). La seule vraie parade = géométrie (exclure le strip bas de la gate) + tap immobile. Donc les ~18–34 derniers pt du bas de la bande partent au système au 2e glissement : à ASSUMER devant Kathryn, jamais « réglé ». Le filet reste le chien de garde (le doigt volé ne doit pas laisser d'état cassé) — déjà en place NavEncre.swift:182-194.

2) Le « comme de l'eau » PARFAIT entre les points (tween à l'élan) et la card (commit) n'est pas atteignable tant que la card reste sur `.animation(value: dockH)` FIXE 0,25 s (PageCard.swift:239) : une durée de tween variable ne se raccorde pas à un layout fixe → couture. Deux issues honnêtes : soit points ET card à l'élan (piloter le padding au withAnimation, plus dur), soit card en 0,25 s fixe et couture ASSUMÉE — ce que Kathryn a peut-être déjà demandé (« commit au relâcher », journal PARTIE 1). À trancher au doigt, pas en lecture.

3) TOUT verdict de geste/gel/cadence est sur TÉLÉPHONE : le simulateur n'a ni haptique ni la vraie cadence (NavEncre.swift:249-250, MEMORY charge-machine). Les seuils sont des points de DÉPART à caler au doigt : course=34 (NavEncre.swift:197), tempoNav≈0,30, vP>0,35, pas borné 0,12 (le commentaire NavEncre.swift:152-154 prévient déjà « les chiffres ne sont PAS ceux du player »).

4) On ne peut PAS prouver en lecture que (a) le pan racine reçoit bien le doigt sur device, ni (b) que `.onGeometryChange(.global)` reflète l'offset(18) de la bande. À sonder OBLIGATOIREMENT au 1er build avec `-gesteSonde` (PanBande.swift:45, SondeHit/SondeGestePan PlayerMonde.swift:791-894) AVANT de déclarer quoi que ce soit vert. Ne réinstaller qu'un plan dont ces deux sondes ont parlé (journal É6 : ne pas empiler des installs non concluantes).
