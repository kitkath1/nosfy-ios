import ActivityKit
import Foundation

/// Les données de la Live Activity « séance en cours ». Fichier partagé entre
/// l'app (qui pilote start/update/end) et l'extension (qui dessine l'île et
/// l'écran verrouillé). Le chrono n'est PAS ici : il dérive tout seul de
/// `startedAt` côté rendu, sans aucune mise à jour.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseCount: Int
        var setCount: Int
        /// Volume total en kilogrammes, arrondi.
        var volume: Int
    }

    /// Le début de la séance, figé pour toute la vie de l'activity.
    var startedAt: Date
}
