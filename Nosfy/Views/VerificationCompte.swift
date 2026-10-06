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
    /// (06-10, « la connexion n'est pas résolue ») : la session gardée se lit
    /// AVANT l'appel — un renouvellement refusé pendant la lecture l'efface
    /// (`suspendre`), et l'écran bloquait alors pour de bon ; une annulation
    /// laissait le sablier tourner sans fin ; un réseau faible pouvait le
    /// faire tourner 80 s. Une personne connue au questionnaire fini entre
    /// donc sur TOUTE panne, et au plus tard après 8 s.
    @discardableResult
    @MainActor
    private func lire() async -> Bool {
        let connue = !InscriptionCompte.aReprendre && SupabaseSession.sessionGardee()
        do {
            let profil = try await Self.profilEnTemps(connue ? 8 : nil)
            try Task.checkCancellation()
            onProfil(profil)
            return true
        } catch {
            // Un renouvellement refusé PENDANT la lecture — par cet appel ou par
            // un autre du lancement — a suspendu la session : la personne reste
            // connue (son identité attend), elle entre (banc E du 06-10).
            let suspendue = !InscriptionCompte.aReprendre && SupabaseSession.identiteSuspendue != nil
            if connue || suspendue {
                print("[erreur] verification-compte : \(error.localizedDescription) → personne connue, questionnaire fini : elle entre sans le serveur")
                onProfil(Self.profilDuTelephone)
                return true
            }
            guard let cas = ErreurNosfy.cas(pour: error) else { return false }
            print("[erreur] verification-compte : \(cas)")
            withAnimation(.easeOut(duration: 0.4)) {
                chargement = false
                panne = cas
            }
            return false
        }
    }

    /// `profil()`, borné : au-delà de `limite` secondes, une panne de réseau.
    private static func profilEnTemps(_ limite: Double?) async throws -> ProfilServeur.Profil {
        guard let limite else { return try await ProfilServeur.profil() }
        return try await withThrowingTaskGroup(of: ProfilServeur.Profil.self) { g in
            g.addTask { try await ProfilServeur.profil() }
            g.addTask {
                try await Task.sleep(for: .seconds(limite))
                throw URLError(.timedOut)
            }
            defer { g.cancelAll() }
            guard let p = try await g.next() else { throw URLError(.timedOut) }
            return p
        }
    }

    /// Ce que le téléphone tient d'elle, sans réseau : assez pour l'aiguillage
    /// (le questionnaire est fini) — jamais un fait inventé.
    private static var profilDuTelephone: ProfilServeur.Profil {
        ProfilServeur.Profil(existe: true, onboardingTermine: true, langue: Langue.courante,
                             prenom: ProfilServeur.prenomLocal, but: ProfilServeur.butLocal,
                             objectifHebdo: Goal.weeklyTarget, exercices: [], seances: 0)
    }
}
