import Foundation

/// Le reçu est la confirmation économique. L'annonce ne calcule aucun gain.
struct EvenementGain: Codable, Equatable, Identifiable {
    let id: String
    let userId: String
    let genre: String
    let montant: Int
    let motif: String

    init?(_ j: [String: Any]) {
        guard let id = j["id"] as? String,
              let userId = j["user_id"] as? String,
              let genre = j["genre"] as? String,
              let montant = j["montant"] as? Int, montant > 0 else { return nil }
        self.id = id; self.userId = userId; self.genre = genre
        self.montant = montant; self.motif = j["motif"] as? String ?? ""
    }
}

struct RecuRecompense {
    let id: String
    let userId: String
    let coffre: SacreServeur.EtatCoffre
    let evenements: [EvenementGain]

    init?(_ j: [String: Any]) {
        guard let id = j["receipt_id"] as? String,
              let userId = j["user_id"] as? String,
              let coffre = j["coffre"] as? [String: Any] else { return nil }
        self.id = id; self.userId = userId
        self.coffre = SacreServeur.decoderCoffre(coffre)
        evenements = (j["events"] as? [[String: Any]] ?? []).compactMap(EvenementGain.init)
    }
}

enum CartesServeur {
    static func objet(_ nom: String, jwt: String, corps: [String: Any] = [:]) async throws -> Any {
        var req = URLRequest(url: WoopConfig.supabaseURL.appending(path: "rest/v1/rpc/\(nom)"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: corps)
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw SacreServeur.Erreur.http(code, "récompense non confirmée") }
        return data.isEmpty ? NSNull() : try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    }

    static func evenements(jwt: String) async throws -> [EvenementGain] {
        let j = try await objet("annonces_en_attente", jwt: jwt)
        guard let lignes = j as? [[String: Any]] else { throw SacreServeur.Erreur.reponse }
        return lignes.compactMap(EvenementGain.init)
    }

    static func acquitter(_ e: EvenementGain) async {
        do {
            let owner = try await SupabaseSession.shared.currentUserID()
            guard owner.lowercased() == e.userId.lowercased() else { return }
            let jwt = try await SupabaseSession.shared.token()
            _ = try await objet("acquitter_annonces", jwt: jwt, corps: ["p_ids": [e.id]])
        } catch { /* Le prochain rafraîchissement retente l'acquittement. */ }
    }

    /// Garder la même opération jusque l'image réellement reçue, même après relance.
    @MainActor static func operation(user: String, noir: Bool) -> UUID {
        let key = cleOperation(user: user, noir: noir)
        if let s = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: s) { return id }
        let id = UUID(); UserDefaults.standard.set(id.uuidString, forKey: key); return id
    }

    @MainActor static func terminer(user: String, noir: Bool) {
        UserDefaults.standard.removeObject(forKey: cleOperation(user: user, noir: noir))
    }

    private static func cleOperation(user: String, noir: Bool) -> String {
        "woop.cartes.ouverture.\(user.lowercased()).\(noir ? "noir" : "ordinaire")"
    }
}
