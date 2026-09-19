import Foundation
import SwiftData

enum BancPreferences {
    static let nom = "nosfy.front-back.\(UUID().uuidString)"
    static let valeur = UserDefaults(suiteName: nom)!
}
enum CoffreSession {
    static var valeur: String?
    static func lire() -> String? { valeur }
    static func ecrire(_ v: String) { valeur = v }
    static func effacer() { valeur = nil }
}
func L(_ fr: String, _ en: String) -> String { fr }
enum Langue { static let en = false }
extension ExerciseCategory { var nomLocalise: String { rawValue } }
struct SlateLigne { var reps: Int; var kilos: Double; var seconds: Int; var done: Bool }
struct SlateGroupe { var id: String; var exercise: Exercise; var rows: [SlateLigne] }
@MainActor final class CompteEtat {
    static let shared = CompteEtat()
    var generationDonnees = UUID()
    func demanderLaPorte(raison: String) {}
}
// Seul l'hôte des vues est remplacé ; le callback conserve l'écriture du reçu.
@MainActor final class EconomieWoop {
    static let shared = EconomieWoop()
    static let possible = true
    var derniere: SacreServeur.ClotureSeance?
    var retour: SacreServeur.RetourQuotidien?
    func appliquer(_ r: SacreServeur.ClotureSeance) {
        derniere = r
        ReglementSeance.shared.recevoir(r)
    }
    func appliquer(_ r: SacreServeur.RetourQuotidien) { retour = r }
    func rafraichir() async {}
}
enum ForgeServeur {
    static func jwtBanc() async throws -> String { fatalError("Ancien compte de banc interdit") }
}

@main struct FrontBack {
    @MainActor static var n = 0
    @MainActor static func check(_ condition: Bool, _ texte: String) throws {
        guard condition else { throw NSError(domain: "Verification", code: 1,
                                            userInfo: [NSLocalizedDescriptionKey: texte]) }
        n += 1
        print("PASS \(texte)")
    }
    @MainActor static func main() async throws {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        let s = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let user = s["user"] as! [String: Any]
        let uid = user["id"] as! String
        defer { BancPreferences.valeur.removePersistentDomain(forName: BancPreferences.nom) }
        // Les douze lecteurs passent par le vrai refresh HTTP, une seule session.
        await SupabaseSession.shared.adopter(access: "e30.eyJleHAiOjB9.signature",
            refresh: s["refresh_token"] as! String, userID: uid)
        do {
            try await verifier(uid: uid)
            let jwt = try await SupabaseSession.shared.token()
            try await fermerSession(jwt)
            await SupabaseSession.shared.oublier()
        } catch {
            if let jwt = try? await SupabaseSession.shared.token() { try? await fermerSession(jwt) }
            await SupabaseSession.shared.oublier()
            throw error
        }
        print("\(n) contrôles Swift → Supabase → SwiftData PASS ; rendu et Apple natif hors banc")
    }

