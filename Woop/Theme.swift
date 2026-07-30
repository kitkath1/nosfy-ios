import SwiftUI

// MARK: - Typographie

/// Inter, la linéale de l'app : néo-grotesque neutre dessinée pour l'écran —
/// le registre « minimal premium » qui remplace le SF Rounded d'origine.
/// Quatre graisses statiques (Woop/Fonts), enregistrées au lancement.
extension Font {
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .heavy, .black: return .custom("Inter-Bold", size: size)
        case .semibold: return .custom("Inter-SemiBold", size: size)
        case .medium: return .custom("Inter-Medium", size: size)
        default: return .custom("Inter-Regular", size: size)
        }
    }
}

// MARK: - Palette

extension Color {
    /// Fond de l'app : quasiment noir, avec une dominante froide imperceptible.
    static let woopBase = Color(red: 0.016, green: 0.016, blue: 0.024)
    /// Noir un cran au-dessus, pour les feuilles modales.
    static let woopSheet = Color(red: 0.027, green: 0.027, blue: 0.035)

    /// Le noir des surfaces de la famille diamant : NOIR PUR. Les photos
    /// d'exercice ont un fond noir absolu — toute valeur au-dessus de zéro
    /// dessinerait le contour de l'image dans la carte. La carte n'est plus
    /// une plaque, c'est un vide serti d'un liseré.
    static let woopCard = Color.black

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

    /// LE liseré de la famille diamant — exactement celui du bouton primaire :
    /// vif en haut, éteint avant le bas. Il ne suit pas l'azimut 225° du ciel
    /// (le `bevel` ci-dessus) : les composants diamant sont éclairés par leur
    /// PROPRE lumière, celle du bijou, pas par celle de la scène.
    static let diamondRim = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.65), location: 0.0),
            .init(color: .white.opacity(0.10), location: 0.40),
            .init(color: .white.opacity(0.0), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Le même, relevé, pour la surface mise en avant. Le violet reste un
    /// murmure au milieu du parcours : au-delà, le registre bijou se dissout.
    static let diamondRimNeon = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.88), location: 0.0),
            .init(color: .woopViolet.opacity(0.24), location: 0.42),
            .init(color: .white.opacity(0.03), location: 1.0)
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

    /// Encre argent des titres : blanc qui s'éteint doucement vers le bas.
    /// C'est un métal, pas un effet — le dégradé reste sous le seuil où l'œil
    /// lirait « texte grisé ».
    static let silverText = LinearGradient(
        stops: [
            .init(color: .white, location: 0.0),
            .init(color: .white.opacity(0.80), location: 0.62),
            .init(color: .white.opacity(0.68), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Le grand titre d'une fiche : blanc franc à l'attaque, extinction marquée
    /// en fin de course — le mot se perd dans le noir de la page au lieu de
    /// s'arrêter net. La diagonale, et non l'horizontale : un dégradé purement
    /// horizontal rallume le début de CHAQUE ligne, et un titre sur deux lignes
    /// se met alors à clignoter. On s'arrête à 0,25 — plus bas, les dernières
    /// lettres cessent d'être lisibles, et un titre illisible n'est plus un titre.
    static let titleFade = LinearGradient(
        stops: [
            .init(color: .white, location: 0.0),
            .init(color: .white.opacity(0.90), location: 0.32),
            .init(color: .white.opacity(0.60), location: 0.68),
            .init(color: .white.opacity(0.25), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Encre des facettes d'un contrôle — les signes + et −. C'est le parcours
    /// du liseré diamant appliqué à un glyphe : vif en haut, éteint en bas. Le
    /// violet a quitté les steppers ; dans cette page l'accent est une lumière,
    /// pas une couleur.
    static let controlInk = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.95), location: 0.0),
            .init(color: .white.opacity(0.52), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
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

// MARK: - Surface diamant

/// LA surface de l'app, membre de la famille diamant : un noir pur serti d'un
/// liseré, avec les éclats-bijou du bouton primaire semés sur le contour.
///
/// Elle remplace l'ancienne « surface métal » (dégradé gris-vert + reflet
/// spéculaire). La raison est photographique : les images d'exercice ont un
/// fond NOIR ABSOLU, et la moindre plaque grise sous elles redessinait le
/// rectangle de la photo dans la carte. En noir pur, l'image n'a plus de
/// bord — seuls le corps et le muscle en lumière flottent.
///
/// L'ombre portée a disparu avec le gris : sur du noir sur du noir, un flou
/// de rayon 22 ne dessine rien. C'était le poste le plus cher de la carte.
struct DiamondSurface: ViewModifier {
    var cornerRadius: CGFloat = 22
    var neon: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background { shape.fill(Color.woopCard) }
            .overlay {
                shape.strokeBorder(neon ? WoopGradient.diamondRimNeon
                                        : WoopGradient.diamondRim,
                                   lineWidth: 1)
            }
            // Murmure : à pleine puissance (1.0) les éclats appartiennent au
            // CTA. Une page entière de cartes qui scintillent au même volume
            // que le bouton d'action n'a plus de hiérarchie.
            .diamondGlints(cornerRadius: cornerRadius, strength: neon ? 0.75 : 0.5)
    }
}

extension View {
    func diamondSurface(cornerRadius: CGFloat = 22, neon: Bool = false) -> some View {
        modifier(DiamondSurface(cornerRadius: cornerRadius, neon: neon))
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
            .diamondSurface(cornerRadius: cornerRadius, neon: neon)
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
            // Capitales espacées : le registre « gravé » de la référence — la
            // taille descend d'un cran, l'interlettrage porte la présence.
            .font(.inter(13.5, .semibold))
            .textCase(.uppercase)
            .tracking(2.4)
            .foregroundStyle(.white.opacity(0.95))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
                ZStack {
                    // Noir velours : dense en bas, à peine soulevé en haut —
                    // aucune couleur, la matière absorbe la lumière.
                    shape.fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.165, green: 0.165, blue: 0.195), location: 0.0),
                                .init(color: Color(red: 0.088, green: 0.088, blue: 0.108), location: 0.52),
                                .init(color: Color(red: 0.038, green: 0.038, blue: 0.052), location: 1.0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    // Reflet d'étoffe : une lueur douce centrée au-dessus du
                    // bouton, qui meurt vite — c'est elle qui fait « velours »
                    // plutôt que « plastique ».
                    shape.fill(
                        RadialGradient(
                            colors: [.white.opacity(0.14), .clear],
                            center: UnitPoint(x: 0.5, y: -0.55),
                            startRadius: 0, endRadius: 240
                        )
                    )
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.70), radius: 18, y: 10)
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
            // Le registre bijou du CONNEXION : des facettes qui flashent sur
            // le liseré — le CTA est une pièce taillée, pas un rectangle.
            .diamondGlints(cornerRadius: 15)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct WoopSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(14.5, .medium))
            .foregroundStyle(Color.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .diamondSurface(cornerRadius: 13)
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
                .font(.inter(19, .semibold))
                .foregroundStyle(WoopGradient.silverText)
            Spacer()
            if let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionLabel)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    // Monochrome : l'action secondaire est une encre discrète,
                    // pas un accent coloré — le violet est réservé au néon.
                    .font(.inter(14))
                    .foregroundStyle(Color.inkSecondary)
                }
            }
        }
    }
}
