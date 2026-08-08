import SwiftUI

// MARK: - L'écran 1

/// L'entrée. Gros plan violent sur la lune de néon, puis un dézoom à traîne
/// longue ; la fenêtre se referme à 60 % de la hauteur et le récap monte
/// dessous.
struct StoryOne: View {
    let session: StorySession
    /// Le temps écoulé sur la page, pause déduite.
    let t: Double
    /// L'horloge murale, pour les shaders.
    let now: Date
    let size: CGSize
    var paused: Bool = false

    var body: some View {
        let winH = windowHeight
        let s = scale
        let vw = size.width * s
        let vh = vw / StoryFilm.aspectOne

        ZStack(alignment: .top) {
            Color.black

            // LA FENÊTRE. La couche reçoit sa taille au RATIO DE LA SOURCE :
            // c'est la condition pour que le fondu de pied tombe sur de
            // l'image et pas sur du noir.
            StoryReel(master: "story_1",
                      loopFile: "story_1_loop",
                      handoffFrame: StoryFilm.handoffFrame,
                      videoSize: CGSize(width: vw, height: vh),
                      paused: paused)
                .frame(width: size.width, height: winH, alignment: .center)
                .clipped()
                .mask(StoryFootFade(total: winH, fade: footFade))
                .frame(maxHeight: .infinity, alignment: .top)

            // LE RÉCIT
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0).frame(height: winH - 26)

                StoryTitle(text: session.title, t: t,
                           start: StoryCine.contentAt)

                Text(session.dateLabel)
                    .font(.inter(14))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.top, 7)
                    .opacity(fade(StoryCine.contentAt + 0.30, 0.5))
                    .offset(y: rise(StoryCine.contentAt + 0.30, 0.5, 10))

                StorySummaryCard(session: session, t: t, now: now,
                                 start: StoryCine.contentAt + 0.48)
                    .padding(.top, 22)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: La caméra

    /// La hauteur de la fenêtre : l'écran entier pendant l'intro, puis 60 %.
    private var windowHeight: CGFloat {
        let u = CGFloat(StoryCine.sstep(StoryCine.windowAt,
                                        StoryCine.windowAt + StoryCine.windowFor,
                                        t))
        let rest = size.height * StoryCine.windowShare
        return size.height + (rest - size.height) * u
    }

    /// Le fondu de pied n'apparaît qu'avec la fenêtre : pendant l'intro,
    /// l'image tient tout l'écran et n'a aucune raison de s'éteindre en bas.
    private var footFade: CGFloat {
        CGFloat(StoryCine.sstep(StoryCine.windowAt,
                                StoryCine.windowAt + StoryCine.windowFor, t)) * 112
    }

    /// L'ÉCHELLE. Elle entre dans la GÉOMÉTRIE de la couche, jamais dans un
    /// `scaleEffect` posé après un masque — sinon SwiftUI compose dans un
    /// tampon à la taille non zoomée et agrandit ce tampon : un zoom
    /// rastérisé, c'est-à-dire flou.
    private var scale: CGFloat {
        // L'échelle qui remplit exactement l'écran.
        let cover = size.height * StoryFilm.aspectOne / size.width
        if t < StoryCine.dezoom {
            let u = CGFloat(StoryCine.outLong(t / StoryCine.dezoom))
            return cover * (1 + (StoryCine.punch - 1) * (1 - u))
        }
        // Puis la fenêtre se referme et l'image se pose dans son cadre : les
        // deux rétrécissent ENSEMBLE, donc l'image a l'air de s'installer, pas
        // d'être rognée.
        let u = CGFloat(StoryCine.sstep(StoryCine.windowAt,
                                        StoryCine.windowAt + StoryCine.windowFor,
                                        t))
        return cover + (1.0 - cover) * u
    }

    private func fade(_ at: Double, _ dur: Double) -> Double {
        StoryCine.sstep(at, at + dur, t)
    }

    private func rise(_ at: Double, _ dur: Double, _ d: CGFloat) -> CGFloat {
        d * (1 - CGFloat(StoryCine.sstep(at, at + dur, t)))
    }
}

// MARK: - Le titre

/// Le titre arrive MOT À MOT : chaque mot monte de douze points en sortant
/// d'un flou. Un titre qui apparaît d'un bloc n'est pas animé, il est
/// simplement en retard.
struct StoryTitle: View {
    let text: String
    let t: Double
    let start: Double
    var stagger: Double = 0.075
    var dur: Double = 0.52

