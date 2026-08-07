import AVFoundation
import SwiftUI
import UIKit

// MARK: - La page BRAVO (`-bravoLab`)
//
// La série est finie. La caméra est COLLÉE à la pièce qui tombe, puis elle
// recule de 3,9× et découvre toute la scène — la pluie de pièces au complet.
// Une fois posée, la lune RESPIRE en boucle, et la page se referme dessous
// sur deux cartes de saisie et deux gestes.
//
// TOUT CE QUI SUIT EST MESURÉ SUR LE FICHIER. Rien n'est choisi au goût.
//
// LES TROIS ACTES DE LA SOURCE
//   chute   0,00 → 2,90 s : le barycentre lumineux descend de 0,057 à 0,388,
//           en u² EXACT (c'est une chute libre : cy = 0,057 + 0,330·u²), et le
//           delta inter-image culmine à 0,0244.
//   rebond  2,90 → 4,00 s : le delta s'effondre à 0,0049, le mouvement meurt.
//   veille  4,00 → 8,04 s : delta 0,0016, mais la luminance MONTE de 0,026 à
//           0,049 — la pièce s'illumine jusqu'à la dernière image.
//
// LE DÉBIT N'EST PAS UN GOÛT. Source à 24 img/s exactement : au débit k
// l'écran affiche 60/24/k rafraîchissements par image à 60 Hz et 120/24/k à
// 120 — entier des deux côtés SEULEMENT pour 1,25 et 2,5. Le débit 1,0 bat
// lui-même en 3:2 à 60 Hz : LE REPOS EST 1,25, PAS 1,0. Et `rate` n'est pas
// animable (chaque écriture est une discontinuité du CMTimebase) : UN SEUL
// palier 2,5 → 1,25, posé sur le rebond, là où la scène décélère d'elle-même.
// `play()` étant littéralement `rate = 1.0`, le débit se pose APRÈS lui.
//
// LE CADRAGE : 3,90 → 1,00.
//   • 3,90 est le PLANCHER du gros plan : en dessous, l'image (16:9) ne couvre
//     plus la hauteur de l'écran et son bord haut — mesuré à 250/255, la pièce
//     y entre tranchée — traverserait la page en ligne claire. À 3,90 l'image
//     fait 862 pt pour 852 d'écran : elle couvre, tout juste.
//   • 1,00 est le SEUL cadrage qui montre toute la scène : les satellites
//     s'étalent de x 0,078 à 0,923, et dès l'échelle 1,25 la ligne de coupe
//     tombe en plein sur l'un d'eux (mesuré 251/255 — une couture franche).
//     Entre 1,00 et 2,15 il n'y a RIEN d'utilisable.
//   • Le créneau de repos vaut EXACTEMENT la hauteur de l'image à 1,00
//     (W·9/16 = 221 pt, 26 % de la page) : c'est la condition pour que le
//     fondu de bords serve à quelque chose — dans un cadre plus haut, l'image
//     ne touche plus ses bords et le masque ne fond que du noir.
//
// LE MASQUE VIENT APRÈS L'ÉCHELLE, ET IL EST CALÉ SUR L'ÉCRAN. La page du
// trésor masque AVANT de zoomer : SwiftUI compose alors dans un tampon à la
// taille non zoomée et n'agrandit QUE CE TAMPON — le « zoom rastérisé,
// exactement le cheap ». Et un fondu calé sur l'IMAGE sort du champ dès
// l'échelle 1,1 : il ne masque plus rien.
//
// LA SOURCE EST EN 1080p, ET ELLE LE RESTE. Le master embarqué est
// suréchantillonné HORS LIGNE en Lanczos vers 2160p : le GPU ne fait plus une
// magnification bilinéaire de 2,6× au gros plan, il échantillonne un master
// deux fois plus dense. Mesuré au cadrage du gros plan : +14 % d'acutance
// moyenne, +23 % au p99, pour 0,8 Mo de plus. Ça ne crée pas de détail —
// ça cesse d'en détruire.
//
// LA BOUCLE EST UN VA-ET-VIENT, ET C'EST OBLIGATOIRE. La luminance monte sans
// arrêt de 5 à 8 s (0,0310 → 0,0494) : reboucler 8 → 5 ferait chuter la
// lumière de 37 % en une image, un clignotement toutes les 2,4 s. Et aucune
// fenêtre ne referme la boucle (la montée est monotone : la meilleure laisse
// encore 3,3 % d'écart). Le fichier de boucle est donc [8→5 à l'envers] suivi
// de [5→8] : il COMMENCE et FINIT sur la même image, mesurée à 0,0495 des deux
// côtés — saut nul par construction —, et la lune respire au lieu de battre.
enum BravoCine {
    /// Les deux seuls débits propres à 60 comme à 120 Hz.
    static let rateFast: Float = 2.5
    static let rateSlow: Float = 1.25
    /// La chute, en temps SOURCE.
    static let fallSrc: Double = 2.90
    /// Le relais vers la boucle : image 191 (7,958 s), la première image du
    /// fichier de boucle. On ne calcule jamais depuis `duration`.
    static let handoffFrame: Int64 = 191
    static var handoffSrc: Double { Double(handoffFrame) / 24.0 }

