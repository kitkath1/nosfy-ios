import Foundation

// MARK: - Configuration

/// Les identifiants Supabase. La clé `anon` est publique par conception —
/// c'est le Row Level Security côté serveur qui protège les données, pas le secret.
/// La clé Anthropic, elle, ne vit que dans les secrets de l'edge function.
enum WoopConfig {
    static let supabaseURL = URL(string:
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
            ?? "https://ytnnyjkramgiqyxdrkcu.supabase.co"
    )!

    static let supabaseAnonKey =
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
            ?? "sb_publishable__EHzc8KHeG_f3TdA6x2iag_F3fIW7v2"

    /// Tant que le projet n'est pas renseigné, l'app fonctionne en local seul.
    static var isConfigured: Bool {
        !supabaseAnonKey.isEmpty && !supabaseURL.absoluteString.contains("VOTRE-PROJET")
    }

    /// L'identité Supabase dérivée du numéro : l'app est privée, chaque numéro
    /// connu correspond à un compte email-alias (la boîte Gmail de chacune)
    /// créé une fois pour toutes dans Supabase Auth — pas de SMS, le
    /// fournisseur d'OTP viendra plus tard. Un numéro inconnu ne synchronise pas.
    private static let accounts: [String: String] = [
        "0633285654": "kat44426+woop-33633285654@gmail.com",        // kathryn
        "0620373383": "margauxvieljeux+woop-33620373383@gmail.com"  // margaux
    ]

    static func credentials(forPhone digits: String) -> (email: String, password: String)? {
        guard let email = accounts[digits] else { return nil }
        return (email, "woop-33\(digits.dropFirst())-2026")
    }
}

// MARK: - Session

/// Authentification par numéro : le numéro saisi sur l'écran d'accueil désigne
/// un compte Supabase (voir `WoopConfig.credentials`), et c'est son `auth.uid()`
/// qui verrouille les lignes via RLS — les séances te retrouvent sur chaque
/// appareil où tu entres ton numéro.
actor SupabaseSession {
    static let shared = SupabaseSession()

    private var accessToken: String?
    private var refreshToken: String?
    private var userID: String?

    private let tokenKey = "woop.supabase.refreshToken"
    /// Le numéro auquel appartient le refresh token mémorisé : si on se
    /// connecte avec un autre numéro, la session précédente est abandonnée.
    private let tokenPhoneKey = "woop.supabase.tokenPhone"
    private let phoneKey = "woop.phone"

    /// Renvoie un jeton valide pour le numéro courant, en se connectant au
    /// premier appel. Sans numéro enregistré, la synchronisation attend.
    func token() async throws -> String {
        // ⚠️ BANC `-sessionBanc` (30-08 soir) : la session du COMPTE DE TEST de
        // la forge (`ForgeServeur.jwtBanc`), pour MESURER au simulateur ce que
        // le serveur rend à un vrai compte — le coffre, le Welcome Back, la
        // pile des annonces — sans jamais toucher un vrai numéro. Le jeton est
        // gardé le temps du processus ; rien n'est écrit dans les préférences.
        if CommandLine.arguments.contains("-sessionBanc") {
            if let accessToken { return accessToken }
            let jwt = try await ForgeServeur.jwtBanc()
            accessToken = jwt
            return jwt
        }
        guard let phone = UserDefaults.standard.string(forKey: phoneKey),
              let creds = WoopConfig.credentials(forPhone: phone) else {
            throw SupabaseError.notAuthenticated
        }

        if UserDefaults.standard.string(forKey: tokenPhoneKey) != phone {
            accessToken = nil
            userID = nil
            UserDefaults.standard.removeObject(forKey: tokenKey)
        }

        if let accessToken { return accessToken }

        if let stored = UserDefaults.standard.string(forKey: tokenKey) {
            if let refreshed = try? await refresh(using: stored) { return refreshed }
        }
        return try await signIn(creds, phone: phone)
    }

    private func signIn(_ creds: (email: String, password: String),
                        phone: String) async throws -> String {
        var request = URLRequest(url: WoopConfig.supabaseURL
            .appending(path: "auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "password")]))
        request.httpMethod = "POST"
        request.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ["email": creds.email, "password": creds.password])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response, data)
        let token = try store(from: data)
        UserDefaults.standard.set(phone, forKey: tokenPhoneKey)
        return token
    }

    private func refresh(using refreshToken: String) async throws -> String {
        var request = URLRequest(url: WoopConfig.supabaseURL
            .appending(path: "auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")]))
        request.httpMethod = "POST"
        request.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response, data)
        return try store(from: data)
    }

    private func store(from data: Data) throws -> String {
        struct AuthResponse: Decodable {
            let access_token: String
            let refresh_token: String
            let user: User
            struct User: Decodable { let id: String }
        }
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        accessToken = decoded.access_token
        refreshToken = decoded.refresh_token
        userID = decoded.user.id
        UserDefaults.standard.set(decoded.refresh_token, forKey: tokenKey)
        return decoded.access_token
    }

    func currentUserID() async throws -> String {
        _ = try await token()
        guard let userID else { throw SupabaseError.notAuthenticated }
        return userID
    }

    /// Le jeton a expiré : on force une nouvelle authentification au prochain appel.
    func invalidate() {
        accessToken = nil
    }

    static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.transport }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseError.server(
                status: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
    }
}

enum SupabaseError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case transport
    case server(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase n'est pas encore configuré dans l'app."
        case .notAuthenticated:
            return "Session Supabase indisponible."
        case .transport:
            return "Réseau indisponible."
        case .server(let status, let body):
            return "Erreur serveur \(status) — \(body.prefix(160))"
        }
    }
}
