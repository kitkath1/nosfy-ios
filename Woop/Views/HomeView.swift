import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selection: WoopTab

    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var askStart = false
    @State private var showAllWorkouts = false

    private var calendar: Calendar { .current }
    private var finished: [Workout] { workouts.filter { !$0.isActive } }
    private var activeWorkout: Workout? { workouts.first { $0.isActive } }

    private var weekStart: Date {
        calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }

    private var doneThisWeek: Int {
        finished.filter { $0.startedAt >= weekStart }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WoopBackground(animated: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        greeting
                        weeklyCard
                        actionZone
                        recentSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 130)
                }
                // Parallaxe : le ciel glisse sous le contenu, chaque couche à
                // sa profondeur — même vecteur que le gyroscope. Écrit dans
                // l'état PARTAGÉ : les autres onglets gardent ce décalage, le
                // ciel ne saute jamais à la bascule.
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y
                } action: { _, offset in
                    SkyState.shared.scroll = offset
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showAllWorkouts) { WorkoutsListView() }
            .sheet(isPresented: $askStart) { startSheet }
        }
    }

    // MARK: - En-tête

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Bonjour Kathryn")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, .white.opacity(0.66)],
                                   startPoint: .top, endPoint: .bottom)
                )

            Text(contextLine)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.top, 14)
    }

    /// La phrase change avec la situation plutôt que d'afficher un compteur figé.
    private var contextLine: String {
        switch doneThisWeek {
        case 0:
            return "Nouvelle semaine. On repart à zéro."
        case 1:
            return "Première séance de la semaine effectuée."
        case Goal.weeklyTarget - 1:
            return "Plus qu'une séance pour atteindre ton objectif."
        case Goal.weeklyTarget...:
            return "Objectif hebdomadaire atteint."
        default:
            return "Tu as réalisé \(doneThisWeek) séances cette semaine."
        }
    }

    // MARK: - Progression hebdomadaire (consultation)

    /// Cette carte est purement consultative : elle ne navigue nulle part et
    /// ne démarre rien. Le Button est sans action — il n'existe que pour
    /// republier l'état pressé (le liseré s'allume sous le doigt) sans jamais
    /// gêner le scroll.
    ///
    /// Sa matière (verre noir liquide, cordon de nébuleuse, liseré) vit dans
    /// ObjectiveCard.swift — ici il n'y a que le contenu.
    private var weeklyCard: some View {
        Button {} label: {
            ObjectiveGlassCard(achieved: doneThisWeek >= Goal.weeklyTarget) {
                VStack(alignment: .leading, spacing: 0) {
                    // Corps mesurés sur la référence (carte ~353 pt de large) :
                    // titre ~15 pt, grand chiffre ~46 pt, sous-titre ~14 pt.
                    Text("Objectif hebdomadaire")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)

                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        ShimmeringNumber(value: doneThisWeek, size: 34)
                        Text("/ \(Goal.weeklyTarget) entraînements")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .padding(.top, 9)

                    TrophyRow(completed: doneThisWeek, total: Goal.weeklyTarget,
                              slotSize: 44, justified: true, luminous: true)
                        .padding(.top, 22)
                }
            }
        }
        // Le style republie isPressed : le liseré de la carte s'allume sous
        // le doigt (et petit retour haptique doux).
        .buttonStyle(ObjectiveCardPressStyle())
    }

    // MARK: - Action principale

    /// Quand une séance est ouverte, c'est l'overlay flottant (au-dessus de la
    /// barre d'onglets) qui porte reprendre/arrêter — pas de carte doublon ici.
    @ViewBuilder
    private var actionZone: some View {
        if activeWorkout == nil {
            Button("Commencer un entraînement") { askStart = true }
                .buttonStyle(WoopPrimaryButtonStyle())
        }
    }

    /// Confirmation en bottom sheet : une séance en cours ne doit jamais être
    /// écrasée par inadvertance.
    private var startSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.16))
                .frame(width: 38, height: 4)
                .padding(.top, 10)

            VStack(spacing: 12) {
                Text("Commencer une nouvelle séance ?")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)

                Text("Elle est enregistrée immédiatement : tu peux fermer l'app sans rien perdre.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 26)
            .padding(.horizontal, 26)

            VStack(spacing: 10) {
                Button("Commencer") {
                    askStart = false
                    startWorkout()
                }
                .buttonStyle(WoopPrimaryButtonStyle())

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

    // MARK: - Derniers entraînements

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Derniers entraînements",
                          action: finished.isEmpty ? nil : { showAllWorkouts = true })

            if finished.isEmpty {
                WoopCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ta progression commence avec ta première séance.")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.inkPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Elle apparaîtra ici une fois terminée.")
                            .font(.footnote)
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible())],
                          spacing: 12) {
                    ForEach(finished.prefix(4)) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            RecentWorkoutCard(workout: workout)
                        }
                        .buttonStyle(RecentCardGlowStyle())
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func startWorkout() {
        let workout = Workout()
        context.insert(workout)
        try? context.save()
        selection = .exercises
    }
}

