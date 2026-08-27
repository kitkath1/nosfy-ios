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
    /// LE DÉPLIAGE VIT CHEZ L'HÔTE — voir la note de `SlateListe` : dans
    /// une vue montée en `.equatable()`, un `@State` interne est
    /// INVISIBLE à la comparaison, et le tap cesse d'ouvrir.
    @State private var deplies: Set<String> = []

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
                               onContentHeight: { contentH = $0 },
                               deplies: $deplies)
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
    /// Le GAIN (verdict TOP : « il manque la poudre de diamant » — elle
    /// y était, imperceptible). 1 = la story 3, inchangée.
    var gain: Double = 1

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
                        * lumiere * gain
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

// MARK: - La page TOP SESSION (l'exception)

/// La partition de la page d'exception — tout depuis la coupe de la
/// verrière (t = 4,4 sur la page), fonctions pures de `t`.
enum TopCine {
    /// Le reflux de la pills énorme vers son flanc droit.
    static let poseFor = 0.9
    /// LA PLONGÉE de la card : elle n'apparaît pas, elle ATTERRIT.
    static let cardAt = 5.0, cardFor = 0.85
    /// Le SLAM — l'instant où l'échelle touche 1.
    static var slamAt: Double { cardAt + cardFor }
    /// Le halo de page S'ALLUME sur l'impact, puis respire.
    static let haloFor = 0.55
    /// La mini-card néon arrive EN RETARD — le retard fait le wahou.
    static let miniAt = 6.35, miniFor = 0.45
    static let sousAt = 6.15
}

/// LA PAGE « TOP SESSION » (26-08 soir, plan
/// ../rewards/PLAN-TOP-SESSION.md) : le layout Welcome v2 SANS la
/// chauve-souris — la pastille porte LA PAILLETTE DU SPORT, le texte
/// géant passe au ROUGE, tout le contour de l'écran s'embrase
/// (rouge → blanc pur), une pills ÉNORME entre par la droite, et la
/// mini-card au néon VERT dépasse de la card avec LA stat de
/// l'exception. C'est la première vue de la story les grands jours.
struct StoryTopScene: View {
    let session: StorySession
    let sport: TopSport
    let t: Double
    let size: CGSize
    var paused: Bool = false

    /// L'horloge murale de la poudre (l'école PoudreStory).
    @State private var naissance = Date()

