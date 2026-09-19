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
            /// LA PISCINE (15-09, session cardio) : les longueurs nagées et le
            /// bassin — une ligne `piscine_longueurs` par exercice, seulement
            /// s'il y en a (0 = rien à pousser).
            var longueurs: Int = 0
            var metresParLongueur: Int = 25
        }
    }

    /// `piscine_longueurs` (20260915160000) : une ligne par exercice de
    /// piscine, clé = l'exercice (upsert `merge-duplicates` sur la pk).
    private struct PiscineRow: Encodable {
        let logged_exercise_id: String
        let user_id: String
        let longueurs: Int
        let metres_par_longueur: Int
    }

    private struct Instantane: Encodable {
        let p_workout: WorkoutRow
        let p_exercices: [LoggedExerciseRow]
        let p_series: [StrengthSetRow]
        let p_phases: [CardioPhaseRow]
        let p_piscines: [PiscineRow]
    }

    // MARK: Envoi

    func push(_ snapshots: [Snapshot], proprietaire: String? = nil) async {
        // Les données de démonstration ne quittent jamais l'appareil : un run
        // Xcode avec `-demoData` ne doit pas polluer un vrai compte.
        // `-syncNow` lève le garde-fou (tests de bout en bout uniquement).
        if CommandLine.arguments.contains("-demoData"),
           !CommandLine.arguments.contains("-syncNow") { return }
        guard WoopConfig.isConfigured, !snapshots.isEmpty, !inFlight else { return }
        do {
            try await pousser(snapshots, proprietaire: proprietaire)
            await OutboxGains.shared.vider()
        } catch {
            // La séance est déjà enregistrée localement : on réessaiera au prochain envoi.
            await SupabaseSession.shared.invalidate()
            print("Synchronisation Supabase différée : \(error.localizedDescription)")
        }
    }

    /// LA POUSSÉE QUI DIT SI ELLE A RÉUSSI (14-09, plan compte C2) : la
    /// déconnexion pousse ce qui attend et REFUSE d'effacer le téléphone si
    /// l'envoi échoue — `push` avale ses pannes, elle ne peut pas le savoir.
    /// Même corps, même ordre (les clés étrangères pointent vers la table
    /// précédente), sans le garde-fou de la démo : c'est l'appelant qui décide.
    func pousser(_ snapshots: [Snapshot], proprietaire: String? = nil) async throws {
        guard WoopConfig.isConfigured, !snapshots.isEmpty else { return }
        while inFlight { try await Task.sleep(for: .milliseconds(100)) }
        inFlight = true
        defer { inFlight = false }

        do {
            let token = try await SupabaseSession.shared.token()
            let userID = try await SupabaseSession.shared.currentUserID()
            guard proprietaire == nil || proprietaire?.lowercased() == userID.lowercased() else {
                throw CancellationError()
            }
            let iso = ISO8601DateFormatter()

            // Une séance et son arbre dans UNE transaction, avant toute clôture.
            for snapshot in snapshots {
                let lot = [snapshot]
                let workouts = lot.map {
                    WorkoutRow(id: $0.id, user_id: userID,
                               started_at: iso.string(from: $0.startedAt),
                               ended_at: $0.endedAt.map(iso.string(from:)),
                               notes: $0.notes)
                }
                let exercises = lot.flatMap { snapshot in
                    snapshot.exercises.map {
                        LoggedExerciseRow(id: $0.id, workout_id: snapshot.id, user_id: userID,
                                          exercise_id: $0.exerciseID, position: $0.position)
                    }
                }
                let sets = lot.flatMap(\.exercises).flatMap { exercise in
                    exercise.sets.map {
                        StrengthSetRow(id: $0.id, logged_exercise_id: exercise.id, user_id: userID,
                                       reps: $0.reps, weight: $0.weight, position: $0.position)
                    }
                }
                let phases = lot.flatMap(\.exercises).flatMap { exercise in
                    exercise.phases.map {
                        CardioPhaseRow(id: $0.id, logged_exercise_id: exercise.id, user_id: userID,
                                       kind: $0.kind, seconds: $0.seconds, speed: $0.speed,
                                       incline: $0.incline, cycle_index: $0.cycleIndex,
                                       position: $0.position)
                    }
                }

                let piscines = lot.flatMap(\.exercises)
                    .filter { $0.longueurs > 0 }
                    .map {
                        PiscineRow(logged_exercise_id: $0.id, user_id: userID,
                                   longueurs: $0.longueurs,
                                   metres_par_longueur: $0.metresParLongueur)
                    }

                let corps = Instantane(p_workout: workouts[0], p_exercices: exercises,
                                       p_series: sets, p_phases: phases, p_piscines: piscines)
                var request = URLRequest(url: WoopConfig.supabaseURL.appending(path: "rest/v1/rpc/synchroniser_seance"))
                request.httpMethod = "POST"
                request.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(corps)
                let (data, response) = try await URLSession.shared.data(for: request)
                try SupabaseSession.check(response, data)
                guard let objet = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      objet["ok"] as? Bool == true else { throw URLError(.cannotParseResponse) }
            }

        } catch {
            await SupabaseSession.shared.invalidate()
            throw error
        }
    }


}

