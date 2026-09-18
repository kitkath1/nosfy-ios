import SwiftUI

// MARK: - Banc de la flamme ember (`-emberLab`)

/// Le VENT, calculé UNE FOIS PAR FRAME côté CPU — jamais par pixel : ces
/// signaux sont identiques sur tout l'écran, les évaluer trois millions de
/// fois par image était le gaspillage qui cassait la fluidité.
/// Un bruit fractal du temps : apériodique, avec accalmies et rafales.
enum EmberWind {
    private static func hash1(_ n: Float) -> Float {
        let s = sin(n * 127.1 + 311.7) * 43758.5453
        return s - floor(s)
    }

    /// Bruit de valeur 1D lisse (mêmes crans que le `vnoise` du shader).
    private static func vnoise1(_ x: Float) -> Float {
        let i = floor(x), f = x - floor(x)
        let u = f * f * (3 - 2 * f)
        return hash1(i) * (1 - u) + hash1(i + 1) * u
    }

    /// fBm 3 octaves, ramené à ~[-1 ; 1] — le souffle.
    static func wind(_ t: Float) -> Float {
        let n = vnoise1(t * 0.28)
              + 0.55 * vnoise1(t * 0.83 + 53.1)
              + 0.30 * vnoise1(t * 2.10 + 71.3)
        return (n / 1.85 - 0.5) * 2
    }

    /// L'énergie turbulente du moment : 0 air calme, 1 bourrasque.
    static func gust(_ t: Float) -> Float {
        let n = (vnoise1(t * 0.13 + 91.7)
                 + 0.5 * vnoise1(t * 0.31 + 103.3)) / 1.5
        return smooth(n, 0.50, 0.78)
    }

    /// L'inspiration : apériodique, 8-14 s, jamais la même.
    static func inhale(_ t: Float) -> Float {
        let n = (vnoise1(t * 0.075 + 149.3)
                 + 0.5 * vnoise1(t * 0.190 + 163.7)) / 1.5
        let e = max(0, min(1, 1.5 * n - 0.35))
        return 0.060 * e * e
    }

    /// La lèche du cœur : la physique d'une bougie (dérive + rattrapés).
    static func lick(_ t: Float) -> Float {
        max(0, min(1, (vnoise1(t * 0.55 + 131.7)
                       + 0.5 * vnoise1(t * 1.40 + 139.1)) / 1.5))
    }

    /// Le glissement de laque : déclenché par les rafales, pas au métronome.
    static func sweep(_ t: Float) -> Float {
        (vnoise1(t * 0.045 + 173.3) + 0.5 * vnoise1(t * 0.110 + 181.9)) / 1.5
    }

    private static func smooth(_ x: Float, _ a: Float, _ b: Float) -> Float {
        let u = max(0, min(1, (x - a) / (b - a)))
        return u * u * (3 - 2 * u)
    }
}

/// Page noire pure plein écran : la flamme emoji 3D laquée, seule, dessinée
/// entièrement par le shader `emberFlame` (fond, souffle, corps, interne,
/// cœur, braises). `-emberFreeze` fige le temps à une pose flatteuse ;
/// `-emberFPS` loggue la cadence réelle toutes les deux secondes.
struct EmberFlameLab: View {
    private static let frozen = CommandLine.arguments.contains("-emberFreeze")
    private static let showFPS = CommandLine.arguments.contains("-emberFPS")
    /// La pose figée : les braises y scintillent à des phases variées.
    private static let freezeTime: Float = 4.2

    /// Le toucher : un tap sur la flamme fait JAILLIR des centaines de
    /// mini-braises depuis le point touché.
    @State private var tapPoint = CGPoint(x: -4096, y: -4096)
    @State private var tapDate = Date.distantPast
    /// La sonde de cadence (un chiffre, jamais une promesse).
    @State private var probe = FPSProbe()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if Self.frozen {
                flame(t: Self.freezeTime, now: Date())
            } else {
                TimelineView(.animation) { tl in   // plein 60 Hz, la danse est continue
                    let t = Float(tl.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 4096))
                    flame(t: t, now: tl.date)
                        .onChange(of: tl.date) { _, d in
                            if Self.showFPS { probe.tick(d) }
                        }
                }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    private func flame(t: Float, now: Date) -> some View {
        GeometryReader { geo in
            Rectangle()
                .fill(.black)   // JAMAIS .clear : le `* color.a` final avale tout
                .colorEffect(ShaderLibrary.emberFlame(
                    .float2(geo.size),
                    .float(t),
                    .float2(tapPoint),
                    .float(Float(min(now.timeIntervalSince(tapDate), 1e6))),
                    // Le vent, en éventail de retards : chaque étage de la
                    // flamme lit le MÊME souffle, décalé — une rafale la
                    // traverse de la pointe au sol.
                    .float4(EmberWind.wind(t),
                            EmberWind.wind(t - 0.12),
                            EmberWind.wind(t - 0.20),
                            EmberWind.wind(t - 0.35)),
                    .float4(EmberWind.wind(t - 0.45),
                            EmberWind.gust(t),
                            EmberWind.inhale(t),
                            EmberWind.lick(t)),
                    .float(EmberWind.sweep(t))))
                .onTapGesture(coordinateSpace: .local) { loc in
                    tapPoint = loc
                    tapDate = Date()
                }
        }
        .ignoresSafeArea()
    }
}

/// Compte les images rendues et imprime la cadence réelle — `-emberFPS`.
@Observable
final class FPSProbe {
    private var frames = 0
    private var window: Date?

    func tick(_ now: Date) {
        frames += 1
        guard let start = window else { window = now; return }
        let dt = now.timeIntervalSince(start)
        if dt >= 2 {
            print(String(format: "[emberFPS] %.1f img/s (%d en %.1f s)",
                         Double(frames) / dt, frames, dt))
            frames = 0
            window = now
        }
    }
}