    var body: some View {
        ZStack {
            Color.black

            pills
            halo
            carte
            miniNeon
        }
        .frame(width: size.width, height: size.height)
        // LE SLAM de l'atterrissage — l'haptique la plus lourde : la
        // card se pose, le halo s'allume dessus.
        .onChange(of: t >= TopCine.slamAt) { _, pose in
            if pose { SwapFeedback.shared.slam() }
        }
        // Le grain DOUX à la pose de la pastille (chirurgien D16) —
        // trois événements, trois textures : le slam, la pose, le tick.
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.45),
                         trigger: t >= TopCine.slamAt + 0.40)
    }

    // MARK: La pills énorme

    /// Le gabarit au repos : 1,5 écran de large, le corps qui SORT par
    /// la droite. Fichier `story-pilule-top` (2648×1664, définition
    /// native — l'école du « vrai 4K »).
    private var pillsRepos: CGRect {
        let w = size.width * 1.5
        let h = w * 1664 / 2648
        return CGRect(x: size.width - w * 0.72, y: size.height * 0.34 - h / 2,
                      width: w, height: h)
    }

    private var pills: some View {
        // Le reflux depuis le plein cadre — la même école que le résumé :
        // transform seulement, arrivée à vitesse nulle.
        let u = CGFloat(StoryCine.outLong(
            min(max((t - EndedCine.cut) / TopCine.poseFor, 0), 1)))
        let repos = pillsRepos
        let k0 = size.height * 1.15 / repos.height
        let k = k0 + (1 - k0) * u
        let centre = CGPoint(x: repos.midX, y: repos.midY)
        let dx = (size.width / 2 - centre.x) * (1 - u)
        let dy = (size.height / 2 - centre.y) * (1 - u)
        return CalqueVideo(nom: "story-pilule-top",
                           pose: "story-pilule-top-poster",
                           rate: paused ? 0 : 1)
            .frame(width: repos.width, height: repos.height)
            .scaleEffect(k, anchor: .center)
            .offset(x: dx, y: dy)
            .position(x: centre.x, y: centre.y)
            .blendMode(.plusLighter)
    }

    // MARK: Le halo de page

    /// TOUT le contour s'embrase : un lit ROUGE large et flouté vers
    /// l'intérieur + une arête BLANC PUR fine — deux couches, jamais un
    /// contour fermé d'épaisseur égale. Il s'allume SUR le slam et
    /// respire ensuite. ⚠️ Anti-brun : le rouge est celui du feu de la
    /// maison (R = 1, le vert désaturé), jamais un rouge neuf.
    private var halo: some View {
        let allume = StoryCine.sstep(TopCine.slamAt - 0.05,
                                     TopCine.slamAt + TopCine.haloFor, t)
        let souffle = t <= TopCine.slamAt ? 1.0
            : 0.86 + 0.14 * sin((t - TopCine.slamAt) * 0.9)
        let force = allume * souffle
        // L'AMORCE ÉLECTRIQUE (chirurgien C13) : à l'impact, l'arête
        // s'allume par DEUX à-coups — 60 ms d'extinction entre les
        // deux — avant de tenir. Un néon réel s'amorce, il ne fade pas.
        let s1 = TopCine.slamAt
        let coup1 = StoryCine.sstep(s1 - 0.02, s1 + 0.02, t)
            * (1 - StoryCine.sstep(s1 + 0.05, s1 + 0.08, t))
        let coup2 = StoryCine.sstep(s1 + 0.11, s1 + 0.15, t)
        let flash = max(coup1, coup2 * (1 - StoryCine.sstep(
            s1 + 0.30, s1 + 0.55, t)))
        let rouge = Color(red: 1.0, green: 0.20, blue: 0.05)
        let forme = RoundedRectangle(cornerRadius: 52, style: .continuous)
        return ZStack {
            forme
                .strokeBorder(rouge.opacity(0.55 * force), lineWidth: 30)
                .blur(radius: 26)
            forme
                .strokeBorder(rouge.opacity(0.35 * force), lineWidth: 10)
                .blur(radius: 8)
            // L'arête blanc pur — « montrer que c'est important ».
            // L'arête blanc pur — et son FLASH à l'impact : elle
            // s'allume au-delà d'elle-même pendant 0,25 s puis se pose.
            forme
                .strokeBorder(Color.white.opacity(0.85 * force
                    + 0.6 * flash), lineWidth: 2.2 + 2.4 * flash)
                .blur(radius: 1.1 + flash)
        }
        .padding(2)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: La card

    private static let forme = RoundedRectangle(cornerRadius: 36,
                                                style: .continuous)

    private var carte: some View {
        let l = min(size.width * 0.80, 332)
        let h = l * 1.32
        // LA PLONGÉE : elle vient de l'avant — grande, floue — et se
        // pose. Le flou se résout avec l'échelle (softBlur : sous
        // 0,2 pt le modificateur est retiré de l'arbre).
        let u = StoryCine.sstep(TopCine.cardAt,
                                TopCine.cardAt + TopCine.cardFor, t)
        let k = 1.6 - 0.6 * CGFloat(StoryCine.outLong(u, 3.0))
        return ZStack {
            // LA PASTILLE, AU CENTRE (verdict §9) — plus petite, un
            // médaillon qui mord la traîne du mot.
            pastille(l: l)
            // DEUX LIGNES SEULEMENT, dans le tiers bas, assises sur la
            // fin du fondu du mot (le kicker « BEST OF THE WEEK » est
            // MORT — c'était la ligne de trop). Le titre prend LA
            // taille de la story 3, pour la consistance.
            VStack(spacing: 6) {
                Text(sport.titre)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color(white: 0.94))
                    .opacity(StoryCine.sstep(TopCine.sousAt - 0.15,
                                             TopCine.sousAt + 0.25, t))
                Text(sport.sousTexte)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(white: 0.55))
                    .opacity(StoryCine.sstep(TopCine.sousAt,
                                             TopCine.sousAt + 0.4, t))
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 34)
        }
        .frame(width: l, height: h)
        // LA POUDRE DE DIAMANT — le micro-détail des grandes robes :
        // elle vit dans la lumière de la pastille.
        .overlay {
            PoudreStory(largeur: l, hauteur: h, naissance: naissance,
                        nappe: l / 2, gain: 1.7)
                .opacity(StoryCine.sstep(TopCine.slamAt,
                                         TopCine.slamAt + 0.6, t))
        }
        .background {
            ZStack {
                Self.forme.fill(
                    LinearGradient(colors: [Color(white: 0.105),
                                            Color(white: 0.05)],
                                   startPoint: .top, endPoint: .bottom))
                texteGeant(l: l, h: h)
                // Le FIL ROUGE sous l'arête — l'écho du halo de page,
                // discret : une arête ouverte, jamais un contour fermé.
                Self.forme.strokeBorder(
                    LinearGradient(
                        stops: [.init(color: Color(red: 1.0, green: 0.30,
                                                   blue: 0.10)
                                          .opacity(0.35), location: 0),
                                .init(color: .clear, location: 0.55)],
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading),
                    lineWidth: 1.4)
                // LA CRÊTE ANGULAIRE (chirurgien A1) : une lampe FIXE
                // dans la pièce dont la crête glisse de ±4° sur 11 s —
                // l'objet respire sous la lumière, rien ne le traverse.
                Self.forme.strokeBorder(
                    AngularGradient(
                        stops: [.init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.30),
                                      location: 0.115),
                                .init(color: .clear, location: 0.24),
                                .init(color: .clear, location: 1)],
                        center: .center,
                        angle: .degrees(-56 + 4 * sin(t * 0.571))),
                    lineWidth: 1.2)
            }
        }
        .clipShape(Self.forme)
        // LE SETTLE À MASSE (chirurgien C8) : un seul rebond MORT,
        // sur-amorti — l'objet pèse.
        .scaleEffect(k * (t <= TopCine.slamAt ? 1
            : 1 - 0.006 * CGFloat(exp(-(t - TopCine.slamAt) / 0.16)
                * sin((t - TopCine.slamAt) * 15))))
        .modifier(SoftBlur(radius: (1 - CGFloat(u)) * 10))
        .opacity(min(1, u * 2.2))
        .position(x: size.width * 0.50, y: size.height * 0.55)
    }

    /// LE TEXTE GÉANT, en ROUGE — les deux lignes du contrat bigLines,
    /// empilées derrière la pastille, fondues (l'école du mot argent de
    /// la story card, recolorée au feu de la maison).
    private func texteGeant(l: CGFloat, h: CGFloat) -> some View {
        // LE MOT EN HAUT (layout §9) : la tête pleine au sommet de la
        // card, la traîne qui FOND EN DESCENDANT — « le texte va dans
        // le fondu de la card en bas ». La lame du glint est MORTE
        // (« les balayages blancs, c'est trop cheap ») : la lumière du
        // mot est DIFFUSE, elle naît partout dedans — la même recette
        // que le mot argent de la story 3, pour la consistance.
        let lignes = sport.bigLines
        let corps = l * 1.16 / CGFloat(max(3, lignes.map(\.count).max() ?? 3))
        let mots = VStack(spacing: -corps * 0.35) {
            ForEach(Array(lignes.enumerated()), id: \.offset) { _, mot in
                Text(mot)
                    .font(.system(size: corps * 1.55, weight: .black))
                    .tracking(-corps * 0.04)
                    .fixedSize()
            }
        }
        return ZStack {
            mots
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 1.0, green: 0.34, blue: 0.10),
                             Color(red: 0.62, green: 0.05, blue: 0.02)],
                    startPoint: .top, endPoint: .bottom))
            nappesTop(l: l)
                .mask { mots }
                .blendMode(.plusLighter)
        }
        .frame(width: l)
        // « Plus fondu sur le côté et le bottom » (verdict) : les
        // flancs mangent 18 % chacun, le pied meurt dès 0,86.
        .mask {
            LinearGradient(
                stops: [.init(color: .clear, location: 0),
                        .init(color: .white, location: 0.18),
                        .init(color: .white, location: 0.82),
                        .init(color: .clear, location: 1)],
                startPoint: .leading, endPoint: .trailing)
        }
        .mask {
            LinearGradient(
                stops: [.init(color: .white, location: 0),
                        .init(color: .white.opacity(0.66), location: 0.44),
                        .init(color: .white.opacity(0.16), location: 0.70),
                        .init(color: .clear, location: 0.88)],
                startPoint: .top, endPoint: .bottom)
        }
        .opacity(0.60 * StoryCine.sstep(TopCine.cardAt + 0.25,
                                        TopCine.cardAt + 0.85, t))
        .frame(width: l, height: h, alignment: .top)
        // « Le texte un peu remonté » : collé au sommet, plus de coussin.
        .padding(.top, 0)
        .offset(y: -6)
    }

    /// La lumière DIFFUSE du mot — la recette des nappes de la story 3
    /// (périodes premières, bosses étroites, dérive infime), calée sur
    /// l'arrivée de la card.
    private func nappesTop(l: CGFloat) -> some View {
        let periodes: [Double] = [3.7, 5.3, 7.1, 4.3, 6.7, 9.1, 5.9]
        return ZStack {
            ForEach(0 ..< 7, id: \.self) { i in
                let h1 = Self.hashTop(i, 1)
                let h2 = Self.hashTop(i, 2)
                let h3 = Self.hashTop(i, 3)
                let u = (t / periodes[i] + h1)
                    .truncatingRemainder(dividingBy: 1)
                let bosse = pow(max(0, sin(.pi * u)), 6.0)
                let derive = CGFloat(sin(t * (0.21 + 0.11 * h2)
                    + h3 * 6.28))
                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.55), .clear],
                        center: .center, startRadius: 0,
                        endRadius: l * CGFloat(0.13 + 0.10 * h2)))
                    .frame(width: l * CGFloat(0.30 + 0.24 * h2),
                           height: l * CGFloat(0.24 + 0.18 * h3))
                    .offset(x: l * (CGFloat(h1) - 0.5) * 1.05
                            + derive * l * 0.03,
                            y: l * (CGFloat(h3) - 0.5) * 0.85)
                    .opacity(bosse)
            }
        }
        .blur(radius: 6)
        .opacity(StoryCine.sstep(TopCine.slamAt, TopCine.slamAt + 0.8, t))
    }

    private static func hashTop(_ i: Int, _ k: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return v - floor(v)
    }

    /// LA PASTILLE-PAILLETTE — la grammaire de `PastilleLuneReward`,
    /// recopiée en fonctions pures de `t` (l'originale est private dans
    /// RewardCard et porte sa propre horloge — ici la page EST
    /// l'horloge) : une seule image, la lumière est un DÉGRADÉ balayé
    /// posé sur sa forme, le halo derrière, flottement à trois horloges
    /// premières, JAMAIS de rotation 3D (le verdict de la card qui
    /// laguait).
    private func pastille(l: CGFloat) -> some View {
        let cote = l * 0.34
        // TOUT EST PRÉ-TYPÉ (la loi du type-checker, payée une fois de
        // plus ici même) : le pulse du catch-light se calcule AVANT le
        // builder.
        let vif: Double = Double(JaugeVent.flicker(Float(t), phase: 2.3))
        let opCatch: Double = 0.24 + 0.06 * vif
        let rayonCatch: CGFloat = cote * 0.22
        // ⚠️ LE BUG DE NAISSANCE (verdict Kathryn) : la pastille
        // naissait PENDANT l'atterrissage de la card — deux échelles se
        // battaient (la plongée 1,6 → 1 ET son propre 0,86 → 1) et sa
        // dérive partait en plein vol. Elle naît maintenant APRÈS le
        // slam, et son flottement est GATÉ par la naissance : il part
        // de zéro, pas du milieu d'une sinusoïde.
        let naissance = StoryCine.sstep(TopCine.slamAt + 0.05,
                                        TopCine.slamAt + 0.50, t)
        let n = CGFloat(naissance)
        let flotte = n * CGFloat(sin(t * 0.62) * 6
            + sin(t * 1.13 + 0.9) * 2.5)
        let derive = n * CGFloat(cos(t * 0.47 + 1.4) * 4)
        let souffle = 1 + 0.022 * CGFloat(sin(t * 0.83)) * n
        return Image(sport.pastille)
            .resizable()
            .scaledToFit()
            .frame(width: cote, height: cote)
            // LE CATCH-LIGHT (chirurgien A2) — le balayage est MORT :
            // un point spéculaire FIXE en haut-gauche qui s'intensifie
            // par pulses APÉRIODIQUES (bruit de valeur, jamais un sinus
            // nu) : le verre ACCROCHE la lumière, rien ne le traverse.
            .overlay {
                RoundedRectangle(cornerRadius: rayonCatch,
                                 style: .continuous)
                    .fill(EllipticalGradient(
                        stops: [.init(color: .white.opacity(opCatch),
                                      location: 0),
                                .init(color: .white.opacity(0.06),
                                      location: 0.40),
                                .init(color: .clear, location: 0.9)],
                        center: UnitPoint(x: 0.30, y: 0.22),
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.5))
                    .blendMode(.screen)
                    .padding(2)
                    .allowsHitTesting(false)
            }
            .background(
                Circle()
                    .fill(RadialGradient(
                        stops: [.init(color: .white.opacity(0.15),
                                      location: 0),
                                .init(color: .clear, location: 1)],
                        center: .center,
                        startRadius: 0, endRadius: cote))
                    .frame(width: cote * 1.6, height: cote * 1.6)
                    .blur(radius: 13)
                    .allowsHitTesting(false))
            // L'OMBRE VRAIE sous la pastille — elle respire avec le
            // flottement : l'objet plane, il n'est pas collé.
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(0.5 * naissance
                        - Double(flotte) * 0.012))
                    .frame(width: cote * 0.62 + flotte * 1.5,
                           height: cote * 0.10)
                    .blur(radius: 9)
                    .offset(y: cote * 0.16)
                    .allowsHitTesting(false)
            }
            // LA POSE (chirurgien C9) : elle DESCEND de 6 pt et
            // s'écrase d'un souffle (squash 1,03/0,97 en cloche) — une
            // pièce qui se pose, pas une image qui apparaît.
            .scaleEffect(x: souffle * (0.94 + 0.06 * n)
                * (1 + 0.03 * CGFloat(sin(.pi * naissance))),
                         y: souffle * (0.94 + 0.06 * n)
                * (1 - 0.03 * CGFloat(sin(.pi * naissance))))
            .opacity(naissance)
            .offset(x: derive, y: flotte - (1 - n) * 6)
    }

    // MARK: La mini-card néon

    /// LA stat qui justifie l'exception — RECOPIÉE d'un fait, jamais
    /// inventée : les minutes (cardio) ou le volume (muscu).
    private var stat: (nombre: Int, unite: String) {
        switch sport {
        case .cardio:
            return (session.minutes, "min")
        case .muscu:
            var v = 0
            for g in session.groupes {
                for r in g.rows { v += r.reps * Int(r.kilos) }
            }
            return (v, "kg")
        }
    }

    /// Le wahou : elle DÉPASSE de la card (en overlay de la scène,
    /// jamais dans le flux — le piège de la fente), arrive EN RETARD
    /// par rotation depuis derrière l'arête, et son néon VERT est le
    /// seul vert de la scène — il crie sur le rouge.
    private var miniNeon: some View {
        let l = min(size.width * 0.80, 332)
        let h = l * 1.32
        let m = StoryCine.sstep(TopCine.miniAt,
                                TopCine.miniAt + TopCine.miniFor, t)
        let vert = Color(red: 0.30, green: 1.0, blue: 0.45)
        let ambre = Color(red: 1.0, green: 0.72, blue: 0.30)
        let s = stat
        // L'ODOMÈTRE (chirurgien C11) : le nombre ROULE de 0 à sa
        // valeur en 0,7 s à sortie douce — et le néon S'AMORCE en deux
        // temps (ambre faible 0,1 s, puis vert plein) : un tube réel
        // s'allume, il ne fade pas.
        let roule = Int(Double(s.nombre) * StoryCine.outLong(
            min(max((t - TopCine.miniAt - 0.10) / 0.7, 0), 1), 2.6))
        let phase = t - TopCine.miniAt
        let encre: Color = phase < 0.10 ? Color(white: 0.35)
            : (phase < 0.20 ? ambre.opacity(0.6) : vert)
        let lueur: Color = phase < 0.20 ? ambre : vert
        return VStack(alignment: .leading, spacing: 3) {
            Text("Best week")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(white: 0.52))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(roule)")
                    .font(.system(size: 30, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.identity)
                Text(s.unite)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(encre)
            // LE NÉON : la lueur serrée + la nappe large — deux ombres
            // sur une card STATIQUE, pas une par ligne de liste.
            .shadow(color: lueur.opacity(0.95 * (phase < 0.20 ? 0.4 : 1)),
                    radius: 3)
            .shadow(color: lueur.opacity(0.55 * (phase < 0.20 ? 0.3 : 1)),
                    radius: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.15),
                                              Color(white: 0.07)],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [.init(color: .white.opacity(0.22),
                                      location: 0),
                                .init(color: .white.opacity(0.04),
                                      location: 0.5),
                                .init(color: .clear, location: 1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    lineWidth: 1)
        }
        .rotationEffect(.degrees(14 - 7 * m))
        // Le POP : elle dépasse sa taille d'un souffle puis se pose —
        // en cloche, jamais deux animations sur la même valeur.
        .scaleEffect(1 + 0.10 * CGFloat(sin(.pi * m)))
        .offset(x: CGFloat(1 - m) * -30)
        .opacity(m)
        .position(x: size.width * 0.50 + l * 0.44,
                  y: size.height * 0.55 - h * 0.30)
        // Le tick du wahou — un grain rigide quand elle claque.
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7),
                         trigger: t >= TopCine.miniAt + 0.25)
    }
}

// MARK: - La page « WIN » (le butin)

/// La partition du butin — tout en fonctions pures de `t`.
enum WinCine {
    static let cardAt = 0.15, cardFor = 0.6
    /// La pièce SE POSE (l'école de la pièce du calendrier).
    static let pieceAt = 0.85
    static let compteurAt = 1.3, compteurFor = 2.2
    static let titreAt = 4.3
}

/// LA PAGE « WIN », tour 2 (tools/story/PLAN-STORY-WIN.md §7) : la
/// pills CÔTÉ OR qui monte du bas ; la card ALIGNÉE sur la story 3
/// (même gabarit, même centre) ; « WIN » EN OR, gros, très fondu ;
/// LA PIÈCE DU PODIUM (`piece-or-mini` — la vidéo est MORTE, « big
/// beug ») qui se pose, FLOTTE, et SE DÉPLACE au doigt ; le compteur
/// qui roule ; et LES BOOSTERS DANS LA CARD — animés comme les
/// stickers, saisissables eux aussi, et leur déplacement SOULÈVE DE
/// LA POUDRE DE DIAMANT (la poudre naît DU mouvement).
/// LES DEUX ROBES DU BUTIN (27-08, plan ../story/PLAN-WIN-RENVERSE.md)
/// — `.poche` : les boosters montent d'une poche au bord bas, le mot
/// et la pièce sont en haut (la robe validée) ; `.renverse` : les
/// paquets PENDENT au plafond et tombent, la pièce et le mot se posent
/// au SOL, le mot passe au chrome irisé et le laser à l'or.
enum RobeWin { case poche, renverse }

