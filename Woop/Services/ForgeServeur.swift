import UIKit

// MARK: - Le client de la forge serveur (forge-card)

/// LE POINT DE RENCONTRE des deux chantiers : le flow booster (carrousel,
/// ouverture) appelle `ForgeServeur.tirer(...)` et reçoit une
/// `LuneForge.Carte` prête pour `CarteVivante(art:depth:)` — rien d'autre
/// à savoir. Le serveur décide POOL-OU-NEUF (le « on a la même ! ») ;
/// une carte du pool arrive en ~1 s, une neuve en 60-90 s : l'animation
/// d'ouverture doit savoir attendre, jamais compter sur une durée fixe.
///
/// La clé publishable est une clé CLIENT (faite pour être embarquée) ;
/// la clé OpenAI, elle, vit dans l'Edge Function — jamais ici.
enum ForgeServeur {
    static let base = URL(string: "https://ytnnyjkramgiqyxdrkcu.supabase.co")!
    static let publishable = "sb_publishable__EHzc8KHeG_f3TdA6x2iag_F3fIW7v2"

    enum Erreur: LocalizedError {
        case http(Int, String), reponse, illustration
        var errorDescription: String? {
            switch self {
            case .http(let code, let m): return "serveur \(code) : \(m)"
            case .reponse: return "réponse illisible"
            case .illustration: return "illustration introuvable"
            }
        }
    }

    /// Le tirage. `famille`/`forceNeuf` sont des manettes d'atelier —
    /// le flow réel appelle juste `tirer(jwt:workoutId:)`.
    static func tirer(jwt: String, workoutId: String? = nil,
                      famille: String? = nil,
                      forceNeuf: Bool = false) async throws -> LuneForge.Carte {
        var corps: [String: Any] = [:]
        if let workoutId { corps["workout_id"] = workoutId }
        if let famille { corps["famille"] = famille }
        if forceNeuf { corps["force_new"] = true }

        var req = URLRequest(url: base.appending(path: "functions/v1/forge-card"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(publishable, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: corps)
        // Une carte NEUVE se peint en 60-90 s — le client attend large.
        req.timeoutInterval = 300

        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let détail = (try? JSONSerialization.jsonObject(with: data))
                .flatMap { $0 as? [String: Any] }
                .flatMap { $0["error"] as? String } ?? ""
            throw Erreur.http(code, détail)
        }
        guard let json = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
              let carte = json["card"] as? [String: Any],
              let nom = carte["famille"] as? String,
              let rarete = carte["rarete"] as? String,
              let scene = carte["scene"] as? String,
              let artUrl = (carte["art_url"] as? String).flatMap(URL.init)
        else { throw Erreur.reponse }

        // L'illustration NUE du pool → l'habillage local (cadre + lunes
        // de rareté + depth v0) : le même code que la forge d'atelier.
        let (png, _) = try await URLSession.shared.data(from: artUrl)
        guard let illustration = UIImage(data: png) else {
            throw Erreur.illustration
        }
        let (art, depth) = try LuneForge.habiller(illustration: illustration,
                                                  rarete: rarete)
        return LuneForge.Carte(
            art: art, depth: depth,
            famille: LuneForge.Famille(nom: nom, rarete: rarete,
                                       brief: "", dur: ""),
            scene: scene)
    }

    // MARK: L'échafaudage du banc

    /// Le user de TEST du banc (dev uniquement — les vrais comptes
    /// seront « Connexion avec Apple », voir supabase/README.md).
    static func jwtBanc() async throws -> String {
        var req = URLRequest(url: base.appending(
            path: "auth/v1/token").appending(
            queryItems: [.init(name: "grant_type", value: "password")]))
        req.httpMethod = "POST"
        req.setValue(publishable, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": "kat44426+woop-forge-test@gmail.com",
            "password": "forge-test-2026",
        ])
        let (data, rep) = try await URLSession.shared.data(for: req)
        guard (rep as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
              let jwt = json["access_token"] as? String
        else { throw Erreur.reponse }
        return jwt
    }
}
