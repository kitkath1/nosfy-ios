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
    /// LA CLARTÉ DU FOND SOUS LE CHIP [0,1] — 0 : la nuit (verre fumé
    /// noir, glyphe blanc) ; 1 : une lumière (verre TRANSPARENT, glyphe à
    /// l'ENCRE SOMBRE). Sur l'aurora d'une carte dépliée, un verre teinté
    /// noir fait une pastille sale — et un glyphe blanc sur de la crème
    /// n'existe pas : les deux doivent basculer ENSEMBLE, c'est la loi
    /// déjà écrite pour le nom du profil.
    var clarte: Double = 0
    var action: () -> Void

    /// L'encre sombre de la maison — celle qui s'écrit sur la lumière.
    static let encreClaire = Color(red: 0.18, green: 0.10, blue: 0.04)

    var body: some View {
        let c = min(max(clarte, 0), 1)
        let forme = RoundedRectangle(cornerRadius: 15, style: .continuous)
        Button(action: action) {
            Image(systemName: symbole)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.inkPrimary.opacity(1 - c))
                .overlay {
                    Image(systemName: symbole)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Self.encreClaire)
                        .opacity(c)
                }
                .frame(width: 44, height: 44)
                .background {
                    // DEUX VERRES EN FONDU, et c'est la clé : baisser la
                    // teinte d'un verre `.regular` ne le rend PAS
                    // transparent — le matériau dépoli garde sa propre
                    // matière et devient un pavé GRIS SALE sur la lumière
                    // (payé le 15-08 : « toujours cassé dans le haut »).
                    // Le verre vraiment transparent, c'est `.clear` —
                    // celui du couvercle de la bannière profil. On croise
                    // les deux au lieu d'en éteindre un.
                    ZStack {
                        Color.clear
                            .glassEffect(.regular
                                .tint(Color.black.opacity(0.5))
                                .interactive(), in: forme)
                            .opacity(1 - c)
                        // LE VERRE DE JOUR. Deux fausses pistes payées le
                        // 15-08 : baisser la teinte d'un verre `.regular`
                        // (il garde sa matière et devient un pavé gris),
                        // puis passer en `.clear` et forcer le mode clair
                        // (le matériau reste sombre au simulateur). Ce
                        // qui marche : garder le MÊME verre et lui donner
                        // une teinte BLANCHE — il s'éclaircit au lieu de
                        // s'assombrir, et se pose sur la lumière comme un
                        // galet de verre dépoli clair.
                        Color.clear
                            .glassEffect(.regular
                                .tint(Color.white.opacity(0.42))
                                .interactive(), in: forme)
                            .opacity(c)
                    }
                }
                .overlay(forme.strokeBorder(
                    Color.white.opacity(0.08 * (1 - c)), lineWidth: 1))
                // Sur la lumière, le liseré blanc n'existe plus : c'est
                // une arête SOMBRE, très fine, qui détache le verre.
                .overlay(forme.strokeBorder(
                    Color.black.opacity(0.10 * c), lineWidth: 1))
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
    /// Transmise au chevron : voir `ChipVerre.clarte`.
    var clarte: Double = 0
    @ViewBuilder var droite: () -> Droite

    var body: some View {
        HStack {
            ChipVerre(symbole: "chevron.left", label: "Retour",
                      clarte: clarte, action: retour)
            Spacer()
            droite()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}
