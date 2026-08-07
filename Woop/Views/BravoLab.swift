import AVFoundation
import SwiftUI
import UIKit

// MARK: - La page BRAVO (`-bravoLab`)
//
// La série est finie : une pluie de pièces d'or tombe, l'une d'elles se pose
// debout, et la page se referme autour d'elle. Toute la cinématique EST la
// vidéo — plus une seule pastille de verre, plus un seul shader de scène.
//
// La partition, calée sur les TROIS ACTES MESURÉS du fichier :
//   la chute  0,00 → 2,90 s de source (le barycentre lumineux descend de
//             0,057 à 0,388 ; le delta inter-image culmine à 0,0244)
//   le rebond 2,90 → 4,00 s (le delta s'effondre à 0,0049 : le mouvement meurt)
//   la veille 4,00 → 8,04 s (delta 0,0016, MAIS la luminance moyenne monte
//             sans arrêt de 0,026 à 0,049 — la pièce s'illumine jusqu'au bout)
//
// CE QUI EST MESURÉ, ET QUI DÉCIDE DE TOUT :
//
// • LE DÉBIT N'EST PAS UN GOÛT. La source est à 24 img/s EXACTEMENT. À 120 Hz
//   cela fait 5 rafraîchissements par image ; au débit k, 5/k — entier
//   seulement pour k ∈ {1 ; 1,25 ; 1,667 ; 2,5 ; 5}. À 60 Hz, seuls 1,25 et
//   2,5 survivent. 2,5 est LE SEUL propre des deux côtés. La chute dure alors
//   1,16 s à l'écran.
// • PAS DE RAMPE DE DÉBIT. `rate` n'est pas animable : chaque écriture est une
//   discontinuité du CMTimebase, une rampe à 60 Hz fabrique 60 micro-à-coups.
//   UN SEUL palier 2,5 → 1,0, posé sur le REBOND — là où la scène décélère
//   déjà d'elle-même. La loi « jamais un scale qui claque » est tenue non par
//   une courbe mais par la physique de la scène.
// • `play()` EST LITTÉRALEMENT `rate = 1.0`. Poser le débit APRÈS, jamais avant.
// • LE GEL NE SE FAIT PAS SUR LE LECTEUR. Une vidéo en pause devient NOIRE au
//   retour de l'arrière-plan : la surface de décodage est libérée et un
//   lecteur en pause ne la redemande jamais. On croise vers une IMAGE FIXE de
//   la dernière frame pendant que le lecteur l'affiche encore — mêmes pixels,
//   le fondu ne peut pas se voir — puis on démonte le lecteur.
// • LE MASQUE VIENT APRÈS L'ÉCHELLE, ET IL EST CALÉ SUR L'ÉCRAN. La page du
//   trésor masque AVANT de zoomer : SwiftUI compose alors dans un tampon à la
//   taille non zoomée (1179 × 663 px) et n'agrandit QUE CE TAMPON — le « zoom
//   rastérisé, c'était exactement le cheap ». Sur un coffre sombre ça passe ;
//   sur une pièce dont toute l'identité est un liseré d'un pixel, non. Et un
//   fondu calé sur l'IMAGE sort du champ dès l'échelle 1,1 : il ne masque plus
//   rien. Ici le fondu vit sur le CRÉNEAU, fixe à l'écran, l'image glisse dessous.
// • LE CADRAGE EST 2,15, et c'est mesuré : c'est la seule échelle dont les
//   QUATRE bords sont propres en fin de vidéo (haut 0, bas 4, gauche 0,
//   droite 45 sur 255). À 1,93 les flancs sont à 161/210 ; à 1,63 — le pixel
//   natif — ils sont à 225/226, le pire des trois. Tout ce qui dépasse ~10 se
//   lit comme une COUTURE.
// • L'OUVERTURE EST 2,60, PAS PLUS. Au-delà, le cadrage central mord la pièce :
//   elle occupe x 0,364 → 0,642, et à l'échelle s on ne voit que 1/s de la
//   largeur. À 3,2 il ne reste que 3 pt de marge de chaque côté ; à 2,6 elle
//   respire. La source est en 1080p — un vrai gros plan demanderait un master 4K.
//
// `-bravoAuto` rejoue en boucle, `-bravoFreeze` ouvre la page déjà posée.
enum BravoCine {
    /// LES DEUX SEULS DÉBITS PROPRES. À 24 img/s de source, un débit k donne
    /// 60/24/k rafraîchissements par image à 60 Hz et 120/24/k à 120 : entier
    /// des deux côtés uniquement pour k = 1,25 et k = 2,5. Le débit 1,0
    /// lui-même bat en 3:2 à 60 Hz — il n'est donc PAS le repos, c'est 1,25.
    static let rateFast: Float = 2.5
    static let rateSlow: Float = 1.25
    /// La chute, en temps SOURCE (mesurée).
    static let fallSrc: Double = 2.90
    /// Où l'on gèle : l'image 168, à 7,00 s de source. Pas la dernière (192) —
    /// la luminance moyenne y vaut déjà 0,0447 contre 0,0494 à la fin, soit
    /// 90 % de la montée, et les 1,04 s gagnées valent mieux que ces 10 %.
    /// On ne calcule jamais depuis `duration` : sur le fichier d'origine la
    /// piste audio était 0,038 s plus longue que la vidéo.
    static let endFrame: Int64 = 168
    static var endSrc: Double { Double(endFrame) / 24.0 }

