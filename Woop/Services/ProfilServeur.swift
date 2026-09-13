import Foundation

// ════════════════════════════════════════════════════════════════════════
// LE PROFIL AU SERVEUR — les appels, prêts, PAS ENCORE APPELÉS (13-09)
//
// Migration `20260913200000_profil.sql` : `profils`, `exercices_choisis`,
// `profil()`, `definir_profil(…)`, `choisir_exercices(ids)`. Kathryn :
// « créer pour plus tard même si c'est empty » ; « on crée des comptes que
// par Apple, et ça identifie direct si un compte existe déjà : on arrive à
// la home direct ».
//
// Les deux sites d'appel à poser, chez la session de la porte :
//  · après l'échange Apple : `ProfilServeur.profil()` → si
//    `onboardingTermine`, la home direct ; sinon le questionnaire de Nosfy.
//    (Plus jamais « aucune ligne user_prefs = une nouvelle » : la chambre
//    Regularity écrit user_prefs dès qu'on choisit un objectif.)
//  · à la fin de Nosfy : `ProfilServeur.definirProfil(langue:prenom:but:objectifHebdo:)`
//    — UN appel, il relaie l'objectif à `definir_objectif` (user_prefs) et pose
//    la date de fin d'onboarding. Puis `ChambreEtat.shared.objectif` suit au
//    prochain passage par la chambre (le serveur gagne).
//  · quand la personne choisit ses exercices : `choisirExercices(ids)` — les
//    ids du catalogue Swift, dans l'ordre ; le catalogue reste dans l'app.
//
// Tant qu'aucune de ces lignes n'est posée, la carte du serveur dit 🔵.
// ════════════════════════════════════════════════════════════════════════

enum ProfilServeur {
    struct Profil {
        var existe: Bool
        var onboardingTermine: Bool
        var langue: String?
        var prenom: String?
        var but: String?
        var objectifHebdo: Int
        var exercices: [String]
        var seances: Int

        /// La loi du vide : ce que rend le serveur pour une personne qui n'a rien.
        static let vide = Profil(existe: false, onboardingTermine: false, langue: nil, prenom: nil,
                                 but: nil, objectifHebdo: Goal.weeklyTarget, exercices: [], seances: 0)

        init(existe: Bool, onboardingTermine: Bool, langue: String?, prenom: String?, but: String?,
             objectifHebdo: Int, exercices: [String], seances: Int) {
            self.existe = existe; self.onboardingTermine = onboardingTermine
            self.langue = langue; self.prenom = prenom; self.but = but
            self.objectifHebdo = objectifHebdo; self.exercices = exercices; self.seances = seances
        }

        init(json o: [String: Any]) {
            existe = o["existe"] as? Bool ?? false
            onboardingTermine = o["onboarding_termine"] as? Bool ?? false
            langue = o["langue"] as? String
            prenom = o["prenom"] as? String
            but = o["but"] as? String
            objectifHebdo = (o["objectif_hebdo"] as? NSNumber)?.intValue ?? Goal.weeklyTarget
            exercices = o["exercices"] as? [String] ?? []
            seances = (o["seances"] as? NSNumber)?.intValue ?? 0
        }
    }

    /// LE PRÉNOM, gardé localement (13-09, Kathryn : « le nom, tu dois le garder
    /// en backend, il apparaît dans la home et dans la page profil »). La clé
    /// que la home lit en `@AppStorage` pour « Hello Kathryn, » ; le serveur
    /// (`profils.prenom`) est la source, ceci son cache — posé à chaque lecture
    /// ou écriture du profil.
    static let clePrenom = "woop.prenom"
    static var prenomLocal: String? {
        let p = UserDefaults.standard.string(forKey: clePrenom)
        return (p?.isEmpty ?? true) ? nil : p
    }
    private static func garder(_ p: Profil) {
        if let n = p.prenom, !n.isEmpty { UserDefaults.standard.set(n, forKey: clePrenom) }
    }

    /// Rafraîchit le prénom depuis le serveur, en silence : sans session, sans
    /// réseau, rien ne bouge (le cache reste). La home l'appelle en apparaissant.
    static func rafraichirPrenom() async {
        guard WoopConfig.isConfigured else { return }
        if let p = try? await profil() { garder(p) }
    }

    /// `profil()` — l'aiguillage et tout ce qu'on sait de la personne.
    static func profil() async throws -> Profil {
        let p = Profil(json: try await objet("profil"))
        garder(p)
        return p
    }

    /// `definir_profil(…)` — la fin du questionnaire de Nosfy, en un appel.
    /// Rend le profil tel que le serveur le tient après l'écriture.
    static func definirProfil(langue: String?, prenom: String?, but: String?,
                              objectifHebdo: Int?, onboardingTermine: Bool = true) async throws -> Profil {
        var corps: [String: Any] = ["p_onboarding_termine": onboardingTermine]
        if let langue { corps["p_langue"] = langue }
        if let prenom { corps["p_prenom"] = prenom }
        if let but { corps["p_but"] = but }
        if let objectifHebdo { corps["p_objectif_hebdo"] = objectifHebdo }
        let p = Profil(json: try await objet("definir_profil", corps: corps))
        garder(p)
        return p
    }

    /// `choisir_exercices(ids)` — l'ensemble des exercices choisis, dans l'ordre.
    static func choisirExercices(_ ids: [String]) async throws -> [String] {
        let o = try await objet("choisir_exercices", corps: ["p_ids": ids])
        return o["exercices"] as? [String] ?? []
    }

    // MARK: - L'appel nu (la forme de ChambreServeur, avec la session courante)

    enum Erreur: Error { case http(Int, String), reponse }

    private static func objet(_ nom: String, corps: [String: Any] = [:]) async throws -> [String: Any] {
        let jwt = try await SupabaseSession.shared.token()
        var req = URLRequest(url: WoopConfig.supabaseURL.appending(path: "rest/v1/rpc/\(nom)"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = corps.isEmpty ? Data("{}".utf8) : try JSONSerialization.data(withJSONObject: corps)
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(code) else {
            let detail = (try? JSONSerialization.jsonObject(with: data)).flatMap { $0 as? [String: Any] }
                .flatMap { $0["message"] as? String } ?? ""
            throw Erreur.http(code, detail)
        }
        let json = try JSONSerialization.jsonObject(with: data)
        if let o = json as? [String: Any] { return o }
        if let a = json as? [[String: Any]], let p = a.first { return p }
        throw Erreur.reponse
    }
}
