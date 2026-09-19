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

/// LA MUSIQUE DU SACRE À LA PLONGÉE : l'appui fort qui fait ENTRER dans
/// la carte mérite ses cordes — `sacre-lune` (le pad Em9→Cmaj7→Am7→B,
/// clochettes mineures, réverbe 3,4 s). Fondu d'entrée 1,2 s, tenue le
/// temps du voyage, fondu de sortie calé sur le RETOUR de la plongée
/// (8,4 s). Doctrine maison : `.ambient` + `mixWithOthers`, se tait si
/// une musique joue déjà — et s'efface devant BoosterAmbience (le
/// manège a ses trois actes : JAMAIS deux sacres superposés).
@MainActor
final class LuneSacre {
    static let shared = LuneSacre()
    private var player: AVAudioPlayer?
    /// Le compteur de génération : une re-plongée remplace le fondu de
    /// sortie programmé de la précédente (jamais un fondu fantôme qui
    /// éteint la nouvelle).
    private var generation = 0
    private init() {}

    /// La piste par TYPOLOGIE (les 4 lunes de la forge). Loi Kathryn :
    /// zéro carillon, zéro église, zéro gong — cordes, cuivres sombres,
    /// chœur, timbales. Sommets composés TÔT (4-8 s : la fenêtre de la
    /// plongée n'entend que ~10 s).
    private static func piste(_ rarete: String?) -> String {
        switch rarete {
        case "common": return "sacre-commune"        // la tendresse noble
        case "epic": return "sacre-epique"           // la houle dramatique
        case "legendary": return "sacre-legendaire"  // le grandiose pur
        default: return "sacre-lune"                 // rare — les cordes
        }
    }

    func dive(rarete: String? = nil) {
        guard !AVAudioSession.sharedInstance().isOtherAudioPlaying,
              !BoosterAmbience.sounding,
              let url = Bundle.main.url(forResource: Self.piste(rarete),
                                        withExtension: "caf") else { return }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        player?.stop()
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        player = p
        generation += 1
        let gen = generation
        p.volume = 0
        p.play()
        p.setVolume(0.30, fadeDuration: 1.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.4) { [weak self] in
            guard let self, self.generation == gen else { return }
            self.player?.setVolume(0, fadeDuration: 2.0)
        }
    }

    /// LA SORTIE. Quitter le Sacre par le chevron doit emporter sa
    /// musique — sinon elle chante par-dessus la home. On incrémente la
    /// génération pour que le fondu de 8,4 s déjà programmé ne vienne pas
    /// parler après nous.
    func sortir(over seconds: TimeInterval = 0.7) {
        guard let p = player else { return }
        generation += 1
        p.setVolume(0, fadeDuration: seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds + 0.05) {
            [weak self] in
            guard let self, self.player === p else { return }
            p.stop()
            self.player = nil
        }
    }
}
