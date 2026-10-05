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
            // ⚠️ 05-10 (TestFlight 86, « en sous-sol, réseau faible ou pas du
            // tout, le message noir d'erreur de Nosfy : impossible ») : cette
            // vérification est armée par CHAQUE entrée Apple (`verifierALaReprise`)
            // et ne s'éteint qu'à une lecture de profil RÉUSSIE — une entrée
            // faite sous un réseau faible la laissait armée, et chaque lancement
            // suivant sans réseau bloquait ici, derrière un écran sans « Plus
            // tard ». Or le téléphone SAIT déjà si le questionnaire est fini
            // (`InscriptionCompte.aReprendre`, posé à la dernière lecture) : une
            // personne connue entre avec ce qu'il tient — prénom, but — et la
            // vérification reste due pour la prochaine lecture avec réseau
            // (le drapeau n'est pas touché, `profil()` l'éteindra).
            if !InscriptionCompte.aReprendre, SupabaseSession.sessionGardee() {
                print("[erreur] verification-compte : \(cas) → personne connue, questionnaire fini : elle entre sans le serveur")
                onProfil(Self.profilDuTelephone)
                return true
            }
            print("[erreur] verification-compte : \(cas)")
            withAnimation(.easeOut(duration: 0.4)) {
                chargement = false
                panne = cas
            }
            return false
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
