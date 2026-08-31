import SwiftUI
import AVFoundation

// MARK: - LA CARD « STOP » — le player pose sa question dans la lumière
//
// Plan : tools/stop/PLAN-STOP-CARD.md. La réf : la card « You Made It »
// (le spot, le mot géant révélé par la lampe), la châsse Nosfy (la bête sur
// du noir vrai, jamais détourée), la home (le slider).
//
// ⚠️ LA LOI DU CHANTIER : la card ne dépend pas du mot pour être comprise.
// Le mot est une ATMOSPHÈRE (la bête se tient devant, elle en cache le
// milieu, c'est voulu) ; la question est le titre, la décision est le slider.

// MARK: L'hôte à la racine

/// LA SIGNATURE EXACTE DE `PausePanneauHote` : le stop des cinq players
/// converge ici par `DepartEtat.shared.pauseOuverte`, la racine le monte
/// inconditionnellement — c'est l'hôte qui gère son vide.
///
/// Un seul progrès `p` porté par une vue `Animatable` (jamais des `.opacity`
/// sous un `withAnimation` nu). Les verrous sont des DRAPEAUX posés par les
/// completions — jamais une garde sur la valeur de `p` : sous `withAnimation`
/// le modèle saute à la cible dès la première image.
struct StopCardHote: View {
    var ouverte: Bool
    var duree: String
    var series: Int
    var gain: Int
    var onTerminer: () -> Void = {}
    var onContinuer: () -> Void = {}

    /// L'unique progrès de l'entrée [0,1] — toutes les rampes en dérivent.
    @State private var p: Double = 0
    /// La card vit (elle reste montée tant que sa sortie joue).
    @State private var montee = false
    /// L'entrée est posée — le verrou du commit.
    @State private var posee = false
    /// La sortie est engagée — plus rien n'y touche.
    @State private var enSortie = false
    /// L'horloge du spot et de la poudre — posée à CHAQUE ouverture.
    @State private var naissance = Date()
    /// L'haptique de la pose (le sim ne vibre pas — verdict téléphone).
    @State private var boum = 0

    var body: some View {
        ZStack {
            Color.clear
            if montee {
                StopCard(p: p, duree: duree, series: series, gain: gain,
                         naissance: naissance,
                         onStop: commettre,
                         onCancel: { fermer(puis: onContinuer) })
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(ouverte)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.8),
                         trigger: boum)
        .onChange(of: ouverte) { _, v in
            if v {
                if !montee { ouvrir() }
            } else if montee, !enSortie {
                // Fermée par un tiers (une clôture qui n'est pas passée
                // par la card) : elle sort proprement quand même.
                fermer(puis: {})
            }
        }
        // Au banc, l'hôte naît ouvert.
        .onAppear { if ouverte, !montee { ouvrir() } }
    }

    // MARK: le film

    /// L'ENTRÉE — 0,60 s linéaire : une question, pas une cérémonie (la
    /// reward prend 1,45 s parce qu'elle fête). Les smoothsteps internes
    /// portent chacun leur courbe.
    private func ouvrir() {
        // `-stopT <s>` recule la naissance : les horloges partent à `s`.
        naissance = Date().addingTimeInterval(-(StopBanc.tFige ?? 0))
        enSortie = false
        posee = StopBanc.fige
        p = StopBanc.fige ? 1 : 0
        montee = true
        guard !StopBanc.fige else { return }
        withAnimation(.linear(duration: 0.60)) {
            p = 1
        } completion: {
            posee = true
            boum += 1
        }
    }

    /// CANCEL (le lien, ou le scrim) — 0,30 s, puis l'hôte apprend.
    private func fermer(puis fin: @escaping () -> Void) {
        guard montee, !enSortie else { return }
        enSortie = true
        withAnimation(.easeOut(duration: 0.30)) {
            p = 0
        } completion: {
            montee = false
            fin()
        }
    }

    /// STOP — le slider a commis. L'ORDRE EST LE SUJET : le slider joue SON
    /// filament et sa gerbe (0,45 s, on ne le démonte pas pendant), PUIS la
    /// card s'en va, PUIS la clôture — `terminerSeance()` inchangée (home,
    /// trophée, notif pièces, booster). Son `pauseOuverte = false` tombe sur
    /// une card déjà partie : sans effet visible, c'est voulu.
    private func commettre() {
        guard montee, posee, !enSortie else { return }
        enSortie = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            withAnimation(.easeOut(duration: 0.42)) {
                p = 0
            } completion: {
                montee = false
                onTerminer()
            }
        }
    }
}

// MARK: - La card

