import AVFoundation
import CoreHaptics
import SwiftUI
import SwiftData

// MARK: - Banc d'essai (`-homeLab`)

/// La home expérimentale « aurora » : l'ancienne home noire n'est pas
/// touchée — celle-ci vit ici, lancée avec `-homeLab` (ajouter `-demoData`
/// pour peupler les cartes). `-deckLab` isole la pile de cartes sur le fond
/// nu : c'est là qu'on la règle au pixel.
struct HomeAuroraLab: View {
    private static let deckOnly = CommandLine.arguments.contains("-deckLab")

    @State private var selection: WoopTab = .home

    /// L'ordre des onglets, tenu ICI plutôt que dans `WoopTab` : ce fichier est
    /// partagé, et une conformance ajoutée à l'énum se paie en conflits.
    private static let order: [WoopTab] = [.home, .exercises, .progress, .profile]

    private static let tabItems: [(icon: String, label: String)] = [
        ("house.fill", "Accueil"),
        ("figure.strengthtraining.functional", "Entraînements"),
        ("chart.line.uptrend.xyaxis", "Progression"),
        ("person", "Profil"),
    ]

    /// Le pont entre l'onglet nommé et l'index attendu par la barre.
    private var tabIndex: Binding<Int> {
        Binding(get: { Self.order.firstIndex(of: selection) ?? 0 },
                set: { selection = Self.order[$0] })
    }

