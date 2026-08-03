import CoreHaptics
import SwiftUI

// MARK: - La cinématique de la connexion : la plongée dans la lune
//
// CONNEXION touché : trois temps, un seul sujet — la lune du monolithe, le
// logo, l'objet dont la home tire littéralement sa couleur (BG_JAUNE, « le
// jaune du néon de la lune »).
//
//   A. L'ASPIRATION (0 → 0,85 s). Les halos de la page remontent vers la lune
//      et le feu du bas s'éteint en proportion (drainage — jamais de fusion à
//      mi-écran : une nappe à luminance moyenne, c'est le marron). La page se
//      déshabille : textes, input, bouton fondent. La lune s'engorge.
//   B. LA PLONGÉE (0,85 → 1,75 s). Zoom massif ancré sur la lune (1 → 8,
//      courbe de chute), flou et bloom montent AVANT que la trame du zoom ne
//      se voie, stries radiales, puis flash blanc-or. La transition passe par
//      le HAUT de la luminance : le marron est géométriquement impossible, et
//      la coupe se cache dans le blanc — pas dans le noir.
//   C. L'ARRIVÉE (1,75 → 2,7 s). La home est déjà là, un peu trop près
//      (1,28), et se pose en reculant. Sa crête accueille (+welcome), la
//      barre bijou monte en ressort, le galet souffle UNE bouffée d'invite.
//
// La partition vit ici, en constantes nommées : le shader (`diveLight`), le
// grondement (DiveRumble) et la racine (WoopApp) lisent la même horloge.
enum ConnexionCine {
    /// L'aspiration : la montée de `cine` dans le champ du fond.
    static let aspiration: Double = 0.85
    /// La plongée part à la fin de l'aspiration…
    static let diveStart: Double = 0.85
    static let dive: Double = 0.90
    /// …le flash attaque un souffle avant le sommet…
    static let flashStart: Double = 1.60
    /// …et culmine ici : LA COUPE. La page change sous le blanc plein.
    static let swapAt: Double = 1.75
    /// La barre bijou se pose ~0,6 s après la coupe ; le galet souffle alors.
    static let barLanding: Double = 0.60
    static let end: Double = 2.70

    /// L'abscisse et l'ordonnée de la lune, en fractions d'écran — celles de
    /// `MoonLanding.spot`, la pose du monolithe sur la page de connexion.
    static func anchor(in size: CGSize) -> UnitPoint {
        let p = MoonLanding.spot(in: size)
        return UnitPoint(x: p.x / max(size.width, 1), y: p.y / max(size.height, 1))
    }

    private static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// Le drainage du fond, 0 → 1.
    static func cineLevel(_ e: Double) -> Double { sstep(0, aspiration, e) }

    /// La progression de la plongée, 0 → 1.
    static func diveU(_ e: Double) -> Double {
        min(max((e - diveStart) / dive, 0), 1)
    }

    /// L'échelle de la caméra : 8^(u^1,8) — départ presque immobile, fin
    /// violente. Le profil d'une chute, pas d'un zoom au métronome.
    static func scale(_ e: Double) -> Double { pow(8.0, pow(diveU(e), 1.8)) }

    /// Le flou couvre la page AVANT que l'échelle ne dépasse ~3 (u ≈ 0,5),
    /// là où la trame du `scaleEffect` commencerait à se voir.
    static func blur(_ e: Double) -> Double { 14 * sstep(0.35, 1.0, diveU(e)) }

    /// Le voile de la coupe : attaque en 0,15 s, relâche en exp(−t/0,22).
    static func flash(_ e: Double) -> Double {
        if e <= swapAt { return sstep(flashStart, swapAt, e) }
        return exp(-(e - swapAt) / 0.22)
    }

    /// L'accueil de la home : plein à la coupe, éteint en ~0,9 s.
    @MainActor
    static func welcome(at date: Date) -> Double {
        guard let s = HomeWelcome.start else { return 0 }
        let dt = date.timeIntervalSince(s)
        if dt < 0 || dt > 1.6 { return 0 }
        return exp(-dt / 0.30)
    }
}

/// L'horloge de l'accueil, posée par la racine à l'instant de la coupe et lue
/// par `AuroraFloor` — le fond de la home est trop profond dans l'arbre pour
/// qu'un binding le traverse proprement (même précédent que `SkyState`).
@MainActor
enum HomeWelcome {
    static var start: Date?
}

// MARK: - La caméra

