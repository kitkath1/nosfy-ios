import ActivityKit
import Foundation

/// Pilote la Live Activity de la séance en cours : l'app est seule maîtresse
/// du cycle (démarrage, mises à jour aux événements réels — série cochée,
/// exercice ajouté — et fin). Le chrono, lui, tourne sans nous.
@MainActor
enum WorkoutActivityController {
    /// Démarre l'activity pour une séance qui vient d'ouvrir (ou la resynchronise
    /// si le système en garde une). À appeler aussi au lancement de l'app :
    /// une séance restée ouverte doit retrouver son île.
    static func ensure(_ workout: Workout?) {
        guard let workout else {
            end()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if Activity<WorkoutActivityAttributes>.activities.isEmpty {
            let attributes = WorkoutActivityAttributes(startedAt: workout.startedAt)
            _ = try? Activity.request(
                attributes: attributes,
                content: .init(state: state(for: workout), staleDate: nil)
            )
        } else {
            sync(workout)
        }
    }

    /// Pousse l'état courant — c'est cette update qui fait « vivre » l'orbe
    /// (le système anime la transition entre deux instantanés).
    static func sync(_ workout: Workout) {
        let content = ActivityContent(state: state(for: workout), staleDate: nil)
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.update(content)
            }
        }
    }

    /// Termine toutes les activities (séance finie ou annulée).
    static func end() {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
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
