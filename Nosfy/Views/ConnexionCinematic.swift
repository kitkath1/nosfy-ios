import CoreHaptics
import SwiftUI

// MARK: - La cinématique de la connexion : la lune se dissout en braises
//
// CONNEXION touché : quatre actes, un seul fil — la lumière du néon change
// trois fois d'état sans jamais mentir : tube → poussière → feu.
//
//   A. L'ASPIRATION (0 → 0,90). Le feu du bas draine vers la lune, la page se
//      déshabille, la caméra du shader s'approche d'un souffle.
//   B. L'APPROCHE (0,90 → 1,55). La caméra de `MonolithScene` — celle du
//      travelling du splash, rendue vectorielle par le shader, nette à tout
//      grossissement — pousse vers le croissant qui vient au centre pendant
//      que l'aurore s'éteint au vrai noir. Pas un scaleEffect : la V2
//      rastérisée était exactement le « cheap ».
//   C. LA DISSOLUTION ET L'APNÉE (1,45 → 2,55). Le tube s'effrite en
//      centaines de braises, du dos vers les pointes — la dissolution
//      VOYAGE le long de l'arc. Le nuage reste en apesanteur dans le noir ;
//      LA COUPE se cache là (2,10), derrière lui : il est le seul témoin de
//      continuité entre les deux pages. Dans la main : le silence.
//   D. L'AUBE (2,55 → 3,70). La gravité reprend les braises, elles retombent
//      en arcs à queues de comète — et la home s'allume LÀ OÙ elles se
//      posent : sa lumière naît avec la forme de la connexion (un fil de
//      crête au bord bas) puis se déploie vers sa propre forme. La barre
//      monte en ressort, le fil d'or frémit, le galet souffle son invite.
//
// La partition vit ici ; le shader `moonDust` (AuroraBg.metal) duplique
// sciemment quatre constantes de temps — les garder alignées.
enum ConnexionCine {
    static let aspiration: Double = 0.90
    /// L'approche de la caméra.
    static let pushStart: Double = 0.90
    static let pushEnd: Double = 1.55
    /// La dissolution s'amorce pendant la fin de l'approche.
    static let dissolve: Double = 1.45
    /// Le monolithe a fini de fondre — le nuage a pris le relais.
    static let moonGone: Double = 1.95
    /// LA COUPE : plein noir derrière le nuage suspendu.
    static let swapAt: Double = 2.10
    /// La gravité reprend le nuage, et l'aube part avec elle.
    static let fallAt: Double = 2.55
    /// La barre se lance à la chute, se pose ~0,5 s plus tard.
    static let barAt: Double = 2.55
    /// La bouffée du galet, sur la pose de la barre.
    static let breathAt: Double = 3.10
    static let end: Double = 3.70

    /// Le rayon de l'arc du tube en unités de SCÈNE (la face nominale vaut
    /// `MoonLanding.faceR` = 76). Calibré sur capture — c'est lui qui fait
    /// naître les braises SUR le tube et pas à côté.
    static let ringSceneR: Double = 44

    private static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// Le drainage du fond du login, 0 → 1.
    static func cineLevel(_ e: Double) -> Double { sstep(0, aspiration, e) }

    /// Le zoom de la caméra : un soupçon pendant l'aspiration (elle se
    /// penche), puis la poussée exponentielle, puis l'immobilité — la
    /// dissolution se regarde à caméra posée.
    static func camZoom(_ e: Double) -> Float {
        let lean = 0.70 * pow(0.82 / 0.70, sstep(0.10, aspiration, e))
        guard e > pushStart else { return Float(lean) }
        let u = sstep(pushStart, pushEnd, min(e, pushEnd))
        return Float(0.82 * pow(1.60 / 0.82, u))
    }