    /// La chute, à l'écran : 1,16 s.
    static var fallScreen: Double { fallSrc / Double(rateFast) }
    /// La queue, à l'écran : 3,28 s.
    static var tailScreen: Double { (endSrc - fallSrc) / Double(rateSlow) }
    /// Le recul du cadrage : il dure le rebond, pas plus.
    static let settleFor: Double = 1.10
    /// Le gel — 4,44 s après la première image.
    static var freezeAt: Double { fallScreen + tailScreen }
    /// Le contenu naît DÈS QUE LE CADRAGE EST POSÉ, pas à la fin de la vidéo.
    /// Le premier jet le faisait naître une seconde avant le gel : entre la
    /// pose (2,26 s) et lui, la page restait TROIS SECONDES sur une pièce
    /// immobile et un écran vide — filmé, mesuré, refusé.
    static let contentAt: Double = 2.60
    /// Le croisement vers l'image fixe.
    static let crossFade: Double = 0.25

    /// Les deux cadrages.
    static let zoomOpen: CGFloat = 2.60
    static let zoomRest: CGFloat = 2.15
    /// La PLACE au repos — 48,5 % de la page. Ce n'est pas la taille de
    /// l'image (qui vaut 2,15, soit 56 %) : le créneau est un nombre de mise
    /// en page, l'échelle un nombre de cadrage. Les découpler est ce qui
    /// permet d'avoir les quatre bords propres ET le texte entier dessous.
    static let slotRest: CGFloat = 0.485
    /// Ce que le créneau rogne en haut de l'image, en fraction de sa hauteur :
    /// pendant la chute, le bord haut de la source est à 250/255 — la pièce
    /// entre EN ÉTANT TRANCHÉE. On coupe cette arête hors du champ.
    static let topBite: CGFloat = 0.065

    static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }
}

// MARK: - La page

struct BravoView: View {
    var seriesLabel: String = "Série 1"
    var reps: Int = 12
    var kilos: Int = 20
    /// Le primaire : on part sur le repos chronométré.
    var onStartTimer: (Int, Int) -> Void = { _, _ in }
    /// Le lien : on rend la main à la fiche d'exercice.
    var onFinish: () -> Void = {}

    @State private var player: AVPlayer?
    /// La première image est arrivée — le fondu d'entrée n'est PAS un pari.
    @State private var visible = false
    /// Le cadrage a reculé dans son créneau.
    @State private var settled = false
    /// Le texte, les nombres et les boutons sont nés.
    @State private var born = false
    /// L'image fixe de la dernière frame, et le croisement vers elle.
    @State private var stillFrame: UIImage?
    @State private var frozen = false
    @State private var endObserver: Any?