struct StoryWin: View {
    let session: StorySession
    let t: Double
    let size: CGSize
    var paused: Bool = false
    /// Le cadre de la card, remonté au chef : bouger un objet ne ferme
    /// pas la story et ne change pas de page.
    var onCardRect: (CGRect) -> Void = { _ in }
    /// La robe. Le moteur tranchera (backend §4 nonies) ; au banc,
    /// `-winRenverse`.
    var robe: RobeWin =
        ProcessInfo.processInfo.arguments.contains("-winRenverse")
            ? .renverse : .poche

    private var renverse: Bool { robe == .renverse }

    /// LES PLACEMENTS LIBRES : clé 0 = la pièce, 1…5 = les boosters.
    /// Les objets RESTENT où on les pose (tranché §6) — l'état survit
    /// aux ré-évaluations de l'horloge.
    @State private var placements: [Int: CGSize] = [:]
    @State private var prises: [Int: CGSize] = [:]
    /// LA POUDRE DU DOIGT : les grains nés du déplacement.
    @State private var grains: [(pos: CGPoint, naissance: Date)] = []
    @State private var naissance = Date()
    /// Les objets TENUS par le doigt (le liseré holo s'allume) et le
    /// compte des prises (une haptique légère à chaque saisie).
    /// Banc `-winHolo` : le premier booster est tenu allumé, pour
    /// filmer la frise sans doigt.
    @State private var tenus: Set<Int> =
        ProcessInfo.processInfo.arguments.contains("-winHolo") ? [1] : []
    @State private var saisies = 0

    private var pieces: Int { session.series * 20 }
    private var boosters: Int { pieces / 100 }

    private var roule: Int {
        let u = StoryCine.outLong(min(max(
            (t - WinCine.compteurAt) / WinCine.compteurFor, 0), 1), 2.6)
        return Int(Double(pieces) * u)
    }