    /// Où la caméra amène le centre du croissant : de sa pose (le coin haut
    /// gauche) vers le regard (un cheveu au-dessus du centre de l'écran).
    static func camPoint(_ e: Double, in size: CGSize) -> CGPoint {
        let p0 = MoonLanding.spot(in: size)
        let p1 = CGPoint(x: size.width * 0.50, y: size.height * 0.40)
        let u = sstep(pushStart, pushEnd, min(e, pushEnd))
        return CGPoint(x: p0.x + (p1.x - p0.x) * u,
                       y: p0.y + (p1.y - p0.y) * u)
    }

    /// Le monolithe fond pendant que le balayage le remplace par les braises
    /// — l'arc encore allumé du shader `moonDust` couvre le raccord.
    static func moonAlpha(_ e: Double) -> Double {
        1 - sstep(dissolve + 0.10, moonGone, e)
    }

    /// L'aurore du login s'éteint au vrai noir pendant l'approche : plus
    /// aucun orange sombre à l'écran quand la dissolution commence.
    static func bgAlpha(_ e: Double) -> Double { 1 - sstep(1.00, 1.70, e) }

    /// L'aube de la home, lue par `AuroraFloor` : 0 tant que l'apnée dure,
    /// puis la naissance — et 1 pour toujours hors cérémonie.
    @MainActor
    static func birth(at date: Date) -> Double {
        guard let s = HomeWelcome.start else { return 1 }
        let dt = date.timeIntervalSince(s)
        if dt > 2.2 { return 1 }
        return sstep(fallAt - swapAt, 1.35, dt)
    }
}

/// L'horloge de la coupe, posée par la racine et lue par le fond de la home —
/// trop profond dans l'arbre pour un binding (même précédent que `SkyState`).
@MainActor
enum HomeWelcome {
    static var start: Date?
}

// MARK: - La lune qui plonge

/// Le monolithe de la page de connexion, caméra en main. Au repos (`start`
/// nul) c'est pixel pour pixel `LandedMonolithView` ; en cérémonie, la caméra
/// du SHADER pousse vers le croissant — le rendu reste vectoriel, net à tout
/// grossissement, verre et frange chromatique compris.
struct CineMonolith: View {
    var start: Date?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: start == nil)) { tl in
                let e = start.map { tl.date.timeIntervalSince($0) } ?? 0
                let z = ConnexionCine.camZoom(e)
                let aim = MoonLanding.cameraTarget(
                    bringing: ConnexionCine.camPoint(e, in: size),
                    at: z, in: size)
                MonolithScene(faceR: MoonLanding.faceR,
                              camera: SIMD3(aim.x, aim.y, z),
                              cineCtl: SIMD4(0, 0, 1, -1),
                              edgeFade: 1,
                              revealOverride: 1,
                              hitArea: MoonLanding.hitRect(in: size),
                              idleLife: 1)
                    .opacity(ConnexionCine.moonAlpha(e))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Le nuage de braises

/// L'hôte de `moonDust` : les centaines de braises de la dissolution. Posé
/// au-dessus de TOUT dans la racine — la page change dessous pendant l'apnée
/// et le nuage ne bronche pas d'un pixel. Il avale aussi le doigt le temps
/// de la cérémonie.
struct MoonDustOverlay: View {
    let start: Date
    @StateObject private var tilt = BgTilt()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                let e = tl.date.timeIntervalSince(start)
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                // Le nuage vit là où la caméra a laissé le croissant — les
                // fonctions sont figées après la poussée, la disparition du
                // monolithe ne le déplace pas.
                let q = ConnexionCine.camPoint(e, in: size)
                let r = ConnexionCine.ringSceneR
                    * Double(ConnexionCine.camZoom(min(e, ConnexionCine.moonGone)))
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.moonDust(
                        .float2(size.width, size.height), .float(t),
                        .float(Float(e)),
                        .float3(Float(q.x), Float(q.y), Float(r)),
                        .float2(Float(tilt.value.x), Float(tilt.value.y))))
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
    }
}

// MARK: - Le grondement