    var body: some View {
        let words = text.split(separator: " ").map(String.init)
        HStack(spacing: 8) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, w in
                let a = start + Double(i) * stagger
                let u = StoryCine.sstep(a, a + dur, t)
                Text(w)
                    .font(.inter(30, .semibold))
                    .foregroundStyle(WoopGradient.titleFade)
                    .opacity(u)
                    .blur(radius: (1 - u) * 6)
                    .offset(y: (1 - CGFloat(u)) * 12)
            }
        }
    }
}

// MARK: - Le récap

/// La dalle du récap : la MATIÈRE DES CARDS SWAP en noir profond, quatre
/// lignes, quatre nombres qui comptent.
///
/// SON BORD N'EST PAS UN CONTOUR. Le PNG de référence montre un filet doré
/// fermé, d'épaisseur égale, autour d'un aplat noir — exactement ce que les
/// commits 2eb31fc / e52ea8a ont refusé huit fois : « c'est la grammaire d'un
/// galet rétroéclairé ». Ce qu'on allume ici, c'est le TUBE du shader : une
/// lumière asymétrique, franche en haut, éteinte en bas. Elle donne la même
/// sensation de bord chaud sans jamais fermer le contour.
struct StorySummaryCard: View {
    let session: StorySession
    let t: Double
    let now: Date
    let start: Double

    /// Le débord de l'hôte du shader. En dessous de 54, le fondu d'hôte rogne
    /// le halo et le shader dessine une plaque rectangulaire.
    private static let pad: CGFloat = 58
    private static let radius: CGFloat = 26

