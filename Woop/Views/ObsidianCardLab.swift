import SwiftUI

// MARK: - Banc d'essai de la carte obsidienne (`-obsidianLab`)

/// Page noire nue : le DOUBLON de la carte Objectif, au repos et sous le doigt.
/// Le contenu est la copie exacte de celui de la home — ce qu'on juge ici est
/// ce qu'on verra là-bas.
///
/// La page est un NOIR PUR : mesuré sur la référence HD (back_hero.png), le
/// fond vaut #000000 partout, jusqu'au ras de la carte. C'est le bloom qui
/// détache la pierre, pas une illumination de page — un fond gris trahirait
/// immédiatement le montage.
struct ObsidianCardLab: View {
    var body: some View {
        ZStack {
            pageBackground
            VStack(spacing: 40) {
                card(pressed: false)
                // La copie « doigt posé », figée.
                card(pressed: true)
            }
            .padding(.horizontal, 20)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private var pageBackground: some View {
        Color.black.ignoresSafeArea()
    }

    private func card(pressed: Bool) -> some View {
        ObsidianGlassCard {
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
