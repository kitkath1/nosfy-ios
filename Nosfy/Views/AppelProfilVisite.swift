import SwiftUI
import UIKit

/// Le glyphe blanc s'allume au temps Profil ou Pièces de la visite. Seule l'opacité de
/// son image fixe est animée par le compositeur ; aucun réveil de la page.
struct AppelProfilVisite: View {
    enum Symbole { case profil, lune }
    var symbole: Symbole = .profil
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.ongletCache) private var cache

    var body: some View {
        Glyphe(symbole: symbole, fige: phase != .active || cache || reduceMotion
               || ProtectionThermique.shared.ambianceAuRepos
               || CommandLine.arguments.contains("-sansAppelProfilVisite"))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private struct Glyphe: UIViewRepresentable {
        var symbole: Symbole
        var fige: Bool
        func makeUIView(context: Context) -> Hote { Hote(symbole: symbole) }
        func updateUIView(_ vue: Hote, context: Context) {
            vue.image = Hote.image(symbole)
            vue.fige = fige
        }
        static func dismantleUIView(_ vue: Hote, coordinator: ()) {
            vue.layer.removeAllAnimations()
        }
    }

    private final class Hote: UIImageView {
        private static let glyphe = UIImage(systemName: "person", withConfiguration:
            UIImage.SymbolConfiguration(pointSize: 21, weight: .medium))
        // Même contour et même placement que le croissant de MoonCoinView.
        // Image cuite une seule fois ; le compositeur anime ensuite son alpha.
        private static let lune = UIGraphicsImageRenderer(size: CGSize(width: 46, height: 46)).image { _ in
            let largeur: CGFloat = 46 * 0.865 * 0.71
            let rect = CGRect(x: (46 - largeur) / 2,
                              y: 46 * 0.485 - largeur / 2,
                              width: largeur, height: largeur)
            UIColor.white.setFill()
            UIBezierPath(cgPath: MoonShape().path(in: rect).cgPath).fill()
        }
        static func image(_ symbole: Symbole) -> UIImage? {
            switch symbole {
            case .profil: glyphe
            case .lune: lune
            }
        }
        var fige = true { didSet { actualiser() } }

        init(symbole: Symbole) {
            super.init(image: Self.image(symbole))
            tintColor = .white
            contentMode = .center
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }
        required init?(coder: NSCoder) { fatalError() }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            actualiser()
        }
        private func actualiser() {
            guard !fige, window != nil else {
                layer.removeAnimation(forKey: "appel-profil")
                layer.opacity = 1
                return
            }
            guard layer.animation(forKey: "appel-profil") == nil else { return }
            let souffle = CAKeyframeAnimation(keyPath: "opacity")
            souffle.values = [0.25, 1, 1, 0.25]
            souffle.keyTimes = [0, 0.4, 0.6, 1]
            souffle.duration = 1.6
            souffle.repeatCount = .infinity
            souffle.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 3)
            layer.add(souffle, forKey: "appel-profil")
        }
    }
}