    var body: some View {
        let l = min(size.width * 0.80, 332)
        let h = l * 1.32
        // MÊME CENTRE que la card de la story 3 (« elle est pas la
        // même hauteur que la card précédente » — mesuré : 0,47 contre
        // 0,53, c'était ça).
        let centre = CGPoint(x: size.width * 0.50, y: size.height * 0.53)

        ZStack {
            Color.black

            pillsOr

            carte(l: l, h: h)
                .position(centre)

            // LES OBJETS — par-dessus la card, bornés à son intérieur.
            objets(l: l, h: h, centre: centre)

            // LA POCHE : les boosters vivent DANS la card — coupés par
            // sa forme, vus de moitié au bord bas, et libres au doigt
            // dedans (verdict : « dans la card, on les voit de moitié »).
            poche(l: l, h: h, centre: centre)

            // LA POUDRE DU DOIGT, au-dessus de tout — MONTÉE seulement
            // quand il y a des grains : une Canvas à 30 Hz qui ne
            // dessine rien reste une horloge qui coûte (le lag mesuré
            // à 58 img/s sur la card, contre 82 sur Détails).
            if !grains.isEmpty {
                PoudreDoigt(grains: grains)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6),
                         trigger: saisies)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.65),
                         trigger: beatPlaques)
        // Le rect du chef : toute la zone de la card + objets.
        .onGeometryChange(for: CGRect.self) { proxy in
            CGRect(x: centre.x - l / 2 - 20, y: centre.y - h / 2 - 20,
                   width: l + 40, height: h + 40)
                .offsetBy(dx: proxy.frame(in: .named("storyFlow")).minX
                    - proxy.frame(in: .local).minX,
                          dy: proxy.frame(in: .named("storyFlow")).minY
                    - proxy.frame(in: .local).minY)
        } action: { onCardRect($0) }
    }

    // MARK: La pills or

    private var pillsOr: some View {
        let mw = size.width * 1.15
        let mh = mw * 1352 / 1500
        // « La vidéo n'est pas fondue, on a un gros bloc noir » : les
        // bords de COUPE du fichier faisaient un rectangle. Le fondu est
        // CUIT dans `story-macro-or` (un scrim numpy : le haut et les
        // flancs s'éteignent à zéro — l'école recuit_calques) : aucun
        // masque par image sur une couche vidéo, la cadence est sauve.
        return CalqueVideo(nom: "story-macro-or",
                           pose: "story-macro-or-poster",
                           rate: paused ? 0 : 1)
            .frame(width: mw, height: mh)
            .frame(width: size.width, height: size.height,
                   alignment: .bottom)
            .offset(y: mh * 0.42)
            .blendMode(.plusLighter)
            .opacity(StoryCine.sstep(0.05, 0.65, t))
    }

    // MARK: La card

    private static let forme = RoundedRectangle(cornerRadius: 36,
                                                style: .continuous)

    private func carte(l: CGFloat, h: CGFloat) -> some View {
        let u = StoryCine.sstep(WinCine.cardAt,
                                WinCine.cardAt + WinCine.cardFor, t)
        // « Enlève "pièces" à côté, rajoute un sous-titre dessous, et
        // baisse un peu le texte » : le nombre SEUL en titre, le
        // sous-titre gris à la taille des autres cards, la couronne
        // en dessous, plus discrète.
        let compteurU = StoryCine.sstep(WinCine.compteurAt - 0.2,
                                        WinCine.compteurAt + 0.2, t)
        let titreU = StoryCine.sstep(WinCine.titreAt,
                                     WinCine.titreAt + 0.4, t)
        return VStack(spacing: 2) {
            Text("+\(roule)")
                .font(.system(size: 44, weight: .bold))
                .monospacedDigit()
                .contentTransition(.identity)
                .foregroundStyle(Color(white: 0.96))
                .opacity(compteurU)
            Text("pièces gagnées")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(white: 0.55))
                .opacity(compteurU)
            Text(couronne)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.55)
                    .opacity(0.72))
                .padding(.top, 6)
                .opacity(titreU)
        }
        .frame(maxHeight: .infinity, alignment: .center)
        // AU SOL, le mot occupe tout le bas : le compteur REMONTE
        // (mesuré : sinon le mot le recouvrait sur 64 pt et la pièce
        // écrasait la couronne — plan §7.3).
        .offset(y: renverse ? -h * 0.10 : h * 0.07)
        .frame(width: l, height: h)
        .background {
            ZStack {
                // « Plus dégradé, gris → noir » (verdict) : le fond va du
                // gris du haut au noir du pied, en trois paliers.
                Self.forme.fill(
                    LinearGradient(
                        stops: [.init(color: Color(white: 0.145),
                                      location: 0),
                                .init(color: Color(white: 0.075),
                                      location: 0.55),
                                .init(color: Color(white: 0.02),
                                      location: 1)],
                        startPoint: .top, endPoint: .bottom))
                // LE FILAMENT (verdict) : un fin liseré halo rouge/blanc
                // qui passe DERRIÈRE le mot — un néon POSÉ, jamais un
                // balayage. Il vit à sa propre lumière (dans le bloc du
                // mot il héritait de l'opacité 0,46 et se noyait).
                filament(l: l, h: h)
                motOr(l: l, h: h)
                Self.forme.strokeBorder(
                    LinearGradient(
                        stops: [.init(color: .white.opacity(0.18),
                                      location: 0),
                                .init(color: .white.opacity(0.05),
                                      location: 0.38),
                                .init(color: .clear, location: 1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    lineWidth: 1)
            }
        }
        .clipShape(Self.forme)
        .scaleEffect(0.96 + 0.04 * CGFloat(u))
        .opacity(min(1, u * 2))
    }

    private func filament(l: CGFloat, h: CGFloat) -> some View {
        // TOUT EST PRÉ-TYPÉ (la loi du type-checker, re-payée ici).
        let tq: Double = (t * 20).rounded() / 20
        // « OUI C'EST LASER ! » (verdict) — et il change de couleur avec
        // le mot : quand WIN passe au chrome, le laser prend l'OR.
        // C'est l'ÉCHANGE des registres, ce qui rend la robe lisible
        // d'un coup d'œil.
        let rouge = renverse
            ? Color(red: 1.0, green: 0.78, blue: 0.38)
            : Color(red: 1.0, green: 0.22, blue: 0.08)
        let souffle: Double = 0.62 + 0.16 * sin(tq * 0.61)
        let entree: Double = StoryCine.sstep(WinCine.cardAt + 0.5,
                                             WinCine.cardAt + 1.1, t)
        let alpha: Double = souffle * entree
        // « Le filament rouge qui bouge, s'anime aussi » : son POINT DE
        // LUMIÈRE glisse le long du fil (le courant dans un néon — pas
        // un balayage sur le mot), le fil ondule (deux horloges) et
        // bascule doucement.
        let pic: Double = 0.5 + 0.26 * sin(tq * 0.47 + 0.6)
        let gauche: Double = max(0.03, pic - 0.30)
        let droite: Double = min(0.97, pic + 0.30)
        let dy: CGFloat = l * 0.31 + CGFloat(sin(tq * 0.37)) * 5
            + CGFloat(sin(tq * 0.83 + 1.1)) * 2
        let tilt: Double = -6 + 2.6 * sin(tq * 0.29)
        let stops: [Gradient.Stop] = [
            .init(color: .clear, location: 0),
            .init(color: rouge.opacity(0.95), location: gauche),
            .init(color: .white, location: pic),
            .init(color: rouge.opacity(0.95), location: droite),
            .init(color: .clear, location: 1)
        ]
        // La réflexion court en sens INVERSE (son point de lumière
        // remonte quand celui du fil descend).
        let picBas: Double = 1 - pic
        return Capsule()
            .fill(LinearGradient(stops: stops,
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: l * 0.98, height: 1.8)
            .shadow(color: rouge.opacity(0.9), radius: 8)
            .shadow(color: .white.opacity(0.55), radius: 1.6)
            .rotationEffect(.degrees(renverse ? -tilt : tilt))
            .blendMode(.plusLighter)
            .opacity(alpha)
            // AU SOL : il descend avec le mot et suit la pente
            // inverse. Plus SA RÉFLEXION — deux fois plus fine, deux
            // fois plus sourde, décalée de 9 pt et d'une phase : un
            // laser réel se reflète.
            .overlay {
                if renverse {
                    Capsule()
                        .fill(LinearGradient(
                            stops: Self.stopsLaser(pic: picBas,
                                                   or: rouge),
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: l * 0.94, height: 0.9)
                        .shadow(color: rouge.opacity(0.5), radius: 5)
                        .rotationEffect(.degrees(-tilt * 0.8))
                        .opacity(alpha * 0.45)
                        .offset(y: 9)
                }
            }
            .frame(width: l, height: h,
                   alignment: renverse ? .bottom : .top)
            .offset(y: renverse ? -dy : dy)
    }

    /// Les stops d'un laser : le point de lumière BLANC glisse entre
    /// deux bornes colorées — partagé par le fil et sa réflexion.
    static func stopsLaser(pic: Double, or: Color) -> [Gradient.Stop] {
        let g = max(0.03, pic - 0.30)
        let d = min(0.97, pic + 0.30)
        return [.init(color: .clear, location: 0),
                .init(color: or.opacity(0.95), location: g),
                .init(color: .white, location: pic),
                .init(color: or.opacity(0.95), location: d),
                .init(color: .clear, location: 1)]
    }

    private var couronne: String {
        switch boosters {
        case 0: return "Steady grind."
        case 1...2: return "Nice haul."
        case 3...4: return "Big win."
        default: return "Jackpot."
        }
    }

    /// « WIN » EN OR — tour 2 : PLUS GROS (toute la largeur, la
    /// maquette) et PLUS FONDU (la traîne meurt à ~0,58 : le mot
    /// irrigue la moitié de la card).
    /// « WIN PLUS MAJESTUEUX, PLUS CHIRURGIEN » (verdict tour 3) :
    /// le mot est GRAVÉ (l'ombre interne sous l'encre — imprimé, pas
    /// posé), des NAPPES D'OR naissent dedans (périodes premières,
    /// jamais un balayage), des SCINTILLES apériodiques piquent les
    /// lettres, un halo d'or très doux respire derrière — et la
    /// traîne FOND DANS LE GRIS de la card (une queue longue, morte à
    /// 0,86, sur le graphite — jamais une coupe).
    private func motOr(l: CGFloat, h: CGFloat) -> some View {
        // L'HORLOGE QUANTIFIÉE (20 Hz) : le mot porte deux masques et
        // des nappes qui dérivent LENTEMENT — les recomposer à 60 Hz
        // coûtait la cadence (41 img/s mesuré). À 20 pas par seconde,
        // ses entrées ne changent qu'une image sur trois : le rendu
        // ne se refait qu'à ces instants.
        let t = (t * 20).rounded() / 20
        let glyphe = Text("WIN")
            .font(.system(size: l * 0.52, weight: .black))
            .tracking(-l * 0.018)
            .fixedSize()
        // « PLUS TRAVAILLÉ DANS L'OR » : l'encre est un MÉTAL — six
        // paliers (champagne, or, une BANDE de reflet étroite qui
        // dérive lentement, ambre, bronze au pied) — sous un BISEAU
        // champagne qui affleure au bord haut des lettres.
        // EN ROBE RENVERSÉE : « CHROME IRISÉ STP » (verdict) — le mot
        // est fait de la MATIÈRE DES PAQUETS qui pleuvent sur lui. Un
        // socle de métal FROID (l'irisation seule ferait une flaque
        // d'essence — il faut du métal dessous pour que ça reste un
        // mot), et par-dessus l'arc-en-ciel qui tourne LENTEMENT.
        let bande: Double = 0.40 + 0.05 * sin(t * 0.31)
        // Les deux bornes de la bande irisée qui DESCEND (sens inverse
        // de l'arc angulaire) — pré-typées, la loi du type-checker.
        let irise1: Double = 0.26 + 0.16 * sin(t * 0.23 + 1.1)
        let irise2: Double = min(0.94, irise1 + 0.30)
        let chaudHalo = Color(red: 1.0, green: 0.80, blue: 0.42)
        let froidHalo = Color(red: 0.72, green: 0.86, blue: 1.0)
        let haloTeinte: Color = renverse ? froidHalo : chaudHalo
        let haloBase: Double = renverse ? 0.085 : 0.13
        let haloAlpha: Double = haloBase + 0.03 * sin(t * 0.53)
        let biseau: Color = renverse
            ? Color(red: 0.90, green: 0.95, blue: 1.0)
            : Color(red: 1.0, green: 0.94, blue: 0.76)
        let dGrav: CGFloat = renverse ? -1.8 : 1.8
        let dBis: CGFloat = renverse ? 1.3 : -1.3
        let metal: [Gradient.Stop] = Self.metalStops(bande: bande,
                                                     froid: renverse)
        return ZStack {
            // Le halo, très doux, qui respire derrière le mot — froid
            // en robe renversée, et RETENU : une couleur froide en
            // additif sature au blanc bien plus vite qu'un or.
            Ellipse()
                .fill(RadialGradient(
                    colors: [haloTeinte.opacity(haloAlpha), .clear],
                    center: .center, startRadius: 0,
                    endRadius: l * 0.45))
                .frame(width: l * 1.1, height: l * 0.55)
                .blendMode(.plusLighter)
            // LA GRAVURE : l'ombre interne d'abord, le biseau, l'encre.
            // EN ROBE RENVERSÉE le mot est CREUSÉ DANS LE SOL : la
            // gravure s'inverse (l'ombre passe au-dessus, le biseau
            // dessous) — une lettre creusée dans un sol est éclairée
            // par le haut. Garder l'ordre donnerait un mot en RELIEF.
            glyphe
                .foregroundStyle(Color.black.opacity(0.45))
                .offset(y: dGrav)
            glyphe
                .foregroundStyle(biseau.opacity(0.85))
                .offset(y: dBis)
            glyphe
                .foregroundStyle(LinearGradient(
                    stops: metal, startPoint: .top, endPoint: .bottom))
            // L'IRISATION DU CHROME : un arc-en-ciel qui tourne à
            // 6 °/s (le holo au doigt tourne à 24 : un mot n'est pas
            // un objet qu'on incline), masqué par le glyphe, retenu à
            // 0,45 — la loi du plusLighter qui sature au blanc.
            if renverse {
                // MESURÉ au film : à 0,45, multipliée par l'opacité
                // finale du mot (0,28), l'irisation ne pesait que 0,13
                // — le mot rendait GRIS. Deux passes CROISÉES : l'arc
                // angulaire qui tourne, et une bande LINÉAIRE qui
                // descend en sens inverse. C'est leur croisement qui
                // fait le chrome (une seule nappe fait un dégradé).
                Rectangle()
                    .fill(AngularGradient(
                        colors: [Color(red: 0.05, green: 0.85, blue: 1.0),
                                 Color(red: 1.0, green: 0.25, blue: 0.85),
                                 Color(red: 1.0, green: 0.78, blue: 0.15),
                                 Color(red: 0.20, green: 1.0, blue: 0.45),
                                 Color(red: 0.05, green: 0.85, blue: 1.0)],
                        center: .center, angle: .degrees(t * 6)))
                    .frame(width: l * 1.2, height: l * 0.7)
                    .mask { glyphe }
                    .blendMode(.plusLighter)
                    .opacity(0.95)
                Rectangle()
                    .fill(LinearGradient(
                        stops: [.init(color: .clear, location: 0),
                                .init(color: Color(red: 0.35, green: 0.95,
                                                   blue: 1.0)
                                    .opacity(0.55), location: irise1),
                                .init(color: Color(red: 1.0, green: 0.45,
                                                   blue: 0.95)
                                    .opacity(0.45), location: irise2),
                                .init(color: .clear, location: 1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .frame(width: l * 1.2, height: l * 0.7)
                    .mask { glyphe }
                    .blendMode(.plusLighter)
                    .opacity(0.8)
            }
            // LES NAPPES D'OR — la lumière naît DANS les lettres.
            nappesOr(l: l)
                .mask { glyphe }
                .blendMode(.plusLighter)
        }
        .frame(width: l)
        .mask {
            // « Fondu aussi sur les côtés » : les flancs mangent 26 % —
            // le mot sort de la matière, il n'est pas posé dessus.
            LinearGradient(
                stops: [.init(color: .clear, location: 0),
                        .init(color: .white, location: 0.30),
                        .init(color: .white, location: 0.70),
                        .init(color: .clear, location: 1)],
                startPoint: .leading, endPoint: .trailing)
        }
        .mask {
            // LA TRAÎNE LONGUE — « encore plus fondu » : elle fond DANS
            // le gris dès le tiers, cinq paliers, morte à 0,80.
            // AU SOL elle se RETOURNE : pleine au pied, dissoute en
            // montant — sans quoi le mot serait à pleine encre contre
            // le palier le plus noir du fond, et le fondu marcherait
            // à l'envers.
            LinearGradient(
                stops: [.init(color: .white, location: 0),
                        .init(color: .white.opacity(0.92),
                              location: 0.14),
                        .init(color: .white.opacity(0.58),
                              location: 0.30),
                        .init(color: .white.opacity(0.26),
                              location: 0.48),
                        .init(color: .white.opacity(0.08),
                              location: 0.66),
                        .init(color: .clear, location: 0.80)],
                startPoint: renverse ? .bottom : .top,
                endPoint: renverse ? .top : .bottom)
        }
        // « Un peu plus fond de carte » : le mot RECULE dans la matière
        // — il est du fond, pas un objet posé dessus.
        // ⚠️ MESURÉ : le fond de la card va de 0,145 en haut à 0,02 en
        // bas — le MÊME 0,42 rendrait le mot ~6× plus contrasté au sol
        // (rapport 20× contre 3,3×). D'où 0,22 en robe renversée : deux
        // fois plus présent qu'en haut (c'est l'intention d'un mot
        // GRAVÉ dans le sol), pas six.
        .opacity((renverse ? 0.28 : 0.42)
            * StoryCine.sstep(WinCine.cardAt + 0.25,
                              WinCine.cardAt + 0.80, t))
        .frame(width: l, height: h,
               alignment: renverse ? .bottom : .top)
        .offset(y: renverse ? -8 : 6)
    }

    /// LES SIX PALIERS DU MÉTAL — deux tables, chacune PRÉ-TYPÉE dans
    /// sa propre fonction (la loi du type-checker : un ternaire entre
    /// deux littéraux de six `Gradient.Stop` fait exploser la
    /// vérification — le build est parti à plus de dix minutes).
    static func metalStops(bande: Double, froid: Bool) -> [Gradient.Stop] {
        let g: Double = max(0.08, bande - 0.16)
        let d: Double = min(0.82, bande + 0.14)
        if froid {
            let c0 = Color(white: 0.96)
            let c1 = Color(red: 0.72, green: 0.75, blue: 0.82)
            let c2 = Color(white: 1.0)
            let c3 = Color(red: 0.56, green: 0.60, blue: 0.70)
            let c4 = Color(red: 0.32, green: 0.35, blue: 0.44)
            let c5 = Color(red: 0.16, green: 0.18, blue: 0.24)
            return [.init(color: c0, location: 0),
                    .init(color: c1, location: g),
                    .init(color: c2, location: bande),
                    .init(color: c3, location: d),
                    .init(color: c4, location: 0.86),
                    .init(color: c5, location: 1)]
        }
        let c0 = Color(red: 1.0, green: 0.90, blue: 0.62)
        let c1 = Color(red: 1.0, green: 0.78, blue: 0.38)
        let c2 = Color(red: 1.0, green: 0.93, blue: 0.68)
        let c3 = Color(red: 0.98, green: 0.70, blue: 0.26)
        let c4 = Color(red: 0.92, green: 0.44, blue: 0.06)
        let c5 = Color(red: 0.62, green: 0.30, blue: 0.05)
        return [.init(color: c0, location: 0),
                .init(color: c1, location: g),
                .init(color: c2, location: bande),
                .init(color: c3, location: d),
                .init(color: c4, location: 0.86),
                .init(color: c5, location: 1)]
    }

    /// Les nappes d'or + les scintilles du mot — périodes premières,
    /// bosses étroites, dérive infime ; les scintilles sont des
    /// piqûres (enveloppe puissance 12, une pointe rare).
    private func nappesOr(l: CGFloat) -> some View {
        let t = (t * 20).rounded() / 20
        let teinteNappe: Color = renverse
            ? Color(red: 0.86, green: 0.94, blue: 1.0)
            : Color(red: 1.0, green: 0.90, blue: 0.62)
        let alphaNappe: Double = renverse ? 0.34 : 0.50
        let periodes: [Double] = [3.7, 5.3, 7.1, 4.3, 6.7, 5.9, 8.3]
        return ZStack {
            ForEach(0 ..< 7, id: \.self) { i in
                let h1 = Self.hashWin(i, 1)
                let h2 = Self.hashWin(i, 2)
                let h3 = Self.hashWin(i, 3)
                let u = (t / periodes[i] + h1)
                    .truncatingRemainder(dividingBy: 1)
                let bosse = pow(max(0, sin(.pi * u)), 6.0)
                Ellipse()
                    .fill(RadialGradient(
                        colors: [teinteNappe.opacity(alphaNappe),
                                 .clear],
                        center: .center, startRadius: 0,
                        endRadius: l * CGFloat(0.10 + 0.08 * h2)))
                    .frame(width: l * CGFloat(0.24 + 0.20 * h2),
                           height: l * CGFloat(0.16 + 0.12 * h3))
                    .offset(x: l * (CGFloat(h1) - 0.5) * 0.95,
                            y: l * (CGFloat(h3) - 0.5) * 0.30)
                    .opacity(bosse)
            }
            // Les scintilles : neuf piqûres d'or blanc, rares.
            ForEach(0 ..< 9, id: \.self) { i in
                let h1 = Self.hashWin(i, 7)
                let h2 = Self.hashWin(i, 8)
                let u = (t / (2.9 + 2.3 * h1) + h2)
                    .truncatingRemainder(dividingBy: 1)
                let pointe = pow(max(0, sin(.pi * u)), 12.0)
                Circle()
                    .fill(Color(red: 1.0, green: 0.97, blue: 0.88))
                    .frame(width: 2.4, height: 2.4)
                    .offset(x: l * (CGFloat(h1) - 0.5) * 0.90,
                            y: l * (CGFloat(h2) - 0.5) * 0.26)
                    .opacity(pointe * 0.9)
            }
        }
    }

    private static func hashWin(_ i: Int, _ k: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return v - floor(v)
    }

    // MARK: Les objets saisissables

    private var beatPlaques: Int {
        (1...max(1, boosters)).filter { roule >= $0 * 100 + 15 }.count
    }

    /// La pièce (clé 0) + les boosters (clés 1…5) : chacun a sa place
    /// de naissance, son animation, sa prise — et RESTE où on le pose.
    private func objets(l: CGFloat, h: CGFloat,
                        centre: CGPoint) -> some View {
        return ZStack {
            // LA PIÈCE DU PODIUM — elle se pose, flotte, se saisit.
            objet(cle: 0, centre: centre, l: l, h: h,
                  base: CGPoint(x: 0,
                                y: renverse ? h * 0.14 : -h * 0.24)) {
                let pose = StoryCine.sstep(WinCine.pieceAt,
                                           WinCine.pieceAt + 0.35, t)
                // « FAIS UN TRUC PLUS PREMIUM, ET D'ELLE SORTENT DES
                // PETITES POUDRES DE DIAMANT » : la pièce ne nage plus
                // comme un sticker — elle PLANE sur une courbe de
                // Lissajous (deux horloges premières, jamais un
                // aller-retour), à peine inclinée, un souffle d'échelle,
                // un halo d'or qui respire dessous, et LA POUSSIÈRE qui
                // naît d'elle et la suit au doigt.
                let n = CGFloat(pose)
                let px = CGFloat(sin(t * 0.53)) * 5.5 * n
                let py = -(CGFloat(sin(t * 0.62)) * 7
                    + CGFloat(sin(t * 1.13 + 0.9)) * 2.5) * n
                let tilt = sin(t * 0.31 + 0.7) * 2.2 * pose
                let souffle = 1 + 0.02 * CGFloat(sin(t * 0.83)) * n
                let halo = 0.20 + 0.06 * sin(t * 0.71)
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color(red: 1.0, green: 0.80,
                                           blue: 0.42).opacity(halo),
                                     .clear],
                            center: .center, startRadius: 0,
                            endRadius: 78))
                        .frame(width: 160, height: 160)
                        .blendMode(.plusLighter)
                    // AU SOL : la pièce ÉCLAIRE la gravure sous elle —
                    // une flaque qui respire avec sa hauteur. Une pièce
                    // qui plane au-dessus d'un sol gravé doit éclairer
                    // ce sol.
                    if renverse {
                        let orFlaque = Color(red: 1.0, green: 0.84,
                                             blue: 0.50)
                        let aFlaque: Double = 0.10
                            + 0.04 * sin(t * 0.71) - Double(py) * 0.004
                        Ellipse()
                            .fill(RadialGradient(
                                colors: [orFlaque.opacity(aFlaque),
                                         .clear],
                                center: .center, startRadius: 0,
                                endRadius: l * 0.24))
                            .frame(width: l * 0.46, height: l * 0.12)
                            .offset(y: 62 - py * 0.5)
                            .blendMode(.plusLighter)
                    }
                    PoudrePiece(naissance: naissance)
                        .frame(width: 220, height: 220)
                        .blendMode(.plusLighter)
                    Image("piece-or-mini")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(tilt))
                        .scaleEffect(x: souffle * (0.92 + 0.08 * n)
                            * (1 + 0.03 * CGFloat(sin(.pi * pose))),
                                     y: souffle * (0.92 + 0.08 * n)
                            * (1 - 0.03 * CGFloat(sin(.pi * pose))))
                }
                .opacity(pose)
                .offset(x: px, y: py - (1 - n) * 6)
            }

        }
    }

    /// LA POCHE DES BOOSTERS (verdict : « ils sont dans la card, on les
    /// voit de moitié, et ils bougent — là ils sont juste plaqués ») :
    /// une couche COUPÉE par la forme de la card, le centre de chaque
    /// booster posé SUR le bord bas — la moitié basse vit sous la
    /// coupe, comme des cartes dans une poche. Chacun MONTE de la
    /// poche à son franchissement de 100, puis NAGE (deux fois plus
    /// ample qu'avant : ±12 pt, la part visible respire), et se tire
    /// au doigt jusqu'en haut de la card — jamais plus bas que la
    /// moitié.
    private func poche(l: CGFloat, h: CGFloat,
                       centre: CGPoint) -> some View {
        let montres = min(boosters, 5)
        // « Grossis-les un peu, monte-les un peu » : 116 → 130 pt, le
        // centre 12 % au-dessus du bord bas. « Toujours un qui dépasse
        // un peu plus que les autres » : LE HÉROS (celui du milieu)
        // sort de 16 % de plus.
        let hb: CGFloat = 130
        let wb = hb * 794 / 1278
        let basesB: [(x: CGFloat, deg: Double)] = [
            (-0.24, -9), (0.03, 6), (0.27, -4), (-0.09, 11), (0.15, -12)
        ]
        let heros = montres >= 2 ? 1 : 0
        let origine = CGPoint(x: l / 2, y: h / 2)
        // AU PLAFOND, tout est miroir. ⚠️ MESURÉ : sans retourner AUSSI
        // les bornes, le clamp écrasait la pose 44,2 pt plus bas et les
        // paquets ne dépassaient JAMAIS du bord haut.
        let bornes = renverse
            ? Bornes(x: l / 2 - wb * 0.45,
                     haut: -h / 2, bas: h / 2 - hb * 0.62)
            : Bornes(x: l / 2 - wb * 0.45,
                     haut: -h / 2 + hb * 0.62, bas: h / 2)
        return ZStack {
            ForEach(0 ..< montres, id: \.self) { i in
                let seuil = Double((i + 1) * 100)
                let pose = min(max((Double(roule) - seuil) / 30.0, 0), 1)
                // LA CHUTE (robe renversée) : il TOMBE du plafond et
                // REBONDIT — une arrivée molle serait un vol, pas une
                // chute. Sinon : la montée douce de la poche.
                let chute: Double = 1 - pow(1 - pose, 2)
                let rebond: Double = 0.09
                    * sin(.pi * min(1, pose * 1.6)) * exp(-pose * 4)
                let montee: Double = renverse
                    ? min(1, chute + rebond)
                    : StoryCine.outLong(pose, 3.0)
                let phi = Double(i) * 2.1
                let n = CGFloat(montee)
                // LA NAGE — trois horloges premières, dérive, balancement
                // lent et profond ; jamais un tremblé. « De base ils
                // bougent davantage » (verdict) : ±18 pt de houle, ±6 de
                // dérive, ±4,5°.
                // SUSPENDU, ce n'est plus une nage mais un PENDULE : un
                // objet accroché par le haut a un point d'attache — la
                // rotation s'amplifie, la translation se réduit, et
                // l'oscillation tient en UN terme (un pendule est en
                // sin, pas en Lissajous).
                let pendule: CGFloat = CGFloat(sin(t * 1.85 + phi))
                let houle: CGFloat = CGFloat(sin(t * 0.62 + phi)) * 14
                    + CGFloat(sin(t * 1.13 + phi + 0.9)) * 4
                let flotte: CGFloat = renverse
                    ? pendule * 4 * n : houle * n
                let deriveP: CGFloat = CGFloat(sin(t * 1.85 + phi + 0.4))
                let deriveH: CGFloat = CGFloat(cos(t * 0.47 + phi + 1.4))
                let derive: CGFloat = renverse
                    ? deriveP * 7 * n : deriveH * 6 * n
                let sway: Double = renverse
                    ? sin(t * 1.85 + phi) * 7 * montee
                    : sin(t * 0.43 + phi) * 4.5 * montee
                let souffle = 1 + 0.018
                    * CGFloat(sin(t * 0.83 + phi)) * n
                // LA MONTÉE : il sort de la poche (caché sous la coupe)
                // et se cale, avec un petit dépassement de ressort.
                // Au plafond, le signe s'inverse : il DESCEND de là-haut.
                let sortie = (renverse ? -(1 - n) : (1 - n)) * hb * 0.62
                let tenu = tenus.contains(i + 1)
                let prise = prises[i + 1] ?? .zero
                // LE HOLO S'ALLUME (verdict) : la frise irisée du
                // sticker, extraite par saturation, colorée d'un
                // dégradé irisé dont la TEINTE TOURNE AVEC LE DOIGT —
                // comme un vrai holo qu'on incline — et qui luit.
                let tq: Double = (t * 20).rounded() / 20
                let teinte: Double = Double(prise.width) * 1.1
                    + Double(prise.height) * 0.7 + tq * 24
                let repos: CGFloat = renverse
                    ? -h / 2 + hb * (i == heros ? 0.28 : 0.12)
                    : h / 2 - hb * (i == heros ? 0.28 : 0.12)
                objet(cle: i + 1, centre: origine, l: l, h: h,
                      base: CGPoint(x: basesB[i].x * l, y: repos),
                      bornes: bornes, revient: true) {
                    ZStack(alignment: .topTrailing) {
                        Image("sticker-booster")
                            .resizable()
                            .scaledToFit()
                            .frame(width: wb, height: hb)
                            .overlay {
                                holo(wb: wb, hb: hb, teinte: teinte)
                                    .opacity(tenu ? 1 : 0)
                                    .animation(.easeOut(duration: 0.28),
                                               value: tenu)
                            }
                        if i == 4 && boosters > 5 {
                            Text("×\(boosters)")
                                .font(.inter(13, .semibold))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.94,
                                                   blue: 0.80),
                                             Color(red: 1.0, green: 0.78,
                                                   blue: 0.38)],
                                    startPoint: .top,
                                    endPoint: .bottom))
                                .offset(x: 8, y: -6)
                        }
                    }
                    .rotationEffect(.degrees(basesB[i].deg + sway))
                    .scaleEffect(souffle * (1 + 0.06 * CGFloat(sin(.pi * montee))))
                    .opacity(min(1, pose * 2.5))
                    // L'OMBRE PORTÉE — la seule de la page : quand un
                    // paquet descend vers le mot, il l'assombrit. C'est
                    // ce qui PROUVE qu'il est au-dessus.
                    .background {
                        if renverse {
                            let bas = max(0, Double(repos - flotte
                                + prise.height) / Double(h * 0.34))
                            // Un DÉGRADÉ, jamais un `blur` : trois
                            // flous par image coûtaient 14 img/s
                            // (42 contre 56 mesurés).
                            Ellipse()
                                .fill(RadialGradient(
                                    colors: [Color.black.opacity(
                                        0.45 * min(1, bas)), .clear],
                                    center: .center, startRadius: 0,
                                    endRadius: wb * 0.62))
                                .frame(width: wb * 1.5, height: hb * 0.5)
                                .offset(y: hb * 0.42)
                        }
                    }
                    .offset(x: derive, y: -flotte + sortie)
                }
                .zIndex(Double(i))
            }
        }
        .frame(width: l, height: h)
        .clipShape(Self.forme)
        .position(centre)
    }

    /// LA FRISE HOLO ALLUMÉE : le masque `sticker-booster-holo` porte
    /// un dégradé irisé (cyan → magenta → or → cyan) tourné par la
    /// teinte, en deux couches — le trait net, et sa lueur (flou 3).
    private func holo(wb: CGFloat, hb: CGFloat, teinte: Double)
        -> some View {
        // MESURÉ au film : à pleine intensité le plusLighter SATURE AU
        // BLANC sur la frise (déjà claire) — l'irisation meurt. Des
        // couleurs SATURÉES et une intensité retenue : le holo colore.
        let irise = AngularGradient(
            colors: [Color(red: 0.05, green: 0.85, blue: 1.0),
                     Color(red: 1.0, green: 0.25, blue: 0.85),
                     Color(red: 1.0, green: 0.78, blue: 0.15),
                     Color(red: 0.20, green: 1.0, blue: 0.45),
                     Color(red: 0.05, green: 0.85, blue: 1.0)],
            center: .center, angle: .degrees(teinte))
        return ZStack {
            Image("sticker-booster-holo")
                .resizable()
                .scaledToFit()
                .frame(width: wb, height: hb)
                .foregroundStyle(irise)
                .blur(radius: 3.5)
                .opacity(0.55)
            Image("sticker-booster-holo")
                .resizable()
                .scaledToFit()
                .frame(width: wb, height: hb)
                .foregroundStyle(irise)
                .opacity(0.62)
        }
        .blendMode(.plusLighter)
    }


    /// UN objet saisissable de CETTE page — l'enveloppe qui passe les
    /// cinq états à la pièce partagée `ObjetSaisissable` (extraite pour
    /// que la story card puisse s'en servir : une seule vérité).
    private func objet<V: View>(cle: Int, centre: CGPoint, l: CGFloat,
                                h: CGFloat, base: CGPoint,
                                bornes: Bornes? = nil,
                                revient: Bool = false,
                                @ViewBuilder _ contenu: @escaping () -> V)
        -> some View {
        ObjetSaisissable(cle: cle, centre: centre,
                         bornes: bornes ?? Bornes(x: l / 2 - 30,
                                                  haut: -h / 2 + 40,
                                                  bas: h / 2 - 30),
                         base: base, revient: revient,
                         placements: $placements, prises: $prises,
                         tenus: $tenus, grains: $grains,
                         saisies: $saisies, contenu: contenu)
    }

}

