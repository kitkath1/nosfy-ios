import Foundation
import Security

// MARK: - Configuration

/// Les identifiants Supabase. La clé `anon` est publique par conception —
/// c'est le Row Level Security côté serveur qui protège les données, pas le secret.
/// La clé Anthropic, elle, ne vit que dans les secrets de l'edge function.
///
/// ⚠️ LES DEUX NUMÉROS EN DUR SONT MORTS (14-09, plan compte C4) : `accounts` et
/// `credentials(forPhone:)` tenaient deux comptes e-mail et un mot de passe
/// dérivé du numéro — quiconque lisait le binaire entrait dans les deux. La
/// seule identité est Apple ; le mot de passe ne sert qu'au banc, sous DEBUG
/// (`ForgeServeur.sessionBanc`).
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

// MARK: - Le coffre : le refresh token au Keychain (14-09, plan compte C2)

/// Le refresh token dormait dans `UserDefaults` — il partait dans les
/// sauvegardes en clair (brique b-po-keychain). Il vit ici, dans le Keychain,
/// accessible après le premier déverrouillage et JAMAIS migré vers un autre
/// appareil (`ThisDeviceOnly`) : une session est celle d'un téléphone.
enum CoffreSession {
    private static let service = "fr.kathryn.woop"
    private static let compte = "supabase.refresh"

    private static var requete: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: compte]
    }

    static func lire() -> String? {
        var q = requete
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultat: AnyObject?
        let statut = SecItemCopyMatching(q as CFDictionary, &resultat)
        guard statut == errSecSuccess, let data = resultat as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func ecrire(_ refresh: String) {
        let data = Data(refresh.utf8)
        let maj: [String: Any] = [kSecValueData as String: data]
        let statut = SecItemUpdate(requete as CFDictionary, maj as CFDictionary)
        guard statut != errSecSuccess else { return }
        var q = requete
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let ajout = SecItemAdd(q as CFDictionary, nil)
        if ajout != errSecSuccess { print("[session] Keychain refuse d'écrire le refresh (\(ajout))") }
    }

    static func effacer() {
        SecItemDelete(requete as CFDictionary)
    }
}

// MARK: - Session

