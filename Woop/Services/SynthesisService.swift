import Foundation

// MARK: - Charge utile

/// Ce que l'app envoie à l'edge function. On n'envoie que des chiffres et des
/// noms d'exercices : rien qui identifie Kathryn.
struct SynthesisPayload: Encodable {
    let period: String
    let weeklyTarget: Int
    let workouts: [WorkoutSummary]
    let previous: [WorkoutSummary]

    struct WorkoutSummary: Encodable {
        let date: String
        let exercises: [ExerciseSummary]
    }

    struct ExerciseSummary: Encodable {
        let name: String
        var sets: [SetSummary]?
        var phases: [PhaseSummary]?
    }

    struct SetSummary: Encodable {
        let reps: Int
        let weight: Double
    }

    struct PhaseSummary: Encodable {
        let kind: String
        let seconds: Int
        let speed: Double
    }
}

// MARK: - Service

@Observable
final class SynthesisService {
    enum State: Equatable {
        case idle
        case loading
        case ready(String)
        case failed(String)
    }

    private(set) var state: State = .idle

    /// Construit la charge utile à partir des séances locales et interroge
    /// l'edge function, qui détient seule la clé Anthropic.
    @MainActor
    func generate(from workouts: [Workout], period: Timeframe) async {
        guard WoopConfig.isConfigured else {
            state = .failed("Renseigne l'URL et la clé Supabase pour activer la synthèse.")
            return
        }

        state = .loading

        let calendar = Calendar.current
        let now = Date.now
        let component: Calendar.Component = period == .week ? .weekOfYear : .month
        guard let currentStart = calendar.dateInterval(of: component, for: now)?.start,
              let previousStart = calendar.date(byAdding: component, value: -1, to: currentStart)
        else {
            state = .failed("Période invalide.")
            return
        }

        let current = workouts.filter { $0.startedAt >= currentStart }
        let previous = workouts.filter { $0.startedAt >= previousStart && $0.startedAt < currentStart }

        let payload = SynthesisPayload(
            period: period == .week ? "week" : "month",
            weeklyTarget: Goal.weeklyTarget,
            workouts: current.map(Self.summarize),
            previous: previous.map(Self.summarize)
        )

        do {
            let text = try await call(payload)
            state = .ready(text)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private static func summarize(_ workout: Workout) -> SynthesisPayload.WorkoutSummary {
        SynthesisPayload.WorkoutSummary(
            date: ISO8601DateFormatter().string(from: workout.startedAt),
            exercises: workout.orderedExercises.map { logged in
                SynthesisPayload.ExerciseSummary(
                    name: logged.name,
                    sets: logged.orderedSets.isEmpty ? nil : logged.orderedSets.map {
                        .init(reps: $0.reps, weight: $0.weight)
                    },
                    phases: logged.orderedPhases.isEmpty ? nil : logged.orderedPhases.map {
                        .init(kind: $0.kind.rawValue, seconds: $0.seconds, speed: $0.speed)
                    }
                )
            }
        )
    }

    private func call(_ payload: SynthesisPayload) async throws -> String {
        let token = try await SupabaseSession.shared.token()

        var request = URLRequest(
            url: WoopConfig.supabaseURL.appending(path: "functions/v1/weekly-synthesis")
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try SupabaseSession.check(response, data)

        struct Reply: Decodable {
            let synthesis: String?
            let error: String?
        }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        if let synthesis = reply.synthesis { return synthesis }
        throw SupabaseError.server(status: 502, body: reply.error ?? "réponse vide")
    }
}
