import SwiftUI
import AVFoundation
import UIKit

// MARK: - Les constantes de la pellicule

/// Tout ce qui concerne les fichiers eux-mêmes. Les valeurs sont MESURÉES sur
/// les masters, pas choisies : les changer sans refaire l'encodage casse le
/// raccord.
enum StoryFilm {
    /// LE DÉBIT. Les trois sources sont à 24 img/s. À 1,25 elles sortent à
    /// 30 img/s : DEUX rafraîchissements pleins à 60 Hz, QUATRE à 120 Hz. Le
    /// débit 1,0 bat en 3:2 à 60 Hz — une image sur deux tient deux fois plus
    /// longtemps que sa voisine, et sur une orbite lente ce battement se voit.
    /// Seuls 1,25 et 2,5 sont propres pour du 24 img/s.
    static let rate: Float = 1.25

    /// L'IMAGE DE RACCORD de `story_1` : la première des trois dernières
    /// secondes, 5,041667 s × 24 = 121. C'est EXACTEMENT la première image de
    /// `story_1_loop`, donc l'échange des deux couches ne peut pas se voir.
    static let handoffFrame: Int64 = 121

    /// Les ratios des fichiers ré-encodés (1170 px de large).
    /// `story_1` et `story_1_loop` partagent le leur — ils sortent du même
    /// master, et la boucle ne serait pas raccord sinon.
    static let aspectOne: CGFloat = 1170.0 / 2078.0
    static let aspectTwo: CGFloat = 1170.0 / 2190.0
    static let aspectThree: CGFloat = 1170.0 / 2576.0
}

// MARK: - La pellicule

/// Un plan de story : un master joué une fois, et — pour la story 1 — une
/// boucle ping-pong qui prend le relais à l'image de raccord.
///
/// LE POINT DE MÉTHODE : la caméra n'entre PAS ici. Le parent calcule
/// `videoSize` et la couche reçoit ces bornes-là ; l'`AVPlayerLayer` redécode
/// à la bonne taille, donc le grossissement est sans perte. Un `.scaleEffect`
/// posé après un masque fait composer SwiftUI dans un tampon à la taille non
/// zoomée puis agrandir ce tampon — un zoom rastérisé, c'est-à-dire flou.
struct StoryReel: View {
    /// Le nom de base du fichier, SANS dossier : les ressources arrivent à
    /// plat à la racine du bundle.
    let master: String
    /// Le fichier de boucle, s'il y en a un.
    var loopFile: String? = nil
    /// L'image à laquelle la boucle prend le relais (échelle de temps 24).
    var handoffFrame: Int64 = 0
    /// La taille EXACTE de la couche, AU RATIO DE LA SOURCE. Un fondu de bord
    /// n'a de sens que si l'image touche vraiment les bords de son cadre : en
    /// `resizeAspect` dans un cadre plus haut, l'image décolle de ses bords et
    /// le fondu ne dégrade plus que du noir — une arête franche en travers de
    /// l'écran.
    let videoSize: CGSize
    /// L'appui long met la story en pause : l'image aussi.
    var paused: Bool = false

    @State private var cine: AVPlayer?
    @State private var loop: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var loopReady: NSKeyValueObservation?
    @State private var handoff: Any?
    /// Le relais est tombé : c'est la boucle qu'on regarde.
    @State private var onLoop = false
    /// Les filets : la première image de chaque fichier, posée SOUS son
    /// lecteur. On ne les voit jamais — sauf pendant les une à trois images
    /// où `AVPlayerLooper` change d'item, et à l'allumage.
    @State private var masterFrame: UIImage?
    @State private var loopFrame: UIImage?

    var body: some View {
        ZStack {
            if let frame = onLoop ? loopFrame : masterFrame {
                Image(uiImage: frame).resizable()
            }
            if let cine {
                CinematicPlayer(player: cine)
                    .opacity(onLoop ? 0 : 1)
            }
            if let loop {
                CinematicPlayer(player: loop, opaqueBackground: false)
                    .opacity(onLoop ? 1 : 0)
            }
        }
        .frame(width: videoSize.width, height: videoSize.height)
        .onAppear(perform: start)
        .onDisappear(perform: teardown)
        .onChange(of: paused) { _, now in
            let live: AVPlayer? = onLoop ? loop : cine
            guard let live else { return }
            if now {
                live.pause()
            } else {
                // `play()` vaut littéralement `rate = 1.0` : il écraserait le
                // 1,25. Le débit se pose APRÈS.
                live.play()
                live.rate = StoryFilm.rate
            }
        }
    }

    // MARK: La mise en route

