import AVFoundation
import SwiftUI
import UIKit

// MARK: - LA CHAMBRE AU TRÉSOR (coffre v2)
//
// Le plan : `tools/coffre-v2/PLAN-COFFRE-V2.md`. Les cinq lois, en une phrase
// chacune, parce que c'est d'elles que tout le fichier découle :
//
//  1. **LA PIÈCE EST L'INTERRUPTEUR, ET IL EST MOMENTANÉ.** La salle vit tant
//     que le doigt est posé, et retombe au lâcher. Un interrupteur qu'on ne
//     bascule qu'une fois est un fusible : la seule interaction de la page
//     s'épuiserait au premier usage.
//  2. **LE NOIR EST CONTINU.** Le quart haut du film de la chambre est à VRAI
//     ZÉRO (mesuré : min 0, moyenne 0,000) — la phrase se pose donc dessus
//     sans qu'aucune couture ne dise où la card commence.
//  3. **UNE SEULE LAMPE** : la barre néon de la vidéo. Aucun halo maison.
//     L'exception nommée : le croissant de la pièce, qui n'éclaire que
//     l'intérieur de sa silhouette.
//  4. **LE VERRE A DE QUOI VIVRE** — le sol est à L 152. (Et c'est pour ça
//     que le shader maison a été abandonné : cf. §6.3 bis du plan. Les pièces
//     sont les RENDUS de Kathryn.)
//  5. **LE FILM NE MENT PAS SUR LE LIEU** : on coupe au sommet et la pièce du
//     film devient la pièce de la page.

// MARK: - Les cotes

enum CoffreV2Cotes {
    /// Le patron `GrandeCardExos`, à la lettre.
    static let margeHaut: CGFloat = 10
    static let rayon: CGFloat = 55
    /// Le diamètre de la pièce — 33 % de la largeur de card (mesuré sur la
    /// maquette de Kathryn).
    static let piece: CGFloat = 132
    /// La case de la planche vaut ce multiple du diamètre (voir `recuit_pieces`).
    static let marge: CGFloat = 1.18
    /// Le centre de la pièce, en fraction de hauteur d'écran : posée SUR le
    /// sol, jamais flottante.
    static let piecY: CGFloat = 0.615
    /// La levée maximale de la card au tirage — la même bande que la home.
    static let levee: CGFloat = 140

    static var forme: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: rayon,
                               bottomLeadingRadius: rayon,
                               bottomTrailingRadius: rayon,
                               topTrailingRadius: rayon,
                               style: .continuous)
    }
}

// MARK: - La planche de sprites

/// UNE PIÈCE, UN TOUR DE MANÈGE, 72 CASES.
///
/// ⚠️ **ON NE SEEKE JAMAIS DANS UNE VIDÉO.** `DepartCine.swift:15-26` porte
/// les trois mesures qui l'ont tué : le geste réclamait **4 295 img/s**,
/// AVPlayer en sert 15 à 25, on voyait **quatre images sur 859**. Le tour de
/// Kathryn est donc découpé à la cuisson en une PLANCHE : une texture chargée
/// une fois, et le doigt ne fait plus que choisir une case. Zéro décodeur,
/// zéro seek, réponse à l'image près.
struct PlanchePiece {
    let nom: String
    let cases: Int
    let colonnes: Int

    static let or = PlanchePiece(nom: "piece-or", cases: 72, colonnes: 9)
    static let argent = PlanchePiece(nom: "piece-argent", cases: 72, colonnes: 9)

}

/// La pièce à l'écran : une case de la planche, découpée à la volée.
///
/// ⚠️ **LA PLANCHE EST CHARGÉE UNE FOIS ET RETENUE.** Un `Image(nom)` par
/// image de geste rechargerait la texture à chaque tour de doigt — c'est la
/// version paresseuse du seek qu'on vient d'éviter.
struct PieceSprite: View {
    let planche: PlanchePiece
    /// L'angle courant, en tours (0 → 1 = un tour complet). Continu : c'est le
    /// doigt qui l'écrit, et lui ne connaît pas les cases.
    let tour: Double
    var diametre: CGFloat = CoffreV2Cotes.piece

    @State private var source: CGImage?

    private var k: Int {
        Int((tour * Double(planche.cases)).rounded())
    }

