import SwiftUI
import AVFoundation
import UIKit

// MARK: - Le panneau « Recommencer ? »

/// AU RETOUR DE BRAVO, LA QUESTION. La fiche se réinstalle et un panneau de
/// verre monte du bas — l'école SetEntrySheet, à la lettre : NOTRE panneau
/// dans l'arbre de la fiche, jamais un sheet système (la présentation
/// d'iOS 26 recule toute la fenêtre et révèle un fond gris — payé deux
/// fois), le vrai Liquid Glass qui réfracte la carte Série et le galet.
///
/// En tête : la flamme (`flamme_overlay`, boucle ping-pong muette) sous une
/// petite caméra qui se pose — la présence, pas un plan. Puis la question,
/// le primaire de la maison, et l'échappée d'encre. Tirer le panneau vers
/// le bas, c'est dire non — et pendant qu'il descend, la carte Série
/// s'anime derrière : les pièces volent, le compte s'allume.
struct RestartSheet: View {
    var onLaunch: () -> Void = {}
    var onDismiss: () -> Void = {}

    /// Le drag de rangement — sur TOUTE la surface : pas de molettes ici,
    /// les deux boutons gardent leurs taps (le drag exige 12 pt).
    @State private var pull: CGFloat = 0
    /// L'instant de naissance : la petite caméra du header et la poussière
    /// de diamants s'écrivent dessus — fonction pure du temps.
    @State private var born: Date = .now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Coins hauts seuls — le bas appartient à l'écran (le CADRE FANTÔME
    /// est une faute déjà payée).
    private static let shape = UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: 34, bottomLeading: 0,
                           bottomTrailing: 0, topTrailing: 34),
        style: .continuous)

    var body: some View {
        GeometryReader { g in
            VStack(spacing: 0) {
                flameHeader(W: g.size.width, slotH: g.size.height * 0.30)
                Text("Do you want to repeat\nthis exercise?")
                    .font(.inter(20, .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
                    .padding(.horizontal, 30)
                Text("The next set starts on a 3, 2, 1.")
                    .font(.inter(12.5))
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 7)
                    .padding(.horizontal, 30)
                Spacer(minLength: 0)
                DiamondPrimaryButton(title: "Start exercise") { onLaunch() }
                    .padding(.horizontal, 26)
                // L'échappée : de l'encre seule — sur la nuit, un cadre
                // clair se lit comme un bug (l'école du footer de BRAVO).
                Button { onDismiss() } label: {
                    Text("No, I'm done")
                        .font(.inter(15, .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
        // LE VERRE EST LE VRAI — il échantillonne la fiche vivante. Et
        // par-dessus, LA NUIT QUI FOND : quasi opaque en haut (elle épouse
        // le noir de la vidéo — la couture verre/vidéo jurait, verdict
        // Kathryn), transparente en pied — le bas du panneau redevient du
        // verre aéré, la fiche respire à travers, le diamant vit sur l'air.
        .background {
            ZStack {
                Color.clear.glassEffect(
                    .regular.tint(Color.black.opacity(0.30)),
                    in: Self.shape)
                Self.shape
                    .fill(LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.95),
                                  location: 0),
                            .init(color: Color.black.opacity(0.88),
                                  location: 0.38),
                            .init(color: Color.black.opacity(0.25),
                                  location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom))
                    .allowsHitTesting(false)
            }
        }
        // La vidéo file bord à bord : c'est le panneau qui porte les coins.
        .clipShape(Self.shape)
        // Le fil du bord — seulement là où la feuille se détache de la page.
        .overlay {
            Self.shape
                .strokeBorder(LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.16), location: 0),
                        .init(color: Color.white.opacity(0.03), location: 0.18),
                        .init(color: .clear, location: 0.45)
                    ],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .allowsHitTesting(false)
        }
        .offset(y: pull)
        // TOUTE la surface attrape le drag — la zone de la flamme était
        // devenue transparente au toucher quand son fond noir est parti
        // (payé : « j'arrive pas à drag »). La contentShape rend chaque
        // pixel du panneau saisissable, et le geste SIMULTANÉ laisse les
        // deux boutons garder leurs taps (12 pt de course avant que le
        // drag n'existe).
        .contentShape(Self.shape)
        .simultaneousGesture(dismissDrag)
    }

    // MARK: La flamme et sa petite caméra

    /// La caméra entre par la GÉOMÉTRIE du cadre (l'école BravoCine : le
    /// lecteur redécode aux nouvelles bornes, jamais un zoom rastérisé) —
    /// et la vidéo n'est JAMAIS fille d'un drawingGroup (le carré jaune).
    private func flameHeader(W: CGFloat, slotH: CGFloat) -> some View {
        // L'horloge ne se met plus en pause : la poussière de diamants
        // rouges vit en continu (la caméra, elle, est posée depuis
        // longtemps — son terme est mort à ~2 s).
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: reduceMotion)) { tl in
            let e = tl.date.timeIntervalSince(born)
            // Posée en ~1,8 s, pente qui meurt : une présence, pas un plan.
            let z: CGFloat = reduceMotion ? 1 : 1 + 0.12 * exp(-e * 1.9)
            let fadeIn = min(1, max(e, 0) / 0.45)
            ZStack {
                // CENTRÉE ET SANS RECTANGLE : la source est une flamme sur
                // du noir pur (point noir écrasé à l'encodage) — en ADDITIF
                // le noir disparaît sans détourage (la leçon des cartes
                // démon), il ne reste que la flamme sur la nuit du panneau.
                // 1,28 : « je la voyais un peu plus grosse » (verdict
                // Kathryn, round 3).
                RestartFlameVideo()
                    .frame(width: slotH * (4.0 / 3.0) * 1.28 * z,
                           height: slotH * 1.28 * z)
                    .blendMode(.plusLighter)
                // LA POUSSIÈRE DE DIAMANTS ROUGES — très très fine :
                // des croix taillées de 0,8 à 2 pt qui montent en dérivant
                // autour de la flamme, chacune son scintillement. Fonction
                // pure du temps : chaque pierre boucle sur son cycle
                // propre, aucun état, rien à semer.
                redDust(t: e, W: W, slotH: slotH)
            }
            // 8 pt sous la poignée : la pointe de la flamme ne monte plus
            // jusqu'à la barre grise (verdict Kathryn).
            .offset(y: 8)
            .frame(width: W, height: slotH)
            .clipped()
            .opacity(fadeIn)
        }
        .frame(height: slotH)
    }

    private func redDust(t: Double, W: CGFloat, slotH: CGFloat) -> some View {
        Canvas { ctx, _ in
            for i in 0..<26 {
                let life = 2.6 + 2.2 * Self.hash(i, 2)
                let cyc = (t / life + Self.hash(i, 5))
                    .truncatingRemainder(dividingBy: 1)
                // Naît autour de la flamme, monte d'un souffle en dérivant.
                let cx = W / 2 + (Self.hash(i, 1) - 0.5) * slotH * 1.9
                let cy = slotH * (0.30 + 0.62 * Self.hash(i, 3))
                let x = cx + sin(t * (0.5 + Self.hash(i, 8))
                                 + Self.hash(i, 9) * 6.28) * 7
                let y = cy - CGFloat(cyc) * slotH * 0.34
                // Le voile de vie : entre en douceur, meurt en montant —
                // et scintille TRANCHÉ (le cube), comme les pierres du
                // slider.
                let s = sin(.pi * cyc)
                let tw0 = 0.5 + 0.5 * sin(t * (9 + 14 * Self.hash(i, 4))
                                          + Self.hash(i, 6) * 6.28)
                let a = s * s * (0.25 + 0.75 * tw0 * tw0 * tw0)
                guard a > 0.02 else { continue }
                let r = CGFloat(0.8 + 1.2 * Self.hash(i, 7))
                // Rouge braise — deux tempéraments : rubis profond et
                // rouge-orangé vif, jamais de rose.
                let deep = Self.hash(i, 10) < 0.4
                let c = deep
                    ? Color(red: 0.88, green: 0.16, blue: 0.12)
                    : Color(red: 1.00, green: 0.34, blue: 0.16)
                var star = Path()
                star.move(to: CGPoint(x: -r, y: 0))
                star.addLine(to: CGPoint(x: 0, y: -r * 0.22))
                star.addLine(to: CGPoint(x: r, y: 0))
                star.addLine(to: CGPoint(x: 0, y: r * 0.22))
                star.closeSubpath()
                star.move(to: CGPoint(x: 0, y: -r))
                star.addLine(to: CGPoint(x: r * 0.22, y: 0))
                star.addLine(to: CGPoint(x: 0, y: r))
                star.addLine(to: CGPoint(x: -r * 0.22, y: 0))
                star.closeSubpath()
                let placed = star.applying(
                    CGAffineTransform(translationX: x, y: y)
                        .rotated(by: (Self.hash(i, 11) - 0.5) * 0.9))
                ctx.fill(placed, with: .color(c.opacity(a * 0.9)))
                // Le cœur vif — c'est lui la facette.
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 0.5, y: y - 0.5,
                                           width: 1.0, height: 1.0)),
                    with: .color(Color(red: 1.0, green: 0.62, blue: 0.45)
                        .opacity(a)))
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .frame(width: W, height: slotH)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { v in
                pull = max(0, v.translation.height)
            }
            .onEnded { _ in
                if pull > 90 {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.34,
                                          dampingFraction: 0.82)) { pull = 0 }
                }
            }
    }
}

