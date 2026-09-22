import SwiftUI
import SwiftData
import Observation

/// Un jour peut contenir plusieurs séances : aucune n'est masquée par `.first`.
@MainActor
@Observable
final class HistoriqueStories {
    var choix: [Workout] = []
    var choixOuvert = false
    var story: StoryLaunch?
    var chargement = false
    private var ticket = UUID()

    /// `parFin` (21-09) : la Route demande les séances par leur FIN — un
    /// galet = un jour, et c'est la fin qui donne le jour du galet.
    func ouvrir(jour: Date, contexte: ModelContext, parFin: Bool = false) {
        guard !chargement, story == nil else { return }
        let seances = (try? contexte.fetch(FetchDescriptor<Workout>())) ?? []
        choix = SeancesHistorique.duJour(jour, parmi: seances, parFin: parFin)
        if choix.count == 1, let w = choix.first { ouvrir(w, contexte: contexte) }
        else if choix.isEmpty {
            // Le silence est un bug : sans cette trace, un « View » qui
            // n'ouvre rien ne laisse aucune preuve (retour TestFlight 81).
            NavDiagnostic.noter("historique.jour-vide")
        } else { choixOuvert = true }
    }

    func ouvrir(_ workout: Workout, contexte: ModelContext) {
        guard !chargement, story == nil else { return }
        choixOuvert = false
        chargement = true
        ticket = UUID()
        let demande = ticket
        let generation = CompteEtat.shared.generationDonnees
        Task { @MainActor in
            await SupabaseSync.restaurerBilans(dans: contexte, pour: [workout])
            guard ticket == demande, generation == CompteEtat.shared.generationDonnees else { return }
            chargement = false
            story = StoryLaunch(workout: workout, rect: .zero)
        }
    }

    func oublier() {
        ticket = UUID()
        chargement = false
        choixOuvert = false
        choix = []
        story = nil
    }
}

struct HistoriqueStoriesHote: ViewModifier {
    @Bindable var historique: HistoriqueStories
    @Environment(\.modelContext) private var contexte

    func body(content: Content) -> some View {
        content
            .confirmationDialog(L("Séances de ce jour", "Sessions on this day"),
                                isPresented: $historique.choixOuvert, titleVisibility: .visible) {
                ForEach(historique.choix, id: \.remoteID) { w in
                    Button(libelle(w)) { historique.ouvrir(w, contexte: contexte) }
                }
                Button(L("Annuler", "Cancel"), role: .cancel) {}
            }
            .overlay {
                if historique.chargement {
                    ProgressView().tint(.white).allowsHitTesting(false)
                        .accessibilityLabel(L("Chargement de la séance", "Loading session"))
                }
            }
            .fullScreenCover(item: $historique.story) { launch in
                StoryPortal(from: launch.rect, fromRadius: 18,
                            session: StorySession(workout: launch.workout)) {
                    historique.story = nil
                }
                .presentationBackground(.clear)
                .couvreLaHome()
            }
            .onChange(of: CompteEtat.shared.generationDonnees) { _, _ in historique.oublier() }
    }

    private func libelle(_ w: Workout) -> String {
        let format = DateFormatter()
        format.locale = Locale(identifier: Langue.en ? "en_US" : "fr_FR")
        format.dateFormat = Langue.en ? "h:mm a" : "HH:mm"
        let heure = format.string(from: w.startedAt)
        let nom = w.categories.first?.nomLocalise ?? L("Séance", "Session")
        return "\(heure) · \(nom) · \(max(1, Int(w.duration / 60))) min"
    }
}