/// La partition haptique, lancée D'UN BLOC au tap : le motif tient l'horloge
/// du moteur haptique, insensible aux frames que les shaders coûteront.
///
///   0,00        le tap
///   0,15→0,90   l'accelerando — des grains dont la cadence se resserre
///   0,90→1,55   la poussée — la masse enfle avec la caméra
///   1,55→2,05   l'ÉMIETTEMENT — le grondement se défait en grains épars,
///               comme le tube en braises : la main sent la dissolution
///   2,05→2,55   le SILENCE — l'apnée. L'absence est le geste le plus
///               premium de la séquence.
///   2,55→3,45   l'aube — une nappe chaude et grave qui enfle et retombe,
///               le tic de la barre qui se pose, le souffle du galet
///
/// Muet au simulateur : ne se juge qu'à la main, sur l'iPhone.
@MainActor
final class DiveRumble {
    static let shared = DiveRumble()
    private var engine: CHHapticEngine?
    private init() {}

    func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              engine == nil else { return }
        engine = try? CHHapticEngine()
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        engine?.stoppedHandler = { _ in }
        try? engine?.start()
    }

    func play() {
        guard let engine else { return }
        var events: [CHHapticEvent] = []

        func transient(_ time: Double, _ intensity: Float, _ sharpness: Float) {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity,
                                           value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness,
                                           value: sharpness),
                ],
                relativeTime: time))
        }

        // Le tap.
        transient(0.0, 0.40, 0.20)

        // L'accelerando.
        var tg = 0.15
        while tg < ConnexionCine.aspiration {
            let u = Float((tg - 0.15) / (ConnexionCine.aspiration - 0.15))
            transient(tg, 0.15 + 0.25 * u, 0.10)
            tg += 0.14 - 0.08 * Double(u)
        }

        // La poussée : la masse continue, modelée par la courbe globale.
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.28),
            ],
            relativeTime: ConnexionCine.pushStart,
            duration: ConnexionCine.dissolve + 0.15 - ConnexionCine.pushStart))

        // L'émiettement : des grains épars qui S'ESPACENT — l'inverse exact
        // de l'accelerando, la matière qui se défait.
        var te = ConnexionCine.dissolve + 0.10
        var step = 0.055
        while te < ConnexionCine.swapAt - 0.05 {
            let u = Float((te - ConnexionCine.dissolve)
                          / (ConnexionCine.swapAt - ConnexionCine.dissolve))
            transient(te, 0.34 * (1.0 - 0.6 * u), 0.30)
            step *= 1.35
            te += step
        }

        // L'aube : la nappe chaude — grave (sharpness négatif via la courbe),
        // elle enfle avec la lumière et se pose avec la barre.
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15),
            ],
            relativeTime: ConnexionCine.fallAt,
            duration: 3.45 - ConnexionCine.fallAt))
        transient(3.02, 0.62, 0.12)                       // la barre se pose
        transient(ConnexionCine.breathAt + 0.05, 0.40, 0.10)  // le galet souffle

        // Les courbes globales : plates pendant l'accelerando, puis ce sont
        // elles qui font la poussée, l'extinction, le silence et l'aube.
        let intensity = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.0, value: 1.0),
                .init(relativeTime: 0.89, value: 1.0),
                .init(relativeTime: ConnexionCine.pushStart, value: 0.25),
                .init(relativeTime: ConnexionCine.pushEnd, value: 0.72),
                .init(relativeTime: ConnexionCine.swapAt, value: 0.30),
                .init(relativeTime: ConnexionCine.fallAt, value: 0.0),
                .init(relativeTime: 3.00, value: 0.48),
                .init(relativeTime: 3.45, value: 0.0),
            ],
            relativeTime: 0)
        let sharpness = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl,
            controlPoints: [
                .init(relativeTime: 0.0, value: 0.0),
                .init(relativeTime: ConnexionCine.pushEnd, value: 0.10),
                .init(relativeTime: ConnexionCine.fallAt, value: -0.25),
                .init(relativeTime: 3.45, value: -0.25),
            ],
            relativeTime: 0)

        if let pattern = try? CHHapticPattern(events: events,
                                              parameterCurves: [intensity, sharpness]),
           let player = try? engine.makePlayer(with: pattern) {
            try? engine.start()
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }
}
