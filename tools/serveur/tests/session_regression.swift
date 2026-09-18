import Foundation

// Compilé avec l'actor SupabaseSession réel par verif_session.py.
// Le réseau et le Keychain sont remplacés ; aucun compte réel n'est utilisé.
enum WoopConfig {
    static let supabaseURL = URL(string: "https://woop-session.test")!
    static let supabaseAnonKey = "test"
}
enum CoffreSession {
    static var valeur: String?
    static func lire() -> String? { valeur }
    static func ecrire(_ value: String) { valeur = value }
    static func effacer() { valeur = nil }
}
@MainActor final class CompteEtat {
    static let shared = CompteEtat()
    var rappels = 0
    func demanderLaPorte(raison: String) { rappels += 1 }
}

func jwt(_ expiration: TimeInterval, user: String = "alice") -> String {
    let data = try! JSONSerialization.data(withJSONObject: ["exp": expiration, "sub": user])
    let charge = data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    return "e30.\(charge).signature"
}

final class Reseau: URLProtocol, @unchecked Sendable {
    static let verrou = NSLock()
    static var appels = 0
    static var statut = 200
    static var delai = 0.05
    static var panne = false
    static var resultat: String { jwt(Date().timeIntervalSince1970 + 3600) }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "woop-session.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.verrou.lock(); Self.appels += 1
        let statut = Self.statut, panne = Self.panne, delai = Self.delai
        Self.verrou.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + delai) {
            if panne {
                self.client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
                return
            }
            let response = HTTPURLResponse(url: self.request.url!, statusCode: statut,
                                           httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            let data = try! JSONSerialization.data(withJSONObject: [
                "access_token": Self.resultat, "refresh_token": "refresh-renouvele",
                "user": ["id": "alice"]
            ])
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

@main struct Tests {
    static func check(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
        print("PASS \(message)")
    }
    static func main() async throws {
        URLProtocol.registerClass(Reseau.self)
        let cle = "woop.apple.userID"
        let ancienne = UserDefaults.standard.object(forKey: cle)
        defer {
            if let ancienne { UserDefaults.standard.set(ancienne, forKey: cle) }
            else { UserDefaults.standard.removeObject(forKey: cle) }
        }
        let now = Date().timeIntervalSince1970
        check(SupabaseSession.encoreValide(jwt(now + 3600)), "jeton frais")
        check(!SupabaseSession.encoreValide(jwt(now + 59)), "renouvellement avant expiration")
        check(!SupabaseSession.encoreValide(jwt(now - 1)), "jeton expiré")
        check(!SupabaseSession.encoreValide("illisible"), "jeton illisible")
        check(!SupabaseSession.encoreValide("e30.e30.signature"), "expiration absente")
        let s = SupabaseSession()
        let fresh = jwt(now + 3600)
        await s.adopter(access: fresh, refresh: "refresh", userID: "alice")
        let lu = try await s.token()
        check(lu == fresh && Reseau.appels == 0, "cache valide sans réseau")

        await s.adopter(access: jwt(now - 1), refresh: "refresh", userID: "alice")
        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<30 { group.addTask { try await s.token() } }
            var resultat: [String] = []
            for try await token in group { resultat.append(token) }
            return resultat
        }
        check(Reseau.appels == 1 && Set(tokens).count == 1, "30 appels concurrents, un seul refresh")
        check(CoffreSession.lire() == "refresh-renouvele", "rotation conservée")
        await s.invalidate("ancien-refuse")
        let conserve = try await s.token()
        check(conserve == tokens[0] && Reseau.appels == 1, "401 ancien sans invalidation du jeton neuf")

        await s.invalidate(tokens[0])
        Reseau.panne = true
        do { _ = try await s.token(); fatalError("panne attendue") } catch {}
        check(CoffreSession.lire() != nil, "panne réseau conserve la session")
        Reseau.panne = false
        let repris = try await s.token()
        check(SupabaseSession.encoreValide(repris), "reprise réseau renouvelle")

        await s.invalidate()
        Reseau.statut = 401
        do { _ = try await s.token(); fatalError("refus attendu") } catch {}
        check(CoffreSession.lire() == nil, "refresh révoqué efface la session")
        let portes = await CompteEtat.shared.rappels
        check(portes == 1, "une seule demande de reconnexion")

        Reseau.statut = 200; Reseau.delai = 0.2
        await s.adopter(access: jwt(now - 1), refresh: "alice", userID: "alice")
        let ancien = Task { try await s.token() }
        try await Task.sleep(for: .milliseconds(40))
        let bob = jwt(now + 3600, user: "bob")
        await s.adopter(access: bob, refresh: "bob", userID: "bob")
        _ = try? await ancien.value
        try await Task.sleep(for: .milliseconds(230))
        let courant = try await s.token()
        check(courant == bob && CoffreSession.lire() == "bob", "refresh tardif ne remplace pas le nouveau compte")

        await s.adopter(access: jwt(now - 1), refresh: "alice", userID: "alice")
        let retard = Task { try await s.token() }
        try await Task.sleep(for: .milliseconds(40))
        await s.oublier()
        _ = try? await retard.value
        try await Task.sleep(for: .milliseconds(230))
        check(CoffreSession.lire() == nil, "refresh tardif ne ressuscite pas une déconnexion")
    }
}
