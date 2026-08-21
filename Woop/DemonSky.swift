import SwiftUI
import CoreMotion

// MARK: - Parallaxe gyroscopique

/// Inclinaison lissée du téléphone, pour la parallaxe des couches du ciel.
///
/// Deux filtres en cascade :
///   - un passe-bas (~0,8 s) : le geste devient une dérive de caméra, jamais
///     un tremblement ;
///   - un recentrage très lent (~15 s) : c'est l'ÉCART à la tenue habituelle
///     qui compte, pas l'angle absolu — le téléphone tenu incliné dans un
///     canapé revient doucement au neutre au lieu de rester décalé.
///
/// Le simulateur n'a pas de gyroscope : l'inclinaison reste à zéro et le ciel
/// est simplement immobile — dégradation sans risque.
@Observable
final class SkyMotion {
    static let shared = SkyMotion()

    private let manager = CMMotionManager()
    private var baseline = CGVector.zero
    private(set) var tilt = CGVector.zero      // ±1 par axe, lissé
    /// LA SECOUSSE — l'accélération PROPRE du téléphone, gravité retirée.
    /// ⚠️ Elle n'a rien à voir avec `tilt` : une inclinaison est une POSITION
    /// (lissée fort, recentrée lentement), une secousse est une IMPULSION.
    /// Filtrée fort mais courte, elle retombe d'elle-même à zéro dès que la
    /// main s'immobilise — `userAcceleration` vaut 0 sur un téléphone posé.
    private(set) var shake = CGVector.zero     // ±1 par axe, en g

    func start(reduceMotion: Bool) {
        guard !reduceMotion, manager.isDeviceMotionAvailable,
              !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let a = motion?.attitude else { return }
            let raw = CGVector(dx: a.roll, dy: a.pitch)
            // Recentrage lent, puis écart borné à ±0.28 rad (≈16° suffisent
            // pour la pleine amplitude — le plongeon répond au geste doux),
            // puis lissage.
            baseline.dx += (raw.dx - baseline.dx) * 0.003
            baseline.dy += (raw.dy - baseline.dy) * 0.003
            let x = max(-1, min(1, (raw.dx - baseline.dx) / 0.22))
            let y = max(-1, min(1, (raw.dy - baseline.dy) / 0.22))
            tilt.dx += (x - tilt.dx) * 0.24
            tilt.dy += (y - tilt.dy) * 0.24
            // La secousse : attaque rapide (0,55) pour qu'un coup sec se
            // sente, et aucun recentrage — elle rentre seule.
            guard let ua = motion?.userAcceleration else { return }
            let sx = max(-1, min(1, CGFloat(ua.x) * 2.2))
            let sy = max(-1, min(1, CGFloat(-ua.y) * 2.2))
            shake.dx += (sx - shake.dx) * 0.55
            shake.dy += (sy - shake.dy) * 0.55
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        tilt = .zero
        shake = .zero
    }
}

// MARK: - État partagé du ciel

/// L'état que TOUTES les instances du ciel partagent — c'est lui qui garantit
/// qu'un changement d'onglet ne change rien : même scroll, même horloge de
/// révélation, même gyroscope (SkyMotion). Le temps, lui, est déjà global
/// (temps absolu modulo 900 s).
@Observable
final class SkyState {
    static let shared = SkyState()
    /// Décalage de scroll de la home. Les autres onglets le LISENT tel quel :
    /// le vecteur de parallaxe ne saute jamais à la bascule.
    var scroll: CGFloat = 0
    /// Début de la révélation : au lancement et au retour d'arrière-plan
    /// UNIQUEMENT — jamais au changement d'onglet.
    var revealStart: Date = .now
}

// MARK: - Ciel nébuleuse (vue)

/// Le fond galactique, en deux passes (voir DemonSky.metal) :
///   1. la nébuleuse, rendue en DEMI-résolution puis agrandie ×2 — vérifié :
///      le shader s'évalue bien sur le raster réduit (4× moins de fragments),
///      et l'upscale bilinéaire est invisible sur un contenu vaporeux ;
///   2. les étoiles, en pleine résolution (sub-pixel, l'upscale les tuerait),
///      composées en `plusLighter` : de la lumière ajoutée au ciel.
///
/// 30 images par seconde, pas plus : sans `minimumInterval`, TimelineView
/// suit ProMotion à 120 Hz — 4× le coût GPU et la dalle LTPO bloquée en haute
/// fréquence. La matière évolue sur des minutes, seul le scintillement a
/// besoin de fluidité, et 30 fps y suffisent.
struct WoopDemonSky: View {
    var paused: Bool = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var motion: SkyMotion { .shared }
    private var sky: SkyState { .shared }

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
                // Le temps part en float32 vers le GPU : modulo 900 s, sinon
                // la mantisse ne suit plus et les sinus avancent par paliers.
                // Toutes les animations du shader sont périodiques sur 900 s
                // exactement — le raccord de boucle est invisible.
                let t = Float(timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))

                // Révélation : 2 s de montée d'exposition au lancement et au
                // retour d'arrière-plan — l'horloge est PARTAGÉE : changer
                // d'onglet ne la rejoue jamais. Écrans figés : toujours à 1.
                let raw = paused ? 1.0 : min(max(
                    timeline.date.timeIntervalSince(sky.revealStart) / 2.0, 0), 1)
                let reveal = Float(raw * raw * (3 - 2 * raw))

                // Le scroll (partagé) s'injecte dans le même vecteur que le
                // gyroscope : chaque couche le démultiplie par sa profondeur.
                let tilt = CGVector(dx: motion.tilt.dx,
                                    dy: motion.tilt.dy + sky.scroll * 0.0009)

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(.black)
                        .frame(width: w / 2, height: h / 2)
                        .colorEffect(Self.dithered(ShaderLibrary.nebulaField(
                            .float2(w / 2, h / 2), .float(t), .float(reveal),
                            .float2(tilt.dx, tilt.dy),
                            .image(NebulaNoise.image))))
                        .scaleEffect(2, anchor: .topLeading)

                    Rectangle()
                        .fill(.black)
                        .frame(width: w, height: h)
                        .colorEffect(ShaderLibrary.nebulaStars(
                            .float2(w, h), .float(t), .float(reveal),
                            .float2(tilt.dx, tilt.dy),
                            .image(NebulaNoise.image)))
                        .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            // Pas de reset de révélation ici : l'apparition d'un onglet ne
            // doit RIEN changer au ciel.
            if !paused { motion.start(reduceMotion: reduceMotion) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                SkyState.shared.revealStart = .now
                if !paused { motion.start(reduceMotion: reduceMotion) }
            } else {
                motion.stop()
            }
        }
    }

    /// Dithering natif du shader : casse le banding 8 bits des longues rampes
    /// sombres du halo, quasi gratuit.
    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }
}
