import SwiftUI
import SwiftData

/// Le calendrier n'est plus un onglet : il vit DANS Progression, sous les
/// courbes. C'est sa place naturelle — la grille du mois donne un contexte
/// visuel aux graphiques, et l'app descend à quatre onglets, ce qui libère le
/// centre de la barre pour le bouton de séance.
///
/// La vue n'a donc plus de chrome à elle : ni `NavigationStack`, ni fond, ni
/// `ScrollView` — elle s'insère dans ceux de son hôte. Elle garde en revanche
/// sa propre `@Query` et son propre état de mois : le mois affiché n'a rien à
/// voir avec la période choisie pour les courbes.
struct CalendarSection: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @State private var monthAnchor: Date = .now
    @State private var selectedDay: Date?

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // lundi
        return c
    }

    private var finished: [Workout] { workouts.filter { !$0.isActive } }

    /// Séances indexées par jour, pour un accès direct dans la grille.
    private var byDay: [Date: [Workout]] {
        Dictionary(grouping: finished) { calendar.startOfDay(for: $0.startedAt) }
    }

    var body: some View {
        VStack(spacing: 18) {
            monthCard
            if let selectedDay {
                daySection(selectedDay)
            }
            streakCard
        }
    }

    // MARK: - Grille du mois

    private var monthCard: some View {
        WoopCard {
            VStack(spacing: 16) {
                HStack {
                    Button { shiftMonth(-1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.woopViolet)
                            .frame(width: 34, height: 34)
                    }
                    Spacer()
                    Text(monthAnchor.formatted(.dateTime.month(.wide).year()).capitalized)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    Button { shiftMonth(1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.woopViolet)
                            .frame(width: 34, height: 34)
                    }
                }

                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                          spacing: 8) {
                    ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            DayCell(
                                date: day,
                                count: byDay[calendar.startOfDay(for: day)]?.count ?? 0,
                                isToday: calendar.isDateInToday(day),
                                isSelected: selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false,
                                goalWeek: reachedGoal(weekOf: day)
                            )
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedDay = (selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false)
                                        ? nil : day
                                }
                            }
                        } else {
                            Color.clear.frame(height: 38)
                        }
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first]).map { String($0.prefix(2)) }
    }

    /// Les cases du mois, précédées des cases vides d'alignement.
    private var gridDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: interval.start))
        }
        return cells
    }

    /// Vrai si la semaine contenant ce jour compte au moins l'objectif de séances.
    private func reachedGoal(weekOf day: Date) -> Bool {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: day) else { return false }
        let count = finished.filter { interval.contains($0.startedAt) }.count
        return count >= Goal.weeklyTarget
    }

    private func shiftMonth(_ delta: Int) {
        withAnimation(.easeOut(duration: 0.2)) {
            monthAnchor = calendar.date(byAdding: .month, value: delta, to: monthAnchor) ?? monthAnchor
            selectedDay = nil
        }
    }

    // MARK: - Détail du jour

    @ViewBuilder
    private func daySection(_ day: Date) -> some View {
        let items = byDay[calendar.startOfDay(for: day)] ?? []
        VStack(alignment: .leading, spacing: 12) {
            Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if items.isEmpty {
                WoopCard(cornerRadius: 15, padding: 16) {
                    Text("Aucune séance ce jour-là.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkMuted)
                }
            } else {
                ForEach(items) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        DetailedWorkoutRow(workout: workout)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Série en cours

    private var streakCard: some View {
        WoopCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.woopGold.opacity(0.14)).frame(width: 44, height: 44)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.woopGold)
                        .neonGlow(.woopGold, radius: 7, opacity: 0.5)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak) semaine\(streak > 1 ? "s" : "") d'affilée")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text("Au moins une séance par semaine.")
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
            }
        }
    }

    /// Nombre de semaines consécutives (celle en cours ou la précédente incluse)
    /// comptant au moins une séance.
    private var streak: Int {
        let weeks = Set(finished.map { workout -> Date in
            let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear],
                                                from: workout.startedAt)
            return calendar.date(from: parts) ?? workout.startedAt
        })
        guard !weeks.isEmpty else { return 0 }

        var cursor = calendar.date(from: calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .now
        if !weeks.contains(cursor) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor)
            else { return 0 }
            cursor = previous
        }
        var count = 0
        while weeks.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor)
            else { break }
            cursor = previous
        }
        return count
    }
}

// MARK: - Case du calendrier

struct DayCell: View {
    let date: Date
    let count: Int
    let isToday: Bool
    let isSelected: Bool
    /// L'objectif hebdomadaire a été atteint sur la semaine de ce jour.
    var goalWeek: Bool = false

    private var day: String {
        "\(Calendar.current.component(.day, from: date))"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(day)
                .font(.system(size: 13, weight: count > 0 ? .semibold : .regular, design: .rounded))
                .foregroundStyle(count > 0 ? Color.inkPrimary : Color.inkMuted)

            // Point blanc pour une séance ordinaire, doré quand l'objectif de la
            // semaine est atteint. Le rouge évoquerait une erreur.
            HStack(spacing: 2) {
                ForEach(0..<min(count, 3), id: \.self) { _ in
                    Circle()
                        .fill(goalWeek ? Color.woopGold : Color.white.opacity(0.85))
                        .frame(width: 4, height: 4)
                        .shadow(color: goalWeek ? Color.woopGold.opacity(0.7)
                                                : Color.white.opacity(0.4), radius: 3)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.woopVioletCore.opacity(0.22))
            } else if count > 0 {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            }
        }
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.woopViolet.opacity(0.65), lineWidth: 1)
            } else if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.woopViolet.opacity(0.4), lineWidth: 1)
            }
        }
    }
}