// MARK: - L'objet qu'on prend dans la main

/// LES BORNES d'un objet saisissable, autour de son origine.
struct Bornes {
    let x: CGFloat
    let haut: CGFloat
    let bas: CGFloat
}

/// L'OBJET SAISISSABLE — extrait de la page WIN (27-08) pour que la
/// story card s'en serve : une seule vérité, pas deux qui divergent.
/// Sa place = base + placement gardé + prise en cours, CLAMPÉE ; la
/// prise est un geste d'ENFANT à `minimumDistance: 2` (un tap franc
/// retombe chez le chef d'orchestre, qui renonce via le rect de la
/// card) ; le déplacement SOULÈVE la poudre de diamant.
struct ObjetSaisissable<Contenu: View>: View {
    let cle: Int
    let centre: CGPoint
    let bornes: Bornes
    let base: CGPoint
    /// `true` = un RESSORT le ramène au lâcher (les boosters, la
    /// colonne de la story card) ; `false` = il RESTE où on le pose
    /// (la pièce du butin).
    var revient: Bool = false
    /// La saisie ne s'arme qu'après cette date de page — avant ~1 s,
    /// le chef d'orchestre tourne la page sur n'importe quel tap
    /// (garde `clock > 0.95`), et un objet qui vient d'atterrir n'est
    /// pas encore un objet qu'on prend.
    var armeA: Double = 0
    var horloge: Double = .infinity

