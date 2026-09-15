import SwiftUI
import AVFoundation

// MARK: - LA GRANDE CARD DE LA PAGE EXERCICES (22-08)
//
// La page Exercices reprend la grammaire de la home v2 : la page entière est
// UNE card à très grands coins arrondis, posée sur la nuit, qui suit le doigt
// vers le bas et qui SE RACCOURCIT par le bas pour découvrir le player quand
// la séance tourne.
//
// ⚠️ POURQUOI UN JUMEAU DE `GrandeCardVideo` ET PAS UN PARAMÈTRE DESSUS.
// La card de la home est en plein chantier (le scrub au geste, la scène de
// départ, la rotation 3D de la vidéo) : s'y accrocher, c'est hériter d'un
// comportement qui change sous nous. Ici la card est plus simple — pas de
// caméra, pas de scrub — et elle a un besoin que la home n'a pas : PUBLIER SA
// FORME, parce que son contenu (une grille qui défile) doit être découpé
// dedans. Les deux partagent ce qui compte vraiment : `BoosterLoopLayerView`,
// l'école `AVPlayerLooper`, et l'image de pose sous la vidéo.

/// La boucle du fond — l'école exacte de la home et de la pop-up booster :
/// `AVPlayerLooper` (jamais un seek sur didPlayToEndTime), looper RETENU par
/// le coordinateur, muet, démontage qui rend tout, et la reprise au retour de
/// l'arrière-plan (une page d'onglet n'est pas un panneau transitoire).
struct ExosFondVideo: UIViewRepresentable {
    /// §3.4septies F2 : le lecteur SE TAIT quand le player global couvre
    /// (« les lecteurs se taisent quand la page ne se voit plus »).
    var rate: Float = 1

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var retour: NSObjectProtocol?
        var statut: NSKeyValueObservation?
        /// Le rate DEMANDÉ par l'hôte — ce que les réveils rejouent
        /// (03-09, chantier chauffe item 1 : un `play()` en dur au retour
        /// au premier plan relançait le décodeur sous sa porte).
        var rate: Float = 1
        deinit {
            if let r = retour { NotificationCenter.default.removeObserver(r) }
            statut?.invalidate()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BoosterLoopLayerView {
        let v = BoosterLoopLayerView()
        // ⚠️ Le fond de la couche est TRANSPARENT, jamais noir : c'est
        // l'image de pose posée dessous qui doit se voir quand le décodeur
        // rate une frame. Une couche noire opaque, et le raté DEVIENT le
        // glitch noir (le défaut payé le 21-08 sur la home).
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.playerLayer.videoGravity = .resizeAspectFill
        v.playerLayer.backgroundColor = UIColor.clear.cgColor
        // ⚠️ `resizeAspectFill` DÉBORDE SES BORNES. Un `CALayer` ne masque pas
        // ses enfants par défaut, et le `clipShape` de SwiftUI ne rattrape pas
        // une couche UIKit : la vidéo (1620 × 3522 dans une boîte de
        // 1146 × 2592) débordait de 23 px de chaque côté et allait se poser à
        // 2,3 pt du bord de l'écran — mesuré — au lieu des 10 pt de marge de
        // nuit de la card. La card paraissait collée aux flancs, et sa lumière
        // touchait l'arête physique.
        v.clipsToBounds = true
        v.playerLayer.masksToBounds = true
        // LE CELLIER DU SPLASH (03-09, item 9) : l'asset vient de
        // `AssetsVideo` — chauffé au lancement, il ne se re-parse pas.
        // L'`AVPlayerItem(url:)` direct parsait le mp4 de 16,5 Mo À FROID
        // dans la transition animée du premier tap d'onglet.
        guard let modele = AssetsVideo.item("exos-fond-loop") else {
            // Sans le fichier, l'image de pose tient la page à elle seule.
            return v
        }
        let p = AVQueuePlayer()
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        let c = context.coordinator
        c.looper = AVPlayerLooper(player: p, templateItem: modele)
        c.player = p
        v.playerLayer.player = p
        // ⚠️ LES RÉVEILS REJOUENT LE RATE DEMANDÉ (03-09, item 1) — plus
        // jamais un `play()` en dur qui relance un lecteur en pose.
        c.rate = rate
        if c.rate > 0 { p.rate = c.rate }
        // LE PRÉCHARGEMENT, une fois les tampons prêts : sans lui la première
        // seconde est une suite de frames manquées.
        // ⚠️ `preroll` LÈVE UNE EXCEPTION tant que le statut n'est pas
        // `readyToPlay` — appelé à la construction, il tue l'app au lancement
        // (payé le 21-08). Il s'attache donc au statut. Préroller reste
        // permis : c'est le play FINAL qui se conditionne.
        c.statut = p.observe(\.status, options: [.new]) { [weak c] joueur, _ in
            guard joueur.status == .readyToPlay else { return }
            joueur.preroll(atRate: 1) { fini in
                guard fini, let c, c.rate > 0, c.player === joueur else { return }
                joueur.rate = c.rate
            }
        }
        c.retour = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main) { [weak p, weak c] _ in
                guard let p, let c, c.rate > 0, c.player === p else { return }
                p.rate = c.rate
            }
        return v
    }

