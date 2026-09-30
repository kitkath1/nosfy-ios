import SwiftUI

// MARK: - La cérémonie de la légendaire — elle sort de la lumière (30-09-2026)

/// LA SORTIE D'UNE QUATRE LUNES (PLAN-LEGENDAIRE-PLONGEE § 3) : une orange
/// sort du sachet ; une légendaire sort d'une PORTE DE LUMIÈRE qui se
/// referme sur elle. Aucun éclair, aucun balayage : la seule lumière est
/// celle de la porte, qui a un bord, et c'est elle qui allume la gravure
/// pendant que la lame tourne.
///
///   0,0 s  noir total
///   0,4 s  un point blanc au centre, qui s'étire en un cheveu vertical de 1 px
///   0,9 s  le cheveu s'écarte en une fente de 12 pt, deux bords nets
///   1,2 s  la carte sort de la fente PAR LA TRANCHE et tourne vers elle
///          (1,2 s) ; sa gravure prend la lumière de la porte, arête après
///          arête
///   2,4 s  face à elle : la vie s'éveille (braises, neige, nacre)
///   2,4 s  la porte se referme derrière la carte et meurt ; le temps de la
///          météo ralentit au tiers jusqu'à 4,0 s
///   4,0 s  le temps reprend ; sous la carte, gravé : le nom · Quatre Lunes ·
///          le monde
///
/// AU MANÈGE (BoosterLab) : jouée une fois quand une légendaire est révélée
/// et que sa matière publiée est prête, par-dessus l'étage résultat, puis
/// fondue en lui. AU BANC : `-luneLab -luneCarte <nom> -luneCeremonie`,
/// rejouée toutes les 7 s pour la filmer. Une seule horloge, le temps
/// d'une cérémonie.
struct CeremonieLegendaire: View {
    var art: Image
    var depth: Image
    var matiere: LuneMatiere
    var nom: String
    var monde: String
    /// Rejouer en boucle (banc) — sinon une fois, puis la carte reste posée.
    var boucle = false
    /// La taille et la place de la carte à l'arrivée : au manège, CELLES de
    /// la carte vivante de l'étage résultat — la cérémonie se fond en elle
    /// sans un saut. nil : le gabarit de la carte vivante plein écran.
    var taille: CGSize? = nil
    var decalageY: CGFloat = 0

    @State private var depart = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let periode: Double = 7

    private static func ease(_ a: Double, _ b: Double, _ v: Double) -> Double {
        let t = max(0, min(1, (v - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    /// L'âge de la cérémonie (Reduce Motion : la carte déjà posée).
    private func age(_ date: Date) -> Double {
        if reduceMotion { return 5 }
        let a = date.timeIntervalSince(depart)
        return boucle ? a.truncatingRemainder(dividingBy: Self.periode) : a
    }

    /// Le temps de la météo : il ralentit au tiers pendant que la porte se
    /// referme (2,6 → 4,0 s), puis reprend — jamais de saut.
    private static func tempsMeteo(_ t: Double) -> Float {
        let base = 100.0
        if t < 2.6 { return Float(base + t) }
        if t < 4.0 { return Float(base + 2.6 + (t - 2.6) / 3) }
        return Float(base + 2.6 + 1.4 / 3 + (t - 4.0))
    }

    var body: some View {
        GeometryReader { geo in
            let cs = taille ?? CarteVivante.cardSize(in: geo.size)
            TimelineView(.animation) { tl in
                let t = age(tl.date)
                ZStack {
                    Color.black
                    ZStack {
                        porte(t, carte: cs)
                        carte(t, taille: cs)
                        legende(t)
                            .offset(y: cs.height / 2 + 34)
                    }
                    .offset(y: decalageY)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .onAppear { depart = Date() }
    }

    // MARK: La porte

    /// Un point, un cheveu, une fente — puis la fente se referme et meurt.
    /// Blanc pur, bloom ≤ 4 pt ; elle vit DERRIÈRE la carte.
    private func porte(_ t: Double, carte cs: CGSize) -> some View {
        let naissance = Self.ease(0.4, 0.9, t)
        let ouverture = Self.ease(0.9, 1.2, t) * (1 - Self.ease(2.4, 3.4, t))
        let vie = t < 0.4 ? 0 : (1 - Self.ease(3.0, 3.8, t))
        // Pas plus haute que la carte : une fois de face, la carte la cache
        // entièrement — plus grande, ses deux bouts dépassaient et la carte
        // semblait pendue à une tige (vu au film du 30-09).
        let hauteur = max(2, cs.height * 0.94 * naissance)
        let ecart = 12 * ouverture
        return ZStack {
            // Le jour entre les deux bords : une lumière douce, bornée.
            Rectangle()
                .fill(Color.white.opacity(0.16 * ouverture))
                .frame(width: ecart, height: hauteur)
            bord(hauteur).offset(x: -ecart / 2)
            bord(hauteur).offset(x: ecart / 2)
        }
        .opacity(vie)
        .allowsHitTesting(false)
    }

    private func bord(_ hauteur: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 1, height: hauteur)
            .shadow(color: .white.opacity(0.55), radius: 2.5)
    }

    // MARK: La carte

    /// La lame sort de la fente par la tranche (88° → 0°) ; la lampe du
    /// monde est la porte : elle glisse du rasant au frontal à mesure que la
    /// carte tourne, et la gravure s'allume arête après arête.
    @ViewBuilder
    private func carte(_ t: Double, taille cs: CGSize) -> some View {
        if t >= 1.2 {
            let tour = Self.ease(1.2, 2.4, t)
            let angle = 88 * (1 - tour)
            let porteLampe = Float(-0.9 * (1 - tour))
            CarteLuneCard(size: cs,
                          tilt: SIMD2(porteLampe, 0.05),
                          t: Self.tempsMeteo(t),
                          foil: 1,
                          art: art, depth: depth, matiere: matiere,
                          vie: Float(Self.ease(2.4, 2.8, t)))
                .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0),
                                  perspective: 0.42)
                .scaleEffect(0.94 + 0.06 * tour)
                .opacity(Self.ease(1.2, 1.32, t))
        }
    }

    // MARK: Le nom, gravé

    private func legende(_ t: Double) -> some View {
        VStack(spacing: 6) {
            Text(nom.uppercased())
                .font(.system(size: 15, weight: .semibold))
                .tracking(3.5)
                .foregroundStyle(LinearGradient(
                    colors: [.white, .white.opacity(0.62)],
                    startPoint: .top, endPoint: .bottom))
            Text(L("Quatre Lunes", "Four Moons") + " · " + monde)
                .font(.system(size: 11, weight: .regular))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.42))
        }
        .opacity(Self.ease(4.0, 4.6, t))
        .allowsHitTesting(false)
    }
}
