import SwiftUI

// MARK: - Banc d'essai de la carte Objectif (`-cardLab`)

/// Page noire nue : la carte « Objectif hebdomadaire » seule, au repos et
/// sous le doigt, pour régler la pierre au pixel — sans le ciel de la home
/// qui masque ce que le shader fait vraiment.
///
/// Le contenu est la COPIE EXACTE de celui de la home (mêmes corps, même
/// tracking, mêmes marges) : ce qu'on juge ici est ce qu'on verra là-bas.
struct ObjectiveCardLab: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 34) {
                card(pressed: false, achieved: false)
                // La copie « doigt posé », figée : régler l'éveil du liseré
                // sans devoir garder le doigt sur l'écran.
                card(pressed: true, achieved: false)
            }
            .padding(.horizontal, 20)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private func card(pressed: Bool, achieved: Bool) -> some View {
        ObjectiveGlassCard(achieved: achieved) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Objectif hebdomadaire")
                    .font(.inter(12, .medium))
                    .textCase(.uppercase)
                    .tracking(2.2)
                    .foregroundStyle(.white.opacity(0.58))

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    ShimmeringNumber(value: 1, size: 34)
                    Text("/ 5 entraînements")
                        .font(.inter(13))
                        .foregroundStyle(Color.inkSecondary)
                }
                .padding(.top, 9)

                TrophyRow(completed: 1, total: 5, slotSize: 44,
                          justified: true, luminous: true, celebrates: false)
                    .padding(.top, 22)
            }
        }
        .environment(\.objectiveCardPressed, pressed)
    }
}
