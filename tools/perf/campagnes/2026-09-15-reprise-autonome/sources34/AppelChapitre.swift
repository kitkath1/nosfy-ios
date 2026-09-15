import SwiftUI
import UIKit

/// Un seul repère, autour du jour à ouvrir. Le cercle est dessiné une fois ;
/// le compositeur anime son alpha et son échelle pendant 1,4 s sur 5,2 s.
/// Aucun flou, shader ou horloge de rendu SwiftUI.
struct AppelChapitre: View {
    let taille: CGFloat
    @Environment(\.ongletCache) private var cache
    @Environment(\.scenePhase) private var scene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var dort: Bool {
        cache || scene != .active || reduceMotion
            || DepartEtat.shared.homeDort || CouvertureFoyer.shared.recouvert
            || ProtectionThermique.shared.appelAuRepos
    }

    var body: some View {
        AnneauChapitre(immobile: dort)
            .frame(width: taille, height: taille)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct AnneauChapitre: UIViewRepresentable {
    let immobile: Bool

    final class Vue: UIView {
        override class var layerClass: AnyClass { CAShapeLayer.self }
        private var trait: CAShapeLayer { layer as! CAShapeLayer }
        private var tailleDessinee: CGSize = .zero
        var immobile = true

        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            isUserInteractionEnabled = false
            trait.fillColor = nil
            trait.strokeColor = UIColor.white.cgColor
            trait.lineWidth = 1.3
            trait.opacity = 0
        }
        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.size != tailleDessinee else { return }
            tailleDessinee = bounds.size
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            trait.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).cgPath
            CATransaction.commit()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            actualiser()
        }

        func actualiser() {
            guard !immobile, window != nil else {
                layer.removeAnimation(forKey: "appel-chapitre")
                return
            }
            guard layer.animation(forKey: "appel-chapitre") == nil else { return }
            let alpha = CAKeyframeAnimation(keyPath: "opacity")
            alpha.values = [0, 0.46, 0, 0]
            alpha.keyTimes = [0, 0.045, 0.27, 1]
            let taille = CAKeyframeAnimation(keyPath: "transform.scale")
            taille.values = [0.97, 1.08, 1.65, 1.65]
            taille.keyTimes = [0, 0.045, 0.27, 1]
            for animation in [alpha, taille] {
                animation.duration = 5.2
                animation.timingFunctions = [
                    CAMediaTimingFunction(name: .easeOut),
                    CAMediaTimingFunction(name: .easeOut),
                    CAMediaTimingFunction(name: .linear)
                ]
            }
            let appel = CAAnimationGroup()
            appel.animations = [alpha, taille]
            appel.duration = 5.2
            appel.repeatCount = .infinity
            layer.add(appel, forKey: "appel-chapitre")
        }
    }

    func makeUIView(context: Context) -> Vue { Vue(frame: .zero) }
    func updateUIView(_ vue: Vue, context: Context) {
        vue.immobile = immobile
        vue.actualiser()
    }
    static func dismantleUIView(_ vue: Vue, coordinator: ()) {
        vue.immobile = true
        vue.actualiser()
    }
}
