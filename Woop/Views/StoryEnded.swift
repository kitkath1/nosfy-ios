import SwiftUI

// MARK: - La partition

/// « SESSION ENDED » — le nouvel écran 1 de la story
/// (tools/story/PLAN-STORY-V2-ENDED.md). Deux actes sur UNE page du chef
/// d'orchestre : une coupe de page au milieu du plongeon tuerait la
/// cinématique. Tout est fonction pure de `t`, école `StoryCine`.
enum EndedCine {
    // ── Acte A : la verrière ──
    /// La naissance : la caméra est DÉJÀ dans le texte (verdict tour 3 :
    /// « de base ça doit être zoomé » — le zoom-depuis-petit était
    /// l'effet cheap, il est MORT).
    static let naissanceAt = 0.06, naissanceFor = 0.55
    /// LE TRAVELLING : toute la ligne défile devant la caméra à pleine
    /// échelle — c'est LA passe de lecture, l'école du site M5.
    static let travelAt = 0.7, travelFor = 2.7
    /// LE PLONGEON : la course s'arrête sur la lettre-cible et l'échelle
    /// repart, dérivée FORTE à la fin — on coupe au sommet du mouvement.
    static let diveAt = 3.4, diveFor = 1.0
    /// L'ÉCHANGE SEC. Jamais un fondu : la couche entrante (la pilule de
    /// l'acte B) est montée et DÉCODÉE depuis `diveAt` — la loi du flash
    /// noir dit qu'un fondu vers une couche qui n'a pas encore produit son
    /// image se mélange à du NOIR.
    static let cut = 4.4

    // ── Acte B : le résumé ──
    /// Le reflux : la pilule plein cadre recule et se pose en haut à droite.
    static let poseFor = 0.9
    static let eclairAt = 5.1, eclairFor = 0.6
    /// La card se matérialise : le voile noir AU-DESSUS du verre s'éteint
    /// (le verre ignore `.opacity` — on fond un calque, jamais le verre).
    static let cardAt = 5.3, cardFor = 0.7
    static let lignesAt = 5.8

    // ── Les échelles ──
    /// Le rapport du zoom fou. C'est AUSSI l'échelle du LAYOUT : le
    /// composite se construit à la taille du défilement et l'échelle anime
    /// DE PETIT À 1,0 — on réduit un grand tampon (net par construction),
    /// on ne grossit jamais un petit (la loi du zoom rastérisé, payée sur
    /// le dézoom de StoryOne).
    static let punch: CGFloat = 4.0
    /// Le sommet du plongeon, en multiples du repos. 12 coupait en plein
    /// zoom (la lettre entière encore à l'écran — mesuré au sim) : à 34,
    /// le bol de la lettre-cible mange l'écran et la coupe tombe DANS le
    /// verre. Au-delà du tampon ×4 le raster grossit ~2× — de la matière
    /// douce en plein mouvement, les arêtes du glyphe sont déjà sorties.
    static let dive: CGFloat = 34.0

    /// Le corps du texte AU LAYOUT (donc déjà ×4) : le repos est retrouvé
    /// par MESURE (kRepos = largeur visée / largeur mesurée du composite),
    /// jamais par les métriques supposées de la police.
    static let corps: CGFloat = 190

    /// Une entrée qui accélère : dérivée nulle au départ, forte à l'arrivée
    /// — le miroir de `outLong`, pour un plongeon qui se termine en coupe.
    static func inLong(_ u: Double, _ k: Double = 2.6) -> Double {
        let c = min(max(u, 0), 1)
        return pow(c, k)
    }
}

// MARK: - L'écran

struct StoryEnded: View {
    let session: StorySession
    /// Le temps de page, pause déduite (l'horloge du chef d'orchestre).
    let t: Double
    let now: Date
    let size: CGSize
    var paused: Bool = false

    /// Les cadres des deux mots dans le repère du composite — MESURÉS.
    @State private var motRects: [String: CGRect] = [:]
    @State private var verriereSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black