/// LA SESSION D'APPLE (06-09 → 14-09) : `AppleAuth.entrer()` fait l'échange
/// `grant_type=id_token` et POSE ici la session (`adopter`) ; `token()` la
/// rafraîchit en silence à chaque lancement ; `oublier()` l'efface à la
/// déconnexion et à la suppression. C'est son `auth.uid()` qui verrouille les
/// lignes via RLS — les séances te retrouvent sur chaque appareil où tu entres.
actor SupabaseSession {
    static let shared = SupabaseSession()

    private var accessToken: String?
    private var refreshToken: String?
    private var userID: String?
    private var renouvellement: (id: UUID, task: Task<String, Error>)?
    private var generation = UUID()

    /// L'ANCIEN emplacement du refresh (UserDefaults) — lu une dernière fois
    /// pour migrer au Keychain, puis effacé. Les deux clés du numéro sont
    /// mortes avec lui (C4) ; elles ne sont plus qu'effacées.
    private static let ancienneCleRefresh = "woop.supabase.refreshToken"
    private static let ancienneClePhone = "woop.supabase.tokenPhone"
    private static let cleNumero = "woop.phone"
    /// L'identité Apple retenue : l'`id` Supabase de la personne (le `sub` de
    /// son jeton). Sa présence + un refresh au coffre = une session gardée.
    private static let appleUserKey = "woop.apple.userID"

    /// UNE SESSION EST GARDÉE — lisible sans réseau, depuis n'importe quel fil,
    /// AVANT le premier rendu : c'est elle qui décide de la porte (C0 :
    /// `showAuth = !sessionGardee()`). Migre au passage le refresh qui dormait
    /// encore dans les préférences.
    nonisolated static func sessionGardee() -> Bool {
        let defaults = UserDefaults.standard
        if let ancien = defaults.string(forKey: ancienneCleRefresh), !ancien.isEmpty {
            if CoffreSession.lire() == nil { CoffreSession.ecrire(ancien) }
            defaults.removeObject(forKey: ancienneCleRefresh)
            print("[session] refresh migré des préférences au Keychain")
        }
        return defaults.string(forKey: appleUserKey) != nil && CoffreSession.lire() != nil
    }

    /// Renvoie un jeton valide pour la session gardée, en le rafraîchissant
    /// au premier appel. Sans session, la synchronisation attend.
    func token() async throws -> String {
        #if DEBUG
        // ⚠️ BANC `-sessionBanc [email mdp]` (30-08 soir) : la session du COMPTE
        // DE TEST de la forge (ou d'un compte jetable donné en argument), pour
        // MESURER au simulateur ce que le serveur rend à un vrai compte — sans
        // jamais toucher un vrai compte. Le jeton est gardé le temps du
        // processus ; rien n'est écrit dans les préférences ni au coffre.
        if CommandLine.arguments.contains("-sessionBanc") {
            if let accessToken, Self.encoreValide(accessToken) { return accessToken }
            let creds = ForgeServeur.identifiantsBanc(apres: "-sessionBanc")
            let jwt = try await ForgeServeur.jwtBanc(email: creds?.email, mdp: creds?.mdp)
            accessToken = jwt
            // 13-09 : l'identité du compte de test, lue dans le jeton (`sub`),
            // pour que `currentUserID()` — donc `push()` — marche aussi au banc.
            userID = Self.sujet(du: jwt)
            return jwt
        }
        // Le banc `-sessionAdoptee [email mdp]` (13-09) : la session du compte de
        // test (ou d'un compte jetable), POSÉE comme la porte Apple la pose —
        // gardée au coffre, donc la relance SANS argument passe par C0.
        if CommandLine.arguments.contains("-sessionAdoptee"),
           UserDefaults.standard.string(forKey: Self.appleUserKey) == nil {
            let creds = ForgeServeur.identifiantsBanc(apres: "-sessionAdoptee")
            let s = try await ForgeServeur.sessionBanc(email: creds?.email, mdp: creds?.mdp)
            adopter(access: s.access, refresh: s.refresh, userID: s.userID)
        }
        #endif
        guard let appleID = UserDefaults.standard.string(forKey: Self.appleUserKey) else {
            throw SupabaseError.notAuthenticated
        }
        if let accessToken, Self.encoreValide(accessToken) { return accessToken }
        // Un actor peut recevoir un autre appel pendant l'attente réseau.
        // Tous les lecteurs partagent donc le même renouvellement.
        if let renouvellement { return try await renouvellement.task.value }
        if userID == nil { userID = appleID }
        _ = Self.sessionGardee()                       // la migration, si elle n'a pas eu lieu
        guard let stored = CoffreSession.lire() else { throw SupabaseError.notAuthenticated }
        let id = UUID()
        let generation = self.generation
        let task = Task { try await renouveler(stored, generation: generation) }
        renouvellement = (id, task)
        defer {
            if renouvellement?.id == id { renouvellement = nil }
        }
        return try await task.value
    }

    private func renouveler(_ stored: String, generation: UUID) async throws -> String {
        do {
            return try await refresh(using: stored, generation: generation)
        } catch SupabaseError.server(let statut, let corps) where (400...403).contains(statut) {
            guard self.generation == generation else { throw CancellationError() }
            // LE REFRESH EST REFUSÉ (C0) : jeton révoqué, compte supprimé ailleurs,
            // déconnexion faite sur un autre appareil. Ce n'est pas une panne, c'est
            // la fin de la session : on l'oublie et la porte revient. Une panne
            // RÉSEAU, elle, passe par le `catch` général et ne touche à rien.
            print("[session] refresh refusé (\(statut)) → la session est oubliée · \(corps.prefix(140))")
            oublier()
            await CompteEtat.shared.demanderLaPorte(raison: "session_revoquee")
            throw SupabaseError.sessionRevoquee
        }
    }

    private func refresh(using refreshToken: String, generation: UUID) async throws -> String {
        var request = URLRequest(url: WoopConfig.supabaseURL
            .appending(path: "auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")]))
        request.httpMethod = "POST"
        request.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        // Une réponse ancienne ne doit jamais ressusciter une session effacée,
        // ni remplacer celle d'une autre personne connectée entre-temps.
        try Task.checkCancellation()
        guard self.generation == generation else { throw CancellationError() }
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
        CoffreSession.ecrire(decoded.refresh_token)
        return decoded.access_token
    }

    /// LA SESSION VENUE D'APPLE (06-09) — `AppleAuth.entrer()` a déjà fait
    /// l'échange `grant_type=id_token` ; elle pose ici le résultat pour que toute
    /// la synchro s'en serve. Le refresh va au coffre (Keychain), l'identité
    /// dans les préférences : c'est le couple que `sessionGardee()` lit.
    func adopter(access: String, refresh: String, userID: String) {
        annulerRenouvellement()
        self.accessToken = access
        self.refreshToken = refresh
        self.userID = userID
        CoffreSession.ecrire(refresh)
        UserDefaults.standard.set(userID, forKey: Self.appleUserKey)
        UserDefaults.standard.removeObject(forKey: Self.ancienneCleRefresh)
    }

    /// OUBLIER LA SESSION (C2) — tout ce qui identifie la personne sur ce
    /// téléphone : le jeton, le refresh (coffre), l'identité, et les deux
    /// reliques du numéro. Ne dit rien au serveur : `deconnecterAuServeur()`
    /// s'en charge AVANT, quand il y a un réseau.
    func oublier() {
        annulerRenouvellement()
        accessToken = nil
        refreshToken = nil
        userID = nil
        CoffreSession.effacer()
        let d = UserDefaults.standard
        d.removeObject(forKey: Self.appleUserKey)
        d.removeObject(forKey: Self.ancienneCleRefresh)
        d.removeObject(forKey: Self.ancienneClePhone)
        d.removeObject(forKey: Self.cleNumero)
    }

    /// `POST /auth/v1/logout` (C2) : le serveur révoque le refresh — la session
    /// ne peut plus renaître, même depuis une sauvegarde. Une panne réseau
    /// s'imprime et n'empêche pas d'oublier : rend `false`, c'est tout.
    @discardableResult
    func deconnecterAuServeur() async -> Bool {
        let jwt: String
        do { jwt = try await token() } catch {
            print("[session] logout : pas de jeton à révoquer (\(error.localizedDescription))")
            return false
        }
        var request = URLRequest(url: WoopConfig.supabaseURL
            .appending(path: "auth/v1/logout")
            .appending(queryItems: [URLQueryItem(name: "scope", value: "global")]))
        request.httpMethod = "POST"
        request.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.check(response, data)
            print("[session] logout → le refresh est révoqué au serveur")
            return true
        } catch {
            print("[session] logout en panne (on oublie quand même) · \(error.localizedDescription)")
            return false
        }
    }

    func currentUserID() async throws -> String {
        _ = try await token()
        guard let userID else { throw SupabaseError.notAuthenticated }
        return userID
    }

    /// Le `sub` d'un JWT (sa partie centrale, base64url) — sans vérifier la
    /// signature : c'est le serveur qui vérifie, ici on ne fait que lire qui
    /// on est. Sert au banc (`-sessionBanc`), où l'identité ne vient pas de
    /// la réponse de connexion.
    nonisolated static func sujet(du jwt: String) -> String? {
        charge(du: jwt)?["sub"] as? String
    }

    /// La signature reste vérifiée par Supabase. Ici, l'expiration sert
    /// seulement à renouveler en avance ; une charge illisible est périmée.
    nonisolated static func encoreValide(_ jwt: String, marge: TimeInterval = 60,
                                        maintenant: Date = Date()) -> Bool {
        guard let exp = charge(du: jwt)?["exp"] as? Double, exp.isFinite else { return false }
        return exp - maintenant.timeIntervalSince1970 > marge
    }

    nonisolated private static func charge(du jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    /// Le jeton a expiré : on force une nouvelle authentification au prochain appel.
    func invalidate(_ refuse: String? = nil) {
        if let refuse, refuse != accessToken { return }
        accessToken = nil
    }

    private func annulerRenouvellement() {
        generation = UUID()
        renouvellement?.task.cancel()
        renouvellement = nil
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
    /// Le serveur a refusé le refresh : la session est finie, la porte revient.
    case sessionRevoquee
    case transport
    case server(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase n'est pas encore configuré dans l'app."
        case .notAuthenticated:
            return "Session Supabase indisponible."
        case .sessionRevoquee:
            return "La session a été révoquée : reconnecte-toi."
        case .transport:
            return "Réseau indisponible."
        case .server(let status, let body):
            return "Erreur serveur \(status) — \(body.prefix(160))"
        }
    }
}