/// Le conteneur qui plonge : la page de connexion entière, zoomée vers la
/// lune et floutée. Les couches qui vendent la vitesse (bloom, stries, flash)
/// ne sont PAS ici — elles vivent en coordonnées écran dans
/// `DiveLightOverlay`, au-dessus, et restent nettes pendant que la page se
/// pixellise sous elles.
struct DivingContainer<Content: View>: View {
    var start: Date?
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            let anchor = ConnexionCine.anchor(in: geo.size)
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: start == nil)) { tl in
                let e = start.map { tl.date.timeIntervalSince($0) } ?? 0
                content
                    .scaleEffect(ConnexionCine.scale(e), anchor: anchor)
                    .blur(radius: ConnexionCine.blur(e))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - La lumière

/// L'hôte du shader `diveLight` : bloom du tube, stries, flash — en fondu
/// écran, au-dessus de TOUT (il couvre la coupe, c'est sa raison d'être).
/// Il avale aussi le doigt : on ne tape pas sur un écran en pleine cérémonie.
struct DiveLightOverlay: View {
    let start: Date

    var body: some View {
        GeometryReader { geo in
            let c = MoonLanding.spot(in: geo.size)
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                let e = tl.date.timeIntervalSince(start)
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.diveLight(
                        .float2(geo.size.width, geo.size.height), .float(t),
                        .float2(Float(c.x), Float(c.y)),
                        .float(Float(ConnexionCine.diveU(e))),
                        .float(Float(ConnexionCine.flash(e)))))
                    .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
    }
}

/// La surge de l'aspiration : pendant que la page se vide, la lune est le
/// seul objet qui GAGNE de la lumière — un halo d'or qui enfle sur place,
/// en fondu écran, aux couleurs du tube. L'œil est déjà sur elle quand la
/// caméra part.
struct MoonSurge: View {
    let start: Date

    var body: some View {
        GeometryReader { geo in
            let p = MoonLanding.spot(in: geo.size)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let cine = ConnexionCine.cineLevel(tl.date.timeIntervalSince(start))
                Rectangle()
                    .fill(RadialGradient(
                        stops: [
                            .init(color: Color(red: 1.00, green: 0.93, blue: 0.82)
                                .opacity(0.50 * cine), location: 0),
                            .init(color: Color(red: 1.00, green: 0.78, blue: 0.34)
                                .opacity(0.30 * cine), location: 0.38),
                            .init(color: .clear, location: 1),
                        ],
                        center: UnitPoint(x: p.x / max(geo.size.width, 1),
                                          y: p.y / max(geo.size.height, 1)),
                        startRadius: 8,
                        endRadius: 70 + 110 * cine))
                    .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Le grondement

/// La partition haptique de la plongée, lancée D'UN BLOC à t = 0 : le motif
/// tient l'horloge du moteur haptique et ne dépend pas des frames que deux
/// shaders plein écran vont coûter. Grammaire de la fusée : un `continuous`
/// grave porte la masse, des `transient` posent les accents.
///
///   0,00        le tap
///   0,15→0,85   l'accelerando : des grains dont la cadence se resserre
///               (140 → 60 ms) — la main sent que quelque chose s'amasse
///   0,85→1,75   le doppler : intensité ET sharpness montent ensemble
///   1,75        le passage — fort mais rond
///   1,95 / 2,35 / 2,60   la retombée scintillante, calée sur le flash qui
///               relâche, la pose de la barre, le souffle du galet
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

        // L'accelerando : cadence 140 → 60 ms, intensité 0,15 → 0,40.
        var tGrain = 0.15
        while tGrain < ConnexionCine.aspiration {
            let u = Float((tGrain - 0.15) / (ConnexionCine.aspiration - 0.15))
            transient(tGrain, 0.15 + 0.25 * u, 0.10)
            tGrain += 0.14 - 0.08 * Double(u)
        }

        // Le doppler : la masse continue, modelée par les courbes plus bas.
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.30),
            ],
            relativeTime: ConnexionCine.diveStart,
            duration: 2.30 - ConnexionCine.diveStart))

        // Le passage, puis la retombée. Les valeurs des trois dernières sont
        // relevées : la courbe d'intensité les atténue en proportion — c'est
        // le produit des deux qui doit donner 0,35 / 0,30 / 0,18.
        transient(ConnexionCine.swapAt, 1.00, 0.35)
        transient(1.95, 0.60, 0.15)
        transient(ConnexionCine.swapAt + ConnexionCine.barLanding, 0.65, 0.12)
        transient(2.60, 0.45, 0.10)

        // Les courbes sont GLOBALES (elles modulent tout le motif) : plates à
        // 1,0 pendant l'accelerando pour laisser les grains à leur valeur,
        // puis c'est elles qui font le doppler et la retombée.
        let intensity = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.0, value: 1.0),
                .init(relativeTime: 0.84, value: 1.0),
                .init(relativeTime: ConnexionCine.diveStart, value: 0.25),
                .init(relativeTime: ConnexionCine.swapAt, value: 0.95),
                .init(relativeTime: 1.95, value: 0.60),
                .init(relativeTime: 2.35, value: 0.45),
                .init(relativeTime: 2.70, value: 0.0),
            ],
            relativeTime: 0)
        let sharpness = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl,
            controlPoints: [
                .init(relativeTime: 0.0, value: 0.0),
                .init(relativeTime: ConnexionCine.diveStart, value: -0.20),
                .init(relativeTime: ConnexionCine.swapAt, value: 0.15),
                .init(relativeTime: 2.10, value: -0.15),
                .init(relativeTime: 2.70, value: -0.20),
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
