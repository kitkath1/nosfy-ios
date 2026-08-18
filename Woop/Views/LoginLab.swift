import AVFoundation
import SwiftUI

// MARK: - Banc d'essai (`-loginLab`)

/// Page de connexion expérimentale : la nuit très noire en haut, l'aurore
/// chaude (blanc, doré, orange, gris) qui monte du bas pendant que ses
/// rideaux et ses halos descendent vers elle, des poussières-bijou qui
/// s'échappent de la lumière — et, posés dessus, le registre de la maison :
/// titre Inter en bas à gauche, l'input et le bouton CONNEXION de la famille
/// diamant. L'AuthView réelle n'est pas touchée : tout vit ici.
/// L'écran d'entrée de l'app — le seul. Le splash de la lune se termine
/// dessus : `LandedMonolithView`, plus bas, EST l'objet sur lequel la
/// cinématique se pose. L'ancien écran d'authentification (nébuleuse et
/// diablotins, `AuthView`) est passé en archive derrière `-authNebula`.
///
/// Ce n'est plus un banc : `-loginLab` l'ouvre nu, la racine l'ouvre avec un
/// `onConnect`. Un seul type pour les deux — un doublon d'écran de connexion
/// dériverait en deux jours.
struct AuroraLoginView: View {
    /// Le numéro saisi, en chiffres. C'est la clé de la session Supabase
    /// (`woop.phone` → `WoopConfig.credentials`) : c'est l'appelant qui décide
    /// quoi en faire, l'écran ne touche pas aux réglages.
    var onConnect: (String) -> Void = { _ in }
    /// Posé par la racine quand CONNEXION est touché : le fond draine alors
    /// sa lumière vers la lune (l'aspiration de la cinématique de sortie).
    var cineStart: Date? = nil

    /// La cérémonie est en cours : la page se déshabille.
    private var leaving: Bool { cineStart != nil }

    /// `-loginPressed` fige le CONNEXION en état tap : la fumée d'échappée
    /// se capture sans devoir garder le doigt posé (le pattern des bancs).
    private static let pressed = CommandLine.arguments.contains("-loginPressed")
    /// `-loginTrail` sème une caresse figée : la traîne de lumière se
    /// capture sans doigt.
    private static let trailBench = CommandLine.arguments.contains("-loginTrail")