    var body: some View {
        if Self.deckOnly {
            SwapDeckLab().preferredColorScheme(.dark)
        } else {
            // La barre native est MASQUÉE au profit de la barre bijou. Le verre
            // liquide d'Apple est translucide par nature ; posé sur cette
            // aurore, il en prend la couleur et la barre devient un reflet du
            // sol. L'obsidienne, elle, reste NOIRE sur le feu — et c'est le
            // contraste qui fait le bijou. Le TabView demeure pour ce qu'il
            // fait bien : l'état et les piles de navigation.
            //
            // `toolbarVisibility` se pose sur le CONTENU de chaque onglet :
            // appliqué au TabView, il ne masque rien.
            TabView(selection: $selection) {
                Tab("Accueil", systemImage: "house.fill", value: WoopTab.home) {
                    HomeAuroraView(selection: $selection)
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
                Tab("Exercices", systemImage: "figure.strengthtraining.functional",
                    value: WoopTab.exercises) {
                    Color.black.ignoresSafeArea()
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
                Tab("Progrès", systemImage: "chart.line.uptrend.xyaxis",
                    value: WoopTab.progress) {
                    Color.black.ignoresSafeArea()
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
                Tab("Profil", systemImage: "person", value: WoopTab.profile) {
                    Color.black.ignoresSafeArea()
                        .toolbarVisibility(.hidden, for: .tabBar)
                }
            }
            // `safeAreaInset` plutôt qu'un overlay : la barre réserve sa place,
            // donc la pile de cartes s'arrête au-dessus d'elle au lieu de couler
            // dessous, et elle se pose d'elle-même au-dessus de l'indicateur.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                JewelTabBar(items: Self.tabItems, selection: tabIndex,
                            play: PlayParams()) {
                    // Le branchement sur le démarrage de séance viendra ; pour
                    // l'instant le galet ne fait que s'allumer.
                }
                .frame(height: 64)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            // L'accent suit le mood : le violet de l'app jure dans un écran
            // d'or. Ici la sélection est une lumière chaude.
            .tint(Color(red: 1.0, green: 0.80, blue: 0.48))
            .preferredColorScheme(.dark)
        }
    }
}

/// Le banc de la pile : le fond aurora, la pile, ses points. Rien d'autre.
struct SwapDeckLab: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @State private var topCard = 0

    private var deck: [Workout] {
        Array(workouts.filter { !$0.isActive }.prefix(4))
    }

    var body: some View {
        ZStack {
            AuroraHomeBackground()
            // Comme dans la home : plus de points sous la pile — l'éventail
            // suffit à dire qu'il y a d'autres cartes.
            SwapDeck(workouts: deck, topCard: $topCard) { _ in }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - La home aurora

/// La même home que la noire — salut, objectif, CTA, derniers
/// entraînements — mais dans le mood du splash aurora : la nébuleuse
/// blanche se réchauffe de nuances orange et jaunes, et les quatre carrés
/// deviennent un carrousel de cartes « swap » en noir mat à reflets chauds.
struct HomeAuroraView: View {
    @Binding var selection: WoopTab

    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var askStart = false
    @State private var showAllWorkouts = false
    /// La carte du dessus de la pile — les points en bas la suivent.
    @State private var topCard = 0
    /// La séance qu'un toucher vient d'ouvrir.
    @State private var opened: Workout?
    /// La story en cours d'ouverture, et le rectangle d'où elle part.
    @State private var story: StoryLaunch?
    /// L'horloge de la fumée du coffre, ou `nil` si personne n'y touche.
    @State private var smokeStart: Date?
    /// L'instant où le doigt s'est levé (la fumée retombe à partir de là).
    @State private var smokeEnd: Date?
    /// La page du trésor.
    @State private var showCoffreFort = false

    private var finished: [Workout] { workouts.filter { !$0.isActive } }
    private var activeWorkout: Workout? { workouts.first { $0.isActive } }
    private var swapped: [Workout] { Array(finished.prefix(4)) }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }

    private var doneThisWeek: Int {
        finished.filter { $0.startedAt >= weekStart }.count
    }

    /// L'arrivée de la cinématique : le contenu naît APRÈS la lumière — un
    /// souffle après l'aube, jamais avant elle. Hors cérémonie, tout est là
    /// dès la première image.
    @State private var contentBorn = true

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraHomeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Group {
                            greeting
                            weeklyCard
                        }
                        .padding(.horizontal, 20)
                        // Le carrousel déborde du gabarit : pleine largeur,
                        // les cartes voisines dépassent des deux côtés.
                        swapSection
                    }
                    .padding(.bottom, 130)
                }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y
                } action: { _, offset in
                    SkyState.shared.scroll = offset
                }
                .opacity(contentBorn ? 1 : 0)
                .offset(y: contentBorn ? 0 : 10)
            }
            // La fumée du coffre se dessine ICI, hors du défilement : le
            // coffre publie sa place (CoffreFortCoinBounds) et le nuage — qui
            // déborde de près de cent points — s'étale sans rencontrer le
            // bord du ScrollView, qui l'aurait tranché au couteau.
            .overlayPreferenceValue(CoffreFortCoinBounds.self) { anchor in
                GeometryReader { proxy in
                    if let anchor, let smokeStart {
                        let box = proxy[anchor]
                        CoinSmoke(center: CGPoint(x: box.midX, y: box.midY),
                                  radius: CoffreFortCoinButton.diameter / 2,
                                  start: smokeStart, end: smokeEnd,
                                  palette: .light)
                    }
                }
                .allowsHitTesting(false)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: smokeStart)
            .navigationBarHidden(true)
            .onAppear {
                fireSmokeBenchIfAsked()
                guard HomeWelcome.start != nil else { return }
                contentBorn = false
                // La lumière d'abord (l'aube part 0,45 s après la coupe), le
                // contenu un souffle plus tard — c'est elle qui le révèle.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    withAnimation(.easeOut(duration: 0.65)) { contentBorn = true }
                }
            }
            .navigationDestination(isPresented: $showAllWorkouts) { WorkoutsListView() }
            .navigationDestination(item: $opened) { WorkoutDetailView(workout: $0) }
            .sheet(isPresented: $askStart) { startSheet }
            // Plein écran, et non une destination de navigation : la page du
            // trésor doit couvrir AUSSI la barre bijou (posée en
            // `safeAreaInset` à la racine) — une cinématique avec une barre
            // d'onglets qui flotte par-dessus n'est plus une cinématique.
            .fullScreenCover(isPresented: $showCoffreFort) {
                CoffreFortFlow(
                    // La règle des pièces : 20 par SÉRIE faite — le trésor
                    // compte les séries de toutes les séances terminées.
                    coins: CoffreFortPurse.coins(
                        doneSeries: finished
                            .flatMap { $0.exercises ?? [] }
                            .reduce(0) { $0 + $1.completedSets })
                ) {
                    showCoffreFort = false
                }
            }
            // La story, pour la même raison : elle doit couvrir la barre bijou.
            .fullScreenCover(item: $story) { launch in
                StoryPortal(from: launch.rect,
                            session: StorySession(workout: launch.workout)) {
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) { story = nil }
                }
            }
        }
    }

    // MARK: En-tête, objectif, CTA — la home noire, à l'identique

    /// Le salut, et le coffre à sa droite — même ligne, même hauteur d'œil.
    /// La marge droite lui vient du `.padding(.horizontal, 20)` du groupe
    /// au-dessus : il ne touche pas la paroi.
    private var greeting: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Bonjour Kathryn")
                .font(.inter(30, .semibold))
                .tracking(-0.3)
                .foregroundStyle(WoopGradient.silverText)

            Spacer(minLength: 8)

            // LE BOUTON D'ESSAI DU PARCOURS BOOSTER — temporaire, et
            // assumé. La pop-up viendra de la FIN DE SÉANCE (le
            // « Terminer » d'`ActiveWorkoutView`), mais ce flow-là n'est
            // pas validé : on teste la chaîne bouton par bouton (home →
            // pop-up → manège → cérémonie → profil). À retirer au
            // branchement. Le parcours : `tools/sacre/PARCOURS-BOOSTER.md`.
            Button { SacreEtat.shared.proposer() } label: {
                SachetVignette(largeur: 16, hauteur: 28)
                    .frame(width: 44, height: 44)
                    .background {
                        Color.clear.glassEffect(
                            .regular.tint(Color.black.opacity(0.5))
                                .interactive(),
                            in: RoundedRectangle(cornerRadius: 15,
                                                 style: .continuous))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 15,
                                              style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08),
                                      lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Essai : proposer un booster")

            CoffreFortCoinButton(onPress: chestTouched, action: openCoffreFort)
        }
        .padding(.top, 14)
    }

    /// Le doigt se pose, le doigt se lève — l'horloge de la fumée vit ICI
    /// parce que c'est la page qui la dessine (le coffre, lui, défile).
    private func chestTouched(_ pressed: Bool) {
        if pressed {
            smokeStart = .now
            smokeEnd = nil
        } else {
            let mark = Date.now
            smokeEnd = mark
            // La bouffée s'éteint en ~0,45 s ; on démonte le sous-arbre une
            // fois qu'il ne reste rien à dessiner, pour rendre les 30 Hz du
            // TimelineView. Une autre bouffée a pu naître entre-temps : on
            // n'éteint que la SIENNE.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard smokeEnd == mark else { return }
                smokeStart = nil
                smokeEnd = nil
            }
        }
    }

    /// `-coffreSmoke` : la bouffée part SEULE, deux secondes après l'arrivée,
    /// et la page du trésor ne s'ouvre pas (c'est l'action du bouton, pas le
    /// toucher, qui l'ouvre). Le simulateur ne sait pas poser un doigt sur
    /// l'écran — sans ce déclencheur, la fumée n'est vérifiable que sur
    /// l'appareil. Même idée que `-aubeFire` pour la traversée du dôme.
    private func fireSmokeBenchIfAsked() {
        guard CommandLine.arguments.contains("-coffreSmoke") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            chestTouched(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                chestTouched(false)
            }
        }
    }

    /// Le toucher fume, PUIS la page s'ouvre. Ouverte au même instant, la
    /// fumée serait recouverte avant d'avoir été vue — on lui laisse le
    /// temps de naître sur la home.
    private func openCoffreFort() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            showCoffreFort = true
        }
    }

    private var weeklyCard: some View {
        Button {} label: {
            // L'obsidienne, pas le verre : c'est la matière que Kathryn a
            // retenue (verdict du 2026-08-02). Elle a aussi l'avantage d'être
            // franchement sombre — sur une aurore qui monte jusqu'à 60 % de
            // l'écran, une carte de verre translucide prendrait la couleur du
            // sol et disparaîtrait.
            ObsidianGlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Objectif hebdomadaire")
                        .font(.inter(12, .medium))
                        .textCase(.uppercase)
                        .tracking(2.2)
                        .foregroundStyle(.white.opacity(0.58))

                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        ShimmeringNumber(value: doneThisWeek, size: 34)
                        Text("/ \(Goal.weeklyTarget) entraînements")
                            .font(.inter(13))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .padding(.top, 9)

                    TrophyRow(completed: doneThisWeek, total: Goal.weeklyTarget,
                              slotSize: 44, justified: true, luminous: true,
                              celebrates: true)
                        .padding(.top, 22)
                }
            }
        }
        .buttonStyle(ObsidianCardPressStyle())
    }

    // Le bouton « Commencer un entraînement » a été RETIRÉ : c'est le galet
    // play, au centre de la barre d'onglets, qui démarre désormais une séance.
    // Un appel à l'action en double — un pavé dans la page ET un bouton qui
    // respire en bas — annulerait justement ce que le galet cherche à être.

    private var startSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.16))
                .frame(width: 38, height: 4)
                .padding(.top, 10)

            VStack(spacing: 12) {
                Text("Commencer une nouvelle séance ?")
                    .font(.inter(19, .semibold))
                    .foregroundStyle(WoopGradient.silverText)
                    .multilineTextAlignment(.center)

                Text("Elle est enregistrée immédiatement : tu peux fermer l'app sans rien perdre.")
                    .font(.inter(13))
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 26)
            .padding(.horizontal, 26)

            VStack(spacing: 10) {
                DiamondPrimaryButton(title: "Commencer", smokeWarmth: 0.4) {
                    askStart = false
                    startWorkout()
                }

                Button("Annuler") { askStart = false }
                    .buttonStyle(WoopSecondaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(WoopBackground())
        .presentationDetents([.height(290)])
        .presentationBackground(Color.woopSheet)
        .presentationCornerRadius(30)
    }

    private func startWorkout() {
        let workout = Workout()
        context.insert(workout)
        try? context.save()
        WorkoutActivityController.ensure(workout)
        selection = .exercises
    }

    // MARK: Derniers entraînements — le carrousel « swap »

    @ViewBuilder
    private var swapSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Derniers entraînements",
                          // « Tout voir » ouvre le CALENDRIER (l'onglet
                          // Progrès depuis le 18-08) — l'animation de
                          // bascule de la maison, le chevron y ramène.
                          // Et il POSE la demande d'OUVERTURE : la
                          // cinématique-bilan ne joue que par cette
                          // porte (arbitrage 19-08).
                          action: {
                              CalCine.demande = true
                              withAnimation(.easeOut(duration: 0.3)) {
                                  selection = .progress
                              }
                          })
                .padding(.horizontal, 20)

            Text("Ta collection d'entraînements")
                .font(.inter(13))
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 20)

            if swapped.isEmpty {
                // La pile vide n'est plus une phrase dans une boîte : c'est la
                // même carte, néon allumé, et des chevrons qui descendent vers
                // le galet de la barre.
                SwapEmptyCard()
                    .padding(.top, 16)
            } else {
                // LE CARNET DE CUIR (chantier 18-08) : la collection est
                // un carnet relié — la pile swap a cédé sa place mais vit
                // toujours au design system (SwapDeck, banc -deckLab).
                // Le tap l'ouvre en double page, EN PLACE dans la section
                // (jalon 3) ; les pages de séances sont le jalon 4.
                CarnetHome()
                    .frame(maxWidth: .infinity)
                    .frame(height: SwapDeck.deckHeight)
                    .padding(.top, 16)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - La pile qu'on swipe

/// Les séances en pile, comme un jeu de cartes qu'on écarte du pouce : la
/// carte du dessus suit le doigt et s'incline, celle de dessous attend,
/// déjà visible — on sait qu'il y en a une autre. Passé le seuil, la carte
/// part en volée et la suivante monte à sa place. Rien ne se perd : la
/// pile tourne en boucle.
/// L'axe d'un geste sur la carte du dessus, verrouillé une fois pour toutes.
enum SwapAxis { case undecided, side, up }

/// Le rectangle de la carte du dessus, remonté jusqu'au deck. Le zéro n'écrase
/// jamais une vraie valeur : les cartes du dessous n'en publient pas, et une
/// réduction naïve les laisserait effacer celle du dessus.
struct TopCardRectKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

struct SwapDeck: View {
    let workouts: [Workout]
    @Binding var topCard: Int
    var onOpen: (Workout) -> Void
    /// Le tirage VERS LE HAUT ouvre la story de la séance. Le rectangle rendu
    /// est celui de la carte à l'écran, à l'instant du lâcher : c'est là que
    /// le portail commence à s'ouvrir.
    var onStory: (Workout, CGRect) -> Void = { _, _ in }

    /// Le déplacement du doigt sur la carte du dessus.
    @State private var drag: CGSize = SwapDeck.benchSwipe
        ? CGSize(width: 128, height: -18) : .zero
    /// Pendant la volée, plus rien ne répond : une carte à la fois.
    @State private var flying = false
    /// La carte qui vient de partir : gardée invisible le temps que la pile
    /// se réorganise, sinon on la voit retraverser l'écran vers le fond.
    @State private var vanished: PersistentIdentifier?
    /// La gerbe en cours, s'il y en a une.
    @State private var burst: Burst?
    /// Le dernier grain haptique joué : le moteur se sature si on le nourrit
    /// à chaque image du geste.
    @State private var lastTick: Date = .distantPast
    /// L'horodatage du toucher : la bouffée du néon intérieur.
    @State private var tapAt: Date = .distantPast
    /// Le tube a-t-il déjà pris pour CE geste : l'amorçage ne sonne qu'une
    /// fois, pas à chaque image passée au-dessus du seuil.
    @State private var ignited = false
    /// L'AXE DU GESTE, verrouillé aux dix premiers points. Il n'y a qu'UN
    /// reconnaisseur sur cette carte et il consomme déjà les deux axes : en
    /// ajouter un second pour le tirage vertical ne marche pas, le premier
    /// avale tout. C'est donc le même geste qui décide, une fois, de ce qu'il
    /// est — et il ne change plus d'avis avant le lâcher.
    @State private var axis: SwapAxis = .undecided
    /// La montée de la carte quand on la tire vers le haut.
    @State private var lift: CGFloat = 0
    /// Le rectangle de la carte du dessus, à l'écran, au repos.
    @State private var topRect: CGRect = .zero

    /// Les cartes visibles, de la plus profonde à celle du dessus (l'ordre
    /// de rendu). La plus profonde est transparente : c'est là que la carte
    /// qui vient de partir revient, sans jamais se voir traverser l'écran.
    private var slots: [(depth: Int, workout: Workout)] {
        guard !workouts.isEmpty else { return [] }
        let shown = min(workouts.count, 4)
        return (0..<shown).reversed().map { depth in
            (depth, workouts[(topCard + depth) % workouts.count])
        }
    }

    /// La carte, un cran au-dessus de la référence d'origine (207 × 265) :
    /// verdict du 2026-08-04 — « un peu plus grosses, toujours noires ».
    /// Dimensionnée à la main — un `aspectRatio` dans une pile se bat avec la
    /// hauteur du conteneur et finit par déborder — et assez basse pour que la
    /// pile, ses points ET la barre d'onglets tiennent ensemble à l'écran.
    static let cardHeight: CGFloat = 282
    static let cardWidth: CGFloat = 220
    /// L'éventail : les cartes de dessous ne se cachent plus SOUS la
    /// première, elles dépassent sur les CÔTÉS — une main de cartes
    /// entrouverte. Écart latéral, léger enfoncement, inclinaison de l'aile.
    private static let fanStep: CGFloat = 40
    private static let fanDip: CGFloat = 12
    private static let fanTilt: Double = 5.0
    private static let fanShrink: CGFloat = 0.93
    /// La hauteur du bloc : la carte et l'air des coins levés de l'éventail.
    static let deckHeight = cardHeight + 26
    /// Où se trouve le centre de la carte du dessus dans le bloc : au centre —
    /// l'éventail s'écarte sur les côtés, il ne s'empile plus vers le bas.
    static let topCardCenterY = deckHeight / 2
    /// La marge où respire la gerbe : les bijoux volent bien au-delà de la
    /// pile — un shader ne peint que dans son rectangle hôte.
    private static let burstRoom: CGFloat = 290
    /// Le geste est décidé au-delà de ce déplacement.
    private static let threshold: CGFloat = 96
    /// Le banc fige la carte du dessus en plein geste (`-deckSwiped`) : la
    /// suivante doit se lire comme « prête », sans avoir à tenir le doigt.
    private static let benchSwipe = CommandLine.arguments.contains("-deckSwiped")
    /// `-deckBurst` rejoue la pluie en boucle (toutes les 3 s) : une pluie
    /// se juge en la regardant TOMBER, pas sur une image figée.
    private static let benchBurst = CommandLine.arguments.contains("-deckBurst")

    /// Le seuil du tirage vertical. Plus haut que celui du swap : une story
    /// est un aller sans retour, elle ne doit pas partir sur un frôlement.
    static let liftThreshold: CGFloat = 110

    /// La montée du geste : 0 au repos, 1 quand le doigt a décidé. C'est elle
    /// qui embrase l'écrin de la carte — le tirage vertical l'embrase AUSSI,
    /// donc la carte prend feu dans la main avant de partir en story.
    private var charge: Float {
        let side = abs(drag.width) / Self.threshold
        let up = lift / Self.liftThreshold
        return Float(min(max(side, up), 1))
    }

    /// Où le doigt tire, en vecteur unitaire — le foyer de lumière s'y rend.
    private var pull: CGSize {
        let len = max(sqrt(drag.width * drag.width + drag.height * drag.height), 1)
        return CGSize(width: drag.width / len, height: drag.height / len)
    }

    var body: some View {
        ZStack {
            reflection
            ForEach(slots, id: \.workout.persistentModelID) { slot in
                card(slot.workout, depth: slot.depth)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.deckHeight)
        // La gerbe vit AU-DESSUS de la pile et lui survit : hébergée ici, elle
        // continue de s'ouvrir alors que la carte a déjà quitté l'écran.
        .overlay {
            if let burst {
                SwapBurstLayer(burst: burst, room: Self.burstRoom)
                    .padding(-Self.burstRoom)
                    .allowsHitTesting(false)
            }
        }
        .onPreferenceChange(TopCardRectKey.self) { topRect = $0 }
        .onAppear {
            guard Self.benchBurst, burst == nil else { return }
            // Au banc, la carte est au repos : la pluie part de SON contour,
            // et se rejoue en boucle pour qu'on puisse la regarder tomber.
            let seed = { burst = Burst(at: .now, origin: .zero,
                                       way: CGSize(width: 1, height: 0)) }
            seed()
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                seed()
            }
        }
    }

    /// Le reflet : la carte du dessus, retournée sous elle, floutée et
    /// fondue en quelques points. Composée en `plusLighter` — la carte est
    /// noire, seule sa LUMIÈRE se reflète (le liseré, le dégradé d'or, le
    /// texte) : un sol poli sous la nuit, jamais une copie grise. Elle
    /// suit le geste, donc le reflet danse avec elle.
    @ViewBuilder
    private var reflection: some View {
        if let top = slots.first(where: { $0.depth == 0 })?.workout {
            SwapWorkoutCard(workout: top, seed: 0, charge: charge,
                            tapAt: tapAt, pull: pull)
                .frame(width: Self.cardWidth, height: Self.cardHeight)
                .scaleEffect(x: 1, y: -1)
                .mask {
                    // Le masque garde la bande qui TOUCHE la carte et se perd
                    // en descendant. Inversé, le reflet se détachait loin
                    // dessous — invisible dans la home, où cette bande tombe
                    // derrière la barre d'onglets.
                    //
                    // Il est COURT : il meurt en 26 pt (0,10 de la hauteur) au
                    // lieu de 146 (0,55). Sur l'aurore embrasée, un reflet long
                    // n'ajoute rien — le sol y est déjà à 98 % de blanc, la
                    // lumière ne peut plus s'y ajouter — sauf les BLOCS DE
                    // TEXTE de la carte, qui tombaient à 38-55 pt sous elle et
                    // se lisaient en deux plaques pâles rectangulaires
                    // (« la card transparente, le calque derrière »). Ce qui
                    // pose la carte sur un sol poli, c'est la bande de CONTACT,
                    // pas la traîne : coupée avant le cartouche, il reste le
                    // reflet et plus le fantôme.
                    LinearGradient(stops: [
                        .init(color: .white.opacity(0.90), location: 0.0),
                        .init(color: .white.opacity(0.28), location: 0.045),
                        .init(color: .white.opacity(0.0), location: 0.10)
                    ], startPoint: .top, endPoint: .bottom)
                }
                .blur(radius: 3)
                .opacity(0.60)
                .rotationEffect(.degrees(-Double(drag.width) / 30), anchor: .top)
                .offset(x: drag.width,
                        y: Self.cardHeight + 3 + drag.height * 0.25)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func card(_ workout: Workout, depth: Int) -> some View {
        let isTop = depth == 0
        let deepest = depth == min(workouts.count, 4) - 1 && workouts.count > 1
        let gone = workout.persistentModelID == vanished
        // L'éventail : la deuxième carte dépasse à DROITE, la troisième à
        // GAUCHE — on ne les devine plus sous la première, on les voit,
        // chacune de son côté. La plus profonde reste le quai de retour.
        let wing: CGFloat = depth == 1 ? 1 : (depth == 2 ? -1 : 0)

        SwapWorkoutCard(workout: workout, seed: Float(depth),
                        charge: isTop ? charge : 0,
                        tapAt: isTop ? tapAt : .distantPast,
                        pull: pull)
            .frame(width: Self.cardWidth, height: Self.cardHeight)
            // Le rectangle de la carte du dessus, AU REPOS, en coordonnées
            // écran : c'est de là que le portail de la story part. Il est lu
            // avant les transformations du geste — la montée du doigt lui est
            // ajoutée au lâcher, pas ici.
            .background {
                if isTop {
                    GeometryReader { g in
                        Color.clear.preference(key: TopCardRectKey.self,
                                               value: g.frame(in: .global))
                    }
                }
            }
            // SANS ceci, seuls les GLYPHES sont tactiles : la carte est un
            // vide, le doigt passait au travers et c'est la page qui
            // scrollait. C'est toute la panne du geste.
            .contentShape(Rectangle())
            // Le voile : les ailes restent NOIRES mais reculent d'un demi-ton
            // dans la nuit — la première carte garde la lumière pour elle.
            // En opacité animée, pas en `if` : à la promotion d'une aile, le
            // voile se lève avec le ressort au lieu de sauter.
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(isTop ? 0 : 0.34))
                    .allowsHitTesting(false)
            }
            .scaleEffect(isTop ? 1 - min(abs(drag.width), 140) / 2600
                               : Self.fanShrink)
            .offset(x: isTop ? drag.width : wing * Self.fanStep,
                    y: isTop ? drag.height * 0.25 - lift : Self.fanDip)
            // Le basculement 3D : la carte n'est plus une image qui glisse,
            // c'est un objet qu'on incline — elle pivote autour de son axe
            // vertical vers le côté où l'on tire, et s'incline vers l'avant
            // ou l'arrière selon la hauteur du doigt. La perspective est
            // courte : c'est ce qui donne l'épaisseur.
            .rotation3DEffect(.degrees(isTop ? Double(drag.width) / 11 : 0),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.62)
            .rotation3DEffect(.degrees(isTop ? -Double(drag.height) / 15 : 0),
                              axis: (x: 1, y: 0, z: 0), perspective: 0.62)
            // Et le pivot BAS reste, en retrait : la carte bascule dans la
            // main, elle ne tourne pas autour de son nombril — et les ailes
            // s'inclinent chacune vers son bord, comme une main de cartes.
            .rotationEffect(.degrees(isTop ? Double(drag.width) / 30
                                           : Double(wing) * Self.fanTilt),
                            anchor: .bottom)
            // La carte de fond reste invisible, et celle qui vient de partir
            // aussi : ni l'une ni l'autre ne doit se voir revenir.
            .opacity(deepest || gone ? 0 : 1)
            .zIndex(Double(10 - depth))
            .animation(.spring(response: 0.46, dampingFraction: 0.80), value: topCard)
            .allowsHitTesting(isTop && !flying)
            // LE TOUCHER OUVRE LA STORY. Le tube s'allume d'abord : sans ce
            // court délai, l'ouverture emporte la carte et la bouffée ne se
            // voit jamais. La fiche de séance reste accessible par
            // « Tout voir ».
            .onTapGesture {
                guard isTop else { return }
                tapAt = .now
                SwapFeedback.shared.ignite()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    onStory(workout, topRect)
                }
            }
            .gesture(isTop ? swipeGesture() : nil)
    }

    private func swipeGesture() -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !flying else { return }

                // LE VERROU D'AXE, décidé une seule fois. Sur les dix premiers
                // points, le geste choisit ce qu'il est : latéral, c'est le
                // swap ; vers le HAUT, c'est la story. Et il ne revient plus
                // dessus — un axe qui se rediscute en cours de route donne un
                // geste qui hésite sous le doigt.
                if axis == .undecided {
                    let dx = abs(value.translation.width)
                    let dy = abs(value.translation.height)
                    if max(dx, dy) > 10 {
                        // Vers le BAS, rien de neuf : c'est le swap qui garde
                        // la main, la story ne se tire que vers le haut.
                        axis = (dy > dx && value.translation.height < 0)
                            ? .up : .side
                    }
                }

                if axis == .up {
                    // LA RÉSISTANCE : suivi franc sur soixante points, puis
                    // 25 % — la carte a du poids, elle ne colle pas au doigt
                    // jusqu'au bout de l'écran.
                    let pull = max(0, -value.translation.height)
                    lift = min(pull, 60) + max(pull - 60, 0) * 0.25
                    drag = CGSize(width: 0, height: value.translation.height)
                } else {
                    drag = value.translation
                }
                // L'amorçage : une seule fois par geste, à l'instant où le
                // tube prend. Au-delà, c'est le grain qui parle.
                if !ignited, charge > 0.12 {
                    ignited = true
                    SwapFeedback.shared.ignite()
                }
                // Le grain sous le doigt : cadencé (plus serré à mesure que
                // le seuil approche), jamais à chaque image — la trame du
                // moteur haptique se saturerait et on ne sentirait plus rien.
                let now = Date()
                let period = 0.11 - 0.05 * Double(charge)
                if now.timeIntervalSince(lastTick) > period {
                    lastTick = now
                    SwapFeedback.shared.drag(charge: charge)
                }
            }
            .onEnded { value in
                guard !flying else { return }
                let wasUp = axis == .up
                axis = .undecided

                if wasUp {
                    let go = lift > Self.liftThreshold
                        || value.predictedEndTranslation.height < -260
                    if go, let top = slots.first(where: { $0.depth == 0 })?
                        .workout {
                        // Le portail part du rectangle où la carte est
                        // RÉELLEMENT, c'est-à-dire soulevée : sans ça il
                        // s'ouvrirait d'un cran plus bas que ce que la main
                        // vient de porter, et la continuité se casse.
                        onStory(top, topRect.offsetBy(dx: 0, dy: -lift))
                    }
                    withAnimation(.spring(response: 0.42,
                                          dampingFraction: 0.86)) {
                        lift = 0
                        drag = .zero
                    }
                    ignited = false
                    return
                }

                let go = abs(value.translation.width) > Self.threshold
                    || abs(value.predictedEndTranslation.width) > 220
                guard go else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                        drag = .zero
                    }
                    ignited = false
                    return
                }
                fly(from: value.translation)
                ignited = false
            }
    }

    /// La volée, et tout ce qui l'accompagne : la gerbe de bijoux s'ouvre à
    /// l'instant de l'arrachement, le grave monte dans la main, le verre
    /// sonne — puis la pile se referme sur la suivante.
    private func fly(from translation: CGSize) {
        guard let departing = slots.first(where: { $0.depth == 0 })?.workout
        else { return }
        flying = true
        let side: CGFloat = translation.width > 0 ? 1 : -1

        // La gerbe naît là où la carte se trouve À CET INSTANT : les bijoux
        // sortent de SON contour, pas d'un point abstrait.
        burst = Burst(at: .now,
                      origin: CGSize(width: translation.width,
                                     height: translation.height * 0.25),
                      way: CGSize(width: side, height: 0))
        SwapFeedback.shared.swipe()

        withAnimation(.easeOut(duration: 0.46)) {
            drag = CGSize(width: side * (Self.cardWidth + 420),
                          height: translation.height * 0.5)
        }
        // La carte est hors champ : on la masque, on remet le geste à zéro
        // sans animation, et la pile monte d'un cran EN ressort.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                vanished = departing.persistentModelID
                drag = .zero
            }
            topCard = (topCard + 1) % max(workouts.count, 1)
            flying = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            vanished = nil
        }
        // La pluie tombe longtemps : la couche vit jusqu'à la dernière
        // étoile (2,4 s côté shader).
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            burst = nil
        }
    }
}