// MARK: - La flamme en boucle

/// Le gabarit boucle pure de la maison (l'école DemonVideo) : un
/// `AVPlayerLayer` nu, un `AVPlayerLooper` RETENU par le Coordinator
/// (relâché, la boucle s'arrête au premier tour), muet, jamais
/// didPlayToEndTime+seek (l'image noire au raccord). Le fichier est un
/// PING-PONG ré-encodé (aller-retour, 16 s) : la lumière de la flamme
/// dérive sur 8 s — l'aller-retour rend le bouclage sans saut.
private final class FlameLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

private struct RestartFlameVideo: UIViewRepresentable {
    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> FlameLayerView {
        let v = FlameLayerView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        // ENTIÈRE ET CENTRÉE, jamais recadrée : le cadre est posé côté
        // SwiftUI au format exact de la source (4:3), l'additif efface
        // le noir autour.
        v.playerLayer.videoGravity = .resizeAspect
        guard let url = Bundle.main.url(forResource: "flamme_overlay",
                                        withExtension: "mp4") else {
            // Sans le fichier, le panneau reste le panneau — jamais un
            // rectangle noir « en attendant ».
            return v
        }
        let item = AVPlayerItem(url: url)
        let p = AVQueuePlayer()
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        context.coordinator.looper = AVPlayerLooper(player: p,
                                                    templateItem: item)
        context.coordinator.player = p
        v.playerLayer.player = p
        p.play()
        return v
    }

