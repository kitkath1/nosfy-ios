import AVFoundation
import SwiftUI

// MARK: - Banc d'essai (`-counterLab`)

/// Page noire nue : le cadran éclipse seul, pour le régler au pixel.
/// `-counterPressed` fige la bouffée à son pic (capture des volutes sans
/// devoir taper au bon centième — même astuce que `benchPress` au banc du
/// bouton).
struct CounterLab: View {
    private static let pressed = CommandLine.arguments.contains("-counterPressed")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Le spotlight de la nuit : un pinceau de lumière très fin qui
            // descend du haut et donne un sol à la scène. Sous le cadran.
            NightSpotlight()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            EclipseCounter(startedAt: .now.addingTimeInterval(-27),
                           caption: "Série 2",
                           benchPress: Self.pressed ? 0.85 : nil)

            // Le grain de la maison : les dégradés sombres bandent sur OLED.
            WoopGrain(density: 0.028, lightAlpha: 0.022, darkAlpha: 0.028)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Le spotlight

/// L'hôte du shader `nightSpotlight` : plein écran, sous tout le reste.
struct NightSpotlight: View {
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.nightSpotlight(
                        .float2(geo.size.width, geo.size.height), .float(t)))
            }
        }
    }
}

// MARK: - Le cadran éclipse

/// Un disque de velours noir, quatre lumières qui tournent derrière — deux
/// blanches lunaires, deux dorées, chacune à son tempo — et le chrono en
/// dégradé de blanc au centre. La lumière ne vit qu'au-delà du bord : le
/// disque l'occulte, elle le couronne. Au tap : UNE bouffée — onde du
/// toucher, voix qui enflent un instant, volutes de fumée qui glissent vers
/// l'extérieur et se dissolvent en une seconde. Une réponse, pas un état.
/// Tout l'arrière vit dans `EclipseHalo.metal` ; la vue porte le chrono,
/// l'aiguille-balayage, le toucher et le tic.
struct EclipseCounter: View {
    /// La seule source de vérité du temps — jamais d'accumulation par image.
    let startedAt: Date
    /// Le murmure au-dessus du chrono (« Série 2 ») ; vide : rien.
    var caption: String = ""
    /// La bouffée figée du banc (nil = pilotée par le tap) : capture au pic.
    var benchPress: Float? = nil
    /// Diamètre du disque de velours.
    var diameter: CGFloat = 250
    /// Naissance du cadran (cérémonie d'arrivée) : les quatre voix
    /// s'allument en canon sur ~1,2 s. nil = déjà né (bancs, usage courant).
    /// ANTIDATÉE par l'appelant si des proto-halos ont déjà commencé le
    /// geste ailleurs — ignite reprend alors au niveau atteint.
    var birth: Date? = nil
    /// L'horloge des CHIFFRES et du grossissement — le vrai instant de la
    /// coupe, distinct de `birth` quand celle-ci est antidatée.
    var faceBirth: Date? = nil
    /// La RENAISSANCE : le cadran naît de la petite bille du morphisme —
    /// il grossit de ce diamètre-là jusqu'à `diameter`, avec un
    /// micro-dépassement de ressort. nil = taille pleine dès la naissance.
    var birthDiameter: CGFloat? = nil
    /// La laque : 0 = velours d'origine, 1 = liquid glass noir — les halos
    /// se reflètent dans le disque.
    var gloss: Float = 0

    /// L'horodatage du tap : l'enveloppe de la bouffée (attaque 0,10 s,
    /// extinction ~0,7 s) se rejoue dans le TimelineView — un paramètre de
    /// shader ne s'interpole pas tout seul. Un seul déclenchement par toucher.
    @State private var tapAt: Date = .distantPast
    @State private var fingerDown = false
    /// La dernière seconde entendue : le tic ne sonne qu'au basculement.
    @State private var heardSecond = -1