// MARK: - La gerbe

/// Une gerbe en cours : quand elle est née, d'où elle part (le décalage de
/// la carte à l'arrachement), et vers où la carte s'en est allée.
struct Burst: Equatable {
    let at: Date
    let origin: CGSize
    let way: CGSize
}

/// L'hôte du shader `swapBurst` : un rectangle bien plus large que la pile
/// (les bijoux volent loin), présent SEULEMENT pendant la gerbe — au repos,
/// la vue n'existe pas et ne coûte rien.
struct SwapBurstLayer: View {
    let burst: Burst
    let room: CGFloat

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                let age = Float(tl.date.timeIntervalSince(burst.at))
                // Le centre de la carte au moment de l'arrachement, dans le
                // repère de CETTE couche (élargie de `room` de chaque côté).
                let cx = geo.size.width / 2 + burst.origin.width
                let cy = room + SwapDeck.topCardCenterY + burst.origin.height
                // L'hôte se remplit de BLANC opaque : le shader multiplie sa
                // sortie par `color.a` — sur un remplissage `.clear`, toute
                // la gerbe s'annulait sans rien dire.
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.swapBurst(
                        .float2(geo.size.width, geo.size.height), .float(t),
                        .float2(Float(cx), Float(cy)),
                        .float2(Float(SwapDeck.cardWidth / 2),
                                Float(SwapDeck.cardHeight / 2)),
                        .float(24),
                        .float2(Float(burst.way.width), Float(burst.way.height)),
                        .float(age)))
            }
        }
        .blendMode(.plusLighter)
    }
}

