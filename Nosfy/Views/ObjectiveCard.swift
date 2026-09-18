import SwiftUI
import UIKit

// MARK: - État pressé (Button → carte)

/// Le liseré de la carte s'allume au toucher, mais c'est le Button de la home
/// qui SAIT quand le doigt est posé : son style republie `isPressed` dans
/// l'environnement, la carte le lit. Aucune gesture parallèle — le tap de
/// navigation reste intact.
private struct ObjectiveCardPressedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var objectiveCardPressed: Bool {
        get { self[ObjectiveCardPressedKey.self] }
        set { self[ObjectiveCardPressedKey.self] = newValue }
    }
}

/// À poser sur le Button qui enveloppe ObjectiveGlassCard. Ajoute le retour
/// haptique doux du toucher — la carte « vibre » sous le doigt.
struct ObjectiveCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.objectiveCardPressed, configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
                }
            }
    }
}

// MARK: - La pierre — une passe, tout le bijou

/// Toute la matière de la carte vit dans `objectiveJewel`
/// (Woop/ObjectiveJewel.metal) : le métal noir et ses griffes révélées par
/// une lumière rasante, la nébuleuse et ses poussières d'étoiles, le liseré
/// hairline à lumière inégale et ses éclats de taille. Ici, seulement le
/// cadrage (marge de débordement pour les halos) et la rampe du toucher —
/// un paramètre de shader ne s'interpole pas tout seul : on horodate le
/// basculement et le TimelineView fait la pente.
private struct JewelSurface: View {
    var cornerRadius: CGFloat
    var lit: Bool
    var warm: Bool
    var paused: Bool

    /// Marge de débordement : halos et éclats vivent DEHORS, en alpha.
    private static let pad: CGFloat = 18

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
                    .colorEffect(Self.dithered(ShaderLibrary.objectiveJewel(
                        .float2(w, h), .float(t),
                        .float(Float(Self.pad)), .float(Float(cornerRadius)),
                        .float(l), .float(warm ? 1 : 0))))
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

// MARK: - Carte Objectif — verre noir liquide (ancienne matière)

/// La lumière sur le verre : voir `objectiveCrest` dans DemonSky.metal.
/// Une seule passe, en DEMI-résolution (tout y est diffus), composée en
/// `plusLighter` — de la lumière ajoutée au verre, jamais un calque qui le
/// grise. Même horloge globale que le ciel (mod 900 s).
private struct GlassLight: View {
    var paused: Bool

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
                let t = Float(timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))

                Rectangle()
                    .fill(.black)
                    .frame(width: w / 2, height: h / 2)
                    .colorEffect(Self.dithered(ShaderLibrary.objectiveCrest(
                        .float2(w / 2, h / 2), .float(t),
                        .image(NebulaNoise.image))))
                    .scaleEffect(2, anchor: .topLeading)
            }
        }
        .allowsHitTesting(false)
    }

    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }
}

// MARK: - L'arête usinée

/// L'arête de la carte est une arête de MÉTAL usiné, pas un contour : un
/// hairline de 0,8 pt porté par un dégradé ANGULAIRE à pics spéculaires —
/// un arc blanc froid centré sur le coin haut-gauche (là où la lumière
/// frappe), qui court sur le bord haut et s'éteint ; un écho à peine
/// visible au coin opposé ; du quasi-noir entre les deux. Une lueur serrée
/// n'existe que sous l'arc.
///
/// AU TOUCHER, l'arc s'étend et tout s'allume davantage, avec la pulsation
/// lente (~1,9 s) — une lampe qui respire, pas un stroboscope.
private struct GlassBorder: View {
    var cornerRadius: CGFloat
    /// Objectif atteint : l'arc se réchauffe vers l'or-récompense — la seule
    /// célébration, discrète, dans la famille chromatique documentée.
    var achieved: Bool = false
    /// Doigt posé sur la carte : la lumière s'allume.
    var lit: Bool = false

    /// Blanc froid acier ; or-récompense si l'objectif est atteint.
    private var arc: Color {
        achieved ? Color(red: 1.0, green: 0.95, blue: 0.82)
                 : Color(red: 0.96, green: 0.985, blue: 1.0)
    }

    /// Le dégradé angulaire de l'arête. Angle 0 = 3 h, sens horaire :
    /// coin haut-gauche ≈ 0.625 de tour, coin bas-droit ≈ 0.125.
    private func edge(rest: Bool) -> AngularGradient {
        let f = rest ? 1.0 : 2.3          // le toucher lève tout le plancher
        return AngularGradient(
            stops: [
                .init(color: .white.opacity(0.09 * f), location: 0.0),
                .init(color: .white.opacity(0.16 * f), location: 0.115),  // écho bas-droit
                .init(color: .white.opacity(0.08 * f), location: 0.19),
                .init(color: .white.opacity(0.045 * f), location: 0.40),
                .init(color: .white.opacity(0.07 * f), location: 0.545),
                .init(color: arc.opacity(rest ? 0.55 : 0.85), location: 0.595),
                .init(color: arc, location: 0.625),                       // coin haut-gauche
                .init(color: arc.opacity(rest ? 0.50 : 0.80), location: 0.71),
                .init(color: .white.opacity(0.18 * f), location: 0.82),
                .init(color: .white.opacity(0.07 * f), location: 0.93),
                .init(color: .white.opacity(0.09 * f), location: 1.0),
            ],
            center: .center, angle: .degrees(0))
    }

