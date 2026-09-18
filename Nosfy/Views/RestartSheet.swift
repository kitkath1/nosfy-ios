import SwiftUI
import AVFoundation
import UIKit

// MARK: - LES MESURES DE LA FAMILLE DES PANNEAUX-QUESTION

/// ⚠️ **LA FAMILLE, ENFIN ÉCRITE UNE FOIS** (26-08). Verdict de Kathryn : « le
/// composant Stop doit avoir EXACTEMENT les mêmes dimensions que l'overlay avec
/// la flamme — les deux doivent appartenir à la même famille UI ».
///
/// Ils n'y appartenaient pas, et c'était mécaniquement impossible : ils
/// portaient déjà la même forme, le même verre, la même poignée et le même
/// seuil de drag — copiés-collés — mais leurs HAUTEURS se calculaient sur deux
/// bases différentes (0,47 de l'écran PLEIN pour le stop, 0,52 du SAFE pour la
/// question), donc leurs cotes ne pouvaient coïncider sur aucun téléphone.
/// Tout ce qui suit est désormais lu, jamais recopié.
enum PanneauMesures {
    /// Coins hauts seuls — le bas appartient à l'écran (le CADRE FANTÔME est
    /// une faute déjà payée).
    static let rayonHaut: CGFloat = 34
    static let shape = UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: rayonHaut, bottomLeading: 0,
                           bottomTrailing: 0, topTrailing: rayonHaut),
        style: .continuous)

    /// Le drag de rangement : 12 pt de course avant qu'il n'existe (les
    /// boutons gardent leurs taps), 90 pt pour valider.
    static let dragMin: CGFloat = 12
    static let seuilRangement: CGFloat = 90

    /// ⚠️ **LA MARGE DE HALO N'EST PAS UN CONFORT, C'EST UNE MESURE.** La
    /// lumière de la carte des séries est peinte par `VerreGonfle` dans un
    /// rectangle **28 pt plus grand** que la carte, et posé APRÈS le
    /// `clipShape` : un panneau qui affleurerait pile le bord de la carte
    /// laisserait donc fuir 28 pt de halo au-dessus de lui. C'est la bande
    /// claire qu'on voit sur le screenshot de Kathryn.
    /// 44 et non 28 : la marge doit DÉPASSER le halo pour que le bord du
    /// panneau ne l'affleure pas — deux arêtes à 6 pt l'une de l'autre se
    /// lisent comme un défaut, pas comme une couverture. Et pas plus de 44 :
    /// au-delà le panneau mangerait le titre de l'exercice. Il recouvre LA
    /// CARTE, pas la page. Mesuré : bord du panneau à 450 pt, halo de la carte
    /// à 473, bas du titre à 426 — 23 pt de couverture, 24 pt d'air.
    static let margeHalo: CGFloat = 44

    /// L'ANCRE PAR DÉFAUT : le bord haut de la carte des séries, **mesuré**
    /// depuis le haut de la zone sûre (sonde numpy sur capture : arête montante
    /// la plus franche à y = 500,7 pt sur un écran de 852, safe top 59).
    ///
    /// ⚠️ **C'EST UNE MESURE, PAS UN CALCUL** — et le calcul est justement le
    /// piège payé ici. J'avais déduit l'ancre de `expandedHeader + 4` (= 367) :
    /// faux de 75 pt, parce que ce 367 vit dans le conteneur de l'overlay, qui
    /// commence lui-même sous les chips. Le panneau montait 168 pt trop haut et
    /// mangeait le titre de l'exercice. La règle du dépôt vaut aussi pour la
    /// géométrie : on mesure, on ne déduit pas.
    ///
    /// Elle ne sert que de REPLI : quand la page connaît la vraie position de
    /// sa carte (`seriesCardFrame`), c'est elle qui parle.
    static let ancreDepuisSafe: CGFloat = 442

    /// LA HAUTEUR ANCRÉE — celle des deux panneaux.
    ///
    /// ⚠️ **PLUS AUCUNE FRACTION.** L'ancienne `g.size.height * 0.52` était
    /// calculée sur la hauteur SANS zone sûre alors que le panneau est posé
    /// bord à bord : il manquait `0,52 × (haut + bas)` ≈ **48 pt** sur un
    /// iPhone de 852. Et surtout, une fraction ne peut pas RECOUVRIR quelque
    /// chose : le bord haut de la carte est à un offset FIXE (367 pt), donc
    /// le panneau dépassait ou pas selon le modèle d'écran — sur un 932 pt il
    /// manquait ~14 pt, et la carte se voyait derrière.
    ///
    /// ⚠️ **L'ANCRE EST EN ESPACE PHYSIQUE, ET LA HAUTEUR AUSSI.** Piège payé
    /// au premier essai : j'ai d'abord soustrait l'ancre de la hauteur SÛRE, et
    /// le panneau est monté 34 pt trop bas — la carte se voyait encore. Le bord
    /// haut de la carte est posé dans un conteneur plein cadre (`367` depuis le
    /// bord PHYSIQUE), pas depuis le haut de la zone sûre : mélanger les deux
    /// origines, c'est perdre l'inset du haut (59 pt sur un iPhone 16).
    ///
    /// - `hauteurPleine` : du bord physique haut au bord physique bas. Depuis
    ///   un `GeometryReader` qui RESPECTE la zone sûre (l'école du calendrier —
    ///   c'est son contenu qui l'ignore, jamais lui) :
    ///   `g.size.height + g.safeAreaInsets.top + g.safeAreaInsets.bottom`.
    /// - `ancre` : le bord haut PHYSIQUE de ce qu'il faut recouvrir.
    static func hauteurAncree(hauteurPleine: CGFloat,
                              ancre: CGFloat) -> CGFloat {
        // Le plancher : sur un très petit écran, le panneau garde de quoi
        // respirer plutôt que d'écraser sa flamme.
        max(380, hauteurPleine - ancre + margeHalo)
    }

    /// L'ancre de repli, quand rien n'a été mesuré (le panneau Stop, qui peut
    /// s'ouvrir depuis une page sans carte). Même entrée, même sortie : les
    /// deux panneaux de la famille ont alors LES MÊMES COTES au point près.
    static func ancreParDefaut(insetHaut: CGFloat) -> CGFloat {
        insetHaut + ancreDepuisSafe
    }
}

