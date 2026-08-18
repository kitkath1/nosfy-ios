import SwiftUI

// MARK: - Banc d'essai (`-flameLab`)

/// Page noire nue : la flamme bijou seule — un objet 3D raymarché, laqué,
/// qui danse sur place dans son halo braise. Le doigt la fait pivoter à
/// droite et à gauche (inertie au relâcher, retour doux au repos), et un
/// tap lâche une bouffée de fumée orange en filaments, avec un rebond
/// squash-stretch et un tic dans la paume.
///
/// Sous-flags de capture (le pattern des bancs) :
///   `-flameFreeze <t>` fige l'horloge du shader à t secondes ;
///   `-flameYaw <rad>` fige la rotation manuelle ;
///   `-flamePuff <age>` fige une bouffée à cet âge (fumée déterministe).
struct FlameLab: View {
    private static let freeze: Float? = UserDefaults.standard
        .string(forKey: "flameFreeze").flatMap(Float.init)
    private static let yaw: Float? = UserDefaults.standard
        .string(forKey: "flameYaw").flatMap(Float.init)
    private static let puff: Float? = UserDefaults.standard
        .string(forKey: "flamePuff").flatMap(Float.init)

    /// Prime sur `-flameFreeze` : les previews ne portent pas d'arguments.
    var freezeOverride: Float? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            FlameScene(freeze: freezeOverride ?? Self.freeze,
                       yawOverride: Self.yaw,
                       puffOverride: Self.puff)
                .ignoresSafeArea()
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }
}

// MARK: - La scène

/// L'hôte du shader `flameJewel` : plein écran, 60 fps — la danse et la
/// fumée sont des mouvements continus, 30 les ferait vibrer.
///
/// La rotation au doigt est une FONCTION PURE DU TEMPS (le pattern du
/// monolithe) : glissement pendant le geste, inertie amortie résolue
/// analytiquement au relâcher, puis retour doux au repos. Rien ne
/// s'accumule par image.
struct FlameScene: View {
    var freeze: Float? = nil
    var yawOverride: Float? = nil
    var puffOverride: Float? = nil

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealStart: Date = .now

    /// L'état du geste — horodaté, jamais intégré par image.
    @State private var began = false
    @State private var dragging = false
    @State private var yawAtGrab: Float = 0
    @State private var yawLive: Float = 0
    @State private var releaseAt: Date = .distantPast
    @State private var releaseYaw: Float = 0
    @State private var releaseVel: Float = 0
    /// Les deux dernières bouffées — deux suffisent : à la troisième, la
    /// première est déjà éteinte (3,2 s de vie).
    @State private var puffDates: [Date] = []
    @State private var puffTick = 0

    /// ~0,63° par point : un demi-tour sur ~280 pt de glissement.
    private static let radPerPoint: Float = 0.011
    /// La butée : au-delà, la silhouette de trois quarts arrière ne raconte
    /// plus rien — et l'inertie ramène toujours dans la fourchette.
    private static let yawLimit: Float = 2.2
    private static let damping: Float = 2.0
    private static let restDelay: Float = 2.2
    private static let restFall: Float = 3.2

    /// Le lacet manuel à une date donnée — fonction pure.
    private func userYaw(at date: Date) -> Float {
        if let forced = yawOverride { return forced }
        if dragging { return yawLive }
        let age = Float(date.timeIntervalSince(releaseAt))
        guard age.isFinite, age >= 0, age < 3600 else { return 0 }
        var y = releaseYaw + releaseVel * (1 - exp(-Self.damping * age)) / Self.damping
        y *= exp(-max(age - Self.restDelay, 0) / Self.restFall)
        return max(-Self.yawLimit, min(Self.yawLimit, y))
    }

    /// Les âges des deux dernières bouffées (négatif = pas de bouffée).
    private func puffAges(at date: Date) -> SIMD2<Float> {
        if let forced = puffOverride { return SIMD2(forced, -1) }
        var ages = SIMD2<Float>(-1, -1)
        for (i, d) in puffDates.suffix(2).reversed().enumerated() where i < 2 {
            ages[i] = Float(date.timeIntervalSince(d))
        }
        return ages
    }

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: reduceMotion && !dragging)) { tl in
                // Le temps part en float32 vers le GPU : modulo 900 s.
                let t = freeze ?? Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                let raw = freeze == nil
                    ? min(max(tl.date.timeIntervalSince(revealStart) / 0.9, 0), 1)
                    : 1.0
                FlameCanvas(size: CGSize(width: w, height: h), t: t,
                            yaw: userYaw(at: tl.date), reveal: Float(raw),
                            puffs: puffAges(at: tl.date))
            }
        }
        // Glisser = lacet ; un relâcher quasi immobile = un tap, la bouffée.
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                if !began {
                    began = true
                    yawAtGrab = userYaw(at: .now)
                }
                let travel = abs(v.translation.width) + abs(v.translation.height)
                if !dragging && travel > 10 { dragging = true }
                if dragging {
                    yawLive = max(-Self.yawLimit, min(Self.yawLimit,
                        yawAtGrab + Float(v.translation.width) * Self.radPerPoint))
                }
            }
            .onEnded { v in
                if dragging {
                    releaseYaw = yawLive
                    // L'élan : ce qu'il restait de course dans le geste.
                    let fling = Float(v.predictedEndTranslation.width
                                      - v.translation.width)
                    releaseVel = fling * Self.radPerPoint * Self.damping
                    releaseAt = .now
                } else {
                    puffDates.append(.now)
                    if puffDates.count > 2 { puffDates.removeFirst() }
                    puffTick += 1
                }
                began = false
                dragging = false
            })
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55),
                         trigger: puffTick)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { revealStart = .now }
        }
    }
}

// MARK: - La toile

/// Le rendu nu du shader, SANS horloge — tout lui arrive en paramètres
/// (une horloge, une image : le pattern du monolithe).
struct FlameCanvas: View {
    var size: CGSize
    var t: Float
    var yaw: Float = 0
    var reveal: Float = 1
    var puffs: SIMD2<Float> = SIMD2(-1, -1)

    var body: some View {
        Rectangle()
            .fill(.black)
            .frame(width: size.width, height: size.height)
            .colorEffect(Self.dithered(ShaderLibrary.flameJewel(
                .float2(size.width, size.height), .float(t),
                .float(yaw), .float(reveal),
                .float2(puffs.x, puffs.y))))
    }

    /// Dithering natif : casse le banding des longues rampes du halo.
    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }
}

#Preview { FlameLab() }
#Preview("Figé t=60") { FlameLab(freezeOverride: 60) }
