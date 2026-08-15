import SwiftUI
import AVFoundation

// MARK: - L'ÉTAT PARTAGÉ DU SACRE
//
// LE PIÈGE QUI IMPOSE CE FICHIER : le contenu d'un onglet est construit
// PARESSEUSEMENT. Tant que personne n'a ouvert le profil, `ProfilLuneView`
// n'existe pas — donc elle n'écoute aucune `NotificationCenter`, et le
// premier « Ouvrir un Booster » ne faisait RIEN. Une notification est un
// cri dans une pièce vide : il faut que quelqu'un y soit déjà.
//
// L'état, lui, se lit à la racine. Le Manège se monte AU-DESSUS du
// TabView et de la barre bijou (`WoopApp.mainBody`) : il n'a plus besoin
// que qui que ce soit ait été instancié avant lui, et le flow reste celui
// d'où on vient — on ouvre un booster depuis la home SANS passer par
// l'onglet profil.
//
// Le parcours complet est écrit dans `tools/sacre/PARCOURS-BOOSTER.md`,
// et ce que le serveur doit lui servir dans `SUPABASE-PIPELINE.md`.

/// Le chef d'orchestre du parcours booster — une seule instance, lue à la
/// racine de l'app.
@Observable
final class SacreEtat {
    static let shared = SacreEtat()
    private init() {}

    /// La pop-up de proposition (« Un booster t'attend »).
    var popupOuverte = false
    /// Le Manège — le carrousel des sachets, monté à la racine.
    var manegeOuvert = false
    /// La rareté que la page profil doit ACCUEILLIR (l'envol accompli).
    /// Elle est posée APRÈS la bascule d'onglet : la page doit exister
    /// pour l'entendre — et son `onAppear` la relit en filet de sécurité.
    var arriveeDemandee: String?

    /// Le compteur des sachets non ouverts — la pill du profil et le
    /// nombre de tours du manège.
    ///
    /// MAQUETTE tant que Supabase n'est pas là : c'est `user_boosters`
    /// (les lignes à `opened_at is null`) qui donnera ce nombre, et c'est
    /// la seule façon qu'il survive à la fermeture de l'app.
    var boostersEnAttente = 1

    /// La proposition (aujourd'hui le bouton d'essai de la home ; demain
    /// la fin de séance).
    func proposer() {
        guard !manegeOuvert else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            popupOuverte = true
        }
    }

    /// L'ouverture du Manège — depuis la pop-up comme depuis la pill du
    /// profil. On reste dans le flow où on est.
    func ouvrirManege() {
        withAnimation(.easeOut(duration: 0.22)) { popupOuverte = false }
        withAnimation(.easeInOut(duration: 0.38).delay(0.06)) {
            manegeOuvert = true
        }
    }

    /// Le chevron des deux écrans du Sacre : on rend la main à la home.
    func fermerManege() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.32)) { manegeOuvert = false }
    }
}

// MARK: - La boucle vidéo du header

