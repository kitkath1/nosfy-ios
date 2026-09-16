import ActivityKit
import Foundation
import OSLog

/// Pilote la Live Activity de la séance en cours : l'app est seule maîtresse
/// du cycle (démarrage, mises à jour aux événements réels — série cochée,
/// exercice ajouté — et fin). Le chrono, lui, tourne sans nous.
@MainActor
enum WorkoutActivityController {
    private static let log = Logger(subsystem: "fr.kathryn.woop", category: "LiveActivity")
    /// Activity.activities peut se rafraîchir après le retour de request.
    private static var courante: Activity<WorkoutActivityAttributes>?

    private static var connues: [Activity<WorkoutActivityAttributes>] {
        var result = Activity<WorkoutActivityAttributes>.activities
        if let courante, !result.contains(where: { $0.id == courante.id }) {
            result.append(courante)
        }
        return result.filter { $0.activityState == .active || $0.activityState == .stale }
    }

    /// Démarre l'activity pour une séance qui vient d'ouvrir (ou la resynchronise
    /// si le système en garde une). À appeler aussi au lancement de l'app :
    /// une séance restée ouverte doit retrouver son île.
    static func ensure(_ workout: Workout?) {
        guard let workout else {
            end()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let activities = connues
        let content = ActivityContent(state: state(for: workout), staleDate: nil)
        if let activity = activities.first(where: {
            $0.attributes.startedAt == workout.startedAt
        }) {
            courante = activity
            // Restaurer aussi la présentation / son lien après une mise à
            // jour de l'app, même si les chiffres de séance n'ont pas bougé.
            Task { await activity.update(content) }
        } else {
            courante = nil
            let attributes = WorkoutActivityAttributes(startedAt: workout.startedAt)
            do {
                courante = try Activity.request(attributes: attributes, content: content)
            } catch {
                log.error("Démarrage de l'île refusé : \(error.localizedDescription, privacy: .public)")
            }
        }
        // Une séance restaurée ne doit pas reprendre le chrono d'une ancienne.
        let anciennes = activities.filter { $0.id != courante?.id }
        Task {
            for activity in anciennes {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Pousse l'état courant — c'est cette update qui fait « vivre » l'orbe
    /// (le système anime la transition entre deux instantanés).
    static func sync(_ workout: Workout) {
        // Une activité fermée par l'utilisatrice ne renaît pas à chaque série.
        // La création appartient au démarrage / à la restauration de séance.
        let activities = connues.filter { $0.attributes.startedAt == workout.startedAt }
        let content = ActivityContent(state: state(for: workout), staleDate: nil)
        Task {
            for activity in activities where activity.content.state != content.state {
                await activity.update(content)
            }
        }
    }

    /// Termine toutes les activities (séance finie ou annulée).
    static func end() {
        // Capturer AVANT le Task : une fin différée ne doit jamais terminer
        // une nouvelle séance démarrée entre-temps.
        let activities = connues
        courante = nil
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func state(for workout: Workout) -> WorkoutActivityAttributes.ContentState {
        .init(exerciseCount: workout.exerciseCount,
              setCount: workout.setCount,
              volume: Int(workout.totalVolume))
    }
}
