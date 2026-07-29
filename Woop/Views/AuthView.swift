import SwiftUI

// MARK: - Écran d'authentification

/// L'écran qui suit le splash : une nuit très noire — une voie lactée fine et
/// granuleuse, des centaines de poussières d'étoiles — habitée par des
/// diablotins à la silhouette du splash. Leurs corps d'encre apparaissent et
/// se dissolvent ; leurs yeux de porcelaine ne s'allument que par moments,
/// jamais tous ensemble. Au centre, le formulaire : Bienvenue, le numéro,
/// le bouton velours noir.
struct AuthView: View {
    var onConnect: (String) -> Void

    /// L'horloge de la scène : posée à l'apparition, toute la nuit s'en déduit.
    @State private var start: Date?
    @State private var formShown = false
    @State private var phone = ""
    @State private var connecting = false
    @FocusState private var phoneFocused: Bool

    private var digits: String { phone.filter(\.isNumber) }
    /// Un mobile français : dix chiffres, 06 ou 07.
    private var isValid: Bool {
        digits.count == 10 && (digits.hasPrefix("06") || digits.hasPrefix("07"))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TimelineView(.animation) { context in
                let t = start.map { context.date.timeIntervalSince($0) } ?? 0
                ImpNight(t: t)
            }
            .ignoresSafeArea()
            .onTapGesture { phoneFocused = false }

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    Text("Bienvenue")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                    Text("Ton numéro suffit — tes séances\nte retrouvent partout.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.inkSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.bottom, 34)
                .reveal(formShown, delay: 0)

                phoneField
                    .padding(.bottom, 16)
                    .reveal(formShown, delay: 0.12)

                Button {
                    connect()
                } label: {
                    Text("Se connecter par SMS")
                }
                .buttonStyle(WoopPrimaryButtonStyle())
                .disabled(!isValid || connecting)
                .opacity(isValid ? 1 : 0.45)
                .animation(.easeOut(duration: 0.25), value: isValid)
                .reveal(formShown, delay: 0.24)

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            start = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { formShown = true }
        }
    }

    /// La connexion est immédiate : un toucher, on entre. Le vrai envoi
    /// d'OTP viendra se loger ici plus tard.
    private func connect() {
        guard !connecting else { return }
        connecting = true
        phoneFocused = false
        onConnect(digits)
    }

    // MARK: Formulaire

    private var phoneField: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.inkMuted)
            TextField("06 12 34 56 78", text: $phone)
                .keyboardType(.numberPad)
                .textContentType(.telephoneNumber)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .tint(Color.inkPrimary)
                .focused($phoneFocused)
                .onChange(of: phone) { _, value in
                    let formatted = Self.format(value)
                    if formatted != value { phone = formatted }
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.055))
        }
        .overlay {
            // La même arête de lumière que le bouton velours : vive en haut,
            // morte en bas — et qui s'éveille quand le champ prend le focus.
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(phoneFocused ? 0.55 : 0.28), location: 0.0),
                            .init(color: .white.opacity(0.07), location: 0.4),
                            .init(color: .white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .animation(.easeOut(duration: 0.3), value: phoneFocused)
    }

    /// « 0612345678 » → « 06 12 34 56 78 » — dix chiffres, groupés par deux.
    private static func format(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber).prefix(10)
        var out = ""
        for (i, d) in digits.enumerated() {
            if i > 0 && i % 2 == 0 { out.append(" ") }
            out.append(d)
        }
        return out
    }
}

// MARK: - La nuit aux diablotins

/// Toute la scène dans un seul Canvas : la voie lactée granuleuse, des
/// centaines de poussières fines, le liseré de particules — et les
/// diablotins, à la silhouette exacte du splash. Tout est précalculé une
/// fois ; chaque frame ne fait que moduler des alphas.
private struct ImpNight: View {
    var t: Double

    // MARK: La silhouette

