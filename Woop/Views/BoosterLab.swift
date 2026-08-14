import SceneKit
import SwiftUI

// MARK: - Banc d'essai (`-boosterLab`)

/// Page noire nue : le booster de récompense seul — le sachet noir laqué au
/// croissant, flottant dans son studio braise. Une pichenette le fait
/// TOURNER (inertie amortie, puis il se pose en douceur sur la face la plus
/// proche — recto ou verso) ; le doigt posé sur la bande du haut, face
/// avant, TRACE la découpe : un trait de lumière blanc-orangé avance sous
/// le doigt (le geste de Pokémon Pocket), la bande tombe, la carte sort du
/// sachet et vient se présenter.
///
/// Sous-flags de capture (le pattern des bancs) :
///   `-boosterStill` coupe le flottement au repos ;
///   `-boosterDos` démarre verso face caméra ;
///   `-boosterYaw <deg>` fige un lacet arbitraire (180 = recto, 90 = profil) ;
///   `-boosterMylar` charge la recette matière « mylar métallisé »
///     (par défaut : « laque noire ») ;
///   `-boosterTear <s>` fige une déchirure entamée à s (0…1) ;
///   `-boosterOpen` démarre sachet ouvert, carte présentée.
struct BoosterLab: View {
    private static let still = CommandLine.arguments.contains("-boosterStill")
    private static let dos = CommandLine.arguments.contains("-boosterDos")
    private static let mylar = CommandLine.arguments.contains("-boosterMylar")
    private static let tear: Float? = UserDefaults.standard
        .string(forKey: "boosterTear").flatMap(Float.init)
    private static let yawDeg: Float? = UserDefaults.standard
        .string(forKey: "boosterYaw").flatMap(Float.init)
    private static let open = CommandLine.arguments.contains("-boosterOpen")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            BoosterStage(still: Self.still, frozenTear: Self.tear,
                         startOpen: Self.open, startDos: Self.dos,
                         mylar: Self.mylar, frozenYawDeg: Self.yawDeg)
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
/// fait tourner le sachet ou tranche la bande (la découpe ne s'arme que
/// recto posé face caméra).
struct BoosterStage: UIViewRepresentable {
    var still: Bool
    var frozenTear: Float?
    var startOpen: Bool
    var startDos: Bool = false
    var mylar: Bool = false
    var frozenYawDeg: Float? = nil

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.rendersContinuously = true
        context.coordinator.attach(to: view, still: still, dos: startDos,
                                   mylar: mylar, yawDeg: frozenYawDeg)
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
        private var dos = false
        private var mylar = false
        private var yawDeg: Float?

        private enum Mode { case idle, spinning, tearing, opening, revealed }
        private var mode: Mode = .idle
        /// Le geste en cours : écran → progression, calé au premier point.
        private var tearOriginX: CGFloat = 0
        private var tearSpanX: CGFloat = 1
        private var tearStartProgress: Float = 0
        private var lastTickStep = 0
        private let tick = UIImpactFeedbackGenerator(style: .light)
        private let thud = UIImpactFeedbackGenerator(style: .medium)

        // ---- le tour du sachet (l'idiome maison : inertie amortie) ----
        /// Le lacet vrai, non borné : π = recto face caméra, 0 = verso.
        private var yaw: Float = .pi
        private var yawVel: Float = 0
        private var grabYaw: Float = .pi
        private var pitch: Float = 0
        private var spinLink: CADisplayLink?
        /// Écran → radians : une pleine largeur de drag ≈ un demi-tour.
        private static let radPerPoint: Float = 0.010
        /// Frein de l'inertie (s⁻¹) ; sous `magnetBelow` rad/s, l'aimant
        /// de la face la plus proche prend la main (ressort quasi
        /// critique) — le sachet ne s'arrête jamais de profil.
        private static let friction: Float = 2.0
        private static let magnetBelow: Float = 1.2
        private static let stiffness: Float = 60

