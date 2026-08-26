import SwiftUI

// MARK: - L'écran 2 : « Détails »

/// La page des détails (brief 26-08, maquette Frame …228) : le DÔME de
/// verre qui mange le bas de l'écran (macro native — « en 4K sinon ça va
/// faire caca »), l'éclair en haut à droite, le titre au registre SF de
/// la phrase, et la partition EXISTANTE — mais REPLIÉE PAR DÉFAUT :
/// `courant: ""` ne déplie rien à la naissance, le tap déplie (le
/// dépliage voyage déjà dans les données du ForEach, leçon payée).
struct StoryDetails: View {
    let session: StorySession
    let t: Double
    let now: Date
    let size: CGSize
    var paused: Bool = false
    /// Le cadre de la partition, remonté au chef d'orchestre — il y
    /// renonce à son verdict de tap.
    var onPartitionRect: (CGRect) -> Void = { _ in }

    @State private var contentH: CGFloat = 0

    var body: some View {
        // L'ARC DIAGONAL (tour 4, Frame …228) : la rotation est CUITE
        // dans le fichier (+22°), le calque n'a plus qu'à se poser —
        // 1,35 fois l'écran, ancré au bord bas. Et quand la partition
        // arrive, l'arc RECULE : son opacité tombe sur LA MÊME rampe
        // que l'entrée de la liste — une seule chose bouge à la fois.
        // v3 TOUR 5 : « la pills est beaucoup plus grande, il faut
        // vraiment un 4K » — 1,75·L (le verre mange ~55 % de l'écran
        // comme la Frame …228), fichier 2400×1820 sur-échantillonné
        // AVANT rotation : l'affichage (~2110 px @3x) est SOUS le
        // fichier, plus de bouillie possible.
        let mw = size.width * 1.75
        let mh = mw * 1820 / 2400
        let recul = StoryCine.sstep(0.35, 0.95, t)

        ZStack(alignment: .top) {
            Color.black

            CalqueVideo(nom: "story-macro-bas",
                        pose: "story-macro-bas-poster",
                        rate: paused ? 0 : 1)
                .frame(width: mw, height: mh)
                .frame(width: size.width, height: size.height,
                       alignment: .bottom)
                // La crête vers le bord droit, la fuite en bas-gauche —
                // la coupe du fichier reste hors écran à droite.
                .offset(x: size.width * 0.22)
                .opacity(StoryCine.sstep(0.05, 0.60, t)
                    * (1 - 0.55 * recul))

            // L'éclair, en haut à droite sur cette page (la maquette).
            CalqueVideo(nom: "story-eclair-loop",
                        pose: "story-eclair-loop-poster",
                        rate: paused ? 0 : 1)
                .frame(width: size.width * 0.30,
                       height: size.width * 0.30 * 1872 / 1016)
                .position(x: size.width * 0.80, y: size.height * 0.17)
                .blendMode(.plusLighter)
                .opacity(StoryCine.sstep(0.15, 0.65, t))

            VStack(alignment: .leading, spacing: 0) {
                Text("Détails")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color(white: 0.96))
                    .padding(.leading, 24)
                    .opacity(StoryCine.sstep(0.10, 0.55, t))
                    .offset(y: (1 - CGFloat(
                        StoryCine.sstep(0.10, 0.60, t))) * 10)

                if !session.groupes.isEmpty {
                    SlateListe(groupes: session.groupes,
                               courant: "",
                               basAir: 24,
                               onContentHeight: { contentH = $0 })
                        .equatable()
                        .frame(height: min(size.height * 0.56,
                                           contentH > 0 ? contentH
                                               : size.height * 0.56))
                        .opacity(StoryCine.sstep(0.35, 0.90, t))
                        .offset(y: (1 - CGFloat(
                            StoryCine.sstep(0.35, 0.95, t))) * 14)
                        .padding(.top, size.height * 0.075)
                        // La liste court PLUS LARGE que le titre : une
                        // ligne dépliée demande ~342 pt incompressibles,
                        // à 24 pt de marge elle était rognée.
                        .padding(.horizontal, 6)
                        .onGeometryChange(for: CGRect.self) {
                            $0.frame(in: .named("storyFlow"))
                        } action: { onPartitionRect($0) }
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 64)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - L'écran 3 : la « Story card »

/// La page de l'analyse (brief 26-08, maquette Frame …230) : le verre
/// macro qui entre par le flanc gauche, et LA STORY CARD — le variant
/// `.story` des cards rewards. Elle vit ICI en attendant que l'arbre se
/// calme : `RewardCard.swift` est en vol dans une session parallèle, on
/// ne le touche pas — la robe y déménagera au calme, à l'identique.
struct StoryAnalyse: View {
    let session: StorySession
    let t: Double
    let now: Date
    let size: CGSize
    var paused: Bool = false
    /// Le cadre de la card, remonté au chef d'orchestre — les gestes
    /// nés dedans (tilt, appui long) ne ferment pas la story et ne
    /// changent pas de page.
    var onPartitionRect: (CGRect) -> Void = { _ in }

    var body: some View {
        // LE BULBE ROND (tour 4, Frame …230) : le bas de la gélule vu de
        // près, le noir NATUREL gardé autour — le contour courbe du
        // verre est le VRAI bord de l'objet, LE MASQUE DE FONDU DU
        // TOUR 3 EST MORT (il écrasait ce contour). Posé en gros à
        // gauche, débordant hors écran par le haut-gauche, additif sur
        // le noir.
        let mw = size.width * 0.98
        let mh = mw * 1352 / 1500

        ZStack {
            Color.black

            CalqueVideo(nom: "story-macro-flanc",
                        pose: "story-macro-flanc-poster",
                        rate: paused ? 0 : 1)
                .frame(width: mw, height: mh)
                .position(x: size.width * 0.16, y: size.height * 0.22)
                .blendMode(.plusLighter)
                .opacity(StoryCine.sstep(0.05, 0.60, t))

            StoryCard(session: session, t: t, size: size,
                      paused: paused, onCardRect: onPartitionRect)
                .position(x: size.width * 0.52, y: size.height * 0.53)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - La robe `.story`

/// Fond noir comme les robes rewards, taille rewards, R36. Les STICKERS
/// du calendrier (les mêmes PNG, `WoopSticker.asset` — larges marges
/// transparentes, le glyphe fait ~45 % du canevas), qui BOUGENT — la
/// lévitation glaciale de l'école CalLab (±2 pt, horloges premières,
/// jamais de repeatForever : tout est fonction pure de `t`) — sous UN
/// HALO DE LUMIÈRE. Et l'analyse au registre Apple : SF bold, blanc et
/// gris mêlés — STATIQUE aujourd'hui, contextuelle plus tard (le
/// contrat des textes dynamiques du plan backend, §4 : l'IA choisira
/// les MOTS, jamais la typo).
struct StoryCard: View {
    let session: StorySession
    let t: Double
    let size: CGSize
    var paused: Bool = false
    /// Le cadre de la card, remonté au chef d'orchestre.
    var onCardRect: (CGRect) -> Void = { _ in }

    /// L'horloge murale de la poudre — un `@State` : la vue se
    /// ré-évalue à chaque image de `t`, la naissance ne bouge pas.
    @State private var naissance = Date()
    /// LE TILT AU DRAG (±11°, l'école RewardCard) — AUTORISÉ ici :
    /// cette card n'a pas de verre natif, la loi verre + rotation3D ne
    /// mord pas.
    @State private var pench: CGSize = .zero
    /// L'APPUI LONG : on la tient entre les doigts, elle se soulève.
    @GestureState private var tenue = false
    /// LE GYRO DOUX — la parallaxe différentielle au poignet.
    @ObservedObject private var motion = BacMotion.shared

    private static let forme = RoundedRectangle(cornerRadius: 36,
                                                style: .continuous)

    var body: some View {
        let l = min(size.width * 0.80, 332)
        let h = l * 1.32

        VStack(alignment: .leading, spacing: 0) {
            scene(l: l)
                .padding(.top, 26)
            texte
                .padding(.top, 18)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 30)
        .frame(width: l, height: h, alignment: .topLeading)
        // LA POUDRE DE DIAMANT — et elle OBÉIT à la lumière : les
        // grains brillent plus quand la nappe du spotlight passe.
        .overlay {
            PoudreStory(largeur: l, hauteur: h, naissance: naissance,
                        nappe: l / 2 + balaie(l: l))
                .opacity(StoryCine.sstep(0.55, 1.1, t))
        }
        .background {
            ZStack {
                Self.forme.fill(
                    LinearGradient(colors: [Color(white: 0.105),
                                            Color(white: 0.055)],
                                   startPoint: .top, endPoint: .bottom))
                // Une arête rasante OUVERTE — jamais un contour fermé.
                Self.forme.strokeBorder(
                    LinearGradient(
                        stops: [.init(color: .white.opacity(0.16),
                                      location: 0),
                                .init(color: .white.opacity(0.04),
                                      location: 0.38),
                                .init(color: .clear, location: 1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    lineWidth: 1)
            }
        }
        .clipShape(Self.forme)
        // L'appui long : la card se SOULÈVE entre les doigts.
        .scaleEffect(tenue ? 1.02 : 1.0)
        .animation(.spring(response: 0.30, dampingFraction: 0.72),
                   value: tenue)
        // LE TILT : le doigt penche l'OBJET.
        .rotation3DEffect(.degrees(Double(pench.width)),
                          axis: (x: 0, y: 1, z: 0))
        .rotation3DEffect(.degrees(Double(-pench.height)),
                          axis: (x: 1, y: 0, z: 0))
        .simultaneousGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { v in
                    pench = CGSize(
                        width: max(-11, min(11, v.translation.width / 9)),
                        height: max(-11, min(11, v.translation.height / 9)))
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.42,
                                          dampingFraction: 0.62)) {
                        pench = .zero
                    }
                })
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.24)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .updating($tenue) { _, s, _ in s = true })
        // L'entrée séquencée haptique : un grain RIGIDE par slam de
        // sticker (trois, jamais plus).
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.62),
                         trigger: beatPose)
        .opacity(StoryCine.sstep(0.25, 0.80, t))
        .offset(y: (1 - CGFloat(StoryCine.sstep(0.25, 0.85, t))) * 16)
        // Le cadre remonté au chef : les gestes nés dedans ne ferment
        // pas la story (les transforms ne changent pas le layout).
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named("storyFlow"))
        } action: { onCardRect($0) }
        .onAppear { BacMotion.shared.start() }
    }

