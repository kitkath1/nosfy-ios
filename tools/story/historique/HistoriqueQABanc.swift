// Copié seulement dans le projet temporaire du banc, jamais dans l'app livrée.
import SwiftUI
import SwiftData

struct HistoriqueQABanc: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if CommandLine.arguments.contains("-histoChambre") {
                ChambreRegularite(f: fenetre, fenetre: .semaine).padding(24)
            } else {
                CardSeances(faites: 3, joursFaits: [0, 1], vide: false,
                            interaction: .home(onEdition: {}))
                    .frame(width: 330, height: 330)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var fenetre: ChambreFenetre {
        var f = ChambreFenetre()
        f.faites = 3
        f.jours = (0..<7).map { i in
            let date = SeancesHistorique.jourDeSemaine(i)!
            var j = ChambreJour(date: date, numero: Calendar.current.component(.day, from: date))
            j.seances = i == 0 ? 2 : (i == 1 ? 1 : 0)
            return j
        }
        return f
    }

    @MainActor static func semer(in container: ModelContainer) {
        let ctx = container.mainContext
        try? ctx.delete(model: Workout.self)
        for (jour, heure, pieces) in [(0, 9, 20), (0, 18, 73), (1, 10, 41)] {
            let debut = Calendar.current.date(byAdding: .hour, value: heure,
                                              to: SeancesHistorique.jourDeSemaine(jour)!)!
            let w = Workout(startedAt: debut, endedAt: debut.addingTimeInterval(600))
            ctx.insert(w)
            let e = LoggedExercise(exerciseID: "hip-thrust", order: 0); ctx.insert(e); e.workout = w
            let s = StrengthSet(reps: 10, weight: 5, order: 0, isDone: true); ctx.insert(s); s.loggedExercise = e
            w.bilanRecompense = try? JSONSerialization.data(withJSONObject:
                ["pieces": pieces, "piecesMuscu": pieces, "boosters": 1, "argent": 0])
        }
        try? ctx.save()
    }
}
