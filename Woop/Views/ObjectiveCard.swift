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

/// Le ciel de verre : voir `objectiveCrest` + `objectiveCrestStars` dans
/// DemonSky.metal. Deux passes, comme le ciel : le diffus (nappes de métal
/// liquide + cordon de nébuleuse) en DEMI-résolution, la poudre d'étoiles en
/// pleine, composées en `plusLighter` — de la lumière ajoutée au verre,
/// jamais un calque qui le grise. Même horloge globale que le ciel
/// (mod 900 s) : la carte est une fenêtre sur le même cosmos.
private struct GlassNebula: View {
    var paused: Bool

    /// Unité verticale du cordon, en points (sa largeur, sa chute).
    private static let fall: CGFloat = 62

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
                let t = Float(timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))

                ZStack(alignment: .topLeading) {
                    // Le shader travaille en unités relatives à `fall` : les
                    // uniforms divisés par deux suffisent à la demi-résolution.
                    Rectangle()
                        .fill(.black)
                        .frame(width: w / 2, height: h / 2)
                        .colorEffect(Self.dithered(ShaderLibrary.objectiveCrest(
                            .float2(w / 2, h / 2), .float(t),
                            .float(Self.fall / 2),
                            .image(NebulaNoise.image),
                            .image(NebulaStrip.image))))
                        .scaleEffect(2, anchor: .topLeading)

                    Rectangle()
                        .fill(.black)
                        .frame(width: w, height: h)
                        .colorEffect(ShaderLibrary.objectiveCrestStars(
                            .float2(w, h), .float(t),
                            .float(Self.fall),
                            .image(NebulaNoise.image),
                            .image(NebulaStrip.image)))
                        .blendMode(.plusLighter)
                }
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

/// Le fil qui cerne le verre. AU REPOS il est éteint : un trait à peine là,
/// qui délimite sans briller. AU TOUCHER il s'allume — trois passes
/// concentriques (halo, lueur, fil, une vraie PSF) — et VIBRE lentement :
/// une pulsation de ~1,9 s, une lampe qui respire, pas un stroboscope.
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

    private var restLine: LinearGradient {
        LinearGradient(
            stops: [.init(color: (achieved ? Color(red: 1.0, green: 0.95, blue: 0.82) : .white)
                              .opacity(0.30), location: 0.0),
                    .init(color: .white.opacity(0.13), location: 0.45),
                    .init(color: .white.opacity(0.07), location: 1.0)],
            startPoint: .top, endPoint: .bottom)
    }

    private var litLine: LinearGradient {
        LinearGradient(
            stops: [.init(color: achieved ? Color(red: 1.0, green: 0.95, blue: 0.82) : .white,
                          location: 0.0),
                    .init(color: .white.opacity(0.60), location: 0.42),
                    .init(color: .white.opacity(0.36), location: 1.0)],
            startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            // Le fil éteint, toujours là : la carte reste délimitée.
            shape.stroke(restLine, lineWidth: 1)

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
                                       .init(color: .white.opacity(0.72), location: 1.0)],
                               startPoint: .top, endPoint: .bottom)
                    .padding(-48)      // couvre le débord du flou
            }
            .opacity(lit ? 1 : 0)
            .animation(.easeOut(duration: lit ? 0.22 : 0.9), value: lit)
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
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

                    GlassNebula(paused: paused)
                        .clipShape(shape)
                        .blendMode(.plusLighter)

                    WoopGrain(density: 0.05, lightAlpha: 0.022, darkAlpha: 0.032)
                        .clipShape(shape)
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
