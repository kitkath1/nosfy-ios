import SwiftUI

// MARK: - LE chip de verre de la maison

/// LE composant unique des boutons d'en-tête (verdict du 14-08 : « le
/// chevron doit être le même composant sur toutes les pages et
/// absolument au même endroit »). La recette est celle de la fiche
/// d'exercice — le verre fumé FONCÉ posé sur la braise : 44×44, rayon 15
/// continu, `glassEffect` teinté noir 0,5, liseré blanc 0,08.
struct ChipVerre: View {
    var symbole: String
    var label: String
    var action: () -> Void

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: 15, style: .continuous)
        Button(action: action) {
            Image(systemName: symbole)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: 44, height: 44)
                .background {
                    Color.clear
                        .glassEffect(.regular.tint(Color.black.opacity(0.5))
                            .interactive(), in: forme)
                }
                .overlay(forme.strokeBorder(Color.white.opacity(0.08),
                                            lineWidth: 1))
                .contentShape(forme)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// La rangée d'en-tête canonique — chevron à gauche, l'action de droite
/// en face, aux cotes de la fiche d'exercice (20 / 4 / 8) : la position
/// du chevron ne bouge JAMAIS d'une page à l'autre.
struct RangeeChips<Droite: View>: View {
    var retour: () -> Void
    @ViewBuilder var droite: () -> Droite

    var body: some View {
        HStack {
            ChipVerre(symbole: "chevron.left", label: "Retour",
                      action: retour)
            Spacer()
            droite()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}
