import SwiftUI
import UIKit
import QuartzCore

/// Prototype opt-in : même peinture SwiftUI et mêmes traits floutés,
/// exportés à l'échelle native. Aucune horloge ni écriture SwiftUI par
/// image. Le verre placé au-dessus reste cependant un coût de composition.
///
/// Limites à comparer sur téléphone : rééchantillonnage de la peinture
/// tournée, quantification des images, alpha du masque et bords du flou.
/// La marge de 16 pt conserve les débords des traits ; elle n'agrandit pas
/// le layout. ImageRenderer ne voit que ces dessins, jamais le verre.
struct LisereCoreAnimation<F: Shape>: UIViewRepresentable {
    var forme: F
    var W: CGFloat
    var H: CGFloat
    var chambre: Double
    var penche: Double
    var dort: Bool
    var amplitude: Double
    var periode: Double
    var pose: Double?
    var onEchec: () -> Void

    func makeUIView(context: Context) -> LisereCoreAnimationVue {
        LisereCoreAnimationVue(frame: .zero)
    }

    func updateUIView(_ vue: LisereCoreAnimationVue, context: Context) {
        let taille = CGSize(width: W, height: H)
        guard W > 0, H > 0, W.isFinite, H.isFinite else {
            vue.arreter()
            return
        }
        let scale = max(context.environment.displayScale, 1)
        let neuf = !vue.correspond(taille: taille, scale: scale,
                                   chemin: forme.path(in: CGRect(
                                    origin: .zero, size: taille)))
        if neuf, !vue.preparer(forme: forme, taille: taille, scale: scale) {
            vue.signalerEchec(onEchec)
            return
        }
        if neuf {
            // Les images neuves sont déjà à la bonne taille : pas de fondu
            // implicite de contents, ni d'entrée depuis un masque vide.
            UIView.performWithoutAnimation {
                vue.appliquer(chambre: chambre, penche: penche)
            }
        } else {
            // La pression suit exactement la transaction de l'hôte. Elle
            // ne recuit PAS les images et ne réarme pas la respiration.
            context.animate {
                vue.appliquer(chambre: chambre, penche: penche)
            }
        }
        vue.respirer(dort: dort, amplitude: amplitude,
                     periode: periode, pose: pose)
    }

    static func dismantleUIView(_ vue: LisereCoreAnimationVue,
                                coordinator: ()) {
        vue.arreter()
    }
}

final class LisereCoreAnimationVue: UIView {
    private static let marge: CGFloat = 16
    private static let cleSouffle = "lisere.respiration"

    private struct Cache: Equatable {
        var taille: CGSize
        var scale: CGFloat
        var chemin: Path
    }
    private struct Respiration: Equatable {
        var dort: Bool
        var amplitude: Double
        var periode: Double
        var pose: Double?
    }