    /// La chute à l'écran : 1,16 s.
    static var fallScreen: Double { fallSrc / Double(rateFast) }
    /// Le recul du cadrage, qui part à la seconde où la pièce touche.
    static let settleFor: Double = 1.50
    static var settledAt: Double { fallScreen + settleFor }
    /// Le contenu naît dès que le cadrage est posé — pas à la fin de la vidéo.
    static var contentAt: Double { settledAt + 0.24 }
    /// Le relais, à l'écran : 5,21 s.
    static var handoffAt: Double {
        fallScreen + (handoffSrc - fallSrc) / Double(rateSlow)
    }
    static let crossFade: Double = 0.30

    static let zoomOpen: CGFloat = 3.90
    static let zoomRest: CGFloat = 1.00
    /// Le flou du gros plan — il se résorbe avec le recul. Ce n'est pas une
    /// rustine de résolution : c'est la mise au point qui se fait, et c'est
    /// l'école du plongeon de la connexion (le flou couvre la trame avant
    /// qu'elle ne se voie).
    static let blurOpen: CGFloat = 8.0

    static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// Le recul, 0 → 1. Départ à pente nulle, arrivée à pente nulle : la
    /// caméra ne s'arrête jamais net.
    static func pull(_ e: Double) -> Double {
        sstep(fallScreen, settledAt, e)
    }

    static func zoom(_ e: Double) -> CGFloat {
        // Exponentielle, comme le plongeon : à échelle constante par seconde,
        // le recul se SENT linéaire à l'œil.
        zoomOpen * pow(zoomRest / zoomOpen, CGFloat(pull(e)))
    }

    static func blur(_ e: Double) -> CGFloat {
        blurOpen * (1 - CGFloat(sstep(0.10, 0.85, pull(e))))
    }
}

// MARK: - La page

struct BravoView: View {
    var reps: Int = 12
    var kilos: Int = 20
    var onStartTimer: (Int, Int) -> Void = { _, _ in }
    var onFinish: () -> Void = {}

    @State private var cine: AVPlayer?
    @State private var loop: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var onLoop = false
    @State private var visible = false
    @State private var startedAt = Date()
    @State private var handoffObserver: Any?

