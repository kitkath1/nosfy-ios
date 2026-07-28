import SwiftUI

// MARK: - Palette

extension Color {
    /// Fond de l'app : quasiment noir, avec une dominante froide imperceptible.
    static let woopBase = Color(red: 0.016, green: 0.016, blue: 0.024)
    /// Noir un cran au-dessus, pour les feuilles modales.
    static let woopSheet = Color(red: 0.027, green: 0.027, blue: 0.035)

    /// Haut d'une surface métal (la lumière frappe ici).
    static let woopMetalHigh = Color(red: 0.098, green: 0.098, blue: 0.125)
    /// Corps de la surface.
    static let woopMetalMid = Color(red: 0.051, green: 0.051, blue: 0.071)
    /// Bas de la surface, presque fondu dans le fond.
    static let woopMetalLow = Color(red: 0.027, green: 0.027, blue: 0.039)

    /// Néon violet — l'accent.
    static let woopViolet = Color(red: 0.647, green: 0.545, blue: 1.0)
    /// Violet saturé, cœur du néon.
    static let woopVioletCore = Color(red: 0.522, green: 0.365, blue: 1.0)
    /// Violet profond, pour les halos.
    static let woopVioletDeep = Color(red: 0.361, green: 0.212, blue: 0.847)
    /// Récompense.
    static let woopGold = Color(red: 0.949, green: 0.749, blue: 0.325)

    /// Série musculation — validée CVD sur fond sombre.
    static let woopChartStrength = Color(red: 0.545, green: 0.361, blue: 0.965)
    /// Série cardio — validée CVD sur fond sombre.
    static let woopChartCardio = Color(red: 0.055, green: 0.588, blue: 0.671)

    static let inkPrimary = Color.white.opacity(0.96)
    static let inkSecondary = Color.white.opacity(0.55)
    static let inkMuted = Color.white.opacity(0.30)
}

// MARK: - Dégradés

enum WoopGradient {
    /// Matière métal : trois arrêts, décentrés, pour que la lumière semble venir d'en haut à gauche.
    static let metal = LinearGradient(
        stops: [
            .init(color: .woopMetalHigh, location: 0.0),
            .init(color: .woopMetalMid, location: 0.42),
            .init(color: .woopMetalLow, location: 1.0)
        ],
        startPoint: UnitPoint(x: 0.1, y: 0.0),
        endPoint: UnitPoint(x: 0.85, y: 1.0)
    )