    /// ⚠️ **ON DÉCOUPE LE `CGImage`, ON NE JOUE PAS AVEC LES CADRES.**
    /// Le premier jet posait la planche entière dans un cadre neuf fois trop
    /// large, la décalait d'un `offset`, puis rognait — et il affichait la
    /// **case 12 au lieu de la case 0** (mesuré : la pièce à l'écran ne
    /// correspondait à aucune case demandée). `offset` est une transformation
    /// de RENDU, pas de layout : le `frame(alignment:)` qui suit aligne des
    /// bornes qui n'ont pas bougé, et le compte n'y retombe jamais.
    ///
    /// `cropping(to:)` ne copie RIEN — c'est une fenêtre sur les mêmes octets.
    /// Et il ne monte que la case dans le GPU, au lieu des 2880 × 2560 de la
    /// planche à chaque image du geste.
    private var cellule: CGImage? {
        guard let source else { return nil }
        let c = CGFloat(planche.colonnes)
        let l = ceil(CGFloat(planche.cases) / c)
        let w = CGFloat(source.width) / c
        let h = CGFloat(source.height) / l
        let i = ((k % planche.cases) + planche.cases) % planche.cases
        return source.cropping(to: CGRect(x: CGFloat(i % planche.colonnes) * w,
                                          y: CGFloat(i / planche.colonnes) * h,
                                          width: w, height: h))
    }

    var body: some View {
        let cote = diametre * CoffreV2Cotes.marge
        Group {
            if let cellule {
                Image(decorative: cellule, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                Color.clear
            }
        }
        .frame(width: cote, height: cote)
        .task(id: planche.nom) {
            guard source == nil else { return }
            // ⚠️ CHARGÉE UNE FOIS ET RETENUE. Un `UIImage(named:)` par image de
            // geste rechargerait la texture à chaque tour de doigt — la
            // version paresseuse du seek qu'on vient d'éviter.
            source = UIImage(named: planche.nom)?.cgImage
        }
    }
}

// MARK: - Le fond de la chambre

/// LA CHAMBRE, en boucle. L'école exacte des exos et de la home :
/// `AVPlayerLooper` (jamais un seek sur `didPlayToEndTime`), looper RETENU par
/// le coordinateur, muet, et **le fond de la couche TRANSPARENT** — c'est
/// l'image de pose dessous qui doit se voir quand le décodeur rate une frame,
/// sinon le raté DEVIENT le glitch noir.
struct SalleVideo: UIViewRepresentable {
    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var retour: NSObjectProtocol?
        deinit { if let r = retour { NotificationCenter.default.removeObserver(r) } }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BoosterLoopLayerView {
        let v = BoosterLoopLayerView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.playerLayer.videoGravity = .resizeAspectFill
        v.playerLayer.backgroundColor = UIColor.clear.cgColor
        // ⚠️ `resizeAspectFill` DÉBORDE SES BORNES : un `CALayer` ne masque
        // pas ses enfants, et le `clipShape` de SwiftUI ne rattrape pas une
        // couche UIKit (défaut mesuré sur les exos : 23 px de débord de chaque
        // côté). Les deux masques, pas un seul.
        v.clipsToBounds = true
        v.playerLayer.masksToBounds = true

        guard let url = Bundle.main.url(forResource: "coffre-salle-loop",
                                        withExtension: "mp4") else { return v }
        let item = AVPlayerItem(url: url)
        let p = AVQueuePlayer(playerItem: item)
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        context.coordinator.looper = AVPlayerLooper(player: p, templateItem: item)
        context.coordinator.player = p
        v.playerLayer.player = p
        p.play()
        // Le retour d'arrière-plan : le système coupe la lecture, une page
        // d'onglet n'est pas un panneau transitoire.
        context.coordinator.retour = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { _ in p.play() }
        return v
    }

    func updateUIView(_ view: BoosterLoopLayerView, context: Context) {}

    static func dismantleUIView(_ view: BoosterLoopLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        view.playerLayer.player = nil
        coordinator.looper = nil
        coordinator.player = nil
    }
}

// MARK: - La page

struct CoffreV2Page: View {
    let coins: Int
    var onClose: () -> Void = {}

