import Foundation
import SwiftData

/// Pousse les séances terminées vers Supabase. SwiftData reste la source de
/// vérité : cette synchronisation est une sauvegarde, elle ne bloque jamais
/// l'enregistrement local et échoue silencieusement quand le réseau manque.
actor SupabaseSync {
    static let shared = SupabaseSync()

    private var inFlight = false

    // MARK: Corps des requêtes

    private struct WorkoutRow: Encodable {
        let id: String
        let user_id: String
        let started_at: String
        let ended_at: String?
        let notes: String
    }

    private struct LoggedExerciseRow: Encodable {
        let id: String
        let workout_id: String
        let user_id: String
        let exercise_id: String
        let position: Int
    }

    private struct StrengthSetRow: Encodable {
        let id: String
        let logged_exercise_id: String
        let user_id: String
        let reps: Int
        let weight: Double
        let position: Int
    }

    private struct CardioPhaseRow: Encodable {
        let id: String
        let logged_exercise_id: String
        let user_id: String
        let kind: String
        let seconds: Int
        let speed: Double
        let incline: Double
        let cycle_index: Int
        let position: Int
    }

    /// Instantané d'une séance, extrait sur le thread principal avant l'envoi.
    struct Snapshot: Sendable {
        let id: String
        let startedAt: Date
        let endedAt: Date?
        let notes: String
        var exercises: [ExerciseSnapshot]

        struct ExerciseSnapshot: Sendable {
            let id: String
            let exerciseID: String
            let position: Int
            let sets: [(id: String, reps: Int, weight: Double, position: Int)]
            let phases: [(id: String, kind: String, seconds: Int, speed: Double, incline: Double, cycleIndex: Int, position: Int)]
        }
    }

    // MARK: Envoi

    func push(_ snapshots: [Snapshot]) async {
        // Les données de démonstration ne quittent jamais l'appareil : un run
        // Xcode avec `-demoData` ne doit pas polluer un vrai compte.
        // `-syncNow` lève le garde-fou (tests de bout en bout uniquement).
        if CommandLine.arguments.contains("-demoData"),
           !CommandLine.arguments.contains("-syncNow") { return }
        guard WoopConfig.isConfigured, !snapshots.isEmpty, !inFlight else { return }
        inFlight = true
        defer { inFlight = false }

        do {
            let token = try await SupabaseSession.shared.token()
            let userID = try await SupabaseSession.shared.currentUserID()
            let iso = ISO8601DateFormatter()

            let workouts = snapshots.map {
                WorkoutRow(id: $0.id, user_id: userID,
                           started_at: iso.string(from: $0.startedAt),
                           ended_at: $0.endedAt.map(iso.string(from:)),
                           notes: $0.notes)
            }
            let exercises = snapshots.flatMap { snapshot in
                snapshot.exercises.map {
                    LoggedExerciseRow(id: $0.id, workout_id: snapshot.id, user_id: userID,
                                      exercise_id: $0.exerciseID, position: $0.position)
                }
            }
            let sets = snapshots.flatMap(\.exercises).flatMap { exercise in
                exercise.sets.map {
                    StrengthSetRow(id: $0.id, logged_exercise_id: exercise.id, user_id: userID,
                                   reps: $0.reps, weight: $0.weight, position: $0.position)
                }
            }
            let phases = snapshots.flatMap(\.exercises).flatMap { exercise in
                exercise.phases.map {
                    CardioPhaseRow(id: $0.id, logged_exercise_id: exercise.id, user_id: userID,
                                   kind: $0.kind, seconds: $0.seconds, speed: $0.speed,
                                   incline: $0.incline, cycle_index: $0.cycleIndex,
                                   position: $0.position)
                }
            }

            // L'ordre compte : les clés étrangères pointent vers la table précédente.
            try await upsert(workouts, into: "workouts", token: token)
            try await upsert(exercises, into: "logged_exercises", token: token)
            try await upsert(sets, into: "strength_sets", token: token)
            try await upsert(phases, into: "cardio_phases", token: token)
        } catch {
            // La séance est déjà enregistrée localement : on réessaiera au prochain envoi.
            await SupabaseSession.shared.invalidate()
            print("Synchronisation Supabase différée : \(error.localizedDescription)")
        }
    }

    private func upsert<T: Encodable>(_ rows: [T], into table: String, token: String) async throws {
        guard !rows.isEmpty else { return }

        var request = URLRequest(url: WoopConfig.supabaseURL.appending(path: "rest/v1/\(table)"))
        request.httpMethod = "POST"
        request.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Réenvoyer une séance déjà poussée doit la mettre à jour, pas échouer.
        request.setValue("resolution=merge-duplicates,return=minimal",
                         forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(rows)

        let (data, response) = try await URLSession.shared.data(for: request)
        try SupabaseSession.check(response, data)
    }
}

// MARK: - Extraction depuis SwiftData

extension Workout {
    /// Fige la séance dans une structure transportable, pour pouvoir l'envoyer
    /// depuis un contexte détaché sans traîner les objets SwiftData.
    @MainActor
    func snapshot() -> SupabaseSync.Snapshot {
        SupabaseSync.Snapshot(
            id: remoteID.uuidString,
            startedAt: startedAt,
            endedAt: endedAt,
            notes: notes,
            exercises: orderedExercises.map { logged in
                .init(
                    id: logged.remoteID.uuidString,
                    exerciseID: logged.exerciseID,
                    position: logged.order,
                    sets: logged.orderedSets.map {
                        (id: $0.remoteID.uuidString, reps: $0.reps,
                         weight: $0.weight, position: $0.order)
                    },
                    phases: logged.orderedPhases.map {
                        (id: $0.remoteID.uuidString, kind: $0.kindRaw, seconds: $0.seconds,
                         speed: $0.speed, incline: $0.incline,
                         cycleIndex: $0.cycleIndex, position: $0.order)
                    }
                )
            }
        )
    }
}
