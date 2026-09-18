import AVFoundation
import CoreHaptics
import os
import SceneKit
import SwiftUI

// MARK: - Les mains du manège

/// Le moteur haptique du chantier : lit continu du drag (le roulement du
/// manège sous le doigt), détentes de cran (le clic d'un barillet),
/// freinage de l'aimant, coup sourd d'engagement, accent d'arrivée.
/// Repli UIKit quand le matériel n'a pas de Taptic — et le SIMULATEUR n'a
/// AUCUNE haptique : tout ceci ne se juge qu'au téléphone.
final class BoosterHaptics {
    private var engine: CHHapticEngine?
    private var bed: CHHapticAdvancedPatternPlayer?
    private var needsRestart = false
    private let fallback = UIImpactFeedbackGenerator(style: .light)
    private let fallbackHeavy = UIImpactFeedbackGenerator(style: .heavy)

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.playsHapticsOnly = true
        engine?.isAutoShutdownEnabled = true
        engine?.stoppedHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.needsRestart = true }
        }
        engine?.resetHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.needsRestart = true
                self?.bed = nil
            }
        }
        // Le même coordinateur habille le décor du Profil : aucune
        // vibration ne justifie de démarrer son moteur à la construction.
        needsRestart = true
    }

    private func revive() {
        guard needsRestart, let engine else { return }
        do {
            try engine.start()
            buildBed()
            needsRestart = false
            NavDiagnostic.noter("haptique-booster-demarre")
        } catch { needsRestart = true }
    }

    private func buildBed() {
        guard let engine else { return }
        let ev = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            .init(parameterID: .hapticIntensity, value: 1.0),
            .init(parameterID: .hapticSharpness, value: 0.45),
        ], relativeTime: 0, duration: 30)
        if let pattern = try? CHHapticPattern(events: [ev], parameters: []) {
            bed = try? engine.makeAdvancedPlayer(with: pattern)
        }
    }

    func bedStart() {
        revive()
        try? bed?.start(atTime: CHHapticTimeImmediate)
        bedIntensity(0)
    }

    /// 0…1 : le roulement suit la vitesse de la roue.
    func bedIntensity(_ v: Float) {
        try? bed?.sendParameters([
            .init(parameterID: .hapticIntensityControl,
                  value: min(max(v, 0), 1), relativeTime: 0),
        ], atTime: CHHapticTimeImmediate)
    }

    /// Un écran caché rend aussi son moteur haptique ; le prochain geste
    /// le redémarre, sans perdre la scène ou sa pose.
    func suspend() {
        bedStop()
        bed = nil
        needsRestart = true
        engine?.stop { erreur in
            DispatchQueue.main.async {
                NavDiagnostic.noter("haptique-booster-arrete",
                    destination: erreur == nil ? "ok" : "erreur")
            }
        }
    }

    /// Fin définitive de cette cérémonie, même si un rappel la retient encore.
    func shutdown() {
        bedStop()
        engine?.resetHandler = {}
        engine?.stoppedHandler = { _ in }
        engine?.stop(completionHandler: nil)
        bed = nil
        engine = nil
    }

    func bedStop() {
        try? bed?.stop(atTime: CHHapticTimeImmediate)
    }

    private func transient(_ intensity: Float, _ sharpness: Float) {
        guard let engine else { return }
        revive()
        let ev = CHHapticEvent(eventType: .hapticTransient, parameters: [
            .init(parameterID: .hapticIntensity, value: intensity),
            .init(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: 0)
        if let p = try? CHHapticPattern(events: [ev], parameters: []),
           let player = try? engine.makePlayer(with: p) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }

    /// Le clic de barillet, à chaque cran.
    func detent() {
        if engine != nil { transient(0.55, 0.65) }
        else { fallback.impactOccurred(intensity: 0.5) }
    }

    /// Le decrescendo de l'aimant qui pose la roue.
    func brake() {
        if engine != nil { transient(0.35, 0.3) }
    }

    /// Le verrou de la mise en place, et la pose d'un spin.
    func lock() {
        if engine != nil { transient(0.4, 0.5) }
        else { fallback.impactOccurred(intensity: 0.4) }
    }

    /// L'accent d'arrivée du dolly.
    func arrive() {
        if engine != nil { transient(0.7, 0.5) }
        else { fallback.impactOccurred(intensity: 0.7) }
    }

    /// Un crépitement de déchirure : la saveur suit la vitesse du geste.
    /// Netteté HAUTE — c'est elle qui fait « mylar » (basse, ça fait
    /// caoutchouc).
    func pop(_ v: Float) {
        guard engine != nil else {
            fallback.impactOccurred(intensity: 0.5)
            return
        }
        if v > 0.7 || Float.random(in: 0 ... 1) < 0.15 {
            transient(1.0, 1.0)
        } else if Float.random(in: 0 ... 1) < 0.5 {
            transient(Float.random(in: 0.65 ... 0.85), 0.95)
        } else {
            transient(Float.random(in: 0.45 ... 0.6), 0.8)
        }
    }

    /// La paire scintillante de la carte présentée, calée sur le carillon.
    func sparkle() {
        guard let engine else {
            fallback.impactOccurred(intensity: 0.6)
            return
        }
        revive()
        let a = CHHapticEvent(eventType: .hapticTransient, parameters: [
            .init(parameterID: .hapticIntensity, value: 0.6),
            .init(parameterID: .hapticSharpness, value: 0.45),
        ], relativeTime: 0)
        let b = CHHapticEvent(eventType: .hapticTransient, parameters: [
            .init(parameterID: .hapticIntensity, value: 0.35),
            .init(parameterID: .hapticSharpness, value: 0.7),
        ], relativeTime: 0.09)
        if let p = try? CHHapticPattern(events: [a, b], parameters: []),
           let player = try? engine.makePlayer(with: p) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }

    /// Le coup sourd de l'engagement : l'impact profond + un grondement
    /// de 180 ms qui meurt — le mécanisme qui s'enclenche.
    func commitThunk() {
        guard let engine else {
            fallbackHeavy.impactOccurred()
            return
        }
        revive()
        let hit = CHHapticEvent(eventType: .hapticTransient, parameters: [
            .init(parameterID: .hapticIntensity, value: 1.0),
            .init(parameterID: .hapticSharpness, value: 0.35),
        ], relativeTime: 0)
        let rumble = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            .init(parameterID: .hapticIntensity, value: 0.9),
            .init(parameterID: .hapticSharpness, value: 0.2),
        ], relativeTime: 0.005, duration: 0.18)
        let dying = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [.init(relativeTime: 0, value: 1.0),
                            .init(relativeTime: 0.18, value: 0.0)],
            relativeTime: 0)
        if let p = try? CHHapticPattern(events: [hit, rumble],
                                        parameterCurves: [dying]),
           let player = try? engine.makePlayer(with: p) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }

    /// LE DOUBLE COUP DE LA RUPTURE : l'impact GRAVE dans l'os (le
    /// RRRIP), un grondement bref, et le claquement SEC 40 ms derrière
    /// — la bande qui cède en deux temps, calée sur le clac cuit dans
    /// `dechirure-finale`.
    func ripThunk() {
        guard let engine else {
            fallbackHeavy.impactOccurred()
            return
        }
        revive()
        let deep = CHHapticEvent(eventType: .hapticTransient, parameters: [
            .init(parameterID: .hapticIntensity, value: 1.0),
            .init(parameterID: .hapticSharpness, value: 0.12),
        ], relativeTime: 0)
        let rumble = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            .init(parameterID: .hapticIntensity, value: 0.8),
            .init(parameterID: .hapticSharpness, value: 0.15),
        ], relativeTime: 0.005, duration: 0.16)
        let clac = CHHapticEvent(eventType: .hapticTransient, parameters: [
            .init(parameterID: .hapticIntensity, value: 1.0),
            .init(parameterID: .hapticSharpness, value: 1.0),
        ], relativeTime: 0.04)
        let dying = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [.init(relativeTime: 0, value: 1.0),
                            .init(relativeTime: 0.16, value: 0.0)],
            relativeTime: 0)
        if let p = try? CHHapticPattern(events: [deep, rumble, clac],
                                        parameterCurves: [dying]),
           let player = try? engine.makePlayer(with: p) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }

    /// Le RAIDISSEMENT avant qu'un pop ne cède : 70 ms de tension
    /// sourde — la main sent que ça va lâcher AVANT que ça lâche.
    func stiffen() {
        guard let engine else { return }
        revive()
        let ev = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            .init(parameterID: .hapticIntensity, value: 0.32),
            .init(parameterID: .hapticSharpness, value: 0.18),
        ], relativeTime: 0, duration: 0.07)
        if let p = try? CHHapticPattern(events: [ev], parameters: []),
           let player = try? engine.makePlayer(with: p) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }

    /// LE CLIC DE SERTISSAGE : la carte qui se clipse dans son cadre —
    /// un seul tap ferme et MAT (netteté basse : le feutre, pas le
    /// verre).
    func seatClick() {
        if engine != nil { transient(0.8, 0.28) }
        else { fallback.impactOccurred(intensity: 0.8) }
    }

    /// Le DÉCALAGE de netteté du lit (additif, −1…1) : le souffle qui
    /// s'assombrit vers le grave pendant la chute du sachet.
    func bedSharpness(_ shift: Float) {
        try? bed?.sendParameters([
            .init(parameterID: .hapticSharpnessControl,
                  value: min(max(shift, -1), 1), relativeTime: 0),
        ], atTime: CHHapticTimeImmediate)
    }

    /// LE SOUPIR du sachet relâché sans déchirure : une détente douce
    /// qui retombe — l'anticipation rendue, pas punie.
    func exhale() {
        guard let engine else { return }
        revive()
        let ev = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            .init(parameterID: .hapticIntensity, value: 0.3),
            .init(parameterID: .hapticSharpness, value: 0.08),
        ], relativeTime: 0, duration: 0.5)
        let fall = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [.init(relativeTime: 0, value: 1.0),
                            .init(relativeTime: 0.5, value: 0.0)],
            relativeTime: 0)
        if let p = try? CHHapticPattern(events: [ev], parameterCurves: [fall]),
           let player = try? engine.makePlayer(with: p) {
            try? player.start(atTime: CHHapticTimeImmediate)
        }
    }
}

// MARK: - L'oreille du flux booster

/// Les trois actes en musique, boucles sans couture (cuites au pipeline
/// numpy, périodiques par construction), fondues l'une dans l'autre :
/// la boîte à musique du MANÈGE, la veillée sombre de l'ENGAGEMENT,
/// et le sacre — sombre, émouvant — quand LA CARTE se présente.
/// Tout se MÉLANGE à la musique de l'utilisateur sans jamais la toucher,
/// respecte le silencieux, et se tait si une musique joue déjà — on ne
/// se bat pas contre la playlist de séance.
final class BoosterAmbience {
    /// Les pistes et leur volume de croisière.
    static let manege = "manege-nappe"
    static let veille = "braise-veille"
    static let sacre = "sacre-lune"
    private static let levels: [String: Float] = [
        manege: 0.22, veille: 0.30, sacre: 0.30,
    ]

    private let engine = AVAudioEngine()
    private var players: [String: AVAudioPlayerNode] = [:]
    private var ready = false
    private var fadeTimers: [String: Timer] = [:]

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default,
                                 options: [.mixWithOthers])
        guard !session.isOtherAudioPlaying else { return }
        for name in [Self.manege, Self.veille, Self.sacre] {
            guard let url = Bundle.main.url(forResource: name,
                                            withExtension: "caf"),
                  let file = try? AVAudioFile(forReading: url),
                  let buf = AVAudioPCMBuffer(
                      pcmFormat: file.processingFormat,
                      frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buf)) != nil else { continue }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: buf.format)
            player.volume = 0
            players[name] = player
            engine.prepare()
            if engine.isRunning || (try? engine.start()) != nil {
                player.scheduleBuffer(buf, at: nil, options: .loops)
                player.play()
            }
        }
        ready = !players.isEmpty && engine.isRunning
    }

    /// Fondu d'une piste vers un volume cible.
    private func fade(_ name: String, to target: Float, over seconds: Double) {
        guard ready, let player = players[name] else { return }
        fadeTimers[name]?.invalidate()
        let start = player.volume
        let t0 = CACurrentMediaTime()
        fadeTimers[name] = Timer.scheduledTimer(withTimeInterval: 1.0 / 30,
                                                repeats: true) { [weak self] timer in
            guard self != nil else {
                timer.invalidate()
                return
            }
            let u = Float(min((CACurrentMediaTime() - t0) / seconds, 1))
            player.volume = start + (target - start) * u
            if u >= 1 { timer.invalidate() }
        }
    }

    /// L'acte demandé monte, les autres s'effacent.
    /// Le témoin de présence : LuneSacre (la plongée de la carte)
    /// s'efface quand le manège chante déjà — JAMAIS deux sacres
    /// superposés.
    static var sounding = false

    func act(_ name: String, over seconds: Double) {
        if !players.isEmpty { Self.sounding = true }
        for key in players.keys {
            fade(key, to: key == name ? (Self.levels[name] ?? 0.25) : 0,
                 over: seconds)
        }
    }

    /// Tout s'éteint.
    func silence(over seconds: Double) {
        Self.sounding = false
        for key in players.keys { fade(key, to: 0, over: seconds) }
    }

    deinit {
        Self.sounding = false
        for timer in fadeTimers.values { timer.invalidate() }
        if ready { engine.stop() }
    }
}

/// Les bruits de la cérémonie : la BRAISE qui suit le doigt pendant la
/// découpe (deux boucles sans couture — éparse et dense — fondues selon
/// la vitesse du geste), et le CARILLON féérique quand la carte se
/// présente. Même étiquette que la musique : mélangé, respectueux du
/// silencieux, jamais contre la playlist.
final class BoosterSFX {
    private let engine = AVAudioEngine()
    private var eparse: AVAudioPlayerNode?
    private var dense: AVAudioPlayerNode?
    private var chimePlayer: AVAudioPlayerNode?
    private var chimeBuf: AVAudioPCMBuffer?
    private var ripPlayer: AVAudioPlayerNode?
    private var ripBuf: AVAudioPCMBuffer?
    private var ready = false
    /// Le plafond du crépitement dans le mix (la braise reste un garni).
    private static let crackleCeiling: Float = 0.5

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default,
                                 options: [.mixWithOthers])
        func load(_ name: String, loop: Bool) -> AVAudioPlayerNode? {
            guard let url = Bundle.main.url(forResource: name,
                                            withExtension: "caf"),
                  let file = try? AVAudioFile(forReading: url),
                  let buf = AVAudioPCMBuffer(
                      pcmFormat: file.processingFormat,
                      frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buf)) != nil else { return nil }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: buf.format)
            player.volume = 0
            if loop {
                player.scheduleBuffer(buf, at: nil, options: .loops)
            } else if chimeBuf == nil {
                chimeBuf = buf
            } else {
                ripBuf = buf
            }
            return player
        }
        eparse = load("dechirure-lente", loop: true)
        dense = load("dechirure-franche", loop: true)
        chimePlayer = load("feerie-carillon", loop: false)
        ripPlayer = load("dechirure-finale", loop: false)
        engine.prepare()
        guard (try? engine.start()) != nil else { return }
        eparse?.play()
        dense?.play()
        chimePlayer?.play()
        ripPlayer?.play()
        ready = true
    }

    /// La braise sous le doigt : v = vitesse du geste (0…1). L'éparse
    /// porte les gestes lents, la dense monte avec la fougue.
    func crackle(_ v: Float) {
        guard ready else { return }
        let w = min(max((v - 0.25) / 0.55, 0), 1)
        let g = powf(min(max(v, 0), 1), 0.6) * Self.crackleCeiling
        eparse?.volume = (1 - w) * g
        dense?.volume = w * g
    }

    func crackleOff() {
        eparse?.volume = 0
        dense?.volume = 0
    }

    /// LE GRAND RRRIP : la bande qui cède — la déchirure accélère et
    /// se libère d'un coup sec.
    func rip() {
        guard ready, let ripPlayer, let ripBuf else { return }
        ripPlayer.volume = 0.85
        ripPlayer.scheduleBuffer(ripBuf, at: nil)
    }

    /// Le carillon féérique, un seul, au sacre de la carte.
    func chime() {
        guard ready, let chimePlayer, let chimeBuf else { return }
        chimePlayer.volume = 0.9
        chimePlayer.scheduleBuffer(chimeBuf, at: nil)
    }

    deinit {
        if ready { engine.stop() }
    }
}

// MARK: - Banc d'essai (`-boosterLab`)