    /// LE DOIGT SUR LA PIÈCE — la salle vit tant qu'il est là (loi 1).
    @State private var allume: Double =
        CommandLine.arguments.contains("-coffre2Allume") ? 1 : 0
    /// Le tour de la pièce, en tours. Le doigt l'écrit ; il ne se remet
    /// jamais à zéro, il continue.
    @State private var tour: Double = 0
    @State private var tourPrise: Double = 0
    /// Laquelle des deux pièces est présentée. L'or = les pièces gagnées,
    /// l'argent = celles à gagner (arbitrage 25-08).
    @State private var orDevant = true
    /// LE TIRAGE de la card — la levée découvre la lune, comme la home.
    @State private var tirage: CGFloat = 0
    /// L'arrivée : le film joue, puis la page naît. `passe` coupe court.
    @State private var arrivee: Double = 0
    @State private var passe = false
    @State private var lecteur: AVPlayer?
    @State private var nee = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sansFilm = CommandLine.arguments.contains("-coffreSansFilm")
    /// `-coffre2Allume` : la salle est allumée d'emblée. Le simulateur ne sait
    /// pas TENIR un doigt, et une lampe momentanée ne se juge qu'allumée —
    /// sans ce banc, la loi 1 n'est vérifiable que sur le téléphone.
    private static let allumeFixe = CommandLine.arguments.contains("-coffre2Allume")
    /// `-coffreSkip` : le raccourci part seul à 2 s — le simulateur ne tape pas.
    private static let skipAuto = CommandLine.arguments.contains("-coffreSkip")

    /// L'encre du compte : blanche sur la nuit, presque noire sur le sol
    /// éclairé. Une seule valeur, pilotée par la lampe.
    private var encre: Color {
        Color(white: 1 - 0.90 * allume)
    }

    /// La lune du secret : elle se découvre quand la card se soulève. Le
    /// seuil et la course sont ceux de la home (`luneP`).
    private var luneP: Double {
        min(max((-Double(tirage) - 70) / 60, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height
            let W = geo.size.width
            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()

                // LA LUNE, sous la card : elle n'existe que découverte.
                if luneP > 0.01 {
                    LuneSecrete(p: luneP)
                        .frame(maxWidth: .infinity)
                        .position(x: W / 2, y: H - 52)
                }

                carte(geo)
                    .offset(y: max(tirage, 0))

                contenu(geo)
                    .offset(y: max(tirage, 0))

                if !Self.sansFilm { film(geo) }
            }
            .contentShape(Rectangle())
            .gesture(tirageGeste)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)

        .onAppear(perform: demarrer)
        .onDisappear { lecteur?.pause() }
    }

    // MARK: La card et la chambre

    @ViewBuilder
    private func carte(_ geo: GeometryProxy) -> some View {
        let H = geo.size.height
        // ⚠️ LE `Color.clear` TIENT LA TAILLE : `aspectRatio(.fill)` ne prend
        // PAS la taille proposée (défaut mesuré sur les exos — la card se
        // posait à 2,3 pt du bord au lieu de 10).
        Color.black
            .overlay(
                Color.clear
                    .overlay {
                        ZStack {
                            // L'IMAGE DE POSE, dessous : le filet du fond. Le
                            // décodage du simulateur est LOGICIEL et rate des
                            // frames ; sans elle, un raté peint tout en NOIR.
                            Image("salle-poster")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                            SalleVideo()
                        }
                        // ★ LOI 1 : LA CHAMBRE S'ALLUME SOUS LE DOIGT.
                        // Le quart haut du film est à zéro absolu, donc ce
                        // fondu n'agit QUE sur la barre et le sol — à l'œil,
                        // c'est une lampe qui monte, pas une image qui
                        // apparaît.
                        .opacity(allume)
                    }
                    .clipShape(CoffreV2Cotes.forme)
                    .padding(.top, CoffreV2Cotes.margeHaut)
            )
            .frame(height: H)
            .ignoresSafeArea()
    }

    // MARK: Le contenu