    /// La goutte aux cornes cambrées du splash — les mêmes courbes, la droite
    /// un souffle plus haute. C'est LE diablotin de l'app, en miniature.
    static let outline: [CGPoint] = inkPolyline(from: CGPoint(x: 0.500, y: 0.975), [
        .curve(0.318, 0.968, 0.208, 0.890),   // assise gauche pleine
        .curve(0.106, 0.780, 0.118, 0.582),   // flanc gauche tendu
        .curve(0.132, 0.442, 0.240, 0.322),   // joue gauche
        .curve(0.196, 0.246, 0.226, 0.150),   // corne g. : petite griffe cambrée
        .curve(0.243, 0.108, 0.260, 0.130),   // pointe fine
        .curve(0.296, 0.205, 0.354, 0.262),   // bord interne, retour au crâne
        .curve(0.500, 0.212, 0.646, 0.256),   // crâne entre les cornes
        .curve(0.692, 0.162, 0.728, 0.094),   // corne d. : bord interne raide
        .curve(0.744, 0.048, 0.764, 0.078),   // pointe aiguille, plus haute
        .curve(0.798, 0.180, 0.774, 0.316),   // bord externe, cambrure inverse
        .curve(0.862, 0.424, 0.878, 0.582),   // joue droite
        .curve(0.892, 0.780, 0.796, 0.890),   // flanc droit
        .curve(0.690, 0.968, 0.500, 0.975)    // assise droite
    ], steps: 10)

    /// Le contour rééchantillonné pour l'arête de lumière, et le poids
    /// lumineux de chaque point : vif sur la crête et les cornes (la lumière
    /// vient d'en haut), mort le long des flancs et de l'assise.
    static let rim: [CGPoint] = inkResample(outline, count: 110)
    static let rimWeight: [CGFloat] = rim.map { p in
        let crest = smoothstep((0.46 - p.y) / 0.30)
        let seat = 1 - smoothstep((p.y - 0.80) / 0.12)
        return crest * seat
    }

    // MARK: Le peuple de la nuit

    /// Un diablotin : sa place, sa taille (côté de sa boîte), son inclinaison,
    /// sa vie (cadences propres) — et s'il est éphémère : ceux-là émergent du
    /// noir puis s'y dissolvent tout entiers.
    private struct Imp {
        let x: CGFloat
        let y: CGFloat
        let side: CGFloat
        let tilt: Double
        let phase: Double
        let ephemeral: Bool
        /// Fraction du temps visible où les yeux sont allumés.
        let litFraction: Double
    }

    /// Les ancres (le gros en bas-gauche, le moyen en haut-gauche, le coupé
    /// du bord droit) demeurent ; les petits vont et viennent. Le couloir
    /// central appartient au formulaire.
    private static let imps: [Imp] = [
        Imp(x: 0.16, y: 0.885, side: 120, tilt: 4, phase: 0.2, ephemeral: false, litFraction: 0.62),
        Imp(x: 0.13, y: 0.095, side: 62, tilt: -5, phase: 2.7, ephemeral: false, litFraction: 0.55),
        Imp(x: 0.965, y: 0.50, side: 70, tilt: -8, phase: 4.9, ephemeral: false, litFraction: 0.45),
        Imp(x: 0.815, y: 0.045, side: 26, tilt: 6, phase: 1.4, ephemeral: true, litFraction: 0.42),
        Imp(x: 0.50, y: 0.145, side: 18, tilt: 3, phase: 3.8, ephemeral: true, litFraction: 0.30),
        Imp(x: 0.07, y: 0.30, side: 20, tilt: 7, phase: 5.5, ephemeral: true, litFraction: 0.38),
        Imp(x: 0.90, y: 0.245, side: 22, tilt: -6, phase: 0.9, ephemeral: true, litFraction: 0.35),
        Imp(x: 0.735, y: 0.895, side: 26, tilt: -4, phase: 2.1, ephemeral: true, litFraction: 0.42),
        Imp(x: 0.42, y: 0.78, side: 15, tilt: 8, phase: 4.3, ephemeral: true, litFraction: 0.30),
        Imp(x: 0.60, y: 0.04, side: 14, tilt: -7, phase: 5.9, ephemeral: true, litFraction: 0.32)
    ]