// MARK: - Le ciel réchauffé

/// La nuit de la page : noir absolu, le halo de l'aurore qui DESCEND du haut
/// — versé par la Dynamic Island, les mêmes tons que la connexion mais en
/// plafond de lumière, et tout le bas rendu à la nuit — et, gardées du ciel
/// d'origine, les poussières d'étoiles (la passe `nebulaStars` seule),
/// déménagées dans le noir du BAS : là où le halo vit, elles seraient
/// invisibles ; c'est la nuit qui a besoin d'elles.
struct AuroraHomeBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black

            AuroraFloor()

            // Les particules du bas : le champ d'étoiles du ciel de la
            // maison, éteint avant le halo pour laisser la nuit seule.
            StarDustCeiling()
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.44),
                        .init(color: .white.opacity(0.50), location: 0.68),
                        .init(color: .white.opacity(0.80), location: 1.0)
                    ], startPoint: .top, endPoint: .bottom)
                }

            WoopGrain()
        }
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
        // LE GYROSCOPE S'AMORCE ICI — le bug du 19-08 : SkyMotion n'était
        // démarré que par l'ancien ciel (WoopDemonSky), l'auth et le banc
        // logo. Sur la home aurora, personne ne l'appelait : la parallaxe
        // des étoiles ET l'inclinaison du carnet lisaient des zéros sur
        // téléphone. La scène est l'endroit juste : tout ce qui vit dessus
        // en profite. Le retour d'arrière-plan relance (le système coupe
        // les updates, la leçon de WoopDemonSky).
        .onAppear { SkyMotion.shared.start(reduceMotion: reduceMotion) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                SkyMotion.shared.start(reduceMotion: reduceMotion)
            }
        }
    }
}