// MARK: - Lecture : le pull (14-09, tools/sync/PLAN-PULL-SEANCES.md)

extension SupabaseSync {
    /// Ce que la relecture a fait — pour le journal `[pull]` et la mesure.
    struct Relecture: Sendable {
        var total = 0, rendues = 0, inserees = 0, ignorees = 0, local = 0
        var serveurAt: Date?
    }

    /// `woop.pull.depuis` : le `serveur_at` du dernier pull — l'appel suivant ne
    /// demande que ce qui a fini après. `-pullTout` l'ignore.
    static let cleDepuis = "woop.pull.depuis"

    /// LE PULL — cinq règles (plan § 3) : n'insère que ce qui manque (par `remoteID`),
    /// séances finies seulement, incrémental, valeurs honnêtes pour ce que le serveur
    /// ne porte pas, silencieux en panne. Tourne sur le MainActor dans le contexte
    /// principal : les `@Query` de la home se rafraîchissent d'elles-mêmes.
    @MainActor
    @discardableResult
    static func relire(dans contexte: ModelContext) async -> Relecture? {
        let args = CommandLine.arguments
        if args.contains("-sansPull") { return nil }
        if args.contains("-demoData"), !args.contains("-pullNow") { return nil }
        guard WoopConfig.isConfigured else { return nil }

        let generation = CompteEtat.shared.generationDonnees
        let depuis: String? = args.contains("-pullTout") ? nil
            : UserDefaults.standard.string(forKey: cleDepuis)
        let o: [String: Any]
        do {
            o = try await lireSeances(depuis: depuis)
        } catch {
            print("[pull] seances_depuis ✗ \(error.localizedDescription)")
            return nil
        }
        guard generation == CompteEtat.shared.generationDonnees,
              !Task.isCancelled else { return nil }
        var r = Relecture()
        r.total = (o["total"] as? NSNumber)?.intValue ?? 0
        r.rendues = (o["rendues"] as? NSNumber)?.intValue ?? 0
        r.serveurAt = (o["serveur_at"] as? String).flatMap(instant)

        // Ce que le téléphone a déjà — jamais touché.
        let existants = Set(((try? contexte.fetch(FetchDescriptor<Workout>())) ?? []).map { $0.remoteID.uuidString.lowercased() })
        for s in (o["seances"] as? [[String: Any]]) ?? [] {
            guard let id = s["id"] as? String, let uuid = UUID(uuidString: id),
                  let debut = instant(s["started_at"]), let fin = instant(s["ended_at"]) else { continue }
            if existants.contains(id.lowercased()) { r.ignorees += 1; continue }
            let w = Workout(startedAt: debut, endedAt: fin)
            w.remoteID = uuid
            w.notes = s["notes"] as? String ?? ""
            contexte.insert(w)
            for e in (s["exercices"] as? [[String: Any]]) ?? [] {
                guard let eid = e["id"] as? String, let euuid = UUID(uuidString: eid),
                      let exo = e["exercise_id"] as? String else { continue }
                let l = LoggedExercise(exerciseID: exo, order: (e["position"] as? NSNumber)?.intValue ?? 0)
                l.remoteID = euuid
                l.workout = w
                // La piscine (20260915170000) : `piscine {longueurs, metres_par_longueur,
                // metres}` par exercice, null sans longueurs.
                if let p = e["piscine"] as? [String: Any] {
                    l.longueurs = (p["longueurs"] as? NSNumber)?.intValue ?? 0
                    l.metresParLongueur = (p["metres_par_longueur"] as? NSNumber)?.intValue ?? 25
                }
                contexte.insert(l)
                for st in (e["series"] as? [[String: Any]]) ?? [] {
                    guard let sid = st["id"] as? String, let suuid = UUID(uuidString: sid) else { continue }
                    // Une séance FINIE : ses séries ont été faites (l'économie ne paie que
                    // celles-là) ; la durée sous tension, le serveur ne la porte pas.
                    let set = StrengthSet(reps: (st["reps"] as? NSNumber)?.intValue ?? 0,
                                          weight: (st["weight"] as? NSNumber)?.doubleValue ?? 0,
                                          order: (st["position"] as? NSNumber)?.intValue ?? 0,
                                          isDone: true)
                    set.remoteID = suuid
                    set.loggedExercise = l
                    contexte.insert(set)
                }
                for ph in (e["phases"] as? [[String: Any]]) ?? [] {
                    guard let pid = ph["id"] as? String, let puuid = UUID(uuidString: pid) else { continue }
                    // Une séance FINIE : ses phases ont été faites (le miroir des
                    // séries, `isDone: true` — 15-09, session cardio : le graphe
                    // de la fiche et l'overlay ne lisent que les phases faites).
                    let phase = CardioPhase(kind: PhaseKind(rawValue: ph["kind"] as? String ?? "") ?? .recuperation,
                                            seconds: (ph["seconds"] as? NSNumber)?.intValue ?? 0,
                                            speed: (ph["speed"] as? NSNumber)?.doubleValue ?? 0,
                                            cycleIndex: (ph["cycle_index"] as? NSNumber)?.intValue ?? 0,
                                            order: (ph["position"] as? NSNumber)?.intValue ?? 0,
                                            incline: (ph["incline"] as? NSNumber)?.doubleValue ?? 0,
                                            isDone: true)
                    phase.remoteID = puuid
                    phase.loggedExercise = l
                    contexte.insert(phase)
                }
            }
            r.inserees += 1
        }
        if r.inserees > 0 {
            do { try contexte.save() }
            catch {
                print("[pull] sauvegarde différée : \(error.localizedDescription)")
                return nil
            }
        }
        // Aussi pour les séances déjà importées avant ce raccord : le curseur
        // des séances ne doit pas empêcher de retrouver leur reçu manquant.
        await restaurerBilans(dans: contexte)
        guard generation == CompteEtat.shared.generationDonnees,
              !Task.isCancelled else { return nil }
        r.local = (try? contexte.fetchCount(FetchDescriptor<Workout>())) ?? 0
        if let at = o["serveur_at"] as? String { UserDefaults.standard.set(at, forKey: cleDepuis) }
        print("[pull] seances_depuis(\(depuis ?? "tout")) → total \(r.total), rendues \(r.rendues) · insérées \(r.inserees), ignorées \(r.ignorees) · local \(r.local)")
        return r
    }