    /// Débord du shader : les halos (et les volutes de la bouffée) vivent
    /// au-delà du disque — large, ET fondu dans le noir côté shader avant le
    /// bord (`hostFade`) : le tap ne doit jamais révéler le rectangle hôte.
    private var overflow: CGFloat { diameter * 0.58 }

    var body: some View {
        // Le cadre reste taillé pour le diamètre ÉPANOUI (le cadran grossit
        // d'un souffle à la naissance) : la frame ne bouge jamais, seul le
        // rayon du shader respire — rien ne re-layoute à 60 Hz.
        let side = ceil(diameter * 1.06) + overflow * 2
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = Float(tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900))
            let elapsed = max(0, tl.date.timeIntervalSince(startedAt))
            // L'enveloppe de la bouffée : attaque brève, extinction douce.
            let age = min(max(tl.date.timeIntervalSince(tapAt), 0), 9)
            let attack = min(age / 0.10, 1)
            let decay = exp(-max(age - 0.10, 0) / 0.70)
            let puff = benchPress ?? Float(attack * decay)
            let shaderAge = benchPress == nil ? Float(age) : 0.45
            let ignite = birth.map {
                Float(min(max(tl.date.timeIntervalSince($0) / 1.25, 0), 1))
            } ?? 1
            // L'éveil du chrono : à la naissance, les chiffres n'existent
            // pas encore — le disque d'abord, les halos ensuite, la parole
            // en dernier. Et le cadran GROSSIT d'un souffle en arrivant
            // (250 → ~262 pt). Sans naissance : tout est là, comme toujours.
            let fb = faceBirth ?? birth
            let fe = fb.map { tl.date.timeIntervalSince($0) } ?? 9
            let faceU = min(max((fe - 0.55) / 0.6, 0), 1)
            let faceIn = faceU * faceU * (3 - 2 * faceU)
            // La renaissance : 34 → 250 pt en ressort, micro-dépassement
            // puis assise — la bille du morphisme DEVIENT le cadran.
            let dia = birthDiameter.map {
                Self.rebornDiameter(fe, from: $0, to: diameter)
            } ?? diameter
            // Le shader SORTI du ZStack : une expression de plus dans l'appel
            // et le type-checker abandonne (la leçon des 36 arguments).
            let halo = ShaderLibrary.eclipseHalo(
                .float2(side, side), .float(t), .float(dia / 2),
                .float(puff), .float(shaderAge),
                .float(ignite), .float(gloss))
            ZStack {
                Rectangle()
                    .fill(.white)
                    .frame(width: side, height: side)
                    .colorEffect(halo)
                sweep(progress: elapsed.truncatingRemainder(dividingBy: 60) / 60,
                      dia: dia)
                    .opacity(faceIn)
                face(elapsed: Int(elapsed))
                    .opacity(faceIn)
            }
            .frame(width: side, height: side)
            .onChange(of: Int(elapsed)) { _, s in
                // Le tic de la seconde, le toc de la minute. Jamais au premier
                // rendu : un cadran qui sonne en apparaissant fait sursauter.
                guard heardSecond >= 0 else { heardSecond = s; return }
                guard s != heardSecond else { return }
                heardSecond = s
                if s % 60 == 0 { DialChime.shared.minute() }
                else { DialChime.shared.second() }
            }
        }
        // Le tap : UNE bouffée par toucher, déclenchée au contact (pas au
        // relâcher — la réponse doit être immédiate sous le doigt). Le doigt
        // posé sur le disque seulement : dehors, il n'y a rien à toucher.
        .contentShape(Circle().inset(by: overflow))
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !fingerDown else { return }
                fingerDown = true
                tapAt = .now
                DialChime.shared.tap()
            }
            .onEnded { _ in fingerDown = false })
        // La vibration du tap : souple, pas un choc — le velours répond.
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.85),
                         trigger: fingerDown) { _, new in new }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(startedAt, style: .timer))
    }

    // MARK: Le chrono

    private func face(elapsed: Int) -> some View {
        VStack(spacing: 13) {
            if !caption.isEmpty {
                Text(caption.uppercased())
                    .font(.inter(10.5, .semibold))
                    .tracking(3.8)
                    .foregroundStyle(Color.white.opacity(0.30))
            }
            // Le chrono : un fil de métal blanc qui s'éteint vers le bas.
            // Inter Light (graisse dédiée, hors du quatuor de Theme.swift) :
            // à 56 pt, la Regular pèse — la lumière demande un trait fin.
            Text(Self.format(elapsed))
                .font(Font.custom("Inter-Light", size: 56).monospacedDigit())
                .tracking(0.5)
                .foregroundStyle(LinearGradient(stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white.opacity(0.80), location: 0.55),
                    .init(color: .white.opacity(0.46), location: 1.0)
                ], startPoint: .top, endPoint: .bottom))
        }
    }

    /// L'aiguille-balayage : un fil de lumière qui parcourt le tour en une
    /// minute, tête vive, queue qui se perd — un trait, pas un anneau.
    private func sweep(progress: Double, dia: CGFloat) -> some View {
        let p = min(max(progress, 0.0001), 1.0)
        return Circle()
            .trim(from: 0, to: p)
            .stroke(
                AngularGradient(stops: [
                    .init(color: .white.opacity(0.0), location: 0.0),
                    .init(color: .white.opacity(0.07), location: max(0, p - 0.5)),
                    .init(color: .white.opacity(0.28), location: max(0, p - 0.12)),
                    .init(color: .white.opacity(0.92), location: p),
                    .init(color: .clear, location: min(1.0, p + 0.0001))
                ], center: .center),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            .rotationEffect(.degrees(-90))
            // Assise sur le limbe (+6, pas +20) : décollée, l'aiguille lit
            // comme une rayure d'écran (verdict du panel).
            .frame(width: dia + 6, height: dia + 6)
    }

    static func format(_ s: Int) -> String {
        "\(s / 60):" + String(format: "%02d", s % 60)
    }

    /// La courbe de renaissance : easeOutBack (c1 = 1,5), dépassement ~+6 %
    /// puis assise — sortie du body, le type-checker n'en veut pas là-bas.
    private static func rebornDiameter(_ fe: Double, from bd: CGFloat,
                                       to full: CGFloat) -> CGFloat {
        guard fe < 1.6 else { return full }
        // Une ÉCLOSION, pas un pop de widget : plus lent, dépassement doux.
        let u = min(max((fe - 0.05) / 0.95, 0), 1)
        let c1 = 0.8
        let s = 1 + (c1 + 1) * pow(u - 1, 3) + c1 * pow(u - 1, 2)
        return bd + (full - bd) * CGFloat(s)
    }
}

// MARK: - Le tic

/// L'échappement du cadran : un tic minuscule à chaque seconde, un ton plus
/// bas au passage de la minute. Sons synthétisés (Woop/Sounds), joués en
/// `.ambient` + `mixWithOthers` : le cadran ne coupe JAMAIS la musique de la
/// salle — il se glisse dessous.
final class DialChime {
    static let shared = DialChime()

    private let tick: AVAudioPlayer?
    private let tock: AVAudioPlayer?
    private let tapSound: AVAudioPlayer?

    private init() {
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        func load(_ name: String) -> AVAudioPlayer? {
            guard let url = Bundle.main.url(forResource: name,
                                            withExtension: "wav") else {
                return nil
            }
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            return player
        }
        tick = load("DialTick")
        tock = load("DialTock")
        tapSound = load("DialTap")
    }

    func second() { play(tick, volume: 0.55) }
    func minute() { play(tock, volume: 0.80) }
    /// Le souffle du tap : un sub feutré + une bouffée d'air, jamais un bip.
    func tap() { play(tapSound, volume: 0.70) }

    private func play(_ player: AVAudioPlayer?, volume: Float) {
        guard let player else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}
