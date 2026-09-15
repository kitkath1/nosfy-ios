import SwiftUI
import UIKit

/// Deux valeurs animées par le compositeur, sans tâche ni état SwiftUI
/// réécrit à chaque impulsion. Le texte et les gestes restent chez l'hôte.
struct ChevronAppelNatif: UIViewRepresentable {
    var retard: Double
    var immobile: Bool

    final class Vue: UIView {
        override class var layerClass: AnyClass { CAShapeLayer.self }
        private var trait: CAShapeLayer { layer as! CAShapeLayer }
        private var tailleDessinee: CGSize = .zero
        private var retardAnime: Double?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            isUserInteractionEnabled = false
            backgroundColor = .clear
            trait.fillColor = nil
            trait.strokeColor = UIColor.white.cgColor
            trait.lineWidth = 1.6
            trait.lineCap = .round
            trait.lineJoin = .round
            trait.opacity = 0.34
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.size != tailleDessinee else { return }
            tailleDessinee = bounds.size
            let chemin = UIBezierPath()
            chemin.move(to: CGPoint(x: bounds.minX, y: bounds.maxY))
            chemin.addLine(to: CGPoint(x: bounds.midX, y: bounds.minY))
            chemin.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            trait.path = chemin.cgPath
            CATransaction.commit()
        }

        func regler(immobile: Bool, retard: Double) {
            if immobile { arreter(); return }
            guard retardAnime != retard else { return }
            retardAnime = retard
            let temps: [NSNumber] = [0, 0.17, 0.34, 1]
            let courbes = [
                CAMediaTimingFunction(controlPoints: 0.39, 0.575, 0.565, 1),
                CAMediaTimingFunction(controlPoints: 0.47, 0, 0.745, 0.715),
                CAMediaTimingFunction(name: .linear)
            ]
            let alpha = CAKeyframeAnimation(keyPath: "opacity")
            alpha.values = [0.34, 0.80, 0.34, 0.34]
            alpha.keyTimes = temps
            alpha.timingFunctions = courbes
            alpha.duration = 2.6
            let course = CAKeyframeAnimation(keyPath: "transform.translation.y")
            course.values = [0, -2, 0, 0]
            course.keyTimes = temps
            course.timingFunctions = courbes
            course.duration = 2.6
            let appel = CAAnimationGroup()
            appel.animations = [alpha, course]
            appel.duration = 2.6
            appel.repeatCount = .infinity
            appel.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + retard
            layer.add(appel, forKey: "appel")
        }

        func arreter() {
            guard retardAnime != nil else { return }
            layer.removeAnimation(forKey: "appel")
            retardAnime = nil
        }
    }

    func makeUIView(context: Context) -> Vue { Vue(frame: .zero) }

    func updateUIView(_ vue: Vue, context: Context) {
        vue.regler(immobile: immobile, retard: retard)
    }

    static func dismantleUIView(_ vue: Vue, coordinator: ()) {
        vue.arreter()
    }
}
