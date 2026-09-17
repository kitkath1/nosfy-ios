import SwiftUI
import UIKit

/// Le glyphe blanc s'allume au temps Profil de la visite. Seule l'opacité de
/// son image fixe est animée par le compositeur ; aucun réveil de la page.
struct AppelProfilVisite: View {
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.ongletCache) private var cache

    var body: some View {
        Glyphe(fige: phase != .active || cache || reduceMotion
               || ProtectionThermique.shared.ambianceAuRepos
               || CommandLine.arguments.contains("-sansAppelProfilVisite"))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private struct Glyphe: UIViewRepresentable {
        var fige: Bool
        func makeUIView(context: Context) -> Hote { Hote() }
        func updateUIView(_ vue: Hote, context: Context) { vue.fige = fige }
        static func dismantleUIView(_ vue: Hote, coordinator: ()) {
            vue.layer.removeAllAnimations()
        }
    }

    private final class Hote: UIImageView {
        private static let glyphe = UIImage(systemName: "person", withConfiguration:
            UIImage.SymbolConfiguration(pointSize: 21, weight: .medium))
        var fige = true { didSet { actualiser() } }

        init() {
            super.init(image: Self.glyphe)
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