    @State private var repsValue = 12
    @State private var kilosValue = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let skipCine = CommandLine.arguments.contains("-bravoFreeze")

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            // Le créneau de repos vaut EXACTEMENT la hauteur de l'image à
            // l'échelle 1 : l'image touche ses bords, donc le fondu a de la
            // matière à éteindre.
            let slotRest = W * 9.0 / 16.0
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: reduceMotion)) { tl in
                let e = clock(tl.date)
                let z = BravoCine.zoom(e)
                let slot = H + (slotRest - H) * CGFloat(BravoCine.pull(e))
                let bornU = BravoCine.sstep(BravoCine.contentAt,
                                            BravoCine.contentAt + 0.70, e)
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 0) {
                        cinema(W: W, slot: slot, zoom: z, blur: BravoCine.blur(e))
                        content
                            .opacity(bornU)
                            .offset(y: (1 - bornU) * 18)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .background(Color.black)
        .onAppear(perform: start)
        .onDisappear(perform: teardown)
    }

    /// L'horloge de la partition — fonction pure du temps, l'école de
    /// ConnexionCine : aucune animation SwiftUI ne pilote la caméra.
    private func clock(_ now: Date) -> Double {
        if Self.skipCine || reduceMotion { return 99 }
        return now.timeIntervalSince(startedAt)
    }

    // MARK: Le cinéma

    /// L'ordre des modificateurs EST le sujet : l'image prend sa taille
    /// zoomée, le créneau la ROGNE, et le fondu ne s'applique qu'ensuite —
    /// donc à la résolution de l'écran, sur des bords fixes.
    private func cinema(W: CGFloat, slot: CGFloat,
                        zoom: CGFloat, blur: CGFloat) -> some View {
        let vw = W * zoom
        let vh = vw * 9.0 / 16.0
        return ZStack {
            Color.black
            ZStack {
                if let cine {
                    CinematicPlayer(player: cine).opacity(onLoop ? 0 : 1)
                }
                if let loop {
                    CinematicPlayer(player: loop).opacity(onLoop ? 1 : 0)
                }
            }
            .frame(width: vw, height: vh)
            .blur(radius: blur)
        }
        .frame(width: W, height: max(slot, 1))
        .clipped()
        .mask(edgeFade)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(false)
    }

    /// Le fondu de bords, en espace ÉCRAN. Le haut est le seul bord chargé :
    /// à l'échelle 1 un satellite touche l'arête de la source (mesuré 58/255)
    /// et pendant la chute cette arête monte à 250. Les flancs ne portent que
    /// du bokeh, le bas est mesuré à 4.
    private var edgeFade: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black, location: 0.070),
            .init(color: .black, location: 0.930),
            .init(color: .clear, location: 1.0)
        ], startPoint: .leading, endPoint: .trailing)
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.080),
                .init(color: .black, location: 0.950),
                .init(color: .clear, location: 1.0)
            ], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: Le texte, les cartes, les deux gestes

    private var content: some View {
        VStack(spacing: 0) {
            Text("Bravo")
                .font(.inter(30, .semibold))
                .tracking(-0.3)
                .foregroundStyle(WoopGradient.silverText)
                .padding(.top, 22)

            // La coupure est FORCÉE. Mesuré dans les vraies Inter : la ligne
            // longue fait 330 pt pour 353 disponibles — elle tient, mais
            // laissée libre elle se recomposerait au premier cran de Dynamic
            // Type et le bloc entier déborderait de la page.
            Text("Votre série est terminée.\nVeuillez indiquer vos répétitions et poids soulevés.")
                .font(.inter(14))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                GlassStepperCard(title: "RÉPÉTITIONS", symbol: "flame.fill",
                                 unit: "REPS", value: $repsValue,
                                 range: 1...60, perPoint: 1.0 / 13.0)
                GlassStepperCard(title: "POIDS", symbol: "dumbbell.fill",
                                 unit: "KG", value: $kilosValue,
                                 range: 0...300, perPoint: 1.0 / 9.0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            DiamondPrimaryButton(title: "Lancer le chronomètre") {
                onStartTimer(repsValue, kilosValue)
            }
            .padding(.horizontal, 20)
            // 30 pt au moins : sous le bouton, la fumée d'échappée du tap est
            // calculée jusqu'à 30 pt et l'anneau du burst monte à 38.
            .padding(.top, 26)

            // LE LIEN — ni fond ni contour : sur la nuit, un cadre clair se
            // lit comme un bug. C'est l'encre seule qui le dit.
            Button(action: onFinish) {
                Text("Terminer l'exercice")
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: La mise en route

    private func start() {
        guard cine == nil else { return }
        repsValue = reps
        kilosValue = kilos
        startedAt = .now

        guard let url = Bundle.main.url(forResource: "piece-bravo",
                                        withExtension: "mp4") else {
            visible = true
            return
        }

        // LA BOUCLE, montée tout de suite mais muette : elle doit être prête
        // et à sa première image quand le relais tombe, sinon le raccord
        // montre une image noire.
        if let lurl = Bundle.main.url(forResource: "piece-bravo-loop",
                                      withExtension: "mp4") {
            let q = AVQueuePlayer()
            q.isMuted = true
            q.automaticallyWaitsToMinimizeStalling = false
            looper = AVPlayerLooper(player: q, templateItem: AVPlayerItem(url: lurl))
            loop = q
        }

        let p = AVPlayer(playerItem: AVPlayerItem(url: url))
        // La piste audio a été retirée à l'encodage ; le muet est une
        // ceinture — une cinématique ne coupe jamais la musique de personne.
        p.isMuted = true
        // À poser AVANT toute écriture de `rate`, sinon le débit est différé.
        p.automaticallyWaitsToMinimizeStalling = false
        p.actionAtItemEnd = .pause
        cine = p

        guard !Self.skipCine, !reduceMotion else {
            visible = true
            onLoop = true
            loop?.play()
            loop?.rate = BravoCine.rateSlow
            return
        }

        // LE RELAIS : la boucle démarre et on croise vers elle. Sa première
        // image EST l'image 191 de la cinématique — mêmes pixels, le fondu ne
        // peut pas se voir.
        handoffObserver = p.addBoundaryTimeObserver(
            forTimes: [NSValue(time: CMTime(value: BravoCine.handoffFrame,
                                            timescale: 24))],
            queue: .main) { [weak p] in
                loop?.play()
                loop?.rate = BravoCine.rateSlow
                withAnimation(.easeInOut(duration: BravoCine.crossFade)) {
                    onLoop = true
                }
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + BravoCine.crossFade + 0.1) { p?.pause() }
            }

        // `play()` d'abord, le débit ENSUITE : `play()` est littéralement
        // `rate = 1.0` et écraserait le 2,5.
        p.play()
        p.rate = BravoCine.rateFast
        withAnimation(.easeOut(duration: 0.40)) { visible = true }

        // LE PALIER UNIQUE, sur le rebond : la scène décélère au même
        // instant, donc la loi « jamais un scale qui claque » est tenue par
        // la physique de l'image et non par une courbe.
        DispatchQueue.main.asyncAfter(deadline: .now() + BravoCine.fallScreen) {
            cine?.rate = BravoCine.rateSlow
        }
    }

    private func teardown() {
        if let handoffObserver { cine?.removeTimeObserver(handoffObserver) }
        handoffObserver = nil
        cine?.pause(); cine = nil
        loop?.pause(); loop = nil
        looper = nil
    }
}

// MARK: - La carte de saisie

/// Une carte de Liquid Glass, l'en-tête et son glyphe, un filet, puis les deux
/// facettes rondes et le nombre. TROIS gestes sur le même objet, et ils ne se
/// marchent pas dessus :
///   — les facettes `−` / `+`, avec la répétition au maintien ;
///   — le GLISSEMENT vertical sur le nombre : la molette ;
///   — le TAP sur le nombre : la saisie au clavier.
/// Le piège : un `DragGesture(minimumDistance: 0)` posé sur le nombre AVALE le
/// tap et rend la saisie manuelle inatteignable. La distance minimale est donc
/// non nulle, et le tap vit dans son propre reconnaisseur.
struct GlassStepperCard: View {
    let title: String
    let symbol: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    /// Unités par point de glissement — la résistance du cran.
    let perPoint: Double

    @State private var valueAtGrab: Int?
    @State private var ticks = 0
    @State private var held = false
    @State private var typing = ""
    @FocusState private var editing: Bool

    private static let shape = RoundedRectangle(cornerRadius: 26,
                                                style: .continuous)

    var body: some View {
        VStack(spacing: 0) {
            header
            // Le filet ne borde rien : il SÉPARE, à l'intérieur d'une matière
            // qui se détache déjà seule. Rentré de 18 pt pour ne jamais
            // toucher l'arête de la carte — un trait qui atteint le bord
            // redevient un contour.
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
                .padding(.horizontal, 18)
            row
        }
        .background {
            Color.clear.glassEffect(
                .regular.tint(Color.black.opacity(held ? 0.34 : 0.48)),
                in: Self.shape)
        }
        .animation(.easeOut(duration: 0.22), value: held)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.inter(11, .semibold))
                .tracking(2.4)
                .foregroundStyle(Color.inkMuted)
            Spacer(minLength: 8)
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.34))
        }
        .padding(.horizontal, 20)
        .padding(.top, 15)
        .padding(.bottom, 13)
    }

    private var row: some View {
        HStack(spacing: 0) {
            facet("minus") { step(-1) }
            Spacer(minLength: 0)
            number
            Spacer(minLength: 0)
            facet("plus") { step(1) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var number: some View {
        VStack(spacing: 3) {
            Group {
                if editing {
                    TextField("", text: $typing)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($editing)
                        .frame(width: 120)
                } else {
                    Text("\(value)")
                        .contentTransition(.numericText())
                }
            }
            .font(Font.custom("Inter-Light", size: 42).monospacedDigit())
            .tracking(0.5)
            .foregroundStyle(LinearGradient(stops: [
                .init(color: .white, location: 0.0),
                .init(color: .white.opacity(0.82), location: 0.55),
                .init(color: .white.opacity(0.50), location: 1.0)
            ], startPoint: .top, endPoint: .bottom))

            Text(unit)
                .font(.inter(10.5, .semibold))
                .tracking(3.8)
                .foregroundStyle(Color.white.opacity(held ? 0.55 : 0.32))
        }
        .frame(minWidth: 118, minHeight: 58)
        .contentShape(Rectangle())
        .onTapGesture {
            typing = "\(value)"
            editing = true
        }
        .gesture(
            // Distance minimale NON NULLE : sinon ce reconnaisseur avale le
            // tap et la saisie au clavier devient inatteignable.
            DragGesture(minimumDistance: 8)
                .onChanged { v in
                    if valueAtGrab == nil { valueAtGrab = value; held = true }
                    guard let base = valueAtGrab else { return }
                    // Vers le HAUT la valeur monte : le doigt tire la matière,
                    // comme partout ailleurs dans l'app.
                    let d = Int((-v.translation.height * perPoint).rounded())
                    set(base + d)
                }
                .onEnded { _ in valueAtGrab = nil; held = false }
        )
        .onChange(of: editing) { _, now in
            guard !now else { return }
            if let v = Int(typing.filter(\.isNumber)) { set(v) }
        }
        .toolbar {
            if editing {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { editing = false }
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.65),
                         trigger: ticks)
        .accessibilityElement()
        .accessibilityLabel(title.capitalized)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: step(1)
            case .decrement: step(-1)
            default: break
            }
        }
    }

    /// Une facette : du verre, un signe, et la répétition au maintien — le
    /// correctif durement gagné des steppers de la fiche.
    private func facet(_ glyph: String,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: glyph)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.78))
                .frame(width: 56, height: 56)
                .background {
                    Color.clear.glassEffect(
                        .regular.tint(Color.white.opacity(0.06)).interactive(),
                        in: Circle())
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }

    private func step(_ d: Int) { set(value + d) }

    private func set(_ raw: Int) {
        let next = min(max(raw, range.lowerBound), range.upperBound)
        guard next != value else { return }
        value = next
        ticks += 1
        DialChime.shared.second()
    }
}

// MARK: - Le banc

/// `-bravoLab` : la page seule, rejouable. `-bravoAuto` la relance en boucle,
/// `-bravoFreeze` l'ouvre déjà posée (captures de la mise en page).
struct BravoLab: View {
    private static let cycling = CommandLine.arguments.contains("-bravoAuto")

    @State private var run = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Rejouer, c'est REMONTER la vue : les lecteurs repartent de zéro
            // et la partition avec eux.
            BravoView().id(run)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { run += 1 } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.trailing, 14)
            .padding(.bottom, 22)
        }
        .task {
            guard Self.cycling else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(9))
                run += 1
            }
        }
    }
}

#Preview { BravoLab() }