    /// La lueur : n'existe que sous l'arc — transparente partout ailleurs.
    private func arcGlow(_ opacity: Double) -> AngularGradient {
        AngularGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.52),
                .init(color: arc.opacity(opacity), location: 0.625),
                .init(color: arc.opacity(opacity * 0.35), location: 0.74),
                .init(color: .clear, location: 0.86),
                .init(color: .clear, location: 1.0),
            ],
            center: .center, angle: .degrees(0))
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            // Au repos : le hairline usiné et sa lueur d'arc, statiques.
            shape.stroke(arcGlow(0.30), lineWidth: 2.2)
                .blur(radius: 2.5)
            shape.stroke(edge(rest: true), lineWidth: 0.8)

            // Au toucher : tout s'allume et respire. La pulsation ne tourne
            // que doigt posé ; allumage vif (0,22 s), extinction traînante
            // (0,9 s) — une braise, pas un interrupteur.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !lit)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let pulse = 0.80 + 0.20 * sin(t * 2 * .pi / 1.9)
                ZStack {
                    shape.stroke(arcGlow(0.35), lineWidth: 6)
                        .blur(radius: 10)
                    shape.stroke(arcGlow(0.55), lineWidth: 2.4)
                        .blur(radius: 2.5)
                    shape.stroke(edge(rest: false), lineWidth: 1.0)
                }
                .opacity(pulse)
            }
            .opacity(lit ? 1 : 0)
            .animation(.easeOut(duration: lit ? 0.22 : 0.9), value: lit)
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

// MARK: - Le grand chiffre à reflet

/// Le compteur de la carte : encre de base, et toutes les ~7 s un glint
/// argenté le traverse en ~1,5 s — du métal poli qui accroche la lumière,
/// pas un gadget qui clignote. Coupé par Reduce Motion.
struct ShimmeringNumber: View {
    let value: Int
    var size: CGFloat = 36

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var text: Text {
        Text("\(value)")
            .font(.inter(size, .semibold))
    }

    var body: some View {
        text
            // Dégradé resserré pour un corps géant : la course verticale d'un
            // chiffre de 34 pt ferait finir silverText en gris moyen sur du
            // métal gris — le chiffre garde sa densité jusqu'à la base.
            .foregroundStyle(
                LinearGradient(colors: [.white, .white.opacity(0.78)],
                               startPoint: .top, endPoint: .bottom)
            )
            .contentTransition(.numericText())
            .overlay {
                if !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        // Fenêtre de balayage : le glint ne vit que 22 % de
                        // la période — le reste du temps, rien ne bouge.
                        let u = timeline.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 7.0) / 7.0
                        let p = u / 0.22
                        if p < 1 {
                            LinearGradient(
                                stops: [.init(color: .clear, location: 0),
                                        .init(color: .clear, location: max(p - 0.18, 0)),
                                        .init(color: .white.opacity(0.55), location: p),
                                        .init(color: .clear, location: min(p + 0.18, 1)),
                                        .init(color: .clear, location: 1)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            .mask(text)
                        }
                    }
                }
            }
    }
}

// MARK: - La carte

/// La carte « Objectif hebdomadaire » : un rectangle arrondi de verre noir
/// liquide — noir quasi absolu, animé en sourdine (nappes spéculaires à
/// 1-4 %, un cordon de nébuleuse diagonal discret, des étoiles fines),
/// cerclé d'un fil de lumière qui s'éteint vers le bas. Tout est murmure :
/// le spectaculaire (mesa découpée, ruban lumineux) a été essayé puis
/// abandonné — il écrasait la hiérarchie de la home.
///
/// Réservée à l'objectif hebdomadaire : une app dont toutes les surfaces
/// portent un ciel n'a plus de hiérarchie.
struct ObjectiveGlassCard<Content: View>: View {
    /// Objectif hebdomadaire atteint : le liseré se réchauffe.
    var achieved: Bool = false
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.objectiveCardPressed) private var pressed
    @State private var onScreen = true

    private var paused: Bool { !onScreen || reduceMotion }
    private let cornerRadius: CGFloat = 30

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.init(top: 20, leading: 22, bottom: 24, trailing: 22))
            // Toute la matière en UNE passe : métal noir griffé, nébuleuse,
            // liseré hairline à éclats. Le Liquid Glass natif a été essayé et
            // abandonné ici — teinté vers le noir il grisait la pierre, et sa
            // réfraction contredisait la lecture « bijou serti ».
            .background { JewelSurface(cornerRadius: cornerRadius, lit: pressed,
                                       warm: achieved, paused: paused) }
            .contentShape(shape)
            // Hors écran, le verre s'endort — même dégradation sans risque
            // que MistyDiamondSurface (hors ScrollView la valeur reste à true).
            .onScrollVisibilityChange(threshold: 0.02) { visible in
                onScreen = visible
            }
    }
}
