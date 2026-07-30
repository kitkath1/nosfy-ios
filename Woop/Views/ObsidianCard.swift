import SwiftUI

// MARK: - Carte « obsidienne » — le doublon de travail

/// DOUBLON de `ObjectiveGlassCard` (carte Objectif bijou). L'originale reste
/// telle quelle au design system — elle a coûté trop de travail pour servir de
/// brouillon. Ici on cherche une AUTRE matière : verre fumé noir poli, presque
/// opaque, éclairé par une source chaude posée hors du cadre au coin
/// haut-gauche. Toute la matière vit dans `obsidianSurface`
/// (Woop/ObsidianCard.metal) ; ici, seulement le cadrage (marge de
/// débordement pour le bloom et l'ombre portée) et la rampe du toucher.
private struct ObsidianSurface: View {
    var cornerRadius: CGFloat
    var lit: Bool
    var paused: Bool

    /// Marge de débordement : le bloom chaud et l'ombre portée vivent DEHORS,
    /// en alpha. Large, parce que la source est franchement hors carte.
    static let pad: CGFloat = 90

    @State private var animStart: Date = .distantPast
    @State private var wasLit = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width + Self.pad * 2
            let h = geo.size.height + Self.pad * 2

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                let raw = min(max(tl.date.timeIntervalSince(animStart) / 0.35, 0), 1)
                let eased = Float(raw * raw * (3 - 2 * raw))
                let l = wasLit ? eased : 1 - eased

                Rectangle()
                    .fill(.white)
                    .frame(width: w, height: h)
                    .colorEffect(Self.dithered(ShaderLibrary.obsidianSurface(
                        .float2(w, h), .float(t),
                        .float(Float(Self.pad)), .float(Float(cornerRadius)),
                        .float(l))))
            }
            .offset(x: -Self.pad, y: -Self.pad)
        }
        .allowsHitTesting(false)
        .onAppear { wasLit = lit }
        .onChange(of: lit) { _, now in
            animStart = .now
            wasLit = now
        }
    }

    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }
}

/// La carte obsidienne. Même contrat que `ObjectiveGlassCard` (contenu injecté,
/// état pressé lu dans l'environnement) : les deux sont interchangeables sur la
/// home, on peut donc les comparer sans rien réécrire.
struct ObsidianGlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.objectiveCardPressed) private var pressed
    @State private var onScreen = true

    private var paused: Bool { !onScreen || reduceMotion }
    /// 27 pt — MESURÉ sur la référence (ajustement de cercle sur la crête
    /// spéculaire des trois coins non cramés : 25,2 / 25,5 / 24,8 pt, méthode
    /// diagonale 27,4 pt). Le brief annonçait 36-42 pt : la référence dit non,
    /// et c'est elle qui gagne. À 38 pt le coin mordait si loin que le bord
    /// haut n'existait plus dans les 25 premiers points.
    private let cornerRadius: CGFloat = 27

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.init(top: 20, leading: 22, bottom: 24, trailing: 22))
            .background { ObsidianSurface(cornerRadius: cornerRadius, lit: pressed,
                                          paused: paused) }
            .contentShape(shape)
            .onScrollVisibilityChange(threshold: 0.02) { visible in
                onScreen = visible
            }
    }
}
