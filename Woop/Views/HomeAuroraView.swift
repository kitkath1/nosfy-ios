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

    /// La carte, aux mesures de la référence (≈ 207 × 265 pt) : dimensionnée
    /// à la main — un `aspectRatio` dans une pile se bat avec la hauteur du
    /// conteneur et finit par déborder — et assez basse pour que la pile,
    /// ses points ET la barre d'onglets tiennent ensemble à l'écran.
    static let cardHeight: CGFloat = 265
    static let cardWidth: CGFloat = 207
    private static let sinkStep: CGFloat = 20
    /// La hauteur du bloc : la carte, le recul des suivantes, et un peu d'air.
    static let deckHeight = cardHeight + sinkStep * 2 + 10
    /// Où se trouve le centre de la carte du dessus dans le bloc : la pile
    /// est centrée, et la carte du dessus est remontée d'un cran de recul.
    static let topCardCenterY = deckHeight / 2 - sinkStep
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

    /// La montée du geste : 0 au repos, 1 quand le doigt a décidé. C'est elle
    /// qui embrase l'écrin de la carte.
    private var charge: Float {
        Float(min(abs(drag.width) / Self.threshold, 1))
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
                    LinearGradient(stops: [
                        .init(color: .white.opacity(0.95), location: 0.0),
                        .init(color: .white.opacity(0.30), location: 0.22),
                        .init(color: .white.opacity(0.0), location: 0.55)
                    ], startPoint: .top, endPoint: .bottom)
                }
                .blur(radius: 3)
                .opacity(0.70)
                .rotationEffect(.degrees(-Double(drag.width) / 30), anchor: .top)
                .offset(x: drag.width,
                        y: Self.cardHeight - Self.sinkStep + 3 + drag.height * 0.25)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func card(_ workout: Workout, depth: Int) -> some View {
        let isTop = depth == 0
        let deepest = depth == min(workouts.count, 3) - 1 && workouts.count > 1
        let gone = workout.persistentModelID == vanished
        // Le recul des cartes de dessous : elles descendent et rétrécissent
        // à peine — juste assez pour dire « il y en a d'autres ».
        let sink = CGFloat(depth) * Self.sinkStep
        let shrink = 1 - CGFloat(depth) * 0.05

        SwapWorkoutCard(workout: workout, seed: Float(depth),
                        charge: isTop ? charge : 0,
                        tapAt: isTop ? tapAt : .distantPast,
                        pull: pull)
            .frame(width: Self.cardWidth, height: Self.cardHeight)
            // SANS ceci, seuls les GLYPHES sont tactiles : la carte est un
            // vide, le doigt passait au travers et c'est la page qui
            // scrollait. C'est toute la panne du geste.
            .contentShape(Rectangle())
            .scaleEffect(isTop ? 1 - min(abs(drag.width), 140) / 2600 : shrink)
            .offset(x: isTop ? drag.width : 0,
                    y: (isTop ? drag.height * 0.25 : 0) + sink - Self.sinkStep)
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
            // main, elle ne tourne pas autour de son nombril.
            .rotationEffect(.degrees(isTop ? Double(drag.width) / 30 : 0),
                            anchor: .bottom)
            // La carte de fond reste invisible, et celle qui vient de partir
            // aussi : ni l'une ni l'autre ne doit se voir revenir.
            .opacity(deepest || gone ? 0 : 1)
            .zIndex(Double(10 - depth))
            .animation(.spring(response: 0.46, dampingFraction: 0.80), value: topCard)
            .allowsHitTesting(isTop && !flying)
            // Le toucher allume le tube AVANT d'ouvrir : sans ce court
            // délai, la navigation emporte la carte et la bouffée ne se
            // voit jamais.
            .onTapGesture {
                guard isTop else { return }
                tapAt = .now
                SwapFeedback.shared.ignite()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    onOpen(workout)
                }
            }
            .gesture(isTop ? swipeGesture() : nil)
    }

    private func swipeGesture() -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !flying else { return }
                drag = value.translation
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

/// L'hôte de l'aurore. Depuis le 2026-08-02 c'est `bgAuroraHome` — le MÊME
/// champ que la page de connexion (mêmes rideaux, mêmes poussières, même
/// parallaxe à trois plans), à deux constantes près : la crête remonte dans le
/// cadre et la nuit se rétrécit à 40 % de la hauteur. L'ancien `homeAurora`
/// reste dans AuroraHome.metal, plus référencé.
struct AuroraFloor: View {
    @StateObject private var tilt = BgTilt()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                // L'accueil : au débouché de la cinématique de connexion, la
                // crête reçoit un surcroît qui retombe — la page répond à la
                // lumière d'où l'on vient. Zéro en temps normal.
                let welcome = ConnexionCine.welcome(at: tl.date)
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.bgAuroraHome(
                        .float2(geo.size.width, geo.size.height), .float(t),
                        .float2(Float(tilt.value.x), Float(tilt.value.y)),
                        .float(Float(welcome))))
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

    /// Marge du shader : au repos le souffle doré de l'arête tient en
    /// quelques points, mais sous le geste le halo déborde loin — un shader
    /// ne peint que dans son rectangle hôte.
    private static let pad: CGFloat = 54

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // En tête, à gauche : le nom seul. Rien d'autre — la carte est
            // d'abord du vide (la référence : un mot en haut, deux mesures
            // en bas, et beaucoup de noir entre les deux).
            // Le titre descend et respire : le tube est à 14 pt du bord et
            // sa nappe porte loin — collé en haut, le texte baignait dedans.
            Text(title)
                .font(.inter(19, .medium))
                .foregroundStyle(Color.white.opacity(0.95))
                .padding(.top, 8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(workout.relativeDateLabel)
                .font(.inter(11))
                .foregroundStyle(Color.white.opacity(0.46))
                .padding(.top, 5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

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
        .background { ecrin }
    }

    private var title: String {
        workout.categories.first?.rawValue ?? "Séance"
    }

    /// Une mesure du cartouche bas : l'étiquette murmure en capitales
    /// espacées, la valeur se pose dessous.
    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            // Relevées : à 30 % de blanc, la nappe d'or du tube les mangeait.
            Text(label)
                .font(.inter(8.5, .medium))
                .tracking(1.3)
                .foregroundStyle(Color.white.opacity(0.46))
            Text(value)
                .font(.inter(12.5))
                .foregroundStyle(Color.white.opacity(0.88))
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
                // Le tube est ÉTEINT au repos : il ne vit que du geste et du
                // toucher. Le tap y souffle une bouffée qui retombe seule.
                let since = tl.date.timeIntervalSince(tapAt)
                let pulse = since < 0 ? 0
                    : Float(min(since / 0.10, 1) * exp(-max(since - 0.10, 0) / 0.45))
                let neon = max(charge, min(pulse, 1))
                Rectangle()
                    .fill(.white)
                    .frame(width: w, height: h)
                    .colorEffect(ShaderLibrary.swapCard(
                        .float2(w, h), .float(t),
                        .float(Float(Self.pad)), .float(24), .float(seed),
                        .float(charge),
                        .float2(Float(pull.width), Float(pull.height)),
                        .float(neon)))
            }
            .offset(x: -Self.pad, y: -Self.pad)
        }
        .allowsHitTesting(false)
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
}

#Preview {
    HomeAuroraLab()
}
