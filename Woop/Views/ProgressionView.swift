import SwiftUI
import SwiftData
import Charts

enum Timeframe: String, CaseIterable, Identifiable {
    case week = "Semaine"
    case month = "Mois"
    var id: String { rawValue }

    var component: Calendar.Component { self == .week ? .weekOfYear : .month }
    var chartUnit: Calendar.Component { self == .week ? .weekOfYear : .month }
}

struct ProgressionView: View {
    @Query(sort: \Workout.startedAt) private var workouts: [Workout]
    @State private var timeframe: Timeframe = .week
    @State private var selectedExercise: String?

    private var calendar: Calendar { .current }
    private var finished: [Workout] { workouts.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            ZStack {
                WoopBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Picker("Période", selection: $timeframe) {
                            ForEach(Timeframe.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        if finished.isEmpty {
                            emptyState
                        } else {
                            volumeCard
                            cardioCard
                            maxWeightCard
                            SynthesisCard(workouts: finished, period: timeframe)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Progrès")
        }
    }

    private var emptyState: some View {
        WoopCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundStyle(Color.woopViolet)
                Text("Pas encore de courbes")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text("Tes performances apparaîtront ici après quelques séances.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkMuted)
            }
        }
    }

    // MARK: - Agrégation

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private func bucket(_ date: Date) -> Date {
        let parts: DateComponents = timeframe == .week
            ? calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            : calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? date
    }

    private var volumeSeries: [Point] {
        Dictionary(grouping: finished) { bucket($0.startedAt) }
            .map { Point(date: $0.key, value: $0.value.reduce(0) { $0 + $1.totalVolume }) }
            .filter { $0.value > 0 }
            .sorted { $0.date < $1.date }
    }

    private var cardioSeries: [Point] {
        Dictionary(grouping: finished) { bucket($0.startedAt) }
            .map { Point(date: $0.key, value: Double($0.value.reduce(0) { $0 + $1.cardioMinutes })) }
            .filter { $0.value > 0 }
            .sorted { $0.date < $1.date }
    }

    /// Exercices de musculation réellement pratiqués, du plus fréquent au moins fréquent.
    private var practiced: [String] {
        var counts: [String: Int] = [:]
        for workout in finished {
            for logged in workout.orderedExercises where !logged.orderedSets.isEmpty {
                counts[logged.exerciseID, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    private var currentExercise: String? { selectedExercise ?? practiced.first }

    private func maxWeightSeries(for id: String) -> [Point] {
        finished.compactMap { workout in
            let best = workout.orderedExercises
                .filter { $0.exerciseID == id }
                .map(\.maxWeight)
                .max()
            guard let best, best > 0 else { return nil }
            return Point(date: workout.startedAt, value: best)
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Cartes

    private var volumeCard: some View {
        WoopCard {
            VStack(alignment: .leading, spacing: 14) {
                chartTitle("Volume musculation", unit: "kg")
                if volumeSeries.isEmpty {
                    placeholder("Le volume (charge × répétitions) apparaîtra ici.")
                } else {
                    Chart(volumeSeries.suffix(12)) { point in
                        BarMark(
                            x: .value("Période", point.date, unit: timeframe.chartUnit),
                            y: .value("Volume", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [.woopChartStrength,
                                                    .woopChartStrength.opacity(0.35)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .cornerRadius(4)
                    }
                    .chartYAxis { axisMarks }
                    .chartXAxis { xAxisMarks }
                    .frame(height: 170)
                }
            }
        }
    }

    private var cardioCard: some View {
        WoopCard {
            VStack(alignment: .leading, spacing: 14) {
                chartTitle("Cardio", unit: "min")
                if cardioSeries.isEmpty {
                    placeholder("Tes minutes de cardio apparaîtront ici.")
                } else {
                    Chart(cardioSeries.suffix(12)) { point in
                        BarMark(
                            x: .value("Période", point.date, unit: timeframe.chartUnit),
                            y: .value("Minutes", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [.woopChartCardio,
                                                    .woopChartCardio.opacity(0.35)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .cornerRadius(4)
                    }
                    .chartYAxis { axisMarks }
                    .chartXAxis { xAxisMarks }
                    .frame(height: 150)
                }
            }
        }
    }

    @ViewBuilder
    private var maxWeightCard: some View {
        WoopCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Charge max")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    if !practiced.isEmpty {
                        Menu {
                            ForEach(practiced, id: \.self) { id in
                                Button(ExerciseCatalog.exercise(id: id)?.name ?? id) {
                                    selectedExercise = id
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(ExerciseCatalog.exercise(id: currentExercise ?? "")?.name ?? "—")
                                    .lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .font(.system(.footnote, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.woopViolet)
                        }
                    }
                }

                if let id = currentExercise {
                    let series = maxWeightSeries(for: id)
                    if series.count >= 2 {
                        let values = series.map(\.value)
                        let lo = max(0, (values.min() ?? 0) - max((values.max()! - values.min()!) * 0.3, 2.5))
                        let hi = (values.max() ?? 0) + max((values.max()! - values.min()!) * 0.3, 2.5)
                        Chart(series) { point in
                            AreaMark(
                                x: .value("Date", point.date),
                                yStart: .value("Base", lo),
                                yEnd: .value("Charge", point.value)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.woopChartStrength.opacity(0.32), .clear],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .interpolationMethod(.monotone)

                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Charge", point.value)
                            )
                            .foregroundStyle(Color.woopChartStrength)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .interpolationMethod(.monotone)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Charge", point.value)
                            )
                            .foregroundStyle(Color.woopChartStrength)
                            .symbolSize(46)
                        }
                        .chartYScale(domain: lo...hi)
                        .chartYAxis { axisMarks }
                        .chartXAxis { xAxisMarks }
                        .frame(height: 180)

                        if let first = series.first?.value, let last = series.last?.value,
                           last > first {
                            Label(
                                "+\((last - first).formatted(.number.precision(.fractionLength(0...1)))) kg depuis le début",
                                systemImage: "arrow.up.right"
                            )
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.woopGold)
                        }
                    } else {
                        placeholder("Encore une séance avec cet exercice pour tracer la courbe.")
                    }
                } else {
                    placeholder("Enregistre une série avec charge pour suivre ta progression.")
                }
            }
        }
    }

    // MARK: - Habillage des graphiques

    private func chartTitle(_ title: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            Text(unit)
                .font(.caption2)
                .foregroundStyle(Color.inkMuted)
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity, minHeight: 90)
            .multilineTextAlignment(.center)
    }

    private var axisMarks: some AxisContent {
        AxisMarks(position: .leading) { _ in
            AxisGridLine().foregroundStyle(Color.white.opacity(0.07))
            AxisValueLabel().foregroundStyle(Color.inkMuted).font(.caption2)
        }
    }

    private var xAxisMarks: some AxisContent {
        AxisMarks { _ in
            AxisValueLabel(format: timeframe == .week
                           ? Date.FormatStyle().day().month(.abbreviated)
                           : Date.FormatStyle().month(.abbreviated))
                .foregroundStyle(Color.inkMuted)
                .font(.caption2)
        }
    }
}
