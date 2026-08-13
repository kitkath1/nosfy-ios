import SwiftUI

// MARK: - flamme-jauge

/// La carte « Séries » au feu : le médaillon-bijou laqué à gauche (le shader
/// `jaugeLacque`, la recette du galet play transposée à l'orange), le compte
/// au centre, les cinq petites flammes qui dansent, et la jauge-braise
/// saupoudrée de diamants. Tout est HARD-CODÉ : cinq séries, une palette,
/// pas un seul paramètre de thème — c'est un bijou autonome.
///
/// La leçon anti-brun s'applique partout : sur toute la rampe orange, la
/// SATURATION reste haute. Un orange qui perd sa saturation en s'assombrissant
/// devient marron ; ici la rampe descend en TEINTE (or → orange → braise
/// rouge), jamais en saturation.
struct FlammeJauge: View {
    /// Séries validées (1…5). La jauge, le compte et les petites flammes
    /// suivent tous cette seule valeur.
    var done: Int

    /// Cinq séries, gravées dans le marbre.
    private let total = 5

    /// LA PARTITION. Une série validée n'est pas un changement d'état, c'est
    /// un accord : le trait part tout de suite (t0), la flamme naît et le
    /// compte roule sur le deuxième temps (+0,16 s), la veine du cadre et
    /// l'inspiration du médaillon suivent avec leurs propres retards. Tout
    /// se lit dans des horodatages — les courbes se calculent au temps, pas
    /// à l'état, comme partout dans l'app.
    @State private var shownDone = 1
    @State private var surgeFrom = 0
    @State private var surgeAt: Date?
    @State private var igniteAt: Date?
    @State private var celebrateAt: Date?