    /// La course de la nappe du spotlight, autour du centre de la
    /// rangée des stickers.
    private func balaie(l: CGFloat) -> CGFloat {
        CGFloat(sin(t * 0.52)) * l * 0.33
    }

    /// Les slams déjà tombés — le trigger haptique de l'entrée.
    private var beatPose: Int {
        (0 ..< 3).filter { t >= 0.45 + Double($0) * 0.16 + 0.12 }.count
    }

    // MARK: Les stickers — DES PERFORMANCES, pas des décors

    /// Le mapping catégorie → sticker (contrat au §4 ter du plan
    /// backend) : bras = haut du corps, basket = cardio, chocolat =
    /// abdos, jambes = bas du corps, piscine = la nage (tranchés) ;
    /// abricot = fessiers, flamme = intensité (à confirmer). Ici
    /// l'heuristique LOCALE du banc, sur le titre de la séance — le
    /// vrai choix viendra des FAITS, au règlement.
    private var planche: [WoopSticker] {
        var s: [WoopSticker] = []
        let titre = session.title.lowercased()
        if titre.contains("haut") || titre.contains("upper")
            || titre.contains("push") || titre.contains("pull") {
            s.append(.bras)
        }
        // La nage AVANT le cardio générique : une séance piscine porte
        // sa goutte, pas la basket du tapis.
        if titre.contains("piscine") || titre.contains("nage")
            || titre.contains("natation") || titre.contains("swim")
            || titre.contains("crawl") {
            s.append(.piscine)
        }
        if titre.contains("cardio") || titre.contains("hiit")
            || titre.contains("course") || titre.contains("run") {
            s.append(.basket)
        }
        if titre.contains("abdo") || titre.contains("core") {
            s.append(.chocolat)
        }
        if titre.contains("jambe") || titre.contains("leg")
            || titre.contains("bas du corps") {
            s.append(.jambes)
        }
        if titre.contains("fessier") || titre.contains("glute") {
            s.append(.abricot)
        }
        // Le gabarit de secours — jamais une card sans stickers. La nage
        // fait exception : lui coller la basket ferait DEUX cardios sur
        // une seule séance, et un sticker est un fait (le contrat en
        // admet deux comme trois).
        if s.isEmpty { s = [.bras, .basket] }
        if s.count == 1, s[0] != .piscine {
            s.append(s[0] == .basket ? .abricot : .basket)
        }
        // L'intensité couronne la séance (à confirmer par Kathryn).
        s.append(.flamme)
        return Array(s.prefix(3))
    }

