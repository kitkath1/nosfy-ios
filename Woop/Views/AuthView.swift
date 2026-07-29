import SwiftUI

// MARK: - Écran d'authentification

/// L'écran qui suit le splash : le même noir souverain, et le lettrage WOOP
/// en lumière — la lumière AVANT la matière : les faisceaux percent d'abord
/// le noir, les lettres se révèlent dedans, puis, par moments seulement,
/// deux yeux en amande s'allument dans les O — l'apparition, jamais le décor.
/// En dessous, le formulaire : un titre, le numéro, le bouton velours noir.
struct AuthView: View {
    var onConnect: (String) -> Void

    /// L'horloge de la séquence : posée à l'apparition, tout le lettrage
    /// se déduit d'elle (faisceaux, révélation, apparitions des yeux).
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
            Color.black
                .ignoresSafeArea()
                .onTapGesture { phoneFocused = false }

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                wordmark
                    .frame(height: 70)
                    .padding(.bottom, 60)

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { formShown = true }
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

    // MARK: Le lettrage

    private static let letters: [Character] = Array("WOOP")
    /// La font de la lumière : Futura Medium — géométrique, fine, les O
    /// parfaitement ronds. C'est la graisse Bold qui faisait « autocollant ».
    private static let neonFont = Font.custom("Futura-Medium", size: 52)
    /// La matière de la lettre : un souffle plus claire en crête qu'en pied —
    /// la lumière a une direction, jamais un aplat.
    private static let letterFill = LinearGradient(
        stops: [
            .init(color: .white, location: 0.0),
            .init(color: Color(white: 0.97), location: 0.45),
            .init(color: Color(white: 0.84), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )

    private var wordmark: some View {
        TimelineView(.animation) { context in
            let t = start.map { context.date.timeIntervalSince($0) } ?? 0
            wordmarkContent(t: t)
        }
    }

    /// Les couches, dans l'ordre où la lumière existe : les faisceaux et leur
    /// poussière, la brume, le bloom serré, puis la matière nette des lettres.
    private func wordmarkContent(t: Double) -> some View {
        let pulse = Self.eyePresence(t)
        let reveal = sm((t - 0.95) / 0.9)
        return letterRow(t: t)
            .background(alignment: .bottom) {
                BeamField(t: t, pulse: pulse)
                    .frame(width: 260, height: 430)
                    .offset(y: -16)
                    .blendMode(.plusLighter)
            }
            .background {
                // La brume : large, très faible — elle respire avec l'apparition.
                letterRow(t: t)
                    .blur(radius: 20)
                    .opacity(0.24 + 0.16 * pulse)
                    .blendMode(.plusLighter)
            }
            .background {
                // Le bloom serré : c'est lui qui fait « surexposé », pas un
                // gros halo — 3 pt, pas 20.
                letterRow(t: t)
                    .blur(radius: 3)
                    .opacity(0.45 + 0.25 * pulse)
                    .blendMode(.plusLighter)
            }
            // La révélation : les lettres se condensent dans la lumière —
            // floues puis nettes, jamais un simple fondu.
            .blur(radius: (1 - reveal) * 7)
    }

    /// Une rangée de lettres à l'instant `t`, les O habités par l'apparition.
    private func letterRow(t: Double) -> some View {
        HStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { i in
                let isO = i == 1 || i == 2
                Text(String(Self.letters[i]))
                    .font(Self.neonFont)
                    .foregroundStyle(Self.letterFill)
                    .opacity(letterAlpha(i: i, t: t))
                    .overlay {
                        if isO {
                            almondEye(t: t, mirrored: i == 1)
                        }
                    }
            }
        }
    }

    /// La révélation d'une lettre : en cascade douce, gauche → droite, puis
    /// une respiration à peine perceptible. Aucun crachotement : la lumière
    /// arrive, la matière se condense dedans.
    private func letterAlpha(i: Int, t: Double) -> Double {
        let k = sm((t - 0.95 - 0.10 * Double(i)) / 0.85)
        let breath = 0.975 + 0.025 * sin(t * 0.8 + Double(i) * 1.6)
        return k * breath
    }

    // MARK: L'apparition

    /// Le regard n'est pas un décor : les O restent des lettres pures, et
    /// toutes les ~7,5 s, les yeux s'allument 1,8 s puis s'éteignent.
    /// Renvoie la présence 0…1 — le halo et les faisceaux respirent avec.
    private static func eyePresence(_ t: Double) -> Double {
        let tt = t - 3.2   // première apparition, une fois le lettrage posé
        guard tt >= 0 else { return 0 }
        let cycle = tt.truncatingRemainder(dividingBy: 7.5)
        let rise = Double(smoothstep(CGFloat(cycle / 0.35)))
        let fall = 1 - Double(smoothstep(CGFloat((cycle - 2.0) / 0.5)))
        return rise * fall
    }

    /// L'œil en amande dans le contre du O : il ne vit que pendant
    /// l'apparition — une braise calme, un clin d'œil juste avant de mourir.
    private func almondEye(t: Double, mirrored: Bool) -> some View {
        let presence = Self.eyePresence(t)
        let tt = max(0, t - 3.2)
        let cycle = tt.truncatingRemainder(dividingBy: 7.5)
        // La braise : un tremblement lent, jamais un clignotement.
        let ember = 0.88 + 0.12 * sin(t * 5.1 + (mirrored ? 0 : 1.3)) * sin(t * 3.3)
        // Le clin d'œil d'adieu, juste avant l'extinction.
        let wink = cycle > 1.85 && cycle < 2.05
            ? max(0, sin((cycle - 1.85) / 0.20 * .pi)) : 0
        let openness = max(0.05, 1 - 0.9 * wink)
        let alpha = presence * ember

        return AlmondEyeShape()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: Color(white: 0.90), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: 13, height: 6)
            .scaleEffect(y: openness)
            .rotationEffect(.degrees(mirrored ? -5 : 5))
            .shadow(color: .white.opacity(0.85 * alpha), radius: 2)
            .shadow(color: .white.opacity(0.45 * alpha), radius: 6)
            .shadow(color: Color.lunar.opacity(0.30 * alpha), radius: 11)
            .opacity(alpha)
            .offset(y: -1)
    }

