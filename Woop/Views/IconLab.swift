import SwiftUI

// MARK: - Banc des trois icônes néon (`-iconLab`)

/// Les trois icônes — chocolat, bras, pêche — dessinées par le seul shader
/// `neonIcon`, sur une nuit noire pure.
///
/// Cinq scènes, choisies par `-icon <nom>` :
/// - `chocolat` / `bras` / `peche` : une icône seule, dans un carré de
///   `exportSide` points, centré — c'est la scène d'EXPORT (à ×3 elle donne
///   exactement 1020 px de côté, la planche livrée).
/// - `trio` : les trois de front, même taille, même lumière — le contrôle de
///   famille, celui qui dit si elles sont bien de la même main. (défaut)
/// - `petit` : la planche à 44 pt, taille réelle d'un onglet — le contrôle de
///   lisibilité, celui qui dit si le halo mange la forme.
///
/// `-iconFreeze` fige le temps (captures reproductibles au pixel).
struct IconLab: View {
    /// Le carré d'export : 340 pt × ×3 = 1020 px.
    private static let exportSide: CGFloat = 340

    private static let frozen = CommandLine.arguments.contains("-iconFreeze")
    private static let freezeTime: Float = 3.0

    /// La scène demandée, lue derrière `-icon`.
    private static let scene: String = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-icon"), i + 1 < a.count else { return "trio" }
        return a[i + 1]
    }()

    private static let ids: [String: Float] = ["chocolat": 0, "bras": 1, "peche": 2]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if Self.frozen {
                scene(t: Self.freezeTime)
            } else {
                TimelineView(.animation) { tl in
                    scene(t: Float(tl.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 4096)))
                }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    @ViewBuilder
    private func scene(t: Float) -> some View {
        switch Self.scene {
        case "trio":
            HStack(spacing: 18) {
                ForEach(["chocolat", "bras", "peche"], id: \.self) { name in
                    icon(name, side: 104, t: t)
                }
            }
        case "petit":
            VStack(spacing: 44) {
                HStack(spacing: 30) {
                    ForEach(["chocolat", "bras", "peche"], id: \.self) { name in
                        icon(name, side: 44, t: t)
                    }
                }
                HStack(spacing: 26) {
                    ForEach(["chocolat", "bras", "peche"], id: \.self) { name in
                        icon(name, side: 64, t: t)
                    }
                }
            }
        default:
            icon(Self.scene, side: Self.exportSide, t: t)
        }
    }

    /// Un carré, une icône. Le fond du carré est le noir de la page : la
    /// lumière du shader est la SEULE chose qui s'en détache.
    private func icon(_ name: String, side: CGFloat, t: Float) -> some View {
        Rectangle()
            .fill(.black)   // JAMAIS .clear : le `* color.a` final avale tout
            .frame(width: side, height: side)
            .colorEffect(ShaderLibrary.neonIcon(
                .float2(side, side),
                .float(t),
                .float(Self.ids[name] ?? 0)))
    }
}
