import AVFoundation
import CoreHaptics
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
        engine?.stoppedHandler = { [weak self] _ in self?.needsRestart = true }
        engine?.resetHandler = { [weak self] in
            try? self?.engine?.start()
            self?.buildBed()
        }
        try? engine?.start()
        buildBed()
    }

    private func revive() {
        guard needsRestart else { return }
        try? engine?.start()
        buildBed()
        needsRestart = false
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
    func act(_ name: String, over seconds: Double) {
        for key in players.keys {
            fade(key, to: key == name ? (Self.levels[name] ?? 0.25) : 0,
                 over: seconds)
        }
    }

    /// Tout s'éteint.
    func silence(over seconds: Double) {
        for key in players.keys { fade(key, to: 0, over: seconds) }
    }

    deinit {
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
///   `-boosterOpen` démarre sachet ouvert, carte présentée.
struct BoosterLab: View {
    private static let still = CommandLine.arguments.contains("-boosterStill")
    private static let dos = CommandLine.arguments.contains("-boosterDos")
    private static let mylar = CommandLine.arguments.contains("-boosterMylar")
    private static let gallery = CommandLine.arguments.contains("-boosterGallery")
    private static let tear: Float? = UserDefaults.standard
        .string(forKey: "boosterTear").flatMap(Float.init)
    private static let yawDeg: Float? = UserDefaults.standard
        .string(forKey: "boosterYaw").flatMap(Float.init)
    private static let open = CommandLine.arguments.contains("-boosterOpen")
    private static let cine = CommandLine.arguments.contains("-boosterCine")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            BoosterStage(still: Self.still, frozenTear: Self.tear,
                         startOpen: Self.open, startDos: Self.dos,
                         mylar: Self.mylar, frozenYawDeg: Self.yawDeg,
                         gallery: Self.gallery, cine: Self.cine)
                .ignoresSafeArea()
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }
}

// MARK: - La cage SceneKit

/// L'hôte du sachet : 60 fps (la découpe et les étincelles sont des
/// mouvements continus), gestes UIKit — le hit-test décide si le doigt
/// fait tourner le sachet ou tranche la bande (la découpe ne s'arme que
/// recto posé face caméra).
struct BoosterStage: UIViewRepresentable {
    var still: Bool
    var frozenTear: Float?
    var startOpen: Bool
    var startDos: Bool = false
    var mylar: Bool = false
    var frozenYawDeg: Float? = nil
    var gallery: Bool = false
    var cine: Bool = false

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.rendersContinuously = true
        context.coordinator.attach(to: view, still: still, dos: startDos,
                                   mylar: mylar, yawDeg: frozenYawDeg,
                                   gallery: gallery)
        if cine {
            context.coordinator.autoCeremony(after: 1.4)
        }
        if let s = frozenTear {
            context.coordinator.freezeTear(at: s)
        } else if startOpen {
            context.coordinator.jumpToOpen()
        }
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.pan(_:)))
        view.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.tap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: le chef d'orchestre

    final class Coordinator: NSObject {
        private weak var view: SCNView?
        private var stage: BoosterScene?
        private var still = false
        private var dos = false
        private var mylar = false
        private var yawDeg: Float?
        private var galleryOn = false

        private enum Mode {
            case idle, spinning, tearing, opening, revealed
            case placing, galleryIdle, galleryScrub, galleryFly, ringSpin
            case committing, maybeBack, backingOut
        }
        private var mode: Mode = .idle
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

        private func startInvite() {
            inviteTimer?.invalidate()
            let timer = Timer(fire: Date().addingTimeInterval(1.4),
                              interval: 4.2, repeats: true) { [weak self] _ in
                guard let self, self.mode == .idle,
                      let stage = self.stage,
                      stage.tearProgress == 0, self.restingFront else { return }
                stage.inviteSweep()
            }
            RunLoop.main.add(timer, forMode: .common)
            inviteTimer = timer
        }

        private func stopInvite() {
            inviteTimer?.invalidate()
            inviteTimer = nil
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
        private var placingStart: CFTimeInterval = 0

        // ---- le spin du sachet central DANS l'anneau ----
        /// Lacet propre du clone centré (0 = face à la caméra), son élan,
        /// sa prise, son lien de vol.
        private var cloneYaw: Float = 0
        private var cloneVel: Float = 0
        private var cloneGrab: Float = 0
        private var ringSpinLink: CADisplayLink?

        /// L'index de clone au centre pour une rotation donnée.
        private func centerIndex(_ off: Float) -> Int {
            let n = BoosterScene.ringCount
            return ((Int(off.rounded()) % n) + n) % n
        }

        func attach(to view: SCNView, still: Bool, dos: Bool = false,
                    mylar: Bool = false, yawDeg: Float? = nil,
                    gallery: Bool = false) {
            self.view = view
            self.still = still
            self.dos = dos
            self.mylar = mylar
            self.yawDeg = yawDeg
            self.galleryOn = gallery
            stopSpin()
            stopScroll()
            stopInvite()
            guard let stage = BoosterScene(still: still, mylar: mylar,
                                           gallery: gallery) else { return }
            self.stage = stage
            view.scene = stage.scene
            view.pointOfView = stage.cameraNode
            yaw = yawDeg.map { $0 * .pi / 180 } ?? (dos ? 0 : .pi)
            yawVel = 0
            pitch = 0
            applyPose()
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
                    beginPlacing()
                    ambience = BoosterAmbience()
                    ambience?.act(BoosterAmbience.manege, over: 2.4)
                }
            } else {
                mode = .idle
                if !still { startInvite() }
            }
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
            stage.packNode.eulerAngles.y = yaw
            stage.packNode.eulerAngles.x = pitch
            SCNTransaction.commit()
        }

        private func startSpin() {
            stopSpin()
            let link = CADisplayLink(target: self, selector: #selector(spinStep(_:)))
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
            guard let stage else { return }
            mode = .placing
            stage.floorNode.opacity = 0
            stage.cameraNode.position.z = 3.4
            for i in 0 ..< BoosterScene.ringCount { stage.galleryLight[i] = 0 }
            offset = -1.45
            stage.applyGallery(offset: offset)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.4
            stage.floorNode.opacity = 1
            SCNTransaction.commit()
            placingStart = CACurrentMediaTime()
            let link = CADisplayLink(target: self,
                                     selector: #selector(placingStep(_:)))
            link.add(to: .main, forMode: .common)
            placingLink = link
        }

        private func stopPlacing() {
            placingLink?.invalidate()
            placingLink = nil
        }

        @objc private func placingStep(_ link: CADisplayLink) {
            guard view?.window != nil, let stage else {
                stopPlacing()
                return
            }
            let t = Float(CACurrentMediaTime() - placingStart)
            // La roue freine : décélération cubique sur 1,1 s.
            let u = min(t / 1.1, 1)
            offset = -1.45 * powf(1 - u, 3)
            // La caméra recule, douce.
            let c = min(t / 1.3, 1)
            stage.cameraNode.position.z = 3.4 + 0.6 * (c * c * (3 - 2 * c))
            // Les feux en cascade, du fond vers le devant.
            let n = BoosterScene.ringCount
            for i in 0 ..< n {
                let raw = Float(i) * 2 * .pi / Float(n)
                let theta = abs(atan2f(sinf(raw), cosf(raw)))
                let start = 0.25 + 0.75 * (1 - theta / .pi)
                stage.galleryLight[i] = min(max((t - start) / 0.3, 0), 1)
            }
            stage.applyGallery(offset: offset)
            if t >= 1.45 {
                offset = 0
                for i in 0 ..< n { stage.galleryLight[i] = 1 }
                stage.applyGallery(offset: 0)
                stopPlacing()
                haptics.lock()
                mode = .galleryIdle
            }
        }

        // MARK: le spin du sachet central dans l'anneau

        private func startRingSpin() {
            stopRingSpin()
            let link = CADisplayLink(target: self,
                                     selector: #selector(ringSpinStep(_:)))
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
            clone.eulerAngles.y = .pi + cloneYaw
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
            stopScroll()
            let link = CADisplayLink(target: self,
                                     selector: #selector(scrollStep(_:)))
            link.add(to: .main, forMode: .common)
            scrollLink = link
        }

        private func stopScroll() {
            scrollLink?.invalidate()
            scrollLink = nil
        }

        /// La détente quand le sachet du centre change — le clic de
        /// barillet, à chaque cran.
        private func tickIfCenterChanged() {
            let center = Int(offset.rounded())
            if center != lastCenterSlot {
                lastCenterSlot = center
                haptics.detent()
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
            }
            stage.applyGallery(offset: offset)
            tickIfCenterChanged()
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

        /// L'engagement : les voisins filent chacun dans leur direction en
        /// accélérant, le sol s'éteint, et la caméra fait son dolly-zoom
        /// (z ET champ ensemble : une pure approche) vers le cadrage
        /// cérémonie. Le vrai sachet a pris la place du clone centré —
        /// identiques, personne ne voit l'échange.
        private func commitGallery(slot: Int) {
            guard let stage else { return }
            mode = .committing
            selectedSlot = slot
            commitOffset = offset
            stopScroll()
            stopRingSpin()
            // Le coup sourd du mécanisme qui s'enclenche — et la musique
            // change d'acte : la boîte à musique s'efface, la veillée
            // sombre s'installe sous la découpe.
            haptics.commitThunk()
            ambience?.act(BoosterAmbience.veille, over: 1.4)

            // Le vrai sachet prend l'orientation où la main a laissé le
            // clone — engagé dos visible, il arrive dos visible.
            yaw = .pi + cloneYaw
            pitch = 0
            applyPose()
            stage.packNode.position = SCNVector3(0, -0.02, 0)
            stage.galleryPacks[slot].isHidden = true
            stage.packNode.isHidden = false

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
            // sent (accent haptique au même instant).
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.62
            SCNTransaction.animationTimingFunction =
                CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
            stage.cameraNode.position.z = 2.02
            stage.cameraNode.camera?.fieldOfView = 60
            SCNTransaction.commit()

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
                self.mode = .idle
                self.startInvite()
            }
        }

        /// Le retour à l'anneau (avant la morsure) : la caméra ressort,
        /// le sol se rallume, les voisins reviennent à leur place.
        private func backOutGallery() {
            guard let stage else { return }
            mode = .backingOut
            stage.packNode.removeAnimation(forKey: "bob")
            stage.packNode.removeAnimation(forKey: "sway")
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
            stage.cameraNode.position.z = 4.0
            stage.cameraNode.camera?.fieldOfView = 42
            stage.floorNode.opacity = 1
            stage.applyGallery(offset: offset)
            SCNTransaction.commit()

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
        }

        /// `-boosterCine` : la cérémonie se joue TOUTE SEULE (le banc de
        /// filmage — impossible de glisser un doigt via simctl). Une
        /// déchirure d'~1,1 s au rythme d'une vraie main, puis la fin.
        func autoCeremony(after delay: TimeInterval) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, let stage = self.stage, self.mode == .idle
                else { return }
                self.mode = .tearing
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
                    stage.packNode.eulerAngles.x =
                        Float.random(in: -1 ... 1) * 0.006
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
                       yawDeg: yawDeg, gallery: galleryOn)
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
                    popThreshold = Float.random(in: 0.015 ... 0.045)
                    haptics.bedStart()
                    if sfx == nil, !still { sfx = BoosterSFX() }
                    tick.prepare()
                } else if packHit != nil {
                    // Attraper le sachet — y compris en plein vol : la main
                    // vole l'élan, le tour reprend sous le doigt.
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
                    // proportionnellement à la vitesse du geste.
                    stage.packNode.eulerAngles.x =
                        Float.random(in: -1 ... 1) * 0.010 * tearBedV
                    sfx?.crackle(tearBedV)
                    tearAccum += delta
                    if tearAccum >= popThreshold {
                        tearAccum = 0
                        popThreshold = Float.random(in: 0.015 ... 0.045)
                        haptics.pop(tearBedV)
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
                    // la vitesse de la roue.
                    let speed = abs(offset - lastScrubOffset)
                    lastScrubOffset = offset
                    haptics.bedIntensity(0.12 + min(speed * 22, 0.35))
                case .ringSpin:
                    cloneYaw = cloneGrab
                        + Float(g.translation(in: view).x) * Self.radPerPoint
                    applyCloneSpin()
                case .maybeBack:
                    if g.translation(in: view).y > 90,
                       stage.tearProgress == 0 {
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
                    mode = mode == .revealed ? .revealed : .idle
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
            mode = .opening
            stage.setTear(1, sparking: true)
            // La bande cède : LE GRAND RRRIP, le coup profond dans la
            // paume, et la lune BAT une fois — puis veille, incandescente.
            haptics.bedStop()
            haptics.commitThunk()
            stage.moonPulse()
            sfx?.rip()
            sfx?.crackleOff()
            stopInvite()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self, let stage = self.stage else { return }
                stage.setSparking(false)
                // La bande, déjà enroulée par le peeling, S'ARRACHE :
                // elle part en l'air en tournant et meurt en vol.
                stage.flyOffCap()
                stage.fadeTornGlow(over: 1.0)
                // La carte s'éveille et sort DOS D'ABORD — le motif
                // croissants offert, la question posée.
                stage.cardNode.isHidden = false
                stage.cardNode.eulerAngles.y = 0
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 1.1
                SCNTransaction.animationTimingFunction =
                    CAMediaTimingFunction(name: .easeInEaseOut)
                stage.packNode.eulerAngles.x = -0.14
                stage.cardNode.position.y = 0.78
                SCNTransaction.commit()

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                    self.presentCard()
                }
            }
        }

        /// La carte quitte le sachet et prend la scène ; le sachet s'efface
        /// par le bas, la lumière remonte — et le troisième acte s'ouvre :
        /// le sacre, sombre et émouvant.
        private func presentCard() {
            guard let stage else { return }
            // Figée depuis l'intérieur, la carte emporterait le pincement :
            // on bake le monde AVANT de la poser (le piège documenté).
            let world = stage.cardNode.worldTransform
            stage.cardNode.removeFromParentNode()
            stage.scene.rootNode.addChildNode(stage.cardNode)
            stage.cardNode.transform = world

            // LE TEMPS MORT : la carte dérive à peine, dos offert, la
            // caméra pousse doucement — une demi-seconde de question.
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            SCNTransaction.animationTimingFunction =
                CAMediaTimingFunction(name: .easeOut)
            stage.cardNode.position.y += 0.04
            stage.cameraNode.position.z = 1.86
            SCNTransaction.commit()
            // Le sachet vide s'efface par le bas pendant la question.
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.7
            SCNTransaction.animationTimingFunction =
                CAMediaTimingFunction(controlPoints: 0.5, 0, 0.8, 0.4)
            stage.packNode.position.y = -1.7
            SCNTransaction.commit()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
                self?.flipCard()
            }
        }

        /// LE FLIP : 0,35 s, et TOUT concentré sur la frame de profil —
        /// pointe de bloom, carillon, paume, lumière qui salue. Un seul
        /// éclat dans une scène presque noire.
        private func flipCard() {
            guard let stage else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.35
            SCNTransaction.animationTimingFunction =
                CAMediaTimingFunction(controlPoints: 0.55, 0, 0.2, 1)
            stage.cardNode.position = SCNVector3(0, 0.02, 0.55)
            // du dos (≈ π monde) vers la FACE (0) : le demi-tour.
            stage.cardNode.eulerAngles = SCNVector3(0, 0, 0)
            stage.cardNode.scale = SCNVector3(0.98, 0.98, 0.98)
            SCNTransaction.commit()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) { [weak self] in
                guard let self, let stage = self.stage else { return }
                stage.bloomSpike()
                stage.celebrate()
                self.sfx?.chime()
                self.haptics.sparkle()
                self.ambience?.act(BoosterAmbience.sacre, over: 1.4)
            }

            // L'assise : un ressort discret après le flip.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { [weak self] in
                guard let self, let stage = self.stage else { return }
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.2
                SCNTransaction.animationTimingFunction =
                    CAMediaTimingFunction(name: .easeOut)
                stage.cardNode.scale = SCNVector3(1.09, 1.09, 1.09)
                SCNTransaction.commit()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.25
                    SCNTransaction.animationTimingFunction =
                        CAMediaTimingFunction(name: .easeInEaseOut)
                    stage.cardNode.scale = SCNVector3(1.05, 1.05, 1.05)
                    SCNTransaction.commit()
                }
                self.mode = .revealed
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
