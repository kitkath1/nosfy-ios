import SwiftUI
import UIKit

// MARK: - Le verre gonflé — la matière de la carte des séries
//
// TOUTE la matière vit dans `verreGonfle` (Woop/VerreCoulant.metal). Ici,
// seulement le cadrage : un rectangle PLUS GRAND que la carte (marge
// `pad`) pour loger la lumière qui déborde.
//
// RESTAURATION (16-08, verdict 2/10 sur le tour 9) : le shader est GELÉ —
// t = 0 en dur, plus de TimelineView, mêmes pixels à chaque frame. La loi
// du brief : on reproduit une PHOTOGRAPHIE ; la respiration ne reviendra
// qu'après le match au DIFF, en modulant des portées, avec t=0 ≡ l'état
// calibré. `mode` = le mini debug (0 FINAL · 1 SDF · 2 INSIDE ONLY ·
// 3 OUTSIDE ONLY · 4 ×16), piloté par le banc `-verreLab`.
struct VerreGonfle: View {
    var rayonHaut: CGFloat
    var rayonBas: CGFloat
    /// Conservé pour l'appelant (la loi de fluidité reprendra au dé-gel) —
    /// sans effet tant que le shader est figé.
    var allege: Bool
    var mode: Int = 0

    /// La marge de débordement — Phase 2 : le bloom est borné à ~16 pt
    /// de la tranche (seuil + borne spatiale dans le shader), 28 pt
    /// suffisent avec l'antialiasing. L'époque des 84 pt est morte avec
    /// les rayons.
    static let pad: CGFloat = 28

    /// LA CONTROLMAP (Phase 8) — lue depuis le dépôt au banc ; au
    /// téléphone (fichier absent) : un pixel NOIR = aucune modulation.
    /// Elle rejoindra le bundle au moment du commit.
    private static let mapImage: Image = {
        if let ui = UIImage(contentsOfFile:
            "/Users/kathryn/Desktop/woochoper-ios/tools/verre/CollapsedGlassControlMap.png") {
            return Image(uiImage: ui)
        }
        let r = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let ui = r.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return Image(uiImage: ui)
    }()

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width + Self.pad * 2
            let h = geo.size.height + Self.pad * 2
            Rectangle()
                .fill(.white)
                .frame(width: w, height: h)
                .colorEffect(Self.dithered(ShaderLibrary.verreGonfle(
                    .float2(w, h), .float(0),
                    .float(Float(Self.pad)),
                    .float(Float(rayonHaut)), .float(Float(rayonBas)),
                    .float(Float(mode)),
                    .image(Self.mapImage))))
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
