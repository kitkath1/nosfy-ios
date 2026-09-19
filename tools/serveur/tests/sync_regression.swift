import Foundation

enum WoopConfig {
    static let isConfigured = true
    static let supabaseURL = URL(string: "https://nosfy.invalid")!
    static let supabaseAnonKey = "publishable-test"
}
actor SupabaseSession {
    static let shared = SupabaseSession()
    func token() async throws -> String { "test-jwt" }
    func currentUserID() async throws -> String { "current-user" }
    func invalidate() async {}
    static func check(_ response: URLResponse, _ data: Data) throws {
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }
}
actor OutboxGains {
    static let shared = OutboxGains()
    var vidages = 0
    func vider() { vidages += 1 }
}
struct Serie {
    let remoteID = UUID()
    var reps = 10, weight = 20.0, order = 0, isDone = true
}
struct Phase {
    let remoteID = UUID()
    var kindRaw = "effort", seconds = 20, speed = 8.0, incline = 1.0, cycleIndex = 0, order = 0
}
struct Exercice {
    let remoteID = UUID()
    var exerciseID = "biceps", order = 0
    var orderedSets = [Serie(), Serie(isDone: false)]
    var phasesFaites = [Phase(), Phase(seconds: 0)]
    var longueurs = 20, metresParLongueur = 25
}
struct Workout {
    let remoteID = UUID()
    var startedAt = Date().addingTimeInterval(-60), endedAt: Date? = Date(), notes = "test"
    var orderedExercises = [Exercice()]
}
final class Transport: URLProtocol {
    static var requetes: [URLRequest] = []
    static var code = 200
    static var reponse = #"{"ok":true}"#
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "nosfy.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requetes.append(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!,statusCode: Self.code,httpVersion: nil,headerFields: nil)!,cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self,didLoad:Data(Self.reponse.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main struct Tests {
    static var nombre = 0
    static func check(_ v: Bool, _ nom: String) { precondition(v,nom); nombre += 1;print("PASS " + nom) }
    @MainActor static func main() async throws {
        URLProtocol.registerClass(Transport.self)
        let snap = Workout().snapshot()
        check(snap.exercises[0].sets.count == 1,"séries prévues exclues")
        check(snap.exercises[0].phases.count == 1,"phases sans durée exclues")
        check(snap.exercises[0].longueurs == 20,"piscine conservée")
        let sync = SupabaseSync()
        try await sync.pousser([snap])
        check(Transport.requetes.count == 1,"une transaction pour tout l'arbre")
        let req = Transport.requetes[0]
        check(req.url!.path == "/rest/v1/rpc/synchroniser_seance" && req.httpMethod == "POST","RPC atomique appelée")
        check(req.value(forHTTPHeaderField:"Authorization") == "Bearer test-jwt","session courante transmise")
        let data: Data
        if let body = req.httpBody { data = body } else {
            let stream = req.httpBodyStream!;stream.open();defer { stream.close() }
            var buffer = [UInt8](repeating:0,count:4096), body = Data()
            while stream.hasBytesAvailable { let n = stream.read(&buffer,maxLength:buffer.count);if n <= 0 { break };body.append(buffer,count:n) }
            data = body
        }
        let json = try JSONSerialization.jsonObject(with:data) as! [String:Any]
        check((json["p_workout"] as! [String:Any])["id"] as? String == snap.id,"UUID de séance conservé")
        check((json["p_series"] as! [[String:Any]]).count == 1 && (json["p_phases"] as! [[String:Any]]).count == 1 && (json["p_piscines"] as! [[String:Any]]).count == 1,"réalisations groupées dans le même corps")
        Transport.code = 503
        do { try await sync.pousser([snap]);preconditionFailure("503 avalé") } catch { check(true,"échec remonte pour préserver le compte local") }
        await sync.push([snap])
        check(await OutboxGains.shared.vidages == 0,"échec ne déclenche pas les gains")
        Transport.code = 200;Transport.reponse = #"{"ok":false}"#
        do { try await sync.pousser([snap]);preconditionFailure("réponse invalide acceptée") } catch { check(true,"accusé incomplet refusé") }
        Transport.reponse = #"{"ok":true}"#
        await sync.push([snap])
        check(await OutboxGains.shared.vidages == 1,"sauvegarde confirmée relance les gains")
        let avantAutreCompte = Transport.requetes.count
        do {
            try await sync.pousser([snap], proprietaire: "ancien-compte")
            preconditionFailure("ancien propriétaire accepté")
        } catch is CancellationError {
            check(Transport.requetes.count == avantAutreCompte, "changement de compte : aucun ancien instantané envoyé")
        }
        print("\(nombre) contrôles PASS")
    }
}
