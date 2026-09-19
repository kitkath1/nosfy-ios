import Foundation
import SwiftData

func L(_ fr: String, _ en: String) -> String { fr }
enum Langue { static let en = false }
extension ExerciseCategory { var nomLocalise: String { rawValue } }
struct SlateLigne { var reps:Int;var kilos:Double;var seconds:Int;var done:Bool }
struct SlateGroupe { var id:String;var exercise:Exercise;var rows:[SlateLigne] }
struct EvenementGain { var genre:String;var montant:Int }
struct Recu { var evenements:[EvenementGain] = [] }
enum SacreServeur {
 struct Fait { var kind:String;var detail:[String:Any] = [:] }
 struct ClotureSeance {
  var pieces=20;var piecesTotal=20;var boostersGagnes:Int?=1;var argentSeance=false
  var recu:Recu?=Recu();var faits:[Fait]=[];var workoutId:String?
 }
}
@MainActor final class CompteEtat {
 static let shared=CompteEtat();var generationDonnees=UUID()
 var enPorte=false;var seanceEnCours=false;var finSeancePresentee=false
}
@MainActor final class EconomieWoop {
 static let shared=EconomieWoop();static var possible=true
 var piecesParSerie=25;var serveur=true;var retourDisponible=true
 var or=0;var piecesRetourQuotidien=10
 func reclamerRetour() {}
}
@MainActor final class SacreEtat { static let shared=SacreEtat();var manegeOuvert=false;var popupOuverte=false }
@MainActor final class DepartEtat {
 static let shared=DepartEtat();var cheminOuvert=false;var panneauOuvert=false;var pauseOuverte=false
 var welcomeOuverte=false;var welcomePremiereOuverte=false;var visiteOuverte=false
}
@MainActor enum PremiereArrivee { static var premiereFois=false }
actor SupabaseSession {
 static let shared=SupabaseSession()
 func currentUserID() -> String { "qa-owner" }
}
enum GainEnAttente {case finDeSeance(seance:UUID,series:Int)}
actor OutboxGains {
 static let shared=OutboxGains();var identiteGeneration=UUID()
 var seancesARejouer:Set<UUID>=[];var appels=0;var series:[Int]=[]
 func retenir(_ gain:GainEnAttente,siGeneration:UUID?=nil) {
  guard siGeneration==nil || siGeneration==identiteGeneration else{return}
  if case .finDeSeance(let id,let n)=gain {seancesARejouer.insert(id);series.append(n)}
 }
 func vider(){appels+=1}
}
actor SupabaseSync {
 struct Snapshot:Sendable {var id:UUID}
 static let shared=SupabaseSync();var envois=0;var fileAvantReseau=false
 func push(_ s:[Snapshot],proprietaire:String?=nil)async {
  if !s.isEmpty {envois+=1;fileAvantReseau=await !OutboxGains.shared.seancesARejouer.isEmpty}
 }
}
extension Workout {func snapshot()->SupabaseSync.Snapshot{.init(id:remoteID)}}
@main struct Tests {
 @MainActor static var n=0
 @MainActor static func check(_ b:Bool,_ nom:String){precondition(b,nom);n+=1;print("PASS "+nom)}
 @MainActor static func main()async throws {
  let url=URL(fileURLWithPath:CommandLine.arguments[2])
  let cfg=ModelConfiguration(url:url)
  let container=try ModelContainer(for:Workout.self,LoggedExercise.self,StrengthSet.self,CardioPhase.self,configurations:cfg)
  let ctx=container.mainContext
  if CommandLine.arguments[1]=="semer" {
   let w=Workout(startedAt:Date().addingTimeInterval(-600),endedAt:Date())
   w.recompenseARegler=true;ctx.insert(w)
   let e=LoggedExercise(exerciseID:"hip-thrust",order:0);ctx.insert(e);e.workout=w
   for i in 0..<5 {
    let s=StrengthSet(reps:10,weight:i==0 ? 5:90,order:i,isDone:i==0)
    ctx.insert(s);s.loggedExercise=e
   }
   try ctx.save()
   check(w.seriesPayantes==1,"une série faite parmi cinq prévues")
   print("Arrêt du processus après sauvegarde, avant tout appel réseau")
   return
  }
  let w=try ctx.fetch(FetchDescriptor<Workout>()).first { $0.seriesPayantes == 1 }!
  if CommandLine.arguments[1]=="migrer" {
   check(w.seriesPayantes==1,"migration conserve l’historique déjà présent")
   check(!w.recompenseARegler && w.bilanRecompense==nil,"nouveaux champs sans gain rétroactif sur ancienne base")
   return
  }
  if CommandLine.arguments[1]=="recu" {
   check(!w.recompenseARegler,"reçu acquitté conservé après nouveau processus")
   let story=StorySession(workout:w)
   check(story.recompense?.pieces==190 && story.recompense?.boosters==3,"story retrouve le bilan persistant")
   check(story.top == .cardio && story.double != nil,"faits persistants retrouvés")
   return
  }

  check(w.endedAt != nil && w.recompenseARegler,"nouveau processus retrouve clôture et demande de gain")
  let pending=StorySession(workout:w)
  check(pending.series==1 && pending.sets.count==1,"story ne compte que les séries faites")
  check(pending.sets[0].coins==0,"aucune pièce par série inventée avant réponse")
  check(pending.recompenseEnAttente && pending.recompense==nil,"pas de faux gain avant réponse")
  ReglementSeance.shared.contexte=ctx
  await ReglementSeance.shared.reprendre()
  check(await SupabaseSync.shared.fileAvantReseau,"gain mis en file avant première synchro")
  check(await OutboxGains.shared.series==[1],"la reprise transmet le nombre réellement fait")
  check(w.recompenseARegler,"échec ou absence de réponse conserve le marqueur")
  var c=SacreServeur.ClotureSeance(workoutId:w.remoteID.uuidString)
  ReglementSeance.shared.recevoir(c)
  check(!w.recompenseARegler,"réponse sauvegardée acquitte la clôture locale")
  let done=StorySession(workout:w)
  check(done.recompense?.pieces==20 && done.recompense?.boosters==1,"vingt pièces affichent le sachet forfaitaire confirmé")
  check(!done.recompenseEnAttente,"le bilan confirmé sort de l’attente")
  c.piecesTotal=190;c.boostersGagnes=3;c.argentSeance=true
  c.faits=[.init(kind:"top_cardio"),.init(kind:"double_jour",detail:["heures":["08:00","19:00"],"minutes":32])]
  ReglementSeance.shared.recevoir(c)
  let replay=StorySession(workout:w)
  check(replay.recompense?.boosters==3,"reçu rejoué après annonces acquittées conserve les trois sachets")
  check(replay.recompense?.pieces==190 && replay.recompense?.argent==1,"bilan garde pièces totales et argent du serveur")
  check(replay.top == .cardio && replay.double?.heures.count==2,"faits TOP et double appartiennent à la même séance")
  let empty=Workout(endedAt:Date());ctx.insert(empty)
  let se=StorySession(workout:empty)
  check(se.series==0 && se.sets.isEmpty && !empty.faitPourRoute,"séance vide : aucune série démo et aucun galet")
  let pool=LoggedExercise(exerciseID:"piscine",order:0);ctx.insert(pool);pool.workout=empty;pool.longueurs=2
  check(empty.faitPourRoute && StorySession(workout:empty).sets.isEmpty,"piscine pure avance sans inventer de musculation")
  let other=SacreServeur.ClotureSeance(workoutId:UUID().uuidString)
  ReglementSeance.shared.recevoir(other)
  check(StorySession(workout:empty).recompense==nil,"un autre reçu ne repeint pas la séance")
  let user=CompteEtat.shared;let dep=DepartEtat.shared
  for block in 0..<8 {
   user.seanceEnCours=block==0;user.finSeancePresentee=block==1;dep.cheminOuvert=block==2
   dep.panneauOuvert=block==3;dep.pauseOuverte=block==4;user.enPorte=block==5
   PremiereArrivee.premiereFois=block==6;EconomieWoop.shared.retourDisponible=block != 7
   dep.welcomeOuverte=false;Compte.proposerWelcomeBack()
   check(!dep.welcomeOuverte,"Welcome Back retenu garde \(block)")
  }
  user.seanceEnCours=false;user.finSeancePresentee=false;dep.cheminOuvert=false
  dep.panneauOuvert=false;dep.pauseOuverte=false;user.enPorte=false
  PremiereArrivee.premiereFois=false;EconomieWoop.shared.retourDisponible=true
  Compte.proposerWelcomeBack();check(dep.welcomeOuverte,"Welcome Back disponible sur accueil libre")
  print("\(n) contrôles PASS dans le second processus")
 }
}