/// L'hôte : un `AVPlayerLayer` nu — `VideoPlayer` (AVKit) apporterait ses
/// commandes et son fond, dont une pop-up n'a que faire.
final class BoosterLoopLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// Les trois sachets en éventail, fumée qui monte. L'école des démons :
/// `AVPlayerLooper` (jamais un `seek(.zero)` sur `didPlayToEndTime` — il
/// laisse une image noire au raccord), le looper RETENU par le
/// coordinateur, et le muet obligatoire.
///
/// LA COUTURE DU FICHIER, elle, a été réglée AVANT l'app : la source
/// bouclait mal (écart 4,4/255 entre sa dernière et sa première image).
/// `Woop/Media/booster-loop.mp4` est recuit avec un fondu croisé de 0,5 s
/// de la queue sur la tête — mesuré à 2,03, quand deux images
/// consécutives ordinaires en valent déjà 1,40. La couture est au niveau
/// du mouvement naturel : il n'y en a plus.
struct BoosterLoopVideo: UIViewRepresentable {
    final class Coordinator {
        var player: AVQueuePlayer?
        // Relâché, la boucle s'arrête au premier tour et le header se fige.
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BoosterLoopLayerView {
        let v = BoosterLoopLayerView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        // Le cadre du header est plus large que la vidéo (3:2) : elle
        // remplit et c'est le haut/bas qui se recadre — de la fumée et du
        // reflet, jamais les sachets.
        v.playerLayer.videoGravity = .resizeAspectFill
        guard let url = Bundle.main.url(forResource: "booster-loop",
                                        withExtension: "mp4") else {
            // Sans le fichier, le panneau reste le panneau : son verre et
            // sa nuit. On ne pose jamais un rectangle noir « en attendant ».
            return v
        }
        let p = AVQueuePlayer()
        p.isMuted = true
        // Rien à mettre en tampon : le fichier est dans le paquet.
        p.automaticallyWaitsToMinimizeStalling = false
        context.coordinator.looper = AVPlayerLooper(
            player: p, templateItem: AVPlayerItem(url: url))
        context.coordinator.player = p
        v.playerLayer.player = p
        p.play()
        return v
    }

    func updateUIView(_ v: BoosterLoopLayerView, context: Context) {}

    static func dismantleUIView(_ v: BoosterLoopLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }
}

// MARK: - LA POP-UP BOOSTER

/// La proposition, AU MILIEU DE L'ÉCRAN. C'est la grammaire du panneau
/// « Recommencer » de la fiche d'exercice — même verre, même nuit qui
/// fond, même primaire, même échappée en encre nue — mais les QUATRE
/// coins sont arrondis : ce panneau-ci ne touche aucun bord, et un cadre
/// fantôme au ras d'un écran est une faute déjà payée.
struct BoosterPopup: View {
    var onOuvrir: () -> Void = {}
    var onFermer: () -> Void = {}

    @State private var born = false

    private static let forme = RoundedRectangle(cornerRadius: 34,
                                                style: .continuous)

    var body: some View {
        ZStack {
            // Le voile : assez pour détacher le panneau, assez peu pour
            // que le verre ait encore une page à échantillonner.
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onFermer() }

            GeometryReader { g in
                let W = min(g.size.width - 44, 352)
                panneau(W: W, headerH: W * 0.60)
                    .frame(width: W)
                    .scaleEffect(born ? 1 : 0.92)
                    .opacity(born ? 1 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                born = true
            }
        }
    }

    private func panneau(W: CGFloat, headerH: CGFloat) -> some View {
        VStack(spacing: 0) {
            // La réserve du header : le texte remonte de 30 pt DANS la
            // fumée — la vidéo et le titre se recouvrent au lieu de se
            // succéder, il n'y a jamais de ligne d'horizon entre eux.
            Color.clear.frame(height: headerH - 30)

            Text("Un booster t'attend")
                .font(.inter(20, .semibold))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 30)
            Text("Une carte du set Lune dort à l'intérieur.")
                .font(.inter(12.5))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 7)
                .padding(.horizontal, 30)

            DiamondPrimaryButton(title: "Ouvrir un Booster",
                                 smokeWarmth: 0.55) {
                onOuvrir()
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)