    @Binding var placements: [Int: CGSize]
    @Binding var prises: [Int: CGSize]
    @Binding var tenus: Set<Int>
    @Binding var grains: [(pos: CGPoint, naissance: Date)]
    @Binding var saisies: Int
    @ViewBuilder var contenu: () -> Contenu

    var body: some View {
        let pose = placements[cle] ?? .zero
        let prise = prises[cle] ?? .zero
        let dx = pose.width + prise.width
        let dy = pose.height + prise.height
        let x = min(max(base.x + dx, -bornes.x), bornes.x)
        let y = min(max(base.y + dy, bornes.haut), bornes.bas)
        return contenu()
            .position(x: centre.x + x, y: centre.y + y)
            .gesture(
                DragGesture(minimumDistance: 2,
                            coordinateSpace: .named("storyFlow"))
                    .onChanged { v in
                        guard horloge >= armeA else { return }
                        if !tenus.contains(cle) {
                            tenus.insert(cle)
                            saisies += 1
                        }
                        prises[cle] = v.translation
                        // LA POUDRE NAÎT DU MOUVEMENT — un grain par
                        // pas de doigt, jamais un tapis permanent.
                        // ⚠️ LE MÉNAGE VIT ICI AUSSI : avec le seul
                        // ménage du lâcher, un drag de ~1,5 s saturait
                        // le plafond de 90 et la poudre MOURAIT en
                        // cours de geste (défaut mesuré au plan).
                        if grains.count >= 90 {
                            let n = Date()
                            grains.removeAll {
                                n.timeIntervalSince($0.naissance) > 0.9
                            }
                        }
                        if grains.count < 90 {
                            grains.append((pos: v.location,
                                           naissance: Date()))
                        }
                    }
                    .onEnded { v in
                        guard horloge >= armeA else { return }
                        tenus.remove(cle)
                        if revient {
                            // La place n'est jamais gardée : un
                            // ressort le remet où il était.
                            withAnimation(.spring(response: 0.62,
                                                  dampingFraction: 0.58)) {
                                prises[cle] = .zero
                            }
                        } else {
                            var p = placements[cle] ?? .zero
                            p.width += v.translation.width
                            p.height += v.translation.height
                            placements[cle] = p
                            prises[cle] = .zero
                        }
                        grains.removeAll {
                            Date().timeIntervalSince($0.naissance) > 1
                        }
                    })
    }
}

// MARK: - La poudre du doigt

