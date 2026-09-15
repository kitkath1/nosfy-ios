import SwiftUI
import UIKit

/// Diagnostic ponctuel exécuté sur l'iPhone : aucune connexion au Mac n'est
/// nécessaire après le lancement. Les suppressions de blocs ne persistent pas.
@Observable
final class BancCoutHome {
    static let demande = CommandLine.arguments.contains("-bancCoutHome")
    static let shared = BancCoutHome()

    enum Phase: String {
        case complete, sansWidgets, sansRoute, fondSeul, nu
    }

    private(set) var phase: Phase = .complete
    @ObservationIgnored private var lance = false

    var pullSonde: Int? {
        guard Self.demande else { return nil }
        switch phase {
        case .fondSeul: return 1
        case .nu: return 3
        default: return 0
        }
    }

    @MainActor
    func executer() async {
        guard Self.demande, !lance else { return }
        lance = true
        // La mesure ne change ni les données du compte ni le moteur thermique.
        // Les catégories thermiques/protection sont enregistrées à chaque ligne.
        defer {
            poser(.complete)
            NavDiagnostic.noter("banc-home-fin")
            SondeVol.shared.arreter()
        }
        do {
            try await Task.sleep(for: .seconds(5))
            guard contexteValide else { return }
            SondeVol.shared.demarrer()
            let parcours: [(Phase, Int)] = [
                (.complete, 35), (.sansWidgets, 25), (.sansRoute, 25),
                (.fondSeul, 25), (.nu, 25), (.complete, 25)
            ]
            for (etape, duree) in parcours {
                poser(etape)
                for _ in 0..<duree {
                    try await Task.sleep(for: .seconds(1))
                    // Un changement de page, une séance ou la veille annulent
                    // immédiatement le banc ; ils ne deviennent pas une mesure.
                    guard contexteValide else { return }
                }
            }
        } catch { /* L'annulation restaure aussi la Home par le defer. */ }
    }

    @MainActor
    private var contexteValide: Bool {
        UIApplication.shared.applicationState == .active
            && NavEtat.shared.page == .home
            && !SondeVol.shared.enSeance
            && !DepartEtat.shared.homeDort
            && !DepartEtat.shared.visiteOuverte
            && !PlayerEtat.shared.couvre
    }

    @MainActor
    private func poser(_ prochaine: Phase) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { phase = prochaine }
        NavDiagnostic.noter("banc-home-phase", destination: prochaine.rawValue)
    }
}
