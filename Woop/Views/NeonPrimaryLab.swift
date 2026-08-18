import SwiftUI

// MARK: - Banc d'essai du bouton primary néon (`-neonLab`)

/// PREMIÈRE ÉTAPE, EN NOIR SIMPLE : on ne juge ici QUE le relief. Pas de néon,
/// pas d'allumage — la question posée est « est-ce la même matière que la pièce
/// de référence, et le texte est-il vraiment incrusté ? ». Le néon viendra
/// remplir le sillon une fois le creux validé.
///
/// Les quatre lignes font varier la taille et la graisse, parce que c'est LE
/// point dur : sur la référence, le mur de la gravure fait un tiers de la
/// largeur du trait. À 15 pt, une hampe d'Inter fait 5,7 px à 3x et le mur ne
/// peut faire qu'un pixel — la gravure se lit à peine. Plus gros et plus gras,
/// elle se lit vraiment. C'est un arbitrage de goût, pas de technique.
struct NeonPrimaryLab: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 26) {
                labelled("15 pt semibold — la taille actuelle") {
                    NeonPrimaryButton(title: "Lancer Entraînement",
                                      fontSize: 15, weight: .semibold) {}
                }
                labelled("17 pt bold") {
                    NeonPrimaryButton(title: "Lancer Entraînement",
                                      fontSize: 17, weight: .bold) {}
                }
                labelled("19 pt heavy") {
                    NeonPrimaryButton(title: "Lancer Entraînement",
                                      fontSize: 19, weight: .heavy) {}
                }
                labelled("19 pt heavy, capitales espacées") {
                    NeonPrimaryButton(title: "LANCER ENTRAÎNEMENT",
                                      fontSize: 15, weight: .heavy,
                                      tracking: 2.2) {}
                }
            }
            .padding(.horizontal, 26)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    @ViewBuilder
    private func labelled<C: View>(_ text: String,
                                   @ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 7) {
            Text(text)
                .font(.inter(9, .medium))
                .textCase(.uppercase)
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.24))
            content()
        }
    }
}