    private func scene(l: CGFloat) -> some View {
        let trio = planche
        let grand = l * 0.44
        let bal = balaie(l: l)
        // La rangée de la maquette …233 : l'arrière à gauche, le héros
        // au centre, la flamme collée à droite.
        let poses: [(x: CGFloat, deg: Double, z: Double)] = [
            (-0.52, -8, 0), (0.02, 4, 2), (0.56, 11, 1)
        ]

        return ZStack {
            // LE MOT GÉANT prend TOUT le header (verdict : « plus gros,
            // plus fondu, magnifique, très luxe ») — les stickers
            // MORDENT dessus, c'est le chevauchement qui fait la
            // profondeur.
            // Posé pour que sa TÊTE fonde dans la card — pas coupée net
            // par le bord (mesuré au sim).
            titre(l: l)
                .offset(x: CGFloat(motion.pench.width) * 3,
                        y: -grand * 0.16)

            // LE SPOTLIGHT : la nappe balaie la rangée et accroche les
            // stickers au passage.
            EllipticalGradient(
                colors: [Color(red: 1.0, green: 0.94, blue: 0.84)
                    .opacity(0.26), .clear],
                center: .center)
                .frame(width: grand * 1.8, height: grand * 1.2)
                .offset(x: bal, y: grand * 0.04)
                .blendMode(.plusLighter)

            ForEach(Array(trio.enumerated()), id: \.offset) { i, st in
                sticker(st, i: i, grand: grand,
                        x: poses[i].x, deg: poses[i].deg, bal: bal)
                    .zIndex(poses[i].z)
            }
        }
        .frame(height: grand * 1.04)
        .frame(maxWidth: .infinity)
    }

