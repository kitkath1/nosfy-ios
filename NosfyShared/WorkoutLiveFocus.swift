import Foundation

/// Un instantané d'un exercice réellement lancé. Dates, jamais de tick envoyé.
struct WorkoutLivePhase: Codable, Hashable {
    enum Kind: String, Codable { case effort, recovery, pause, rest, logging, ready }
    var kind: Kind
    var startedAt: Date? = nil
    var endsAt: Date? = nil
    var elapsed: TimeInterval = 0
    var reps: Int? = nil
    var kilos: Double? = nil

    func seconds(at date: Date) -> Int {
        if let end = endsAt {
            let from = max(startedAt ?? date, date)
            return max(0, Int(ceil(end.timeIntervalSince(from))))
        }
        return max(0, Int(elapsed + (startedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)))
    }
}

struct WorkoutLiveFocus: Codable, Hashable {
    enum Sport: String, Codable { case strength, hiit, treadmill, stairs, swimming }
    struct Stage: Codable, Hashable, Identifiable {
        var id: Int
        var value: Double
        var recovery: Bool
    }
    var source: UUID
    var exerciseID: String
    var name: String
    var sport: Sport
    var phase: WorkoutLivePhase
    var set: Int? = nil
    var value: Double? = nil
    var laps: Int? = nil
    var poolLength: Int? = nil
    var stages: [Stage] = []
    var revision: Int = 0

    var isCardio: Bool { sport == .hiit || sport == .treadmill || sport == .stairs }
    var calm: Bool { phase.kind != .effort }

    /// Au plus douze allures, identités stables et aucun échantillonnage temporel.
    func following(_ previous: Self?) -> Self {
        var next = self
        let previous = previous?.source == source ? previous : nil
        next.stages = previous?.stages ?? []
        if isCardio, let value {
            let recovery = phase.kind != .effort
            if previous == nil || previous?.phase.kind != phase.kind
                || previous?.phase.startedAt != phase.startedAt || previous?.value != value {
                let stage = Stage(id: (next.stages.last?.id ?? -1) + 1,
                                  value: phase.kind == .pause ? 0 : value,
                                  recovery: recovery)
                next.stages = Array((next.stages + [stage]).suffix(12))
            }
        }
        next.revision = previous?.revision ?? 0
        if next != previous { next.revision += 1 }
        return next
    }

    func phaseLabel(english: Bool, stale: Bool = false) -> String {
        switch phase.kind {
        case .effort:
            if sport == .strength { return "\(english ? "Set" : "Série") \(set ?? 1)" }
            if sport == .hiit { return "Effort \(set ?? 1)" }
            return english ? "In progress" : "En cours"
        case .recovery: return english ? "Recovery" : "Récupération"
        case .pause: return english ? "Paused" : "En pause"
        case .rest:
            return stale ? (english ? "Rest complete" : "Repos terminé")
                : "\(english ? "Set" : "Série") \(set ?? 1) · \(english ? "Rest" : "Repos")"
        case .logging: return english ? "Log your set" : "Saisie de la série"
        case .ready: return english ? "Set complete" : "Série terminée"
        }
    }

    func detail(english: Bool) -> String? {
        let locale = Locale(identifier: english ? "en_US" : "fr_FR")
        func number(_ n: Double) -> String {
            n.formatted(.number.locale(locale).precision(.fractionLength(0...1)))
        }
        if sport == .swimming, let laps, let poolLength {
            return "\(laps) \(english ? (laps == 1 ? "length" : "lengths") : (laps == 1 ? "longueur" : "longueurs")) · \(laps * poolLength) m"
        }
        if let value {
            return sport == .stairs ? "\(english ? "Level" : "Niveau") \(number(value))"
                : "\(number(value)) km/h"
        }
        if let reps = phase.reps, let kilos = phase.kilos {
            return "\(reps) reps · \(number(kilos)) kg"
        }
        return nil
    }
}