    var body: some View {
        TimelineView(.animation) { context in
            let t = Float(context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 3600))
            content(t: t, date: context.date)
        }
        .onAppear { shownDone = done }
        .onChange(of: done) { old, new in
            if new > old {
                surgeFrom = old
                surgeAt = .now
                celebrateAt = .now
                igniteAt = .now.addingTimeInterval(0.16)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                        shownDone = new
                    }
                }
            } else {
                // Le retour (5 → 1 en boucle) n'est pas une victoire : pas de
                // cérémonie, juste le ressort qui remet tout en place.
                surgeFrom = new
                surgeAt = nil
                igniteAt = nil
                celebrateAt = nil
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    shownDone = new
                }
            }
        }
    }

    private func content(t: Float, date: Date) -> some View {
        HStack(spacing: 14) {
            FlammeMedaillon(t: t, date: date, celebrateAt: celebrateAt)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        titre
                        Text("Touchez pour voir le détail")
                            .font(.inter(12, .regular))
                            .foregroundStyle(Color.white.opacity(0.48))
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 6)
                    FlammesRow(done: shownDone, total: total, t: t,
                               date: date, igniteAt: igniteAt)
                }
                JaugeBraise(done: done, total: total, t: t, date: date,
                            surgeAt: surgeAt, surgeFrom: surgeFrom)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .padding(.vertical, 15)
        .background(carte(t: t, date: date))
        // Les lueurs vivent DANS le bijou : sans ce clip, l'ombre portée de
        // la braise fuyait sous la carte en une bande dorée.
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var titre: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("Séries")
                .font(.inter(18, .semibold))
                .foregroundStyle(Color.white.opacity(0.96))
            Text("\(shownDone)")
                .font(.inter(19, .bold))
                .foregroundStyle(Color.white)
                .contentTransition(.numericText(value: Double(shownDone)))
            Text("/ \(total)")
                .font(.inter(14, .semibold))
                .foregroundStyle(Color.white.opacity(0.40))
        }
        .lineLimit(1)
        .fixedSize()
    }

    /// La plaque : un gradient vertical sombre, du GRAIN pour la matière
    /// mate, une vignette qui assoit le contenu, le sertissage — et la VEINE :
    /// un court arc de lumière qui circule sur la tranche, cadencé par le
    /// bruit, et qui fait un tour rapide quand une série se valide.
    private func carte(t: Float, date: Date) -> some View {
        let souffle = 0.72 + 0.28 * Double(JaugeVent.souffle(t))
        // La veine : sa position du moment, et sa célébration éventuelle.
        let lent = Double(t) * 0.048
        var angle = (lent - floor(lent)) * 360.0
        var veineOp = 0.30 + 0.18 * Double(JaugeVent.souffle(t))
        if let c = celebrateAt {
            let e = date.timeIntervalSince(c) - 0.25
            if e > 0, e < 0.9 {
                let q = e / 0.9
                angle += (1 - pow(1 - q, 3)) * 360
                veineOp += sin(.pi * q) * 0.55
            }
        }
        let veineAngle = angle

        return RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(LinearGradient(
                stops: [
                    .init(color: Color(red: 0.102, green: 0.098, blue: 0.106), location: 0.0),
                    .init(color: Color(red: 0.071, green: 0.067, blue: 0.075), location: 0.55),
                    .init(color: Color(red: 0.051, green: 0.047, blue: 0.055), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom))
            .overlay {
                // La lumière de la flamme se couche sur la plaque : une nappe
                // chaude ancrée sur le médaillon, qui respire avec lui.
                EllipticalGradient(
                    stops: [
                        .init(color: FlammePalette.coeur.opacity(0.10 * souffle), location: 0.0),
                        .init(color: FlammePalette.braise.opacity(0.045 * souffle), location: 0.45),
                        .init(color: .clear, location: 1.0),
                    ],
                    center: UnitPoint(x: 0.115, y: 0.5),
                    startRadiusFraction: 0, endRadiusFraction: 0.62)
                .blendMode(.plusLighter)
            }
            .overlay {
                // Le grain : 2-3 %, invisible en tant que tel — mais sans lui
                // l'aplat dégradé se lit « rendu logiciel », pas « matière ».
                GrainTexture.tuile
                    .resizable(resizingMode: .tile)
                    .opacity(0.045)
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            }
            .overlay {
                // La vignette : les coins s'éteignent, le contenu s'assoit.
                EllipticalGradient(
                    stops: [
                        .init(color: .clear, location: 0.60),
                        .init(color: Color.black.opacity(0.15), location: 1.0),
                    ],
                    center: .center,
                    startRadiusFraction: 0, endRadiusFraction: 0.82)
            }
            .overlay {
                // Le sertissage : la tranche prend la lumière en haut.
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.12), location: 0.0),
                            .init(color: Color.white.opacity(0.04), location: 0.4),
                            .init(color: Color.white.opacity(0.02), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .overlay {
                // LA VEINE : l'arc d'or qui vit sur la tranche. Longues
                // queues de fondu — dans les coins d'un rectangle arrondi la
                // vitesse angulaire varie, et un arc court y sauterait.
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(AngularGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.36),
                            .init(color: FlammePalette.or.opacity(0.25), location: 0.46),
                            .init(color: FlammePalette.blanc.opacity(0.85), location: 0.50),
                            .init(color: FlammePalette.or.opacity(0.25), location: 0.54),
                            .init(color: .clear, location: 0.64),
                            .init(color: .clear, location: 1.0),
                        ],
                        center: .center, angle: .degrees(veineAngle)),
                        lineWidth: 1)
                    .blendMode(.plusLighter)
                    .opacity(veineOp)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Palette

/// La rampe de feu, du blanc-chaud à la braise rouge. Quatre arrêts qui ne
/// perdent JAMAIS leur saturation en descendant — c'est la recette anti-brun.
enum FlammePalette {
    /// Blanc chauffé, le cœur le plus vif.
    static let blanc = Color(red: 1.0, green: 0.94, blue: 0.80)
    /// Or de néon.
    static let or = Color(red: 1.0, green: 0.78, blue: 0.38)
    /// Orange plein, le corps du néon.
    static let flamme = Color(red: 1.0, green: 0.55, blue: 0.10)
    /// Cœur orange soutenu.
    static let coeur = Color(red: 1.0, green: 0.40, blue: 0.04)
    /// Braise rouge, le bas de la rampe.
    static let braise = Color(red: 1.0, green: 0.22, blue: 0.02)

    /// La rampe verticale du néon : or en tête, braise au pied.
    static let neon = LinearGradient(
        stops: [
            .init(color: or, location: 0.0),
            .init(color: flamme, location: 0.45),
            .init(color: coeur, location: 0.78),
            .init(color: braise, location: 1.0),
        ],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - Le vent

/// Le souffle de la carte, calculé UNE fois par frame côté CPU — le même
/// bruit de valeur que les autres flammes de l'app : apériodique, avec des
/// accalmies et des reprises, jamais un métronome.
enum JaugeVent {
    private static func hash1(_ n: Float) -> Float {
        let s = sin(n * 127.1 + 311.7) * 43758.5453
        return s - floor(s)
    }

    private static func vnoise1(_ x: Float) -> Float {
        let i = floor(x), f = x - floor(x)
        let u = f * f * (3 - 2 * f)
        return hash1(i) * (1 - u) + hash1(i + 1) * u
    }

    /// La respiration lente du halo : 0 repos, 1 pleine braise.
    static func souffle(_ t: Float, phase: Float = 0) -> Float {
        let n = vnoise1(t * 0.32 + phase)
              + 0.5 * vnoise1(t * 0.9 + phase + 47.1)
        return n / 1.5
    }

    /// Le tremblé vif du néon — petit, rapide, celui d'un tube qui vit.
    static func flicker(_ t: Float, phase: Float = 0) -> Float {
        let n = vnoise1(t * 2.6 + phase)
              + 0.45 * vnoise1(t * 6.2 + phase * 1.7 + 13.7)
        return n / 1.45
    }

    /// Une dérive lente et centrée, en [-1 ; 1] — le cœur qui se balance.
    static func derive(_ t: Float, phase: Float = 0) -> Float {
        let n = vnoise1(t * 0.22 + phase)
              + 0.5 * vnoise1(t * 0.57 + phase + 27.9)
        return (n / 1.5 - 0.5) * 2
    }
}

// MARK: - La matière

/// La tuile de grain, générée UNE fois : un bruit gris neutre, tuilé sur la
/// plaque à 3-4 % — c'est lui qui sépare « matière » d'« aplat logiciel ».
enum GrainTexture {
    static let tuile: Image = {
        let size = 96
        var pixels = [UInt8](repeating: 128, count: size * size)
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        for i in 0..<pixels.count {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            pixels[i] = UInt8(truncatingIfNeeded: Int(seed >> 56))
        }
        let ctx = CGContext(data: &pixels, width: size, height: size,
                            bitsPerComponent: 8, bytesPerRow: size,
                            space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        return Image(decorative: ctx.makeImage()!, scale: 2)
    }()
}

/// Le losange de la famille diamant — celui des célébrations.
struct DiamantShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Le médaillon

/// Le bijou : le shader `jaugeLacque` — un galet mat dans lequel la flamme
/// est extrudée en laque orange, sa lampe qui respire, sa nappe qui déborde.
/// La recette du bouton play de la nav bar, transposée au feu. Autour, en
/// SwiftUI : l'aura que le médaillon pose sur la carte.
struct FlammeMedaillon: View {
    let t: Float
    let date: Date
    let celebrateAt: Date?

    /// L'inspiration de la cérémonie : attaque rapide, décrue longue.
    private var boost: Double {
        guard let c = celebrateAt else { return 0 }
        let e = date.timeIntervalSince(c) - 0.30
        guard e > 0, e < 1.2 else { return 0 }
        let q = e / 1.2
        return q < 0.15 ? q / 0.15 : 1 - (q - 0.15) / 0.85
    }

    var body: some View {
        let souffle = Double(JaugeVent.souffle(t))
        let vif = Double(JaugeVent.flicker(t))
        let derive = Double(JaugeVent.derive(t))
        let b = boost
        ZStack {
            // La niche : le rond chaud que la flamme éclaire — comme la
            // référence, une simple pastille, à peine plus claire au cœur.
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: Color(red: 0.168, green: 0.126, blue: 0.106), location: 0.0),
                        .init(color: Color(red: 0.112, green: 0.088, blue: 0.080), location: 0.62),
                        .init(color: Color(red: 0.070, green: 0.056, blue: 0.058), location: 1.0),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.44),
                    startRadius: 0, endRadius: 34))

            // L'ambiance qui respire — et qui prend sa grande inspiration
            // quand une série se valide.
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: FlammePalette.coeur.opacity(0.20 + 0.10 * souffle + 0.25 * b), location: 0.0),
                        .init(color: FlammePalette.braise.opacity(0.06 + 0.04 * souffle), location: 0.55),
                        .init(color: .clear, location: 1.0),
                    ],
                    center: .center, startRadius: 0, endRadius: 29))
                .blendMode(.plusLighter)

            // Le ventre : une lueur SOBRE — la réf n'a pas de cœur blanc,
            // juste l'orange qui affleure sous le contour. La respiration
            // reste, mais en sourdine.
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(RadialGradient(
                    stops: [
                        .init(color: FlammePalette.flamme.opacity(0.75), location: 0.0),
                        .init(color: FlammePalette.coeur.opacity(0.40), location: 0.60),
                        .init(color: .clear, location: 1.0),
                    ],
                    center: UnitPoint(x: 0.5 + 0.04 * derive, y: 0.62),
                    startRadius: 0, endRadius: 17))
                .opacity(0.26 + 0.09 * souffle + 0.04 * vif + 0.25 * b)
                .blur(radius: 2.2 - 0.5 * souffle)
                .blendMode(.plusLighter)

            // Le contour : l'orange DOUX et quasi uniforme de la référence —
            // pas de rampe or→braise qui fait bijou. Il danse, à peine.
            Image(systemName: "flame")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(LinearGradient(
                    stops: [
                        .init(color: Color(red: 1.0, green: 0.66, blue: 0.34), location: 0.0),
                        .init(color: Color(red: 0.99, green: 0.56, blue: 0.24), location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom))
                .opacity(0.90 + 0.10 * vif)
                .shadow(color: FlammePalette.coeur.opacity(0.45 + 0.12 * vif), radius: 3.5)
                .shadow(color: FlammePalette.braise.opacity(0.22 + 0.12 * souffle + 0.25 * b),
                        radius: 8)
                .rotationEffect(.degrees(1.3 * derive), anchor: .bottom)
        }
        .frame(width: 58, height: 58)
        .compositingGroup()
    }
}

