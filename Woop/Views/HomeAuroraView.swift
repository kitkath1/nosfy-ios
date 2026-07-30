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

    var body: some View {
        if Self.deckOnly {
            SwapDeckLab().preferredColorScheme(.dark)
        } else {
            HomeAuroraView(selection: $selection)
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
            VStack(spacing: 22) {
                SwapDeck(workouts: deck, topCard: $topCard) { _ in }
                HStack(spacing: 9) {
                    ForEach(deck.indices, id: \.self) { index in
                        let current = deck.isEmpty ? 0 : topCard % deck.count
                        Circle()
                            .fill(index == current
                                  ? Color(red: 1.0, green: 0.78, blue: 0.45)
                                  : Color.white.opacity(0.16))
                            .frame(width: index == current ? 7 : 5,
                                   height: index == current ? 7 : 5)
                    }
                }
            }
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

    private var finished: [Workout] { workouts.filter { !$0.isActive } }
    private var activeWorkout: Workout? { workouts.first { $0.isActive } }
    private var swapped: [Workout] { Array(finished.prefix(4)) }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }

    private var doneThisWeek: Int {
        finished.filter { $0.startedAt >= weekStart }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraHomeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Group {
                            greeting
                            weeklyCard
                            actionZone
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
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showAllWorkouts) { WorkoutsListView() }
            .navigationDestination(item: $opened) { WorkoutDetailView(workout: $0) }
            .sheet(isPresented: $askStart) { startSheet }
        }
    }

    // MARK: En-tête, objectif, CTA — la home noire, à l'identique

    private var greeting: some View {
        Text("Bonjour Kathryn")
            .font(.inter(30, .semibold))
            .tracking(-0.3)
            .foregroundStyle(WoopGradient.silverText)
            .padding(.top, 14)
    }

    private var weeklyCard: some View {
        Button {} label: {
            ObjectiveGlassCard(achieved: doneThisWeek >= Goal.weeklyTarget) {
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
        .buttonStyle(ObjectiveCardPressStyle())
    }

    @ViewBuilder
    private var actionZone: some View {
        if activeWorkout == nil {
            // La fumée d'échappée en or léger : la cohérence avec la page
            // de connexion aurora.
            DiamondPrimaryButton(title: "Commencer un entraînement",
                                 smokeWarmth: 0.4) { askStart = true }
        }
    }

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
                          action: finished.isEmpty ? nil : { showAllWorkouts = true })
                .padding(.horizontal, 20)

            Text("Ta collection d'entraînements")
                .font(.inter(13))
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, 20)

            if swapped.isEmpty {
                WoopCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ta progression commence avec ta première séance.")
                            .font(.inter(14, .medium))
                            .foregroundStyle(Color.inkPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Elle apparaîtra ici une fois terminée.")
                            .font(.inter(13))
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            } else {
                SwapDeck(workouts: swapped, topCard: $topCard) { opened = $0 }
                    .padding(.top, 16)
                dots
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }
        }
        .padding(.top, 4)
    }

    /// Les points de la pile : celui de la carte du dessus s'allume d'or.
    private var dots: some View {
        HStack(spacing: 9) {
            ForEach(swapped.indices, id: \.self) { index in
                let current = swapped.isEmpty ? 0 : topCard % swapped.count
                Circle()
                    .fill(index == current
                          ? Color(red: 1.0, green: 0.78, blue: 0.45)
                          : Color.white.opacity(0.16))
                    .frame(width: index == current ? 7 : 5,
                           height: index == current ? 7 : 5)
                    .animation(.easeOut(duration: 0.25), value: topCard)
            }
        }
    }
}

// MARK: - La pile qu'on swipe

/// Les séances en pile, comme un jeu de cartes qu'on écarte du pouce : la
/// carte du dessus suit le doigt et s'incline, celle de dessous attend,
/// déjà visible — on sait qu'il y en a une autre. Passé le seuil, la carte
/// part en volée et la suivante monte à sa place. Rien ne se perd : la
/// pile tourne en boucle.
struct SwapDeck: View {
    let workouts: [Workout]
    @Binding var topCard: Int
    var onOpen: (Workout) -> Void

    /// Le déplacement du doigt sur la carte du dessus.
    @State private var drag: CGSize = SwapDeck.benchSwipe
        ? CGSize(width: 128, height: -18) : .zero
    /// Pendant la volée, plus rien ne répond : une carte à la fois.
    @State private var flying = false
    @State private var swipes = 0

    /// Au-delà, le doigt a décidé : la carte part.
    private static let threshold: CGFloat = 96

    /// Les cartes visibles, de la plus profonde à celle du dessus (l'ordre
    /// de rendu). La plus profonde est transparente : c'est là que la carte
    /// qui vient de partir revient, sans jamais se voir traverser l'écran.
    private var slots: [(depth: Int, workout: Workout)] {
        guard !workouts.isEmpty else { return [] }
        let shown = min(workouts.count, 3)
        return (0..<shown).reversed().map { depth in
            (depth, workouts[(topCard + depth) % workouts.count])
        }
    }

    /// La carte : haute et étroite comme la référence, dimensionnée à la
    /// main — un `aspectRatio` dans une pile se bat avec la hauteur du
    /// conteneur et finit par déborder.
    private static let ratio: CGFloat = 0.80     // largeur / hauteur
    private static let sinkStep: CGFloat = 22
    /// Le banc fige la carte du dessus en plein geste (`-deckSwiped`) : la
    /// suivante doit se lire comme « prête », sans avoir à tenir le doigt.
    private static let benchSwipe = CommandLine.arguments.contains("-deckSwiped")