    func updateUIView(_ v: BoosterLoopLayerView, context: Context) {
        let c = context.coordinator
        c.rate = rate
        guard let p = c.player else { return }
        if p.rate != rate { p.rate = rate }
    }

    static func dismantleUIView(_ v: BoosterLoopLayerView,
                                coordinator: Coordinator) {
        let c = coordinator
        c.rate = 0
        if let retour = c.retour { NotificationCenter.default.removeObserver(retour) }
        c.retour = nil
        c.statut?.invalidate(); c.statut = nil
        let p = c.player
        p?.cancelPendingPrerolls()
        p?.pause()
        c.looper?.disableLooping(); c.looper = nil
        p?.removeAllItems()
        v.playerLayer.player = nil
        c.player = nil
        NavDiagnostic.noter("video-demontage",
            destination: "exos-fond-loop;rate=\(p?.rate ?? 0);items=\(p?.items().count ?? 0)")
    }
}

/// LA CARD : le fond vidéo de la page Exercices, aux cotes de la home — marge
/// de nuit de 10 pt sur trois côtés, rayon CONCENTRIQUE (celui de l'écran
/// moins la marge en haut, celui de l'écran en bas puisqu'elle touche le bord
/// physique). C'est ce décrochage de rayon qui la fait lire « posée » et pas
/// « collée ».
/// §3.4ter : l'`ignoresSafeArea` conditionnel de la card exos — plein
/// écran dans l'ancien monde, sage dans le slot du moteur.
private struct IgnoreSaufNue: ViewModifier {
    let nue: Bool
    func body(content: Content) -> some View {
        if nue { content } else { content.ignoresSafeArea() }
    }
}

struct GrandeCardExos: View {
    /// La naissance de la page, 0 → 1 : la card s'allume en fondu avec une
    /// approche imperceptible (1,015 → 1). Jamais un bounce (la spec).
    var naissance: Double = 1
    /// LA PORTE D'ONGLET (03-09, item 4) : quand la page n'est pas
    /// l'onglet affiché, le lecteur CÈDE LA PLACE à sa pose — l'école
    /// exacte de la home sous `\.dort` (« pas un rate 0 : ce lecteur
    /// l'ignore par trois chemins, et le réveil flushe la couche »).
    @Environment(\.ongletCache) private var ongletCache
    /// §3.4ter S2' : `nue` = SANS robe (ni clip, ni marges, ni
    /// `ignoresSafeArea`) — la robe vient du moteur PageCard, la card
    /// n'est plus que son fond vidéo, plein cadre du slot.
    var nue: Bool = false
    /// LA MARGE DE NUIT — VERTICALE SEULEMENT (verdict 22-08 : « il y a trop
    /// d'espace, la card doit prendre les côtés droit et gauche »). La card
    /// touche les deux flancs et ne garde sa bande de nuit qu'EN HAUT : c'est
    /// elle qui la fait lire « posée », et c'est elle qui s'ouvre quand on
    /// pousse la page.
    static let margeHaut: CGFloat = 10
    static let margeCote: CGFloat = 0
    /// LE RAYON DE L'ÉCRAN, sur les QUATRE coins. La loi concentrique dit
    /// qu'une forme prend le rayon de l'écran MOINS sa marge : à 10 pt du bord
    /// c'était 45, mais la card touche désormais l'arête physique sur ses deux
    /// flancs — un rayon plus serré y laisserait un croissant de nuit au coin,
    /// et c'est exactement ce décrochage qui trahit une marge oubliée.
    static let rayon: CGFloat = 55