    var body: some View {
        VStack(spacing: 0) {
            row(0, "stopwatch", "min", session.minutes, nil)
            hair
            row(1, "dumbbell.fill", "exos", session.exos, nil)
            hair
            row(2, "square.3.layers.3d", "séries", session.series, nil)
            hair
            row(3, "flame.fill", "kcal", session.kcal, nil)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background { matter }
        .overlay { topLight }
        .opacity(StoryCine.sstep(start, start + 0.5, t))
        .offset(y: (1 - CGFloat(StoryCine.sstep(start, start + 0.6, t))) * 14)
    }

    /// LA LUMIÈRE DE BORD, dessinée à la main — et c'est le cœur du sujet.
    ///
    /// Le tube du shader (`lit`) a été essayé : il donne un contour néon
    /// FERMÉ, d'épaisseur égale sur les quatre côtés, autour d'un aplat noir.
    /// C'est mot pour mot la grammaire refusée huit fois (2eb31fc / e52ea8a),
    /// et à l'écran il écrase les chiffres qu'il est censé encadrer. `nu` ne
    /// le retire pas : il retire le liseré de l'arête et laisse justement le
    /// tube — j'avais les deux à l'envers.
    ///
    /// Ce qu'on veut, c'est une lumière RASANTE : franche sur l'arête haute,
    /// morte avant la mi-hauteur des flancs, rien en bas. Un contour ouvert
    /// n'est pas un galet rétroéclairé, c'est une dalle prise par une softbox.
    private var topLight: some View {
        let ramp = StoryCine.sstep(start + 0.16, start + 1.05, t)
        let warm = Color(red: 1.0, green: 0.72, blue: 0.36)
        return RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: warm.opacity(0.52 * ramp), location: 0),
                        .init(color: warm.opacity(0.20 * ramp), location: 0.14),
                        .init(color: warm.opacity(0.05 * ramp), location: 0.34),
                        .init(color: .clear, location: 0.56)
                    ],
                    startPoint: .top, endPoint: .bottom),
                lineWidth: 1)
            .allowsHitTesting(false)
    }

    /// LA MATIÈRE. `noir = 1` : le niveau tombe de 74 %, le lustre de 55 %,
    /// mais la poudre et le fresnel de bord RESTENT — une dalle qui perd son
    /// grain devient un trou découpé. `enterre = -4000` est la valeur neutre :
    /// zéro dirait au shader que le pied de la carte est sur la ligne de coupe
    /// d'une fente, ce qui tue le tube, le fresnel et un cinquième du mat.
    private var matter: some View {
        GeometryReader { geo in
            // TOUT EST PRÉ-TYPÉ. Un appel de shader avec des conversions en
            // ligne fait exploser le type-checker de Swift — « unable to
            // type-check this expression in reasonable time », sans une seule
            // ligne fautive désignée. La maison hisse donc les scalaires.
            let pad: CGFloat = Self.pad
            let w: CGFloat = geo.size.width + pad * 2
            let h: CGFloat = geo.size.height + pad * 2
            let wf: Float = Float(w)
            let hf: Float = Float(h)
            let padf: Float = Float(pad)
            let radf: Float = Float(Self.radius)
            let tt: Float = Float(now.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900))
            // `lit` À ZÉRO : le tube est un contour fermé, il est dessiné à la
            // main au-dessus (voir `topLight`). Ce qui sépare la dalle de la
            // nuit ici, c'est son incidence par le haut et son fresnel de
            // bord — pas un liseré.
            let lit: Float = 0
            Rectangle()
                .fill(.white)
                .frame(width: w, height: h)
                .colorEffect(ShaderLibrary.swapCard(
                    .float2(wf, hf),
                    .float(tt),
                    .float(padf),
                    .float(radf),
                    .float(0),
                    .float(0),
                    .float2(0, 1),
                    .float(lit),
                    // `noir` 1 : le noir profond. Le niveau tombe de 74 % et
                    // le lustre de 55 %, mais la poudre et le fresnel restent
                    // — une dalle qui perd son grain devient un trou découpé.
                    .float(1),
                    // `enterre` : la valeur NEUTRE est -4000, pas zéro — zéro
                    // dirait au shader que le pied de la dalle touche la ligne
                    // de coupe d'une fente.
                    .float(-4000),
                    // `nu` 1 : LA DALLE GARDE SON TUBE ET PERD SON CONTOUR.
                    // C'est le paramètre qui sépare les deux, et c'est
                    // exactement l'arbitrage rendu ici : la lumière de bord
                    // reste, la bande grise fermée autour de l'aplat noir
                    // s'en va.
                    .float(1)))
                .offset(x: -pad, y: -pad)
                .allowsHitTesting(false)
        }
    }

    private var hair: some View {
        Rectangle()
            .fill(Color.white.opacity(0.055))
            .frame(height: 1)
            .padding(.leading, 62)
    }

    private func row(_ i: Int, _ symbol: String, _ label: String,
                     _ value: Int, _ unit: String?) -> some View {
        let a = start + 0.40 + Double(i) * 0.09
        return HStack(spacing: 16) {
            StoryStatIcon(symbol: symbol)
            Text(label)
                .font(.inter(15))
                .foregroundStyle(Color.white.opacity(0.52))
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(count(to: value, from: a))")
                    .font(.inter(30, .medium))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .monospacedDigit()
                    .contentTransition(.identity)
                if let unit {
                    Text(unit)
                        .font(.inter(13))
                        .foregroundStyle(Color.white.opacity(0.42))
                }
            }
        }
        .padding(.vertical, 13)
        .opacity(StoryCine.sstep(a - 0.10, a + 0.34, t))
    }

    /// Le comptage. Sortie douce : les derniers pas ralentissent, sinon le
    /// nombre a l'air d'un compteur mécanique qui s'arrête net.
    private func count(to value: Int, from a: Double) -> Int {
        let u = StoryCine.outLong(min(max((t - a) / 0.95, 0), 1), 2.6)
        return Int((Double(value) * u).rounded())
    }
}

// MARK: - La pastille d'icône

/// Le jeton noir des lignes du récap. Il n'existe AUCUN shader capable de
/// rendre un SF Symbol dans ce projet — tous les objets métalliques de l'app
/// (la pièce, le badge, le triangle du play) sont dessinés analytiquement dans
/// leur propre shader. On reste donc sur le traitement maison : un disque de
/// verre noir, une incidence par le haut, un filet, et un glyphe froid tiré
/// vers le tiède.
struct StoryStatIcon: View {
    let symbol: String
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color.white.opacity(0.085),
                             Color.white.opacity(0.012)],
                    center: UnitPoint(x: 0.34, y: 0.20),
                    startRadius: 0, endRadius: size * 0.92))
            Circle()
                .strokeBorder(LinearGradient(
                    colors: [Color.white.opacity(0.20),
                             Color.white.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
            Image(systemName: symbol)
                .font(.system(size: size * 0.40, weight: .medium))
                .foregroundStyle(LinearGradient(
                    colors: [Color.white.opacity(0.92),
                             Color(red: 0.78, green: 0.72, blue: 0.62)],
                    startPoint: .top, endPoint: .bottom))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.6), radius: 6, y: 3)
    }
}