    /// Le générateur déterministe de la nuit : tout se déduit de l'index,
    /// jamais du hasard — la scène est identique à chaque frame.
    private static func hash(_ i: Int, _ salt: Double) -> Double {
        let v = sin(Double(i) * 127.1 + salt * 311.7) * 43758.5453
        return v - v.rounded(.down)
    }

    /// La veine de la voie lactée : un S très doux, haut-centre → bas-droite,
    /// en unités d'écran.
    private static func vein(_ u: CGFloat) -> CGPoint {
        let a = CGPoint(x: 0.58, y: -0.06)
        let b = CGPoint(x: 0.40, y: 0.42)
        let c = CGPoint(x: 0.66, y: 1.06)
        let control1 = CGPoint(x: 0.50, y: 0.18)
        let control2 = CGPoint(x: 0.44, y: 0.78)
        func quad(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ k: CGFloat) -> CGPoint {
            let m = 1 - k
            return CGPoint(x: m * m * p0.x + 2 * m * k * p1.x + k * k * p2.x,
                           y: m * m * p0.y + 2 * m * k * p1.y + k * k * p2.y)
        }
        return u < 0.5 ? quad(a, control1, b, u * 2) : quad(b, control2, c, (u - 0.5) * 2)
    }

    // MARK: Les populations précalculées

    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let r: CGFloat
        let alpha: Double
        /// 0 = fixe ; sinon, fréquence de scintillement.
        let twinkle: Double
    }

    /// ~380 poussières : fines (0,3–1 px pour l'essentiel), très inégales,
    /// denses le long de la veine — la voie lactée est une population, pas
    /// un dégradé.
    private static let stars: [Star] = (0..<380).map { i in
        let onVein = hash(i, 1) < 0.60
        var x: CGFloat, y: CGFloat
        if onVein {
            let u = CGFloat(hash(i, 2))
            let p = vein(u)
            // Étalement pseudo-gaussien : somme de deux tirages.
            let spreadX = CGFloat(hash(i, 3) + hash(i, 13) - 1) * 0.17
            let spreadY = CGFloat(hash(i, 4) + hash(i, 14) - 1) * 0.06
            x = p.x + spreadX
            y = p.y + spreadY
        } else {
            x = CGFloat(hash(i, 5))
            y = CGFloat(hash(i, 6))
        }
        // Presque toutes minuscules ; une poignée à peine plus grandes.
        let sizePick = hash(i, 7)
        let r: CGFloat = sizePick > 0.97 ? 1.1 + CGFloat(hash(i, 8)) * 0.5
            : 0.3 + CGFloat(pow(hash(i, 8), 2)) * 0.5
        let alpha = 0.04 + 0.30 * pow(hash(i, 9), 3)
        let twinkle = hash(i, 10) < 0.25 ? 0.3 + hash(i, 11) * 0.9 : 0
        return Star(x: x, y: y, r: r, alpha: alpha, twinkle: twinkle)
    }

    private struct Cloud {
        let x: CGFloat
        let y: CGFloat
        let r: CGFloat
        let alpha: Double
        let bucket: Int
    }

    /// La matière nuageuse : ~150 taches très faibles en grappes le long de
    /// la veine, trois flous — c'est l'accumulation qui fait la voilure
    /// laiteuse, avec ses paquets et ses trous, jamais un trait.
    private static let clouds: [Cloud] = {
        // Neuf grappes posées sur la veine, latéralement décalées.
        let centers: [CGPoint] = (0..<9).map { c in
            let u = CGFloat(c) / 8 * 0.92 + 0.04 + CGFloat(hash(c, 40) - 0.5) * 0.06
            var p = vein(u)
            p.x += CGFloat(hash(c, 41) - 0.5) * 0.10
            return p
        }
        return (0..<150).map { i in
            let c = Int(hash(i, 42) * 8.999)
            let center = centers[c]
            let bucket = Int(hash(i, 43) * 2.999)
            let spread: CGFloat = [0.045, 0.075, 0.12][bucket]
            let x = center.x + CGFloat(hash(i, 44) + hash(i, 45) - 1) * spread * 1.6
            let y = center.y + CGFloat(hash(i, 46) + hash(i, 47) - 1) * spread
            let r: CGFloat = [3.5, 6.5, 11.0][bucket] * (0.6 + CGFloat(hash(i, 48)))
            let alpha = [0.030, 0.022, 0.015][bucket] * (0.5 + hash(i, 49))
            return Cloud(x: x, y: y, r: r, alpha: alpha, bucket: bucket)
        }
    }()

    var body: some View {
        Canvas { context, size in
            let fade = Double(smoothstep(CGFloat(t / 1.2)))
            guard fade > 0.01 else { return }

            drawMilkyWay(context, size, fade: fade)
            drawStars(context, size, fade: fade)
            drawDrift(context, size, fade: fade)
            for (i, imp) in Self.imps.enumerated() {
                drawImp(context, size, imp: imp, index: i, fade: fade)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: La voie lactée

    /// Le lit le plus large d'abord (un seul trait très flou, à peine là),
    /// puis les grappes nuageuses en trois passes de flou. Une respiration
    /// imperceptible par grappe — la nuit n'est pas une photo figée.
    private func drawMilkyWay(_ context: GraphicsContext, _ size: CGSize, fade: Double) {
        var bed = Path()
        for k in 0...24 {
            let u = CGFloat(k) / 24
            let p = Self.vein(u)
            let point = CGPoint(x: p.x * size.width, y: p.y * size.height)
            if k == 0 { bed.move(to: point) } else { bed.addLine(to: point) }
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: size.width * 0.11))
            layer.stroke(bed, with: .color(.white.opacity(0.020 * fade)),
                         style: StrokeStyle(lineWidth: size.width * 0.30, lineCap: .round))
        }

        for bucket in 0..<3 {
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: [5.0, 9.0, 15.0][bucket]))
                for (i, cloud) in Self.clouds.enumerated() where cloud.bucket == bucket {
                    let breath = 1 + 0.22 * sin(t * 0.05 + Double(i))
                    let r = cloud.r
                    layer.fill(
                        Path(ellipseIn: CGRect(x: cloud.x * size.width - r,
                                               y: cloud.y * size.height - r,
                                               width: r * 2, height: r * 2)),
                        with: .color(.white.opacity(cloud.alpha * breath * fade))
                    )
                }
            }
        }
    }

    // MARK: Les poussières

    private func drawStars(_ context: GraphicsContext, _ size: CGSize, fade: Double) {
        for star in Self.stars {
            var a = star.alpha
            if star.twinkle > 0 {
                a *= 0.45 + 0.55 * pow(0.5 + 0.5 * sin(t * star.twinkle + Double(star.x) * 37), 2)
            }
            let r = star.r
            let x = star.x * size.width, y = star.y * size.height
            context.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(a * fade))
            )
        }
    }

    /// Le liseré : un filet de grains fins en dérive ascendante le long de la
    /// veine — nés du noir, morts dans le noir.
    private func drawDrift(_ context: GraphicsContext, _ size: CGSize, fade: Double) {
        for i in 0..<26 {
            let u = CGFloat((Self.hash(i, 20) + t * (0.005 + 0.005 * Self.hash(i, 21)))
                .truncatingRemainder(dividingBy: 1))
            let p = Self.vein(1 - u)
            let side = CGFloat(Self.hash(i, 22) - 0.5) * size.width * 0.09
            let sway = CGFloat(sin(t * (0.3 + Self.hash(i, 23) * 0.4) + Double(i) * 2.2)) * 5
            let x = p.x * size.width + side + sway
            let y = p.y * size.height
            let twinkle = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(t * (0.8 + Self.hash(i, 24)) + Double(i)), 2)
            let life = sin(.pi * Double(u))
            let a = 0.20 * twinkle * life
            guard a > 0.02 else { continue }
            let r = 0.4 + 0.5 * CGFloat(Self.hash(i, 25))
            context.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(a * fade))
            )
        }
    }

    // MARK: Les diablotins

    /// La vie d'un corps : les ancres demeurent ; les éphémères émergent du
    /// noir, vivent une dizaine de secondes, s'y dissolvent — décalés pour
    /// que la nuit ne soit jamais vide ni pleine.
    private func bodyPresence(_ imp: Imp, index: Int) -> Double {
        guard imp.ephemeral else { return 1 }
        let period = 17 + Self.hash(index, 60) * 9
        let visible = period * 0.62
        let c = (t + imp.phase * 4).truncatingRemainder(dividingBy: period)
        guard c < visible else { return 0 }
        let rise = Double(smoothstep(CGFloat(c / 1.6)))
        let fall = 1 - Double(smoothstep(CGFloat((c - (visible - 2.0)) / 2.0)))
        return rise * fall
    }

    /// La vie des yeux : allumés par plages, sur la cadence propre de chacun —
    /// jamais tous ensemble, et jamais longtemps.
    private func eyesLit(_ imp: Imp, index: Int) -> Double {
        let period = 9 + Self.hash(index, 61) * 6
        let lit = period * imp.litFraction
        let c = (t + imp.phase * 7).truncatingRemainder(dividingBy: period)
        guard c < lit else { return 0 }
        let rise = Double(smoothstep(CGFloat(c / 0.5)))
        let fall = 1 - Double(smoothstep(CGFloat((c - (lit - 0.7)) / 0.7)))
        return rise * fall
    }

    private func drawImp(_ context: GraphicsContext, _ size: CGSize,
                         imp: Imp, index: Int, fade: Double) {
        let birth = Double(smoothstep(CGFloat((t - 0.3 - Self.hash(index, 30) * 1.1) / 0.8)))
        let presence = bodyPresence(imp, index: index) * birth * fade
        guard presence > 0.01 else { return }

        // Le flottement : ±2 pt, très lent, chacun sa dérive.
        let cx = imp.x * size.width + CGFloat(sin(t * 0.11 + imp.phase * 2)) * 2.5
        let cy = imp.y * size.height + CGFloat(cos(t * 0.08 + imp.phase * 3)) * 2.0
        let side = imp.side
        let tilt = imp.tilt * .pi / 180
        let ca = CGFloat(cos(tilt)), sa = CGFloat(sin(tilt))

        /// Unité → écran : centrage, inclinaison, échelle.
        func P(_ u: CGPoint) -> CGPoint {
            let dx = (u.x - 0.5) * side, dy = (u.y - 0.55) * side
            return CGPoint(x: cx + dx * ca - dy * sa, y: cy + dx * sa + dy * ca)
        }
        let transform = CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: tilt)
            .scaledBy(x: side, y: side)
            .translatedBy(x: -0.5, y: -0.55)

        // Le corps : la goutte du splash, encre à peine plus claire que la
        // nuit — un dégradé qui meurt vers l'assise.
        var silhouette = Path()
        silhouette.move(to: Self.outline[0])
        for p in Self.outline.dropFirst() { silhouette.addLine(to: p) }
        silhouette.closeSubpath()
        let body = silhouette.applying(transform)
        context.fill(
            body,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.055 * presence), location: 0.0),
                    .init(color: .white.opacity(0.030 * presence), location: 0.45),
                    .init(color: .white.opacity(0.010 * presence), location: 1.0)
                ]),
                startPoint: P(CGPoint(x: 0.5, y: 0.05)),
                endPoint: P(CGPoint(x: 0.5, y: 1.0))
            )
        )

        // L'arête de lumière : vive sur la crête et les cornes, morte sur les
        // flancs — la signature du diablotin du splash.
        let lit = eyesLit(imp, index: index)
        let rimGain = (0.11 + 0.10 * lit) * presence
        let stride = side >= 50 ? 1 : 2
        var i = 0
        while i < Self.rim.count - stride {
            let w = Self.rimWeight[i]
            if w > 0.04 {
                var segment = Path()
                segment.move(to: P(Self.rim[i]))
                segment.addLine(to: P(Self.rim[i + stride]))
                context.stroke(
                    segment,
                    with: .color(.white.opacity(Double(w) * rimGain)),
                    style: StrokeStyle(lineWidth: side >= 50 ? 0.9 : 0.7, lineCap: .round)
                )
            }
            i += stride
        }

        drawEyes(context, imp: imp, index: index, lit: lit,
                 presence: presence, transform: transform, side: side, at: P)
    }

    /// Les yeux du splash en miniature : deux globes de porcelaine inclinés,
    /// catchlight, regard qui glisse, clignements rares — et leur halo qui
    /// éclaire la face quand ils s'allument.
    private func drawEyes(_ context: GraphicsContext, imp: Imp, index: Int,
                          lit: Double, presence: Double,
                          transform: CGAffineTransform, side: CGFloat,
                          at P: (CGPoint) -> CGPoint) {
        guard lit > 0.01 else { return }
        // La braise : une respiration lente, jamais un stroboscope.
        let ember = 0.82 + 0.18 * sin(t * 1.3 + imp.phase * 4) * sin(t * 0.7 + imp.phase)
        // Le clignement, sur la cadence propre de l'individu.
        let blinkPeriod = 4.5 + Self.hash(index, 62) * 3.5
        let c = (t + imp.phase * 5).truncatingRemainder(dividingBy: blinkPeriod)
        let window = blinkPeriod - 0.20
        let blink = c > window ? max(0, sin((c - window) / 0.20 * .pi)) : 0
        let openness = max(0.05, 1 - blink)
        // Le regard : une dérive de l'ordre du pixel.
        let gazeX = CGFloat(sin(t * 0.10 + imp.phase * 2.7)) * 0.020
        let gazeY = CGFloat(cos(t * 0.07 + imp.phase * 1.9)) * 0.012

        let a = lit * ember * presence
        let eyeW: CGFloat = 0.125
        let eyeH: CGFloat = 0.150 * CGFloat(openness)

        // La face s'éclaire sous les yeux — leur propre lumière sur l'encre.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: side * 0.16))
            layer.fill(
                Path(ellipseIn: CGRect(x: -0.32, y: 0.30, width: 0.64, height: 0.34))
                    .applying(transform),
                with: .color(.white.opacity(0.14 * a))
            )
        }

        for s: CGFloat in [-1, 1] {
            let ex = 0.5 + s * 0.135 + gazeX
            let ey = 0.485 + gazeY
            let rect = CGRect(x: ex - eyeW / 2, y: ey - eyeH / 2, width: eyeW, height: eyeH)
            // L'inclinaison du splash : ±5°, pointes externes relevées.
            let eyeTurn = CGAffineTransform(translationX: ex, y: ey)
                .rotated(by: s * -0.087)
                .translatedBy(x: -ex, y: -ey)
            let globe = Path(ellipseIn: rect).applying(eyeTurn).applying(transform)

            // Le halo, puis la porcelaine — deux passes, comme toute lumière.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: max(1.5, side * 0.07)))
                layer.fill(globe, with: .color(.white.opacity(0.50 * a)))
            }
            context.fill(globe, with: .color(.white.opacity(0.95 * a)))

            // Le catchlight des grands : la pupille qu'on ne dessine pas.
            if side >= 40 {
                let cl = eyeW * 0.16
                let cx = ex - eyeW * 0.14 - gazeX * 0.8
                let cy = ey - eyeH * 0.22 - gazeY * 0.6
                let dot = Path(ellipseIn: CGRect(x: cx - cl / 2, y: cy - cl / 2,
                                                 width: cl, height: cl * 0.85))
                    .applying(transform)
                context.fill(dot, with: .color(.black.opacity(0.55 * a)))
            }
        }
    }
}

// MARK: - Révélation du formulaire

private extension View {
    /// L'entrée d'un bloc du formulaire : il monte de 26 pt en fondu, avec
    /// son retard propre — la cascade dans la nuit.
    func reveal(_ shown: Bool, delay: Double) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 26)
            .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(delay),
                       value: shown)
    }
}