    /// Un sticker qui ARRIVE (le slam de pose de la pièce du calendrier :
    /// il tombe avec du poids, l'ombre s'écrase) puis qui VIT — la
    /// lévitation amplifiée, le balancement, la respiration, la
    /// PARALLAXE au poignet (l'avant plus que l'arrière) et l'ombre qui
    /// FUIT la lumière du spotlight. Tout en fonctions pures de `t`.
    private func sticker(_ st: WoopSticker, i: Int, grand: CGFloat,
                         x: CGFloat, deg: Double,
                         bal: CGFloat) -> some View {
        let a = 0.45 + Double(i) * 0.16
        let pose = StoryCine.sstep(a, a + 0.30, t)
        let chute = 1.55 - 0.55 * StoryCine.outLong(pose, 3.0)
        let phi = Double(i) * 2.1
        let leve = CGFloat(sin(t * 1.57 + phi)) * 3.0 * CGFloat(pose)
        let sway = sin(t * 0.71 + phi) * 3.5 * pose
        let souffle = 1 + 0.012 * CGFloat(sin(t * 1.9 + phi)) * CGFloat(pose)
        // Le gyro : la parallaxe DIFFÉRENTIELLE — la profondeur se joue
        // à plusieurs.
        let doigt = CGFloat(motion.pench.width) * (3.5 + CGFloat(i) * 1.6)

        return ZStack {
            // L'ombre vraie — elle s'écrase à la pose, respire ensuite,
            // et s'allonge à l'OPPOSÉ de la nappe : une seule lumière
            // dans la scène, tout lui obéit.
            Ellipse()
                .fill(Color.black.opacity(0.50 * pose
                    - Double(leve) * 0.03))
                .frame(width: grand * 0.44 + leve * 3 + abs(bal) * 0.05,
                       height: grand * 0.10)
                .blur(radius: 8)
                .offset(x: -bal * 0.16, y: grand * 0.30)
            Image(st.asset)
                .resizable()
                .scaledToFit()
                .frame(width: grand, height: grand)
                .offset(y: -leve)
        }
        .rotationEffect(.degrees(deg + sway))
        .scaleEffect(CGFloat(chute) * souffle)
        .opacity(min(1, pose * 2.5))
        .offset(x: x * grand + doigt)
    }

    // MARK: Le mot géant