            // L'échappée en ENCRE SEULE — sur la nuit, un cadre clair se
            // lit comme un bug (l'école du footer de BRAVO).
            Button { onFermer() } label: {
                Text("Plus tard")
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .padding(.bottom, 16)
        }
        // LE VERRE EST LE VRAI (il échantillonne la page vivante), et
        // par-dessus LA NUIT QUI FOND : quasi opaque en haut — elle épouse
        // le noir de la vidéo, la couture verre/vidéo jurait (verdict) —,
        // transparente en pied : le diamant vit sur l'air.
        .background {
            ZStack {
                // Jamais `.interactive()` sur un grand verre : il vole les
                // gestes de ce qui vit dessus.
                Color.clear.glassEffect(
                    .regular.tint(Color.black.opacity(0.30)),
                    in: Self.forme)
                Self.forme
                    .fill(LinearGradient(stops: [
                        .init(color: .black.opacity(0.95), location: 0),
                        .init(color: .black.opacity(0.88), location: 0.38),
                        .init(color: .black.opacity(0.25), location: 1)
                    ], startPoint: .top, endPoint: .bottom))
                    .allowsHitTesting(false)
            }
        }
        // La vidéo file bord à bord : c'est le panneau qui porte les coins.
        // `plusLighter` parce que le noir d'un H.264 n'est pas pur — en
        // composition normale, un rectangle gris se devine sur le verre.
        .overlay(alignment: .top) {
            BoosterLoopVideo()
                .frame(width: W, height: headerH)
                .mask(LinearGradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: 0.50),
                    .init(color: .white.opacity(0.35), location: 0.80),
                    .init(color: .clear, location: 1.0)
                ], startPoint: .top, endPoint: .bottom))
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .clipShape(Self.forme)
        // Le fil du bord — seulement là où la feuille se détache du fond.
        .overlay {
            Self.forme
                .strokeBorder(LinearGradient(stops: [
                    .init(color: Color.white.opacity(0.16), location: 0),
                    .init(color: Color.white.opacity(0.03), location: 0.18),
                    .init(color: .clear, location: 0.45)
                ], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Le sachet en vignette

/// UNE IMAGE DU PAQUET, PAS D'UN CATALOGUE. Les PNG de `Woop/Media` sont
/// des ressources nues : `Image("booster-pill")` cherche dans les
/// catalogues d'assets et ne trouve RIEN — silencieusement (le bouton
/// d'essai est resté un carré vide une capture durant). Le chargement
/// passe donc par le bundle, comme le dos des cartes.
///
/// Et c'est bien une image, pas une `SCNView` : une scène SceneKit dans
/// une capsule coûterait le prix d'une page pour vingt pixels.
struct SachetVignette: View {
    var largeur: CGFloat
    var hauteur: CGFloat

    private static let image: UIImage? = Bundle.main
        .path(forResource: "booster-pill", ofType: "png")
        .flatMap { UIImage(contentsOfFile: $0) }

    var body: some View {
        if let ui = Self.image {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .frame(width: largeur, height: hauteur)
                // Le sachet vit sur du noir : `plusLighter` efface son
                // fond et ne laisse que ses néons — pas de découpe alpha
                // à entretenir.
                .blendMode(.plusLighter)
        }
    }
}

// MARK: - La pill Booster (le header du profil)

/// La sœur de la pastille des pièces, à côté d'elle : le sachet en 3D (une
/// image du rendu, pas une SCNView — une scène SceneKit dans une capsule
/// coûterait le prix d'une page pour vingt pixels) et le nombre de
/// boosters qui attendent. Un clic ouvre le Manège.
///
/// C'est la RÉCUPÉRATION du parcours : dire « Plus tard » à la pop-up ne
/// perd jamais un sachet, et cette pill est la porte pour y revenir.
struct PillBooster: View {
    var nombre: Int
    var action: () -> Void

    @State private var kick: CGFloat = 0

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.42)) {
                kick = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.30)) { kick = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { action() }
        } label: {
            HStack(spacing: 7) {
                SachetVignette(largeur: 15, hauteur: 26)
                    .frame(width: 20, height: 24)
                    .rotationEffect(.degrees(Double(kick) * -10))
                Text("\(nombre)")
                    .font(.inter(15, .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassEffect(.regular.tint(Color.black.opacity(0.5))
                             .interactive(),
                         in: .capsule)
            .scaleEffect(1 + 0.10 * kick)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(nombre) booster — ouvrir le manège")
    }
}