/// Page noire nue : le booster de récompense seul — le sachet noir laqué au
/// croissant, flottant dans son studio braise. Une pichenette le fait
/// TOURNER (inertie amortie, puis il se pose en douceur sur la face la plus
/// proche — recto ou verso) ; le doigt posé sur la bande du haut, face
/// avant, TRACE la découpe : un trait de lumière blanc-orangé avance sous
/// le doigt (le geste de Pokémon Pocket), la bande tombe, la carte sort du
/// sachet et vient se présenter.
///
/// ════════════════════════ « LE SACRE » ════════════════════════
/// LE NOM DU FLOW COMPLET (acté par Kathryn, 15-08-2026) : du cercle
/// des boosters à la carte de fin — manège → engagement → charge au
/// maintien → découpe de braise → sortie sans un tour → LE SACRE de
/// la carte vivante. On le lance ENTIER avec
/// `-boosterLab -boosterGallery` ; dans l'app, c'est le trio
/// `BoosterStage(gallery: true)` + `BoosterHandle` + overlay
/// `CarteVivante` (l'assemblage du raccord vit dans ce fichier).
/// Variantes : `-boosterShiny` (le tell des rares), `-boosterCine`
/// (il se joue seul, pour filmer), `-boosterHoldDemo` (la boucle
/// charge/soupir/relais sans main).
/// ═══════════════════════════════════════════════════════════════
///
/// `-boosterGallery` ouvre sur la GALERIE : l'anneau de cinq sachets mirés
/// dans le sol d'encre, à l'objectif long. Un swipe = un cran, aimanté ;
/// tap sur un flanc = il vient au centre ; tap au centre = l'engagement
/// (les voisins filent, dolly-zoom vers le cadrage cérémonie) ; swipe vers
/// le bas avant la morsure = retour à l'anneau.
///
/// Sous-flags de capture (le pattern des bancs) :
///   `-boosterStill` coupe le flottement au repos ;
///   `-boosterDos` démarre verso face caméra ;
///   `-boosterYaw <deg>` fige un lacet arbitraire (180 = recto, 90 = profil) ;
///   `-boosterMylar` charge la recette matière « mylar métallisé »
///     (par défaut : « laque noire ») ;
///   `-boosterTear <s>` fige une déchirure entamée à s (0…1) ;
///   `-boosterOpen` démarre sachet ouvert, carte présentée ;
///   `-boosterNoir` habille le sachet de la ROBE NOIRE (le manège des
///     légendaires — même expérience, même braise, un autre dessin).
struct BoosterLab: View {
    @Environment(\.scenePhase) private var scenePhase
    private static let still = CommandLine.arguments.contains("-boosterStill")
    private static let dos = CommandLine.arguments.contains("-boosterDos")
    private static let mylar = CommandLine.arguments.contains("-boosterMylar")
    /// `-boosterNoir` : LE MANÈGE DES LÉGENDAIRES — le même carrousel, la
    /// robe noire (le plan est `tools/sacre/PLAN-BOOSTER-NOIR.md`).
    private static let noir = CommandLine.arguments.contains("-boosterNoir")
    private static let gallery = CommandLine.arguments.contains("-boosterGallery")
    /// L'invite au-dessus de la carte : chevron de poussière par défaut,
    /// `-boosterInvite feux` pour les feux de piste (les deux candidates
    /// au banc, verdict Kathryn à l'écran).
    private static let inviteFeux = UserDefaults.standard
        .string(forKey: "boosterInvite") == "feux"
    private static let tear: Float? = UserDefaults.standard
        .string(forKey: "boosterTear").flatMap(Float.init)
    private static let yawDeg: Float? = UserDefaults.standard
        .string(forKey: "boosterYaw").flatMap(Float.init)
    private static let open = CommandLine.arguments.contains("-boosterOpen")
    private static let cine = CommandLine.arguments.contains("-boosterCine")
    /// `-boosterScelle` : le banc du SCELLEMENT (30-08) — la forge tourne
    /// aussi hors app, et consomme un sachet du compte de test avec le jwt
    /// du banc (voir `lancerForge`). La seule preuve jouable au sim que « le
    /// sachet consommé porte sa carte » ; jamais par défaut.
    private static let scelle = CommandLine.arguments.contains("-boosterScelle")
    /// `-boosterEnvol` : la carte s'envole seule après le registre — le
    /// balayage est le seul geste qu'un film au simulateur ne sait pas
    /// jouer, et sans lui la chaîne s'arrête juste avant l'accueil.
    private static let envolAuto = CommandLine.arguments
        .contains("-boosterEnvol")

    /// LE MODE APP : le Sacre monté au-dessus du profil — galerie
    /// forcée, pas de bouton rejouer, et l'envol REND la carte à l'hôte
    /// (le raccord d'accueil : auto-scroll, descente, fumée).
    var appMode = false
    /// La morsure que la card 2D a faite (BoosterCard.swift, la déchirure
    /// au drag), reprise par le manège — mode app seulement.
    var dechirureDepart: Float? = nil
    /// LA ROBE DU MANÈGE — `.noire` monte le carrousel des légendaires
    /// (§3 du plan : deux réserves, deux portes, deux manèges ; ils ne se
    /// mélangent JAMAIS, verdict Kathryn). Le banc `-boosterNoir` la force.
    var robe: RobeBooster = .lune
    private var robeEffective: RobeBooster { Self.noir ? .noire : robe }
    /// LE CHEVRON DE SORTIE — il rend la main à la HOME depuis les deux
    /// escales où l'on a le droit de partir : le MANÈGE (avant
    /// l'engagement) et le RÉSULTAT (la carte posée). Jamais pendant la
    /// cérémonie : une fois l'ouverture lancée, la séquence va au bout.
    var onRetourHome: (() -> Void)? = nil
    /// La carte au moment où elle s'est envolée — la vraie famille et
    /// son art (le placeholder n'est plus qu'un repli de forge).
    var onCarteEnvolee: ((CarteEnvolee) -> Void)? = nil

    @StateObject private var handle = BoosterHandle()
    @State private var carteOpacity: Double = 0
    // ---- l'étage d'ENREGISTREMENT (post-sacre) ----
    /// Le tirage du balayage (points, brut) et le départ du vol.
    @State private var envolY: CGFloat = 0
    @State private var envolStart: Date?
    @State private var envolArmed = false
    @State private var inviteKilled = false
    @State private var registreBorn = Date()
    /// La carte est en PLONGÉE (appui long) : le registre, le rêve et le
    /// courant se taisent — le voyage règne seul.
    @State private var carteEnPlongee = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // PLEIN ÉCRAN, pas la safe area : la SCNView rend sur tout
            // l'écran — un GeometryReader en safe area donnerait un
            // overlay 12 % trop petit et décalé (le liseré de la carte
            // scène dépassait au-dessus, payé à la capture).
            GeometryReader { geo in
                ZStack {
                    BoosterStage(still: Self.still, frozenTear: Self.tear,
                                 dechirureDepart: appMode ? dechirureDepart : nil,
                                 startOpen: Self.open, startDos: Self.dos,
                                 mylar: Self.mylar, frozenYawDeg: Self.yawDeg,
                                 // En mode app le manège précède la
                                 // cérémonie — SAUF au banc du flow
                                 // complet (`-boosterCine`), où elle se
                                 // joue toute seule depuis le sachet
                                 // posé (autoCeremony n'arme que sur
                                 // `mode == .idle`, jamais en galerie).
                                 gallery: (Self.gallery || appMode)
                                     && !Self.cine,
                                 cine: Self.cine,
                                 handle: handle,
                                 forge: appMode || Self.scelle,
                                 paused: scenePhase != .active || handle.attenteReseau,
                                 robe: robeEffective,
                                 cadreDecoupe: true)
                        .ignoresSafeArea()
                        // Recognizers désactivés ≠ hit-test désactivé :
                        // sans ça le SCNView avale les touches destinées
                        // à la carte vivante.
                        .allowsHitTesting(!handle.revealed)
                    if handle.revealed, !handle.flown {
                        // LE RECOUVREMENT MÊME-IMAGE : CarteVivante posée
                        // exactement sur la carte SceneKit immobile —
                        // projection ANALYTIQUE de la pose de destination
                        // (plan 0,60×0,80 · scale 1,05 · centre (0, 0.02,
                        // 0.55) · caméra z 1,86 · FOV 60 vertical) :
                        // projW = H·0,63/(2·1,31·tan 30°). Jamais de
                        // projectPoint à attach — mauvaise caméra.
                        let H = geo.size.height
                        let projW = H * 0.41647
                        let cardW = min(projW + 46, 426)
                        let cardH = projW * 1448.0 / 1086.0
                        TimelineView(.animation(minimumInterval: 1.0 / 60,
                                                paused: scenePhase != .active)) { tl in
                            let age = tl.date.timeIntervalSince(registreBorn)
                            // — LE VOL (l'avion) : fonction pure du temps.
                            // Cabrée, montée quadratique, dérive, roulis,
                            // et elle S'AMENUISE en s'éloignant — un
                            // avion devient un point, puis rien.
                            let fp = envolStart.map {
                                min(max(tl.date.timeIntervalSince($0) / 0.92,
                                        0), 1)
                            } ?? 0
                            let climb = 0.62 * Double(H)
                                * (0.35 * fp * fp + 0.65 * fp * fp * fp)
                            let drift = 26 * fp * fp
                            let roll = 6 * sstepD(0.12, 0.5, fp)
                            let vScale = 1 - 0.9 * pow(sstepD(0.04, 0.96, fp),
                                                       0.85)
                            let vFade = 1 - sstepD(0.86, 1.0, fp)
                            // — LA RÉPÉTITION : la carte RÊVE de partir.
                            // Toutes les ~3,6 s, le nez se lève, elle
                            // monte comme retenue par un fil, se repose
                            // avec un soupçon de rebond. L'insistance
                            // grandit doucement si personne ne répond.
                            let insiste = 1 + 0.55 * min(age / 11, 1)
                            let u = age.truncatingRemainder(dividingBy: 3.6)
                            let dreaming = !inviteKilled && envolY <= 0
                                && envolStart == nil && !carteEnPlongee
                            let dream = dreaming
                                ? insiste * (sstepD(0.0, 0.55, u)
                                    - sstepD(0.55, 1.35, u)
                                    - 0.10 * (sstepD(1.35, 1.55, u)
                                        - sstepD(1.55, 1.95, u)))
                                : 0
                            let dreamLift = 7.5 * dream
                            // — LE TIRAGE élastique : beaucoup d'assiette,
                            // peu de montée — l'avion CABRE avant de
                            // quitter la piste, le seuil se sent.
                            let rise = 60 * tanh(Double(envolY) / 110)
                            let pitch = envolStart != nil
                                ? -18 - 14 * sstepD(0.0, 0.35, fp)
                                : -2.8 * dream - 18 * sstepD(0, 130,
                                                             Double(envolY))
                            // — L'AIR : la brise du repos, qui s'emballe
                            // avec le tirage et raconte le décollage.
                            let boost = 1 + Double(envolY) / 55 + fp * 5.5
                            ZStack {
                                CourantAscendant(date: tl.date,
                                                 born: registreBorn,
                                                 boost: boost, front: false)
                                    .frame(width: min(cardW + 96,
                                                      geo.size.width),
                                           height: cardH + 170)
                                    .offset(y: -0.01322 * H)
                                    .opacity(carteEnPlongee ? 0 : 1)
                                    // Jamais un pop AU-DESSUS du noir
                                    // de sortie : le courant revient en
                                    // fondu avec la levée du battement.
                                    .animation(.easeInOut(duration: 0.35),
                                               value: carteEnPlongee)
                                // LA FUMÉE D'ENVOL : le sillage de
                                // l'avion — des volutes très fines qui
                                // naissent derrière la carte le long de
                                // sa trajectoire PASSÉE, s'élargissent
                                // et s'évanouissent. (Les traits de
                                // vitesse sont morts : « trop cheap ».)
                                if fp > 0.02 {
                                    Canvas { ctx, size in
                                        for k in 0 ..< 16 {
                                            let pk = fp - Double(k) * 0.05
                                            guard pk > 0 else { continue }
                                            let cy = 0.62 * Double(H)
                                                * (0.35 * pk * pk
                                                    + 0.65 * pk * pk * pk)
                                            let cx = 26 * pk * pk
                                                + 7 * sin(Double(k) * 2.1
                                                          + fp * 8)
                                            let a = fp - pk
                                            let rad = 8 + 150 * a
                                            let op = 0.05 * (1 - a * 4.2)
                                            guard op > 0 else { continue }
                                            let rect = CGRect(
                                                x: size.width / 2 + cx
                                                    - rad / 2,
                                                y: size.height / 2 - cy + 34
                                                    - rad / 2,
                                                width: rad, height: rad)
                                            ctx.opacity = op
                                            ctx.fill(
                                                Ellipse().path(in: rect),
                                                with: .color(.white))
                                        }
                                    }
                                    .blur(radius: 9)
                                    .offset(y: -0.01322 * H)
                                    .allowsHitTesting(false)
                                }
                                CarteVivante(art: handle.carteArt
                                                 .map(Image.init(uiImage:)),
                                             depth: handle.carteDepth
                                                 .map(Image.init(uiImage:)),
                                             rarete: handle.rarete,
                                             onDive: { carteEnPlongee = $0 },
                                             diveOnTap: true)
                                    .frame(width: cardW)
                                    .rotation3DEffect(
                                        .degrees(pitch),
                                        axis: (x: 1, y: 0, z: 0),
                                        perspective: 0.4)
                                    .rotationEffect(.degrees(roll))
                                    .scaleEffect(vScale)
                                    .offset(x: drift,
                                            y: -0.01322 * H - rise
                                                - dreamLift - climb)
                                    .opacity(carteOpacity * vFade)
                                CourantAscendant(date: tl.date,
                                                 born: registreBorn,
                                                 boost: boost, front: true)
                                    .frame(width: min(cardW + 96,
                                                      geo.size.width),
                                           height: cardH + 170)
                                    .offset(y: -0.01322 * H)
                                    .opacity(carteEnPlongee ? 0 : 1)
                                    // Jamais un pop AU-DESSUS du noir
                                    // de sortie : le courant revient en
                                    // fondu avec la levée du battement.
                                    .animation(.easeInOut(duration: 0.35),
                                               value: carteEnPlongee)
                                // L'INVITE au-dessus de la carte : l'air
                                // qui montre le ciel. Meurt au premier
                                // contact, se tait en plongée et en vol.
                                if !inviteKilled {
                                    Group {
                                        if Self.inviteFeux {
                                            FeuxDePiste(date: tl.date,
                                                        born: registreBorn)
                                        } else {
                                            ChevronDePoussiere(
                                                date: tl.date,
                                                born: registreBorn)
                                        }
                                    }
                                    .frame(width: 160, height: 120)
                                    .offset(y: -0.01322 * H - cardH / 2 - 62)
                                    .opacity(carteEnPlongee
                                        || envolStart != nil ? 0 : 1)
                                    .animation(.easeInOut(duration: 0.3),
                                               value: carteEnPlongee)
                                }
                                // LE REGISTRE : les lunes + « Nouveau ».
                                // Il ne suit pas la carte (elle part
                                // SEULE), et il se tait pendant la
                                // plongée — le voyage règne.
                                SacreRegistre(lunes: handle.lunes,
                                              nouvelle: handle.nouvelle,
                                              born: registreBorn)
                                    .offset(y: -0.01322 * H + cardH / 2 + 42)
                                    .opacity(envolArmed || envolStart != nil
                                        || carteEnPlongee ? 0 : 1)
                                    .animation(.easeOut(duration: 0.25),
                                               value: envolArmed)
                                    .animation(.easeInOut(duration: 0.35),
                                               value: carteEnPlongee)
                            }
                        }
                        // Le cadre PLEIN ÉCRAN : sans lui, la bande du
                        // courant (plus large que l'écran) faisait
                        // déborder la pile et le GeometryReader posait
                        // tout décalé — la carte doit être CENTRÉE.
                        .frame(width: geo.size.width,
                               height: geo.size.height)
                        .simultaneousGesture(DragGesture(minimumDistance: 12)
                            .onChanged { v in
                                guard envolStart == nil, !carteEnPlongee
                                else { return }
                                inviteKilled = true
                                let dy = v.translation.height
                                if !envolArmed, dy < -40,
                                   abs(dy) > 1.6 * abs(v.translation.width) {
                                    envolArmed = true
                                }
                                if envolArmed { envolY = max(0, -dy) }
                            }
                            .onEnded { v in
                                guard envolArmed, envolStart == nil,
                                      !carteEnPlongee else { return }
                                if envolY > 130 || v.predictedEndTranslation
                                    .height < -320 {
                                    envoler()
                                } else {
                                    withAnimation(.spring(response: 0.4,
                                                          dampingFraction: 0.72)) {
                                        envolY = 0
                                    }
                                    envolArmed = false
                                }
                            })
                        .onAppear {
                            registreBorn = Date()
                            withAnimation(.easeInOut(duration: 0.35)) {
                                carteOpacity = 1
                            }
                            // Recouvrir D'ABORD, éteindre ENSUITE :
                            // l'extinction attend l'overlay opaque —
                            // en retard c'est invisible, en avance
                            // c'est un trou noir d'une frame.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                                handle.coordinator?.extinguishForHandoff()
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
            // LE BOUTON DE RELANCE du banc : réarme toute la cérémonie
            // à volonté — indispensable depuis que le tap appartient à
            // CarteVivante après le raccord. Posé AU-DESSUS de tout
            // (l'overlay carte capte les touches sur toute sa frame).
            // En mode app, pas de rejouer : l'envol rend la main.
            if !appMode {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        carteOpacity = 0
                        handle.revealed = false
                        handle.flown = false
                        envolY = 0
                        envolStart = nil
                        envolArmed = false
                        inviteKilled = false
                        handle.coordinator?.replay()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(12)
                    }
                }
            }
            .padding(.trailing, 6)
            }

            // LE CHEVRON DE SORTIE — le composant de la maison, à sa
            // place canonique : `RangeeChips` le pose exactement où il
            // vit sur la fiche d'exercice et sur la page profil, et il
            // ne bouge JAMAIS d'une page à l'autre.
            //
            // Il n'existe qu'aux DEUX escales où l'on a le droit de
            // partir — le MANÈGE qui tourne encore, et le RÉSULTAT posé.
            // Pendant la cérémonie il n'est même pas dans l'arbre : rien
            // à interrompre, et pas un chip de verre à échantillonner
            // au-dessus de la scène pendant la découpe.
            #if DEBUG
            if CommandLine.arguments.contains("-cartesQA") {
                VStack { Spacer(); Text("revelee=\(handle.revealed);carte=\(handle.cardId ?? "");rarete=\(handle.rarete);attente=\(handle.attenteReseau)")
                    .font(.system(size: 1)).foregroundStyle(.clear)
                    .accessibilityIdentifier("cartes-qa-ouverture") }
            }
            #endif
            if handle.attenteReseau || handle.erreurForge != nil {
                VStack(spacing: 14) {
                    Spacer()
                    Text(handle.erreurForge == nil
                         ? L("Votre carte arrive…", "Your card is on its way…")
                         : L("Votre carte vous attend.", "Your card is waiting for you."))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    if handle.erreurForge != nil {
                        Button(L("Réessayer", "Try again")) { handle.coordinator?.reprendreForge() }
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 70)
            }
            if let onRetourHome, handle.auManege || handle.revealed || handle.attenteReseau || handle.erreurForge != nil {
                VStack(spacing: 0) {
                    RangeeChips(retour: {
                        // Sortir à l'escale RÉSULTAT ne jette pas le
                        // tirage : la carte se pose DIRECTEMENT dans la
                        // collection (le même payload que l'envol, la
                        // forge tardive prime) — sans cérémonie.
                        if appMode, handle.revealed, !handle.flown {
                            let tardive = handle.forgeTardive
                            let artPlein = tardive?.art ?? handle.carteArt
                            CollectionLune.shared.poser(
                                rarete: tardive?.famille.rarete
                                    ?? handle.rarete,
                                famille: tardive?.famille.nom
                                    ?? handle.famille,
                                art: artPlein.map(GabaritCarte.vignette)
                                    ?? ArtDuSacre.art,
                                artPlein: artPlein,
                                depth: tardive?.depth ?? handle.carteDepth,
                                cardId: tardive?.cardId ?? handle.cardId,
                                acquisitionId: tardive?.acquisitionId ?? handle.acquisitionId)
                        }
                        onRetourHome()
                    }) { EmptyView() }
                    Spacer(minLength: 0)
                }
                .opacity(chevronVisible ? 1 : 0)
                .allowsHitTesting(chevronVisible)
                .animation(.easeInOut(duration: 0.28), value: chevronVisible)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            // La typologie au banc : `-boosterRarete <r>` + `-boosterNouveau`
            // (dans l'app, la forge remplira la poignée elle-même).
            handle.rarete = UserDefaults.standard
                .string(forKey: "boosterRarete") ?? "rare"
            handle.nouvelle = CommandLine.arguments
                .contains("-boosterNouveau")
            // En mode app, la nouveauté vient de la COLLECTION : le
            // registre du Sacre dit vrai, pas un flag de banc.
            if appMode {
                handle.nouvelle = CollectionLune.shared
                    .destination(rarete: handle.rarete,
                                 famille: ArtDuSacre.famillePlaceholder)
                    .nouvelle
            }
        }
        // LE BANC DE LA CHAÎNE ENTIÈRE (`-boosterEnvol`) : le balayage
        // est le seul geste que le film ne peut pas jouer tout seul. Ici
        // la carte part d'elle-même une fois le registre écrit — de la
        // pop-up à la carte posée dans la collection, sans un doigt.
        .onChange(of: handle.revealed) { _, ouvert in
            if ouvert, let booster = handle.boosterId, let owner = handle.userId {
                Task {
                    do {
                        guard try await SupabaseSession.shared.currentUserID().lowercased() == owner.lowercased() else { return }
                        let jwt = try await SupabaseSession.shared.token()
                        let j = try await CartesServeur.objet("confirmer_revelation", jwt: jwt, corps: ["p_booster": booster])
                        guard try await SupabaseSession.shared.currentUserID().lowercased() == owner.lowercased() else { return }
                        CartesServeur.terminer(user: owner, noir: robeEffective == .noire)
                        if let coffre = j as? [String: Any] { EconomieWoop.shared.appliquer(SacreServeur.decoderCoffre(coffre)) }
                    } catch { /* Le sachet reste reprenable avec la même carte. */ }
                }
            }
            guard ouvert, Self.envolAuto, envolStart == nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
                guard handle.revealed, !handle.flown,
                      envolStart == nil else { return }
                envoler()
            }
        }
    }