/// L'hôte de l'aurore. Depuis le 2026-08-04 `bgAuroraHome` est RETOURNÉ — le
/// MÊME champ que la page de connexion (mêmes rideaux, mêmes poussières, même
/// parallaxe à trois plans) mais la lumière descend du HAUT, versée par la
/// Dynamic Island, et le bas de la page est rendu à la nuit. L'ancien
/// `homeAurora` reste dans AuroraHome.metal, plus référencé.
struct AuroraFloor: View {
    @StateObject private var tilt = BgTilt()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                // L'aube : au débouché de la cinématique de connexion, la
                // lumière NAÎT — avec la forme du login (un fil de crête au
                // bord bas) qui se déploie vers celle de la home. Hors
                // cérémonie, 1 : la page est elle-même.
                let birth = ConnexionCine.birth(at: tl.date)
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.bgAuroraHome(
                        .float2(geo.size.width, geo.size.height), .float(t),
                        .float2(Float(tilt.value.x), Float(tilt.value.y)),
                        .float(Float(birth))))
            }
        }
    }
}

/// La passe étoiles du ciel de la maison, seule (le champ sub-pixel de
/// `nebulaStars`, en pleine résolution — l'upscale les tuerait). Composée
/// en `plusLighter` : de la lumière ajoutée à la nuit.
struct StarDustCeiling: View {
    private var motion: SkyMotion { .shared }
    private var sky: SkyState { .shared }

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = Float(timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                let raw = min(max(timeline.date.timeIntervalSince(sky.revealStart) / 2.0, 0), 1)
                let reveal = Float(raw * raw * (3 - 2 * raw))
                let tilt = CGVector(dx: motion.tilt.dx,
                                    dy: motion.tilt.dy + sky.scroll * 0.0009)
                Rectangle()
                    .fill(.black)
                    .frame(width: w, height: h)
                    .colorEffect(ShaderLibrary.nebulaStars(
                        .float2(w, h), .float(t), .float(reveal),
                        .float2(tilt.dx, tilt.dy),
                        .image(NebulaNoise.image)))
                    .blendMode(.plusLighter)
            }
        }
    }
}

