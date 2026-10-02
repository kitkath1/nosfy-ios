import SwiftUI

/// BANC DES VERROUS DE LA HOME (01-10, retours TestFlight 85) — posé dans la
/// COPIE jetable seulement, jamais dans le dépôt. Il expose l'état de tout ce
/// qui peut endormir ou rendre sourde la home, sous une forme que le test UI
/// relit (`clé=valeur;…` dans le label d'accessibilité) et que la console
/// imprime à chaque changement.
struct SondeVerrousVue: View {
    var body: some View {
        let l = Self.ligne()
        Text(l)
            .font(.system(size: 6))
            .foregroundStyle(.white.opacity(0.02))
            .frame(width: 2, height: 2, alignment: .topLeading)
            .accessibilityElement()
            .accessibilityIdentifier("sonde-verrous")
            .accessibilityLabel(l)
            .allowsHitTesting(false)
            .onChange(of: l, initial: true) { _, n in
                print("[verrous] t=\(String(format: "%.1f", Date().timeIntervalSince(Self.t0))) \(n)")
            }
            .task { await Self.welcomeForcee() }
    }

    static let t0 = Date()

    @MainActor
    static func ligne() -> String {
        let r = RythmeEcran.shared
        let d = DepartEtat.shared
        let s = SacreEtat.shared
        let b = { (v: Bool) in v ? "1" : "0" }
        return "stories=\(r.stories.count);couv=\(r.couvertures.count);onglet=\(r.ongletActif)"
            + ";homeDort=\(b(d.homeDort));chemin=\(b(d.cheminOuvert));popup=\(b(s.popupOuverte))"
            + ";manege=\(b(s.manegeOuvert));pose=\(b(s.manegePose));welcome=\(b(d.welcomeOuverte))"
            + ";pause=\(b(d.pauseOuverte));couvreP=\(b(PlayerEtat.shared.couvre))"
            + ";recouvert=\(b(CouvertureFoyer.shared.recouvert))"
            + ";fiche=\(PlayerEtat.shared.ficheSeance?.id ?? "-")"
            + ";seance=\(b(CompteEtat.shared.seanceEnCours))"
    }

    /// `-welcomeForce` : la card Welcome Back s'ouvre 5 s après le lancement,
    /// sans attendre le serveur (on mesure le GESTE du Claim, pas le versement).
    /// `-welcomeRobeTexte` force la robe « You're back ».
    @MainActor
    static func welcomeForcee() async {
        let a = CommandLine.arguments
        guard a.contains("-welcomeForce") else { return }
        try? await Task.sleep(for: .seconds(5))
        let d = DepartEtat.shared
        d.welcomeRobe = a.contains("-welcomeRobeTexte") ? .texte : .video
        d.welcomeOuverte = true
    }
}