    @ViewBuilder
    private func contenu(_ geo: GeometryProxy) -> some View {
        let H = geo.size.height
        let W = geo.size.width
        ZStack(alignment: .topLeading) {
            // LA PHRASE — la grammaire de la home : Inter-SemiBold 30,
            // tracking −0,4, spacing 2, tons alternés. Trois lignes, et la
            // troisième EST l'invite (le mot invite, pas la lumière).
            // ⚠️ **LE CHEVRON ET LA PHRASE VIVENT DANS LE MÊME ESPACE**, et
            // c'est le correctif d'un défaut vu DEUX FOIS (sur la maquette,
            // puis en capture) : le chevron mangeait la première lettre.
            // La cause n'était pas la cote mais le REPÈRE — posé en
            // `.overlay(alignment: .topLeading)` sur une vue qui fuit la zone
            // sûre, il partait quand même de l'encoche (~59 pt), donc son
            // « top 63 » valait 122 à l'écran pendant que la phrase comptait
            // depuis zéro. Deux origines, aucun calcul ne pouvait tomber
            // juste. Ils sont maintenant empilés dans la MÊME colonne : l'air
            // entre eux est un `spacing`, plus une soustraction.
            VStack(alignment: .leading, spacing: 26) {
                ChipVerre(symbole: "chevron.left", label: "Fermer",
                          action: onClose)
                VStack(alignment: .leading, spacing: 2) {
                    ligne("Find what", clair: true, i: 0)
                    ligne("you worked", clair: false, i: 1)
                    ligne("for.", clair: true, i: 2)
                }
            }
            .padding(.leading, 22)
            .padding(.top, 63)

            // LA PIÈCE, posée sur le sol, avec son OMBRE DE CONTACT — c'est
            // elle, et rien d'autre, qui sépare « posé » de « collé ».
            piece(W: W, H: H)

            // LA LÉGENDE DU COMPTE : un grand chiffre, un petit mot, PAS de
            // conteneur (la pastille est morte — trois objets ronds sur le
            // même axe, c'était l'autocollant à l'échelle de la page).
            VStack(spacing: 2) {
                // ⚠️ **LE COMPTE CHANGE D'ENCRE AVEC LA LUMIÈRE.** Il vit à
                // 0,68 H, c'est-à-dire SUR le sol — noir absolu quand la salle
                // dort, **L 152** quand elle s'allume. Un blanc à 0,96 y
                // devient illisible (vu en capture), et c'est la seule chose
                // de la page qui traverse les deux régimes. Il bascule donc
                // vers une encre SOMBRE à mesure que la lampe monte : la loi
                // 3 dit qu'une seule lampe commande, et l'encre lui obéit.
                Text("\(coins)")
                    .font(.inter(34, .semibold))
                    .foregroundStyle(encre.opacity(0.96))
                    .contentTransition(.numericText())
                Text("coins earned")
                    .font(.inter(13))
                    .foregroundStyle(encre.opacity(0.52))
            }
            .frame(width: W)
            .position(x: W / 2,
                      y: H * CoffreV2Cotes.piecY
                        + CoffreV2Cotes.piece * CoffreV2Cotes.marge / 2 + 44)
            .opacity(nee ? 1 : 0)
        }
        .opacity(nee ? 1 : 0)
    }

    private func ligne(_ texte: String, clair: Bool, i: Int) -> some View {
        // La cascade de la home : `retard 0,14`, `duree 0,90` — trois lignes
        // font donc 1,18 s, et pas 0,50 (l'erreur du premier plan).
        let p = min(max((arrivee - 0.14 * Double(i)) / 0.90, 0), 1)
        return Text(texte)
            .font(.inter(30, .semibold))
            .tracking(-0.4)
            .foregroundStyle(.white.opacity(clair ? 1.0 : 0.42))
            .blur(radius: p > 0.995 ? 0 : 9 * (1 - p))
            .offset(y: 9 * (1 - p))
            .opacity(p)
    }

    @ViewBuilder
    private func piece(W: CGFloat, H: CGFloat) -> some View {
        let d = CoffreV2Cotes.piece
        let cy = H * CoffreV2Cotes.piecY
        ZStack {
            // L'OMBRE DE CONTACT — serrée et écrasée. Une flaque large ne pose
            // rien, elle salit le sol.
            Ellipse()
                .fill(Color.black.opacity(0.80 * allume))
                .frame(width: d * 1.04, height: d * 0.23)
                .blur(radius: 18)
                .position(x: W / 2, y: cy + d * 0.40)

            PieceSprite(planche: orDevant ? .or : .argent, tour: tour)
                .position(x: W / 2, y: cy)
                .gesture(pieceGeste)
        }
        .allowsHitTesting(nee)
    }

    // MARK: Les gestes

