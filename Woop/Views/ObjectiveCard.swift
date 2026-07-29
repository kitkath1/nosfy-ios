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

// MARK: - Carte Objectif — verre noir liquide

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

// MARK: - Liseré de lumière

/// Le fil qui cerne le verre RÉPOND à la source haut-gauche : brillant et
/// blanc au coin où la lumière frappe l'arête, gris neutre sur le haut,
/// presque éteint en bas-droit — un dégradé de nuances de blanc, jamais
/// uniforme. Une lueur douce n'existe qu'au voisinage du coin éclairé.
/// AU TOUCHER, tout s'allume davantage et VIBRE lentement (~1,9 s) — une
/// lampe qui respire, pas un stroboscope.
private struct GlassBorder: View {
    var cornerRadius: CGFloat
    /// Objectif atteint : le fil se réchauffe vers l'or-récompense — la seule
    /// célébration, discrète, dans la famille chromatique documentée.
    var achieved: Bool = false
    /// Doigt posé sur la carte : la lumière s'allume.
    var lit: Bool = false

    private var glow: Color {
        achieved ? Color(red: 1.0, green: 0.93, blue: 0.75) : .white
    }

    /// L'arête au repos : le dégradé suit la lumière — coin haut-gauche
    /// brillant, bas-droit presque mort.
    private var restLine: LinearGradient {
        LinearGradient(
            stops: [.init(color: (achieved ? Color(red: 1.0, green: 0.95, blue: 0.82) : .white)
                              .opacity(0.85), location: 0.0),
                    .init(color: .white.opacity(0.30), location: 0.32),
                    .init(color: .white.opacity(0.12), location: 0.68),
                    .init(color: .white.opacity(0.05), location: 1.0)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var litLine: LinearGradient {
        LinearGradient(
            stops: [.init(color: achieved ? Color(red: 1.0, green: 0.95, blue: 0.82) : .white,
                          location: 0.0),
                    .init(color: .white.opacity(0.55), location: 0.40),
                    .init(color: .white.opacity(0.26), location: 1.0)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// La lueur du coin : n'existe qu'au voisinage de la source.
    private var cornerMask: RadialGradient {
        RadialGradient(
            stops: [.init(color: .white, location: 0.0),
                    .init(color: .white.opacity(0.35), location: 0.55),
                    .init(color: .clear, location: 1.0)],
            center: .topLeading, startRadius: 0, endRadius: 320)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            // Le fil au repos, toujours là : l'arête répond à la lumière.
            shape.stroke(restLine, lineWidth: 1)

            // La lueur du coin éclairé — douce, statique, jamais un néon.
            shape.stroke(glow.opacity(0.35), lineWidth: 2.5)
                .blur(radius: 3)
                .mask(cornerMask)

            // La lumière du toucher. La pulsation ne tourne que doigt posé
            // (TimelineView en pause sinon) ; l'allumage est vif (0,22 s),
            // l'extinction traîne (0,9 s) — une braise, pas un interrupteur.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !lit)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let pulse = 0.80 + 0.20 * sin(t * 2 * .pi / 1.9)
                ZStack {
                    shape.stroke(glow.opacity(achieved ? 0.26 : 0.20), lineWidth: 7)
                        .blur(radius: 14)
                    shape.stroke(glow.opacity(0.50), lineWidth: 2.2)
                        .blur(radius: 2.5)
                    shape.stroke(litLine, lineWidth: 1.1)
                }
                .opacity(pulse)
            }
            .mask {
                LinearGradient(stops: [.init(color: .white, location: 0.0),
                                       .init(color: .white.opacity(0.60), location: 1.0)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .padding(-48)      // couvre le débord du flou
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
            .font(.system(size: size, weight: .bold, design: .rounded))
    }

    var body: some View {
        text
            .foregroundStyle(Color.inkPrimary)
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
            .background {
                ZStack {
                    // Liquid Glass NATIF, teinté vers le noir : du verre fumé,
                    // pas une vitre claire. Le ciel derrière la carte se
                    // réfracte dedans — au scroll, le fond glisse et se
                    // reflète dans le verre ; `interactive()` ajoute la
                    // réponse tactile native du matériau. Aucun fill opaque :
                    // il tuerait la réfraction.
                    Color.clear
                        .glassEffect(.regular.tint(Color.black.opacity(0.55)).interactive(),
                                     in: shape)

                    GlassLight(paused: paused)
                        .clipShape(shape)
                        .blendMode(.plusLighter)

                    WoopGrain(density: 0.05, lightAlpha: 0.022, darkAlpha: 0.032)
                        .clipShape(shape)

                    // Épaisseur du verre : un second fil INSCRIT, très faible,
                    // et un souffle de lumière sous le bord haut — c'est ce
                    // qui sépare une plaque noire d'un verre taillé.
                    shape.inset(by: 1.5)
                        .stroke(
                            LinearGradient(
                                stops: [.init(color: .white.opacity(0.07), location: 0.0),
                                        .init(color: .white.opacity(0.015), location: 0.35),
                                        .init(color: .clear, location: 1.0)],
                                startPoint: .top, endPoint: .bottom),
                            lineWidth: 1)
                    shape.fill(
                        LinearGradient(
                            stops: [.init(color: .white.opacity(0.030), location: 0.0),
                                    .init(color: .clear, location: 0.22)],
                            startPoint: .top, endPoint: .bottom))
                }
            }
            .overlay { GlassBorder(cornerRadius: cornerRadius, achieved: achieved,
                                   lit: pressed) }
            .contentShape(shape)
            // Hors écran, le verre s'endort — même dégradation sans risque
            // que MistyMetalSurface (hors ScrollView la valeur reste à true).
            .onScrollVisibilityChange(threshold: 0.02) { visible in
                onScreen = visible
            }
    }
}