// MARK: - La carte swap

/// Une séance en pièce de collection : noir mat à reflet orange-jaune
/// (l'écrin vit dans `swapCard`, AuroraHome.metal), pastille d'icône en
/// haut, et en bas le cartouche — date gravée, grand titre, mesures.
struct SwapWorkoutCard: View {
    let workout: Workout
    /// La phase de la carte : quatre cartes, quatre reflets désynchronisés.
    var seed: Float = 0
    /// La montée du geste (0 → 1) : l'écrin s'embrase avec elle.
    var charge: Float = 0
    /// L'horodatage du dernier toucher : le néon intérieur souffle une
    /// bouffée (0,10 s d'attaque, ~0,45 s d'extinction) puis se rendort.
    var tapAt: Date = .distantPast
    /// La direction où le doigt tire (unitaire) : le foyer de lumière s'y
    /// masse à mesure que la charge monte.
    var pull: CGSize = CGSize(width: 1, height: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // En tête, à gauche : le nom seul. Rien d'autre — la carte est
            // d'abord du vide (la référence : un mot en haut, deux mesures
            // en bas, et beaucoup de noir entre les deux).
            SwapCardHeading(title: title,
                            subtitle: workout.relativeDateLabel)

            Spacer(minLength: 20)

            HStack(alignment: .top, spacing: 0) {
                stat("DURÉE", value: "\(Int(workout.duration / 60)) min")
                Spacer(minLength: 10)
                stat("EXERCICES", value: "\(workout.orderedExercises.count)")
                    .frame(width: 72, alignment: .leading)
            }
        }
        // 30 pt : le texte se tient à l'écart du tube (14 pt) et de sa nappe.
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // L'écrin vit dans le design system (SwapCardSurface.swift) depuis
        // le 2026-08-18 : même hôte, même shader, rien n'a bougé.
        .background {
            SwapCardSurface(seed: seed, charge: charge, pull: pull,
                            lit: .geste(tapAt: tapAt))
        }
    }

    private var title: String {
        workout.categories.first?.rawValue ?? "Séance"
    }

    private func stat(_ label: String, value: String) -> some View {
        SwapCardStat(label: label, value: value)
    }
}