/// LA SCÈNE — c'est ELLE qui déplie `p` image par image (Animatable), donc
/// toutes les rampes dérivées jouent sous le `withAnimation` de l'hôte.
struct StopCard: View, Animatable {
    var p: Double
    var duree: String
    var series: Int
    var gain: Int
    var naissance: Date
    var onStop: () -> Void
    var onCancel: () -> Void

    var animatableData: Double {
        get { p }
        set { p = newValue }
    }

    /// La forme de la famille (RewardScene) : rayon 36 continu.
    private static let forme = RoundedRectangle(cornerRadius: 36,
                                                style: .continuous)
    /// 332 × 480 pt : plus haute que la reward (1,32) — elle porte un slider.
    private static let ratio: CGFloat = 480.0 / 332.0
    /// Le centre du mot, depuis le bord haut (§2.1 du plan).
    private static let centreMot: CGFloat = 112

    var body: some View {
        GeometryReader { g in
            let l = min(g.size.width * 0.80, 332)
            ZStack {
                // Le scrim — profond, et il porte Cancel au tap.
                Color.black.opacity(0.70 * sstep(0, 0.35, p))
                    .contentShape(Rectangle())
                    .onTapGesture { onCancel() }
                carte(largeur: l, hauteur: l * Self.ratio)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
    }

    // MARK: les couches, de l'arrière vers l'avant

    private func carte(largeur l: CGFloat, hauteur h: CGFloat) -> some View {
        ZStack {
            // 1. LA DALLE — noire. Pas de verre : la vidéo bord à bord est
            //    opaque, un verre dessous ne serait jamais vu et coûterait.
            Self.forme.fill(Color.black)

            // 2. LA VIDÉO, BORD À BORD — la bête et du noir EXACT, rien
            //    d'autre. Elle occupe la card entière : aucun bord de
            //    rectangle à voir, aucun masque sur la couche (la loi).
            //    La bête ENTRE DANS LA LUMIÈRE (fondu).
            if !StopBanc.sansVideo {
                VideoBoucle(nom: "stop-bat-loop")
                    .frame(width: l, height: h)
                    .opacity(sstep(0.30, 0.60, p))
            }

            // 3. LE MUR — ce qui vit DERRIÈRE la bête (le fond gris → noir
            //    et le mot), troué à sa silhouette. C'est ainsi qu'elle est
            //    « devant » sans qu'aucune vidéo soit détourée.
            mur(largeur: l, hauteur: h)

            // 4. LE CÔNE — NON masqué, en écran : il éclaire le mot ET la
            //    bête. La lumière vit DEVANT le plan, la seule place permise.
            LampeEventail(naissance: naissance)
                .opacity(sstep(0.25, 0.70, p))

            // 5. LA POUDRE — devant tout, comme sur toutes les cards.
            PoudreDiamant(largeur: l, hauteur: h, naissance: naissance)
                .opacity(sstep(0.35, 0.75, p))

            // 6. L'ENCRE.
            encre(largeur: l, hauteur: h)

            // 7. LE LISERÉ — un fil neutre, à peine là (la reward « autres »).
            Self.forme.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.14), location: 0),
                        .init(color: .white.opacity(0.08), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom),
                lineWidth: 1)
                .opacity(sstep(0.12, 0.45, p))
        }
        // Le clip qui rogne le mot (il est HORS layout) — obligatoire.
        .clipShape(Self.forme)
        .frame(width: l, height: h)
        // Une transform, jamais un resize.
        .scaleEffect(0.94 + 0.06 * sstep(0, 0.30, p))
        .opacity(sstep(0, 0.16, p))
        // L'ombre est BLANCHE : sur une page éteinte, c'est la lumière qui
        // continue sous la card et la détache.
        .shadow(color: .white.opacity(0.14 * sstep(0.25, 0.65, p)),
                radius: 38, y: 30)
    }

    /// LE MUR : le fond (inversé, voir `fond`) et le mot, SOMBRE, que la lampe
    /// révèle — jamais une opacité baissée.
    ///
    /// Le tout sous UN masque, cuit par `tools/stop/bake_stop.py` : la
    /// silhouette inverse de la bête, NOYÉE DANS UNE POCHE D'OMBRE de 22 pt.
    /// Ce n'est pas un détourage — c'en est le contraire assumé. La silhouette
    /// est STATIQUE alors que les oreilles BOUGENT (elles sortent du trou de
    /// 1 553 px en médiane, 4 889 au pire) : aucun contour n'est juste sur les
    /// 240 images, donc on ne cherche plus le contour, on l'éteint. Le mur
    /// meurt en approchant d'elle ; une oreille qui déborde n'a plus rien à
    /// découper, et le mot s'efface avant de la toucher.
    ///
    /// ⚠️ Ce sont les LETTRES qui faisaient le halo, pas le gris du fond (le T
    /// et le O passent pile sur ses oreilles) : mesuré, le fond inversé seul ne
    /// menait le p95 du bord que de 151 à 143 — c'est la poche qui le met à 102.
    private func mur(largeur l: CGFloat, hauteur h: CGFloat) -> some View {
        ZStack {
            Self.fond
            TexteGeant(naissance: naissance, lignes: ["STOP"])
                // Les flancs seuls (le masque hôte des autres robes) — le
                // fondu du pied est DÉJÀ dans l'encre du composant.
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white, location: 0.24),
                            .init(color: .white, location: 0.76),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading, endPoint: .trailing))
                // Le composant centre le mot (et le décale de +6) : on le
                // remonte au centre voulu.
                .offset(y: Self.centreMot - h / 2 - 6)
        }
        .mask {
            Image("stop-bat-masque")
                .resizable()
                .frame(width: l, height: h)
        }
        .opacity(sstep(0.10, 0.45, p))
        .allowsHitTesting(false)
    }

    /// LE MUR INVERSÉ (tranché avec Kathryn le 29-08) — le quasi-noir en HAUT,
    /// derrière le mot et la bête ; le gris monte du BAS.
    ///
    /// Le mur d'origine (crête grise à 26 %) mettait du clair pile derrière
    /// ses oreilles : comme la silhouette est statique et que les oreilles
    /// bougent, chaque écart s'y voyait. Sur du quasi-noir, l'écart n'a plus
    /// de quoi se voir. Et le mot y GAGNE : à opacité égale, du blanc à 0,40
    /// sur du 0,01 contraste 40 fois, contre 3,8 fois sur l'ancien 0,125.
    ///
    /// La lueur de sol reste BASSE et meurt avant le slider : celui-ci est une
    /// obsidienne noire, un plancher clair l'aplatirait, et le titre blanc y
    /// perdrait son mordant.
    private static let fond = LinearGradient(
        stops: [
            .init(color: Color(white: 0.006), location: 0),
            .init(color: Color(white: 0.012), location: 0.35),
            .init(color: Color(white: 0.045), location: 0.60),
            .init(color: Color(white: 0.062), location: 0.72),
            .init(color: Color(white: 0.028), location: 0.84),
            .init(color: Color(white: 0.008), location: 1)
        ],
        startPoint: .top, endPoint: .bottom)

    // MARK: l'encre

    private var bilan: String {
        "\(series) \(series == 1 ? "set" : "sets") · \(duree) · +\(gain) coins"
    }

    private func encre(largeur l: CGFloat, hauteur h: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            titres
                .opacity(sstep(0.45, 0.75, p))
                .offset(y: 6 * (1 - sstep(0.45, 0.75, p)))
            commandes
                .opacity(sstep(0.55, 0.90, p))
                .offset(y: 8 * (1 - sstep(0.55, 0.90, p)))
        }
        // 36 et non 16 (verdict Kathryn 30-08, « élève le stop dans la
        // pop-up ») : le bloc slider respire du bord bas de la card.
        .padding(.bottom, 36)
        .frame(width: l, height: h, alignment: .bottom)
    }

    /// Titre et bilan RESPIRENT (verdict Kathryn 29-08 : +4 pt) — collés,
    /// ils se lisaient comme une seule masse.
    private var titres: some View {
        VStack(spacing: 10) {
            Text("Stop the session?")
                .font(.inter(22, .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.white, .white.opacity(0.78)],
                                   startPoint: .top, endPoint: .bottom))
            Text(bilan)
                .font(.inter(15))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .multilineTextAlignment(.center)
        .allowsHitTesting(false)
    }

    /// Le slider de la home, libellé « Stop » (le composant le met en
    /// capitales). ⚠️ `onConfirm:` NOMMÉ — deux propriétés optionnelles le
    /// suivent, une closure traînante irait se coller à `pose`.
    ///
    /// `labelCentre: true` : sans lui le composant décale son mot vers la
    /// droite (il fuit le pouce), et « STOP » ne tombait pas sur l'axe de
    /// « Cancel » juste dessous — ça se lisait comme un défaut d'alignement.
    private var commandes: some View {
        VStack(spacing: 6) {
            SliderObsidienne(label: "Stop",
                             height: 62,
                             auto: StopBanc.sliderAuto,
                             labelCentre: true,
                             onConfirm: onStop)
                .padding(.horizontal, 20)
                // +10 pt (verdict Kathryn 29-08) : le bloc de texte se
                // décolle du slider, la décision n'est plus dans la question.
                .padding(.top, 28)
            // LE BOUTON LIEN — de l'encre nue, la zone de toucher reste large.
            // (Aucun drag d'ancêtre dans cette card : un `Button` suffit.)
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - La couche vidéo

// ⚠️ INTERNAL, plus private (30-08) : la card booster monte la même couche
// (`booster-dot-loop`). Le type de vue doit suivre — un `makeUIView` qui
// rend un type privé depuis une struct interne ne compile pas.
final class BoucleLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// LA BOUCLE — l'école `VideoNosfy` : `AVPlayerLooper` RETENU par le
/// coordinateur (relâché, la boucle s'arrête au premier tour), muette,
/// `clipsToBounds` ET `masksToBounds` (un CALayer ne masque pas ses enfants,
/// et le `clipShape` SwiftUI ne rattrape pas une couche UIKit). Fond NOIR
/// sous le décodeur : le sim décode en logiciel et rate des images — sur la
/// dalle noire, un raté est invisible.
struct VideoBoucle: UIViewRepresentable {
    let nom: String

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BoucleLayerView {
        let v = BoucleLayerView()
        v.backgroundColor = .black
        v.isUserInteractionEnabled = false
        v.clipsToBounds = true
        v.layer.masksToBounds = true
        // Le fichier est au ratio EXACT de la card (1080 × 1562).
        v.playerLayer.videoGravity = .resizeAspectFill
        // ⚠️ `Woop/Media` est NU : `Image(nom)` n'y trouve rien, en silence.
        guard let url = Bundle.main.url(forResource: nom,
                                        withExtension: "mp4") else {
            return v
        }
        let p = AVQueuePlayer()
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        // AVPlayerLooper, JAMAIS un `seek(.zero)` sur `didPlayToEndTime`.
        context.coordinator.looper = AVPlayerLooper(
            player: p, templateItem: AVPlayerItem(url: url))
        context.coordinator.player = p
        v.playerLayer.player = p
        p.play()
        return v
    }

    func updateUIView(_ v: BoucleLayerView, context: Context) {}

    static func dismantleUIView(_ v: BoucleLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }
}

// MARK: - Le banc (`-stopLab`) — les prises, lues UNE fois

enum StopBanc {
    /// Le banc est en scène : la card SEULE sur du noir.
    static let actif = CommandLine.arguments.contains("-stopLab")
    /// `-stopFige` — la card naît POSÉE (captures immobiles, aucune rampe).
    static let fige = CommandLine.arguments.contains("-stopFige")
    /// `-stopNu` — pas de bandeau.
    static let nu = CommandLine.arguments.contains("-stopNu")
    /// `-stopAuto` — ouvre / ferme en boucle : c'est celui qu'on FILME.
    static let auto = CommandLine.arguments.contains("-stopAuto")
    /// `-stopSliderAuto` — le slider rejoue son geste seul (le sim n'a pas
    /// de doigt) : le commit se filme.
    static let sliderAuto = CommandLine.arguments.contains("-stopSliderAuto")
    /// `-fps` — la sonde de cadence (`simctl launch --console-pty`).
    static let fps = CommandLine.arguments.contains("-fps")

    /// `-stopSansVideo` — SONDE : la card sans sa couche vidéo, tout le reste
    /// identique. Elle ne sert qu'à ATTRIBUER un gel : le film du 29-08 montre
    /// que l'app se fige ~0,7 s à chaque montage de la card, ce qui avale
    /// l'entrée de 0,60 s (elle saute en 10 ms). Le suspect est la naissance
    /// de l'`AVPlayer`. Filmer le banc avec ET sans ce drapeau, et comparer
    /// les trous d'horodatage, tranche la question — un juge qui affirme ne
    /// remplace pas une sonde qui mesure.
    static let sansVideo = CommandLine.arguments.contains("-stopSansVideo")

    /// `-stopT <s>` — les horloges (balayage du spot, scintilles, poudre)
    /// NAISSENT à l'instant `s` : la card se monte avec `naissance` reculée
    /// d'autant.
    ///
    /// ⚠️ Ce que ça fait vraiment, et pas plus : ça ALIGNE LA PHASE de deux
    /// lancements, ça ne les FIGE pas — `TexteGeant`, `LampeEventail` et
    /// `PoudreDiamant` portent chacun leur `TimelineView`, ils continuent de
    /// tourner. Deux captures prises au même délai après le lancement
    /// tombent au même instant du balayage (période ~9,7 s) ; c'est la seule
    /// façon de comparer deux tours de fouettage.
    static let tFige: Double? = number(after: "-stopT")

    /// `-stopOuvre` — LE VRAI FLOW (J3) : avec `-activeWorkout -skipAuth`,
    /// la racine lève `pauseOuverte` peu après la home. Déclaré ici pour que
    /// le drapeau vive avec le banc ; il est lu dans `WoopApp`.
    static let ouvre = CommandLine.arguments.contains("-stopOuvre")

    static func number(after flag: String) -> Double? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: flag), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return v
    }
}

private func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}
