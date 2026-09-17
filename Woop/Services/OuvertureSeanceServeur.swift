import Foundation

/// Le début est envoyé sans attendre la fin de séance. Une insertion ignorée
/// en cas de conflit ne peut jamais rouvrir une séance déjà terminée au serveur.
actor OuvertureSeanceServeur {
    static let shared = OuvertureSeanceServeur()
    private var recues: Set<UUID> = []
    private var annulees = Set((UserDefaults.standard.stringArray(forKey: "woop.depart.annulations") ?? [])
        .compactMap(UUID.init(uuidString:)))
    private var aRetirer = Set((UserDefaults.standard.stringArray(forKey: "woop.depart.annulations") ?? [])
        .compactMap(UUID.init(uuidString:)))
    private var proprietaires = UserDefaults.standard.dictionary(forKey: "woop.depart.proprietaires") as? [String: String] ?? [:]
    private var vidageEnCours = false
    private var envois: [UUID: Task<Void, Never>] = [:]

    private struct Ligne: Encodable {
        var id: UUID
        var user_id: String
        var started_at: String
    }
    private struct Recu: Decodable {
        var id: UUID
        var ended_at: String?
    }

    private var autorise: Bool {
        let args = CommandLine.arguments
        let demo = ["-demoData", "-demoForce", "-activeWorkout", "-countLab", "-piluleLab"]
            .contains { args.contains($0) }
        return WoopConfig.isConfigured && !args.contains("-sansServeur")
            && (!demo || args.contains("-syncNow"))
    }

    func ouvrir(id: UUID, debut: Date) async {
        guard autorise, !recues.contains(id), !annulees.contains(id) else { return }
        if let t = envois[id] { await t.value; return }
        let t = Task { await self.inserer(id: id, debut: debut) }
        envois[id] = t
        await t.value
        envois[id] = nil
    }

    private func inserer(id: UUID, debut: Date) async {
        let depart = Date()
        do {
            let token = try await SupabaseSession.shared.token()
            let uid = try await SupabaseSession.shared.currentUserID()
            guard !annulees.contains(id) else { return }
            // Garder l'appartenance avant l'envoi : même une réponse perdue
            // puis un kill doivent permettre d'annuler avec le bon compte.
            let utiles = aRetirer.union(envois.keys).union([id])
            proprietaires = proprietaires.filter { cle, _ in
                UUID(uuidString: cle).map { utiles.contains($0) } ?? false
            }
            proprietaires[id.uuidString] = uid
            UserDefaults.standard.set(proprietaires, forKey: "woop.depart.proprietaires")
            var r = requete("workouts?on_conflict=id", token: token)
            r.httpMethod = "POST"
            r.setValue("resolution=ignore-duplicates,return=representation", forHTTPHeaderField: "Prefer")
            r.httpBody = try JSONEncoder().encode([
                Ligne(id: id, user_id: uid, started_at: ISO8601DateFormatter().string(from: debut))
            ])
            let (data, response) = try await URLSession.shared.data(for: r)
            try SupabaseSession.check(response, data)
            var lignes = try JSONDecoder().decode([Recu].self, from: data)
            if lignes.isEmpty {
                // Un rejeu renvoie[] : relire la ligne réellement conservée.
                let lecture = requete("workouts?id=eq.\(id.uuidString)&select=id,ended_at", token: token)
                let (d, reponse) = try await URLSession.shared.data(for: lecture)
                try SupabaseSession.check(reponse, d)
                lignes = try JSONDecoder().decode([Recu].self, from: d)
            }
            guard let recu = lignes.first(where: { $0.id == id }) else {
                throw URLError(.cannotParseResponse)
            }
            recues.insert(id)
            print("[depart-serveur] \(id) · \(recu.ended_at == nil ? "ouverte" : "déjà terminée") · \(Int(Date().timeIntervalSince(depart) * 1000))ms")
        } catch {
            // La séance locale continue. L'apparition / le retour au premier
            // plan retentent avec le même UUID, sans bloquer le film ni le doigt.
            print("[depart-serveur] \(id) · différé · \(error.localizedDescription)")
        }
    }

    /// L'annulation locale attend son éventuel envoi, puis retire seulement
    /// cette séance encore ouverte. Une fin déjà reçue ne peut pas être effacée.
    func annuler(id: UUID) async {
        guard autorise else { return }
        annulees.insert(id)
        aRetirer.insert(id)
        garderAnnulations()
        if let t = envois[id] { await t.value }
        await reprendreAnnulations()
    }

    /// Les annulations hors ligne survivent au kill. RLS et propriétaire
    /// enregistré empêchent de les rejouer avec le compte suivant.
    func reprendreAnnulations() async {
        guard autorise, !aRetirer.isEmpty, !vidageEnCours else { return }
        vidageEnCours = true
        defer { vidageEnCours = false }
        do {
            let token = try await SupabaseSession.shared.token()
            let uid = try await SupabaseSession.shared.currentUserID()
            for id in Array(aRetirer) {
                if let t = envois[id] { await t.value }
                guard let owner = proprietaires[id.uuidString] else {
                    // Aucun envoi n'a quitté l'app pour cet UUID.
                    aRetirer.remove(id)
                    garderAnnulations()
                    continue
                }
                guard owner == uid else { continue }
                var r = requete("workouts?id=eq.\(id.uuidString)&ended_at=is.null", token: token)
                r.httpMethod = "DELETE"
                let (data, response) = try await URLSession.shared.data(for: r)
                try SupabaseSession.check(response, data)
                recues.remove(id)
                aRetirer.remove(id)
                garderAnnulations()
                print("[depart-serveur] \(id) · annulation synchronisée")
            }
        } catch {
            print("[depart-serveur] annulations différées · \(error.localizedDescription)")
        }
    }

    private func garderAnnulations() {
        UserDefaults.standard.set(aRetirer.map(\.uuidString), forKey: "woop.depart.annulations")
    }

    private func requete(_ chemin: String, token: String) -> URLRequest {
        // Le chemin ne contient que nos noms de colonnes et un UUID.
        var r = URLRequest(url: URL(string: "rest/v1/" + chemin,
                                   relativeTo: WoopConfig.supabaseURL)!.absoluteURL)
        r.timeoutInterval = 12
        r.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return r
    }
}
