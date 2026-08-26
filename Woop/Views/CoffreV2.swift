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

    /// ⚠️ **LA SALLE EST ALLUMÉE PAR DÉFAUT** (verdict Kathryn, 25-08 : « par
    /// défaut le background est allumé, là l'écran est noir »). Le plan avait
    /// tranché l'inverse — une chambre éteinte qu'on allume au doigt — et la
    /// page livrée lui a donné tort en trois secondes : la première image
    /// était un écran noir. On garde l'idée de l'interrupteur, mais **elle ne
    /// commande plus l'existence de la lumière, seulement son ÉCLAT** : le
    /// doigt fait monter la lampe d'un cran, et elle redescend au lâcher.
    @State private var eclat: Double = 0

    /// Le tour de la pièce présentée, en tours (1 = un tour complet). Continu :
    /// c'est le doigt qui l'écrit, et lui ne connaît pas les cases.
    @State private var tour: Double = 0
    @State private var tourPrise: Double = 0

    /// LE MANÈGE — deux pièces, un cran chacune. `page` est continue pendant
    /// le geste : c'est elle qui porte le flou et le voyage.
    @State private var page: Double = 0
    @State private var pagePrise: Double = 0
    /// L'axe du geste, verrouillé au premier mouvement franc. ⚠️ Sans lui, un
    /// glissement de manège nourrit AUSSI le tirage de la card : le moindre
    /// soupçon de vertical fait sauter la page en plein voyage.
    @State private var axeVertical: Bool?

    /// LE TIRAGE de la card — la levée découvre la lune, comme la home.
    @State private var tirage: CGFloat = 0

    // ── L'ARRIVÉE
    /// L'avancement de la phrase (en secondes de sa propre partition).
    @State private var arrivee: Double = 0
    /// LE RACCORD : 1 = la pièce est encore à la taille et à la place du
    /// film ; 0 = elle est posée. C'est UN SEUL curseur, et c'est lui qui
    /// fait la transition — pas un fondu croisé entre deux objets.
    @State private var raccord: Double = 1
    @State private var lecteur: AVPlayer?
    @State private var filmVisible = false
    @State private var nee = false
    @State private var passe = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sansFilm = CommandLine.arguments.contains("-coffreSansFilm")
    /// `-coffreSkip` : le raccourci part seul à 1,2 s — le simulateur ne tape
    /// pas, et un raccourci qui n'est jamais filmé n'est pas vérifié.
    private static let skipAuto = CommandLine.arguments.contains("-coffreSkip")
    /// `-coffreArgent` ouvre sur la pièce noire (capture du second cran).
    private static let argentDabord = CommandLine.arguments.contains("-coffreArgent")
    /// `-coffrePage <v>` FIGE le manège à mi-voyage. Le simulateur ne sait pas
    /// glisser : sans ce banc, l'instant où LES DEUX pièces sont à l'écran —
    /// c'est-à-dire tout le sujet du geste — n'est jamais vérifiable.
    ///
    /// ⚠️ **UN ARGUMENT DE LANCEMENT N'ARRIVE PAS TOUJOURS EN `NSNumber`.**
    /// Le dépôt tient la règle inverse (« les arguments arrivent en NSNumber :
    /// `as? Double` ÉCHOUE quand la valeur s'écrit sans décimale ») et elle
    /// est INCOMPLÈTE : mesuré ici au `print`, `-coffrePage 0.35` rend
    /// `Optional(0.35)` mais le `as? NSNumber` retourne **nil** — c'est une
    /// `String`. Le banc s'appliquait donc jamais, et j'ai cru pendant trois
    /// captures que le manège ne marchait pas alors qu'il n'était jamais figé.
    /// **On lit les deux formes, toujours.**
    private static let pageFigee: Double? = nombre("coffrePage")

    static func nombre(_ cle: String) -> Double? {
        let o = UserDefaults.standard.object(forKey: cle)
        if let n = o as? NSNumber { return n.doubleValue }
        if let t = o as? String { return Double(t) }
        return nil
    }

    // MARK: Les grandeurs dérivées

    /// La lune du secret : elle se découvre quand la card se soulève. Le seuil
    /// et la course sont ceux de la home (`luneP`).
    private var luneP: Double {
        min(max((-Double(tirage) - 70) / 60, 0), 1)
    }

    /// L'encre du compte. Il vit SUR le sol (L 152 allumé) : un blanc y est
    /// illisible. Elle suit donc la lampe, comme tout le reste de la page.
    private var encre: Color { Color(white: 0.10) }

    /// ⚠️ **LA LOI COVER-FLOW DU PLAN NE S'APPLIQUE PAS ICI.** `|sin(2πu)|`
    /// est NUL au milieu du voyage (la source le dit : « nette face caméra au
    /// centre ») — juste pour un manège où l'objet se PRÉSENTE à mi-chemin
    /// avant de repartir. Ici il n'y a que deux crans et le milieu n'est pas
    /// une présentation, c'est le creux du geste : la mise au point suit donc
    /// la DISTANCE au cran, et rien d'autre.

    /// LES DEUX PIÈCES, dans l'ordre du manège : l'or (les pièces gagnées)
    /// puis la noire (celles à gagner).
    private static let manege: [PlanchePiece] = [.or, .argent]

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

                carte(geo).offset(y: max(tirage, 0))
                contenu(geo).offset(y: max(tirage, 0))
                if filmVisible { film(geo) }
            }
            .contentShape(Rectangle())
            .gesture(gestePage)
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
        Color.black
            .overlay(
                // ⚠️ LE `Color.clear` TIENT LA TAILLE : `aspectRatio(.fill)` ne
                // prend PAS la taille proposée (défaut mesuré sur les exos —
                // la card se posait à 2,3 pt du bord au lieu de 10).
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
                        // LA LAMPE MONTE D'UN CRAN SOUS LE DOIGT. Le quart
                        // haut du film étant à zéro absolu, ce gain n'agit
                        // que sur la barre et le sol : c'est une lampe qu'on
                        // pousse, pas une image qu'on éclaircit.
                        .brightness(0.10 * eclat)
                        .saturation(1 + 0.14 * eclat)
                    }
                    .clipShape(CoffreV2Cotes.forme)
                    .padding(.top, CoffreV2Cotes.margeHaut)
            )
            .frame(height: geo.size.height)
            .ignoresSafeArea()
    }

    // MARK: Le contenu

    @ViewBuilder
    private func contenu(_ geo: GeometryProxy) -> some View {
        let H = geo.size.height
        let W = geo.size.width
        ZStack(alignment: .topLeading) {
            // ⚠️ **LE CHEVRON ET LA PHRASE VIVENT DANS LE MÊME ESPACE**, et
            // c'est le correctif d'un défaut vu DEUX FOIS (maquette, puis
            // capture) : le chevron mangeait la première lettre. La cause
            // n'était pas la cote mais le REPÈRE — posé en overlay sur une vue
            // qui fuit la zone sûre, il partait quand même de l'encoche.
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
            .opacity(nee ? 1 : 0)

            piece(W: W, H: H)

            // LA LÉGENDE DU COMPTE : un grand chiffre, un petit mot, PAS de
            // conteneur (la pastille est morte — trois objets ronds sur le
            // même axe, c'était l'autocollant à l'échelle de la page).
            VStack(spacing: 2) {
                Text("\(coins)")
                    .font(.inter(34, .semibold))
                    .foregroundStyle(encre.opacity(0.92))
                    .contentTransition(.numericText())
                Text("coins earned")
                    .font(.inter(13))
                    .foregroundStyle(encre.opacity(0.52))
            }
            .frame(width: W)
            .position(x: W / 2,
                      y: H * CoffreV2Cotes.piecY
                        + CoffreV2Cotes.piece * CoffreV2Cotes.marge / 2 + 44)
            .opacity(nee ? (1 - raccord) : 0)
        }
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

    // MARK: La pièce et son manège

    /// ⚠️ **LE RACCORD EST UNE POSE, PAS UN FONDU.** Au sommet du film la
    /// pièce emplit la bande ; la pièce de la page NAÎT à cette taille et à
    /// cette place, puis se pose. On ne voit donc pas deux objets se
    /// remplacer : on voit le même, qui atterrit. Les cotes viennent de la
    /// mesure du film (image 70 : bbox 0,94 de la hauteur de bande, centre à
    /// x 0,47 / y 0,53), pas d'un réglage à l'œil.
    private func filmDiam(_ W: CGFloat) -> CGFloat { W * 9 / 16 * 0.94 }
    private func filmCentre(_ W: CGFloat, _ H: CGFloat) -> CGPoint {
        CGPoint(x: W * 0.47, y: H * 0.42 + (0.53 - 0.5) * W * 9 / 16)
    }

    /// ⚠️ **LES DEUX PIÈCES SONT MONTÉES EN PERMANENCE, ET ELLES GLISSENT.**
    /// Le premier jet n'en montrait qu'UNE et faisait « voyager » un objet qui
    /// se remplaçait tout seul au passage du cran : on ne voyait donc jamais
    /// la seconde ARRIVER, ce qui était pourtant toute la demande (« la
    /// deuxième pièce noire qu'on peut voir au drag »). Ici chacune a sa
    /// place sur un rail, `page` fait défiler le rail, et pendant tout le
    /// geste **les deux sont à l'écran** — celle qui part et celle qui vient.
    ///
    /// Le pas du rail vaut 0,86 W : assez pour que la sortante soit hors du
    /// cadre au cran, assez peu pour qu'on aperçoive l'entrante dès les
    /// premiers points de doigt.
    @ViewBuilder
    private func piece(W: CGFloat, H: CGFloat) -> some View {
        let d = CoffreV2Cotes.piece
        let repos = CGPoint(x: W / 2, y: H * CoffreV2Cotes.piecY)
        let depart = filmCentre(W, H)
        // Le raccord interpole TOUT en même temps : la taille, la place, et
        // rien d'autre. Une seule courbe, donc aucun décalage possible.
        let r = raccord * raccord * (3 - 2 * raccord)      // smoothstep
        let pas = W * 0.86

        ZStack {
            ForEach(Array(Self.manege.enumerated()), id: \.offset) { i, pl in
                // L'écart au centre, en fraction de pas : 0 = présentée.
                let e = Double(i) - page
                // ⚠️ LE FLOU EST UNE MISE AU POINT, PAS UN EFFET : ce qui
                // voyage est flou, ce qui est POSÉ est net. Il vaut donc
                // |e| borné, et il tombe à zéro sur chaque cran — jamais la
                // formule en |sin(2πu)| du plan, qui pique aux quarts et
                // laisserait la pièce nette EN PLEIN VOYAGE.
                let loin = min(abs(e), 1)
                // La pièce présentée est la seule à jouer le raccord du film.
                let actif = abs(e) < 0.5
                let diam = actif ? d + (filmDiam(W) - d) * CGFloat(r) : d
                let cx = W / 2 + CGFloat(e) * pas
                    + (actif ? (depart.x - repos.x) * CGFloat(r) : 0)
                let cy = repos.y + (actif ? (depart.y - repos.y) * CGFloat(r) : 0)

                ZStack {
                    // L'OMBRE DE CONTACT — serrée et écrasée. Une flaque large
                    // ne pose rien, elle salit le sol. Elle meurt pendant le
                    // raccord : une pièce en vol n'a pas d'ombre au sol.
                    Ellipse()
                        .fill(Color.black.opacity(0.80 * (actif ? (1 - r) : 1)))
                        .frame(width: d * 1.04, height: d * 0.23)
                        .blur(radius: 18)
                        .position(x: cx, y: repos.y + d * 0.40)
                        .opacity(1 - loin)

                    PieceSprite(planche: pl, tour: tour, diametre: diam)
                        // ⚠️ Le flou et l'échelle sont LÉGAUX ICI : ce sont des
                        // IMAGES, pas du verre natif (l'interdit du §6.3 ne
                        // vaut que pour `glassEffect`). C'est ce que la voie
                        // « les rendus de Kathryn » a débloqué.
                        .blur(radius: 7 * loin)
                        .scaleEffect(1 - 0.16 * loin)
                        .position(x: cx, y: cy)
                        .opacity(1 - 0.35 * loin)
                }
                .allowsHitTesting(actif)
            }
        }
        .contentShape(Rectangle())
        .gesture(gestePiece)
        .allowsHitTesting(nee)
    }

    // MARK: Les gestes

    /// LE DOIGT SUR LA PIÈCE : il la fait tourner, et il pousse la lampe.
    private var gestePiece: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if eclat < 0.02 {
                    tourPrise = tour
                    UIImpactFeedbackGenerator(style: .soft)
                        .impactOccurred(intensity: 0.6)
                }
                withAnimation(.easeOut(duration: 0.26)) { eclat = 1 }
                // 320 pt de doigt = un tour complet.
                tour = tourPrise + Double(v.translation.width) / 320
            }
            .onEnded { _ in
                // ⚠️ LA RETOMBÉE EST PLUS LENTE QUE LA MONTÉE (0,62 contre
                // 0,26). Une lampe frappe et s'éteint doucement ; l'inverse se
                // lit comme un bug d'affichage.
                withAnimation(.easeInOut(duration: 0.62)) { eclat = 0 }
            }
    }

    /// LE GESTE DE LA PAGE — un seul reconnaisseur, DEUX sens, et un axe
    /// verrouillé au premier mouvement franc : vertical = la card se soulève
    /// et la lune se découvre ; horizontal = le manège change de pièce.
    private var gestePage: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { g in
                if axeVertical == nil {
                    let dx = abs(g.translation.width)
                    let dy = abs(g.translation.height)
                    guard max(dx, dy) > 10 else { return }
                    axeVertical = dy > dx
                    if axeVertical == false { pagePrise = page }
                }
                if axeVertical == true {
                    let t = g.translation.height
                    let net = t < 0 ? min(t + 14, 0) : max(t - 14, 0)
                    tirage = CoffreV2Cotes.levee * CGFloat(tanh(Double(net) / 190))
                } else {
                    // ⚠️ **VERS LA DROITE AMÈNE LA PIÈCE NOIRE** (sa demande,
                    // mot pour mot). C'est l'inverse de la convention d'un
                    // carrousel — on suit la commande, pas l'habitude.
                    // 200 pt de doigt = un cran ; la course est bornée : deux
                    // pièces, pas un rouleau infini.
                    let d = Double(g.translation.width) / 200
                    page = min(max(pagePrise + d, 0), 1)
                }
            }
            .onEnded { g in
                let vertical = axeVertical ?? true
                axeVertical = nil
                if vertical {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                        tirage = 0
                    }
                } else {
                    // LE CRAN : on tombe sur la pièce la plus proche, élan
                    // compris. Une pièce ne s'immobilise pas entre deux faces.
                    let elan = Double(g.predictedEndTranslation.width) / 200
                    let vise = (pagePrise + elan).rounded()
                    let cible = min(max(vise, 0), 1)
                    if cible != page.rounded() {
                        UIImpactFeedbackGenerator(style: .rigid)
                            .impactOccurred(intensity: 0.7)
                    }
                    withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                        page = cible
                    }
                }
            }
    }

    // MARK: L'arrivée

    @ViewBuilder
    private func film(_ geo: GeometryProxy) -> some View {
        let W = geo.size.width
        let H = geo.size.height
        if let lecteur {
            // LA BANDE 16:9 — le film est PAYSAGE et ses pièces occupent la
            // bande centrale : un crop portrait les couperait en deux
            // (mesuré). On le montre donc entier, en bande.
            CinematicPlayer(player: lecteur)
                .frame(width: W, height: W * 9 / 16)
                .mask(fonduBords)
                .position(x: W / 2, y: H * 0.42)
                // ⚠️ IL S'ÉTEINT PENDANT QUE LA PIÈCE SE POSE, pas avant : les
                // deux partagent le MÊME curseur `raccord`. C'est ce qui fait
                // que l'objet du film et celui de la page ne se croisent
                // jamais — ils sont le même, une seule image durant.
                .opacity(raccord)
                .allowsHitTesting(false)

            // LA SURFACE DU RACCOURCI — TOUT L'ÉCRAN, et c'est délibéré. Sur
            // la v1 elle était bornée à la bande vidéo ; ici la page n'a rien
            // d'autre à écouter pendant l'arrivée, et un raccourci qu'on rate
            // parce qu'on a tapé 40 pt trop bas n'est pas un raccourci.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { passerDevant() }
                .accessibilityLabel("Passer l'introduction")
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
        guard !nee, !passe else { return }
        // Le banc ouvre directement sur le second cran (capture de la noire).
        if Self.argentDabord { page = 1 }
        if let f = Self.pageFigee { page = f }
        // Sans film (ou sous Reduce Motion), la page est là tout de suite : on
        // ne fait jamais attendre devant une absence.
        guard !Self.sansFilm, !reduceMotion,
              let url = Bundle.main.url(forResource: "coffre-arrivee",
                                        withExtension: "mp4") else {
            poser(duree: 0.01); return
        }
        let p = AVPlayer(url: url)
        p.automaticallyWaitsToMinimizeStalling = false
        p.isMuted = true
        lecteur = p
        filmVisible = true
        p.play()
        // 45 images à 24 i/s = 1,88 s : la ruée, puis la montée au sommet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.86) { poser() }
        if Self.skipAuto {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { passerDevant() }
        }
    }

    /// LE RACCOURCI. ⚠️ Il ne SAUTE pas : la home a déjà payé le saut (« de
    /// 0,6 à 1,95 en UNE image » → verdict « pas assez fluide »). Il joue la
    /// MÊME pose, en deux fois moins de temps.
    private func passerDevant() {
        guard !passe else { return }
        poser(duree: 0.44)
    }

    /// LA POSE — l'unique transition du film vers la page.
    private func poser(duree: Double = 0.86) {
        guard !passe else { return }
        passe = true
        nee = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
        // ⚠️ UNE SEULE COURBE POUR TOUT : la pièce rétrécit, descend, et le
        // film s'éteint sur le même `raccord`. Deux animations parallèles
        // auraient deux durées et l'objet se dédoublerait à l'œil.
        withAnimation(.timingCurve(0.22, 0.72, 0.16, 1, duration: duree)) {
            raccord = 0
        }
        // La phrase s'écrit DERRIÈRE la pose, jamais après : elle a le temps
        // d'arriver pendant que la pièce descend.
        withAnimation(.linear(duration: 1.18).delay(duree * 0.34)) {
            arrivee = 1.18
        }
        // Le lecteur s'arrête quand il n'est plus vu — inutile de décoder du
        // 1080 sous une couche à opacité zéro.
        DispatchQueue.main.asyncAfter(deadline: .now() + duree + 0.05) {
            lecteur?.pause()
            lecteur = nil
            filmVisible = false
        }
    }
}

// MARK: - Le banc

/// `-coffre2` : la page seule.
/// `-coffreSansFilm` saute l'arrivée · `-coffreSkip` la passe à 1,2 s (le
/// simulateur ne tape pas) · `-coffreArgent` ouvre sur la seconde pièce.
struct CoffreV2Lab: View {
    var body: some View {
        CoffreV2Page(coins: 1240)
            .preferredColorScheme(.dark)
    }
}