// MARK: - Point pulsant

/// Signale une séance active. Lent et discret — pas un clignotant.
struct PulsingDot: View {
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.woopGold.opacity(0.30))
                .frame(width: 16, height: 16)
                .scaleEffect(expanded ? 1.5 : 0.8)
                .opacity(expanded ? 0 : 1)
            Circle()
                .fill(Color.woopGold)
                .frame(width: 8, height: 8)
        }
        .frame(width: 18, height: 18)
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                expanded = true
            }
        }
    }
}

// MARK: - Ronds de progression

/// Les cinq ronds de l'objectif. Vides par défaut, remplis quand la séance
/// correspondante a été terminée — l'état vient des données, pas d'un tap.
/// Toucher un rond joue une brève transformation en coupe : un retour tactile,
/// pas un changement d'état.
struct TrophyRow: View {
    let completed: Int
    let total: Int
    /// Diamètre des ronds. 44 par défaut (WeekDetail), 52 sur la carte crête.
    var slotSize: CGFloat = 44
    /// Répartis sur toute la largeur (carte crête) plutôt que tassés à gauche.
    var justified: Bool = false
    /// Style « verre noir » de la carte crête : intérieur plus sombre, halo
    /// chaud autour du rond gagné. Faux ailleurs — WeekDetail garde le rendu
    /// d'origine sur métal.
    var luminous: Bool = false

    @State private var revealed = 0
    @State private var teased: Int?

    var body: some View {
        HStack(spacing: justified ? 0 : 11) {
            ForEach(0..<total, id: \.self) { index in
                TrophySlot(
                    filled: index < revealed,
                    teasing: teased == index,
                    size: slotSize,
                    luminous: luminous
                )
                .onTapGesture { tease(index) }
                if justified && index < total - 1 { Spacer(minLength: 6) }
            }
            if !justified { Spacer(minLength: 0) }
        }
        .onAppear { animateIn() }
        .onChange(of: completed) { _, _ in animateIn() }
    }

    private func animateIn() {
        revealed = 0
        for index in 0..<min(completed, total) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(index) * 0.14) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.52)) {
                    revealed = index + 1
                }
            }
        }
    }

    private func tease(_ index: Int) {
        guard index >= revealed else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { teased = index }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.3)) { teased = nil }
        }
    }
}

struct TrophySlot: View {
    let filled: Bool
    var teasing: Bool = false
    var size: CGFloat = 44
    var luminous: Bool = false

    private var showsTrophy: Bool { filled || teasing }

    var body: some View {
        ZStack {
            Circle()
                .fill(cupFill)
                .frame(width: size, height: size)

            Circle()
                .strokeBorder(ring, lineWidth: 1)
                .frame(width: size, height: size)

            // Halo chaud du rond gagné, style verre noir uniquement : une
            // couronne diffuse HORS du trait — la récompense éclaire son
            // pourtour. Sur métal (WeekDetail) le rendu d'origine reste.
            if showsTrophy && luminous {
                Circle()
                    .stroke(Color(red: 1.0, green: 0.94, blue: 0.80).opacity(0.55),
                            lineWidth: 2)
                    .frame(width: size, height: size)
                    .blur(radius: 5)
            }

            if showsTrophy {
                // Style crème-argent sur la carte crête (la référence est
                // quasi monochrome) ; l'or d'origine partout ailleurs.
                Image(systemName: "trophy.fill")
                    .font(.system(size: size * 0.39, weight: .semibold))
                    .foregroundStyle(
                        luminous
                        ? LinearGradient(colors: [.white,
                                                  Color(red: 0.96, green: 0.92, blue: 0.80)],
                                         startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color(red: 1.0, green: 0.93, blue: 0.72),
                                                  Color.woopGold],
                                         startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: luminous
                            ? Color(red: 1.0, green: 0.95, blue: 0.80).opacity(0.50)
                            : Color.woopGold.opacity(0.55), radius: 7)
                    .transition(.scale(scale: 0.25).combined(with: .opacity))
            } else {
                Circle()
                    .fill(Color.white.opacity(luminous ? 0.07 : 0.10))
                    .frame(width: size * (luminous ? 0.115 : 0.16),
                           height: size * (luminous ? 0.115 : 0.16))
            }
        }
        .frame(width: size, height: size)
        .opacity(teasing && !filled ? 0.75 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: showsTrophy)
    }

