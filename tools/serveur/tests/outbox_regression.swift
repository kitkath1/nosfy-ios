import Foundation

enum WoopConfig { static let isConfigured = true }
actor SupabaseSession {
    static let shared = SupabaseSession()
    func token() async throws -> String { "test" }
    func invalidate(_ token: String) async {}
}
enum ForgeServeur { static func jwtBanc() async throws -> String { "test" } }
struct Cloture {
    let pieces = 20, solde = 20, reste = 20
    let piecesCreditees = true, boosterNeuf = true, argent = false
}
struct Retour { let credite = true, montant = 10, solde = 10 }
@MainActor final class EconomieWoop {
    static let shared = EconomieWoop()
    var applications = 0
    func appliquer(_ r: Cloture) { applications += 1 }
    func appliquer(_ r: Retour) { applications += 1 }
    func rafraichir() async {}
}
actor Reseau {
    static let shared = Reseau()
    var code = 503, appels = 0
    var bloquer = false
    var suite: CheckedContinuation<Void, Never>?
    var persisteAvantReseau = false
    func configurer(_ code: Int, bloque: Bool = false) {
        self.code = code; bloquer = bloque
    }
    func attendre(_ cible: Int) async throws {
        for _ in 0..<200 {
            if appels >= cible { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw URLError(.timedOut)
    }
    func liberer() { bloquer = false; suite?.resume(); suite = nil }
    func envoyer() async throws {
        appels += 1
        if let data = UserDefaults.standard.data(forKey: "woop.outbox.gains"),
           let f = try? JSONDecoder().decode([GainEnAttente].self, from: data) {
            persisteAvantReseau = !f.isEmpty
        }
        if bloquer { await withCheckedContinuation { suite = $0 } }
        if code != 200 { throw SacreServeur.Erreur.http(code, "banc") }
    }
}
enum SacreServeur {
    enum Erreur: Error { case http(Int, String), reponse }
    static func cloturerSeance(_ id: UUID, series: Int, jwt: String) async throws -> Cloture {
        try await Reseau.shared.envoyer(); return Cloture()
    }
    static func claimRetourQuotidien(jwt: String) async throws -> Retour {
        try await Reseau.shared.envoyer(); return Retour()
    }
    static func reclamerNoeudChemin(_ n: Int, pieces: Int, monnaie: String, boosters: [String], jwt: String) async throws -> Bool {
        try await Reseau.shared.envoyer(); return true
    }
}
@main struct Tests {
    static func check(_ v: Bool,_ nom: String) { precondition(v,nom); print("PASS " + nom) }
    static func main() async throws {
        let cle = "woop.outbox.gains"
        let sauvegarde = UserDefaults.standard.data(forKey: cle)
        defer { if let sauvegarde { UserDefaults.standard.set(sauvegarde,forKey:cle) } else { UserDefaults.standard.removeObject(forKey:cle) } }
        let o = OutboxGains()
        await o.effacer()
        let id = UUID(); let gain = GainEnAttente.finDeSeance(seance:id,series:1)
        await o.poster(gain)
        check(await Reseau.shared.persisteAvantReseau,"gain persiste avant le réseau")
        check(await o.enAttente == 1,"503 conserve le gain")
        check(await o.seancesARejouer == [id],"rattrapage identifie la séance à synchroniser")
        await o.poster(gain)
        check(await o.enAttente == 1,"doublon en attente évité")
        await Reseau.shared.configurer(200)
        await o.vider()
        check(await o.enAttente == 0,"succès retire le gain")
        check(await EconomieWoop.shared.applications == 1,"réponse appliquée une fois")
        await Reseau.shared.configurer(200,bloque:true)
        let cible = await Reseau.shared.appels + 1
        let premier = Task { await o.poster(.finDeSeance(seance:UUID(),series:1)) }
        try await Reseau.shared.attendre(cible)
        await o.poster(.finDeSeance(seance:UUID(),series:2))
        check(await o.enAttente == 2,"ajout concurrent conservé")
        await Reseau.shared.liberer();await premier.value
        check(await o.enAttente == 0,"ajout concurrent envoyé dans le même vidage")
        check(await EconomieWoop.shared.applications == 3,"deux réponses concurrentes appliquées")
        await Reseau.shared.configurer(200,bloque:true)
        let cible2 = await Reseau.shared.appels + 1
        let ancien = Task { await o.poster(.finDeSeance(seance:UUID(),series:3)) }
        try await Reseau.shared.attendre(cible2)
        await o.effacer()
        await Reseau.shared.liberer();await ancien.value
        check(await o.enAttente == 0,"changement de compte ne recrée pas la file")
        check(await EconomieWoop.shared.applications == 3,"retour tardif de l'ancien compte ignoré")
        await Reseau.shared.configurer(403);await o.poster(gain)
        check(await o.enAttente == 0,"refus définitif ne bouche pas la file")
        await Reseau.shared.configurer(401);await o.poster(gain)
        check(await o.enAttente == 1,"session à renouveler conserve le gain")
        print("13 contrôles PASS")
    }
}
