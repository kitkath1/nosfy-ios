import Foundation

enum WoopConfig {
 static let isConfigured = true
 static let supabaseURL = URL(string:"https://nosfy.invalid")!
 static let supabaseAnonKey = "test"
}
actor SupabaseSession {
 static let shared = SupabaseSession()
 func token() async throws -> String { "test" }
 static func check(_ r:URLResponse,_ d:Data)throws {
  guard (r as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
 }
}
@MainActor final class CompteEtat {
 static let shared = CompteEtat()
 var generationDonnees = UUID()
}
struct FetchDescriptor<T> {}
final class ModelContext {
 var workouts:[Workout]=[]; var exercises:[LoggedExercise]=[];var sets:[StrengthSet]=[];var phases:[CardioPhase]=[]
 func fetch(_ d:FetchDescriptor<Workout>)throws->[Workout]{workouts}
 func fetchCount(_ d:FetchDescriptor<Workout>)throws->Int{workouts.count}
 func insert<T>(_ item:T) {
  if let x=item as? Workout {workouts.append(x)}
  if let x=item as? LoggedExercise {exercises.append(x)}
  if let x=item as? StrengthSet {sets.append(x)}
  if let x=item as? CardioPhase {phases.append(x)}
 }
 func save()throws{}
}
final class Workout {
 var remoteID=UUID();var startedAt:Date;var endedAt:Date?;var notes=""
 init(startedAt:Date,endedAt:Date?){self.startedAt=startedAt;self.endedAt=endedAt}
}
final class LoggedExercise {
 var remoteID=UUID();var workout:Workout?;var longueurs=0;var metresParLongueur=25;var exerciseID:String;var order:Int
 init(exerciseID:String,order:Int){self.exerciseID=exerciseID;self.order=order}
}
final class StrengthSet {
 var remoteID=UUID();var loggedExercise:LoggedExercise?;let isDone:Bool
 init(reps:Int,weight:Double,order:Int,isDone:Bool){self.isDone=isDone}
}
enum PhaseKind:String {case effort,recuperation}
final class CardioPhase {
 var remoteID=UUID();var loggedExercise:LoggedExercise?;let isDone:Bool
 init(kind:PhaseKind,seconds:Int,speed:Double,cycleIndex:Int,order:Int,incline:Double,isDone:Bool){self.isDone=isDone}
}
final class Transport:URLProtocol {
 static let lock=NSLock();static var pending:Transport?
 override class func canInit(with r:URLRequest)->Bool{r.url?.host=="nosfy.invalid"}
 override class func canonicalRequest(for r:URLRequest)->URLRequest{r}
 override func startLoading(){Self.lock.lock();Self.pending=self;Self.lock.unlock()}
 override func stopLoading(){}
 static func take()->Transport? {lock.lock();defer{lock.unlock()};let p=pending;pending=nil;return p}
 func reply(_ body:Data,code:Int=200){
  client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:code,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed)
  client?.urlProtocol(self,didLoad:body);client?.urlProtocolDidFinishLoading(self)
 }
}
@main struct Tests {
 static var n=0
 static func check(_ b:Bool,_ name:String){precondition(b,name);n+=1;print("PASS "+name)}
 @MainActor static func waiting()async throws->Transport {
  for _ in 0..<300 {if let p=Transport.take(){return p};try await Task.sleep(for:.milliseconds(10))}
  fatalError("requête absente")
 }
 @MainActor static func main()async throws{
  URLProtocol.registerClass(Transport.self)
  defer{UserDefaults.standard.removeObject(forKey:SupabaseSync.cleDepuis)}
  UserDefaults.standard.removeObject(forKey:SupabaseSync.cleDepuis)
  let ctx=ModelContext();let id=UUID();let now="2026-09-18T10:00:00Z"
  let ex:[String:Any] = ["id":UUID().uuidString,"exercise_id":"hip-thrust","series":[["id":UUID().uuidString,"reps":10]],"phases":[["id":UUID().uuidString,"kind":"effort","seconds":30]],"piscine":["longueurs":20,"metres_par_longueur":25]]
  let body=try JSONSerialization.data(withJSONObject:["serveur_at":now,"total":1,"rendues":1,"seances":[["id":id.uuidString,"started_at":"2026-09-18T09:00:00Z","ended_at":now,"exercices":[ex]]]])
  let first=Task{@MainActor in await SupabaseSync.relire(dans:ctx)}
  let p=try await waiting();p.reply(body);let r=await first.value
  check(r?.inserees==1 && ctx.workouts.first?.remoteID==id,"historique serveur réinséré avec son identité")
  check(ctx.sets.count==1 && ctx.sets[0].isDone,"séries faites restaurées pour la Route")
  check(ctx.phases.count==1 && ctx.phases[0].isDone && ctx.exercises[0].longueurs==20,"cardio et piscine restaurés")
  check(UserDefaults.standard.string(forKey:SupabaseSync.cleDepuis)==now,"curseur posé après lecture")
  let replay=Task{@MainActor in await SupabaseSync.relire(dans:ctx)}
  let p2=try await waiting();p2.reply(body);_ = await replay.value
  check(ctx.workouts.count==1 && ctx.sets.count==1,"relecture sans doublons")
  let suivant=ModelContext();UserDefaults.standard.removeObject(forKey:SupabaseSync.cleDepuis)
  let late=Task{@MainActor in await SupabaseSync.relire(dans:suivant)}
  let p3=try await waiting();CompteEtat.shared.generationDonnees=UUID();p3.reply(body)
  let refuse=await late.value
  check(refuse==nil && suivant.workouts.isEmpty,"réponse du compte précédent écartée")
  check(UserDefaults.standard.string(forKey:SupabaseSync.cleDepuis)==nil,"ancien compte ne pose aucun curseur")
  let offline=Task{@MainActor in await SupabaseSync.relire(dans:suivant)}
  let p4=try await waiting();p4.reply(Data("{}".utf8),code:503);_ = await offline.value
  check(suivant.workouts.isEmpty && UserDefaults.standard.string(forKey:SupabaseSync.cleDepuis)==nil,"échec réseau : données et curseur inchangés")
  let reconnect=Task{@MainActor in await SupabaseSync.relire(dans:suivant)}
  let p5=try await waiting();p5.reply(body);_ = await reconnect.value
  check(suivant.workouts.count==1,"nouvelle lecture après reconnexion récupère les séances")
  print("\(n) contrôles pull PASS — transport et stockage isolés")
 }
}