    /// Lecture seule. Revoir une story ne poste jamais de clôture dans l'outbox.
    /// Une panne garde les bilans manquants éligibles au prochain passage.
    @MainActor
    static func restaurerBilans(dans contexte: ModelContext, pour seances: [Workout]? = nil) async {
        let generation = CompteEtat.shared.generationDonnees
        let toutes = seances ?? ((try? contexte.fetch(FetchDescriptor<Workout>())) ?? [])
        let manquantes = toutes.filter { $0.endedAt != nil && $0.bilanRecompense == nil && !$0.recompenseARegler }
        guard !manquantes.isEmpty else { return }
        do {
            let jwt = try await SupabaseSession.shared.token()
            let owner = try await SupabaseSession.shared.currentUserID().lowercased()
            for debut in stride(from: 0, to: manquantes.count, by: 100) {
                guard generation == CompteEtat.shared.generationDonnees, !Task.isCancelled else { return }
                let lot = Array(manquantes[debut..<min(debut + 100, manquantes.count)])
                var req = URLRequest(url: WoopConfig.supabaseURL.appending(path: "rest/v1/rpc/recus_seances"))
                req.httpMethod = "POST"
                req.timeoutInterval = 15
                req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
                req.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONEncoder().encode(["p_workouts": lot.map { $0.remoteID.uuidString.lowercased() }])
                let (data, rep) = try await URLSession.shared.data(for: req)
                try SupabaseSession.check(rep, data)
                struct Recu: Decodable {
                    let workout_id: UUID
                    let user_id: String
                    let bilan: BilanRecompenseSeance
                }
                let recus = try JSONDecoder().decode([Recu].self, from: data)
                guard generation == CompteEtat.shared.generationDonnees, !Task.isCancelled else { return }
                var changes: [Workout] = []
                do {
                    for recu in recus where recu.user_id.lowercased() == owner {
                        guard let w = lot.first(where: { $0.remoteID == recu.workout_id }),
                              w.bilanRecompense == nil, !w.recompenseARegler else { continue }
                        w.bilanRecompense = try JSONEncoder().encode(recu.bilan)
                        changes.append(w)
                    }
                    if !changes.isEmpty { try contexte.save() }
                } catch {
                    // Ne pas annuler les autres modifications du contexte partagé.
                    for w in changes { w.bilanRecompense = nil }
                    throw error
                }
                print("[pull] bilans historiques : \(changes.count) retrouvés")
            }
        } catch {
            print("[pull] bilans historiques différés : \(error.localizedDescription)")
        }
    }