    private func start() {
        guard cine == nil else { return }
        guard let url = Bundle.main.url(forResource: master,
                                        withExtension: "mp4") else { return }

        // LA BOUCLE D'ABORD, montée et amorcée avant même que le master parte :
        // elle doit être à sa première image quand le relais tombe, sinon le
        // raccord montre du noir.
        if let loopFile,
           let lurl = Bundle.main.url(forResource: loopFile,
                                      withExtension: "mp4") {
            let q = AVQueuePlayer()
            q.isMuted = true
            // À poser AVANT toute écriture de `rate`, sinon le débit est
            // différé.
            q.automaticallyWaitsToMinimizeStalling = false
            looper = AVPlayerLooper(player: q,
                                    templateItem: AVPlayerItem(url: lurl))
            grabFirstFrame(url: lurl) { loopFrame = $0 }
            // LE PRÉCHARGEMENT amorce le pipeline de décodage SANS avancer
            // l'horloge : au relais, la première image est déjà prête. Il n'est
            // appelable qu'une fois l'item `.readyToPlay`, d'où l'observation.
            loopReady = q.observe(\.status, options: [.initial, .new]) { p, _ in
                guard p.status == .readyToPlay else { return }
                p.preroll(atRate: StoryFilm.rate) { _ in }
            }
            loop = q
        }

        let p = AVPlayer(playerItem: AVPlayerItem(url: url))
        // La piste audio a été retirée à l'encodage ; le muet est une ceinture.
        // Une story ne coupe la musique de personne.
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        p.actionAtItemEnd = .pause
        grabFirstFrame(url: url) { masterFrame = $0 }
        cine = p

        if loop != nil, handoffFrame > 0 {
            handoff = p.addBoundaryTimeObserver(
                forTimes: [NSValue(time: CMTime(value: handoffFrame,
                                                timescale: 24))],
                queue: .main) { [weak p] in
                    loop?.play()
                    loop?.rate = StoryFilm.rate
                    // ÉCHANGE SEC, JAMAIS UN FONDU. Un fondu croisé de 0,30 s
                    // est LE flash noir : pendant qu'il court, la couche
                    // entrante n'a pas encore produit sa première image, donc
                    // le composite se mélange à du NOIR. Les deux couches
                    // montrent la MÊME image, donc un échange en une frame est
                    // invisible par construction. Les 50 ms laissent au
                    // décodeur le temps de présenter la sienne ; se tromper
                    // d'une image ne coûte rien, elles sont identiques.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        onLoop = true
                        p?.pause()
                    }
                    // ET ON DÉMONTE LE MASTER. Un lecteur en pause reste un
                    // décodeur vivant ; une fois la boucle à l'écran, il n'a
                    // plus rien à montrer.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        if let handoff {
                            cine?.removeTimeObserver(handoff)
                            self.handoff = nil
                        }
                        cine?.replaceCurrentItem(with: nil)
                        cine = nil
                    }
                }
        }

        p.play()
        p.rate = StoryFilm.rate
    }

    /// La première image d'un fichier, à tolérance NULLE : on veut CETTE
    /// image-là, pas sa voisine — c'est le filet qui bouche le trou du
    /// bouclage, il doit porter exactement ce qu'on devait voir.
    private func grabFirstFrame(url: URL,
                                _ done: @escaping (UIImage) -> Void) {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = .zero
        gen.generateCGImagesAsynchronously(
            forTimes: [NSValue(time: .zero)]) { _, image, _, _, _ in
            guard let image else { return }
            let ui = UIImage(cgImage: image)
            DispatchQueue.main.async { done(ui) }
        }
    }

    private func teardown() {
        if let handoff { cine?.removeTimeObserver(handoff) }
        handoff = nil
        loopReady?.invalidate(); loopReady = nil
        cine?.pause(); cine?.replaceCurrentItem(with: nil); cine = nil
        loop?.pause(); loop?.removeAllItems(); loop = nil
        looper = nil
    }
}

// MARK: - Le fondu de pied

/// Le bas d'une fenêtre vidéo ne se termine JAMAIS sur une arête : l'image
/// fond dans le noir de la page sur les derniers points. Une arête franche à
/// mi-page, c'est le défaut qui a tué la carte noire de la fiche muscu — « on
/// dirait une card qui scrolle ».
struct StoryFootFade: View {
    /// La hauteur totale de la fenêtre à masquer.
    let total: CGFloat
    /// La hauteur du fondu, en pied.
    var fade: CGFloat = 96
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white,
                      location: total > 0 ? max(0, (total - fade) / total) : 1),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top, endPoint: .bottom)
    }
}

/// Un flou qui n'existe que lorsqu'il peint : en dessous de 0,2 pt, le
/// modificateur est retiré de l'arbre plutôt que de coûter une passe hors
/// écran pour rien.
struct SoftBlur: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        if radius > 0.2 { content.blur(radius: radius) } else { content }
    }
}

extension View {
    func softBlur(_ radius: CGFloat) -> some View {
        modifier(SoftBlur(radius: radius))
    }
}