// MARK: - Les cinq petites flammes

/// La rangée de droite : une flamme par série — les glyphes SF, ceux qui se
/// lisent au premier regard. Les validées brûlent et DANSENT : penchement,
/// respiration et tremblé propres à chacune (sa phase), jamais en chœur.
struct FlammesRow: View {
    let done: Int
    let total: Int
    let t: Float
    let date: Date
    let igniteAt: Date?

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                PetiteFlamme(lit: i < done, t: t, phase: Float(i) * 4.7,
                             date: date,
                             igniteAt: i == done - 1 ? igniteAt : nil)
            }
        }
    }
}

struct PetiteFlamme: View {
    let lit: Bool
    let t: Float
    let phase: Float
    let date: Date
    /// L'heure de naissance de CETTE flamme, si elle vient de s'allumer —
    /// la cérémonie (flash, diamants, onde) se déroule dessus.
    let igniteAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let vif = Double(JaugeVent.flicker(t, phase: phase))
        let souffle = Double(JaugeVent.souffle(t, phase: phase * 3.1))
        let sway = Double(JaugeVent.derive(t, phase: phase + 9.3))
        let e = igniteAt.map { date.timeIntervalSince($0) } ?? -1

        ZStack {
            if lit {
                // Le ventre : un cœur d'or qui bat sous le contour, et qui
                // se penche AVEC la flamme — la lumière suit la danse.
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(RadialGradient(
                        stops: [
                            .init(color: FlammePalette.blanc, location: 0.0),
                            .init(color: FlammePalette.or.opacity(0.7), location: 0.45),
                            .init(color: FlammePalette.coeur.opacity(0.0), location: 1.0),
                        ],
                        center: UnitPoint(x: 0.5 + 0.05 * sway, y: 0.66),
                        startRadius: 0, endRadius: 8))
                    .opacity(0.34 + 0.14 * vif + 0.10 * souffle)
                    .blur(radius: 1.3)
                    .blendMode(.plusLighter)
                Image(systemName: "flame")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FlammePalette.neon)
                    .opacity(0.88 + 0.12 * vif)
                    .shadow(color: FlammePalette.coeur.opacity(0.55 + 0.25 * vif), radius: 3)
                    .shadow(color: FlammePalette.braise.opacity(0.28 + 0.18 * souffle), radius: 7)
            } else {
                Image(systemName: "flame")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.16))
            }
        }
        .frame(width: 16, height: 19)
        // La danse : chaque flamme penche depuis son pied et respire à son
        // rythme. Les éteintes ne bougent pas — une flamme morte est immobile.
        .rotationEffect(.degrees(lit ? 3.4 * sway : 0), anchor: .bottom)
        .scaleEffect(lit ? 1.0 + 0.04 * souffle : 0.88)
        .animation(.spring(response: 0.34, dampingFraction: 0.55), value: lit)
        .overlay {
            if e >= 0, e < 0.8 {
                ceremonie(e: e)
            }
        }
    }

    /// La cérémonie de naissance : le flash blanc-chaud qui retombe, l'onde
    /// qui s'étend, et la couronne de diamants qui s'écarte en tournant.
    @ViewBuilder
    private func ceremonie(e: Double) -> some View {
        let q = min(1, e / 0.8)
        let grandit = 1 - (1 - q) * (1 - q)
        ZStack {
            // Le flash : la flamme naît surexposée, presque blanche.
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(FlammePalette.blanc)
                .opacity(max(0, 1 - e / 0.32) * 0.85)
                .blur(radius: 1)
                .blendMode(.plusLighter)
            // L'onde : un fin anneau qui se dissout en s'étendant.
            Circle()
                .stroke(FlammePalette.or.opacity(0.50 * (1 - q)), lineWidth: 0.8)
                .frame(width: 8 + 26 * grandit, height: 8 + 26 * grandit)
                .blendMode(.plusLighter)
            // La couronne : six diamants qui naissent sur un cercle,
            // s'écartent et s'éteignent — la famille diamant de l'app.
            if !reduceMotion {
                ForEach(0..<6, id: \.self) { k in
                    let a = (Double(k) * 60 - 90 + 26 * q) * .pi / 180
                    let r = 6 + 11 * grandit
                    let bell = q < 0.22 ? q / 0.22 : 1 - (q - 0.22) / 0.78
                    DiamantShape()
                        .fill(LinearGradient(
                            colors: [FlammePalette.blanc, FlammePalette.or],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: 4.6)
                        .scaleEffect(0.35 + 0.75 * bell)
                        .opacity(bell)
                        .offset(x: r * cos(a), y: r * sin(a))
                        .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - La jauge

/// La braise couchée : un rail creusé presque noir, le trait de feu braise →
/// or, la POUSSIÈRE DE DIAMANTS qui scintille dedans, et le cap-gemme à la
/// pointe — cœur blanc, anneau d'or, micro-reflet. À chaque série : le trait
/// part en surge, le segment neuf naît blanc-chaud et REFROIDIT vers la
/// rampe, le cap dépasse sa cible et se pose.
struct JaugeBraise: View {
    let done: Int
    let total: Int
    let t: Float
    let date: Date
    let surgeAt: Date?
    let surgeFrom: Int

    private let hauteur: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let frac = CGFloat(done) / CGFloat(total)
            let largeur = max(hauteur, geo.size.width * frac)
            let vieille = geo.size.width * CGFloat(surgeFrom) / CGFloat(total)
            ZStack(alignment: .leading) {
                // Le rail : creusé, plus sombre en haut — une rainure.
                Capsule()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.50), location: 0.0),
                            .init(color: Color.white.opacity(0.06), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom))
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 0.7)
                    }

                braise(largeur: largeur, vieille: vieille)
            }
        }
        .frame(height: hauteur)
    }

    private func braise(largeur: CGFloat, vieille: CGFloat) -> some View {
        let souffle = Double(JaugeVent.souffle(t))
        let vif = Double(JaugeVent.flicker(t, phase: 31.4))
        let eS = surgeAt.map { date.timeIntervalSince($0) } ?? .infinity
        // Le cap dépasse sa cible et se pose — l'overshoot d'une chose qui
        // a une masse.
        let pulse = eS < 1.2 ? 1 + 0.30 * exp(-4.5 * eS) * sin(11 * eS) : 1

        return Capsule()
            .fill(LinearGradient(
                stops: [
                    .init(color: FlammePalette.braise, location: 0.0),
                    .init(color: FlammePalette.coeur, location: 0.16),
                    .init(color: FlammePalette.flamme, location: 0.58),
                    .init(color: FlammePalette.or, location: 1.0),
                ],
                startPoint: .leading, endPoint: .trailing))
            .overlay {
                // LE CŒUR DU TUBE : la ligne blanc-chaud qui court au centre
                // — c'est elle qui fait lire « néon » et non « barre remplie ».
                Capsule()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: FlammePalette.blanc.opacity(0.10), location: 0.0),
                            .init(color: FlammePalette.blanc.opacity(0.75 + 0.10 * vif), location: 0.72),
                            .init(color: FlammePalette.blanc.opacity(0.92), location: 1.0),
                        ],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: hauteur * 0.38)
                    .padding(.horizontal, 2.5)
                    .blur(radius: 1.1)
                    .blendMode(.plusLighter)
            }
            .overlay {
                // LE LISERÉ : le petit border BLANC dégradé de la référence —
                // brillant en tête, presque rien au pied. C'est le bord de
                // verre du tube.
                Capsule()
                    .strokeBorder(LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.95), location: 0.0),
                            .init(color: Color.white.opacity(0.45), location: 0.55),
                            .init(color: Color.white.opacity(0.25), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.0)
                    .blendMode(.plusLighter)
                    .opacity(0.85 + 0.15 * vif)
            }
            .overlay {
                // LA POUSSIÈRE DE DIAMANTS — le balayage est mort.
                PoussiereDiamants(t: t)
                    .clipShape(Capsule())
            }
            .overlay {
                // Le métal chaud qui refroidit : le segment fraîchement gagné
                // naît blanc-chaud, puis la rampe reprend ses droits.
                if eS < 0.5 {
                    GeometryReader { g in
                        let x0 = min(vieille, g.size.width)
                        Rectangle()
                            .fill(Color.white.opacity(0.42 * (1 - eS / 0.5)))
                            .frame(width: max(0, g.size.width - x0))
                            .offset(x: x0)
                            .blur(radius: 1)
                            .blendMode(.plusLighter)
                    }
                    .clipShape(Capsule())
                }
            }
            .overlay(alignment: .trailing) {
                capGemme(pulse: pulse, vif: vif)
            }
            .frame(width: largeur)
            // Le halo du néon : serré et saturé d'abord, large et braise
            // ensuite — c'est le tube qui éclaire la rainure.
            .shadow(color: FlammePalette.coeur.opacity(0.70 + 0.20 * souffle), radius: 4)
            .shadow(color: FlammePalette.coeur.opacity(0.40 + 0.15 * souffle), radius: 9)
            .shadow(color: FlammePalette.braise.opacity(0.30 + 0.15 * souffle), radius: 16)
            .animation(.spring(response: 0.55, dampingFraction: 0.72), value: done)
    }

    /// Le cap-gemme : le point le plus lumineux de la carte — un cœur blanc
    /// serti d'un anneau d'or, avec son micro-reflet haut-gauche.
    private func capGemme(pulse: Double, vif: Double) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: FlammePalette.blanc.opacity(0.95), location: 0.0),
                        .init(color: FlammePalette.or.opacity(0.55), location: 0.55),
                        .init(color: .clear, location: 1.0),
                    ],
                    center: .center, startRadius: 0, endRadius: 7))
                .frame(width: 14, height: 14)
                .opacity(0.80 + 0.20 * vif)
            Circle()
                .strokeBorder(FlammePalette.or.opacity(0.85), lineWidth: 0.7)
                .frame(width: 7.6, height: 7.6)
            Circle()
                .fill(Color.white)
                .frame(width: 3.4, height: 3.4)
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 1.3, height: 1.3)
                .offset(x: -1.4, y: -1.6)
        }
        .compositingGroup()
        .blendMode(.plusLighter)
        .scaleEffect(pulse)
        .offset(x: 2)
    }
}

