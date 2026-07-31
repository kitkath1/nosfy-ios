import SwiftUI
import UIKit

// MARK: - Le toucher : le spot s'ouvre

/// À poser sur le Button qui enveloppe `ObsidianGlassCard`. Le faisceau froid
/// GROSSIT sous le doigt (+26 % en long, +34 % en large, +30 % d'amplitude), et
/// la main doit sentir la même chose : pas un clic, un GONFLEMENT. D'où deux
/// impacts très rapprochés, faible puis fort — un seul impact, même appuyé, se
/// lit comme un interrupteur ; deux à 90 ms se lisent comme une ouverture.
/// Au relâchement, un seul toucher léger : le spot se referme, il ne claque pas.
struct ObsidianCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.objectiveCardPressed, configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                let gen = UIImpactFeedbackGenerator(style: .soft)
                gen.prepare()
                if pressed {
                    gen.impactOccurred(intensity: 0.35)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                        gen.impactOccurred(intensity: 0.75)
                    }
                } else {
                    gen.impactOccurred(intensity: 0.30)
                }
            }
    }
}

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

    /// Marge de débordement. Elle valait 90 pt tant que le halo vivait dehors ;
    /// depuis que la lumière s'arrête net au bord, il ne reste qu'à loger
    /// l'antialiasing du liseré. 6 pt suffisent, et la texture rendue passe de
    /// 542×355 à 374×187 points — moitié moins de pixels à chaque image.
    static let pad: CGFloat = 6

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
    /// La référence mesurait 27 pt (cercle ajusté sur la crête spéculaire des
    /// trois coins non cramés). Kathryn l'a trouvé trop rond une fois la carte
    /// dans l'app : descendu à 20 pt à sa demande (31/07) — son œil gagne sur
    /// la mesure.
    private let cornerRadius: CGFloat = 20

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
