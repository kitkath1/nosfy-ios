import SceneKit
import SwiftUI

// MARK: - Banc d'essai (`-boosterLab`)

/// Page noire nue : le booster de récompense seul — le sachet noir laqué au
/// croissant, flottant dans son studio braise. Le doigt l'incline ; posé sur
/// la bande du haut, il TRACE la découpe : un trait de lumière blanc-orangé
/// avance sous le doigt (le geste de Pokémon Pocket), la bande tombe, la
/// carte sort du sachet et vient se présenter.
///
/// Sous-flags de capture (le pattern des bancs) :
///   `-boosterStill` coupe le flottement au repos ;
///   `-boosterTear <s>` fige une déchirure entamée à s (0…1) ;
///   `-boosterOpen` démarre sachet ouvert, carte présentée.
struct BoosterLab: View {
    private static let still = CommandLine.arguments.contains("-boosterStill")
    private static let tear: Float? = UserDefaults.standard
        .string(forKey: "boosterTear").flatMap(Float.init)
    private static let open = CommandLine.arguments.contains("-boosterOpen")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            BoosterStage(still: Self.still, frozenTear: Self.tear, startOpen: Self.open)
                .ignoresSafeArea()
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }
}

// MARK: - La cage SceneKit

/// L'hôte du sachet : 60 fps (la découpe et les étincelles sont des
/// mouvements continus), gestes UIKit — le hit-test décide si le doigt
/// incline le sachet ou tranche la bande.
struct BoosterStage: UIViewRepresentable {
    var still: Bool
    var frozenTear: Float?
    var startOpen: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.rendersContinuously = true
        context.coordinator.attach(to: view, still: still)
        if let s = frozenTear {
            context.coordinator.freezeTear(at: s)
        } else if startOpen {
            context.coordinator.jumpToOpen()
        }
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.pan(_:)))
        view.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.tap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: le chef d'orchestre

    final class Coordinator: NSObject {
        private weak var view: SCNView?
        private var stage: BoosterScene?
        private var still = false

        private enum Mode { case idle, tilting, tearing, opening, revealed }
        private var mode: Mode = .idle
        /// Le geste en cours : écran → progression, calé au premier point.
        private var tearOriginX: CGFloat = 0
        private var tearSpanX: CGFloat = 1
        private var tearStartProgress: Float = 0
        private var lastTickStep = 0
        private let tick = UIImpactFeedbackGenerator(style: .light)
        private let thud = UIImpactFeedbackGenerator(style: .medium)

        func attach(to view: SCNView, still: Bool) {
            self.view = view
            self.still = still
            guard let stage = BoosterScene(still: still) else { return }
            self.stage = stage
            view.scene = stage.scene
            view.pointOfView = stage.cameraNode
            mode = .idle
        }

        func freezeTear(at s: Float) {
            stage?.setTear(s, sparking: false)
            stage?.dim(true)
        }

        func jumpToOpen() {
            guard let stage else { return }
            stage.setTear(1, sparking: false)
            stage.capNode.isHidden = true
            // Reparentée D'ABORD, posée ENSUITE : figée depuis l'intérieur
            // du sachet, la carte emporterait le pincement x·0,75 dans sa
            // transformation monde — présentée maigre, sans un mot.
            stage.cardNode.removeFromParentNode()
            stage.scene.rootNode.addChildNode(stage.cardNode)
            stage.cardNode.position = SCNVector3(0, 0.02, 0.55)
            stage.cardNode.eulerAngles = SCNVector3(0, 0, 0)
            stage.cardNode.scale = SCNVector3(1.05, 1.05, 1.05)
            stage.packNode.position.y = -1.7
            mode = .revealed
        }

        // MARK: gestes

        @objc func tap(_ g: UITapGestureRecognizer) {
            guard mode == .revealed, let view else { return }
            // Un toucher, et le banc se réarme : la cérémonie se rejoue à
            // volonté — la méthode maison pour juger un enchaînement.
            attach(to: view, still: still)
        }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            guard let view, let stage else { return }
            switch g.state {
            case .began:
                guard mode == .idle else { return }
                let p = g.location(in: view)
                let hits = view.hitTest(p, options: [.ignoreHiddenNodes: true])
                let packHit = hits.first { $0.node === stage.bodyNode || $0.node === stage.capNode }
                if let hit = packHit, hit.localCoordinates.y > stage.yTear - 0.07 {
                    mode = .tearing
                    // La course écran de la découpe : la largeur projetée du
                    // sachet à hauteur de la ligne — convertie DEPUIS le
                    // repère du sachet, pour que le pincement x·0,75 compte.
                    let a = stage.packNode.convertPosition(
                        SCNVector3(0.40, stage.yTear, -0.06), to: nil)
                    let b = stage.packNode.convertPosition(
                        SCNVector3(-0.40, stage.yTear, -0.06), to: nil)
                    let left = view.projectPoint(a)
                    let right = view.projectPoint(b)
                    tearOriginX = CGFloat(min(left.x, right.x))
                    tearSpanX = max(CGFloat(abs(right.x - left.x)), 1)
                    tearStartProgress = stage.tearProgress
                    lastTickStep = Int(tearStartProgress * 8)
                    stage.dim(true)
                    tick.prepare()
                } else if packHit != nil {
                    mode = .tilting
                }
            case .changed:
                switch mode {
                case .tearing:
                    let s = Float((g.location(in: view).x - tearOriginX) / tearSpanX)
                    let progress = max(tearStartProgress, min(s, 1))
                    stage.setTear(progress, sparking: true)
                    let step = Int(progress * 8)
                    if step > lastTickStep {
                        lastTickStep = step
                        tick.impactOccurred(intensity: 0.6)
                    }
                case .tilting:
                    let t = g.translation(in: view)
                    let yaw = Float(t.x / 240).clamped(to: -0.5 ... 0.5)
                    let pitch = Float(t.y / 320).clamped(to: -0.3 ... 0.3)
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0
                    stage.packNode.eulerAngles.y = .pi + yaw
                    stage.packNode.eulerAngles.x = pitch
                    SCNTransaction.commit()
                default:
                    break
                }
            case .ended, .cancelled:
                switch mode {
                case .tearing:
                    stage.sparks.birthRate = 0
                    if stage.tearProgress > 0.82 {
                        finishTear()
                    } else {
                        // Entamé mais pas fini : le sachet reste mordu, la
                        // pénombre se lève — on reprendra la découpe.
                        stage.dim(false)
                        mode = .idle
                    }
                case .tilting:
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.6
                    SCNTransaction.animationTimingFunction =
                        CAMediaTimingFunction(name: .easeOut)
                    stage.packNode.eulerAngles.y = .pi
                    stage.packNode.eulerAngles.x = 0
                    SCNTransaction.commit()
                    mode = .idle
                default:
                    mode = mode == .revealed ? .revealed : .idle
                }
            default:
                break
            }
        }

        // MARK: l'ouverture

        /// Fin de course : la découpe file toute seule au bout, la bande
        /// meurt, la carte monte de la fente puis vient se présenter.
        private func finishTear() {
            guard let stage else { return }
            mode = .opening
            stage.setTear(1, sparking: true)
            thud.impactOccurred()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self, let stage = self.stage else { return }
                stage.sparks.birthRate = 0
                stage.capNode.isHidden = true
                stage.fadeTornGlow(over: 1.0)

                // Le sachet s'incline, la carte sort de la fente.
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 1.1
                SCNTransaction.animationTimingFunction =
                    CAMediaTimingFunction(name: .easeInEaseOut)
                stage.packNode.eulerAngles.x = -0.14
                stage.cardNode.position.y = 0.78
                SCNTransaction.commit()

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                    self.presentCard()
                }
            }
        }

        /// La carte quitte le sachet et prend la scène ; le sachet s'efface
        /// par le bas, la lumière remonte.
        private func presentCard() {
            guard let stage else { return }
            let world = stage.cardNode.worldTransform
            stage.cardNode.removeFromParentNode()
            stage.scene.rootNode.addChildNode(stage.cardNode)
            stage.cardNode.transform = world

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.9
            SCNTransaction.animationTimingFunction =
                CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            stage.cardNode.position = SCNVector3(0, 0.02, 0.55)
            stage.cardNode.eulerAngles = SCNVector3(0, 0, 0)
            stage.cardNode.scale = SCNVector3(1.05, 1.05, 1.05)
            stage.packNode.position.y = -1.7
            stage.dim(false)
            SCNTransaction.commit()

            let cardMaterial = stage.cardNode.geometry?.firstMaterial
            cardMaterial?.emission.intensity = 0.5
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.4
            cardMaterial?.emission.intensity = 0
            SCNTransaction.commit()

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            mode = .revealed
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    BoosterLab()
}
