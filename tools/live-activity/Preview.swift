// Banc dédié : embarquer Assets.car de la cible NosfyWidgets dans le bundle.
// Les PNG bruts seuls ne suffisent pas au rendu Image de ce banc.
import SwiftUI
import ActivityKit

@main struct PreviewApp: App {
    var body: some Scene {
        WindowGroup { PreviewScreen().preferredColorScheme(.dark) }
    }
}
struct PreviewScreen: View {
    @State private var didStart = false
    @State private var selected = 0
    private let start = Date.now.addingTimeInterval(-766)
    var cases: [(String, WorkoutActivityAttributes.ContentState)] {
        let source = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let phases: [(String, WorkoutLiveFocus)] = [
            ("muscu", .init(source: source, exerciseID: "developpe-couche", name: "Développé couché", sport: .strength, phase: .init(kind: .effort, startedAt: .now - 24), set: 2)),
            ("repos-muscu", .init(source: source, exerciseID: "developpe-couche", name: "Développé couché", sport: .strength, phase: .init(kind: .rest, startedAt: .now - 7, endsAt: .now + 38, reps: 12, kilos: 22.5), set: 2)),
            ("hiit", .init(source: source, exerciseID: "hiit-tapis", name: "Tapis · HIIT", sport: .hiit, phase: .init(kind: .effort, startedAt: .now - 24), set: 3, value: 16, stages: [.init(id: 0, value: 10, recovery: false),.init(id: 1, value: 7, recovery: true),.init(id: 2, value: 13, recovery: false),.init(id: 3, value: 7, recovery: true),.init(id: 4, value: 16, recovery: false)])),
            ("recuperation", .init(source: source, exerciseID: "hiit-tapis", name: "Tapis · HIIT", sport: .hiit, phase: .init(kind: .recovery, startedAt: .now - 38), set: 3, value: 7, stages: [.init(id: 0, value: 16, recovery: false), .init(id: 1, value: 7, recovery: true)])),
            ("pause", .init(source: source, exerciseID: "tapis-lent", name: "Tapis", sport: .treadmill, phase: .init(kind: .pause, elapsed: 754), value: 7, stages: [.init(id: 0, value: 7, recovery: false),.init(id: 1, value: 0, recovery: true)])),
            ("stairs-en", .init(source: source, exerciseID: "escalier", name: "Stair climber", sport: .stairs, phase: .init(kind: .effort, startedAt: .now - 248), value: 9, stages: [.init(id: 0, value: 6, recovery: false),.init(id: 1, value: 9, recovery: false)])),
            ("piscine", .init(source: source, exerciseID: "piscine", name: "Piscine", sport: .swimming, phase: .init(kind: .effort), laps: 12, poolLength: 25))
        ]
        return phases.enumerated().map { index, pair in
            var focus = pair.1
            focus.revision = index + 1
            return (pair.0, .init(exerciseCount: 3, setCount: 5, volume: 500, focus: focus, language: pair.0 == "stairs-en" ? "en" : "fr"))
        }
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Nosfy · Live Activity").font(.title2.weight(.semibold)).padding(.top, 20)
                if CommandLine.arguments.contains("-animation") {
                    card(cases[selected].1)
                } else {
                ForEach(cases, id: \.0) { name, state in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(name).font(.caption).foregroundStyle(.secondary)
                        card(state)
                    }
                }
                }
            }.padding(16)
        }
        .defaultScrollAnchor(CommandLine.arguments.contains("-bottom") ? .bottom : .top)
        .background(Color(white: 0.09))
        .task {
            guard !didStart else { return }
            didStart = true
            if CommandLine.arguments.contains("-animation") {
                for index in 0..<cases.count {
                    try? await Task.sleep(for: .seconds(2))
                    selected = index
                }
            }
        }
    }
    func card(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        WorkoutLiveCard(state: state, startedAt: start)
            .background(Color(red: 0.016, green: 0.016, blue: 0.024))
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
