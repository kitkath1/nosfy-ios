import SwiftUI
import simd

// MARK: - LA LUNE DE SANG — le splash de la porte
//
// Jalon 4 de `tools/porte/PLAN-PORTE.md`. Trois états tenus, du plus clair au
// plus éteint, puis le noir — 3,40 s en tout (l'arbitrage du 22-08 : version
// courte). Le film d'arrivée de la porte commence au noir : la couture entre
// les deux est noir-sur-noir, donc introuvable.
//
//   0,00 → 0,40   LA POSE       la lune arrive, reveal 0 → 1
//   0,40 → 0,95   ÉTAT ①        halo ivoire large (r 150), tube or, étoiles
//   0,95 → 1,20   fondu         night.w 0 → 0,52
//   1,20 → 1,75   ÉTAT ②        halo orange serré (r ~123), bandes ambre
//   1,75 → 2,00   fondu         night.w → 1,00 ; la braise s'allume (z 0,40)
//   2,00 → 2,55   ÉTAT ③        lune de sang : halo r 96 à −35 %, tube sang
//   2,55 → 3,40   EXTINCTION    tout meurt au noir
//
// ⚠️ 0,55 s PAR PALIER EST UN PLANCHER, PAS UN CONFORT : en dessous, l'œil ne
// lit plus trois états mais un dégradé continu. Si le verdict téléphone dit
// que ça défile, c'est l'EXTINCTION qu'on raccourcit, jamais les paliers.
//
// TOUT EST FONCTION PURE DU TEMPS — `LuneDeSangBeat.at(t:)` — jamais une
// animation d'état : la scène se rejoue à l'identique image par image, la
// condition pour la régler par captures (`-luneSangLab`, `-luneSangFreeze <t>`).
//
// LES TROIS ÉTATS NE SONT PAS PEINTS ICI : ce sont trois valeurs de l'uniform
// `night` du shader `logoMonolith`. Le sang vit sur `night.w` — son canal
// PROPRE depuis le découplage du 22-08 : sur l'ancien `night.y`, une lune
// rouge nette n'était pas exprimable, les nuages avalaient l'écran dès 0,80.
//
// LA CAMÉRA NE BOUGE PAS. Le plan-séquence de 13,95 s reste l'archive
// (`-moonSplashLab`) ; ici la lune est POSÉE, ce sont ses états qui voyagent.
// Une horloge, une image : la partition et le shader lisent le même instant
// (c'est pour ça qu'on appelle `MonolithCanvas`, nu, jamais `MonolithScene`
// qui porte sa propre TimelineView).

// MARK: - La partition

struct LuneDeSangBeat {
    var reveal: Float = 0
    var night: SIMD4<Float> = .zero
    var idleLife: Float = 0
    /// La caméra du shader : (cible x, cible y, zoom). C'est ELLE qui fait la
    /// plongée — jamais un scaleEffect, qui rastériserait les hairlines.
    var camera: SIMD3<Float> = SIMD3(0, 0, 1)
    /// (cine, boom, bgFade, cometHead). `boom` = la SURTENSION du néon à la
    /// pose (le shader multiplie l'énergie par 1 + 2,2·boom) ; `cometHead` =
    /// LA COMÈTE, en abscisse normalisée sur le contour — une sentinelle
    /// négative lui rend son rythme de croisière.
    var cineCtl: SIMD4<Float> = SIMD4(0, 0, 0, -1)
    /// LE LACET D'ARRIVÉE : la lune arrive DE BIAIS et pivote vers sa pose,
    /// en ressort qui dépasse d'un cheveu (l'école exacte de l'archive).
    var yaw: Float = 0

    // Les temps, en secondes. Les statiques sont la SEULE source des durées :
    // le `.task` de fin et l'haptique les lisent aussi — une durée écrite deux
    // fois finit par se dédire. (La partition V2 du 22-08 au soir : « pas
    // assez spectaculaire » → la plongée.)
    static let naissance = 0.45     // la lueur minuscule au loin
    static let plongee = 0.85       // la caméra fond sur elle
    static let palier = 0.55        // ⚠️ PLANCHER, jamais moins
    static let fondu = 0.25
    static let extinction = 1.00