// MARK: - Le retour du swipe

/// Ce que le corps entend et sent quand une carte s'arrache : un grave qui
/// ENFLE dans la main (0,6 s — `sensoryFeedback` ne sait faire que des coups
/// secs, il faut CoreHaptics pour une montée lente), précédé d'un choc net à
/// l'instant du décollement ; et un verre galactique qui s'ouvre en écho.
///
/// Le son est joué en `.ambient` + `mixWithOthers` : jamais par-dessus la
/// musique de la salle. **Le simulateur ne vibre pas** — la partie haptique
/// ne se juge que sur l'iPhone.
final class SwapFeedback {
    static let shared = SwapFeedback()

    private let player: AVAudioPlayer?
    private let ignitePlayer: AVAudioPlayer?
    private var engine: CHHapticEngine?

    private init() {
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        func load(_ name: String) -> AVAudioPlayer? {
            guard let url = Bundle.main.url(forResource: name,
                                            withExtension: "wav") else { return nil }
            let p = try? AVAudioPlayer(contentsOf: url)
            p?.prepareToPlay()
            return p
        }
        player = load("AuroraSwipe")
        ignitePlayer = load("NeonIgnite")

        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        // Le moteur peut être arrêté par le système (appel, arrière-plan) :
        // sans ces deux relances, la vibration disparaît en cours de session.
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        engine?.stoppedHandler = { _ in }
        try? engine?.start()
    }

