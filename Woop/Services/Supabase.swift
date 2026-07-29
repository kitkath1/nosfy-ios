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
}

// MARK: - Session

/// Authentification anonyme : pas d'écran de connexion, mais un vrai `auth.uid()`
/// derrière lequel verrouiller les lignes via RLS.
actor SupabaseSession {
    static let shared = SupabaseSession()

    private var accessToken: String?
    private var refreshToken: String?
    private var userID: String?

    private let tokenKey = "woop.supabase.refreshToken"

    /// Renvoie un jeton valide, en créant l'utilisateur anonyme au premier appel.
    func token() async throws -> String {
        if let accessToken { return accessToken }

        if let stored = UserDefaults.standard.string(forKey: tokenKey) {
            if let refreshed = try? await refresh(using: stored) { return refreshed }
        }
        return try await signUpAnonymously()
    }

    private func signUpAnonymously() async throws -> String {
        var request = URLRequest(url: WoopConfig.supabaseURL.appending(path: "auth/v1/signup"))
        request.httpMethod = "POST"
        request.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response, data)
        return try store(from: data)
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
