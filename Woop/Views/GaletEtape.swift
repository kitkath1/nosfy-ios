import SwiftUI
import Observation

// LE GALET-ÉTAPE (§22, réf 2 « LA PASTILLE-BIJOU ») — un ROND parfait,
// l'effet BOUTON à DEUX bordures : anneau externe vif / interstice noir /
// anneau interne discret, la lumière en ARCS INÉGAUX le long des anneaux
// (l'école du liseré fin : lobes en cosinus qui meurent en fondu, jamais
// un anneau égal), dôme de verre fumé sombre. Le peint (`goutteVerre`)
// est une FUMÉE semi-transparente : la lentille native `.clear` vit
// dessous et réfracte la vidéo. L'encre du chiffre vit AU-DESSUS.
//
// La grammaire est MUETTE (LOI 4) : la matière ne meurt jamais (la photo
// est la loi), les états ne jouent que sur une marge fine de gains, la
// taille et la respiration de l'actif. Le refus d'un verrouillé est
// L'IMMOBILITÉ : le press s'avorte à 1 %, les liserés s'allument une
// fois, froid, 0,12 s — un caillou refuse en étant un caillou.

// MARK: - Les états

enum EtapeEtat: Equatable {
    case verrouille          // un caillou d'obsidienne
    case prochain            // verrouillé, mais le glyphe appelle (30 %)
    case actif               // la nacre respire
    case accompli            // la nacre calme
    case parfait             // le souffle d'or dans le liseré
}

// MARK: - La forme de la goutte

/// LA MÊME forme que le shader `goutteVerre` (3 harmoniques + rotation +
/// écrasement), côté SwiftUI — pour la LENTILLE NATIVE qui vit sous le
/// peint. Les deux DOIVENT rester jumelles : un écart = un liseré qui
/// flotte hors du verre.
struct GoutteForme: Shape {
    var graine: Double
    var aspect: CGFloat

    func path(in rect: CGRect) -> Path {
        let s = graine
        let R = rect.width / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rot = 0.0
        var pts: [CGPoint] = []
        for i in 0..<96 {
            let th = Double(i) / 96 * 2 * .pi
            let rho = 1.0   // réf 2 : la pastille est un ROND parfait
            let x = cos(th) * rho
            let ys = sin(th) * rho * aspect
            let xr = cos(-rot) * x - sin(-rot) * ys
            let yr = sin(-rot) * x + cos(-rot) * ys
            pts.append(CGPoint(x: c.x + CGFloat(xr) * R,
                               y: c.y + CGFloat(yr) * R))
        }
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }
}

// MARK: - Le galet

struct GaletEtape: View {
    let etat: EtapeEtat
    /// Le glyphe : un chiffre d'étape laqué (école cadran), ou un croissant
    /// pour les jalons — jamais les glyphes Duolingo.
    var numero: Int? = nil
    var glyphe: String? = nil
    /// La LARGEUR de la goutte (§22 : 60 au repos, 66 pour l'actif, 82
    /// pour le nœud-trésor) — la hauteur en découle par l'écrasement.
    var taille: CGFloat = 60
    /// La graine de forme : chaque goutte du chemin est unique.
    var graine: Double = 0
    /// LA LENTILLE NATIVE — le verre `.clear` qui RÉFRACTE la vidéo qui
    /// bouge dessous (l'orbe, les flammes). Légal ici : le contenu est
    /// DOUX (la loi affinée du 20-08). Sur le noir pur elle est invisible
    /// — les cheveux peints portent la goutte. Coupée hors des écrans
    /// voisins (le budget verre).
    var lentille: Bool = true
    var onTap: () -> Void = {}

    /// L'écrasement de la goutte : plus large que haute, comme une goutte
    /// posée (la réf « CHAPITRE 1 » : ~0,72), jitté par graine — aucune
    /// goutte n'est tombée pareil.
    static let aspect: CGFloat = 1.0
    private var aspectGoutte: CGFloat {
        Self.aspect
    }

