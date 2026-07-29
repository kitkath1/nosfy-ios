import SwiftUI

// MARK: - Écran d'authentification

/// L'écran qui suit le splash : une nébuleuse fractale très noire rendue en
/// Metal (AuthNebula.metal) — brume qui se fond dans le noir, veine
/// granuleuse, milliers de poussières — habitée par des diablotins qu'on
/// DEVINE : corps en occultation pure, liserés de lumière d'une finesse de
/// cheveu, couronnes de micro-particules, fentes d'yeux féroces qui ne
/// s'allument que par moments. Au centre, le formulaire.
struct AuthView: View {
    var onConnect: (String) -> Void

    /// L'horloge des diablotins : posée à l'apparition.
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

            AuthNebulaView()
                .ignoresSafeArea()

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

// MARK: - Le fond Metal

/// L'hôte des deux passes d'AuthNebula.metal, sur le modèle exact de
/// WoopDemonSky : la brume en demi-résolution agrandie ×2, les poussières en
/// pleine résolution composées en plusLighter, 30 images par seconde.
private struct AuthNebulaView: View {
    @State private var revealStart: Date = .now

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                // Temps absolu modulo 900 s — mêmes conventions que le ciel.
                let t = Float(timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                let raw = min(max(timeline.date.timeIntervalSince(revealStart) / 2.0, 0), 1)
                let reveal = Float(raw * raw * (3 - 2 * raw))

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(.black)
                        .frame(width: w / 2, height: h / 2)
                        .colorEffect(Self.dithered(ShaderLibrary.authNebulaField(
                            .float2(w / 2, h / 2), .float(t), .float(reveal),
                            .image(NebulaNoise.image))))
                        .scaleEffect(2, anchor: .topLeading)

                    Rectangle()
                        .fill(.black)
                        .frame(width: w, height: h)
                        .colorEffect(ShaderLibrary.authNebulaStars(
                            .float2(w, h), .float(t), .float(reveal),
                            .image(NebulaNoise.image)))
                        .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { revealStart = .now }
    }

    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }
}

// MARK: - Les diablotins devinés

/// La couche Canvas au-dessus de la nébuleuse : des présences, pas des
/// personnages. Chaque diablotin est un TROU dans la brume (occultation
/// noire à la silhouette du splash), révélé par des cheveux de lumière
/// distribués par une enveloppe bruitée — 2-3 éclats, de vrais trous — et
/// par une couronne de micro-particules. Les yeux sont des fentes.
private struct ImpNight: View {
    var t: Double

    // MARK: La silhouette du splash

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

    /// Le contour rééchantillonné (les cheveux de lumière) et ses normales
    /// extérieures (la couronne).
    static let rim: [CGPoint] = inkResample(outline, count: 120)
    static let normals: [CGPoint] = {
        let n = rim.count
        let centroid = CGPoint(x: 0.5, y: 0.55)
        return (0..<n).map { i in
            let a = rim[max(0, i - 1)], b = rim[min(n - 1, i + 1)]
            var dx = b.x - a.x, dy = b.y - a.y
            let length = max(hypot(dx, dy), 0.0001)
            dx /= length; dy /= length
            var nx = -dy, ny = dx
            if nx * (centroid.x - rim[i].x) + ny * (centroid.y - rim[i].y) > 0 {
                nx = -nx; ny = -ny
            }
            return CGPoint(x: nx, y: ny)
        }
    }()
    /// Le biais de crête : la lumière accroche le haut (crête, cornes),
    /// meurt sur l'assise. L'enveloppe bruitée fera le reste.
    static let rimCrest: [CGFloat] = rim.map { p in
        let crest = smoothstep((0.50 - p.y) / 0.34)
        let seat = 1 - smoothstep((p.y - 0.82) / 0.10)
        return (0.18 + 0.82 * crest) * seat
    }

    /// L'enveloppe des accidents : le bruit qui décide OÙ la lumière accroche
    /// le contour — des îlots qui dérivent lentement, jamais un trait continu.
    static let envelope = InkNoise(seed: 77)

    // MARK: La couronne

    /// Les grains génériques d'une couronne : tirés une fois, décalés par
    /// individu. Denses contre la silhouette, raréfiés au loin.
    struct Grain {
        let index: Int
        let dist: CGFloat
        let size: CGFloat
        let freq: Double
        let phase: Double
    }

    static let grains: [Grain] = {
        let noise = InkNoise(seed: 113)
        return (0..<48).map { i in
            let u = CGFloat(i)
            return Grain(
                index: Int(abs(noise(u * 1.7)) * CGFloat(rim.count - 1)),
                dist: 0.012 + pow(abs(noise(u * 2.9)), 2) * 0.20,
                size: 0.30 + 0.60 * abs(noise(u * 5.3)),
                freq: 0.5 + 2.1 * Double(abs(noise(u * 6.7))),
                phase: Double(abs(noise(u * 8.1))) * 6.28
            )
        }
    }()

    // MARK: Le peuple

