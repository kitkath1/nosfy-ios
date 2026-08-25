import SwiftUI

// MARK: - Banc d'essai (`-logoLab`)

/// Page noire nue : le monolithe du logo seul — un pavé de laque noire vu de
/// trois quarts, la lune du logo en tube de néon sur sa face, un filet
/// orange qui court autour de l'arête, une raie anamorphique et une flaque
/// de lumière au sol. Plein écran, et il TOURNE : le doigt le fait pivoter
/// à droite et à gauche.
///
/// Sous-flags de capture (le pattern des bancs — figer l'état transitoire
/// plutôt que taper au bon centième) :
///   `-logoFreeze <t>` fige l'horloge du shader à t secondes (captures
///   déterministes — les arguments `-clé valeur` tombent dans UserDefaults,
///   même mécanique que `openTab`) ;
///   `-logoYaw <rad>` fige la rotation manuelle (pour capturer l'objet
///   tourné sans garder le doigt posé) ;
///   `-logoBoost` fige la montée du néon à son pic (LE test du criard) ;
///   `-logoSweep` fige le point chaud du filet à mi-course.
struct LogoLab: View {
    private static let freeze: Float? = UserDefaults.standard
        .string(forKey: "logoFreeze").flatMap(Float.init)
    private static let yaw: Float? = UserDefaults.standard
        .string(forKey: "logoYaw").flatMap(Float.init)
    private static let boost = CommandLine.arguments.contains("-logoBoost")
    private static let sweep = CommandLine.arguments.contains("-logoSweep")

    /// Prime sur `-logoFreeze` : les previews ne portent pas d'arguments.
    var freezeOverride: Float? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            MonolithScene(freeze: freezeOverride ?? Self.freeze,
                          yawOverride: Self.yaw,
                          benchBoost: Self.boost ? 1.0 : nil,
                          // 0,83 et non 0,5 : l'abscisse curviligne de lmArc
                          // part du coin haut-gauche dans le sens horaire, et
                          // l'ARÊTE VERTICALE GAUCHE — celle que la référence
                          // veut vive, et où l'étoile fleurit — occupe
                          // [0,750 ; 0,905]. À 0,5 le banc figeait le point
                          // chaud au milieu du bord BAS : on capturait le seul
                          // endroit qu'on ne cherchait pas à juger.
                          benchSweep: Self.sweep ? 0.83 : nil)
                .ignoresSafeArea()

            // Le grain de la maison, MOITIÉ DOSE ici : le shader possède déjà
            // son propre dither à 1,6/255, et toute la calibration de la scène
            // vit sous 15/255 (halo 14,6 ; laque 10,6 ; fond médiane 0). Un
            // grain à darkAlpha 0,028 = ±7/255 posé par-dessus noie le halo
            // d'ambiance et fait sauter la métrique « ≥ 95 % des pixels du
            // fond < 8/255 ». Leçon : quand le shader dithère lui-même, le
            // grain d'hôte n'est plus une assurance, c'est du bruit.
            WoopGrain(density: 0.018, lightAlpha: 0.014, darkAlpha: 0.013)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }
}

// MARK: - La scène

/// L'hôte du shader `logoMonolith` : plein écran, 30 fps, horloge mod 900,
/// PLEINE résolution — contrairement au ciel, tout le contenu signature est
/// sub-pixel (filet de 1 pt, cœur du tube, poussière) et le coût est
/// concentré sur une petite part de l'écran.
///
/// La rotation au doigt est une FONCTION PURE DU TEMPS : le glissement
/// pendant le geste, puis une inertie amortie résolue analytiquement
/// (v·(1−e^{−kt})/k), puis un retour doux au repos. Rien ne s'accumule par
/// image — le TimelineView recalcule tout depuis les horodatages, comme la
/// bouffée du cadran.
struct MonolithScene: View {
    var freeze: Float? = nil
    /// Rotation manuelle figée (radians) — pour les captures.
    var yawOverride: Float? = nil
    var benchBoost: Float? = nil
    var benchSweep: Float? = nil

