import Foundation
import SwiftData

@main struct JoursTests {
    @MainActor static func main() throws {
        let container = try ModelContainer(for: Workout.self, LoggedExercise.self, StrengthSet.self,
            CardioPhase.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        let iso = ISO8601DateFormatter()
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Paris")!
        func date(_ s: String) -> Date { iso.date(from: s)! }
        func seance(_ debut: String, terminee: Bool = true, travail: Bool = true) -> Workout {
            let d = date(debut), w = Workout(startedAt: d, endedAt: terminee ? d.addingTimeInterval(600) : nil)
            ctx.insert(w)
            if travail {
                let e = LoggedExercise(exerciseID: "hip-thrust", order: 0); ctx.insert(e); e.workout = w
                let s = StrengthSet(reps: 10, weight: 5, order: 0, isDone: true); ctx.insert(s); s.loggedExercise = e
            }
            return w
        }
        let a = seance("2026-09-18T23:30:00Z"), b = seance("2026-09-19T16:00:00Z")
        let autre = seance("2026-09-18T09:00:00Z")
        let ouverte = seance("2026-09-19T12:00:00Z", terminee: false)
        let vide = seance("2026-09-19T13:00:00Z", travail: false)
        let toutes = [b, vide, autre, ouverte, a]
        let jour = SeancesHistorique.duJour(date("2026-09-19T10:00:00Z"), parmi: toutes, calendrier: c)
        precondition(jour.map(\.remoteID) == [a.remoteID, b.remoteID])
        print("PASS jour local : deux séances classées, minuit UTC respecté, vide et séance ouverte exclus")
        precondition(SeancesHistorique.duJour(date("2026-09-17T10:00:00Z"), parmi: toutes, calendrier: c).isEmpty)
        print("PASS jour sans séance : aucune story inventée")
        precondition(SeancesHistorique.duJour(date("2026-09-18T10:00:00Z"), parmi: toutes, calendrier: c).map(\.remoteID) == [autre.remoteID])
        print("PASS jour voisin : sa propre séance seulement")
        for instant in ["2026-03-29T14:00:00Z", "2026-10-25T14:00:00Z"] {
            let jours = (0..<7).map { SeancesHistorique.jourDeSemaine($0, maintenant: date(instant), calendrier: c)! }
            precondition(c.component(.weekday, from: jours[0]) == 2 && c.component(.weekday, from: jours[6]) == 1)
            precondition(Set(jours).count == 7 && jours.allSatisfy { c.component(.hour, from: $0) == 0 })
        }
        print("PASS jours du widget : lundi à dimanche, changements d'heure compris")
        precondition(SeancesHistorique.jourDeSemaine(-1) == nil && SeancesHistorique.jourDeSemaine(7) == nil)
        print("PASS index hors semaine ignoré")
        print("5 contrôles historique des jours PASS")
    }
}
