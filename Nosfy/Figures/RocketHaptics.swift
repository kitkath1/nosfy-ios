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
        engine?.playsHapticsOnly = true
        engine?.isAutoShutdownEnabled = true
        // Le moteur s'arrête tout seul quand l'app passe en fond ; on le
        // laisse repartir à la demande plutôt que de le tenir éveillé.
        engine?.resetHandler = {}
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

    /// LES PALIERS DE LA LUNE DE SANG (la porte, 22-08) : un battement par
    /// moment — le coup sourd et grave du cœur du splash, envoyé D'UN BLOC au
    /// moteur (jamais image par image : une vibration cadencée par la boucle
    /// d'affichage tremble précisément quand le GPU peine). `fort` = le choc
    /// de la POSE, quand la plongée s'arrête : plein poids, un peu plus sec.
    /// Muet au simulateur.
    func paliers(_ battements: [(time: Double, fort: Bool)]) {
        guard let engine else { return }
        var events: [CHHapticEvent] = []
        for b in battements {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity,
                          value: b.fort ? 1.0 : 0.85),
                    .init(parameterID: .hapticSharpness,
                          value: b.fort ? 0.30 : 0.08),
                ],
                relativeTime: b.time))
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity,
                          value: b.fort ? 0.70 : 0.45),
                    .init(parameterID: .hapticSharpness, value: 0.05),
                ],
                relativeTime: b.time, duration: b.fort ? 0.36 : 0.28))
        }
        guard let pattern = try? CHHapticPattern(events: events,
                                                 parameterCurves: []),
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
    /// ⚠️ `theme: false` ARRÊTE L'HAPTIQUE SEULE. Par défaut cette méthode
    /// coupe aussi la musique — un couplage juste tant que les deux finissent
    /// ensemble. Ils ne finissent plus ensemble : le thème de la Lune de Sang
    /// dure 5,506 s pour un plan de 4,45, et sa dernière seconde ring out
    /// EXPRÈS dans la couture noire. À la fin naturelle, le motif haptique est
    /// déjà terminé de lui-même et il n'y a rien à couper — mais un `stop()`
    /// nu emporterait la queue du thème avec lui.
    func stop(theme: Bool = true) {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        dragEnd()
        engine?.stop { erreur in
            DispatchQueue.main.async {
                NavDiagnostic.noter("haptique-story-arrete",
                    destination: erreur == nil ? "ok" : "erreur")
            }
        }
        if theme { MoonTheme.shared.stop() }
    }

    /// LE SOUFFLE — « RIEN N'EST FRAPPÉ, TOUT RESPIRE ».
    ///
    /// Verdict 26-08 : « l'haptique horrible ». `paliers` tire **trois impacts
    /// transitoires** (intensité 1,0 / 0,85 / 0,85, netteté 0,30) calés pile
    /// sur les trois états — l'haptique SOULIGNAIT donc les marches que tout
    /// le reste du chantier s'emploie à fondre. Trois coups frappés en 4,45 s
    /// sur une scène qui doit être « comme un film, doux, mélodieux ».
    ///
    /// Ici : **aucun transitoire**. Un seul événement continu qui couvre tout
    /// le plan, dont l'intensité suit une courbe de contrôle — elle monte avec
    /// la plongée, culmine à la pose sans jamais claquer, s'infléchit sur
    /// chaque état, et meurt avec l'extinction. La main sent la lumière.
    ///
    /// ⚠️ Muet au simulateur : ça se juge sur l'appareil, uniquement.
    func respire(duree: Double, points: [(t: Double, force: Float)],
                 nettete: Float = 0.05) {
        guard let engine, points.count >= 2 else { return }
        let ev = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: nettete),
            ],
            relativeTime: 0, duration: duree)
        let courbe = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: points.map {
                .init(relativeTime: $0.t, value: $0.force)
            },
            relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [ev],
                                                 parameterCurves: [courbe]),
              let p = try? engine.makePlayer(with: pattern) else { return }
        player = p
        try? engine.start()
        try? p.start(atTime: CHHapticTimeImmediate)
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

    /// La piste chargée — deux splashs, deux montages du MÊME matériau.
    ///
    /// ⚠️ **`LuneSangTheme` EST UN RECUT, PAS UN AUTRE MORCEAU** : le thème
    /// d'origine dure 15,556 s et son impact tombe à 6,300 — il a été composé
    /// pour le plan-séquence de 13,95 s. La Lune de Sang fait 4,45 s et sa
    /// pose est à 1,30. Joué tel quel, le son commenterait une image partie
    /// depuis cinq secondes. `tools/porte/recuit_theme.sh` recale l'impact au
    /// centième et pose le geste final sur l'extinction.
    private var piste: String?

    func prepare(_ nom: String = "MoonSplashTheme") {
        guard piste != nom,
              let url = Bundle.main.url(forResource: nom,
                                        withExtension: "m4a") else { return }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.55
        player?.prepareToPlay()
        piste = nom
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

// MARK: - La poussière sonore du drag
//
/// PAILLETTE — le grain de lumière sonore du geste : quand le doigt porte
/// la bulle, du cristal minuscule s'égrène derrière elle. Ce n'est pas un
/// effet de bouton (un son par appui) mais une TEXTURE : elle se sème à la
/// DISTANCE PARCOURUE, jamais au temps — un doigt qui s'arrête se tait, un
/// doigt qui file laisse une traînée. Chaque grain sort à une hauteur et à
/// un volume différents (deux paillettes ne sonnent jamais pareil), et
/// l'ensemble reste sous le seuil de l'attention : on le sent, on ne
/// l'écoute pas.
///
/// Un POOL de lecteurs : les grains se chevauchent : rejouer un seul
/// `AVAudioPlayer` le couperait net à chaque nouveau grain — le hachage
/// qui trahit l'échantillon. `.ambient` : le mode silencieux est respecté,
/// et la musique de l'utilisateur continue.
@MainActor
final class Paillettes {
    static let shared = Paillettes()

    private var pool: [AVAudioPlayer] = []
    private var next = 0
    private var lastAt: TimeInterval = 0
    /// La distance qu'il reste à parcourir avant le prochain grain.
    private var toNext: CGFloat = 0

    private init() {}

    func prepare() {
        guard pool.isEmpty,
              let url = Bundle.main.url(forResource: "Paillette",
                                        withExtension: "wav") else { return }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<6 {
            guard let p = try? AVAudioPlayer(contentsOf: url) else { continue }
            p.enableRate = true
            p.volume = 0
            p.prepareToPlay()
            pool.append(p)
        }
        toNext = Self.stride()
    }

    /// Le doigt a parcouru `distance` points depuis le dernier appel.
    /// `level` ∈ [0,1] : la montée — plus haut, plus clair et plus dense.
    func travel(_ distance: CGFloat, level: Double) {
        guard !pool.isEmpty, distance > 0 else { return }
        toNext -= distance
        guard toNext <= 0 else { return }
        toNext = Self.stride() * (1.0 - 0.35 * CGFloat(min(max(level, 0), 1)))
        grain(level: level)
    }

    /// Le geste s'achève : la traînée s'arrête, mais on ne coupe rien —
    /// les grains en vol finissent de s'éteindre.
    func end() { toNext = Self.stride() }

    // MARK: L'annonce des chiffres

    /// LA PAILLETTE D'ANNONCE — trois grains en arpège montant, à
    /// l'instant où les chiffres affleurent sur le cadran. Elle remplace
    /// le battement grave du thème (un DONG de 1,5 s de traîne, mesuré à
    /// 76 % sous 150 Hz, retiré du fichier) : l'annonce se fait par la
    /// même matière que la poussière du geste, en plus haut et en plus
    /// bref. Déclenchée par le code, donc collée aux chiffres à la frame
    /// près, quoi qu'il arrive à la partition.
    func announce(after delay: TimeInterval) {
        announceToken &+= 1
        let token = announceToken
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(delay, 0)))
            guard token == self.announceToken else { return }
            self.arpeggio()
        }
    }

    /// La cinématique s'en va avant l'heure : l'annonce ne doit pas
    /// sonner dans le vide.
    func cancelAnnounce() { announceToken &+= 1 }

    private var announceToken = 0

    private func arpeggio() {
        // Trois degrés qui montent (tierce mineure, quarte) sur 145 ms :
        // assez pour qu'on entende une INTENTION, trop court pour qu'on
        // entende une mélodie.
        let steps: [(TimeInterval, Float, Float)] = [
            (0.000, 1.00, 0.055),
            (0.072, 1.19, 0.048),
            (0.145, 1.41, 0.040)
        ]
        for (dt, rate, vol) in steps {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(dt))
                self.play(rate: rate, volume: vol)
            }
        }
    }

    private func grain(level: Double) {
        let now = CACurrentMediaTime()
        // Jamais deux grains collés : en dessous de 45 ms l'oreille entend
        // une mitraille, pas une poudre.
        guard now - lastAt > 0.045 else { return }
        lastAt = now
        // La hauteur monte AVEC le geste — c'est la même dramaturgie que
        // le grondement haptique, une octave de cristal en chemin.
        let lv = min(max(level, 0), 1)
        // TRÈS discret : sous le seuil de l'attention. Un grain qu'on
        // remarque isolément est un son d'interface ; une poudre, on la
        // sent seulement quand le doigt bouge.
        play(rate: Float.random(in: 0.82 ... 1.08) + Float(lv) * 0.40,
             volume: Float.random(in: 0.030 ... 0.065) + Float(lv) * 0.045)
    }

    private func play(rate: Float, volume: Float) {
        guard !pool.isEmpty else { return }
        let p = pool[next]
        next = (next + 1) % pool.count
        p.rate = rate
        p.volume = volume
        p.currentTime = 0
        p.play()
    }

    /// L'espacement de base, en points de doigt — jamais régulier : une
    /// cadence fixe s'entend comme un métronome.
    private static func stride() -> CGFloat { CGFloat.random(in: 11 ... 26) }
}
