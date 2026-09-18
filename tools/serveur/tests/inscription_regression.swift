import Foundation

enum Goal { static let weeklyTarget = 5 }
struct HomeLot: Decodable {}
enum HomeTextes { @MainActor static func garder(_ lot: HomeLot?) {} }
enum DecideurSerie { static func chargerRegles() async {} }
enum Langue { static let courante = "fr"; static func poser(_ langue: String?) {} }
enum PremiereArrivee { static func poserPremiereFois(_ premiere: Bool) {} }
enum WoopConfig {
    static let isConfigured = true
    static let supabaseURL = URL(string: "https://woop-inscription.test")!
    static let supabaseAnonKey = "qa"
}
actor SupabaseSession {
    static let shared = SupabaseSession()
    func token() -> String { "session-qa" }
}
final class ReseauInscription: URLProtocol, @unchecked Sendable {
    static var objet: [String: Any] = [:]
    static var horsLigne = false
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "woop-inscription.test"
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if Self.horsLigne {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: Self.objet))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main struct TestsInscription {
    static func check(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
        print("PASS \(message)")
    }
    static func ecrire() async throws {
        _ = try await ProfilServeur.definirProfil(langue: "fr", prenom: "Camille", but: "force", objectifHebdo: 3)
    }
    static func main() async throws {
        URLProtocol.registerClass(ReseauInscription.self)
        let cles = [InscriptionCompte.cleEnCours, InscriptionCompte.cleVerification,
                    InscriptionCompte.cleBrouillon, ProfilServeur.clePrenom]
        let anciennes = cles.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (cle, valeur) in zip(cles, anciennes) {
                if let valeur { UserDefaults.standard.set(valeur, forKey: cle) }
                else { UserDefaults.standard.removeObject(forKey: cle) }
            }
        }
        InscriptionCompte.oublier()
        InscriptionCompte.verifierALaReprise()
        ReseauInscription.horsLigne = true
        do { _ = try await ProfilServeur.profil(); fatalError("panne attendue") } catch {}
        check(InscriptionCompte.aVerifier, "profil hors ligne : décision différée, aucune home ni nouvel onboarding inventé")
        ReseauInscription.horsLigne = false
        ReseauInscription.objet = ["erreur": "sans_session"]
        do { _ = try await ProfilServeur.profil(); fatalError("réponse refusée attendue") } catch {}
        check(InscriptionCompte.aVerifier, "profil illisible : vérification toujours due")
        ReseauInscription.objet = ["existe": false, "onboarding_termine": false]
        _ = try await ProfilServeur.profil()
        check(InscriptionCompte.aReprendre && !InscriptionCompte.aVerifier, "compte neuf : Nosfy reste dû après relance")
        let reponses = InscriptionCompte.Reponses(langue: "en", prenom: "Camille", but: "force", jours: [1, 3, 5])
        InscriptionCompte.garder(reponses)
        check(InscriptionCompte.brouillon?.prenom == "Camille"
              && InscriptionCompte.brouillon?.objectifHebdo == 3
              && InscriptionCompte.brouillon?.langue == "en", "réponses persistées et relues avec langue et objectif")
        ReseauInscription.horsLigne = true
        do { try await ecrire(); fatalError("panne attendue") } catch {}
        check(InscriptionCompte.aReprendre && InscriptionCompte.brouillon != nil,
              "échec réseau : réponses gardées pour réessayer")
        ReseauInscription.horsLigne = false
        ReseauInscription.objet = ["ok": false, "raison": "prenom_requis"]
        do { try await ecrire(); fatalError("refus métier attendu") } catch ProfilServeur.Erreur.refus(let raison) {
            check(raison == "prenom_requis", "HTTP 200 ok:false est un refus, pas une inscription réussie")
        }
        check(InscriptionCompte.brouillon != nil && InscriptionCompte.aReprendre,
              "refus métier : brouillon et reprise conservés")
        ReseauInscription.objet = ["ok": true, "existe": true, "onboarding_termine": false]
        do { try await ecrire(); fatalError("profil incomplet attendu") } catch ProfilServeur.Erreur.reponse {}
        check(InscriptionCompte.aReprendre, "réponse incomplète : la home attend encore")
        ReseauInscription.objet = ["ok": true, "existe": true, "onboarding_termine": true,
                                   "prenom": "Camille", "langue": "fr", "objectif_hebdo": 3]
        try await ecrire()
        check(!InscriptionCompte.aReprendre && !InscriptionCompte.aVerifier && InscriptionCompte.brouillon == nil,
              "confirmation serveur : inscription terminée, brouillon effacé")
        check(ProfilServeur.prenomLocal == "Camille", "prénom confirmé disponible pour la home et le profil")
        InscriptionCompte.verifierALaReprise()
        _ = try await ProfilServeur.profil()
        check(!InscriptionCompte.aVerifier && !InscriptionCompte.aReprendre, "compte connu : accès direct après lecture")
        InscriptionCompte.garder(reponses)
        InscriptionCompte.verifierALaReprise()
        InscriptionCompte.oublier()
        check(!InscriptionCompte.aReprendre && !InscriptionCompte.aVerifier && InscriptionCompte.brouillon == nil,
              "déconnexion : aucune réponse transmise au prochain compte")
    }
}