    @State private var phone = ""
    /// La caresse : les derniers points du doigt, horodatés — le shader en
    /// fait des lueurs qui s'évasent et meurent en une seconde.
    @State private var traces: [TouchTrace] = []
    @State private var lastSample = Date.distantPast
    /// La vibration de la caresse : un tic haptique doux tous les ~90 ms
    /// tant que le doigt glisse.
    @State private var hapticTick = 0
    @State private var lastHaptic = Date.distantPast

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AuroraLoginBackground(traces: traces, bench: Self.trailBench,
                                  cineStart: cineStart)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // La couche de la caresse : sous le contenu (l'input et le
            // bouton gardent leurs touches), au-dessus du fond.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .gesture(DragGesture(minimumDistance: 0,
                                     coordinateSpace: .global)
                    .onChanged { v in caress(at: v.location) })

            // Le monolithe posé — l'objet sur lequel la cinématique du splash
            // se termine. Il occupe tout l'écran en rendu (son halo et sa
            // flaque en ont besoin) mais ne capte le doigt que dans son
            // voisinage : la caresse continue de vivre sur toute la page.
            // En cérémonie, c'est SA caméra qui plonge (CineMonolith) : le
            // tube grossit vectoriel, net — jamais un scaleEffect rastérisé.
            CineMonolith(start: cineStart)
                .allowsHitTesting(true)

            // La page se déshabille : le contenu fond en glissant d'un cheveu
            // vers le bas — elle s'incline pour le départ. À la fin de
            // l'aspiration il ne reste que la nuit et la lune.
            content
                .opacity(leaving ? 0 : 1)
                .offset(y: leaving ? 12 : 0)
                .animation(.easeIn(duration: 0.5).delay(0.15), value: leaving)

            // Le grain de la maison : les nappes chaudes bandent sur OLED.
            WoopGrain(density: 0.028, lightAlpha: 0.022, darkAlpha: 0.028)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        // Les micro-repères verticaux de la référence : des murmures
        // d'archive sur le bord gauche, à peine là. Premiers partis à
        // l'aspiration — un murmure n'a pas de cérémonie d'adieu.
        .overlay(alignment: .topLeading) {
            edgeTags
                .opacity(leaving ? 0 : 1)
                .animation(.easeOut(duration: 0.4), value: leaving)
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55),
                         trigger: hapticTick)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }

    /// Un échantillon tous les ~28 ms suffit : le shader interpole en
    /// s'évasant, une traîne continue naît de points espacés.
    private func caress(at p: CGPoint) {
        let now = Date()
        // Une nouvelle caresse (doigt reposé après une pause) : un souffle.
        if now.timeIntervalSince(lastSample) > 0.5 {
            SparkleChime.shared.breath()
        }
        if now.timeIntervalSince(lastSample) > 0.028 {
            lastSample = now
            traces.append(TouchTrace(point: p, born: now))
            traces.removeAll { now.timeIntervalSince($0.born) > 1.4 }
            if traces.count > 10 { traces.removeFirst(traces.count - 10) }
        }
        if now.timeIntervalSince(lastHaptic) > 0.09 {
            lastHaptic = now
            hapticTick += 1
        }
    }

    // MARK: Le contenu

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            // Les textes laissent passer le doigt : la caresse de lumière
            // traverse tout le haut de la page, seuls l'input et le bouton
            // gardent leurs touches.
            Group {
                Text("Bienvenue")
                    .font(.inter(13))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 10)

                title
                    .padding(.bottom, 14)

                Text("Ton numéro suffit — tes séances\nte retrouvent partout.")
                    .font(.inter(14))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineSpacing(4)
                    .padding(.bottom, 30)
            }
            .allowsHitTesting(false)

            DiamondInputField(placeholder: "Numéro de téléphone", text: $phone,
                              icon: "phone", keyboard: .phonePad)
                .padding(.bottom, 14)

            // La fumée du tap en or léger : sur l'aurore, le blanc pur
            // suffit presque — l'or la marie au fond.
            //
            // Le bouton n'est PAS conditionné à la validité du numéro : on
            // teste le parcours de bout en bout, et c'est l'appelant qui
            // décide s'il retient la saisie.
            DiamondConnexionButton(benchPress: Self.pressed ? 1 : nil,
                                   smokeWarmth: 0.4) {
                onConnect(phone.filter(\.isNumber))
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 22)
    }

    /// Le titre : Inter en grand, le dernier mot un cran plus présent —
    /// la hiérarchie de la référence (« designers » en gras), pas un slogan.
    /// « séances » porte sa propre encre : le fondu diagonal du titre
    /// éteignait justement le mot-clé (verdict mesuré : 1,32:1).
    private var title: some View {
        Text("Reprends le fil\nde tes \(Text("séances").font(.inter(34, .semibold)).foregroundStyle(Color(red: 0.97, green: 0.95, blue: 0.91)))")
            .font(.inter(34))
            .foregroundStyle(WoopGradient.titleFade)
            .lineSpacing(0)
    }

    private var edgeTags: some View {
        VStack(spacing: 64) {
            edgeTag("0730")
            edgeTag("WOOP")
        }
        .padding(.leading, 4)
        .padding(.top, 122)
    }

    private func edgeTag(_ s: String) -> some View {
        Text(s)
            .font(.inter(9, .medium))
            .tracking(3.2)
            .foregroundStyle(.white.opacity(0.16))
            .fixedSize()
            .rotationEffect(.degrees(-90))
            .frame(width: 14, height: 54)
    }
}

// MARK: - Le fond

/// Un point de la caresse, horodaté : le shader calcule l'âge lui-même à
/// chaque image — jamais d'accumulation.
struct TouchTrace {
    let point: CGPoint
    let born: Date
}