    /// Les horodatages des rampes — un uniform de shader n'est pas
    /// animable par SwiftUI : la timeline fait la pente (école pressLevel).
    @State private var presseDepuis: Date? = nil
    @State private var relacheA: Date = .distantPast
    @State private var refusA: Date = .distantPast
    /// La bouffée de FUMÉE du press (sa demande : « quand on appuie ça
    /// sort de la fumée ») — horodatée, fonction pure du temps.
    @State private var fumeeA: Date = .distantPast
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
        // les pastilles se frôlent (pas 58 / Ø 62) : la zone de tap
        // colle au bouton, sinon elle vole le doigt du voisin.
        .contentShape(Circle().inset(by: pad - 2))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    doigt = g.location
                    if presseDepuis == nil {
                        presseDepuis = Date()
                        if !verrouille {
                            fumeeA = Date()
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
            && now.timeIntervalSince(fumeeA) > 1.5
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
        let H = D * aspectGoutte
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
            // Le reflet au sol : la goutte est POSÉE — à peine visible.
            // LE MIROIR DU SOL — la réf : sous chaque goutte, un reflet
            // doux étiré vers le bas sur la dalle noire.
            Ellipse()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.08), .clear],
                    center: .center, startRadius: 0, endRadius: D * 0.42))
                .frame(width: D * 0.88, height: D * 0.30)
                .position(x: centre.x, y: centre.y + H / 2 + D * 0.15)
                .blur(radius: 6)
            Ellipse()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.05), .clear],
                    center: .center, startRadius: 0, endRadius: D * 0.26))
                .frame(width: D * 0.55, height: D * 0.10)
                .position(x: centre.x, y: centre.y + H / 2 + D * 0.05)
                .blur(radius: 3)
            // LA LENTILLE NATIVE — sous le peint : elle plie la vidéo qui
            // passe derrière la goutte (taille CONSTANTE, jamais animée —
            // la loi des bounds vivants).
            if lentille {
                Color.clear
                    .glassEffect(.clear, in: GoutteForme(graine: graine,
                                                         aspect: aspectGoutte))
                    .frame(width: D, height: D)
                    .position(centre)
            }
            // LA GOUTTE PEINTE — la fumée semi-transparente + les cheveux
            // de lumière du shader `goutteVerre`, AU-DESSUS du natif.
            Rectangle()
                .fill(.white)
                .frame(width: D + 2 * pad, height: D + 2 * pad)
                .colorEffect(goutteShader(souffle: souffle,
                                          press: press, refus: refus))
            // LE GLYPHE LAQUÉ — l'encre vit AU-DESSUS du verre peint.
            glypheVue
                .position(x: centre.x, y: centre.y + 1)
        }
        .compositingGroup()
        // LA FUMÉE DU PRESS — trois volutes pâles qui s'échappent du
        // bouton et se dissolvent (l'école Pil-3 B), une bouffée par
        // press, fonction pure du temps.
        .overlay {
            let u = min(max((t - fumeeA.timeIntervalSinceReferenceDate) / 1.3, 0), 1)
            if u > 0 && u < 1 {
                ForEach(0..<3, id: \.self) { i in
                    let ui = min(max(u * 1.4 - Double(i) * 0.12, 0), 1)
                    let derive: CGFloat = [-14, 10, -4][i]
                    Ellipse()
                        .fill(Color(white: 0.88)
                            .opacity(0.24 * (1 - ui) * (ui > 0 ? 1 : 0)))
                        .frame(width: D * (0.30 + 0.45 * ui),
                               height: D * (0.22 + 0.30 * ui))
                        .offset(x: derive * ui + [8, -10, 2][i],
                                y: -H * 0.34 - D * 0.62 * ui)
                        .blur(radius: 5 + 7 * ui)
                }
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

    /// Les gains de la goutte (rim, pool, or) — la grammaire reste MUETTE :
    /// l'état se dit par l'intensité de la lumière, jamais par la couleur
    /// (l'or du parfait excepté, dans la nappe basse seulement).
    private var gainsEtat: (rim: Float, pool: Float, chaud: Float) {
        // LA PHOTO EST LA LOI : la matière ne meurt jamais — les états
        // ne jouent que sur une marge fine (le chemin se lit au chiffre
        // et à la respiration de l'actif).
        switch etat {
        case .verrouille: return (0.85, 0.85, 0)
        case .prochain: return (0.92, 0.92, 0)
        case .actif: return (1.0, 1.0, 0)
        case .accompli: return (0.95, 0.90, 0)
        case .parfait: return (0.95, 0.90, 0.5)
        }
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
        // La réf : des chiffres BLANCS, droits, poids moyen — jamais
        // rounded (le chiffre de la réf est un SF droit).
        let laque = LinearGradient(
            colors: [Color(white: 0.92), Color(white: 0.74)],
            startPoint: .top, endPoint: .bottom)
        let alpha: Double = {
            switch etat {
            case .verrouille: return 0.85
            case .prochain: return 0.90
            case .actif: return 1.0
            case .accompli, .parfait: return 0.92
            }
        }()
        Group {
            if let g = glyphe {
                Image(systemName: g)
                    .font(.system(size: taille * 0.26, weight: .regular))
            } else if let n = numero {
                Text("\(n)")
                    .font(.system(size: taille * 0.27, weight: .regular))
            }
        }
        .foregroundStyle(laque)
        .opacity(alpha)
    }

    /// `goutteVerre` — 6 × float2 + 1 float, l'arité au float près (page
    /// BLANCHE sinon). Ra.x est la DEMI-largeur ; la forme vient de la
    /// graine, les états ne jouent que sur les gains de lumière.
    private func goutteShader(souffle: Double, press: Double,
                              refus: Double) -> Shader {
        let R = Float(taille / 2)
        let c = Float(pad + taille / 2)
        let g = gainsEtat
        return ShaderLibrary.goutteVerre(
            .float2(c, c),
            .float2(R, Float(aspectGoutte)),
            .float2(Float(graine), g.chaud),
            .float2(g.rim, g.pool),
            .float2(Float(press), Float(souffle)),
            .float2(Float(refus), 0),
            .float(1.0))
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
                // §20 Pil-3 — LE PRESS : « quand on appuie, de la fumée ou
                // de la lumière sort ». Les deux candidats, à presser.
                HStack(spacing: 30) {
                    VStack(spacing: 6) {
                        PressDemo(fumee: false)
                        Text("A — la lumière").etiquette
                    }
                    VStack(spacing: 6) {
                        PressDemo(fumee: true)
                        Text("B — la fumée").etiquette
                    }
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .environment(\.colorScheme, .dark)
    }

    private func rangee() -> some View {
        HStack(spacing: 22) {
            VStack(spacing: 6) {
                boutonNatif(date: nil, ame: 0.16)
                Text("à faire").etiquette
            }
            VStack(spacing: 6) {
                boutonNatif(date: "25 AUG", ame: 0.30)
                Text("actif").etiquette
            }
            VStack(spacing: 6) {
                pillMetal(date: "12 JUN", taille: 76)
                Text("fait — métal").etiquette
            }
        }
    }

    /// LE BOUTON NATIF NOURRI (son verdict Pil-1 : « on part en natif,
    /// mais on doit VOIR que c'est un bouton ») — le verre à jeun rendait
    /// un trou : on le NOURRIT (une âme peinte dessous, qu'il réfracte),
    /// et on lui donne le corps d'un bouton Duolingo : le FLANC épais
    /// sous la face, l'ombre portée de l'élévation. L'encre vit AU-DESSUS
    /// du verre, jamais dedans (la loi de la molette).
    private func boutonNatif(date: String?, ame: Double) -> some View {
        let D: CGFloat = 76
        return ZStack {
            // l'ombre portée : le bouton est POSÉ sur la page
            Ellipse()
                .fill(Color.black.opacity(0.6))
                .frame(width: D * 0.92, height: D * 0.30)
                .offset(y: D * 0.50)
                .blur(radius: 7)
            // le flanc : l'épaisseur que le press mangera
            Circle()
                .fill(Color(white: 0.055))
                .frame(width: D, height: D)
                .offset(y: 5)
            // l'âme : ce que le verre réfracte — la nacre qui nourrit
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: Color(white: ame + 0.14), location: 0),
                        .init(color: Color(white: ame), location: 0.55),
                        .init(color: Color(white: ame * 0.55), location: 1),
                    ],
                    center: UnitPoint(x: 0.42, y: 0.36),
                    startRadius: 0, endRadius: D * 0.62))
                .frame(width: D - 2, height: D - 2)
            Ellipse()
                .fill(Color.white.opacity(0.20))
                .frame(width: D * 0.55, height: D * 0.30)
                .offset(x: -D * 0.10, y: -D * 0.22)
                .blur(radius: 6)
            // LA FACE DE VERRE NATIF — elle a maintenant de quoi vivre
            Circle()
                .fill(Color.clear)
                .glassEffect(.clear, in: Circle())
                .frame(width: D, height: D)
            // l'encre AU-DESSUS du verre
            if let date {
                Text(date)
                    .font(.system(size: D * 0.20, weight: .bold,
                                  design: .rounded))
                    .kerning(0.6)
                    .foregroundStyle(LinearGradient(
                        colors: [Color(white: 1.0), Color(white: 0.80)],
                        startPoint: .top, endPoint: .bottom))
            }
        }
        .frame(width: D + 24, height: D + 24)
    }

    /// D — LE MÉTAL SABLÉ v1 : le shader `pillMetal` + le NÉON blanc
    /// autour du noir (anneau fin) + la DATE gravée en creux (l'emboss :
    /// encre sombre, lumière sur la lèvre basse).
    private func pillMetal(date: String, taille: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 0.08)) { ctx in
            let t = Float(ctx.date.timeIntervalSinceReferenceDate)
            let pad: CGFloat = 12
            ZStack {
                // le bouton est POSÉ : l'ombre de l'élévation + le flanc
                Ellipse()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: taille * 0.92, height: taille * 0.30)
                    .offset(y: taille * 0.50)
                    .blur(radius: 7)
                Circle()
                    .fill(Color(white: 0.04))
                    .frame(width: taille, height: taille)
                    .offset(y: 5)
                Rectangle()
                    .fill(.white)
                    .frame(width: taille + 2 * pad, height: taille + 2 * pad)
                    .colorEffect(ShaderLibrary.pillMetal(
                        .float2(Float(pad + taille / 2), Float(pad + taille / 2)),
                        .float2(Float(taille / 2), t),
                        .float2(0.016, 0.8)))
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

/// §20 Pil-3 — LE PRESS DU BOUTON : au maintien la lumière s'accumule
/// sous la face (l'énergie), au relâcher elle S'ÉCHAPPE — en bloom (A) ou
/// en volutes de fumée pâle (B, esquisse). Rampes horodatées, fonctions
/// pures du temps (la maison : un @State par image est interdit).
private struct PressDemo: View {
    let fumee: Bool
    @State private var presseDepuis: Date? = nil
    @State private var relacheA: Date = .distantPast
    @State private var burstA: Date = .distantPast

    var body: some View {
        let D: CGFloat = 84
        TimelineView(.animation(minimumInterval: nil,
                                paused: pauseTimeline)) { ctx in
            let now = ctx.date
            let press = rampe(now)
            let u = burst(now)
            ZStack {
                // l'échappée au relâcher
                if u < 1 {
                    if fumee {
                        volutes(u: u, D: D)
                    } else {
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color(red: 1, green: 0.96,
                                               blue: 0.88).opacity(0.45 * (1 - u)),
                                         .clear],
                                center: .center, startRadius: 0,
                                endRadius: D * (0.7 + 0.8 * u)))
                            .frame(width: D * 2.2, height: D * 2.2)
                            .blendMode(.plusLighter)
                    }
                }
                // la lumière qui s'ACCUMULE au maintien
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.30 * press), .clear],
                        center: .center, startRadius: 0, endRadius: D * 0.9))
                    .frame(width: D * 1.8, height: D * 1.8)
                    .blendMode(.plusLighter)
                corpsBouton(D: D, press: press)
                    .offset(y: 3.5 * press)
            }
            .frame(width: D + 60, height: D + 60)
        }
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if presseDepuis == nil {
                    presseDepuis = Date()
                    UIImpactFeedbackGenerator(style: .medium)
                        .impactOccurred(intensity: 0.85)
                }
            }
            .onEnded { _ in
                relacheA = Date()
                burstA = Date()
                presseDepuis = nil
                UIImpactFeedbackGenerator(style: .light)
                    .impactOccurred(intensity: 0.6)
            })
    }

    private var pauseTimeline: Bool {
        if presseDepuis != nil { return false }
        return Date().timeIntervalSince(burstA) > 1.6
            && Date().timeIntervalSince(relacheA) > 0.5
    }

    private func rampe(_ now: Date) -> Double {
        func lisse(_ v: Double) -> Double {
            let u = min(max(v, 0), 1); return u * u * (3 - 2 * u)
        }
        if let d = presseDepuis { return lisse(now.timeIntervalSince(d) / 0.12) }
        return 1 - lisse(now.timeIntervalSince(relacheA) / 0.30)
    }

    private func burst(_ now: Date) -> Double {
        min(max(now.timeIntervalSince(burstA) / (fumee ? 1.4 : 0.55), 0), 1)
    }

    /// les volutes : trois souffles pâles qui montent et se dissolvent
    private func volutes(u: Double, D: CGFloat) -> some View {
        ForEach(0..<3, id: \.self) { i in
            let fi = Double(i)
            let ui = min(max((u * 1.4 - fi * 0.12), 0), 1)
            let derive: CGFloat = [-14, 10, -4][i]
            Ellipse()
                .fill(Color(white: 0.88).opacity(0.26 * (1 - ui) * (ui > 0 ? 1 : 0)))
                .frame(width: D * (0.30 + 0.45 * ui),
                       height: D * (0.22 + 0.30 * ui))
                .offset(x: derive * ui + [8, -10, 2][i],
                        y: -D * 0.30 - D * 0.75 * ui)
                .blur(radius: 5 + 7 * ui)
        }
    }

    private func corpsBouton(D: CGFloat, press: Double) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.6))
                .frame(width: D * 0.92, height: D * 0.30)
                .offset(y: D * 0.50 - 3.5 * press)
                .blur(radius: 7)
            Circle().fill(Color(white: 0.055))
                .frame(width: D, height: D).offset(y: 5 - 3.5 * press)
            Circle()
                .fill(RadialGradient(
                    stops: [.init(color: Color(white: 0.40), location: 0),
                            .init(color: Color(white: 0.28), location: 0.55),
                            .init(color: Color(white: 0.16), location: 1)],
                    center: UnitPoint(x: 0.42, y: 0.36),
                    startRadius: 0, endRadius: D * 0.62))
                .frame(width: D - 2, height: D - 2)
            Ellipse().fill(Color.white.opacity(0.20))
                .frame(width: D * 0.55, height: D * 0.30)
                .offset(x: -D * 0.10, y: -D * 0.22)
                .blur(radius: 6)
            Circle().fill(Color.clear)
                .glassEffect(.clear, in: Circle())
                .frame(width: D, height: D)
            Text("25 AUG")
                .font(.system(size: D * 0.19, weight: .bold, design: .rounded))
                .kerning(0.6)
                .foregroundStyle(LinearGradient(
                    colors: [Color(white: 1.0), Color(white: 0.80)],
                    startPoint: .top, endPoint: .bottom))
        }
    }
}

// MARK: - La mire (`-duoGalets`)

/// LA MIRE DU GALET-ÉTAPE (§22) : le serpentin RÉEL de l'écran « La
/// braise rouge » (la spec verbatim, jamais une copie), sur le noir de la
/// page, états mélangés comme en situation — 1-3 accomplis, 4 parfait,
/// 5 actif, 6 prochain, le reste verrouillé. La mire EST la vérité.
struct GaletEtapeLab: View {
    @State private var actifTape = 0

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.height / 874.0
            ZStack(alignment: .topLeading) {
                Color.black
                ForEach(EcranSpec.etapes.filter { $0.ecran == 3 }) { e in
                    let n = e.id % 10
                    GaletEtape(etat: etatMire(n),
                               numero: n + 1,
                               taille: 62,
                               graine: Double(e.id),
                               onTap: { actifTape += 1 })
                        .position(x: geo.size.width / 2 + e.dx,
                                  y: e.y * k)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .environment(\.colorScheme, .dark)
    }

    private func etatMire(_ n: Int) -> EtapeEtat {
        switch n {
        case 0, 1, 2: return .accompli
        case 3: return .parfait
        case 4: return .actif
        case 5: return .prochain
        default: return .verrouille
        }
    }
}