    /// smoothstep en Double — le confort local du helper d'Ink.
    private func sm(_ x: Double) -> Double { Double(smoothstep(CGFloat(x))) }
}

// MARK: - Les faisceaux

/// La lumière volumétrique : un faisceau par fût de lettre, dessiné — largeur,
/// longueur et intensité inégales, deux héros qui montent loin, et des grains
/// de poussière qui dérivent dans la lumière. C'est la scène du LOVE : des
/// shafts avec des trous, jamais une nappe de flou.
private struct BeamField: View {
    var t: Double
    var pulse: Double

    /// Un faisceau : position (en unités de la rangée), longueur, largeur à
    /// la base, inclinaison, et sa vie propre (fréquence, phase, gain).
    private struct Beam {
        let x: CGFloat
        let len: CGFloat
        let width: CGFloat
        let lean: CGFloat
        let freq: Double
        let phase: Double
        let gain: Double
    }

    /// Posés sur les fûts : W (cinq pointes), les jantes des O, la hampe et
    /// le ventre du P. Deux héros — un dans le W, un sur la hampe du P.
    private static let beams: [Beam] = [
        Beam(x: 0.030, len: 120, width: 3.2, lean: -0.018, freq: 0.42, phase: 0.7, gain: 0.75),
        Beam(x: 0.085, len: 310, width: 2.4, lean: -0.008, freq: 0.31, phase: 2.9, gain: 1.00),
        Beam(x: 0.140, len: 85, width: 3.6, lean: 0.004, freq: 0.55, phase: 1.6, gain: 0.60),
        Beam(x: 0.196, len: 150, width: 2.8, lean: 0.012, freq: 0.38, phase: 4.4, gain: 0.80),
        Beam(x: 0.250, len: 65, width: 3.0, lean: 0.020, freq: 0.60, phase: 0.2, gain: 0.55),
        Beam(x: 0.355, len: 105, width: 3.8, lean: -0.012, freq: 0.45, phase: 3.5, gain: 0.70),
        Beam(x: 0.465, len: 175, width: 3.0, lean: 0.008, freq: 0.34, phase: 5.1, gain: 0.85),
        Beam(x: 0.575, len: 140, width: 3.4, lean: -0.006, freq: 0.50, phase: 1.1, gain: 0.75),
        Beam(x: 0.685, len: 80, width: 3.0, lean: 0.014, freq: 0.58, phase: 2.3, gain: 0.55),
        Beam(x: 0.795, len: 330, width: 2.2, lean: 0.004, freq: 0.29, phase: 3.9, gain: 1.00),
        Beam(x: 0.885, len: 95, width: 3.4, lean: 0.018, freq: 0.48, phase: 5.7, gain: 0.65)
    ]