// MARK: - La pop-up de relance

/// La question de fin de série reprend la carte centrée des récompenses.
/// Les deux choix rendent la main au parcours existant après le fondu de sortie.
struct RestartPopup: View {
    var onLaunch: () -> Void = {}
    var onDismiss: () -> Void = {}

    @State private var visible = false
    @State private var enSortie = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase

    private static let forme = RoundedRectangle(cornerRadius: 36, style: .continuous)

    var body: some View {
        GeometryReader { g in
            let largeur = min(g.size.width * 0.80, 332)
            let hauteur = max(400, largeur * 1.32)
            ZStack {
                Color.black.opacity(visible ? 0.68 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { fermer(relancer: false) }
                    .accessibilityHidden(true)

                carte(largeur: largeur, hauteur: hauteur)
                    .scaleEffect(reduceMotion ? 1 : (visible ? 1 : 0.94))
                    .opacity(visible ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("restart-popup")
        .accessibilityAction(.escape) { fermer(relancer: false) }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15)
                          : .spring(response: 0.40, dampingFraction: 0.88)) {
                visible = true
            }
        }
    }

    private func carte(largeur: CGFloat, hauteur: CGFloat) -> some View {
        VStack(spacing: 0) {
            RestartFlameVideo(lecture: visible && !enSortie && phase == .active
                              && !reduceMotion && !ProtectionThermique.shared.ambianceAuRepos)
                .frame(width: largeur * 0.78, height: hauteur * 0.38)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .padding(.top, 12)

            Text(L("Encore une série ?", "One more set?"))
                .font(.inter(23, .semibold))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .accessibilityAddTraits(.isHeader)
            Text(L("À ton rythme.", "At your pace."))
                .font(.inter(14))
                .foregroundStyle(Color.inkMuted)
                .padding(.top, 8)

            Spacer(minLength: 20)

            Button { fermer(relancer: true) } label: {
                Text(L("Recommencer", "Start again"))
                    .font(.inter(16, .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        Color.clear.glassEffect(.clear.interactive(), in: Capsule())
                            .environment(\.colorScheme, .dark)
                    }
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("restart-launch")
            .padding(.horizontal, 28)

            Button { fermer(relancer: false) } label: {
                Text(L("Terminé", "Done"))
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("restart-dismiss")
            .padding(.top, 6)
            .padding(.bottom, 18)
        }
        .frame(width: largeur, height: hauteur)
        .background {
            ZStack {
                Self.forme.fill(.black)
                Color.clear.glassEffect(.regular.tint(.black.opacity(0.40)), in: Self.forme)
                    .environment(\.colorScheme, .dark)
                Self.forme.fill(Color.black.opacity(0.94))
                Self.forme.fill(RadialGradient(
                    colors: [Color(red: 0.34, green: 0.07, blue: 0.025).opacity(0.38), .clear],
                    center: .bottom, startRadius: 0, endRadius: largeur * 0.85))
            }
        }
        .clipShape(Self.forme)
        .overlay {
            Self.forme.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.20), .white.opacity(0.04)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            Button { fermer(relancer: false) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("Fermer", "Close"))
            .accessibilityIdentifier("restart-close")
            .padding(8)
        }
        .disabled(enSortie)
    }

    private func fermer(relancer: Bool) {
        guard !enSortie else { return }
        enSortie = true
        withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.24)) {
            visible = false
        } completion: {
            if relancer { onLaunch() } else { onDismiss() }
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
    var lecture: Bool

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
        if lecture { p.play() }
        return v
    }

    func updateUIView(_ v: FlameLayerView, context: Context) {
        guard let player = context.coordinator.player else { return }
        if lecture {
            if player.rate == 0 { player.play() }
        } else if player.rate != 0 {
            player.pause()
        }
    }

    static func dismantleUIView(_ v: FlameLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        coordinator.player?.removeAllItems()
        v.playerLayer.player = nil
        coordinator.looper = nil
        coordinator.player = nil
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

// MARK: - LA PILL DE GAIN, ET LE DÉCIDEUR DE FIN DE SÉRIE

/// LA PILL DES PIÈCES — le comportement PAR DÉFAUT de la fin d'une série
/// (`tools/rewards/CHANTIERS-UX.md` §3 : « les états Liquid Glass : +20, la
/// pièce, +20 · 140 cette séance. Micro-animation, AUCUNE interruption »).
///
/// ⚠️ **ELLE N'INTERROMPT RIEN, ET C'EST TOUTE SA RAISON D'ÊTRE.** Soixante
/// pour cent des séries ne méritent pas une pop-up : elles méritent qu'on
/// dise merci et qu'on s'efface. Elle descend du haut, tient deux secondes,
/// et repart — le doigt n'a jamais rien à faire, la fiche reste vivante
/// dessous, et le panneau « Recommencer ? » arrive derrière elle.
///
/// Le verre est le NATIF, et sa taille est CONSTANTE (l'entrée se joue par
/// `offset` + `opacity`) : un `glassEffect` redimensionné image par image
/// rend un blur plat définitif — la loi payée du dépôt.
struct PillGain: View {
    /// Ce que la série vient de rapporter.
    let gain: Int
    /// Le cumul de la séance — « ce que ça fait au total », la seule façon de
    /// donner du poids à un +20.
    let total: Int

    var body: some View {
        HStack(spacing: 9) {
            Image("piece-or-mini")
                .resizable().scaledToFit()
                .frame(width: 20, height: 20)
            Text("+\(gain)")
                .font(.inter(15, .semibold).monospacedDigit())
                .foregroundStyle(Color.inkPrimary)
            Text("·")
                .font(.inter(13))
                .foregroundStyle(Color(white: 1).opacity(0.28))
            Text("\(total) this session")
                .font(.inter(12.5).monospacedDigit())
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .frame(height: 44)
        .background {
            ZStack {
                Color.clear.glassEffect(
                    .regular.tint(Color.black.opacity(0.34)),
                    in: Capsule(style: .continuous))
                // Le noir AU-DESSUS du verre, sous l'encre — la loi de la
                // maison : le verre pour l'ambiance, le noir pour lire.
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.30))
                Capsule(style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [Color.white.opacity(0.18),
                                 Color.white.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plus \(gain) coins, \(total) this session")
    }
}

/// CE QUI SE PASSE APRÈS UNE SÉRIE.
///
/// ⚠️ **C'EST UNE PLACE, PAS UN MOTEUR** (26-08). Le verdict demande la chaîne
/// complète — pill / Moment / pop-up / vidéo — mais il demande AUSSI « pas de
/// backend, pas de nouvelles règles complexes ». Les deux tiennent ensemble à
/// une condition : câbler l'UI ENTIÈRE maintenant, et laisser le CHOIX derrière
/// une seule fonction que le backend remplacera sans toucher à un pixel.
///
/// La règle ci-dessous est donc délibérément bête et DÉTERMINISTE (une page qui
/// change d'avis à chaque relance ne se juge pas). Le vrai moteur — les faits,
/// les probabilités, l'atmosphère, l'IA contextuelle — vit dans
/// `tools/rewards/PLAN-REWARDS-BACKEND.md` et prendra cette place-ci.
enum IssueSerie: Equatable {
    /// Le cas normal (~60 %) : la pill, et rien d'autre.
    case pill(gain: Int, total: Int)
    /// Le cas contextuel : un MOMENT — une pop-up qui raconte un FAIT de la
    /// séance en cours. ⚠️ Le fait est VRAI (il vient de la fiche), il n'est
    /// pas inventé : c'est la seule chose qu'on puisse honnêtement raconter
    /// sans backend.
    case moment(titre: String, fait: String, style: RewardStyle)
    /// Le cas reward, et le cas RARE (avec sa vidéo).
    case reward(style: RewardStyle, video: String?)
}

/// LES RÈGLES DU RYTHME DES ANNONCES — lues au serveur (`regles_annonces()`,
/// reward_rules), les valeurs ci-dessous en REPLI hors ligne. Tranché le
/// 30-08 (PLAN-COFFRE-ANNONCES.md §4 M2, §5.2) : les rangs fixes 3 / 5 / 10,
/// puis un rang au hasard toutes les 5 à 8 séries ; 4 pop-ups par séance au
/// plus, une en pièces, une vidéo ; pour les rangs tirés, 3 séries ET 6 min
/// depuis la dernière. Changer le rythme = une ligne en base, pas une version.
struct ReglesAnnonces: Equatable {
    var rangsFixes: [Int] = [3, 5, 10]
    var rangVideo: Int = 10
    /// La vidéo du cas RARE (rang vidéo) — en base (`popup_video_rare`).
    var videoRare: String = "reward-rare"
    /// Le POOL des vidéos chauve-souris des autres pop-ups reward, où l'app tire
    /// AU HASARD (`popup_videos_reward`) — en base, comme le reste du barème.
    var videosReward: [String] = ["reward-piece-1", "reward-piece-2",
                                  "reward-piece-3", "reward-piece-4",
                                  "reward-piece-5", "reward-fire", "reward-lune"]
    var hasardApres: Int = 10
    var hasardEcartMin: Int = 5
    var hasardEcartMax: Int = 8
    var popupsMax: Int = 4
    var rewardMonetaireMax: Int = 1
    var videoMax: Int = 1
    var ecartMinSeries: Int = 3
    var ecartMinMinutes: Int = 6
    var ecartExigeLesDeux: Bool = true

    /// Une clé absente ou illisible garde le repli — jamais un zéro qui
    /// éteindrait les pop-ups par accident.
    static func lire(_ j: [String: Any]) -> ReglesAnnonces {
        var r = ReglesAnnonces()
        func n(_ k: String, _ v: inout Int) { if let x = j[k] as? Int, x >= 0 { v = x } }
        if let l = j["popup_rangs_fixes"] as? [Int], !l.isEmpty { r.rangsFixes = l.sorted() }
        n("popup_rang_video", &r.rangVideo)
        if let s = j["popup_video_rare"] as? String, !s.isEmpty { r.videoRare = s }
        if let l = j["popup_videos_reward"] as? [String], !l.isEmpty { r.videosReward = l }
        n("popup_hasard_apres", &r.hasardApres)
        n("popup_hasard_ecart_min", &r.hasardEcartMin)
        n("popup_hasard_ecart_max", &r.hasardEcartMax)
        n("popups_max_seance", &r.popupsMax)
        n("reward_monetaire_max_seance", &r.rewardMonetaireMax)
        n("video_max_seance", &r.videoMax)
        n("ecart_min_series", &r.ecartMinSeries)
        n("ecart_min_minutes", &r.ecartMinMinutes)
        if let b = j["ecart_exige_les_deux"] as? Bool { r.ecartExigeLesDeux = b }
        if r.hasardEcartMax < r.hasardEcartMin { r.hasardEcartMax = r.hasardEcartMin }
        return r
    }
}

/// LE DÉCIDEUR À BUDGET (15-09, étape 5 — le J4 du plan annonces).
///
/// ⚠️ Jusqu'ici il tirait TOUS les multiples de 3, 5 et 10 — sans hasard,
/// sans budget, sans horloge, avec trois chiffres en dur (le site :
/// « `regles_annonces()` sans appelant »). Il lit maintenant les règles du
/// serveur, tient un budget PAR SÉANCE (d'où `seance`, l'identité de la
/// séance ouverte — sans elle, le banc), et tire les rangs après le dernier
/// fixe de façon DÉTERMINISTE (un hachage de la séance et du rang : la même
/// séance rejouée donne les mêmes pop-ups, un banc est reproductible).
/// La pill de chaque série n'est pas une pop-up : elle ne compte pas.
enum DecideurSerie {
    /// Les règles courantes — le repli tant que le serveur n'a pas répondu.
    private(set) static var regles = ReglesAnnonces()
    private(set) static var reglesLues = false

    /// `regles_annonces()` — une fois par lancement, à l'apparition de la
    /// home (ProfilServeur.rafraichirPrenom) ; silencieuse en panne.
    static func chargerRegles() async {
        guard !reglesLues, !CommandLine.arguments.contains("-sansServeur") else { return }
        guard let jwt = try? await SupabaseSession.shared.token(),
              let j = try? await SacreServeur.reglesAnnonces(jwt: jwt) else { return }
        let r = ReglesAnnonces.lire(j)
        // Le seuil d'effort des widgets voyage dans la même réponse
        // (reward_rules entier) : un seul chiffre, celui de la base.
        let seuil = (j["seuil_effort_kmh"] as? NSNumber)?.doubleValue
        // Les planchers du barème cardio (16-09) : la quittance de Finish
        // dit « under 5 min · not paid » avec le chiffre de la base, jamais
        // un 5 en dur.
        let minTapis = (j["cardio_tapis_min_minutes"] as? NSNumber)?.doubleValue
        let minEscalier = (j["cardio_escalier_min_minutes"] as? NSNumber)?.doubleValue
        let hiitMinS = (j["cardio_hiit_effort_min_s"] as? NSNumber)?.doubleValue
        await MainActor.run {
            regles = r
            reglesLues = true
            if let seuil, seuil > 0 { SemaineStats.seuilEffort = seuil }
            if let minTapis, minTapis > 0 { ModeCardio.minMinutesTapis = minTapis }
            if let minEscalier, minEscalier > 0 { ModeCardio.minMinutesEscalier = minEscalier }
            if let hiitMinS, hiitMinS > 0 { ModeCardio.hiitEffortMinS = hiitMinS }
        }
        print("[annonces] regles_annonces() → rangs \(r.rangsFixes), vidéo \(r.rangVideo), "
              + "hasard \(r.hasardEcartMin)-\(r.hasardEcartMax) après \(r.hasardApres), "
              + "budget \(r.popupsMax)/\(r.rewardMonetaireMax)/\(r.videoMax), "
              + "écart \(r.ecartMinSeries) séries \(r.ecartExigeLesDeux ? "ET" : "OU") \(r.ecartMinMinutes) min, "
              + "rare \(r.videoRare), pool \(r.videosReward.count) vidéos \(r.videosReward)")
        print("[cardio] planchers du barème lus : tapis \(minTapis.map { "\($0)" } ?? "absent") min, "
              + "escalier \(minEscalier.map { "\($0)" } ?? "absent") min, seuil \(seuil.map { "\($0)" } ?? "absent") km/h, "
              + "effort HIIT \(hiitMinS.map { "\($0)" } ?? "absent") s")
    }

    /// Ce que la séance a déjà consommé.
    private struct EtatSeance {
        var cle: String
        var popups = 0
        var monetaires = 0
        var videos = 0
        var dernierRang: Int?
        var derniereDate: Date?
        /// Le prochain rang tiré (après le dernier fixe) ; nil = pas encore tiré.
        var prochainHasard: Int?
    }
    private static var etat = EtatSeance(cle: "")
    /// L'horloge de séance — remplacée par le banc (deux minutes par série).
    static var horloge: () -> Date = { Date() }

    /// Un hachage STABLE (FNV-1a) — `hashValue` change à chaque lancement.
    private static func stable(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for o in s.utf8 { h = (h ^ UInt64(o)) &* 0x100000001b3 }
        return h
    }

    /// Le prochain rang tiré après `apres` : + [écart min … écart max],
    /// déterministe pour (séance, rang de départ).
    private static func tirage(apres: Int, cle: String) -> Int {
        let r = regles
        let n = r.hasardEcartMax - r.hasardEcartMin + 1
        return apres + r.hasardEcartMin + Int(stable("\(cle)|\(apres)") % UInt64(max(n, 1)))
    }

    /// Une vidéo chauve-souris du POOL serveur, tirée AU HASARD mais DÉTERMINISTE
    /// (par séance + rang) — la même série rejouée donne la même vidéo, un banc
    /// est reproductible. Pool vide → nil, et l'écran retombe sur sa vidéo par
    /// défaut (ExerciseDetailView `videoNom ?? …` — le comportement d'avant le
    /// branchement) : jamais de pop-up sans header.
    private static func videoReward(cle: String, serie: Int) -> String? {
        let pool = regles.videosReward
        guard !pool.isEmpty else { return nil }
        return pool[Int(stable("\(cle)|vid|\(serie)") % UInt64(pool.count))]
    }

    /// `serie` : le rang de la série qu'on vient de finir (1-based).
    /// `reps`/`kilos` : ce qu'elle a réellement pesé. `seance` : l'identité
    /// de la séance ouverte (le budget est le sien).
    static func pour(serie: Int, gain: Int, total: Int,
                     reps: Int, kilos: Double, seance: UUID? = nil) -> IssueSerie {
        if !reglesLues { Task { await chargerRegles() } }
        let cle = seance?.uuidString ?? "banc"
        if etat.cle != cle { etat = EtatSeance(cle: cle) }
        let r = regles
        let pill = IssueSerie.pill(gain: gain, total: total)

        // Le rang est-il un rang de pop-up ?
        let fixe = r.rangsFixes.contains(serie)
        var tire = false
        if !fixe, serie > r.hasardApres {
            if etat.prochainHasard == nil {
                etat.prochainHasard = tirage(apres: max(r.hasardApres, etat.dernierRang ?? 0), cle: cle)
            }
            if let p = etat.prochainHasard, serie >= p {
                // l'écart depuis la dernière pop-up : séries ET/OU minutes
                let dSeries = serie - (etat.dernierRang ?? 0)
                let dMin = etat.derniereDate.map { horloge().timeIntervalSince($0) / 60 } ?? .infinity
                let okSeries = dSeries >= r.ecartMinSeries
                let okMin = dMin >= Double(r.ecartMinMinutes)
                let ecartTenu = r.ecartExigeLesDeux ? (okSeries && okMin) : (okSeries || okMin)
                if ecartTenu {
                    tire = true
                } else {
                    // pas encore : on réessaie à la série suivante
                    etat.prochainHasard = serie + 1
                }
            }
        }
        guard fixe || tire else { return pill }

        // Le budget de la séance.
        guard etat.popups < r.popupsMax else { return pill }
        let issue: IssueSerie
        if fixe, serie == r.rangVideo, etat.videos < r.videoMax {
            // Le dernier rang fixe : le cas RARE, avec sa vidéo — une par séance.
            issue = .reward(style: .fire, video: r.videoRare)
            etat.videos += 1
        } else if fixe, r.rangsFixes.firstIndex(of: serie) == 0 {
            // Le premier rang fixe : un MOMENT, et il dit quelque chose de VRAI.
            let poids = kilos.formatted(.number.precision(.fractionLength(0...1)))
            issue = .moment(titre: "Set \(serie)",
                            fait: L("\(reps) reps à \(poids) kg — déjà \(total) pièces.",
                                    "\(reps) reps at \(poids) kg — that's \(total) coins so far."),
                            style: .galet)
        } else if etat.monetaires < r.rewardMonetaireMax {
            // La pop-up de récompense en pièces — une par séance, avec une VIDÉO
            // chauve-souris tirée du pool serveur (au hasard, déterministe).
            issue = .reward(style: .halo, video: Self.videoReward(cle: cle, serie: serie))
            etat.monetaires += 1
        } else {
            // Le budget « pièces » est pris : un moment sans pièces.
            let poids = kilos.formatted(.number.precision(.fractionLength(0...1)))
            issue = .moment(titre: "Set \(serie)",
                            fait: L("\(reps) reps à \(poids) kg — déjà \(total) pièces.",
                                    "\(reps) reps at \(poids) kg — that's \(total) coins so far."),
                            style: .galet)
        }
        etat.popups += 1
        etat.dernierRang = serie
        etat.derniereDate = horloge()
        if tire { etat.prochainHasard = tirage(apres: serie, cle: cle) }
        return issue
    }

    /// Le banc : `-decideurBanc` — trente séries d'une séance imaginaire,
    /// les issues imprimées (journal `[annonces]`) : on doit lire 3, 5, 10,
    /// puis un rang tous les 5 à 8, jamais 6 / 9 / 12, quatre pop-ups au plus.
    static let banc = CommandLine.arguments.contains("-decideurBanc")
    static func jouerBanc() {
        let s = UUID()
        var ligne: [String] = []
        let depart = Date()
        var rang = 0
        horloge = { depart.addingTimeInterval(Double(rang) * 120) }   // 2 min par série
        defer { horloge = { Date() } }
        for n in 1 ... 30 {
            rang = n
            switch pour(serie: n, gain: 20, total: n * 20, reps: 10, kilos: 40, seance: s) {
            case .pill: break
            case .moment: ligne.append("\(n) moment")
            case .reward(_, let v): ligne.append("\(n) reward" + (v == nil ? "" : "+vidéo"))
            }
        }
        print("[annonces] banc 30 séries (\(reglesLues ? "règles serveur" : "repli")) → " + ligne.joined(separator: " · "))
        etat = EtatSeance(cle: "")
    }
}
