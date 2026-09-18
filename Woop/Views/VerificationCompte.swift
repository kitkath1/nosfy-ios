import SwiftUI

/// Reprend une connexion interrompue avant la réponse de profil().
struct VerificationCompte: View {
    var onProfil: (ProfilServeur.Profil) -> Void
    @State private var chargement = true
    @State private var tentative = 0

    var body: some View {
        VStack(spacing: 20) {
            if chargement {
                ProgressView().tint(.white)
                Text(L("Ouverture de ton compte…", "Opening your account…"))
            } else {
                Text(L("Ton profil est indisponible pour le moment.", "Your profile is temporarily unavailable."))
                    .multilineTextAlignment(.center)
                Button(L("Réessayer", "Try again")) { tentative += 1 }
                    .buttonStyle(.borderedProminent)
            }
        }
        .font(.inter(16))
        .foregroundStyle(.white)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .task(id: tentative) {
            chargement = true
            do {
                let profil = try await ProfilServeur.profil()
                try Task.checkCancellation()
                onProfil(profil)
            } catch {
                chargement = false
            }
        }
    }
}