    /// La sortie est-elle offerte ? Au manège tant qu'aucun sachet n'est
    /// engagé ; au résultat tant que la carte n'est ni en plongée (elle
    /// règne seule), ni tirée, ni en vol.
    private var chevronVisible: Bool {
        if handle.revealed {
            return !handle.flown && !carteEnPlongee
                && envolStart == nil && envolY <= 0
        }
        return handle.auManege || handle.attenteReseau || handle.erreurForge != nil
    }

    /// L'ENVOL-AVION : la carte part SEULE (le registre s'est déjà
    /// effacé) — cabrée, montée quadratique avec dérive et roulis, et
    /// elle S'AMENUISE en s'éloignant jusqu'au point, puis rien. Un
    /// souffle dans la paume ; l'écran noir tient, et attend le raccord
    /// de la collection. Le vol lui-même est piloté par la TimelineView
    /// (fonction pure de l'âge d'`envolStart`, 0,92 s).
    private func envoler() {
        inviteKilled = true
        envolStart = Date()
        handle.coordinator?.envolSouffle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            handle.flown = true
            envolStart = nil
            envolY = 0
            envolArmed = false
            // Le mode app rend la carte à l'hôte : l'accueil commence.
            // Une forge TARDIVE prime — la collection reçoit la carte
            // réellement tirée, jamais le placeholder de cérémonie.
            let tardive = handle.forgeTardive
            let artPlein = tardive?.art ?? handle.carteArt
            onCarteEnvolee?(CarteEnvolee(
                rarete: tardive?.famille.rarete ?? handle.rarete,
                famille: tardive?.famille.nom ?? handle.famille,
                art: artPlein.map(GabaritCarte.vignette) ?? ArtDuSacre.art,
                artPlein: artPlein,
                depth: tardive?.depth ?? handle.carteDepth,
                cardId: tardive?.cardId ?? handle.cardId,
                acquisitionId: tardive?.acquisitionId ?? handle.acquisitionId))
        }
    }
}

/// La poignée du raccord : le chef d'orchestre y annonce la révélation
/// (la vue monte CarteVivante), la vue y commande l'extinction de la
/// scène une fois l'overlay opaque.
final class BoosterHandle: ObservableObject {
    @Published var revealed = false
    /// LE MANÈGE TOURNE ENCORE : le sachet n'est pas engagé, donc le
    /// chevron de sortie a le droit d'exister. Il meurt à l'engagement
    /// (`commitGallery`) et renaît au retour à l'anneau (`backOutGallery`).
    @Published var auManege = false
    /// L'ENVOL accompli : la carte est partie vers la collection —
    /// l'écran noir tient, et attend le raccord (la page profil, l'autre
    /// chantier).
    @Published var flown = false
    /// La typologie de la carte révélée (common/rare/epic/legendary —
    /// les 4 lunes) et sa NOUVEAUTÉ dans la collection.
    var rarete: String = "rare"
    var nouvelle: Bool = false
    /// LA CARTE FORGÉE (remplie par le tirage lancé à l'engagement) :
    /// la famille réelle, l'art habillé et sa depth. Publiés : une
    /// forge qui arrive après le dévoilement habille la CarteVivante
    /// déjà montée. nil = le repli carte-lune-1.
    @Published var carteArt: UIImage?
    @Published var carteDepth: UIImage?
    var famille: String = ArtDuSacre.famillePlaceholder
    /// La forge arrivée APRÈS le dévoilement : le visuel de la
    /// cérémonie reste gelé, mais l'envol emporte CETTE carte à la
    /// collection (le serveur a consommé le tirage — on ne jette pas).
    var forgeTardive: LuneForge.Carte?
    var cardId: String?
    var acquisitionId: String?
    var boosterId: String?
    var userId: String?
    @Published var cartePrete = false
    @Published var attenteReseau = false
    @Published var erreurForge: String?
    weak var coordinator: BoosterStage.Coordinator?

    /// Les lunes de la typologie : le registre du sacre les pose une à une.
    var lunes: Int {
        switch rarete {
        case "common": return 1
        case "epic": return 3
        case "legendary": return 4
        default: return 2
        }
    }
}

// MARK: - Le registre du sacre (sous la carte)

/// LES LUNES QUI SE POSENT : sous la carte, la typologie s'écrit avec le
/// VRAI glyphe du logo — chaque lune naît d'un point de lumière flou qui
/// se condense en croissant net, l'une après l'autre. Si la carte est
/// NOUVELLE, la dernière atterrit dans un éclat bref, et c'est elle qui
/// allume le mot. Monochrome blanc — l'or appartient à la carte.
struct SacreRegistre: View {
    @Environment(\.scenePhase) private var scenePhase
    var lunes: Int
    var nouvelle: Bool
    var born: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60,
                                paused: scenePhase != .active)) { tl in
            let age = tl.date.timeIntervalSince(born)
            VStack(spacing: 13) {
                HStack(spacing: 9) {
                    ForEach(0 ..< lunes, id: \.self) { i in
                        let t = age - 0.35 - Double(i) * 0.16
                        let k = min(max(t / 0.4, 0), 1)
                        let e = k * k * (3 - 2 * k)
                        CroissantLune(taille: 13,
                                      couleur: .white.opacity(0.92))
                            .scaleEffect(0.4 + 0.6 * e)
                            .blur(radius: (1 - e) * 5)
                            .opacity(e)
                            .overlay {
                                // L'éclat de la dernière lune (nouveauté).
                                if nouvelle, i == lunes - 1 {
                                    Circle().fill(.white)
                                        .frame(width: 22, height: 22)
                                        .blur(radius: 7)
                                        .opacity(t > 0.4 && t < 0.75
                                            ? (0.75 - t) * 2.4 : 0)
                                }
                            }
                    }
                }
                if nouvelle {
                    NouveauMot(age: age - (0.55 + Double(lunes) * 0.16))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// « NOUVEAU », ÉCRIT PAR LA LUMIÈRE : jamais un badge (loi Kathryn) —
/// des capitales fines très espacées en dégradé blanc, révélées de
/// gauche à droite par un stylo de lumière (le point brillant mène la
/// lisière). Ensuite, le mot respire à peine et un RAPPEL DE FOIL le
/// traverse toutes les ~5 s — la même matière que la carte au-dessus.
struct NouveauMot: View {
    var age: Double

    var body: some View {
        let k = min(max(age / 1.1, 0), 1)
        let e = k * k * (3 - 2 * k)
        let breath = 0.86 + 0.14 * sin(max(age - 1.1, 0) * 2 * .pi / 6.5)
        let sweep = (age - 2.6).truncatingRemainder(dividingBy: 5.2) / 0.9

        Text(L("NOUVEAU", "NEW"))
            .font(.system(size: 12, weight: .light))
            .kerning(4.5)
            .foregroundStyle(LinearGradient(
                colors: [.white, .white.opacity(0.5)],
                startPoint: .top, endPoint: .bottom))
            .overlay {
                // Le rappel de foil : une bande claire qui traverse le
                // mot, masquée par ses lettres.
                GeometryReader { g in
                    if age > 2.6, sweep >= 0, sweep <= 1 {
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.9), .clear],
                            startPoint: .leading, endPoint: .trailing)
                            .frame(width: 34)
                            .position(x: -17 + (g.size.width + 34)
                                      * CGFloat(sweep),
                                      y: g.size.height / 2)
                    }
                }
                .mask(Text(L("NOUVEAU", "NEW"))
                    .font(.system(size: 12, weight: .light)).kerning(4.5))
            }
            .mask(GeometryReader { g in
                Rectangle()
                    .frame(width: g.size.width * CGFloat(e) + 8)
                    .position(x: (g.size.width * CGFloat(e) + 8) / 2 - 4,
                              y: g.size.height / 2)
            })
            .overlay {
                // Le stylo de lumière qui écrit, à la lisière du mot.
                GeometryReader { g in
                    if age > 0, e < 1 {
                        Circle().fill(.white)
                            .frame(width: 4, height: 4)
                            .blur(radius: 1.8)
                            .shadow(color: .white.opacity(0.9), radius: 5)
                            .position(x: g.size.width * CGFloat(e),
                                      y: g.size.height / 2)
                    }
                }
            }
            .opacity(age > 0 ? breath : 0)
    }
}

/// La brique des partitions de pose : le smoothstep.
private func sstepD(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let k = min(max((x - a) / (b - a), 0), 1)
    return k * k * (3 - 2 * k)
}

/// LE CHEVRON DE POUSSIÈRE (candidate n°1 de l'invite) : l'air se
/// discipline un instant — les poussières CONVERGENT en chevron (la
/// forme des flèches : la lisibilité), le chevron MONTE en
/// s'éclaircissant, puis les particules se libèrent et redeviennent de
/// l'air (la matière de la maison : le wahou discret). Deux vagues en
/// canon, cycle ~3,4 s, meurt au premier contact.
struct ChevronDePoussiere: View {
    var date: Date
    var born: Date

    private func fract(_ x: Double) -> Double { x - x.rounded(.down) }
    private func r(_ i: Int, _ s: Double) -> Double {
        fract(sin(Double(i) * 127.1 + s * 311.7) * 43758.5453)
    }