    /// Reflet spéculaire posé sur le métal : une bande blanche très faible en haut.
    static let specular = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.075), location: 0.0),
            .init(color: .white.opacity(0.018), location: 0.22),
            .init(color: .clear, location: 0.55),
            .init(color: .white.opacity(0.012), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Biseau : arête blanche vive en BAS À GAUCHE — côté cœur de la
    /// nébuleuse (azimut ~225°, le token de lumière de la scène). Les cartes
    /// sont des objets DANS le ciel : leurs arêtes s'allument face à la seule
    /// source de l'écran, et s'éteignent vers le haut-droite.
    static let bevel = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.42), location: 0.0),
            .init(color: .white.opacity(0.10), location: 0.18),
            .init(color: .white.opacity(0.0), location: 0.52),
            .init(color: .white.opacity(0.055), location: 1.0)
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    /// Biseau accentué, pour la carte active uniquement. L'arête reste blanche ;
    /// le violet n'apparaît qu'en second temps, sinon l'effet premium se dissout.
    static let bevelNeon = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.58), location: 0.0),
            .init(color: .woopViolet.opacity(0.30), location: 0.16),
            .init(color: .white.opacity(0.03), location: 0.50),
            .init(color: .woopVioletCore.opacity(0.10), location: 1.0)
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    /// Trait des dessins d'exercice : blanc en haut, violet, puis une pointe de
    /// rouge en bas. Fin et continu — c'est une ligne, pas une masse.
    static let figureStroke = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.90), location: 0.0),
            .init(color: .woopViolet.opacity(0.95), location: 0.34),
            .init(color: .woopVioletCore.opacity(0.85), location: 0.62),
            .init(color: Color(red: 0.87, green: 0.31, blue: 0.42).opacity(0.75), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Même dégradé, plus dense, pour le logo.
    static let logoStroke = LinearGradient(
        stops: [
            .init(color: .white, location: 0.0),
            .init(color: .woopViolet, location: 0.30),
            .init(color: .woopVioletCore, location: 0.62),
            .init(color: Color(red: 0.90, green: 0.28, blue: 0.40), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Néon violet → blanc, pour les boutons et les valeurs mises en avant.
    static let neon = LinearGradient(
        stops: [
            .init(color: .white, location: 0.0),
            .init(color: .woopViolet, location: 0.38),
            .init(color: .woopVioletCore, location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let neonFill = LinearGradient(
        colors: [.woopVioletCore, .woopVioletDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Surface métal

/// La surface de base de l'app : dégradé sombre + reflet spéculaire + biseau.
/// Trois couches, c'est ce qui distingue « une carte grise » d'une pièce métallique.
struct MetalSurface: ViewModifier {
    var cornerRadius: CGFloat = 22
    var neon: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                ZStack {
                    shape.fill(WoopGradient.metal)
                    shape.fill(WoopGradient.specular)
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.75), radius: 22, y: 14)
                .shadow(color: neon ? Color.woopVioletCore.opacity(0.14) : .clear,
                        radius: 24, y: 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(neon ? WoopGradient.bevelNeon : WoopGradient.bevel,
                                  lineWidth: 1)
            }
    }
}

extension View {
    func metalSurface(cornerRadius: CGFloat = 22, neon: Bool = false) -> some View {
        modifier(MetalSurface(cornerRadius: cornerRadius, neon: neon))
    }

    /// Lueur néon posée derrière un élément clair.
    func neonGlow(_ color: Color = .woopVioletCore, radius: CGFloat = 12,
                  opacity: Double = 0.75) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
            .shadow(color: color.opacity(opacity * 0.5), radius: radius * 2.2)
    }
}

struct WoopCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var padding: CGFloat = 20
    var neon: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .metalSurface(cornerRadius: cornerRadius, neon: neon)
    }
}

// MARK: - Contour balayé

/// Balayage lumineux qui parcourt le contour une fois à l'apparition, puis se fige
/// sur le biseau néon. Réservé à la carte principale.
struct SweepBorder: View {
    var cornerRadius: CGFloat = 22
    var lineWidth: CGFloat = 1
    @State private var angle: Double = -100
    @State private var settled = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                settled
                    ? AnyShapeStyle(WoopGradient.bevelNeon)
                    : AnyShapeStyle(
                        AngularGradient(
                            stops: [
                                .init(color: .white.opacity(0.0), location: 0.0),
                                .init(color: .white.opacity(0.95), location: 0.07),
                                .init(color: .woopVioletCore.opacity(0.85), location: 0.15),
                                .init(color: .white.opacity(0.0), location: 0.32),
                                .init(color: .white.opacity(0.0), location: 1.0)
                            ],
                            center: .center,
                            angle: .degrees(angle)
                        )
                    ),
                lineWidth: lineWidth
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2)) { angle = 260 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.45)) { settled = true }
                }
            }
    }
}

// MARK: - Boutons

struct WoopPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
                ZStack {
                    shape.fill(WoopGradient.neonFill)
                    shape.fill(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .clear],
                            startPoint: .top, endPoint: .center
                        )
                    )
                }
                .compositingGroup()
                // Halo contenu : l'ancien rayon 18 débordait sur le ciel et
                // teintait la brume grise en mauve (R−B mesuré à −79) — le
                // ciel reste N&B, le violet redevient l'unique événement coloré.
                .shadow(color: Color.woopVioletCore.opacity(0.32), radius: 11, y: 5)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.65), location: 0.0),
                                .init(color: .white.opacity(0.10), location: 0.4),
                                .init(color: .white.opacity(0.0), location: 1.0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct WoopSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(Color.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .metalSurface(cornerRadius: 13)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Titre de section

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionLabel: String = "Tout voir"

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            if let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionLabel)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.woopViolet)
                }
            }
        }
    }
}
