import AVFoundation
import CoreHaptics
import UIKit

// MARK: - Le grondement de la fusée
//
// `sensoryFeedback` ne sait faire que des CHOCS : un pic, puis plus rien. Un
// décollage, ce n'est pas une suite de chocs — c'est un GRONDEMENT CONTINU qui
// monte. Il faut donc descendre à CoreHaptics, seul endroit où l'on peut tenir
// une vibration et lui donner une courbe.
//
// La partition haptique double exactement la partition visuelle : un souffle
// à l'allumage, un grondement grave qui enfle pendant tout le travelling, la
// DÉTONATION au boom, puis la retombée et le petit choc de la pose. Les quatre
// virages de la courbe posent par-dessus leurs accents secs.
//
// Deux voies séparées, et c'est ce qui fait la puissance : un `continuous` de
// basse fréquence (sharpness 0,05-0,25) porte la MASSE, des `transient` posent
// les ACCENTS. Un grondement seul est mou ; des chocs seuls sont maigres.
//
// Le simulateur n'a pas de moteur haptique : tout ceci est silencieux là-bas,
// et ne se juge qu'à la main, sur un vrai appareil.
@MainActor
final class RocketHaptics {
    static let shared = RocketHaptics()

    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?

    private init() {}

    /// Prépare le moteur. À appeler à l'apparition du splash : démarrer un
    /// moteur CoreHaptics coûte quelques dizaines de millisecondes, et on ne
    /// veut pas les payer sur la première image.
    func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              engine == nil else { return }
        engine = try? CHHapticEngine()
        // Le moteur s'arrête tout seul quand l'app passe en fond ; on le
        // laisse repartir à la demande plutôt que de le tenir éveillé.
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        engine?.stoppedHandler = { _ in }
        try? engine?.start()
    }

    /// Joue tout le décollage, d'un bloc. Le motif porte ses propres courbes :
    /// une fois lancé, il tient l'horloge du moteur haptique et ne dépend plus
    /// des aléas de la boucle d'affichage — c'est la seule façon d'avoir une
    /// vibration RÉGULIÈRE pendant qu'un shader coûteux occupe le GPU.
    func launch(ignite: Double, travel: Double, boom: Double, coda: Double,
                heartbeat: Double, relight: Double,
                beats: [(time: Double, hard: Bool)],
                struggles: [Double] = []) {
        guard let engine else { return }
        let tBoom = ignite + travel
        let tFlight = tBoom + boom
        let flight = coda

        var events: [CHHapticEvent] = []

        // ---- Le grondement : une seule tenue, du premier souffle à la pose.
        // Son intensité est une COURBE, c'est là que vit la montée en régime.
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.12),
                // Grave : un moteur, pas une sonnette.
                .init(parameterID: .hapticSharpness, value: 0.05),
            ],
            relativeTime: 0,
            duration: tFlight + flight))

        // ---- La détonation. Un transient seul « claque » mais ne pèse rien :
        // on l'épaule d'une courte tenue à pleine intensité.
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.75),
            ],
            relativeTime: tBoom))
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.30),
            ],
            relativeTime: tBoom,
            duration: 0.42))

        // ---- Les quatre virages de la courbe : des accents secs sur le
        // grondement, fermes dans les cornes, effleurés dans les crochets.
        for beat in beats {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity,
                          value: beat.hard ? 0.55 : 0.28),
                    .init(parameterID: .hapticSharpness,
                          value: beat.hard ? 0.65 : 0.40),
                ],
                relativeTime: beat.time))
        }

        // ---- LA LUTTE : deux secousses sourdes quand le néon chute — la
        // main sent la lune se débattre avant de céder.
        for st in struggles {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.42),
                    .init(parameterID: .hapticSharpness, value: 0.12),
                ],
                relativeTime: st))
        }

        // ---- LE BATTEMENT, au cœur du noir de l'éclipse : un coup sourd et
        // grave, comme un cœur — pas un choc. C'est le seul événement du
        // silence, il doit peser.
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.85),
                .init(parameterID: .hapticSharpness, value: 0.08),
            ],
            relativeTime: heartbeat))
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.45),
                .init(parameterID: .hapticSharpness, value: 0.05),
            ],
            relativeTime: heartbeat,
            duration: 0.28))

        // ---- La caresse, quand la lune se rallume sur la page.
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.30),
                .init(parameterID: .hapticSharpness, value: 0.30),
            ],
            relativeTime: relight))

        // ---- LA MONTÉE EN RÉGIME. C'est cette courbe, et rien d'autre, qui
        // fait « fusée » : le grondement part à peine perceptible, enfle
        // lentement pendant tout le voyage, sature à la détonation, puis
        // retombe pendant que l'objet se pose.
        let ramp = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.15),
                .init(relativeTime: ignite, value: 0.45),
                .init(relativeTime: ignite + travel * 0.45, value: 1.10),
                .init(relativeTime: tBoom - 0.25, value: 2.20),
                .init(relativeTime: tBoom, value: 4.00),
                .init(relativeTime: tBoom + 0.55, value: 1.30),
                // La nuit : le grondement redescend en murmure pendant que la
                // pierre fond, s'éteint tout à fait juste avant le battement —
                // le noir doit être aussi SILENCIEUX à la main qu'à l'œil —
                // et ne revient plus : le rideau se lève sans un bruit.
                .init(relativeTime: tFlight, value: 0.40),
                .init(relativeTime: heartbeat - 0.30, value: 0.12),
                .init(relativeTime: heartbeat - 0.05, value: 0.0),
                .init(relativeTime: tFlight + flight, value: 0.0),
            ],
            relativeTime: 0)

        // La fréquence monte avec le régime : un moteur qui accélère.
        let pitch = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl,
            controlPoints: [
                .init(relativeTime: 0, value: -0.35),
                .init(relativeTime: tBoom - 0.4, value: 0.15),
                .init(relativeTime: tBoom, value: 0.55),
                .init(relativeTime: tFlight, value: -0.10),
            ],
            relativeTime: 0)

        guard let pattern = try? CHHapticPattern(events: events,
                                                 parameterCurves: [ramp, pitch]),
              let p = try? engine.makePlayer(with: pattern) else { return }
        player = p
        try? engine.start()
        try? p.start(atTime: CHHapticTimeImmediate)
    }

    /// LA PAUSE DU SOMMET (lentille liquide) : une fusée sur le point de
    /// décoller. Le grondement part à peine perceptible, la montée en régime
    /// ACCÉLÈRE — les crans se resserrent vers la fin — et la détonation
    /// sèche tombe à l'instant exact de la coupe. Suivent LE TOUCHER DE LA
    /// GOUTTE (l'atterrissage, léger et précis) et, après le silence du
    /// repli, L'ANNONCE : un battement grave qui pèse — l'école du cœur du
    /// splash. Muet au simulateur.
    func surge(rise: Double, contact: Double, beat: Double,
               ticks: [Double] = []) {
        guard let engine else { return }
        var events: [CHHapticEvent] = [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 1.0),
                    .init(parameterID: .hapticSharpness, value: 0.14),
                ],
                relativeTime: 0, duration: rise + 0.05),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 1.0),
                    .init(parameterID: .hapticSharpness, value: 0.70),
                ],
                relativeTime: rise),
            // Le toucher de la goutte.
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.50),
                    .init(parameterID: .hapticSharpness, value: 0.42),
                ],
                relativeTime: contact),
            // L'annonce : un coup sourd et grave, épaulé d'une courte
            // tenue — un cœur, pas un choc.
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.85),
                    .init(parameterID: .hapticSharpness, value: 0.08),
                ],
                relativeTime: beat),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.45),
                    .init(parameterID: .hapticSharpness, value: 0.05),
                ],
                relativeTime: beat, duration: 0.28),
        ]
        // LA SECOUSSE : par-dessus le grondement continu (qui sature à
        // 1,0), une rafale de transitoires qui s'ACCÉLÈRE — c'est elle
        // qui fait « très fort » : la fusée secoue, elle ne ronronne pas.
        var tk = 0.0
        var step = 0.11
        while tk < rise {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity,
                          value: Float(0.70 + 0.30 * tk / max(rise, 0.1))),
                    .init(parameterID: .hapticSharpness, value: 0.45),
                ],
                relativeTime: tk))
            tk += step
            step = max(step * 0.86, 0.035)
        }
        // Les PERLES de la dévidée : tick… tick… tick, en crescendo —
        // l'horlogerie d'un bijou qu'on remonte.
        for (i, tk) in ticks.enumerated() {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity,
                          value: 0.24 + 0.07 * Float(i)),
                    .init(parameterID: .hapticSharpness, value: 0.55),
                ],
                relativeTime: tk))
        }
        let ramp = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                // TRÈS FORTE dès que la pastille est en haut : la fusée
                // gronde à pleine charge sur toute la pause tenue.
                .init(relativeTime: 0, value: 0.85),
                .init(relativeTime: rise * 0.30, value: 1.60),
                .init(relativeTime: rise * 0.60, value: 2.10),
                .init(relativeTime: rise, value: 2.40),
                .init(relativeTime: rise + 0.05, value: 0.0),
                // La courbe REMONTE à 1 après la coupe — sans quoi elle
                // muselait le toucher de la goutte et le battement.
                .init(relativeTime: rise + 0.10, value: 1.0),
            ],
            relativeTime: 0)
        let pitch = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl,
            controlPoints: [
                .init(relativeTime: 0, value: -0.30),
                .init(relativeTime: rise * 0.80, value: 0.10),
                .init(relativeTime: rise, value: 0.50),
            ],
            relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: events,
                                                 parameterCurves: [ramp, pitch]),
              let p = try? engine.makePlayer(with: pattern) else { return }
        player = p
        try? engine.start()
        try? p.start(atTime: CHHapticTimeImmediate)
    }

    // MARK: Le grondement du drag — n'existe qu'au doigt, en crescendo.

    private var dragPlayer: CHHapticPatternPlayer?

    /// À chaque mouvement du drag, avec la montée [0,1] : le grondement
    /// naît au premier millimètre, enfle en crescendo (climb^1,6), reste
    /// doux — la fusée du sommet prend le relais. Muet au simulateur.
    func dragLevel(_ climb: Double) {
        guard let engine else { return }
        if dragPlayer == nil {
            let ev = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 1.0),
                    .init(parameterID: .hapticSharpness, value: 0.06),
                ],
                relativeTime: 0, duration: 60)
            guard let pattern = try? CHHapticPattern(events: [ev],
                                                     parameters: []),
                  let p = try? engine.makePlayer(with: pattern)
            else { return }
            dragPlayer = p
            try? engine.start()
            try? p.start(atTime: CHHapticTimeImmediate)
        }
        let level = Float(0.04 + 0.72 * pow(max(climb, 0), 1.6))
        try? dragPlayer?.sendParameters([
            CHHapticDynamicParameter(
                parameterID: .hapticIntensityControl,
                value: level, relativeTime: 0),
            CHHapticDynamicParameter(
                parameterID: .hapticSharpnessControl,
                value: Float(-0.2 + 0.35 * climb), relativeTime: 0),
        ], atTime: CHHapticTimeImmediate)
    }

    func dragEnd() {
        try? dragPlayer?.stop(atTime: CHHapticTimeImmediate)
        dragPlayer = nil
    }

    /// Le souffle sourd de la rafale — le tap sur le cadran.
    func tapFlare() {
        guard let engine else { return }
        let ev = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.55),
                .init(parameterID: .hapticSharpness, value: 0.30),
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.22),
                .init(parameterID: .hapticSharpness, value: 0.05),
            ], relativeTime: 0.01, duration: 0.16),
        ]
        guard let pattern = try? CHHapticPattern(events: ev,
                                                 parameters: []),
              let p = try? engine.makePlayer(with: pattern) else { return }
        try? engine.start()
        try? p.start(atTime: CHHapticTimeImmediate)
    }

    /// Coupe net — quand on passe le splash d'un toucher, le grondement ne
    /// doit pas continuer sous l'écran suivant.
    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        MoonTheme.shared.stop()
    }
}