    /// Les zooms de la caméra : loin → posée → l'implosion rentre d'un cheveu.
    static let zoomLoin: Float = 0.32
    static let zoomPose: Float = 1.20
    static let zoomMort: Float = 1.26

    static var tPose: Double { naissance + plongee }      // 1,30 — le choc
    static var t1: Double { tPose }                       // début état ①
    static var t2: Double { t1 + palier + fondu }         // 2,10 — état ②
    static var t3: Double { t2 + palier + fondu }         // 2,90 — état ③
    static var tMort: Double { t3 + palier }              // 3,45
    static var total: Double { tMort + extinction }       // 4,45

    /// Les battements : FORT à la pose (la main reçoit le choc de l'arrivée),
    /// puis un par état.
    static var battements: [(time: Double, fort: Bool)] {
        [(tPose, true), (t2, false), (t3, false)]
    }

    private static func lisse(_ x: Double) -> Float {
        let c = min(max(x, 0), 1)
        return Float(c * c * (3 - 2 * c))
    }

    /// La surtension de la pose : une décharge, pas un projecteur — montée en
    /// 60 ms, morte en 550 ms (la courbe exacte du boom de l'archive).
    private static func surtension(_ t: Double) -> Float {
        let d = Float(max(t - tPose, 0))
        return exp(-d / 0.55) * (1 - exp(-d / 0.06))
    }

    /// Un ressort amorti résolu à la main — il dépasse de 8 % puis revient.
    /// ⚠️ NORMALISÉ pour valoir 1 EXACTEMENT en p = 1 : la forme brute
    /// s'arrête à 0,99728, et ce demi-point de reliquat suffit à décaler la
    /// pose finale (la leçon payée du raccord de l'archive).
    private static let queueRessort: Float =
        exp(-6.0) * (cos(7.5) + (6.0 / 7.5) * sin(7.5))

    private static func ressort(_ p: Float) -> Float {
        if p >= 1 { return 1 }
        let x = max(p, 0)
        let brut = 1 - exp(-6 * x) * (cos(7.5 * x) + (6.0 / 7.5) * sin(7.5 * x))
        return brut / (1 - queueRessort)
    }

