import SwiftUI

// MARK: - Le verre gonflé — la matière de la carte des séries
//
// TOUTE la matière vit dans `verreGonfle` (Woop/VerreCoulant.metal) : les
// huit systèmes optiques mesurés au pixel sur la référence de Kathryn
// (épaule gauche à deux facettes, flaque du flanc droit, nappe du coin
// haut-droit, brume sépia du bas, trait angulaire, blooms et rayons dans
// l'air, grain). Ici, seulement le cadrage : un rectangle PLUS GRAND que la
// carte (marge `pad`) pour loger la lumière qui déborde, et la cadence.
//
// Les couches SwiftUI d'avant (dégradés + strokeBorder + ellipses floues)
// sont MORTES — verdict du 15-08 : « on dirait du blur, des corner borders
// dégradés, un halo posé vite fait ». Un verre n'est pas une couleur, c'est
// un éclairage : il se calcule, il ne se peint pas.
struct VerreGonfle: View {
    var rayonHaut: CGFloat
    var rayonBas: CGFloat
    var allege: Bool

    /// La marge de débordement : les flaques des coins bas (portée ~40 pt)
    /// et les rayons doivent mourir AVANT le bord du rectangle, sinon ils
    /// se coupent net. 84 pt les laisse s'éteindre sous 1/255.
    static let pad: CGFloat = 84

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width + Self.pad * 2
            let h = geo.size.height + Self.pad * 2
            // EN COURSE (`allege`) la respiration se fige : la cadence
            // tombe à 1 s — la taille, elle, continue d'animer le shader
            // à chaque image, c'est tout ce que l'œil suit.
            TimelineView(.animation(minimumInterval: allege ? 1.0 : 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                Rectangle()
                    .fill(.white)
                    .frame(width: w, height: h)
                    .colorEffect(Self.dithered(ShaderLibrary.verreGonfle(
                        .float2(w, h), .float(t),
                        .float(Float(Self.pad)),
                        .float(Float(rayonHaut)), .float(Float(rayonBas)))))
            }
            .offset(x: -Self.pad, y: -Self.pad)
        }
        .allowsHitTesting(false)
    }

    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }
}
