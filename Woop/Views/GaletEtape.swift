import SwiftUI
import Observation

// LE GALET-ÉTAPE — le nœud du chemin de feu (J2, plan
// tools/duolingo/PLAN-DUOLINGUO.md §6). École LaunchPebble en petit :
// dôme radial + foyer en voile séparé + liseré `galetLisere` — du verre
// PEINT (LOI 3 : le natif à jeun sur du noir rend un trou dans du métal).
//
// La grammaire est MUETTE (LOI 4) : les états se disent par la matière et
// la taille, jamais par la couleur ni un anneau. Le refus d'un verrouillé
// est L'IMMOBILITÉ : le press s'avorte à 1 %, le liseré s'allume une fois,
// froid, 0,12 s — un caillou refuse en étant un caillou.
//
// Le « légèrement 3D » : un FLANC de 2,5 pt sous le dôme (l'épaisseur que
// le press mange), le foyer qui glisse vers le doigt, et un micro-tilt
// ≤ 4° vers le point de contact.

// MARK: - Les états

enum EtapeEtat: Equatable {
    case verrouille          // un caillou d'obsidienne
    case prochain            // verrouillé, mais le glyphe appelle (30 %)
    case actif               // la nacre respire
    case accompli            // la nacre calme
    case parfait             // le souffle d'or dans le liseré
}

// MARK: - Le galet

struct GaletEtape: View {
    let etat: EtapeEtat
    /// Le glyphe : un chiffre d'étape laqué (école cadran), ou un croissant
    /// pour les jalons — jamais les glyphes Duolingo.
    var numero: Int? = nil
    var glyphe: String? = nil
    /// 76 au repos, 84 pour l'actif (la hiérarchie par la taille), 98 pour
    /// le nœud-trésor.
    var taille: CGFloat = 76
    var onTap: () -> Void = {}

    /// Les horodatages des rampes — un uniform de shader n'est pas
    /// animable par SwiftUI : la timeline fait la pente (école pressLevel).
    @State private var presseDepuis: Date? = nil
    @State private var relacheA: Date = .distantPast
    @State private var refusA: Date = .distantPast
    @State private var doigt: CGPoint = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Le pad du raster : le liseré, son halo et l'ombre vivent au bord —
    /// toute énergie meurt AVANT le bord du pad (le CADRE FANTÔME).
    private var pad: CGFloat { 26 }