    func swipe() {
        if let player {
            player.volume = 0.34
            player.currentTime = 0
            player.play()
        }
        rumble()
    }

    /// L'AMORÇAGE du tube : le petit bruit de lumière (clac d'amorce, souffle
    /// d'air, bourdon de verre qui monte) et la montée qui l'accompagne dans
    /// la main — 0,22 s, douce, très peu « sharp » : ça s'allume, ça ne
    /// claque pas. Joué UNE fois par allumage.
    func ignite() {
        if let ignitePlayer {
            ignitePlayer.volume = 0.30
            ignitePlayer.currentTime = 0
            ignitePlayer.play()
        }
        guard let engine else { return }
        let swell = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.62),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.18)
        ], relativeTime: 0, duration: 0.22)
        let shape = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.00, value: 0.10),
                .init(relativeTime: 0.07, value: 1.00),
                .init(relativeTime: 0.22, value: 0.00)
            ], relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [swell],
                                                 parameterCurves: [shape]),
              let p = try? engine.makePlayer(with: pattern) else { return }
        try? p.start(atTime: CHHapticTimeImmediate)
    }

    /// Le toucher : un coup net et court — le tube s'allume, rien de plus.
    func tap() {
        guard let engine else { return }
        let click = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
        ], relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [click], parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    /// Le grain du geste : tant que le doigt pousse, la carte « crisse »
    /// sous la main — des impulsions minuscules dont la force et la cadence
    /// montent avec la charge. Le corps sent le seuil approcher avant que
    /// l'œil ne le voie.
    func drag(charge: Float) {
        guard let engine, charge > 0.03 else { return }
        let tick = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity,
                                   value: 0.12 + 0.55 * charge),
            CHHapticEventParameter(parameterID: .hapticSharpness,
                                   value: 0.25 + 0.35 * charge)
        ], relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [tick], parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    /// Le grave : un choc bref, puis 0,6 s de continu très peu « sharp »
    /// (donc profond, pas grésillant) dont l'intensité monte en 0,14 s et
    /// retombe lentement — la carte qui s'arrache, pas un clic.
    private func rumble() {
        guard let engine else { return }
        let strike = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.42)
        ], relativeTime: 0)
        let swell = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.10)
        ], relativeTime: 0.02, duration: 0.60)
        let shape = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.00, value: 0.20),
                .init(relativeTime: 0.14, value: 1.00),
                .init(relativeTime: 0.36, value: 0.78),
                .init(relativeTime: 0.60, value: 0.00)
            ], relativeTime: 0.02)

        guard let pattern = try? CHHapticPattern(events: [strike, swell],
                                                 parameterCurves: [shape]),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? engine.start()
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    /// LE CHOC DU DÉZOOM — le plus lourd de toute l'app, et il ne s'obtient
    /// PAS avec une intensité.
    ///
    /// `.sensoryFeedback(.impact(intensity: 1))` plafonne : quoi qu'on écrive,
    /// un transitoire seul se sent comme un clic. Le POIDS vient de
    /// l'enveloppe — deux transitoires très rapprochés (le corps ne les
    /// sépare pas, il entend un coup plus gros) et une continue longue, très
    /// peu « sharp », qui décroît lentement. C'est la queue qui fait la masse ;
    /// l'attaque ne fait que la déclencher.
    ///
    /// 0,72 s au total, contre 0,60 pour `rumble()` : la carte qui se pose ne
    /// s'arrache pas, elle ATTERRIT, et un atterrissage résonne plus longtemps
    /// qu'il ne claque.
    func slam() {
        guard let engine else { return }
        let strike = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.58)
        ], relativeTime: 0)
        // Le doublon, à 35 ms : sous 50 ms le corps ne compte plus les coups,
        // il en sent UN, plus gros. Au-delà, il en compte deux et ça devient
        // un roulement.
        let echo = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.92),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.30)
        ], relativeTime: 0.035)
        let swell = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.05)
        ], relativeTime: 0.01, duration: 0.72)
        let shape = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.00, value: 1.00),
                .init(relativeTime: 0.10, value: 0.92),
                .init(relativeTime: 0.34, value: 0.55),
                .init(relativeTime: 0.72, value: 0.00)
            ], relativeTime: 0.01)

        guard let pattern = try? CHHapticPattern(events: [strike, echo, swell],
                                                 parameterCurves: [shape]),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? engine.start()
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}

#Preview {
    HomeAuroraLab()
}