// MARK: - Le thème lunaire
//
/// La musique du plan : un bourdon très grave qui enfle pendant tout le
/// voyage, des cloches inharmoniques posées sur les quatre accidents de la
/// courbe — aux instants EXACTS où la caméra les prend —, un souffle inversé
/// qui aspire pendant la seconde et demie qui précède la détonation, l'impact,
/// puis un pad qui s'ouvre pendant que l'objet se pose.
///
/// ELLE SUIT LA CAMÉRA, littéralement : la brillance du pad monte linéairement
/// sur toute la durée du travelling, exactement comme le plan recule. Un seul
/// geste, du son à l'image. La pièce est synthétisée hors ligne (le script vit
/// dans le scratchpad de la session) et embarquée en AAC — 188 Ko.
///
/// Mixée en `.ambient` + `mixWithOthers`, comme la paillette de l'aurore :
/// jamais par-dessus la musique de l'utilisatrice.
@MainActor
final class MoonTheme {
    static let shared = MoonTheme()
    private var player: AVAudioPlayer?

    private init() {}

    func prepare() {
        guard player == nil,
              let url = Bundle.main.url(forResource: "MoonSplashTheme",
                                        withExtension: "m4a") else { return }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.55
        player?.prepareToPlay()
    }

    func play() {
        guard let player else { return }
        player.currentTime = 0
        player.play()
    }