    var body: some View {
        GeometryReader { geo in
            let w = min(geo.size.width * 0.72, 320)
            ZStack {
                ForEach(slots, id: \.workout.persistentModelID) { slot in
                    card(slot.workout, depth: slot.depth,
                         size: CGSize(width: w, height: w / Self.ratio))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .frame(height: UIScreen.main.bounds.width * 0.72 / Self.ratio
               + Self.sinkStep * 2 + 8)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: swipes)
    }

    @ViewBuilder
    private func card(_ workout: Workout, depth: Int, size: CGSize) -> some View {
        let isTop = depth == 0
        let deepest = depth == min(workouts.count, 3) - 1 && workouts.count > 1
        // Le recul des cartes de dessous : elles descendent et rétrécissent
        // à peine — juste assez pour dire « il y en a d'autres ».
        let sink = CGFloat(depth) * Self.sinkStep
        let shrink = 1 - CGFloat(depth) * 0.05

        SwapWorkoutCard(workout: workout, seed: Float(depth))
            .frame(width: size.width, height: size.height)
            .scaleEffect(isTop ? 1 - min(abs(drag.width), 140) / 2600 : shrink)
            .offset(x: isTop ? drag.width : 0,
                    y: (isTop ? drag.height * 0.25 : 0) + sink)
            // Le pivot est BAS : la carte bascule dans la main, elle ne
            // tourne pas autour de son nombril.
            .rotationEffect(.degrees(isTop ? Double(drag.width) / 20 : 0),
                            anchor: .bottom)
            // La carte de fond reste invisible : c'est le siège de celle qui
            // vient de partir, elle ne doit jamais se voir revenir.
            .opacity(deepest ? 0 : 1)
            .zIndex(Double(10 - depth))
            .animation(.spring(response: 0.42, dampingFraction: 0.78), value: topCard)
            .allowsHitTesting(isTop && !flying)
            .onTapGesture { if isTop { onOpen(workout) } }
            .gesture(isTop ? swipeGesture(width: size.width) : nil)
    }

    private func swipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !flying else { return }
                drag = value.translation
            }
            .onEnded { value in
                guard !flying else { return }
                let go = abs(value.translation.width) > Self.threshold
                    || abs(value.predictedEndTranslation.width) > 220
                guard go else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                        drag = .zero
                    }
                    return
                }
                // La volée : la carte sort par le côté qu'a choisi le doigt,
                // puis la pile tourne d'un cran SANS animation — la carte
                // partie reprend sa place au fond, invisible.
                flying = true
                swipes += 1
                let side: CGFloat = value.translation.width > 0 ? 1 : -1
                withAnimation(.easeOut(duration: 0.26)) {
                    drag = CGSize(width: side * (width + 260),
                                  height: value.translation.height * 0.5)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.27) {
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        topCard = (topCard + 1) % max(workouts.count, 1)
                        drag = .zero
                    }
                    flying = false
                }
            }
    }
}

// MARK: - Le ciel réchauffé

/// La nuit de la page : noir absolu, l'aurore de la connexion qui monte du
/// bas — les mêmes tons de la photo, mais en murmure : elle n'est qu'un sol
/// sous le contenu — et, gardées du ciel d'origine, les poussières
/// d'étoiles du HAUT (la passe `nebulaStars` seule : la nébuleuse, elle, a
/// laissé la place à l'aurore).
struct AuroraHomeBackground: View {
    var body: some View {
        ZStack {
            Color.black

            AuroraFloor()

            // Les particules du haut : le champ d'étoiles du ciel de la
            // maison, éteint avant le bas pour laisser l'aurore seule.
            StarDustCeiling()
                .mask {
                    LinearGradient(stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: .white.opacity(0.55), location: 0.16),
                        .init(color: .clear, location: 0.36)
                    ], startPoint: .top, endPoint: .bottom)
                }

            WoopGrain()
        }
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// L'hôte du shader `homeAurora`.
struct AuroraFloor: View {
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.homeAurora(
                        .float2(geo.size.width, geo.size.height), .float(t)))
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

    /// Marge du shader : le souffle doré de l'arête vit à peine dehors.
    private static let pad: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // En tête, à gauche : le nom seul. Rien d'autre — la carte est
            // d'abord du vide (la référence : un mot en haut, deux mesures
            // en bas, et beaucoup de noir entre les deux).
            Text(title)
                .font(.inter(21, .medium))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(workout.relativeDateLabel)
                .font(.inter(11.5))
                .foregroundStyle(Color.white.opacity(0.34))
                .padding(.top, 6)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 24)

            HStack(alignment: .top, spacing: 0) {
                stat("DURÉE", value: "\(Int(workout.duration / 60)) min")
                Spacer(minLength: 12)
                stat("EXERCICES", value: "\(workout.orderedExercises.count)")
                    .frame(width: 96, alignment: .leading)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background { ecrin }
    }

    private var title: String {
        workout.categories.first?.rawValue ?? "Séance"
    }

    /// Une mesure du cartouche bas : l'étiquette murmure en capitales
    /// espacées, la valeur se pose dessous.
    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.inter(9, .medium))
                .tracking(1.6)
                .foregroundStyle(Color.white.opacity(0.30))
            Text(value)
                .font(.inter(13.5))
                .foregroundStyle(Color.white.opacity(0.78))
        }
        // Un chiffre ne se plie jamais : « 52 min » est un bloc.
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var ecrin: some View {
        GeometryReader { geo in
            let w = geo.size.width + Self.pad * 2
            let h = geo.size.height + Self.pad * 2
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                Rectangle()
                    .fill(.white)
                    .frame(width: w, height: h)
                    .colorEffect(ShaderLibrary.swapCard(
                        .float2(w, h), .float(t),
                        .float(Float(Self.pad)), .float(26), .float(seed)))
            }
            .offset(x: -Self.pad, y: -Self.pad)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    HomeAuroraLab()
}