    /// LA FORME, publiée : le contenu de la page (la grille qui défile) se
    /// découpe DEDANS. Deux formes qui divergeraient d'un point, et les
    /// cartes dépasseraient des coins.
    static var forme: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: rayon,
                               bottomLeadingRadius: rayon,
                               bottomTrailingRadius: rayon,
                               topTrailingRadius: rayon,
                               style: .continuous)
    }

    var body: some View {
        Color.black
            .overlay(
                // ⚠️ LE `Color.clear` N'EST PAS DÉCORATIF, IL TIENT LA TAILLE —
                // et c'est le correctif d'un défaut MESURÉ (22-08 : la card se
                // posait à 2,3 pt du bord au lieu de 10). `aspectRatio(.fill)`
                // ne donne PAS à sa vue la taille proposée : elle prend la
                // taille REMPLIE, plus grande. Le `clipShape` posé dessus
                // découpait donc à la taille DÉBORDÉE — il ne coupait rien — et
                // le `padding` centrait ce bloc trop large dans la page. La
                // preuve par le banc : marge 10 → bord à 2,3 pt ; marge 30 →
                // bord à 7,0 pt. Toujours 23 % de la marge demandée, soit
                // exactement le débord de la vidéo (hauteur × 0,46).
                //
                // Un hôte de taille NEUTRE fixe le cadre, le contenu déborde
                // dedans, et le clip mord enfin sur la bonne forme.
                Color.clear
                    .overlay {
                        ZStack {
                            // L'IMAGE DE POSE, dessous : le FILET du fond. Le
                            // décodage du simulateur est logiciel et rate des
                            // frames ; sans elle, un raté peint tout en NOIR.
                            Image("exos-fond-poster")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                            // Onglet caché → le lecteur se DÉMONTE, la pose
                            // tient la card ; au retour il renaît derrière
                            // elle (le cellier du splash rend la renaissance
                            // gratuite — plus de re-parse).
                            if !ongletCache {
                                ExosFondVideo(
                                    rate: PlayerEtat.shared.couvre ? 0 : 1)
                            }
                        }
                    }
                .clipShape(nue ? UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 0,
                    style: .continuous) : Self.forme)
                .padding(.top, nue ? 0 : Self.margeHaut)
                .padding(.horizontal, nue ? 0 : Self.margeCote)
                .opacity(naissance)
                .scaleEffect(1.015 - 0.015 * naissance)
            )
            // §3.4ter : nue, la card vit dans un slot en zone sûre — un
            // `ignoresSafeArea` y volerait les insets (la loi du root).
            .modifier(IgnoreSaufNue(nue: nue))
        // ⚠️ LA LEVÉE NE VIT PLUS ICI : c'est `CarteLevee` qui la pose, en
        // `ViewModifier`, pour que la card puisse suivre le doigt sans que le
        // reste de la page ne soit reconstruit. Elle se retire EN BAS, et le
        // noir avec — posée sur le seul contenu, elle laisserait le fond noir
        // couvrir toute la page : la bande s'ouvrirait vraiment, mais derrière
        // un rideau noir.
    }
}