    /// La demi-face, en points. 76 est le cadrage historique du banc ; le
    /// splash le réduit pour poser un petit monolithe sur l'écran de
    /// connexion. Tout le reste de la scène est calibré en POINTS et suit
    /// donc proportionnellement (le seuil de la sortie anticipée, la flaque,
    /// la profondeur) — sauf les hairlines, qui doivent rester des hairlines.
    var faceR: Float = 76
    /// La caméra : (cible.x, cible.y, zoom) en points de scène. Neutre par
    /// défaut — la scène ne bouge pas d'un LSB tant que le splash ne la
    /// pilote pas.
    var camera: SIMD3<Float> = SIMD3(0, 0, 1)
    /// (cinéma, boom, ouverture du fond, tête de comète imposée).
    var cineCtl: SIMD4<Float> = SIMD4(0, 0, 0, -1)
    /// Fond les raies et le halo avant le bord du cadre — pour les petits
    /// formats, où ils seraient tranchés net.
    var edgeFade: Float = 0
    /// Rampe d'allumage imposée (sinon : la rampe 2 s interne).
    var revealOverride: Float? = nil
    /// Le geste est-il actif ? Le splash le coupe pendant la cinématique.
    var interactive: Bool = true
    /// La zone qui capte le doigt. Nil = tout le cadre (le banc). Posé sur
    /// l'écran de connexion, le shader occupe TOUT l'écran alors que l'objet
    /// n'en occupe qu'un coin : sans cette restriction, il volerait la
    /// caresse de l'aurore sur les neuf dixièmes de la page.
    var hitArea: CGRect? = nil
    /// Images par seconde. 30 suffit à un objet qu'on tourne au doigt ; le
    /// travelling du splash, lui, EXIGE 60 — voir MoonSplash.swift, où le
    /// calcul est fait.
    var fps: Double = 30
    /// À 1, le pavé disparaît : il ne reste que le croissant de néon dans le
    /// noir. L'état du travelling du splash.
    var soloNeon: Float = 0
    /// La vie de l'objet posé — cf. MonolithCanvas.
    var idleLife: Float = 0
    /// Le plan de nuit : (atmosphère, marée des nuages, braise mourante).
    var night: SIMD4<Float> = .zero

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealStart: Date = .now

    /// L'état du geste — horodaté, jamais intégré par image.
    @State private var dragging = false
    @State private var yawAtGrab: Float = 0
    @State private var yawLive: Float = 0
    @State private var releaseAt: Date = .distantPast
    @State private var releaseYaw: Float = 0
    @State private var releaseVel: Float = 0
    /// La dernière position où la lumière a murmuré — le son suit le geste
    /// par PAS d'angle, pas par image : tourner lentement murmure peu.
    @State private var chimeYaw: Float = 0
    @State private var chimeTick = 0

    private var motion: SkyMotion { .shared }

    /// Combien de radians par point glissé : ~0,43° par point, soit un
    /// demi-tour de la fourchette utile sur 80 pt — le pavé suit le doigt
    /// sans jamais partir en toupie.
    private static let radPerPoint: Float = 0.0075
    /// La borne. Elle NE CHANGE PAS — mais sa raison d'être a changé : la
    /// silhouette est passée à six tranches (résidu radial mesuré contre une
    /// référence à 161 tranches : 0,048 pt au repos, 0,266 pt à 34°, 0,705 pt
    /// à cette butée, pour un seuil de visibilité de 0,333 pt = 1 px à 3x).
    /// Trois tranches créneautaient dès 20° de lacet ; six tiennent jusqu'à
    /// ~40°, et le reste est un transitoire tenu au doigt. On garde donc
    /// toute la course du geste au lieu de la rogner.
    private static let yawLimit: Float = 0.61
    /// Amortissement de l'inertie (s⁻¹) et début du retour au repos.
    private static let damping: Float = 2.2
    private static let restDelay: Float = 1.8
    private static let restFall: Float = 2.6