    /// LE DOIGT SUR LA PIÈCE : il allume la salle ET la fait tourner.
    private var pieceGeste: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if allume < 0.02 {
                    tourPrise = tour
                    UIImpactFeedbackGenerator(style: .soft)
                        .impactOccurred(intensity: 0.6)
                }
                // ★ LA LAMPE MONTE VITE (elle frappe), et elle retombera
                // lentement — jamais l'inverse.
                withAnimation(.easeOut(duration: 0.26)) { allume = 1 }
                // 320 pt de doigt = un tour complet.
                tour = tourPrise + Double(v.translation.width) / 320
            }
            .onEnded { _ in
                guard !Self.allumeFixe else { return }
                // ⚠️ LA RETOMBÉE EST PLUS LENTE QUE LA MONTÉE (0,62 contre
                // 0,26). Une lampe frappe et s'éteint doucement ; l'inverse
                // se lit comme un bug d'affichage.
                withAnimation(.easeInOut(duration: 0.62)) { allume = 0 }
            }
    }

    /// LE TIRAGE de la card — l'élastique en tanh, la même loi que la home,
    /// et le ressort au lâcher.
    private var tirageGeste: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { g in
                let t = g.translation.height
                let net = t < 0 ? min(t + 14, 0) : max(t - 14, 0)
                tirage = CoffreV2Cotes.levee * CGFloat(tanh(Double(net) / 190))
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    tirage = 0
                }
            }
    }

    // MARK: L'arrivée

    @ViewBuilder
    private func film(_ geo: GeometryProxy) -> some View {
        let W = geo.size.width
        let H = geo.size.height
        if let lecteur, !passe {
            // LA BANDE 16:9 — le film est PAYSAGE et ses pièces occupent la
            // bande centrale : un crop portrait les couperait en deux
            // (mesuré). On le montre donc entier, en bande.
            CinematicPlayer(player: lecteur)
                .frame(width: W, height: W * 9 / 16)
                .mask(fonduBords)
                .position(x: W / 2, y: H * 0.42)
                .transition(.opacity)
                .allowsHitTesting(false)
            // LA SURFACE DU RACCOURCI — bornée à la bande, comme la v1.
            Color.clear
                .frame(width: W, height: W * 9 / 16)
                .contentShape(Rectangle())
                .position(x: W / 2, y: H * 0.42)
                .onTapGesture { passerDevant() }
                .accessibilityLabel("Passer")
                .accessibilityAddTraits(.isButton)
        }
    }

    /// Le fondu des quatre bords, calé sur l'image : rien ne doit mourir
    /// contre une arête — une lumière qui meurt sur son cadre DESSINE son
    /// cadre.
    private var fonduBords: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black, location: 0.09),
            .init(color: .black, location: 0.91),
            .init(color: .clear, location: 1.0)
        ], startPoint: .leading, endPoint: .trailing)
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.10),
                .init(color: .black, location: 0.90),
                .init(color: .clear, location: 1.0)
            ], startPoint: .top, endPoint: .bottom)
        )
    }

    private func demarrer() {
        guard !nee else { return }
        // Sans film (ou sous Reduce Motion), la page est là tout de suite : on
        // ne fait jamais attendre devant une absence.
        guard !Self.sansFilm, !reduceMotion,
              let url = Bundle.main.url(forResource: "coffre-arrivee",
                                        withExtension: "mp4") else {
            naitre(); return
        }
        let p = AVPlayer(url: url)
        p.automaticallyWaitsToMinimizeStalling = false
        p.isMuted = true
        lecteur = p
        p.play()
        // 45 images à 24 i/s = 1,88 s : la ruée, puis la montée au sommet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.88) {
            guard !passe else { return }
            naitre()
        }
        if Self.skipAuto {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { passerDevant() }
        }
    }

    /// LE RACCOURCI. ⚠️ Il ne SAUTE pas : la home a déjà payé le saut (« de
    /// 0,6 à 1,95 en UNE image » → verdict « pas assez fluide »). On pose la
    /// scène en 0,28 s, et le lecteur s'arrête — inutile de décoder du 1080
    /// sous une couche à opacité zéro.
    private func passerDevant() {
        guard !passe else { return }
        passe = true
        lecteur?.pause()
        lecteur = nil
        naitre(duree: 0.28)
    }

    private func naitre(duree: Double = 0.55) {
        guard !nee else { return }
        withAnimation(.easeOut(duration: duree)) { nee = true; passe = true }
        // La phrase s'écrit ensuite, ligne à ligne.
        withAnimation(.linear(duration: 1.18).delay(duree * 0.4)) {
            arrivee = 1.18
        }
    }
}

// MARK: - Le banc

/// `-coffre2` : la page seule. `-coffre2Allume` la montre salle allumée (le
/// simulateur ne sait pas tenir un doigt, et une lampe ne se juge qu'allumée).
struct CoffreV2Lab: View {
    var body: some View {
        CoffreV2Page(coins: 1240)
            .preferredColorScheme(.dark)
    }
}