    private struct Imp {
        let x: CGFloat
        let y: CGFloat
        let side: CGFloat
        let tilt: Double
        let phase: Double
        let ephemeral: Bool
        let litFraction: Double
    }

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
        Imp(x: 0.60, y: 0.04, side: 14, tilt: -7, phase: 5.9, ephemeral: true, litFraction: 0.32),
        Imp(x: 0.55, y: 0.355, side: 16, tilt: 5, phase: 1.8, ephemeral: true, litFraction: 0.25),
        Imp(x: 0.33, y: 0.27, side: 13, tilt: -6, phase: 3.3, ephemeral: true, litFraction: 0.22)
    ]

    private static func hash(_ i: Int, _ salt: Double) -> Double {
        let v = sin(Double(i) * 127.1 + salt * 311.7) * 43758.5453
        return v - v.rounded(.down)
    }

    var body: some View {
        Canvas { context, size in
            let fade = Double(smoothstep(CGFloat(t / 1.2)))
            guard fade > 0.01 else { return }
            for (i, imp) in Self.imps.enumerated() {
                drawImp(context, size, imp: imp, index: i, fade: fade)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Les vies

    /// Les ancres demeurent ; les éphémères se fondent dans la brume puis en
    /// ressortent, décalés — la nuit n'est jamais vide ni pleine.
    private func bodyPresence(_ imp: Imp, index: Int) -> Double {
        guard imp.ephemeral else { return 1 }
        let period = 17 + Self.hash(index, 60) * 9
        let visible = period * 0.62
        let c = (t + imp.phase * 4).truncatingRemainder(dividingBy: period)
        guard c < visible else { return 0 }
        let rise = Double(smoothstep(CGFloat(c / 1.8)))
        let fall = 1 - Double(smoothstep(CGFloat((c - (visible - 2.2)) / 2.2)))
        return rise * fall
    }

    /// Les yeux, par plages courtes sur la cadence propre de chacun — jamais
    /// tous ensemble, jamais longtemps.
    private func eyesLit(_ imp: Imp, index: Int) -> Double {
        let period = 9 + Self.hash(index, 61) * 6
        let lit = period * imp.litFraction
        let c = (t + imp.phase * 7).truncatingRemainder(dividingBy: period)
        guard c < lit else { return 0 }
        let rise = Double(smoothstep(CGFloat(c / 0.5)))
        let fall = 1 - Double(smoothstep(CGFloat((c - (lit - 0.7)) / 0.7)))
        return rise * fall
    }

    // MARK: Le dessin

    private func drawImp(_ context: GraphicsContext, _ size: CGSize,
                         imp: Imp, index: Int, fade: Double) {
        let birth = Double(smoothstep(CGFloat((t - 0.3 - Self.hash(index, 30) * 1.1) / 0.8)))
        let presence = bodyPresence(imp, index: index) * birth * fade
        guard presence > 0.01 else { return }
        let lit = eyesLit(imp, index: index)

        let cx = imp.x * size.width + CGFloat(sin(t * 0.11 + imp.phase * 2)) * 2.5
        let cy = imp.y * size.height + CGFloat(cos(t * 0.08 + imp.phase * 3)) * 2.0
        let side = imp.side
        let tilt = imp.tilt * .pi / 180
        let ca = CGFloat(cos(tilt)), sa = CGFloat(sin(tilt))

        func P(_ u: CGPoint) -> CGPoint {
            let dx = (u.x - 0.5) * side, dy = (u.y - 0.55) * side
            return CGPoint(x: cx + dx * ca - dy * sa, y: cy + dx * sa + dy * ca)
        }
        let transform = CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: tilt)
            .scaledBy(x: side, y: side)
            .translatedBy(x: -0.5, y: -0.55)

        // ---- L'occultation : le diablotin est un TROU dans la nébuleuse —
        // plus sombre que la brume, il l'avale, elle le dessine en creux.
        var silhouette = Path()
        silhouette.move(to: Self.outline[0])
        for p in Self.outline.dropFirst() { silhouette.addLine(to: p) }
        silhouette.closeSubpath()
        let body = silhouette.applying(transform)
        context.fill(
            body,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .black.opacity(0.60 * presence), location: 0.0),
                    .init(color: .black.opacity(0.88 * presence), location: 1.0)
                ]),
                startPoint: P(CGPoint(x: 0.5, y: 0.05)),
                endPoint: P(CGPoint(x: 0.5, y: 1.0))
            )
        )

        // ---- Les cheveux de lumière : l'enveloppe bruitée décide des îlots
        // (2-3 éclats, de vrais trous), la crête et les cornes sont
        // privilégiées, tout dérive lentement. Deux passes : le bloom voilé,
        // puis le cheveu vif — groupés par paliers en traits continus.
        let rimGain = presence * (0.35 + 0.65 * lit)
        let impSeed = CGFloat(index) * 37
        var buckets = [Int: Path]()
        let stride = side >= 50 ? 1 : 2
        var i = 0
        while i < Self.rim.count - stride {
            let e = 0.5 + 0.5 * Self.envelope(CGFloat(i) / 13 + impSeed + CGFloat(t) * 0.055)
            let accident = Double(smoothstep((e - 0.56) / 0.24))
            let w = Double(Self.rimCrest[i]) * (0.10 + 0.90 * accident)
            if w > 0.06 {
                let bucket = min(4, Int(w * 5))
                var path = buckets[bucket] ?? Path()
                path.move(to: P(Self.rim[i]))
                path.addLine(to: P(Self.rim[i + stride]))
                buckets[bucket] = path
            }
            i += stride
        }
        for (bucket, path) in buckets {
            let w = (Double(bucket) + 0.5) / 5
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 1.6))
                layer.stroke(path, with: .color(.white.opacity(w * 0.38 * rimGain)),
                             style: StrokeStyle(lineWidth: 1.8, lineCap: .butt))
            }
            context.stroke(
                path,
                with: .color(.white.opacity(w * 0.95 * rimGain)),
                style: StrokeStyle(lineWidth: side >= 50 ? 0.65 : 0.5,
                                   lineCap: .butt, lineJoin: .round)
            )
        }

        // ---- La couronne : la poussière qui trahit la présence — dense
        // contre la silhouette, raréfiée au loin, chaque grain sur sa cadence.
        let coronaGain = presence * (0.40 + 0.60 * lit)
        if coronaGain > 0.04 {
            let shift = Int(Self.hash(index, 70) * Double(Self.rim.count))
            for grain in Self.grains {
                let gi = (grain.index + shift) % Self.rim.count
                let base = Self.rim[gi]
                let normal = Self.normals[gi]
                let pos = P(CGPoint(x: base.x + normal.x * grain.dist,
                                    y: base.y + normal.y * grain.dist))
                let near = Double(1 - grain.dist / 0.24)
                let twinkle = 0.20 + 0.80 * pow(0.5 + 0.5 * sin(t * grain.freq + grain.phase + Double(index)), 3)
                let a = coronaGain * near * near * twinkle * 0.55
                guard a > 0.02 else { continue }
                let r = grain.size
                context.fill(
                    Path(ellipseIn: CGRect(x: pos.x - r, y: pos.y - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(a))
                )
            }
        }

        drawEyes(context, imp: imp, index: index, lit: lit,
                 presence: presence, transform: transform, side: side)
    }

    /// Les fentes : petites, acérées, pointes externes relevées — féroces.
    /// Le seul blanc pur de la scène.
    private func drawEyes(_ context: GraphicsContext, imp: Imp, index: Int,
                          lit: Double, presence: Double,
                          transform: CGAffineTransform, side: CGFloat) {
        guard lit > 0.01 else { return }
        let ember = 0.84 + 0.16 * sin(t * 1.3 + imp.phase * 4) * sin(t * 0.7 + imp.phase)
        let blinkPeriod = 4.5 + Self.hash(index, 62) * 3.5
        let c = (t + imp.phase * 5).truncatingRemainder(dividingBy: blinkPeriod)
        let window = blinkPeriod - 0.20
        let blink = c > window ? max(0, sin((c - window) / 0.20 * .pi)) : 0
        let openness = max(0.08, 1 - blink)
        let gazeX = CGFloat(sin(t * 0.10 + imp.phase * 2.7)) * 0.014
        let gazeY = CGFloat(cos(t * 0.07 + imp.phase * 1.9)) * 0.008

        let a = lit * ember * presence
        let eyeW: CGFloat = 0.105
        let eyeH: CGFloat = 0.030 * CGFloat(openness)

        // Une lueur infime sur la face — juste ce qu'il faut pour que les
        // fentes n'aient pas l'air collées sur du néant.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: side * 0.10))
            layer.fill(
                Path(ellipseIn: CGRect(x: 0.26, y: 0.40, width: 0.48, height: 0.18))
                    .applying(transform),
                with: .color(.white.opacity(0.07 * a))
            )
        }

        for s: CGFloat in [-1, 1] {
            let ex = 0.5 + s * 0.135 + gazeX
            let ey = 0.485 + gazeY
            // L'amande-fente : deux arcs tendus, pointes vives.
            var slit = Path()
            slit.move(to: CGPoint(x: ex - eyeW / 2, y: ey))
            slit.addQuadCurve(to: CGPoint(x: ex + eyeW / 2, y: ey),
                              control: CGPoint(x: ex, y: ey - eyeH * 1.4))
            slit.addQuadCurve(to: CGPoint(x: ex - eyeW / 2, y: ey),
                              control: CGPoint(x: ex, y: ey + eyeH * 1.4))
            slit.closeSubpath()
            // Pointes EXTERNES relevées (~11°) : la férocité tient là.
            let turn = CGAffineTransform(translationX: ex, y: ey)
                .rotated(by: s * -0.19)
                .translatedBy(x: -ex, y: -ey)
            let shaped = slit.applying(turn).applying(transform)

            context.drawLayer { layer in
                layer.addFilter(.blur(radius: max(1.2, side * 0.045)))
                layer.fill(shaped, with: .color(.white.opacity(0.55 * a)))
            }
            context.fill(shaped, with: .color(.white.opacity(min(1, 0.97 * a))))
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