    /// Le lacet manuel à une date donnée — fonction pure.
    private func userYaw(at date: Date) -> Float {
        if let forced = yawOverride { return forced }
        if dragging { return yawLive }
        let age = Float(date.timeIntervalSince(releaseAt))
        guard age.isFinite, age >= 0, age < 3600 else { return 0 }
        // Inertie : intégrale exacte d'une vitesse amortie exponentiellement.
        var y = releaseYaw + releaseVel * (1 - exp(-Self.damping * age)) / Self.damping
        // Puis l'objet revient doucement à son angle de repos.
        y *= exp(-max(age - Self.restDelay, 0) / Self.restFall)
        return max(-Self.yawLimit, min(Self.yawLimit, y))
    }

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            TimelineView(.animation(minimumInterval: 1.0 / fps,
                                    paused: reduceMotion && !dragging)) { tl in
                // Le temps part en float32 vers le GPU : modulo 900 s — tout
                // le shader est périodique sur 900 s exactement.
                let t = freeze ?? Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                let raw = freeze == nil
                    ? min(max(tl.date.timeIntervalSince(revealStart) / 2.0, 0), 1)
                    : 1.0
                let reveal = revealOverride ?? Float(raw * raw * (3 - 2 * raw))
                let tiltV = SIMD2<Float>(Float(motion.tilt.dx),
                                         Float(motion.tilt.dy))
                MonolithCanvas(size: CGSize(width: w, height: h), t: t,
                               tilt: tiltV,
                               userYaw: userYaw(at: tl.date), reveal: reveal,
                               faceR: faceR, benchBoost: benchBoost,
                               benchSweep: benchSweep,
                               camera: camera, cineCtl: cineCtl,
                               edgeFade: edgeFade, soloNeon: soloNeon,
                               idleLife: idleLife, night: night)
            }
        }
        // Le pavé tourne sous le doigt : glissement horizontal → lacet, et
        // l'élan du relâcher se prolonge en inertie.
        .contentShape(MonolithHitShape(rect: hitArea))
        .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if !dragging {
                        dragging = true
                        yawAtGrab = userYaw(at: .now)
                        chimeYaw = yawAtGrab
                        MonolithChime.shared.prepare()
                    }
                    yawLive = max(-Self.yawLimit, min(Self.yawLimit,
                        yawAtGrab + Float(v.translation.width) * Self.radPerPoint))
                    // La lumière murmure par pas de ~5° de rotation, à un
                    // volume qui suit l'ampleur du pas — et la main reçoit
                    // un tic très doux au même instant : l'œil, l'oreille et
                    // la paume racontent le même reflet.
                    let step = abs(yawLive - chimeYaw)
                    if step > 0.085 {
                        MonolithChime.shared.turn(speed: Double(min(step / 0.30, 1)))
                        chimeYaw = yawLive
                        chimeTick += 1
                    }
                }
                .onEnded { v in
                    releaseYaw = yawLive
                    // L'élan : ce qu'il restait de course dans le geste.
                    let fling = Float(v.predictedEndTranslation.width
                                      - v.translation.width)
                    releaseVel = fling * Self.radPerPoint * Self.damping
                    releaseAt = .now
                    dragging = false
                    MonolithChime.shared.release(
                        fling: Double(min(abs(releaseVel) / 1.6, 1)))
                },
            // Pendant la cinématique, le pavé est un PLAN, pas un objet qu'on
            // manipule : le doigt ne doit pas pouvoir contrarier la caméra.
            including: interactive ? .all : .subviews
        )
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.32),
                         trigger: chimeTick)
        .onAppear { motion.start(reduceMotion: reduceMotion) }
        .onChange(of: scenePhase) { _, phase in
            // Le gyroscope s'arrête sur `scenePhase` SEULEMENT — jamais
            // `onDisappear` : `stop()` remet le tilt à zéro pour tous les
            // consommateurs, dont le ciel de la home.
            if phase == .active {
                revealStart = .now
                motion.start(reduceMotion: reduceMotion)
            } else {
                motion.stop()
            }
        }
    }
}

// MARK: - La toile

/// Le rendu nu du shader, SANS horloge. Tout lui arrive en paramètres.
///
/// C'est ce découpage qui rend la cinématique fluide : le splash a sa propre
/// `TimelineView`, et si la scène en gardait une seconde à l'intérieur, les
/// deux tiqueraient indépendamment — la caméra serait calculée à un instant,
/// le shader dessiné à un autre, et le plan avancerait par à-coups sans que
/// personne ne soit en retard. Une horloge, une image.
struct MonolithCanvas: View {
    var size: CGSize
    var t: Float
    var tilt: SIMD2<Float> = .zero
    var userYaw: Float = 0
    var reveal: Float = 1
    var faceR: Float = 76
    var benchBoost: Float? = nil
    var benchSweep: Float? = nil
    var camera: SIMD3<Float> = SIMD3(0, 0, 1)
    var cineCtl: SIMD4<Float> = SIMD4(0, 0, 0, -1)
    var edgeFade: Float = 0
    var soloNeon: Float = 0
    /// La vie de l'objet POSÉ : flottement lent et grésillement rare. Nulle
    /// pendant la cinématique, pleine une fois la lune arrivée sur la page.
    var idleLife: Float = 0
    /// Le plan de nuit : (atmosphère, marée des nuages, braise mourante).
    var night: SIMD4<Float> = .zero

    fileprivate static let debugSDF = CommandLine.arguments.contains("-logoDebugSDF")

    var body: some View {
        Rectangle()
            .fill(.black)
            .frame(width: size.width, height: size.height)
            .colorEffect(Self.dithered(ShaderLibrary.logoMonolith(
                .float2(size.width, size.height), .float(t),
                .float2(tilt.x, tilt.y), .float(userYaw),
                .float(reveal), .float(faceR),
                .float(benchBoost ?? -1), .float(benchSweep ?? -1),
                .float(Self.debugSDF ? 1 : 0),
                .float3(MoonSDF.padding, MoonSDF.tightRange, MoonSDF.wideRange),
                .float3(0.5, 0.485, 0.71),
                .float3(camera.x, camera.y, camera.z),
                .float4(cineCtl.x, cineCtl.y, cineCtl.z, cineCtl.w),
                .float(edgeFade), .float(soloNeon), .float(idleLife),
                .float4(night.x, night.y, night.z, night.w),
                .image(MoonSDF.image))))
    }

    /// Dithering natif du shader : casse le banding 8 bits des longues
    /// rampes sombres de la laque et du bloom, quasi gratuit.
    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }
}

/// La zone sensible de la scène : tout le cadre, ou le seul voisinage de
/// l'objet quand il n'occupe qu'un coin de l'écran.
private struct MonolithHitShape: Shape {
    var rect: CGRect?

    func path(in bounds: CGRect) -> Path {
        Path(rect ?? bounds)
    }
}

#Preview { LogoLab() }
#Preview("Figé t=60") { LogoLab(freezeOverride: 60) }
