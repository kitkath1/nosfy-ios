import AVFoundation
import CoreHaptics

// MARK: - La poussière de la carte-lune : le son et le souffle

/// Le shimmer de poussière magique du tap — TRÈS discret. Le son est
/// synthétisé (Media/PoussiereLune.wav, gen_shimmer.py) : une pluie de
/// micro-clochettes qui se disperse sur un souffle d'air, jamais une frappe.
/// Doctrine de la maison : session `.ambient` + `mixWithOthers` (jamais
/// par-dessus la musique de l'utilisatrice), volume bas, hauteur variée à
/// chaque lecture.
@MainActor
final class DustChime {
    static let shared = DustChime()

    /// Deux exemplaires en rotation : deux taps rapprochés se superposent
    /// au lieu de se tronquer.
    private var players: [AVAudioPlayer] = []
    private var next = 0

    private init() {}

    func prepare() {
        guard players.isEmpty,
              let url = Bundle.main.url(forResource: "PoussiereLune",
                                        withExtension: "wav") else { return }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        players = (0..<2).compactMap { _ in
            guard let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
            p.enableRate = true
            p.volume = 0.22
            p.prepareToPlay()
            return p
        }
    }

    func puff() {
        prepare()
        guard !players.isEmpty else { return }
        let p = players[next % players.count]
        next += 1
        // ±8 % : deux expirations ne sonnent jamais pareil.
        p.rate = Float.random(in: 0.92...1.08)
        p.currentTime = 0
        p.play()
    }
}

/// Les signatures haptiques de la carte : l'EXPIRATION du tap (un contact
/// net puis un souffle qui s'éteint — le doigt sent l'air partir, pas un
/// bouton), et l'ENTRÉE DE PLONGÉE (une nappe grave qui enfle : on passe
/// la vitre). Le pattern de DiveRumble, en miniature.
/// Muet au simulateur : ne se juge qu'à la main, sur l'iPhone.
@MainActor
final class LuneBreath {
    static let shared = LuneBreath()
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

    /// Le tap : l'expiration du contour.
    func exhale() {
        guard let engine else { return }
        let tap = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.48),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.30),
            ], relativeTime: 0)
        let souffle = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.42),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.10),
            ], relativeTime: 0.02, duration: 0.42)
        // Le souffle S'ÉTEINT : une nappe constante est un bourdonnement.
        let fall = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.02, value: 1.0),
                .init(relativeTime: 0.44, value: 0.0),
            ], relativeTime: 0)
        if let pattern = try? CHHapticPattern(events: [tap, souffle],
                                             parameterCurves: [fall]),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        }
    }

    /// L'entrée de plongée : l'appui reconnu (un grain net), puis la nappe
    /// grave qui ENFLE pendant toute la traversée, et un second seuil au
    /// moment où la vitre passe (~1,15 s — le cadre sort de l'écran). La
    /// main doit sentir qu'elle ENTRE quelque part, pas qu'un mode change.
    func dive() {
        guard let engine else { return }
        let prise = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
            ], relativeTime: 0)
        let nappe = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.06),
            ], relativeTime: 0.05, duration: 1.6)
        let swell = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.05, value: 0.0),
                .init(relativeTime: 1.10, value: 1.0),
                .init(relativeTime: 1.65, value: 0.0),
            ], relativeTime: 0)
        let vitre = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.62),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.30),
            ], relativeTime: 1.15)
        if let pattern = try? CHHapticPattern(events: [prise, nappe, vitre],
                                              parameterCurves: [swell]),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        }
    }
}