    /// LA bigWord — une TABLE de tiers de performance (contrat §4 ter
    /// du plan backend), jamais un choix libre.
    private var bigWord: String {
        let v = faits.volume
        if v >= 6000 { return "KING" }
        if v >= 3000 { return "BOSS" }
        return "SOLID"
    }

    /// LE MOT EN ARGENT, tout le header — l'école TexteGeant de la robe
    /// welcome : l'encre en dégradé riche, la dissolution à DEUX masques
    /// (les flancs ET le pied), et le GLINT qui le traverse par
    /// instants — un événement, jamais en continu.
    private func titre(l: CGFloat) -> some View {
        let mot = bigWord
        let corps = l * 1.30 / CGFloat(max(3, mot.count))
        // ×1,55 : le mot déborde des flancs (~20 % de chaque côté) mais
        // reste DEVINABLE — à ×2 il ne montrait plus que son ventre.
        let glyphe = Text(mot)
            .font(.system(size: corps * 1.55, weight: .black))
            .tracking(-corps * 0.04)
            .fixedSize()
        return ZStack {
            glyphe
                .foregroundStyle(LinearGradient(
                    colors: [Color(white: 0.94), Color(white: 0.26)],
                    startPoint: .top, endPoint: .bottom))
            // LA LUMIÈRE DIFFUSE, à la place de la lame : elle ne
            // traverse plus, elle NAÎT PARTOUT dans le mot (verdict :
            // « le balayage sur la police c'est trop cheap »).
            nappes(l: l)
                .mask { glyphe }
                .blendMode(.plusLighter)
        }
        .frame(width: l)
        // Les flancs fondent — jamais une coupe franche. Le fondu de
        // GAUCHE commence PLUS TÔT (verdict : « il commence trop
        // loin ») : le mot sort de la nuit au lieu d'être posé dessus.
        .mask {
            LinearGradient(
                stops: [.init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.35),
                              location: 0.16),
                        .init(color: .white, location: 0.42),
                        .init(color: .white, location: 0.86),
                        .init(color: .clear, location: 1)],
                startPoint: .leading, endPoint: .trailing)
        }
        // Le fondu majestueux : plein en haut du mot, mort aux deux
        // tiers.
        .mask {
            LinearGradient(
                stops: [.init(color: .white, location: 0),
                        .init(color: .white.opacity(0.72),
                              location: 0.40),
                        .init(color: .white.opacity(0.20),
                              location: 0.70),
                        .init(color: .clear, location: 0.94)],
                startPoint: .top, endPoint: .bottom)
        }
        .opacity(0.52 * StoryCine.sstep(0.35, 0.90, t))
    }

    /// LA LUMIÈRE DIFFUSE DU MOT — sept nappes molles, chacune sur SA
    /// période première et SA phase (hash déterministe) : elles
    /// s'allument et meurent à des endroits différents du mot, sans
    /// jamais former une lame qui traverse. Une seule brille fort à la
    /// fois, jamais au même endroit — c'est l'irrégularité qui fait le
    /// métal ; un balayage régulier fait le sticker.
    private func nappes(l: CGFloat) -> some View {
        let periodes: [Double] = [3.7, 5.3, 7.1, 4.3, 6.7, 9.1, 5.9]
        return ZStack {
            ForEach(0 ..< 7, id: \.self) { i in
                let h1 = Self.hash(i, 1)
                let h2 = Self.hash(i, 2)
                let h3 = Self.hash(i, 3)
                // Le battement : une bosse étroite dans la période — la
                // nappe est éteinte la plupart du temps.
                let u = (t / periodes[i] + h1)
                    .truncatingRemainder(dividingBy: 1)
                let bosse = pow(max(0, sin(.pi * u)), 6.0)
                // Elle DÉRIVE à peine pendant qu'elle brille : une
                // lumière qui vit, pas un objet qui passe.
                let derive = CGFloat(sin(t * (0.21 + 0.11 * h2) + h3 * 6.28))
                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.52), .clear],
                        center: .center, startRadius: 0,
                        endRadius: l * CGFloat(0.11 + 0.09 * h2)))
                    .frame(width: l * CGFloat(0.26 + 0.22 * h2),
                           height: l * CGFloat(0.16 + 0.14 * h3))
                    .offset(x: l * (CGFloat(h1) - 0.5) * 1.10
                            + derive * l * 0.03,
                            y: l * (CGFloat(h3) - 0.5) * 0.34)
                    .opacity(bosse)
            }
        }
        .blur(radius: 6)
        .opacity(StoryCine.sstep(1.2, 2.2, t))
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }

    // MARK: Les faits locaux

    /// La meilleure série (l'exo du CATALOGUE + la charge) et le volume
    /// total — les faits v1, calculés du `StorySession`. Le fact engine
    /// serveur les remplacera avec ses fenêtres (contrat §4 ter).
    private var faits: (exo: String, kg: Int, volume: Int) {
        var exo = "the bar"; var kg = 0; var volume = 0
        for g in session.groupes {
            for r in g.rows {
                volume += r.reps * Int(r.kilos)
                if Int(r.kilos) > kg {
                    kg = Int(r.kilos)
                    exo = g.exercise.name
                }
            }
        }
        return (Self.court(exo), kg, volume)
    }

    /// Le nom du catalogue, TRONQUÉ au contrat (≤ 14 signes, au mot —
    /// le client tronque, il ne rétrécit jamais). Et jamais un
    /// MOT-OUTIL en bout de ligne : « crunch à la, » n'est pas une
    /// phrase (mesuré au sim).
    private static func court(_ nom: String) -> String {
        let outils: Set<String> = ["à", "a", "la", "le", "les", "de",
                                   "du", "des", "en", "the", "of", "on",
                                   "au", "aux"]
        var mots: [String] = []
        var total = 0
        for mot in nom.split(separator: " ") {
            let ajout = mot.count + (mots.isEmpty ? 0 : 1)
            if total + ajout > 14 { break }
            mots.append(String(mot))
            total += ajout
        }
        while let dernier = mots.last,
              outils.contains(dernier.lowercased()) {
            mots.removeLast()
        }
        if mots.isEmpty { return String(nom.prefix(14)).lowercased() }
        return mots.joined(separator: " ").lowercased()
    }

    /// LES SIX PHRASES VRAIES — EXACTEMENT 6 lignes (le contrat §4 ter),
    /// les nombres RECOPIÉS des faits, le nom du CATALOGUE dedans.
    /// Gabarits par catégorie dominante — l'IA remplira LE MÊME MOULE.
    private var phrases: [[(String, Bool)]] {
        let f = faits
        let minutes = session.minutes
        let series = session.series
        switch planche.first ?? .bras {
        case .basket:
            return [[("Cardio came in.", false)],
                    [("\(minutes) min", false), (" on the clock,", true)],
                    [("heart up high,", true)],
                    [("\(series) rounds", false), (" done.", true)],
                    [("no seat taken.", true)],
                    [("Breathe. Repeat.", false)]]
        case .chocolat:
            return [[("Core day locked.", false)],
                    [("\(series) sets", false), (" of core,", true)],
                    [("\(f.exo),", false)],
                    [("steel underneath,", true)],
                    [("in \(minutes) minutes.", true)],
                    [("Hold the line.", false)]]
        case .piscine:
            return [[("Water day done.", false)],
                    [("\(minutes) min", false), (" in the lane,", true)],
                    [("stroke after stroke,", true)],
                    [("\(series) sets", false), (" logged.", true)],
                    [("lungs wide open.", true)],
                    [("Push off again.", false)]]
        case .jambes:
            return [[("Leg day loaded.", false)],
                    [("\(f.kg) kg", false), (" on", true)],
                    [("\(f.exo),", false)],
                    [("deep and low,", true)],
                    [("\(series) sets, \(minutes) min.", true)],
                    [("Walk it off.", false)]]
        case .abricot:
            return [[("Glutes on fire.", false)],
                    [("\(f.kg) kg", false), (" on", true)],
                    [("\(f.exo),", false)],
                    [("hips driving up,", true)],
                    [("\(series) sets, \(minutes) min.", true)],
                    [("Squeeze and hold.", false)]]
        default:
            return [[("Big push day.", false)],
                    [("\(f.kg) kg", false), (" on", true)],
                    [("\(f.exo),", false)],
                    [("your best set,", true)],
                    [("\(series) sets in \(minutes) min.", true)],
                    [("Keep pressing.", false)]]
        }
    }

    // MARK: L'analyse

    private var texte: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(phrases.enumerated()), id: \.offset) { i, mots in
                let a = 0.70 + Double(i) * 0.10
                // LA LECTURE QUI S'ALLUME : chaque ligne grise s'éclaire
                // à SON tour, puis se rendort — le texte se lit tout
                // seul (fonction pure de t, le piège des rampes sous
                // withAnimation ne mord pas ici).
                let lit = 1.9 + Double(i) * 0.55
                let actif = StoryCine.sstep(lit, lit + 0.35, t)
                    * (1 - StoryCine.sstep(lit + 0.95, lit + 1.30, t))
                let gris = Color(white: 0.48 + 0.34 * actif)
                let blanc = Color(white: 0.94)
                mots.reduce(Text("")) { acc, m in
                    acc + Text(m.0)
                        .foregroundColor(m.1 ? gris : blanc)
                }
                .font(.system(size: 25, weight: .bold))
                .opacity(StoryCine.sstep(a, a + 0.45, t))
            }
        }
    }
}