            // L'ACTE A vit jusqu'à la coupe ; l'ACTE B est monté dès le
            // plongeon (sa vidéo décode en aveugle) et prend l'écran à la
            // coupe, en une image.
            if t < EndedCine.cut { acteA }
            if t >= EndedCine.diveAt { acteB.opacity(t >= EndedCine.cut ? 1 : 0) }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        // LA PARTITION HAPTIQUE. Des beats dérivés de t : un impact doux
        // au départ du travelling puis un grain par mot qui passe ; LE
        // SLAM à la coupe — on rentre DANS la pills, c'est l'atterrissage
        // le plus lourd de la maison ; un impact doux quand la card se
        // matérialise. ⚠️ Le sim est muet : verdict téléphone.
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55),
                         trigger: beatTravel)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5),
                         trigger: t >= EndedCine.cardAt)
        .onChange(of: t >= EndedCine.cut) { _, coupe in
            if coupe { SwapFeedback.shared.slam() }
        }
    }

    // MARK: - Acte A — la verrière

    private var acteA: some View {
        let k = echelle
        let f = focus
        let cx = verriereSize.width / 2
        let cy = verriereSize.height / 2
        // Le point visé reste au centre de l'écran : l'offset compense
        // l'échelle. (Géométrie simple parce que l'ancre du scale est le
        // centre du composite.)
        let dx = (cx - f.x) * k
        let dy = (cy - f.y) * k
        let naissance = StoryCine.sstep(EndedCine.naissanceAt,
                                        EndedCine.naissanceAt
                                            + EndedCine.naissanceFor, t)
        return verriere
            .fixedSize()
            .scaleEffect(k, anchor: .center)
            .position(x: size.width / 2 + dx, y: size.height / 2 + dy)
            .opacity(naissance)
    }

    /// Les deux mots, chacun sur SON verre. La forme robuste : le glyphe
    /// transparent donne la taille, la vidéo vit en OVERLAY (elle n'enfle
    /// pas l'hôte), et le MÊME glyphe fait le masque. ⚠️ `CalqueVideo`
    /// porte son `clipsToBounds` interne — un `.mask` SwiftUI ne rattrape
    /// JAMAIS le débord d'une couche UIKit, ici il n'a rien à rattraper.
    private var verriere: some View {
        HStack(spacing: EndedCine.corps * 0.24) {
            mot("Session", nom: "story-ended-verre-a")
            mot("Ended", nom: "story-ended-verre-b")
        }
        .coordinateSpace(name: "verriere")
        .onGeometryChange(for: CGSize.self) { $0.size } action: {
            verriereSize = $0
        }
    }

    private func mot(_ texte: String, nom: String) -> some View {
        let glyphe = Text(texte).font(.inter(EndedCine.corps, .bold))
        return glyphe
            .foregroundStyle(.clear)
            .overlay {
                ZStack {
                    // Le SOCLE du glyphe — l'école ChiffreRevele : une
                    // lettre presque invisible SOUS la vidéo, pour que la
                    // forme se lise même là où le verre est noir. Sans lui
                    // la verrière ne « ressort » pas du noir de la page.
                    // 0,13 : mesuré au sim — à 0,105 le repos restait
                    // sous le seuil de lecture.
                    Color(white: 0.13)
                    CalqueVideo(nom: nom, pose: nom + "-poster",
                                rate: paused ? 0 : 1)
                }
            }
            .mask { glyphe }
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .named("verriere"))
            } action: { motRects[texte] = $0 }
    }

    /// L'échelle visuelle du composite. Plus de « repos petit » : la
    /// naissance est une approche IMPERCEPTIBLE (0,94 → 1), jamais un
    /// bounce ni un zoom d'entrée.
    private var echelle: CGFloat {
        if t < EndedCine.diveAt {
            return 0.94 + 0.06 * CGFloat(StoryCine.sstep(0, 0.70, t))
        }
        // Le plongeon : 1 → dive/punch, en accélérant jusqu'à la coupe.
        let u = EndedCine.inLong((t - EndedCine.diveAt) / EndedCine.diveFor)
        return 1 + (EndedCine.dive / EndedCine.punch - 1) * CGFloat(u)
    }

    /// Le point visé, dans le repère du composite. LE DÉPART : le début
    /// de la ligne, le « S » posé près du bord gauche — on n'a jamais vu
    /// la phrase entière. LE TRAVELLING glisse jusqu'à la cible du
    /// plongeon : le « n » d'Ended (minX + 0,26·l) — c'est là que
    /// l'aspectFill pose le bulbe AMBRÉ du verre B, l'intérieur de la
    /// lettre est incandescent à la coupe et la pills qui suit est de la
    /// même chair. Le voyage FINIT sur la cible à vitesse nulle, le
    /// plongeon repart de zéro — pas d'angle à la jonction.
    private var focus: CGPoint {
        let session = motRects["Session"]
            ?? CGRect(origin: .zero, size: verriereSize)
        let ended = motRects["Ended"]
            ?? CGRect(origin: .zero, size: verriereSize)
        let depart = CGPoint(x: session.minX + size.width / 2 - 28,
                             y: session.midY)
        let cible = CGPoint(x: ended.minX + ended.width * 0.26,
                            y: ended.midY)
        if t < EndedCine.travelAt { return depart }
        let u = CGFloat(StoryCine.sstep(EndedCine.travelAt,
                                        EndedCine.travelAt
                                            + EndedCine.travelFor, t))
        return CGPoint(x: depart.x + (cible.x - depart.x) * u,
                       y: depart.y + (cible.y - depart.y) * u)
    }

    // MARK: - La partition haptique

    /// Les BEATS du travelling : un entier dérivé de `t` — jamais un
    /// grain par image, la trame du moteur sature. 1 au départ du
    /// travelling, +1 quand chaque mot passe le centre de l'écran.
    private var beatTravel: Int {
        guard t >= EndedCine.travelAt else { return 0 }
        var n = 1
        let f = focus.x
        if let s = motRects["Session"], f > s.midX { n += 1 }
        if let e = motRects["Ended"], f > e.minX + e.width * 0.10 { n += 1 }
        return n
    }

    // MARK: - Acte B — le résumé

    /// La pilule au repos, TOUR 4 : elle se RANGE dans le coin
    /// haut-droit (« pas faire le haut du texte ! ») — plus petite, le
    /// corps qui déborde par le coin, le haut-gauche rendu au NOIR de la
    /// phrase. Ratio du fichier 1206/964.
    private var piluleRepos: CGRect {
        let w = size.width * 0.62
        let h = w * 964 / 1206
        return CGRect(x: size.width - w * 0.82, y: -h * 0.16,
                      width: w, height: h)
    }

    private var acteB: some View {
        // Le reflux : sortie à traîne longue — la pilule arrive à vitesse
        // NULLE dans son coin, aucune jonction anguleuse.
        let u = CGFloat(StoryCine.outLong(
            min(max((t - EndedCine.cut) / EndedCine.poseFor, 0), 1)))
        let repos = piluleRepos
        // Au départ (u = 0) : la pilule couvre l'écran, centrée.
        let k0 = size.height * 1.15 / repos.height
        let k = k0 + (1 - k0) * u
        let centre = CGPoint(x: repos.midX, y: repos.midY)
        let dx = (size.width / 2 - centre.x) * (1 - u)
        let dy = (size.height / 2 - centre.y) * (1 - u)

        return ZStack {
            Color.black

            // LA PILLS, fondue comme sur la home : additif sur le noir —
            // le sombre disparaît par construction, le mouvement au repos
            // est CUIT dans le fichier. On TRANSFORME, on ne redimensionne
            // jamais (la loi de CalqueVideo).
            CalqueVideo(nom: "story-pilule-droite",
                        pose: "story-pilule-droite-poster",
                        rate: paused ? 0 : 1)
                .frame(width: repos.width, height: repos.height)
                // Le nez qui PLONGE vers la card — la diagonale de la
                // maquette (12° du tour 3 ne changeait pas la
                // composition, verdict tour 4). Rotation SwiftUI sûre :
                // additif sur noir, les bords noirs tournés n'ajoutent
                // rien.
                .rotationEffect(.degrees(32))
                .scaleEffect(k, anchor: .center)
                .offset(x: dx, y: dy)
                .position(x: centre.x, y: centre.y)
                .blendMode(.plusLighter)

            // L'ordre des couches est celui de la maquette : la phrase et
            // l'éclair passent SOUS la card — elle les recouvre.
            phrase
            eclair
            carte
        }
    }

    // MARK: La phrase

    /// « Kathryn, votre session du 12 juin » — le registre Apple de la
    /// maquette : SF bold, GRANDE, l'alternance blanc / gris par ligne.
    /// ⚠️ Le prénom est en dur, comme le « Bonjour Kathryn » de la home —
    /// la même dette, au même endroit du backlog.
    private var phrase: some View {
        let blanc = Color(white: 0.96)
        let gris = Color(white: 0.52)
        let lignes: [(String, Color)] = [
            ("Kathryn,", blanc),
            ("votre session", gris),
            (dateCourte, blanc)
        ]
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lignes.enumerated()), id: \.offset) { i, l in
                let a = EndedCine.cut + 0.35 + Double(i) * 0.12
                Text(l.0)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(l.1)
                    .opacity(StoryCine.sstep(a, a + 0.45, t))
                    .offset(y: (1 - CGFloat(
                        StoryCine.sstep(a, a + 0.50, t))) * 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: .topLeading)
        .padding(.leading, 24)
        .padding(.top, size.height * 0.09)
    }

    /// « du 12 janvier » — la date de la séance sans son chapeau
    /// (`dateLabel` = « Séance du … » côté vraie séance, « Session du … »
    /// côté démo calendrier).
    private var dateCourte: String {
        let l = session.dateLabel
        for prefixe in ["Séance ", "Session "] where l.hasPrefix(prefixe) {
            return String(l.dropFirst(prefixe.count))
        }
        return l
    }

    private var eclair: some View {
        let n = StoryCine.sstep(EndedCine.eclairAt,
                                EndedCine.eclairAt + EndedCine.eclairFor, t)
        let w = size.width * 0.36
        return CalqueVideo(nom: "story-eclair-loop",
                           pose: "story-eclair-loop-poster",
                           rate: paused ? 0 : 1)
            .frame(width: w, height: w * 1872 / 1016)
            .position(x: size.width * 0.21,
                      y: size.height - w * 1.02)
            .blendMode(.plusLighter)
            .opacity(n)
            .offset(y: (1 - CGFloat(n)) * 14)
    }

    // MARK: La card

    /// LA TAILLE DES CARDS REWARDS (verdict 26-08) : min(0,80·L, 332),
    /// ratio 1,32, rayon 36 continuous — le gabarit de RewardCard.
    /// LA MATIÈRE des petites cards exercice : une seule dalle
    /// `glassEffect(.clear)` et LA NUIT PAR-DESSUS qui se dissout — là où
    /// elle est pleine le verre n'existe pas, là où elle s'efface la
    /// pills remonte au travers (ExercisesView, la carte d'exercice).
    /// ⚠️ La card ne bouge JAMAIS en taille (le verre aux bounds vivants =
    /// blur plat), AUCUN `rotation3DEffect` (verre natif + tilt = le verre
    /// se détache). Sa naissance est un VOILE NOIR par-dessus qui s'éteint
    /// — le verre ignore `.opacity`.
    private static let formeCarte = RoundedRectangle(cornerRadius: 36,
                                                     style: .continuous)

    /// « Un poil moins de noir : juste les 30 % du haut, et après liquid
    /// glass » (verdict tour 3) — la nuit s'arrête tôt, les chiffres du
    /// bas vivent SUR le verre.
    private static let nuitCarte = LinearGradient(
        stops: [
            .init(color: .black, location: 0.0),
            .init(color: .black, location: 0.30),
            .init(color: .black.opacity(0.50), location: 0.45),
            .init(color: .black.opacity(0.15), location: 0.65),
            .init(color: .clear, location: 0.85)
        ],
        startPoint: .top, endPoint: .bottom)

    private var carte: some View {
        let l = min(size.width * 0.80, 332)
        let h = l * 1.32
        let voile = 1 - StoryCine.sstep(EndedCine.cardAt,
                                        EndedCine.cardAt + EndedCine.cardFor,
                                        t)
        return contenuCarte(l: l)
            .frame(width: l, height: h, alignment: .topLeading)
            .background {
                ZStack {
                    Self.formeCarte
                        .fill(Color.clear)
                        .glassEffect(.clear, in: Self.formeCarte)
                    Self.formeCarte.fill(Self.nuitCarte)
                }
            }
            .clipShape(Self.formeCarte)
            .overlay {
                Self.formeCarte
                    .fill(Color.black)
                    .opacity(voile)
            }
            .position(x: size.width * 0.50, y: size.height * 0.55)
    }

    /// « Police à la Apple, plus gros » : SF, blanc plat, les unités
    /// grises — le registre de la maquette. Les nombres COMPTENT.
    private func contenuCarte(l: CGFloat) -> some View {
        let blanc = Color(white: 0.97)
        let gris = Color(white: 0.52)
        return VStack(alignment: .leading, spacing: 0) {
            Text("Séance du jour")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(gris)
                .opacity(ligne(0))
            Rectangle()
                .fill(Color(white: 0.38))
                .frame(width: 26, height: 1.5)
                .padding(.top, 8)
                .opacity(ligne(0))
            Text("Résumé")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(blanc)
                .padding(.top, 18)
                .opacity(ligne(0))

            Spacer(minLength: 0)

            rangée(1, session.minutes, "min", blanc, gris)
            rangée(2, session.series, "séries", blanc, gris)
            rangée(3, session.exos, "exos", blanc, gris)
            rangée(4, session.kcal, "calories", blanc, gris)
        }
        .padding(28)
    }

    private func rangée(_ i: Int, _ valeur: Int, _ unite: String,
                        _ blanc: Color, _ gris: Color) -> some View {
        let depuis = EndedCine.lignesAt + Double(i - 1) * 0.11
        let montre = compte(valeur, depuis: depuis)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(montre)")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(blanc)
                .monospacedDigit()
                .contentTransition(.identity)
            Text(unite)
                .font(.system(size: 16))
                .foregroundStyle(gris)
        }
        .padding(.top, 10)
        .opacity(ligne(i))
    }

    private func ligne(_ i: Int) -> Double {
        let a = EndedCine.lignesAt + Double(i) * 0.11
        return StoryCine.sstep(a - 0.30, a + 0.30, t)
    }

    /// Le comptage, sortie douce — un compteur qui s'arrête net a l'air
    /// mécanique (l'école de StorySummaryCard).
    private func compte(_ valeur: Int, depuis a: Double) -> Int {
        let u = StoryCine.outLong(min(max((t - a) / 0.95, 0), 1), 2.6)
        return Int((Double(valeur) * u).rounded())
    }
}
