import SwiftUI
import SwiftData

/// La liste complète, atteinte depuis « Tout voir ».
struct WorkoutsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    private var finished: [Workout] { workouts.filter { !$0.isActive } }

    /// Séances groupées par mois, du plus récent au plus ancien.
    private var grouped: [(month: Date, items: [Workout])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: finished) { workout -> Date in
            let parts = calendar.dateComponents([.year, .month], from: workout.startedAt)
            return calendar.date(from: parts) ?? workout.startedAt
        }
        return dict.map { (month: $0.key, items: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.month > $1.month }
    }

    var body: some View {
        ZStack {
            WoopBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(grouped, id: \.month) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group.month.formatted(.dateTime.month(.wide).year()).capitalized)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(Color.inkSecondary)

                            ForEach(group.items) { workout in
                                NavigationLink {
                                    WorkoutDetailView(workout: workout)
                                } label: {
                                    DetailedWorkoutRow(workout: workout)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Toutes les séances")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct DetailedWorkoutRow: View {
    let workout: Workout

    var body: some View {
        WoopCard(cornerRadius: 15, padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.startedAt.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("\(workout.exerciseCount) exercice\(workout.exerciseCount > 1 ? "s" : "") · \(Int(workout.duration / 60)) min")
                            .font(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.inkMuted)
                }

                HStack(spacing: 8) {
                    if workout.totalVolume > 0 {
                        MetricPill(value: "\(Int(workout.totalVolume)) kg",
                                   tint: .woopChartStrength)
                    }
                    if workout.cardioMinutes > 0 {
                        MetricPill(value: "\(workout.cardioMinutes) min cardio",
                                   tint: .woopChartCardio)
                    }
                }
            }
        }
    }
}

struct MetricPill: View {
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }
}

// MARK: - Détail d'une séance

struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        ZStack {
            WoopBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    WoopCard(neon: true) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(workout.startedAt.formatted(date: .complete, time: .omitted).capitalized)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(Color.inkMuted)

                            HStack(spacing: 26) {
                                StatBlock(value: "\(workout.exerciseCount)", label: "exercices")
                                StatBlock(value: "\(Int(workout.duration / 60))", label: "minutes")
                                if workout.totalVolume > 0 {
                                    StatBlock(value: "\(Int(workout.totalVolume))", label: "kg")
                                }
                            }
                        }
                    }

                    Text("Exercices")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .padding(.top, 4)

                    ForEach(workout.orderedExercises) { logged in
                        LoggedExerciseCard(logged: logged)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.inkMuted)
        }
    }
}