    /// L'appel nu — la forme de `ChambreServeur.rpc`, avec la session courante.
    private static func lireSeances(depuis: String?) async throws -> [String: Any] {
        let jwt = try await SupabaseSession.shared.token()
        var req = URLRequest(url: WoopConfig.supabaseURL.appending(path: "rest/v1/rpc/seances_depuis"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var corps: [String: Any] = ["p_limite": 500]
        if let depuis { corps["p_depuis"] = depuis }
        req.httpBody = try JSONSerialization.data(withJSONObject: corps)
        let (data, rep) = try await URLSession.shared.data(for: req)
        try SupabaseSession.check(rep, data)
        guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        if let e = o["erreur"] as? String { throw NSError(domain: "pull", code: 1, userInfo: [NSLocalizedDescriptionKey: e]) }
        return o
    }

    /// « 2026-09-06T17:15:00+00:00 » (un `timestamptz`), avec ou sans fraction.
    private static func instant(_ v: Any?) -> Date? {
        guard let s = v as? String else { return nil }
        let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = a.date(from: s) { return d }
        let b = ISO8601DateFormatter(); b.formatOptions = [.withInternetDateTime]
        return b.date(from: s)
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
                    sets: logged.orderedSets.filter(\.isDone).map {
                        (id: $0.remoteID.uuidString, reps: $0.reps,
                         weight: $0.weight, position: $0.order)
                    },
                    phases: logged.phasesFaites.filter { $0.seconds > 0 }.map {
                        (id: $0.remoteID.uuidString, kind: $0.kindRaw, seconds: $0.seconds,
                         speed: $0.speed, incline: $0.incline,
                         cycleIndex: $0.cycleIndex, position: $0.order)
                    },
                    longueurs: logged.longueurs,
                    metresParLongueur: logged.metresParLongueur
                )
            }
        )
    }
}