// MARK: - La poudre de la story

/// LA POUDRE DE DIAMANT — la recette de `PoudreDiamant` (RewardCard),
/// copiée à l'identique parce que l'originale est `private` et que son
/// fichier est en vol dans une session parallèle : Canvas sous
/// TimelineView 30 Hz, grains-étoiles déterministes par hash, l'additif
/// demandé AU CONTEXTE, jamais à la vue. Le jour où l'arbre est calme,
/// l'une des deux meurt.
private struct PoudreStory: View {
    var largeur: CGFloat
    var hauteur: CGFloat
    var naissance: Date
    /// La position x de la nappe du spotlight, dans le repère de la
    /// card : les grains BRILLENT quand la lumière passe sur eux —
    /// « les paillettes ne vivent que dans la lumière ».
    var nappe: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let grains = 58

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(naissance)
            Canvas { ctx, _ in
                ctx.blendMode = .plusLighter
                for i in 0 ..< Self.grains {
                    let vie = 2.8 + 3.2 * Self.hash(i, 2)
                    let cyc = (t / vie + Self.hash(i, 5))
                        .truncatingRemainder(dividingBy: 1)
                    let cx = largeur / 2
                        + (Self.hash(i, 1) - 0.5) * largeur * 0.86
                    // Ici la poudre vit dans le TIERS HAUT — la lumière
                    // du spotlight des stickers, pas la fumée du bas.
                    let base = 0.10 + 0.34 * Self.hash(i, 3)
                    let cy = hauteur * base
                    let x = cx + sin(t * (0.35 + 0.5 * Self.hash(i, 8))
                                     + Self.hash(i, 9) * 6.28) * 8
                    let y = cy - CGFloat(cyc) * hauteur * 0.16
                    let s = sin(.pi * cyc)
                    let tw = 0.5 + 0.5 * sin(t * (7 + 12 * Self.hash(i, 4))
                                             + Self.hash(i, 6) * 6.28)
                    let d = Double(abs(x - nappe))
                    let sigma = Double(largeur) * 0.20
                    let lumiere = 0.45
                        + 0.55 * exp(-d * d / (2 * sigma * sigma))
                    let a = s * s * (0.18 + 0.82 * tw * tw * tw) * 0.8
                        * lumiere
                    guard a > 0.02 else { continue }
                    let r = CGFloat(0.6 + 1.5 * Self.hash(i, 7))
                    let c = Self.hash(i, 10) < 0.4
                        ? Color.white
                        : Color(red: 0.90, green: 0.95, blue: 1.00)
                    var etoile = Path()
                    etoile.move(to: CGPoint(x: -r, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: -r * 0.22))
                    etoile.addLine(to: CGPoint(x: r, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: r * 0.22))
                    etoile.closeSubpath()
                    etoile.move(to: CGPoint(x: 0, y: -r))
                    etoile.addLine(to: CGPoint(x: r * 0.22, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: r))
                    etoile.addLine(to: CGPoint(x: -r * 0.22, y: 0))
                    etoile.closeSubpath()
                    ctx.fill(etoile.applying(
                        CGAffineTransform(translationX: x, y: y)
                            .rotated(by: (Self.hash(i, 11) - 0.5) * 0.9)),
                             with: .color(c.opacity(a * 0.85)))
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 0.45, y: y - 0.45,
                                               width: 0.9, height: 0.9)),
                        with: .color(Color.white.opacity(a * 0.9)))
                }
            }
        }
        .allowsHitTesting(false)
        .frame(width: largeur, height: hauteur)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }
}
