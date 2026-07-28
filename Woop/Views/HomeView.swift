import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selection: WoopTab
    @Binding var showActiveSheet: Bool

    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var askStart = false
    @State private var confirmFinish = false
    @State private var showAllWorkouts = false
    @State private var showWeekDetail = false
    @State private var scrollY: CGFloat = 0

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
                WoopBackground(animated: true, scroll: scrollY)
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
                // sa profondeur — via le même vecteur que le gyroscope.
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y
                } action: { _, offset in
                    scrollY = offset
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showAllWorkouts) { WorkoutsListView() }
            .navigationDestination(isPresented: $showWeekDetail) {
                WeekDetailView(weekStart: weekStart, workouts: finished)
            }
            .sheet(isPresented: $askStart) { startSheet }
            .alert("Terminer cette séance ?", isPresented: $confirmFinish) {
                Button("Continuer la séance", role: .cancel) {}
                Button("Terminer") { finishActive() }
            } message: {
                if let activeWorkout {
                    Text("\(activeWorkout.exerciseCount) exercice\(activeWorkout.exerciseCount > 1 ? "s" : "") · \(Int(activeWorkout.duration / 60)) minutes.")
                }
            }
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

    /// Cette carte sert à consulter la progression. Elle ne démarre pas de séance :
    /// mélanger consultation et action rendrait le geste ambigu.
    private var weeklyCard: some View {
        Button { showWeekDetail = true } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Objectif hebdomadaire")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.inkSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(doneThisWeek)")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.inkPrimary)
                                .contentTransition(.numericText())
                            Text("/ \(Goal.weeklyTarget) entraînements")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.inkMuted)
                }

                TrophyRow(completed: doneThisWeek, total: Goal.weeklyTarget)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mistyMetalSurface(cornerRadius: 24, neon: doneThisWeek >= Goal.weeklyTarget)
            .overlay(SweepBorder(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action principale

    @ViewBuilder
    private var actionZone: some View {
        if let active = activeWorkout {
            WoopCard(cornerRadius: 24, padding: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        PulsingDot()
                        Text("Entraînement en cours")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                    }

                    Text("\(active.exerciseCount) exercice\(active.exerciseCount > 1 ? "s" : "") ajouté\(active.exerciseCount > 1 ? "s" : "") · commencé à \(active.startedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.inkSecondary)

                    HStack(spacing: 10) {
                        Button("Reprendre") { showActiveSheet = true }
                            .buttonStyle(WoopPrimaryButtonStyle())
                        Button("Terminer") { confirmFinish = true }
                            .buttonStyle(WoopSecondaryButtonStyle())
                            .frame(maxWidth: 130)
                    }
                }
            }
        } else {
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
                VStack(spacing: 12) {
                    ForEach(finished.prefix(4)) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            WorkoutRow(workout: workout)
                        }
                        .buttonStyle(.plain)
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

    private func finishActive() {
        guard let active = activeWorkout else { return }
        active.endedAt = .now
        try? context.save()
        let snapshot = active.snapshot()
        Task.detached { await SupabaseSync.shared.push([snapshot]) }
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

    @State private var revealed = 0
    @State private var teased: Int?

    var body: some View {
        HStack(spacing: 11) {
            ForEach(0..<total, id: \.self) { index in
                TrophySlot(
                    filled: index < revealed,
                    teasing: teased == index
                )
                .onTapGesture { tease(index) }
            }
            Spacer(minLength: 0)
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

    private var showsTrophy: Bool { filled || teasing }

    var body: some View {
        ZStack {
            Circle()
                .fill(cupFill)
                .frame(width: 44, height: 44)

            Circle()
                .strokeBorder(ring, lineWidth: 1)
                .frame(width: 44, height: 44)

            if showsTrophy {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(red: 1.0, green: 0.93, blue: 0.72),
                                                Color.woopGold],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color.woopGold.opacity(0.55), radius: 7)
                    .transition(.scale(scale: 0.25).combined(with: .opacity))
            } else {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 7, height: 7)
            }
        }
        .frame(width: 44, height: 44)
        .opacity(teasing && !filled ? 0.75 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: showsTrophy)
    }

    private var cupFill: AnyShapeStyle {
        if showsTrophy {
            return AnyShapeStyle(RadialGradient(
                colors: [Color.woopGold.opacity(0.32), Color.woopGold.opacity(0.05)],
                center: .top, startRadius: 2, endRadius: 42))
        }
        return AnyShapeStyle(LinearGradient(
            colors: [Color.black.opacity(0.55), Color.white.opacity(0.035)],
            startPoint: .top, endPoint: .bottom))
    }

    private var ring: AnyShapeStyle {
        if showsTrophy {
            return AnyShapeStyle(LinearGradient(
                stops: [.init(color: Color(red: 1, green: 0.92, blue: 0.70), location: 0),
                        .init(color: Color.woopGold.opacity(0.45), location: 0.35),
                        .init(color: Color.woopGold.opacity(0.06), location: 1)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(LinearGradient(
            stops: [.init(color: .white.opacity(0.28), location: 0),
                    .init(color: .white.opacity(0.05), location: 0.4),
                    .init(color: .white.opacity(0.0), location: 1)],
            startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

// MARK: - Ligne de séance

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.relativeDateLabel)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text(workout.rowSummary)
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.inkMuted)
        }
        .padding(16)
        .metalSurface(cornerRadius: 15)
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