    var body: some View {
        let verrouille = etat == .verrouille || etat == .prochain
        // La timeline ne tourne que si quelque chose vit : la respiration
        // de l'actif, ou une rampe de press/refus en vol (± une seconde).
        TimelineView(.animation(minimumInterval: nil, paused: pauseTimeline)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let press = rampePress(ctx.date)
            corps(t: t, press: press, verrouille: verrouille)
        }
        .frame(width: taille + 2 * pad, height: taille + 2 * pad)
        .contentShape(Circle().inset(by: pad - 6))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    doigt = g.location
                    if presseDepuis == nil {
                        presseDepuis = Date()
                        if !verrouille {
                            UIImpactFeedbackGenerator(style: .medium)
                                .impactOccurred(intensity: 0.85)
                        }
                    }
                }
                .onEnded { g in
                    relacheA = Date()
                    presseDepuis = nil
                    // Un TAP, pas la fin d'un scroll qui passait par là :
                    // au-delà de 12 pt de course, le geste appartient au
                    // défilement.
                    let course = hypot(g.translation.width, g.translation.height)
                    guard course < 12 else { return }
                    if verrouille {
                        // LE REFUS : rien ne bouge. Le liseré s'allume une
                        // fois, froid ; une haptique sèche. C'est tout.
                        refusA = Date()
                        UIImpactFeedbackGenerator(style: .rigid)
                            .impactOccurred(intensity: 0.6)
                    } else {
                        onTap()
                    }
                }
        )
    }

    private var pauseTimeline: Bool {
        if reduceMotion { return true }
        if etat == .actif || etat == .parfait { return false }
        if presseDepuis != nil { return false }
        let now = Date()
        return now.timeIntervalSince(relacheA) > 1.0
            && now.timeIntervalSince(refusA) > 1.0
    }

    /// La rampe horodatée : montée 0,10 s, descente 0,26 s, en smoothstep —
    /// un interrupteur claque, une matière se repose (école JewelTabBar).
    /// Un verrouillé n'accorde que 1 % : le press s'avorte.
    private func rampePress(_ now: Date) -> Double {
        func lisse(_ u: Double) -> Double {
            let v = min(max(u, 0), 1); return v * v * (3 - 2 * v)
        }
        if let debut = presseDepuis {
            return lisse(now.timeIntervalSince(debut) / 0.10)
        }
        return 1 - lisse(now.timeIntervalSince(relacheA) / 0.26)
    }

    @ViewBuilder
    private func corps(t: Double, press: Double, verrouille: Bool) -> some View {
        let D = taille
        let centre = CGPoint(x: pad + D / 2, y: pad + D / 2)
        let pressAmpl = verrouille ? 0.01 : 0.03
        let enfonce = 1 - pressAmpl * press
        // Le souffle de l'actif : la respiration asymétrique de la maison.
        let vivant = (etat == .actif || etat == .parfait) && !reduceMotion
        let souffle = vivant ? LaunchPebble.breath(t, lag: 0) : 0
        // Le flash froid du refus : une pente qui meurt en 0,12 s.
        let refus = max(0, 1 - Date(timeIntervalSinceReferenceDate: t)
            .timeIntervalSince(refusA) / 0.12)

        ZStack {
            // LE FLANC — l'épaisseur du verre, que le press mange.
            Circle()
                .fill(couleurFlanc)
                .frame(width: D, height: D)
                .position(x: centre.x, y: centre.y + 2.5 * enfonce)
            // LE DÔME — 6 arrêts, la lampe de la maison en haut à gauche.
            Circle()
                .fill(RadialGradient(
                    stops: arretsDome,
                    center: UnitPoint(x: 0.44, y: 0.40),
                    startRadius: 0, endRadius: D * 0.78))
                .frame(width: D, height: D)
                .position(centre)
            // LE FOYER — un voile, pas un anneau (« un gradient radial ne
            // sait faire que des ANNEAUX »). Il glisse vers le doigt.
            Ellipse()
                .fill(RadialGradient(
                    stops: [
                        .init(color: .white.opacity(foyerA * (1 + 0.5 * press)), location: 0),
                        .init(color: .white.opacity(foyerA * 0.4), location: 0.55),
                        .init(color: .white.opacity(0), location: 1),
                    ],
                    center: .center, startRadius: 0, endRadius: D * 0.30))
                .frame(width: D * 0.62, height: D * 0.46)
                .position(x: centre.x - D * 0.14 + decalFoyer.x * press,
                          y: centre.y - D * 0.18 + decalFoyer.y * press)
                .blur(radius: 7)
            // LE GLYPHE LAQUÉ — corps mat, glyphe laqué (l'école du galet
            // play). Un chiffre est légal sur du verre peint (école cadran).
            glypheVue
                .position(x: centre.x, y: centre.y - 1)
        }
        .compositingGroup()
        .colorEffect(lisereShader(t: t, souffle: souffle,
                                  press: press, refus: refus))
        // L'or du parfait : un souffle très bas, DERRIÈRE le liseré blanc.
        .background {
            if etat == .parfait {
                Circle()
                    .stroke(Color(red: 1.0, green: 0.82, blue: 0.45)
                        .opacity(0.10 + 0.10 * souffle), lineWidth: 3)
                    .frame(width: D + 2, height: D + 2)
                    .position(centre)
                    .blur(radius: 4)
            }
        }
        .scaleEffect(enfonce)
        // Le micro-tilt vers le doigt — le « légèrement 3D » du brief.
        .rotation3DEffect(
            .degrees(4 * press),
            axis: axeTilt,
            anchor: .center, perspective: 0.6)
    }

    // MARK: la matière par état

    private var arretsDome: [Gradient.Stop] {
        func gris(_ v: Double) -> Color { Color(white: v) }
        // ⚠️ PAS UNE BOULE DE BILLARD (payé à la première mire) : un écart
        // trop grand entre le cœur et le bord lit « balle de ping-pong ».
        // La matière de la maison est MATE — le volume vient du flanc, du
        // liseré et du foyer, le dôme reste presque plat.
        switch etat {
        case .verrouille, .prochain:
            // L'obsidienne : presque le noir de la page, le volume à peine.
            return [.init(color: gris(0.135), location: 0.0),
                    .init(color: gris(0.12), location: 0.40),
                    .init(color: gris(0.09), location: 0.78),
                    .init(color: gris(0.07), location: 0.92),
                    .init(color: gris(0.095), location: 0.99),
                    .init(color: gris(0.095), location: 1.0)]
        case .actif:
            // La nacre du galet d'aube, ramenée au petit format — mate.
            return [.init(color: gris(0.50), location: 0.0),
                    .init(color: gris(0.46), location: 0.40),
                    .init(color: gris(0.38), location: 0.78),
                    .init(color: gris(0.32), location: 0.92),
                    .init(color: gris(0.42), location: 0.99),
                    .init(color: gris(0.42), location: 1.0)]
        case .accompli, .parfait:
            // La nacre CALME : plus sombre, sans foyer vif.
            return [.init(color: gris(0.30), location: 0.0),
                    .init(color: gris(0.27), location: 0.40),
                    .init(color: gris(0.22), location: 0.78),
                    .init(color: gris(0.185), location: 0.92),
                    .init(color: gris(0.25), location: 0.99),
                    .init(color: gris(0.25), location: 1.0)]
        }
    }

    private var couleurFlanc: Color {
        switch etat {
        case .verrouille, .prochain: return Color(white: 0.035)
        default: return Color(white: 0.12)
        }
    }

    private var foyerA: Double {
        switch etat {
        case .verrouille, .prochain: return 0.05
        case .actif: return 0.30
        case .accompli, .parfait: return 0.14
        }
    }

    private var decalFoyer: CGPoint {
        // Le foyer glisse VERS le doigt (borné à ±6 pt).
        let c = CGPoint(x: pad + taille / 2, y: pad + taille / 2)
        let dx = min(max(doigt.x - c.x, -30), 30) / 5
        let dy = min(max(doigt.y - c.y, -30), 30) / 5
        return CGPoint(x: dx, y: dy)
    }

    private var axeTilt: (x: CGFloat, y: CGFloat, z: CGFloat) {
        // L'axe perpendiculaire au vecteur centre→doigt : le galet
        // s'incline vers le point de contact.
        let c = CGPoint(x: pad + taille / 2, y: pad + taille / 2)
        let vx = doigt.x - c.x, vy = doigt.y - c.y
        let n = max(1, sqrt(vx * vx + vy * vy))
        return (x: vy / n, y: -vx / n, z: 0)
    }

    @ViewBuilder private var glypheVue: some View {
        let laque = LinearGradient(
            colors: [Color(white: 1.0), Color(white: 0.78)],
            startPoint: .top, endPoint: .bottom)
        let alpha: Double = {
            switch etat {
            case .verrouille: return 0.22
            case .prochain: return 0.30
            case .actif: return 1.0
            case .accompli, .parfait: return 0.92
            }
        }()
        Group {
            if let g = glyphe {
                Image(systemName: g)
                    .font(.system(size: taille * 0.30, weight: .semibold))
            } else if let n = numero {
                Text("\(n)")
                    .font(.system(size: taille * 0.36, weight: .semibold,
                                  design: .rounded))
            }
        }
        .foregroundStyle(laque)
        .opacity(alpha)
    }

    /// `galetLisere` — 7 × float2 + 1 float, l'arité au float près (page
    /// BLANCHE sinon). Cercle : écrasement 1. Le liseré vit sur l'arc
    /// haut (la lampe de la maison), il meurt bien avant le bord du pad.
    /// ⚠️ domeRS.x est un RAYON (l'école LaunchPebble passe D = rayon) —
    /// passé en diamètre, l'arc flottait à 38 pt HORS du dôme (payé à la
    /// première mire).
    private func lisereShader(t: Double, souffle: Double,
                              press: Double, refus: Double) -> Shader {
        let D = Float(taille / 2)
        let cx = Float(pad + taille / 2), cy = Float(pad + taille / 2)
        let (delta, gain): (Float, Float) = {
            switch etat {
            case .verrouille, .prochain:
                return (5, 0.16 + Float(refus) * 0.55)
            case .actif:
                return (8 + Float(souffle) * 3.0, 0.85 + Float(press) * 0.15)
            case .accompli, .parfait:
                return (6, 0.34)
            }
        }()
        let haloA: Float = etat == .actif ? 0.10 + Float(souffle) * 0.08 : 0.04
        let dust: Float = etat == .actif ? 0.35 : 0
        // ⚠️ `fondu` attend des COSINUS d'angle (école LaunchPebble:289-290),
        // pas des degrés — en degrés bruts le fondu sature et le liseré fait
        // un ANNEAU complet, le radio-button interdit (payé à la 2e mire).
        let full = Float(cos(44.0 * Double.pi / 180))
        let end = Float(cos(110.0 * Double.pi / 180))
        return ShaderLibrary.galetLisere(
            .float2(cx, cy),
            .float2(D, 1.0),
            .float2(delta, 0.60),
            .float2(3.0, haloA),
            .float2(full, end),
            .float2(dust, Float(t)),
            .float2(0.34, 10),
            .float(gain))
    }
}