/// LES GRAINS NÉS DU MOUVEMENT (l'école de la gerbe du coffre + la
/// poudre de diamant) : chaque grain vit ~0,8 s — il monte, scintille
/// TRANCHÉ et meurt. Une seule horloge pour tout le champ.
private struct PoudreDoigt: View {
    let grains: [(pos: CGPoint, naissance: Date)]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            Canvas { ctx, _ in
                ctx.blendMode = .plusLighter
                for (i, g) in grains.enumerated() {
                    let age = tl.date.timeIntervalSince(g.naissance)
                    guard age >= 0, age < 0.8 else { continue }
                    let u = age / 0.8
                    let h1 = Self.hash(i, 1), h2 = Self.hash(i, 2)
                    let x = g.pos.x + CGFloat(h1 - 0.5) * 26
                    let y = g.pos.y + CGFloat(h2 - 0.5) * 20
                        - CGFloat(u) * 22
                    let tw = 0.5 + 0.5 * sin(age * (9 + 10 * h1)
                        + h2 * 6.28)
                    let a = (1 - u) * (0.25 + 0.75 * tw * tw)
                    guard a > 0.03 else { continue }
                    let r = CGFloat(0.8 + 1.6 * Self.hash(i, 3))
                    var etoile = Path()
                    etoile.move(to: CGPoint(x: -r, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: -r * 0.24))
                    etoile.addLine(to: CGPoint(x: r, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: r * 0.24))
                    etoile.closeSubpath()
                    etoile.move(to: CGPoint(x: 0, y: -r))
                    etoile.addLine(to: CGPoint(x: r * 0.24, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: r))
                    etoile.addLine(to: CGPoint(x: -r * 0.24, y: 0))
                    etoile.closeSubpath()
                    ctx.fill(etoile.applying(
                        CGAffineTransform(translationX: x, y: y)),
                             with: .color(Color(red: 0.95, green: 0.97,
                                                blue: 1.0)
                                 .opacity(a * 0.9)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return v - floor(v)
    }
}

// MARK: - La poussière de la pièce

/// LA POUDRE QUI SORT DE LA PIÈCE : des grains qui naissent à son
/// bord, montent et s'écartent, scintillent TRANCHÉ et meurent — une
/// seule horloge, 30 Hz, l'école PoudreStory. Elle vit dans le cadre de
/// la pièce, donc elle la SUIT au doigt.
private struct PoudrePiece: View {
    let naissance: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let grains = 26

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(naissance)
            Canvas { ctx, size in
                ctx.blendMode = .plusLighter
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0 ..< Self.grains {
                    let vie = 1.4 + 1.4 * Self.hash(i, 2)
                    let cyc = (t / vie + Self.hash(i, 5))
                        .truncatingRemainder(dividingBy: 1)
                    let ang = Self.hash(i, 1) * 6.2832
                    // Naît au bord de la pièce (r 44-52), s'écarte de
                    // 22 pt et monte de 16 pendant sa vie.
                    let r0 = 44 + 8 * Self.hash(i, 3)
                    let r = r0 + 22 * cyc
                    let x = c.x + CGFloat(cos(ang) * r)
                        + CGFloat(sin(t * (0.6 + 0.5 * Self.hash(i, 8))
                                      + Self.hash(i, 9) * 6.28)) * 3
                    let y = c.y + CGFloat(sin(ang) * r) - CGFloat(cyc) * 16
                    let s = sin(.pi * cyc)
                    let tw = 0.5 + 0.5 * sin(t * (7 + 10 * Self.hash(i, 4))
                                             + Self.hash(i, 6) * 6.28)
                    let a = s * s * (0.15 + 0.85 * tw * tw * tw)
                    guard a > 0.03 else { continue }
                    let rr = CGFloat(0.7 + 1.5 * Self.hash(i, 7))
                    let col = Self.hash(i, 10) < 0.5
                        ? Color.white
                        : Color(red: 1.0, green: 0.93, blue: 0.72)
                    var etoile = Path()
                    etoile.move(to: CGPoint(x: -rr, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: -rr * 0.24))
                    etoile.addLine(to: CGPoint(x: rr, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: rr * 0.24))
                    etoile.closeSubpath()
                    etoile.move(to: CGPoint(x: 0, y: -rr))
                    etoile.addLine(to: CGPoint(x: rr * 0.24, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: rr))
                    etoile.addLine(to: CGPoint(x: -rr * 0.24, y: 0))
                    etoile.closeSubpath()
                    ctx.fill(etoile.applying(
                        CGAffineTransform(translationX: x, y: y)),
                             with: .color(col.opacity(a * 0.9)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return v - floor(v)
    }
}

// MARK: - La page « ×2 » (deux séances le même jour)

/// La partition de la page ×2 — l'école TopCine, plus LE SECOND COUP :
/// le premier battement ×2 est l'atterrissage lui-même (plan
/// ../rewards/PLAN-VARIANT-X2.md §4).
enum DoubleCine {
    static let poseFor = 0.9
    static let cardAt = 5.0, cardFor = 0.85
    static var slamAt: Double { cardAt + cardFor }
    /// 0,28 s après le slam — le halo s'allume SUR celui-là, pas sur le
    /// premier (le retard fait le wahou).
    static var coup2At: Double { slamAt + 0.28 }
    static let haloFor = 0.55
    static let fumeeFor = 1.2
    static let miniAt = 6.75, miniFor = 0.45
    static let sousAt = 6.55
    /// LE RYTHME ×2 : deux coups à 0,28 s, puis le repos — période
    /// 2,46 s. Jamais un sinus nu : c'est le rythme qui dit « deux ».
    static let periode = 2.46, ecart = 0.28
    static func battement(_ t: Double) -> Double {
        guard t >= 0 else { return 0 }
        let phi = t.truncatingRemainder(dividingBy: periode)
        func pulse(_ x: Double) -> Double { exp(-(x / 0.09) * (x / 0.09)) }
        return min(1, pulse(phi) + pulse(phi - ecart))
    }
}

/// LA PAGE « ×2 » (27-08, plan ../rewards/PLAN-VARIANT-X2.md) : le moule
/// de TOP SESSION, re-costumé en NOIR ET BLANC — le rouge n'existe qu'en
/// trois points (le x2 de la pastille et sa braise, la fumée, le halo de
/// page). La pills énorme entre par la GAUCHE, le mot géant est ARGENT,
/// le halo de page est noir / orange / rouge et PULSE sur le rythme ×2,
/// le footer de la card FUME (rouge, noir, blanc — un shader borné), et
/// la mini-card, à gauche, dit les DEUX HEURES en néon blanc.
struct StoryDoubleScene: View {
    let session: StorySession
    let t: Double
    let size: CGSize
    var paused: Bool = false

    @State private var naissance = Date()

    /// Les interrupteurs du banc de cadence (A/B au mpdecimate) :
    /// `-x2SansFumee`, `-x2SansHalo`.
    private static let sansFumee = CommandLine.arguments.contains("-x2SansFumee")
    private static let sansHalo = CommandLine.arguments.contains("-x2SansHalo")

    private var fait: DoubleFait {
        session.double ?? DoubleFait(heures: ["--:--", "--:--"],
                                     minutes: session.minutes)
    }
    /// Le battement partagé par tout (halo, braise, fumée) — il part du
    /// slam : le premier coup EST l'atterrissage.
    private var bat: Double {
        t >= DoubleCine.slamAt ? DoubleCine.battement(t - DoubleCine.slamAt) : 0
    }
    private var l: CGFloat { min(size.width * 0.80, 332) }
    private var h: CGFloat { l * 1.32 }
    private var centre: CGPoint {
        CGPoint(x: size.width * 0.50, y: size.height * 0.55)
    }

    var body: some View {
        ZStack {
            Color.black

            pills
            if !Self.sansHalo { halo }
            carte
            miniHeures
        }
        .frame(width: size.width, height: size.height)
        .onChange(of: t >= DoubleCine.slamAt) { _, pose in
            if pose { SwapFeedback.shared.slam() }
        }
        // LE SECOND COUP — rigide, plus court que le slam.
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7),
                         trigger: t >= DoubleCine.coup2At)
        // Le grain doux de la pose de la pastille (D16).
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.45),
                         trigger: t >= DoubleCine.coup2At + 0.45)
    }

    // MARK: La pills énorme — par la GAUCHE

    private var pillsRepos: CGRect {
        let w = size.width * 1.5
        let hh = w * 1664 / 2648
        return CGRect(x: -w * 0.28, y: size.height * 0.34 - hh / 2,
                      width: w, height: hh)
    }

    private var pills: some View {
        let u = CGFloat(StoryCine.outLong(
            min(max((t - EndedCine.cut) / DoubleCine.poseFor, 0), 1)))
        let repos = pillsRepos
        let k0 = size.height * 1.15 / repos.height
        let k = k0 + (1 - k0) * u
        let c = CGPoint(x: repos.midX, y: repos.midY)
        let dx = (size.width / 2 - c.x) * (1 - u)
        let dy = (size.height / 2 - c.y) * (1 - u)
        // Le MIROIR : la même vidéo que TOP, retournée — le corps sort
        // par la gauche. Transform seul, jamais un redimensionnement.
        return CalqueVideo(nom: "story-pilule-top",
                           pose: "story-pilule-top-poster",
                           rate: paused ? 0 : 1)
            .frame(width: repos.width, height: repos.height)
            .scaleEffect(x: -k, y: k, anchor: .center)
            .offset(x: dx, y: dy)
            .position(x: c.x, y: c.y)
            .blendMode(.plusLighter)
    }

    // MARK: Le halo de page — noir, rouge, orange, qui pulse plus fort

    private var halo: some View {
        let allume = StoryCine.sstep(DoubleCine.coup2At - 0.05,
                                     DoubleCine.coup2At + DoubleCine.haloFor, t)
        // Amplitude 0,30 (TOP : 0,14) — sur le rythme ×2.
        let force = allume * (0.70 + 0.30 * bat)
        let orange = Color(red: 1.0, green: 0.55, blue: 0.10)
        let rouge = Color(red: 1.0, green: 0.20, blue: 0.05)
        let forme = RoundedRectangle(cornerRadius: 52, style: .continuous)
        // CADENCE (MESURÉ : 39 img/s complet contre 53 sans halo — trois
        // flous plein écran recalculés par image). Le contenu est
        // CONSTANT : on le RASTERISE une fois (`drawingGroup`) et seule
        // l'opacité bouge. Deux groupes — le noir et les chauds n'ont
        // pas la même rampe.
        return ZStack {
            // LE NOIR : l'écran s'ÉTEINT au bord — une vignette, pas une
            // couleur qui s'ajoute.
            forme
                .strokeBorder(Color.black.opacity(0.70), lineWidth: 44)
                .blur(radius: 34)
                .drawingGroup()
                .opacity(allume)
            ZStack {
                forme
                    .strokeBorder(orange.opacity(0.50), lineWidth: 26)
                    .blur(radius: 22)
                forme
                    .strokeBorder(rouge.opacity(0.45), lineWidth: 12)
                    .blur(radius: 8)
            }
            .drawingGroup()
            .blendMode(.plusLighter)
            .opacity(force)
        }
        .padding(2)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: La card

    private static let forme = RoundedRectangle(cornerRadius: 36,
                                                style: .continuous)

    private var carte: some View {
        let u = StoryCine.sstep(DoubleCine.cardAt,
                                DoubleCine.cardAt + DoubleCine.cardFor, t)
        let k = 1.6 - 0.6 * CGFloat(StoryCine.outLong(u, 3.0))
        // LE SECOND COUP : une cloche d'échelle de 2,5 % — la card
        // re-frappe 0,28 s après s'être posée.
        let u2 = min(max((t - DoubleCine.coup2At) / 0.16, 0), 1)
        let coup = 1 + 0.025 * CGFloat(sin(.pi * u2))
        let settle: CGFloat = t <= DoubleCine.slamAt ? 1
            : 1 - 0.006 * CGFloat(exp(-(t - DoubleCine.slamAt) / 0.16)
                * sin((t - DoubleCine.slamAt) * 15))
        let rouge = Color(red: 1.0, green: 0.30, blue: 0.10)
        return ZStack {
            projecteur
            pastille
            VStack(spacing: 6) {
                Text("Double day")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color(white: 0.97))
                    .opacity(StoryCine.sstep(DoubleCine.sousAt - 0.15,
                                             DoubleCine.sousAt + 0.25, t))
                Text("Two sessions today.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(white: 0.62))
                    .opacity(StoryCine.sstep(DoubleCine.sousAt,
                                             DoubleCine.sousAt + 0.4, t))
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 34)
        }
        .frame(width: l, height: h)
        .overlay {
            PoudreStory(largeur: l, hauteur: h, naissance: naissance,
                        nappe: l / 2, gain: 1.4)
                .opacity(StoryCine.sstep(DoubleCine.coup2At,
                                         DoubleCine.coup2At + 0.6, t))
        }
        .background {
            ZStack {
                // Plus noir que TOP : dark/white, aucun gris tiède.
                Self.forme.fill(
                    LinearGradient(colors: [Color(white: 0.07),
                                            Color(white: 0.015)],
                                   startPoint: .top, endPoint: .bottom))
                texteGeant
                if !Self.sansFumee { fumee }
                // Le fil rouge d'arête — l'écho du halo, discret.
                Self.forme.strokeBorder(
                    LinearGradient(
                        stops: [.init(color: rouge.opacity(0.30),
                                      location: 0),
                                .init(color: .clear, location: 0.55)],
                        startPoint: .bottomTrailing, endPoint: .topLeading),
                    lineWidth: 1.4)
                // La crête angulaire (A1), en BLANC plus franc — la seule
                // lumière froide de la scène.
                Self.forme.strokeBorder(
                    AngularGradient(
                        stops: [.init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.42),
                                      location: 0.115),
                                .init(color: .clear, location: 0.24),
                                .init(color: .clear, location: 1)],
                        center: .center,
                        angle: .degrees(-56 + 4 * sin(t * 0.571))),
                    lineWidth: 1.2)
            }
        }
        .clipShape(Self.forme)
        .scaleEffect(k * settle * coup)
        .modifier(SoftBlur(radius: (1 - CGFloat(u)) * 10))
        .opacity(min(1, u * 2.2))
        .position(centre)
    }

    // MARK: Le projecteur — la mini-card ÉCLAIRE le ×2

    /// « Un effet spotlight sur le x2, au niveau de Twice today »
    /// (verdict) : la mini-card n'est plus posée à côté — elle est la
    /// SOURCE. Un éventail descend de son bord (l'école `LampeEventail`
    /// de la robe spotlight : deux nappes, la large et le cœur, flancs
    /// FONDUS — jamais d'arête franche, un trait net sur du noir est de
    /// l'encre, pas de la lumière), incliné vers le centre, et il
    /// s'AVIVE au battement ×2.
    private var projecteur: some View {
        let m = StoryCine.sstep(DoubleCine.miniAt + 0.10,
                                DoubleCine.miniAt + 0.70, t)
        // La source : le coin bas-droit de la mini-card (elle est à
        // gauche, la pastille est au centre) — le faisceau part de là.
        let source = CGPoint(x: l * 0.50 - l * 0.27 + l * 0.10,
                             y: h * 0.50 - h * 0.30 + 26)
        let vif: Double = 0.72 + 0.28 * bat
        let large = EventailX2()
            .fill(LinearGradient(
                stops: [.init(color: .white.opacity(0.30), location: 0),
                        .init(color: .white.opacity(0.09), location: 0.5),
                        .init(color: .clear, location: 1)],
                startPoint: .top, endPoint: .bottom))
            .mask(LinearGradient(
                stops: [.init(color: .clear, location: 0.04),
                        .init(color: .white, location: 0.30),
                        .init(color: .white, location: 0.70),
                        .init(color: .clear, location: 0.96)],
                startPoint: .leading, endPoint: .trailing))
            .blur(radius: 14)
            .frame(width: l * 0.86, height: h * 0.52)
        let coeur = EventailX2()
            .fill(LinearGradient(
                stops: [.init(color: .white.opacity(0.46), location: 0),
                        .init(color: .white.opacity(0.13), location: 0.4),
                        .init(color: .clear, location: 1)],
                startPoint: .top, endPoint: .bottom))
            .mask(LinearGradient(
                stops: [.init(color: .clear, location: 0.22),
                        .init(color: .white, location: 0.42),
                        .init(color: .white, location: 0.58),
                        .init(color: .clear, location: 0.78)],
                startPoint: .leading, endPoint: .trailing))
            .blur(radius: 10)
            .frame(width: l * 0.60, height: h * 0.42)
        return ZStack(alignment: .top) {
            large
            coeur
        }
        .compositingGroup()
        .opacity(m * vif)
        .blendMode(.screen)
        // Le faisceau est ANCRÉ à sa source et penche vers le centre.
        .rotationEffect(.degrees(19), anchor: .top)
        .position(x: source.x, y: source.y)
        .frame(width: l, height: h)
        .allowsHitTesting(false)
    }

    // MARK: La fumée du footer

    /// « Une alternance de fumée rouge, noire et blanche » : le shader
    /// `fumeeX2` BORNÉ à la bande basse de la card (0,36·h), trois
    /// panaches dont la TEINTE glisse rouge → noir → blanc sur 14 s,
    /// décalées d'un tiers — à tout instant les trois couleurs
    /// coexistent. Le noir se lit parce qu'il ASSOMBRIT ; le blanc et le
    /// rouge sont retenus (jamais saturés). Elle MONTE du bord bas après
    /// le second coup — la card se pose, puis elle fume.
    private var fumee: some View {
        let bande = h * 0.44
        let monte = StoryCine.sstep(DoubleCine.coup2At + 0.15,
                                    DoubleCine.coup2At + 0.15
                                        + DoubleCine.fumeeFor, t)
        // L'HORLOGE À 30 Hz : le shader ne se recalcule qu'une image sur
        // deux (la fumée est lente — personne ne voit 30 contre 60).
        let tq: Double = (t * 30).rounded() / 30
        let batq: Double = (bat * 20).rounded() / 20
        let teintes: [Color] = (0 ..< 3).map { k in
            Self.teinteFumee(phase: (tq / 14 + Double(k) / 3)
                .truncatingRemainder(dividingBy: 1))
        }
        return ZStack(alignment: .bottom) {
            // LA BRUME CLAIRE AU PIED : la fumée NOIRE ne se lit que sur
            // du non-noir — un voile gris chaud que le noir CREUSE.
            LinearGradient(
                stops: [.init(color: .clear, location: 0),
                        .init(color: Color(red: 0.16, green: 0.13,
                                           blue: 0.12), location: 1)],
                startPoint: .top, endPoint: .bottom)
                .frame(width: l, height: bande)
            Rectangle()
                .fill(Color.black)
                .frame(width: l, height: bande)
                .colorEffect(ShaderLibrary.fumeeX2(
                    .float2(Float(l), Float(bande)),
                    .float(Float(tq)),
                    .float(Float(batq)),
                    .color(teintes[0]),
                    .color(teintes[1]),
                    .color(teintes[2])))
        }
            .mask {
                LinearGradient(
                    stops: [.init(color: .clear, location: 0),
                            .init(color: .white, location: 0.38),
                            .init(color: .white, location: 1)],
                    startPoint: .top, endPoint: .bottom)
            }
            .offset(y: (1 - CGFloat(monte)) * bande * 0.6)
            .opacity(monte)
            .frame(width: l, height: h, alignment: .bottom)
    }

    /// La partition des teintes : rouge (0-⅓) → noir (⅓-⅔) → blanc
    /// (⅔-1), fondus triangulaires — l'alpha porte l'intensité de chaque
    /// matière (le noir plus dense, le blanc retenu).
    private static func teinteFumee(phase: Double) -> Color {
        func poids(_ c: Double) -> Double {
            var d = abs(phase - c)
            d = min(d, 1 - d)
            return max(0, 1 - d * 3)
        }
        let wr = poids(1.0 / 6), wn = poids(0.5), wb = poids(5.0 / 6)
        let s = max(0.001, wr + wn + wb)
        let r = (1.00 * wr + 0.00 * wn + 0.96 * wb) / s
        let g = (0.16 * wr + 0.00 * wn + 0.94 * wb) / s
        let b = (0.05 * wr + 0.00 * wn + 0.92 * wb) / s
        let a = (0.66 * wr + 0.90 * wn + 0.52 * wb) / s
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    // MARK: Le texte géant — ARGENT

    private var texteGeant: some View {
        let lignes = ["TWICE", "TODAY"]
        let corps = l * 1.16 / 5
        let mots = VStack(spacing: -corps * 0.35) {
            ForEach(lignes.indices, id: \.self) { i in
                Text(lignes[i])
                    .font(.system(size: corps * 1.55, weight: .black))
                    .tracking(-corps * 0.04)
                    .fixedSize()
            }
        }
        return ZStack {
            mots
                .foregroundStyle(LinearGradient(
                    colors: [Color(white: 0.98),
                             Color(red: 0.78, green: 0.79, blue: 0.84),
                             Color(white: 0.40)],
                    startPoint: .top, endPoint: .bottom))
            nappesBlanches
                .mask { mots }
                .blendMode(.plusLighter)
        }
        .frame(width: l)
        .mask {
            LinearGradient(
                stops: [.init(color: .clear, location: 0),
                        .init(color: .white, location: 0.18),
                        .init(color: .white, location: 0.82),
                        .init(color: .clear, location: 1)],
                startPoint: .leading, endPoint: .trailing)
        }
        .mask {
            LinearGradient(
                stops: [.init(color: .white, location: 0),
                        .init(color: .white.opacity(0.66), location: 0.44),
                        .init(color: .white.opacity(0.16), location: 0.70),
                        .init(color: .clear, location: 0.88)],
                startPoint: .top, endPoint: .bottom)
        }
        .opacity(0.55 * StoryCine.sstep(DoubleCine.cardAt + 0.25,
                                        DoubleCine.cardAt + 0.85, t))
        .frame(width: l, height: h, alignment: .top)
        .offset(y: -6)
    }

    private var nappesBlanches: some View {
        let periodes: [Double] = [3.7, 5.3, 7.1, 4.3, 6.7, 9.1, 5.9]
        return ZStack {
            ForEach(0 ..< 7, id: \.self) { i in
                let h1 = Self.hashX2(i, 1)
                let h2 = Self.hashX2(i, 2)
                let h3 = Self.hashX2(i, 3)
                let u = (t / periodes[i] + h1)
                    .truncatingRemainder(dividingBy: 1)
                let bosse = pow(max(0, sin(.pi * u)), 6.0)
                let derive = CGFloat(sin(t * (0.21 + 0.11 * h2)
                    + h3 * 6.28))
                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.55), .clear],
                        center: .center, startRadius: 0,
                        endRadius: l * CGFloat(0.13 + 0.10 * h2)))
                    .frame(width: l * CGFloat(0.30 + 0.24 * h2),
                           height: l * CGFloat(0.24 + 0.18 * h3))
                    .offset(x: l * (CGFloat(h1) - 0.5) * 1.05
                            + derive * l * 0.03,
                            y: l * (CGFloat(h3) - 0.5) * 0.85)
                    .opacity(bosse)
            }
        }
        .blur(radius: 6)
        .opacity(StoryCine.sstep(DoubleCine.slamAt,
                                 DoubleCine.slamAt + 0.8, t))
    }

    private static func hashX2(_ i: Int, _ k: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return v - floor(v)
    }

    // MARK: La pastille ×2 et sa braise

    private var pastille: some View {
        let cote = l * 0.34
        // TOUT EST PRÉ-TYPÉ (la loi du type-checker).
        let vif: Double = Double(JaugeVent.flicker(Float(t), phase: 2.3))
        let opCatch: Double = 0.24 + 0.06 * vif
        let rayonCatch: CGFloat = cote * 0.22
        let nais = StoryCine.sstep(DoubleCine.coup2At + 0.05,
                                   DoubleCine.coup2At + 0.50, t)
        let n = CGFloat(nais)
        let flotte = n * CGFloat(sin(t * 0.62) * 6
            + sin(t * 1.13 + 0.9) * 2.5)
        let derive = n * CGFloat(cos(t * 0.47 + 1.4) * 4)
        let souffle = 1 + 0.022 * CGFloat(sin(t * 0.83)) * n
        // LA BRAISE ×2 : le x2 gravé s'éclaire de l'intérieur et BAT —
        // 0,16 au repos, 0,46 au coup ; et une lueur qui déborde de la
        // pastille à chaque battement.
        let braise: Double = 0.16 + 0.30 * bat
        let deborde: Double = 0.12 * bat
        let rouge = Color(red: 1.0, green: 0.22, blue: 0.06)
        return Image("sticker-pastille-fois2")
            .resizable()
            .scaledToFit()
            .frame(width: cote, height: cote)
            .overlay {
                Ellipse()
                    .fill(RadialGradient(
                        colors: [rouge.opacity(braise), .clear],
                        center: .center, startRadius: 0,
                        endRadius: cote * 0.34))
                    .frame(width: cote * 0.68, height: cote * 0.46)
                    .offset(x: cote * 0.02, y: -cote * 0.02)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: rayonCatch,
                                 style: .continuous)
                    .fill(EllipticalGradient(
                        stops: [.init(color: .white.opacity(opCatch),
                                      location: 0),
                                .init(color: .white.opacity(0.06),
                                      location: 0.40),
                                .init(color: .clear, location: 0.9)],
                        center: UnitPoint(x: 0.30, y: 0.22),
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.5))
                    .blendMode(.screen)
                    .padding(2)
                    .allowsHitTesting(false)
            }
            .background(
                Circle()
                    .fill(RadialGradient(
                        stops: [.init(color: rouge.opacity(deborde),
                                      location: 0),
                                .init(color: .white.opacity(0.10),
                                      location: 0.35),
                                .init(color: .clear, location: 1)],
                        center: .center,
                        startRadius: 0, endRadius: cote))
                    .frame(width: cote * 1.7, height: cote * 1.7)
                    .blur(radius: 13)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false))
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(0.5 * nais
                        - Double(flotte) * 0.012))
                    .frame(width: cote * 0.62 + flotte * 1.5,
                           height: cote * 0.10)
                    .blur(radius: 9)
                    .offset(y: cote * 0.16)
                    .allowsHitTesting(false)
            }
            .scaleEffect(x: souffle * (0.94 + 0.06 * n)
                * (1 + 0.03 * CGFloat(sin(.pi * nais))),
                         y: souffle * (0.94 + 0.06 * n)
                * (1 - 0.03 * CGFloat(sin(.pi * nais))))
            .opacity(nais)
            .offset(x: derive, y: flotte - (1 - n) * 6)
    }

    // MARK: La mini-card des deux heures — néon BLANC, à gauche

    private var miniHeures: some View {
        let m = StoryCine.sstep(DoubleCine.miniAt,
                                DoubleCine.miniAt + DoubleCine.miniFor, t)
        let phase = t - DoubleCine.miniAt
        let blanc = Color(white: 0.98)
        // Le néon S'AMORCE en deux temps (gris 0,1 s, puis blanc plein).
        let encre: Color = phase < 0.10 ? Color(white: 0.35)
            : (phase < 0.20 ? Color(white: 0.62) : blanc)
        let plein: Double = phase < 0.20 ? 0.3 : 1
        let heures = fait.heures.prefix(2).joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 3) {
            Text("Twice today")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(white: 0.52))
            Text(heures)
                .font(.system(size: 21, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(encre)
                .shadow(color: blanc.opacity(0.90 * plein), radius: 3)
                .shadow(color: blanc.opacity(0.45 * plein), radius: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.13),
                                              Color(white: 0.05)],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [.init(color: .white.opacity(0.26),
                                      location: 0),
                                .init(color: .white.opacity(0.04),
                                      location: 0.5),
                                .init(color: .clear, location: 1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    lineWidth: 1)
        }
        .rotationEffect(.degrees(-14 + 7 * m))
        .scaleEffect(1 + 0.10 * CGFloat(sin(.pi * m)))
        .offset(x: CGFloat(1 - m) * 30)
        .opacity(m)
        // MESURÉ au film : à 0,44·l elle sortait de l'écran (elle est
        // plus large que « 42 min ») — 0,27·l, ~55 % dedans.
        .position(x: size.width * 0.50 - l * 0.27,
                  y: size.height * 0.55 - h * 0.30)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.6),
                         trigger: t >= DoubleCine.miniAt + 0.25)
    }
}

/// L'ÉVENTAIL DU PROJECTEUR ×2 — le cône de la lampe, PROPORTIONNEL (la
/// forme de la robe spotlight est `private` dans RewardCard et calée en
/// points fixes ; ici la card change de taille). Col étroit à la source,
/// ouverture large au pied.
private struct EventailX2: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let col = r.width * 0.09
        let pied = r.width * 0.50
        p.move(to: CGPoint(x: r.midX - col, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + col, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + pied, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX - pied, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