    var body: some View {
        Canvas { ctx, size in
            let t = date.timeIntervalSince(born)
            guard t > 0.8 else { return }
            let u0 = (t - 0.8).truncatingRemainder(dividingBy: 3.4)
            for wave in 0 ..< 2 {
                let u = u0 - Double(wave) * 0.35
                guard u > 0, u < 2.0 else { continue }
                let gather = sstepD(0, 0.55, u)
                let ride = sstepD(0.55, 1.30, u)
                let free = sstepD(1.30, 1.90, u)
                let n = 16
                for i in 0 ..< n {
                    let side: Double = i % 2 == 0 ? -1 : 1
                    let f = Double(i / 2) / Double(n / 2 - 1)
                    // Le slot du chevron : pointe en haut, ailes en bas.
                    let sx = side * f * 24
                    let sy = f * 15
                    // Naissance éparse (l'air), libération aérienne.
                    let seed = i + wave * 40
                    let bx = sx + (r(seed, 1) - 0.5) * 70
                    let by = sy + 26 + r(seed, 2) * 30
                    let fx = sx + (r(seed, 3) - 0.5) * 40
                    let fy = sy - 30 - r(seed, 4) * 24
                    let x = bx + (sx - bx) * gather + (fx - sx) * free
                    let y = by + (sy - by) * gather + (fy - sy) * free
                        - 24 * ride + Double(wave) * 20
                    let op = (0.16 + 0.44 * gather) * (1 - free)
                    let sz = 1.1 + 1.1 * r(i, 5)
                    let rect = CGRect(x: size.width / 2 + x - sz / 2,
                                      y: size.height / 2 + y - sz / 2,
                                      width: sz, height: sz)
                    ctx.opacity = op
                    ctx.fill(Ellipse().path(in: rect), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// LES FEUX DE PISTE (candidate n°2 de l'invite) : trois lumières
/// empilées au-dessus de la carte qui s'allument de BAS en HAUT puis
/// s'éteignent — une piste d'envol qui défile, la direction dite sans
/// une flèche. Cohérente avec l'envol-avion.
struct FeuxDePiste: View {
    var date: Date
    var born: Date

    var body: some View {
        Canvas { ctx, size in
            let t = date.timeIntervalSince(born)
            guard t > 0.8 else { return }
            let u = (t - 0.8).truncatingRemainder(dividingBy: 2.7)
            for i in 0 ..< 3 {
                let on = u - Double(i) * 0.22
                let env = sstepD(0, 0.18, on) * (1 - sstepD(0.5, 1.0, on))
                guard env > 0 else { continue }
                let y = size.height / 2 + 22 - Double(i) * 22
                let halo = CGRect(x: size.width / 2 - 7, y: y - 7,
                                  width: 14, height: 14)
                let core = CGRect(x: size.width / 2 - 1.6, y: y - 1.6,
                                  width: 3.2, height: 3.2)
                ctx.opacity = 0.16 * env
                ctx.fill(Ellipse().path(in: halo), with: .color(.white))
                ctx.opacity = 0.75 * env
                ctx.fill(Ellipse().path(in: core), with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }
}

/// LE COURANT ASCENDANT : l'air lui-même monte autour de la carte — de
/// fines poussières blanches qui dérivent vers le haut, scintillent à
/// peine, entrent et sortent en fondu. Deux couches (derrière/devant la
/// carte) pour la PROFONDEUR ; pendant le tirage et l'envol, le courant
/// S'ACCÉLÈRE et les poussières s'étirent en traits de vitesse — l'air
/// annonce le décollage, puis le raconte. (La comète-doigt est morte :
/// « on ne comprend pas » — ici c'est l'objet et son air qui parlent.)
struct CourantAscendant: View {
    var date: Date
    var born: Date
    /// 1 = brise du repos ; monte avec le tirage, s'emballe à l'envol.
    var boost: Double
    var front: Bool

    private func fract(_ x: Double) -> Double { x - x.rounded(.down) }
    private func r(_ i: Int, _ salt: Double) -> Double {
        fract(sin(Double(i) * 127.1 + salt * 311.7) * 43758.5453)
    }

    var body: some View {
        Canvas { ctx, size in
            let t = date.timeIntervalSince(born)
            guard t > 0 else { return }
            let n = front ? 9 : 26
            for i in 0 ..< n {
                let r1 = r(i, front ? 11 : 1)
                let r2 = r(i, 2), r3 = r(i, 3), r4 = r(i, 4)
                let r5 = r(i, 5), r6 = r(i, 6)
                // L'air s'accélère avec le geste — mais JAMAIS de traits
                // de vitesse (« trop cheap ») : la fumée d'envol raconte
                // le sillage, les poussières restent des poussières.
                let speed = (13 + 24 * r1) * min(max(boost, 1), 2.2)
                let period = Double(size.height) + 70
                let yUp = fract((t * speed + r2 * period * 3) / period) * period
                let y = Double(size.height) + 35 - yUp
                let x = Double(size.width) * (0.06 + 0.88 * r3)
                    + 13 * sin(t * (0.25 + 0.5 * r4) + r5 * 6.28)
                // TRÈS fines, TRÈS subtiles (loi Kathryn) : des points
                // d'un souffle, fondus aux lisières, qui scintillent à
                // peine.
                let edge = min(yUp / 90, 1) * min((period - yUp) / 90, 1)
                let flick = 0.65 + 0.35 * sin(t * (1.8 + 2.6 * r6) + r1 * 6.28)
                let sz = (front ? 0.5 : 0.7) + (front ? 0.8 : 1.2) * r2
                let rect = CGRect(x: x - sz / 2, y: y - sz / 2,
                                  width: sz, height: sz)
                ctx.opacity = (front ? 0.18 : 0.28) * edge * flick
                ctx.fill(Ellipse().path(in: rect), with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - La cage SceneKit

/// L'hôte du sachet : 60 fps (la découpe et les étincelles sont des
/// mouvements continus), gestes UIKit — le hit-test décide si le doigt
/// fait tourner le sachet ou tranche la bande (la découpe ne s'arme que
/// recto posé face caméra).
private final class BoosterPoseSCNView: SCNView {
    var apresLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        apresLayout?()
    }
}

struct BoosterStage: UIViewRepresentable {
    var still: Bool
    var frozenTear: Float?
    /// LA DÉCHIRURE HÉRITÉE de la card 2D (BoosterCard.swift) : le sachet
    /// arrive au manège DÉJÀ MORDU à s (0…1) — l'état « entamé, pas fini » de
    /// `pan(.ended)`, que le doigt reprend là où la card l'a laissé. nil =
    /// sachet intact. Les réglages de banc (`frozenTear`, `startOpen`)
    /// gardent la priorité.
    var dechirureDepart: Float? = nil
    var startOpen: Bool
    var startDos: Bool = false
    var mylar: Bool = false
    var frozenYawDeg: Float? = nil
    var gallery: Bool = false
    var cine: Bool = false
    var handle: BoosterHandle? = nil
    /// Le FLOW APP : l'engagement tire la vraie carte au serveur.
    var forge: Bool = false
    /// LA PAUSE PILOTÉE : un SCNView effacé par l'opacité REND QUAND
    /// MÊME à 60 fps — le géant du profil scrollé hors de vue coûtait
    /// 560×700 en continu sous toute la page.
    var paused: Bool = false
    /// Un décor visible peut dormir sans disparaître : conserver sa pose
    /// en image et détacher la scène. Réservé au sachet non interactif du
    /// Profil ; le manège et le sachet manipulable gardent leurs gestes.
    var poseAuRepos: Bool = false
    /// Le profil présente son sachet à 30 Hz ; les autres hôtes gardent
    /// leur cadence, notamment la cérémonie à 60 Hz.
    var preferredFramesPerSecond: Int = 60
    /// LE DÉCOR INTERACTIF (la porte, 22-08, PLAN-V2-MANEGE.md) : PAN
    /// SEULEMENT. Le tap et le maintien ne sont pas installés — l'engagement
    /// (commitGallery, dont le tap est le SEUL appelant) devient
    /// inatteignable par construction. La rotation au doigt, la pichenette
    /// et le gyro restent entiers.
    var panOnly: Bool = false
    /// LE DÉCOR SILENCIEUX : la galerie sans sa nappe (`BoosterAmbience`).
    /// Sur un écran d'entrée, la musique du manège n'a rien à faire — et la
    /// porte-nappe de `placingStep` est satisfaite par l'horloge seule.
    var muet: Bool = false
    /// LA ROBE du sachet (`.lune` par défaut : la porte, le géant du profil
    /// et le four ne changent pas). `.noire` = le manège des légendaires.
    var robe: RobeBooster = .lune
    /// LE CADRAGE DE DÉCOUPE dès la pose, pour le banc SANS anneau (le
    /// sachet y est déjà « présenté »). Dans le flow, c'est l'engagement qui
    /// l'installe. Le géant du profil et le décor de la porte ne le
    /// demandent pas : ils gardent leur cadrage.
    var cadreDecoupe: Bool = false

    func makeUIView(context: Context) -> SCNView {
        let view = BoosterPoseSCNView()
        view.apresLayout = { [weak coordinateur = context.coordinator] in
            coordinateur?.actualiserPose()
        }
        if NavDiagnostic.actif {
            NavDiagnostic.enregistrer(view, role: "booster") {
                [weak coordinateur = context.coordinator] in
                coordinateur?.nombreRendusDiagnostic
            }
        }
        // Transparent (15-08) : le sachet vit aussi hors des bancs — sur
        // la page profil, il émerge du sol sans boîte noire.
        view.backgroundColor = .clear
        // 2X SUR TÉLÉPHONE (le levier fluidité documenté — HDR + bloom
        // + particules + découpe au même budget GPU) ; le simulateur
        // garde 4X pour les films de banc.
        #if targetEnvironment(simulator)
        view.antialiasingMode = .multisampling4X
        #else
        view.antialiasingMode = .multisampling2X
        #endif
        view.preferredFramesPerSecond = preferredFramesPerSecond
        view.isPlaying = !paused
        view.rendersContinuously = !paused
        context.coordinator.forgeActive = forge
        context.coordinator.attach(to: view, still: still, dos: startDos,
                                   mylar: mylar, yawDeg: frozenYawDeg,
                                   gallery: gallery, muet: muet, robe: robe,
                                   cadreDecoupe: cadreDecoupe)
        context.coordinator.handle = handle
        handle?.coordinator = context.coordinator
        // La poignée arrive APRÈS `attach` : le `didSet` du mode a déjà
        // parlé dans le vide, on lui redonne l'état de départ à la main.
        context.coordinator.publishManege()
        if cine {
            context.coordinator.autoCeremony(after: 1.4)
        }
        if let s = frozenTear {
            context.coordinator.freezeTear(at: s)
        } else if startOpen {
            context.coordinator.jumpToOpen()
        } else if let s = dechirureDepart {
            context.coordinator.reprendreDechirure(depuis: s)
        }
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.pan(_:)))
        view.addGestureRecognizer(pan)
        // LE DÉCOR (`panOnly`) : ni tap ni maintien. Le tap est le SEUL
        // appelant de commitGallery — non installé, la cérémonie complète est
        // inatteignable, quoi que fasse le doigt.
        if !panOnly {
            let tap = UITapGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.tap(_:)))
            view.addGestureRecognizer(tap)
            // LA CHARGE AU MAINTIEN : le doigt posé sans déchirer. Le pan
            // garde la priorité (il convertit la charge en découpe) — le
            // long-press n'avale rien.
            let hold = UILongPressGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.hold(_:)))
            hold.minimumPressDuration = 0.18
            hold.cancelsTouchesInView = false
            view.addGestureRecognizer(hold)
        // SANS delegate, UIKit interdit pan et long-press ENSEMBLE : le
        // doigt posé 0,18 s (la charge — le geste appris) empêchait le
        // pan de naître pour tout le reste du toucher, et la découpe ne
        // pouvait JAMAIS prendre le relais du maintien. Le relais
        // `adoptHoldIntoTear` suppose cette simultanéité.
            hold.delegate = context.coordinator
            context.coordinator.holdRecognizer = hold
        }
        pan.delegate = context.coordinator
        // L'HORLOGE DE LA MISE EN PLACE ATTEND LES PIXELS : le delegate
        // de rendu dit quand la scène a VRAIMENT dessiné (sur téléphone,
        // Metal compile les pipelines à la première frame — le
        // CADisplayLink tiquait pendant ce temps et la roue se
        // dévissait sur une vue NOIRE : « il manque l'arrivée »).
        view.delegate = context.coordinator
        context.coordinator.panRecognizer = pan
        if CommandLine.arguments.contains("-boosterHoldDemo") {
            context.coordinator.holdDemo()
        }
        context.coordinator.appliquerRepos(paused: paused, poseVisible: poseAuRepos)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // La pause du rendu suit l'hôte (le scroll, la planque) — le
        // teardown, lui, reste le seul démontage. JAMAIS réveiller une
        // vue GELÉE par le raccord (extinguishForHandoff) : sa dernière
        // frame doit dormir sous la CarteVivante — un updateUIView de
        // scroll la relançait.
        guard !context.coordinator.frozen else { return }
        if uiView.preferredFramesPerSecond != preferredFramesPerSecond {
            uiView.preferredFramesPerSecond = preferredFramesPerSecond
        }
        context.coordinator.appliquerRepos(paused: paused, poseVisible: poseAuRepos)
    }

    /// LE MANÈGE NE DOIT PAS SURVIVRE À SON ÉCRAN. Sans ce démontage, sa
    /// nappe continuait de chanter par-dessus la home après le chevron :
    /// un `CADisplayLink` retient sa cible, donc le coordinateur — et son
    /// moteur audio — ne mouraient jamais. Voir `Coordinator.teardown()`.
    static func dismantleUIView(_ uiView: SCNView,
                                coordinator: Coordinator) {
        coordinator.teardown()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: le chef d'orchestre

    final class Coordinator: NSObject, UIGestureRecognizerDelegate,
                             SCNSceneRendererDelegate {
        private weak var view: SCNView?
        private var pauseDemandee = false
        private var poseDemandee = false
        private var imageDeRepos: UIImageView?
        private var taillePose = CGSize.zero
        private var capturePoseEnCours = false

        func appliquerRepos(paused: Bool, poseVisible: Bool) {
            pauseDemandee = paused
            poseDemandee = poseVisible
            actualiserPose()
        }

        func actualiserPose() {
            guard !demonte, !frozen, !capturePoseEnCours, let view else { return }
            capturePoseEnCours = true
            defer { capturePoseEnCours = false }
            if pauseDemandee {
                imageDeRepos?.removeFromSuperview()
                imageDeRepos = nil
                setPaused(true)
                return
            }
            guard poseDemandee else {
                setPaused(false)
                imageDeRepos?.removeFromSuperview()
                imageDeRepos = nil
                return
            }
            // La première mise à jour précède parfois le layout. Attendre
            // sa taille réelle évite de garder une capture vide au montage.
            guard view.bounds.width > 0, view.bounds.height > 0 else { return }
            if imageDeRepos == nil || taillePose != view.bounds.size {
                setPaused(false)
                let pose = view.snapshot()
                let image = imageDeRepos ?? UIImageView()
                image.image = pose
                image.frame = view.bounds
                image.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                image.isUserInteractionEnabled = false
                image.accessibilityIdentifier = "booster-pose-repos"
                if image.superview == nil { view.addSubview(image) }
                imageDeRepos = image
                taillePose = view.bounds.size
                NavDiagnostic.noter("booster-pose-repos", destination: "image-visible")
            }
            setPaused(true)
        }
        /// La scène a mis de VRAIS pixels à l'écran — flag + IDENTITÉ
        /// de scène lus/écrits ENSEMBLE sous verrou (fil de rendu ↔
        /// main). L'identité protège le replay : une frame de
        /// l'ANCIENNE scène qui se complète après le re-gate ne doit
        /// pas ouvrir la porte.
        private let renderGate = OSAllocatedUnfairLock<
            (rendered: Bool, scene: ObjectIdentifier?, rendusDiagnostic: UInt64)>(
            initialState: (false, nil, 0))

        var sceneDidRender: Bool {
            renderGate.withLock { $0.rendered }
        }

        /// Total des callbacks de rendu terminés par ce coordinateur ;
        /// lu à 1 Hz par le diagnostic, sans accès au moteur SceneKit.
        var nombreRendusDiagnostic: UInt64 {
            renderGate.withLock { $0.rendusDiagnostic }
        }

        // Fil de rendu SceneKit : ne toucher NI SceneKit NI UIKit ici.
        func renderer(_ renderer: SCNSceneRenderer,
                      didRenderScene scene: SCNScene,
                      atTime time: TimeInterval) {
            renderGate.withLock {
                if NavDiagnostic.actif { $0.rendusDiagnostic &+= 1 }
                if $0.scene == ObjectIdentifier(scene) {
                    $0.rendered = true
                }
            }
        }
        private var stage: BoosterScene?
        /// LA MORSURE HÉRITÉE de la card (`reprendreDechirure`) : « rien de
        /// plus que ce que la card a fait » = un sachet encore INTACT du point
        /// de vue du manège. Les gardes `tearProgress == 0` (l'invite, la
        /// charge au maintien, le retour à l'anneau, le tell de rareté, le
        /// soupir) comparent à ELLE, sinon elles meurent toutes dès que le
        /// sachet naît mordu (relecture adverse, 30-08). Remise à 0 à chaque
        /// `attach`.
        private var morsureHeritee: Float = 0
        /// La poignée du raccord CarteVivante (nil hors handoff).
        weak var handle: BoosterHandle?
        /// La paire pan/hold — la SEULE autorisée à se reconnaître
        /// ensemble (le tap reste exclusif).
        weak var panRecognizer: UIPanGestureRecognizer?
        weak var holdRecognizer: UILongPressGestureRecognizer?
        /// GELÉE par le raccord CarteVivante : la pause pilotée
        /// (updateUIView) n'a plus le droit de la réveiller.
        var frozen = false

        func gestureRecognizer(
            _ g: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer)
            -> Bool {
            (g === panRecognizer && other === holdRecognizer)
                || (g === holdRecognizer && other === panRecognizer)
        }
        private var still = false
        private var dos = false
        private var mylar = false
        private var yawDeg: Float?
        private var galleryOn = false
        /// La robe portée par la scène en place — le rejeu (`replay`, le tap
        /// de réarmement) reconstruit une scène : sans mémoire, il repasserait
        /// au sachet du set Lune au milieu d'un manège noir.
        private var robe: RobeBooster = .lune
        /// Le banc l'a demandé (sans anneau), et il est POSÉ en ce moment :
        /// `finishTear` ne rend le cadrage canonique que s'il l'a pris.
        private var cadreDecoupeDemande = false
        private var cadreDecoupeActif = false
        /// La forge serveur ne tire que dans le FLOW APP (les bancs
        /// rejouent la cérémonie à volonté — pas un tirage par replay).
        var forgeActive = false
        private var forgeLancee = false
        private var ouvertureDifferee = false

        private enum Mode {
            case idle, spinning, tearing, opening, revealed
            case placing, galleryIdle, galleryScrub, galleryFly, ringSpin
            case committing, maybeBack, backingOut
        }
        private var mode: Mode = .idle {
            didSet {
                // LE CHEVRON DE SORTIE N'EXISTE QU'AU MANÈGE. Il meurt à
                // l'engagement du sachet — une fois l'ouverture lancée, la
                // séquence va au bout : on n'interrompt pas un sacre — et
                // il renaît si la main ressort à l'anneau.
                let au = mode == .galleryIdle || mode == .galleryScrub
                    || mode == .galleryFly || mode == .ringSpin
                if handle?.auManege != au { handle?.auManege = au }
                // LE FILET DE LA VIE (galerie) : chaque retour à .idle
                // DEPUIS UN ÉTAT DE GESTE s'assure que le sachet posé
                // respire et que l'invite veille — les deux appels sont
                // idempotents (bob déjà posé = no-op ; timer vivant =
                // pas de re-timer). Jamais depuis les cinématiques :
                // un .idle né de .opening/.placing serait un bug, pas
                // une occasion d'armer des animations dessus.
                if mode == .idle, galleryOn,
                   oldValue == .tearing || oldValue == .spinning
                       || oldValue == .maybeBack || oldValue == .committing {
                    stage?.beginIdleBreath()
                    if inviteTimer == nil { startInvite() }
                }
            }
        }
        /// Les mains et l'oreille du manège.
        private let haptics = BoosterHaptics()
        private var ambience: BoosterAmbience?
        private var sfx: BoosterSFX?
        /// Le geste de découpe, côté sensations : vitesse lissée du doigt,
        /// distance accumulée depuis le dernier crépitement, seuil tiré
        /// au sort (les pops suivent la DISTANCE déchirée, pas le temps —
        /// une déchirure lente crépite lentement, comme du vrai foil).
        private var tearBedV: Float = 0
        private var tearAccum: Float = 0
        private var tearPrev: Float = 0
        private var popThreshold: Float = 0.03
        /// L'horloge de l'invite : tant que le sachet posé n'est pas
        /// mordu, la lueur fantôme balaie la ligne toutes les ~4 s.
        private var inviteTimer: Timer?
        private var inviteWanted = false
        private var hostPaused = false
        private var demonte = false
        private var sceneSuspendue: (scene: SCNScene, camera: SCNNode?,
                                      temps: TimeInterval)?

        private func startInvite() {
            guard !demonte, !frozen else { return }
            inviteWanted = true
            inviteTimer?.invalidate()
            inviteTimer = nil
            guard !hostPaused else { return }
            let timer = Timer(fire: Date().addingTimeInterval(1.4),
                              interval: 4.2, repeats: true) { [weak self] _ in
                guard let self, let stage = self.stage else { return }
                guard self.mode == .idle,
                      stage.tearProgress <= self.morsureHeritee,
                      self.restingFront else {
                    // SENTINELLE : un sweep sauté pour cause de
                    // non-recto était invisible — c'est ce silence qui
                    // a rendu « impossible de déchirer » indéchiffrable.
                    if self.mode == .idle,
                       stage.tearProgress <= self.morsureHeritee {
                        print("[booster] sweep sauté : non-recto yaw=\(self.yaw)")
                    }
                    return
                }
                stage.inviteSweep()
            }
            RunLoop.main.add(timer, forMode: .common)
            inviteTimer = timer
        }

        private func stopInvite() {
            inviteWanted = false
            inviteTimer?.invalidate()
            inviteTimer = nil
        }

        /// Sur téléphone, isPlaying/rendersContinuously à false et une
        /// scène pausée rendaient encore à 30 Hz derrière le profil invisible.
        /// On détache la scène du renderer, en gardant ses objets, sa caméra
        /// et son temps pour le retour. Aucun attach/teardown ni Sacre.
        func setPaused(_ paused: Bool) {
            guard !demonte, !frozen, let view else { return }
            if paused {
                if view.isPlaying { view.isPlaying = false }
                if view.rendersContinuously { view.rendersContinuously = false }
                if let scene = view.scene {
                    scene.isPaused = true
                    sceneSuspendue = (scene, view.pointOfView, view.sceneTime)
                    view.scene = nil
                }
            } else {
                if let suspendue = sceneSuspendue {
                    // Un replay peut avoir posé une nouvelle scène : ne
                    // jamais lui rendre la caméra ou le temps de l'ancienne.
                    if view.scene == nil, let scene = stage?.scene,
                       scene === suspendue.scene {
                        view.scene = scene
                        view.pointOfView = suspendue.camera
                        view.sceneTime = suspendue.temps
                    }
                    sceneSuspendue = nil
                }
                if view.scene?.isPaused == true { view.scene?.isPaused = false }
                if !view.isPlaying { view.isPlaying = true }
                if !view.rendersContinuously { view.rendersContinuously = true }
            }
            if !paused, ouvertureDifferee, handle?.cartePrete == true {
                ouvertureDifferee = false
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.demonte, !self.hostPaused else { return }
                    self.finishTear()
                }
            }
            guard hostPaused != paused else { return }
            hostPaused = paused
            if paused { haptics.suspend() }
            if NavDiagnostic.actif {
                let scene = paused ? sceneSuspendue?.scene : view.scene
                let camera = paused ? sceneSuspendue?.camera : view.pointOfView
                let idScene = scene.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
                let idCamera = camera.map { String(describing: ObjectIdentifier($0)) } ?? "nil"
                let temps = paused ? sceneSuspendue?.temps ?? view.sceneTime : view.sceneTime
                NavDiagnostic.noter(paused ? "booster-pause" : "booster-reprise",
                    destination: "vue=\(ObjectIdentifier(view));scene=\(idScene);"
                        + "camera=\(idCamera);sceneTime=\(temps);rendus=\(nombreRendusDiagnostic)")
            }
            for link in [holdLink, spinLink, scrollLink, placingLink,
                         ringSpinLink, gyroLink] {
                link?.isPaused = paused
            }
            if paused {
                // Garder l'intention, pas le Timer : aucun réveil à 4,2 s.
                inviteTimer?.invalidate()
                inviteTimer = nil
                if motionClient {
                    motionClient = false
                    LuneMotion.shared.stop()
                }
                if holdLink != nil { haptics.bedStop() }
            } else {
                if inviteWanted { startInvite() }
                if gyroLink != nil, !motionClient {
                    motionClient = true
                    LuneMotion.shared.start()
                }
                if holdLink != nil { haptics.bedStart() }
            }
        }
        // ---- LA CHARGE AU MAINTIEN (le doigt posé sans déchirer) ----
        /// La lune monte en incandescence sous le doigt immobile ; le
        /// relâcher est LE SOUPIR (tout redescend, rendu pas puni) ; la
        /// déchirure qui démarre HÉRITE du plancher de charge.
        private var holdLink: CADisplayLink?
        private var holdCharge: Float = 0
        private var holdReleasing = false
        private var holdLast: CFTimeInterval = 0

        @objc func hold(_ g: UILongPressGestureRecognizer) {
            guard let view, let stage else { return }
            switch g.state {
            case .began:
                guard mode == .idle, restingFront,
                      stage.tearProgress <= morsureHeritee,
                      holdLink == nil else { return }
                let hits = view.hitTest(g.location(in: view),
                                        options: [.ignoreHiddenNodes: true])
                guard hits.contains(where: { $0.node === stage.bodyNode
                        || $0.node === stage.capNode }) else { return }
                startHold()
            case .ended, .cancelled, .failed:
                beginHoldRelease()
            default:
                break
            }
        }

        func startHold() {
            guard !demonte, !frozen else { return }
            guard holdLink == nil else { return }
            stopInvite()
            // Le pulse du tell rendrait folles les écritures `lipGlow`
            // de la charge — il se tait sous le doigt.
            stage?.retirerShinyLeak()
            holdReleasing = false
            holdLast = CACurrentMediaTime()
            haptics.bedStart()
            let link = CADisplayLink(target: self,
                                     selector: #selector(holdStep(_:)))
            link.isPaused = hostPaused
            link.add(to: .main, forMode: .common)
            holdLink = link
        }

        @objc private func holdStep(_ link: CADisplayLink) {
            guard let stage else { stopHold(); return }
            let now = CACurrentMediaTime()
            let dt = Float(min(now - holdLast, 1.0 / 20))
            holdLast = now
            if holdReleasing {
                holdCharge -= dt / 0.7
                if holdCharge <= 0 { stopHold(); return }
            } else {
                let was = holdCharge
                holdCharge = min(holdCharge + dt / 1.6, 1)
                // Le plateau : un petit verrou dans la paume — elle est
                // pleine, tu peux déchirer.
                if was < 1, holdCharge >= 1 { haptics.lock() }
            }
            stage.setHoldCharge(CGFloat(holdCharge))
            haptics.bedIntensity(holdReleasing
                ? 0.18 * holdCharge
                : 0.05 + 0.22 * holdCharge)
        }

        func beginHoldRelease() {
            // Le soupir est TOUJOURS légitime au lever : gardé sur
            // `mode == .idle`, un doigt parti en rotation laissait la
            // charge orpheline — vibration perpétuelle, lune
            // incandescente figée.
            guard holdLink != nil, !holdReleasing else { return }
            holdReleasing = true
            haptics.exhale()
        }

        private func stopHold() {
            holdLink?.invalidate()
            holdLink = nil
            holdCharge = 0
            holdReleasing = false
            stage?.setHoldCharge(0)
            haptics.bedIntensity(0)
            haptics.bedStop()
            if mode == .idle { startInvite() }
            // Le soupir rend son tell au sachet intact.
            if let stage, stage.tearProgress <= morsureHeritee {
                stage.poserShinyLeak()
            }
        }

        /// La découpe prend le relais du maintien : le plancher de
        /// charge passe à setTear (la lune ne retombe pas), la lèvre
        /// rend l'antenne, le lit haptique reste à la main du geste.
        private func adoptHoldIntoTear() {
            guard holdLink != nil, let stage else { return }
            stage.holdChargeFloor = CGFloat(0.55 * holdCharge)
            holdLink?.invalidate()
            holdLink = nil
            holdReleasing = false
            holdCharge = 0
            for node in [stage.bodyNode, stage.capNode] {
                node.geometry?.firstMaterial?
                    .setValue(0.0 as CGFloat, forKey: "lipGlow")
            }
        }

        /// Le banc filmé de la charge (`-boosterHoldDemo`) : maintien →
        /// soupir → maintien → la découpe prend le relais (simctl ne
        /// sait pas poser un doigt).
        func holdDemo() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                [weak self] in self?.startHold()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
                [weak self] in self?.beginHoldRelease()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
                [weak self] in self?.startHold()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.6) {
                [weak self] in self?.autoCeremony(after: 0)
            }
        }

        /// Le geste en cours : écran → progression, calé au premier point.
        private var tearOriginX: CGFloat = 0
        private var tearSpanX: CGFloat = 1
        private var tearStartProgress: Float = 0
        private let tick = UIImpactFeedbackGenerator(style: .light)

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

        // ---- le défilement de l'anneau ----
        /// La rotation en crans flottants (sans butées : c'est un cercle),
        /// l'élan, la cible du ressort, le lien.
        private var offset: Float = 0
        private var scrollVel: Float = 0
        private var scrollTarget: Float = 0
        private var grabOffset: Float = 0
        private var scrollLink: CADisplayLink?
        private var lastCenterSlot = 0
        /// Le clone engagé et la rotation au moment de l'engagement (pour
        /// le retour à l'anneau).
        private var selectedSlot = 0
        private var commitOffset: Float = 0
        /// Écran → crans : ~190 pt par sachet.
        private static let slotPoints: Float = 190
        /// Le dernier cran vu par le lit haptique du scrub.
        private var lastScrubOffset: Float = 0

        // ---- la mise en place cinématique ----
        private var placingLink: CADisplayLink?
        /// L'horloge de la mise en place, en PAS BORNÉS — jamais
        /// murale : un gel RALENTIT le vol, il ne le saute plus.
        /// L'ARRIVÉE ROYALE : t = 0 À LA PREMIÈRE IMAGE (le rideau est
        /// porté par la porte-nappe + les départs des beats). Vol
        /// caméra 0,6→2,6 vers un z ENFONCÉ (3,96) puis l'assise
        /// 2,6→2,9 vers 4,0 — l'école du dolly d'engagement (2,02→2,05).
        private var placingT: Float = 0
        private var placingLast: CFTimeInterval = 0
        private static let placingZOver: Float = 3.96
        private static let placingRoll: Float = -4 * .pi / 180
        private static let placingFlightEnd: Float = 2.6
        private static let placingPose: Float = 2.9
        /// Le départ de la nappe (horloge MURALE légitime : on
        /// synchronise l'AUDIO, qui court en temps mural).
        private var nappeT0: CFTimeInterval = 0
        /// L'atterrissage n'a droit qu'à UN verrou + UNE bouffée.
        private var landed = false

        // ---- le spin du sachet central DANS l'anneau ----
        /// Lacet propre du clone centré (0 = face à la caméra), son élan,
        /// sa prise, son lien de vol.
        private var cloneYaw: Float = 0
        private var cloneVel: Float = 0
        private var cloneGrab: Float = 0
        private var ringSpinLink: CADisplayLink?
        /// LA PARALLAXE DU POIGNET (galerie, téléphone seulement) :
        /// l'anneau contre-pivote de ~±1,6° avec l'inclinaison — la
        /// profondeur sans un geste. Muette dès qu'un autre écrivain
        /// tient l'anneau (doigt, aimant, engagement).
        private var gyroLink: CADisplayLink?

        /// L'index de clone au centre pour une rotation donnée.
        private func centerIndex(_ off: Float) -> Int {
            let n = BoosterScene.ringCount
            return ((Int(off.rounded()) % n) + n) % n
        }

        func attach(to view: SCNView, still: Bool, dos: Bool = false,
                    mylar: Bool = false, yawDeg: Float? = nil,
                    gallery: Bool = false, muet: Bool = false,
                    robe: RobeBooster = .lune,
                    cadreDecoupe: Bool = false) {
            self.view = view
            morsureHeritee = 0
            self.still = still
            self.dos = dos
            self.mylar = mylar
            self.yawDeg = yawDeg
            self.galleryOn = gallery
            self.robe = robe
            self.cadreDecoupeDemande = cadreDecoupe
            self.cadreDecoupeActif = false
            stopSpin()
            stopScroll()
            stopInvite()
            stopGalleryGyro()
            guard let stage = BoosterScene(still: still, mylar: mylar,
                                           gallery: gallery,
                                           robe: robe) else { return }
            self.stage = stage
            // Le re-gate AVANT la pose de la scène (chaque scène neuve
            // attend SA première frame rendue), et le delegate ici —
            // attach est le chemin commun makeUIView + replay.
            renderGate.withLock {
                $0.rendered = false
                $0.scene = ObjectIdentifier(stage.scene)
            }
            view.delegate = self
            view.scene = stage.scene
            view.pointOfView = stage.cameraNode
            yaw = yawDeg.map { $0 * .pi / 180 } ?? (dos ? 0 : .pi)
            yawVel = 0
            pitch = 0
            applyPose()
            // Le banc SANS anneau montre l'état « présenté » : il porte donc
            // le cadrage de découpe dès la pose. Dans le flow, c'est
            // l'engagement qui l'installe (et `finishTear` qui le rend).
            if cadreDecoupe, !gallery {
                stage.cameraNode.position = SCNVector3(
                    0, Self.cadreDechirure.y, 2.05)
                stage.cameraNode.camera?.fieldOfView = Self.cadreDechirure.fov
                cadreDecoupeActif = true
            }
            if gallery {
                offset = 0
                scrollTarget = 0
                scrollVel = 0
                lastCenterSlot = 0
                selectedSlot = 0
                commitOffset = 0
                cloneYaw = 0
                cloneVel = 0
                stopRingSpin()
                stopPlacing()
                if still {
                    stage.applyGallery(offset: offset)
                    mode = .galleryIdle
                } else {
                    // BEAT 0 — L'OREILLE ARRIVE AVANT L'ŒIL : la nappe
                    // part ICI, elle n'attend jamais les pixels (la
                    // porte-nappe de placingStep retient l'IMAGE 0,25 s).
                    // Attaque 0,9 s — à 2,4 s elle était inaudible au
                    // lever de rideau (fondu linéaire).
                    // LE DÉCOR (`muet`, la porte) : pas de nappe — mais
                    // `nappeT0` se pose QUAND MÊME : la porte-nappe de
                    // placingStep est une horloge, elle doit passer.
                    if !muet {
                        ambience = BoosterAmbience()
                        ambience?.act(BoosterAmbience.manege, over: 0.9)
                    }
                    nappeT0 = CACurrentMediaTime()
                    beginPlacing()
                }
                startGalleryGyro()
            } else {
                mode = .idle
                if !still { startInvite() }
            }
        }

        /// LA POSE REJOUÉE (la porte, 22-08) : la cinématique de mise en
        /// place, à la demande — le décor la rejoue à CHAQUE arrivée sur sa
        /// page. `beginPlacing` remet lui-même caméra, feux, studio et offset
        /// à zéro ; pendant qu'il joue, le gyro se tait tout seul (il n'écrit
        /// qu'en `.galleryIdle`). Une ligne, parce que `beginPlacing` est
        /// privé et que `BoosterHandle.coordinator` n'expose que l'interne.
        func rejoueLaPose() {
            guard stage != nil else { return }
            stopScroll()
            stopRingSpin()
            beginPlacing()
        }

        /// LE DÉMONTAGE — sans lui, LE MANÈGE CONTINUE DE CHANTER après
        /// le chevron (verdict Kathryn, 15-08). Deux causes empilées :
        ///
        /// 1. un `CADisplayLink` **RETIENT sa cible**. Tant qu'un seul
        ///    tourne encore — le gyro, le défilement, l'anneau —, le
        ///    coordinateur ne meurt jamais, donc son `deinit` (qui arrête
        ///    le moteur audio) n'est jamais appelé : la nappe du manège
        ///    joue par-dessus la home, indéfiniment ;
        /// 2. CoreMotion continue de réveiller le fil principal soixante
        ///    fois par seconde pour une scène que personne ne regarde.
        ///
        /// Le son SORT en fondu : l'ambiance est retenue le temps qu'il
        /// s'achève, parce que son `deinit` couperait le moteur net.
        func teardown() {
            guard !demonte else { return }
            demonte = true
            imageDeRepos?.removeFromSuperview()
            imageDeRepos = nil
            (view as? BoosterPoseSCNView)?.apresLayout = nil
            hostPaused = true
            stopSpin()
            stopScroll()
            stopPlacing()
            stopRingSpin()
            stopGalleryGyro()
            // stopHold AVANT stopInvite : stopHold relance l'invite
            // quand mode == .idle — dans l'autre ordre, un Timer 4,2 s
            // ressuscité survivait au démontage pour toujours.
            stopHold()
            stopInvite()
            // On ne rend QUE le crédit qu'on a pris : le teardown du
            // géant du profil (gallery: false, jamais client) tuait le
            // poignet de TOUTE l'app — manège compris, en plein vol.
            if motionClient {
                motionClient = false
                LuneMotion.shared.stop()
            }
            // SCNView.delegate est `unowned(unsafe)` (assign ObjC, pas
            // weak-zeroing) : une frame en vol sur le fil de rendu peut
            // appeler un coordinateur MORT si la SCNView survit à la
            // transition de démontage.
            view?.delegate = nil
            // La musique de la carte s'en va aussi : on peut quitter le
            // Sacre depuis l'étage de résultat, en pleine plongée.
            // (Le démontage n'est pas isolé au fil principal, elle si.)
            DispatchQueue.main.async { LuneSacre.shared.sortir() }
            let sortante = ambience
            sortante?.silence(over: 0.55)
            ambience = nil
            sfx = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                // La retenir jusqu'ici : relâchée plus tôt, son `deinit`
                // arrêterait le moteur au milieu du fondu.
                _ = sortante
            }
            view?.isPlaying = false
            view?.rendersContinuously = false
            // Une action SceneKit ou un rappel déjà en file peut retenir le
            // coordinateur après dismantle. Couper aussi sa scène empêche
            // ces fins de cérémonie de rallumer un moteur hors écran.
            stage?.scene.isPaused = true
            stage?.scene.rootNode.removeAllActions()
            stage?.scene.rootNode.enumerateChildNodes { node, _ in
                node.removeAllActions()
                node.removeAllAnimations()
                node.removeAllParticleSystems()
            }
            view?.scene = nil
            sceneSuspendue = nil
            stage = nil
            haptics.shutdown()
            handle?.coordinator = nil
            handle = nil
            NavDiagnostic.noter("booster-demontage",
                destination: "scene=0;liens=0;gyro=0;haptique=0")
            print("[booster-bench] démontage : liens coupés, gyro arrêté, "
                  + "sonnant=\(BoosterAmbience.sounding)")
        }

        /// Republie l'état « au manège » vers la poignée — elle est
        /// branchée APRÈS `attach`, donc le premier `didSet` du mode
        /// a parlé dans le vide.
        func publishManege() {
            let au = mode == .galleryIdle || mode == .galleryScrub
                || mode == .galleryFly || mode == .ringSpin
            handle?.auManege = au
        }

        /// CE coordinateur est-il client du poignet ? UN seul crédit
        /// LuneMotion par coordinateur, rendu au teardown — le géant et
        /// le trône (gallery: false) n'en prennent jamais : leur
        /// démontage ne doit plus tuer le gyro du manège en plein vol.
        private var motionClient = false

        private func startGalleryGyro() {
            guard !demonte, !frozen else { return }
            guard gyroLink == nil else { return }
            if !motionClient, !hostPaused {
                motionClient = true
                LuneMotion.shared.start()
            }
            let link = CADisplayLink(target: self,
                                     selector: #selector(gyroStep(_:)))
            link.isPaused = hostPaused
            link.add(to: .main, forMode: .common)
            gyroLink = link
        }

        private func stopGalleryGyro() {
            gyroLink?.invalidate()
            gyroLink = nil
        }

        /// Le dernier biais gyro écrit — la BANDE MORTE (école du
        /// calendrier) : poignet immobile = zéro écriture de scène.
        private var gyroLastBias: Float = .greatestFiniteMagnitude

        @objc private func gyroStep(_ link: CADisplayLink) {
            // Au repos SEULEMENT : un seul écrivain par pose d'anneau.
            guard let stage, mode == .galleryIdle,
                  scrollLink == nil, ringSpinLink == nil,
                  LuneMotion.shared.live else { return }
            let bias = 0.045 * LuneMotion.shared.tilt.x
            guard abs(bias - gyroLastBias) > 0.0005 else { return }
            gyroLastBias = bias
            // `centerSpin` : la pichenette posée du sachet central
            // survit au poignet — sans elle, la frame gyro qui suit un
            // settle dos faisait CLAQUER le sachet face caméra.
            stage.applyGallery(offset: offset + bias, centerSpin: cloneYaw)
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
            // LE TRIPLET ENTIER depuis la base canonique — écrire une
            // composante seule relit l'euler décomposé et peut retomber
            // sur la forme alternative : le sachet couché une frame.
            stage.packNode.eulerAngles = SCNVector3(pitch, yaw, 0)
            SCNTransaction.commit()
        }

        private func startSpin() {
            guard !demonte, !frozen else { return }
            stopSpin()
            let link = CADisplayLink(target: self, selector: #selector(spinStep(_:)))
            link.isPaused = hostPaused
            link.add(to: .main, forMode: .common)
            spinLink = link
        }

        private func stopSpin() {
            spinLink?.invalidate()
            spinLink = nil
        }

        // MARK: la mise en place cinématique

        /// La braise s'allume, la roue freinée se dévisse jusqu'à sa place,
        /// les feux montent en cascade (le fond d'abord, le central en
        /// dernier), la caméra recule — ~1,45 s, gestes verrouillés.
        private func beginPlacing() {
            guard !demonte, !frozen else { return }
            guard let stage else { return }
            mode = .placing
            stage.floorNode.opacity = 0
            stage.floorGlowNode.opacity = 0
            // L'ARRIVÉE ROYALE : la caméra part TRÈS LOIN et HAUTE,
            // penchée sur l'anneau, au télé serré, LE ROULIS DÉJÀ DANS
            // LA POSE D'ATTENTE (sinon il claque au premier tick) —
            // toujours le TRIPLET entier.
            stage.cameraNode.position = SCNVector3(0, 1.6, 7.5)
            stage.cameraNode.eulerAngles = SCNVector3(-0.34, 0,
                                                      Self.placingRoll)
            stage.cameraNode.camera?.fieldOfView = 34
            for i in 0 ..< BoosterScene.ringCount { stage.galleryLight[i] = 0 }
            for i in 0 ..< BoosterScene.ringCount { stage.moonLight[i] = 0 }
            // LE VRAI NOIR de la constellation : le studio s'éteint
            // (key/embers/IBL peignent les corps physicallyBased sans
            // une émission), le rim est scalé par galleryLight dans
            // applyGallery.
            stage.setGalleryStudio(0)
            offset = -1.45
            stage.applyGallery(offset: offset)
            // L'HORLOGE EN PAS BORNÉS, jamais murale (deux pièges
            // payés) : (1) murale posée à l'attach, 72 % du dévissage
            // brûlait sous le fondu d'entrée ; (2) même paresseuse, la
            // PREMIÈRE ouverture du process compile les shaders Metal
            // PENDANT la roue — les frames gelées sautaient la
            // cinématique. Chaque frame avance d'un pas plafonné : un
            // gel RALENTIT l'arrivée d'un souffle, il ne peut plus la
            // sauter. t = 0 à la première image.
            placingT = 0
            placingLast = 0
            landed = false
            let link = CADisplayLink(target: self,
                                     selector: #selector(placingStep(_:)))
            link.isPaused = hostPaused
            link.add(to: .main, forMode: .common)
            placingLink = link
        }

        private func stopPlacing() {
            placingLink?.invalidate()
            placingLink = nil
        }

        @objc private func placingStep(_ link: CADisplayLink) {
            guard let stage else {
                stopPlacing()
                return
            }
            // Fenêtre pas encore là (montage en transaction lourde) : on
            // SAUTE la frame, le lien vit — le tuer figeait le manège à
            // jamais, feux éteints, sans un mot.
            guard view?.window != nil else { return }
            // LES PIXELS D'ABORD : tant que la scène n'a pas rendu sa
            // première vraie frame (compilation Metal en cours), le
            // rideau ne se lève pas — la roue ne se dévisse JAMAIS sur
            // une vue noire.
            guard sceneDidRender else { return }
            // La nappe chante 0,25 s DANS LE NOIR avant le rideau —
            // partie à l'attach, elle n'attend pas les pixels ; ici
            // seule l'IMAGE attend (horloge murale LÉGITIME : c'est
            // l'audio qu'on synchronise, pas la scène).
            guard CACurrentMediaTime() - nappeT0 >= 0.25 else { return }
            if placingLast == 0 {
                // Le rideau : le sol s'allume pendant le fondu d'entrée.
                placingLast = link.timestamp
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.4
                stage.floorNode.opacity = 1
                SCNTransaction.commit()
                return
            }
            let dt = Float(min(link.timestamp - placingLast, 1.0 / 30))
            placingLast = link.timestamp
            placingT += dt
            let t = placingT
            let n = BoosterScene.ringCount

            // BEAT 1 — la lueur du CENTRE : monte 0→0,5, RETOMBE
            // 1,4→2,6 (l'état posé = aujourd'hui, nappe éteinte). Sur
            // l'horloge bornée — une SCNTransaction murale se ferait
            // manger par un gel Metal.
            let gRise = min(max(t / 0.5, 0), 1)
            let gFall = min(max((t - 1.4) / 1.2, 0), 1)
            stage.floorGlowNode.opacity = CGFloat(gRise * (1 - gFall))
            let gs = 0.55 + 0.45 * gRise
            stage.floorGlowNode.scale = SCNVector3(gs, gs, gs)

            // BEAT 2 — LA CONSTELLATION : les lunes une à une dans le
            // noir, 0,3→1,35 fond→devant (les DOS aux croissants
            // ouvrent le bal) ; puis elle FOND dans les corps allumés
            // (2,15→2,6).
            let melt = min(max((t - 2.15) / 0.45, 0), 1)
            for i in 0 ..< n {
                let raw = Float(i) * 2 * .pi / Float(n)
                let theta = abs(atan2f(sinf(raw), cosf(raw)))
                let ordre = 1 - theta / .pi     // 0 = fond, 1 = devant
                let mRise = min(max((t - (0.3 + 0.8 * ordre)) / 0.25, 0), 1)
                stage.moonLight[i] = mRise * (1 - melt * melt)
                // BEAT 3b — LES CORPS pendant la plongée, 0,6→2,6
                // fond→devant (le devant finit À l'atterrissage).
                stage.galleryLight[i] =
                    min(max((t - (0.6 + 1.7 * ordre)) / 0.30, 0), 1)
            }
            // Le studio remonte AVEC les corps, smoothstep 0,6→2,6.
            let lk = min(max((t - 0.6) / 2.0, 0), 1)
            stage.setGalleryStudio(lk * lk * (3 - 2 * lk))

            // BEAT 3 — LA PLONGÉE 0,6→2,6 + roulis −4°→0 : smootherstep
            // vers un z ENFONCÉ (3,96 — l'overshoot est DANS le vol),
            // puis l'assise easeOut 2,6→2,9 vers 4,0 (l'école
            // 2,02→2,05 du dolly d'engagement).
            let c = min(max((t - 0.6) / 2.0, 0), 1)
            let s = c * c * c * (c * (c * 6 - 15) + 10)
            var z = 7.5 + (Self.placingZOver - 7.5) * s
            if t > Self.placingFlightEnd {
                let a = min((t - Self.placingFlightEnd)
                    / (Self.placingPose - Self.placingFlightEnd), 1)
                let e = 1 - (1 - a) * (1 - a)
                z = Self.placingZOver + (4.0 - Self.placingZOver) * e
            }
            stage.cameraNode.position = SCNVector3(0, 1.6 * (1 - s), z)
            // TRIPLET ENTIER, jamais une composante (le piège euler).
            stage.cameraNode.eulerAngles =
                SCNVector3(-0.34 * (1 - s), 0, Self.placingRoll * (1 - s))
            stage.cameraNode.camera?.fieldOfView = 34 + 8 * CGFloat(s)

            // BEAT 4 — LA ROUE se dévisse dès 0,8, décélération
            // cubique, calée pour FINIR AVEC l'atterrissage (dérivée
            // des constantes, jamais un magique).
            let u = min(max((t - 0.8) / (Self.placingFlightEnd - 0.8), 0), 1)
            offset = -1.45 * powf(1 - u, 3)
            stage.applyGallery(offset: offset)

            // BEAT 5 — L'ATTERRISSAGE (2,6, z au point bas) : le verrou
            // se SENT, la poudre souffle, le sachet central INSPIRE —
            // une seule fois.
            if !landed, t >= Self.placingFlightEnd {
                landed = true
                haptics.lock()
                stage.galleryDustPuff()
                stage.centerBreathIn()
            }

            // LA POSE (2,9) : les finals EXACTS écrits en dur
            // (l'horloge flottante ne les garantit pas).
            if t >= Self.placingPose {
                offset = 0
                for i in 0 ..< n {
                    stage.galleryLight[i] = 1
                    stage.moonLight[i] = 0
                }
                stage.setGalleryStudio(1)
                stage.floorGlowNode.opacity = 0
                stage.applyGallery(offset: 0)
                stage.cameraNode.position = SCNVector3(0, 0, 4.0)
                stage.cameraNode.eulerAngles = SCNVector3(0, 0, 0)
                stage.cameraNode.camera?.fieldOfView = 42
                stopPlacing()
                haptics.brake()
                mode = .galleryIdle
                // LA ROUE EST POSÉE — l'app peut éclipser la home
                // derrière le noir : la désallocation ne tombera plus
                // jamais en plein dévissage.
                if SacreEtat.shared.manegeOuvert {
                    SacreEtat.shared.manegePose = true
                }
            }
        }

        // MARK: le spin du sachet central dans l'anneau

        private func startRingSpin() {
            guard !demonte, !frozen else { return }
            stopRingSpin()
            let link = CADisplayLink(target: self,
                                     selector: #selector(ringSpinStep(_:)))
            link.isPaused = hostPaused
            link.add(to: .main, forMode: .common)
            ringSpinLink = link
        }

        private func stopRingSpin() {
            ringSpinLink?.invalidate()
            ringSpinLink = nil
        }

        private func applyCloneSpin() {
            guard let stage else { return }
            let clone = stage.galleryPacks[centerIndex(offset)]
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0
            // TRIPLET ENTIER — la composante seule relit l'euler
            // décomposé (forme alternative à lacet π : clone couché).
            clone.eulerAngles = SCNVector3(0, .pi + cloneYaw, 0)
            SCNTransaction.commit()
        }

        /// La pichenette du sachet central : même physique que la
        /// cérémonie — frein, puis aimant sur la face la plus proche
        /// (recto OU dos aux croissants).
        @objc private func ringSpinStep(_ link: CADisplayLink) {
            guard view?.window != nil else {
                stopRingSpin()
                return
            }
            let dt = Float(min(max(link.targetTimestamp - link.timestamp,
                                   1.0 / 240), 1.0 / 30))
            if abs(cloneVel) > Self.magnetBelow {
                cloneVel *= exp(-Self.friction * dt)
            } else {
                let target = (cloneYaw / .pi).rounded() * .pi
                cloneVel += (target - cloneYaw) * Self.stiffness * dt
                cloneVel *= exp(-2 * sqrtf(Self.stiffness) * dt)
                if abs(cloneYaw - target) < 0.002, abs(cloneVel) < 0.02 {
                    var settled = fmodf(target, 2 * .pi)
                    if settled < 0 { settled += 2 * .pi }
                    if settled > .pi { settled -= 2 * .pi }
                    cloneYaw = settled
                    cloneVel = 0
                    stopRingSpin()
                    applyCloneSpin()
                    haptics.lock()
                    return
                }
            }
            cloneYaw += cloneVel * dt
            applyCloneSpin()
        }

        // MARK: la galerie — défilement, engagement, retour

        private func startScroll() {
            guard !demonte, !frozen else { return }
            stopScroll()
            let link = CADisplayLink(target: self,
                                     selector: #selector(scrollStep(_:)))
            link.isPaused = hostPaused
            link.add(to: .main, forMode: .common)
            scrollLink = link
        }

        private func stopScroll() {
            scrollLink?.invalidate()
            scrollLink = nil
        }

        /// La détente quand le sachet du centre change — le clic de
        /// barillet, à chaque cran. La poudre souffle AVEC l'haptique.
        private func tickIfCenterChanged() {
            let center = Int(offset.rounded())
            if center != lastCenterSlot {
                lastCenterSlot = center
                haptics.detent()
                stage?.galleryDustPuff()
            }
        }

        /// Une frame de vol de l'anneau : ressort quasi critique vers le
        /// cran cible, avec l'élan du relâcher en entrée.
        @objc private func scrollStep(_ link: CADisplayLink) {
            guard view?.window != nil, let stage else {
                stopScroll()
                return
            }
            let dt = Float(min(max(link.targetTimestamp - link.timestamp,
                                   1.0 / 240), 1.0 / 30))
            let k: Float = 170
            scrollVel += (scrollTarget - offset) * k * dt
            scrollVel *= exp(-2 * sqrtf(k) * 0.92 * dt)
            offset += scrollVel * dt
            if abs(offset - scrollTarget) < 0.002, abs(scrollVel) < 0.02 {
                offset = scrollTarget
                scrollVel = 0
                stopScroll()
                haptics.brake()
                mode = .galleryIdle
                // La roue posée : la poudre revient au voile de repos
                // (le drive du dernier flick restait écrit — tempête).
                stage.setGalleryDustDrive(0)
            }
            stage.applyGallery(offset: offset)
            tickIfCenterChanged()
            // La poudre suit le vol : elle vit avec l'élan, meurt avec.
            if scrollLink != nil {
                stage.setGalleryDustDrive(min(abs(scrollVel) * 0.35, 1))
            }
        }

        /// L'index du clone de galerie sous un nœud touché, s'il y en a un.
        private func galleryIndex(of node: SCNNode) -> Int? {
            var cursor: SCNNode? = node
            while let n = cursor {
                if let i = stage?.galleryPacks.firstIndex(of: n) { return i }
                cursor = n.parent
            }
            return nil
        }

        /// L'index du clone sous un point écran.
        private func galleryHitIndex(at p: CGPoint) -> Int? {
            guard let view else { return nil }
            let hits = view.hitTest(p, options: [.ignoreHiddenNodes: true])
            return hits.compactMap { galleryIndex(of: $0.node) }.first
        }

        /// LE TIRAGE DE LA VRAIE CARTE — lancé à l'engagement pour que
        /// la latence du serveur vive DERRIÈRE la cérémonie (pool ~1 s :
        /// prêt bien avant le dévoilement ; neuve 60-90 s : la carte
        /// prend son art en retard, la collection reçoit le vrai).
        /// Jamais d'échec visible : sans réseau ou sans session, le
        /// repli est carte-lune-1 — la cérémonie ne casse pas.
        func reprendreForge() {
            guard !demonte, handle?.cartePrete != true else { return }
            forgeLancee = false
            lancerForge()
        }

        private func lancerForge() {
            guard forgeActive, !forgeLancee else { return }
            forgeLancee = true
            handle?.erreurForge = nil
            let noir = robe == .noire
            Task { @MainActor [weak self] in
                do {
                    let jwt = try await SupabaseSession.shared.token()
                    let owner = try await SupabaseSession.shared.currentUserID()
                    guard let booster = await EconomieWoop.shared.consommerBooster(legendaire: noir)
                    else { throw ForgeServeur.Erreur.reponse }
                    let carte = try await ForgeServeur.tirer(jwt: jwt, boosterId: booster)
                    guard try await SupabaseSession.shared.currentUserID().lowercased() == owner.lowercased(),
                          let self, !self.demonte, let handle = self.handle, !handle.flown else { return }
                    handle.boosterId = booster
                    handle.userId = owner
                    handle.cardId = carte.cardId
                    handle.acquisitionId = carte.acquisitionId
                    handle.famille = carte.famille.nom
                    handle.rarete = carte.famille.rarete
                    handle.nouvelle = CollectionLune.shared.destination(rarete: carte.famille.rarete,
                        famille: carte.famille.nom, cardId: carte.cardId).nouvelle
                    handle.carteDepth = carte.depth
                    handle.carteArt = carte.art
                    self.stage?.habillerCarte(carte.art)
                    if ["epic", "legendary"].contains(carte.famille.rarete) {
                        self.stage?.setTell(discret: self.mode != .idle)
                    }
                    handle.cartePrete = true
                    handle.attenteReseau = false
                    handle.erreurForge = nil
                } catch {
                    guard let self, !self.demonte else { return }
                    self.handle?.erreurForge = "attente"
                    print("[cartes] même sachet à reprendre : \(error.localizedDescription)")
                }
            }
        }

        /// L'engagement : les voisins filent chacun dans leur direction en
        /// accélérant, le sol s'éteint, et la caméra fait son dolly-zoom
        /// (z ET champ ensemble : une pure approche) vers le cadrage
        /// cérémonie. Le vrai sachet a pris la place du clone centré —
        /// identiques, personne ne voit l'échange.
        /// LE CADRAGE DE LA DÉCHIRURE — le sachet EN GROS, LE BAS COUPÉ par
        /// le bord de l'écran (verdict Kathryn du 28-08, référence Pokémon
        /// Pocket en main) : le pouce doit pouvoir TIRER la bande, et on ne
        /// tire pas confortablement sur un objet posé au milieu du vide.
        ///
        /// Le grossissement se prend à l'OBJECTIF, jamais en avançant la
        /// caméra : à distance égale (z 2,05) le champ passe de 60° à 49°,
        /// soit ×1,28 — un rapprochement l'aurait grossi en le déformant (le
        /// sachet est presque plat face à l'objectif, une courte focale lui
        /// creuse les flancs). La caméra MONTE ensuite de 0,57 : le sujet
        /// descend d'autant, et **on n'en voit plus que 85 %** — le pied est
        /// dans la main, hors cadre. Le sachet fait 0,536 d'écran de haut ;
        /// 85 % de lui = 0,456, son bord haut se pose donc à 54,4 %. (Deux
        /// crans essayés avant : 100 % visible « beaucoup trop », 70 % trop
        /// bas — la fraction VISIBLE est le réglage, pas la position.)
        ///
        /// **LES CHIFFRES SONT RELEVÉS SUR LA RÉFÉRENCE, PAS ESTIMÉS.** Sur
        /// la capture Pokémon Pocket de Kathryn : le sachet fait **74 % de la
        /// largeur**, son bord haut est à **46 % de la hauteur**, son pied
        /// sort par le bas. Deux essais au jugé ont été refusés avant de la
        /// mesurer — ×2 (champ 30°) donne 116 % de largeur, donc coupé SUR
        /// LES FLANCS, ce que la référence ne fait jamais ; ×1,55 posait
        /// encore le bord haut au tiers, « beaucoup trop ».
        ///
        /// La géométrie qui les relie, une fois pour toutes : à champ 60° le
        /// sachet occupe 0,999 unité de haut sur 0,631 de large, et l'écran
        /// en montre 2,367 × 1,089. D'où ×1,28 (74 % de large), et la caméra
        /// à 0,43 pour poser le bord haut à 47 % — le pied tombe alors à
        /// 100,5 %, coupé d'un cheveu, exactement comme la référence.
        ///
        /// ⚠️ Il ne vaut QUE pour la cérémonie engagée. Il est rendu au
        /// cadrage canonique (0 · 0 · 2,05, champ 60°) dès `finishTear` —
        /// tout l'aval (la sortie de carte, le dolly 1,86, le recouvrement
        /// même-image de `CarteVivante`) est calé dessus et ne bouge pas.
        private static let cadreDechirure: (y: Float, fov: CGFloat) = (0.57, 49)

        private func commitGallery(slot: Int) {
            guard let stage else { return }
            mode = .committing
            selectedSlot = slot
            commitOffset = offset
            stopScroll()
            stopRingSpin()
            stopGalleryGyro()
            // L'éclatement radial emporte le voile : la poudre du
            // manège se tait pour la cérémonie (sinon des grains dorés
            // en plein cadre pendant toute la découpe).
            stage.setGalleryDustOn(false)
            // Le coup sourd du mécanisme qui s'enclenche — et la musique
            // change d'acte : la boîte à musique s'efface, la veillée
            // sombre s'installe sous la découpe.
            haptics.commitThunk()
            ambience?.act(BoosterAmbience.veille, over: 1.4)

            // Le vrai sachet prend l'orientation où la main a laissé le
            // clone… puis SE PRÉSENTE RECTO pendant le dolly : engagé
            // dos, la découpe ne pouvait plus JAMAIS s'armer
            // (`restingFront` faux en permanence, l'invite éteinte, pas
            // un mot) — et sur téléphone le gyro remettait de toute
            // façon le clone de face : l'« arrivée dos » était déjà un
            // claquement, pas un choix tenu.
            yaw = .pi + cloneYaw
            pitch = 0
            applyPose()
            stage.packNode.position = SCNVector3(0, -0.02, 0)
            stage.galleryPacks[slot].isHidden = true
            stage.packNode.isHidden = false
            if abs(atan2f(sinf(yaw - .pi), cosf(yaw - .pi))) > 0.01 {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.62
                SCNTransaction.animationTimingFunction =
                    CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
                stage.packNode.eulerAngles = SCNVector3(0, Float.pi, 0)
                SCNTransaction.commit()
                yaw = .pi
            }
            cloneYaw = 0
            cloneVel = 0
            // LE SACHET ARRIVE VIVANT AU DOLLY : la respiration s'arme
            // ICI, synchrone — le bloc +0,9 s n'est plus le seul
            // écrivain de la vie (s'il rate, le sachet restait une
            // statue). Idempotent : le +0,9 s peut le rappeler sans
            // saut. Berceau et demi-tour vivent sur des nœuds disjoints.
            stage.beginIdleBreath()
            // LA FORGE PART À L'ENGAGEMENT : le tirage (pool ~1 s, carte
            // neuve 60-90 s) se cache derrière la cérémonie — au
            // dévoilement, la poignée porte la vraie carte, ou le repli.
            lancerForge()

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.32
            SCNTransaction.animationTimingFunction =
                CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
            let n = Float(BoosterScene.ringCount)
            for (i, clone) in stage.galleryPacks.enumerated() where i != slot {
                // Chacun fuit RADIALEMENT, dans sa propre direction du
                // cercle — le manège éclate vers le dehors.
                let theta = (Float(i) - offset) * (2 * .pi / n)
                clone.position.x += sinf(theta) * 1.5
                clone.position.z += cosf(theta) * 1.5
                clone.opacity = 0
            }
            stage.floorNode.opacity = 0
            SCNTransaction.commit()

            // Le dolly-zoom avec un souffle d'overshoot : il dépasse d'un
            // cheveu (2,02) puis se pose (2,05) — l'arrivée se voit ET se
            // sent (accent haptique au même instant). Il atterrit sur LE
            // CADRAGE DE LA DÉCHIRURE (voir `cadreDechirure`).
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.62
            SCNTransaction.animationTimingFunction =
                CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
            stage.cameraNode.position = SCNVector3(0, Self.cadreDechirure.y, 2.02)
            stage.cameraNode.camera?.fieldOfView = Self.cadreDechirure.fov
            SCNTransaction.commit()
            cadreDecoupeActif = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) { [weak self] in
                guard let self, self.mode == .committing,
                      let stage = self.stage else { return }
                self.haptics.arrive()
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.25
                SCNTransaction.animationTimingFunction =
                    CAMediaTimingFunction(name: .easeOut)
                stage.cameraNode.position.z = 2.05
                SCNTransaction.commit()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                guard let self, self.mode == .committing,
                      let stage = self.stage else { return }
                stage.floorNode.isHidden = true
                stage.beginIdleBreath()
                // SENTINELLE (jamais un écrasement de pose — le recto
                // est garanti par le demi-tour d'engagement) : un
                // engagement non-recto rendrait la découpe inarmable en
                // silence — c'est ce silence qui a coûté.
                if !self.restingFront {
                    print("[booster] engagement non-recto : yaw=\(self.yaw)")
                }
                self.mode = .idle
                self.startInvite()
            }
        }

        /// Le retour à l'anneau (avant la morsure) : la caméra ressort,
        /// le sol se rallume, les voisins reviennent à leur place.
        private func backOutGallery() {
            guard let stage else { return }
            mode = .backingOut
            stage.swayNode.removeAnimation(forKey: "bob")
            stage.swayNode.removeAnimation(forKey: "sway")
            stage.packNode.isHidden = true
            stage.galleryPacks[selectedSlot].isHidden = false
            stage.floorNode.isHidden = false
            offset = commitOffset
            scrollTarget = offset
            scrollVel = 0
            lastCenterSlot = Int(offset.rounded())
            // L'anneau reprend ses droits : le clone revient posé de face.
            cloneYaw = 0
            cloneVel = 0
            ambience?.act(BoosterAmbience.manege, over: 0.9)

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.45
            SCNTransaction.animationTimingFunction =
                CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
            // La position ENTIÈRE, pas seulement z : le cadrage de découpe
            // a monté la caméra (Self.cadreDechirure) — un retour qui ne
            // rendrait que z laisserait l'anneau décentré vers le bas.
            stage.cameraNode.position = SCNVector3(0, 0, 4.0)
            stage.cameraNode.camera?.fieldOfView = 42
            cadreDecoupeActif = false
            stage.floorNode.opacity = 1
            stage.applyGallery(offset: offset)
            SCNTransaction.commit()

            // L'anneau retrouve TOUTE sa vie : le voile de poudre se
            // rallume, et la parallaxe du poignet renaît (stoppée à
            // l'engagement, elle ne revenait jamais).
            stage.setGalleryDustOn(true)
            startGalleryGyro()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.47) { [weak self] in
                guard let self, self.mode == .backingOut else { return }
                self.mode = .galleryIdle
            }
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
            // La poudre reste allumée : une capture de découpe sans sa
            // poudre ne juge rien (le rendu tourne en continu, elle vit).
            stage?.setTear(s, sparking: true)
            stage?.dim(true)
        }

        /// LA REPRISE — la card 2D a mordu le sachet à s, le manège continue.
        /// Le front est POSÉ à s, et rien d'autre : ni `dim` (la pénombre
        /// vient avec le doigt — `pan(.began)` — et se lève au lâcher), ni
        /// poudre (le sachet dort caché dans l'anneau jusqu'à l'engagement),
        /// ni mode (`attach` l'a écrit). `setTear` est monotone : la découpe
        /// ne redescendra jamais sous s — c'est le contrat. Le pan reprend
        /// tout seul : `tearStartProgress = stage.tearProgress` au `.began`,
        /// et le mapping du doigt est absolu sur la largeur du sachet.
        /// ⚠️ Plafond 0,75 : au-delà de 0,82 un simple toucher-lâcher sur le
        /// sachet passerait le seuil du RRRIP — une cérémonie sur un tap.
        /// ⚠️ `s == 0` reste un no-op : `setTear(0)` allumerait quand même
        /// `tornGlow` — le fil d'or sur un sachet intact.
        func reprendreDechirure(depuis s: Float) {
            guard let stage, s > 0 else { return }
            morsureHeritee = min(s, 0.75)
            stage.setTear(morsureHeritee, sparking: false)
        }

        func jumpToOpen() {
            guard let stage else { return }
            stage.setTear(1, sparking: false)
            stage.capNode.isHidden = true
            stage.cardNode.isHidden = false
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
            // Le raccourci atterrit sur le VRAI état final : l'overlay
            // (CarteVivante + registre + invite) se monte comme après
            // une cérémonie complète — sinon le banc -boosterOpen ne
            // montre qu'une carte scène nue.
            DispatchQueue.main.async { [weak self] in
                self?.handle?.revealed = true
            }
        }

        /// `-boosterCine` : la cérémonie se joue TOUTE SEULE (le banc de
        /// filmage — impossible de glisser un doigt via simctl). Une
        /// déchirure d'~1,1 s au rythme d'une vraie main, puis la fin.
        func autoCeremony(after delay: TimeInterval) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, let stage = self.stage, self.mode == .idle
                else { return }
                // Un maintien en cours passe le relais : la lune garde
                // son plancher de charge.
                self.adoptHoldIntoTear()
                self.mode = .tearing
                // Le banc du SCELLEMENT (`-boosterScelle`, 30-08) : la
                // cinématique n'engage pas (pas de galerie), donc la forge
                // ne partait jamais d'ici — c'est elle qu'on veut prouver.
                // `lancerForge` est gardée par `forgeActive` : sans le
                // drapeau, rien ne change.
                if self.forgeActive { self.lancerForge() }
                stage.dim(true)
                if self.sfx == nil, !self.still { self.sfx = BoosterSFX() }
                self.haptics.bedStart()
                var p: Float = 0
                let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60,
                                                 repeats: true) { [weak self] t in
                    guard let self, let stage = self.stage else {
                        t.invalidate()
                        return
                    }
                    p += 0.9 / 66
                    let eased = p * p * (3 - 2 * p)
                    stage.setTear(min(eased, 0.9), sparking: true)
                    self.tearBedV = 0.55
                    self.sfx?.crackle(0.55)
                    // Le tremblement vit sur le BERCEAU (identité), en
                    // triplet entier — jamais sur le pack au lacet π,
                    // où la décomposition d'euler change de forme au
                    // bruit près (le « booster qui tourne »).
                    stage.swayNode.eulerAngles = SCNVector3(
                        Float.random(in: -1 ... 1) * 0.006, 0, 0)
                    if p >= 0.9 {
                        t.invalidate()
                        self.sfx?.crackleOff()
                        self.finishTear()
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
            }
        }

        // MARK: gestes

        @objc func tap(_ g: UITapGestureRecognizer) {
            guard let view else { return }
            switch mode {
            case .revealed:
                // Un toucher, et le banc se réarme : la cérémonie (galerie
                // comprise) se rejoue à volonté — la méthode maison pour
                // juger un enchaînement.
                attach(to: view, still: still, dos: dos, mylar: mylar,
                       yawDeg: yawDeg, gallery: galleryOn, robe: robe,
                       cadreDecoupe: cadreDecoupeDemande)
            case .galleryIdle, .galleryFly:
                // Tap sur le sachet qui se présente : l'engagement. Tap
                // ailleurs sur l'anneau : le manège tourne (par le chemin
                // le plus court) pour le présenter.
                let hits = view.hitTest(g.location(in: view),
                                        options: [.ignoreHiddenNodes: true])
                guard let idx = hits.compactMap({ galleryIndex(of: $0.node) })
                    .first else { return }
                if idx == centerIndex(offset), mode == .galleryIdle,
                   abs(offset - offset.rounded()) < 0.08,
                   ringSpinLink == nil {
                    commitGallery(slot: idx)
                } else {
                    // L'anneau repart : la pichenette du centre meurt
                    // AVEC son centre — un settle encore en vol écrirait
                    // sur le clone du NOUVEAU cran (yaws parasites).
                    stopRingSpin()
                    cloneYaw = 0
                    cloneVel = 0
                    let n = BoosterScene.ringCount
                    var delta = ((idx - centerIndex(offset)) % n + n) % n
                    if delta > n / 2 { delta -= n }
                    scrollTarget = offset.rounded() + Float(delta)
                    mode = .galleryFly
                    startScroll()
                }
            default:
                break
            }
        }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            guard let view, let stage else { return }
            switch g.state {
            case .began:
                if mode == .galleryIdle || mode == .galleryFly {
                    // La zone dit l'intention : attraper le SACHET CENTRAL
                    // posé = le tourner sur lui-même (la pichenette, dos
                    // aux croissants compris) ; tout le reste de l'écran
                    // fait tourner le manège.
                    if mode == .galleryIdle,
                       abs(offset - offset.rounded()) < 0.1,
                       let idx = galleryHitIndex(at: g.location(in: view)),
                       idx == centerIndex(offset) {
                        stopRingSpin()
                        cloneGrab = cloneYaw
                        mode = .ringSpin
                        return
                    }
                    stopScroll()
                    // Même loi qu'au tap-vol : le scrub déplace le
                    // centre, la pichenette posée meurt avec lui.
                    stopRingSpin()
                    cloneYaw = 0
                    cloneVel = 0
                    grabOffset = offset
                    lastScrubOffset = offset
                    haptics.bedStart()
                    mode = .galleryScrub
                    return
                }
                guard mode == .idle else { return }
                let p = g.location(in: view)
                let hits = view.hitTest(p, options: [.ignoreHiddenNodes: true])
                let packHit = hits.first { $0.node === stage.bodyNode || $0.node === stage.capNode }
                if packHit == nil, galleryOn {
                    // Un geste né hors du sachet : peut-être le retour à
                    // l'anneau (il se confirme vers le bas).
                    mode = .maybeBack
                    return
                }
                if let hit = packHit, restingFront,
                   hit.localCoordinates.y > stage.yTear - 0.07 {
                    // Le doigt qui a CHARGÉ mord maintenant : la
                    // découpe hérite du plancher de la lune.
                    adoptHoldIntoTear()
                    stage.retirerShinyLeak()
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
                    stage.dim(true)
                    // La main et l'oreille s'arment avec la découpe.
                    tearBedV = 0
                    tearAccum = 0
                    tearPrev = stage.tearProgress
                    popThreshold = Float.random(in: 0.025 ... 0.06)
                    haptics.bedStart()
                    if sfx == nil, !still { sfx = BoosterSFX() }
                    tick.prepare()
                } else if packHit != nil, !cadreDecoupeActif {
                    // PAS DE ROTATION QUAND LE SACHET EST PRÉSENTÉ (verdict
                    // Kathryn, 28-08) : il est là pour être DÉCHIRÉ, et un
                    // objet qu'on fait tourner sous le pouce n'invite pas à
                    // tirer dessus — pire, la moitié des gestes de traction
                    // le mettaient en rotation au lieu d'ouvrir.
                    //
                    // LA GARDE EST LE CADRAGE, PAS LE MANÈGE. Première
                    // version : `!galleryOn` — elle laissait le sachet
                    // tourner sur le banc sans anneau, c'est-à-dire
                    // exactement là où Kathryn le jugeait (« on peut pas
                    // faire de rotation, il est fixe ! genre le faire
                    // tourner à 360 degrés »). `cadreDecoupeActif` dit LA
                    // chose qui compte : le sachet est présenté pour être
                    // ouvert. Le géant de la page profil ne le porte jamais,
                    // il garde sa pichenette entière.
                    //
                    // Attraper le sachet — y compris en plein vol : la main
                    // vole l'élan, le tour reprend sous le doigt. La
                    // charge en cours meurt AVEC le changement
                    // d'intention (sinon holdLink orphelin).
                    stopHold()
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
                    // La sensation suit le geste : le lit gronde avec la
                    // VITESSE, les crépitements tombent avec la DISTANCE.
                    let delta = max(stage.tearProgress - tearPrev, 0)
                    tearPrev = stage.tearProgress
                    // Le plancher monte avec la CHARGE de la lune : plus
                    // elle brûle, plus la paume gronde, même à geste lent.
                    tearBedV = tearBedV * 0.8 + min(delta * 28, 1) * 0.2
                    haptics.bedIntensity(0.2 + 0.3 * stage.tearProgress
                                         + 0.5 * powf(tearBedV, 0.7))
                    // Le foil RÉSISTE : le sachet tremble sous l'effort,
                    // proportionnellement à la vitesse du geste. Sur le
                    // BERCEAU (identité), en triplet entier — jamais sur
                    // le pack au lacet π (forme alternative au bruit
                    // près : le « booster qui tourne »).
                    stage.swayNode.eulerAngles = SCNVector3(
                        Float.random(in: -1 ... 1) * 0.010 * tearBedV, 0, 0)
                    sfx?.crackle(tearBedV)
                    tearAccum += delta
                    if tearAccum >= popThreshold {
                        tearAccum = 0
                        // Des pops plus RARES et plus secs (le grain
                        // premium), chacun annoncé par un raidissement
                        // de 70 ms : la main sent que ça va céder.
                        popThreshold = Float.random(in: 0.025 ... 0.06)
                        haptics.stiffen()
                        let pv = tearBedV
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            [weak self] in self?.haptics.pop(pv)
                        }
                    }
                case .spinning:
                    let t = g.translation(in: view)
                    yaw = grabYaw + Float(t.x) * Self.radPerPoint
                    pitch = Float(t.y / 320).clamped(to: -0.3 ... 0.3)
                    applyPose()
                case .galleryScrub:
                    let t = g.translation(in: view)
                    offset = grabOffset - Float(t.x) / Self.slotPoints
                    stage.applyGallery(offset: offset)
                    tickIfCenterChanged()
                    // Le roulement du manège sous le doigt : le lit suit
                    // la vitesse de la roue — et la poudre aussi (la
                    // traîne du geste).
                    let speed = abs(offset - lastScrubOffset)
                    lastScrubOffset = offset
                    haptics.bedIntensity(0.12 + min(speed * 22, 0.35))
                    stage.setGalleryDustDrive(min(speed * 26, 1))
                case .ringSpin:
                    cloneYaw = cloneGrab
                        + Float(g.translation(in: view).x) * Self.radPerPoint
                    applyCloneSpin()
                case .maybeBack:
                    if g.translation(in: view).y > 90,
                       stage.tearProgress <= morsureHeritee {
                        backOutGallery()
                    }
                default:
                    break
                }
            case .ended, .cancelled:
                switch mode {
                case .tearing:
                    stage.setSparking(false)
                    haptics.bedStop()
                    sfx?.crackleOff()
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
                case .galleryScrub:
                    // L'élan projette, l'aimant pose sur un cran — jamais
                    // à plus de deux sachets de la main qui lâche.
                    haptics.bedStop()
                    let vel = (-Float(g.velocity(in: view).x) / Self.slotPoints)
                        .clamped(to: -6 ... 6)
                    let release = offset.rounded()
                    scrollVel = vel
                    scrollTarget = (offset + vel * 0.35).rounded()
                        .clamped(to: (release - 2) ... (release + 2))
                    mode = .galleryFly
                    startScroll()
                case .ringSpin:
                    // La pichenette du sachet dans l'anneau.
                    cloneVel = (Float(g.velocity(in: view).x) * Self.radPerPoint)
                        .clamped(to: -14 ... 14)
                    mode = .galleryIdle
                    startRingSpin()
                case .maybeBack:
                    mode = .idle
                default:
                    // JAMAIS d'écriture de mode au lever du doigt hors
                    // des états tenus par la main : le `default` qui
                    // forçait .idle BRIQUAIT le retour à l'anneau
                    // (.backingOut clobbé) et réarmait les gestes en
                    // pleine cérémonie (.opening/.committing → double
                    // finishTear, deux pilotes sur la carte).
                    break
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
            if forgeActive, handle?.cartePrete != true {
                ouvertureDifferee = true
                mode = .opening
                handle?.attenteReseau = true
                haptics.suspend()
                sfx?.crackleOff()
                return
            }
            mode = .opening
            // LE CADRAGE REND LA MAIN : la découpe est finie, la carte va
            // sortir — on revient au cadrage canonique (champ 60°, caméra à
            // hauteur d'axe) sur lequel TOUTE la suite est calée. Le
            // mouvement se fond dans le grand RRRIP : un recul qui ouvre
            // l'espace au moment exact où quelque chose en sort.
            if cadreDecoupeActif {
                cadreDecoupeActif = false
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.55
                SCNTransaction.animationTimingFunction =
                    CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
                stage.cameraNode.position = SCNVector3(0, 0, 2.05)
                stage.cameraNode.camera?.fieldOfView = 60
                SCNTransaction.commit()
            }
            // L'ENVOL part à t=0 et AVANT setTear(1) : sa rampe de tearU
            // doit partir de la valeur vivante (un saut 0,82→1
            // téléporterait un demi-tour de rouleau). Accroche 0→0,30 s,
            // rupture à 0,42 s — pile le claquement grave cuit dans
            // `dechirure-finale` que rip() lance maintenant.
            stage.flyOffCap()
            stage.setTear(1, sparking: true)
            // La bande cède : LE GRAND RRRIP, le coup profond dans la
            // paume, et la lune BAT une fois — puis veille, incandescente.
            // LE SILENCE APRÈS : le lit tombe à zéro pendant le zoom —
            // c'est le creux qui rend le double coup et la montée
            // audibles dans la main (partition v6).
            haptics.bedIntensity(0)
            haptics.commitThunk()
            stage.moonPulse()
            sfx?.rip()
            sfx?.crackleOff()
            stopInvite()
            // La respiration au repos rend l'antenne : le pilote de la
            // sortie devient l'UNIQUE écrivain du sachet (deux mains sur
            // position.y et l'étreinte serait illisible).
            stage.swayNode.removeAnimation(forKey: "bob", blendOutDuration: 0.15)
            stage.swayNode.removeAnimation(forKey: "sway", blendOutDuration: 0.15)
            // Et le berceau rentre à l'IDENTITÉ : le dernier jitter du
            // tremblement (≤0,6°) ne doit rester cuit ni dans la pose
            // du sachet ni dans le monde baké de la carte (audit v5).
            stage.swayNode.eulerAngles = SCNVector3(0, 0, 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
                // La rupture de la bande : LE DOUBLE COUP — le grave
                // dans l'os, le clac sec 40 ms derrière, calés sur le
                // claquement cuit dans dechirure-finale. (La lèvre,
                // elle, appartient au pilote — un seul écrivain.)
                self?.haptics.ripThunk()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
                guard let self, let stage = self.stage else { return }
                stage.setSparking(false)
                // La carte s'éveille FACE VISIBLE (son orientation de
                // naissance : y=π local sous le pack à π = identité
                // monde) et NE TOURNERA PLUS JAMAIS — ni dos d'abord
                // ni flip, verdict Kathryn. On n'écrit pas son euler
                // ici : à lacet π ambiant, la composante relue est le
                // piège de la forme alternative. Le pilote fait le reste.
                stage.cardNode.isHidden = false
                self.extractCard()
            }
        }

        /// LA SORTIE DE LA CARTE — « ZOOM ET RÉVÉLATION » (verdict
        /// Kathryn : la PHYSICALITÉ était le cheap — plus un beat, plus
        /// un rebond, plus une déformation. La caméra fait le drame, la
        /// carte fait UN seul geste).
        ///
        /// Partition (·k via -cardExitSlow) :
        ///   0,0→0,4  la bande achève de sortir, rien ne bouge
        ///   0,4→1,5  L'APPROCHE — dolly-in vers le sachet PLEIN CADRE
        ///            (z 2,05→1,35, TOUT en z : zéro tangage — le
        ///            dé-tangage se lisait « la carte tourne »), la
        ///            braise s'éveille, la poudre naît en rampe
        ///   1,5→2,0  LA SUSPENSION — tout est tenu, le glow INSPIRE
        ///            (0,85→0,95 en 0,5 s — une houle, pas un beat)
        ///   2,0      bake de reparentage À L'ARRÊT (la carte quitte le
        ///            sachet AVANT que son opacité ne fonde — sinon le
        ///            fondu du parent l'emporterait) + scale UNIFORME
        ///            0,98 dès cette frame : la carte n'est JAMAIS
        ///            rendue pincée (le ×0,75 hérité du sachet, grossi
        ///            par le zoom, écrasait le dos de 25 % plein
        ///            cadre ; 0,60·0,98 = 0,588 de large ≈ la largeur
        ///            visuelle du sachet 0,61 — ça passe la fente, et
        ///            la carte est encore cachée à cet instant)
        ///   2,0→4,6  L'ÉLÉVATION — la carte monte FACE VISIBLE en UN
        ///            easeInOutCubic de 2,6 s (elle ne tourne JAMAIS :
        ///            ni dos d'abord, ni flip — verdict Kathryn)
        ///            pendant que la caméra RECULE en z pur
        ///            (1,35→2,05) ; à 2,9 LE SACHET PLONGE hors cadre
        ///            par le bas (lâché easeIn cubique) en GLISSANT
        ///            VERS L'OR (deathGold — jamais la baisse d'orange
        ///            nue qui traverse le marron), lèvre et poudre
        ///            taries avant la chute, braises de scène mortes
        ///            avec lui
        ///   4,6→4,85 LA POSE — silence tenu, puis la carte GLISSE à
        ///            sa place (translation SEULE, dolly 2,05→1,86),
        ///            le sacre à l'ARRIVÉE
        ///
        /// Le sachet ne TOURNE jamais — il sort du cadre par le bas.
        /// La carte ne tourne JAMAIS, point : zéro settle, zéro
        /// tremblement, zéro animation de scale hors assise. Un
        /// écrivain par propriété.
        private func extractCard() {
            guard let stage else { return }
            let card = stage.cardNode
            let pack = stage.packNode
            let bodyMat = stage.bodyNode.geometry?.firstMaterial
            let sparks = stage.sparks
            let sparkNode = stage.sparkNode
            let cam = stage.cameraNode
            let k = UserDefaults.standard.object(forKey: "cardExitSlow") != nil
                ? max(UserDefaults.standard.double(forKey: "cardExitSlow"), 0.05)
                : 1.0

            func ss(_ a: Float, _ b: Float, _ x: Float) -> Float {
                let t = min(max((x - a) / (b - a), 0), 1)
                return t * t * (3 - 2 * t)
            }
            let bodyEmission = bodyMat?.emission
            // La pose de départ du sachet : la chute se calcule depuis
            // elle (le pack est resté statique pendant la découpe).
            let packY0 = pack.position.y
            // Le porteur de poudre est garé en bout de course après
            // setTear(1) : recentré sur la fente, À L'ARRÊT, avant tout.
            sparkNode.position.x = 0

            // — l'état du bake (rempli à t = 2,0, tout à l'arrêt) —
            var y0w: Float = 0
            var rise: Float = 0

            // Le pilote : caméra, lumière, poudre, sachet-lumière et le
            // geste unique de la carte — fonctions pures du temps.
            func poseC(_ t: Float) {
                // La caméra : plongée vers le sachet PLEIN CADRE (le
                // « plus gros zoom » du verdict), puis retrait
                // d'accueil — jonctions à vitesse nulle, et TOUT EN Z :
                // zéro tangage, zéro montée. Le dé-tangage pendant la
                // montée changeait la perspective du plan de la carte
                // (trapèze→rectangle) — ça se lisait « la carte
                // tourne » (audit v5).
                let a = ss(0.4, 1.5, t)
                let r = ss(2.0, 4.6, t)
                let lift = a * (1 - r)
                cam.position.z = 2.05 - 0.70 * lift
                cam.position.y = 0
                cam.eulerAngles = SCNVector3(0, 0, 0)

                // La braise : décrue post-RRRIP → éveil → houle (0,5 s,
                // jamais un beat) → tenue → esclave du fondu du sachet.
                var glow: Float = 1.0 - 0.4 * ss(0.0, 0.4, t)
                glow += 0.25 * ss(0.4, 1.5, t)
                glow += 0.10 * ss(1.5, 2.0, t)
                glow *= 1.0 - ss(2.9, 3.8, t)
                bodyMat?.setValue(CGFloat(glow), forKey: "tornGlow")

                // La poudre de diamant : des RAMPES, jamais des marches
                // — et tarie AVANT la chute (elle tombe avec le sachet).
                sparks.birthRate = CGFloat(4 + 26 * ss(0.4, 2.6, t))
                    * CGFloat(1.0 - ss(2.5, 3.1, t))

                // LA CHUTE CINÉMATIQUE (verdict Kathryn) : dès que la
                // carte a dégagé la fente, le sachet PLONGE hors cadre
                // par le bas — un lâché en easeIn cubique. Plus
                // d'opacité : ce qui sort du cadre n'a pas à s'éteindre
                // (et les deux peaux du sachet aminci n'ont plus à se
                // battre en transparence). Pendant la chute, LA MORT
                // PAR L'OR : deathGold glisse la teinte de TOUTE
                // l'émission vers l'or-blanc (la loi anti-brun — une
                // baisse d'orange nue traverse le marron), la charge ne
                // fait que s'ADOUCIR (plancher 50 %, jamais la zone
                // boueuse), et les braises de scène (omni embers,
                // tearLight du téléphone) meurent AVEC le sachet —
                // sinon elles le repeignent en rouge pendant qu'il
                // tombe (audit v5).
                let drop = min(max((t - 2.9) / 1.25, 0), 1)
                pack.position.y = packY0 - 2.0 * drop * drop * drop
                bodyMat?.setValue(CGFloat(ss(2.4, 3.2, t)), forKey: "deathGold")
                let charge = 1.0 - ss(3.0, 4.0, t)
                bodyEmission?.intensity = CGFloat(0.6 * (0.5 + 0.5 * charge))
                bodyMat?.setValue(CGFloat(charge), forKey: "moonCharge")
                stage.setEmberLights(CGFloat(1.0 - ss(2.9, 4.0, t)))

                // La carte : UN seul geste — easeInOutCubic de 2,6 s,
                // zéro settle, zéro tremblement, scale intouché (le
                // pincement statique appartient à la fente, le flip
                // l'absorbera comme il l'a toujours fait).
                var v: Float = 0
                if t >= 2.0 {
                    let x = min((t - 2.0) / 2.6, 1)
                    let e = x < 0.5
                        ? 4 * x * x * x
                        : 1 - powf(-2 * x + 2, 3) / 2
                    card.position.y = y0w + rise * e
                    v = (x < 0.5 ? 12 * x * x : 3 * (2 - 2 * x) * (2 - 2 * x)) / 3
                }
                // La partition de la main : SILENCE pendant l'approche
                // (v = 0), le frottement de la montée avec la vitesse,
                // et pendant la chute LE SOUFFLE DESCENDANT — un lit
                // très doux qui glisse vers le grave (netteté en
                // décalage négatif) et s'éteint avec le sachet.
                let bedV: Float = v > 0.001 ? 0.06 + 0.32 * v : 0
                let breath = 0.10 * (1 - drop) * ss(2.9, 3.2, t)
                DispatchQueue.main.async { [weak self] in
                    self?.sfx?.crackle(0.5 * v)
                    self?.haptics.bedIntensity(max(bedV, breath))
                    self?.haptics.bedSharpness(-0.35 * drop)
                }
            }

            // LE BAKE à l'arrêt complet (t = 2,0) : la carte quitte le
            // sachet AVANT le fondu d'opacité du parent, le monde est
            // exact sans course, le pincement reste tel quel.
            let bake = SCNAction.run { [weak self] _ in
                guard let self, let stage = self.stage else { return }
                let world = card.worldTransform
                card.removeFromParentNode()
                stage.scene.rootNode.addChildNode(card)
                card.transform = world
                // Jamais pincée : le monde apporte le (0,75, 1, 0,45)
                // du sachet — on le remplace par l'uniforme AVANT
                // qu'elle ne se montre. Et l'orientation RENORMALISÉE
                // au triplet canonique (identité = face caméra) : la
                // décomposition du monde baké rend une forme au hasard
                // du bruit, le résidu du berceau (≤0,35°) est jeté.
                // Plus RIEN n'écrit ni n'anime son euler ensuite — une
                // carte qui ne tourne jamais ne peut pas culbuter.
                card.scale = SCNVector3(0.98, 0.98, 0.98)
                card.eulerAngles = SCNVector3(0, 0, 0)
                y0w = card.position.y
                rise = 0.75 - y0w
                DispatchQueue.main.async { DustChime.shared.puff() }
            }

            func seg(_ start: Float, _ dur: Float,
                     _ pose: @escaping (Float) -> Void) -> SCNAction {
                .customAction(duration: TimeInterval(dur) * k) { _, el in
                    pose(start + Float(Double(el) / k))
                }
            }

            stage.scene.rootNode.runAction(.sequence([
                seg(0, 1.5, poseC),
                // Fin du dolly : la poudre accroche la lumière — le
                // seul geste haptique de l'approche, doux.
                .run { [weak self] _ in
                    DispatchQueue.main.async { self?.haptics.sparkle() }
                },
                seg(1.5, 0.5, poseC),
                bake,
                seg(2.0, 2.6, poseC),
                // Fin de montée : le frottement meurt, silence tenu.
                .run { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.sfx?.crackleOff()
                        self?.haptics.bedStop()
                    }
                },
                seg(4.6, 0.25, poseC),
                // Le témoin passe à LA POSE : le dolly 2,05 → 1,86 et
                // la glisse de la carte, ensemble — translation seule,
                // le sacre à l'arrivée.
                .run { [weak self] _ in
                    guard let self, let stage = self.stage else { return }
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.45
                    SCNTransaction.animationTimingFunction =
                        CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
                    stage.cameraNode.position.z = 1.86
                    SCNTransaction.commit()
                    DispatchQueue.main.async { self.poseCard() }
                },
            ]))
        }

        /// LA POSE : la carte GLISSE à sa place — translation SEULE,
        /// jamais une rotation (verdict Kathryn : « je n'aime pas
        /// qu'elle tourne » — Pocket sort les cartes face visible, le
        /// flip est MORT). Le sacre — bloom, carillon, paume — éclate à
        /// l'ARRIVÉE : un seul éclat dans une scène presque noire.
        private func poseCard() {
            guard let stage else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.45
            SCNTransaction.animationTimingFunction =
                CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
            stage.cardNode.position = SCNVector3(0, 0.02, 0.55)
            SCNTransaction.commit()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
                guard let self, let stage = self.stage else { return }
                stage.bloomSpike()
                stage.celebrate()
                self.sfx?.chime()
                self.haptics.sparkle()
                self.ambience?.act(BoosterAmbience.sacre, over: 1.4)
            }

            // L'assise : un ressort discret après la pose — et pendant
            // qu'elle se joue, LA CONVERGENCE : la caméra rentre à
            // l'identité (exposition 0, bloom 0) pour que le rendu
            // SceneKit de la carte devienne le PNG nu — la scène ne
            // contient plus que la carte, ça se lit comme le sacre qui
            // se pose, pas comme un réglage.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { [weak self] in
                guard let self, let stage = self.stage else { return }
                if let camera = stage.cameraNode.camera {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.45
                    camera.exposureOffset = 0
                    camera.bloomIntensity = 0
                    SCNTransaction.commit()
                }
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.2
                SCNTransaction.animationTimingFunction =
                    CAMediaTimingFunction(name: .easeOut)
                stage.cardNode.scale = SCNVector3(1.09, 1.09, 1.09)
                SCNTransaction.commit()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // LE CLIC DE SERTISSAGE : au sommet du ressort, la
                    // carte se clipse dans son cadre — un tap ferme et
                    // mat, distinct du sparkle du sacre (280 ms avant).
                    self.haptics.seatClick()
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.25
                    SCNTransaction.animationTimingFunction =
                        CAMediaTimingFunction(name: .easeInEaseOut)
                    stage.cardNode.scale = SCNVector3(1.05, 1.05, 1.05)
                    // .revealed SEULEMENT quand la carte est posée : le
                    // completionBlock de la SECONDE détente — jamais un
                    // asyncAfter deviné (la carte serait encore en
                    // ressort, l'overlay taillé pour 1,05 sur une carte
                    // à 1,09 = bords qui doublent).
                    SCNTransaction.completionBlock = { [weak self] in
                        DispatchQueue.main.async {
                            guard let self else { return }
                            self.mode = .revealed
                            self.handle?.revealed = true
                        }
                    }
                    SCNTransaction.commit()
                }
            }
        }

        /// Le souffle de l'envol : la carte quitte la main — une
        /// expiration descendante, rien d'autre (la partition du sacre
        /// est déjà passée).
        func envolSouffle() {
            haptics.exhale()
        }

        /// LA RELANCE du banc : dégèle la vue, rearme les gestes et
        /// rebâtit une scène neuve — la cérémonie se rejoue à volonté,
        /// même après le raccord (où la SCNView a été gelée et ses
        /// recognizers désarmés).
        func replay() {
            guard let view else { return }
            frozen = false
            view.isHidden = false
            view.isPlaying = true
            view.rendersContinuously = true
            view.gestureRecognizers?.forEach { $0.isEnabled = true }
            attach(to: view, still: still, dos: dos, mylar: mylar,
                   yawDeg: yawDeg, gallery: galleryOn, robe: robe,
                   cadreDecoupe: cadreDecoupeDemande)
            if CommandLine.arguments.contains("-boosterCine") {
                autoCeremony(after: 1.0)
            }
        }

        /// L'EXTINCTION sous l'overlay opaque : la carte scène se cache
        /// (masquage sec sous une image identique déjà affichée =
        /// invisible), le tonemap sort de la boucle d'un coup
        /// (wantsHDR n'est pas animable — la marche est cachée), et la
        /// SCNView rend le GPU. CarteVivante règne seule.
        func extinguishForHandoff() {
            guard !demonte, !frozen, let stage, let view else { return }
            frozen = true
            haptics.suspend()
            stopSpin()
            stopScroll()
            stopPlacing()
            stopRingSpin()
            stopGalleryGyro()
            stopHold()
            stopInvite()
            if motionClient {
                motionClient = false
                LuneMotion.shared.stop()
            }
            stage.cardNode.isHidden = true
            stage.cameraNode.camera?.wantsHDR = false
            view.gestureRecognizers?.forEach { $0.isEnabled = false }
            // Laisser quelques frames emporter la carte cachée AVANT de
            // geler — PUIS CACHER LA VUE : gelée mais visible, sa
            // dernière frame reste affichée à jamais (la nappe de braise
            // sous la carte — le « trop éclairé en bas » payé au banc).
            // Le noir du ZStack prend le relais, CarteVivante règne.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak view] in
                guard let self, !self.demonte, self.frozen, let view,
                      view.scene === stage.scene else { return }
                view.isPlaying = false
                view.rendersContinuously = false
                view.isHidden = true
                // Comme pour la pause du profil : les drapeaux de rendu
                // seuls ne suffisent pas. Le résultat est déjà recouvert ;
                // aucune image de la scène ne doit encore être produite.
                stage.scene.isPaused = true
                stage.scene.rootNode.removeAllActions()
                stage.scene.rootNode.enumerateChildNodes { node, _ in
                    node.removeAllActions()
                    node.removeAllAnimations()
                    node.removeAllParticleSystems()
                }
                view.scene = nil
                NavDiagnostic.noter("booster-relais", destination: "scene=0;liens=0;gyro=0")
            }
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