    static func at(_ t: Double) -> LuneDeSangBeat {
        var b = LuneDeSangBeat()
        // L'atmosphère (étoiles, halo de clair de lune) s'installe pendant la
        // naissance : c'est elle qui fait la NUIT, les états ne font que la
        // teinter.
        b.night.x = lisse(t / naissance)

        // LA CAMÉRA. Elle part à ×0,32 (la lune est une lueur minuscule) et
        // FOND sur elle en exponentielle p^1,6 — la courbe de la plongée de
        // l'archive : lente au départ, elle avale la fin. Le reveal suit la
        // course : la lune naît PENDANT qu'on l'approche, pas avant.
        // ⚠️ LE NÉON RESTE BAS PENDANT LA COURSE, ET C'EST TOUTE LA MISE EN
        // SCÈNE. Mesuré : à pleine puissance le tube sature à 254 et la
        // comète, qui sature au même niveau, DISPARAÎT dedans — elle courait
        // (point chaud déplacé de 57 px en 0,1 s) sans qu'on la voie. En
        // tenant le tube à 0,52, la comète devient la seule chose brillante :
        // c'est elle qui TRACE le croissant. Puis l'embrasement, à la pose.
        if t < naissance {
            b.camera.z = Self.zoomLoin
            b.reveal = 0.30 * b.night.x
        } else if t < tPose {
            let p = Float(lisse((t - naissance) / plongee))
            let e = pow(p, 1.6)
            b.camera.z = Self.zoomLoin
                + (Self.zoomPose - Self.zoomLoin) * e
            b.reveal = 0.30 + 0.22 * e          // le tube reste en veille
        } else {
            b.camera.z = Self.zoomPose
            // L'EMBRASEMENT : 0,52 → 1 en 0,30 s, sous la surtension. La
            // comète s'éteint pile là (§ cineCtl.w) — sa course meurt DANS
            // la lumière qu'elle a allumée.
            b.reveal = 0.52 + 0.48 * lisse((t - tPose) / 0.30)
        }

        // LA SURTENSION : le néon surtend sous le coup de frein de la pose.
        b.cineCtl.y = surtension(t)

        // LA COMÈTE — le levier de spectacle que le shader tenait en réserve
        // (verdict 23-08 : « encore plus spectaculaire »). Une décharge de
        // lumière court DANS le tube, tête nette et traîne derrière. Elle
        // fait UN TOUR ET DEMI pendant la plongée, accélérant en même temps
        // que la caméra (la même exponentielle p^1,6 — elle est portée par le
        // mouvement, elle ne le double pas), et s'arrête net à la pose : sa
        // course EST le coup de frein que la surtension fait claquer.
        // Sentinelle négative = pas de comète (le rythme de croisière du
        // shader ne doit pas s'inviter pendant les paliers).
        if t >= naissance * 0.5 && t < tPose {
            let q = Float(min(max((t - naissance * 0.5)
                                  / (tPose - naissance * 0.5), 0), 1))
            b.cineCtl.w = fmod(pow(q, 1.6) * 1.5, 1.0)
        } else if t >= tPose && t < tPose + 0.22 {
            // Elle s'éteint SUR la pose, pas avant : la tête reste plantée
            // à l'arrivée le temps que la surtension éclate.
            b.cineCtl.w = fmod(1.5, 1.0)
        } else {
            b.cineCtl.w = -1
        }

        // LE LACET : la lune arrive DE BIAIS (~12°) et pivote vers sa pose
        // pendant que la plongée finit — dépasse d'un cheveu, revient. Ce qui
        // rend le geste riche, ce ne sont pas les degrés : ce sont les
        // REFLETS qui balayent le verre pendant qu'elle tourne.
        b.yaw = 0.21 * (1 - ressort(Float(min(max(t / (tPose + 0.35), 0), 1))))

        // Le grésillement du néon posé : la lune ne doit jamais avoir l'air
        // ARRÊTÉE pendant les paliers.
        b.idleLife = lisse((t - tPose) / 0.3)

        // Le sang : deux marches lissées, tenues entre les fondus. Les
        // tremblements de l'agonie (drops, gasp) vivent DANS le shader sur
        // cette courbe — ils jouent tout seuls pendant les rampes.
        b.night.w = 0.52 * lisse((t - (t1 + palier)) / fondu)
                  + 0.48 * lisse((t - (t2 + palier)) / fondu)
        // La braise du contour s'allume avec le second fondu.
        b.night.z = 0.40 * lisse((t - (t2 + palier)) / fondu)

        if t >= tMort {
            // L'IMPLOSION DOUCE : la lumière tombe PENDANT que la caméra
            // rentre d'un cheveu — la lune ne s'éteint pas, elle se referme.
            // La braise du contour meurt en dernier, comme sur l'éclipse.
            let a = (t - tMort) / extinction
            let chute = 1 - lisse(a / 0.8)
            b.reveal *= chute
            b.night.x *= chute
            b.idleLife *= chute
            b.night.z *= 1 - lisse((a - 0.25) / 0.75)
            b.camera.z = Self.zoomPose
                + (Self.zoomMort - Self.zoomPose) * lisse(a)
        }
        return b
    }
}

// MARK: - La vue

struct LuneDeSangView: View {
    var onFinish: () -> Void = {}

    /// L'horloge : posée SEULEMENT quand la LUT du croissant est prête —
    /// toucher `MoonSDF.image` sur le fil principal pendant la cuisson bloque
    /// et fait sauter le début du plan (la loi du grand splash).
    @State private var start: Date?
    @State private var finished = false