    /// Un fondu court plutôt qu'une coupure : passer le splash ne doit pas
    /// claquer.
    func stop() {
        guard let player, player.isPlaying else { return }
        player.setVolume(0, fadeDuration: 0.35)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak player] in
            player?.stop()
            player?.volume = 0.55
        }
    }
}

// MARK: - Le thème de la lentille
//
/// La pièce de la Transformation : sombre, sobre, élégante. Elle n'entre
/// qu'au SOMMET — quand la partition devient fixe (la montée au doigt reste
/// muette, portée par le grondement seul). Bourdon grave qui enfle vers la
/// coupe, souffle aspiré, impact feutré à la coupe, pad de nuit pendant la
/// descente, goutte cristalline à la pose, murmure qui monte avec la
/// condensation, cloche grave au battement — puis LE SILENCE : l'arrivée
/// n'a pas de boucle. Synthétisée hors ligne (script au scratchpad de la
/// session), embarquée en AAC.
/// Mixée en `.ambient` + `mixWithOthers` : jamais par-dessus sa musique.
@MainActor
final class LensTheme {
    static let shared = LensTheme()
    private var player: AVAudioPlayer?

    private init() {}

    func prepare() {
        guard player == nil,
              let url = Bundle.main.url(forResource: "LensTheme",
                                        withExtension: "m4a") else { return }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.50
        player?.prepareToPlay()
    }

    func play() {
        guard let player else { return }
        player.currentTime = 0
        player.volume = 0.50
        player.play()
    }

    func stop() {
        guard let player, player.isPlaying else { return }
        player.setVolume(0, fadeDuration: 0.35)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak player] in
            player?.stop()
            player?.volume = 0.50
        }
    }
}

// MARK: - Le tick de la rafale
//
/// DialTap — la langue sonore du cadran, hauteur qui varie d'un rien :
/// deux taps ne sonnent jamais exactement pareil.
@MainActor
final class LensChime {
    static let shared = LensChime()
    private var tap: AVAudioPlayer?

    private init() {}

    func prepare() {
        guard tap == nil,
              let url = Bundle.main.url(forResource: "DialTap",
                                        withExtension: "wav") else { return }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        tap = try? AVAudioPlayer(contentsOf: url)
        tap?.enableRate = true
        tap?.volume = 0.5
        tap?.prepareToPlay()
    }

    func flare() {
        guard let tap else { return }
        tap.rate = Float.random(in: 0.94 ... 1.06)
        tap.currentTime = 0
        tap.play()
    }
}
