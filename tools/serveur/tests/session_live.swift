import Foundation

// Les deux points d'écriture de SacreServeur restent interdits dans ce banc
// de lecture. Aucun remplacement du réseau ni des décodeurs de l'app.
enum GainEnAttente {
    case finDeSeance(seance: UUID, series: Int), retourQuotidien
}
actor OutboxGains {
    static let shared = OutboxGains()
    func poster(_ gain: GainEnAttente) { fatalError("Écriture interdite dans ce banc") }
}

enum WoopConfig {
    static let supabaseURL = URL(string: "https://ytnnyjkramgiqyxdrkcu.supabase.co")!
    static let supabaseAnonKey = ProcessInfo.processInfo.environment["WOOP_TEST_KEY"]!
}
enum CoffreSession {
    static var valeur: String?
    static func lire() -> String? { valeur }
    static func ecrire(_ value: String) { valeur = value }
    static func effacer() { valeur = nil }
}
@MainActor final class CompteEtat {
    static let shared = CompteEtat()
    func demanderLaPorte(raison: String) {}
}
@main struct Live {
    static func appel(_ path: String, body: [String: String], jwt: String? = nil) async throws -> Data {
        var r = URLRequest(url: URL(string: WoopConfig.supabaseURL.absoluteString + path)!)
        r.httpMethod = "POST"
        r.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let jwt { r.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization") }
        r.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else { throw SupabaseError.transport }
        return data
    }
    static func main() async throws {
        let email = "kat44426+woop-forge-test@gmail.com"
        let data = try await appel("/auth/v1/token?grant_type=password",
            body: ["email": email, "password": ProcessInfo.processInfo.environment["WOOP_TEST_PASSWORD"]!])
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let user = obj["user"] as! [String: Any]
        guard user["email"] as? String == email else { fatalError("Compte inattendu") }
        let s = SupabaseSession()
        var nettoyage = obj["access_token"] as! String
        do {
            // Seul le cache d'accès de ce banc est périmé. Le refresh est celui
            // de la session QA que CE test vient d'ouvrir.
            await s.adopter(access: "e30.eyJleHAiOjB9.signature",
                refresh: obj["refresh_token"] as! String, userID: user["id"] as! String)
            let tokens = try await withThrowingTaskGroup(of: String.self) { g in
                for _ in 0..<12 { g.addTask { try await s.token() } }
                var all: [String] = []
                for try await token in g { all.append(token) }
                return all
            }
            guard Set(tokens).count == 1, SupabaseSession.encoreValide(tokens[0]),
                  SupabaseSession.sujet(du: tokens[0]) == user["id"] as? String else {
                fatalError("Renouvellement invalide")
            }
            nettoyage = tokens[0]
            let coffre = try await appel("/rest/v1/rpc/etat_coffre", body: [:], jwt: nettoyage)
            let resultat = try JSONSerialization.jsonObject(with: coffre) as! [String: Any]
            guard resultat["prix_booster"] != nil else { fatalError("Coffre incomplet") }
            print("PASS refresh Supabase réel : 12 appels, même jeton neuf, identité QA conservée, etat_coffre 200")
            let lu = try await SacreServeur.etatCoffre(jwt: nettoyage)
            guard lu.soldeOr == resultat["solde_or"] as? Int,
                  lu.soldeArgent == resultat["solde_argent"] as? Int,
                  lu.boostersOr == resultat["boosters_or"] as? Int,
                  lu.prixBooster == resultat["prix_booster"] as? Int,
                  lu.piecesParSerie == resultat["pieces_par_serie"] as? Int,
                  lu.piecesParLongueur == resultat["pieces_par_longueur"] as? Int,
                  lu.retourProchain != nil else { fatalError("Contrat coffre différent du serveur") }
            print("PASS vrai client Swift coffre : soldes, sachets, tarifs et date serveur décodés")
            let annonces = try await SacreServeur.reglesAnnonces(jwt: nettoyage)
            let regles = ReglesAnnonces.lire(annonces)
            guard regles.rangsFixes == (annonces["popup_rangs_fixes"] as? [Int])?.sorted(),
                  regles.popupsMax == annonces["popups_max_seance"] as? Int,
                  regles.videoRare == annonces["popup_video_rare"] as? String,
                  regles.videosReward == annonces["popup_videos_reward"] as? [String],
                  regles.ecartMinSeries == annonces["ecart_min_series"] as? Int,
                  regles.ecartMinMinutes == annonces["ecart_min_minutes"] as? Int
            else { fatalError("Contrat annonces différent du serveur") }
            print("PASS vrai décodeur Swift annonces : rangs, budget, vidéos et écarts du serveur")
            let journal = try await SacreServeur.historique(jwt: nettoyage)
            let collection = try await SacreServeur.maCollection(jwt: nettoyage)
            print("PASS vrais clients Swift : journal \(journal.count) lignes, collection \(collection.count) familles")
            do {
                _ = try await SacreServeur.etatCoffre(jwt: "jeton-invalide")
                fatalError("Le coffre accepte un jeton invalide")
            } catch SacreServeur.Erreur.http(let code, _) where code == 401 {
                print("PASS coffre privé : jeton invalide refusé HTTP 401")
            }
        } catch {
            _ = try? await appel("/auth/v1/logout?scope=local", body: [:], jwt: nettoyage)
            await s.oublier()
            throw error
        }
        _ = try await appel("/auth/v1/logout?scope=local", body: [:], jwt: nettoyage)
        await s.oublier()
        print("PASS seule la session QA de cet essai est fermée ; aucun gain écrit")
    }
}