    /// `-luneSangFreeze <t>` fige la partition à l'instant t — la scène se
    /// règle par captures. ⚠️ Comme `-moonSplashFreeze`, le drapeau coupe le
    /// minuteur de fin : la porte ne s'ouvre plus que d'un tap. C'est voulu.
    private static let freeze: Double? = UserDefaults.standard
        .string(forKey: "luneSangFreeze").flatMap(Double.init)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = CGSize(width: geo.size.width,
                              height: geo.size.height
                                  + geo.safeAreaInsets.top
                                  + geo.safeAreaInsets.bottom)
            ZStack {
                Color.black
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                    let t = Self.freeze
                        ?? start.map { tl.date.timeIntervalSince($0) } ?? 0
                    let b = LuneDeSangBeat.at(reduceMotion
                                              ? LuneDeSangBeat.t3 : t)
                    // `soloNeon: 1` — LE PAVÉ N'EXISTE PAS : il n'y a que le
                    // croissant dans la nuit, comme sur la maquette (et comme
                    // la phase « nuit » de l'archive : solo 1 + night.x 1 =
                    // le néon seul sous le clair de lune). La caméra vient de
                    // la partition : c'est elle qui fait la plongée.
                    MonolithCanvas(size: size, t: Float(
                                       tl.date.timeIntervalSinceReferenceDate
                                           .truncatingRemainder(dividingBy: 900)),
                                   userYaw: b.yaw,
                                   reveal: b.reveal,
                                   camera: b.camera,
                                   cineCtl: b.cineCtl,
                                   soloNeon: 1,
                                   idleLife: b.idleLife,
                                   night: b.night)
                }
                // Le grain de la maison, à la dose du splash : les nappes
                // sombres bandent sur OLED.
                WoopGrain(density: 0.018, lightAlpha: 0.014, darkAlpha: 0.013)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        // La loi du splash : un tap termine à tout instant. Le callback fait
        // foi, jamais la durée nominale.
        .onTapGesture { finish() }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .task {
            RocketHaptics.shared.prepare()
            // La LUT se LIT du bundle (deux millisecondes) ; ce qui se chauffe
            // vraiment, c'est la compilation du shader. On attend quand même :
            // une horloge posée avant `isReady` mange le début du plan.
            // ⚠️ Le `try?` AVALE l'annulation : sur une vue démontée, un
            // `sleep` annulé revient immédiatement et la boucle tournerait à
            // CHAUD jusqu'à `isReady`. La garde rend l'attente annulable.
            while !MoonSDF.isReady {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
            guard Self.freeze == nil else { return }
            if reduceMotion {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else { return }
                finish()
                return
            }
            start = .now
            // Les battements partent D'UN BLOC au moteur — jamais cadencés
            // par la boucle d'affichage. Le premier est FORT : le choc de la
            // pose, quand la plongée s'arrête.
            RocketHaptics.shared.paliers(LuneDeSangBeat.battements)
            try? await Task.sleep(nanoseconds:
                UInt64(LuneDeSangBeat.total * 1_000_000_000))
            // Une vue démontée ne déclare pas de fin : le callback appartient
            // à l'écran encore monté.
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        RocketHaptics.shared.stop()
        onFinish()
    }
}

// MARK: - Le banc (`-luneSangLab`)

/// La partition en boucle à la demande : elle joue, puis « Rejouer ».
/// `-luneSangFreeze <t>` fige un instant (le bouton ne sert alors à rien,
/// la vue figée EST la capture).
struct LuneSangLab: View {
    @State private var run = UUID()
    @State private var finie = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LuneDeSangView {
                withAnimation(.easeOut(duration: 0.3)) { finie = true }
            }
            .id(run)
            if finie {
                Button("Rejouer") {
                    finie = false
                    run = UUID()
                }
                .font(.inter(14, .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 560)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    LuneDeSangView()
}
