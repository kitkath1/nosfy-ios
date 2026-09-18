import SwiftUI

/// Reprend une connexion interrompue avant la réponse de profil().
///
/// 18-09 : la panne se dit avec l'écran d'erreur de la maison (`EcranErreur`,
/// la bête, Réessayer, le mode avion lu) — plus de texte nu sur le noir. Il
/// bloque (pas de « Plus tard ») : sans profil, la racine ne sait pas où aller.
struct VerificationCompte: View {
    var onProfil: (ProfilServeur.Profil) -> Void
    @State private var chargement = true
    @State private var panne: ErreurNosfy.Cas?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if chargement {
                VStack(spacing: 20) {
                    ProgressView().tint(.white)
                    Text(L("Ouverture de ton compte…", "Opening your account…"))
                }
                .font(.inter(16))
                .foregroundStyle(.white)
                .padding(32)
            } else if let panne {
                EcranErreur(cas: panne, reessayer: { await lire() })
                    .transition(.opacity)
            }
        }
        .task { await lire() }
    }

    /// Lire le profil ; vrai si la racine a été servie.
    @discardableResult
    @MainActor
    private func lire() async -> Bool {
        do {
            let profil = try await ProfilServeur.profil()
            try Task.checkCancellation()
            onProfil(profil)
            return true
        } catch {
            guard let cas = ErreurNosfy.cas(pour: error) else { return false }
            print("[erreur] verification-compte : \(cas)")
            withAnimation(.easeOut(duration: 0.4)) {
                chargement = false
                panne = cas
            }
            return false
        }
    }
}