/// L'hôte du fond : plein écran, sous tout le reste. Depuis le banc `-bgLab`
/// validé, c'est `bgAuroraLogin` — le fond embrasé par le bas avec sa
/// parallaxe 3D au mouvement de l'appareil — plus la caresse du doigt. La
/// vue garde l'horloge de la paillette : quand l'enveloppe passe son seuil,
/// elle SONNE — image et murmure ne font qu'un.
struct AuroraLoginBackground: View {
    var traces: [TouchTrace] = []
    /// Le banc : une caresse figée en travers de la page.
    var bench: Bool = false
    /// La cinématique de sortie, si CONNEXION a été touché : les foyers du
    /// fond convergent vers l'or à mesure que l'horloge avance.
    var cineStart: Date? = nil
    /// L'inclinaison de l'appareil (muette au simulateur : ici le doigt
    /// appartient à la caresse, pas à la parallaxe).
    @StateObject private var tilt = BgTilt()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                let flashing = sin(t * 0.83 + 0.7) > 0.933
                let cine = cineStart.map {
                    ConnexionCine.cineLevel(tl.date.timeIntervalSince($0))
                } ?? 0
                // L'abscisse de la lune, en fraction de largeur : c'est vers
                // ELLE que les foyers remontent, pas vers le centre.
                let xLune = MoonLanding.spot(in: geo.size).x
                    / max(geo.size.width, 1)
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.bgAuroraLogin(
                        .float2(geo.size.width, geo.size.height), .float(t),
                        .float2(Float(tilt.value.x), Float(tilt.value.y)),
                        .float2(Float(cine), Float(xLune)),
                        .floatArray(trailArray(at: tl.date, size: geo.size,
                                               fastForward: cine * 1.4))))
                    // Pendant l'approche, l'aurore s'éteint au VRAI noir :
                    // plus un pixel d'orange sombre à l'écran quand la
                    // dissolution commence — le marron n'a nulle part où
                    // naître.
                    .opacity(cineStart.map {
                        ConnexionCine.bgAlpha(tl.date.timeIntervalSince($0))
                    } ?? 1)
                    .onChange(of: flashing) { _, on in
                        if on { SparkleChime.shared.play() }
                    }
            }
        }
    }

    /// Les triplets (x, y, âge) que consomme le shader. Jamais vide : un
    /// point sentinelle hors champ garde le buffer valide. `fastForward`
    /// vieillit la caresse d'autorité pendant l'aspiration : les lueurs
    /// meurent de leur mort naturelle, pas d'un fondu plaqué dessus.
    private func trailArray(at now: Date, size: CGSize,
                            fastForward: Double = 0) -> [Float] {
        if bench {
            // La caresse figée : six lueurs en travers de la page, la plus
            // jeune en tête — l'âge fige la traîne au milieu de sa vie.
            return (0..<6).flatMap { i -> [Float] in
                let f = CGFloat(i)
                return [Float(size.width * (0.72 - 0.09 * f)),
                        Float(size.height * (0.36 + 0.05 * f + 0.008 * f * f)),
                        Float(0.06 + 0.13 * Double(i))]
            }
        }
        var arr: [Float] = []
        for tr in traces {
            let age = Float(now.timeIntervalSince(tr.born)) + Float(fastForward)
            if age < 1.4 {
                arr += [Float(tr.point.x), Float(tr.point.y), age]
            }
        }
        return arr.isEmpty ? [-4000, -4000, 9] : arr
    }
}

// MARK: - La paillette

/// Les murmures de la page : la paillette (verre très aigu, désaccordé de
/// quelques cents) quand l'étoile de la croix fleurit, et le souffle d'air
/// au début de chaque caresse. Synthétisés (Woop/Sounds), joués en
/// `.ambient` + `mixWithOthers` : jamais par-dessus la musique — dessous,
/// comme le tic du cadran.
final class SparkleChime {
    static let shared = SparkleChime()

    private let sparkle: AVAudioPlayer?
    private let breathPlayer: AVAudioPlayer?

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
        sparkle = load("AuroraSparkle")
        breathPlayer = load("AuroraBreath")
    }

    func play() {
        guard let sparkle else { return }
        sparkle.volume = 0.32
        sparkle.currentTime = 0
        sparkle.play()
    }

    /// Le souffle de la caresse : un « shhh » d'air, à peine là.
    func breath() {
        guard let breathPlayer else { return }
        breathPlayer.volume = 0.26
        breathPlayer.currentTime = 0
        breathPlayer.play()
    }
}

#Preview {
    AuroraLoginView()
}