    @State private var repsValue = 12
    @State private var kilosValue = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let skipCine = CommandLine.arguments.contains("-bravoFreeze")

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let slot = (settled || reduceMotion) ? H * BravoCine.slotRest : H
            let zoom = (settled || reduceMotion) ? BravoCine.zoomRest
                                                 : BravoCine.zoomOpen
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    cinema(W: W, slot: slot, zoom: zoom)
                    content
                        .opacity(born ? 1 : 0)
                        .offset(y: born ? 0 : 16)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear(perform: start)
        .onDisappear(perform: teardown)
    }

    // MARK: Le cinéma

    /// L'ordre des modificateurs EST le sujet : l'image prend sa taille
    /// zoomée, le créneau la ROGNE, et c'est seulement là que le fondu
    /// s'applique — donc à la résolution de l'écran, sur des bords fixes.
    private func cinema(W: CGFloat, slot: CGFloat, zoom: CGFloat) -> some View {
        let vw = W * zoom
        let vh = vw * 9.0 / 16.0
        return ZStack(alignment: .top) {
            Color.black
            ZStack {
                if let player {
                    CinematicPlayer(player: player)
                        .opacity(frozen ? 0 : 1)
                }
                // L'image fixe est posée à la MÊME taille et sous le MÊME
                // masque : le croisement porte les mêmes pixels, il est
                // invisible par construction.
                if let stillFrame {
                    Image(uiImage: stillFrame)
                        .resizable()
                        .opacity(frozen ? 1 : 0)
                }
            }
            .frame(width: vw, height: vh)
            // La morsure du haut : l'arête où la pièce entre tranchée à
            // 250/255 est poussée hors du créneau.
            .offset(y: -vh * BravoCine.topBite)
        }
        .frame(width: W, height: slot, alignment: .top)
        .clipped()
        .mask(edgeFade)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(false)
    }

    /// Le fondu de bords, en espace ÉCRAN. Les flancs portent du bokeh flou
    /// (mesuré à 45/255 au pire, au cadrage 2,15) : 7 % suffisent à l'éteindre
    /// sans qu'on voie la coupe. Le haut et le bas sont mesurés à 0 et 4 en fin
    /// de vidéo — leur fondu ne sert que pendant la chute.
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
                .init(color: .black, location: 0.045),
                .init(color: .black, location: 0.945),
                .init(color: .clear, location: 1.0)
            ], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: Le texte, les nombres, les deux gestes

    private var content: some View {
        VStack(spacing: 0) {
            Text("Bravo")
                .font(.inter(30, .semibold))
                .tracking(-0.3)
                .foregroundStyle(WoopGradient.silverText)
                .padding(.top, 26)

            // La coupure est FORCÉE. Mesuré dans les vraies Inter : la
            // deuxième ligne fait 330 pt pour 353 disponibles — elle tient,
            // mais laissée libre elle se recomposerait au premier cran de
            // Dynamic Type et le bloc entier déborderait de la page.
            Text("Votre série est terminée.\nVeuillez indiquer vos répétitions et poids soulevés.")
                .font(.inter(14))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)
                .padding(.horizontal, 20)

            HStack(spacing: 14) {
                GlassDialNumber(value: $kilosValue, unit: "KG",
                                range: 0...300, perPoint: 1.0 / 9.0)
                GlassDialNumber(value: $repsValue, unit: "REPS",
                                range: 1...60, perPoint: 1.0 / 13.0)
            }
            .padding(.top, 30)

            DiamondPrimaryButton(title: "Lancer le chronomètre") {
                onStartTimer(repsValue, kilosValue)
            }
            .padding(.horizontal, 20)
            // 30 pt au moins : sous le bouton, la fumée d'échappée du tap est
            // calculée jusqu'à 30 pt et l'anneau du burst va à 38.
            .padding(.top, 32)

            // LE LIEN — pas de fond, pas de contour : sur la nuit, un cadre
            // clair se lit comme un bug. C'est l'encre seule qui le dit.
            Button(action: onFinish) {
                Text("Terminer l'exercice")
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: La mise en route

    private func start() {
        guard player == nil else { return }
        repsValue = reps
        kilosValue = kilos

        guard let url = Bundle.main.url(forResource: "piece-bravo",
                                        withExtension: "mp4") else {
            // Sans le fichier, la page est là tout de suite : on ne bloque
            // jamais l'utilisatrice sur une absence.
            settled = true; visible = true; born = true
            return
        }

        // L'image fixe de la fin, préparée tout de suite : elle doit être
        // prête bien avant le gel (six secondes plus tard).
        prepareStill(url: url)

        guard !Self.skipCine, !reduceMotion else {
            settled = true; visible = true; born = true
            let p = AVPlayer(url: url)
            p.isMuted = true
            player = p
            p.seek(to: CMTime(value: BravoCine.endFrame, timescale: 24),
                   toleranceBefore: .zero, toleranceAfter: .zero)
            return
        }

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        // La piste audio a été retirée à l'encodage ; le muet est une
        // ceinture — une cinématique ne coupe jamais la musique de personne.
        p.isMuted = true
        // À poser AVANT toute écriture de `rate`, sinon le débit est différé.
        p.automaticallyWaitsToMinimizeStalling = false
        p.actionAtItemEnd = .pause
        player = p

        // LE GEL : un observateur de frontière sur la dernière image exacte.
        // On ne laisse jamais `AVPlayerItemDidPlayToEndTime` arriver seul — à
        // la fin d'item la sortie vidéo peut se démonter et la couche virer au
        // noir.
        endObserver = p.addBoundaryTimeObserver(
            forTimes: [NSValue(time: CMTime(value: BravoCine.endFrame,
                                             timescale: 24))],
            queue: .main) { [weak p] in
                p?.pause()
                withAnimation(.easeInOut(duration: BravoCine.crossFade)) {
                    frozen = true
                }
            }

        // `play()` d'abord, le débit ENSUITE : `play()` est littéralement
        // `rate = 1.0` et écraserait le 2,5.
        p.play()
        p.rate = BravoCine.rateFast

        withAnimation(.easeOut(duration: 0.45)) { visible = true }

        // LE PALIER UNIQUE, posé sur le rebond — là où la scène décélère
        // d'elle-même. Le recul du cadrage part au même instant : un seul
        // geste, pas deux.
        DispatchQueue.main.asyncAfter(deadline: .now() + BravoCine.fallScreen) {
            guard let p = player else { return }
            // LE PALIER UNIQUE : 2,5 → 1,25, jamais 1,0 (qui bat en 3:2 à
            // 60 Hz). Il tombe sur le REBOND, là où la scène décélère déjà
            // d'elle-même : la loi « jamais un scale qui claque » est tenue
            // par la physique de l'image, pas par une courbe.
            p.rate = BravoCine.rateSlow
            withAnimation(.easeInOut(duration: BravoCine.settleFor)) {
                settled = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + BravoCine.contentAt) {
            withAnimation(.easeOut(duration: 0.65)) { born = true }
        }
    }

    /// La dernière image, extraite une fois. Tolérances à zéro : on veut
    /// CETTE image-là, pas sa voisine — sinon le croisement fait un saut.
    private func prepareStill(url: URL) {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = .zero
        let t = CMTime(value: BravoCine.endFrame, timescale: 24)
        gen.generateCGImagesAsynchronously(forTimes: [NSValue(time: t)]) {
            _, image, _, _, _ in
            guard let image else { return }
            let ui = UIImage(cgImage: image)
            DispatchQueue.main.async { stillFrame = ui }
        }
    }

    private func teardown() {
        if let endObserver { player?.removeTimeObserver(endObserver) }
        endObserver = nil
        player?.pause()
        player = nil
    }
}

// MARK: - La molette de verre

/// Un nombre dans une capsule de Liquid Glass, qu'on règle EN GLISSANT
/// DESSUS. Pas de −/+, pas de puits, pas de contour : la capsule se détache
/// par sa matière, jamais par un trait. Chaque unité franchie est un cran —
/// le tic du cadran et une vibration souple, la même que partout ailleurs.
struct GlassDialNumber: View {
    @Binding var value: Int
    let unit: String
    let range: ClosedRange<Int>
    /// Unités par point de glissement — la résistance du cran.
    let perPoint: Double

    @State private var valueAtGrab: Int?
    @State private var ticks = 0
    @State private var held = false

    private static let shape = Capsule(style: .continuous)

    var body: some View {
        VStack(spacing: 5) {
            Text("\(value)")
                .font(Font.custom("Inter-Light", size: 42).monospacedDigit())
                .tracking(0.5)
                .foregroundStyle(LinearGradient(stops: [
                    .init(color: .white, location: 0.0),
                    .init(color: .white.opacity(0.82), location: 0.55),
                    .init(color: .white.opacity(0.50), location: 1.0)
                ], startPoint: .top, endPoint: .bottom))
                .contentTransition(.numericText())
            Text(unit)
                .font(.inter(10.5, .semibold))
                .tracking(3.8)
                .foregroundStyle(Color.white.opacity(held ? 0.55 : 0.32))
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 14)
        .frame(minWidth: 150)
        .background {
            // La matière de la maison — le verre fumé des chips du header et
            // de la carte Série. Elle se réveille sous le doigt.
            Color.clear.glassEffect(
                .regular.tint(Color.black.opacity(held ? 0.30 : 0.45)),
                in: Self.shape)
        }
        .contentShape(Self.shape)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if valueAtGrab == nil {
                        valueAtGrab = value
                        withAnimation(.easeOut(duration: 0.18)) { held = true }
                    }
                    guard let base = valueAtGrab else { return }
                    // Vers le HAUT la valeur monte : le doigt tire la matière,
                    // comme dans tout le reste de l'app.
                    let delta = Int((-v.translation.height * perPoint).rounded())
                    let next = min(max(base + delta, range.lowerBound),
                                   range.upperBound)
                    guard next != value else { return }
                    value = next
                    ticks += 1
                    DialChime.shared.second()
                }
                .onEnded { _ in
                    valueAtGrab = nil
                    withAnimation(.easeOut(duration: 0.25)) { held = false }
                }
        )
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.65),
                         trigger: ticks)
        .accessibilityElement()
        .accessibilityLabel(unit == "KG" ? "Poids" : "Répétitions")
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, range.upperBound)
            case .decrement: value = max(value - 1, range.lowerBound)
            default: break
            }
        }
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
            // Rejouer, c'est REMONTER la vue : le lecteur repart de zéro et la
            // partition avec lui (le procédé du banc du trésor).
            BravoView()
                .id(run)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { run += 1 } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.trailing, 16)
            .padding(.bottom, 26)
        }
        .task {
            guard Self.cycling else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7.5))
                run += 1
            }
        }
    }
}

#Preview { BravoLab() }