// MARK: - La mire des matières (`-pillMire`, §20 Pil-1)

/// LA MIRE DES MATIÈRES — les candidats du « à faire » (A natif /
/// B liquidLens / C peint enrichi), le métal sablé v1 (D) et l'actif (E),
/// sur DEUX fonds : le noir pur et le feu (les poses réelles de la page).
/// La question de Pil-1 : « le à-faire : natif, liquidLens ou peint ? »
struct PillMireLab: View {
    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 26) {
                Text("SUR LE NOIR").etiquette
                rangee()
                ZStack {
                    HStack(spacing: 0) {
                        Image("duo-feu-blanc-poster").resizable().scaledToFill()
                        Image("duo-feu-rouge-poster").resizable().scaledToFill()
                    }
                    .frame(height: 190).clipped()
                    rangee()
                }
                Text("SUR LE FEU").etiquette
                HStack(spacing: 26) {
                    VStack(spacing: 6) {
                        pillMetal(date: "12 JUN", taille: 100)
                        Text("D métal (grand)").etiquette
                    }
                    VStack(spacing: 6) {
                        GaletEtape(etat: .actif, numero: 2, taille: 92)
                        Text("E actif (actuel)").etiquette
                    }
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .environment(\.colorScheme, .dark)
    }

    private func rangee() -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 6) {
                pillNatif
                Text("A natif").etiquette
            }
            VStack(spacing: 6) {
                pillLens
                Text("B liquidLens").etiquette
            }
            VStack(spacing: 6) {
                GaletEtape(etat: .verrouille, numero: 4, taille: 76)
                    .frame(width: 84, height: 84)
                Text("C peint").etiquette
            }
            VStack(spacing: 6) {
                pillMetal(date: "12 JUN", taille: 76)
                Text("D métal").etiquette
            }
        }
    }

    /// A — LE NATIF `.clear` (le procès du §10.1, enfin sur mire — l'encre
    /// vit HORS du conteneur, la loi de la molette).
    private var pillNatif: some View {
        GlassEffectContainer(spacing: 0) {
            Circle()
                .fill(Color.clear)
                .glassEffect(.clear, in: Circle())
                .frame(width: 76, height: 76)
        }
        .frame(width: 84, height: 84)
    }

    /// B — LE LIQUIDLENS en petit : la vraie lentille de la fiche exo
    /// (layerEffect — elle réfracte SA couche : le patch de fond qu'on lui
    /// donne). Queue d'appel = 18 floats, l'arité de LaunchPebble.
    private var pillLens: some View {
        TimelineView(.animation) { ctx in
            let t = Float(ctx.date.timeIntervalSinceReferenceDate)
            ZStack {
                Image("duo-feu-blanc-poster")
                    .resizable().scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipped()
                    .opacity(0.55)
            }
            .layerEffect(ShaderLibrary.liquidLens(
                .float2(84, 84), .float2(42, 42), .float(36),
                .float(0.055), .float(0.9), .float(0),
                .float(1.0), .float(0.30), .float(t),
                .float(0), .float(0), .float(0), .float(0),
                .float(0), .float(0), .float(0), .float(0)),
                maxSampleOffset: CGSize(width: 24, height: 24))
        }
        .frame(width: 84, height: 84)
    }

    /// D — LE MÉTAL SABLÉ v1 : le shader `pillMetal` + le NÉON blanc
    /// autour du noir (anneau fin) + la DATE gravée en creux (l'emboss :
    /// encre sombre, lumière sur la lèvre basse).
    private func pillMetal(date: String, taille: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 0.08)) { ctx in
            let t = Float(ctx.date.timeIntervalSinceReferenceDate)
            let pad: CGFloat = 12
            ZStack {
                Rectangle()
                    .fill(.white)
                    .frame(width: taille + 2 * pad, height: taille + 2 * pad)
                    .colorEffect(ShaderLibrary.pillMetal(
                        .float2(Float(pad + taille / 2), Float(pad + taille / 2)),
                        .float2(Float(taille / 2), t),
                        .float2(0.018, 0.85)))
                // LE NÉON BLANC autour du noir — fin, calme, constant.
                Circle()
                    .stroke(Color.white.opacity(0.75), lineWidth: 1.4)
                    .frame(width: taille + 1, height: taille + 1)
                    .blur(radius: 0.6)
                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 4)
                    .frame(width: taille + 3, height: taille + 3)
                    .blur(radius: 3.5)
                // LA DATE GRAVÉE : l'encre enfoncée, la lèvre basse allumée.
                Text(date)
                    .font(.system(size: taille * 0.20, weight: .bold,
                                  design: .rounded))
                    .kerning(0.8)
                    .foregroundStyle(Color(white: 0.04))
                    .shadow(color: .white.opacity(0.30), radius: 0.4, y: 0.8)
            }
        }
        .frame(width: taille + 24, height: taille + 24)
    }
}

private extension Text {
    var etiquette: some View {
        self.font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.45))
    }
}

// MARK: - La mire (`-duoGalets`)

/// LA MIRE DU GALET-ÉTAPE : la grammaire complète sur mire grise et sur
/// noir (le galet vivra sur le noir de la LOI 2 — les deux fonds jugent).
struct GaletEtapeLab: View {
    @State private var actifTape = 0

    var body: some View {
        HStack(spacing: 0) {
            colonne(fond: Color(white: 0.42))
            colonne(fond: .black)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .environment(\.colorScheme, .dark)
    }

    private func colonne(fond: Color) -> some View {
        ZStack {
            fond
            VStack(spacing: 12) {
                GaletEtape(etat: .verrouille, numero: 4)
                GaletEtape(etat: .prochain, numero: 3)
                GaletEtape(etat: .actif, numero: 2, taille: 84,
                           onTap: { actifTape += 1 })
                GaletEtape(etat: .accompli, numero: 1)
                GaletEtape(etat: .parfait, numero: 1)
                GaletEtape(etat: .verrouille, glyphe: "moon.fill",
                           taille: 98)
                Text("taps : \(actifTape)")
                    .font(.system(size: 11, weight: .medium,
                                  design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}
