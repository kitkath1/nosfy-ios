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
    private static var focused: (session: Date, value: WorkoutLiveFocus)?
    private static var requestedSession: Date?
    private static var stoppedSessions: Set<Date> = []
    private static var updates: Task<Void, Never>?

    /// Seuls les gestes du player choisissent l'exercice, jamais une fiche consultée.
    static func show(_ focus: WorkoutLiveFocus, for workout: Workout) {
        guard workout.isActive, !stoppedSessions.contains(workout.startedAt) else { return }
        let previous = focused?.session == workout.startedAt ? focused?.value : nil
        focused = (workout.startedAt, focus.following(previous))
        ensure(workout)
    }

    /// Une ancienne vue ne peut pas effacer l'exercice lancé après elle.
    static func clearFocus(source: UUID, for workout: Workout?) {
        guard focused?.value.source == source else { return }
        focused = nil
        if let workout, workout.isActive { sync(workout) }
    }

    private static func enqueue(_ action: @escaping @MainActor () async -> Void) {
        let previous = updates
        updates = Task { @MainActor in
            await previous?.value
            guard !Task.isCancelled else { return }
            await action()
        }
    }

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
        guard workout.isActive else {
            end(session: workout.startedAt)
            return
        }
        guard !stoppedSessions.contains(workout.startedAt) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let activities = connues
        let state = state(for: workout)
        let content = ActivityContent(state: state, staleDate: state.focus?.phase.endsAt)
        if let activity = activities.first(where: {
            $0.attributes.startedAt == workout.startedAt
        }) {
            courante = activity
            // Restaurer aussi la présentation / son lien après une mise à
            // jour de l'app, même si les chiffres de séance n'ont pas bougé.
            requestedSession = workout.startedAt
            enqueue {
                guard !stoppedSessions.contains(activity.attributes.startedAt) else { return }
                guard activity.activityState == .active || activity.activityState == .stale else { return }
                if activity.content.state != content.state { await activity.update(content) }
            }
        } else {
            // Un geste ultérieur ne ressuscite pas une carte balayée par l'utilisatrice.
            guard requestedSession != workout.startedAt else { return }
            courante = nil
            let attributes = WorkoutActivityAttributes(startedAt: workout.startedAt)
            do {
                courante = try Activity.request(attributes: attributes, content: content)
                requestedSession = workout.startedAt
            } catch {
                log.error("Démarrage de l'île refusé : \(error.localizedDescription, privacy: .public)")
            }
        }
        // Une séance restaurée ne doit pas reprendre le chrono d'une ancienne.
        let anciennes = activities.filter { $0.id != courante?.id }
        enqueue {
            for activity in anciennes {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Pousse les faits acquis en conservant le contexte du player en cours.
    static func sync(_ workout: Workout) {
        guard workout.isActive, !stoppedSessions.contains(workout.startedAt) else {
            end(session: workout.startedAt)
            return
        }
        // Une activité fermée par l'utilisatrice ne renaît pas à chaque série.
        // La création appartient au démarrage / à la restauration de séance.
        let activities = connues.filter { $0.attributes.startedAt == workout.startedAt }
        let state = state(for: workout)
        let content = ActivityContent(state: state, staleDate: state.focus?.phase.endsAt)
        enqueue {
            guard !stoppedSessions.contains(workout.startedAt) else { return }
            for activity in activities where activity.content.state != content.state
                && (activity.activityState == .active || activity.activityState == .stale) {
                await activity.update(content)
            }
        }
    }

    /// Termine toutes les activities (séance finie ou annulée).
    static func end() {
        end(session: nil)
    }

    private static func end(session: Date?) {
        // Capturer AVANT le Task : une fin différée ne doit jamais terminer
        // une nouvelle séance démarrée entre-temps.
        let activities = connues.filter { session == nil || $0.attributes.startedAt == session }
        stoppedSessions.formUnion(activities.map { $0.attributes.startedAt })
        if let session { stoppedSessions.insert(session) }
        if session == nil {
            if let requestedSession { stoppedSessions.insert(requestedSession) }
            updates?.cancel()
            updates = nil
        }
        if session == nil || courante?.attributes.startedAt == session { courante = nil }
        if session == nil || focused?.session == session { focused = nil }
        // Stop ne doit pas attendre une file d'updates ou une réponse serveur.
        Task { @MainActor in
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func state(for workout: Workout) -> WorkoutActivityAttributes.ContentState {
        .init(exerciseCount: workout.exerciseCount,
              setCount: workout.setCount,
              volume: Int(workout.totalVolume),
              focus: focused?.session == workout.startedAt ? focused?.value : nil,
              language: Langue.courante)
    }
}
