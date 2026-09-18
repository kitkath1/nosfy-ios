import SwiftUI
import UIKit

/// La rangée reste indépendante des anciens moteurs de respiration : elle
/// peut être intégrée aussi bien avant qu'après leur refonte SwiftUI.
struct PerlesSemaineNatives: View {
    static let actives = !CommandLine.arguments.contains("-perleSwiftUI")
        && !SouffleBanc.horloge
    let jours: [String]
    let joursFaits: Set<Int>?
    let faites: Int
    let p: Double
    let largeur: CGFloat
    let hauteur: CGFloat
    let immobile: Bool

    var body: some View {
        ZStack {
            ForEach(0..<jours.count, id: \.self) { i in
                let fait = joursFaits?.contains(i) ?? (Double(i) < Double(faites) * p)
                let dernier = fait && i == (joursFaits.map { $0.max() ?? -1 } ?? faites - 1)
                Group {
                    if dernier {
                        PerleSemaineNative(largeurWidget: largeur,
                            immobile: immobile || CommandLine.arguments.contains("-sansSoufflePerle"))
                    } else {
                        Circle().fill(fait
                            ? AnyShapeStyle(RadialGradient(stops: [
                                .init(color: CardTon.chaleur(0.92), location: 0),
                                .init(color: CardTon.chaleur(0.60), location: 0.55),
                                .init(color: CardTon.chaleur(0.26), location: 1)
                            ], center: UnitPoint(x: 0.38, y: 0.30), startRadius: 0,
                               endRadius: 0.046 * largeur))
                            : AnyShapeStyle(LinearGradient(
                                colors: [Color(white: 0.20), Color(white: 0.135)],
                                startPoint: .top, endPoint: .bottom)))
                    }
                }
                .frame(width: 0.052 * largeur, height: 0.052 * largeur)
                .shadow(color: fait && !dernier ? CardTon.chaleur(0.38).opacity(0.55) : .clear,
                        radius: 0.030 * largeur)
                .position(x: (0.156 + 0.1115 * Double(i)) * largeur, y: 0.578 * hauteur)
                Text(jours[i])
                    .font(.system(size: 0.046 * hauteur, weight: .medium))
                    .foregroundStyle(CardTon.encreJour)
                    .position(x: (0.156 + 0.1115 * Double(i)) * largeur, y: 0.680 * hauteur)
            }
        }
        .frame(width: largeur, height: hauteur)
    }
}

/// Les deux robes du point hebdomadaire sont calculées à sa taille une fois.
/// Le fondu et le souffle passent ensuite au compositeur, sans entretenir
/// une interpolation dans le graphe SwiftUI de la Home.
struct PerleSemaineNative: UIViewRepresentable {
    let largeurWidget: CGFloat
    let immobile: Bool
    @Environment(\.scenePhase) private var scene
    @Environment(\.ongletCache) private var cache

    final class Vue: UIView {
        let pic = CALayer()
        var configuration: CGSize = .zero
        var immobile = true

        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            isUserInteractionEnabled = false
            layer.masksToBounds = true
            pic.opacity = 0
            layer.addSublayer(pic)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.cornerRadius = bounds.width / 2
            pic.frame = bounds
            CATransaction.commit()
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            actualiser()
        }
        func actualiser() {
            guard !immobile, window != nil else {
                layer.removeAnimation(forKey: "souffle-perle")
                pic.removeAnimation(forKey: "robe-perle")
                return
            }
            guard layer.animation(forKey: "souffle-perle") == nil else { return }
            let taille = CABasicAnimation(keyPath: "transform.scale")
            taille.fromValue = 1.0
            taille.toValue = 1.06
            let robe = CABasicAnimation(keyPath: "opacity")
            robe.fromValue = 0.0
            robe.toValue = 1.0
            let debut = layer.convertTime(CACurrentMediaTime(), from: nil)
            for animation in [taille, robe] {
                animation.duration = 2.35
                animation.autoreverses = true
                animation.repeatCount = .infinity
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation.beginTime = debut
            }
            layer.add(taille, forKey: "souffle-perle")
            pic.add(robe, forKey: "robe-perle")
        }
    }

    func makeUIView(context: Context) -> Vue { Vue(frame: .zero) }

    func updateUIView(_ vue: Vue, context: Context) {
        let diametre = largeurWidget * 0.052
        let facteur = context.environment.displayScale
        let configuration = CGSize(width: diametre, height: facteur)
        if vue.configuration != configuration {
            func image(_ phase: Double) -> CGImage? {
                let robe = RadialGradient(stops: [
                    .init(color: CardTon.chaleur(0.92 + 0.08 * phase), location: 0),
                    .init(color: CardTon.chaleur(0.60), location: 0.55),
                    .init(color: CardTon.chaleur(0.26), location: 1)
                ], center: UnitPoint(x: 0.38, y: 0.30), startRadius: 0,
                   endRadius: 0.046 * largeurWidget)
                let rendu = ImageRenderer(content: Rectangle().fill(robe)
                    .frame(width: diametre, height: diametre))
                rendu.scale = facteur
                return rendu.cgImage
            }
            if let repos = image(0), let pic = image(1) {
                vue.configuration = configuration
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                vue.layer.contents = repos
                vue.layer.contentsScale = facteur
                vue.pic.contents = pic
                vue.pic.contentsScale = facteur
                CATransaction.commit()
            }
        }
        vue.immobile = immobile || cache || scene != .active
            || DepartEtat.shared.homeDort || CouvertureFoyer.shared.recouvert
            || ProtectionThermique.shared.ambianceAuRepos
        vue.actualiser()
    }

    static func dismantleUIView(_ vue: Vue, coordinator: ()) {
        vue.immobile = true
        vue.actualiser()
    }
}