        func attach(to view: SCNView, still: Bool, dos: Bool = false,
                    mylar: Bool = false, yawDeg: Float? = nil) {
            self.view = view
            self.still = still
            self.dos = dos
            self.mylar = mylar
            self.yawDeg = yawDeg
            stopSpin()
            guard let stage = BoosterScene(still: still, mylar: mylar) else { return }
            self.stage = stage
            view.scene = stage.scene
            view.pointOfView = stage.cameraNode
            yaw = yawDeg.map { $0 * .pi / 180 } ?? (dos ? 0 : .pi)
            yawVel = 0
            pitch = 0
            applyPose()
            mode = .idle
        }

        /// Le sachet est-il posé recto face caméra ? (La découpe ne s'arme
        /// que là — sur le verso ou en plein tour, le doigt fait tourner.)
        private var restingFront: Bool {
            spinLink == nil
                && abs(atan2f(sinf(yaw - .pi), cosf(yaw - .pi))) < 0.35
        }

        private func applyPose() {
            guard let stage else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0
            stage.packNode.eulerAngles.y = yaw
            stage.packNode.eulerAngles.x = pitch
            SCNTransaction.commit()
        }

        private func startSpin() {
            stopSpin()
            let link = CADisplayLink(target: self, selector: #selector(spinStep(_:)))
            link.add(to: .main, forMode: .common)
            spinLink = link
        }

        private func stopSpin() {
            spinLink?.invalidate()
            spinLink = nil
        }

        /// Une frame de vol libre : frein exponentiel tant que ça file,
        /// puis le ressort de l'aimant vers la face la plus proche.
        @objc private func spinStep(_ link: CADisplayLink) {
            // Le link RETIENT sa cible : si l'écran est parti, on se coupe
            // soi-même — sinon le coordinateur tournerait pour personne.
            guard view?.window != nil else {
                stopSpin()
                return
            }
            let dt = Float(min(max(link.targetTimestamp - link.timestamp,
                                   1.0 / 240), 1.0 / 30))
            if abs(yawVel) > Self.magnetBelow {
                yawVel *= exp(-Self.friction * dt)
            } else {
                let target = (yaw / .pi).rounded() * .pi
                yawVel += (target - yaw) * Self.stiffness * dt
                yawVel *= exp(-2 * sqrtf(Self.stiffness) * dt)
                if abs(yaw - target) < 0.002, abs(yawVel) < 0.02 {
                    // Posé. On replie le lacet dans [0 ; 2π) pour ne pas
                    // dériver à l'infini au fil des pichenettes.
                    var settled = fmodf(target, 2 * .pi)
                    if settled < 0 { settled += 2 * .pi }
                    yaw = settled
                    yawVel = 0
                    stopSpin()
                    applyPose()
                    tick.impactOccurred(intensity: 0.4)
                    return
                }
            }
            yaw += yawVel * dt
            pitch *= exp(-6 * dt)
            applyPose()
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
            attach(to: view, still: still, dos: dos, mylar: mylar,
                   yawDeg: yawDeg)
        }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            guard let view, let stage else { return }
            switch g.state {
            case .began:
                guard mode == .idle else { return }
                let p = g.location(in: view)
                let hits = view.hitTest(p, options: [.ignoreHiddenNodes: true])
                let packHit = hits.first { $0.node === stage.bodyNode || $0.node === stage.capNode }
                if let hit = packHit, restingFront,
                   hit.localCoordinates.y > stage.yTear - 0.07 {
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
                    // Attraper le sachet — y compris en plein vol : la main
                    // vole l'élan, le tour reprend sous le doigt.
                    mode = .spinning
                    stopSpin()
                    grabYaw = yaw
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
                case .spinning:
                    let t = g.translation(in: view)
                    yaw = grabYaw + Float(t.x) * Self.radPerPoint
                    pitch = Float(t.y / 320).clamped(to: -0.3 ... 0.3)
                    applyPose()
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
                case .spinning:
                    // La pichenette : l'élan du relâcher part en vol libre,
                    // l'aimant posera le sachet sur la face la plus proche.
                    yawVel = (Float(g.velocity(in: view).x) * Self.radPerPoint)
                        .clamped(to: -14 ... 14)
                    mode = .idle
                    startSpin()
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