/// Des centaines de petits diamants qui vivent DANS la braise : chacun a sa
/// place, sa vitesse de dérive vers le cap, et son scintillement — une
/// pointe brève (sinus à la puissance 7), pas une pulsation. C'est de la
/// poussière de gemme, pas des paillettes de fête.
struct PoussiereDiamants: View {
    let t: Float

    var body: some View {
        Canvas { ctx, size in
            guard size.width > 4 else { return }
            ctx.blendMode = .plusLighter
            let n = max(60, Int(size.width * 1.8))
            let tt = Double(t)
            for i in 0..<n {
                let h1 = Self.hash(i * 5 + 1)
                let h2 = Self.hash(i * 5 + 2)
                let h3 = Self.hash(i * 5 + 3)
                let h4 = Self.hash(i * 5 + 4)
                let h5 = Self.hash(i * 5 + 5)
                // La dérive : chaque grain avance vers le cap, à sa vitesse.
                let x = ((h1 + tt * 0.020 * (0.4 + 0.8 * h2))
                    .truncatingRemainder(dividingBy: 1)) * size.width
                let y = 1.0 + h2 * (size.height - 2.0)
                // Deux castes : la poussière, qui scintille à peine, et les
                // ÉTOILES (une sur sept), qui jettent de vrais éclats — c'est
                // l'inégalité qui fait le précieux, jamais l'uniforme.
                let etoile = h5 < 0.14
                let tw = 0.5 + 0.5 * sin(tt * (2.2 + 3.4 * h3) + h4 * 6.283)
                let glint = etoile ? pow(tw, 4.0) : pow(tw, 9.0) * 0.45
                guard glint > 0.015 else { continue }
                let s = (etoile ? 0.55 + 0.65 * h4 : 0.28 + 0.42 * h4)
                var path = Path()
                path.move(to: CGPoint(x: x, y: y - s))
                path.addLine(to: CGPoint(x: x + s * 0.62, y: y))
                path.addLine(to: CGPoint(x: x, y: y + s))
                path.addLine(to: CGPoint(x: x - s * 0.62, y: y))
                path.closeSubpath()
                let couleur = h3 < 0.35 ? FlammePalette.blanc : Color.white
                ctx.fill(path, with: .color(couleur.opacity(glint * (0.40 + 0.50 * h2))))
                // L'éclat en croix d'une étoile au sommet de son scintillement.
                if etoile, glint > 0.55 {
                    let f = (glint - 0.55) / 0.45
                    let L = s * (1.6 + 2.2 * f)
                    var croix = Path()
                    croix.move(to: CGPoint(x: x - L, y: y))
                    croix.addLine(to: CGPoint(x: x + L, y: y))
                    croix.move(to: CGPoint(x: x, y: y - L * 0.7))
                    croix.addLine(to: CGPoint(x: x, y: y + L * 0.7))
                    ctx.stroke(croix, with: .color(Color.white.opacity(0.55 * f)),
                               lineWidth: 0.5)
                }
            }
        }
        .allowsHitTesting(false)
    }

    static func hash(_ n: Int) -> Double {
        let s = sin(Double(n) * 127.1 + 311.7) * 43758.5453
        return s - floor(s)
    }
}