    // Un seul jeu d'images par instance. Ni la pression ni l'angle ne
    // figurent dans la clé : appuyer ne déclenche aucun ImageRenderer.
    private var cache: Cache?
    private var demande: Respiration?
    private var effective: Respiration?
    private var echecSignale = false
    private var angleBase: CGFloat?
    private var alphaPression: CGFloat?
    private let surface = UIView()
    private let orientation = UIView()
    private let oscillation = UIView()
    private let peinture = UIImageView()
    private let masque = UIView()
    private let trait = UIImageView()
    private let halo = UIImageView()
    private let pression = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        for vue in [self, surface, orientation, oscillation, peinture,
                    masque, trait, halo, pression] {
            vue.backgroundColor = .clear
            vue.isOpaque = false
            vue.isUserInteractionEnabled = false
            vue.clipsToBounds = false
            vue.accessibilityElementsHidden = true
        }
        addSubview(surface)
        surface.addSubview(oscillation)
        oscillation.addSubview(orientation)
        orientation.addSubview(peinture)
        // Dans le témoin, l'angle de base tourne le dégradé DANS le
        // carré, puis la respiration tourne ce carré. Garder cet ordre
        // évite de déplacer ses bords quand la chambre change.
        oscillation.clipsToBounds = true
        surface.mask = masque
        masque.addSubview(trait)
        masque.addSubview(halo)
        masque.addSubview(pression)
        halo.alpha = 0.46
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) indisponible") }

    func correspond(taille: CGSize, scale: CGFloat, chemin: Path) -> Bool {
        cache == Cache(taille: taille, scale: scale, chemin: chemin)
    }

    func preparer<F: Shape>(forme: F, taille: CGSize,
                            scale: CGFloat) -> Bool {
        let cote = hypot(taille.width, taille.height)
        // Le dégradé interne reste couvrant quand son angle de base
        // change ; seul le carré d'origine (cote) le découpe ensuite.
        let cotePeinture = cote * sqrt(2)
        let dessin = Rectangle()
            .fill(cardLisereConique(.zero))
            .frame(width: cotePeinture, height: cotePeinture)
        guard let couleur = image(dessin, scale: scale),
              let net = image(forme.stroke(.white, lineWidth: 1.6)
                .frame(width: taille.width, height: taille.height)
                .padding(Self.marge), scale: scale),
              let large = image(forme.stroke(.white, lineWidth: 4.4)
                .blur(radius: 2.4)
                .frame(width: taille.width, height: taille.height)
                .padding(Self.marge), scale: scale),
              let serre = image(forme.stroke(.white, lineWidth: 2.6)
                .blur(radius: 1.2)
                .frame(width: taille.width, height: taille.height)
                .padding(Self.marge), scale: scale)
        else { return false }

        UIView.performWithoutAnimation {
            surface.frame = CGRect(x: -Self.marge, y: -Self.marge,
                                   width: taille.width + 2 * Self.marge,
                                   height: taille.height + 2 * Self.marge)
            masque.frame = surface.bounds
            for vue in [trait, halo, pression] { vue.frame = masque.bounds }
            // bounds/center restent définis même quand transform est
            // animé ; régler frame sur une vue tournée serait ambigu.
            oscillation.bounds = CGRect(x: 0, y: 0, width: cote, height: cote)
            oscillation.center = CGPoint(x: surface.bounds.midX,
                                         y: surface.bounds.midY)
            orientation.bounds = CGRect(x: 0, y: 0,
                                        width: cotePeinture,
                                        height: cotePeinture)
            orientation.center = CGPoint(x: cote / 2, y: cote / 2)
            peinture.frame = orientation.bounds
            peinture.image = couleur
            trait.image = net
            halo.image = large
            pression.image = serre
        }
        cache = Cache(taille: taille, scale: scale,
                      chemin: forme.path(in: CGRect(origin: .zero, size: taille)))
        return true
    }

    private func image<V: View>(_ contenu: V, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: contenu)
        renderer.scale = scale
        renderer.isOpaque = false
        renderer.colorMode = .nonLinear
        // Le CGImage conserve son espace couleur et son alpha. Aucun
        // aller-retour PNG/JPEG ni conversion manuelle des stops.
        guard let image = renderer.cgImage else { return nil }
        return UIImage(cgImage: image, scale: scale, orientation: .up)
    }

    func appliquer(chambre: Double, penche: Double) {
        let angle = CGFloat((16 * chambre - penche) * .pi / 180)
        let alpha = CGFloat(min(max(0.55 * chambre, 0), 1))
        if angleBase != angle {
            angleBase = angle
            orientation.transform = CGAffineTransform(rotationAngle: angle)
        }
        if alphaPression != alpha {
            alphaPression = alpha
            pression.alpha = alpha
        }
    }

    func respirer(dort: Bool, amplitude: Double,
                  periode: Double, pose: Double?) {
        demande = Respiration(dort: dort, amplitude: amplitude,
                              periode: periode, pose: pose)
        reconciler()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reconciler()
    }

    private func reconciler() {
        guard var etat = demande else { return }
        etat.dort = etat.dort || window == nil || etat.pose != nil
        guard etat != effective else { return }
        effective = etat
        oscillation.layer.removeAnimation(forKey: Self.cleSouffle)
        UIView.performWithoutAnimation {
            oscillation.transform = CGAffineTransform(
                rotationAngle: CGFloat((etat.pose ?? 0) * .pi / 180))
        }
        guard !etat.dort, etat.periode > 0, etat.periode.isFinite,
              etat.amplitude.isFinite else { return }
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = -etat.amplitude * .pi / 180
        animation.toValue = etat.amplitude * .pi / 180
        animation.duration = etat.periode / 2
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(
            controlPoints: 0.42, 0, 0.58, 1)
        oscillation.layer.add(animation, forKey: Self.cleSouffle)
    }

    func arreter() {
        demande = nil
        effective = nil
        oscillation.layer.removeAnimation(forKey: Self.cleSouffle)
        orientation.layer.removeAllAnimations()
        pression.layer.removeAllAnimations()
    }

    func signalerEchec(_ action: @escaping () -> Void) {
        guard !echecSignale else { return }
        echecSignale = true
        arreter()
        print("[lisere] ImageRenderer indisponible : retour au témoin SwiftUI")
        // Ne pas modifier l'état SwiftUI pendant updateUIView.
        DispatchQueue.main.async(execute: action)
    }
}
