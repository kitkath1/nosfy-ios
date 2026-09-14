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
        /// La réponse d'une ÉCRITURE : `ok` false + `raison` (« prenom_requis »,
        /// « sans_session ») quand le serveur refuse — règle du 13-09 : on ne
        /// finit pas l'onboarding sans prénom, l'input passe au rouge.
        var ok: Bool = true
        var raison: String?
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
            ok = o["ok"] as? Bool ?? (o["raison"] == nil)
            raison = o["raison"] as? String
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
    /// réseau, rien ne bouge (le cache reste). La home l'appelle en apparaissant
    /// — par `home()`, l'appel fait pour elle (13-09 soir).
    static func rafraichirPrenom() async {
        guard WoopConfig.isConfigured else { return }
        if let a = try? await accueil(), let n = a.prenom, !n.isEmpty {
            UserDefaults.standard.set(n, forKey: clePrenom)
        }
    }

    // MARK: - home() : ce que la home demande au serveur, en un appel

    /// LA VÉRITÉ DU SERVEUR POUR LA HOME (13-09 soir, Kathryn : « la homepage
    /// est aussi interactive, des fois le wording change ; ça doit récupérer
    /// de vraies données »). Le prénom, les séances faites cette semaine,
    /// l'objectif, le reste, la séance en cours et ses minutes.
    ///
    /// Ce que la home en CONSOMME aujourd'hui : le prénom. Les nombres, elle
    /// les compte sur les séances du téléphone (la même passe que les cards,
    /// b-ux-chambre-donnees) — parce qu'une phrase qui dirait « 3 workouts »
    /// au-dessus d'une card Regularity à « 0 / 5 » (téléphone vide, serveur
    /// plein) contredirait l'écran. Le jour où la lecture des séances existe
    /// (le `pull` qui manque), `faites` / `reste` / `enSeance` sont déjà là.
    struct Accueil {
        var prenom: String?
        var onboardingTermine: Bool
        var faites: Int
        var objectif: Int
        var reste: Int
        var enSeance: Bool
        var minutesEnSeance: Int
        var derniereSeance: Date?
        var seancesTotal: Int
        /// LA PREMIÈRE ARRIVÉE (migration 20260913230000, session back-end) :
        /// `premiere_fois` = onboarding terminé ET aucune séance finie ;
        /// `visite_home` = la visite guidée a été faite (marquer_visite_home).
        var premiereFois: Bool
        var visiteHome: Bool
        /// La langue de la personne (`profils.langue`) — le cache `woop.langue` la suit.
        var langue: String?
        /// LA PHRASE DE LA HOME VIENT DU SERVEUR (14-09, migrations 20260914010000 +
        /// 011000, session back-end — sur l'ordre de Kathryn : « fais anglais /
        /// français pour les variants de la Home, vide, active, en cours »). Les
        /// quatre variantes dans la langue du profil, le prénom dans le premier
        /// fragment : `vide`, `active`, `seance_debut`, `seance` — quatre fragments
        /// chacune, clair / sourd / clair / sourd. Le cache `woop.phrases` les suit ;
        /// la Home compose son nombre (séances, minutes) dans le troisième.
        var phrases: [String: [String]]

        init(json o: [String: Any]) {
            prenom = (o["prenom"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            onboardingTermine = o["onboarding_termine"] as? Bool ?? false
            premiereFois = o["premiere_fois"] as? Bool ?? false
            visiteHome = o["visite_home"] as? Bool ?? false
            langue = o["langue"] as? String
            var ph: [String: [String]] = [:]
            for (etat, v) in (o["phrases"] as? [String: Any]) ?? [:] {
                if let f = v as? [Any] {
                    let mots = f.compactMap { $0 as? String }
                    if mots.count == 4 { ph[etat] = mots }
                }
            }
            phrases = ph
            faites = (o["faites"] as? NSNumber)?.intValue ?? 0
            objectif = (o["objectif"] as? NSNumber)?.intValue ?? Goal.weeklyTarget
            reste = (o["reste"] as? NSNumber)?.intValue ?? max(objectif - faites, 0)
            enSeance = o["en_seance"] as? Bool ?? false
            minutesEnSeance = (o["minutes_en_seance"] as? NSNumber)?.intValue ?? 0
            derniereSeance = (o["derniere_seance_at"] as? String).flatMap {
                let a = ISO8601DateFormatter(); a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = a.date(from: $0) { return d }
                let b = ISO8601DateFormatter(); b.formatOptions = [.withInternetDateTime]
                return b.date(from: $0)
            }
            seancesTotal = (o["seances_total"] as? NSNumber)?.intValue ?? 0
        }
    }

    /// `home()` — un appel, le journal `[home-serveur]` dit ce qui est revenu.
    static func accueil() async throws -> Accueil {
        let a = Accueil(json: try await objet("home"))
        print("[home-serveur] home() → prénom \(a.prenom ?? "—") · \(a.faites) / \(a.objectif), reste \(a.reste) · en séance \(a.enSeance) (\(a.minutesEnSeance) min) · \(a.seancesTotal) séances en tout · première fois \(a.premiereFois) · visite \(a.visiteHome) · langue \(a.langue ?? "—")")
        Langue.poser(a.langue)                        // le serveur gagne (le contrat § 9)
        PremiereArrivee.poserPremiereFois(a.premiereFois) // idem : la phrase et la card ROUTE
        if !a.phrases.isEmpty {                       // idem : les mots de la Home
            UserDefaults.standard.set(a.phrases, forKey: clePhrases)
            print("[home-serveur] phrases → \(a.phrases.keys.sorted().joined(separator: ", "))")
        }
        dernierAccueil = a
        return a
    }

    /// Le dernier `home()` lu — la racine s'en sert pour la première arrivée.
    static var dernierAccueil: Accueil?

    /// LES MOTS DE LA HOME, en cache (le dernier `home()`) — `vide`, `active`,
    /// `seance_debut`, `seance`, quatre fragments chacun. Vide tant qu'aucun
    /// `home()` n'a répondu (les bancs, le hors-ligne) : la Home garde alors ses
    /// textes de repli.
    static let clePhrases = "woop.phrases"
    static var phrasesLocales: [String: [String]] {
        (UserDefaults.standard.dictionary(forKey: clePhrases) as? [String: [String]]) ?? [:]
    }

    /// `marquer_visite_home()` — la visite guidée est faite ; la date se pose une fois.
    static func marquerVisiteHome() async throws -> Profil {
        Profil(json: try await objet("marquer_visite_home"))
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
