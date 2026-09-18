import Foundation

@main struct LiveChecks {
    @MainActor static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
            precondition(condition(), name)
            checks += 1
        }
        let t = Date(timeIntervalSinceReferenceDate: 900_000_000)
        let source = UUID()
        let effort = WorkoutLivePhase(kind: .effort, startedAt: t)
        expect(effort.seconds(at: t + 24) == 24, "effort date anchor")
        expect(effort.seconds(at: t - 5) == 0, "future start clamps to zero")
        let paused = WorkoutLivePhase(kind: .pause, elapsed: 74)
        expect(paused.seconds(at: t + 3600) == 74, "pause freezes active time")
        let resumed = WorkoutLivePhase(kind: .effort, startedAt: t + 100, elapsed: 74)
        expect(resumed.seconds(at: t + 106) == 80, "resume excludes pause")
        let rest = WorkoutLivePhase(kind: .rest, startedAt: t, endsAt: t + 45)
        expect(rest.seconds(at: t - 3) == 45, "rest ignition does not extend rest")
        expect(rest.seconds(at: t + 10) == 35, "rest countdown")
        expect(rest.seconds(at: t + 80) == 0, "rest never negative")
        var focus = WorkoutLiveFocus(source: source, exerciseID: "hiit-tapis", name: "Tapis · HIIT", sport: .hiit, phase: effort, set: 3, value: 16).following(nil)
        expect(focus.stages.count == 1 && focus.stages[0].value == 16, "first pace")
        expect(focus.phaseLabel(english: false) == "Effort 3", "French effort")
        expect(focus.detail(english: false) == "16 km/h", "pace unit")
        expect(focus.following(focus) == focus, "duplicate event is silent")
        var next = focus
        next.phase = .init(kind: .recovery, startedAt: t + 24)
        next.value = 7
        next = next.following(focus)
        expect(next.stages.count == 2 && next.stages.last?.recovery == true, "recovery stage")
        expect(next.revision == focus.revision + 1, "one reflection per new event")
        expect(next.phaseLabel(english: true) == "Recovery", "English recovery")
        focus = next
        for index in 0..<80 {
            next = focus
            next.value = Double(index % 20)
            focus = next.following(focus)
        }
        expect(focus.stages.count == 12, "bounded history")
        expect(Set(focus.stages.map(\.id)).count == 12, "stable unique stage IDs")
        let state = WorkoutActivityAttributes.ContentState(exerciseCount: 4, setCount: 9, volume: 1250, focus: focus, language: "fr")
        let bytes = try JSONEncoder().encode(state)
        expect(bytes.count < 3500, "payload leaves room for attributes under 4 KB")
        let decoded = try JSONDecoder().decode(WorkoutActivityAttributes.ContentState.self, from: bytes)
        expect(decoded == state, "payload round trip")
        let old = try JSONDecoder().decode(WorkoutActivityAttributes.ContentState.self, from: Data(#"{"exerciseCount":2,"setCount":3,"volume":60}"#.utf8))
        expect(old.focus == nil && old.language == nil, "legacy activity decodes")
        var swim = WorkoutLiveFocus(source: UUID(), exerciseID: "piscine", name: "Piscine", sport: .swimming, phase: effort, laps: 12, poolLength: 25)
        expect(swim.detail(english: false) == "12 longueurs · 300 m", "pool distance from entered lengths")
        swim.laps = 11
        expect(swim.detail(english: true) == "11 lengths · 275 m", "pool correction")
        expect(swim.following(focus).stages.isEmpty, "new exercise resets pace history")
        var strength = WorkoutLiveFocus(source: UUID(), exerciseID: "developpe-couche", name: "Développé couché", sport: .strength, phase: rest, set: 2)
        expect(strength.phaseLabel(english: false) == "Série 2 · Repos", "strength rest identifies set")
        expect(strength.phaseLabel(english: true, stale: true) == "Rest complete", "deadline needs no app tick")
        strength.phase.kilos = 22.5
        strength.phase.reps = 12
        expect(strength.detail(english: false) == "12 reps · 22,5 kg", "French numbers")
        expect(strength.detail(english: true) == "12 reps · 22.5 kg", "English numbers")

        // Les vrais gestes du modèle cardio : aucun doublon ni changement d'écriture.
        let hiit = SeanceTapis(mode: .hiit, naissance: t - SeanceTapis.arrivee)
        var events = 0, sets = 0, recovery = 0
        hiit.onLiveChange = { events += 1 }
        hiit.onSetFini = { _ in sets += 1 }
        hiit.onRecupFinie = { _, _ in recovery += 1 }
        expect(hiit.livePhase.startedAt == t, "HIIT anchor matches player")
        hiit.stopper(t)
        expect(events == 0 && sets == 0, "empty tap produces no event or saved set")
        hiit.vitesse = 16
        hiit.sceller(16, t + 10)
        expect(events == 1, "HIIT pace seal emits once")
        hiit.stopper(t + 24)
        expect(events == 2 && sets == 1, "HIIT stop saves once and emits")
        expect(hiit.livePhase.kind == .recovery && hiit.vitesse == 7, "recovery speed is actual player speed")
        expect(hiit.livePhase.seconds(at: t + 62) == 38, "recovery elapsed not countdown")
        hiit.relancer(t + 62)
        expect(events == 3 && recovery == 1, "restart saves recovery once")
        expect(hiit.livePhase.kind == .effort && hiit.setIndex == 2, "next effort rank")
        hiit.finir(t + 90)
        expect(events == 4 && sets == 2 && hiit.terminee, "finish flushes effort before clearing")
        hiit.finir(t + 100)
        expect(events == 4 && sets == 2, "finish idempotent")
        for mode in [ModeCardio.tapisModere, .escalier] {
            let cardio = SeanceTapis(mode: mode, naissance: t - SeanceTapis.arrivee)
            var changes = 0, segments = 0
            cardio.onLiveChange = { changes += 1 }
            cardio.onSegmentFini = { _, _, _ in segments += 1 }
            cardio.pauser(t + 60)
            expect(changes == 1 && segments == 1, "continuous pause saves actual segment")
            expect(cardio.livePhase.kind == .pause, "continuous pause phase")
            expect(cardio.livePhase.seconds(at: t + 3600) == 60, "continuous timer frozen")
            cardio.vitesse = 9
            cardio.sceller(9, t + 70)
            expect(changes == 2 && segments == 1, "paused pace does not write a fake segment")
            cardio.reprendre(t + 100)
            expect(changes == 3, "resume event")
            expect(cardio.livePhase.seconds(at: t + 120) == 80, "active time excludes pause")
            cardio.finir(t + 130)
            expect(changes == 4 && segments == 2, "continuous finish preserved")
            expect(cardio.terminee, "end propagated")
        }
        let abandoned = SeanceTapis(mode: .hiit, naissance: t)
        var endings = 0
        abandoned.onLiveChange = { endings += 1 }
        abandoned.abandonner(t + 30)
        expect(endings == 1 && abandoned.terminee, "session cancellation clears focus")
        print("PASS \(checks) checks; payload \(bytes.count) bytes; actual cardio player exercised")
    }
}