    private var cupFill: AnyShapeStyle {
        if showsTrophy {
            if luminous {
                // Verre noir : l'intérieur reste sombre et quasi neutre, la
                // récompense vit dans l'anneau et le trophée.
                return AnyShapeStyle(RadialGradient(
                    colors: [Color(red: 1.0, green: 0.96, blue: 0.86).opacity(0.07),
                             Color.white.opacity(0.01)],
                    center: .top, startRadius: 2, endRadius: size - 2))
            }
            return AnyShapeStyle(RadialGradient(
                colors: [Color.woopGold.opacity(0.32), Color.woopGold.opacity(0.05)],
                center: .top, startRadius: 2, endRadius: size - 2))
        }
        if luminous {
            // Sur le verre noir, l'intérieur d'un rond vide EST le verre : un
            // disque plus sombre lirait « bouton éteint », pas « emplacement ».
            return AnyShapeStyle(LinearGradient(
                colors: [Color.black.opacity(0.16), Color.white.opacity(0.012)],
                startPoint: .top, endPoint: .bottom))
        }
        return AnyShapeStyle(LinearGradient(
            colors: [Color.black.opacity(0.55), Color.white.opacity(0.035)],
            startPoint: .top, endPoint: .bottom))
    }

    private var ring: AnyShapeStyle {
        if showsTrophy {
            if luminous {
                return AnyShapeStyle(LinearGradient(
                    stops: [.init(color: Color(red: 1, green: 0.97, blue: 0.88).opacity(0.90), location: 0),
                            .init(color: Color(red: 1, green: 0.94, blue: 0.78).opacity(0.38), location: 0.4),
                            .init(color: Color(red: 1, green: 0.94, blue: 0.78).opacity(0.08), location: 1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            return AnyShapeStyle(LinearGradient(
                stops: [.init(color: Color(red: 1, green: 0.92, blue: 0.70), location: 0),
                        .init(color: Color.woopGold.opacity(0.45), location: 0.35),
                        .init(color: Color.woopGold.opacity(0.06), location: 1)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if luminous {
            // Ronds vides sur verre noir : à peine là — un cercle fantôme et
            // son point, comme la référence.
            return AnyShapeStyle(LinearGradient(
                stops: [.init(color: .white.opacity(0.18), location: 0),
                        .init(color: .white.opacity(0.035), location: 0.45),
                        .init(color: .white.opacity(0.0), location: 1)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(LinearGradient(
            stops: [.init(color: .white.opacity(0.28), location: 0),
                    .init(color: .white.opacity(0.05), location: 0.4),
                    .init(color: .white.opacity(0.0), location: 1)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

// MARK: - Détail de la semaine

struct WeekDetailView: View {
    let weekStart: Date
    let workouts: [Workout]

    private var ofWeek: [Workout] {
        workouts.filter { $0.startedAt >= weekStart }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var totalMinutes: Int {
        ofWeek.reduce(0) { $0 + Int($1.duration / 60) }
    }

    private var totalSets: Int {
        ofWeek.reduce(0) { $0 + $1.orderedExercises.reduce(0) { $0 + $1.orderedSets.count } }
    }

    var body: some View {
        ZStack {
            WoopBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    WoopCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Semaine du \(weekStart.formatted(.dateTime.day().month(.wide)))")
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(Color.inkMuted)
                            HStack(spacing: 26) {
                                StatBlock(value: "\(ofWeek.count)", label: "séances")
                                StatBlock(value: "\(totalMinutes)", label: "minutes")
                                StatBlock(value: "\(totalSets)", label: "séries")
                            }
                            TrophyRow(completed: ofWeek.count, total: Goal.weeklyTarget)
                        }
                    }

                    if ofWeek.isEmpty {
                        WoopCard {
                            Text("Aucune séance cette semaine pour l'instant.")
                                .font(.footnote)
                                .foregroundStyle(Color.inkMuted)
                        }
                    } else {
                        ForEach(ofWeek) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                DetailedWorkoutRow(workout: workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Cette semaine")
        .navigationBarTitleDisplayMode(.inline)
    }
}
