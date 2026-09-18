import UIKit
import CryptoKit

// MARK: - Le client de la forge serveur (forge-card)

/// LE POINT DE RENCONTRE des deux chantiers : le flow booster (carrousel,
/// ouverture) appelle `ForgeServeur.tirer(...)` et reçoit une
/// `LuneForge.Carte` prête pour `CarteVivante(art:depth:)` — rien d'autre
/// à savoir. Le serveur attribue une référence déjà publiée et commune.
/// L’ouverture attend ses vrais pixels, vérifiés par leur empreinte.
/// La clé publishable est une clé client ; aucun appel IA dans ce parcours.
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

    /// Le tirage exige boosterId ; les anciens paramètres d’atelier sont ignorés au serveur.
    static func tirer(jwt: String, workoutId: String? = nil,
                      famille: String? = nil,
                      forceNeuf: Bool = false,
                      boosterId: String? = nil) async throws -> LuneForge.Carte {
        var corps: [String: Any] = ["contract_version": 2]
        if let workoutId { corps["workout_id"] = workoutId }
        if let famille { corps["famille"] = famille }
        if forceNeuf { corps["force_new"] = true }
        // LE BOOSTER NOIR : on envoie l'id de SA réserve, JAMAIS une rareté.
        // C'est le serveur qui relit `user_boosters.origine` et impose le
        // registre légendaire — une rareté demandée par le client serait la
        // faille de tout le système (§4 decies de la note backend).
        if let boosterId { corps["booster_id"] = boosterId }

        var req = URLRequest(url: base.appending(path: "functions/v1/forge-card"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(publishable, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: corps)
        // Une attente réseau peut être reprise avec le même sachet.
        req.timeoutInterval = 45

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
              let id = carte["id"] as? String,
              let nom = carte["famille"] as? String,
              let rarete = carte["rarete"] as? String,
              let scene = carte["scene"] as? String,
              let artUrl = (carte["art_url"] as? String).flatMap(URL.init)
        else { throw Erreur.reponse }

        // L'illustration NUE du pool → l'habillage local (cadre + lunes
        // de rareté + depth v0) : le même code que la forge d'atelier.
        let (png, imageResponse) = try await URLSession.shared.data(from: artUrl)
        if let attendu = carte["art_sha256"] as? String {
            let empreinte = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
            guard empreinte == attendu else { throw Erreur.illustration }
        }
        guard (imageResponse as? HTTPURLResponse)?.statusCode == 200,
              let illustration = UIImage(data: png) else {
            throw Erreur.illustration
        }
        let (art, depth) = try await Task.detached(priority: .userInitiated) {
            try LuneForge.habiller(illustration: illustration, rarete: rarete)
        }.value
        let dossier = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "cartes-lune")
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        try? png.write(to: dossier.appending(path: "\(id).png"), options: .atomic)
        let noms = carte["noms"] as? [String: String] ?? [:]
        let nomLocal = await MainActor.run { L(noms["fr"] ?? nom, noms["en"] ?? nom) }
        return LuneForge.Carte(
            art: art, depth: depth,
            famille: LuneForge.Famille(nom: nomLocal, rarete: rarete,
                                       brief: "", dur: ""),
            scene: scene, cardId: id, acquisitionId: json["acquisition_id"] as? String)
    }

    // MARK: L'échafaudage du banc

    /// Le user de TEST du banc (dev uniquement — les vrais comptes
    /// seront « Connexion avec Apple », voir supabase/README.md).
    static func jwtBanc(email: String? = nil, mdp: String? = nil) async throws -> String {
        try await sessionBanc(email: email, mdp: mdp).access
    }

    /// `-sessionBanc <email> <mdp>` / `-sessionAdoptee <email> <mdp>` (14-09) :
    /// les deux mots qui SUIVENT le drapeau, s'ils n'en sont pas un — un compte
    /// jetable à la place du compte de test (la mesure de la première arrivée,
    /// de la déconnexion, de la suppression). Sans eux : le compte de test.
    static func identifiantsBanc(apres drapeau: String) -> (email: String, mdp: String)? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: drapeau), i + 2 < args.count else { return nil }
        let email = args[i + 1], mdp = args[i + 2]
        guard !email.hasPrefix("-"), !mdp.hasPrefix("-"), email.contains("@") else { return nil }
        return (email, mdp)
    }

    /// La session ENTIÈRE du compte de test (13-09) — ce que la porte Apple
    /// obtient de son échange, pour le banc `-sessionAdoptee` : on la POSE par
    /// `SupabaseSession.adopter(...)` et on mesure le chemin d'un compte créé
    /// par Apple (jeton adopté → `token()` → `push()` → `widget_*`), sans le
    /// bouton Apple, que le simulateur n'a pas.
    /// ⚠️ SOUS DEBUG SEULEMENT (14-09, plan compte C4) : en release, le chemin
    /// `grant_type=password` n'existe pas et AUCUN identifiant ne dort dans le
    /// binaire — la seule identité est Apple.
    static func sessionBanc(email: String? = nil, mdp: String? = nil) async throws -> (access: String, refresh: String, userID: String) {
        #if DEBUG
        var req = URLRequest(url: base.appending(
            path: "auth/v1/token").appending(
            queryItems: [.init(name: "grant_type", value: "password")]))
        req.httpMethod = "POST"
        req.setValue(publishable, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email ?? "kat44426+woop-forge-test@gmail.com",
            "password": mdp ?? "forge-test-2026",
        ])
        let (data, rep) = try await URLSession.shared.data(for: req)
        guard (rep as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
              let jwt = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any],
              let id = user["id"] as? String
        else { throw Erreur.reponse }
        return (jwt, refresh, id)
        #else
        throw Erreur.reponse
        #endif
    }
}