    @MainActor static func verifier(uid: String) async throws {
        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<12 { group.addTask { try await SupabaseSession.shared.token() } }
            var values: [String] = []
            for try await v in group { values.append(v) }
            return values
        }
        let jwt = tokens[0]
        try check(Set(tokens).count == 1 && SupabaseSession.sujet(du: jwt) == uid,
                  "session réelle : 12 lecteurs partagent le jeton renouvelé du compte QA")
        let neuf = try await SacreServeur.etatCoffre(jwt: jwt)
        try check(neuf.soldeOr == 0 && neuf.soldeArgent == 0 && neuf.boostersOr == 0 && neuf.boostersNoirs == 0,
                  "vrai décodeur Coffre : compte neuf à zéro")
        let initiales = try await CartesServeur.evenements(jwt: jwt)
        let initiale = try await SacreServeur.maCollection(jwt: jwt)
        try check(initiales.isEmpty && initiale.isEmpty, "clients Annonces et Collection : compte neuf vide")
        _ = try await CartesServeur.objet("definir_profil", jwt: jwt,
            corps: ["p_prenom": "Swift QA", "p_langue": "fr", "p_but": "force", "p_objectif_hebdo": 4])
        let container = try ModelContainer(for: Workout.self, LoggedExercise.self, StrengthSet.self,
            CardioPhase.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        let w = Workout(startedAt: Date().addingTimeInterval(-600), endedAt: Date().addingTimeInterval(-2))
        w.recompenseARegler = true; ctx.insert(w)
        let e = LoggedExercise(exerciseID: "hip-thrust", order: 0); ctx.insert(e); e.workout = w
        for i in 0..<5 {
            let set = StrengthSet(reps: 10, weight: i == 0 ? 5 : 90, order: i, isDone: i == 0)
            ctx.insert(set); set.loggedExercise = e
        }
        try ctx.save()
        ReglementSeance.shared.contexte = ctx
        await ReglementSeance.shared.reprendre()
        let r = EconomieWoop.shared.derniere
        let restant = await OutboxGains.shared.enAttente
        try check(r?.workoutId == w.remoteID.uuidString.lowercased() && !w.recompenseARegler && restant == 0,
                  "vrai règlement → sync HTTP → outbox HTTP → reçu sauvé et file vidée")
        let story = StorySession(workout: w)
        try check(story.series == 1 && story.sets.count == 1 && w.totalVolume == 50,
                  "front : une série faite parmi cinq prévues, volume 50 kg")
        try check(story.recompense?.pieces == 20 && story.recompense?.boosters == 1 && !story.recompenseEnAttente,
                  "story construite depuis le reçu réel : 20 pièces et un sachet")
        let rows = try await CartesServeur.objet("seances_depuis", jwt: jwt, corps: ["p_depuis": NSNull()]) as! [String: Any]
        let seances = rows["seances"] as! [[String: Any]]
        let exos = seances.first?["exercices"] as? [[String: Any]] ?? []
        try check(seances.count == 1 && (exos.first?["series"] as? [Any])?.count == 1,
                  "backend relu : seule la série faite a traversé le snapshot Swift")
        let avant = try await SacreServeur.etatCoffre(jwt: jwt)
        await OutboxGains.shared.poster(.finDeSeance(seance: w.remoteID, series: 1))
        let apres = try await SacreServeur.etatCoffre(jwt: jwt)
        try check(avant.soldeOr == apres.soldeOr && avant.boostersOr == apres.boostersOr && avant.version == apres.version,
                  "rejeu par la vraie outbox : ni pièce ni sachet supplémentaire")
        let events = try await CartesServeur.evenements(jwt: jwt)
        try check(!events.isEmpty && events.allSatisfy { $0.userId == uid }
                  && Set(events.map(\.id)).count == events.count,
                  "annonces réelles décodées : identifiants uniques et bon propriétaire")
        for event in events { await CartesServeur.acquitter(event) }
        let restantes = try await CartesServeur.evenements(jwt: jwt)
        try check(restantes.isEmpty, "acquittement par le client Swift : aucune annonce restante")
        let rejoue = try await SacreServeur.cloturerSeance(w.remoteID, series: 1, jwt: jwt)
        ReglementSeance.shared.recevoir(rejoue)
        let historique = StorySession(workout: w)
        try check(rejoue.recu?.evenements.isEmpty == true && historique.recompense == story.recompense,
                  "story après acquittement : même montant et même sachet, malgré events vide")
        await OutboxGains.shared.poster(.retourQuotidien)
        try check(EconomieWoop.shared.retour?.credite == true
                  && EconomieWoop.shared.retour?.montant == neuf.piecesRetourQuotidien,
                  "Claim quotidien via outbox : montant réglé par le serveur")
        let paye = try await SacreServeur.etatCoffre(jwt: jwt)
        await OutboxGains.shared.poster(.retourQuotidien)
        let second = try await SacreServeur.etatCoffre(jwt: jwt)
        try check(EconomieWoop.shared.retour?.credite == false && second.soldeOr == paye.soldeOr
                  && second.retourDisponible == false, "second Claim : solde inchangé et Welcome Back indisponible")
        let operation = CartesServeur.operation(user: uid, noir: false)
        try check(operation == CartesServeur.operation(user: uid, noir: false),
                  "client Cartes : opération d’ouverture conservée pour la reprise")
        let prepare = try await CartesServeur.objet("preparer_booster", jwt: jwt,
            corps: ["p_operation": operation.uuidString, "p_legendaire": false]) as! [String: Any]
        let booster = prepare["booster_id"] as! String
        let again = try await CartesServeur.objet("preparer_booster", jwt: jwt,
            corps: ["p_operation": operation.uuidString, "p_legendaire": false]) as! [String: Any]
        try check(again["booster_id"] as? String == booster, "préparation rejouée : même vrai sachet")
        let carte = try await CartesServeur.objet("attribuer_carte", jwt: jwt, corps: ["p_booster": booster]) as! [String: Any]
        let bis = try await CartesServeur.objet("attribuer_carte", jwt: jwt, corps: ["p_booster": booster]) as! [String: Any]
        try check(carte["acquisition_id"] as? String != nil && carte["acquisition_id"] as? String == bis["acquisition_id"] as? String,
                  "attribution RPC et reprise : un seul exemplaire")
        _ = try await CartesServeur.objet("confirmer_revelation", jwt: jwt, corps: ["p_booster": booster])
        CartesServeur.terminer(user: uid, noir: false)
        let col = try await SacreServeur.maCollection(jwt: jwt)
        try check(col.reduce(0) { $0 + $1.nombre } == 1, "vrai décodeur Collection : une carte conservée")
        let journal = try await SacreServeur.historique(jwt: jwt)
        try check(!journal.isEmpty && journal.allSatisfy { $0.id != nil }, "vrai décodeur Coffre : journal avec UUID serveur")
        let autreContainer = try ModelContainer(for: Workout.self, LoggedExercise.self, StrengthSet.self,
            CardioPhase.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        BancPreferences.valeur.removeObject(forKey: SupabaseSync.cleDepuis)
        let pull = await SupabaseSync.relire(dans: autreContainer.mainContext)
        let restaurees = try autreContainer.mainContext.fetch(FetchDescriptor<Workout>())
        try check(pull?.inserees == 1 && restaurees.first?.seriesPayantes == 1 && restaurees.first?.totalVolume == 50,
                  "vrai pull HTTP → base locale neuve : séance, série et volume retrouvés")
        try check(restaurees.first.map { StorySession(workout: $0).recompense == story.recompense } == true,
                  "reçu historique restauré après ouverture du sachet et acquittement des annonces")
        let stockAvantLecture = try await SacreServeur.etatCoffre(jwt: jwt)
        restaurees.first?.bilanRecompense = nil
        try autreContainer.mainContext.save()
        let secondPull = await SupabaseSync.relire(dans: autreContainer.mainContext)
        try check(secondPull?.inserees == 0 && restaurees.first.map { StorySession(workout: $0).recompense == story.recompense } == true,
                  "séance déjà importée et curseur posé : reçu manquant récupéré sans doublon")
        let stockApresLecture = try await SacreServeur.etatCoffre(jwt: jwt)
        let annoncesApresLecture = try await CartesServeur.evenements(jwt: jwt)
        try check(stockApresLecture.version == stockAvantLecture.version
                  && stockApresLecture.soldeOr == stockAvantLecture.soldeOr,
                  "relecture historique : aucun paiement ni changement de version du coffre")
        try check(Set(events.map(\.id)).isDisjoint(with: Set(annoncesApresLecture.map(\.id))),
                  "relecture historique : annonces de la séance non rejouées")
        do {
            _ = try await SacreServeur.etatCoffre(jwt: "jeton-invalide")
            try check(false, "jeton invalide accepté")
        } catch SacreServeur.Erreur.http(let code, _) where code == 401 {
            try check(true, "client Swift : jeton invalide refusé HTTP 401")
        }
    }

    static func fermerSession(_ jwt: String) async throws {
        var req = URLRequest(url: WoopConfig.supabaseURL.appending(path: "auth/v1/logout").appending(queryItems: [.init(name: "scope", value: "local")]))
        req.httpMethod = "POST"
        req.setValue(WoopConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else { throw SupabaseError.transport }
    }
}