    /// Un petit générateur déterministe pour la poussière — pas de hasard,
    /// pas d'horloge : tout se déduit de l'index.
    private static func hash(_ i: Int, _ salt: Double) -> Double {
        let v = sin(Double(i) * 127.1 + salt * 311.7) * 43758.5453
        return v - v.rounded(.down)
    }

    var body: some View {
        Canvas { context, size in
            // Les faisceaux naissent avant les lettres : la lumière d'abord.
            let grow = Double(smoothstep(CGFloat((t - 0.25) / 1.1)))
            guard grow > 0.001 else { return }
            let lenK = CGFloat(0.35 + 0.65 * grow)
            let baseY = size.height - 30
            let rowW = size.width - 28
            let x0: CGFloat = 14

            for (b, beam) in Self.beams.enumerated() {
                // La vie du faisceau : un shimmer lent, cubique — des pleins
                // et de vrais creux, et l'apparition le fait respirer.
                let life = pow(0.5 + 0.5 * sin(t * beam.freq * 2 + beam.phase), 1.6)
                let a = beam.gain * (0.22 + 0.78 * life) * grow * (1 + 0.7 * pulse)
                guard a > 0.02 else { continue }

                let bx = x0 + beam.x * rowW
                let len = beam.len * lenK
                // L'éventail : les faisceaux DIVERGENT depuis le lettrage —
                // gauche vers la gauche, droite vers la droite — plus une
                // dérive propre minuscule. Jamais de croisements : des
                // projecteurs, pas un laser show.
                let topX = bx + (beam.x - 0.5) * len * 0.16 + beam.lean * len * 6
                let topY = baseY - len
                let wBase = beam.width
                let wTop = beam.width * 2.6

                // Le shaft : un trapèze qui S'OUVRE en montant (la lumière
                // diverge), fondu de la base vers le sommet.
                var path = Path()
                path.move(to: CGPoint(x: bx - wBase / 2, y: baseY))
                path.addLine(to: CGPoint(x: topX - wTop / 2, y: topY))
                path.addLine(to: CGPoint(x: topX + wTop / 2, y: topY))
                path.addLine(to: CGPoint(x: bx + wBase / 2, y: baseY))
                path.closeSubpath()

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 2.2))
                    layer.fill(
                        path,
                        with: .linearGradient(
                            Gradient(stops: [
                                .init(color: .white.opacity(0.34 * a), location: 0.0),
                                .init(color: .white.opacity(0.13 * a), location: 0.42),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: CGPoint(x: bx, y: baseY),
                            endPoint: CGPoint(x: topX, y: topY)
                        )
                    )
                }

                // La poussière du faisceau : trois grains qui montent dedans,
                // minuscules, éclairés par lui.
                for g in 0..<3 {
                    let i = b * 3 + g
                    let speed = 0.022 + 0.03 * Self.hash(i, 1)
                    let yy = (Self.hash(i, 2) + t * speed)
                        .truncatingRemainder(dividingBy: 1)
                    let sway = sin(t * (0.5 + Self.hash(i, 3)) + Double(i)) * 2.5
                    let px = bx + (topX - bx) * yy + sway
                    let py = baseY - len * yy
                    let twinkle = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(t * (1.1 + Self.hash(i, 4)) + Double(i) * 2.1), 2)
                    let ga = a * (1 - yy) * twinkle * 0.9
                    guard ga > 0.02 else { continue }
                    let r = 0.5 + 1.0 * Self.hash(i, 5)
                    context.fill(
                        Path(ellipseIn: CGRect(x: px - r, y: py - r,
                                               width: r * 2, height: r * 2)),
                        with: .color(.white.opacity(ga))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - L'amande

/// L'œil en amande : deux arcs symétriques, pointes vives aux deux bouts —
/// la lentille calme, pas la flamme.
private struct AlmondEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                          control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.30))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY),
                          control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.30))
        path.closeSubpath()
        return path
    }
}

// MARK: - Révélation du formulaire

private extension View {
    /// L'entrée d'un bloc du formulaire : il monte de 26 pt en fondu, avec
    /// son retard propre — la cascade sous la lumière.
    func reveal(_ shown: Bool, delay: Double) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 26)
            .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(delay),
                       value: shown)
    }
}