    func updateUIView(_ v: FlameLayerView, context: Context) {}

    static func dismantleUIView(_ v: FlameLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }
}

// MARK: - Les pièces de la série

/// LA SÉRIE S'ÉCRIT EN PIÈCES. Quand le panneau s'en va, une poignée de
/// pièces de lune vole vers la carte Série — l'école CoinField de BRAVO :
/// UNE seule horloge pilote tout le champ en appel shader brut (empiler
/// des MoonCoinView, c'est un TimelineView par pièce — interdit), les
/// pièces volent ALLUMÉES et s'éteignent à l'arrivée (on ne fait jamais
/// apparaître une lumière, et rien ne reste — le tas au sol a été refusé
/// deux fois). La balistique de BRAVO devient une interpolation
/// source → carte, chaque pièce son arc et son retard.
struct SeriesCoinFlight: View {
    let start: Date
    let source: CGPoint
    let target: CGPoint
    var count: Int = 7
    var onDone: () -> Void = {}

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let age = tl.date.timeIntervalSince(start)
            let clock = tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900)
            ZStack {
                ForEach(states(age: age), id: \.i) { st in
                    coin(st, clock: clock)
                }
            }
            .onChange(of: tl.date) { _, d in
                // La volée dure ~1,1 s ; à 1,5 le champ se démonte.
                if d.timeIntervalSince(start) > 1.5 { onDone() }
            }
        }
        .allowsHitTesting(false)
    }

    private struct CoinState: Identifiable {
        let i: Int
        var id: Int { i }
        var p: CGPoint
        var r: CGFloat
        var yaw: Double
        var lit: Double
        var alpha: Double
    }

    private func states(age: Double) -> [CoinState] {
        guard age > 0 else { return [] }
        var out: [CoinState] = []
        for i in 0..<count {
            let delay = 0.055 * Double(i) + 0.05 * Self.hash(i, 7)
            let dur = 0.60 + 0.16 * Self.hash(i, 2)
            let u = (age - delay) / dur
            guard u > 0, u < 1.08 else { continue }
            let s = min(max(u, 0), 1)
            let e = s * s * (3 - 2 * s)
            // Chaque pièce son départ, son arc et son point de chute.
            let sx = source.x + (Self.hash(i, 1) - 0.5) * 70
            let sy = source.y + (Self.hash(i, 5) - 0.5) * 30
            let tx = target.x + (Self.hash(i, 3) - 0.5) * 18
            let ty = target.y + (Self.hash(i, 9) - 0.5) * 8
            // L'arc : un contrôle au-dessus du chemin — la pièce MONTE
            // avant de se poser, elle ne file pas en ligne droite.
            let cx = (sx + tx) / 2 + (Self.hash(i, 11) - 0.5) * 90
            let cy = min(sy, ty) - 70 - 60 * Self.hash(i, 4)
            let mt = 1 - e
            let x = mt * mt * sx + 2 * mt * e * cx + e * e * tx
            let y = mt * mt * sy + 2 * mt * e * cy + e * e * ty
            // Le lacet se range en arrivant — la pièce se pose de face.
            let yaw = (5.0 + 4.0 * Self.hash(i, 6)) * (1 - e) * (1 - e)
                    + Self.hash(i, 8) * 6.28 * (1 - e)
            let lit = 1 - Self.sstep(0.80, 0.97, s)
            let alpha = min(1, u * 9) * (1 - Self.sstep(0.90, 1.06, u))
            out.append(CoinState(
                i: i,
                p: CGPoint(x: x, y: y),
                r: CGFloat(7.5 + 3.0 * Self.hash(i, 3)),
                yaw: yaw, lit: lit, alpha: alpha))
        }
        return out
    }

    private func coin(_ st: CoinState, clock: Double) -> some View {
        let side = st.r * MoonCoinView.hostScale
        return Rectangle()
            .fill(.white)
            .frame(width: side, height: side)
            .colorEffect(ShaderLibrary.moonCoin(
                .float2(Float(side), Float(side)),
                .float(Float(clock)),
                .float2(0, 0),
                .float(Float(st.yaw)),
                .float(Float(st.r)),
                .float(Float(st.lit)),
                .float(1),
                .float3(MoonSDF.padding, MoonSDF.tightRange,
                        MoonSDF.wideRange),
                .float3(0.5, 0.485, 0.71),
                .float4(0.86, 0.62, 1.0, 1.0),
                .image(MoonSDF.image)))
            .position(st.p)
            .opacity(st.alpha)
    }

    private static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }
}
