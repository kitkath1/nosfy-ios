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
            guard try await attendreHome() else { return }
            SondeVol.shared.demarrer()
            let captureID = Int(Date().timeIntervalSince1970)
            let parcours: [(Phase, Int)] = [
                (.complete, 35), (.sansWidgets, 25), (.sansRoute, 25),
                (.fondSeul, 25), (.nu, 25), (.complete, 25)
            ]
            for (index, element) in parcours.enumerated() {
                let (etape, duree) = element
                poser(etape)
                // Preuve du rendu, y compris des suppressions de blocs.
                // Cette transition est exclue des fenêtres de coût retenues.
                try await Task.sleep(for: .seconds(0.3))
                guard verifierContexte(),
                      photographier(id: captureID, index: index) else { return }
                for _ in 0..<duree {
                    try await Task.sleep(for: .seconds(1))
                    // Un changement de page, une séance ou la veille annulent
                    // immédiatement le banc ; ils ne deviennent pas une mesure.
                    guard verifierContexte() else { return }
                }
            }
        } catch {
            NavDiagnostic.noter("banc-home-annule", destination: "tache-annulee")
        }
    }

    @MainActor
    private func attendreHome() async throws -> Bool {
        // Le splash et la lecture du compte peuvent dépasser cinq secondes.
        // Attendre la vraie Home, sans relancer l'app ni contourner sa porte.
        try await Task.sleep(for: .seconds(5))
        var dernierObstacle: String?
        var passagesPrets = 0
        for _ in 0..<60 {
            try Task.checkCancellation()
            // Même action que « Later » : aucun Claim ni écriture de compte.
            if UIApplication.shared.applicationState == .active,
               NavEtat.shared.page == .home,
               DepartEtat.shared.welcomeOuverte {
                DepartEtat.shared.welcomeOuverte = false
                NavDiagnostic.noter("banc-home-welcome-later")
                passagesPrets = 0
            }
            let obstacle = obstacleAuBanc
            if let obstacle {
                passagesPrets = 0
                if obstacle != dernierObstacle {
                    NavDiagnostic.noter("banc-home-attente", destination: obstacle)
                }
                // Une navigation ou mise en arrière-plan annule le test.
                if NavEtat.shared.page != .home
                    || UIApplication.shared.applicationState == .background {
                    return verifierContexte()
                }
            } else {
                passagesPrets += 1
                if passagesPrets >= 5 { return true } // Deux secondes stables.
            }
            dernierObstacle = obstacle
            try await Task.sleep(for: .milliseconds(500))
        }
        NavDiagnostic.noter("banc-home-annule",
                            destination: "attente-expiree;\(obstacleAuBanc ?? "stabilisation")")
        return false
    }

    @MainActor
    private var obstacleAuBanc: String? {
        if UIApplication.shared.applicationState != .active { return "app-inactive" }
        if NavEtat.shared.page != .home { return "autre-page" }
        if SondeVol.shared.enSeance { return "seance" }
        if DepartEtat.shared.homeDort { return "home-dort" }
        if DepartEtat.shared.visiteOuverte { return "visite" }
        if DepartEtat.shared.welcomeOuverte { return "welcome" }
        if DepartEtat.shared.welcomePremiereOuverte { return "premiere-arrivee" }
        if CompteEtat.shared.enPorte { return "porte" }
        if SacreEtat.shared.popupOuverte { return "sacre" }
        if SacreEtat.shared.manegeOuvert { return "manege" }
        if PlayerEtat.shared.couvre { return "player" }
        return nil
    }

    @MainActor
    private func verifierContexte() -> Bool {
        guard let obstacle = obstacleAuBanc else { return true }
        NavDiagnostic.noter("banc-home-annule", destination: obstacle)
        return false
    }

    @MainActor
    private func photographier(id: Int, index: Int) -> Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let fenetre = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
        else { return false }
        var dessine = false
        let rendu = UIGraphicsImageRenderer(bounds: fenetre.bounds).image { _ in
            dessine = fenetre.drawHierarchy(in: fenetre.bounds, afterScreenUpdates: true)
        }
        guard dessine, let png = rendu.pngData() else { return false }
        let nom = "banc-home-\(id)-\(index)-\(phase.rawValue).png"
        let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            try png.write(to: dossier.appendingPathComponent(nom), options: .atomic)
            NavDiagnostic.noter("banc-home-capture", destination: nom)
            return true
        } catch {
            NavDiagnostic.noter("banc-home-capture-echec", destination: error.localizedDescription)
            return false
        }
    }

    @MainActor
    private func poser(_ prochaine: Phase) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { phase = prochaine }
        NavDiagnostic.noter("banc-home-phase", destination: prochaine.rawValue)
    }
}
